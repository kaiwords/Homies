import { useState } from 'react'
import { useHomies } from '../context/HomiesContext.jsx'
import { Avatar } from '../components/Avatar.jsx'
import { FilePicker, Attachment } from '../components/FilePicker.jsx'
import { MarkPaidModal } from '../components/MarkPaidModal.jsx'
import { fmtAUD, fmtDate, equalSplit } from '../lib/format.js'

export function Necessities() {
  const { state, update, currentUser } = useHomies()
  const [editing, setEditing] = useState(null)
  const [paying, setPaying] = useState(null)

  const totalShared = state.necessities
    .filter((n) => n.mode === 'shared')
    .reduce((s, n) => s + n.amount, 0)
  const housematesCount = state.users.filter((u) => !u.pending && !u.moveOutDate).length
  const perPerson = housematesCount ? totalShared / housematesCount : 0

  const remove = (n) => {
    if (!confirm(`Delete "${n.item}"?`)) return
    update((s) => ({ ...s, necessities: s.necessities.filter((x) => x.id !== n.id) }))
  }

  const togglePaid = (n, uid, proof) => {
    update((s) => ({
      ...s,
      necessities: s.necessities.map((x) => {
        if (x.id !== n.id) return x
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
          <h1>Necessities</h1>
          <p>Toilet paper, hand soap, bin liners — the small stuff. Whoever logs the purchase picks the split.</p>
        </div>
        <button className="btn" onClick={() => setEditing({})}>+ Log purchase</button>
      </div>

      <div className="card">
        <div className="card-row">
          <div className="stat">
            <div className="label">Shared total this period</div>
            <div className="value">{fmtAUD(totalShared)}</div>
          </div>
          <div className="stat">
            <div className="label">≈ Per person</div>
            <div className="value">{fmtAUD(perPerson)}</div>
          </div>
        </div>
      </div>

      {state.necessities.length === 0 && <div className="empty"><h3>Nothing logged yet</h3></div>}

      {state.necessities.map((n) => {
        const payer = state.users.find((u) => u.id === n.payer)
        const isCreator = n.addedBy === currentUser.id
        const shares = n.shares || {}
        return (
          <div key={n.id} className="card">
            <div className="row" style={{ alignItems: 'flex-start' }}>
              <Avatar user={payer} size="sm" />
              <div style={{ flex: 1 }}>
                <div className="bold">{n.item}</div>
                <div className="tiny muted">
                  {fmtDate(n.date)} · paid by {payer?.name || '—'} · {n.mode === 'shared' ? `split ${n.split || 'equal'}` : 'just them'}
                </div>
              </div>
              <div className="bold">{fmtAUD(n.amount)}</div>
              {isCreator && (
                <div className="row" style={{ marginLeft: 8 }}>
                  <button className="btn secondary small" onClick={() => setEditing(n)}>Edit</button>
                  <button className="btn ghost small" onClick={() => remove(n)}>Delete</button>
                </div>
              )}
            </div>

            {n.proof && (
              <div style={{ marginTop: 6 }}>
                <div className="tiny muted bold">Receipt</div>
                <Attachment value={n.proof} compact />
              </div>
            )}

            {n.mode === 'shared' && (
              <>
                <hr />
                {Object.entries(shares).map(([uid, amt]) => {
                  const u = state.users.find((x) => x.id === uid)
                  if (!u) return null
                  const paid = !!(n.paidBy && n.paidBy[uid])
                  const proof = n.paidByProof?.[uid] || null
                  const isYou = uid === currentUser.id
                  const isPayer = uid === n.payer
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
                          onClick={() => paid ? togglePaid(n, uid) : setPaying({ necessity: n, uid })}
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
        <NecessityModal
          existing={editing.id ? editing : null}
          onClose={() => setEditing(null)}
        />
      )}

      {paying && (
        <MarkPaidModal
          title={`Mark "${paying.necessity.item}" as paid`}
          amountLabel={`Your share: ${fmtAUD(paying.necessity.shares?.[paying.uid] || 0)}`}
          onConfirm={(proof) => {
            togglePaid(paying.necessity, paying.uid, proof)
            setPaying(null)
          }}
          onClose={() => setPaying(null)}
        />
      )}
    </>
  )
}

function NecessityModal({ existing, onClose }) {
  const { state, update, currentUser } = useHomies()
  const housemates = state.users.filter((u) => !u.pending && !u.moveOutDate)
  const isEdit = !!existing

  const initialCustom = isEdit && existing.split === 'custom'
    ? Object.fromEntries(Object.entries(existing.shares || {}).map(([id, amt]) => [id, String(amt)]))
    : {}

  const [draft, setDraft] = useState(isEdit ? {
    item: existing.item || '',
    amount: String(existing.amount ?? ''),
    mode: existing.mode || 'shared',
    participants: Object.keys(existing.shares || {}).length ? Object.keys(existing.shares) : housemates.map((u) => u.id),
    split: existing.split || 'equal',
    custom: initialCustom,
    proof: existing.proof || null,
  } : {
    item: '',
    amount: '',
    mode: 'shared',
    participants: housemates.map((u) => u.id),
    split: 'equal',
    custom: {},
    proof: null,
  })

  const setF = (k, v) => setDraft((d) => ({ ...d, [k]: v }))
  const toggleP = (id) => setF('participants', draft.participants.includes(id) ? draft.participants.filter((x) => x !== id) : [...draft.participants, id])

  const total = Number(draft.amount) || 0
  const computeShares = () => {
    if (draft.mode !== 'shared') return {}
    if (draft.split === 'equal') {
      const arr = equalSplit(total, draft.participants.length)
      return draft.participants.reduce((acc, id, i) => ({ ...acc, [id]: arr[i] }), {})
    }
    return draft.participants.reduce((acc, id) => ({ ...acc, [id]: Number(draft.custom[id] || 0) }), {})
  }
  const sharesPreview = computeShares()
  const splitTotal = Object.values(sharesPreview).reduce((a, b) => a + b, 0)

  const save = () => {
    update((s) => {
      if (isEdit) {
        const newShareUids = Object.keys(sharesPreview)
        const paidBy = Object.fromEntries(Object.entries(existing.paidBy || {}).filter(([uid]) => newShareUids.includes(uid)))
        const paidByProof = Object.fromEntries(Object.entries(existing.paidByProof || {}).filter(([uid]) => newShareUids.includes(uid)))
        return {
          ...s,
          necessities: s.necessities.map((x) => x.id === existing.id ? {
            ...x,
            item: draft.item,
            amount: total,
            mode: draft.mode,
            split: draft.split,
            shares: sharesPreview,
            paidBy,
            paidByProof,
            proof: draft.proof,
          } : x),
        }
      }
      return {
        ...s,
        necessities: [{
          id: 'n-' + Math.random().toString(36).slice(2, 6),
          item: draft.item,
          amount: total,
          mode: draft.mode,
          split: draft.split,
          shares: sharesPreview,
          payer: currentUser.id,
          addedBy: currentUser.id,
          paidBy: {},
          paidByProof: {},
          proof: draft.proof,
          date: new Date().toISOString().slice(0, 10),
        }, ...s.necessities],
      }
    })
    onClose()
  }

  return (
    <div className="modal-bg" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()} style={{ maxWidth: 560 }}>
        <h2>{isEdit ? 'Edit purchase' : 'Log a purchase'}</h2>

        <div className="field-row">
          <div className="field">
            <label>Item</label>
            <input type="text" value={draft.item} onChange={(e) => setF('item', e.target.value)} placeholder="Toilet paper (24-pack)" />
          </div>
          <div className="field">
            <label>Amount paid</label>
            <input type="number" min="0" step="0.01" value={draft.amount} onChange={(e) => setF('amount', e.target.value)} />
          </div>
        </div>

        <div className="field">
          <label>Mode</label>
          <div className="segment">
            <button type="button" className={draft.mode === 'shared' ? 'on' : ''} onClick={() => setF('mode', 'shared')}>Shared</button>
            <button type="button" className={draft.mode === 'individual' ? 'on' : ''} onClick={() => setF('mode', 'individual')}>Just me</button>
          </div>
        </div>

        {draft.mode === 'shared' && (
          <>
            <div className="field">
              <label>Split between</label>
              <div className="checkbox-grid">
                {housemates.map((u) => (
                  <label key={u.id}>
                    <input type="checkbox" checked={draft.participants.includes(u.id)} onChange={() => toggleP(u.id)} />
                    <Avatar user={u} size="sm" /> {u.name}
                  </label>
                ))}
              </div>
            </div>

            <div className="field">
              <label>Split method</label>
              <div className="segment">
                <button type="button" className={draft.split === 'equal' ? 'on' : ''} onClick={() => setF('split', 'equal')}>Equal</button>
                <button type="button" className={draft.split === 'custom' ? 'on' : ''} onClick={() => setF('split', 'custom')}>Custom</button>
              </div>
            </div>

            {draft.split === 'custom' && (
              <div className="field">
                <label>Per-person amount</label>
                {draft.participants.map((id) => {
                  const u = state.users.find((x) => x.id === id)
                  if (!u) return null
                  return (
                    <div key={id} className="row" style={{ marginBottom: 6 }}>
                      <Avatar user={u} size="sm" />
                      <span style={{ flex: 1 }}>{u.name}</span>
                      <input
                        type="number"
                        min="0"
                        step="0.01"
                        value={draft.custom[id] || ''}
                        onChange={(e) => setF('custom', { ...draft.custom, [id]: e.target.value })}
                        style={{ width: 100, padding: '6px 10px', border: '1px solid var(--border-strong)', borderRadius: 'var(--radius-sm)' }}
                      />
                    </div>
                  )
                })}
              </div>
            )}

            <div className="card" style={{ background: 'var(--surface-2)' }}>
              <div className="tiny muted bold mb">Preview</div>
              {Object.entries(sharesPreview).map(([id, amt]) => {
                const u = state.users.find((x) => x.id === id)
                return (
                  <div key={id} className="row" style={{ justifyContent: 'space-between' }}>
                    <span>{u?.name}</span>
                    <span className="bold">{fmtAUD(amt)}</span>
                  </div>
                )
              })}
              <hr />
              <div className="row" style={{ justifyContent: 'space-between' }}>
                <span className="bold">Split total</span>
                <span className="bold">{fmtAUD(splitTotal)}</span>
              </div>
              {Math.abs(splitTotal - total) > 0.05 && total > 0 && (
                <div className="chip warn mt">Split doesn't add up to {fmtAUD(total)}</div>
              )}
            </div>
          </>
        )}

        <div className="field">
          <label>Receipt <span className="hint">(optional)</span></label>
          <FilePicker value={draft.proof} onChange={(v) => setF('proof', v)} />
        </div>

        <div className="modal-actions">
          <button className="btn secondary" onClick={onClose}>Cancel</button>
          <button className="btn" onClick={save} disabled={!draft.item || !draft.amount}>{isEdit ? 'Save changes' : 'Log purchase'}</button>
        </div>
      </div>
    </div>
  )
}
