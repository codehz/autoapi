const win32 = @import("win32");
const HRESULT = @import("./HRESULT.zig");

const com = win32.system.com;
const zig = win32.zig;

var COM_INITED = false;

fn init_com_if_needed() void {
    if (!COM_INITED) {
        const hr = com.CoInitializeEx(null, .{ .APARTMENTTHREADED = 1 });
        HRESULT.check("CoInitializeEx", hr);
        COM_INITED = true;
    }
}

pub fn CreateInstance(comptime class: *const zig.Guid, comptime interface: *const zig.Guid, comptime Type: type) *Type {
    init_com_if_needed();
    var result: *Type = undefined;
    const hr = com.CoCreateInstance(
        class,
        null,
        .{ .INPROC_SERVER = 1 },
        interface,
        @ptrCast(&result),
    );
    HRESULT.check("Create COM instance: " ++ @typeName(Type), hr);
    return result;
}

pub fn LazyCreateInstance(comptime class: *const zig.Guid, comptime interface: *const zig.Guid, comptime Type: type) fn () *Type {
    return struct {
        var holder: ?*Type = undefined;
        pub fn ptr() *Type {
            if (holder == null) {
                holder = CreateInstance(class, interface, Type);
            }
            return holder.?;
        }
    }.ptr;
}
