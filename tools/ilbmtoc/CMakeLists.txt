cmake_minimum_required(VERSION 3.20)

project(ilbmtoc LANGUAGES C)

add_executable(ilbmtoc ilbmtoc.c)

install(TARGETS ilbmtoc RUNTIME DESTINATION bin)
