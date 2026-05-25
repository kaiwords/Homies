import { useState } from 'react'
import { useHomies } from '../context/HomiesContext.jsx'
import { Avatar } from '../components/Avatar.jsx'
import { fmtAUD, fmtDate, fmtRelative } from '../lib/format.js'

export function Leaving() {
  const { state, update, currentUser } = useHomies()
  const isLeaseholder = currentUser.role === 'leaseholder'

  const myNotice = state.notices.find((n) => n.userId === currentUser.id)
  const minLeaveDate = new Date()
  minLeaveDate.setDate(minLeaveDate.getDate() + 14)
  const minLeaveDateIso = minLeaveDate.toISOString().slice(0, 10)

  const [leaveDate, setLeaveDate] = useState(minLeaveDateIso)
  const [reason, setReason] = useState('')

  const giveNotice = () => {
    update((s) => ({
      ...s,
      notices: [...s.notices.filter((n) => n.userId !== currentUser.id), {
        id: 'nt-' + Math.random().toString(36).slice(2, 6),
        userId: currentUser.id,
        givenAt: new Date().toISOString().slice(0, 10),
        leaveDate,
        reason,
        bondReturn: 'after-agent',
        deductions: [],
        deductionExplanation: '',
        tenantAgreed: null,
      }],
    }))
  }

  const cancelNotice = () => {
    update((s) => ({ ...s, notices: s.notices.filter((n) => n.userId !== currentUser.id) }))
  }

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Leaving the house</h1>
          <p>Give 2 weeks' notice. Bond returns once the leaseholder or agent has confirmed the inspection.</p>
        </div>
      </div>

      {!myNotice && (
        <div className="card">
          <h2>Give notice</h2>
          <p className="muted tiny mb">Earliest leave date is 14 days from today: <strong>{fmtDate(minLeaveDateIso)}</strong>.</p>

          <div className="field-row">
            <div className="field">
              <label>Leaving date</label>
              <input type="date" min={minLeaveDateIso} value={leaveDate} onChange={(e) => setLeaveDate(e.target.value)} />
            </div>
          </div>

          <div className="field">
            <label>Reason (optional)</label>
            <textarea rows={3} value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Moving cities, new job, etc." />
          </div>

          <button className="btn" onClick={giveNotice} disabled={new Date(leaveDate) < minLeaveDate}>Give notice</button>
        </div>
      )}

      {myNotice && <NoticeCard notice={myNotice} onCancel={cancelNotice} />}

      {isLeaseholder && state.notices.filter((n) => n.userId !== currentUser.id).length > 0 && (
        <div className="card">
          <h2>Housemates on notice</h2>
          {state.notices.filter((n) => n.userId !== currentUser.id).map((n) => (
            <NoticeAdminRow key={n.id} notice={n} />
          ))}
        </div>
      )}
    </>
  )
}

function NoticeCard({ notice, onCancel }) {
  return (
    <div className="card">
      <h2>You've given notice</h2>
      <div className="row" style={{ marginBottom: 8 }}>
        <span className="chip warn">leaving {fmtRelative(notice.leaveDate)}</span>
      </div>
      <p>Final day: <strong>{fmtDate(notice.leaveDate)}</strong>. Notice given on {fmtDate(notice.givenAt)}.</p>
      {notice.reason && <p className="muted tiny">Reason: "{notice.reason}"</p>}

      <hr />

      <h3>Bond return</h3>
      <p className="tiny muted">
        Leaseholder has set: <strong>{notice.bondReturn === 'now' ? 'release immediately' : 'release after agent inspection'}</strong>.
      </p>
      {notice.deductions.length > 0 && (
        <>
          <div className="bold tiny mt">Proposed deductions</div>
          {notice.deductions.map((d, i) => (
            <div key={i} className="row" style={{ padding: '4px 0' }}>
              <span className="tiny" style={{ flex: 1 }}>{d.reason}</span>
              <span className="tiny bold">{fmtAUD(d.amount)}</span>
            </div>
          ))}
          {notice.deductionExplanation && <p className="tiny muted">{notice.deductionExplanation}</p>}
          {notice.tenantAgreed === null && <div className="row mt"><button className="btn small">Agree to deductions</button><button className="btn small secondary">Dispute</button></div>}
        </>
      )}

      <hr />
      <button className="btn ghost small" onClick={onCancel} style={{ color: 'var(--danger)' }}>Cancel notice</button>
    </div>
  )
}

