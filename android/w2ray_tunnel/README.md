# android/w2ray_tunnel

The native half of the `w2rayTunnel` plugin (`lib/plugins/w2ray_tunnel`). A Gradle module that
`android/settings.gradle.kts` includes only when `w2ray_tunnel` is enabled in `sweetmelon.yaml`.

```
src/main/kotlin/ir/legion/w2ray/
  engine/      plain JVM code, no Android classes (tested on the JVM)
    Config.kt        settings from JavaScript -> checked objects
    WebSocket.kt     RFC 6455 client (TLS name, Host header, certificate check)
    Link.kt          the w2ray tunnel protocol on one WebSocket (auth, connect, bytes)
    Engine.kt        opens links, keeps ready ones, relays bytes, health, DNS over TCP, HTTP GET
    SocksServer.kt   SOCKS5 listener (CONNECT, UDP ASSOCIATE for DNS) used by hev and for sharing
    Net.kt           address helpers, "bypass LAN" routes, hev-socks5-tunnel YAML
  android/     VpnService, notification, network watcher, app list, W2rayApi (the only door)
src/main/kotlin/hev/htproxy/TProxyService.kt   JNI binding of hev-socks5-tunnel (name fixed by the library)
src/main/jni/                                  hev-socks5-tunnel sources + our Android.mk
src/test/kotlin/                               unit and end-to-end tests with a fake w2ray server
```

The app reaches the module through `com.core.sweetmelon.W2rayTunnelHost`, by reflection, so it compiles
without the module.

## Tests

```bash
cd android && ./gradlew :w2ray_tunnel:testDebugUnitTest
```

They run on the JVM: the fake server (`FakeW2rayServer`) speaks the protocol of `src/tunnel/server.js` of
the w2ray project, so SOCKS5 -> engine -> WebSocket -> destination is tested end to end, including a wrong
password, refused destinations, SOCKS5 login, the connection limit, network resets and DNS over TCP.

## Updating hev-socks5-tunnel

`src/main/jni/hev-socks5-tunnel` is a copy of https://github.com/heiher/hev-socks5-tunnel at the commit in its
`.rev-id` (MIT licence, see `LICENSE` there). To update: copy `src`, `include`, `build.mk` and the `Android.mk`,
`build.mk`, `configs.mk`, `include`, `src` of `third-part/{hev-task-system,lwip,yaml}`, set `.rev-id`, and compare
`src/main/jni/Android.mk` with the upstream `Android.mk`. The JNI contract is `hev.htproxy.TProxyService`
(`TProxyStartService`, `TProxyStopService`, `TProxyIsRunning`, `TProxyGetStats`).
