// Optional Firebase Web Push configuration for web/firebase-messaging-sw.js.
// Leave as null to disable Web Push gracefully (the app falls back to live
// WebSocket alerts without console errors).
//
// To enable Web Push in production, replace `null` with your Firebase Web app
// config object (these values are public client identifiers):
//
// self.EVA_FIREBASE_WEB_CONFIG = {
//   apiKey: '...',
//   authDomain: '...',
//   projectId: '...',
//   storageBucket: '...',
//   messagingSenderId: '...',
//   appId: '...',
// };
self.EVA_FIREBASE_WEB_CONFIG = null;
