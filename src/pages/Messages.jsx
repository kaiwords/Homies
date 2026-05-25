import { useState, useMemo, useRef } from 'react'
import { useHomies } from '../context/HomiesContext.jsx'
import { Avatar } from '../components/Avatar.jsx'

function dmKey(a, b) {
  return [a, b].sort().join('-')
}

const MAX_BYTES = 1024 * 1024 * 2

export function Messages() {
  const { state, update, currentUser } = useHomies()
  const housemates = state.users.filter((u) => !u.pending && !u.moveOutDate && u.id !== currentUser.id)
  const [activeId, setActiveId] = useState('group')
  const [draft, setDraft] = useState('')
  const [pendingAttachment, setPendingAttachment] = useState(null)
  const [attachError, setAttachError] = useState(null)
  const [pollOpen, setPollOpen] = useState(false)
  const fileRef = useRef(null)

  const isGroup = activeId === 'group'
  const messages = useMemo(() => {
    if (isGroup) return state.messages.group
    return state.messages.dms[dmKey(currentUser.id, activeId)] || []
  }, [isGroup, activeId, state.messages, currentUser.id])

  const pickFile = (e) => {
    const file = e.target.files?.[0]
    if (!file) return
    setAttachError(null)
    if (file.size > MAX_BYTES) {
      setAttachError(`File is ${(file.size / 1024 / 1024).toFixed(1)} MB — keep it under 2 MB.`)
      e.target.value = ''
      return
    }
    const reader = new FileReader()
    reader.onload = () => {
      setPendingAttachment({
        fileName: file.name,
        dataUrl: reader.result,
        type: file.type,
        size: file.size,
      })
    }
    reader.onerror = () => setAttachError('Could not read that file.')
    reader.readAsDataURL(file)
    e.target.value = ''
  }

  const appendMessage = (msg) => {
    update((s) => {
      if (isGroup) {
        return { ...s, messages: { ...s.messages, group: [...s.messages.group, msg] } }
      }
      const key = dmKey(currentUser.id, activeId)
      return { ...s, messages: { ...s.messages, dms: { ...s.messages.dms, [key]: [...(s.messages.dms[key] || []), msg] } } }
    })
  }

  const send = () => {
    const text = draft.trim()
    if (!text && !pendingAttachment) return
    appendMessage({
      id: 'm-' + Math.random().toString(36).slice(2, 6),
      from: currentUser.id,
      type: 'text',
      text,
      attachment: pendingAttachment,
      at: new Date().toISOString(),
    })
    setDraft('')
    setPendingAttachment(null)
    setAttachError(null)
  }

  const sendPoll = (question, options, multi) => {
    appendMessage({
      id: 'm-' + Math.random().toString(36).slice(2, 6),
      from: currentUser.id,
      type: 'poll',
      at: new Date().toISOString(),
      poll: {
        question,
        multi,
        closed: false,
        options: options.map((text) => ({
          id: 'o-' + Math.random().toString(36).slice(2, 6),
          text,
          addedBy: currentUser.id,
        })),
        votes: {},
      },
    })
    setPollOpen(false)
  }

  const conversationKey = isGroup ? 'group' : dmKey(currentUser.id, activeId)
  const mutatePollMessage = (msgId, mutator) => {
    update((s) => {
      if (isGroup) {
        return {
          ...s,
          messages: { ...s.messages, group: s.messages.group.map((m) => m.id === msgId ? mutator(m) : m) },
        }
      }
      const list = s.messages.dms[conversationKey] || []
      return {
        ...s,
        messages: {
          ...s.messages,
          dms: { ...s.messages.dms, [conversationKey]: list.map((m) => m.id === msgId ? mutator(m) : m) },
        },
      }
    })
  }

  const togglePollVote = (msgId, optionId) => {
    mutatePollMessage(msgId, (m) => {
      if (m.type !== 'poll' || m.poll.closed) return m
      const votes = { ...(m.poll.votes || {}) }
      const allOptionIds = m.poll.options.map((o) => o.id)
      const alreadyVoted = (votes[optionId] || []).includes(currentUser.id)
      if (m.poll.multi) {
        const current = votes[optionId] || []
        votes[optionId] = alreadyVoted ? current.filter((u) => u !== currentUser.id) : [...current, currentUser.id]
      } else {
        // single-choice: clear my vote from all options, then set the new one (unless toggling off)
        for (const oid of allOptionIds) {
          votes[oid] = (votes[oid] || []).filter((u) => u !== currentUser.id)
        }
        if (!alreadyVoted) votes[optionId] = [...(votes[optionId] || []), currentUser.id]
      }
      return { ...m, poll: { ...m.poll, votes } }
    })
  }

  const addPollOption = (msgId, text) => {
    const trimmed = text.trim()
    if (!trimmed) return
    mutatePollMessage(msgId, (m) => {
      if (m.type !== 'poll' || m.poll.closed) return m
      return {
        ...m,
        poll: {
          ...m.poll,
          options: [...m.poll.options, {
            id: 'o-' + Math.random().toString(36).slice(2, 6),
            text: trimmed,
            addedBy: currentUser.id,
          }],
        },
      }
    })
  }

  const closePoll = (msgId) => {
    mutatePollMessage(msgId, (m) => m.type === 'poll' ? { ...m, poll: { ...m.poll, closed: true } } : m)
  }

  const activeUser = !isGroup && housemates.find((u) => u.id === activeId)

  return (
    <div className="messages-wrap" style={{ display: 'grid', gridTemplateColumns: '220px 1fr', gap: 14, height: 'calc(100svh - 130px)' }}>
      <div className="card" style={{ padding: 0, overflow: 'auto' }}>
        <ConvItem
          active={isGroup}
          onClick={() => setActiveId('group')}
          icon="👥"
          name="House group"
          sub={`${state.users.filter((u) => !u.pending && !u.moveOutDate).length} members`}
        />
        {housemates.map((u) => (
          <ConvItem
            key={u.id}
            active={activeId === u.id}
            onClick={() => setActiveId(u.id)}
            avatar={u}
            name={u.name}
            sub={u.role}
          />
        ))}
      </div>

      <div className="card" style={{ padding: 0, display: 'flex', flexDirection: 'column' }}>
        <div style={{ padding: '14px 18px', borderBottom: '1px solid var(--border)' }}>
          <div className="bold">{isGroup ? 'House group' : activeUser?.name || ''}</div>
          <div className="tiny muted">{isGroup ? 'Everyone living here.' : 'Just the two of you.'}</div>
        </div>

        <div style={{ flex: 1, overflowY: 'auto', padding: 18, display: 'flex', flexDirection: 'column', gap: 12 }}>
          {messages.length === 0 && <div className="muted tiny center" style={{ marginTop: 40 }}>No messages yet — say hi.</div>}
          {messages.map((m) => {
            const sender = state.users.find((u) => u.id === m.from)
            const mine = m.from === currentUser.id
            if (m.type === 'poll') {
              return (
                <div key={m.id} className="row" style={{ alignItems: 'flex-end', justifyContent: mine ? 'flex-end' : 'flex-start' }}>
                  {!mine && <Avatar user={sender} size="sm" />}
                  <PollBubble
                    message={m}
                    mine={mine}
                    senderName={sender?.name}
                    currentUserId={currentUser.id}
                    onVote={(optId) => togglePollVote(m.id, optId)}
                    onAddOption={(text) => addPollOption(m.id, text)}
                    onClose={() => closePoll(m.id)}
                  />
                </div>
              )
            }
            const a = m.attachment
            const isImage = a?.type?.startsWith('image/') && a.dataUrl
            return (
              <div key={m.id} className="row" style={{ alignItems: 'flex-end', justifyContent: mine ? 'flex-end' : 'flex-start' }}>
                {!mine && <Avatar user={sender} size="sm" />}
                <div style={{
                  background: mine ? 'var(--accent)' : 'var(--surface-2)',
                  color: mine ? '#fff' : 'var(--text)',
                  padding: '8px 12px',
                  borderRadius: 14,
                  maxWidth: '70%',
                }}>
                  {!mine && <div className="tiny bold" style={{ color: 'var(--text-dim)' }}>{sender?.name}</div>}
                  {a && (
                    isImage ? (
                      <a href={a.dataUrl} target="_blank" rel="noreferrer">
                        <img
                          src={a.dataUrl}
                          alt={a.fileName || 'attachment'}
                          style={{ maxWidth: 240, maxHeight: 240, borderRadius: 10, display: 'block', marginBottom: m.text ? 6 : 0 }}
                        />
                      </a>
                    ) : a.dataUrl ? (
                      <a href={a.dataUrl} target="_blank" rel="noreferrer" style={{ color: mine ? '#fff' : 'var(--accent)', textDecoration: 'underline' }}>
                        📎 {a.fileName || 'file'}
                      </a>
                    ) : null
                  )}
                  {m.text && <div style={{ fontSize: 14 }}>{m.text}</div>}
                </div>
              </div>
            )
          })}
        </div>

        <div style={{ padding: 14, borderTop: '1px solid var(--border)' }}>
          {pendingAttachment && (
            <div className="row mb" style={{ background: 'var(--surface-2)', padding: '6px 10px', borderRadius: 10 }}>
              {pendingAttachment.type?.startsWith('image/') ? (
                <img src={pendingAttachment.dataUrl} alt="" style={{ width: 36, height: 36, objectFit: 'cover', borderRadius: 6 }} />
              ) : (
                <span style={{ fontSize: 22 }}>📎</span>
              )}
              <div className="tiny" style={{ flex: 1 }}>
                <div className="bold">{pendingAttachment.fileName}</div>
                <div className="faint">{(pendingAttachment.size / 1024).toFixed(0)} KB</div>
              </div>
              <button type="button" className="btn ghost small" onClick={() => setPendingAttachment(null)}>Remove</button>
            </div>
          )}
          {attachError && <div className="chip danger mb">{attachError}</div>}
          <div className="row">
            <input
              ref={fileRef}
              type="file"
              accept="image/*,application/pdf"
              onChange={pickFile}
              style={{ display: 'none' }}
            />
            <button
              type="button"
              className="btn secondary small"
              onClick={() => fileRef.current?.click()}
              title="Attach a photo"
              style={{ padding: '8px 12px' }}
            >
              📎
            </button>
            <button
              type="button"
              className="btn secondary small"
              onClick={() => setPollOpen(true)}
              title="Create a poll"
              style={{ padding: '8px 12px' }}
            >
              📊
            </button>
            <input
              type="text"
              value={draft}
              onChange={(e) => setDraft(e.target.value)}
              placeholder="Type a message…"
              style={{ flex: 1, padding: '10px 14px', border: '1px solid var(--border-strong)', borderRadius: 20 }}
              onKeyDown={(e) => e.key === 'Enter' && send()}
            />
            <button className="btn" onClick={send} disabled={!draft.trim() && !pendingAttachment}>Send</button>
          </div>
        </div>
      </div>

      {pollOpen && <NewPollModal onClose={() => setPollOpen(false)} onCreate={sendPoll} />}
    </div>
  )
}

