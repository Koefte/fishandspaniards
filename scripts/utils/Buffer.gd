class_name Buffer

var data:PackedByteArray
var cursor: int = 0
func _init(pData:PackedByteArray):
	data = pData

func consume(bytes_count:int):
	if cursor >= data.size():
		printerr("[Buffer] You ate enough!")
		return
	var slice = data.slice(cursor,cursor + bytes_count)
	cursor += bytes_count
	return slice

func consume_byte() -> int:
	if cursor >= data.size():
		printerr("[Buffer] You ate enough!")
		return 0
	var byte_val = data[cursor]
	cursor += 1
	return byte_val

func consume_rest():
	if cursor >= data.size():
		printerr("[Buffer] You ate enough!")
		return
	var slice = data.slice(cursor,data.size())
	cursor = data.size()
	return slice
