import { useState } from 'react'
import { FilePicker } from './FilePicker.jsx'

export function MarkPaidModal({ title, amountLabel, currentProof = null, onConfirm, onClose }) {
  const [proof, setProof] = useState(currentProof)

  return (
    <div className="modal-bg" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()} style={{ maxWidth: 460 }}>
        <h2>{title}</h2>
        {amountLabel && <p className="tiny muted mb">{amountLabel}</p>}

        <div className="field">
          <label>Payment proof <span className="hint">(optional — screenshot of bank transfer / PayID)</span></label>
          <FilePicker value={proof} onChange={setProof} />
        </div>

        <div className="modal-actions">
          <button className="btn secondary" onClick={onClose}>Cancel</button>
          <button className="btn" onClick={() => onConfirm(proof)}>Confirm paid</button>
        </div>
      </div>
    </div>
  )
}
