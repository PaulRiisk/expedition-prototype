extends Camera2D

## ================================================================
## KAMERA – mit Screen-Shake für Game Feel
## ================================================================

var shake_strength: float = 0.0
var shake_duration: float = 0.0
var shake_decay: float = 5.0

var original_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	original_offset = offset

func _process(delta: float) -> void:
	if shake_duration > 0.0:
		shake_duration -= delta
		var current_strength: float = shake_strength * (shake_duration / max(shake_duration + delta, 0.001))
		offset = original_offset + Vector2(
			randf_range(-current_strength, current_strength),
			randf_range(-current_strength, current_strength)
		)
	else:
		offset = original_offset

## Wird von außen aufgerufen (z.B. wenn der Spieler getroffen wird)
func shake(strength: float, duration: float) -> void:
	shake_strength = maxf(shake_strength, strength)
	shake_duration = maxf(shake_duration, duration)
