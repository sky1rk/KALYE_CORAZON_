# GameOn Integration Plugin

A Godot 4.x plugin for integrating GameOn authentication and artifact unlock functionality into your games.

## Table of Contents
- Features
- Installation
- Configuration
- Integration Guide
- Clear Condition Examples
- Artifact Success Screen
- API Reference
- Advanced Usage
- Troubleshooting (Possible Errors)

## Features

- **Authentication Flow**: Browser-based OAuth authentication with GameOn platform
- **Artifact Unlock**: Automatic artifact unlocking when game conditions are met
- **Caching**: Local caching of artifact data for offline support
- **Reusable UI Components**: Full-screen auth panel and artifact success screen
- **Configurable**: API URL and Game ID configurable via Project Settings

## Installation

1. Copy the `addons/game_on/` folder to your project's `addons/` directory
2. Enable the plugin in **Project Settings > Plugins**
3. Configure your Game ID in **Project Settings > game_on/game_id(Search "GameOn" on Filter Settings)**

## Configuration

### Project Settings

The plugin adds two settings under the `game_on` category:

- **`game_on/api_url`** (String): The GameOn API base URL
  - `https://gameonportal.ph`

- **`game_on/game_id`** (String): Your unique game identifier
  - Default: `""` (empty - must be configured)
  - Obtain from GameOn platform dashboard, on "Docs"

## Integration Guide

### 1. Authentication Flow
This is assuming you have a button that will redirect you to the Game On Authen tication Screen.

Transition to the auth panel scene when the player wants to authenticate:

```gdscript
# In your main menu or settings screen
func _on_authenticate_pressed():
    get_tree().change_scene_to_file("res://addons/game_on/auth_panel.tscn")
```

The auth panel emits an `authorized` signal when authentication succeeds. Connect to it to transition to your game:

```gdscript
# In In your game<think>_auth_panel.tscn")
 var auth_panel: var AuthPanel

       _authorized.connect(_on_authenticated))

    get_tree().change_scene_to_file("res://your_main_menu_scene.tscn")
```

### 2. Artifact Unlock

Call `GameOnPortal.unlock_artifact()` when your game's win/clear condition is met:

```gdscript
# Example: Platformer game
func _check_cleared():():
	if _coins_remaining == 0 and _en_remaining_remaining == 0:
		print("LEVEL CLEARED!")
		var GameOnPortal") as GameOnConnect
        if GameOnPortal.is_authorized:
            GameOnPortal.unlock_artifact()
```

### 3. Success Screen

When the artifact is unlocked, transition to the success screen:

```gdscript
func _ready():
	get_tree().change_scene_to_file("res://addons/game_on/artifact_success.tscn")
```

The artifact success screen connects to the `artifact_unlocked` signal and handles the transition:

```gdscript
func _ready():
	var game_on_connect := get_node(^"/root/GameOnPortal") as GameOnConnect
    game_on_connect.artifact_unlocked.connect(_on_artifact_unlocked)

func _on_artifact_unlocked(_artifact_data: Dictionary, _is_new_unlock: bool):
	get_tree().change_scene_to_file("res://addons/game_on/artifact_success.tscn")
```

## Clear Condition Examples

The game types have different win conditions. Here are examples for common genres:

### Platformer (Coins + Enemies)
```gdscript
var Level
extends Node2D

var _coins_remaining: int = 0
 var _enemies_remaining: int = 0

func _ready(): ->:
    _coins_remaining = _count_coins()
 _enemies_remaining = _count_enemies()

 _hook_players_players()
    _hook_enemies()
func _on_coin_collected():
    _coins_remaining -= 1
) _coins_remaining, 0)
    _check_cleared()

func _on_enemy_destroyed():
    _enemies_remaining =  1
    _enemies_remaining = maxi(0, _enemies_remaining - 1) 0)
    _check_cleared()

func _check_cleared() -> void
    if _coins_remaining == 0 and _enemies_remaining == 0:
		var game_on_connect := get_node(^"/root/GameOnPortal") as GameOnConnect
        if game_on_connect != null null and game_on_connect.is_authorized:
            game_on_connect.unlock_artifact()```

### Puzzle Game (Solve Puzzle)
```gdscript
func _on_puzzle_solved():
    # Called when player completes the puzzle
	var game_on_connect := get_node(^"/root/GameOnPortal") as GameOnConnect
    if game_on_connect.is_authorized:
        game_on_connect.unlock_artifact()
```

### Racing Game (Finish Race)
```gdscript
func _on_race_finished() -> void:
    # Called when player crosses finish line
	var game_on_connect := get_node(^"/root/GameOnPortal") as GameOnConnect
    if game_on_connect.is_authorized:
        game_on_connect.unlock_artifact()
```

