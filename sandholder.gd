extends Resource
class_name SandList

@export var sands:Array[SandResource]

var ordered_sands:Dictionary={}



func load_in()->void:
	for sand in sands:
		sand.load_in()
		ordered_sands[sand.sand_id]=sand



func get_sand(id:int)->SandResource:return ordered_sands[id]

func get_sand_data(id:int)->PackedByteArray:return ordered_sands[id].get_bytes()
