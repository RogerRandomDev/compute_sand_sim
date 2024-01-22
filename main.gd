extends Node2D

var rd :RenderingDevice 
var rope_shader_file = null
var rope_spirv: RDShaderSPIRV = null
var rope_shader = null
var element_buffer
var out_buffer
var image_buffers:Array[RID]=[RID(),RID()]
var uniform_set
var image_sets:Array[RID]=[RID(),RID()]
var pipeline
var compute_list

var size_of_world:Vector2=Vector2(640,640)
var set_used:bool=false
var thread_count:Vector2i=Vector2i.ZERO

var  tex_mat:=Texture2DRD
var tex_rid

var current_sand_data=PackedByteArray()

func _ready():
	tex_mat=$Sprite2D.texture
	randomize()


func create_image_uniform(ind:int):
	var uniform_image := RDUniform.new()
	uniform_image.uniform_type=RenderingDevice.UNIFORM_TYPE_IMAGE
	
	uniform_image.binding=0
	uniform_image.add_id(image_buffers[ind])
	return uniform_image


# Called when the node enters the scene tree for the first time.
func run_ready():
	
	rd = RenderingServer.get_rendering_device()
	rope_shader_file = load("res://compute_sand.glsl")
	rope_spirv = rope_shader_file.get_spirv()
	rope_shader = rd.shader_create_from_spirv(rope_spirv)
	
	$Sprite2D.scale=Vector2(640,640)/(size_of_world)
	thread_count=Vector2i(Vector2(5,5)/$Sprite2D.scale)
	
	var data:=PackedByteArray([])
	data.append_array(
		PackedFloat32Array([
			0.0,
			0.0,
			0.0,
			size_of_world.x,
			size_of_world.y
		]).to_byte_array()
		)
	
	var uncompiled_elements=PackedByteArray()
	var element_ids=PackedFloat32Array()
	element_ids.resize(size_of_world.x*size_of_world.y)
	element_ids.fill(0)
	for y in size_of_world.y:
		element_ids[size_of_world.x*y]=2
		element_ids[size_of_world.x*y+size_of_world.x-1]=2
	for x in size_of_world.x:
		element_ids[x]=2
	uncompiled_elements.resize(len(element_ids)*24)
	for elem in len(element_ids):
		uncompiled_elements.encode_float(elem*24,element_ids[elem])
		uncompiled_elements.encode_u8(elem*24+4,0)
		uncompiled_elements.encode_float(elem*24+8,0)
	data.append_array(uncompiled_elements)
	
	#image buffer
	var fmt = RDTextureFormat.new()
	fmt.width = size_of_world.x
	fmt.height = size_of_world.y
	fmt.texture_type=RenderingDevice.TEXTURE_TYPE_2D
	fmt.depth=1
	fmt.array_layers=1
	fmt.mipmaps=1
	fmt.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT + RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT + RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT + RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	var view = RDTextureView.new()
	var img=Image.create(size_of_world.x,size_of_world.y,false,Image.FORMAT_RGBA8)
	
	#load buffers and build the shader
	
	element_buffer=rd.storage_buffer_create(data.size(),data)
	var a=uncompiled_elements
	out_buffer=rd.storage_buffer_create(a.size(),a)
	
	image_buffers[0]=rd.texture_create(fmt,RDTextureView.new())
	image_buffers[1]=rd.texture_create(fmt,RDTextureView.new())
	rd.texture_clear(image_buffers[0],Color(0,0,0,1),0,1,0,1)
	rd.texture_clear(image_buffers[1],Color(0,0,0,1),0,1,0,1)
	#image_buffer=img_rd
	#$Sprite2D.texture=tex_mat
	
	
	canv_img="A"
	var uniform_elements := RDUniform.new()
	uniform_elements.uniform_type=RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform_elements.binding=0
	uniform_elements.add_id(element_buffer)
	
	var uniform_elements_out := RDUniform.new()
	uniform_elements_out.uniform_type=RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform_elements_out.binding=2
	uniform_elements_out.add_id(out_buffer)
	
	
	var uniform_images:Array=[
		create_image_uniform(0),
		create_image_uniform(1)
	]
	
	
	uniform_set = rd.uniform_set_create([uniform_elements,uniform_elements_out], rope_shader, 0)
	image_sets = [
		rd.uniform_set_create([uniform_images[0]],rope_shader,1),
		rd.uniform_set_create([uniform_images[1]],rope_shader,1)
		]
	pipeline = rd.compute_pipeline_create(rope_shader)
	
	#pipeline = rd.compute_pipeline_create(rope_shader)
	#compute_list = rd.compute_list_begin()
	#
	#rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	#rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	#rd.compute_list_dispatch(compute_list, thread_count.x,thread_count.y, 1)
	#rd.compute_list_end()
	#
	#rd.submit()
	#rd.sync()
	#var loaded_img=Image.create_from_data(size_of_world.x,size_of_world.y,false,Image.FORMAT_RGBA8,rd.texture_get_data(image_buffer,0))
	#canv_img=loaded_img
	
	#$Sprite2D.texture=ImageTexture.create_from_image(loaded_img)
	#var rs_tex_rid=RenderingServer.texture_rd_create(image_buffer,RenderingServer.TEXTURE_LAYERED_2D_ARRAY)
	#tex_rid=rs_tex_rid
	#RenderingServer.canvas_item_add_texture_rect(
		#get_canvas_item(),
		#Rect2(0,0,640,640),
		#tex_rid,false
		#)
	#$Sprite2D.texture=tex_mat
	
	
	
