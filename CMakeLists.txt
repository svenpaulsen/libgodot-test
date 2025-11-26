cmake_minimum_required(VERSION 3.28)

project(
    godot_test
    VERSION 0.0.1
    DESCRIPTION "A light-weight test app that embeds and runs the Godot engine"
    LANGUAGES C CXX
)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if (NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Debug CACHE STRING "Default to debug build type" FORCE)
endif()

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_INSTALL_RPATH_USE_LINK_PATH ON)

if(WIN32)
    set(PLATFORM windows)
elseif(APPLE)
    set(PLATFORM macos)
elseif(UNIX)
    set(PLATFORM linuxbsd)
else()
    message(FATAL_ERROR "Unknown platform; only Windows, macOS and Linux are supported")
endif()

set(ARCH ${CMAKE_SYSTEM_PROCESSOR})
if(ARCH STREQUAL "x86_64" OR ARCH STREQUAL "amd64" OR ARCH STREQUAL "AMD64")
    set(ARCH x86_64)
elseif(ARCH STREQUAL "x86" OR ARCH STREQUAL "i386" OR ARCH STREQUAL "i686")
    set(ARCH x86_32)
elseif(ARCH STREQUAL "aarch64" OR ARCH STREQUAL "arm64" OR ARCH STREQUAL "arm64e" OR ARCH STREQUAL "ARM64")
    set(ARCH arm64)
else()
    message(FATAL_ERROR "Unknown processor; ${ARCH}")
endif()

add_executable(${PROJECT_NAME})

if(WIN32)
    target_compile_options(${PROJECT_NAME} PRIVATE /utf-8)
endif()

include("./cmake/dependencies.cmake")

target_sources(${PROJECT_NAME} PRIVATE src/main.cpp)
target_compile_definitions(${PROJECT_NAME} PRIVATE PROJECT_NAME="${PROJECT_NAME}" PROJECT_DESCRIPTION="${PROJECT_DESCRIPTION}")
