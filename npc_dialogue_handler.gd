extends Node2D

@onready var dialogue_box: DialogueBox = $DialogueBox
@onready var api_handler: APIHandler = $APIHandler if has_node("APIHandler") else null

var person: String = "Furious Fisher Frank"
var global_knowledge_path: String = "res://npc_global_knowledge/npc_global_knowledge.txt"
var restrictions_path: String = "res://npc_global_knowledge/npc_restrictions.txt"
var npc_prompt_format: String = "res://npc_dialogue_data/%s.txt"

var sys_prompt: String = ""

func _ready() -> void:
	if api_handler == null:
		api_handler = APIHandler.new()
		add_child(api_handler)

	dialogue_box.set_title(person)

	# 1. Load NPC Restrictions
	var restrictions_text: String = ""
	if FileAccess.file_exists(restrictions_path):
		var file = FileAccess.open(restrictions_path, FileAccess.READ)
		restrictions_text = file.get_as_text().strip_edges()

	# 2. Load World / Global Knowledge
	var global_knowledge: String = ""
	if FileAccess.file_exists(global_knowledge_path):
		var file = FileAccess.open(global_knowledge_path, FileAccess.READ)
		global_knowledge = file.get_as_text().strip_edges()

	# 3. Load NPC Specific Persona & Knowledge
	var npc_prompt: String = ""
	var prompt_path: String = npc_prompt_format % person
	if FileAccess.file_exists(prompt_path):
		var file = FileAccess.open(prompt_path, FileAccess.READ)
		npc_prompt = file.get_as_text().strip_edges()
	else:
		var alt_path: String = "res://npc_dialogue_data/%s" % person
		if FileAccess.file_exists(alt_path):
			var file = FileAccess.open(alt_path, FileAccess.READ)
			npc_prompt = file.get_as_text().strip_edges()
		else:
			push_error("Could not find prompt for: " + person)

	# 4. Build Combined System Prompt
	sys_prompt = build_system_prompt(restrictions_text, global_knowledge, npc_prompt)

	dialogue_box.text_submitted.connect(_on_text_submitted)

## Combines restrictions, world background, and character persona into a unified system prompt
func build_system_prompt(restrictions: String, global_knowledge: String, npc_prompt: String) -> String:
	var parts: Array[String] = []
	
	if not restrictions.is_empty():
		parts.append(restrictions)
		
	if not global_knowledge.is_empty():
		parts.append("=== WORLD & GLOBAL KNOWLEDGE ===\n" + global_knowledge)
		
	if not npc_prompt.is_empty():
		parts.append("=== CHARACTER PERSONA & KNOWLEDGE ===\n" + npc_prompt)
		
	return "\n\n".join(parts).strip_edges()

func _on_text_submitted(text: String) -> void:
	# 1. Add user message to chat log
	dialogue_box.add_message("You", text, true)
	
	# 2. Show thinking indicator
	dialogue_box.show_thinking_indicator(person)

	# 3. Request AI response from KI:connect API
	var response: String = await api_handler.send_message(text, "", sys_prompt)

	# 4. Handle REJECT vs normal responses
	var cleaned_response: String = response.strip_edges().to_upper()
	if cleaned_response.begins_with("REJECT") or cleaned_response == "REJECT":
		dialogue_box.add_warning("Please stay in character! Keep your questions relevant to the world and character context.")
	elif response.is_empty():
		dialogue_box.add_message(person, "[i](No response received)[/i]", false)
	else:
		dialogue_box.add_message(person, response, false)
