
ENABLED = true
PARTYADD = true
AUTOLEAVE = false 
INVITED = {}
AUTO_LEAVE_DELAY = 2
DEBUG = false
CHANNEL_NAME = "layer"
CHANNEL_MSG = "layer"

local VERSION = "1.0.9"
local CHANNEL_WHISPER = "WHISPER"
local CHANNEL_GUILD = "GUILD"
local MSG_INVITE = "inv"
local MSG_COUNT = "count"
local MSG_COUNT_ENABLED = "count-en"
local MSG_COUNT_DISABLED = "count-de"
local ADDON_PREFIX = "ZE2okI8Vx5H72L"
local SCOPE = CHANNEL_GUILD
local HOPPER_QUERY_TIMEOUT = 10
local HOP_REQUEST_TIMEOUT = 10
local HOP_REQUEST_CHANNEL_RESORT = 3
local HOP_ACCEPT_TIMEOUT = 60
local HOP_REQUEST_COOLDOWN = 10
local HOP_INVITE_COOLDOWN = 600 -- wait 10 minutes before inviting someone again
local IDENTICAL_PLAYERS_CHANGED = 0.1 -- allow 10% identical players (10/50)
local LAYER_DETECTION_TIMEOUT = 90
local LAYER_DETECTION_WHO = 10

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
local gInLayerOf = nil

local gLayerID = nil
local gLayerDetectionStarted = nil
local gLayerDetectionWho = nil
local gSentWhoQuery = nil
local gWhoResult = nil
local gWhoResultSize = 0
local libWho = nil 

------------------------------------------------------------------------------
-- Utils

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

------------------------------------------------------------------------------
-- Events

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
	local t = time()
	if gShouldAutoLeave > 0 and t - gShouldAutoLeave >= AUTO_LEAVE_DELAY then 
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
	if gHopRequested then 
		if t - gHopRequestTime > HOP_REQUEST_TIMEOUT then 
			print("No one seems to respond. Make sure your guild members install this addon.")
			gHopRequested = false 
			gHopRequestTime = 0
		end 
		if t - gHopRequestTime > HOP_REQUEST_CHANNEL_RESORT and CHANNEL_NAME and not gToPlayer then 
			Hopper_RequestFromChannel()
		end 
	end 
	if gHoppers ~= nil and t - gHoppersQuery > HOPPER_QUERY_TIMEOUT then 
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
	if gLayerDetectionStarted then
		if t - gLayerDetectionStarted > LAYER_DETECTION_TIMEOUT then 
			gLayerDetectionStarted = nil 
			gLayerDetectionWho = nil 
			gWhoResult = {}
			debug("Layer detection timeout, stopping")
		else 
			inCombat = UnitAffectingCombat("player")
			if inCombat then 
				gLayerDetectionStarted = t 
				gLayerDetectionWho = t 
			else
				if t - gLayerDetectionWho > LAYER_DETECTION_WHO then 
					gLayerDetectionWho = t
					Hopper_SampleWho() 
				end 
			end 
		end 
	end 
end 

------------------------------------------------------------------------------
-- Party 

-- sender = realm player name
function Hopper_HandleIncomingPartyInvite(sender) 
	local partySize = GetNumGroupMembers()
	debug("Party requested from "..sender..", partySize = "..partySize..", gHopRequestTime = "..gHopRequestTime)
	if partySize == 0 and gHopRequested and time() - gHopRequestTime <= HOP_REQUEST_TIMEOUT then 
		print("Hopped into "..sender.."'s world!")
		gInLayerOf = sender 
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

------------------------------------------------------------------------------
-- Addon Comm

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
		debug("Hop requested "..message.." from "..sender.." through "..channel)
		local isLeader = partySize > 0 and UnitIsGroupLeader(gPlayerName)
		if (sender ~= gPlayerName and sender ~= gRealmPlayerName) and (partySize == 0 or isLeader and PARTYADD) then
			local lastInvite = INVITED[removeRealmName(sender)]
			if lastInvite then 
				debug("Invited before "..tostring(time() - lastInvite).." seconds")
			end 
			if channel == CHANNEL_WHISPER or not lastInvite or time() - lastInvite > HOP_INVITE_COOLDOWN then   
				gHopInvitationSent = removeRealmName(sender)
				debug("Inviting "..gHopInvitationSent.." to my layer")
				gHopInvitationTime = time()
				InviteUnit(sender)
			end 
		end 
	end 
end 

------------------------------------------------------------------------------
-- Layer detection

