package main

import "core:fmt"
import "core:math"
import la "core:math/linalg"
import "core:math/rand"
import "core:mem"
import rl "vendor:raylib"

window_width :: 1200
window_height :: 800

init :: proc() {
	rl.InitWindow(window_width, window_height, "Memory Assignment")
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

collide_line_circle :: proc(x: vec2, radius: f32, p1, p2: vec2) -> (bool, vec2, f32) {
	// Get the closest point s on the segment p1-p2 to the center x
	lambda_s := la.dot(x - p1, p2 - p1) / la.dot(p2 - p1, p2 - p1)
	lambda_s = la.saturate(lambda_s) // Constrain s to be within the segment
	s := la.lerp(p1, p2, lambda_s)

	// Calculate x->s vector
	d := s - x
	dist := la.length(d) - radius

	return dist <= 0, la.normalize(d), dist
}

update :: proc(state: ^State) {
	// Update time
	now := rl.GetTime()
	state.delta_time = now - state.elapsed_time
	state.elapsed_time = now

	// Update player
	target_velocity := state.input_vector * state.player_speed
	state.player.velocity = la.lerp(
		state.player.velocity,
		target_velocity,
		5 * f32(state.delta_time),
	)
	movement_vector := state.player.velocity * f32(state.delta_time)

	// Check collisions
	for wall in state.walls {
		collides, direction, dist := collide_line_circle(
			state.player.position + movement_vector,
			10 + state.wall_thickness / 2,
			{wall.x1, wall.y1},
			{wall.x2, wall.y2},
		)

		if collides {
			// Remove the movement component normal to the wall, ie in the direction of collision
			normal_movement_mag := la.dot(direction, movement_vector)
			movement_vector -= min(normal_movement_mag, -dist) * direction
		}
	}

	state.player.position = state.player.position + movement_vector

	// Update spawners
	for &spawner in state.bullet_spawners {
		if spawner.spawn_timer >= spawner.spawn_frequency {
			spawner.spawn_timer -= spawner.spawn_frequency

			angle := rand.float32_range(0, math.TAU)
			direction: vec2 = {math.cos(angle), math.sin(angle)}
			bullet: Bullet = {
				x        = spawner.x,
				y        = spawner.y,
				type     = spawner.bullet_type,
				velocity = direction * spawner.velocity,
			}

			append(&state.bullets, bullet)
		}

		spawner.spawn_timer += f32(state.delta_time)
	}

	// Update bullets
	for bullet_idx := 0; bullet_idx < len(state.bullets); bullet_idx += 1 {
		bullet := &state.bullets[bullet_idx]

		movement_vector := bullet.velocity * f32(state.delta_time)

		wall_loop: for wall, wall_idx in state.walls {
			collides, direction, dist := collide_line_circle(
				bullet.position + movement_vector,
				5 + state.wall_thickness / 2,
				{wall.x1, wall.y1},
				{wall.x2, wall.y2},
			)

			if collides {
				switch bullet.type {
				case .bouncer:
					movement_length := la.length(movement_vector)
					first_move_length := la.length(movement_vector) + dist
					bullet.position += la.normalize(movement_vector) * first_move_length // Move to collision point

					movement_length -= first_move_length
					bullet.velocity += 2 * la.dot(bullet.velocity, -direction) * direction
					movement_vector = la.normalize(bullet.velocity) * movement_length
				case .bulldozer:
					if !wall.invulnerable {
						unordered_remove(&state.walls, wall_idx)
					}

					unordered_remove(&state.bullets, bullet_idx)
					bullet_idx -= 1
					break wall_loop
				case .constructor:
					p1 :=
						bullet.position +
						movement_vector +
						(5 + state.wall_thickness / 2 - dist) * direction
					p2 := p1 - 100 * direction
					append(&state.walls, Wall{x1 = p1.x, y1 = p1.y, x2 = p2.x, y2 = p2.y})

					unordered_remove(&state.bullets, bullet_idx)
					bullet_idx -= 1
					break wall_loop
				}
			}
		}

		bullet.position += movement_vector
	}

	// Update camera
	state.camera.target = state.player.position
	state.camera.offset.x = f32(window_width) / 2
	state.camera.offset.y = f32(window_height) / 2
	state.camera.offset -= 0.2 * state.player.velocity
}

draw :: proc(state: ^State) {
	rl.BeginDrawing(); {
		rl.BeginMode2D(state.camera); {
			rl.ClearBackground(rl.BLACK)

			// Game area
			rl.DrawRectangle(0, 0, state.map_width, state.map_height, rl.WHITE)

			// Player
			rl.DrawCircleV(state.player.position, 10, rl.RED)

			// Walls
			for wall in state.walls {
				rl.DrawLineEx(
					{wall.x1, wall.y1},
					{wall.x2, wall.y2},
					state.wall_thickness,
					rl.BLACK if wall.invulnerable else rl.DARKBLUE,
				)
			}

			// Spawners
			for spawner in state.bullet_spawners {
				rl.DrawCircleV({spawner.x, spawner.y}, 10, rl.ORANGE)
			}

			// Bullets
			for bullet in state.bullets {
				rl.DrawCircleV(bullet.position, 5, rl.BLACK)
			}
		}; rl.EndMode2D()
	}; rl.EndDrawing()
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

	for exit := false; !exit && !rl.WindowShouldClose(); {
		process_input(&state)
		update(&state)
		draw(&state)
	}
}
