const std = @import("std");
const win32 = @import("win32");
const HotKey = @import("./utils/HotKey.zig");
const foundation = win32.foundation;
const messaging = win32.ui.windows_and_messaging;

const MSG_REFRESH = messaging.WM_APP;

var msg: messaging.MSG = undefined;

var mainThreadId: u32 = undefined;

const timer = @import("./utils/timer.zig");
var manager = timer.TimerManager(1024).empty;

fn CtrlCHandler(code: u32) callconv(.winapi) i32 {
    std.debug.print("Ctrl-C\n", .{});
    return messaging.PostThreadMessageW(
        mainThreadId,
        messaging.WM_QUIT,
        @intCast(code),
        0,
    );
}

pub export fn loop() callconv(.c) i32 {
    mainThreadId = win32.system.threading.GetCurrentThreadId();
    _ = win32.system.console.SetConsoleCtrlHandler(CtrlCHandler, win32.zig.TRUE);
    defer _ = win32.system.console.SetConsoleCtrlHandler(CtrlCHandler, win32.zig.FALSE);
    while (true) {
        const start_tick: u64 = @intCast(std.time.milliTimestamp());
        const next_target = manager.get_next_target();
        const next = if (next_target <= start_tick) 0 else next_target - start_tick;
        const next32: u32 = if (next > std.math.maxInt(u32)) std.math.maxInt(u32) else @intCast(next);
        const result = messaging.MsgWaitForMultipleObjectsEx(
            0,
            null,
            next32,
            messaging.QS_ALLINPUT,
            .{},
        );
        switch (result) {
            @intFromEnum(foundation.WAIT_TIMEOUT) => {
                manager.process_timers(@intCast(std.time.milliTimestamp()));
            },
            @intFromEnum(foundation.WAIT_OBJECT_0) => {
                while (messaging.PeekMessageW(
                    &msg,
                    null,
                    0,
                    0,
                    messaging.PM_REMOVE,
                ) != 0) {
                    switch (msg.message) {
                        MSG_REFRESH => {},
                        messaging.WM_QUIT => return @intCast(msg.wParam),
                        messaging.WM_HOTKEY => HotKey.notify(msg.wParam),
                        else => {
                            _ = messaging.TranslateMessage(&msg);
                            _ = messaging.DispatchMessageW(&msg);
                        },
                    }
                }
            },
            else => {},
        }
    }
}

pub export fn quit(code: i32) callconv(.c) void {
    messaging.PostQuitMessage(code);
}

pub export fn timer_new(interval: u64, repeat: bool, callback: ?*const fn () callconv(.c) void) callconv(.c) u32 {
    _ = messaging.PostMessageW(null, MSG_REFRESH, 0, 0);
    const current_tick: u64 = @intCast(std.time.milliTimestamp());
    return manager.add_timer(current_tick, interval, repeat, callback) orelse
        return std.math.maxInt(u32);
}

pub export fn timer_remove(id: u32) callconv(.c) void {
    manager.remove_timer(id);
}
