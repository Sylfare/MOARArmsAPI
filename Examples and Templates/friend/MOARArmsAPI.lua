--MOAR Arms API by MitchOfTarcoola
--Allows for creation of custom player arms, mainly for avatars with more than 2 arms.
--Designed to fully replace vanilla arms
--Very W.I.P

--[[
FEATURES:

* arms will visually behave almost like vanilla arms (its not perfect but it works well)
* Works with items that have custom hold/use poses (bows, cbows, tridents, shields, etc)
  * Modded items that have custom hold/use can be inserted into the ItemOverrides table to work.
* Arms can be set up to hold specific hotbar slots, alongside mainhand and offhand. The arm holding the mainhand slot won't hold items assigned to other arms, that arm does it instead.
* Arms can be given an animation to play when they swing
  * custom anims are still W.I.P, and doesn't properly work with the custom hold/use poses


to-do (if I can be bothered)

 * custom anims for other cases, such as when an item is held
 * proper item-specific use anims for key items, instead of just using vanilla rots
   * find a way to make certain items display like in vanilla when used (things like bow/cbow charging, and trident/spyglass rotating)
 * cleanup/bugfixes where needed
   * better commenting, both for myself and anyone trying to understand how this all works
 * other stuff that i havent thought about yet



HOW TO USE

--at the top of the script, put a require for this stored as a variable, like this:

Arm = require("MOARArmsAPI")

then, in the script, define the arms using Arm:NewArm(id, side, item pivot, arm model, held slot, custom anim if any)

Each pair of arms must have a different ID, with the 2 arms in each pair sharing ID values
the side is either "LEFT" or "RIGHT", depending on which side the arm is on
item pivot is the part where the item is rendered, just like Left/RightItemPivot parent types.
arm model is the root model of the arm itself
the held slot is what this arm will hold. If set to "MAINHAND" or "OFFHAND", the arm will generally hold whatever is in your main or off hand.
the held slot can also be set to a number from 0-8, corresponding to the hotbar slots. The arm will hold whatever item is in that hotbar slot, and when the slot is selected, the mainhand arm will remain holding what it was and this arm will swing when using that item. This allows your avatar to use all their arms.
the custom anim, if specified, will play a blockbench animation instead of swinging the arm.

e.g. 1, a simple 4 armed character:

Arm:newArm(1, "RIGHT", models.model.Body.RightArm.RightItem, models.model.Body.RightArm, "MAINHAND")
Arm:newArm(1, "LEFT", models.model.Body.LeftArm.LeftItem, models.model.Body.LeftArm, "OFFHAND")
Arm:newArm(2, "RIGHT", models.model.Body.RightArm2.RightItem2, models.model.Body.RightArm2, 0)
Arm:newArm(2, "LEFT", models.model.Body.LeftArm2.LeftItem2, models.model.Body.LeftArm2, 1)

e.g. 2, a character that uses their tail alongside their hands

Arm:newArm(1, "RIGHT", models.model.Body.RightArm.RightItem, models.model.Body.RightArm, "MAINHAND")
Arm:newArm(1, "LEFT", models.model.Body.LeftArm.LeftItem, models.model.Body.LeftArm, "OFFHAND")
Arm:newArm(2, "RIGHT", models.model.Body.Tail1.Tail2.Tail3.TailItem, nil, 0, animations.model.TailAttack)


Arms can also be saved to a variable, allowing access to some of its values, such as the RenderTask for the item, or whether it is currently attacking.
Messing with the variables will likely cause problems

ExtraArm = Arm:newArm(2, "RIGHT", models.model.SecondRightArm.SecondRightItem, models.model.SecondRightArm, 1)




]]
--configurable vars. Generally alternative code for if another mod or something breaks the script

--false: uses maths to calculate arm swinging from walking. My math isn't perfect.
--true: uses the vanilla model's leg rotation to calculate arm swinging from walking. Looks better, but will likely break if something messes with vanilla model legs
local useLegRotForArmAnim = true




