# cargo-cyclonedx/tests/smoke.star — stable across upstream releases, OFFLINE,
# and hermetic. Assert on the contract (exit code, version SHAPE, a COMPUTED
# document), never on help or banner prose.
#
# ⚠ THE ENV BLOCK IS LOAD-BEARING AND `HOME` IS DELIBERATELY ABSENT.
# cargo-cyclonedx shells out to BOTH `cargo metadata` and `rustc -vV` (the
# latter supplies the default `--target`). On the macOS and Windows runners
# those are RUSTUP SHIMS, which locate their toolchain through `$HOME/.rustup`.
# Redirecting HOME to scratch — the usual fleet fix for tools that persist state
# under $HOME — therefore BREAKS them. Measured on a rustup host:
#
#   $ env HOME=<scratch> cargo-cyclonedx cyclonedx --format json …
#   thread 'main' panicked at cargo-cyclonedx/src/platform.rs:30:10:
#   Failed to parse rustc output to determine the current platform.   → exit 101
#
#   $ env CARGO_HOME=<scratch>/cargo-home cargo-cyclonedx cyclonedx …  → exit 0
#
# `CARGO_HOME` is the tool-specific equivalent and is safe: rustup resolves the
# toolchain through RUSTUP_HOME, not CARGO_HOME. It is set anyway so the
# container legs never depend on `$HOME` being writable, and
# `CARGO_NET_OFFLINE=true` makes the run provably network-free — the test
# project below declares ZERO dependencies, so resolution is entirely local and
# crates.io is never reached.
ENV = {
    "CARGO_NET_OFFLINE": "true",
    "CARGO_HOME": ocx.scratch_root + "/cargo-home",
}

CDX = "cargo-cyclonedx.exe" if ocx.target_platform.os == ocx.os.Windows else "cargo-cyclonedx"

# ── Tier 1 + 2: liveness on the composed PATH + version SHAPE ───────────────
#
# ⚠ NOTE THE `cyclonedx` TOKEN. cargo-cyclonedx is a CARGO SUBCOMMAND: invoked
# as `cargo cyclonedx`, cargo execs `cargo-cyclonedx cyclonedx …`, so the plugin
# receives its own subcommand name as argv[1] and its clap parser REQUIRES it.
# There is no bare mode — `cargo-cyclonedx --version` is an error, not an
# alias (see the negative control below).
#
# Measured: stdout is exactly "cargo-cyclonedx-cyclonedx 0.5.9\n" on 0.5.9 and
# "cargo-cyclonedx-cyclonedx 0.5.8\n" on 0.5.8. The digits are the contract; the
# exact version is not, and neither is the leading token — a rebrand must not
# red this.
r_version = ocx.run(CDX, "cyclonedx", "--version")
expect.ok(r_version)
expect.matches(r_version.stdout, r"\d+\.\d+\.\d+")

# ── Negative control on the argv contract ───────────────────────────────────
# The line above would also pass against a binary that ignored its arguments
# entirely. This is what rules that out: WITHOUT the injected subcommand token
# the same flag is rejected by the argument parser. Measured identically on
# 0.5.8 and 0.5.9 — exit 2 (clap's unknown-argument code), nothing on stdout,
# the usage block on stderr. An EXACT exit code, not "non-zero": a range would
# tolerate a crash.
r_bare = ocx.run(CDX, "--version")
expect.eq(r_bare.exit_code, 2)
expect.eq(r_bare.stdout, "")

# ── Tier 3: a real SBOM generated from a hermetic Cargo project ─────────────
#
# The zero-dependency manifest is what keeps this offline: `cargo metadata` has
# nothing to resolve against the registry. Every asserted value below is one
# this file CHOSE (name, version, license) or one the tool COMPUTED from them
# (the purl), so a truncated, stubbed or wrong-flavour archive cannot satisfy
# them.
MANIFEST = (
    "[package]\n" +
    "name = \"ocxsmoke\"\n" +
    "version = \"0.4.2\"\n" +
    "edition = \"2021\"\n" +
    "license = \"MIT\"\n" +
    "\n" +
    "[dependencies]\n"
)

ocx.mkdir("proj/src")
ocx.write_file("proj/Cargo.toml", MANIFEST)
ocx.write_file("proj/src/main.rs", "fn main() { println!(\"ocx\"); }\n")

# `--override-filename ocxbom` pins the output path (default is
# `<crate>.cdx.json`); `--spec-version 1.5` is asserted below, which makes the
# check a statement about a flag this test PASSES rather than about a default
# that upstream is free to move. Output goes to a FILE, never stdout — so no
# assertion here can be broken by colorization or an unsolicited banner.
r_gen = ocx.run(
    CDX, "cyclonedx",
    "--format", "json",
    "--all",
    "--spec-version", "1.5",
    "--override-filename", "ocxbom",
    cwd="proj",
    env=ENV,
)
expect.ok(r_gen)

# Counts, not bare substring presence: a count pins the document's shape and is
# parser-free. Measured identical on 0.5.8 and 0.5.9 — the purl and the crate
# name each appear TWICE (once for the crate component, once for the `bin`
# Cargo target carried as its subcomponent).
bom = ocx.read_file("proj/ocxbom.json")
expect.eq(bom.count("\"bomFormat\": \"CycloneDX\""), 1)
expect.eq(bom.count("\"specVersion\": \"1.5\""), 1)
expect.eq(bom.count("\"expression\": \"MIT\""), 1)
# The purl is SYNTHESISED — `pkg:cargo/<name>@<version>` is assembled from two
# separate manifest fields into purl syntax. A tool that merely copied its input
# through could not produce it, which is what makes this more than an echo test.
expect.eq(bom.count("pkg:cargo/ocxsmoke@0.4.2"), 2)

# ── Negative control on the generator ───────────────────────────────────────
# Handed a manifest that is not valid TOML, the real binary exits 1 and writes
# NOTHING to stdout (the parse error goes to stderr). Measured identically on
# 0.5.8 and 0.5.9. Without this, "it wrote a file" could be satisfied by a tool
# that never read the manifest at all.
ocx.mkdir("bad")
ocx.write_file("bad/Cargo.toml", "this is not a cargo manifest\n[[[\n")

r_bad = ocx.run(CDX, "cyclonedx", "--format", "json", cwd="bad", env=ENV)
expect.eq(r_bad.exit_code, 1)
expect.eq(r_bad.stdout, "")

# No Tier 4: metadata.json declares PATH only, and Tier 1 already proved it.
