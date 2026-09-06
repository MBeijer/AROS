cmake_minimum_required(VERSION 3.20)
file(READ "${DIAGNOSTIC_FILE}" _diagnostic)
message(FATAL_ERROR "${_diagnostic}")