local MainhandVanillaArm = nil
local OffhandVanillaArm = nil
events.ENTITY_INIT:register(function ()
    if player:isLeftHanded() then
        OffhandVanillaArm = vanilla_model.RIGHT_ARM
        MainhandVanillaArm = vanilla_model.LEFT_ARM
    else
        OffhandVanillaArm = vanilla_model.LEFT_ARM
        MainhandVanillaArm = vanilla_model.RIGHT_ARM
    end
end)



---@class Arm
---@field ID integer
---@field LeftRight ArmType
---@field Model ModelPart
---@field ItemModel ModelPart
---@field ItemChoice ItemChoice
---@field AttackAnim
---@field isAttacking boolean
---@field AtkTime number
---@field ItemSlot integer
---@field Item string
---@field ItemRender ItemTask
---@field newArm function
---@field ChangeItem function
local Arm = {}

---@alias ArmType
---| "LEFT"
---| "RIGHT"


---@alias ItemChoice
---| "MAINHAND"
---| "OFFHAND"
---| integer


---Declare an Arm
---@param id integer ID of arm. Cannot match another arm on same side. Indicates which other arm is used for 2 handed animations
---@param left_right ArmType Whether arm is left or right
---@param itemPivot ModelPart ModelPart of the Held Item
---@param armModel ModelPart | nil ModelPart of the arm itself. Will remove vanilla RightArm and LeftArm parenting from the part if present, to replace with custom anims. nil value means no rotations applied (e.g fully custom anims)
---@param itemChoice ItemChoice Item to prioritise. "MAINHAND" and "OFFHAND" for vanilla hands, or a number representing a hotbar slot. (0 is leftmost slot, 8 for rightmost)
function Arm:newArm(id, left_right, itemPivot, armModel, itemChoice, attackAnim)
    --setup arm vars
    arm = {ID=id, LeftRight = left_right, ItemPivot = itemPivot, Model = armModel, ItemChoice = itemChoice, AttackAnim = attackAnim}
    if type(itemChoice) == "number" then
        arm.ItemSlot = itemChoice
        table.insert(UsedSlots, itemChoice)
    end
    arm.AtkTime = 0

    
    table.insert(Arms, arm)

    --stop arm parenting to vanilla, if it is
    if armModel and (armModel:getParentType() == "LeftArm" or armModel:getParentType() == "RightArm") then
        armModel:setParentType("None")
    end

    --Item RenderTask
    arm.ItemRender = arm.ItemPivot:newItem("HandItem")
    arm.ItemRender:setRot(-90,0, 180)
    if left_right == "LEFT" then
        arm.ItemRender:setDisplayMode("THIRD_PERSON_LEFT_HAND")
    elseif left_right == "RIGHT" then
        arm.ItemRender:setDisplayMode("THIRD_PERSON_RIGHT_HAND")
    end

    setmetatable(arm, self)
    self.__index = self
    return arm
end



---Change Held Item of an Arm
---@param item ItemChoice
function Arm:ChangeItem(item)
    if type(self.ItemChoice) == "number" then
        for index, value in ipairs(UsedSlots) do --if changing from a slot, remove from UsedSlots list
            if value == self.ItemSlot then
                table.remove(UsedSlots, index)
                break
            end
        end
        for _, arm in ipairs(Arms) do --swap with mainhand, if needed
            if arm.ItemChoice == "MAINHAND" and item == arm.ItemSlot then

                arm.ItemSlot = self.ItemChoice
            end
        end

    end
    if type(item) == "number" then

        self.ItemSlot = item
        table.insert(UsedSlots, item)
    else
        self.ItemSlot = nil
    end
    self.ItemChoice = item
end


vanilla_model.HELD_ITEMS:setVisible(false)


function player_init() 
    Pos = player:getPos() 
    OldPos = player:getPos()
    needInit = false
end
events.ENTITY_INIT:register(player_init)


--Auto update for players first loading avatar

function pings.getArmData()
    if host:isHost() then
        
        for id, arm in pairs(Arms) do
            pings.updateArm(id, arm.Item)
        end
    end

end

