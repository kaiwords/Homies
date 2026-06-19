import { useState } from 'react'
import { useHomies } from '../context/HomiesContext.jsx'
import { Avatar } from '../components/Avatar.jsx'
import { Attachment } from '../components/FilePicker.jsx'
import { fmtDate, fmtRelative } from '../lib/format.js'

const DAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']

export function Cleaning() {
  const { state, update, currentUser } = useHomies()
  const isLeaseholder = currentUser.role === 'leaseholder'
  const [editingTask, setEditingTask] = useState(null)

  const markDone = (id) => {
    update((s) => ({
      ...s,
      cleaningTasks: s.cleaningTasks.map((t) => t.id === id ? { ...t, done: true, completedAt: new Date().toISOString().slice(0, 10) } : t),
    }))
  }

  const undoDone = (id) => {
    update((s) => ({
      ...s,
      cleaningTasks: s.cleaningTasks.map((t) => t.id === id ? { ...t, done: false, completedAt: null } : t),
    }))
  }

  const setRosterAssignee = (day, assigneeId) => {
    update((s) => ({
      ...s,
      cleaningRoster: s.cleaningRoster.map((r) => r.day === day ? { ...r, assignee: assigneeId } : r),
    }))
  }

  const setRosterArea = (day, area) => {
    update((s) => ({
      ...s,
      cleaningRoster: s.cleaningRoster.map((r) => r.day === day ? { ...r, area } : r),
    }))
  }

  const addRosterDay = (day) => {
    update((s) => ({
      ...s,
      cleaningRoster: [...s.cleaningRoster, { day, area: '', assignee: '' }],
    }))
  }

  const removeRosterDay = (day) => {
    update((s) => ({
      ...s,
      cleaningRoster: s.cleaningRoster.filter((r) => r.day !== day),
    }))
  }

  const deleteTask = (id) => {
    if (!confirm('Delete this task?')) return
    update((s) => ({ ...s, cleaningTasks: s.cleaningTasks.filter((t) => t.id !== id) }))
  }

  const housemates = state.users.filter((u) => !u.pending && !u.moveOutDate)

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Cleaning</h1>
          <p>Weekly roster + the task list. Tick off with photo proof, or log an excuse if you can't.</p>
        </div>
        {isLeaseholder && <button className="btn" onClick={() => setEditingTask({})}>+ Add task</button>}
      </div>

      <div className="card">
        <h2>This week's roster</h2>
        <p className="tiny muted mb">{isLeaseholder ? 'Edit the area + assignee for each day. Remove or add days as needed.' : 'Leaseholder sets the schedule.'}</p>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 10 }}>
          {DAYS.filter((d) => state.cleaningRoster.some((r) => r.day === d)).map((d) => {
            const row = state.cleaningRoster.find((r) => r.day === d)
            const assignee = row ? state.users.find((u) => u.id === row.assignee) : null
            return (
              <div key={d} style={{ background: 'var(--surface-2)', padding: 10, borderRadius: 'var(--radius-sm)' }}>
                <div className="row" style={{ justifyContent: 'space-between', marginBottom: 4 }}>
                  <div className="tiny muted bold">{d}</div>
                  {isLeaseholder && <button className="btn ghost small" style={{ padding: '2px 6px', fontSize: 11 }} onClick={() => removeRosterDay(d)}>×</button>}
                </div>
                {isLeaseholder ? (
                  <input
                    type="text"
                    value={row?.area || ''}
                    onChange={(e) => setRosterArea(d, e.target.value)}
                    placeholder="Area"
                    style={{ width: '100%', padding: '4px 6px', border: '1px solid var(--border-strong)', borderRadius: 'var(--radius-sm)', fontSize: 13, marginBottom: 6 }}
                  />
                ) : (
                  <div className="tiny" style={{ marginBottom: 6 }}>{row?.area || '—'}</div>
                )}
                {isLeaseholder ? (
                  <select
                    value={row?.assignee || ''}
                    onChange={(e) => setRosterAssignee(d, e.target.value)}
                    style={{ width: '100%', padding: '4px 6px', border: '1px solid var(--border-strong)', borderRadius: 'var(--radius-sm)', fontSize: 13 }}
                  >
                    <option value="">— unassigned —</option>
                    {housemates.map((u) => <option key={u.id} value={u.id}>{u.name}</option>)}
                  </select>
                ) : (
                  <div className="row">
                    {assignee ? <><Avatar user={assignee} size="sm" /><span className="tiny">{assignee.name.split(' ')[0]}</span></> : <span className="tiny faint">unassigned</span>}
                  </div>
                )}
              </div>
            )
          })}
        </div>
        {isLeaseholder && DAYS.some((d) => !state.cleaningRoster.some((r) => r.day === d)) && (
          <div className="row mt">
            <span className="tiny muted">Add a day:</span>
            {DAYS.filter((d) => !state.cleaningRoster.some((r) => r.day === d)).map((d) => (
              <button key={d} type="button" className="btn ghost small" onClick={() => addRosterDay(d)}>+ {d}</button>
            ))}
          </div>
        )}
      </div>

      <div className="card">
        <h2>Tasks</h2>
        {state.cleaningTasks.length === 0 && <p className="muted tiny">No tasks yet.</p>}

        {state.cleaningTasks.map((t) => {
          const assignee = state.users.find((u) => u.id === t.assignee)
          const isMine = t.assignee === currentUser.id
          const overdue = !t.done && !t.excuse && new Date(t.dueDate) < new Date(new Date().toISOString().slice(0, 10))
          return (
            <div key={t.id} className="row" style={{ padding: '12px 0', borderTop: '1px solid var(--border)', alignItems: 'flex-start' }}>
              <input
                type="checkbox"
                checked={t.done}
                onChange={() => t.done ? undoDone(t.id) : markDone(t.id)}
                disabled={!isMine && !isLeaseholder}
                style={{ marginTop: 4, accentColor: 'var(--accent)' }}
              />
              <div style={{ flex: 1 }}>
                <div className="row">
                  <span className={'bold' + (t.done ? '' : '')} style={{ textDecoration: t.done ? 'line-through' : 'none', color: t.done ? 'var(--text-faint)' : 'var(--text)' }}>
                    {t.task}
                  </span>
                  {overdue && <span className="chip danger">overdue</span>}
                  {t.done && <span className="chip ok">done {fmtRelative(t.completedAt)}</span>}
                  {t.excuse && <span className="chip warn">excused</span>}
                </div>
                <div className="tiny muted">
                  {assignee?.name || '—'} · due {fmtDate(t.dueDate)}
                </div>
                {t.excuse && (
                  <div className="tiny" style={{ marginTop: 4, fontStyle: 'italic', color: 'var(--text-dim)' }}>
                    "{t.excuse}"
                  </div>
                )}
                {t.photo && <Attachment value={t.photo} compact />}
                {isMine && !t.done && (
                  <div className="row mt">
                    <ExcuseButton task={t} />
                    <PhotoButton task={t} />
                  </div>
                )}
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 6 }}>
                <Avatar user={assignee} size="sm" />
                {isLeaseholder && (
                  <div className="row">
                    <button className="btn ghost small" onClick={() => deleteTask(t.id)}>Delete</button>
                    <button className="btn secondary small" onClick={() => setEditingTask(t)}>Edit</button>
                  </div>
                )}
              </div>
            </div>
          )
        })}
      </div>

      {editingTask && <TaskModal existing={editingTask.id ? editingTask : null} onClose={() => setEditingTask(null)} />}
    </>
  )
}

