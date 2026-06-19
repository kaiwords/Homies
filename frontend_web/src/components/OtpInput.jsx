import { useRef, useEffect } from 'react'

export function OtpInput({ value, onChange, length = 6, autoFocus = true }) {
  const refs = useRef([])

  useEffect(() => {
    if (autoFocus) refs.current[0]?.focus()
  }, [autoFocus])

  const digits = Array(length).fill('').map((_, i) => value[i] || '')

  const setDigit = (i, char) => {
    const sanitized = (char || '').replace(/\D/g, '').slice(-1)
    const next = [...digits]
    next[i] = sanitized
    onChange(next.join(''))
    if (sanitized && i < length - 1) refs.current[i + 1]?.focus()
  }

  const handleKeyDown = (i, e) => {
    if (e.key === 'Backspace' && !digits[i] && i > 0) {
      const next = [...digits]
      next[i - 1] = ''
      onChange(next.join(''))
      refs.current[i - 1]?.focus()
    }
    if (e.key === 'ArrowLeft' && i > 0) refs.current[i - 1]?.focus()
    if (e.key === 'ArrowRight' && i < length - 1) refs.current[i + 1]?.focus()
  }

  const handlePaste = (e) => {
    const pasted = e.clipboardData.getData('text').replace(/\D/g, '').slice(0, length)
    if (pasted) {
      e.preventDefault()
      onChange(pasted.padEnd(length, '').slice(0, length))
      const lastIdx = Math.min(pasted.length, length) - 1
      refs.current[lastIdx]?.focus()
    }
  }

  return (
    <div className="row" style={{ gap: 6 }}>
      {Array(length).fill(0).map((_, i) => (
        <input
          key={i}
          ref={(el) => (refs.current[i] = el)}
          type="text"
          inputMode="numeric"
          maxLength={1}
          value={digits[i]}
          onChange={(e) => setDigit(i, e.target.value)}
          onKeyDown={(e) => handleKeyDown(i, e)}
          onPaste={i === 0 ? handlePaste : undefined}
          style={{
            width: 44,
            height: 52,
            fontSize: 22,
            textAlign: 'center',
            border: '1px solid var(--border-strong)',
            borderRadius: 'var(--radius-sm)',
            outline: 'none',
            background: 'var(--surface)',
            fontFamily: 'var(--mono)',
          }}
        />
      ))}
    </div>
  )
}
