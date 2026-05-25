import { useState } from 'react'
import { Navigate } from 'react-router-dom'
import { useHomies } from '../context/HomiesContext.jsx'
import { Avatar } from '../components/Avatar.jsx'
import { fmtAUD, fmtDate, fmtRelative, equalSplit } from '../lib/format.js'

export function Termination() {
  const { state, update, currentUser } = useHomies()
  if (currentUser?.role !== 'leaseholder') return <Navigate to="/app" replace />
  const isLeaseholder = true
  const housemates = state.users.filter((u) => !u.pending && !u.moveOutDate)
  const totalBond = housemates.reduce((s, u) => s + (u.bondAmount || 0), 0)

  const [draft, setDraft] = useState(() => state.termination || {
    expenses: [],
    splitMode: 'equal',
    customShares: {},
    notes: '',
  })

  const totalExpenses = draft.expenses.reduce((s, e) => s + (Number(e.amount) || 0), 0)
  const netRefund = totalBond - totalExpenses

  const shares = (() => {
    if (draft.splitMode === 'equal') {
      const arr = equalSplit(netRefund, housemates.length)
      return housemates.reduce((acc, u, i) => ({ ...acc, [u.id]: arr[i] }), {})
    }
    return housemates.reduce((acc, u) => ({ ...acc, [u.id]: Number(draft.customShares[u.id] || 0) }), {})
  })()

  const addExpense = () => setDraft({ ...draft, expenses: [...draft.expenses, { id: 'e-' + Math.random().toString(36).slice(2, 6), reason: '', amount: '' }] })
  const updateExpense = (i, k, v) => setDraft({ ...draft, expenses: draft.expenses.map((e, idx) => idx === i ? { ...e, [k]: v } : e) })
  const removeExpense = (i) => setDraft({ ...draft, expenses: draft.expenses.filter((_, idx) => idx !== i) })

  const save = () => update((s) => ({ ...s, termination: draft }))

  return (
    <>
      <div className="page-head">
        <div>
          <h1>End of lease</h1>
          <p>Final cleanup, fix-up expenses, and how the combined bond gets split.</p>
        </div>
        {isLeaseholder && <button className="btn" onClick={save}>Save plan</button>}
      </div>

      <div className="card">
        <h2>Lease wrap-up</h2>
        <div className="card-row">
          <div className="stat">
            <div className="label">Lease end</div>
            <div className="value" style={{ fontSize: 16 }}>{fmtDate(state.property.leaseEnd)}</div>
            <div className="sub">{fmtRelative(state.property.leaseEnd)}</div>
          </div>
          <div className="stat">
            <div className="label">Housemates at end</div>
            <div className="value">{housemates.length}</div>
            <div className="sub">share the bond if all stayed</div>
          </div>
          <div className="stat">
            <div className="label">Combined bond</div>
            <div className="value">{fmtAUD(totalBond)}</div>
          </div>
        </div>
      </div>

      <div className="card">
        <h2>Property expenses to fix</h2>
        <p className="tiny muted mb">Cleaning, repairs, damage — anything coming out of the bond.</p>

        {draft.expenses.map((e, i) => (
          <div key={e.id} className="row mb">
            <input type="text" value={e.reason} onChange={(ev) => updateExpense(i, 'reason', ev.target.value)} placeholder="Carpet steam clean, oven repair…" disabled={!isLeaseholder} style={{ flex: 1, padding: '8px 10px', border: '1px solid var(--border-strong)', borderRadius: 'var(--radius-sm)' }} />
            <input type="number" value={e.amount} onChange={(ev) => updateExpense(i, 'amount', ev.target.value)} placeholder="$" disabled={!isLeaseholder} style={{ width: 110, padding: '8px 10px', border: '1px solid var(--border-strong)', borderRadius: 'var(--radius-sm)' }} />
            {isLeaseholder && <button className="btn ghost small" onClick={() => removeExpense(i)}>×</button>}
          </div>
        ))}

        {isLeaseholder && <button className="btn secondary" onClick={addExpense}>+ Add expense</button>}

        <hr />
        <div className="row" style={{ justifyContent: 'space-between' }}>
          <span>Combined bond</span><span className="bold">{fmtAUD(totalBond)}</span>
        </div>
        <div className="row" style={{ justifyContent: 'space-between' }}>
          <span>Less expenses</span><span className="bold">−{fmtAUD(totalExpenses)}</span>
        </div>
        <hr />
        <div className="row" style={{ justifyContent: 'space-between' }}>
          <span className="bold">Net refund to split</span><span className="bold" style={{ color: 'var(--accent)' }}>{fmtAUD(netRefund)}</span>
        </div>
      </div>

      <div className="card">
        <h2>Refund split</h2>
        <p className="tiny muted mb">
          If everyone stayed until the lease ended, split equally. Otherwise the leaseholder can set custom amounts (per the original spec).
        </p>

        {isLeaseholder && (
          <div className="segment mb">
            <button type="button" className={draft.splitMode === 'equal' ? 'on' : ''} onClick={() => setDraft({ ...draft, splitMode: 'equal' })}>Equal</button>
            <button type="button" className={draft.splitMode === 'custom' ? 'on' : ''} onClick={() => setDraft({ ...draft, splitMode: 'custom' })}>Custom</button>
          </div>
        )}

        {housemates.map((u) => (
          <div key={u.id} className="row" style={{ padding: '8px 0' }}>
            <Avatar user={u} size="sm" />
            <span style={{ flex: 1 }} className="tiny">{u.name}</span>
            {draft.splitMode === 'custom' && isLeaseholder ? (
              <input
                type="number"
                value={draft.customShares[u.id] || ''}
                onChange={(e) => setDraft({ ...draft, customShares: { ...draft.customShares, [u.id]: e.target.value } })}
                style={{ width: 110, padding: '6px 10px', border: '1px solid var(--border-strong)', borderRadius: 'var(--radius-sm)' }}
              />
            ) : (
              <span className="bold tiny">{fmtAUD(shares[u.id] || 0)}</span>
            )}
          </div>
        ))}
      </div>

      <div className="card">
        <h2>Notes</h2>
        <textarea
          rows={4}
          value={draft.notes}
          onChange={(e) => setDraft({ ...draft, notes: e.target.value })}
          disabled={!isLeaseholder}
          placeholder="Anything else to record — agent timeline, key handover, forwarding addresses."
          style={{ width: '100%', padding: '10px 12px', border: '1px solid var(--border-strong)', borderRadius: 'var(--radius-sm)' }}
        />
      </div>
    </>
  )
}
