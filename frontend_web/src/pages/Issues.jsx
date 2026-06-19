import { useState } from 'react'
import { useHomies } from '../context/HomiesContext.jsx'
import { Avatar } from '../components/Avatar.jsx'
import { FilePicker, Attachment } from '../components/FilePicker.jsx'
import { fmtDate } from '../lib/format.js'

const CATEGORIES = [
  ['plumbing', '🚿 Plumbing'],
  ['appliance', '🧊 Appliance'],
  ['electrical', '💡 Electrical'],
  ['structure', '🏠 Structure'],
  ['pest', '🐜 Pest'],
  ['other', '📌 Other'],
]

const labelFor = (key) => CATEGORIES.find(([k]) => k === key)?.[1] || '📌 Other'

export function Issues() {
  const { state, update, currentUser } = useHomies()
  const [editing, setEditing] = useState(null)

  const issues = state.issues || []
  const open = issues.filter((i) => i.status === 'open')
  const fixed = issues.filter((i) => i.status === 'fixed')

  const markFixed = (id) => {
    update((s) => ({
      ...s,
      issues: (s.issues || []).map((i) =>
        i.id === id
          ? { ...i, status: 'fixed', fixedAt: new Date().toISOString().slice(0, 10), fixedBy: currentUser.id }
          : i,
      ),
    }))
  }

  const reopen = (id) => {
    update((s) => ({
      ...s,
      issues: (s.issues || []).map((i) =>
        i.id === id ? { ...i, status: 'open', fixedAt: null, fixedBy: null } : i,
      ),
    }))
  }

  const remove = (issue) => {
    if (!confirm(`Delete "${issue.title}"?`)) return
    update((s) => ({ ...s, issues: (s.issues || []).filter((i) => i.id !== issue.id) }))
  }

  return (
    <>
      <div className="page-head">
        <div>
          <h1>House issues</h1>
          <p>Broken stuff, leaks, dodgy appliances — anyone can raise an issue and mark it fixed once sorted.</p>
        </div>
        <button className="btn" onClick={() => setEditing({})}>+ Raise an issue</button>
      </div>

      {issues.length === 0 && (
        <div className="empty">
          <h3>No issues raised</h3>
          <p>Tap "Raise an issue" when something needs fixing.</p>
        </div>
      )}

      {open.length > 0 && (
        <>
          <h2 style={{ marginTop: 8 }}>Open · {open.length}</h2>
          {open.map((i) => (
            <IssueCard
              key={i.id}
              issue={i}
              canEdit={i.raisedBy === currentUser.id}
              onEdit={() => setEditing(i)}
              onDelete={() => remove(i)}
              onFix={() => markFixed(i.id)}
            />
          ))}
        </>
      )}

      {fixed.length > 0 && (
        <>
          <h2 style={{ marginTop: 16 }}>Fixed · {fixed.length}</h2>
          {fixed.map((i) => (
            <IssueCard
              key={i.id}
              issue={i}
              canEdit={i.raisedBy === currentUser.id}
              onEdit={() => setEditing(i)}
              onDelete={() => remove(i)}
              onReopen={() => reopen(i.id)}
            />
          ))}
        </>
      )}

      {editing && <IssueModal existing={editing.id ? editing : null} onClose={() => setEditing(null)} />}
    </>
  )
}

