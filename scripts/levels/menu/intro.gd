extends Node2D

@onready var label = $IntroText
@onready var alarm = $AlarmSound

var texts = [
	"Every day feels the same.",
	"Wake up.",
	"Go to class.",
	"Repeat."
]

var current = 0

func _ready():
	label.hide()
	alarm.play()
	show_next()

func show_next():

	if current >= texts.size():
		get_tree().change_scene_to_file("res://scenes/levels/bedroom.tscn")
		return

	label.show()
	label.modulate.a = 0
	label.text = texts[current]

	var tween = create_tween()

	tween.tween_property(label,"modulate:a",1.0,.5)
	tween.tween_interval(1.8)
	tween.tween_property(label,"modulate:a",0,.5)

	await tween.finished

	current += 1

	if current == texts.size()-1:
		alarm.stop()

	show_next()