function PollBubble({ message, mine, senderName, currentUserId, onVote, onAddOption, onClose }) {
  const [newOption, setNewOption] = useState('')
  const poll = message.poll
  const totalVotes = Object.values(poll.votes || {}).reduce((sum, v) => sum + v.length, 0)
  const isCreator = message.from === currentUserId

  const addOption = () => {
    onAddOption(newOption)
    setNewOption('')
  }

  return (
    <div
      style={{
        background: mine ? 'var(--accent)' : 'var(--surface-2)',
        color: mine ? '#fff' : 'var(--text)',
        padding: '10px 14px',
        borderRadius: 14,
        maxWidth: '85%',
        minWidth: 240,
      }}
    >
      {!mine && <div className="tiny bold" style={{ color: 'var(--text-dim)' }}>{senderName}</div>}
      <div className="row" style={{ gap: 6, marginBottom: 6 }}>
        <span style={{ fontSize: 14, fontWeight: 600 }}>📊 {poll.question}</span>
      </div>
      <div className="tiny" style={{ opacity: 0.85, marginBottom: 8 }}>
        {poll.multi ? 'Multiple choice' : 'Single choice'}
        {poll.closed && ' · closed'}
        {totalVotes > 0 && ` · ${totalVotes} vote${totalVotes === 1 ? '' : 's'}`}
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
        {poll.options.map((opt) => {
          const voters = poll.votes?.[opt.id] || []
          const voted = voters.includes(currentUserId)
          const pct = totalVotes > 0 ? Math.round((voters.length / totalVotes) * 100) : 0
          return (
            <button
              key={opt.id}
              type="button"
              onClick={() => onVote(opt.id)}
              disabled={poll.closed}
              style={{
                position: 'relative',
                textAlign: 'left',
                padding: '8px 12px',
                border: `1px solid ${mine ? 'rgba(255,255,255,0.5)' : 'var(--border-strong)'}`,
                borderRadius: 10,
                background: mine ? 'rgba(255,255,255,0.1)' : 'var(--surface)',
                color: 'inherit',
                cursor: poll.closed ? 'default' : 'pointer',
                overflow: 'hidden',
              }}
            >
              <div
                style={{
                  position: 'absolute',
                  inset: 0,
                  width: `${pct}%`,
                  background: mine ? 'rgba(255,255,255,0.18)' : 'var(--accent-soft)',
                  transition: 'width 0.2s',
                  pointerEvents: 'none',
                }}
              />
              <div className="row" style={{ position: 'relative', justifyContent: 'space-between', gap: 8 }}>
                <span style={{ fontSize: 13 }}>{voted ? '✓ ' : ''}{opt.text}</span>
                <span className="tiny" style={{ opacity: 0.8 }}>{voters.length} · {pct}%</span>
              </div>
            </button>
          )
        })}
      </div>

      {!poll.closed && (
        <div className="row" style={{ marginTop: 8, gap: 6 }}>
          <input
            type="text"
            value={newOption}
            onChange={(e) => setNewOption(e.target.value)}
            placeholder="+ Add option"
            onKeyDown={(e) => e.key === 'Enter' && addOption()}
            style={{
              flex: 1,
              padding: '6px 10px',
              fontSize: 12,
              border: `1px solid ${mine ? 'rgba(255,255,255,0.4)' : 'var(--border)'}`,
              borderRadius: 8,
              background: mine ? 'rgba(255,255,255,0.1)' : 'var(--surface)',
              color: 'inherit',
            }}
          />
          <button
            type="button"
            onClick={addOption}
            disabled={!newOption.trim()}
            className="btn small"
            style={{ padding: '4px 10px' }}
          >
            Add
          </button>
        </div>
      )}

      {isCreator && !poll.closed && (
        <div className="row" style={{ marginTop: 8, justifyContent: 'flex-end' }}>
          <button
            type="button"
            onClick={onClose}
            className="btn ghost small"
            style={{ color: 'inherit', opacity: 0.8 }}
          >
            Close poll
          </button>
        </div>
      )}
    </div>
  )
}

