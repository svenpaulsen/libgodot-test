/*
 * A light-weight test app that embeds and runs the Godot engine
 *
 * Usage: godot_test --path <path_to_project>
 */

#include <iostream>

#include <libgodot.h>

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
        std::cout << "initializing Godot extension" << std::endl;
    };

    // Called when Godot unloads the extension
    r_initialization->deinitialize = [](void *userdata, GDExtensionInitializationLevel level) {
        std::cout << "shutting down Godot extension" << std::endl;
    };

    return true;
}

int main(int argc, char *argv[])
{
    if (argc < 2) {
        std::cerr << "Usage: godot_test <project_path_or_pck>" << std::endl;
        return EXIT_FAILURE;
    }
    const char *project_path = argv[1];

    // Create an embedded Godot engine instance
    auto instance = libgodot_create_godot_instance(argc, argv, init_extension);
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

    // Run Godot's per-frame iteration loop until it returns true (e.g. engine requests shutdown)
    while (!libgodot_iteration_godot_instance(instance)) {}

    // Cleanly destroy the engine instance
    libgodot_unload_project(instance);
    libgodot_destroy_godot_instance(instance);

    return EXIT_SUCCESS;
}
