# Linux VPN service adapter

This package replaces the unavailable `KaringX/vpn-service` dependency for the
Linux build of Karing v1.2.25.2802. It is a new implementation, not decompiled or
recovered original Dart source.

Evidence used:

- The release's `lib/libapp.so` is a Dart AOT snapshot. Its retained symbols name
  `vpn_service_method_channel_pc.dart`, `state.dart`, `proxy_manager.dart`,
  `VpnServiceConfig`, the connection states, and GNOME `gsettings` schemas.
- The app wrapper was recovered from public Karing commit `3c00ed64^`, then
  adapted to the selected tag's settings and diversion-rule interfaces.
- The release's Go core records public source revision
  `93f6a441a141cc4b5914a4c63dd97c77bc69281c` of `KaringX/sing-box`.
  `cmd/sing-box/cmd_extension_karing.go` and
  `cmd/sing-box/cmd_run_extension_karing.go` establish the process arguments,
  ready-socket handshake, and local HTTP control protocol.

The adapter launches the bundled `karingService run2`, waits for its readiness
connection, forwards reload/stop/traffic requests, and reports process exits. It
configures GNOME's system proxy through argument-safe `gsettings` subprocesses
and restores the previous values when disabled. Linux startup integration lives
in the app's existing `launch_at_startup` dependency.

TUN authorization grants `cap_net_admin,cap_net_raw+ep` to the service executable
using `sudo` and password input on stdin. No password is stored. The release
used full setuid permissions; this replacement uses narrower file capabilities.

Supported scope is Linux. GNOME proxy changes require the GNOME proxy schemas,
`gsettings`, and a working user D-Bus session. macOS, Windows, Android, and iOS
native plugin functionality is not reconstructed; their API methods report
unsupported operations. TUN routing requires host network privileges and a TUN
device and must be verified on the target desktop.

Integration validation exercised a real HTTP request through the service's
mixed proxy, traffic JSON, reload, and stop. GNOME proxy enablement and previous
configuration restoration were also exercised in an isolated D-Bus session.

Run the retained integration checks from the repository root:

```sh
dart third_party/vpn_service/tool/service_smoke.dart bind/linux/core/karingService
dart third_party/vpn_service/tool/system_proxy_smoke.dart
```

The proxy check creates its own temporary configuration directory and D-Bus
session; it does not change the desktop user's proxy settings. The service
check binds temporary local ports and requires a built core executable.
