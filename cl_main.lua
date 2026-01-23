local Config = lib.load('config')
local FREE_CAM
local offsetRotX, offsetRotY, offsetRotZ = 0.0, 0.0, 0.0
local speed = 1.0
local rotSpeed = 2.0
local currFilter = 1
local camActive = false
local barsOn = false
local currFov = 50.0
local precision = 1.0

local vorpCore = nil

local function getCore()
    if vorpCore then return vorpCore end
    local success, result = pcall(function()
        return exports.vorp_core:GetCore()
    end)
    if success then vorpCore = result end
    return vorpCore
end

local function notify(message)
    local core = getCore()
    if core and core.NotifyRightTip then
        core.NotifyRightTip(message, 3000)
        return
    end
    TriggerEvent("vorp:TipRight", message, 3000)
end

local function toggleMap()
    local isRadarVisible = not IsRadarHidden()
    DisplayRadar(not isRadarVisible)
end

local function toggleBars()
    barsOn = not barsOn
    if barsOn then
        CreateThread(function()
            while barsOn do
                DrawRect(0.5, 0.94, 1.0, 0.12, 0, 0, 0, 255)
                DrawRect(0.5, 0.06, 1.0, 0.12, 0, 0, 0, 255)
                Wait(0)
            end
        end)
    end
end

local function resetEverything()
    FreezeEntityPosition(PlayerPedId(), false)
    if FREE_CAM and DoesCamExist(FREE_CAM) then
        RenderScriptCams(false, false, 0, true, false)
        DestroyCam(FREE_CAM, false)
    end
    offsetRotX = 0.0
    offsetRotY = 0.0
    offsetRotZ = 0.0
    speed = 1.0
    rotSpeed = 2.0
    currFov = 50.0
    currFilter = 1
    DisplayRadar(true)
    ClearTimecycleModifier()
    FREE_CAM = nil
    precision = 1.0
    barsOn = false
end

local function setNewFov(change)
    if not DoesCamExist(FREE_CAM) then return end
    local currentFov = GetCamFov(FREE_CAM)
    local newFov = currentFov + change
    if newFov >= Config.MinFov and newFov <= Config.MaxFov then
        SetCamFov(FREE_CAM, newFov)
    end
end

local function processNewPos(x, y, z)
    local newPos = {x = x, y = y, z = z}
    local moveSpeed = 0.1 * speed

    local function updatePosition(multX, multY, multZ, direction)
        newPos.x = newPos.x + direction * moveSpeed * multX
        newPos.y = newPos.y - direction * moveSpeed * multY
    end

    if IsDisabledControlPressed(1, 0x8FD015D8) then
        updatePosition(Sin(offsetRotZ), Cos(offsetRotZ), Sin(offsetRotX), -1)
    elseif IsDisabledControlPressed(1, 0xD27782E3) then
        updatePosition(Sin(offsetRotZ), Cos(offsetRotZ), Sin(offsetRotX), 1)
    end

    if IsDisabledControlPressed(1, 0x7065027D) then
        updatePosition(Sin(offsetRotZ + 90.0), Cos(offsetRotZ + 90.0), Sin(offsetRotY), -1)
    elseif IsDisabledControlPressed(1, 0xB4E465B4) then
        updatePosition(Sin(offsetRotZ + 90.0), Cos(offsetRotZ + 90.0), Sin(offsetRotY), 1)
    end

    if IsDisabledControlPressed(1, 0xD9D0E1C0) then
        newPos.z = newPos.z + moveSpeed
    elseif IsDisabledControlPressed(1, 0x26E9DC00) then
        newPos.z = newPos.z - moveSpeed
    end

    if IsDisabledControlPressed(1, 0xA5BDCD3C) then
        setNewFov(-1.0)
    elseif IsDisabledControlPressed(1, 0x430593AA) then
        setNewFov(1.0)
    end

    offsetRotX = offsetRotX - (GetDisabledControlNormal(1, 0xD2047988) * precision * 8.0)
    offsetRotZ = offsetRotZ - (GetDisabledControlNormal(1, 0xA987235F) * precision * 8.0)

    if IsDisabledControlPressed(1, 0xDE794E3E) then
        offsetRotY = offsetRotY - precision
    elseif IsDisabledControlPressed(1, 0xCEFD9220) then
        offsetRotY = offsetRotY + precision
    end

    offsetRotX = math.clamp(offsetRotX, -90.0, 90.0)
    offsetRotY = math.clamp(offsetRotY, -90.0, 90.0)
    offsetRotZ = offsetRotZ % 360.0

    return newPos
