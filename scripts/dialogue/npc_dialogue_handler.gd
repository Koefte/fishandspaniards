extends Node2D

@onready var dialogue_box: DialogueBox = $DialogueBox
@onready var api_handler: APIHandler = $APIHandler if has_node("APIHandler") else null

var person: String = "Furious r Frank"
var global_knowledge_path: String = "res://npc_global_knowledge/npc_global_knowledge.json"
var restrictions_path: String = "res://npc_global_knowledge/npc_restrictions.json"
var npc_folder_path: String = "res://npc_dialogue_data/"

var sys_prompt: String = ""
var global_knowledge_cache: String = ""
var npc_prompt_cache: String = ""
var available_npcs: Array[String] = []

func _ready() -> void:
	if api_handler == null:
		api_handler = APIHandler.new()
		add_child(api_handler)

	# 1. Discover all character JSON files dynamically
	discover_available_npcs()

	# 2. Connect signals
	dialogue_box.text_submitted.connect(_on_text_submitted)
	dialogue_box.npc_changed.connect(set_active_npc)

	# 3. Setup UI dropdown selector and initialize starting NPC
	if not available_npcs.is_empty():
		if not available_npcs.has(person):
			person = available_npcs[0]
		dialogue_box.setup_npc_selector(available_npcs, person)
		set_active_npc(person, false)

## Scans res://npc_dialogue_data/ for all .json character files
func discover_available_npcs() -> void:
	available_npcs.clear()
	var dir = DirAccess.open(npc_folder_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				var char_name = file_name.get_basename()
				available_npcs.append(char_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	
	available_npcs.sort()

## Switches active conversation NPC at runtime
func set_active_npc(new_npc: String, show_info: bool = true) -> void:
	person = new_npc
	load_system_prompt()
	if show_info:
		dialogue_box.add_system_info("Now talking to: %s" % person)

## Loads JSON restrictions, global knowledge, and character persona to build sys_prompt
func load_system_prompt() -> void:
	# 1. Load NPC Restrictions JSON
	var restrictions_text: String = parse_restrictions_json(restrictions_path)

	# 2. Load World / Global Knowledge JSON
	global_knowledge_cache = parse_global_knowledge_json(global_knowledge_path)

	# 3. Load Selected NPC Persona & Knowledge JSON
	var prompt_path: String = npc_folder_path + "%s.json" % person
	npc_prompt_cache = parse_npc_json(prompt_path)

	sys_prompt = build_system_prompt(restrictions_text, global_knowledge_cache, npc_prompt_cache)

## Parses restrictions JSON into a formatted system text string
func parse_restrictions_json(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and json.get_data() is Dictionary:
		var data: Dictionary = json.get_data()
		var out: String = "=== NPC DIALOGUE & CONTEXT RESTRICTIONS ===\nCRITICAL DIRECTIVES:\n\n"
		if data.has("reject_rule"):
			out += "1. REJECT RULE (FOR OUT-OF-CONTEXT / MODERN TOPICS):\n   - " + str(data["reject_rule"]) + "\n\n"
		if data.has("in_context_rule"):
			out += "2. IN-CONTEXT RULE (FOR IN-WORLD & HISTORICAL ERA TOPICS):\n   - " + str(data["in_context_rule"]) + "\n\n"
		if data.has("roleplay_and_no_hallucinations"):
			out += "3. ROLEPLAY & NO HALLUCINATIONS:\n   - " + str(data["roleplay_and_no_hallucinations"]) + "\n\n"
		if data.has("response_format"):
			out += "4. RESPONSE FORMAT:\n   - " + str(data["response_format"])
		return out.strip_edges()
	return ""

## Parses global knowledge JSON into a formatted text string
func parse_global_knowledge_json(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and json.get_data() is Dictionary:
		var data: Dictionary = json.get_data()
		var lines: Array[String] = []
		if data.has("world_facts") and data["world_facts"] is Array:
			for fact in data["world_facts"]:
				lines.append(str(fact))
		elif data.has("location"):
			lines.append("You live in the town of " + str(data["location"]))
		return "\n".join(lines)
	return ""

## Parses NPC character JSON into a formatted prompt string
func parse_npc_json(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and json.get_data() is Dictionary:
		var data: Dictionary = json.get_data()
		var parts: Array[String] = []
		
		if data.has("role"):
			parts.append("Role\n" + str(data["role"]))
		if data.has("location"):
			parts.append("Location\n" + str(data["location"]))
		if data.has("personality_traits") and data["personality_traits"] is Array:
			var traits: Array[String] = []
			for trait_item in data["personality_traits"]:
				traits.append(str(trait_item))
			parts.append("Personality Traits\n\n" + "\n".join(traits))
		if data.has("knowledge") and data["knowledge"] is Array:
			var k_items: Array[String] = []
			for k in data["knowledge"]:
				k_items.append(str(k))
			parts.append("Knowledge\n\n" + "\n".join(k_items))
			
		return "\n\n".join(parts)
	return ""

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

	# 3. Request AI response from RWTH KI:connect API
	var response: String = await api_handler.send_message(text, "", sys_prompt)

	# 4. Handle REJECT by re-prompting API for an in-character "don't know" response
	var cleaned_response: String = response.strip_edges().to_upper()
	if cleaned_response.begins_with("REJECT") or cleaned_response == "REJECT":
		var fallback_sys_prompt: String = "=== WORLD KNOWLEDGE ===\n" + global_knowledge_cache + "\n\n=== CHARACTER PERSONA ===\n" + npc_prompt_cache + "\n\n=== DIRECTIVE ===\nThe player asked about an unknown, modern, or out-of-world topic. In your character's exact voice, speech pattern, and personality, respond in 1 short sentence stating in-character that you have never heard of such a thing or know nothing about it."
		
		var in_character_fallback: String = await api_handler.send_message(text, "", fallback_sys_prompt)
		
		var cleaned_fallback: String = in_character_fallback.strip_edges().to_upper()
		if cleaned_fallback.is_empty() or cleaned_fallback.begins_with("REJECT"):
			dialogue_box.add_message(person, "I don't know anything about that...", false)
		else:
			dialogue_box.add_message(person, in_character_fallback, false)
	elif response.is_empty():
		dialogue_box.add_message(person, "[i](No response received)[/i]", false)
	else:
		dialogue_box.add_message(person, response, false)
