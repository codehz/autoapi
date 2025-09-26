const win32 = @import("win32");
const std = @import("std");
const memory = @import("./memory.zig");

const keyboard_and_mouse = win32.ui.input.keyboard_and_mouse;

export fn input_text(text: [*:0]const u8) callconv(.c) u32 {
    var sfa = memory.fallbackAllocator();
    const allocator = sfa.get();
    const slice: []const u8 = std.mem.span(text);
    const view = std.unicode.Wtf8View.init(slice) catch @panic("failed to decode wtf8 input");
    const inputs = allocator.alloc(keyboard_and_mouse.INPUT, slice.len * 2) catch @panic("failed to alloc");
    defer allocator.free(inputs);
    var it = view.iterator();
    var count: usize = 0;
    while (it.nextCodepoint()) |codepoint| {
        if (codepoint < 0x10000) {
            const code = std.mem.nativeToLittle(u16, @intCast(codepoint));
            inputs[count] = input_from_scan(code, false);
            count += 1;
            inputs[count] = input_from_scan(code, true);
            count += 1;
        } else {
            const high = @as(u16, @intCast((codepoint - 0x10000) >> 10)) + 0xD800;
            const low = @as(u16, @intCast(codepoint & 0x3FF)) + 0xDC00;
            inputs[count] = input_from_scan(high, false);
            count += 1;
            inputs[count] = input_from_scan(high, true);
            count += 1;
            inputs[count] = input_from_scan(low, false);
            count += 1;
            inputs[count] = input_from_scan(low, true);
            count += 1;
        }
    }
    return keyboard_and_mouse.SendInput(
        @intCast(count),
        inputs.ptr,
        @sizeOf(keyboard_and_mouse.INPUT),
    );
}

export fn input_send(inputs: [*]const keyboard_and_mouse.INPUT, count: u32) callconv(.c) u32 {
    return keyboard_and_mouse.SendInput(
        @intCast(count),
        @constCast(inputs),
        @sizeOf(keyboard_and_mouse.INPUT),
    );
}

fn input_from_scan(scan: u16, keyup: bool) keyboard_and_mouse.INPUT {
    var result = std.mem.zeroes(keyboard_and_mouse.INPUT);
    result.type = .KEYBOARD;
    result.Anonymous.ki.wScan = scan;
    result.Anonymous.ki.dwFlags = .{ .UNICODE = 1, .KEYUP = @intFromBool(keyup) };
    return result;
}
