local json = require("lib/json")

function read_bodies()
  DAYS_PER_YEAR = 365.24
  DF=DAYS_PER_YEAR
  PI = 3.141592653589793
  SOLAR_MASS = 4 * PI * PI
  PRINT_EVERY=1

  -- 4*pi^2 * AU^3 * yr^-2 * solar_mass^-1
  GRAVITY= SOLAR_MASS / DAYS_PER_YEAR

  -- solar mass units
  masses = {
    sun = 1,
    mercury = 0.16601 / 1e+6,
    venus = 2.4478383 / 1e+6,
--    moon = 0.03693474/ 1e+6,
    earth = 3.00348959632 / 1e+6,
    mars = 0.3227151  / 1e+6,
    jupiter = 954.79194   / 1e+6,
    saturn = 285.8860 / 1e+6,
    uranus = 43.66244 / 1e+6,
    neptune = 51.51389    / 1e+6,
    pluto = 0.007396 / 1e+6,
  }

  -- given in kilometers
  diameters = {
    mercury = 4879,
    venus = 12104,
    earth = 12756  ,
    moon = 3475 ,
    mars = 6792,
    jupiter = 142984   ,
    saturn = 120536,
    uranus = 51118 ,
    neptune = 49528    ,
    pluto = 2370,
    sun = 1.3914E+6
  }

  colors = {
    mercury = { 255, 0, 0 },
    venus = { 255, 255, 255 },
    earth = { 0, 255, 255}  ,
    moon = {155, 155, 155} ,
    mars = {255, 180, 0},
    jupiter = {155, 255, 80},
    saturn = {0, 0, 255},
    uranus = {135, 135, 155},
    neptune = {44, 100, 100},
    pluto = {25, 25, 255},
    sun = {255, 255, 0}


  }

  body_by_name = {}
  for l in io.lines("planets.json") do
    data = json.decode(l)
    for name, vec in pairs(data["results"]) do
      p = Body:new()
      p.name = name
      p.r = diameters[name] / 2

      if colors[name] then
        p.color = colors[name]
      end

      if masses[name] then
        p.m = masses[name] * DF * DF
        p.x = { vec[1][1]*DF, vec[1][2]*DF, vec[1][3]*DF}
        p.v = { vec[2][1]*DF, vec[2][2]*DF, vec[2][3]*DF}
        p:adjust()

        table.insert(BODIES, p)
        body_by_name[name] = p
      end

      if name == "sun" then FB = #BODIES end

      print(string.format("added %s m: %.02f %.02f ", name, p.r, p.m))
    end

  end

  local moon = body_by_name.moon

  if moon ~= nil then
    local earth = body_by_name.earth
    for j = 1,DIM do
      moon.x[j] = moon.x[j] + earth.x[j]
      moon.v[j] = moon.v[j] + earth.v[j]
    end
  end

  return BODIES
end

return {
  read_bodies=read_bodies
}
