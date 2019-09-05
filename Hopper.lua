

local function print(text)
    DEFAULT_CHAT_FRAME:AddMessage(text)
end

local function emptyIfNil(text) 
	if text == nil then return "" end 
	return text
end 

------------------------------------------------

function Hopper_OnLoad(self)
	gRealmName = GetRealmName()
	gFaction = UnitFactionGroup("player")
	gPlayerName = UnitName("player")

	SLASH_Hopper1 = "/hop"
    SlashCmdList["Hopper"] = Hopper_Main

	print("|cFFFF8080 Hopper |rLoaded, write |cFF00FF00/hop help|r for options")

	self:RegisterEvent("CHAT_MSG_ADDON")
end 

function Hopper_OnEvent(event, arg1, arg2, arg3, arg4)
	-- print("|cFFFF8080 Hopper |r  Hopper_OnEvent  "..event)
	if (event == "CHAT_MSG_ADDON") then
		print("|cFFFF8080 Hopper |r Incoming Message: ["..emptyIfNil(arg1).."] ["..emptyIfNil(arg2).."] ["..emptyIfNil(arg3).."] ["..emptyIfNil(arg4).."]")
	end
end

function Hopper_OnUpdate(self)
end 

function Hopper_Main(msg) 
	local _, _, cmd, arg1 = string.find(string.upper(msg), "([%w]+)%s*(.*)$");
	if not cmd then
	elseif  "S" == cmd or "SEND" == cmd then
		SendAddonMessage("manual", arg1, "PARTY")
	elseif  "R" == cmd or "RESET" == cmd then
    elseif  "H" == cmd or "HELP" == cmd then
        print("|cFFFF8080 Hopper |rCommands: ")
        print("|cFFFF8080 Hopper |r  |cFF00FF00/ahdump|r - scan AH")
        print("|cFFFF8080 Hopper |r  |cFF00FF00/ahdump c <CLASS_INDEX>|r - scan only class index")
	end
end 

