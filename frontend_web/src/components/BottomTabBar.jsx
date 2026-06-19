import { useState } from 'react'
import { NavLink } from 'react-router-dom'
import { SECTIONS } from '../data/mockData.js'
import { useHomies } from '../context/HomiesContext.jsx'

const PRIMARY_KEYS = ['dashboard', 'bills', 'cleaning', 'messages']

export function BottomTabBar() {
  const { state, currentUser } = useHomies()
  const [showMore, setShowMore] = useState(false)
  const isLeaseholder = currentUser?.role === 'leaseholder'

  const pendingComplaints = state.complaints.filter((c) => c.status === 'open').length
  const pendingTasks = state.cleaningTasks.filter((t) => !t.done && !t.excuse).length

  const primary = PRIMARY_KEYS.map((k) => SECTIONS.find((s) => s.key === k)).filter(Boolean)
  const other = SECTIONS.filter((s) => !PRIMARY_KEYS.includes(s.key) && (isLeaseholder || s.key !== 'termination'))

  const badgeFor = (key) => {
    if (key === 'cleaning' && pendingTasks) return pendingTasks
    if (key === 'complaints' && pendingComplaints) return pendingComplaints
    return null
  }

  return (
    <>
      <nav className="bottom-tabs">
        {primary.map((s) => {
          const badge = badgeFor(s.key)
          return (
            <NavLink
              key={s.key}
              to={s.path}
              end={s.path === '/app'}
              className={({ isActive }) => 'tab' + (isActive ? ' active' : '')}
            >
              <span className="tab-icon">{s.icon}</span>
              <span className="tab-label">{s.label.split(' ')[0]}</span>
              {badge ? <span className="tab-badge">{badge}</span> : null}
            </NavLink>
          )
        })}
        <button
          type="button"
          className={'tab' + (showMore ? ' active' : '')}
          onClick={() => setShowMore(true)}
        >
          <span className="tab-icon">⋯</span>
          <span className="tab-label">More</span>
        </button>
      </nav>

      {showMore && (
        <div className="sheet-bg" onClick={() => setShowMore(false)}>
          <div className="sheet" onClick={(e) => e.stopPropagation()}>
            <div className="sheet-handle" />
            <h2 style={{ marginBottom: 14 }}>All sections</h2>
            <div className="sheet-grid">
              {other.map((s) => {
                const badge = badgeFor(s.key)
                return (
                  <NavLink
                    key={s.key}
                    to={s.path}
                    onClick={() => setShowMore(false)}
                    className={({ isActive }) => 'sheet-item' + (isActive ? ' active' : '')}
                  >
                    <span className="sheet-icon">{s.icon}</span>
                    <span className="sheet-label">{s.label}</span>
                    {badge ? <span className="tab-badge">{badge}</span> : null}
                  </NavLink>
                )
              })}
            </div>
          </div>
        </div>
      )}
    </>
  )
}
