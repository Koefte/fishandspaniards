class_name DatabaseAPI
extends Node

func update_npc_position(npc_name: String, pos: String) -> void:
	var path: String = "res://npc_dialogue_data/%s.json" % npc_name
	if not FileAccess.file_exists(path):
		push_error("DatabaseAPI: Character JSON file does not exist at %s" % path)
		return

	var file_read = FileAccess.open(path, FileAccess.READ)
	if not file_read:
		push_error("DatabaseAPI: Failed to open %s for reading" % path)
		return

	var json_string: String = file_read.get_as_text()
	file_read.close()

	var json_data = JSON.parse_string(json_string)
	if not (json_data is Dictionary):
		push_error("DatabaseAPI: Invalid JSON data in %s" % path)
		return

	json_data["location"] = pos

	var file_write = FileAccess.open(path, FileAccess.WRITE)
	if not file_write:
		push_error("DatabaseAPI: Failed to open %s for writing" % path)
		return

	file_write.store_string(JSON.stringify(json_data, "\t"))
	file_write.close()

func push_world_fact(fact: String) -> void:
	var path: String = "res://npc_global_knowledge/npc_global_knowledge.json"
	if not FileAccess.file_exists(path):
		push_error("DatabaseAPI: Global knowledge JSON file does not exist at %s" % path)
		return

	var file_read = FileAccess.open(path, FileAccess.READ)
	if not file_read:
		push_error("DatabaseAPI: Failed to open %s for reading" % path)
		return

	var json_string: String = file_read.get_as_text()
	file_read.close()

	var json_data = JSON.parse_string(json_string)
	if not (json_data is Dictionary):
		push_error("DatabaseAPI: Invalid JSON data in %s" % path)
		return

	if not json_data.has("world_facts") or not (json_data["world_facts"] is Array):
		json_data["world_facts"] = []

	json_data["world_facts"].append(fact)

	var file_write = FileAccess.open(path, FileAccess.WRITE)
	if not file_write:
		push_error("DatabaseAPI: Failed to open %s for writing" % path)
		return

	file_write.store_string(JSON.stringify(json_data, "\t"))
	file_write.close()
