const std = @import("std");
const win32 = @import("win32");
const HRESULT = @import("./HRESULT.zig");
const d3d = win32.graphics.direct3d;
const d3d11 = win32.graphics.direct3d11;
const dxgi = win32.graphics.dxgi;

const Image = @import("./Image.zig");

pub const ScreenSize = struct {
    width: i32,
    height: i32,
};

factory: *dxgi.IDXGIFactory1 = undefined,
adapter: *dxgi.IDXGIAdapter1 = undefined,
device: *d3d11.ID3D11Device = undefined,
context: *d3d11.ID3D11DeviceContext = undefined,
duplication: *dxgi.IDXGIOutputDuplication = undefined,

screenshot: Image = undefined,

inited: bool = false,

pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
    if (!self.inited) return;
    defer self.inited = false;

    allocator.destroy(self.buffer);

    self.duplication.ReleaseFrame();
    self.duplication.IUnknown.Release();

    self.context.IUnknown.Release();
    self.device.IUnknown.Release();
    self.adapter.IUnknown.Release();
    self.factory.IUnknown.Release();
}

pub fn init(self: *@This(), allocator: std.mem.Allocator) void {
    if (self.inited) return;
    defer self.inited = true;

    var hr: i32 = undefined;

    hr = dxgi.CreateDXGIFactory1(dxgi.IID_IDXGIFactory1, @ptrCast(&self.factory));
    HRESULT.check("create dxgi factory", hr);

    hr = self.factory.EnumAdapters1(0, &self.adapter);
    HRESULT.check("get dxgi adapter", hr);

    var feature_level: d3d.D3D_FEATURE_LEVEL = undefined;
    hr = d3d11.D3D11CreateDevice(
        &self.adapter.IDXGIAdapter,
        d3d.D3D_DRIVER_TYPE_UNKNOWN,
        null,
        .{},
        null,
        0,
        d3d11.D3D11_SDK_VERSION,
        &self.device,
        &feature_level,
        &self.context,
    );
    HRESULT.check("create d3d11 device", hr);

    var output: *dxgi.IDXGIOutput = undefined;
    hr = self.adapter.IDXGIAdapter.EnumOutputs(0, &output);
    HRESULT.check("get dxgi output", hr);
    defer _ = output.IUnknown.Release();

    var output_desc: dxgi.DXGI_OUTPUT_DESC = undefined;
    hr = output.GetDesc(&output_desc);
    HRESULT.check("get dxgi output desc", hr);

    var output1: *dxgi.IDXGIOutput1 = undefined;
    hr = output.IUnknown.QueryInterface(dxgi.IID_IDXGIOutput1, @ptrCast(&output1));
    HRESULT.check("get dxgi output1", hr);
    defer _ = output1.IUnknown.Release();

    hr = output1.DuplicateOutput(&self.device.IUnknown, &self.duplication);
    HRESULT.check("duplicate output", hr);

    self.screenshot.init(
        allocator,
        output_desc.DesktopCoordinates.right - output_desc.DesktopCoordinates.left,
        output_desc.DesktopCoordinates.bottom - output_desc.DesktopCoordinates.top,
    );
}

