--- ${title}

---@author ${author}
---@version r_version_r
---@date 09/12/2020

InitRoyalMod(Utils.getFilename("rmod/", g_currentModDirectory))
InitRoyalUtility(Utils.getFilename("utility/", g_currentModDirectory))

LoaderVehiclesAI = RoyalMod.new(r_debug_r, false)

function LoaderVehiclesAI:onValidateVehicleTypes(_, _, _, addSpecializationByVehicleType, _)
    addSpecializationByVehicleType("aiLoaderVehicle", "loaderVehicle")
end
