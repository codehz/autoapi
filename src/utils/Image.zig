const std = @import("std");
const COM = @import("./COM.zig");
const win32 = @import("win32");
const check = @import("./check.zig");
const memory = @import("./memory.zig");
const Stream = @import("./Stream.zig");
const com = win32.system.com;
const imaging = win32.graphics.imaging;
const zig = win32.zig;
const HRESULT = @import("./HRESULT.zig");

data: []align(4) u8,
width: i32,
height: i32,

allocated: bool = false,

pub fn init(self: *@This(), allocator: std.mem.Allocator, width: i32, height: i32) void {
    self.width = width;
    self.height = height;
    self.data = allocator.allocWithOptions(
        u8,
        @intCast(width * height * 4),
        .@"4",
        null,
    ) catch @panic("failed to allocate data");
}

pub fn resize(self: *@This(), allocator: std.mem.Allocator, width: i32, height: i32) void {
    self.width = width;
    self.height = height;
    self.data = allocator.realloc(self.data, @intCast(width * height * 4)) catch @panic("failed to reallocate data");
}

pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
    allocator.free(self.data);
    allocator.destroy(self);
}

const Image = @This();

fn clone(self: *Image) callconv(.c) *Image {
    const result = std.heap.raw_c_allocator.create(Image) catch @panic("failed to clone");
    const data = std.heap.raw_c_allocator.allocWithOptions(
        u8,
        self.data.len,
        .@"4",
        null,
    ) catch @panic("failed to dupe data");
    @memcpy(data, self.data);
    result.* = .{
        .allocated = true,
        .data = data,
        .width = self.width,
        .height = self.height,
    };
    return result;
}

fn free_clone(self: *Image) callconv(.c) void {
    if (self.allocated) {
        self.deinit(std.heap.raw_c_allocator);
    }
}

fn pixel_get(self: *Image, x: i32, y: i32) callconv(.c) u32 {
    if (x < 0 or x >= self.width or y < 0 or y >= self.height) return 0;
    const data: []align(1) u32 = @ptrCast(self.data);
    return data[@as(usize, @intCast(y)) * @as(usize, @intCast(self.width)) + @as(usize, @intCast(x))] & 0xFFFFFF;
}

const SaveFormat = enum { bmp, png, ico, jpeg, tiff, gif, wmp, dds, adng, heif, webp, raw };
const SaveFormatMap = std.EnumMap(SaveFormat, *const zig.Guid).init(.{
    .bmp = &imaging.GUID_ContainerFormatBmp,
    .png = &imaging.GUID_ContainerFormatPng,
    .ico = &imaging.GUID_ContainerFormatIco,
    .jpeg = &imaging.GUID_ContainerFormatJpeg,
    .tiff = &imaging.GUID_ContainerFormatTiff,
    .gif = &imaging.GUID_ContainerFormatGif,
    .wmp = &imaging.GUID_ContainerFormatWmp,
    .dds = &imaging.GUID_ContainerFormatDds,
    .adng = &imaging.GUID_ContainerFormatAdng,
    .heif = &imaging.GUID_ContainerFormatHeif,
    .webp = &imaging.GUID_ContainerFormatWebp,
    .raw = &imaging.GUID_ContainerFormatRaw,
});

fn save(self: *Image, path: [*:0]const u8, format: [*:0]const u8) callconv(.c) i32 {
    const parsed_format = std.meta.stringToEnum(SaveFormat, std.mem.span(format)) orelse @panic("invalid format");
    const format_guid = SaveFormatMap.getAssertContains(parsed_format);

    var sfa = memory.fallbackAllocator();
    const allocator = sfa.get();

    const path_w = memory.toWtf16Z(allocator, path);
    defer allocator.free(path_w);

    const stream = Stream.createStreamOnFile(
        path_w.ptr,
        .{ .CREATE = 1, .WRITE = 1 },
    ) catch return HRESULT.last();
    defer stream.deinit();

    const bitmap = WIC.createBitmapFromMemory(
        @intCast(self.width),
        @intCast(self.height),
        @intCast(self.width * 4),
        @intCast(self.width * self.height * 4),
        @ptrCast(self.data.ptr),
    );
    defer _ = bitmap.IUnknown.Release();

    const encoder = WIC.Encoder.create(format_guid);
    defer encoder.deinit();

    encoder.init(stream, .itmapEncoderNoCache);

    const frame = encoder.newFrame();
    defer frame.deinit();

    frame.init();
    frame.write(&bitmap.IWICBitmapSource);
    frame.commit();
    encoder.commit();

    return 0;
}

