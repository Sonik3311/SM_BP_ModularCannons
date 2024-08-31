-- Just for storing/editing shell data and giving it to players

dofile "$CONTENT_DATA/Scripts/shell_uuid.lua"

Shell = class()

function Shell:server_onCreate()
end

function Shell:client_onCreate()
    self.cl = {}
    self.cl.gui_apfsds = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/Shell_Settings_apfsds.layout", false)
    self.cl.gui_he = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/Shell_Settings_he.layout", false)
    self.cl.gui_ap = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/Shell_Settings_ap.layout", false)
    self.cl.gui_aphe = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/Shell_Settings_aphe.layout", false)
    self.cl.gui_apfsds:setButtonCallback("Button_APHE", "gui_change_to_APHE")
    self.cl.gui_apfsds:setButtonCallback("Button_AP", "gui_change_to_AP")
    self.cl.gui_apfsds:setButtonCallback("Button_HE", "gui_change_to_HE")
    self.cl.gui_ap:setButtonCallback("Button_APHE", "gui_change_to_APHE")
    self.cl.gui_ap:setButtonCallback("Button_APFSDS", "gui_change_to_APFSDS")
    self.cl.gui_ap:setButtonCallback("Button_HE", "gui_change_to_HE")
    self.cl.gui_aphe:setButtonCallback("Button_APFSDS", "gui_change_to_APFSDS")
    self.cl.gui_aphe:setButtonCallback("Button_AP", "gui_change_to_AP")
    self.cl.gui_aphe:setButtonCallback("Button_HE", "gui_change_to_HE")
    self.cl.gui_he:setButtonCallback("Button_APHE", "gui_change_to_APHE")
    self.cl.gui_he:setButtonCallback("Button_AP", "gui_change_to_AP")
    self.cl.gui_he:setButtonCallback("Button_APFSDS", "gui_change_to_APFSDS")
    self.cl.gui = self.cl.gui_apfsds

    self.cl.gui_apfsds:setOnCloseCallback("cl_onGuiClosed")
    self.cl.gui_ap:setOnCloseCallback("cl_onGuiClosed")
    self.cl.gui_aphe:setOnCloseCallback("cl_onGuiClosed")
    self.cl.gui_he:setOnCloseCallback("cl_onGuiClosed")
end

function Shell.client_onInteract(self, character)
    self.network:sendToServer("sv_transfer_to_carry")
end

function Shell:sv_transfer_to_carry(data, player)
    local character = player.character
    local uuid = #self.interactable:getPublicData() > 1 and obj_generic_acammo or obj_generic_apfsds
    print(#self.interactable:getPublicData(), uuid)
    sm.container.beginTransaction()
    sm.container.collect(player:getCarry(), uuid, 1, true)
    if sm.container.endTransaction() then
        print("World -> Carry")
        local pd = character:getPublicData()
        pd.carried_shell = self.interactable:getPublicData()
        print(pd)
        character:setPublicData(pd)
        self.shape:destroyShape()
    end
end

function Shell.client_canTinker(self, character)
    return true
end

function Shell.client_canInteract(self, character)
    return true
end

-- TODO: Move to shapeset
function Shell.server_canErase(self)
    return false
end

function Shell.client_canErase(self)
    return false
end

function Shell:cl_onGuiClosed()
    if self.cl.gui_changed then -- hack
        self.cl.gui:open()
    end
    self.cl.gui_changed = false
    print("gui closed")
end

function Shell.client_onTinker(self, character, state)
    if state == true then
        self.cl.gui:open()
    end
    print("onTinker")
end

-------------------------------------------------------------------------------
--[[                            Network Server                             ]] --
-------------------------------------------------------------------------------

function Shell:sv_edit_ammo(data)
    local ammo_index = data.ammo_index
    local from_scratch = data.from_scratch
    local ammo_edits = data.edits
    local ammo = self.interactable:getPublicData()

    if from_scratch then
        ammo_edits.caliber = ammo_edits.caliber or ammo[ammo_index].caliber
        ammo[ammo_index] = ammo_edits
        self.interactable:setPublicData(ammo)
        return
    end

    for property, value in pairs(ammo_edits) do
        ammo[ammo_index][property] = value
    end
    self.interactable:setPublicData(ammo)
end

-------------------------------------------------------------------------------
--[[                                 GUI                                   ]] --
-------------------------------------------------------------------------------

function Shell:gui_change_to_APFSDS()
    print("change to APFSDS")
    self.cl.gui:close()
    self.cl.gui = self.cl.gui_apfsds
    self.cl.gui:open()
    self.cl.gui_changed = true

    local ammo_index = 1
    self.network:sendToServer("sv_edit_ammo", {
        ammo_index = ammo_index,
        from_scratch = true,
        edits = {
            type = "APFSDS",
            caliber = nil,
            parameters = {
                propellant = 200,
                projectile_mass = 12,
                diameter = 27,
                penetrator_length = 700,
                penetrator_density = 17800
            }
        }
    })
end

function Shell:gui_change_to_AP()
    print("change to AP")
    self.cl.gui:close()
    self.cl.gui = self.cl.gui_ap
    self.cl.gui:open()
    self.cl.gui_changed = true

    local ammo_index = 1
    self.network:sendToServer("sv_edit_ammo", {
        ammo_index = ammo_index,
        from_scratch = true,
        edits = {
            type = "AP",
            calibre = nil,
            parameters = {
                propellant = 130,
                projectile_mass = 10,
                is_apcbc = true
            }
        }
    })
end

function Shell:gui_change_to_APHE()
    print("change to APHE")
    self.cl.gui:close()
    self.cl.gui = self.cl.gui_aphe
    self.cl.gui:open()
    self.cl.gui_changed = true
    local ammo_index = 1
    self.network:sendToServer("sv_edit_ammo", {
        ammo_index = ammo_index,
        from_scratch = true,
        edits = {
            type = "APHE",
            caliber = nil,
            parameters = {
                propellant = 120,
                projectile_mass = 100,
                is_apcbc = true,
                explosive_mass = 0.365, --kg
            },
            fuse = {
                active = false,
                delay = 0.001,     --seconds
                trigger_depth = 10 --mm
            }
        }
    })
end

function Shell:gui_change_to_HE()
    print("change to HE")
    self.cl.gui:close()
    self.cl.gui = self.cl.gui_he
    self.cl.gui:open()
    self.cl.gui_changed = true
    local ammo_index = 1
    self.network:sendToServer("sv_edit_ammo", {
        ammo_index = ammo_index,
        from_scratch = true,
        edits = {
            type = "HE",
            caliber = nil,
            parameters = {
                propellant = 50,
                projectile_mass = 15,
                explosive_mass = 1000
            }
        }
    })
end
