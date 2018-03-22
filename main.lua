local split = require("lib/split")
local gamera = require("lib/gamera")
local list = require("lib/list")
local presets = require("lib/nbody_presets")
local planets = require("lib/planets")


BODIES = {} -- list of bodies
DIM=3

-- love version is laid out like:
--   major, minor, revision, codename = love.getVersion( )
LOVE_MAJ=nil
LOVE_MIN=nil
LOVE_REV=nil
LOVE_CODENAME=nil


-- drawing options
DRAW_OUTLINE=true
DRAW_CANVAS=false
DRAW_FORCES=false
DRAW_BODY_INFO = 0

-- trajectory
TILE_CANVAS = {}
TILE_LAST_USED = {}
TILE_SIZE = 1000
MAX_TILES = 500
TRAJECTORY_SIZE=10000
TRAJECTORY_MINI=1000

-- speed stuff
H=0.001 -- step size
NOW = 0 -- current tick
DT = 0 -- displayed DT
SPEED=10
PRINT_EVERY=1
USE_ADAPTIVE_INTEGRATOR=false

FB = 0 -- focused body, 0 means centered

-- translation, rotation and scale
TX=0
TY=0
RX=0
RY=0
RZ=0
SCALE=1
RESET_FUNC=presets.main

SCREENSHOT = false

-- helpers

function clone(x)
  return { x[1], x[2], x[3] }
end

function tableLength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

-- Body Class
Body = {}
function Body:new(x, y, z, m)
  o = {}
  setmetatable(o, self)
  self.__index = self
  o.name = nil

  o.x = {x,y,z} -- location
  o.dx = {x,y,z} -- displayed location after any rotations

  -- this is our state
  o.v = {0,0,0} -- velocity
  o.a = {0,0,0} -- acceleration
  o.pa = { 0, 0, 0} -- prev accel
  -- end state

  o.color = { math.random(1, 255), math.random(2, 255), math.random(1, 255) }

  o.collision = 0
	o.stopped = false

  o.m = m or 1
  o.direction = nil
  o.r = 0

  o:adjust()

  return o
end

function Body:save_state()
  local st = {}
  st.a = clone(self.a)
  st.v = clone(self.v)
  st.x = clone(self.x)

  return st

end

function Body:restore_state(st)
  self.a = clone(st.a)
  self.v = clone(st.v)
  self.x = clone(st.x)
end

function Body:adjust()
  self.dr = math.log(self.r)
end

local cos = math.cos
local sin = math.sin
local FC = nil
local zero_xyz = {0,0,0}
function rotate_coords(x)
  local ox = zero_xyz
  if FC then
    ox = FC
  end

  nx = {x[1] - ox[1], x[2] - ox[2], x[3] - ox[3]}

  -- rotate X (moves y and z)
  nx[2], nx[3] = nx[2] * cos(RX) - nx[3] * sin(RX), nx[2] * sin(RX) + nx[3] * cos(RX)

  -- rotate Y (moves x and z)
  nx[1], nx[3] = nx[1] * cos(RY) + nx[3] * sin(RY), nx[1] * -sin(RY) + nx[3] * cos(RY)

  -- rotate Z (moves x and y)
  nx[1], nx[2] = nx[1] * cos(RZ) - nx[2] * sin(RZ), nx[1] * sin(RZ) + nx[2] * cos(RZ)

  return {nx[1] + ox[1], nx[2] + ox[2], nx[3] + nx[3]}

end


TRAJECTORIES = {}
-- record the trajectory into tiled canvases
function record_trajectories()
  if NOW * H % PRINT_EVERY == 0 then
    for i = 1, #BODIES do
      body = BODIES[i]
      draw_trajectory_pixel(body, rotate_coords(body.x))
      if not TRAJECTORIES[i] then
        TRAJECTORIES[i] = List.new()
      end

      tr = TRAJECTORIES[i]
      list.pushright(tr, {body.x[1], body.x[2], body.x[3]})

      while tr.last - tr.first > TRAJECTORY_SIZE do
        list.popleft(tr)
      end
    end
  end

end

