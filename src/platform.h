/*
 * Platform abstraction for libgodot-test
 *
 * Each platform implements these functions to create a native window
 * and provide the display server interface to Godot.
 */

#pragma once

#include <libgodot.h>

#include <functional>

// Platform-specific context (opaque to main.cpp)
struct PlatformContext;

// Callbacks from platform to main
struct PlatformCallbacks {
    std::function<bool()> on_frame; // Called each frame, return true to quit
    std::function<void()> on_quit;  // Called when window close is requested
    std::function<void()> on_start; // Called when the UI start button is pressed
    std::function<void()> on_stop;  // Called when the UI stop button is pressed
};

// Initialize the platform (create window, set up display server interface)
// Returns nullptr on failure
PlatformContext* platform_init(int width, int height, const char* title);

// Shutdown the platform
void platform_shutdown(PlatformContext* ctx);

// Run the platform event loop
// This will call callbacks.on_frame() each frame
void platform_run(PlatformContext* ctx, PlatformCallbacks callbacks);

// Get the display server interface for Godot
LibGodotDisplayServerInterface* platform_get_display_server_interface(PlatformContext* ctx);

// Set the window title
void platform_set_window_title(PlatformContext* ctx, const char* title);

// Enable/disable the embedded start/stop controls and update the status label
void platform_set_run_state(PlatformContext* ctx, bool project_running, const char* status_text);
