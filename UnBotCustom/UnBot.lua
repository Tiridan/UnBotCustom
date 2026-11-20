
function UnBotSplit(str, split_char)
    local sub_str_tab = {};
    while (true) do
        local pos = string.find(str, split_char);
        if (not pos) then
            sub_str_tab[#sub_str_tab + 1] = str;
            break
        end
        local sub_str = string.sub(str, 1, pos - 1);
        sub_str_tab[#sub_str_tab + 1] = sub_str;
        str = string.sub(str, pos + 1, #str);
    end

    return sub_str_tab;
end

function UnBotCloseAll()
	UnBotHideAllSubFrame();
	UnBotCloseAllBagsFrame();
	UnBotClearAllQRFrame();
	UnBotClearAllStrategyFrame();
	OnlineFrame:Hide();
	NPCFrame:Hide();
	UnBotFrame:Hide();
	DisplayInfomation(UnBotLocale.Text("Bar is now hidden. Use /unbot to toggle the bar."));
end

local function AddButton(name,fromParent,temp,gi,ci)
	if (fromParent == nil) then
		return nil;
	end
	if (UnBotIconFiles[ci] == nil) then
		return nil;
	end
	local newFrame = CreateFrame("Button",name..tostring(ci),fromParent.lastButton,temp);
	newFrame.groupIndex = gi;
	newFrame.comIndex = ci;
	newFrame.Icon = newFrame:CreateTexture("UnBotSubIcon"..tostring(ci),"BACKGROUND");
	newFrame.Icon:SetTexture(GetIconPathByIndex(UnBotIconFiles[ci]));
	newFrame.Icon:SetAllPoints(newFrame);
	newFrame.Icon:Show();
	newFrame:Show();
	newFrame:SetPushedTexture([[Interface\BUTTONS\UI-Quickslot-Depress]]);
	newFrame:SetHighlightTexture([[Interface\Buttons\UI-Common-MouseHilight]],"ADD");
	fromParent.lastButton = newFrame;
	if(fromParent.nextSubButtonIndex == 1) then
		UpdateGroupButtonActive(gi,true);
		if(UnBotCommandBarConfig[ci] == nil) then
			local groupButton = _G["UnBotCommandButton"..tostring(newFrame.groupIndex)];
			if (groupButton ~= nil) then
				ResetCommandToAction(newFrame,groupButton.comIndex,false);
			else
				ResetCommandToAction(newFrame,ci,false);
			end
		end
	end
	fromParent.nextSubButtonIndex = fromParent.nextSubButtonIndex + 1;
	return newFrame;
end

function InspectFrame_Show(unit)
	if(InspectFrame) then
		DoInspectFrameShow(unit);
	else
		if( IsAddOnLoaded("Blizzard_InspectUI") == nil) then
			local loaded, reason = LoadAddOn("Blizzard_InspectUI");
			if( loaded == nil) then
				DisplayInfomation(UnBotLocale.Text("Window initialization failed: ")..reason);
			else
				DoInspectFrameShow(unit);
			end
		end
	end
end

function DoInspectFrameShow(unit)
	if(InspectFrame) then
		HideUIPanel(InspectFrame);
		if ( CanInspect(unit, true) ) then
			NotifyInspect(unit);
			InspectFrame.unit = unit;
			InspectSwitchTabs(1);
			ShowUIPanel(InspectFrame);
			InspectFrame_UpdateTalentTab();
			DisplayInfomation("InspectFrame_Show "..UnitName(unit));
		end	
	end
end



function InitializeUnBotFrame()
	if (UnBotLocale) then UnBotLocale.Initialize(); end
	DisplayInfomation(UnBotLocale.Text("Initializing bot controller"));
	if(UnBotFrame.Inited == true) then
		return;
	end
	UnBotFrame.Inited = true;
	
	if (UnBotCommandBarConfig == nil) then
		UnBotCommandBarConfig = {};
	end
	for i=1, 10 do
		UpdateGroupButtonActive(i,false);
	end
	for i=1, #UnBotCommandToGroups do
		if (UnBotExecuteCommand[i] ~= nil and UnBotExecuteCommand[i] ~= "") then
			local toGroup = UnBotCommandToGroups[i];
			local newFrame = AddButton("UnBotSubCommandButton",_G["UnBotSubFrame"..tostring(toGroup)],"UnBotCommandSubButtonTemplate",toGroup,i);
		end
	end

	for i=1, 10 do
		local groupButton = _G["UnBotCommandButton"..tostring(i)];
		ResetCommandToAction(groupButton, UnBotCommandBarConfig[i],false);
	end
	UnBotUpdateHotkeys();

	InitializeStrategy();

	SetUnBotScale();

	DisplayInfomation(UnBotLocale.Text("Bot controller initialized"));
end

local function GetCommandTypeTextByType(typeIndex)
	if (typeIndex == 4) then
		return UnBotLocale.Text("Group");
	elseif (typeIndex == 3) then
		return UnBotLocale.Text("Hostile");
	elseif (typeIndex == 2) then
		return UnBotLocale.Text("Friendly");
	else
		return UnBotLocale.Text("None");
	end
end

function CommandButton_OnEnter(self,index,btnType)
	GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT");
	GameTooltip:AddLine(UnBotTooltipTitle[index],1,0,0,1);
	GameTooltip:AddDoubleLine(UnBotLocale.Text("Target:"),GetCommandTypeTextByType(UnBotCommandType[index]),0,0,1,1,0,1);
	GameTooltip:AddLine(UnBotTooltipHelp[index],0,1,0,1);
	GameTooltip:AddLine(" ",1,1,1,1);
	if (self.groupIndex > 0) then
		GameTooltip:AddDoubleLine(UnBotLocale.Text("Uses:"),UnBotExecuteCommand[index],0,0.85,0.85,0,0.85,0.85);
	end
	GameTooltip:AddLine(UnBotLocale.Text("LMB: Use"),0.65,0.55,0,1);
	if (self.groupIndex > 0) then
		if (btnType == 1) then
			GameTooltip:AddLine(UnBotLocale.Text("RMB: Toggle button group"),0.65,0.55,0,1);
		elseif (btnType == 2) then
			GameTooltip:AddLine(UnBotLocale.Text("RMB: Set shortcut"),0.65,0.55,0,1);
		end
	else
		GameTooltip:AddLine(UnBotLocale.Text("RMB: Hide the bar"),0.65,0.55,0,1);
	end
	GameTooltip:AddDoubleLine("ID:",tostring(index),0,0,1,1,0,1);
	GameTooltip:AddTexture(GetIconPathByIndex(UnBotIconFiles[index]));
	GameTooltip:Show();
end

function UnBotHideAllSubFrame()
	for i=0, 10 do
		local frameObject = _G["UnBotSubFrame"..tostring(i)];
		if (frameObject ~= nil) then
			frameObject:Hide();
		end
		local groupButton = _G["UnBotCommandButton"..tostring(i)];
		if (groupButton ~= nil) then
			groupButton.showMenu = false;
		end
	end
end

function UnBotClearAllQRFrame()
	for i=1, #(UnBotFrame.ShowedQRs) do
		local qr = UnBotFrame.ShowedQRs[i];
		qr.showTick = 0;
		qr:Hide();
		qr:SetParent(nil);
	end
	UnBotFrame.ShowedQRs = {};
end

function UnBotClearAllStrategyFrame()
	for i=1, #(UnBotFrame.ShowedStrategy) do
		local ss = UnBotFrame.ShowedStrategy[i];
		ss:Hide();
		ss:SetParent(nil);
	end
	UnBotFrame.ShowedStrategy = {};
end

function UnBotRemoveByQRFrame(targetQR)
	for i=1, #(UnBotFrame.ShowedQRs) do
		if (UnBotFrame.ShowedQRs[i]:GetName() == targetQR:GetName()) then
			table.remove(UnBotFrame.ShowedQRs,i);
			return;
		end
	end
end

function UpdateGroupButtonActive(index,show)
	local groupButton = _G["UnBotCommandButton"..tostring(index)];
	if (groupButton == nil) then
		return;
	end
	if (show == true) then
		groupButton:Show();
	else
		groupButton:Hide();
	end
end

function ResetCommandToAction(self,index,save)
	local groupButton = _G["UnBotCommandButton"..tostring(self.groupIndex)];
	if (groupButton == nil or index == nil) then
		return;
	end
	if (UnBotExecuteCommand[index] == nil or UnBotExecuteCommand[index] == "") then
		return;
	end
	-- The parent may still be hidden during ADDON_LOADED; OnShow is not guaranteed yet.
	if (not groupButton.Icon) then
		groupButton.Icon = groupButton:CreateTexture("UnBotCommandIcon"..tostring(groupButton.groupIndex),"BACKGROUND");
		groupButton.Icon:SetAllPoints(groupButton);
	end
	groupButton.Icon:SetTexture(GetIconPathByIndex(UnBotIconFiles[index]));
	groupButton.comIndex = index;
	groupButton.Icon:Show();
	--DisplayInfomation("应用 "..tostring(index).." 号命令到组按钮 "..tostring(self.groupIndex));

	if (save == true) then
		UnBotCommandBarConfig[self.groupIndex] = index;
	end

	local subFrame = _G["UnBotSubFrame"..tostring(self.groupIndex)];
	groupButton.showMenu = false;
	if (subFrame == nil) then
		return;
	end
	subFrame:Hide();
end

function GetIconPathByIndex(index)
	local iconPath = UnBotCommandIconsPath[index];
	return iconPath;
end

function UnBotUpdateHotkeys()
	for i=1, 10 do
		local groupButtonLabel = _G["UnBotCommandButton"..tostring(i).."Label"];
		if (groupButtonLabel ~= nil) then
			local bindingKey = GetBindingKey("CLICK UnBotCommandButton"..tostring(i)..":LeftButton");
			if (bindingKey ~= nil) then
				local keyText = GetBindingText(bindingKey, "KEY_", 1);
				groupButtonLabel:SetText(keyText);
			else
				groupButtonLabel:SetText("");
			end
		end
	end
	local groupFuncLabel = _G["UnBotCommandButtonFuncLabel"];
	if (groupFuncLabel ~= nil) then
		local bindingFuncKey = GetBindingKey("CLICK UnBotCommandButtonFunc:LeftButton");
		if (bindingFuncKey ~= nil) then
			local keyText = GetBindingText(bindingFuncKey, "KEY_", 1);
			groupFuncLabel:SetText(keyText);
		else
			groupFuncLabel:SetText("");
		end
	end
end

UnBotChatWindowName = "UnBot";
UnBotChatPendingMessages = UnBotChatPendingMessages or {};
UnBotChatCanCreate = false;

function UnBotChatFindFrame()
	if (not NUM_CHAT_WINDOWS) then
		return nil;
	end
	for i = 1, NUM_CHAT_WINDOWS, 1 do
		local frame = _G["ChatFrame"..tostring(i)];
		local tab = _G["ChatFrame"..tostring(i).."Tab"];
		if (frame and tab and tab.GetText and tab:GetText() == UnBotChatWindowName) then
			return frame;
		end
	end
	return nil;
end

function UnBotChatFrameIsDocked(frame)
	if (not frame) then
		return false;
	end
	if (frame.isDocked == true or frame.isDocked == 1) then
		return true;
	end
	if (GetChatWindowInfo and frame.GetID) then
		local result = { pcall(GetChatWindowInfo, frame:GetID()) };
		return result[1] and (result[10] == true or result[10] == 1) and true or false;
	end
	return false;
end

function UnBotChatDockFrame(frame)
	if (not frame) then
		return false;
	end
	if (not UnBotChatFrameIsDocked(frame)) then
		-- A fresh FCF window can inherit LOCKED=1 while still floating. Unlock it
		-- before docking so it never remains as an immovable tab in the middle
		-- of the player's chat area.
		if (FCF_SetLocked) then
			pcall(FCF_SetLocked, frame, nil);
		end
		if (FCF_DockFrame) then
			pcall(FCF_DockFrame, frame);
		end
	end
	if (not UnBotChatFrameIsDocked(frame)) then
		return false;
	end
	local tab = _G[tostring(frame:GetName()).."Tab"];
	if (tab and tab.Show) then
		tab:Show();
	end
	return true;
end

function UnBotChatPrepareFrame(frame)
	if (not frame or frame.UnBotOnly) then
		return frame;
	end
	if (ChatFrame_RemoveAllMessageGroups) then
		ChatFrame_RemoveAllMessageGroups(frame);
	end
	if (ChatFrame_RemoveAllChannels) then
		ChatFrame_RemoveAllChannels(frame);
	end
	frame.UnBotOnly = true;
	return frame;
end

function UnBotChatEnsureFrame()
	if (not UnBotChatCanCreate) then
		return nil;
	end
	local frame = UnBotChatFindFrame();
	if (not frame and FCF_OpenNewWindow) then
		-- Some 3.3.5 clients throw from FCF_FadeInChatFrame after they have
		-- already created a partial window. Catch that error, find the partial
		-- frame and repair/dock it below.
		pcall(FCF_OpenNewWindow, UnBotChatWindowName);
		frame = UnBotChatFindFrame();
	end
	if (frame) then
		-- A valid dedicated window is usable even when docking is refused.
		UnBotChatDockFrame(frame);
		local tab = _G[tostring(frame:GetName()).."Tab"];
		if (tab and tab.Show) then tab:Show(); end
		UnBotChatFrame = UnBotChatPrepareFrame(frame);
		UnBotChatUseDefault = false;
		return UnBotChatFrame;
	end
	UnBotChatUseDefault = false;
	return nil;
end

function UnBotChatFlushPending(frame)
	if (not frame) then
		return;
	end
	for i = 1, #(UnBotChatPendingMessages or {}), 1 do
		frame:AddMessage(UnBotChatPendingMessages[i]);
	end
	UnBotChatPendingMessages = {};
end

function UnBotChatWrite(text, service)
	text = tostring(text or "");
	if (service ~= false and UnBotChatRouting and UnBotChatRouting.WriteService(text)) then return; end
	if (UnBotCombatChat and UnBotCombatChat.IsNotice(text)) then
		UnBotCombatChat.Write(text);
		return;
	end
	local frame = UnBotChatEnsureFrame();
	if (frame) then
		UnBotChatFlushPending(frame);
		frame:AddMessage(text);
	else
		table.insert(UnBotChatPendingMessages, text);
	end
end

function UnBotChatSelect()
	local frame = UnBotChatEnsureFrame();
	if (not frame) then
		if (DEFAULT_CHAT_FRAME) then
			DEFAULT_CHAT_FRAME:AddMessage(
				"|cffff5555UnBot: не удалось создать отдельную вкладку чата. Освободите одно окно чата и повторите /ubchat.|r"
			);
		end
		return;
	end
	UnBotChatFlushPending(frame);
	if (FCF_SelectDockFrame and UnBotChatFrameIsDocked(frame)) then
		FCF_SelectDockFrame(frame);
	else
		frame:Show();
	end
end

function UnBotChatNormalizeName(name)
	name = tostring(name or "");
	name = string.gsub(name, "%-[^%-]+$", "");
	return string.lower(name);
end

function UnBotChatIsKnownBot(name, accountAltsOnly)
	if (not accountAltsOnly and UnBotChatRouting and UnBotChatRouting.IsPaired(name)) then return true; end
	local wanted = UnBotChatNormalizeName(name);
	if (wanted == "") then
		return false;
	end
	for savedName, profile in pairs((UnBotBotRegistry and UnBotBotRegistry.bots) or {}) do
		if (not accountAltsOnly or (profile and (profile.accountAlt or profile.protectedAccountCharacter))) then
			if (UnBotChatNormalizeName(savedName) == wanted) then
				return true;
			end
			if (profile and profile.name and UnBotChatNormalizeName(profile.name) == wanted) then
				return true;
			end
		end
	end
	local storage = UnBotSquadConfig and UnBotSquadConfig.accountAlts;
	for savedName, profile in pairs((storage and storage.characters) or {}) do
		if (
			UnBotChatNormalizeName(savedName) == wanted
			or (profile and profile.name and UnBotChatNormalizeName(profile.name) == wanted)
		) then
			return true;
		end
	end
	return false;
end

function UnBotChatLooksLikeBotWhisper(message)
	local text = string.lower(tostring(message or ""));
	if (string.find(text, " lvl", 1, true) and string.find(text, " gs", 1, true)) then
		return true;
	end
	if (string.find(text, "buying [", 1, true) or string.find(text, "casting [", 1, true)) then
		return true;
	end
	if (string.find(text, "game objects", 1, true)) then
		return true;
	end
	return false;
end

function UnBotChatIsOwnGroupCommand(message, author)
	if (UnBotChatNormalizeName(author) ~= UnBotChatNormalizeName(UnitName("player"))) then
		return false;
	end
	local text = string.lower(tostring(message or ""));
	text = string.gsub(text, "^%s+", "");
	if (
		string.find(text, ".playerbot ", 1, true) == 1
		or string.find(text, "@", 1, true) == 1
		or string.find(text, "co ", 1, true) == 1
		or string.find(text, "nc ", 1, true) == 1
		or string.find(text, "rti ", 1, true) == 1
		or string.find(text, "attack rti ", 1, true) == 1
	) then
		return true;
	end
	return text == "leave" or text == "summon" or text == "follow" or text == "stay";
end

function UnBotChatKeepAutoBalanceSystem(message)
	local text = tostring(message or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "");
	return text:lower():find("[autobalance]", 1, true) ~= nil;
end

function UnBotChatIsPlayerbotSystemMessage(message)
	if (UnBotChatKeepAutoBalanceSystem(message)) then return false; end
	local text = string.lower(tostring(message or ""));
	if (string.find(text, "[autobalance]", 1, true)) then return true; end
	local clean = tostring(message or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "");
	local botName = clean:match('Игрок с именем "([^"]+)" не найден')
		or clean:match("^([^%s]+) присоединяется к группе")
		or clean:match("^([^%s]+) покидает группу")
		or clean:match("^([^%s]+) joins the party");
	if (botName and (UnBotChatIsKnownBot(botName)
		or (UnBotGroundChest and (botName == UnBotGroundChest.pendingName or botName == UnBotGroundChest.currentName)))) then
		return true;
	end
	if (string.find(text, "playerbot", 1, true)) then
		return true;
	end
	if (string.find(text, "bot roster:", 1, true)) then
		return true;
	end
	if (string.find(text, "random bot", 1, true)) then
		return true;
	end
	if (string.find(text, "already logged in", 1, true)) then
		return true;
	end
	if (
		(string.find(text, "add:", 1, true) or string.find(text, "remove:", 1, true))
		and string.find(text, " - ok", 1, true)
	) then
		return true;
	end
	return false;
end

function UnBotChatAddFilteredMessage(event, message, author)
	local key = tostring(event).."\031"..tostring(author or "").."\031"..tostring(message or "");
	local now = GetTime and GetTime() or 0;
	if (UnBotChatLastFilterKey == key and now - (UnBotChatLastFilterTime or 0) < 0.02) then
		return;
	end
	UnBotChatLastFilterKey = key;
	UnBotChatLastFilterTime = now;
	if (UnBotCombatChat and UnBotCombatChat.IsMessage(event, message, author)) then
		UnBotCombatChat.WriteEvent(event, message, author);
		return;
	end
	if (UnBotDebugChatIsMessage and UnBotDebugChatIsMessage(event, message, author)) then
		UnBotDebugChatWrite("<"..tostring(author).."> "..tostring(message));
		return;
	end
	if (event == "CHAT_MSG_WHISPER") then
		UnBotChatWrite("|cffff80ff<"..tostring(author)..">|r "..tostring(message), false);
	elseif (event == "CHAT_MSG_WHISPER_INFORM") then
		UnBotChatWrite("|cffaaaaff-> "..tostring(author)..":|r "..tostring(message), false);
	elseif (event == "CHAT_MSG_SYSTEM") then
		UnBotChatWrite("|cffffff00Сервер:|r "..tostring(message), false);
	else
		UnBotChatWrite("|cffaaaaaaКоманда:|r "..tostring(message), false);
	end
end

function UnBotChatMessageFilter(self, event, message, author)
	if (UnBotChatRouting) then
		local handled, filtered = UnBotChatRouting.Filter(self, event, message, author);
		if (handled) then return filtered; end
	end
	-- Account alts keep Blizzard's normal whisper display, including replies
	-- about strategies/casts and outgoing whispers. Controllers still get events.
	if ((event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_WHISPER_INFORM")
		and UnBotChatIsKnownBot(author, true)) then return false; end
	-- Let Blizzard display AutoBalance in the normal system
	-- message tabs. Do not manually echo: filters run once for each chat frame.
	if (event == "CHAT_MSG_SYSTEM" and UnBotChatKeepAutoBalanceSystem(message)) then return false; end
	local route = UnBotCombatChat and UnBotCombatChat.IsMessage(event, message, author);
	if (route) then
		-- Display only: the original event still reaches bot controllers.
	elseif (event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_WHISPER_INFORM") then
		route = (UnBotDebugChatIsMessage and UnBotDebugChatIsMessage(event, message, author)) or UnBotChatIsKnownBot(author)
			or (event == "CHAT_MSG_WHISPER" and UnBotChatLooksLikeBotWhisper(message));
	elseif (
		event == "CHAT_MSG_SAY"
		or event == "CHAT_MSG_PARTY"
		or event == "CHAT_MSG_PARTY_LEADER"
		or event == "CHAT_MSG_RAID"
		or event == "CHAT_MSG_RAID_LEADER"
	) then
		route = UnBotChatIsOwnGroupCommand(message, author);
	elseif (event == "CHAT_MSG_SYSTEM") then
		route = UnBotChatIsPlayerbotSystemMessage(message);
	end
	if (route) then
		UnBotChatAddFilteredMessage(event, message, author);
		return true;
	end
	return false;
end

function UnBotChatInstallFilters()
	if (UnBotChatFiltersInstalled or not ChatFrame_AddMessageEventFilter) then
		return;
	end
	UnBotChatFiltersInstalled = true;
	ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", UnBotChatMessageFilter);
	ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", UnBotChatMessageFilter);
	ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", UnBotChatMessageFilter);
	ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY", UnBotChatMessageFilter);
	ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY_LEADER", UnBotChatMessageFilter);
	ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID", UnBotChatMessageFilter);
	ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_LEADER", UnBotChatMessageFilter);
	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", UnBotChatMessageFilter);
	ChatFrame_AddMessageEventFilter("CHAT_MSG_MONSTER_YELL", UnBotChatMessageFilter);
end

function DisplayInfomation(info)
	UnBotChatWrite("|cff00cccc"..tostring(info or "").."|r");
end

SLASH_UNBOTCHAT1 = "/ubchat";
SlashCmdList["UNBOTCHAT"] = function()
	UnBotChatSelect();
end

UnBotChatLoader = UnBotChatLoader or CreateFrame("Frame", "UnBotChatLoader");
UnBotChatLoader:RegisterEvent("PLAYER_LOGIN");
UnBotChatLoader:SetScript("OnEvent", function(self)
	-- Let Blizzard finish restoring chat windows before opening/docking ours.
	-- Messages produced during this short delay remain in the pending queue.
	UnBotChatCanCreate = false;
	self.UnBotChatCreateAt = GetTime() + 1;
end);
UnBotChatLoader:SetScript("OnUpdate", function(self)
	if (
		(self.UnBotChatCreateAt or 0) <= 0
		or GetTime() < self.UnBotChatCreateAt
	) then
		return;
	end
	self.UnBotChatCreateAt = 0;
	UnBotChatCanCreate = true;
	local frame = UnBotChatEnsureFrame();
	if (UnBotCombatChat) then UnBotCombatChat.Start(); end
	if (frame) then
		UnBotChatFlushPending(frame);
		return;
	end
	UnBotChatUseDefault = false;
	if (DEFAULT_CHAT_FRAME) then
		DEFAULT_CHAT_FRAME:AddMessage(
			"|cffff5555UnBot: не удалось создать вкладку. Сообщения ожидают её открытия; освободите окно чата и выполните /ubchat.|r"
		);
	end
end);

UnBotChatInstallFilters();

function CanAddToUnBotFrame(targetName)
	for i=1, #(UnBotFrame.ShowedBags) do
		if (UnBotFrame.ShowedBags[i]:GetName() == targetName) then
			return false;
		end
	end
	return true;
end

function AddToUnBotFrame(bagsFrame, targetName)
	for i=1, #(UnBotFrame.ShowedBags) do
		if (UnBotFrame.ShowedBags[i]:GetName() == targetName) then
			return false;
		end
	end
	table.insert(UnBotFrame.ShowedBags, bagsFrame);
	return true;
end

function RemoveFromUnBotFrame(bagsFrame)
	for i=1, #(UnBotFrame.ShowedBags) do
		if (UnBotFrame.ShowedBags[i]:GetName() == bagsFrame:GetName()) then
			table.remove(UnBotFrame.ShowedBags,i);
			return;
		end
	end
end

function AddToUnBotStrategyFrame(strategyFrame, targetName)
	for i=1, #(UnBotFrame.ShowedStrategy) do
		if (UnBotFrame.ShowedStrategy[i]:GetName() == targetName) then
			return false;
		end
	end
	table.insert(UnBotFrame.ShowedStrategy, strategyFrame);
	return true;
end

function RemoveFromStrategyFrame(strategyFrame)
	for i=1, #(UnBotFrame.ShowedStrategy) do
		if (UnBotFrame.ShowedStrategy[i]:GetName() == strategyFrame:GetName()) then
			table.remove(UnBotFrame.ShowedStrategy,i);
			return;
		end
	end
end

function UnBotEnableAllFrameFlushButton()
	for i=1, #(UnBotFrame.ShowedBags) do
		local flushButton = _G["BagsFrameFlush"..(UnBotFrame.ShowedBags[i]:GetName())]
		if (flushButton ~= nil) then
			flushButton:Enable();
		end
	end
end
function UnBotDisableAllFrameFlushButton()
	for i=1, #(UnBotFrame.ShowedBags) do
		local flushButton = _G["BagsFrameFlush"..(UnBotFrame.ShowedBags[i]:GetName())]
		if (flushButton ~= nil) then
			flushButton:Disable();
		end
	end
end

function CaseNormalWhisperMsg(name, info)
	local i1, i2 = string.find(info, "Select reward");
	if (i1 ~= nil and i2 ~= nil) then
		RecvQuestReward(name, info);
	end
end

function SubCommandButton_OnLeftClick(index)
	if (index > 0) then
		if (UnBotExecuteCommand[index] == nil or UnBotExecuteCommand[index] == "") then
			return;
		end
	end
	if (UnBotCommandType[index] == nil) then
		DisplayInfomation("Could not find order "..tostring(index));
		return;
	end
	local realize = getglobal("UnBotCommandRealize");
	if (realize ~= nil and realize[index] ~= nil) then
		realize[index](index);
	else
		if (UnBotCommandType[index] == 1) then
			SendChatMessage(UnBotExecuteCommand[index], "SAY");
		elseif (UnBotCommandType[index] == 2) then
			local targetName = UnitName("target");
			local isParty = UnitInParty("target");
			local isRaid = UnitInRaid("target");
			if (targetName == nil or targetName == "") then
				DisplayInfomation(UnBotLocale.Text("You have no target."));
				return;
			end
			if (isParty == nil and isRaid == nil) then
				DisplayInfomation(UnBotLocale.Text("The target is not in your group."));
				return;
			end
			-- if (not IsRealPartyLeader()) then
			-- 	DisplayInfomation("你当前不是队伍领袖。");
			-- else
			SendChatMessage(UnBotExecuteCommand[index], "WHISPER", nil, targetName);
			-- end
		elseif (UnBotCommandType[index] == 3) then
			local targetName = UnitName("target");
			if (targetName == nil or targetName == "") then
				DisplayInfomation(UnBotLocale.Text("You have no target."));
				return;
			end
			-- if (not IsRealPartyLeader()) then
			-- 	DisplayInfomation("你当前不是队伍领袖。");
			-- else
			SendChatMessage(UnBotExecuteCommand[index], "PARTY");
			-- end
		elseif (UnBotCommandType[index] == 4) then
			-- if (not IsRealPartyLeader()) then
			-- 	DisplayInfomation("你当前不是队伍领袖。");
			-- else
			SendChatMessage(UnBotExecuteCommand[index], "PARTY");
			-- end
		else
			DisplayInfomation("You click button index "..tostring(index)..", execute "..UnBotExecuteCommand[index]);
		end
	end
end

function UnBotFrameUpdate(ubFrame, tick)
	if (ubFrame.DelayInitTime > 0 and tick > ubFrame.DelayInitTime) then
		ubFrame.DelayInitTime = 0;
		UnBotInitInspectFrame();
	end
end

function SetUnBotScale()
	if (UnBotScaleConfig == nil or UnButScaleConfig == "" or tonumber(UnBotScaleConfig) == nil) then
		UnBotScaleConfig = 1;
	end

	if (UnBotScaleConfig ~= nil and UnButScaleConfig ~= "" and tonumber(UnBotScaleConfig) ~= nil) then
		UnBotFrame:SetScale(UnBotScaleConfig);
		OnlineFrame:SetScale(UnBotScaleConfig);
		NPCFrame:SetScale(UnBotScaleConfig);
		for i=1, #(UnBotFrame.ShowedStrategy) do
			local ss = UnBotFrame.ShowedStrategy[i];
			ss:SetScale(UnBotScaleConfig);
		end
		for i=1, #(UnBotFrame.ShowedBags) do
			local ss = UnBotFrame.ShowedBags[i];
			ss:SetScale(UnBotScaleConfig);
		end
	end
end

-- Service windows live in this existing TOC file so cached XML includes cannot skip them.
-- Shared, readable service windows; compatible with the 3.3.5 frame API.
UnBotServiceUI = UnBotServiceUI or {};

function UnBotServiceUI.Text(parent, size, width, text)
	local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
	label:SetFont(STANDARD_TEXT_FONT, size);
	label:SetWidth(width);
	label:SetJustifyH("LEFT");
	label:SetJustifyV("TOP");
	label:SetSpacing(4);
	label:SetText(text or "");
	return label;
end

function UnBotServiceUI.Panel(parent, width, height)
	local panel = CreateFrame("Frame", nil, parent);
	panel:SetWidth(width);
	panel:SetHeight(height);
	panel:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = false, edgeSize = 12, insets = {left=3, right=3, top=3, bottom=3}});
	panel:SetBackdropColor(0.035, 0.045, 0.06, 1);
	panel:SetBackdropBorderColor(0.45, 0.4, 0.28, 1);
	return panel;
end

function UnBotServiceUI.Button(parent, width, text, action)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate");
	button:SetWidth(width);
	button:SetHeight(36);
	button:SetText(text);
	button:GetFontString():SetFont(STANDARD_TEXT_FONT, 17);
	button:SetScript("OnClick", action);
	return button;
end

function UnBotServiceUI.Window(name, title, height)
	local frame = CreateFrame("Frame", name, UIParent);
	frame:Hide();
	frame:SetWidth(1020);
	frame:SetHeight(height);
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0);
	frame:SetScale(math.min(1, (UIParent:GetWidth()-32)/1020, (UIParent:GetHeight()-32)/height));
	frame:SetFrameStrata("DIALOG");
	frame:SetClampedToScreen(true);
	frame:SetMovable(true);
	frame:EnableMouse(true);
	frame:RegisterForDrag("LeftButton");
	frame:SetScript("OnDragStart", function(self) self:StartMoving(); end);
	frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); end);
	frame:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = false, edgeSize = 32, insets = {left=11, right=12, top=12, bottom=11}});
	frame:SetBackdropColor(0.055, 0.045, 0.035, 1);
	frame.title = UnBotServiceUI.Text(frame, 25, 900, title);
	frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 32, -22);
	frame.title:SetTextColor(1, 0.82, 0);
	frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton");
	frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8);
	frame.close:SetScript("OnClick", function() frame:Hide(); end);
	if (UISpecialFrames) then table.insert(UISpecialFrames, name); end
	return frame;
