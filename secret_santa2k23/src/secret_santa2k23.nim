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

import raylib, raymath, reasings, nim_tiled, std/math, os, rlgl

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
  wallSize = 16.0

var currentScreen = title
var nextScreen = title
var fadeAlpha = 0.0
var fadeTimer = 60
var fadeOut = false
var fadeInLen = 60
var fadeOutLen = 60
var transitioning = false
var stage = 0
var mapSize = 20 # the map is always square
var cam_angle = 0.0

var players: array[4,Player]
var walls: seq[Wall] = @[]
#var level: Model

let level_template = readFile($getAppDir() & "\\lvl.txt")
var level = level_template
var level_tex: Texture2D
var floor: Model
echo level_template

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


# 3d aabb collision
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

# Draw cube with texture piece applied to all faces
proc drawCubeTextureRec(texture: Texture2D, source: Rectangle, position: Vector3, width: float, height: float, length: float, faces: (bool,bool,bool,bool,bool,bool), color: Color) =

    let x: float = position.x
    let y: float = position.y
    let z: float = position.z
    let texWidth: float = texture.width.float
    let texHeight: float = texture.height.float

    # Set desired texture to be enabled while drawing following vertex data
    setTexture(texture.id)

    # We calculate the normalized texture coordinates for the desired texture-source-rectangle
    # It means converting from (tex.width, tex.height) coordinates to [0.0, 1.0] equivalent 
    rlBegin(Quads)
    color4ub(color.r, color.g, color.b, color.a)

        # Front face
    if faces[0]:
      normal3f(0.0, 0.0, 1.0)
      texCoord2f(source.x/texWidth, (source.y + source.height)/texHeight)
      vertex3f(x - width/2, y - height/2, z + length/2)
      texCoord2f((source.x + source.width)/texWidth, (source.y + source.height)/texHeight)
      vertex3f(x + width/2, y - height/2, z + length/2)
      texCoord2f((source.x + source.width)/texWidth, source.y/texHeight)
      vertex3f(x + width/2, y + height/2, z + length/2)
      texCoord2f(source.x/texWidth, source.y/texHeight)
      vertex3f(x - width/2, y + height/2, z + length/2)

        # Back face\
    if faces[1]:
      normal3f(0.0, 0.0, -1.0)
      texCoord2f((source.x + source.width)/texWidth, (source.y + source.height)/texHeight)
      vertex3f(x - width/2, y - height/2, z - length/2)
      texCoord2f((source.x + source.width)/texWidth, source.y/texHeight)
      vertex3f(x - width/2, y + height/2, z - length/2)
      texCoord2f(source.x/texWidth, source.y/texHeight)
      vertex3f(x + width/2, y + height/2, z - length/2)
      texCoord2f(source.x/texWidth, (source.y + source.height)/texHeight)
      vertex3f(x + width/2, y - height/2, z - length/2)

        # Top face
    if faces[2]:
      normal3f(0.0, 1.0, 0.0)
      texCoord2f(source.x/texWidth, source.y/texHeight)
      vertex3f(x - width/2, y + height/2, z - length/2)
      texCoord2f(source.x/texWidth, (source.y + source.height)/texHeight)
      vertex3f(x - width/2, y + height/2, z + length/2)
      texCoord2f((source.x + source.width)/texWidth, (source.y + source.height)/texHeight)
      vertex3f(x + width/2, y + height/2, z + length/2)
      texCoord2f((source.x + source.width)/texWidth, source.y/texHeight)
      vertex3f(x + width/2, y + height/2, z - length/2)

        # Bottom face
    if faces[3]:
      normal3f(0.0, -1.0, 0.0)
      texCoord2f((source.x + source.width)/texWidth, source.y/texHeight)
      vertex3f(x - width/2, y - height/2, z - length/2)
      texCoord2f(source.x/texWidth, source.y/texHeight)
      vertex3f(x + width/2, y - height/2, z - length/2)
      texCoord2f(source.x/texWidth, (source.y + source.height)/texHeight)
      vertex3f(x + width/2, y - height/2, z + length/2)
      texCoord2f((source.x + source.width)/texWidth, (source.y + source.height)/texHeight)
      vertex3f(x - width/2, y - height/2, z + length/2)

        # Right face
    if faces[4]:
      normal3f(1.0, 0.0, 0.0)
      texCoord2f((source.x + source.width)/texWidth, (source.y + source.height)/texHeight)
      vertex3f(x + width/2, y - height/2, z - length/2)
      texCoord2f((source.x + source.width)/texWidth, source.y/texHeight)
      vertex3f(x + width/2, y + height/2, z - length/2)
      texCoord2f(source.x/texWidth, source.y/texHeight)
      vertex3f(x + width/2, y + height/2, z + length/2)
      texCoord2f(source.x/texWidth, (source.y + source.height)/texHeight)
      vertex3f(x + width/2, y - height/2, z + length/2)

        # Left face
    if faces[5]:
      normal3f( - 1.0, 0.0, 0.0)
      texCoord2f(source.x/texWidth, (source.y + source.height)/texHeight)
      vertex3f(x - width/2, y - height/2, z - length/2)
      texCoord2f((source.x + source.width)/texWidth, (source.y + source.height)/texHeight)
      vertex3f(x - width/2, y - height/2, z + length/2)
      texCoord2f((source.x + source.width)/texWidth, source.y/texHeight)
      vertex3f(x - width/2, y + height/2, z + length/2)
      texCoord2f(source.x/texWidth, source.y/texHeight)
      vertex3f(x - width/2, y + height/2, z - length/2)

    rlEnd()

    setTexture(0)

