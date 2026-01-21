local Config = lib.load('config')
local FREE_CAM
local offsetRotX, offsetRotY, offsetRotZ = 0.0, 0.0, 0.0
local precision = 1.0
local speed = 1.0
local currFilter = 1
local camActive = false
local dofOn = false
local dofStrength = 0.5
local dofFar = 0.5
local dofNear = 0.10
local barsOn = false
local currFov = 50.0

local vorpCore = nil

local function getCore()
    if vorpCore then return vorpCore end
    local success, result = pcall(function()
        return exports.vorp_core:GetCore()
    end)
    if success then vorpCore = result end
    return vorpCore
end

local function notify(message, notifType)
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
    ClearFocus()
    if FREE_CAM and DoesCamExist(FREE_CAM) then
        SetCamUseShallowDofMode(FREE_CAM, false)
        RenderScriptCams(false, false, 0, true, false)
        DestroyCam(FREE_CAM, false)
    end
    offsetRotX = 0.0
    offsetRotY = 0.0
    offsetRotZ = 0.0
    speed = 1.0
    precision = 1.0
    currFov = 50.0
    currFilter = 1
    ClearTimecycleModifier()
    FREE_CAM = nil
    dofStrength = 0.5
    dofFar = 0.5
    dofNear = 0.10
    dofOn = false
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

local function toggleDof()
    dofOn = not dofOn
    if dofOn then
        if DoesCamExist(FREE_CAM) then
            SetCamUseShallowDofMode(FREE_CAM, true)
            SetCamNearDof(FREE_CAM, dofNear)
            SetCamFarDof(FREE_CAM, dofFar)
            SetCamDofStrength(FREE_CAM, dofStrength)
        end
    else
        dofStrength = 0.5
        dofFar = 0.5
        dofNear = 0.10
        if DoesCamExist(FREE_CAM) then
            SetCamNearDof(FREE_CAM, dofNear)
            SetCamFarDof(FREE_CAM, dofFar)
            SetCamDofStrength(FREE_CAM, dofStrength)
            SetCamUseShallowDofMode(FREE_CAM, false)
        end
        ClearFocus()
    end
end

local function processNewPos(x, y, z)
    local newPos = { x = x, y = y, z = z }
    local moveSpeed = 0.1 * speed

    local function updatePosition(multX, multY, direction)
        newPos.x = newPos.x + direction * moveSpeed * multX
        newPos.y = newPos.y - direction * moveSpeed * multY
    end

    if IsDisabledControlPressed(1, 32) then
        updatePosition(math.sin(math.rad(offsetRotZ)), math.cos(math.rad(offsetRotZ)), -1)
    elseif IsDisabledControlPressed(1, 33) then
        updatePosition(math.sin(math.rad(offsetRotZ)), math.cos(math.rad(offsetRotZ)), 1)
    end

    if IsDisabledControlPressed(1, 34) then
        updatePosition(math.sin(math.rad(offsetRotZ + 90.0)), math.cos(math.rad(offsetRotZ + 90.0)), -1)
    elseif IsDisabledControlPressed(1, 35) then
        updatePosition(math.sin(math.rad(offsetRotZ + 90.0)), math.cos(math.rad(offsetRotZ + 90.0)), 1)
    end

    if IsDisabledControlPressed(1, 22) then
        newPos.z = newPos.z + moveSpeed
    elseif IsDisabledControlPressed(1, 36) then
        newPos.z = newPos.z - moveSpeed
    end

    if IsDisabledControlPressed(1, 21) then
        if IsDisabledControlPressed(1, 15) then
            speed = math.min(speed + 0.1, Config.MaxSpeed)
        elseif IsDisabledControlPressed(1, 14) then
            speed = math.max(speed - 0.1, Config.MinSpeed)
        end
    else
        if IsDisabledControlPressed(1, 15) then
            setNewFov(-1.0)
        elseif IsDisabledControlPressed(1, 14) then
            setNewFov(1.0)
        end
    end

    offsetRotX = offsetRotX - (GetDisabledControlNormal(1, 2) * precision * 8.0)
    offsetRotZ = offsetRotZ - (GetDisabledControlNormal(1, 1) * precision * 8.0)

    if IsDisabledControlPressed(1, 44) then
        offsetRotY = offsetRotY - precision
    elseif IsDisabledControlPressed(1, 38) then
        offsetRotY = offsetRotY + precision
    end

    offsetRotX = math.max(-90.0, math.min(90.0, offsetRotX))
    offsetRotY = math.max(-90.0, math.min(90.0, offsetRotY))
    offsetRotZ = offsetRotZ % 360.0

    return newPos
