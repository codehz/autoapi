const std = @import("std");
const win32 = @import("win32");
const keyboard_and_mouse = win32.ui.input.keyboard_and_mouse;

pub fn parseVK(vk_str: []const u8) !u16 {
    const virtual_key = std.meta.stringToEnum(keyboard_and_mouse.VIRTUAL_KEY, vk_str) orelse return error.InvalidHotKey;
    return @intFromEnum(virtual_key);
}
