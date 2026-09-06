cmake_minimum_required(VERSION 3.20)
if(NOT TEST_BINARY_DIR)
  message(FATAL_ERROR "Set TEST_BINARY_DIR to an isolated test directory")
endif()
get_filename_component(AROS_SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
include("${AROS_SOURCE_DIR}/cmake/AROSMmakeBuild.cmake")
set(AROS_TARGET linux-x86_64)
set(AROS_TARGET_FAMILY unix)
set(AROS_CONFIG_BUILD_DIR "${TEST_BINARY_DIR}/config")
file(MAKE_DIRECTORY "${AROS_CONFIG_BUILD_DIR}/bin/${AROS_TARGET}/gen/config")
file(WRITE "${AROS_CONFIG_BUILD_DIR}/bin/${AROS_TARGET}/gen/config/target.cfg"
  "FAMILY := unix\nNOSTARTUP_LDFLAGS := -nostartfiles\n")
set(_AROS_MMAKE_VAR_KOBJSDIR "${TEST_BINARY_DIR}/kobjs")
set(_AROS_MMAKE_VAR_AROSARCHDIR "${TEST_BINARY_DIR}/AROS/boot/linux")
set(MODULE_PATH arch/all-unix/boot)
set(MODULE_MMAKE_NAME kernel-link-unix)
set(CONTEXT_FILE "${TEST_BINARY_DIR}/context.cmake")
file(WRITE "${CONTEXT_FILE}" "")
foreach(_var IN ITEMS AROS_SOURCE_DIR AROS_CONFIG_BUILD_DIR AROS_TARGET AROS_TARGET_FAMILY
    MODULE_PATH MODULE_MMAKE_NAME _AROS_MMAKE_VAR_KOBJSDIR _AROS_MMAKE_VAR_AROSARCHDIR)
  file(APPEND "${CONTEXT_FILE}" "set(${_var} [==[${${_var}}]==])\n")
endforeach()
set(OUTPUT_FILE "${TEST_BINARY_DIR}/metadata.cmake")
include("${AROS_SOURCE_DIR}/cmake/collect_mmake_kickstart.cmake")
include("${OUTPUT_FILE}")
set(_expected "${_AROS_MMAKE_VAR_KOBJSDIR}/kernel_resource.o;${_AROS_MMAKE_VAR_KOBJSDIR}/exec_library.o;${_AROS_MMAKE_VAR_KOBJSDIR}/task_resource.o")
if(NOT KICKSTART_OBJECTS STREQUAL _expected
   OR NOT KICKSTART_OUTPUT STREQUAL "${_AROS_MMAKE_VAR_AROSARCHDIR}/kernel"
   OR NOT KICKSTART_LINK_OPTIONS STREQUAL "-nostartfiles;-noclibs;-nosysbase;-Wl,-Ur"
   OR NOT KICKSTART_LIBS STREQUAL "stdc.static")
  message(FATAL_ERROR "Hosted kickstart metadata mismatch")
endif()

file(WRITE "${TEST_BINARY_DIR}/mmakefile.src" [=[
LIBS := first second
ifeq ($(CPU),x86_64)
%link_kickstart mmake=test file=kernel startup=start.o \
  res=task libs=$(LIBS) devs=timer classes=gadget hidds=gfx handlers=ram
else
%link_kickstart mmake=test file=wrong startup=wrong.o
endif
]=])
set(MODULE_MMAKE_NAME test)
_aros_parse_mmake_module("${TEST_BINARY_DIR}/mmakefile.src")
if(NOT MODULE_MMAKE_KICKSTART_libs STREQUAL "first;second"
   OR NOT MODULE_MMAKE_KICKSTART_file STREQUAL "kernel"
   OR NOT MODULE_MMAKE_KICKSTART_handlers STREQUAL "ram")
  message(FATAL_ERROR "Conditional/bare-list kickstart parsing failed")
endif()

# Do not silently accept upstream options that the native linker cannot honor.
file(MAKE_DIRECTORY "${TEST_BINARY_DIR}/unsupported")
file(WRITE "${TEST_BINARY_DIR}/unsupported-context.cmake"
  "include([==[${CONTEXT_FILE}]==])\n"
  "set(AROS_SOURCE_DIR [==[${TEST_BINARY_DIR}]==])\n"
  "set(MODULE_PATH unsupported)\n"
  "set(MODULE_MMAKE_NAME rejected)\n")
foreach(_unsupported IN ITEMS map packfmt strip deps)
  file(WRITE "${TEST_BINARY_DIR}/unsupported/mmakefile.src"
    "%link_kickstart mmake=rejected file=kernel startup=start.o ${_unsupported}=unsupported-value\n")
  execute_process(COMMAND "${CMAKE_COMMAND}"
    "-DCONTEXT_FILE=${TEST_BINARY_DIR}/unsupported-context.cmake"
    "-DOUTPUT_FILE=${TEST_BINARY_DIR}/unsupported-metadata.cmake"
    -P "${AROS_SOURCE_DIR}/cmake/collect_mmake_kickstart.cmake"
    RESULT_VARIABLE _result OUTPUT_VARIABLE _stdout ERROR_VARIABLE _stderr)
  if(_result EQUAL 0 OR NOT _stderr MATCHES "link_kickstart ${_unsupported} is not implemented yet")
    message(FATAL_ERROR "Unsupported ${_unsupported} was not rejected: ${_stdout}${_stderr}")
  endif()
endforeach()

# Exercise localization with real binutils; the fixture supplies its own sets,
# so GNU ld can stand in for collect-aros in this narrowly scoped test.
find_program(_cc cc REQUIRED)
find_program(_ld ld REQUIRED)
find_program(_objcopy objcopy REQUIRED)
find_program(_nm nm REQUIRED)
file(MAKE_DIRECTORY "${TEST_BINARY_DIR}/tools")
foreach(_tool IN ITEMS ld objcopy nm)
  if(_tool STREQUAL "ld")
    set(_name collect-aros)
  else()
    set(_name "${_tool}")
  endif()
  file(CREATE_LINK "${_${_tool}}" "${TEST_BINARY_DIR}/tools/fixture-${_name}" SYMBOLIC)
endforeach()
file(WRITE "${TEST_BINARY_DIR}/symbols.c"
  "int SysBase, KernelBase, __INIT_LIST__, __INIT_END__, __aros_libfoo;\n")
execute_process(COMMAND "${_cc}" -c "${TEST_BINARY_DIR}/symbols.c" -o "${TEST_BINARY_DIR}/symbols.o"
  RESULT_VARIABLE _result)
if(NOT _result EQUAL 0)
  message(FATAL_ERROR "Fixture compile failed")
endif()
file(WRITE "${TEST_BINARY_DIR}/link.cmake"
  "set(AROS_TOOLCHAIN_DIR [==[${TEST_BINARY_DIR}/tools]==])\n"
  "set(AROS_TOOLCHAIN_PREFIX fixture)\n"
  "set(_module_kobj_objects [==[${TEST_BINARY_DIR}/symbols.o]==])\n"
  "set(AROS_NATIVE_PUBLIC_LIB_DIR [==[${TEST_BINARY_DIR}]==])\n"
  "set(AROS_NATIVE_PRIVATE_LIB_DIR [==[${TEST_BINARY_DIR}]==])\n"
  "set(AROS_NATIVE_REL_LIB_DIR [==[${TEST_BINARY_DIR}]==])\n")
execute_process(COMMAND "${CMAKE_COMMAND}" "-DMODULE_LINK_MANIFEST=${TEST_BINARY_DIR}/link.cmake"
  "-DKICKSTART_OUTPUT=${TEST_BINARY_DIR}/symbols-kobj.o"
  -P "${AROS_SOURCE_DIR}/cmake/link_genmodule_module.cmake" RESULT_VARIABLE _result)
if(NOT _result EQUAL 0)
  message(FATAL_ERROR "Fixture kickstart link failed")
endif()
execute_process(COMMAND "${_nm}" "${TEST_BINARY_DIR}/symbols-kobj.o"
  OUTPUT_VARIABLE _symbols RESULT_VARIABLE _result)
if(NOT _result EQUAL 0 OR NOT _symbols MATCHES " B SysBase")
  message(FATAL_ERROR "SysBase must remain externally visible")
endif()
foreach(_local IN ITEMS KernelBase __INIT_LIST__ __INIT_END__ __aros_libfoo)
  if(NOT _symbols MATCHES " b ${_local}")
    message(FATAL_ERROR "${_local} must be local")
  endif()
endforeach()
message(STATUS "Kickstart metadata and localization checks passed")
