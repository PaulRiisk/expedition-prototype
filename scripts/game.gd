extends Node2D

## ================================================================
## GAME – Hauptscript mit Startraum, 15 Räumen, 2 Bossen, Versuchs-Tracking
## ================================================================

@export var total_rooms: int = 15
const BOSS1_ROOM: int = 10
const BOSS2_ROOM: int = 15

## Offset: Raum wird zentriert im 1280x720 Viewport
const ROOM_OFFSET: Vector2 = Vector2(136, 96)

## Keys für den Session-übergreifenden Zustand (überlebt reload_current_scene).
## Gespeichert auf dem SceneTree per set_meta / get_meta.
const META_ATTEMPTS: String = "blockshooter_attempts"
const META_CONTROL_MODE: String = "blockshooter_control_mode"

var current_room_number: int = 0  ## 0 = Startraum
var current_room: Room = null
var player: Player = null
var game_ended: bool = false

## Versuchszähler (aktuelle Session). Start bei 1.
var attempt_number: int = 1

var player_scene: PackedScene = preload("res://scenes/player.tscn")
var room_scene: PackedScene = preload("res://scenes/room.tscn")

## UI-Referenzen
@onready var hp_label: Label = $UI/HPLabel
@onready var room_label: Label = $UI/RoomLabel
@onready var attempt_label: Label = $UI/AttemptLabel
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
	
	# Versuchszähler aus dem SceneTree-Meta holen (überlebt reload_current_scene)
	var tree := get_tree()
	if tree.has_meta(META_ATTEMPTS):
		attempt_number = int(tree.get_meta(META_ATTEMPTS))
	else:
		attempt_number = 1
		tree.set_meta(META_ATTEMPTS, attempt_number)
	
	_spawn_player()
	
	# Vorher gewählten Steuerungsmodus wiederherstellen
	if tree.has_meta(META_CONTROL_MODE):
		player.control_mode = tree.get_meta(META_CONTROL_MODE)
	
	_update_attempt_label()
	_load_room(0)  # Startraum

func _process(_delta: float) -> void:
	if game_ended and Input.is_action_just_pressed("restart"):
		_restart_game()

func _input(event: InputEvent) -> void:
	# Steuerungswechsel nur im Startraum
	if current_room_number == 0 and not game_ended:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_TAB:
				_toggle_control_mode()
			# --- DEBUG-SPRÜNGE (nur im Startraum aktiv) ---
			# F1 = Boss 1, F2 = Boss 2, F3 = Raum 14 (letzter Raum vor Boss 2)
			elif event.keycode == KEY_F1:
				_debug_jump_to(BOSS1_ROOM)
			elif event.keycode == KEY_F2:
				_debug_jump_to(BOSS2_ROOM)
			#elif event.keycode == KEY_F3:
			#	_debug_jump_to(14)

func _debug_jump_to(room_num: int) -> void:
	hint_label.text = ""
	control_label.visible = false
	_load_room(room_num)

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
		hint_label.text = "TAB = Steuerung wechseln | Nach oben gehen = Start" # | F1/F2 = Boss 1/2 (Debug)
		_update_control_label()
	elif room_num == BOSS1_ROOM:
		## ===== BOSS 1 =====
		room.is_boss_room = true
		room.is_boss2_room = false
		room.num_melee_enemies = 0
		room.num_ranged_enemies = 0
		room.num_spread_enemies = 0
		hint_label.text = "BOSS 1"
	elif room_num == BOSS2_ROOM:
		## ===== BOSS 2 (FINALE) =====
		room.is_boss_room = true
		room.is_boss2_room = true
		room.num_melee_enemies = 0
		room.num_ranged_enemies = 0
		room.num_spread_enemies = 0
		hint_label.text = "BOSS 2 – FINALE"
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
## SCHWIERIGKEITSKURVE – jetzt für 15 Räume (Boss 1 @ 10, Boss 2 @ 15)
## =========================================================
func _configure_room_difficulty(room: Room, num: int) -> void:
	if num <= 2:
		# 1–2: Einstieg, nur Nahkämpfer
		room.num_melee_enemies = 3
		room.num_ranged_enemies = 0
		room.num_spread_enemies = 0
	elif num <= 4:
		# 3–4: Fernkämpfer kommen dazu
		room.num_melee_enemies = 3
		room.num_ranged_enemies = 1
		room.num_spread_enemies = 0
	elif num == 5:
		# 5: Lila Fächer-Schützen kommen dazu
		room.num_melee_enemies = 3
		room.num_ranged_enemies = 1
		room.num_spread_enemies = 1
	elif num <= 7:
		# 6–7: Voller Mix + Welle 2
		room.num_melee_enemies = 3
		room.num_ranged_enemies = 3
		room.num_spread_enemies = 1
		room.wave2_melee = 2
		room.wave2_ranged = 3
	elif num == 8 or num == 9:
		# 8–9: Hart, Welle 2 mit Fächer
		room.num_melee_enemies = 4
		room.num_ranged_enemies = 2
		room.num_spread_enemies = 1
		room.wave2_melee = 3
		room.wave2_ranged = 1
		room.wave2_spread = 2
	# Raum 10 = Boss 1 (hier nicht konfiguriert)
	elif num == 11 or num == 12:
		# 11–12: Post-Boss-1, frischer Mix mit angehobener Intensität
		room.num_melee_enemies = 4
		room.num_ranged_enemies = 2
		room.num_spread_enemies = 2
		room.wave2_melee = 2
		room.wave2_ranged = 2
	elif num == 13:
		# 13: Sehr hart
		room.num_melee_enemies = 5
		room.num_ranged_enemies = 2
		room.num_spread_enemies = 2
		room.wave2_melee = 3
		room.wave2_ranged = 2
		room.wave2_spread = 1
	else:
		# 14: Pre-Finale, härtester Raum vor Boss 2
		room.num_melee_enemies = 5
		room.num_ranged_enemies = 3
		room.num_spread_enemies = 3
		room.wave2_melee = 3
		room.wave2_spread = 2

