cmake_minimum_required(VERSION 3.12)
project(libudis86 LANGUAGES C)

set(CMAKE_C_STANDARD 99)
find_package(Python3 REQUIRED COMPONENTS Interpreter)

set(_udis86_optable "${CMAKE_CURRENT_SOURCE_DIR}/../docs/x86/optable.xml")
set(_udis86_codegen_script "${CMAKE_CURRENT_SOURCE_DIR}/../scripts/ud_itab.py")
set(_udis86_codegen_dep "${CMAKE_CURRENT_SOURCE_DIR}/../scripts/ud_opcode.py")
set(_udis86_gen_root "${CMAKE_CURRENT_BINARY_DIR}/generated")
set(_udis86_gen_dir "${_udis86_gen_root}/libudis86")
set(_udis86_gen_itab_c "${_udis86_gen_dir}/itab.c")
set(_udis86_gen_itab_h "${_udis86_gen_dir}/itab.h")

add_custom_command(
  OUTPUT "${_udis86_gen_itab_c}" "${_udis86_gen_itab_h}"
  COMMAND "${CMAKE_COMMAND}" -E make_directory "${_udis86_gen_dir}"
  COMMAND "${Python3_EXECUTABLE}" "${_udis86_codegen_script}" "${_udis86_optable}" "${_udis86_gen_dir}"
  DEPENDS "${_udis86_optable}" "${_udis86_codegen_script}" "${_udis86_codegen_dep}"
  COMMENT "Generating udis86 instruction tables"
  VERBATIM
)

add_library(libudis86 STATIC
  decode.c
  syn-att.c
  syn-intel.c
  syn.c
  udis86.c
  "${_udis86_gen_itab_c}"
  "${_udis86_gen_itab_h}"
)

target_include_directories(libudis86
  PUBLIC
    "${CMAKE_CURRENT_SOURCE_DIR}"
    "${_udis86_gen_root}"
    "${_udis86_gen_dir}"
    "${CMAKE_CURRENT_SOURCE_DIR}/.."
)
target_compile_definitions(libudis86
  PRIVATE
    __AROS__
    HAVE_STRING_H
    HAVE_STDINT_H
    HAVE_INTTYPES_H
    HAVE_STDARG_H
    HAVE_ASSERT_H
)
