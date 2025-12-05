/*
 * macOS platform implementation for libgodot-test
 *
 * Creates an NSWindow with a CAMetalLayer for Godot rendering.
 */

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import <Metal/Metal.h>

#include "platform.h"

#include <iostream>
#include <string>

// ============================================================================
// macOS keycode to Godot keycode mapping
// ============================================================================

// Godot Key enum values (from core/os/keyboard.h)
// Letters are uppercase ASCII values, special keys have SPECIAL bit set
static const unsigned int GODOT_KEY_SPECIAL = (1 << 22);

static unsigned int macos_to_godot_keycode(unsigned short macKeyCode) {
    // Map macOS virtual keycodes to Godot keycodes
    // Letters map to uppercase ASCII, special keys to Godot special values
    switch (macKeyCode) {
        // Letters (Godot uses uppercase ASCII)
        case 0x00: return 'A';
        case 0x01: return 'S';
        case 0x02: return 'D';
        case 0x03: return 'F';
        case 0x04: return 'H';
        case 0x05: return 'G';
        case 0x06: return 'Z';
        case 0x07: return 'X';
        case 0x08: return 'C';
        case 0x09: return 'V';
        case 0x0B: return 'B';
        case 0x0C: return 'Q';
        case 0x0D: return 'W';
        case 0x0E: return 'E';
        case 0x0F: return 'R';
        case 0x10: return 'Y';
        case 0x11: return 'T';
        case 0x1F: return 'O';
        case 0x20: return 'U';
        case 0x22: return 'I';
        case 0x23: return 'P';
        case 0x25: return 'L';
        case 0x26: return 'J';
        case 0x28: return 'K';
        case 0x2D: return 'N';
        case 0x2E: return 'M';

        // Numbers
        case 0x12: return '1';
        case 0x13: return '2';
        case 0x14: return '3';
        case 0x15: return '4';
        case 0x16: return '6';
        case 0x17: return '5';
        case 0x19: return '9';
        case 0x1A: return '7';
        case 0x1C: return '8';
        case 0x1D: return '0';

        // Special keys
        case 0x24: return GODOT_KEY_SPECIAL | 0x05; // Enter
        case 0x30: return GODOT_KEY_SPECIAL | 0x02; // Tab
        case 0x31: return ' ';                       // Space
        case 0x33: return GODOT_KEY_SPECIAL | 0x04; // Backspace
        case 0x35: return GODOT_KEY_SPECIAL | 0x01; // Escape
        case 0x7B: return GODOT_KEY_SPECIAL | 0x0F; // Left
        case 0x7C: return GODOT_KEY_SPECIAL | 0x11; // Right
        case 0x7D: return GODOT_KEY_SPECIAL | 0x12; // Down
        case 0x7E: return GODOT_KEY_SPECIAL | 0x10; // Up

        // Punctuation
        case 0x18: return '=';
        case 0x1B: return '-';
        case 0x1E: return ']';
        case 0x21: return '[';
        case 0x27: return '\'';
        case 0x29: return ';';
        case 0x2A: return '\\';
        case 0x2B: return ',';
        case 0x2C: return '/';
        case 0x2F: return '.';
        case 0x32: return '`';

        default: return macKeyCode; // Fallback
    }
}

// ============================================================================
// Platform Context
// ============================================================================

struct PlatformContext {
    NSWindow* window = nil;
    NSView* containerView = nil;      // Main container view
    NSView* godotView = nil;          // View that holds the Metal layer for Godot
    NSView* borderView = nil;         // Border around the Godot view
    NSView* overlayView = nil;        // Semi-transparent overlay when project is stopped
    CAMetalLayer* metalLayer = nil;
    NSTextField* titleLabel = nil;    // Label above the Godot view
    NSButton* startButton = nil;      // Start project button
    NSButton* stopButton = nil;       // Stop project button
    NSObject* controlsTarget = nil;   // Target to route button actions

    LibGodotDisplayServerInterface interface = {};

    // Godot rendering area size (the embedded area, not the window)
    int width = 0;
    int height = 0;
    float scale = 1.0f;

    // Insets for the embedded area
    int inset_left = 40;
    int inset_top = 80;    // Extra space for title
    int inset_right = 40;
    int inset_bottom = 40;

    bool running = false;
    bool focused = true;
    bool project_running = false;

    // Mouse state
    int mouse_x = 0;
    int mouse_y = 0;
    unsigned int mouse_buttons = 0;
    LibGodotMouseMode mouse_mode = LIBGODOT_MOUSE_MODE_VISIBLE;

    // Callbacks
    PlatformCallbacks callbacks;

    // Godot instance (set after creation)
    GDExtensionObjectPtr godot_instance = nullptr;

    // Project path for title
    std::string project_path;
};

// Global context pointer for callbacks
static PlatformContext* g_ctx = nullptr;

// ============================================================================
// Display Server Interface Callbacks
// ============================================================================

static const char* ds_get_name(void* user_data) {
    return "libgodot-test";
}

static int ds_get_screen_count(void* user_data) {
    return 1;
}

static int ds_get_primary_screen(void* user_data) {
    return 0;
}

