animations.model.idle:play() --idale anim for naga
models.model.LeftLeg:setPrimaryTexture("SKIN") --use vanilla skin
models.model.RightLeg:setPrimaryTexture("SKIN")
models.model.Body.LeftArm:setPrimaryTexture("SKIN")
models.model.Body.RightArm:setPrimaryTexture("SKIN")
models.model.Head:setPrimaryTexture("SKIN")
models.model.Body.torso:setPrimaryTexture("SKIN")
vanilla_model.PLAYER:setVisible(false) --hide vanilla player

--using MOARArmsAPI
Arm = require("MOARArmsAPI")

Arm:newArm(1, "LEFT", models.model.Body.LeftArm.bone19, models.model.Body.LeftArm, "OFFHAND")
Arm:newArm(1, "RIGHT", models.model.Body.RightArm.bone20, models.model.Body.RightArm, "MAINHAND")
CustomArm = Arm:newArm(2, "RIGHT", models.model.Body.bone.bone2.bone11.bone12.bone14.RightItemPivot, nil, 0, animations.model.attack)

--fixing sneak pose
headOffset = vec(0,4.25,0)
armOffset = vec(0,0,-1) --sneak adjustment constants

events.TICK:register(function() --sneak position adjustments
    if player:getPose() == "CROUCHING" then
        models.model.Body.LeftArm:setPos(armOffset)
        models.model.Body.RightArm:setPos(armOffset)
        models.model.Body.bone.bone2.bone11.bone16.bone17.piv.Head2:setPos(headOffset)
    else
        models.model.Body.LeftArm:setPos(0)
        models.model.Body.RightArm:setPos(0)
        models.model.Body.bone.bone2.bone11.bone16.bone17.piv.Head2:setPos(0)
    end
end)

--prevents torso swinging when naga is swinging item
events.RENDER:register(function()
    if CustomArm.isAttacking then
        models.model.Body:setRot(0, -vanilla_model.BODY:getOriginRot().y)
    end
end)
    