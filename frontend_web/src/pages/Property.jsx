import { useHomies } from '../context/HomiesContext.jsx'
import { fmtAUD, fmtDate, cadenceLabel } from '../lib/format.js'

const FEATURE_LABELS = {
  balcony: 'Balcony',
  garage: 'Garage / parking',
  furnished: 'Furnished',
  swimmingPool: 'Swimming pool',
  gym: 'Gym',
  airCon: 'Air conditioning',
  dishwasher: 'Dishwasher',
  laundry: 'In-unit laundry',
  petsAllowed: 'Pets allowed',
  nbn: 'NBN included',
}

export function Property() {
  const { state, currentUser } = useHomies()
  const p = state.property
  const isLeaseholder = currentUser.role === 'leaseholder'
  const features = Object.entries(p.features || {}).filter(([, v]) => v).map(([k]) => FEATURE_LABELS[k] || k)

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Property & lease</h1>
          <p>The details every housemate should know.</p>
        </div>
        {isLeaseholder && <button className="btn secondary">Edit details</button>}
      </div>

      <div className="card">
        <h2>{p.address}</h2>
        <p className="muted">{p.type} · {p.bedrooms} bed · {p.bathrooms} bath · sleeps up to {p.maxOccupants}</p>

        {features.length > 0 && (
          <div className="row mt" style={{ flexWrap: 'wrap', gap: 6 }}>
            {features.map((f) => <span key={f} className="chip">{f}</span>)}
          </div>
        )}
      </div>

      <div className="card">
        <h2>Lease</h2>
        <div className="card-row">
          <div className="stat">
            <div className="label">Start</div>
            <div className="value" style={{ fontSize: 16 }}>{fmtDate(p.leaseStart)}</div>
          </div>
          <div className="stat">
            <div className="label">End</div>
            <div className="value" style={{ fontSize: 16 }}>{fmtDate(p.leaseEnd)}</div>
          </div>
          <div className="stat">
            <div className="label">Agent</div>
            <div className="value" style={{ fontSize: 16 }}>{p.agent || '—'}</div>
            <div className="sub">{p.agentContact || ''}</div>
          </div>
        </div>
      </div>

      <div className="card">
        <h2>Rent & bond</h2>
        <div className="card-row">
          <div className="stat">
            <div className="label">Rent</div>
            <div className="value">{fmtAUD(p.rentAmount)}</div>
            <div className="sub">{cadenceLabel(p.rentCadence)} · starts {fmtDate(p.rentStartDate)}</div>
          </div>
          <div className="stat">
            <div className="label">Bond required</div>
            <div className="value">{p.bondWeeks} weeks</div>
            <div className="sub">≈ {fmtAUD(p.rentAmount * p.bondWeeks)} for the property</div>
          </div>
          <div className="stat">
            <div className="label">Advance rent</div>
            <div className="value">{p.advanceWeeks} weeks</div>
            <div className="sub">collected before move-in</div>
          </div>
        </div>
      </div>

      {!isLeaseholder && (
        <div className="placeholder-banner">
          Only the leaseholder can edit property & lease details. Speak to them if anything looks off.
        </div>
      )}
    </>
  )
}
