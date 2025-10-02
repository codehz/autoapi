const win32 = @import("win32");

export fn get_key_state(vk: i32) bool {
    return win32.ui.input.keyboard_and_mouse.GetAsyncKeyState(vk) < 0;
}
