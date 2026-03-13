# AROS CMake Migration Notes

## Goal
Replace the legacy `metamake` + `make` + `autoconf/configure` build flow with a full CMake build, while keeping the tree buildable during migration.
Hard requirement: CMake-native outputs must match legacy outputs 1:1 (byte-identical where feasible) for tools and full system artifacts (`rom/`, `kernel/`, packaged output tree).
Constraint: avoid changing legacy build scripts/sources unless absolutely required for correctness; keep migration behavior in CMake glue.

## Current Status (2026-03-10)
- Root `CMakeLists.txt` is the primary CMake entry point for incremental migration.
- Root now delegates subsystem orchestration to domain `CMakeLists.txt` files (`arch/`, `tools/`, `rom/`, `workbench/`) instead of owning large per-subdirectory blocks.
- Native CMake subprojects currently integrated:
  - `tools/MetaMake` (`metamake` target producing `mmake`)
  - `tools/crosstools` (GNU toolchain bootstrap via `ExternalProject`)
  - `tools/zopfli` (`libzopfli`, `zopfli`)
  - `arch/all-pc/udis86` (`libudis86`, `udcli`)
  - `tools/genmf` (`genmf`)
  - `tools/setrev` (`setrev`)
  - `tools/elf2hunk` (`elf2hunk`)
  - `tools/ilbmtoc` (`ilbmtoc`)
  - `tools/archtools` (`archtool`)
  - `tools/ilbmtoicon` (`ilbmtoicon`, `infoinfo`) when `PNG`/`ZLIB` are present
  - `tools/dtdesc` (`c_iff`, `createdtdesc`, `examinedtdesc`)
  - `tools/genctbl` (`genctbl`, optional `aros-localize-ctbls` generation target)
  - `tools/mkamikeymap` (`mkamikeymap`)
  - `tools/fd2pragma` (`fd2pragma`)
  - `tools/ADFlib` (`adflib`, optional `unadf`)
  - `tools/flexcat` (`flexcat`, host/unix path)
  - `tools/lha` (`lha`, ExternalProject wrapper)
- Legacy AROS build graph is still available through CMake wrapper targets (`aros-all`, `aros-tools`, `aros-sdk`, etc.) when `AROS_ENABLE_LEGACY_PIPELINE=ON`.
- Domain ownership for wrappers is now explicit:
  - root owns global graph wrappers (`aros-all`, `aros-aros`, `aros-complete`, etc.)
  - `rom/CMakeLists.txt` owns ROM wrappers (`aros-rom`, `aros-rom-kernel-package-base`)
  - `workbench/CMakeLists.txt` owns Workbench wrappers (`aros-workbench`, `aros-workbench-complete`)
- Additional wrapper targets now exposed for actual graph entry points: `aros-aros` (`make AROS`), `aros-complete` (`make AROS-complete`), and `aros-layering-report` (MetaMake layer-chain introspection).
- `aros-rom` (`make rom`) is now exposed as a dedicated wrapper target for ROM-focused build passes.
- First non-tool module entrypoints now exist:
  - `rom/utility/CMakeLists.txt` with `aros-rom-utility-layered-sources` and `aros-rom-utility` (`make kernel-utility`)
  - `workbench/libs/CMakeLists.txt` with `aros-workbench-libs-complete` (`make workbench-libs-complete`)
- Coexistence targets:
  - `aros-tools-native`: aggregate target for CMake-native host tool outputs.
  - `aros-coexist-compare`: builds native + legacy tool outputs and compares matching artifacts.
- Full output parity target:
  - `aros-output-parity-compare`: compares complete CMake-driven output tree (`bin/<target>/AROS`) against a legacy reference output tree.
  - `aros-legacy-reference-build`: creates/updates that legacy reference tree from inside the CMake workflow.
  - Legacy-reference parity build now runs with:
    - `MMAKE_CONFIG=<parity-build>/mmake.config`
    - no forced `MMAKE=<cmake-native-mmake>` override (parity uses legacy-selected mmake path)
    - parity-only `AS=<toolchain>/<triplet>-gcc` environment override to stabilize AHI `configure` assembler flag probing (`-Wa,--defsym,...` expectation).
    - `-j1` by default (`AROS_PARITY_LEGACY_SERIAL_MAKE=ON`) to reduce racey fetch/build behavior in parity reference generation.
  - Current direction: allow legacy parity to run its own crosstools staging steps (do not suppress `CROSSTOOLS_TARGET`) so include/lib staging matches the historical layer order.
- Non-tool layering analysis targets:
  - `aros-rom-debug-layering-report`: per-file layer override/addition report for `rom/debug`.
  - `aros-rom-utility-layering-report`: per-file layer override/addition report for `rom/utility`.

## Session Notes (2026-03-11)
### User-reported timeline (summary)
- Initial parity failures repeatedly stopped in `compiler/startup` with missing target C++ headers under crosstools:
  - missing `.../include/c++/stdlib.h`
  - then missing `cstdlib`
  - then missing `x86_64-aros/bits/{c++config.h,os_defines.h,cpu_defines.h}`
  - then missing `bits/std_abs.h`
