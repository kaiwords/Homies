import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useHomies } from '../context/HomiesContext.jsx'

export function Login() {
  const { signInWithEmail } = useHomies()
  const navigate = useNavigate()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState(null)
  const [busy, setBusy] = useState(false)

  const submit = async (e) => {
    e.preventDefault()
    setError(null)
    setBusy(true)
    const res = await signInWithEmail({ email, password })
    setBusy(false)
    if (res.ok) {
      navigate('/app')
    } else {
      setError(res.error)
    }
  }

  return (
    <div className="auth-wrap">
      <div className="auth-card">
        <h1><span style={{ color: 'var(--accent)' }}>●</span> Sign in</h1>
        <p className="auth-sub">Welcome back. Sign in with your email and password.</p>

        <form onSubmit={submit}>
          <div className="field">
            <label>Email address</label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="you@example.com"
              required
              autoFocus
              autoComplete="email"
            />
          </div>

          <div className="field">
            <label>Password</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              autoComplete="current-password"
            />
          </div>

          {error ? (
            <div className="hint" style={{ color: 'var(--danger, #c0392b)', marginBottom: 12 }}>
              {error}
            </div>
          ) : null}

          <button
            className="btn"
            type="submit"
            disabled={busy || !email || !password}
            style={{ width: '100%' }}
          >
            {busy ? 'Signing in…' : 'Sign in'}
          </button>
        </form>

        <div className="auth-foot">
          New here? <Link to="/signup">Create an account</Link>
          <br />
          Just exploring? <Link to="/demo">Try a demo account</Link>
          <br />
          <Link to="/">Back</Link>
        </div>
      </div>
    </div>
  )
}
