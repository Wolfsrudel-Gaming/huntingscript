fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'wr_hunting'
author 'Wolfsrudel Gaming'
description 'Realistisches Jagdsystem für ESX – Jagdreviere in der offenen Spielwelt'
version '1.0.0'

dependencies {
    '/onesync',
    'es_extended',
    'oxmysql',
}

shared_scripts {
    'config.lua',
    'locales/de.lua',
    'locales/en.lua',
    'shared/main.lua',
}

client_scripts {
    'client/utils.lua',
    'client/interaction.lua',
    'client/animals.lua',
    'client/hunting.lua',
    'client/police.lua',
    'client/butcher.lua',
    'client/tanning.lua',
    'client/cooking.lua',
    'client/trophies.lua',
    'client/trader.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/utils.lua',
    'server/database.lua',
    'server/animals.lua',
    'server/hunting.lua',
    'server/butcher.lua',
    'server/tanning.lua',
    'server/cooking.lua',
    'server/trophies.lua',
    'server/trader.lua',
}
