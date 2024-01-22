#[compute]
#version 450
// Invocations in the (x, y, z) dimension
layout(local_size_x = 16,local_size_y=16) in;

precision highp int;

struct element {

    float elementID;
    uint is_moving;
    float type_of;
    float custom_value;
    int move_direction_x;
    int move_direction_y;
};



layout(set = 0, binding = 0, std430) restrict buffer World{
    float offset;
    float cur_set;
    float time;
    float s_x;
    float s_y;
    element data[];
}
world;
layout(set = 0, binding = 2, std430) restrict buffer outputWorld{
    element data[];
}
world_out;

shared float current_step;


layout(set = 1, binding = 0, rgba8) uniform restrict writeonly image2D outputImage;


layout(push_constant, std430) uniform Params {
	uint draw_stage;
    uint x_off;
    uint y_off;

} params;


float PHI = 1.61803398874989484820459;  // Φ = Golden Ratio   
const float seed=51.12715;

float gold_noise(in vec2 xy){
       return fract(tan(distance(xy*PHI, xy)*seed)*xy.x);
}


float rand(vec2 n) {
	return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453);
}

float noise(vec2 p){
	vec2 ip = floor(p);
	vec2 u = fract(p);
	u = u*u*(3.0-2.0*u);

	float res = mix(
		mix(rand(ip),rand(ip+vec2(1.0,0.0)),u.x),
		mix(rand(ip+vec2(0.0,1.0)),rand(ip+vec2(1.0,1.0)),u.x),u.y);
	return ((res*res)-0.5);
}


ivec2 index_to_coordinate(uint index){
    return ivec2(index%uint(world.s_x),index/uint(world.s_x));
}

uint coordinate_to_index(ivec2 coord){
    return uint(coord.x+coord.y*int(world.s_x));
}

// void change_index_cell(ivec2 uindex,float new_cell){
//     uint index=coordinate_to_index(uindex);
//     world.data[index].elementID=new_cell;
//     // world_out.data[index].elementID=new_cell;
// }


// void change_index_cell(uint index,float new_cell){
//     world.data[index].elementID=new_cell;
//     // world_out.data[index].elementID=new_cell;
// }
void swap_cells(uint ind_1,uint ind_2){
    element e1=world.data[ind_1];
    element e2=world.data[ind_2];
    world.data[ind_1]=e2;
    world.data[ind_2]=e1;
    // world_out.data[ind_1]=e2;
    // world_out.data[ind_2]=e1;
}

void sand_pull(ivec2 at_index, element current_element,uint edit_ind){
    uint indices_sand[4]={
        coordinate_to_index(at_index+ivec2(-1,0)),
        coordinate_to_index(at_index+ivec2(1,0)),
        coordinate_to_index(at_index+ivec2(0,1)),
        coordinate_to_index(at_index+ivec2(0,-1)),
    };
    if(
        world.data[indices_sand[0]].type_of==1.0&&
        world.data[indices_sand[0]].is_moving<world.data[edit_ind].is_moving&&
        gold_noise(vec2(at_index+ivec2(3150,0))+vec2(world.time*414.612+current_step*32.0,0.0))<world.data[indices_sand[0]].custom_value
        
    ){
        world.data[indices_sand[0]].is_moving=world.data[edit_ind].is_moving-1;
    }
    if(
        world.data[indices_sand[1]].type_of==1.0&&
        world.data[indices_sand[1]].is_moving<world.data[edit_ind].is_moving&&
        gold_noise(vec2(at_index+ivec2(3850,0))+vec2(world.time*414.612+current_step*32.0,0.0))<world.data[indices_sand[1]].custom_value
    ){
        world.data[indices_sand[1]].is_moving=world.data[edit_ind].is_moving-1;
    }
    if(
        world.data[indices_sand[2]].type_of==1.0&&
        world.data[indices_sand[2]].is_moving<world.data[edit_ind].is_moving
    ){
        world.data[indices_sand[2]].is_moving=world.data[edit_ind].is_moving-1;
    }
    if(
        world.data[indices_sand[3]].type_of==1.0&&
        world.data[indices_sand[3]].is_moving<world.data[edit_ind].is_moving
    ){
        world.data[indices_sand[3]].is_moving=world.data[edit_ind].is_moving-1;
    }
}


bool liquid_flow_through(element check_against){
    return (check_against.elementID==0.0&&check_against.type_of==0.0||check_against.type_of==3.0);
}
bool gas_flow_through(element check_against){
    return (check_against.elementID==0.0&&check_against.type_of==0.0);
}






