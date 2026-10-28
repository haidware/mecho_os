let notificationAudioContext;

function prepareNotificationAudio() {
  const AudioContext = window.AudioContext || window.webkitAudioContext;
  if (!AudioContext) return;
  notificationAudioContext ??= new AudioContext();
  if (notificationAudioContext.state === 'suspended') {
    notificationAudioContext.resume().catch((error) => {
      console.warn('Could not enable notification sound:', error);
    });
  }
}

window.mechoPush = {
  subscribe: async function (applicationServerKey) {
    if (
      !('serviceWorker' in navigator) ||
      !('PushManager' in window) ||
      !('Notification' in window)
    ) {
      throw new Error('This browser does not support web push notifications.');
    }

    prepareNotificationAudio();
    const permission = await Notification.requestPermission();
    if (permission !== 'granted') {
      throw new Error(
        permission === 'denied'
          ? 'Notifications are blocked for this site. Allow them in your browser or device settings, then try again.'
          : 'Notification permission was not granted.'
      );
    }

    const registration = await navigator.serviceWorker.register(
      '/push_service_worker.js',
      { scope: '/' }
    );
    await navigator.serviceWorker.ready;
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
  },
  playAlert: function () {
    if ('vibrate' in navigator) {
      navigator.vibrate([180, 90, 180]);
    }

    if (!notificationAudioContext) return false;
    if (notificationAudioContext.state === 'suspended') {
      notificationAudioContext.resume().catch((error) => {
        console.warn('Could not play notification sound:', error);
      });
      return false;
    }

    const oscillator = notificationAudioContext.createOscillator();
    const gain = notificationAudioContext.createGain();
    oscillator.type = 'sine';
    oscillator.frequency.value = 880;
    gain.gain.setValueAtTime(0.0001, notificationAudioContext.currentTime);
    gain.gain.exponentialRampToValueAtTime(
      0.12,
      notificationAudioContext.currentTime + 0.02
    );
    gain.gain.exponentialRampToValueAtTime(
      0.0001,
      notificationAudioContext.currentTime + 0.28
    );
    oscillator.connect(gain);
    gain.connect(notificationAudioContext.destination);
    oscillator.start();
    oscillator.stop(notificationAudioContext.currentTime + 0.3);
    return true;
  }
};
