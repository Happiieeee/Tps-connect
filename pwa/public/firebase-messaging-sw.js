/* eslint-disable no-undef */
// Firebase Cloud Messaging Service Worker
// This runs in the background to receive push notifications even when the app is closed

importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCa7Vo1QQLb4Os1f2x-ALH_thHS1eTTvCw',
  authDomain: 'tps-connect-bc72b.firebaseapp.com',
  projectId: 'tps-connect-bc72b',
  storageBucket: 'tps-connect-bc72b.firebasestorage.app',
  messagingSenderId: '574925311873',
  appId: '1:574925311873:web:19d83a369b3ac1ef062280',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const { title, body } = payload.notification || {};
  if (title) {
    self.registration.showNotification(title, {
      body,
      icon: '/icon-192.png',
      badge: '/icon-192.png',
      data: payload.data,
    });
  }
});
