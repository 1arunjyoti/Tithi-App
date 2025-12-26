# CMakeLists.txt for Swiss Ephemeris Android build
cmake_minimum_required(VERSION 3.18.1)

project("swisseph")

# Get the directory containing this CMakeLists.txt
# Path: packages/jyotish/android/src/main/cpp/CMakeLists.txt
# Source: packages/jyotish/native/swisseph/swisseph-master/src/

# Build the path to the Swiss Ephemeris source directory
# From cpp folder, go up 6 levels to reach packages/jyotish, then into native/swisseph/swisseph-master/src
get_filename_component(JYOTISH_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../../" ABSOLUTE)
set(SWISSEPH_SOURCE_DIR "${JYOTISH_ROOT}/packages/jyotish/native/swisseph/swisseph-master/src")

message(STATUS "CMAKE_CURRENT_SOURCE_DIR: ${CMAKE_CURRENT_SOURCE_DIR}")
message(STATUS "JYOTISH_ROOT: ${JYOTISH_ROOT}")
message(STATUS "SWISSEPH_SOURCE_DIR: ${SWISSEPH_SOURCE_DIR}")

# Check if source files exist
if(NOT EXISTS "${SWISSEPH_SOURCE_DIR}/sweph.c")
    message(FATAL_ERROR "Swiss Ephemeris source files not found at ${SWISSEPH_SOURCE_DIR}. Please download from https://github.com/aloistr/swisseph")
endif()

# Collect all C source files for the Swiss Ephemeris library
set(SWISSEPH_SRC
    ${SWISSEPH_SOURCE_DIR}/swecl.c
    ${SWISSEPH_SOURCE_DIR}/swedate.c
    ${SWISSEPH_SOURCE_DIR}/swehel.c
    ${SWISSEPH_SOURCE_DIR}/swehouse.c
    ${SWISSEPH_SOURCE_DIR}/swejpl.c
    ${SWISSEPH_SOURCE_DIR}/swemmoon.c
    ${SWISSEPH_SOURCE_DIR}/swemplan.c
    ${SWISSEPH_SOURCE_DIR}/sweph.c
    ${SWISSEPH_SOURCE_DIR}/swephlib.c
)

# Create the shared library
add_library(swisseph SHARED ${SWISSEPH_SRC})

# Include directory for headers
target_include_directories(swisseph PRIVATE ${SWISSEPH_SOURCE_DIR})

# Link with required libraries
target_link_libraries(swisseph 
    android
    log
    m  # math library
)

# Compiler flags for position-independent code
target_compile_options(swisseph PRIVATE -fPIC -O2)