static void ds_get_screen_position(void* user_data, int screen, int* x, int* y) {
    *x = 0;
    *y = 0;
}

static void ds_get_screen_size(void* user_data, int screen, int* w, int* h) {
    PlatformContext* ctx = (PlatformContext*)user_data;
    NSScreen* mainScreen = [NSScreen mainScreen];
    NSRect frame = [mainScreen frame];
    *w = (int)(frame.size.width * ctx->scale);
    *h = (int)(frame.size.height * ctx->scale);
}

static int ds_get_screen_dpi(void* user_data, int screen) {
    return 96;
}

static float ds_get_screen_scale(void* user_data, int screen) {
    PlatformContext* ctx = (PlatformContext*)user_data;
    return ctx->scale;
}

static float ds_get_screen_refresh_rate(void* user_data, int screen) {
    return 60.0f;
}

static void ds_get_window_position(void* user_data, int window_id, int* x, int* y) {
    PlatformContext* ctx = (PlatformContext*)user_data;
    if (ctx->window) {
        NSRect frame = [ctx->window frame];
        *x = (int)frame.origin.x;
        *y = (int)frame.origin.y;
    } else {
        *x = 0;
        *y = 0;
    }
}

static void ds_get_window_size(void* user_data, int window_id, int* w, int* h) {
    PlatformContext* ctx = (PlatformContext*)user_data;
    *w = ctx->width;
    *h = ctx->height;
}

static void ds_set_window_size(void* user_data, int window_id, int w, int h) {
    PlatformContext* ctx = (PlatformContext*)user_data;
    if (!ctx->window) {
        return;
    }

    // Ignore resize requests before a project is running to keep the initial window size.
    if (!ctx->project_running) {
        return;
    }

    // Prevent the project from shrinking the window below the current embedded area.
    int target_w = w < ctx->width ? ctx->width : w;
    int target_h = h < ctx->height ? ctx->height : h;

    NSRect frame = [ctx->window frame];
    frame.size.width = target_w / ctx->scale;
    frame.size.height = target_h / ctx->scale;
    [ctx->window setFrame:frame display:YES animate:NO];
}

static void ds_set_window_position(void* user_data, int window_id, int x, int y) {
    PlatformContext* ctx = (PlatformContext*)user_data;
    if (ctx->window) {
        [ctx->window setFrameOrigin:NSMakePoint(x, y)];
    }
}

static GDExtensionBool ds_window_can_draw(void* user_data, int window_id) {
    return true;
}

static GDExtensionBool ds_window_is_focused(void* user_data, int window_id) {
    PlatformContext* ctx = (PlatformContext*)user_data;
    return ctx->focused;
}

static void ds_process_events(void* user_data) {
    // Events are processed in the main run loop
}

static void* ds_get_native_handle(void* user_data, LibGodotHandleType handle_type, int window_id) {
    PlatformContext* ctx = (PlatformContext*)user_data;
    switch (handle_type) {
        case LIBGODOT_HANDLE_WINDOW_VIEW:
            return (__bridge void*)ctx->metalLayer;
        case LIBGODOT_HANDLE_WINDOW:
            return (__bridge void*)ctx->window;
        default:
            return nullptr;
    }
}

static void ds_swap_buffers(void* user_data) {
    // Metal handles presentation automatically
}

static void ds_mouse_set_mode(void* user_data, LibGodotMouseMode mode) {
    PlatformContext* ctx = (PlatformContext*)user_data;
    ctx->mouse_mode = mode;

    switch (mode) {
        case LIBGODOT_MOUSE_MODE_VISIBLE:
            [NSCursor unhide];
            CGAssociateMouseAndMouseCursorPosition(true);
            break;
        case LIBGODOT_MOUSE_MODE_HIDDEN:
            [NSCursor hide];
            CGAssociateMouseAndMouseCursorPosition(true);
            break;
        case LIBGODOT_MOUSE_MODE_CAPTURED:
            [NSCursor hide];
            CGAssociateMouseAndMouseCursorPosition(false);
            break;
        case LIBGODOT_MOUSE_MODE_CONFINED:
        case LIBGODOT_MOUSE_MODE_CONFINED_HIDDEN:
            // Not fully implemented
            break;
    }
}

static LibGodotMouseMode ds_mouse_get_mode(void* user_data) {
    PlatformContext* ctx = (PlatformContext*)user_data;
    return ctx->mouse_mode;
}

static void ds_warp_mouse(void* user_data, int x, int y) {
    PlatformContext* ctx = (PlatformContext*)user_data;
    if (ctx->window) {
        NSRect frame = [ctx->window frame];
        CGPoint point;
        point.x = frame.origin.x + x / ctx->scale;
        point.y = [[NSScreen mainScreen] frame].size.height - (frame.origin.y + frame.size.height) + y / ctx->scale;
        CGWarpMouseCursorPosition(point);
    }
}

static void ds_get_mouse_position(void* user_data, int* x, int* y) {
    PlatformContext* ctx = (PlatformContext*)user_data;
    *x = ctx->mouse_x;
    *y = ctx->mouse_y;
}

