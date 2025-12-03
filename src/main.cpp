/*
 * libgodot-test: A cross-platform test app that embeds the Godot engine
 *
 * Usage: godot_test --path <path_to_project>
 *
 * This creates a native window using platform-specific code and renders
 * Godot content into it using the external display server interface.
 */

#include <iostream>
#include <string>
#include <vector>

#include "platform.h"
#include <libgodot.h>

// Platform-specific helper to set godot instance on context
extern "C" void platform_set_godot_instance(PlatformContext* ctx, GDExtensionObjectPtr instance);

// Global state
static GDExtensionObjectPtr g_godot_instance = nullptr;
static bool                 g_should_quit    = false;

/*
 * Custom Godot GDExtension initialization entry point.
 */
static GDExtensionBool init_extension(GDExtensionInterfaceGetProcAddress p_get_proc_address,
                                      GDExtensionClassLibraryPtr         p_library,
                                      GDExtensionInitialization*         r_initialization)
{
    r_initialization->minimum_initialization_level = GDEXTENSION_INITIALIZATION_SCENE;

    r_initialization->initialize = [](void* userdata, GDExtensionInitializationLevel level) {
        if (level == GDEXTENSION_INITIALIZATION_SCENE) {
            std::cout << "[libgodot-test] Godot extension initialized" << std::endl;
        }
    };

    r_initialization->deinitialize = [](void* userdata, GDExtensionInitializationLevel level) {
        if (level == GDEXTENSION_INITIALIZATION_SCENE) {
            std::cout << "[libgodot-test] Godot extension shutdown" << std::endl;
        }
    };

    return true;
}

/*
 * Frame callback - called each frame from platform event loop
 * Returns true when we should quit
 */
static bool on_frame()
{
    if (!g_godot_instance) {
        return true;
    }

    // Run one Godot iteration
    bool should_quit = libgodot_iteration_godot_instance(g_godot_instance);

    return should_quit || g_should_quit;
}

/*
 * Quit callback - called when window close is requested
 */
static void on_quit()
{
    g_should_quit = true;
}

int main(int argc, char* argv[])
{
    std::cout << "[libgodot-test] Starting..." << std::endl;

    // Extract project path from arguments for window title
    std::string project_path;
    for (int i = 1; i < argc; i++) {
        if (std::string(argv[i]) == "--path" && i + 1 < argc) {
            project_path = argv[i + 1];
            break;
        }
    }

    // Initialize platform (creates native window)
    PlatformContext* platform = platform_init(1280, 720, "libgodot-test");
    if (!platform) {
        std::cerr << "[libgodot-test] Failed to initialize platform" << std::endl;
        return EXIT_FAILURE;
    }

    // Set window title with project path
    if (!project_path.empty()) {
        std::string title = "Embedded Godot Project from " + project_path;
        platform_set_window_title(platform, title.c_str());
    }

    // Set up the external display server interface
    LibGodotDisplayServerInterface* ds_interface = platform_get_display_server_interface(platform);
    libgodot_display_server_set_interface(ds_interface);

    // Build command line arguments for Godot
    // We inject --display-driver external to use our display server
    std::vector<char*> godot_argv;
    godot_argv.push_back(argv[0]);

    // Add --display-driver external
    static char display_driver_arg[] = "--display-driver";
    static char display_driver_val[] = "external";
    godot_argv.push_back(display_driver_arg);
    godot_argv.push_back(display_driver_val);

    // Add --rendering-driver metal (for macOS)
#ifdef __APPLE__
    static char rendering_driver_arg[] = "--rendering-driver";
    static char rendering_driver_val[] = "metal";
    godot_argv.push_back(rendering_driver_arg);
    godot_argv.push_back(rendering_driver_val);
#endif

    // Pass through original arguments (skip argv[0])
    for (int i = 1; i < argc; i++) {
        godot_argv.push_back(argv[i]);
    }

    std::cout << "[libgodot-test] Creating Godot instance with args:";
    for (auto& arg : godot_argv) {
        std::cout << " " << arg;
    }
    std::cout << std::endl;

    // Create the Godot instance
    g_godot_instance = libgodot_create_godot_instance(static_cast<int>(godot_argv.size()),
                                                      godot_argv.data(), init_extension);

    if (!g_godot_instance) {
        std::cerr << "[libgodot-test] Failed to create Godot instance" << std::endl;
        platform_shutdown(platform);
        return EXIT_FAILURE;
    }

    // Set the instance on the platform context so events can be forwarded
    platform_set_godot_instance(platform, g_godot_instance);

    // Start the Godot main loop
    if (!libgodot_start_godot_instance(g_godot_instance)) {
        std::cerr << "[libgodot-test] Failed to start Godot instance" << std::endl;
        libgodot_destroy_godot_instance(g_godot_instance);
        platform_shutdown(platform);
        return EXIT_FAILURE;
    }

    std::cout << "[libgodot-test] Godot started, entering main loop" << std::endl;

    // Run the platform event loop
    PlatformCallbacks callbacks;
    callbacks.on_frame = on_frame;
    callbacks.on_quit  = on_quit;
    platform_run(platform, callbacks);

    std::cout << "[libgodot-test] Main loop ended, shutting down" << std::endl;

    // Clean up
    libgodot_destroy_godot_instance(g_godot_instance);
    g_godot_instance = nullptr;

    platform_shutdown(platform);

    std::cout << "[libgodot-test] Done" << std::endl;
    return EXIT_SUCCESS;
}
