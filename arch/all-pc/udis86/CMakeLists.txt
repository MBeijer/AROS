cmake_minimum_required(VERSION 3.12)
project(udis86 LANGUAGES C)

option(UDIS86_BUILD_UDCLI "Build udcli tool" ON)

find_package(Python3 REQUIRED COMPONENTS Interpreter)

add_subdirectory(libudis86)
if(UDIS86_BUILD_UDCLI)
  add_subdirectory(udcli)
endif()

add_library(udis86 INTERFACE)
target_include_directories(udis86 INTERFACE ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(udis86 INTERFACE libudis86)

if(COMMAND aros_register_mmake_linklib AND DEFINED AROS_LEGACY_BUILD_DIR AND DEFINED AROS_TARGET)
  set(_aros_udis86_optable "${CMAKE_CURRENT_SOURCE_DIR}/docs/x86/optable.xml")
  set(_aros_udis86_codegen_script "${CMAKE_CURRENT_SOURCE_DIR}/scripts/ud_itab.py")
  set(_aros_udis86_codegen_dep "${CMAKE_CURRENT_SOURCE_DIR}/scripts/ud_opcode.py")
  set(_aros_udis86_gen_dir "${AROS_LEGACY_BUILD_DIR}/bin/${AROS_TARGET}/gen/arch/all-pc/udis86/libudis86")
  set(_aros_udis86_gen_itab_c "${_aros_udis86_gen_dir}/itab.c")
  set(_aros_udis86_gen_itab_h "${_aros_udis86_gen_dir}/itab.h")

  add_custom_command(
    OUTPUT "${_aros_udis86_gen_itab_c}" "${_aros_udis86_gen_itab_h}"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${_aros_udis86_gen_dir}"
    COMMAND "${Python3_EXECUTABLE}" "${_aros_udis86_codegen_script}" "${_aros_udis86_optable}" "${_aros_udis86_gen_dir}"
    DEPENDS "${_aros_udis86_optable}" "${_aros_udis86_codegen_script}" "${_aros_udis86_codegen_dep}"
    COMMENT "Generating native CMake target-side udis86 instruction tables"
    VERBATIM
  )

  add_custom_target(aros-arch-udis86-genfiles-native DEPENDS "${_aros_udis86_gen_itab_c}" "${_aros_udis86_gen_itab_h}")

  aros_register_mmake_linklib(
    aros-arch-udis86-linklib-native
    MODULE_PATH "arch/all-pc/udis86"
    LIBNAME "udis86"
    # Retain the existing itab.h adapter until generated-header rules migrate.
    LEGACY_GENERATED_HEADERS
    DEPENDS
      aros-arch-udis86-genfiles-native
      "${_aros_udis86_gen_itab_c}"
      "${_aros_udis86_gen_itab_h}"
  )

  if(TARGET aros-arch-linklibs-native)
    add_dependencies(aros-arch-linklibs-native aros-arch-udis86-linklib-native)
  endif()
endif()
