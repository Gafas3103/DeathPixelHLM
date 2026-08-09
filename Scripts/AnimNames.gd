class_name AnimNames
extends RefCounted

## Utilidad para reproducir animaciones sin depender del nombre exacto.
##
## Cada quien en el grupo puede haber nombrado las animaciones distinto
## ("idle" / "Stop" / "Quieto"...). En vez de romperse, estas funciones
## prueban una lista de nombres candidatos y usan el primero que exista.

## Devuelve el primer nombre de la lista que exista en el AnimatedSprite2D,
## o "" si no hay ninguno.
static func resolve(sprite: AnimatedSprite2D, candidates: Array) -> String:
	if sprite == null or sprite.sprite_frames == null:
		return ""
	for c in candidates:
		var n := String(c)
		if sprite.sprite_frames.has_animation(n):
			return n
	return ""

## Reproduce la primera animación disponible de la lista.
## Devuelve true si logró reproducir algo.
static func play(sprite: AnimatedSprite2D, candidates: Array) -> bool:
	var n := resolve(sprite, candidates)
	if n == "":
		return false
	if sprite.animation != n or not sprite.is_playing():
		sprite.play(n)
	return true

# --- Listas de nombres estándar del proyecto -------------------------------
# Si tu compañero usó otro nombre, agrégalo aquí y funciona en todo el juego.

const IDLE := ["idle", "Idle", "Stop", "stop", "Quieto", "quieto"]
const WALK := ["walk", "Walk", "Move", "move", "run", "Run", "Caminar", "caminar"]
const SHOOT := ["shoot", "Shoot", "Attack", "attack", "disparo", "Disparo", "Disparar"]
const DEAD := ["dead", "Dead", "die", "Die", "Muerte", "muerte", "Muerto"]
