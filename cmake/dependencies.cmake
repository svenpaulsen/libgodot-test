include(FetchContent)

# =============================================================================
# Godot Engine
# =============================================================================

message(STATUS "Installing Godot Engine")

FetchContent_Declare(
    godot
    GIT_REPOSITORY https://github.com/svenpaulsen/godot.git
    GIT_TAG        origin/4.5
    EXCLUDE_FROM_ALL
)
FetchContent_MakeAvailable(godot)

if(WIN32)
    set(GODOT_PLATFORM windows)
elseif(APPLE)
    set(GODOT_PLATFORM macos)
elseif(UNIX)
    set(GODOT_PLATFORM linuxbsd)
else()
    message(FATAL_ERROR "Unknown platform; only Windows, macOS and Linux are supported")
endif()

set(GODOT_ARCH ${CMAKE_SYSTEM_PROCESSOR})
if(GODOT_ARCH STREQUAL "amd64" OR GODOT_ARCH STREQUAL "AMD64")
    set(GODOT_ARCH x86_64)
elseif(GODOT_ARCH STREQUAL "x86" OR GODOT_ARCH STREQUAL "i386" OR GODOT_ARCH STREQUAL "i686")
    set(GODOT_ARCH x86_32)
elseif(GODOT_ARCH STREQUAL "aarch64" OR GODOT_ARCH STREQUAL "arm64e" OR GODOT_ARCH STREQUAL "ARM64")
    set(GODOT_ARCH arm64)
endif()

if(CMAKE_BUILD_TYPE STREQUAL "Release")
    set(GODOT_TEMPLATE template_release)
else()
    set(GODOT_TEMPLATE template_debug)
endif()

target_include_directories(${PROJECT_NAME} PRIVATE ${godot_SOURCE_DIR} ${godot_SOURCE_DIR}/core/extension ${godot_SOURCE_DIR}/platform/${GODOT_PLATFORM})
target_link_directories(${PROJECT_NAME} PRIVATE ${godot_SOURCE_DIR}/bin)
target_link_libraries(${PROJECT_NAME} PRIVATE godot.${GODOT_PLATFORM}.${GODOT_TEMPLATE}.${GODOT_ARCH})

add_custom_target(godot_shared_library
    COMMAND scons 
        platform=${GODOT_PLATFORM}
        arch=${GODOT_ARCH}
        target=${GODOT_TEMPLATE}
        library_type=shared_library 
        disable_path_overrides=no
    WORKING_DIRECTORY ${godot_SOURCE_DIR}
)

if(APPLE)
    add_custom_command(TARGET godot_shared_library POST_BUILD 
        COMMAND ${CMAKE_INSTALL_NAME_TOOL}
            -id @rpath/${CMAKE_SHARED_LIBRARY_PREFIX}godot.${GODOT_PLATFORM}.${GODOT_TEMPLATE}.${GODOT_ARCH}${CMAKE_SHARED_LIBRARY_SUFFIX}
            ${godot_SOURCE_DIR}/bin/${CMAKE_SHARED_LIBRARY_PREFIX}godot.${GODOT_PLATFORM}.${GODOT_TEMPLATE}.${GODOT_ARCH}${CMAKE_SHARED_LIBRARY_SUFFIX}
    )
endif()

add_dependencies(${PROJECT_NAME} godot_shared_library)

add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${godot_SOURCE_DIR}/bin/${CMAKE_SHARED_LIBRARY_PREFIX}godot.${GODOT_PLATFORM}.${GODOT_TEMPLATE}.${GODOT_ARCH}${CMAKE_SHARED_LIBRARY_SUFFIX}
        $<TARGET_FILE_DIR:${PROJECT_NAME}>
)
