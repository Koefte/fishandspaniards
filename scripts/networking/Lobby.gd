extends Node

@onready var IdInput = $IdInput

func _on_host_button_pressed():
	SteamAPIManager.host_game()
	
func _on_join_button_pressed():
	SteamAPIManager.join_game(IdInput.text)

func _on_start_button_pressed():
	NetworkManager.start_game()
