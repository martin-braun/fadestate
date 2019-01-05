# fadestate.lua for LÖVE
Simple gamestate lib that allows simple fading transitions

## Usage

### Prepare

```lua
fadestate = require "fadestate"

local masterCanvas

local SampleState = {}
function SampleState:init()
	print("state initialized")
end
function SampleState:enter(lastState)
	print("state entered")
end
function SampleState:resume()
	print("state resumed")
end
function SampleState:update(dt)
	-- your update logic for this state
end
function SampleState:draw()
	-- your draw logic for this state
end
function SampleState:leave()
	print("state left")
end

function love.load(args)
	masterCanvas = love.graphics.newCanvas()
	fadestate.init(masterCanvas, SampleState, "out-in", 0.5)
end

function love.update(dt)
	fadestate.update(dt)
end

function love.draw()
	fadestate.draw()
end
```

### Change state

```lua

fadestate.switch(myNewState, "out-in", 0.5, 0.5) -- replaces current state on top of the stack, calls oldState:leave, newState:init (once) and newState:enter

fadestate.push(myNextState, "out-in", 0.5, 0.5) -- adds new state on top of the stack, calls newState:init (once) and newState:enter

fadestate.pop("out-in", 0.5, 0.5) -- pops the current state from top of the stack, calls oldState:leave and lastState:resume

```

## Support

- Tested for 0.10.2, but should work with 11.x. Simple change the constant `COLOR_TOP` to 1 in the fadestate.lua file.
- Color mode not supported yet (fading into white, etc.)
- Does not pass any other love-events to the states, besides love.update and love.draw. This is designed for games that make use of ECS structures, so you should have systems register any actions like keystrokes or events.