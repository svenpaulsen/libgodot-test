include(FetchContent)

# =============================================================================
# spdlog
# =============================================================================

message(STATUS "Installing spdlog")

FetchContent_Declare(
    spdlog
    GIT_REPOSITORY https://github.com/gabime/spdlog.git
    GIT_TAG        v1.16.0
    EXCLUDE_FROM_ALL
)
FetchContent_MakeAvailable(spdlog)

target_include_directories(${PROJECT_NAME} PRIVATE ${spdlog_SOURCE_DIR}/include)

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

target_include_directories(${PROJECT_NAME} PRIVATE ${godot_SOURCE_DIR} ${godot_SOURCE_DIR}/core/extension ${godot_SOURCE_DIR}/platform/${PLATFORM})
target_link_directories(${PROJECT_NAME} PRIVATE ${godot_SOURCE_DIR}/bin)
target_link_libraries(${PROJECT_NAME} PRIVATE godot.${PLATFORM}.template_release.${ARCH})

add_custom_target(godot_shared_library
    COMMAND scons 
        platform=${PLATFORM}
        arch=${ARCH}
        target=template_release
        library_type=shared_library 
        disable_path_overrides=no
    WORKING_DIRECTORY ${godot_SOURCE_DIR}
)

if(APPLE)
    add_custom_command(TARGET godot_shared_library POST_BUILD 
        COMMAND ${CMAKE_INSTALL_NAME_TOOL}
            -id @rpath/${CMAKE_SHARED_LIBRARY_PREFIX}godot.${PLATFORM}.template_release.${ARCH}${CMAKE_SHARED_LIBRARY_SUFFIX}
            ${godot_SOURCE_DIR}/bin/${CMAKE_SHARED_LIBRARY_PREFIX}godot.${PLATFORM}.template_release.${ARCH}${CMAKE_SHARED_LIBRARY_SUFFIX}
    )
endif()

add_dependencies(${PROJECT_NAME} godot_shared_library)

add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${godot_SOURCE_DIR}/bin/${CMAKE_SHARED_LIBRARY_PREFIX}godot.${PLATFORM}.template_release.${ARCH}${CMAKE_SHARED_LIBRARY_SUFFIX}
        $<TARGET_FILE_DIR:${PROJECT_NAME}>
)
