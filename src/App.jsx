import { Routes, Route, Navigate, Outlet } from 'react-router-dom'
import { useHomies } from './context/HomiesContext.jsx'
import { Sidebar } from './components/Sidebar.jsx'
import { BottomTabBar } from './components/BottomTabBar.jsx'
import { TopBar } from './components/TopBar.jsx'

import { Welcome } from './pages/Welcome.jsx'
import { Login } from './pages/Login.jsx'
import { Signup } from './pages/Signup.jsx'
import { AcceptInvite } from './pages/AcceptInvite.jsx'
import { LeaseholderOnboarding } from './pages/LeaseholderOnboarding.jsx'
import { TenantOnboarding } from './pages/TenantOnboarding.jsx'
import { Dashboard } from './pages/Dashboard.jsx'
import { Property } from './pages/Property.jsx'
import { Housemates } from './pages/Housemates.jsx'
import { Bills } from './pages/Bills.jsx'
import { Subscriptions } from './pages/Subscriptions.jsx'
import { Groceries } from './pages/Groceries.jsx'
import { Necessities } from './pages/Necessities.jsx'
import { Cleaning } from './pages/Cleaning.jsx'
import { HouseRules } from './pages/HouseRules.jsx'
import { Parties } from './pages/Parties.jsx'
import { Messages } from './pages/Messages.jsx'
import { Complaints } from './pages/Complaints.jsx'
import { Issues } from './pages/Issues.jsx'
import { Leaving } from './pages/Leaving.jsx'
import { Termination } from './pages/Termination.jsx'

function AppShell() {
  const { currentUser } = useHomies()
  if (!currentUser) return <Navigate to="/login" replace />
  return (
    <div className="app">
      <Sidebar />
      <div className="main">
        <TopBar />
        <div className="content">
          <Outlet />
        </div>
      </div>
      <BottomTabBar />
    </div>
  )
}

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<Welcome />} />
      <Route path="/login" element={<Login />} />
      <Route path="/signup" element={<Signup />} />
      <Route path="/invite/:code" element={<AcceptInvite />} />
      <Route path="/onboarding/leaseholder" element={<LeaseholderOnboarding />} />
      <Route path="/onboarding/tenant" element={<TenantOnboarding />} />
      <Route path="/app" element={<AppShell />}>
        <Route index element={<Dashboard />} />
        <Route path="property" element={<Property />} />
        <Route path="housemates" element={<Housemates />} />
        <Route path="bills" element={<Bills />} />
        <Route path="subscriptions" element={<Subscriptions />} />
        <Route path="groceries" element={<Groceries />} />
        <Route path="necessities" element={<Necessities />} />
        <Route path="cleaning" element={<Cleaning />} />
        <Route path="rules" element={<HouseRules />} />
        <Route path="parties" element={<Parties />} />
        <Route path="messages" element={<Messages />} />
        <Route path="issues" element={<Issues />} />
        <Route path="complaints" element={<Complaints />} />
        <Route path="leaving" element={<Leaving />} />
        <Route path="termination" element={<Termination />} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}
