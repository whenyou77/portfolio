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

import raylib, raymath, reasings, nim_tiled, std/math

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
    pos: Vector2
    size: Vector2
  Actor = object of Thing
    vel: Vector2
    hp: int
  Solid = object of Thing
  Player = object of Actor
    att_cooldown: int
  Wall = object of Solid
const
  screenWidth = 960
  screenHeight = 960

var currentScreen = title
var nextScreen = title
var fadeAlpha = 0.0
var fadeTimer = 60
var fadeOut = false
var fadeInLen = 60
var fadeOutLen = 60
var transitioning = false

var players: array[4,Player]
var walls: seq[Wall] = @[]

var camera = Camera2D(zoom:1.0)

# function to activate transition
proc transition(transitionTo:Screen,lengthIn:int,lengthOut:int) =
  if not transitioning:
    transitioning = true
    fadeOut = false
    nextScreen=transitionTo
    fadeInLen = lengthIn
    fadeTimer = lengthIn
    fadeOutLen = lengthOut

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
        if p.att_cooldown > 0: p.att_cooldown -= 1
        if i == 0:
          if isKeyDown(D) or isKeyDown(Right):
            if p.vel.x < 8.0: p.vel.x += 0.5
          elif isKeyDown(A) or isKeyDown(Left):
            if p.vel.x > -8.0: p.vel.x -= 0.5
          else:
            if p.vel.x > 0.0: 
              p.vel.x -= 0.3
              if p.vel.x < 0.0:
                p.vel.x = 0.0
            elif p.vel.x < 0.0: 
              p.vel.x += 0.3
              if p.vel.x > 0.0:
                p.vel.x = 0.0
          if isKeyDown(S) or isKeyDown(Down):
            if p.vel.y < 8.0: p.vel.y += 0.5
          elif isKeyDown(W) or isKeyDown(Up):
            if p.vel.y > -8.0: p.vel.y -= 0.5
          else:
            if p.vel.y > 0.0: 
              p.vel.y -= 0.3
              if p.vel.y < 0.0:
                p.vel.y = 0.0
            elif p.vel.y < 0.0: 
              p.vel.y += 0.3
              if p.vel.y > 0.0:
                p.vel.y = 0.0
          if isMouseButtonPressed(MouseButton.Left): p.att_cooldown = 60
        p.pos += p.vel
      camera.offset = Vector2(x: screenWidth/2.0-players[0].pos.x, y: screenHeight/2.0-players[0].pos.y)
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
        of gameplay: players[0] = Player(pos:Vector2(x:64.0,y:64.0),size:Vector2(x:32.0,y:32.0),vel:Vector2(),hp:1,att_cooldown:0)
        else: camera.offset = Vector2(x: 0.0, y: 0.0)    

  # --------------------------------------------------------------------------------------
  # Draw
  # --------------------------------------------------------------------------------------
  beginDrawing()
  beginMode2D(camera)
  clearBackground(RayWhite)
  if currentScreen == title: drawText("Welcome! Press Enter to continue!", 20, screenHeight-60, 40, LightGray)
  # don't want to repeat the same code for rendering gameplay in pause screen
  elif currentScreen == gameplay or currentScreen == pause: 
    drawText("*Blows up pancakes with mind*\n\n\nPress Enter to open the pause screen.", 20, screenHeight-100, 40, LightGray)
    for i,p in players.pairs:
      drawRectangle(p.pos,p.size,Green)
  endMode2D()
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