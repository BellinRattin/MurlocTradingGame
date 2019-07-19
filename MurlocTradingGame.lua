local addonName, Addon = ...

Addon.Events:RegisterEvent("MERCHANT_SHOW")
Addon.Events:RegisterEvent("ADDON_LOADED")
Addon.Events:RegisterEvent("PLAYER_ENTERING_WORLD")

-- UI things --
local StdUi = LibStub("StdUi")

local window = StdUi:Window(UIParent, "Murloc Trading Game", 350, 75)
window:SetPoint('CENTER')

local fontString = StdUi:FontString(window, "you shouldn't see this, please report it")
StdUi:GlueTop(fontString, window, 0, -45)

window:Hide()
--------------------------------------------------------------------------

-- table <merchant id> = <merchant name (in english at least)>
local merchants_names = {
	[152084] = "Mrrl",
	[151950] = "Mrrglrlr",
	[151951] = "Grrmrlg",
	[151952] = "Flrgrrl",
	[151953] = "Hurlgrl",
	[111111] = "Wash"
}

-- list of item id to do a GetItemInfo on ADDON_LOADED to have them in cache
-- may try some item:ContinueOnItemLoad later on
local items_to_query = {
	-- normal items
	168091,	168092,	168093,	168094,	168095,	168096, 168097,
	-- hidden stock

	-- materials
	167912,	167910,	167911,	167909,	169782,

	167896,	167903,	167902,	167904,	169780,

	167915,	167914,	167916,	167923,	167913,	169783,

	167906,	167905,	167907,	167908,	169781,
}

-- table <item id> = <id of the merchan who sell it>
-- 111111 is wash is some whater
local merchants = {
	[167912] = 151952,
	[167910] = 151952,
	[167911] = 151952,
	[167909] = 151952,
	[169782] = 151952,

	[167896] = 151950,
	[167903] = 151950,
	[167902] = 151950,
	[167904] = 151950,
	[169780] = 151950,

	[167915] = 151953,
	[167914] = 151953,
	[167916] = 151953,
	----------------------------------------
	[167923] = 111111,
	----------------------------------------
	[167913] = 151953,
	[169783] = 151953,

	[167906] = 151951,
	[167905] = 151951,
	[167907] = 151951,
	[167908] = 151951,
	[169781] = 151951,
}

-- table <item id> = <table of prices>
-- table of prices {<currency id>,<amount>}
local prices = {
	[167912] = {{"gold", 1}},
	[167910] = {{167906, 2}},
	[167911] = {{167915, 4}},
	[167909] = {{167905, 6}},
	[169782] = {{167904, 2}, {167902, 9}},

	[167896] = {{"gold", 1}},
	[167903] = {{167915, 4}},
	[167902] = {{167910, 3},{167914, 3}},
	[167904] = {{167911, 2}},
	[169780] = {{167908, 8},{167913, 7}},

	[167915] = {{"gold", 1}},
	[167914] = {{167906, 5}},
	[167916] = {{167912, 6}},
	----------------------------------------
	[167923] = {{167916, 1}},
	----------------------------------------
	[167913] = {{167905, 5}},
	[169783] = {{167904, 4},{167909, 7}},

	[167906] = {{"gold", 1}},
	[167905] = {{167896, 3}},
	[167907] = {{167903, 5}},
	[167908] = {{167923, 3}},
	[169781] = {{167913, 8},{167909, 4}},
}

-- table <item id> = <number owned>
local owned = {

}

-- some local values
local PLAYER_FULL_NAME = ""
local clean_socks = 0
local buyNumber = 0

-- list of items to buy in "optimized" order"
local buyList = {}
-- temp list to generate the above one
local tmpList = {
	[1] = {},
	[2] = {},
	[3] = {},
}

-- function to select the buyList active entry and update the helper display
local function UpdateCurrentBuyItem()
	buyNumber = buyNumber + 1

	if buyList[buyNumber].itemID == 167923 then
		clean_socks = 0
		Addon.Events:RegisterEvent("CHAT_MSG_LOOT")
	end

	local instruction = "go to "..merchants_names[buyList[buyNumber].merchant].." and buy "..Addon.Util.GetItemLinkFromId(buyList[buyNumber].itemID).." x "..buyList[buyNumber].quantity
	fontString:SetText(instruction)
end

-- check bags for already owned items
local function GetBagsItems()
	for container = 0, 4 do
		for slot = 1, GetContainerNumSlots(container) do
			local itemId = GetContainerItemID(container, slot)
			if itemId and prices[itemId] then
				owned[itemId] = GetItemCount(itemId, false, false)
			end
		end
	end
end

-- recursive function to calculate all the subitems required to buy something
local function CalculateSubItems(index, item, quantity, deep)

	if item == "gold" then 
	else
		local correct_quantity = quantity

		if owned[item] then
			if owned[item] > quantity then
				correct_quantity = 0
				owned[item] = owned[item] - quantity
			else
				correct_quantity = quantity - owned[item]
				owned[item] = 0
			end
		end

		if correct_quantity > 0 then
			table.insert(tmpList[index], 1, {
			["operation"] = "BUY", 
			["itemID"] = item, 
			["quantity"] = correct_quantity, 
			["deep"] = deep,
			["merchant"] = merchants[item]})
			
			for _, curr in pairs(prices[tonumber(item)]) do
				CalculateSubItems(index, curr[1], curr[2]*quantity, deep+1)
			end
		end
	end
