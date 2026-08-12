class_name Packet extends NetworkedDataObject

enum PacketType {MOVEMENT, DESTROY}

var type: PacketType
var data: Dictionary = {}
var owner_id: int = 0
var owner: Object = null

const DEFAULT_MOVE_PACKET = {
	move_x = 0,
	move_y = 0,
	move_z = 0
}
const DEFAULT_DESTROY_PACKET = {}

const DEFAULT_PACKETS = {
	PacketType.MOVEMENT: DEFAULT_MOVE_PACKET,
	PacketType.DESTROY: DEFAULT_DESTROY_PACKET
}

func ensure_packet_structure(pData: Dictionary, structure: Dictionary) -> bool:
	for key in structure:
		if not pData.has(key):
			return false
		if typeof(pData[key]) != typeof(structure[key]):
			return false
	return true

func serialize() -> PackedByteArray:
	var raw_data = PackedByteArray()
	raw_data.append(type)
	raw_data.append(owner_id)
	raw_data.append_array(var_to_bytes(data))
	return raw_data

func _init(pType: PacketType = PacketType.MOVEMENT, pData: Dictionary = {}, pOwner = null) -> void:
	if not ensure_packet_structure(pData, DEFAULT_PACKETS.get(pType, {})):
		printerr("[Packet] invalid packet data , want ", DEFAULT_PACKETS.get(pType, {}), " have ", pData)
	type = pType
	data = pData
	if typeof(pOwner) == TYPE_INT:
		owner_id = pOwner
	elif pOwner is Object:
		owner = pOwner
		if "id" in pOwner:
			owner_id = pOwner.id
