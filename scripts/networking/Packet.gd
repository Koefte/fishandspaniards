class_name Packet extends NetworkedDataObject

enum PacketType {MOVEMENT,DESTROY} # Subject to change

var type : PacketType;
var data : Dictionary = {}
var owner: GameObject

const DEFAULT_MOVE_PACKET =  {
	move_x = 0,
	move_y = 0
}
const DEFAULT_DESTROY_PACKET = {}

const DEFAULT_PACKETS = {
	PacketType.MOVEMENT: DEFAULT_MOVE_PACKET,
	PacketType.DESTROY: DEFAULT_DESTROY_PACKET
}


func ensure_packet_structure(data:Dictionary,structure: Dictionary) -> bool:
	for key in structure:
		if not data.has(key):
			return false
		if typeof(data[key]) != structure[key]:
			return false
	return true

func serialize() -> PackedByteArray:
	var raw_data = PackedByteArray()
	raw_data.append(0) # 0 -> Packet , 1 -> State
	raw_data.append(type)
	raw_data.append(owner.id)
	raw_data.append_array(var_to_bytes(data))
	return raw_data

func _init(pType:PacketType,pData:Dictionary,pOwner:GameObject) -> void:
	if not ensure_packet_structure(pData,DEFAULT_PACKETS[pType]):
		printerr("[Packet] invalid packet data , want ",DEFAULT_PACKETS[pType]," have ",pData)
	type = pType
	data = pData
	owner = pOwner