static unsigned int ds_get_mouse_button_state(void* user_data) {
    PlatformContext* ctx = (PlatformContext*)user_data;
    return ctx->mouse_buttons;
}

static void ds_cursor_set_shape(void* user_data, LibGodotCursorShape shape) {
    NSCursor* cursor = nil;
    switch (shape) {
        case LIBGODOT_CURSOR_ARROW:
            cursor = [NSCursor arrowCursor];
            break;
        case LIBGODOT_CURSOR_IBEAM:
            cursor = [NSCursor IBeamCursor];
            break;
        case LIBGODOT_CURSOR_POINTING_HAND:
            cursor = [NSCursor pointingHandCursor];
            break;
        case LIBGODOT_CURSOR_CROSS:
            cursor = [NSCursor crosshairCursor];
            break;
        case LIBGODOT_CURSOR_WAIT:
        case LIBGODOT_CURSOR_BUSY:
            cursor = [NSCursor arrowCursor]; // No spinning cursor in AppKit
            break;
        case LIBGODOT_CURSOR_DRAG:
            cursor = [NSCursor closedHandCursor];
            break;
        case LIBGODOT_CURSOR_CAN_DROP:
            cursor = [NSCursor dragCopyCursor];
            break;
        case LIBGODOT_CURSOR_FORBIDDEN:
            cursor = [NSCursor operationNotAllowedCursor];
            break;
        case LIBGODOT_CURSOR_VSIZE:
            cursor = [NSCursor resizeUpDownCursor];
            break;
        case LIBGODOT_CURSOR_HSIZE:
            cursor = [NSCursor resizeLeftRightCursor];
            break;
        case LIBGODOT_CURSOR_MOVE:
            cursor = [NSCursor openHandCursor];
            break;
        default:
            cursor = [NSCursor arrowCursor];
            break;
    }
    [cursor set];
}

static void ds_set_window_title(void* user_data, int window_id, const char* title) {
    PlatformContext* ctx = (PlatformContext*)user_data;
    if (ctx->window && title) {
        [ctx->window setTitle:[NSString stringWithUTF8String:title]];
    }
}

// ============================================================================
// Custom NSView for event handling
// ============================================================================

@interface LibGodotTestView : NSView
@property (nonatomic, assign) PlatformContext* platformContext;
@end

@implementation LibGodotTestView

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (BOOL)canBecomeKeyView {
    return YES;
}

- (BOOL)acceptsFirstMouse:(NSEvent*)event {
    return YES;
}

- (BOOL)shouldForwardInput {
    return self.platformContext &&
           self.platformContext->godot_instance &&
           self.platformContext->project_running;
}

- (CALayer*)makeBackingLayer {
    CAMetalLayer* layer = [CAMetalLayer layer];
    // Note: We set device here for early layer setup, but Godot's Metal driver
    // will also set it when creating the surface. That's fine - they'll be the same device.
    layer.device = MTLCreateSystemDefaultDevice();
    layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    layer.framebufferOnly = YES;
    layer.opaque = YES;
    // Match DisplayServerEmbedded layer settings
    layer.anchorPoint = CGPointMake(0, 1);  // Bottom-left anchor
    layer.magnificationFilter = kCAFilterNearest;
    layer.minificationFilter = kCAFilterNearest;
    layer.actions = @{ @"contents" : [NSNull null] };  // Disable implicit animations
    layer.contentsScale = self.window.backingScaleFactor;
    return layer;
}

- (BOOL)wantsUpdateLayer {
    return YES;
}

- (BOOL)wantsLayer {
    return YES;
}

// Helper to convert modifier flags
- (unsigned int)modifiersFromEvent:(NSEvent*)event {
    unsigned int mods = LIBGODOT_KEY_MOD_NONE;
    NSEventModifierFlags flags = [event modifierFlags];
    if (flags & NSEventModifierFlagShift) mods |= LIBGODOT_KEY_MOD_SHIFT;
    if (flags & NSEventModifierFlagOption) mods |= LIBGODOT_KEY_MOD_ALT;
    if (flags & NSEventModifierFlagControl) mods |= LIBGODOT_KEY_MOD_CTRL;
    if (flags & NSEventModifierFlagCommand) mods |= LIBGODOT_KEY_MOD_META;
    if (flags & NSEventModifierFlagCapsLock) mods |= LIBGODOT_KEY_MOD_CAPS_LOCK;
    return mods;
}

// Helper to get mouse position in view coordinates (scaled)
- (void)getMousePosition:(NSEvent*)event x:(int*)x y:(int*)y {
    NSPoint loc = [self convertPoint:[event locationInWindow] fromView:nil];
    float scale = self.platformContext->scale;
    *x = (int)(loc.x * scale);
    *y = (int)((self.bounds.size.height - loc.y) * scale);
}

// Mouse events
- (void)mouseDown:(NSEvent*)event {
    if (![self shouldForwardInput]) return;

    int x, y;
    [self getMousePosition:event x:&x y:&y];
    self.platformContext->mouse_buttons |= LIBGODOT_MOUSE_BUTTON_LEFT;

    libgodot_display_server_push_mouse_button_event(
        self.platformContext->godot_instance,
        LIBGODOT_MOUSE_BUTTON_INDEX_LEFT,
        true, x, y,
        [self modifiersFromEvent:event],
        self.platformContext->mouse_buttons
    );
}

