class_name State extends NetworkedDataObject

var obj: GameObject

func serialize() -> PackedByteArray:
	var arr = PackedByteArray()
	arr.append(1) # 0 -> Packet , 1 -> State
	arr.append_array(var_to_bytes(obj))
	return arr

func _init(pObj:GameObject):
	obj = pObj
