-- Just for storing/editing shell data and giving it to players

dofile "$CONTENT_DATA/Scripts/shell_uuid.lua"

Shell = class()

local function deep_copy(tbl)
    if tbl == nil then
        return nil
    end
    local copy = {}
    for key, value in pairs(tbl) do
        local var_type = type(value)
        if var_type ~= 'table' then
            if var_type == "Vec3" then
                copy[key] = sm.vec3.new(value.x, value.y, value.z)
            elseif var_type == "Quat" then
                copy[key] = sm.quat.new(value.x, value.y, value.z, value.w)
            elseif var_type == "Color" then
                copy[key] = sm.color.new(value.r, value.g, value.b)
            elseif var_type == "Uuid" then
                copy[key] = sm.uuid.new(tostring(value))
            else
                copy[key] = value
            end
        else
            copy[key] = deep_copy(value)
        end
    end
    return copy
end


function Shell:server_onCreate()
    self.sv = {}

    self.sv.ammo = self.storage:load() or self.interactable:getPublicData()
    self.interactable:setPublicData(self.sv.ammo)
    self.sv.save_timer = 0
end

function Shell:server_onFixedUpdate(dt)
    self.sv.save_timer = math.max(-1, self.sv.save_timer - dt)
    if self.sv.save_timer <= 0 and self.sv.save_timer >= -dt then
        print("SAVE!!!!")
        self.storage:save(self.sv.ammo)
    end
end

