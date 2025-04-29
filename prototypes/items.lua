data:extend({
    {
        type = "item",
        name = "atd-source",
        icon = "__AutomaticTrainDeployment_SpaceAge__/graphics/icons/train-stop.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "train-transport",
        order = "a[train-system]-f[train-stop]-a[source]",
        place_result = "atd-source",
        stack_size = 10
    },
    {
        type = "item",
        name = "atd-deployer",
        icon = "__AutomaticTrainDeployment_SpaceAge__/graphics/icons/train-stop.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "train-transport",
        order = "a[train-system]-f[train-stop]-b[deployer]",
        place_result = "atd-deployer",
        stack_size = 10
    },
    {
        type = "item",
        name = "atd-cleaner",
        icon = "__AutomaticTrainDeployment_SpaceAge__/graphics/icons/train-stop.png",
        icon_size = 64,
        icon_mipmaps = 4,
        subgroup = "train-transport",
        order = "a[train-system]-f[train-stop]-c[cleaner]",
        place_result = "atd-cleaner",
        stack_size = 10
    }
})