- (void)mouseUp:(NSEvent*)event {
    if (![self shouldForwardInput]) return;

    int x, y;
    [self getMousePosition:event x:&x y:&y];
    self.platformContext->mouse_buttons &= ~LIBGODOT_MOUSE_BUTTON_LEFT;

    libgodot_display_server_push_mouse_button_event(
        self.platformContext->godot_instance,
        LIBGODOT_MOUSE_BUTTON_INDEX_LEFT,
        false, x, y,
        [self modifiersFromEvent:event],
        self.platformContext->mouse_buttons
    );
}

- (void)rightMouseDown:(NSEvent*)event {
    if (![self shouldForwardInput]) return;

    int x, y;
    [self getMousePosition:event x:&x y:&y];
    self.platformContext->mouse_buttons |= LIBGODOT_MOUSE_BUTTON_RIGHT;

    libgodot_display_server_push_mouse_button_event(
        self.platformContext->godot_instance,
        LIBGODOT_MOUSE_BUTTON_INDEX_RIGHT,
        true, x, y,
        [self modifiersFromEvent:event],
        self.platformContext->mouse_buttons
    );
}

- (void)rightMouseUp:(NSEvent*)event {
    if (![self shouldForwardInput]) return;

    int x, y;
    [self getMousePosition:event x:&x y:&y];
    self.platformContext->mouse_buttons &= ~LIBGODOT_MOUSE_BUTTON_RIGHT;

    libgodot_display_server_push_mouse_button_event(
        self.platformContext->godot_instance,
        LIBGODOT_MOUSE_BUTTON_INDEX_RIGHT,
        false, x, y,
        [self modifiersFromEvent:event],
        self.platformContext->mouse_buttons
    );
}

- (void)otherMouseDown:(NSEvent*)event {
    if (![self shouldForwardInput]) return;

    int x, y;
    [self getMousePosition:event x:&x y:&y];

    LibGodotMouseButtonIndex button = LIBGODOT_MOUSE_BUTTON_INDEX_MIDDLE;
    unsigned int mask = LIBGODOT_MOUSE_BUTTON_MIDDLE;

    if ([event buttonNumber] == 2) {
        button = LIBGODOT_MOUSE_BUTTON_INDEX_MIDDLE;
        mask = LIBGODOT_MOUSE_BUTTON_MIDDLE;
    } else if ([event buttonNumber] == 3) {
        button = LIBGODOT_MOUSE_BUTTON_INDEX_XBUTTON1;
        mask = LIBGODOT_MOUSE_BUTTON_XBUTTON1;
    } else if ([event buttonNumber] == 4) {
        button = LIBGODOT_MOUSE_BUTTON_INDEX_XBUTTON2;
        mask = LIBGODOT_MOUSE_BUTTON_XBUTTON2;
    }

    self.platformContext->mouse_buttons |= mask;

    libgodot_display_server_push_mouse_button_event(
        self.platformContext->godot_instance,
        button,
        true, x, y,
        [self modifiersFromEvent:event],
        self.platformContext->mouse_buttons
    );
}

- (void)otherMouseUp:(NSEvent*)event {
    if (![self shouldForwardInput]) return;

    int x, y;
    [self getMousePosition:event x:&x y:&y];

    LibGodotMouseButtonIndex button = LIBGODOT_MOUSE_BUTTON_INDEX_MIDDLE;
    unsigned int mask = LIBGODOT_MOUSE_BUTTON_MIDDLE;

    if ([event buttonNumber] == 2) {
        button = LIBGODOT_MOUSE_BUTTON_INDEX_MIDDLE;
        mask = LIBGODOT_MOUSE_BUTTON_MIDDLE;
    } else if ([event buttonNumber] == 3) {
        button = LIBGODOT_MOUSE_BUTTON_INDEX_XBUTTON1;
        mask = LIBGODOT_MOUSE_BUTTON_XBUTTON1;
    } else if ([event buttonNumber] == 4) {
        button = LIBGODOT_MOUSE_BUTTON_INDEX_XBUTTON2;
        mask = LIBGODOT_MOUSE_BUTTON_XBUTTON2;
    }

    self.platformContext->mouse_buttons &= ~mask;

    libgodot_display_server_push_mouse_button_event(
        self.platformContext->godot_instance,
        button,
        false, x, y,
        [self modifiersFromEvent:event],
        self.platformContext->mouse_buttons
    );
}

- (void)mouseMoved:(NSEvent*)event {
    if (![self shouldForwardInput]) return;

    int x, y;
    [self getMousePosition:event x:&x y:&y];

    int dx = (int)[event deltaX];
    int dy = (int)[event deltaY];

    self.platformContext->mouse_x = x;
    self.platformContext->mouse_y = y;

    libgodot_display_server_push_mouse_motion_event(
        self.platformContext->godot_instance,
        x, y, dx, dy,
        [self modifiersFromEvent:event],
        self.platformContext->mouse_buttons
    );
}

