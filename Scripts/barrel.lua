Barrel = class()
Barrel.poseWeightCount = 1

function Barrel:client_onCreate()
    self.power = self.interactable:getPower()
    self.interactable:setPoseWeight( 0, self.power / 1000 )
end

function Barrel.client_onFixedUpdate(self, dt)
    local new_power = self.interactable:getPower()
    if new_power ~= self.power then
        self.power = new_power
        self.interactable:setPoseWeight( 0, self.power / 1000 )
    end
end
