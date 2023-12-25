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

import raylib, raymath, std/math, rlgl, std/strutils

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
  CollectibleType = enum
    carrot # C
    banana # B
    dubloon # M
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
    att_cooldown: float
    falling: bool
    delta: Vector3
  Solid = object of Thing
  Enemy = object of Actor
    enemyType: EnemyType
    max_hp: float
  Player = object of Actor # P
    charge_vel: Vector2 # when you attack, you charge. This is the velocity exerted on the player
    charge_cooldown: float
    bananized: bool
    dubloons_held: int
    alive: bool
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
var fadeTimer = 0.0
var fadeOut = false
var fadeInLen = 0
var fadeOutLen = 0
var transitioning = false
var inElevator = false
var stage = 0
var dubloonGoal = 0
var dubloonsHeld = 0
let mapSize = 20 # the map is always square
let row = mapSize+2 # how many characters till next row in the map? (\n also counts)
var carrotsHeld = 0 # carrots are shared
var startingCarrots = 0 # how many carrots were held when the stage ended?
var advance = false # switch to next stage?
var playersInGame = 1 # how many players in-game?
var joinedPlayers = (false,false,false,false)
var damagedAlready: seq[int]

var players: array[4,Player]
var walls: seq[Wall] = @[]
var collectibles: seq[Collectible] = @[]
var enemies: seq[Enemy] = @[]
#var level: Model

let level_template = readFile("resources/lvl.txt")
var level = level_template
var level_tex: Texture2D
var floor: Model
var bonnie: Model
var bonnie_bb = Vector3()
var possumModel: Model
var crowModel: Model
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
    fadeTimer = lengthIn.float
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

proc bresenhamLine(x0, y0, x1, y1: int): seq[tuple[x, y: int]] =
  var dx = abs(x1 - x0)
  var dy = abs(y1 - y0)
  var sx = if x0 < x1: 1 else: -1
  var sy = if y0 < y1: 1 else: -1
  var err = dx - dy
  var x = x0
  var y = y0
  var points: seq[tuple[x, y: int]] = @[]

  while true:
    points.add((x: x, y: y))
    if x == x1 and y == y1: break
    let e2 = 2 * err
    if e2 > -dy:
      err -= dy
      x += sx
    if e2 < dx:
      err += dx
      y += sy

  points.del(0) # ensure that the tile on which the start point is isn't included
  return points

proc lineOfSight(player, enemy: (int,int), grid: string, e: Enemy): bool =
  let points = bresenhamLine(player[0], player[1], enemy[0], enemy[1])
  for point in points:
    if grid[point.y*row+point.x] == '#' or grid[point.y*22+point.x] == '/' or grid[point.y*22+point.x] == 'w' or grid[point.y*22+point.x] == 'W':
      #echo "colliding with " & $point
      return false
  return true

proc recenter(model: var Model) = 
  let bb: BoundingBox = model.getModelBoundingBox()
  var center = Vector3()
  center.x = bb.min.x  + (((bb.max.x - bb.min.x)/2))
  center.z = bb.min.z  + (((bb.max.z - bb.min.z)/2))

  let matTranslate = translate(-center.x,0.0,-center.z)
  model.transform = matTranslate

# ----------------------------------------------------------------------------------------
# Module functions Definition
# ----------------------------------------------------------------------------------------

