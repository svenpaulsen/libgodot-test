/*
 * A light-weight test app that embeds and runs the Godot engine
 *
 * Usage: godot_test --path <path_to_project>
 */

#include <godot_instance.h>
#include <libgodot.h>
#include <spdlog/sinks/stdout_color_sinks.h>
#include <spdlog/spdlog.h>

/**
 * Convenience logging macros wrapping spdlog.
 */
#define LOG_DEBUG(...) spdlog::debug(__VA_ARGS__)
#define LOG_INFO(...) spdlog::info(__VA_ARGS__)
#define LOG_WARNING(...) spdlog::warn(__VA_ARGS__)
#define LOG_ERROR(...) spdlog::error(__VA_ARGS__)
#define LOG_CRITICAL(...)                                                                          \
    do {                                                                                           \
        spdlog::critical(__VA_ARGS__);                                                             \
        std::exit(EXIT_FAILURE);                                                                   \
    } while (0)

/*
 * Custom Godot GDExtension initialization entry point.
 */
GDExtensionBool init_extension(GDExtensionInterfaceGetProcAddress p_get_proc_address,
                               GDExtensionClassLibraryPtr         p_library,
                               GDExtensionInitialization         *r_initialization)
{
    // Only require the scene initialization level for this extension
    r_initialization->minimum_initialization_level = GDEXTENSION_INITIALIZATION_SCENE;

    // Called when Godot loads the extension
    r_initialization->initialize = [](void *userdata, GDExtensionInitializationLevel level) {
        LOG_DEBUG("initializing Godot extension");
    };

    // Called when Godot unloads the extension
    r_initialization->deinitialize = [](void *userdata, GDExtensionInitializationLevel level) {
        LOG_DEBUG("shutting down Godot extension");
    };

    return true;
}

int main(int argc, char *argv[])
{
    // Create colored console logger and configure formatting
    spdlog::set_default_logger(spdlog::stdout_color_mt(PROJECT_NAME));
    spdlog::set_pattern("[%T.%e] %n: %^%v%$");
#ifndef NDEBUG
    spdlog::set_level(spdlog::level::trace);
#else
    spdlog::set_level(spdlog::level::info);
#endif

    // Create an embedded Godot engine instance
    auto instance = libgodot_create_godot_instance(argc, argv, init_extension);
    if (instance == nullptr) {
        LOG_CRITICAL("failed to initialize Godot Engine instance");
    }

    // Wrap raw pointer as GodotInstance for convenience
    auto godot = reinterpret_cast<GodotInstance *>(instance);

    // Start the main Godot loop
    if (!godot->start()) {
        LOG_CRITICAL("failed to start Godot Engine instance");
    }

    // Run Godot's per-frame iteration loop until it returns true (e.g. engine requests shutdown)
    while (!godot->iteration()) {}

    // Cleanly destroy the engine instance
    libgodot_destroy_godot_instance(godot);

    return EXIT_SUCCESS;
}
