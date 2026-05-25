import { useState, useMemo } from 'react'
import { useHomies } from '../context/HomiesContext.jsx'
import { Avatar } from '../components/Avatar.jsx'
import { FilePicker, Attachment } from '../components/FilePicker.jsx'
import { MarkPaidModal } from '../components/MarkPaidModal.jsx'
import {
  fmtAUD,
  fmtDate,
  fmtRelative,
  equalSplit,
  prorateShares,
  residentDays,
  daysBetween,
  addCadence,
  subtractCadence,
  cadenceLabelFull,
} from '../lib/format.js'

const CATEGORIES = [
  ['utility', '💡 Utility'],
  ['internet', '🌐 NBN / internet'],
  ['water', '💧 Water'],
  ['maintenance', '🛠️ Maintenance'],
  ['cleaning', '🧹 Cleaning service'],
  ['pest', '🐜 Pest control'],
  ['other', '📌 Other'],
]

const CADENCES = ['weekly', 'fortnightly', 'monthly', 'quarterly', 'half-yearly', 'yearly', 'custom']

const dueChip = (iso) => {
  const days = Math.round((new Date(iso).getTime() - Date.now()) / 86400000)
  if (days < 0) return { cls: 'danger', label: `overdue · ${Math.abs(days)} d` }
  if (days <= 7) return { cls: 'warn', label: `due ${fmtRelative(iso)}` }
  return { cls: '', label: `due ${fmtRelative(iso)}` }
}

export function Bills() {
  const { state, update, currentUser } = useHomies()
  const [tab, setTab] = useState('bills')
  const [editingBill, setEditingBill] = useState(null)
  const [editingSchedule, setEditingSchedule] = useState(null)
  const [recordingSchedule, setRecordingSchedule] = useState(null)

  const isLeaseholder = currentUser?.role === 'leaseholder'
  const schedules = state.billSchedules || []
  const dueSchedules = useMemo(
    () => schedules.filter((s) => s.active && new Date(s.nextDueDate).getTime() - Date.now() <= 7 * 86400000),
    [schedules]
  )

  const markPaid = (billId, userId, proof) => {
    update((s) => ({
      ...s,
      bills: s.bills.map((b) => {
        if (b.id !== billId) return b
        const wasPaid = !!b.paidBy[userId]
        const paidBy = { ...b.paidBy }
        const paidByProof = { ...(b.paidByProof || {}) }
        if (wasPaid) {
          delete paidBy[userId]
          delete paidByProof[userId]
        } else {
          paidBy[userId] = true
          if (proof) paidByProof[userId] = proof
        }
        const everyone = Object.keys(b.shares).every((uid) => paidBy[uid])
        return { ...b, paidBy, paidByProof, status: everyone ? 'settled' : 'pending' }
      }),
    }))
  }

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Bills</h1>
          <p>Split equal, by percentage, custom amounts, or prorated by move-in date.</p>
        </div>
        {tab === 'bills'
          ? <button className="btn" onClick={() => setEditingBill({})}>+ New bill</button>
          : isLeaseholder && <button className="btn" onClick={() => setEditingSchedule({})}>+ New schedule</button>}
      </div>

      <div className="segment" style={{ marginBottom: 16 }}>
        <button type="button" className={tab === 'bills' ? 'on' : ''} onClick={() => setTab('bills')}>Bills</button>
        <button type="button" className={tab === 'schedules' ? 'on' : ''} onClick={() => setTab('schedules')}>
          Schedules{schedules.length ? ` · ${schedules.length}` : ''}
        </button>
      </div>

      {tab === 'bills' && dueSchedules.length > 0 && (
        <div className="card" style={{ background: 'var(--surface-2)', borderColor: 'var(--accent-border)' }}>
          <div className="row" style={{ justifyContent: 'space-between' }}>
            <div>
              <div className="bold">🔔 {dueSchedules.length} scheduled bill{dueSchedules.length === 1 ? '' : 's'} due soon</div>
              <div className="tiny muted">
                {dueSchedules.slice(0, 3).map((s) => s.title).join(' · ')}
                {dueSchedules.length > 3 && ` · +${dueSchedules.length - 3} more`}
              </div>
            </div>
            <button className="btn small" onClick={() => setTab('schedules')}>Open schedules</button>
          </div>
        </div>
      )}

      {tab === 'bills' && (
        <>
          {state.bills.length === 0 && <div className="empty"><h3>No bills yet</h3><p>Add one when the next invoice arrives.</p></div>}
          {state.bills.map((b) => (
            <BillCard
              key={b.id}
              bill={b}
              onMarkPaid={markPaid}
              canManage={b.issuedBy === currentUser?.id}
              onEdit={() => setEditingBill(b)}
            />
          ))}
        </>
      )}

      {tab === 'schedules' && (
        <>
          {schedules.length === 0 && (
            <div className="empty">
              <h3>No bill schedules yet</h3>
              <p>Add electricity, NBN, water, pest control, steam cleaning — anything that arrives on a cycle. We'll remind you when each is due and let you record the actual amount with proof.</p>
            </div>
          )}
          {schedules.map((sch) => (
            <ScheduleCard
              key={sch.id}
              schedule={sch}
              canManage={sch.createdBy === currentUser?.id}
              onRecord={() => setRecordingSchedule(sch)}
              onEdit={() => setEditingSchedule(sch)}
            />
          ))}
        </>
      )}

      {editingBill && <BillModal existing={editingBill.id ? editingBill : null} onClose={() => setEditingBill(null)} />}
      {editingSchedule && <ScheduleModal existing={editingSchedule.id ? editingSchedule : null} onClose={() => setEditingSchedule(null)} />}
      {recordingSchedule && (
        <RecordBillModal
          schedule={recordingSchedule}
          onClose={() => setRecordingSchedule(null)}
        />
      )}
    </>
  )
}

