import { useState } from 'react'
import { useHomies } from '../context/HomiesContext.jsx'
import { Avatar } from '../components/Avatar.jsx'
import { FilePicker, Attachment } from '../components/FilePicker.jsx'
import { MarkPaidModal } from '../components/MarkPaidModal.jsx'
import { fmtAUD, equalSplit } from '../lib/format.js'

export function Subscriptions() {
  const { state, update, currentUser } = useHomies()
  const [editing, setEditing] = useState(null)
  const [paying, setPaying] = useState(null)

  const remove = (id) => {
    if (!confirm('Remove this subscription?')) return
    update((s) => ({ ...s, subscriptions: s.subscriptions.filter((x) => x.id !== id) }))
  }

  const togglePaid = (sub, uid, proof) => {
    update((s) => ({
      ...s,
      subscriptions: s.subscriptions.map((x) => {
        if (x.id !== sub.id) return x
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
          <h1>Subscriptions</h1>
          <p>Recurring services — Netflix, Spotify, gym, anything shared.</p>
        </div>
        <button className="btn" onClick={() => setEditing({})}>+ Add subscription</button>
      </div>

      {state.subscriptions.length === 0 && <div className="empty"><h3>No subscriptions yet</h3></div>}

      {state.subscriptions.map((sub) => {
        const payer = state.users.find((u) => u.id === sub.payer)
        const isCreator = (sub.addedBy || sub.payer) === currentUser.id
        return (
          <div className="card" key={sub.id}>
            <div className="row" style={{ alignItems: 'flex-start' }}>
              <div style={{ flex: 1 }}>
                <div className="bold">{sub.name}</div>
                <div className="tiny muted">
                  {fmtAUD(sub.amount)} / {sub.cadence} · paid by {payer?.name || '—'}
                </div>
              </div>
              {isCreator && (
                <>
                  <button className="btn secondary small" onClick={() => setEditing(sub)}>Edit</button>
                  <button className="btn ghost small" onClick={() => remove(sub.id)}>Remove</button>
                </>
              )}
            </div>

            {sub.proof && (
              <div style={{ marginTop: 6 }}>
                <div className="tiny muted bold">Subscription receipt</div>
                <Attachment value={sub.proof} compact />
              </div>
            )}

            <hr />
            {sub.participants.map((uid) => {
              const u = state.users.find((x) => x.id === uid)
              if (!u) return null
              const paid = !!(sub.paidBy && sub.paidBy[uid])
              const proof = sub.paidByProof?.[uid] || null
              const isYou = uid === currentUser.id
              const isPayer = uid === sub.payer
              return (
                <div key={uid} className="row" style={{ padding: '6px 0' }}>
                  <Avatar user={u} size="sm" />
                  <div style={{ flex: 1 }}>
                    <div className="bold tiny">{u.name}{isYou ? ' (you)' : ''}{isPayer ? ' — payer' : ''}</div>
                    <div className="tiny muted">{fmtAUD(sub.shares[uid] || 0)}</div>
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
                      onClick={() => paid ? togglePaid(sub, uid) : setPaying({ sub, uid })}
                      disabled={!isYou && !isCreator}
                    >
                      {paid ? '✓ Paid' : 'Mark paid'}
                    </button>
                  )}
                </div>
              )
            })}
          </div>
        )
      })}

      {editing && <SubModal existing={editing.id ? editing : null} onClose={() => setEditing(null)} />}

      {paying && (
        <MarkPaidModal
          title={`Mark "${paying.sub.name}" as paid`}
          amountLabel={`Your share: ${fmtAUD(paying.sub.shares?.[paying.uid] || 0)}`}
          onConfirm={(proof) => {
            togglePaid(paying.sub, paying.uid, proof)
            setPaying(null)
          }}
          onClose={() => setPaying(null)}
        />
      )}
    </>
  )
}

function SubModal({ onClose, existing }) {
  const { state, update, currentUser } = useHomies()
  const housemates = state.users.filter((u) => !u.pending && !u.moveOutDate)
  const isEdit = !!existing
  const [draft, setDraft] = useState(isEdit ? {
    name: existing.name || '',
    amount: String(existing.amount ?? ''),
    cadence: existing.cadence || 'monthly',
    payer: existing.payer || currentUser.id,
    participants: existing.participants || housemates.map((u) => u.id),
    proof: existing.proof || null,
  } : {
    name: '',
    amount: '',
    cadence: 'monthly',
    payer: currentUser.id,
    participants: housemates.map((u) => u.id),
    proof: null,
  })

  const setF = (k, v) => setDraft((d) => ({ ...d, [k]: v }))
  const toggleP = (id) => setF('participants', draft.participants.includes(id) ? draft.participants.filter((x) => x !== id) : [...draft.participants, id])

  const total = Number(draft.amount) || 0
  const arr = equalSplit(total, draft.participants.length)
  const shares = draft.participants.reduce((acc, id, i) => ({ ...acc, [id]: arr[i] }), {})

  const save = () => {
    update((s) => {
      if (isEdit) {
        const newShareUids = draft.participants
        const paidBy = Object.fromEntries(Object.entries(existing.paidBy || {}).filter(([uid]) => newShareUids.includes(uid)))
        const paidByProof = Object.fromEntries(Object.entries(existing.paidByProof || {}).filter(([uid]) => newShareUids.includes(uid)))
        return {
          ...s,
          subscriptions: s.subscriptions.map((x) => x.id === existing.id ? {
            ...x,
            name: draft.name,
            amount: total,
            cadence: draft.cadence,
            payer: draft.payer,
            participants: draft.participants,
            shares,
            paidBy,
            paidByProof,
            proof: draft.proof,
          } : x),
        }
      }
      return {
        ...s,
        subscriptions: [...s.subscriptions, {
          id: 's-' + Math.random().toString(36).slice(2, 6),
          name: draft.name,
          amount: total,
          cadence: draft.cadence,
          payer: draft.payer,
          addedBy: currentUser.id,
          participants: draft.participants,
          split: 'equal',
          shares,
          paidBy: {},
          paidByProof: {},
          proof: draft.proof,
        }],
      }
    })
    onClose()
  }

  return (
    <div className="modal-bg" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <h2>{isEdit ? 'Edit subscription' : 'Add subscription'}</h2>

        <div className="field">
          <label>Name</label>
          <input type="text" value={draft.name} onChange={(e) => setF('name', e.target.value)} placeholder="Netflix Premium" />
        </div>

        <div className="field-row">
          <div className="field">
            <label>Amount</label>
            <input type="number" min="0" step="0.01" value={draft.amount} onChange={(e) => setF('amount', e.target.value)} />
          </div>
          <div className="field">
            <label>Cadence</label>
            <select value={draft.cadence} onChange={(e) => setF('cadence', e.target.value)}>
              <option value="weekly">Weekly</option>
              <option value="fortnightly">Fortnightly</option>
              <option value="monthly">Monthly</option>
              <option value="yearly">Yearly</option>
            </select>
          </div>
        </div>

        <div className="field">
          <label>Paid by</label>
          <select value={draft.payer} onChange={(e) => setF('payer', e.target.value)}>
            {housemates.map((u) => <option key={u.id} value={u.id}>{u.name}</option>)}
          </select>
        </div>

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
          <span className="hint">Anyone not ticked is excluded — useful when a housemate doesn't use the service.</span>
        </div>

        <div className="field">
          <label>Subscription receipt <span className="hint">(optional)</span></label>
          <FilePicker value={draft.proof} onChange={(v) => setF('proof', v)} />
        </div>

        <div className="modal-actions">
          <button className="btn secondary" onClick={onClose}>Cancel</button>
          <button className="btn" onClick={save} disabled={!draft.name || !draft.amount || draft.participants.length === 0}>{isEdit ? 'Save changes' : 'Add'}</button>
        </div>
      </div>
    </div>
  )
}
