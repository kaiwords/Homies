import { useState } from 'react'
import { useHomies } from '../context/HomiesContext.jsx'
import { Avatar } from '../components/Avatar.jsx'
import { fmtDate } from '../lib/format.js'

const THRESHOLD = 100

export function Complaints() {
  const { state, update, currentUser } = useHomies()
  const [showNew, setShowNew] = useState(false)

  const resolve = (id, action) => {
    update((s) => ({
      ...s,
      complaints: s.complaints.map((c) => c.id === id ? { ...c, status: action } : c),
    }))
  }

  const housemates = state.users.filter((u) => !u.pending)
  const totalsByUser = housemates.reduce((acc, u) => {
    acc[u.id] = state.complaints.filter((c) => c.against === u.id).reduce((sum, c) => sum + (c.severity || 1), 0)
    return acc
  }, {})

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Complaints</h1>
          <p>Raise an issue against a housemate. Threshold for serious action is {THRESHOLD} points (leaseholder can change).</p>
        </div>
        <button className="btn" onClick={() => setShowNew(true)}>+ New complaint</button>
      </div>

      <div className="card">
        <h2>Complaint score</h2>
        <p className="tiny muted mb">Sum of severity points for each housemate.</p>
        {housemates.map((u) => {
          const score = totalsByUser[u.id] || 0
          const pct = Math.min(100, (score / THRESHOLD) * 100)
          return (
            <div key={u.id} className="row" style={{ padding: '8px 0' }}>
              <Avatar user={u} size="sm" />
              <span className="tiny" style={{ width: 140 }}>{u.name}</span>
              <div style={{ flex: 1, height: 8, background: 'var(--surface-2)', borderRadius: 4, overflow: 'hidden' }}>
                <div style={{ width: `${pct}%`, height: '100%', background: score >= THRESHOLD ? 'var(--danger)' : score >= THRESHOLD * 0.5 ? 'var(--warn)' : 'var(--ok)' }} />
              </div>
              <span className="tiny bold" style={{ width: 60, textAlign: 'right' }}>{score} / {THRESHOLD}</span>
            </div>
          )
        })}
      </div>

      <div className="card">
        <h2>Open complaints</h2>
        {state.complaints.length === 0 && <p className="muted tiny">No complaints. Nice house.</p>}
        {state.complaints.map((c) => {
          const against = state.users.find((u) => u.id === c.against)
          const from = state.users.find((u) => u.id === c.from)
          return (
            <div key={c.id} className="card" style={{ background: 'var(--surface-2)', marginTop: 12 }}>
              <div className="row" style={{ alignItems: 'flex-start' }}>
                <div style={{ flex: 1 }}>
                  <div className="row">
                    <span className="bold">Against {against?.name}</span>
                    <span className={'chip ' + (c.status === 'open' ? 'warn' : 'ok')}>{c.status}</span>
                    <span className="chip">severity {c.severity}</span>
                  </div>
                  <div className="tiny muted">From {from?.name} · {fmtDate(c.date)}</div>
                  <p className="mt">{c.reason}</p>
                </div>
              </div>
              {c.status === 'open' && currentUser.role === 'leaseholder' && (
                <div className="row mt">
                  <button className="btn small secondary" onClick={() => resolve(c.id, 'ignored')}>Ignore</button>
                  <button className="btn small" onClick={() => resolve(c.id, 'actioned')}>Action taken</button>
                </div>
              )}
            </div>
          )
        })}
      </div>

      {showNew && <NewComplaintModal onClose={() => setShowNew(false)} />}
    </>
  )
}

function NewComplaintModal({ onClose }) {
  const { state, update, currentUser } = useHomies()
  const others = state.users.filter((u) => !u.pending && u.id !== currentUser.id)
  const [draft, setDraft] = useState({ against: others[0]?.id || '', severity: 5, reason: '' })

  const save = () => {
    update((s) => ({
      ...s,
      complaints: [{
        id: 'co-' + Math.random().toString(36).slice(2, 6),
        against: draft.against,
        from: currentUser.id,
        reason: draft.reason,
        severity: Number(draft.severity),
        date: new Date().toISOString().slice(0, 10),
        status: 'open',
      }, ...s.complaints],
    }))
    onClose()
  }

  return (
    <div className="modal-bg" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <h2>Lodge a complaint</h2>
        <p className="muted tiny mb">Keep it factual. Severity reflects how serious you think it is — 1 (minor) to 50 (major).</p>

        <div className="field">
          <label>Against</label>
          <select value={draft.against} onChange={(e) => setDraft({ ...draft, against: e.target.value })}>
            {others.map((u) => <option key={u.id} value={u.id}>{u.name}</option>)}
          </select>
        </div>

        <div className="field">
          <label>What happened?</label>
          <textarea rows={3} value={draft.reason} onChange={(e) => setDraft({ ...draft, reason: e.target.value })} placeholder="Be specific — when, where, what." />
        </div>

        <div className="field">
          <label>Severity: {draft.severity}</label>
          <input type="range" min="1" max="50" value={draft.severity} onChange={(e) => setDraft({ ...draft, severity: e.target.value })} />
        </div>

        <div className="modal-actions">
          <button className="btn secondary" onClick={onClose}>Cancel</button>
          <button className="btn danger" onClick={save} disabled={!draft.reason.trim()}>Submit</button>
        </div>
      </div>
    </div>
  )
}
