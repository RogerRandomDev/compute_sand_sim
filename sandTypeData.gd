@tool
extends Resource
class_name SandResource


@export var sand_id:int=0
@export_enum(
	'SOLID',
	'FALLING',
	'LIQUID',
	'GAS'
) var sand_type:int=0
@export var generator_type:int=-1;
@export var sand_special:int=0
@export var custom_value:float=0.0
@export var sand_name:String=" "
@export var sand_always_place:bool=false

var compiled_bytes:PackedByteArray

func load_in()->void:
	compiled_bytes=PackedFloat32Array([
		sand_id,0.0,sand_type,custom_value,0,0
	]).to_byte_array()
	if generator_type!=-1:
		compiled_bytes.encode_float(8,generator_type)
	compiled_bytes.encode_u32(4,sand_special)
	compiled_bytes.encode_u32(16,1)
	compiled_bytes.encode_u32(20,1)
	

func get_bytes()->PackedByteArray:
	return compiled_bytes
