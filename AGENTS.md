# AROS CMake Migration Notes

## Goal
Replace the legacy `metamake` + `make` + `autoconf/configure` build flow with a full CMake build, while keeping the tree buildable during migration.
Hard requirement: CMake-native outputs must match legacy outputs 1:1 (byte-identical where feasible) for tools and full system artifacts (`rom/`, `kernel/`, packaged output tree).
Constraint: avoid changing legacy build scripts/sources unless absolutely required for correctness; keep migration behavior in CMake glue.

## End-State Clarification (2026-09-04)
- The end goal is to replace MetaMake with CMake, not to provide a permanent CMake frontend to MetaMake.
- CMake must ultimately own source/layer selection, generated inputs, dependency ordering, compilation, linking, and packaging without invoking MetaMake, legacy make, or legacy configure for the migrated system build.
- Retain `mmakefile.src` support so upstream changes can still be imported. CMake may continue to read those files as declarative build metadata; replacing MetaMake execution does not require removing the manifest format or its parser.
- Legacy execution wrappers are migration scaffolding. Preserve them while replacements are incomplete or unverified, but do not make the finished native build depend on them.
- Existing generators such as `genmodule` can remain build tools invoked directly by CMake; their generation and dependency edges must be CMake-owned.
- Keep the legacy build as the correctness/parity reference. Completing a wrapper target alone does not count as native migration progress.

## First Milestone
- Build and run Linux-hosted AROS x86_64 through the CMake-native path. Hosted AROS runs as a Linux application; this milestone does not require QEMU or a separately booted guest.
- Completion requires the hosted launcher, required runtime modules, and packaged runtime tree to build through CMake and successfully launch to a usable AROS session. A successful module build or legacy-wrapper build alone is insufficient.
- Prioritize dependencies that unblock that hosted build/run milestone, checking migrated outputs against legacy as they are added. Keep `mmakefile.src` compatibility for upstream updates.
- Tackle compiling and cross-compiling other targets after the hosted x86_64 milestone works. Keep shared CMake primitives portable while focusing verification on `linux-x86_64` first.
- Next critical path: finish runtime data and dynamic-module packaging. The runtime packaging checkpoints below pass the former Mount requester and Path crash and reach a verified interactive shell. All 34 configuration-listed boot modules build and relocate. Base fonts now stage natively and FixFonts generates their descriptors without the former error. Classes, Tools/Utilities, theme data, and IPrefs remain missing. This is not completed startup or a usable Workbench session. Complete runtime validation takes priority over expanding unrelated Workbench libraries.
- Extend the shared host/program, genmodule, and kickstart primitives as needed, retaining upstream manifest input support. Individual `exec.library` / `kernel.resource` files are not substitutes for the linked hosted kernel image, and loading that image is not yet a usable AROS session.

## Include-Owned Text Generation (2026-09-07)
- Native include registration now discovers the complete declared fetch closure before registering local or named text-transform prerequisites. The owning include graph supplies receipts to the shared generator; callers no longer list fetch targets or generator rules separately. Assignment-only option includes control selected metadata edges and recipes and trigger ordinary-build reconfiguration. No OS-local CMakeLists, package inventory or copied upstream recipes were added.
- Source preparation remains a bounded two-build handoff when required fetches are not ready. Once ready, the existing prerequisite registry owns aliases, cross-manifest edges, generator ordering and consumer dependencies. A nested include producer computes its own authorization rather than inheriting an outer consumer's unrelated sibling fetch. Removed fetch edges cannot authorize leftover extracted sources. Generated text support remains restricted to the verified sed primitive; it does not permit arbitrary included recipes or make execution.
- The real-tree probe exposed broad candidate matches activating an unrelated PowerPC generated recipe include. Program discovery now filters for actual program/linklib declarations before parsing, and metadata option evaluation is scoped to candidate metadata identities rather than every undecodable macro candidate. Relevant unsupported/generated includes still fail explicitly.
- `aros-include-transforms-check`, also required by `aros-includes-check`, exercises an ordinary program consuming copied and generated headers, local and named generator prerequisites, cross-manifest sibling fetches, option-controlled edges, archive/header/option edits, missing outputs, no-op builds, removed authorization, nested-consumer isolation, cycles, unsupported substitutions/options, unrelated generated includes, and imported/removed manifest augmentations.
- The unchanged zlib local `includes-copy` declaration now builds its declared `workbench-libs-z-pkgc` prerequisite and stages target/host `zlib.h` and `chromeconf.h` through the registry in `/tmp/aros-library-fetch-metadata/build`. The target headers and `zlib.pc` are byte-identical to the workspace reference SDK; the next unchanged target build reports `ninja: no work to do` without reconfiguration (`/tmp/aros-sdk-zlib-includes-build.log`). The probe selects only the manifest and include identity; it no longer supplies transform names or fetch targets to the include target.
- Final verification: the new include-transform graph fixture, existing include suite and standalone transform suite pass (`/tmp/aros-sdk-transforms-graph-final.log`, `/tmp/aros-sdk-transforms-final-includes.log`, `/tmp/aros-sdk-transforms-final-text.log`). All 18 broader regression scripts pass after the final production changes (`/tmp/aros-sdk-transforms-final-regressions.log`). Host header copies also match the reference SDK, the real target remains a no-op (`/tmp/aros-sdk-zlib-includes-noop.log`), and `git diff --check` passes.
- This closes the copy-includes prerequisite integration slice, not the complete zlib SDK/module graph. The separate `workbench-libs-z-includes` aggregate and its `zconf.h` generator still need integration with module SDK producers and the transitional broad `includes-copy` boundary. Do not count an old `zconf.h` left by the standalone probe as a producer in this graph. The archive probe's reference-header dependency, clean configuration independence and usable hosted Workbench remain open. Shared system outputs and the running hosted session were not changed.

## Native Manifest Text Transforms (2026-09-06)
- `cmake/AROSTextTransforms.cmake` adds a shared named local-rule primitive for generated text. It follows manifest-local aliases, reads active assignment-only options, evaluates recipe variables after the manifest and translates single-quoted `$(SED) -e 's/.../.../[g]' $< > $@` recipes directly to a host sed invocation. `/` and `|` delimiters are supported; scripts, execution/file-writing flags, escaped delimiters, multiple inputs and arbitrary setup recipes fail explicitly. No shell, MetaMake, make or configure recipe is executed.
- Inputs must be source-owned static files or exact files from explicitly supplied native fetch producers. Incomplete fetches retain the prepare/reconfigure handoff. Receipts are verified at configure and build time, including source membership before publication. Native output containment and symlink identity are rechecked at build time; successful temporary output is atomically renamed, and failed sed/receipt checks leave the previous output intact. Shared manifest directory setup has a single Ninja producer and recovers when deleted.
- `aros-text-transforms-check` verifies option/recipe evaluation, literal `$${prefix}` data, source/archive/option edits, missing outputs/setup recovery, no-op builds, rejected unsupported recipes, cycles, competing local producers, stale generated inputs, removed fetch authorization, source/output symlink escapes, and modified fetched content (`/tmp/aros-text-transforms-check6.log`). The existing static-text regression passes too (`/tmp/aros-transform-static-text.log`).
- The unchanged zlib `workbench-libs-z-geninc` and `workbench-libs-z-pkgc` rules now generate native `zconf.h` and `zlib.pc` in the isolated `/tmp/aros-library-fetch-metadata/build` tree. Both files are byte-identical to the workspace reference SDK copies, including pkg-config's literal variable references. The probe supplies only selected metadata identities and the existing manifest-discovered zlib fetch producer, not copied substitutions, paths or source lists.
- Final verification: all 18 broader native configuration, metadata, program, linklib, static graph, reconfiguration and fetch regression scripts pass (`/tmp/aros-text-transforms-regressions.log`). Both real zlib outputs still compare byte-identically; the final unchanged two-target build reports `ninja: no work to do` without CMake reconfiguration.
- This verifies the shared primitive and the real generated artifacts, not the complete zlib/SDK graph. Automatic registration through the include/program prerequisite resolver is not wired yet; source-preparation context must come from the owning metadata graph before those aliases can be enabled globally. The prior archive probe still uses reference sysroot headers. Next connect these native transforms and bounded option includes to SDK prerequisites without adopting legacy outputs or dropping sibling dependencies. No shared system build or hosted session was changed; the usable Workbench milestone remains open.

## Linklib Conditions And Option Inputs (2026-09-06)
- The archive compiler now uses the shared balanced equality evaluator instead of greedy comma splitting. Compile regressions cover nested `findstring`/`addprefix`, empty left/right operands, empty equality, else branches and inactive parents; the unchanged zlib manifest passes its architecture conditions without source-specific overrides.
- Active assignment-only source option includes are read at their declaration point by the archive compiler. Fetch discovery and archive compilation share the source-ownership/statement validator; generated or escaped inputs, recipes, metadata, nested includes, included conditionals and direct shell expressions fail explicitly. The generated `config/aros.cfg` bridge retains its separate reader. This is bounded option-fragment support, not a general included-makefile interpreter or a unification of the older archive parser's variable-assignment semantics with the configure-time reader.
- The archive logical-line reader now preserves physical continuations and can retain recipe markers for validation. Parsed option files are archive depfile inputs, including files outside the library source glob. The isolated options fixture verifies declaration snapshots, option-driven source selection and flag edits, stale-member removal, missing-archive recovery, invalid/missing/escaped input rejection and no-op builds (`/tmp/aros-linklib-options-check.log`). Fetch format and dedicated include regressions also pass (`/tmp/aros-linklib-fetch-format-check.log`, `/tmp/aros-linklib-options-includes.log`). General include-prerequisite/configure-graph integration remains separate work; this archive check is not evidence that arbitrary option-controlled metadata edges are supported.
- A direct archive replay from the 185 receipt-owned native zlib sources now succeeds (`/tmp/aros-zlib-linklib-options.log`). All 21 member names/order match the workspace legacy archive; 20 members are byte-identical. `inflate.o` differs because the reference depfile names generic `inflate.c`, whereas the current manifest selects `contrib/optimizations/inflate.c`. Compiling the generic file with the native command produces a byte-identical reference object (`/tmp/aros-zlib-inflate-diagnostic.log`). Keep the manifest-selected source rather than hard-coding a generic fallback; fresh legacy source-selection/parity verification remains open.
- The direct archive probe still uses prepared tools and reference configuration/sysroot headers, including reference-generated `zconf.h`. It does not establish a complete native zlib prerequisite graph, header generation, clean configuration independence or usable hosted Workbench startup. Next migrate/verify the generated header and remaining declared packaging prerequisites through shared primitives. No shared system build or running AROS session was changed.
- Final verification: all 18 broader isolated regression scripts pass, including the new archive-options fixture (`/tmp/aros-linklib-options-regressions.log`). The dedicated include check also passes. The real zlib fetch settles to no work without regeneration after the shared helper changes (`/tmp/aros-zlib-options-fetch-noop.log`); `git diff --check` passes.

## Upstream Zlib Fetch Compatibility (2026-09-06)
- `%fetch` now uses genmf's last-value-wins scalar semantics, including repeated `destination` and `mmake`; other macro translators retain duplicate rejection. Both `tools/genmf/genmf.c` and `genmf.py`, plus the workspace generated zlib makefile, confirm the final destination wins. No upstream manifest or legacy script was changed.
- `scripts/fetch.sh` uses `base` for unpack/patch markers and cached patch copies, not extraction. Native receipts/control files replace that bookkeeping; extraction and patching remain inside the final destination, and the legacy base is never written. The earlier description of a separate extraction base was incorrect.
- Fetch translation opts into source-owned, assignment-only option includes at their declaration point, using the shared rule assignment semantics. Their contents drive recipe fingerprints and ordinary-build reconfiguration. Missing/generated/escaped include files, recipes, metadata declarations, nested includes and conditionals inside those option files fail explicitly. This bounded path is not general included-recipe execution, and does not yet replace the separate linklib compilation parser.
- Archive/receipt paths accept ordinary spaces while still rejecting control characters, traversal, links and unsupported metacharacters. Patch paths retain stricter validation. An absent safe patch subdirectory falls back to the extraction root with a diagnostic, matching legacy `do_patch`'s ignored failed `cd`; existing non-directory paths remain rejected. Failed extraction/patching still cannot publish partial sources.
- The unchanged zlib declaration now downloads, extracts and patches 185 native files in `/tmp/aros-library-fetch-metadata/build` (`/tmp/aros-zlib-native-fetch-final.log`). Their contents match the workspace legacy source tree; the reference alone contains `adler32_simd.c.orig`, a legacy patch backup. Native ownership markers are additional control files. The settled target reports no work without reconfiguration (`/tmp/aros-zlib-native-fetch-noop.log`). No reference extracted source was adopted.
- The format fixture covers repeated/empty scalar overrides, separate bookkeeping base preservation, ordered options and edits, space-containing archive-member recovery, rejected unsafe/unsupported includes and no-op builds (`/tmp/aros-fetch-format-tests3.log`). All seven Python safety tests pass, including patch-root fallback and traversal rejection; the dedicated include fixture passes (`/tmp/aros-fetch-format-includes.log`).
- Final verification: all 18 broader isolated regression scripts pass with the completed implementation (`/tmp/aros-fetch-format-regressions.log`), covering configuration, metadata, programs, linklibs, code generation, static packaging, reconfiguration and fetch integration.
- A direct `z.static` archive probe now reaches the older linklib compiler parser and fails on the nested `ifneq (,$(findstring ...))` condition (`/tmp/aros-zlib-linklib-probe.log`). Reuse balanced condition parsing there, then audit its option-include/source snapshots and remaining generated-header prerequisites. This checkpoint verifies source preparation, not native `libz.static.a`, complete configuration independence or usable Workbench startup. The existing AROS session was left running; shared system outputs were not rebuilt.

## Library-Owned Source Preparation (2026-09-06)
- Ordinary manifest linklibs now gather native fetch receipts from their own selected metadata identity, including aliases and cross-manifest augmentations, even without local `%copy_includes` declarations. Deferred input registration uses the shared metadata reader and source-preparation traversal; archive commands receive the verified receipt context and dependency edges. No package list, OS-local CMakeLists, legacy recipe execution or upstream manifest change was added.
- Missing/changed sources retain the explicit prepare/reconfigure handoff before compilation. Local header declarations still contribute their existing receipt context independently. Compiled prerequisite programs and linklibs are source-ownership boundaries, including linklibs not yet registered; their private fetched files cannot become consumer sources just because a metadata edge names them. This is source preparation, not a complete translation of every non-fetch linklib prerequisite or removal of configuration/sysroot scaffolding.
- The expanded linklib fixture passes headerless initial preparation, archive edits, missing archive/source-tree recovery, ordinary-build discovery of a second fetch via a new top-level manifest, both source trees contributing archive members, removed authorization, cycles, private-library isolation and settled no-op builds (`/tmp/aros-library-fetch-check3.log`). All 18 broader regression scripts pass (`/tmp/aros-library-fetch-regressions.log`), as does the dedicated include fixture (`/tmp/aros-library-fetch-includes.log`).
- A direct native-source archive build through the unchanged bzip2 manifest produces all seven `libbz2_nostdio.a` members byte-identical to the workspace legacy reference (`/tmp/aros-library-fetch-bzip2.log`). This uses prepared tools/SDK and reference configuration; it does not establish archive-container byte parity, the complete bzip2 prerequisite graph or independent bootstrap.
- A real zlib metadata probe follows `linklibs-z-static` to `zlib-fetch`, then rejects the upstream fetch declaration's duplicate `destination` argument (`/tmp/aros-library-fetch-zlib-metadata.log`). Supporting that declaration and its separate extraction-base semantics requires checking legacy macro/fetch behavior, not editing the manifest or adopting the existing extracted source. Generated headers, module fetching and configuration independence remain open. CLion was reconfiguring and an AROS session was running, so no shared build/session was started or disturbed. The usable hosted Workbench milestone remains incomplete.

## Program Fetch Prerequisite Graph (2026-09-06)
- Program source preparation now follows metadata aliases and include prerequisites before collecting compiler inputs. The metadata-only pass gathers native receipts without expanding header lists or recursively registering prerequisite executables before their sources exist. Prerequisite programs retain their own source ownership, and registered runtime/interface producers are boundaries. The normal registry still supplies actual build/staging dependencies and unsupported-producer/recipe diagnostics.
- A second-source-tree regression exposed lost cross-manifest alias augmentations. The shared metadata-edge reader now serves both fetch discovery and ordinary prerequisite registration. Exported identities remain global lookup points even when declared beside their consumer; local traversal cannot discard an upstream-added edge elsewhere. No new package/source list or OS-local CMakeLists was added. The existing broad-SDK alias exception is shared rather than duplicated and remains transitional.
- The fetch fixture checks aliases, same-manifest declarations, nested include prerequisites, absent initial sources, patch/archive edits, ordinary-build discovery of a second source archive, changed second-archive content, actual copied headers, removed source authorization, cycles/unsupported recipes and rejection of a prerequisite executable's private fetched source. Missing-output recovery, receipt verification, no-op builds and Python archive/patch safety coverage remain active.
- Final verification: all 18 isolated regression scripts pass on the frozen implementation (`/tmp/aros-program-fetch-stable-regressions.log`), as does the dedicated include fixture (`/tmp/aros-program-fetch-stable-includes.log`). The isolated bzip2 header target builds and settles without reconfiguration; target and host `bzlib.h` match the workspace legacy reference byte-for-byte. Direct compilation of the receipt-owned native bzip2 source also produces byte-identical `bzip2.o` (`/tmp/aros-program-fetch-bzip2-replay.log`). This uses prepared tools/SDK and reference configuration, not a complete bzip2 link or independent bootstrap. No legacy configure/make execution was used for these checks.
- This does not complete linklib fetch discovery without local headers, generated-header translation, module fetching or native configuration/sysroot independence. CLion was reconfiguring and an AROS session was active during verification, so no shared build or runtime session was started or disturbed. The usable hosted Workbench milestone remains open.

## Indirect Include Fetch Ownership (2026-09-06)
- Include targets now publish their native fetch-target closure, including while awaiting preparation. Outer include consumers collect receipts through resolved metadata aliases, intermediate include producers and multi-manifest include aggregates. Local linklibs inherit those receipts through their existing header context. The registry still owns dependency validation; arbitrary CMake target edges and old files do not imply source ownership. No package list or OS-local CMakeLists was added.
- Stronger output assertions exposed a separate prerequisite bug: a same-manifest `%copy_includes` identity with metadata edges was flattened as a plain alias, retaining the fetch but dropping the actual header copies. Prerequisite collection now recognizes include identities as concrete producers without misclassifying them as target programs. The fixture verifies the intermediate copies themselves, not just successful outer compilation.
- The expanded include fixture checks newly discovered alias augmentations, nested/multi-part include producers, duplicate/shared paths to fetches, two receipts, initial and changed-archive preparation, missing-source recovery, settled no-op builds and rejected cycles/recipes/removed authorization. It passes in `/tmp/aros-indirect-includes-producers.log`. The linklib fixture now obtains its fetched C/assembly/object inputs through an external include producer and alias; it retains content verification and same-consumer fetch-edge removal coverage.
- Parallel testing also reproduced an intermittent race in the explicitly retained legacy header adapter: separate linklibs copied the same header concurrently. `stage_mmake_includes.cmake` now locks within the build tree for its staging pass. This is temporary adapter synchronization, not new legacy execution; the native copier still uses shared Ninja producers.
- Final verification: all 18 broader regression scripts pass after the producer-boundary fix (`/tmp/aros-indirect-regressions-final.log`), including the expanded archive test and fetch safety checks. The unchanged bzip2 header probe succeeds (`/tmp/aros-indirect-bzip2-headers.log`), then reports no work without reconfiguration (`/tmp/aros-indirect-bzip2-noop.log`); both target and host `bzlib.h` remain byte-identical to the workspace reference. `git diff --check` passes. These isolated checks do not establish full-system parity or clean bootstrap independence.
- At this checkpoint program source collection still had its separate direct-fetch path; the Program Fetch Prerequisite Graph checkpoint above supersedes that limitation. Linklib fetch discovery without local header declarations, generated-header translation, remaining module consumers and configuration/sysroot independence are still open. CLion was reconfiguring while an AROS session was running, so no shared build or runtime session was started or disturbed for this checkpoint. The usable Workbench milestone remains incomplete.

## Native Linklib Sources (2026-09-06)
- Ordinary linklib registration now passes native fetch receipts from its local header declarations to compilation through a content-stable, Ninja-tracked context. `TOP`, `TARGETDIR`, and `GENDIR` resolve to native build paths. No package/source list or OS-local CMakeLists was added. This currently follows direct fetch prerequisites of local header declarations, not arbitrary or general transitive linklib fetch dependencies.
- The archive builder verifies receipts before compiling and authorizes exact fetched C/assembly sources and explicit object inputs. Removing the fetch edge cannot adopt leftover files under the native target tree. With receipts active, other inputs must belong to the source tree rather than generated/reference trees. Ordinary libraries without receipts retain older external-source compatibility outside the native target tree; this is not universal source-ownership enforcement. The explicit `LEGACY_GENERATED_HEADERS` adapter retains its old compile context.
- The fetched-source fixture exposed a same-stem C/assembly object collision even after the old path-based fallback. The builder now disambiguates remaining collisions without changing noncolliding member names. The fixture checks archive/source/assembly/object edits, build-time rejection of modified extracted content, removal of the same consumer's fetch edge, preparation/reconfiguration and settled no-op builds (`/tmp/aros-linklib-owned-sources.log`).
- All 18 broader regression scripts pass (`/tmp/aros-linklib-source-regressions.log`), and the dedicated include suite passes (`/tmp/aros-linklib-source-includes.log`). The final expanded linklib fixture passes after the last collision/test changes. A direct replay of the unchanged Codesets linklib compiles its verified native fetched source and produces `autoinit-aros.o` byte-identical to the workspace reference (`/tmp/aros-codesets-native-linklib.log`); its depfile names the native fetched source. This is not verification of Codesets' complete prerequisite graph, which still reaches an unsupported generated SDK-header rule in the isolated header probe.
- The replay uses the prepared compiler, native headers and reference configuration/sysroot; linklib registration still has generated-configuration coupling. No legacy configure/make was invoked for this checkpoint. CLion was building the shared hosted target, so verification stayed isolated; no new shared aggregate or hosted runtime result is claimed. Generated headers, remaining module/linklib fetch consumers, clean configuration independence and the usable Workbench milestone remain open.

