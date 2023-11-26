import raylib, raymath
include math
import random

proc aabb*(x1: float, y1: float, w1: float, h1: float,
x2: float, y2: float, w2: float, h2: float): bool =
  if
    x1 < x2 + w2 and
    x1 + w1 > x2 and
    y1 < y2 + h2 and
    h1 + y1 > y2:
      return true
  false

#[------------------------------------------------------------------------------------
  Program main entry point
  ------------------------------------------------------------------------------------]#

const screenWidth = 1024;
const screenHeight = 1024;

type 
  State = enum
    Title
    Gameplay
    Pause
    GameOver
  MonsterType = enum
    Standard
    Knight
    Swordfish
    Golem
  EnemyType = enum
    Helpless
    Beginner
    Experienced
    Mage
    TeamMelee
    TeamArcher
    TeamSpellcaster
    TeamTank
    PrinceCharming
    WizardRed  #fire
    WizardYellow # lightning
    WizardBlue # ice
    WizardGreen # shadow wizard
    Goblin # insanity
  BulletType = enum
    Arrow
    FireBall
    BigFire
    IceBall
    PoisonBall
  AreaDamageType = enum
    Fire
    Inferno
    Ice
    Poison
    Thunder

  Weapon = enum
    None
  Target = enum
    None
    Leader
    EnemyAttack

  Thing = object of RootObj
    x: float
    y: float
    w: float
    h: float
    d: float
  Bullet = object of Thing
    damage_type: BulletType
    vx: float
    vy: float
    lifetime: float
  Solid = object of Thing
  AreaDamage = object of Thing
    damage_type: AreaDamageType
    anim_time: float
    time: float
  Being = object of Thing
    hp: float
    max_hp: float
    atk: float
    #def: float
    spd: float
    cooldown: float
    max_cooldown: float
    tangible: bool
    vx: float
    vy: float
    rotation:float
  Monster = object of Being
    weapon: Weapon
    monster_type: MonsterType
    lead: bool
    target: Target
    loyal: bool
  Enemy = object of Being
    enemy_type: EnemyType

proc recenter(model: var Model) = 
  let bb: BoundingBox = model.getModelBoundingBox()
  var center = Vector3()
  center.x = bb.min.x  + (((bb.max.x - bb.min.x)/2))
  center.z = bb.min.z  + (((bb.max.z - bb.min.z)/2))

  let matTranslate = translate(-center.x,0.0,-center.z)
  model.transform = matTranslate

