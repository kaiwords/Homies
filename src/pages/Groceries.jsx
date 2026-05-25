import { useState } from 'react'
import { useHomies } from '../context/HomiesContext.jsx'
import { Avatar } from '../components/Avatar.jsx'
import { FilePicker, Attachment } from '../components/FilePicker.jsx'
import { MarkPaidModal } from '../components/MarkPaidModal.jsx'
import { fmtAUD, fmtDate, equalSplit } from '../lib/format.js'

export function Groceries() {
  const { state, update, currentUser } = useHomies()
  const [editing, setEditing] = useState(null)
  const [paying, setPaying] = useState(null)

  const remove = (g) => {
    if (!confirm(`Delete "${g.title}"?`)) return
    update((s) => ({ ...s, groceries: s.groceries.filter((x) => x.id !== g.id) }))
  }

  const togglePaid = (g, uid, proof) => {
    update((s) => ({
      ...s,
      groceries: s.groceries.map((x) => {
        if (x.id !== g.id) return x
        const paidBy = { ...(x.paidBy || {}) }
        const paidByProof = { ...(x.paidByProof || {}) }
        if (paidBy[uid]) {
          delete paidBy[uid]
          delete paidByProof[uid]
        } else {
          paidBy[uid] = true
          if (proof) paidByProof[uid] = proof
        }
        return { ...x, paidBy, paidByProof }
      }),
    }))
  }

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Groceries</h1>
          <p>Shared shops or solo runs — upload the receipt and we'll do the splits.</p>
        </div>
        <button className="btn" onClick={() => setEditing({})}>+ Log shop</button>
      </div>

      {state.groceries.length === 0 && <div className="empty"><h3>No shops logged yet</h3></div>}

      {state.groceries.map((g) => {
        const payer = state.users.find((u) => u.id === g.payer)
        const isCreator = (g.addedBy || g.payer) === currentUser.id
        return (
          <div className="card" key={g.id}>
            <div className="row" style={{ alignItems: 'flex-start' }}>
              <div style={{ flex: 1 }}>
                <div className="bold">{g.title}</div>
                <div className="tiny muted">
                  {fmtDate(g.date)} · paid by {payer?.name || '—'} · {g.mode === 'shared' ? 'split shared' : 'individual'}
                </div>
              </div>
              <div className="bold">{fmtAUD(g.total)}</div>
              {isCreator && (
                <div className="row" style={{ marginLeft: 8 }}>
                  <button className="btn secondary small" onClick={() => setEditing(g)}>Edit</button>
                  <button className="btn ghost small" onClick={() => remove(g)}>Delete</button>
                </div>
              )}
            </div>

            {g.receipt && (
              <div style={{ marginTop: 6 }}>
                <div className="tiny muted bold">Receipt</div>
                <Attachment value={g.receipt} compact />
              </div>
            )}

            {g.mode === 'shared' && (
              <>
                <hr />
                {Object.entries(g.shares || {}).map(([uid, amt]) => {
                  const u = state.users.find((x) => x.id === uid)
                  if (!u) return null
                  const paid = !!(g.paidBy && g.paidBy[uid])
                  const proof = g.paidByProof?.[uid] || null
                  const isYou = uid === currentUser.id
                  const isPayer = uid === g.payer
                  return (
                    <div key={uid} className="row" style={{ padding: '6px 0' }}>
                      <Avatar user={u} size="sm" />
                      <div style={{ flex: 1 }}>
                        <div className="bold tiny">{u.name}{isYou ? ' (you)' : ''}{isPayer ? ' — payer' : ''}</div>
                        <div className="tiny muted">{fmtAUD(amt)}</div>
                      </div>
                      {proof && (
                        <a href={proof.dataUrl} target="_blank" rel="noreferrer" title="View payment proof">
                          {proof.type?.startsWith('image/')
                            ? <img src={proof.dataUrl} alt="" style={{ width: 28, height: 28, objectFit: 'cover', borderRadius: 4 }} />
                            : <span className="chip">📎</span>}
                        </a>
                      )}
                      {!isPayer && (
                        <button
                          className={'btn small ' + (paid ? 'secondary' : '')}
                          onClick={() => paid ? togglePaid(g, uid) : setPaying({ grocery: g, uid })}
                          disabled={!isYou && !isCreator}
                        >
                          {paid ? '✓ Paid' : 'Mark paid'}
                        </button>
                      )}
                    </div>
                  )
                })}
              </>
            )}
          </div>
        )
      })}

      {editing && (
        <GroceryModal
          existing={editing.id ? editing : null}
          onClose={() => setEditing(null)}
        />
      )}

      {paying && (
        <MarkPaidModal
          title={`Mark "${paying.grocery.title}" as paid`}
          amountLabel={`Your share: ${fmtAUD(paying.grocery.shares?.[paying.uid] || 0)}`}
          onConfirm={(proof) => {
            togglePaid(paying.grocery, paying.uid, proof)
            setPaying(null)
          }}
          onClose={() => setPaying(null)}
        />
      )}
    </>
  )
}

