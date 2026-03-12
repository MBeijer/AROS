# CMake Build Entry Point

This repository now exposes a CMake-based top-level workflow.

## Scope

- Domain-level CMake orchestration entry points in `tools/`, `arch/`, `rom/`, and `workbench/` (root delegates to these)
- Native CMake superbuild for `tools/crosstools` (GNU toolchain bootstrap via `ExternalProject`)
- Native CMake build of `tools/MetaMake/mmake` (optional)
- Native CMake build of `tools/zopfli` (library + CLI)
- Native CMake build of `arch/all-pc/udis86` (library + `udcli`, with out-of-tree code generation)
- Native CMake build of selected `tools/` leaf utilities (`genmf`, `setrev`, `elf2hunk`, `ilbmtoc`, `archtool`)
- Native CMake build of `tools/ilbmtoicon` (when `PNG` and `ZLIB` are available)
- Native CMake build of `tools/dtdesc` (`c_iff` static library + descriptor tools)
- Native CMake build of `tools/genctbl` (`genctbl`, plus optional `aros-localize-ctbls` helper target)
- Native CMake build of `tools/mkamikeymap` (`mkamikeymap`)
- Native CMake build of `tools/fd2pragma` (`fd2pragma`, host CLI mode)
- Native CMake build of `tools/ADFlib` (`adflib`, optional `unadf`)
- Native CMake build of `tools/flexcat` (`flexcat`, host/unix path)
- Native CMake ExternalProject wrapper of `tools/lha` (`lha`)
- Legacy wrapper targets for existing AROS make graph (`all`, `tools`, `sdk`, `contrib`, and others), with wrapper ownership split by domain (`rom/`, `workbench/`).
- Layering report target for MetaMake arch resolution (`aros-layering-report`)
- Coexistence compare target for native-vs-legacy host tools (`aros-coexist-compare`)
- Per-module layering report targets for non-tool migration planning (`aros-rom-debug-layering-report`, `aros-rom-utility-layering-report`)
- First domain-level module migration entrypoints:
  - `rom/utility` (`aros-rom-utility-layered-sources`, `aros-rom-utility`)
  - `workbench/libs` (`aros-workbench-libs-complete`)
- Full output parity target against a legacy reference build (`aros-output-parity-compare`)

This is an incremental migration: CMake drives the existing project build graph while deeper per-module conversion continues.

## Configure (Native Crosstools Only)

```bash
cmake -S . -B build-cmake \
  -DAROS_ENABLE_LEGACY_PIPELINE=OFF \
  -DAROS_BUILD_METAMAKE=ON \
  -DAROS_BUILD_ZOPFLI=ON \
  -DAROS_BUILD_UDIS86=ON \
  -DAROS_BUILD_GENMF=ON \
  -DAROS_BUILD_SETREV=ON \
  -DAROS_BUILD_ELF2HUNK=ON \
  -DAROS_BUILD_ILBMTOC=ON \
  -DAROS_BUILD_ARCHTOOL=ON \
  -DAROS_BUILD_ILBMTOICON=ON \
  -DAROS_BUILD_DTDESC=ON \
  -DAROS_BUILD_GENCTBL=ON \
  -DAROS_BUILD_MKAMIKEYMAP=ON \
  -DAROS_BUILD_FD2PRAGMA=ON \
  -DAROS_BUILD_ADFLIB=ON \
  -DAROS_BUILD_FLEXCAT=ON \
  -DAROS_BUILD_LHA=ON \
  -DAROS_TARGET=linux-x86_64 \
  -DAROS_CROSSTOOLS_NATIVE=ON \
  -DAROS_CROSSTOOLS_TARGET_CPU=x86_64 \
  -DAROS_CROSSTOOLS_INSTALL_DIR="$PWD/toolchain-core-x86_64" \
  -DAROS_CROSSTOOLS_SYSROOT="$PWD/sysroot" \
  -DAROS_MAKE_JOBS=8
```

