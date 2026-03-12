cmake_minimum_required(VERSION 3.20)

project(genmodule LANGUAGES C)

add_executable(genmodule
  boopsisupport.c
  config.c
  dtsupport.c
  fileread.c
  functionhead.c
  genmodule.c
  muisupport.c
  oopsupport.c
  stringlist.c
  writeautoinit.c
  writeend.c
  writefd.c
  writefunclist.c
  writegetlibbase.c
  writeincclib.c
  writeincdefines.c
  writeincinline.c
  writeincinterfaces.c
  writeinclibdefs.c
  writeincproto.c
  writelinkentries.c
  writemakefile.c
  writeskel.c
  writestart.c
  writestubs.c
  writethunk.c
  writeutils.c
)

target_include_directories(genmodule PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")

target_compile_options(genmodule PRIVATE -Wall -O2)

if(AROS_CROSSTOOLS_TARGET_CPU STREQUAL "x86_64")
  target_compile_definitions(genmodule PRIVATE LIBBASE_IN_REG)
endif()

install(TARGETS genmodule RUNTIME DESTINATION bin)
