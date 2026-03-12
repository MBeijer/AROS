cmake_minimum_required(VERSION 3.20)

project(fd2pragma LANGUAGES C)

add_executable(fd2pragma fd2pragma.c)

# Host-side CMake build uses the portable CLI parser path.
# The Amiga ReadArgs integration path depends on proto/dos headers.
target_compile_definitions(fd2pragma PRIVATE FD2PRAGMA_AMIGA)

install(TARGETS fd2pragma RUNTIME DESTINATION bin)
install(FILES fd2pragma.guide DESTINATION share/doc/fd2pragma)
