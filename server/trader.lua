--[[
    Händler: Ankauf von Beute, Verkauf von Ausrüstung und Jagdscheinen.
]]

local function GetTrader(index)
    return Config.Traders[tonumber(index) or -1]
end

local function IsNearTrader(src, trader)
    return IsPlayerNear(src, trader.coords.xyz, 5.0)
end

local function FindShopEntry(trader, item)
    for _, entry in ipairs(trader.shop or {}) do
        if entry.item == item then return entry end
    end
    return nil
end

--[[ Übersicht für das Händler-Menü ]]

ESX.RegisterServerCallback('wr_hunting:trader:getInfo', function(src, cb, index)
    local trader = GetTrader(index)
    if not trader or not IsNearTrader(src, trader) then return cb(false) end

    local info = { sells = trader.prices ~= nil and next(trader.prices) ~= nil, shop = {}, license = nil }
    for _, entry in ipairs(trader.shop or {}) do
        info.shop[#info.shop + 1] = { item = entry.item, label = Inventory.Label(entry.item), price = entry.price }
    end
    if trader.license and Config.License.enabled and Config.License.provider == 'builtin' then
        local valid, untilTs = GetLicenseStatus(src)
        info.license = {
            status = FormatLicense(valid, untilTs),
            valid  = valid,
            price  = Config.License.price,
            days   = Config.License.durationDays,
        }
    end
    cb(true, info)
end)

--[[ Ankauf ]]

ESX.RegisterServerCallback('wr_hunting:trader:getOffers', function(src, cb, index)
    local trader = GetTrader(index)
    if not trader or not trader.prices or not IsNearTrader(src, trader) then return cb(false) end

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
    if not trader or not trader.prices or amount < 1 then return cb(false, L('trader_error')) end
    if not IsNearTrader(src, trader) then return cb(false, L('too_far')) end
    if RateLimited(src, 'traderSell', 750) then return cb(false, L('trader_error')) end

    local price = trader.prices[item]
    if not price then return cb(false, L('trader_error')) end
    if Inventory.Count(src, item) < amount then return cb(false, L('trader_not_enough')) end
    if not Inventory.Remove(src, item, amount) then return cb(false, L('trader_not_enough')) end

    local total = price * amount
    Inventory.AddMoney(src, trader.account or 'money', total)
    cb(true, L('trader_sold', amount, Inventory.Label(item), total))
end)

--[[ Ausrüstung ]]

ESX.RegisterServerCallback('wr_hunting:trader:buy', function(src, cb, index, item, amount)
    local trader = GetTrader(index)
    amount = math.floor(tonumber(amount) or 1)
    if not trader or amount < 1 or amount > 10 then return cb(false, L('trader_error')) end
    if not IsNearTrader(src, trader) then return cb(false, L('too_far')) end
    if RateLimited(src, 'traderBuy', 750) then return cb(false, L('trader_error')) end

    local entry = FindShopEntry(trader, item)
    if not entry then return cb(false, L('trader_error')) end
    if not Inventory.CanCarry(src, item, amount) then return cb(false, L('inventory_full')) end

    local total = entry.price * amount
    if not Inventory.RemoveMoney(src, trader.account or 'money', total) then
        return cb(false, L('not_enough_money', total))
    end
    if not Inventory.Add(src, item, amount) then
        Inventory.AddMoney(src, trader.account or 'money', total)
        return cb(false, L('inventory_full'))
    end
    cb(true, L('trader_bought', amount, Inventory.Label(item), total))
end)

--[[ Jagdschein ]]

ESX.RegisterServerCallback('wr_hunting:trader:buyLicense', function(src, cb, index)
    local trader = GetTrader(index)
    if not trader or not trader.license then return cb(false, L('license_not_available')) end
    if not IsNearTrader(src, trader) then return cb(false, L('too_far')) end
    if RateLimited(src, 'buyLicense', 2000) then return cb(false, L('trader_error')) end
    cb(BuyLicense(src))
end)
