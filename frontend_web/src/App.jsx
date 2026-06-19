import { Routes, Route, Navigate } from 'react-router-dom'
import { Landing } from './pages/Landing.jsx'

// ─────────────────────────────────────────────────────────────────────────────
// WEB = MARKETING SITE ONLY.
//
// Homies is a Flutter mobile app (see ../homies_mobile). The web build serves
// the marketing landing page and points visitors to the App Store / Play Store.
// The original React app screens still live under src/pages but are intentionally
// not routed.
// ─────────────────────────────────────────────────────────────────────────────

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<Landing />} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}