function Hopper_SampleWho() 
	local whotext
	if gFaction == "Horde" then whotext = 'z-"Orgrimmar"' else whotext = 'z-"Stormwind"' end 

	wholib = wholib or LibStub:GetLibrary("LibWho-2.0", true)
	gSentWhoQuery = time()
	if wholib then
		debug("Sending who query "..whotext)
		wholib:Who(whotext, {
			queue = wholib.WHOLIB_QUEUE_QUIET,
			flags = 0,
			callback = Hopper_ProcessWhoResult
		})
	else
		printerr("No wholib detected")
		-- SendWho(whotext)
	end
end 

function Hopper_StartLayerChangeDetection() 
	gWhoResult = nil 
	Hopper_SampleWho()
	gLayerDetectionStarted = time()
	gLayerDetectionWho = gLayerDetectionStarted
end 

function Hopper_ProcessWhoResult(query, result, complete)
	debug("Who query returned "..#result.." results")
	if not gWhoResult then 
		gWhoResultSize = #result 
		gWhoResult = {}
		for k, v in pairs(result) do 
			gWhoResult[v.Name] = 1
		end 
		Hopper_RequestHop_Send()
	else 
		local count = 0
		for k, v in pairs(result) do 
			if gWhoResult[v.Name] then count = count + 1 end
		end 
		local commonPercent = count / gWhoResultSize
		debug("Who common = "..tostring(math.floor(commonPercent * 100)).."% "..count.."/"..gWhoResultSize)
		if commonPercent <= IDENTICAL_PLAYERS_CHANGED then 
			Hopper_OnLayerChange()
		end 
	end 
end 

function Hopper_OnLayerChange() 
	gLayerDetectionStarted = nil 
	gLayerDetectionWho = nil
	gWhoResult = nil 
	print("|cffff2222 !! Layer changed !!")
end 

------------------------------------------------------------------------------
-- Commands

function Hopper_RequestHop()
	if not IsInGuild() and not gToPlayer then 
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
		Hopper_StartLayerChangeDetection()
	else 
		printerr("Can't hop while in a party, leave it first.")
	end 
end 

function Hopper_RequestHop_Send() 
	print("Sending hop request...")
	gHopRequestTime = time()
	gHopRequested = true 
	if gToPlayer then 
		if gToPlayer == "CHANNEL" then 
			Hopper_RequestFromChannel()
		else 
			C_ChatInfo.SendAddonMessage(ADDON_PREFIX, MSG_INVITE, CHANNEL_WHISPER, gToPlayer)
		end 
	else 
		C_ChatInfo.SendAddonMessage(ADDON_PREFIX, MSG_INVITE, SCOPE)
	end 
end 

function Hopper_RequestFromChannel() 
	for i=1,15 do
		local id, name = GetChannelName(i);
		if name and string.lower(name) == string.lower(CHANNEL_NAME) then
			SendChatMessage(CHANNEL_MSG, "CHANNEL", nil, id);
		end
	end	  
end 

function Hopper_Count()
	print("Counting hoppers...")
	gHoppersQuery = time()
	gHoppers = {}
	C_ChatInfo.SendAddonMessage(ADDON_PREFIX, MSG_COUNT, SCOPE)
end 

function Hopper_PrintStatus()
	if ENABLED then 
		print("Auto invite |cff11ff11enabled|r, write |cFFFFFF00/hop d|r to disable.")
	else 
		print("Auto invite |cffff1111disabled|r, write |cFFFFFF00/hop e|r to enable.")
	end 
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
	elseif  "CH" == cmd or "CHANNEL" == cmd then
		gToPlayer = "CHANNEL"
		Hopper_RequestHop()
	elseif  "CHNAME" == cmd then
		if arg1 and string.len(arg1) > 0 then 
			CHANNEL_NAME = arg1 
			print("Channel request set to |cff11ff11"..CHANNEL_NAME.."|r")
		else 
			CHANNEL_NAME = nil 
			print("Channel request |cffff1111disabled|r")
		end 
	elseif  "CHTXT" == cmd  then
		if arg1 and string.len(arg1) > 0 then 
			CHANNEL_MSG = arg1 
			print("Channel request message set to |cff11ff11"..CHANNEL_MSG.."|r")
		end 
	elseif  "TEST" == cmd then
		-- gWhoResult = nil 
		-- Hopper_SampleWho()
		-- gLayerDetectionStarted = time()
	elseif  "DEBUG" == cmd then
		DEBUG = not DEBUG
		print("Debug = "..tostring(DEBUG))
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
        print(" |cFFFFFF00/hop ch|r - will request for layer invite in public channel, if set")
        print(" |cFFFFFF00/hop chname <channel name>|r - will request for layer invite in this channel if no guildy responds ("..tostring(CHANNEL_NAME)..")")
        print(" |cFFFFFF00/hop chtxt <request text>|r - this text will be sent to request channel if enabled ("..tostring(CHANNEL_MSG)..")")
	end
end 