fn load_internal(path: [*:0]const u8) !*@This() {
    var sfa = memory.fallbackAllocator();
    const allocator = sfa.get();

    const path_w = memory.toWtf16Z(allocator, path);
    defer allocator.free(path_w);

    const stream = try Stream.createStreamOnFile(path_w.ptr, .{});
    defer stream.deinit();

    const decoder = try WIC.Decoder.create(stream);
    defer decoder.deinit();

    const frame = decoder.getFrame(0);
    defer frame.deinit();

    const converter = try WIC.FormatConverter.create(&frame.inner.?.IWICBitmapSource);

    const width, const height = frame.getSize();

    const buffer: []align(4) u8 = std.heap.raw_c_allocator.allocWithOptions(
        u8,
        @intCast(width * height * 4),
        .@"4",
        null,
    ) catch @panic("failed to alloc");
    errdefer std.heap.raw_c_allocator.free(buffer);

    converter.copy(width * 4, buffer);

    const result = std.heap.raw_c_allocator.create(@This()) catch @panic("failed to create Image");
    result.* = .{
        .data = buffer,
        .width = @intCast(width),
        .height = @intCast(height),
        .allocated = true,
    };
    return result;
}

fn load(path: [*:0]const u8, result: *?*@This()) callconv(.c) i32 {
    const result_ptr = load_internal(path) catch return HRESULT.last();
    result.* = result_ptr;
    return 0;
}

