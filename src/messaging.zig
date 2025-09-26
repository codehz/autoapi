const win32 = @import("win32");
const std = @import("std");
const memory = @import("./utils/memory.zig");

pub export fn msgbox(title: [*:0]const u8, text: [*:0]const u8) i32 {
    var sfa = memory.fallbackAllocator();
    const allocator = sfa.get();
    const wtitle = memory.toWtf16Z(allocator, title);
    defer allocator.free(wtitle);
    const wtext = memory.toWtf16Z(allocator, text);
    defer allocator.free(wtext);
    const result = win32.ui.windows_and_messaging.MessageBoxW(null, wtext, wtitle, .{ .OKCANCEL = 1 });
    return @intFromEnum(result);
}
