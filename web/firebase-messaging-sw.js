importScripts("https://www.gstatic.com/firebasejs/8.10.1/firebase-app.js");
importScripts("https://www.gstatic.com/firebasejs/8.10.1/firebase-messaging.js");

firebase.initializeApp({
    apiKey: 'AIzaSyCzzCpX6Qlar5_GuEn6fU9OJZiEFx2OJPA',
    appId: '1:422412778152:web:622a0d81c8f4752f24e09d',
    messagingSenderId: '422412778152',
    projectId: 'ppdeli-f07a9',
    authDomain: 'ppdeli-f07a9.firebaseapp.com',
    databaseURL: 'https://ppdeli-f07a9-default-rtdb.firebaseio.com',
    storageBucket: 'ppdeli-f07a9.firebasestorage.app',
    measurementId: 'G-BT2NW6JTWF',
});

const messaging = firebase.messaging();

messaging.setBackgroundMessageHandler(function (payload) {
    const promiseChain = clients
        .matchAll({
            type: "window",
            includeUncontrolled: true
        })
        .then(windowClients => {
            for (let i = 0; i < windowClients.length; i++) {
                const windowClient = windowClients[i];
                windowClient.postMessage(payload);
            }
        })
        .then(() => {
            const title = payload.notification.title;
            const options = {
                body: payload.notification.score
              };
            return registration.showNotification(title, options);
        });
    return promiseChain;
});
self.addEventListener('notificationclick', function (event) {
    console.log('notification received: ', event)
});