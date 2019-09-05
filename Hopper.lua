
ENABLED = true
PARTYADD = true
AUTOLEAVE = false 

local MSG_INVITE = "inv"
local ADDON_PREFIX = "ZE2okI8Vx5H72L"
local SCOPE = "GUILD"
local HOP_REQUEST_TIMEOUT = 10
local HOP_REQUEST_COOLDOWN = 10
local AUTO_LEAVE_DELAY = 1
local gPlayerName = nil 
local gRealmName = nil 
local gRealmPlayerName = nil 
local gHopRequested = 0
local gShouldAutoLeave = 0

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
	gRealmPlayerName = gPlayerName.."-"..gRealmName:gsub("%s+", "")

	SLASH_Hopper1 = "/hop"
    SlashCmdList["Hopper"] = Hopper_Main

	p("Loaded, write |cFFFFFF00/hop|r to change layer, |cFFFFFF00/hop h|r for help.")
	Hopper_PrintStatus()

	self:SetScript("OnEvent", Hopper_OnEvent)
	self:SetScript("OnUpdate", Hopper_OnUpdate)
	self:RegisterEvent("CHAT_MSG_ADDON")
	self:RegisterEvent("PARTY_INVITE_REQUEST")

	successfulRequest = C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
	if not successfulRequest then 
		pe("Failed registering to message prefix!")
	end 
end 

function Hopper_OnEvent(self, event, prefix, message, distribution, sender)
	local partySize = GetNumGroupMembers()

	if (ENABLED and event == "CHAT_MSG_ADDON") then
		p("requested "..message.." from "..sender.." my name "..gPlayerName.." / "..gRealmPlayerName)
		local isLeader = partySize > 0 and UnitIsGroupLeader(gPlayerName)
		if message == MSG_INVITE and (sender ~= gPlayerName and sender ~= gRealmPlayerName) and (partySize == 0 or isLeader and PARTYADD) then
			InviteUnit(sender)
		end 
	end

	if (ENABLED and event == "PARTY_INVITE_REQUEST" and partySize == 0 and time() - gHopRequested <= HOP_REQUEST_TIMEOUT) then 
		AcceptGroup()
		gShouldAutoLeave = time()
		for i=1, STATICPOPUP_NUMDIALOGS do
			if _G["StaticPopup"..i].which == "PARTY_INVITE" then
				_G["StaticPopup"..i].inviteAccepted = 1
				StaticPopup_Hide("PARTY_INVITE");
				break
			elseif _G["StaticPopup"..i].which == "PARTY_INVITE_XREALM" then
				_G["StaticPopup"..i].inviteAccepted = 1
				StaticPopup_Hide("PARTY_INVITE_XREALM");
				break
			end
		end
	end 
end

function Hopper_OnUpdate(self)
	if time() - gShouldAutoLeave >= AUTO_LEAVE_DELAY then 
		gShouldAutoLeave = 0
		LeaveParty()
	end 
end 

function Hopper_PrintStatus()
	if ENABLED then 
		p("Auto invite |cff11ff11enabled|r, write |cFFFFFF00/hop d|r to disable.")
	else 
		p("Auto invite |cffff1111disabled|r, write |cFFFFFF00/hop e|r to enable.")
	end 
end 

function Hopper_RequestHop()
	local partySize = GetNumGroupMembers()
	if partySize == 0 or AUTOLEAVE then 
		if partySize > 0 then
			LeaveParty()
		end 
		gHopRequested = time()
		C_ChatInfo.SendAddonMessage(ADDON_PREFIX, MSG_INVITE, SCOPE)
	else 
		pe("Can't hop while in a party, leave it first.")
	end 
end 

function Hopper_Main(msg) 
	local _, _, cmd, arg1 = string.find(string.upper(msg), "([%w]+)%s*(.*)$");
	if not cmd then
		Hopper_RequestHop()
	elseif  "D" == cmd or "DISABLE" == cmd then
		ENABLED = false
		Hopper_PrintStatus()
	elseif  "E" == cmd or "ENABLE" == cmd then
		ENABLED = true 
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
	elseif  "L" == cmd or "AUTOLEAVE" == cmd then
		AUTOLEAVE = not AUTOLEAVE
		if AUTOLEAVE then 
			p("Auto Leave Party |cff11ff11enabled|r. Will leave if in a party when /hop is used.")
		else 
			p("Auto Leave Party |cffff1111disabled|r. Will ignore /hop command if in a party.")
		end 
    elseif  "H" == cmd or "HELP" == cmd then
        p("Commands: ")
        p(" |cFFFFFF00/hop|r - change layer")
        p(" |cFFFFFF00/hop e|r - enable auto invite of guild members")
        p(" |cFFFFFF00/hop d|r - disable auto invite")
        p(" |cFFFFFF00/hop p|r - enable/disable adding auto inviting members to existing party")
	end
end 
