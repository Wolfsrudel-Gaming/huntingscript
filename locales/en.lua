Locales = Locales or {}

Locales['en'] = {
    -- General
    progress_cancel        = '[X] Cancel',
    too_far                = 'You are too far away.',
    inventory_full         = 'You do not have enough inventory space.',
    duration_minutes       = '%d min',
    duration_seconds       = '%d sec',

    -- Zones
    zone_enter             = 'You are entering %s. Good hunting!',
    zone_leave             = 'You are leaving %s. Hunting weapons outside of hunting grounds will be reported.',

    -- Kill & quality
    kill_confirmed         = '%s killed – %s',
    quality_perfect        = 'clean shot, perfect quality',
    quality_good           = 'good quality',
    quality_damaged        = 'damaged',
    quality_ruined         = 'almost unusable',

    -- Butchering
    butcher_prompt         = '~INPUT_PICKUP~ Skin %s',
    butcher_progress       = 'Skinning %s',
    butcher_cancelled      = 'Skinning cancelled.',
    butcher_failed         = 'Skinning failed.',
    butcher_too_fast       = 'You were too fast – take your time.',
    butcher_success        = 'Received: %s',
    butcher_nothing        = 'Nothing usable was left of the animal.',
    carcass_invalid        = 'This carcass cannot be skinned.',
    carcass_busy           = 'Someone is already skinning this animal.',
    need_knife             = 'You need a knife to skin the animal.',
    pelt_ruined            = 'The pelt was ruined by the shot.',
    trophy_found           = 'Incredible! The head is perfectly intact – a rare trophy (%s)!',

    -- Tanning
    tanning_blip           = 'Tannery',
    tanning_prompt         = '~INPUT_PICKUP~ Use tanning rack',
    tanning_slot_free      = 'Rack %d: free',
    tanning_slot_free_desc = 'Stretch a raw pelt',
    tanning_slot_ready     = 'Rack %d: %s – ready!',
    tanning_slot_ready_desc= 'Take the tanned pelt',
    tanning_slot_busy_own  = 'Rack %d: %s',
    tanning_slot_busy      = 'Rack %d: occupied',
    tanning_slot_busy_desc = 'Someone else is tanning here',
    tanning_remaining      = '%s remaining',
    tanning_duration       = 'Tanning time: %s',
    tanning_choose_pelt    = 'Choose a pelt',
    tanning_no_pelts       = 'You have no raw pelts.',
    tanning_placing        = 'Stretching pelt',
    tanning_collecting     = 'Taking tanned pelt',
    tanning_started        = '%s has been stretched. Ready in %s.',
    tanning_collected      = 'You received %dx %s.',
    tanning_slot_taken     = 'This rack is already occupied.',
    tanning_limit          = 'You can tan at most %d pelts at the same time.',
    tanning_need_item      = 'You need %dx %s for tanning.',
    tanning_not_ready      = 'The pelt is not tanned yet.',
    tanning_not_yours      = 'This is not your pelt.',
    tanning_error          = 'The tanning rack cannot be used right now.',

    -- Cooking
    cook_prompt_grill      = '~INPUT_PICKUP~ Grill',
    cook_prompt_fire       = '~INPUT_PICKUP~ Cook over the fire',
    cook_title_grill       = 'Grill',
    cook_title_fire        = 'Campfire',
    cook_one               = 'Grill 1x %s',
    cook_all               = 'Grill %dx %s',
    cook_desc              = 'Makes %s – %d sec per piece',
    cook_progress          = 'Grilling meat (%d/%d)',
    cook_done              = 'You grilled %d pieces of meat.',
    cook_cancelled         = 'Grilling cancelled.',
    cook_no_meat           = 'You have no raw meat.',
    cook_too_fast          = 'The meat is not done yet.',
    cook_error             = 'Grilling is not possible.',

    -- Campfire
    campfire_placing       = 'Building campfire',
    campfire_placed        = 'The campfire will burn for about %d minutes.',
    campfire_invalid       = 'You cannot build a campfire here.',
    campfire_indoors       = 'You cannot build a campfire indoors.',
    campfire_too_close     = 'There is already a fire here.',
    campfire_limit         = 'You can have at most %d campfires at once.',
    campfire_no_item       = 'You do not have a campfire kit.',
    campfire_extinguish    = 'Extinguish campfire',
    campfire_extinguished  = 'The campfire has been extinguished.',

    -- Eating
    eat_done               = 'You ate %s.',
    eat_raw_lucky          = 'Raw … but it stayed down.',
    eat_raw_sick           = 'You feel sick – raw meat was not a good idea.',

    -- Trophies
    trophy_place_help      = '~INPUT_PICKUP~ Place~n~~INPUT_CELLPHONE_CANCEL~ Cancel~n~Mouse wheel / ~INPUT_CELLPHONE_LEFT~ ~INPUT_CELLPHONE_RIGHT~ Rotate~n~~INPUT_CELLPHONE_UP~ ~INPUT_CELLPHONE_DOWN~ Height',
    trophy_place_cancelled = 'Placement cancelled.',
    trophy_placed          = 'Trophy placed.',
    trophy_removed         = 'Trophy taken down.',
    trophy_removed_admin   = 'Trophy removed.',
    trophy_pickup_prompt   = '~INPUT_PICKUP~ Take down trophy',
    trophy_limit           = 'You can place at most %d trophies.',
    trophy_no_item         = 'You do not have this trophy.',
    trophy_not_yours       = 'This is not your trophy.',
    trophy_none_nearby     = 'No trophy nearby.',
    trophy_model_missing   = 'The trophy model could not be loaded.',
    trophy_error           = 'The trophy could not be saved.',

    -- Trader
    trader_prompt          = '~INPUT_PICKUP~ Trade with %s',
    trader_price           = '$%d each – total $%d',
    trader_nothing         = 'You have nothing I am interested in.',
    trader_sold            = 'You sold %dx %s for $%d.',
    trader_not_enough      = 'You do not have enough of that.',
    trader_error           = 'The trade failed.',

    -- Police
    dispatch_sender        = 'Dispatch',
    gender_male            = 'male',
    gender_female          = 'female',
    alert_kill_code        = '10-94',
    alert_kill_title       = 'Suspected poaching',
    alert_kill_message     = 'Residents report gunshots and a %s person next to a killed animal.',
    alert_weapon_code      = '10-32',
    alert_weapon_title     = 'Person with hunting weapon',
    alert_weapon_message   = 'A %s person with a hunting weapon was spotted outside of hunting grounds.',

    -- Admin
    admin_invalid_type     = 'Unknown animal type. Available: %s',
    admin_cleared          = 'Removed %d hunting animals.',
}
