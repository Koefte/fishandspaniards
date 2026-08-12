class_name SteamAPIManager_Internal extends Node

@export var current_lobby_id: int = 0
@export var host_id: int = -1

func _ready() -> void:
	print("==================================================")
	print("[SteamP2P] Initializing SteamAPIManager...")
	
	if typeof(Steam) == TYPE_NIL:
		printerr("[SteamP2P] CRITICAL ERROR: Steam singleton is NIL! Is GodotSteam GDExtension enabled?")
		print("==================================================")
		return

	var init_result = Steam.steamInit(480, false)
	print("[SteamP2P] Steam.steamInit(480) Result: ", init_result)

	var is_running: bool = Steam.isSteamRunning()
	print("[SteamP2P] Steam Client Running: ", is_running)
	if is_running:
		print("[SteamP2P] My Steam ID: ", Steam.getSteamID(), " | Persona: ", Steam.getPersonaName())
	else:
		printerr("[SteamP2P] WARNING: Steam Client is NOT running in the background! P2P networking will not function.")

	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.p2p_session_request.connect(_on_p2p_session_request)
	Steam.p2p_session_connect_fail.connect(_on_p2p_session_connect_fail)
	print("==================================================")

func _on_p2p_session_request(remote_id: int) -> void:
	print("[SteamP2P] Accepting incoming P2P session request from Steam ID: ", remote_id)
	Steam.acceptP2PSessionWithUser(remote_id)

func _on_p2p_session_connect_fail(remote_id: int, p2p_session_error: int) -> void:
	printerr("[SteamP2P] Connection failed with Steam ID: ", remote_id, " Error: ", p2p_session_error)

func _process(_delta: float) -> void:
	if typeof(Steam) != TYPE_NIL:
		Steam.run_callbacks()
		_poll_incoming_packets()

func _broadcast_raw_bytes(raw_bytes: PackedByteArray, is_state: bool) -> void:
	if current_lobby_id == 0:
		print("[SteamP2P] Cannot send packet: Not currently in a lobby (current_lobby_id is 0)")
		return

	var payload: PackedByteArray = PackedByteArray([1 if is_state else 0])
	payload.append_array(raw_bytes)

	var my_steam_id: int = Steam.getSteamID()
	var num_members: int = Steam.getNumLobbyMembers(current_lobby_id)
	var send_type: int = Steam.P2P_SEND_UNRELIABLE_NO_DELAY if is_state else Steam.P2P_SEND_RELIABLE

	print("[SteamP2P] Broadcasting payload (size: ", payload.size(), " bytes) to ", num_members, " lobby members...")

	for i in range(num_members):
		var target_steam_id: int = Steam.getLobbyMemberByIndex(current_lobby_id, i)
		if target_steam_id != my_steam_id:
			Steam.acceptP2PSessionWithUser(target_steam_id)
			var sent: bool = Steam.sendP2PPacket(target_steam_id, payload, send_type, 0)
			print("[SteamP2P] Send P2P Packet to ", target_steam_id, " -> Result: ", sent)

func _poll_incoming_packets() -> void:
	var channel: int = 0
	var packet_size: int = Steam.getAvailableP2PPacketSize(channel)

	while packet_size > 0:
		var packet_dict: Dictionary = Steam.readP2PPacket(packet_size, channel)
		print("[SteamP2P] Incoming P2P Packet detected! Dictionary: ", packet_dict)

		if not packet_dict.is_empty():
			var sender_steam_id: int = 0
			if packet_dict.has("remote_steam_id"):
				sender_steam_id = packet_dict["remote_steam_id"]
			elif packet_dict.has("steam_id"):
				sender_steam_id = packet_dict["steam_id"]

			var raw_bytes: PackedByteArray = PackedByteArray()
			if packet_dict.has("data"):
				raw_bytes = packet_dict["data"]

			if not raw_bytes.is_empty():
				_decode_and_route(sender_steam_id, raw_bytes)
				

		packet_size = Steam.getAvailableP2PPacketSize(channel)

