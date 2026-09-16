import { getApp, getApps, initializeApp, type FirebaseApp } from 'firebase/app';
import { getAuth, type Auth } from 'firebase/auth';
import { getFirestore, type Firestore } from 'firebase/firestore';
import { getStorage, type FirebaseStorage } from 'firebase/storage';

/**
 * Firebase client for the admin panel.
 *
 * The keys below are public by design. What protects this data is the deployed
 * Firestore/Storage rules, which check `users/{uid}.role == 'Admin'` server
 * side - not the presence of an API key, and not the role check this app does
 * for its own UI. See docs/SECURITY_RULES.md in the Flutter repo.
 */
const config = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
};

/**
 * Next re-executes modules across HMR reloads and route segments, and calling
 * initializeApp twice throws. getApps() makes this idempotent.
 */
export const app: FirebaseApp = getApps().length ? getApp() : initializeApp(config);

export const auth: Auth = getAuth(app);
export const db: Firestore = getFirestore(app);

/**
 * Storage is exported but NOT yet provisioned on this Firebase project - the
 * bucket named above does not exist until someone enables it (which needs the
 * Blaze plan). Every call through it will fail with `object-not-found` or
 * `bucket-not-found` until then, so callers must treat a missing photo as
 * normal rather than as an error. See `isStorageMissing` in ./errors.
 */
export const storage: FirebaseStorage = getStorage(app);

export const FIREBASE_PROJECT_ID = config.projectId ?? 'id-cardx';
