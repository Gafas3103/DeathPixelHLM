extends Area2D

var can_pickup = false
@onready var prompt = $PromptLabel

func _ready():
	prompt.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.collision_layer & 2 != 0: # Capa del jugador
		can_pickup = true
		prompt.visible = true

func _on_body_exited(body):
	if body.collision_layer & 2 != 0:
		can_pickup = false
		prompt.visible = false

func _process(delta):
	if can_pickup and Input.is_action_just_pressed("action"):
		read_note()

func read_note():
	var ui_scene = preload("res://Scenes/NoteUI.tscn")
	var ui = ui_scene.instantiate()
	get_tree().current_scene.add_child(ui)
	get_tree().paused = true
	queue_free()
