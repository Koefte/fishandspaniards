class_name NetworkManager_Internal extends Node

const STATE_TIME = 1

const log_debug = true

var id_counter: int = 0
var delta_t_acc: float = 0.0

func _process(delta: float) -> void:
	delta_t_acc += delta
	if delta_t_acc > STATE_TIME:
		if SteamAPIManager.is_host():
			GameStateManager.update_entities()
			send_game_state(GameStateManager.get_entire_state())
		delta_t_acc = 0.0
	send_actor_actions()

func start_game():
	if SteamAPIManager.is_host():
		SteamAPIManager.send_packet(Packet.new(Packet.PacketType.START_GAME, {}))
	_initiate_game_start()

func _get_local_entity_id() -> int:
	if not SteamAPIManager.is_host() and SteamAPIManager.current_lobby_id != 0:
		var members = SteamAPIManager.get_lobby_members()
		var my_steam_id = Steam.getSteamID()
		for i in range(members.size()):
			if members[i]["steam_id"] == my_steam_id:
				return i
		return 1
	return 0

func _initiate_game_start():
	GameStateManager.start_game()
	await get_tree().process_frame
	var player_node: Node3D = get_tree().current_scene.get_node("Player")
	var player_pos: Vector3 = player_node.global_position

	var local_id = _get_local_entity_id()
	var local_player = NetEntity.new(local_id, player_pos, NetEntity.EntityType.PLAYER, NetEntity.AuthorityRole.AUTONOMOUS_PROXY)
	local_player.node_ref = player_node
	player_node.net_entity = local_player

	GameStateManager.register_object(local_player)

	if SteamAPIManager.is_host():
		id_counter = 1
		for i in range(SteamAPIManager.get_player_count() - 1):
			var remote_spawn = Vector3(randi_range(0, 10), 1.03, randi_range(0, 10))
			var remote_entity = NetEntity.new(id_counter, remote_spawn, NetEntity.EntityType.NETWORKED_PLAYER, NetEntity.AuthorityRole.SIMULATED_PROXY)
			GameStateManager.register_object(remote_entity)
			id_counter += 1
		send_game_state(GameStateManager.get_entire_state())

func send_actor_actions():
	var objects = GameStateManager.get_objects()
	for id in objects:
		var entity: NetEntity = objects[id]
		for action in entity.poll_actions():
			SteamAPIManager.send_packet(action)

func send_game_state(entire_state: Array):
	for entity in entire_state:
		SteamAPIManager.send_state(State.new(entity))

func receive_packet(p: Packet):
	if log_debug:
		print("received packet: ", p)
	if p.type == Packet.PacketType.START_GAME:
		if not SteamAPIManager.is_host():
			_initiate_game_start()
	elif p.type == Packet.PacketType.MOVEMENT:
		var move_vec = Vector3(p.data.move_x, p.data.move_y, p.data.move_z)
		var new_pos = Vector3.ZERO
		if p.data.has("pos_x"):
			new_pos = Vector3(p.data.pos_x, p.data.pos_y, p.data.pos_z)
		GameStateManager.set_movement(p.owner_id, move_vec, new_pos)

func receive_state(s: State):
	if SteamAPIManager.is_host():
		return
	if s:
		GameStateManager.set_obj(s.state_data if "state_data" in s else s.obj)
