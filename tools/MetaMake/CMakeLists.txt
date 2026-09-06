include(CheckFunctionExists)
include(CheckIncludeFile)

set(PACKAGE "MetaMake")
set(PACKAGE_NAME "MetaMake")
set(PACKAGE_TARNAME "metamake")
set(PACKAGE_VERSION "0.8")
set(PACKAGE_STRING "${PACKAGE_NAME} ${PACKAGE_VERSION}")
set(PACKAGE_BUGREPORT "")
set(PACKAGE_URL "")
set(VERSION "${PACKAGE_VERSION}")
set(PROTOTYPES 1)
set(STDC_HEADERS 1)

check_include_file(dirent.h HAVE_DIRENT_H)
check_include_file(ndir.h HAVE_NDIR_H)
check_include_file(netinet/in.h HAVE_NETINET_IN_H)
check_include_file(stdarg.h HAVE_STDARG_H)
check_include_file(stdint.h HAVE_STDINT_H)
check_include_file(stdio.h HAVE_STDIO_H)
check_include_file(stdlib.h HAVE_STDLIB_H)
check_include_file(strings.h HAVE_STRINGS_H)
check_include_file(string.h HAVE_STRING_H)
check_include_file(sys/dir.h HAVE_SYS_DIR_H)
check_include_file(sys/ndir.h HAVE_SYS_NDIR_H)
check_include_file(sys/stat.h HAVE_SYS_STAT_H)
check_include_file(sys/types.h HAVE_SYS_TYPES_H)
check_include_file(unistd.h HAVE_UNISTD_H)
check_include_file(inttypes.h HAVE_INTTYPES_H)

check_function_exists(vprintf HAVE_VPRINTF)
check_function_exists(getcwd HAVE_GETCWD)
check_function_exists(strdup HAVE_STRDUP)
check_function_exists(strndup HAVE_STRNDUP)
check_function_exists(strerror HAVE_STRERROR)

set(HAVE_CONFIG_H 1)

configure_file(
  "${CMAKE_CURRENT_SOURCE_DIR}/config.h.cmake"
  "${CMAKE_CURRENT_BINARY_DIR}/config.h"
  @ONLY
)

add_executable(metamake
  cache.c
  dep.c
  dirnode.c
  io.c
  list.c
  mem.c
  mmake.c
  project.c
  var.c
)

target_include_directories(metamake PRIVATE
  "${CMAKE_CURRENT_BINARY_DIR}"
  "${CMAKE_CURRENT_SOURCE_DIR}"
)

if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
  target_link_libraries(metamake PRIVATE ws2_32)
endif()

set_target_properties(metamake PROPERTIES OUTPUT_NAME mmake)

install(TARGETS metamake RUNTIME DESTINATION bin)
