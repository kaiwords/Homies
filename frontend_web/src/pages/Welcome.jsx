import { Link } from 'react-router-dom'

export function Welcome() {
  return (
    <div className="auth-wrap">
      <div className="auth-card" style={{ maxWidth: 540 }}>
        <h1><span style={{ color: 'var(--accent)' }}>●</span> homies</h1>
        <p className="auth-sub">
          Run a sharehouse without the spreadsheets. Bills, bond, chores, parties, complaints — one place, fair splits, less drama.
        </p>

        <div className="card-row" style={{ marginBottom: 20 }}>
          <Feature icon="💡" title="Bills & bond" body="Split utilities, track who paid, prorate by move-in date." />
          <Feature icon="🧹" title="Chores" body="Roster, photo proof, excuses with a paper trail." />
          <Feature icon="🚪" title="Move out, cleanly" body="2-week notice, bond release, deductions explained." />
        </div>

        <div className="row" style={{ gap: 10 }}>
          <Link className="btn" to="/signup">Create account</Link>
          <Link className="btn secondary" to="/login">Sign in</Link>
        </div>
      </div>
    </div>
  )
}

function Feature({ icon, title, body }) {
  return (
    <div className="card" style={{ background: 'var(--surface-2)' }}>
      <div style={{ fontSize: 22, marginBottom: 6 }}>{icon}</div>
      <div className="bold">{title}</div>
      <div className="tiny muted">{body}</div>
    </div>
  )
}
