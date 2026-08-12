class_name NetworkManager_Internal extends Node

const STATE_TIME = 1

const log_debug = true

var id_counter: int = 0
var delta_t_acc: float = 0.0

func _process(delta: float) -> void:
	delta_t_acc += delta
	if delta_t_acc > STATE_TIME:
		if SteamAPIManager.is_host():
			send_game_state(GameStateManager.get_entire_state())
		delta_t_acc = 0.0
	send_actor_actions()

func start_game():
	if SteamAPIManager.is_host():
		SteamAPIManager.send_packet(Packet.new(Packet.PacketType.START_GAME, {}))
	_initiate_game_start()

func _initiate_game_start():
	GameStateManager.start_game()
	await get_tree().process_frame
	var player_node = get_tree().current_scene.get_node_or_null("Player") if get_tree().current_scene else null
	var player_pos = player_node.global_position if player_node else Vector3.ZERO
	var local_player = NetEntity.new(id_counter, player_pos, NetEntity.EntityType.PLAYER, NetEntity.AuthorityRole.AUTONOMOUS_PROXY)
	if player_node:
		local_player.node_ref = player_node
		player_node.net_entity = local_player

	GameStateManager.register_object(local_player)
	id_counter += 1

	if SteamAPIManager.is_host():
		for i in SteamAPIManager.get_player_count() - 1:
			var remote_spawn = Vector3(randi_range(0, 10), 0, randi_range(0, 10))
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
		print("received packet: ",p)
	if p.type == Packet.PacketType.START_GAME:
		if not SteamAPIManager.is_host():
			_initiate_game_start()
	elif p.type == Packet.PacketType.MOVEMENT:
		GameStateManager.set_movement(p.owner, Vector3(p.data.move_x, p.data.move_y, p.data.move_z))

func receive_state(s: State):
	if SteamAPIManager.is_host():
		return
	if s:
		GameStateManager.set_obj(s.state_data if "state_data" in s else s.obj)
