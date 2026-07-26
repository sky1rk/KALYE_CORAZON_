extends Node2D

@onready var text_label = $ReflectionText
@onready var door = $DoorClose

var reflection = [
	"But somewhere along the way...", 
	"I forgot to appreciate the place helping me get there.", 
	"And today...",
	"Something feels... different."
]

var current = 0

func _ready():
	text_label.hide()
	door.play()
	show_next()

func show_next():

	if current >= reflection.size():
		get_tree().change_scene_to_file("res://scenes/levels/startscreen.tscn")
		return

	text_label.show()
	text_label.text = reflection[current]
	text_label.modulate.a = 0

	var tween = create_tween()

	tween.tween_property(text_label, "modulate:a", 1.0, 0.5)
	tween.tween_interval(2.0)
	tween.tween_property(text_label, "modulate:a", 0.0, 0.5)

	await tween.finished

	current += 1

	show_next()
