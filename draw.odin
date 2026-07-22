package main

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

@(private)
draw_game :: proc(state: ^State) {
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
}

@(private)
draw_main_menu :: proc(state: ^State) {
	ui_begin_frame(full_screen, rl.WHITE); {
		ui_text("Bullet Dodge Game", {0, -50}, rl.WHITE, rl.BLUE, 4, 60, .Center, .Center)

		if ui_button("Start game", {0, 50}, {200, 0}, align_x = .Center, align_y = .Center) {
			state.state = .Running
		}
		if ui_button("Quit", {0, 90}, {200, 0}, align_x = .Center, align_y = .Center) {
			state.state = .Quit
		}
	}; ui_end_frame()
}

@(private)
draw_game_ui :: proc(state: ^State) {
	ui_begin_frame(full_screen, padding = {20, 20}); {
		sb := strings.builder_make(ui_alloc)

		fmt.sbprintf(&sb, "Time: %3.3fs", state.survived_time)
		ui_text(strings.to_string(sb), {0, 0}, rl.BLACK, rl.WHITE, 1)

		strings.builder_reset(&sb)
		fmt.sbprintf(&sb, "Frametime: %3.0fms", state.delta_time * 1000)
		ui_text(strings.to_string(sb), {0, 25}, rl.BLACK, rl.WHITE, 1)

		strings.builder_reset(&sb)
		fmt.sbprintf(&sb, "Framerate: %3.0f fps", 1 / state.delta_time)
		ui_text(strings.to_string(sb), {0, 50}, rl.BLACK, rl.WHITE, 1)

		strings.builder_reset(&sb)
		fmt.sbprintf(&sb, "Bullets: %d", len(state.bullets))
		ui_text(strings.to_string(sb), {0, 75}, rl.BLACK, rl.WHITE, 1)

		strings.builder_reset(&sb)
		fmt.sbprintf(&sb, "Walls: %d", len(state.walls))
		ui_text(strings.to_string(sb), {0, 100}, rl.BLACK, rl.WHITE, 1)
	}; ui_end_frame()
}

@(private)
draw_game_over_menu :: proc(state: ^State) {
	ui_begin_frame(full_screen, {0, 0, 0, 128}); {
		ui_text("Game Over", {0, -200}, rl.WHITE, rl.BLACK, 2, 60, .Center, .Center)

		sb := strings.builder_make(ui_alloc)
		fmt.sbprintf(&sb, "Survived for %3.3f seconds", state.survived_time)

		ui_text(strings.to_string(sb), {0, -150}, rl.WHITE, rl.BLACK, 1, 30, .Center, .Center)

		if ui_button("Main Menu", {0, 50}, {200, 0}, align_x = .Center, align_y = .Center) {
			state.state = .Menu
		}
		if ui_button("Quit", {0, 90}, {200, 0}, align_x = .Center, align_y = .Center) {
			state.state = .Quit
		}
	}; ui_end_frame()
}

draw :: proc(state: ^State) {
	rl.BeginDrawing(); {
		// Game world
		if state.state != .Menu {
			draw_game(state)
		}

		// UI
		ui_begin(); {
			switch state.state {
			case .Menu:
				draw_main_menu(state)
			case .Running:
				draw_game_ui(state)
			case .Paused:
			case .Game_Over:
				draw_game_over_menu(state)
			case .Quit:
				unreachable()
			}
		}; ui_end()
	}; rl.EndDrawing()
}
