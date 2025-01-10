fx_version 'cerulean'
game 'gta5'

name 'cdn-fuel'
author 'https://github.com/icarius' -- Base Refueling System: (https://github.com/InZidiuZ/LegacyFuel), other code by Codine (https://www.github.com/CodineDev).
description 'Qbox version of cdn-fuel'
version '2.1.9'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua', -- OX_Lib, only line this in if you have ox_lib and are using them.
    '@qbx_core/modules/lib.lua',
    'shared/config.lua',
}

client_scripts {
    '@PolyZone/client.lua',
    '@qbx_core/modules/playerdata.lua',
    'client/fuel_cl.lua',
    'client/electric_cl.lua',
    'client/station_cl.lua',
    'client/utils.lua',
    'client/exporthandler.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/fuel_sv.lua',
    'server/station_sv.lua',
    'server/electric_sv.lua',
}

files {
    'locales/*.lua',
    'stream/[electric_nozzle]/electric_nozzle_typ.ytyp',
    'stream/[electric_charger]/electric_charger_typ.ytyp',
}

exports { -- Call with exports['cdn-fuel']:GetFuel or exports['cdn-fuel']:SetFuel
    'GetFuel',
    'SetFuel'
}

lua54 'yes'

dependencies { -- Make sure these are started before cdn-fuel in your server.cfg!
    'PolyZone',
    'interact-sound',
    'ox_lib', -- Ox Library
    'ox_target',
}

data_file 'DLC_ITYP_REQUEST' 'stream/[electric_nozzle]/electric_nozzle_typ.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/[electric_charger]/electric_charger_typ.ytyp'

provide 'cdn-syphoning' -- This is used to override cdn-syphoning(https://github.com/CodineDev/cdn-syphoning) if you have it installed. If you don't have it installed, don't worry about this. If you do, we recommend removing it and using this instead.
provide 'LegacyFuel'