
ENABLED = true
PARTYADD = true
AUTOLEAVE = false 
INVITED = {}
AUTO_LEAVE_DELAY = 1

local VERSION = "1.0.5"
local MSG_INVITE = "inv"
local MSG_COUNT = "count"
local MSG_COUNT_ENABLED = "count-en"
local MSG_COUNT_DISABLED = "count-de"
local ADDON_PREFIX = "ZE2okI8Vx5H72L"
local SCOPE = "GUILD"
local HOPPER_QUERY_TIMEOUT = 10
local HOP_REQUEST_TIMEOUT = 10
local HOP_ACCEPT_TIMEOUT = 60
local HOP_REQUEST_COOLDOWN = 10
local HOP_INVITE_COOLDOWN = 1200 -- wait 20 minutes before inviting someone again
local gPlayerName = nil 
local gRealmName = nil 
local gRealmPlayerName = nil 
local gHopRequestTime = 0
local gHopRequested = false
local gShouldAutoLeave = 0
local gHopInvitationSent = nil
local gHopInvitationTime = 0
local gHopRequestRetry = false
local gHoppers = nil
local gHoppersQuery = nil
local gToPlayer = nil
DEBUG = false

local function print(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF8080Hopper |r".. text)
end 

local function printerr(text)
	print("|cFFFF0000".. text .."|r")
end 

local function debug(text) 
	if DEBUG then 
		print("|cFF999999"..text.."|r")
	end 
end 

local function emptyIfNil(text) 
	if text == nil then return "" end 
	return tostring(text)
end 

local function getRealmName(playerName) 
	return playerName.."-"..gRealmName:gsub("%s+", "")
end 

local function removeRealmName(playerRealmName) 
	local fixedRealmName = gRealmName:gsub("%s+", "")
	if string.match(playerRealmName, fixedRealmName) then 
		return string.gsub(playerRealmName, "-"..fixedRealmName, "") 
	end 
	return playerRealmName
end 

local function splitCsv(text, sep) 
	local result = {}
	for word in string.gmatch(text, '([^,]+)') do 
		table.insert(result, word)
	end 
	return result 
end 

------------------------------------------------

function Hopper_OnLoad(self)
	gRealmName = GetRealmName()
	gFaction = UnitFactionGroup("player")
	gPlayerName = UnitName("player")
	gRealmPlayerName = getRealmName(gPlayerName)

	if not INVITED then INVITED = {} end 

	SLASH_Hopper1 = "/hop"
    SlashCmdList["Hopper"] = Hopper_Main

	print("|cffff4040"..VERSION.."|r loaded, write |cFFFFFF00/hop|r to change layer, |cFFFFFF00/hop h|r for help.")
	Hopper_PrintStatus()

	self:SetScript("OnEvent", Hopper_OnEvent)
	self:SetScript("OnUpdate", Hopper_OnUpdate)
	self:RegisterEvent("CHAT_MSG_ADDON")
	self:RegisterEvent("PARTY_INVITE_REQUEST")
	self:RegisterEvent("GROUP_ROSTER_UPDATE")

	successfulRequest = C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
	if not successfulRequest then 
		printerr("Failed registering to message prefix!")
	end 
end 

function Hopper_OnEvent(self, event, arg1, arg2, arg3, arg4, arg5)
	if event == "CHAT_MSG_ADDON" and arg1 == ADDON_PREFIX then
		Hopper_HandleAddonMessage(arg2, arg3, arg4, arg5)
	end

	if event == "PARTY_INVITE_REQUEST" then 
		Hopper_HandleIncomingPartyInvite(getRealmName(arg1))
	end 

	if event == "GROUP_ROSTER_UPDATE" then 
		-- debug("GROUP_ROSTER_UPDATE")
		if gHopInvitationTime > 0 and time() - gHopInvitationTime < HOP_ACCEPT_TIMEOUT then 
			-- debug("gHopInvitationSent in party = "..tostring(UnitInParty(gHopInvitationSent)))
			-- debug("Checking if "..gHopInvitationSent.." is in party: "..tostring(UnitInParty(gHopInvitationSent)))
			if UnitInParty(gHopInvitationSent) then 
				debug("Group joined, logging "..gHopInvitationSent.." invite time")
				INVITED[gHopInvitationSent] = gHopInvitationTime
				gHopInvitationTime = 0
				gHopInvitationSent = nil 
			end 
		end 
	end 

end

function Hopper_OnUpdate(self)
	if gShouldAutoLeave > 0 and time() - gShouldAutoLeave >= AUTO_LEAVE_DELAY then 
		gShouldAutoLeave = 0
		LeaveParty()
	end 
	if gHopRequestRetry then 
		local partySize = GetNumGroupMembers()
		if partySize == 0 then 
			gHopRequestRetry = false 
			Hopper_RequestHop()
		end 
	end 
	if gHopRequested and time() - gHopRequestTime > HOP_REQUEST_TIMEOUT then 
		print("No one seems to respond. Make sure your guild members install this addon.")
		gHopRequested = false 
		gHopRequestTime = 0
	end 
	if gHoppers ~= nil and time() - gHoppersQuery > HOPPER_QUERY_TIMEOUT then 
		local enabled = 0
		local total = 0
		for k, v in pairs(gHoppers) do 
			if v["Enabled"] == "true" then 
				enabled = enabled + 1
			end 
			total = total + 1
		end 
		print("Query result: "..total.." hoppers, "..enabled.." enablers")
		gHoppers = nil 
	end 
end 

function Hopper_HandleIncomingPartyInvite(sender) 
	local partySize = GetNumGroupMembers()
	debug("Party requested from "..sender..", partySize = "..partySize..", gHopRequestTime = "..gHopRequestTime)
	if partySize == 0 and gHopRequested and time() - gHopRequestTime <= HOP_REQUEST_TIMEOUT then 
		print("Hopped into "..sender.."'s world!")
		AcceptGroup()
		gHopRequested = false 
		if AUTO_LEAVE_DELAY > 0 then 
			gShouldAutoLeave = time()
		end 
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

function Hopper_HandleAddonMessage(text, channel, sender, target)
	local partySize = GetNumGroupMembers()
	local parts = splitCsv(text)
	local message = parts[1]
	-- debug('CHAT_MSG_ADDON ('..sender..') '..text)
	if message == MSG_COUNT then 
		if parts[2] then 
			-- count response
			if gHoppers ~= nil then 
				debug("Count - "..sender..", enabled: "..parts[2]..", version: "..parts[3])
				gHoppers[sender] = {["Enabled"] = parts[2], ["Version"] = parts[3]}
			end 	
		else 
			-- count query
			debug("Hop count query from "..sender)
			C_ChatInfo.SendAddonMessage(ADDON_PREFIX, MSG_COUNT..","..tostring(ENABLED)..","..VERSION, SCOPE)
		end 
	end 
	if message == MSG_COUNT_ENABLED then 
		-- old count response
		if gHoppers ~= nil then 
			debug("Count - "..sender.." - ENABLED")
			gHoppers[sender] = {["Enabled"] = "true"}
		end 
	end 
	if message == MSG_COUNT_DISABLED then 
		-- old count response
		if gHoppers ~= nil then 
			debug("Count - "..sender.." - DISABLED")
			gHoppers[sender] = {["Enabled"] = "false"}
		end 
	end 
	if message == MSG_INVITE and ENABLED then 
		debug("Hop requested "..message.." from "..sender.." my name "..gPlayerName.." / "..gRealmPlayerName)
		local isLeader = partySize > 0 and UnitIsGroupLeader(gPlayerName)
		if (sender ~= gPlayerName and sender ~= gRealmPlayerName) and (partySize == 0 or isLeader and PARTYADD) then
			local lastInvite = INVITED[removeRealmName(sender)]
			if lastInvite then 
				debug("Invited before "..tostring(time() - lastInvite).." seconds")
			end 
			if not lastInvite or time() - lastInvite > HOP_INVITE_COOLDOWN then   
				gHopInvitationSent = removeRealmName(sender)
				debug("Inviting "..gHopInvitationSent.." to my layer")
				gHopInvitationTime = time()
				InviteUnit(sender)
			end 
		end 
	end 
end 

function Hopper_PrintStatus()
	if ENABLED then 
		print("Auto invite |cff11ff11enabled|r, write |cFFFFFF00/hop d|r to disable.")
	else 
		print("Auto invite |cffff1111disabled|r, write |cFFFFFF00/hop e|r to enable.")
	end 
end 

function Hopper_RequestHop()
	if not IsInGuild() then 
		printerr("You are not in a guild, this addon only works between guild members.")
		return 
	end 
	local partySize = GetNumGroupMembers()
	debug("gHopRequestTime = "..gHopRequestTime..", partySize = "..partySize..", AUTOLEAVE = "..tostring(AUTOLEAVE))
	if time() - gHopRequestTime <= HOP_REQUEST_COOLDOWN then 
		printerr("TOO SOON, MORTAL INFIDEL. Try again in "..tostring(HOP_REQUEST_COOLDOWN - (time() - gHopRequestTime)).." seconds.")
		return 
	end 
	if partySize == 0 or AUTOLEAVE then 
		if partySize > 0 then
			LeaveParty()
			gHopRequestRetry = true 
			return 
		end 
		print("Sending hop request...")
		gHopRequestTime = time()
		gHopRequested = true 
		if gToPlayer then 
			C_ChatInfo.SendAddonMessage(ADDON_PREFIX, MSG_INVITE, "WHISPER", gToPlayer)
		else 
			C_ChatInfo.SendAddonMessage(ADDON_PREFIX, MSG_INVITE, SCOPE)
		end 
	else 
		printerr("Can't hop while in a party, leave it first.")
	end 
end 

function Hopper_Count()
	print("Counting hoppers...")
	gHoppersQuery = time()
	gHoppers = {}
	C_ChatInfo.SendAddonMessage(ADDON_PREFIX, MSG_COUNT, SCOPE)
end 

function Hopper_Main(msg) 
	local _, _, cmd, arg1 = string.find(string.upper(msg), "([%w]+)%s*(.*)$");
	if not cmd then
		gToPlayer = nil
		Hopper_RequestHop()
	elseif  "TO" == cmd then
		gToPlayer = arg1 
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
	elseif  "LD" == cmd or "LEAVEDELAY" == cmd then
		AUTO_LEAVE_DELAY = tonumber(arg1)
		print("Set leave delay to "..AUTO_LEAVE_DELAY)
	elseif  "P" == cmd or "PARTYADD" == cmd then
		PARTYADD = not PARTYADD
		if PARTYADD then 
			print("Party Add |cff11ff11enabled|r. Will add to party, if leading.")
		else 
			print("Party Add |cffff1111disabled|r. Will not add to party.")
		end 
	elseif  "L" == cmd or "AUTOLEAVE" == cmd then
		AUTOLEAVE = not AUTOLEAVE
		if AUTOLEAVE then 
			print("Auto Leave Party |cff11ff11enabled|r. Will leave if in a party when /hop is used.")
		else 
			print("Auto Leave Party |cffff1111disabled|r. Will ignore /hop command if in a party.")
		end 
	elseif  "C" == cmd or "COUNT" == cmd then
		if not gHoppers then 
			Hopper_Count()
		end 
	elseif  "DEBUG" == cmd then
		DEBUG = not DEBUG
	elseif  "RESET" == cmd then
		INVITED = {}
    elseif  "H" == cmd or "HELP" == cmd then
        print("Commands: ")
        print(" |cFFFFFF00/hop|r - change layer")
        print(" |cFFFFFF00/hop to <player name>|r - hop into <player name> layer, if haven't done so recently")
        print(" |cFFFFFF00/hop e|r - enable auto invite of guild members")
        print(" |cFFFFFF00/hop d|r - disable auto invite")
        print(" |cFFFFFF00/hop p|r - enable/disable adding auto inviting members to existing party ("..tostring(PARTYADD)..")")
        print(" |cFFFFFF00/hop l|r - enable/disable auto leave current party for /hop ("..tostring(AUTOLEAVE)..")")
        print(" |cFFFFFF00/hop ld <seconds>|r - set leave delay, don't make it too short to allow layer switching ("..tostring(AUTO_LEAVE_DELAY)..")")
	end
end 
