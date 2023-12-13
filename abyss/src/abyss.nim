# ****************************************************************************************
#
#   raylib [core] example - Basic window
#
#   Welcome to raylib!
#
#   To test examples, just press F6 and execute raylib_compile_execute script
#   Note that compiled executable is placed in the same folder as .c file
#
#   You can find all basic examples on C:\raylib\raylib\examples folder or
#   raylib official webpage: www.raylib.com
#
#   Enjoy using raylib. :)
#
#   Example originally created with raylib 1.0, last time updated with raylib 1.0
#
#   Example licensed under an unmodified zlib/libpng license, which is an OSI-certified,
#   BSD-like license that allows static linking with closed source software
#
#   Copyright (c) 2013-2023 Ramon Santamaria (@raysan5)
#   Converted to Nim by Antonis Geralis (@planetis-m) in 2022
#
# ****************************************************************************************

import raylib, os, math

# ----------------------------------------------------------------------------------------
# Global Variables Definition
# ----------------------------------------------------------------------------------------

const
  screenWidth = 640
  screenHeight = 704
  mapSize = 20

type State = enum
  gameplay
  pause
  fail
  title
  
type Player = object
  pos: Vector2
  vel: Vector2
  coyote: int
  jump_buffer: int
  mobile: bool
  
type Wall = object
  pos: Vector2
  size: Vector2

proc aabb*(x1: float, y1: float, w1: float, h1: float,
x2: float, y2: float, w2: float, h2: float): bool =
  if
    x1 < x2 + w2 and
    x1 + w1 > x2 and
    y1 < y2 + h2 and
    h1 + y1 > y2:
      return true
  false
# ----------------------------------------------------------------------------------------
# Program main entry point
# ----------------------------------------------------------------------------------------

var players: seq[Player]
var state = gameplay
let level_template = readFile($getAppDir() & "\\lvl.txt")
var level = level_template
echo level_template
var stage = 0
var gems_left = 0
var camera = Camera2D(zoom:1.0,offset:Vector2(x:0.0,y: -stage.float*640.0))

