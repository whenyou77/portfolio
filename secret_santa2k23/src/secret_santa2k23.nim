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

import raylib, raymath, reasings, nim_tiled, std/math, os

# ----------------------------------------------------------------------------------------
# Global Variables Definition
# ----------------------------------------------------------------------------------------
type 
  Screen = enum
    title
    charaSelect
    gameplay
    pause
    gameOver
    thxForPlaying
  Thing = object of RootObj
    pos: Vector3
    size: Vector3
  Actor = object of Thing
    vel: Vector3
    hp: int
    grounded: bool
  Solid = object of Thing
  Player = object of Actor
    att_cooldown: int
  Wall = object of Solid
const
  screenWidth = 960
  screenHeight = 960
  cameraZoom = 56.0 # how far is the camera from the player? Base: 56

var currentScreen = title
var nextScreen = title
var fadeAlpha = 0.0
var fadeTimer = 60
var fadeOut = false
var fadeInLen = 60
var fadeOutLen = 60
var transitioning = false

var players: array[4,Player]
var walls: seq[Wall] = @[Wall(pos:Vector3(x: -4.0,y:4.0,z: 4.0),size:Vector3(x: 8.0,y:8.0,z: 8.0))]
var level: Model

var camera = Camera(
  position: Vector3(x: 5, y: 5, z: 10),  # Camera position
  target: Vector3(x: 0, y: 0, z: 0),     # Camera target it looks-at
  up: Vector3(x: 0, y: 1, z: 0),         # Camera up vector (rotation over its axis)
  fovy: 45,                              # Camera field-of-view apperture in Y (degrees)
  projection: Orthographic           # Defines projection type, see CameraProjection
)

# function to activate transition
proc transition(transitionTo:Screen,lengthIn:int,lengthOut:int) =
  if not transitioning:
    transitioning = true
    fadeOut = false
    nextScreen=transitionTo
    fadeInLen = lengthIn
    fadeTimer = lengthIn
    fadeOutLen = lengthOut

proc aabbcc*(x1: float, y1: float, z1: float, w1: float, h1: float, d1: float,
x2: float, y2: float, z2: float, w2: float, h2: float, d2: float): bool =
  if
    x1-w1/2.0 < x2 + w2/2.0 and
    x1 + w1/2.0 > x2 - w2/2.0 and
    y1-h1/2.0 < y2 + h2/2.0 and
    h1/2.0 + y1 > y2-h2/2.0 and
    z1-d1/2.0 < z2 + d2/2.0 and
    d1/2.0 + z1 > z2-d2/2.0:
      return true
  false

# ----------------------------------------------------------------------------------------
# Module functions Definition
# ----------------------------------------------------------------------------------------

