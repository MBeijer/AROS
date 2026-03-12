cmake_minimum_required(VERSION 3.12)
project(udcli LANGUAGES C)

add_executable(udcli udcli.c)
target_link_libraries(udcli udis86)
target_compile_definitions(udcli PRIVATE __AROS__)
