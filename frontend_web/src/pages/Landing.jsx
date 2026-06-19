import './Landing.css'

// ── Replace these with your real store URLs once the apps are published ──
const APP_STORE_URL = '#'
const PLAY_STORE_URL = '#'

const FEATURES = [
  {
    icon: '💡',
    title: 'Bills & bond',
    body: 'Split utilities fairly, track who has paid, and prorate by move-in date — no spreadsheets, no awkward chases.',
  },
  {
    icon: '🧹',
    title: 'Chores & cleaning',
    body: 'A rolling roster with photo proof and a paper trail, so everyone pulls their weight.',
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
    title: 'House messages',
    body: 'One group chat for the whole house. Keep plans, reminders and decisions in one place.',
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
    title: 'Move out, cleanly',
    body: 'Two-week notice, bond release and deductions all explained — leave without the drama.',
  },
]

const STEPS = [
  { n: '1', title: 'Download the app', body: 'Grab Homies from the App Store or Google Play.' },
  { n: '2', title: 'Set up your house', body: 'Create your sharehouse or join with an invite link.' },
  { n: '3', title: 'Run it together', body: 'Split bills, share chores and keep everyone on the same page.' },
]

function StoreBadges({ size = 'lg' }) {
  return (
    <div className={`store-badges ${size}`}>
      <a className="store-badge" href={APP_STORE_URL} aria-label="Download on the App Store">
        <span className="store-badge-icon"></span>
        <span className="store-badge-text">
          <small>Download on the</small>
          <strong>App Store</strong>
        </span>
      </a>
      <a className="store-badge" href={PLAY_STORE_URL} aria-label="Get it on Google Play">
        <span className="store-badge-icon">▶</span>
        <span className="store-badge-text">
          <small>Get it on</small>
          <strong>Google Play</strong>
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
            <span className="lp-pill">📱 Mobile app</span>
            <h1>Run a sharehouse without the spreadsheets.</h1>
            <p className="lp-lead">
              Bills, bond, chores, groceries, parties, complaints — one place,
              fair splits, less drama. Homies keeps your whole house on the
              same page.
            </p>
            <StoreBadges />
            <p className="lp-note">Free to download · Available on iOS &amp; Android</p>
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
                  <div className="lp-screen-meta">Assigned to Sam</div>
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

      {/* ── Mobile-only notice ── */}
      <section className="lp-banner">
        <div className="lp-container">
          <p>
            <strong>Homies lives on your phone.</strong> This website is just an
            overview — to create your house, split bills and chat with your
            housemates, download the mobile app below.
          </p>
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
          <p>Download free and bring calm to your sharehouse today.</p>
          <StoreBadges />
        </div>
      </section>

      {/* ── Footer ── */}
      <footer className="lp-footer">
        <div className="lp-container lp-footer-inner">
          <span className="lp-brand">
            <span className="lp-brand-dot" /> homies
          </span>
          <span className="lp-footer-copy">
            © {new Date().getFullYear()} Homies. All rights reserved.
          </span>
        </div>
      </footer>
    </div>
  )
}