function ExcuseButton({ task }) {
  const { update } = useHomies()
  const [open, setOpen] = useState(false)
  const [text, setText] = useState('')

  const save = () => {
    update((s) => ({
      ...s,
      cleaningTasks: s.cleaningTasks.map((t) => t.id === task.id ? { ...t, excuse: text } : t),
    }))
    setOpen(false)
  }

  if (open) {
    return (
      <div className="row" style={{ flex: 1 }}>
        <input
          type="text"
          value={text}
          onChange={(e) => setText(e.target.value)}
          placeholder="Why couldn't you?"
          style={{ flex: 1, padding: '6px 10px', border: '1px solid var(--border-strong)', borderRadius: 'var(--radius-sm)', fontSize: 13 }}
        />
        <button className="btn small" onClick={save} disabled={!text.trim()}>Log excuse</button>
        <button className="btn ghost small" onClick={() => setOpen(false)}>Cancel</button>
      </div>
    )
  }
  return <button className="btn ghost small" onClick={() => setOpen(true)}>Can't do it</button>
}

function PhotoButton({ task }) {
  const { update } = useHomies()
  const handleFile = (e) => {
    const file = e.target.files?.[0]
    if (!file) return
    if (file.size > 2 * 1024 * 1024) {
      alert('Image too big — keep it under 2 MB for the demo.')
      return
    }
    const reader = new FileReader()
    reader.onload = () => {
      const photo = {
        fileName: file.name,
        dataUrl: reader.result,
        type: file.type,
        size: file.size,
        uploadedAt: new Date().toISOString(),
      }
      update((s) => ({
        ...s,
        cleaningTasks: s.cleaningTasks.map((t) => t.id === task.id ? { ...t, photo, done: true, completedAt: new Date().toISOString().slice(0, 10) } : t),
      }))
    }
    reader.readAsDataURL(file)
  }
  return (
    <label className="btn ghost small" style={{ cursor: 'pointer' }}>
      📷 Photo proof
      <input type="file" accept="image/*" style={{ display: 'none' }} onChange={handleFile} />
    </label>
  )
}

