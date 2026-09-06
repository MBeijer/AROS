cmake_minimum_required(VERSION 3.20)
if(NOT TEST_BINARY_DIR)
  message(FATAL_ERROR "Pass an isolated TEST_BINARY_DIR")
endif()
get_filename_component(_cmake_dir "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
get_filename_component(CMAKE_SOURCE_DIR "${_cmake_dir}/.." ABSOLUTE)
include("${_cmake_dir}/AROSModule.cmake")
include("${_cmake_dir}/AROSMmakeRules.cmake")
set(AROS_TARGET linux-x86_64)
set(AROS_TARGET_FAMILY unix)
string(RANDOM LENGTH 12 ALPHABET 0123456789abcdef _id)
set(_scratch "${TEST_BINARY_DIR}/${_id}")
set(AROS_LEGACY_BUILD_DIR "${_scratch}/config")
set(AROS_NATIVE_SYSTEM_DIR "${_scratch}/runtime")
file(MAKE_DIRECTORY "${AROS_LEGACY_BUILD_DIR}/config")
file(WRITE "${AROS_LEGACY_BUILD_DIR}/config/make.cfg"
  "AROS_DIR_DEVS := Devs\nAROS_DEVS := $(AROSDIR)/$(AROS_DIR_DEVS)\n")
set(_manifest "${CMAKE_SOURCE_DIR}/arch/all-hosted/hidd/x11/mmakefile.src")
foreach(_arch IN ITEMS linux darwin)
  set(AROS_TARGET "${_arch}-x86_64")
  aros_collect_mmake_static_files("${_manifest}" hosted-X11-x11gfx _maps)
  list(LENGTH _maps_COPIES _count)
  if(NOT _count EQUAL 3)
    message(FATAL_ERROR "Expected three reachable keymap copies, got ${_count}")
  endif()
  foreach(_copy IN LISTS _maps_COPIES)
    if(_maps_${_copy}_OUTPUT MATCHES "/keycode2rawkey.table$")
      if(_arch STREQUAL "linux")
        set(_expected def-x11-keycode2rawkey.table)
      else()
        set(_expected mac-x11-keycode2rawkey.table)
      endif()
      if(NOT _maps_${_copy}_INPUTS MATCHES "/${_expected}$")
        message(FATAL_ERROR "Lost the manifest's ${_arch} keymap selection")
      endif()
    endif()
    if(NOT "${AROS_NATIVE_SYSTEM_DIR}/Devs/Keymaps/X11" IN_LIST _maps_${_copy}_DIRECTORIES)
      message(FATAL_ERROR "Directory prerequisite was not translated")
    endif()
  endforeach()
endforeach()

set(_source "${_scratch}/source")
set(_build "${_scratch}/build")
file(MAKE_DIRECTORY "${_source}/data")
configure_file("${CMAKE_CURRENT_LIST_DIR}/static-files/CMakeLists.txt"
  "${_source}/CMakeLists.txt" COPYONLY)
file(WRITE "${_source}/data/one.txt" "first input\n")
file(WRITE "${_source}/data/two.txt" "second input\n")
set(_rules [=[
INPUT = $(LATER)
LATER := one.txt
EMPTY :=
EMPTY ?= should-not-replace-empty
ifeq ($(EMPTY),)
    OUTPUT := $(AROSDIR)/data/result.txt
else
    OUTPUT := $(AROSDIR)/wrong/result.txt
endif
#MM example : assets
#MM- assets : example
assets : $(OUTPUT)
	@$(NOP)
$(OUTPUT) : $(INPUT) | setup
	@$(CP) $< $@
setup :
	%mkdirs_q $(AROSDIR)/data $(AROSDIR)/extra
# An unreachable interactive copy must not become an automatic build action.
backup : one.txt
	$(CP) $< ~/backup
]=])
file(WRITE "${_source}/data/mmakefile.src" "${_rules}")
execute_process(COMMAND "${CMAKE_COMMAND}" -G Ninja -S "${_source}" -B "${_build}"
  "-DAROS_CMAKE_DIR=${_cmake_dir}" COMMAND_ERROR_IS_FATAL ANY)

function(check_build input)
  execute_process(COMMAND "${CMAKE_COMMAND}" --build "${_build}" --target static-files
    COMMAND_ERROR_IS_FATAL ANY)
  execute_process(COMMAND "${CMAKE_COMMAND}" -E compare_files
    "${_source}/data/${input}" "${_build}/runtime/data/result.txt"
    COMMAND_ERROR_IS_FATAL ANY)
endfunction()
check_build(one.txt)
if(NOT IS_DIRECTORY "${_build}/runtime/extra")
  message(FATAL_ERROR "Directory helper outputs are missing")
endif()
file(TIMESTAMP "${_build}/runtime/data/result.txt" _before "%s")
execute_process(COMMAND "${CMAKE_COMMAND}" -E sleep 1 COMMAND_ERROR_IS_FATAL ANY)
check_build(one.txt)
file(TIMESTAMP "${_build}/runtime/data/result.txt" _after "%s")
if(NOT _before STREQUAL _after)
  message(FATAL_ERROR "Unchanged static copy rebuilt")
endif()
file(APPEND "${_source}/data/one.txt" "changed input\n")
check_build(one.txt)
execute_process(COMMAND "${CMAKE_COMMAND}" -E sleep 1 COMMAND_ERROR_IS_FATAL ANY)
string(REPLACE "LATER := one.txt" "LATER := two.txt" _updated "${_rules}")
file(WRITE "${_source}/data/mmakefile.src" "${_updated}")
check_build(two.txt)
file(REMOVE "${_build}/runtime/data/result.txt")
check_build(two.txt)
file(APPEND "${_source}/data/mmakefile.src" [=[

#MM example : $(AROSDIR)/new/added.txt
$(AROSDIR)/new/added.txt : one.txt
	$(CP) $< $@
]=])
check_build(two.txt)
execute_process(COMMAND "${CMAKE_COMMAND}" -E compare_files
  "${_source}/data/one.txt" "${_build}/runtime/new/added.txt"
  COMMAND_ERROR_IS_FATAL ANY)

function(expect_failure rules diagnostic)
  file(WRITE "${_source}/data/mmakefile.src" "${rules}")
  execute_process(COMMAND "${CMAKE_COMMAND}" -G Ninja -S "${_source}" -B "${_build}"
    "-DAROS_CMAKE_DIR=${_cmake_dir}" RESULT_VARIABLE _result
    OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
  if(_result EQUAL 0 OR NOT "${_out}${_err}" MATCHES "${diagnostic}")
    message(FATAL_ERROR "Expected '${diagnostic}', got (${_result}): ${_out}${_err}")
  endif()
endfunction()
string(REPLACE "@$(CP) $< $@" "@$(CP) $< $@\n\t@echo side-effect" _bad "${_rules}")
expect_failure("${_bad}" "Unsupported static copy recipe")
string(REPLACE "@$(CP) $< $@" "@$(CP) $< $@ && echo side-effect" _bad "${_rules}")
expect_failure("${_bad}" "Unsupported static copy recipe")
string(REPLACE "LATER := one.txt" "LATER := missing.txt" _bad "${_rules}")
expect_failure("${_bad}" "requires an existing source file")
string(REPLACE "setup :" "setup : unknown-generator" _bad "${_rules}")
expect_failure("${_bad}" "Unsupported prerequisite")
string(REPLACE "$(AROSDIR)/data/result.txt" "$(AROSDIR)/../escaped.txt" _bad "${_rules}")
expect_failure("${_bad}" "outside the native runtime tree")
set(_bad "${_rules}\none.txt :\n\t@echo generated\n")
expect_failure("${_bad}" "Unsupported prerequisite")
set(_bad "ifdef UNSUPPORTED\n${_rules}\nendif\n")
expect_failure("${_bad}" "Unsupported rule conditional")
message(STATUS "Manifest copy selection, conditions, rebuilding, no-op and unsupported-recipe checks passed")
