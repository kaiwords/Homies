export const fmtAUD = (n) => {
  if (n == null || isNaN(n)) return '—'
  return new Intl.NumberFormat('en-AU', {
    style: 'currency',
    currency: 'AUD',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(n)
}

export const fmtDate = (iso) => {
  if (!iso) return '—'
  const d = new Date(iso)
  if (isNaN(d.getTime())) return iso
  return d.toLocaleDateString('en-AU', { day: '2-digit', month: 'short', year: 'numeric' })
}

export const fmtDateShort = (iso) => {
  if (!iso) return '—'
  const d = new Date(iso)
  if (isNaN(d.getTime())) return iso
  return d.toLocaleDateString('en-AU', { day: '2-digit', month: 'short' })
}

export const fmtRelative = (iso) => {
  if (!iso) return ''
  const d = new Date(iso)
  const diff = d.getTime() - Date.now()
  const days = Math.round(diff / 86400000)
  if (days === 0) return 'today'
  if (days === 1) return 'tomorrow'
  if (days === -1) return 'yesterday'
  if (days > 0 && days < 7) return `in ${days} days`
  if (days < 0 && days > -7) return `${Math.abs(days)} days ago`
  return fmtDate(iso)
}

export const equalSplit = (total, n) => {
  if (!n) return []
  const base = Math.floor((total * 100) / n) / 100
  const shares = Array(n).fill(base)
  const remainder = Math.round((total - base * n) * 100) / 100
  if (remainder > 0) shares[0] = Math.round((shares[0] + remainder) * 100) / 100
  return shares
}

const DAY_MS = 86400000

export const daysBetween = (startIso, endIso) => {
  const s = new Date(startIso)
  const e = new Date(endIso)
  if (isNaN(s) || isNaN(e)) return 0
  return Math.max(0, Math.floor((e - s) / DAY_MS) + 1)
}

export const residentDays = (user, periodStart, periodEnd) => {
  const start = new Date(periodStart)
  const end = new Date(periodEnd)
  if (isNaN(start) || isNaN(end) || end < start) return 0
  const moveIn = user.moveInDate ? new Date(user.moveInDate) : start
  const moveOut = user.moveOutDate ? new Date(user.moveOutDate) : end
  const overlapStart = moveIn > start ? moveIn : start
  const overlapEnd = moveOut < end ? moveOut : end
  if (overlapEnd < overlapStart) return 0
  return Math.floor((overlapEnd - overlapStart) / DAY_MS) + 1
}

export const prorateShares = (total, participantIds, users, periodStart, periodEnd) => {
  if (!periodStart || !periodEnd) {
    const arr = equalSplit(total, participantIds.length)
    return participantIds.reduce((acc, id, i) => ({ ...acc, [id]: arr[i] }), {})
  }
  const personDays = {}
  let totalPersonDays = 0
  for (const id of participantIds) {
    const u = users.find((x) => x.id === id)
    const d = u ? residentDays(u, periodStart, periodEnd) : 0
    personDays[id] = d
    totalPersonDays += d
  }
  if (totalPersonDays === 0) {
    return participantIds.reduce((acc, id) => ({ ...acc, [id]: 0 }), {})
  }
  const shares = {}
  let runningSum = 0
  participantIds.forEach((id, i) => {
    if (i === participantIds.length - 1) {
      shares[id] = Math.round((total - runningSum) * 100) / 100
    } else {
      const exact = (total * personDays[id]) / totalPersonDays
      const rounded = Math.round(exact * 100) / 100
      shares[id] = rounded
      runningSum += rounded
    }
  })
  return shares
}

export const isApprovalComplete = (user) =>
  !!user && !!user.docVerified && !!user.bondPaid && !!user.advanceRentPaid && !!user.acceptedRulesAt && !!user.moveInDate

export const cadenceLabel = (c) => ({ weekly: 'Weekly', fortnightly: 'Fortnightly', monthly: 'Monthly' }[c] || c)

const CADENCE_LABELS = {
  weekly: 'Weekly',
  fortnightly: 'Fortnightly',
  monthly: 'Monthly',
  quarterly: 'Quarterly',
  'half-yearly': 'Half-yearly',
  yearly: 'Yearly',
}

export const cadenceLabelFull = (c, customDays) => {
  if (c === 'custom') return `Every ${customDays || '?'} days`
  return CADENCE_LABELS[c] || c
}

const shiftDate = (iso, cadence, customDays, sign) => {
  if (!iso) return iso
  const d = new Date(iso)
  if (isNaN(d.getTime())) return iso
  const s = sign < 0 ? -1 : 1
  switch (cadence) {
    case 'weekly': d.setDate(d.getDate() + 7 * s); break
    case 'fortnightly': d.setDate(d.getDate() + 14 * s); break
    case 'monthly': d.setMonth(d.getMonth() + 1 * s); break
    case 'quarterly': d.setMonth(d.getMonth() + 3 * s); break
    case 'half-yearly': d.setMonth(d.getMonth() + 6 * s); break
    case 'yearly': d.setFullYear(d.getFullYear() + 1 * s); break
    case 'custom': d.setDate(d.getDate() + (Number(customDays) || 0) * s); break
    default: return iso
  }
  return d.toISOString().slice(0, 10)
}

export const addCadence = (iso, cadence, customDays) => shiftDate(iso, cadence, customDays, +1)
export const subtractCadence = (iso, cadence, customDays) => shiftDate(iso, cadence, customDays, -1)
