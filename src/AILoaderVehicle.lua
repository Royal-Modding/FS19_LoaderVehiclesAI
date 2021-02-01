--
-- ${title}
--
-- @author ${author}
-- @version ${version}
-- @date 09/12/2020

AILoaderVehicle = {}

AILoaderVehicle.MOD_NAME = g_currentModName

function AILoaderVehicle.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(AIVehicle, specializations) and SpecializationUtil.hasSpecialization(Motorized, specializations) and SpecializationUtil.hasSpecialization(AIImplement, specializations) and
        SpecializationUtil.hasSpecialization(Shovel, specializations) and
        SpecializationUtil.hasSpecialization(Dischargeable, specializations)
end

function AILoaderVehicle.registerFunctions(vehicleType)
end

function AILoaderVehicle.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanStartAIVehicle", AILoaderVehicle.getCanStartAIVehicle)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanBeSelected", AILoaderVehicle.getCanBeSelected)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getAINeedsTrafficCollisionBox", AILoaderVehicle.getAINeedsTrafficCollisionBox)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getAIRequiresTurnOn", AILoaderVehicle.getAIRequiresTurnOn)

    SpecializationUtil.registerOverwrittenFunction(vehicleType, "updateAI", AILoaderVehicle.updateAI)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "updateAILowFrequency", AILoaderVehicle.updateAILowFrequency)
end

function AILoaderVehicle.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", AILoaderVehicle)
    SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", AILoaderVehicle)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", AILoaderVehicle)

    SpecializationUtil.registerEventListener(vehicleType, "onAIStart", AILoaderVehicle)
    SpecializationUtil.registerEventListener(vehicleType, "onAIEnd", AILoaderVehicle)
end

function AILoaderVehicle:onLoad(savegame)
    self.spec_aiLoaderVehicle = self[string.format("spec_%s.aiLoaderVehicle", AILoaderVehicle.MOD_NAME)]
    local spec = self.spec_aiLoaderVehicle
    spec.canDoLoadingWork = false
    spec.speed = 1.5
end

function AILoaderVehicle:onPostLoad(savegame)
    local spec = self.spec_aiLoaderVehicle
    spec.shovelNode = self.spec_shovel.shovelNodes[1]

    -- fix for holmer terra felis 2
    local x, y, z = getTranslation(spec.shovelNode.node)
    if string.format("%.2f", x) == "0.00" and string.format("%.2f", y) == "-0.98" and string.format("%.2f", z) == "2.27" then
        setTranslation(spec.shovelNode.node, x, y, z + 2.056)
    end

    spec.frontArea = {}
    spec.frontArea.node = spec.shovelNode.node
    spec.frontArea.length = spec.shovelNode.length / 1.5
    spec.frontArea.offset = spec.frontArea.length
    spec.frontArea.width = spec.shovelNode.width
    spec.frontArea.active = false
    spec.rearArea = {}
    spec.rearArea.node = spec.shovelNode.node
    spec.rearArea.length = spec.shovelNode.length / 2
    spec.rearArea.offset = -spec.rearArea.length
    spec.rearArea.length = spec.rearArea.length * 1.1
    spec.rearArea.width = spec.shovelNode.width
    spec.rearArea.active = false
end

---Updates the AI logic that is possible to be run at a lower frequency (by default every 4 frames)
-- Primarly this is the evaluation of the drive strategies (collsion, etc.)
-- Runs only on server
-- @param float dt time since last call in ms
-- @includeCode
function AILoaderVehicle:updateAILowFrequency(superFunc, dt)
    if superFunc ~= nil then
        superFunc(self, dt)
    end
    local spec = self.spec_aiLoaderVehicle
    if not spec.canDoLoadingWork and self:getIsAIActive() and self:getCanAIVehicleContinueWork() then
        if not self:getIsAIImplementInLine() then
            self:aiImplementStartLine()
        else
            spec.canDoLoadingWork = true
        end
    end
    if spec.canDoLoadingWork then
        if self:getIsDischargeNodeActive(spec.currentDischargeNode) and self:getCanDischargeToObject(spec.currentDischargeNode) and self:getCanToggleDischargeToObject() then
            if self.spec_dischargeable.currentDischargeState == Dischargeable.DISCHARGE_STATE_OFF then
                self:setDischargeState(Dischargeable.DISCHARGE_STATE_OBJECT)
            end
        end
        local areas = {spec.frontArea, spec.rearArea}
        for _, area in pairs(areas) do
            local sx, _, sz = localToWorld(area.node, -area.width, 0, area.offset - area.length)
            local wx, _, wz = localToWorld(area.node, area.width, 0, area.offset - area.length)
            local hx, _, hz = localToWorld(area.node, -area.width, 0, area.offset + area.length)
            area.active = DensityMapHeightUtil.getFillTypeAtArea(sx, sz, wx, wz, hx, hz) ~= FillType.UNKNOWN
        end
    end
