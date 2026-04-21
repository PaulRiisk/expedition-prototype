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