function IssueCard({ issue, canEdit, onEdit, onDelete, onFix, onReopen }) {
  const { state } = useHomies()
  const raisedBy = state.users.find((u) => u.id === issue.raisedBy)
  const fixedBy = issue.fixedBy ? state.users.find((u) => u.id === issue.fixedBy) : null
  const isOpen = issue.status === 'open'

  return (
    <div className="card" style={{ background: isOpen ? 'var(--surface)' : 'var(--surface-2)' }}>
      <div className="row" style={{ alignItems: 'flex-start' }}>
        <div style={{ flex: 1 }}>
          <div className="row">
            <span className="bold" style={{ fontSize: 16 }}>{issue.title}</span>
            <span className={'chip ' + (isOpen ? 'warn' : 'ok')}>{isOpen ? 'open' : 'fixed'}</span>
            <span className="chip">{labelFor(issue.category)}</span>
          </div>
          <div className="tiny muted">
            Raised by {raisedBy?.name || '—'} · {fmtDate(issue.raisedAt)}
            {!isOpen && fixedBy && ` · fixed by ${fixedBy.name} on ${fmtDate(issue.fixedAt)}`}
          </div>
          {issue.description && <p className="mt" style={{ marginBottom: 0 }}>{issue.description}</p>}
        </div>
        <Avatar user={raisedBy} size="sm" />
      </div>

      {issue.photo && (
        <div style={{ marginTop: 8 }}>
          <Attachment value={issue.photo} compact />
        </div>
      )}

      <div className="row mt" style={{ justifyContent: 'flex-end' }}>
        {canEdit && <button className="btn ghost small" onClick={onDelete}>Delete</button>}
        {canEdit && <button className="btn secondary small" onClick={onEdit}>Edit</button>}
        {isOpen
          ? <button className="btn small" onClick={onFix}>✓ Mark fixed</button>
          : <button className="btn secondary small" onClick={onReopen}>Reopen</button>}
      </div>
    </div>
  )
}

function IssueModal({ existing, onClose }) {
  const { update, currentUser } = useHomies()
  const isEdit = !!existing

  const [draft, setDraft] = useState(isEdit ? {
    title: existing.title || '',
    category: existing.category || 'other',
    description: existing.description || '',
    photo: existing.photo || null,
  } : {
    title: '',
    category: 'other',
    description: '',
    photo: null,
  })

  const setF = (k, v) => setDraft((d) => ({ ...d, [k]: v }))

  const save = () => {
    update((s) => {
      if (isEdit) {
        return {
          ...s,
          issues: (s.issues || []).map((i) => i.id === existing.id ? {
            ...i,
            title: draft.title,
            category: draft.category,
            description: draft.description,
            photo: draft.photo,
          } : i),
        }
      }
      return {
        ...s,
        issues: [{
          id: 'is-' + Math.random().toString(36).slice(2, 6),
          title: draft.title,
          category: draft.category,
          description: draft.description,
          photo: draft.photo,
          raisedBy: currentUser.id,
          raisedAt: new Date().toISOString().slice(0, 10),
          status: 'open',
          fixedAt: null,
          fixedBy: null,
        }, ...(s.issues || [])],
      }
    })
    onClose()
  }

  return (
    <div className="modal-bg" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <h2>{isEdit ? 'Edit issue' : 'Raise a house issue'}</h2>

        <div className="field">
          <label>Title</label>
          <input type="text" value={draft.title} onChange={(e) => setF('title', e.target.value)} placeholder="Leaking shower tap" />
        </div>

        <div className="field">
          <label>Category</label>
          <select value={draft.category} onChange={(e) => setF('category', e.target.value)}>
            {CATEGORIES.map(([v, l]) => <option key={v} value={v}>{l}</option>)}
          </select>
        </div>

        <div className="field">
          <label>Description <span className="hint">(optional)</span></label>
          <textarea
            rows={3}
            value={draft.description}
            onChange={(e) => setF('description', e.target.value)}
            placeholder="Where, when, how bad. Anything the leaseholder needs to know to call a tradie."
          />
        </div>

        <div className="field">
          <label>Photo <span className="hint">(optional)</span></label>
          <FilePicker value={draft.photo} onChange={(v) => setF('photo', v)} />
        </div>

        <div className="modal-actions">
          <button className="btn secondary" onClick={onClose}>Cancel</button>
          <button className="btn" onClick={save} disabled={!draft.title.trim()}>
            {isEdit ? 'Save changes' : 'Raise issue'}
          </button>
        </div>
      </div>
    </div>
  )
}