function NewPollModal({ onClose, onCreate }) {
  const [question, setQuestion] = useState('')
  const [options, setOptions] = useState(['', ''])
  const [multi, setMulti] = useState(false)

  const setOpt = (i, v) => setOptions((arr) => arr.map((x, idx) => idx === i ? v : x))
  const addOpt = () => setOptions((arr) => [...arr, ''])
  const removeOpt = (i) => setOptions((arr) => arr.filter((_, idx) => idx !== i))

  const trimmed = options.map((o) => o.trim()).filter(Boolean)
  const canCreate = question.trim() && trimmed.length >= 2

  const create = () => {
    if (!canCreate) return
    onCreate(question.trim(), trimmed, multi)
  }

  return (
    <div className="modal-bg" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()} style={{ maxWidth: 460 }}>
        <h2>New poll</h2>
        <p className="tiny muted mb">Anyone in this chat can vote and add more options.</p>

        <div className="field">
          <label>Question</label>
          <input
            type="text"
            value={question}
            onChange={(e) => setQuestion(e.target.value)}
            placeholder="Pizza or Thai tonight?"
            autoFocus
          />
        </div>

        <div className="field">
          <label>Options</label>
          {options.map((opt, i) => (
            <div key={i} className="row" style={{ marginBottom: 6 }}>
              <input
                type="text"
                value={opt}
                onChange={(e) => setOpt(i, e.target.value)}
                placeholder={`Option ${i + 1}`}
                style={{ flex: 1, padding: '8px 10px', border: '1px solid var(--border-strong)', borderRadius: 'var(--radius-sm)' }}
              />
              {options.length > 2 && (
                <button type="button" className="btn ghost small" onClick={() => removeOpt(i)}>×</button>
              )}
            </div>
          ))}
          <button type="button" className="btn secondary small" onClick={addOpt}>+ Add option</button>
        </div>

        <label className="row" style={{ marginBottom: 12 }}>
          <input type="checkbox" checked={multi} onChange={(e) => setMulti(e.target.checked)} />
          <span className="tiny">Allow multiple votes per person</span>
        </label>

        <div className="modal-actions">
          <button className="btn secondary" onClick={onClose}>Cancel</button>
          <button className="btn" onClick={create} disabled={!canCreate}>Send poll</button>
        </div>
      </div>
    </div>
  )
}

function ConvItem({ active, onClick, icon, avatar, name, sub }) {
  return (
    <button
      type="button"
      onClick={onClick}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 10,
        padding: '12px 14px',
        width: '100%',
        textAlign: 'left',
        border: 'none',
        background: active ? 'var(--accent-soft)' : 'transparent',
        borderBottom: '1px solid var(--border)',
        cursor: 'pointer',
      }}
    >
      {icon ? <span style={{ fontSize: 22 }}>{icon}</span> : <Avatar user={avatar} />}
      <div style={{ flex: 1 }}>
        <div className="bold tiny" style={{ color: active ? 'var(--accent-strong)' : 'var(--text)' }}>{name}</div>
        <div className="tiny faint">{sub}</div>
      </div>
    </button>
  )
}
