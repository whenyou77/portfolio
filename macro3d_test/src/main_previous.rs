use macroquad::prelude::*;
use enum_iterator::{next_cycle,previous_cycle,Sequence};
use ipslim::Lim;

#[derive(Sequence, Debug)]
enum Direction
{
    North,
    East,
    South,
    West
}

enum Ore
{
    Coal,
    Copper,
    Iron,
    Gold,
    Diamond
}

enum Action
{
    // MOVEMENT
    North,
    South,
    East,
    West,
    Up,
    Down,
    Clockwise, // ROTATION
    CounterClockwise,
    //ACTIONS
    Mine,
    Attack,
    Idle
}

/*enum NpcType
{
    Normal(String),
    Poor(String, u32)
}*/

enum EnemyType
{
    Plebian,
    Mercenary,
    Swordfish,
    Gunslinger,
    Demon,
    Snitch,
    BigSnitch // AKA "Death the Snitch"
}

enum Parts
{
    Empty,
    Wall,
    Vein(Ore),
    Player(f32),
    //Npc(NpcType),
    Stairs,
    Elevator,
    Enemy
}

const TURN_STEP: i32 = 9;
const WALK_STEP: f32 = 0.8;

fn hovers(x1: f32, x2: f32, y1: f32, y2: f32, hover_x: f32, hover_y: f32) -> bool
{
    if 
        hover_x < x2 &&
        hover_x > x1 &&
        hover_y < y2 &&
        hover_y > y1
    {
        // Collision detected!
     true
    } else {
        // No collision
     false
    }
}

fn window_conf() -> Conf {
    Conf {
        window_title: "SHADOW WIZARD MONEY GANG".to_owned(),
        fullscreen: false,
        window_resizable: false,
        window_width: 1280,
        window_height: 800,
        ..Default::default()
    }
}