end

UnBotLootControl = UnBotLootControl or { sent = {}, observed = {}, offset = 0, status = "Выберите разрешения в списке и нажмите «Применить настройки»." };

function UnBotLootControl.Entry(name)
	if (not UnBotAccountAlts) then return nil; end
	if (UnBotAltStrategies and UnBotAltStrategies.Entry) then return UnBotAltStrategies.Entry(name); end
	local resolved = UnBotAccountAlts.ResolveName(name, true);
	local entry = resolved and UnBotAccountAlts.EnsureStorage().characters[resolved];
	if (UnBotAccountAlts.IsBoundToCurrentAccount(name) and type(entry) == "table" and entry.discoverySource == "bot-list") then return entry; end
	if (UnBotAccountAlts.LinkedCharacter) then
		local linked, accountKey = UnBotAccountAlts.LinkedCharacter(name);
		if (linked) then return linked, linked.name, accountKey; end
	end
end

function UnBotLootControl.Allowed(name)
	local entry = UnBotLootControl.Entry(name);
	return entry and entry.allowLoot == true or false;
end

function UnBotLootControl.Roster()
	local rows = {};
	local raid = (GetNumRaidMembers() or 0) > 0;
	local count = raid and GetNumRaidMembers() or GetNumPartyMembers();
	for index = 1, (count or 0) do
		local unit = (raid and "raid" or "party")..index;
		local name = UnitName(unit);
		if (name and name ~= UNKNOWNOBJECT and name ~= UNKNOWN and not UnitIsUnit(unit, "player")) then
			local profile = UnBotBotRegistry and UnBotBotRegistry.bots and UnBotBotRegistry.bots[name];
			profile = type(profile) == "table" and profile or nil;
			local alt = UnBotIsAccountAltProfile and UnBotIsAccountAltProfile(name, profile);
			local entry, resolved, linkedAccountKey = UnBotLootControl.Entry(name);
			table.insert(rows, {name=name, unit=unit, online=UnitIsConnected(unit) and true or false,
				kind=alt and "alt" or (profile and "wild" or "unknown"), editable=alt and entry ~= nil, linkedAccountKey=linkedAccountKey});
		end
	end
	table.sort(rows, function(a,b) return a.name < b.name; end);
	return rows;