- Build later progressed but failed in `workbench/devs/AHI`:
  - `x86_64-aros-gcc: error: CPU=x86_64: No such file or directory`
  - `... LITTLE_ENDIAN=1 ...`
  - `... x86_64=1 ...`
  - `unrecognized command-line option '--defsym'`
  - one pass also showed `-E or -x required when input is from standard input`
- Next parity failures moved to C/C++ unit tests:
  - link failure: `x86_64-aros-ld: cannot find -lstdc++`
  - compile failure: `cunit-cplusplus-static.cpp` had `NULL` undeclared (missing `<cstddef>`)
  - compile failure in `headertest.cpp` via `aros/stdc/wchar.h`: `wint_t` not declared
  - compile failure in CRT tests: `fpos64_t` undeclared
  - compile failure in `cunit-crt-realpath.c`: `PATH_MAX` undeclared and `realpath` implicit
- User guidance: fixes were getting too cludgy; key point is legacy build has layered dependencies and legacy crosstools performs extra include/sysroot staging before full AROS build.

### Current state after user guidance
- Decision: prefer layer-correct legacy behavior over parity-only header/runtime shims.
- Root CMake parity wiring has been shifted toward that:
  - do not inject `CROSSTOOLS_TARGET=` in parity make invocation
  - do not run parity pre-touch crosstools-flag sync in the parity command chain
  - parity libstdc++ compatibility shim hook removed from active parity graph
  - `AROS_LEGACY_SKIP_CROSSTOOLS_MMAKE` default is now `OFF`
- `developer/debug/test/cplusplus/cunit-cplusplus-static.cpp` currently includes `<cstddef>` for `NULL`.
- Outstanding verification task: rerun `aros-output-parity-compare` from clean parity state and confirm that legacy crosstools staging now resolves the earlier header/runtime drift without shim-side overrides.

## Session Notes (2026-03-12)
### User guidance and confirmed build-shape findings
- Keep updating this file when new migration-relevant information or constraints are discovered during the session.
- When regenerating `cmake-build-debug`, always use the Ninja generator (`cmake -G Ninja ...`).
- Keep compile and tool output visible in the normal build stream. Log files are allowed as mirrors for debugging, but they must not replace live stdout/stderr.
- `rom/mmakefile.src` expresses ROM build order; use it as the reference ordering when introducing native CMake ROM targets.
- ROM modules can depend on each other. `exec` is part of ROM and should be treated as an early/native producer of headers and related developer include surfaces needed by downstream ROM modules.
- Module include dependencies are explicitly expressed in module `mmakefile.src` files through `#MM <module>-includes : ...` lines. Example from `rom/utility/mmakefile.src`:
  - `kernel-utility-includes` depends on `kernel-exec-includes`
- CMake should model those include relationships with reusable `INTERFACE` targets so downstream modules inherit the proper header surface through target dependencies instead of ad-hoc include path wiring.
- Pretty much everything under ROM uses `genmodule`; treat `genmodule` as the central native migration primitive rather than building module-specific custom paths.
- Native crosstools should be made to build under CMake so ROM-native targets can progress, but this must stay on the CMake side only; do not edit legacy build logic to get there.
- Treat `AROS_CROSSTOOLS_INSTALL_DIR` as an arbitrary install prefix, not a build-directory-shaped path. `collect-aros`, reuse detection, and CMake-side crosstools sync logic must keep working when the toolchain is installed outside `cmake-build-debug`, for example under `/opt/x86_64-aros`.
- Legacy-compatible crosstools layout means target-prefixed tools are available at the install-prefix top level. Do not make CMake-side crosstools logic depend on `<prefix>/bin` existing.
- When `AROS_CROSSTOOLS_NATIVE=OFF`, the CMake wrapper-backed crosstools build can produce the usable target compiler under `legacy-main/bin/<target>/tools/crosstools` even if `AROS_CROSSTOOLS_INSTALL_DIR` points at `cmake-build-debug/bin/...`. Native include/link/module stages must resolve and use the actual reusable toolchain prefix, not the nominal unset/root prefix.
- The native genmodule module link path must pull in the real compiler-side default linklib surface, not just whatever `uselibs=` is present in a module `mmakefile.src`. The current baseline includes at least `amiga`, `arossupport`, `stdc.static`, `libinit`, and `autoinit`, with `autoinit` often being required indirectly by generated `*_autoinit.c` linklib stubs.

### Native ROM migration findings
- Generic `genmodule` CMake support now needs to read active-layer `arch/<layer>/<module>/mmakefile.src` files, not just source-directory overrides, because those manifests define archspecific source additions/overrides, flags, and linklib pieces.
- Layered include precedence matters just as much as layered source precedence. Active layer include directories must come before the base module directory so headers like `exec_platform.h` resolve to the active layer version.
- Native include staging must also honor `arch/*-all/include/mmakefile.src` `copy_includes` rules, because some active headers depend on support headers from sibling CPU namespaces.
- Configure-time module `INTERFACE` targets must publish more than just the staged global include root.
  - They should expose active layer directories, module/user include dirs from `USER_INCLUDES`, active-layer `make.opts` include additions, and `%get_archincludes` results where applicable.
  - `CURDIR` / `MAINDIR` token expansion matters for that configure-time include surface just as it does in the build-time mmake parser.
