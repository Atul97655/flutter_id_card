import { getApp, getApps, initializeApp, type FirebaseApp } from 'firebase/app';
import { getAuth, type Auth } from 'firebase/auth';
import { getFirestore, type Firestore } from 'firebase/firestore';
import { getStorage, type FirebaseStorage } from 'firebase/storage';

/**
 * Firebase client for the admin panel.
 *
 * Initialised **lazily**, on first actual use, rather than when this module is
 * evaluated. That matters more than it looks: Next prerenders every page at
 * build time, which evaluates this module on the server, and eager
 * initialisation meant a missing environment variable failed the whole build
 * with `auth/invalid-api-key` while prerendering `/_not-found` - a page that
 * does not use Firebase at all. The error named neither the real cause nor the
 * page that actually needed it.
 *
 * Deferring to first use means the build never touches Firebase, and a
 * misconfiguration surfaces in the browser with a message that says which
 * variable is missing.
 *
 * The config values are public by design. They identify the project; they do
 * not grant access. What protects the data is the deployed Firestore and
 * Storage rules, which check `users/{uid}.role` server side. See
 * docs/SECURITY_RULES.md in the Flutter repo.
 */

const REQUIRED = [
  'NEXT_PUBLIC_FIREBASE_API_KEY',
  'NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN',
  'NEXT_PUBLIC_FIREBASE_PROJECT_ID',
  'NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET',
  'NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID',
  'NEXT_PUBLIC_FIREBASE_APP_ID',
] as const;

function readConfig() {
  const config = {
    apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
    authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
    projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
    storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
    messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
    appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
  };

  const missing = REQUIRED.filter((k) => !process.env[k]);
  if (missing.length > 0) {
    throw new Error(
      `Firebase is not configured. Missing: ${missing.join(', ')}. ` +
        'Copy admin-web/.env.example to .env.local and fill it in, or set ' +
        'these in your hosting provider’s environment variables.',
    );
  }

  return config;
}

let cachedApp: FirebaseApp | null = null;

/**
 * The Firebase app, created once.
 *
 * `getApps()` makes this idempotent across Next's HMR reloads and route
 * segments, where calling `initializeApp` twice would throw.
 */
export function firebaseApp(): FirebaseApp {
  if (cachedApp) return cachedApp;
  cachedApp = getApps().length ? getApp() : initializeApp(readConfig());
  return cachedApp;
}

export function firebaseAuth(): Auth {
  return getAuth(firebaseApp());
}

export function firebaseDb(): Firestore {
  return getFirestore(firebaseApp());
}

/**
 * Cloud Storage.
 *
 * NOT provisioned on this Firebase project - the bucket named in the config
 * does not exist until someone enables Storage, which needs the Blaze plan.
 * Every call through it fails with `object-not-found` or `bucket-not-found`
 * until then, so callers must treat a missing photo as normal rather than as
 * an error.
 */
export function firebaseStorage(): FirebaseStorage {
  return getStorage(firebaseApp());
}

/**
 * Read straight from the environment rather than through the app, so a screen
 * can name the project without forcing Firebase to initialise.
 */
export const FIREBASE_PROJECT_ID =
  process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? 'id-cardx';