proc updateDrawFrame {.cdecl.} =
  # Update
  # --------------------------------------------------------------------------------------
  let dt = getFrameTime()*60.0
  # Game logic
  case currentScreen:
    of gameplay:
      if not transitioning:

        # PLAYER

        var elevatorPlayers = 0
        
        # i is the player id

        for i,p in players.mpairs:
          var velMod = 1.0
          let oldpos = p.pos
          if p.bananized: velMod = 1.2
          if p.charge_cooldown > 0: 
            p.charge_cooldown -= 1*dt
          if p.att_cooldown > 0: 
            p.att_cooldown -= 1*dt
          if p.vel.y > -2.0: p.vel.y -= 0.04*dt
          if i == 0 and p.alive:
            if p.charge_vel.x == 0.0 and p.charge_vel.y == 0.0:
              if isKeyDown(D) or isKeyDown(Right):
                if p.vel.x < 0.5*velMod: p.vel.x += 0.075*velMod*dt
              elif isKeyDown(A) or isKeyDown(Left):
                if p.vel.x > -0.5*velMod: p.vel.x -= 0.075*velMod*dt
              else:
                if p.vel.x > 0.0: 
                  p.vel.x -= 0.05*velMod*dt
                  if p.vel.x < 0.0:
                    p.vel.x = 0.0
                elif p.vel.x < 0.0: 
                  p.vel.x += 0.05*velMod*dt
                  if p.vel.x > 0.0:
                    p.vel.x = 0.0
              if isKeyDown(S) or isKeyDown(Down):
                if p.vel.z < 0.5*velMod: p.vel.z += 0.075*velMod*dt
              elif isKeyDown(W) or isKeyDown(Up):
                if p.vel.z > -0.5*velMod: p.vel.z -= 0.075*velMod*dt
              else:
                if p.vel.z > 0.0: 
                  p.vel.z -= 0.05*velMod*dt
                  if p.vel.z < 0.0:
                    p.vel.z = 0.0
                elif p.vel.z < 0.0: 
                  p.vel.z += 0.05*velMod*dt
                  if p.vel.z > 0.0:
                    p.vel.z = 0.0
            if (isKeyPressed(Space) or isKeyPressed(C)) and p.grounded: p.vel.y = 1.0
            if (isMouseButtonPressed(MouseButton.Right) or isKeyPressed(X) or isKeyPressed(O)) and p.charge_cooldown <= 0 and (p.vel.x != 0.0 or p.vel.z != 0.0): 
              p.charge_cooldown = 300
              p.vel.y = 0.0
              p.charge_vel = Vector2(x:1.0*p.vel.x.sgn().float,y:1.0*p.vel.z.sgn().float)
              damagedAlready = @[]
            if (isMouseButtonPressed(MouseButton.Left) or isKeyPressed(Z) or isKeyPressed(P)) and p.att_cooldown <= 0 and p.charge_vel == Vector2(): 
              p.att_cooldown = 50
              let radius = sqrt(2.0)+6.0
              for e in enemies.mitems:
                if checkCollisionCircleRec(Vector2(x:p.pos.x,y:p.pos.z),radius.float32,Rectangle(x:e.pos.x,y:e.pos.z,width:e.size.x,height:e.size.z)) and e.pos.y + e.size.y/2.0 > p.pos.y-p.size.y/2.0 and e.pos.y - e.size.y/2.0 < p.pos.y + p.size.y/2.0:
                  e.hp -= 10.0
                  e.vel = Vector3()
                  if e.enemyType == jeopard: e.att_cooldown += 10
            if (isKeyPressed(KeyboardKey.E) or isKeyPressed(F)) and carrotsHeld > 0 and p.hp < playerMaxHp:
              carrotsHeld -= 1
              p.hp += 15.0
          p.grounded = false
          if p.falling:
            p.vel = Vector3()
            p.vel.y = -0.1
          p.pos.x += (p.vel.x+p.charge_vel.x)*dt
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
          p.pos.z += (p.vel.z+p.charge_vel.y)*dt
          if level[(floor((p.pos.z-p.size.z/2.0+wallSize/2.0)/wallSize)*rowFloat+floor((p.pos.x.float-p.size.x/2.0+wallSize/2.0)/wallSize)).int] == '#' or level[(floor((p.pos.z.float-p.size.z/2.0+wallSize/2.0)/wallSize)*rowFloat+floor((p.pos.x.float+p.size.x/2.0+wallSize/2.0)/wallSize)).int] == '#':
            p.pos.z = (floor((p.pos.z.float-p.size.z/2.0+wallSize/2.0)/wallSize))*wallSize+wallSize/2.0+p.size.z/2.0
            p.vel.z = 0.0
          elif level[(floor((p.pos.z+p.size.z/2.0+wallSize/2.0)/wallSize)*rowFloat+floor((p.pos.x.float-p.size.x/2.0+wallSize/2.0)/wallSize)).int] == '#' or level[(floor((p.pos.z.float+p.size.z/2.0+wallSize/2.0)/wallSize)*rowFloat+floor((p.pos.x.float+p.size.x/2.0+wallSize/2.0)/wallSize)).int] == '#':
            p.pos.z = (floor((p.pos.z.float+p.size.z/2.0+wallSize/2.0)/wallSize))*wallSize-wallSize/2.0-p.size.z/2.0-0.0001
            p.vel.z = 0.0
          if level[(floor((p.pos.z-p.size.z/2.0+wallSize/2.0)/wallSize)*rowFloat+floor((p.pos.x.float-p.size.x/2.0+wallSize/2.0)/wallSize)).int] == 'E' and 
          level[(floor((p.pos.z.float-p.size.z/2.0+wallSize/2.0)/wallSize)*rowFloat+floor((p.pos.x.float+p.size.x/2.0+wallSize/2.0)/wallSize)).int] == 'E' and 
          level[(floor((p.pos.z+p.size.z/2.0+wallSize/2.0)/wallSize)*rowFloat+floor((p.pos.x.float-p.size.x/2.0+wallSize/2.0)/wallSize)).int] == 'E' and 
          level[(floor((p.pos.z.float+p.size.z/2.0+wallSize/2.0)/wallSize)*rowFloat+floor((p.pos.x.float+p.size.x/2.0+wallSize/2.0)/wallSize)).int] == 'E' and
          dubloonsHeld >= dubloonGoal:
            elevatorPlayers+=1
            #echo stage
          if level[(floor((p.pos.z+wallSize/2.0)/wallSize)*rowFloat+floor((p.pos.x.float+wallSize/2.0)/wallSize)).int] == '/':
              let cell = (floor((p.pos.z+wallSize/2.0)/wallSize)*rowFloat+floor((p.pos.x.float+wallSize/2.0)/wallSize)).int
              level[cell] = level_template[cell].toUpperAscii()
              if level_template[cell] == '/': level[cell] = ' '
          for w in walls:
            if aabbcc(p.pos.x,p.pos.z,p.pos.y,p.size.x,p.size.z,p.size.y,w.pos.x,w.pos.z,w.pos.y,w.size.x,w.size.z,w.size.y):
              if p.pos.z > w.pos.z:
                p.pos.z = w.pos.z+w.size.z/2.0+p.size.z/2.0
              else:
                p.pos.z = w.pos.z-w.size.z/2.0-p.size.z/2.0
              p.vel.z = 0.0

          # charge_vel x friction
          if p.charge_vel.x > 0.0: 
            for n,e in enemies.mpairs:
              if aabbcc(p.pos.x,p.pos.z,p.pos.y,p.size.x,p.size.z,p.size.y,e.pos.x,e.pos.z,e.pos.y,e.size.x,e.size.z,e.size.y) and not damagedAlready.contains(n):
                e.hp -= 15.0
                damagedAlready.add(n)
            p.vel.y = 0.0
            p.charge_vel.x -= 0.05*dt
            if p.charge_vel.x < 0.0:
              p.charge_vel.x = 0.0
          elif p.charge_vel.x < 0.0: 
            for n,e in enemies.mpairs:
              if aabbcc(p.pos.x,p.pos.z,p.pos.y,p.size.x,p.size.z,p.size.y,e.pos.x,e.pos.z,e.pos.y,e.size.x,e.size.z,e.size.y) and not damagedAlready.contains(n):
                e.hp -= 15.0
                damagedAlready.add(n)
            p.vel.y = 0.0
            p.charge_vel.x += 0.05*dt
            if p.charge_vel.x > 0.0:
              p.charge_vel.x = 0.0
          # charge_vel z friction (y, beacuse it's a vector2)
          if p.charge_vel.y > 0.0: 
            for n,e in enemies.mpairs:
              if aabbcc(p.pos.x,p.pos.z,p.pos.y,p.size.x,p.size.z,p.size.y,e.pos.x,e.pos.z,e.pos.y,e.size.x,e.size.z,e.size.y) and not damagedAlready.contains(n):
                e.hp -= 15.0
                damagedAlready.add(n)
            p.vel.y = 0.0
            p.charge_vel.y -= 0.05*dt
            if p.charge_vel.y < 0.0:
              p.charge_vel.y = 0.0
          elif p.charge_vel.y < 0.0: 
            for n,e in enemies.mpairs:
              if aabbcc(p.pos.x,p.pos.z,p.pos.y,p.size.x,p.size.z,p.size.y,e.pos.x,e.pos.z,e.pos.y,e.size.x,e.size.z,e.size.y) and not damagedAlready.contains(n):
                e.hp -= 15.0
                damagedAlready.add(n)
            p.vel.y = 0.0
            p.charge_vel.y += 0.05*dt
            if p.charge_vel.y > 0.0:
              p.charge_vel.y = 0.0
          p.pos.y += p.vel.y*dt
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
          if level[(floor((p.pos.z-p.size.z/2.0+wallSize/2.0)/wallSize)*rowFloat+floor((p.pos.x.float-p.size.x/2.0+wallSize/2.0)/wallSize)).int] == 'S' and level[(floor((p.pos.z.float-p.size.z/2.0+wallSize/2.0)/wallSize)*rowFloat+floor((p.pos.x.float+p.size.x/2.0+wallSize/2.0)/wallSize)).int] == 'S' and level[(floor((p.pos.z+p.size.z/2.0+wallSize/2.0)/wallSize)*rowFloat+floor((p.pos.x.float-p.size.x/2.0+wallSize/2.0)/wallSize)).int] == 'S' and level[(floor((p.pos.z.float+p.size.z/2.0+wallSize/2.0)/wallSize)*rowFloat+floor((p.pos.x.float+p.size.x/2.0+wallSize/2.0)/wallSize)).int] == 'S' and p.pos.y-p.size.y/2.0<0.0:
            p.falling = true
          if not p.falling:
            if p.pos.y < p.size.y/2.0: 
              p.pos.y = p.size.y/2.0
              p.vel.y = 0.0
              p.grounded = true
            if p.pos.y > wallSize-p.size.y/2.0:
              p.pos.y = wallSize-p.size.y/2.0
              p.vel.y = 0.0
          if p.pos.y+p.size.y/2.0 < 0.0: p.hp = 0.0
          p.hp = p.hp.clamp(0.0,playerMaxHp)
          if p.pos-oldpos != Vector3(): p.delta = (p.pos-oldpos)*dt
        if elevatorPlayers==1:
          advance = true
          if stage+1 > 2:
            transition(thxForPlaying,30,30)
          else:
            startingCarrots = carrotsHeld
            transition(gameplay,30,30)
        if players[0].hp <= 0.0:
          transition(gameOver,60,30)
          
        if isKeyPressed(Enter): currentScreen = pause
        if isKeyPressed(R): transition(gameplay,30,30)

      # ENEMY

      var deletion_queue: seq[int] = @[]
      var deleted = 0

      for i,e in enemies.mpairs:
        let oldpos = e.pos
        if e.att_cooldown > 0: e.att_cooldown -= 1*dt
        if e.vel.y > -2.0 and e.enemyType != crow: e.vel.y -= 0.04*dt
        var velMod = 0.4
        case e.enemyType:
        of possum: velMod = 0.6
        of jeopard: velMod = 0.5
        of crow: velMod = 0.4 
        var closest = 0
        for n,p in players.pairs:
          if distance(e.pos,p.pos) < distance(e.pos,players[closest].pos) and p.alive:
            closest = n
        closest = 0
        let p = players[closest]
        if distance(e.pos,p.pos) < hypot(e.size.x/2.0,e.size.z/2.0)+hypot(p.size.x/2.0,p.size.z/2.0)+max(e.size.x,e.size.z)/2.0 and e.att_cooldown <= 0:
          if players[closest].charge_vel == Vector2():
            case e.enemyType:
            of possum: 
              players[closest].hp -= 10.0
              e.att_cooldown = 90
            of jeopard: 
              players[closest].hp -= 40.0
              e.att_cooldown = 120
            of crow: 
              players[closest].hp -= 10.0
              e.att_cooldown = 60
        e.vel.x = 0.0
        e.vel.z = 0.0
        if lineOfSight((floor((e.pos.x+wallSize/2.0)/wallSize).int,floor((e.pos.z+wallSize/2.0)/wallSize).int),(floor((p.pos.x+wallSize/2.0)/wallSize).int,floor((p.pos.z+wallSize/2.0)/wallSize).int),level,e):
          let angleToPlayer = arctan2(p.pos.z-e.pos.z,p.pos.x-e.pos.x)
          e.vel.x = velMod*angleToPlayer.cos()
          e.vel.z = velMod*angleToPlayer.sin()
          #echo e.vel
        if e.att_cooldown > 0:
          e.vel.x = 0.0
          e.vel.z = 0.0
        e.pos.x += e.vel.x*dt
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
        e.pos.z += e.vel.z*dt
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
        e.pos.y += e.vel.y*dt
        for w in walls:
          if aabbcc(e.pos.x,e.pos.z,e.pos.y,e.size.x,e.size.z,e.size.y,w.pos.x,w.pos.z,w.pos.y,w.size.x,w.size.z,w.size.y):
            if e.pos.y > w.pos.y:
              e.pos.y = w.pos.y+w.size.y/2.0+e.size.y/2.0
              e.grounded = true
            else:
              e.pos.y = w.pos.y-w.size.y/2.0-e.size.y/2.0
              e.vel.y = 0.0
        if level[(floor((e.pos.z-e.size.z/2.0+wallSize/2.0)/wallSize)*rowFloat+floor((e.pos.x.float-e.size.x/2.0+wallSize/2.0)/wallSize)).int] == 'S' and level[(floor((e.pos.z.float-e.size.z/2.0+wallSize/2.0)/wallSize)*rowFloat+floor((e.pos.x.float+e.size.x/2.0+wallSize/2.0)/wallSize)).int] == 'S' and level[(floor((e.pos.z+e.size.z/2.0+wallSize/2.0)/wallSize)*rowFloat+floor((e.pos.x.float-e.size.x/2.0+wallSize/2.0)/wallSize)).int] == 'S' and level[(floor((e.pos.z.float+e.size.z/2.0+wallSize/2.0)/wallSize)*rowFloat+floor((e.pos.x.float+e.size.x/2.0+wallSize/2.0)/wallSize)).int] == 'S' and e.pos.y-p.size.y/2.0<0.0:
          e.falling = true
        if e.pos.y < e.size.y/2.0 and not e.falling: 
          e.pos.y = e.size.y/2.0
          e.vel.y = 0.0
          e.grounded = true
        if e.pos.y < -wallSize*3.0: e.hp = 0.0
        if e.hp <= 0.0: deletion_queue.add(i)
        if e.pos-oldpos != Vector3(): e.delta = e.pos-oldpos

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
    fadeTimer -= 1*dt
    echo fadeTimer
    
    if fadeTimer < 0.0: fadeTimer = 0.0
    fadeAlpha = 255.0*((fadeInLen.float-fadeTimer)/fadeInLen.float)
    echo fadeAlpha
    if fadeOut: 
      fadeAlpha = 255.0*((fadeTimer-fadeOutLen.float)/fadeOutLen.float)
      if fadeTimer <= 0: 
        transitioning = false
    elif fadeTimer <= 0: 
      # switch to next screen, start fading out
      fadeOut = true
      fadeTimer=fadeOutLen.float
      currentScreen = nextScreen
      camera.position = Vector3()
      case currentScreen:
        of gameplay:
          level = level_template
          carrotsHeld = startingCarrots
          collectibles = @[]
          enemies = @[]
          walls = @[]
          dubloonGoal = 0    
          if advance: 
            stage += 1
            advance = false
          if stage == 2: dubloonGoal = 9
          for y in stage*mapSize..stage*mapSize+mapSize-1:
            for x in 0..mapSize:
              if y*(mapSize+2)+x >= level_template.len: break
              let cell = level[y*(mapSize+2)+x].toUpperAscii()
              if cell == 'P':
                players[0] = Player(pos:Vector3(x: x.float*wallSize-2.0,y:1.5,z: y.float*wallSize-2.0),size:bonnie_bb,vel:Vector3(),hp:playerMaxHp,att_cooldown:0,alive:true)
                players[1] = Player(pos:Vector3(x: x.float*wallSize+2.0,y:1.5,z: y.float*wallSize-2.0),size:bonnie_bb,vel:Vector3(),hp:playerMaxHp,att_cooldown:0,alive:false)
                players[2] = Player(pos:Vector3(x: x.float*wallSize-2.0,y:1.5,z: y.float*wallSize+2.0),size:bonnie_bb,vel:Vector3(),hp:playerMaxHp,att_cooldown:0,alive:false)
                players[3] = Player(pos:Vector3(x: x.float*wallSize+2.0,y:1.5,z: y.float*wallSize+2.0),size:bonnie_bb,vel:Vector3(),hp:playerMaxHp,att_cooldown:0,alive:false)
              elif level[y*(mapSize+2)+x] == 'w':
                walls.add(Wall(pos:Vector3(x: x.float*wallSize,y:wallSize/4.0,z: y.float*wallSize),size:Vector3(x:wallSize,y:wallSize/2.0,z:2.0)))
              elif level[y*(mapSize+2)+x] == 'W':
                walls.add(Wall(pos:Vector3(x: x.float*wallSize,y:wallSize/4.0,z: y.float*wallSize),size:Vector3(x:2.0,y:wallSize/2.0,z:wallSize)))
              elif cell == 'C':
                collectibles.add(Collectible(pos:Vector3(x: x.float*wallSize,y:2.0,z: y.float*wallSize),size:Vector3(x:2.0,y:2.0,z:2.0),collectible_type:carrot))
              elif cell == 'B':
                collectibles.add(Collectible(pos:Vector3(x: x.float*wallSize,y:2.0,z: y.float*wallSize),size:Vector3(x:2.0,y:2.0,z:2.0),collectible_type:banana))
              elif cell == 'M':
                collectibles.add(Collectible(pos:Vector3(x: x.float*wallSize,y:2.0,z: y.float*wallSize),size:Vector3(x:1.0,y:2.0,z:2.0),collectible_type:dubloon))
              elif cell == 'J':
                enemies.add(Enemy(pos:Vector3(x: x.float*wallSize,y:2.5,z: y.float*wallSize),size:Vector3(x:7.0,y:5.0,z:5.0),enemyType:jeopard,hp:40.0,max_hp:40.0))
              elif cell == 'K':
                enemies.add(Enemy(pos:Vector3(x: x.float*wallSize,y:wallSize-1.25,z: y.float*wallSize),size:Vector3(x:1.5,y:1.5,z:1.5),enemyType:crow,hp:10.0,max_hp:10.0))
                enemies.add(Enemy(pos:Vector3(x: x.float*wallSize,y:wallSize-1.25,z: y.float*wallSize),size:Vector3(x:1.5,y:1.5,z:1.5),enemyType:crow,hp:10.0,max_hp:10.0))
              elif cell == 'O':
                enemies.add(Enemy(pos:Vector3(x: x.float*wallSize,y:0.75,z: y.float*wallSize),size:Vector3(x:3.0,y:1.5,z:1.5),enemyType:possum,hp:20.0,max_hp:20.0))
                enemies.add(Enemy(pos:Vector3(x: x.float*wallSize,y:0.75,z: y.float*wallSize),size:Vector3(x:3.0,y:1.5,z:1.5),enemyType:possum,hp:20.0,max_hp:20.0))
                enemies.add(Enemy(pos:Vector3(x: x.float*wallSize,y:0.75,z: y.float*wallSize),size:Vector3(x:3.0,y:1.5,z:1.5),enemyType:possum,hp:20.0,max_hp:20.0))
              if cell != 'W' and level[y*(mapSize+2)+x].isLowerAscii():
                level[y*(mapSize+2)+x] = '/'
        of title:
          advance = false
          stage = 0
          carrotsHeld = 0
          startingCarrots = 0
        else: camera.position = Vector3()

  dubloonsHeld = players[0].dubloons_held+players[1].dubloons_held+players[2].dubloons_held+players[3].dubloons_held
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
    # DRAW PLAYERS
    for i,p in players.pairs:
      let rot = -arctan2(p.delta.z,p.delta.x)*180/PI
      if p.alive:
        drawModel(bonnie,p.pos-Vector3(y: 2.0),Vector3(y:1.0),rot,Vector3(x:1.0,y:1.0,z:1.0),if p.falling: Orange else: White)
        #drawCube(p.pos,p.size,Green)
        let groundpos = 0.0 # shadow's y (ground height)
        let radius = sqrt(p.size.x/2.0*p.size.x/2.0+p.size.z/2.0*p.size.z/2.0)+0.5
        if not p.falling: drawCylinder(Vector3(x:p.pos.x,y:0.001,z:p.pos.z),radius-(p.pos.y-groundpos)/10.0,radius-(p.pos.y-groundpos)/10.0,0.0,20,Black)
        let radius2 = sqrt(2.0)+6.0
        if p.att_cooldown > 0: drawCylinder(Vector3(x:p.pos.x,y:p.pos.y,z:p.pos.z),radius2,radius2,2.0,20,Color(r:255,a:floor(160*(p.att_cooldown/50)).uint8))
    # DRAW SHORT WALLS
    for w in walls:
      drawCubeTextureRec(level_tex, Rectangle(x:0,y:8,width:16,height:8),w.pos,w.size.x,w.size.y,w.size.z,(true,true,true,true,true,true),White)
    # DRAW COLLECTIBLES
    for c in collectibles:
      let mapIndex = level[floor((c.pos.z.float+wallSize/2.0)/wallSize).int*row+floor((c.pos.x.float+wallSize/2.0)/wallSize).int] # on which index of the map is the collectible placed on?
      if not (mapIndex == '/'):
        case c.collectible_type:
        of carrot: drawCube(c.pos+Vector3(y: sin(getTime()*4.0))/4.0,c.size,Orange)
        of banana: drawCube(c.pos+Vector3(y: sin(getTime()*4.0))/4.0,c.size,Yellow)
        of dubloon: drawCube(c.pos+Vector3(y: sin(getTime()*4.0))/4.0,c.size,Gold)
        let groundpos = 0.0 # shadow's y (ground height)
        let radius = sqrt(c.size.x/2.0*c.size.x/2.0+c.size.z/2.0*c.size.z/2.0)+0.5
        drawCylinder(Vector3(x:c.pos.x,y:0.1,z:c.pos.z),radius-(c.pos.y-groundpos)/10.0,radius-(c.pos.y-groundpos)/10.0,0.0,20,Black)
    # DRAW ENEMIES
    for e in enemies:
      let rot = -arctan2(e.delta.z,e.delta.x)*180/PI
      let mapIndex = level[floor((e.pos.z.float+wallSize/2.0)/wallSize).int*row+floor((e.pos.x.float+wallSize/2.0)/wallSize).int] # on which index of the map is the enemy placed on?
      if not (mapIndex == '/'):
        case e.enemyType:
        of crow: drawModel(crowModel,e.pos-Vector3(y:e.size.y/4.0),Vector3(y:1.0),rot+180.0,Vector3(x:1.0,y:1.0,z:1.0),if e.falling: Orange else: White) 
        of jeopard: drawCube(e.pos,e.size,Gold)
        of possum:
          drawModel(possumModel,e.pos-Vector3(y:e.size.y/4.0),Vector3(y:1.0),rot,Vector3(x:1.0,y:1.0,z:1.0),if e.falling: Orange else: White) 
        #drawCubeWires(e.pos,e.size,Red)
        let groundpos = 0.0 # shadow's y (ground height)
        let radius = sqrt(e.size.x/2.0*e.size.x/2.0+e.size.z/2.0*e.size.z/2.0)+0.5
        if not e.falling: drawCylinder(Vector3(x:e.pos.x,y:0.1,z:e.pos.z),radius-(e.pos.y-groundpos)/10.0,radius-(e.pos.y-groundpos)/10.0,0.0,20,Black)
    # DRAW THE LEVEL ITSELF
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
          elif level[y*row+x] == 'S': 
            drawCubeTextureRec(level_tex, Rectangle(x:128,y:0,width:32,height:32),Vector3(x:x.float*wallSize,y: -8.0,z:y.float*wallSize),wallSize,wallSize,wallSize,(false,false,true,false,false,false),Gold)
          else:
            drawCubeTextureRec(level_tex, Rectangle(x:0,y:0,width:16,height:16),Vector3(x:x.float*wallSize,y: -8.0,z:y.float*wallSize),wallSize,wallSize,wallSize,(false,false,true,false,false,false),LightGray)
        elif not ((level[y*row+x+row] == '#' or level[y*row+x+row] == '/') and (level[y*row+x-row] == '#' or level[y*row+x-row] == '/') and (level[y*row+x+1] == '#' or level[y*row+x+1] == '/') and (level[y*row+x-1] == '#' or level[y*row+x-1] == '/')):
          drawCubeTextureRec(level_tex, Rectangle(x:0,y:0,width:16,height:16),Vector3(x:x.float*wallSize,y: -8.0,z:y.float*wallSize),wallSize,wallSize,wallSize,(false,false,true,false,false,false),Color(r:255,g:255,b:255,a:4))
    endMode3D()

    # UI

    for enemy in enemies:
      let cubeScreenPosition = getWorldToScreen(Vector3(x:enemy.pos.x,y:enemy.pos.y,z:enemy.pos.z), camera)
      if enemy.hp < enemy.max_hp: 
        drawRectangle(Vector2(x:cubeScreenPosition.x-enemy.size.x/1.5,y:cubeScreenPosition.y-8.0),Vector2(x:enemy.size.x*8.0,y: 8.0),Gray)
        drawRectangle(Vector2(x:cubeScreenPosition.x-enemy.size.x/1.5,y:cubeScreenPosition.y-8.0),Vector2(x:(enemy.hp/enemy.max_hp)*enemy.size.x*8.0,y: 8.0),Green)
    drawRectangle(Vector2(),Vector2(x:240.0,y:40.0),Gray)
    drawRectangle(Vector2(),Vector2(x:240.0*(players[0].hp/playerMaxHp),y:40.0),Green)
    drawText("HP",10,10,20,Black)
    drawRectangle(Vector2(y:40),Vector2(x:200.0,y:10.0),Gray)
    let cooldown = players[0].charge_cooldown
    drawRectangle(Vector2(y:40),Vector2(x:200.0*(300-cooldown).float/300.0,y:10.0),SkyBlue)
    if carrotsHeld > 0: drawText(("Carrots: " & $carrotsHeld).cstring,250,10,20,Orange)
    if dubloonGoal > 0: drawText(("Coins: " & $dubloonsHeld & "/" & $dubloonGoal).cstring,260+measureText(("Carrots: " & $carrotsHeld).cstring,20),10,20,if dubloonsHeld >= dubloonGoal: Green else: Gold)
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
  initWindow(screenWidth, screenHeight, "B-HOP UNDERGROUND")
  #level = loadModel(getAppDir() & "./dungeon_test.obj")
  level_tex = loadTexture("resources/dungeon_tileset2.png")
  level_tex.setTextureFilter(Point)
  bonnie = loadModel("resources/bonnie.vox")
  bonnie.recenter()
  possumModel = loadModel("resources/possum.vox")
  possumModel.recenter()
  crowModel = loadModel("resources/crow.vox")
  crowModel.recenter()
  bonnie_bb = (bonnie.getModelBoundingBox().max-bonnie.getModelBoundingBox().min)
  bonnie_bb = Vector3(x:bonnie_bb.x.abs(),y:bonnie_bb.y.abs(),z:bonnie_bb.z.abs())
  when defined(emscripten):
    emscriptenSetMainLoop(updateDrawFrame, 0, 1)
  else:
    #setTargetFPS(60) # Set our game to run at 60 frames-per-second
    # ------------------------------------------------------------------------------------
    # Main game loop
    while not windowShouldClose(): # Detect window close button or ESC key
      updateDrawFrame()
  # De-Initialization
  # --------------------------------------------------------------------------------------
  closeWindow() # Close window and OpenGL context
  # --------------------------------------------------------------------------------------

main()