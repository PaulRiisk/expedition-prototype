# Expedition 299 – Prototyp

Erster spielbarer Build zum Testen der Kernmechanik.

## Setup

1. Godot 4.3+ starten, "Importieren" → Ordner auswählen
2. F5 drücken → läuft

Kein Autoload, keine Plugins, nichts manuell zu konfigurieren.

## Steuerung

| Taste | Aktion |
|-------|--------|
| WASD / Pfeiltasten | Bewegen |
| Still stehen | Automatisches Schießen auf nächsten Gegner |
| ENTER | Neustart nach Game Over |

## Ziel des Prototyps

Die eine Frage beantworten:
> **Macht es Spaß, stillzustehen um zu schießen und sich zu bewegen um auszuweichen?**

## Was drin ist

- ✅ Spieler bewegt sich mit WASD
- ✅ Schießt automatisch nur wenn stillstehend (Kern-Mechanik)
- ✅ Zielt auf nächsten Gegner
- ✅ Nahkämpfer (rot) und Fernkämpfer (orange)
- ✅ Raumkette (10 Räume, letzter = Boss)
- ✅ Raumwechsel nach oben durch offene Tür
- ✅ HP-System mit 5 Leben und I-Frames nach Treffer
- ✅ Game Feel: Hit-Flash, Screen-Shake, Blink bei I-Frames
- ✅ Game Over + Win Screen + Neustart
- ✅ Schwierigkeits-Skalierung über Räume

## Was bewusst NICHT drin ist

- ❌ Hub / Menüs
- ❌ Progression, Items, Währung
- ❌ In-Level Fähigkeiten (kommt in die Basisversion)
- ❌ Sound / Musik
- ❌ Hübsche Grafik – bewusst geometrische Formen
- ❌ Controller-Support

## Tuning

Alle wichtigen Werte sind Export-Variablen, also im Godot-Inspector änderbar
ohne Code anzufassen:

**Spieler** (`player.gd` → Inspector bei `Player`-Node in der Player-Scene):
- `move_speed` – Bewegungsgeschwindigkeit
- `max_health` – Startleben
- `shoot_interval` – Sekunden zwischen Schüssen
- `projectile_speed` – Wie schnell Projektile fliegen
- `invincibility_time` – I-Frame-Dauer nach Treffer

**Gegner** (in `enemy.gd` verändert – betrifft alle Gegner):
- `move_speed`, `max_health`, `contact_damage`
- `shoot_interval` (nur Fernkämpfer)
- `ranged_keep_distance` (Abstand den Fernkämpfer halten)

**Raum-Progression** (in `game.gd`, Funktion `_load_room`):
- Wie viele Gegner in welchem Raum spawnen
- Wann Fernkämpfer dazu kommen
- `total_rooms` – Gesamt-Raumzahl (Standard: 10)

## Was ich empfehle zu testen

1. **Erste Runde:** Spielen wie die Parameter sind. Einfach erfahren wie sich das anfühlt.
2. **Zweite Runde:** `shoot_interval` mal auf 0.2 stellen (schnelleres Schießen) – fühlt sich besser an?
3. **Dritte Runde:** `move_speed` auf 350 – zu schnell? Zu träge bei 200?
4. **Freund dazu holen:** Blind spielen lassen ohne Erklärung. Verstehen sie die Mechanik intuitiv?

Das Ziel ist das richtige "Feel" zu finden. Wenn es sich nach 3-4 Tuning-Runden
immer noch nicht gut anfühlt, ist das ein wichtiges Signal – nicht zum Aufgeben,
sondern zum Hinterfragen was fehlt (z.B. Dodge-Roll? Bessere Telegraphierung?).

## Struktur

```
expedition-prototype/
├── project.godot              # Projektkonfig + Input-Mappings
├── scenes/
│   ├── game.tscn             # Hauptszene
│   ├── player.tscn
│   ├── enemy.tscn
│   ├── projectile.tscn
│   └── room.tscn
└── scripts/
    ├── game.gd               # Raumkette, UI, Game Over
    ├── player.gd             # Bewegung, Auto-Aim, Schießen, HP
    ├── enemy.gd              # Nah- und Fernkämpfer
    ├── projectile.gd         # Shared für Spieler + Gegner
    ├── room.gd               # Einzelner Raum mit Gegnerspawn
    └── camera.gd             # Screen-Shake
```
