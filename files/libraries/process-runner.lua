-- Copyright (c) 2022 David Vogel
--
-- This software is released under the MIT License.
-- https://opensource.org/licenses/MIT

-- A simple library to run/control processes. Specifically made for the Noita map capture addon.
-- This allows only one process to be run at a time in a given context.

-- No idea if this library has much use outside of this mod.

if not async then
	require("coroutines") -- Loads Noita's coroutines library from `data/scripts/lib/coroutines.lua`.
end

-------------
-- Classes --
-------------

local ProcessRunner = {}

---@class ProcessRunnerCtx
---@field running boolean|nil
---@field stopping boolean|nil
---@field progressCurrent number|nil
---@field progressEnd number|nil
local Context = {}
Context.__index = Context

-----------------
-- Constructor --
-----------------

---Returns a new process runner context.
---@return ProcessRunnerCtx
function ProcessRunner.New()
	return setmetatable({}, Context)
end

-------------
-- Methods --
-------------

---Returns whether some process is running.
---@return boolean
function Context:IsRunning()
	return self.running or false
end

---Returns whether the process needs to stop as soon as possible.
---@return boolean
function Context:IsStopping()
	return self.stopping or false
end

---Returns the progress of the process.
---@return number current
---@return number end
function Context:GetProgress()
	return self.progressCurrent or 0, self.progressEnd or 0
end

---Tells the currently running process to stop.
function Context:Stop()
	self.stopping = true
end

---Starts a process with the three given callback functions.
---This will just call the tree callbacks in order.
---Everything is called from inside a coroutine, so you can use yield.
---
---There can only be ever one process at a time.
---If there is already a process running, this will just do nothing.
---@param initFunc fun(ctx:ProcessRunnerCtx)|nil -- Called first.
---@param doFunc fun(ctx:ProcessRunnerCtx)|nil -- Called after `initFunc` has been run.
---@param endFunc fun(ctx:ProcessRunnerCtx)|nil -- Called after `doFunc` has been run.
---@param errFunc fun(err:string, scope:"init"|"do"|"end") -- Called on any error.
function Context:Run(initFunc, doFunc, endFunc, errFunc)
	if self.running then return end

	async(function()
		self.running, self.stopping, self.progressCurrent, self.progressEnd = true, false, nil, nil

		-- Init function.
		if initFunc then
			local ok, err = pcall(initFunc, self)
			if not ok then
				-- Error happened, abort.
				if endFunc then pcall(endFunc, self) end
				errFunc(err, "init")
				self.running, self.stopping = false, false
				return
			end
		end

		-- Do function.
		if doFunc then
			local ok, err = pcall(doFunc, self)
			if not ok then
				-- Error happened, abort.
				errFunc(err, "do")
			end
		end

		-- End function.
		if endFunc then
			local ok, err = pcall(endFunc, self)
			if not ok then
				-- Error happened, abort.
				errFunc(err, "end")
			end
		end

		self.running, self.stopping = false, false
	end)
end

return ProcessRunner
