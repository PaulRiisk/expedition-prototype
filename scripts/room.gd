extends Node2D
class_name Room

## ================================================================
## RAUM – ein einzelner Kampfraum
## ================================================================
## Spawnt Gegner in Wellen, wartet bis alle tot sind, öffnet dann die Tür.

signal room_cleared

## Raumgrenzen (müssen mit Wänden im Scene-Setup matchen)
const ROOM_WIDTH: float = 1100.0
const ROOM_HEIGHT: float = 600.0

## ----- Konfiguration (wird von game.gd gesetzt) -----
@export var num_melee_enemies: int = 2
@export var num_ranged_enemies: int = 0
@export var is_boss_room: bool = false
@export var room_number: int = 1
@export var total_rooms: int = 10

## ----- Wellen-System -----
@export var wave2_melee: int = 0      ## 2. Welle Nahkämpfer (0 = keine 2. Welle)
@export var wave2_ranged: int = 0     ## 2. Welle Fernkämpfer
@export var wave2_delay: float = 1.5  ## Sekunden nach dem letzten Kill der 1. Welle

## ----- Spawn-Delay -----
@export var enemy_spawn_delay: float = 0.15  ## Gegner warten kurz bevor sie aktiv werden

## Spawn-Bereich
var spawn_margin: float = 60.0
## Mindestabstand zum Spieler beim Spawnen
var min_player_distance: float = 150.0

var enemies_alive: int = 0
var cleared: bool = false
var wave: int = 1
var wave2_triggered: bool = false
var player_ref: Node2D = null

var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")

@onready var exit_door: ColorRect = $ExitDoor
@onready var enemies_container: Node = $Enemies

func _ready() -> void:
	exit_door.modulate = Color(0.4, 0.2, 0.2)
	call_deferred("_spawn_enemies")

func set_player(p: Node2D) -> void:
	player_ref = p

func _spawn_enemies() -> void:
	if player_ref == null:
		await get_tree().create_timer(0.05).timeout
		if player_ref == null:
			return
	
	# Boss-Raum
	if is_boss_room:
		_spawn_enemy(Enemy.EnemyType.MELEE, _random_spawn_pos(), true)
		enemies_alive += 1
		return
	
	# Welle 1
	for i in range(num_melee_enemies):
		_spawn_enemy(Enemy.EnemyType.MELEE, _random_spawn_pos(), false)
		enemies_alive += 1
	
	for i in range(num_ranged_enemies):
		_spawn_enemy(Enemy.EnemyType.RANGED, _random_spawn_pos(), false)
		enemies_alive += 1
	
	if enemies_alive == 0:
		_clear_room()

## Spawn-Position: überall im Raum AUSSER zu nah am Spieler
func _random_spawn_pos() -> Vector2:
	var attempts: int = 0
	while attempts < 20:
		var x := randf_range(spawn_margin, ROOM_WIDTH - spawn_margin)
		var y := randf_range(spawn_margin, ROOM_HEIGHT - spawn_margin)
		var pos := Vector2(x, y)
		
		# Prüfe Abstand zum Spieler
		if player_ref != null:
			var dist: float = pos.distance_to(player_ref.position)
			if dist >= min_player_distance:
				return pos
		else:
			return pos
		attempts += 1
	
	# Fallback: oben im Raum
	return Vector2(randf_range(spawn_margin, ROOM_WIDTH - spawn_margin), spawn_margin + 50)

func _spawn_enemy(type: int, pos: Vector2, boss: bool) -> void:
	var enemy := enemy_scene.instantiate()
	enemy.enemy_type = type
	enemy.player_ref = player_ref
	enemy.position = pos
	enemy.spawn_delay = enemy_spawn_delay
	
	if boss:
		enemy.is_boss = true
		enemy.max_health = 30
		enemy.move_speed = 100.0
		enemy.contact_damage = 2
	
	enemy.died.connect(_on_enemy_died)
	enemies_container.add_child(enemy)

func _on_enemy_died(_enemy: Enemy) -> void:
	enemies_alive -= 1
	
	# Welle 1 geschafft → Welle 2 spawnen falls konfiguriert
	if enemies_alive <= 0 and not wave2_triggered and (wave2_melee > 0 or wave2_ranged > 0):
		wave2_triggered = true
		_spawn_wave_2()
		return
	
	if enemies_alive <= 0 and not cleared:
		_clear_room()

func _spawn_wave_2() -> void:
	wave = 2
	# Kurze Pause bevor die nächste Welle kommt
	await get_tree().create_timer(wave2_delay).timeout
	
	for i in range(wave2_melee):
		_spawn_enemy(Enemy.EnemyType.MELEE, _random_spawn_pos(), false)
		enemies_alive += 1
	
	for i in range(wave2_ranged):
		_spawn_enemy(Enemy.EnemyType.RANGED, _random_spawn_pos(), false)
		enemies_alive += 1
	
	if enemies_alive <= 0:
		_clear_room()

func _clear_room() -> void:
	cleared = true
	$Walls/WallTopCol.set_deferred("disabled", true)
	var tween := create_tween()
	tween.tween_property(exit_door, "modulate", Color(0.3, 1.0, 0.4), 0.4)
	room_cleared.emit()
