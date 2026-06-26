import { initializeApp } from 'firebase/app'
import { getAuth, createUserWithEmailAndPassword, signInWithEmailAndPassword, signOut as firebaseSignOut, onAuthStateChanged, updateProfile } from 'firebase/auth'
import { getFirestore, doc, setDoc, onSnapshot, collection, getDocs, serverTimestamp } from 'firebase/firestore'
import { firebaseConfig } from './firebaseConfig'

const app = initializeApp(firebaseConfig)
const auth = getAuth(app)
const db = getFirestore(app)

export const getAuthInstance = () => auth
export const getDb = () => db

export const signUp = async (email: string, password: string, displayName?: string) => {
  const userCredential = await createUserWithEmailAndPassword(auth, email, password)
  if (displayName) {
    await updateProfile(userCredential.user, { displayName })
    // store displayName in users collection
    await setDoc(doc(db, 'users', userCredential.user.uid), { displayName })
  } else {
    await setDoc(doc(db, 'users', userCredential.user.uid), { displayName: null })
  }
  return userCredential.user
}

export const signIn = async (email: string, password: string) => {
  const userCredential = await signInWithEmailAndPassword(auth, email, password)
  return userCredential.user
}

export const signOut = async () => {
  await firebaseSignOut(auth)
}

export const onAuthChanged = (cb: (user: any) => void) => {
  return onAuthStateChanged(auth, cb)
}

export const setRating = async (episodeId: string, uid: string, rating: number | null) => {
  const docRef = doc(db, 'ratings', episodeId)
  const data: any = {}
  if (rating === null) {
    data[uid] = null
  } else {
    data[uid] = rating
  }
  data.updatedAt = serverTimestamp()
  await setDoc(docRef, data, { merge: true })
}

export const listenToRatings = (cb: (snapshotData: Record<string, any>) => void) => {
  const col = collection(db, 'ratings')
  // listen to all docs in ratings collection
  return onSnapshot(col, (querySnap) => {
    const out: Record<string, any> = {}
    querySnap.forEach((d) => {
      out[d.id] = d.data()
    })
    cb(out)
  })
}

export const loadUsersMap = async (): Promise<Record<string, string | null>> => {
  const usersSnap = await getDocs(collection(db, 'users'))
  const map: Record<string, string | null> = {}
  usersSnap.forEach((d) => {
    const data = d.data()
    map[d.id] = data.displayName ?? null
  })
  return map
}