proc main =
  # Initialization
  # --------------------------------------------------------------------------------------
  for y in stage*mapSize..stage*mapSize+mapSize-1:
    for x in 0..mapSize-1:
      if level[y*22+x] == '2':
        players.add(Player(pos:Vector2(x:x.float*32.0,y:y.float*32.0),mobile:true))
      if level[y*22+x] == '3':
        gems_left += 1
  initWindow(screenWidth, screenHeight, "raylib [core] example - basic window")
  setTargetFPS(60) # Set our game to run at 60 frames-per-second
  # --------------------------------------------------------------------------------------
  # Main game loop
  while not windowShouldClose(): # Detect window close button or ESC key
    # Update
    # ------------------------------------------------------------------------------------
    # TODO: Update your variables here
    # ------------------------------------------------------------------------------------
    if state == gameplay:
      for p in players.mitems:
        if p.vel.y < 16.0: p.vel.y += 0.7
        if p.mobile:
          if isKeyDown(D):
            p.vel.x = 4
          elif isKeyDown(A):
            p.vel.x = -4
          else:
            p.vel.x = 0
          if isKeyPressed(W): p.jump_buffer = 10
        echo p.coyote, p.jump_buffer
        if p.jump_buffer > 0 and p.coyote > 0:
          p.vel.y = -10
          p.jump_buffer = 0
          p.coyote = 0
        if p.coyote > 0: p.coyote -= 1
        if p.jump_buffer > 0: p.jump_buffer -= 1
        p.pos.x += p.vel.x.round()
        if level[(floor(p.pos.y.float/32.0)*(mapSize+2).float+floor(p.pos.x.float/32.0)).int] == '1' or level[(floor((p.pos.y.float+31.0)/32.0)*(mapSize+2).float+floor(p.pos.x.float/32.0)).int] == '1':
          p.pos.x = (floor((p.pos.x.float)/32.0)+1)*32.0
        if level[(floor(p.pos.y.float/32.0)*(mapSize+2).float+floor((p.pos.x.float+31.0)/32.0)).int] == '1' or level[(floor((p.pos.y.float+31.0)/32.0)*(mapSize+2).float+floor((p.pos.x.float+31.0)/32.0)).int] == '1':
          p.pos.x = (floor((p.pos.x.float+31.0)/32.0)-1)*32.0
        for p2 in players.mitems:
          if p == p2: continue
          if aabb(p.pos.x,p.pos.y,32.0,32.0,p2.pos.x,p2.pos.y,32.0,32.0):
            if p.pos.x+16.0>p2.pos.x+16.0:
              p.pos.x = p2.pos.x+32.0
            else:
              p.pos.x = p2.pos.x-32.0
        p.pos.y += p.vel.y.round()
        if level[(floor(p.pos.y.float/32.0)*(mapSize+2).float+floor(p.pos.x.float/32.0)).int] == '1' or level[(floor(p.pos.y.float/32.0)*(mapSize+2).float+floor((p.pos.x.float+31.0)/32.0)).int] == '1':
          p.pos.y = (floor((p.pos.y.float)/32.0)+1)*32.0
          p.vel.y = 0.0
        if level[(floor((p.pos.y.float+31.0)/32.0)*(mapSize+2).float+floor(p.pos.x.float/32.0)).int] == '1' or level[(floor((p.pos.y.float+31.0)/32.0)*(mapSize+2).float+floor((p.pos.x.float+31.0)/32.0)).int] == '1':
          p.pos.y = (floor((p.pos.y.float+31.0)/32.0)-1)*32.0
          p.vel.y = 0.0
          p.coyote = 5
        for p2 in players.mitems:
          if p == p2: continue
          if aabb(p.pos.x,p.pos.y,32.0,32.0,p2.pos.x,p2.pos.y,32.0,32.0):
            if p.pos.y+16.0>p2.pos.y+16.0:
              p.pos.y = p2.pos.y+32.0
            else:
              p.pos.y = p2.pos.y-32.0
              p.vel.y = 0.0
              p.coyote = 5  
        if level[(floor(p.pos.y.float/32.0)*(mapSize+2).float+floor(p.pos.x.float/32.0)).int] == '4' or 
        level[(floor((p.pos.y.float+31.0)/32.0)*(mapSize+2).float+floor(p.pos.x.float/32.0)).int] == '4' or 
        level[(floor(p.pos.y.float/32.0)*(mapSize+2).float+floor((p.pos.x.float+31.0)/32.0)).int] == '4' or 
        level[(floor((p.pos.y.float+31.0)/32.0)*(mapSize+2).float+floor((p.pos.x.float+31.0)/32.0)).int] == '4': 
          for _ in 0..players.len()-1:
            players.delete(0)
          gems_left = 0
          for y in stage*20..stage*20+mapSize-1:
            for x in 0..mapSize-1:
              if level_template[y*22+x] == '2':
                players.add(Player(pos:Vector2(x:x.float*32.0,y:y.float*32.0),mobile:true))
              if level_template[y*22+x] == '3':
                level[y*22+x] = '3'
                gems_left += 1

        if level[(floor(p.pos.y.float/32.0)*(mapSize+2).float+floor(p.pos.x.float/32.0)).int] == '3':
          gems_left -= 1
          p.mobile = false
          p.vel.x = 0.0
          level[(floor(p.pos.y.float/32.0)*(mapSize+2).float+floor(p.pos.x.float/32.0)).int] = ' '
        if level[(floor((p.pos.y.float+31.0)/32.0)*(mapSize+2).float+floor(p.pos.x.float/32.0)).int] == '3':
          gems_left -= 1
          p.mobile = false
          p.vel.x = 0.0
          level[(floor((p.pos.y.float+31.0)/32.0)*(mapSize+2).float+floor(p.pos.x.float/32.0)).int] = ' '
        if level[(floor(p.pos.y.float/32.0)*(mapSize+2).float+floor((p.pos.x.float+31.0)/32.0)).int] == '3':
          gems_left -= 1
          p.mobile = false
          p.vel.x = 0.0
          level[(floor(p.pos.y.float/32.0)*(mapSize+2).float+floor((p.pos.x.float+31.0)/32.0)).int] = ' '
        if level[(floor((p.pos.y.float+31.0)/32.0)*(mapSize+2).float+floor((p.pos.x.float+31.0)/32.0)).int] == '3':
          gems_left -= 1
          p.mobile = false
          p.vel.x = 0.0
          level[(floor((p.pos.y.float+31.0)/32.0)*(mapSize+2).float+floor((p.pos.x.float+31.0)/32.0)).int] = ' '

      if isKeyPressed(Enter):
        state = pause
      if gems_left == 0:
        stage += 1
        camera.offset.y -= 640
        for _ in 0..players.len()-1:
          players.delete(0)
        for y in stage*20..stage*20+mapSize-1:
          for x in 0..mapSize-1:
            if level[y*22+x] == '2':
              players.add(Player(pos:Vector2(x:x.float*32.0,y:y.float*32.0),mobile:true))
            if level[y*22+x] == '3':
              gems_left += 1
    elif state == pause:
      if isKeyPressed(Enter):
        state = gameplay
    # Draw
    # ------------------------------------------------------------------------------------
    beginDrawing()
    clearBackground(RayWhite)
    beginMode2D(camera)
    for p in players:
      drawRectangle(p.pos,Vector2(x:32.0,y:32.0),Green)
    for y in stage*mapSize..stage*mapSize+19:
      for x in 0..19:
        if level[y*22+x] == '1':
          drawRectangle(Vector2(x:x.float*32.0,y:y.float*32.0),Vector2(x:32.0,y:32.0),Black)
        if level[y*22+x] == '3':
          drawRectangle(Vector2(x:x.float*32.0,y:y.float*32.0),Vector2(x:32.0,y:32.0),SkyBlue)
        if level[y*22+x] == '4':
          drawRectangle(Vector2(x:x.float*32.0,y:y.float*32.0),Vector2(x:32.0,y:32.0),Red)
    endMode2D()
    if state == pause:
      drawRectangle(0,0,screenWidth,screenHeight,Color(r:0,g:0,b:0,a:64))
      drawText("PAUSED", 10, 10, 20, White)
    #drawText("Congrats! You created your first window!", 190, 200, 20, LightGray)
    endDrawing()
  # ------------------------------------------------------------------------------------
  # De-Initialization
  # --------------------------------------------------------------------------------------
  closeWindow() # Close window and OpenGL context
  # --------------------------------------------------------------------------------------

main()