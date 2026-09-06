cmake_minimum_required(VERSION 3.20)

project(elf2hunk LANGUAGES C)

add_executable(elf2hunk elf2hunk.c)
target_compile_definitions(elf2hunk PRIVATE DEBUG=0)

install(TARGETS elf2hunk RUNTIME DESTINATION bin)