end

local function processCamControls()
    DisableAllControlActions(0)
    DisableAllControlActions(1)
    DisableAllControlActions(2)
    
    EnableControlAction(0, 0x1F6D95E5, true) -- F4
    EnableControlAction(1, 0x1F6D95E5, true)
    EnableControlAction(2, 0x1F6D95E5, true)

    local camCoords = GetCamCoord(FREE_CAM)
    local newPos = processNewPos(camCoords.x, camCoords.y, camCoords.z)

    SetCamCoord(FREE_CAM, newPos.x, newPos.y, newPos.z)
    SetCamRot(FREE_CAM, offsetRotX, offsetRotY, offsetRotZ, 2)

    local ped = PlayerPedId()
    local currentPos = GetEntityCoords(ped)
    if #(currentPos - vector3(newPos.x, newPos.y, newPos.z)) > Config.MaxDistance then
        if not IsEntityDead(ped) then
            notify('You went too far using the free camera.')
        end
        camActive = false
        lib.hideMenu()
    end
end

local function toggleCam()
    camActive = not camActive
    local ped = PlayerPedId()
    
    if camActive then
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        
        FREE_CAM = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', coords.x, coords.y, coords.z + 0.5, 0.0, 0.0, 0.0, currFov, false, 0)
        SetCamRot(FREE_CAM, 0.0, 0.0, heading, 2)
        SetCamActive(FREE_CAM, true)
        RenderScriptCams(true, false, 0, true, false)
        FreezeEntityPosition(ped, true)
        
        offsetRotZ = heading

        CreateThread(function()
            while camActive do
                processCamControls()
                Wait(0)
            end
            FreezeEntityPosition(PlayerPedId(), false)
            resetEverything()
        end)
        
        notify('Freecam enabled.')
    else
        FreezeEntityPosition(ped, false)
        notify('Freecam disabled.')
    end
end

RegisterCommand(Config.CommandName, function()
    lib.registerMenu({
        id = 'cinematic_cam_menu',
        title = 'Cinematic Free Camera',
        position = 'top-right',
        onSideScroll = function(selected, scrollIndex, args)
            if selected == 2 then
                local filter = Config.Filters[scrollIndex]
                if filter == 'None' then
                    ClearTimecycleModifier()
                else
                    SetTimecycleModifier(filter)
                end
                currFilter = scrollIndex
            end
        end,
        onCheck = function(selected, checked, args)
            if selected == 1 then
                toggleCam()
            elseif selected == 3 then
                toggleBars()
            elseif selected == 4 then
                toggleMap()
            end
        end,
        options = {
            { label = 'Toggle Camera', checked = camActive, icon = 'camera', description = 'W/A/S/D move, Space/Z up/down, Q/E roll, Scroll to zoom' },
            { label = 'Camera Filters', values = Config.Filters, icon = 'palette', defaultIndex = currFilter, description = 'Use arrow keys to navigate filters.' },
            { label = 'Toggle Black Bars', checked = barsOn, icon = 'film', description = 'Toggle cinematic bars.' },
            { label = 'Toggle Minimap', checked = not IsRadarHidden(), icon = 'map', description = 'Toggle the minimap.' },
        }
    }, function(selected, scrollIndex, args)
        if selected == 2 then
            ClearTimecycleModifier()
            currFilter = 1
        end
    end)
    lib.showMenu('cinematic_cam_menu')
end)

AddEventHandler('gameEventTriggered', function(event, data)
    if event ~= 'CEventNetworkEntityDamage' then return end
    local victim, victimDied = data[1], data[4]
    if not IsPedAPlayer(victim) then return end
    if victimDied and NetworkGetPlayerIndexFromPed(victim) == PlayerId() and (IsPedDeadOrDying(victim, true) or IsPedFatallyInjured(victim)) then
        if DoesCamExist(FREE_CAM) then
            camActive = false
            resetEverything()
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    camActive = false
    barsOn = false
    FreezeEntityPosition(PlayerPedId(), false)
    resetEverything()
end)