local VORPCore = {}
local prompts = GetRandomIntInRange(0, 0xffffff)

Citizen.CreateThread(function()
    while not VORPCore do        
        TriggerEvent("getCore", function(core)
            VORPCore = core
        end)
        Citizen.Await(200)
    end
end)

RegisterNetEvent("vorp:SelectedCharacter") -- NPC loads after selecting character
AddEventHandler("vorp:SelectedCharacter", function(charid)
    startTrainer()
end)

function startTrainer() -- Loading Trainer Function
    for i,v in ipairs(Config.trainers) do 
        local x, y, z = table.unpack(v.coords)
        if Config.aiTrainerped then 
            -- Loading Model
            local hashModel = GetHashKey(v.npcmodel) 
            if IsModelValid(hashModel) then 
                RequestModel(hashModel)
                while not HasModelLoaded(hashModel) do                
                    Wait(100)
                end
            else 
                print(v.npcmodel .. " is not valid") -- Concatenations
            end        
            -- Spawn Ped
            local npc = CreatePed(hashModel, x, y, z, v.heading, false, true, true, true)
            Citizen.InvokeNative(0x283978A15512B2FE, npc, true) -- SetRandomOutfitVariation
            SetEntityNoCollisionEntity(PlayerPedId(), npc, false)
            SetEntityCanBeDamaged(npc, false)
            SetEntityInvincible(npc, true)
            Wait(1000)
            FreezeEntityPosition(npc, true) -- NPC can't escape
            SetBlockingOfNonTemporaryEvents(npc, true) -- NPC can't be scared
        end
        local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, x, y, z) -- Blip Creation
        SetBlipSprite(blip, v.blip, true) -- Blip Texture
        Citizen.InvokeNative(0x9CB1A1623062F402, blip, v.trainername) -- Name of Blip
    end
end

-- Updated 1/30: Can not longer sell players horses! Including AI!

local tamestate = 0

Citizen.CreateThread(function() -- captures event when you break horse in
	while true do
		Citizen.Wait(1) 
		local size = GetNumberOfEvents(0) 
		if size > 0 then 
			for i = 0, size - 1 do
				local eventAtIndex = GetEventAtIndex(0, i)
                if eventAtIndex == GetHashKey("EVENT_HORSE_BROKEN") then
                    tamestate = 1
                end
            end
        end
    end
end)

function sellAnimal() -- Selling horse function
    print(tamestate)
    local horse = Citizen.InvokeNative(0xE7E11B8DCBED1058,PlayerPedId()) -- Gets mount
    local model = GetEntityModel(horse)
    if model ~= 0 then
        print("model",model)
        if tamestate > 0 then -- checks to see if you recently broke the horse in
            if Config.Animals[model] ~= nil then -- Paying for animals
                local animal = Config.Animals[model]
                local money = animal.money
                local gold = animal.gold
                local rolPoints = animal.rolPoints
                local xp = animal.xp               
                TriggerServerEvent("vorp_sellhorse:giveReward", money, gold, rolPoints, xp) 
                TriggerEvent("vorp:TipRight", Config.Language.AnimalSold, 4000) -- Sold notification
                DeletePed(horse)
                Wait(100) 
                tamestate = 0
            else
                TriggerEvent("vorp:TipRight", Config.Language.NotInTheTrainer, 4000) -- Notification when horse is not recognized
            end
        else
            TriggerEvent("vorp:TipRight", Config.Language.NotBroken, 4000) -- Notification when you didn't break the horse 
        end
    else
        TriggerEvent("vorp:TipRight", Config.Language.NoMount, 4000) -- Notification when you don't have a mount
    end
end

Citizen.CreateThread(function()
    Citizen.Wait(5000)
    local str = Config.Language.press 
	openTrainer = PromptRegisterBegin()
	PromptSetControlAction(openTrainer, Config.keys["G"])
	str = CreateVarString(10, 'LITERAL_STRING', str)
	PromptSetText(openTrainer, str)
	PromptSetEnabled(openTrainer, 1)
	PromptSetVisible(openTrainer, 1)
	PromptSetStandardMode(openTrainer,1)
    PromptSetHoldMode(openTrainer, 1)
	PromptSetGroup(openTrainer, prompts)
	Citizen.InvokeNative(0xC5F428EE08FA7F2C,openTrainer,true)
	PromptRegisterEnd(openTrainer)
end)

Citizen.CreateThread(function()
    while true do
        local sleep = true
        for i,v in ipairs(Config.trainers) do
            local playerCoords = GetEntityCoords(PlayerPedId())       
            if Vdist(playerCoords, v.coords) <= v.radius then -- Checking distance between player and trainer
                local job
                sleep = false
                local label  = CreateVarString(10, 'LITERAL_STRING', Config.Language.sell)
                     PromptSetActiveGroupThisFrame(prompts, label)
                if Citizen.InvokeNative(0xC92AC953F0A982AE,openTrainer) then
              
                    if Config.joblocked then 
                        TriggerEvent('vorp:ExecuteServerCallBack','vorp_sellhorse:getjob', function(result)  
                            job =   result
                        end)
                        while job == nil do 
                            Wait(100)
                        end
                        if job == v.trainerjob then 
                            sellAnimal()     
                            Citizen.Wait(200)
                        else
                            TriggerEvent("vorp:TipRight", Config.Language.notatrainer.." : "..v.trainerjob, 4000) 
                        end
                    else
                        sellAnimal()  
                        Citizen.Wait(200)
                    end  
                    Citizen.Wait(1000)       
                end
            end
        end  
        if sleep then 
            Citizen.Wait(500)
        end 
        Citizen.Wait(1)
    end
end)

-- DEV TOOLS -- 

RegisterCommand("horse", function() -- prints what entity model current mount is
    local horse = Citizen.InvokeNative(0xE7E11B8DCBED1058,PlayerPedId())
    local model = GetEntityModel(horse)
    print("model",model) 
 end)

 RegisterCommand("dh", function() -- deletes horse
    local horse = Citizen.InvokeNative(0xE7E11B8DCBED1058,PlayerPedId()) -- 
    DeletePed(horse)
 end)
