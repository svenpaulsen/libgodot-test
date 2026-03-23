# Test Project for LibGodot

A lightweight test application that embeds and runs the Godot Engine using `libgodot`.

## Usage

```text
godot_test <project_path_or_pck>
```

## Extending Engine from Host Application

`libgodot_create_godot_instance()` accepts an optional GDExtension init function as the third argument.
This lets you register native classes that GDScript can call, using the standard GDExtension API.

### Concept

1. The init function receives `p_get_proc_address` (access to all GDExtension C APIs) and `p_library` (your extension handle)
2. In the `initialize` callback, register a class and its methods via ClassDB
3. GDScript can then call those methods like any other engine singleton

The raw GDExtension C API is functional but verbose. With [godot-cpp](https://github.com/godotengine/godot-cpp) the same thing is:

```cpp
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/core/class_db.hpp>

class HostBridge : public Object {
    GDCLASS(HostBridge, Object);
protected:
    static void _bind_methods() {
        ClassDB::bind_static_method("HostBridge",
                D_METHOD("ping", "message"), &HostBridge::ping);
    }
public:
    static String ping(const String &message) {
        return "pong: " + message;
    }
};
```

Register it in your init callback:

```cpp
ClassDB::register_class<HostBridge>();
Engine::get_singleton()->register_singleton("HostBridge", memnew(HostBridge));
```

GDScript side:

```gdscript
var reply = HostBridge.ping("hello from godot")
print(reply)  # "pong: hello from godot"
```