func _on_room_cleared() -> void:
	if current_room.is_boss_room:
		# Nur nach Boss 2 ist das Spiel gewonnen. Boss 1 → nächster Raum.
		if current_room_number == BOSS2_ROOM:
			hint_label.text = "BOSS 2 BESIEGT!"
			await get_tree().create_timer(0.8).timeout
			_show_win_screen()
		else:
			hint_label.text = "Boss besiegt! Nach oben laufen für nächsten Raum."
			_wait_for_player_to_exit()
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
	
	# Moduswechsel = neuer Anlauf → Zähler zurücksetzen.
	# Aber nur, wenn wirklich ein voriger Modus gespeichert war (sonst
	# würde der erste TAB-Druck überhaupt schon resetten).
	var tree := get_tree()
	if tree.has_meta(META_CONTROL_MODE):
		var previous_mode: int = tree.get_meta(META_CONTROL_MODE)
		if previous_mode != player.control_mode:
			attempt_number = 1
			tree.set_meta(META_ATTEMPTS, attempt_number)
			_update_attempt_label()
	tree.set_meta(META_CONTROL_MODE, player.control_mode)
	
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
	elif current_room_number == BOSS1_ROOM:
		room_label.text = "BOSS 1"
	elif current_room_number == BOSS2_ROOM:
		room_label.text = "BOSS 2"
	else:
		room_label.text = "Raum %d / %d" % [current_room_number, total_rooms]

func _update_attempt_label() -> void:
	attempt_label.text = "Versuch: %d" % attempt_number

func _mode_letter() -> String:
	if player != null and player.control_mode == Player.ControlMode.MOUSE_AIM:
		return "B"
	return "A"

func _on_player_died() -> void:
	if game_ended:
		return
	game_ended = true
	end_title.text = "GAME OVER"
	end_title.modulate = Color(1.0, 0.3, 0.3)
	end_info.text = "Du bist in Raum %d gefallen (Versuch %d, Modus %s).\n\nENTER für Neustart" % [current_room_number, attempt_number, _mode_letter()]
	end_screen.visible = true
	camera.shake(16.0, 0.5)

func _show_win_screen() -> void:
	if game_ended:
		return
	game_ended = true
	end_title.text = "GEWONNEN!"
	end_title.modulate = Color(0.4, 1.0, 0.5)
	end_info.text = "Gewonnen nach %d Versuch%s im Modus %s!\n\nENTER für Neustart" % [
		attempt_number,
		"" if attempt_number == 1 else "en",
		_mode_letter()
	]
	end_screen.visible = true
	
	# Nach dem Sieg Zähler zurücksetzen (der nächste Run startet wieder bei 1)
	var tree := get_tree()
	tree.set_meta(META_ATTEMPTS, 1)

## Restart via ENTER im Endscreen.
## Tod  → Zähler +1, Modus bleibt erhalten.
## Sieg → Zähler wurde schon auf 1 gesetzt (siehe _show_win_screen).
func _restart_game() -> void:
	var tree := get_tree()
	var next_attempts: int = 1
	if tree.has_meta(META_ATTEMPTS):
		next_attempts = int(tree.get_meta(META_ATTEMPTS))
	# Unterscheidung: War es ein Tod (Titel "GAME OVER") oder ein Sieg?
	if end_title.text == "GAME OVER":
		next_attempts += 1
	# Bei Sieg bleibt next_attempts = 1 (wurde in _show_win_screen gesetzt).
	tree.set_meta(META_ATTEMPTS, next_attempts)
	# Modus beibehalten (wurde schon beim Toggle gespeichert)
	tree.reload_current_scene()
