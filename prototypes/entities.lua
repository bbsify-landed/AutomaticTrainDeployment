-- Get the base game train stop to use as a template
local base_train_stop = data.raw["train-stop"]["train-stop"]

-- Create deep copies of the base train stop using util.table.deepcopy
local deployer = util.table.deepcopy(base_train_stop)
local cleaner = util.table.deepcopy(base_train_stop)

-- Customize deployer
deployer.name = "atd-deployer"
deployer.minable.result = "atd-deployer"
deployer.light1.light.color = {r = 0.1, g = 0.9, b = 0.1} -- Green light
deployer.color = {r = 0.09, g = 0.75, b = 0.6}
deployer.chart_color = {r = 0.09, g = 0.75, b = 0.6}
deployer.map_color = {r = 0.09, g = 0.75, b = 0.6}

-- Customize cleaner
cleaner.name = "atd-cleaner"
cleaner.minable.result = "atd-cleaner"
cleaner.light1.light.color = {r = 0.9, g = 0.1, b = 0.1} -- Red light
cleaner.color = {r = 0.95, g = 0.09, b = 0.1}
cleaner.chart_color = {r = 0.95, g = 0.09, b = 0.1}
cleaner.map_color = {r = 0.95, g = 0.09, b = 0.1}

-- Interface entities
local deployer_interface =
{
    type = "simple-entity",
    name = "atd-deployer-interface",
    icon = "__AutomaticTrainDeployment_SpaceAge__/graphics/icons/train-stop.png",
    icon_size = 64,
    icon_mipmaps = 4,
    flags = {"not-on-map", "placeable-off-grid"},
    collision_mask = {
        layers = {}  -- In Factorio 2.0, collision_mask needs a layers table
    },
    collision_box = {{-0.1, -0.1}, {0.1, 0.1}},
    selectable_in_game = false,
    picture = {
        filename = "__core__/graphics/empty.png",
        priority = "low",
        width = 1,
        height = 1
    }
}

local cleaner_interface =
{
    type = "simple-entity",
    name = "atd-cleaner-interface",
    icon = "__AutomaticTrainDeployment_SpaceAge__/graphics/icons/train-stop.png",
    icon_size = 64,
    icon_mipmaps = 4,
    flags = {"not-on-map", "placeable-off-grid"},
    collision_mask = {
        layers = {}  -- In Factorio 2.0, collision_mask needs a layers table
    },
    collision_box = {{-0.1, -0.1}, {0.1, 0.1}},
    selectable_in_game = false,
    picture = {
        filename = "__core__/graphics/empty.png",
        priority = "low",
        width = 1,
        height = 1
    }
}

data:extend({
    deployer,
    deployer_interface,
    cleaner,
    cleaner_interface
})