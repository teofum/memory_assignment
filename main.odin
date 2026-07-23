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
	rl.SetExitKey(nil)
}

process_input :: proc(state: ^State) {
	state.input_vector = {0, 0}

	if rl.IsKeyDown(.W) do state.input_vector.y -= 1
	if rl.IsKeyDown(.A) do state.input_vector.x -= 1
	if rl.IsKeyDown(.S) do state.input_vector.y += 1
	if rl.IsKeyDown(.D) do state.input_vector.x += 1

	if la.length2(state.input_vector) > 0 {
		state.input_vector = la.normalize(state.input_vector)
	}

	if rl.IsKeyPressed(.ESCAPE) {
		#partial switch state.state {
		case .Running:
			state.state = .Paused
		case .Paused:
			state.state = .Running
		}
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

	// Use a dynamic arena for state alloc to allow it to expand (not ideal!)
	state_dynamic_arena: mem.Dynamic_Arena
	mem.dynamic_arena_init(&state_dynamic_arena)
	defer mem.dynamic_arena_destroy(&state_dynamic_arena)

	// State allocator, data lives for as long as a level is loaded
	state_alloc := mem.dynamic_arena_allocator(&state_dynamic_arena)

	// Temp allocator uses a small (64k) arena
	temp_arena: mem.Arena
	temp_arena_data := make([]u8, 64 * 1024)
	mem.arena_init(&temp_arena, temp_arena_data)
	defer delete(temp_arena_data)

	// Temp allocator, for data that lives only one frame
	temp_alloc := mem.arena_allocator(&temp_arena)

	state: State
	error: MapError

	init()
	defer shutdown()

	ui_init(temp_alloc)

	for state.state != .Quit && !rl.WindowShouldClose() {
		process_input(&state)
		update(&state)
		start_game := draw(&state, temp_alloc)

		if start_game {
			mem.free_all(state_alloc)
			state, error = open_map("data/map.json", state_alloc)
			if error != nil {
				fmt.println("Error loading map data: ", error)
				panic("Failed to load map data")
			}
		}

		mem.free_all(temp_alloc)
	}
}
