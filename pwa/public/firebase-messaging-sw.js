/* eslint-disable no-undef */
// Firebase Cloud Messaging Service Worker
// This runs in the background to receive push notifications even when the app is closed

importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBqU7NIBH7_xol4fdI5_uYOQQrlohVDxVQ',
  authDomain: 'tps-aut.firebaseapp.com',
  projectId: 'tps-aut',
  storageBucket: 'tps-aut.firebasestorage.app',
  messagingSenderId: '384559680246',
  appId: '1:384559680246:web:bc8a2ca76acade2f5bfad7',
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
