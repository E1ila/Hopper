

local function print(text)
    DEFAULT_CHAT_FRAME:AddMessage(text)
end

------------------------------------------------

function Hopper_OnLoad(self)
	realmName = GetRealmName()
	faction = UnitFactionGroup("player")
	playerName = UnitName("player")

	SLASH_Hopper1 = "/hop"
    SlashCmdList["Hopper"] = Hopper_Main

	print("|cFFFF8080 Hopper |rLoaded, write |cFF00FF00/ahdump help|r for options")

	-- this:RegisterEvent("PLAYER_TARGET_CHANGED")
	self:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
end 

function Hopper_OnEvent(event, arg1)
	-- print("|cFFFF8080 Hopper |r  Hopper_OnEvent  "..event)
	if (event == "AUCTION_ITEM_LIST_UPDATE") then
	end
end

function Hopper_OnUpdate(self)
end 

function Hopper_Main(msg) 
	local _, _, cmd, arg1 = string.find(string.upper(msg), "([%w]+)%s*(.*)$");
	if not cmd then
	elseif  "R" == cmd or "RESET" == cmd then
    elseif  "H" == cmd or "HELP" == cmd then
        print("|cFFFF8080 Hopper |rCommands: ")
        print("|cFFFF8080 Hopper |r  |cFF00FF00/ahdump|r - scan AH")
        print("|cFFFF8080 Hopper |r  |cFF00FF00/ahdump c <CLASS_INDEX>|r - scan only class index")
	end
end 

