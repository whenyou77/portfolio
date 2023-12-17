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

import raylib, raymath, reasings, std/math, os, rlgl, std/strutils

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
  Direction = enum
    up = 0
    right = 1
    down = 2
    left = 3
  CollectibleType = enum
    carrot # C
    banana # B
    dubloon # D
  EnemyType = enum
    possum # O
    crow # K
    jeopard # J
  Thing = object of RootObj
    pos: Vector3
    size: Vector3
  Collectible = object of Thing
    collectibleType: CollectibleType
  Actor = object of Thing
    vel: Vector3
    ext_vel: Vector3
    hp: float
    grounded: bool
    att_cooldown: int
  Solid = object of Thing
  Enemy = object of Actor
    enemyType: EnemyType
  Player = object of Actor # P
    charge_vel: Vector2 # when you attack, you charge. This is the velocity exerted on the player
    charge_cooldown: int
    bananized: bool
    dubloons_held: int
  Wall = object of Solid # #
const
  screenWidth = 960
  screenHeight = 960
  cameraZoom = 56.0 # how far is the camera from the player? Base: 56
  wallSize = 16.0
  playerMaxHp = 100.0

var currentScreen = title
var nextScreen = title
var fadeAlpha = 0.0
var fadeTimer = 0
var fadeOut = false
var fadeInLen = 0
var fadeOutLen = 0
var transitioning = false
var inElevator = false
var stage = 0
var mapSize = 20 # the map is always square
var row = mapSize+2 # how many characters till next row in the map? (\n also counts)
var carrotsHeld = 0 # carrots are shared
var startingCarrots = 0 # how many carrots were held when the stage ended?
var advance = false # switch to next stage?

var players: array[4,Player]
var walls: seq[Wall] = @[]
var collectibles: seq[Collectible] = @[]
var enemies: seq[Enemy] = @[]
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

proc circle_collision(pos1: Vector2, rad1: float, pos2:Vector2, rad2: float): bool =
  let dx = abs(pos1.x-pos2.x)
  let dy = abs(pos1.y-pos2.y)
  if sqrt(dx*dx+dy*dy) <= rad1+rad2: return true
  else: return false

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

        # Back face
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

# ----------------------------------------------------------------------------------------
# Module functions Definition
# ----------------------------------------------------------------------------------------

