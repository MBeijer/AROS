# CMake Build Entry Point

The goal is to replace AROS MetaMake, make, and configure execution with a
CMake-owned build, retaining `mmakefile.src` as upstream-compatible metadata.
Migration is incomplete. The first milestone is a usable Linux-hosted x86_64
AROS session, not merely a successful library build or entry into the kernel.

## Scope

- The repository root sets up CMake; shared OS/SDK translation belongs in `cmake/`. Local `tools/` CMakeLists are supported. Remaining OS/SDK CMakeLists are transitional, not the intended architecture.
- Manifest discovery has no top-level directory allowlist. Edits to manifests, newly added source directories, and manifest additions/removals trigger reconfiguration on the next ordinary build. `mmakefile.src` takes precedence over sibling `mmakefile`; ignored/hidden/symlinked directories and build trees are excluded.
- Hosted launcher, loader archive, bootstrap configuration, kernel entrypoint, and architecture ROM-support archive registration no longer require `arch/CMakeLists.txt`, `bootstrap/CMakeLists.txt`, or hosted OS-local CMakeLists. Producers and destinations are selected from manifest identities, not copied source-directory lists. `arch/all-pc/udis86` still has transitional host-tool/SDK code-generation registration.
- Removed 31 redundant `workbench/libs/*/CMakeLists.txt` wrappers. Their existing selected-library profile now calls the shared manifest registry directly, preserving target names and module/interface commands. This does not complete the OS-local CMake cleanup: the Workbench parent/profile, MUI header generator, cgxvideo compatibility adapter, ROM, compiler, HIDD and Udis86 registrations still need migration. The parent no longer adopts arbitrary library-local CMake files; the two remaining local adapters are explicit exceptions pending replacement, not the end-state design.
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

Native targets compile/link/generate their migrated artifacts directly. Legacy
wrapper targets remain available for unmigrated work and parity reference;
completing those wrappers does not establish native migration or independence.

## Explicit Native Configuration

`AROS_NATIVE_CONFIG_FILE` optionally supplies configuration values missing from,
or differing from, the prepared reference snapshot. Set it to an absolute file
path at configuration time:

```bash
cmake -S . -B cmake-build-debug -DAROS_NATIVE_CONFIG_FILE=/absolute/path/native.cfg
```

The file contains literal `NAME=value` assignments. For example,
`TARGET_UNITTESTS=no` is an explicit choice, not a built-in default. Blank lines
and full-line `#` comments are allowed. Empty assignments are explicit empty
values. Duplicate keys, missing files, Make expressions, includes, inline
comments, and continuations are rejected. Values are not evaluated as shell or
CMake code. The original configuration files remain unchanged.

The shared manifest configuration readers use these values before reference
configuration evaluation, including immediate assignments in the ordered
program reader. Manifest-local assignments and native path contexts retain
their existing semantics. This is not a replacement for native configuration
generation or a way to change the CMake target/toolchain. Unspecified values
still come from the reference snapshot; unresolved placeholders are not given
invented defaults. Clearing `AROS_NATIVE_CONFIG_FILE` disables these inputs.

Editing this file triggers reconfiguration on the next ordinary build, updating
target selection and affected compiler options. Program and linklib regressions
verify changed binary contents, unchanged reference configuration, missing-file
recovery, rejected executable expressions, and subsequent no-op builds.

## Native Hosted Checkpoint (2026-09-06)

**Current limitation:** the program allowlist has been removed. Default program
discovery follows the upstream metadata graph, now passing AboutAROS's
compiler-only repository condition without executing it. It stops at
`test-crt-stdc-@aros_config_unittests@-cunit`: the prepared `target.cfg` still
contains `TARGET_UNITTESTS := @aros_config_unittests@`. No value is guessed.
An explicit native configuration file now allows supplying that choice without
editing the reference snapshot. Read-only probes with `yes` and `no` progress
beyond it and now complete discovery: each finds 234 target-OS program identities
across 1262 metadata nodes. These are observed counts, not maintained lists.
Discovery preserves cyclic aggregate metadata, including this upstream path:

```text
includes-copy -> external-openurl-includes -> kernel-dos-includes ->
kernel-intuition-includes -> kernel-graphics-includes ->
workbench-libs-cgfx-includes -> includes-copy
```

These edges occur in the unchanged manifests. MetaMake pre-marks targets before
recursing and skips visited dependencies. Native discovery instead records all
nodes and edges, including backedges, without treating aggregate reachability
as executable ordering. Concrete native prerequisite cycles and unsupported
recipes remain errors. Complete header-copy/interface scheduling is still
migration work; successful discovery does not mean every producer can build.

Host/kernel compiler roles remain traversable metadata but are excluded from
the target-OS program projection. This prevents registering the hosted
bootstrap twice through different compiler primitives. Unknown roles fail.

Explicit program `objdir` is now translated consistently for compilation,
named `.o`/`.d` outputs, and generated-input prerequisites. The isolated
compilation-metadata/prerequisite probe now passes the previously blocked Zune
test/demo producers, Demos, and the following monitor producers. It stops at
`external-bz2-bzip2-bin`'s generated/external `bzip2.c`, which requires a native
source producer. The bounded fetch support below now prepares and compiles that
source in isolation; full external library/include prerequisite integration is
still incomplete. Existing extracted reference files cannot satisfy native
source ownership. The earlier full-inventory preflight is recorded in
`/tmp/aros-nix-preflight.log`, not a successful aggregate build.

