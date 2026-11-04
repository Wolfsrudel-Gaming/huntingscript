--[[
    Händler: Verkauf von Fleisch, Fellen, Leder und Trophäen.
]]

local function GetTrader(index)
    return Config.Traders[tonumber(index) or -1]
end

ESX.RegisterServerCallback('wr_hunting:trader:getOffers', function(src, cb, index)
    local trader = GetTrader(index)
    if not trader or not IsPlayerNear(src, trader.coords.xyz, 5.0) then return cb(false) end

    local offers = {}
    for item, price in pairs(trader.prices) do
        local count = Inventory.Count(src, item)
        if count > 0 then
            offers[#offers + 1] = { item = item, label = Inventory.Label(item), count = count, price = price }
        end
    end
    table.sort(offers, function(a, b) return a.label < b.label end)
    cb(true, offers)
end)

ESX.RegisterServerCallback('wr_hunting:trader:sell', function(src, cb, index, item, amount)
    local trader = GetTrader(index)
    amount = math.floor(tonumber(amount) or 0)
    if not trader or amount < 1 then return cb(false, L('trader_error')) end
    if not IsPlayerNear(src, trader.coords.xyz, 5.0) then return cb(false, L('too_far')) end
    if RateLimited(src, 'traderSell', 750) then return cb(false, L('trader_error')) end

    local price = trader.prices[item]
    if not price then return cb(false, L('trader_error')) end
    if Inventory.Count(src, item) < amount then return cb(false, L('trader_not_enough')) end
    if not Inventory.Remove(src, item, amount) then return cb(false, L('trader_not_enough')) end

    local total = price * amount
    Inventory.AddMoney(src, trader.account or 'money', total)
    cb(true, L('trader_sold', amount, Inventory.Label(item), total))
end)
