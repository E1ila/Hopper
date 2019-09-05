
local ADDON_PREFIX = "ZE2okI8Vx5H72L"

local function print(text)
    DEFAULT_CHAT_FRAME:AddMessage(text)
end

local function p(text)
	print("|cFFFF8080Hopper |r".. text)
end 

local function pe(text)
	p("|cFFFF0000".. text .."|r")
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

	p("Loaded, write |cFF00FF00/hop help|r for options")

	self:RegisterEvent("CHAT_MSG_ADDON")

	successfulRequest = C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
	if not successfulRequest then 
		pe("Failed registering to message prefix!")
	end 
end 

function Hopper_OnEvent(event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
	if (event == "CHAT_MSG_ADDON") then
		p("Incoming Message: ["..emptyIfNil(arg1).."] ["..emptyIfNil(arg2).."] ["..emptyIfNil(arg3).."] ["..emptyIfNil(arg4).."] ["..emptyIfNil(arg5).."] ["..emptyIfNil(arg6).."] ["..emptyIfNil(arg7).."] ["..emptyIfNil(arg8).."] ["..emptyIfNil(arg9).."]")
	end
end

function Hopper_OnUpdate(self)
end 

function Hopper_Main(msg) 
	local _, _, cmd, arg1 = string.find(string.upper(msg), "([%w]+)%s*(.*)$");
	if not cmd then
	elseif  "S" == cmd or "SEND" == cmd then
		C_ChatInfo.SendAddonMessage(ADDON_PREFIX, arg1, "PARTY")
	elseif  "R" == cmd or "RESET" == cmd then
    elseif  "H" == cmd or "HELP" == cmd then
        p("Commands: ")
        p(" |cFF00FF00/ahdump|r - scan AH")
        p(" |cFF00FF00/ahdump c <CLASS_INDEX>|r - scan only class index")
	end
end 