end

--function to create a buy list and "optimize" the route
-- /run print(GetMerchantItemID(1))
-- /run print(GetMerchantItemLink(1))
-- took items from tmpList and put in buyList in the correct order
local function CalculateBuyListAndRoute()
	local itemid = GetMerchantItemID(1)
	local last = {
		["operation"] = "BUY", 
		["itemID"] = itemid,
		["quantity"] = 1, 
		["deep"] = 0,
		["merchant"] = 152084}
	local itemCount = GetMerchantItemCostInfo(1)
	for i = 1, itemCount do
		_, itemValue, itemLink, _ = GetMerchantItemCostItem(1, i)
		CalculateSubItems(i, Addon.Util.GetItemIdFromItemLink(itemLink), itemValue, 1)
	end

	local mem = 0
	local count = #tmpList[1] + #tmpList[2] + #tmpList[3]
	local a,b,c = 1,1,1

	for i = 1, count do
		local bool = false

		if not(tmpList[1][a] == nil) and not bool then
			if tmpList[1][a].merchant == mem then
				table.insert(buyList, tmpList[1][a])
				a = a + 1
				bool = true
			end
		end
		if not(tmpList[2][b] == nil) and not bool then
			if tmpList[2][b].merchant == mem then
				table.insert(buyList, tmpList[2][b])
				b = b + 1
				bool = true
			end
		end
		if not(tmpList[3][c] == nil) and not bool then
			if tmpList[3][c].merchant == mem then
				table.insert(buyList, tmpList[3][c])
				c = c + 1
				bool = true
			end
		end

		if not bool then
			if not(tmpList[1][a] == nil) then
				if not(tmpList[2][b] == nil) then
					if not(tmpList[3][c] == nil) then
						-- 1 2 3 
						if tmpList[1][a][5] == tmpList[2][b][5] then
							table.insert(buyList,  tmpList[1][a])
							mem = tmpList[1][a].merchant
							a = a + 1
						else
							table.insert(wT,  tmpList[3][c])
							mem = tmpList[3][c].merchant
							c = c + 1
						end
					else
						-- 1 2 X
						table.insert(buyList,  tmpList[1][a])
						mem = tmpList[1][a].merchant
						a = a + 1
					end
				else
					table.insert(buyList,  tmpList[1][a])
					mem = tmpList[1][a].merchant
					a = a + 1
				end
			else
				if not(tmpList[2][b] == nil) then
					table.insert(buyList,  tmpList[2][b])
					mem = tmpList[2][b].merchant
					b = b + 1 
				else
					if not(tmpList[3][c] == nil) then
						-- X X 3
						table.insert(buyList,  tmpList[3][c])
						mem = tmpList[3][c].merchant
						c = c + 1
					end
				end
			end
		end
	end
	table.insert(buyList, last)
	UpdateCurrentBuyItem()
end

-- function to buy the need items, 
-- it loops the buy if the quantity exceed the max stack size form the vendor
local function BuyItemLoop(index, amount)
	local quantity = amount
	local stack = GetMerchantItemMaxStack(index)
	while quantity > 0 do
		BuyMerchantItem(index, min(quantity, stack))
		quantity = quantity - min(quantity, stack)
	end
end

-- function to buy items from a merchant
-- it checks if the current merchant is the right one and buy the needed items
local function BuyItemFromMerchant(npc_id)
	if buyList[buyNumber] then
		local item = buyList[buyNumber]
		if npc_id == item.merchant then
			for itemIndex = 1, GetMerchantNumItems() do
				local itemId = GetMerchantItemID(itemIndex)
				if itemId == item.itemID then
					BuyItemLoop(itemIndex, item.quantity)
					UpdateCurrentBuyItem()
				end
			end
			BuyItemFromMerchant(npc_id)
		else
		end
	end
end

-- check which merchant is open and act accordingly
local m_visited = false
function Addon.Events:MERCHANT_SHOW()
	local npc_id = Addon.Util.GetNPCId()
	if npc_id == 152084 then
		if not m_visited then
			m_visited = true
			window:Show()
			CalculateBuyListAndRoute() -- Calculate Passages
		else
			--check if all items are there
			BuyMerchantItem(1, 1)
			fontString:SetText("DONZO")
		end
	else
		if (npc_id == 151950) or (npc_id == 151951) or (npc_id == 151952) or (npc_id == 151953) then
			BuyItemFromMerchant(npc_id)
		end
	end
end


function Addon.Events:PLAYER_ENTERING_WORLD()
	local n, s = UnitFullName("player")
	PLAYER_FULL_NAME = n.."-"..s
end

-- some query when the addon is first loaded
function Addon.Events:ADDON_LOADED(name)
	if name == addonName then
		for i = 1, #items_to_query do
			GetItemInfo(items_to_query[i])
		end

		GetBagsItems()
	end
end


-- check loot messages for Clean Murloc Socks (and only that)
-- it is active only when clean socks are the currrent needed item
function Addon.Events:CHAT_MSG_LOOT(...)
	local text, unit = ...

	if unit  == PLAYER_FULL_NAME then
		local itemID = Addon.Util.GetItemIdFromItemLink(text)

		if itemID == 167923 then
			clean_socks = clean_socks + 1
		end
		if clean_socks == buyList[buyNumber].quantity then
			Addon.Events:UnregisterEvent("CHAT_MSG_LOOT")
			UpdateCurrentBuyItem()
		end
	end
end

