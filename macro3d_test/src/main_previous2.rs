use bracket_random::prelude::RandomNumberGenerator;
use pathfinding::prelude::bfs;
use macroquad::{prelude::*, audio::{play_sound_once, load_sound_from_bytes}};
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

#[derive(PartialEq)]
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
    Shoot,
    Magic,
    Heal,
    Idle
}

/*enum NpcType
{
    Normal(String),
    Poor(String, u32)
}*/

#[derive(Clone,Copy,PartialEq)]
enum EnemyType
{
    Plebian,
    Mercenary,
    Swordfish,
    Gunslinger,
    Imp,
    Demon,
    Snitch,
    BigSnitch // AKA "Death the Snitch"
}

#[derive(Clone,Copy,PartialEq)]
struct Enemy{
    enemy_type: EnemyType,
    hp: f32
}

#[derive(PartialEq)]
enum Parts
{
    Empty,
    Wall,
    Vein(Ore),
    Player(f32),
    //Npc(NpcType),
    Stairs,
    Elevator,
    Enemy(Enemy)
}

enum State
{
    Normal,
    Combat(Enemy)
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

#[derive(Clone, Debug, Eq, Hash, Ord, PartialEq, PartialOrd)]
struct Pos(usize, usize);

impl Pos {
  fn successors(&self) -> Vec<Pos> {
    let &Pos(x, y) = self;
    vec![Pos(x+1,y), Pos((x as i32-1).clamp(0,999) as usize,y), Pos(x,y+1), Pos(x,(y as i32-1).clamp(0,999) as usize)]
  }
}

/*fn rotate_cube(gl: &mut QuadGl, position: Vec3, rotation: Vec3, size: Vec3, texture: impl Into<Option<Texture2D>>, color: Color)
{
    draw_cube(vec3(20., 1., -2.), vec3(0., 2., 2.), texture, WHITE);
    gl.push_model_matrix(glam::Mat4::from_translation(position));
    gl.push_model_matrix(glam::Mat4::from_scale(size));
    gl.push_model_matrix(glam::Mat4::from_rotation_x(rotation.x));
    gl.push_model_matrix(glam::Mat4::from_rotation_y(rotation.y));
    gl.push_model_matrix(glam::Mat4::from_rotation_z(rotation.z));
    gl.pop_model_matrix();
}*/

#[macroquad::main(window_conf)]
async fn main() {

    // TEXTURES

    let ferris = load_texture("../ferris.png").await.unwrap();

    let clay = load_texture("../funky.png").await.unwrap(); clay.set_filter(FilterMode::Nearest);
    let rock = load_texture("../rock.png").await.unwrap(); rock.set_filter(FilterMode::Nearest);
    let coal = load_texture("../coal.png").await.unwrap(); coal.set_filter(FilterMode::Nearest);
    let copper = load_texture("../copper.png").await.unwrap(); copper.set_filter(FilterMode::Nearest);
    let iron = load_texture("../iron.png").await.unwrap(); iron.set_filter(FilterMode::Nearest);
    let gold = load_texture("../gold.png").await.unwrap(); gold.set_filter(FilterMode::Nearest);
    let diamond = load_texture("../diamond.png").await.unwrap(); diamond.set_filter(FilterMode::Nearest);
    let elevator = load_texture("../elevator.png").await.unwrap(); elevator.set_filter(FilterMode::Nearest);

    let plebian = load_texture("../plebian.png").await.unwrap(); plebian.set_filter(FilterMode::Nearest);
    let mercenary = load_texture("../mercenary.png").await.unwrap(); mercenary.set_filter(FilterMode::Nearest);
    let gunslinger = load_texture("../gunslinger.png").await.unwrap(); gunslinger.set_filter(FilterMode::Nearest);

    let snitch = load_texture("../snitch.png").await.unwrap(); snitch.set_filter(FilterMode::Nearest);

    let bar = load_texture("../bar.png").await.unwrap(); bar.set_filter(FilterMode::Nearest);
    let coal_i = load_texture("../coal_i.png").await.unwrap(); coal_i.set_filter(FilterMode::Nearest);
    let copper_i = load_texture("../copper_i.png").await.unwrap(); copper_i.set_filter(FilterMode::Nearest);
    let iron_i = load_texture("../iron_i.png").await.unwrap(); iron_i.set_filter(FilterMode::Nearest);
    let gold_i = load_texture("../gold_i.png").await.unwrap(); gold_i.set_filter(FilterMode::Nearest);
    let diamond_i = load_texture("../diamond_i.png").await.unwrap(); diamond_i.set_filter(FilterMode::Nearest);

    // SOUNDS

    let footstep = load_sound_from_bytes(load_file("../footstep.ogg").await.unwrap().as_slice()).await.unwrap();


    // let limit = Lim::limit(&mut self);
    //let idiot = load_texture("../me.png").await.unwrap();

    let mut x: f32 = 0.;
    let mut y: f32 = 0.;
    let mut z: f32 = 0.;
    let mut angle: f32 = 90.;
    let mut anim_timer: i32 = 0;
    let mut hp = 200.;
    let mut money = 0.;
    // coal: 50
    // copper: 75
    // iron: 250
    // gold: 2000
    // diamond: 10000
    let mut paused = false;
    let mut control = true;

    let mut resources = [0,0,0,0,0];

    let mut direction = Direction::North;
    let mut action = Action::Idle;

    let mut map = [[[Parts::Wall,Parts::Wall,Parts::Wall,Parts::Wall,Parts::Wall,Parts::Vein(Ore::Copper),Parts::Vein(Ore::Coal),Parts::Wall,Parts::Wall,Parts::Wall],
    [Parts::Wall,Parts::Enemy(Enemy{enemy_type: EnemyType::Snitch, hp: 20.}),Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
    [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Enemy(Enemy{enemy_type: EnemyType::Mercenary, hp: 60.}),Parts::Enemy(Enemy{enemy_type: EnemyType::Plebian, hp: 30.}),Parts::Empty,Parts::Elevator,Parts::Empty,Parts::Wall],
    [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
    [Parts::Wall,Parts::Wall,Parts::Empty,Parts::Vein(Ore::Gold),Parts::Empty,Parts::Empty,Parts::Vein(Ore::Diamond),Parts::Empty,Parts::Wall,Parts::Wall],
    [Parts::Wall,Parts::Wall,Parts::Empty,Parts::Wall,Parts::Empty,Parts::Empty,Parts::Wall,Parts::Empty,Parts::Wall,Parts::Wall],
    [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
    [Parts::Wall,Parts::Empty,Parts::Player(0.),Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
    [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Enemy(Enemy{enemy_type: EnemyType::Gunslinger, hp: 40.}),Parts::Empty,Parts::Wall],
    [Parts::Wall,Parts::Wall,Parts::Wall,Parts::Vein(Ore::Iron),Parts::Stairs,Parts::Stairs,Parts::Vein(Ore::Iron),Parts::Wall,Parts::Wall,Parts::Wall]],
    [[Parts::Wall,Parts::Wall,Parts::Wall,Parts::Wall,Parts::Wall,Parts::Vein(Ore::Copper),Parts::Vein(Ore::Coal),Parts::Wall,Parts::Wall,Parts::Wall],
    [Parts::Wall,Parts::Enemy(Enemy{enemy_type: EnemyType::Snitch, hp: 20.}),Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
    [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Enemy(Enemy{enemy_type: EnemyType::Mercenary, hp: 60.}),Parts::Enemy(Enemy{enemy_type: EnemyType::Plebian, hp: 30.}),Parts::Empty,Parts::Elevator,Parts::Empty,Parts::Wall],
    [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
    [Parts::Wall,Parts::Wall,Parts::Empty,Parts::Vein(Ore::Gold),Parts::Empty,Parts::Empty,Parts::Vein(Ore::Diamond),Parts::Empty,Parts::Wall,Parts::Wall],
    [Parts::Wall,Parts::Wall,Parts::Empty,Parts::Wall,Parts::Empty,Parts::Empty,Parts::Wall,Parts::Empty,Parts::Wall,Parts::Wall],
    [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
    [Parts::Wall,Parts::Empty,Parts::Player(0.),Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
    [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Enemy(Enemy{enemy_type: EnemyType::Gunslinger, hp: 40.}),Parts::Empty,Parts::Wall],
    [Parts::Wall,Parts::Wall,Parts::Wall,Parts::Vein(Ore::Iron),Parts::Stairs,Parts::Stairs,Parts::Vein(Ore::Iron),Parts::Wall,Parts::Wall,Parts::Wall]],
    [[Parts::Wall,Parts::Wall,Parts::Wall,Parts::Wall,Parts::Wall,Parts::Vein(Ore::Copper),Parts::Vein(Ore::Coal),Parts::Wall,Parts::Wall,Parts::Wall],
    [Parts::Wall,Parts::Enemy(Enemy{enemy_type: EnemyType::Snitch, hp: 20.}),Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
    [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Enemy(Enemy{enemy_type: EnemyType::Mercenary, hp: 60.}),Parts::Enemy(Enemy{enemy_type: EnemyType::Plebian, hp: 30.}),Parts::Empty,Parts::Elevator,Parts::Empty,Parts::Wall],
    [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
    [Parts::Wall,Parts::Wall,Parts::Empty,Parts::Vein(Ore::Gold),Parts::Empty,Parts::Empty,Parts::Vein(Ore::Diamond),Parts::Empty,Parts::Wall,Parts::Wall],
    [Parts::Wall,Parts::Wall,Parts::Empty,Parts::Wall,Parts::Empty,Parts::Empty,Parts::Wall,Parts::Empty,Parts::Wall,Parts::Wall],
    [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
    [Parts::Wall,Parts::Empty,Parts::Player(0.),Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
    [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Enemy(Enemy{enemy_type: EnemyType::Gunslinger, hp: 40.}),Parts::Empty,Parts::Wall],
    [Parts::Wall,Parts::Wall,Parts::Wall,Parts::Vein(Ore::Iron),Parts::Stairs,Parts::Stairs,Parts::Vein(Ore::Iron),Parts::Wall,Parts::Wall,Parts::Wall]]];

    /*[[
        [Parts::Wall,Parts::Wall,Parts::Wall,Parts::Wall,Parts::Wall,Parts::Vein(Ore::Copper),Parts::Vein(Ore::Coal),Parts::Wall,Parts::Wall,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Elevator,Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Wall,Parts::Empty,Parts::Vein(Ore::Gold),Parts::Empty,Parts::Empty,Parts::Vein(Ore::Diamond),Parts::Empty,Parts::Wall,Parts::Wall],
        [Parts::Wall,Parts::Wall,Parts::Empty,Parts::Wall,Parts::Empty,Parts::Empty,Parts::Wall,Parts::Empty,Parts::Wall,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Player(0.),Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Enemy(Enemy{enemy_type: EnemyType::Plebian, hp: 69.}),Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Wall,Parts::Wall,Parts::Vein(Ore::Iron),Parts::Stairs,Parts::Stairs,Parts::Vein(Ore::Iron),Parts::Wall,Parts::Wall,Parts::Wall]
    ],
    [
        [Parts::Wall,Parts::Wall,Parts::Wall,Parts::Wall,Parts::Wall,Parts::Vein(Ore::Copper),Parts::Vein(Ore::Coal),Parts::Wall,Parts::Wall,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Elevator,Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Wall,Parts::Empty,Parts::Vein(Ore::Gold),Parts::Empty,Parts::Empty,Parts::Vein(Ore::Diamond),Parts::Empty,Parts::Wall,Parts::Wall],
        [Parts::Wall,Parts::Wall,Parts::Empty,Parts::Wall,Parts::Empty,Parts::Empty,Parts::Wall,Parts::Empty,Parts::Wall,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Enemy(Enemy{enemy_type: EnemyType::Plebian, hp: 69.}),Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Wall,Parts::Wall,Parts::Vein(Ore::Iron),Parts::Stairs,Parts::Stairs,Parts::Vein(Ore::Iron),Parts::Wall,Parts::Wall,Parts::Wall]
    ],
    [
        [Parts::Wall,Parts::Wall,Parts::Wall,Parts::Wall,Parts::Wall,Parts::Vein(Ore::Copper),Parts::Vein(Ore::Coal),Parts::Wall,Parts::Wall,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Elevator,Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Wall,Parts::Empty,Parts::Vein(Ore::Gold),Parts::Empty,Parts::Empty,Parts::Vein(Ore::Diamond),Parts::Empty,Parts::Wall,Parts::Wall],
        [Parts::Wall,Parts::Wall,Parts::Empty,Parts::Wall,Parts::Empty,Parts::Empty,Parts::Wall,Parts::Empty,Parts::Wall,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Enemy(Enemy{enemy_type: EnemyType::Plebian, hp: 69.}),Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Wall,Parts::Wall,Parts::Vein(Ore::Iron),Parts::Stairs,Parts::Stairs,Parts::Vein(Ore::Iron),Parts::Wall,Parts::Wall,Parts::Wall]
    ],
    [
        [Parts::Wall,Parts::Wall,Parts::Wall,Parts::Wall,Parts::Wall,Parts::Vein(Ore::Copper),Parts::Vein(Ore::Coal),Parts::Wall,Parts::Wall,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Elevator,Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Wall,Parts::Empty,Parts::Vein(Ore::Gold),Parts::Empty,Parts::Empty,Parts::Vein(Ore::Diamond),Parts::Empty,Parts::Wall,Parts::Wall],
        [Parts::Wall,Parts::Wall,Parts::Empty,Parts::Wall,Parts::Empty,Parts::Empty,Parts::Wall,Parts::Empty,Parts::Wall,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Enemy(Enemy{enemy_type: EnemyType::Plebian, hp: 69.}),Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Wall,Parts::Wall,Parts::Vein(Ore::Iron),Parts::Stairs,Parts::Stairs,Parts::Vein(Ore::Iron),Parts::Wall,Parts::Wall,Parts::Wall]
    ],
    [
        [Parts::Wall,Parts::Wall,Parts::Wall,Parts::Wall,Parts::Wall,Parts::Vein(Ore::Copper),Parts::Vein(Ore::Coal),Parts::Wall,Parts::Wall,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Elevator,Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Wall,Parts::Empty,Parts::Vein(Ore::Gold),Parts::Empty,Parts::Empty,Parts::Vein(Ore::Diamond),Parts::Empty,Parts::Wall,Parts::Wall],
        [Parts::Wall,Parts::Wall,Parts::Empty,Parts::Wall,Parts::Empty,Parts::Empty,Parts::Wall,Parts::Empty,Parts::Wall,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Enemy(Enemy{enemy_type: EnemyType::Plebian, hp: 69.}),Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Empty,Parts::Wall],
        [Parts::Wall,Parts::Wall,Parts::Wall,Parts::Vein(Ore::Iron),Parts::Stairs,Parts::Stairs,Parts::Vein(Ore::Iron),Parts::Wall,Parts::Wall,Parts::Wall]
    ]];*/

    'p:for mz in 0..map.len()
    {
        for my in 0..map[mz].len() as i8
    {
        for mx in 0..map[mz][my as usize].len() as i8
        {
            if let Parts::Player(_) = &map[mz][map[mz].len()-my as usize-1][mx as usize]
            {
                z = (mx - map[mz][my as usize].len() as i8/2) as f32*8.;
                x = (my - map[mz].len() as i8/2) as f32*8.;
                y = mz as f32*-8.;
                break 'p;
            }
        }
                
    }
    } 
    

    while hp >= 1. {

        let mut rng = RandomNumberGenerator::new();

        let map_z = -(y/8.) as usize;
        let map_y = map[map_z].len()-(x/8.+map[map_z].len() as f32/2.) as usize-1;
        let map_x = (z/8.+map[map_z][map_y].len() as f32/2.) as usize;

        let fps_mod = 4;

        if is_key_pressed(KeyCode::Escape)
        {
            paused = !paused;
        }

        if anim_timer == 0 && !paused
        {
            action = Action::Idle;

            x = x.round();
            y = y.round();
            z = z.round();

           /* if let Parts::Enemy(enemy) = &map[map_x+1][map_y]
            {
                state = State::Combat(enemy.clone());
            }
            else if let Parts::Enemy(enemy) = &map[map_x-1][map_y]
            {
                state = State::Combat(enemy.clone());
            }
            else if let Parts::Enemy(enemy) = &map[map_x][map_y+1]
            {
                state = State::Combat(enemy.clone());
            }
            else if let Parts::Enemy(enemy) = &map[map_x][map_y-1]
            {
                state = State::Combat(enemy.clone());
            }*/

            if control
            {
                if is_key_pressed(KeyCode::H) || hovers(512., 575., 736., 800., mouse_position().0, mouse_position().1) && is_mouse_button_pressed(MouseButton::Left)
            {
                let angle_ry = angle.to_radians().sin().round() as i32;
                let angle_rx = angle.to_radians().cos().round() as i32;
                println!("{},{}",angle_ry,angle_rx);
                match map[map_z][(map_y as i32-angle_ry) as usize][(map_x as i32 +angle_rx) as usize]
                {
                    Parts::Vein(_) => { action = Action::Mine; anim_timer = 60*fps_mod;},
                    Parts::Enemy(_) => { action = Action::Mine; anim_timer = 60*fps_mod;},
                    _ => ()
                }
            }
            else if is_key_pressed(KeyCode::J) || hovers(576., 589., 736., 800., mouse_position().0, mouse_position().1) && is_mouse_button_pressed(MouseButton::Left)
            {
                action = Action::Shoot;
                anim_timer = 120*fps_mod;
            }
            else if is_key_pressed(KeyCode::K) || hovers(590., 5653., 736., 800., mouse_position().0, mouse_position().1) && is_mouse_button_pressed(MouseButton::Left)
            {
                for r in 0..5 {
                    if resources[r] > 0
                    {
                        action = Action::Magic;
                        anim_timer = 120*fps_mod;
                        break;
                    }
                
                }
            }
            else if is_key_pressed(KeyCode::L) || hovers(654., 717., 736., 800., mouse_position().0, mouse_position().1) && is_mouse_button_pressed(MouseButton::Left)
            {
                for r in 0..5 {
                    if resources[r] > 0
                    {
                        action = Action::Heal;
                        anim_timer = 120*fps_mod;
                        break;
                    }
                
                }
            }

            if is_key_pressed(KeyCode::D)
            {
                let angle_ry = angle.to_radians().cos().round() as i32;
                let angle_rx = angle.to_radians().sin().round() as i32;
                if let Parts::Empty = &map[map_z][(map_y as i32+angle_ry) as usize][(map_x as i32 +angle_rx) as usize] {
                    map[map_z][map_y][map_x] = Parts::Empty;
                    map[map_z][(map_y as i32+angle_ry) as usize][(map_x as i32 +angle_rx) as usize] = Parts::Player(0.);
                    action = Action::East;
                    anim_timer = 10*fps_mod;
                    play_sound_once(footstep);
                }
                
            }
            else if is_key_pressed(KeyCode::A)
            {
                let angle_ry = angle.to_radians().cos().round() as i32;
                let angle_rx = angle.to_radians().sin().round() as i32;
                if let Parts::Empty = &map[map_z][(map_y as i32-angle_ry) as usize][(map_x as i32-angle_rx) as usize] {
                    map[map_z][map_y][map_x] = Parts::Empty;
                    map[map_z][(map_y as i32-angle_ry) as usize][(map_x as i32-angle_rx) as usize] = Parts::Player(0.);
                    action = Action::West;
                    anim_timer = 10*fps_mod;
                    play_sound_once(footstep)
                }
            }
            else if is_key_pressed(KeyCode::W)
            {
                let angle_ry = angle.to_radians().sin().round() as i32;
                let angle_rx = angle.to_radians().cos().round() as i32;
                if let Parts::Empty = &map[map_z][(map_y as i32-angle_ry) as usize][(map_x as i32 +angle_rx) as usize] {
                    map[map_z][map_y][map_x] = Parts::Empty;
                    map[map_z][(map_y as i32-angle_ry) as usize][(map_x as i32 +angle_rx) as usize] = Parts::Player(0.);
                    action = Action::North;
                    anim_timer = 10*fps_mod;
                    play_sound_once(footstep)
                }
            }
            else if is_key_pressed(KeyCode::S)
            {
                let angle_ry = angle.to_radians().sin().round() as i32;
                let angle_rx = angle.to_radians().cos().round() as i32;
                if let Parts::Empty = &map[map_z][(map_y as i32+angle_ry) as usize][(map_x as i32 -angle_rx) as usize] {
                    map[map_z][map_y][map_x] = Parts::Empty;
                    map[map_z][(map_y as i32+angle_ry) as usize][(map_x as i32 -angle_rx) as usize] = Parts::Player(0.);
                    action = Action::South;
                    anim_timer = 10*fps_mod;
                    play_sound_once(footstep)
                }
            }

            if is_key_pressed(KeyCode::Space) && map_z > 0
            {
                let angle_ry = angle.to_radians().sin().round() as i32;
                let angle_rx = angle.to_radians().cos().round() as i32;
                println!("{},{}",angle_ry,angle_rx);
                if let Parts::Elevator = &map[map_z][(map_y as i32-angle_ry) as usize][(map_x as i32 +angle_rx) as usize] {
                    action = Action::Up;
                    anim_timer = 180*fps_mod;
                }
            }
            if is_key_pressed(KeyCode::LeftShift) && map_z < 2
            {
                let angle_ry = angle.to_radians().sin().round() as i32;
                let angle_rx = angle.to_radians().cos().round() as i32;
                println!("{},{}",angle_ry,angle_rx);
                if let Parts::Elevator = &map[map_z][(map_y as i32-angle_ry) as usize][(map_x as i32 +angle_rx) as usize] {
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
            else
            {
                    for my in 0..map[map_z].len()
                    {           
                        for mx in 0..map[map_z][my].len()
                        {
                            if let Parts::Enemy(enemy) = map[map_z][my][mx]
                            {
                                if let Parts::Player(_) = map[map_z][my][mx+1]
                                {
                                    match enemy.enemy_type
                                    {
                                        EnemyType::Plebian => hp -= 20.,
                                        EnemyType::Mercenary => hp -= 40.,
                                        EnemyType::Gunslinger => (),
                                        EnemyType::Swordfish => hp -= 80.,
                                        EnemyType::Snitch => 'r: for r in 0..5 {
                                            if resources[r] > 0
                                            {
                                                let mut resource: usize = rng.range(0, 5);
                                                loop
                                                {
                                                    if resources[resource] > 0
                                                    {
                                                        resources[resource] -= 1;
                                                        map[map_z][my][mx+1] = Parts::Empty;
                                                        break 'r;
                                                    }
                                                    resource = rng.range(0, 5);
                                                }
                                
                                            }
                        
                                        },
                                        _ => ()
                                    }
                                }
                                else if let Parts::Player(_) = map[map_z][my][mx-1]
                                {
                                    match enemy.enemy_type
                                    {
                                        EnemyType::Plebian => hp -= 20.,
                                        EnemyType::Mercenary => hp -= 40.,
                                        EnemyType::Gunslinger => (),
                                        EnemyType::Swordfish => hp -= 80.,
                                        EnemyType::Snitch => 'r: for r in 0..5 {
                                            if resources[r] > 0
                                            {
                                                let mut resource: usize = rng.range(0, 5);
                                                loop
                                                {
                                                    if resources[resource] > 0
                                                    {
                                                        resources[resource] -= 1;
                                                        map[map_z][my][mx-1] = Parts::Empty;
                                                        break 'r;
                                                    }
                                                    resource = rng.range(0, 5);
                                                }
                                
                                            }
                        
                                        },
                                        _ => ()
                                    }
                                }
                                else if let Parts::Player(_) = map[map_z][my+1][mx]
                                {
                                    match enemy.enemy_type
                                    {
                                        EnemyType::Plebian => hp -= 20.,
                                        EnemyType::Mercenary => hp -= 40.,
                                        EnemyType::Gunslinger => (),
                                        EnemyType::Swordfish => hp -= 80.,
                                        EnemyType::Snitch => 'r: for r in 0..5 {
                                            if resources[r] > 0
                                            {
                                                let mut resource: usize = rng.range(0, 5);
                                                loop
                                                {
                                                    if resources[resource] > 0
                                                    {
                                                        resources[resource] -= 1;
                                                        map[map_z][my+1][mx] = Parts::Empty;
                                                        break 'r;
                                                    }
                                                    resource = rng.range(0, 5);
                                                }
                                
                                            }
                        
                                        },
                                        _ => ()
                                    }
                                }
                                else if let Parts::Player(_) = map[map_z][my-1][mx]
                                {
                                    match enemy.enemy_type
                                    {
                                        EnemyType::Plebian => hp -= 20.,
                                        EnemyType::Mercenary => hp -= 40.,
                                        EnemyType::Gunslinger => (),
                                        EnemyType::Swordfish => hp -= 80.,
                                        EnemyType::Snitch => 'r: for r in 0..5 {
                                            if resources[r] > 0
                                            {
                                                let mut resource: usize = rng.range(0, 5);
                                                loop
                                                {
                                                    if resources[resource] > 0
                                                    {
                                                        resources[resource] -= 1;
                                                        map[map_z][my-1][mx] = Parts::Empty;
                                                        break 'r;
                                                    }
                                                    resource = rng.range(0, 5);
                                                }
                                
                                            }
                        
                                        },
                                        _ => ()
                                    }
                                }
                                else
                                {
                                    let result = bfs(&Pos(my, mx), |p| p.successors(), |p| *p == Pos(map_y, map_x)).unwrap();
                                    map[map_z][my][mx] = Parts::Empty;
                                    map[map_z][result[0].1][result[0].0] = Parts::Enemy(enemy);
                                    for pos in 0..result.len()
                                    {
                                        match map[map_z][result[pos].1][result[pos].0]
                                        {
                                            Parts::Empty => (),
                                            Parts::Player(_) => {
                                                map[map_z][result[pos].1][result[pos].0] = Parts::Empty;
                                                map[map_z][result[pos-1].1][result[pos-1].0] = Parts::Enemy(enemy);
                                            },
                                            _=> {
                                                map[map_z][my][mx] = Parts::Empty;
                                                map[map_z][result[0].1][result[0].0] = Parts::Enemy(enemy);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                
                    }
                /*if let Parts::Enemy(enemy) = &map[map_z][map_y][map_x+1]
                {
                    match enemy.enemy_type
                    {
                        EnemyType::Plebian => hp -= 20.,
                        EnemyType::Mercenary => hp -= 40.,
                        EnemyType::Gunslinger => (),
                        EnemyType::Swordfish => hp -= 80.,
                        EnemyType::Snitch => 'r: for r in 0..5 {
                            if resources[r] > 0
                            {
                                let mut resource: usize = rng.range(0, 5);
                                loop
                                {
                                    if resources[resource] > 0
                                    {
                                        resources[resource] -= 1;
                                        map[map_z][map_y][map_x+1] = Parts::Empty;
                                        break 'r;
                                    }
                                    resource = rng.range(0, 5);
                                }
                                
                            }
                        
                        },
                        _ => ()
                    }
                }
                if let Parts::Enemy(enemy) = &map[map_z][map_y+1][map_x]
                {
                    match enemy.enemy_type
                    {
                        EnemyType::Plebian => hp -= 20.,
                        EnemyType::Mercenary => hp -= 40.,
                        EnemyType::Gunslinger => (),
                        EnemyType::Swordfish => hp -= 80.,
                        EnemyType::Snitch => 'r: for r in 0..5 {
                            if resources[r] > 0
                            {
                                let mut resource: usize = rng.range(0, 5);
                                loop
                                {
                                    if resources[resource] > 0
                                    {
                                        resources[resource] -= 1;
                                        map[map_z][map_y+1][map_x] = Parts::Empty;
                                        break 'r;
                                    }
                                    resource = rng.range(0, 5);
                                }
                                
                            }
                        
                        },
                        _ => ()
                    }
                }
                if let Parts::Enemy(enemy) = &map[map_z][map_y][map_x-1]
                {
                    match enemy.enemy_type
                    {
                        EnemyType::Plebian => hp -= 20.,
                        EnemyType::Mercenary => hp -= 40.,
                        EnemyType::Gunslinger => (),
                        EnemyType::Swordfish => hp -= 80.,
                        EnemyType::Snitch => 'r: for r in 0..5 {
                            if resources[r] > 0
                            {
                                let mut resource: usize = rng.range(0, 5);
                                loop
                                {
                                    if resources[resource] > 0
                                    {
                                        resources[resource] -= 1;
                                        map[map_z][map_y][map_x-1] = Parts::Empty;
                                        break 'r;
                                    }
                                    resource = rng.range(0, 5);
                                }
                                
                            }
                        
                        },
                        _ => ()
                    }
                }
                if let Parts::Enemy(enemy) = &map[map_z][map_y-1][map_x]
                {
                    match enemy.enemy_type
                    {
                        EnemyType::Plebian => hp -= 20.,
                        EnemyType::Mercenary => hp -= 40.,
                        EnemyType::Gunslinger => (),
                        EnemyType::Swordfish => hp -= 80.,
                        EnemyType::Snitch => 'r: for r in 0..5 {
                            if resources[r] > 0
                            {
                                let mut resource: usize = rng.range(0, 5);
                                loop
                                {
                                    if resources[resource] > 0
                                    {
                                        resources[resource] -= 1;
                                        map[map_z][map_y-1][map_x] = Parts::Empty;
                                        break 'r;
                                    }
                                    resource = rng.range(0, 5);
                                }
                                
                            }
                        
                        },
                        _ => ()
                    }
                }*/
            let mut distance: i32 = 1;
            loop
            {
                match map[map_z][map_y][map_x+distance as usize]
                {
                    Parts::Enemy(enemy) => if let EnemyType::Gunslinger = enemy.enemy_type {
                        hp -= 20.;
                        println!("ouch");
                    },
                    Parts::Empty => (),
                    _ => break
                }
                distance += 1;
            }
            distance = 1;
            loop
            {
                let map_x = map_x as i32;
                match map[map_z][map_y][(map_x-distance) as usize]
                {
                    Parts::Enemy(enemy) => if let EnemyType::Gunslinger = enemy.enemy_type {
                        hp -= 20.;
                        println!("ouch");
                    },
                    Parts::Empty => (),
                    _ => break
                }
                distance += 1;
            }
            distance = 1;
            loop
            {
                match map[map_z][map_y+distance as usize][map_x]
                {
                    Parts::Enemy(enemy) => if let EnemyType::Gunslinger = enemy.enemy_type {
                        hp -= 20.;
                        println!("ouch");
                    },
                    Parts::Empty => (),
                    _ => break
                }
                distance += 1;
            }
            distance = 1;
            loop
            {
                let map_y = map_y as i32;
                match map[map_z][(map_y-distance) as usize][map_x]
                {
                    Parts::Enemy(enemy) => if let EnemyType::Gunslinger = enemy.enemy_type {
                        hp -= 20.;
                        println!("ouch");
                    },
                    Parts::Empty => (),
                    _ => break
                }
                distance += 1;
            }
            }

            control = true;

        }
            
        if anim_timer > 0 && !paused && control
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
                        match map[map_z][(map_y as i32-angle_ry) as usize][(map_x as i32 +angle_rx) as usize]
                        {
                            Parts::Vein(Ore::Coal) => {resources[0] += 1; map[map_z][(map_y as i32-angle_ry) as usize][(map_x as i32 +angle_rx) as usize] = Parts::Wall;},
                            Parts::Vein(Ore::Copper) => {resources[1] += 1; map[map_z][(map_y as i32-angle_ry) as usize][(map_x as i32 +angle_rx) as usize] = Parts::Wall;},
                            Parts::Vein(Ore::Iron) => {resources[2] += 1; map[map_z][(map_y as i32-angle_ry) as usize][(map_x as i32 +angle_rx) as usize] = Parts::Wall;},
                            Parts::Vein(Ore::Gold) => {resources[3] += 1; map[map_z][(map_y as i32-angle_ry) as usize][(map_x as i32 +angle_rx) as usize] = Parts::Wall;},
                            Parts::Vein(Ore::Diamond) => {resources[4] += 1; map[map_z][(map_y as i32-angle_ry) as usize][(map_x as i32 +angle_rx) as usize] = Parts::Wall;},
                            Parts::Enemy(mut enemy) => {
                                enemy.hp -= 25.;
                                map[map_z][(map_y as i32-angle_ry) as usize][(map_x as i32 +angle_rx) as usize] = Parts::Enemy(enemy);
                                if enemy.hp.ceil() < 1.
                                {
                                    map[map_z][(map_y as i32-angle_ry) as usize][(map_x as i32 +angle_rx) as usize] = Parts::Empty;
                                }
                            }
                            _ => ()
                        }
                    }
                },
                Action::Shoot => {
                    if anim_timer-1==0
                    {
                        let angle_ry = angle.to_radians().sin().round() as i32;
                        let angle_rx = angle.to_radians().cos().round() as i32;
                        let mut distance = 1;

                        loop 
                        {
                            match map[map_z][(map_y as i32-angle_ry*distance) as usize][(map_x as i32 +angle_rx*distance) as usize]
                            {
                                Parts::Empty => distance+=1,
                                Parts::Player(_) => distance+=1,
                                Parts::Enemy(mut enemy) => {
                                    if let EnemyType::Mercenary = enemy.enemy_type
                                    {
                                        enemy.hp-=((30.-(distance-1) as f32).clamp(0.,200.)/4.).round(); 
                                    }
                                    else
                                    {
                                        enemy.hp-=(30.-(distance-1) as f32).clamp(0.,200.); 
                                    }
                                    map[map_z][(map_y as i32-angle_ry*distance) as usize][(map_x as i32 +angle_rx*distance) as usize] = Parts::Enemy(enemy);
                                    if enemy.hp.ceil() < 1.
                                    {
                                        map[map_z][(map_y as i32-angle_ry*distance) as usize][(map_x as i32 +angle_rx*distance) as usize] = Parts::Empty;
                                    }
                                    break;
                                },
                                _ => break
                            }
                        }
                    }

                    
                },
                Action::Magic=> if anim_timer-1==0
                {
                        let angle_ry = angle.to_radians().sin().round() as i32;
                        let angle_rx = angle.to_radians().cos().round() as i32;
                        let mut distance = 1;

                        for r in 0..5 {
                            if resources[r] > 0
                            {
                                resources[r] -= 1;
                                loop 
                                {
                                    match map[map_z][(map_y as i32-angle_ry*distance) as usize][(map_x as i32 +angle_rx*distance) as usize]
                                    {
                                        Parts::Empty => distance+=1,
                                        Parts::Player(_) => distance+=1,
                                        Parts::Enemy(mut enemy) => {
                                            enemy.hp-=(50.*r as f32-(distance-1) as f32*5.*r as f32).clamp(0.,200.); 
                                            map[map_z][(map_y as i32-angle_ry*distance) as usize][(map_x as i32 +angle_rx*distance) as usize] = Parts::Enemy(enemy);
                                            if enemy.hp.ceil() < 1.
                                            {
                                                map[map_z][(map_y as i32-angle_ry*distance) as usize][(map_x as i32 +angle_rx*distance) as usize] = Parts::Empty;
                                            }
                                            break;
                                        },
                                         _ => break
                                    }
                                }
                                break;
                            }
                        }
                },
                Action::Heal => if anim_timer-1==0 { for r in 0..5 {
                    if resources[r] > 0
                    {
                        resources[r] -= 1;
                        hp += 20.*(r as f32+1.);
                        break;
                        
                    } } },
                _ => ()
                }
            anim_timer -= 1;
            if anim_timer == 0
            {
                match action
                {
                    Action::Clockwise => (),
                    Action::CounterClockwise => (),
                    _ => control = false
                }
            }
        }
        else if anim_timer > 0 && !paused && !control
        {

        }

        clear_background(LIGHTGRAY);

        // Going 3d!

        set_camera(&Camera3D {
            position: vec3(x, y+4., z),
            up: vec3(0., 1., 0.),
            target: vec3(x+angle.to_radians().sin()*8., y+4., z+angle.to_radians().cos()*8.),
            ..Default::default()
        });

        //draw_grid(24, 1., BLACK, GRAY);

        /*draw_cube_wires(vec3(0., 1., -6.), vec3(2., 2., 2.), DARKGREEN);
        draw_cube_wires(vec3(0., 1., 6.), vec3(2., 2., 2.), DARKBLUE);
        draw_cube_wires(vec3(2., 1., 2.), vec3(2., 2., 2.), YELLOW);

        draw_plane(vec3(-8., 0., -8.), vec2(5., 5.), ferris, WHITE);

        draw_cube(vec3(-5., 1., -2.), vec3(2., 2., 2.), rust_logo, WHITE);
        draw_cube(vec3(-5., 1., 2.), vec3(2., 2., 2.), ferris, WHITE);
        draw_cube(vec3(2., 0., -2.), vec3(0.4, 0.4, 0.4), None, BLACK);

        draw_sphere(vec3(-8., 0., 0.), 1., None, BLUE);*/
        draw_plane(vec3(-4.,8.,-4.), vec2((map[map_z][map_y].len() as f32/2.)*8., (map[map_z].len() as f32/2.)*8.), rock, GRAY);
        for mz in 0..map.len()
        {
            draw_plane(vec3(-4.,mz as f32*-8.,-4.), vec2((map[map_z][map_y].len() as f32/2.)*8., (map[map_z].len() as f32/2.)*8.), rock, GRAY);
            //draw_plane(vec3(-4.,8.,-4.), vec2((map[map_z][map_y].len() as f32/2.)*8., (map[map_z].len() as f32/2.)*8.), rock, DARKGRAY);
        }


        for mz in 0..map.len()
        {
            if ((-y)/8.).round() as usize == mz
            {
                for my in 0..map[mz].len() as i8
                {
                    for mx in 0..map[mz][my as usize].len() as i8
                    {
                        match map[mz][map[mz].len()-my as usize-1][mx as usize]
                        {
                             Parts::Wall => draw_cube(vec3((my - map[mz].len() as i8/2) as f32*8., 4.+mz as f32*-8., (mx - map[mz][my as usize].len() as i8/2) as f32*8.), vec3(8., 8., 8.), rock, WHITE),
                             Parts::Vein(Ore::Diamond) => draw_cube(vec3((my - map[mz].len() as i8/2) as f32*8., 4.+mz as f32*-8., (mx - map[mz][my as usize].len() as i8/2) as f32*8.), vec3(8., 8., 8.), diamond, WHITE),
                             Parts::Vein(Ore::Gold) => draw_cube(vec3((my - map[mz].len() as i8/2) as f32*8., 4.+mz as f32*-8., (mx - map[mz][my as usize].len() as i8/2) as f32*8.), vec3(8., 8., 8.), gold, WHITE),
                              Parts::Vein(Ore::Iron) => draw_cube(vec3((my - map[mz].len() as i8/2) as f32*8., 4.+mz as f32*-8., (mx - map[mz][my as usize].len() as i8/2) as f32*8.), vec3(8., 8., 8.), iron, WHITE),
                    //Parts::Elevator => draw_cube(vec3((my - map.len() as i8/2) as f32*8., 4., (mx - map[my as usize].len() as i8/2) as f32*8.), vec3(8., 8., 8.), elevator, WHITE),
                    //Parts::Vein(Ore::Bronze) => draw_cube(vec3((my - map.len() as i8/2) as f32*8., 4., (mx - map[my as usize].len() as i8/2) as f32*8.), vec3(8., 8., 8.), None, MAROON),
                            Parts::Vein(Ore::Copper) => draw_cube(vec3((my - map[mz].len() as i8/2) as f32*8., 4.+mz as f32*-8., (mx - map[mz][my as usize].len() as i8/2) as f32*8.), vec3(8., 8., 8.), copper, WHITE),
                            Parts::Vein(Ore::Coal) => draw_cube(vec3((my - map[mz].len() as i8/2) as f32*8., 4.+mz as f32*-8., (mx - map[mz][my as usize].len() as i8/2) as f32*8.), vec3(8., 8., 8.), coal, WHITE),
                    //Parts::Enemy{_,_,_,EnemyType::Plebian,_} => (),
                            _ => ()
                        }
                
                    }
                }
            }
            
        }
            

        for mz in 0..map.len()
        {
        for my in 0..map[mz].len() as i8
        {
            for mx in 0..map[mz][my as usize].len() as i8
            {
                if let Parts::Enemy(enemy) = &map[mz][map[mz].len()-my as usize-1][mx as usize]
                {
                    match enemy.enemy_type
                    {
                        EnemyType::Plebian => draw_cube(vec3((my - map[mz].len() as i8/2) as f32*8., 4.+mz as f32*-8., (mx - map[mz][my as usize].len() as i8/2) as f32*8.), vec3(0., 8., 8.), plebian, WHITE),
                        EnemyType::Gunslinger => draw_cube(vec3((my - map[mz].len() as i8/2) as f32*8., 4.+mz as f32*-8., (mx - map[mz][my as usize].len() as i8/2) as f32*8.), vec3(0., 8., 8.), gunslinger, WHITE),
                        EnemyType::Mercenary => draw_cube(vec3((my - map[mz].len() as i8/2) as f32*8., 4.+mz as f32*-8., (mx - map[mz][my as usize].len() as i8/2) as f32*8.), vec3(0., 8., 8.), mercenary, WHITE),
                        EnemyType::Snitch => draw_cube(vec3((my - map[mz].len() as i8/2) as f32*8., 4.+mz as f32*-8., (mx - map[mz][my as usize].len() as i8/2) as f32*8.), vec3(0., 8., 8.), snitch, WHITE),
                        //rotate_cube(gl, vec3((my - map.len() as i8/2) as f32*8., 4., (mx - map[my as usize].len() as i8/2) as f32*8.), vec3(0.,90.,0.), vec3(0., 8., 8.), plebian, WHITE),
                        _ => ()
                    }
                }
            }
        }
        }

        for mz in 0..map.len()
        {
           for my in 0..map[mz].len() as i8
        {
            for mx in 0..map[mz][my as usize].len() as i8
            {
                /*match map[map.len()-my as usize-1][mx as usize]
                {
                    //Parts::Wall => draw_cube(vec3((my - map.len() as i8/2) as f32*8., 4., (mx - map[my as usize].len() as i8/2) as f32*8.), vec3(8., 8., 8.), rock, WHITE),
                    //Parts::Vein(Ore::Diamond) => draw_cube(vec3((my - map.len() as i8/2) as f32*8., 4., (mx - map[my as usize].len() as i8/2) as f32*8.), vec3(8., 8., 8.), diamond, WHITE),
                    //Parts::Vein(Ore::Gold) => draw_cube(vec3((my - map.len() as i8/2) as f32*8., 4., (mx - map[my as usize].len() as i8/2) as f32*8.), vec3(8., 8., 8.), gold, WHITE),
                    //Parts::Vein(Ore::Iron) => draw_cube(vec3((my - map.len() as i8/2) as f32*8., 4., (mx - map[my as usize].len() as i8/2) as f32*8.), vec3(8., 8., 8.), iron, WHITE),
                    Parts::Elevator => draw_cube(vec3((my - map.len() as i8/2) as f32*8., 4., (mx - map[my as usize].len() as i8/2) as f32*8.), vec3(8., 8., 8.), elevator, WHITE),
                    //Parts::Vein(Ore::Bronze) => draw_cube(vec3((my - map.len() as i8/2) as f32*8., 4., (mx - map[my as usize].len() as i8/2) as f32*8.), vec3(8., 8., 8.), None, MAROON),
                    //Parts::Vein(Ore::Copper) => draw_cube(vec3((my - map.len() as i8/2) as f32*8., 4., (mx - map[my as usize].len() as i8/2) as f32*8.), vec3(8., 8., 8.), copper, WHITE),
                    //Parts::Vein(Ore::Coal) => draw_cube(vec3((my - map.len() as i8/2) as f32*8., 4., (mx - map[my as usize].len() as i8/2) as f32*8.), vec3(8., 8., 8.), coal, WHITE),
                    //Parts::Enemy{_,_,_,EnemyType::Plebian,_} => (),
                    _ => ()
                }*/
                if let Parts::Elevator = map[mz][map[mz].len()-my as usize-1][mx as usize]
                {
                    draw_cube(vec3((my - map[mz].len() as i8/2) as f32*8., 4.+mz as f32*-8., (mx - map[mz][my as usize].len() as i8/2) as f32*8.), vec3(8., 8., 8.), elevator, WHITE);
                }
            }
        }
        }

        

        draw_cube(vec3(20., 1., -2.), vec3(0., 2., 2.), ferris, WHITE);

        //draw_cube(vec3(0., 4., -8.), vec3(48., 8., 8.), clay, DARKGRAY);
        //draw_cube(vec3(0., 4., 8.), vec3(48., 8., 8.), clay, DARKGRAY);

        // Back to screen space, render some text

        set_default_camera();

        draw_rectangle(0., 0., screen_width(), screen_height(), color_u8!(8,8,0,200));

        //draw_rectangle(1280./10., 800./12., 1280./10.*8., 800./6., BLACK);

        //draw_text(&format!("{},{},{}, {}, {}, {}, {}, {}*, {}, {}, {}, {:?}",x,y,z,map_x,map_y, -angle.to_radians().sin() as usize, angle.to_radians().cos() as usize,angle,get_fps(), anim_timer, fps_mod, direction).to_string(), 1280./10.+10.0, 800./12.+30.0, 30.0, LIME);

        /*draw_rectangle(0., 800./6.*5., 1280., 800./6., BLACK);

        if hovers(0., 1280., 800./6.*5., 800., mouse_position().0, mouse_position().1)
        {
            draw_rectangle(0., 800./6.*5., 1280., 800./6., RED);
        }*/

        /*for my in 0..map.len() as i8
        {
            for mx in 0..map[my as usize].len() as i8
            {
                match map[my as usize][mx as usize]
                {
                    Parts::Player(_) => draw_rectangle(mx as f32*32., my as f32*32., 32., 32., LIME),
                    Parts::Enemy(_) => draw_rectangle(mx as f32*32., my as f32*32., 32., 32., RED),
                    Parts::Empty => (),
                    _ => draw_rectangle(mx as f32*32., my as f32*32., 32., 32., WHITE)
                }
                
            }
        }*/

        draw_texture(coal_i,0.,0.,WHITE);
        draw_text(&resources[0].to_string(),96., 48., 32., WHITE);

        draw_texture(copper_i,0.,64.,WHITE);
        draw_text(&resources[1].to_string(),96., 112., 32., WHITE);

        draw_texture(iron_i,0.,128.,WHITE);
        draw_text(&resources[2].to_string(),96., 176., 32., WHITE);

        draw_texture(gold_i,0.,192.,WHITE);
        draw_text(&resources[3].to_string(),96., 240., 32., WHITE);

        draw_texture(diamond_i,0.,256.,WHITE);
        draw_text(&resources[4].to_string(),96., 304., 32., WHITE);


        draw_text("H             L",534., 732., 32., WHITE);
        draw_text("J    K",602., 736., 32., WHITE);
        //draw_text("J   K",602., 732., 32., WHITE);
        draw_texture(bar, 512., 736., WHITE);

        draw_text(&format!("{}$", money).to_string(), 0., 800., 48., LIME);

        //draw_texture_ex(rust_logo, 0., 800./6.*5., WHITE, DrawTextureParams { dest_size: Some(Vec2::new(160.,800./6.)), source: None, rotation: 0., flip_x: false, flip_y: false, pivot: None });
        //draw_rectangle(128., 0., 32., 32., RED);
        

        next_frame().await
    }
}