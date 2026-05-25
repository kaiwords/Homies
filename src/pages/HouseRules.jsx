import { useState } from 'react'
import { useHomies } from '../context/HomiesContext.jsx'
import { fmtDate } from '../lib/format.js'

export function HouseRules() {
  const { state, update, currentUser } = useHomies()
  const isLeaseholder = currentUser.role === 'leaseholder'
  const [newRule, setNewRule] = useState('')
  const [editingId, setEditingId] = useState(null)
  const [editText, setEditText] = useState('')

  const addRule = () => {
    if (!newRule.trim()) return
    update((s) => ({
      ...s,
      houseRules: [...s.houseRules, {
        id: 'r-' + Math.random().toString(36).slice(2, 6),
        text: newRule.trim(),
        addedBy: currentUser.id,
        addedAt: new Date().toISOString().slice(0, 10),
      }],
    }))
    setNewRule('')
  }

  const removeRule = (id) => {
    if (!confirm('Remove this rule?')) return
    update((s) => ({ ...s, houseRules: s.houseRules.filter((r) => r.id !== id) }))
  }

  const startEdit = (rule) => {
    setEditingId(rule.id)
    setEditText(rule.text)
  }
  const cancelEdit = () => {
    setEditingId(null)
    setEditText('')
  }
  const saveEdit = () => {
    if (!editText.trim()) return
    update((s) => ({
      ...s,
      houseRules: s.houseRules.map((r) => r.id === editingId ? { ...r, text: editText.trim() } : r),
    }))
    cancelEdit()
  }

  return (
    <>
      <div className="page-head">
        <div>
          <h1>House rules</h1>
          <p>Tenants must accept these on join. Leaseholder can edit anytime.</p>
        </div>
      </div>

      {!isLeaseholder && (
        <div className="placeholder-banner">
          You accepted these on {fmtDate(currentUser.acceptedRulesAt)}. Only the leaseholder can edit.
        </div>
      )}

      {isLeaseholder && (
        <div className="card">
          <h2>Add a rule</h2>
          <div className="row">
            <input
              type="text"
              value={newRule}
              onChange={(e) => setNewRule(e.target.value)}
              placeholder="E.g. No smoking inside, vaping on balcony only"
              style={{ flex: 1, padding: '10px 12px', border: '1px solid var(--border-strong)', borderRadius: 'var(--radius-sm)' }}
              onKeyDown={(e) => e.key === 'Enter' && addRule()}
            />
            <button className="btn" onClick={addRule}>Add</button>
          </div>
          <span className="hint">Common topics: smoking, vaping, alcohol, parties, guests, quiet hours, pets.</span>
        </div>
      )}

      <div className="card">
        <h2>Current rules</h2>
        {state.houseRules.length === 0 && <p className="muted tiny">No rules yet.</p>}
        {state.houseRules.map((r, i) => {
          const author = state.users.find((u) => u.id === r.addedBy)
          const isEditingThis = editingId === r.id
          return (
            <div key={r.id} className="row" style={{ padding: '12px 0', borderTop: i === 0 ? 'none' : '1px solid var(--border)', alignItems: 'flex-start' }}>
              <div style={{ width: 24, color: 'var(--text-faint)' }}>{i + 1}.</div>
              <div style={{ flex: 1 }}>
                {isEditingThis ? (
                  <input
                    type="text"
                    value={editText}
                    onChange={(e) => setEditText(e.target.value)}
                    onKeyDown={(e) => { if (e.key === 'Enter') saveEdit(); if (e.key === 'Escape') cancelEdit() }}
                    autoFocus
                    style={{ width: '100%', padding: '8px 10px', border: '1px solid var(--border-strong)', borderRadius: 'var(--radius-sm)' }}
                  />
                ) : (
                  <div>{r.text}</div>
                )}
                <div className="tiny muted">Added by {author?.name || '—'} · {fmtDate(r.addedAt)}</div>
              </div>
              {isLeaseholder && (
                isEditingThis ? (
                  <div className="row">
                    <button className="btn ghost small" onClick={cancelEdit}>Cancel</button>
                    <button className="btn small" onClick={saveEdit} disabled={!editText.trim()}>Save</button>
                  </div>
                ) : (
                  <div className="row">
                    <button className="btn ghost small" onClick={() => removeRule(r.id)}>Remove</button>
                    <button className="btn secondary small" onClick={() => startEdit(r)}>Edit</button>
                  </div>
                )
              )}
            </div>
          )
        })}
      </div>
    </>
  )
}
