--[[ Destiny AI
Created by: Fredyman_95 and MineDragonCZ_
Special Thanks To: 
Shickla - We used parts of his code
Mr_Spagetty - comments and aesthetic modification of the code + notes for code sections
v.1.1.0.0
]]

-- Declarations ---------------------------------------------------------------
local c = require("component")
local event = require("event")
local f = require("filesystem")
local m = require("math")
local s = require("sides")
local console = c.command_block
local clock = c.countdown
local destiny = c.warpcontroller
local rs = c.redstone
local siren = c.os_alarm
local events = {}
local devMode = true
local mainLoop = true

-- End of Declarations --------------------------------------------------------

-- Autopilot Config -----------------------------------------------------------
local firstStopID = 0            -- first stop Dim ID
local lastStopID = 10            -- last stop Dim ID
local minStop = 30               -- minimum time for stop (dev mode - s, normally min)
local maxStop = 60               -- max time for stop (dev mode - s, normally min)
local safetyTime = 65            -- time reserve for gate dial (s)
local ftlMalfunctionDim = 100    -- ID of planet (star) where Destiny jumps with broken FTL drive
local chanceReducer = 1          -- Reducer of chance to brake FTL
local maxTotalChance = 50        -- Max total Chance
local maxftlBreakChance = 20     -- Max chance for FTL drive malfunction
local minftlBreakChance = 3      -- Min chance for FTL drive malfunction
local stayInSystem = 150         -- cost of travel in Solar system 
local leaveSystem = 400          -- cost of travel out of Solar system     Solar system position... when you reach earth everything is far and cost reached 500.. and thats max...
local returnToCourseTimer = 6000  -- Time for countdown clock after fixing FTL drive (ticks)
local sameSystemJump = 10        -- Chance for same system jump in %
local rsFtlChecker = s.west        -- Choose one of: east, west, south, north, top, bottom
local rsFtlFixer = s.east          -- Choose one of: east, west, south, north, top, bottom
local effectRadius = 500           -- radius for FTL drop in/out effect

-- End of Autopilot Config ---------------------------------------------------

-- Destiny stargate settings --------------------------------------------------
local fakeDimPos = "10 20 30"                 -- Position of stargate in fake dimension
local fakeDim = {"1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1", "1"}                            -- Table with all fake dimension IDs
local destinyGatePos = "-1526 129 -1541"         -- World position of Destiny Stargate
local warpDimID = 0                           -- Fake dimension for not diable gate

-- End of Destiny Stargate settings -------------------------------------------

-- Functions
-- Common functions -------------------------------------------------------
    local function timer(pauseTime)
        pause = tonumber(pauseTime * 10)
        for i = 0 , pauseTime do
            os.sleep(.1)
            if not mainLoop then break end
        end
        mainLoop = true
    end

    local function coloredText(text, colorCode)
        gpu.setForeground(colorCode)
        print(text)
        gpu.setForeground(0xFFFFFF)
    end

-- End of Common functions ------------------------------------------------

