fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

name 'jenn_freecam'
description 'Cinematic Freecam for RedM'
version '1.0.0'
author 'jenn'

shared_scripts {
    '@ox_lib/init.lua',
}

client_scripts {
    'cl_main.lua',
    'config.lua' 
}

lua54 'yes'