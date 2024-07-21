Barrel = class()
Barrel.poseWeightCount = 1

function Barrel:server_onCreate()
    self.sv_diameter = -1
end

function Barrel:client_onCreate()
    self.cl_diameter = -1
    self.network:sendToServer("sv_getBarrelDiameter")
end



function Barrel:sv_getBarrelDiameter(data, client)
    local pd = self.interactable:getPublicData()

    if pd and pd.diameter then
        self.network:sendToClient(client, "cl_getBarrelDiameter", {pd.diameter})
        return
    end
    self.network:sendToClient(client, "cl_getBarrelDiameter", {50})
end

function Barrel:cl_getBarrelDiameter(data)
    local new_diameter = data[1]
    if new_diameter ~= self.cl_diameter then
        self:cl_updateDiameter({new_diameter})
    end
    self.cl_diameter = new_diameter
end



function Barrel:server_onFixedUpdate(dt)
    local pd = self.interactable:getPublicData()
    if pd and pd.diameter ~= self.diameter then
        self.diameter = pd.diameter
        self.network:sendToClients("cl_updateDiameter", {self.diameter})
    end
end

function Barrel:cl_updateDiameter(data)
    self.interactable:setPoseWeight( 0, data[1] / 1000 )
end
