local ffi = require("ffi")

ffi.cdef [[
typedef unsigned char byte;
struct U32Slice {
    unsigned int *ptr;
    int length;
};

int msgbox(char const *title, char const *text);

struct Image {
    struct U32Slice;
    int width;
    int height;
    bool allocated;
};
struct Image *screenshot();
struct Image *image_clone(struct Image *self);
void image_free(struct Image *self);
struct ImageSearchOptions {
    int x1;
    int y1;
    int x2;
    int y2;
    unsigned int color;
    unsigned char variation;
};
struct ImageSearchResult {
    unsigned int color;
    int x;
    int y;
};
bool image_search_pixel(struct Image *self, struct ImageSearchOptions *options, struct ImageSearchResult *result);
unsigned int image_pixel_get(struct Image *self, int x, int y);
void image_save(struct Image *self, char const *path, char const *format);
int image_load(char const *path, struct Image **result);

int hotkey_new(char const *hotkey, void (*callback)());
int hotkey_delete(int id);

void loop();
void quit(int code);

char const *format_error(int code);

unsigned int timer_new(unsigned long interval, bool repeat, void (*callback)());
void timer_remove(unsigned int id);

unsigned int input_text(char const *text);
unsigned int input_send(struct Input *inputs, unsigned int count);

struct Input {
    int32_t type;
    union {
        struct MouseInput {
            int32_t dx, dy;
            int32_t data;
            int32_t flags;
            uint32_t time;
            uint64_t extraInfo;
        } mouse;
        struct KeyboardInput {
            uint16_t vk;
            uint16_t scan;
            uint32_t flags;
            uint32_t time;
            uint64_t extraInfo;
        } keyboard;
        struct HardwareInput {
            uint32_t msg;
            uint32_t param;
        } hardware;
    };
};
]]

local function get_script_directory()
    local script_path = arg[0] or debug.getinfo(1, "S").source:sub(2)
    return script_path:match("^(.*[/\\])") or "."
end

local function load_dll(dll_name)
    local dir = get_script_directory()
    local dll_path = dir .. "/" .. dll_name
    local ok, lib = pcall(ffi.load, dll_path)
    if ok then
        return lib
    end
    return ffi.load(dll_name)
end

local api = load_dll("autoapi.dll")

do
    ---@alias ImageSearchOptions { x1: integer, y1: integer, x2: integer, y2: integer, color: integer, variation: integer }
    ---@alias ImageSearchResult { x: integer, y: integer, color: integer }

    ---@class (exact) Slice: userdata
    ---@field ptr integer[]
    ---@field length integer

    ---@class (exact) Image: Slice
    ---@field width integer
    ---@field height integer
    ---@field search_pixel fun(self: Image, opts: ImageSearchOptions): ImageSearchResult?
    ---@field get fun(self: Image, x: integer, y: integer): integer
    ---@field save fun(self: Image, path: string, format: string)
    ---@field clone fun(self: Image): Image

    ---@type ImageSearchResult
    local search_result = ffi.new("struct ImageSearchResult")

    ffi.metatype("struct Image", {
        __index = {
            search_pixel = function(self, opts)
                if api.image_search_pixel(self, opts, search_result) then
                    return {
                        x = search_result.x,
                        y = search_result.y,
                        color = search_result.color
                    }
                else
                    return nil
                end
            end,
            get = function(self, x, y)
                return api.image_pixel_get(self, x, y)
            end,
            save = function(self, path, format)
                api.image_save(self, path, format)
            end,
            clone = function(self)
                return ffi.gc(api.image_clone(self), api.image_free)
            end,
        },
    })
end