end

function UnBotLootControl.Find(name)
	for _, row in ipairs(UnBotLootControl.Roster()) do
		if (row.name == name) then return row; end
	end
end

function UnBotLootControl.SetStatus(text)
	UnBotLootControl.status = text;
	if (UnBotBotCenterMessage) then UnBotBotCenterMessage(text); end
	UnBotLootControl.Refresh();
end

function UnBotLootControl.MethodResult(text)
	UnBotLootControl.awaitingMethod = false;
	UnBotLootControl.SetStatus(text);
end

-- Used both by this window and by the existing account-character summon path.
function UnBotLootControl.Send(name)
	local row = UnBotLootControl.Find(name);
	if (not row or row.kind ~= "alt" or not row.editable or not row.online) then return false; end
	local allowed = UnBotLootControl.Allowed(name);
	if UnBotAltStrategies then
		UnBotAltStrategies.SetLootChoice(name,allowed);
		local entry=UnBotAltStrategies.Entry(name);
		local profile=entry and entry.strategyProfile;
		if not profile then return false; end
		return UnBotAltStrategies.Enqueue(name,"apply",{co={loot=allowed},nc={loot=allowed},revision=profile.revision});
	end
	SendChatMessage("co "..(allowed and "+" or "-").."loot", "WHISPER", nil, name);
	SendChatMessage("nc "..(allowed and "+" or "-").."loot", "WHISPER", nil, name);
	UnBotLootControl.sent[name] = {allowed=allowed, at=GetTime()};
	UnBotLootControl.observed[name] = nil;
	if (UnBotLootControl.query and UnBotLootControl.query.name == name) then UnBotLootControl.query = nil; end
	return true;
end

function UnBotLootControl.Choose(name, allowed)
	local row = UnBotLootControl.Find(name);
	local entry = row and row.editable and UnBotLootControl.Entry(name);
	if (not entry) then return; end
	entry.allowLoot = allowed and true or false;
	if UnBotAltStrategies then UnBotAltStrategies.SetLootChoice(name,entry.allowLoot); end
	UnBotLootControl.SetStatus(name..": выбор сохранён. Нажмите «Применить настройки»; при следующем призыве он применяется автоматически.");
end

function UnBotLootControl.Apply()
	if UnBotAltStrategies and (UnBotAltStrategies.active or #UnBotAltStrategies.queue>0) then
		UnBotLootControl.SetStatus("Дождитесь завершения сверки стратегий или остановите её в редакторе."); return;
	end
	if ((InCombatLockdown and InCombatLockdown()) or UnitAffectingCombat("player")) then
		UnBotLootControl.SetStatus("Дождитесь окончания боя, затем примените настройки."); return;
	end
	local count, wild, unknown = 0, 0, 0;
	for _, row in ipairs(UnBotLootControl.Roster()) do
		if (row.online) then
			if (row.kind == "alt" and UnBotLootControl.Send(row.name)) then count = count + 1;
			elseif (row.kind == "wild") then wild = wild + 1;
			elseif (row.kind == "unknown") then unknown = unknown + 1; end
		end
	end
	if (count + wild == 0) then
		UnBotLootControl.SetStatus("В группе нет доступных ботов. Для отключённых персонажей выбор сохранён до следующего призыва."); return;
	end
	if (unknown > 0) then
		UnBotLootControl.SetStatus("Команды своим персонажам отправлены: "..count..". В группе есть неизвестные участники; способ добычи выберите вручную."); return;
	end
	UnBotAltLootAutomationArm("настройки добычи", false);
	UnBotLootControl.awaitingMethod = true;
	UnBotLootControl.SetStatus("Команды своим персонажам отправлены: "..count..". Проверяем способ добычи. Ответ выбранного персонажа можно запросить кнопкой «Проверить».");
end

function UnBotLootControl.Query(name)
	local row = UnBotLootControl.Find(name);
	if (UnBotLootControl.query or not row or not row.online or not row.editable) then return; end
	if UnBotAltStrategies then
		if UnBotAltStrategies.Enqueue(name,"inspect") then
			UnBotLootControl.observed[name]=nil;
			UnBotLootControl.SetStatus(name..": запрос текущих стратегий поставлен в очередь с паузами.");
		end
		return;
	end
	UnBotLootControl.observed[name] = nil;
	UnBotLootControl.query = {name=name, mode="nc", deadline=GetTime()+6, startedAt=GetTime()};
	SendChatMessage("nc ?", "WHISPER", nil, name);
	UnBotLootControl.SetStatus(name..": ждём ответ о сборе добычи, до 12 секунд.");
end

function UnBotLootControl.Reply(message, sender)
	local q = UnBotLootControl.query;
	if (not q or GetTime() > q.deadline or UnBotAccountAlts.SenderKey(sender) ~= UnBotAccountAlts.SenderKey(q.name)) then return; end
	local row = UnBotLootControl.Find(q.name);
	if (not row or not row.online or not row.editable) then UnBotLootControl.query = nil; return; end
	local text = tostring(message or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "");
	local list = text:match("^[Ss]trategies:%s*(.*)$");
	if (list == nil) then return; end
	local allowed = false;
	for token in list:gmatch("([^,]+)") do
		if (token:match("^%s*(.-)%s*$") == "loot") then allowed = true; end
	end
	q[q.mode] = allowed;
	if (q.mode == "nc") then
		q.mode = "co"; q.deadline = GetTime()+6;
		SendChatMessage("co ?", "WHISPER", nil, q.name);
	else
		UnBotLootControl.observed[q.name] = {nc=q.nc, co=q.co, at=GetTime()};
		UnBotLootControl.query = nil;
		UnBotLootControl.SetStatus(q.name..": ответ получен. Вне боя сбор "..(q.nc and "включён" or "выключен")..", в бою "..(q.co and "включён" or "выключен")..".");
	end
end

function UnBotLootControl.MethodText()
	local method = GetLootMethod and GetLootMethod();
	local labels = {freeforall="Каждый за себя", master="Ответственный за добычу", group="Групповая добыча", roundrobin="По очереди", needbeforegreed="Приоритет по нужности"};
	local text = "Сейчас: "..(labels[method] or "нет группы");
	if (method == "master") then
		text = text..(UnBotGunshipMasterLootPlayerIsMaster() and " — вы" or " — другой участник");
		local threshold = GetLootThreshold and GetLootThreshold();
		local quality = {[0]="серых", [1]="белых", [2]="зелёных", [3]="синих", [4]="фиолетовых", [5]="легендарных"};
		text = text..", от "..(quality[threshold] or "неизвестного качества");
	end
	return text;
end

function UnBotLootControl.RowStatus(row)
	if (not row.online) then return "Не в сети — не собирает"; end
	if (row.kind == "unknown") then return "UnBot не управляет"; end
	if (row.kind == "wild") then
		if (UnBotGunshipMasterLootPlayerIsMaster() and GetLootThreshold and GetLootThreshold() == 2) then
			return "Может брать серое и белое";
		end
		return "Может брать по правилам группы";
	end
	if (not row.editable) then return "Нужно подтвердить аккаунт альта"; end
	local seen = UnBotLootControl.observed[row.name];
	if (seen) then
		if (seen.nc ~= seen.co) then return "Ответ: в бою и вне боя по-разному"; end
		return seen.nc and "Ответ: сбор включён" or "Ответ: сбор выключен";
	end
	local sent = UnBotLootControl.sent[row.name];
	if (sent) then return sent.allowed and "Разрешение отправлено" or "Запрет отправлен"; end
	return "Не проверено";
end

-- Loot choices belong to the personal co/nc editor. Legacy command helpers
-- remain available, but opening this window is informational only.
function UnBotLootControl.Refresh()
	local frame = UnBotLootControl.frame;
	if (frame and frame:IsShown()) then frame.method:SetText(UnBotLootControl.MethodText()); end
end

function UnBotLootControl.Open()
	local state = UnBotLootControl;
	if (not state.frame) then
		local frame = UnBotServiceUI.Window("UnBotLootControlWindow", "Справка по луту", 720);
		state.frame = frame;
		frame:SetFrameStrata("FULLSCREEN_DIALOG");
		frame.method = UnBotServiceUI.Text(frame, 18, 948);
		frame.method:SetPoint("TOPLEFT", frame, "TOPLEFT", 36, -64);
		frame.method:SetTextColor(0.35, 0.95, 1);
		frame.help = UnBotServiceUI.Text(frame, 18, 948,
			"|cffffd100Как включить сбор у альта|r\nВ редакторе стратегий справа, в «НЕБОЕВЫЕ СТРАТЕГИИ (nc)», найдите «Поднимать добычу» и выберите «Включить» (nc +loot). Чтобы запретить сбор — «Выключить» (nc -loot).\n\n"
			.."|cffffd100Лут в бою настраивается отдельно|r\nТа же строка слева управляет co +loot / co -loot — сбором в боевом режиме. Для полного запрета выключите loot в обеих половинах. «По умолчанию» снимает личное указание и не означает запрет.\n\n"
			.."|cffffd100Сохранение и применение|r\nВключите «При призыве применять мои настройки» и нажмите «Применить и проверить» для онлайн-альта вне боя. «Сохранить» запоминает профиль для следующего призыва. Настройки личные: для каждого своего или связанного альта отдельно. Без личного профиля сохраняется поведение сервера.\n\n"
			.."|cffffd100Правила группы и случайные боты|r\nUnBot включает «Каждый за себя» для группы только из ваших и связанных альтов. Со случайными ботами назначает вас ответственным за зелёные и более ценные предметы; серые и белые вещи они всё ещё могут забрать. Для смены правил нужны права лидера и окончание боя. Временный баффер тоже влияет на правила группы.\n\n"
			.."|cffffd100Квестовый лут на этом сервере|r\nПо установленным правилам сервера предметы и убийства засчитываются альтам вместе с вами при сдаче задания; им не обязательно собирать предметы самим. Чтобы нужный предмет выпал вам, ударьте противника первым. Оставьте альтам место в сумках для награды. Сообщение «Задание не выполнено» до сдачи допустимо: итог определяется при разговоре с выдающим награду NPC.");
		frame.help:SetPoint("TOPLEFT", frame, "TOPLEFT", 36, -104);
		local close = UnBotServiceUI.Button(frame, 180, "Закрыть", function() frame:Hide(); end);
		close:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -36, 22);
		frame:SetScript("OnShow", function() UnBotLootControl.Refresh(); end);
	end
	state.frame:Show(); state.frame:Raise(); UnBotLootControl.Refresh();
end

