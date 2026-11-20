-- Manual wipe recovery: release, confirm, summon, confirm arrival, stop.
-- Cooldowns come from server replies, never from a guessed fixed interval.
UnBotSpiritRescue = UnBotSpiritRescue or {active = false, status = "Цикл не запущен."};

function UnBotSpiritRescue.Message(text)
	UnBotSpecSummonMessage("Освобождение духа: "..text);
end

function UnBotSpiritRescue.Storage()
	UnBotSquadConfig = UnBotSquadConfig or {};
	UnBotSquadConfig.spiritReleaseTimers = UnBotSquadConfig.spiritReleaseTimers or {};
	local key = (GetRealmName() or "")..":"..(UnitName("player") or "");
	UnBotSquadConfig.spiritReleaseTimers[key] = UnBotSquadConfig.spiritReleaseTimers[key] or {};
	return UnBotSquadConfig.spiritReleaseTimers[key];
end

function UnBotSpiritRescue.Context()
	local name, kind = GetInstanceInfo();
	return (GetRealmName() or "")..":"..(UnitName("player") or "")..":"..tostring(name)..":"..tostring(kind);
end

function UnBotSpiritRescue.Roster()
	local result = {};
	local raid = (GetNumRaidMembers() or 0) > 0;
	local count = raid and GetNumRaidMembers() or GetNumPartyMembers();
	for index = 1, count or 0 do
		local unit = (raid and "raid" or "party")..index;
		local name = UnitName(unit);
		if (name and name ~= UnitName("player") and UnBotBotRegistry and UnBotBotRegistry.bots
			and UnBotBotRegistry.bots[name]) then
			result[name] = {unit = unit, online = UnitIsConnected(unit) and true or false,
				dead = UnitIsDeadOrGhost(unit) and true or false, ghost = UnitIsGhost(unit) and true or false};
		end
	end
	return result;
end

function UnBotSpiritRescue.Combat()
	if (UnitAffectingCombat("player") or (InCombatLockdown and InCombatLockdown())) then return true; end
	local raid = (GetNumRaidMembers() or 0) > 0;
	for index = 1, (raid and GetNumRaidMembers() or GetNumPartyMembers()) or 0 do
		local unit = (raid and "raid" or "party")..index;
		if (UnitIsConnected(unit) and UnitAffectingCombat(unit)) then return true; end
	end
	return false;
end

function UnBotSpiritRescue.Busy()
	return (UnBotRaidReserveOtherAutomationActive and UnBotRaidReserveOtherAutomationActive(false, true))
		or (UnBotRaidReserve and UnBotRaidReserve.active)
		or (UnBotPVPSummon and UnBotPVPSummon.active)
		or (UnBotSquadSummon and UnBotSquadSummon.active)
		or (UnBotSquadBuilder and UnBotSquadBuilder.postSummonSequence)
		or (UnBotGunshipMasterLoot and UnBotGunshipMasterLoot.paused);
end

function UnBotSpiritRescue.RecordRelease()
	local state, storage = UnBotSpiritRescue, UnBotSpiritRescue.Storage();
	state.lastSendAt = GetTime();
	storage.lastReleaseAt = time();
	state.watched = state.watched or {};
	for name, bot in pairs(UnBotSpiritRescue.Roster()) do
		if (bot.online and bot.dead) then state.watched[name] = true; end
	end
end

function UnBotSpiritRescue.Stop(text)
	local state = UnBotSpiritRescue;
	state.active, state.stage = false, nil;
	state.status = text or "Остановлено.";
	state.stableAt = nil;
	UnBotSpiritRescue.Message(state.status);
	UnBotSpiritRescue.Refresh();
end

