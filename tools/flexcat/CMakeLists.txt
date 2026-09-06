cmake_minimum_required(VERSION 3.20)

project(flexcat LANGUAGES C)

add_executable(flexcat
  src/main.c
  src/createcat.c
  src/createcatsrc.c
  src/createct.c
  src/globals.c
  src/readprefs.c
  src/scancd.c
  src/scanct.c
  src/scanpo.c
  src/showfuncs.c
  src/swapfuncs.c
  src/translators.c
  src/utils.c
  src/locale_other.c
)

target_include_directories(flexcat PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/src")
set_target_properties(flexcat PROPERTIES
  AROS_FLEXCAT_SOURCE_DESCRIPTION_DIR "${CMAKE_CURRENT_SOURCE_DIR}/src/sd")
target_compile_definitions(flexcat PRIVATE _GNU_SOURCE NOERRORONWARN)

if(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang")
  target_compile_options(flexcat PRIVATE -std=gnu17)
endif()

find_package(Iconv QUIET)
if(TARGET Iconv::Iconv)
  target_link_libraries(flexcat PRIVATE Iconv::Iconv)
endif()

install(TARGETS flexcat RUNTIME DESTINATION bin)
install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/src/sd" DESTINATION share/flexcat)
install(FILES
  "${CMAKE_CURRENT_SOURCE_DIR}/README"
  "${CMAKE_CURRENT_SOURCE_DIR}/COPYING"
  DESTINATION share/doc/flexcat
)