UnBotLootControl.driver = CreateFrame("Frame");
UnBotLootControl.driver:RegisterEvent("CHAT_MSG_WHISPER");
UnBotLootControl.driver:RegisterEvent("PARTY_MEMBERS_CHANGED");
UnBotLootControl.driver:RegisterEvent("RAID_ROSTER_UPDATE");
UnBotLootControl.driver:SetScript("OnEvent", function(self, event, message, sender)
	if (event == "CHAT_MSG_WHISPER") then UnBotLootControl.Reply(message, sender);
	else
		-- A reconnect or a changed group invalidates an old observation.
		UnBotLootControl.observed = {}; UnBotLootControl.sent = {}; UnBotLootControl.query = nil;
		UnBotLootControl.Refresh();
	end
end);
UnBotLootControl.driver:SetScript("OnUpdate", function(self, elapsed)
	self.elapsed = (self.elapsed or 0)+elapsed;
	if (self.elapsed < 0.5) then return; end
	self.elapsed = 0;
	local q = UnBotLootControl.query;
	if (q and GetTime() >= q.deadline) then
		UnBotLootControl.query = nil;
		UnBotLootControl.SetStatus(q.name..": ответ не получен. Фактическое разрешение неизвестно; автоматического повтора нет.");
	end
	UnBotLootControl.Refresh();
end);

SLASH_UNBOTLOOT1 = "/ubloot";
SlashCmdList["UNBOTLOOT"] = function() UnBotLootControl.Open(); end;


-- Combat chat only changes presentation. It never sends or rewrites commands.
-- Keep the routing API for existing callers, but use the main UnBot tab.
UnBotCombatChat = {name = UnBotChatWindowName, pending = {}, recent = {}, patterns = {}, attempts = 0};

function UnBotCombatChat.Clean(text)
    return tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        :gsub("|H.-|h(.-)|h", "%1"):gsub("^%s+", ""):gsub("%s+$", "");
end

function UnBotCombatChat.Command(text)
    text = UnBotCombatChat.Clean(text):lower();
    -- Playerbot role/class selectors may be chained.
    for i = 1, 8 do
        if not text:match("^@%S+%s+") then break end
        text = text:gsub("^@%S+%s+", "", 1);
    end
    local verb = text:match("^(%S+)");
    if text == "reset botai" then return true end
    return verb and ({co=true, nc=true, de=true, rt=true, rti=true, rtsc=true, cc=true,
        attack=true, pull=true, flee=true, follow=true, stay=true, guard=true,
        formation=true, cast=true, spell=true, ["do"]=true, assist=true,
        tank=true, grind=true, endpull=true})[verb] or false;
end

