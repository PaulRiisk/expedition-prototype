extends CharacterBody2D
class_name Player

## ================================================================
## SPIELER – Zwei Steuerungsmodi + Dash-Fähigkeit
## ================================================================
## Modus A (Standard): Stehen = Auto-Schießen, Bewegen = Ausweichen
## Modus B (Maus-Aim): WASD bewegt + schießt mit Maus, auch in Bewegung
## Dash (Leertaste): kurzer Speed-Burst in Bewegungsrichtung, unverwundbar

signal health_changed(current: int, maximum: int)
signal died

## ----- Steuerungsmodus -----
enum ControlMode { AUTO_AIM, MOUSE_AIM }
var control_mode: ControlMode = ControlMode.AUTO_AIM

## ----- Tuning -----
@export var move_speed: float = 280.0
@export var max_health: int = 5
@export var shoot_interval: float = 0.35
@export var projectile_speed: float = 600.0
@export var projectile_damage: int = 1
@export var invincibility_time: float = 0.8

## ----- Dash -----
@export var dash_cooldown: float = 6.0
@export var dash_duration: float = 0.2
@export var dash_speed_multiplier: float = 7.0

## ----- Interne Variablen -----
var current_health: int
var shoot_timer: float = 0.0
var invincibility_timer: float = 0.0
var is_moving: bool = false

## Dash-State
var is_dashing: bool = false
var dash_time_left: float = 0.0
var dash_cooldown_left: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
## Letzte Bewegungsrichtung (für Dash im Stand)
var last_move_dir: Vector2 = Vector2.UP

var enemy_group_name: String = "enemies"
var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")

@onready var sprite: ColorRect = $Sprite

## Cooldown-Leiste (wie HP-Bar der Gegner, aber blau) – wird in _ready erstellt
var cd_bar_bg: ColorRect
var cd_bar_fill: ColorRect

func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)
	z_index = 10
	collision_layer = 2
	collision_mask = 21
	_create_cooldown_bar()

func _create_cooldown_bar() -> void:
	# Position: oberhalb des Spielers, analog zum HP-Balken der Gegner
	var sprite_half_h: float = 14.0  # Spieler-Sprite ist 28x28
	
	cd_bar_bg = ColorRect.new()
	cd_bar_bg.size = Vector2(36, 4)
	cd_bar_bg.position = Vector2(-18, -sprite_half_h - 10)
	cd_bar_bg.color = Color(0.15, 0.15, 0.2, 0.8)
	cd_bar_bg.z_index = 5
	add_child(cd_bar_bg)
	
	cd_bar_fill = ColorRect.new()
	cd_bar_fill.size = Vector2(36, 4)
	cd_bar_fill.position = Vector2(-18, -sprite_half_h - 10)
	cd_bar_fill.color = Color(0.4, 0.7, 1.0, 0.95)  # blau
	cd_bar_fill.z_index = 6
	add_child(cd_bar_fill)

func _update_cooldown_bar() -> void:
	if cd_bar_fill == null:
		return
	# Balken zeigt "Readiness": voll = bereit, leer = frisch verbraucht
	var ratio: float = 1.0
	if dash_cooldown_left > 0.0:
		ratio = 1.0 - (dash_cooldown_left / dash_cooldown)
	cd_bar_fill.size.x = 36.0 * ratio
	# Wenn bereit: heller, sonst gedämpfter
	if dash_cooldown_left <= 0.0:
		cd_bar_fill.color = Color(0.4, 0.8, 1.0, 0.95)
	else:
		cd_bar_fill.color = Color(0.4, 0.7, 1.0, 0.75)

func _physics_process(delta: float) -> void:
	_handle_dash_input()
	_handle_dash_state(delta)
	_handle_movement(delta)
	_handle_shooting(delta)
	_handle_invincibility(delta)
	_handle_visuals(delta)
	_update_cooldown_bar()

func _handle_dash_input() -> void:
	if is_dashing:
		return
	if dash_cooldown_left > 0.0:
		return
	if not Input.is_key_pressed(KEY_SPACE):
		return
	_start_dash()