-- Destiny´s AI Functions -------------------------------------------------
    local function destinyAlarm()
        local loop = true
        siren.activate()
        while loop do
            timer(1)
            if rs.getInput(rsFtlFixer) > 0 then loop = false end
        end
        siren.deactive()
        ftlDriveStatusWasFixed = true
        clock.setCountdown(returnToCourseTimer)
    end

    local function setTimer()
        -- sets the time left on the clock to between minStop and maxStop + safetyTime
        if devMode
        then timeMultiplayer = 20   -- min and max get multiplyed by 20
        else timeMultiplayer = 1200 -- min and max get multiplyed by 1200
        end
        time = tonumber(m.random((minStop * timeMultiplayer), (maxStop * timeMultiplayer)) + safetyTime*20)
        timer(0.5)
        clock.setCountdown(time)
        ------------------------------------------------------------------------- save clock time :D
    end

    local function setChance()
        -- saves the recalculated actual chance to the external storage medium (command block)
        actualChance = actualChance - chanceReducer
        chanceSaver = asssert(io.open("/destinyAI/backup/chance", "w"))
        chanceSaver:write(actualChance)
        chanceSaver:close()
    end

    local function autopilotFtlMalfuction()
        -- break the ftl drive
        ftlDriveStatusBroken = true
        dimIdSaver = assert(io.open("/destinyAI/backup/dimension", "w"))
        dimIdSaver:write(destiny.currentPlanet())
        dimIdSaver:close()
        destiny.setDestination(ftlMalfunctionDim)
    end

    local function autopilotReturnToCourse()
        -- return to the programed course
        ftlBreakChance = tonumber(m.random(minftlBreakChance, maxftlBreakChance)) -- reset the chance of the drive breaking
        dimIdSaver = assert(io.open("/destinyAI/backup/dimension", "r")) -- set the destination of the next warp
        destiny.setDestination(tonumber(dimIdSaver:read()))
        dimIdSaver:close()
        dimIdSaver.setCommand(" ") -- clear dimId from external storage
        dimIdSaver = assert(io.open("/destinyAI/backup/dimension", "w"))
        dimIdSaver:write(" ")
        dimIdSaver:close()
        actualChance = tonumber(m.random((maxftlBreakChance + 2) , 100)) -- generate actual chance
        ftlStatusBroken = false -- reset drive broken state
        ftlDriveStatusWasFixed = false -- reset drive fixed state
    end

    local function autopilotSetCourse()
        if actualChance < ftlBreakChance and not ftlDriveStatusWasFixed then
            -- ftl drive breaks and you get stranded in the middle of space
            autopilotFtlMalfuction()
            if devMode then print("FTl will brake now") end
        elseif ftlDriveStatusWasFixed then
            -- the drive just got fixed now returning to course
            autopilotReturnToCourse()
            if devMode then print("FTL was fixed") end
        else
            local systemJumpChance = tonumber(m.random(1, 100)) -- genereate change to jump
            if systemJumpChance < sameSystemJump
            then destinyJumpLimit = stayInSystem -- jump to same system
            else destinyJumpLimit = leaveSystem -- jump to different system
            end
            local position = tonumber(destiny.currentPlanet()) -- get the ship's current spatial location
            -- checking for a position that the ship can jump to
            local failed = true
            while failed do
                if position == 0 then position = position + 1 end
                position = position + 1
                if position > lastStopID then position = firstStopID end
                if destiny.setDestination(position) then failed = false end
                if tonumber(destiny.getTravelCost()) < destinyJumpLimit then failed = true end
                os.sleep(.5)
                if devmode then print("Warp is set to this ID: " .. destiny.getDestination()) end
            end
        end
    end

    local function destinyCheck()
        -- setting the fake position of the gate so it thinks that Destiny is Warping
        console.setCommand("jsg sgsetfakepos " .. fakeDimPos .. " " .. warpDimID .. " " .. destinyGatePos)
        console.executeCommand()

        -- setting of the alarm so that everybody knows that FTL is broken
        siren.setRange(15)
        siren.setAlarm("destiny_alarm")
        ftlIsActive = destiny.isInWarp()
        if rs.getInput(rsFtlChecker) > 0 then
            -- broke the ftl drive
            ftlStatusBroken = true
        else
            -- resetting the chance of the drive breaking
            ftlStatusBroken = false
            ftlBreakChance = tonumber(m.random(minftlBreakChance, maxftlBreakChance))
            chanceSaver = assert(io.open("/destinyAI/backup/chance", "r"))
            actualChance = tonumber(chanceSaver:read())
            chanceSaver:close()
            if destiny.getDestination() == ftlMalfunctionDim then
                dimIdSaver = assert(io.open("/destinyAI/backup/dimension", "r"))
                id = tonumber(dimIdSaver:read())
                dimIdSaver:close()
            else
                id = destiny.currentPlanet()
                print(id)
                if id == 0 then id = id + 1 end --------------------------------------------------------------- rewrite to id = id + 1
                jumpClockSaver = assert(io.open("/destinyAI/backup/countdown", "r"))
                clock.setCountdown(tonumber(jumpClockSaver:read()))
                jumpClockSaver:close()                       
                -- setting the fake position of the gate so it thinks it is on the planet the ship is orbiting
                console.setCommand("jsg sgsetfakepos " .. fakeDimPos .. " " .. fakeDim[id] .. " " .. destinyGatePos)
                console.executeCommand()
            end
        end
    end

    local function missionParameters()
            if not f.isDirectory("/destinyAI/backup") then -- Creates `/destinyAI/backup` directory, if it doesn't already exist
                print("Creating \"/destinyAI/backup\" directory")
                local success, msg = f.makeDirectory("/destinyAI/backup")
                if success == nil then
                    io.stderr:write("Failed to created \"/destinyAI/backup\" directory, "..msg)
                    os.exit(false)
                end
            end     
        if not f.exists("/destinyAI/backup/countdown") then      -- system check if file for saving entries exists 
            jumpClockSaver = io.open("/destinyAI/backup/countdown","w")
            jumpClockSaver:write(returnToCourseTimer)
            jumpClockSaver:close()
        end
        if not f.exists("/destinyAI/backup/chance") then         -- system check if file for saving entries exists
            chanceSaver = io.open("/destinyAI/backup/chance","w")
            chanceSaver:write(m.random((maxftlBreakChance + 2), maxTotalChance))
            chanceSaver:close()
        end
        while ftlIsActive do -- jumping loop (only boot up sequence)
            os.sleep(.1)
            ftlIsActive = destiny.isInWarp()
        end
        if not f.exists("/destinyAI/backup/dimension") then      -- system check if file for saving entries exists
            dimIdSaver = io.open("/destinyAI/backup/dimension","w")
            dimIdSaver:write(destiny.currentPlanet())
            dimIdSaver:close()
        end
    end

