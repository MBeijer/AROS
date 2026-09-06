cmake_minimum_required(VERSION 3.20)
if(NOT TEST_BINARY_DIR)
  message(FATAL_ERROR "Pass TEST_BINARY_DIR")
endif()
get_filename_component(_repo "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
string(RANDOM LENGTH 10 ALPHABET abcdef0123456789 _id)
set(_root "${TEST_BINARY_DIR}/${_id}")
set(_src "${_root}/src")
set(_build "${_root}/build")
file(MAKE_DIRECTORY "${_src}/commands" "${_src}/include"
  "${_src}/config-snapshot/bin/linux-x86_64/gen/config")
configure_file("${CMAKE_CURRENT_LIST_DIR}/programs/CMakeLists.txt" "${_src}/CMakeLists.txt" COPYONLY)
file(WRITE "${_src}/mmake.config.in" "defaulttarget image\n")
file(WRITE "${_src}/mmakefile.src" "#MM image : commands helper\n")
file(WRITE "${_src}/support.c" "int support(void) { return 0; }\n")
file(WRITE "${_src}/extra.h" "#define EXTRA_VALUE 1\n")
file(WRITE "${_src}/config-snapshot/bin/linux-x86_64/gen/config/target.cfg"
  "FAMILY := unix\nCPPFLAGS = $(USER_CPPFLAGS)\nCFLAGS = $(USER_CFLAGS)\nLDFLAGS = $(USER_LDFLAGS)\nNOSTARTUP_LDFLAGS := -nostartfiles\n")
file(WRITE "${_src}/commands/Main.c" "volatile int value; void _start(void) { value = 1; }\n")
file(WRITE "${_src}/commands/Helper.c" "void _start(void) {}\n")
file(WRITE "${_src}/commands/linux-script" "static script, never execute\n")
file(WRITE "${_src}/commands/extra-script" "extra static data\n")
set(_manifest [=[
USER_LDFLAGS := -nostdlib -no-pie
%build_progs mmake=commands files=Main targetdir=$(AROSDIR)/C usestartup=no
%build_prog mmake=helper progname=Helper targetdir=$(AROSDIR)/C usestartup=no
#MM commands : layer-data
commands : scripts | empty-directory
helper : scripts
scripts : $(AROSDIR)/S/start
ifeq ($(AROS_TARGET_ARCH),linux)
SCRIPT := linux-script
else
SCRIPT := missing-inactive-input
endif
$(AROSDIR)/S/start : $(SCRIPT) | setup
	@$(CP) $^ $@
setup :
	%mkdirs_q $(AROSDIR)/S
empty-directory :
	%mkdirs_q $(AROSDIR)/Empty
unreachable :
	@echo must-not-execute
]=])
file(WRITE "${_src}/commands/mmakefile.src" "${_manifest}")
set(_runtime "${_build}/output/AROS")
function(run)
  execute_process(COMMAND ${ARGN} RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
  if(NOT _result EQUAL 0)
    message(FATAL_ERROR "Command failed (${_result}): ${ARGN}\n${_out}${_err}")
  endif()
endfunction()
function(build)
  run("${CMAKE_COMMAND}" --build "${_build}" --target fixture-programs -j 4)
endfunction()
function(noop)
  execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_build}" --target fixture-programs
    RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
  if(NOT _result EQUAL 0 OR NOT _out MATCHES "no work to do" OR _out MATCHES "Re-running CMake")
    message(FATAL_ERROR "Expected unchanged graph and outputs: ${_out}${_err}")
  endif()
endfunction()
function(reject manifest pattern)
  file(WRITE "${_src}/commands/mmakefile.src" "${manifest}")
  execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_build}" --target fixture-programs
    RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
  string(REGEX REPLACE "[ \t\r\n]+" " " _message "${_out}${_err}")
  if(_result EQUAL 0 OR NOT _message MATCHES "${pattern}")
    message(FATAL_ERROR "Expected ${pattern}: ${_out}${_err}")
  endif()