Both single and batch programs now support `nix=yes/no`. `NIX_LDFLAGS` comes
from configuration and is applied only at link time, after ISA options and
before startup-suppression/detach options, as in the upstream macros. Compiler
specs select objects and libraries, each requiring a native producer. No
hard-coded `-nix` flag, startup-object name, or library inventory was added.

SDK-object selection now prefers explicitly declared intermediates over
implicit chains, and the shortest matching compile-pattern stem over generic
patterns. This preserves the real `nix/nixmain.o` rule's `_XOPEN_SOURCE=700`
flags. Existing generated objects do not determine selection or replace
producers; unsupported object recipes/constraints still fail. A direct isolated
native compile of unchanged `nixmain.c` produces a byte-identical 1504-byte
legacy-reference `nixmain.o`. This uses prepared compiler/SDK/configuration
inputs, not a clean independent build or a newly verified hosted session.

`aros-programs-check` includes `mmake_nix_programs.cmake`, covering single/batch
linking, link-only flags, specs-driven inputs, flag ordering, source/header/
archive rebuilds, configuration changes, missing-output recovery, no-op builds,
object-pattern precedence, and rejected invalid options/missing producers.
Startup/archive-only edits do not recompile programs; changes to the shared
program metadata currently rebuild compilation conservatively.

### Manifest Header Staging

Named program include prerequisites now discover `%copy_includes` producers
from the manifest inventory. `cmake/AROSIncludeTargets.cmake` reads upstream
macro defaults and copies exactly the declaration-time header list, preserving
nested paths or flattening names when `dir` is specified. Public/private target
SDK copies and host/kernel-only copies remain distinct. Dependency-only
manifests can augment a producer with native fetch prerequisites; existing
extracted reference headers never satisfy those edges.

Header lists may use the upstream `WILDCARD` helper over literal source or
native fetched directories. Discovery defers filesystem selection until fetch
receipts are ready and verified. Ordinary builds discover added/removed matching
headers; hidden files and directories are excluded according to the supported
shell pattern semantics. Arbitrary shell helpers, wildcard directory components,
unowned external files and modified fetched inventories remain errors. Removed
headers lose their Ninja producer, but old staged copies are not yet deleted.

`aros-includes-check`, also run by `aros-programs-check`, verifies defaults,
bare macros, destination roles, shared copies, cross-manifest fetch dependencies,
source/archive edits, new producers, missing-file recovery, unsafe paths and
no-op builds. The unchanged bzip2 manifest produces target and host `bzlib.h`
copies byte-identical to the reference SDK, followed by a no-op build.
The unchanged Codesets fetch also produces 110 files identical to the reference;
its six header declarations select seven matching headers in a metadata-only
probe. Its complete SDK prerequisite graph is not yet verified: the isolated
full-header probe stops at an unsupported generated SDK-header rule.

Ordinary manifest linklibs now use this copier for their local header
declarations by default. Registration is deferred until native module-interface
providers exist, including linklibs discovered in a later deferred pass. Shared
declarations reuse one copy producer; header stamps drive archive rebuilds.
Manifests without local copy declarations do not evaluate unrelated conditions
for this header phase, but remain reconfiguration inputs.

The linklib fixture covers exact lists, per-declaration SDK selection,
late interface registration, shared copies, header/manifest edits, missing-header
recovery, fetched-header preparation and archive changes, and no-op builds.
The real compiler-support/autoinit declarations produce 15 target and 15 host
headers byte-identical to the reference SDK, followed by a no-op build.
The shared `aros-compiler-arossupport-linklib-native-includes` and
`aros-compiler-autoinit-linklib-native-includes` targets also build successfully
and settle to a no-op without reconfiguration. All 18 broader regression scripts
and the dedicated include suite pass.

This path remains bounded: generated-header recipes and included rules/options
still require native translation. The existing udis86 generator adapter explicitly
retains the transitional stager via `LEGACY_GENERATED_HEADERS`; it now tracks its
generated files as file-level dependencies too. There is no automatic fallback
for unsupported headers. HIDD/module staging, broad shared include aliases, and
linklib configuration independence remain migration work. Native fetched linklib
sources now have the bounded support described below.

The repository-level header probe still invoked legacy configure through generated
configuration dependencies, even with `AROS_ENABLE_LEGACY_PIPELINE=OFF`, and
refreshed the shared `cmake-build-debug/legacy-main` configuration. Disabling
wrapper targets does not yet remove that dependency. Thus the header parity result
is not a clean-build independence claim; future isolated repository probes should
use a separate configuration snapshot rather than the shared reference directory.

### External Source Preparation

Selected program `%fetch` prerequisites now use shared manifest translation in
`cmake/AROSFetchTargets.cmake`, not per-package registrations. Ninja invokes a
Python helper directly for acquisition, extraction and ordered patching. Names,
paths, suffix/origin order and patch options come from the manifest and upstream
macro defaults. Declared archive caches can be read, but legacy extracted trees
are never adopted. New downloads and patched sources stay in the native build.

