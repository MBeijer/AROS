cmake_minimum_required(VERSION 3.20)

project(ADFlib LANGUAGES C)

option(ADFLIB_BUILD_UNADF "Build ADFlib unadf example tool" ON)

configure_file(
  "${CMAKE_CURRENT_SOURCE_DIR}/config.h.cmake"
  "${CMAKE_CURRENT_BINARY_DIR}/config.h"
  @ONLY
)

add_library(adflib STATIC
  src/adf_hd.c
  src/adf_disk.c
  src/adf_raw.c
  src/adf_bitm.c
  src/adf_dump.c
  src/adf_util.c
  src/adf_env.c
  src/generic/adf_nativ.c
  src/adf_dir.c
  src/adf_file.c
  src/adf_cache.c
  src/adf_link.c
  src/adf_salv.c
)

target_include_directories(adflib
  PUBLIC
    "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src>"
    "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src/generic>"
    "$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}>"
    "$<INSTALL_INTERFACE:include>"
)

target_compile_definitions(adflib PRIVATE _XOPEN_SOURCE _SVID_SOURCE _BSD_SOURCE _DEFAULT_SOURCE _GNU_SOURCE)
if(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang")
  target_compile_options(adflib PRIVATE -std=gnu17 -pedantic -Wall)
endif()

if(ADFLIB_BUILD_UNADF)
  add_executable(unadf examples/unadf.c)
  target_link_libraries(unadf PRIVATE adflib)
  target_include_directories(unadf PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/src"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/generic"
    "${CMAKE_CURRENT_BINARY_DIR}"
  )
endif()

install(TARGETS adflib
  ARCHIVE DESTINATION lib
  LIBRARY DESTINATION lib
  RUNTIME DESTINATION bin
)
if(TARGET unadf)
  install(TARGETS unadf RUNTIME DESTINATION bin)
endif()

install(FILES
  src/adf_defs.h
  src/adf_blk.h
  src/adf_err.h
  src/adf_str.h
  src/adflib.h
  src/adf_bitm.h
  src/adf_cache.h
  src/adf_dir.h
  src/adf_disk.h
  src/adf_dump.h
  src/adf_env.h
  src/adf_file.h
  src/adf_hd.h
  src/adf_link.h
  src/adf_raw.h
  src/adf_salv.h
  src/adf_util.h
  src/defendian.h
  src/hd_blk.h
  src/prefix.h
  src/generic/adf_nativ.h
  DESTINATION include
)
