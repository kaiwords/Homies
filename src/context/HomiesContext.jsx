import { createContext, useContext, useEffect, useState, useCallback, useMemo, useRef } from 'react'
import {
  onAuthStateChanged,
  createUserWithEmailAndPassword,
  signInWithEmailAndPassword,
  signOut as fbSignOut,
} from 'firebase/auth'
import { doc, getDoc, setDoc, serverTimestamp } from 'firebase/firestore'
import { auth, db } from '../lib/firebase.js'
import { initialState } from '../data/mockData.js'

const HomiesContext = createContext(null)

const STORAGE_KEY = 'homies-state-v3'

function loadState() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (!raw) return initialState
    return { ...initialState, ...JSON.parse(raw) }
  } catch {
    return initialState
  }
}

function initialsFor(name) {
  const parts = String(name || '').trim().split(/\s+/).filter(Boolean)
  if (parts.length === 0) return '??'
  return parts.slice(0, 2).map((p) => p[0]).join('').toUpperCase()
}

function authErrorMessage(err) {
  switch (err?.code) {
    case 'auth/email-already-in-use':
      return 'An account already exists for that email.'
    case 'auth/invalid-email':
      return "That email address isn't valid."
    case 'auth/weak-password':
      return 'Password is too weak — use at least 6 characters.'
    case 'auth/user-not-found':
    case 'auth/wrong-password':
    case 'auth/invalid-credential':
      return 'Email or password is incorrect.'
    case 'auth/too-many-requests':
      return 'Too many attempts — wait a moment and try again.'
    case 'auth/network-request-failed':
      return 'Network error — check your connection and try again.'
    default:
      return err?.message || `Authentication failed${err?.code ? ` (${err.code})` : ''}.`
  }
}

function buildProfileFromFirestore(fbUser, data) {
  return {
    id: fbUser.uid,
    name: data?.name || fbUser.email || 'User',
    initials: data?.initials || initialsFor(data?.name || fbUser.email || 'U'),
    role: data?.role || 'tenant',
    email: data?.email || fbUser.email || '',
    phone: data?.phone || '',
    moveInDate: data?.moveInDate ?? null,
    moveOutDate: data?.moveOutDate ?? null,
    bondPaid: data?.bondPaid ?? false,
    bondAmount: data?.bondAmount ?? 0,
    docVerified: data?.docVerified ?? false,
    advanceRentPaid: data?.advanceRentPaid ?? false,
    acceptedRulesAt: data?.acceptedRulesAt ?? null,
    pending: data?.pending ?? true,
  }
}

export function HomiesProvider({ children }) {
  const [state, setState] = useState(() => loadState())
  const stateRef = useRef(state)
  stateRef.current = state

  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(state))
    } catch {
      /* localStorage might be full or disabled — non-fatal for demo */
    }
  }, [state])

  const update = useCallback((fn) => setState((s) => fn(s)), [])
  const patch = useCallback((delta) => setState((s) => ({ ...s, ...delta })), [])
  const reset = useCallback(() => {
    localStorage.removeItem(STORAGE_KEY)
    setState(initialState)
  }, [])

  const hydrateUser = useCallback(async (fbUser) => {
    try {
      const snap = await getDoc(doc(db, 'users', fbUser.uid))
      const profile = buildProfileFromFirestore(fbUser, snap.exists() ? snap.data() : null)
      setState((s) => {
        const idx = s.users.findIndex((u) => u.id === fbUser.uid)
        const users = idx >= 0
          ? s.users.map((u, i) => (i === idx ? { ...u, ...profile } : u))
          : [...s.users, profile]
        return {
          ...s,
          users,
          session: { ...s.session, userId: fbUser.uid },
        }
      })
    } catch (e) {
      console.error('Failed to hydrate user from Firestore', e)
    }
  }, [])

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, (fbUser) => {
      if (!fbUser) {
        if (stateRef.current.session.userId != null) {
          setState((s) => ({
            ...s,
            session: { userId: null, pendingSignup: null },
          }))
        }
        return
      }
      const sess = stateRef.current.session
      const haveUser = stateRef.current.users.some((u) => u.id === fbUser.uid)
      if (sess.userId === fbUser.uid && haveUser) return
      hydrateUser(fbUser)
    })
    return () => unsub()
  }, [hydrateUser])

  const signInWithEmail = useCallback(
    async ({ email, password }) => {
      try {
        const cred = await signInWithEmailAndPassword(auth, email.trim(), password)
        await hydrateUser(cred.user)
        return { ok: true }
      } catch (e) {
        return { ok: false, error: authErrorMessage(e) }
      }
    },
    [hydrateUser],
  )

  const signUpWithEmail = useCallback(async ({ email, password, name, role, phone = '' }) => {
    try {
      const cred = await createUserWithEmailAndPassword(auth, email.trim(), password)
      const uid = cred.user.uid
      const displayName = name.trim() || 'New user'
      const initials = initialsFor(displayName)
      await setDoc(doc(db, 'users', uid), {
        name: displayName,
        initials,
        role,
        email: email.trim(),
        phone: phone.trim(),
        pending: true,
        createdAt: serverTimestamp(),
      })
      setState((s) => {
        const newUser = {
          id: uid,
          name: displayName,
          initials,
          role,
          email: email.trim(),
          phone: phone.trim(),
          moveInDate: null,
          moveOutDate: null,
          bondPaid: false,
          bondAmount: 0,
          docVerified: false,
          advanceRentPaid: false,
          acceptedRulesAt: null,
          pending: true,
        }
        return {
          ...s,
          users: [...s.users.filter((u) => u.id !== uid), newUser],
          session: { ...s.session, userId: uid, pendingSignup: { role } },
        }
      })
      return { ok: true }
    } catch (e) {
      return { ok: false, error: authErrorMessage(e) }
    }
  }, [])

  const signOut = useCallback(async () => {
    try {
      await fbSignOut(auth)
    } catch {
      /* no signed-in Firebase user — fine */
    }
    setState((s) => ({
      ...s,
      session: { userId: null, pendingSignup: null },
    }))
  }, [])

  const value = useMemo(() => {
    const currentUser = state.users.find((u) => u.id === state.session.userId) || null
    return {
      state,
      currentUser,
      update,
      patch,
      reset,
      signInWithEmail,
      signUpWithEmail,
      signOut,
    }
  }, [state, update, patch, reset, signInWithEmail, signUpWithEmail, signOut])

  return <HomiesContext.Provider value={value}>{children}</HomiesContext.Provider>
}

export function useHomies() {
  const ctx = useContext(HomiesContext)
  if (!ctx) throw new Error('useHomies must be used within HomiesProvider')
  return ctx
}

export function useUser(id) {
  const { state } = useHomies()
  return state.users.find((u) => u.id === id) || null
}
