extends Node2D
class_name Room

## ================================================================
## RAUM – ein einzelner Kampfraum
## ================================================================
## Der Raum spawnt Gegner, wartet bis alle tot sind, öffnet dann die Tür.

signal room_cleared

## Raumgrenzen (müssen mit Wänden im Scene-Setup matchen)
const ROOM_WIDTH: float = 1100.0
const ROOM_HEIGHT: float = 600.0

## ----- Konfiguration -----
@export var num_melee_enemies: int = 2
@export var num_ranged_enemies: int = 0
@export var is_boss_room: bool = false
@export var room_number: int = 1
@export var total_rooms: int = 10

## Spawn-Positionen (werden zur Laufzeit berechnet)
var spawn_margin: float = 80.0

var enemies_alive: int = 0
var cleared: bool = false
var player_ref: Node2D = null

var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")

## Referenzen auf Nodes in der Scene
@onready var exit_door: ColorRect = $ExitDoor
@onready var enemies_container: Node = $Enemies

func _ready() -> void:
	exit_door.modulate = Color(0.4, 0.2, 0.2)  # Geschlossen = dunkelrot
	# Warten bis Game-Script den Player gesetzt hat
	call_deferred("_spawn_enemies")

func set_player(p: Node2D) -> void:
	player_ref = p

func _spawn_enemies() -> void:
	if player_ref == null:
		# Warten bis Player gesetzt ist
		await get_tree().create_timer(0.05).timeout
		if player_ref == null:
			return
	
	# Boss-Raum: ein einzelner starker Nahkämpfer
	if is_boss_room:
		_spawn_enemy(Enemy.EnemyType.MELEE, _random_spawn_pos(), true)
		enemies_alive += 1
		return
	
	for i in range(num_melee_enemies):
		_spawn_enemy(Enemy.EnemyType.MELEE, _random_spawn_pos(), false)
		enemies_alive += 1
	
	for i in range(num_ranged_enemies):
		_spawn_enemy(Enemy.EnemyType.RANGED, _random_spawn_pos(), false)
		enemies_alive += 1
	
	# Edge Case: Raum ohne Gegner direkt clearen
	if enemies_alive == 0:
		_clear_room()

func _random_spawn_pos() -> Vector2:
	# Gegner nicht zu nah am Spieler (der unten startet) spawnen
	var x := randf_range(spawn_margin, ROOM_WIDTH - spawn_margin)
	var y := randf_range(spawn_margin, ROOM_HEIGHT * 0.6)  # Obere 60% des Raums
	return Vector2(x, y)

func _spawn_enemy(type: int, pos: Vector2, is_boss: bool) -> void:
	var enemy := enemy_scene.instantiate()
	enemy.enemy_type = type
	enemy.player_ref = player_ref
	enemy.position = pos
	
	if is_boss:
		enemy.max_health = 15
		enemy.move_speed = 90.0
		enemy.contact_damage = 2
	
	enemy.died.connect(_on_enemy_died)
	enemies_container.add_child(enemy)

func _on_enemy_died(_enemy: Enemy) -> void:
	enemies_alive -= 1
	if enemies_alive <= 0 and not cleared:
		_clear_room()

func _clear_room() -> void:
	cleared = true
	# Obere Wand-Kollision deaktivieren damit der Spieler durchlaufen kann
	$Walls/WallTopCol.set_deferred("disabled", true)
	# Tür öffnet sich visuell
	var tween := create_tween()
	tween.tween_property(exit_door, "modulate", Color(0.3, 1.0, 0.4), 0.4)
	room_cleared.emit()
