extends Control

@export var list:SandList=null



func _ready():
	var itemList=$ItemList as ItemList
	list.load_in()
	for item in list.sands:
		itemList.add_item(item.sand_name)
	itemList.item_selected.connect(selected_item)
	get_parent().current_sand_data=list.sands[0].get_bytes()


func selected_item(ind:int)->void:
	get_parent().current_sand_data=list.sands[ind].get_bytes()
	get_parent().ignore_block=list.sands[ind].sand_always_place
