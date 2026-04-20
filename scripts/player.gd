extends CharacterBody2D
class_name Player

## ================================================================
## SPIELER – Zwei Steuerungsmodi
## ================================================================
## Modus A (Standard): Stehen = Auto-Schießen, Bewegen = Ausweichen
## Modus B (Maus-Aim): WASD bewegt + schießt mit Maus, auch in Bewegung

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

## ----- Interne Variablen -----
var current_health: int
var shoot_timer: float = 0.0
var invincibility_timer: float = 0.0
var is_moving: bool = false

var enemy_group_name: String = "enemies"
var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")

@onready var sprite: ColorRect = $Sprite

func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)
	z_index = 10
	collision_layer = 2
	collision_mask = 21

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_shooting(delta)
	_handle_invincibility(delta)
	_handle_visuals(delta)

func _handle_movement(_delta: float) -> void:
	var input_dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	input_dir = input_dir.normalized()
	velocity = input_dir * move_speed
	is_moving = input_dir.length() > 0.01
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
	# Mausposition in Weltkoordinaten – muss mit global_position verglichen werden
	var mouse_pos: Vector2 = get_global_mouse_position()
	# Sicherheitscheck: nicht auf sich selbst schießen
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
	# Projektil als Sibling hinzufügen, Position in Weltkoordinaten
	get_parent().add_child(projectile)
	projectile.global_position = global_position
	var direction := (target_pos - global_position).normalized()
	projectile.setup(direction, projectile_speed, projectile_damage, true)

func _handle_invincibility(delta: float) -> void:
	if invincibility_timer > 0.0:
		invincibility_timer -= delta

func _handle_visuals(_delta: float) -> void:
	if invincibility_timer > 0.0:
		sprite.visible = fmod(invincibility_timer * 20.0, 1.0) > 0.5
	else:
		sprite.visible = true

func take_damage(amount: int) -> void:
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