function BillCard({ bill, onMarkPaid, canManage, onEdit }) {
  const { state, update, currentUser } = useHomies()
  const b = bill
  const [paying, setPaying] = useState(null)
  const remove = () => {
    if (!confirm(`Delete bill "${b.title}"? Tenants will no longer owe their share.`)) return
    update((s) => ({ ...s, bills: s.bills.filter((x) => x.id !== b.id) }))
  }
  return (
    <div className="card">
      <div className="row" style={{ alignItems: 'flex-start' }}>
        <div style={{ flex: 1 }}>
          <div className="row">
            <span className="bold" style={{ fontSize: 16 }}>{b.title}</span>
            <span className={'chip ' + (b.status === 'settled' ? 'ok' : new Date(b.dueDate) < new Date() ? 'danger' : 'warn')}>
              {b.status === 'settled' ? 'settled' : fmtRelative(b.dueDate)}
            </span>
            <span className="chip">{b.split}</span>
            {b.scheduleId && <span className="chip">🔁 scheduled</span>}
          </div>
          <div className="tiny muted">
            Due {fmtDate(b.dueDate)}
            {b.periodStart && ` · period ${fmtDate(b.periodStart)} → ${fmtDate(b.periodEnd)} (${daysBetween(b.periodStart, b.periodEnd)} days)`}
          </div>
        </div>
        <div style={{ textAlign: 'right' }}>
          <div className="bold" style={{ fontSize: 18 }}>{fmtAUD(b.amount)}</div>
          {canManage && (
            <div className="row" style={{ justifyContent: 'flex-end', marginTop: 4 }}>
              <button className="btn ghost small" onClick={remove}>Delete</button>
              <button className="btn secondary small" onClick={onEdit}>Edit</button>
            </div>
          )}
        </div>
      </div>

      {b.proof && (
        <div style={{ marginTop: 8 }}>
          <div className="tiny muted bold">Proof of bill</div>
          <Attachment value={b.proof} compact />
        </div>
      )}

      <hr />

      {Object.entries(b.shares).map(([uid, amount]) => {
        const user = state.users.find((u) => u.id === uid)
        if (!user) return null
        const paid = !!b.paidBy[uid]
        const proof = b.paidByProof?.[uid] || null
        const isYou = uid === currentUser.id
        const days = b.periodStart ? residentDays(user, b.periodStart, b.periodEnd) : null
        return (
          <div key={uid} className="row" style={{ padding: '6px 0' }}>
            <Avatar user={user} size="sm" />
            <div style={{ flex: 1 }}>
              <div className="bold tiny">{user.name}{isYou ? ' (you)' : ''}</div>
              <div className="tiny muted">
                {fmtAUD(amount)}
                {b.split === 'prorated' && days != null && ` · resident ${days} day${days === 1 ? '' : 's'}`}
              </div>
            </div>
            {proof && (
              <a href={proof.dataUrl} target="_blank" rel="noreferrer" title="View payment proof">
                {proof.type?.startsWith('image/')
                  ? <img src={proof.dataUrl} alt="" style={{ width: 28, height: 28, objectFit: 'cover', borderRadius: 4 }} />
                  : <span className="chip">📎</span>}
              </a>
            )}
            <button
              className={'btn small ' + (paid ? 'secondary' : '')}
              onClick={() => paid ? onMarkPaid(b.id, uid) : setPaying({ uid, amount })}
              disabled={!isYou && !canManage}
            >
              {paid ? '✓ Paid' : 'Mark paid'}
            </button>
          </div>
        )
      })}

      {paying && (
        <MarkPaidModal
          title={`Mark "${b.title}" as paid`}
          amountLabel={`Your share: ${fmtAUD(paying.amount)}`}
          onConfirm={(proof) => {
            onMarkPaid(b.id, paying.uid, proof)
            setPaying(null)
          }}
          onClose={() => setPaying(null)}
        />
      )}
    </div>
  )
}

