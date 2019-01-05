
local FS = {
  _VERSION     = "fadestate v1.0.0",
  _DESCRIPTION = "Simple gamestate lib that allows simple fading transitions",
  _URL         = "",
  _LICENSE     = [[
		MIT LICENSE

		Copyright (c) 2019 Martin Braun

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
		the following conditions:

    The above copyright notice and this permission notice shall be included
		in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
  ]]
}

local COLOR_TOP = 255

local __NULL__, lg = function() return end, love.graphics
local setColor, setCanvas, clear, draw = lg.setColor, lg.setCanvas , lg.clear, lg.draw

-- enum STATE_CHANGE_TYPE
local STATE_CHANGE_TYPE_SWITCH = "switch"
local STATE_CHANGE_TYPE_PUSH = "push"
local STATE_CHANGE_TYPE_POP = "pop"

-- enum FADE_TYPE
local FADE_TYPE_INSTANT = "instant"
local FADE_TYPE_OUT_IN = "out-in"
local FADE_TYPE_CROSS = "cross"

local isTransitioning = false
local activeTransition = {
	stateChangeType = nil,
	nextState = nil,
	fadeType = nil,
	fadeDurOut = nil,
	fadeDurIn = nil,
	fadeColor = nil,
	-- helpers:
	fromState = nil,
	toState = nil,
	entered = nil,
}

local defaultDur = 0.5

local stack = {}

local masterCanvas, canvasTop, canvas2nd
local canvasTopOpacity, canvas2ndOpacity = 0, COLOR_TOP

