# mirror-cyclonedx

OCX mirror for [cargo-cyclonedx](https://github.com/CycloneDX/cyclonedx-rust-cargo),
the official OWASP CycloneDX SBOM generator for Cargo projects. One repository,
one spec directory per package.

| Package | Spec | Publishes to | Announced as | Upstream SPDX |
|---|---|---|---|---|
| [cargo-cyclonedx](https://github.com/CycloneDX/cyclonedx-rust-cargo) | [`cargo-cyclonedx/mirror.yml`](cargo-cyclonedx/mirror.yml) | `ghcr.io/ocx-contrib/cyclonedx/cargo-cyclonedx` | [`ocx.sh/cyclonedx/cargo-cyclonedx`](https://index.ocx.sh/cyclonedx/cargo-cyclonedx) | `Apache-2.0` |

Each upstream release is discovered, re-bundled, smoke-tested per
`(version, platform)` and only then pushed with cascade tags, after which the
result is announced into the OCX index.

> **The upstream repository is not named after the package.** `cargo-cyclonedx`
> is one crate inside the `cyclonedx-rust-cargo` workspace, which also holds the
> `cyclonedx-bom` library. The two release under **different tag schemes on
> different cadences** — `cargo-cyclonedx-X.Y.Z` and `cyclonedx-bom-X.Y.Z` — so
> `tag_pattern` anchors the literal `cargo-cyclonedx-` prefix. There is no `v`
> prefix on either scheme, and a handful of bare legacy tags (`0.1.0`) predate
> the workspace split and carry no assets at all.

## Layout

```
mirror-base.yml         repo-wide policy every spec inherits via `extends:`
cargo-cyclonedx/
├── mirror.yml          the spec — never at the repo root
├── metadata.json       bundle interface
├── CATALOG.md          → ocx package describe
├── logo.svg / logo.png describe assets, 512px PNG
└── tests/smoke.star    Starlark smoke test
```

`LICENSE` and `NOTICE.md` are shared at the root. Logos are **not** — each
package carries its own, because a repo-root `logo.*` sits in no workflow's
`paths:` filter, so replacing it would publish nothing until some unrelated
edit happened to fire.

⚠️ `extends:` is a **shallow** merge of top-level keys. A spec that restates
`platforms:` to change one runner drops every `containers:` entry with it — and
here that would also drop the `setup:` lines that provision `cargo` into each
leg. Nothing reds; the legs simply stop proving anything. Restate a block in
full or not at all.

## Platforms

`cargo-cyclonedx` publishes **five** platform entries: both Linux arches, both
macOS arches and `windows/amd64`.

**There is no `windows/arm64`, and none is planned.** Upstream ships exactly one
Windows asset — `cargo-cyclonedx-x86_64-pc-windows-msvc.zip` — in every release;
`aarch64-pc-windows-msvc` has never existed. Declaring the key anyway would boot
a `windows-11-arm` runner that resolves no asset and reports success having
tested nothing.

**The two Linux keys deliberately differ in shape**, because upstream's asset
set is asymmetric: x86_64 gets both a `-gnu` and a `-musl` build, aarch64 gets
`-gnu` only.

| Platform key | Asset | Measured |
|---|---|---|
| `linux/amd64` (bare) | `x86_64-unknown-linux-musl.tar.xz` | `static-pie linked`, `PT_INTERP` absent, `DT_NEEDED` empty ⇒ requires nothing of the host |
| `linux/arm64+libc.glibc` | `aarch64-unknown-linux-gnu.tar.xz` | `interpreter /lib/ld-linux-aarch64.so.1`, needs `libc.so.6` + `libgcc_s.so.1`, floor `GLIBC_2.34` |

`os.features` states what an artifact requires *of the host*, so a static binary
takes a **bare** key — tagging it `+libc.musl` would be a false requirement that
hid it from every glibc host it in fact runs on. The aarch64 build genuinely is
dynamic, so `+libc.glibc` there is correct and necessary. Both were measured on
both in-range versions, and neither is UPX-packed (which would have made `file`
call even the glibc build "statically linked"). The evidence is recorded above
the `assets:` block in `cargo-cyclonedx/mirror.yml`.

The `alpine:3.20` container leg is what turns the bare key's universality claim
into evidence; the `+libc.glibc` key drops alpine, because a glibc-dynamic
binary cannot load under musl at all.

**The x86_64 `-gnu` asset is deliberately not carried.** The static musl build
already runs under both userlands, and the usual reason to ship a second
gnu-keyed platform — musl's resolver ignoring `nsswitch.conf` — cannot apply:
cargo-cyclonedx performs no name resolution at all.

## Archive layout differs between unix and windows

The unix `.tar.xz` assets wrap their payload in one directory named after the
target triple; the Windows `.zip` is **flat**, with `cargo-cyclonedx.exe` at the
archive root. `asset_type` therefore carries a per-platform override —
`strip_components: 1` by default, `0` for `windows/amd64`. Applying the default
to the flat zip would delete the executable and hoist its three markdown
siblings in its place. Both layouts converge on a binary at the content root,
which is why one `metadata.json` with a bare `${installPath}` PATH serves every
platform.

## cargo is a runtime dependency

cargo-cyclonedx is a **plugin for an existing Rust installation**, not a
standalone scanner: it shells out to `cargo metadata` for the project graph and
to `rustc -vV` for the default target. None of `ubuntu:24.04`, `alpine:3.20` or
`fedora:40` ships either, so each Linux container leg carries a
`containers[].setup` line installing the distro `cargo` package (which pulls
`rustc` with it). Without it the only container-safe verb would be `--version`
and the smoke would prove nothing about real execution.

`os.features` says libc only — a runtime dependency beyond libc has no
declarable home in the spec, so `setup:` fixes the CI leg without fixing what a
consumer must already have installed. That requirement is stated in
`CATALOG.md`.

## Editing

| File | Edit | Regenerate after |
|------|------|------------------|
| `mirror-base.yml`, `cargo-cyclonedx/mirror.yml` | hand | yes — see below |
| `cargo-cyclonedx/{metadata.json,CATALOG.md,logo.*}` | hand | — |
| `cargo-cyclonedx/tests/smoke.star` | hand | — |
| `.github/workflows/*.yml` | **generated — never hand-edit** | re-run when a spec changes |

```bash
ocx-mirror package pipeline generate ci --spec cargo-cyclonedx/mirror.yml
```

**Name every spec.** `--spec` *appends* rather than replaces, so a command
naming a subset silently stops rendering the rest while staying green — and the
drift guard reds on a generated workflow the current spec set no longer
produces.

`verify-generated.yml` exits 65 on drift. If a generated workflow is wrong, the
spec or the renderer template is wrong — fix it there and regenerate.

Run `direnv allow` once to put the pinned toolchain on `PATH`, and invoke
`ocx-mirror` directly — never `ocx run -- ocx-mirror`, which pins
`OCX_BINARY_PIN` to the bootstrap `ocx` and false-reds the nested push.

## The binaries claim

`cargo-cyclonedx/metadata.json` declares `binaries: ["cargo-cyclonedx"]` by
hand, and the spec sets `bin_scan: "off"` — forced, not preferred. Stripping the
unix wrapper directory lands the executable at the content root with no
subdirectory left for the scan to inspect, and with nothing to inspect `auto`
and `verify` both fail spec load at exit 65 rather than offer a hollow check.
The hand-written list is what the error message itself directs, and it is short
and stable: the binary is the only mode-0755 entry in every archive, while
`LICENSE`, `README.md` and `CHANGELOG.md` are 0644 data.

## Required secrets

| Secret | Use |
|--------|-----|
| `OCX_ANNOUNCE_TOKEN` | opens the index pull request from the `ocx-contrib/index` fork |
| `OCX_MIRROR_DISCORD_HOOK` | notify-stage Discord webhook URL |

(Inherited from the `ocx-contrib` org with visibility ALL. GHCR pushes use the
run's own `GITHUB_TOKEN` — no registry secret needed.)

## License

Apache-2.0 — see [`LICENSE`](LICENSE). Upstream assets are out of scope; each
package's redistribution license is recorded in [`NOTICE.md`](NOTICE.md).
