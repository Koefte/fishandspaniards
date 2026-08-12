extends Node

@onready var IdInput = $IdInput

func _ready() -> void:
	if has_node("HostButton"):
		$HostButton.pressed.connect(_on_host_button_pressed)
	if has_node("JoinButton"):
		$JoinButton.pressed.connect(_on_join_button_pressed)
	if has_node("StartButton"):
		$StartButton.pressed.connect(_on_start_button_pressed)

func _on_host_button_pressed():
	SteamAPIManager.host_game()
	
func _on_join_button_pressed():
	SteamAPIManager.join_game(IdInput.text.to_int())

func _on_start_button_pressed():
	NetworkManager.start_game()
