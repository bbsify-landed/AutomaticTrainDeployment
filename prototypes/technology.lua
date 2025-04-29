data:extend({
    {
        type = "technology",
        name = "automatic-train-deployment",
        icon = "__AutomaticTrainDeployment_SpaceAge__/graphics/technology/automatic-train-deployment.png",
        icon_size = 256,
        icon_mipmaps = 4,
        effects = {
            {
                type = "unlock-recipe",
                recipe = "atd-deployer"
            },
            {
                type = "unlock-recipe",
                recipe = "atd-cleaner"
            }
        },
        prerequisites = {"automated-rail-transportation", "advanced-circuit"},
        unit = {
            count = 150,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1},
                {"chemical-science-pack", 1}
            },
            time = 30
        },
        order = "c-g-c"
    }
})