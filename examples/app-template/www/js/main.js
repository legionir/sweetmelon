// NativeSDK comes from js/native-sdk.js, which the build adds from the core.
// The plugins used here (storage, toast) are found by "detect" and switched on.
var S = window.NativeSDK;

S.waitForReady().then(function () {
  return S.storage.get('opens').then(function (res) {
    var n = (Number(res && res.value) || 0) + 1;
    document.getElementById('count').textContent = 'Opened ' + n + ' times';
    return S.storage.set('opens', n);
  });
});

document.getElementById('hello').onclick = function () {
  S.toast.show('Hello from My App');
};
