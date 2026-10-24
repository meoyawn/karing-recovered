# karing-recovered

Recovered and reconstructed source needed to build the Linux Flutter desktop
app from the public Karing tag `v1.2.25.2802`.

This independent source-recovery project is not affiliated with or endorsed by
KaringX. It contains a source overlay and patches for the pinned public tag.
The upstream application, release binaries, branding assets, and build caches
are fetched separately or left in the local working directory.

## Build

```sh
git clone https://github.com/meoyawn/karing-recovered.git
cd karing-recovered
python3 scripts/prepare.py --build
```

This prepares `work/karing` at upstream commit
`0c320dc182d095ec0d483f852169421e749c2bac`, applies the patch and source overlay,
and builds a **debug** Linux app. Preparation is also available without a build:

```sh
python3 scripts/prepare.py
```

The scripts require Python 3, Git, Flutter/Dart, Go, clang, CMake, pkg-config,
and network access. The resolved lockfile requires Flutter 3.47 or newer
and Dart 3.13 or newer; the verified build used Flutter 3.47.5 and Dart 3.13.4.
Missing Ubuntu/Debian development libraries can be extracted locally without
sudo. The backend build downloads the recorded Go 1.26.6 toolchain if needed.

Run with Fish after building:

```fish
./work/karing/scripts/run_linux.fish
```

The executable is `work/karing/build/linux/x64/debug/bundle/karing`.
Keep the entire bundle together. The verified host was Ubuntu 26.04 x86-64.
See [Linux build notes](overlay/linux/README.md) for host dependencies and scope.

## What was recovered

- Historical public Dart utilities and the app VPN wrapper were restored from
  commit `e3c19f1eb1225dbd48a4862f0983b82d0af8de69` and adapted to the selected tag.
- The unavailable `vpn-service` package was replaced with a new Linux Dart
  implementation of the real process, readiness, HTTP-control, and GNOME proxy
  interfaces.
- Dart AOT snapshot metadata and targeted source-URI strings informed the
  reconstruction. These do not recover complete original Dart source.
- The Go service's embedded build metadata identified public `KaringX/sing-box`
  revision `93f6a441a141cc4b5914a4c63dd97c77bc69281c`. The build script fetches
  that exact revision and builds its original feature tags from source.
- Config serialization was migrated to the recovered core schema. A published
  hotkey plugin was patched to guard two uninitialized-pointer paths.

The release's Go binary reports a dirty source checkout, so unavailable local
changes remain unknown. This project does not claim a byte-identical or fully
equivalent recreation of the signed upstream release.

[Dart source provenance](overlay/native/reconstruction/dart-source-provenance.json),
[core provenance](overlay/native/linux-core/provenance.json), and the
[CI investigation](overlay/native/reconstruction/ci-investigation.json) record
the source boundaries and limitations. No public app CI download path for the
missing source package was found.

## Validation and remaining gaps

The recovered source produced a Linux debug build, and its GUI opened and
advanced through onboarding. The adapter was exercised against the rebuilt
core with real HTTP proxy traffic, traffic statistics, reload, and shutdown.
GNOME proxy configuration and restoration were checked in an isolated D-Bus
session. Actual app-generated no-TUN configuration passes the rebuilt core's
configuration check. Dart analysis reported zero compile errors, with existing
warnings and lints remaining.

After building, retained integration checks can be run from `work/karing`:

```sh
dart third_party/vpn_service/tool/service_smoke.dart bind/linux/core/karingService
dart third_party/vpn_service/tool/system_proxy_smoke.dart
```

Privileged TUN routing needs validation on the destination desktop. Other
platforms' native plugins have not been reconstructed. Private provider
signing and encrypted-subscription decoding are unavailable; private Sentry
configuration is replaced with disabled telemetry. Statistics and some newer
protocol editors have simplified implementations. Ordinary URL/file subscription
handling remains implemented, but not every application feature is verified.

## Licensing and attribution

New contributions in this repository are provided under GPL-3.0-or-later; see
[LICENSE](LICENSE). Recovered upstream files retain their original terms and
copyright notices. The upstream Karing notice includes an additional
name/association provision and is preserved verbatim in
[LICENSES/Karing-LICENSE.md](LICENSES/Karing-LICENSE.md). The vendored hotkey
plugin retains its MIT license. See [NOTICE](NOTICE) for the file mapping.
