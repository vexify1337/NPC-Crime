Config = {}

Config.debug = false

Config.distance_check = {
    min_distance = 20.0,
    check_interval = 5000,
    time_before_theft = 60000
}

Config.allowed_vehicle_classes = {
    [6] = true,
    [7] = true,
    [4] = true,
    [5] = true,
    [3] = true,
}

Config.whitelist_vehicles = {
    'police',
    'police2',
    'police3',
    'police4',
    'sheriff',
    'sheriff2',
    'fbi',
    'fbi2',
    'state',
    'state2',
    'riot',
    'policet',
    'policeb',
}

Config.blacklist_vehicles = {
}

Config.npc = {
    model = 'a_m_y_hipster_01',
    spawn_distance = 30.0,
    carjack_animation = {
        dict = 'mp_common_miss',
        name = 'carjack_idle'
    },
    carjack_animation_alt = {
        dict = 'amb@world_human_welding',
        name = 'welding'
    }
}

Config.destinations = {
    {x = 196.73, y = 338.12, z = 105.76, w = 191.61},
    {x = -257.48, y = -441.34, z = 27.44, w = 195.66},
    {x = -335.85, y = -1377.05, z = 31.30, w = 194.39},
}

Config.vehicle_stripping = {
    remove_wheels = true,
    remove_doors = true,
    damage_engine = true,
    damage_body = true,
    set_dirt_level = 1.0,
}

