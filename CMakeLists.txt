cmake_minimum_required(VERSION 3.28)

project(
    godot_test
    VERSION 0.0.1
    DESCRIPTION "A light-weight test app that embeds and runs the Godot engine"
    LANGUAGES C CXX OBJCXX
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

if(MSVC)
    add_compile_options(/std:c++20 /Zc:__cplusplus)
endif()

add_executable(${PROJECT_NAME})

include("./cmake/dependencies.cmake")

# Common sources
target_sources(${PROJECT_NAME} PRIVATE src/main.cpp)

# Platform-specific sources
if(APPLE)
    target_sources(${PROJECT_NAME} PRIVATE src/platform_macos.mm)
    target_link_libraries(${PROJECT_NAME} PRIVATE
        "-framework Cocoa"
        "-framework QuartzCore"
        "-framework Metal"
        "-framework CoreGraphics"
    )
elseif(WIN32)
    # target_sources(${PROJECT_NAME} PRIVATE src/platform_windows.cpp)
    message(WARNING "Windows platform not yet implemented")
elseif(UNIX)
    # target_sources(${PROJECT_NAME} PRIVATE src/platform_linux.cpp)
    message(WARNING "Linux platform not yet implemented")
endif()

target_compile_definitions(${PROJECT_NAME} PRIVATE PROJECT_NAME="${PROJECT_NAME}" PROJECT_DESCRIPTION="${PROJECT_DESCRIPTION}")
