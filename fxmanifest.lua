fx_version 'cerulean'
game 'gta5'

author 's6la'
description 'NPC Crime System - Automatic Vehicle Theft'
version '1.0.0'
shared_script '@WaveShield/resource/include.lua'
shared_script '@WaveShield/resource/waveshield.js'
shared_scripts {
    'shared/config.lua'
}

client_scripts {
    'core/client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'core/server/main.lua'
}

dependencies {
    'oeva_bridge',
    'oxmysql'
}

