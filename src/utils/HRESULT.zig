const win32 = @import("win32");
const std = @import("std");

pub fn check(what: []const u8, result: i32) void {
    if (win32.zig.FAILED(result)) {
        @branchHint(.unlikely);
        win32.zig.panicHresult(what, result);
    }
}

threadlocal var last_hresult: ?i32 = null;

pub fn report(result: i32) error{HRESULT}!void {
    if (win32.zig.FAILED(result)) {
        @branchHint(.unlikely);
        last_hresult = result;
        return error.HRESULT;
    }
}

pub fn last() i32 {
    defer last_hresult = null;
    return last_hresult.?;
}

pub fn set(result: i32) void {
    last_hresult = result;
}

threadlocal var format_error_buffer_w: [1024]u16 = undefined;
threadlocal var format_error_buffer: [4096]u8 = undefined;

export fn format_error(result: i32) [*:0]const u8 {
    const len = win32.system.diagnostics.debug.FormatMessageW(
        .{ .FROM_SYSTEM = 1, .IGNORE_INSERTS = 1 },
        null,
        @bitCast(result),
        0,
        @ptrCast(&format_error_buffer_w),
        @intCast(format_error_buffer_w.len),
        null,
    );
    const slice = format_error_buffer_w[0..len];
    const wtf8len = std.unicode.wtf16LeToWtf8(&format_error_buffer, slice);
    const trimed = std.mem.lastIndexOfScalar(u8, format_error_buffer[0..wtf8len], '\r') orelse wtf8len;
    format_error_buffer[trimed] = 0;
    return format_error_buffer[0..trimed :0].ptr;
}
