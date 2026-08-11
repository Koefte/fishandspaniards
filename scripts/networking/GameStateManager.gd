class_name GameStateManager_Proprietary extends Node

var entities : Array[Entity] = []
var actors	 : Array[Actor] 	= []

func update_entities():
	# entities dont act themselves so their behaviour is entirely determined by physics
	pass

func get_entire_state():
	return {
		"entities":entities,
		"actors":actors
	}

func get_actors():
	return actors
	
func set_movement(owner:GameObject,move_vec:Vector2):
	owner.dir = move_vec
	
func set_obj(obj:GameObject):
	if obj is Actor:
		for actor in actors:
			if obj.id == actor.id:
				actor = obj as Actor
				return
	for entity in entities:
		if entity.id == obj.id:
			entity = obj
	
