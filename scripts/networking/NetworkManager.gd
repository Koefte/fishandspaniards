class_name NetworkManager_Internal extends Node

const STATE_TIME = 1

var delta_t_acc = 0

func _process(delta: float) -> void:
	delta_t_acc += delta
	if delta_t_acc > STATE_TIME:
		var entire_state = GameStateManager.get_entire_state()
		if SteamAPIManager.is_host():
			send_game_state(entire_state)
		delta_t_acc = 0
	send_actor_actions()
	
func start_game():
	pass
	
	
func send_actor_actions():
	var actors = GameStateManager.get_actors()
	for actor in actors:
		for action in actor.actions:
			SteamAPIManager.send_packet(Packet.new(action.type,action.data,actor))

func receive_packet(p:Packet):
	if p.type == Packet.PacketType.MOVEMENT:
		GameStateManager.set_movement(p.owner,Vector2(p.data.move_x,p.data.move_y))
	if p.type == Packet.PacketType.DESTROY:
		GameStateManager.destroy_obj(p.owner)
		
func receive_state(s:State):
	if GameStateManager.is_host():
		printerr("[NetworkManager] received state allthough user is host")
		return
	GameStateManager.set_obj(s.obj)
	
	
	
func send_game_state(entire_state:Dictionary):
	for actor in entire_state.actors:
		SteamAPIManager.send_state(State.new(actor))
	for entity in entire_state.entities:
		SteamAPIManager.send_state(State.new(entity))