function Shell:client_onCreate()
    self.cl = {}

    self.cl.is_apcbc = false -- to avoid desync you must desync
    self.cl.selected_shell_id = 1
    self.cl.ammo = {}
    self:cl_request_ammoInfo()

    -- help
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

    self.cl.gui_apfsds:setButtonCallback("Copy_Button", "gui_copy_shell")
    self.cl.gui_ap:setButtonCallback("Copy_Button", "gui_copy_shell")
    self.cl.gui_aphe:setButtonCallback("Copy_Button", "gui_copy_shell")
    self.cl.gui_he:setButtonCallback("Copy_Button", "gui_copy_shell")
    self.cl.gui_apfsds:setButtonCallback("Paste_Button", "gui_paste_shell")
    self.cl.gui_ap:setButtonCallback("Paste_Button", "gui_paste_shell")
    self.cl.gui_aphe:setButtonCallback("Paste_Button", "gui_paste_shell")
    self.cl.gui_he:setButtonCallback("Paste_Button", "gui_paste_shell")

    self.cl.gui_apfsds:setButtonCallback("AC_LeftButton", "gui_select_shell")
    self.cl.gui_ap:setButtonCallback("AC_LeftButton", "gui_select_shell")
    self.cl.gui_aphe:setButtonCallback("AC_LeftButton", "gui_select_shell")
    self.cl.gui_he:setButtonCallback("AC_LeftButton", "gui_select_shell")
    self.cl.gui_apfsds:setButtonCallback("AC_RightButton", "gui_select_shell")
    self.cl.gui_ap:setButtonCallback("AC_RightButton", "gui_select_shell")
    self.cl.gui_aphe:setButtonCallback("AC_RightButton", "gui_select_shell")
    self.cl.gui_he:setButtonCallback("AC_RightButton", "gui_select_shell")

    self.cl.gui_apfsds:setSliderCallback("Slider_Amount", "gui_onChange_propellant")
    self.cl.gui_apfsds:setTextChangedCallback("TextBox_Amount", "gui_onChange_propellant")
    self.cl.gui_ap:setSliderCallback("Slider_Amount", "gui_onChange_propellant")
    self.cl.gui_ap:setTextChangedCallback("TextBox_Amount", "gui_onChange_propellant")
    self.cl.gui_aphe:setSliderCallback("Slider_Amount", "gui_onChange_propellant")
    self.cl.gui_aphe:setTextChangedCallback("TextBox_Amount", "gui_onChange_propellant")
    self.cl.gui_he:setSliderCallback("Slider_Amount", "gui_onChange_propellant")
    self.cl.gui_he:setTextChangedCallback("TextBox_Amount", "gui_onChange_propellant")

    self.cl.gui_apfsds:setSliderCallback("Slider_Diameter", "gui_onChange_caliber")
    self.cl.gui_apfsds:setTextChangedCallback("TextBox_Diameter", "gui_onChange_caliber")
    self.cl.gui_ap:setSliderCallback("Slider_Diameter", "gui_onChange_caliber")
    self.cl.gui_ap:setTextChangedCallback("TextBox_Diameter", "gui_onChange_caliber")
    self.cl.gui_aphe:setSliderCallback("Slider_Diameter", "gui_onChange_caliber")
    self.cl.gui_aphe:setTextChangedCallback("TextBox_Diameter", "gui_onChange_caliber")
    self.cl.gui_he:setSliderCallback("Slider_Diameter", "gui_onChange_caliber")
    self.cl.gui_he:setTextChangedCallback("TextBox_Diameter", "gui_onChange_caliber")

    --                                                  one job...
    self.cl.gui_apfsds:setSliderCallback("Slider_APFSDS_Lenght", "gui_onChange_APFSDS_Length")
    self.cl.gui_apfsds:setTextChangedCallback("TextBox_APFSDS_Lenght", "gui_onChange_APFSDS_Length")
    self.cl.gui_apfsds:setSliderCallback("Slider_APFSDS_Diameter", "gui_onChange_APFSDS_Diameter")
    self.cl.gui_apfsds:setTextChangedCallback("TextBox_APFSDS_Diameter", "gui_onChange_APFSDS_Diameter")
    self.cl.gui_apfsds:setSliderCallback("Slider_APFSDS_Density", "gui_onChange_APFSDS_Density")
    self.cl.gui_apfsds:setTextChangedCallback("TextBox_APFSDS_Density", "gui_onChange_APFSDS_Density")

    self.cl.gui_ap:setButtonCallback("CheckBox_AP_APCBC", "gui_onChange_APCBC")
    self.cl.gui_aphe:setButtonCallback("CheckBox_APHE_APCBC", "gui_onChange_APCBC")

    self.cl.gui_aphe:setSliderCallback("Slider_APHE_Mass", "gui_onChange_APHE_explosive")
    self.cl.gui_aphe:setTextChangedCallback("TextBox_APHE_Mass", "gui_onChange_APHE_explosive")
    self.cl.gui_aphe:setTextChangedCallback("TextBox_APHE_FuseDepth", "gui_onChange_APHE_FuseDepth")
    self.cl.gui_aphe:setTextChangedCallback("TextBox_APHE_FuseDelay", "gui_onChange_APHE_FuseDelay")

    self.cl.gui_he:setSliderCallback("Slider_HE_Mass", "gui_onChange_HE_explosive")
    self.cl.gui_he:setTextChangedCallback("TextBox_HE_Mass", "gui_onChange_HE_explosive")

    self.cl.gui_apfsds:setOnCloseCallback("cl_onGuiClosed")
    self.cl.gui_ap:setOnCloseCallback("cl_onGuiClosed")
    self.cl.gui_aphe:setOnCloseCallback("cl_onGuiClosed")
    self.cl.gui_he:setOnCloseCallback("cl_onGuiClosed")
end

function Shell.client_onInteract(self, character)
    self.network:sendToServer("sv_transfer_to_carry")
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
    else
        self.network:sendToServer("sv_save")
    end
    self.cl.gui_changed = false

    print("gui closed")
end

function Shell.client_onTinker(self, character, state)
    if state == true then
        self:cl_request_ammoInfo()
        self:gui_setText()
        self:gui_set_gui_type()
        self.cl.gui:open()
    end
end

-------------------------------------------------------------------------------
--[[                            Network Server                             ]] --
-------------------------------------------------------------------------------