void process_sand_motion_base(ivec2 at_index,element current_element,uint edit_ind,uint type){
        element below=world.data[coordinate_to_index(at_index+ivec2(0,1))];
        //base sand
        
        if(below.elementID==0.0||below.type_of>=2.0){
            world.data[edit_ind].is_moving=min(max(world.data[edit_ind].is_moving+1,5),20);
            current_element.is_moving=world.data[edit_ind].is_moving;
            sand_pull(at_index,current_element,edit_ind);
            
            swap_cells(edit_ind,coordinate_to_index(at_index+ivec2(0,1)));
            
            return;
        }
        float rand_direction=sign(rand(vec2(at_index+vec2(world.offset*128.0,409.0*(world.time+current_step*23.0)))));
        element diagonals[2]={
            world.data[coordinate_to_index(at_index+ivec2(rand_direction,1))],
            world.data[coordinate_to_index(at_index+ivec2(-rand_direction,1))]
        };

        if(current_element.is_moving==0) return;
        world.data[edit_ind].is_moving--;

        if(diagonals[0].elementID==0.0||diagonals[0].type_of>=2.0){
            // world.data[edit_ind].is_moving=min(world.data[edit_ind].is_moving+1,4);
            world.data[edit_ind].is_moving++;
            sand_pull(at_index,current_element,edit_ind);
            swap_cells(edit_ind,coordinate_to_index(at_index+ivec2(rand_direction,1)));
            
            return;
        }
        if(diagonals[1].elementID==0.0||diagonals[1].type_of>=2.0){
            // world.data[edit_ind].is_moving=min(world.data[edit_ind].is_moving+1,4);
            world.data[edit_ind].is_moving++;
            sand_pull(at_index,current_element,edit_ind);
            swap_cells(edit_ind,coordinate_to_index(at_index+ivec2(-rand_direction,1)));
            
            return;
        }
}


void process_liquid_motion_base(ivec2 at_index,element current_element,uint edit_ind,uint type){
    element below=world.data[coordinate_to_index(at_index+ivec2(0,1))];
    //base liquid
    if(liquid_flow_through(below)){
        swap_cells(edit_ind,coordinate_to_index(at_index+ivec2(0,1)));
        return;
    }
    float rand_direction=(current_element.move_direction_x!=0?current_element.move_direction_x:sign(gold_noise(vec2(at_index+vec2(world.offset*74.0,49.0*(world.time+current_step*23.0))))));
    
    if(!liquid_flow_through(world.data[coordinate_to_index(at_index+ivec2(rand_direction,0))])){
        world.data[edit_ind].move_direction_x=-world.data[edit_ind].move_direction_x;
    }

    element diagonals[2]={
        world.data[coordinate_to_index(at_index+ivec2(rand_direction,1))],
        world.data[coordinate_to_index(at_index+ivec2(-rand_direction,1))]
    };
    int max_l=1;


    if(liquid_flow_through(world.data[coordinate_to_index(at_index+ivec2(max_l*rand_direction,0))])){
            while(max_l<=4&&liquid_flow_through(world.data[coordinate_to_index(at_index+ivec2(max_l*rand_direction,0))])){
                // if(world.data[coordinate_to_index(at_index+ivec2(-(max_l-1)*rand_direction,1))].elementID!=0.0) over_shoot++;
                max_l++;
                
            }
            if(!liquid_flow_through(world.data[coordinate_to_index(at_index+ivec2(max_l*rand_direction,0))])) max_l--;
            
            swap_cells(edit_ind,coordinate_to_index(at_index+ivec2(max_l*rand_direction,0)));
            return;
    }

    if(liquid_flow_through(diagonals[0])){
        swap_cells(edit_ind,coordinate_to_index(at_index+ivec2(rand_direction,1)));
        world.data[edit_ind].move_direction_x=int(rand_direction);
        return;
    }
    if(liquid_flow_through(diagonals[1])){
        swap_cells(edit_ind,coordinate_to_index(at_index+ivec2(-rand_direction,1)));
        world.data[edit_ind].move_direction_x=-int(rand_direction);
        return;
    }
}


