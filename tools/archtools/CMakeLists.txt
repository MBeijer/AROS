cmake_minimum_required(VERSION 3.20)

project(archtool LANGUAGES C)

add_executable(archtool archtool.c)

install(TARGETS archtool RUNTIME DESTINATION bin)
