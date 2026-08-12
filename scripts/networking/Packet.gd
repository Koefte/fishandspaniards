class_name Packet extends NetworkedDataObject

enum PacketType {MOVEMENT, DESTROY, START_GAME, DEBUG, KEY_INPUT}

var type: PacketType
var data: Dictionary = {}
var owner_id: int = 0
var owner: Object = null


const DEFAULT_KEY_INPUT_PACKET = {
	"forward": false,
	"backward": false,
	"left": false,
	"right": false,
	"jump": false,
	"rot_y": 0.0
}
const DEFAULT_DESTROY_PACKET = {}
const DEFAULT_START_GAME_PACKET = {}
const DEFAULT_DEBUG_PACKET = {
	message = "hey"
}

const DEFAULT_PACKETS = {
	PacketType.KEY_INPUT: DEFAULT_KEY_INPUT_PACKET,
	PacketType.DESTROY: DEFAULT_DESTROY_PACKET,
	PacketType.START_GAME: DEFAULT_START_GAME_PACKET,
	PacketType.DEBUG: DEFAULT_DEBUG_PACKET
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