function ScheduleCard({ schedule, canManage, onRecord, onEdit }) {
  const { state, update } = useHomies()
  const sch = schedule
  const chip = dueChip(sch.nextDueDate)
  const categoryLabel = CATEGORIES.find(([k]) => k === sch.category)?.[1] || '📌'

  const toggleActive = () => {
    update((s) => ({
      ...s,
      billSchedules: s.billSchedules.map((x) => x.id === sch.id ? { ...x, active: !x.active } : x),
    }))
  }
  const remove = () => {
    if (!confirm(`Delete schedule "${sch.title}"?`)) return
    update((s) => ({ ...s, billSchedules: s.billSchedules.filter((x) => x.id !== sch.id) }))
  }

  return (
    <div className="card">
      <div className="row" style={{ alignItems: 'flex-start' }}>
        <div style={{ flex: 1 }}>
          <div className="row">
            <span className="bold" style={{ fontSize: 16 }}>{sch.title}</span>
            <span className="chip">{categoryLabel}</span>
            <span className="chip">{cadenceLabelFull(sch.cadence, sch.customDays)}</span>
            {sch.active
              ? <span className={'chip ' + chip.cls}>{chip.label}</span>
              : <span className="chip">paused</span>}
          </div>
          <div className="tiny muted">
            Next: {fmtDate(sch.nextDueDate)} · period {fmtDate(sch.cycleStart)} → {fmtDate(sch.nextDueDate)}
            {sch.estimatedAmount ? ` · est. ${fmtAUD(sch.estimatedAmount)}` : ''}
          </div>
        </div>
        <div className="bold" style={{ fontSize: 16 }}>{fmtAUD(sch.estimatedAmount)}</div>
      </div>

      <div className="row" style={{ marginTop: 8 }}>
        <span className="tiny muted">Splits between:</span>
        {sch.participants.map((id) => {
          const u = state.users.find((x) => x.id === id)
          return u ? <Avatar key={id} user={u} size="sm" /> : null
        })}
        <span className="tiny muted">· {sch.splitMethod}</span>
      </div>

      {canManage && (
        <>
          <hr />
          <div className="row" style={{ justifyContent: 'flex-end' }}>
            <button className="btn ghost small" onClick={remove}>Delete</button>
            <button className="btn secondary small" onClick={onEdit}>Edit</button>
            <button className="btn secondary small" onClick={toggleActive}>{sch.active ? 'Pause' : 'Resume'}</button>
            <button className="btn small" onClick={onRecord} disabled={!sch.active}>📸 Record bill</button>
          </div>
        </>
      )}
    </div>
  )
}

