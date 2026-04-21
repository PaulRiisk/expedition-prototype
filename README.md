# Blockshooter – Patchnotes zum Prototypen für Version 1.0

## Was ist passiert

### 1. Versuchszähler (oben rechts)
- Zeigt "Versuch: X" direkt unter "Raum Y / 15".
- Zählt **bei ENTER im GAME-OVER-Screen** hoch (manuell bei Restart-Taste).
- Wird **zurückgesetzt** bei: Sieg, Moduswechsel (TAB im Startraum).
- Nur pro Session (keine Save-Datei). Technisch: gespeichert auf dem SceneTree
  per `set_meta`, überlebt damit `reload_current_scene()`.

### 2. Lila Projektile für Fächerschützen (Gegner 3)
- `projectile.setup()` akzeptiert einen optionalen Farbparameter.
- Spread-Gegner (und Boss 2) schießen jetzt lila statt orange.
- `player.gd` funktioniert unverändert, da der neue Parameter optional ist.

### 3. Endscreen mit Modus-Info
- Sieg: `"Gewonnen nach X Versuch(en) im Modus A/B!"`
- Tod: `"Du bist in Raum X gefallen (Versuch Y, Modus A/B)"`

### 4. 15 Räume, 2 Bosse
- Boss 1: Raum 10 (wie bisher – Charge-Attacke).
- Räume 11–14: neue Schwierigkeitskurve (steigende Wellen mit Fächerschützen).
- Boss 2: Raum 15 = Boss 1 **plus** 5-Projektil-Fächerschuss alle ~1.6s, 45 HP,
  dunkel-lila visuell unterscheidbar. Schießt während des Charges NICHT
  (verhindert unfaire Situationen).

### 5. Anti-Glitch (Gegner ineinander)
Zwei Mechanismen kombiniert:
- **Separation-Steering im `_physics_process`**: jeder Gegner bekommt einen
  sanften Abstoßungsvektor von Nachbarn im Radius 44px. Löst das Problem,
  dass Gegner, die alle zum Spieler wollen, sich ineinander drücken.
- **Spawn-Abstand**: neue Gegner spawnen nur, wenn sie ≥56px von jedem
  bereits existierenden Gegner entfernt sind (plus ≥150px vom Spieler).
  Verhindert initiales Überlappen.

Während des Boss-Charges ist Separation deaktiviert, damit der Charge
nicht verzerrt wird.

### 6. Death- und Hit-Partikel (Bonus)
- Gegner-Tod: 9 kleine Quadrate in Gegnerfarbe fliegen auseinander,
  faden aus (Boss: 14 Partikel, größer).
- Projektil-Treffer: 5 kleine Quadrate in Projektilfarbe spritzen.
- Alles mit `ColorRect` + `Tween`, keine externen Assets nötig.

### 7. Desktop-Icon (`icon.svg`)
Blockshooter-Motiv: blauer Spieler-Block in der Mitte, rote/orange/lila
Gegnerblöcke in den Ecken, ein paar Projektile, passendes Grid. In Godot
einstellen via:

	Project Settings → Application → Config → Icon → res://icon.svg

Für exportierte EXE: Export-Preset → Resources → Icon ebenfalls auf
`res://icon.svg` setzen (Godot rendert es automatisch in die passenden
Plattformgrößen).

### Features
- Spieler bewegt sich mit WASD
- Schießt automatisch nur wenn stillstehend (Kern-Mechanik)
- Zielt auf nächsten Gegner
- Nahkämpfer (rot) und Fernkämpfer (orange)
- Raumkette (10 Räume, letzter = Boss)
- Raumwechsel nach oben durch offene Tür
- HP-System mit 5 Leben und I-Frames nach Treffer
- Game Feel: Hit-Flash, Screen-Shake, Blink bei I-Frames
- Game Over + Win Screen + Neustart
- Schwierigkeits-Skalierung über Räume

