extends Area2D
class_name Projectile

## ================================================================
## PROJEKTIL – wird vom Spieler und von Gegnern verwendet
## ================================================================

var direction: Vector2 = Vector2.RIGHT
var speed: float = 600.0
var damage: int = 1
var is_player_projectile: bool = true
var lifetime: float = 3.0  ## Nach X Sekunden selbst zerstören

@onready var sprite: ColorRect = $Sprite

## Wird beim Spawnen vom Schützen aufgerufen
func setup(dir: Vector2, spd: float, dmg: int, from_player: bool) -> void:
	direction = dir.normalized()
	speed = spd
	damage = dmg
	is_player_projectile = from_player

func _ready() -> void:
	# Collision-Layer je nach Herkunft unterschiedlich
	if is_player_projectile:
		collision_layer = 8   # Layer 4
		collision_mask = 4    # trifft Layer 3: enemy
		modulate = Color(0.6, 0.9, 1.0)
	else:
		collision_layer = 16  # Layer 5
		collision_mask = 2    # trifft Layer 2: player
		modulate = Color(1.0, 0.5, 0.3)
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	# Falls Gegner als Area2D umgesetzt werden
	if area.has_method("take_damage"):
		area.take_damage(damage)
		queue_free()
