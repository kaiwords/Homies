import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useHomies } from '../context/HomiesContext.jsx'
import { fmtAUD } from '../lib/format.js'

const FEATURES = [
  ['balcony', 'Balcony'],
  ['garage', 'Garage / parking'],
  ['furnished', 'Furnished'],
  ['swimmingPool', 'Swimming pool'],
  ['gym', 'Gym'],
  ['airCon', 'Air conditioning'],
  ['dishwasher', 'Dishwasher'],
  ['laundry', 'In-unit laundry'],
  ['petsAllowed', 'Pets allowed'],
  ['nbn', 'NBN included'],
]

export function LeaseholderOnboarding() {
  const { state, update, currentUser } = useHomies()
  const navigate = useNavigate()
  const [step, setStep] = useState(0)
  const [draft, setDraft] = useState(() => ({
    address: '',
    type: 'House',
    bedrooms: 3,
    bathrooms: 1,
    features: {},
    agent: '',
    agentContact: '',
    leaseStart: '',
    leaseEnd: '',
    leaseAgreementName: null,
    rentAmount: '',
    rentCadence: 'weekly',
    rentStartDate: '',
    bondWeeks: 4,
    advanceWeeks: 2,
    maxOccupants: 4,
    rules: [
      'No smoking inside the property',
      'Quiet hours after 10pm',
    ],
    invites: [{ email: '', role: 'tenant' }],
  }))

  const setF = (k, v) => setDraft((d) => ({ ...d, [k]: v }))
  const toggleFeature = (k) => setF('features', { ...draft.features, [k]: !draft.features[k] })

  const finish = () => {
    update((s) => ({
      ...s,
      property: {
        ...s.property,
        address: draft.address || s.property.address,
        type: draft.type,
        bedrooms: Number(draft.bedrooms),
        bathrooms: Number(draft.bathrooms),
        features: draft.features,
        agent: draft.agent,
        agentContact: draft.agentContact,
        leaseStart: draft.leaseStart,
        leaseEnd: draft.leaseEnd,
        rentAmount: Number(draft.rentAmount) || 0,
        rentCadence: draft.rentCadence,
        rentStartDate: draft.rentStartDate,
        bondWeeks: Number(draft.bondWeeks),
        advanceWeeks: Number(draft.advanceWeeks),
        maxOccupants: Number(draft.maxOccupants),
        setupComplete: true,
      },
      houseRules: draft.rules.map((text, i) => ({
        id: 'r-onboard-' + i,
        text,
        addedBy: currentUser?.id || 'u1',
        addedAt: new Date().toISOString().slice(0, 10),
      })),
      invites: draft.invites.filter((inv) => inv.email.trim()).map((inv) => ({
        code: 'HMI-' + Math.random().toString(36).slice(2, 6).toUpperCase(),
        email: inv.email.trim(),
        role: inv.role,
        sentAt: new Date().toISOString().slice(0, 10),
        status: 'sent',
      })),
      session: { ...s.session, pendingSignup: null },
    }))
    if (currentUser) {
      update((s) => ({
        ...s,
        users: s.users.map((u) => u.id === currentUser.id ? { ...u, pending: false, docVerified: true, bondPaid: true, acceptedRulesAt: new Date().toISOString().slice(0, 10) } : u),
      }))
    }
    navigate('/app')
  }

  const bondAmount = Number(draft.rentAmount || 0) * Number(draft.bondWeeks || 0)
  const advanceAmount = Number(draft.rentAmount || 0) * Number(draft.advanceWeeks || 0)

  const steps = ['Property', 'Lease & agent', 'Rent & bond', 'House rules', 'Invite housemates']

  return (
    <div className="wizard">
      <h1>Set up your sharehouse</h1>
      <p className="muted mb">Step {step + 1} of {steps.length} — {steps[step]}</p>

      <div className="steps">
        {steps.map((_, i) => <div key={i} className={'step' + (i <= step ? ' on' : '')} />)}
      </div>

      <div className="card">
        {step === 0 && (
          <>
            <h2>Property details</h2>
            <p className="muted mb">Where is it and what's it like?</p>

            <div className="field">
              <label>Address</label>
              <input type="text" value={draft.address} onChange={(e) => setF('address', e.target.value)} placeholder="12 Banksia Street, Newtown NSW 2042" />
            </div>

            <div className="field-row">
              <div className="field">
                <label>Property type</label>
                <select value={draft.type} onChange={(e) => setF('type', e.target.value)}>
                  <option>House</option>
                  <option>Apartment / Unit</option>
                  <option>Townhouse</option>
                  <option>Granny flat</option>
                </select>
              </div>
              <div className="field">
                <label>Bedrooms</label>
                <input type="number" min="1" max="20" value={draft.bedrooms} onChange={(e) => setF('bedrooms', e.target.value)} />
              </div>
              <div className="field">
                <label>Bathrooms</label>
                <input type="number" min="1" max="10" value={draft.bathrooms} onChange={(e) => setF('bathrooms', e.target.value)} />
              </div>
              <div className="field">
                <label>Max occupants</label>
                <input type="number" min="1" max="20" value={draft.maxOccupants} onChange={(e) => setF('maxOccupants', e.target.value)} />
              </div>
            </div>

            <div className="field">
              <label>Features</label>
              <div className="checkbox-grid">
                {FEATURES.map(([k, lbl]) => (
                  <label key={k}>
                    <input type="checkbox" checked={!!draft.features[k]} onChange={() => toggleFeature(k)} />
                    {lbl}
                  </label>
                ))}
              </div>
            </div>
          </>
        )}

        {step === 1 && (
          <>
            <h2>Lease & agent</h2>
            <p className="muted mb">Lease dates and who manages the property.</p>

            <div className="field-row">
              <div className="field">
                <label>Lease start</label>
                <input type="date" value={draft.leaseStart} onChange={(e) => setF('leaseStart', e.target.value)} />
              </div>
              <div className="field">
                <label>Lease end (expiration)</label>
                <input type="date" value={draft.leaseEnd} onChange={(e) => setF('leaseEnd', e.target.value)} />
              </div>
            </div>

            <div className="field">
              <label>Renting through (agent / landlord)</label>
              <input type="text" value={draft.agent} onChange={(e) => setF('agent', e.target.value)} placeholder="Ray White Newtown" />
            </div>

            <div className="field">
              <label>Agent contact (optional)</label>
              <input type="text" value={draft.agentContact} onChange={(e) => setF('agentContact', e.target.value)} placeholder="leasing@example.com.au" />
            </div>

            <div className="field">
              <label>Lease agreement</label>
              <input type="file" onChange={(e) => setF('leaseAgreementName', e.target.files?.[0]?.name || null)} />
              <span className="hint">Required to sign as leaseholder. Only one leaseholder needs to upload — others can co-sign via invite.</span>
              {draft.leaseAgreementName && (
                <div className="chip ok" style={{ marginTop: 6 }}>Attached: {draft.leaseAgreementName}</div>
              )}
            </div>
          </>
        )}

        {step === 2 && (
          <>
            <h2>Rent & bond rules</h2>
            <p className="muted mb">How rent flows and what new housemates owe up front.</p>

            <div className="field-row">
              <div className="field">
                <label>Rent amount</label>
                <input type="number" min="0" step="10" value={draft.rentAmount} onChange={(e) => setF('rentAmount', e.target.value)} placeholder="850" />
              </div>
              <div className="field">
                <label>Cadence</label>
                <div className="segment">
                  {['weekly', 'fortnightly', 'monthly'].map((c) => (
                    <button type="button" key={c} className={draft.rentCadence === c ? 'on' : ''} onClick={() => setF('rentCadence', c)}>
                      {c[0].toUpperCase() + c.slice(1)}
                    </button>
                  ))}
                </div>
              </div>
              <div className="field">
                <label>Rent start date</label>
                <input type="date" value={draft.rentStartDate} onChange={(e) => setF('rentStartDate', e.target.value)} />
              </div>
            </div>

            <hr />

            <div className="field">
              <label>Bond required from each new housemate</label>
              <div className="segment">
                {[2, 4].map((n) => (
                  <button type="button" key={n} className={Number(draft.bondWeeks) === n ? 'on' : ''} onClick={() => setF('bondWeeks', n)}>
                    {n} weeks
                  </button>
                ))}
              </div>
              <span className="hint">You can waive this for individual housemates later if needed.</span>
            </div>

            <div className="field">
              <label>Advance rent required</label>
              <div className="segment">
                {[0, 1, 2, 4].map((n) => (
                  <button type="button" key={n} className={Number(draft.advanceWeeks) === n ? 'on' : ''} onClick={() => setF('advanceWeeks', n)}>
                    {n === 0 ? 'None' : `${n} weeks`}
                  </button>
                ))}
              </div>
            </div>

            {draft.rentAmount && (
              <div className="card" style={{ background: 'var(--surface-2)', marginTop: 12 }}>
                <div className="tiny muted bold">A new housemate will owe before move-in:</div>
                <div className="row" style={{ justifyContent: 'space-between', marginTop: 6 }}>
                  <span>Bond ({draft.bondWeeks} weeks)</span>
                  <span className="bold">{fmtAUD(bondAmount / Math.max(Number(state.property.maxOccupants) || 1, 1))} <span className="faint tiny">/ person estimate</span></span>
                </div>
                <div className="row" style={{ justifyContent: 'space-between' }}>
                  <span>Advance rent ({draft.advanceWeeks} weeks)</span>
                  <span className="bold">{fmtAUD(advanceAmount / Math.max(Number(state.property.maxOccupants) || 1, 1))} <span className="faint tiny">/ person estimate</span></span>
                </div>
              </div>
            )}
          </>
        )}

        {step === 3 && (
          <>
            <h2>Initial house rules</h2>
            <p className="muted mb">Tenants must accept these on join. You can add or remove later.</p>

            {draft.rules.map((r, i) => (
              <div className="row mb" key={i}>
                <input
                  type="text"
                  value={r}
                  onChange={(e) => {
                    const next = [...draft.rules]
                    next[i] = e.target.value
                    setF('rules', next)
                  }}
                  style={{ flex: 1, padding: '10px 12px', border: '1px solid var(--border-strong)', borderRadius: 'var(--radius-sm)' }}
                />
                <button className="btn ghost small" onClick={() => setF('rules', draft.rules.filter((_, idx) => idx !== i))}>Remove</button>
              </div>
            ))}
            <button className="btn secondary" onClick={() => setF('rules', [...draft.rules, ''])}>+ Add another rule</button>
          </>
        )}

        {step === 4 && (
          <>
            <h2>Invite your housemates</h2>
            <p className="muted mb">Send emails now or skip and invite from the dashboard later.</p>

            {draft.invites.map((inv, i) => (
              <div className="field-row" key={i} style={{ marginBottom: 12, alignItems: 'flex-end' }}>
                <div className="field" style={{ marginBottom: 0 }}>
                  <label>Email</label>
                  <input
                    type="email"
                    value={inv.email}
                    onChange={(e) => {
                      const next = [...draft.invites]
                      next[i] = { ...next[i], email: e.target.value }
                      setF('invites', next)
                    }}
                    placeholder="housemate@example.com"
                  />
                </div>
                <div className="field" style={{ marginBottom: 0 }}>
                  <label>Role</label>
                  <select
                    value={inv.role}
                    onChange={(e) => {
                      const next = [...draft.invites]
                      next[i] = { ...next[i], role: e.target.value }
                      setF('invites', next)
                    }}
                  >
                    <option value="tenant">Tenant</option>
                    <option value="leaseholder">Co-leaseholder</option>
                  </select>
                </div>
                <button className="btn ghost small" onClick={() => setF('invites', draft.invites.filter((_, idx) => idx !== i))} disabled={draft.invites.length === 1}>×</button>
              </div>
            ))}
            <button className="btn secondary" onClick={() => setF('invites', [...draft.invites, { email: '', role: 'tenant' }])}>+ Another invite</button>
          </>
        )}
      </div>

      <div className="actions">
        <button className="btn secondary" onClick={() => setStep(Math.max(0, step - 1))} disabled={step === 0}>← Back</button>
        {step < steps.length - 1 ? (
          <button className="btn" onClick={() => setStep(step + 1)}>Continue →</button>
        ) : (
          <button className="btn" onClick={finish}>Finish setup ✓</button>
        )}
      </div>
    </div>
  )
}