comptime {
    @export(&clone, .{ .name = "image_clone" });
    @export(&free_clone, .{ .name = "image_free" });
    @export(&struct {
        const SearchOptions = struct {
            x1: i32,
            y1: i32,
            x2: i32,
            y2: i32,
            color: u32,
            variation: u8,
        };
        const SearchResult = struct {
            color: u32,
            x: i32,
            y: i32,
        };
        const vector_size = std.simd.suggestVectorLength(u32) orelse 8;

        const VecU32 = @Vector(vector_size, u32);
        const VecBool = @Vector(vector_size, bool);
        fn linear_search_rgb(haystack: []u32, color: u32) ?usize {
            const mask = 0xFFFFFF;
            const color_masked: u32 = color & mask;
            const color_vec: VecU32 = @splat(color_masked);
            const mask_vec: VecU32 = @splat(mask);

            var i: usize = 0;
            while (i + vector_size <= haystack.len) : (i += vector_size) {
                const slice = haystack[i..][0..vector_size];
                const data_vec: VecU32 = slice.*;

                const masked_vec = data_vec & mask_vec;
                const comparison = masked_vec == color_vec;

                if (@reduce(.Or, comparison)) {
                    for (@as([vector_size]bool, comparison), 0..) |val, j| {
                        if (val) {
                            return i + j;
                        }
                    }
                }
            }

            while (i < haystack.len) : (i += 1) {
                if ((haystack[i] & mask) == color_masked) {
                    return i;
                }
            }

            return null;
        }
        fn linear_search_rgb_range(haystack: []u32, color1: u32, color2: u32) ?usize {
            const byte_mask_vec: VecU32 = @splat(0xFF);

            const low_bytes = [_]u8{
                @as(u8, @truncate(color1)),
                @as(u8, @truncate(color1 >> 8)),
                @as(u8, @truncate(color1 >> 16)),
            };
            const high_bytes = [_]u8{
                @as(u8, @truncate(color2)),
                @as(u8, @truncate(color2 >> 8)),
                @as(u8, @truncate(color2 >> 16)),
            };

            const low_vec = [_]VecU32{
                @splat(@as(u32, low_bytes[0])),
                @splat(@as(u32, low_bytes[1])),
                @splat(@as(u32, low_bytes[2])),
            };
            const high_vec = [_]VecU32{
                @splat(@as(u32, high_bytes[0])),
                @splat(@as(u32, high_bytes[1])),
                @splat(@as(u32, high_bytes[2])),
            };

            var i: usize = 0;
            while (i + vector_size <= haystack.len) : (i += vector_size) {
                const slice = haystack[i..][0..vector_size];
                const input_vec: VecU32 = slice.*;

                var all_in_range: VecBool = @splat(true);
                inline for (0..3) |byte_idx| {
                    const shift = 8 * byte_idx;
                    const byte_vec = @as(VecU32, input_vec >> @splat(@as(u32, shift))) & byte_mask_vec;
                    all_in_range = all_in_range &
                        (byte_vec >= low_vec[byte_idx]) &
                        (byte_vec <= high_vec[byte_idx]);
                }

                if (@reduce(.Or, all_in_range)) {
                    for (@as([vector_size]bool, all_in_range), 0..) |in_range, j| {
                        if (in_range) {
                            return i + j;
                        }
                    }
                }
            }

            while (i < haystack.len) : (i += 1) {
                const val = haystack[i];
                var in_range = true;
                inline for (0..3) |byte_idx| {
                    const byte = @as(u8, @truncate(val >> (8 * byte_idx)));
                    in_range = in_range and
                        (byte >= low_bytes[byte_idx]) and
                        (byte <= high_bytes[byte_idx]);
                }
                if (in_range) {
                    return i;
                }
            }

            return null;
        }
        fn getColorBounds(color: u32, delta: u8) struct { lower: u32, upper: u32 } {
            // Extract RGB components
            const r = @as(u8, @truncate((color >> 16) & 0xFF));
            const g = @as(u8, @truncate((color >> 8) & 0xFF));
            const b = @as(u8, @truncate(color & 0xFF));

            // Calculate bounds for each component with clamping
            const r_lower = if (r < delta) 0 else r - delta;
            const r_upper = if (r > 255 - delta) 255 else r + delta;
            const g_lower = if (g < delta) 0 else g - delta;
            const g_upper = if (g > 255 - delta) 255 else g + delta;
            const b_lower = if (b < delta) 0 else b - delta;
            const b_upper = if (b > 255 - delta) 255 else b + delta;

            // Combine bounds into u32 colors
            const lower = (@as(u32, r_lower) << 16) | (@as(u32, g_lower) << 8) | @as(u32, b_lower);
            const upper = (@as(u32, r_upper) << 16) | (@as(u32, g_upper) << 8) | @as(u32, b_upper);

            return .{ .lower = lower, .upper = upper };
        }
        pub fn search_pixel(self: *Image, options: *SearchOptions, result: *SearchResult) callconv(.c) bool {
            const min_x: usize = @intCast(@max(@min(options.x1, options.x2), 0));
            const max_x: usize = @intCast(@min(@max(options.x1, options.x2) + 1, self.width));
            const min_y: usize = @intCast(@max(@min(options.y1, options.y2), 0));
            const max_y: usize = @intCast(@min(@max(options.y1, options.y2) + 1, self.height));

            const data: []u32 = @ptrCast(self.data);

            if (options.variation == 0) {
                for (min_y..max_y) |y| {
                    const found = linear_search_rgb(
                        data[y * @as(usize, @intCast(self.width)) + min_x ..][0 .. max_x - min_x],
                        options.color,
                    ) orelse continue;
                    result.x = @intCast(found + min_x);
                    result.y = @intCast(y);
                    result.color = data[y * @as(usize, @intCast(self.width)) + found + min_x] & 0xFFFFFF;
                    return true;
                }
            } else {
                const range = getColorBounds(options.color, options.variation);
                for (min_y..max_y) |y| {
                    const found = linear_search_rgb_range(
                        data[y * @as(usize, @intCast(self.width)) + min_x ..][0 .. max_x - min_x],
                        range.lower,
                        range.upper,
                    ) orelse continue;
                    result.x = @intCast(found + min_x);
                    result.y = @intCast(y);
                    result.color = data[y * @as(usize, @intCast(self.width)) + found + min_x] & 0xFFFFFF;
                    return true;
                }
            }
            return false;
        }
    }.search_pixel, .{ .name = "image_search_pixel" });
    @export(&pixel_get, .{ .name = "image_pixel_get" });
    @export(&save, .{ .name = "image_save" });
    @export(&load, .{ .name = "image_load" });
}

