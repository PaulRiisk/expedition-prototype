extends CharacterBody2D
class_name Enemy

## ================================================================
## GEGNER – Basisklasse für Nahkämpfer, Fernkämpfer und Boss
## ================================================================

signal died(enemy: Enemy)

enum EnemyType { MELEE, RANGED }

## ----- Tuning (im Inspector einstellbar) -----
@export var enemy_type: EnemyType = EnemyType.MELEE
@export var max_health: int = 3
@export var move_speed: float = 120.0
@export var contact_damage: int = 1
@export var contact_damage_cooldown: float = 0.8

## Nur für RANGED relevant:
@export var shoot_interval: float = 1.5
@export var projectile_speed: float = 300.0
@export var ranged_keep_distance: float = 350.0
@export var fan_shot_count: int = 1        ## 1 = einzeln, 3 = Fächer
@export var fan_spread_angle: float = 25.0 ## Winkel des Fächers in Grad

## ----- Boss-Charge (nur für Boss-Nahkämpfer) -----
var is_boss: bool = false
var charge_cooldown: float = 2.5       ## Sekunden zwischen Charges
var charge_timer: float = 2.5          ## Startet nach 3s mit erstem Charge
var charge_speed_multiplier: float = 7.0
var charge_duration: float = 1.0       ## Wie lang der Charge dauert
var is_charging: bool = false
var charge_time_left: float = 0.0
var charge_direction: Vector2 = Vector2.ZERO

## ----- Spawn-Delay -----
var spawn_delay: float = 0.0          ## Wird vom Room gesetzt
var spawn_delay_timer: float = 0.0
var is_active: bool = false            ## Gegner bewegen/schießen erst nach Delay

## ----- Interne Variablen -----
var current_health: int
var contact_damage_timer: float = 0.0
var shoot_timer: float = 0.0
var hit_flash_timer: float = 0.0
var dead: bool = false

var player_ref: Node2D = null
var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")

@onready var sprite: ColorRect = $Sprite

func _ready() -> void:
	current_health = max_health
	add_to_group("enemies")
	
	collision_layer = 4
	collision_mask = 11
	
	# Visuell unterscheiden je nach Typ
	if enemy_type == EnemyType.RANGED:
		sprite.color = Color(0.9, 0.5, 0.2)
		sprite.size = Vector2(28, 28)
		sprite.position = Vector2(-14, -14)
	else:
		sprite.color = Color(0.85, 0.2, 0.3)
		sprite.size = Vector2(32, 32)
		sprite.position = Vector2(-16, -16)
	
	# Boss visuell größer und dunkler
	if is_boss:
		sprite.color = Color(0.7, 0.1, 0.15)
		sprite.size = Vector2(48, 48)
		sprite.position = Vector2(-24, -24)
	
	# Schuss-Timer randomisieren
	shoot_timer = randf_range(0.3, shoot_interval)
	
	# Spawn-Delay: Gegner startet inaktiv
	if spawn_delay > 0.0:
		spawn_delay_timer = spawn_delay
		is_active = false
		# Während Delay leicht transparent
		modulate = Color(1, 1, 1, 0.4)
	else:
		is_active = true

func _physics_process(delta: float) -> void:
	if dead or player_ref == null:
		return
	
	# Spawn-Delay abwarten
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
	# Boss: Charge-Timer
	if is_boss and not is_charging:
		charge_timer -= delta

func _handle_behavior(delta: float) -> void:
	var to_player: Vector2 = player_ref.global_position - global_position
	var distance: float = to_player.length()
	var direction: Vector2 = to_player.normalized() if distance > 0.01 else Vector2.ZERO
	
	# Boss-Charge hat Priorität
	if is_boss:
		_behavior_boss(direction, distance, delta)
	else:
		match enemy_type:
			EnemyType.MELEE:
				_behavior_melee(direction, distance)
			EnemyType.RANGED:
				_behavior_ranged(direction, distance)
	
	move_and_slide()
	_check_contact_damage()

func _behavior_melee(direction: Vector2, _distance: float) -> void:
	velocity = direction * move_speed

func _behavior_ranged(direction: Vector2, distance: float) -> void:
	if distance < ranged_keep_distance - 30:
		velocity = -direction * move_speed
	elif distance > ranged_keep_distance + 30:
		velocity = direction * (move_speed * 0.7)
	else:
		velocity = Vector2.ZERO
	
	if shoot_timer <= 0.0:
		_shoot_at_player()
		shoot_timer = shoot_interval

## Boss: Normales Verfolgen + gelegentlicher Charge
func _behavior_boss(direction: Vector2, _distance: float, delta: float) -> void:
	if is_charging:
		# Charge läuft: geradeaus in festgelegte Richtung
		velocity = charge_direction * move_speed * charge_speed_multiplier
		charge_time_left -= delta
		if charge_time_left <= 0.0:
			is_charging = false
			charge_timer = charge_cooldown
			# Kurz stehen bleiben nach Charge
			velocity = Vector2.ZERO
	elif charge_timer <= 0.0:
		# Charge starten! Richtung zum Spieler einfrieren
		is_charging = true
		charge_direction = direction
		charge_time_left = charge_duration
		# Visuelles Signal: kurz weiß aufblitzen
		hit_flash_timer = 0.15
	else:
		# Normales Verfolgen (etwas langsamer als Standard-Melee)
		velocity = direction * move_speed

## Fächer-Schuss: 1 Projektil = gezielt, 3 = Fächer
func _shoot_at_player() -> void:
	if player_ref == null:
		return
	
	var base_dir: Vector2 = (player_ref.global_position - global_position).normalized()
	
	if fan_shot_count <= 1:
		# Einzelschuss
		_fire_projectile(base_dir)
	else:
		# Fächer: gleichmäßig um die Zielrichtung verteilt
		var half_spread: float = deg_to_rad(fan_spread_angle / 2.0)
		for i in range(fan_shot_count):
			var t: float = float(i) / float(fan_shot_count - 1)  # 0.0 bis 1.0
			var angle_offset: float = lerp(-half_spread, half_spread, t)
			var rotated_dir: Vector2 = base_dir.rotated(angle_offset)
			_fire_projectile(rotated_dir)

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
		var collider := collision.get_collider()
		if collider == player_ref:
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