function TaskModal({ onClose, existing }) {
  const { state, update } = useHomies()
  const housemates = state.users.filter((u) => !u.pending && !u.moveOutDate)
  const isEdit = !!existing
  const [draft, setDraft] = useState(isEdit ? {
    task: existing.task || '',
    assignee: existing.assignee || housemates[0]?.id || '',
    dueDate: existing.dueDate || '',
  } : {
    task: '',
    assignee: housemates[0]?.id || '',
    dueDate: '',
  })

  const save = () => {
    update((s) => {
      if (isEdit) {
        return {
          ...s,
          cleaningTasks: s.cleaningTasks.map((t) => t.id === existing.id ? {
            ...t,
            task: draft.task,
            assignee: draft.assignee,
            dueDate: draft.dueDate,
          } : t),
        }
      }
      return {
        ...s,
        cleaningTasks: [...s.cleaningTasks, {
          id: 'c-' + Math.random().toString(36).slice(2, 6),
          task: draft.task,
          assignee: draft.assignee,
          dueDate: draft.dueDate,
          done: false,
          photoUrl: null,
          excuse: null,
        }],
      }
    })
    onClose()
  }

  return (
    <div className="modal-bg" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <h2>{isEdit ? 'Edit cleaning task' : 'Add cleaning task'}</h2>
        <div className="field">
          <label>Task</label>
          <input type="text" value={draft.task} onChange={(e) => setDraft({ ...draft, task: e.target.value })} placeholder="Scrub the oven" />
        </div>
        <div className="field-row">
          <div className="field">
            <label>Assignee</label>
            <select value={draft.assignee} onChange={(e) => setDraft({ ...draft, assignee: e.target.value })}>
              {housemates.map((u) => <option key={u.id} value={u.id}>{u.name}</option>)}
            </select>
          </div>
          <div className="field">
            <label>Due date</label>
            <input type="date" value={draft.dueDate} onChange={(e) => setDraft({ ...draft, dueDate: e.target.value })} />
          </div>
        </div>
        <div className="modal-actions">
          <button className="btn secondary" onClick={onClose}>Cancel</button>
          <button className="btn" onClick={save} disabled={!draft.task || !draft.dueDate}>{isEdit ? 'Save changes' : 'Add task'}</button>
        </div>
      </div>
    </div>
  )
}
