package main

import "core:math"
import la "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

@(private)
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

@(private)
update_player :: proc(state: ^State) {
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
			movement_vector -= min(normal_movement_mag, -dist * 1.05) * direction
		}
	}

	state.player.position = state.player.position + movement_vector
}

@(private)
update_spawners :: proc(state: ^State) {
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
}

@(private)
bounce_bullet :: proc(bullet: ^Bullet, move, direction: vec2, dist: f32) -> vec2 {
	movement_length := la.length(move)
	first_move_length := la.length(move) + dist
	bullet.position += la.normalize(move) * first_move_length // Move to collision point

	movement_length -= first_move_length
	bullet.velocity += 2 * la.dot(bullet.velocity, -direction) * direction
	return la.normalize(bullet.velocity) * movement_length
}

@(private)
update_bullets :: proc(state: ^State) {
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
					movement_vector = bounce_bullet(bullet, movement_vector, direction, dist)
				case .bulldozer:
					if !wall.invulnerable {
						unordered_remove(&state.walls, wall_idx)
						unordered_remove(&state.bullets, bullet_idx)
						bullet_idx -= 1
						break wall_loop
					} else {
						movement_vector = bounce_bullet(bullet, movement_vector, direction, dist)
					}
				case .constructor:
					p1 :=
						bullet.position +
						movement_vector +
						(5 + state.wall_thickness / 2 - dist) * direction
					p2 := p1 - 100 * direction
					p1 += 100 * direction
					append(&state.walls, Wall{x1 = p1.x, y1 = p1.y, x2 = p2.x, y2 = p2.y})

					unordered_remove(&state.bullets, bullet_idx)
					bullet_idx -= 1
					break wall_loop
				}
			}
		}

		bullet.position += movement_vector
	}
}

update :: proc(state: ^State) {
	// Update time
	now := rl.GetTime()
	state.delta_time = now - state.elapsed_time
	state.elapsed_time = now

	if state.state != .Running do return

	state.survived_time += state.delta_time

	update_player(state)
	update_spawners(state)
	update_bullets(state)

	// Check player bullet collisions
	for bullet in state.bullets {
		if rl.CheckCollisionCircles(state.player.position, 10, bullet.position, 5) {
			state.state = .Game_Over
		}
	}

	// Update camera
	state.camera.target = state.player.position
	state.camera.offset.x = f32(window_width) / 2
	state.camera.offset.y = f32(window_height) / 2
	state.camera.offset -= 0.2 * state.player.velocity
}