function draw_trajectory_pixel(body, dx)
  tile_x = math.floor(dx[1] / TILE_SIZE)
  tile_y = math.floor(dx[2] / TILE_SIZE)
  tile_key  = table.concat({tile_x, tile_y}, ' ')
  tc = TILE_CANVAS[tile_key]

  if tc == nil then
    tc = love.graphics.newCanvas(TILE_SIZE, TILE_SIZE)
    TILE_CANVAS[tile_key] = tc
  end

  love.graphics.setCanvas(tc)
  body.color[4] = 255
  love.graphics.setColor(unpack(body.color))

  local z = dx[3]
  if z > 0 then
    love.graphics.circle("fill", dx[1] % TILE_SIZE, dx[2] % TILE_SIZE, 1)
  else
    love.graphics.circle("fill", dx[1] % TILE_SIZE, dx[2] % TILE_SIZE, 1)

  end
  love.graphics.setCanvas()
end

function redraw_trajectories(max_count)
  TILE_CANVAS = {}
  force = max_count == nil and true
  max_count = max_count or TRAJECTORY_SIZE


	local tr = TRAJECTORIES[1]
	local s,l = tr.first, tr.last

	for i = l,s,-1 do
		if l - i > max_count then
			break
		end

		for j = 1, #BODIES do
			body = BODIES[j]
			tr = TRAJECTORIES[j]
      if tr ~= nil then
        draw_trajectory_pixel(body, rotate_coords(tr[i]))
      end
		end

	end

end


function implicit_euler(dt, func)
  update_gravities()

  for i=1,#BODIES do
    b = BODIES[i]
    for j = 1,DIM do
      b.v[j] = b.v[j] + b.a[j] * dt
      b.x[j] = b.x[j] + b.v[j] * dt
    end
  end
end

function euler(dt, func)
  update_gravities()

  for i=1,#BODIES do
    b = BODIES[i]
    for j = 1,DIM do
      b.x[j] = b.x[j] + b.v[j] * dt
      b.v[j] = b.v[j] + b.a[j] * dt
    end
  end
end

function verlet(dt, func)
  update_gravities()

  for i = 1,#BODIES do
    b = BODIES[i]
    for j = 1,DIM do
      b.v[j] = b.v[j] + (b.pa[j] + b.a[j]) / 2 * dt
      b.pa[j] = b.a[j]
      b.x[j] = b.x[j] + b.v[j] * dt + 0.5 * b.a[j] * dt * dt;
    end
  end
end

R3=1

function update_gravities()
  for i=1,#BODIES do
    BODIES[i].a = calc_gravity_on(i)
  end
end


function calc_gravity_on(body, pos)
  b1 = BODIES[body]
  local a = { 0,0,0 }
  local d = { 0,0,0 }

  pos = pos or b1.x

  for i = 1, #BODIES do
    if (i ~= body) then
      local b2 = BODIES[i]
      local dist = 0
      for j = 1,DIM do
        d[j] = pos[j] - b2.x[j]
        dist = dist + d[j] * d[j]
      end

      r = math.sqrt(dist)
      r3 = r * r * r
      r3 = math.max(r3, R3, b1.r + b2.r)

      for j = 1,DIM do
        a[j] = a[j] + -(GRAVITY * b2.m * d[j] / r3)
      end
    end
  end

  return a
end


-- can be rk4, rk4a, verlet, euler, implicit_euler
local INTEGRATORS = { verlet, implicit_euler, euler }
local INTEGRATOR_NAMES = { "verlet", "implicit euler", "euler" }
local cur_integrator = 1

local integrator = INTEGRATORS[1]
-- the problem here is that orbit updating is not happening in lockstep (globally)
-- for all bodies. we need to do that
function update_orbit()

  for i = 1, #BODIES do
    local b = BODIES[i]
  end

  -- summing forces O(n^2)
  for i = 1, #BODIES do
    BODIES[i].a = calc_gravity_on(i)
  end

  DT = 0.9 * DT + 0.1 * H
  -- applying forces
  integrator(H, i)

end

