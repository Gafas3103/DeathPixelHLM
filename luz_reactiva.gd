extends Light3D

## Ejemplo vivo de "cambiar una propiedad de luz por código" (Sesión 17).
## Alterna light_color entre dos colores cada cierto tiempo, con Tween para
## que la transición se vea suave en vez de un salto brusco — la misma idea
## de Efectos.flash() de la Sesión 11, escrita aparte para no depender de
## esa clase en este proyecto.

@export var color_normal: Color = Color.WHITE
@export var color_alerta: Color = Color(1.0, 0.15, 0.15)
@export var intervalo: float = 1.5


func _ready() -> void:
	var temporizador := Timer.new()
	temporizador.wait_time = intervalo
	temporizador.autostart = true
	add_child(temporizador)
	temporizador.timeout.connect(_parpadear)


func _parpadear() -> void:
	var tween := create_tween()
	tween.tween_property(self, "light_color", color_alerta, 0.3)
	tween.tween_property(self, "light_color", color_normal, 0.3)