## Linklib Header Integration (2026-09-06)
- Ordinary `aros_register_mmake_linklib` registrations now stage local `%copy_includes` declarations through `AROSIncludeTargets.cmake` instead of the old directory glob. Header lists, SDK/host destinations, explicit prerequisite identities and native fetch ownership use the shared translator. No package/header inventory was added. This retains the old linklib-local declaration scope; it does not activate broad shared include aliases across the entire tree.
- Header registration is deferred until native module-interface identities exist. Multiple linklibs from one manifest reuse header targets, and linklibs discovered by later deferred program dependency resolution schedule another pass. Header stamps are file dependencies of the existing linklib include stamp and archive. Manifests with no local copy declarations remain reconfiguration inputs but skip unrelated rule-condition evaluation in the header phase.
- The full configure exposed udis86's unconverted generated `itab.h` prerequisite recipe. Its existing code-generation adapter explicitly retains `LEGACY_GENERATED_HEADERS`; unsupported inputs do not silently fall back to the old stager. The adapter now supplies its existing generated `.c`/`.h` output variables as file-level dependencies, fixing restaging/rebuilding after generated-content changes. Migrating this generator and removing its existing OS-local CMakeLists remains work, as do HIDD/module header staging and linklib external-source/configuration coupling.
- The expanded linklib fixture builds real archives and checks exact header lists, per-declaration private SDK selection, late interface registration, shared copies and later-deferred library discovery, source/manifest edits, newly declared headers, missing-output recovery, unsafe pre-existing generated inputs, and no-op builds. It also checks explicit legacy-generator refresh and native fetched-header preparation/reconfiguration, archive edits and settled no-op behavior (`/tmp/aros-linklib-fetch-verified.log`). These synthetic builds do not invoke legacy configure or make.
- The isolated repository configure succeeds with hosted bootstrap and legacy wrapper targets disabled (`/tmp/aros-linklib-root-configure.log`). Its two strict compiler-support/autoinit header targets build 15 target and 15 host headers byte-identical to the workspace reference SDK (`/tmp/aros-linklib-header-parity.cmake`), then report no work (`/tmp/aros-linklib-root-noop.log`). However, the first build still traversed generated-configuration dependencies into legacy configure and refreshed `cmake-build-debug/legacy-main`; this is not legacy-independent verification. Future isolated repository builds must use their own configuration snapshot rather than pointing at the shared reference directory.
- All 18 broader regression scripts pass (`/tmp/aros-linklib-regressions-final.log`), as does the dedicated include suite (`/tmp/aros-linklib-includes-regression.log`). After CLion became idle, the shared `aros-compiler-arossupport-linklib-native-includes` and `aros-compiler-autoinit-linklib-native-includes` build succeeded (`/tmp/aros-linklib-shared-final.log`); its repeat reports no work without reconfiguration (`/tmp/aros-linklib-shared-noop.log`). `git diff --check` passes.
- The initial shared-build attempt overlapped CLion auto-reload and failed at the now-explicitly-retained udis86 adapter. The request to stop only the agent sandbox arrived after that process exited; no CLion process was terminated. No complete shared OS aggregate or new hosted runtime result is claimed. The usable Workbench milestone remains open.

## Fetched Header Wildcards (2026-09-06)
- Codesets exposed a prerequisite to replacing the remaining linklib stager: its `%copy_includes` lists use the upstream `WILDCARD` helper over fetched directories. Include discovery now selects identities without expanding filesystem-dependent defaults; source preparation and receipt verification precede full declaration-time header selection. Explicit macro values do not evaluate unused recursive defaults.
- The shared wildcard translator accepts absolute patterns only for consumers supplying an ownership validator. Header consumers authorize source-tree files or exact receipt-listed fetched files and receipt-owned directory roots; ordinary static packaging retains its source-relative restriction. Literal directories, regular files, supported shell-hidden-file behavior and configuration-driven helper-definition validation remain enforced. No shell helper is executed and no package/header allowlist was introduced.
- The include fixture now covers source wildcard additions/removals, empty matches, hidden files/directories, declaration snapshots, absolute fetched patterns, preparation handoff, archive-added headers, unreceipted files, explicit overrides of unused defaults, and rejection of external paths, wildcard directories and altered helper definitions. Removing a source removes its copy producer from Ninja; automatic deletion of previously staged headers remains unimplemented.
- The unchanged Codesets fetch prepares 110 files under `/tmp/aros-real-codesets/build`, recursively byte-identical to the reference extracted source tree. A metadata-only probe of its six unchanged header declarations selects seven receipt-owned headers with the expected destinations, all byte-identical to their reference counterparts (`/tmp/aros-real-codesets-{fetch,metadata}.log`). This does not build its complete SDK prerequisite graph: the isolated full-header probe reaches an unsupported generated `aros/i386/libcall.h` recipe through unresolved SDK interface prerequisites (`/tmp/aros-real-codesets-configure.log`). No dependency was replaced with a dummy producer, and module/linklib staging has not yet been switched wholesale.
- Verification: the expanded include fixture passes (`/tmp/aros-wild-includes-final.log`), all 18 existing isolated regression scripts pass (`/tmp/aros-wild-regressions.log`), and the separate static/font wildcard fixture passes (`/tmp/aros-wild-static.log`). The Codesets fetch and unchanged bzip2 header build settle to no-op builds (`/tmp/aros-real-codesets-noop.log`, `/tmp/aros-wild-bzip2-noop.log`); bzip2 retains byte-identical target headers. `git diff --check` passes. No new shared aggregate build or hosted runtime validation was performed.

## Manifest Header Copies (2026-09-06)
- `cmake/AROSIncludeTargets.cmake` translates selected `%copy_includes` declarations for named program prerequisites, plus a local entrypoint for the shared default identity. It reads macro defaults from `config/make.tmpl`, snapshots header lists/options at each declaration, and stages exactly those files. Explicit `dir` flattens names; omitted `dir` preserves relative paths. Target/public and private SDK destinations and host/kernel-only copies retain their distinct behavior. Bare macros are accepted by the shared rule reader.
- Inventory-wide named discovery combines every matching manifest's explicit dependency edges, including dependency-only augmentations. Native fetch receipts authorize exact external headers; the existing prepare/reconfigure handoff applies. Removing the fetch edge cannot be bypassed with an old extracted header. No package/source-directory allowlist, legacy recipe execution, or OS-local CMakeLists was added.
- Copy outputs and interface stamps are Ninja-owned. Source/manifest/archive changes, new top-level producers and missing headers rebuild consumers; settled builds are no-ops. Duplicate same-source declarations share copies; conflicting/aliased outputs, escaping source/output symlinks, unsupported roles/options/includes/prerequisite recipes, local generated-header rules without native producers, and metadata cycles fail explicitly. Build-time checks verify fetched receipts and output containment/canonical identity again.
- At this checkpoint, existing module/linklib registrations still used the transitional directory-globbing path; ordinary linklib registrations have since switched as recorded under Linklib Header Integration above. Broad shared `includes-copy`/`includes` aliases are not enabled globally. General transitive fetch scheduling, generated headers and integration of the remaining module/SDK producers remain work.
- `aros-includes-check` is a dependency of `aros-programs-check`. Its isolated Ninja fixture passes declaration-time defaults, public/private/host/kernel staging, nested/flattened paths, shared copies, source/archive edits, cross-manifest fetch augmentation, producer-edge removal, missing-header recovery, bare macros, unsafe inputs and no-op checks (`/tmp/aros-includes-test.log`). The unchanged bzip2 manifest stages native target and host `bzlib.h` files byte-identical to the corresponding workspace legacy SDK copies, then reports no work (`/tmp/aros-real-includes-{configure,build,noop}.log`). This is header/source integration verification, not full bzip2 linking or hosted Workbench completion.
- Final verification: the tightened header fixture passes (`/tmp/aros-includes-final.log`), as do all 18 existing isolated scripts covering native configuration, graph/program discovery, compilation/linking, SDK objects, code generation, host/module metadata, static packaging, reconfiguration and fetch safety (`/tmp/aros-includes-isolated-checks.log`). The real header probe remains a no-op after rebuilding with final containment checks. `git diff --check` passes. These runs use CLion's CMake in isolated Ninja builds; no new shared-build aggregate or hosted runtime result is claimed.

## Native External Sources (2026-09-06)
- `cmake/AROSFetchTargets.cmake` translates selected `%fetch` declarations using shared manifest discovery, active assignments, and defaults read from `config/make.tmpl`. Archive names, suffix/origin order, destination, and ordered patch specifications come from metadata. `cache://` reads the upstream script's literal cache-base assignment without executing that script. No package allowlist or OS-local CMakeLists was added; unrelated fetch implementation arguments are not validated before identity selection.
- Ninja invokes `cmake/build_mmake_fetch.py` directly to acquire, extract, and patch sources into an owned native directory. Existing declared archive caches are read-only inputs, never existing extracted trees or legacy binaries. Downloads are cached inside the native build. Program/fetch contexts rebase `TARGETDIR` so configuration-derived external paths resolve into native output space instead of the reference tree.
- This is bounded support: regular-file/directory tar.gz, tar.bz2, tar.xz, tgz, and zip archives; local/HTTP(S)/FTP origins; local source-owned unified patches with optional relative subdirectory and `-f`/`-pN`. Separate extraction bases, other pseudo-protocols/archive formats, remote/compressed patches, extra included recipes/options, and fetch prerequisite augmentations require further translation and fail explicitly. Python 3.8+ and `patch` are required when a fetch producer is selected.
- Clean preparation currently requires two ordinary build invocations: the first prepares sources and emits an explicit run-again diagnostic instead of configuring an incomplete consumer graph. Receipt/output discovery reconfigures on the next build, enabling source/header scanning and compilation. CMake excludes custom-command outputs from its own regeneration dependencies, so no configure-time download, recursive build, or generated-Ninja modification was used to fake single-command completion. Archive/patch changes may need the same preparation handoff. Single-command clean bootstrap remains work.
- Completed content-keyed receipts authorize exact generated source files for target-program compilation. Removing the manifest producer invalidates that authorization even if old files exist. Extracted trees are managed inputs: direct edits, extra files, and symlinks are rejected before compilation; modify the archive/patch instead. This prevents generated source changes bypassing configure-time header discovery. This handoff currently covers direct/local-alias program fetch prerequisites, not general transitive fetch scheduling or all module/linklib/include consumers.
- Extraction rejects traversal, duplicate members, links/devices, unsafe filenames, overlapping destinations and unowned destination data. Patches execute only as unified diffs against a staging directory. Failure leaves the previous completed source tree intact. Only matching owned trees or empty directory scaffolding (which Ninja recreates for missing byproducts) may be replaced. SHA-256 receipts record the acquired archive, local patches, and output file contents; these are provenance/integrity records, not upstream-authenticated checksum verification.
- `aros-fetch-check`, also a dependency of `aros-programs-check`, covers preparation/reconfiguration, patch/archive edits, newly required generated headers, missing-source/header/recipe-marker/tree recovery, producer removal, new top-level metadata augmentations, rejected options/paths and no-op builds. Losing the ownership marker rejects existing data instead of overwriting it. Its six Python safety tests (with multiple subcases) cover malicious tar/zip entries, unowned outputs, source inventory changes, patch escapes/failures, destination containment and candidate order. Fetch helper/tool changes participate in configuration dependencies and receipt fingerprints too.
- The unchanged `external-bz2` fetch declaration downloads and patches 56 files in `/tmp/aros-real-fetch/build`; recursive comparison with the workspace legacy bzip2 source tree is byte-identical. The settled fetch target reports `ninja: no work to do`. Direct program-collector/builder replays of these natively fetched sources produce byte-identical `bzip2.o` (55608 bytes) and `bzip2recover.o` (11528 bytes). Logs and contexts are under `/tmp/aros-real-fetch*` and `/tmp/aros-fetch-*`. This verifies source preparation and compilation, not the bzip2 runtime/library link graph or executable packaging.
- The default aggregate still reports the unresolved `TARGET_UNITTESTS` placeholder; no native configuration choice was installed. Complete fetch integration for external modules/linklibs/includes and remaining external-source forms is still needed before full aggregate compilation. No new hosted runtime result or completed usable-Workbench milestone is claimed. Legacy scripts, OS sources and the reference source tree were not modified for this work.
- Verification: 18 isolated regression scripts pass through CLion's CMake with generated Ninja fixtures, covering native configuration, graph discovery, single/batch programs, object directories, program/static dependencies, detach/nix linking, linklibs, code generation, host/module metadata, static graphs/copies/patterns, manifest regeneration and fetch (`/tmp/aros-fetch-isolated-checks.log`). The dedicated fetch fixture also passes the final ownership checks (`/tmp/aros-fetch-final.log`). The main regression invocation overlapped a CLion reload and was stopped by terminating only the agent's build sandbox. CLion subsequently started its own hosted-bootstrap build; no successful shared aggregate run is claimed for this checkpoint. `git diff --check` passes.

## Unix-Style Program Linking (2026-09-06)
- `%build_prog` and `%build_progs` now accept `nix=yes/no`. The shared parser reads `NIX_LDFLAGS` from configuration and inserts them after ISA options, before `NOSTARTUP_LDFLAGS` and `DETACH_LDFLAGS`, matching the upstream link macros. These flags are link-only; no hard-coded `-nix`, object name, library list, or OS-local CMakeLists was added. The existing compiler-specs probe discovers required inputs and requires native producers.
- The real `nixmain.o` producer exposed incorrect SDK-object selection: the first satisfiable generic copy/compile chain hid the explicitly declared `nix/nixmain.o` intermediate and its `_XOPEN_SOURCE=700` flags. The bounded SDK-object translator now considers explicitly declared intermediates before implicit chains and prefers the shortest matching compile-pattern stem, retaining manifest order for ties. It still requires an owned source/compile rule, rejects differing overlapping copy patterns and unsupported constraints, and never lets an existing generated object select or satisfy the rule.
- `aros-programs-check` includes `mmake_nix_programs.cmake`. Its isolated single/batch builds cover link-only options, specs-selected objects/libraries, startup suppression and detach ordering, source/header/archive recovery, configuration edits, no-op builds, selected-rule flag snapshots, declared intermediate/compile-pattern precedence, and rejected invalid options or missing configuration/producers. Startup/archive-only changes relink without recompiling program sources; edits to the combined program metadata currently recompile conservatively.
- A direct isolated compile of unchanged `compiler/startup/nixmain.c` through the shared object collector/builder is byte-identical to the workspace legacy `Development/lib/nixmain.o` (1504 bytes). Context, metadata, output, and log are under `/tmp/aros-nix-*`. This uses the prepared compiler/native SDK and reference configuration; it is not clean bootstrap, full program linking, or runtime verification.
- Full-inventory compilation-metadata/prerequisite preflight now passes the `nix` option and rejects bzip2's generated/external `bzip2.c` because it has no native source producer (`/tmp/aros-nix-preflight.log`). Native external-source fetching/extraction/patching and path ownership are the next blocker; existing extracted reference files must not bypass that check. The unresolved default `TARGET_UNITTESTS` placeholder remains unchanged, and no native configuration choice was installed. The usable hosted Workbench milestone is still incomplete.
- Shared verification passes `aros-programs-check`, `aros-program-codegen-check`, `aros-hosted-metadata-check`, `aros-static-graph-check`, and `aros-manifest-reconfigure-check` through CLion's CMake/Ninja, without main-graph regeneration (`/tmp/aros-nix-checks-final.log`). The discovery fixture's old unsupported-`nix` assertion now tests still-unsupported `usetree=yes` instead. The final isolated nix fixture passes after tightening the missing-archive diagnostic (`/tmp/aros-nix-programs-final.log`); the ordinary default program build still reports the unresolved unit-test edge without regeneration or a partial aggregate (`/tmp/aros-nix-default-diagnostic.log`). `git diff --check` passes. No legacy scripts, OS sources, reference artifacts, or native configuration choices were modified for this checkpoint.

## Program Static Prerequisites (2026-09-06)
- Program prerequisite collection now separates reachable local recipe nodes from metadata identities and delegates them to the existing strict static-data translator. Its `LOCAL_NODE` mode accepts an ordinary unexported rule (or a supported copy-pattern instance) only with strict validation; it does not let an existing file substitute for a missing producer. No Demos-specific adapter, program allowlist, or OS-local CMakeLists was added.
- Deferred registration restores the program's native path context and registers copy/setup outputs as dependencies of both aggregate and individual executable targets. Multiple consumers may reuse the same static producer. Copy-only content edits and added data rules rebuild staging without relinking the executable. Supported formats remain those of the shared static translator; arbitrary recipes, generated copy inputs, unsafe paths, and conflicting output owners are still rejected.
- External exported aliases now resolve their local ordinary rules too, retaining explicit `#MM` dependencies as global edges so local declarations do not hide other manifests' augmentations. Static nodes' exported metadata prerequisites resolve through the program/runtime registry. Native program/static dependency cycles remain errors. This does not complete the entire runtime/module/header dependency graph or implement included make-recipe execution.
- `aros-programs-check` includes `mmake_program_static.cmake`. Isolated checks pass for single/batch programs, shared outputs, normal/order-only prerequisites, copy patterns, direct executable builds, source edits, added/removed rules and top-level aliases, cross-manifest augmentation, setup-only directory recovery, no-op builds, and rejected cycles/recipes/paths/stale inputs/collisions. Existing program-dependency and strict static-graph fixtures also pass.
- An isolated CMake/Ninja project builds the unchanged `developer/demos/mmakefile.src` local copy prerequisite through the program/static handoff. Its staged `Demos/forkbomb` is byte-identical to the source and workspace legacy copy, and the next build reports `ninja: no work to do`. The file is only copied, never executed. Probe files/logs are under `/tmp/aros-real-program-static*`; no legacy file was adopted as a native producer.
- At this checkpoint, the full-inventory compilation-metadata/prerequisite preflight passed `demos` and the following monitor producers, stopping at `external-bz2-bzip2-bin`'s unsupported `nix=yes` (`/tmp/aros-program-static-preflight.log`). The Unix-style linking checkpoint above supersedes that option failure; external-source/fetch requirements remain migration work. This preflight is not a full program build. The default aggregate still has the unresolved `TARGET_UNITTESTS` placeholder, and no configuration choice has been installed in the active cache. No new hosted-session result or completed milestone is claimed.
- Shared verification: `aros-programs-check`, `aros-program-codegen-check`, `aros-hosted-metadata-check`, `aros-static-graph-check`, and `aros-manifest-reconfigure-check` all pass through CLion's CMake/Ninja (`/tmp/aros-program-static-checks-final.log`), without main-graph regeneration in the settled run. The initial invocation overlapped a CLion reload; it finished before the request to terminate only the agent's sandbox could take effect, so verification was repeated after both regenerations finished. `git diff --check` passes. No user process or reference build was changed to make the tests pass.

## Manifest-Defined Program Object Directories (2026-09-06)
- Target-program translation now captures explicit `objdir` at the selected `%build_prog` / `%build_progs` declaration. Native compilation writes named `.o` and `.d` outputs there; omitted `objdir` retains the existing private numeric object layout. This is shared manifest translation, without OS-local CMakeLists or per-program exceptions.
- The program-specific directory does not rebind global `OBJDIR`. Generated-input collection publishes `<mmake>_OBJDIR`, `_OBJS`, and `_DEPS` using the selected directory and follows named object/depfile prerequisites there. Supported Bison rules may generate into that directory or the original global `OBJDIR`; later assignments cannot change the captured directory.
- Explicit paths must be normalized absolute paths without whitespace or unresolved Make syntax, contained in the native build and outside the reference tree. Duplicate object/depfile/program owners fail, including program paths aliased through internal symlinks. Compiler output/depfile containment is rechecked at build time to catch directory or depfile symlink changes after configuration. This is bounded support, not arbitrary object recipes, shared-object deduplication, `usetree`, or a general implicit-rule translator.
- `aros-programs-check` includes `mmake_program_objdir.cmake`. It verifies multi-object/batch compilation, named depfiles, header/config/manifest edits, output-directory changes preserving the fixture binary, missing-output recovery, no-op builds, collisions, and rejected unsafe paths. The code-generation fixture additionally covers custom/global generated-input namespaces, `_OBJDIR`/`_OBJS`/`_DEPS` edges, grammar rebuild isolation, and generator/object/depfile ownership conflicts.
- Verification: the combined `aros-programs-check`, `aros-hosted-metadata-check`, `aros-static-graph-check`, and `aros-manifest-reconfigure-check` build passes through CLion's CMake/Ninja (`/tmp/aros-objdir-checks-final.log`). The separate `aros-program-codegen-check` also passes (`/tmp/aros-objdir-codegen-final.log`), as does `git diff --check`. Direct isolated compilation of the five unchanged NBalance test sources succeeds: Dispatcher, NBalance, Pointer, and Debug objects are byte-identical to the workspace legacy reference; NBalance-Test differs only in five embedded build-date bytes. This replay uses the prepared compiler/native SDK and writes only under `/tmp/aros-objdir-native-replay`; it is not full program linking or native aggregate verification.
- At this earlier checkpoint the full-inventory compilation-metadata/prerequisite preflight passed the first Zune test/demo programs and stopped at `demos`' `forkbomb` file-copy prerequisite (`/tmp/aros-objdir-preflight.log`). The static-prerequisite checkpoint above supersedes that failure by translating its `$(CP) $< $@` rule, not bypassing it. The default program aggregate still failed on the `TARGET_UNITTESTS` placeholder without regenerating (`/tmp/aros-objdir-default-diagnostic.log`); no configuration choice was installed in the active cache. The usable hosted Workbench milestone remains incomplete.