- A clean-clone CMake configure cannot assume `legacy-main/bin/<target>/gen/config/target.cfg` already exists.
  - Native module registration parses legacy mmake/config metadata during CMake configure, so the root CMake configure path must bootstrap the legacy `configure` step early enough to create the first-pass config files in `legacy-main`.
  - The correct first-pass outputs from legacy `configure` are the core config files such as `target.cfg`, `build.cfg`, `conf.cmake`, `make.defaults`, `config/make.cfg`, and `mmake.config`.
  - `compiler.cfg` is not a guaranteed first-pass `configure` output, so bootstrap validation must not require it.
  - `_aros_get_target_context()` should also tolerate a missing `target.cfg` and fall back to the `AROS_TARGET` arch/family split instead of hard-failing the whole CMake configure.
- Current concrete blocker for `aros-rom-exec-native` is generated-header fidelity, not legacy build behavior:
  - `compiler/include/mmakefile.src` rewrites `exec/execbase.h` with `sed` for the SMP/private-field layout.
  - current native include staging still copies `compiler/include/exec/execbase.inc` too literally.
  - CMake-native include staging must reproduce that generated-header transform so `arch/all-unix/exec/exec_platform.h` sees the expected `Private1`..`Private5` layout.
- Native crosstools now build successfully from CMake far enough to provide the target compiler frontend (`x86_64-aros-gcc`) and companion binutils needed by native ROM modules. The optional target `libstdc++-v3` stage still fails and is not currently required for the ROM-native path that is being advanced.
- The shared native `genmodule` module linker must model module semantics, not program semantics:
  - module link must preserve start/source/end object ordering from MetaMake
  - module link must not inherit the target GCC default autolib/autoinit chain from `compiler/autoinit/auto`
  - explicit module/linklib inputs must be linked through the CMake-side module graph instead
- Active-layer `%get_archincludes` / `%set_archincludes` are part of the real MetaMake contract for hosted/native ROM modules. CMake-native mmake parsing must resolve those macros generically so modules can inherit archspecific include surfaces like `TARGET_KERNEL_INCLUDES` / `TARGET_EXEC_INCLUDES`.
- The mmake parser also needs generic fallback expansion from generated `target.cfg` values. Without that, tokens like `$(KERNEL_INCLUDES)` collapse away and hosted ROM modules pick the wrong headers.
- Hosted/native layer compile precedence must match MetaMake:
  - module/user/layer include options have to appear before the staged AROS include root
  - otherwise hosted modules like `arch/all-unix/timer/timer_init.c` include AROS `sys/time.h` instead of the host OS header they were written against
- Native ROM interface generation needs to follow the producer list from `rom/mmakefile.src` `includes-generate`, filtered to actual flat `rom/<module>` `%build_module` producers. Only registering a hand-picked subset leaves real SDK producers like `bootloader` unstaged and breaks downstream modules such as `timer.device`.
- Existing build directories may still carry a narrower cached `AROS_ROM_NATIVE_INTERFACE_MODULES` value from earlier migration steps. In the current `cmake-build-debug` this was manually expanded to include the additional interface producers needed by the active ROM modules.
- Verified native ROM module status in the active build directory:
  - `exec.library` builds
  - `utility.library` builds
  - `debug.library` builds
  - `processor.resource` builds
  - `timer.device` builds
- Arch-specific native linklibs need their own reusable bucket outside compiler/core linklibs. Current CMake shape now has an `aros-arch-linklibs-native` aggregate, and ROM-native module builds depend on it when present.
- `udis86` is now staged on the CMake side as a target-format native linklib by reusing the existing `%build_linklib` description in `arch/all-pc/udis86/mmakefile.src` plus a CMake-side codegen step for the generated `itab` sources. This is the current pattern reference for similar arch-side non-core linklibs.
- The generic source resolver in the native module/linklib builders must accept absolute generated basenames without an extension (for example generated `.../itab` resolving to `.../itab.c`).
- Non-fatal toolchain-path warning still present during some module links:
  - `objdump` / `nm` are looked up under the crosstools root without `/bin`
  - builds currently complete despite that warning, but the path resolution should be normalized on the CMake side later

## Migration Strategy
1. Keep root CMake as the stable entry point.
2. Convert one subsystem at a time to native CMake targets.
3. Preserve wrapper targets until native replacements exist.
4. Remove legacy wrapper mode only after all critical paths are native.