function UnBotSpiritRescue.Start()
	local state, storage = UnBotSpiritRescue, UnBotSpiritRescue.Storage();
	UnBotSpiritRescue.Show();
	if (state.active) then UnBotSpiritRescue.Message("цикл уже выполняется."); return false; end
	if (UnBotSpiritRescue.Combat()) then UnBotSpiritRescue.Stop("Дождитесь полного завершения боя у группы."); return false; end
	local inside, kind = IsInInstance();
	if (not inside or (kind ~= "raid" and kind ~= "party")) then
		UnBotSpiritRescue.Stop("Release используется только в подземелье или рейде."); return false;
	end
	if (UnBotSpiritRescue.Busy()) then UnBotSpiritRescue.Stop("Сначала завершите другой цикл UnBot."); return false; end
	local needsRelease = false;
	state.names, state.deadNames, state.released, state.watched = {}, {}, {}, {};
	for name, bot in pairs(UnBotSpiritRescue.Roster()) do
		if (bot.online) then
			state.names[name] = true;
			if (bot.dead) then
				state.deadNames[name], state.watched[name] = true, true;
				if (bot.ghost) then state.released[name] = true; else needsRelease = true; end
			end
		end
	end
	if (not next(state.deadNames)) then UnBotSpiritRescue.Stop("Мёртвых онлайн-ботов в группе нет."); return false; end
	if (needsRelease and (storage.cooldownUntil or 0) > time()) then
		UnBotSpiritRescue.Stop("Release пока недоступен: дождитесь таймера в окне."); return false;
	end
	state.active, state.stage, state.context = true, "release", UnBotSpiritRescue.Context();
	state.deadline, state.stageDeadline = GetTime() + 90, GetTime() + 20;
	state.summonAttempts, state.stableAt = 0, nil;
	if (not needsRelease) then
		UnBotSpiritRescue.Message("дух уже освобождён у всех мёртвых ботов; призываю.");
		UnBotSpiritRescue.SendSummon(); return true;
	end
	state.status = "Release отправлен; ожидаю освобождения всех мёртвых ботов.";
	UnBotSpiritRescue.RecordRelease();
	SendChatMessage("release", (GetNumRaidMembers() or 0) > 0 and "RAID" or "PARTY");
	UnBotSpiritRescue.Message(state.status);
	UnBotSpiritRescue.Refresh();
	return true;
end

function UnBotSpiritRescue.SendSummon()
	local state = UnBotSpiritRescue;
	state.summonAttempts = state.summonAttempts + 1;
	state.stage, state.nextSummonAt = "arrival", GetTime() + 10;
	SendChatMessage("summon", (GetNumRaidMembers() or 0) > 0 and "RAID" or "PARTY");
	state.status = "Summon отправлен; ожидаю живых ботов рядом.";
	UnBotSpiritRescue.Message(state.status);
end