local VK = {
    ["0"] = 48,
    ["1"] = 49,
    ["2"] = 50,
    ["3"] = 51,
    ["4"] = 52,
    ["5"] = 53,
    ["6"] = 54,
    ["7"] = 55,
    ["8"] = 56,
    ["9"] = 57,
    A = 65,
    B = 66,
    C = 67,
    D = 68,
    E = 69,
    F = 70,
    G = 71,
    H = 72,
    I = 73,
    J = 74,
    K = 75,
    L = 76,
    M = 77,
    N = 78,
    O = 79,
    P = 80,
    Q = 81,
    R = 82,
    S = 83,
    T = 84,
    U = 85,
    V = 86,
    W = 87,
    X = 88,
    Y = 89,
    Z = 90,
    LBUTTON = 1,
    RBUTTON = 2,
    CANCEL = 3,
    MBUTTON = 4,
    XBUTTON1 = 5,
    XBUTTON2 = 6,
    BACK = 8,
    TAB = 9,
    CLEAR = 12,
    RETURN = 13,
    SHIFT = 16,
    CONTROL = 17,
    MENU = 18,
    PAUSE = 19,
    CAPITAL = 20,
    KANA = 21,
    IME_ON = 22,
    JUNJA = 23,
    FINAL = 24,
    HANJA = 25,
    IME_OFF = 26,
    ESCAPE = 27,
    CONVERT = 28,
    NONCONVERT = 29,
    ACCEPT = 30,
    MODECHANGE = 31,
    SPACE = 32,
    PRIOR = 33,
    NEXT = 34,
    END = 35,
    HOME = 36,
    LEFT = 37,
    UP = 38,
    RIGHT = 39,
    DOWN = 40,
    SELECT = 41,
    PRINT = 42,
    EXECUTE = 43,
    SNAPSHOT = 44,
    INSERT = 45,
    DELETE = 46,
    HELP = 47,
    LWIN = 91,
    RWIN = 92,
    APPS = 93,
    SLEEP = 95,
    NUMPAD0 = 96,
    NUMPAD1 = 97,
    NUMPAD2 = 98,
    NUMPAD3 = 99,
    NUMPAD4 = 100,
    NUMPAD5 = 101,
    NUMPAD6 = 102,
    NUMPAD7 = 103,
    NUMPAD8 = 104,
    NUMPAD9 = 105,
    MULTIPLY = 106,
    ADD = 107,
    SEPARATOR = 108,
    SUBTRACT = 109,
    DECIMAL = 110,
    DIVIDE = 111,
    F1 = 112,
    F2 = 113,
    F3 = 114,
    F4 = 115,
    F5 = 116,
    F6 = 117,
    F7 = 118,
    F8 = 119,
    F9 = 120,
    F10 = 121,
    F11 = 122,
    F12 = 123,
    F13 = 124,
    F14 = 125,
    F15 = 126,
    F16 = 127,
    F17 = 128,
    F18 = 129,
    F19 = 130,
    F20 = 131,
    F21 = 132,
    F22 = 133,
    F23 = 134,
    F24 = 135,
    NAVIGATION_VIEW = 136,
    NAVIGATION_MENU = 137,
    NAVIGATION_UP = 138,
    NAVIGATION_DOWN = 139,
    NAVIGATION_LEFT = 140,
    NAVIGATION_RIGHT = 141,
    NAVIGATION_ACCEPT = 142,
    NAVIGATION_CANCEL = 143,
    NUMLOCK = 144,
    SCROLL = 145,
    OEM_NEC_EQUAL = 146,
    OEM_FJ_MASSHOU = 147,
    OEM_FJ_TOUROKU = 148,
    OEM_FJ_LOYA = 149,
    OEM_FJ_ROYA = 150,
    LSHIFT = 160,
    RSHIFT = 161,
    LCONTROL = 162,
    RCONTROL = 163,
    LMENU = 164,
    RMENU = 165,
    BROWSER_BACK = 166,
    BROWSER_FORWARD = 167,
    BROWSER_REFRESH = 168,
    BROWSER_STOP = 169,
    BROWSER_SEARCH = 170,
    BROWSER_FAVORITES = 171,
    BROWSER_HOME = 172,
    VOLUME_MUTE = 173,
    VOLUME_DOWN = 174,
    VOLUME_UP = 175,
    MEDIA_NEXT_TRACK = 176,
    MEDIA_PREV_TRACK = 177,
    MEDIA_STOP = 178,
    MEDIA_PLAY_PAUSE = 179,
    LAUNCH_MAIL = 180,
    LAUNCH_MEDIA_SELECT = 181,
    LAUNCH_APP1 = 182,
    LAUNCH_APP2 = 183,
    OEM_1 = 186,
    OEM_PLUS = 187,
    OEM_COMMA = 188,
    OEM_MINUS = 189,
    OEM_PERIOD = 190,
    OEM_2 = 191,
    OEM_3 = 192,
    GAMEPAD_A = 195,
    GAMEPAD_B = 196,
    GAMEPAD_X = 197,
    GAMEPAD_Y = 198,
    GAMEPAD_RIGHT_SHOULDER = 199,
    GAMEPAD_LEFT_SHOULDER = 200,
    GAMEPAD_LEFT_TRIGGER = 201,
    GAMEPAD_RIGHT_TRIGGER = 202,
    GAMEPAD_DPAD_UP = 203,
    GAMEPAD_DPAD_DOWN = 204,
    GAMEPAD_DPAD_LEFT = 205,
    GAMEPAD_DPAD_RIGHT = 206,
    GAMEPAD_MENU = 207,
    GAMEPAD_VIEW = 208,
    GAMEPAD_LEFT_THUMBSTICK_BUTTON = 209,
    GAMEPAD_RIGHT_THUMBSTICK_BUTTON = 210,
    GAMEPAD_LEFT_THUMBSTICK_UP = 211,
    GAMEPAD_LEFT_THUMBSTICK_DOWN = 212,
    GAMEPAD_LEFT_THUMBSTICK_RIGHT = 213,
    GAMEPAD_LEFT_THUMBSTICK_LEFT = 214,
    GAMEPAD_RIGHT_THUMBSTICK_UP = 215,
    GAMEPAD_RIGHT_THUMBSTICK_DOWN = 216,
    GAMEPAD_RIGHT_THUMBSTICK_RIGHT = 217,
    GAMEPAD_RIGHT_THUMBSTICK_LEFT = 218,
    OEM_4 = 219,
    OEM_5 = 220,
    OEM_6 = 221,
    OEM_7 = 222,
    OEM_8 = 223,
    OEM_AX = 225,
    OEM_102 = 226,
    ICO_HELP = 227,
    ICO_00 = 228,
    PROCESSKEY = 229,
    ICO_CLEAR = 230,
    PACKET = 231,
    OEM_RESET = 233,
    OEM_JUMP = 234,
    OEM_PA1 = 235,
    OEM_PA2 = 236,
    OEM_PA3 = 237,
    OEM_WSCTRL = 238,
    OEM_CUSEL = 239,
    OEM_ATTN = 240,
    OEM_FINISH = 241,
    OEM_COPY = 242,
    OEM_AUTO = 243,
    OEM_ENLW = 244,
    OEM_BACKTAB = 245,
    ATTN = 246,
    CRSEL = 247,
    EXSEL = 248,
    EREOF = 249,
    PLAY = 250,
    ZOOM = 251,
    NONAME = 252,
    PA1 = 253,
    OEM_CLEAR = 254,
}

