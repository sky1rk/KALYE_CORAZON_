@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_autoload_singleton("GameOnPortal", "res://addons/game_on/game_on_connect.gd")
	
	if not ProjectSettings.has_setting("game_on/api_url"):
		ProjectSettings.set_setting("game_on/api_url", "https://staging.gameonportal.ph")
		ProjectSettings.set_initial_value("game_on/api_url", "https://staging.gameonportal.ph")
		ProjectSettings.add_property_info({
			"name": "game_on/api_url",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": ""
		})
	
	if not ProjectSettings.has_setting("game_on/game_id"):
		ProjectSettings.set_setting("game_on/game_id", "")
		ProjectSettings.set_initial_value("game_on/game_id", "")
		ProjectSettings.add_property_info({
			"name": "game_on/game_id",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": ""
		})
	
	ProjectSettings.save()


func _exit_tree() -> void:
	remove_autoload_singleton("GameOnPortal")
