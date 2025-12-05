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
static PlatformContext*     g_platform       = nullptr;
static std::string          g_project_path;
static bool                 g_project_running = false;

static std::string resolve_project_path(int argc, char* argv[])
{
    for (int i = 1; i < argc - 1; ++i) {
        std::string arg = argv[i];
        if ((arg == "--path" || arg == "--main-pack") && (i + 1) < argc) {
            return std::string(argv[i + 1]);
        }
    }

    if (argc > 1) {
        std::string first = argv[1];
        if (first != "--path" && first != "--main-pack") {
            return first;
        }
    }

    return {};
}

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

static void update_run_state(bool running, const std::string& status)
{
    g_project_running = running;
    if (g_platform) {
        const char* status_text = status.empty() ? nullptr : status.c_str();
        platform_set_run_state(g_platform, running, status_text);
    }
}

static void stop_project(const char* reason = nullptr)
{
    if (!g_godot_instance || !g_project_running) {
        return;
    }

    std::string log_reason = reason ? std::string(reason) : "Stopped";
    std::cout << "[libgodot-test] Unloading project (" << log_reason << ")" << std::endl;

    libgodot_unload_project(g_godot_instance);

    std::string status = reason ? std::string("Project stopped: ") + reason : "Project stopped";
    update_run_state(false, status);
}

static void start_project()
{
    if (!g_godot_instance) {
        std::cerr << "[libgodot-test] Cannot start project: Godot instance is null" << std::endl;
        g_should_quit = true;
        return;
    }

    if (g_project_running) {
        std::cout << "[libgodot-test] Project already running" << std::endl;
        return;
    }

    if (g_project_path.empty()) {
        std::cerr << "[libgodot-test] Cannot start project: no path provided" << std::endl;
        return;
    }

    std::cout << "[libgodot-test] Loading project: " << g_project_path << std::endl;
    update_run_state(false, "Loading project...");

    if (!libgodot_load_project(g_godot_instance, g_project_path.c_str())) {
        std::cerr << "[libgodot-test] Failed to load Godot project: " << g_project_path << std::endl;
        update_run_state(false, "Failed to load project");
        return;
    }

    std::string status = "Running project: " + g_project_path;
    update_run_state(true, status);
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

    if (g_project_running) {
        bool should_quit = libgodot_iteration_godot_instance(g_godot_instance);
        if (should_quit) {
            stop_project("Project requested exit");
        }
    }

    return g_should_quit;
}

/*
 * Quit callback - called when window close is requested
 */
static void on_quit()
{
    stop_project("Window close requested");
    g_should_quit = true;
}

int main(int argc, char* argv[])
{
    std::cout << "[libgodot-test] Starting..." << std::endl;

    // Extract project path from arguments for window title and load/unload
    auto project_path = resolve_project_path(argc, argv);
    if (project_path.empty()) {
        std::cerr << "Usage: godot_test <project_path_or_pck> [--path <project_path>|--main-pack <pck>]" << std::endl;
        return EXIT_FAILURE;
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
    g_platform = platform;
    g_project_path = project_path;

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

    // Initial UI state before starting the project
    std::string initial_status = "Project ready: " + g_project_path;
    update_run_state(false, initial_status);

    // Run the platform event loop
    PlatformCallbacks callbacks;
    callbacks.on_frame = on_frame;
    callbacks.on_quit  = on_quit;
    callbacks.on_start = start_project;
    callbacks.on_stop  = []() { stop_project("Stopped by user"); };

    // Auto-start the project once the engine is initialized
    start_project();

    std::cout << "[libgodot-test] Godot ready, entering main loop" << std::endl;
    platform_run(platform, callbacks);

    std::cout << "[libgodot-test] Main loop ended, shutting down" << std::endl;

    // Clean up
    stop_project("Shutting down");
    libgodot_destroy_godot_instance(g_godot_instance);
    g_godot_instance = nullptr;

    platform_shutdown(platform);
    g_platform = nullptr;

    std::cout << "[libgodot-test] Done" << std::endl;
    return EXIT_SUCCESS;
}
