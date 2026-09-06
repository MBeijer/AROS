cmake_minimum_required(VERSION 3.20)

foreach(_required AROS_BOOTSTRAP AROS_SYSTEM_DIR TEST_BINARY_DIR TEST_CC)
  if(NOT DEFINED ${_required})
    message(FATAL_ERROR "${_required} is required")
  endif()
endforeach()
get_filename_component(_source "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
file(MAKE_DIRECTORY "${TEST_BINARY_DIR}/include/exec")

# Stop at a missing module, before executing any AROS code or opening a display.
set(_config "${TEST_BINARY_DIR}/trace.conf")
set(_missing "${TEST_BINARY_DIR}/missing-boot-module")
if(EXISTS "${_missing}")
  message(FATAL_ERROR "Trace fixture requires a nonexistent boot module: ${_missing}")
endif()
function(_probe _name _config_args _expected)
  file(WRITE "${_config}" "module ${_missing}\n${_config_args}")
  execute_process(COMMAND "${AROS_BOOTSTRAP}" -m 16 -c "${_config}" ${ARGN}
    WORKING_DIRECTORY "${AROS_SYSTEM_DIR}" TIMEOUT 5
    RESULT_VARIABLE _result OUTPUT_VARIABLE _stdout ERROR_VARIABLE _stderr)
  set(_output "${_stdout}${_stderr}")
  if(NOT _result MATCHES "^[1-9][0-9]*$" OR
     NOT _output MATCHES "Failed to open" OR _output MATCHES "Entering kernel")
    message(FATAL_ERROR "${_name}: did not stop safely at the missing module (${_result}):\n${_output}")
  endif()
  if(_expected STREQUAL "quiet")
    if(_output MATCHES "Effective kernel arguments|Inspecting boot modules|Reading module")
      message(FATAL_ERROR "Quiet bootstrap unexpectedly emitted verbose diagnostics:\n${_output}")
    endif()
  else()
    string(FIND "${_output}" "[Bootstrap] Effective kernel arguments: ${_expected}\n" _found)
    string(FIND "${_output}" "[Bootstrap] Reading module ${_missing}\n" _module)
    if(_found EQUAL -1 OR _module EQUAL -1 OR NOT _output MATCHES "Inspecting boot modules")
      message(FATAL_ERROR "${_name}: missing trace or incorrect argument precedence:\n${_output}")
    endif()
  endif()
endfunction()

execute_process(COMMAND "${AROS_BOOTSTRAP}" --help RESULT_VARIABLE _result
  OUTPUT_VARIABLE _help ERROR_VARIABLE _stderr TIMEOUT 5)
if(NOT _result EQUAL 0 OR NOT _help MATCHES "--verbose" OR NOT _help MATCHES "sysdebug=")
  message(FATAL_ERROR "Bootstrap help does not document boot tracing: ${_help}${_stderr}")
endif()
set(_defaults "sysdebug=Init,InitResident,InitCode,AddTask,RamLib,LoadSeg,AddDosNode")
_probe(quiet "" quiet)
_probe(short "" "${_defaults}" -v)
_probe(long "arguments bootdelay=1\n" "bootdelay=1 ${_defaults}" --verbose)
_probe(command_override "arguments bootdelay=1\n"
  "sysdebug=Init bootdelay=1" -v sysdebug=Init)
_probe(config_override "arguments sysdebug=none\n" "sysdebug=none" --verbose)
_probe(case_override "arguments SYSDEBUG=Init\n" "SYSDEBUG=Init" -v)
_probe(not_an_override "arguments other_sysdebug=none\n"
  "other_sysdebug=none ${_defaults}" -v)

# Exercise the private boot D macro without needing to execute target-OS code.
file(WRITE "${TEST_BINARY_DIR}/include/exec/execbase.h" [=[
#define EXECDEBUGF_INIT (1UL << 30)
struct ExecBase { unsigned long ex_DebugFlags; };
]=])
file(WRITE "${TEST_BINARY_DIR}/macro.c" [=[
#if DEBUG
#define D(...) __VA_ARGS__
#else
#define D(...)
#endif
#include "rom/dosboot/bootdebug.h"
int main(void)
{
    struct ExecBase base = {0};
    struct ExecBase *SysBase = &base;
    int calls = 0;
    D(calls++;)
    base.ex_DebugFlags = 1;
    D(calls++;);
    base.ex_DebugFlags = EXECDEBUGF_INIT;
    D(calls++; calls++;)
#if DEBUG
    return calls != 4;
#elif defined(NO_RUNTIME_DEBUG)
    return calls != 0;
#else
    return calls != 2;
#endif
}
]=])
foreach(_mode runtime explicit disabled)
  set(_flags -DDEBUG=0)
  if(_mode STREQUAL "explicit")
    set(_flags -DDEBUG=1)
  elseif(_mode STREQUAL "disabled")
    list(APPEND _flags -DNO_RUNTIME_DEBUG)
  endif()
  execute_process(COMMAND "${TEST_CC}" "-I${TEST_BINARY_DIR}/include" "-I${_source}"
    ${_flags} "${TEST_BINARY_DIR}/macro.c" -o "${TEST_BINARY_DIR}/macro-${_mode}"
    RESULT_VARIABLE _result)
  if(NOT _result EQUAL 0)
    message(FATAL_ERROR "Boot diagnostic macro compilation failed: ${_mode}")
  endif()
  execute_process(COMMAND "${TEST_BINARY_DIR}/macro-${_mode}" RESULT_VARIABLE _result TIMEOUT 5)
  if(NOT _result EQUAL 0)
    message(FATAL_ERROR "Boot diagnostic enablement failed: ${_mode}")
  endif()
endforeach()
message(STATUS "Hosted boot trace options, argument precedence, quiet mode and runtime diagnostic gating passed")
