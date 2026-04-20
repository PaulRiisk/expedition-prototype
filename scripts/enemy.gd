extends CharacterBody2D
class_name Enemy

## ================================================================
## GEGNER – Nahkämpfer, Fernkämpfer, Fächer-Schütze, Boss
## ================================================================

signal died(enemy: Enemy)

enum EnemyType { MELEE, RANGED, SPREAD }

## ----- Tuning -----
@export var enemy_type: EnemyType = EnemyType.MELEE
@export var max_health: int = 4
@export var move_speed: float = 120.0
@export var contact_damage: int = 1
@export var contact_damage_cooldown: float = 0.8

## Fernkampf-Parameter:
@export var shoot_interval: float = 1.5
@export var projectile_speed: float = 350.0
@export var ranged_keep_distance: float = 400.0

## ----- Boss-Charge -----
var is_boss: bool = false
var charge_cooldown: float = 2.0
var charge_timer: float = 2.5	## Startet mit erstem Charge
var charge_speed_multiplier: float = 9.0
var charge_duration: float = 0.75
var is_charging: bool = false
var charge_time_left: float = 0.0
var charge_direction: Vector2 = Vector2.ZERO

## ----- Spawn-Delay -----
var spawn_delay: float = 0.0
var spawn_delay_timer: float = 0.0
var is_active: bool = false

## ----- Interne Variablen -----
var current_health: int
var contact_damage_timer: float = 0.0
var shoot_timer: float = 0.0
var hit_flash_timer: float = 0.0
var dead: bool = false

var player_ref: Node2D = null
var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")

@onready var sprite: ColorRect = $Sprite

## HP-Balken Nodes (werden in _ready erstellt)
var hp_bar_bg: ColorRect
var hp_bar_fill: ColorRect

func _ready() -> void:
	current_health = max_health
	add_to_group("enemies")
	
	collision_layer = 4
	collision_mask = 11
	
	# Visuals je nach Typ
	match enemy_type:
		EnemyType.MELEE:
			sprite.color = Color(0.85, 0.2, 0.3)  # Rot
			sprite.size = Vector2(32, 32)
			sprite.position = Vector2(-16, -16)
		EnemyType.RANGED:
			sprite.color = Color(0.9, 0.5, 0.2)  # Orange
			sprite.size = Vector2(28, 28)
			sprite.position = Vector2(-14, -14)
		EnemyType.SPREAD:
			sprite.color = Color(0.6, 0.25, 0.7)  # Lila
			sprite.size = Vector2(30, 30)
			sprite.position = Vector2(-15, -15)
	
	# Boss: größer, dunkler
	if is_boss:
		sprite.color = Color(0.7, 0.1, 0.15)
		sprite.size = Vector2(48, 48)
		sprite.position = Vector2(-24, -24)
	
	# HP-Balken erstellen
	_create_hp_bar()
	
	shoot_timer = randf_range(0.3, shoot_interval)
	
	# Spawn-Delay
	if spawn_delay > 0.0:
		spawn_delay_timer = spawn_delay
		is_active = false
		modulate = Color(1, 1, 1, 0.4)
	else:
		is_active = true

func _create_hp_bar() -> void:
	# Hintergrund (dunkelgrau)
	hp_bar_bg = ColorRect.new()
	hp_bar_bg.size = Vector2(36, 5)
	hp_bar_bg.position = Vector2(-18, -sprite.size.y / 2.0 - 12)
	hp_bar_bg.color = Color(0.15, 0.15, 0.2, 0.8)
	hp_bar_bg.z_index = 5
	add_child(hp_bar_bg)
	
	# Füllung (rot → wird bei Schaden kürzer)
	hp_bar_fill = ColorRect.new()
	hp_bar_fill.size = Vector2(36, 5)
	hp_bar_fill.position = Vector2(-18, -sprite.size.y / 2.0 - 12)
	hp_bar_fill.color = Color(0.85, 0.2, 0.2, 0.9)
	hp_bar_fill.z_index = 6
	add_child(hp_bar_fill)

func _update_hp_bar() -> void:
	if hp_bar_fill == null:
		return
	var ratio: float = float(current_health) / float(max_health)
	hp_bar_fill.size.x = 36.0 * ratio