- (void)mouseDragged:(NSEvent*)event {
    [self mouseMoved:event];
}

- (void)rightMouseDragged:(NSEvent*)event {
    [self mouseMoved:event];
}

- (void)otherMouseDragged:(NSEvent*)event {
    [self mouseMoved:event];
}

- (void)scrollWheel:(NSEvent*)event {
    if (![self shouldForwardInput]) return;

    int x, y;
    [self getMousePosition:event x:&x y:&y];

    float dx = [event scrollingDeltaX];
    float dy = [event scrollingDeltaY];

    if ([event hasPreciseScrollingDeltas]) {
        dx *= 0.03f;
        dy *= 0.03f;
    }

    libgodot_display_server_push_mouse_wheel_event(
        self.platformContext->godot_instance,
        dx, dy, x, y,
        [self modifiersFromEvent:event]
    );
}

// Keyboard events
- (void)keyDown:(NSEvent*)event {
    if (![self shouldForwardInput]) return;

    // Get the key code and map to Godot keycode
    unsigned short macKeyCode = [event keyCode];
    unsigned int godotKeyCode = macos_to_godot_keycode(macKeyCode);

    NSString* chars = [event characters];
    unsigned int unicode = 0;
    if ([chars length] > 0) {
        unicode = [chars characterAtIndex:0];
    }

    libgodot_display_server_push_key_event(
        self.platformContext->godot_instance,
        godotKeyCode,   // keycode (mapped to Godot)
        godotKeyCode,   // physical keycode
        godotKeyCode,   // key label
        unicode,
        LIBGODOT_KEY_LOCATION_UNSPECIFIED,
        true,
        [event isARepeat],
        [self modifiersFromEvent:event]
    );

    // Also send text input for printable characters
    if (unicode >= 32 && unicode != 127) {
        libgodot_display_server_push_input_text(
            self.platformContext->godot_instance,
            [chars UTF8String]
        );
    }
}

- (void)keyUp:(NSEvent*)event {
    if (![self shouldForwardInput]) return;

    unsigned short macKeyCode = [event keyCode];
    unsigned int godotKeyCode = macos_to_godot_keycode(macKeyCode);

    NSString* chars = [event characters];
    unsigned int unicode = 0;
    if ([chars length] > 0) {
        unicode = [chars characterAtIndex:0];
    }

    libgodot_display_server_push_key_event(
        self.platformContext->godot_instance,
        godotKeyCode,
        godotKeyCode,
        godotKeyCode,
        unicode,
        LIBGODOT_KEY_LOCATION_UNSPECIFIED,
        false,
        false,
        [self modifiersFromEvent:event]
    );
}

- (void)flagsChanged:(NSEvent*)event {
    // Handle modifier key changes if needed
}

@end

// Target object that forwards UI button actions to the callbacks owned by the C++ side
@interface LibGodotTestControls : NSObject
@property (nonatomic, assign) PlatformContext* platformContext;
@end

@implementation LibGodotTestControls

- (void)startPressed:(id)sender {
    if (self.platformContext && self.platformContext->callbacks.on_start) {
        self.platformContext->callbacks.on_start();
    }
}

- (void)stopPressed:(id)sender {
    if (self.platformContext && self.platformContext->callbacks.on_stop) {
        self.platformContext->callbacks.on_stop();
    }
}

@end

// ============================================================================
// Layout Helper
// ============================================================================

static void updateLayout(PlatformContext* ctx) {
    if (!ctx || !ctx->window) return;

    NSRect contentRect = [[ctx->window contentView] bounds];
    const CGFloat buttonWidth = 110.0;
    const CGFloat buttonHeight = 30.0;
    const CGFloat buttonSpacing = 12.0;

    // Calculate Godot view frame (in points, unscaled)
    CGFloat godotX = ctx->inset_left;
    CGFloat godotY = ctx->inset_bottom;
    CGFloat godotWidth = contentRect.size.width - ctx->inset_left - ctx->inset_right;
    CGFloat godotHeight = contentRect.size.height - ctx->inset_top - ctx->inset_bottom;

    // Clamp to minimum size to avoid negative dimensions
    godotWidth = fmax(godotWidth, 1.0);
    godotHeight = fmax(godotHeight, 1.0);

    // Update godotView frame
    if (ctx->godotView) {
        ctx->godotView.frame = NSMakeRect(godotX, godotY, godotWidth, godotHeight);
    }

    // Update borderView frame (slightly larger to create border effect)
    if (ctx->borderView) {
        CGFloat borderPadding = 2.0;
        ctx->borderView.frame = NSMakeRect(
            godotX - borderPadding,
            godotY - borderPadding,
            godotWidth + borderPadding * 2,
            godotHeight + borderPadding * 2
        );
    }

    // Update titleLabel frame (positioned above the Godot area)
    if (ctx->titleLabel) {
        CGFloat labelHeight = 30.0;
        CGFloat labelY = contentRect.size.height - ctx->inset_top + 20;
        CGFloat labelWidth = godotWidth;
        if (ctx->startButton && ctx->stopButton) {
            CGFloat reservedSpace = buttonWidth * 2 + buttonSpacing + 8.0;
            labelWidth = fmax(godotWidth - reservedSpace, 100.0);
        }
        ctx->titleLabel.frame = NSMakeRect(ctx->inset_left, labelY, labelWidth, labelHeight);
    }

    // Position start/stop buttons in the header area
    if (ctx->startButton && ctx->stopButton) {
        CGFloat buttonY = contentRect.size.height - ctx->inset_top + 12.0;

        CGFloat stopX = contentRect.size.width - ctx->inset_right - buttonWidth;
        CGFloat startX = stopX - buttonWidth - buttonSpacing;

        ctx->startButton.frame = NSMakeRect(startX, buttonY, buttonWidth, buttonHeight);
        ctx->stopButton.frame = NSMakeRect(stopX, buttonY, buttonWidth, buttonHeight);
    }

    // Update stored dimensions (in pixels, scaled)
    ctx->width = (int)(godotWidth * ctx->scale);
    ctx->height = (int)(godotHeight * ctx->scale);

    // Update CAMetalLayer drawable size
    if (ctx->metalLayer) {
        ctx->metalLayer.drawableSize = CGSizeMake(ctx->width, ctx->height);
    }

    // Match overlay to Godot view area
    if (ctx->overlayView && ctx->godotView) {
        ctx->overlayView.frame = ctx->godotView.frame;
    }
}

