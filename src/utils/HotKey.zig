const std = @import("std");
const win32 = @import("win32");
const keyboard_and_mouse = win32.ui.input.keyboard_and_mouse;
const VirtualKey = @import("./VirtualKey.zig");

const MAX_HOTKEYS = 256;

var hotkeys: [MAX_HOTKEYS]@This() = undefined;
var id_max: u8 = 0;

fn id_alloc() ?usize {
    if (id_max >= MAX_HOTKEYS) return null;
    defer id_max += 1;
    return @intCast(id_max);
}

callback: *const fn () callconv(.c) void,

pub fn notify(id: usize) void {
    if (id >= id_max) return;
    hotkeys[id].callback();
}

fn parseHotKey(hotkey_str: [*:0]const u8) !struct { keyboard_and_mouse.HOT_KEY_MODIFIERS, u32 } {
    var modifiers: keyboard_and_mouse.HOT_KEY_MODIFIERS = .{};

    var i: usize = 0;
    while (hotkey_str[i] != 0) : (i += 1) {
        const char = hotkey_str[i];
        switch (char) {
            '#' => modifiers.WIN = 1,
            '!' => modifiers.ALT = 1,
            '^' => modifiers.CONTROL = 1,
            '+' => modifiers.SHIFT = 1,
            else => {
                const vk_str: []const u8 = std.mem.span(hotkey_str[i..]);
                const vk = try VirtualKey.parseVK(vk_str);
                return .{ modifiers, @intCast(vk) };
            },
        }
    }
    return error.InvalidHotKey;
}

pub fn new(hotkey: [*:0]const u8, callback: *const fn () callconv(.c) void) callconv(.c) i32 {
    const fsModifiers, const vk = parseHotKey(hotkey) catch return -1;
    const id = id_alloc() orelse return -2;
    hotkeys[id].callback = callback;
    if (keyboard_and_mouse.RegisterHotKey(null, @intCast(id), fsModifiers, vk) == 0) {
        std.log.err("Failed to register hot key: {f}", .{win32.foundation.GetLastError()});
        return -3;
    }
    return @intCast(id);
}

pub fn delete(id: u32) callconv(.c) i32 {
    if (id >= id_max) return -1;
    if (0 == keyboard_and_mouse.UnregisterHotKey(null, @intCast(id))) {
        return @intCast(@intFromEnum(win32.foundation.GetLastError()));
    }
    return 0;
}

comptime {
    @export(&new, .{ .name = "hotkey_new" });
    @export(&delete, .{ .name = "hotkey_delete" });
}
