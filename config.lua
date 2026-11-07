Config = {}

--[[ =====================================================================
    ALLGEMEIN
===================================================================== ]]
Config.Locale         = 'de'        -- 'de' | 'en'
Config.Debug          = false       -- Zeigt Status über Tieren an + Konsolen-Logs
Config.Inventory      = 'auto'      -- 'auto' | 'esx' | 'ox' (ox_inventory)
Config.Menu           = 'auto'      -- 'auto' | 'esx_context' | 'esx_menu_default'
Config.InteractKey    = 38          -- E   (Steuerung: https://docs.fivem.net/docs/game-references/controls/)
Config.CancelKey      = 73          -- X   (Fortschrittsbalken abbrechen)
Config.NetworkedProps = true        -- Handprops (Messer, Fleisch) auch für andere Spieler sichtbar
Config.AdminGroups    = { 'admin', 'superadmin' }

-- Eigene Benachrichtigung (Client). nil = ESX.ShowNotification
-- Beispiel ox_lib: function(msg, type) lib.notify({ description = msg, type = type }) end
Config.Notify = nil

--[[ =====================================================================
    JAGDREVIERE
    Tiere spawnen ausschließlich innerhalb dieser Kreise in der normalen
    Spielwelt (keine Instanzen). Gewichtung in "animals" = relative Häufigkeit.
===================================================================== ]]
Config.ZoneMargin        = 25.0     -- Toleranz am Reviersrand (Meter) für Waffen-Meldungen
Config.ZoneNotifications = true     -- Hinweis beim Betreten/Verlassen eines Reviers
Config.ZoneBlips = {
    enabled     = true,
    sprite      = 141,
    colour      = 2,
    scale       = 0.8,
    radiusAlpha = 70,
}

Config.Zones = {
    {
        id         = 'paleto_forest',
        label      = 'Jagdrevier Paleto Forest',
        center     = vector3(-650.0, 5500.0, 50.0),
        radius     = 350.0,
        maxAnimals = 8,
        animals    = { deer = 50, boar = 30, rabbit = 20 },
    },
    {
        id         = 'chiliad_wilderness',
        label      = 'Jagdrevier Chiliad Mountain State Wilderness',
        center     = vector3(-1300.0, 4850.0, 120.0),
        radius     = 420.0,
        maxAnimals = 10,
        animals    = { deer = 45, boar = 35, coyote = 10, rabbit = 10 },
    },
    {
        id         = 'mount_chiliad',
        label      = 'Jagdrevier Mount Chiliad',
        center     = vector3(450.0, 5450.0, 600.0),
        radius     = 400.0,
        maxAnimals = 8,
        animals    = { deer = 40, coyote = 30, boar = 20, rabbit = 10 },
    },
    {
        id         = 'grand_senora',
        label      = 'Jagdrevier Grand Senora Wüste',
        center     = vector3(1000.0, 3100.0, 50.0),
        radius     = 400.0,
        maxAnimals = 8,
        animals    = { coyote = 60, rabbit = 40 },
    },
}

--[[ =====================================================================
    SPAWNING
===================================================================== ]]
Config.Spawning = {
    interval        = 20,       -- Sekunden zwischen zwei Spawn-Wellen pro Revier
    minDistance     = 70.0,     -- Mindestabstand eines Spawns zu jedem Spieler
    maxDistance     = 170.0,    -- Maximalabstand zum ausgewählten Spieler
    despawnDistance = 450.0,    -- Lebende Tiere ohne Spieler in diesem Umkreis werden entfernt
    carcassLifetime = 900,      -- Sekunden, bis ein nicht ausgenommener Kadaver verschwindet
    homeRadius      = 45.0,     -- Radius, in dem ein Tier umherstreift
    minGroundNormal = 0.72,     -- Verhindert Spawns an Steilhängen (1.0 = flach)
    avoidVisible    = true,     -- Bevorzugt Spawnpunkte außerhalb des Sichtfelds
    maxGlobal       = 60,       -- Maximale Anzahl lebender Tiere auf dem gesamten Server
}

--[[ =====================================================================
    TIERE
    behaviour: 'prey'       = Fluchttier
               'aggressive' = kann Spieler angreifen und Schaden verursachen
    activity : Häufigkeits-Multiplikator je Tageszeit (night/dawn/day/dusk)
===================================================================== ]]
Config.Animals = {
    deer = {
        label       = 'Hirsch',
        model       = 'a_c_deer',
        health      = 250,
        behaviour   = 'prey',
        detection   = 45.0,         -- Wahrnehmungsradius (Meter)
        fleeTime    = 30,           -- Sekunden Fluchtverhalten
        group       = { 1, 2 },     -- Gruppengröße (min, max)
        activity    = { night = 0.5, dawn = 1.6, day = 1.0, dusk = 1.6 },
        alertChance = 30,           -- % Chance auf Polizeimeldung beim Erlegen
        protected   = false,        -- Geschützte Art → Meldung mit Config.Police.kill.protectedChance
        butcherTime = 15,           -- Sekunden zum Ausnehmen
        loot = {
            meat   = { item = 'meat_deer', min = 3, max = 5 },
            pelt   = { item = 'pelt_deer' },
            trophy = 'trophy_deer',
        },
    },

    boar = {
        label       = 'Wildschwein',
        model       = 'a_c_boar',
        health      = 320,
        behaviour   = 'aggressive',
        detection   = 30.0,
        fleeTime    = 20,
        group       = { 1, 3 },
        activity    = { night = 1.4, dawn = 1.2, day = 0.7, dusk = 1.2 },
        alertChance = 30,
        protected   = false,
        butcherTime = 15,
        aggressive = {
            aggroRadius    = 15.0,      -- Kommt ein Spieler näher, kann das Tier angreifen
            chance         = 60,        -- % Angriff statt Flucht (Tag)
            nightChance    = 75,        -- % Angriff statt Flucht (Nacht)
            onDamageChance = 85,        -- % Gegenangriff nach Treffer
            fleeOnDetect   = false,     -- true = flieht schon beim Wahrnehmen (wie Fluchttier)
            reach          = 1.9,       -- Angriffsreichweite (Meter)
            damage         = { 12, 20 },-- Schaden pro Treffer (min, max)
            cooldown       = 1600,      -- ms zwischen zwei Treffern
            ragdollChance  = 35,        -- % Chance, den Spieler umzurennen
            chaseDistance  = 70.0,      -- Verfolgung bricht ab, wenn das Ziel weiter weg ist
            maxChaseTime   = 35,        -- Sekunden, danach zieht sich das Tier zurück
        },
        loot = {
            meat   = { item = 'meat_boar', min = 2, max = 4 },
            pelt   = { item = 'pelt_boar' },
            trophy = 'trophy_boar',
        },
    },

    coyote = {
        label       = 'Kojote',
        model       = 'a_c_coyote',
        health      = 160,
        behaviour   = 'aggressive',
        detection   = 35.0,
        fleeTime    = 25,
        group       = { 1, 3 },
        activity    = { night = 1.8, dawn = 1.3, day = 0.5, dusk = 1.3 },
        alertChance = 25,
        protected   = false,
        butcherTime = 10,
        aggressive = {
            aggroRadius    = 20.0,
            chance         = 40,
            nightChance    = 75,
            onDamageChance = 70,
            fleeOnDetect   = false,
            reach          = 1.6,
            damage         = { 6, 12 },
            cooldown       = 1100,
            ragdollChance  = 0,
            chaseDistance  = 90.0,
            maxChaseTime   = 40,
        },
        loot = {
            meat   = { item = 'meat_coyote', min = 1, max = 2 },
            pelt   = { item = 'pelt_coyote' },
            trophy = 'trophy_coyote',
        },
    },

    rabbit = {
        label       = 'Kaninchen',
        model       = 'a_c_rabbit_01',
        health      = 110,
        behaviour   = 'prey',
        detection   = 20.0,
        fleeTime    = 15,
        group       = { 1, 2 },
        activity    = { night = 1.0, dawn = 1.4, day = 1.0, dusk = 1.4 },
        alertChance = 10,
        protected   = false,
        butcherTime = 6,
        loot = {
            meat = { item = 'meat_rabbit', min = 1, max = 1 },
            pelt = { item = 'pelt_rabbit' },
            -- kein Trophäen-Drop für Kaninchen
        },
    },
}

--[[ =====================================================================
    WAHRNEHMUNG / VERHALTEN
===================================================================== ]]
Config.Behaviour = {
    gunshotRadius         = 140.0,  -- Tiere in diesem Umkreis flüchten bei Schüssen
    gunshotRadiusSilenced = 45.0,   -- ... mit Schalldämpfer
    stealthMultiplier     = 0.5,    -- Schleichen (Ducken) halbiert die Wahrnehmung
    sprintMultiplier      = 1.6,    -- Sprinten vergrößert sie
    vehicleMultiplier     = 1.3,    -- Fahrzeuge
    noLosMultiplier       = 0.6,    -- Keine Sichtlinie (Deckung)
    nightMultiplier       = 0.8,    -- Nachts sehen Tiere schlechter
}

--[[ =====================================================================
    JAGDWAFFEN
    clean = true  → sauberer Schuss möglich (Kopf-/Halsschuss = perfekte Qualität)
    clean = false → Schrot etc. beschädigt Fell und Fleisch
    alertOutsideZone = false → Ziehen außerhalb der Reviere löst keine Meldung aus
===================================================================== ]]
Config.HuntingWeapons = {
    ['WEAPON_MUSKET']            = { clean = true },
    ['WEAPON_SNIPERRIFLE']       = { clean = true },
    ['WEAPON_MARKSMANRIFLE']     = { clean = true },
    ['WEAPON_MARKSMANRIFLE_MK2'] = { clean = true },
    ['WEAPON_PRECISIONRIFLE']    = { clean = true },
    ['WEAPON_DBSHOTGUN']         = { clean = false },
    ['WEAPON_PUMPSHOTGUN']       = { clean = false },
}

-- Todesursachen, die Fell und Fleisch (fast) vollständig zerstören
Config.RuinedCauses = {
    'WEAPON_RUN_OVER_BY_CAR', 'WEAPON_RAMMED_BY_CAR', 'WEAPON_EXPLOSION', 'WEAPON_FIRE',
    'WEAPON_GRENADE', 'WEAPON_GRENADELAUNCHER', 'WEAPON_RPG', 'WEAPON_STICKYBOMB',
    'WEAPON_MOLOTOV', 'WEAPON_PIPEBOMB', 'WEAPON_HOMINGLAUNCHER', 'WEAPON_MINIGUN',
    'WEAPON_PROXMINE', 'WEAPON_COMPACTLAUNCHER',
}

-- Knochen, die als sauberer Kopf-/Halsschuss zählen (SKEL_Head, SKEL_Neck_1)
Config.HeadshotBones = { 31086, 39317 }

-- Qualitätsstufen der Beute
Config.Quality = {
    perfect = { meatBonus = 1,  peltChance = 100 },
    good    = { meatBonus = 0,  peltChance = 100 },
    damaged = { meatBonus = -1, peltChance = 60 },
    ruined  = { meatBonus = -2, peltChance = 0 },
}

--[[ =====================================================================
    POLIZEI / MELDUNGEN
===================================================================== ]]
Config.Police = {
    jobs        = { 'police', 'sheriff' },      -- Erhalten Meldungen
    ignoredJobs = { 'police', 'sheriff' },      -- Lösen keine Meldungen aus (z.B. auch 'ranger')

    -- 'builtin' = eingebaute Meldung (Benachrichtigung + Blip) an alle Polizisten
    -- 'client'  = Config.Police.clientDispatch wird beim Verdächtigen ausgeführt
    -- 'server'  = Config.Police.serverDispatch wird serverseitig ausgeführt
    dispatch = 'builtin',

    locationFuzz = 90.0,        -- Ungenauigkeit der gemeldeten Position (Meter)
    blip = {
        sprite   = 141,
        colour   = 1,
        scale    = 1.1,
        radius   = 150.0,
        duration = 150,         -- Sekunden
        flash    = true,
    },

    -- Erlegtes Tier: jede Tötung kann gemeldet werden (Chance je Tier: Config.Animals[x].alertChance)
    kill = {
        enabled           = true,
        cooldown          = 45,     -- Sekunden pro Spieler zwischen zwei Meldungen
        nightBonus        = 15,     -- +% bei Nacht (Wilderei-Verdacht)
        outsideZoneChance  = 100,   -- Tier außerhalb eines Reviers erlegt
        protectedChance    = 100,   -- Geschützte Art
        noLicenseChance    = 100,   -- Ohne gültigen Jagdschein (siehe Config.License)
        closedSeasonChance = 100,   -- Abschuss in der Schonzeit (siehe Config.Seasons)
        overLimitChance    = 100,   -- Tageskontingent überschritten
    },

    -- Polizei kann Kadaver untersuchen (Todeszeit, Waffe, Verstöße) und Jagdscheine prüfen
    inspection = {
        enabled = true,
        key     = 47,               -- G
    },

    -- Jagdwaffe außerhalb eines Reviers gezogen
    weapon = {
        enabled     = true,
        chance      = 100,
        cooldown    = 120,
        onLeaveZone = true,         -- Auch melden, wenn man mit gezogener Waffe das Revier verlässt
    },

    -- Beispiele für externe Dispatch-Systeme (dispatch = 'client'):
    clientDispatch = function(alert)
        -- alert = { type = 'kill'|'weapon', coords = vector3, title = '', message = '', street = '', code = '' }
        --
        -- cd_dispatch:
        -- local data = exports['cd_dispatch']:GetPlayerInfo()
        -- TriggerServerEvent('cd_dispatch:AddNotification', {
        --     job_table = { 'police', 'sheriff' }, coords = alert.coords, title = alert.code .. ' - ' .. alert.title,
        --     message = alert.message, flash = 0, unique_id = data.unique_id, sound = 1,
        --     blip = { sprite = 141, scale = 1.1, colour = 1, flashes = true, text = alert.title, time = 5, radius = 0 },
        -- })
        --
        -- ps-dispatch:
        -- exports['ps-dispatch']:CustomAlert({ coords = alert.coords, message = alert.title, dispatchCode = alert.code,
        --     description = alert.message, radius = 0, sprite = 141, color = 1, scale = 1.1, length = 3 })
    end,

    serverDispatch = function(source, alert)
        -- Eigene serverseitige Integration (dispatch = 'server')
    end,
}

--[[ =====================================================================
    JAGDSCHEIN
    provider = 'builtin'     → eigener Jagdschein, beim Händler (license = true) kaufbar,
                               gültig für durationDays Echtzeit-Tage
    provider = 'esx_license' → Prüfung über esx_license (type)
    Wer ohne gültigen Schein jagt, wird bei jedem Abschuss gemeldet und erhält keine Erfahrung.
===================================================================== ]]
Config.License = {
    enabled      = true,
    provider     = 'builtin',
    type         = 'hunting',   -- nur für esx_license
    price        = 2500,
    durationDays = 7,
    account      = 'bank',      -- 'money' | 'bank'
}

--[[ =====================================================================
    SCHONZEITEN & ABSCHUSSKONTINGENT
    closedMonths: Monate (1-12, reales Serverdatum), in denen die Art nicht bejagt werden darf
    dailyLimit  : Abschüsse pro Spieler und Tag (0 = unbegrenzt)
    Verstöße werden gemeldet (Config.Police.kill.*Chance) und geben keine Erfahrung.
===================================================================== ]]
Config.Seasons = {
    enabled = true,
    animals = {
        deer   = { closedMonths = { 3, 4, 5 }, dailyLimit = 3 },    -- Setzzeit im Frühjahr
        boar   = { closedMonths = {},          dailyLimit = 5 },    -- Schwarzwild ganzjährig
        coyote = { closedMonths = {},          dailyLimit = 0 },    -- Raubwild ganzjährig
        rabbit = { closedMonths = {},          dailyLimit = 6 },
    },
}

--[[ =====================================================================
    WIND & WITTERUNG
    Der Wind wird serverweit synchronisiert und dreht langsam. Steht der Jäger
    so, dass der Wind seine Witterung zum Tier trägt, bemerkt es ihn deutlich
    früher. "Unter Wind" (Wind kommt vom Tier) ist er schwerer zu bemerken.
===================================================================== ]]
Config.Wind = {
    enabled          = true,
    changeInterval   = 240,     -- Sekunden zwischen Winddrehungen
    maxShift         = 40.0,    -- Maximale Drehung pro Änderung (Grad)
    scentMultiplier  = 1.7,     -- Tier steht unter dem Wind des Jägers
    coverMultiplier  = 0.6,     -- Jäger steht unter dem Wind des Tieres
    hud              = true,    -- Windanzeige in den Revieren
}

--[[ =====================================================================
    SCHWEISSFÄHRTE & NACHSUCHE
    Angeschossene Tiere bluten, hinterlassen eine für alle sichtbare Blutspur
    und verenden bei schweren Treffern nach einiger Zeit. Der Abschuss wird
    dem Schützen zugeschrieben – er muss das Tier aber erst finden.
===================================================================== ]]
Config.Tracking = {
    enabled          = true,
    bleedThreshold   = 0.7,     -- Unter 70 % Leben blutet das Tier
    bleedInterval    = 3000,    -- ms zwischen zwei Blutverlust-Ticks
    bleedRate        = 0.025,   -- Anteil der Max-Lebenspunkte pro Tick
    restThreshold    = 0.35,    -- Schwer verletzte Tiere legen sich nach der Flucht ins Wundbett
    dropDistance     = 2.5,     -- Meter zwischen zwei Blutstropfen
    decalLifetime    = 900,     -- Sekunden, die Blutspuren sichtbar bleiben
    maxDecals        = 200,     -- Maximale Blutspuren pro Client
    attributionTime  = 900,     -- Sekunden, in denen ein verendetes Tier dem Schützen zugeordnet wird
}

--[[ =====================================================================
    KÖDER (KIRRUNG / SALZLECKE)
    Ausgelegte Köder locken nach einiger Zeit passende Tiere an.
===================================================================== ]]
Config.Baits = {
    onlyInZones     = true,     -- Nur innerhalb der Jagdreviere auslegbar
    maxPerPlayer    = 2,
    placeTime       = 5,
    minDistance     = 25.0,     -- Mindestabstand zwischen zwei Ködern
    renderDistance  = 120.0,
    items = {
        bait_corn = {
            model        = 'prop_feed_sack_01',
            animals      = { boar = 85, rabbit = 15 },
            duration     = 1500,        -- Sekunden, die der Köder liegt
            attractDelay = { 60, 180 }, -- Sekunden bis zum nächsten angelockten Tier
            maxAnimals   = 3,           -- Tiere pro Köder
            spawnDistance = { 60.0, 110.0 },
            homeRadius   = 10.0,        -- Tiere bleiben in diesem Radius um den Köder
        },
        bait_saltlick = {
            model        = 'prop_feeder1',
            animals      = { deer = 100 },
            duration     = 1800,
            attractDelay = { 90, 240 },
            maxAnimals   = 2,
            spawnDistance = { 70.0, 120.0 },
            homeRadius   = 12.0,
        },
    },
}

--[[ =====================================================================
    ANSITZ / TARNZELT
    Wer sich im (eigenen oder fremden) Ansitz aufhält, wird von Tieren kaum bemerkt.
    fixed: feste Hochsitze in der Map (nur Tarnwirkung, kein Prop)
===================================================================== ]]
Config.Blinds = {
    item              = 'hunting_blind',
    model             = 'prop_hunterhide',
    radius            = 2.5,
    stealthMultiplier = 0.35,
    lifetime          = 7200,   -- Sekunden, danach wird das Tarnzelt automatisch abgebaut (Item zurück)
    maxPerPlayer      = 1,
    placeTime         = 10,
    renderDistance    = 150.0,
    fixed = {
        -- { coords = vector3(-1340.0, 4840.0, 140.0), radius = 3.0 },
    },
}

--[[ =====================================================================
    FERNGLAS
===================================================================== ]]
Config.Binoculars = {
    item      = 'binoculars',
    fovMax    = 45.0,
    fovMin    = 4.0,
    zoomSpeed = 4.0,
    maxRange  = 400.0,          -- Wild bis zu dieser Entfernung wird erkannt
}

--[[ =====================================================================
    JÄGER-ERFAHRUNG
    Erfahrung gibt es nur für legale Abschüsse. Höhere Stufen nehmen schneller
    aus, bekommen öfter zusätzliches Fleisch und werden später bemerkt.
    Die Trophäen-Chance (1 zu 250) bleibt davon unberührt.
===================================================================== ]]
Config.Progression = {
    enabled = true,
    levels  = { 0, 100, 250, 500, 900, 1400, 2000, 2800, 3800, 5000 },   -- XP-Schwellen für Stufe 1-10
    xp = {
        kill    = { deer = 20, boar = 25, coyote = 15, rabbit = 8 },
        perfect = 15,   -- Bonus für sauberen Kopf-/Halsschuss
        butcher = 5,
        tracked = 15,   -- Erfolgreiche Nachsuche (eigenes verendetes Tier ausgenommen)
        tan     = 5,
        cook    = 1,
    },
    perks = {
        butcherSpeed    = 0.04, -- -4 % Ausnehm-Zeit pro Stufe
        maxButcherSpeed = 0.35,
        meatChance      = 5,    -- +5 % Chance pro Stufe auf 1 zusätzliches Fleisch
        stealth         = 0.02, -- -2 % Wahrnehmungsradius pro Stufe
        maxStealth      = 0.2,
    },
}

--[[ =====================================================================
    AUSNEHMEN
===================================================================== ]]
Config.Butchering = {
    distance     = 2.2,
    trophyChance = 250,     -- Tierkopf-Trophäe: Chance 1 zu 250
    knifeWeapons = { 'WEAPON_KNIFE', 'WEAPON_SWITCHBLADE', 'WEAPON_DAGGER', 'WEAPON_MACHETE' },
    knifeItems   = {},      -- Zusätzliche Item-Messer, z.B. { 'hunting_knife' }
    knifeProp    = 'prop_cs_bowie_knife',
    anim         = { dict = 'amb@medic@standing@kneel@base', name = 'base' },
    upperAnim    = { dict = 'anim@gangops@facility@servers@bodysearch@', name = 'player_search' },
}

--[[ =====================================================================
    GERBEN
    Rohe Felle werden in einen Gerbrahmen gespannt und sind nach Ablauf
    der Zeit (Echtzeit, läuft auch offline weiter) abholbereit.
===================================================================== ]]
Config.Tanning = {
    maxPerPlayer = 4,           -- Gleichzeitig gespannte Felle pro Spieler (alle Rahmen)
    placeTime    = 8,           -- Sekunden: Fell aufspannen
    collectTime  = 4,           -- Sekunden: Leder abnehmen
    requiredItem = nil,         -- z.B. { name = 'salt', count = 1 } (wird pro Fell verbraucht)
    blip = { enabled = true, sprite = 141, colour = 47, scale = 0.7 },

    recipes = {
        pelt_deer   = { result = 'leather_deer',   amount = 1, duration = 600 },
        pelt_boar   = { result = 'leather_boar',   amount = 1, duration = 600 },
        pelt_coyote = { result = 'leather_coyote', amount = 1, duration = 480 },
        pelt_rabbit = { result = 'leather_rabbit', amount = 1, duration = 300 },
    },

    racks = {
        {
            id     = 'paleto_lodge_1',
            label  = 'Gerbrahmen – Jagdhütte Paleto',
            coords = vector4(-764.6, 5591.8, 33.5, 115.0),
            model  = 'prop_tool_bench02',    -- false = kein Prop spawnen (z.B. bei eigenem MLO)
            slots  = 2,
        },
        {
            id     = 'paleto_lodge_2',
            label  = 'Gerbrahmen – Jagdhütte Paleto',
            coords = vector4(-763.4, 5596.2, 33.5, 115.0),
            model  = 'prop_tool_bench02',
            slots  = 2,
        },
    },
}

--[[ =====================================================================
    GRILLEN
    Jeder Grill der Spielwelt (Modelle unten), feste Feuerstellen und
    selbst gebaute Lagerfeuer können zum Grillen genutzt werden.
===================================================================== ]]
Config.Cooking = {
    distance    = 2.2,
    maxBatch    = 10,           -- Maximal so viele Stücke in einem Durchgang
    grillModels = {
        'prop_bbq_1', 'prop_bbq_2', 'prop_bbq_3', 'prop_bbq_4', 'prop_bbq_5',
        'prop_beach_bbq', 'prop_hobo_stove_01',
    },
    scenario = 'PROP_HUMAN_BBQ',

    recipes = {
        meat_deer   = { result = 'cooked_deer',   duration = 10 },
        meat_boar   = { result = 'cooked_boar',   duration = 12 },
        meat_coyote = { result = 'cooked_coyote', duration = 10 },
        meat_rabbit = { result = 'cooked_rabbit', duration = 8 },
    },

    -- Feste Feuerstellen (brennen dauerhaft)
    stations = {
        { label = 'Feuerstelle – Jagdhütte Paleto', coords = vector3(-773.2, 5590.2, 33.5) },
    },
}

Config.Campfire = {
    item             = 'campfire_kit',
    model            = 'prop_beach_fire',
    particle         = { asset = 'core', name = 'ent_amb_beach_campfire', scale = 0.8 },  -- false = kein Effekt
    lifetime         = 900,     -- Sekunden Brenndauer
    placeTime        = 6,
    maxPerPlayer     = 1,
    allowInInteriors = false,
    renderDistance   = 120.0,
}

--[[ =====================================================================
    ESSEN
===================================================================== ]]
Config.Eating = {
    statusEvent = 'esx_status:add',     -- esx_status / esx_basicneeds
    cooked = {
        cooked_deer   = { hunger = 400000, heal = 10 },
        cooked_boar   = { hunger = 450000, heal = 10 },
        cooked_coyote = { hunger = 250000, heal = 5 },
        cooked_rabbit = { hunger = 200000, heal = 5 },
    },
    raw = {
        enabled    = true,      -- Rohes Fleisch essbar (mit Risiko)
        hunger     = 80000,
        sickChance = 65,        -- % Chance, dass einem schlecht wird
        damage     = 20,
    },
    anim = {
        dict     = 'mp_player_inteat@burger',
        name     = 'mp_player_int_eat_burger',
        duration = 5000,
        prop     = 'prop_cs_steak',
    },
}

--[[ =====================================================================
    TROPHÄEN (TIERKÖPFE) ALS DEKO
    GTA V enthält keine Tierkopf-Props. Tragt den Modellnamen eines
    gestreamten Custom-Props unter "prop" ein. Ist kein (gültiges) Prop
    vorhanden, wird ersatzweise das ganze Tier als Präparat aufgestellt.
===================================================================== ]]
Config.Trophies = {
    maxPerPlayer   = 10,
    placeDistance  = 4.0,
    renderDistance = 60.0,
    items = {
        trophy_deer   = { prop = nil, fallbackPed = 'a_c_deer',   wallOffset = 0.05, headingOffset = 0.0 },
        trophy_boar   = { prop = nil, fallbackPed = 'a_c_boar',   wallOffset = 0.05, headingOffset = 0.0 },
        trophy_coyote = { prop = nil, fallbackPed = 'a_c_coyote', wallOffset = 0.05, headingOffset = 0.0 },
    },
}

--[[ =====================================================================
    HÄNDLER
    prices  : Ankauf von Fleisch, Fellen, Leder und Trophäen
    shop    : Verkauf von Jagdausrüstung
    license : true = Jagdschein (builtin) kann hier gekauft/verlängert werden
===================================================================== ]]
Config.Traders = {
    {
        label   = 'Wildhändler Paleto',
        ped     = 's_m_m_ammucountry',
        coords  = vector4(-769.2, 5595.6, 33.5, 200.0),
        account = 'money',
        license = true,
        blip    = { enabled = true, sprite = 141, colour = 21, scale = 0.8 },
        shop    = {
            { item = 'campfire_kit',  price = 150 },
            { item = 'bait_corn',     price = 90 },
            { item = 'bait_saltlick', price = 140 },
            { item = 'hunting_blind', price = 950 },
            { item = 'binoculars',    price = 450 },
        },
        prices  = {
            meat_deer = 35, meat_boar = 30, meat_coyote = 15, meat_rabbit = 12,
            pelt_deer = 90, pelt_boar = 70, pelt_coyote = 60, pelt_rabbit = 25,
            leather_deer = 240, leather_boar = 190, leather_coyote = 160, leather_rabbit = 70,
            trophy_deer = 3500, trophy_boar = 3000, trophy_coyote = 2500,
        },
    },
    {
        label   = 'Raven Schlachthof',
        ped     = 's_m_y_factory_01',
        coords  = vector4(969.2, -2107.9, 31.5, 90.0),
        account = 'money',
        blip    = { enabled = true, sprite = 141, colour = 21, scale = 0.8 },
        prices  = {
            meat_deer = 42, meat_boar = 38, meat_coyote = 18, meat_rabbit = 15,
        },
    },
}
