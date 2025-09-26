const std = @import("std");

pub fn lazy(comptime T: type, comptime lazy_fn: anytype) fn () T {
    return struct {
        var data: ?T = undefined;
        pub fn ptr() T {
            return data orelse data: {
                data = lazy_fn();
                break :data data.?;
            };
        }
    }.ptr;
}
