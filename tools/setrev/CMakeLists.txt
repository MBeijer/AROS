cmake_minimum_required(VERSION 3.20)

project(setrev LANGUAGES C)

add_executable(setrev setrev.c)

install(TARGETS setrev RUNTIME DESTINATION bin)
