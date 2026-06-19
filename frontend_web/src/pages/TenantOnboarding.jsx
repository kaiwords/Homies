import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useHomies } from '../context/HomiesContext.jsx'
import { FilePicker } from '../components/FilePicker.jsx'
import { fmtAUD } from '../lib/format.js'

export function TenantOnboarding() {
  const { state, update, currentUser } = useHomies()
  const navigate = useNavigate()
  const [step, setStep] = useState(0)
  const [idDoc, setIdDoc] = useState({ kind: 'drivers-licence', file: null })
  const [bondProof, setBondProof] = useState({ method: 'bank-transfer', file: null })
  const [advanceProof, setAdvanceProof] = useState({ method: 'bank-transfer', file: null })
  const [moveInDate, setMoveInDate] = useState('')
  const [acceptedRules, setAcceptedRules] = useState(false)

  const bondAmount = (state.property.rentAmount * state.property.bondWeeks) / Math.max(state.property.maxOccupants, 1)
  const advanceAmount = (state.property.rentAmount * state.property.advanceWeeks) / Math.max(state.property.maxOccupants, 1)

  const steps = ['ID document', 'Bond', 'Advance rent', 'House rules', 'Move-in date']

  const finish = () => {
    if (!currentUser) {
      navigate('/login')
      return
    }
    const submissions = {
      idDoc: idDoc.file ? { kind: idDoc.kind, ...idDoc.file } : null,
      bondProof: bondProof.file ? { method: bondProof.method, ...bondProof.file } : null,
      advanceRentProof: advanceProof.file ? { method: advanceProof.method, ...advanceProof.file } : null,
    }
    update((s) => ({
      ...s,
      users: s.users.map((u) => u.id === currentUser.id ? {
        ...u,
        pending: true,
        docVerified: false,
        bondPaid: false,
        bondAmount: Math.round(bondAmount * 100) / 100,
        advanceRentPaid: false,
        moveInDate: moveInDate || new Date().toISOString().slice(0, 10),
        acceptedRulesAt: acceptedRules ? new Date().toISOString().slice(0, 10) : null,
        submissions,
      } : u),
    }))
    navigate('/app')
  }

  return (
    <div className="wizard">
      <h1>Welcome — let's get you moved in</h1>
      <p className="muted mb">Step {step + 1} of {steps.length} — {steps[step]}</p>

      <div className="steps">
        {steps.map((_, i) => <div key={i} className={'step' + (i <= step ? ' on' : '')} />)}
      </div>

      <div className="card">
        {step === 0 && (
          <>
            <h2>Upload one valid ID</h2>
            <p className="muted mb">The leaseholder will review and approve before you can move in.</p>

            <div className="field">
              <label>Document type</label>
              <select value={idDoc.kind} onChange={(e) => setIdDoc({ ...idDoc, kind: e.target.value })}>
                <option value="drivers-licence">Driver's licence</option>
                <option value="passport">Passport</option>
                <option value="medicare">Medicare card</option>
                <option value="proof-of-age">Proof of age card</option>
              </select>
            </div>

            <div className="field">
              <label>Upload image or PDF</label>
              <FilePicker value={idDoc.file} onChange={(f) => setIdDoc({ ...idDoc, file: f })} />
            </div>
          </>
        )}

        {step === 1 && (
          <>
            <h2>Pay your bond</h2>
            <p className="muted mb">{state.property.bondWeeks} weeks of rent — {fmtAUD(bondAmount)} (your share at {state.property.maxOccupants} max occupants).</p>

            <div className="card" style={{ background: 'var(--surface-2)' }}>
              <div className="row" style={{ justifyContent: 'space-between' }}>
                <div>
                  <div className="bold">Pay to leaseholder</div>
                  <div className="tiny muted">Bank: 062-000 · 12345678 · Ref BOND-{currentUser?.id || 'NEW'}</div>
                </div>
                <div className="bold" style={{ fontSize: 20 }}>{fmtAUD(bondAmount)}</div>
              </div>
            </div>

            <div className="field mt">
              <label>Method</label>
              <div className="segment">
                {['bank-transfer', 'payid', 'cash'].map((m) => (
                  <button type="button" key={m} className={bondProof.method === m ? 'on' : ''} onClick={() => setBondProof({ ...bondProof, method: m })}>
                    {m.replace('-', ' ')}
                  </button>
                ))}
              </div>
            </div>

            <div className="field">
              <label>Upload proof (screenshot)</label>
              <FilePicker value={bondProof.file} onChange={(f) => setBondProof({ ...bondProof, file: f })} />
              <span className="hint">The leaseholder can waive bond in exceptional cases — talk to them if needed.</span>
            </div>
          </>
        )}

        {step === 2 && (
          <>
            <h2>Pay {state.property.advanceWeeks} weeks advance rent</h2>
            <p className="muted mb">{fmtAUD(advanceAmount)} — paid up-front so you start with a buffer.</p>

            <div className="field">
              <label>Method</label>
              <div className="segment">
                {['bank-transfer', 'payid', 'cash'].map((m) => (
                  <button type="button" key={m} className={advanceProof.method === m ? 'on' : ''} onClick={() => setAdvanceProof({ ...advanceProof, method: m })}>
                    {m.replace('-', ' ')}
                  </button>
                ))}
              </div>
            </div>

            <div className="field">
              <label>Upload proof</label>
              <FilePicker value={advanceProof.file} onChange={(f) => setAdvanceProof({ ...advanceProof, file: f })} />
            </div>
          </>
        )}

        {step === 3 && (
          <>
            <h2>House rules</h2>
            <p className="muted mb">You must accept these before the leaseholder will let you move in.</p>

            <ul style={{ paddingLeft: 18 }}>
              {state.houseRules.map((r) => (
                <li key={r.id} style={{ marginBottom: 6 }}>{r.text}</li>
              ))}
            </ul>

            <label className="row" style={{ marginTop: 12, cursor: 'pointer' }}>
              <input type="checkbox" checked={acceptedRules} onChange={(e) => setAcceptedRules(e.target.checked)} />
              I have read and agree to the house rules above.
            </label>
          </>
        )}

        {step === 4 && (
          <>
            <h2>Move-in date</h2>
            <p className="muted mb">We use this to prorate your share of bills and rent. The leaseholder must approve your submissions before you can move in.</p>

            <div className="field">
              <label>Planned move-in date</label>
              <input type="date" value={moveInDate} onChange={(e) => setMoveInDate(e.target.value)} />
            </div>

            <div className="placeholder-banner" style={{ marginTop: 12 }}>
              After you submit, the leaseholder will be notified to approve your ID and bond proofs. You'll see status updates on your dashboard.
            </div>
          </>
        )}
      </div>

      <div className="actions">
        <button className="btn secondary" onClick={() => setStep(Math.max(0, step - 1))} disabled={step === 0}>← Back</button>
        {step < steps.length - 1 ? (
          <button
            className="btn"
            onClick={() => setStep(step + 1)}
            disabled={
              (step === 0 && !idDoc.file) ||
              (step === 1 && !bondProof.file) ||
              (step === 2 && !advanceProof.file) ||
              (step === 3 && !acceptedRules)
            }
          >
            Continue →
          </button>
        ) : (
          <button className="btn" onClick={finish} disabled={!moveInDate}>Submit for approval ✓</button>
        )}
      </div>
    </div>
  )
}
