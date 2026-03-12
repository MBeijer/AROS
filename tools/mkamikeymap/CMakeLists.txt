cmake_minimum_required(VERSION 3.20)

project(mkamikeymap LANGUAGES C)

add_executable(mkamikeymap
  mkamikeymap.c
  config.c
  parsedescriptor.c
  writekeymap.c
)

target_include_directories(mkamikeymap
  PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}"
    "${CMAKE_CURRENT_SOURCE_DIR}/compat"
)

install(TARGETS mkamikeymap RUNTIME DESTINATION bin)
install(FILES template.akmd DESTINATION share/mkamikeymap)
