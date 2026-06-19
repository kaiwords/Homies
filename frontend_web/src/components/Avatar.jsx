export function Avatar({ user, size = 'md' }) {
  if (!user) return null
  const cls = size === 'lg' ? 'avatar lg' : size === 'sm' ? 'avatar sm' : 'avatar'
  return <span className={cls} title={user.name}>{user.initials}</span>
}

export function AvatarStack({ users }) {
  return (
    <span className="avatar-stack">
      {users.filter(Boolean).map((u) => (
        <Avatar key={u.id} user={u} size="sm" />
      ))}
    </span>
  )
}