## Aggregate Reachability Versus Build Ordering (2026-09-06)
- Program discovery now treats exported aggregate metadata as a reachability graph, not an executable DAG. Its visited-node traversal terminates cycles while retaining all outgoing edges, including backedges and self-edges. Collected metadata publishes every reached node and its dependencies. No module-name exception, allowlist, or traversal-order edge removal was added.
- Native prerequisite registration remains strict: local/cross-manifest prerequisite cycles, mutually dependent executable producers, unsupported recipes, and unsupported generated inputs are still rejected. This does not establish native scheduling for every reached header-copy/interface producer. Discovery remains a projection, not a universal translator or proof of dependency completeness.
- Both `compiler=host` and `compiler=kernel` are excluded from the target-OS program projection, while their metadata dependencies remain reachable. The unchanged hosted bootstrap is no longer misclassified as a second target-OS executable. Unknown compiler roles fail discovery. Direct program-manifest lookup also excludes host/kernel declarations sharing an identity with a target program.
- Read-only full-inventory collectors with explicit `TARGET_UNITTESTS=no` and `yes` both succeed: 234 target-OS program identities across 1262 metadata nodes. Both preserve the complete upstream header cycle recorded below. Results: `/tmp/aros-aggregate-graph-no-final.cmake` and `/tmp/aros-aggregate-graph-yes-final.cmake`. These counts are verification results, not maintained target lists.
- At this earlier checkpoint, the isolated compilation-metadata preflight rejected `classes-zune-nbalance-test`'s explicit `objdir=$(GENDIR)/$(CURDIR)/test`. The object-directory checkpoint above supersedes that failure with consistent object-output and generated-input translation. A separate prerequisite-only probe reached and rejected the Demos custom `forkbomb` recipe. Other unsupported producers may follow; neither probe is a native program build.
- Regression fixtures cover cyclic aggregates with outgoing programs, self-edges, reversed entry/manifest order, cross-manifest additions, source rebuilds, missing-output recovery, and no-op builds. Concrete local/alias/executable cycles still fail native registration. Compiler-role traversal, shared identities, invalid roles, and the unchanged hosted bootstrap also have coverage.
- Verification: `aros-programs-check`, `aros-hosted-metadata-check`, `aros-static-graph-check`, and `aros-manifest-reconfigure-check` pass through CLion's CMake/Ninja (`/tmp/aros-aggregate-graph-checks.log`). Final graph/discovery fixtures also pass after tightening invalid compiler roles such as `no` and `0` so CMake false values cannot become the default compiler. The ordinary native-program build reports the unchanged placeholder without regeneration or a partial aggregate (`/tmp/aros-aggregate-default-diagnostic.log`). `git diff --check` passes.
- No configuration choice was installed in the active cache, no legacy scripts/sources were changed, and no new boot or parity comparison was performed. Without explicit configuration the default aggregate still fails on the unit-test placeholder. Discovery failures preserve unrelated targets; later unsupported producer registration can still fail configuration itself. The hosted milestone remains incomplete.

## Explicit Native Configuration (2026-09-06)
- `AROS_NATIVE_CONFIG_FILE` optionally supplies literal `NAME=value` configuration assignments to the native manifest readers. It has no default values or per-module inventory. The reference configuration is not modified; unset entries continue to use it, including unresolved placeholders that must still fail when used in the graph.
- Shared configure-time, build-time module/program, and linklib value readers consume the same file. Ordered program configuration seeds these values before evaluating includes, conditions, and immediate assignments, protecting them from reference-config reassignment. This overrides configuration, not manifest-local assignments or CMake's native path context. It is not full native configuration generation or a toolchain/target selector.
- Only blank lines, full-line comments, and literal assignments are accepted. Empty values are explicit, duplicate names and malformed/nonliteral entries fail, and a specified missing file fails rather than falling back silently. No includes, Make expansions, shell commands, or CMake code are executed. The file is parsed once per interpreter; edits between builds reconfigure the graph and update affected native compilation, with no-op builds preserved.
- `aros-programs-check` now includes `mmake_native_config.cmake`. It exercises full versus partial configuration readers, target selection, flag-driven binary changes, external config-file edits, empty values, reserved reader-field collisions, missing-file recovery, rejected syntax/duplicates/shell expressions, unchanged reference bytes, and no-op builds. The existing linklib fixture also verifies config-driven archive rebuilding and subsequent no-op behavior. Program, dependency, detached-program, host/module metadata, static graph, manifest reconfiguration, and kickstart fixtures pass in isolated directories under `/tmp/aros-native-config-*`.
- At this earlier checkpoint, read-only full-inventory probes with explicit `yes` and `no` values exposed a metadata cycle: `includes-copy -> external-openurl-includes -> kernel-dos-includes -> kernel-intuition-includes -> kernel-graphics-includes -> workbench-libs-cgfx-includes -> includes-copy`. The reachability checkpoint above supersedes that discovery failure; no `TARGET_UNITTESTS` choice has been installed in the active cache or reference snapshot.
- Those edges are present in unchanged manifests. `tools/MetaMake/project.c` marks a target updated before recursing and skips already-updated dependencies. Do not reproduce that traversal-order-dependent cycle skipping as Ninja dependency ordering. Aggregate reachability now preserves the cycle separately from native producer ordering; complete header-copy/interface scheduling remains migration work.
- The first shared regression invocation overlapped a CLion auto-reload and was stopped by terminating only the agent's build sandbox. The settled retry of `aros-programs-check`, `aros-hosted-metadata-check`, `aros-static-graph-check`, and `aros-manifest-reconfigure-check` passes through CLion's CMake/Ninja (`/tmp/aros-native-config-checks-final.log`). Program/startup contexts also preserve literal `@...@` text in configuration-file paths instead of treating it as a second CMake template. There is no new complete native program build, runtime session, or full-system parity result.

## Program Graph Evaluation (2026-09-06)
- Program discovery now distinguishes unknown conditions from true/false. Uncertain compiler-only assignments stay opaque; unknown producer presence, identities, compiler selection, exported edges, and conditional includes still fail. Later unconditional assignments can replace an unknown value. The non-discovery rule reader remains strict. This gets past the unchanged AboutAROS manifest without executing its repository scripts or adding a module-specific adapter; it does not implement AboutAROS compilation or generated inputs.
- Macro arguments and candidate identities are tokenized before expansion, preserving quoted/nested Make calls and ignoring apparent `mmake=` keys inside other values. Only program identity/compiler fields are expanded for discovery. Semicolons in conditional arguments survive CMake list handling. Unknown values remain unknown through word functions and immediate snapshots, including unexpanded configuration placeholders.
- The traversal indexes literal identities and precompiled candidate patterns once, caches lookups locally, and parses each candidate manifest once. Ordinary-rule prerequisites join the global graph only after confirming an active export; local files such as `AROS.boot` and inactive declarations do not become global edges merely because they match a variable-name pattern. No new program/directory allowlist was introduced.
- Without an explicit native configuration file, the prepared default graph stops on `test-crt-stdc-@aros_config_unittests@-cunit`: `legacy-main/bin/linux-x86_64/gen/config/target.cfg` still has `TARGET_UNITTESTS := @aros_config_unittests@`, also present in `config/target.cfg.in`. No default was guessed or written into the generated configuration. The explicit-input checkpoint above describes the next blocker after supplying this value. The earlier isolated full-inventory collector reached the placeholder diagnostic in about 51 seconds; that is not successful complete-graph or native-build verification.
- `aros-programs-check` includes `mmake_graph_metadata.cmake`, covering deferred flag conditions, tainted identities/edges/compiler values, assignment modes and snapshots, nested inactive branches, quoted/nested identities, local/inactive exports, semicolon conditions, configuration placeholders, and the unchanged AboutAROS manifest. The existing graph-discovery, program/startup/icon, program-dependency, detached-program, host/module metadata, static-file, static-graph, and font-pattern fixtures also pass. Diagnostics/context are written as literal data, not CMake templates, so `@...@` errors cannot disappear through substitution. Full program compilation, clean bootstrap, new runtime verification, and full-system parity remain open.
- Main Ninja verification reports the exact placeholder diagnostic without regeneration (`/tmp/aros-native-graph-final.log`). The combined `aros-programs-check`, `aros-static-graph-check`, `aros-hosted-metadata-check`, and `aros-manifest-reconfigure-check` invocation passes (`/tmp/aros-native-graph-checks.log`). A final focused regression rejects bare `#MM` under unknown conditions, and candidate indexing preserves possible markers across conditional branches and assignments. Discovery/static-graph/static-text fixtures pass again after that correction; the full-inventory collector still reports the same placeholder (`/tmp/aros-program-graph-final.log`). CLion auto-reload overlapped the first diagnostic check; the settled retry is the verification reference. No new native boot or parity comparison was performed by the agent.

## Program Allowlist Correction (2026-09-06)
- The user explicitly rejected extending the curated program-entrypoint defaults. Earlier checkpoint descriptions of those profiles are historical, not permission to add more module names. Do not relocate or rename such inventories as a substitute for graph discovery. Remaining static/module profiles are migration debt too.
- The root no longer supplies a program-entrypoint list or matches a growing list of old cache values. `AROS_NATIVE_PROGRAM_RULES` is removed on reconfiguration. `AROS_NATIVE_PROGRAM_ROOT` is an optional single aggregate override; its empty default reads `defaulttarget` from `mmake.config.in` on each configuration, rather than copying that identity into CMake.
- `cmake/AROSProgramDiscovery.cmake` follows active exported metadata across the manifest inventory and projects reachable target-side `%build_prog`/`%build_progs` identities. A local program producer does not hide additional declarations of its aggregate in other files. Cross-manifest prerequisites feed the native dependency finalizer, including every part of shared-identity producers, rather than merely listing both programs in an aggregate. Host programs are excluded from this target-side projection. Variable identities and plain-manifest fallback feed the existing native program builder.
- Initial Ninja verification reached the saved AboutAROS discovery failure (`/tmp/aros-default-program-graph-check.log`), superseded by the graph-evaluation checkpoint above. This was a verified diagnostic, not a successful program build. CLion's existing hosted processes were left untouched; no new boot, native IPrefs validation, or parity comparison was performed for this change.
- This is program discovery, not universal translation of other macro kinds or their implicit edges. Unsupported metadata is not executed or silently excluded. Discovery runs in an isolated CMake interpreter; a failure registers a build-failing aggregate with the diagnostic, not a partial list, while keeping unrelated targets configurable. Later program compilation/dependency translation still retains its strict checks.
- The initial AboutAROS failure came from `ifneq ($(REPOTYPE),)`, which depends on an unsupported `$(shell ...)` expression. Discovery now defers that compiler-only decision as described above; `aros-programs-native` and its dependent run target remain blocked by the configuration placeholder. Earlier successful subset builds and shell probes remain historical evidence, not proof that the expanded aggregate builds. Do not restore an allowlist, execute arbitrary Make shell expressions during discovery, or adopt existing binaries to bypass these checks.
- Detached program support now obtains `DETACH_LDFLAGS` from configuration and lets the existing compiler-specs probe/native SDK-object registry select startup objects. No IPrefs-specific source list, `-detach` flag, or `detach.o` producer was added. Its isolated single/batch-program regression passes; a new native IPrefs build/run has not been verified.
- The isolated discovery regression passes actual compile/link, new top-level producer addition/removal, cross-manifest aggregate augmentation, source edits, missing-output recovery, configuration/defaulttarget changes, active/inactive branches, host exclusion, plain-manifest precedence/fallback, no-op builds, cycle rejection and failure recovery. Unsupported graph-affecting shell conditionals block the aggregate without executing the shell or preventing unrelated targets from building; unsupported program options also remain errors. Existing program/startup/icon and program-prerequisite regressions pass after the lookup change.

## Base Font Packaging (2026-09-06)
- The native local static profile now selects `boot;workbench-fonts-quick`. The unchanged `workbench/fonts/mmakefile` supplies the groups, filenames, nested expressions, and pattern copy rule. No font-file inventory, OS-local CMakeLists, or legacy source/manifest edit was added. Only the old default-valued `boot` cache is upgraded; custom subsets remain unchanged. This explicitly selects the exported local quick rule, not the global `workbench-fonts` aggregate with its additional localized/external font producers.
- `cmake/AROSStaticWildcards.cmake` translates the upstream `$(call WILDCARD,...)` source-relative regular-file helper after validating its definition. It never executes `$(shell ...)`. The bounded glob support uses literal source directories, excludes implicit hidden entries from the inventory, and requires owned, representable source filenames. Inventory/configuration changes trigger ordinary-build reconfiguration. Directory globs, arbitrary helper definitions, unsafe paths and escaped/build-cache sources fail explicitly. The helper definition still comes from the legacy configuration bridge; this is not native configure replacement.
- Configure-time Make expansion binds `foreach` variables before evaluating nested word/call functions, restoring outer bindings afterward. Only static-rule consumers opt into filesystem-aware expansion; the separate build-time interpreter remains unchanged.
- `cmake/AROSStaticPatterns.cmake` instantiates reachable absolute single-stem CP rules with one existing source prerequisite. Overlapping patterns, generated source chains, extra prerequisites/recipes, unsafe destinations, and explicit targets requiring implicit recipe search fail rather than being guessed. Exact source copies also reject locally declared pattern-generated inputs. This is not a general Make implicit-rule resolver. The local quick slice does not require translation of the font setup's automatic-variable directory recipe.
- The isolated `mmake_static_patterns.cmake` regression covers nested foreach/filter expansion, binding restoration, source/manifest edits, file additions/removals, missing-output recovery, no-op builds, helper configuration edits, unsupported patterns/definitions, stale generated sources, and symlink/build-cache escapes. It also stages all 36 files selected by the real font manifest. `aros-static-graph-check` includes this fixture alongside the global static graph and directory-copy checks. Existing isolated static file/text/graph/directory-copy, program/startup/icon/dependency, host/module metadata, and manifest reconfiguration checks pass.
- The complete selected native launcher/boot/core/program/data build passes. All 36 native font files are byte-identical to source and the workspace legacy copies. The next ordinary aggregate build reports `ninja: no work to do` without regeneration. Logs: `/tmp/aros-font-runtime-verified-build.log`, `/tmp/aros-font-runtime-noop.log`. CLion again began an automatic reload during the agent's initial Ninja regeneration; the agent stopped its own build, waited for CLion, then verified against the settled graph.
- Final main-Ninja verification also passes `aros-static-graph-check`, all 34 non-executing boot relocations, and the hosted boot-trace regression. Log: `/tmp/aros-font-runtime-checks.log`. No completed milestone or full-system parity claim follows from these checks.
- A bounded 30-second native boot no longer reports missing `SYS:Fonts` or the FixFonts failure. FixFonts creates five `.font` descriptors and `fontcache` in the runtime tree; these are runtime outputs, not adopted legacy files. The window-specific probe again executes `echo cmakenativeshellok` and `version`, displaying `Kickstart 51.51, Workbench 40.0` and another prompt. Screenshot: `/tmp/aros-hosted-base-fonts.png`; host trace: `/tmp/aros-hosted-base-fonts.log`. The intended timeout exits 137 and leaves no bootstrap processes. Missing Classes/Tools/Utilities/theme/IPrefs still prevent complete startup; full-system parity, a clean independent build, and a usable Workbench remain unverified.

## Runtime Packaging And Shell Input (2026-09-06)
- `aros-runtime-data-native` now selects `workbench-s`, `workbench-devs-mountlist`, and `workbench-directories`, alongside the existing local boot signature rule. Mountlist, the seven DOSDrivers files, and Workbench's setup directories come from unchanged metadata; no file/directory inventory or OS-local CMakeLists was added. Previous default-valued caches upgrade, while intentional custom subsets remain unchanged.
- `cmake/AROSStaticDirectoryCopies.cmake` translates the guarded flat-directory `if [ -d ... ]; then MKDIR ...; CP .../* ...; fi` pattern as data, not executable shell recipes. CMake inventories optional source directories and non-hidden immediate files; additions/removals reconfigure on an ordinary build, content edits rebuild, and missing outputs recover. Empty existing sources, subdirectories, unowned/local-generated sources, unsafe destinations, extra commands/options, and explicit prerequisites fail rather than being guessed. Source removal drops its producer but does not delete previously staged files, matching the legacy CP behavior. Recursive copying and arbitrary recipe interpretation remain unsupported.
- The shared reader recognizes double-colon setup rules and space-indented `%mkdirs_q` calls, as used by `workbench-directories`. Copy commands create their parent directories without claiming separate directory outputs; otherwise the DOSDrivers copy and Workbench setup produce duplicate Ninja outputs. The isolated regression includes a separate manifest owning the same directory, setup/copy recovery, optional directory appearance/removal, hidden entries, source/manifest changes, no-op builds, generated patterns, symlink escapes, and conflicting file producers. `aros-static-graph-check` runs it alongside the existing global static graph fixture.
- The first packaged boot passed Mount but crashed at `Path_main+0x35a` after `SYS:System: object not found`. Source and disassembly show the existing command carries a NULL insertion predecessor after a failed path, then dereferences it on the next successful insertion. Native Path differs from legacy only in three build-date bytes. No Path source workaround was added; the program profile now also selects `workbench-system` and `workbench-fs-pipe`, producing CLI, FixFonts, and pipe-handler through existing shared program primitives rather than creating an empty System directory.
- Verified: Mountlist and all seven DOSDrivers files match both source and workspace legacy bytes. CLI, FixFonts, and pipe-handler are byte-identical to legacy too. The combined native launcher/boot/core/program/data build succeeds and the next ordinary build reports `ninja: no work to do` without reconfiguration. All 34 boot modules relocate; static graph/directory-copy/file/text, manifest reconfiguration, host/module metadata, program/startup/icon/dependency, and boot-trace checks pass. Logs: `/tmp/aros-directory-runtime-verified-build.log`, `/tmp/aros-runtime-packaging-verified-build.log`, `/tmp/aros-runtime-packaging-noop.log`, `/tmp/aros-runtime-packaging-checks.log`. Full-system parity and clean legacy independence remain open.
- Subsequent 30-second native boots reach the shell without the Mount requester or Path crash. A window-specific X11 probe executes `echo cmakenativeshellok` and `version`, returning `Kickstart 51.51, Workbench 40.0` and another prompt. The HIDD's inner drawable, not its named outer window, receives keyboard events; the probe does not move desktop focus. Screenshot: `/tmp/aros-hosted-runtime-shell-probe.png`; trace: `/tmp/aros-hosted-runtime-shell-probe.log`. This verifies shell input, not complete startup: missing Classes/Fonts/Tools/Utilities/theme/IPrefs and `FixFonts failed: not enough memory available` remain visible. Investigate those native producers next, including the wildcard/pattern-copy font manifest; do not interpret the FixFonts message alone as proven memory exhaustion. The bounded runs terminate at the intended limit with no remaining bootstrap processes.

