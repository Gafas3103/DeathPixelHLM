class_name AnimNames
extends RefCounted

## Reproduce animaciones sin depender del nombre exacto: prueba una lista de candidatos y usa el primero que exista.

## primer nombre de la lista que exista, o ""
static func resolve(sprite: AnimatedSprite2D, candidates: Array) -> String:
	if sprite == null or sprite.sprite_frames == null:
		return ""
	for c in candidates:
		var n := String(c)
		if sprite.sprite_frames.has_animation(n):
			return n
	return ""

## reproduce la primera disponible, true si pudo
static func play(sprite: AnimatedSprite2D, candidates: Array) -> bool:
	var n := resolve(sprite, candidates)
	if n == "":
		return false
	if sprite.animation != n or not sprite.is_playing():
		sprite.play(n)
	return true

# nombres estándar; si usan otro, agrégalo aquí

const IDLE := ["idle", "Idle", "Stop", "stop", "Quieto", "quieto"]
const WALK := ["walk", "Walk", "Move", "move", "run", "Run", "Caminar", "caminar"]
const SHOOT := ["shoot", "Shoot", "Attack", "attack", "disparo", "Disparo", "Disparar"]
const DEAD := ["dead", "Dead", "die", "Die", "Muerte", "muerte", "Muerto"]
