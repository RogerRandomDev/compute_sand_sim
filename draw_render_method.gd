extends Sprite2D

@export var draw_shell:bool=false
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _draw():
	if !draw_shell:return
	for i in range(0,640,8/scale.x):
		draw_line(Vector2(i,0),Vector2(i,640),Color(Color.WHITE,0.25),1.0,false)
		draw_line(Vector2(0,i),Vector2(640,i),Color(Color.WHITE,0.25),1.0,false)
	for i in range(0,640,4/scale.x):
		draw_line(Vector2(i,0),Vector2(i,640),Color(Color.WHITE,0.125),1.0,false)
		draw_line(Vector2(0,i),Vector2(640,i),Color(Color.WHITE,0.125),1.0,false)
