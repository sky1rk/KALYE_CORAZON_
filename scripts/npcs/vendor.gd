extends CharacterBody2D

@export var interaction_enabled := true
@export_file("*.tscn") var table_scene_path := "res://scenes/minigames/table.tscn"

@onready var area: Area2D = $EncounterArea
@onready var prompt: Label = $Label
@onready var animated_sprite: AnimatedSprite2D = $CharacterBody2D

var player_near = false

func _ready():
	prompt.hide()
	_play_idle_animation()

	if not interaction_enabled:
		area.monitoring = false
		return

	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if _is_player(body):
		player_near = true
		prompt.show()

func _on_body_exited(body):
	if _is_player(body):
		player_near = false
		prompt.hide()

func _process(_delta):
	if player_near and Input.is_action_just_pressed("interact"):
		interact()

func interact():
	player_near = false
	prompt.hide()
	get_tree().change_scene_to_file(table_scene_path)


func _is_player(body: Node) -> bool:
	return body.is_in_group("Player") or body.is_in_group("player") or body.name == "player" or body.name == "Caleb"


func _play_idle_animation() -> void:
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("idle"):
		animated_sprite.play("idle")


func _on_encounter_area_body_entered(body: Node2D) -> void:
	pass # Replace with function body.
