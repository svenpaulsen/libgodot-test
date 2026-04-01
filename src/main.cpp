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

/*
 * Status callback that receives engine lifecycle transitions.
 */
static void my_status(void * /*userdata*/, LibGodotStatus status, const char *detail)
{
    const char *name = "UNKNOWN";
    switch (status) {
        case LIBGODOT_STATUS_UNINITIALIZED:
            name = "UNINITIALIZED";
            break;
        case LIBGODOT_STATUS_CORE_READY:
            name = "CORE_READY";
            break;
        case LIBGODOT_STATUS_SERVERS_READY:
            name = "SERVERS_READY";
            break;
        case LIBGODOT_STATUS_WARMING_UP:
            name = "WARMING_UP";
            break;
        case LIBGODOT_STATUS_PROJECT_LOADING:
            name = "PROJECT_LOADING";
            break;
        case LIBGODOT_STATUS_RUNNING:
            name = "RUNNING";
            break;
        case LIBGODOT_STATUS_PROJECT_UNLOADING:
            name = "PROJECT_UNLOADING";
            break;
        case LIBGODOT_STATUS_IDLE:
            name = "IDLE";
            break;
        case LIBGODOT_STATUS_STOPPING:
            name = "STOPPING";
            break;
        case LIBGODOT_STATUS_STOPPED:
            name = "STOPPED";
            break;
        case LIBGODOT_STATUS_ERROR:
            name = "ERROR";
            break;
    }

    if (detail) {
        std::cout << "[STATUS] " << name << " — " << detail << std::endl;
    } else {
        std::cout << "[STATUS] " << name << std::endl;
    }
}

int main(int argc, char *argv[])
{
    if (argc < 2) {
        std::cerr << "Usage: godot_test <project_path_or_pck>" << std::endl;
        return EXIT_FAILURE;
    }
    const char *project_path = argv[1];

    // Register callbacks before creating the instance to capture early messages.
    libgodot_set_log_callback(my_log, nullptr);
    libgodot_set_status_callback(my_status, nullptr);

    // Create an embedded Godot engine instance.
    auto instance = libgodot_create_godot_instance(argc, argv, NULL);
    if (instance == nullptr) {
        std::cerr << "failed to initialize Godot Engine instance" << std::endl;
        return EXIT_FAILURE;
    }

    // Pre-compile built-in engine shaders before loading a project.
    std::cout << "Warming up engine shaders..." << std::endl;
    if (!libgodot_warmup(instance)) {
        std::cerr << "failed to start shader warmup" << std::endl;
        libgodot_destroy_godot_instance(instance);
        return EXIT_FAILURE;
    }

    // Wait for warmup to complete, printing progress.
    while (libgodot_get_status(instance) == LIBGODOT_STATUS_WARMING_UP) {
        int32_t pending = libgodot_get_shader_compilations_pending();
        int32_t total   = libgodot_get_shader_compilations_total();
        std::cout << "\r  Compiling shaders... " << total << " done, " << pending << " pending"
                  << std::flush;
    }
    std::cout << std::endl;
    std::cout << "Warmup complete — " << libgodot_get_shader_compilations_total()
              << " shader variants compiled." << std::endl;

    // Load and start the project.
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