Notes:
- `AROS_CROSSTOOLS_FAMILY` currently supports `gnu` in native mode.
- `AROS_GCC_VERSION`, `AROS_BINUTILS_VERSION`, `AROS_GMP_VERSION`, `AROS_ISL_VERSION`, `AROS_MPFR_VERSION`, `AROS_MPC_VERSION` are configurable cache variables.
- `AROS_CROSSTOOLS_HOST_CFLAGS` and `AROS_CROSSTOOLS_HOST_CXXFLAGS` control host compiler flags passed to GNU dependency `configure` steps (defaults: `-std=gnu17`, `-std=gnu++17`) to avoid C23 probe breakage with newer host compilers.
- `AROS_CROSSTOOLS_WORK_ROOT` controls where crosstools `ExternalProject` sources/build trees live; point it to fast local storage when building from slow/NFS workspaces.
- `AROS_CROSSTOOLS_INSTALL_DIR` now defaults to `build-cmake/bin/<target>/tools/crosstools` to match legacy AROS graph expectations.
- If `AROS_TOOLCHAIN_INSTALL_DIR` is empty and native crosstools is enabled, root `configure` automatically uses `AROS_CROSSTOOLS_INSTALL_DIR` so primary and legacy-reference builds use the same toolchain path.
- Native crosstools still uses GNU Make internally for third-party projects, but no longer uses AROS `configure`/MetaMake targets for crosstools.
- `AROS_MAKE_JOBS` defaults to `MAKE_JOBS` from the environment when present.
- `AROS_BUILD_METAMAKE`, `AROS_BUILD_ZOPFLI`, `AROS_BUILD_UDIS86`, `AROS_BUILD_GENMF`, `AROS_BUILD_SETREV`, `AROS_BUILD_ELF2HUNK`, `AROS_BUILD_ILBMTOC`, `AROS_BUILD_ARCHTOOL`, `AROS_BUILD_ILBMTOICON`, `AROS_BUILD_DTDESC`, `AROS_BUILD_GENCTBL`, `AROS_BUILD_MKAMIKEYMAP`, `AROS_BUILD_FD2PRAGMA`, `AROS_BUILD_ADFLIB`, `AROS_BUILD_FLEXCAT`, and `AROS_BUILD_LHA` toggle native CMake subprojects.
- `AROS_LHA_GIT_REPOSITORY`, `AROS_LHA_GIT_TAG`, and `AROS_LHA_INSTALL_DIR` control the `tools/lha` ExternalProject source and install location.
- `AROS_LEGACY_USE_NATIVE_MMAKE` injects the CMake-built `mmake` binary into legacy `make` wrapper invocations (`MMAKE=...`) to reduce dependence on legacy MetaMake autotools bootstrapping.
- `AROS_LEGACY_SKIP_CROSSTOOLS_MMAKE` (with `AROS_CROSSTOOLS_NATIVE=ON`) injects `CROSSTOOLS_TARGET=` into legacy wrapper invocations to avoid re-running crosstools through MetaMake during AROS graph builds.
- `AROS_ENABLE_COEXIST_COMPARE` enables `aros-tools-native` and `aros-coexist-compare` targets.
- `AROS_COEXIST_STRICT_COMPARE` controls whether `aros-coexist-compare` fails on mismatches (`OFF` by default to allow incremental diff triage).
- `aros-coexist-compare` first compares normalized binaries (debug/build-id stripped). If bytes still differ, it falls back to a no-argument behavior check (normalized output + exit code) before marking a mismatch.
- `AROS_ENABLE_OUTPUT_PARITY_CHECK` enables `aros-output-parity-compare`.
- `aros-legacy-reference-build` builds a legacy reference output tree from CMake in `AROS_PARITY_LEGACY_BUILD_DIR` (default: `build-cmake/legacy-reference`).
- `AROS_PARITY_LEGACY_MAKE_TARGET` controls which legacy target is built for reference generation (default: `AROS`).
- `AROS_PARITY_REFERENCE_DIR` must point to the legacy reference output tree (for example `<legacy-build>/bin/<target>/AROS`).
- `AROS_PARITY_CMAKE_OUTPUT_DIR` defaults to `build-cmake/bin/<target>/AROS`.
- `AROS_OUTPUT_PARITY_STRICT` controls fail/pass behavior for parity differences (defaults to `ON`).
- `ilbmtoicon` requires both `PNG` and `ZLIB`; the target is skipped with a warning when unavailable.
- `genctbl` exposes optional target `aros-localize-ctbls`, which expects `UnicodeData.txt` at `${AROS_UCD_DIR}/UnicodeData.txt` (default: `build-cmake/ucd/UnicodeData.txt`).
- `mkamikeymap` uses a local compatibility header shim under `tools/mkamikeymap/compat/` to support host-side CMake builds without generated AROS SDK headers.