## Startup Command Graph (2026-09-06)
- The hosted program profile now selects `workbench-c`, `workbench-c-shellcommands`, `hosted-X11-monitor`, and `workbench-c-shell`. Eval, RequestString, AddDataTypes, and the self-starting command batch are reached through declared prerequisites rather than repeated in the defaults. Existing default-valued caches are upgraded; intentional custom subsets are preserved.
- Native runtime-module targets publish their exact mmake identity. Program prerequisites resolve only registered native runtime/interface producers or discovered programs/catalogs/icons, not similarly named legacy wrapper targets or existing output files. Newly discovered programs are finalized transitively. Recipe-less external aliases follow active metadata across manifests; absent metadata aliases remain optional, as in MetaMake. Unsupported reachable recipes/macros and local/external alias cycles fail explicitly; program target cycles are rejected by CMake.
- A program identity can have producers in multiple manifests. The real `workbench-c` identity is shared by the main 49-command batch and HDTool. These are grouped, with output-ownership checks; multiple active program declarations within one manifest still need separate rule-snapshot support and fail explicitly. The profile selects program macros and their local prerequisites, not every augmentation of the global `#MM workbench-c` aggregate. Full global runtime closure remains work.
- The first expanded build linked all 36 shell commands but failed compiling SetPSM on an unused version string. A read-only GNU Make configuration probe confirmed the actual legacy `CONFIG_WARN_CFLAGS` is empty: its immediate assignment precedes the compiler-feature definitions. The old CMake lazy reader incorrectly picked up later `-Wall -Werror`. Do not fix this with a SetPSM source edit or per-command suppression.
- `cmake/AROSMmakeConfig.cmake` now reads the prepared program configuration through `config/aros.cfg` in include order, preserving immediate/recursive assignment and append semantics. Configuration-derived output paths are rebased to the supplied native roots after reading the legacy snapshot. Includes and optional-include inventories trigger graph refresh. Configuration recipes are not executed; unused shell helpers retain an unsupported-value marker and fail if consumed. Unknown active conditions, required missing includes, and recursive includes fail explicitly. Partial synthetic profiles retain the old individual-value reader; modules/linklibs have not been switched to this snapshot reader. This is still a legacy-generated configuration bridge, not native configure replacement.
- Shared `strip` expression support preserves nested `foreach` bindings. Isolated regressions cover program/runtime prerequisites, multi-manifest producers and conflicts, same-manifest program dependencies, source/config edits, optional includes, missing outputs, no-op builds, cycles, and unsupported recipes/config expressions. Existing program/startup/icon, host/module metadata, kickstart, linklib, native CRT-header, static-graph, and manifest-reconfiguration checks pass. SetPSM compiles unchanged with flags matching the legacy probe.
- The combined `aros-programs-native`, hosted launcher/boot-module, core-module, and runtime-data build succeeds; all 34 boot modules relocate without execution. The following ordinary aggregate build reports `ninja: no work to do` without regeneration. CRT metadata/header/link and boot-trace checks pass too. Logs: `/tmp/aros-startup-commands-verified-build.log`, `/tmp/aros-startup-commands-noop.log`, `/tmp/aros-startup-crt-trace-checks.log`. Known CRT noreturn and macro-redefinition warnings remain non-fatal.
- Targeted parity for the 86 newly selected core/shell commands: 48 are byte-identical to the workspace legacy reference, including HDTool and SetPSM; the other 38 each differ in exactly three bytes, solely the embedded date `06.09.2026` versus `12.03.2026`. All file and text/data/bss sizes match. Replacing only that date in an in-memory comparison makes all 38 identical; native files are unchanged. Details: `/tmp/aros-startup-parity.log`. This is not full-system parity or a fresh legacy reference build.
- Two bounded 30-second launches now pass the earlier missing-command/RAM:ENV failure. The readable `--verbose --forcestdmodes` run opens a 1024x768 AROS screen, reports missing `SYS:Classes`, `SYS:Fonts`, and `DEVS:Printers`, then waits at a Mount Failure requester showing `ERROR`. The native tree also lacks `DEVS:DOSDrivers`, which Startup-Sequence passes to Mount. Both runs end at the intended timeout with no remaining bootstrap processes; no shell input probe was sent while the requester was active. Screenshot: `/tmp/aros-hosted-startup-standard-modes.png`; trace: `/tmp/aros-hosted-startup-standard-modes.log`. Extend the manifest-driven data/runtime graph (including `workbench/devs/mmakefile.src`, `workbench/fonts/mmakefile`, and class producers), not ad-hoc empty directories or copied legacy outputs. Startup completion and a usable session remain unverified.
- No OS/SDK CMakeLists or legacy source/manifest edits were added for this increment. Continue removing the remaining transitional OS-local registrations through verified shared primitives; the preceding 31-file Workbench cleanup is not the end state.

## Deferred Boot Log (2026-09-05)
- User is prototyping `rom/syslog` in the adjacent `apolloos` tree as a Linux-style visible boot log, so startup is not just a silent screen. They would like it to capture existing `D(bug(...))` diagnostics too.
- User explicitly said to finish CMake first. Afterward, port the syslog prototype from ApolloOS into this AROS tree and develop/test it here; leave the ApolloOS tree unchanged.
- The user never got the ApolloOS prototype working correctly. It is unfinished reference code, not a known-good implementation: the follow-up includes diagnosing, implementing, and verifying a working AROS boot log, not merely copying files.
- The current prototype renders directly into an Intuition window. Early message buffering and display attachment are separate future concerns; boot-device selection and the boot menu remain dosboot responsibilities.
- `compiler/arossupport/include/debug.h` compiles `D(...)` away when `DEBUG=0`. A future log sink can capture emitted diagnostics, not code absent from the binary; normal boot-progress logging needs a separate enablement policy.
- User additionally wants both `AROSBootstrap` console output and the in-OS boot display to be more verbose and show the same output. Treat these as two views of one ordered boot-log stream, not independent messages that can diverge. Preserve early bootstrap messages for the later in-OS display and continue mirroring kernel/OS boot progress to the host console. The full buffered/display syslog remains deferred; the user subsequently brought forward useful console boot tracing to help current CMake runtime diagnosis without repeatedly resorting to GDB. This does not authorize work in ApolloOS.
- User considers the existing `D(bug(...))` diagnostics the likely source of that output. Prefer reusing those diagnostics instead of maintaining a parallel set of boot messages; enabling relevant compiled-out diagnostics remains necessary. The immediate boot-only enablement below is implemented; broader syslog filtering remains future work.

## CRT Metadata Repair (2026-09-06)
- Both post-DOS CRT build failures were reproduced through Ninja. The shared module resolver now uses the same object-basename identity as the layer classifier and resolves the override's own relative path, rather than the base token. This selects the declared x86_64 assembly for `stdc/longjmp` and `stdc/setjmp`; missing overrides and ambiguous base identities fail explicitly.
- The staged flat libc aliases were synthetic, not a faithful legacy SDK surface: the workspace legacy SDK has no root `errno.h` or `stdlib.h`. Removed bulk alias publication, its unused helpers, the growing per-header removal list, and the ineffective `compiler/crt`-specific `-I` workaround. Libc headers remain in their published namespaces and use the shared compiler search order. This supersedes earlier claims that a mixed flat libc header surface matched legacy; broader header staging is still transitional.
- `aros-crt-metadata-check` adds real CRT and synthetic relative/extension override, precedence, missing-source, and ambiguity checks plus an actual target-compiler header probe. The probe passes for POSIX errno/environment/jump/signal/time declarations without module-specific flags. Host/module metadata, kickstart, and program/startup/no-op regressions also pass.
- The combined native core-module/hosted/program/data rebuild succeeded in `/tmp/aros-crt-rebuild.log`, including `m.library`, `stdlib.library`, and `crt.library`. All 34 boot modules relocate and the boot-trace regression passes. A subsequent bounded run loads stdlib but repeatedly initializes m until Boot Mount overflows its stack (`/tmp/aros-hosted-after-crt.log`); the 15-second SIGKILL timeout left no bootstrap processes. This is a new concrete runtime failure, not a usable session.
- The math layer declared `../fenv`, which legacy finds as `arch/x86_64-all/crt/fenv.c` through its manifest-directory VPATH fallback. Native source resolution silently omitted this addition. The shared layer resolver now supports the declared-path/module-directory fallback for overrides, additions, and their source-local flags. Missing additions fail explicitly. This remains bounded source lookup, not full arbitrary VPATH/include-recipe interpretation. The real math-manifest regression and synthetic missing-addition negative case pass. The full stable rebuild passed in `/tmp/aros-crt-fenv-stable-rebuild.log`; native `fenv.o` and `_fenv.o` are byte-identical to legacy. An earlier attempt was interrupted after the shared graph/log were regenerated externally; the stable retry recorded its work normally.
- That rebuild still linked six math self-call stubs. A link map traced them to CMake's added genmodule `--undefined` entrypoint flags, not implementation references: the exported public names differ from the configured underscored implementations and some are inline-only. Legacy resident-module recipes do not use the entrypoint list. The shared builder no longer injects those flags; the resident function table retains implementations, and explicit manifest link flags remain intact. `aros-crt-link-check` rejects the old math binary and passes the rebuilt native library. Its output path comes from the public `m.library` target; the internal producer does not expose `AROS_MODULE_OUTPUT`.
- The link-map probe also showed compiler specs searching the legacy sysroot's archives before native `-L` paths. Resident linking now derives the sysroot from the native public SDK library directory. The corrected math test link selects native support archives, with only compiler-owned `libgcc` outside the native SDK. This is not full generic archive provenance enforcement: other explicit SDK/configuration bridges still need migration. The corrected probe has text/data/bss 228828/8/16 versus legacy 228844/8/16; strict parity remains open.
- `aros-hosted-run-verbose` now depends on the existing `aros-core-modules-native` aggregate. This closes the three CRT outputs in that prepared-tree run profile, not the complete dynamic runtime dependency closure. Compiler module registration remains transitional.
- Before the fenv repair, stdlib native/legacy text/data/bss match at 62816/0/24. CRT `.text` (136436), `.eh_frame` (31592), data (220), bss (616), and defined-symbol names match; native `.rodata` is 13792 versus 14448. Embedded source paths are relative natively versus absolute in legacy, and build dates differ. Strict CRT binary parity is not claimed. The complete native STDC header namespace matches the workspace legacy tree; POSIX headers have an extra native `sys/statvfs.h`, so full SDK header parity is not claimed either.
- Final combined core-module/hosted/program/data build and both CRT checks pass in `/tmp/aros-crt-final-stable.log`. The next ordinary build reports `ninja: no work to do` without regeneration (`/tmp/aros-crt-final-noop.log`); all 34 boot modules relocate and the trace regression passes (`/tmp/aros-crt-final-load-trace.log`). The first attempt stopped on incorrect test output-path wiring. After correcting it, an overlapping regeneration replaced the shared graph/log; that resume was interrupted. The final retry kept the graph unchanged and recorded work normally. CLion reports auto-reload enabled; wait for its configuration to finish before starting Ninja after CMake edits.
- Two 30-second native boot probes now initialize math once, start the monitor driver and reach console/CLI setup without the former recursive load or stack overflow. Screenshot `/tmp/aros-hosted-after-link-fix.png` shows an X11 screen with a `1>` prompt, missing `SetClock`, `FailAt`, `If`, `MakeDir`, and `EndIf`, then `Can't find RAM:ENV`. The visible errors identify the next packaging slice: `workbench-c` and `workbench-c-shellcommands` from their unchanged manifests. Keyboard interaction and a usable session are not verified. Both SIGKILL-bounded probes exit 137 and leave no bootstrap processes. Logs: `/tmp/aros-hosted-after-link-fix.log` and `/tmp/aros-hosted-after-link-fix-display.log`.
- Fresh parity retains byte-identical `fenv.o`, `_fenv.o`, and 11 selected packaged files (bootstrap configuration, boot signature, shell segment, X11 monitor/icon, startup object and five S scripts). Kernel and stdlib text/data/bss still match legacy. Sixteen launcher/loader objects match their pre-registration-refactor references after stripping debug metadata; `bootstrap.c.o` differs in exactly one embedded build-date byte (05 versus 06 September). This supersedes the earlier 17-of-17 observation after the date rollover. Math remains 228828/8/16 versus legacy 228844/8/16; CRT remains 181820/220/616 versus 182476/220/616.
- The remaining math mismatch is not merely a date difference: module `-isystem` paths select native `aros/stdc/float.h` before GCC's builtin header, and its LDBL_MAX constant overflows. The legacy e_powl dependency file selects GCC's float.h. A target-compiler `_Static_assert(LDBL_MAX == __LDBL_MAX__)` probe fails with the current module order and passes when the compiler's own include directory comes first. Function-size differences include catanl, ctanl and __ieee754_powl. Repair shared builtin/SDK header precedence and extend regression coverage; do not alter individual math sources or claim strict parity. The existing POSIX header probe explicitly supplies the builtin include directory and therefore does not expose this additional ordering defect.

## Remaining Local Registration Cleanup (2026-09-06)
- Removed 31 redundant Workbench library-local CMakeLists. The existing selected-library profile calls `aros_register_mmake_genmodule_module` directly; module names/types/configuration, link declarations and layers still come from the manifests, not replacement per-library CMake files. All 64 module/interface commands in the selected Workbench aggregate match the preceding graph apart from command working directories. Legacy wrapper names remain available.
- This is a bounded deletion of redundant registrations, not completed manifest-driven OS discovery. The parent Workbench profile and its hand-maintained selection defaults still need replacement, as do ROM/compiler/HIDD/Udis86 registration. `muimaster` still owns a native header generator and `cgxvideo` owns compatibility flags absent from its manifest; retain these two explicit adapters until their replacements preserve those behaviors. Do not silently adopt arbitrary new library-local CMakeLists.
- The module builder resolves builtin headers through the selected compiler's `-print-file-name=include` query and supplies that directory before native SDK `-isystem` fallbacks. Both base and architecture-layer compile surfaces retain it, including host-header mode. No compiler version/path is hard-coded. The real CRT probe now uses production flags rather than prearranging a test-only builtin search path, asserts floating-point limits, and checks compiler-owned `float.h` and `stddef.h` in the depfile. POSIX declarations, host/module metadata, CRT layers, program/startup, linklib depfiles, manifest reconfiguration, kickstart, and runtime producer-graph checks pass.
- The combined core-module/hosted-bootstrap/boot-load/program/runtime-data build passes (`/tmp/aros-header-order-rebuild.log`), including both CRT checks and relocation of all 34 boot modules. The following ordinary aggregate build reports `ninja: no work to do` without regeneration (`/tmp/aros-header-order-noop.log`). Boot-trace/quiet-mode/argument-precedence tests pass (`/tmp/aros-header-order-trace-check.log`). The full Workbench library aggregate was inspected for command parity, not rebuilt in full. Non-fatal HWAttrBase and _GNU_SOURCE redefinition warnings remain; the floating-constant overflow warnings are absent.
- Rebuilt math text/data/bss now matches legacy at 228844/8/16. The affected `e_powl.o`, `s_catanl.o`, and `s_ctanl.o` are byte-identical to the workspace legacy objects. All sized function symbols match; the sized-symbol comparison differs only in the embedded M_LibID string. The complete math binaries still differ in 5274 bytes, with differing assembly/archive symbol placement and build dates (6.9.2026 versus 12.3.2026); this is not strict binary parity. Kernel/stdlib section sizes still match the preceding checkpoint, and CRT remains 181820/220/616 versus legacy 182476/220/616.
- A separate AROSBootstrap session appeared during validation and left a running kernel child. It was not started by the agent's non-executing trace tests and was left untouched; no competing GUI smoke test was run. The preceding visible-shell/missing-startup-command checkpoint remains the latest agent-verified launch evidence. Read-only preflight confirms both `workbench-c` and `workbench-c-shellcommands` parse into native program metadata; their registration, declared dependency closure, build and runtime verification remain next work.

## Hosted Registration Migration (2026-09-05)
- `arch/CMakeLists.txt`, `bootstrap/CMakeLists.txt`, and the hosted bootstrap, Unix boot, and hostlib local CMakeLists are removed. Shared orchestration now lives in `cmake/AROSHosted.cmake`; `AROSMmakeEntrypoints.cmake` discovers active producers by metadata identity across the manifest inventory. This is not a claim that all OS/SDK local CMakeLists are gone: Udis86's mixed host-tool/target-SDK code generation still has an explicitly transitional registration, as do existing compiler/ROM/Workbench subsystems.
- Host source/layer selection continues through the shared collector. Host output directories now come from `targetdir`/`libdir`; declared host archive prerequisites are discovered recursively and target-side archive prerequisites are ordered without linking them into the host executable. The `romhack` provider comes from active metadata aliases, not a constructed `arch/<cpu>-all/crt` path. The former default `AROS_ARCH_NATIVE_MODULES` cache is retired; custom directory overrides produce an explicit migration diagnostic.
- `AROSScriptOutputs.cmake` translates the Unix boot manifest's declared shell-script/stdout generator and directory prerequisite. It preserves direct output-specific `=`/`:=` assignments, conditional inputs, and late recipe variables. Included recipe files, inherited target-specific variables, unsupported recipes, unowned/generated inputs, cycles, and ambiguous producers are rejected. This is bounded recipe translation, not a general Make evaluator. Other rule consumers do not silently accept these target-specific assignments.
- The bootstrap configuration is also generated into a private configure-time preview, using the same declared script and arguments. Hosted runtime discovery reads that preview instead of duplicating its template path and `@arch@` substitution. The packaged output remains Ninja-owned; manifest, script, template, interpreter, and imported configuration changes refresh its graph. Failed stdout generators remove partial/stale outputs.
- Shared expression handling now supports resolved `filter`/`filter-out` patterns, including a single `%` wildcard. Unresolved nested expressions remain unresolved for strict consumers rather than being evaluated as literal words. Raw manifest identity expressions are cached by content hash to avoid repeatedly scanning full manifests; conditions and paths are still evaluated in context.
- The new `aros-host-discovery-check` passes actual host compile/link/script generation, conditional producer selection, relocating a producer into a new top-level directory, plain-manifest fallback, source/script/template/config edits, missing-output recovery, no-op builds, and negative graph/recipe tests. Host/module metadata, kickstart, program, linklib, catalog, program-code-generation, static-text/static-graph/static-file, manifest-reconfiguration, and runtime-graph regressions also pass.
- The combined native bootstrap, selected-program, runtime-data, and boot-load build succeeds; all 34 configured boot modules relocate without execution. `AROSBootstrap.conf` and `AROS.boot` remain byte-identical to the workspace legacy reference. Kernel text/data/bss remain 157823/144/1064. All 17 launcher/loader objects match the pre-registration-refactor objects after stripping debug metadata. The build mirror is `/tmp/aros-arch-manifest-build.log`. These checks do not establish full binary parity or a usable session.
- Shared-tree incremental verification initially hit the concurrent-regeneration issue again: the completed build's steps were absent from the active `.ninja_log`, and the next dry-run warned about a premature end of file. A dry-run listing CMake regeneration behind `VerifyGlobs` is not itself proof that an ordinary build reconfigures. CLion MCP confirms auto-reload is enabled for this same build directory; the actor replacing the log was not established. The stable retry kept `build.ninja` unchanged and recorded completed steps normally: the complete native build, 34-module load check, and boot-trace regression passed, followed by an ordinary bootstrap/boot-module/program/data build reporting `ninja: no work to do` without reconfiguration. Logs: `/tmp/aros-arch-final-incremental.log`, `/tmp/aros-arch-final-load-trace.log`, `/tmp/aros-arch-final-noop.log`. Avoid concurrent regeneration/builds rather than attributing lost-log recompilation to source dependencies.

## Boot Signature And Post-DOS Checkpoint (2026-09-05)
- The former missing `AROS.boot` blocker described below is fixed through shared generated-text recipe translation. `aros-runtime-data-native` selects the exported local `boot` rule from the unchanged manifest, writing the CPU signature natively. It is byte-identical to the workspace legacy file (`x86_64` plus newline). Do not confuse this local rule slice with the larger global `#MM boot` aggregate, whose other prerequisites remain migration work.
- `aros-static-text-check` covers text/manifest/configuration edits, missing outputs, newly discovered local producers, no-op builds, and rejection of unsupported expressions/recipes, unknown or stale prerequisites, cycles, and escaped destinations. Static-text, static-graph, static-file, and boot-trace checks passed at this checkpoint.
- A bounded verbose native run now accepts the DOS volume and reaches `RTF_AFTERDOS`. The next trace shows Emergency console and icon initialization followed by `OpenLibrary("stdlib.library", 1) = NULL`. No usable hosted session was observed; the 12-second SIGKILL timeout is not successful boot completion. The diagnostic mirror is `/tmp/aros-hosted-afterdos-boot.log`.
- At this earlier checkpoint native `stdlib.library` and `crt.library` were absent. Building their existing targets exposed shared migration defects: stdlib selected generic `compiler/crt/stdc/longjmp.c` (which deliberately errors) instead of the x86_64 assembly override; CRT compilation reported undeclared `EISDIR` in `posixc/__fdesc.c`. The CRT repair above resolves those build failures without copying legacy libraries or removing source guards. Complete post-DOS runtime producer closure remains work.
- Read-only follow-up found an inconsistent override identity: `build_genmodule_module.cmake` classified layer overrides by `NAME_WE`, while `_aros_resolve_module_sources` compared the complete base and override tokens. The repair above now addresses that mismatch with regression coverage; full CRT/runtime verification is separate.
- `CMAKE_BUILD.md` now separates prepared-tree native hosted commands and limitations from legacy wrappers. Keep that guide updated with subsequent structural/runtime changes, not just this checkpoint log.

## Immediate Hosted Boot Trace (2026-09-05)
- The user explicitly brought forward verbose console boot diagnostics to help the current migration investigation, without waiting for the full syslog/display port. ApolloOS remains untouched.
- `AROSBootstrap -v` / `--verbose` enables its existing startup diagnostics, module read/loading phases, and a focused default `sysdebug=Init,InitResident,InitCode,AddTask,RamLib,LoadSeg,AddDosNode` trace. Explicit command-line or configuration `sysdebug=` flags take precedence; runs without verbosity retain their existing quiet behavior.
- `rom/dosboot/bootdebug.h` makes existing `D(bug(...))` statements in DOSBoot initialization, DOS initialization, CliInit, boot-volume validation, and the generic DOS boot sequence available under the runtime Exec `Init` flag. It does not globally enable DEBUG or change explicitly enabled DEBUG builds; `NO_RUNTIME_DEBUG` remains respected. One statement-fragment `D(else ...)` was converted to a normal else block, and an existing diagnostic with a missing format argument was corrected.
- `aros-hosted-run-verbose` builds the current native boot modules, launcher/configuration, selected programs, and runtime data, then launches with `--verbose` from the native runtime root. This target does not imply that runtime packaging is complete. `aros-hosted-boot-trace-check` tests CLI help, both verbose spellings, preserved kernel arguments, explicit override precedence, quiet mode, and the private diagnostic macro's runtime/explicit/disabled behavior. Its launcher probes deliberately stop at a missing module before kernel execution.
- The rebuilt native launcher and modules pass those trace tests. A bounded 12-second verbose run now identifies the startup failure without GDB: `EMU:` mounts and locks successfully, but `__dos_IsBootable` cannot open `:AROS.boot` (DOS error 205). CliInit returns error 212, DOS initialization returns NULL, and DOSBoot reports no bootable disk before retrying every three seconds. This replaces the earlier ambiguous wait-state diagnosis with a concrete missing packaging prerequisite; it does not establish that no later boot failures exist.
- At this earlier checkpoint the native runtime root lacked `AROS.boot`; the later boot-signature checkpoint above resolves that failure through its manifest producer, not a manual file or copied legacy output.
- These requested diagnostic source changes intentionally change the bootstrap/DOS/DOSBoot binaries relative to the unmodified legacy reference. Legacy manifests are unchanged. Full-system binary parity, a usable hosted session, buffered early-message retention, and the matching in-OS syslog display are still unverified or unimplemented. The current implementation emits through the existing host/debug output paths only.
- Final native bootstrap/boot-module builds and `aros-hosted-boot-trace-check` pass; all 34 configured boot modules still load and relocate without execution. The following ordinary bootstrap/boot-module build reports `ninja: no work to do` without reconfiguration. A second bounded launch with `--verbose sysdebug=Init` confirms the explicit narrower override and the same missing-signature failure; its live console mirror is `/tmp/aros-hosted-verbose-boot.log`. Both verbose runtime probes stop at the intended 12-second SIGKILL limit, not at a successful boot.
- A final bounded run without verbosity emits only the original RAM allocation, kernel entry, and host-stack protection lines. No `AROSBootstrap` processes remain after these tests.

