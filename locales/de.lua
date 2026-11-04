Locales = Locales or {}

Locales['de'] = {
    -- Allgemein
    progress_cancel        = '[X] Abbrechen',
    too_far                = 'Du bist zu weit entfernt.',
    inventory_full         = 'Du hast nicht genug Platz im Inventar.',
    duration_minutes       = '%d Min.',
    duration_seconds       = '%d Sek.',

    -- Reviere
    zone_enter             = 'Du betrittst das %s. Waidmannsheil!',
    zone_leave             = 'Du verlässt das %s. Jagdwaffen außerhalb der Reviere werden gemeldet.',

    -- Abschuss & Qualität
    kill_confirmed         = '%s erlegt – %s',
    quality_perfect        = 'sauberer Blattschuss, perfekte Qualität',
    quality_good           = 'gute Qualität',
    quality_damaged        = 'Beute beschädigt',
    quality_ruined         = 'Beute nahezu unbrauchbar',

    -- Ausnehmen
    butcher_prompt         = '~INPUT_PICKUP~ %s ausnehmen',
    butcher_progress       = '%s wird ausgenommen',
    butcher_cancelled      = 'Ausnehmen abgebrochen.',
    butcher_failed         = 'Das Ausnehmen ist fehlgeschlagen.',
    butcher_too_fast       = 'Du warst zu schnell – nimm dir Zeit.',
    butcher_success        = 'Erhalten: %s',
    butcher_nothing        = 'Von dem Tier war nichts mehr zu gebrauchen.',
    carcass_invalid        = 'Dieser Kadaver kann nicht ausgenommen werden.',
    carcass_busy           = 'Jemand nimmt dieses Tier bereits aus.',
    need_knife             = 'Du brauchst ein Messer, um das Tier auszunehmen.',
    pelt_ruined            = 'Das Fell ist durch den Schuss unbrauchbar geworden.',
    trophy_found           = 'Unglaublich! Der Kopf ist perfekt erhalten – eine seltene Trophäe (%s)!',

    -- Gerben
    tanning_blip           = 'Gerberei',
    tanning_prompt         = '~INPUT_PICKUP~ Gerbrahmen benutzen',
    tanning_slot_free      = 'Rahmen %d: frei',
    tanning_slot_free_desc = 'Ein rohes Fell aufspannen',
    tanning_slot_ready     = 'Rahmen %d: %s – fertig!',
    tanning_slot_ready_desc= 'Gegerbtes Fell abnehmen',
    tanning_slot_busy_own  = 'Rahmen %d: %s',
    tanning_slot_busy      = 'Rahmen %d: belegt',
    tanning_slot_busy_desc = 'Hier gerbt bereits jemand anderes',
    tanning_remaining      = 'Noch %s',
    tanning_duration       = 'Gerbdauer: %s',
    tanning_choose_pelt    = 'Fell auswählen',
    tanning_no_pelts       = 'Du hast keine rohen Felle dabei.',
    tanning_placing        = 'Fell wird aufgespannt',
    tanning_collecting     = 'Gegerbtes Fell wird abgenommen',
    tanning_started        = '%s ist aufgespannt. Fertig in %s.',
    tanning_collected      = 'Du hast %dx %s erhalten.',
    tanning_slot_taken     = 'Dieser Rahmen ist bereits belegt.',
    tanning_limit          = 'Du kannst maximal %d Felle gleichzeitig gerben.',
    tanning_need_item      = 'Du benötigst %dx %s zum Gerben.',
    tanning_not_ready      = 'Das Fell ist noch nicht fertig gegerbt.',
    tanning_not_yours      = 'Das ist nicht dein Fell.',
    tanning_error          = 'Der Gerbrahmen kann gerade nicht benutzt werden.',

    -- Grillen
    cook_prompt_grill      = '~INPUT_PICKUP~ Grillen',
    cook_prompt_fire       = '~INPUT_PICKUP~ Am Feuer braten',
    cook_title_grill       = 'Grill',
    cook_title_fire        = 'Lagerfeuer',
    cook_one               = '1x %s grillen',
    cook_all               = '%dx %s grillen',
    cook_desc              = 'Ergibt %s – %d Sek. pro Stück',
    cook_progress          = 'Fleisch wird gegrillt (%d/%d)',
    cook_done              = 'Du hast %d Stück Fleisch gegrillt.',
    cook_cancelled         = 'Grillen abgebrochen.',
    cook_no_meat           = 'Du hast kein rohes Fleisch dabei.',
    cook_too_fast          = 'Das Fleisch ist noch nicht durch.',
    cook_error             = 'Grillen nicht möglich.',

    -- Lagerfeuer
    campfire_placing       = 'Lagerfeuer wird aufgebaut',
    campfire_placed        = 'Das Lagerfeuer brennt etwa %d Minuten.',
    campfire_invalid       = 'Hier kannst du kein Lagerfeuer aufbauen.',
    campfire_indoors       = 'Drinnen kannst du kein Lagerfeuer machen.',
    campfire_too_close     = 'Hier brennt bereits ein Feuer.',
    campfire_limit         = 'Du kannst maximal %d Lagerfeuer gleichzeitig haben.',
    campfire_no_item       = 'Du hast kein Lagerfeuer-Set.',
    campfire_extinguish    = 'Lagerfeuer löschen',
    campfire_extinguished  = 'Das Lagerfeuer wurde gelöscht.',

    -- Essen
    eat_done               = 'Du hast %s gegessen.',
    eat_raw_lucky          = 'Roh … aber es ist drin geblieben.',
    eat_raw_sick           = 'Dir wird übel – das rohe Fleisch war keine gute Idee.',

    -- Trophäen
    trophy_place_help      = '~INPUT_PICKUP~ Platzieren~n~~INPUT_CELLPHONE_CANCEL~ Abbrechen~n~Mausrad / ~INPUT_CELLPHONE_LEFT~ ~INPUT_CELLPHONE_RIGHT~ Drehen~n~~INPUT_CELLPHONE_UP~ ~INPUT_CELLPHONE_DOWN~ Höhe',
    trophy_place_cancelled = 'Platzieren abgebrochen.',
    trophy_placed          = 'Trophäe aufgehängt.',
    trophy_removed         = 'Trophäe abgenommen.',
    trophy_removed_admin   = 'Trophäe entfernt.',
    trophy_pickup_prompt   = '~INPUT_PICKUP~ Trophäe abnehmen',
    trophy_limit           = 'Du kannst maximal %d Trophäen aufstellen.',
    trophy_no_item         = 'Du hast diese Trophäe nicht.',
    trophy_not_yours       = 'Das ist nicht deine Trophäe.',
    trophy_none_nearby     = 'Keine Trophäe in der Nähe.',
    trophy_model_missing   = 'Das Trophäen-Modell konnte nicht geladen werden.',
    trophy_error           = 'Die Trophäe konnte nicht gespeichert werden.',

    -- Händler
    trader_prompt          = '~INPUT_PICKUP~ Mit %s handeln',
    trader_price           = '$%d pro Stück – gesamt $%d',
    trader_nothing         = 'Du hast nichts, was mich interessiert.',
    trader_sold            = 'Du hast %dx %s für $%d verkauft.',
    trader_not_enough      = 'Du hast nicht genug davon.',
    trader_error           = 'Der Handel ist fehlgeschlagen.',

    -- Polizei
    dispatch_sender        = 'Leitstelle',
    gender_male            = 'männliche Person',
    gender_female          = 'weibliche Person',
    alert_kill_code        = '10-94',
    alert_kill_title       = 'Verdacht auf Wilderei',
    alert_kill_message     = 'Anwohner melden Schüsse und eine %s bei einem erlegten Tier.',
    alert_weapon_code      = '10-32',
    alert_weapon_title     = 'Person mit Jagdwaffe',
    alert_weapon_message   = 'Eine %s mit Jagdwaffe außerhalb eines Jagdreviers gesichtet.',

    -- Admin
    admin_invalid_type     = 'Unbekannte Tierart. Verfügbar: %s',
    admin_cleared          = '%d Jagdtiere entfernt.',
}
