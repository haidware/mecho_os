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
  getSetupStatus: function () {
    const userAgent = navigator.userAgent || '';
    const isIOS =
      /iPad|iPhone|iPod/.test(userAgent) ||
      (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
    const isAndroid = /Android/i.test(userAgent);
    const standalone =
      navigator.standalone === true ||
      window.matchMedia('(display-mode: standalone)').matches;
    const supported =
      'Notification' in window &&
      'serviceWorker' in navigator &&
      'PushManager' in window;
    let message = '';

    if (!supported) {
      message = 'This browser does not support web push notifications. Open Mecho OS in a supported browser.';
    } else if (isIOS && !standalone) {
      message = 'On iPhone or iPad, first use Share > Add to Home Screen, then open Mecho OS from its Home Screen icon. iOS only allows web push from the installed app.';
    } else if (Notification.permission === 'denied') {
      message = isAndroid
        ? 'Notifications are blocked. Allow them in Android Settings > Apps > Mecho OS > Notifications, or in Chrome site settings.'
        : 'Notifications are blocked for this app. Allow them in your device or browser settings, then return to Mecho OS.';
    }

    return JSON.stringify({
      supported,
      isIOS,
      isAndroid,
      standalone,
      permission: supported ? Notification.permission : 'unsupported',
      canRequest: supported && Notification.permission !== 'denied' && (!isIOS || standalone),
      message
    });
  },
  getSubscription: async function () {
    if (!('serviceWorker' in navigator) || !('PushManager' in window)) {
      return 'null';
    }
    const registration = await navigator.serviceWorker.getRegistration('/');
    const subscription = registration
      ? await registration.pushManager.getSubscription()
      : null;
    return JSON.stringify(subscription ? subscription.toJSON() : null);
  },
  requestPermission: function () {
    if (!('Notification' in window)) {
      return Promise.reject(
        new Error('This browser does not support web notifications.')
      );
    }

    if (
      navigator.userActivation &&
      !navigator.userActivation.isActive
    ) {
      return Promise.reject(
        new Error(
          'Tap Enable alerts directly in Mecho OS. Your browser may block the permission prompt unless it follows your tap.'
        )
      );
    }

    prepareNotificationAudio();
    return Notification.requestPermission();
  },
  subscribe: async function (applicationServerKey) {
    if (
      !('serviceWorker' in navigator) ||
      !('PushManager' in window) ||
      !('Notification' in window)
    ) {
      throw new Error('This browser does not support web push notifications.');
    }

    const setup = window.mechoPush.getSetupStatus();
    const status = JSON.parse(setup);
    if (!status.canRequest) {
      throw new Error(status.message || 'Notifications are not available in this browser.');
    }

    const permission = Notification.permission === 'granted'
      ? 'granted'
      : await window.mechoPush.requestPermission();
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
