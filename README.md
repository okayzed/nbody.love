## About

an n-body gravity simulator written in lua with the love2d framework

![](https://github.com/okayzed/nbody.love/raw/master/img/ducati3.gif)

## keyboard shortcuts

* **1**: random body placement
* **2**: show solar system
* **3**: use nbody presets
* **space** / **backspace**: focus next / prev body
* **f**: float camera
* **r**: reset canvas
* **c**: restart current simulation
* **m**: toggle drawing trajectories
* **s**: take a screenshot
* **b** and **n**: prev / next nbody simulation
* **\-** and **\+** : zoom out / in
* **.** and **,**: slow down / speed up simulation
* **d** and **D**: decrease / increase time step
* **[** and **]**: pick prev / next integrator
* **p**: print body info (mass, area, velocity) to terminal


## Integrators

* euler / semi-implicit euler
* verlet

## Sources

Planetary data is obtained from the [astro-phys.com](http://www.astro-phys.com/api/de406/states?date=2016-1-31&bodies=sun,mercury,venus,earth,mars,jupiter,neptune,uranus,pluto&type=polynomial&unit=au) API

closed nbody orbits are from [www.princeton.edu/~rvdb/WebGL/nBody.html](http://www.princeton.edu/~rvdb/WebGL/nBody.html)

## more GIFs

![](https://github.com/okayzed/nbody.love/raw/master/img/hill3.gif)
![](https://github.com/okayzed/nbody.love/raw/master/img/solar.gif)