## Manifest-Driven Architecture (2026-09-05)
- The repository root `CMakeLists.txt` is explicitly allowed and remains the build setup/entry point. Shared OS/SDK translation and orchestration belong in `cmake/`.
- `tools/` may retain local `CMakeLists.txt` files; the user explicitly considers those appropriate for tools.
- Actual AROS OS and SDK targets must be generated from `mmakefile.src` by orchestration in the repository root and `cmake/`, without OS/SDK per-directory `CMakeLists.txt` files in the end state. This applies to target-side libraries/includes even where host-tool code shares a directory.
- Existing OS/SDK subsystem registrations are transitional, not an exception to that boundary; replace them with verified shared manifest-driven paths while preserving their outputs and dependencies. Do not merely move hand-maintained per-module target lists into another directory.
- Avoid hard-coded source-directory/module lists and duplicated upstream facts. Use `mmakefile.src`, its dependency/layer declarations, and other upstream metadata wherever they describe the behavior.
- Editing `mmakefile.src` must trigger CMake reconfiguration on the next ordinary build, not just rerun a custom compilation command with a stale graph. Adding/removing manifests, including in new top-level source directories, must also be discovered automatically.
- `cmake/AROSManifests.cmake` walks source directories without an allowlist, reads upstream `ignoredir` entries from `mmake.config.in`, skips hidden/symlinked directories and CMake build trees before descending, and tracks both directory inventories and manifest contents. It never runs MetaMake to discover files.
- `aros-manifest-reconfigure-check` uses an isolated Ninja fixture to check base/layer manifest edits, added/removed manifests, newly added top-level source directories, ignored build/cache inputs, and no-op builds.
- Hidden directories must be excluded from the glob inventory itself, not just skipped during descent: sandbox-created `.agents`/`.codex` directories otherwise cause spurious regeneration. The regression fixture covers added hidden state. Final unchanged `aros-hosted-modules-native` build reports `ninja: no work to do` with no reconfiguration, taking about 1.1 seconds in the active NFS checkout.
- Hosted runtime discovery now lives in `cmake/AROSHostedModules.cmake`: it selects genmodule producers from active arch manifests using the upstream boot configuration, then delegates dependency/include/layer handling to the shared module registry. The new UnixIO/emulation/X11 modules do not require per-directory CMake files.
- This initial target-discovery slice handles single unconditional genmodule producers. Multiple/conditional module declarations fail explicitly rather than guessing. Discovery is not yet a universal make-recipe translator: existing ROM/Workbench registration and target-program packaging remain migration work.

## Runtime Graph And Static Data (2026-09-05)
- `cmake/AROSMmakeRules.cmake` now translates reachable local static-file rules whose sole recipe is `$(CP) $< $@`, including `%mkdirs_q` prerequisites. Paths, conditional source selection, and dependency edges come from the manifest; the hard-coded X11 keymap-copy adapter has been removed.
- The rule reader preserves recipe boundaries instead of treating recipe lines as declarations. Unsupported reachable copy recipes, generated copy inputs, unsafe destinations, and unsupported prerequisite recipes fail explicitly. Interactive/unreachable recipes are not executed. This bounded support does not replace the program/module registry or interpret arbitrary make recipes or included recipe files.
- `aros-static-files-check` covers real Linux/Darwin X11 source selection, native copy outputs, source edits, manifest edits/new copy rules, missing-output recovery, no-op builds, cyclic metadata aliases, and rejection of unsupported recipes.
- All three native X11 keymap files match the existing workspace legacy copies byte-for-byte.
- `cmake/AROSRuntime.cmake` assembles runtime module sets from registered artifact paths, preserving configuration order and tracking native producer dependencies. Existing unowned files cannot satisfy the graph. Partial profiles can configure, but building an incomplete runtime set fails with the missing producer list.
- `aros-runtime-graph-check` verifies cross-directory producer lookup, nonstandard artifact names, ordered output lists, source rebuilds, missing-output recovery, no-op builds, and rejection of stale files without native producers.
- `aros-hosted-boot-modules-native` uses the upstream bootstrap configuration to select the complete boot module set. `aros-hosted-boot-load-check` extends the existing ELF loader test to that entire ordered set using non-executable buffers; it does not run the kernel.
- Verified: all 34 configured native boot modules load and relocate successfully. The single-kernel loader, hosted metadata, static-file rules, runtime producer graph, and manifest reconfiguration regression targets also pass through the active Ninja build.
- A subsequent build of `aros-hosted-boot-modules-native` and `aros-hosted-bootstrap-native` reports `ninja: no work to do`, with no CMake reconfiguration, using the same CLion CMake executable.
- A bounded native launcher run allocates RAM and enters the native kernel, but does not reach a usable AROS session within 15 seconds. Following the forked kernel child in GDB shows `Exec_53_Wait` through `core_SysCall` / `cpu_Dispatch` waiting in host `sigsuspend`; this is not evidence of a tight CPU loop or a proven packaging-only failure. The parent normally waits for that child in `waitpid`.
- The native runtime tree now contains the 13 self-starting `workbench-c-sh` commands in `C/` plus the startup-enabled `Devs/Monitors/X11` executable and icon. The five `S/` startup scripts are also staged natively (see the static packaging checkpoint below). Remaining commands/data and further runtime diagnosis are still required. Complete legacy independence and full-system parity have not been established.

## Static Packaging Checkpoint (2026-09-05)
- Manifest discovery now prefers `mmakefile.src`, falling back to plain `mmakefile` only when no sibling `.src` exists, matching MetaMake's source selection. This supports the upstream `workbench/s/mmakefile` without converting it or adding OS-local CMakeLists. Generated/build trees remain pruned by the existing inventory rules; an orphan plain makefile in a source directory is still a fallback candidate, not automatically classified as generated.
- `cmake/AROSStaticTargets.cmake` registers selected static-data entrypoints by metadata identity across the manifest inventory. Explicit `#MM` dependency names and aliases drive layer reachability; local declarations do not hide additional producers in other manifests. Absent metadata producers are optional, as in MetaMake, and an upstream-added producer becomes visible on an ordinary build.
- `aros-runtime-data-native` currently selects `workbench-s` through `AROS_NATIVE_STATIC_RULES`. This is a migrated-entrypoint profile, not a duplicated list of source files, output paths, or architecture directories. All five copy rules, their destinations, and the setup/arch prerequisites come from the unchanged manifest.
- The shared rule reader supports bare `#MM` before an ordinary rule, colonless metadata declarations, and the guarded `IF/TEST/MKDIR/NOP` directory-creation pattern. Static copies accept `$<` or `$^`; `$^` requires exactly one distinct normal source, with order-only setup prerequisites kept separate. Shell recipes are recognized as data, not executed through make or a general-purpose shell interpreter.
- The configure-time logical-line reader now preserves physical lines before assembling continuations. `file(STRINGS)` had folded them into semicolon-containing text, dropping continued `#MM` edges and distorting multi-line shell recipes. The separate build-time/layer readers have not been unified with this implementation; their behavior still needs auditing as migration expands.
- Strict static graph registration rejects unowned/generated copy inputs, unsupported prerequisite recipes/macros, conflicting output producers, and metadata cycles rather than silently adopting stale artifacts or dropping requirements. It does not yet translate included recipe files, arbitrary generated data, or macro-generated metadata edges. The older local static extraction used alongside native modules remains a separate bounded path and still supports its existing local alias closure.
- Isolated regression coverage includes plain-manifest edits and `.src` precedence/fallback, new top-level layer producers, active/inactive conditions, local aliases augmented across manifests, producer removal, continued metadata, setup-only directory recovery, copy/source edits, missing-output recovery, and no-op builds. Negative tests cover multiple `$^` inputs, stale generated inputs, escaped symlink sources, unsupported recipes/macros, cycles, and output conflicts.
- Verified in `cmake-build-debug`: `aros-runtime-data-native` builds the complete `S/` directory without MetaMake/make execution; recursive comparison with `legacy-main/bin/linux-x86_64/AROS/S` is byte-identical. Its next ordinary build reports `ninja: no work to do`. Full Ninja reconfiguration after these changes completed in 53 seconds.
- Next runtime packaging work includes the startup-enabled core command batch and its declared program/code-generation dependencies, plus remaining runtime data. Staging `Startup-Sequence` is not evidence that it can run successfully or that the hosted milestone is complete.

## Shell And Catalog Checkpoint (2026-09-05)
- The hosted default `AROS_NATIVE_PROGRAM_RULES` now also selects `workbench-c-shell`; previous default-valued caches are upgraded. Its sources, program flags, output `L/UserShell-Seg`, and DOS catalog dependency come from the unchanged upstream manifests. No OS/SDK per-directory CMakeLists were added.
- `cmake/AROSCatalogTargets.cmake` discovers literal `%build_catalogs` prerequisites by metadata identity and runs the native FlexCat tool directly. Defaults are read from `config/make.tmpl`; language lists, destination subdirectories, catalog names, and optional generated-source paths come from the manifest. Empty catalog lists use a configure-aware `.ct` inventory. The host-tool target publishes its source-description directory rather than requiring legacy-installed templates.
- The bounded translator preserves the macro's Russian conversion option and catalog warning-exit policy; header generation still requires exit zero. Generated filenames are passed unchanged because source templates can embed them. Failed generation removes invalid/stale outputs, and a successful exit without an output also fails the build.
- Catalogs require owned static `.cd`/`.ct` inputs and source descriptions (or native-tool templates). Unsupported arguments, reachable prerequisite recipes/dependencies, local input-generation rules, ambiguous producers/descriptions, escaped output paths, and conflicting static/catalog outputs fail explicitly. This is not arbitrary make-recipe execution, global generated-input discovery, or universal catalog-header integration into existing ROM/module consumers. The existing transitional DOS module header registration remains separate.
- `aros-catalogs-check` covers actual Ninja generation through a fixture tool, manifest/template edits, automatic language addition/removal (including dotted names), source/template rebuilds, missing-output recovery, no-op builds, warning/error exits, symlink escapes, stale legacy inputs, conflicting producers, and catalog dependencies through a target-program consumer. Catalog-only edits do not relink that program. Removing its catalog manifest fails despite existing outputs; adding the producer in a new top-level directory recovers on the next ordinary build.
- Verified native `L/UserShell-Seg`, all ten `Locale/Catalogs/*/System/Libs/dos.catalog` files, and `rom/dos/strings.h` are byte-identical to the existing workspace legacy reference. Shell text/data/bss are 26456/0/0. `aros-programs-native` succeeds, and the subsequent combined program/runtime-data/boot-module/bootstrap build reports `ninja: no work to do` without regeneration. The isolated program and catalog regression suites pass.
- A bounded launcher check with the new native shell still prints kernel entry and host-stack protection, then reaches the 12-second SIGKILL timeout (exit 137) without an observed usable session. A subsequent host process check finds no remaining `AROSBootstrap`. Missing shell packaging was not sufficient to fix startup; remaining startup commands/data and kernel/task initialization diagnosis remain on the critical path. Full-system parity and clean independence from legacy configuration/toolchain scaffolding remain open.
- CLion MCP resolves this checkout and exposes the hosted-bootstrap run configuration; no debug session was active during this check. The connected LM Studio review endpoint refused its connection, so it supplied no review findings. Syslog/ApolloOS remain untouched.

## Program Code Generation Checkpoint (2026-09-05)
- `cmake/AROSProgramCodegen.cmake` translates local compile prerequisites for selected `%build_prog` / `%build_progs` declarations, including the implicit `<mmake-name>_DEPS` / `_OBJS` lists. The configure-time variable expander now accepts hyphenated metadata variable names. Individual object/depfile edges stay source-specific; group edges reach the complete selected source set.
- The first supported generator is the declared `$(BISON) -o $@ $<` rule with one owned static grammar and one native object-directory output. `Eval.c` includes `evalParser.tab.c`; Ninja now owns its generation and orders it before compilation rather than adopting a parser from the legacy tree. There is no Eval-specific source/path inventory or OS-local CMakeLists addition.
- Recipe tool variables are late-bound after reading the manifest, unlike build-macro flag snapshots. The configured Bison executable and its discovered data files are tracked, with the data directory pinned for generation. Grammar includes also contribute native SDK-header producer dependencies. Failed generation, including success without an output, removes stale output and fails the build.
- This is deliberately bounded: included manifests/options for code-generation rules, implicit pattern generators, order-only compile prerequisites, multiple-output/alternate-skeleton/language Bison directives, generated grammar inputs, and arbitrary recipes still require native support. Unsupported reachable rules, cycles, conflicting producers, source/legacy output destinations, and symlink escapes are rejected.
- The hosted program profile now also selects `workbench-c-eval`, `workbench-c-requeststring`, and `workbench-c-adddatatypes`. Their sources, flags, generated inputs, and destinations come from the unchanged upstream manifest. All three actual native binaries (`C/Eval`, `C/RequestString`, `C/AddDataTypes`) are byte-identical to the workspace legacy copies. The combined selected-program/runtime-data/bootstrap build and 34-module non-executing relocation check pass.
- `aros-program-codegen-check` exercises actual Bison and compiler execution under Ninja, grammar edits, missing-output recovery, no-op builds, per-source/group dependency selection, native headers referenced only by the grammar, late-bound tool selection, and the rejection/cleanup cases above. The existing target-program regression also passes after integration.
- These helper programs are prerequisites of the larger `workbench-c` batch, not a substitute for migrating that batch's complete metadata graph (including program children, optional architecture aliases, and runtime module prerequisites). Remaining startup commands/data and diagnosis beyond kernel entry stay on the critical path. Clean legacy independence and a usable hosted session remain unverified.
- Final combined verification in the active CLion/Ninja build passes: selected native programs, runtime data, bootstrap, all 34 boot-module relocations, program codegen, program/startup/icon and linklib regressions, catalogs, static-file rules, and manifest reconfiguration. The following ordinary program/data/boot-module/bootstrap build reports `ninja: no work to do` without regeneration (about 0.9 seconds). Final `C/Eval` remains byte-identical after the generator dependency refinements.
- A read-only GDB snapshot at the first host `sigsuspend` shows an empty `TaskReady` list and waiting tasks including Exec housekeeper/Guru, X11, input, console, EMU, Intuition handlers, and Exec Bootstrap Task. The library list includes `dos.library`, `intuition.library`, and `x11gfx.hidd`. This is an early-wait snapshot, not proof of a permanent deadlock or a usable session. GDB was terminated after inspection and no `AROSBootstrap` processes remained. Further startup diagnosis must not assume that packaging is the only problem.

## Manifest Option Ordering (2026-09-05)
- The hosted aggregate rebuild exposed duplicate `Utility_66_SetMem` definitions: the generic implementation was selected alongside the SSE implementation. `arch/x86_64-all/utility/make.opts` defines `USE_SSE_COPYMEM`; its manifest conditionally selects an intentionally empty architecture `setmem.c` to replace the generic source. Applying those options only at compilation time loses this source-selection behavior.
- The shared build-time manifest interpreter now reads active `.opts` includes at their declaration point, before subsequent conditionals, assignments, and build-rule snapshots. Required missing option files and recursive includes fail explicitly; optional missing includes remain allowed. Generated configuration retains its separate reader; this is not general included-makefile recipe execution.
- Included option files are published as parsed inputs and tracked by the host/program collectors. An ordinary program build after editing an included options file reconfigures CMake and rebuilds with the updated flags. The real utility-layer fixture verifies selection of the empty override, and a synthetic fixture verifies ordered multiple includes and isolation from later flags.
- The interpreter queues numeric line identifiers instead of mutable line-text lists. CMake list mutation otherwise unescapes semicolons preserved by the existing logical-line reader and corrupts continued macro arguments. Hosted/module metadata, program rebuild, and kickstart regressions pass with this representation. Full hosted aggregate verification after the options and layer-flag fixes passes as recorded below.
- The next rebuild exposed the previously noted layer-flag subtraction bug in Exec assembly: removing each base USER token separately stripped shared `-isystem` options but left unrelated SDK include paths as bare input files. The compiler rejected `execstubs.s` with the multiple-input `-o` error. The shared module compiler now constructs base and layer argument lists from their respective inputs instead of subtracting tokens; it also preserves global flags that happen to equal base flags. The metadata fixture checks option/operand integrity and base/layer isolation. A direct replay of the complete Exec compilation now succeeds without those unused-input warnings.
- A direct utility compile/link replay now succeeds too. The architecture `setmem.o` has no defined symbols, while `setmem_sse.o` owns `Utility_66_SetMem`. Native and workspace legacy utility text/data/bss sizes match at 16568/0/8; the files differ in 17 bytes, so strict byte parity is not claimed.
- Retaining complete common options also exposed incorrect layer include ordering in the kernel: source-local include flags had been appended after global/base include directories, selecting `rom/exec/exec_platform.h` instead of the hosted override. The shared compiler now merges source-local include search options ahead of common options, retaining option/operand pairs and declaration order; other source-local flags remain last so they can override compiler defaults. Regression coverage checks both precedence rules, and a direct replay of complete kernel compilation succeeds. Exec and the hosted drivers also passed the preceding aggregate's compilation phase.
- Runtime inventory also lacks `L/UserShell-Seg`. Its upstream producer is `workbench-c-shell` in `workbench/c/Shell/mmakefile.src`, including the declared DOS catalog prerequisite. Migrate that producer and dependencies through the shared graph rather than copying a legacy shell to make the native runtime appear complete.
- Final verification: the combined `aros-runtime-data-native`, `aros-programs-native`, `aros-hosted-boot-load-check`, and `aros-hosted-bootstrap-native` build succeeds. All 34 boot modules load and relocate without execution. Replacing the always-run load check with `aros-hosted-boot-modules-native` in the next invocation reports `ninja: no work to do` without regeneration. The successful log mirror is `/tmp/aros-hosted-verified-rebuild.log`; it contains neither compile errors nor the former unused-linker-input warnings. Math attribute and HIDD macro-redefinition warnings remain non-fatal.
- Final targeted parity preserves byte-identical `S/`, `Devs/Monitors/X11`, and `Development/lib/startup.o`. Kernel text/data/bss remain 157823/144/1064, matching the workspace legacy image, and utility retains the 17-byte difference noted above. Full-system strict parity is still open.
- A bounded native launch enters the kernel and prints its host-stack protection message, but no AROS window or usable session was observed. A repeat with verbose timeout diagnostics is terminated by the 10-second limit (exit 137); a subsequent process check finds no remaining `AROSBootstrap` process. This is a boot-progress checkpoint, not milestone completion or proof that missing packaging is the only startup problem. Keep shell/startup packaging and further runtime diagnosis on the critical path.