// ============================================================================
// Window Delegate
// ============================================================================

@interface LibGodotTestWindowDelegate : NSObject <NSWindowDelegate>
@property (nonatomic, assign) PlatformContext* platformContext;
@end

@implementation LibGodotTestWindowDelegate

- (void)windowDidBecomeKey:(NSNotification*)notification {
    self.platformContext->focused = true;
    if (self.platformContext->godot_instance) {
        libgodot_display_server_push_window_event(
            self.platformContext->godot_instance,
            LIBGODOT_WINDOW_EVENT_FOCUS_IN,
            LIBGODOT_MAIN_WINDOW_ID
        );
    }
}

- (void)windowDidResignKey:(NSNotification*)notification {
    self.platformContext->focused = false;
    if (self.platformContext->godot_instance) {
        libgodot_display_server_push_window_event(
            self.platformContext->godot_instance,
            LIBGODOT_WINDOW_EVENT_FOCUS_OUT,
            LIBGODOT_MAIN_WINDOW_ID
        );
    }
}

- (void)windowDidResize:(NSNotification*)notification {
    PlatformContext* ctx = self.platformContext;
    if (!ctx) return;

    // Store old dimensions to detect actual changes
    int oldWidth = ctx->width;
    int oldHeight = ctx->height;

    // Recalculate and apply layout for all views
    updateLayout(ctx);

    // Notify Godot if dimensions actually changed
    if ((ctx->width != oldWidth || ctx->height != oldHeight) && ctx->godot_instance) {
        libgodot_display_server_notify_window_size_changed(
            ctx->godot_instance,
            LIBGODOT_MAIN_WINDOW_ID,
            ctx->width, ctx->height
        );
    }
}

- (void)windowDidChangeBackingProperties:(NSNotification*)notification {
    PlatformContext* ctx = self.platformContext;
    if (!ctx || !ctx->window) return;

    // Check if scale factor changed (e.g., window moved between Retina and non-Retina displays)
    CGFloat newScale = [[ctx->window screen] backingScaleFactor];
    if (newScale != ctx->scale) {
        ctx->scale = newScale;

        // Update Metal layer contents scale
        if (ctx->metalLayer) {
            ctx->metalLayer.contentsScale = newScale;
        }

        // Recalculate layout with new scale
        updateLayout(ctx);

        // Notify Godot of size change (dimensions in pixels changed due to scale)
        if (ctx->godot_instance) {
            libgodot_display_server_notify_window_size_changed(
                ctx->godot_instance,
                LIBGODOT_MAIN_WINDOW_ID,
                ctx->width, ctx->height
            );
        }
    }
}

- (BOOL)windowShouldClose:(NSWindow*)sender {
    if (self.platformContext->godot_instance) {
        libgodot_display_server_push_window_event(
            self.platformContext->godot_instance,
            LIBGODOT_WINDOW_EVENT_CLOSE_REQUEST,
            LIBGODOT_MAIN_WINDOW_ID
        );
    }
    if (self.platformContext->callbacks.on_quit) {
        self.platformContext->callbacks.on_quit();
    }
    self.platformContext->running = false;
    return NO; // Let the app handle closing
}

@end

// ============================================================================
// Platform API Implementation
// ============================================================================

