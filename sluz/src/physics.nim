import std/math

proc aabb*(x1: int, y1: int, w1: int, h1: int,
x2: int, y2: int, w2: int, h2: int): bool =
  if
    x1 < x2 + w2 and
    x1 + w1 > x2 and
    y1 < y2 + h2 and
    h1 + y1 > y2:
      return true
  false

type
    IVector2* = object
        x: int
        y: int
    IVector4* = object
        x: int
        y: int
        z: int
        w: int
    PhysicsObject = object of RootObj
        x: int
        y: int
        width: int
        height: int
        vx: float
        vy: float
        x_remainder: float
        y_remainder: float
        tangible: bool
    Solid* = object of PhysicsObject
        speed: int
        points: seq[IVector4]
        stop: int
        currentpoint: int
        backtrack: bool
        id: int
    Actor* = object of PhysicsObject
    Wall* = object of Solid
    Killer* = object of Solid
    Player* = object of Actor
        sticking: bool
    
var actors: seq[Actor]
var solids: seq[Wall]
var killers: seq[Killer]

proc moveX*(actor: var Actor,amount: float) = 
    actor.x_remainder += amount
    var move: int = actor.x_remainder.round().int
    if move != 0:
        actor.x_remainder-=move.float
        let signum = move.sgn().int
        var hit = false
        while move != 0:
            if actor.tangible:
                for solid in solids:
                    if aabb(actor.x+signum,actor.y,actor.width,actor.height,solid.x,solid.y,solid.width,solid.height) and solid.tangible:
                        hit = true
                        actor.vx = 0.0
                        break
                if hit: break
            actor.x += signum
            move -= signum
    discard

proc moveX*(killer: var Killer,amount: float) = 
    killer.x_remainder += amount
    var move: int = killer.x_remainder.round().int
    if move != 0: 
        killer.x_remainder-=move.float
        killer.x += move
    discard

proc moveY*(killer: var Killer,amount: float) = 
    killer.y_remainder += amount
    var move: int = killer.y_remainder.round().int
    if move != 0: 
        killer.y_remainder-=move.float
        killer.y += move
    discard

proc moveX_with_proc*(actor: var Actor,amount: float,on_collision: proc) = 
    actor.x_remainder += amount
    var move: int = actor.x_remainder.round().int
    if move != 0:
        actor.x_remainder-=move.float
        let signum = move.sgn().int
        var hit = false
        while move != 0:
            for solid in solids:
                if aabb(actor.x+signum,actor.y,actor.width,actor.height,solid.x,solid.y,solid.width,solid.height) and solid.tangible:
                    on_collision()
                    hit = true
                    break
            if hit: break
            actor.x += signum
            move -= signum
    discard

proc moveY*(actor: var Actor,amount: float) = 
    actor.y_remainder += amount
    var move: int = actor.y_remainder.round().int
    if move != 0:
        actor.y_remainder-=move.float
        let signum = move.sgn().int
        var hit = false
        while move != 0:
            if actor.tangible:
                for solid in solids:
                    if aabb(actor.x,actor.y+signum,actor.width,actor.height,solid.x,solid.y,solid.width,solid.height) and solid.tangible:
                        hit = true
                        actor.vy = 0.0
                        break
                if hit: break
            actor.y += signum
            move -= signum
    discard

proc checkCollision*(actor: Actor): bool =
    for solid in solids: 
        if aabb(actor.x,actor.y,actor.width,actor.height,solid.x,solid.y,solid.width,solid.height) and solid.tangible: 
            return true

method isRiding*(actor: Actor,solid: Solid): bool {.base.} = 
    if aabb(actor.x,actor.y+1,actor.width,actor.height,solid.x,solid.y,solid.width,solid.height) and actor.y<solid.y: return true
    else: return false

method isRiding*(actor: Player,solid: Solid): bool = 
    if aabb(actor.x,actor.y+1,actor.width,actor.height,solid.x,solid.y,solid.width,solid.height) or aabb(actor.x,actor.y-1,actor.width,actor.height,solid.x,solid.y,solid.width,solid.height) and actor.vy < 0.0 or (aabb(actor.x-1,actor.y,actor.width,actor.height,solid.x,solid.y,solid.width,solid.height) or aabb(actor.x+1,actor.y,actor.width,actor.height,solid.x,solid.y,solid.width,solid.height)): 
        return true
    else: return false

proc moveSolid*(solid: var Wall,vx:float,vy:float) =
    solid.x_remainder += vx
    solid.y_remainder += vy
    var move_x: int = solid.x_remainder.round().int
    var move_y: int = solid.y_remainder.round().int

    if move_x != 0 or move_y != 0:

        var riding: seq[int]
        for i, actor in actors.pairs:
            if actor of Player:
                if Player(actor).isRiding(solid):
                    riding.add(i)
            elif actor.isRiding(solid):
                riding.add(i)

        solid.tangible = false

        if move_x != 0:
            solid.x_remainder -= move_x.float
            solid.x += move_x
            #echo move_x
            if move_x > 0:
                for i, actor in actors.mpairs:
                    if aabb(actor.x,actor.y,actor.width,actor.height,solid.x,solid.y,solid.width,solid.height):
                        actor.moveX(((solid.x+solid.width)-actor.x).float)
                        if actor.checkCollision(): echo "dead"
                    elif riding.contains(i):
                        actor.moveX(move_x.float)
            else:
                for i, actor in actors.mpairs:
                    if aabb(actor.x,actor.y,actor.width,actor.height,solid.x,solid.y,solid.width,solid.height):
                        actor.moveX((solid.x-(actor.x+actor.width)).float)
                        if actor.checkCollision(): echo "dead"
                    elif riding.contains(i):
                        actor.moveX(move_x.float)
        if move_y != 0:
            solid.y_remainder -= move_y.float
            solid.y += move_y
            if move_y > 0:
                for i, actor in actors.mpairs:
                    if aabb(actor.x,actor.y,actor.width,actor.height,solid.x,solid.y,solid.width,solid.height):
                        actor.moveY(((solid.y+solid.height)-actor.y).float)
                        if actor.checkCollision(): echo "dead"
                    elif riding.contains(i):
                        actor.moveY(move_y.float)
            else:
                for i, actor in actors.mpairs:
                    if aabb(actor.x,actor.y,actor.width,actor.height,solid.x,solid.y,solid.width,solid.height):
                        actor.moveY((solid.y-(actor.y+actor.height)).float)
                        if actor.checkCollision(): echo "dead"
                    elif riding.contains(i):
                        actor.moveY(move_y.float)
        
        solid.tangible = true

    discard