pub fn capture(self: *@This(), allocator: std.mem.Allocator) void {
    self.initIfNeeded(allocator);

    var hr: i32 = undefined;
    var frame_info: dxgi.DXGI_OUTDUPL_FRAME_INFO = undefined;

    var desktop_resource: *dxgi.IDXGIResource = undefined;

    while (true) {
        hr = self.duplication.AcquireNextFrame(1000, &frame_info, &desktop_resource);
        HRESULT.check("acquire next frame", hr);
        if (frame_info.LastPresentTime.QuadPart != 0) break;
        hr = self.duplication.ReleaseFrame();
        HRESULT.check("release frame", hr);
        _ = desktop_resource.IUnknown.Release();
    }

    var acquired_texture: *d3d11.ID3D11Texture2D = undefined;
    hr = desktop_resource.IUnknown.QueryInterface(d3d11.IID_ID3D11Texture2D, @ptrCast(&acquired_texture));
    HRESULT.check("get acquired desktop image", hr);
    defer _ = acquired_texture.IUnknown.Release();

    var staging_texture: *d3d11.ID3D11Texture2D = undefined;
    var desc: d3d11.D3D11_TEXTURE2D_DESC = undefined;
    acquired_texture.GetDesc(&desc);
    desc.CPUAccessFlags = .{ .READ = 1, .WRITE = 1 };
    desc.Usage = .STAGING;
    desc.BindFlags = .{};
    desc.MiscFlags = .{};
    hr = self.device.CreateTexture2D(&desc, null, &staging_texture);
    HRESULT.check("create staging texture", hr);
    defer _ = staging_texture.IUnknown.Release();

    self.context.CopyResource(&staging_texture.ID3D11Resource, &acquired_texture.ID3D11Resource);

    var mapped: d3d11.D3D11_MAPPED_SUBRESOURCE = undefined;
    hr = self.context.Map(
        &staging_texture.ID3D11Resource,
        0,
        d3d11.D3D11_MAP_READ,
        0,
        &mapped,
    );
    HRESULT.check("map resource", hr);
    defer self.context.Unmap(&staging_texture.ID3D11Resource, 0);

    const dst: []u8 = self.screenshot.data;
    const src: [*]u8 = @ptrCast(mapped.pData);

    for (0..@intCast(self.screenshot.height)) |y| {
        const pitch: usize = @intCast(mapped.RowPitch);
        const bytes_per_row: usize = @intCast(self.screenshot.width * 4);
        @memcpy(
            dst[y * bytes_per_row ..][0..bytes_per_row],
            src[y * pitch ..][0..bytes_per_row],
        );
    }
}

fn initIfNeeded(self: *@This(), allocator: std.mem.Allocator) void {
    if (self.inited) {
        var hr: i32 = undefined;

        var output: *dxgi.IDXGIOutput = undefined;
        hr = self.adapter.IDXGIAdapter.EnumOutputs(0, &output);
        HRESULT.check("get dxgi output", hr);
        defer _ = output.IUnknown.Release();

        var output_desc: dxgi.DXGI_OUTPUT_DESC = undefined;
        hr = output.GetDesc(&output_desc);
        HRESULT.check("get dxgi output desc", hr);

        const width = output_desc.DesktopCoordinates.right - output_desc.DesktopCoordinates.left;
        const height = output_desc.DesktopCoordinates.bottom - output_desc.DesktopCoordinates.top;

        if (width != self.screenshot.width or height != self.screenshot.height) {
            _ = self.duplication.ReleaseFrame();
            _ = self.duplication.IUnknown.Release();

            // self.size = newsize;

            var output1: *dxgi.IDXGIOutput1 = undefined;
            hr = output.IUnknown.QueryInterface(dxgi.IID_IDXGIOutput1, @ptrCast(&output1));
            HRESULT.check("get dxgi output1", hr);
            defer _ = output1.IUnknown.Release();

            hr = output1.DuplicateOutput(&self.device.IUnknown, &self.duplication);
            HRESULT.check("duplicate output", hr);

            self.screenshot.resize(allocator, width, height);
        }
    } else {
        self.init(allocator);
    }
}

fn createTextureDesc(size: ScreenSize) d3d11.D3D11_TEXTURE2D_DESC {
    return .{
        .Width = @intCast(size.width),
        .Height = @intCast(size.height),
        .MipLevels = 1,
        .ArraySize = 1,
        .Format = .R8G8B8A8_UNORM,
        .SampleDesc = .{
            .Count = 1,
            .Quality = 0,
        },
        .Usage = .STAGING,
        .BindFlags = .{},
        .CPUAccessFlags = .{ .READ = 1, .WRITE = 1 },
        .MiscFlags = .{},
    };
}
