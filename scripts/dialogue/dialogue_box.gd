class_name DialogueBox
extends CanvasLayer

## Emitted when the user submits text
signal text_submitted(text: String)

## Emitted when the user selects a different NPC to talk to
signal npc_changed(npc_name: String)

@onready var npc_select_option: OptionButton = %NPCSelectOption
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var chat_log: VBoxContainer = %ChatLog
@onready var line_edit: LineEdit = %LineEdit
@onready var send_button: Button = %SendButton

var _thinking_label: RichTextLabel = null
var _available_npcs: Array[String] = []

func _ready() -> void:
	line_edit.text_submitted.connect(_on_text_submitted)
	send_button.pressed.connect(_on_send_button_pressed)
	npc_select_option.item_selected.connect(_on_npc_item_selected)

## Populates the NPC selection dropdown with available character names
func setup_npc_selector(npc_names: Array[String], current_active: String = "") -> void:
	_available_npcs = npc_names
	npc_select_option.clear()
	var selected_index: int = 0

	for i in range(_available_npcs.size()):
		var name_str: String = _available_npcs[i]
		npc_select_option.add_item(name_str, i)
		if name_str == current_active:
			selected_index = i

	if not _available_npcs.is_empty():
		npc_select_option.select(selected_index)

## Adds a new message entry into the chat log window
func add_message(sender_name: String, message_text: String, is_player: bool = false) -> void:
	remove_thinking_indicator()

	var rtl: RichTextLabel = RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if is_player:
		rtl.text = "[color=#4FC3F7][b]%s:[/b][/color] %s" % [sender_name, message_text]
	else:
		rtl.text = "[color=#FFD54F][b]%s:[/b][/color] %s" % [sender_name, message_text]

	chat_log.add_child(rtl)
	_scroll_to_bottom()

## Adds a system notification into the chat log (e.g. character switch)
func add_system_info(info_text: String) -> void:
	remove_thinking_indicator()

	var rtl: RichTextLabel = RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	rtl.text = "[color=#80CBC4][i]--- %s ---[/i][/color]" % info_text

	chat_log.add_child(rtl)
	_scroll_to_bottom()

## Displays a warning message in the chat log (e.g., stay in character warning)
func add_warning(warning_text: String) -> void:
	remove_thinking_indicator()

	var rtl: RichTextLabel = RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	rtl.text = "[color=#FF5252][b]⚠️ Warning:[/b] %s[/color]" % warning_text

	chat_log.add_child(rtl)
	_scroll_to_bottom()

## Displays a temporary loading indicator while waiting for the AI response
func show_thinking_indicator(sender_name: String = "NPC") -> void:
	remove_thinking_indicator()
	
	_thinking_label = RichTextLabel.new()
	_thinking_label.bbcode_enabled = true
	_thinking_label.fit_content = true
	_thinking_label.scroll_active = false
	_thinking_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_thinking_label.text = "[color=#888888][i]%s is thinking...[/i][/color]" % sender_name
	
	chat_log.add_child(_thinking_label)
	_scroll_to_bottom()

## Removes the temporary loading indicator
func remove_thinking_indicator() -> void:
	if _thinking_label and is_instance_valid(_thinking_label):
		_thinking_label.queue_free()
		_thinking_label = null

func clear_chat() -> void:
	for child in chat_log.get_children():
		child.queue_free()

func _on_npc_item_selected(index: int) -> void:
	if index >= 0 and index < _available_npcs.size():
		var chosen_npc: String = _available_npcs[index]
		npc_changed.emit(chosen_npc)

func _on_send_button_pressed() -> void:
	_submit_text()

func _on_text_submitted(_new_text: String) -> void:
	_submit_text()

func _submit_text() -> void:
	var message: String = line_edit.text.strip_edges()
	if not message.is_empty():
		text_submitted.emit(message)
		line_edit.clear()

func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	scroll_container.scroll_vertical = int(scroll_container.get_v_scroll_bar().max_value)
