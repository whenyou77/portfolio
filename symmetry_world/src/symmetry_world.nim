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

import raylib, nim_tiled, os, math, std/random, tables, strutils

# ----------------------------------------------------------------------------------------
# Global Variables Definition
# ----------------------------------------------------------------------------------------

type 
  EntityType = enum
    Player,
    Npc,
    King,
    Tribe,
    Boss
  Place = enum
    Mainland
    PlayerHouse
    Castle
    House1
    House2
    House3
    House4
    HouseL
    Badland
    BadCastle
    BossLair
  State = enum
    Gameplay
    Pause
    TitleScreen
  Entity = object
    x: float 
    y: float
    w: float
    h: float
    vx: float
    vy: float
    grounded: bool
    place: Place
    entity_type: EntityType
    quote: string

const
  screenWidth = 960
  screenHeight = 960
  water = {35,36,43,44,51,52,59,60,40,48}
  lava = {1,2,9,10,37,38,45,46}
  rot = {53,54,61,62}

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

proc main =
  # Initialization
  # --------------------------------------------------------------------------------------
  var entities: seq[Entity] = @[
    #Entity(x:2976.0,y:544.0,w:32.0,h:32.0,entity_type: Player,place: Mainland),
    #Entity(x:2944.0,y:544.0,w:32.0,h:32.0,entity_type: Player,place: Mainland),
    Entity(x:5728.0,y:576.0,w:32.0,h:32.0,entity_type: Player,place: Mainland),
    Entity(x:5824.0,y:576.0,w:32.0,h:32.0,entity_type: Npc,place: Mainland,vx:0,quote:"I am not suspicious at all (they really aren't); "),
    Entity(x:6816.0,y:576.0,w:32.0,h:32.0,entity_type: Npc,place: Mainland,vx:1,quote:"Walking in circles is muh passion;"),
    Entity(x:6912.0,y:512.0,w:32.0,h:32.0,entity_type: Npc,place: Mainland,vx:0),
    Entity(x:7648.0,y:576.0,w:32.0,h:32.0,entity_type: Npc,place: Mainland,vx:0),
    Entity(x:7776.0,y:608.0,w:32.0,h:32.0,entity_type: Npc,place: Mainland,vx:0),
    Entity(x:352.0,y:1952.0,w:32.0,h:32.0,entity_type: Npc,place: HouseL,vx:0,quote:"...;This is it;The end times are coming;It will spread;Spread forever;And we can't do anything about it;...;...........;Goo d b  y  e;   c   r  u   e   l\n      w      o   rl     d"),
    Entity(x:784.0,y:2156.0,w:32.0,h:64.0,entity_type: King,place: Castle,vx:1,quote:"I am the king;and you do what I say;(woop woop)"),
    Entity(x:3264.0,y:1152.0,w:32.0,h:32.0,entity_type: Npc,place: Mainland,vx:0,quote:"uuuuuhhhh;this area is off limits;please leave"),
  ]
  #[let map_entities = loadTiledMap(getAppDir()/"map.tmx").orDefault.layers[5].objects
  for entity in map_entities.items:
    case entity.class:
    of "player": entities.add(Entity(x:entity.x,y:entity.y,w:32.0,h:32.0,entity_type: Player,place: Mainland))
    of "npc": entities.add(Entity(x:entity.x,y:entity.y,w:32.0,h:64.0,entity_type: Npc,place: parseEnum[Place](entity.properties.getOrDefault("place").str),vx:entity.properties.getOrDefault("vx").number,vy:entity.properties.getOrDefault("vy").number,quote:entity.properties.getOrDefault("quote").str))
    #of "tribe": entities.add(Entity(x:entity.x,y:entity.y,w:32.0,h:32.0,entity_type: Tribe,place: parseEnum[Place](entity.properties.getOrDefault("place").str),vx:entity.properties.getOrDefault("vx").number,vy:entity.properties.getOrDefault("vy").number,quote:entity.properties.getOrDefault("quote").str))
    #of "boss": entities.add(Entity(x:entity.x,y:entity.y,w:32.0,h:32.0,entity_type: Npc,place: parseEnum[Place](entity.properties.getOrDefault("place").str),vx:entity.properties.getOrDefault("vx").number,vy:entity.properties.getOrDefault("vy").number,quote:entity.properties.getOrDefault("quote").str))
    else: entities.add(Entity(x:entity.x,y:entity.y,w:32.0,h:32.0,entity_type: Player,place: Mainland))]#
  var terrain = loadTiledMap(getAppDir()/"map.tmx").orDefault.layers[2]
  let obj = loadTiledMap(getAppDir()/"map.tmx").orDefault.layers[4].objects
  initWindow(screenWidth, screenHeight, "TILEWORLD")
  setTargetFPS(60) # Set our game to run at 60 frames-per-second
  let background2_img = loadImage(getAppDir()/"background2.png")
  let background2 = loadTextureFromImage(background2_img)
  let background_img = loadImage(getAppDir()/"background.png")
  let background = loadTextureFromImage(background_img)
  let terrain_img = loadImage(getAppDir()/"terrain.png")
  let terrain_tex = loadTextureFromImage(terrain_img)
  let foreground_img = loadImage(getAppDir()/"foreground.png")
  let foreground = loadTextureFromImage(foreground_img)
  let player_img = loadImage(getAppDir()/"player.png")
  let player = loadTextureFromImage(player_img)
  let king_img = loadImage(getAppDir()/"king.png")
  let king = loadTextureFromImage(king_img)
  var camera = Camera2D()
  let font = getFontDefault()
  camera.zoom = 1.0
  camera.rotation = 0.0
  camera.target = Vector2(x:0.0,y:0.0)
  var break_loop = false
  var raw_text: string = ""
  var shown_text: string = ""
  var state = Gameplay
  let quest = 0

  #var frame = 0
  # --------------------------------------------------------------------------------------
  randomize()
  # Main game loop
  while not windowShouldClose(): # Detect window close button or ESC key

    if break_loop: break

    # Update
    # ------------------------------------------------------------------------------------
    # TODO: Update your variables here
    # ------------------------------------------------------------------------------------
    # Draw
    # ------------------------------------------------------------------------------------

    
    if raw_text != "" and shown_text == "":
      for i in 0..raw_text.len-1:
        let c = $raw_text[i]
        if c == ";": break
        shown_text.add(c)
    for entity in entities.mitems:
      if entity.entity_type == Player:
        if raw_text == "":
          if isKeyPressed(KeyboardKey.E):
            for entity2 in entities:
              if entity2.entity_type==Player:continue
              if aabb(entity.x,entity.y,entity.w,entity.h,entity2.x,entity2.y,entity2.w,entity2.h): 
                raw_text = entity2.quote
          if isKeyPressed(S):
            for o in obj:
              if aabb(entity.x,entity.y,entity.w,entity.h,o.x,o.y,o.width,o.height):
                if o.properties.hasKey("place"):
                  entity.place = parseEnum[Place](o.properties.getOrDefault("place").str)
                  entity.x = o.properties.getOrDefault("x").number
                  entity.y = o.properties.getOrDefault("y").number
                  break
          if isKeyDown(D):
            entity.vx = 4
          elif isKeyDown(A):
            entity.vx = -4
          else: entity.vx = 0
          entity.vy += 0.5
          if entity.vy > 16.0: entity.vy = 16.0
          if (isKeyDown(Space) or isKeyDown(W)) and entity.grounded:
            entity.vy = -8.0
        else:
          if entity.vx != 0: entity.vx = 0 
          if isKeyPressed(KeyboardKey.E):
            raw_text.delete(0,shown_text.len)
            shown_text = ""
      else:
        entity.vy += 0.5
        if entity.vy > 16.0: entity.vy = 16.0

    echo raw_text
    echo shown_text

    for entity in entities.mitems:
      entity.grounded = false
      entity.x += entity.vx
      var topleft = terrain.tileAt(floor(entity.x/32.0).int, floor(entity.y/32.0).int)
      let topright = terrain.tileAt(floor((entity.x+entity.w)/32.0).int, floor(entity.y/32.0).int)
      let bottomleft = terrain.tileAt(floor(entity.x/32.0).int, floor((entity.y+entity.h-1)/32.0).int)
      let bottomright = terrain.tileAt(floor((entity.x+entity.w)/32.0).int, floor((entity.y+entity.h-1)/32.0).int)
      #var topright2 = terrain.tileAt(floor((entity.x+entity.w-1)/32.0).int, floor(entity.y/32.0).int)
      #var bottomleft2 = terrain.tileAt(floor(entity.x/32.0).int, floor((entity.y+entity.h-1)/32.0).int)
      #var bottomright2 = terrain.tileAt(floor((entity.x+entity.w-1)/32.0).int, floor((entity.y+entity.h-1)/32.0).int)
      #echo bottomleft
      #if topleft == 35 or topleft == 36 or topleft == 43 or topleft == 44 or bottomleft == 35 or bottomleft == 36 or bottomleft == 43 or bottomleft == 44 or topright == 35 or topright == 36 or topright == 43 or topright == 44 or bottomright == 35 or bottomright == 36 or bottomright == 43 or bottomright == 44:
        #entity.vy = entity.vy
      if not (topleft in {0}+water+lava+rot and bottomleft in {0}+water+lava+rot): 
        if entity.entity_type == Player: entity.vx = 0
        else: entity.vx *= -1
        entity.x -= entity.x-floor((entity.x-1)/32.0)*32.0-32.0
      if not (topright in {0}+water+lava+rot and bottomright in {0}+water+lava+rot): 
        if entity.entity_type == Player: entity.vx = 0
        else: entity.vx *= -1
        entity.x -= entity.x+entity.w-floor((entity.x+entity.w)/32.0)*32.0
      #[topleft = terrain.tileAt(floor(entity.x/32.0).int, floor(entity.y/32.0).int)
      topright2 = terrain.tileAt(floor((entity.x+entity.w-1)/32.0).int, floor(entity.y/32.0).int)
      bottomleft2 = terrain.tileAt(floor(entity.x/32.0).int, floor((entity.y+entity.h-1)/32.0).int)
      bottomright2 = terrain.tileAt(floor((entity.x+entity.w-1)/32.0).int, floor((entity.y+entity.h-1)/32.0).int)]#
      #[if topleft == 18 or topleft == 17 or topleft == 26 or topleft == 25 or topleft == 4 or topleft == 3 or topleft == 12 or topleft == 11: 
        entity.vx = 0
        entity.x -= entity.x-floor(entity.x/32.0)*32.0-32.0
      elif topright == 18 or topright == 17 or topright == 26 or topright == 25 or topright == 4 or topright == 3 or topright == 12 or topright == 11: 
        entity.vx = 0
        entity.x -= entity.x+entity.w-floor((entity.x+entity.w-1)/32.0)*32.0
      elif bottomleft == 18 or bottomleft == 17 or bottomleft == 26 or bottomleft == 25 or bottomleft == 4 or bottomleft == 3 or bottomleft == 12 or bottomleft == 11: 
        entity.vx = 0
        entity.x -= entity.x-floor(entity.x/32.0)*32.0-32.0
      elif bottomright == 18 or bottomright == 17 or bottomright == 26 or bottomright == 25 or bottomright == 4 or bottomright == 3 or bottomright == 12 or bottomright == 11: 
        entity.vx = 0
        entity.x -= entity.x+entity.w-floor((entity.x+entity.w-1)/32.0)*32.0]#
    for entity in entities.mitems:
      entity.y += entity.vy
      var topleft = terrain.tileAt(floor(entity.x/32.0).int, floor(entity.y/32.0).int)
      let topright = terrain.tileAt(floor((entity.x+entity.w-1)/32.0).int, floor(entity.y/32.0).int)
      let bottomleft = terrain.tileAt(floor(entity.x/32.0).int, floor((entity.y+entity.h)/32.0).int)
      let bottomright = terrain.tileAt(floor((entity.x+entity.w-1)/32.0).int, floor((entity.y+entity.h)/32.0).int)

      #[echo bottomleft, bottomright
      echo entity.y
      echo entity.vy]#
      #echo bottomleft
      if topleft in water or bottomleft in water or topright in water or bottomright in water:
        if entity.vy>2.0: entity.vy = 2.0
        entity.grounded = true
      if not (topleft in {0}+water+lava+rot and topright in {0}+water+lava+rot): 
        entity.vy = 0
        entity.y -= entity.y-floor(entity.y/32.0)*32.0-32.0
      if not (bottomleft in {0}+water+lava+rot and bottomright in {0}+water+lava+rot): 
        entity.vy = 0
        entity.y -= entity.y+entity.h-floor((entity.y+entity.h)/32.0)*32.0
        entity.grounded = true
      topleft = terrain.tileAt(floor(entity.x/32.0).int, floor(entity.y/32.0).int)
      let topright2 = terrain.tileAt(floor((entity.x+entity.w-1)/32.0).int, floor(entity.y/32.0).int)
      let bottomleft2 = terrain.tileAt(floor(entity.x/32.0).int, floor((entity.y+entity.h-1)/32.0).int)
      let bottomright2 = terrain.tileAt(floor((entity.x+entity.w-1)/32.0).int, floor((entity.y+entity.h-1)/32.0).int)
      if topleft in lava or bottomleft2 in lava or topright2 in lava or bottomright2 in lava or topleft in rot or bottomleft2 in rot or topright2 in rot or bottomright2 in rot: break_loop = true

    if entities[0].place == Mainland: camera.offset = Vector2(x: -entities[0].x.float+screenWidth.float/2.0-16.0,y: -entities[0].y.float+screenHeight.float/2.0-16.0)
    beginDrawing()
    case entities[0].place:
      of Mainland: clearBackground(Color(r:0,g:0,b:255,a:255))
      else: clearBackground(Black)
    beginMode2D(camera)
    var dest_rect = Rectangle()
    case entities[0].place:
      of Castle:
        dest_rect = Rectangle(x:640,y:1920,width:320,height:320)
      of House1:
        dest_rect = Rectangle(x:0,y:1920,width:128,height:192)
      of House2:
        dest_rect = Rectangle(x:128,y:1920,width:128,height:192)
      of House3:
        dest_rect = Rectangle(x:0,y:2112,width:128,height:192)
      of House4:
        dest_rect = Rectangle(x:128,y:2112,width:128,height:192)
      of HouseL:
        dest_rect = Rectangle(x:256,y:1920,width:192,height:192)
      of Mainland:
        dest_rect = Rectangle(x:0,y:0,width:8640,height:1920)
      of PlayerHouse:
        dest_rect = Rectangle(x:448,y:1920,width:192,height:320)
      else:
        drawTexture(background2,Vector2(x:0.0,y:0.0),White)
        drawTexture(background,Vector2(x:0.0,y:0.0),White)
        drawTexture(terrain_tex,Vector2(x:0.0,y:0.0),White)
    if entities[0].place != Mainland: camera.offset = Vector2(x: -dest_rect.x,y: -dest_rect.y)
    drawTexture(background2,dest_rect,dest_rect,Vector2(x:0.0,y:0.0),0.0,White)
    drawTexture(background,dest_rect,dest_rect,Vector2(x:0.0,y:0.0),0.0,White)
    drawTexture(terrain_tex,dest_rect,dest_rect,Vector2(x:0.0,y:0.0),0.0,White)
    for entity in entities.items:
      if entity.place == entities[0].place or entity.entity_type == Player:
        case entity.entity_type:
        of Player: drawTexture(player,Vector2(x:entity.x,y:entity.y),White)
        of Npc: drawTexture(player,Vector2(x:entity.x,y:entity.y),Green)
        of King: drawTexture(king,Vector2(x:entity.x,y:entity.y),White)
        else: drawRectangle(Vector2(x:entity.x,y:entity.y),Vector2(x:entity.w,y:entity.h),Lime)
    drawTexture(foreground,dest_rect,dest_rect,Vector2(x:0.0,y:0.0),0.0,White)
    endMode2D()

    #drawText("THE GAME HAS NOT CRASHED.\nYOU SIMPLY ROTTED AWAY.\nPRESS R TO RESTART.", 0, 0, 20, Black)
    drawFPS(880,10)
    let quest_text = #[(case quest:
      of 0: "Find out what everyone is talking about"
      of 1: "Find out more about Rot"
      of 2: "See where Rot manifested itself"
      else: "")]#"Current objective: Placeholder!".cstring
    if quest_text != "":
      drawRectangle(Vector2(x:0.0,y:0.0),Vector2(x:measureText(quest_text,20).float+20.0,y:40.0),Black)
      drawText(quest_text, 10, 10, 20, White)
    if shown_text != "":
      let text_height = measureText(font,shown_text.cstring,20,2).y+20.0
      drawRectangle(Vector2(x:0.0,y:screenHeight-text_height),Vector2(x:screenWidth,y:screenHeight-text_height-10.0),Black)
      drawText(shown_text.cstring, 10, (screenHeight-text_height).int32+10, 20, White)
    endDrawing()
    # ------------------------------------------------------------------------------------
  # De-Initialization
  # --------------------------------------------------------------------------------------
  closeWindow() # Close window and OpenGL context
  # --------------------------------------------------------------------------------------

main()