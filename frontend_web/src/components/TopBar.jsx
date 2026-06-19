import { useNavigate } from 'react-router-dom'
import { useHomies } from '../context/HomiesContext.jsx'
import { Avatar } from './Avatar.jsx'

export function TopBar() {
  const { state, currentUser, signOut } = useHomies()
  const navigate = useNavigate()
  const handleSignOut = () => {
    signOut()
    navigate('/login')
  }

  return (
    <div className="topbar">
      <div>
        <div className="property-name">{state.property.address}</div>
        <div className="property-meta">
          {state.property.bedrooms}-bed · {state.users.filter((u) => !u.pending && !u.moveOutDate).length} living here · agent {state.property.agent}
        </div>
      </div>
      <div className="me">
        {currentUser ? (
          <>
            <Avatar user={currentUser} />
            <div style={{ fontSize: 13, lineHeight: 1.2 }}>
              <div className="bold">{currentUser.name.replace(/^You \(/, '').replace(/\)$/, '')}</div>
              <div className="faint tiny">{currentUser.role}</div>
            </div>
            <button className="btn ghost small" onClick={handleSignOut}>Sign out</button>
          </>
        ) : null}
      </div>
    </div>
  )
}