proc updateDrawFrame {.cdecl.} =
  # Update
  # --------------------------------------------------------------------------------------
  
  # Game logic
  case currentScreen:
    of gameplay:
      for i,p in players.mpairs:
        if p.att_cooldown > 0: 
          p.att_cooldown -= 1
          echo p.att_cooldown
        if p.vel.y > -2.0: p.vel.y -= 0.04
        if i == 0:
          if isKeyDown(D) or isKeyDown(Right):
            if p.vel.x < 0.5: p.vel.x += 0.075
          elif isKeyDown(W) or isKeyDown(Left):
            if p.vel.x > -0.5: p.vel.x -= 0.075
          else:
            if p.vel.x > 0.0: 
              p.vel.x -= 0.05
              if p.vel.x < 0.0:
                p.vel.x = 0.0
            elif p.vel.x < 0.0: 
              p.vel.x += 0.05
              if p.vel.x > 0.0:
                p.vel.x = 0.0
          if isKeyDown(S) or isKeyDown(Down):
            if p.vel.z < 0.5: p.vel.z += 0.075
          elif isKeyDown(KeyboardKey.E) or isKeyDown(Up):
            if p.vel.z > -0.5: p.vel.z -= 0.075
          else:
            if p.vel.z > 0.0: 
              p.vel.z -= 0.05
              if p.vel.z < 0.0:
                p.vel.z = 0.0
            elif p.vel.z < 0.0: 
              p.vel.z += 0.05
              if p.vel.z > 0.0:
                p.vel.z = 0.0
          if isKeyPressed(Space) and p.grounded: p.vel.y = 1.0
          if isMouseButtonPressed(MouseButton.Left) and p.att_cooldown == 0: p.att_cooldown = 60
        p.grounded = false
        p.pos.x += p.vel.x
        for w in walls:
          if aabbcc(p.pos.x,p.pos.z,p.pos.y,p.size.x,p.size.z,p.size.y,w.pos.x,w.pos.z,w.pos.y,w.size.x,w.size.z,w.size.y):
            if p.pos.x > w.pos.x:
              p.pos.x = w.pos.x+w.size.x/2.0+p.size.x/2.0
            else:
              p.pos.x = w.pos.x-w.size.x/2.0-p.size.x/2.0
            p.vel.x = 0.0
            echo "collision"
        p.pos.z += p.vel.z
        for w in walls:
          if aabbcc(p.pos.x,p.pos.z,p.pos.y,p.size.x,p.size.z,p.size.y,w.pos.x,w.pos.z,w.pos.y,w.size.x,w.size.z,w.size.y):
            if p.pos.z > w.pos.z:
              p.pos.z = w.pos.z+w.size.z/2.0+p.size.z/2.0
            else:
              p.pos.z = w.pos.z-w.size.z/2.0-p.size.z/2.0
            echo "collision"
            p.vel.z = 0.0
        p.pos.y += p.vel.y
        for w in walls:
          if aabbcc(p.pos.x,p.pos.z,p.pos.y,p.size.x,p.size.z,p.size.y,w.pos.x,w.pos.z,w.pos.y,w.size.x,w.size.z,w.size.y):
            if p.pos.y > w.pos.y:
              p.pos.y = w.pos.y+w.size.y/2.0+p.size.y/2.0
              p.vel.y = 0.0
              p.grounded = true
            else:
              p.pos.y = w.pos.y-w.size.y/2.0-p.size.y/2.0
            echo "collision"
        echo p.pos.x, p.pos.z
        if p.pos.y < p.size.y/2.0: 
          p.pos.y = p.size.y/2.0
          p.vel.y = 0.0
          p.grounded = true
      camera.position = players[0].pos + Vector3(x:cameraZoom,y:cameraZoom,z:cameraZoom)
      camera.target = players[0].pos
      if isKeyPressed(Enter): currentScreen = pause
    of pause:
      if isKeyPressed(Enter): currentScreen = gameplay
      if isKeyPressed(Backspace): transition(title,30,30)
    else: 
      if isKeyPressed(Enter): transition(gameplay,30,30)

  # Transition effect
  if transitioning:
    fadeTimer -= 1
    fadeAlpha = 255.0*((fadeInLen-fadeTimer)/fadeInLen)
    if fadeOut: 
      fadeAlpha = 255.0*((fadeTimer-fadeOutLen)/fadeOutLen)
      if fadeTimer == 0: 
        transitioning = false
    elif fadeTimer == 0: 
      # switch to next screen, start fading out
      fadeOut = true
      fadeTimer=fadeOutLen
      currentScreen = nextScreen
      case currentScreen:
        of gameplay: players[0] = Player(pos:Vector3(x: 0.0,y:1.0,z: 0.0),size:Vector3(x:2.0,y:2.0,z:2.0),vel:Vector3(),hp:1,att_cooldown:0)
        else: camera.position = Vector3()
  # --------------------------------------------------------------------------------------
  # Draw
  # --------------------------------------------------------------------------------------
  beginDrawing()
  clearBackground(Color(r:8,g:8,b:16,a:255))
  if currentScreen == title: drawText("Welcome! Press Enter to continue!", 20, screenHeight-60, 40, LightGray)
  # don't want to repeat the same code for rendering gameplay in pause screen
  elif currentScreen == gameplay or currentScreen == pause: 
    drawText("*Blows up pancakes with mind*\n\n\nPress Enter to open the pause screen.", 20, screenHeight-100, 40, LightGray)
    beginMode3D(camera)
    drawModel(level, Vector3(x:0.0,y:0.0,z:0.0),4.0,White)
    for i,p in players.pairs:
      #drawRectangle(p.pos,p.size,Green)
      drawCube(p.pos,p.size,Green)
      let groundpos = 0.0 # shadow's y (ground height)
      drawCircle3D(Vector3(x:p.pos.x,y:0.1,z:p.pos.z),2.0-(p.pos.y-groundpos)/10.0,Vector3(x:1.0),90.0,Black)
      #drawCubeWires(p.pos,p.size*1.5,Blue)
      #drawGrid(1000,2.0)
    for w in walls:
      drawCube(w.pos,w.size,Red)
    endMode3D()
  # pause screen
  if currentScreen == pause:
    drawRectangle(0,0,screenWidth,screenHeight,Color(r:0,g:0,b:0,a:96))
    drawText("PAUSED.\nPress Backspace to return to title.\nPress Enter to get back into gameplay.",10,10,20,White)
  drawRectangle(0,0,screenWidth,screenHeight,Color(r:0,g:0,b:0,a:fadeAlpha.uint8)) # transition rectangle
  endDrawing()
  # --------------------------------------------------------------------------------------

# ----------------------------------------------------------------------------------------
# Program main entry point
# ----------------------------------------------------------------------------------------

proc main =
  # Initialization
  # --------------------------------------------------------------------------------------
  initWindow(screenWidth, screenHeight, "raylib [core] example - basic window")
  level = loadModel(getAppDir() & "./dungeon_test.obj")
  let level_tex = loadTexture(getAppDir() & "./dungeon_tileset2.png")
  level_tex.setTextureFilter(Point)
  level.materials[0].maps[Albedo].texture= level_tex
  when defined(emscripten):
    emscriptenSetMainLoop(updateDrawFrame, 60, 1)
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