PlatformContext* platform_init(int width, int height, const char* title) {
    @autoreleasepool {
        // Initialize NSApplication
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

        PlatformContext* ctx = new PlatformContext();
        ctx->scale = [[NSScreen mainScreen] backingScaleFactor];

        g_ctx = ctx;

        // Window size includes insets
        int windowWidth = width + ctx->inset_left + ctx->inset_right;
        int windowHeight = height + ctx->inset_top + ctx->inset_bottom;

        // Godot rendering area size (in pixels)
        ctx->width = (int)(width * ctx->scale);
        ctx->height = (int)(height * ctx->scale);

        // Create window
        NSRect windowRect = NSMakeRect(0, 0, windowWidth, windowHeight);
        NSWindowStyleMask styleMask = NSWindowStyleMaskTitled |
                                       NSWindowStyleMaskClosable |
                                       NSWindowStyleMaskMiniaturizable |
                                       NSWindowStyleMaskResizable;

        ctx->window = [[NSWindow alloc] initWithContentRect:windowRect
                                                  styleMask:styleMask
                                                    backing:NSBackingStoreBuffered
                                                      defer:NO];

        if (!ctx->window) {
            std::cerr << "Failed to create NSWindow" << std::endl;
            delete ctx;
            return nullptr;
        }

        [ctx->window setTitle:[NSString stringWithUTF8String:title]];
        [ctx->window center];
        [ctx->window setAcceptsMouseMovedEvents:YES];
        [ctx->window setBackgroundColor:[NSColor colorWithCalibratedRed:0.2 green:0.2 blue:0.25 alpha:1.0]];

        // Create container view (fills the window)
        NSView* containerView = [[NSView alloc] initWithFrame:windowRect];
        containerView.wantsLayer = YES;
        containerView.layer.backgroundColor = [[NSColor colorWithCalibratedRed:0.2 green:0.2 blue:0.25 alpha:1.0] CGColor];
        [ctx->window setContentView:containerView];
        ctx->containerView = containerView;

        // Create title label
        NSRect labelRect = NSMakeRect(ctx->inset_left, windowHeight - 50, width, 30);
        NSTextField* label = [[NSTextField alloc] initWithFrame:labelRect];
        label.stringValue = @"Embedded Godot Project";
        label.font = [NSFont boldSystemFontOfSize:18];
        label.textColor = [NSColor whiteColor];
        label.backgroundColor = [NSColor clearColor];
        label.bordered = NO;
        label.editable = NO;
        label.selectable = NO;
        [containerView addSubview:label];
        ctx->titleLabel = label;

        // Set up start/stop controls
        LibGodotTestControls* controls = [[LibGodotTestControls alloc] init];
        controls.platformContext = ctx;
        ctx->controlsTarget = controls;

        NSButton* startButton = [NSButton buttonWithTitle:@"Start"
                                                   target:controls
                                                   action:@selector(startPressed:)];
        startButton.bezelStyle = NSBezelStyleRounded;
        startButton.font = [NSFont systemFontOfSize:14 weight:NSFontWeightSemibold];
        startButton.wantsLayer = YES;
        startButton.layer.cornerRadius = 6.0;
        [containerView addSubview:startButton];
        ctx->startButton = startButton;

        NSButton* stopButton = [NSButton buttonWithTitle:@"Stop"
                                                  target:controls
                                                  action:@selector(stopPressed:)];
        stopButton.bezelStyle = NSBezelStyleRounded;
        stopButton.font = [NSFont systemFontOfSize:14 weight:NSFontWeightSemibold];
        stopButton.wantsLayer = YES;
        stopButton.layer.cornerRadius = 6.0;
        [containerView addSubview:stopButton];
        ctx->stopButton = stopButton;

        // Create border view (slightly larger than Godot view for border effect)
        int borderWidth = 2;
        NSRect borderRect = NSMakeRect(ctx->inset_left - borderWidth,
                                       ctx->inset_bottom - borderWidth,
                                       width + borderWidth * 2,
                                       height + borderWidth * 2);
        NSView* borderView = [[NSView alloc] initWithFrame:borderRect];
        borderView.wantsLayer = YES;
        borderView.layer.backgroundColor = [[NSColor colorWithCalibratedRed:0.4 green:0.4 blue:0.5 alpha:1.0] CGColor];
        borderView.layer.cornerRadius = 4;
        [containerView addSubview:borderView];
        ctx->borderView = borderView;

        // Create Godot view (where Metal rendering happens)
        NSRect godotRect = NSMakeRect(ctx->inset_left, ctx->inset_bottom, width, height);
        LibGodotTestView* godotView = [[LibGodotTestView alloc] initWithFrame:godotRect];
        godotView.platformContext = ctx;
        godotView.wantsLayer = YES;  // Force layer creation immediately
        [containerView addSubview:godotView];
        ctx->godotView = godotView;

        // Overlay view used to gray-out the last frame when stopped
        NSView* overlay = [[NSView alloc] initWithFrame:godotRect];
        overlay.wantsLayer = YES;
        overlay.layer.backgroundColor = [[NSColor colorWithCalibratedWhite:0.1 alpha:0.55] CGColor];
        overlay.hidden = YES;
        [containerView addSubview:overlay positioned:NSWindowAbove relativeTo:godotView];
        ctx->overlayView = overlay;

        // Force the layer to be created now by accessing it
        CALayer* layer = [godotView layer];
        if (![layer isKindOfClass:[CAMetalLayer class]]) {
            std::cerr << "View layer is not a CAMetalLayer!" << std::endl;
            delete ctx;
            return nullptr;
        }

        ctx->metalLayer = (CAMetalLayer*)layer;
        // Set drawable size in pixels (scaled)
        ctx->metalLayer.drawableSize = CGSizeMake(ctx->width, ctx->height);
        ctx->metalLayer.contentsScale = ctx->scale;

        // Set up window delegate
        LibGodotTestWindowDelegate* delegate = [[LibGodotTestWindowDelegate alloc] init];
        delegate.platformContext = ctx;
        [ctx->window setDelegate:delegate];

        // Set up display server interface
        ctx->interface.user_data = ctx;
        ctx->interface.get_name = ds_get_name;
        ctx->interface.get_screen_count = ds_get_screen_count;
        ctx->interface.get_primary_screen = ds_get_primary_screen;
        ctx->interface.get_screen_position = ds_get_screen_position;
        ctx->interface.get_screen_size = ds_get_screen_size;
        ctx->interface.get_screen_dpi = ds_get_screen_dpi;
        ctx->interface.get_screen_scale = ds_get_screen_scale;
        ctx->interface.get_screen_refresh_rate = ds_get_screen_refresh_rate;
        ctx->interface.get_window_position = ds_get_window_position;
        ctx->interface.get_window_size = ds_get_window_size;
        ctx->interface.set_window_size = ds_set_window_size;
        ctx->interface.set_window_position = ds_set_window_position;
        ctx->interface.window_can_draw = ds_window_can_draw;
        ctx->interface.window_is_focused = ds_window_is_focused;
        ctx->interface.process_events = ds_process_events;
        ctx->interface.get_native_handle = ds_get_native_handle;
        ctx->interface.swap_buffers = ds_swap_buffers;
        ctx->interface.mouse_set_mode = ds_mouse_set_mode;
        ctx->interface.mouse_get_mode = ds_mouse_get_mode;
        ctx->interface.warp_mouse = ds_warp_mouse;
        ctx->interface.get_mouse_position = ds_get_mouse_position;
        ctx->interface.get_mouse_button_state = ds_get_mouse_button_state;
        ctx->interface.cursor_set_shape = ds_cursor_set_shape;
        ctx->interface.set_window_title = ds_set_window_title;

        // Apply initial layout/state to controls before showing the window
        updateLayout(ctx);
        platform_set_run_state(ctx, false, nullptr);

        return ctx;
    }
}

