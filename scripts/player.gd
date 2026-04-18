extends CharacterBody2D
class_name Player

## ================================================================
## SPIELER – Bewegung, Auto-Aim, Schießen, HP
## ================================================================
## Design-Prinzip (siehe GDD 01 - Kernmechanik):
##   Stehen = Schießen, Bewegen = Ausweichen
## Im Prototyp bewusst einfach gehalten: keine Dodge, kein Precision Mode.

signal health_changed(current: int, maximum: int)
signal died

## ----- Tuning-Parameter (im Inspector einstellbar) -----
@export var move_speed: float = 280.0
@export var max_health: int = 5
@export var shoot_interval: float = 0.35   ## Sekunden zwischen Schüssen
@export var projectile_speed: float = 600.0
@export var projectile_damage: int = 1
@export var invincibility_time: float = 0.8  ## I-Frames nach Treffer

## ----- Interne Variablen -----
var current_health: int
var shoot_timer: float = 0.0
var invincibility_timer: float = 0.0
var is_moving: bool = false

## Wird vom Game-Script gesetzt, damit der Spieler die Gegner findet
var enemy_group_name: String = "enemies"

## Projektil-Scene wird zur Laufzeit geladen
var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")

## Referenz auf die Sprite-Node (für Treffer-Flash und Idle-Wobble)
@onready var sprite: ColorRect = $Sprite

func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)
	z_index = 10
	# Collision-Layer: Spieler ist auf Layer 2, kollidiert mit World(1) und Enemy-Projektilen(5)
	collision_layer = 2    # Spieler ist auf Layer 2
	collision_mask = 21    # Kollidiert mit World(1) + Enemy(4) + EnemyProjectile(16)

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_shooting(delta)
	_handle_invincibility(delta)
	_handle_visuals(delta)

## Bewegung per WASD / Pfeiltasten
func _handle_movement(_delta: float) -> void:
	var input_dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	input_dir = input_dir.normalized()
	
	velocity = input_dir * move_speed
	is_moving = input_dir.length() > 0.01
	
	move_and_slide()

## Schießen: Nur wenn stillstehend, automatisch auf nächsten Gegner
func _handle_shooting(delta: float) -> void:
	shoot_timer -= delta
	
	# Kernregel: nur schießen wenn der Spieler NICHT bewegt
	if is_moving:
		return
	
	if shoot_timer > 0.0:
		return
	
	var target := _find_nearest_enemy()
	if target == null:
		return
	
	_shoot_at(target.global_position)
	shoot_timer = shoot_interval

## Findet den nächsten lebenden Gegner auf dem Bildschirm
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

## Spawnt ein Projektil in Richtung Zielposition
func _shoot_at(target_pos: Vector2) -> void:
	var projectile := projectile_scene.instantiate()
	projectile.global_position = global_position
	var direction := (target_pos - global_position).normalized()
	projectile.setup(direction, projectile_speed, projectile_damage, true)
	get_parent().add_child(projectile)

## I-Frames runterzählen
func _handle_invincibility(delta: float) -> void:
	if invincibility_timer > 0.0:
		invincibility_timer -= delta

## Visuelles Feedback: Idle-Wobble beim Stehen, Blink bei I-Frames
func _handle_visuals(_delta: float) -> void:
	if invincibility_timer > 0.0:
		# Schnelles Blinken während I-Frames
		sprite.visible = fmod(invincibility_timer * 20.0, 1.0) > 0.5
	else:
		sprite.visible = true

## Schaden nehmen (wird von Gegnern und deren Projektilen aufgerufen)
func take_damage(amount: int) -> void:
	if invincibility_timer > 0.0:
		return
	if current_health <= 0:
		return
	
	current_health -= amount
	invincibility_timer = invincibility_time
	health_changed.emit(current_health, max_health)
	
	# Kamera-Shake via Event an Game-Script
	get_tree().call_group("camera", "shake", 8.0, 0.2)
	
	if current_health <= 0:
		died.emit()

func is_dead() -> bool:
	return current_health <= 0
