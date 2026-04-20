extends Node2D

## ================================================================
## GAME – Hauptscript mit Startraum und Steuerungswechsel
## ================================================================

@export var total_rooms: int = 10

## Offset: Raum wird zentriert im 1280x720 Viewport
const ROOM_OFFSET: Vector2 = Vector2(136, 96)

var current_room_number: int = 0  ## 0 = Startraum
var current_room: Room = null
var player: Player = null
var game_ended: bool = false

var player_scene: PackedScene = preload("res://scenes/player.tscn")
var room_scene: PackedScene = preload("res://scenes/room.tscn")

## UI-Referenzen
@onready var hp_label: Label = $UI/HPLabel
@onready var room_label: Label = $UI/RoomLabel
@onready var hint_label: Label = $UI/HintLabel
@onready var control_label: Label = $UI/ControlLabel
@onready var end_screen: Control = $UI/EndScreen
@onready var end_title: Label = $UI/EndScreen/Panel/VBox/Title
@onready var end_info: Label = $UI/EndScreen/Panel/VBox/Info
@onready var camera: Camera2D = $Camera

@onready var room_container: Node2D = $RoomContainer

func _ready() -> void:
	randomize()
	camera.add_to_group("camera")
	end_screen.visible = false
	
	# RoomContainer Offset: Raum zentriert
	room_container.position = ROOM_OFFSET
	
	_spawn_player()
	_load_room(0)  # Startraum

func _process(_delta: float) -> void:
	if game_ended and Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()

func _input(event: InputEvent) -> void:
	# Steuerungswechsel nur im Startraum
	if current_room_number == 0 and not game_ended:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_TAB:
				_toggle_control_mode()

func _spawn_player() -> void:
	player = player_scene.instantiate()
	player.position = Vector2(Room.ROOM_WIDTH / 2, Room.ROOM_HEIGHT - 60)
	player.health_changed.connect(_on_health_changed)
	player.died.connect(_on_player_died)
	room_container.add_child(player)

func _load_room(room_num: int) -> void:
	if current_room != null:
		current_room.queue_free()
		current_room = null
	
	current_room_number = room_num
	var room := room_scene.instantiate()
	room.room_number = room_num
	room.total_rooms = total_rooms
	
	if room_num == 0:
		## ===== STARTRAUM =====
		room.is_start_room = true
		room.is_boss_room = false
		room.num_melee_enemies = 0
		room.num_ranged_enemies = 0
		room.num_spread_enemies = 0
		hint_label.text = "TAB = Steuerung wechseln | Nach oben gehen = Start"
		_update_control_label()
	elif room_num == total_rooms:
		## ===== BOSS =====
		room.is_boss_room = true
		room.num_melee_enemies = 0
		room.num_ranged_enemies = 0
		room.num_spread_enemies = 0
		hint_label.text = ""
	else:
		## ===== NORMALE RÄUME =====
		room.is_boss_room = false
		hint_label.text = ""
		_configure_room_difficulty(room, room_num)
	
	room.set_player(player)
	room.room_cleared.connect(_on_room_cleared)
	room_container.add_child(room)
	current_room = room
	
	player.position = Vector2(Room.ROOM_WIDTH / 2, Room.ROOM_HEIGHT - 60)
	_update_room_label()
	
	# Startraum: direkt auf Spieler warten (kein room_cleared Signal nötig)
	if room_num == 0:
		_wait_for_player_to_exit()

## =========================================================
## SCHWIERIGKEITSKURVE
## =========================================================
func _configure_room_difficulty(room: Room, num: int) -> void:
	if num <= 2:
		# Einstieg: nur Nahkämpfer
		room.num_melee_enemies = 3
		room.num_ranged_enemies = 0
		room.num_spread_enemies = 0
	elif num <= 4:
		# Fernkämpfer kommen dazu
		room.num_melee_enemies = 3
		room.num_ranged_enemies = 1
		room.num_spread_enemies = 0
	elif num <= 5:
		# Lila Fächer-Schützen kommen dazu
		room.num_melee_enemies = 3
		room.num_ranged_enemies = 1
		room.num_spread_enemies = 1
	elif num <= 7:
		# Voller Mix
		room.num_melee_enemies = 3
		room.num_ranged_enemies = 3
		room.num_spread_enemies = 1
		room.wave2_melee = 2
		room.wave2_ranged = 3
	elif num <= 9:
		# Hart: viele Gegner + Welle 2 mit Fächer
		room.num_melee_enemies = 4
		room.num_ranged_enemies = 2
		room.num_spread_enemies = 1
		room.wave2_melee = 3
		room.wave2_ranged = 1
		room.wave2_spread = 2
	else:
		# Raum 10+: Extra hart
		room.num_melee_enemies = 5
		room.num_ranged_enemies = 2
		room.num_spread_enemies = 2
		room.wave2_melee = 3
		room.wave2_spread = 2

func _on_room_cleared() -> void:
	if current_room.is_boss_room:
		hint_label.text = "BOSS BESIEGT!"
		await get_tree().create_timer(0.8).timeout
		_show_win_screen()
	else:
		hint_label.text = "Raum geschafft! Nach oben laufen für nächsten Raum."
		_wait_for_player_to_exit()

func _wait_for_player_to_exit() -> void:
	while current_room != null and current_room.cleared and not game_ended:
		await get_tree().process_frame
		if game_ended or player == null or player.is_dead():
			return
		if player.position.y < 30:
			_next_room()
			return

func _next_room() -> void:
	hint_label.text = ""
	control_label.visible = false
	_load_room(current_room_number + 1)

## --- Steuerungswechsel ---
func _toggle_control_mode() -> void:
	if player.control_mode == Player.ControlMode.AUTO_AIM:
		player.control_mode = Player.ControlMode.MOUSE_AIM
	else:
		player.control_mode = Player.ControlMode.AUTO_AIM
	_update_control_label()

func _update_control_label() -> void:
	control_label.visible = true
	if player.control_mode == Player.ControlMode.AUTO_AIM:
		control_label.text = "Modus A: Stehen = Auto-Schießen | Bewegen = Ausweichen"
	else:
		control_label.text = "Modus B: WASD + Maus zielen & schießen (Linksklick)"

## --- UI ---
func _on_health_changed(current: int, maximum: int) -> void:
	var hearts := ""
	for i in range(current):
		hearts += "♥ "
	for i in range(current, maximum):
		hearts += "♡ "
	hp_label.text = "HP: " + hearts

func _update_room_label() -> void:
	if current_room_number == 0:
		room_label.text = "START"
	elif current_room_number == total_rooms:
		room_label.text = "BOSS"
	else:
		room_label.text = "Raum %d / %d" % [current_room_number, total_rooms]

func _on_player_died() -> void:
	if game_ended:
		return
	game_ended = true
	end_title.text = "GAME OVER"
	end_title.modulate = Color(1.0, 0.3, 0.3)
	end_info.text = "Du bist in Raum %d gefallen.\n\nENTER für Neustart" % current_room_number
	end_screen.visible = true
	camera.shake(16.0, 0.5)

func _show_win_screen() -> void:
	if game_ended:
		return
	game_ended = true
	end_title.text = "EXPEDITION ERFOLGREICH"
	end_title.modulate = Color(0.4, 1.0, 0.5)
	end_info.text = "Du hast alle %d Räume überstanden!\n\nENTER für Neustart" % total_rooms
	end_screen.visible = true
