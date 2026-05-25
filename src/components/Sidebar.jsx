import { NavLink } from 'react-router-dom'
import { SECTIONS } from '../data/mockData.js'
import { useHomies } from '../context/HomiesContext.jsx'

export function Sidebar() {
  const { state, currentUser } = useHomies()
  const pendingComplaints = state.complaints.filter((c) => c.status === 'open').length
  const pendingTasks = state.cleaningTasks.filter((t) => !t.done && !t.excuse).length
  const isLeaseholder = currentUser?.role === 'leaseholder'

  const badgeFor = (key) => {
    if (key === 'complaints' && pendingComplaints) return pendingComplaints
    if (key === 'cleaning' && pendingTasks) return pendingTasks
    return null
  }

  const primary = SECTIONS.filter((s) => ['dashboard', 'property', 'housemates'].includes(s.key))
  const money = SECTIONS.filter((s) => ['bills', 'subscriptions', 'groceries', 'necessities'].includes(s.key))
  const living = SECTIONS.filter((s) => ['cleaning', 'rules', 'parties', 'messages', 'issues', 'complaints'].includes(s.key))
  const exitKeys = isLeaseholder ? ['leaving', 'termination'] : ['leaving']
  const exit = SECTIONS.filter((s) => exitKeys.includes(s.key))

  return (
    <nav className="sidebar">
      <div className="brand">
        <span className="brand-dot" />
        homies
      </div>

      {primary.map((s) => (
        <NavLink key={s.key} to={s.path} end={s.path === '/app'} className={({ isActive }) => 'nav-item' + (isActive ? ' active' : '')}>
          <span className="nav-icon">{s.icon}</span>
          {s.label}
        </NavLink>
      ))}

      <div className="nav-section">Money</div>
      {money.map((s) => (
        <NavLink key={s.key} to={s.path} className={({ isActive }) => 'nav-item' + (isActive ? ' active' : '')}>
          <span className="nav-icon">{s.icon}</span>
          {s.label}
        </NavLink>
      ))}

      <div className="nav-section">Living together</div>
      {living.map((s) => {
        const badge = badgeFor(s.key)
        return (
          <NavLink key={s.key} to={s.path} className={({ isActive }) => 'nav-item' + (isActive ? ' active' : '')}>
            <span className="nav-icon">{s.icon}</span>
            {s.label}
            {badge ? <span className="nav-badge">{badge}</span> : null}
          </NavLink>
        )
      })}

      <div className="nav-section">Wrap up</div>
      {exit.map((s) => (
        <NavLink key={s.key} to={s.path} className={({ isActive }) => 'nav-item' + (isActive ? ' active' : '')}>
          <span className="nav-icon">{s.icon}</span>
          {s.label}
        </NavLink>
      ))}
    </nav>
  )
}