## Key CMake Options
- `AROS_ENABLE_LEGACY_PIPELINE`: ON uses `./configure` + GNU make wrapper targets.
- `AROS_BUILD_METAMAKE`: build native CMake `mmake`.
- `AROS_BUILD_ZOPFLI`: build native CMake zopfli targets.
- `AROS_BUILD_UDIS86`: build native CMake udis86 targets.
- `AROS_BUILD_GENMF`: build native CMake `genmf`.
- `AROS_BUILD_SETREV`: build native CMake `setrev`.
- `AROS_BUILD_ELF2HUNK`: build native CMake `elf2hunk`.
- `AROS_BUILD_ILBMTOC`: build native CMake `ilbmtoc`.
- `AROS_BUILD_ARCHTOOL`: build native CMake `archtool`.
- `AROS_BUILD_ILBMTOICON`: build native CMake `ilbmtoicon` and `infoinfo` (requires PNG/ZLIB).
- `AROS_BUILD_DTDESC`: build native CMake `c_iff`, `createdtdesc`, and `examinedtdesc`.
- `AROS_BUILD_GENCTBL`: build native CMake `genctbl`.
- `AROS_BUILD_MKAMIKEYMAP`: build native CMake `mkamikeymap`.
- `AROS_BUILD_FD2PRAGMA`: build native CMake `fd2pragma`.
- `AROS_BUILD_ADFLIB`: build native CMake `adflib` (and optionally `unadf`).
- `AROS_BUILD_FLEXCAT`: build native CMake `flexcat`.
- `AROS_BUILD_LHA`: build native CMake ExternalProject wrapper for `lha`.
- `AROS_LHA_GIT_REPOSITORY` / `AROS_LHA_GIT_TAG` / `AROS_LHA_INSTALL_DIR`: configure `tools/lha` external source and install path.
- `AROS_LEGACY_USE_NATIVE_MMAKE`: when ON, legacy make-wrapper targets are executed with `MMAKE=<CMake-built mmake>` to bypass fragile legacy MetaMake bootstrap paths.
- `AROS_LEGACY_SKIP_CROSSTOOLS_MMAKE`: when ON (and legacy wrapper dependencies on crosstools are enabled), wrapper invocations use `CROSSTOOLS_TARGET=` to suppress legacy crosstools rebuild paths. Current default is `OFF` to preserve legacy staging order.
- `AROS_LEGACY_REUSE_EXISTING_CROSSTOOLS`: when ON, legacy/parity wrappers skip the crosstools dependency edge if an existing target compiler already exists in the configured toolchain install dir.
- `AROS_ENABLE_COEXIST_COMPARE`: enables coexistence compare targets.
- `AROS_COEXIST_STRICT_COMPARE`: makes `aros-coexist-compare` fail on any artifact mismatch when ON.
- Coexist compare policy: normalized-binary compare first, then fallback behavior compare (no-arg output + exit code). This reduces false mismatches from debug/build-id/path differences while still flagging real behavioral drift.
- `AROS_ENABLE_OUTPUT_PARITY_CHECK`: enables full output-tree parity target.
- `AROS_PARITY_LEGACY_BUILD_DIR`: build directory used for in-CMake legacy reference generation.
  - Default is now `/tmp/aros-legacy-reference-<target>` to avoid source-tree recursion side effects from in-tree legacy-reference builds.
- `AROS_PARITY_LEGACY_MAKE_TARGET`: legacy make target used for reference generation (`AROS` by default).
- `AROS_PARITY_LEGACY_SERIAL_MAKE`: when ON, force legacy-reference parity make step to run with `-j1` for deterministic/stable parity generation.
- `AROS_PARITY_LEGACY_TOOLCHAIN_INSTALL_DIR`: optional toolchain path used only by legacy-reference parity configure; empty falls back to effective shared toolchain path.
- `AROS_PARITY_REFERENCE_DIR`: legacy reference `bin/<target>/AROS` path used for parity checks.
- `AROS_PARITY_CMAKE_OUTPUT_DIR`: CMake output tree path (defaults to `build/bin/<target>/AROS`).
- `AROS_OUTPUT_PARITY_STRICT`: fail parity target on any file diff (defaults ON).
- `AROS_CROSSTOOLS_INSTALL_DIR`: default aligned to `build/bin/<target>/tools/crosstools` so legacy AROS graph targets and generated target compiler paths are consistent.
- Root `configure` and `legacy-reference` `configure` now both use one effective toolchain install path (prefers `AROS_TOOLCHAIN_INSTALL_DIR`, falls back to `AROS_CROSSTOOLS_INSTALL_DIR` when native crosstools is on) to avoid parity drift from path mismatches.
- `AROS_CROSSTOOLS_NATIVE`: ON uses CMake/ExternalProject toolchain path.
- `AROS_CROSSTOOLS_BUILD_TARGET_LIBSTDCXX`: when ON, native crosstools also builds/installs target `libstdc++-v3` (headers+runtime) so legacy AROS targets requiring `.../include/c++/stdlib.h` can build.
- `AROS_CROSSTOOLS_HOST_CFLAGS` / `AROS_CROSSTOOLS_HOST_CXXFLAGS`: host flags for GNU dependency configure probes; defaults force pre-C23 mode for compatibility with newer GCC.
- `AROS_CROSSTOOLS_WORK_ROOT`: workspace for crosstools source/build trees; set to fast local storage (for example `/tmp/...`) when the project tree is on slow storage/NFS.

## Layering Rule (Important for `rom/`, `arch/`, `kernel/` work)
- MetaMake resolves architecture-specific builds through an alias chain. For target-specific module work, treat the active layer order as:
  - `arch-cpu-variant` -> `arch-cpu` -> `arch-variant` -> `arch` -> `family` -> `cpu`