function UnBotCombatChat.IsNotice(text)
    text = UnBotCombatChat.Clean(text);
    -- Only our own notices pass here; never classify ordinary player speech.
    for _, prefix in ipairs({"Синдрагоса", "Ребрад", "Лорд Ребрад", "Саурфанг",
        "Свална", "Сестра Свална", "Валитрия", "Гниломорд", "Тухлопуз",
        "Мерзоцид", "Профессор Мерзоцид", "Принцы крови", "Лана'тель",
        "Ланатель", "Лич:", "Король-лич", "Леди Смертный Шёпот", "Смертный Шёпот"}) do
        if text:sub(1, #prefix) == prefix then return true end
    end
    return false;
end

function UnBotCombatChat.BuildMarkPatterns()
    -- Use the running client's localized formats, including private-client additions.
    UnBotCombatChat.patterns = {};
    for key, value in pairs(_G) do
        if type(key) == "string" and type(value) == "string"
            and (key:find("RAID_TARGET", 1, true) or key:find("TARGET_ICON", 1, true))
            and (value:find("%%[sd]") or value:find("%%[%d]+%$[sd]")) then
            local pattern = UnBotCombatChat.Clean(value):gsub("%%[%d]+%$", "%%")
                :gsub("%%[sd]", "\001"):gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
                :gsub("\001", ".-");
            table.insert(UnBotCombatChat.patterns, "^"..pattern.."$");
        end
    end
end

function UnBotCombatChat.IsMark(text)
    text = UnBotCombatChat.Clean(text);
    for _, pattern in ipairs(UnBotCombatChat.patterns) do
        if text:match(pattern) then return true end
    end
    local lower = text:lower();
    -- Some servers send custom system text instead of a Blizzard format.
    local icon = lower:find("raidtargetingicon", 1, true) or lower:find("{rt%d}")
        or lower:find("raid target", 1, true) or text:find("рейдов", 1, true);
    -- Chat filters run before Blizzard replaces {triangle}/{cross}/localized tags.
    for tag in text:gmatch("{([^{}]+)}") do
        local key = strlower and strlower(tag) or tag:lower();
        if ICON_TAG_LIST and (ICON_TAG_LIST[tag] or ICON_TAG_LIST[key]) then icon = true; break end
    end
    return icon and (lower:find(" sets ", 1, true) or lower:find(" removes ", 1, true)
        or lower:find(" marked ", 1, true) or lower:find(" cleared ", 1, true)
        or text:find("установ", 1, true) or text:find("назнач", 1, true)
        or text:find("помеч", 1, true) or text:find("снима", 1, true)
        or text:find(" ставит ", 1, true)
        or text:find("снял", 1, true) or text:find("снята", 1, true)) and true or false;
end

function UnBotCombatChat.Sent(message, channel, language, target)
    if channel ~= "WHISPER" or not target or not UnBotChatIsKnownBot(target) then return end
    local history = UnBotCombatChat.recent;
    if #history >= 80 then table.remove(history, 1) end
    local text = UnBotCombatChat.Clean(message):lower();
    table.insert(history, {name=UnBotChatNormalizeName(target), time=GetTime(),
        combat=UnBotCombatChat.Command(message), query=text == "co ?" or text == "nc ?" or text == "de ?"});
end

function UnBotCombatChat.Recent(name)
    name = UnBotChatNormalizeName(name);
    for i = #UnBotCombatChat.recent, 1, -1 do
        local entry = UnBotCombatChat.recent[i];
        if GetTime() - entry.time > 10 then break end
        if entry.name == name then return entry end
    end
end

function UnBotCombatChat.IsReply(text, author)
    local recent = UnBotCombatChat.Recent(author);
    text = UnBotCombatChat.Clean(text):lower();
    if text:match("strategies?%s*:") or text:match("^combat strategies")
        or text:match("^non%-combat strategies") or text:match("^rti[%s:]")
        or text:match("^rtsc[%s:]") or text:match("^raid target")
        or text:match("^casting ") or text:match("^cast:")
        or text:match("^cannot cast ") or text:match("^unknown spell")
        or text:match("^spell cast failed") or text:match("^do:%s*icc ") then return true end
    -- Strategy queries return a bare comma-separated list on this server.
    if recent and recent.combat then
        if recent.query and text:match("^[%w%s,_%+%-]+$") then return true end
        if text:match("^do:") or text:match("^spell cast failed")
            or text:match("^unknown spell") or text:match("^cannot cast")
            or text:match("^no items") or text == "ok" then return true end
    end
    return false;
end

function UnBotCombatChat.IsMessage(event, message, author)
    if (event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_WHISPER_INFORM")
        and UnBotChatIsKnownBot(author, true) then return false end
    if event == "CHAT_MSG_MONSTER_YELL" then return UnBotCombatChat.IsNotice(author) end
    if event == "CHAT_MSG_SYSTEM" then
        return UnBotCombatChat.IsMark(message) or UnBotCombatChat.IsBotSystem(message);
    end
    if event == "CHAT_MSG_WHISPER" then
        -- Preserve the dedicated chest/debug conversation during a chest job.
        local chest = UnBotGroundChest;
        if chest and chest.active and UnBotChatNormalizeName(chest.currentName) == UnBotChatNormalizeName(author) then return false end
        return UnBotChatIsKnownBot(author) and UnBotCombatChat.IsReply(message, author);
    elseif event == "CHAT_MSG_WHISPER_INFORM" then
        return UnBotChatIsKnownBot(author) and UnBotCombatChat.Command(message);
    elseif event == "CHAT_MSG_SAY" or event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER"
        or event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER" then
        if UnBotChatNormalizeName(author) == UnBotChatNormalizeName(UnitName("player")) then
            return UnBotCombatChat.Command(message);
        end
        return UnBotChatIsKnownBot(author) and UnBotCombatChat.IsReply(message, author);
    end
    return false;
end

function UnBotCombatChat.IsBotSystem(message)
    if UnBotChatKeepAutoBalanceSystem(message) then return false end
    local text = UnBotCombatChat.Clean(message);
    local name = text:match("^([^%s]+) умирает%.$")
        or text:match("^([^%s]+) dies%.$")
        or text:match("^([^%s]+) присоединяется к рейдовой группе%.$")
        or text:match("^([^%s]+) покидает рейдовую группу%.$")
        or text:match("^([^%s]+) присоединяется к группе%.$")
        or text:match("^([^%s]+) покидает группу%.$")
        or text:match("^([^%s]+) has joined the raid group%.$")
        or text:match("^([^%s]+) has left the raid group%.$")
        or text:match("^([^%s]+) joins the party%.$")
        or text:match("^([^%s]+) leaves the party%.$");
    if name then return UnBotChatIsKnownBot(name) end
    name = text:match("^[Rr]emove:%s*([^%s]+)%s*%-%s*player is offline%.?$");
    if name then return true end -- An explicit Playerbot removal result.
    name = text:match("^([^%s:]+):%s*[Cc]annot cast%s")
        or text:match("^([^%s:]+):%s*[Cc]asting%s")
        or text:match("^([^%s:]+):%s*[Uu]nknown spell%s");
    return name and UnBotChatIsKnownBot(name) or false;
end

function UnBotCombatChat.Find()
    for i = 1, (NUM_CHAT_WINDOWS or 0) do
        local tab = _G["ChatFrame"..i.."Tab"];
        if tab and tab:GetText() == UnBotCombatChat.name then return _G["ChatFrame"..i] end
    end
end

function UnBotCombatChat.Ensure(manual)
    if not UnBotChatCanCreate then return nil end
    local frame = UnBotCombatChat.Find();
    if not frame
        and (manual or (UnBotCombatChat.attempts < 3 and GetTime() >= (UnBotCombatChat.retryAt or 0))) then
        UnBotCombatChat.attempts = UnBotCombatChat.attempts + 1;
        UnBotCombatChat.retryAt = GetTime() + 10;
        if FCF_OpenNewWindow then pcall(FCF_OpenNewWindow, UnBotCombatChat.name) end
        frame = UnBotCombatChat.Find(); -- recover a partially created window too
    end
    if frame then
        UnBotChatPrepareFrame(frame);
        UnBotChatDockFrame(frame);
        UnBotChatFlushPending(frame);
        for _, line in ipairs(UnBotCombatChat.pending) do frame:AddMessage(line) end
        UnBotCombatChat.pending = {};
        UnBotCombatChat.warned = false;
    end
    return frame;
end

function UnBotCombatChat.Write(text)
    local frame = UnBotCombatChat.Ensure();
    if frame then frame:AddMessage(tostring(text)); return end
    if #UnBotCombatChat.pending >= 500 then table.remove(UnBotCombatChat.pending, 1) end
    table.insert(UnBotCombatChat.pending, tostring(text));
    if UnBotChatCanCreate and not UnBotCombatChat.warned then
        UnBotCombatChat.warned = true;
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffaa00UnBot: вкладка недоступна. Последние 500 боевых строк хранятся в памяти; освободите окно чата и выполните /ubcombat.|r") end
    end
end

function UnBotCombatChat.WriteEvent(event, message, author)
    local prefix = "|cffaaaaaaКоманда:|r ";
    if event == "CHAT_MSG_MONSTER_YELL" then prefix = "|cffff5555"..tostring(author)..":|r "
    elseif event == "CHAT_MSG_WHISPER" or (event ~= "CHAT_MSG_SYSTEM"
        and event ~= "CHAT_MSG_WHISPER_INFORM" and UnBotChatIsKnownBot(author)) then
        prefix = "|cffff80ff<"..tostring(author)..">|r "
    elseif event == "CHAT_MSG_WHISPER_INFORM" then prefix = "|cffaaaaff-> "..tostring(author)..":|r "
    elseif event == "CHAT_MSG_SYSTEM" then
        prefix = UnBotCombatChat.IsMark(message) and "|cffffff00Метки:|r " or "|cffffff00Боты:|r ";
        if UnBotCombatChat.IsMark(message) then
            message = tostring(message):gsub("{([^{}]+)}", function(tag)
                local key = strlower and strlower(tag) or tag:lower();
                local index = ICON_TAG_LIST and (ICON_TAG_LIST[tag] or ICON_TAG_LIST[key]);
                if index and ICON_LIST and ICON_LIST[index] then
                    return ICON_LIST[index].."0|t";
                end
                return "{"..tag.."}";
            end);
        end
    end
    UnBotCombatChat.Write(prefix..tostring(message));
end

function UnBotCombatChat.IsDBMChatRoutingEnabled()
    local c = UnBotSquadConfig and UnBotSquadConfig.chatRouting;
    return type(c) == "table" and c.interceptDBM == true;
end

function UnBotCombatChat.InstallDBMChatRouting()
    -- DBM caches its AddMsg function and writes straight to AddMessage.
    -- Chain the existing methods (including timestamp addons); no DBM settings change.
    for i = 1, (NUM_CHAT_WINDOWS or 0) do
        local frame = _G["ChatFrame"..i];
        if frame and frame.AddMessage and not frame.UnBotCombatDBMRouted then
            local original = frame.AddMessage;
            frame.UnBotCombatDBMRouted = true;
            frame.AddMessage = function(self, text, ...)
                -- Preserve DBM output and all arguments unless the player opts in.
                if type(text) == "string" and text:find("|cffff7d0a<|r|cffffd200", 1, true)
                    and not UnBotCombatChat.IsDBMChatRoutingEnabled() then
                    return original(self, text, ...);
                end
                -- Some marker notices reach AddMessage without passing chat filters.
                -- Match the rendered notice, not ordinary player speech about marks.
                if self ~= UnBotCombatChat.Find() and type(text) == "string" then
                    local clean = UnBotCombatChat.Clean(text):gsub("^%[%d%d:%d%d:%d%d%]%s*", "");
                    if clean:match("^%[[^%]]+%] ставит .+ на .+") and UnBotCombatChat.IsMark(clean) then
                        local now = GetTime();
                        if UnBotCombatChat.directMark ~= clean or now - (UnBotCombatChat.directMarkTime or 0) > 0.02 then
                            UnBotCombatChat.directMark = clean;
                            UnBotCombatChat.directMarkTime = now;
                            UnBotCombatChat.Write(text);
                        end
                        return;
                    end
                end
                if self ~= UnBotCombatChat.Find() and type(text) == "string"
                    and text:find("|cffff7d0a<|r|cffffd200", 1, true) then
                    UnBotCombatChat.Write(text);
                    return;
                end
                return original(self, text, ...);
            end;
        end
    end
end

function UnBotCombatChat.Start()
    UnBotCombatChat.BuildMarkPatterns();
    UnBotCombatChat.Write("|cffffcc66UnBot: боевые и служебные сообщения собраны в этой вкладке. Открыть: /ubchat.|r");
    UnBotCombatChat.InstallDBMChatRouting();
end

SLASH_UNBOTCOMBATCHAT1 = "/ubcombat";
SlashCmdList["UNBOTCOMBATCHAT"] = function()
    local frame = UnBotCombatChat.Ensure(true);
    if not frame then
        UnBotCombatChat.warned = false;
        UnBotCombatChat.Write("|cffffcc66UnBot: ожидаю открытия вкладки.|r");
        return;
    end
    if FCF_SelectDockFrame and UnBotChatFrameIsDocked(frame) then FCF_SelectDockFrame(frame)
    else frame:Show() end
end;

if hooksecurefunc then hooksecurefunc("SendChatMessage", UnBotCombatChat.Sent) end

-- Debug routing is display-only. GroundChest listens to the raw whisper event.
function UnBotDebugChatIsMessage(event, message, author)
    if event ~= "CHAT_MSG_WHISPER" then return false end
    local state = UnBotGroundChest
    local selected = state and state.currentName and UnBotAccountAlts.SenderKey(author) == UnBotAccountAlts.SenderKey(state.currentName)
    if selected and state.active then return true end
    if not selected and not UnBotChatIsKnownBot(author) then return false end
    local text = tostring(message or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower()
    return text:find("spell cast failed", 1, true) ~= nil
        or text:match("^do:%s") ~= nil or text:match("^debug") ~= nil
end

function UnBotDebugChatWrite(text)
    UnBotDebugChatPending = UnBotDebugChatPending or {}
    local frame
    if UnBotChatCanCreate then
        for i=1,(NUM_CHAT_WINDOWS or 0) do
            local tab = _G["ChatFrame"..i.."Tab"]
            if tab and tab:GetText() == "UnBot Debug" then frame = _G["ChatFrame"..i]; break end
        end
        if not frame and GetTime() >= (UnBotDebugChatRetryAt or 0) then
            UnBotDebugChatRetryAt = GetTime()+10
            if FCF_OpenNewWindow then pcall(FCF_OpenNewWindow, "UnBot Debug") end
            for i=1,(NUM_CHAT_WINDOWS or 0) do
                local tab = _G["ChatFrame"..i.."Tab"]
                if tab and tab:GetText() == "UnBot Debug" then frame = _G["ChatFrame"..i]; break end
            end
        end
    end
    if frame then
        UnBotChatPrepareFrame(frame)
        UnBotChatDockFrame(frame)
        local tab = _G[frame:GetName().."Tab"]
        if tab then tab:Show() end
        for _,line in ipairs(UnBotDebugChatPending) do frame:AddMessage(line) end
        UnBotDebugChatPending = {}
        frame:AddMessage(text)
    else
        if #UnBotDebugChatPending >= 500 then table.remove(UnBotDebugChatPending,1) end
        table.insert(UnBotDebugChatPending,text)
        if not UnBotDebugChatWarned then
            UnBotDebugChatWarned = true
            UnBotChatWrite("UnBot Debug: нет свободного окна чата; последние 500 строк временно хранятся в памяти. Освободите окно; создание повторится при следующем сообщении.")
        end
    end
end


-- BEGIN SQUAD LOOT SETTINGS
-- Explicit squad loot choices. /p commands address the whole current group/raid.
UnBotSquadLoot = UnBotSquadLoot or {};
do
local S = UnBotSquadLoot;
S.modes = {
 {key="keep", text="Не менять режим", command="", hint="Оставить серверный выбор"},
 {key="all", text="Всё", command="ll all", hint="Все предметы"},
 {key="normal", text="Кроме BOP", command="ll normal", hint="Без привязки при получении"},
 {key="gray", text="Только серые", command="ll gray", hint="Только серые предметы"},
 {key="quest", text="Только квестовые", command="ll quest", hint="Предметы заданий"},
 {key="skill", text="По профессиям", command="ll skill", hint="Травы, руда, снятие шкур"},
};
function S.Config()
 UnBotSquadConfig = UnBotSquadConfig or {};
 if type(UnBotSquadConfig.squadLoot) ~= "table" then UnBotSquadConfig.squadLoot = {}; end
 return UnBotSquadConfig.squadLoot;
end
function S.Message(text)
 S.status = text;
 if UnBotSpecSummonMessage then UnBotSpecSummonMessage("Настройки лута: "..text); end
 S.Refresh();
end
function S.Mode(key)
 for _, mode in ipairs(S.modes) do if mode.key == key then return mode; end end
 return S.modes[1];
end
function S.Items(text)
 local commands = {};
 for line in tostring(text or ""):gmatch("[^\r\n]+") do
  line = line:match("^%s*(.-)%s*$");
  if line ~= "" then
   local sign, item = line:match("^([+-])%s*(.+)$");
   item = (item or line):match("^%s*(.-)%s*$");
   if item:find("[%c]") or item:find(";",1,true) or item:sub(1,1)=="/" or #item > 245
    or item:sub(1,1)=="-" or item:sub(1,1)=="+" or item:match("^ll%s") then
    return nil, "Некорректная строка предмета. Используйте ID, название или ссылку; перед исключением поставьте минус.";
   end
   if item == "all" or item == "normal" or item == "gray" or item == "quest" or item == "skill" then
    return nil, "Режимы ll выбираются кнопками, а в поле указываются предметы.";
   end
   table.insert(commands,"ll "..(sign == "-" and "-" or "")..item);
   if #commands > 10 then return nil,"Не более 10 предметов за одно применение."; end
  end
 end
 return commands;
end
function S.Busy()
 return (UnBotSpecSummon and UnBotSpecSummon.active)
  or (UnBotSquadBuilder and UnBotSquadBuilder.postSummonSequence)
  or (UnBotSquadSummon and UnBotSquadSummon.active)
  or (UnBotPVPSummon and UnBotPVPSummon.active)
  or (UnBotBuffCycle and UnBotBuffCycle.active)
  or (UnBotSquadSpecCheck and (UnBotSquadSpecCheck.active or (UnBotSquadSpecCheck.autoStartAt or 0)>0))
  or (UnBotAltStrategies and (UnBotAltStrategies.active or #(UnBotAltStrategies.queue or {})>0));
end
function S.Roster()
 local names, signature = {}, {};
 local raid = (GetNumRaidMembers() or 0)>0;
 local count = raid and GetNumRaidMembers() or GetNumPartyMembers();
 for i=1,(count or 0) do
  local unit=(raid and "raid" or "party")..i;
  if not UnitIsUnit(unit,"player") then
   local name=UnitName(unit);
   if name and name~=UNKNOWN and name~=UNKNOWNOBJECT then
    names[name]=true; table.insert(signature,name..":"..tostring(UnitGUID(unit)));
   end
  end
 end
 table.sort(signature); return names,table.concat(signature,"|");
end
function S.Finish(reason)
 local j = S.job;
 if not j then return; end
 S.job = nil;
 if j.customStart and UnBotSquadCommands then
  UnBotSquadCommands.Result(reason,math.max(0,j.sent-j.customStart+1),j.customCount);
 end
 if j.customOnly then return; end
 local confirmed=0; for _ in pairs(j.confirmed) do confirmed=confirmed+1; end
 S.Message((reason or "Проход завершён")..". Через /p отправлено команд: "..j.sent
  .."; ответов о выбранном режиме: "..confirmed..". "
  ..(j.mismatch and "Есть ответ с другим режимом; проверьте чат." or "Без ответа применение не подтверждено.").." Повторов нет.");
end
function S.Apply(automatic)
 if S.job then if not automatic then S.Message("Применение уже идёт; дождитесь итога или нажмите «Стоп»."); end; return false; end
 if not automatic and S.Busy() then S.Message("Сначала завершите сборку состава и текущие операции UnBot."); return false; end
 local c = S.Config();
 local items, err = S.Items(c.items);
 if not items then S.Message(err); return false; end
 local mode, commands = S.Mode(c.mode), {};
 if c.enableLoot then table.insert(commands,"nc +loot"); end
 if mode.command~="" then table.insert(commands,mode.command); end
 for _,command in ipairs(items) do table.insert(commands,command); end
 if #commands==0 then S.Message("Выберите режим, включение loot или предметы."); return false; end
 local names, signature = S.Roster();
 if not next(names) then S.Message("Нет группы или рейда для команды /p."); return false; end
 S.job={commands=commands,index=1,sent=0,mode=mode,names=names,signature=signature,confirmed={},
  nextAt=GetTime(),deadline=GetTime()+#commands*0.8+8};
 S.Message("Применяю ко всей группе/рейду через /p: "..(mode.command~="" and mode.command or "выбранные команды")..".");
 return true;
end
function S.Custom(commands)
 if S.job then
  local j=S.job;
  if j.customStart then return false,"Пользовательские команды уже в очереди."; end
  j.customStart=#j.commands+1; j.customCount=#commands;
  for _,command in ipairs(commands) do table.insert(j.commands,command); end
  j.deadline=j.deadline+#commands*0.8+5; j.finishAt=nil;
  return true;
 end
 local names,signature=S.Roster();
 if not next(names) then return false,"Нет группы или рейда для команды /p."; end
 S.job={commands=commands,index=1,sent=0,mode=S.modes[1],names=names,signature=signature,confirmed={},
  customOnly=true,customStart=1,customCount=#commands,nextAt=GetTime(),deadline=GetTime()+#commands*0.8+8};
 return true;
end
function S.Auto()
 if S.Config().autoApply == true then S.Apply(true); end
 if UnBotSquadCommands then UnBotSquadCommands.Auto(); end
end
function S.Tick()
 local j=S.job;
 if not j then return; end
 if S.Busy() then S.Finish("Остановлено: началась другая операция UnBot"); return; end
 local _,signature=S.Roster();
 if signature~=j.signature then S.Finish("Остановлено: изменился состав группы/рейда"); return; end
 if GetTime()>=j.deadline then S.Finish("Истёк общий таймаут"); return; end
 if GetTime()<j.nextAt then return; end
 local command=j.commands[j.index];
 if command then
  j.index=j.index+1; j.sent=j.sent+1; j.nextAt=GetTime()+0.8;
  if command==j.mode.command then j.modeSentAt=GetTime(); end
  -- PARTY is exactly /p, including while the player is in a raid.
  SendChatMessage(command,"PARTY");
 else
  if not j.finishAt then j.finishAt=GetTime()+5; end
  if GetTime()>=j.finishAt then S.Finish(); end
 end
end
function S.Reply(message,sender)
 local j=S.job;
 if not j or j.sent==0 or GetTime()>j.deadline then return; end
 local name=tostring(sender or ""):match("^[^-]+");
 if not j.names[name] then return; end
 local text=tostring(message or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):lower();
 local mode=j.modeSentAt and text:match("loot strategy set to%s+([%a]+)");
 if mode then
  if mode==j.mode.key then j.confirmed[name]=true;
  else j.mismatch=true; S.Message(name..": сервер вернул ll "..mode.." вместо ll "..j.mode.key.."; повтора нет."); end
 elseif text:find("unknown command",1,true) or text:find("not allowed",1,true) or text:find("invalid command",1,true) then
  S.Finish(name..": отказ сервера");
 end
end
function S.Save()
 local f=S.frame; local c=S.Config();
 local items,err=S.Items(f.items:GetText());
 if not items then S.Message(err); return false; end
 c.items=f.items:GetText();
 S.Message("Выбор сохранён. "..(c.autoApply and "Команды /p отправятся после полной сборки состава." or "Для готового состава нажмите «Применить сейчас»."));
 return true;
end
function S.Refresh()
 if UnBotLootSettings and UnBotLootSettings.RefreshBots then UnBotLootSettings.RefreshBots();end
 local f=S.frame;
 if not f or not f:IsShown() then return; end
 local c=S.Config();
 f.auto:SetChecked(c.autoApply==true); f.enable:SetChecked(c.enableLoot==true);
 for _,b in ipairs(f.modes) do b:SetChecked(S.Mode(c.mode).key==b.mode.key); end
 f.status:SetText(S.status or "Выберите настройки. Открытие окна и выбор опций не отправляют команд.");
end
function S.Check(frame,text,x,y,action)
 local b=CreateFrame("CheckButton",nil,frame,"UICheckButtonTemplate");
 b:SetWidth(24); b:SetHeight(24); b:SetPoint("TOPLEFT",frame,"TOPLEFT",x,y);
 b.text=UnBotServiceUI.Text(b,17,870,text); b.text:SetPoint("LEFT",b,"RIGHT",2,0);
 b:SetScript("OnClick",action); return b;
end
function S.Open()
 if UnBotLootSettings then UnBotLootSettings.Show("bots");return;end
 if not S.frame then
  local f=UnBotServiceUI.Window("UnBotSquadLootWindow","Настройки лута",720); S.frame=f;
  f:SetFrameStrata("FULLSCREEN_DIALOG");
  f.auto=S.Check(f,"После полной сборки отправлять выбранные команды через /p всей группе/рейду",34,-66,function(b) S.Config().autoApply=b:GetChecked() and true or false; end);
  f.enable=S.Check(f,"nc +loot — включить сбор вне боя (grind тоже включает сбор)",34,-104,function(b) S.Config().enableLoot=b:GetChecked() and true or false; end);
  f.modes={};
  for i,mode in ipairs(S.modes) do
   local b=S.Check(f,mode.text..(mode.command~="" and (" — /p "..mode.command) or ""),34+((i-1)%2)*480,-166-math.floor((i-1)/2)*52,function(b) S.Config().mode=b.mode.key; S.Refresh(); end);
   b.mode=mode; b.text:SetWidth(420); table.insert(f.modes,b);
   b.hint=UnBotServiceUI.Text(f,15,420,mode.hint); b.hint:SetPoint("TOPLEFT",f,"TOPLEFT",60+((i-1)%2)*480,-192-math.floor((i-1)/2)*52);
  end
  f.itemHelp=UnBotServiceUI.Text(f,17,948,"Предметы: /p ll [item] и /p ll -[item]. Одна строка — ID, название или ссылка; минус исключает. До 10 строк.");
  f.itemHelp:SetPoint("TOPLEFT",f,"TOPLEFT",36,-340);
  f.itemScroll=CreateFrame("ScrollFrame","UnBotSquadLootItemsScroll",f,"UIPanelScrollFrameTemplate");
  f.itemScroll:SetWidth(900); f.itemScroll:SetHeight(96); f.itemScroll:SetPoint("TOPLEFT",f,"TOPLEFT",46,-394);
  f.items=CreateFrame("EditBox",nil,f.itemScroll,"InputBoxTemplate"); f.items:SetMultiLine(true); f.items:SetAutoFocus(false);
  f.items:SetWidth(880); f.items:SetHeight(220); f.items:SetPoint("TOPLEFT",f.itemScroll,"TOPLEFT",0,0);
  f.itemScroll:SetScrollChild(f.items);
  f.itemScroll:EnableMouseWheel(true);
  f.itemScroll:SetScript("OnMouseWheel",function(b,delta) b:SetVerticalScroll(math.max(0,math.min(b:GetVerticalScrollRange() or 0,(b:GetVerticalScroll() or 0)-delta*24))); end);
  f.items:SetScript("OnCursorChanged",function(_,x,y,w,h)
   local top=f.itemScroll:GetVerticalScroll() or 0; local cursor=-y;
   if cursor<top then f.itemScroll:SetVerticalScroll(math.max(0,cursor));
   elseif cursor+h>top+96 then f.itemScroll:SetVerticalScroll(math.min(f.itemScroll:GetVerticalScrollRange() or 0,cursor+h-96)); end
  end);
  f.items:SetFont(STANDARD_TEXT_FONT,17); f.items:SetMaxLetters(2400);
  f.items:SetScript("OnEscapePressed",function(b) b:ClearFocus(); end);
  f.help=UnBotServiceUI.Text(f,16,948,"Выбран один режим ll. Порядок: nc +loot (если выбрано) → режим ll → предметы. Каждая команда один раз отправляется через /p всей текущей группе/рейду, включая своих и диких ботов. Личные профили co/nc и способ групповой добычи не перезаписываются. При смене состава очередь останавливается. Ответы ботов видны в чате; отсутствие ответа не означает успех.");
  f.help:SetPoint("TOPLEFT",f,"TOPLEFT",36,-514);
  f.status=UnBotServiceUI.Text(f,16,948); f.status:SetPoint("TOPLEFT",f,"TOPLEFT",36,-602);
  f.save=UnBotServiceUI.Button(f,170,"Сохранить",function() S.Save(); end); f.save:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",36,22);
  f.apply=UnBotServiceUI.Button(f,260,"Применить сейчас",function() if S.Save() then S.Apply(false); end end); f.apply:SetPoint("LEFT",f.save,"RIGHT",12,0);
  f.stop=UnBotServiceUI.Button(f,130,"Стоп",function() S.Finish("Остановлено игроком"); end); f.stop:SetPoint("LEFT",f.apply,"RIGHT",12,0);
  f.closeButton=UnBotServiceUI.Button(f,170,"Закрыть",function() if S.Save() then f:Hide(); end end); f.closeButton:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-36,22);
  f:SetScript("OnHide",function() if S.Items(f.items:GetText()) then S.Config().items=f.items:GetText(); end; f.items:ClearFocus(); end);
 end
 S.frame.items:SetText(S.Config().items or ""); S.frame:Show(); S.frame:Raise(); S.Refresh();
end
function S.CreateButton(builder)
 if UnBotLootSettings then
  if UnBotSquadCommands then UnBotSquadCommands.CreateButton(builder);end
  return;
 end
 if builder.lootSettingsButton then return; end
 local b=CreateFrame("Button",nil,builder.frame,"UIPanelButtonTemplate");
 b:SetWidth(174); b:SetHeight(22); b:SetPoint("BOTTOMLEFT",builder.frame,"BOTTOMLEFT",284,132);
 b:SetText("Настройки лута"); b:SetScript("OnClick",S.Open); builder.lootSettingsButton=b;
 if UnBotSquadCommands then UnBotSquadCommands.CreateButton(builder); end
end
S.driver=CreateFrame("Frame");
for _,event in ipairs({"CHAT_MSG_WHISPER","CHAT_MSG_PARTY","CHAT_MSG_RAID"}) do S.driver:RegisterEvent(event); end
S.driver:SetScript("OnEvent",function(_,event,message,sender) S.Reply(message,sender); end);
S.driver:SetScript("OnUpdate",function() S.Tick(); end);
SLASH_UNBOTSQUADLOOT1="/ubsquadloot"; SlashCmdList.UNBOTSQUADLOOT=S.Open;
end

-- END SQUAD LOOT SETTINGS

-- BEGIN POST SUMMON COMMANDS
UnBotSquadCommands = UnBotSquadCommands or {};
do
local C=UnBotSquadCommands;
C.example="nc -naxx, co -naxx";
C.cyrillic={["А"]="а",["Б"]="б",["В"]="в",["Г"]="г",["Д"]="д",["Е"]="е",["Ё"]="ё",["Ж"]="ж",["З"]="з",["И"]="и",["Й"]="й",["К"]="к",["Л"]="л",["М"]="м",["Н"]="н",["О"]="о",["П"]="п",["Р"]="р",["С"]="с",["Т"]="т",["У"]="у",["Ф"]="ф",["Х"]="х",["Ц"]="ц",["Ч"]="ч",["Ш"]="ш",["Щ"]="щ",["Ъ"]="ъ",["Ы"]="ы",["Ь"]="ь",["Э"]="э",["Ю"]="ю",["Я"]="я"};
function C.Fold(text)
 text=tostring(text or ""):gsub("[A-Z]",string.lower);
 for upper,lower in pairs(C.cyrillic) do text=text:gsub(upper,lower); end
 return text;
end
function C.Control(text)
 for i=1,#text do local b=text:byte(i);if b<32 or b==127 then return true;end;end
 return false;
end
function C.Length(text)
 local n=0;for i=1,#text do local b=text:byte(i);if b<128 or b>=192 then n=n+1;end;end
 return n;
end
-- Retire only the former built-in bulk-disable preset; keep all personal sets.
C.retiredBulkRaidText="co -naxx, nc -naxx, co -wotlk-os, nc -wotlk-os, co -wotlk-eoe, nc -wotlk-eoe, co -ulduar, nc -ulduar, co -voa, nc -voa, co -icc, nc -icc, co -rs, nc -rs, co -aq20, nc -aq20, co -moltencore, nc -moltencore, co -bwl, nc -bwl, co -karazhan, nc -karazhan, co -gruulslair, nc -gruulslair, co -magtheridon, nc -magtheridon, co -ssc, nc -ssc, co -tempestkeep, nc -tempestkeep, co -hyjal, nc -hyjal, co -blacktemple, nc -blacktemple, co -zulaman, nc -zulaman, co -onyxia, nc -onyxia, co -tbc-mech, nc -tbc-mech, co -tbc-seth, nc -tbc-seth, co -tbc-ac, nc -tbc-ac";
function C.RemoveRetiredRaidPreset(lib)
 if type(lib)~="table" or lib.retiredBulkRaidPresetVersion==1 then return;end
 local removed={};local entries=type(lib.entries)=="table" and lib.entries or {};
 for i=#entries,1,-1 do
  local entry=entries[i];
  if type(entry)=="table" and (entry.builtinKey=="raid:all:off"
   or (entry.name=="Все стратегии/All: выключить" and entry.text==C.retiredBulkRaidText)) then
   if entry.id~=nil then removed[entry.id]=true;end
   table.remove(entries,i);
  end
 end
 local cfg=UnBotSquadConfig and UnBotSquadConfig.postSummonCommands;
 if type(cfg)=="table" then
  if removed[cfg.selectedId] then cfg.selectedId=nil;end
  if cfg.presetName=="Все стратегии/All: выключить" then cfg.presetName=nil;end
  if cfg.text==C.retiredBulkRaidText then cfg.text="";cfg.enabled=false;end
 end
 if type(lib.raidPresetSeeds)=="table" then lib.raidPresetSeeds["all:off"]=true;end
 lib.retiredBulkRaidPresetVersion=1;
end
function C.Config()
 UnBotSquadConfig=UnBotSquadConfig or {};
 if type(UnBotSquadConfig.postSummonCommands)~="table" then UnBotSquadConfig.postSummonCommands={}; end
 C.RemoveRetiredRaidPreset(UnBotSquadConfig.squadCommandPresets);
 return UnBotSquadConfig.postSummonCommands;
end
C.raidStrategies={
 {key="naxx",instance="Наксрамас / Naxxramas",name="Наксрамас/Naxx",aliases="Naxxramas",expansion="Wrath of the Lich King",kind="Рейд",hint=""},
 {key="wotlk-os",instance="Обсидиановое святилище / Obsidian Sanctum",name="Обсидиановое святилище/OS",aliases="Obsidian Sanctum",expansion="Wrath of the Lich King",kind="Рейд",hint="По предоставленной справке: до OS+2; сначала убить Весперона."},
 {key="wotlk-eoe",instance="Око Вечности / Eye of Eternity",name="Око Вечности/EoE",aliases="Eye of Eternity",expansion="Wrath of the Lich King",kind="Рейд",hint=""},
 {key="ulduar",instance="Ульдуар / Ulduar",name="Ульдуар/Ulduar",aliases="Ulduar",expansion="Wrath of the Lich King",kind="Рейд",hint="По предоставленной справке: все боссы, кроме Алгалона."},
 {key="voa",instance="Склеп Аркавона / Vault of Archavon",name="Склеп Аркавона/VoA",aliases="Vault of Archavon",expansion="Wrath of the Lich King",kind="Рейд",hint="По предоставленной справке: до Эмалона."},
 {key="icc",instance="Цитадель Ледяной Короны / Icecrown Citadel",name="ЦЛК/ICC",aliases="Icecrown Citadel Цитадель Ледяной Короны",expansion="Wrath of the Lich King",kind="Рейд",hint=""},
 {key="rs",instance="Рубиновое святилище / Ruby Sanctum",name="Рубиновое святилище/RS",aliases="Ruby Sanctum",expansion="Wrath of the Lich King",kind="Рейд",hint=""},
 {key="aq20",instance="Руины Анкиража / Ruins of Ahn'Qiraj",name="Руины Анкиража/AQ20",aliases="Ruins of Ahn Qiraj Ahn'Qiraj",expansion="Classic",kind="Рейд",hint="По предоставленной справке: стратегия нужна только на Оссириане; остальные боссы проходимы без неё."},
 {key="moltencore",instance="Огненные Недра / Molten Core",name="Огненные Недра/MC",aliases="Molten Core",expansion="Classic",kind="Рейд",hint=""},
 {key="bwl",instance="Логово Крыла Тьмы / Blackwing Lair",name="Логово Крыла Тьмы/BWL",aliases="Blackwing Lair",expansion="Classic",kind="Рейд",hint="По предоставленной справке: ботам даётся эффект плаща из чешуи Ониксии; боты отключают подавляющие устройства и снимают бронзовое поражение на Хромаггусе."},
 {key="karazhan",instance="Каражан / Karazhan",name="Каражан/Karazhan",aliases="Karazhan",expansion="The Burning Crusade",kind="Рейд",hint=""},
 {key="gruulslair",instance="Логово Груула / Gruul's Lair",name="Логово Груула/Gruul",aliases="Gruul's Lair",expansion="The Burning Crusade",kind="Рейд",hint=""},
 {key="magtheridon",instance="Логово Магтеридона / Magtheridon's Lair",name="Логово Магтеридона/Magtheridon",aliases="Magtheridon's Lair",expansion="The Burning Crusade",kind="Рейд",hint=""},
 {key="ssc",instance="Змеиное святилище / Serpentshrine Cavern",name="Змеиное святилище/SSC",aliases="Serpentshrine Cavern",expansion="The Burning Crusade",kind="Рейд",hint=""},
 {key="tempestkeep",instance="Крепость Бурь: Око / Tempest Keep: The Eye",name="Крепость Бурь/TK",aliases="Tempest Keep The Eye",expansion="The Burning Crusade",kind="Рейд",hint=""},
 {key="hyjal",instance="Вершина Хиджала / The Battle for Mount Hyjal",name="Вершина Хиджала/Hyjal",aliases="The Battle for Mount Hyjal",expansion="The Burning Crusade",kind="Рейд",hint=""},
 {key="blacktemple",instance="Чёрный храм / Black Temple",name="Чёрный храм/BT",aliases="Black Temple Черный храм",expansion="The Burning Crusade",kind="Рейд",hint=""},
 {key="zulaman",instance="ЗулАман / Zul'Aman",name="ЗулАман/ZA",aliases="Zul'Aman Зул Аман Зул'Аман",expansion="The Burning Crusade",kind="Рейд",hint=""},
 {key="onyxia",instance="Логово Ониксии / Onyxia's Lair",name="Логово Ониксии/Onyxia",aliases="Onyxia's Lair",expansion="Classic / Wrath of the Lich King",kind="Рейд",hint=""},
 {key="tbc-mech",instance="Крепость Бурь: Механар / Tempest Keep: The Mechanar",name="Механар/Mech",aliases="Tempest Keep The Mechanar",expansion="The Burning Crusade",kind="Подземелье",hint=""},
 {key="tbc-seth",instance="Аукиндон: Сетеккские залы / Auchindoun: Sethekk Halls",name="Сетеккские залы/Sethekk",aliases="Auchindoun Sethekk Halls",expansion="The Burning Crusade",kind="Подземелье",hint=""},
 {key="tbc-ac",instance="Аукиндон: Аукенайские гробницы / Auchindoun: Auchenai Crypts",name="Аукенайские гробницы/AC",aliases="Auchindoun Auchenai Crypts",expansion="The Burning Crusade",kind="Подземелье",hint=""},
};
C.behaviorPresets={
 {key="behavior:manual",name="Ручной/Manual: AoE, уклонение и ЦЛК выкл.",text="co -aoe, co -avoid aoe, co -icc",description="Ручной режим прежней кнопки: отключает AoE, уклонение от зон урона и тактику ЦЛК у всей текущей группы/рейда через /p."},
 {key="behavior:normal",name="Обычный/Normal: AoE, уклонение и ЦЛК вкл.",text="co +aoe, co +avoid aoe, co +icc",description="Обычный режим прежней кнопки: включает AoE, уклонение от зон урона и тактику ЦЛК у всей текущей группы/рейда через /p. Включает все три ключа независимо от прежнего состояния."},
};
function C.SeedRaidPresets(lib)
 if lib.raidPresetsSeedVersion==2 then return;end
 if type(lib.raidPresetSeeds)~="table" then lib.raidPresetSeeds={};end
 local definitions={};
 for _,preset in ipairs(C.behaviorPresets) do
  table.insert(definitions,{key=preset.key,builtinKey=preset.key,name=preset.name,text=preset.text,description=preset.description});
 end
 for _,raid in ipairs(C.raidStrategies) do
  for _,mode in ipairs({{suffix="on",sign="+",label="включить"},{suffix="off",sign="-",label="выключить"}}) do
   local commands={"co "..mode.sign..raid.key,"nc "..mode.sign..raid.key};
   table.insert(definitions,{key=raid.key..":"..mode.suffix,name=raid.name..": "..mode.label,text=table.concat(commands,", "),description="Дополнение: "..raid.expansion.."\n"..raid.kind..": "..raid.instance.."\nКлюч: "..raid.key..(raid.hint~="" and ("\n"..raid.hint) or ""),searchText=raid.aliases.." "..raid.expansion.." "..raid.kind});
  end
 end
 local nextId=tonumber(lib.nextId) or 1;local names={};
 for _,entry in ipairs(lib.entries) do
  if type(entry)=="table" then
   nextId=math.max(nextId,(tonumber(entry.id) or 0)+1);
   if type(entry.name)=="string" then names[C.Fold(entry.name)]=true;end
  end
 end
 local pending=0;
 for _,definition in ipairs(definitions) do
  if not lib.raidPresetSeeds[definition.key] then
   if names[C.Fold(definition.name)] then lib.raidPresetSeeds[definition.key]=true;
   elseif #lib.entries<100 then
    table.insert(lib.entries,{id=nextId,name=definition.name,text=definition.text,description=definition.description,searchText=definition.searchText,
     builtinKey=definition.builtinKey or ("raid:"..definition.key),updatedAt=time and time() or 0});
    names[C.Fold(definition.name)]=true;nextId=nextId+1;lib.raidPresetSeeds[definition.key]=true;
   else pending=pending+1;end
  end
 end
 lib.nextId=nextId;lib.raidPresetsSeedPending=pending;
 if pending==0 then lib.raidPresetsSeedVersion=2;end
end
function C.Library()
 UnBotSquadConfig=UnBotSquadConfig or {};
 if type(UnBotSquadConfig.squadCommandPresets)~="table" then UnBotSquadConfig.squadCommandPresets={}; end
 local lib=UnBotSquadConfig.squadCommandPresets;
 if type(lib.entries)~="table" then lib.entries={}; end
 C.RemoveRetiredRaidPreset(lib);
 C.SeedRaidPresets(lib);
 return lib;
end
function C.Parse(text)
 text=tostring(text or "");
 if #text>16000 then return nil,"Слишком длинная строка: максимум 16000 байт."; end
 local commands={};
 for part in text:gmatch("[^,\r\n]+") do
  part=part:match("^%s*(.-)%s*$");
  if part~="" then
   part=part:gsub("^/p%s+",""):match("^%s*(.-)%s*$");
   if part=="" or part:sub(1,1)=="/" or C.Control(part) then
    return nil,"Нужна команда боту, например nc -naxx. Разделяйте команды запятой или новой строкой.";
   end
   if #part>255 then return nil,"Одна команда длиннее 255 байт: сократите её."; end
   table.insert(commands,part);
   if #commands>50 then return nil,"За один проход допускается до 50 команд."; end
  end
 end
 return commands;
end
function C.Message(text)
 C.status=text;
 if UnBotSpecSummonMessage then UnBotSpecSummonMessage("Команды после призыва: "..text); end
 C.Refresh();
end
function C.Result(reason,sent,total)
 C.Message((reason or "Очередь завершена")..". Через /p отправлено "..sent.."/"..total.." пользовательских команд. Ответы смотрите в чате; повтора нет.");
end
function C.Queue(text,automatic,label)
 local commands,err=C.Parse(text);
 if not commands then C.Message(err); return false; end
 if #commands==0 then if not automatic then C.Message("Введите команды или выберите пресет."); end; return false; end
 if not automatic and (UnBotSquadLoot.Busy() or UnBotSquadLoot.job) then
  C.Message("Сначала завершите сборку и текущую очередь UnBot."); return false;
 end
 local ok,reason=UnBotSquadLoot.Custom(commands);
 if not ok then C.Message(reason); return false; end
 C.Message((label and ("Пресет «"..label.."»: ") or "").."В очередь /p добавлено команд: "..#commands..". Область — вся текущая группа/рейд.");
 return true;
end
function C.Execute(automatic)
 return C.Queue(C.Config().text,automatic);
end
function C.RunPreset(id)
 for _,entry in ipairs(C.Library().entries) do
  if type(entry)=="table" and entry.id==id then
   if type(entry.text)~="string" then C.Message("У пресета нет корректного текста команд.");return false;end
   return C.Queue(entry.text,false,entry.name);
  end
 end
 C.Message("Пресет уже отсутствует в списке. Откройте меню заново.");return false;
end
function C.PresetMenuEntry(entry)
 local id=entry.id;local commands,err=C.Parse(entry.text);
 local preview={"Нажатие отправит команды всей текущей группе/рейду через /p."};
 if type(entry.description)=="string" and entry.description~="" then table.insert(preview,entry.description);end
 for _,command in ipairs(commands or {}) do table.insert(preview,"/p "..command);end
 if err then table.insert(preview,err);end
 table.insert(preview,"Автокоманды после призыва и личные профили не меняются.");
 return {text=entry.name,notCheckable=true,tooltipTitle=entry.name,tooltipText=table.concat(preview,"\n"),tooltipOnButton=true,
  func=function() C.RunPreset(id);end};
end
function C.BehaviorMenu()
 local menu={{text="Настроить пресеты...",notCheckable=true,func=C.Open}};
 local entries=C.Matches("");
 if #entries==0 then table.insert(menu,{text="Нет сохранённых пресетов",notCheckable=true,disabled=true});
 elseif #entries<=10 then
  for _,entry in ipairs(entries) do table.insert(menu,C.PresetMenuEntry(entry));end
 else
  for first=1,#entries,10 do
   local page={};local last=math.min(first+9,#entries);
   for i=first,last do table.insert(page,C.PresetMenuEntry(entries[i]));end
   table.insert(menu,{text="Пресеты "..first.."–"..last,notCheckable=true,hasArrow=true,menuList=page});
  end
 end
 return menu;
end
function C.FindPreset(id)
 for _,entry in ipairs(C.Library().entries) do if type(entry)=="table" and entry.id==id then return entry;end;end
end
function C.QuickSlots()
 local lib=C.Library();
 if type(UnBotSquadConfig.squadCommandMenuSlots)~="table" then UnBotSquadConfig.squadCommandMenuSlots={};end
 local cfg=UnBotSquadConfig.squadCommandMenuSlots;
 if type(cfg.slots)~="table" then cfg.slots={};end
 for i=1,8 do if type(cfg.slots[i])~="table" then cfg.slots[i]={};end;end
 if not cfg.initialized then
  for i,preset in ipairs(C.behaviorPresets) do
   if cfg.slots[i].presetId==nil then
    for _,entry in ipairs(lib.entries) do
     if type(entry)=="table" and (entry.builtinKey==preset.key or C.Fold(entry.name)==C.Fold(preset.name)) then cfg.slots[i].presetId=entry.id;break end
    end
   end
  end
  cfg.initialized=true;
 end
 return cfg.slots;
end
function C.AssignQuickSlot(index,id)
 if type(index)~="number" or index<1 or index>8 or index~=math.floor(index) then return false;end
 if id~=nil and not C.FindPreset(id) then C.Message("Пресет уже удалён. Выберите другой.");return false;end
 C.QuickSlots()[index].presetId=id;
 if C.quickDrafts then C.quickDrafts[index]=nil;end
 C.quickStatus="Слот "..index..(id and ": пресет назначен." or ": очищен.");
 C.RefreshQuickSlots();return true;
end
function C.SelectQuickSlot(index,id)
 if type(index)~="number" or index<1 or index>8 or index~=math.floor(index) then return false;end
 local entry=C.FindPreset(id);
 if not entry then C.quickStatus="Пресет уже удалён. Выберите другой в этой строке.";C.RefreshQuickSlots();return false;end
 C.quickDrafts=C.quickDrafts or {};C.quickDrafts[index]=id;
 C.quickStatus="Слот "..index..": выбран «"..entry.name.."». Нажмите «Назначить» в этой строке.";
 C.RefreshQuickSlots();return true;
end
function C.AssignSelectedQuickSlot(index)
 local slot=C.QuickSlots()[index];
 local id=(C.quickDrafts and C.quickDrafts[index]) or (slot and slot.presetId);
 local entry=C.FindPreset(id);
 if not entry then C.quickStatus="Выберите существующий пресет в этой строке и нажмите «Назначить».";C.RefreshQuickSlots();return false;end
 return C.AssignQuickSlot(index,entry.id);
end
function C.RunQuickSlot(index)
 local slot=C.QuickSlots()[index];local entry=slot and C.FindPreset(slot.presetId);
 if not entry then C.OpenQuickSlots(index);return false;end
 return C.RunPreset(entry.id);
end
function C.QuickSlotMenuEntry(index)
 local slot=C.QuickSlots()[index];local entry=C.FindPreset(slot.presetId);
 local item=entry and C.PresetMenuEntry(entry) or {text="Слот "..index..(slot.presetId and ": пресет удалён — настроить..." or ": назначить пресет..."),notCheckable=true};
 if entry then item.text=index..". "..item.text;end
 item.quickCommandSlot=index;item.func=function() C.RunQuickSlot(index);end;
 return item;
end
function C.QuickSlotPickerEntry(index,entry)
 local id=entry.id;local item=C.PresetMenuEntry(entry);
 item.func=function() C.SelectQuickSlot(index,id);end;
 item.tooltipText=(entry.description or "").."\nВыбрать для этой строки. Затем нажмите «Назначить»; отправка — нажатием слота в меню.";
 return item;
end
function C.ChooseQuickSlot(index,button)
 local entries=C.Matches("");local menu={{text="Слот "..index..": выбрать пресет",isTitle=true,notCheckable=true}};
 if #entries==0 then table.insert(menu,{text="Нет сохранённых пресетов",disabled=true,notCheckable=true});
 elseif #entries<=10 then
  for _,entry in ipairs(entries) do table.insert(menu,C.QuickSlotPickerEntry(index,entry));end
 else
  for first=1,#entries,10 do
   local page={};local last=math.min(first+9,#entries);
   for i=first,last do table.insert(page,C.QuickSlotPickerEntry(index,entries[i]));end
   table.insert(menu,{text="Пресеты "..first.."–"..last,hasArrow=true,notCheckable=true,menuList=page});
  end
 end
 C.quickMenuFrame=C.quickMenuFrame or CreateFrame("Frame","UnBotQuickCommandSlotMenu",UIParent,"UIDropDownMenuTemplate");
 EasyMenu(menu,C.quickMenuFrame,button,0,0,"MENU",2);
end
function C.RefreshQuickSlots()
 local f=C.quickFrame;if not f or not f:IsShown() then return;end
 local slots=C.QuickSlots();
 for i,row in ipairs(f.rows) do
  local draft=C.quickDrafts and C.quickDrafts[i];local id=draft or slots[i].presetId;
  local entry=C.FindPreset(id);row.entry=entry;
  row.choose:SetText(entry and entry.name or (id and "Пресет удалён — выбрать другой..." or "Выбрать пресет..."));
  row.assign:SetText(draft and "Назначить *" or "Назначить");
 end
 f.status:SetText(C.quickStatus or "Выберите пресет в строке и нажмите «Назначить». Назначенные слоты сохраняются сразу.");
end
function C.CreateQuickSlotRow(f,index)
 local y=-96-(index-1)*54;local row={};
 row.label=UnBotServiceUI.Text(f,17,44,tostring(index)..".");row.label:SetPoint("TOPLEFT",f,"TOPLEFT",32,y-8);
 row.choose=UnBotServiceUI.Button(f,530,"",function(button) C.ChooseQuickSlot(index,button);end);row.choose:SetHeight(34);row.choose:SetPoint("TOPLEFT",f,"TOPLEFT",80,y);
 row.choose:GetFontString():SetWidth(510);row.choose:GetFontString():SetHeight(32);row.choose:GetFontString():SetFont(STANDARD_TEXT_FONT,15);
 row.choose:SetScript("OnEnter",function(button) if row.entry and GameTooltip then GameTooltip:SetOwner(button,"ANCHOR_RIGHT");GameTooltip:ClearLines();GameTooltip:AddLine(row.entry.name,1,.82,0,true);GameTooltip:AddLine(row.entry.description or "",1,1,1,true);GameTooltip:Show();end;end);
 row.choose:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide();end;end);
 row.assign=UnBotServiceUI.Button(f,232,"Назначить",function() C.AssignSelectedQuickSlot(index);end);row.assign:SetHeight(34);row.assign:SetPoint("TOPLEFT",f,"TOPLEFT",624,y);
 row.clear=UnBotServiceUI.Button(f,114,"Очистить",function() C.AssignQuickSlot(index,nil);end);row.clear:SetHeight(34);row.clear:SetPoint("TOPLEFT",f,"TOPLEFT",870,y);
 return row;
end
function C.OpenQuickSlots(index)
 if not C.quickFrame then
  local f=UnBotServiceUI.Window("UnBotQuickCommandSlotsWindow","8 слотов в меню «Поведение ботов»",680);C.quickFrame=f;f:SetFrameStrata("FULLSCREEN_DIALOG");
  f.heading=UnBotServiceUI.Text(f,16,948,"Выберите пресет в нужной строке и нажмите «Назначить».");f.heading:SetPoint("TOPLEFT",f,"TOPLEFT",32,-64);
  f.rows={};for i=1,8 do f.rows[i]=C.CreateQuickSlotRow(f,i);end
  f.help=UnBotServiceUI.Text(f,15,948,"Выбор строки подтверждается кнопкой «Назначить». Правка сохранённого пресета обновляет действие слота. Отправка — нажатием слота в меню «Поведение ботов».");f.help:SetPoint("TOPLEFT",f,"TOPLEFT",32,-528);
  f.status=UnBotServiceUI.Text(f,15,948);f.status:SetPoint("TOPLEFT",f,"TOPLEFT",32,-582);f.status:SetHeight(40);
  f.closeButton=UnBotServiceUI.Button(f,170,"Закрыть",function() f:Hide();end);f.closeButton:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-36,20);
  f:SetScript("OnHide",function() C.quickDrafts={};C.quickStatus=nil;end);
 end
 if index then C.quickStatus="Слот "..index..": выберите пресет в этой строке и нажмите «Назначить».";end
 C.quickFrame:Show();C.quickFrame:Raise();C.RefreshQuickSlots();
end
function C.RefreshBehaviorMenu()
 for _,section in ipairs(UnBotToolsMenu or {}) do
  for i,entry in ipairs(section.menuList or {}) do
   if entry.squadCommandPresets then entry.menuList=C.BehaviorMenu();
   elseif entry.quickCommandSlot then section.menuList[i]=C.QuickSlotMenuEntry(entry.quickCommandSlot);end
  end
 end
end
function C.Auto()
 if C.Config().enabled==true then C.Execute(true); end
end
function C.Selected()
 local id=C.Config().selectedId;
 for index,entry in ipairs(C.Library().entries) do
  if type(entry)=="table" and entry.id==id then return entry,index; end
 end
end
function C.Matches(query)
 query=C.Fold(query):match("^%s*(.-)%s*$");
 local matches={};
 for _,entry in ipairs(C.Library().entries) do
  if type(entry)=="table" and type(entry.name)=="string" and type(entry.text)=="string"
   and (query=="" or C.Fold(entry.name.." "..entry.text.." "..tostring(entry.searchText or "")):find(query,1,true)) then table.insert(matches,entry); end
 end
 table.sort(matches,function(a,b)
  local an,bn=C.Fold(a.name),C.Fold(b.name);
  if an==bn then return tostring(a.id)<tostring(b.id); end
  return an<bn;
 end);
 return matches;
end
function C.Load(id)
 local entry;
 for _,candidate in ipairs(C.Library().entries) do if type(candidate)=="table" and candidate.id==id then entry=candidate; break end end
 if not entry then C.Message("Пресет уже отсутствует в списке."); return false; end
 local cfg=C.Config();cfg.text=entry.text;cfg.selectedId=entry.id;cfg.presetName=entry.name;
 if C.frame then
  local f=C.frame;f.loading=true;f.edit:SetText(entry.text);f.name:SetText(entry.name);f.loading=false;
 end
 C.Message("Загружен пресет «"..entry.name.."». Команды не отправлены."); return true;
end
function C.SaveCurrent()
 local cfg=C.Config();
 local text=C.frame and C.frame.edit:GetText() or cfg.text or "";
 local commands,err=C.Parse(text);
 if not commands then C.Message(err);return false; end
 if cfg.enabled and #commands==0 then C.Message("Автоприменение включено: заполните команды или снимите галочку.");return false; end
 cfg.text=text;
 C.Message("Выбор сохранён. "..(cfg.enabled and "Отправлю через /p после полной сборки состава." or "Автоприменение выключено."));
 return true;
end
function C.SavePreset(name,text)
 name=tostring(name or ""):match("^%s*(.-)%s*$");
 if name=="" or C.Length(name)>64 or C.Control(name) or name:find("|",1,true) then C.Message("Укажите название пресета, до 64 символов, без служебных знаков.");return false; end
 local commands,err=C.Parse(text);
 if not commands then C.Message(err);return false; end
 if #commands==0 then C.Message("В пустом пресете нет команд. Заполните поле команд.");return false; end
 local lib=C.Library();local entry;
 for _,candidate in ipairs(lib.entries) do
  if type(candidate)=="table" and C.Fold(candidate.name)==C.Fold(name) then entry=candidate;break end
 end
 if not entry then
  if #lib.entries>=100 then C.Message("Сохранено 100/100 пресетов. Обновите существующий или удалите ненужный.");return false; end
  local id=tonumber(lib.nextId) or 1;
  for _,candidate in ipairs(lib.entries) do if type(candidate)=="table" then id=math.max(id,(tonumber(candidate.id) or 0)+1);end;end
  entry={id=id};lib.nextId=id+1;table.insert(lib.entries,entry);
 end
 entry.name=name;entry.text=tostring(text);entry.updatedAt=time();
 local cfg=C.Config();cfg.selectedId=entry.id;cfg.text=entry.text;cfg.presetName=name;
 C.Message("Пресет «"..name.."» сохранён ("..#lib.entries.."/100). Другое имя создаёт новый пресет; то же имя обновляет существующий.");
 return true;
end
function C.DeleteSelected()
 local entry,index=C.Selected();
 if not entry then C.Message("Сначала выберите пресет в списке.");return false;end
 table.remove(C.Library().entries,index);C.Config().selectedId=nil;
 C.Message("Удалён пресет «"..entry.name.."». Текст в поле сохранён.");return true;
end
function C.Refresh()
 local f=C.frame;
 if not f or not f:IsShown() then return;end
 local cfg=C.Config();f.auto:SetChecked(cfg.enabled==true);
 f.measure:SetText(f.edit:GetText());f.edit:SetHeight(math.max(130,(f.measure:GetStringHeight() or 130)+24));
 local commands,err=C.Parse(f.edit:GetText());
 f.preview:SetText(commands and ("Команд: "..#commands.."/50. Каждая отправится отдельно: /p <команда>.") or err);
 local selected=C.Selected();f.selected:SetText("Выбранный пресет:\n"..(selected and selected.name or "не выбран").."\nСохранено: "..#C.Library().entries.."/100.");
 local pending=C.Library().raidPresetsSeedPending or 0;
 f.status:SetText(pending>0 and ("Для встроенных пресетов стратегий не хватает мест: "..pending..". Лимит — 100; удалите ненужные записи.") or C.status or "Открытие окна, поиск и выбор пресета не отправляют команд.");
 C.RenderDropdown();
 C.RefreshQuickSlots();
end
function C.ShowPresetTooltip(button,entry)
 if not GameTooltip or not entry then return;end
 GameTooltip:SetOwner(button,"ANCHOR_RIGHT");GameTooltip:ClearLines();GameTooltip:AddLine(entry.name,1,0.82,0,true);
 if type(entry.description)=="string" and entry.description~="" then GameTooltip:AddLine(entry.description,1,1,1,true);end
 GameTooltip:AddLine("Выбор загружает команды справа. Для отправки нажмите «Применить сейчас».",0.6,0.85,1,true);
 GameTooltip:Show();
end
function C.RenderDropdown()
 local f=C.frame;if not f then return;end
 local matches=C.Matches(f.search:GetText());
 local last=math.max(0,math.ceil(#matches/6)-1)*6;
 C.offset=math.max(0,math.min(C.offset or 0,last));
 for i,b in ipairs(f.rows) do
  b.entry=matches[C.offset+i];
  if b.entry then b:SetText(b.entry.name);b:Show();else b:Hide();end
 end
 f.empty:SetText(#matches==0 and "Ничего не найдено" or "");
 f.page:SetText("Найдено: "..#matches.."; "..(#matches>0 and (C.offset+1).."–"..math.min(C.offset+6,#matches) or "0"));
end
function C.Edit(parent,width,height,x,y,multiline)
 local e=CreateFrame("EditBox",nil,parent,not multiline and "InputBoxTemplate" or nil);e:SetAutoFocus(false);
 e:SetWidth(width);e:SetHeight(height);e:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);e:SetFont(STANDARD_TEXT_FONT,17);
 e:SetScript("OnEscapePressed",function(b) b:ClearFocus();end);return e;
end
function C.Open()
 if C.frame and C.frame:IsShown() then C.frame:Raise();return;end
 if not C.frame then
  local f=UnBotServiceUI.Window("UnBotPostSummonCommandsWindow","Команды и пресеты",720);C.frame=f;f:SetFrameStrata("FULLSCREEN");
  f.auto=UnBotSquadLoot.Check(f,"После полного призыва отправить команды всей группе/рейду через /p",28,-66,function(b) C.Config().enabled=b:GetChecked() and true or false;C.Refresh();end);
  f.libraryTitle=UnBotServiceUI.Text(f,19,300,"Сохранённые пресеты");f.libraryTitle:SetPoint("TOPLEFT",f,"TOPLEFT",28,-112);
  f.searchLabel=UnBotServiceUI.Text(f,16,60,"Поиск:");f.searchLabel:SetPoint("TOPLEFT",f,"TOPLEFT",28,-156);
  f.search=C.Edit(f,160,30,90,-148);f.search:SetMaxLetters(128);
  f.choose=UnBotServiceUI.Button(f,66,"Все",function() f.search:SetText("");C.offset=0;C.RenderDropdown();end);f.choose:SetHeight(30);f.choose:SetPoint("TOPLEFT",f,"TOPLEFT",262,-148);
  f.dropdown=UnBotServiceUI.Panel(f,300,302);f.dropdown:SetPoint("TOPLEFT",f,"TOPLEFT",28,-194);f.dropdown:EnableMouse(true);f.dropdown:EnableMouseWheel(true);
  f.rows={};
  for i=1,6 do
   local b=UnBotServiceUI.Button(f.dropdown,276,"",function(b) if b.entry then C.Load(b.entry.id);end;end);b:SetHeight(34);b:SetPoint("TOPLEFT",f.dropdown,"TOPLEFT",12,-10-(i-1)*36);
   b:GetFontString():SetFont(STANDARD_TEXT_FONT,15);b:GetFontString():SetWidth(258);b:GetFontString():SetHeight(32);
   b:SetScript("OnEnter",function(button) C.ShowPresetTooltip(button,button.entry);end);
   b:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide();end;end);table.insert(f.rows,b);
  end
  f.empty=UnBotServiceUI.Text(f.dropdown,16,268);f.empty:SetPoint("TOPLEFT",f.dropdown,"TOPLEFT",16,-14);
  f.page=UnBotServiceUI.Text(f.dropdown,14,268);f.page:SetPoint("BOTTOMLEFT",f.dropdown,"BOTTOMLEFT",16,38);
  f.prev=UnBotServiceUI.Button(f.dropdown,60,"<",function() C.offset=(C.offset or 0)-6;C.RenderDropdown();end);f.prev:SetHeight(24);f.prev:SetPoint("BOTTOMLEFT",f.dropdown,"BOTTOMLEFT",12,8);
  f.next=UnBotServiceUI.Button(f.dropdown,60,">",function() C.offset=(C.offset or 0)+6;C.RenderDropdown();end);f.next:SetHeight(24);f.next:SetPoint("BOTTOMRIGHT",f.dropdown,"BOTTOMRIGHT",-12,8);
  f.dropdown:SetScript("OnMouseWheel",function(_,d) C.offset=(C.offset or 0)-d*6;C.RenderDropdown();end);
  f.search:SetScript("OnTextChanged",function() if not f.loading then C.offset=0;C.RenderDropdown();end;end);
  f.search:SetScript("OnEscapePressed",function(b) b:ClearFocus();end);
  f.selected=UnBotServiceUI.Text(f,16,300);f.selected:SetPoint("TOPLEFT",f,"TOPLEFT",28,-508);f.selected:SetHeight(80);
  f.help=UnBotServiceUI.Button(f,300,"8 слотов меню...",function() C.OpenQuickSlots();end);f.help:SetPoint("TOPLEFT",f,"TOPLEFT",28,-600);
  f.commandsTitle=UnBotServiceUI.Text(f,19,630,"Команды для группы / рейда");f.commandsTitle:SetPoint("TOPLEFT",f,"TOPLEFT",356,-112);
  f.example=UnBotServiceUI.Text(f,16,630,"Пример строки: nc -naxx, co -naxx\nРазделитель — запятая или новая строка. Префикс /p не нужен.");f.example:SetPoint("TOPLEFT",f,"TOPLEFT",356,-150);
  f.editorPanel=UnBotServiceUI.Panel(f,632,160);f.editorPanel:SetPoint("TOPLEFT",f,"TOPLEFT",352,-204);
  f.scroll=CreateFrame("ScrollFrame","UnBotPostSummonCommandsScroll",f,"UIPanelScrollFrameTemplate");f.scroll:SetWidth(588);f.scroll:SetHeight(130);f.scroll:SetPoint("TOPLEFT",f,"TOPLEFT",366,-218);
  f.edit=C.Edit(f.scroll,568,130,0,0,true);f.edit:SetMultiLine(true);f.edit:SetMaxLetters(16000);f.edit:SetTextInsets(4,4,4,4);f.scroll:SetScrollChild(f.edit);f.scroll:EnableMouseWheel(true);
  f.scroll:SetScript("OnMouseWheel",function(b,d) b:SetVerticalScroll(math.max(0,math.min(b:GetVerticalScrollRange() or 0,(b:GetVerticalScroll() or 0)-d*24)));end);
  f.edit:SetScript("OnCursorChanged",function(_,x,y,w,h)
   local top=f.scroll:GetVerticalScroll() or 0;local cursor=-y;
   if cursor<top then f.scroll:SetVerticalScroll(math.max(0,cursor));elseif cursor+h>top+130 then f.scroll:SetVerticalScroll(math.min(f.scroll:GetVerticalScrollRange() or 0,cursor+h-130));end
  end);
  f.measure=UnBotServiceUI.Text(f.scroll,17,560);f.measure:Hide();
  f.edit:SetScript("OnTextChanged",function(b) if not f.loading then C.Config().text=b:GetText();C.Refresh();end;end);
  f.preview=UnBotServiceUI.Text(f,15,630);f.preview:SetPoint("TOPLEFT",f,"TOPLEFT",356,-380);
  f.nameLabel=UnBotServiceUI.Text(f,17,630,"Название пресета:");f.nameLabel:SetPoint("TOPLEFT",f,"TOPLEFT",356,-418);
  f.name=C.Edit(f,620,30,360,-448);f.name:SetMaxLetters(64);
  f.name:SetScript("OnTextChanged",function(b) if not f.loading then C.Config().presetName=b:GetText();end;end);
  f.savePreset=UnBotServiceUI.Button(f,300,"Сохранить пресет",function() C.SavePreset(f.name:GetText(),f.edit:GetText());end);f.savePreset:SetPoint("TOPLEFT",f,"TOPLEFT",356,-494);
  f.deletePreset=UnBotServiceUI.Button(f,312,"Удалить выбранный",C.DeleteSelected);f.deletePreset:SetPoint("TOPLEFT",f,"TOPLEFT",672,-494);
  f.libraryHelp=UnBotServiceUI.Text(f,15,630,"До 100 пресетов. То же название обновляет запись, новое — создаёт отдельную. Личные профили альтов не меняются.");f.libraryHelp:SetPoint("TOPLEFT",f,"TOPLEFT",356,-546);
  f.status=UnBotServiceUI.Text(f,15,630);f.status:SetPoint("TOPLEFT",f,"TOPLEFT",356,-600);f.status:SetHeight(56);
  f.save=UnBotServiceUI.Button(f,160,"Сохранить",C.SaveCurrent);f.save:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",28,20);
  f.fillExample=UnBotServiceUI.Button(f,112,"Пример",function() f.edit:SetText(C.example);C.Config().text=C.example;C.Refresh();end);f.fillExample:SetPoint("LEFT",f.save,"RIGHT",12,0);
  f.apply=UnBotServiceUI.Button(f,224,"Применить сейчас",function() if C.SaveCurrent() then C.Execute(false);end;end);f.apply:SetPoint("LEFT",f.fillExample,"RIGHT",12,0);
  f.stop=UnBotServiceUI.Button(f,100,"Стоп",function() if UnBotSquadLoot.job and UnBotSquadLoot.job.customStart then UnBotSquadLoot.Finish("Остановлено игроком");end;end);f.stop:SetPoint("LEFT",f.apply,"RIGHT",12,0);
  f.closeButton=UnBotServiceUI.Button(f,170,"Закрыть",function() if C.SaveCurrent() then f:Hide();end;end);f.closeButton:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-36,20);
  f:SetScript("OnHide",function() f.edit:ClearFocus();f.search:ClearFocus();f.name:ClearFocus();end);
 end
 local f=C.frame;local cfg=C.Config();f.loading=true;f.edit:SetText(cfg.text or "");f.name:SetText(cfg.presetName or "");f.search:SetText("");f.loading=false;
 f:Show();f:Raise();f.dropdown:Show();C.Refresh();
end
function C.CreateButton(builder)
 if builder.commandSettingsButton then return;end
 if builder.settingsSection and builder.settingsSection.caption then builder.settingsSection.caption:SetText("НАСТРОЙКИ");end
 local b=CreateFrame("Button",nil,builder.frame,"UIPanelButtonTemplate");b:SetWidth(128);b:SetHeight(22);b:SetPoint("BOTTOMLEFT",builder.frame,"BOTTOMLEFT",150,132);
 b:SetText("Свои команды");b:SetScript("OnClick",C.Open);builder.commandSettingsButton=b;
end
SLASH_UNBOTPOSTCOMMANDS1="/ubcommands";SlashCmdList.UNBOTPOSTCOMMANDS=C.Open;
end
-- END POST SUMMON COMMANDS
