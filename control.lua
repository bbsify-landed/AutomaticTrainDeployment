-- Automatic Train Deployment
-- Original mod by aaargha: https://mods.factorio.com/mods/aaargha/AutomaticTrainDeployment
-- Updated for Factorio 2.0 and Space Age 2.0
local util = require("util")

local sources = {}     -- Train source stations
local deployers = {}   -- Train deployer stations
local cleaners = {}    -- Train cleaner stations

-- trains can't be in different orientations than this
local direction_to_orientation = {
    [defines.direction.north] = 0,
    [defines.direction.east] = 0.25,
    [defines.direction.south] = 0.5,
    [defines.direction.west] = 0.75,
}
local function orientation_to_direction(o)
    return (o * 16) % 16
end

local debug = false

-- Add logging function for easier debugging
local function log_message(message)
    if not debug then return end
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
    local source_train = source_station.get_stopped_train()
    if not (source_train and source_train.valid) then
        return nil, nil
    end
    
    return source_train.carriages, source_train
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
    
    -- Get the source train composition with detailed carriage information
    local source_composition, _ = get_source_composition(source_station)
    if not source_composition then
        log_message("Failed to get source composition")
        return false
    end
    
    local curr_rail_dir = deployer.entity.connected_rail_direction
    local connected_rail = deployer.entity.connected_rail
    if not (connected_rail and connected_rail.valid) then
        log_message("Invalid connected rail")
        return false
    end
    if connected_rail.trains_in_block > 0 then
        return false
    end

    local source_station_orientation = direction_to_orientation[source_station.direction]
    local deployer_orientation = direction_to_orientation[deployer.entity.direction]

    log_message("Source station orientation: " .. source_station_orientation)
    log_message("Deployer orientation: " .. deployer_orientation)

    local orientation_diff = deployer_orientation - source_station_orientation
    if orientation_diff < 0 then
        orientation_diff = orientation_diff + 1
    end
    log_message("Orientation difference: " .. orientation_diff)

    local rail_end = connected_rail.get_rail_end(curr_rail_dir)
    rail_end.flip_direction()
    local made_space = rail_end.move_natural() and rail_end.move_natural()
    if not made_space then
        log_message("Failed to make space for new train")
        return false
    end

    local curr_carriage = nil
    local composition_idx = 1
    local iters = 0
    while composition_idx <= #source_composition and iters < 100 do
        log_message("Deploying carriage " .. composition_idx .. "/" .. #source_composition)
        local carriage = source_composition[composition_idx]

        if not (rail_end and rail_end.valid) then
            log_message("Ran out of rail")
            return false
        end

        log_message("Deploying to rail: " .. serpent.line(rail_end.rail.position))

        local orientation = carriage.orientation + orientation_diff
        if orientation >= 1 then
            orientation = orientation - 1
        end
        log_message("Carriage orientation: " .. orientation)

        local new_carriage = deployer.entity.surface.create_entity{
            name = carriage.name,
            orientation = orientation,
            position = rail_end.rail.position,
            force = deployer.entity.force,
        }

        if new_carriage and new_carriage.valid then
            composition_idx = composition_idx + 1

            -- if locomotive, copy fuel inventory
            if new_carriage.type == "locomotive" then
                local fuel_inventory = new_carriage.get_fuel_inventory()
                if fuel_inventory and fuel_inventory.valid then
                    local source_fuel_inventory = carriage.get_fuel_inventory()
                    if source_fuel_inventory and source_fuel_inventory.valid then
                        for i = 1, #source_fuel_inventory do
                            local item = source_fuel_inventory[i]
                            if item and item.valid_for_read then
                                fuel_inventory.insert(item)
                            end
                        end
                    end
                end
            end

            -- if cargo wagon, copy contents
            if new_carriage.type == "cargo-wagon" then
                local cargo_inventory = new_carriage.get_inventory(defines.inventory.cargo_wagon)
                if cargo_inventory and cargo_inventory.valid then
                    local source_cargo_inventory = carriage.get_inventory(defines.inventory.cargo_wagon)
                    if source_cargo_inventory and source_cargo_inventory.valid then
                        for i = 1, #source_cargo_inventory do
                            local item = source_cargo_inventory[i]
                            if item and item.valid_for_read then
                                cargo_inventory.insert(item)
                            end
                        end
                    end
                end
            end

            -- if fluid wagon, copy contents
            if new_carriage.type == "fluid-wagon" then
                local fc = carriage.get_fluid_contents()
                for name, amount in pairs(fc) do
                    new_carriage.insert_fluid({name = name, amount = amount})
                end
            end
        

            if curr_carriage and curr_carriage.valid then
                curr_carriage.connect_rolling_stock(curr_rail_dir)
            end
            curr_carriage = new_carriage
        end

        local moved = rail_end.move_natural()
        if not moved then
            log_message("Ran out of rail")
            return false
        end

        iters = iters + 1
    end
    
    if curr_carriage and curr_carriage.valid then
        curr_carriage.train.schedule = source_train.schedule
        curr_carriage.train.manual_mode = source_train.manual_mode
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
            return 
        end

        log_message("Train " .. train.id .. " arrived at station: " .. station.name .. " " .. station.backer_name)

        if station.name == "atd-cleaner" then
            -- If it's at a cleaner, remove the train
            log_message("Cleaning train at station: " .. station.backer_name)
            for _, carriage in ipairs(train.carriages) do
                if carriage.valid then
                    carriage.destroy()
                end
            end
        end
    end
end

-- Initialize or update stored stations
local function initialize()
    -- Reset all station registers
    storage.sources = {}
    storage.deployers = {}
    storage.cleaners = {}

    sources = storage.sources
    deployers = storage.deployers
    cleaners = storage.cleaners
    
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
    sources = storage.sources
    deployers = storage.deployers
    cleaners = storage.cleaners
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
script.on_nth_tick(1, on_nth_tick)