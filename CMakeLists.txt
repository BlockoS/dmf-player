cmake_minimum_required (VERSION 2.8)
include(CheckCXXSymbolExists)

project(dmfread)
set(DMF_READ_MAJOR "0")
set(DMF_READ_MINOR "1")
set(DMF_READ_PATCH "0")
set(VERSION "${DMF_READ_MAJOR}.${DMF_READ_MINOR}.${DMF_READ_PATCH}")
set(PROJECT_NAME dmfread)
set(PACKAGE dmfread)
set(PACKAGE_VERSION "${VERSION}")
add_definitions(-DPACKAGE_VERSION="${PACKAGE_VERSION}")

# Force build type to Debug if none was specified.
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Debug")
endif()

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -std=c++11")
if(CMAKE_BUILD_TYPE EQUAL "Debug")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -g")
elseif(CMAKE_BUILD_TYPE EQUAL "Release")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3")
endif()

set(LIBRARY_OUTPUT_PATH    "${CMAKE_BINARY_DIR}/${CMAKE_BUILD_TYPE}")
set(EXECUTABLE_OUTPUT_PATH "${CMAKE_BINARY_DIR}/${CMAKE_BUILD_TYPE}")
set(ARCHIVE_OUTPUT_PATH    "${CMAKE_BINARY_DIR}/${CMAKE_BUILD_TYPE}")

find_package(ZLIB)

include_directories(${ZLIB_INCLUDE_DIRS}
                    ${CMAKE_CURRENT_SOURCE_DIR})

set(DMF_READ_SOURCES datareader.cpp
                     dmf.cpp
                     main.cpp
                     pce.cpp
                     pcewriter.cpp)

add_executable(dmfread ${DMF_READ_SOURCES})
target_link_libraries(dmfread ${ZLIB_LIBRARIES})