var canv_item
var canv_img
var t=0
var do_now:bool=false
func _process(delta):
	queue_redraw()
	if image_sets[0].get_id()==0:return
	do_now=!do_now
	t+=delta
	if t>200:t-=200
	RenderingServer.call_on_render_thread(update_sim)
		#run_ready()
	
	
	update_zoom_view()
func update_zoom_view():
	var global_mouse_pos=$Sprite2D.get_global_mouse_position()
	var mouse_coords=global_mouse_pos/$Sprite2D.scale
	var scaled_by=Vector2(mouse_coords)
	#mouse_coords=mouse_coords.clamp(Vector2(edit_scale*0.5,edit_scale*0.5),size_of_world-Vector2(edit_scale*0.5,edit_scale*0.5))
	scaled_by=Vector2i(scaled_by-mouse_coords)
	var abs_scaled_by=abs(scaled_by)
	var zoomed=$Control/Sprite2D2
	var from_coords=mouse_coords-Vector2(edit_scale*0.5,edit_scale*0.5)+Vector2(scaled_by)
	var offset_coords=-(from_coords-from_coords.clamp(
		Vector2.ZERO,
		Vector2(size_of_world)-Vector2(edit_scale,edit_scale)
	)).floor()
	zoomed.region_rect=Rect2(
		Vector2i(from_coords+offset_coords*Vector2(
			int(offset_coords.x>0),
			int(offset_coords.y>0)
			)
			),
		Vector2(
			Vector2(edit_scale,edit_scale)-abs(offset_coords)
		)
		
	)
	zoomed.scale=Vector2(128,128)/Vector2(edit_scale,edit_scale)

@export var process_counts:int=3

func update_sim()->void:
	set_used=!set_used
	
	rd.buffer_update(element_buffer,0,12,PackedFloat32Array(
		[randf_range(-3.0,3.0),
		float(set_used),
		t
		]
	).to_byte_array())
	#for chunked_set in 4:
		
		#process_chunked(chunked_set%2,floor(chunked_set/2),0,0,0)
	#draw process
	
	for i in process_counts:
		process_chunked(0,0,0,0,int(i==process_counts-1))
		process_chunked(1,0,0,0,int(i==process_counts-1))
		process_chunked(0,1,0,0,int(i==process_counts-1))
		process_chunked(1,1,0,0,int(i==process_counts-1))
	
	
	#canv_img.set_data(int(size_of_world.x),int(size_of_world.y),false,Image.FORMAT_RGBA8,rd.texture_get_data(image_buffer,0))
	#$Sprite2D.texture=ImageTexture.create_from_image(canv_img)
	if tex_mat:
		if rd.texture_is_valid(image_buffers[int(!set_used)]):
			tex_mat.texture_rd_rid=image_buffers[int(!set_used)]
	
	#var loaded_img=Image.create_from_data(size_of_world.x,size_of_world.y,false,Image.FORMAT_RGBA8,rd.texture_get_data(image_buffers[int(!set_used)],0))
	#$Sprite2D.texture=ImageTexture.create_from_image(loaded_img)

func process_chunked(x_o,y_o,x_w_o,y_w_o,is_draw)->void:
	var pushed_constants=PackedByteArray()
	pushed_constants.resize(16)
	pushed_constants.encode_u32(0,is_draw)
	pushed_constants.encode_u32(4,x_o)
	pushed_constants.encode_u32(8,y_o)
	
	#handle the render stage for updating every sand
	compute_list = rd.compute_list_begin()
	
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_bind_uniform_set(compute_list, image_sets[int(set_used)], 1)
	rd.compute_list_set_push_constant(compute_list,pushed_constants,pushed_constants.size())
	#rd.compute_list_dispatch(compute_list, thread_count.x,1, 1)
	rd.compute_list_dispatch(compute_list, thread_count.x, thread_count.y, 1)
	rd.compute_list_end()
	
	#rd.sync()