end

---Updates the AI logic that is needed to be called at a regular frequency (by default every 2 frames)
-- Primarly this is wheel turning / motor logic
-- Runs only on server
-- @param float dt time since last call in ms
-- @includeCode
function AILoaderVehicle:updateAI(superFunc, dt)
    if superFunc ~= nil then
        superFunc(self, dt)
    end
    local spec = self.spec_aiLoaderVehicle
    if spec.canDoLoadingWork then
        if spec.frontArea.active then
            local level = self:getFillUnitFillLevel(spec.shovelNode.fillUnitIndex)
            local capacity = self:getFillUnitCapacity(spec.shovelNode.fillUnitIndex) * 0.85
            if not spec.rearArea.active and level < capacity then
                AIVehicleUtil.driveToPoint(self, dt, spec.speed * 2, true, true, 0, 0, spec.speed, true)
            else
                AIVehicleUtil.driveToPoint(self, dt, 0, false, true, 0, 0, 0, true)
            end
        else
            if not spec.rearArea.active then
                self:stopAIVehicle(AIVehicle.STOP_REASON_REGULAR, true)
            end
        end
    end
end

function AILoaderVehicle:onUpdate(dt)
    local spec = self.spec_aiLoaderVehicle
    if VehicleDebug.state == VehicleDebug.DEBUG_AI then
        Utility.drawDebugRectangle(spec.frontArea.node, -spec.frontArea.width, spec.frontArea.width, spec.frontArea.offset - spec.frontArea.length, spec.frontArea.offset + spec.frontArea.length, 0.5, true, 1, 0, 0, 0, 1, 0, spec.frontArea.active)
        Utility.drawDebugRectangle(spec.rearArea.node, -spec.rearArea.width, spec.rearArea.width, spec.rearArea.offset - spec.rearArea.length, spec.rearArea.offset + spec.rearArea.length, 0.5, true, 1, 0, 0, 0, 1, 0, spec.rearArea.active)
    end
end

function AILoaderVehicle:onAIStart()
    local spec = self.spec_aiLoaderVehicle
    if self.isServer then
        spec.currentDischargeNode = self.spec_dischargeable.currentDischargeNode
        spec.shovelFillLitersPerSecondBackup = spec.shovelNode.fillLitersPerSecond
        -- set shovel fill speed same as unload speed to make everything much smoother
        if spec.shovelNode.fillLitersPerSecond > spec.currentDischargeNode.emptySpeed then
            spec.shovelNode.fillLitersPerSecond = spec.currentDischargeNode.emptySpeed * 1.1
        end
    end
end

function AILoaderVehicle:onAIEnd()
    local spec = self.spec_aiLoaderVehicle
    if self.isServer then
        spec.canDoLoadingWork = false
        self:aiImplementEndLine()
        spec.shovelNode.fillLitersPerSecond = spec.shovelFillLitersPerSecondBackup
    end
end

function AILoaderVehicle:getCanStartAIVehicle(superFunc)
    if not self:getIsMotorStarted() then
        return false
    end

    if g_currentMission.disableAIVehicle then
        return false
    end

    if AIVehicle.getNumHirablesHiredByFarm ~= nil then
        if AIVehicle.getNumHirablesHiredByFarm(self:getOwnerFarmId()) >= (g_currentMission.maxNumHirables * 2) then
            return false
        end
    else
        if AIVehicle.numHirablesHired >= g_currentMission.maxNumHirables then
            return false
        end
    end

    return true
end

function AILoaderVehicle:getCanBeSelected(superFunc)
    return true
end

function AILoaderVehicle:getAINeedsTrafficCollisionBox(superFunc)
    return false
end

function AILoaderVehicle:getAIRequiresTurnOn()
    return true
end
