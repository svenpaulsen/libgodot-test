/*
 * A light-weight test app that embeds and runs the Godot engine.
 *
 * Usage: godot_test <project_path_or_pck>
 */

#include <iostream>

#include <libgodot.h>

/*
 * Log callback that receives all engine output.
 */
static void my_log(void * /*userdata*/, LibGodotLogLevel level, const char *message)
{
    switch (level) {
        case LIBGODOT_LOG_LEVEL_WARNING:
            std::cout << "[WARN]  " << message << std::endl;
            break;
        case LIBGODOT_LOG_LEVEL_ERROR:
            std::cerr << "[ERROR] " << message << std::endl;
            break;
        default:
            std::cout << "[INFO]  " << message << std::endl;
            break;
    }
}

int main(int argc, char *argv[])
{
    if (argc < 2) {
        std::cerr << "Usage: godot_test <project_path_or_pck>" << std::endl;
        return EXIT_FAILURE;
    }
    const char *project_path = argv[1];

    // Register the log callback before creating the instance to capture early messages.
    // This also suppresses the engine's default stdout/stderr output.
    libgodot_set_log_callback(my_log, nullptr);

    // Create an embedded Godot engine instance.
    // Pass NULL as the init function since we don't need to register custom native types.
    auto instance = libgodot_create_godot_instance(argc, argv, NULL);
    if (instance == nullptr) {
        std::cerr << "failed to initialize Godot Engine instance" << std::endl;
        return EXIT_FAILURE;
    }

    // Load and start the project after the engine is initialized.
    if (!libgodot_load_project(instance, project_path)) {
        std::cerr << "failed to load Godot project: " << project_path << std::endl;
        libgodot_destroy_godot_instance(instance);
        return EXIT_FAILURE;
    }

    // Run Godot's per-frame iteration loop until it returns true (engine requests shutdown).
    while (!libgodot_iteration_godot_instance(instance)) {}

    // Cleanly destroy the engine instance.
    libgodot_unload_project(instance);
    libgodot_destroy_godot_instance(instance);

    return EXIT_SUCCESS;
}