function NoticeAdminRow({ notice }) {
  const { state, update } = useHomies()
  const user = state.users.find((u) => u.id === notice.userId)
  const [showDeductions, setShowDeductions] = useState(false)
  const [deductions, setDeductions] = useState(notice.deductions)
  const [explanation, setExplanation] = useState(notice.deductionExplanation || '')
  const [bondMode, setBondMode] = useState(notice.bondReturn)

  const addDeduction = () => setDeductions([...deductions, { reason: '', amount: '' }])
  const updateDeduction = (i, k, v) => setDeductions(deductions.map((d, idx) => idx === i ? { ...d, [k]: v } : d))

  const save = () => {
    update((s) => ({
      ...s,
      notices: s.notices.map((n) => n.userId === notice.userId ? {
        ...n,
        bondReturn: bondMode,
        deductions: deductions.filter((d) => d.reason && d.amount).map((d) => ({ ...d, amount: Number(d.amount) })),
        deductionExplanation: explanation,
      } : n),
    }))
    setShowDeductions(false)
  }

  const totalDeduction = deductions.reduce((s, d) => s + (Number(d.amount) || 0), 0)
  const refund = (user?.bondAmount || 0) - totalDeduction

  return (
    <div className="card" style={{ background: 'var(--surface-2)', marginTop: 12 }}>
      <div className="row" style={{ alignItems: 'flex-start' }}>
        <Avatar user={user} />
        <div style={{ flex: 1 }}>
          <div className="bold">{user?.name}</div>
          <div className="tiny muted">Leaves {fmtDate(notice.leaveDate)} ({fmtRelative(notice.leaveDate)}) · bond {fmtAUD(user?.bondAmount || 0)}</div>
        </div>
        <button className="btn small secondary" onClick={() => setShowDeductions(!showDeductions)}>
          {showDeductions ? 'Close' : 'Manage bond'}
        </button>
      </div>

      {showDeductions && (
        <>
          <hr />
          <div className="field">
            <label>When to release bond</label>
            <div className="segment">
              <button type="button" className={bondMode === 'now' ? 'on' : ''} onClick={() => setBondMode('now')}>Release now</button>
              <button type="button" className={bondMode === 'after-agent' ? 'on' : ''} onClick={() => setBondMode('after-agent')}>After agent inspection</button>
            </div>
          </div>

          <div className="field">
            <label>Deductions (if any)</label>
            {deductions.map((d, i) => (
              <div key={i} className="row mb">
                <input type="text" value={d.reason} placeholder="Reason (cleaning, damage…)" onChange={(e) => updateDeduction(i, 'reason', e.target.value)} style={{ flex: 1, padding: '8px 10px', border: '1px solid var(--border-strong)', borderRadius: 'var(--radius-sm)' }} />
                <input type="number" value={d.amount} placeholder="$" onChange={(e) => updateDeduction(i, 'amount', e.target.value)} style={{ width: 100, padding: '8px 10px', border: '1px solid var(--border-strong)', borderRadius: 'var(--radius-sm)' }} />
              </div>
            ))}
            <button className="btn ghost small" onClick={addDeduction}>+ Add deduction</button>
          </div>

          {deductions.length > 0 && (
            <div className="field">
              <label>Explanation (required if cutting bond)</label>
              <textarea rows={3} value={explanation} onChange={(e) => setExplanation(e.target.value)} placeholder="Why these deductions? Tenant must agree." />
            </div>
          )}

          <div className="card" style={{ background: 'var(--surface)' }}>
            <div className="row" style={{ justifyContent: 'space-between' }}>
              <span>Bond paid</span><span className="bold">{fmtAUD(user?.bondAmount || 0)}</span>
            </div>
            <div className="row" style={{ justifyContent: 'space-between' }}>
              <span>Deductions</span><span className="bold">−{fmtAUD(totalDeduction)}</span>
            </div>
            <hr />
            <div className="row" style={{ justifyContent: 'space-between' }}>
              <span className="bold">Refund</span><span className="bold" style={{ color: 'var(--accent)' }}>{fmtAUD(refund)}</span>
            </div>
          </div>

          <div className="modal-actions">
            <button className="btn" onClick={save}>Save bond plan</button>
          </div>
        </>
      )}
    </div>
  )
}
