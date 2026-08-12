extends Control

@onready var host_button: Button = $MarginContainer/MainVBox/TopControlsHBox/HostButton
@onready var join_button: Button = $MarginContainer/MainVBox/TopControlsHBox/JoinButton
@onready var id_input: LineEdit = $MarginContainer/MainVBox/TopControlsHBox/IdInput
@onready var lobby_id_label: Label = $MarginContainer/MainVBox/LobbyInfoHBox/LobbyIdLabel
@onready var copy_id_button: Button = $MarginContainer/MainVBox/LobbyInfoHBox/CopyIdButton
@onready var player_count_label: Label = $MarginContainer/MainVBox/PlayerListPanel/PlayerListMargin/PlayerListVBoxContainer/PlayerCountLabel
@onready var player_list_vbox: VBoxContainer = $MarginContainer/MainVBox/PlayerListPanel/PlayerListMargin/PlayerListVBoxContainer/PlayerListScroll/PlayerListVBox
@onready var start_button: Button = $MarginContainer/MainVBox/BottomActionHBox/StartButton
@onready var status_label: Label = $MarginContainer/MainVBox/BottomActionHBox/StatusLabel

func _ready() -> void:
	host_button.pressed.connect(_on_host_button_pressed)
	join_button.pressed.connect(_on_join_button_pressed)
	start_button.pressed.connect(_on_start_button_pressed)
	copy_id_button.pressed.connect(_on_copy_id_button_pressed)

	Steam.lobby_created.connect(_on_steam_lobby_created)
	Steam.lobby_joined.connect(_on_steam_lobby_joined)
	Steam.lobby_chat_update.connect(_on_steam_lobby_chat_update)

	refresh_lobby_ui()

func _on_host_button_pressed() -> void:
	status_label.text = "Creating Steam Lobby..."
	SteamAPIManager.host_game()

func _on_join_button_pressed() -> void:
	var input_text = id_input.text.strip_edges()
	if input_text.is_valid_int():
		status_label.text = "Joining Lobby " + input_text + "..."
		SteamAPIManager.join_game(input_text.to_int())
	else:
		status_label.text = "Please enter a valid numeric Lobby ID."

func _on_start_button_pressed() -> void:
	if SteamAPIManager.is_host():
		status_label.text = "Starting Game..."
		NetworkManager.start_game()

func _on_copy_id_button_pressed() -> void:
	if SteamAPIManager.current_lobby_id != 0:
		DisplayServer.clipboard_set(str(SteamAPIManager.current_lobby_id))
		status_label.text = "Lobby ID copied to clipboard!"

func _on_steam_lobby_created(connect_res: int, _lobby_id: int) -> void:
	if connect_res == 1:
		status_label.text = "Lobby created successfully! You are Host."
	else:
		status_label.text = "Failed to create Steam lobby."
	refresh_lobby_ui()

func _on_steam_lobby_joined(_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response == 1:
		if SteamAPIManager.is_host():
			status_label.text = "Lobby ready. Click Start Game to launch."
		else:
			status_label.text = "Joined lobby. Waiting for Host to start game..."
	else:
		status_label.text = "Failed to join lobby (Response code: %d)" % response
	refresh_lobby_ui()

func _on_steam_lobby_chat_update(_lobby_id: int, _change_id: int, _making_change_id: int, _chat_state: int) -> void:
	refresh_lobby_ui()

func refresh_lobby_ui() -> void:
	var lobby_id = SteamAPIManager.current_lobby_id

	if lobby_id != 0:
		lobby_id_label.text = "Lobby ID: " + str(lobby_id)
	else:
		lobby_id_label.text = "Lobby ID: Not Created"

	copy_id_button.disabled = (lobby_id == 0)
	start_button.disabled = not (lobby_id != 0 and SteamAPIManager.is_host())

	var members = SteamAPIManager.get_lobby_members()
	player_count_label.text = "Connected Players (%d / 4)" % members.size()

	for child in player_list_vbox.get_children():
		child.queue_free()

	if members.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No players connected. Host or join a lobby to populate."
		empty_label.modulate = Color(0.7, 0.7, 0.7)
		player_list_vbox.add_child(empty_label)
	else:
		for member in members:
			var card = PanelContainer.new()
			var margin = MarginContainer.new()
			margin.add_theme_constant_override("margin_left", 12)
			margin.add_theme_constant_override("margin_top", 8)
			margin.add_theme_constant_override("margin_right", 12)
			margin.add_theme_constant_override("margin_bottom", 8)

			var hbox = HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 16)

			var name_label = Label.new()
			name_label.text = member["persona_name"]
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_label.add_theme_font_size_override("font_size", 16)

			var id_label = Label.new()
			id_label.text = "ID: " + str(member["steam_id"])
			id_label.modulate = Color(0.6, 0.8, 1.0)

			var badge_label = Label.new()
			if member["is_host"]:
				badge_label.text = "[ HOST ]"
				badge_label.modulate = Color(0.3, 1.0, 0.4)
			else:
				badge_label.text = "[ CLIENT ]"
				badge_label.modulate = Color(0.9, 0.9, 0.3)

			hbox.add_child(name_label)
			hbox.add_child(id_label)
			hbox.add_child(badge_label)
			margin.add_child(hbox)
			card.add_child(margin)
			player_list_vbox.add_child(card)