function Shell:sv_edit_ammo(data)
    local ammo_index = data.ammo_index
    local from_scratch = data.from_scratch
    local is_fuse_setting = data.is_fuse
    local ammo_edits = data.edits
    local ammo = self.interactable:getPublicData()

    if from_scratch then
        ammo_edits.caliber = ammo_edits.caliber or ammo[ammo_index].caliber
        ammo[ammo_index] = ammo_edits
        self.interactable:setPublicData(ammo)
        return
    end

    for property, value in pairs(ammo_edits) do
        if is_fuse_setting then
            ammo[ammo_index].fuse[property] = value
        elseif property ~= "caliber" then
            ammo[ammo_index].parameters[property] = value
        else
            ammo[ammo_index][property] = value
        end
    end
    self.interactable:setPublicData(ammo)
    self.sv.storage = ammo
    self.sv.save_timer = 2
end

function Shell:sv_sync_ammo(data, client)
    self.network:sendToClient(client, "cl_recieve_ammoInfo", self.interactable:getPublicData())
end

function Shell:sv_save()
    self.sv.save_timer = 0
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

-------------------------------------------------------------------------------
--[[                            Network Client                             ]] --
-------------------------------------------------------------------------------

function Shell:cl_request_ammoInfo()
    self.network:sendToServer("sv_sync_ammo")
end

function Shell:cl_recieve_ammoInfo(data)
    print(data)
    self.cl.ammo = data
end

-------------------------------------------------------------------------------
--[[                                 GUI                                   ]] --
-------------------------------------------------------------------------------

function Shell:gui_set_gui_type()
    if not self.cl.ammo then
        return
    end
    local id = self.cl.selected_shell_id
    if self.cl.ammo[id].type == "APFSDS" then
        self.cl.gui = self.cl.gui_apfsds
    elseif self.cl.ammo[id].type == "AP" then
        self.cl.gui = self.cl.gui_ap
    elseif self.cl.ammo[id].type == "APHE" then
        self.cl.gui = self.cl.gui_aphe
    elseif self.cl.ammo[id].type == "HE" then
        self.cl.gui = self.cl.gui_he
    end
end