local list = {}
local send_update_ping = true
local update_ping = function() pings.getArmData() end
events.TICK:register(function()
    if host:isHost() then
        
        for player_name in pairs(world.getPlayers()) do
            if not list[player_name] then
              send_update_ping = true
            end
            list[player_name] = 2
          end
          for i, v in pairs(list) do
            list[i] = v - 1
            if v < 0 then list[i] = nil end
          end
          if send_update_ping  and (world.getTime()) % 4 == 0 then
            send_update_ping = false
            update_ping()
          end
    end
  
end)

--math functions
local sin = math.sin 
local sqrt = math.sqrt
local pi = math.pi
--keys
--local AtkKey = keybind:create("TEST", keybind:getVanillaKey("key.attack"))
--local UseKey = keybind:create("TEST2", keybind:getVanillaKey("key.use"))
--calculating players horizontal velocity
local Velocity = 0 

local Pos = vec(0,0,0)
local OldPos = vec(0,0,0)
--Arm groups

Arms = {}
--other vars
local Adjdistance = 0
local MainhandSlot = 0
local MainhandArm = {}
UsedSlots = {}
local isSneaking = false




--Item Overrides. Items in here will cause arms to use vanilla rotation instead of scripted rotation. Used for things like bows, crossbows, and tridents.
--Use this when an item is held/used differently than most, visually.
--Use overrides are active when the respective item is being used
--Hold overrides are used when the item is held in an active vanilla slot, and there is no active Use override.
--Mainhand takes priority
--If using mods, insert any modded items that need it in here, e.g modded guns and bows, space mod rockets.
--an item is 'aimed' if, when holding/using it, the player points it in the direction you are looking. Bows are aimed, shields are not.
local ItemOverrides = {
    OneHandHold = {--Vanilla rot when held, for arm holding item

    },
    TwoHandHold = {--Vanilla rot when held, for arm holding item and matching opposite arm

    },
    OneHandUse = {--Vanilla rot when being used, for arm holding item
        {id = "minecraft:trident"},
        {id = "minecraft:shield"},
    },
    TwoHandUse = {--Vanilla rot when being used, for arm holding item and matching opposite arm
        {id = "minecraft:crossbow"},
        --modded
        {id = "rosia:purple_steel_rifle"},
    },

    --If item is aimed, like bows, cbows, guns, as well as things like spyglasses and goat horns, put in here.

    OneHandHoldAimed = {--Vanilla rot when held, for arm holding item

    },
    TwoHandHoldAimed = {--Vanilla rot when held, for arm holding item and matching opposite arm
        {id = "minecraft:crossbow", tag = {Charged = 1}},
        --modded
        {id = "create:potato_cannon"},
        {id = "create:handheld_worldshaper"},
        {id = "rosia:purple_steel_rifle", tag = {Charged = 1}}
    },
    OneHandUseAimed = {--Vanilla rot when being used, for arm holding item
        {id = "minecraft:goat_horn"},
        {id = "minecraft:spyglass"}
    },
    TwoHandUseAimed = {--Vanilla rot when being used, for arm holding item and matching opposite arm
        {id = "minecraft:bow"},
        --modded
        {id = "waystones:warp_stone"},
        {id = "waystones:warp_scroll"},
        {id = "waystones:return_scroll"},
        {id = "waystones:bound_scroll"},
    }
}
local OverrideNum = 0 --which pair of arms to override
local OverrideVal = "NONE" --which arms in the pair to override. can be "NONE","MAINHAND","OFFHAND","BOTH"
local OverrideisAimed = false --whether animation is 'aimed'
local OverrideisInverted = false --whether to invert the anim (item is in vanilla right hand but in model's left hand and vice versa)
local function compareItem(check, item) -- checks whether table 'item' contains everything in table 'check'. use the value "ANY" to indicate that the value can be any non-nil value
    for k, v in pairs(check) do
        if type(v) ~= 'table' then --item in 'check' isnt a table

            if (v ~= item[k]) and not (v == "ANY" and item[k] ~= nil) then
                return false
            end
        elseif type(item[k]) ~= 'table' then --'check' has table, 'item' doesnt
            return false
        else
            if not compareItem(v, item[k]) then return false end --recursive call on the table within table
        end
    end
    return true --if no mismatch found, true.
end
function getOverride()
    OverrideisAimed = false
    OverrideisInverted = player:isLeftHanded()
    if player:getPose() == "SWIMMING" then
        OverrideVal = "ALL"
        OverrideNum = -1
        return
    end
    MainhandItem = player:getHeldItem()
    OffhandItem = player:getHeldItem(true)
    ActiveItem = player:getActiveItem()
    for _, item in ipairs(ItemOverrides.TwoHandUse) do
        if compareItem(item, ActiveItem) then --active item needs override
            OverrideVal = "BOTH"
            if ActiveItem == MainhandItem then
                for _, arm in ipairs(Arms) do
                    if arm.ItemSlot == MainhandSlot then
                        if arm.LeftRight == "LEFT" then
                            OverrideisInverted = not OverrideisInverted
                        end
                        OverrideNum = arm.ID
                        return
                    end
                end
            else
                for _, arm in ipairs(Arms) do
                    if arm.ItemChoice == "OFFHAND" then
                        if arm.LeftRight == "RIGHT" then
                            OverrideisInverted = not OverrideisInverted
                        end
                        OverrideNum = arm.ID
                        return
                    end
                end
            end
        end
    end
    for _, item in ipairs(ItemOverrides.OneHandUse) do
        if compareItem(item, ActiveItem) then --active item needs override
            
            if ActiveItem == MainhandItem then
                OverrideVal = "MAINHAND"
                for _, arm in ipairs(Arms) do
                    if arm.ItemSlot == MainhandSlot then
                        if arm.LeftRight == "LEFT" then
                            OverrideisInverted = not OverrideisInverted
                        end
                        OverrideNum = arm.ID
                        return
                    end
                end
            else
                OverrideVal = "OFFHAND"
                for _, arm in ipairs(Arms) do
                    if arm.ItemChoice == "OFFHAND" then
                        if arm.LeftRight == "RIGHT" then
                            OverrideisInverted = not OverrideisInverted
                        end
                        OverrideNum = arm.ID
                        return
                    end
                end
            end
        end
    end
    for _, item in ipairs(ItemOverrides.TwoHandHold) do
        if compareItem(item, MainhandItem) then --held item needs override
            OverrideVal = "BOTH"
            for _, arm in ipairs(Arms) do
                if arm.ItemSlot == MainhandSlot then
                    if arm.LeftRight == "LEFT" then
                        OverrideisInverted = not OverrideisInverted
                    end
                    OverrideNum = arm.ID
                    return
                end
            end
        elseif compareItem(item, OffhandItem) then
            OverrideVal = "BOTH"
            for _, arm in ipairs(Arms) do
                if arm.ItemChoice == "OFFHAND" then
                    if arm.LeftRight == "RIGHT" then
                        OverrideisInverted = not OverrideisInverted
                    end
                    OverrideNum = arm.ID
                    return
                end
            end
        end
    end
    for _, item in ipairs(ItemOverrides.OneHandHold) do
        if compareItem(item, MainhandItem) then --held item needs override
            OverrideVal = "MAINHAND"
            for _, arm in ipairs(Arms) do
                if arm.ItemSlot == MainhandSlot then
                    if arm.LeftRight == "LEFT" then
                        OverrideisInverted = not OverrideisInverted
                    end
                    OverrideNum = arm.ID
                    return
                end
            end
        elseif compareItem(item, OffhandItem) then
            OverrideVal = "OFFHAND"
            for _, arm in ipairs(Arms) do
                if arm.ItemChoice == "OFFHAND" then
                    if arm.LeftRight == "RIGHT" then
                        OverrideisInverted = not OverrideisInverted
                    end
                    OverrideNum = arm.ID
                    return
                end
            end
        end
    end
    OverrideisAimed = true --if a check below passes, item is aimed
    for _, item in ipairs(ItemOverrides.TwoHandUseAimed) do
        if compareItem(item, ActiveItem) then --active item needs override
            OverrideVal = "BOTH"
            if ActiveItem == MainhandItem then
                for _, arm in ipairs(Arms) do
                    if arm.ItemSlot == MainhandSlot then
                        if arm.LeftRight == "LEFT" then
                            OverrideisInverted = not OverrideisInverted
                        end
                        OverrideNum = arm.ID
                        return
                    end
                end
            else
                for _, arm in ipairs(Arms) do
                    if arm.ItemChoice == "OFFHAND" then
                        if arm.LeftRight == "RIGHT" then
                            OverrideisInverted = not OverrideisInverted
                        end
                        OverrideNum = arm.ID
                        return
                    end
                end
            end
        end
    end
    for _, item in ipairs(ItemOverrides.OneHandUseAimed) do
        if compareItem(item, ActiveItem) then --active item needs override
            
            if ActiveItem == MainhandItem then
                OverrideVal = "MAINHAND"
                for _, arm in ipairs(Arms) do
                    if arm.ItemSlot == MainhandSlot then
                        if arm.LeftRight == "LEFT" then
                            OverrideisInverted = not OverrideisInverted
                        end
                        OverrideNum = arm.ID
                        return
                    end
                end
            else
                OverrideVal = "OFFHAND"
                for _, arm in ipairs(Arms) do
                    if arm.ItemChoice == "OFFHAND" then
                        if arm.LeftRight == "RIGHT" then
                            OverrideisInverted = not OverrideisInverted
                        end
                        OverrideNum = arm.ID
                        return
                    end
                end
            end
        end
    end
    for _, item in ipairs(ItemOverrides.TwoHandHoldAimed) do
        if compareItem(item, MainhandItem) then --held item needs override
            OverrideVal = "BOTH"
            for _, arm in ipairs(Arms) do
                if arm.ItemSlot == MainhandSlot then
                    if arm.LeftRight == "LEFT" then
                        OverrideisInverted = not OverrideisInverted
                    end
                    OverrideNum = arm.ID
                    return
                end
            end
        elseif compareItem(item, OffhandItem) then
            OverrideVal = "BOTH"
            for _, arm in ipairs(Arms) do
                if arm.ItemChoice == "OFFHAND" then
                    if arm.LeftRight == "RIGHT" then
                        OverrideisInverted = not OverrideisInverted
                    end
                    OverrideNum = arm.ID
                    return
                end
            end
        end
    end
    for _, item in ipairs(ItemOverrides.OneHandHoldAimed) do
        if compareItem(item, MainhandItem) then --held item needs override
            OverrideVal = "MAINHAND"
            for _, arm in ipairs(Arms) do
                if arm.ItemSlot == MainhandSlot then
                    if arm.LeftRight == "LEFT" then
                        OverrideisInverted = not OverrideisInverted
                    end
                    OverrideNum = arm.ID
                    return
                end
            end
        elseif compareItem(item, OffhandItem) then
            OverrideVal = "OFFHAND"
            for _, arm in ipairs(Arms) do
                if arm.ItemChoice == "OFFHAND" then
                    if arm.LeftRight == "RIGHT" then
                        OverrideisInverted = not OverrideisInverted
                    end
                    OverrideNum = arm.ID
                    return
                end
            end
        end
    end
    OverrideisAimed = false
    OverrideVal = "NONE"
    OverrideNum = 0
end


-- Strip back excessive item NBT. Don't wanna try to ping stuff like the entire contents of a shulker box
-- "ANY" means any data there is kept. Any other value will override the value on the item, if it has an existing value
-- this is probably very incomplete
-- Most modded items that have a different appearance based on NBT would likely need said NBT added in here to show properly. Some things, like chiseled blocks with chisel mods, likely won't work at all even if listed due to ping size limits
--some modded things might hit ping size limits with these settings, like if an item contains ALL of a contained mob's NBT in it's BlockEntityTag.
--This is also used on the host's end for displaying held items. What you see is what others see.
--NOTE: the stripper function is known to fail on complex data.
--note to self: clean up the stripper code
local NBTWhitelist = {
    --universal
    CustomModelData = "ANY",
    Display = "ANY",

    --tools
    Enchantments = {
        "ANY" --only ping first ench, should allow texture packs that differentiate between ench. books to work
    },
    Damage = "ANY",

    --head
    SkullOwner = "ANY",

    --crossbow
    Charged = "ANY",
    ChargedProjectiles = {
        {
            id = "ANY",
            Count = "ANY",
        }
    },

    --potions
    Potion = "ANY",
    CustomPotionColor = "ANY",

    --block entity stuff 
    -- many modded item's BlockEntityTags seem to break my script for some reason...
    --BlockEntityTag = "ANY",


    --modded

}


local function _stripItem(check, item, output)
    for k, v in pairs(check) do
        if type(v) ~= 'table' then --item in 'check' isnt a table
            if item[k] ~= nil then
                if v == "ANY" then
                    output[k] = item[k]
                end
            end

        elseif type(item[k]) ~= 'table' then --'check' has table, 'item' doesnt
            --item[k] = nil
        else
            output[k] = {}
            _stripItem(v, item[k], output[k]) --recursive call on the table within table
        end
    end
    
end

local next = next
local function tagToStackString(tag, output) --converts a tag value to a string. Like the ItemStack function, but for any table. 
    comma = false
    if next(tag) == nil then --empty list
        output[1] = output[1] .. "[],"
    elseif tag[1] then --is a list
        --output[2] = false
        output[1] = output[1] .. "["
        for k, v in ipairs(tag) do
            if comma then
                output[1] = output[1] .. ","
            end
            comma = true
            if type(v) == "table" then
                if next(v) == nil then
                    output[1] = output[1] .. "{}"
                else
                    tagToStackString(v, output)
                end
            elseif type(v) == "string" then
                output[1] = output[1] .. "'"
                output[1] = output[1] .. v
                output[1] = output[1] .. "'"
            else
                output[1] = output[1] .. v
            end
        end
        output[1] = output[1] .. "]"
    else
        
        output[1] = output[1] .. "{"
        for k, v in pairs(tag) do
            if comma then
                output[1] = output[1] .. ","
            end
            comma = true
            output[1] = output[1] .. k
            output[1] = output[1] .. ":"
            if type(v) == "table" then
                tagToStackString(v, output)
            elseif type(v) == "string" then
                output[1] = output[1] .. "'"
                output[1] = output[1] .. v
                output[1] = output[1] .. "'"
            else
                output[1] = output[1] .. v
            end
        end
        output[1] = output[1] .. "}"
    end
    
end

local function stripItem(item) -- strip all nbt from "item" that isn't included in "check"
    if next(item.tag) == nil then return item:toStackString() end --item has no tags, no need to strip what doesn't exist 
    output = {}
    _stripItem(NBTWhitelist, item.tag, output)
    stackString = {item:getID(), false} --(Why is an ItemStack's tag read-only? WHYYYYYY) (also this code is jank, and i think might contain unneeded leftovers from previous attempts at it)
    tagToStackString(output, stackString)
    result = stackString[1]
    return result
end



function pings.updateArm(armID, item) --getting items from specific slots is Host only, so ping it.
    local arm = Arms[armID]
    arm.Item = item
    arm.ItemRender:item(item)
end
function pings.mainHandSlot(slot)
    MainhandSlot = slot
end

function table.contains(table, element) --func for checking if an item is in a table
    for _, value in pairs(table) do
      if value == element then
        return true
      end
    end
    return false
  end

events.TICK:register(function()

    
    
    
    --if needInit then pings.getArmData() end

    --calculate velocity, use it for arm swinging anim
    if not useLegRotForArmAnim then
        OldPos = Pos
        Pos = player:getPos()
        Velocity = sqrt((Pos.x-OldPos.x)^2+(Pos.z-OldPos.z)^2)
        Adjdistance = Adjdistance + math.min(Velocity*16.8,4.2) --originally tried all kinds of math for this, before discovering that it's a piecewise linear. XD
    end
    

    --Main hand arm item. Item doesn't change when selecting a slot held in another arm
    if host:isHost() then 
        if MainhandSlot ~= player:getNbt().SelectedItemSlot then
            pings.mainHandSlot(player:getNbt().SelectedItemSlot)
        end
    end

    if not table.contains(UsedSlots, MainhandSlot) then
        for _, arm in ipairs(Arms) do
            if arm.ItemChoice == "MAINHAND" then
                arm.ItemSlot = MainhandSlot
            end
        end
    end

    --Arm overrides
    getOverride()

    

    
    --Arm atk/use swing anim, and update held item model
    for k, arm in pairs(Arms) do 
        if arm.isAttacking then --Attack anim ticker
            if arm.AtkTime < 1 and OverrideVal ~= "NONE" then
                arm.isAttacking = false
                arm.AtkTime = 0
            else
                arm.AtkTime = arm.AtkTime + 1
                --TBA: when making customizable attack anim functions, move this there
                if arm.AtkTime == 6 then
                    arm.AtkTime = 0
                    arm.isAttacking = false
                end 
            end  
        end
        if arm.ItemSlot and host:isHost() then
            item = stripItem(host:getSlot(arm.ItemSlot))
            if arm.Item ~= item then
                pings.updateArm(k, item)

            end
        end
        if arm.ItemChoice == "OFFHAND" then
            arm.Item = stripItem(player:getHeldItem(true))
             arm.ItemRender:item(arm.Item)
        end
        
    end


    
end)



events.RENDER:register(function(delta, mode)

    
    --first person stuff
    if mode == "FIRST_PERSON" then
        vanilla_model.HELD_ITEMS:setVisible(true)
    else

        vanilla_model.HELD_ITEMS:setVisible(false)
    end

    --first person stuff, arm-specific
    for _, arm in pairs(Arms) do
        if (arm.ItemChoice == "MAINHAND" or arm.ItemChoice == "OFFHAND") and arm.Model then
            if mode == "FIRST_PERSON" then
                
                if arm.LeftRight == "LEFT" then
                    arm.Model:setParentType("LeftArm")
                else
                    arm.Model:setParentType("RightArm")
                    
                end
                arm.ItemRender:setVisible(false)
            else
                
                arm.Model:setParentType("None")
                arm.ItemRender:setVisible(true)
                
            end
        end
    end
    



    isSneaking = vanilla_model.BODY:getOriginRot().x ~= 0


    --Arm swinging from walking
    local walkRot
    if useLegRotForArmAnim then
        walkRot = vanilla_model.RIGHT_LEG:getOriginRot().x*0.7

    else
        walkRot = (sin((Adjdistance+math.min(Velocity*16.8,4.2)*delta)/(2*pi)) * math.min(Velocity*3,1)) * 57.3
    end
    
    --Idle swinging
    local idleRotX = (sin(math.rad(world.getTime(delta)*18/5))*3)
    local idleRotZ = (sin(math.rad(world.getTime(delta)*18/4))*3+3)

    --log(OverrideNum)
    --log(OverrideVal)
    --log(OverrideisAimed)
    --log(OverrideisInverted)

    for _, arm in pairs(Arms) do
        ArmRot = vec(0,0,0)


        
        

        if OverrideVal == "ALL" then --override all arms
            arm.isOverridden = true
        elseif OverrideNum == arm.ID then

            if OverrideVal == "BOTH" then
                arm.isOverridden = true
            elseif OverrideVal == "MAINHAND" and arm.ItemSlot == MainhandSlot then
                arm.isOverridden = true
            elseif OverrideVal == "OFFHAND" and arm.ItemChoice == "OFFHAND" then
                arm.isOverridden = true
            end
        end
        if arm.isOverridden then
            

            VanillaRot = {0,0}
            if arm.LeftRight == "LEFT" then
                if OverrideisInverted then
                    VanillaRot = vanilla_model.RIGHT_ARM:getOriginRot()
                    VanillaRot.y = -VanillaRot.y
                    if OverrideisAimed then
                        VanillaRot.y = VanillaRot.y + 2 * vanilla_model.HEAD:getOriginRot().y
                    end
                else
                    VanillaRot = vanilla_model.LEFT_ARM:getOriginRot()
                end
            else
                if OverrideisInverted then
                    VanillaRot = vanilla_model.LEFT_ARM:getOriginRot()
                    VanillaRot.y = -VanillaRot.y
                    if OverrideisAimed then
                        VanillaRot.y = VanillaRot.y + 2 * vanilla_model.HEAD:getOriginRot().y
                    end
                else
                    VanillaRot = vanilla_model.RIGHT_ARM:getOriginRot()
                end
            end


            --[[VanillaRot = {0,0}
            if arm.LeftRight == "LEFT" then
                
                if OverrideVal == "ALL" or OverrideVal == "BOTH" then --override involves both arms
                    VanillaRot = OffhandVanillaArm:getOriginRot()
                elseif arm.ItemChoice ~= "OFFHAND" then --single arm, but other side
                    VanillaRot = MainhandVanillaArm:getOriginRot()
                    VanillaRot.y = -VanillaRot.y
                else
                    VanillaRot = OffhandVanillaArm:getOriginRot()
                end
                
            else
                if OverrideVal == "ALL" or OverrideVal == "BOTH" then
                    VanillaRot = MainhandVanillaArm:getOriginRot()
                elseif arm.ItemChoice == "OFFHAND" then
                    VanillaRot = OffhandVanillaArm:getOriginRot()
                    VanillaRot.y = -VanillaRot.y
                else
                    VanillaRot = MainhandVanillaArm:getOriginRot()
                end

            end]]

            ArmRot = VanillaRot
            if isSneaking and arm.Model then --sneaking
                if arm.Model:getParent():getParentType() == "Body" then --if part is parented to the model's body/torso
                    ArmRot:add(50)
                end
            end
            

        else

            if arm.ItemSlot == MainhandSlot and OverrideVal ~= "BOTH" then --Detect arm atk/use swinging
                if 12 < MainhandVanillaArm:getOriginRot().y or MainhandVanillaArm:getOriginRot().y < -12 then
                    arm.isAttacking = true
                end
            end

            if arm.ItemChoice == "OFFHAND" and OverrideVal ~= "BOTH" then
                if 12 < OffhandVanillaArm:getOriginRot().y or OffhandVanillaArm:getOriginRot().y < -12 then
                    arm.isAttacking = true
                end
            end


            if player:getVehicle() then --riding
                ArmRot:add(40)
            else
                if arm.ID % 2 == 0 then Rot = -walkRot else Rot = walkRot end --walking
                if arm.Item ~= "minecraft:air" then Rot = Rot * 0.6 end --arms dont swing as far if they're holding an item.
                if arm.LeftRight == "RIGHT" then
                    ArmRot:add(-Rot)
                else
                    ArmRot:add(Rot)
                end

                if isSneaking and arm.Model then --sneaking
                    if arm.Model:getParent():getParentType() == "Body" then --if part is parented to the model's body/torso
                        ArmRot:add(5)
                    else
                        ArmRot:add(-20)
                    end
                end
                
            end
            if arm.isAttacking then --attacking

                --TBA: make this a separate, customizable func. call
                if arm.AttackAnim then
                    arm.AttackAnim:play() --play anim instead of swinging
                else
                    if arm.LeftRight == "RIGHT" then
                        ArmRot:add(sin((arm.AtkTime+delta)/6*pi)*80, -sin((arm.AtkTime+delta)/3*pi)*20+10, 0)
                    else
                        ArmRot:add(sin((arm.AtkTime+delta)/6*pi)*80, sin((arm.AtkTime+delta)/3*pi)*20-10, 0)
                    end
                end
            end
            if arm.Item ~= "minecraft:air" then --holding item
                ArmRot:add(20,0,0)

            end
            if arm.ID % 2 == 0 then Rot = -idleRotX else Rot = idleRotX end --Idling
            if arm.LeftRight == "RIGHT" then
                ArmRot:add(-Rot,0,idleRotZ)
            else
                ArmRot:add(Rot,0,-idleRotZ)
            end
        end

        if arm.Model then arm.Model:offsetRot(ArmRot) end
        arm.isOverridden = false
    end
end)




return Arm