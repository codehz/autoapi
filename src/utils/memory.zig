const std = @import("std");

pub fn fallbackAllocator() std.heap.StackFallbackAllocator(4096) {
    return std.heap.stackFallback(4096, std.heap.raw_c_allocator);
}

pub fn toWtf16Z(allocator: std.mem.Allocator, input: [*:0]const u8) [:0]u16 {
    return std.unicode.wtf8ToWtf16LeAllocZ(allocator, std.mem.span(input)) catch unreachable;
}
