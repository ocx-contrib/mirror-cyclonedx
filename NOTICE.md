# NOTICE

This repository packages and redistributes upstream software published by the
[OWASP CycloneDX](https://cyclonedx.org/) project, from the
[cyclonedx-rust-cargo](https://github.com/CycloneDX/cyclonedx-rust-cargo)
repository. The Apache-2.0 license in [`LICENSE`](LICENSE) covers the OCX
pipeline files authored here. It does **not** cover any upstream-derived asset —
each package's redistributed bytes carry their own license, recorded below.

Each package's logo is reproduced for catalog identification only, under
nominative fair use. The marks remain the property of their respective owners
and no endorsement is implied.

| Package | GHCR path | Upstream SPDX |
|---|---|---|
| `cargo-cyclonedx` | `ghcr.io/ocx-contrib/cyclonedx/cargo-cyclonedx` | `Apache-2.0` |

---

## `cargo-cyclonedx`

Upstream: <https://github.com/CycloneDX/cyclonedx-rust-cargo>
Published to `ghcr.io/ocx-contrib/cyclonedx/cargo-cyclonedx`.

| Component | SPDX | Holder |
|---|---|---|
| cargo-cyclonedx (`cargo-cyclonedx`) | **Apache-2.0** | The OWASP CycloneDX project and the cyclonedx-rust-cargo contributors |

The license gate was cleared against the LICENSE **file**, not only the GitHub
API: the repository root `LICENSE` and `cargo-cyclonedx/LICENSE` are both the
standard Apache License 2.0 full text and are byte-identical to each other and
to the `LICENSE` shipped inside every release archive. `Cargo.toml` declares
`license.workspace = true`; the per-crate copy is the standard Rust crates.io
packaging convention, not a separate grant.

Apache License 2.0 grants redistribution of the binary form (§4) on condition
that recipients receive a copy of the license, that existing copyright, patent,
trademark and attribution notices are retained, and that modified files are
marked as changed. All three conditions are met without further action here:
the mirrored archives each ship upstream's own `LICENSE` file at their root,
republished unmodified, and nothing in any archive is altered. The published
binaries statically link third-party Rust crates under permissive licenses,
enumerated in upstream's `Cargo.lock`.

The CycloneDX cyclone mark reproduced as this package's logo is taken from the
project's own website assets and is used for catalog identification only.

No modifications are made to any upstream artifact in this repository; they are
republished byte-for-byte inside an OCX bundle.
