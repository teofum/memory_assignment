package main

import "core:fmt"
import la "core:math/linalg"
import "core:mem"
import rl "vendor:raylib"

window_width :: 1200
window_height :: 800

init :: proc() {
	rl.InitWindow(window_width, window_height, "Memory Assignment")
	rl.SetTargetFPS(120)

	ui_init()
}

process_input :: proc(state: ^State) {
	state.input_vector = {0, 0}

	if rl.IsKeyDown(rl.KeyboardKey.W) do state.input_vector.y -= 1
	if rl.IsKeyDown(rl.KeyboardKey.A) do state.input_vector.x -= 1
	if rl.IsKeyDown(rl.KeyboardKey.S) do state.input_vector.y += 1
	if rl.IsKeyDown(rl.KeyboardKey.D) do state.input_vector.x += 1

	if la.length2(state.input_vector) > 0 {
		state.input_vector = la.normalize(state.input_vector)
	}
}

shutdown :: proc() {
	rl.CloseWindow()
}

main :: proc() {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)

	defer {
		if len(track.allocation_map) > 0 {
			fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
			for _, entry in track.allocation_map {
				fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
			}
		}
		mem.tracking_allocator_destroy(&track)
	}

	state, error := open_map("data/map.json")
	if error != nil {
		panic("Error reading map file")
	}

	init()
	defer shutdown()

	for state.state != .Quit && !rl.WindowShouldClose() {
		process_input(&state)
		update(&state)
		draw(&state)
	}
}
