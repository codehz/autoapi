const std = @import("std");
const ScreenCapture = @import("./utils/ScreenCapture.zig");
const Image = @import("./utils/Image.zig");

var capture: ScreenCapture = .{};

pub export fn screenshot() *Image {
    capture.capture(std.heap.raw_c_allocator);
    return &capture.screenshot;
}