func _physics_process(delta):
	if image_buffers[0].get_id()==0:return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if !$Control.get_global_rect().has_point(get_global_mouse_position()):
			RenderingServer.call_on_render_thread(update_with_changes.bind(get_global_mouse_position()))


func _input(event):
	if event is InputEventMouseButton:
		edit_scale=max(edit_scale-int(Input.is_mouse_button_pressed(MOUSE_BUTTON_WHEEL_DOWN)),4)
		edit_scale=min(edit_scale+int(Input.is_mouse_button_pressed(MOUSE_BUTTON_WHEEL_UP)),64)

var ignore_block:bool=false
func update_with_changes(global_mouse_pos:Vector2):
	if not (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):return
	var mouse_coords=global_mouse_pos/$Sprite2D.scale
	var scaled_by=Vector2(mouse_coords)
	mouse_coords=mouse_coords.clamp(Vector2(edit_scale*0.5,edit_scale*0.5),size_of_world-Vector2(edit_scale*0.5,edit_scale*0.5))
	scaled_by=Vector2i(scaled_by-mouse_coords)
	var abs_scaled_by=abs(scaled_by)
	if abs_scaled_by.y>=edit_scale||abs_scaled_by.x>=edit_scale:return
	mouse_coords+=Vector2(scaled_by)
	for i in edit_scale-abs_scaled_by.y:
		var change_row=PackedByteArray([])
		var coord_at_2=Vector2i(mouse_coords.x-edit_scale*0.5,mouse_coords.y+i-edit_scale*0.5)
		if (coord_at_2.y>size_of_world.y-1 or coord_at_2.y<1):continue
		
		change_row=rd.buffer_get_data(out_buffer,
			(coord_at_2.x+coord_at_2.y*size_of_world.x)*24,(edit_scale-abs_scaled_by.x)*24
		)
		
		if(len(change_row)==0):continue
		for j in edit_scale-abs_scaled_by.x:
			var coord_at=Vector2i(mouse_coords.x+j-edit_scale*0.5,mouse_coords.y+i-edit_scale*0.5)
			if (coord_at.x>size_of_world.x-2||coord_at.x<1):continue
			
			var index_from_coord=int(
				coord_at.x+(coord_at.y*size_of_world.x)
			)
			if(index_from_coord<0||index_from_coord>size_of_world.x*size_of_world.y):continue
			var val=change_row.decode_float(j*24)
			
			if(val==0||ignore_block):
				for k in 24:change_row[j*24+k]=current_sand_data[k]
		rd.buffer_update(element_buffer,(coord_at_2.x+coord_at_2.y*size_of_world.x)*24+20,len(change_row),change_row)
		#rd.buffer_update(out_buffer,(coord_at_2.x+coord_at_2.y*size_of_world.x)*12,len(change_row),change_row)


func _on_popup_canceled():
	size_of_world=Vector2i(640,640)
	RenderingServer.call_on_render_thread(run_ready)
	$Popup.visible=false


func _on_popup_confirmed():
	$Popup.visible=false
	size_of_world=Vector2i(1024,1024)
	RenderingServer.call_on_render_thread(run_ready)
var edit_scale:int=32

func _draw():
	var p=Vector2($Sprite2D.get_global_mouse_position())
	p=p.clamp(
		Vector2(edit_scale*0.5,edit_scale*0.5)*$Sprite2D.scale,(size_of_world-Vector2(edit_scale*0.5,edit_scale*0.5))*$Sprite2D.scale
	)
	if $Control.get_global_rect().has_point(get_global_mouse_position()):
		$Control/Sprite2D2.hide()
		return
	$Control/Sprite2D2.show()
	#draw_rect(Rect2(
		#Vector2(p-Vector2(edit_scale*0.5,edit_scale*0.5)*$Sprite2D.scale),Vector2(edit_scale,edit_scale)*$Sprite2D.scale
	#),Color.RED,false)
	var rect=$Control/Sprite2D2.region_rect
	rect.position*=$Sprite2D.scale
	rect.size*=$Sprite2D.scale
	draw_rect(
		rect,Color.RED,false
	)

func _exit_tree():
	RenderingServer.call_on_render_thread(free_compute)

#clears the remaining rids after closing
func free_compute():
	for i in 2:
		if image_sets[i].is_valid():
			rd.free_rid(image_sets[i])
		if image_buffers[i].is_valid():
			rd.free_rid(image_buffers[i])
	if out_buffer.is_valid():
		rd.free_rid(out_buffer)
	if element_buffer.is_valid():
		rd.free_rid(element_buffer)
