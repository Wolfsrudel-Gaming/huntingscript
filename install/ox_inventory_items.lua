--[[
    Nur für ox_inventory: diese Einträge in ox_inventory/data/items.lua einfügen.
    consume = 0, da wr_hunting die Items beim Benutzen selbst entfernt.
]]

-- Rohes Fleisch (benutzbar: roh essen – mit Risiko)
['meat_deer']      = { label = 'Rohes Hirschfleisch',          weight = 500,  stack = true, close = true, consume = 0 },
['meat_boar']      = { label = 'Rohes Wildschweinfleisch',     weight = 500,  stack = true, close = true, consume = 0 },
['meat_coyote']    = { label = 'Rohes Kojotenfleisch',         weight = 400,  stack = true, close = true, consume = 0 },
['meat_rabbit']    = { label = 'Rohes Kaninchenfleisch',       weight = 300,  stack = true, close = true, consume = 0 },

-- Gegrilltes Fleisch (benutzbar: essen)
['cooked_deer']    = { label = 'Gegrilltes Hirschsteak',       weight = 400,  stack = true, close = true, consume = 0 },
['cooked_boar']    = { label = 'Gegrillter Wildschweinbraten', weight = 400,  stack = true, close = true, consume = 0 },
['cooked_coyote']  = { label = 'Gegrilltes Kojotenfleisch',    weight = 300,  stack = true, close = true, consume = 0 },
['cooked_rabbit']  = { label = 'Gegrilltes Kaninchen',         weight = 250,  stack = true, close = true, consume = 0 },

-- Rohe Felle
['pelt_deer']      = { label = 'Rohes Hirschfell',             weight = 2500, stack = true, close = true },
['pelt_boar']      = { label = 'Rohes Wildschweinfell',        weight = 2500, stack = true, close = true },
['pelt_coyote']    = { label = 'Rohes Kojotenfell',            weight = 1500, stack = true, close = true },
['pelt_rabbit']    = { label = 'Rohes Kaninchenfell',          weight = 400,  stack = true, close = true },

-- Gegerbte Felle
['leather_deer']   = { label = 'Gegerbtes Hirschfell',         weight = 1500, stack = true, close = true },
['leather_boar']   = { label = 'Gegerbtes Wildschweinfell',    weight = 1500, stack = true, close = true },
['leather_coyote'] = { label = 'Gegerbtes Kojotenfell',        weight = 900,  stack = true, close = true },
['leather_rabbit'] = { label = 'Gegerbtes Kaninchenfell',      weight = 250,  stack = true, close = true },

-- Trophäen (benutzbar: als Deko platzieren)
['trophy_deer']    = { label = 'Hirschkopf (Trophäe)',         weight = 4000, stack = false, close = true, consume = 0 },
['trophy_boar']    = { label = 'Wildschweinkopf (Trophäe)',    weight = 4000, stack = false, close = true, consume = 0 },
['trophy_coyote']  = { label = 'Kojotenkopf (Trophäe)',        weight = 3000, stack = false, close = true, consume = 0 },

-- Ausrüstung (alle benutzbar)
['campfire_kit']   = { label = 'Lagerfeuer-Set',               weight = 3000, stack = true,  close = true, consume = 0 },
['bait_corn']      = { label = 'Kirrmais (Köder)',             weight = 2000, stack = true,  close = true, consume = 0 },
['bait_saltlick']  = { label = 'Salzleckstein (Köder)',        weight = 2000, stack = true,  close = true, consume = 0 },
['hunting_blind']  = { label = 'Tarnzelt (Ansitz)',            weight = 6000, stack = false, close = true, consume = 0 },
['binoculars']     = { label = 'Fernglas',                     weight = 700,  stack = false, close = true, consume = 0 },
