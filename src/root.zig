//! By convention, root.zig is the root source file when making a library.
pub const UNICODE = true;

const std = @import("std");
const win32 = @import("win32");
const HRESULT = @import("./utils/HRESULT.zig");

comptime {
    _ = @import("./messaging.zig");
    _ = @import("./loop.zig");
    _ = @import("./screen.zig");
    _ = @import("./utils/Input.zig");
    _ = @import("./utils/KeyState.zig");
}

pub fn DllMain(instance: std.os.windows.HINSTANCE, reason: std.os.windows.DWORD, reserved: std.os.windows.LPVOID) std.os.windows.BOOL {
    _ = instance;
    _ = reserved;

    if (reason == 1) {
        var hr: i32 = undefined;
        hr = win32.ui.hi_dpi.SetProcessDpiAwareness(.PER_MONITOR_DPI_AWARE);
        HRESULT.check("SetProcessDpiAwareness", hr);

        if (win32.system.stations_and_desktops.OpenInputDesktop(
            0,
            0,
            win32.system.system_services.GENERIC_ALL,
        )) |desktop| {
            defer _ = win32.system.stations_and_desktops.CloseDesktop(desktop);
            if (win32.system.stations_and_desktops.SetThreadDesktop(desktop) == 0) {
                @panic("failed to set thread desktop");
            }
        } else {
            @panic("failed to open desktop");
        }
    }

    return std.os.windows.TRUE;
}