- Before converting any non-tool subsystem (for example modules under `rom/`), run `cmake --build <build-dir> --target aros-layering-report` and use its output to determine which `arch/<layer>/...` directories override base sources.

## Immediate Next Steps
- Update this file whenever the user provides migration-relevant constraints or when a new structural/native-build finding changes the direction of the work.
- Keep advancing ROM-native modules in ROM build order and use the newly working `exec` / `utility` / `processor` / `timer` outputs as the baseline for the next parity steps.
- Use the now-working `debug` / `udis86` arch-linklib path as the template for other arch-side native linklibs that are outside compiler/core linklibs.
- Remove the need for manual `AROS_ROM_NATIVE_INTERFACE_MODULES` cache expansion by making the ROM interface-producer discovery/cached-default migration robust for existing build directories.
- Continue building native crosstools from CMake only as needed to unblock ROM-native targets; do not change legacy crosstools or legacy build logic.
- Use `rom/mmakefile.src` build ordering, `#MM ...-includes`, and `%get_archincludes`-resolved include producers to drive reusable CMake `INTERFACE` graphs for ROM modules, with `exec` treated as an early include producer.
- Rerun full parity from the active out-of-tree build dir:
  - `cmake --build <build-dir> --target aros-output-parity-compare`
- Validate parity now runs with layer-correct crosstools behavior:
  - confirm parity `gmake` line keeps `MMAKE_CONFIG=<parity-build>/mmake.config`
  - confirm parity line does not force `CROSSTOOLS_TARGET=`
  - inspect crosstools staging results under `<toolchain>/<triplet>/{include,sys-include}` before debugging downstream compile errors
- Once parity reaches compare stage, fix output diffs module-by-module (starting with `rom/` and `workbench/`) while preserving layer resolution semantics.
- Convert additional libraries/tools under `tools/` that still rely on `mmakefile.src` (notably `icu4c`, `sdk`).
- Extend `tools/flexcat` CMake path with optional catalog-generation helper targets equivalent to legacy `tools-flexcat-locale`.
- Improve `tools/lha` CMake wrapper by pinning tested upstream revision and adding optional offline tarball/source override.
- Start CMake-native migration for non-tool subsystem modules with layering-aware source selection (beginning with a small `rom/` module that has clear `arch/<layer>/` overrides).
- Consider replacing `tools/mkamikeymap/compat/*` with proper generated/public AROS headers once the CMake include generation pipeline is in place.
- Replace legacy `aros-*` make wrapper targets with native CMake targets per subsystem.
- Introduce CMake install/export rules for cross-toolchain and host tools where missing.
- Add CI jobs that run CMake-only configure/build for selected targets.

## Working Rule
Do not delete legacy paths until a verified CMake-native target exists for the same build artifact.
Wrap temporary compatibility blocks in CMake with explicit `START LEGACY` / `END LEGACY` comments so removal points are obvious later.

## New Migration Findings (2026-03-12)
- `%build_linklib` arguments in `mmakefile.src` are not consistently quoted. The generic CMake parser must accept both `files="$(FILES)"` and `files=$(FILES)` forms and continue consuming bare list tokens until the next `key=value` argument.
- Existing `cmake-build-debug` caches may still pin `AROS_COMPILER_NATIVE_LINKLIBS=amiga;arossupport;stdc-static`. CMake cache migration must upgrade that older value to include native `autoinit` and `libinit`, otherwise ROM modules silently mix native and legacy compiler linklibs.
- The installed legacy target SDK does not flatten the whole `aros/stdc` / `aros/posixc` surface into the include root.
  - Real target-compiler resolution check: `<ctype.h>` resolves to `include/aros/stdc/ctype.h`.
  - The installed `include/aros/posixc/` tree is pruned relative to the source tree; headers like `ctype.h`, `langinfo.h`, `nl_types.h`, `wchar.h`, and `wctype.h` are not present there.
  - Native include staging must match the installed SDK surface, not copy the raw source-tree `compiler/crt/posixc/include` namespace wholesale.
- Hosted layer sources are a separate include-order case. For sources under hosted layers like `arch/all-unix/...`, keep the AROS include root available but demote it behind host libc headers (`-idirafter` instead of early `-I`) so intended host headers like `<signal.h>` and `<sys/time.h>` win without breaking AROS-specific includes.
- Manual/native module linklibs that are not part of the broad target autolib chain must stay ahead of the discovered autolibs in the generic link order.
  - Concrete effect: keeping `stdc.static` ahead of the autolib chain restored symbol/layout parity for `utility`, `debug`, `processor`, and `timer`.
- Layer mmake compile flags are source-local, not module-global.
  - `USER_CPPFLAGS`, `USER_INCLUDES`, `USER_CFLAGS`, and `USER_AFLAGS` from resolved arch layer `mmakefile.src` files must apply to that layer's sources/overrides only.
  - Do not append hosted/kernel layer flags like `KERNEL_INCLUDES` to the base module compile args.
