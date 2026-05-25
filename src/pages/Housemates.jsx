import { useState } from 'react'
import { useHomies } from '../context/HomiesContext.jsx'
import { Avatar } from '../components/Avatar.jsx'
import { Attachment } from '../components/FilePicker.jsx'
import { fmtAUD, fmtDate } from '../lib/format.js'
import { isApprovalComplete } from '../lib/format.js'

export function Housemates() {
  const { state, update, currentUser } = useHomies()
  const [showInvite, setShowInvite] = useState(false)
  const [inviteEmail, setInviteEmail] = useState('')
  const [inviteRole, setInviteRole] = useState('tenant')

  const isLeaseholder = currentUser.role === 'leaseholder'

  const removeUser = (id) => {
    if (!confirm('Remove this housemate? They\'ll lose access immediately.')) return
    update((s) => ({ ...s, users: s.users.filter((u) => u.id !== id) }))
  }

  const setFlag = (id, flag) => {
    update((s) => ({
      ...s,
      users: s.users.map((u) => {
        if (u.id !== id) return u
        const next = { ...u, [flag]: true }
        if (next.docVerified && next.bondPaid && next.advanceRentPaid && next.acceptedRulesAt && next.moveInDate) {
          next.pending = false
        }
        return next
      }),
    }))
  }

  const rejectFlag = (id, flag) => {
    update((s) => ({
      ...s,
      users: s.users.map((u) => u.id === id ? { ...u, [flag]: false } : u),
    }))
  }

  const sendInvite = () => {
    if (!inviteEmail.trim()) return
    const code = 'HMI-' + Math.random().toString(36).slice(2, 6).toUpperCase()
    update((s) => ({
      ...s,
      invites: [...s.invites, {
        code,
        email: inviteEmail.trim(),
        role: inviteRole,
        sentAt: new Date().toISOString().slice(0, 10),
        status: 'sent',
      }],
    }))
    setInviteEmail('')
    setShowInvite(false)
  }

  const awaitingApproval = state.users.filter((u) => u.pending && u.submissions)

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Housemates</h1>
          <p>Who's living here, who's awaiting approval, and who's still on invite.</p>
        </div>
        {isLeaseholder && (
          <button className="btn" onClick={() => setShowInvite(true)}>+ Invite</button>
        )}
      </div>

      {awaitingApproval.length > 0 && isLeaseholder && (
        <>
          <h2 style={{ marginTop: 8 }}>⏳ Awaiting your approval</h2>
          {awaitingApproval.map((u) => (
            <ApprovalCard key={u.id} user={u} onApprove={setFlag} onReject={rejectFlag} />
          ))}
          <hr />
          <h2>Active housemates</h2>
        </>
      )}

      {state.users.filter((u) => !u.pending || !u.submissions).map((u) => (
        <div className="card" key={u.id}>
          <div className="row" style={{ gap: 14 }}>
            <Avatar user={u} size="lg" />
            <div style={{ flex: 1 }}>
              <div className="row">
                <span className="bold">{u.name}</span>
                <span className={'chip ' + (u.role === 'leaseholder' ? 'accent' : 'info')}>{u.role}</span>
                {u.pending && !u.submissions && <span className="chip warn">invited</span>}
                {u.moveOutDate && <span className="chip">moving out {fmtDate(u.moveOutDate)}</span>}
                {isApprovalComplete(u) && <span className="chip ok">active</span>}
              </div>
              <div className="tiny muted">{u.email} · {u.phone}</div>
              <div className="tiny muted">
                {u.moveInDate ? `Moved in ${fmtDate(u.moveInDate)}` : 'Not moved in yet'}
                {u.bondPaid ? ` · bond ${fmtAUD(u.bondAmount)}` : ''}
              </div>
            </div>
            {isLeaseholder && u.id !== currentUser.id && (
              <button className="btn small ghost" onClick={() => removeUser(u.id)} style={{ color: 'var(--danger)' }}>Remove</button>
            )}
          </div>
        </div>
      ))}

      {state.invites.length > 0 && (
        <div className="card">
          <h2>Pending invites</h2>
          {state.invites.map((i) => (
            <div key={i.code} className="row" style={{ padding: '8px 0', borderTop: '1px solid var(--border)' }}>
              <div style={{ flex: 1 }}>
                <div className="bold">{i.email}</div>
                <div className="tiny muted">{i.role} · code {i.code} · sent {fmtDate(i.sentAt)}</div>
              </div>
              <a href={`/invite/${i.code}`} className="btn small secondary" target="_blank" rel="noreferrer">Open link</a>
            </div>
          ))}
        </div>
      )}

      {showInvite && (
        <div className="modal-bg" onClick={() => setShowInvite(false)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <h2>Invite a housemate</h2>
            <div className="field">
              <label>Email</label>
              <input type="email" value={inviteEmail} onChange={(e) => setInviteEmail(e.target.value)} placeholder="housemate@example.com" />
            </div>
            <div className="field">
              <label>Role</label>
              <div className="segment">
                <button type="button" className={inviteRole === 'tenant' ? 'on' : ''} onClick={() => setInviteRole('tenant')}>Tenant</button>
                <button type="button" className={inviteRole === 'leaseholder' ? 'on' : ''} onClick={() => setInviteRole('leaseholder')}>Co-leaseholder</button>
              </div>
            </div>
            <div className="modal-actions">
              <button className="btn secondary" onClick={() => setShowInvite(false)}>Cancel</button>
              <button className="btn" onClick={sendInvite} disabled={!inviteEmail.trim()}>Send invite</button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}

function ApprovalCard({ user, onApprove, onReject }) {
  const subs = user.submissions || {}
  return (
    <div className="card" style={{ borderColor: 'var(--warn-soft)', background: 'var(--surface)' }}>
      <div className="row" style={{ gap: 14 }}>
        <Avatar user={user} size="lg" />
        <div style={{ flex: 1 }}>
          <div className="row">
            <span className="bold">{user.name}</span>
            <span className="chip warn">awaiting approval</span>
          </div>
          <div className="tiny muted">{user.email} · {user.phone}</div>
          <div className="tiny muted">
            Planned move-in {user.moveInDate ? fmtDate(user.moveInDate) : '—'}
            {user.acceptedRulesAt && ` · rules accepted ${fmtDate(user.acceptedRulesAt)}`}
          </div>
        </div>
      </div>

      <hr />

      <ApprovalRow
        title="ID document"
        sub={subs.idDoc ? `${(subs.idDoc.kind || '').replace('-', ' ')}` : 'No submission'}
        attachment={subs.idDoc}
        approved={user.docVerified}
        onApprove={() => onApprove(user.id, 'docVerified')}
        onReject={() => onReject(user.id, 'docVerified')}
      />

      <ApprovalRow
        title={`Bond — ${fmtAUD(user.bondAmount || 0)}`}
        sub={subs.bondProof ? `paid via ${subs.bondProof.method}` : 'No submission'}
        attachment={subs.bondProof}
        approved={user.bondPaid}
        onApprove={() => onApprove(user.id, 'bondPaid')}
        onReject={() => onReject(user.id, 'bondPaid')}
      />

      <ApprovalRow
        title="Advance rent"
        sub={subs.advanceRentProof ? `paid via ${subs.advanceRentProof.method}` : 'No submission'}
        attachment={subs.advanceRentProof}
        approved={user.advanceRentPaid}
        onApprove={() => onApprove(user.id, 'advanceRentPaid')}
        onReject={() => onReject(user.id, 'advanceRentPaid')}
      />

      <div className="tiny muted mt">
        Approving all three above will make {user.name.split(' ')[0]} an active housemate.
      </div>
    </div>
  )
}

function ApprovalRow({ title, sub, attachment, approved, onApprove, onReject }) {
  return (
    <div className="row" style={{ padding: '10px 0', borderTop: '1px solid var(--border)', alignItems: 'flex-start' }}>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div className="bold tiny">{title}</div>
        <div className="tiny muted">{sub}</div>
        {attachment && <Attachment value={attachment} compact />}
      </div>
      {approved ? (
        <div className="row">
          <span className="chip ok">approved</span>
          <button className="btn ghost small" onClick={onReject}>Revoke</button>
        </div>
      ) : (
        <div className="row">
          <button className="btn small" onClick={onApprove} disabled={!attachment}>Approve</button>
        </div>
      )}
    </div>
  )
}
