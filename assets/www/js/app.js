(function () {
  'use strict';

  var outputEl, logEl, requestCount = 0, eventCount = 0;

  function $(id) { return document.getElementById(id); }

  function updateStats() {
    var info = window.NativeSDK ? window.NativeSDK.info() : null;
    var ready = !!(info && info.initialized);
    var state = $('bridgeState');
    if (!state.classList.contains('is-error')) {
      state.textContent = ready ? 'Ready' : 'Waiting...';
      state.classList.toggle('is-ready', ready);
    }
    $('requestCount').textContent = String(info ? info.totalRequests : requestCount);
    $('pendingCount').textContent = String(info ? info.pendingRequests : 0);
    $('eventCount').textContent = String(eventCount);
  }

  function log(msg, type) {
    type = type || 'info';
    var item = document.createElement('div');
    item.className = 'log-item log-' + type;
    var now = new Date();
    var t = now.toLocaleTimeString('en-US', { hour12: false, hour: '2-digit', minute: '2-digit', second: '2-digit' });
    item.textContent = '[' + t + '] ' + msg;
    logEl.prepend(item);
    while (logEl.children.length > 300) logEl.removeChild(logEl.lastChild);
  }

  function show(data) { outputEl.textContent = JSON.stringify(data, null, 2); }

  function parseJ(v) { if (!v || !v.trim()) return null; try { return JSON.parse(v); } catch (_) { return v; } }

  async function run(label, fn) {
    var ui = window.SweetmelonUI;
    var panel = ui ? ui.currentPanel() : null;
    requestCount++; updateStats(); log('→ ' + label, 'info');
    try {
      var r = await fn(); show(r); log('✓ ' + label, 'success');
      if (ui) ui.markAvailable(panel);
      updateStats(); return r;
    } catch (e) {
      var m = e && e.message ? e.message : JSON.stringify(e);
      if (ui && e && e.code === 'PLUGIN_NOT_FOUND') ui.markUnavailable(panel);
      show({ error: m, raw: e }); log('✗ ' + label + ' — ' + m, 'error'); updateStats(); throw e;
    }
  }

  function bind() {
    var S = window.NativeSDK;
    var runRaw = run;
    // Handlers fire and forget; the error is already shown in Output and Log.
    run = function (label, fn) { return runRaw(label, fn).catch(function () {}); };

    // Header
    $('btnBridgeInfo').onclick = function () { show(S.info()); updateStats(); };
    $('btnClearLog').onclick = function () { logEl.innerHTML = ''; eventCount = 0; updateStats(); };
    $('btnBatchTest').onclick = function () {
      run('batch test (4 calls)', function () {
        return S.batch([
          { plugin: 'storage', method: 'keys', args: {} },
          { plugin: 'deviceInfo', method: 'getAppInfo', args: {} },
          { plugin: 'connectivity', method: 'getStatus', args: {} },
          { plugin: 'clipboard', method: 'hasText', args: {} }
        ], { parallel: true });
      });
    };

    // Permission
    $('btnPermissionCheck').onclick = function () { run('permission.check', function () { return S.permission.check($('permissionName').value.trim()); }); };
    $('btnPermissionRequest').onclick = function () { run('permission.request', function () { return S.permission.request($('permissionName').value.trim()); }); };
    $('btnPermissionKnown').onclick = function () { run('permission.known', function () { return S.permission.getKnownPermissions(); }); };
    $('btnPermissionSettings').onclick = function () { run('permission.settings', function () { return S.permission.openSettings(); }); };

    // App Lifecycle
    $('btnLifecycleState').onclick = function () { run('appLifecycle.getState', function () { return S.appLifecycle.getState(); }); };
    $('btnLifecycleEnable').onclick = function () { run('appLifecycle.enable', function () { return S.appLifecycle.enableEvents(); }); };
    $('btnLifecycleDisable').onclick = function () { run('appLifecycle.disable', function () { return S.appLifecycle.disableEvents(); }); };
    $('btnLifecycleInfo').onclick = function () { run('appLifecycle.info', function () { return S.appLifecycle.getInfo(); }); };

    // Device
    $('btnDeviceInfo').onclick = function () { run('deviceInfo', function () { return S.deviceInfo.getDeviceInfo(); }); };
    $('btnAppInfo').onclick = function () { run('appInfo', function () { return S.deviceInfo.getAppInfo(); }); };
    $('btnDeviceAll').onclick = function () { run('deviceAll', function () { return S.deviceInfo.getAll(); }); };

    // Connectivity
    $('btnConnectivityStatus').onclick = function () { run('connectivity.status', function () { return S.connectivity.getStatus(); }); };
    $('btnConnectivityStart').onclick = function () { run('connectivity.start', function () { return S.connectivity.startWatch(); }); };
    $('btnConnectivityStop').onclick = function () { run('connectivity.stop', function () { return S.connectivity.stopWatch(); }); };
    $('btnConnectivityIsOnline').onclick = function () { run('connectivity.online', function () { return S.connectivity.isOnline(); }); };

    // Storage
    $('btnStorageSet').onclick = function () { run('storage.set', function () { return S.storage.set($('storageKey').value.trim(), parseJ($('storageValue').value)); }); };
    $('btnStorageGet').onclick = function () { run('storage.get', function () { return S.storage.get($('storageKey').value.trim()); }); };
    $('btnStorageHas').onclick = function () { run('storage.has', function () { return S.storage.has($('storageKey').value.trim()); }); };
    $('btnStorageKeys').onclick = function () { run('storage.keys', function () { return S.storage.keys(); }); };
    $('btnStorageRemove').onclick = function () { run('storage.remove', function () { return S.storage.remove($('storageKey').value.trim()); }); };
    $('btnStorageClear').onclick = function () { run('storage.clear', function () { return S.storage.clear(); }); };

    // FileSystem
    $('btnFsDirs').onclick = function () { run('fs.dirs', function () { return S.fileSystem.getDirectories(); }); };
    $('btnFsWrite').onclick = function () { run('fs.write', function () { return S.fileSystem.writeFile($('filePath').value.trim(), $('fileContent').value); }); };
    $('btnFsRead').onclick = function () { run('fs.read', function () { return S.fileSystem.readFile($('filePath').value.trim()); }); };
    $('btnFsExists').onclick = function () { run('fs.exists', function () { return S.fileSystem.fileExists($('filePath').value.trim()); }); };
    $('btnFsList').onclick = function () { run('fs.list', function () { return S.fileSystem.listFiles('demo', { recursive: true }); }); };
    $('btnFsStat').onclick = function () { run('fs.stat', function () { return S.fileSystem.stat($('filePath').value.trim()); }); };
    $('btnFsDelete').onclick = function () { run('fs.delete', function () { return S.fileSystem.deleteFile($('filePath').value.trim()); }); };

    // HTTP
    $('btnHttpGet').onclick = function () { run('http.get', function () { return S.http.get($('httpUrl').value.trim(), { responseType: 'json' }); }); };
    $('btnHttpPost').onclick = function () { run('http.post', function () { return S.http.post('https://jsonplaceholder.typicode.com/posts', { title: 'sweetmelon', body: 'post body', userId: 1 }, { bodyType: 'json', responseType: 'json' }); }); };
    $('btnHttpDownload').onclick = function () { run('http.download', function () { return S.http.download({ url: 'https://jsonplaceholder.typicode.com/todos/1', fileName: 'todo.json', baseDir: 'temporary' }); }); };

    // Intent
    $('btnIntentCanOpen').onclick = function () { run('intent.canOpen', function () { return S.intent.canOpenUrl($('intentUrl').value.trim()); }); };
    $('btnIntentOpen').onclick = function () { run('intent.open', function () { return S.intent.openUrl($('intentUrl').value.trim()); }); };
    $('btnIntentInitial').onclick = function () { run('intent.initial', function () { return S.intent.getInitialLink(); }); };
    $('btnIntentLatest').onclick = function () { run('intent.latest', function () { return S.intent.getLatestLink(); }); };
    $('btnIntentListenStart').onclick = function () { run('intent.listen', function () { return S.intent.startListening(); }); };
    $('btnIntentListenStop').onclick = function () { run('intent.stopListen', function () { return S.intent.stopListening(); }); };

    // Clipboard
    $('btnClipboardWrite').onclick = function () { run('clipboard.write', function () { return S.clipboard.writeText($('clipboardText').value); }); };
    $('btnClipboardRead').onclick = function () { run('clipboard.read', function () { return S.clipboard.readText(); }); };
    $('btnClipboardHas').onclick = function () { run('clipboard.has', function () { return S.clipboard.hasText(); }); };
    $('btnClipboardClear').onclick = function () { run('clipboard.clear', function () { return S.clipboard.clear(); }); };

    // Share
    $('btnShareText').onclick = function () { run('share.text', function () { return S.share.shareText($('shareText').value, 'Sweetmelon'); }); };
    $('btnShareFile').onclick = async function () {
      await run('fs.write (prep share)', function () { return S.fileSystem.writeFile('share/demo.txt', 'Share file at ' + new Date().toISOString()); });
      var dirs = await run('fs.dirs', function () { return S.fileSystem.getDirectories(); });
      await run('share.files', function () { return S.share.shareFiles([(dirs.documents || '') + '/share/demo.txt'], 'Shared file', 'Sweetmelon'); });
    };

    // Camera
    $('btnCameraInfo').onclick = function () { run('camera.info', function () { return S.camera.getInfo(); }); };
    $('btnTakePhoto').onclick = function () { run('camera.photo', function () { return S.camera.takePhoto({ quality: 80 }); }); };
    $('btnPickGallery').onclick = function () { run('camera.gallery', function () { return S.camera.pickFromGallery({ multiple: false }); }); };

    // Geolocation
    $('btnGeoPermission').onclick = function () { run('geo.checkPerm', function () { return S.geolocation.checkPermission(); }); };
    $('btnGeoRequestPermission').onclick = function () { run('geo.requestPerm', function () { return S.geolocation.requestPermission(); }); };
    $('btnGeoCurrent').onclick = function () { run('geo.current', function () { return S.geolocation.getCurrentPosition({ accuracy: 'high' }); }); };
    $('btnGeoStart').onclick = function () { run('geo.watch', function () { return S.geolocation.watchPosition({ accuracy: 'high', distanceFilter: 10 }); }); };
    $('btnGeoStop').onclick = function () { run('geo.stop', function () { return S.geolocation.clearWatch(); }); };
    $('btnGeoEnabled').onclick = function () { run('geo.enabled', function () { return S.geolocation.isLocationEnabled(); }); };

    // ── فاز ۳ ──

    // Back Button
    $('btnBackEnable').onclick = function () { run('back.enableIntercept', function () { return S.backButton.enableIntercept(); }); };
    $('btnBackDisable').onclick = function () { run('back.disableIntercept', function () { return S.backButton.disableIntercept(); }); };
    $('btnBackState').onclick = function () { run('back.state', function () { return S.backButton.getState(); }); };
    $('btnBackExitOnBack').onclick = function () { run('back.exitOnBack', function () { return S.backButton.setExitOnBack(true); }); };
    $('btnBackMinimize').onclick = function () { run('back.minimize', function () { return S.backButton.minimizeApp(); }); };
    $('btnBackExit').onclick = function () { run('back.exit', function () { return S.backButton.exitApp(); }); };

    // Secure Storage
    $('btnSecSet').onclick = function () { run('sec.set', function () { return S.secureStorage.set($('secKey').value.trim(), $('secValue').value); }); };
    $('btnSecGet').onclick = function () { run('sec.get', function () { return S.secureStorage.get($('secKey').value.trim()); }); };
    $('btnSecHas').onclick = function () { run('sec.has', function () { return S.secureStorage.has($('secKey').value.trim()); }); };
    $('btnSecKeys').onclick = function () { run('sec.keys', function () { return S.secureStorage.keys(); }); };
    $('btnSecRemove').onclick = function () { run('sec.remove', function () { return S.secureStorage.remove($('secKey').value.trim()); }); };
    $('btnSecClear').onclick = function () { run('sec.clear', function () { return S.secureStorage.clear(); }); };
    $('btnSecInfo').onclick = function () { run('sec.info', function () { return S.secureStorage.getInfo(); }); };

    // Notification
    $('btnNotifShow').onclick = function () { run('notif.show', function () { return S.notification.show({ title: $('notifTitle').value, body: $('notifBody').value, payload: 'custom-payload-123' }); }); };
    $('btnNotifCancelAll').onclick = function () { run('notif.cancelAll', function () { return S.notification.cancelAll(); }); };
    $('btnNotifActive').onclick = function () { run('notif.active', function () { return S.notification.getActive(); }); };
    $('btnNotifPending').onclick = function () { run('notif.pending', function () { return S.notification.getPending(); }); };
    $('btnNotifChannel').onclick = function () { run('notif.channel', function () { return S.notification.createChannel({ channelId: 'alerts', channelName: 'Alerts', importance: 'high' }); }); };
    $('btnNotifInfo').onclick = function () { run('notif.info', function () { return S.notification.getInfo(); }); };

    // Status Bar
    $('btnSbDark').onclick = function () { run('sb.dark', function () { return S.statusBar.setStyle('dark'); }); };
    $('btnSbLight').onclick = function () { run('sb.light', function () { return S.statusBar.setStyle('light'); }); };
    $('btnSbHide').onclick = function () { run('sb.hide', function () { return S.statusBar.hide(); }); };
    $('btnSbShow').onclick = function () { run('sb.show', function () { return S.statusBar.show(); }); };
    $('btnSbFullscreen').onclick = function () { run('sb.fullscreen', function () { return S.statusBar.setFullscreen(); }); };
    $('btnSbExitFs').onclick = function () { run('sb.exitFs', function () { return S.statusBar.exitFullscreen(); }); };

    // Orientation
    $('btnOrPortrait').onclick = function () { run('or.portrait', function () { return S.orientation.lock('portrait'); }); };
    $('btnOrLandscape').onclick = function () { run('or.landscape', function () { return S.orientation.lock('landscape'); }); };
    $('btnOrUnlock').onclick = function () { run('or.unlock', function () { return S.orientation.unlock(); }); };
    $('btnOrInfo').onclick = function () { run('or.info', function () { return S.orientation.getInfo(); }); };

    // Haptic
    $('btnHapLight').onclick = function () { run('hap.light', function () { return S.haptic.lightImpact(); }); };
    $('btnHapMedium').onclick = function () { run('hap.medium', function () { return S.haptic.mediumImpact(); }); };
    $('btnHapHeavy').onclick = function () { run('hap.heavy', function () { return S.haptic.heavyImpact(); }); };
    $('btnHapClick').onclick = function () { run('hap.click', function () { return S.haptic.selectionClick(); }); };
    $('btnHapVibrate').onclick = function () { run('hap.vibrate', function () { return S.haptic.vibrate(); }); };

    // Keyboard
    $('btnKbState').onclick = function () { run('kb.state', function () { return S.keyboard.getState(); }); };
    $('btnKbWatch').onclick = function () { run('kb.watch', function () { return S.keyboard.startWatch(); }); };
    $('btnKbStopWatch').onclick = function () { run('kb.stopWatch', function () { return S.keyboard.stopWatch(); }); };
    $('btnKbHide').onclick = function () { run('kb.hide', function () { return S.keyboard.hide(); }); };
    $('btnKbInfo').onclick = function () { run('kb.info', function () { return S.keyboard.getInfo(); }); };

    // ── فاز ۴ ──

    // Biometrics
    $('btnBioAvailable').onclick = function () { run('bio.isAvailable', function () { return S.biometrics.isAvailable(); }); };
    $('btnBioTypes').onclick = function () { run('bio.types', function () { return S.biometrics.getAvailableBiometrics(); }); };
    $('btnBioAuth').onclick = function () { run('bio.authenticate', function () { return S.biometrics.authenticate({ reason: 'Please verify your identity' }); }); };
    $('btnBioInfo').onclick = function () { run('bio.info', function () { return S.biometrics.getInfo(); }); };

    // QR
    $('btnQrScan').onclick = function () { run('qr.scan', function () { return S.qrScanner.scan({ timeoutMs: 60000 }); }); };
    $('btnQrInfo').onclick = function () { run('qr.info', function () { return S.qrScanner.getInfo(); }); };

    // Audio
    var lastRecPath = null;
    $('btnAudioRecord').onclick = function () { run('audio.record', function () { return S.audio.startRecording(); }); };
    $('btnAudioStopRecord').onclick = async function () {
      var r = await run('audio.stopRecord', function () { return S.audio.stopRecording(); });
      if (r && r.path) lastRecPath = r.path;
    };
    $('btnAudioPlay').onclick = function () {
      run('audio.play', function () {
        return S.audio.play({ path: lastRecPath || '', url: lastRecPath ? null : 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3' });
      });
    };
    $('btnAudioPause').onclick = function () { run('audio.pause', function () { return S.audio.pause(); }); };
    $('btnAudioResume').onclick = function () { run('audio.resume', function () { return S.audio.resume(); }); };
    $('btnAudioStop').onclick = function () { run('audio.stop', function () { return S.audio.stop(); }); };
    $('btnAudioInfo').onclick = function () { run('audio.info', function () { return S.audio.getInfo(); }); };

    // SMS OTP
    $('btnSmsSignature').onclick = function () { run('sms.signature', function () { return S.smsOtp.getAppSignature(); }); };
    $('btnSmsListen').onclick = function () { run('sms.listen', function () { return S.smsOtp.startListening(); }); };
    $('btnSmsStop').onclick = function () { run('sms.stop', function () { return S.smsOtp.stopListening(); }); };
    $('btnSmsLastCode').onclick = function () { run('sms.lastCode', function () { return S.smsOtp.getLastCode(); }); };
    $('btnSmsHint').onclick = function () { run('sms.hint', function () { return S.smsOtp.requestHint(); }); };
    $('btnSmsInfo').onclick = function () { run('sms.info', function () { return S.smsOtp.getInfo(); }); };

    // Download Manager
    $('btnDlStart').onclick = function () {
      run('dl.download', function () {
        return S.downloadManager.download({
          url: $('downloadUrl').value.trim(),
          fileName: 'test-download.bin',
          baseDir: 'temporary'
        });
      });
    };
    $('btnDlCancelAll').onclick = function () { run('dl.cancelAll', function () { return S.downloadManager.cancelAll(); }); };
    $('btnDlActive').onclick = function () { run('dl.active', function () { return S.downloadManager.getActive(); }); };
    $('btnDlInfo').onclick = function () { run('dl.info', function () { return S.downloadManager.getInfo(); }); };

    // Database
    $('btnDbOpen').onclick = function () {
      run('db.open', function () {
        return S.database.open('testdb', {
          version: 1,
          onCreate: [
            'CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, email TEXT, age INTEGER, created_at TEXT DEFAULT CURRENT_TIMESTAMP)'
          ]
        });
      });
    };
    $('btnDbInsert').onclick = function () {
      run('db.insert', function () {
        return S.database.insert('testdb', 'users', {
          name: 'User ' + Math.floor(Math.random() * 1000),
          email: 'user@example.com',
          age: Math.floor(Math.random() * 50) + 18
        });
      });
    };
    $('btnDbQuery').onclick = function () { run('db.query', function () { return S.database.query('testdb', 'users', { orderBy: 'id DESC', limit: 20 }); }); };
    $('btnDbUpdate').onclick = function () {
      run('db.update', function () {
        return S.database.update('testdb', 'users', { name: 'Updated User' }, { where: 'id = ?', whereArgs: [1] });
      });
    };
    $('btnDbDelete').onclick = function () {
      run('db.delete', function () {
        return S.database.delete('testdb', 'users', { where: 'id = ?', whereArgs: [1] });
      });
    };
    $('btnDbDrop').onclick = function () { run('db.drop', function () { return S.database.deleteDatabase('testdb'); }); };
    $('btnDbInfo').onclick = function () { run('db.info', function () { return S.database.getInfo(); }); };

    // Contacts
    $('btnContactCount').onclick = function () { run('contacts.count', function () { return S.contacts.getCount(); }); };
    $('btnContactAll').onclick = function () { run('contacts.all', function () { return S.contacts.getAll({ limit: 10, withPhoto: false }); }); };
    $('btnContactSearch').onclick = function () { run('contacts.search', function () { return S.contacts.search($('contactQuery').value.trim()); }); };
    $('btnContactPick').onclick = function () { run('contacts.pick', function () { return S.contacts.pickContact(); }); };
    $('btnContactInfo').onclick = function () { run('contacts.info', function () { return S.contacts.getInfo(); }); };

    // Network Info
    $('btnNetInterfaces').onclick = function () { run('networkInfo.interfaces', function () { return S.networkInfo.getInterfaces(); }); };
    $('btnNetIps').onclick = function () { run('networkInfo.ips', function () { return S.networkInfo.getIpAddresses(); }); };
    $('btnNetLocalIp').onclick = function () { run('networkInfo.localIp', function () { return S.networkInfo.getLocalIp(); }); };
    $('btnNetExternalIp').onclick = function () { run('networkInfo.externalIp', function () { return S.networkInfo.getExternalIp(); }); };
    $('btnNetGateway').onclick = function () { run('networkInfo.gateway', function () { return S.networkInfo.getGateway(); }); };
    $('btnNetHostname').onclick = function () { run('networkInfo.hostname', function () { return S.networkInfo.getHostname(); }); };
    $('btnNetInfo').onclick = function () { run('networkInfo.info', function () { return S.networkInfo.getInfo(); }); };

    // Encryption
    $('btnEncGenKey').onclick = function () {
      run('encryption.generateAesKey', async function () {
        var r = await S.encryption.generateAesKey(256);
        $('encKey').value = r.key || '';
        $('encIv').value = r.iv || '';
        return r;
      });
    };
    $('btnEncAesEncrypt').onclick = function () {
      run('encryption.aesEncrypt', async function () {
        var r = await S.encryption.aesEncrypt($('encText').value, $('encKey').value.trim(), $('encIv').value.trim() || undefined);
        if (r && r.encrypted) $('encCipher').value = r.encrypted;
        if (r && r.iv) $('encIv').value = r.iv;
        return r;
      });
    };
    $('btnEncAesDecrypt').onclick = function () { run('encryption.aesDecrypt', function () { return S.encryption.aesDecrypt($('encCipher').value.trim(), $('encKey').value.trim(), $('encIv').value.trim()); }); };
    $('btnEncSha256').onclick = function () { run('encryption.sha256', function () { return S.encryption.hashSha256($('encText').value); }); };
    $('btnEncSha512').onclick = function () { run('encryption.sha512', function () { return S.encryption.hashSha512($('encText').value); }); };
    $('btnEncMd5').onclick = function () { run('encryption.md5', function () { return S.encryption.hashMd5($('encText').value); }); };
    $('btnEncHmac').onclick = function () { run('encryption.hmacSha256', function () { return S.encryption.hmacSha256($('encText').value, $('encKey').value.trim() || 'secret'); }); };
    $('btnEncRandom').onclick = function () { run('encryption.randomBytes', function () { return S.encryption.generateRandomBytes(32); }); };
    $('btnEncB64Enc').onclick = function () { run('encryption.base64Encode', function () { return S.encryption.base64Encode($('encText').value); }); };
    $('btnEncB64Dec').onclick = function () { run('encryption.base64Decode', function () { return S.encryption.base64Decode($('encText').value); }); };
    $('btnEncInfo').onclick = function () { run('encryption.info', function () { return S.encryption.getInfo(); }); };

    // Toast
    $('btnToastShort').onclick = function () { run('toast.short', function () { return S.toast.show($('toastText').value, { duration: 'short' }); }); };
    $('btnToastLong').onclick = function () { run('toast.long', function () { return S.toast.show($('toastText').value, { duration: 'long' }); }); };
    $('btnToastTop').onclick = function () { run('toast.top', function () { return S.toast.show($('toastText').value, { position: 'top' }); }); };
    $('btnToastError').onclick = function () { run('toast.error', function () { return S.toast.show($('toastText').value, { backgroundColor: '#F44336', textColor: '#FFFFFF' }); }); };
    $('btnToastInfo').onclick = function () { run('toast.info', function () { return S.toast.getInfo(); }); };

    // File Picker
    $('btnPickFiles').onclick = function () { run('filePicker.files', function () { return S.filePicker.pickFiles({ multiple: true }); }); };
    $('btnPickImages').onclick = function () { run('filePicker.images', function () { return S.filePicker.pickImages({ multiple: true }); }); };
    $('btnPickVideos').onclick = function () { run('filePicker.videos', function () { return S.filePicker.pickVideos(); }); };
    $('btnPickMedia').onclick = function () { run('filePicker.media', function () { return S.filePicker.pickMedia({ multiple: true }); }); };
    $('btnPickDir').onclick = function () { run('filePicker.directory', function () { return S.filePicker.pickDirectory(); }); };
    $('btnPickInfo').onclick = function () { run('filePicker.info', function () { return S.filePicker.getInfo(); }); };

    // Safe Area
    $('btnSafeInsets').onclick = function () { run('safeArea.insets', function () { return S.safeArea.getInsets(); }); };
    $('btnSafeScreen').onclick = function () { run('safeArea.screen', function () { return S.safeArea.getScreenInfo(); }); };
    $('btnSafeInfo').onclick = function () { run('safeArea.info', function () { return S.safeArea.getInfo(); }); };

    // Phone Dialer
    $('btnPhoneDial').onclick = function () { run('phone.dial', function () { return S.phoneDialer.dial($('phoneNumber').value.trim()); }); };
    $('btnPhoneCall').onclick = function () { run('phone.call', function () { return S.phoneDialer.directCall($('phoneNumber').value.trim()); }); };
    $('btnPhoneSms').onclick = function () { run('phone.sms', function () { return S.phoneDialer.sendSms($('phoneNumber').value.trim(), 'Hello from Sweetmelon'); }); };
    $('btnPhoneEmail').onclick = function () { run('phone.email', function () { return S.phoneDialer.sendEmail({ to: $('emailTo').value.trim(), subject: 'Hello', body: 'Sent from Sweetmelon bridge' }); }); };
    $('btnPhoneCanDial').onclick = function () { run('phone.canDial', function () { return S.phoneDialer.canDial($('phoneNumber').value.trim()); }); };
    $('btnPhoneInfo').onclick = function () { run('phone.info', function () { return S.phoneDialer.getInfo(); }); };
  }

  function bindEvents() {
    var S = window.NativeSDK;

    var events = [
      'app.lifecycle.change',
      'connectivity.change',
      'connectivity.error',
      'intent.deepLink',
      'intent.error',
      'geolocation.position',
      'geolocation.error',
      'backButton.pressed',
      'notification.tap',
      'keyboard.change'
    ];

    events.forEach(function (ev) {
      S.on(ev, function (data) {
        eventCount++;
        log('EVENT ' + ev + ' → ' + JSON.stringify(data), 'event');
        updateStats();
      });
    });

    // فاز ۴ events
    var phase4Events = [
      'qrScanner.scanned',
      'audio.playerState',
      'audio.position',
      'smsOtp.received',
      'download.progress',
      'download.complete',
      'download.error'
    ];

    phase4Events.forEach(function (ev) {
      S.on(ev, function (data) {
        eventCount++;
        var msg = JSON.stringify(data);
        if (msg.length > 120) msg = msg.substring(0, 120) + '...';
        log('EVENT ' + ev + ' → ' + msg, 'event');
        updateStats();
      });
    });
  }

  async function init() {
    outputEl = $('output');
    logEl = $('log');
    updateStats();
    log('Initializing NativeSDK...', 'info');

    try {
      await window.NativeSDK.waitForReady(10000);
    } catch (e) {
      var state = $('bridgeState');
      state.textContent = 'Unavailable';
      state.classList.add('is-error');
      log('Native bridge not available (' + e.message + '). Open this page inside the Sweetmelon app.', 'error');
      show({ error: e.message });
      bind();
      return;
    }

    log('NativeSDK ready', 'success');
    updateStats();
    bind();
    bindEvents();

    try { await window.NativeSDK.connectivity.startWatch(); } catch (_) {}
    try { await window.NativeSDK.intent.startListening(); } catch (_) {}
    try { await window.NativeSDK.keyboard.startWatch(); } catch (_) {}
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
