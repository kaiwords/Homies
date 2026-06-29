export function Privacy() {
  return (
    <div style={{ maxWidth: 720, margin: '0 auto', padding: '48px 24px 80px', fontFamily: 'inherit', color: 'var(--text)' }}>
      <a href="/" style={{ fontSize: 14, color: 'var(--accent-strong)', textDecoration: 'none', display: 'inline-block', marginBottom: 32 }}>
        ← Back to Homies
      </a>
      <h1 style={{ fontSize: 32, fontWeight: 700, letterSpacing: '-0.5px', marginBottom: 8 }}>Privacy Policy</h1>
      <p style={{ color: 'var(--text-faint)', fontSize: 14, marginBottom: 40 }}>Last updated: June 2025</p>

      <Section title="Overview">
        Homies ("we", "our", or "us") is a mobile app that helps sharehouses manage bills, chores, messages and more.
        This policy explains what data we collect, how we use it, and your rights.
      </Section>

      <Section title="Data we collect">
        <ul>
          <li><strong>Account information</strong> — your name, email address and phone number when you sign up.</li>
          <li><strong>House data</strong> — bills, chore rosters, messages and other content you create inside the app.</li>
          <li><strong>Photos and files</strong> — images or documents you upload (e.g. lease agreements, bill receipts).</li>
          <li><strong>Usage data</strong> — basic analytics to understand how the app is used (no advertising profiles).</li>
        </ul>
      </Section>

      <Section title="How we use your data">
        <ul>
          <li>To provide and improve the Homies service.</li>
          <li>To send in-app notifications relevant to your house.</li>
          <li>To respond to support requests.</li>
        </ul>
        We do not sell your personal data to third parties.
      </Section>

      <Section title="Data storage">
        Your data is stored securely using Google Firebase (Firestore and Firebase Auth), hosted in Australia where available.
        Uploaded files are stored in Firebase Storage.
      </Section>

      <Section title="Data sharing">
        Your house data (bills, chores, messages) is shared with other members of your house as part of the service.
        We do not share your data with advertisers or data brokers.
      </Section>

      <Section title="Data retention">
        Your data is retained while your account is active. You can request deletion of your account and associated data
        by contacting us at <a href="mailto:support@homiesapp.com" style={{ color: 'var(--accent-strong)' }}>support@homiesapp.com</a>.
      </Section>

      <Section title="Your rights">
        You have the right to access, correct or delete your personal data at any time. Contact us and we will respond
        within 30 days.
      </Section>

      <Section title="Contact">
        Questions about this policy? Email us at{' '}
        <a href="mailto:support@homiesapp.com" style={{ color: 'var(--accent-strong)' }}>support@homiesapp.com</a>.
      </Section>
    </div>
  )
}

function Section({ title, children }) {
  return (
    <section style={{ marginBottom: 32 }}>
      <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 10 }}>{title}</h2>
      <div style={{ fontSize: 15, lineHeight: 1.7, color: 'var(--text-dim)' }}>{children}</div>
    </section>
  )
}