# Rotates the camera around its up vector
# Yaw is "looking left and right"
# If rotateAroundTarget is false, the camera rotates around its position
# Note: angle must be provided in radians
proc cameraYaw(camera: var Camera, angle: float, rotateAroundTarget: bool) =

    # Rotation axis
    var up = camera.up.normalize()

    # View vector
    var targetPosition = camera.target-camera.position

    # Rotate view vector around up axis
    targetPosition = rotateByAxisAngle(targetPosition, up, angle)

    if rotateAroundTarget:
    
        # Move position relative to target
        camera.position = camera.target-targetPosition
    
    else: # rotate around camera.position
    
        # Move target relative to position
        camera.target = camera.position+targetPosition


# ----------------------------------------------------------------------------------------
# Module functions Definition
# ----------------------------------------------------------------------------------------

proc updateDrawFrame {.cdecl.} =
  # Update
  # --------------------------------------------------------------------------------------
  
  # Game logic
  case currentScreen:
    of gameplay:
      # i is the player id
      for i,p in players.mpairs:
        if p.att_cooldown > 0: 
          p.att_cooldown -= 1
          echo p.att_cooldown
        if p.vel.y > -2.0: p.vel.y -= 0.04
        if i == 0:
          if isKeyDown(D) or isKeyDown(Right):
            if p.vel.x < 0.5: p.vel.x += 0.075
          elif isKeyDown(A) or isKeyDown(Left):
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
          elif isKeyDown(W) or isKeyDown(Up):
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
          if isKeyPressed(KeyboardKey.E):
            cam_angle += PI/2.0
          if isKeyPressed(Q):
            cam_angle -= PI/2.0
          if cam_angle < 0.0: cam_angle = PI*1.5
          if cam_angle > PI*1.5: cam_angle = 0.0
          if isKeyPressed(Space) and p.grounded: p.vel.y = 1.0
          if isMouseButtonPressed(MouseButton.Left) and p.att_cooldown == 0: p.att_cooldown = 60
        p.grounded = false
        p.pos.x += p.vel.x
        if i == 0: echo (floor((p.pos.z.float+p.size.z/2.0+wallSize/2.0)/wallSize))*wallSize-wallSize/2.0-p.size.z/2.0, (floor((p.pos.z.float-p.size.z/2.0+wallSize/2.0)/wallSize))*wallSize+wallSize/2.0+p.size.z/2.0
        if level[(floor((p.pos.z-p.size.z/2.0+wallSize/2.0)/wallSize)*(mapSize+2).float+floor((p.pos.x.float-p.size.x/2.0+wallSize/2.0)/wallSize)).int] == '#' or level[(floor((p.pos.z.float+p.size.z/2.0+wallSize/2.0)/wallSize)*(mapSize+2).float+floor((p.pos.x.float-p.size.x/2.0+wallSize/2.0)/wallSize)).int] == '#':
          p.pos.x = (floor((p.pos.x.float-p.size.x/2.0+wallSize/2.0)/wallSize))*wallSize+wallSize/2.0+p.size.x/2.0
          p.vel.x = 0.0
          echo "collx-"
        elif level[(floor((p.pos.z+p.size.z/2.0+wallSize/2.0)/wallSize)*(mapSize+2).float+floor((p.pos.x.float+p.size.x/2.0+wallSize/2.0)/wallSize)).int] == '#' or level[(floor((p.pos.z.float-p.size.z/2.0+wallSize/2.0)/wallSize)*(mapSize+2).float+floor((p.pos.x.float+p.size.x/2.0+wallSize/2.0)/wallSize)).int] == '#':
          p.pos.x = (floor((p.pos.x.float+p.size.x/2.0+wallSize/2.0)/wallSize))*wallSize-wallSize/2.0-p.size.x/2.0-0.0001
          p.vel.x = 0.0
          echo "collx+"
        for w in walls:
          if aabbcc(p.pos.x,p.pos.z,p.pos.y,p.size.x,p.size.z,p.size.y,w.pos.x,w.pos.z,w.pos.y,w.size.x,w.size.z,w.size.y):
            if p.pos.x > w.pos.x:
              p.pos.x = w.pos.x+w.size.x/2.0+p.size.x/2.0
            else:
              p.pos.x = w.pos.x-w.size.x/2.0-p.size.x/2.0
            p.vel.x = 0.0
        p.pos.z += p.vel.z
        if level[(floor((p.pos.z-p.size.z/2.0+wallSize/2.0)/wallSize)*(mapSize+2).float+floor((p.pos.x.float-p.size.x/2.0+wallSize/2.0)/wallSize)).int] == '#' or level[(floor((p.pos.z.float-p.size.z/2.0+wallSize/2.0)/wallSize)*(mapSize+2).float+floor((p.pos.x.float+p.size.x/2.0+wallSize/2.0)/wallSize)).int] == '#':
          p.pos.z = (floor((p.pos.z.float-p.size.z/2.0+wallSize/2.0)/wallSize))*wallSize+wallSize/2.0+p.size.z/2.0
          p.vel.z = 0.0
          echo "collz-"
        elif level[(floor((p.pos.z+p.size.z/2.0+wallSize/2.0)/wallSize)*(mapSize+2).float+floor((p.pos.x.float-p.size.x/2.0+wallSize/2.0)/wallSize)).int] == '#' or level[(floor((p.pos.z.float+p.size.z/2.0+wallSize/2.0)/wallSize)*(mapSize+2).float+floor((p.pos.x.float+p.size.x/2.0+wallSize/2.0)/wallSize)).int] == '#':
          p.pos.z = (floor((p.pos.z.float+p.size.z/2.0+wallSize/2.0)/wallSize))*wallSize-wallSize/2.0-p.size.z/2.0-0.0001
          p.vel.z = 0.0
          echo "collz+"
        for w in walls:
          if aabbcc(p.pos.x,p.pos.z,p.pos.y,p.size.x,p.size.z,p.size.y,w.pos.x,w.pos.z,w.pos.y,w.size.x,w.size.z,w.size.y):
            if p.pos.z > w.pos.z:
              p.pos.z = w.pos.z+w.size.z/2.0+p.size.z/2.0
            else:
              p.pos.z = w.pos.z-w.size.z/2.0-p.size.z/2.0
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
        if p.pos.y < p.size.y/2.0: 
          p.pos.y = p.size.y/2.0
          p.vel.y = 0.0
          p.grounded = true
        if p.pos.y > wallSize-p.size.y/2.0:
          p.pos.y = wallSize-p.size.y/2.0
          p.vel.y = 0.0
      camera.position = players[0].pos + Vector3(x:cameraZoom,y:cameraZoom,z:cameraZoom)
      camera.target = players[0].pos
      camera.cameraYaw(cam_angle,true)
      if isKeyPressed(Enter): currentScreen = pause
      if isKeyPressed(R): transition(gameplay,30,30)
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
        of gameplay: 
          #[for y in stage*mapSize..stage*mapSize+mapSize-1:
            for x in 0..mapSize-1:
              if level[y*22+x] == '#':
                walls.add(Wall(pos:Vector3(x:x.float*wallSize,y:wallSize/2.0,z:y.float*wallSize),size:Vector3(x:wallSize,y:wallSize,z:wallSize)))]#
          cam_angle = 0.0
          for y in stage*mapSize..stage*mapSize+mapSize-1:
            for x in 0..mapSize-1:
              if level[y*22+x] == '2':
                players[0] = Player(pos:Vector3(x: x.float*wallSize,y:1.0,z: y.float*wallSize),size:Vector3(x:2.0,y:2.0,z:2.0),vel:Vector3(),hp:1,att_cooldown:0)
                break
        else: camera.position = Vector3()
  # --------------------------------------------------------------------------------------
  # Draw
  # --------------------------------------------------------------------------------------
  beginDrawing()
  clearBackground(Color(r:8,g:8,b:16,a:255))
  if currentScreen == title: drawText("Welcome! Press Enter to continue!", 20, screenHeight-60, 40, LightGray)
  # don't want to repeat the same code for rendering gameplay in pause screen
  elif currentScreen == gameplay or currentScreen == pause: 
    #drawText("*Blows up pancakes with mind*\n\n\nPress Enter to open the pause screen.", 20, screenHeight-100, 40, LightGray)
    beginMode3D(camera)
    #drawModel(level, Vector3(x:0.0,y:0.0,z:0.0),4.0,White)
    #drawModel(floor, Vector3(x:(mapSize/2).float*wallSize,y:0.0,z:(mapSize/2).float*wallSize),1.0,White)
    for i,p in players.pairs:
      #drawRectangle(p.pos,p.size,Green)
      drawCube(p.pos,p.size,Green)
      let groundpos = 0.0 # shadow's y (ground height)
      drawCircle3D(Vector3(x:p.pos.x,y:0.1,z:p.pos.z),2.0-(p.pos.y-groundpos)/10.0,Vector3(x:1.0),90.0,Black)
      #drawCubeWires(p.pos,p.size*1.5,Blue)
      #drawGrid(1000,2.0)
      #drawCube(w.pos,w.size,Red)
    let floorSize = wallSize*mapSize.float
    drawCubeTextureRec(level_tex, Rectangle(x:0,y:0,width:16,height:16),Vector3(x:0.0,y: -wallSize/2.0,z:0.0),floorSize,floorSize,floorSize,(false,false,true,false,false,false),LightGray)
    for y in stage*mapSize..stage*mapSize+mapSize-1:
      for x in 0..mapSize-1:
        #if x != 19 and y != stage*mapSize+19 and x != 0 and y != stage*mapSize:
          if level[y*22+x] == '#':
            if cam_angle == 0.0 and x != 19 and y != stage*mapSize+19:
              let row = mapSize+2 # how many characters till next row in the map?
              let front = not (level[y*row+x+row] == '#' or level[y*row+x+row] == '/')
              #let back = not (level[y*row+x-row] == '#')
              #let top = not (level[y*22+x] == '#')
              #let bottom = not (level[y*22+x] == '#')
              let right = not (level[y*row+x+1] == '#' or level[y*row+x+1] == '/')
              #let left = not (level[y*row+x-1] == '#')
              drawCubeTextureRec(level_tex, Rectangle(x:0,y:0,width:16,height:16),Vector3(x:x.float*wallSize,y:wallSize/2.0,z:y.float*wallSize),wallSize,wallSize,wallSize,(front,false,false,false,right,false),White)
            elif cam_angle == PI/2.0:
              let row = mapSize+2 # how many characters till next row in the map?
              let front = not (level[y*row+x+row] == '#')
              let back = not (level[y*row+x-row] == '#')
              #let top = not (level[y*22+x] == '#')
              #let bottom = not (level[y*22+x] == '#')
              let right = not (level[y*row+x+1] == '#')
              let left = not (level[y*row+x-1] == '#')
              drawCubeTextureRec(level_tex, Rectangle(x:0,y:0,width:16,height:16),Vector3(x:x.float*wallSize,y:wallSize/2.0,z:y.float*wallSize),wallSize,wallSize,wallSize,(front,false,false,false,false,left),White)
            elif cam_angle == PI and x != 0 and y != stage*mapSize:
              let row = mapSize+2 # how many characters till next row in the map?
              #let front = not (level[y*row+x+row] == '#')
              let back = not (level[y*row+x-row] == '#')
              #let top = not (level[y*22+x] == '#')
              #let bottom = not (level[y*22+x] == '#')
              #let right = not (level[y*row+x+1] == '#')
              let left = not (level[y*row+x-1] == '#')
              drawCubeTextureRec(level_tex, Rectangle(x:0,y:0,width:16,height:16),Vector3(x:x.float*wallSize,y:wallSize/2.0,z:y.float*wallSize),wallSize,wallSize,wallSize,(false,back,false,false,false,left),White)
            elif cam_angle == PI*1.5:
              let row = mapSize+2 # how many characters till next row in the map?
              let front = not (level[y*row+x+row] == '#')
              let back = not (level[y*row+x-row] == '#')
              #let top = not (level[y*22+x] == '#')
              #let bottom = not (level[y*22+x] == '#')
              let right = not (level[y*row+x+1] == '#')
              let left = not (level[y*row+x-1] == '#')
              drawCubeTextureRec(level_tex, Rectangle(x:0,y:0,width:16,height:16),Vector3(x:x.float*wallSize,y:wallSize/2.0,z:y.float*wallSize),wallSize,wallSize,wallSize,(front,back,false,false,right,left),White)
          elif level[y*22+x] == ' ' or level[y*22+x] == '2':
            drawCubeTextureRec(level_tex, Rectangle(x:0,y:0,width:16,height:16),Vector3(x:x.float*wallSize,y: -8.0,z:y.float*wallSize),wallSize,wallSize,wallSize,(false,false,true,false,false,false),LightGray)
    endMode3D()
    # 2d minimap for debugging purposes. Might leave it in the game because it's aesthetically pleasing
    #[for y in stage*mapSize..stage*mapSize+19:
      for x in 0..19:
        if level[y*22+x] == '#':
          drawRectangle(Vector2(x:x.float*wallSize,y:y.float*wallSize),Vector2(x:wallSize,y:wallSize),White)
    drawRectangle(Vector2(y:floor((players[0].pos.z-players[0].size.z/2.0+wallSize/2.0)/wallSize)*wallSize,x:floor((players[0].pos.x.float-players[0].size.x/2.0+wallSize/2.0)/wallSize)*wallSize),Vector2(x:wallSize,y:wallSize),Green)
    drawRectangle(Vector2(y:floor((players[0].pos.z+players[0].size.z/2.0+wallSize/2.0)/wallSize)*wallSize,x:floor((players[0].pos.x.float-players[0].size.x/2.0+wallSize/2.0)/wallSize)*wallSize),Vector2(x:wallSize,y:wallSize),Green)
    drawRectangle(Vector2(y:floor((players[0].pos.z-players[0].size.z/2.0+wallSize/2.0)/wallSize)*wallSize,x:floor((players[0].pos.x.float+players[0].size.x/2.0+wallSize/2.0)/wallSize)*wallSize),Vector2(x:wallSize,y:wallSize),Green)
    drawRectangle(Vector2(y:floor((players[0].pos.z+players[0].size.z/2.0+wallSize/2.0)/wallSize)*wallSize,x:floor((players[0].pos.x.float+players[0].size.x/2.0+wallSize/2.0)/wallSize)*wallSize),Vector2(x:wallSize,y:wallSize),Green)]#
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
  #level = loadModel(getAppDir() & "./dungeon_test.obj")
  level_tex = loadTexture(getAppDir() & "./dungeon_tileset2.png")
  level_tex.setTextureFilter(Point)
  #level.materials[0].maps[Albedo].texture= level_tex
  floor = loadModelFromMesh(genMeshPlane(mapSize.float*wallSize,mapSize.float*wallSize,10,10))
  floor.materials[0].maps[Albedo].texture = level_tex
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