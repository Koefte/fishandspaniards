class_name APIHandler
extends Node

## Emitted when an API response is successfully received
signal response_received(response_text: String)

## Emitted when an API request fails
signal request_failed(error_message: String)

## RWTH KI:connect API configuration
@export var api_url: String = "https://chat.kiconnect.nrw/api/v1/chat/completions"
@export var api_key: String = "6a78dfaa4468c1fc494a0aa8:YpInHRWKWI9BrD1UpFKSzDoj59XxVv/NAxilS4D+mCc="
@export var default_model: String = "mistralai-mistral-small-4-119b"

@onready var http_request: HTTPRequest = $HTTPRequest if has_node("HTTPRequest") else null

func _ready() -> void:
	if http_request == null:
		http_request = HTTPRequest.new()
		add_child(http_request)

## Sends a message to the RWTH KI:connect API (https://chat.kiconnect.nrw/api/v1/chat/completions) and returns model response.
## Parameters:
## - user_message: The text input from the user.
## - model: Target model name (defaults to `default_model` = "gpt-oss-120b" if empty).
## - system_prompt: Optional system prompt instructions for character persona & restrictions.
## - history: Optional array of past conversation messages [{"role": "user"/"assistant", "content": "..."}].
## Returns: The text response from the model, or an empty string on error.
func send_message(user_message: String, model: String = "", system_prompt: String = "", history: Array = []) -> String:
	if http_request == null:
		http_request = HTTPRequest.new()
		add_child(http_request)

	var selected_model: String = model if not model.strip_edges().is_empty() else default_model

	# Prepare messages array
	var messages: Array[Dictionary] = []

	if not system_prompt.strip_edges().is_empty():
		messages.append({
			"role": "system",
			"content": system_prompt
		})

	for item in history:
		if item is Dictionary and item.has("role") and item.has("content"):
			messages.append(item)

	messages.append({
		"role": "user",
		"content": user_message
	})

	var headers: PackedStringArray = [
		"Content-Type: application/json"
	]

	if not api_key.strip_edges().is_empty():
		headers.append("Authorization: Bearer " + api_key)

	var payload: Dictionary = {
		"model": selected_model,
		"messages": messages,
		"stream": false
	}

	var json_payload: String = JSON.stringify(payload)

	var err: Error = http_request.request(api_url, headers, HTTPClient.METHOD_POST, json_payload)
	if err != OK:
		var err_msg: String = "Failed to dispatch request to RWTH API (Error code: %d)" % err
		push_error(err_msg)
		request_failed.emit(err_msg)
		return ""

	var response: Array = await http_request.request_completed
	var result: int = response[0]
	var response_code: int = response[1]
	var body: PackedByteArray = response[3]

	if result != HTTPRequest.RESULT_SUCCESS or (response_code != 200 and response_code != 201):
		var body_str: String = body.get_string_from_utf8()
		var err_msg: String = "RWTH API Error (HTTP %d): %s" % [response_code, body_str]
		push_error(err_msg)
		request_failed.emit(err_msg)
		return ""

	var response_text: String = body.get_string_from_utf8()
	var json: JSON = JSON.new()
	var parse_err: Error = json.parse(response_text)

	if parse_err != OK:
		var err_msg: String = "Failed to parse JSON response from RWTH API"
		push_error(err_msg)
		request_failed.emit(err_msg)
		return ""

	var data = json.get_data()

	# 1. Standard OpenAI Chat Format (/v1/chat/completions)
	if data is Dictionary and data.has("choices") and data["choices"] is Array and data["choices"].size() > 0:
		var choice = data["choices"][0]
		if choice is Dictionary and choice.has("message") and choice["message"] is Dictionary:
			var reply: String = choice["message"].get("content", "")
			response_received.emit(reply)
			return reply

	var err_msg: String = "Unexpected response structure from RWTH API"
	push_error(err_msg)
	request_failed.emit(err_msg)
	return ""
