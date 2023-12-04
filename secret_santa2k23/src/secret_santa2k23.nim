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

import raylib, raymath, nim_tiled

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

var players: seq[Player] = @[]
var walls: seq[Wall] = @[]

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
        if i == 0:
          if isKeyDown(D):
            p.vel.x = 4.0
          elif isKeyDown(A):
            p.vel.x = -4.0
          else:
            p.vel.x = 0.0
          if isKeyDown(S):
            p.vel.y = 4.0
          elif isKeyDown(W):
            p.vel.y = -4.0
          else:
            p.vel.y = 0.0
        p.pos += p.vel
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
      if currentScreen == gameplay:
        players.add(Player(pos:Vector2(x:64.0,y:64.0),size:Vector2(x:32.0,y:32.0),vel:Vector2(),hp:1))
      if currentScreen == title:
        for _ in 0..players.len()-1:
          players.del(0)

  # --------------------------------------------------------------------------------------
  # Draw
  # --------------------------------------------------------------------------------------
  beginDrawing()
  clearBackground(RayWhite)
  if currentScreen == title: drawText("Welcome! Press Enter to continue!", 380, 400, 40, LightGray)
  # don't want to repeat the same code for rendering gameplay in pause screen
  elif currentScreen == gameplay or currentScreen == pause: 
    drawText("*Blows up pancakes with mind*\n\n\nPress Enter to open the pause screen.", 380, 400, 40, LightGray)
    for i,p in players.pairs:
      drawRectangle(p.pos,p.size,Green)
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