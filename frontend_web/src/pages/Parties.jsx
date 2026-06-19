import { useState } from 'react'
import { useHomies } from '../context/HomiesContext.jsx'
import { Avatar } from '../components/Avatar.jsx'
import { fmtDate } from '../lib/format.js'

export function Parties() {
  const { state, update, currentUser } = useHomies()
  const [showNew, setShowNew] = useState(false)

  const respond = (partyId, response, alternativeDate = null) => {
    update((s) => ({
      ...s,
      parties: s.parties.map((p) => {
        if (p.id !== partyId) return p
        return {
          ...p,
          responses: { ...p.responses, [currentUser.id]: response },
          ...(alternativeDate ? { suggestedDates: [...(p.suggestedDates || []), { by: currentUser.id, date: alternativeDate }] } : {}),
        }
      }),
    }))
  }

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Parties</h1>
          <p>Propose a home party. Housemates can accept, suggest a different date, or pass.</p>
        </div>
        <button className="btn" onClick={() => setShowNew(true)}>+ Propose party</button>
      </div>

      {state.parties.length === 0 && <div className="empty"><h3>No parties yet</h3><p>Hosting something? Run it by the house first.</p></div>}

      {state.parties.map((p) => {
        const host = state.users.find((u) => u.id === p.host)
        const myResponse = p.responses[currentUser.id]
        const others = state.users.filter((u) => !u.pending && !u.moveOutDate && u.id !== p.host)
        return (
          <div className="card" key={p.id}>
            <div className="row" style={{ alignItems: 'flex-start' }}>
              <div style={{ flex: 1 }}>
                <div className="bold" style={{ fontSize: 16 }}>{p.title}</div>
                <div className="tiny muted">{fmtDate(p.date)} at {p.time} · host {host?.name || '—'}</div>
                {p.notes && <p className="tiny" style={{ marginTop: 6 }}>{p.notes}</p>}
              </div>
            </div>

            <hr />

            <div>
              <div className="tiny muted bold mb">Housemate responses</div>
              {others.map((u) => {
                const r = p.responses[u.id]
                return (
                  <div key={u.id} className="row" style={{ padding: '4px 0' }}>
                    <Avatar user={u} size="sm" />
                    <span className="tiny" style={{ flex: 1 }}>{u.name}</span>
                    {r === 'accept' && <span className="chip ok">in</span>}
                    {r === 'push' && <span className="chip warn">suggest other date</span>}
                    {r === 'decline' && <span className="chip danger">pass</span>}
                    {!r && <span className="chip">no reply</span>}
                  </div>
                )
              })}
            </div>

            {p.host !== currentUser.id && (
              <>
                <hr />
                <div className="row">
                  <span className="tiny muted">Your reply:</span>
                  <button className={'btn small ' + (myResponse === 'accept' ? '' : 'secondary')} onClick={() => respond(p.id, 'accept')}>I'm in</button>
                  <button className={'btn small ' + (myResponse === 'push' ? '' : 'secondary')} onClick={() => respond(p.id, 'push')}>Push it</button>
                  <button className={'btn small ' + (myResponse === 'decline' ? '' : 'secondary')} onClick={() => respond(p.id, 'decline')}>Pass</button>
                </div>
              </>
            )}
          </div>
        )
      })}

      {showNew && <NewPartyModal onClose={() => setShowNew(false)} />}
    </>
  )
}

function NewPartyModal({ onClose }) {
  const { update, currentUser } = useHomies()
  const [draft, setDraft] = useState({ title: '', date: '', time: '19:00', notes: '' })

  const save = () => {
    update((s) => ({
      ...s,
      parties: [...s.parties, {
        id: 'pa-' + Math.random().toString(36).slice(2, 6),
        title: draft.title,
        date: draft.date,
        time: draft.time,
        host: currentUser.id,
        notes: draft.notes,
        responses: {},
        status: 'planning',
      }],
    }))
    onClose()
  }

  return (
    <div className="modal-bg" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <h2>Propose a party</h2>
        <div className="field">
          <label>What's the occasion?</label>
          <input type="text" value={draft.title} onChange={(e) => setDraft({ ...draft, title: e.target.value })} placeholder="Marco's 30th, housewarming, etc." />
        </div>
        <div className="field-row">
          <div className="field">
            <label>Date</label>
            <input type="date" value={draft.date} onChange={(e) => setDraft({ ...draft, date: e.target.value })} />
          </div>
          <div className="field">
            <label>Start time</label>
            <input type="text" value={draft.time} onChange={(e) => setDraft({ ...draft, time: e.target.value })} placeholder="19:00" />
          </div>
        </div>
        <div className="field">
          <label>Notes for housemates</label>
          <textarea rows={3} value={draft.notes} onChange={(e) => setDraft({ ...draft, notes: e.target.value })} placeholder="Roughly how many people, food & drinks, end time…" />
        </div>
        <div className="modal-actions">
          <button className="btn secondary" onClick={onClose}>Cancel</button>
          <button className="btn" onClick={save} disabled={!draft.title || !draft.date}>Propose</button>
        </div>
      </div>
    </div>
  )
}
