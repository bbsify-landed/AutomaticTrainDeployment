-- Automatic Train Deployment
-- Original mod by aaargha: https://mods.factorio.com/mods/aaargha/AutomaticTrainDeployment
-- Updated for Factorio 2.0 and Space Age 2.0
local util = require("util")

local sources = {}     -- Train source stations
local deployers = {}   -- Train deployer stations
local cleaners = {}    -- Train cleaner stations

-- Add logging function for easier debugging
local function log_message(message)
    log("[ATD] " .. message)
end

local function track_entities_construction(event)
    local entity = event.created_entity or event.entity
    if not (entity and entity.valid) then return end
    
    -- Check and register sources
    if entity.name == "atd-source" then
        log_message("Source built at " .. serpent.line(entity.position))
        sources[entity.unit_number] = {
            entity = entity,
            interface = entity.surface.create_entity{
                name = "atd-source-interface",
                position = entity.position,
                force = entity.force
            }
        }
    end
    
    -- Check and register deployers
    if entity.name == "atd-deployer" then
        log_message("Deployer built at " .. serpent.line(entity.position))
        deployers[entity.unit_number] = {
            entity = entity,
            interface = entity.surface.create_entity{
                name = "atd-deployer-interface",
                position = entity.position,
                force = entity.force
            },
            last_signal = 0
        }
    end
    
    -- Check and register cleaners
    if entity.name == "atd-cleaner" then
        log_message("Cleaner built at " .. serpent.line(entity.position))
        cleaners[entity.unit_number] = {
            entity = entity,
            interface = entity.surface.create_entity{
                name = "atd-cleaner-interface",
                position = entity.position,
                force = entity.force
            }
        }
    end
end