- Current native status after the generic fixes:
  - `libarossupport.a`, `libautoinit.a`, and `liblibinit.a` build natively.
  - Native ROM artifacts now build for:
    - `aros.library`
    - `bootloader.resource`
    - `exec.library`
    - `utility.library`
    - `debug.library`
    - `processor.resource`
    - `timer.device`
    - `FileSystem.resource`
    - `keymap.library`
  - `Prefs/Env-Archive/ABI` is now emitted by the native `kernel-aros` path and matches the legacy reference byte-for-byte.
  - Current parity state against `/tmp/aros-legacy-reference-linux-x86_64`:
    - `aros.library`, `bootloader.resource`, `FileSystem.resource`, `keymap.library`, `utility.library`, `debug.library`, `processor.resource`, and `timer.device` now differ only in the embedded version date string (`12.3.2026` vs `10.3.2026` in the current reference tree).
    - `exec.library` still has no comparable artifact in that legacy reference tree.

## User guidance and confirmed build-shape findings
- Keep `AGENTS.md` updated when new migration-relevant information appears or when the user gives new build-shape guidance.
- Never modify legacy build scripts, legacy patches, or legacy toolchain behavior to move the CMake migration forward. The legacy build remains the correctness reference.
- The legacy build system is only a reference/checkpoint for correctness and parity. If CMake orchestration differs from legacy behavior, fix the CMake side or the CMake invocation shape, not legacy sources.
- Do not get stuck indefinitely on crosstools internals. ROM/module progress matters more than over-polishing crosstools implementation details.
- When regenerating `cmake-build-debug`, always use the Ninja generator.
- Keep CMake-side primitives broad and reusable. Do not add super-custom `cmake/` macros or one-off module scripts when the behavior is really a shared MetaMake pattern.
- `genmodule` is the common case across the tree; build shared CMake support around it instead of special-casing individual modules.
- ROM module include dependencies expressed as `#MM ...-includes` lines should be modeled with CMake `INTERFACE` targets so header exposure follows dependency edges naturally.
- `rom/mmakefile.src` is the authoritative ROM build order, and per-module `mmakefile.src` `#MM ...-includes` lines are authoritative dependency declarations.
- Layering is a shared mechanism. Model it generically as target/arch/family source overrides, additions, and dependency augmentation; do not hand-wire per-module layer behavior.
- Native crosstools layout should match legacy expectations for target-prefixed tools: GNU target tools install at the crosstools root, while `collect-aros` lives under `<prefix>/<triplet>/bin` with the root-level alias alongside the other target-prefixed tools.
- If ROM progress is blocked on a full native `ExternalProject` crosstools conversion, prefer the existing CMake wrapper-backed crosstools path over editing legacy patches or legacy sources.
- When using the wrapper-backed crosstools path, point both `AROS_PORTS_SOURCES_DIR` and `AROS_CROSSTOOLS_SOURCE_CACHE_DIR` at an existing `bin/Sources` cache so host-tool and crosstools fetches stay local.

## Session Notes (2026-03-12)
- Keep `AGENTS.md` updated whenever new migration-relevant findings appear in the session.
- `%gen_archfamilyrules` participates in real layer reachability and must be modeled by the generic CMake layer resolver.
  - Example: `rom/utility` reaches the `all-pc` layer through `%gen_archfamilyrules mainmmake=kernel-utility family=pc arch=x86_64`.
- Generic native layer/source resolution must combine:
  - active directory layers (`x86_64-all`, `all-linux`, `all-unix`, etc.)
  - active MetaMake alias/side-target reachability from `#MM` target dependencies
- Layer-side `#MM` target expansion affects source discovery, not just dependency order.
  - Example: `kernel-utility-pc-avx` contributes `arch/all-pc/utility/setmem_avx.c`.
- Per-rule `ISA_FLAGS` need source-local propagation through the generic CMake mmake parser so archspecific sources compile with the same ISA knobs as legacy.
  - Example: `arch/all-pc/utility/setmem_avx.c` requires `-mavx`.
- The shared native genmodule module link path must not force `-nostdlib`.
  - Legacy module linking uses module semantics and object ordering, but does not model ordinary resident modules as fully freestanding `-nostdlib` links.
- The staged native public include root does not flatten all of `aros/stdc`, `aros/posixc`, or `dos`.
  - Do not broadly alias those namespaces into root-level headers in CMake include staging.
- Hosted/unix layer sources may intentionally include host libc/POSIX headers.
  - For hosted layer sources, do not force staged `aros/stdc` / `aros/posixc` include paths ahead of host headers.
- Current remaining ROM parity drift is now small and appears to be dominated by compile-flag/codegen/layout differences rather than missing layers, missing sources, or missing module-startup pieces.
- ROM/module layering must follow MetaMake alias targets, not just active `arch/<layer>/...` directories.
  - Confirmed examples:
    - `arch/x86_64-all/debug/mmakefile.src` aliases `kernel-debug-x86_64 -> kernel-debug-i386`, and the real extra sources live in `arch/i386-all/debug`.
    - `arch/all-pc/processor/mmakefile.src` carries the `x86_64 -> i386` processor path and must be reachable from the generic resolver.
- Generic module-layer resolution now needs two pieces:
  - active directory layers (`all-linux`, `all-unix`, `x86_64-all`, etc.)
  - reachable MetaMake alias targets discovered from `#MM- <mmake>-<src> : <mmake>-<dst>` edges
