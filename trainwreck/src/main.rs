use macroquad::{prelude::*, audio::{play_sound_once, load_sound_from_bytes, play_sound, PlaySoundParams}};
use macroquad::rand::gen_range;

const SCREEN_DIMENSIONS: f32 = 994.;

enum GameState
{
    Gameplay,
    Title,
    Loss,
    Transitioning
}

struct Train
{
    pos: Vec2,
    track: usize,
    passed: bool,
    direction: bool,
    desired: bool
}

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
        window_title: "TRAINWRECK".to_owned(),
        fullscreen: false,
        window_resizable: false,
        window_width: 992,
        window_height: 992,
        ..Default::default()
    }
}

#[macroquad::main(window_conf)]
async fn main() {

    let t_track = load_texture("./assets/track.png").await.unwrap();
    let t_train = load_texture("./assets/train.png").await.unwrap();
    let t_train_45 = load_texture("./assets/train_45.png").await.unwrap();
    let t_train_n45 = load_texture("./assets/train_n45.png").await.unwrap();
    let t_thumbs_up = load_texture("./assets/yes.png").await.unwrap();
    let t_thumbs_down = load_texture("./assets/no.png").await.unwrap();
    let t_logo = load_texture("./assets/logo2.png").await.unwrap();
    let t_fork0 = load_texture("./assets/fork_off.png").await.unwrap();
    let t_fork1 = load_texture("./assets/fork_on.png").await.unwrap();
    let t_environment = load_texture("./assets/environment.png").await.unwrap();

    let s_ding = load_sound_from_bytes(load_file("./assets/pleasing-bell.wav").await.unwrap().as_slice()).await.unwrap();
    let s_bong = load_sound_from_bytes(load_file("./assets/death_bell.wav").await.unwrap().as_slice()).await.unwrap();
    let s_level_up = load_sound_from_bytes(load_file("./assets/upmid.wav").await.unwrap().as_slice()).await.unwrap();
    let s_environment = load_sound_from_bytes(load_file("./assets/wind_woosh_loop.ogg").await.unwrap().as_slice()).await.unwrap();
    let s_lever = load_sound_from_bytes(load_file("./assets/lever.ogg").await.unwrap().as_slice()).await.unwrap();

    let mut state = GameState::Title;

    let mut deviations = [(false,SCREEN_DIMENSIONS/2.);10];
    let mut trains: Vec<Train> = Vec::new();
    let mut train_removal_queue: Vec<usize> = Vec::new();

    let mut yes: u32 = 0;
    let mut yes_goal: u32 = 20;
    let mut no: u32 = 0;
    let mut no_limit: u32 = 20;
    let mut so_far: u32 = 0;
    let mut level: u32 = 1;
    let mut high_score = 0;

    play_sound(s_environment, PlaySoundParams { looped: true, ..Default::default() });
    println!("In case of an error, info will be displayed here.");

    loop {

        let dt = 60.*get_frame_time();
        let fps_mul = if (get_fps() as f32/60.).round() as usize == 0 {60} else {(get_fps() as f32/60.).round() as usize};

        match state
        {
            GameState::Gameplay => {
                if gen_range(0, 60*fps_mul) == 59*fps_mul && trains.len() < level as usize+((level-1) as f32/2.).floor() as usize+2 && get_time().floor() > 3. && yes < yes_goal
                {
                    let track = gen_range(0, 10);
                    let desired = if gen_range(0, 2) == 0
                    {
                        false
                    }
                    else {
                        true
                    };
                    trains.push(Train{track: track, pos: Vec2::new(0.,-96.), passed: false, direction: false, desired: desired});
                    if gen_range(0, 15*fps_mul) == 14*fps_mul && trains.len() < level as usize+((level-1) as f32/2.).floor() as usize && level > 3
                    {
                        trains.push(Train{track: track, pos: Vec2::new(0.,-96.), passed: false, direction: false, desired: !desired});
                        if gen_range(0, 5*fps_mul) == 4*fps_mul && trains.len() < level as usize+((level-1) as f32/2.).floor() as usize && level > 4 && track > 0
                        {
                            let track = track as i32+gen_range(-1,2) as i32;
                            if track != 0
                            {
                                trains.push(Train{track: track as usize, pos: Vec2::new(0.,-96.), passed: false, direction: false, desired: !desired});
                            }
                            
                        }
                    }
                }
        
                for i in 0..deviations.len()
                {
                    if hovers(i as f32*64.+192., i as f32*64.+63.+192., 0., SCREEN_DIMENSIONS, mouse_position().0, mouse_position().1) && (is_mouse_button_pressed(MouseButton::Left) || is_key_pressed(KeyCode::Space))
                    {
                        deviations[i].0 = !deviations[i].0;
                        play_sound_once(s_lever);
                    }
                }
        
                for i in 0..trains.len()
                {
                    let speed = gen_range(1, 5) as f32/gen_range(1, 2) as f32;
                    trains[i].pos.y += dt*speed*2.;
                    if i > 0
                    {
                        if trains[i].pos.y+96. > trains[i-1].pos.y
                        {
                            trains[i].pos.y = trains[i-1].pos.y-96.;
                        }
                    }
                    if trains[i].pos.y+48.>=deviations[trains[i].track].1 && trains[i].pos.x == 0.
                    {
                        trains[i].passed=true;
                        trains[i].direction = deviations[trains[i].track].0;
                    }
                    if trains[i].pos.y > SCREEN_DIMENSIONS
                    {
                        if trains[i].direction == trains[i].desired
                        {
                            yes += 1;
                            play_sound_once(s_ding);
                        }
                        else {
                            no += 1;
                            play_sound_once(s_bong);
                        }
                        so_far += 1;
                        train_removal_queue.push(i);
                    }
                    if trains[i].passed
                    {
                        if trains[i].direction
                        {
                            trains[i].pos.x += dt*speed;
                        }
                        else {
                            trains[i].pos.x -= dt*speed;
                        }
                    }
                    if trains[i].pos.x >= 16.
                    {
                        trains[i].passed = false;
                        trains[i].pos.x = 16.;
                    }
                    else if trains[i].pos.x <= -16.
                    {
                        trains[i].passed = false;
                        trains[i].pos.x = -16.;
                    }
                }
        
                for i in train_removal_queue.iter()
                {
                    trains.remove(*i);
                }
                train_removal_queue.clear();
        
                if yes >= yes_goal && trains.is_empty()
                {
                    level+=1;
                    yes = 0;
                    if no > 0
                    {
                        no -= 1;
                    }
                    yes_goal = level*20+level;
                    no_limit += level;
                    for n in 0..deviations.len()
                    {
                        deviations[n].1 = SCREEN_DIMENSIONS/2.+gen_range(-(2_i32.pow(level)), 2_i32.pow(level)).clamp(-300,300) as f32;
                    }
                    play_sound_once(s_level_up);
                }
        
                if no > no_limit
                {
                    if so_far > high_score
                    {
                        high_score = so_far;
                    }
                    draw_text("You lost!", SCREEN_DIMENSIONS/2.-320., SCREEN_DIMENSIONS/2.-96., 96., BLACK);
                    draw_text("Press any key to restart!", SCREEN_DIMENSIONS/2.-300., SCREEN_DIMENSIONS/2.+100., 48., BLACK);
                    draw_text(&format!("High score: {}", high_score).to_string(), SCREEN_DIMENSIONS/2.-240., SCREEN_DIMENSIONS/2.+140., 36., BLACK);
                    state = GameState::Loss;
                }
            },
            GameState::Loss => {
                if get_last_key_pressed().is_some() || is_mouse_button_down(MouseButton::Left) || is_mouse_button_down(MouseButton::Right)
                {
                    trains.clear();
                    deviations = [(false,SCREEN_DIMENSIONS/2.);10];
                    trains = Vec::new();
                    train_removal_queue = Vec::new();

                    yes = 0;
                    yes_goal = 20;
                    no = 0;
                    no_limit = 20;
                    so_far = 0;
                    level = 1;

                    state = GameState::Transitioning;
                }
            }
            GameState::Title => {
                if get_last_key_pressed().is_some() || is_mouse_button_down(MouseButton::Left) || is_mouse_button_down(MouseButton::Right)
                {
                    state = GameState::Transitioning;
                }
            }
            GameState::Transitioning => {
                state=GameState::Gameplay;
            }
        }

        clear_background(LIGHTGRAY);

        match state
        {
            GameState::Title => {
                draw_texture(t_logo, SCREEN_DIMENSIONS/2.-320., SCREEN_DIMENSIONS/2.-60., WHITE);
                draw_text("Press any key to play!", SCREEN_DIMENSIONS/2.-240., SCREEN_DIMENSIONS/2.+100., 48., BLACK);
            },
            GameState::Loss => {
                draw_text("You lost!", SCREEN_DIMENSIONS/2.-240., SCREEN_DIMENSIONS/2., 96., BLACK);
                draw_text("Press any key to restart!", SCREEN_DIMENSIONS/2.-240., SCREEN_DIMENSIONS/2.+100., 48., BLACK);
            }
            GameState::Gameplay => {for i in 0..deviations.len()
            {
                draw_texture(t_track, i as f32*64.+192., 1.+deviations[i].1-SCREEN_DIMENSIONS/2., BLACK);
                draw_texture(t_track, i as f32*64.+192.-16., 64.+deviations[i].1, Color::from_rgba(64,0,0,255));
                draw_texture(t_track, i as f32*64.+192.+16., 64.+deviations[i].1, Color::from_rgba(0,64,0,255));
                draw_texture(t_track, i as f32*64.+192.-16., 64.+deviations[i].1+SCREEN_DIMENSIONS/2., Color::from_rgba(64,0,0,255));
                draw_texture(t_track, i as f32*64.+192.+16., 64.+deviations[i].1+SCREEN_DIMENSIONS/2., Color::from_rgba(0,64,0,255));
                if deviations[i].0 {draw_texture(t_fork1, i as f32*64.+192.-16., deviations[i].1, WHITE)} else {draw_texture(t_fork0, i as f32*64.+192.-16., deviations[i].1, WHITE)}
            }
            draw_texture(t_environment, 0., 0., BLACK);
            for train in trains.iter()
            {
                if train.desired {
                    if train.passed
                    {
                        if train.direction
                        {
                            draw_texture(t_train_n45, train.track as f32*64.+train.pos.x+192.-48., train.pos.y, GREEN);
                        }
                        else {
                            draw_texture(t_train_45, train.track as f32*64.+train.pos.x+192.-48., train.pos.y, GREEN);
                        }
                    }
                    else {
                        draw_texture(t_train, train.track as f32*64.+train.pos.x+192., train.pos.y, GREEN);
                    }
                } 
                else {
                    if train.passed
                    {
                        if train.direction
                        {
                            draw_texture(t_train_n45, train.track as f32*64.+train.pos.x+192.-48., train.pos.y, RED);
                        }
                        else {
                            draw_texture(t_train_45, train.track as f32*64.+train.pos.x+192.-48., train.pos.y, RED);
                        }
                    }
                    else {
                        draw_texture(t_train, train.track as f32*64.+train.pos.x+192., train.pos.y, RED);
                    }
                }
            }

            draw_text(&format!("LEVEL {}:", level).to_string(), 0., 24., 48., BLACK);
            draw_text(&so_far.to_string(), 0., 52., 48., BLACK);
            draw_texture(t_thumbs_up, 0., 48., WHITE);
            draw_text(&format!("{}/{}",yes,yes_goal).to_string(), 52., 80., 48., GREEN);
            draw_texture(t_thumbs_down, 0., 80., WHITE);
            draw_text(&format!("{}/{}",no,no_limit).to_string(), 52., 108., 48., RED);
            if high_score > 0
            {
                draw_text(&format!("High score: {}",high_score).to_string(), 0., 132., 24., DARKGRAY);
            }
        }
        GameState::Transitioning => ()
        }

        next_frame().await;
    }

}