local function track_entities_removal(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end
    
    -- Remove sources from tracking
    if entity.name == "atd-source" then
        log_message("Source removed at " .. serpent.line(entity.position))
        if sources[entity.unit_number] and sources[entity.unit_number].interface and sources[entity.unit_number].interface.valid then
            sources[entity.unit_number].interface.destroy()
        end
        sources[entity.unit_number] = nil
    end
    
    -- Remove deployers from tracking
    if entity.name == "atd-deployer" then
        log_message("Deployer removed at " .. serpent.line(entity.position))
        if deployers[entity.unit_number] and deployers[entity.unit_number].interface and deployers[entity.unit_number].interface.valid then
            deployers[entity.unit_number].interface.destroy()
        end
        deployers[entity.unit_number] = nil
    end
    
    -- Remove cleaners from tracking
    if entity.name == "atd-cleaner" then
        log_message("Cleaner removed at " .. serpent.line(entity.position))
        if cleaners[entity.unit_number] and cleaners[entity.unit_number].interface and cleaners[entity.unit_number].interface.valid then
            cleaners[entity.unit_number].interface.destroy()
        end
        cleaners[entity.unit_number] = nil
    end
end

-- Get the train composition from a source station, including carriage details
local function get_source_composition(source_station)
    log_message("Getting source train composition from " .. source_station.backer_name)
    
    -- Find all trains stopped at the source station
    local trains = source_station.get_train_stop_trains()
    if #trains == 0 then
        log_message("No source train found at " .. source_station.backer_name)
        return nil
    end
    
    -- Get the first train at the station
    local source_train = trains[1]
    log_message("Found source train with ID " .. source_train.id)
    
    -- Get the detailed composition of the source train with position and orientation
    local composition = {}
    
    -- Record reference position (first carriage position)
    local reference_position = nil
    if #source_train.carriages > 0 then
        reference_position = {
            x = source_train.carriages[1].position.x,
            y = source_train.carriages[1].position.y
        }
    else
        log_message("Train has no carriages")
        return nil, nil
    end
    
    -- Store each carriage's details
    for i, carriage in ipairs(source_train.carriages) do
        -- Calculate offset relative to the first carriage
        local offset = {
            x = carriage.position.x - reference_position.x,
            y = carriage.position.y - reference_position.y
        }
        
        -- Add carriage details to composition
        table.insert(composition, {
            name = carriage.name,
            type = carriage.type,
            orientation = carriage.orientation,
            offset = offset
        })
        
        log_message("Recorded carriage " .. i .. " of type " .. carriage.type .. 
                   " with orientation " .. carriage.orientation .. 
                   " at offset " .. serpent.line(offset))
    end
    
    return composition, source_train
end

-- Find rail at position
local function find_rail_at_position(surface, position)
    local rail = surface.find_entities_filtered{
        position = position,
        type = {"straight-rail", "curved-rail"},
        limit = 1
    }[1]
    
    return rail
end

-- Deploy a new train from a source train
local function deploy_train(deployer, source_station, source_train)
    if not (deployer and deployer.interface and deployer.interface.valid) then
        log_message("Invalid deployer interface")
        return false
    end
    
    if not (source_station and source_station.valid) then
        log_message("Invalid source station")
        return false
    end
    
    if not (source_train and source_train.valid) then
        log_message("Invalid source train")
        return false
    end
    
    log_message("Deploying train from source: " .. source_station.backer_name)
    
    -- Get the source train composition with detailed carriage information
    local source_composition, _ = get_source_composition(source_station)
    if not source_composition then
        log_message("Failed to get source composition")
        return false
    end
    
    -- Get the reference position (deployer interface)
    local interface = deployer.interface
    local deploy_position = interface.position
    local deploy_direction = interface.direction
    
    log_message("Deployer position: " .. serpent.line(deploy_position) .. 
               " with direction: " .. deploy_direction)
    
    -- Find rail at deployer position
    local rail = find_rail_at_position(interface.surface, deploy_position)
    if not rail then
        log_message("No rail found at deployer position")
        return false
    end
    
    -- Create a new train with the source composition
    local created_carriages = {}
    
    -- Create each carriage at the exact offset from the deployer, adjusting direction
    for i, carriage_data in ipairs(source_composition) do
        -- Apply directional rotation to the offset coordinates
        local rotated_offset = {x = 0, y = 0}
        
        if deploy_direction == defines.direction.north then
            -- North: Use original offset
            rotated_offset.x = carriage_data.offset.x
            rotated_offset.y = carriage_data.offset.y
        elseif deploy_direction == defines.direction.east then
            -- East: Rotate 90° clockwise (x becomes y, y becomes -x)
            rotated_offset.x = carriage_data.offset.y
            rotated_offset.y = -carriage_data.offset.x
        elseif deploy_direction == defines.direction.south then
            -- South: Rotate 180° (x becomes -x, y becomes -y)
            rotated_offset.x = -carriage_data.offset.x
            rotated_offset.y = -carriage_data.offset.y
        elseif deploy_direction == defines.direction.west then
            -- West: Rotate 270° clockwise (x becomes -y, y becomes x)
            rotated_offset.x = -carriage_data.offset.y
            rotated_offset.y = carriage_data.offset.x
        end
        
        -- Calculate final position
        local position = {
            x = deploy_position.x + rotated_offset.x,
            y = deploy_position.y + rotated_offset.y
        }
        
        -- Find rail at this position
        local current_rail = find_rail_at_position(interface.surface, position)
        if not current_rail then
            log_message("No rail found at position " .. serpent.line(position) .. " for carriage " .. i)
            -- Try to find the nearest rail within a small radius
            local nearby_rails = interface.surface.find_entities_filtered{
                position = position,
                type = {"straight-rail", "curved-rail"},
                radius = 2
            }
            
            if #nearby_rails > 0 then
                current_rail = nearby_rails[1]
                position = current_rail.position
                log_message("Found nearby rail at " .. serpent.line(position))
            else
                -- Skip this carriage if no rail found
                log_message("Skipping carriage " .. i .. " due to missing rail")
                goto continue
            end
        end
        
        -- Calculate entity orientation based on source orientation and deployer direction
        local orientation = (carriage_data.orientation + (deploy_direction / 8)) % 1
        
        -- For locomotives, determine if we need to flip the orientation
        local entity_direction = deploy_direction
        if carriage_data.type == "locomotive" then
            -- Check if this is originally a backward-facing locomotive
            local orig_direction = math.floor(carriage_data.orientation * 8)
            local is_backward = (orig_direction >= 2 and orig_direction <= 6)
            
            if is_backward then
                entity_direction = (deploy_direction + 4) % 8
            end
        end
        
        log_message("Creating " .. carriage_data.type .. " '" .. carriage_data.name .. 
                   "' at position " .. serpent.line(position) .. 
                   " with orientation " .. orientation .. 
                   " and direction " .. entity_direction)
        
        -- Create the entity directly on the rail
        local entity = interface.surface.create_entity{
            name = carriage_data.name,
            position = position,
            direction = entity_direction,
            orientation = orientation,
            force = interface.force,
            raise_built = true
        }
        
        if entity then
            table.insert(created_carriages, entity)
        else
            log_message("Failed to create entity: " .. carriage_data.name)
        end
        
        ::continue::
    end
    
    -- Connect the carriages to form a train
    if #created_carriages > 1 then
        for i = 1, #created_carriages - 1 do
            local success = pcall(function()
                created_carriages[i].connect_rolling_stock(defines.rail_direction.back)
            end)
            
            if not success then
                log_message("Failed to connect carriage " .. i .. " to " .. (i+1))
            end
        end
    end
    
    -- Get the newly created train
    if #created_carriages > 0 then
        local new_train = created_carriages[1].train
        
        -- Copy the schedule if the source train has one
        if source_train.schedule then
            log_message("Copying schedule from source train")
            local schedule = util.table.deepcopy(source_train.schedule)
            
            -- Set the train to automatic mode (if needed)
            new_train.schedule = schedule
            new_train.manual_mode = false
            
            log_message("New train created successfully with ID: " .. new_train.id)
            return true
        else
            log_message("Source train has no schedule")
            return false
        end
    else
        log_message("Failed to create any carriages")
        return false
    end
end

-- Check circuit conditions and deploy trains accordingly
local function check_circuit_conditions()
    for id, deployer in pairs(deployers) do
        if deployer.entity and deployer.entity.valid then
            if deployer.entity.get_stopped_train() then
                goto continue
            end

            local red = defines.wire_connector_id.circuit_red
            local green = defines.wire_connector_id.circuit_green
            local circuit_red = deployer.entity.get_circuit_network(red)
            local circuit_green = deployer.entity.get_circuit_network(green)

            -- Check if the deployer has circuit connection
            if circuit_red or circuit_green then
        
                -- Get the signal value (use virtual signal "signal-D" for deploy)        
                local deploy_signal = 0
                
                if circuit_red then
                    deploy_signal = deploy_signal + (circuit_red.get_signal({type="virtual", name="signal-D"}) or 0)
                end
                
                if circuit_green then
                    deploy_signal = deploy_signal + (circuit_green.get_signal({type="virtual", name="signal-D"}) or 0)
                end
                
                -- Check if the signal has increased (positive edge trigger)
                if deploy_signal > deployer.last_signal and deploy_signal > 0 then
                    log_message("Deploy signal received: " .. deploy_signal)
                    
                    -- Find a source train to deploy
                    -- Same name as the deployer indicates the source
                    local source_name = deployer.entity.backer_name
                    for _, source in pairs(sources) do
                        if source.entity and source.entity.valid and source.entity.backer_name == source_name then
                            local _, source_train = get_source_composition(source.entity)
                            if source_train then
                                deploy_train(deployer, source.entity, source_train)
                                break  -- Deploy one train and exit
                            end
                        end
                    end
                end

                deployer.last_signal = deploy_signal
            end
        end
        ::continue::
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
    local old_state = event.old_state
    log_message("Train " .. train.id .. " state changed from " .. old_state .. " to: " .. state)
    
    -- Handle station arrivals
    if (state == defines.train_state.wait_station or state == defines.train_state.arrive_station) then
        local station = train.station
        if not (station and station.valid) then 
            log_message("No valid station")
            return 
        end
        
        log_message("Train at station: " .. station.backer_name)
        
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

local source_metatable =
{
    __index = function(key)
        return "no value for key " .. key
    end
}
local deployer_metatable =
{
    __index = function(key)
        return "no value for key " .. key
    end
}
local cleaner_metatable =
{
    __index = function(key)
        return "no value for key " .. key
    end
}
script.register_metatable("atd-source", source_metatable)
script.register_metatable("atd-deployer", deployer_metatable)
script.register_metatable("atd-cleaner", cleaner_metatable)

-- Initialize or update stored stations
local function initialize()
    -- Reset all station registers
    sources = {}
    deployers = {}
    cleaners = {}
    setmetatable(sources, source_metatable)
    setmetatable(deployers, deployer_metatable)
    setmetatable(cleaners, cleaner_metatable)
    
    log_message("Initializing mod")
    
    -- Find all stations on all surfaces
    for _, surface in pairs(game.surfaces) do
        -- Find all sources
        local foundSources = surface.find_entities_filtered{name = "atd-source"}
        log_message("Found " .. #foundSources .. " sources on surface " .. surface.name)
        
        for _, entity in pairs(foundSources) do
            -- Create interface if needed
            local interface = surface.find_entities_filtered{
                position = entity.position,
                name = "atd-source-interface",
                limit = 1
            }[1]
            
            if not interface then
                interface = surface.create_entity{
                    name = "atd-source-interface",
                    position = entity.position,
                    force = entity.force
                }
            end
            
            sources[entity.unit_number] = {
                entity = entity,
                interface = interface
            }
        end
        
        -- Find all deployers
        local foundDeployers = surface.find_entities_filtered{name = "atd-deployer"}
        log_message("Found " .. #foundDeployers .. " deployers on surface " .. surface.name)
        
        for _, entity in pairs(foundDeployers) do
            -- Create interface if needed
            local interface = surface.find_entities_filtered{
                position = entity.position,
                name = "atd-deployer-interface",
                limit = 1
            }[1]
            
            if not interface then
                interface = surface.create_entity{
                    name = "atd-deployer-interface",
                    position = entity.position,
                    force = entity.force
                }
            end
            
            deployers[entity.unit_number] = {
                entity = entity,
                interface = interface,
                last_signal = 0
            }
        end
        
        -- Find all cleaners
        local foundCleaners = surface.find_entities_filtered{name = "atd-cleaner"}
        log_message("Found " .. #foundCleaners .. " cleaners on surface " .. surface.name)
        
        for _, entity in pairs(foundCleaners) do
            -- Create interface if needed
            local interface = surface.find_entities_filtered{
                position = entity.position,
                name = "atd-cleaner-interface",
                limit = 1
            }[1]
            
            if not interface then
                interface = surface.create_entity{
                    name = "atd-cleaner-interface",
                    position = entity.position,
                    force = entity.force
                }
            end
            
            cleaners[entity.unit_number] = {
                entity = entity,
                interface = interface
            }
        end
    end

    log_message("Initialization complete")
end

local function load()
    setmetatable(sources, source_metatable)
    setmetatable(deployers, deployer_metatable)
    setmetatable(cleaners, cleaner_metatable)
end

-- Check circuit conditions every 30 ticks (0.5 seconds)
local function on_nth_tick()
    check_circuit_conditions()
end

-- Register events
script.on_init(initialize)
script.on_configuration_changed(initialize)
script.on_load(load)

script.on_event(defines.events.on_built_entity, track_entities_construction)
script.on_event(defines.events.on_robot_built_entity, track_entities_construction)

script.on_event(defines.events.on_pre_player_mined_item, track_entities_removal)
script.on_event(defines.events.on_robot_pre_mined, track_entities_removal)
script.on_event(defines.events.on_entity_died, track_entities_removal)
script.on_event(defines.events.on_object_destroyed, track_entities_removal)

script.on_event(defines.events.on_train_changed_state, handle_train_changed_state)

-- Set up the nth tick handler
script.on_nth_tick(30, on_nth_tick)