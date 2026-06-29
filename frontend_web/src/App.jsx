import { Routes, Route, Navigate } from 'react-router-dom'
import { Landing } from './pages/Landing.jsx'
import { Privacy } from './pages/Privacy.jsx'

// ─────────────────────────────────────────────────────────────────────────────
// WEB = MARKETING SITE ONLY.
//
// Homies is a Flutter mobile app (see ../frontend_app). The web build serves
// the marketing landing page and points visitors to the App Store.
// ─────────────────────────────────────────────────────────────────────────────

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<Landing />} />
      <Route path="/privacy" element={<Privacy />} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}