local M = {
    api = api
}

---@generic T, R
---@param func fun(...:`T`): R
---@param ... T
---@return boolean, R
function M.try(func, ...)
    return xpcall(func, print, ...)
end

---@generic T
---@param func async fun(...:`T`)
---@param ... T
---@return thread
function M.async(func, ...)
    local co = coroutine.create(func)
    local function run_coroutine(...)
        local ok, future = coroutine.resume(co, ...)
        if not ok then
            error(future)
        end
        if coroutine.status(co) == "suspended" then
            if type(future) == "function" then
                future(run_coroutine)
            else
                error("invalid yield", future)
            end
        end
    end
    run_coroutine(...)
    return co
end

---@generic T
---@param func async fun(...:`T`)
---@return fun(...:T): thread
function M.AsyncFunction(func)
    return function(...)
        return M.async(func, ...)
    end
end

---@generic T
---@type async fun(awaitable: fun(cb: fun(...:`T`))):T
M.await = coroutine.yield

---@generic T
---@param interval integer
---@param callback fun(): `T`
---@return fun(cb: fun(value: T))
---@nodiscard
function M.interval(interval, callback)
    return function(cb)
        local timer_id
        local c_callback

        ---@type ffi.cb*
        c_callback = ffi.cast("void(*)()", function()
            local ret = callback()
            if ret ~= nil then
                api.timer_remove(timer_id)
                c_callback:free()
                cb(ret)
            end
        end)
        timer_id = api.timer_new(interval, true, c_callback)
    end
end

---@param time integer
---@return fun(cb: fun())
---@nodiscard
function M.sleep(time)
    return function(cb)
        local c_callback
        ---@type ffi.cb*
        c_callback = ffi.cast("void(*)()", function()
            c_callback:free()
            cb()
        end)
        api.timer_new(time, false, c_callback)
    end
end

---@type table<string, [integer, ffi.cb*]>
local hotkeys = {}

