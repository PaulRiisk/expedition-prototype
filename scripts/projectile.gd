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

## Optionale Farb-Override (für z.B. lila Fächerschütze-Projektile).
## Wenn null, wird die Default-Farbe je nach Herkunft verwendet.
var color_override: Variant = null

@onready var sprite: ColorRect = $Sprite

## Wird beim Spawnen vom Schützen aufgerufen
func setup(dir: Vector2, spd: float, dmg: int, from_player: bool, color: Variant = null) -> void:
	direction = dir.normalized()
	speed = spd
	damage = dmg
	is_player_projectile = from_player
	color_override = color

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
	
	# Farb-Override (z.B. für SPREAD-Gegner → lila Projektile)
	if color_override != null:
		modulate = color_override
	
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
	_spawn_hit_particles()
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	# Falls Gegner als Area2D umgesetzt werden
	if area.has_method("take_damage"):
		area.take_damage(damage)
		_spawn_hit_particles()
		queue_free()

## Kleine Treffer-Partikel in der Farbe des Projektils
func _spawn_hit_particles() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var particle_color: Color = modulate
	for i in range(5):
		var p := ColorRect.new()
		p.size = Vector2(4, 4)
		p.color = particle_color
		p.position = global_position - Vector2(2, 2)
		p.z_index = 20
		parent.add_child(p)
		
		var angle: float = randf() * TAU
		var dist: float = randf_range(10.0, 22.0)
		var target: Vector2 = p.position + Vector2(cos(angle), sin(angle)) * dist
		
		var tween := p.create_tween()
		tween.set_parallel(true)
		tween.tween_property(p, "position", target, 0.25)
		tween.tween_property(p, "modulate:a", 0.0, 0.25)
		tween.chain().tween_callback(p.queue_free)
