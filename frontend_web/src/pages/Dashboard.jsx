import { Link } from 'react-router-dom'
import { useHomies } from '../context/HomiesContext.jsx'
import { AvatarStack } from '../components/Avatar.jsx'
import { fmtAUD, fmtDate, fmtRelative } from '../lib/format.js'

export function Dashboard() {
  const { state, currentUser } = useHomies()

  const activeMates = state.users.filter((u) => !u.pending && !u.moveOutDate)
  const myBillsOwed = state.bills
    .filter((b) => b.status === 'pending' && b.shares[currentUser.id] && !b.paidBy[currentUser.id])
    .reduce((sum, b) => sum + (b.shares[currentUser.id] || 0), 0)

  const myTasks = state.cleaningTasks.filter((t) => t.assignee === currentUser.id && !t.done)
  const upcomingParties = state.parties.filter((p) => new Date(p.date) >= new Date())
  const openComplaints = state.complaints.filter((c) => c.status === 'open')
  const pendingInvites = state.invites.filter((i) => state.users.find((u) => u.email === i.email && u.pending))

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Good day, {currentUser.name.replace(/^You \(/, '').replace(/\)$/, '').split(' ')[0]} 👋</h1>
          <p>Here's what's up at home.</p>
        </div>
        <AvatarStack users={activeMates} />
      </div>

      <div className="card">
        <div className="card-row">
          <div className="stat">
            <div className="label">You owe</div>
            <div className="value">{fmtAUD(myBillsOwed)}</div>
            <div className="sub">{state.bills.filter((b) => b.status === 'pending' && !b.paidBy[currentUser.id]).length} bill(s) pending</div>
          </div>
          <div className="stat">
            <div className="label">Cleaning tasks</div>
            <div className="value">{myTasks.length}</div>
            <div className="sub">assigned to you</div>
          </div>
          <div className="stat">
            <div className="label">Housemates</div>
            <div className="value">{activeMates.length}<span className="sub" style={{ fontWeight: 400 }}> / {state.property.maxOccupants}</span></div>
            <div className="sub">{pendingInvites.length} invite(s) sent</div>
          </div>
          <div className="stat">
            <div className="label">Lease ends</div>
            <div className="value" style={{ fontSize: 16, fontWeight: 500 }}>{fmtDate(state.property.leaseEnd)}</div>
            <div className="sub">{fmtRelative(state.property.leaseEnd)}</div>
          </div>
        </div>
      </div>

      <div className="card">
        <h2>Coming up</h2>
        <ul style={{ listStyle: 'none', padding: 0, margin: 0 }}>
          {state.bills.filter((b) => b.status === 'pending').slice(0, 2).map((b) => (
            <li key={b.id} className="row" style={{ padding: '10px 0', borderTop: '1px solid var(--border)' }}>
              <span style={{ fontSize: 20 }}>💡</span>
              <div style={{ flex: 1 }}>
                <div className="bold">{b.title}</div>
                <div className="tiny muted">Due {fmtRelative(b.dueDate)} · Your share {fmtAUD(b.shares[currentUser.id] || 0)}</div>
              </div>
              <Link to="/app/bills" className="btn small secondary">Open</Link>
            </li>
          ))}
          {myTasks.slice(0, 2).map((t) => (
            <li key={t.id} className="row" style={{ padding: '10px 0', borderTop: '1px solid var(--border)' }}>
              <span style={{ fontSize: 20 }}>🧹</span>
              <div style={{ flex: 1 }}>
                <div className="bold">{t.task}</div>
                <div className="tiny muted">Due {fmtRelative(t.dueDate)}</div>
              </div>
              <Link to="/app/cleaning" className="btn small secondary">Open</Link>
            </li>
          ))}
          {upcomingParties.slice(0, 1).map((p) => (
            <li key={p.id} className="row" style={{ padding: '10px 0', borderTop: '1px solid var(--border)' }}>
              <span style={{ fontSize: 20 }}>🎉</span>
              <div style={{ flex: 1 }}>
                <div className="bold">{p.title}</div>
                <div className="tiny muted">{fmtDate(p.date)} {p.time} · {Object.values(p.responses).filter((r) => r === 'accept').length} accepted</div>
              </div>
              <Link to="/app/parties" className="btn small secondary">RSVP</Link>
            </li>
          ))}
        </ul>
      </div>

      {openComplaints.length > 0 && (
        <div className="card" style={{ borderColor: 'var(--danger-soft)' }}>
          <h2>🚩 Open complaints</h2>
          <p className="tiny muted mb">There {openComplaints.length === 1 ? 'is' : 'are'} {openComplaints.length} unresolved.</p>
          <Link to="/app/complaints" className="btn secondary small">Review</Link>
        </div>
      )}
    </>
  )
}
