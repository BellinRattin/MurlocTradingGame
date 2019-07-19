local AddonName, Addon = ...

local string = string
local strsplit = strsplit
local tonumber = tonumber
local UnitGUID = UnitGUID
local GetItemInfo = GetItemInfo

Addon.Frames = {}
Addon.Functions = {}
Addon.Util = {}

Addon.Events = CreateFrame("Frame")
Addon.Events:SetScript("OnEvent", function(self, event, ...)
	if not self[event] then
		return
	end
	self[event](self, ...)
end)

-- Given an itemLink it returns the relative itemString
function Addon.Util.GetItemStringFromItemLink(itemLink)
	local itemString = string.match(itemLink, "item[(%-?%d):]+")
	return itemString
end


-- local itemID = string.match(text, "item:(%d+):")
-- Given an itemLink it returns the relative itemID as a number
function Addon.Util.GetItemIdFromItemLink(itemLink)
	--local itemID = string.find(itemLink, "item:(%d+):")
	local _, _, _, _, Id = string.find(itemLink, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*):?(%d*):?(%-?%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?")
	return tonumber(Id)
end

-- return the id of the targeted npc
function Addon.Util.GetNPCId()
	local guid = UnitGUID("target")
	local _, _, _, _, _, npc_id= strsplit("-",guid)
	return tonumber(npc_id)
end

function Addon.Util.GetItemLinkFromId(itemID)
	_, itemLink = GetItemInfo(itemID)
	return itemLink
end