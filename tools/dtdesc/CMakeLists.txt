cmake_minimum_required(VERSION 3.20)

project(dtdesc LANGUAGES C)

add_library(c_iff STATIC
  c_iff/checkiff.c
  c_iff/closeiff.c
  c_iff/endchunk.c
  c_iff/filesize.c
  c_iff/fixiffsize.c
  c_iff/newchunk.c
  c_iff/newiff.c
  c_iff/newsubform.c
  c_iff/openiff.c
  c_iff/readchunkdata.c
  c_iff/readchunkheader.c
  c_iff/skipchunkdata.c
  c_iff/writechunkdata.c
)
target_include_directories(c_iff PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/c_iff")

add_executable(createdtdesc createdtdesc.c)
target_include_directories(createdtdesc PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(createdtdesc PRIVATE c_iff)

add_executable(examinedtdesc examinedtdesc.c)
target_include_directories(examinedtdesc PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(examinedtdesc PRIVATE c_iff)

install(TARGETS c_iff createdtdesc examinedtdesc
  ARCHIVE DESTINATION lib
  RUNTIME DESTINATION bin
)
install(FILES c_iff/c_iff.h dtdesc.h DESTINATION include)
install(FILES FORMAT DESTINATION share/doc/dtdesc)
