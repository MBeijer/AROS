cmake_minimum_required(VERSION 3.20)
project(AROSRuntimeFixture NONE)
include("${AROS_RUNTIME_HELPER}")
add_subdirectory(producers)
file(WRITE "${CMAKE_BINARY_DIR}/runtime/stale" "A file without a native producer\n")
aros_add_runtime_module_set(boot-modules SYSTEM_DIR "${CMAKE_BINARY_DIR}/runtime"
  MODULE_PATHS boot/kernel L/differently-named-handler)
get_target_property(_outputs boot-modules AROS_RUNTIME_MODULE_OUTPUTS)
if(NOT _outputs STREQUAL "${CMAKE_BINARY_DIR}/runtime/boot/kernel;${CMAKE_BINARY_DIR}/runtime/L/differently-named-handler")
  message(FATAL_ERROR "Runtime module ordering or paths were lost")
endif()
aros_add_runtime_module_set(incomplete SYSTEM_DIR "${CMAKE_BINARY_DIR}/runtime"
  MODULE_PATHS boot/kernel stale)