function GroceryModal({ existing, onClose }) {
  const { state, update, currentUser } = useHomies()
  const housemates = state.users.filter((u) => !u.pending && !u.moveOutDate)
  const isEdit = !!existing

  const [draft, setDraft] = useState(isEdit ? {
    title: existing.title || '',
    total: String(existing.total ?? ''),
    mode: existing.mode || 'shared',
    payer: existing.payer || currentUser.id,
    participants: Object.keys(existing.shares || {}).length ? Object.keys(existing.shares) : housemates.map((u) => u.id),
    receipt: existing.receipt || null,
  } : {
    title: '',
    total: '',
    mode: 'shared',
    payer: currentUser.id,
    participants: housemates.map((u) => u.id),
    receipt: null,
  })

  const setF = (k, v) => setDraft((d) => ({ ...d, [k]: v }))
  const toggleP = (id) => setF('participants', draft.participants.includes(id) ? draft.participants.filter((x) => x !== id) : [...draft.participants, id])

  const save = () => {
    const total = Number(draft.total) || 0
    const arr = equalSplit(total, draft.participants.length)
    const shares = draft.mode === 'shared'
      ? draft.participants.reduce((acc, id, i) => ({ ...acc, [id]: arr[i] }), {})
      : {}

    update((s) => {
      if (isEdit) {
        const newShareUids = Object.keys(shares)
        const paidBy = Object.fromEntries(Object.entries(existing.paidBy || {}).filter(([uid]) => newShareUids.includes(uid)))
        const paidByProof = Object.fromEntries(Object.entries(existing.paidByProof || {}).filter(([uid]) => newShareUids.includes(uid)))
        return {
          ...s,
          groceries: s.groceries.map((x) => x.id === existing.id ? {
            ...x,
            title: draft.title,
            total,
            payer: draft.payer,
            mode: draft.mode,
            shares,
            paidBy,
            paidByProof,
            receipt: draft.receipt,
          } : x),
        }
      }
      return {
        ...s,
        groceries: [...s.groceries, {
          id: 'g-' + Math.random().toString(36).slice(2, 6),
          title: draft.title,
          total,
          payer: draft.payer,
          addedBy: currentUser.id,
          mode: draft.mode,
          split: 'equal',
          shares,
          paidBy: {},
          paidByProof: {},
          date: new Date().toISOString().slice(0, 10),
          receipt: draft.receipt,
        }],
      }
    })
    onClose()
  }

  return (
    <div className="modal-bg" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <h2>{isEdit ? 'Edit grocery shop' : 'Log a grocery shop'}</h2>

        <div className="field">
          <label>What was it?</label>
          <input type="text" value={draft.title} onChange={(e) => setF('title', e.target.value)} placeholder="Coles weekly shop" />
        </div>

        <div className="field-row">
          <div className="field">
            <label>Total</label>
            <input type="number" min="0" step="0.01" value={draft.total} onChange={(e) => setF('total', e.target.value)} />
          </div>
          <div className="field">
            <label>Paid by</label>
            <select value={draft.payer} onChange={(e) => setF('payer', e.target.value)}>
              {housemates.map((u) => <option key={u.id} value={u.id}>{u.name}</option>)}
            </select>
          </div>
        </div>

        <div className="field">
          <label>Mode</label>
          <div className="segment">
            <button type="button" className={draft.mode === 'shared' ? 'on' : ''} onClick={() => setF('mode', 'shared')}>Shared (split it)</button>
            <button type="button" className={draft.mode === 'individual' ? 'on' : ''} onClick={() => setF('mode', 'individual')}>Individual (no split)</button>
          </div>
        </div>

        {draft.mode === 'shared' && (
          <div className="field">
            <label>Split between</label>
            <div className="checkbox-grid">
              {housemates.map((u) => (
                <label key={u.id}>
                  <input type="checkbox" checked={draft.participants.includes(u.id)} onChange={() => toggleP(u.id)} />
                  {u.name}
                </label>
              ))}
            </div>
          </div>
        )}

        <div className="field">
          <label>Receipt <span className="hint">(optional)</span></label>
          <FilePicker value={draft.receipt} onChange={(f) => setF('receipt', f)} />
        </div>

        <div className="modal-actions">
          <button className="btn secondary" onClick={onClose}>Cancel</button>
          <button className="btn" onClick={save} disabled={!draft.title || !draft.total}>{isEdit ? 'Save changes' : 'Save'}</button>
        </div>
      </div>
    </div>
  )
}