func construct_packet(raw_bytes: PackedByteArray) -> Packet:
	var buffer = Buffer.new(raw_bytes)
	var type = buffer.consume_byte()
	var owner_id = buffer.consume_byte()
	var rest = buffer.consume_rest()
	var data = bytes_to_var(rest) if rest and not rest.is_empty() else {}
	return Packet.new(type, data, owner_id)

func _decode_and_route(sender_id: int, raw_bytes: PackedByteArray) -> void:
	if raw_bytes.is_empty():
		return

	var header: int = raw_bytes[0]
	var payload_slice: PackedByteArray = raw_bytes.slice(1)

	match header:
		0: # Packet
			var pkt: Packet = construct_packet(payload_slice)
			print("[SteamP2P] Received Packet from ", sender_id, ": type=", pkt.type)
			NetworkManager.receive_packet(pkt)
		1: # State
			var state_val = bytes_to_var(payload_slice)
			print("[SteamP2P] Received State from ", sender_id)
			NetworkManager.receive_state(State.new(state_val))
		_:
			printerr("[SteamP2P] Unknown packet header received: ", header)

func _on_lobby_created(connect_res: int, lobby_id: int) -> void:
	print("[SteamP2P] _on_lobby_created signal triggered. Result: ", connect_res, " | Lobby ID: ", lobby_id)
	if connect_res != 1:
		printerr("[SteamP2P] Failed to create lobby")
		return
	current_lobby_id = lobby_id
	host_id = Steam.getSteamID()
	Steam.setLobbyData(lobby_id, "name", Steam.getPersonaName() + "'s Lobby")
	print("=== LOBBY CREATED SUCCESSFULLY ===")
	print("Lobby ID: ", lobby_id)
	print("Host Steam ID: ", host_id)

func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	print("[SteamP2P] _on_lobby_joined signal triggered. Response: ", response, " | Lobby ID: ", lobby_id)
	if response != 1:
		printerr("[SteamP2P] Failed to join lobby, response code: ", response)
		return

	current_lobby_id = lobby_id
	host_id = Steam.getLobbyOwner(lobby_id)
	
	if host_id != Steam.getSteamID():
		Steam.acceptP2PSessionWithUser(host_id)

	print("[SteamP2P] Joined Lobby ", lobby_id, " (Host ID: ", host_id, ")")

func send_packet(p: Packet) -> void:
	print("[SteamP2P] send_packet called for packet type: ", p.type)
	_broadcast_raw_bytes(p.serialize(), false)

func send_state(s: State) -> void:
	if not is_host():
		return
	_broadcast_raw_bytes(s.serialize(), true)

func is_host() -> bool:
	return host_id == Steam.getSteamID()

func host_game() -> void:
	print("[SteamP2P] host_game() called...")
	if current_lobby_id != 0:
		print("[SteamP2P] Already in a lobby: ", current_lobby_id)
		return
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, 4)
	print("[SteamP2P] Steam.createLobby requested.")

func join_game(target_lobby_id: int) -> void:
	print("[SteamP2P] join_game() called for lobby: ", target_lobby_id)
	if current_lobby_id != 0:
		print("[SteamP2P] Already in a lobby: ", current_lobby_id)
		return
	Steam.joinLobby(target_lobby_id)
	print("[SteamP2P] Steam.joinLobby requested.")

func get_player_count() -> int:
	if current_lobby_id != 0:
		return Steam.getNumLobbyMembers(current_lobby_id)
	return 1

func get_lobby_members() -> Array[Dictionary]:
	var members: Array[Dictionary] = []
	if current_lobby_id == 0:
		return members
	var count = Steam.getNumLobbyMembers(current_lobby_id)
	var my_id = Steam.getSteamID()
	for i in range(count):
		var member_steam_id = Steam.getLobbyMemberByIndex(current_lobby_id, i)
		var persona_name: String = ""
		if member_steam_id == my_id:
			persona_name = Steam.getPersonaName()
		else:
			persona_name = Steam.getFriendPersonaName(member_steam_id)
			if persona_name.is_empty():
				persona_name = "Player " + str(member_steam_id)

		members.append({
			"steam_id": member_steam_id,
			"persona_name": persona_name,
			"is_host": member_steam_id == host_id
		})
	return members
