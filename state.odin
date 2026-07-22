package main

import "core:encoding/json"
import "core:mem"
import "core:os"
import rl "vendor:raylib"

vec2 :: [2]f32

BulletType :: enum {
	bouncer,
	bulldozer,
	constructor,
}

Wall :: struct {
	x1, x2, y1, y2: f32,
	invulnerable:   bool,
}

Spawner :: struct {
	x, y:            f32,
	spawn_frequency: f32,
	spawn_timer:     f32,
	velocity:        f32,
	bullet_type:     BulletType,
}

Bullet :: struct {
	using position: vec2,
	velocity:       vec2,
	type:           BulletType,
}

Player :: struct {
	position, velocity: vec2,
}

State :: struct {
	map_width:       i32,
	map_height:      i32,
	wall_thickness:  f32,
	player_speed:    f32,
	walls:           [dynamic]Wall,
	bullets:         [dynamic]Bullet,
	bullet_spawners: []Spawner,
	player:          Player,
	input_vector:    vec2,
	camera:          rl.Camera2D,
	elapsed_time:    f64,
	delta_time:      f64,
}

MapError :: union #shared_nil {
	os.Error,
	json.Unmarshal_Error,
	mem.Allocator_Error,
}

open_map :: proc(file_name: string) -> (state: State, err: MapError) {
	data := os.read_entire_file(file_name, context.allocator) or_return
	defer delete(data)

	json.unmarshal(data, &state) or_return
	state.bullets = make([dynamic]Bullet) or_return

	// Map bound walls
	w, h := f32(state.map_width), f32(state.map_height)
	append(
		&state.walls,
		Wall{x1 = 0, y1 = 0, x2 = w, y2 = 0, invulnerable = true},
		Wall{x1 = 0, y1 = h, x2 = w, y2 = h, invulnerable = true},
		Wall{x1 = 0, y1 = 0, x2 = 0, y2 = h, invulnerable = true},
		Wall{x1 = w, y1 = 0, x2 = w, y2 = h, invulnerable = true},
	)

	state.player.position.x = w / 2
	state.player.position.y = h / 2

	state.camera.zoom = 1.0

	state.elapsed_time = rl.GetTime()

	return
}
