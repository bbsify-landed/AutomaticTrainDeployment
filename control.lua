-- Automatic Train Deployment
-- Original mod by aaargha: https://mods.factorio.com/mods/aaargha/AutomaticTrainDeployment
-- Updated for Factorio 2.0 and Space Age 2.0

local deployers = {}
local cleaners = {}

-- Add logging function for easier debugging
local function log_message(message)
    log("[ATD] " .. message)
end

local function track_entities_construction(event)
    local entity = event.created_entity or event.entity
    if not (entity and entity.valid) then return end
    
    -- Check and register deployers
    if entity.name == "atd-deployer" then
        log_message("Deployer built at " .. serpent.line(entity.position))
        deployers[entity.unit_number] = {
            entity = entity,
            interface = entity.surface.find_entities_filtered{
                position = entity.position,
                name = "atd-deployer-interface",
                limit = 1
            }[1]
        }
    end
    
    -- Check and register cleaners
    if entity.name == "atd-cleaner" then
        log_message("Cleaner built at " .. serpent.line(entity.position))
        cleaners[entity.unit_number] = {
            entity = entity,
            interface = entity.surface.find_entities_filtered{
                position = entity.position,
                name = "atd-cleaner-interface",
                limit = 1
            }[1]
        }
    end
end

local function track_entities_removal(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end
    
    -- Remove deployers from tracking
    if entity.name == "atd-deployer" then
        log_message("Deployer removed at " .. serpent.line(entity.position))
        deployers[entity.unit_number] = nil
    end
    
    -- Remove cleaners from tracking
    if entity.name == "atd-cleaner" then
        log_message("Cleaner removed at " .. serpent.line(entity.position))
        cleaners[entity.unit_number] = nil
    end
end

local function handle_train_changed_state(event)
    -- Get the train that changed state
    local train = event.train
    if not (train and train.valid) then 
        log_message("Invalid train in event")
        return 
    end
    
    -- Get the train's current state
    local state = train.state
    log_message("Train state changed to: " .. state)
    
    -- Handle deployers
    if state == defines.train_state.wait_station then
        local station = train.station
        if not (station and station.valid) then 
            log_message("No valid station")
            return 
        end
        
        log_message("Train at station: " .. station.backer_name)
        
        -- Check if the train is at a deployer station
        local deployer = nil
        for _, deploy in pairs(deployers) do
            if deploy.entity.valid and deploy.entity.backer_name == station.backer_name then
                deployer = deploy
                log_message("Found matching deployer: " .. station.backer_name)
                break
            end
        end
        
        -- If it's at a deployer, deploy a new train
        if deployer and deployer.entity.valid then
            log_message("Deploying new train from template")
            
            -- Get the composition of the train at the deployer
            local composition = {
                locomotives = {
                    front_movers = {},
                    back_movers = {}
                },
                cargo_wagons = {},
                fluid_wagons = {}
            }
            
            for _, carriage in ipairs(train.carriages) do
                if carriage.type == "locomotive" then
                    local orientation = carriage.orientation * 8 -- In 2.0, orientation values are multiplied by 2
                    log_message("Locomotive orientation: " .. orientation)
                    if orientation < 2 or orientation > 6 then
                        table.insert(composition.locomotives.front_movers, carriage.name)
                    else
                        table.insert(composition.locomotives.back_movers, carriage.name)
                    end
                elseif carriage.type == "cargo-wagon" then
                    table.insert(composition.cargo_wagons, carriage.name)
                elseif carriage.type == "fluid-wagon" then
                    table.insert(composition.fluid_wagons, carriage.name)
                end
            end
            
            -- Get the track direction at the deployer interface
            local interface = deployer.interface
            if not interface or not interface.valid then 
                log_message("No valid interface for deployer")
                return 
            end
            
            local direction = interface.direction
            local position = interface.position
            
            -- Create a new train with the same composition
            local created_carriages = {}
            local current_pos = {x = position.x, y = position.y}
            
            -- Create the front movers
            for _, name in ipairs(composition.locomotives.front_movers) do
                log_message("Creating front locomotive: " .. name)
                local locomotive = interface.surface.create_entity{
                    name = name,
                    position = current_pos,
                    direction = direction,
                    force = interface.force
                }
                
                -- Move to the next position
                if direction == defines.direction.north then
                    current_pos.y = current_pos.y - 7
                elseif direction == defines.direction.east then
                    current_pos.x = current_pos.x + 7
                elseif direction == defines.direction.south then
                    current_pos.y = current_pos.y + 7
                elseif direction == defines.direction.west then
                    current_pos.x = current_pos.x - 7
                end
                
                table.insert(created_carriages, locomotive)
            end
            
            -- Create the cargo wagons
            for _, name in ipairs(composition.cargo_wagons) do
                log_message("Creating cargo wagon: " .. name)
                local wagon = interface.surface.create_entity{
                    name = name,
                    position = current_pos,
                    direction = direction,
                    force = interface.force
                }
                
                -- Move to the next position
                if direction == defines.direction.north then
                    current_pos.y = current_pos.y - 7
                elseif direction == defines.direction.east then
                    current_pos.x = current_pos.x + 7
                elseif direction == defines.direction.south then
                    current_pos.y = current_pos.y + 7
                elseif direction == defines.direction.west then
                    current_pos.x = current_pos.x - 7
                end
                
                table.insert(created_carriages, wagon)
            end
            
            -- Create the fluid wagons
            for _, name in ipairs(composition.fluid_wagons) do
                log_message("Creating fluid wagon: " .. name)
                local wagon = interface.surface.create_entity{
                    name = name,
                    position = current_pos,
                    direction = direction,
                    force = interface.force
                }
                
                -- Move to the next position
                if direction == defines.direction.north then
                    current_pos.y = current_pos.y - 7
                elseif direction == defines.direction.east then
                    current_pos.x = current_pos.x + 7
                elseif direction == defines.direction.south then
                    current_pos.y = current_pos.y + 7
                elseif direction == defines.direction.west then
                    current_pos.x = current_pos.x - 7
                end
                
                table.insert(created_carriages, wagon)
            end
            
            -- Create the back movers
            for _, name in ipairs(composition.locomotives.back_movers) do
                log_message("Creating back locomotive: " .. name)
                local locomotive = interface.surface.create_entity{
                    name = name,
                    position = current_pos,
                    direction = (direction + 4) % 8, -- Opposite direction
                    force = interface.force
                }
                
                -- Move to the next position
                if direction == defines.direction.north then
                    current_pos.y = current_pos.y - 7
                elseif direction == defines.direction.east then
                    current_pos.x = current_pos.x + 7
                elseif direction == defines.direction.south then
                    current_pos.y = current_pos.y + 7
                elseif direction == defines.direction.west then
                    current_pos.x = current_pos.x - 7
                end
                
                table.insert(created_carriages, locomotive)
            end
            
            -- Connect the carriages to form a train
            if #created_carriages > 1 then
                for i = 1, #created_carriages - 1 do
                    created_carriages[i].connect_rolling_stock(defines.rail_direction.front, created_carriages[i + 1])
                end
            end
            
            -- Get the newly created train
            if #created_carriages > 0 then
                local new_train = created_carriages[1].train
                
                -- Copy the schedule if it exists
                if train.schedule then
                    log_message("Copying schedule from template train")
                    local schedule = table.deepcopy(train.schedule)
                    -- Move to the next station in the schedule
                    schedule.current = ((schedule.current or 1) % #schedule.records) + 1
                    log_message("Next station index: " .. schedule.current)
                    new_train.schedule = schedule
                    
                    -- Set the train to automatic
                    new_train.manual_mode = false
                end
            else
                log_message("Failed to create any carriages")
            end
        end
        
        -- Check if the train is at a cleaner station
        local cleaner = nil
        for _, clean in pairs(cleaners) do
            if clean.entity.valid and clean.entity.backer_name == station.backer_name then
                cleaner = clean
                log_message("Found matching cleaner: " .. station.backer_name)
                break
            end
        end
        
        -- If it's at a cleaner, remove the train
        if cleaner and cleaner.entity.valid then
            log_message("Cleaning train at station: " .. station.backer_name)
            for _, carriage in ipairs(train.carriages) do
                if carriage.valid then
                    carriage.destroy()
                end
            end
        end
    end
end

-- Initialize or update stored deployers and cleaners
local function initialize()
    -- Reset deployers and cleaners
    deployers = {}
    cleaners = {}
    
    log_message("Initializing mod")
    
    -- Find all deployers
    for _, surface in pairs(game.surfaces) do
        local foundDeployers = surface.find_entities_filtered{name = "atd-deployer"}
        log_message("Found " .. #foundDeployers .. " deployers on surface " .. surface.name)
        
        for _, entity in pairs(foundDeployers) do
            deployers[entity.unit_number] = {
                entity = entity,
                interface = surface.find_entities_filtered{
                    position = entity.position,
                    name = "atd-deployer-interface",
                    limit = 1
                }[1]
            }
        end
        
        -- Find all cleaners
        local foundCleaners = surface.find_entities_filtered{name = "atd-cleaner"}
        log_message("Found " .. #foundCleaners .. " cleaners on surface " .. surface.name)
        
        for _, entity in pairs(foundCleaners) do
            cleaners[entity.unit_number] = {
                entity = entity,
                interface = surface.find_entities_filtered{
                    position = entity.position,
                    name = "atd-cleaner-interface",
                    limit = 1
                }[1]
            }
        end
    end
end

-- Register events
script.on_init(initialize)
script.on_configuration_changed(initialize)
script.on_load(function()
    log_message("Mod loaded")
end)

script.on_event(defines.events.on_built_entity, track_entities_construction)
script.on_event(defines.events.on_robot_built_entity, track_entities_construction)

script.on_event(defines.events.on_pre_player_mined_item, track_entities_removal)
script.on_event(defines.events.on_robot_pre_mined, track_entities_removal)
script.on_event(defines.events.on_entity_died, track_entities_removal)

script.on_event(defines.events.on_train_changed_state, handle_train_changed_state)