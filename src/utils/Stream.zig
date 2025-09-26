const win32 = @import("win32");
const HRESULT = @import("./HRESULT.zig");
const shell = win32.ui.shell;
const com = win32.system.com;
const storage = com.structured_storage;

inner: ?*com.IStream,

pub fn createStreamOnFile(path: [*:0]const u16, comptime mode: storage.STGM) !@This() {
    var result: @This() = undefined;
    const hr = shell.SHCreateStreamOnFileW(path, @bitCast(mode), &result.inner);
    HRESULT.report(hr) catch return error.SHCreateStreamOnFileW;
    return result;
}

pub fn deinit(self: @This()) void {
    _ = self.inner.?.IUnknown.Release();
}