## Target Program Migration (2026-09-05)
- `cmake/AROSProgramTargets.cmake` discovers selected `%build_prog` / `%build_progs` entrypoints from the manifest inventory. `AROS_NATIVE_PROGRAM_RULES` selects migrated entrypoints, initially `workbench-c-sh`; program names, sources, flags, output directories, and explicit prerequisites are read from `mmakefile.src`, not copied into CMake lists. No new OS/SDK per-directory CMakeLists are needed for these programs.
- `aros-programs-native` builds the selected target-OS programs using direct compiler/linker/strip commands owned by Ninja. This is distinct from the host-program primitive. It supports self-starting C programs (`usestartup=no`) and the bounded manifest-driven startup-object path described below. C++/assembly programs, instrumentation, debug sidecars, and unowned generated sources fail explicitly rather than silently using legacy artifacts or dropping requirements.
- Program linking retains the compiler's default library semantics and manifest `-nostartfiles`/`-noclibs` settings. It does not inherit the resident-module linker flags. Native headers, native SDK library directories, and a native sysroot are passed explicitly; the reusable compiler itself still comes from the existing toolchain. Link maps validate loaded archive paths against the native SDK, allowing only the compiler's own `libgcc` outside it. An external-shadowing regression verifies that fallback archives are rejected and invalid outputs removed.
- Program archive dependencies now come from GCC's non-executing `-###` link command for the selected manifest flags, rather than an all-SDK aggregate or a copied default-library list. Each requested archive requires a native producer; the compiler's own `libgcc` is tracked separately. Existing linklib builders still carry broader ROM-interface prerequisites and legacy config/sysroot coupling.
- Unregistered program libraries are discovered from unambiguous literal `%build_linklib libname=...` declarations in the manifest inventory and built through the shared linklib primitive. This discovers `mui` and `codesets` without per-library registration lists. Ambiguous or undiscovered producers fail explicitly.
- The linklib parser now shares `addprefix`/`addsuffix` expansion with the module/host/program parser. The discovered codesets linklib uses these expressions for its external source paths; literal unresolved `$(addprefix` must not be treated as a source basename.
- Generic linklib commands publish combined GCC depfiles, including all compiled sources/headers and explicit object inputs. An isolated Ninja fixture verifies external source/header edits, multiple compilation units, missing archives, and no-op builds; `aros-programs-check` runs this check too.
- Codesets currently compiles from an already-extracted source cache in the existing build. Native fetching/patching of `%fetch` inputs remains unimplemented; reusing that source is an incremental checkpoint, not a clean independent build. No legacy archive is copied to satisfy its producer.
- The installed configuration expresses `PORTSDIR` through `TARGETDIR` and `TOP`; legacy Makefile supplies `TOP` outside those configuration files. The linklib interpreter now supplies the configuration/build root explicitly instead of silently producing `/bin/<target>/Ports`. The fixture exercises that expansion. Other build-time interpreter contexts still need the same audit as external-source migration expands.
- Program compilation follows registered header-interface producers as well as explicit `#MM` prerequisites. Source include changes and compiler/specs changes trigger graph refresh; library files and interface stamps drive relinks. Compiler specs edits also relink when the library names are unchanged.
- A clean configure can precede compiler installation. Program targets fail with an explicit bootstrap prerequisite until the target compiler is installed; a configure-aware compiler-path inventory activates the real program graph on the next ordinary build. Single-command clean toolchain bootstrap plus full system build remains migration work.
- The program tests cover multiline/bare/quoted arguments, selected-rule flag isolation, default and multi-object sources, actual compile/link/strip, config and manifest reconfiguration, new program discovery, SDK-header rebuilds, archive-only relinks, missing outputs, no-op builds, and unsupported-input diagnostics. The isolated Ninja regression passes, as does the existing hosted/module metadata regression.
- Verified: `aros-programs-native` builds all 13 manifest-selected `workbench-c-sh` commands into native `AROS/C`, plus `hosted-X11-monitor` and its icon, using directly built SDK objects/linklibs. The following ordinary Ninja build reports `no work to do` without CMake regeneration.
- Targeted parity against the existing workspace legacy tree: `Assign`, `Beep`, `Copy`, `GfxControl`, `SetKeyboard`, and `WaitX` are byte-identical. `AROSMonDrvs`, `BindDrivers`, `Debug`, `Dir`, `LoadWB`, `Play`, and `Print` each differ in exactly three bytes, all within the embedded build date (`05.09.2026` vs `12.03.2026`). Text/data/bss sizes match for all 13. This is not fresh full-system parity or runtime execution validation.
- A usable hosted session and complete runtime packaging remain unverified. Next extend native support for remaining commands and startup data, then retest and diagnose hosted startup. Do not treat the selected command/monitor slice as completion of the first milestone.
- During verification, `build.ninja` was regenerated and `.ninja_log` compacted while our Ninja invocation was still running, without a configure command from the agent. Later completed interface steps were absent from the active log and rebuilt unnecessarily. CLion auto-reload is a suspected source, not a confirmed process attribution. The final retry kept the graph stable, recorded matching timestamps, and passed the ordinary no-op check. Avoid concurrent regeneration/builds in this shared directory.
- Refreshing all SDK interfaces exposed an existing source-resolution error: interface-only genmodule builds were requiring runtime implementation sources. The shared builder now resolves those sources only for runtime builds, while still requiring actual link-stub sources. Expat and FreeType interface generation now passes this previously failing step. Their full runtime/source-fetch migration is not established by that check.
- The shared build-time parser now expands `addprefix`/`addsuffix` word lists, including nested and empty lists, with regression coverage. This handles manifest-derived interface include flags without a FreeType-specific workaround.
- The earlier all-SDK program dependency also reached an unrelated utf8proc interface rejected by the current genmodule (`forcebase PosixCBase`). Narrowing program dependencies removes that unrelated producer from this build; it does not establish utf8proc migration or change its legacy source.
- Additional passing program regressions cover compiler-default library producer selection, unrelated failing SDK targets remaining unreachable, specs edits, generated header-only interfaces, and compiler installation after initial configuration. No working hosted-session claim follows from these isolated tests.

## Hosted Module Findings (2026-09-05)
### Startup And Icon Translation Checkpoint
- Program startup is no longer rejected unconditionally. GCC's non-executing link probe discovers startup/end objects in addition to default archives; each object requires a native manifest producer. `-B<native-sdk-lib>/` selects those objects, and link-map validation rejects unowned object inputs as well as archives outside the native SDK.
- `cmake/AROSMmakeObjects.cmake` supports a bounded standalone SDK-object pattern: an explicitly declared output, a single `$(CP) $< $@` pattern rule, and a target-C `%rule_compile` producer using an owned source. It captures compile options at the rule, not after later `USER_*` assignments. C++/Objective-C and arbitrary generated-object recipes remain unsupported; this is not yet a full implicit-rule or layered-startup translator.
- `cmake/AROSIconTargets.cmake` discovers selected `%build_icons` prerequisites and runs native `ilbmtoicon` directly. Icon names, destination, metadata/image inputs, and optional shared image come from the manifest. No OS/SDK per-directory CMakeLists were added for startup objects, the X11 monitor, or its icon.
- The hosted default program entrypoints now include `hosted-X11-monitor` alongside `workbench-c-sh`; old default-valued caches are upgraded. This is a migrated-entrypoint profile, not a copied source/output inventory.
- `%build_module` implicitly publishes `<mmake-name>-includes`, even when no explicit `#MM` declaration appears. Interface registration now uses the selected manifest mmake name rather than inventing only `kernel-<module>-includes`; the X11 monitor exposed this omission.
- Make condition arguments must be split with balanced nested calls and preserve empty operands. The shared equality path and `findstring` expansion now handle conditions such as `ifneq (,$(findstring arm,$(AROS_TARGET_CPU)))` without treating the nested comma as the comparison separator.
- GCC 10 checks input existence even for `-###`; the probe now uses an empty, never-linked `.o` placeholder so compiler-generated temporary object names are not mistaken for startup inputs.
- START LEGACY: configured icon-set/theme/bootloader values currently exist as exported assignments in the generated top-level Makefile rather than the cfg files. The CMake configuration reader imports those assignments without running any recipes; program configuration tracks that file for changes. Native configuration generation still needs to replace this bridge. END LEGACY.
- Isolated program tests now cover compiler-selected startup compilation, header/source/manifest rebuilds, missing-object recovery, stale-output rejection after producer removal, rejection of external startup paths, generated startup header dependencies, and icon-only rebuilds without program relinking. Unsupported explicit SDK-object constraints and generated icon inputs are rejected rather than silently ignored/adopted; differing overlapping object patterns remain unsupported. Exported icon configuration edits reconfigure and select the new producer without relinking the program. The host/module metadata, linklib depfile, static-file, manifest-reconfiguration, runtime-graph, and kickstart checks also pass.
- The linklib interpreter must snapshot `USER_CPPFLAGS`, `USER_INCLUDES`, `USER_CFLAGS`, and `USER_AFLAGS` at the selected `%build_linklib` declaration, and clear optional macro arguments between declarations. Previously the later `stdc-static` flags leaked into `crtprog`, including `-fno-builtin`, changing `abort.o` from legacy `.text.unlikely` to `.text`. The shared fix has a regression with earlier explicit arguments and later USER flags/includes, covering C and assembly compilation.
- Verified native versus workspace legacy: `Devs/Monitors/X11`, `Devs/Monitors/X11.info`, and `Development/lib/startup.o` are byte-identical. All 12 `libcrtprog.a` members are byte-identical; the 17942-byte archives match after normalizing only archive-member timestamps. Rebuilding the complete selected-program aggregate preserves the 13 command parity results above. Existing math attribute and CRT noreturn warnings remain non-fatal; this checkpoint is not a usable hosted-session claim.
- The subsequent static packaging checkpoint above implements `workbench/s/mmakefile` discovery and its copy/setup graph without a hard-coded `S/` file inventory.

- `aros-arch-hostlib-native` builds successfully. Native and workspace legacy hostlib text/data/bss sizes match at 7036/0/8; strict full-system parity remains open.
- Entire modules can request host libc headers through `USER_INCLUDES=$(KERNEL_INCLUDES)`, not only individual architecture-layer source files. The shared genmodule compile path must preserve that intent for base/generated sources too, demoting the AROS SDK behind host headers instead of mixing host `sys/types.h` with target `fcntl.h`/`errno.h`.
- `%build_module` output identity includes `modsuffix` and `moduledir`, not just `modtype`. The hosted emulation handler is a resource with handler suffix in `boot/linux/L`; native metadata now preserves those explicit overrides.
- Nested layer resolution already reaches `arch/all-unix/filesys/emul_handler` via the generic alias resolver. Do not replace that with hand-wired source overrides.
- The configure-time config reader must handle indented conditional assignments, such as `AROS_DIR_ARCH` in `config/make.cfg`. It now evaluates only enclosing conditions, handles conditional defaults without recursive lookup cycles, and caches unexpanded logical lines by content hash. Hard-coding `boot/linux/L` would only have hidden the original `boot//L` expansion bug.
- Verified: `aros-hosted-modules-native`, `aros-hosted-metadata-check`, and `aros-manifest-reconfigure-check` all build/pass through the active Ninja graph. The module aggregate builds hostlib, UnixIO, emulation, and X11 from the discovered manifest producers. Full-project reconfiguration completed in 47 seconds in this NFS checkout.
- Native versus workspace legacy text/data/bss sizes match for UnixIO (16008/128/40), emulation (32230/272/16), and X11 (63448/2608/1096). These are section-size checks, not strict binary parity or a working hosted session.
- Remaining warning: compiling the emulation layer reports its base directory as an unused linker input. The shared layer-flag subtraction removes standalone option tokens without treating all option/argument pairs atomically; investigate that generic behavior rather than patching the emulation manifest.
- Runtime packaging still needs remaining `C/` commands beyond the self-starting subset and further data. The generic paths now stage `S/` startup scripts, X11 keymaps, the monitor executable, and its icon. Shared include/config generation and the compiler/sysroot remain legacy-coupled; do not report the hosted milestone complete yet.

## Current Checkpoint (2026-09-04)
- The March verification notes below are historical. The previous `/tmp/aros-legacy-reference-linux-x86_64` tree is no longer present; full-system parity has not been re-established in this session.
- The current `aros-output-parity-compare` implementation still defaults its candidate to `legacy-main/bin/<target>/AROS` and depends on the legacy AROS wrapper. Before using it to validate the hosted milestone, wire its candidate and build dependency to the native hosted output/aggregate. Until then, use explicit native paths for targeted comparisons; the existing target is not evidence of native system parity.
- The reported `muiscreen` missing `libraries/mui.h` failure exposed an unmodeled generated SDK input. MetaMake produces it with `workbench/libs/muimaster/buildincludes.c`, not a plain source-header copy.
- CMake now builds that host tool and uses the shared stdout-to-file helper with `WORKING_DIRECTORY` support. `aros-generated-includes-native` collects generated SDK inputs before native include staging, with both target ordering and file dependencies for rebuilds.
- Generated SDK headers live under `native-generated-includes` and are staged after legacy snapshot inputs so the CMake-produced header wins. Header producers register independently of runtime-module migration.
- Verified: `aros-native-includes` succeeds and both the generated and staged `libraries/mui.h` match the existing workspace legacy header byte-for-byte (SHA-256 `3ce56429e31cfe5ee45d081f186d7d53e283e768d07bccb9abacda8f72f962a9`). This does not establish muimaster runtime or full-system parity.
- The originally failing `muiscreen_regcall_stubs.c` passes a target-compiler syntax check with `-nostdinc`, using only native-staged headers and GCC built-ins, without legacy SDK header fallback.
- Verified: `cmake --build cmake-build-debug --target aros-workbench-libs-complete-native -j 6` completed successfully, including `muiscreen.library` and `identify.library`. This refreshes the active native artifacts discussed as stale in the historical notes below; it does not establish a legacy-independent system build.
- Targeted comparisons against the workspace legacy outputs show matching sizes for `uuid`, `identify`, `muiscreen`, `rexxsupport`, `kms`, and `reqtools`. The first three have 16-18 differing bytes, with version dates now `4.9.2026` versus `12.3.2026`; the latter three retain substantial same-size multi-byte drift. Strict binary parity remains unverified.
- The follow-up incremental build restarted host compilation after the shared build directory was regenerated with CLion's CMake instead of `/usr/bin/cmake`; that redundant build was stopped. Full-aggregate no-op behavior has not been established. Avoid IDE regeneration or competing builds while validating one build tree, and use a consistent CMake executable/profile.