This currently needs a preparation pass: the first build prepares sources and
reports that another build is needed. The next ordinary build discovers the
receipt, reconfigures, and registers the real compile/header dependency graph.
Archive/patch changes may require the same handoff. Downloads do not run during
configuration; this is not yet a single-command clean bootstrap. Settled builds
are no-ops. Managed extracted sources must be changed through their archive or
patch, not edited in place; source receipts authorize exact files and compilation
rejects modified inventories/content.

Include producers now retain fetch ownership through metadata aliases and
intermediate include producers, including multi-manifest aggregates. They publish
the same fetch closure before and after preparation, so an outer consumer waits
for every source receipt before expanding headers. The existing prerequisite
registry still validates recipes and rejects cycles. Ownership is not inferred
from arbitrary CMake dependency edges or pre-existing files.
Same-manifest include declarations remain concrete producers rather than being
flattened to their prerequisite leaves, so their own header copies are retained.

Program source preparation now has a metadata-only pass through aliases and
include prerequisites too. It gathers all required fetch receipts before source
collection, without registering prerequisite executables or expanding header
lists while their sources are absent. Prerequisite programs retain their own
source ownership; registered runtime/interface producers remain boundaries.
The full prerequisite registry still supplies the actual staging/build order
and rejects unsupported producers or recipes.

Exported aliases stay global lookup points even when declared beside a consumer.
The shared metadata-edge reader preserves additions from other manifests instead
of flattening an alias to just its local dependencies. The fetch regression checks
ordinary-build discovery of a second archive/source tree, both initial and
changed-source preparation, include outputs, no-op builds, removed authorization,
cycles, unsupported recipes and isolation of prerequisite-program sources.

Verification on 2026-09-06 passes all 18 isolated regression scripts plus the
dedicated include fixture. The isolated bzip2 header target settles without
reconfiguration; both staged headers and a direct native-source `bzip2.o`
compilation match the workspace legacy reference byte-for-byte. This uses
prepared tools/SDK and reference configuration, not a complete executable link,
independent bootstrap or new hosted-session validation.

Ordinary linklibs propagate fetch receipts from both their own manifest
prerequisites and local header declarations to the archive builder. Library-owned
preparation follows aliases and cross-manifest augmentations and works without
any local header-copy declarations. Prerequisite executables and libraries retain
their private source ownership, including libraries not yet registered.
A tracked context binds `TOP`, `TARGETDIR`
and `GENDIR` to native build paths. The builder verifies receipts before compiling
C/assembly sources or accepting explicit object inputs. Removing the fetch edge
rejects leftover native target-tree files. With receipts active, other inputs
must be source-tree files, not generated/reference inputs. Libraries without
receipts retain older external-source compatibility outside the native target
tree; the explicit legacy generated-header adapter retains its old context.
This does not yet propagate fetch ownership through every producer type or
translate every non-fetch linklib prerequisite. Broad transitional SDK aliases,
generated-header recipes and configuration/sysroot coupling still require migration.

The linklib fixture verifies fetched C/assembly/object changes, same-stem object
collision handling, modified-content rejection at compilation, removed fetch
edges and no-op builds. A direct replay of the unchanged Codesets linklib from
its verified native source tree produces `autoinit-aros.o` byte-identical to the
reference. This uses prepared tools/SDK and reference configuration/sysroot;
it does not establish the complete Codesets prerequisite graph or a clean build.
The include fixture also checks indirect preparation, multiple receipts, shared
aliases, cross-manifest include aggregates, new upstream edges and rejected
cycles/recipes. The retained legacy header stager uses a build-tree lock to avoid
concurrent libraries racing to copy the same file; native copies continue to use
shared Ninja producers instead.

Library-owned preparation is covered by clean headerless builds, archive edits,
missing-source/archive recovery, newly discovered second-source manifests,
removed ownership, private-library isolation, cycles and no-op checks. The 18
broader regressions and dedicated include fixture pass. A direct build of
`libbz2_nostdio.a` from native receipt-owned sources produces all seven members
byte-identical to the workspace reference, without establishing archive-container
parity or the full bzip2 build graph.

The unchanged zlib `%fetch` declaration now prepares 185 native files. Their
contents match the reference source tree, apart from a legacy-only patch backup;
native ownership markers are separate control files. The settled target is a
no-op without reconfiguration. The archive compiler now handles nested
`ifneq`/`findstring` conditions through the shared balanced evaluator and reads
assignment-only source option fragments in declaration order. Parsed option
files are depfile inputs; the isolated archive fixture verifies option-driven
flag/source edits, missing-output recovery, rejected unsafe/unsupported inputs
and settled no-op builds. This is not general included-recipe execution or full
option-controlled prerequisite-graph support.

A direct `libz.static.a` replay from native receipt-owned sources succeeds.
Its 21 member names/order match the reference and 20 members are byte-identical.
The remaining `inflate.o` uses the optimized source selected by the current
manifest; the reference depfile names generic `inflate.c`. A diagnostic compile
of that generic file with the native command matches the reference object.
No source override was added to hide this discrepancy. Fresh legacy parity
verification remains open. The replay uses prepared tools and reference
configuration/sysroot headers, including generated `zconf.h`; the complete
native generated-header/prerequisite graph and hosted Workbench milestone are
not established by this archive check.

