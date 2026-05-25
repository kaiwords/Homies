import { useState } from 'react'
import { Link, useNavigate, useLocation } from 'react-router-dom'
import { useHomies } from '../context/HomiesContext.jsx'

export function Signup() {
  const { signUpWithEmail, update } = useHomies()
  const navigate = useNavigate()
  const location = useLocation()
  const invite = location.state?.invite || null
  const [step, setStep] = useState(invite ? 'details' : 'role')
  const [role, setRole] = useState(invite?.role || null)
  const [form, setForm] = useState({
    name: '',
    email: invite?.email || '',
    phone: '',
    password: '',
  })
  const [error, setError] = useState(null)
  const [busy, setBusy] = useState(false)

  const handleChange = (k) => (e) => setForm({ ...form, [k]: e.target.value })

  const pickRole = (r) => {
    setRole(r)
    setStep('details')
  }

  const submit = async (e) => {
    e.preventDefault()
    setError(null)
    setBusy(true)
    const res = await signUpWithEmail({
      email: form.email,
      password: form.password,
      name: form.name,
      role,
      phone: form.phone,
    })
    setBusy(false)
    if (!res.ok) {
      setError(res.error)
      return
    }
    if (invite?.code) {
      update((s) => ({
        ...s,
        invites: s.invites.map((i) =>
          i.code === invite.code ? { ...i, status: 'accepted', acceptedAt: new Date().toISOString().slice(0, 10) } : i,
        ),
      }))
    }
    if (role === 'leaseholder') navigate('/onboarding/leaseholder')
    else navigate('/onboarding/tenant')
  }

  if (step === 'role') {
    return (
      <div className="auth-wrap">
        <div className="auth-card">
          <h1><span style={{ color: 'var(--accent)' }}>●</span> Create account</h1>
          <p className="auth-sub">First — what's your role in the property?</p>

          <div className="card-row" style={{ marginBottom: 18 }}>
            <RoleCard
              icon="🔑"
              title="Leaseholder"
              body="I hold the lease (alone or with co-leaseholders). I'll set up the property, invite tenants, and manage bond, bills, and rules."
              onClick={() => pickRole('leaseholder')}
            />
            <RoleCard
              icon="🛋️"
              title="Tenant"
              body="Tenants join by invite only — ask your leaseholder to send you an invite link, then open it to create your account."
              disabled
            />
          </div>

          <div className="auth-foot">
            Already have an account? <Link to="/login">Sign in</Link>
            <br />
            <Link to="/">Back</Link>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="auth-wrap">
      <div className="auth-card">
        <h1><span style={{ color: 'var(--accent)' }}>●</span> {role === 'leaseholder' ? 'Leaseholder' : 'Tenant'} signup</h1>
        <p className="auth-sub">Just the basics. You'll add property and lease details next.</p>

        {invite && (
          <div className="card mb" style={{ background: 'var(--surface-2)' }}>
            <div className="tiny muted bold">Joining by invite</div>
            <div className="tiny">
              Code <span style={{ fontFamily: 'var(--mono)' }}>{invite.code}</span> · role locked to <strong>{invite.role}</strong>
            </div>
          </div>
        )}

        <form onSubmit={submit}>
          <div className="field">
            <label>Full name</label>
            <input type="text" value={form.name} onChange={handleChange('name')} required autoComplete="name" />
          </div>

          <div className="field">
            <label>Email</label>
            <input
              type="email"
              value={form.email}
              onChange={handleChange('email')}
              required
              placeholder="you@example.com"
              autoComplete="email"
              readOnly={!!invite}
            />
            {invite && <span className="hint">Use the email the invite was sent to.</span>}
          </div>

          <div className="field">
            <label>Mobile number <span className="hint">(optional)</span></label>
            <input
              type="tel"
              value={form.phone}
              onChange={handleChange('phone')}
              placeholder="+61 4XX XXX XXX"
              autoComplete="tel"
            />
          </div>

          <div className="field">
            <label>Password</label>
            <input
              type="password"
              value={form.password}
              onChange={handleChange('password')}
              required
              minLength={6}
              autoComplete="new-password"
            />
            <span className="hint">At least 6 characters.</span>
          </div>

          {error ? (
            <div className="hint" style={{ color: 'var(--danger, #c0392b)', marginBottom: 12 }}>
              {error}
            </div>
          ) : null}

          <div className="row" style={{ justifyContent: 'space-between' }}>
            {invite ? (
              <Link className="btn ghost" to="/">← Back</Link>
            ) : (
              <button type="button" className="btn ghost" onClick={() => setStep('role')} disabled={busy}>← Change role</button>
            )}
            <button type="submit" className="btn" disabled={busy}>
              {busy ? 'Creating account…' : 'Create account →'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

function RoleCard({ icon, title, body, onClick, disabled = false }) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      style={{
        textAlign: 'left',
        background: 'var(--surface)',
        border: '1px solid var(--border)',
        borderRadius: 'var(--radius)',
        padding: 16,
        cursor: disabled ? 'not-allowed' : 'pointer',
        opacity: disabled ? 0.6 : 1,
      }}
    >
      <div style={{ fontSize: 26, marginBottom: 6 }}>{icon}</div>
      <div className="bold" style={{ marginBottom: 4 }}>
        {title} {disabled && <span className="chip">invite only</span>}
      </div>
      <div className="tiny muted">{body}</div>
    </button>
  )
}