const WIC = struct {
    const factory = COM.LazyCreateInstance(
        &imaging.CLSID_WICImagingFactory,
        imaging.IID_IWICImagingFactory,
        imaging.IWICImagingFactory,
    );

    const PIXEL_FORMAT: ?*zig.Guid = @constCast(&imaging.GUID_WICPixelFormat32bppBGRA);

    pub fn createBitmapFromMemory(
        uiWidth: u32,
        uiHeight: u32,
        cbStride: u32,
        cbBufferSize: u32,
        pbBuffer: [*:0]u8,
    ) *imaging.IWICBitmap {
        var bitmap: ?*imaging.IWICBitmap = null;
        const hr = factory().CreateBitmapFromMemory(
            uiWidth,
            uiHeight,
            PIXEL_FORMAT,
            cbStride,
            cbBufferSize,
            pbBuffer,
            &bitmap,
        );
        HRESULT.check("CreateBitmapFromMemory", hr);
        return bitmap.?;
    }

    pub const FormatConverter = struct {
        inner: ?*imaging.IWICFormatConverter,

        pub fn create(source: *imaging.IWICBitmapSource) !@This() {
            var converter: @This() = undefined;

            var hr = factory().CreateFormatConverter(&converter.inner);
            HRESULT.check("IWICImagingFactory.CreateFormatConverter", hr);

            hr = converter.inner.?.Initialize(
                source,
                PIXEL_FORMAT,
                .itmapDitherTypeNone,
                null,
                0.0,
                .itmapPaletteTypeMedianCut,
            );
            HRESULT.report(hr) catch return error.IWICFormatConverter_Initialize;

            return converter;
        }

        pub fn copy(self: @This(), stride: u32, buffer: []u8) void {
            const hr = self.inner.?.IWICBitmapSource.CopyPixels(
                null,
                stride,
                @intCast(buffer.len),
                @ptrCast(buffer.ptr),
            );
            HRESULT.check("IWICFormatConverter.CopyPixels", hr);
        }

        pub fn deinit(self: @This()) void {
            _ = self.inner.?.IUnknown.Release();
        }
    };

    pub const Decoder = struct {
        inner: ?*imaging.IWICBitmapDecoder,

        pub fn create(stream: Stream) !@This() {
            var decoder: @This() = undefined;
            const hr = factory().CreateDecoderFromStream(
                stream.inner.?,
                null,
                .DecodeMetadataCacheOnDemand,
                &decoder.inner,
            );
            HRESULT.report(hr) catch return error.IWICImagingFactory_CreateDecoderFromStream;
            return decoder;
        }

        pub fn deinit(self: @This()) void {
            _ = self.inner.?.IUnknown.Release();
        }

        pub fn getFrame(self: @This(), index: u32) Frame {
            var frame: Frame = undefined;
            const hr = self.inner.?.GetFrame(index, &frame.inner);
            HRESULT.check("IWICBitmapDecoder.GetFrame", hr);
            return frame;
        }

        pub const Frame = struct {
            inner: ?*imaging.IWICBitmapFrameDecode,

            pub fn getSize(self: @This()) struct { u32, u32 } {
                var size: struct { u32, u32 } = undefined;

                const hr = self.inner.?.IWICBitmapSource.GetSize(&size.@"0", &size.@"1");
                HRESULT.check("IWICBitmapFrameDecode.GetSize", hr);

                return size;
            }

            pub fn deinit(self: @This()) void {
                _ = self.inner.?.IUnknown.Release();
            }
        };
    };

    pub const Encoder = struct {
        inner: ?*imaging.IWICBitmapEncoder,

        pub fn create(format: ?*const zig.Guid) Encoder {
            var encoder: @This() = undefined;
            const hr = factory().CreateEncoder(format, null, &encoder.inner);
            HRESULT.check("IWICImagingFactory.CreateEncoder", hr);
            return encoder;
        }

        pub fn init(self: @This(), stream: Stream, cacheOptions: imaging.WICBitmapEncoderCacheOption) void {
            const hr = self.inner.?.Initialize(stream.inner.?, cacheOptions);
            HRESULT.check("IWICBitmapEncoder.Initialize", hr);
        }

        pub fn deinit(self: @This()) void {
            _ = self.inner.?.IUnknown.Release();
        }

        pub const Frame = struct {
            inner: ?*imaging.IWICBitmapFrameEncode,

            pub fn init(self: @This()) void {
                const hr = self.inner.?.Initialize(null);
                HRESULT.check("IWICBitmapFrameEncode.Initialize", hr);
            }

            pub fn deinit(self: @This()) void {
                _ = self.inner.?.IUnknown.Release();
            }

            pub fn write(self: @This(), bitmap: *imaging.IWICBitmapSource) void {
                const hr = self.inner.?.WriteSource(bitmap, null);
                HRESULT.check("IWICBitmapFrameEncode.WriteSource", hr);
            }

            pub fn commit(self: @This()) void {
                const hr = self.inner.?.Commit();
                HRESULT.check("IWICBitmapFrameEncode.Commit", hr);
            }
        };

        pub fn newFrame(self: @This()) Frame {
            var frame: Frame = undefined;
            const hr = self.inner.?.CreateNewFrame(&frame.inner, null);
            HRESULT.check("IWICBitmapEncoder.CreateNewFrame", hr);
            return frame;
        }

        pub fn commit(self: @This()) void {
            const hr = self.inner.?.Commit();
            HRESULT.check("IWICBitmapEncoder.Commit", hr);
        }
    };
};