`cmake/AROSTextTransforms.cmake` now provides a native local-rule primitive for
manifest-declared text generation. It accepts one owned source, local alias
dependencies, optional guarded directory setup and single-quoted sed
substitutions with `/` or `|` delimiters and optional `g`. Sed runs directly,
without a shell; scripts, command-execution/file-writing flags, escaped
delimiters and unsupported recipes are rejected. Native fetch receipts can
authorize external inputs. Build-time ownership/path checks and atomic output
publication prevent failed transforms from replacing valid files.

The unchanged zlib header/pkg-config rules generate `zconf.h` and `zlib.pc`
byte-identical to the workspace reference copies in an isolated native tree.
`aros-text-transforms-check` covers rebuilds, missing-output/setup recovery,
literal dollar data, no-op builds, unsafe recipes, symlinks and fetch ownership.
Include targets now register local and named transform prerequisites through
the shared registry after discovering their complete manifest-declared fetch
closure. Programs depending on those includes wait for generated headers and
rebuild when they change. Assignment-only options can control dependency edges
and recipes; edits trigger ordinary-build reconfiguration. Nested include
producers must establish their own source ownership rather than borrowing an
outer consumer's sibling fetch. Unsupported recipes and removed authorization
remain errors.

`aros-include-transforms-check` (also part of `aros-includes-check`) verifies this
graph, consumer rebuilds, newly imported/removed manifests, no-op builds and
ownership boundaries. The unchanged zlib local `includes-copy` declaration now
stages `zlib.h` and `chromeconf.h` and builds its declared `zlib.pc` prerequisite
without separately supplying generator names or fetch targets; those outputs
match the reference SDK. Its separate module include aggregate and `zconf.h`
producer still need integration. These checks do not establish a complete native
zlib SDK graph or remove the prior archive probe's reference-header dependency.

Fetch scalars follow genmf's last-value-wins behavior; other macro translators
still reject duplicates. Source-owned, assignment-only option includes are read
at their declaration point and tracked for recipe/reconfiguration changes.
Nested includes, conditionals, recipes and metadata inside those option files
remain unsupported. Legacy `base` is a marker/patch-cache location, not an
extraction root: native control files replace it without writing there.
Extraction uses the final `destination`. A missing safe patch subdirectory falls
back to the extraction root with a diagnostic, matching legacy `do_patch`;
traversal and existing non-directory paths remain errors.

Supported inputs are regular-file/directory tar.gz, tar.bz2, tar.xz, tgz and zip
archives; local/HTTP(S)/FTP origins and the upstream `cache://` mapping; local
unified patches with relative subdirectories and `-f`/`-pN` options. Selecting a
fetch requires Python 3.8+ and `patch`. Archive/receipt paths support ordinary
spaces, but patch paths retain stricter validation. Links, traversal, unowned outputs and
unsupported recipe/options fail explicitly. Failed extraction/patching does not
publish a partial source tree. Recorded SHA-256 hashes describe downloaded and
generated content, not an authenticated upstream checksum policy.

`aros-fetch-check` exercises the preparation/reconfigure/compile handoff,
rebuilds, missing outputs, ownership and unsafe archives/patches; it is also run
by `aros-programs-check`. The unchanged bzip2 fetch produces 56 files identical
to the workspace reference, with a settled no-op build. Isolated native program
compilation also produces byte-identical `bzip2.o` and `bzip2recover.o`. General
transitive fetch dependencies, remaining external module/linklib/include consumers, other
archive/protocol/patch forms and complete runtime packaging remain work. These
checks do not establish full-system parity or a usable hosted Workbench.
The combined program, code-generation, hosted-metadata, static-graph, and
manifest-reconfiguration targets pass with no main-graph regeneration
(`/tmp/aros-nix-checks-final.log`). These tests and the object parity replay do
not establish a complete native program aggregate or usable hosted Workbench.

Program-local copy/setup prerequisites now use the shared strict static-data
translator, including supported copy patterns. Exported external aliases also
follow local ordinary rules, while explicit `#MM` edges remain global so newly
added layers can augment them. Native producers are required even if stale
output files exist. Unsupported recipes, generated inputs, escaping paths,
conflicting output owners, and executable dependency cycles still fail.

Both aggregate and individual executable targets build their static
prerequisites. Copy-only edits rebuild staging without relinking executables;
manifest/layer additions and removals refresh the graph on an ordinary build.
`aros-programs-check` exercises these cases in `mmake_program_static.cmake`,
including shared outputs, setup recovery, cross-manifest dependencies, and
no-op builds. This is not general Make recipe interpretation or a complete
runtime packaging graph.

An isolated CMake/Ninja build of the unchanged Demos copy rule produces a
`Demos/forkbomb` byte-identical to both the source and workspace legacy copy,
followed by a no-op build. The file is copied, never executed. Probe artifacts
and logs are under `/tmp/aros-real-program-static*`; the broader metadata
preflight is logged in `/tmp/aros-program-static-preflight.log`.
The settled shared build passes `aros-programs-check`,
`aros-program-codegen-check`, `aros-hosted-metadata-check`,
`aros-static-graph-check`, and `aros-manifest-reconfigure-check` without
main-graph regeneration (`/tmp/aros-program-static-checks-final.log`).
The first run overlapped CLion auto-reload and was not used as the final
verification result.