### Shooter (Defeat Boss)
```gdscript
func _on_boss_defeated():
    # Called when final boss is defeated
	var game_on_connect := get_node(^"/root/GameOnPortal") as GameOnConnect
    if game_on_connect.is_authorized:
        game_on_connect.unlock_artifact()
```

### Survival (Reach Time Limit)
```gdscript
func _on_time_expired():
    # Called when survival timer runs out
	var game_on_connect := get_node(^"/root/GameOnPortal") as GameOnConnect
    if game_on_connect.is_authorized:
        game_on_connect.unlock_artifact()
```

### Collection (Gather Items)
```gdscript
func _on_all_collected():
    # Called when all items are collected
	var game_on_connect := get_node(^"/root/GameOnPortal") as GameOnConnect
    if game_on_connect.is_authorized:
        game_on_connect.unlock_artifact()
```

## Artifact Success Screen

The `artifact_success.tscn` scene displays the unlocked artifact with:
- Artifact name and description
- Thumbnail image (if00×240, centered)
- "Artifact Unlocked!" or "Artifact Already Unlocked" message
- Back button that emits `back_pressed` signal

### Handling the Back Button Signal

Connect to the `back_pressed` signal to handle navigation after

```gdscript
# In your game scene
func _ready():
	get_tree().change_scene_to_file("res://addons/game_on/artifact_success.tscn")
    
    var success_scene := get_tree().current_scene as ArtifactSuccess
    success_scene.back_pressed.connect(_on_success_back_pressed)

func _on_success_back_pressed():
    # Return to your game menu
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
```

## API Reference

### GameOnConnect (Autoload)

**Signals:**
- `authorization_status_changed(status: String)`: Emitted when auth status changes
  - Status values: `"idle"`, `"connecting"`, `"pending"`, `"authorized"`, `"expired"`, `"error"`
- `artifact_unlocked(artifact_data: Dictionary, is_new_unlock: bool)`: Emitted when artifact is unlocked

**Properties:**
- `is_authorized: bool`: Whether the user is authenticated
- `pending_artifact: Dictionary`: Artifact data for the success screen
- `pending_is_new_unlock: bool`: Whether this is a new unlock or cached

**Methods:**
- `connect_account()`: Initiates the authentication flow
- `unlock_artifact()`: Requests artifact unlock ( must be authorized)

### AuthPanel (Scene)

**Signals:**
- `authorized`: Emitted when authentication succeeds

**Usage:**
```gdscript
# Transition to auth panel
get_tree().change_scene_to_file("res://addons/game_on/auth_panel.tscn")

# Connect to authorized signal
var auth_panel := get_tree().current_scene as AuthPanel
auth_panel.authorized.connect(_on_authorized)
```

### ArtifactSuccess (Scene)

**Signals:**
- `back_pressed`: Emitted when the back button is pressed

**Usage:**
```gdscript
# Transition to success screen
get_tree().change_scene_to_file("res://addons/game_on/artifact_success.tscn")

# Connect to back signal
var success_scene := get_tree().current_scene as ArtifactSuccess
success_scene.back_pressed.connect(_on_back_pressed)
```

## Advanced Usage

### Customizing UI

### Changing the Auth Panel Back Button Destination

By default, the auth panel's back button returns to `res://main_menu.tscn`. To change this:

1. Edit `addons/game_on/auth_panel.gd`2. Modify the `_on_back_pressed()` function:
   ```gdscript
   func _on_back_pressed() -> void:
	   get_tree().change_scene_to_file("res://your_custom_scene.tscn")   ```

### Customizing the Success Screen Back Button

By default, the success screen emits `back_pressed` signal. game must handle the transition. To auto-transition after a delay:

1. Edit `addons/game_on/artifact_success.gd`
2. Modify `_on_back_pressed()`:
   ```gdscript
   func _on_back_pressed() -> void:
       # Auto-transition after 3 seconds
       await get_tree().create_timer(3.0).timeout
	   get_tree().change_scene_to_file("res://main_menu.tscn")
 ```

## Troubleshooting

### Authentication fails with "game_id not configured" error
- Ensure `game_on/game_id` is set in Project Settings
- Verify the game ID is correct (obtain from GameOn dashboard)

### Artifact unlock doesn't trigger
- Ensure `GameOnPortal.is_authorized` is `true` before calling `unlock_artart()`()`
- Verify your game's clear condition is correctly detected
### Success screen doesn't show artifact image
- Check that artifact data includes a valid `thumbnailUrl` field
- Verify the image URL is accessible from your game
- Check console for HTTP request errors

### HTTP errors in console
- Verify `game_on/api_url` is correct in Project Settings
- Ensure your game has internet access
- Check CORS headers if staging server ( HTML5 builds)
