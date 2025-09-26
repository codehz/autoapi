const win32 = @import("win32");
const std = @import("std");

pub fn HRESULT(what: []const u8, result: i32) void {
    if (win32.zig.FAILED(result)) {
        @branchHint(.unlikely);
        win32.zig.panicHresult(what, result);
    }
}

var last_hresult: i32 = 0;

pub fn reportHRESULT(result: i32) error.HRESULT!void {
    if (win32.zig.FAILED(result)) {
        @branchHint(.unlikely);
        last_hresult = result;
        return error.HRESULT;
    }
    return;
}