Custom object directories must expand to normalized absolute paths inside the
native build and outside the legacy reference tree; whitespace, unresolved
syntax, escaped symlinks, and conflicting producers are rejected. Omitting
`objdir` preserves the existing private object layout. `<mmake>_OBJDIR`, `_OBJS`,
and `_DEPS` expose the selected directory without rebinding global `OBJDIR`,
so `objdir=$(OBJDIR)/test` and global generated inputs remain distinct.
Supported parser-generation rules can write into either namespace. Compilation
rechecks object and depfile containment in case symlinks change after configure.

The program regressions cover custom directories, named depfiles, header and
grammar rebuild isolation, configuration/manifest edits, missing-output recovery,
producer conflicts, path safety, and no-op builds. A direct isolated NBalance
test compilation produces four byte-identical legacy-reference objects and a
fifth differing only in five build-date bytes. This uses the prepared compiler
and native SDK, not a clean bootstrap, full program link, or aggregate build.

No configuration choice was installed in the active cache. `aros-programs-native`
and its dependent run target remain blocked. Discovery failures leave unrelated
targets configurable; later producer-registration errors may fail configuration
itself. The successful subset build/run results below precede this graph
expansion and do not verify the new aggregate.

Verification for this discovery checkpoint: `aros-programs-check`,
`aros-hosted-metadata-check`, `aros-static-graph-check`, and
`aros-manifest-reconfigure-check` pass. Coverage includes preserved cyclic
reachability, rejected concrete build cycles, manifest-driven graph refresh,
compiler-role selection, actual fixture compilation, and no-op builds.
The object-directory checkpoint reran all four successfully, plus the separate
`aros-program-codegen-check`. Logs: `/tmp/aros-objdir-checks-final.log` and
`/tmp/aros-objdir-codegen-final.log`. The ordinary default program build still
reports the configuration placeholder without reconfiguration, recorded in
`/tmp/aros-objdir-default-diagnostic.log`.

The active development build is `cmake-build-debug`, configured for
`AROS_TARGET=linux-x86_64` with `AROS_BUILD_HOSTED_BOOTSTRAP=ON`. It currently
reuses an installed AROS compiler, legacy-generated configuration assignments,
and some previously extracted external sources. These commands describe an
incremental build in that prepared tree, **not a verified clean bootstrap**:

```bash
cmake --build cmake-build-debug --target \
  aros-hosted-bootstrap-native aros-hosted-boot-modules-native \
  aros-core-modules-native aros-programs-native aros-runtime-data-native -j 6
cmake --build cmake-build-debug --target aros-hosted-boot-load-check
```

`aros-hosted-bootstrap-native` builds the launcher and its configuration.
`aros-hosted-boot-modules-native` builds the ordered upstream boot module set,
including the linked hosted kernel. The load check relocates all 34 configured
modules in non-executing buffers; it does not boot AROS.
`aros-core-modules-native` builds the three CRT runtime libraries needed after
DOS starts. The verbose run target now also depends on that aggregate; this
does not yet cover the full dynamically loaded runtime dependency graph.

Selected program packaging includes `C/` commands, `L/UserShell-Seg`,
`L/pipe-handler`, `System/CLI`, `System/FixFonts`, the X11 monitor/icon, DOS
catalogs, and generated parser dependencies. Runtime data includes the five
`S/` scripts, Mountlist, the manifest-selected DOSDrivers files and Workbench
setup directories, the base font files, and the manifest-generated `AROS.boot`
CPU signature.
`AROS_NATIVE_PROGRAM_RULES` is obsolete and removed on reconfiguration.
Program discovery reads `defaulttarget` from `mmake.config.in`; the optional
`AROS_NATIVE_PROGRAM_ROOT` overrides that single aggregate, not a program list.
`AROS_NATIVE_STATIC_RULES` still selects migrated static-data entrypoints;
that remaining curated profile is migration debt, not the intended end state.
`AROS_NATIVE_LOCAL_STATIC_RULES` defaults to `boot;workbench-fonts-quick`.
These exported local rules supply the signature and base fonts only, not every
dependency of the global `#MM boot` or `workbench-fonts` aggregates.

Program discovery follows active exported edges across all discovered
manifests, including additions to an aggregate that also has a local program
producer. It projects reachable target-side `%build_prog`/`%build_progs`
identities, excluding host programs. It does not translate other macro kinds
or claim their implicit edges are complete. Manifest additions, removals,
edits and configuration changes refresh the graph on an ordinary build.
Cross-file program prerequisites are passed to the native dependency finalizer
for compile/link ordering, including every part of shared-identity producers.
No partial program aggregate is registered if discovery fails; the build
prints the saved diagnostic instead of accepting stale outputs. After
discovery, unsupported program features and missing native dependencies
remain errors. Multiple producer manifests are grouped, variable identities
are resolved, and duplicate executable destinations are rejected.
Discovery preserves unknown compiler-only assignments rather than choosing a
conditional branch. Unknown identities, producer presence, exported edges,
compiler selection and conditional includes still fail; compilation consumers
remain strict. Quoted/nested macro arguments are split before expansion, and
semicolon-bearing conditions remain data. Neither repository scripts nor Make
shell expressions are executed by discovery. This does not implement the
remaining program compilation or generated-input translation.

