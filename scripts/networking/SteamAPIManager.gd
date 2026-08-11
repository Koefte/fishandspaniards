class_name SteamAPIManager


#enum lobby_status{Private, Friends, Public, Invisible}


var current_lobby_id: int = 0
var host_id : int = -1

#Internal Functions

func _broadcast_raw_bytes(raw_bytes: PackedByteArray, is_state: bool) -> void:
	raw_bytes.insert(0,is_state)
	var my_steam_id: int = Steam.getSteamID()
	
	var num_members: int = Steam.getNumLobbyMembers(current_lobby_id)
	
	var send_type: int
	if is_state:
		send_type = Steam.P2P_SEND_RELIABLE 
	else:
		send_type = Steam.P2P_SEND_UNRELIABLE_NO_DELAY 

	for i in range(num_members):
		var target_steam_id: int = Steam.getLobbyMemberByIndex(current_lobby_id, i)
		
		if target_steam_id != my_steam_id:
			Steam.sendP2PPacket(target_steam_id, raw_bytes, send_type, 0)

func _poll_incoming_packets() -> void:
	var channel: int = 0
	
	var packet_size: int = Steam.getAvailableP2PPacketSize(channel)
	
	while packet_size > 0:
		var packet_dict: Dictionary = Steam.readP2PPacket(packet_size, channel)
		
		if not packet_dict.is_empty():
			var sender_steam_id: int = packet_dict["remote_steam_id"]
			var raw_bytes: PackedByteArray = packet_dict["data"]
			
			_decode_and_route(sender_steam_id, raw_bytes)
		
		packet_size = Steam.getAvailableP2PPacketSize(channel)


func construct_packet(raw_bytes: PackedByteArray) -> Packet:
	var buffer = Buffer.new(raw_bytes)
	var type = buffer.consume(1)
	var owner_id = buffer.consume(1)
	var data = bytes_to_var(buffer.consume_rest())
	return Packet.new(type,data,owner_id)
			

static func _decode_and_route(sender_id: int, raw_bytes: PackedByteArray) -> void:
	
	var header: int = raw_bytes[0]
	
	match header:
		0: # Packet
			
			NetworkManager.receive_packet(construct_packet(raw_bytes.slice(1)))
			print("Received Packet from ", sender_id)
			
		1: # State
			NetworkManager.receive_state(State.new(bytes_to_var(raw_bytes.slice(1))))
			print("Received State from ", sender_id)
			
		_:
			printerr("Unknown packet header received!")

func _on_lobby_created(connect_res: int,lobby_id:int):
	if connect_res != 1:
		printerr("Failed to create lobby")
		return
	current_lobby_id = lobby_id
	Steam.setLobbyData(lobby_id,"name",Steam.getPersonaName() + "'s Lobby")
	Steam.setLobbyData(lobby_id,"name","fish and ships")
	
	
func _on_lobby_joined(lobby_id:int,_permissions:int,_locked:bool,response: int):
	if response != 1:
		printerr("Failed to join, got response code: ",response)
	current_lobby_id = lobby_id
	host_id = Steam.getLobbyOwner(lobby_id)
	print("Joined ",host_id, " Lobby")


#Public Functions

static func send_packet(p:Packet):
	_broadcast_raw_bytes(p.serialize(),false)

static func send_state(s:State):
	_broadcast_raw_bytes(s.serialize(),true)

func is_host() -> bool:
	return host_id == Steam.getSteamID()

func host_game() -> void:
	if current_lobby_id != 0:
		return
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC,4)	
	print("Created Lobby")
	
func join_game(host_id:int) -> void:
	if current_lobby_id != 0:
		return
	Steam.joinLobby(host_id)
	print("Joined Lobby")

func _ready() -> void:
	var init_result = Steam.steamInitEx(false,480)
	print(init_result)	
	
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)

func _process(delta: float) -> void:
	Steam.run_callbacks()
