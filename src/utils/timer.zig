const std = @import("std");

const Timer = struct {
    id: u32,
    interval: u64,
    target: u64,
    repeat: bool,
    callback: ?*const fn () callconv(.c) void,
};

pub fn TimerManager(comptime MAX_TIMERS: comptime_int) type {
    comptime {
        if (MAX_TIMERS == 0) @compileError("MAX_TIMERS must be greater than 0");
    }

    return struct {
        const Self = @This();

        timers: [MAX_TIMERS]Timer, // Fixed-size timer pool
        active_timers: std.bit_set.StaticBitSet(MAX_TIMERS), // Tracks active timers

        pub const empty = std.mem.zeroes(Self);

        pub fn add_timer(self: *Self, current_tick: u64, interval: u64, repeat: bool, callback: ?*const fn () callconv(.c) void) ?u32 {
            var it = self.active_timers.iterator(.{ .kind = .unset });
            const id = it.next() orelse {
                return null;
            };
            self.active_timers.set(@intCast(id));

            const target = current_tick + @as(u64, interval);

            self.timers[id].id = @intCast(id);
            self.timers[id].interval = interval;
            self.timers[id].target = target;
            self.timers[id].repeat = repeat;
            self.timers[id].callback = callback;

            return @intCast(id);
        }

        pub fn remove_timer(self: *Self, id: u32) void {
            if (id >= MAX_TIMERS) return;
            self.active_timers.unset(@intCast(id));
        }

        pub fn get_next_target(self: *Self) u64 {
            var result: u64 = std.math.maxInt(u64);
            var it = self.active_timers.iterator(.{});
            while (it.next()) |id| {
                const timer = &self.timers[id];
                if (timer.target < result) {
                    result = timer.target;
                }
            }
            return result;
        }

        pub fn process_timers(self: *Self, tick: u64) void {
            var it = self.active_timers.iterator(.{});
            while (it.next()) |id| {
                const timer = &self.timers[id];
                if (timer.target <= tick) {
                    if (timer.callback) |callback| callback();
                    if (timer.repeat) {
                        timer.target = tick + timer.interval;
                    } else {
                        self.active_timers.unset(id);
                    }
                }
            }
        }
    };
}