Candidate patterns and manifest parses are cached within one traversal.
Ordinary-rule prerequisites need an active export before joining the global
graph; local files and inactive declarations cannot satisfy that check through
a candidate pattern alone. Saved diagnostics are literal text, retaining
unexpanded `@...@` placeholders. `aros-programs-check` includes both the graph
build/reconfiguration fixture and the focused `mmake_graph_metadata.cmake`
fixture, including the real AboutAROS manifest and strict-consumer checks.
The main program, static-graph, hosted-metadata, and manifest-reconfiguration
check targets pass (`/tmp/aros-native-graph-checks.log`). The settled ordinary
`aros-programs-native` build reports the exact configuration placeholder
without regenerating CMake (`/tmp/aros-native-graph-final.log`); this remains a
failed system build, not milestone completion.

The native-configuration increment adds `mmake_native_config.cmake` to
`aros-programs-check` and extends the linklib fixture. Isolated configuration,
graph, program/dependency, host/module metadata, static-graph, manifest-refresh,
and kickstart regressions pass under `/tmp/aros-native-config-*`. The initial
shared check invocation overlapped CLion auto-reload and was stopped; it is not
a verification result. The settled retry of `aros-programs-check`,
`aros-hosted-metadata-check`, `aros-static-graph-check`, and
`aros-manifest-reconfigure-check` passes through CLion's CMake/Ninja
(`/tmp/aros-native-config-checks-final.log`). Program/startup contexts preserve
literal configuration paths, including `@...@` text. No new hosted run or
full-system parity was performed.

The static-data defaults select `workbench-s`, `workbench-devs-mountlist`, and
`workbench-directories`. Guarded flat-directory copies are translated into
individual Ninja outputs with configure-aware source inventories. The optional
directory and its non-hidden files can appear/disappear on an ordinary build;
file edits rebuild and missing outputs recover. Empty existing directories,
subdirectories, unowned/local-generated sources, unsafe destinations, and
unsupported commands/options fail explicitly. Removing a source drops its
producer but does not delete a previously staged file, matching legacy CP.
This is bounded metadata translation, not a shell interpreter or recursive
copy facility. Explicit double-colon directory setup and space-indented
`%mkdirs_q` are supported without duplicate directory outputs from file copies.
`aros-static-graph-check` includes the directory inventory/ownership regression.

The base fonts come from nested `foreach`/`filter-out` expressions and the
`$(call WILDCARD,...)` helper in the unchanged `workbench/fonts/mmakefile`.
CMake validates that helper's regular-file-only definition and inventories
owned source files without executing its shell body. Globs are bounded to
filenames in literal source directories; implicit hidden entries are excluded
from the inventory. Reachable `destination/% : %` rules with a single CP recipe
and existing source are instantiated as Ninja outputs. Ambiguous patterns,
generated chains, unsafe paths, and unsupported implicit-recipe searches fail
explicitly. Source additions/removals and helper configuration edits reconfigure
on an ordinary build; content edits and missing outputs rebuild. The static
graph check also exercises this translation against the real font manifest.
Localized/external font producers and the full global font aggregate remain
unmigrated. No font-group or filename list was duplicated in CMake.

For these programs, `cmake/AROSMmakeConfig.cmake` reads the existing configuration
snapshot in upstream include order. Immediate assignments stay immediate;
recursive assignments and appends retain their Make semantics. This fixes an
incorrect late lookup of `CONFIG_WARN_CFLAGS` that added `-Wall -Werror` and
rejected the unchanged SetPSM source. Includes are tracked for reconfiguration,
including the appearance of optional configuration files. The reader does not
execute configuration recipes or shell helpers; unsupported consumed values
fail explicitly. This still reads legacy-generated configuration, not a native
replacement for configure, and other module/link-library readers remain
transitional.

For interactive diagnosis on a Linux desktop with an accessible X11 display:

```bash
cmake --build cmake-build-debug --target aros-hosted-run-verbose
```

Alternatively, launch `./boot/linux/AROSBootstrap --verbose` from
`cmake-build-debug/bin/linux-x86_64/AROS`. The launcher forks a kernel child;
bounded tests must terminate the process group, not just its waiting parent.
`--verbose`/`-v` enables existing bootstrap and boot diagnostics; an explicit
`sysdebug=Init` argument narrows the default trace. The future buffered syslog
and matching in-OS log display are not implemented; ApolloOS is unchanged.
On large multi-monitor desktops, adding `--forcestdmodes` uses the X11 driver's
standard modes instead of opening a desktop-sized AROS window.

The CRT compile failures are repaired in shared CMake glue: layer overrides
match by object basename and resolve the declared relative source path; libc
headers remain in the legacy SDK namespaces instead of synthetic flat aliases
that hid POSIX declarations such as `EISDIR` and `putenv`. No CRT-specific
include workaround or legacy manifest/source changes are needed.

