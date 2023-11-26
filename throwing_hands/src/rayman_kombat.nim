# ****************************************************************************************
#
#   raylib [core] example - Basic window (adapted for HTML5 platform)
#
#   NOTE: This example is prepared to compile to WebAssembly, as shown in the
#   basic_window_web.nims file. Compile with the -d:emscripten flag.
#   To run the example on the Web, run nimhttpd from the public directory and visit
#   the address printed to stdout. As you will notice, code structure is slightly
#   diferent to the other examples...
#
#   Example originally created with raylib 1.3, last time updated with raylib 1.3
#
#   Example licensed under an unmodified zlib/libpng license, which is an OSI-certified,
#   BSD-like license that allows static linking with closed source software
#
#   Copyright (c) 2015-2022 Ramon Santamaria (@raysan5)
#
# ****************************************************************************************

import raylib, std/math

# ----------------------------------------------------------------------------------------
# Global Variables Definition
# ----------------------------------------------------------------------------------------

const
  screenWidth = 1280
  screenHeight = 960

type 
  LimbType = enum
    Head
    Hand
    Torso
    Foot
  Action = enum
    Idle
    Walk
    Jump
    Duck
    Punch
    Kick
    Guard
    Dodge
    Special
  State = enum
    title
    gameplay
    pause
    p1win
    p2win
  Limb = object
    pos: Vector2
    size: Vector2
    vel: Vector2
    target: Vector2
    attacking: bool
    limb_type: LimbType
    grounded: bool = false
  Player = object
    head: Limb = Limb(pos:Vector2(x:32.0,y: 602.0),size:Vector2(x:32.0,y:32.0),vel:Vector2(x:0.0,y:0.0),attacking:false,limb_type: Head,target:Vector2(x:0.0,y: -40.0))
    torso: Limb = Limb(pos:Vector2(x:32.0,y:648.0),size:Vector2(x:32.0,y:32.0),vel:Vector2(x:0.0,y:0.0),attacking:false,limb_type: Torso,target:Vector2(x:0.0,y:0.0))
    hand_r: Limb = Limb(pos:Vector2(x:64.0,y:648.0),size:Vector2(x:32.0,y:32.0),vel:Vector2(x:0.0,y:0.0),attacking:false,limb_type: Hand,target:Vector2(x:40.0,y:0.0))
    hand_l: Limb = Limb(pos:Vector2(x:0.0,y:648.0),size:Vector2(x:32.0,y:32.0),vel:Vector2(x:0.0,y:0.0),attacking:false,limb_type: Hand,target:Vector2(x: -40.0,y:0.0))
    foot_r: Limb = Limb(pos:Vector2(x:64.0,y:688.0),size:Vector2(x:32.0,y:32.0),vel:Vector2(x:0.0,y:0.0),attacking:false,limb_type: Foot,target:Vector2(x:40.0,y:40.0))
    foot_l: Limb = Limb(pos:Vector2(x:0.0,y:688.0),size:Vector2(x:32.0,y:32.0),vel:Vector2(x:0.0,y:0.0),attacking:false,limb_type: Foot,target:Vector2(x: -40.0,y:40.0))
    hp: int = 8
    max_hp: int = 8
    action: Action
    grounded: bool = false
    left: bool

proc aabb*(x1: float, y1: float, w1: float, h1: float,
x2: float, y2: float, w2: float, h2: float): bool =
  if
    x1 < x2 + w2 and
    x1 + w1 > x2 and
    y1 < y2 + h2 and
    h1 + y1 > y2:
      return true
  false

