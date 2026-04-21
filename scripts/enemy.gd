extends CharacterBody2D
class_name Enemy

## ================================================================
## GEGNER – Nahkämpfer, Fernkämpfer, Fächer-Schütze, Boss 1, Boss 2
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

## Farbe für Fächerschütze-Projektile (lila, passend zum Sprite)
const SPREAD_PROJECTILE_COLOR: Color = Color(0.75, 0.4, 0.95)

## ----- Boss-Charge -----
var is_boss: bool = false
var is_boss2: bool = false   ## Boss 2 = Boss 1 + Fächerschuss + mehr HP
var charge_cooldown: float = 2.0
var charge_timer: float = 2.5	## Startet mit erstem Charge
var charge_speed_multiplier: float = 10.0
var charge_duration: float = 0.53
var is_charging: bool = false
var charge_time_left: float = 0.0
var charge_direction: Vector2 = Vector2.ZERO

## Boss-2 Fächerschuss
var boss2_fan_cooldown: float = 2
var boss2_fan_timer: float = 1.2

## ----- Spawn-Delay -----
var spawn_delay: float = 0.0
var spawn_delay_timer: float = 0.0
var is_active: bool = false

## ----- Separation / Anti-Glitch -----
## Verhindert, dass Gegner ineinander stecken.
## Wird nur bei aktiven, nicht-chargenden Gegnern angewendet.
const SEPARATION_RADIUS: float = 44.0
const SEPARATION_STRENGTH: float = 180.0

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

## Farbe des Sprites (für Death-Partikel)
var sprite_color: Color = Color.WHITE

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
	
	# Boss 1: größer, dunkelrot
	if is_boss and not is_boss2:
		sprite.color = Color(0.7, 0.1, 0.15)
		sprite.size = Vector2(48, 48)
		sprite.position = Vector2(-24, -24)
	
	# Boss 2: größer, dunkel-lila (visuell klar unterscheidbar)
	if is_boss2:
		sprite.color = Color(0.55, 0.15, 0.65)
		sprite.size = Vector2(48, 48)
		sprite.position = Vector2(-24, -24)
	
	sprite_color = sprite.color
	
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
	if is_boss2 and boss2_fan_timer > 0.0:
		boss2_fan_timer -= delta

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
	
	# Separation-Steering: verhindert, dass Gegner ineinander glitchen.
	# Während Boss-Charge überspringen, damit der Charge nicht verzerrt wird.
	if not is_charging:
		velocity += _compute_separation() * SEPARATION_STRENGTH
	
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
	
	# Boss 2: zusätzlich regelmäßig Fächerschüsse (außer während Charge)
	if is_boss2 and not is_charging and boss2_fan_timer <= 0.0:
		_shoot_fan(5)
		boss2_fan_timer = boss2_fan_cooldown

## Schießt 1 oder mehr Projektile als Fächer
func _shoot_fan(count: int) -> void:
	if player_ref == null:
		return
	var base_dir: Vector2 = (player_ref.global_position - global_position).normalized()
	
	if count <= 1:
		_fire_projectile(base_dir)
	else:
		# Weiterer Fächer bei >3 Projektilen für den Boss 2
		var spread_angle: float = deg_to_rad(30.0) if count <= 3 else deg_to_rad(55.0)
		var half_spread: float = spread_angle / 2.0
		for i in range(count):
			var t: float = float(i) / float(count - 1)
			var angle_offset: float = lerp(-half_spread, half_spread, t)
			_fire_projectile(base_dir.rotated(angle_offset))

func _fire_projectile(direction: Vector2) -> void:
	var projectile := projectile_scene.instantiate()
	projectile.global_position = global_position
	# SPREAD-Gegner und Boss 2 verschießen lila Projektile
	var use_purple: bool = (enemy_type == EnemyType.SPREAD) or is_boss2
	var color_override: Variant = SPREAD_PROJECTILE_COLOR if use_purple else null
	projectile.setup(direction, projectile_speed, contact_damage, false, color_override)
	get_parent().add_child(projectile)

## Berechnet einen Wegdrück-Vektor basierend auf nahen anderen Gegnern.
## Verhindert Ineinander-Glitchen durch sanfte Abstoßung.
func _compute_separation() -> Vector2:
	var push: Vector2 = Vector2.ZERO
	var enemies := get_tree().get_nodes_in_group("enemies")
	for other in enemies:
		if other == self:
			continue
		if not (other is Node2D):
			continue
		if other.has_method("is_dead") and other.is_dead():
			continue
		var diff: Vector2 = global_position - other.global_position
		var dist: float = diff.length()
		if dist <= 0.01:
			# Exakt auf derselben Position → zufälligen Schubs geben
			push += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
			continue
		if dist < SEPARATION_RADIUS:
			# Linearer Falloff: nahe = stärker, weit = schwächer
			var strength: float = 1.0 - (dist / SEPARATION_RADIUS)
			push += (diff / dist) * strength
	return push

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
	_spawn_death_particles()
	died.emit(self)
	queue_free()

## Kleine farbige Partikel-Explosion beim Tod
func _spawn_death_particles() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var count: int = 14 if is_boss else 9
	var size: float = 6.0 if is_boss else 5.0
	var origin: Vector2 = global_position
	for i in range(count):
		var p := ColorRect.new()
		p.size = Vector2(size, size)
		p.color = sprite_color
		p.z_index = 20
		parent.add_child(p)
		# global_position statt position, damit der ROOM_OFFSET kein
		# sichtbares Offset zwischen Tod und Partikeln erzeugt.
		p.global_position = origin - Vector2(size * 0.5, size * 0.5)
		
		var angle: float = randf() * TAU
		var dist: float = randf_range(22.0, 55.0) if is_boss else randf_range(14.0, 40.0)
		var target: Vector2 = p.global_position + Vector2(cos(angle), sin(angle)) * dist
		var duration: float = randf_range(0.35, 0.55)
		
		var tween := p.create_tween()
		tween.set_parallel(true)
		tween.tween_property(p, "global_position", target, duration)
		tween.tween_property(p, "modulate:a", 0.0, duration)
		tween.chain().tween_callback(p.queue_free)

func is_dead() -> bool:
	return dead
