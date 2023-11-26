import raylib, nim_tiled
import os, tables, strutils
include physics

const
  screenWidth = 960
  screenHeight = 960
  tileSize = 32

type
  State = enum
    menu, pause, gameplay, transitionIn, transitionOut, endscreen
  Spring* = object of PhysicsObject
    strong: bool
    angle: float

var springs: seq[Spring]

proc main =

  actors.insert(Player(x: 0,y: 768,width: 32,height: 32,tangible: true))

  var coyote = 0

  var spawnpos_x: int = 0
  var spawnpos_y: int = 768
  var checkpoint: int = 0
  var checkpoints: seq[(float,float)] = @[]
  var sticking: bool = false
  var state = menu
  var level = 0

  var map = case level:
    of 1: loadTiledMap(getAppDir()/"map1.tmx").orDefault
    of 2: loadTiledMap(getAppDir()/"map2.tmx").orDefault
    of 3: loadTiledMap(getAppDir()/"map3.tmx").orDefault
    of 4: loadTiledMap(getAppDir()/"map4.tmx").orDefault
    of 5: loadTiledMap(getAppDir()/"map5.tmx").orDefault
    of 6: loadTiledMap(getAppDir()/"map6.tmx").orDefault
    of 7: loadTiledMap(getAppDir()/"map7.tmx").orDefault
    of 8: loadTiledMap(getAppDir()/"map8.tmx").orDefault
    of 9: loadTiledMap(getAppDir()/"map9.tmx").orDefault
    else: loadTiledMap(getAppDir()/"map.tmx").orDefault

  initWindow(screenWidth, screenHeight, "SLUZ (stylized as \"ŚLUZ\")")
  setTargetFPS(60)

  let slime_img = loadImage(getAppDir()/"slime.png")
  let slime_tex = loadTextureFromImage(slime_img)
  let logo_tex = loadTextureFromImage(loadImage(getAppDir()/"sluz_logoB.png"))

  var camera = Camera2D()

  var player_actor: Player

  proc player_die() =
    player_actor.x = spawnpos_x
    player_actor.y = spawnpos_y
    player_actor.vx = 0.0
    player_actor.vy = 0.0
    for solid in solids.mitems:
      if solid.points.len > 0:
        solid.x = solid.points[0].x
        solid.y = solid.points[0].y
        solid.stop = solid.points[0].w.int
        solid.backtrack = false
        solid.currentpoint = 0
    for solid in killers.mitems:
      if solid.points.len > 0:
        solid.x = solid.points[0].x
        solid.y = solid.points[0].y
        solid.stop = solid.points[0].w.int
        solid.backtrack = false
        solid.currentpoint = 0

  proc map_init(level_in:int) =

    case level_in:
      of 0: map = loadTiledMap(getAppDir()/"map.tmx").orDefault
      of 1: map = loadTiledMap(getAppDir()/"map1.tmx").orDefault
      of 2: map = loadTiledMap(getAppDir()/"map2.tmx").orDefault
      of 3: map = loadTiledMap(getAppDir()/"map3.tmx").orDefault
      of 4: map = loadTiledMap(getAppDir()/"map4.tmx").orDefault
      of 5: map = loadTiledMap(getAppDir()/"map5.tmx").orDefault
      of 6: map = loadTiledMap(getAppDir()/"map6.tmx").orDefault
      of 7: map = loadTiledMap(getAppDir()/"map7.tmx").orDefault
      of 8: map = loadTiledMap(getAppDir()/"map8.tmx").orDefault
      of 9: map = loadTiledMap(getAppDir()/"map9.tmx").orDefault
      else: echo "no more levels, sorry"

    if checkpoints.len() > 0:
      for _ in 0..checkpoints.len()-1:
        checkpoints.delete(0)
    if solids.len() > 0:
      for _ in 0..solids.len()-1:
        solids.delete(0)
    if killers.len() > 0:
      for _ in 0..killers.len()-1:
        killers.delete(0)
    for obj in map.layers[1].objects:
      var vx = 0.0
      var vy = 0.0
      var points = @[IVector4(x:obj.x.int,y:obj.y.int,z:0,w:0)]
      if obj.properties.hasKey("vx"):
        vx = obj.properties.getOrDefault("vx").number
      if obj.properties.hasKey("vy"):
        vy = obj.properties.getOrDefault("vy").number
      if obj.properties.hasKey("speed"):
        points[0].z = obj.properties.getOrDefault("speed").number.int
      if obj.properties.hasKey("stop"):
        points[0].w = obj.properties.getOrDefault("stop").number.int
      if obj.properties.hasKey("points"):
        let pointstring = obj.properties.getOrDefault("points").str
        var field = 0
        var value = ""
        var point = IVector4(x:0,y:0,z:0,w:0)
        for i in 0..pointstring.len-1:
          if $pointstring[i] == "#":
            field += 1
            continue
          if $pointstring[i] == ",": 
            if value == "": continue
            case field:
            of 0: point.x += value.parseInt()
            of 1: point.y += value.parseInt()
            of 2: point.z += value.parseInt()
            of 3: point.w += value.parseInt()
            else: discard
            field += 1
            value = ""
            continue
          if $pointstring[i] == ";": 
            case field:
            of 0: point.x += value.parseInt()
            of 1: point.y += value.parseInt()
            of 2: point.z += value.parseInt()
            of 3: point.w += value.parseInt()
            else: discard
            points.add(point)
            field = 0
            value = ""
            point = IVector4(x:0,y:0,z:0,w:0)
            continue
          if $pointstring[i] == "x":
            case field:
              of 0: point.x += obj.x.int
              of 1: point.y += obj.x.int
              of 2: point.z += obj.x.int
              of 3: point.w += obj.x.int
              else: discard
            continue
          if $pointstring[i] == "y":
            case field:
              of 0: point.x += obj.y.int
              of 1: point.y += obj.y.int
              of 2: point.z += obj.y.int
              of 3: point.w += obj.y.int
              else: discard
            continue
          value.add(pointstring[i])
        #echo points
      solids.insert(Wall(x:obj.x.int,y:obj.y.int,width:obj.width.int,height:obj.height.int,vx:vx,vy:vy,tangible:true,points:points,stop:points[0].w,currentpoint:0,backtrack:false,speed:points[0].z,id:obj.id))
    for obj in map.layers[2].objects.items:
      var vx = 0.0
      var vy = 0.0
      var points = @[IVector4(x:obj.x.int,y:obj.y.int,z:0,w:0)]
      if obj.properties.hasKey("speed"):
        points[0].z = obj.properties.getOrDefault("speed").number.int
      if obj.properties.hasKey("stop"):
        points[0].w = obj.properties.getOrDefault("stop").number.int
      if obj.properties.hasKey("points"):
        let pointstring = obj.properties.getOrDefault("points").str
        var field = 0
        var value = ""
        var point = IVector4(x:0,y:0,z:0,w:0)
        for i in 0..pointstring.len-1:
          case $pointstring[i]:
            of "#":
              field += 1
              continue
            of ",":
              if value == "": continue
              case field:
                of 0: point.x += value.parseInt()
                of 1: point.y += value.parseInt()
                of 2: point.z += value.parseInt()
                of 3: point.w += value.parseInt()
                else: discard
              field += 1
              value = ""
              continue
            of ";":
              case field:
                of 0: point.x += value.parseInt()
                of 1: point.y += value.parseInt()
                of 2: point.z += value.parseInt()
                of 3: point.w += value.parseInt()
                else: discard
              points.add(point)
              field = 0
              value = ""
              point = IVector4(x:0,y:0,z:0,w:0)
              continue
            of "x":
              case field:
                of 0: point.x += obj.x.int
                of 1: point.y += obj.x.int
                of 2: point.z += obj.x.int
                of 3: point.w += obj.x.int
                else: discard
              continue
            of "y":
              case field:
                of 0: point.x += obj.y.int
                of 1: point.y += obj.y.int
                of 2: point.z += obj.y.int
                of 3: point.w += obj.y.int
                else: discard
              continue
          value.add(pointstring[i])
       # echo points
      if points.len != 0: killers.insert(Killer(x:obj.x.int,y:obj.y.int,width:obj.width.int,height:obj.height.int,vx:vx,vy:vy,tangible:true,points:points,stop:points[0].w,currentpoint:0,backtrack:false,speed:points[0].z,id:obj.id))
      else: killers.insert(Killer(x:obj.x.int,y:obj.y.int,width:obj.width.int,height:obj.height.int,vx:vx,vy:vy,tangible:true,points: @[],stop:0,currentpoint:0,backtrack:false,speed:4,id:obj.id))
    for check in map.layers[3].objects.items:
      checkpoints.add((check.x,check.y))
    #[for thing in map.layers[4].objects.items:
      let t = thing.properties.getOrDefault("type").
      case t:
      of 0: 
        let strong = thing.properties.getOrDefault("strong").boolean
        let angle = thing.properties.getOrDefault("angle").number
        springs.add(Spring(x:thing.x.int,y:thing.y.int,width:32,height:16,strong:strong,angle:angle)) 
      else: continue]#
    
    spawnpos_x = checkpoints[0][0].int
    spawnpos_y = checkpoints[0][1].int
    player_actor.x = spawnpos_x
    player_actor.y = spawnpos_y

  while not windowShouldClose():

    player_actor.sticking = sticking

    case state:
    of gameplay:

      for solid in solids.mitems:
        if solid.stop > 0:
          solid.stop -= 1
        elif solid.points.len > 1:
          let angle = arctan2(
            solid.points[solid.currentpoint].y.float - solid.y.float,
            solid.points[solid.currentpoint].x.float - solid.x.float
          )
          solid.vx = angle.cos()*solid.speed.float
          solid.vy = angle.sin()*solid.speed.float

          if solid.vx > 0 and solid.x.float+solid.vx>solid.points[solid.currentpoint].x.float or solid.vx < 0 and solid.x.float+solid.vx<solid.points[solid.currentpoint].x.float: 
            solid.x_remainder = 0.0
            solid.vx = solid.points[solid.currentpoint].x.float-solid.x.float
          if solid.vy > 0 and solid.y.float+solid.vy>solid.points[solid.currentpoint].y.float or solid.vy < 0 and solid.y.float+solid.vy<solid.points[solid.currentpoint].y.float: 
            solid.y_remainder = 0.0
            solid.vy = solid.points[solid.currentpoint].y.float-solid.y.float

          solid.moveSolid(solid.vx,solid.vy)

          if solid.x==solid.points[solid.currentpoint].x and solid.y==solid.points[solid.currentpoint].y and solid.stop == 0:
            solid.speed = solid.points[solid.currentpoint].z
            solid.stop = (solid.points[solid.currentpoint].w).int
            if solid.currentpoint == solid.points.len-1 or solid.currentpoint == 0: solid.backtrack = not solid.backtrack
            if solid.backtrack: solid.currentpoint += 1 else: solid.currentpoint -= 1

        elif solid.vx != 0 or solid.vy != 0:
          for solid2 in solids:
            if solid != solid2:
              if aabb(solid.x+solid.vx.int,solid.y,solid.width,solid.height,solid2.x+solid2.vx.int,solid2.y,solid2.width,solid2.height) and solid.tangible:
                solid.vx *= -1
              if aabb(solid.x,solid.y+solid.vy.int,solid.width,solid.height,solid2.x,solid2.y+solid2.vy.int,solid2.width,solid2.height) and solid.tangible:
                solid.vy *= -1
          solid.moveSolid(solid.vx,solid.vy)

      for solid in killers.mitems:
        if solid.stop > 0:
          solid.stop -= 1
        if solid.points.len > 1:
          let angle = arctan2(
            solid.points[solid.currentpoint].y.float - solid.y.float,
            solid.points[solid.currentpoint].x.float - solid.x.float
          )
          solid.vx = angle.cos()*solid.speed.float
          solid.vy = angle.sin()*solid.speed.float
          if solid.vx > 0 and solid.x.float+solid.vx>solid.points[solid.currentpoint].x.float or solid.vx < 0 and solid.x.float+solid.vx<solid.points[solid.currentpoint].x.float: 
            solid.x_remainder = 0.0
            solid.vx = solid.points[solid.currentpoint].x.float-solid.x.float
          if solid.vy > 0 and solid.y.float+solid.vy>solid.points[solid.currentpoint].y.float or solid.vy < 0 and solid.y.float+solid.vy<solid.points[solid.currentpoint].y.float: 
            solid.y_remainder = 0.0
            solid.vy = solid.points[solid.currentpoint].y.float-solid.y.float

          solid.moveX(solid.vx)
          solid.moveY(solid.vy)

          if solid.x == solid.points[solid.currentpoint].x and solid.y == solid.points[solid.currentpoint].y and solid.stop == 0:
            solid.stop = solid.points[solid.currentpoint].w*60
            if solid.currentpoint == solid.points.len-1 or solid.currentpoint == 0: solid.backtrack = not solid.backtrack
            if solid.backtrack: solid.currentpoint += 1 else: solid.currentpoint -= 1

      for actor in actors.mitems:
        if actor of Player:
          if not sticking:
            actor.vy += 0.5
            if actor.vy > 16.0: actor.vy = 16.0
          if player_actor.y > 0:
            let topleft = map.layers[0].tileAt(floor(actor.x.float/32.0).int,floor(actor.y.float/32.0).int)
            let topright = map.layers[0].tileAt(floor((actor.x+tileSize-1).float/32.0).int,floor(actor.y.float/32.0).int)
            let bottomleft = map.layers[0].tileAt(floor(actor.x.float/32.0).int,floor((actor.y+tileSize-1).float/32.0).int)
            let bottomright = map.layers[0].tileAt(floor((actor.x+tileSize-1).float/32.0).int,floor((actor.y+tileSize-1).float/32.0).int)
            if topleft == 43 or topright == 43 or bottomleft == 43 or bottomright == 43:
              actor.vy = -17.0
              coyote = 0
          player_actor = actor.Player
        else:
          actor.vy += 0.5
          if actor.vy > 16.0: actor.vy = 16.0

      coyote -= 1
      if coyote < 0: coyote = 0

      if isKeyDown(D) or isKeyDown(Right): player_actor.vx = 4.0
      elif isKeyDown(A) or isKeyDown(Left): player_actor.vx = -4.0
      else: player_actor.vx = 0.0

      for killer in killers:
        if aabb(player_actor.x,player_actor.y,player_actor.width,player_actor.height,killer.x,killer.y,killer.width,killer.height): 
          echo "player spiked"
          player_die()

      if player_actor.checkCollision():
        echo "player squished"
        player_die()

      player_actor.moveX(player_actor.vx)
      player_actor.moveY(player_actor.vy)

      let top = checkCollision(Actor(x:player_actor.x,y:player_actor.y-1,width:player_actor.width,height:player_actor.height))
      let bottom = checkCollision(Actor(x:player_actor.x,y:player_actor.y+1,width:player_actor.width,height:player_actor.height))
      let left = checkCollision(Actor(x:player_actor.x-1,y:player_actor.y,width:player_actor.width,height:player_actor.height))
      let right = checkCollision(Actor(x:player_actor.x+1,y:player_actor.y,width:player_actor.width,height:player_actor.height))

      if top:
        if player_actor.vy < 0:
          coyote = 6

      if bottom: 
        coyote = 6

      if left or right: coyote = 6

      if (isKeyDown(Space) or isKeyDown(W) or isKeyDown(Up) or isKeyDown(C)) and ((bottom or coyote > 0) or right or left or top) and not sticking: 
        player_actor.vy = -8.5
        coyote = 0
    
      if (isKeyDown(LeftShift) or isKeyDown(RightShift)) and (right or left):
        if not sticking: 
          player_actor.vy = 0.0
          player_actor.y_remainder = 0.0
          sticking = true
      else:
        sticking = false

      for c in checkpoint..checkpoints.len()-1:
        let check = checkpoints[c]
        if player_actor.x.float >= check[0] and checkpoint < c:
          spawnpos_x = check[0].int
          spawnpos_y = check[1].int
          checkpoint = c
      if player_actor.x >= map.width*tileSize:
        state = endscreen

      if isKeyPressed(R):
        player_die()
      if isKeyPressed(Enter):
        state = pause

      for actor in actors.mitems:
        if actor of Player:
          actor = player_actor

      camera.zoom = 1.0
      camera.rotation = 0.0
      camera.target = Vector2(x:0.0,y:0.0)
      camera.offset = Vector2(x: -player_actor.x.float+screenWidth.float/2.0-tileSize.float,y: 0.0)

    of pause:
      if isKeyPressed(Enter):
        state = gameplay
    of menu:
      if isKeyPressed(Enter):
        state = transitionIn
        map_init(level)
    of endscreen:
      if isKeyPressed(Enter):
        state = transitionIn
        level += 1
        map_init(level)
    of transitionIn:
      state = transitionOut
    of transitionOut:
      state = gameplay
    
    beginDrawing()

    clearBackground(LightGray)
    
    if state == menu:
      drawTexture(logo_tex,0,0,Green)
      drawText("Press Enter to continue", 10, 266, 20, Black)
    else:

      beginMode2D(camera)

      for actor in actors:
        if actor of Player: 
          let squish = if checkCollision(Actor(x:player_actor.x,y:player_actor.y-1,width:player_actor.width,height:player_actor.height)): 0.0 else: actor.vy.abs()
        #if actor.vy == 0.0 or top or bottom: squish *= 0.0 
          drawTexture(slime_tex, Rectangle(x:0.0,y:0.0,width:32.0,height:32.0), Rectangle(x:actor.x.float,y:actor.y.float-squish/2.0,width:32.0,height:32.0+squish), Vector2(x:0.0,y:0.0), 0.0, Green) #drawTexture(slime_tex,Vector2(x:actor.x.float,y:actor.y.float),Green) #drawRectangle(Rectangle(x:actor.x.float,y:actor.y.float,width:actor.width.float,height:actor.height.float),Green)
      for killer in killers:
        drawRectangle(Rectangle(x:killer.x.float,y:killer.y.float,width:killer.width.float,height:killer.height.float),Red)
      for solid in solids:
        drawRectangle(Rectangle(x:solid.x.float,y:solid.y.float,width:solid.width.float,height:solid.height.float),Black)
      
      if level == 0:
        drawText("WASD/Arrows to move.\nSpace/Up/W/C to jump.", 160, 200, 20, Black)
        drawText("Shift to cling to walls.", 5202, 416, 20, Black)

      endMode2D()

    if state == pause:
      drawRectangle(0,0,screenWidth,screenHeight,Color(r:0,g:0,b:0,a:64))
      drawText("PAUSED", 10,10,20,White)
    if state == endscreen:
      drawRectangle(0,0,screenWidth,screenHeight,Color(r:0,g:0,b:0,a:64))
      drawText("Level finished. Press Enter to proceed to the next.", 10,10,20,White)

    endDrawing()
    
  closeWindow()

main()