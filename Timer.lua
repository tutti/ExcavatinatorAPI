local _, private = ...

local Class = private.Class

local TimerWait = Class:extend()

function TimerWait:construct(timer, time, func, rpt)
    self.timer = timer
    self.initTime = time
    self.time = time
    self.func = func
    self.rpt = rpt
end

function TimerWait:update(elapsed)
    local triggered = false
    self.time = self.time - elapsed
    while self.time < 0 do
        triggered = true
        self.func()
        self.time = self.time + self.initTime
        if not self.rpt and self.time < 0 then self.time = 1 end
    end
    return triggered
end

function TimerWait:cancel()
    self.timer:_cancel(self)
end

local Timer = Class:extend()

function Timer:construct()
    self.totalTime = 0

    self.timeouts = {}
    self.intervals = {}

    self.frame = CreateFrame('Frame')
    self.frame:SetScript('OnUpdate', function(_, elapsed) self:_onUpdate(elapsed) end)
end

function Timer:_onUpdate(elapsed)
    for wait, v in pairs(self.timeouts) do
        local done = wait:update(elapsed)
        if done then self.timeouts[wait] = nil end
    end

    for wait, v in pairs(self.intervals) do
        wait:update(elapsed)
    end
end

function Timer:_cancel(wait)
    self.timeouts[wait] = nil
    self.intervals[wait] = nil
end

function Timer:setTimeout(func, time)
    local wait = TimerWait:new(self, time, func, false)
    self.timeouts[wait] = true
    return wait
end

function Timer:setInterval(func, time)
    local wait = TimerWait:new(self, time, func, true)
    self.intervals[wait] = true
    return wait
end

private.Timer = Timer:new()