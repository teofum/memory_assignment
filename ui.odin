package main

import "base:runtime"
import "core:mem"
import "core:strings"
import rl "vendor:raylib"

button_padding :: vec2{5, 5}
full_screen: rl.Rectangle : {0, 0, window_width, window_height}

Alignment :: enum {
	Start  = 0,
	Center = 1,
	End    = 2,
}

// UI allocator
@(private)
ui_arena_data: [1024 * 1024]u8

@(private)
ui_arena: mem.Arena

ui_alloc: runtime.Allocator

UI_Frame :: struct {
	bounds: rl.Rectangle,
	parent: ^UI_Frame,
}

@(private)
ui_current_frame: ^UI_Frame = nil

// Initialize internal memory management for UI system
ui_init :: proc() {
	mem.arena_init(&ui_arena, ui_arena_data[:])
	ui_alloc = mem.arena_allocator(&ui_arena)
}

ui_begin :: proc() {
	// Doesn't need to do anything for now, just here so we have a clean begin/end
}

ui_end :: proc() {
	mem.free_all(ui_alloc)
}

ui_begin_frame :: proc(
	rect: rl.Rectangle,
	bg_color: rl.Color = rl.BLANK,
	border_color: rl.Color = rl.BLANK,
	padding: vec2 = {0, 0},
	line_thick: f32 = 1,
) {
	if bg_color.a > 0 do rl.DrawRectangleRec(rect, bg_color)
	if border_color.a > 0 do rl.DrawRectangleLinesEx(rect, line_thick, border_color)

	new_frame := new(UI_Frame, ui_alloc)

	new_frame.bounds = {
		x      = rect.x + padding.x,
		y      = rect.y + padding.y,
		width  = rect.width - padding.x * 2,
		height = rect.height - padding.y * 2,
	}
	new_frame.parent = ui_current_frame
	ui_current_frame = new_frame
}

ui_end_frame :: proc() {
	assert(ui_current_frame != nil, "ui_end_frame called without a corresponding begin!")
	ui_current_frame = ui_current_frame.parent
}

ui_align_ex_r :: proc(
	rect: rl.Rectangle,
	align_x, align_y, origin_x, origin_y: Alignment,
) -> rl.Rectangle {
	assert(ui_current_frame != nil, "ui_align must be used within a frame!")

	fb := ui_current_frame.bounds
	x, y, w, h := rect.x, rect.y, rect.width, rect.height
	if align_x == .End do x = -x
	if align_y == .End do y = -y

	x += fb.x + fb.width * f32(align_x) / 2 - w * f32(origin_x) / 2
	y += fb.y + fb.height * f32(align_y) / 2 - h * f32(origin_y) / 2

	return {x, y, w, h}
}

ui_align_ex_v :: proc(
	position, size: vec2,
	align_x, align_y, origin_x, origin_y: Alignment,
) -> rl.Rectangle {
	x, y, w, h := position.x, position.y, size.x, size.y
	return ui_align_ex_r({x, y, w, h}, align_x, align_y, origin_x, origin_y)
}

ui_align_ex_s :: proc(
	x, y, w, h: f32,
	align_x, align_y, origin_x, origin_y: Alignment,
) -> rl.Rectangle {
	return ui_align_ex_r({x, y, w, h}, align_x, align_y, origin_x, origin_y)
}

ui_align_ex :: proc {
	ui_align_ex_r,
	ui_align_ex_v,
	ui_align_ex_s,
}

ui_align_r :: proc(rect: rl.Rectangle, align_x, align_y: Alignment) -> rl.Rectangle {
	return ui_align_ex_r(rect, align_x, align_y, align_x, align_y)
}

ui_align_v :: proc(position, size: vec2, align_x, align_y: Alignment) -> rl.Rectangle {
	return ui_align_ex_v(position, size, align_x, align_y, align_x, align_y)
}

ui_align_s :: proc(x, y, w, h: f32, align_x, align_y: Alignment) -> rl.Rectangle {
	return ui_align_ex_s(x, y, w, h, align_x, align_y, align_x, align_y)
}

ui_align :: proc {
	ui_align_r,
	ui_align_v,
	ui_align_s,
}

ui_text :: proc(
	text: string,
	position: vec2,
	color := rl.BLACK,
	outline_color := rl.BLANK,
	outline_width: u32 = 0,
	font_size: i32 = 20,
	align_x: Alignment = .Start,
	align_y: Alignment = .Start,
) {
	text_c := strings.clone_to_cstring(text, ui_alloc)
	text_width := rl.MeasureText(text_c, font_size)

	text_rect := ui_align(position, {f32(text_width), f32(font_size)}, align_x, align_y)

	x, y := i32(text_rect.x), i32(text_rect.y)
	if outline_color.a > 0 && outline_width > 0 {
		o := i32(outline_width)
		rl.DrawText(text_c, x, y - o, font_size, outline_color)
		rl.DrawText(text_c, x, y + o, font_size, outline_color)
		rl.DrawText(text_c, x - o, y, font_size, outline_color)
		rl.DrawText(text_c, x - o, y - o, font_size, outline_color)
		rl.DrawText(text_c, x - o, y + o, font_size, outline_color)
		rl.DrawText(text_c, x + o, y, font_size, outline_color)
		rl.DrawText(text_c, x + o, y - o, font_size, outline_color)
		rl.DrawText(text_c, x + o, y + o, font_size, outline_color)
	}

	rl.DrawText(text_c, x, y, font_size, color)
}

ui_button :: proc(
	text: string,
	position: vec2,
	size: vec2 = {0, 0},
	font_size: i32 = 20,
	align_x: Alignment = .Start,
	align_y: Alignment = .Start,
) -> bool {
	text_c := strings.clone_to_cstring(text, ui_alloc)
	text_width := rl.MeasureText(text_c, font_size)

	w := f32(text_width) + button_padding.x * 2 if size.x == 0 else size.x
	h := f32(font_size) + button_padding.y * 2 if size.y == 0 else size.y

	screen_space_rect := ui_align(position, {w, h}, align_x, align_y)

	hovered := rl.CheckCollisionPointRec(rl.GetMousePosition(), screen_space_rect)
	active := hovered && rl.IsMouseButtonDown(.LEFT)
	clicked := hovered && rl.IsMouseButtonReleased(.LEFT)

	bg_color :=
		rl.Color{192, 192, 255, 255} if active else ({223, 223, 255, 255} if hovered else rl.WHITE)

	ui_begin_frame(screen_space_rect, bg_color, rl.BLACK, button_padding); {
		ui_text(text, {0, 0}, font_size = font_size, align_x = .Center, align_y = .Center)
	}; ui_end_frame()

	return clicked
}
