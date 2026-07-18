import './Landing.css'

// ── Update this once your App Store listing is live ──────────────────────────
const APP_STORE_URL = 'https://apps.apple.com/app/id6792280943'

const FEATURES = [
  {
    icon: '💸',
    title: 'Bills & rent',
    body: 'Split utilities and rent fairly, track who has paid, and keep a clear record — no spreadsheets, no awkward chases.',
  },
  {
    icon: '🧹',
    title: 'Chores & cleaning',
    body: 'A rolling roster with swap requests, appliance booking and photo proof so everyone pulls their weight.',
  },
  {
    icon: '🛒',
    title: 'Groceries & necessities',
    body: 'Shared shopping lists and house staples, with costs split automatically between housemates.',
  },
  {
    icon: '📺',
    title: 'Subscriptions',
    body: 'Manage shared Netflix, internet and more — see who is in and what each person owes.',
  },
  {
    icon: '💬',
    title: 'House chat',
    body: 'Group chat with pinned announcements, polls, photos and voice messages. Everything in one place.',
  },
  {
    icon: '🎉',
    title: 'Parties & house rules',
    body: 'Give notice for gatherings and keep the agreed house rules where everyone can see them.',
  },
  {
    icon: '🛠️',
    title: 'Issues & complaints',
    body: 'Log maintenance issues and raise complaints with a clear record from report to resolution.',
  },
  {
    icon: '🚪',
    title: 'Move in & out',
    body: 'Condition checklists, bond tracking, two-week notice and deductions all in one place — leave without the drama.',
  },
]

const STEPS = [
  { n: '1', title: 'Download the app', body: 'Grab Leasely from the App Store — free to download.' },
  { n: '2', title: 'Set up your house', body: 'Create your sharehouse or join with an invite code from your leaseholder.' },
  { n: '3', title: 'Run it together', body: 'Split bills, share chores and keep everyone on the same page.' },
]

function AppStoreBadge({ size = 'lg' }) {
  return (
    <div className={`store-badges ${size}`}>
      <a className="store-badge" href={APP_STORE_URL} target="_blank" rel="noopener noreferrer" aria-label="Download on the App Store">
        <span className="store-badge-icon"></span>
        <span className="store-badge-text">
          <small>Download on the</small>
          <strong>App Store</strong>
        </span>
      </a>
    </div>
  )
}

export function Landing() {
  return (
    <div className="landing">
      {/* ── Nav ── */}
      <header className="lp-nav">
        <div className="lp-container lp-nav-inner">
          <a className="lp-brand" href="#top">
            <span className="lp-brand-dot" /> homies
          </a>
          <nav className="lp-nav-links">
            <a href="#features">Features</a>
            <a href="#how">How it works</a>
            <a href="#get">Get the app</a>
          </nav>
        </div>
      </header>

      {/* ── Hero ── */}
      <section className="lp-hero" id="top">
        <div className="lp-container lp-hero-inner">
          <div className="lp-hero-copy">
            <span className="lp-pill">🍎 Now on the App Store</span>
            <h1>Run a sharehouse without the spreadsheets.</h1>
            <p className="lp-lead">
              Bills, bond, chores, groceries, parties, complaints — one place,
              fair splits, less drama. Homies keeps your whole house on the
              same page.
            </p>
            <AppStoreBadge />
            <p className="lp-note">Free to download · iOS</p>
          </div>

          <div className="lp-hero-art">
            <div className="lp-phone">
              <div className="lp-phone-notch" />
              <div className="lp-phone-screen">
                <div className="lp-screen-brand">
                  <span className="lp-brand-dot" /> homies
                </div>
                <div className="lp-screen-card">
                  <div className="lp-screen-row">
                    <span>⚡ Electricity</span>
                    <strong>$42.50</strong>
                  </div>
                  <div className="lp-screen-bar"><span style={{ width: '75%' }} /></div>
                  <div className="lp-screen-meta">3 of 4 housemates paid</div>
                </div>
                <div className="lp-screen-card">
                  <div className="lp-screen-row">
                    <span>🧹 Kitchen clean</span>
                    <span className="lp-screen-chip">Due today</span>
                  </div>
                  <div className="lp-screen-meta">Assigned to Alex</div>
                </div>
                <div className="lp-screen-card">
                  <div className="lp-screen-row">
                    <span>🛒 Groceries</span>
                    <strong>$18.20</strong>
                  </div>
                  <div className="lp-screen-meta">Split 4 ways</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ── Features ── */}
      <section className="lp-features" id="features">
        <div className="lp-container">
          <div className="lp-section-head">
            <h2>Everything a sharehouse needs</h2>
            <p>One app for the money, the mess and the messages.</p>
          </div>
          <div className="lp-feature-grid">
            {FEATURES.map((f) => (
              <div className="lp-feature" key={f.title}>
                <div className="lp-feature-icon">{f.icon}</div>
                <h3>{f.title}</h3>
                <p>{f.body}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── How it works ── */}
      <section className="lp-how" id="how">
        <div className="lp-container">
          <div className="lp-section-head">
            <h2>Up and running in minutes</h2>
            <p>No setup headaches — just download and go.</p>
          </div>
          <div className="lp-steps">
            {STEPS.map((s) => (
              <div className="lp-step" key={s.n}>
                <div className="lp-step-num">{s.n}</div>
                <h3>{s.title}</h3>
                <p>{s.body}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ── Final CTA ── */}
      <section className="lp-cta" id="get">
        <div className="lp-container lp-cta-inner">
          <h2>Get Homies on your phone</h2>
          <p>Download free on iOS and bring calm to your sharehouse today.</p>
          <AppStoreBadge />
        </div>
      </section>

      {/* ── Footer ── */}
      <footer className="lp-footer">
        <div className="lp-container lp-footer-inner">
          <span className="lp-brand">
            <span className="lp-brand-dot" /> homies
          </span>
          <nav className="lp-footer-links">
            <a href="mailto:support@homiesapp.com">Contact</a>
            <a href="/privacy">Privacy policy</a>
          </nav>
          <span className="lp-footer-copy">
            © {new Date().getFullYear()} Homies. All rights reserved.
          </span>
        </div>
      </footer>
    </div>
  )
}
