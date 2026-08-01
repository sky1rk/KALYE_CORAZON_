class_name ArtifactSuccess
extends Control

signal back_pressed

@onready var title_label: Label = %Title
@onready var artifact_name_label: Label = %ArtifactName
@onready var artifact_description_label: Label = %ArtifactDescription
@onready var thumbnail_rect: TextureRect = %Thumbnail
@onready var back_button: Button = %BackButton


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	var game_on_connect := get_node(^"/root/GameOnPortal") as GameOnConnect
	show_artifact(game_on_connect.pending_artifact, game_on_connect.pending_is_new_unlock)


func show_artifact(artifact_data: Dictionary, is_new_unlock: bool) -> void:
	if is_new_unlock:
		title_label.text = "Artifact Unlocked!"
	else:
		title_label.text = "Artifact Already Unlocked"
	
	var artifact: Dictionary = artifact_data.get("artifact", {}) as Dictionary
	artifact_name_label.text = artifact.get("name", "Unknown Artifact")
	artifact_description_label.text = artifact.get("description", "")
	
	var thumbnail_url: String = artifact.get("thumbnailUrl", "")
	if not thumbnail_url.is_empty():
		_download_thumbnail(thumbnail_url)


func _download_thumbnail(url: String) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request(url)
	var result: Array = await http.request_completed
	http.queue_free()
	
	if result.is_empty():
		push_error("Failed to download thumbnail: empty response")
		return
	
	var status: int = result[0]
	if status != HTTPRequest.RESULT_SUCCESS:
		push_error("Failed to download thumbnail, status: %d" % status)
		return
	
	var body: PackedByteArray = result[3]
	var image := Image.new()
	var error := image.load_png_from_buffer(body)
	if error != OK:
		error = image.load_jpg_from_buffer(body)
	if error != OK:
		error = image.load_webp_from_buffer(body)
	if error != OK:
		push_error("Failed to load thumbnail image")
		return
	
	var texture := ImageTexture.create_from_image(image)
	thumbnail_rect.texture = texture


func _on_back_pressed() -> void:
	back_pressed.emit()
	get_tree().change_scene_to_file("res://scenes/levels/startscreen.tscn")