The first successful CRT build exposed a later runtime failure: DOS reaches
`RTF_AFTERDOS` and loads `stdlib.library`, but repeated `m.library` initialization
overflows the Boot Mount stack. A declared math-layer `fenv` implementation had
been silently omitted. The resolver now supports the manifest-directory source
fallback used by legacy VPATH and rejects missing layer additions; source-local
flags use the same resolution. `aros-crt-metadata-check` covers these cases and
the actual target-compiler header probe. The rebuild passed and `fenv.o` matches
legacy byte-for-byte, but linking still forced public names from genmodule's
entrypoint list, pulling self-call stubs for renamed/inline implementations.
Legacy resident linking does not use that list. CMake now leaves retention to
the resident function table and preserves explicit manifest link options.
`aros-crt-link-check` rejects a math library with a self-dependency or missing
floating-point environment implementations. It rejects the old native link and
passes the rebuilt native library. The combined core-module, hosted-module,
launcher, selected-program, and runtime-data build passes, as do both CRT
checks. Its next ordinary build reports `ninja: no work to do` without
reconfiguration. All 34 boot modules relocate, and the boot-trace regression
passes. Logs: `/tmp/aros-crt-final-stable.log`,
`/tmp/aros-crt-final-noop.log`, `/tmp/aros-crt-final-load-trace.log`.

Two bounded 30-second native launches now pass math initialization, start the
monitor driver, and reach console/CLI setup without the former recursive load
or stack overflow. The X11 screenshot shows a `1>` shell prompt, but startup
reports missing `SetClock`, `FailAt`, `If`, `MakeDir`, and `EndIf`, then
`Can't find RAM:ENV`. This is a visible shell checkpoint, not a completed
startup or an interaction-tested usable session. Both timeout runs leave no
bootstrap processes. The trace is `/tmp/aros-hosted-after-link-fix-display.log`
and the screenshot is `/tmp/aros-hosted-after-link-fix.png`.

Resident-module linking now selects the native SDK as its sysroot: the previous
legacy sysroot could override explicit native `-L` paths through compiler specs.
The math test link selects native support archives plus the compiler's own
`libgcc`. General archive ownership enforcement and other legacy configuration/
SDK bridges remain migration work.

The module compiler now asks the selected compiler for its builtin include
directory and places it before SDK system-header fallbacks. Previously, those
fallbacks selected AROS `float.h` ahead of GCC's header and overflowed `LDBL_MAX`;
math text/data/bss was 228828/8/16 versus legacy 228844/8/16. The revised CRT
header regression uses production flags, checks the floating-point limits and
dependency-file provenance of `float.h`/`stddef.h`, and passes alongside POSIX
declaration and host-header-isolation checks. No GCC version/path or individual
math-source workaround is hard-coded. The rebuilt math library now matches
legacy text/data/bss at 228844/8/16; `e_powl.o`, `s_catanl.o`, and `s_ctanl.o`
are byte-identical to their legacy counterparts. All sized function symbols
match. The complete binaries still differ in 5274 bytes, with differing
assembly/archive placement and library-ID build dates, so strict binary parity
is not established.

At the compiler-header checkpoint, the combined hosted/core/program/data rebuild and CRT checks passed
(`/tmp/aros-header-order-rebuild.log`), including all 34 boot relocations.
The next unchanged aggregate build reports `ninja: no work to do` without
regeneration (`/tmp/aros-header-order-noop.log`); boot-trace tests pass too
(`/tmp/aros-header-order-trace-check.log`). Non-fatal macro-redefinition warnings
remain, but the floating-constant overflow warnings are absent. A separate
AROS session was already running before the planned GUI smoke test and was
left untouched; this increment adds no new agent-verified launch claim.

The expanded startup-command profile now builds successfully with the hosted
launcher, boot modules, core modules, and runtime data. All 34 boot modules
relocate, CRT metadata/header/link and boot-trace checks pass, and the next
ordinary aggregate build reports `ninja: no work to do` without regeneration.
Logs: `/tmp/aros-startup-commands-verified-build.log`,
`/tmp/aros-startup-commands-noop.log`, `/tmp/aros-startup-crt-trace-checks.log`.
Program dependency/configuration, existing program/startup/icon, host/module,
kickstart, linklib, static-graph, and manifest-reconfiguration fixtures pass too.

Of the 86 newly selected core/shell commands, 48 are byte-identical to the
workspace legacy reference, including HDTool and SetPSM. The other 38 differ
only in three embedded build-date bytes (`06.09.2026` versus `12.03.2026`);
normalizing that date in memory makes them identical. File and text/data/bss
sizes match for all 86. Details: `/tmp/aros-startup-parity.log`.

