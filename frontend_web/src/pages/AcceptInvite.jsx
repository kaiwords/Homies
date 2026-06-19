import { useParams, useNavigate, Link } from 'react-router-dom'
import { useHomies } from '../context/HomiesContext.jsx'

export function AcceptInvite() {
  const { code } = useParams()
  const { state } = useHomies()
  const navigate = useNavigate()
  const invite = state.invites.find((i) => i.code === code)

  const accept = () => {
    navigate('/signup', {
      state: { invite: { code: invite.code, email: invite.email, role: invite.role } },
    })
  }

  return (
    <div className="auth-wrap">
      <div className="auth-card">
        <h1>You've been invited 🎉</h1>
        {invite ? (
          <>
            <p className="auth-sub">
              You've been invited to join <strong>{state.property.address || 'a sharehouse'}</strong> as a <strong>{invite.role}</strong>.
            </p>
            <div className="card mb" style={{ background: 'var(--surface-2)' }}>
              <div className="row" style={{ justifyContent: 'space-between' }}>
                <div className="muted tiny">Invite code</div>
                <div style={{ fontFamily: 'var(--mono)' }}>{invite.code}</div>
              </div>
              <div className="row" style={{ justifyContent: 'space-between', marginTop: 6 }}>
                <div className="muted tiny">Sent to</div>
                <div>{invite.email}</div>
              </div>
            </div>
            <button className="btn" style={{ width: '100%' }} onClick={accept}>
              Accept &amp; create account
            </button>
          </>
        ) : (
          <p className="auth-sub">That invite code isn't recognised. Ask the leaseholder for a fresh link.</p>
        )}
        <div className="auth-foot">
          <Link to="/">Back to home</Link>
        </div>
      </div>
    </div>
  )
}