void process_gas_motion_base(ivec2 at_index,element current_element,uint edit_ind,uint type){
    //base gas
    if(gold_noise(vec2(at_index*212.0+vec2(059.0,490.0+world.time)))>0.75){
        float val=noise(vec2(at_index*73.74+vec2(5.0,523.0+world.time)));
        if(val<0){
            if(
                world.data[coordinate_to_index(at_index+ivec2(1,0))].elementID==0.0
            ){
                swap_cells(edit_ind,coordinate_to_index(at_index+ivec2(1,0)));
                return;
            }
        }else{
            if(
                world.data[coordinate_to_index(at_index+ivec2(-1,0))].elementID==0.0
            ){ 
                swap_cells(edit_ind,coordinate_to_index(at_index+ivec2(-1,0)));
                return;
            }
        }
        
    }
    float rand_direction=(current_element.is_moving>0?current_element.move_direction_x:sign(rand(vec2(at_index+vec2(world.offset*128.0,409.0*(world.time+current_step*23.0))))));
    element diagonals[2]={
        world.data[coordinate_to_index(at_index+ivec2(rand_direction,-1))],
        world.data[coordinate_to_index(at_index+ivec2(-rand_direction,-1))]
    };
    int max_l=1;

    if(!gas_flow_through(world.data[coordinate_to_index(at_index+ivec2(rand_direction,0))])){
        world.data[edit_ind].move_direction_x=-world.data[edit_ind].move_direction_x;
    }

    
    if(current_element.is_moving>0){
        world.data[edit_ind].is_moving--;
    }
    // diagonals[0]=world.data[coordinate_to_index(at_index+ivec2(rand_direction,-1))];
    // diagonals[1]=world.data[coordinate_to_index(at_index+ivec2(-rand_direction,-1))];

    if(at_index.y>0){
        if(world.data[coordinate_to_index(at_index+ivec2(0,-1))].elementID==0.0||world.data[coordinate_to_index(at_index+ivec2(0,-1))].type_of==1.0){
            // world.data[edit_ind].is_moving=2;
            world.data[edit_ind].is_moving=2;
            swap_cells(edit_ind,coordinate_to_index(at_index+ivec2(0,-1)));
            
            return;
        }

        
        if(diagonals[0].elementID==0.0){
            world.data[edit_ind].is_moving=2;
            swap_cells(edit_ind,coordinate_to_index(at_index+ivec2(rand_direction,-1)));
            return;
        }
        if(diagonals[1].elementID==0.0){
            world.data[edit_ind].is_moving=2;
            swap_cells(edit_ind,coordinate_to_index(at_index+ivec2(-rand_direction,-1)));
            return;
        }
    }
    if(gas_flow_through(world.data[coordinate_to_index(at_index+ivec2(max_l*rand_direction,0))])){
        while(max_l<=4&&gas_flow_through(world.data[coordinate_to_index(at_index+ivec2(max_l*rand_direction,0))])){
            // if(world.data[coordinate_to_index(at_index+ivec2(-(max_l-1)*rand_direction,1))].elementID!=0.0) over_shoot++;
            max_l++;
            
        }
        world.data[edit_ind].is_moving=2;
        max_l--;
        swap_cells(edit_ind,coordinate_to_index(at_index+ivec2(max_l*rand_direction,0)));
        return;
    }
    
    
    return;
}