## Build (Native Crosstools)

```bash
cmake --build build-cmake --target aros-crosstools-toolchain
```

Optional aggregate target:

```bash
cmake --build build-cmake --target aros-crosstools
```

## Configure (Legacy Wrapper Mode)

```bash
cmake -S . -B build-cmake \
  -DAROS_ENABLE_LEGACY_PIPELINE=ON \
  -DAROS_TARGET=linux-x86_64 \
  -DAROS_TOOLCHAIN_INSTALL_DIR="$PWD/toolchain-core-x86_64" \
  -DAROS_PORTS_SOURCES_DIR="$PWD/portssources" \
  -DAROS_CONFIGURE_ARGS="--with-aros-toolchain=yes --enable-debug" \
  -DAROS_MAKE_JOBS=8
```

Legacy notes:
- `AROS_CONFIGURE_ARGS` defaults to `EXTRA_CONFIGURE_OPTS` from the environment when present.
- Legacy AROS sub-build targets are always executed with GNU Make (`gmake`/`make`), independent of the CMake generator.

## Build

Default build (legacy mode):

```bash
cmake --build build-cmake
```

Build specific targets:

```bash
cmake --build build-cmake --target metamake
cmake --build build-cmake --target libzopfli
cmake --build build-cmake --target zopfli
cmake --build build-cmake --target libudis86
cmake --build build-cmake --target udcli
cmake --build build-cmake --target genmf
cmake --build build-cmake --target setrev
cmake --build build-cmake --target elf2hunk
cmake --build build-cmake --target ilbmtoc
cmake --build build-cmake --target archtool
cmake --build build-cmake --target ilbmtoicon
cmake --build build-cmake --target infoinfo
cmake --build build-cmake --target c_iff
cmake --build build-cmake --target createdtdesc
cmake --build build-cmake --target examinedtdesc
cmake --build build-cmake --target genctbl
cmake --build build-cmake --target mkamikeymap
cmake --build build-cmake --target fd2pragma
cmake --build build-cmake --target adflib
cmake --build build-cmake --target unadf
cmake --build build-cmake --target flexcat
cmake --build build-cmake --target lha
cmake --build build-cmake --target aros-localize-ctbls
cmake --build build-cmake --target aros-crosstools-toolchain
cmake --build build-cmake --target aros-tools
cmake --build build-cmake --target aros-aros
cmake --build build-cmake --target aros-complete
cmake --build build-cmake --target aros-rom
cmake --build build-cmake --target aros-rom-kernel-package-base
cmake --build build-cmake --target aros-rom-utility
cmake --build build-cmake --target aros-rom-utility-layered-sources
cmake --build build-cmake --target aros-workbench
cmake --build build-cmake --target aros-workbench-complete
cmake --build build-cmake --target aros-workbench-libs-complete
cmake --build build-cmake --target aros-crosstools
cmake --build build-cmake --target aros-sdk
cmake --build build-cmake --target aros-contrib
cmake --build build-cmake --target aros-query
cmake --build build-cmake --target aros-layering-report
cmake --build build-cmake --target aros-rom-debug-layering-report
cmake --build build-cmake --target aros-rom-utility-layering-report
cmake --build build-cmake --target aros-tools-native
cmake --build build-cmake --target aros-coexist-compare
cmake --build build-cmake --target aros-legacy-reference-build
cmake --build build-cmake --target aros-output-parity-compare
```

Clean:

```bash
cmake --build build-cmake --target aros-clean
```

## Recommended Order (Legacy Mode)

Start by building the toolchain:

```bash
cmake --build build-cmake --target aros-crosstools-toolchain
```

Then continue with the rest of the build graph (for example `aros-all` or `aros-sdk`).

For architecture-dependent modules (for example under `rom/`), inspect the active layer chain first:

```bash
cmake --build build-cmake --target aros-layering-report
```

The report reads configured target metadata and prints the MetaMake alias chain (`arch-cpu-variant`, `arch-cpu`, `arch-variant`, `arch`, `family`, `cpu`) together with matching `arch/` directories.
