import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getMessaging, isSupported } from 'firebase/messaging';

const firebaseConfig = {
  apiKey: 'AIzaSyCa7Vo1QQLb4Os1f2x-ALH_thHS1eTTvCw',
  authDomain: 'tps-connect-bc72b.firebaseapp.com',
  projectId: 'tps-connect-bc72b',
  storageBucket: 'tps-connect-bc72b.firebasestorage.app',
  messagingSenderId: '574925311873',
  appId: '1:574925311873:web:19d83a369b3ac1ef062280',
  measurementId: 'G-ND4SVME5EE',
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);

// Messaging may not be supported in all browsers (e.g. Safari < 16.4)
let messagingInstance = null;
export const getMessagingInstance = async () => {
  if (messagingInstance) return messagingInstance;
  const supported = await isSupported();
  if (supported) {
    messagingInstance = getMessaging(app);
  }
  return messagingInstance;
};

export default app;