-- random bodies
function make_bodies()
  local N = 4
  local dist = 100
  local mass_factor = 1000
  R3 = dist*dist
  PI = 3.141592653589793
  SOLAR_MASS = 4 * PI * PI

  GRAVITY = 100
  for i = 1,N do
    body = Body:new()
    body.name = i
    body.m = mass_factor
    body.x = {math.random(-N,N)*dist, math.random(-N,N)*dist, math.random(-N,N)*dist}
    body.v = {math.random(-10,10), math.random(-10,10), math.random(-10,10)}
    body.r = body.m * 5
    body:adjust()

    table.insert(BODIES, body)
  end

  return BODIES
end

function do_housekeeping()
  NB = {}
  for i = 1,#BODIES do
    if BODIES[i].stopped == false then
      table.insert(NB, BODIES[i])
    else
      if i < FB then
        FB = FB - 1
      end
    end

  end

  B = NB

  if tableLength(TILE_CANVAS) > MAX_TILES then
    NEXT_TILE_CANVAS = {}
    for tk, tc in pairs(TILE_CANVAS) do
      if NOW - (TILE_LAST_USED[tk] or 0 ) < MAX_TILES and tableLength(NEXT_TILE_CANVAS) < MAX_TILES then
        NEXT_TILE_CANVAS[tk] = tc
      end
    end

    TILE_CANVAS = NEXT_TILE_CANVAS
  end
end

function draw_trajectories(l,t,w,h)
  if DRAW_CANVAS then
    for x = l, l+w+TILE_SIZE, TILE_SIZE do
      for y = t, t+h+TILE_SIZE, TILE_SIZE do
        tile_x = math.floor(x / TILE_SIZE)
        tile_y = math.floor(y / TILE_SIZE)
        tile_key  = table.concat({tile_x, tile_y}, ' ')
        tc = TILE_CANVAS[tile_key]
        if tc then
          TILE_LAST_USED[tile_key] = NOW
          love.graphics.draw(tc, tile_x * TILE_SIZE, tile_y * TILE_SIZE)
        end
      end
    end
  end

end

function draw_axes()

  -- TODO: fix this
  -- draw unit lines in each direction
  ul1 = rotate_coords({100, 0, 0})
  ul2 = rotate_coords({0, 100, 0})
  ul3 = rotate_coords({0, 0, 100})

  love.graphics.setColor(255, 0, 0)
  love.graphics.line(0, 0, ul1[1], ul1[2])
  love.graphics.setColor(0, 0, 255)
  love.graphics.line(0, 0, ul2[1], ul2[2])
  love.graphics.setColor(0, 255, 0)
  love.graphics.line(0, 0, ul3[1], ul3[2])


end

function draw_bodies()

  if DRAW_AXES then
    draw_axes()
  end

  for i = 1, #BODIES do
    body = BODIES[i]
    body.color[4] = 150

    dx = rotate_coords(body.x)

    love.graphics.setColor(unpack(body.color))

    love.graphics.circle("fill", dx[1], dx[2], body.dr)

    if body.stopped == false then

      if DRAW_FORCES then
        love.graphics.line(dx[1], dx[2], dx[1]+body.a[1]/100, dx[2]+body.a[2]/100)
      end

      -- if we are zoomed out we draw one way
      if SCALE > 1 then
        if DRAW_OUTLINE then love.graphics.circle("line", dx[1], dx[2], body.dr*SCALE) end
      else
        if DRAW_OUTLINE then love.graphics.circle("line", dx[1], dx[2], body.dr/SCALE) end
      end
    end
  end

end

function draw_text(l,t,w,h)

  for i=1,#BODIES do
    love.graphics.setColor(255, 255, 255)
    if DRAW_BODY_INFO == 2 or (DRAW_BODY_INFO == 1 and FB == i) then
      lstr = string.format("%s\nM: %f\nX: %i %i %i\nV: %i %i %i\nA: %i %i %i",
        BODIES[i].name or "", BODIES[i].m,
        BODIES[i].x[1], BODIES[i].x[2], BODIES[i].x[3],
        BODIES[i].v[1], BODIES[i].v[2], BODIES[i].v[3],
        BODIES[i].a[1], BODIES[i].a[2], BODIES[i].a[3])

      rx = rotate_coords(BODIES[i].x)
      love.graphics.print(lstr, rx[1], rx[2], 0, 1/SCALE, 1/SCALE)
    end
  end

  love.graphics.setColor(255, 255, 255)
  lstr = string.format("T: %.02f SP: %.02f SC: %.02f, DT: %.03e, I: %s",
    NOW*H, SPEED, SCALE, DT, INTEGRATOR_NAMES[cur_integrator])
  font = love.graphics.getFont()
  local fw = font:getWidth(lstr)
  local fh = font:getHeight(lstr) * 2 + 10
  love.graphics.print(lstr, l + w/2 - (fw/SCALE), t + h - fh/SCALE, 0, 1/SCALE*2, 1/SCALE*2)
