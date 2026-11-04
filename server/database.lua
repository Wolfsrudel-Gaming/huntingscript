--[[
    Datenbank: Tabellen werden beim Start automatisch angelegt (siehe auch sql/install.sql).
]]

DatabaseReady = false
local readyCallbacks = {}

--- Führt cb aus, sobald die Tabellen existieren.
function OnDatabaseReady(cb)
    if DatabaseReady then
        CreateThread(cb)
    else
        readyCallbacks[#readyCallbacks + 1] = cb
    end
end

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `hunting_trophies` (
            `id`         INT NOT NULL AUTO_INCREMENT,
            `identifier` VARCHAR(64) NOT NULL,
            `item`       VARCHAR(50) NOT NULL,
            `x`          FLOAT NOT NULL,
            `y`          FLOAT NOT NULL,
            `z`          FLOAT NOT NULL,
            `heading`    FLOAT NOT NULL DEFAULT 0,
            `bucket`     INT NOT NULL DEFAULT 0,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `identifier` (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `hunting_tanning` (
            `id`         INT NOT NULL AUTO_INCREMENT,
            `rack`       VARCHAR(64) NOT NULL,
            `slot`       INT NOT NULL,
            `identifier` VARCHAR(64) NOT NULL,
            `input`      VARCHAR(50) NOT NULL,
            `output`     VARCHAR(50) NOT NULL,
            `amount`     INT NOT NULL DEFAULT 1,
            `finish_at`  INT NOT NULL,
            PRIMARY KEY (`id`),
            UNIQUE KEY `rack_slot` (`rack`, `slot`),
            KEY `identifier` (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    DatabaseReady = true
    for _, cb in ipairs(readyCallbacks) do
        CreateThread(cb)
    end
    readyCallbacks = {}
end)
