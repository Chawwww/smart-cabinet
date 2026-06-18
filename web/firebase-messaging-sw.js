// 导入 Firebase SDK
importScripts("https://www.gstatic.com/firebasejs/9.6.11/firebase-app.js");
importScripts("https://www.gstatic.com/firebasejs/9.6.11/firebase-messaging.js");

// 初始化 Firebase
firebase.initializeApp({
  apiKey: "AIzaSyDmRMUUPm3sUtqvd_yeNi3bpOtn5dxClRs",
  authDomain: "smart-cabinet-test-7.firebaseapp.com",
  projectId: "smart-cabinet-test-7",
  storageBucket: "smart-cabinet-test-7.firebasestorage.app",
  messagingSenderId: "783044757243",
  appId: "1:783044757243:web:48ee2d87a70ed8f078125e",
  measurementId: "G-WDJQ07KJQX"
});

// 初始化 Messaging
const messaging = firebase.messaging();
