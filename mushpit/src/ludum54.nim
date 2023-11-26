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

import raylib
import std/random,std/math,os

# ----------------------------------------------------------------------------------------
# Global Variables Definition
# ----------------------------------------------------------------------------------------

const
  screenWidth = 960.0
  screenHeight = 960.0
  mosherRadius = 32.0
  mosherNum = 200

type Hairdo = enum
  bald,
  mohawk,
  curly,
  straight,
  cap

type 
  Mosher = object
    pos: Vector2
    vel: Vector2
    player: bool
    target: int
    hairdo: Hairdo
    hair_color: Color

proc circle_collision(pos1: Vector2, pos2:Vector2): bool =
  let dx = abs(pos1.x-pos2.x)
  let dy = abs(pos1.y-pos2.y)
  if sqrt(dx*dx+dy*dy) <= mosherRadius*2.0: return true
  else: return false

proc aabb(x1: float32, y1: float32, w1: float32, h1: float32,
x2: float32, y2: float32, w2: float32, h2: float32): bool =
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

proc main =
  randomize()
  # Initialization
  # --------------------------------------------------------------------------------------
  initWindow(screenWidth.int32, screenHeight.int32, "MUSHPIT")
  setTargetFPS(60) # Set our game to run at 60 frames-per-second
  let h1img = loadImage(getAppDir()/"./Sprite-0002.png")
  let hairdo1 = loadTextureFromImage(h1img)
  let h2img = loadImage(getAppDir()/"./Sprite-0003.png")
  let hairdo2 = loadTextureFromImage(h2img)
  let h3img = loadImage(getAppDir()/"./Sprite-0004.png")
  let hairdo3 = loadTextureFromImage(h3img)
  let h4img = loadImage(getAppDir()/"./Sprite-0005.png")
  let hairdo4 = loadTextureFromImage(h4img)
  var moshers: array[0..mosherNum,Mosher]
  moshers[0] = Mosher(pos:Vector2(x:screenWidth/2.0,y:screenHeight/2.0),player:true,vel:Vector2(x:0.0,y:0.0),hairdo:bald,hair_color:White)
  var timer = 0
  var oxygen = 3600
  echo mosherNum
  for i in 1..mosherNum:
    moshers[i] = Mosher(pos:Vector2(x:rand(48..914).float,y:rand(48..914).float),player:false,vel:Vector2(x:0.0,y:0.0),hairdo:rand(0..4).Hairdo,hair_color:Color(r:rand(0..255).uint8,g:rand(0..255).uint8,b:rand(0..255).uint8,a:255))
  # --------------------------------------------------------------------------------------
  # Main game loop
  block game:
    while not windowShouldClose(): # Detect window close button or ESC key
    # Update
    # ------------------------------------------------------------------------------------
    # TODO: Update your variables here
    # ------------------------------------------------------------------------------------
    # Draw
    # ------------------------------------------------------------------------------------
      beginDrawing()
      clearBackground(DarkBlue)
      for n,m in moshers.mpairs:
        if m.player: 
          if isKeyDown(D) or isKeyDown(Right):
            if m.vel.x < 8.0: m.vel.x += 0.5
          elif isKeyDown(A) or isKeyDown(Left):
            if m.vel.x > -8.0: m.vel.x -= 0.5
          else:
            if m.vel.x > 0.0: 
              m.vel.x -= 0.3
              if m.vel.x < 0.0:
                m.vel.x = 0.0
            elif m.vel.x < 0.0: 
              m.vel.x += 0.3
              if m.vel.x > 0.0:
                m.vel.x = 0.0
          m.pos.x += m.vel.x
          if isKeyDown(S) or isKeyDown(Down):
            if m.vel.y < 8.0: m.vel.y += 0.5
          elif isKeyDown(W) or isKeyDown(Up):
            if m.vel.y > -8.0: m.vel.y -= 0.5
          else:
            if m.vel.y > 0.0: 
              m.vel.y -= 0.3
              if m.vel.y < 0.0:
                m.vel.y = 0.0
            elif m.vel.y < 0.0: 
              m.vel.y += 0.3
              if m.vel.y > 0.0:
                m.vel.y = 0.0
          m.pos.y += m.vel.y
          if not aabb(m.pos.x-mosherRadius,m.pos.y-mosherRadius,mosherRadius*2,mosherRadius*2,0,0,screenWidth,screenHeight):
            break game
        else: 
          if m.vel.x > 0.0: 
            m.vel.x -= 0.3
            if m.vel.x < 0.0:
              m.vel.x = 0.0
          elif m.vel.x < 0.0: 
            m.vel.x += 0.3
            if m.vel.x > 0.0:
              m.vel.x = 0.0
          m.pos.x += m.vel.x
          if m.vel.y > 0.0: 
            m.vel.y -= 0.3
            if m.vel.y < 0.0:
              m.vel.y = 0.0
          elif m.vel.y < 0.0: 
            m.vel.y += 0.3
            if m.vel.y > 0.0:
              m.vel.y = 0.0
          m.pos.y += m.vel.y
          
      for n,m in moshers.mpairs:
        for n2,m2 in moshers.mpairs:
          if n != n2:
            if circle_collision(m.pos,m2.pos):
                #let farthest = Vector2(x:angle.cos()*4.0,y:angle.sin()*4.0)
              let farthest2 = arctan2(m.pos.y-m2.pos.y,m.pos.x-m2.pos.x)
              let farthest = arctan2(m2.pos.y-m.pos.y,m2.pos.x-m.pos.x)
              let point = Vector2(x:farthest.cos(),y:farthest.sin())
              let point2 = Vector2(x:farthest2.cos(),y:farthest2.sin())
              m.pos.x += point2.x-point.x
              m.pos.y += point2.y-point.y
              let mv = m.vel
              m.vel = m2.vel
              m2.vel = mv
        if not m.player:
          if m.pos.x > 928: 
            m.vel.x = -abs(m.vel.x)
            m.pos.x = 928
          if m.pos.x < 32: 
            m.vel.x = abs(m.vel.x)
            m.pos.x = 32
          if m.pos.y > 928: 
            m.vel.y = -abs(m.vel.y)
            m.pos.y = 928
          if m.pos.y < 32: 
            m.vel.y = abs(m.vel.y)
            m.pos.y = 32
        drawCircle(m.pos,mosherRadius-2,Color(r:225,g:224,b:180,a:255))
        if m.player: drawRing(m.pos,2.0,2.0,0.0,360.0,0,Lime)
        if not m.player:
          case m.hairdo:
          of mohawk: drawTexture(hairdo1,Vector2(x:m.pos.x-mosherRadius,y:m.pos.y-mosherRadius),m.hair_color)
          of curly: drawTexture(hairdo2,Vector2(x:m.pos.x-mosherRadius,y:m.pos.y-mosherRadius),m.hair_color)
          of straight: drawTexture(hairdo3,Vector2(x:m.pos.x-mosherRadius,y:m.pos.y-mosherRadius),m.hair_color)
          of cap: drawTexture(hairdo4,Vector2(x:m.pos.x-mosherRadius,y:m.pos.y-mosherRadius),m.hair_color)
          of bald: drawCircle(m.pos,mosherRadius,Color(r:225,g:224,b:180,a:255))
      drawRectangle(0,0,screenWidth.int32,screenHeight.int32,Color(r:0,g:0,b:64,a:170))

      drawRing(moshers[0].pos,mosherRadius,mosherRadius-10,0.0,360.0,0,Red)
        

      timer += 1
      if timer == 25:
        timer = 0
        for i in 0..mosherNum:
          let angle = rand(0..360).float*3.14/180.0
          moshers[i].vel = Vector2(x:angle.cos()*12.0,y:angle.sin()*12.0.float)
      oxygen -= 1
      if oxygen == 0: break

      drawText(("OXYGEN LEFT: " & $oxygen).cstring, 10, 10, 20, LightGray)
      endDrawing()
    # ------------------------------------------------------------------------------------
  # De-Initialization
  # --------------------------------------------------------------------------------------
  closeWindow() # Close window and OpenGL context
  # --------------------------------------------------------------------------------------

main()