end

local function processCamControls()
    DisableFirstPersonCamThisFrame()

    local camCoords = GetCamCoord(FREE_CAM)
    local newPos = processNewPos(camCoords.x, camCoords.y, camCoords.z)
    SetFocusArea(newPos.x, newPos.y, newPos.z, 0.0, 0.0, 0.0)
    SetCamCoord(FREE_CAM, newPos.x, newPos.y, newPos.z)
    SetCamRot(FREE_CAM, offsetRotX, offsetRotY, offsetRotZ, 2)

    for _, v in ipairs(Config.DisabledControls) do
        DisableControlAction(0, v, true)
    end

    local ped = PlayerPedId()
    local currentPos = GetEntityCoords(ped)
    if #(currentPos - vector3(newPos.x, newPos.y, newPos.z)) > Config.MaxDistance then
        if not IsEntityDead(ped) then
            notify('You went too far using the free camera.', 'error')
        end
        camActive = false
        lib.hideMenu()
    end

    if dofOn then
        SetUseHiDof()
    end
end

local function toggleCam()
    camActive = not camActive
    if camActive then
        ClearFocus()
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        FREE_CAM = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, currFov)
        SetCamActive(FREE_CAM, true)
        RenderScriptCams(true, false, 0, true, false)
        SetCamAffectsAiming(FREE_CAM, false)

        CreateThread(function()
            while camActive do
                processCamControls()
                Wait(0)
            end
            resetEverything()
        end)
    end
end

RegisterCommand(Config.CommandName, function()
    lib.registerMenu({
        id = 'cinematic_cam_menu',
        title = 'Cinematic Camera',
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
            elseif selected == 6 then
                dofNear = tonumber(Config.NearDof[scrollIndex])
                if DoesCamExist(FREE_CAM) then
                    SetCamNearDof(FREE_CAM, dofNear)
                end
            elseif selected == 7 then
                dofFar = tonumber(Config.FarDof[scrollIndex])
                if DoesCamExist(FREE_CAM) then
                    SetCamFarDof(FREE_CAM, dofFar)
                end
            elseif selected == 8 then
                dofStrength = tonumber(Config.StrengthDof[scrollIndex])
                if DoesCamExist(FREE_CAM) then
                    SetCamDofStrength(FREE_CAM, dofStrength)
                end
            end
        end,
        onCheck = function(selected, checked, args)
            if selected == 1 then
                toggleCam()
            elseif selected == 3 then
                toggleDof()
            elseif selected == 4 then
                toggleBars()
            elseif selected == 5 then
                toggleMap()
            end
        end,
        options = {
            { label = 'Toggle Camera', checked = camActive, icon = 'camera' },
            { label = 'Camera Filters', values = Config.Filters, icon = 'palette', defaultIndex = currFilter, description = 'Use arrow keys to navigate filters.' },
            { label = 'Toggle Depth of Field', checked = dofOn, icon = 'eye', description = 'Toggle Depth of Field effect.' },
            { label = 'Toggle Black Bars', checked = barsOn, icon = 'film', description = 'Toggle cinematic bars.' },
            { label = 'Toggle Minimap', checked = not IsRadarHidden(), icon = 'map', description = 'Toggle the minimap.' },
            { label = 'Depth of Field Near', values = Config.NearDof, icon = 'arrows-left-right', description = 'Adjust the near focus distance.' },
            { label = 'Depth of Field Far', values = Config.FarDof, icon = 'arrows-left-right', description = 'Adjust the far focus distance.' },
            { label = 'Depth of Field Strength', values = Config.StrengthDof, icon = 'arrows-left-right', description = 'Adjust the strength of the DoF effect.' },
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
    resetEverything()
end)