endfunction()
run("${CMAKE_COMMAND}" -G Ninja -S "${_src}" -B "${_build}"
  "-DAROS_TEST_SOURCE=${_repo}" -DAROS_TEST_AUTO_PROGRAMS=ON)
build()
run("${CMAKE_COMMAND}" -E compare_files "${_src}/commands/linux-script" "${_runtime}/S/start")
foreach(_path IN ITEMS C/Main C/Helper Empty)
  if(NOT EXISTS "${_runtime}/${_path}")
    message(FATAL_ERROR "Program graph omitted ${_path}")
  endif()
endforeach()
noop()
file(TIMESTAMP "${_runtime}/C/Main" _before "%s")
run("${CMAKE_COMMAND}" -E sleep 1)
file(APPEND "${_src}/commands/linux-script" "changed without relinking\n")
build()
run("${CMAKE_COMMAND}" -E compare_files "${_src}/commands/linux-script" "${_runtime}/S/start")
file(TIMESTAMP "${_runtime}/C/Main" _after "%s")
if(NOT _before STREQUAL _after)
  message(FATAL_ERROR "Static source edit relinked its program consumer")
endif()
file(REMOVE "${_runtime}/S/start")
run("${CMAKE_COMMAND}" --build "${_build}" --target aros-programs-commands-native-Main -j 4)
if(NOT EXISTS "${_runtime}/S/start")
  message(FATAL_ERROR "Individual executable target lost its static prerequisite")
endif()
file(REMOVE_RECURSE "${_runtime}/Empty")
build()
if(NOT IS_DIRECTORY "${_runtime}/Empty")
  message(FATAL_ERROR "Missing setup-only directory was not recreated")
endif()
set(_extended "${_manifest}\nscripts : $(AROSDIR)/S/extra\n$(AROSDIR)/S/extra : extra-script\n\t@$(CP) $< $@\n")
file(WRITE "${_src}/commands/mmakefile.src" "${_extended}")
build()
run("${CMAKE_COMMAND}" -E compare_files "${_src}/commands/extra-script" "${_runtime}/S/extra")
file(TIMESTAMP "${_runtime}/C/Main" _after "%s")
if(NOT _before STREQUAL _after)
  message(FATAL_ERROR "New static rule relinked its program consumer")
endif()
noop()
file(WRITE "${_src}/commands/mmakefile.src" "${_manifest}")
file(REMOVE "${_runtime}/S/extra")
build()
if(EXISTS "${_runtime}/S/extra")
  message(FATAL_ERROR "Removed copy rule retained its producer")
endif()
# The shared static pattern translator, not the program walker, owns matching.
set(_pattern "${_manifest}\nscripts : $(AROSDIR)/S/extra\n$(AROSDIR)/S/% : %-script\n\t@$(CP) $< $@\n")
file(WRITE "${_src}/commands/mmakefile.src" "${_pattern}")
build()
run("${CMAKE_COMMAND}" -E compare_files "${_src}/commands/extra-script" "${_runtime}/S/extra")
noop()

# A newly added top-level producer augments an optional external alias. Its
# ordinary local aliases, copy rules, and setup/program prerequisites matter.
file(MAKE_DIRECTORY "${_src}/new-layer")
file(WRITE "${_src}/new-layer/data" "cross-manifest static data\n")
file(WRITE "${_src}/new-layer/LayerTool.c" "void _start(void) {}\n")
set(_layer [=[
#MM layer-data : layer-child
layer-data : assets
assets : $(AROSDIR)/S/layer
$(AROSDIR)/S/layer : data
	@$(CP) $< $@
#MM layer-child : layer-tool
#MM
layer-child :
	%mkdirs_q $(AROSDIR)/Layer
USER_LDFLAGS := -nostdlib -no-pie
%build_prog mmake=layer-tool progname=LayerTool targetdir=$(AROSDIR)/C usestartup=no
]=])
file(WRITE "${_src}/new-layer/mmakefile.src" "${_layer}")
build()
foreach(_path IN ITEMS S/layer Layer C/LayerTool)
  if(NOT EXISTS "${_runtime}/${_path}")
    message(FATAL_ERROR "Cross-manifest program prerequisite omitted ${_path}")
  endif()