---@type table<string, fun()>|fun(regs: table<string, fun()>)
M.hotkey = setmetatable({}, {
    ---@param self table<string, fun()>
    ---@param regs table<string, fun()>
    __call = function(self, regs)
        for k, v in pairs(regs) do
            self[k] = v
        end
    end,
    ---@param k string
    ---@param v fun()?
    __newindex = function(_, k, v)
        local orig = hotkeys[k]
        if v == nil then
            if orig ~= nil then
                api.hotkey_delete(orig[1])
                orig[2]:free()
                hotkeys[k] = nil
            end
        else
            if orig ~= nil then
                orig[2]:set(v)
            else
                local callback_c = ffi.cast("void(*)()", v)
                local id = api.hotkey_new(k, callback_c)
                if id < 0 then
                    ---@cast callback_c ffi.cb*
                    callback_c:free()
                    error("failed to create hotkey")
                end
                ---@cast callback_c ffi.cb*
                hotkeys[k] = { id, callback_c }
            end
        end
    end
})

---@return Image
function M.screenshot()
    return api.screenshot()
end

---@return Image
function M.load_image(path)
    local result = ffi.new("struct Image *[1]");
    local code = api.image_load(path, result);
    if code < 0 then
        error(string.format("image_load failed: %s", ffi.string(api.format_error(code))))
    end
    return ffi.gc(result[0], api.image_free)
end

---@param text string
function M.input_text(text)
    api.input_text(text)
end

---@param key string
---@nodiscard
---@return integer
local function parseVK(key)
    local id = string.upper(key)
    local vk = VK[id]
    if vk == nil then
        error("invalid key: " .. key)
    end
    return vk
end

---@alias KeyboardInput { keydown: string } | { keyup: string }
---@alias MouseInput { move: [integer, integer] } | { moveabs: [integer, integer] } | "leftdown" | "leftup" | "rightdown" | "rightup" | "middledown" | "middleup" | "x1down" | "x1up" | "x2down" | "x2up" | { wheel: integer } | { hwheel: integer }
---@alias Input KeyboardInput|MouseInput
---@param inputs Input[]
function M.input(inputs)
    local native_inputs = ffi.new("struct Input[?]", #inputs)
    for i, input in ipairs(inputs) do
        local native_input = native_inputs[i - 1]

        if type(input) == "string" then
            if input == "leftdown" then
                native_input.type = 0
                native_input.mouse.flags = 0x0002
            elseif input == "leftup" then
                native_input.type = 0
                native_input.mouse.flags = 0x0004
            elseif input == "rightdown" then
                native_input.type = 0
                native_input.mouse.flags = 0x0008
            elseif input == "rightup" then
                native_input.type = 0
                native_input.mouse.flags = 0x0010
            elseif input == "middledown" then
                native_input.type = 0
                native_input.mouse.flags = 0x0020
            elseif input == "middleup" then
                native_input.type = 0
                native_input.mouse.flags = 0x0040
            elseif input == "x1down" then
                native_input.type = 0
                native_input.mouse.data = 1
                native_input.mouse.flags = 0x0080
            elseif input == "x1up" then
                native_input.type = 0
                native_input.mouse.data = 1
                native_input.mouse.flags = 0x0100
            elseif input == "x2down" then
                native_input.type = 0
                native_input.mouse.data = 2
                native_input.mouse.flags = 0x0080
            elseif input == "x2up" then
                native_input.type = 0
                native_input.mouse.data = 2
                native_input.mouse.flags = 0x0100
            else
                error("invalid input: " .. input)
            end
        elseif type(input) == "table" then
            if input.move then
                native_input.type = 0
                native_input.mouse.dx = input.move[1]
                native_input.mouse.dy = input.move[2]
                native_input.mouse.flags = 0x0001
            elseif input.moveabs then
                native_input.type = 0
                native_input.mouse.dx = input.moveabs[1]
                native_input.mouse.dy = input.moveabs[2]
                native_input.mouse.flags = 0x8001
            elseif input.wheel then
                native_input.type = 0
                native_input.mouse.data = input.wheel
                native_input.mouse.flags = 0x0800
            elseif input.hwheel then
                native_input.type = 0
                native_input.mouse.data = input.hwheel
                native_input.mouse.flags = 0x0080
            elseif input.keydown then
                native_input.type = 1
                native_input.keyboard.vk = parseVK(input.keydown)
                native_input.keyboard.flags = 0
            elseif input.keyup then
                native_input.type = 1
                native_input.keyboard.vk = parseVK(input.keyup)
                native_input.keyboard.flags = 2
            else
                error("invalid input: " .. input)
            end
        end
    end
    api.input_send(native_inputs, #inputs)
end

function M.loop()
    api.loop()
end

---@param code integer
function M.quit(code)
    api.quit(code)
end

return M