function Shell:gui_setText()
    if not self.cl.ammo then
        return
    end

    local id = self.cl.selected_shell_id
    local propellant = self.cl.ammo[id].parameters.propellant
    local caliber = self.cl.ammo[id].caliber

    local apfsds_length = self.cl.ammo[id].parameters.penetrator_length
    local apfsds_density = self.cl.ammo[id].parameters.penetrator_density
    local apfdsds_diameter = self.cl.ammo[id].parameters.diameter

    local is_apcbc = self.cl.ammo[id].parameters.is_apcbc
    local explosive_mass = self.cl.ammo[id].parameters.explosive_mass
    local fuse_depth = self.cl.ammo[id].fuse and self.cl.ammo[id].fuse.trigger_depth or 0
    local fuse_delay = self.cl.ammo[id].fuse and self.cl.ammo[id].fuse.delay or 0

    self.cl.is_apcbc = is_apcbc

    self.cl.gui_apfsds:setText("TextBox_Amount", tostring(propellant))
    self.cl.gui_ap:setText("TextBox_Amount", tostring(propellant))
    self.cl.gui_aphe:setText("TextBox_Amount", tostring(propellant))
    self.cl.gui_he:setText("TextBox_Amount", tostring(propellant))

    self.cl.gui_apfsds:setText("TextBox_Diameter", tostring(caliber))
    self.cl.gui_ap:setText("TextBox_Diameter", tostring(caliber))
    self.cl.gui_aphe:setText("TextBox_Diameter", tostring(caliber))
    self.cl.gui_he:setText("TextBox_Diameter", tostring(caliber))

    self.cl.gui_apfsds:setText("TextBox_APFSDS_Lenght", tostring(apfsds_length))
    self.cl.gui_apfsds:setText("TextBox_APFSDS_Density", tostring(apfsds_density))
    self.cl.gui_apfsds:setText("TextBox_APFSDS_Diameter", tostring(apfdsds_diameter))

    self.cl.gui_ap:setButtonState("CheckBox_AP_APCBC", self.cl.is_apcbc)
    self.cl.gui_aphe:setButtonState("CheckBox_APHE_APCBC", self.cl.is_apcbc)

    self.cl.gui_aphe:setText("TextBox_APHE_Mass", tostring(explosive_mass))
    self.cl.gui_he:setText("TextBox_HE_Mass", tostring(explosive_mass))

    self.cl.gui_aphe:setText("TextBox_APHE_FuseDepth", tostring(fuse_depth))
    self.cl.gui_aphe:setText("TextBox_APHE_FuseDelay", tostring(fuse_delay))

    local string = tostring(self.cl.selected_shell_id) .. "/" .. tostring(#self.cl.ammo)
    self.cl.gui_apfsds:setText("AC_Ammo", string)
    self.cl.gui_ap:setText("AC_Ammo", string)
    self.cl.gui_aphe:setText("AC_Ammo", string)
    self.cl.gui_he:setText("AC_Ammo", string)
end

function Shell:gui_change_to_APFSDS()
    print("change to APFSDS")
    self.cl.gui:close()
    self.cl.gui = self.cl.gui_apfsds
    self.cl.gui:open()
    self.cl.gui_changed = true

    local ammo_index = self.cl.selected_shell_id
    local old_caliber = self.cl.ammo[ammo_index].caliber
    local new_ammo = {
        type = "APFSDS",
        caliber = old_caliber,
        parameters = {
            propellant = 200,
            projectile_mass = 12,
            diameter = 27,
            penetrator_length = 700,
            penetrator_density = 17800
        }
    }

    self.cl.ammo[ammo_index] = new_ammo
    self.network:sendToServer("sv_edit_ammo", {
        ammo_index = ammo_index,
        from_scratch = true,
        edits = new_ammo
    })
    self:gui_setText()
    self.network:sendToServer("sv_save")
end

function Shell:gui_change_to_AP()
    print("change to AP")
    self.cl.gui:close()
    self.cl.gui = self.cl.gui_ap
    self.cl.gui:open()
    self.cl.gui_changed = true
    self.cl.is_apcbc = false

    local ammo_index = self.cl.selected_shell_id
    local old_caliber = self.cl.ammo[ammo_index].caliber
    local new_ammo = {
        type = "AP",
        caliber = old_caliber,
        parameters = {
            propellant = 130,
            projectile_mass = 10,
            is_apcbc = self.cl.is_apcbc
        }
    }

    self.cl.ammo[ammo_index] = new_ammo
    self.network:sendToServer("sv_edit_ammo", {
        ammo_index = ammo_index,
        from_scratch = true,
        edits = new_ammo
    })

    self:gui_setText()
    self.network:sendToServer("sv_save")
end

function Shell:gui_change_to_APHE()
    print("change to APHE")
    self.cl.gui:close()
    self.cl.gui = self.cl.gui_aphe
    self.cl.gui:open()
    self.cl.gui_changed = true
    self.cl.is_apcbc = false

    local ammo_index = self.cl.selected_shell_id
    local old_caliber = self.cl.ammo[ammo_index].caliber
    local new_ammo = {
        type = "APHE",
        caliber = old_caliber,
        parameters = {
            propellant = 120,
            projectile_mass = 10,
            is_apcbc = self.cl.is_apcbc,
            explosive_mass = 0.365, --kg
        },
        fuse = {
            active = false,
            delay = 0.001,     --seconds
            trigger_depth = 10 --mm
        }
    }

    self.cl.ammo[ammo_index] = new_ammo
    self.network:sendToServer("sv_edit_ammo", {
        ammo_index = ammo_index,
        from_scratch = true,
        edits = new_ammo
    })
    self:gui_setText()
    self.network:sendToServer("sv_save")
end

function Shell:gui_change_to_HE()
    print("change to HE")
    self.cl.gui:close()
    self.cl.gui = self.cl.gui_he
    self.cl.gui:open()
    self.cl.gui_changed = true

    local ammo_index = self.cl.selected_shell_id
    local old_caliber = self.cl.ammo[ammo_index].caliber
    local new_ammo = {
        type = "HE",
        caliber = old_caliber,
        parameters = {
            propellant = 50,
            projectile_mass = 15,
            explosive_mass = 10
        }
    }
    self.cl.ammo[ammo_index] = new_ammo
    self.network:sendToServer("sv_edit_ammo", {
        ammo_index = ammo_index,
        from_scratch = true,
        edits = new_ammo
    })
    self:gui_setText()
    self.network:sendToServer("sv_save")
end

function Shell:gui_onChange_propellant(name, value)
    local converted_value = tonumber(value)
    if name == "Slider_Amount" then
        converted_value = math.floor(sm.util.lerp(10, 250,
            ((value * 1.0101010101) / 100)) + 0.5)
    end
    self.cl.gui_apfsds:setText("TextBox_Amount", tostring(converted_value))
    self.cl.gui_ap:setText("TextBox_Amount", tostring(converted_value))
    self.cl.gui_aphe:setText("TextBox_Amount", tostring(converted_value))
    self.cl.gui_he:setText("TextBox_Amount", tostring(converted_value))

    self.network:sendToServer("sv_edit_ammo", {
        ammo_index = self.cl.selected_shell_id,
        from_scratch = false,
        edits = { propellant = converted_value }
    })
    self.cl.ammo[self.cl.selected_shell_id].parameters.propellant = converted_value
end

function Shell:gui_onChange_caliber(name, value)
    local converted_value = tonumber(value)
    if name == "Slider_Diameter" then
        converted_value = math.floor(sm.util.lerp(10, 250,
            ((value * 1.0101010101) / 100)) + 0.5)
    end
    self.cl.gui_apfsds:setText("TextBox_Diameter", tostring(converted_value))
    self.cl.gui_ap:setText("TextBox_Diameter", tostring(converted_value))
    self.cl.gui_aphe:setText("TextBox_Diameter", tostring(converted_value))
    self.cl.gui_he:setText("TextBox_Diameter", tostring(converted_value))

    self.network:sendToServer("sv_edit_ammo", {
        ammo_index = self.cl.selected_shell_id,
        from_scratch = false,
        edits = { caliber = converted_value }
    })

    self.cl.ammo[self.cl.selected_shell_id].caliber = converted_value
end

function Shell:gui_onChange_APFSDS_Length(name, value)
    local converted_value = tonumber(value)
    if name == "Slider_APFSDS_Lenght" then
        converted_value = math.floor(sm.util.lerp(100, 1000,
            ((value * 1.0101010101) / 100)) + 0.5)
    end
    self.cl.gui_apfsds:setText("TextBox_APFSDS_Lenght", tostring(converted_value))

    self.network:sendToServer("sv_edit_ammo", {
        ammo_index = self.cl.selected_shell_id,
        from_scratch = false,
        edits = { penetrator_length = converted_value }
    })
    self.cl.ammo[self.cl.selected_shell_id].parameters.penetrator_length = converted_value
end

function Shell:gui_onChange_APFSDS_Diameter(name, value)
    local converted_value = tonumber(value)
    if name == "Slider_APFSDS_Diameter" then
        converted_value = math.floor(sm.util.lerp(2, 1000,
            ((value * 1.0101010101) / 100)) + 0.5)
    end
    self.cl.gui_apfsds:setText("TextBox_APFSDS_Diameter", tostring(converted_value))

    self.network:sendToServer("sv_edit_ammo", {
        ammo_index = self.cl.selected_shell_id,
        from_scratch = false,
        edits = { diameter = converted_value }
    })

    self.cl.ammo[self.cl.selected_shell_id].parameters.diameter = converted_value
end

function Shell:gui_onChange_APFSDS_Density(name, value)
    local converted_value = tonumber(value)
    if name == "Slider_Diameter" then
        converted_value = math.floor(sm.util.lerp(7850, 20000,
            ((value * 1.0101010101) / 100)) + 0.5)
    end
    self.cl.gui_apfsds:setText("TextBox_APFSDS_Density", tostring(converted_value))

    self.network:sendToServer("sv_edit_ammo", {
        ammo_index = self.cl.selected_shell_id,
        from_scratch = false,
        edits = { penetrator_density = converted_value }
    })

    self.cl.ammo[self.cl.selected_shell_id].parameters.penetrator_density = converted_value
end

function Shell:gui_onChange_APCBC(name)
    self.cl.is_apcbc = not self.cl.is_apcbc
    self.cl.gui_ap:setButtonState("CheckBox_AP_APCBC", self.cl.is_apcbc)
    self.cl.gui_aphe:setButtonState("CheckBox_APHE_APCBC", self.cl.is_apcbc)
    self.network:sendToServer("sv_edit_ammo", {
        ammo_index = self.cl.selected_shell_id,
        from_scratch = false,
        edits = { is_apcbc = self.cl.is_apcbc }
    })

    self.cl.ammo[self.cl.selected_shell_id].parameters.is_apcbc = self.cl.is_apcbc
end

function Shell:gui_onChange_APHE_explosive(name, value)
    local converted_value = tonumber(value)
    if name == "Slider_APHE_Mass" then
        converted_value = sm.util.lerp(0.01, 1,
            ((value * 1.0101010101) / 100))
    end
    self.cl.gui_aphe:setText("TextBox_APHE_Mass", tostring(converted_value))

    self.network:sendToServer("sv_edit_ammo", {
        ammo_index = self.cl.selected_shell_id,
        from_scratch = false,
        edits = { explosive_mass = converted_value }
    })

    self.cl.ammo[self.cl.selected_shell_id].parameters.explosive_mass = converted_value
end

function Shell:gui_onChange_APHE_FuseDepth(name, value)
    self.network:sendToServer("sv_edit_ammo", {
        ammo_index = self.cl.selected_shell_id,
        from_scratch = false,
        is_fuse = true,
        edits = { trigger_depth = tonumber(value) }
    })

    self.cl.ammo[self.cl.selected_shell_id].fuse.trigger_depth = tonumber(value)
end

function Shell:gui_onChange_APHE_FuseDelay(name, value)
    self.network:sendToServer("sv_edit_ammo", {
        ammo_index = self.cl.selected_shell_id,
        from_scratch = false,
        is_fuse = true,
        edits = { delay = tonumber(value) }
    })

    self.cl.ammo[self.cl.selected_shell_id].fuse.delay = tonumber(value)
end

function Shell:gui_onChange_HE_explosive(name, value)
    local converted_value = tonumber(value)
    if name == "Slider_HE_Mass" then
        converted_value = math.floor(sm.util.lerp(0.1, 50,
            ((value * 1.0101010101) / 100)) + 0.5)
    end
    self.cl.gui_he:setText("TextBox_HE_Mass", tostring(converted_value))

    self.network:sendToServer("sv_edit_ammo", {
        ammo_index = self.cl.selected_shell_id,
        from_scratch = false,
        edits = { explosive_mass = converted_value }
    })

    self.cl.ammo[self.cl.selected_shell_id].parameters.explosive_mass = converted_value
end

function Shell:gui_copy_shell(name)
    print("Copy")
    sm.ACC.copied_shell = deep_copy(self.cl.ammo[self.cl.selected_shell_id])
end

function Shell:gui_paste_shell(name)
    print("Paste")
    self.cl.ammo[self.cl.selected_shell_id] = deep_copy(sm.ACC.copied_shell)
    self.cl.gui_changed = true
    self.cl.gui:close()
    self:gui_set_gui_type()
    self:gui_setText()
end

function Shell:gui_select_shell(name)
    local max_length = #self.cl.ammo
    local old_id = self.cl.selected_shell_id
    if name == "AC_LeftButton" then
        self.cl.selected_shell_id = math.max(1, self.cl.selected_shell_id - 1)
    else
        self.cl.selected_shell_id = math.min(max_length, self.cl.selected_shell_id + 1)
    end

    if old_id == self.cl.selected_shell_id then
        return
    end

    self.cl.gui_changed = true
    self.cl.gui:close()
    self:gui_set_gui_type()
    self:gui_setText()
end
