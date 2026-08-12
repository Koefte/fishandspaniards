class_name State extends NetworkedDataObject

var state_data: Dictionary = {}

func serialize() -> PackedByteArray:
	return var_to_bytes(state_data)

func _init(pObj = null):
	if pObj is NetEntity:
		state_data = {
			"id": pObj.id,
			"pos": pObj.pos,
			"dir": pObj.dir
		}
	elif pObj is Dictionary:
		state_data = pObj
