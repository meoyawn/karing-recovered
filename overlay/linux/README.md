# Reconstructed Linux desktop build

The base is tag `v1.2.25.2802` (`0c320dc1`). This checkout adds the source missing
from the public tag so the Flutter Linux desktop app can be built locally.
It is a reconstructed build, with the limitations below, rather than a
byte-identical copy of the signed upstream release.

From the repository root:

```sh
python3 scripts/build_linux.py
```

The build requires Flutter/Dart, Go, clang, CMake, pkg-config, Git, Python 3,
and network access for pinned dependencies. On Ubuntu/Debian the script can
extract missing GTK, libsecret, AppIndicator, keybinder, curl, and Ninja packages
under `.dart_tool/linux-toolchain` without installing system packages or using
sudo. Go downloads the recorded compiler version, `go1.26.6`, if needed.
Temporary build files also stay under `.dart_tool`. The default is a fast debug
build; an existing recovered core binary is reused. To rebuild the core from
its pinned public source explicitly, run `bash native/linux-core/build.sh`.

Outputs:

- `build/linux/x64/debug/bundle/karing`: desktop executable; keep the entire
  adjacent bundle together.

On this checkout, launch with Fish:

```fish
./scripts/run_linux.fish
```

The launcher includes the locally extracted libraries when present. On another
Linux desktop, install the GTK 3, libsecret, AppIndicator, keybinder, and X11
runtime dependencies before running the unpacked bundle. The host used for
this build is Ubuntu 26.04 x86-64; compatibility with older distributions has
not been established.

## Source recovery

- The release's `libapp.so` exports Dart VM/isolate AOT snapshots. REA parsed
  those sections and their shared snapshot hash. A separate bounded string
  search identified Karing and `vpn_service` source URI strings. These reveal
  source names and compiler structure, not complete original Dart source.
- Most utility and VPN wrapper source was available in the public repository
  at `e3c19f1eb1225dbd48a4862f0983b82d0af8de69`, before its removal in June
  2025. It was restored and adapted to the selected tag's types and APIs.
- `third_party/vpn_service` is a new Linux implementation of the missing Dart
  package. Its process/HTTP protocol comes from the matching public Go source;
  its integration checks exercise the real service and GNOME proxy settings.
- The release's `karingService` embeds Go build metadata pointing to
  `KaringX/sing-box` revision `93f6a441a141cc4b5914a4c63dd97c77bc69281c`.
  `native/linux-core/build.sh` fetches and validates that revision and builds
  the recorded feature tags from source. Cronet is a pinned upstream runtime
  dependency, with the same bytes as the release's `libcronet.so`.
- The vendored hotkey plugin is the published `hotkey_manager_linux` 0.2.0
  source with guards for missing registrations, fixing two uninitialized
  pointer paths detected by clang 21.

Core provenance is in `native/linux-core/provenance.json`. Investigation
records and test logs are retained locally under `.dart_tool/reconstruction`.
The public app repository contains no release build workflows in its reachable
Git history. The checked public Actions metadata supplies no additional source
download path for this tag. A private pipeline or a local release process
remains possible and has not been established.

## Scope and limitations

The reconstructed platform adapter supports Linux. Other operating systems'
native plugins have not been recreated. GNOME system proxy integration needs
`gsettings`, the GNOME proxy schemas, and a working user D-Bus session. TUN
requires a TUN device and network capabilities; privileged host routing needs
validation on the destination desktop.

Private provider signing/encrypted subscription formats cannot be recovered
from the available source and are reported as unavailable. Standard URL/file
subscription handling remains implemented. Private Sentry configuration is
replaced by disabled telemetry. Statistics are exposed through a simplified
record viewer; newer protocol configuration editors preserve imported raw
options without reproducing all original editor behavior.

The original Go binary reports a dirty checkout. The public source revision
cannot reproduce its unavailable local changes, and the rebuilt service uses
an explicit reconstructed version string. The complete app has not been proven
behaviorally equivalent to the upstream release.
