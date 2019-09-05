
ENABLED = true
PARTYADD = true

local ADDON_PREFIX = "ZE2okI8Vx5H72L"
local SCOPE = "GUILD"
local gPlayerName = nil 

local MSG_INVITE = "inv"

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

	p("Loaded, write |cFFFFFF00/hop|r to change layer, |cFFFFFF00/hop h|r for help.")
	Hopper_PrintStatus()

	self:SetScript("OnEvent", Hopper_OnEvent)
	self:RegisterEvent("CHAT_MSG_ADDON")

	successfulRequest = C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
	if not successfulRequest then 
		pe("Failed registering to message prefix!")
	end 
end 

function Hopper_OnEvent(self, event, prefix, message, distribution, sender)
	if (ENABLED and event == "CHAT_MSG_ADDON") then
		local partySize = GetNumGroupMembers()
		local isLeader = partySize > 0 and UnitIsGroupLeader(gPlayerName)
		if message == MSG_INVITE and sender ~= gPlayerName and (partySize == 0 or isLeader and PARTYADD) then
			InviteUnit(sender)
		end 
	end
end

function Hopper_OnUpdate(self)
end 

function Hopper_PrintStatus()
	if ENABLED then 
		p("Auto invite |cff11ff11enabled|r, write |cFFFFFF00/hop d|r to disable.")
	else 
		p("Auto invite |cffff1111disabled|r, write |cFFFFFF00/hop e|r to enable.")
	end 
end 

function Hopper_Main(msg) 
	local _, _, cmd, arg1 = string.find(string.upper(msg), "([%w]+)%s*(.*)$");
	if not cmd then
		C_ChatInfo.SendAddonMessage(ADDON_PREFIX, MSG_INVITE, SCOPE)
	elseif  "D" == cmd or "DISABLE" == cmd then
		ENABLED = false
		Hopper_PrintStatus()
	elseif  "E" == cmd or "ENABLE" == cmd then
		ENABLED = true 
		Hopper_PrintStatus()
	elseif  "P" == cmd or "PARTYADD" == cmd then
		PARTYADD = not PARTYADD
		if PARTYADD then 
			p("Party Add |cff11ff11enabled|r. Will add to party, if leading.")
		else 
			p("Party Add |cffff1111disabled|r. Will not add to party.")
		end 
    elseif  "H" == cmd or "HELP" == cmd then
        p("Commands: ")
        p(" |cFFFFFF00/hop|r - change layer")
        p(" |cFFFFFF00/hop e|r - enable auto invite of guild members")
        p(" |cFFFFFF00/hop d|r - disable auto invite")
	end
end 