end

function adjust_focus(incr)
  start = FB
  incr = incr or 1

  while true do
    FB = FB + incr
    if FB < 1 then FB = #BODIES end
    if FB > #BODIES then FB = 1 end

    if FB == start or BODIES[FB].stopped == false then
      break
    end
  end

  TX=0
  TY=0
end

function print_bodies()
  for i = 1, #BODIES do
    print("BODY", i, BODIES[i].name, "M", BODIES[i].m)
    print("  X",  BODIES[i].x[1], BODIES[i].x[2], BODIES[i].x[3])
    print("  V", BODIES[i].v[1], BODIES[i].v[2], BODIES[i].v[3])
    print("  A", BODIES[i].a[1], BODIES[i].a[2], BODIES[i].a[3])
  end
end

housekeeping = 100

SYSTEM_ENERGY = {}

function magnitude(x)
  local t = 0
  for n = 1, DIM do
    t = t + (x[n]*x[n])
  end
  return math.sqrt(t)
end

function calc_distance(x1, x2)
  local dist = 0
  for n = 1,DIM do
    d = x1[n] - x2[n]
    dist = dist + d * d
  end
  return math.sqrt(dist)
end


local frame_index = 0
function make_screenshot()

  frame_index = frame_index + 1
  if frame_index % 10 == 0 then
    local screenshot = love.graphics.newScreenshot()
    local fname = string.format("%05i-%i.png", frame_index, os.time())
    local file = love.filesystem.newFile(fname, "w")
    if LOVE_MIN == 9 then
      e = screenshot:encode(file, 'png');
    else
      file_data = screenshot:encode('png', nil);
      local data = file_data:getString()
      file:write(data, #data)
    end
    print("SAVED", fname)
    file:close()
  end

end

function update_mouse_drag(dt)
  x = love.mouse.getX()
  y = love.mouse.getY()

  dragging.diffX = x - dragging.lastX
  dragging.diffY = y - dragging.lastY
  dragging.lastX = x
  dragging.lastY = y

  if dragging.active then
    RY = RY + dragging.diffX * dt
    RX = RX + dragging.diffY * dt

    redraw_trajectories(TRAJECTORY_MINI)

    if BODIES[FB] then
      FC = clone(BODIES[FB].x)
    end
  end

end

-- LOVE HANDLERS BELOW
function love.load()
  CAM = gamera.new(0,0,100,100)

  LOVE_MAJ, LOVE_MIN, LOVE_REV, LOVE_CODENAME = love.getVersion()

--  BODIES = make_bodies()
--  BODIES = read_bodies()
  BODIES = presets.main()
end

dragging = { active = false, diffX = 0, diffY = 0, lastX = 0, lastY = 0}
function love.mousepressed(x, y, button)
  if button == "l" or button == 1 then
    if not dragging.active then
      dragging.lastX = x
      dragging.lastY = y
    end

    dragging.active = true
  end
end

function love.mousereleased()
  if dragging.active then
    redraw_trajectories()
  end
  dragging.active = false
end

function love.keypressed( key )
  if key == " " then adjust_focus() end
  if key == "backspace" then adjust_focus(-1) end

  if key == "-" then SCALE = SCALE / 1.5 end
  if key == "=" or key == "+" then SCALE = SCALE * 1.5 end
  if key == "0" then
    RX = 0; RY = 0; RZ = 0; SCALE = 1;
    TX = 0; TY = 0;
    FC = nil
    redraw_trajectories()
  end

  if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
    if key == "." then SPEED = SPEED * 1.5 end
    if key == "," then SPEED = SPEED / 1.5 end

    local rdr = false
    if key == "up" then RX = RX - 0.1; rdr = true end
    if key == "down" then RX = RX + 0.1; rdr = true end
    if key == "left" then RY = RY - 0.1; rdr = true end
    if key == "right" then RY = RY + 0.1; rdr = true end

    if key == "d" then H = H * 10 end

    if rdr then
      redraw_trajectories()
    end
  else
    if key == "." then SPEED = SPEED + 1 end
    if key == "," then SPEED = SPEED - 1 end
    if key == "left" then TX = TX - 100/SCALE end
    if key == "right" then TX = TX + 100/SCALE end
    if key == "up" then TY = TY - 100/SCALE end
    if key == "down" then TY = TY + 100/SCALE end

    if key == "d" then H = H / 10 end
  end

  if key == "a" then DRAW_AXES = not DRAW_AXES end
  if key == "f" then FB = 0 end -- freecam
  if key == "l" then DRAW_FORCES = not DRAW_FORCES end
  if key == "m" then DRAW_CANVAS = not DRAW_CANVAS end
  if key == "o" then DRAW_OUTLINE = not DRAW_OUTLINE end
  if key == "i" then DRAW_BODY_INFO = (DRAW_BODY_INFO + 1) % 3 end
  if key == "r" then TILE_CANVAS = {}; TRAJECTORIES = {}; end

  if key == "[" then
    cur_integrator = cur_integrator - 1
    if cur_integrator == 0 then
      cur_integrator = #INTEGRATORS
    end
    integrator = INTEGRATORS[cur_integrator]
  end

  if key == "]" then
    cur_integrator = cur_integrator + 1
    if cur_integrator > #INTEGRATORS then
      cur_integrator = 1
    end
    integrator = INTEGRATORS[cur_integrator]
  end

  function reset_state(preset)
    preset = preset or RESET_FUNC
    NOW = 0
    H=0.001
    SPEED=10
    PRINT_EVERY=0.1
    TRAJECTORIES = {}
    TILE_CANVAS = {}
    STEP_SIZE = 1
    BODIES = {}
    BODIES = preset()
    RESET_FUNC = preset
  end

  if key == "n" then
    presets.next()
    reset_state(presets.main)
  end

  if key == "b" then
    presets.back()
    reset_state(presets.main)
  end

  if key == "p" then print_bodies() end

  if key == "c" then
    reset_state()
  end

  if key == "1" then
    reset_state(make_bodies)
  end

  if key == "2" then
    reset_state(planets.read_bodies)
  end

  if key == "3" then
    reset_state(presets.main)
  end

  SCALE = math.max(SCALE, 0.001)
end

function love.update(dt)
  SPEED = math.max(0, SPEED)

	update_mouse_drag(dt)

  if dragging.active then
    speed = 1
  else
    speed = SPEED
  end

  for i = 1, speed do
    NOW = NOW + 1

    update_orbit()
    record_trajectories()

    if housekeeping == 0 then
      housekeeping = 100
      do_housekeeping()
    end

    housekeeping = housekeeping - 1
  end
end

function love.draw()
  w = love.graphics.getWidth()
  h = love.graphics.getHeight()

  CAM:setScale(SCALE)

  -- sets l,t,w,h,w2,h2
  CAM:setWindow(0,0,w,h)
  CAM:draw(function(l,t,w,h)
    if BODIES[FB] ~= nil then
      -- sets x and y
      rx = rotate_coords(BODIES[FB].x)
      CAM:setPosition(rx[1] + TX, rx[2] + TY)
      -- sets wl, wt, ww, wh
      CAM:setWorld(rx[1] - w, rx[2] - h, w*2, h*2)
    else
      CAM:setPosition(TX, TY)
      CAM:setWorld(-w, -h, 2*w, 2*h)

    end

    draw_text(l,t,w,h)
    draw_trajectories(l,t,w,h)
    draw_bodies(l,t,w,h)
  end)


  if love.keyboard.isDown("s") then
    local co = coroutine.create(make_screenshot)
    coroutine.resume(co)
  end
end
