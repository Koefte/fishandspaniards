@abstract class_name GameObject extends Node

var id:int
var pos:Vector2 # vec2 just for testing purposes should really be vec3
var dir:Vector2

func _init(pId:int,pPos:Vector2):
	id = pId
	pos = pPos