- `%copy_includes` without an explicit `dir=` means "copy headers from the current mmake directory".
  - The CMake include-staging path must support that form generically.
- Native mmake linklibs can publish headers through `%copy_includes`; that include surface must be staged as part of the native linklib dependency graph before dependent ROM modules compile.
- Generic CMake/native module registration must treat `.conf` `rellib ...` entries as real archive dependencies and publish the resulting `_rel` archives for downstream modules.
  - Concrete example: `rom/graphics/graphics.conf` depends on `utility_rel` and `oop_rel`; once the generic graph published rel archives, `graphics.library` linked successfully without per-module fixes.
- CMake aggregate targets that subdirectories register into must be created before the subdirectories are added.
  - Confirmed with `arch/CMakeLists.txt`: `aros-arch-linklibs-native` had to be defined before `add_subdirectory(all-pc/udis86)` or the registration branch was skipped.
- Current verified native ROM state in `cmake-build-debug`:
  - `debug.library` now builds through the alias-correct path and contains `ud_*` symbols from `udis86`.
  - `processor.resource` builds through the corrected generic path.
- Native include staging must follow the installed legacy SDK header surface, not the raw source-tree header surface.
  - Broadly aliasing `aros/stdc` / `aros/posixc` into root-level headers manufactures headers that do not exist in the legacy SDK and changes which API family wins during native module builds.
  - The staged native include tree may still need targeted legacy-compatible aliases like `dos.h`, but not blanket `aros/stdc` / `aros/posixc` flattening.
- The shared native mmake linklib builder must not force the staged native include root ahead of GCC builtin headers.
  - For compiler/linklib builds, `-idirafter ${AROS_NATIVE_INCLUDE_DIR}` matches the required behavior better than `-I${AROS_NATIVE_INCLUDE_DIR}`.
  - Concrete example: `compiler/crt` `linklibs-stdc-static` expects GCC's builtin `<float.h>` semantics for `STRICT_ASSIGN`; forcing the staged AROS root first breaks that build.
- Current verified native ROM state in `cmake-build-debug`:
  - `exec.library` now builds.
  - `debug.library` builds.
  - `processor.resource` builds.
- Additional current verified ROM state in `cmake-build-debug`:
  - `aros.library` builds and emits `Prefs/Env-Archive/ABI`.
  - `bootloader.resource` builds.
  - `FileSystem.resource` builds.
  - `keymap.library` builds.
  - `timer.device` builds.
  - `utility.library` builds.
- Current parity state after the include-surface/link-order fixes:
  - `debug.library` still differs from legacy, but it is now in the right shape and near legacy size.
  - `processor.resource` still differs from legacy.
  - `timer.device` still differs from legacy.
  - `utility.library` still differs from legacy.
  - `exec.library` now builds natively, but the current legacy reference tree still does not contain a matching `exec.library` artifact at the expected compare path.
- Current parity-shape clue from section comparison:
  - native `utility.library` and `processor.resource` still carry explicit `.aros.set.*` sections (`INITLIB`, `EXPUNGELIB`) that are absent in the legacy outputs
  - that points to a remaining generic output-layout/linker-path mismatch in the native module build, not just random byte drift
- The repo-level `emit_tool_stdout_to_file.cmake` wrapper is a reusable pattern for generated ROM/module inputs.
  - Prefer a shared CMake helper over one-off custom commands for `tool -> stdout -> generated header` cases.
  - Confirmed users of the shared pattern now include:
    - `rom/dos` `errorlist.h`
    - `rom/dosboot` `nomedia_image.h`
    - `rom/intuition` `shutdown_image.h`
- The ROM domain needs to support nested module paths under real MetaMake locations like `rom/devs/*` and `rom/filesys/*`.
  - CMake-side ROM interface/native target naming must sanitize nested module paths for target ids, but keep the real nested `MODULE_PATH` so migration follows the actual tree layout.
- Additional verified native ROM state in `cmake-build-debug`:
  - `graphics.library` builds.
  - `oop.library` builds.
  - `layers.library` builds from `rom/hyperlayers`.
  - `intuition.library` builds.
  - `lddemon.resource` builds.
  - `console.device` builds.
  - `gameport.device` builds.
  - `input.device` builds.
  - `keyboard.device` builds.
  - `con-handler` builds from `rom/filesys/console_handler`.
  - `ram-handler` builds from `rom/filesys/ram`.
- Current parity state for the newly verified native ROM outputs:
  - `graphics.library`, `oop.library`, and `layers.library` match legacy size and currently differ in the same small date/version byte region as the other parity-healthy modules.
  - `intuition.library` matches legacy size exactly (`420384`) and its first byte diff is in the same date/version class (`250913: 62 vs 60`).
  - `lddemon.resource` matches legacy size exactly (`17912`) and its first byte diff is in the same date/version class (`7551: 62 vs 60`).
  - `console.device`, `gameport.device`, `input.device`, and `keyboard.device` all match legacy sizes exactly and currently differ only in the same date/version byte region.
  - `con-handler` and `ram-handler` now also match legacy sizes exactly and currently differ only in the same date/version byte region.