function UnBotSpiritRescue.Update()
	local state, now = UnBotSpiritRescue, GetTime();
	if (not state.active) then return; end
	if (UnBotSpiritRescue.Combat() or UnBotSpiritRescue.Context() ~= state.context) then
		UnBotSpiritRescue.Stop("Цикл остановлен: бой или смена подземелья."); return;
	end
	if (UnBotSpiritRescue.Busy()) then UnBotSpiritRescue.Stop("Цикл остановлен: запущена другая операция UnBot."); return; end
	local roster, missing = UnBotSpiritRescue.Roster(), {};
	for name, bot in pairs(roster) do
		if (bot.online and not state.names[name]) then
			UnBotSpiritRescue.Stop("Состав изменился: появился новый онлайн-бот "..name..". Повторите цикл для текущей группы."); return;
		end
	end
	for name in pairs(state.names) do
		if (not roster[name] or not roster[name].online) then
			UnBotSpiritRescue.Stop("Бот вышел из группы или ушёл офлайн: "..name..". Состав сохранён."); return;
		end
	end
	if (state.stage == "release") then
		for name in pairs(state.deadNames) do
			local bot = roster[name];
			if (bot.ghost or not bot.dead) then state.released[name] = true; end
			if (not state.released[name]) then table.insert(missing, name); end
		end
		if (#missing == 0) then
			UnBotSpiritRescue.Message("освобождение подтверждено; призываю ботов.");
			UnBotSpiritRescue.SendSummon();
		elseif (now >= state.stageDeadline) then
			table.sort(missing);
			UnBotSpiritRescue.Stop("Освобождение не подтверждено: "..table.concat(missing, ", ")..". Summon не отправлен.");
		end
	else
		for name in pairs(state.names) do
			local bot = roster[name];
			if (bot.dead or not UnBotSquadNearbyGateUnitReady(bot.unit)) then table.insert(missing, name); end
		end
		if (#missing == 0) then
			state.stableAt = state.stableAt or now + 1;
			if (now >= state.stableAt) then UnBotSpiritRescue.Stop("Все боты живы и прибыли. Готово."); end
			return;
		end
		state.stableAt = nil;
		if (now >= state.deadline or (state.summonAttempts >= 3 and now >= state.nextSummonAt)) then
			table.sort(missing);
			UnBotSpiritRescue.Stop("Прибытие не подтверждено: "..table.concat(missing, ", ")..". Повторы завершены.");
		elseif (now >= state.nextSummonAt) then UnBotSpiritRescue.SendSummon(); end
	end
end

function UnBotSpiritRescue.Lower(message)
	local text = string.gsub(message, "[A-Z]", string.lower);
	-- Lua 5.1 string.lower is byte/locale-based; preserve UTF-8 server replies.
	return (string.gsub(text, "\208[\129\144-\175]", function(letter)
		local code = string.byte(letter,2);
		if (code == 129) then return string.char(209,145); end
		return code < 160 and string.char(208,code+32) or string.char(209,code-32);
	end));
end

function UnBotSpiritRescue.Seconds(message)
	local text = UnBotSpiritRescue.Lower(message);
	local h, m, s = string.match(text, "(%d+):(%d%d):(%d%d)");
	if (h) then return tonumber(h)*3600 + tonumber(m)*60 + tonumber(s); end
	m, s = string.match(text, "(%d+):(%d%d)");
	if (m) then return tonumber(m)*60 + tonumber(s); end
	h = string.match(text, "(%d+)%s*hours?") or string.match(text, "(%d+)%s*час");
	h = h or string.match(text, "(%d+)%s*h%f[%A]");
	m = string.match(text, "(%d+)%s*min") or string.match(text, "(%d+)%s*мин") or string.match(text, "(%d+)%s*m%f[%A]");
	s = string.match(text, "(%d+)%s*sec") or string.match(text, "(%d+)%s*сек")
		or string.match(text, "(%d+)%s+more%s+sec") or string.match(text, "(%d+)%s*s%f[%A]");
	if (h or m or s) then return (tonumber(h) or 0)*3600 + (tonumber(m) or 0)*60 + (tonumber(s) or 0); end
	return nil;
end

function UnBotSpiritRescue.Reply(event, message, sender)
	if (type(message) ~= "string") then return; end
	local state = UnBotSpiritRescue;
	sender = sender and string.match(sender, "^[^-]+");
	local text = UnBotSpiritRescue.Lower((string.gsub(message, "|c%x%x%x%x%x%x%x%x", "")));
	text = string.gsub(text, "|r", "");
	if (event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER" or event == "CHAT_MSG_RAID"
		or event == "CHAT_MSG_RAID_LEADER" or event == "CHAT_MSG_WHISPER_INFORM") then
		if (text == "release" and ((event == "CHAT_MSG_WHISPER_INFORM" and UnBotSpiritRescue.Roster()[sender])
			or sender == UnitName("player"))) then
			if (not state.lastSendAt or GetTime() - state.lastSendAt > 1) then UnBotSpiritRescue.RecordRelease(); end
			UnBotSpiritRescue.Show();
		end
		return;
	end
	local recent = state.lastSendAt and GetTime() - state.lastSendAt <= 20;
	local ownBot = sender and state.watched and state.watched[sender];
	local releaseText = string.find(text, "release", 1, true) or string.find(text, "освобожд", 1, true);
	if (not recent or (event == "CHAT_MSG_WHISPER" and not ownBot)
		or (event == "CHAT_MSG_SYSTEM" and not releaseText)) then return; end
	if (not releaseText and (string.find(text, "cast", 1, true) or string.find(text, "spell", 1, true)
		or string.find(text, "summon", 1, true) or string.find(text, "teleport", 1, true))) then
		if (state.active and state.stage == "arrival" and string.find(text, "summon", 1, true)
			and (string.find(text, "cannot", 1, true) or string.find(text, "cooldown", 1, true)
				or string.find(text, "wait", 1, true))) then
			UnBotSpiritRescue.Stop("Summon отклонён сервером: "..message);
		end
		return;
	end
	local released = ownBot and not string.find(text, "not release", 1, true)
		and ((string.find(text, "released", 1, true) and releaseText)
			or string.find(text, "освободил дух", 1, true) or string.find(text, "дух освобожд", 1, true));
	if (state.active and state.stage == "release" and released and state.deadNames[sender]) then
		state.released[sender] = true;
	end
	local wait = string.find(text, "wait", 1, true) or string.find(text, "cooldown", 1, true)
		or string.find(text, "too often", 1, true) or string.find(text, "too soon", 1, true)
		or string.find(text, "remaining", 1, true) or string.find(text, "подожд", 1, true)
		or (releaseText and (string.find(text, "again", 1, true) or string.find(text, "available", 1, true)))
		or string.find(text, "повтор", 1, true) or string.find(text, "слишком часто", 1, true)
		or string.find(text, "недоступ", 1, true);
	if (wait and (releaseText or state.stage == "release" or not state.active)) then
		local storage, seconds = UnBotSpiritRescue.Storage(), UnBotSpiritRescue.Seconds(text);
		storage.cooldownMessage = message;
		if (seconds and seconds > 0 and seconds <= 86400) then
			storage.cooldownUntil = math.max(storage.cooldownUntil or 0, time() + seconds);
			storage.cooldownUnknown = nil;
		else storage.cooldownUnknown = true; end
		if (state.active and not released) then UnBotSpiritRescue.Stop("Сервер ограничил release: "..message); end
		UnBotSpiritRescue.Show();
		return;
	end
	if (state.active and (releaseText or ownBot) and (string.find(text, "unknown command", 1, true)
		or string.find(text, "cannot", 1, true) or string.find(text, "not in a dungeon", 1, true)
		or string.find(text, "неизвестная команда", 1, true))) then
		UnBotSpiritRescue.Stop("Команда отклонена сервером: "..message);
	end
end

function UnBotSpiritRescue.Clock(seconds)
	seconds = math.max(0, math.ceil(seconds));
	return string.format("%d:%02d", math.floor(seconds/60), seconds%60);
end

function UnBotSpiritRescue.Refresh()
	local state, storage = UnBotSpiritRescue, UnBotSpiritRescue.Storage();
	if (not state.window) then return; end
	local remaining = (storage.cooldownUntil or 0) - time();
	if (remaining > 0) then
		state.timerText:SetText("Повтор release через "..UnBotSpiritRescue.Clock(remaining).." (ответ сервера)");
	elseif (storage.cooldownUnknown) then
		state.timerText:SetText("Сервер ограничил release; срок ожидания не указан.");
	elseif (storage.cooldownUntil) then
		state.timerText:SetText("Ожидание по ответу сервера истекло.");
	else state.timerText:SetText("Серверный интервал пока не подтверждён."); end
	state.elapsedText:SetText(storage.lastReleaseAt and ("С последнего release: "..UnBotSpiritRescue.Clock(time()-storage.lastReleaseAt)) or "Release ещё не отправлялся.");
	state.statusText:SetText(state.status);
	state.replyText:SetText(storage.cooldownMessage or "При ограничении отсчёт появится из ответа сервера.");
	local needsRelease = false;
	if (remaining > 0) then
		for _, bot in pairs(UnBotSpiritRescue.Roster()) do
			if (bot.online and bot.dead and not bot.ghost) then needsRelease = true; break end
		end
	end
	if (state.active or needsRelease) then state.startButton:Disable(); else state.startButton:Enable(); end
end

function UnBotSpiritRescue.Show()
	local state, storage = UnBotSpiritRescue, UnBotSpiritRescue.Storage();
	if (not state.window) then
		local frame = CreateFrame("Frame", "UnBotSpiritRescueWindow", UIParent);
		state.window = frame;
		frame:SetSize(410, 230);
		frame:SetPoint(storage.point or "CENTER", UIParent, storage.relativePoint or "CENTER", storage.x or 0, storage.y or 140);
		frame:SetFrameStrata("DIALOG");
		frame:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=true, tileSize=32, edgeSize=32, insets={left=11,right=12,top=12,bottom=11}});
		frame:EnableMouse(true); frame:SetMovable(true); frame:RegisterForDrag("LeftButton");
		frame:SetScript("OnDragStart", frame.StartMoving);
		frame:SetScript("OnDragStop", function(self)
			self:StopMovingOrSizing();
			local point, _, relativePoint, x, y = self:GetPoint();
			local saved = UnBotSpiritRescue.Storage();
			saved.point, saved.relativePoint, saved.x, saved.y = point, relativePoint, x, y;
		end);
		local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
		title:SetPoint("TOP", 0, -17); title:SetText("Освобождение духа — таймер");
		local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -5, -5);
		close:SetScript("OnClick", function() frame:Hide(); end);
		state.timerText = frame:CreateFontString(nil,"OVERLAY","GameFontHighlight");
		state.timerText:SetPoint("TOPLEFT",20,-48); state.timerText:SetWidth(370);
		state.elapsedText = frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");
		state.elapsedText:SetPoint("TOPLEFT",20,-79); state.elapsedText:SetWidth(370);
		state.statusText = frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");
		state.statusText:SetPoint("TOPLEFT",20,-103); state.statusText:SetWidth(370);
		state.statusText:SetHeight(36);
		state.replyText = frame:CreateFontString(nil,"OVERLAY","GameFontDisableSmall");
		state.replyText:SetPoint("TOPLEFT",20,-142); state.replyText:SetWidth(370);
		state.replyText:SetHeight(36);
		state.startButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
		state.startButton:SetSize(295,24); state.startButton:SetPoint("BOTTOMLEFT",18,17);
		state.startButton:SetText("Воскресить через освобождение"); state.startButton:SetScript("OnClick",UnBotSpiritRescue.Start);
		local stop = CreateFrame("Button",nil,frame,"UIPanelButtonTemplate");
		stop:SetSize(70,24); stop:SetPoint("BOTTOMRIGHT",-18,17); stop:SetText("Стоп");
		stop:SetScript("OnClick",function() if state.active then UnBotSpiritRescue.Stop("Остановлено игроком."); end end);
	end
	state.window:Show();
	UnBotSpiritRescue.Refresh();