void platform_shutdown(PlatformContext* ctx) {
    if (!ctx) return;

    @autoreleasepool {
        if (ctx->window) {
            [ctx->window close];
            ctx->window = nil;
        }

        g_ctx = nullptr;
        delete ctx;
    }
}

void platform_run(PlatformContext* ctx, PlatformCallbacks callbacks) {
    if (!ctx) return;

    ctx->callbacks = callbacks;
    ctx->running = true;

    @autoreleasepool {
        // Show window
        [ctx->window makeKeyAndOrderFront:nil];
        [NSApp activateIgnoringOtherApps:YES];

        // Main loop
        while (ctx->running) {
            @autoreleasepool {
                // Process events
                NSEvent* event;
                while ((event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                                  untilDate:nil
                                                     inMode:NSDefaultRunLoopMode
                                                    dequeue:YES])) {
                    [NSApp sendEvent:event];
                }

                // Call frame callback
                if (callbacks.on_frame) {
                    if (callbacks.on_frame()) {
                        ctx->running = false;
                    }
                }
            }
        }
    }
}

LibGodotDisplayServerInterface* platform_get_display_server_interface(PlatformContext* ctx) {
    if (!ctx) return nullptr;
    return &ctx->interface;
}

void platform_set_window_title(PlatformContext* ctx, const char* title) {
    if (!ctx || !title) return;

    @autoreleasepool {
        // Update the label inside the window
        if (ctx->titleLabel) {
            [ctx->titleLabel setStringValue:[NSString stringWithUTF8String:title]];
        }
    }
}

void platform_set_run_state(PlatformContext* ctx, bool project_running, const char* status_text) {
    if (!ctx) return;

    ctx->project_running = project_running;

    @autoreleasepool {
        if (ctx->overlayView) {
            ctx->overlayView.hidden = project_running;
        }
        if (ctx->godotView && ctx->godotView.layer) {
            ctx->godotView.layer.opacity = project_running ? 1.0 : 0.55;
        }
        if (ctx->startButton) {
            [ctx->startButton setEnabled:!project_running];
            ctx->startButton.alphaValue = project_running ? 0.6 : 1.0;
        }
        if (ctx->stopButton) {
            [ctx->stopButton setEnabled:project_running];
            ctx->stopButton.alphaValue = project_running ? 1.0 : 0.6;
        }
        if (ctx->titleLabel && status_text) {
            [ctx->titleLabel setStringValue:[NSString stringWithUTF8String:status_text]];
        }
    }
}

// Helper to set the Godot instance on the context (called from main after creation)
extern "C" void platform_set_godot_instance(PlatformContext* ctx, GDExtensionObjectPtr instance) {
    if (ctx) {
        ctx->godot_instance = instance;
    }
}
