cmake_minimum_required(VERSION 3.20)

project(Zopfli LANGUAGES C)

option(ZOPFLI_BUILD_CLI "Build zopfli CLI" ON)
option(ZOPFLI_BUILD_INSTALL "Add install() rules for zopfli" OFF)

set(_zopfli_sources
  blocksplitter.c
  cache.c
  deflate.c
  gzip_container.c
  hash.c
  katajainen.c
  lz77.c
  squeeze.c
  tree.c
  util.c
  zlib_container.c
  zopfli_lib.c
)

add_library(libzopfli STATIC ${_zopfli_sources})
target_include_directories(libzopfli
  PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
    $<INSTALL_INTERFACE:include>
)
target_compile_definitions(libzopfli PRIVATE _DEFAULT_SOURCE)
set_target_properties(libzopfli PROPERTIES OUTPUT_NAME zopfli)

if(UNIX AND NOT APPLE)
  target_link_libraries(libzopfli PUBLIC m)
endif()

if(ZOPFLI_BUILD_CLI)
  add_executable(zopfli zopfli_bin.c)
  target_link_libraries(zopfli PRIVATE libzopfli)
endif()

if(ZOPFLI_BUILD_INSTALL)
  install(TARGETS libzopfli
    ARCHIVE DESTINATION lib
    LIBRARY DESTINATION lib
    RUNTIME DESTINATION bin
  )
  if(TARGET zopfli)
    install(TARGETS zopfli RUNTIME DESTINATION bin)
  endif()
  install(FILES zopfli.h DESTINATION include)
endif()