local function initChangeState(stateChangeType, nextState, fadeType, fadeDurOut, fadeDurIn, fadeColor)
	if stack[#stack] == nextState and fadeType == FADE_TYPE_CROSS then
		error("Unable to fade to the same state instance.")
	end
	if stateChangeType == STATE_CHANGE_TYPE_POP and #stack == 1 then
		error("Unable to pop the last remaining state on the stack, use switch instead.")
	end

	if isTransitioning then
		return false
	end

	fadeType = fadeType or FADE_TYPE_INSTANT
	fadeDurOut = fadeDurOut or defaultDur
	fadeDurIn = fadeDurIn or fadeDurOut
	fadeColor = fadeColor or { COLOR_TOP, COLOR_TOP, COLOR_TOP }

	activeTransition.stateChangeType = stateChangeType
	activeTransition.nextState = nextState
	activeTransition.fadeType = fadeType
	activeTransition.fadeDurOut = fadeDurOut
	activeTransition.fadeDurIn = fadeDurIn
	activeTransition.fadeColor = fadeColor
	activeTransition.entered = nil

	isTransitioning = true

	return true
end

local function enterState(state, previousState, ...)
	if not state.__initialized then
		(state.init or __NULL__)(state)
		state.__initialized = true
	end
	state.__canvas = canvasTop
	;(state.enter or __NULL__)(state, previousState, ...)
end

local function leaveState(state)
	state.__canvas = nil
	;(state.leave or __NULL__)(state)
end

--- Initialize the state manager.
-- Initializes the state manager, adds the first state into the stack, calls firstState:init() and firstState:enter(currentState) and fades the state in.
-- @param canvas The master canvas on which all states will be drawn on.
-- @param firstState New state to put on top of the stack.
-- @param fadeType Type of the fading ("instant" - no fading; "out-in" - fade in new state after fading out current state). ••• WARNING: "cross" cannot be used on initialization!
-- @param fadeDurIn (optional) Duration to fade into the first state, default: fadeDurOut or 0.5.
-- @usage fadestate.init(myCanvas, myFirstState, "out-in", 0.5)
function FS.init(canvas, firstState, fadeType, fadeDurIn, ...)
	if fadeType == FADE_TYPE_CROSS then
		error("Cross-fading into the first state is not possible, use 'out-in', instead.")
	end
	masterCanvas = canvas
	fadeDurIn = fadeDurIn or fadeDurOut
	local w, h = canvas:getDimensions()
	canvasTop, canvas2nd = lg.newCanvas(w, h), lg.newCanvas(w, h)
	stack[#stack + 1] = firstState
	enterState(firstState, nil, ...)
	activeTransition.stateChangeType = STATE_CHANGE_TYPE_PUSH
	activeTransition.nextState = firstState
	activeTransition.toState = firstState
	activeTransition.fadeType = fadeType
	activeTransition.fadeDurOut = 0
	activeTransition.fadeDurIn = fadeDurIn
	activeTransition.entered = nil
	isTransitioning = true
end

--- Update the active states.
-- Updates the state that is on top of the stack. If a transition is happening, it updates the current state as well as the new state in that order. This function should be called in love.update.
-- @param dt Delta time of the last frame.
-- @usage fadestate.update(dt)
function FS.update(dt)
	if isTransitioning then
		local stateChangeType, fadeType, fadeDurOut, fadeDurIn, fromState, toState = activeTransition.stateChangeType, activeTransition.fadeType, activeTransition.fadeDurOut, activeTransition.fadeDurIn, activeTransition.fromState, activeTransition.toState

		if not fromState and not toState then -- initialize transition
			activeTransition.fromState = stack[#stack]
			fromState = activeTransition.fromState
			fromState.__canvas = canvas2nd
			canvasTopOpacity, canvas2ndOpacity = 0, COLOR_TOP
		end

		if fadeType == FADE_TYPE_INSTANT or (fadeDurOut <= 0 and fadeDurIn <= 0) then
			canvas2ndOpacity = 0
			canvasTopOpacity = COLOR_TOP
		else
			if canvas2ndOpacity > 0 then
				canvas2ndOpacity = canvas2ndOpacity - COLOR_TOP / fadeDurOut * dt
			end
			if activeTransition.entered and (canvas2ndOpacity <= 0 or (canvasTopOpacity <= COLOR_TOP and fadeType == FADE_TYPE_CROSS)) then
				canvasTopOpacity = canvasTopOpacity + COLOR_TOP / fadeDurIn * dt
			end
		end

		if fromState and canvas2ndOpacity <= 0 then
			if activeTransition.stateChangeType ~= STATE_CHANGE_TYPE_PUSH then
				leaveState(fromState)
			end
			activeTransition.fromState = nil
			fromState = nil
		end

		if not toState and (fadeType == FADE_TYPE_CROSS or canvas2ndOpacity <= 0) then
			activeTransition.toState = activeTransition.nextState
			toState = activeTransition.toState
			if activeTransition.stateChangeType ~= STATE_CHANGE_TYPE_POP then
				enterState(toState, fromState)
			else
				(toState.resume or __NULL__)(toState)
			end
			canvasTopOpacity = 0
			if stateChangeType == STATE_CHANGE_TYPE_SWITCH or stateChangeType == STATE_CHANGE_TYPE_POP then
				stack[#stack] = nil
			end
			if stateChangeType ~= STATE_CHANGE_TYPE_POP then
				stack[#stack + 1] = toState
			end
		elseif toState then
			activeTransition.entered = true
		end

		if fromState then
			fromState.__canvas = canvas2nd
			;(fromState.update or __NULL__)(fromState, dt)
		end
		if toState then
			toState.__canvas = canvasTop
			;(toState.update or __NULL__)(toState, dt)
		end

		if canvasTopOpacity >= COLOR_TOP then
			activeTransition.stateChangeType = nil
			activeTransition.nextState = nil
			activeTransition.fadeType = nil
			activeTransition.fadeDurOut = nil
			activeTransition.fadeDurIn = nil
			activeTransition.fadeColor = nil
			activeTransition.fromState = nil
			activeTransition.toState = nil
			activeTransition.entered = nil
			isTransitioning = false
		end
	else
		local state = stack[#stack]
		;(state.update or __NULL__)(state, dt)
	end
end

--- Draw the active states.
-- Draws the state that is on top of the stack to the canvas that was given in the init method. If a transition is happening, it draws the current state as well as the new state in that order with the appropriate alpha. This function should be called in love.draw.
-- @param w (optional) Width that is passed to the draw functions of active and transitioning states.
-- @param h (optional) Height that is passed to the draw functions of active and transitioning states.
-- @param lag (optional) Lag time that is passed to the draw functions of active and transitioning states. Only makes sense when making use of linear interpolation on a fixed timestamp.
-- @usage fadestate.draw()
function FS.draw(w, h, lag)
	if isTransitioning then
		local fadeColor, fromState, toState = activeTransition.fadeColor, activeTransition.fromState, activeTransition.toState
		if fromState then
			setCanvas(fromState.__canvas)
			clear(fadeColor)
			;(fromState.draw or __NULL__)(fromState, w, h, lag)
		end
		if toState then
			setCanvas(toState.__canvas)
			clear(fadeColor)
			;(toState.draw or __NULL__)(toState, w, h, lag)
		end
	else
		local state = stack[#stack]
		setCanvas(state.__canvas)
		clear()
		;(state.draw or __NULL__)(state, w, h, lag)
	end
	setCanvas(masterCanvas)
	clear()
	if isTransitioning then
		setColor(COLOR_TOP, COLOR_TOP, COLOR_TOP, canvas2ndOpacity)
		draw(canvas2nd)
	end
	setColor(COLOR_TOP, COLOR_TOP, COLOR_TOP, canvasTopOpacity)
	draw(canvasTop)
end

--- Change the current state to a new one.
-- Fades the current state out, calls currentState:leave() and removes it from the stack after fading out entirely. Adds a new state on the top of the stack, calls newState:init(), if it never has been initialized and calls newState:enter(currentState).
-- @param nextState New state to put on top of the stack.
-- @param fadeType Type of the fading ("instant" - no fading; "out-in" - fade in new state after fading out current state; "cross" - cross-fade both states, simultaneously). ••• WARNING: "cross" cannot be used when transitioning from the current itself (re-entering the same state)!
-- @param fadeDurOut (optional) Duration to fade out current state, default: 0.5.
-- @param fadeDurIn (optional) Duration to fade into new state, default: fadeDurOut or 0.5.
-- @return False, if the transition could not be started, because a transition is still happening.
-- @usage fadestate.switch(myNewState, "out-in", 0.5, 0.5)
function FS.switch(nextState, fadeType, fadeDurOut, fadeDurIn, fadeColor) -- TODO: fix fadeColor, not working yet
	return initChangeState(STATE_CHANGE_TYPE_SWITCH, nextState, fadeType, fadeDurOut, fadeDurIn, fadeColor)
end

--- Push a new state.
-- Fades the current state out and stops calling events on it after fading out entirely. Adds a new state on the top of the stack and fades it in. Calls newState:init() on the added state, if it never has been initialized and calls newState:enter(currentState).
-- @param nextState New state to put on top of the stack.
-- @param fadeType Type of the fading ("instant" - no fading; "out-in" - fade in new state after fading out current state; "cross" - cross-fade both states, simultaneously). ••• WARNING: "cross" cannot be used when transitioning from the current itself (re-entering the same state)!
-- @param fadeDurOut (optional) Duration to fade out current state, default: 0.5.
-- @param fadeDurIn (optional) Duration to fade into new state, default: fadeDurOut or 0.5.
-- @return False, if the transition could not be started, because a transition is still happening.
-- @usage fadestate.push(myNextState, "out-in", 0.5, 0.5)
function FS.push(nextState, fadeType, fadeDurOut, fadeDurIn, fadeColor) -- TODO: fix fadeColor, not working yet
	return initChangeState(STATE_CHANGE_TYPE_PUSH, nextState, fadeType, fadeDurOut, fadeDurIn, fadeColor)
end

--- Pops the current state.
-- Fades the current state out, calls currentState:leave() after fading out entirely and removes this state from the stack. Resumes the new top state on the stack by calling newState:resume() and fades that state in, again.
-- @param fadeType Type of the fading ("instant" - no fading; "out-in" - fade in new state after fading out current state; "cross" - cross-fade both states, simultaneously). ••• WARNING: "cross" cannot be used when transitioning from the current itself (re-entering the same state)!
-- @param fadeDurOut (optional) Duration to fade out current state, default: 0.5.
-- @param fadeDurIn (optional) Duration to fade into new state, default: fadeDurOut or 0.5.
-- @return False, if the transition could not be started, because a transition is still happening.
-- @usage fadestate.pop("out-in", 0.5, 0.5)
function FS.pop(fadeType, fadeDurOut, fadeDurIn, fadeColor) -- TODO: fix fadeColor, not working yet
	return initChangeState(STATE_CHANGE_TYPE_POP, stack[#stack - 1], fadeType, fadeDurOut, fadeDurIn, fadeColor)
end

return FS