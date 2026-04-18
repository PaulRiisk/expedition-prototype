extends Node2D

## ================================================================
## GAME – Hauptscript
## ================================================================
## Verwaltet die Raumkette, den Spieler, UI und Game-Over / Win-Screen.

## ----- Konfiguration -----
@export var total_rooms: int = 10  ## Inklusive Boss-Raum am Ende

## ----- Interne Variablen -----
var current_room_number: int = 1
var current_room: Room = null
var player: Player = null
var game_ended: bool = false

var player_scene: PackedScene = preload("res://scenes/player.tscn")
var room_scene: PackedScene = preload("res://scenes/room.tscn")

## UI-Referenzen
@onready var hp_label: Label = $UI/HPLabel
@onready var room_label: Label = $UI/RoomLabel
@onready var hint_label: Label = $UI/HintLabel
@onready var end_screen: Control = $UI/EndScreen
@onready var end_title: Label = $UI/EndScreen/Panel/VBox/Title
@onready var end_info: Label = $UI/EndScreen/Panel/VBox/Info
@onready var camera: Camera2D = $Camera

## Raum-Container (in der Scene)
@onready var room_container: Node2D = $RoomContainer

func _ready() -> void:
	randomize()
	camera.add_to_group("camera")
	end_screen.visible = false
	hint_label.text = "WASD / Pfeiltasten = Bewegen | Stehen bleiben zum Schießen"
	
	_spawn_player()
	_load_room(current_room_number)

func _process(_delta: float) -> void:
	if game_ended and Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()

## --- Spieler spawnen ---
func _spawn_player() -> void:
	player = player_scene.instantiate()
	# Spieler startet mittig unten im Raum
	player.position = Vector2(Room.ROOM_WIDTH / 2, Room.ROOM_HEIGHT - 80)
	player.health_changed.connect(_on_health_changed)
	player.died.connect(_on_player_died)
	room_container.add_child(player)

## --- Raum laden ---
func _load_room(room_num: int) -> void:
	# Alten Raum entfernen
	if current_room != null:
		current_room.queue_free()
		current_room = null
	
	current_room_number = room_num
	var room := room_scene.instantiate()
	room.room_number = room_num
	room.total_rooms = total_rooms
	room.is_boss_room = (room_num == total_rooms)
	
	# Schwierigkeit skaliert mit Raumnummer
	if room.is_boss_room:
		# Boss-Raum: Nur Boss, keine Standard-Gegner
		room.num_melee_enemies = 0
		room.num_ranged_enemies = 0
	else:
		# Progression: erste Räume einfach, später mehr und gemischter
		if room_num <= 2:
			room.num_melee_enemies = 2
			room.num_ranged_enemies = 0
		elif room_num <= 4:
			room.num_melee_enemies = 2
			room.num_ranged_enemies = 1
		elif room_num <= 6:
			room.num_melee_enemies = 3
			room.num_ranged_enemies = 1
		else:
			room.num_melee_enemies = 3 + (room_num - 7)
			room.num_ranged_enemies = 2
	
	room.set_player(player)
	room.room_cleared.connect(_on_room_cleared)
	room_container.add_child(room)
	current_room = room
	
	# Spieler in den neuen Raum setzen (unten in der Mitte)
	player.position = Vector2(Room.ROOM_WIDTH / 2, Room.ROOM_HEIGHT - 80)
	
	_update_room_label()

func _on_room_cleared() -> void:
	# Hinweis anzeigen dass man zum nächsten Raum gehen kann
	if current_room.is_boss_room:
		hint_label.text = "BOSS BESIEGT!"
		await get_tree().create_timer(0.8).timeout
		_show_win_screen()
	else:
		hint_label.text = "Raum geschafft! Nach oben laufen für nächsten Raum."
		# Wir warten darauf, dass der Spieler nach oben zur Tür läuft
		_wait_for_player_to_exit()

## Prüft ob der Spieler die obere Raumgrenze erreicht hat
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
	_load_room(current_room_number + 1)

## --- UI ---
func _on_health_changed(current: int, maximum: int) -> void:
	var hearts := ""
	for i in range(current):
		hearts += "♥ "
	for i in range(current, maximum):
		hearts += "♡ "
	hp_label.text = "HP: " + hearts

func _update_room_label() -> void:
	if current_room_number == total_rooms:
		room_label.text = "BOSS"
	else:
		room_label.text = "Raum %d / %d" % [current_room_number, total_rooms]

## --- Game Over / Win ---
func _on_player_died() -> void:
	if game_ended:
		return
	game_ended = true
	end_title.text = "GAME OVER"
	end_title.modulate = Color(1.0, 0.3, 0.3)
	end_info.text = "Du bist in Raum %d gefallen.\n\nENTER für Neustart" % current_room_number
	end_screen.visible = true
	
	# Kamera shake final
	camera.shake(16.0, 0.5)

func _show_win_screen() -> void:
	if game_ended:
		return
	game_ended = true
	end_title.text = "EXPEDITION ERFOLGREICH"
	end_title.modulate = Color(0.4, 1.0, 0.5)
	end_info.text = "Du hast alle %d Räume überstanden!\n\nENTER für Neustart" % total_rooms
	end_screen.visible = true