func _start_dash() -> void:
	# Richtung: aktueller Input, wenn vorhanden; sonst letzte Bewegungsrichtung.
	# Wenn der Spieler aber gerade noch nie bewegt wurde, dash in alle Fälle UP
	# (Fallback via last_move_dir = Vector2.UP).
	var input_dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if input_dir.length() > 0.01:
		dash_direction = input_dir.normalized()
	else:
		# Dash im Stand: nur Invul + Transparenz, keine Bewegung.
		dash_direction = Vector2.ZERO
	
	is_dashing = true
	dash_time_left = dash_duration
	dash_cooldown_left = dash_cooldown

func _handle_dash_state(delta: float) -> void:
	if is_dashing:
		dash_time_left -= delta
		if dash_time_left <= 0.0:
			is_dashing = false
	if dash_cooldown_left > 0.0:
		dash_cooldown_left -= delta
		if dash_cooldown_left < 0.0:
			dash_cooldown_left = 0.0

func _handle_movement(_delta: float) -> void:
	var input_dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	input_dir = input_dir.normalized()
	is_moving = input_dir.length() > 0.01
	if is_moving:
		last_move_dir = input_dir
	
	if is_dashing:
		# Dash überschreibt normale Bewegung
		velocity = dash_direction * move_speed * dash_speed_multiplier
	else:
		velocity = input_dir * move_speed
	move_and_slide()

func _handle_shooting(delta: float) -> void:
	shoot_timer -= delta
	
	match control_mode:
		ControlMode.AUTO_AIM:
			_shoot_auto_aim()
		ControlMode.MOUSE_AIM:
			_shoot_mouse_aim()

## Modus A: Nur schießen wenn still, automatisch auf nächsten Gegner
func _shoot_auto_aim() -> void:
	if is_moving:
		return
	if shoot_timer > 0.0:
		return
	var target := _find_nearest_enemy()
	if target == null:
		return
	_shoot_at(target.global_position)
	shoot_timer = shoot_interval

## Modus B: Schießen mit Maus, auch während Bewegung
func _shoot_mouse_aim() -> void:
	if shoot_timer > 0.0:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	var mouse_pos: Vector2 = get_global_mouse_position()
	if mouse_pos.distance_to(global_position) < 5.0:
		return
	_shoot_at(mouse_pos)
	shoot_timer = shoot_interval

func _find_nearest_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group(enemy_group_name)
	var nearest: Node2D = null
	var nearest_dist_sq: float = INF
	for e in enemies:
		if not e is Node2D:
			continue
		if e.has_method("is_dead") and e.is_dead():
			continue
		var dist_sq: float = global_position.distance_squared_to(e.global_position)
		if dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest = e
	return nearest

func _shoot_at(target_pos: Vector2) -> void:
	var projectile := projectile_scene.instantiate()
	get_parent().add_child(projectile)
	projectile.global_position = global_position
	var direction := (target_pos - global_position).normalized()
	projectile.setup(direction, projectile_speed, projectile_damage, true)

func _handle_invincibility(delta: float) -> void:
	if invincibility_timer > 0.0:
		invincibility_timer -= delta

func _handle_visuals(_delta: float) -> void:
	# Dash: transparent (überschreibt Invul-Flackern)
	if is_dashing:
		sprite.visible = true
		sprite.modulate = Color(1, 1, 1, 0.35)
		return
	# Invul nach Treffer: flackern
	if invincibility_timer > 0.0:
		sprite.visible = fmod(invincibility_timer * 20.0, 1.0) > 0.5
		sprite.modulate = Color(1, 1, 1, 1)
	else:
		sprite.visible = true
		sprite.modulate = Color(1, 1, 1, 1)

func take_damage(amount: int) -> void:
	# Während Dash komplett unverwundbar
	if is_dashing:
		return
	if invincibility_timer > 0.0:
		return
	if current_health <= 0:
		return
	current_health -= amount
	invincibility_timer = invincibility_time
	health_changed.emit(current_health, max_health)
	get_tree().call_group("camera", "shake", 8.0, 0.2)
	if current_health <= 0:
		died.emit()

func is_dead() -> bool:
	return current_health <= 0