proc updateDrawFrame {.cdecl.} =
  # Update
  # --------------------------------------------------------------------------------------
  
  # Game logic
  case currentScreen:
    of gameplay:
      if not transitioning:

        # PLAYER

        var elevatorPlayers = 0
        
        # i is the player id

        for i,p in players.mpairs:
          var velMod = 1.0
          if p.bananized: velMod = 1.2
          if p.charge_cooldown > 0: 
            p.charge_cooldown -= 1
          if p.att_cooldown > 0: 
            p.att_cooldown -= 1
          if p.vel.y > -2.0: p.vel.y -= 0.04
          if i == 0:
            if p.charge_vel.x == 0.0 and p.charge_vel.y == 0.0:
              if isKeyDown(D) or isKeyDown(Right):
                if p.vel.x < 0.5*velMod: p.vel.x += 0.075*velMod
              elif isKeyDown(A) or isKeyDown(Left):
                if p.vel.x > -0.5*velMod: p.vel.x -= 0.075*velMod
              else:
                if p.vel.x > 0.0: 
                  p.vel.x -= 0.05*velMod
                  if p.vel.x < 0.0:
                    p.vel.x = 0.0
                elif p.vel.x < 0.0: 
                  p.vel.x += 0.05*velMod
                  if p.vel.x > 0.0:
                    p.vel.x = 0.0
              if isKeyDown(S) or isKeyDown(Down):
                if p.vel.z < 0.5*velMod: p.vel.z += 0.075*velMod
              elif isKeyDown(W) or isKeyDown(Up):
                if p.vel.z > -0.5*velMod: p.vel.z -= 0.075*velMod
              else:
                if p.vel.z > 0.0: 
                  p.vel.z -= 0.05*velMod
                  if p.vel.z < 0.0:
                    p.vel.z = 0.0
                elif p.vel.z < 0.0: 
                  p.vel.z += 0.05*velMod
                  if p.vel.z > 0.0:
                    p.vel.z = 0.0
            if isKeyPressed(Space) and p.grounded: p.vel.y = 1.0
            if (isMouseButtonPressed(MouseButton.Right) or isKeyPressed(X) or isKeyPressed(O)) and p.charge_cooldown == 0 and (p.vel.x != 0.0 or p.vel.z != 0.0): 
              p.charge_cooldown = 300
              p.vel.y = 0.0
              p.charge_vel = Vector2(x:1.0*p.vel.x.sgn().float,y:1.0*p.vel.z.sgn().float)
            if (isMouseButtonPressed(MouseButton.Left) or isKeyPressed(C) or isKeyPressed(P)) and p.att_cooldown == 0: 
              p.att_cooldown = 50
              let radius = sqrt(2.0)+1.0
              for e in enemies.mitems:
                if checkCollisionCircleRec(Vector2(x:p.pos.x,y:p.pos.z),radius.float32,Rectangle(x:e.pos.x,y:e.pos.z,width:e.size.x,height:e.size.z)):
                  e.hp -= 10.0
            if isKeyPressed(KeyboardKey.E) and carrotsHeld > 0 and p.hp < playerMaxHp:
              carrotsHeld -= 1
              p.hp += 10.0
          p.grounded = false
          p.pos.x += p.vel.x+p.charge_vel.x
          let rowFloat = row.float
          if level[(floor((p.pos.z-p.size.z/2.0+wallSize/2.0)/wallSize)*rowFloat+floor((p.pos.x.float-p.size.x/2.0+wallSize/2.0)/wallSize)).int] == '#' or level[(floor((p.pos.z.float+p.size.z/2.0+wallSize/2.0)/wallSize)*rowFloat+floor((p.pos.x.float-p.size.x/2.0+wallSize/2.0)/wallSize)).int] == '#':
            p.pos.x = (floor((p.pos.x.float-p.size.x/2.0+wallSize/2.0)/wallSize))*wallSize+wallSize/2.0+p.size.x/2.0
            p.vel.x = 0.0
          elif level[(floor((p.pos.z+p.size.z/2.0+wallSize/2.0)/wallSize)*rowFloat+floor((p.pos.x.float+p.size.x/2.0+wallSize/2.0)/wallSize)).int] == '#' or level[(floor((p.pos.z.float-p.size.z/2.0+wallSize/2.0)/wallSize)*rowFloat+floor((p.pos.x.float+p.size.x/2.0+wallSize/2.0)/wallSize)).int] == '#':
            p.pos.x = (floor((p.pos.x.float+p.size.x/2.0+wallSize/2.0)/wallSize))*wallSize-wallSize/2.0-p.size.x/2.0-0.0001
            p.vel.x = 0.0
          for w in walls:
            if aabbcc(p.pos.x,p.pos.z,p.pos.y,p.size.x,p.size.z,p.size.y,w.pos.x,w.pos.z,w.pos.y,w.size.x,w.size.z,w.size.y):
              if p.pos.x > w.pos.x:
                p.pos.x = w.pos.x+w.size.x/2.0+p.size.x/2.0
              else:
                p.pos.x = w.pos.x-w.size.x/2.0-p.size.x/2.0
              p.vel.x = 0.0
          p.pos.z += p.vel.z+p.charge_vel.y
          if level[(floor((p.pos.z-p.size.z/2.0+wallSize/2.0)/wallSize)*rowFloat+floor((p.pos.x.float-p.size.x/2.0+wallSize/2.0)/wallSize)).int] == '#' or level[(floor((p.pos.z.float-p.size.z/2.0+wallSize/2.0)/wallSize)*rowFloat+floor((p.pos.x.float+p.size.x/2.0+wallSize/2.0)/wallSize)).int] == '#':
            p.pos.z = (floor((p.pos.z.float-p.size.z/2.0+wallSize/2.0)/wallSize))*wallSize+wallSize/2.0+p.size.z/2.0
            p.vel.z = 0.0
          elif level[(floor((p.pos.z+p.size.z/2.0+wallSize/2.0)/wallSize)*rowFloat+floor((p.pos.x.float-p.size.x/2.0+wallSize/2.0)/wallSize)).int] == '#' or level[(floor((p.pos.z.float+p.size.z/2.0+wallSize/2.0)/wallSize)*rowFloat+floor((p.pos.x.float+p.size.x/2.0+wallSize/2.0)/wallSize)).int] == '#':
            p.pos.z = (floor((p.pos.z.float+p.size.z/2.0+wallSize/2.0)/wallSize))*wallSize-wallSize/2.0-p.size.z/2.0-0.0001
            p.vel.z = 0.0
          if level[(floor((p.pos.z+wallSize/2.0)/wallSize)*rowFloat+floor((p.pos.x.float+wallSize/2.0)/wallSize)).int] == 'E':
            let rec1 = Rectangle(x:floor((p.pos.x.float+wallSize/2.0)/wallSize)*wallSize-wallSize/2.0,y:floor((p.pos.z+wallSize/2.0)/wallSize)*wallSize-wallSize/2.0,width:wallSize,height:wallSize)
            let rec2 = Rectangle(x:p.pos.x-p.size.x/2.0,y:p.pos.z-p.size.z/2.0,width:p.size.x,height:p.size.z)
            let coll = getCollisionRec(rec1,rec2)
            if coll.width*coll.height == p.size.x*p.size.z:
              elevatorPlayers+=1
              echo stage
          if level[(floor((p.pos.z+wallSize/2.0)/wallSize)*rowFloat+floor((p.pos.x.float+wallSize/2.0)/wallSize)).int] == '/':
              level[(floor((p.pos.z+wallSize/2.0)/wallSize)*rowFloat+floor((p.pos.x.float+wallSize/2.0)/wallSize)).int] = ' '
          for w in walls:
            if aabbcc(p.pos.x,p.pos.z,p.pos.y,p.size.x,p.size.z,p.size.y,w.pos.x,w.pos.z,w.pos.y,w.size.x,w.size.z,w.size.y):
              if p.pos.z > w.pos.z:
                p.pos.z = w.pos.z+w.size.z/2.0+p.size.z/2.0
              else:
                p.pos.z = w.pos.z-w.size.z/2.0-p.size.z/2.0
              p.vel.z = 0.0
          # charge_vel x friction
          if p.charge_vel.x > 0.0: 
            p.vel.y = 0.0
            p.charge_vel.x -= 0.05
            if p.charge_vel.x < 0.0:
              p.charge_vel.x = 0.0
          elif p.charge_vel.x < 0.0: 
            p.vel.y = 0.0
            p.charge_vel.x += 0.05
            if p.charge_vel.x > 0.0:
              p.charge_vel.x = 0.0
          # charge_vel z friction (y, beacuse it's a vector2)
          if p.charge_vel.y > 0.0: 
            p.vel.y = 0.0
            p.charge_vel.y -= 0.05
            if p.charge_vel.y < 0.0:
              p.charge_vel.y = 0.0
          elif p.charge_vel.y < 0.0: 
            p.vel.y = 0.0
            p.charge_vel.y += 0.05
            if p.charge_vel.y > 0.0:
              p.charge_vel.y = 0.0
          p.pos.y += p.vel.y
          for w in walls:
            if aabbcc(p.pos.x,p.pos.z,p.pos.y,p.size.x,p.size.z,p.size.y,w.pos.x,w.pos.z,w.pos.y,w.size.x,w.size.z,w.size.y):
              if p.pos.y > w.pos.y:
                p.pos.y = w.pos.y+w.size.y/2.0+p.size.y/2.0
                p.grounded = true
              else:
                p.pos.y = w.pos.y-w.size.y/2.0-p.size.y/2.0
              p.vel.y = 0.0
          for n in 0..collectibles.len-1:
            let c = collectibles[n]
            if aabbcc(p.pos.x,p.pos.z,p.pos.y,p.size.x,p.size.z,p.size.y,c.pos.x,c.pos.z,c.pos.y,c.size.x,c.size.z,c.size.y):
              collectibles.delete(n)
              case c.collectible_type:
              of carrot: carrotsHeld += 1
              of banana: p.bananized = true
              of dubloon: p.dubloons_held += 1
              break
          if p.pos.y < p.size.y/2.0: 
            p.pos.y = p.size.y/2.0
            p.vel.y = 0.0
            p.grounded = true
          if p.pos.y > wallSize-p.size.y/2.0:
            p.pos.y = wallSize-p.size.y/2.0
            p.vel.y = 0.0
          p.hp = p.hp.clamp(0.0,playerMaxHp)
        if elevatorPlayers==1:
          advance = true
          if stage+1 > 2:
            transition(thxForPlaying,30,30)
          else:
            startingCarrots = carrotsHeld
            transition(gameplay,30,30)
          
        if isKeyPressed(Enter): currentScreen = pause
        if isKeyPressed(R): transition(gameplay,30,30)

      # ENEMY

      var deletion_queue: seq[int] = @[]
      var deleted = 0

      for i,e in enemies.mpairs:
        if e.vel.y > -2.0: e.vel.y -= 0.04
        let angleToPlayer = arctan2(players[0].pos.z-e.pos.z,players[0].pos.x-e.pos.x)
        var velMod = 0.4
        case e.enemyType:
        of possum: velMod = 0.6
        of jeopard: velMod = 0.5
        of crow: velMod = 0.4 
        e.vel.x = velMod*angleToPlayer.cos()
        e.vel.z = velMod*angleToPlayer.sin()
        e.pos.x += e.vel.x
        let rowFloat = row.float
        if level[(floor((e.pos.z-e.size.z/2.0+wallSize/2.0)/wallSize)*rowFloat+floor((e.pos.x.float-e.size.x/2.0+wallSize/2.0)/wallSize)).int] == '#' or level[(floor((e.pos.z.float+e.size.z/2.0+wallSize/2.0)/wallSize)*rowFloat+floor((e.pos.x.float-e.size.x/2.0+wallSize/2.0)/wallSize)).int] == '#':
          e.pos.x = (floor((e.pos.x.float-e.size.x/2.0+wallSize/2.0)/wallSize))*wallSize+wallSize/2.0+e.size.x/2.0
          e.vel.x = 0.0
        elif level[(floor((e.pos.z+e.size.z/2.0+wallSize/2.0)/wallSize)*rowFloat+floor((e.pos.x.float+e.size.x/2.0+wallSize/2.0)/wallSize)).int] == '#' or level[(floor((e.pos.z.float-e.size.z/2.0+wallSize/2.0)/wallSize)*rowFloat+floor((e.pos.x.float+e.size.x/2.0+wallSize/2.0)/wallSize)).int] == '#':
          e.pos.x = (floor((e.pos.x.float+e.size.x/2.0+wallSize/2.0)/wallSize))*wallSize-wallSize/2.0-e.size.x/2.0-0.0001
          e.vel.x = 0.0
        for w in walls:
          if aabbcc(e.pos.x,e.pos.z,e.pos.y,e.size.x,e.size.z,e.size.y,w.pos.x,w.pos.z,w.pos.y,w.size.x,w.size.z,w.size.y):
            if e.pos.x > w.pos.x:
              e.pos.x = w.pos.x+w.size.x/2.0+e.size.x/2.0
            else:
              e.pos.x = w.pos.x-w.size.x/2.0-e.size.x/2.0
            e.vel.x = 0.0
        for e2 in enemies:
          if e2 != e and aabbcc(e.pos.x,e.pos.z,e.pos.y,e.size.x,e.size.z,e.size.y,e2.pos.x,e2.pos.z,e2.pos.y,e2.size.x,e2.size.z,e2.size.y):
            if e.pos.x > e2.pos.x:
              e.pos.x = e2.pos.x+e2.size.x/2.0+e.size.x/2.0
            else:
              e.pos.x = e2.pos.x-e2.size.x/2.0-e.size.x/2.0
            e.vel.x = 0.0
        e.pos.z += e.vel.z
        if level[(floor((e.pos.z-e.size.z/2.0+wallSize/2.0)/wallSize)*rowFloat+floor((e.pos.x.float-e.size.x/2.0+wallSize/2.0)/wallSize)).int] == '#' or level[(floor((e.pos.z.float-e.size.z/2.0+wallSize/2.0)/wallSize)*rowFloat+floor((e.pos.x.float+e.size.x/2.0+wallSize/2.0)/wallSize)).int] == '#':
          e.pos.z = (floor((e.pos.z.float-e.size.z/2.0+wallSize/2.0)/wallSize))*wallSize+wallSize/2.0+e.size.z/2.0
          e.vel.z = 0.0
        elif level[(floor((e.pos.z+e.size.z/2.0+wallSize/2.0)/wallSize)*rowFloat+floor((e.pos.x.float-e.size.x/2.0+wallSize/2.0)/wallSize)).int] == '#' or level[(floor((e.pos.z.float+e.size.z/2.0+wallSize/2.0)/wallSize)*rowFloat+floor((e.pos.x.float+e.size.x/2.0+wallSize/2.0)/wallSize)).int] == '#':
          e.pos.z = (floor((e.pos.z.float+e.size.z/2.0+wallSize/2.0)/wallSize))*wallSize-wallSize/2.0-e.size.z/2.0-0.0001
          e.vel.z = 0.0
        for w in walls:
          if aabbcc(e.pos.x,e.pos.z,e.pos.y,e.size.x,e.size.z,e.size.y,w.pos.x,w.pos.z,w.pos.y,w.size.x,w.size.z,w.size.y):
            if e.pos.z > w.pos.z:
              e.pos.z = w.pos.z+w.size.z/2.0+e.size.z/2.0
            else:
              e.pos.z = w.pos.z-w.size.z/2.0-e.size.z/2.0
            e.vel.z = 0.0
        for e2 in enemies:
          if e2 != e and aabbcc(e.pos.x,e.pos.z,e.pos.y,e.size.x,e.size.z,e.size.y,e2.pos.x,e2.pos.z,e2.pos.y,e2.size.x,e2.size.z,e2.size.y):
            if e.pos.z > e2.pos.z:
              e.pos.z = e2.pos.z+e2.size.z/2.0+e.size.z/2.0
            else:
              e.pos.z = e2.pos.z-e2.size.z/2.0-e.size.z/2.0
            e.vel.z = 0.0
        e.pos.y += e.vel.y
        for w in walls:
          if aabbcc(e.pos.x,e.pos.z,e.pos.y,e.size.x,e.size.z,e.size.y,w.pos.x,w.pos.z,w.pos.y,w.size.x,w.size.z,w.size.y):
            if e.pos.y > w.pos.y:
              e.pos.y = w.pos.y+w.size.y/2.0+e.size.y/2.0
              e.grounded = true
            else:
              e.pos.y = w.pos.y-w.size.y/2.0-e.size.y/2.0
              e.vel.y = 0.0
        if e.pos.y < e.size.y/2.0: 
          e.pos.y = e.size.y/2.0
          e.vel.y = 0.0
          e.grounded = true
        if e.pos.y > wallSize-e.size.y/2.0:
          e.pos.y = wallSize-e.size.y/2.0
          e.vel.y = 0.0
        if e.hp <= 0.0: deletion_queue.add(i)

      for d in deletion_queue:
        enemies.del(d-deleted)
        deleted+=1
      # camera controls

      camera.position = players[0].pos + Vector3(x:cameraZoom,y:cameraZoom,z:cameraZoom)
      camera.target = players[0].pos
    of pause:
      if isKeyPressed(Enter): currentScreen = gameplay
      if isKeyPressed(Backspace): transition(title,30,30)
      if isKeyPressed(R): transition(gameplay,30,30)
    of gameOver:
      if isKeyPressed(R): transition(gameplay,30,30)
      if isKeyPressed(Backspace): transition(title,30,30)
    of thxForPlaying:
      if isKeyPressed(Enter): transition(title,120,30)
    of charaSelect:
      if isKeyPressed(R): transition(gameplay,30,30)
    of title: 
      if isKeyPressed(Enter): 
        stage = 0
        transition(gameplay,30,30)
      if isKeyPressed(Backspace): transition(gameOver,30,30)

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
      camera.position = Vector3()
      case currentScreen:
        of gameplay:
          level = level_template
          carrotsHeld = startingCarrots
          collectibles = @[]
          enemies = @[]
          walls = @[]
          if advance: 
            stage += 1
            advance = false
          for y in stage*mapSize..stage*mapSize+mapSize-1:
            for x in 0..mapSize-1:
              let cell = level[y*(mapSize+2)+x].toUpperAscii()
              if cell == 'P':
                players[0] = Player(pos:Vector3(x: x.float*wallSize-2.0,y:1.5,z: y.float*wallSize-2.0),size:Vector3(x:2.0,y:3.0,z:2.0),vel:Vector3(),hp:playerMaxHp,att_cooldown:0)
                players[1] = Player(pos:Vector3(x: x.float*wallSize+2.0,y:1.5,z: y.float*wallSize-2.0),size:Vector3(x:2.0,y:3.0,z:2.0),vel:Vector3(),hp:playerMaxHp,att_cooldown:0)
                players[2] = Player(pos:Vector3(x: x.float*wallSize-2.0,y:1.5,z: y.float*wallSize+2.0),size:Vector3(x:2.0,y:3.0,z:2.0),vel:Vector3(),hp:playerMaxHp,att_cooldown:0)
                players[3] = Player(pos:Vector3(x: x.float*wallSize+2.0,y:1.5,z: y.float*wallSize+2.0),size:Vector3(x:2.0,y:3.0,z:2.0),vel:Vector3(),hp:playerMaxHp,att_cooldown:0)
                break
              elif level[y*(mapSize+2)+x] == 'w':
                walls.add(Wall(pos:Vector3(x: x.float*wallSize,y:wallSize/4.0,z: y.float*wallSize),size:Vector3(x:wallSize,y:wallSize/2.0,z:2.0)))
              elif cell == 'C':
                collectibles.add(Collectible(pos:Vector3(x: x.float*wallSize,y:2.0,z: y.float*wallSize),size:Vector3(x:2.0,y:2.0,z:2.0),collectible_type:carrot))
              elif cell == 'B':
                collectibles.add(Collectible(pos:Vector3(x: x.float*wallSize,y:2.0,z: y.float*wallSize),size:Vector3(x:2.0,y:2.0,z:2.0),collectible_type:banana))
              elif cell == 'D':
                collectibles.add(Collectible(pos:Vector3(x: x.float*wallSize,y:2.0,z: y.float*wallSize),size:Vector3(x:1.0,y:2.0,z:2.0),collectible_type:dubloon))
              elif cell == 'J':
                enemies.add(Enemy(pos:Vector3(x: x.float*wallSize,y:2.5,z: y.float*wallSize),size:Vector3(x:7.0,y:5.0,z:5.0),enemyType:jeopard,hp:50.0))
              elif cell == 'K':
                enemies.add(Enemy(pos:Vector3(x: x.float*wallSize,y:0.75,z: y.float*wallSize),size:Vector3(x:1.5,y:1.5,z:1.5),enemyType:crow,hp:10.0))
              elif cell == 'O':
                enemies.add(Enemy(pos:Vector3(x: x.float*wallSize,y:0.75,z: y.float*wallSize),size:Vector3(x:3.0,y:1.5,z:1.5),enemyType:possum,hp:20.0))
              if cell != 'W' and level[y*(mapSize+2)+x].isLowerAscii():
                level[y*(mapSize+2)+x] = '/'
        of title:
          advance = false
          stage = 0
          carrotsHeld = 0
          startingCarrots = 0
        else: camera.position = Vector3()
  # --------------------------------------------------------------------------------------
  # Draw
  # --------------------------------------------------------------------------------------
  beginDrawing()
  clearBackground(Color(r:8,g:8,b:16,a:255))
  if currentScreen == title: drawText("Welcome! Press Enter to begin!", 20, screenHeight-60, 40, White)
  elif currentScreen == gameOver: drawText("You were defeated! Press R to restart.", 20, screenHeight-60, 40, Red)
  elif currentScreen == thxForPlaying: drawText("Thank you for playing!\n\n\nPress Enter to return to the title screen.", 20, screenHeight-100, 40, White)
  # don't want to repeat the same code for rendering gameplay in pause screen
  elif currentScreen == gameplay or currentScreen == pause: 

    # GAMEPLAY

    beginMode3D(camera)
    for i,p in players.pairs:
      drawCube(p.pos,p.size,Green)
      let groundpos = 0.0 # shadow's y (ground height)
      let radius = sqrt(p.size.x/2.0*p.size.x/2.0+p.size.z/2.0*p.size.z/2.0)+0.5
      drawCylinder(Vector3(x:p.pos.x,y:0.1,z:p.pos.z),radius-(p.pos.y-groundpos)/10.0,radius-(p.pos.y-groundpos)/10.0,0.0,20,Black)
    for w in walls:
      drawCubeTextureRec(level_tex, Rectangle(x:0,y:8,width:16,height:8),w.pos,w.size.x,w.size.y,w.size.z,(true,true,true,true,true,true),White)
    for c in collectibles:
      let mapIndex = level[floor((c.pos.z.float+wallSize/2.0)/wallSize).int*row+floor((c.pos.x.float+wallSize/2.0)/wallSize).int] # on which index of the map is the collectible placed on?
      if not (mapIndex == '/'):
        case c.collectible_type:
        of carrot: drawCube(c.pos,c.size,Orange)
        of banana: drawCube(c.pos,c.size,Yellow)
        of dubloon: drawCube(c.pos,c.size,Gold)
        let groundpos = 0.0 # shadow's y (ground height)
        let radius = sqrt(c.size.x/2.0*c.size.x/2.0+c.size.z/2.0*c.size.z/2.0)+0.5
        drawCylinder(Vector3(x:c.pos.x,y:0.1,z:c.pos.z),radius-(c.pos.y-groundpos)/10.0,radius-(c.pos.y-groundpos)/10.0,0.0,20,Black)
    for e in enemies:
      let mapIndex = level[floor((e.pos.z.float+wallSize/2.0)/wallSize).int*row+floor((e.pos.x.float+wallSize/2.0)/wallSize).int] # on which index of the map is the collectible placed on?
      if not (mapIndex == '/'):
        case e.enemyType:
        of crow: drawCube(e.pos,e.size,Black)
        of jeopard: drawCube(e.pos,e.size,Gold)
        of possum: drawCube(e.pos,e.size,Gray)
        let groundpos = 0.0 # shadow's y (ground height)
        let radius = sqrt(e.size.x/2.0*e.size.x/2.0+e.size.z/2.0*e.size.z/2.0)+0.5
        drawCylinder(Vector3(x:e.pos.x,y:0.1,z:e.pos.z),radius-(e.pos.y-groundpos)/10.0,radius-(e.pos.y-groundpos)/10.0,0.0,20,Black)
    for y in stage*mapSize..stage*mapSize+mapSize-1:
      for x in 0..mapSize-1:
        if not (level[y*row+x] == '/'):
          if level[y*row+x] == '#':
            if x != 19 and y != stage*mapSize+19:
              let front = not (level[y*row+x+row] == '#' or level[y*row+x+row] == '/')
              let right = not (level[y*row+x+1] == '#' or level[y*row+x+1] == '/')
              drawCubeTextureRec(level_tex, Rectangle(x:0,y:0,width:16,height:16),Vector3(x:x.float*wallSize,y:wallSize/2.0,z:y.float*wallSize),wallSize,wallSize,wallSize,(front,false,false,false,right,false),White)
          elif level[y*row+x] == 'E':
            drawCubeTextureRec(level_tex, Rectangle(x:0,y:16,width:16,height:16),Vector3(x:x.float*wallSize,y: -8.0,z:y.float*wallSize),wallSize,wallSize,wallSize,(false,false,true,false,false,false),Brown)
            drawCubeTextureRec(level_tex, Rectangle(x:96,y:0,width:32,height:32),Vector3(x:x.float*wallSize,y: wallSize/2.0,z:y.float*wallSize),wallSize,wallSize,wallSize,(true,true,false,false,true,true),White)
          else: 
            drawCubeTextureRec(level_tex, Rectangle(x:0,y:0,width:16,height:16),Vector3(x:x.float*wallSize,y: -8.0,z:y.float*wallSize),wallSize,wallSize,wallSize,(false,false,true,false,false,false),LightGray)
        elif not ((level[y*row+x+row] == '#' or level[y*row+x+row] == '/') and (level[y*row+x-row] == '#' or level[y*row+x-row] == '/') and (level[y*row+x+1] == '#' or level[y*row+x+1] == '/') and (level[y*row+x-1] == '#' or level[y*row+x-1] == '/')):
          drawCubeTextureRec(level_tex, Rectangle(x:0,y:0,width:16,height:16),Vector3(x:x.float*wallSize,y: -8.0,z:y.float*wallSize),wallSize,wallSize,wallSize,(false,false,true,false,false,false),Color(r:255,g:255,b:255,a:4))
    endMode3D()

    # color filter

    #drawRectangle(0,0,screenWidth,screenHeight,Color(r:255,g:64,b:0,a:16))

    # UI

    drawRectangle(Vector2(),Vector2(x:240.0,y:40.0),Gray)
    drawRectangle(Vector2(),Vector2(x:240.0*(players[0].hp/playerMaxHp),y:40.0),Green)
    drawText("HP",10,10,20,Black)
    drawRectangle(Vector2(y:40),Vector2(x:200.0,y:10.0),Gray)
    let cooldown = players[0].charge_cooldown
    drawRectangle(Vector2(y:40),Vector2(x:200.0*(300-cooldown).float/300.0,y:10.0),SkyBlue)
    if carrotsHeld > 0: drawText(("Carrots: " & $carrotsHeld).cstring,260,10,20,Orange)
  # pause screen
  if currentScreen == pause:
    drawRectangle(0,0,screenWidth,screenHeight,Color(r:0,g:0,b:0,a:96))
    drawText("PAUSED.\nPress Backspace to return to the title screen.\nPress Enter to get back into gameplay.\nPress R to restart.",10,10,20,White)
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