## Hosted Bootstrap Checkpoint (2026-09-04)
- `aros-hosted-bootstrap-native` builds native `gen/lib/libbootstrap.a`, `AROS/boot/linux/AROSBootstrap`, and `AROSBootstrap.conf`. `AROS_BUILD_HOSTED_BOOTSTRAP` controls registration, defaulting on for the supported native Linux x86_64 host/target combination.
- `cmake/AROSMmakeBuild.cmake` now contains the shared build-time manifest parser formerly embedded in `build_genmodule_module.cmake`. The hosted collector runs it in an isolated CMake process, preserving the existing configure-time module registry's separate context.
- The new host-target primitive reads `%build_prog` / `%build_linklib` C rules and active `%build_archspecific` sources from upstream manifests, then emits real CMake object/library/executable targets. Linux overrides unix `preboot.c`; base objects precede the sorted architecture object set. It does not run MetaMake or GNU make to build these artifacts.
- Hosted objects follow registered header-interface producer dependencies without inheriting target-libc include precedence. File-level dependencies on generated-header stamps ensure regeneration recompiles consumers in the same invocation, rather than relying only on ordering edges. The existing shared include/config generation path still has legacy dependencies, so this checkpoint is not yet a clean, legacy-independent hosted system build.
- Shared parser fixes preserve literal quotes in compiler `-D` arguments and snapshot empty flags at the selected build rule, avoiding contamination from later rules (notably `linklibs-bootstrap32`'s `ELF_64BIT`). CMake host compile options group flag/path pairs so repeated `-isystem` arguments survive de-duplication.
- Validation: the hosted aggregate builds; `AROSBootstrap --help` exits successfully and matches legacy output with the same `argv[0]`; the generated configuration matches legacy byte-for-byte. An earlier subsequent Ninja invocation reached `no work to do`; final no-op behavior after the header-dependency changes remains unverified because unrelated targets outside the hosted aggregate's graph wrote to the shared Ninja log during verification. Pause competing builds/regeneration or use an isolated build tree before repeating that check.
- Targeted parity: after stripping debug/compiler metadata, the native `elfloader` archive member matches the workspace legacy member byte-for-byte. The unnormalized launcher is 77712 bytes versus legacy 57008, with text/data/bss sizes 19127/1336/5296 versus 18769/1336/5296. Native uses host GCC 16, the existing legacy executable GCC 15.2; launcher binary parity remains open, not merely date drift.
- Regression checks: `cmake --build cmake-build-debug --target aros-hosted-metadata-check`, or `cmake -DTEST_BINARY_DIR=/tmp/aros-host-metadata-test -P cmake/tests/mmake_host_metadata.cmake`. These cover source overrides, quoted macros, per-rule/layer flag isolation, existing genmodule parsing, and host include-option grouping.
- Running the launcher from the native AROS tree allocates RAM and stops with `Failed to open file kernel!`. Next implement `%link_kickstart` using native kickstart objects (kernel startup, exec, task), then the remaining configuration-listed drivers/runtime files. A usable AROS session has not yet been reached; `--help` is only a launcher smoke test.

## Hosted Kernel Checkpoint (2026-09-04)
- `aros-hosted-kernel-native` now builds `bin/linux-x86_64/AROS/boot/linux/kernel` through CMake-owned compilation and linking. `%link_kickstart` metadata comes from the unchanged `arch/all-unix/boot/mmakefile.src`; no MetaMake/make invocation is used to link the image.
- Genmodule compilation now emits a shared link manifest, with separate runtime-module and `-kobj` link targets. Both reuse the same compiled sources. Hosted kernel linking consumes native `kernel_resource.o`, `exec_library.o`, and `task_resource.o`, rather than standalone resident modules or copied legacy objects.
- Kickstart objects omit the standalone resident entry and runtime-only weak markers, use `collect-aros -Ur` to generate symbol sets, and localize the legacy library-base/set symbols while leaving `SysBase` external. Final kickstart linking keeps the manifest's startup/module ordering and legacy GCC autolib semantics; it must not substitute a freestanding `-nostdlib` link.
- Kobject targets track native archive producers and generated-interface stamps. Deferred kickstart commands have a same-directory file consumer so Ninja emits their output rules correctly. Collected kickstart metadata uses copy-if-different to avoid unnecessary relinking on configure.
- Verification: the native kernel is ELF64/x86-64, AROS ABI 11, relocatable, with `SysBase` as its only undefined symbol. Its text/data/bss sizes match the workspace legacy kernel exactly: 157823/144/1064. All three constituent kobjects also match legacy section sizes.
- Strict kernel byte parity is not established. A confirmed source of layout drift is legacy `$(wildcard .../arch/*.o)` locale collation: under the current `en_US.UTF-8`, `kernel_cpu.o` and `kernel_intr.o` precede `kernel.o`, whereas CMake's existing source sorter places `kernel.c` first. Preserve deterministic native ordering while accounting for the reference build's locale when investigating parity; do not hard-code a kernel-specific reorder. Version dates also differ from the existing reference.
- `aros-kickstart-check` tests hosted manifest ordering, conditional/bare-list arguments, and actual binutils symbol localization. `aros-hosted-kernel-load-check` uses the native ELF loader to allocate and relocate the native kernel with non-executable buffers; it deliberately never calls the entry point. Both pass, as does the existing `aros-hosted-metadata-check`.
- Unsupported nonempty `map`, `packfmt`, `strip`, and `deps` kickstart arguments fail explicitly, with regression coverage, rather than silently dropping upstream requirements. These modes still need native implementation when a target requires them.
- Final incremental verification of `aros-hosted-kernel-native` plus `aros-hosted-bootstrap-native` reports `ninja: no work to do` using the same CLion CMake executable. The focused runtime regression also rebuilt `muiscreen.library` successfully after the compile/link split. This is not a full-Workbench or full-system no-op/parity check.
- The loader check also passes against the workspace legacy kernel. A normal native launcher attempt now allocates RAM and stops at `Failed to open file hostlib.resource!`, replacing the previous missing-kernel failure. The first milestone remains incomplete.
- A broader runtime-link check exposed `aros-rom-task-native` failing on `TaskGetStorageSlot`. That internal symbol resolves from exec when task is linked into the hosted kernel; standalone task linkage remains unresolved and must not be papered over with weak stubs or legacy source edits. Runtime exec and kernel links succeeded.
- This remains an incremental migration checkpoint: shared config/include generation and the reusable compiler/sysroot still have legacy dependencies. A clean legacy-independent hosted build, complete runtime packaging, actual kernel execution, and full-system parity are still outstanding.

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
  - Native module registration parses legacy-style mmake/config metadata during CMake configure, so CMake must synthesize a small bootstrap config surface itself before any native module registration runs.
  - Current CMake-side bootstrap snapshot writes `config/make.cfg`, `gen/config/target.cfg`, `gen/config/build.cfg`, and `gen/config/compiler.cfg` under `legacy-main` without invoking legacy `./configure`.
  - That snapshot is only for CMake-time metadata consumption; the real `aros-configure` build target still runs legacy `./configure` later and replaces it with the full historical outputs (`Makefile`, `config.status`, `mmake.config`, `conf.cmake`, `make.defaults`, and the rest).
  - `_aros_get_target_context()` and the layering helpers should prefer the CMake-derived `AROS_TARGET_FAMILY` when available and tolerate a missing real `target.cfg` instead of hard-failing the whole CMake configure.
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
- After all ROM modules are migrated, refactor [`rom/CMakeLists.txt`](/home/marlon/nfs/storage/projects/amiga/aros/rom/CMakeLists.txt) into a cleaner structure. The current file is transitional and should not remain as a long-term dumping ground for per-module registration clutter.
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
- Current IDE/target naming rule:
  - any CMake target that launches the legacy MetaMake/GNU make pipeline must be named with a clear `mmake-` prefix
  - native CMake targets keep their native names (`aros-*-native`, normal tool targets, etc.) so IDE target lists clearly separate native and legacy/wrapper entrypoints
- Current clean-build/native-include staging finding:
  - on a clean Ninja build directory, `AROS_TARGET_CC` may still be empty at CMake generate time even though the crosstools target will later provide the compiler
  - native include staging must therefore resolve the target compiler at execution time from the toolchain dir/prefix instead of assuming the configure-time `AROS_TARGET_CC` value is already populated
  - concrete case: CLion/Ninja clean builds were failing in `stage_native_includes.cmake` while generating `asm.h`; the shared fix is to pass toolchain dir/prefix and let the staging script find `${triplet}-gcc` itself
- Current clean-build genmodule-export finding:
  - `run_genmodule_exports.cmake` must precreate the include subdirectories that `genmodule writeincludes` writes into on a clean tree
  - the shared required set confirmed so far is: `proto/`, `inline/`, `defines/`, `clib/`, and `interface/`
  - concrete case: clean CLion/Ninja builds were failing in `aros-rom-kernel-clocksource-exports-native` because `proto/clocksource.h` could not be opened when only the root export dir existed
- Current clean-build native runtime-order finding:
  - late-bound native module ordering must be resolved only against real genmodule public-linklib producers discovered after registration order settles
  - do not use autolibs, target C libs, or ordinary native linklib targets to create owner-target dependencies in the finalizer; that creates artificial cycles through the SDK/interface aggregate graph
  - SDK-only registrations (`*-sdk-native`) must stay out of this runtime-order pass entirely
  - concrete case: clean CLion/Ninja builds were failing in `aros-rom-aros-native` with `x86_64-aros-ld: cannot find -lexec` because `rom/aros` registered before `rom/exec`; the shared fix is to add a late dependency only on the `exec` genmodule producer, not on the wider archive/autolib universe
- Current clean-build native archive-order finding:
  - native module archive dependencies must be modeled as file-level dependencies on the produced `.a` archives, not target-level dependencies between the owning utility targets
  - using utility-target dependencies for genmodule/public/`_rel` archives creates artificial SCCs in CMake (`graphics`, `utility`, `intuition`, `hyperlayers`, workbench SDK producers) and then file-level cycles in Ninja
  - the shared fix is:
    - late-resolve archive outputs after registration settles
    - feed only archive file paths into the runtime custom-command dependency set
    - keep genmodule/public/`_rel` archive target names out of the runtime target graph
- Current genmodule ownership finding:
  - public and `_rel` genmodule linklib archives must belong to the interface phase, not the runtime module phase
  - the interface custom command should publish those archives as byproducts, and `build_genmodule_module.cmake` should emit them in `INTERFACE_ONLY` mode
  - the runtime module custom command must no longer own those archives as byproducts; otherwise clean builds create cross-module archive cycles such as `libgraphics.a -> libutility_rel.a -> libintuition.a -> liblayers.a -> libgraphics.a`
- Current MetaMake source-list parsing finding:
  - `%build_module files=` parsing must sanitize directory-marker tokens like `classes/` out of source file lists
  - concrete case: `workbench/libs/muimaster/mmakefile.src` uses `CLASSFILES := $(foreach f, $(CLASSES), classes/$(f))`; the current parser was leaking bogus `classes/` entries into `MODULE_MMAKE_PARSED_FILES` on a clean tree
  - the shared sanitizer now drops trailing-slash directory markers from `%build_module`, `%build_archspecific`, and `%rule_*` source basename lists before source resolution
- Current clean-build verification state in `/tmp/aros-clean-build-reuse`:
  - with `-G Ninja`, `AROS_CROSSTOOLS_NATIVE=OFF`, and a reused working toolchain install, the fresh clean tree now builds:
    - `aros-rom-graphics-native`
    - `aros-rom-utility-native`
  - that clean tree also now gets through the broad native interface graph for ROM/workbench dependencies without the earlier failures on:
    - missing `oop/oop.h`
    - missing `hidd/compositor.h`
    - archive dependency cycles through `libgraphics.a`
    - bogus `classes/` source entries from `muimaster`
- Current no-op rebuild finding:
  - the reintroduced "always rebuild" behavior on settled native targets was caused by modeling genmodule public/`_rel` archives as declared interface byproducts and as direct runtime archive-file deps
  - many modules do not actually emit a public archive in `INTERFACE_ONLY` mode, so declaring those archive paths as byproducts keeps Ninja considering the interface rules dirty forever
  - the shared fix is:
    - do not declare genmodule public/`_rel` archives as interface byproducts
    - order genmodule module-to-module archive dependencies through the provider interface stamp instead of the archive file path
  - verified result on the clean tree:
    - `ninja -C /tmp/aros-clean-build-reuse -d explain aros-workbench-libs-gadtools-native` now reports `no work to do` apart from normal `VerifyGlobs.cmake_force`
- Current IDE/public-target naming rule:
  - enable `USE_FOLDERS` and group native/public targets under `aros/...` while pushing migration/internal implementation targets under `aros/internal/...`
  - keep legacy wrapper targets visibly prefixed as `mmake-*`
  - expose human-facing native artifact targets as `<name>.<type>` (for example `exec.library`, `graphics.library`, `keyboard.device`)
  - expose standalone linklib/native dependency targets with short names where possible (for example `amiga`, `arossupport`, `autoinit`, `libinit`)
  - CMake `INTERFACE` targets can carry the short dependency names for authoring, but they are not independently buildable Ninja targets; that is a CMake limitation, not a graph bug
- Current bootstrap-snapshot finding:
  - the clean-tree bootstrap `compiler.cfg` must provide a broad compiler flag surface, not just a placeholder file
  - missing `compiler.cfg` entries were causing clean native builds to silently drop mmake-derived flags such as `CFLAGS_NO_BUILTIN`, `CFLAGS_MERGE_CONSTANTS`, and the `NOWARN_*`/`WARN_*` family
  - concrete clean-tree regression caused by this: `libstdc.static.a` was being rebuilt with the wrong codegen, which then propagated into `graphics.library`
  - the bootstrap snapshot now versions its state so existing build dirs regenerate when the snapshot schema changes
- Current config/archive dependency finding:
  - native linklib and genmodule custom commands must depend on real config metadata files:
    - `config/make.cfg`
    - `gen/config/target.cfg`
    - `gen/config/build.cfg`
    - `gen/config/compiler.cfg`
  - without those file deps, refreshing the bootstrap snapshot leaves stale native archives and modules in place even though the build settings changed
  - archive consumers must also depend on real produced `.a` files for true archive producers, not only on interface stamps
  - the correct mixed model is:
    - interface stamps for interface-generation ordering
    - real archive file deps for real archive producers (`linklibs-*`, genmodule public linklibs, genmodule `_rel` linklibs)
- Current clean-tree parity state after the no-op fix:
  - `utility.library` from `/tmp/aros-clean-build-reuse` matches the legacy reference in size (`29600`) and is back in the ordinary byte-diff class rather than a structural size regression
  - `graphics.library` from `/tmp/aros-clean-build-reuse` now matches the legacy reference in size (`211088`) and, after a fresh direct module rebuild, is down to a single byte diff in the normal `$VER:` date-drift class
  - `gadtools.library` still has no matching artifact in the current legacy reference tree, so there is still no parity compare for it
- Current native include-staging finding:
  - the flat native include root must mirror the legacy SDK header surface, not just copy trees opportunistically
  - a concrete failure was `native-includes/stdio.h` incorrectly resolving to `dos/stdio.h`, which broke `udis86` consumers because `FILE` was not defined
  - the correct root publication order is legacy-like C runtime first (`aros/stdc`), then POSIX fallbacks (`aros/posixc`), with only explicit historical DOS root aliases such as `dos.h`
- Current verified native ROM state in `cmake-build-debug`:
  - the current package-base native ROM/workbench surface builds in one serialized Ninja pass for:
    `aros`, `battclock`, `bootloader`, `disk`, `dos`, `dosboot`, `exec`, `expansion`, `filesystem`, `filesys/ram`, `filesys/console_handler`, `graphics`, `hyperlayers`, `intuition`, `kernel`, `keymap`, `lddemon`, `devs/console`, `devs/gameport`, `devs/input`, `devs/keyboard`, `hidds/hidd`, `hidds/gfx`, `hidds/input`, `hidds/kbd`, `hidds/mouse`, `misc`, `oop`, `partition`, `utility`, `debug`, `processor`, `timer`, and `workbench/libs/gadtools`
  - `rom/task` remains outside that green set because `GetTaskStorageSlot.c` and `GetParentTaskStorageSlot.c` both leave `TaskGetStorageSlot` unresolved in the generated objects, and the current legacy reference tree does not contain a `task.resource` artifact either
- Additional verified native HIDD state in `cmake-build-debug`:
  - `rom/hidds/pci` is now registered through the generic genmodule path and builds as `bin/linux-x86_64/AROS/Devs/Drivers/pci.hidd`
  - the current legacy reference tree does not contain a matching `pci.hidd` artifact yet, so there is not a parity compare for it yet
- Current cache/migration caveat:
  - existing `cmake-build-debug` trees may need an explicit `AROS_ROM_NATIVE_MODULES` cache update when a newly migrated ROM module is added
  - that cache-upgrade behavior should be cleaned up when `rom/CMakeLists.txt` gets its dedicated post-migration cleanup pass
- Current `dos` / `expansion` parity finding:
  - the earlier remaining real drift in `dos.library` and `expansion.library` was not in generated `*_start.c`, `*_init.o`, or the public archives; those native artifacts match legacy shape closely enough
  - the shared CMake-side mistakes were:
    - treating `noautolib` from `*.conf` as "clear the final autolib link chain"
    - treating `noresident` from `*.conf` as "inject `-nosysbase -Wl,--defsym -Wl,SysBase=0x4` and drop implicit `exec` linkage"
  - both behaviors are wrong:
    - legacy still links the normal archive chain for `noautolib` modules
    - legacy does not derive `-nosysbase` / fake `SysBase` from `noresident`
  - concrete legacy proof from the generated link maps:
    - `dos_init.o` and `expansion_init.o` pull `libexec.a(exec_autoinit.o)` on `SysBase`
    - `libexec.a(exec_autoinit.o)` then pulls `libautoinit.a(__showerror.o)` on `___showerror`
  - if native CMake predefines `SysBase=0x4`, that whole extraction chain is bypassed and the final module loses `___showerror`
  - the CMake registration layer now keeps the normal autolib chain for `noautolib` modules and no longer injects fake-`SysBase` link flags for `noresident`
  - current clean-tree status after direct module rebuilds:
    - `expansion.library` is down to a single byte diff, matching the ordinary `$VER:` date-drift class
    - `dos.library` now matches legacy in size (`176488`) but still has `383` byte diffs
  - the remaining `dos.library` drift is now localized:
    - diff blocks start in `generate_banner()` from `rom/dos/banner.c`, not in startup/link ordering
    - `banner.c` embeds `REPOTYPE`, `REPOREVISION`, `REPOID`, and `ISODATE`
    - the compared artifacts were built from different source-control identities, so the native clean tree and the current legacy reference embed different git hash / repo-id strings before the `$VER:` date
    - concrete object-level evidence from `banner.o`:
      - native `.rodata.cst16` includes `Version Git a628c85211 (git@github.com:MBaijer/AROS.git)`
      - legacy `.rodata.cst16` includes `Version Git fd5684ac62 (https://github.com/deadwood2/AROS)`
    - that means the remaining `dos.library` diff is not currently a proven CMake-vs-legacy build-graph mismatch; the reference inputs themselves are divergent
- Current verification caveat on clean-tree rebuilds:
  - the clean verification tree under `/tmp/aros-clean-build-reuse` still spends a lot of time in long `cmake -P` custom commands on this host/filesystem, often showing `D`/`Ds` process states while rewriting many interface stamps after shared graph changes
  - when this happens, prefer:
    - serialized Ninja verification (`-j1`)
    - or rerunning the final generated module `cmake -P ... build_genmodule_module.cmake` command directly for the specific module being checked
  - avoid reading too much into the wall-clock time there; the important signal is the regenerated command line and final artifact parity, not the slow NFS-bound custom-command churn
- Current `hostlib.resource` migration finding:
  - `arch/all-hosted/hostlib` is already registered natively and exposes the public artifact target `hostlib.resource`
  - the clean-tree blocker was not legacy behavior; it was CMake graph modeling
  - module-generated public/`_rel` linklib side effects must not be modeled as hard file prerequisites in Ninja
    - real `aros_register_mmake_linklib(...)` archives can stay as file deps
    - genmodule module public/`_rel` linklibs must be ordered through their interface targets instead
    - runtime module deps now include `_aros_module_archive_dep_targets`
  - after that fix, the clean-tree `hostlib.resource` edge no longer pulls false file deps like `libdiskfont.a`, `libasl.a`, `libmuimaster.a`, etc.; only the true core linklib archives remain as direct file prerequisites
  - the next blocker was another shared CMake issue:
    - base sources under `arch/...` were being misclassified as layer sources purely because their absolute path matched `/arch/`
    - that stripped module `USER_INCLUDES` from base arch modules
  - the generic rule now is:
    - only treat a source as a layer source when it comes from a different resolved `arch/<layer>/...` directory than the module’s own `MODULE_PATH`
    - base sources under `arch/...` keep full `_common_compile_args`
  - legacy confirms the correct `hostlib` behavior:
    - `close.o` is compiled from `arch/all-hosted/hostlib/close.c`
    - `hostinterface.h` resolves from `arch/all-unix/kernel/hostinterface.h`
    - see `cmake-build-debug/legacy-main/bin/linux-x86_64/gen/arch/all-hosted/hostlib/hostlib/close.d`
  - a direct rerun of `cmake/build_genmodule_module.cmake` for `arch/all-hosted/hostlib` in `/tmp/aros-clean-build-reuse` now succeeds after the source-classification fix
  - current `hostlib.resource` parity status:
    - native: `/tmp/aros-clean-build-reuse/bin/linux-x86_64/AROS/boot/linux/Devs/hostlib.resource`
    - legacy: `/tmp/aros-legacy-reference-linux-x86_64/bin/linux-x86_64/AROS/boot/linux/Devs/hostlib.resource`
    - sizes match exactly: `14688`
    - after the shared source-order fix and a direct module rebuild, `cmp -l | wc -l` is down to `1`
    - the only remaining visible drift is the `$VER:` date byte at offset `4491`
    - `$VER:` stays at the same string offset (`4448`):
      - native: `$VER: hostlib.resource linux-x86_64 4.0 (13.3.2026)`
      - legacy: `$VER: hostlib.resource linux-x86_64 4.0 (10.3.2026)`
  - another shared cause of the remaining structural drift was source ordering:
    - `_aros_resolve_module_sources()` must preserve mmake source order for modules whose own `MODULE_PATH` lives under `arch/...`
    - only resolved sources from a different `arch/<layer>/...` directory should be treated as layer sources and fed into the sorted layer-override path
    - base module sources under `arch/...` must stay in `_resolved_base_sources` so the final link order matches legacy
- Current native asm compilation finding:
  - module asm sources in `cmake/build_genmodule_module.cmake` must be compiled with `-x assembler-with-cpp`, matching legacy `assemble_q` behavior and the existing native `cmake/build_mmake_linklib.cmake` path
  - without that, lowercase preprocessed asm like `arch/x86_64-all/exec/execstubs.s` fails with raw assembler parse errors on backslash-continued macro bodies and `#include`
  - genmodule-produced `LINKLIBAFILES` / `RELLINKLIBAFILES` also need the same `-x assembler-with-cpp` treatment
  - after that shared fix, `exec.library` builds again in the active Ninja tree
- Current workbench/lib migration findings:
  - existing caches may still pin `AROS_WORKBENCH_LIBS_NATIVE_MODULES` to older defaults (`gadtools`, or later broad defaults that still predate newly added modules); native workbench/lib cache migration must keep upgrading those stale values so newly migrated libraries actually register in older build trees
  - current default native workbench/lib set now includes:
    - `amigaguide`, `asl`, `bullet`, `cgfx`, `commodities`, `coolimages`, `datatypes`, `diskfont`, `gadtools`, `icon`, `iffparse`, `locale`, `lowlevel`, `realtime`, `rexxsyslib`, `version`, `workbench`
  - `workbench/libs/lowlevel`, `workbench/libs/realtime`, and `workbench/libs/version` fit the existing generic `aros_register_mmake_genmodule_module(...)` path and do not need module-specific CMake logic
  - current legacy reference tree under `/tmp/aros-legacy-reference-linux-x86_64/bin/linux-x86_64/AROS` still does not contain matching workbench-lib artifacts for:
    - `asl.library`
    - `gadtools.library`
    - `lowlevel.library`
    - `realtime.library`
    - `version.library`
  - do not block native migration of those modules on immediate parity until the legacy reference generation path is widened enough to produce comparable workbench-lib outputs
  - public artifact aliases are now the human-facing names:
    - examples: `asl.library`, `locale.library`, `rexxsyslib.library`
    - short names like `asl`, `exec`, and `locale` are reserved for CMake `INTERFACE` dependency targets, not Ninja-buildable artifact targets
  - module-local catalog headers need a generic CMake path:
    - if a module source set includes `"strings.h"` and the module has exactly one local `.cd` file under a standard catalog directory, CMake should generate a module-local `strings.h` through `flexcat`
    - current generic output path is `CMAKE_BINARY_DIR/modules/<module-id>/generated/strings.h`
    - this is required for workbench modules like `workbench/libs/asl`, where falling back to the staged global `strings.h` loses the module-local `MSG_*` defines
  - native runtime module builds must honor compile-only include dirs separately from the broader `INTERFACE` include surface
    - the runtime `build_genmodule_module.cmake` command now needs the explicit module compile include list (`MODULE_INCLUDE_DIRS`) ahead of inherited/public include dirs
  - raw source directories must not shadow staged/generated public headers
    - keep generated/module include dirs and staged native include roots ahead of `${CMAKE_SOURCE_DIR}/${MODULE_PATH}`
    - concrete failure: `workbench/libs/asl/buttonclass.c` picked the wrong `coolimages.h` ordering and then saw `struct CoolImage` without `numcolors`
  - the flat staged public include root `AROS_NATIVE_INCLUDE_DIR` is a separate late include-order case
    - do not leave it inside early runtime `MODULE_INCLUDE_DIRS`; `build_genmodule_module.cmake` already appends it later on purpose
    - otherwise generated private sources can resolve flat public headers before module-local private ones
    - concrete failure: `rom/lddemon` can pick `native-includes/lddemon.h` instead of `rom/lddemon/lddemon.h`, leaving `struct IntLDDemonBase` incomplete in generated `lddemon_start.c`
  - after shared `AROSModule.cmake` changes, even `/tmp` Ninja build dirs can spend a long time rewriting interface-only `cmake -P` steps because the source tree itself lives on NFS
    - treat that as a verification/performance caveat, not automatically as a new dependency bug
- Current `kernel-package-base` / parity findings on the active `cmake-build-debug` tree:
  - `cmake --build cmake-build-debug --target kernel-package-base -j 6` completes successfully in the current workspace
  - a coarse whole-tree compare against `/tmp/aros-legacy-reference-linux-x86_64/bin/linux-x86_64/AROS` is mostly a coverage signal right now, not a single parity bug:
    - native tree had `69` files vs legacy `2674`
    - most "missing left" results are simply not-yet-migrated outputs
    - current "missing right" examples like `gadtools.library`, `partition.library`, `libamigaguide.a`, `libuuid.a`, etc. are still legacy-reference coverage gaps
  - after a direct rebuild of `rom/expansion` from the generated module command, `expansion.library` jumps from the stale `15224`-byte artifact back to the correct legacy-sized `20848` bytes
    - that confirms the earlier large `expansion.library` mismatch in `cmake-build-debug` can come from stale module outputs, not only live graph regressions
    - after the fresh rebuild, native `expansion.library` and legacy now both contain the expected error-requester/autoinit tail:
      - `__aros_libreq_IntuitionBase.36`
      - `__forceerrorrequester`
      - `GetDataStreamFromFormat`
      - `___showerror`
    - there is still a remaining non-date byte diff (`cmp -l | wc -l` reported `2008`), so parity is improved but not yet finished
  - `rom/hidds/input` currently emits a non-fatal warning in native builds:
    - `HWAttrBase` is redefined between generated private SDK header `.../interface/HW.h` and `rom/hidds/input/input.h`
    - current status is warning-only; not a hard migration blocker yet
  - direct module-command rebuilds are useful for parity spot checks, but only when the module-local generated prerequisites are still present
    - after interrupting a broader clean rebuild, running the raw generated `rom/dos` module command directly failed in `displayerror.c` because `MSG_STRING_*` defines were missing
    - that was due to bypassing the normal generated local string-header dependency path, not a new proven `dos` graph regression
  - direct raw runtime reruns of `cmake/build_genmodule_module.cmake` can also silently contaminate parity if the expected native archive deps are missing
    - concrete case: a manual `rom/expansion` rerun in `cmake-build-debug` produced a false `2007`-byte drift against the clean native tree because native `libautoinit.a`, `liblibinit.a`, and `libstdc.static.a` were absent from `bin/.../AROS/Development/lib`, so the link fell back to sysroot/legacy archives
    - the generic hardening fix is now in place:
      - `AROSModule.cmake` passes the expected native archive file deps into the runtime module command
      - `build_genmodule_module.cmake` now hard-fails if those archives are missing instead of silently accepting fallback resolution
    - after restoring the active tree through the real Ninja target graph, `cmake-build-debug` `expansion.library` is byte-identical to the clean native `/tmp/aros-clean-build-reuse` artifact and back to the normal single-byte/date-only drift against the current legacy reference
  - native archive parity has two separate classes:
    - real content/member-name parity
    - container-header metadata parity (`ar` member timestamps and related archive header bytes)
  - the shared `build_mmake_linklib.cmake` object-base logic was producing path-heavy archive member names for some linklibs where legacy uses plain basenames when they are unique
    - concrete failures:
      - native `libstdc.static.a` stored members like `stdc_math_e_log.o`, while legacy stored `e_log.o`
      - native `libudis86.a` stored members like `_home_..._itab.o`, while legacy stored `itab.o`
    - the generic fix is now in place:
      - `build_mmake_linklib.cmake` prefers the resolved source basename for archive member/object names when that basename is unique within the linklib
      - it falls back to the old sanitized path-based name only on basename collisions
    - after rebuilding `libstdc.static.a` and `libudis86.a`, both now match legacy member names and archive sizes exactly
  - normalized archive-content parity is currently clean for the active native SDK libs:
    - extracting all currently produced `Development/lib/*.a` files with `ar x` and comparing member contents against the legacy reference yields `0` real content diffs across `29` comparable archives
    - remaining raw byte diffs in those `.a` files are just archive-container metadata (member timestamps/header bytes), not differing object contents
  - `compare_output_trees.cmake` now treats `.a` archives specially:
    - it compares member list/order plus extracted member contents instead of raw file size/SHA only
    - this removes false parity failures from archive-header metadata while still catching real archive-content drift
  - with that archive normalization in place, the current non-fatal active-tree compare reports only one differing comparable output:
    - `boot/linux/Libs/expansion.library`
    - current diff count is `1`, and it is the expected `$VER:` date-only drift:
      - native: `$VER: expansion.library 41.4 (13.3.2026)`
      - legacy: `$VER: expansion.library 41.4 (10.3.2026)`
  - after building the remaining currently migrated ROM modules outside `kernel-package-base` (`battclock`, `disk`, `exec`, `kernel`, `misc`, `partition`, `processor`, `timer`, `hidds/pci`), the active accepted native tree is at the pre-`task` state
    - compare state against the current legacy reference:
      - `missing right`: `17`
      - `missing left`: `2616`
      - `differing`: `28`
    - the new `missing right` set is still mostly legacy-reference coverage gaps for artifacts the current reference tree does not contain:
      - `Devs/disk.resource`
      - `Devs/misc.resource`
      - `Devs/Drivers/pci.hidd`
      - `Libs/partition.library`
      - `boot/linux/Devs/kernel.resource`
      - `boot/linux/Libs/exec.library`
      - plus already-known workbench-lib/archive coverage gaps
  - current comparable runtime-output parity is now narrowly classified:
    - `24` comparable runtime outputs differ by exactly `1` byte
    - `Libs/aros.library` differs by `2` bytes
    - `Libs/dos.library` differs by `381` bytes
    - the larger raw `.a` diffs from ad-hoc `cmp` checks are archive-container metadata noise unless they also fail the archive-content compare path
  - `Libs/aros.library` is down to the normal `$VER:` date drift class
  - the remaining `Libs/dos.library` drift is still not a proven CMake-vs-legacy graph bug on this tree
    - current strings still show divergent embedded repo identity and date metadata from `rom/dos/banner.c`
    - native example: `Version Git 0dbb813549 (git@github.com:MBeijer/AROS.git)`
    - legacy example: `Version Git fd5684ac62 (https://github.com/deadwood2/AROS)`
  - `rom/task` remains blocked and must not be "fixed" by changing source as part of the migration
    - `TASKRES_ENABLE` is always defined in `rom/task/task_intern.h`
    - `GetParentTaskStorageSlot.c` and the public getter both call the internal helper `TaskGetStorageSlot(struct Task *, LONG)`
    - the only implementation body in `rom/task/GetTaskStorageSlot.c` was compiled out under `#if 0`, leaving `task.resource` with a single unresolved symbol:
      - `TaskGetStorageSlot`
    - a prior source-side enablement of that body was the wrong move for this migration and must not be treated as accepted progress
    - unless the user explicitly directs otherwise, `task` should stay outside the native-green set until it can be justified against a legacy reference path without changing source
    - the current legacy reference tree still does not contain `Devs/task.resource`, so there is still no artifact-level parity compare for `task`
  - the `rom/hidds/input` `HWAttrBase` warning is inherited from the generated source shape, not from the CMake-native compile command reconstruction
    - native generated `inputclass_start.c` and legacy generated `inputclass_start.c` have the same include order:
      - generated `inputclass_libdefs.h` includes `input.h`
      - then generated `inputclass_start.c` includes `<hidd/hidd.h>`
    - that means the warning is not currently a proven CMake-only regression
  - `workbench/libs` now needs a native aggregate entrypoint, not only the legacy wrapper
    - `workbench/libs/CMakeLists.txt` now exposes `aros-workbench-libs-complete-native` as the native aggregate over enabled `aros-workbench-libs-*-native` module targets
    - this is the correct way to surface the next workbench migration blocker instead of hand-building a stale subset of libs
  - the next concrete native workbench blocker is `workbench/libs/asl`
    - failure:
      - `buttonclass.c:82:47: error: 'struct CoolImage' has no member named 'numcolors'`
    - root cause is include shadowing by the module’s own source directory, not a bad staged public header:
      - `buttonclass.c` includes `<libraries/coolimages.h>`
      - staged `libraries/coolimages.h` includes `<coolimages.h>`
      - if the module source dir `workbench/libs/asl` is on the early `-I` path, that nested include resolves to the private legacy compatibility header `workbench/libs/asl/coolimages.h`
      - that private header uses the old static layout field `depth` instead of the public/shared-layout field `numcolors`
    - the generic runtime-builder fix is:
      - strip the module’s own source dir from `MODULE_INCLUDE_DIRS`
      - re-add `${AROS_SOURCE_DIR}/${MODULE_PATH}` as `-iquote` instead of `-I`
      - this preserves local `"foo.h"` resolution but stops public `<foo.h>` includes from being shadowed by same-directory private headers
    - preprocessor verification after the fix:
      - with the `asl` include shape, `<libraries/coolimages.h>` now resolves nested `<coolimages.h>` to `native-includes/coolimages.h`, not `workbench/libs/asl/coolimages.h`
    - full `aros-workbench-libs-asl-native` / `aros-workbench-libs-complete-native` rebuild verification remains slow on this NFS-backed tree because the changed runtime builder invalidates a broad interface slice before it gets back to the actual `asl` compile
  - the staged flat public root must not publish `limits.h`
    - `stage_native_includes.cmake` was creating `native-includes/limits.h` as a flat alias to `aros/stdc/limits.h`
    - that header does not provide `PATH_MAX`, while the correct public path for current native module builds is `aros/posixc/limits.h`
    - concrete native failure before the fix:
      - `workbench/libs/locale/initlocale.c`: `PATH_MAX` undeclared
    - current generic fix:
      - after publishing flat root aliases, explicitly remove `${AROS_NATIVE_INCLUDE_DIR}/limits.h`
    - verification after rebuilding `aros-native-includes`:
      - `native-includes/limits.h` is absent
      - `<limits.h>` resolves through `aros/posixc/limits.h`
      - `PATH_MAX` expands to `1024`
  - native include staging must also honor compiler-owned `%copy_includes` headers, not only arch include mmakefiles
    - concrete failure on a clean tree:
      - `workbench/libs/coolimages` interface generation failed in generated `coolimages_regcall_stubs.c`
      - staged `native-includes/libraries/coolimages.h` includes flat `<coolimages.h>`
      - `native-includes/coolimages.h` was missing, so the compile died with `fatal error: coolimages.h: No such file or directory`
    - root cause:
      - `compiler/include/libraries/coolimages.h` is only half of the public surface
      - the matching flat header actually comes from `compiler/coolimages/include/coolimages.h`
      - `stage_native_includes.cmake` was staging `compiler/include` directly, but not replaying `%copy_includes` from `compiler/*/mmakefile.src`
    - current generic fix:
      - `stage_native_includes.cmake` now stages `%copy_includes` from `compiler/*/mmakefile.src` in addition to the existing arch include mmakefiles
    - local verification after rebuilding `aros-native-includes`:
      - `native-includes/coolimages.h` is now generated from `compiler/coolimages/include/coolimages.h`
      - direct `aros-workbench-libs-coolimages-native` builds move past the old generated-stub missing-header failure and back into the broader dependency graph
  - the remaining registered native `workbench/libs` modules beyond `asl` are now mostly green on the active tree
    - successful direct native builds:
      - `lowlevel.library`
      - `realtime.library`
      - `rexxsyslib.library`
      - `version.library`
      - `workbench.library`
      - `uuid.library`
      - `mathffp.library`
      - `mathieeedoubtrans.library`
    - current active-file presence check under `bin/linux-x86_64/AROS/Libs`:
      - present: `lowlevel`, `realtime`, `rexxsyslib`, `uuid`, `version`, `workbench`, `mathffp`, `mathieeedoubtrans`
      - missing: `cgxvideo`
  - the native `workbench/libs` module set now also includes the first math-library batch
    - newly registered native modules:
      - `workbench/libs/mathffp`
      - `workbench/libs/mathieeedoubbas`
      - `workbench/libs/mathieeedoubtrans`
      - `workbench/libs/mathieeesingbas`
      - `workbench/libs/mathieeesingtrans`
      - `workbench/libs/mathtrans`
    - each now has a native `CMakeLists.txt` using `aros_register_mmake_genmodule_module(...)`
    - `workbench/libs/CMakeLists.txt` default native module set and cache-upgrade logic were extended so existing default-valued `AROS_WORKBENCH_LIBS_NATIVE_MODULES` caches pick up that batch automatically
    - first verification batch is green:
      - `mathffp.library`
      - `mathieeedoubtrans.library`
    - that gives one simple math module and one transitive case (`mathieeedoubtrans` depends on `mathieeedoubbas`) without needing extra CMake glue
  - `workbench/libs/cgxvideo` and `workbench/libs/uuid` are now registered as native CMake genmodule libraries
    - new module manifests:
      - `workbench/libs/cgxvideo/CMakeLists.txt`
      - `workbench/libs/uuid/CMakeLists.txt`
    - `workbench/libs/CMakeLists.txt` default native module set now includes both `cgxvideo` and `uuid`
    - cache-upgrade logic was extended so existing default-valued `AROS_WORKBENCH_LIBS_NATIVE_MODULES` caches are promoted to the new default instead of silently leaving those two modules disabled
  - `workbench/libs/cgxvideo` is now build-green natively
    - `cgxvideo.library` is present under `bin/linux-x86_64/AROS/Libs`
    - object-level split of the unresolveds:
      - `cgxvideo_init.o` needs `OOPBase`
      - `CreateVLayerHandleTagList.o` needs `OOPBase` and `__IHidd_Overlay`
    - the underlying source convention differs from already-green `workbench/libs/cgfx`:
      - `cgfx` explicitly declares `uselibs="oop"` in `mmakefile.src`
      - `cgfx` private header maps generated public HIDD attr-base symbols back into its library base:
        - `#define __IHidd_BitMap ...`
        - `#define __IHidd_Gfx ...`
      - `cgxvideo` does not declare `uselibs="oop"` and only defines the local alias `HiddOverlayAttrBase`, not the generated public symbol `__IHidd_Overlay`
    - current implication:
      - this is not just a missing CMake target registration
      - the blocker is a legacy module/source convention mismatch that is not yet proven fixable from CMake glue alone without changing accepted source semantics
    - current reference caveat:
      - the active legacy parity tree does not currently contain `Libs/cgxvideo.library`, so there is still no artifact-level parity comparison for this module
    - current CMake-side resolution path (2026-03-14):
      - `aros_register_mmake_genmodule_module(...)` now accepts extra `LINK_LIBS` and `LINK_OPTIONS` so native module manifests can extend legacy-parsed metadata without dropping to a custom registration path
      - `workbench/libs/cgxvideo/CMakeLists.txt` now injects `LINK_LIBS oop`
      - object-level probing showed the HIDD overlay issue is not the macro `Hidd_OverlayAttrBase` itself but the generated token `__IHidd_Overlay`
      - working CMake-side alias is therefore:
        - `COMPILE_DEFINITIONS __IHidd_Overlay=HiddOverlayAttrBase`
      - `cmake/build_genmodule_module.cmake` now also provides a weak `__LIBS__symbol_set_handler_missing` marker when:
        - generated linklib sources pull in `__includelibrarieshandling`
        - but the generated startup does not declare `THIS_PROGRAM_HANDLES_SYMBOLSET(LIBS)` / `DECLARESET(LIBS)`
      - rationale:
        - this matches the existing weak-marker fallback already used for missing `INIT` symbolset handlers
        - it specifically covers `noautolib` genmodule startups like `cgxvideo`, where `*_autoinit.c` is still emitted but the startup omits the normal `LIBS` handler set
      - manual verification:
        - a direct target-compiler object/link probe succeeds once all three CMake-side pieces are applied:
          - `oop` added to the link surface
          - `__IHidd_Overlay=HiddOverlayAttrBase`
          - weak `__LIBS__symbol_set_handler_missing`
      - status:
        - the checked-in CMake changes are in place
        - a full narrow Ninja rebuild of `aros-workbench-libs-cgxvideo-native` now completes successfully on the active tree
        - the active legacy parity tree still has no `Libs/cgxvideo.library`, so parity classification remains `no legacy reference artifact`
  - the shared mmake logical-line reader needed another hardening pass for continued assignments followed by comment lines
    - concrete failure before the fix:
      - `compiler/crt` interface generation stopped in `strcasestr.c` with:
        - `x86_64-aros-gcc: error: #USER_CPPFLAGS: No such file or directory`
        - `x86_64-aros-gcc: error: +=: No such file or directory`
      - root cause:
        - continued `USER_CPPFLAGS := \` blocks in `compiler/crt/mmakefile.src` were still materializing as logical lines containing a trailing `;#USER_CPPFLAGS += ...` fragment inside CMake
    - current generic fix:
      - both copies of `_aros_read_mmake_logical_lines(...)` in `cmake/build_genmodule_module.cmake` and `cmake/AROSModule.cmake` now:
        - treat a comment encountered during a continued logical line as an explicit line terminator
        - strip trailing inline/list-shaped comment fragments with `([ \t]|;)+#.*$`
        - quote the `if()` operands so list-valued intermediates cannot change the condition parse
      - both parser sites that skip comment logical lines now accept `^[ \t;]*#`, not only bare `^#`
    - local verification:
      - the same narrow `aros-workbench-libs-cgxvideo-native` rebuild now passes both earlier `compiler/crt` interface stops and reaches the final `cgxvideo` module build
  - the remaining parity drift in the newly added plain `workbench/libs` batch is mostly shared link-shape, not per-module manifest logic
    - first concrete trigger was `workbench/libs/uuid`
      - active-tree stale output before the fix:
        - native `uuid.library` was `30448`, legacy `25384`
        - native `uuid.library` pulled direct stdlib-side implementations and data such as:
          - `snprintf`
          - `strlen`
          - `vsnprintf`
          - `__vcformat`
          - `__ctype_*`
        - legacy `uuid.library` instead carried the `StdlibBase` libreq/wrapper path:
          - `__aros_libreq_StdlibBase`
          - `__snprintf_StdlibBase_libreq`
          - `__strlen_StdlibBase_libreq`
    - current linker-shape evidence:
      - the generated native module commands for `uuid`, `identify`, `rexxsupport`, `kms`, `muiscreen`, and `reqtools` all pass:
        - `MODULE_LINK_LIBS=` or a small explicit module-local set
        - `MODULE_AUTO_LINK_LIBS=...|m|stdlib|crt|...|exec|autoinit|libinit`
      - `TARGET_C_LIBS` in the active legacy config is empty, so the extra stdlib-side pull is not coming from `target.cfg`
      - archive symbol scan on the active native SDK shows:
        - `libstdlib.a` contains the wrapper/libreq path:
          - `__snprintf_StdlibBase_libreq`
          - `__strlen_StdlibBase_libreq`
        - `libstdc.static.a` contains the full ctype tables:
          - `__ctype_b`
          - `__ctype_toupper`
          - `__ctype_tolower`
        - `libstdc.static.a` and `libstdlib.a` both contain:
          - `snprintf`
          - `vsnprintf`
          - `__vcformat`
    - negative experiment already run:
      - a one-off relink of `uuid` with a temporary copy of `build_genmodule_module.cmake` that drops `--start-group/--end-group` does not work as a direct fix
      - concrete failure:
        - `/tmp/uuid.nogroup.library` fails to link with unresolved `GetDataStreamFromFormat`
      - implication:
        - the parity fix is not “remove all grouping”
    - current generic fix:
      - `cmake/build_genmodule_module.cmake` no longer wraps the entire effective native link set in one `--start-group/--end-group`
      - only the startup/autolib cycle is grouped:
        - `arossupport`
        - `amiga`
        - `exec`
        - `autoinit`
        - `libinit`
      - other auto-link libraries such as `m`, `stdlib`, and `crt` now stay ungrouped, which matches the legacy `%build_module` pull behavior closely enough to avoid dragging in extra stdlib bodies
    - local verification with isolated replays using the checked-in script:
      - `uuid.library`: `25384` vs legacy `25384`, down to a `1`-byte drift class
      - `identify.library`: `64920` vs legacy `64920`, down to a `1`-byte drift class
      - `rexxsupport.library`: `44656` vs legacy `44656`, remaining same-size multi-byte drift
      - `kms.library`: `20760` vs legacy `20760`, remaining same-size multi-byte drift
      - `muiscreen.library`: `25504` vs legacy `25504`, down to a `1`-byte drift class
      - `reqtools.library`: `172368` vs legacy `172368`, remaining same-size multi-byte drift
    - active build-tree caveat:
      - the checked-in shared fix is verified through isolated `/tmp` replays already
      - the active `cmake-build-debug/bin/.../Libs` tree is still partly stale until those targets are rebuilt there:
        - `identify.library` is currently missing from the active tree
        - `uuid.library`, `rexxsupport.library`, `kms.library`, `muiscreen.library`, and `reqtools.library` still show their pre-fix sizes in the active tree
  - the native genmodule linker was missing the target compiler runtime helper archive under `-nostdlib`
    - concrete failure before the fix:
      - `workbench/libs/kms` linked with unresolved `__popcountdi2`
      - source trigger is `parsekeymapseg.c` calling `__builtin_popcount(...)`
    - legacy evidence:
      - current legacy map files load `.../tools/crosstools/lib/gcc/x86_64-aros/10.5.0/libgcc.a`
    - current generic fix:
      - `cmake/build_genmodule_module.cmake` now queries the target compiler with `-print-libgcc-file-name`
      - when the build uses `NOSTDLIB_LDFLAGS`, the resolved helper archive is appended to the module link command
    - local verification after the fix:
      - `kms.library` now links successfully
      - the change held through a rerun of `aros-workbench-libs-complete-native`
  - the full initial math-library batch is now green on the active tree
    - successful direct native builds now include:
      - `mathffp.library`
      - `mathieeedoubbas.library`
      - `mathieeedoubtrans.library`
      - `mathieeesingbas.library`
      - `mathieeesingtrans.library`
      - `mathtrans.library`
    - this extends the earlier first-pass result and shows both base and transitive math-library cases working without extra CMake glue
  - additional plain `workbench/libs` genmodule libraries are now registered natively
    - newly added module manifests:
      - `workbench/libs/camd/CMakeLists.txt`
      - `workbench/libs/identify/CMakeLists.txt`
      - `workbench/libs/rexxsupport/CMakeLists.txt`
      - `workbench/libs/kms/CMakeLists.txt`
      - `workbench/libs/muiscreen/CMakeLists.txt`
      - `workbench/libs/pccard/CMakeLists.txt`
      - `workbench/libs/reqtools/CMakeLists.txt`
    - `workbench/libs/CMakeLists.txt` default native module set and cache-upgrade logic were extended so existing default-valued `AROS_WORKBENCH_LIBS_NATIVE_MODULES` caches pick up that batch automatically
    - current direct native artifact presence under `bin/linux-x86_64/AROS/Libs`:
      - `camd.library`
      - `rexxsupport.library`
      - `kms.library`
      - `muiscreen.library`
      - `pccard.library`
      - `reqtools.library`
      - `identify.library` is currently missing from the active tree, but an isolated replay with the checked-in genmodule script succeeds and matches legacy size
    - `reqtools` currently emits packed-member alignment warnings in a few files, but they are warning-only and not a migration blocker
    - targeted parity check against the active legacy reference tree:
      - parity-healthy `1`-byte drift class:
        - `camd.library`
        - `pccard.library`
      - verified by isolated replay with the checked-in script, but not yet refreshed in the active tree:
        - `identify.library` (`64920` vs `64920`, `1`-byte drift class)
        - `uuid.library` (`25384` vs `25384`, `1`-byte drift class)
        - `muiscreen.library` (`25504` vs `25504`, `1`-byte drift class)
        - `rexxsupport.library` (`44656` vs `44656`, same-size multi-byte drift)
        - `kms.library` (`20760` vs `20760`, same-size multi-byte drift)
        - `reqtools.library` (`172368` vs `172368`, same-size multi-byte drift)
  - `aros-workbench-libs-complete-native` now gets past the former `cgxvideo` blocker
    - aggregate target verification reached successful native module builds for:
      - `amigaguide`
      - `asl`
      - `bullet`
      - `camd`
      - `cgfx`
      - `cgxvideo`
      - `uuid`
    - implication:
      - the earlier `asl`/`coolimages` include-shadowing failure is no longer the aggregate blocker
      - the next actionable workbench issue has shifted from gross size-mismatch cleanup to refreshing the active tree under the checked-in selective-group linker logic and then reducing the remaining same-size drift class (`rexxsupport`, `kms`, `reqtools`)
  - targeted parity checks now need to be part of each migration increment, not a later cleanup pass
    - working rule for new native module batches:
      - after the build goes green, immediately compare each newly added artifact against the active legacy reference tree
      - record each result in one of these buckets before moving on:
        - no legacy reference artifact yet
        - `1`-byte / date-version drift class
        - same-size but multi-byte drift
        - size mismatch
    - current math-library batch parity classification:
      - `mathffp.library`, `mathieeedoubbas.library`, `mathieeedoubtrans.library`, `mathieeesingbas.library`, `mathieeesingtrans.library`, and `mathtrans.library` are all currently in the `1`-byte drift class against the active legacy reference tree