endforeach()
file(MAKE_DIRECTORY "${_src}/another-layer")
file(WRITE "${_src}/another-layer/mmakefile.src"
  "#MM layer-child : extra-layer\n#MM\nextra-layer :\n\t%mkdirs_q $(AROSDIR)/ExtraLayer\n")
build()
if(NOT IS_DIRECTORY "${_runtime}/ExtraLayer")
  message(FATAL_ERROR "Local alias declaration hid another manifest's augmentation")
endif()
file(REMOVE "${_runtime}/S/layer" "${_runtime}/C/LayerTool")
run("${CMAKE_COMMAND}" --build "${_build}" --target aros-programs-commands-native-Main -j 4)
foreach(_path IN ITEMS S/layer C/LayerTool)
  if(NOT EXISTS "${_runtime}/${_path}")
    message(FATAL_ERROR "Individual program lost cross-manifest prerequisite ${_path}")
  endif()
endforeach()
file(TIMESTAMP "${_runtime}/C/Main" _after "%s")
if(NOT _before STREQUAL _after)
  message(FATAL_ERROR "New external data prerequisite relinked the program")
endif()
noop()
file(WRITE "${_src}/new-layer/mmakefile.src" "${_layer}\n#MM layer-tool : commands\n")
reject("${_manifest}" "strongly connected component")
file(REMOVE "${_src}/new-layer/mmakefile.src")
file(REMOVE "${_src}/another-layer/mmakefile.src")
file(REMOVE "${_runtime}/S/layer" "${_runtime}/C/LayerTool")
file(WRITE "${_src}/commands/mmakefile.src" "${_pattern}")
build()
if(EXISTS "${_runtime}/S/layer" OR EXISTS "${_runtime}/C/LayerTool")
  message(FATAL_ERROR "Removed external alias kept its data/program producers")
endif()
noop()

string(REPLACE "@$(CP) $^ $@" "@$(CP) -r $^ $@" _bad "${_manifest}")
reject("${_bad}" "Unsupported static copy recipe")
string(REPLACE "@$(CP) $^ $@" "@echo unsupported" _bad "${_manifest}")
reject("${_bad}" "Unsupported static prerequisite recipe")
string(REPLACE "$(AROSDIR)/S/start" "${_root}/outside" _bad "${_manifest}")
reject("${_bad}" "outside the native runtime tree")
string(REPLACE "linux-script" "missing-input" _bad "${_manifest}")
reject("${_bad}" "requires an existing source file")
string(REPLACE "scripts : $(AROSDIR)/S/start" "scripts : $(AROSDIR)/S/stale" _bad "${_manifest}")
file(WRITE "${_runtime}/S/stale" "stale output cannot replace a producer\n")
reject("${_bad}" "No local static rule")
reject("${_manifest}\nlinux-script :\n\t@echo generated\n" "cannot adopt a generated prerequisite")
string(REPLACE "scripts : $(AROSDIR)/S/start" "scripts : cycle\ncycle : scripts" _bad "${_manifest}")
reject("${_bad}" "metadata dependency cycle")
string(REPLACE "$(AROSDIR)/S/start" "$(AROSDIR)/C/Main" _bad "${_manifest}")
reject("${_bad}" "Conflicting static-file producers")
reject("${_extended}\n$(AROSDIR)/S/start : extra-script\n\t@$(CP) $< $@\n" "Conflicting static-file producers")
file(MAKE_DIRECTORY "${_root}/external")
file(WRITE "${_root}/external/input" "external source\n")
file(CREATE_LINK "${_root}/external/input" "${_src}/commands/escaped-input" SYMBOLIC)
string(REPLACE "linux-script" "escaped-input" _bad "${_manifest}")
reject("${_bad}" "requires an owned source")
file(WRITE "${_src}/commands/mmakefile.src" "${_manifest}")
build()
noop()
message(STATUS "Program static prerequisites, shared copy rules, ownership, rebuilds and no-op checks passed")
