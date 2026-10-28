window.mechoPush = {
  subscribe: async function (applicationServerKey) {
    if (!('serviceWorker' in navigator) || !('PushManager' in window)) {
      throw new Error('This browser does not support web push notifications.');
    }

    const permission = await Notification.requestPermission();
    if (permission !== 'granted') {
      throw new Error('Notification permission was not granted.');
    }

    const registration = await navigator.serviceWorker.register(
      '/push_service_worker.js',
      { scope: '/' }
    );
    let subscription = await registration.pushManager.getSubscription();
    if (!subscription) {
      const keyBytes = Uint8Array.from(
        atob(applicationServerKey.replace(/-/g, '+').replace(/_/g, '/')),
        (character) => character.charCodeAt(0)
      );
      subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: keyBytes
      });
    }
    return JSON.stringify(subscription.toJSON());
  }
};
