import { useState, useRef } from 'react'

const MAX_BYTES = 1024 * 1024 * 2

export function FilePicker({ value, onChange, accept = 'image/*,application/pdf' }) {
  const [reading, setReading] = useState(false)
  const [error, setError] = useState(null)
  const inputRef = useRef(null)

  const handleChange = (e) => {
    const file = e.target.files?.[0]
    if (!file) return
    setError(null)
    if (file.size > MAX_BYTES) {
      setError(`File is ${(file.size / 1024 / 1024).toFixed(1)} MB — keep it under 2 MB for the demo.`)
      return
    }
    setReading(true)
    const reader = new FileReader()
    reader.onload = () => {
      onChange({
        fileName: file.name,
        dataUrl: reader.result,
        type: file.type,
        size: file.size,
        uploadedAt: new Date().toISOString(),
      })
      setReading(false)
    }
    reader.onerror = () => {
      setError('Could not read that file.')
      setReading(false)
    }
    reader.readAsDataURL(file)
  }

  const clear = () => {
    onChange(null)
    if (inputRef.current) inputRef.current.value = ''
  }

  return (
    <div>
      {!value && (
        <input ref={inputRef} type="file" accept={accept} onChange={handleChange} disabled={reading} />
      )}
      {reading && <div className="chip warn" style={{ marginTop: 6 }}>Reading…</div>}
      {error && <div className="chip danger" style={{ marginTop: 6 }}>{error}</div>}
      {value && <Attachment value={value} onRemove={clear} />}
    </div>
  )
}

export function Attachment({ value, onRemove, compact = false }) {
  if (!value) return null
  const isImage = value.type?.startsWith('image/') && value.dataUrl
  const sizeKb = value.size ? `${(value.size / 1024).toFixed(0)} KB` : ''
  return (
    <div className="row mt" style={{ alignItems: 'center', gap: 10 }}>
      {isImage ? (
        <a href={value.dataUrl} target="_blank" rel="noreferrer">
          <img
            src={value.dataUrl}
            alt="attachment"
            style={{
              width: compact ? 40 : 56,
              height: compact ? 40 : 56,
              objectFit: 'cover',
              borderRadius: 'var(--radius-sm)',
              border: '1px solid var(--border)',
              display: 'block',
            }}
          />
        </a>
      ) : value.dataUrl ? (
        <a href={value.dataUrl} target="_blank" rel="noreferrer" className="chip ok">📎 open</a>
      ) : (
        <span className="chip">📎 attached</span>
      )}
      <div className="tiny" style={{ flex: 1 }}>
        <div className="bold">{value.fileName || 'file'}</div>
        <div className="faint">{sizeKb}</div>
      </div>
      {onRemove && <button type="button" className="btn ghost small" onClick={onRemove}>Replace</button>}
    </div>
  )
}