function BillModal({ onClose, existing }) {
  const { state, update, currentUser } = useHomies()
  const housemates = state.users.filter((u) => !u.pending && !u.moveOutDate)
  const hasMixedMoveIns = housemates.some((u) => u.moveInDate !== housemates[0]?.moveInDate)
  const isEdit = !!existing

  const initialCustom = isEdit && (existing.split === 'percentage' || existing.split === 'custom')
    ? Object.fromEntries(Object.entries(existing.shares).map(([id, amt]) => {
        if (existing.split === 'percentage') {
          const pct = existing.amount ? Math.round((amt / existing.amount) * 100) : 0
          return [id, String(pct)]
        }
        return [id, String(amt)]
      }))
    : {}

  const [draft, setDraft] = useState(isEdit ? {
    title: existing.title || '',
    category: existing.category || 'utility',
    amount: String(existing.amount ?? ''),
    dueDate: existing.dueDate || '',
    periodStart: existing.periodStart || '',
    periodEnd: existing.periodEnd || '',
    split: existing.split || 'equal',
    participants: Object.keys(existing.shares || {}),
    custom: initialCustom,
    proof: existing.proof || null,
  } : {
    title: '',
    category: 'utility',
    amount: '',
    dueDate: '',
    periodStart: '',
    periodEnd: '',
    split: hasMixedMoveIns ? 'prorated' : 'equal',
    participants: housemates.map((u) => u.id),
    custom: {},
    proof: null,
  })

  const setF = (k, v) => setDraft((d) => ({ ...d, [k]: v }))
  const toggleP = (id) => {
    const p = draft.participants.includes(id) ? draft.participants.filter((x) => x !== id) : [...draft.participants, id]
    setF('participants', p)
  }

  const computeShares = () => {
    const total = Number(draft.amount) || 0
    if (draft.split === 'equal') {
      const arr = equalSplit(total, draft.participants.length)
      return draft.participants.reduce((acc, id, i) => ({ ...acc, [id]: arr[i] }), {})
    }
    if (draft.split === 'prorated') {
      if (!draft.periodStart || !draft.periodEnd) return {}
      return prorateShares(total, draft.participants, state.users, draft.periodStart, draft.periodEnd)
    }
    if (draft.split === 'percentage') {
      return draft.participants.reduce((acc, id) => {
        const pct = Number(draft.custom[id] || 0) / 100
        return { ...acc, [id]: Math.round(total * pct * 100) / 100 }
      }, {})
    }
    return draft.participants.reduce((acc, id) => ({ ...acc, [id]: Number(draft.custom[id] || 0) }), {})
  }

  const sharesPreview = computeShares()
  const totalSplit = Object.values(sharesPreview).reduce((a, b) => a + b, 0)

  const save = () => {
    update((s) => {
      if (isEdit) {
        const newShareUids = Object.keys(sharesPreview)
        const paidBy = Object.fromEntries(
          Object.entries(existing.paidBy || {}).filter(([uid]) => newShareUids.includes(uid))
        )
        const paidByProof = Object.fromEntries(
          Object.entries(existing.paidByProof || {}).filter(([uid]) => newShareUids.includes(uid))
        )
        const everyone = newShareUids.length > 0 && newShareUids.every((uid) => paidBy[uid])
        return {
          ...s,
          bills: s.bills.map((b) => b.id === existing.id ? {
            ...b,
            title: draft.title,
            category: draft.category,
            amount: Number(draft.amount) || 0,
            periodStart: draft.periodStart || null,
            periodEnd: draft.periodEnd || null,
            dueDate: draft.dueDate,
            split: draft.split,
            shares: sharesPreview,
            paidBy,
            paidByProof,
            proof: draft.proof,
            status: everyone ? 'settled' : 'pending',
          } : b),
        }
      }
      const id = 'b-' + Math.random().toString(36).slice(2, 6)
      return {
        ...s,
        bills: [...s.bills, {
          id,
          title: draft.title,
          category: draft.category,
          amount: Number(draft.amount) || 0,
          periodStart: draft.periodStart || null,
          periodEnd: draft.periodEnd || null,
          dueDate: draft.dueDate,
          issuedBy: currentUser.id,
          split: draft.split,
          shares: sharesPreview,
          status: 'pending',
          paidBy: {},
          paidByProof: {},
          proof: draft.proof,
        }],
      }
    })
    onClose()
  }

  return (
    <div className="modal-bg" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()} style={{ maxWidth: 600 }}>
        <h2>{isEdit ? 'Edit bill' : 'New bill'}</h2>

        <div className="field">
          <label>Title</label>
          <input type="text" value={draft.title} onChange={(e) => setF('title', e.target.value)} placeholder="Electricity — AGL (Dec–Feb)" />
        </div>

        <div className="field-row">
          <div className="field">
            <label>Category</label>
            <select value={draft.category} onChange={(e) => setF('category', e.target.value)}>
              {CATEGORIES.map(([v, l]) => <option key={v} value={v}>{l}</option>)}
            </select>
          </div>
          <div className="field">
            <label>Total amount</label>
            <input type="number" min="0" step="0.01" value={draft.amount} onChange={(e) => setF('amount', e.target.value)} />
          </div>
          <div className="field">
            <label>Due date</label>
            <input type="date" value={draft.dueDate} onChange={(e) => setF('dueDate', e.target.value)} />
          </div>
        </div>

        <div className="field-row">
          <div className="field">
            <label>Period start (optional)</label>
            <input type="date" value={draft.periodStart} onChange={(e) => setF('periodStart', e.target.value)} />
          </div>
          <div className="field">
            <label>Period end (optional)</label>
            <input type="date" value={draft.periodEnd} onChange={(e) => setF('periodEnd', e.target.value)} />
          </div>
        </div>
        <span className="hint" style={{ marginTop: -8, marginBottom: 14, display: 'block' }}>
          Required if splitting prorated — used to charge each housemate only for the days they were resident.
        </span>

        <div className="field">
          <label>Who pays</label>
          <div className="checkbox-grid">
            {housemates.map((u) => (
              <label key={u.id}>
                <input type="checkbox" checked={draft.participants.includes(u.id)} onChange={() => toggleP(u.id)} />
                <Avatar user={u} size="sm" /> {u.name}
              </label>
            ))}
          </div>
        </div>

        <div className="field">
          <label>Split method</label>
          <div className="segment">
            {['equal', 'prorated', 'percentage', 'custom'].map((m) => (
              <button type="button" key={m} className={draft.split === m ? 'on' : ''} onClick={() => setF('split', m)}>
                {m[0].toUpperCase() + m.slice(1)}
              </button>
            ))}
          </div>
          {draft.split === 'prorated' && (
            <span className="hint">Each person pays a share proportional to days they were resident during the bill period.</span>
          )}
        </div>

        {(draft.split === 'percentage' || draft.split === 'custom') && (
          <div className="field">
            <label>Per-person {draft.split === 'percentage' ? '%' : 'amount'}</label>
            {draft.participants.map((id) => {
              const u = state.users.find((x) => x.id === id)
              if (!u) return null
              return (
                <div key={id} className="row" style={{ marginBottom: 6 }}>
                  <Avatar user={u} size="sm" />
                  <span style={{ flex: 1 }}>{u.name}</span>
                  <input
                    type="number"
                    min="0"
                    step={draft.split === 'percentage' ? '1' : '0.01'}
                    value={draft.custom[id] || ''}
                    onChange={(e) => setF('custom', { ...draft.custom, [id]: e.target.value })}
                    style={{ width: 100, padding: '6px 10px', border: '1px solid var(--border-strong)', borderRadius: 'var(--radius-sm)' }}
                  />
                </div>
              )
            })}
          </div>
        )}

        <div className="field">
          <label>Photo of the bill <span className="hint">(optional — invoice screenshot, paper bill)</span></label>
          <FilePicker value={draft.proof} onChange={(v) => setF('proof', v)} />
        </div>

        <div className="card" style={{ background: 'var(--surface-2)' }}>
          <div className="tiny muted bold mb">Preview</div>
          {draft.split === 'prorated' && (!draft.periodStart || !draft.periodEnd) ? (
            <div className="chip warn">Set a period above to compute the prorated split.</div>
          ) : (
            <>
              {Object.entries(sharesPreview).map(([id, amt]) => {
                const u = state.users.find((x) => x.id === id)
                const days = draft.split === 'prorated' && draft.periodStart ? residentDays(u, draft.periodStart, draft.periodEnd) : null
                return (
                  <div key={id} className="row" style={{ justifyContent: 'space-between' }}>
                    <span>{u?.name}{days != null && <span className="faint tiny"> · {days} d</span>}</span>
                    <span className="bold">{fmtAUD(amt)}</span>
                  </div>
                )
              })}
              <hr />
              <div className="row" style={{ justifyContent: 'space-between' }}>
                <span className="bold">Split total</span>
                <span className="bold">{fmtAUD(totalSplit)}</span>
              </div>
              {Math.abs(totalSplit - (Number(draft.amount) || 0)) > 0.05 && (
                <div className="chip warn mt">Split doesn't add up to {fmtAUD(Number(draft.amount) || 0)}</div>
              )}
            </>
          )}
        </div>

        <div className="modal-actions">
          <button className="btn secondary" onClick={onClose}>Cancel</button>
          <button
            className="btn"
            onClick={save}
            disabled={!draft.title || !draft.amount || !draft.dueDate || (draft.split === 'prorated' && (!draft.periodStart || !draft.periodEnd))}
          >
            {isEdit ? 'Save changes' : 'Create bill'}
          </button>
        </div>
      </div>
    </div>
  )
}