proc main =

  # Initialization
  #--------------------------------------------------------------------------------------\

  randomize()

  initWindow(screenWidth, screenHeight, "STADO");

  var plebian = loadModel("plebian.vox")
  plebian.recenter()
  var golem = loadModel("golem.vox")
  golem.recenter()
  var helpless = loadModel("wanderer.vox")
  helpless.recenter()
  var beginner = loadModel("beginner.vox")
  beginner.recenter()
  var experienced = loadModel("assasin.vox")
  experienced.recenter()
  var mage = loadModel("mage.vox")
  mage.recenter()
  var team_melee = loadModel("viking.vox")
  team_melee.recenter()
  var team_archer = loadModel("archer.vox")
  team_melee.recenter()
  var team_spellcaster = loadModel("mage_super.vox")
  team_spellcaster.recenter()
  var team_tank = loadModel("red_ogre.vox")
  team_tank.recenter()
  var wiz_ice = loadModel("wiz_ice.vox")
  wiz_ice.recenter()
  var wiz_fire = loadModel("wiz_fire.vox")
  wiz_fire.recenter()
  var wiz_thunder = loadModel("wiz_thunder.vox")
  wiz_thunder.recenter()

  var state = Gameplay
  
  var level = 0

  var monsters: seq[Monster] = @[
    Monster(x:0.0,y:0.0,w:32.0,h:32.0, d: 32.0, weapon: None, monster_type: Standard, lead: true, target: None, hp: 25.0, max_hp: 25.0, tangible: false, loyal: true,max_cooldown: 60.0),
    #Monster(x:128.0,y:32.0,w:32.0,h:32.0, weapon: None, monster_type: Standard, lead: false, target: Leader, hp: 25.0, tangible: true),
    #Monster(x:128.0,y:256.0,w:32.0,h:32.0, weapon: None, monster_type: Standard, lead: false, target: EnemyAttack, hp: 25.0, tangible: true)
    ]

  var enemies: seq[Enemy]

  #[case level:
  of 0: "THERE'S NO SUCH THING AS A LEVEL 0"
  of 1: enemies.add(Enemy(x:960.0,y:960.0,w:32.0,h:64.0, enemy_type: Helpless, hp: 100.0, tangible: true, spd: 3.0))
  of 2:
    enemies.add(Enemy(x:960.0,y:960.0,w:32.0,h:64.0, enemy_type: Beginner, hp: 200.0, tangible: true, spd: 3.0))
    for n in 0..2:
      monsters.add(Monster(x:rand(-960..960).float,y:rand(-960..960).float,w:32.0,h:32.0, weapon: None, monster_type: Standard, lead: false, target: None, hp: 25.0, tangible: true, loyal: false))
  of 3:
    enemies.add(Enemy(x:960.0,y:960.0,w:32.0,h:64.0, enemy_type: Experienced, hp: 300.0, tangible: true, spd: 4.0))
    for n in 0..7:
      monsters.add(Monster(x:rand(-960..960).float,y:rand(-960..960).float,w:32.0,h:32.0, weapon: None, monster_type: Standard, lead: false, target: None, hp: 25.0, tangible: true, loyal: false))
  of 4:
    enemies.add(Enemy(x:960.0,y:960.0,w:32.0,h:64.0, enemy_type: Mage, hp: 200.0, tangible: true, spd: 4.0))
    monsters.add(Monster(x:rand(-960..960).float,y:rand(-960..960).float,w:32.0,h:32.0, weapon: None, monster_type: Knight, lead: false, target: None, hp: 75.0, tangible: true, loyal: false))
  of 5:
    enemies.add(Enemy(x:960.0,y:960.0,w:32.0,h:64.0, enemy_type: TeamMelee, hp: 350.0, tangible: true, spd: 4.0))
    enemies.add(Enemy(x:960.0,y:960.0,w:32.0,h:64.0, enemy_type: TeamArcher, hp: 200.0, tangible: true, spd: 4.0))
    enemies.add(Enemy(x:960.0,y:960.0,w:32.0,h:64.0, enemy_type: TeamSpellcaster, hp: 75.0, tangible: true, spd: 4.0))
    enemies.add(Enemy(x:960.0,y:960.0,w:64.0,h:64.0, enemy_type: TeamTank, hp: 700.0, tangible: true, spd: 4.0))
    for n in 0..10:
      monsters.add(Monster(x:rand(-960..960).float,y:rand(-960..960).float,w:32.0,h:32.0, weapon: None, monster_type: Standard, lead: false, target: None, hp: 25.0, tangible: true, loyal: false))
    for n in 0..1:
      monsters.add(Monster(x:rand(-960..960).float,y:rand(-960..960).float,w:32.0,h:32.0, weapon: None, monster_type: Knight, lead: false, target: None, hp: 75.0, tangible: true, loyal: false))
  else: echo "MAX LEVEL"]#

  #for n in 0..16:
    #monsters.add(Monster(x:rand(-960..960).float,y:rand(-960..960).float,w:32.0,h:32.0, weapon: None, monster_type: Standard, lead: false, target: None, hp: 25.0, tangible: true, loyal: false))
  #for n in 0..4:
    #monsters.add(Monster(x:rand(-960..960).float,y:rand(-960..960).float,w:32.0,h:32.0, weapon: None, monster_type: Knight, lead: false, target: None, hp: 75.0, tangible: true, loyal: false))

  var area_damage: seq[AreaDamage]# = @[AreaDamage(x:0.0,y:0.0,w:128.0,h:128.0,damage_type:Fire,time:0.0,anim_time:2.0)]
  var bullets: seq[Bullet] = @[#[AreaDamageBall(x:0.0,y:0.0,w:128.0,h:128.0,damage_type:Fire)]#]
  var solids: seq[Solid] = @[Solid(x:96.0,y:96.0,w:96.0,h:96.0,d:96.0)]

  var current_choice = 1

  let map_screen = loadRenderTexture(screenWidth,screenHeight)

  var camera = Camera2D()
  var camera3 = Camera3D()
  camera3.position = Vector3( x:10.0, y:10.0, z:10.0 );  # Camera position
  camera3.target = Vector3( x:0.0, y:0.0, z:0.0 );      # Camera looking at point
  camera3.up = Vector3( x:0.0, y:1.0, z:0.0 );          # Camera up vector (rotation towards target)
  camera3.fovy = 45.0;                                # Camera field-of-view Y
  camera3.projection = Perspective;   

  setTargetFPS(60);               # Set our game to run at 60 frames-per-second
    #--------------------------------------------------------------------------------------

    # Main game loop
  while not windowShouldClose():    # Detect window close button or ESC key
    # Update
    if state == Gameplay:
      for (i,monster) in monsters.mpairs:
        monster.cooldown -= 1.0
        if monster.cooldown < 0.0: monster.cooldown = 0.0
        if monster.target == EnemyAttack and enemies.len == 0: monster.target = None
        if monster.lead:
          monster.tangible = false
          if isKeyDown(D): monster.vx = 5.0
          elif isKeyDown(A): monster.vx = -5.0
          else: monster.vx = 0.0
          for area in area_damage.items:
            if aabb(monster.x-monster.w/2.0 + monster.vx,monster.y-monster.h/2.0,monster.w,monster.h,area.x-area.w/2.0,area.y-area.h/2.0,area.w,area.h) and area.time > 0.0 and area.damage_type == Ice:
              monster.vx = 0.0
              break
          if monster.vx != 0.0:
            for monster2 in enemies:
              if aabb(monster.x-monster.w/2.0 + monster.vx,monster.y-monster.h/2.0,monster.w,monster.h,monster2.x-monster2.w/2.0,monster2.y-monster2.h/2.0,monster2.w,monster2.h) and monster2.tangible and monster.tangible:
              #if monster.x >= monster2.x: monster.x -= (monster.x-monster.w/2.0)-(monster2.x+monster2.w/2.0/4.0)
              #else: monster.x -= (monster.x+monster.w/2.0)-(monster2.x-monster2.w/2.0/4.0)
              #if monster.x >= monster2.x: monster.x -= (monster.x-monster.w/2.0)-(monster2.x+monster2.w/2.0/4.0)
              #else: monster.x -= (monster.x+monster.w/2.0)-(monster2.x-monster2.w/2.0/4.0)
                monster.vx = 0.0
            monster.x += monster.vx
            monster.tangible = true
            for solid in solids.items:
              if aabb(monster.x-monster.w/2.0,monster.y-monster.h/2.0,monster.w,monster.h,solid.x-solid.w/2.0,solid.y-solid.h/2.0,solid.w,solid.h) and monster.tangible:
                if monster.x >= solid.x: monster.x -= (monster.x-monster.w/2.0)-(solid.x+solid.w/2.0)
                else: monster.x -= (monster.x+monster.w/2.0)-(solid.x-solid.w/2.0)
            for solid in enemies.items:
              if aabb(monster.x-monster.w/2.0,monster.y-monster.h/2.0,monster.w,monster.h,solid.x-solid.w/2.0,solid.y-solid.h/2.0,solid.w,solid.h) and monster.tangible:
                if monster.x >= solid.x: monster.x -= (monster.x-monster.w/2.0)-(solid.x+solid.w/2.0)
                else: monster.x -= (monster.x+monster.w/2.0)-(solid.x-solid.w/2.0)
          monster.tangible = true
        else:
          var angle = 0.0
          if monster.target == Leader:
            angle = arctan2(
              monsters[0].y - monster.y,
              monsters[0].x - monster.x
            )
          if monster.target == EnemyAttack:
            if enemies.len > 0:
              var distance = sqrt((enemies[0].x-monster.x).pow(2)+(enemies[0].y-monster.y).pow(2))
              var target = 0
              for (id,enemy) in enemies.pairs:
                if sqrt((enemy.x-monster.x).pow(2)+(enemy.y-monster.y).pow(2)) < distance:
                  distance = sqrt((enemy.x-monster.x).pow(2)+(enemy.y-monster.y).pow(2))
                  target = id
              angle = arctan2(
                enemies[target].y - monster.y,
                enemies[target].x - monster.x
              )
          if monster.target == None:
            for monster2 in monsters:
              if aabb(monster.x-monster.w/2.0,monster.y-monster.h/2.0,monster.w,monster.h,monster2.x-monster2.w/2.0,monster2.y-monster2.h/2.0,monster2.w,monster2.h) and monster2 != monster and monster2.tangible:
                if monster.x >= monster2.x: monster.x -= (monster.x-monster.w/2.0)-(monster2.x+monster2.w/2.0)
                else: monster.x -= (monster.x+monster.w/2.0)-(monster2.x-monster2.w/2.0)
            for monster2 in enemies:
              if aabb(monster.x-monster.w/2.0,monster.y-monster.h/2.0,monster.w,monster.h,monster2.x-monster2.w/2.0,monster2.y-monster2.h/2.0,monster2.w,monster2.h) and monster2.tangible:
                if monster.x >= monster2.x: monster.x -= (monster.x-monster.w/2.0)-(monster2.x+monster2.w/2.0)
                else: monster.x -= (monster.x+monster.w/2.0)-(monster2.x-monster2.w/2.0)
            for solid in solids.items:
              if aabb(monster.x-monster.w/2.0,monster.y-monster.h/2.0,monster.w,monster.h,solid.x-solid.w/2.0,solid.y-solid.h/2.0,solid.w,solid.h) and monster.tangible:
                if monster.x >= solid.x: monster.x -= (monster.x-monster.w/2.0)-(solid.x+solid.w/2.0/4.0)
                else: monster.x -= (monster.x+monster.w/2.0)-(solid.x-solid.w/2.0/4.0)
          else:
            monster.vx = angle.cos()*4.0
            for area in area_damage.items:
              if aabb(monster.x-monster.w/2.0 + monster.vx,monster.y-monster.h/2.0,monster.w,monster.h,area.x-area.w/2.0,area.y-area.h/2.0,area.w,area.h) and area.damage_type == Ice and area.time > 0.0:
                monster.vx = 0.0
                break
            if monster.vx != 0.0:
              for monster2 in monsters:
                if aabb(monster.x-monster.w/2.0+monster.vx,monster.y-monster.h/2.0,monster.w,monster.h,monster2.x-monster2.w/2.0,monster2.y-monster2.h/2.0,monster2.w,monster2.h) and monster2 != monster and monster2.tangible:
              #if monster.x >= monster2.x: monster.x -= (monster.x-monster.w/2.0)-(monster2.x+monster2.w/2.0/4.0)
              #else: monster.x -= (monster.x+monster.w/2.0)-(monster2.x-monster2.w/2.0/4.0)
                  monster.vx = 0.0
              for monster2 in enemies:
                if aabb(monster.x-monster.w/2.0+monster.vx,monster.y-monster.h/2.0,monster.w,monster.h,monster2.x-monster2.w/2.0,monster2.y-monster2.h/2.0,monster2.w,monster2.h) and monster2.tangible:
              #if monster.x >= monster2.x: monster.x -= (monster.x-monster.w/2.0)-(monster2.x+monster2.w/2.0/4.0)
              #else: monster.x -= (monster.x+monster.w/2.0)-(monster2.x-monster2.w/2.0/4.0)
                  monster.vx = 0.0
              monster.x += monster.vx
              for solid in solids.items:
                if aabb(monster.x-monster.w/2.0,monster.y-monster.h/2.0,monster.w,monster.h,solid.x-solid.w/2.0,solid.y-solid.h/2.0,solid.w,solid.h) and monster.tangible:
                  if monster.x >= solid.x: monster.x -= (monster.x-monster.w/2.0)-(solid.x+solid.w/2.0)
                  else: monster.x -= (monster.x+monster.w/2.0)-(solid.x-solid.w/2.0)
              for solid in enemies.items:
                if aabb(monster.x-monster.w/2.0,monster.y-monster.h/2.0,monster.w,monster.h,solid.x-solid.w/2.0,solid.y-solid.h/2.0,solid.w,solid.h) and monster.tangible:
                  if monster.x >= solid.x: monster.x -= (monster.x-monster.w/2.0)-(solid.x+solid.w/2.0)
                  else: monster.x -= (monster.x+monster.w/2.0)-(solid.x-solid.w/2.0)
            #  of EnemyAttack:
      for (i,monster) in monsters.mpairs:
        monster.cooldown -= 1.0
        if monster.cooldown < 0.0: monster.cooldown = 0.0
        if monster.target == EnemyAttack and enemies.len == 0: monster.target = None
        if monster.lead:
          monster.tangible = false
          if isKeyDown(S): monster.vy = 5.0
          elif isKeyDown(W): monster.vy = -5.0
          else: monster.vy = 0.0
          for area in area_damage.items:
            if aabb(monster.x-monster.w/2.0 + monster.vx,monster.y-monster.h/2.0,monster.w,monster.h,area.x-area.w/2.0,area.y-area.h/2.0,area.w,area.h) and area.damage_type == Ice and area.time > 0.0:
              monster.vy = 0.0
              break
          if monster.vy != 0.0:
            for monster2 in enemies:
              if aabb(monster.x-monster.w/2.0,monster.y-monster.h/2.0+monster.vy,monster.w,monster.h,monster2.x-monster2.w/2.0,monster2.y-monster2.h/2.0,monster2.w,monster2.h) and monster2.tangible:
              #if monster.x >= monster2.x: monster.x -= (monster.x-monster.w/2.0)-(monster2.x+monster2.w/2.0/4.0)
              #else: monster.x -= (monster.x+monster.w/2.0)-(monster2.x-monster2.w/2.0/4.0)
                monster.vy = 0.0
            monster.y += monster.vy
            monster.tangible = true
            for solid in solids:
              if aabb(monster.x-monster.w/2.0,monster.y-monster.h/2.0+monster.vy,monster.w,monster.h,solid.x-solid.w/2.0,solid.y-solid.h/2.0,solid.w,solid.h) and monster.tangible:
                if monster.y >= solid.y: monster.y -= (monster.y-monster.h/2.0)-(solid.y+solid.h/2.0)
                else: monster.y -= (monster.y+monster.h/2.0)-(solid.y-solid.h/2.0)
            for solid in enemies:
              if aabb(monster.x-monster.w/2.0,monster.y-monster.h/2.0+monster.vy,monster.w,monster.h,solid.x-solid.w/2.0,solid.y-solid.h/2.0,solid.w,solid.h) and monster.tangible:
                if monster.y >= solid.y: monster.y -= (monster.y-monster.h/2.0)-(solid.y+solid.h/2.0)
                else: monster.y -= (monster.y+monster.h/2.0)-(solid.y-solid.h/2.0)
          monster.tangible = true
        else:
          var angle = 0.0
          if monster.loyal:
            if monster.target == Leader:
              angle = arctan2(
                monsters[0].y - monster.y,
                monsters[0].x - monster.x
              )
            if monster.target == EnemyAttack:
              if enemies.len > 0:
                var distance = sqrt((enemies[0].x-monster.x).pow(2)+(enemies[0].y-monster.y).pow(2))
                var target = 0
                for (id,enemy) in enemies.pairs:
                  if sqrt((enemy.x-monster.x).pow(2)+(enemy.y-monster.y).pow(2)) < distance:
                    distance = sqrt((enemy.x-monster.x).pow(2)+(enemy.y-monster.y).pow(2))
                    target = id
                angle = arctan2(
                  enemies[target].y - monster.y,
                  enemies[target].x - monster.x
                )
          if monster.target == None:
          #[for monster2 in monsters:
            if aabb(monster.x-monster.w/2.0,monster.y-monster.h/2.0,monster.w,monster.h,monster2.x-monster2.w/2.0,monster2.y-monster2.h/2.0,monster2.w,monster2.h) and monster2 != monster and monster2.tangible:
              if monster.x >= monster2.x: monster.x -= (monster.x-monster.w/2.0)-(monster2.x+monster2.w/2.0/4.0)
              else: monster.x -= (monster.x+monster.w/2.0)-(monster2.x-monster2.w/2.0/4.0)
          for monster2 in enemies:
            if aabb(monster.x-monster.w/2.0,monster.y-monster.h/2.0,monster.w,monster.h,monster2.x-monster2.w/2.0,monster2.y-monster2.h/2.0,monster2.w,monster2.h) and monster2.tangible:
              if monster.x >= monster2.x: monster.x -= (monster.x-monster.w/2.0)-(monster2.x+monster2.w/2.0/4.0)
              else: monster.x -= (monster.x+monster.w/2.0)-(monster2.x-monster2.w/2.0/4.0)
          for monster2 in monsters:
            if aabb(monster.x-monster.w/2.0,monster.y-monster.h/2.0,monster.w,monster.h,monster2.x-monster2.w/2.0,monster2.y-monster2.h/2.0,monster2.w,monster2.h) and monster2 != monster and monster2.tangible:
              if monster.y >= monster2.y: monster.y -= (monster.y-monster.h/2.0)-(monster2.y+monster2.h/2.0/4.0)
              else: monster.y -= (monster.y+monster.h/2.0)-(monster2.y-monster2.h/2.0/4.0)
          for monster2 in enemies:
            if aabb(monster.x-monster.w/2.0,monster.y-monster.h/2.0,monster.w,monster.h,monster2.x-monster2.w/2.0,monster2.y-monster2.h/2.0,monster2.w,monster2.h) and monster2.tangible:
              if monster.y >= monster2.y: monster.y -= (monster.y-monster.h/2.0)-(monster2.y+monster2.h/2.0/4.0)
              else: monster.y -= (monster.y+monster.h/2.0)-(monster2.y-monster2.h/2.0/4.0)]#
            for monster2 in monsters:
              if aabb(monster.x-monster.w/2.0,monster.y-monster.h/2.0,monster.w,monster.h,monster2.x-monster2.w/2.0,monster2.y-monster2.h/2.0,monster2.w,monster2.h) and monster2 != monster and monster2.tangible:
                if monster.y >= monster2.y: monster.y -= (monster.y-monster.h/2.0)-(monster2.y+monster2.h/2.0)
                else: monster.y -= (monster.y+monster.h/2.0)-(monster2.y-monster2.h/2.0)
            for monster2 in enemies:
              if aabb(monster.x-monster.w/2.0,monster.y-monster.h/2.0,monster.w,monster.h,monster2.x-monster2.w/2.0,monster2.y-monster2.h/2.0,monster2.w,monster2.h) and monster2.tangible:
                if monster.y >= monster2.y: monster.y -= (monster.y-monster.h/2.0)-(monster2.y+monster2.h/2.0)
                else: monster.y -= (monster.y+monster.h/2.0)-(monster2.y-monster2.h/2.0)
            for monster2 in solids:
              if aabb(monster.x-monster.w/2.0,monster.y-monster.h/2.0,monster.w,monster.h,monster2.x-monster2.w/2.0,monster2.y-monster2.h/2.0,monster2.w,monster2.h):
                if monster.y >= monster2.y: monster.y -= (monster.y-monster.h/2.0)-(monster2.y+monster2.h/2.0)
                else: monster.y -= (monster.y+monster.h/2.0)-(monster2.y-monster2.h/2.0)
          else:
            monster.vy = angle.sin()*4.0
            for area in area_damage.items:
              if aabb(monster.x-monster.w/2.0 + monster.vx,monster.y-monster.h/2.0,monster.w,monster.h,area.x-area.w/2.0,area.y-area.h/2.0,area.w,area.h) and area.damage_type == Ice and area.time > 0.0:
                monster.vy = 0.0
                break
            if monster.vy != 0.0:
              for monster2 in monsters:
                if aabb(monster.x-monster.w/2.0,monster.y-monster.h/2.0+monster.vy,monster.w,monster.h,monster2.x-monster2.w/2.0,monster2.y-monster2.h/2.0,monster2.w,monster2.h) and monster2 != monster and monster2.tangible:
              #if monster.y >= monster2.y: monster.y -= (monster.y-monster.h/2.0)-(monster2.y+monster2.h/2.0/4.0)
              #else: monster.y -= (monster.y+monster.h/2.0)-(monster2.y-monster2.h/2.0/4.0)
                  monster.vy = 0.0
              for monster2 in enemies:
                if aabb(monster.x-monster.w/2.0,monster.y-monster.h/2.0+monster.vy,monster.w,monster.h,monster2.x-monster2.w/2.0,monster2.y-monster2.h/2.0,monster2.w,monster2.h) and monster2.tangible:
              #if monster.x >= monster2.x: monster.x -= (monster.x-monster.w/2.0)-(monster2.x+monster2.w/2.0/4.0)
              #else: monster.x -= (monster.x+monster.w/2.0)-(monster2.x-monster2.w/2.0/4.0)
                  monster.vy = 0.0
              for solid in solids:
                if aabb(monster.x-monster.w/2.0,monster.y-monster.h/2.0+monster.vy,monster.w,monster.h,solid.x-solid.w/2.0,solid.y-solid.h/2.0,solid.w,solid.h) and monster.tangible:
                  if monster.y >= solid.y: monster.y -= (monster.y-monster.h/2.0)-(solid.y+solid.h/2.0)
                  else: monster.y -= (monster.y+monster.h/2.0)-(solid.y-solid.h/2.0)
              monster.y += monster.vy
            #  of EnemyAttack:

      for enemy in enemies.mitems:
        enemy.cooldown -= 1.0
        if enemy.cooldown < 0.0: enemy.cooldown = 0.0
        var distance = sqrt((monsters[0].x-enemy.x).pow(2)+(monsters[0].y-enemy.y).pow(2))
        var target = 0
        for (id,monster) in monsters.pairs:
          if sqrt((monster.x-enemy.x).pow(2)+(monster.y-enemy.y).pow(2)) < distance:
            distance = sqrt((monster.x-enemy.x).pow(2)+(monster.y-enemy.y).pow(2))
            target = id
        let angle = arctan2(
            monsters[target].y - enemy.y,
            monsters[target].x - enemy.x
          )
        enemy.vx = angle.cos()*enemy.spd
        if enemy.enemy_type == Helpless or enemy.enemy_type == Mage or enemy.enemy_type == TeamArcher or enemy.enemy_type == TeamSpellcaster:
          enemy.vx *= -1.0
          if (enemy.enemy_type == Mage or enemy.enemy_type == TeamSpellcaster or enemy.enemy_type == TeamArcher) and enemy.cooldown > 0.0: 
            enemy.vx = 0.0
            enemy.vy = 0.0
            continue
        if enemy.vx != 0.0:
          for monster in monsters:
            if aabb(monster.x-monster.w/2.0 + enemy.vx,monster.y-monster.h/2.0,monster.w,monster.h,enemy.x-enemy.w/2.0,enemy.y-enemy.h/2.0,enemy.w,enemy.h):
          #if enemy.x >= monster.x: enemy.x -= (enemy.x-enemy.w/2.0)-(monster.x+monster.w/2.0)
          #else: enemy.x -= (enemy.x+enemy.w/2.0)-(monster.x-monster.w/2.0)
              enemy.vx = 0.0
          enemy.x += enemy.vx
          for solid in solids:
            if aabb(solid.x-solid.w/2.0,solid.y-solid.h/2.0,solid.w,solid.h,enemy.x-enemy.w/2.0,enemy.y-enemy.h/2.0,enemy.w,enemy.h) and enemy.tangible:
              if enemy.x >= solid.x: enemy.x -= (enemy.x-enemy.w/2.0)-(solid.x+solid.w/2.0)
              else: enemy.x -= (enemy.x+enemy.w/2.0)-(solid.x-solid.w/2.0)
        enemy.vy = angle.sin()*enemy.spd
        if enemy.enemy_type == Helpless or enemy.enemy_type == Mage or enemy.enemy_type == TeamArcher or enemy.enemy_type == TeamSpellcaster:
          enemy.vy *= -1.0
        if enemy.vy != 0.0:
          for monster in monsters:
            if aabb(monster.x-monster.w/2.0,monster.y-monster.h/2.0+enemy.vy,monster.w,monster.h,enemy.x-enemy.w/2.0,enemy.y-enemy.h/2.0,enemy.w,enemy.h):
          #if enemy.y >= monster.y: enemy.y -= (enemy.y-enemy.h/2.0)-(monster.y+monster.h/2.0)
          #else: enemy.y -= (enemy.y+enemy.h/2.0)-(monster.y-monster.h/2.0)
              enemy.vy = 0.0
          enemy.y += enemy.vy
          for solid in solids:
            if aabb(enemy.x-enemy.w/2.0,enemy.y-enemy.h/2.0,enemy.w,enemy.h,solid.x-solid.w/2.0,solid.y-solid.h/2.0,solid.w,solid.h) and enemy.tangible:
              if enemy.y >= solid.y: enemy.y -= (enemy.y-enemy.h/2.0)-(solid.y+solid.h/2.0)
              else: enemy.y -= (enemy.y+enemy.h/2.0)-(solid.y-solid.h/2.0)

      if getMouseWheelMoveV().y > 0.0: current_choice += 1
      elif getMouseWheelMoveV().y < 0.0: current_choice -= 1
      if current_choice > 2: current_choice = 0
      if current_choice < 0: current_choice = 2

      if isMouseButtonDown(Left):
        let ray = getMouseRay(getMousePosition(), camera3);
        for monster in monsters.mitems:
          let collision = getRayCollisionBox(ray, BoundingBox(min:Vector3(x:monster.x/32.0 - monster.w/2.0/32.0, y: -monster.d/2.0/32.0, z:monster.y/32.0 - monster.h/2.0/32.0),max:Vector3(x:monster.x/32.0 + monster.w/2.0/32.0, y:1.0+monster.d/2.0/32.0, z:monster.y/32.0 + monster.h/2.0/32.0)));
          if collision.hit: #if aabb(getMouseX().float+monsters[0].x,getMouseY().float+monsters[0].y,1.0,1.0,monster.x-monster.w/2.0+screenWidth.float/2.0-16.0,monster.y-monster.h/2.0+screenHeight.float/2.0-16.0,monster.w,monster.h):
            if not monster.loyal: monster.loyal = true
            if monster.loyal: monster.target = current_choice.Target
      #[if isMouseButtonPressed(Right):
        for monster in monsters.mitems:
          if aabb(getMouseX().float+monsters[0].x,getMouseY().float+monsters[0].y,1.0,1.0,monster.x-monster.w/2.0+screenWidth.float/2.0-16.0,monster.y-monster.h/2.0+screenHeight.float/2.0-16.0,monster.w,monster.h):
            if not monster.lead: monsters.]#

      for monster in monsters.mitems:
        for area in area_damage.items:
          if aabb(monster.x-monster.w/2.0 + monster.vx,monster.y-monster.h/2.0,monster.w,monster.h,area.x-area.w/2.0,area.y-area.h/2.0,area.w,area.h) and area.time > 0.0:
            case area.damage_type:
            of Fire: monster.hp -= 40.0
            of Thunder: monster.hp -= 100.0
            of Inferno: monster.hp -= 80.0
            of Poison: 
              if area.time mod 60.0 == 0.0:
                monster.hp -= 10.0
            of Ice: continue
        if enemies.len > 0:
          var distance = sqrt((enemies[0].x-monster.x).pow(2)+(enemies[0].y-monster.y).pow(2))
          var target = 0
          for (id,enemy) in enemies.pairs:
            if sqrt((enemy.x-monster.x).pow(2)+(enemy.y-monster.y).pow(2)) < distance:
              distance = sqrt((enemy.x-monster.x).pow(2)+(enemy.y-monster.y).pow(2))
              target = id
          if monster.loyal:
            if (enemies[target].enemy_type == Mage or enemies[target].enemy_type == TeamSpellcaster) and enemies[target].cooldown <= 0.0: continue
            if monster.monster_type == Standard:
              if aabb(enemies[target].x-enemies[target].w/2.0,enemies[target].y-enemies[target].h/2.0,enemies[target].w,enemies[target].h,monster.x-monster.w,monster.y-monster.h,monster.w*2.0,monster.h*2.0) and monster.cooldown == 0:
                enemies[target].hp -= 20.0
                monster.cooldown = 60.0
            if monster.monster_type == Knight:
              if aabb(enemies[target].x-enemies[target].w/2.0,enemies[target].y-enemies[target].h/2.0,enemies[target].w,enemies[target].h,monster.x-monster.w,monster.y-monster.h,monster.w*2.0,monster.h*2.0) and monster.cooldown == 0:
                enemies[target].hp -= 50.0
                monster.cooldown = 120.0

      for enemy in enemies.mitems:

        if enemy.enemy_type == Beginner or enemy.enemy_type == Experienced or enemy.enemy_type == TeamTank:
          var distance = sqrt((monsters[0].x-enemy.x).pow(2)+(monsters[0].y-enemy.y).pow(2))
          var target = 0
          for (id,monster) in monsters.pairs:
            if sqrt((monster.x-enemy.x).pow(2)+(monster.y-enemy.y).pow(2)) < distance:
              distance = sqrt((monster.x-enemy.x).pow(2)+(monster.y-enemy.y).pow(2))
              target = id
          if aabb(monsters[target].x-monsters[target].w/2.0,monsters[target].y-monsters[target].h/2.0,monsters[target].w,monsters[target].h,enemy.x-enemy.w*3.0/4.0,enemy.y-enemy.h*3.0/4.0,enemy.w*1.75,enemy.h*1.75) and enemy.cooldown == 0: 
            case enemy.enemy_type:
            of Beginner:
              monsters[target].hp -= 25.0
              enemy.cooldown = 60.0
            of Experienced:
              monsters[target].hp -= 25.0
              enemy.cooldown = 50.0
            else:
              monsters[target].hp -= 60.0
              enemy.cooldown = 180.0
        if enemy.enemy_type == TeamMelee:
          var hit = false
          var distance = sqrt((monsters[0].x-enemy.x).pow(2)+(monsters[0].y-enemy.y).pow(2))
          var target = 0
          for (id,monster) in monsters.pairs:
            if sqrt((monster.x-enemy.x).pow(2)+(monster.y-enemy.y).pow(2)) < distance:
              distance = sqrt((monster.x-enemy.x).pow(2)+(monster.y-enemy.y).pow(2))
              target = id
          for monster in monsters.mitems:
            if aabb(monster.x-monster.w/2.0,monster.y-monster.h/2.0,monster.w,monster.h,enemy.x-enemy.w*3.0/4.0,enemy.y-enemy.h*3.0/4.0,enemy.w*1.75,enemy.h*1.75) and enemy.cooldown == 0: 
              monster.hp -= 20.0
              hit = true
          if hit: enemy.cooldown = 90.0
        if enemy.enemy_type == Mage or enemy.enemy_type == TeamSpellcaster:
          var distance = sqrt((monsters[0].x-enemy.x).pow(2)+(monsters[0].y-enemy.y).pow(2))
          var target = 0
          for (id,monster) in monsters.pairs:
            if sqrt((monster.x-enemy.x).pow(2)+(monster.y-enemy.y).pow(2)) < distance:
              distance = sqrt((monster.x-enemy.x).pow(2)+(monster.y-enemy.y).pow(2))
              target = id
          let angle = arctan2(
            monsters[target].y - enemy.y,
            monsters[target].x - enemy.x
          )
          if enemy.cooldown == 0 and distance > 384.0:
            bullets.add(Bullet(x:enemy.x,y:enemy.y,w:32.0,h:32.0,d:32.0,vx:angle.cos()*6.0,vy:angle.sin()*6.0,damage_type:FireBall,lifetime:120.0))
            enemy.cooldown = 140.0
        if enemy.enemy_type == TeamArcher:
          var distance = sqrt((monsters[0].x-enemy.x).pow(2)+(monsters[0].y-enemy.y).pow(2))
          var target = 0
          for (id,monster) in monsters.pairs:
            if sqrt((monster.x-enemy.x).pow(2)+(monster.y-enemy.y).pow(2)) < distance:
              distance = sqrt((monster.x-enemy.x).pow(2)+(monster.y-enemy.y).pow(2))
              target = id
          let angle = arctan2(
            monsters[target].y - enemy.y,
            monsters[target].x - enemy.x
          )
          if enemy.cooldown == 0:
            bullets.add(Bullet(x:enemy.x,y:enemy.y,w:8.0,h:8.0,d:8.0,vx:angle.cos()*12.0,vy:angle.sin()*12.0,damage_type:Arrow,lifetime:120.0))
            enemy.cooldown = 60.0

      var removed = 0
      if bullets.len > 0:
        for id in 0..bullets.len-1:
          var bullet = bullets[id-removed]
          bullet.x += bullet.vx
          bullet.y += bullet.vy
          bullet.lifetime -= 1.0
          bullets[id-removed] = bullet
          for monster in monsters.mitems:
            if aabb(bullet.x-bullet.w/2.0,bullet.y-bullet.h/2.0,bullet.w,bullet.h,monster.x-monster.w/2.0,monster.y-monster.h/2.0,monster.w,monster.h) and bullet.damage_type != BigFire:
              bullets.delete(id-removed)
              removed += 1
              case bullet.damage_type:
              of FireBall: area_damage.add(AreaDamage(x:bullet.x,y:bullet.y,w:128.0,h:128.0,damage_type:Fire,time:2.0,anim_time:120.0))
              of BigFire: area_damage.add(AreaDamage(x:bullet.x,y:bullet.y,w:128.0,h:128.0,damage_type:Inferno,time:2.0,anim_time:300.0))
              of IceBall: area_damage.add(AreaDamage(x:bullet.x,y:bullet.y,w:128.0,h:128.0,damage_type:Ice,time:120.0,anim_time:120.0))
              of PoisonBall: area_damage.add(AreaDamage(x:bullet.x,y:bullet.y,w:128.0,h:128.0,damage_type:Poison,time:300.0,anim_time:300.0))
              of Arrow: monster.hp -= 25.0
              break
          for solid in solids.mitems:
            if aabb(bullet.x-bullet.w/2.0,bullet.y-bullet.h/2.0,bullet.w,bullet.h,solid.x-solid.w/2.0,solid.y-solid.h/2.0,solid.w,solid.h) and bullet.damage_type != BigFire:
              bullets.delete(id-removed)
              removed += 1
              case bullet.damage_type:
              of FireBall: area_damage.add(AreaDamage(x:bullet.x,y:bullet.y,w:128.0,h:128.0,damage_type:Fire,time:2.0,anim_time:120.0))
              of BigFire: area_damage.add(AreaDamage(x:bullet.x,y:bullet.y,w:128.0,h:128.0,damage_type:Inferno,time:2.0,anim_time:300.0))
              of IceBall: area_damage.add(AreaDamage(x:bullet.x,y:bullet.y,w:128.0,h:128.0,damage_type:Ice,time:120.0,anim_time:120.0))
              of PoisonBall: area_damage.add(AreaDamage(x:bullet.x,y:bullet.y,w:128.0,h:128.0,damage_type:Poison,time:300.0,anim_time:300.0))
              of Arrow: break
              break
          if bullet.lifetime <= 0:
            bullets.delete(id-removed)
            removed += 1
            case bullet.damage_type:
            of FireBall: area_damage.add(AreaDamage(x:bullet.x,y:bullet.y,w:128.0,h:128.0,damage_type:Fire,time:2.0,anim_time:120.0))
            of BigFire: area_damage.add(AreaDamage(x:bullet.x,y:bullet.y,w:128.0,h:128.0,damage_type:Inferno,time:2.0,anim_time:300.0))
            of IceBall: area_damage.add(AreaDamage(x:bullet.x,y:bullet.y,w:128.0,h:128.0,damage_type:Ice,time:120.0,anim_time:120.0))
            of PoisonBall: area_damage.add(AreaDamage(x:bullet.x,y:bullet.y,w:128.0,h:128.0,damage_type:Poison,time:300.0,anim_time:300.0))
            of Arrow: continue

      removed = 0
      if area_damage.len > 0:
        for id in 0..area_damage.len-1:
          var area = area_damage[id-removed]
          area.time -= 1.0
          area.anim_time -= 1.0
          area_damage[id-removed] = area
          if area.anim_time <= 0:
            area_damage.delete(id-removed)
            removed += 1
            #[case bullet.damage_type:
            of FireBall: area_damage.add(AreaDamage(x:bullet.x,y:bullet.y,w:128.0,h:128.0,damage_type:Fire,time:0.0,anim_time:2.0))
            of IceBall: area_damage.add(AreaDamage(x:bullet.x,y:bullet.y,h:128.0,damage_type:Ice,time:2.0,anim_time:2.0))
            of PoisonBall: area_damage.add(AreaDamage(x:bullet.x,y:bullet.y,h:128.0,damage_type:Poison,time:4.0,anim_time:4.0))
            of Arrow: continue]#

    #[if not monsters[0].lead:
      for monster in monsters:
        if monster.lead:
          monster.]#

      camera.zoom = 1.0
      camera.rotation = 0.0
      camera.target = Vector2(x:0.0,y:0.0)
      camera.offset = Vector2(x: -monsters[0].x+screenWidth.float/2.0-16.0,y: -monsters[0].y+screenHeight.float/2.0-16.0)
      camera3.position = Vector3( x:30+monsters[0].x/32.0, y:40.5, z:30+monsters[0].y/32.0)
      camera3.target = Vector3( x: monsters[0].x/32.0, y:0.5, z: monsters[0].y/32.0 ); 

      removed = 0
      for id in 0..enemies.len-1:
        if enemies[id-removed].hp <= 0.0:
          enemies.delete(id-removed)
          removed += 1
      if enemies.len == 0:
        level += 1
        if monsters.len == 0: monsters.add(Monster(x:0.0,y:0.0,w:32.0,h:32.0, d: 32.0, weapon: None, monster_type: Standard, lead: true, target: None, hp: 25.0, max_hp: 25.0, tangible: false, loyal: true,max_cooldown: 60.0)) 
        monsters[0].x = 0.0
        monsters[0].y = 0.0
        case level:
        of 0: echo " "
        of 1: 
          enemies.add(Enemy(x:0.0,y:256.0,w:32.0,h:32.0,d:64.0, enemy_type: Helpless, hp: 100.0, max_hp: 100.0, tangible: true, spd: 3.0))
          #enemies.add(Enemy(x: 0.0,y:256.0,w:32.0,h:32.0,d:48.0, enemy_type: WizardRed, hp: 300.0, max_hp: 300.0, tangible: true, spd: 4.0))
        of 2:
          enemies.add(Enemy(x:0.0,y:256.0,w:32.0,h:32.0,d:64.0, enemy_type: Beginner, hp: 200.0, max_hp: 200.0, tangible: true, spd: 3.0,max_cooldown: 60.0))
          for n in 0..7:
            monsters.add(Monster(x:rand(-960..960).float,y:rand(-960..960).float,w:32.0,h:32.0,d:32.0, weapon: None, monster_type: Standard, lead: false, target: None, hp: 25.0, max_hp: 25.0, tangible: true, loyal: false,max_cooldown: 60.0))
        of 3:
          enemies.add(Enemy(x:0.0,y:520.0,w:32.0,h:32.0,d:64.0, enemy_type: Beginner, hp: 200.0, max_hp: 200.0, tangible: true, spd: 3.0,max_cooldown: 60.0))
          enemies.add(Enemy(x:0.0,y:256.0,w:32.0,h:32.0,d:64.0, enemy_type: Experienced, hp: 300.0, max_hp: 300.0, tangible: true, spd: 4.0,max_cooldown: 50.0))
          for n in 0..14:
            monsters.add(Monster(x:rand(-960..960).float,y:rand(-960..960).float,w:32.0,h:32.0,d:32.0, weapon: None, monster_type: Standard, lead: false, target: None, hp: 25.0, max_hp: 25.0, tangible: true, loyal: false,max_cooldown: 60.0))
        of 4:
          monsters[0] = Monster(x:0.0,y:0.0,w:32.0,h:32.0,d:64.0, weapon: None, monster_type: Standard, lead: true, target: None, hp: 25.0, tangible: false, loyal: true,max_cooldown: 60.0)
          enemies.add(Enemy(x:0.0,y:256.0,w:32.0,h:32.0,d:64.0, enemy_type: Mage, hp: 200.0, max_hp: 200.0, tangible: true, spd: 4.0,max_cooldown: 140.0))
          monsters.add(Monster(x:rand(-960..960).float,y:rand(-960..960).float,w:32.0,h:32.0,d:32.0, weapon: None, monster_type: Knight, lead: false, target: None, hp: 75.0, max_hp: 75.0, tangible: true, loyal: false,max_cooldown: 120.0))
        of 5:
          enemies.add(Enemy(x: -192.0,y:256.0,w:32.0,h:32.0,d:64.0, enemy_type: TeamMelee, hp: 350.0, max_hp: 350.0, tangible: true, spd: 4.0,max_cooldown: 90.0))
          enemies.add(Enemy(x: -64.0,y:256.0,w:32.0,h:32.0,d:64.0, enemy_type: TeamArcher, hp: 200.0, max_hp: 200.0, tangible: true, spd: 3.0,max_cooldown: 60.0))
          enemies.add(Enemy(x:64.0,y:256.0,w:32.0,h:32.0,d:64.0, enemy_type: TeamSpellcaster, hp: 75.0, max_hp: 75.0, tangible: true, spd: 4.0,max_cooldown: 140.0))
          enemies.add(Enemy(x:192.0,y:256.0,w:64.0,h:64.0,d:64.0, enemy_type: TeamTank, hp: 700.0, max_hp: 700.0, tangible: true, spd: 4.0,max_cooldown: 180.0))
          for n in 0..14:
            monsters.add(Monster(x:rand(-960..960).float,y:rand(-960..960).float,w:32.0,h:32.0,d:32.0, weapon: None, monster_type: Standard, lead: false, target: None, hp: 25.0, max_hp: 25.0, tangible: true, loyal: false,max_cooldown: 60.0))
          for n in 0..3:
            monsters.add(Monster(x:rand(-960..960).float,y:rand(-960..960).float,w:32.0,h:32.0,d:32.0, weapon: None, monster_type: Knight, lead: false, target: None, hp: 75.0, max_hp: 75.0, tangible: true, loyal: false,max_cooldown: 120.0))
          for n in 0..3:
            monsters.add(Monster(x:rand(-960..960).float,y:rand(-960..960).float,w:32.0,h:32.0,d:32.0, weapon: None, monster_type: Golem, lead: false, target: None, hp: 125.0, max_hp: 125.0, tangible: true, loyal: false,max_cooldown: 120.0))
        #[of 7:
          enemies.add(Enemy(x: -64.0,y:256.0,w:32.0,h:32.0,d:32.0, enemy_type: WizardBlue, hp: 300.0, max_hp: 300.0, tangible: true, spd: 4.0))
          enemies.add(Enemy(x: 0.0,y:256.0,w:32.0,h:32.0,d:48.0, enemy_type: WizardRed, hp: 300.0, max_hp: 300.0, tangible: true, spd: 4.0))
          enemies.add(Enemy(x:64.0,y:256.0,w:32.0,h:32.0,d:64.0, enemy_type: WizardYellow, hp: 300.0, max_hp: 300.0, tangible: true, spd: 4.0))]#
        else: echo " "
        #break

      removed = 0
      for id in 0..monsters.len-1:
        if monsters[id-removed].hp <= 0.0:
          let mon = monsters[id-removed]
          monsters.delete(id-removed)
          if monsters.len == 0: 
            state = GameOver
            break
          if mon.lead: 
            monsters[0].lead = true
            monsters[0].loyal = true
          removed += 1

    # Draw
    # ----------------------------------------------------------------------------------

    beginDrawing()

    beginTextureMode(map_screen)

    clearBackground(Black)

    beginMode2D(camera)

    for area in area_damage:
      case area.damage_type:
      of Fire: drawRectangle(Vector2(x:area.x-area.w/2.0,y:area.y-area.h/2.0), Vector2(x:area.w, y:area.h), Gold)
      of Ice: drawRectangle(Vector2(x:area.x-area.w/2.0,y:area.y-area.h/2.0), Vector2(x:area.w, y:area.h), SkyBlue)
      of Poison: drawRectangle(Vector2(x:area.x-area.w/2.0,y:area.y-area.h/2.0), Vector2(x:area.w, y:area.h), Lime)
      of Inferno: drawRectangle(Vector2(x:area.x-area.w/2.0,y:area.y-area.h/2.0), Vector2(x:area.w, y:area.h), Orange)
      of Thunder: continue
    for monster in monsters.items:
      case monster.monster_type:
      of Standard: drawRectangle(Vector2(x:monster.x-monster.w/2.0,y:monster.y-monster.h/2.0), Vector2(x:monster.w, y:monster.h), Red)
      of Knight: drawRectangle(Vector2(x:monster.x-monster.w/2.0,y:monster.y-monster.h/2.0), Vector2(x:monster.w, y:monster.h), LightGray)
      of Swordfish: drawRectangle(Vector2(x:monster.x-monster.w/2.0,y:monster.y-monster.h/2.0), Vector2(x:monster.w, y:monster.h), Blue)
      of Golem: drawRectangle(Vector2(x:monster.x-monster.w/2.0,y:monster.y-monster.h/2.0), Vector2(x:monster.w, y:monster.h), Gray)
      if monster.hp < monster.max_hp: drawRectangle(Vector2(x:monster.x-monster.w/2.0,y:monster.y-16.0-monster.h/2.0),Vector2(x:(monster.hp/monster.max_hp)*monster.w,y:8.0),Green)
    for enemy in enemies.items:
      drawRectangle(Vector2(x:enemy.x-enemy.w/2.0,y:enemy.y-enemy.h/2.0), Vector2(x:enemy.w, y:enemy.h), Green)
      if enemy.hp < enemy.max_hp: drawRectangle(Vector2(x:enemy.x-enemy.w/2.0,y:enemy.y-16.0-enemy.h/2.0),Vector2(x:(enemy.hp/enemy.max_hp)*enemy.w,y:8.0),Green)
    for bullet in bullets.items:
      case bullet.damage_type:
      of FireBall: drawRectangle(Vector2(x:bullet.x-bullet.w/2.0,y:bullet.y-bullet.h/2.0), Vector2(x:bullet.w, y:bullet.h), Gold)
      of BigFire: drawRectangle(Vector2(x:bullet.x-bullet.w/2.0,y:bullet.y-bullet.h/2.0), Vector2(x:bullet.w, y:bullet.h), Gold)
      of IceBall: drawRectangle(Vector2(x:bullet.x-bullet.w/2.0,y:bullet.y-bullet.h/2.0), Vector2(x:bullet.w, y:bullet.h), SkyBlue)
      of PoisonBall: drawRectangle(Vector2(x:bullet.x-bullet.w/2.0,y:bullet.y-bullet.h/2.0), Vector2(x:bullet.w, y:bullet.h), Lime)
      of Arrow: drawRectangle(Vector2(x:bullet.x-bullet.w/2.0,y:bullet.y-bullet.h/2.0), Vector2(x:bullet.w, y:bullet.h), White)
    for solid in solids.items:
      drawRectangle(Vector2(x:solid.x-solid.w/2.0,y:solid.y-solid.h/2.0), Vector2(x:solid.w, y:solid.h), White)

    #drawText("Welcome to the third dimension!", 10, 40, 20, DarkGray)

    endMode2D()

    endTextureMode()

    clearBackground(DarkPurple)

    beginMode3D(camera3)

    #drawCube(Vector3(x:0.0,y:0.0,z:0.0),2.0,2.0,2.0,Red)
    for area in area_damage:
      case area.damage_type:
      of Fire: drawCube(Vector3(x:area.x,z:area.y)/32.0, Vector3(x:area.w, z:area.h)/32.0, Gold)
      of Inferno: drawCube(Vector3(x:area.x,z:area.y)/32.0, Vector3(x:area.w, y:500.0, z:area.h)/32.0, Orange)
      of Ice: drawCube(Vector3(x:area.x,z:area.y)/32.0, Vector3(x:area.w, z:area.h)/32.0, SkyBlue)
      of Poison: drawCube(Vector3(x:area.x,z:area.y)/32.0, Vector3(x:area.w, z:area.h)/32.0, Lime)
      of Thunder: drawCube(Vector3(x:area.x,z:area.y)/32.0, Vector3(x:area.w, y:500.0, z:area.h)/32.0, White)
    for monster in monsters.items:
      case monster.monster_type:
      of Standard: 
        drawModel(plebian,Vector3(x:monster.x/32.0,y:0.0,z:monster.y/32.0),0.25,White)
        #drawCube(Vector3(x:monster.x,y: monster.d/32.0+1.0,z:monster.y)/32.0, Vector3(x:monster.w, y:monster.h, z:monster.w)/32.0, Red)
      of Knight: 
        drawModel(plebian,Vector3(x:monster.x/32.0,y:0.0,z:monster.y/32.0),0.5,Gray)
        #drawCube(Vector3(x:monster.x,y:monster.d/32.0,z:monster.y)/32.0, Vector3(x:monster.w, y:monster.h, z:monster.w)/32.0, LightGray)
      of Swordfish: drawCube(Vector3(x:monster.x,y:0.0,z:monster.y)/32.0, Vector3(x:monster.w, y:monster.h, z:monster.w)/32.0, Blue)
      of Golem: 
        drawModel(golem,Vector3(x:monster.x/32.0,y:0.0,z:monster.y/32.0),0.5,White)
        #drawCube(Vector3(x:monster.x,y:0.0,z:monster.y)/32.0, Vector3(x:monster.w, y:monster.h, z:monster.w)/32.0, Gray)
      #let cubeScreenPosition = getWorldToScreen(Vector3(x:monster.x/32.0,y:0.0,z:monster.y/32.0), camera3);
      #if monster.hp < monster.max_hp: drawCube(Vector2(x:monster.x-monster.w/2.0,y:monster.y-16.0-monster.h/2.0),Vector2(x:(monster.hp/monster.max_hp)*monster.w,y:8.0),Green)
    for enemy in enemies.items:
      case enemy.enemy_type:
      of Mage: drawModel(mage,Vector3(x:enemy.x/32.0,y:0.0,z:enemy.y/32.0),1.0/2.0,White)
      of Helpless: drawModel(helpless,Vector3(x:enemy.x/32.0,y:0.0,z:enemy.y/32.0),1.0/2.0,White)
      of Beginner: drawModel(beginner,Vector3(x:enemy.x/32.0,y:0.0,z:enemy.y/32.0),1.0/2.0,White)
      of Experienced: drawModel(experienced,Vector3(x:enemy.x/32.0,y:0.0,z:enemy.y/32.0),1.0/2.0,White)
      of TeamTank: drawModel(team_tank,Vector3(x:enemy.x/32.0,y:0.0,z:enemy.y/32.0),1.0/2.0,White)
      of TeamArcher: drawModel(team_archer,Vector3(x:enemy.x/32.0,y:0.0,z:enemy.y/32.0),1.0/2.0,White)
      of TeamSpellcaster: drawModel(team_spellcaster,Vector3(x:enemy.x/32.0,y:0.0,z:enemy.y/32.0),1.0/2.0,White)
      of TeamMelee: drawModel(team_melee,Vector3(x:enemy.x/32.0,y:0.0,z:enemy.y/32.0),1.0/2.0,White)
      of WizardBlue: drawModel(team_melee,Vector3(x:enemy.x/32.0,y:0.0,z:enemy.y/32.0),1.0/2.0,White)
      else: drawCube(Vector3(x:enemy.x,y:0.0,z:enemy.y)/32.0, Vector3(x:enemy.w, y:enemy.d, z:enemy.h)/32.0, Green)
      #drawCube(Vector3(x:enemy.x,y:enemy.d/32.0,z:enemy.y)/32.0, Vector3(x:enemy.w, y:enemy.d, z:enemy.h)/32.0, Green)
      #if enemy.hp < enemy.max_hp: drawCube(Vector2(x:enemy.x-enemy.w/2.0,y:enemy.y-16.0-enemy.h/2.0),Vector2(x:(enemy.hp/enemy.max_hp)*enemy.w,y:8.0),Green)
    for bullet in bullets.items:
      case bullet.damage_type:
      of FireBall: drawCube(Vector3(x:bullet.x,y:0.0,z:bullet.y)/32.0, Vector3(x:bullet.w, y:bullet.d, z:bullet.h)/32.0, Gold)
      of BigFire: drawCube(Vector3(x:bullet.x,y:arctan2(bullet.x,bullet.y).sin(),z:bullet.y)/32.0, Vector3(x:bullet.w, y:bullet.d, z:bullet.h)/32.0, Red)
      of IceBall: drawCube(Vector3(x:bullet.x,y:0.0,z:bullet.y)/32.0, Vector3(x:bullet.w, y:bullet.d,z:bullet.h)/32.0, SkyBlue)
      of PoisonBall: drawCube(Vector3(x:bullet.x,y:0.0,z:bullet.y)/32.0, Vector3(x:bullet.w, y:bullet.d, z:bullet.h)/32.0, Lime)
      of Arrow: drawCube(Vector3(x:bullet.x,y:0.0,z:bullet.y)/32.0, Vector3(x:bullet.w, y:bullet.d, z:bullet.h)/32.0, White)
    for solid in solids.items:
      drawCube(Vector3(x:solid.x,y:solid.d/2.0,z:solid.y)/32.0, Vector3(x:solid.w, y:solid.d, z:solid.h)/32.0, Black)

    #drawCube(Vector3(x:0.0,y: -500.0, z: 0.0), Vector3(x:1000.0,y:1000.0,z:1000.0),Purple)

    #drawGrid(100,10.0)

    endMode3D()

    case state:
    of Gameplay: 
      drawText("Monsters left: " & $monsters.len, 10, 20, 20, Red)
      drawText("The monsters will follow: " & $current_choice.Target, 10, 40, 20, Magenta)
      case level:
      of 1: 
        drawText("Goal: Chase down the helpless wanderer!", 10, 60, 20, Green)
        drawText("Hint: Move with WASD. The monster will attack automatically!", 10, 80, 20, SkyBlue)
      of 2: 
        drawText("Goal: Overwhelm the beginner warrior!", 10, 60, 20, Green)
        drawText("Hint: Click on a monster to have it move! Use the scrollwheel to choose its target.", 10, 80, 20, SkyBlue)
      of 3: 
        drawText("Goal: Defeat the experienced warriors!", 10, 60, 20, Green)
        #drawText("Hint: Click on a monster to have it move! Use the scrollwheel to choose its target.", 10, 80, 20, Blue)
      of 4: 
        drawText("Goal: Outsmart the mage!", 10, 60, 20, Green)
        drawText("Hint: The mage can't be damaged if they're not cooling down!", 10, 80, 20, SkyBlue)
      of 5: 
        drawText("Goal: Take The Party down!", 10, 60, 20, Green)
        drawText("Hint: Good luck!", 10, 80, 20, SkyBlue)
      else: 
        drawText("You beat the game! Congratulations!", 10, 60, 20, Green)
      for monster in monsters.items:
        let cubeScreenPosition = getWorldToScreen(Vector3(x:monster.x/32.0,y:2.0,z:monster.y/32.0), camera3);
        if monster.hp < monster.max_hp: drawRectangle(Vector2(x:cubeScreenPosition.x-monster.w/2.0,y:cubeScreenPosition.y-8.0),Vector2(x:(monster.hp/monster.max_hp)*monster.w,y: 8.0),Green)
        if monster.cooldown > 0.0: drawRectangle(Vector2(x:cubeScreenPosition.x-monster.w/2.0,y:cubeScreenPosition.y),Vector2(x:((monster.max_cooldown-monster.cooldown)/monster.max_cooldown)*monster.w,y:8.0),SkyBlue)
      for enemy in enemies.items:
        let cubeScreenPosition = getWorldToScreen(Vector3(x:enemy.x/32.0,y:2.0,z:enemy.y/32.0), camera3);
        if enemy.hp < enemy.max_hp: drawRectangle(Vector2(x:cubeScreenPosition.x-enemy.w/2.0,y:cubeScreenPosition.y-8.0),Vector2(x:(enemy.hp/enemy.max_hp)*enemy.w,y: 8.0),Green)
        if enemy.cooldown > 0.0: drawRectangle(Vector2(x:cubeScreenPosition.x-enemy.w/2.0,y:cubeScreenPosition.y),Vector2(x:((enemy.max_cooldown-enemy.cooldown)/enemy.max_cooldown)*enemy.w,y:8.0),SkyBlue)

      #drawRectangle(Vector2(x:768.0,y:768.0),Vector2(x:256.0,y:256.0),Black)
      #drawTexture(map_screen.texture,Vector2(x:1024.0,y:1024.0),0.0,-0.25,White)
      drawTexture(map_screen.texture,Rectangle(x:0.0,y:0.0,width:1024.0,height: -1024.0),Rectangle(x:768.0,y:768.0,width:256.0,height: 256.0),Vector2(),0.0,White)
      #drawTextu
    of GameOver: drawText("GAME OVER", 408, 512, 80, Red)
    else: echo " "

    drawFPS(1000, 10)

    endDrawing()
    # ----------------------------------------------------------------------------------

    # De-Initialization
    # --------------------------------------------------------------------------------------
  closeWindow()       # Close window and OpenGL context
    #--------------------------------------------------------------------------------------]#


main()