-- End of Destiny´s AI Functions ------------------------------------------
-- End of Functions -----------------------------------------------------------

-- Events ---------------------------------------------------------------------
    events = {
    interrupted = event.listen("interrupted", function()
        mainLoop = false
        os.sleep(.5)
    end),

    -- clock finishes countdown
    clock_end = event.listen("countdown_zero", function(_)
        if devMode then print("Timed Out!") end
        -- applies ftl entry effect for players within 500 block radius
        console.setCommand("jsg destinyftl " .. destinyGatePos .. " " .. effectRadius)
        console.executeCommand()
        os.sleep(.5)
        -- setting the fake position of the gate so it thinks that Destiny is Warping
        console.setCommand("jsg sgsetfakepos " .. fakeDimPos .. " " .. warpDimID .. " " .. destinyGatePos)
        console.executeCommand()
        destiny.warp()
    end),

    --clock save every 10s remaining ticks
    clock_10s = event.listen("countdown_ten_seconds", function(_)
        jumpClockSaver = assert(io.open("/destinyAI/backup/countdown", "w"))
        jumpClockSaver:write(clock.remainingTicks)
        jumpClockSaver:close()
    end),

    -- clear remaing ticks from file (after clock turn off)
    clock_restart = event.listen("countdown_reset", function(_)
        jumpClockSaver = assert(io.open("/destinyAI/backup/countdown", "w"))
        jumpClockSaver:write(" ")
        jumpClockSaver:close()
    end),

    -- destiny just warped
    destiny_warped = event.listen("warpFinished", function(_, dim)
        -- applies ftl exit effect for players within 500 block radius
        console.setCommand("jsg destinyftl " .. destinyGatePos .. " " .. effectRadius .. " out")
        console.executeCommand()
        if devMode then print("Destiny left FTL") end
        if ftlStatusBroken then destinyAlarm() -- the drive broke go fix it
        else -- setting the fake position of the gate so it thinks it is on the planet the ship is orbiting
            console.setCommand("jsg sgsetfakepos " .. fakeDimPos .. " " .. fakeDim[id] .. " " .. destinyGatePos)
            console.executeCommand()
            -- set timer random remain ticks Value (defined in config)
            setTimer()
            -- set course for the next planet
            autopilotSetCourse()
            -- set the chance of the drive breaking
            setChance()
        end
    end)
    }

-- End of Events --------------------------------------------------------------
    missionParameters()
    destinyCheck()

-- Mainloop -------------------------------------------------------------------
    while mainLoop do os.sleep(0.1) end

-- End of Mainloop ------------------------------------------------------------

-- Closing procedure ----------------------------------------------------------
    for k,v in pairs(events) do
        event.cancel(v)
    end
    print("All events cancelled")
-- End of Clossing procedure --------------------------------------------------


--[[ Notes
rewrite to id = id + 1 (line 186)
move ftl fly check into missionParameters() function - this is needed!!!!!   (line 197)
earth warp stuck... add if currentPlanet() == 0 then currentPlanet = 1 end  or check why destiny dont want to jump to any other dim
move events below initialization phase   ?? - Test it maybe its not necessary
creat program that delete directory /destinyAI/backup


    Done:
    Creat Installer
    creat folder system - root directory AI
                - directory for saving variables /AI/Backup
    creat folder check /creat system

]]