Two subsequent bounded launches pass the former missing-command/RAM:ENV
failure. The standard-mode run reports missing `SYS:Classes`, `SYS:Fonts`, and
`DEVS:Printers`, then waits at a Mount Failure requester showing `ERROR`.
`DEVS:DOSDrivers`, passed to Mount by Startup-Sequence, is also absent from the
native tree. Screenshot: `/tmp/aros-hosted-startup-standard-modes.png`; console
trace: `/tmp/aros-hosted-startup-standard-modes.log`. Both runs were terminated
at the intended 30-second limit, with no bootstrap processes left behind.
The requester prevented shell interaction testing. Continue native manifest
support for runtime data and dynamic-module producers, not empty-directory
workarounds or copied legacy outputs. Startup and a usable session remain open.
Full-system parity and a clean build independent of legacy scaffolding remain
open. Requested diagnostic source changes intentionally differ from the
unmodified legacy binaries.

The earlier runtime-data increment stages Mountlist and seven DOSDrivers files,
all byte-identical to source and workspace legacy copies. Workbench's declared
setup directories are created natively. This passes the former Mount requester,
then initially exposed a Path crash after the missing `SYS:System` directory.
The existing Path code retains a NULL insertion predecessor after a missing
path; native and legacy Path differ only in their embedded date. No Path source
workaround was added. Selecting the upstream System and pipe program producers
builds CLI, FixFonts, and pipe-handler, all byte-identical to legacy, and removes
that startup crash. The combined native build passes and the next ordinary
build is a no-op without regeneration. Static graph/copy/text, program and
metadata regressions, 34 boot relocations, and boot-trace checks pass. Logs:
`/tmp/aros-runtime-packaging-verified-build.log`,
`/tmp/aros-runtime-packaging-noop.log`, `/tmp/aros-runtime-packaging-checks.log`.

A subsequent bounded boot verifies keyboard interaction: `echo
cmakenativeshellok` prints the marker, and `version` reports `Kickstart 51.51,
Workbench 40.0` before returning to the prompt. The window-specific probe
targets the X11 HIDD's inner drawable without moving desktop focus. Screenshot:
`/tmp/aros-hosted-runtime-shell-probe.png`; host trace:
`/tmp/aros-hosted-runtime-shell-probe.log`. The 30-second timeout leaves no
bootstrap processes. This is a verified interactive shell checkpoint, not a
completed hosted milestone. That checkpoint still lacked fonts and reported a
FixFonts error; the base-font increment below resolves those two symptoms.

The latest native build stages all 36 base font files, byte-identical to source
and workspace legacy copies. The full selected launcher/boot/core/program/data
build passes and its next invocation is a no-op without regeneration. Logs:
`/tmp/aros-font-runtime-verified-build.log`, `/tmp/aros-font-runtime-noop.log`.
Main-Ninja static-graph, 34-module relocation, and boot-trace checks also pass;
their log is `/tmp/aros-font-runtime-checks.log`.
The new bounded boot no longer reports missing `SYS:Fonts` or the FixFonts
failure, and produces five `.font` descriptors plus a font cache at runtime.
Shell input and `version` still work. Screenshot:
`/tmp/aros-hosted-base-fonts.png`; trace: `/tmp/aros-hosted-base-fonts.log`.
The intended 30-second timeout leaves no bootstrap processes. Classes,
Tools/Utilities, theme data and IPrefs remain missing. Finish their native
manifest-driven packaging and runtime validation before claiming usable
Workbench startup or expanding to other architectures. Full-system parity and
clean independence from legacy configuration/toolchain scaffolding remain open.

Useful regression targets:

```bash
cmake --build cmake-build-debug --target \
  aros-manifest-reconfigure-check aros-host-discovery-check \
  aros-hosted-metadata-check aros-kickstart-check \
  aros-crt-metadata-check aros-crt-link-check \
  aros-programs-check \
  aros-static-graph-check aros-static-text-check aros-runtime-graph-check \
  aros-hosted-boot-trace-check
```

The host-discovery fixture checks producer relocation, conditional selection,
plain-manifest fallback, source/configuration edits, missing-output recovery,
no-op builds, and rejection of unsupported or ambiguous producers. Bootstrap
configuration recipes are translated as a bounded declared shell-script/stdout
generator, not passed to make or a general-purpose recipe interpreter.

The earlier hosted-registration checkpoint passed its combined native
bootstrap/program/data/boot-load build, with
all 34 boot modules relocated. `AROSBootstrap.conf` and `AROS.boot` remain
byte-identical to the workspace legacy reference; the linked kernel retains
matching text/data/bss sizes (157823/144/1064), not a claim of binary identity.
All 17 launcher/loader objects also match their pre-registration-refactor
versions after stripping debug metadata. Catalog and program-code-generation
regressions pass with the updated shared manifest reader.
The stable shared-tree retry also passed the complete native build, the
34-module load check, and the boot-trace regression. The following ordinary
bootstrap/boot-module/program/data build reported `ninja: no work to do`
without reconfiguration. The earlier attempt lost completed Ninja-log records
during concurrent build-tree activity; that attempt was not valid incremental
evidence. Logs from the stable retry are `/tmp/aros-arch-final-incremental.log`,
`/tmp/aros-arch-final-load-trace.log`, and `/tmp/aros-arch-final-noop.log`.

Avoid concurrent CLion auto-reload and command-line builds in the same build
directory. After changes, verify an ordinary second build reports
`ninja: no work to do` without reconfiguration. Compare newly migrated artifacts
against the legacy reference immediately; size equality alone is not byte parity.

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

## Build (Legacy And Tool Targets)

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