var player = Player()
var player2 = Player(head: Limb(pos:Vector2(x:screenWidth.float-32.0-32.0,y: 602.0),size:Vector2(x:32.0,y:32.0),vel:Vector2(x:0.0,y:0.0),attacking:false,limb_type: Head),
  torso: Limb(pos:Vector2(x:screenWidth.float-32.0-32.0,y:648.0),size:Vector2(x:32.0,y:32.0),vel:Vector2(x:0.0,y:0.0),attacking:false,limb_type: Torso),
  hand_r: Limb(pos:Vector2(x:screenWidth.float-32.0-64.0,y:648.0),size:Vector2(x:32.0,y:32.0),vel:Vector2(x:0.0,y:0.0),attacking:false,limb_type: Hand),
  hand_l: Limb(pos:Vector2(x:screenWidth.float-32.0-0.0,y:648.0),size:Vector2(x:32.0,y:32.0),vel:Vector2(x:0.0,y:0.0),attacking:false,limb_type: Hand),
  foot_r: Limb(pos:Vector2(x:screenWidth.float-32.0-64.0,y:688.0),size:Vector2(x:32.0,y:32.0),vel:Vector2(x:0.0,y:0.0),attacking:false,limb_type: Foot),
  foot_l: Limb(pos:Vector2(x:screenWidth.float-32.0-0.0,y:688.0),size:Vector2(x:32.0,y:32.0),vel:Vector2(x:0.0,y:0.0),attacking:false,limb_type: Foot))
var state = title
var walls = @[Rectangle(x: -9999.0,y:720.0,width:1000000.0,height:300.0),Rectangle(x:screenWidth.float/4.0,y:496.0,width:screenWidth.float/2.0,height:256.0)]

# ----------------------------------------------------------------------------------------
# Module functions Definition
# ----------------------------------------------------------------------------------------

proc moveLimb(limb: var Limb,vel: Vector2,player: var Player, walls: seq[Rectangle]) = 
  limb.pos.x += vel.x
  for wall in walls:
    if aabb(limb.pos.x,limb.pos.y,limb.size.x,limb.size.y,wall.x,wall.y,wall.width,wall.height):
      if limb.pos.x > wall.x+wall.width/2.0:
        limb.pos.x = wall.x+wall.width
      else:
        limb.pos.x = wall.x-limb.size.x
      limb.vel.x = 0.0
  limb.pos.y += vel.y
  for wall in walls:
    if aabb(limb.pos.x,limb.pos.y,limb.size.x,limb.size.y,wall.x,wall.y,wall.width,wall.height):
      if limb.pos.y > wall.y+wall.height/2.0:
        limb.pos.y = wall.y+wall.height
      else:
        limb.pos.y = wall.y-limb.size.y
        if limb.limb_type == Foot or limb.limb_type == Hand: player.grounded = true
      limb.vel.y = 0.0