function ScheduleModal({ onClose, existing }) {
  const { state, update, currentUser } = useHomies()
  const housemates = state.users.filter((u) => !u.pending && !u.moveOutDate)
  const isEdit = !!existing

  const [draft, setDraft] = useState(isEdit ? {
    title: existing.title || '',
    category: existing.category || 'utility',
    cadence: existing.cadence || 'quarterly',
    customDays: existing.customDays != null ? String(existing.customDays) : '',
    nextDueDate: existing.nextDueDate || '',
    estimatedAmount: existing.estimatedAmount ? String(existing.estimatedAmount) : '',
    splitMethod: existing.splitMethod || 'prorated',
    participants: existing.participants || housemates.map((u) => u.id),
  } : {
    title: '',
    category: 'utility',
    cadence: 'quarterly',
    customDays: '',
    nextDueDate: '',
    estimatedAmount: '',
    splitMethod: 'prorated',
    participants: housemates.map((u) => u.id),
  })

  const setF = (k, v) => setDraft((d) => ({ ...d, [k]: v }))
  const toggleP = (id) => setF(
    'participants',
    draft.participants.includes(id) ? draft.participants.filter((x) => x !== id) : [...draft.participants, id]
  )

  const cycleStartPreview = draft.nextDueDate
    ? subtractCadence(draft.nextDueDate, draft.cadence, draft.customDays)
    : ''

  const canSave = !!draft.title
    && !!draft.nextDueDate
    && draft.participants.length > 0
    && (draft.cadence !== 'custom' || Number(draft.customDays) > 0)

  const save = () => {
    update((s) => {
      if (isEdit) {
        return {
          ...s,
          billSchedules: s.billSchedules.map((x) => x.id === existing.id ? {
            ...x,
            title: draft.title,
            category: draft.category,
            cadence: draft.cadence,
            customDays: draft.cadence === 'custom' ? Number(draft.customDays) : null,
            cycleStart: cycleStartPreview,
            nextDueDate: draft.nextDueDate,
            estimatedAmount: Number(draft.estimatedAmount) || 0,
            splitMethod: draft.splitMethod,
            participants: draft.participants,
          } : x),
        }
      }
      return {
        ...s,
        billSchedules: [
          ...(s.billSchedules || []),
          {
            id: 'sch-' + Math.random().toString(36).slice(2, 6),
            title: draft.title,
            category: draft.category,
            cadence: draft.cadence,
            customDays: draft.cadence === 'custom' ? Number(draft.customDays) : null,
            cycleStart: cycleStartPreview,
            nextDueDate: draft.nextDueDate,
            estimatedAmount: Number(draft.estimatedAmount) || 0,
            splitMethod: draft.splitMethod,
            participants: draft.participants,
            active: true,
            createdBy: currentUser.id,
          },
        ],
      }
    })
    onClose()
  }

  return (
    <div className="modal-bg" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()} style={{ maxWidth: 600 }}>
        <h2>{isEdit ? 'Edit bill schedule' : 'New bill schedule'}</h2>
        <p className="tiny muted">Set up a recurring bill — electricity, NBN, water, pest control, steam cleaning, anything that arrives on a cycle. We'll surface it on the dashboard when it's due and let you record the actual amount + proof.</p>

        <div className="field">
          <label>Title</label>
          <input type="text" value={draft.title} onChange={(e) => setF('title', e.target.value)} placeholder="Electricity — AGL" />
        </div>

        <div className="field-row">
          <div className="field">
            <label>Category</label>
            <select value={draft.category} onChange={(e) => setF('category', e.target.value)}>
              {CATEGORIES.map(([v, l]) => <option key={v} value={v}>{l}</option>)}
            </select>
          </div>
          <div className="field">
            <label>Cadence</label>
            <select value={draft.cadence} onChange={(e) => setF('cadence', e.target.value)}>
              {CADENCES.map((c) => <option key={c} value={c}>{cadenceLabelFull(c, '?')}</option>)}
            </select>
          </div>
          {draft.cadence === 'custom' && (
            <div className="field">
              <label>Every N days</label>
              <input type="number" min="1" step="1" value={draft.customDays} onChange={(e) => setF('customDays', e.target.value)} />
            </div>
          )}
        </div>

        <div className="field-row">
          <div className="field">
            <label>Next due date</label>
            <input type="date" value={draft.nextDueDate} onChange={(e) => setF('nextDueDate', e.target.value)} />
          </div>
          <div className="field">
            <label>Estimated amount (optional)</label>
            <input type="number" min="0" step="0.01" value={draft.estimatedAmount} onChange={(e) => setF('estimatedAmount', e.target.value)} placeholder="420.00" />
          </div>
        </div>
        {cycleStartPreview && (
          <span className="hint" style={{ marginTop: -8, marginBottom: 14, display: 'block' }}>
            Period for the first invoice: {fmtDate(cycleStartPreview)} → {fmtDate(draft.nextDueDate)}.
          </span>
        )}

        <div className="field">
          <label>Default split</label>
          <div className="segment">
            {['equal', 'prorated'].map((m) => (
              <button type="button" key={m} className={draft.splitMethod === m ? 'on' : ''} onClick={() => setF('splitMethod', m)}>
                {m[0].toUpperCase() + m.slice(1)}
              </button>
            ))}
          </div>
          <span className="hint">You can still change the split when you record each bill.</span>
        </div>

        <div className="field">
          <label>Splits between</label>
          <div className="checkbox-grid">
            {housemates.map((u) => (
              <label key={u.id}>
                <input type="checkbox" checked={draft.participants.includes(u.id)} onChange={() => toggleP(u.id)} />
                <Avatar user={u} size="sm" /> {u.name}
              </label>
            ))}
          </div>
        </div>

        <div className="modal-actions">
          <button className="btn secondary" onClick={onClose}>Cancel</button>
          <button className="btn" onClick={save} disabled={!canSave}>{isEdit ? 'Save changes' : 'Create schedule'}</button>
        </div>
      </div>
    </div>
  )
}