func _physics_process(delta: float) -> void:
	if dead or player_ref == null:
		return
	
	if not is_active:
		spawn_delay_timer -= delta
		if spawn_delay_timer <= 0.0:
			is_active = true
			modulate = Color(1, 1, 1, 1)
		return
	
	_handle_timers(delta)
	_handle_behavior(delta)
	_handle_visuals()

func _handle_timers(delta: float) -> void:
	if contact_damage_timer > 0.0:
		contact_damage_timer -= delta
	if shoot_timer > 0.0:
		shoot_timer -= delta
	if hit_flash_timer > 0.0:
		hit_flash_timer -= delta
	if is_boss and not is_charging:
		charge_timer -= delta

func _handle_behavior(delta: float) -> void:
	var to_player: Vector2 = player_ref.global_position - global_position
	var distance: float = to_player.length()
	var direction: Vector2 = to_player.normalized() if distance > 0.01 else Vector2.ZERO
	
	if is_boss:
		_behavior_boss(direction, distance, delta)
	else:
		match enemy_type:
			EnemyType.MELEE:
				_behavior_melee(direction, distance)
			EnemyType.RANGED:
				_behavior_ranged(direction, distance, 1)
			EnemyType.SPREAD:
				_behavior_ranged(direction, distance, 3)
	
	move_and_slide()
	_check_contact_damage()

func _behavior_melee(direction: Vector2, _distance: float) -> void:
	velocity = direction * move_speed

func _behavior_ranged(direction: Vector2, distance: float, shot_count: int) -> void:
	if distance < ranged_keep_distance - 30:
		velocity = -direction * move_speed
	elif distance > ranged_keep_distance + 30:
		velocity = direction * (move_speed * 0.7)
	else:
		velocity = Vector2.ZERO
	
	if shoot_timer <= 0.0:
		_shoot_fan(shot_count)
		shoot_timer = shoot_interval

func _behavior_boss(direction: Vector2, _distance: float, delta: float) -> void:
	if is_charging:
		velocity = charge_direction * move_speed * charge_speed_multiplier
		charge_time_left -= delta
		if charge_time_left <= 0.0:
			is_charging = false
			charge_timer = charge_cooldown
			velocity = Vector2.ZERO
	elif charge_timer <= 0.0:
		is_charging = true
		charge_direction = direction
		charge_time_left = charge_duration
		hit_flash_timer = 0.15
	else:
		velocity = direction * move_speed

## Schießt 1 oder mehr Projektile als Fächer
func _shoot_fan(count: int) -> void:
	if player_ref == null:
		return
	var base_dir: Vector2 = (player_ref.global_position - global_position).normalized()
	
	if count <= 1:
		_fire_projectile(base_dir)
	else:
		var spread_angle: float = deg_to_rad(30.0)
		var half_spread: float = spread_angle / 2.0
		for i in range(count):
			var t: float = float(i) / float(count - 1)
			var angle_offset: float = lerp(-half_spread, half_spread, t)
			_fire_projectile(base_dir.rotated(angle_offset))

func _fire_projectile(direction: Vector2) -> void:
	var projectile := projectile_scene.instantiate()
	projectile.global_position = global_position
	projectile.setup(direction, projectile_speed, contact_damage, false)
	get_parent().add_child(projectile)

func _check_contact_damage() -> void:
	if contact_damage_timer > 0.0:
		return
	if player_ref == null or not player_ref.has_method("take_damage"):
		return
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		if collision.get_collider() == player_ref:
			player_ref.take_damage(contact_damage)
			contact_damage_timer = contact_damage_cooldown
			break

func _handle_visuals() -> void:
	if hit_flash_timer > 0.0:
		sprite.modulate = Color(2.5, 2.5, 2.5)
	else:
		sprite.modulate = Color.WHITE

func take_damage(amount: int) -> void:
	if dead:
		return
	current_health -= amount
	hit_flash_timer = 0.08
	_update_hp_bar()
	if current_health <= 0:
		_die()

func _die() -> void:
	if dead:
		return
	dead = true
	died.emit(self)
	queue_free()

func is_dead() -> bool:
	return dead