#[macroquad::main(window_conf)]
async fn main() {
    let rust_logo = load_texture("../rust.png").await.unwrap();
    let ferris = load_texture("../ferris.png").await.unwrap();
    let clay = load_texture("../funky.png").await.unwrap(); clay.set_filter(FilterMode::Nearest);
    let rock = load_texture("../rock.png").await.unwrap(); rock.set_filter(FilterMode::Nearest);
    let coal = load_texture("../coal.png").await.unwrap(); coal.set_filter(FilterMode::Nearest);
    let copper = load_texture("../copper.png").await.unwrap(); copper.set_filter(FilterMode::Nearest);
    let iron = load_texture("../iron.png").await.unwrap(); iron.set_filter(FilterMode::Nearest);
    let gold = load_texture("../gold.png").await.unwrap(); gold.set_filter(FilterMode::Nearest);
    let diamond = load_texture("../diamond.png").await.unwrap(); diamond.set_filter(FilterMode::Nearest);
    let elevator = load_texture("../elevator.png").await.unwrap(); elevator.set_filter(FilterMode::Nearest);

    // let limit = Lim::limit(&mut self);
    //let idiot = load_texture("../me.png").await.unwrap();

    let mut x: f32 = 0.;
    let mut y: f32 = 0.;
    let mut z: f32 = 0.;
    let mut angle: f32 = 90.;
    let mut anim_timer: i32 = 0;
    let bullets: u8 = 0;

    let mut resources = [0,0,0,0,0];

    let mut direction = Direction::North;
    let mut action = Action::Idle;

    let mut map = [
        [Parts::Wall,Parts::Wall,Parts::Wall,Parts::Wall,Parts::Wall,Parts::Vein(Ore::Copper),Parts::Vein(Ore::Coal),Parts::Wall,Parts::Wall,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Elevator,Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Wall,Parts::Empty,Parts::Vein(Ore::Gold),Parts::Empty,Parts::Empty,Parts::Vein(Ore::Diamond),Parts::Empty,Parts::Wall,Parts::Wall],
        [Parts::Wall,Parts::Wall,Parts::Empty,Parts::Wall,Parts::Empty,Parts::Empty,Parts::Wall,Parts::Empty,Parts::Wall,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Player(0.),Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Wall,Parts::Wall,Parts::Wall,Parts::Stairs,Parts::Stairs,Parts::Wall,Parts::Wall,Parts::Wall,Parts::Wall]
    ];

    for my in 0..map.len() as i8
    {
        for mx in 0..map[my as usize].len() as i8
        {
            match map[map.len()-my as usize-1][mx as usize]
            {
                Parts::Player(_) => {
                    z = (mx - map[my as usize].len() as i8/2) as f32*8.;
                    x = (my - map.len() as i8/2) as f32*8.
                }
                _ => ()
            }
                
        }
    }

    loop {

        let map_y = map.len()-(x/8.+map.len() as f32/2.) as usize-1;
        let map_x = (z/8.+map[map_y].len() as f32/2.) as usize;

        let fps_mod = 4;

        //map[map_y][map_x] = Parts::Empty;

        //let dt=get_frame_time()-old_time;
        //old_time = get_frame_time()

        if anim_timer == 0
        {
            action = Action::Idle;

            x = x.round();
            y = y.round();
            z = z.round();

            //angle = angle.round();

            /*if angle > 359. || angle < -359.
            {
                angle = 0.;
            }*/

            if is_key_pressed(KeyCode::H)
            {
                let angle_ry = angle.to_radians().sin().round() as i32;
                let angle_rx = angle.to_radians().cos().round() as i32;
                println!("{},{}",angle_ry,angle_rx);
                if let Parts::Vein(_) = &map[(map_y as i32-angle_ry) as usize][(map_x as i32 +angle_rx) as usize] {
                    action = Action::Mine;
                    anim_timer = 60*fps_mod;
                }
                /*if let Parts::Vein(_) = &map[map_y+angle.to_radians().sin() as usize][map_x-angle.to_radians().cos() as usize] {
                    action = Action::Mine;
                    anim_timer = 60*fps_mod;
                }*/
                /*if let Parts::Vein(_) = &map[map_y+angle.to_radians().sin() as usize][map_x]{
                    action = Action::Mine;
                    anim_timer = 60*fps_mod;
                }
                if let Parts::Vein(_) = &map[map_y][map_x-angle.to_radians().cos() as usize]{
                    action = Action::Mine;
                    anim_timer = 60*fps_mod;
                }
                if let Parts::Vein(_) = &map[map_y][map_x+angle.to_radians().cos() as usize]{
                    action = Action::Mine;
                    anim_timer = 60*fps_mod;
                }*/
            }

            if is_key_pressed(KeyCode::D)
            {
                let angle_ry = angle.to_radians().cos().round() as i32;
                let angle_rx = angle.to_radians().sin().round() as i32;
                if let Parts::Empty = &map[(map_y as i32-angle_ry) as usize][(map_x as i32 +angle_rx) as usize] {
                    map[map_y][map_x] = Parts::Empty;
                    map[(map_y as i32-angle_ry) as usize][(map_x as i32 +angle_rx) as usize] = Parts::Player(0.);
                    action = Action::East;
                    anim_timer = 10*fps_mod;
                }
                /*match direction
                {
                    Direction::North => if let Parts::Empty = &map[map_y][map_x+1]
                    {
                        map[map_y][map_x] = Parts::Empty;
                        map[map_y][map_x+1] = Parts::Player(0.);
                        action = Action::East;
                        anim_timer = 10*fps_mod;
                    },
                    Direction::South => if let Parts::Empty = &map[map_y][map_x-1]
                    {
                        map[map_y][map_x] = Parts::Empty;
                        map[map_y][map_x-1] = Parts::Player(0.);
                        action = Action::East;
                        anim_timer = 10*fps_mod;
                    },
                    Direction::East => if let Parts::Empty = &map[map_y+1][map_x]
                    {
                        map[map_y][map_x] = Parts::Empty;
                        map[map_y+1][map_x] = Parts::Player(0.);
                        action = Action::East;
                        anim_timer = 10*fps_mod;      
                    },
                    Direction::West => if let Parts::Empty = &map[map_y-1][map_x]
                    {
                        map[map_y][map_x] = Parts::Empty;
                        map[map_y-1][map_x] = Parts::Player(0.);
                        action = Action::East;
                        anim_timer = 10*fps_mod;
                    }
                }*/
                
            }
            if is_key_pressed(KeyCode::A)
            {
                let angle_ry = angle.to_radians().cos().round() as i32;
                let angle_rx = angle.to_radians().sin().round() as i32;
                if let Parts::Empty = &map[(map_y as i32+angle_ry) as usize][(map_x as i32-angle_rx) as usize] {
                    map[map_y][map_x] = Parts::Empty;
                    map[(map_y as i32+angle_ry) as usize][(map_x as i32-angle_rx) as usize] = Parts::Player(0.);
                    action = Action::West;
                    anim_timer = 10*fps_mod;
                }
                /*match direction
                {
                    Direction::North => if let Parts::Empty = &map[map_y][map_x-1]
                    {
                        map[map_y][map_x] = Parts::Empty;
                        map[map_y][map_x-1] = Parts::Player(0.);
                        action = Action::West;
                        anim_timer = 10*fps_mod;
                    },
                    Direction::South => if let Parts::Empty = &map[map_y][map_x+1]
                    {
                        map[map_y][map_x] = Parts::Empty;
                        map[map_y][map_x+1] = Parts::Player(0.);
                        action = Action::West;
                        anim_timer = 10*fps_mod;
                    },
                    Direction::East => if let Parts::Empty = &map[map_y-1][map_x]
                    {
                        map[map_y][map_x] = Parts::Empty;
                        map[map_y-1][map_x] = Parts::Player(0.);
                        action = Action::West;
                        anim_timer = 10*fps_mod;      
                    },
                    Direction::West => if let Parts::Empty = &map[map_y+1][map_x]
                    {
                        map[map_y][map_x] = Parts::Empty;
                        map[map_y+1][map_x] = Parts::Player(0.);
                        action = Action::West;
                        anim_timer = 10*fps_mod;
                    }
                }*/
            }
            if is_key_pressed(KeyCode::W)
            {
                let angle_ry = angle.to_radians().sin().round() as i32;
                let angle_rx = angle.to_radians().cos().round() as i32;
                if let Parts::Empty = &map[(map_y as i32-angle_ry) as usize][(map_x as i32 +angle_rx) as usize] {
                    map[map_y][map_x] = Parts::Empty;
                    map[(map_y as i32-angle_ry) as usize][(map_x as i32 +angle_rx) as usize] = Parts::Player(0.);
                    action = Action::North;
                    anim_timer = 10*fps_mod;
                }
            }
            if is_key_pressed(KeyCode::S)
            {
                let angle_ry = angle.to_radians().sin().round() as i32;
                let angle_rx = angle.to_radians().cos().round() as i32;
                if let Parts::Empty = &map[(map_y as i32+angle_ry) as usize][(map_x as i32 -angle_rx) as usize] {
                    map[map_y][map_x] = Parts::Empty;
                    map[(map_y as i32+angle_ry) as usize][(map_x as i32 -angle_rx) as usize] = Parts::Player(0.);
                    action = Action::South;
                    anim_timer = 10*fps_mod;
                }
            }

            if is_key_pressed(KeyCode::Space)
            {
                if let Parts::Elevator = map[map_y][map_x]
                {
                    action = Action::Up;
                    anim_timer = 180*fps_mod;
                }
            }
            if is_key_pressed(KeyCode::LeftShift)
            {
                if let Parts::Elevator = map[map_y][map_x]
                {
                    action = Action::Down;
                    anim_timer = 180*fps_mod;
                }
            }

            if is_key_pressed(KeyCode::Q)
            {
                direction = previous_cycle(&direction).unwrap();
                action = Action::CounterClockwise;
                anim_timer = 10*fps_mod;
            }
            if is_key_pressed(KeyCode::E)
            {
                direction = next_cycle(&direction).unwrap();
                action = Action::Clockwise;
                anim_timer = 10*fps_mod;
            }
        }
            
        if anim_timer > 0
        {
            //if anim_timer % fps_mod == 0
            {
                match action
                {
                Action::North => if anim_timer % fps_mod == 0 {
                    x+=WALK_STEP*angle.to_radians().sin();
                    z+=WALK_STEP*angle.to_radians().cos();
                },
                Action::South => if anim_timer % fps_mod == 0 {
                    x-=WALK_STEP*angle.to_radians().sin();
                    z-=WALK_STEP*angle.to_radians().cos();
                },
                Action::East => if anim_timer % fps_mod == 0 {
                    x-=WALK_STEP*angle.to_radians().cos();
                    z+=WALK_STEP*angle.to_radians().sin();
                },
                Action::West => if anim_timer % fps_mod == 0 {
                    x+=WALK_STEP*angle.to_radians().cos();
                    z-=WALK_STEP*angle.to_radians().sin();
                },
                Action::Up => if anim_timer % fps_mod == 0 {y+=WALK_STEP/18.},
                Action::Down => if anim_timer % fps_mod == 0 {y-=WALK_STEP/18.},
                Action::Clockwise => if anim_timer % fps_mod == 0{angle-=TURN_STEP as f32},
                Action::CounterClockwise => if anim_timer % fps_mod == 0{angle+=TURN_STEP as f32},
                Action::Mine => {
                    if anim_timer-1==0
                    {
                        let angle_ry = angle.to_radians().sin().round() as i32;
                        let angle_rx = angle.to_radians().cos().round() as i32;
                        match map[(map_y as i32-angle_ry) as usize][(map_x as i32 +angle_rx) as usize]
                        {
                            Parts::Vein(Ore::Coal) => resources[0] += 1,
                            Parts::Vein(Ore::Copper) => resources[1] += 1,
                            Parts::Vein(Ore::Iron) => resources[2] += 1,
                            Parts::Vein(Ore::Gold) => resources[3] += 1,
                            Parts::Vein(Ore::Diamond) => resources[4] += 1,
                            _ => ()
                        }
                        map[(map_y as i32-angle_ry) as usize][(map_x as i32 +angle_rx) as usize] = Parts::Wall;
                        /*match direction
                        {
                            Direction::North => if let Parts::Vein(ore) = &map[map_y-1][map_x]
                            {
                                match ore
                                {
                                    &Ore::Coal => resources[0] += 1,
                                    &Ore::Copper => resources[1] += 1,
                                    &Ore::Iron => resources[2] += 1,
                                    &Ore::Gold => resources[3] += 1,
                                    &Ore::Diamond => resources[4] += 1,
                                }
                                map[map_y-1][map_x] = Parts::Wall;
                            },
                            Direction::South => if let Parts::Vein(ore) = &map[map_y+1][map_x]
                            {
                                match ore
                                {
                                    &Ore::Coal => resources[0] += 1,
                                    &Ore::Copper => resources[1] += 1,
                                    &Ore::Iron => resources[2] += 1,
                                    &Ore::Gold => resources[3] += 1,
                                    &Ore::Diamond => resources[4] += 1,
                                }
                                map[map_y+1][map_x] = Parts::Wall;
                            },
                            Direction::East => if let Parts::Vein(ore) = &map[map_y][map_x+1]
                            {
                                match ore
                                {
                                    &Ore::Coal => resources[0] += 1,
                                    &Ore::Copper => resources[1] += 1,
                                    &Ore::Iron => resources[2] += 1,
                                    &Ore::Gold => resources[3] += 1,
                                    &Ore::Diamond => resources[4] += 1,
                                }
                                map[map_y][map_x+1] = Parts::Wall;
                            },
                            Direction::West => if let Parts::Vein(ore) = &map[map_y][map_x-1]
                            {
                                match ore
                                {
                                    &Ore::Coal => resources[0] += 1,
                                    &Ore::Copper => resources[1] += 1,
                                    &Ore::Iron => resources[2] += 1,
                                    &Ore::Gold => resources[3] += 1,
                                    &Ore::Diamond => resources[4] += 1,
                                }
                                map[map_y][map_x-1] = Parts::Wall;
                            }
                        }*/
                    }
                },
                Action::Attack =>(),
                Action::Idle => ()
            }
            }
            anim_timer -= 1;
        }

        /*if is_key_down(KeyCode::D)
        {
            z+=WALK_STEP*dt;
        }
        if is_key_down(KeyCode::A)
        {
            z-=WALK_STEP*dt;
        }
        if is_key_down(KeyCode::W)
        {
            x+=WALK_STEP*dt
        }
        if is_key_down(KeyCode::S)
        {
            x-=WALK_STEP*dt;
        }

        if is_key_down(KeyCode::Space)
        {
            y+=WALK_STEP*dt
        }
        if is_key_down(KeyCode::LeftShift)
        {
            y-=WALK_STEP*dt;
        }

        if is_key_down(KeyCode::Q)
        {
                angle+=TURN_STEP*dt;
        }
        if is_key_down(KeyCode::E)
        {
            angle-=TURN_STEP*dt;
        }*/

        clear_background(BLACK);

        // Going 3d!

        set_camera(&Camera3D {
            position: vec3(x, y+4., z),
            up: vec3(0., 1., 0.),
            target: vec3(x+angle.to_radians().sin()*8., y+4., z+angle.to_radians().cos()*8.),
            ..Default::default()
        });

        //draw_grid(24, 1., BLACK, GRAY);
        draw_plane(vec3(-4.,0.,-4.), vec2((map[0].len() as f32/2.)*8., (map.len() as f32/2.)*8.), rock, GRAY);
        draw_plane(vec3(-4.,8.,-4.), vec2((map[0].len() as f32/2.)*8., (map.len() as f32/2.)*8.), rock, DARKGRAY);

        /*draw_cube_wires(vec3(0., 1., -6.), vec3(2., 2., 2.), DARKGREEN);
        draw_cube_wires(vec3(0., 1., 6.), vec3(2., 2., 2.), DARKBLUE);
        draw_cube_wires(vec3(2., 1., 2.), vec3(2., 2., 2.), YELLOW);

        draw_plane(vec3(-8., 0., -8.), vec2(5., 5.), ferris, WHITE);

        draw_cube(vec3(-5., 1., -2.), vec3(2., 2., 2.), rust_logo, WHITE);
        draw_cube(vec3(-5., 1., 2.), vec3(2., 2., 2.), ferris, WHITE);
        draw_cube(vec3(2., 0., -2.), vec3(0.4, 0.4, 0.4), None, BLACK);

        draw_sphere(vec3(-8., 0., 0.), 1., None, BLUE);*/

        for my in 0..map.len() as i8
        {
            for mx in 0..map[my as usize].len() as i8
            {
                match map[map.len()-my as usize-1][mx as usize]
                {
                    Parts::Wall => draw_cube(vec3((my - map.len() as i8/2) as f32*8., 4., (mx - map[my as usize].len() as i8/2) as f32*8.), vec3(8., 8., 8.), rock, WHITE),
                    Parts::Vein(Ore::Diamond) => draw_cube(vec3((my - map.len() as i8/2) as f32*8., 4., (mx - map[my as usize].len() as i8/2) as f32*8.), vec3(8., 8., 8.), diamond, WHITE),
                    Parts::Vein(Ore::Gold) => draw_cube(vec3((my - map.len() as i8/2) as f32*8., 4., (mx - map[my as usize].len() as i8/2) as f32*8.), vec3(8., 8., 8.), gold, WHITE),
                    Parts::Vein(Ore::Iron) => draw_cube(vec3((my - map.len() as i8/2) as f32*8., 4., (mx - map[my as usize].len() as i8/2) as f32*8.), vec3(8., 8., 8.), iron, WHITE),
                    Parts::Elevator => draw_cube(vec3((my - map.len() as i8/2) as f32*8., 4., (mx - map[my as usize].len() as i8/2) as f32*8.), vec3(8., 8., 8.), elevator, WHITE),
                    //Parts::Vein(Ore::Bronze) => draw_cube(vec3((my - map.len() as i8/2) as f32*8., 4., (mx - map[my as usize].len() as i8/2) as f32*8.), vec3(8., 8., 8.), None, MAROON),
                    Parts::Vein(Ore::Copper) => draw_cube(vec3((my - map.len() as i8/2) as f32*8., 4., (mx - map[my as usize].len() as i8/2) as f32*8.), vec3(8., 8., 8.), copper, WHITE),
                    Parts::Vein(Ore::Coal) => draw_cube(vec3((my - map.len() as i8/2) as f32*8., 4., (mx - map[my as usize].len() as i8/2) as f32*8.), vec3(8., 8., 8.), coal, WHITE),
                    _ => ()
                }
                
            }
        }

        draw_cube(vec3(20., 1., -2.), vec3(0., 2., 2.), ferris, WHITE);

        //draw_cube(vec3(0., 4., -8.), vec3(48., 8., 8.), clay, DARKGRAY);
        //draw_cube(vec3(0., 4., 8.), vec3(48., 8., 8.), clay, DARKGRAY);

        // Back to screen space, render some text

        set_default_camera();

        draw_rectangle(0., 0., screen_width(), screen_height(), color_u8!(8,8,0,200));

        draw_rectangle(1280./10., 800./12., 1280./10.*8., 800./6., BLACK);

        draw_text(&format!("{},{},{}, {}, {}, {}, {}, {}*, {}, {}, {}, {:?}",x,y,z,map_x,map_y, -angle.to_radians().sin() as usize, angle.to_radians().cos() as usize,angle,get_fps(), anim_timer, fps_mod, direction).to_string(), 1280./10.+10.0, 800./12.+30.0, 30.0, LIME);

        draw_rectangle(0., 800./6.*5., 1280., 800./6., BLACK);

        if hovers(0., 1280., 800./6.*5., 800., mouse_position().0, mouse_position().1)
        {
            draw_rectangle(0., 800./6.*5., 1280., 800./6., RED);
        }

        draw_texture_ex(rust_logo, 0., 800./6.*5., WHITE, DrawTextureParams { dest_size: Some(Vec2::new(160.,800./6.)), source: None, rotation: 0., flip_x: false, flip_y: false, pivot: None });
        //draw_rectangle(128., 0., 32., 32., RED);
        

        next_frame().await
    }
}