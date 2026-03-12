cmake_minimum_required(VERSION 3.20)

project(genmf LANGUAGES C)

add_executable(genmf genmf.c)

install(TARGETS genmf RUNTIME DESTINATION bin)
