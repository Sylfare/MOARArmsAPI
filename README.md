# MOARArmsAPI

MOARArmsAPI is a script to use with the [Figura](https://www.curseforge.com/minecraft/mc-mods/figura "Figura on CurseForge") mod in Minecraft to create avatars with extra arms

It allows you to create avatars with more than 2 arms, and have the avatar visually utilize all their arms.

This repo contains the script itself, plus basic templates for 4 armed alex and steve, and an example extra use case \(a naga friend on your back with a custom attack anim\)

This is still WIP, so there are some bugs and unfinished stuff.

## HOW TO USE

at the top of the script, put a require for this stored as a variable, like this:

    Arm = require("MOARArmsAPI")

then, in the script, define the arms using `Arm:NewArm(id, side, item pivot, arm model, held slot, anim options, custom animations)`

* Each pair of arms must have a different ID, with the 2 arms in each pair sharing ID values.
* the side is either "LEFT" or "RIGHT", depending on which side the arm is on.
* item pivot is the part where the item is rendered, just like Left/RightItemPivot parent types.
* arm model is the root model of the arm itself.
* the held slot is what this arm will hold. If set to "MAINHAND" or "OFFHAND", the arm will generally hold whatever is in your main or off hand.
* the held slot can also be set to a number from 0-8, corresponding to the hotbar slots. The arm will hold whatever item is in that hotbar slot, and when the slot is selected, the mainhand arm will remain holding what it was and this arm will swing when using that item. This allows your avatar to use all their arms.
* anim options is a table with options for what API anims to use, with keys "IDLE","HOLD","CROUCH","RIDE",  "WALK","SWING","ATTACK","USE","DROP","OVERRIDE","OVERRIDE_AIM"  
anim option values can be 0,1,2. 0 = off, 1 = off if no higher custom anim playing, 2 = always on  
omitted values default to 1 if there's an arm model, 0 otherwise.
* custom anims are set up like anim options, but the values instead are the animation to play for that key.

e.g. 1, a simple 4 armed character:

    Arm:newArm(1, "RIGHT", models.model.Body.RightArm.RightItem, models.model.Body.RightArm, "MAINHAND")
    Arm:newArm(1, "LEFT", models.model.Body.LeftArm.LeftItem, models.model.Body.LeftArm, "OFFHAND")
    Arm:newArm(2, "RIGHT", models.model.Body.RightArm2.RightItem2, models.model.Body.RightArm2, 0)
    Arm:newArm(2, "LEFT", models.model.Body.LeftArm2.LeftItem2, models.model.Body.LeftArm2, 1)

e.g. 2, a character that uses their tail alongside their hands

    Arm:newArm(1, "RIGHT", models.model.Body.RightArm.RightItem, models.model.Body.RightArm, "MAINHAND")
    Arm:newArm(1, "LEFT", models.model.Body.LeftArm.LeftItem, models.model.Body.LeftArm, "OFFHAND")
    Arm:newArm(2, "RIGHT", models.model.Body.Tail1.Tail2.Tail3.TailItem, nil, 0, {}, {SWING=animations.model.tailAttack}})

Arms can also be saved to a variable, allowing access to some of its values, such as the RenderTask for the item, or whether it is currently attacking.
There are some functions that can be used to manipulate the arms.
Messing with the variables will likely cause problems

    ExtraArm = Arm:newArm(2, "RIGHT", models.model.SecondRightArm.SecondRightItem, models.model.SecondRightArm, 1)

The table storing all the arms can also be accessed as a second variable returned by the script, done like so:

    Arm, ArmTable = require("MOARArmsAPI")

### Arm functions

These functions are run off of a specific arm instance, not the main script obtained with `require()`

    Arm:setAnimActive(state)

Sets whether this Arm should animate at all. Also stops custom anims.

    Arm:setItemActive(state)

Sets whether the item held by this Arm should be used. Currently does not free up the held slot, acting as if the item was hidden.
Your own script can manipulate the displayed item in the RenderTask while this is disabled.

    Arm:setActive(state)

Combines `Arm:setAnimActive(state)` and `Arm:setItemActive(state)` into a single function call.