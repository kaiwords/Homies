import { initializeApp } from 'firebase/app'
import { getAuth } from 'firebase/auth'
import { getFirestore } from 'firebase/firestore'

const firebaseConfig = {
  apiKey: 'AIzaSyB1GvJX4pEekU9f8cNLKXVfrRsJjMhUKlE',
  appId: '1:579052656220:web:aeb7db0d4332218b307899',
  messagingSenderId: '579052656220',
  projectId: 'homies-980c7',
  authDomain: 'homies-980c7.firebaseapp.com',
  storageBucket: 'homies-980c7.firebasestorage.app',
  measurementId: 'G-0WZPLJW4ZB',
}

export const firebaseApp = initializeApp(firebaseConfig)
export const auth = getAuth(firebaseApp)
export const db = getFirestore(firebaseApp)