end

UnBotSpiritRescue.frame = CreateFrame("Frame");
for _, event in ipairs({"CHAT_MSG_WHISPER","CHAT_MSG_SYSTEM","CHAT_MSG_PARTY","CHAT_MSG_PARTY_LEADER","CHAT_MSG_RAID","CHAT_MSG_RAID_LEADER","CHAT_MSG_WHISPER_INFORM","PLAYER_ENTERING_WORLD","PLAYER_LOGIN"}) do
	UnBotSpiritRescue.frame:RegisterEvent(event);
end
UnBotSpiritRescue.frame:SetScript("OnEvent", function(self,event,message,sender)
	if (event == "PLAYER_ENTERING_WORLD") then
		if (UnBotSpiritRescue.active) then UnBotSpiritRescue.Stop("Смена мира: цикл остановлен."); end
	elseif (event == "PLAYER_LOGIN") then
		if ((UnBotSpiritRescue.Storage().cooldownUntil or 0) > time()) then UnBotSpiritRescue.Show(); end
	else UnBotSpiritRescue.Reply(event,message,sender); end
end);
UnBotSpiritRescue.frame:SetScript("OnUpdate",function(self,elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed;
	if (self.elapsed < 0.25) then return; end
	self.elapsed = 0;
	UnBotSpiritRescue.Update();
	if (UnBotSpiritRescue.window and UnBotSpiritRescue.window:IsShown()) then UnBotSpiritRescue.Refresh(); end
end);
