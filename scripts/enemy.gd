extends CharacterBody2D
class_name Enemy

## ================================================================
## GEGNER – Basisklasse für Nahkämpfer und Fernkämpfer
## ================================================================
## Typ wird über den Inspector gesetzt (Export-Variable).
## So muss man nicht für jeden Gegnertyp eine eigene Scene anlegen.

signal died(enemy: Enemy)

enum EnemyType { MELEE, RANGED }

## ----- Tuning -----
@export var enemy_type: EnemyType = EnemyType.MELEE
@export var max_health: int = 3
@export var move_speed: float = 120.0
@export var contact_damage: int = 1
@export var contact_damage_cooldown: float = 0.8

## Nur für RANGED relevant:
@export var shoot_interval: float = 1.5
@export var projectile_speed: float = 300.0
@export var ranged_keep_distance: float = 250.0  ## Abstand den Fernkämpfer halten wollen

## ----- Interne Variablen -----
var current_health: int
var contact_damage_timer: float = 0.0
var shoot_timer: float = 0.0
var hit_flash_timer: float = 0.0
var dead: bool = false

## Wird vom Spawner gesetzt
var player_ref: Node2D = null

var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")

@onready var sprite: ColorRect = $Sprite

func _ready() -> void:
	current_health = max_health
	add_to_group("enemies")
	
	# Collision-Layer: Gegner auf Layer 3, kollidiert mit World(1), Player(2), Player-Projektilen(4)
	collision_layer = 4    # Gegner ist auf Layer 3
	collision_mask = 11    # Kollidiert mit World(1) + Player(2) + PlayerProjectile(8)
	
	# Visuell unterscheiden je nach Typ
	if enemy_type == EnemyType.RANGED:
		sprite.color = Color(0.9, 0.5, 0.2)  # Orange = Schütze
		sprite.size = Vector2(28, 28)
		sprite.position = Vector2(-14, -14)
	else:
		sprite.color = Color(0.85, 0.2, 0.3)  # Rot = Nahkampf
		sprite.size = Vector2(32, 32)
		sprite.position = Vector2(-16, -16)
	
	# Schuss-Timer leicht randomisieren, damit nicht alle synchron schießen
	shoot_timer = randf_range(0.3, shoot_interval)

func _physics_process(delta: float) -> void:
	if dead or player_ref == null:
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

## Verhalten je nach Typ
func _handle_behavior(_delta: float) -> void:
	var to_player: Vector2 = player_ref.global_position - global_position
	var distance: float = to_player.length()
	var direction: Vector2 = to_player.normalized() if distance > 0.01 else Vector2.ZERO
	
	match enemy_type:
		EnemyType.MELEE:
			_behavior_melee(direction, distance)
		EnemyType.RANGED:
			_behavior_ranged(direction, distance)
	
	move_and_slide()
	_check_contact_damage()

## Nahkämpfer: läuft direkt auf den Spieler zu
func _behavior_melee(direction: Vector2, _distance: float) -> void:
	velocity = direction * move_speed

## Fernkämpfer: hält Abstand und schießt
func _behavior_ranged(direction: Vector2, distance: float) -> void:
	# Abstandsverhalten: zu nah -> wegbewegen, zu weit -> ranbewegen, gut -> stehen
	if distance < ranged_keep_distance - 30:
		velocity = -direction * move_speed
	elif distance > ranged_keep_distance + 30:
		velocity = direction * (move_speed * 0.7)
	else:
		velocity = Vector2.ZERO
	
	# Schießen
	if shoot_timer <= 0.0:
		_shoot_at_player(direction)
		shoot_timer = shoot_interval

func _shoot_at_player(_direction: Vector2) -> void:
	if player_ref == null:
		return
	var projectile := projectile_scene.instantiate()
	projectile.global_position = global_position
	# Präzises Zielen auf aktuelle Spielerposition
	var shoot_dir: Vector2 = (player_ref.global_position - global_position).normalized()
	projectile.setup(shoot_dir, projectile_speed, contact_damage, false)
	get_parent().add_child(projectile)

## Kontaktschaden: Wenn Gegner den Spieler berührt
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

## Visuelles Feedback: Hit-Flash
func _handle_visuals() -> void:
	if hit_flash_timer > 0.0:
		sprite.modulate = Color(2.5, 2.5, 2.5)  # Weiß-Flash
	else:
		sprite.modulate = Color.WHITE

## Schaden nehmen (wird von Projektilen aufgerufen)
func take_damage(amount: int) -> void:
	if dead:
		return
	current_health -= amount
	hit_flash_timer = 0.08
	
	# Kleiner Knockback-Effekt könnte hier rein – erstmal weggelassen
	
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
