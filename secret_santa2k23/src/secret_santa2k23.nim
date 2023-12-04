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

import raylib, nim_tiled

# ----------------------------------------------------------------------------------------
# Global Variables Definition
# ----------------------------------------------------------------------------------------
type 
  Screen = enum
    title
    charaSelect
    gameplay
    gameOver
    thxForPlaying
const
  screenWidth = 1600
  screenHeight = 900

var currentScreen = title
var nextScreen = title
var fadeAlpha = 0.0
var fadeTimer = 60
var fadeOut = false
var fadeInLen = 60
var fadeOutLen = 60
var transitioning = false

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
  # TODO: Update your variables here
  
  if currentScreen == title and isKeyPressed(Enter): transition(gameplay,30,30)
  if currentScreen == gameplay and isKeyPressed(Backspace): transition(title,30,30)
  if transitioning:
    fadeTimer -= 1
    fadeAlpha = 255.0*((fadeInLen-fadeTimer)/fadeInLen)
    if fadeOut: 
      fadeAlpha = 255.0*((fadeTimer-fadeOutLen)/fadeOutLen)
      if fadeTimer == 0: 
        transitioning = false
    elif fadeTimer == 0: 
      fadeOut = true
      fadeTimer=fadeOutLen
      currentScreen = nextScreen
    echo fadeTimer

  # --------------------------------------------------------------------------------------
  # Draw
  # --------------------------------------------------------------------------------------
  beginDrawing()
  clearBackground(RayWhite)
  if currentScreen == title: drawText("Welcome! Press Enter to continue!", 380, 400, 40, LightGray)
  if currentScreen == gameplay: 
    drawText("*Blows up pancakes with mind*\n\n\nPress Backspace to return.", 380, 400, 40, LightGray)
    
  drawRectangle(0,0,screenWidth,screenHeight,Color(r:0,g:0,b:0,a:fadeAlpha.uint8))
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