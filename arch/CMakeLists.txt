cmake_minimum_required(VERSION 3.20)

add_custom_target(aros-arch-linklibs-native)

if(AROS_BUILD_UDIS86)
  add_subdirectory(all-pc/udis86)
endif()

set(_aros_target_crt_module_path "arch/${AROS_CROSSTOOLS_TARGET_CPU}-all/crt")
if(AROS_CROSSTOOLS_TARGET_CPU AND EXISTS "${CMAKE_SOURCE_DIR}/${_aros_target_crt_module_path}/mmakefile.src")
  aros_register_mmake_linklib(
    aros-arch-crt-romhack-linklib-native
    MODULE_PATH "${_aros_target_crt_module_path}"
    LIBNAME romhack
  )
  add_dependencies(aros-arch-linklibs-native aros-arch-crt-romhack-linklib-native)
endif()

set(_aros_arch_native_modules_default "all-hosted/hostlib")
set(
  AROS_ARCH_NATIVE_MODULES
  "${_aros_arch_native_modules_default}"
  CACHE STRING
  "Semicolon-separated arch modules enabled for native CMake migration"
)
foreach(_aros_arch_module IN LISTS AROS_ARCH_NATIVE_MODULES)
  if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${_aros_arch_module}/CMakeLists.txt")
    add_subdirectory("${_aros_arch_module}")
  endif()
endforeach()