proc updateDrawFrame {.cdecl.} =
  # Update
  # --------------------------------------------------------------------------------------
  # TODO: Update your variables here
  # --------------------------------------------------------------------------------------

  if state == gameplay:
    if isKeyDown(D):
      player.foot_r.vel.x = 6.0
      player.foot_l.vel.x = 6.0
      player.left = false
    elif isKeyDown(A):
      player.foot_r.vel.x = -6.0
      player.foot_l.vel.x = -6.0
      player.left = true
    else:
      player.foot_r.vel.x = 0.0
      player.foot_l.vel.x = 0.0
    if isKeyDown(W) and player.grounded:
      #player.vel.y = -16.0
      player.head.vel.y = -16.0
      player.torso.vel.y = -16.0
      player.foot_r.vel.y = -16.0
      player.foot_l.vel.y = -16.0
      player.hand_r.vel.y = -16.0
      player.hand_l.vel.y = -16.0
    if isKeyPressed(LeftShift):
      if player.left and aabb(player.hand_l.pos.x,player.hand_l.pos.y,player.hand_l.size.x,player.hand_l.size.y,player.torso.pos.x-40.0,player.torso.pos.y-40.0,player.torso.size.x+80.0,player.torso.size.y+80.0):
        player.hand_l.vel.x = -30.0
        player.hand_l.vel.y = 0.0
        player.hand_l.attacking = true
      elif not player.left and aabb(player.hand_r.pos.x,player.hand_r.pos.y,player.hand_r.size.x,player.hand_r.size.y,player.torso.pos.x-40.0,player.torso.pos.y-40.0,player.torso.size.x+80.0,player.torso.size.y+80.0):
        player.hand_r.vel.x = 30.0
        player.hand_r.vel.y = 0.0
        player.hand_r.attacking = true
      #[if (player.left or not aabb(player.hand_r.pos.x,player.hand_r.pos.y,player.hand_r.size.x,player.hand_r.size.y,player.torso.pos.x-40.0,player.torso.pos.y-40.0,player.torso.size.x+80.0,player.torso.size.y+80.0)) and aabb(player.hand_l.pos.x,player.hand_l.pos.y,player.hand_l.size.x,player.hand_l.size.y,player.torso.pos.x-40.0,player.torso.pos.y-40.0,player.torso.size.x+80.0,player.torso.size.y+80.0):
        player.hand_l.vel.x = -30.0
        player.hand_l.vel.y = 0.0
        player.hand_l.attacking = true
      elif (not aabb(player.hand_l.pos.x,player.hand_l.pos.y,player.hand_l.size.x,player.hand_l.size.y,player.torso.pos.x-40.0,player.torso.pos.y-40.0,player.torso.size.x+80.0,player.torso.size.y+80.0) or not player.left) and aabb(player.hand_r.pos.x,player.hand_r.pos.y,player.hand_r.size.x,player.hand_r.size.y,player.torso.pos.x-40.0,player.torso.pos.y-40.0,player.torso.size.x+80.0,player.torso.size.y+80.0):
        player.hand_r.vel.x = 30.0
        player.hand_r.vel.y = 0.0
        player.hand_r.attacking = true]#
    if isKeyDown(S):
      player.head.target.y = 40.0
      player.torso.target.y = 40.0
    else:
      player.head.target.y = -40.0
      player.torso.target.y = 0.0

    if isKeyDown(L):
      player2.foot_r.vel.x = 6.0
      player2.foot_l.vel.x = 6.0
    elif isKeyDown(J):
      player2.foot_r.vel.x = -6.0
      player2.foot_l.vel.x = -6.0
    else:
      player2.foot_r.vel.x = 0.0
      player2.foot_l.vel.x = 0.0
    if isKeyDown(I) and player2.grounded:
      #player2.vel.y = -16.0
      #player2.head.vel.y = -14.0
      player2.torso.vel.y = -15.0
      player2.foot_r.vel.y = -16.0
      player2.foot_l.vel.y = -16.0
      #player2.hand_r.vel.y = -14.0
      #player2.hand_l.vel.y = -14.0
    if isKeyPressed(N):
      if player2.foot_r.vel.x <= 0.0 and player2.foot_l.vel.x <= 0.0 and aabb(player2.hand_l.pos.x,player2.hand_l.pos.y,player2.hand_l.size.x,player2.hand_l.size.y,player2.torso.pos.x-40.0,player2.torso.pos.y-40.0,player2.torso.size.x+80.0,player2.torso.size.y+80.0):
        player2.hand_l.vel.x = -30.0
        player2.hand_l.vel.y = 0.0
        player2.hand_l.attacking = true
      elif player2.foot_r.vel.x > 0.0 and player2.foot_l.vel.x > 0.0 and aabb(player2.hand_r.pos.x,player2.hand_r.pos.y,player2.hand_r.size.x,player2.hand_r.size.y,player2.torso.pos.x-40.0,player2.torso.pos.y-40.0,player2.torso.size.x+80.0,player2.torso.size.y+80.0):
        player2.hand_r.vel.x = 30.0
        player2.hand_r.vel.y = 0.0
        player2.hand_r.attacking = true
    #[if isKeyDown(S):
      player.vel.y = 4.0
    elif isKeyDown(W):
      player.vel.y = -4.0
    else:
      player.vel.y = 0.0]#

    #if not player.grounded: 
      #player.head.vel.y += 0.5
      #player.torso.vel.y += 0.5
    player.foot_r.vel.y += 0.5*getFrameTime()*60
    player.foot_l.vel.y += 0.5*getFrameTime()*60
      #player.hand_r.vel.y += 0.5
      #player.hand_l.vel.y += 0.5
    player.grounded = false

    if not player2.grounded: 
      player2.head.vel.y += 0.5*getFrameTime()*60
      player2.torso.vel.y += 0.5*getFrameTime()*60
      player2.foot_r.vel.y += 0.5*getFrameTime()*60
      player2.foot_l.vel.y += 0.5*getFrameTime()*60
      player2.hand_r.vel.y += 0.5*getFrameTime()*60
      player2.hand_l.vel.y += 0.5*getFrameTime()*60
    player2.grounded = false

    #player.foot_r.vel.x
    #player.foot_r.vel.y
    #player.foot_l.vel.x
    #player.foot_l.vel.y
    player.foot_r.moveLimb(Vector2(x:player.foot_r.vel.x,y:player.foot_r.vel.y),player,walls)
    player.foot_l.moveLimb(Vector2(x:player.foot_l.vel.x,y:player.foot_l.vel.y),player,walls)
    #if player.grounded: 
      #player.torso.vel.y = player.vel.y
      #player.hand_r.vel.y = player.torso.vel.y/2.0
      #player.hand_l.vel.y = player.torso.vel.y/2.0
      #player.head.vel.y = player.torso.vel.y/2.0
      #player.foot_r.vel.y = 0.0
      #player.foot_l.vel.y = 0.0
    #let foot_target = if player.foot_l.pos.x > player.foot_r.pos.x: player.foot_l.pos else: player.foot_r.pos
    let t_angle = if player.foot_l.pos.x < player.foot_r.pos.x: arctan2(player.foot_l.pos.y-40.0-player.torso.pos.y+player.torso.target.y,player.foot_l.pos.x+32.0-player.torso.pos.x+player.torso.target.x) else: arctan2(player.foot_r.pos.y-40.0-player.torso.pos.y+player.torso.target.y,player.foot_r.pos.x+32.0-player.torso.pos.x+player.torso.target.x)
    #let t_angle = arctan2(player.torso.pos.y+(player.foot_l.pos.y-player.foot_r.pos.y)-40.0+player.torso.target.y,player.foot_l.pos.x+32.0-player.torso.pos.x+player.torso.target.x)
    #let lh_angle = arctan2(player.foot_l.pos.y+48.0-player.torso.pos.y,player.foot_l.pos.x-48.0-player.torso.pos.x)
    #let h_angle = arctan2(player.foot_l.pos.y+48.0-player.torso.pos.y,player.foot_l.pos.x-48.0-player.torso.pos.x)
    #player.torso.pos.x += t_angle.cos()*8.0
    #player.torso.pos.y += t_angle.sin()*8.0
    player.torso.vel.x += t_angle.cos()
    player.torso.vel.y += t_angle.sin()
    player.torso.moveLimb(Vector2(x:player.torso.vel.x+t_angle.cos()*8.0,y:player.torso.vel.y+t_angle.sin()*8.0),player,walls)
    let rh_angle = arctan2(player.torso.pos.y-player.hand_r.pos.y+player.hand_r.target.y,player.torso.pos.x+player.hand_r.target.x-player.hand_r.pos.x)
    let lh_angle = arctan2(player.torso.pos.y-player.hand_l.pos.y+player.hand_l.target.y,player.torso.pos.x+player.hand_l.target.x-player.hand_l.pos.x)
    let h_angle = arctan2(player.torso.pos.y+player.head.target.y-player.head.pos.y,player.torso.pos.x-player.head.pos.x+player.head.target.x)
    player.hand_r.vel.x += rh_angle.cos()
    player.hand_r.vel.y += rh_angle.sin()
    #if aabb(player.hand_r.pos.x,player.hand_r.pos.y,player.hand_r.size.x,player.hand_r.size.y,player.torso.pos.x-20.0,player.torso.pos.y-20.0,player.torso.size.x+40.0,player.torso.size.y+40.0): player.hand_r.attacking = false
    player.hand_l.vel.x += lh_angle.cos()
    player.hand_l.vel.y += lh_angle.sin()
    #if aabb(player.hand_l.pos.x,player.hand_l.pos.y,player.hand_l.size.x,player.hand_l.size.y,player.torso.pos.x-20.0,player.torso.pos.y-20.0,player.torso.size.x+40.0,player.torso.size.y+40.0): player.hand_l.attacking = false
    player.head.vel.x += h_angle.cos()
    player.head.vel.y += h_angle.sin()
    player.hand_r.moveLimb(Vector2(x:player.hand_r.vel.x+rh_angle.cos()*8.0,y:player.hand_r.vel.y+rh_angle.sin()*8.0),player,walls)
    if player.hand_r.attacking and aabb(player.hand_r.pos.x,player.hand_r.pos.y,player.hand_r.size.x,player.hand_r.size.y,player2.torso.pos.x,player2.torso.pos.y,player2.torso.size.x,player2.torso.size.y):
      player2.hp -= 1
      player.hand_r.attacking = false
    player.hand_l.moveLimb(Vector2(x:player.hand_l.vel.x+lh_angle.cos()*8.0,y:player.hand_l.vel.y+lh_angle.sin()*8.0),player,walls)
    if player.hand_l.attacking and aabb(player.hand_l.pos.x,player.hand_l.pos.y,player.hand_l.size.x,player.hand_l.size.y,player2.torso.pos.x,player2.torso.pos.y,player2.torso.size.x,player2.torso.size.y):
      player2.hp -= 1
      player.hand_l.attacking = false
    player.head.moveLimb(Vector2(x:player.head.vel.x+h_angle.cos()*8.0,y:player.head.vel.y+h_angle.sin()*8.0),player,walls)
    #[if isKeyDown(S):
      player2.vel.y = 4.0
    elif isKeyDown(W):
      player2.vel.y = -4.0
    else:
      player2.vel.y = 0.0]#

    #player2.foot_r.vel.x
    #player2.foot_r.vel.y
    #player2.foot_l.vel.x
    #player2.foot_l.vel.y
    player2.foot_r.moveLimb(Vector2(x:player2.foot_r.vel.x,y:player2.foot_r.vel.y),player2,walls)
    player2.foot_l.moveLimb(Vector2(x:player2.foot_l.vel.x,y:player2.foot_l.vel.y),player2,walls)
    if player2.grounded: 
      #player2.torso.vel.y = player.vel.y
      #player2.hand_r.vel.y = player.torso.vel.y/2.0
      #player2.hand_l.vel.y = player.torso.vel.y/2.0
      #player2.head.vel.y = player.torso.vel.y/2.0
      player2.foot_r.vel.y = 0.0
      player2.foot_l.vel.y = 0.0
    #let foot_target = if player2.foot_l.pos.x > player.foot_r.pos.x: player.foot_l.pos else: player.foot_r.pos
    let t_angle2 = if player2.foot_l.pos.x < player2.foot_r.pos.x: arctan2(player2.foot_l.pos.y-40.0-player2.torso.pos.y,player2.foot_l.pos.x+32.0-player2.torso.pos.x) else: arctan2(player2.foot_r.pos.y-40.0-player2.torso.pos.y,player2.foot_r.pos.x+32.0-player2.torso.pos.x)
    #let lh_angle = arctan2(player2.foot_l.pos.y+48.0-player.torso.pos.y,player.foot_l.pos.x-48.0-player.torso.pos.x)
    #let h_angle = arctan2(player2.foot_l.pos.y+48.0-player.torso.pos.y,player.foot_l.pos.x-48.0-player.torso.pos.x)
    player2.torso.pos.x += t_angle2.cos()*8.0
    player2.torso.pos.y += t_angle2.sin()*8.0
    player2.torso.vel.x += t_angle2.cos()
    player2.torso.vel.y += t_angle2.sin()
    player2.torso.moveLimb(Vector2(x:player2.torso.vel.x,y:player2.torso.vel.y),player2,walls)
    let rh_angle2 = arctan2(player2.torso.pos.y-player2.hand_r.pos.y,player2.torso.pos.x+40.0-player2.hand_r.pos.x)
    let lh_angle2 = arctan2(player2.torso.pos.y-player2.hand_l.pos.y,player2.torso.pos.x-40.0-player2.hand_l.pos.x)
    let h_angle2 = arctan2(player2.torso.pos.y-40.0-player2.head.pos.y,player2.torso.pos.x-player2.head.pos.x)
    player2.hand_r.pos.x += rh_angle2.cos()*8.0
    player2.hand_r.pos.y += rh_angle2.sin()*8.0
    player2.hand_r.vel.x += rh_angle2.cos()
    player2.hand_r.vel.y += rh_angle2.sin()
    if player2.hand_r.attacking and aabb(player2.hand_r.pos.x,player2.hand_r.pos.y,player2.hand_r.size.x,player2.hand_r.size.y,player.torso.pos.x,player.torso.pos.y,player.torso.size.x,player.torso.size.y):
      player.hp -= 1
      player2.hand_r.attacking = false
    player2.hand_l.pos.x += lh_angle2.cos()*8.0
    player2.hand_l.pos.y += lh_angle2.sin()*8.0
    player2.hand_l.vel.x += lh_angle2.cos()
    player2.hand_l.vel.y += lh_angle2.sin()
    if player2.hand_l.attacking and aabb(player2.hand_l.pos.x,player2.hand_l.pos.y,player2.hand_l.size.x,player2.hand_l.size.y,player.torso.pos.x,player.torso.pos.y,player.torso.size.x,player.torso.size.y):
      player.hp -= 1
      player2.hand_l.attacking = false
    player2.head.pos.x += h_angle2.cos()*8.0
    player2.head.pos.y += h_angle2.sin()*8.0
    player2.head.vel.x += h_angle2.cos()
    player2.head.vel.y += h_angle2.sin()
    player2.hand_r.moveLimb(Vector2(x:player2.hand_r.vel.x,y:player2.hand_r.vel.y),player2,walls)
    player2.hand_l.moveLimb(Vector2(x:player2.hand_l.vel.x,y:player2.hand_l.vel.y),player2,walls)
    player2.head.moveLimb(Vector2(x:player2.head.vel.x,y:player2.head.vel.y),player2,walls)

    if isKeyPressed(Enter): state = pause

    if player.hp < 1: state = p2win
    if player2.hp < 1: state = p1win

  elif state == p1win or state == p2win:
    if isKeyPressed(Enter): 
      player = Player()
      player2 = Player(head: Limb(pos:Vector2(x:screenWidth.float-32.0-32.0,y: 602.0),size:Vector2(x:32.0,y:32.0),vel:Vector2(x:0.0,y:0.0),attacking:false,limb_type: Head),
      torso: Limb(pos:Vector2(x:screenWidth.float-32.0-32.0,y:648.0),size:Vector2(x:32.0,y:32.0),vel:Vector2(x:0.0,y:0.0),attacking:false,limb_type: Torso),
      hand_r: Limb(pos:Vector2(x:screenWidth.float-32.0-64.0,y:648.0),size:Vector2(x:32.0,y:32.0),vel:Vector2(x:0.0,y:0.0),attacking:false,limb_type: Hand),
      hand_l: Limb(pos:Vector2(x:screenWidth.float-32.0-0.0,y:648.0),size:Vector2(x:32.0,y:32.0),vel:Vector2(x:0.0,y:0.0),attacking:false,limb_type: Hand),
      foot_r: Limb(pos:Vector2(x:screenWidth.float-32.0-64.0,y:688.0),size:Vector2(x:32.0,y:32.0),vel:Vector2(x:0.0,y:0.0),attacking:false,limb_type: Foot),
      foot_l: Limb(pos:Vector2(x:screenWidth.float-32.0-0.0,y:688.0),size:Vector2(x:32.0,y:32.0),vel:Vector2(x:0.0,y:0.0),attacking:false,limb_type: Foot))
      state = gameplay

  else:
    if isKeyPressed(Enter): 
      state = gameplay
  #player.grounded = false
  # Draw
  # --------------------------------------------------------------------------------------
  beginDrawing()
  clearBackground(RayWhite)
  if state != title:
    drawRectangle(player.head.pos,player.head.size,Red)
    drawRectangle(player.hand_l.pos,player.hand_l.size,Red)
    drawRectangle(player.foot_l.pos,player.foot_l.size,Red)
    drawRectangle(player.torso.pos,player.torso.size,Red)
    drawRectangle(player.hand_r.pos,player.hand_r.size,Red)
    drawRectangle(player.foot_r.pos,player.foot_r.size,Red)
    drawRectangle(player2.head.pos,player2.head.size,SkyBlue)
    drawRectangle(player2.hand_l.pos,player2.hand_l.size,SkyBlue)
    drawRectangle(player2.foot_l.pos,player2.foot_l.size,SkyBlue)
    drawRectangle(player2.torso.pos,player2.torso.size,SkyBlue)
    drawRectangle(player2.hand_r.pos,player2.hand_r.size,SkyBlue)
    drawRectangle(player2.foot_r.pos,player2.foot_r.size,SkyBlue)
    for wall in walls:
      drawRectangle(wall,Gray)
  case state:
  of gameplay:
    drawRectangle(0,0,32*player.hp.int32,32,Green)
    drawText("PLAYER 1".cstring,8,8,16,Black)
    drawRectangle(screenWidth.int32-32*player2.hp.int32,0,32*player2.max_hp.int32,32,Green)
    drawText("PLAYER 2".cstring,screenWidth.int32-measureText("PLAYER 2".cstring,16)-8,8,16,Black)
  of p1win:
    #drawText("PLAYER 1 WINS!".cstring,640-measureText("PLAYER 1 WINS!".cstring,32),480,32,Red)
    drawRectangle(0,0,screenWidth.int32,screenHeight.int32,Color(r:0,g:0,b:0,a:200))
    drawText("PLAYER 1 WINS!".cstring,515,480,32,Red)
    drawText("Press Enter to restart.".cstring,513,520,16,White)
  of p2win:
    #drawText("PLAYER 2 WINS!".cstring,640,480,32,SkyBlue)
    drawRectangle(0,0,screenWidth.int32,screenHeight.int32,Color(r:0,g:0,b:0,a:200))
    drawText("PLAYER 2 WINS!".cstring,515,480,32,SkyBlue)
    drawText("Press Enter to restart.".cstring,513,520,16,White)
  of title:
    #drawText("Throwing Hands".cstring,640,480,32,Black)
    drawText("Throwing Hands".cstring,513,480,32,Black)
    drawText("Press Enter to begin.".cstring,513,520,16,Black)
  of pause:
    drawRectangle(0,0,screenWidth.int32,screenHeight.int32,Color(r:0,g:0,b:0,a:200))
    drawText("PAUSED. Press Enter to continue.".cstring,10,10,24,White)
  
  endDrawing()
  # --------------------------------------------------------------------------------------

# ----------------------------------------------------------------------------------------
# Program main entry point
# ----------------------------------------------------------------------------------------

proc main =
  # Initialization
  # --------------------------------------------------------------------------------------

  #var solid = Wall(pos:Vector2(x:0.0,y:720.0),size:Vector2(x:screenWidth.float,y:300.0))

  initWindow(screenWidth, screenHeight, "Limberfist/Throwing Hands")
  when defined(emscripten):
    emscriptenSetMainLoop(updateDrawFrame, 0, 1)
  else:
    setTargetFPS(60) # Set our game to run at 60 frames-per-second
    # ------------------------------------------------------------------------------------
    # Main game loop
    while not windowShouldClose(): # Detect window close button or ESC key
      updateDrawFrame()
  # De-Initialization
  # --------------------------------------------------------------------------------------
  closeWindow() # Close window and OpenGL context
  # --------------------------------------------------------------------------------------

main()