void update_index_at(ivec2 at_index,element current_element,uint edit_ind){
    bool clear_self=false;
    uint extra=0;
    switch(int(current_element.elementID)){
        case(0):
            break;
        case(1):
            world.data[edit_ind].type_of=1.0;
            process_sand_motion_base(at_index,current_element,edit_ind,1);
            break;
        case(2):
            world.data[edit_ind].type_of=0.0;
            break;
        case(3):
            //steam
            world.data[edit_ind].type_of=3.0;

            if(world.data[edit_ind].custom_value>0&&noise(vec2(at_index)+vec2((world.time+current_step*42.0)*204.0,0.0))>-0.25){
                    world.data[edit_ind].custom_value--;
            }
            if(world.data[edit_ind].custom_value<=0){
                current_element.elementID=5;
                current_element.type_of=2.0;
                world.data[edit_ind].elementID=5;
                world.data[edit_ind].type_of=2.0;
                world.data[edit_ind].is_moving=0;
            }
            if(noise(vec2(at_index)+vec2((world.time+current_step*42.0)*world.offset))>-0.375) process_gas_motion_base(at_index,current_element,edit_ind,3);
            for(int i=-1;i<3;i++){
            for(int j=-1;j<3;j++){
                uint coord=coordinate_to_index(at_index+ivec2(i,j));
                if(world.data[coord].elementID==3.0&&noise(vec2(at_index)+vec2((world.time+current_step*42.0)*world.offset))>0.05){
                    world.data[coord].custom_value=min(world.data[coord].custom_value+1,256);
                    extra++;
                }
                if(extra>=3) break;
            }
            if(extra>=3) break;
            }
            break;
        case(4):
            //fire
            world.data[edit_ind].type_of=3.0;
            // if(world.data[edit_ind].is_moving>256){world.data[edit_ind].is_moving=255;}
            if(world.data[edit_ind].custom_value>0&&noise(vec2(at_index)+vec2((world.time+current_step*42.0)*204.0,0.0))>-0.375){
                    world.data[edit_ind].custom_value--;current_element.custom_value--;
            }
            clear_self=current_element.custom_value<=0;
            if(clear_self){
                // current_element.elementID=0.0;
                // current_element.type_of=0.0;
                world.data[edit_ind].elementID=0;
                world.data[edit_ind].type_of=0.0;
                world.data[edit_ind].custom_value=0;
                
                break;
            }
            world.data[edit_ind].custom_value=min(world.data[edit_ind].custom_value,128);
            
            if(noise(vec2(at_index)+vec2((world.time+current_step*73.5)*214.0,0.0))>-0.25) process_gas_motion_base(at_index,current_element,edit_ind,3);
            for(int i=-1;i<3;i++){
            for(int j=-1;j<3;j++){
                
                uint coord=coordinate_to_index(at_index+ivec2(i,j));
                if(world.data[coord].elementID==5.0){
                    world.data[coord].elementID=3.0;
                    world.data[coord].type_of=3.0;
                    world.data[coord].custom_value=524;
                    clear_self=true;
                }
            }
            }
            if(clear_self){
                current_element.elementID=0.0;
                current_element.type_of=0.0;
                world.data[edit_ind].elementID=0;
                world.data[edit_ind].type_of=0.0;
                world.data[edit_ind].custom_value=0;
            }
            break;
        case(5):
            //water
            world.data[edit_ind].type_of=2.0;
            process_liquid_motion_base(at_index,current_element,edit_ind,2);
            
            break;
        case(6):
            //resource generator
            if(world.data[coordinate_to_index(at_index+ivec2(0,1))].elementID==0.0){
                world.data[coordinate_to_index(at_index+ivec2(0,1))].elementID=float(current_element.is_moving);
                world.data[coordinate_to_index(at_index+ivec2(0,1))].custom_value=uint(current_element.type_of);
            }
            if(world.data[coordinate_to_index(at_index+ivec2(0,-1))].elementID==0.0){
                world.data[coordinate_to_index(at_index+ivec2(0,-1))].elementID=float(current_element.is_moving);
                world.data[coordinate_to_index(at_index+ivec2(0,-1))].custom_value=uint(current_element.type_of);
            }
            if(world.data[coordinate_to_index(at_index+ivec2(1,0))].elementID==0.0){
                world.data[coordinate_to_index(at_index+ivec2(1,0))].elementID=float(current_element.is_moving);
                world.data[coordinate_to_index(at_index+ivec2(1,0))].custom_value=uint(current_element.type_of);
            }
            if(world.data[coordinate_to_index(at_index+ivec2(-1,0))].elementID==0.0){
                world.data[coordinate_to_index(at_index+ivec2(-1,0))].elementID=float(current_element.is_moving);
                world.data[coordinate_to_index(at_index+ivec2(-1,0))].custom_value=uint(current_element.type_of);
            }

        default:
            break;
    }
}
void draw_color_at(ivec2 at_index,element current_element){
    float color_mult=1.0+noise(vec2(at_index)*20.0)*0.125;
    float special=1.0;
    imageStore(outputImage, at_index, vec4(0.0, 0.0, 0.0, 1.0));
    switch(uint(current_element.elementID)){
        case(0):
            //nothing is there
            imageStore(outputImage, at_index, vec4(0.0, 0.0, 0.0, 1.0));
            break;
        case(1):
            //base sand
            imageStore(outputImage, at_index, vec4(0.75*color_mult, 0.75*color_mult, 0.0, 1.0));
            break;
        case(2):
            //stone
            imageStore(outputImage, at_index, vec4(0.5*color_mult, 0.5*color_mult, 0.5*color_mult, 1.0));
            break;
        case(3):
            //base gas
            imageStore(outputImage, at_index, vec4(0.75*color_mult, 0.75*color_mult, 0.75*color_mult, 1.0));
            break;
        case(4):
            //fire
            special=(1.5+abs(noise(vec2(at_index+vec2(world.offset*22310.0,0.0))*20.0))*0.5)-min(float(current_element.custom_value)/64.0,1.0);
            color_mult=1.0+(color_mult-1.0)*2.0;
            imageStore(outputImage, at_index, vec4(1.0*color_mult, 0.375*color_mult*special, 0.125*color_mult, 1.0));
            break;
        case(5):
            //base liquid
            imageStore(outputImage, at_index, vec4(0.0*color_mult, 0.5*color_mult, 1.0*color_mult, 1.0));
            break;
        default:
            break;
    }
}








// The code we want to execute in each invocation
void main() {
    
    int column_start=int(gl_GlobalInvocationID.x*8+params.x_off*4);
    
    int row_start=int((gl_GlobalInvocationID.y)*8+params.y_off*4);

    current_step=1.0;

    for(int current_y=int(world.s_y)-row_start;current_y>int(world.s_y)-row_start-4;current_y--){
    for(int current_x=column_start;current_x<column_start+4;current_x++){
        ivec2 pixel_ind=ivec2(current_x,current_y);
        uint coord_index=coordinate_to_index(pixel_ind);
        if(params.draw_stage==1){
            draw_color_at(pixel_ind,world.data[coord_index]);
            world_out.data[coord_index]=world.data[coord_index];
        }
        update_index_at(pixel_ind,world.data[coord_index],coord_index);
        
    }
    }
}