function RecordBillModal({ schedule, onClose }) {
  const { state, update, currentUser } = useHomies()
  const sch = schedule
  const today = new Date().toISOString().slice(0, 10)

  const [draft, setDraft] = useState({
    amount: sch.estimatedAmount ? String(sch.estimatedAmount) : '',
    dueDate: today,
    periodStart: sch.cycleStart,
    periodEnd: sch.nextDueDate,
    split: sch.splitMethod,
    participants: sch.participants,
    custom: {},
    proof: null,
    advanceCycle: true,
  })
  const setF = (k, v) => setDraft((d) => ({ ...d, [k]: v }))
  const toggleP = (id) => setF(
    'participants',
    draft.participants.includes(id) ? draft.participants.filter((x) => x !== id) : [...draft.participants, id]
  )

  const housemates = state.users.filter((u) => !u.pending && !u.moveOutDate)

  const computeShares = () => {
    const total = Number(draft.amount) || 0
    if (draft.split === 'equal') {
      const arr = equalSplit(total, draft.participants.length)
      return draft.participants.reduce((acc, id, i) => ({ ...acc, [id]: arr[i] }), {})
    }
    if (draft.split === 'prorated') {
      if (!draft.periodStart || !draft.periodEnd) return {}
      return prorateShares(total, draft.participants, state.users, draft.periodStart, draft.periodEnd)
    }
    if (draft.split === 'percentage') {
      return draft.participants.reduce((acc, id) => {
        const pct = Number(draft.custom[id] || 0) / 100
        return { ...acc, [id]: Math.round(total * pct * 100) / 100 }
      }, {})
    }
    return draft.participants.reduce((acc, id) => ({ ...acc, [id]: Number(draft.custom[id] || 0) }), {})
  }

  const sharesPreview = computeShares()
  const totalSplit = Object.values(sharesPreview).reduce((a, b) => a + b, 0)

  const canSave = !!draft.amount && !!draft.dueDate && draft.participants.length > 0

  const save = () => {
    const id = 'b-' + Math.random().toString(36).slice(2, 6)
    const newNextDue = addCadence(sch.nextDueDate, sch.cadence, sch.customDays)
    update((s) => ({
      ...s,
      bills: [...s.bills, {
        id,
        title: `${sch.title} — ${fmtDate(draft.periodStart)} → ${fmtDate(draft.periodEnd)}`,
        category: sch.category,
        amount: Number(draft.amount) || 0,
        periodStart: draft.periodStart || null,
        periodEnd: draft.periodEnd || null,
        dueDate: draft.dueDate,
        issuedBy: currentUser.id,
        split: draft.split,
        shares: sharesPreview,
        status: 'pending',
        paidBy: {},
        paidByProof: {},
        scheduleId: sch.id,
        proof: draft.proof,
      }],
      billSchedules: draft.advanceCycle
        ? s.billSchedules.map((x) => x.id === sch.id
            ? { ...x, cycleStart: sch.nextDueDate, nextDueDate: newNextDue }
            : x)
        : s.billSchedules,
    }))
    onClose()
  }

  return (
    <div className="modal-bg" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()} style={{ maxWidth: 600 }}>
        <h2>Record {sch.title}</h2>
        <p className="tiny muted">Enter the actual amount on the invoice, attach proof, and the share for each housemate is created automatically.</p>

        <div className="field-row">
          <div className="field">
            <label>Actual amount</label>
            <input type="number" min="0" step="0.01" value={draft.amount} onChange={(e) => setF('amount', e.target.value)} />
          </div>
          <div className="field">
            <label>Due date</label>
            <input type="date" value={draft.dueDate} onChange={(e) => setF('dueDate', e.target.value)} />
          </div>
        </div>

        <div className="field-row">
          <div className="field">
            <label>Period start</label>
            <input type="date" value={draft.periodStart} onChange={(e) => setF('periodStart', e.target.value)} />
          </div>
          <div className="field">
            <label>Period end</label>
            <input type="date" value={draft.periodEnd} onChange={(e) => setF('periodEnd', e.target.value)} />
          </div>
        </div>

        <div className="field">
          <label>Proof of bill (image or PDF)</label>
          <FilePicker value={draft.proof} onChange={(v) => setF('proof', v)} />
          <span className="hint">Optional but recommended — housemates can tap to view.</span>
        </div>

        <div className="field">
          <label>Splits between</label>
          <div className="checkbox-grid">
            {housemates.map((u) => (
              <label key={u.id}>
                <input type="checkbox" checked={draft.participants.includes(u.id)} onChange={() => toggleP(u.id)} />
                <Avatar user={u} size="sm" /> {u.name}
              </label>
            ))}
          </div>
        </div>

        <div className="field">
          <label>Split method</label>
          <div className="segment">
            {['equal', 'prorated', 'percentage', 'custom'].map((m) => (
              <button type="button" key={m} className={draft.split === m ? 'on' : ''} onClick={() => setF('split', m)}>
                {m[0].toUpperCase() + m.slice(1)}
              </button>
            ))}
          </div>
        </div>

        {(draft.split === 'percentage' || draft.split === 'custom') && (
          <div className="field">
            <label>Per-person {draft.split === 'percentage' ? '%' : 'amount'}</label>
            {draft.participants.map((id) => {
              const u = state.users.find((x) => x.id === id)
              if (!u) return null
              return (
                <div key={id} className="row" style={{ marginBottom: 6 }}>
                  <Avatar user={u} size="sm" />
                  <span style={{ flex: 1 }}>{u.name}</span>
                  <input
                    type="number"
                    min="0"
                    step={draft.split === 'percentage' ? '1' : '0.01'}
                    value={draft.custom[id] || ''}
                    onChange={(e) => setF('custom', { ...draft.custom, [id]: e.target.value })}
                    style={{ width: 100, padding: '6px 10px', border: '1px solid var(--border-strong)', borderRadius: 'var(--radius-sm)' }}
                  />
                </div>
              )
            })}
          </div>
        )}

        <div className="card" style={{ background: 'var(--surface-2)' }}>
          <div className="tiny muted bold mb">Preview</div>
          {draft.split === 'prorated' && (!draft.periodStart || !draft.periodEnd) ? (
            <div className="chip warn">Set a period above to compute the prorated split.</div>
          ) : (
            <>
              {Object.entries(sharesPreview).map(([id, amt]) => {
                const u = state.users.find((x) => x.id === id)
                const days = draft.split === 'prorated' && draft.periodStart ? residentDays(u, draft.periodStart, draft.periodEnd) : null
                return (
                  <div key={id} className="row" style={{ justifyContent: 'space-between' }}>
                    <span>{u?.name}{days != null && <span className="faint tiny"> · {days} d</span>}</span>
                    <span className="bold">{fmtAUD(amt)}</span>
                  </div>
                )
              })}
              <hr />
              <div className="row" style={{ justifyContent: 'space-between' }}>
                <span className="bold">Split total</span>
                <span className="bold">{fmtAUD(totalSplit)}</span>
              </div>
              {Math.abs(totalSplit - (Number(draft.amount) || 0)) > 0.05 && (
                <div className="chip warn mt">Split doesn't add up to {fmtAUD(Number(draft.amount) || 0)}</div>
              )}
            </>
          )}
        </div>

        <label className="row" style={{ marginTop: 12 }}>
          <input type="checkbox" checked={draft.advanceCycle} onChange={(e) => setF('advanceCycle', e.target.checked)} />
          <span className="tiny">
            Advance schedule to next cycle (next due: {fmtDate(addCadence(sch.nextDueDate, sch.cadence, sch.customDays))})
          </span>
        </label>

        <div className="modal-actions">
          <button className="btn secondary" onClick={onClose}>Cancel</button>
          <button className="btn" onClick={save} disabled={!canSave}>Record bill & split</button>
        </div>
      </div>
    </div>
  )
}
