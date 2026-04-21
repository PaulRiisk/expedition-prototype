extends Node2D
class_name Room

## ================================================================
## RAUM – Grid-basiert, 21x11 Zellen à 48px
## ================================================================

signal room_cleared

## Grid-Konstanten
const CELL_SIZE: float = 48.0
const GRID_COLS: int = 21
const GRID_ROWS: int = 11
const ROOM_WIDTH: float = GRID_COLS * CELL_SIZE   # 1008
const ROOM_HEIGHT: float = GRID_ROWS * CELL_SIZE  # 528
const WALL_THICKNESS: float = 16.0

## ----- Konfiguration (wird von game.gd gesetzt) -----
@export var num_melee_enemies: int = 2
@export var num_ranged_enemies: int = 0
@export var num_spread_enemies: int = 0   ## Neuer Typ: Lila Fächer-Schütze
@export var is_boss_room: bool = false
@export var is_boss2_room: bool = false   ## Boss 2 (Level 15)
@export var is_start_room: bool = false   ## Startraum ohne Gegner
@export var room_number: int = 1
@export var total_rooms: int = 15

## ----- Wellen-System -----
@export var wave2_melee: int = 0
@export var wave2_ranged: int = 0
@export var wave2_spread: int = 0
@export var wave2_delay: float = 1.5

## ----- Spawn-Delay -----
@export var enemy_spawn_delay: float = 0.35

## Mindestabstand zum Spieler beim Spawnen (in Pixeln)
var min_player_distance: float = 150.0
## Mindestabstand zu anderen bereits gespawnten Gegnern
var min_enemy_distance: float = 56.0

var enemies_alive: int = 0
var cleared: bool = false
var wave2_triggered: bool = false
var player_ref: Node2D = null

var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")

@onready var exit_door: ColorRect = $ExitDoor
@onready var enemies_container: Node = $Enemies
@onready var grid_lines_node: Node2D = $GridLines

func _ready() -> void:
	exit_door.modulate = Color(0.4, 0.2, 0.2)
	_draw_grid()
	
	if is_start_room:
		# Startraum: Tür sofort offen, keine Gegner
		cleared = true
		$Walls/WallTopCol.set_deferred("disabled", true)
		exit_door.modulate = Color(0.3, 1.0, 0.4)
	else:
		call_deferred("_spawn_enemies")

func set_player(p: Node2D) -> void:
	player_ref = p

## Zeichnet subtile Grid-Linien auf den Boden
func _draw_grid() -> void:
	# Vertikale Linien
	for col in range(1, GRID_COLS):
		var line := ColorRect.new()
		line.position = Vector2(col * CELL_SIZE, 0)
		line.size = Vector2(1, ROOM_HEIGHT)
		line.color = Color(0.18, 0.18, 0.25, 0.3)
		grid_lines_node.add_child(line)
	# Horizontale Linien
	for row in range(1, GRID_ROWS):
		var line := ColorRect.new()
		line.position = Vector2(0, row * CELL_SIZE)
		line.size = Vector2(ROOM_WIDTH, 1)
		line.color = Color(0.18, 0.18, 0.25, 0.3)
		grid_lines_node.add_child(line)

func _spawn_enemies() -> void:
	if player_ref == null:
		await get_tree().create_timer(0.05).timeout
		if player_ref == null:
			return
	
	if is_boss_room:
		# Boss 1 oder Boss 2 (abhängig vom Flag)
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
	for i in range(num_spread_enemies):
		_spawn_enemy(Enemy.EnemyType.SPREAD, _random_spawn_pos(), false)
		enemies_alive += 1
	
	if enemies_alive == 0:
		_clear_room()

## Spawn auf Grid-Zellen, mit Abstand zum Spieler UND zu anderen Gegnern.
## Verhindert, dass Gegner direkt aufeinander spawnen (sonst glitchen sie ineinander).
func _random_spawn_pos() -> Vector2:
	var local_player_pos: Vector2 = Vector2.ZERO
	if player_ref != null:
		local_player_pos = to_local(player_ref.global_position)
	
	# Positionen bereits gespawnter Gegner in diesem Raum (lokal)
	var existing_positions: Array[Vector2] = []
	for child in enemies_container.get_children():
		if child is Node2D:
			existing_positions.append(child.position)
	
	for attempt in range(40):
		var col: int = randi_range(3, GRID_COLS - 3)
		var row: int = randi_range(3, GRID_ROWS - 3)
		var pos := Vector2(
			col * CELL_SIZE + CELL_SIZE / 2.0,
			row * CELL_SIZE + CELL_SIZE / 2.0
		)
		
		# Abstand zum Spieler
		if player_ref != null:
			if pos.distance_to(local_player_pos) < min_player_distance:
				continue
		
		# Abstand zu anderen Gegnern
		var too_close: bool = false
		for other_pos in existing_positions:
			if pos.distance_to(other_pos) < min_enemy_distance:
				too_close = true
				break
		if too_close:
			continue
		
		return pos
	
	# Fallback: Mitte des Raums (leicht versetzt, damit nicht alle exakt auf einem Punkt landen)
	return Vector2(
		ROOM_WIDTH / 2.0 + randf_range(-40.0, 40.0),
		ROOM_HEIGHT / 2.0 + randf_range(-40.0, 40.0)
	)

func _spawn_enemy(type: int, pos: Vector2, boss: bool) -> void:
	var enemy := enemy_scene.instantiate()
	enemy.enemy_type = type
	enemy.player_ref = player_ref
	enemy.position = pos
	enemy.spawn_delay = enemy_spawn_delay
	
	if boss:
		enemy.is_boss = true
		if is_boss2_room:
			# Boss 2: Boss 1 + Fächerschuss + mehr HP
			enemy.is_boss2 = true
			enemy.max_health = 45
			enemy.move_speed = 100.0
			enemy.contact_damage = 1
		else:
			# Boss 1
			enemy.max_health = 30
			enemy.move_speed = 110.0
			enemy.contact_damage = 1
	
	enemy.died.connect(_on_enemy_died)
	enemies_container.add_child(enemy)

func _on_enemy_died(_enemy: Enemy) -> void:
	enemies_alive -= 1
	
	if enemies_alive <= 0 and not wave2_triggered and (wave2_melee > 0 or wave2_ranged > 0 or wave2_spread > 0):
		wave2_triggered = true
		_spawn_wave_2()
		return
	
	if enemies_alive <= 0 and not cleared:
		_clear_room()

func _spawn_wave_2() -> void:
	await get_tree().create_timer(wave2_delay).timeout
	
	for i in range(wave2_melee):
		_spawn_enemy(Enemy.EnemyType.MELEE, _random_spawn_pos(), false)
		enemies_alive += 1
	for i in range(wave2_ranged):
		_spawn_enemy(Enemy.EnemyType.RANGED, _random_spawn_pos(), false)
		enemies_alive += 1
	for i in range(wave2_spread):
		_spawn_enemy(Enemy.EnemyType.SPREAD, _random_spawn_pos(), false)
		enemies_alive += 1
	
	if enemies_alive <= 0:
		_clear_room()

func _clear_room() -> void:
	cleared = true
	$Walls/WallTopCol.set_deferred("disabled", true)
	var tween := create_tween()
	tween.tween_property(exit_door, "modulate", Color(0.3, 1.0, 0.4), 0.4)
	room_cleared.emit()