- Additional verified native HIDD state in `cmake-build-debug`:
  - `hiddclass.hidd`, `inputclass.hidd`, `keyboard.hidd`, and `mouse.hidd` build and match legacy size exactly.
  - `gfx.hidd` now also builds and matches legacy size exactly (`224424`).
- Current parity state for the verified native HIDD outputs:
  - `hiddclass.hidd`, `inputclass.hidd`, `keyboard.hidd`, `mouse.hidd`, and `gfx.hidd` are now all in the same parity-healthy class as the other migrated ROM artifacts: size-identical to legacy, with the first remaining file diff in the date/version-byte region.
- Arch-layer `%build_archspecific` and `%rule_*` flags must stay source-local in the native CMake module builder.
  - The parser must capture the current `USER_CPPFLAGS`, `USER_INCLUDES`, `USER_CFLAGS`, `USER_AFLAGS`, and `OPTIMIZATION_CFLAGS` at the point each active arch-specific rule is declared, then apply those only to the sources from that rule.
  - Do not let the final `USER_*` state from an arch-layer `mmakefile.src` bleed across every arch source from that file.
  - Concrete example: `arch/i386-all/hidd/gfx/mmakefile.src` sets `USER_CFLAGS := -mssse3` for `rgbconv_sse` and later `USER_CFLAGS := -mavx2` for `rgbconv_avx`; if CMake reuses the last value globally, `rgbconv_sse.o` is built with AVX/VEX encodings and `gfx.hidd` loses parity.
  - Concrete example: `arch/x86_64-all/hidd/gfx/mmakefile.src` keeps `-mssse3 -mavx2` on `rgbconv_arch` only, while the alias-expanded `x86_sse` and `x86_avx` side targets must retain their own separate ISA flags.
- Handler modules do not follow the same `RESIDENT_BEGIN` contract as disk-based libraries/devices/resources in the final linked output.
  - Legacy handler links load generated `*_start.o`, module sources, and `*_end.o`, but do not load `__resident_begin.o` even though `RESIDENT_BEGIN` is defined in the generic make config.
  - The CMake-native generic module builder must therefore skip `RESIDENT_BEGIN` injection for `modtype=handler`; otherwise handlers gain an extra `__resident_entry` stub at address `0`, shifting the real handler entry and breaking parity.
- Current non-fatal cleanup item:
  - some native module links still emit `objdump` / `nm` lookup warnings because those tools are still being resolved under the crosstools root without `/bin`
- The repeated "always rebuild" behavior on settled ROM targets was not caused by the phony per-module convenience targets.
  - The concrete root cause was incorrect CMake byproduct registration for genmodule `_rel` archives on modules whose `.conf` files do not enable `rellinklib`.
  - Legacy only emits `_rel` archives for modules that explicitly opt into `rellinklib` (for example `utility`), so declaring `_rel` outputs for modules like `aros`, `dos`, or `exec` leaves Ninja chasing outputs that never exist.
  - After fixing that in `cmake/AROSModule.cmake`, a settled `ninja -d explain aros-rom-utility-native` returns `no work to do` apart from normal `VerifyGlobs.cmake_force` glob verification.
- Do not run multiple configure/build commands against the same Ninja build directory in parallel.
  - `aros-configure` can be re-entered from different targets, and racing `cmake --build` / `ninja` invocations against one `cmake-build-debug` tree can corrupt the in-flight `legacy-main` configure probe state and produce false `config.log` failures.
Never change legacy build scripts, legacy patches, legacy configure logic, legacy `mmake` files, or legacy toolchain behavior in order to make CMake migration progress.
The legacy build system is the correctness reference.
Use the legacy build only to verify expected behavior and output parity for the new CMake path.
If CMake/parity disagrees with legacy, fix the CMake invocation, CMake glue, CMake target graph, or CMake-native implementation; do not "fix" legacy to match CMake.
Hard rule: do not get stuck iterating on legacy crosstools/tool parity when ROM-side CMake migration work can proceed.
Hard rule: prioritize progressing native CMake work for `rom/` and comparing ROM outputs against legacy over chasing lower-value tool/bootstrap parity issues.
Hard rule: if a task starts drifting into repeated legacy bootstrap troubleshooting, stop and move back to ROM/native-output comparison work.
Hard rule: do not introduce super-custom CMake macros or one-off per-module build logic when migrating MetaMake rules.
Hard rule: prefer broad, reusable CMake primitives that model recurring MetaMake patterns across the tree.
Hard rule: study the larger MetaMake build pattern first for each artifact class (`.library`, `.device`, `.resource`, handlers, linklibs, includes) before implementing CMake replacements.
Hard rule: model layering generically as target-dependent source overrides/additions and dependency augmentation, matching MetaMake semantics instead of hardcoding individual modules.
Hard rule: when a CMake design only solves one module and does not clearly generalize, stop and redesign it at the pattern level first.
Hard rule: keep `AGENTS.md` updated with new migration-relevant findings, blockers, and user guidance during the session.
Hard rule: when the user provides information that changes build understanding or migration direction, record it in `AGENTS.md`.
Hard rule: use `rom/mmakefile.src` as the reference for ROM build ordering and use module `#MM ...-includes` relationships to drive reusable CMake `INTERFACE` dependency graphs.
