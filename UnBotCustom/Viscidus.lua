-- Viscidus: bounded, bot-side target choice during each glob wave.
-- The 3.3.5 client cannot compare a bot's distance to arbitrary NPCs.
UnBotViscidus = {
	manual = false,
	suppressed = false,
	waveActive = false,
	waves = 0,
	lastWaveAt = -1000,
	lastWaveEndedAt = -1000,
	lastGlobAt = 0,
	fightExpiresAt = 0,
	cooldownUntil = 0,
	rejected = false,
	exhausted = false,
};

function UnBotViscidus:Message(message)
	if UnBotSpecSummonMessage then
		UnBotSpecSummonMessage("Нечистотон: "..message);
	else
		DEFAULT_CHAT_FRAME:AddMessage("UnBot — Нечистотон: "..message);
	end
end

function UnBotViscidus:Enabled()
	if self.suppressed then return false; end
	if self.manual then return true; end
	return UnBotBossPresetLoadedAutoStrategyEnabled
		and UnBotBossPresetLoadedAutoStrategyEnabled("temple_of_ahn_qiraj__viscidus")
		or false;
end

function UnBotViscidus:Send(command)
	local channel;
	if GetNumRaidMembers() > 0 then
		channel = "RAID";
	elseif GetNumPartyMembers() > 0 then
		channel = "PARTY";
	end
	if not channel then return false; end
	SendChatMessage(command, channel);
	return true;
end

function UnBotViscidus:IsNpc(guid, name, entry)
	if type(guid) == "string" then
		local hex = string.match(guid, "^0xF130(%x%x%x%x%x%x)");
		if hex then return tonumber(hex, 16) == entry; end
	end
	if entry == 15667 then
		return name == "Капля Нечистотона" or name == "Glob of Viscidus";
	end
	return name == "Нечистотон" or name == "Viscidus";
end

function UnBotViscidus:EndWave(reason)
	if not self.waveActive then return; end
	self.waveActive = false;
	self.lastWaveEndedAt = GetTime();
	self:Send("@dps co -grind");
	self:Message("капли "..reason.."; свободный выбор цели ДД выключен.");
end

function UnBotViscidus:Stop(reason)
	self:EndWave(reason or "завершились");
	self.fightExpiresAt = 0;
	self.lastGlobAt = 0;
	self.lastWaveAt = -1000;
	self.lastWaveEndedAt = -1000;
	self.waves = 0;
	self.rejected = false;
end

function UnBotViscidus:SeeGlob(now)
	if not self:Enabled() or self.exhausted or now < self.cooldownUntil then return; end
	if self.fightExpiresAt == 0 then
		self.fightExpiresAt = now + 720;
		self.waves = 0;
		self.rejected = false;
	end
	if now >= self.fightExpiresAt or self.rejected then return; end
	self.lastGlobAt = now;
	if self.waveActive or now - self.lastWaveAt < 8
		or now - self.lastWaveEndedAt < 5 then return; end
	if self.waves >= 6 then return; end
	if not self:Send("@dps co +grind") then
		self:Message("не удалось дать команду ДД: нет группы.");
		self.rejected = true;
		return;
	end
	self.waveActive = true;
	self.waves = self.waves + 1;
	self.lastWaveAt = now;
	self:Message("волна капель #"..self.waves
		..": ДД выбирают видимые цели своим AI; танки и лекари остаются на своих ролях.");
end

SLASH_UNBOTVISCIDUS1 = "/ubviscidus";
SlashCmdList.UNBOTVISCIDUS = function(message)
	local command = string.lower(string.match(message or "", "^%s*(%S+)") or "status");
	if command == "on" then
		UnBotViscidus.manual = true;
		UnBotViscidus.suppressed = false;
		UnBotViscidus.exhausted = false;
		UnBotViscidus.rejected = false;
		UnBotViscidus:Message("ручная автостратегия включена до /reload или команды off.");
	elseif command == "off" then
		UnBotViscidus.manual = false;
		UnBotViscidus.suppressed = true;
		UnBotViscidus:Stop("остановлены");
		UnBotViscidus:Message("автостратегия выключена.");
	else
		UnBotViscidus:Message("автостратегия "
			..(UnBotViscidus:Enabled() and "ВКЛ" or "ВЫКЛ")
			.."; /ubviscidus on | off.");
	end
end;

UnBotViscidusFrame = CreateFrame("Frame", "UnBotViscidusFrame");
UnBotViscidusFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
UnBotViscidusFrame:RegisterEvent("PLAYER_REGEN_ENABLED");
UnBotViscidusFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
UnBotViscidusFrame:RegisterEvent("CHAT_MSG_WHISPER");
UnBotViscidusFrame:SetScript("OnEvent", function(self, event, ...)
	local state = UnBotViscidus;
	if event == "PLAYER_ENTERING_WORLD" then
		state:Stop("остановлены");
		return;
	elseif event == "PLAYER_REGEN_ENABLED" then
		if state.fightExpiresAt > 0 or state.exhausted then
			state.endCheckAt = GetTime() + 4;
		end
		return;
	elseif event == "CHAT_MSG_WHISPER" then
		local message = select(1, ...);
		if state.waveActive and type(message) == "string"
			and string.find(string.lower(message), "grind", 1, true)
			and (string.find(string.lower(message), "unknown", 1, true)
				or string.find(string.lower(message), "cannot", 1, true)
				or string.find(string.lower(message), "invalid", 1, true)
				or string.find(string.lower(message), "not found", 1, true)
				or string.find(string.lower(message), "неизвест", 1, true)) then
			state.rejected = true;
			state:EndWave("отклонены сервером");
			state:Message("сервер отклонил co +grind; повторов в этом бою не будет.");
		end
		return;
	end
	if not state:Enabled() then return; end
	local eventType = select(2, ...);
	local sourceGuid, sourceName = select(3, ...), select(4, ...);
	local destGuid, destName = select(6, ...), select(7, ...);
	if (eventType == "UNIT_DIED" or eventType == "PARTY_KILL")
		and state:IsNpc(destGuid, destName, 15299) then
		state:EndWave("завершились");
		state.fightExpiresAt = 0;
		state.cooldownUntil = GetTime() + 8;
		return;
	end
	if state:IsNpc(sourceGuid, sourceName, 15667)
		or state:IsNpc(destGuid, destName, 15667) then
		local spellId = select(9, ...);
		if eventType ~= "UNIT_DIED" and eventType ~= "PARTY_KILL"
			and eventType ~= "SPELL_AURA_REMOVED"
			and not (eventType == "SPELL_CAST_SUCCESS" and spellId == 25896) then
			state:SeeGlob(GetTime());
		end
	end
end);

UnBotViscidusFrame:SetScript("OnUpdate", function()
	local state = UnBotViscidus;
	if state.fightExpiresAt == 0 and not state.endCheckAt then return; end
	local now = GetTime();
	if state.fightExpiresAt > 0 and (not state:Enabled() or now >= state.fightExpiresAt) then
		state:Stop("остановлены по лимиту боя");
		state.cooldownUntil = now + 30;
		state.exhausted = true;
		return;
	end
	if state.endCheckAt and now >= state.endCheckAt then
		state.endCheckAt = nil;
		if not UnitAffectingCombat("player") then
			state:Stop("завершились после боя");
			state.cooldownUntil = now + 5;
			state.exhausted = false;
			return;
		end
	end
	if state.waveActive and (now - state.lastGlobAt > 3 or now - state.lastWaveAt >= 24) then
		state:EndWave("завершились");
	end
end);

-- Twin Emperors controller lives here so /reload loads it from the existing TOC entry.
-- Twin Emperors: split physical and magical damage by raid marker.
-- Tank positioning is an explicit, server-verified scenario below.
UnBotTwinEmperors = {
	enabled = false,
	manual = false,
	suppressed = false,
	marks = {},
	markAttempts = {},
	queue = {},
	nextSend = 0,
	prepared = false,
	active = false,
	refocuses = 0,
	warnings = 0,
};

function UnBotTwinEmperors:Enabled()
	if self.suppressed then return false; end
	if self.manual then return true; end
	return UnBotBossPresetLoadedAutoStrategyEnabled
		and UnBotBossPresetLoadedAutoStrategyEnabled("temple_of_ahn_qiraj__the_twin_emperors")
		or false;
end

function UnBotTwinEmperors:Message(message)
	if UnBotSpecSummonMessage then
		UnBotSpecSummonMessage("Близнецы: "..message);
	else
		DEFAULT_CHAT_FRAME:AddMessage("UnBot — Близнецы: "..message);
	end
end

function UnBotTwinEmperors:Entry(guid)
	if type(guid) ~= "string" then return nil; end
	local hex = string.match(guid, "^0xF1[35]0(%x%x%x%x%x%x)");
	return hex and tonumber(hex, 16) or nil;
end

function UnBotTwinEmperors:GroupInCombat()
	if UnitAffectingCombat("player") then return true; end
	for index = 1, math.min(40, GetNumRaidMembers() or 0) do
		local unit = "raid"..index;
		if UnitExists(unit) and UnitAffectingCombat(unit) then return true; end
	end
	if (GetNumRaidMembers() or 0)==0 then
		for index=1,(GetNumPartyMembers() or 0) do if UnitAffectingCombat("party"..index) then return true; end end
	end
	return false;
end

function UnBotTwinEmperors:Send(command, recipient)
	if recipient then
		SendChatMessage(command, "WHISPER", nil, recipient);
		self.lastCommandAt = GetTime();
		return true;
	end
	if (GetNumRaidMembers() or 0) == 0 then return false; end
	SendChatMessage(command, "RAID");
	self.lastCommandAt = GetTime();
	return true;
end

function UnBotTwinEmperors:Queue(command, recipient)
	if #self.queue >= 96 then return false; end
	self.queue[#self.queue + 1] = {command = command, recipient = recipient};
	return true;
end

function UnBotTwinEmperors:Casters()
	if self.formation and self.formation.prepared then return self.formation:Casters(); end
	local names = {};
	for index = 1, math.min(40, GetNumRaidMembers() or 0) do
		local unit = "raid"..index;
		local name = UnitName(unit);
		local _, class = UnitClass(unit);
		if name and name ~= UnitName("player")
			and (class == "MAGE" or class == "WARLOCK")
			and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit)
			and UnBotBotRegistry and UnBotBotRegistry.bots
			and UnBotBotRegistry.bots[name] then
			names[#names + 1] = name;
		end
	end
	table.sort(names);
	return names;
end

function UnBotTwinEmperors:MarkedUnit(entry, expectedIcon)
	local units = {
		"boss1", "boss2", "boss3", "boss4", "boss5",
		"target", "focus", "mouseover", "targettarget", "focustarget",
	};
	for index = 1, math.min(40, GetNumRaidMembers() or 0) do
		units[#units + 1] = "raid"..index.."target";
	end
	for _, unit in ipairs(units) do
		if UnitExists(unit) and not UnitIsDeadOrGhost(unit)
			and self:Entry(UnitGUID(unit)) == entry then
			local guid = UnitGUID(unit);
			local icon = GetRaidTargetIndex and GetRaidTargetIndex(unit);
			if icon ~= expectedIcon and not self:GroupInCombat() then
				local attempts = self.markAttempts[entry] or 0;
				if attempts < 3 and SetRaidTarget then
					self.markAttempts[entry] = attempts + 1;
					pcall(SetRaidTarget, unit, expectedIcon);
					icon = GetRaidTargetIndex and GetRaidTargetIndex(unit);
				end
			end
			if icon == expectedIcon then
				self.bossNames=self.bossNames or {}; self.bossNames[entry]=UnitName(unit); return guid;
			end
			if (self.markAttempts[entry] or 0) >= 3 and not self.markFailureNotice then
				self.markFailureNotice = true;
				self:Message("не удалось поставить метку; поставь Череп на Век'нилаша и Звезду на Век'лора вручную до пула.");
			end
		end
	end
	return nil;
end

function UnBotTwinEmperors:ArmFromPreset()
	if self.playerTank and self.playerTank:Selected() then self.tanks:StopOnly(); self.playerTank:Stop(); self:Message("№3 выбран: один паладин и игрок. Подготовка и пул — отдельными кнопками /ubtwins tanks."); return; end
	if self:GroupInCombat() then
		self.enabled = false;
		self.manual = false;
		self.suppressed = true;
		self:Message("призыв начат в бою; метки нельзя ставить, повтори подготовку после выхода из боя.");
		return;
	end
	self:Finish();
	self.manual = false;
	self.suppressed = false;
	self.enabled = true;
	self.cooldownUntil = 0;
	self.nextScan = 0;
	self.armExpiresAt = GetTime() + 900;
	self.waitingForRoster = true;
	self:Message("автометки включены: ищу обоих боссов в целях рейда и boss-рамках; череп — Век'нилаш, звезда — Век'лор.");
	self:Prepare();
end

function UnBotTwinEmperors:SquadReady()
	if self.playerTank and self.playerTank:Selected() then self.playerTank:Show(); return; end
	if self.formation then self.formation:AfterSummon(); end
	if not self.enabled or not self.waitingForRoster then return; end
	self.waitingForRoster = false;
	self:Prepare();
end

function UnBotTwinEmperors:Prepare()
	if self.playerTank and self.playerTank:Selected() then return; end
	if not self.enabled or self.prepared or (GetNumRaidMembers() or 0) == 0 then return; end
	-- Boss icons are independent of bot preparation; saved progress only gates bot commands.
	local veknilash = self:MarkedUnit(15275, 8); -- skull: physical damage
	local veklor = self:MarkedUnit(15276, 1); -- star: magical damage
	if veknilash then self.marks[15275] = veknilash; end
	if veklor then self.marks[15276] = veklor; end
	if not self.marks[15275] or not self.marks[15276] then return; end
	if self.formation then
		local f=self.formation; local profile=f:Profile();
		if f.active or f.pendingAuto or f.resume
			or (not (self.retreat and self.retreat:IsMobile()) and profile and profile.enabled and profile.points and not f.prepared)
			or (not (self.retreat and self.retreat:IsMobile()) and profile and profile.preparation and profile.preparation.status=="active" and not f.prepared) then return; end
	end
	if self.tanks and (self.tanks.stage or self.tanks.restoring) then return; end
	if self.waitingForRoster and not self.active then return; end
	local casters = self:Casters();
	if #casters == 0 then
		if not self.noCasterNotice then
			self.noCasterNotice = true;
			self:Message("нет онлайн-магов/варлоков из реестра; жду состав для фокуса Век'лора.");
		end
		return;
	end
	self.noCasterNotice = nil;
	self.casters = casters;
	self.casterNames = {};
	for _, name in ipairs(casters) do self.casterNames[name] = true; end
	if self.formation and self.formation.prepared then self.formation:AssignTargets();
	else
		if not self.active then self:Queue("@dps rti skull"); end
		for _, name in ipairs(casters) do self:Queue("rti star", name); end
	end
	self.prepared = true;
	self.prepareDoneAt = nil;
	if self.active then
		self.refocusAt = GetTime() + 0.2;
		self.casterCheckAt = GetTime() + 15;
	end
	self:Message("метки проверены: череп — Век'нилаш, звезда — Век'лор. Назначаю магам и варлокам Звезду.");
end

function UnBotTwinEmperors:QueueCasterAttack()
	if self.retreat and self.retreat.mobile then return false; end
	if not self.active or not self.prepared then return false; end
	local casters = self:Casters();
	if #casters == 0 then return false; end
	self.casters = casters;
	self.casterNames = {};
	for _, name in ipairs(casters) do
		self.casterNames[name] = true;
		if not self:Queue("rti star", name)
			or not self:Queue("attack rti target", name) then return false; end
	end
	return true;
end

function UnBotTwinEmperors:Finish(reason)
	local hadAssignments = self.prepared or self.active or self.casters;
	local hadFormation = self.formation and (self.formation.prepared or self.formation.active);
	local resetTargets = hadAssignments and not hadFormation and not self:GroupInCombat()
		and not (self.tanks and self.tanks:AutoRestoreBlocked());
	if self.tanks then self.tanks:Stop(reason or "подготовка завершена"); end
	self.queue = {};
	self.prepared = false;
	self.active = false;
	self.casters = nil;
	self.casterNames = nil;
	self.prepareDoneAt = nil;
	self.refocusAt = nil;
	self.fightExpiresAt = nil;
	self.endCheckAt = nil;
	self.marks = {};
	self.markAttempts = {};
	self.markFailureNotice = nil;
	self.refocuses = 0;
	self.warnings = 0;
	self.nextHealWarning = 0;
	self.noCasterNotice = nil;
	self.wrongFocusHits = 0;
	self.wrongFocusRetries = 0;
	self.nextWrongFocusRetryAt = nil;
	self.casterFocusRetries = 0;
	self.armExpiresAt = nil;
	self.waitingForRoster = nil;
	self.cooldownUntil = GetTime() + 5;
	if resetTargets and (GetNumRaidMembers() or 0) > 0 then
		self:Send("@dps rti skull");
	end
	if reason then
		self:Message(reason..(resetTargets and ". Цели ДД возвращены на череп." or "."));
	end
end

function UnBotTwinEmperors:Start()
	if self.groupControl then self.groupControl.deaths={}; self.groupControl.firstDeathAt=nil; end
	if not self.enabled or self.active then return; end
	if not self.prepared or not self.marks[15275] or not self.marks[15276] then
		self:Message("бой начался до назначения целей; проверь Череп и Звезду, продолжу попытки фокуса.");
	end
	self.active = true;
	self.startedAt = GetTime();
	self.fightExpiresAt = self.startedAt + 900;
	self.lastBossAt = self.startedAt;
	self.refocusAt = self.startedAt + 0.2;
	self.refocuses = 0;
	self.warnings = 0;
	self.casterDamage = 0;
	self.casterCheckAt = self.startedAt + 15;
	self.casterFocusRetries = 0;
	self.wrongFocusHits = 0;
	self.wrongFocusRetries = 0;
	self.nextWrongFocusRetryAt = 0;
	if self.tanks then self.tanks:Pull(); end
	self:Message("бой: маги и варлоки держат звезду, прочие ДД — череп. "
		..(self.retreat and self.retreat.mobile and "Оба танка подвижны; после телепорта меняют босса." or self.tanks and self.tanks.retreatMode and "Основной танк ведёт Череп; второй — пассивный резерв." or self.tanks and self.tanks.armed and "Танки удерживают подготовленные стороны." or "Разведение танков не подготовлено: /ubtwins tanks."));
end

SLASH_UNBOTTWINS1 = "/ubtwins";
SlashCmdList.UNBOTTWINS = function(message)
	local state = UnBotTwinEmperors;
	local command = string.lower(string.match(message or "", "^%s*(%S+)") or "status");
	if command == "tanks" then
		state.tanks:Show();
	elseif command == "on" then
		if state:GroupInCombat() then
			state:Message("включение возможно до боя: нужны две проверенные метки.");
			return;
		end
		state:Finish();
		state.manual = true;
		state.suppressed = false;
		state.enabled = true;
		state.cooldownUntil = 0;
		state:Message("включена. По очереди выдели Век'нилаша и Век'лора: поставлю череп и звезду, затем назначу цели ДД.");
	elseif command == "off" then
		state.manual = false;
		state.suppressed = true;
		state.enabled = false;
		state:Finish("выключена");
	else
		state:Message("автостратегия "..(state:Enabled() and "ВКЛ" or "ВЫКЛ").."; /ubtwins on | off | tanks.");
	end
end;

UnBotTwinEmperorsFrame = CreateFrame("Frame", "UnBotTwinEmperorsFrame");
UnBotTwinEmperorsFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
UnBotTwinEmperorsFrame:RegisterEvent("PLAYER_REGEN_ENABLED");
UnBotTwinEmperorsFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
UnBotTwinEmperorsFrame:RegisterEvent("CHAT_MSG_WHISPER");
UnBotTwinEmperorsFrame:RegisterEvent("CHAT_MSG_ADDON");
UnBotTwinEmperorsFrame:RegisterEvent("CHAT_MSG_SYSTEM");
UnBotTwinEmperorsFrame:RegisterEvent("UI_ERROR_MESSAGE");
UnBotTwinEmperorsFrame:RegisterEvent("UI_INFO_MESSAGE");
UnBotTwinEmperorsFrame:RegisterEvent("PLAYER_LOGIN");
UnBotTwinEmperorsFrame:RegisterEvent("PLAYER_LOGOUT");
UnBotTwinEmperorsFrame:SetScript("OnEvent", function(self, event, ...)
	local state = UnBotTwinEmperors;
	if state.groupControl and state.groupControl:Event(event, ...) then return; end
	if state.playerTank and state.playerTank:Selected() and state.playerTank:Event(event, ...) then return; end
	if event == "PLAYER_LOGIN" then
		for _,log in ipairs((UnBotSquadConfig and UnBotSquadConfig.twinFormationLogs) or {}) do
			if log.status=="recording" then log.status="interrupted_unknown"; end
		end
		return;
	elseif event == "PLAYER_LOGOUT" then
		if state.formation then state.formation:SaveCheckpoint(); end
		if state.tanks then state.tanks:FinishLog("reload_or_logout"); end
		return;
	elseif event == "CHAT_MSG_SYSTEM" or event == "UI_ERROR_MESSAGE" or event == "UI_INFO_MESSAGE" then
		local first,second=...; local text=type(first)=="string" and first or second;
		if state.tanks and (event~="CHAT_MSG_SYSTEM" or not UnBotSummonLog or not UnBotSummonLog.IsSystemChat or not UnBotSummonLog.IsSystemChat(text)) then state.tanks:Log(text,event); end
		if event=="CHAT_MSG_SYSTEM" and state.retreat then state.retreat:CommandFeedback(text); end
		return;
	elseif event == "PLAYER_ENTERING_WORLD" then
		if state.active or state.prepared then state:Finish("выход из зоны боя"); end
		return;
	elseif event == "PLAYER_REGEN_ENABLED" then
		if state.active then state.endCheckAt = GetTime() + 5; end
		return;
	elseif event == "CHAT_MSG_WHISPER" then
		if state.tanks then state.tanks:Reply(select(1, ...), select(2, ...)); end
		if not state.enabled or state.retreat and state.retreat.blocked then return; end
		local response = select(1, ...);
		local sender = select(2, ...);
		if type(response) ~= "string" then return; end
		if not sender or not UnBotBotRegistry or not UnBotBotRegistry.bots
			or not UnBotBotRegistry.bots[sender]
			or GetTime() - (state.lastCommandAt or -1000) > 5 then return; end
		local lower = string.lower(response);
		if (string.find(lower, "rti", 1, true) or string.find(lower, "attack", 1, true))
			and (string.find(lower, "unknown", 1, true)
				or string.find(lower, "cannot", 1, true)
				or string.find(lower, "invalid", 1, true)
				or string.find(lower, "not found", 1, true)
				or string.find(lower, "неизвест", 1, true)
				or string.find(lower, "не могу", 1, true)
				or string.find(lower, "невозможно", 1, true)) then
			state.enabled = false;
			state.manual = false;
			state.suppressed = true;
			state:Finish("сервер отклонил команду фокуса; повторов не будет");
		end
		return;
	end
	if not state.enabled then return; end
	local eventType = select(2, ...);
	local sourceGuid, destGuid = select(3, ...), select(6, ...);
	local sourceEntry, destEntry = state:Entry(sourceGuid), state:Entry(destGuid);
	if (sourceEntry ~= 15275 and sourceEntry ~= 15276)
		and (destEntry ~= 15275 and destEntry ~= 15276) then return; end
	if eventType == "UNIT_DIED" or eventType == "PARTY_KILL" then
		if state.active and (destEntry == 15275 or destEntry == 15276) then
			state:Finish("близнец погиб, бой завершается");
		end
		return;
	end
	if not state.active then state:Start(); end
	if not state.active then return; end
	local now = GetTime();
	state.lastBossAt = now;
	local spellId = select(9, ...);
	if state.tanks then state.tanks:Combat(eventType, sourceEntry, destEntry, spellId, ...); end
	if state.retreat and state.retreat.blocked then return; end
	if destEntry == 15276 and (eventType == "SPELL_DAMAGE"
		or eventType == "SPELL_PERIODIC_DAMAGE")
		and state.casterNames and state.casterNames[select(4, ...)] then
		state.casterDamage = state.casterDamage + (tonumber((select(12, ...))) or 0);
	end
	if destEntry == 15275 and (eventType == "SPELL_MISSED"
		or eventType == "RANGE_MISSED")
		and select(12, ...) == "IMMUNE"
		and state.casterNames and state.casterNames[select(4, ...)] then
		state.wrongFocusHits = (state.wrongFocusHits or 0) + 1;
		if state.wrongFocusHits >= 6 and (state.wrongFocusRetries or 0) < 2
			and now >= (state.nextWrongFocusRetryAt or 0) then
			state.wrongFocusRetries = state.wrongFocusRetries + 1;
			state.nextWrongFocusRetryAt = now + 12;
			state.wrongFocusHits = 0;
			state.refocusAt = now + 0.2;
			state:Message("маги/варлоки бьют Век'нилаша в иммун; повторяю им Звезду и команду атаки.");
		end
	end
	if sourceEntry == 15275 and eventType == "SPELL_AURA_APPLIED"
		and spellId == 800 and state.refocuses < 32 then
		state.refocusAt = now + 3;
		state:Message("телепорт: повторю фокус ДД; "
			..(state.retreat and state.retreat.mobile and "оба танка перехватывают новых боссов без возврата на точки." or state.tanks and state.tanks.retreatMode and "основной танк снова берёт Череп; резерв остаётся на месте." or state.tanks and state.tanks.armed and "танки меняют боссов, сохраняя свои стороны." or "разведение танков не включено."));
	elseif eventType == "SPELL_HEAL" and spellId == 7393
		and (destEntry == 15275 or destEntry == 15276) then
		local amount, overheal = select(12, ...), select(13, ...);
		if type(amount) == "number" and amount > (tonumber(overheal) or 0)
			and state.warnings < 4 and now >= (state.nextHealWarning or 0) then
			state.warnings = state.warnings + 1;
			state.nextHealWarning = now + 20;
			state:Message("|cffff4444близнецы лечат друг друга — разведи их дальше!|r");
		end
	end
end);

UnBotTwinEmperorsFrame:SetScript("OnUpdate", function()
	local state = UnBotTwinEmperors;
	if state.groupControl then state.groupControl:Tick(); if state.groupControl.wiping then return; end end
	if state.playerTank and (state.playerTank:Selected() or state.playerTank.active) then state.playerTank:Tick(); return; end
	if state.tanks then state.tanks:Tick(); end
	if state.retreat and state.retreat.blocked then return; end
	if state.enabled and not state:Enabled() then
		state.enabled = false;
		state:Finish("выключена в пресете");
		return;
	end
	if not state.enabled and state:Enabled() then state.enabled = true; end
	if not state.enabled then return; end
	local now = GetTime();
	if now < (state.cooldownUntil or 0) then return; end
	if state.active and now >= (state.fightExpiresAt or 0) then
		state.enabled = false;
		state.manual = false;
		state.suppressed = true;
		state:Finish("достигнут лимит 15 минут");
		return;
	end
	if not state.prepared and not state.active and state.armExpiresAt
		and now >= state.armExpiresAt then
		state.enabled = false;
		state.manual = false;
		state.suppressed = true;
		state:Finish("не нашёл обоих боссов за 15 минут; автометки остановлены");
		return;
	end
	if state.active and state.endCheckAt and now >= state.endCheckAt then
		state.endCheckAt = now + 5;
		if not state:GroupInCombat() and now - (state.lastBossAt or now) >= 5 then
			state:Finish("бой завершился");
			return;
		end
	end
	if state.active and state.casterCheckAt and now >= state.casterCheckAt then
		if (state.casterDamage or 0) == 0 then
			if state.prepared and (state.casterFocusRetries or 0) < 1 then
				state.casterFocusRetries = state.casterFocusRetries + 1;
				state.casterCheckAt = now + 15;
				state.refocusAt = now + 0.2;
				state:Message("нет урона магов/варлоков по Век'лору; повторяю им Звезду и атаку один раз.");
			else
				state.casterCheckAt = nil;
				state:Message("|cffff4444магический урон по Век'лору не подтверждён; проверь наличие босса, Звезду и ответы ботов.|r");
			end
		else
			state.casterCheckAt = nil;
			state:Message("урон магов/варлоков по Век'лору подтверждён: "..math.floor(state.casterDamage)..".");
		end
	end
	if not state.prepared and now >= (state.nextScan or 0) then
		state.nextScan = now + 0.5;
		state:Prepare();
	end
	if #state.queue > 0 and now >= state.nextSend then
		local job = table.remove(state.queue, 1);
		if not state:Send(job.command, job.recipient) then
			state.enabled = false;
			state.manual = false;
			state.suppressed = true;
			state:Finish("нет рейда для отправки команд");
			return;
		end
		state.nextSend = now + 0.4;
		if #state.queue == 0 then state.prepareDoneAt = now + 1; end
	end
	if state.prepared and state.prepareDoneAt and now >= state.prepareDoneAt then
		state.prepareDoneAt = nil;
		state:Message(state.active
			and "цели назначены: маги/варлоки — звезда, прочие ДД — череп."
			or "цели ДД готовы: череп — Век'нилаш, звезда — Век'лор. Разведение танков: /ubtwins tanks.");
	end
	if state.active and state.refocusAt and now >= state.refocusAt then
		if not state.prepared or #state.queue > 0 or state.prepareDoneAt then return; end
		state.refocusAt = nil;
		if state.refocuses < 32 and state:QueueCasterAttack() then
			state.refocuses = state.refocuses + 1;
		end
	end
end);

-- Explicit Twin Emperors tank scenario. No protected target/movement API.
-- Named positions and go replies follow Playerbots PositionAction/GoAction.
do
	local T = {slots={}, queue={}, nextSend=0, swaps=0, lastSent={},commandInterval=1.1,maxAttempts=3,retryPause=3};
UnBotTwinEmperors.tanks = T;
T.desired = {
	co={stay=true,tank=true,passive=false,dps=false,["dps aoe"]=false,follow=false,guard=false,runaway=false,["flee from adds"]=false,
		close=false,behind=false,["tank face"]=false,["tank assist"]=false,["tank aoe"]=false,
		["dps assist"]=false,formation=false,flee=false,["avoid aoe"]=false,grind=false,
		["attack weak"]=false,["attack force"]=false,["move from group"]=false},
	nc={stay=true,passive=false,follow=false,guard=false,runaway=false,["flee from adds"]=false,
		grind=false,["move random"]=false,["move from group"]=false},
};

function T:Message(text)
	self:Log(text);
	self.status=text; UnBotTwinEmperors:Message(text); self:Refresh();
end

function T:LogText(value)
	if UnBotSummonLog and UnBotSummonLog.Text then return UnBotSummonLog.Text(value,2048); end
	local text=tostring(value or ""); if #text<=2048 then return text; end
	local cut=2048; while cut>0 and (text:byte(cut+1) or 0)>=128 and (text:byte(cut+1) or 0)<192 do cut=cut-1; end
	return text:sub(1,cut).." [truncated]";
end

function T:BeginLog(source)
	if self.log then self:FinishLog("next_run"); end
	UnBotSquadConfig=UnBotSquadConfig or {};
	UnBotSquadConfig.twinFormationLogs=UnBotSquadConfig.twinFormationLogs or {};
	local formation=UnBotTwinEmperors.formation; local owner,mode=formation:Key();
	local log={schema=1,version="6.38.214",clientVersion=GetAddOnMetadata and GetAddOnMetadata("UnBotCustom","Version"),
		startedAt=time and time() or 0,clockStart=GetTime(),status="recording",source=source,
		owner=owner,mode=mode,context=self:Context(),commandInterval=self.commandInterval,
		events={},names={},first=1,count=0,bytes=0,serial=0,dropped=0};
	table.insert(UnBotSquadConfig.twinFormationLogs,1,log);
	while #UnBotSquadConfig.twinFormationLogs>3 do table.remove(UnBotSquadConfig.twinFormationLogs); end
	self.log=log; self.logIdleAt=nil; self.lastLogCommandAt=nil;
	self:Log("Запись действий Близнецов начата. Интервал команд: "..self.commandInterval.." с; после теста /reload для записи SavedVariables\\UnBot.lua.","start");
end

function T:Log(text,kind,target,gapMs)
	local log=self.log; if not log then return; end
	local now=GetTime(); log.serial=log.serial+1;
	local entry={seq=log.serial,t=math.floor((now-log.clockStart)*1000+0.5),kind=kind or "stage",
		text=self:LogText(text),target=target,stage=self.stage or "idle",restoring=self.restoring and true or false,
		queue=#self.queue,gapMs=gapMs,attempt=self.pending and self.pending.attempts or nil};
	entry.bytes=#entry.text+#entry.kind+#(target or "")+192;
	while log.count>0 and (log.count>=4000 or log.bytes+entry.bytes>2*1024*1024) do
		local old=log.events[log.first]; log.bytes=log.bytes-old.bytes; log.events[log.first]=nil;
		log.first=log.first%4000+1; log.count=log.count-1; log.dropped=log.dropped+1;
	end
	log.events[(log.first+log.count-1)%4000+1]=entry;
	log.count=log.count+1; log.bytes=log.bytes+entry.bytes; log.lastEventMs=entry.t;
end

function T:FinishLog(reason)
	local log=self.log; if not log then return; end
	self:Log(reason,"end"); log.status=reason; log.endedAt=time and time() or 0;
	log.pending=self.pending and {command=self.pending.command,name=self.pending.name} or nil;
	self.log=nil; self.logIdleAt=nil;
end

function T:TickLog(now)
	if not self.log then return; end
	if now-self.log.clockStart>=1800 then self:FinishLog("log_timeout"); return; end
	local state=UnBotTwinEmperors; local formation=state.formation;
	if self.stage or self.restoring or self.pending or #self.queue>0 or self.armed or self.markCheckUntil
		or formation.active or formation.resume or #state.queue>0 then self.logIdleAt=nil; return; end
	self.logIdleAt=self.logIdleAt or now;
	if now-self.logIdleAt>=10 then
		local ready=formation.prepared or state.retreat and state.retreat:FreeReady();
		self:FinishLog(ready and "prepared" or "stopped");
	end
end

function T:SetProgress(label,total)
	self.progress={label=label,total=total,done=0};
	if UnBotTwinEmperors.formation then UnBotTwinEmperors.formation:SaveCheckpoint(); end
	self:Log(label..": 0/"..total,"progress"); return self.progress;
end
function T:AdvanceProgress(progress)
	if not progress or self.progress~=progress then return; end
	progress.done=math.min(progress.total,progress.done+1);
	UnBotTwinEmperors.formation:SaveCheckpoint();
	self:Log(progress.label..": "..progress.done.."/"..progress.total,"progress");
end
function T:TrackQueuedProgress(label,done)
	local progress=self:SetProgress(label,#self.queue);
	if #self.queue==0 then if done then done(); end return; end
	for i,job in ipairs(self.queue) do
		local previous=job.done; local last=i==#self.queue;
		job.done=function(value)
			self:AdvanceProgress(progress); if previous then previous(value); end
			if last and done then done(); end
		end;
	end
end

function T:Store()
	UnBotSquadConfig=UnBotSquadConfig or {};
	UnBotSquadConfig.twinTankRecovery=UnBotSquadConfig.twinTankRecovery or {};
	local key=(GetRealmName() or "")..":"..(UnitName("player") or "");
	local root=UnBotSquadConfig.twinTankRecovery;
	root[key]=root[key] or {}; return root[key];
end

function T:AutoRestoreBlocked()
	for _,record in pairs(self:Store()) do
		if type(record)=="table" and record.noAutoRestore then return true; end
	end
	return false;
end

function T:Context()
	local name,kind=GetInstanceInfo(); return (name or "")..":"..(kind or "");
end

function T:InRoom()
	local name,kind=GetInstanceInfo();
	return kind=="raid" and name and (name:find("Ahn",1,true) or name:find("Кираж",1,true));
end

function T:Unit(name)
	for i=1,math.min(40,GetNumRaidMembers() or 0) do
		local unit="raid"..i;
		if UnitName(unit)==name and name~=UnitName("player") and UnitIsConnected(unit)
			and not UnitIsDeadOrGhost(unit) and UnBotBotRegistry and UnBotBotRegistry.bots
			and UnBotBotRegistry.bots[name] then return unit; end
	end
end

function T:Busy()
	return UnBotRaidReserveOtherAutomationActive and UnBotRaidReserveOtherAutomationActive(false,false,true)
		or (UnBotSquadBuilder and UnBotSquadBuilder.postSummonSequence)
		or (UnBotAltStrategies and UnBotAltStrategies.active)
		or (UnBotRaidReserve and UnBotRaidReserve.active)
		or (UnBotBotFix and UnBotBotFix.active)
		or (UnBotSquadSummon and UnBotSquadSummon.active)
		or (UnBotPVPSummon and UnBotPVPSummon.active);
end

function T:Job(command,name,wait,done,pause)
	local formation=UnBotTwinEmperors.formation;
	if not wait and formation and formation:CommandWasSent(command,name) then
		if done then formation:AfterQueue(done); end return;
	end
	if #self.queue>=192 then self:Stop("переполнение очереди танков"); return; end
	if not pause and (self.restoring or (self.stage and self.stage:find("^formation_"))) then pause=self.commandInterval; end
	self.queue[#self.queue+1]={command=command,name=name,wait=wait,done=done,pause=pause};
end

function T:ReadWave(work,command,wait,done)
	local remaining=#work; local observed={};
	local progress=self.progress;
	if remaining==0 then done(observed); return; end
	for _,member in ipairs(work) do
		local m=member;
		self:Job(command,m.name,wait,function(value)
			observed[m.name]=value; remaining=remaining-1; self:AdvanceProgress(progress);
			if remaining==0 then done(observed); end
		end);
	end
end

function T:Commands(name,channel,wanted,actual)
	local minus,plus={},{};
	for key,value in pairs(wanted) do
		if value~=(actual[key]==true) then
			table.insert(value and plus or minus,(value and "+" or "-")..key);
		end
	end
	table.sort(minus); table.sort(plus);
	for _,key in ipairs(plus) do minus[#minus+1]=key; end
	local command=channel.." ";
	for _,key in ipairs(minus) do
		if #command+#key>230 then self:Job(command,name); command=channel.." "; end
		command=command..(#command>#channel+1 and "," or "")..key;
	end
	if #command>#channel+1 then self:Job(command,name); end
end

function T:Matches(wanted,actual)
	for key,value in pairs(wanted) do if value~=(actual[key]==true) then return false,key; end end
	return true;
end

function T:Verify(slot,channel,done)
	self:Job(channel.." ?",slot.name,channel,function(actual)
		local ok,key=self:Matches(self.desired[channel],actual);
		if not ok then self:Stop(slot.name..": сервер не подтвердил "..channel.." "..key); return; end
		if done then done(); end
	end);
end

function T:Select(side)
	if self.armed or self.stage or self.pending or #self.queue>0 or self.restoring then self:Message("сначала останови текущую операцию танков"); return; end
	if UnBotTwinEmperors:GroupInCombat() then self:Message("выбор танков возможен до боя"); return; end
	local name=UnitName("target"); local unit=name and self:Unit(name);
	local profile=unit and UnBotBotRegistry.bots[name];
	local formation=UnBotTwinEmperors.formation;
	if not unit or not formation:IsTank({className=profile.className,spec=formation:Spec(profile)}) then
		self:Message("выдели живого онлайн-танка из реестра в своём рейде"); return;
	end
	local other=self.slots[3-side];
	if other and other.name==name then
		local previous=self.slots[side];
		if not previous or previous.name==name then self:Message("для двух сторон нужны разные танки"); return; end
		self.slots[3-side]={name=previous.name,side=3-side,position="ub_twins_"..(3-side),icon=side==1 and "star" or "skull"};
	end
	self.slots[side]={name=name,side=side,position="ub_twins_"..side,icon=side==1 and "skull" or "star"};
	self.selectionOwner,self.selectionMode=formation:Key();
	local saved=formation:Profile(true); if saved then
		saved.selectedTanks=saved.selectedTanks or {};
		for index,slot in pairs(self.slots) do saved.selectedTanks[index]=slot.name; end
	end
	self:Message("сторона "..(side==1 and "Черепа" or "Звезды")..": "..name);
end

function T:AutoSelect()
	local formation=UnBotTwinEmperors.formation;
	if self.stage or self.armed or self.restoring or self.pending or #self.queue>0 or formation.active
		or not formation:Key() or not self:InRoom() or UnBotTwinEmperors:GroupInCombat() then return; end
	local profile=formation:Profile(true); local chosen=formation:PickTanks(profile,formation:Roster()); if not chosen then return; end
	local owner,mode=formation:Key(); local same=self.selectionOwner==owner and self.selectionMode==mode;
	for side=1,2 do
		local previous=self.slots[side]; local name=chosen[side].name;
		if not same or not previous or previous.name~=name then
			self.slots[side]={name=name,side=side,position="ub_twins_"..side,icon=side==1 and "skull" or "star",
				point=profile.points and formation:Copy(profile.points[side])};
		end
	end
	self.selectionOwner,self.selectionMode=owner,mode;
	profile.selectedTanks=profile.selectedTanks or {}; for side=1,2 do profile.selectedTanks[side]=chosen[side].name; end
end

function T:Place(side)
	local slot=self.slots[side];
	if not slot then self:Message("сначала выбери танка этой стороны из цели"); return; end
	if self.armed or self.stage or self.pending or #self.queue>0 or self.restoring then self:Message("дождись завершения текущей операции"); return; end
	if not self:InRoom() or UnBotTwinEmperors:GroupInCombat() or self:Busy() or not self:Unit(slot.name)
		or UnitIsDeadOrGhost("player") or (GetUnitSpeed and GetUnitSpeed("player")>0) then
		self:Message("расстановка: стой на нужном краю Храма Ан'Киража вне боя, дождись завершения других операций"); return;
	end
	if self:Store()[tostring(side)] then self:Message("для замены точки сначала нажми «Стандарт: reset botAI»"); return; end
	self.context=self:Context(); self.expires=GetTime()+90; self.stage="reading"; self.placing=slot;
	slot.verified=false; slot.original={};
	self:Job("co ?",slot.name,"co",function(actual) slot.original.co=actual; end);
	self:Job("nc ?",slot.name,"nc",function(actual)
		slot.original.nc=actual;
		self:Store()[tostring(side)]={name=slot.name,context=self.context,co=slot.original.co,nc=actual};
		self:Job("summon",slot.name,nil,function()
			self.stage="arrival"; self.deadline=GetTime()+20; self.nearAt=nil;
		end);
	end);
	self:Job("rti ?",slot.name,"rti",function(icon)
		slot.original.rti=icon; self:Store()[tostring(side)].rti=icon;
	end);
	self:Message(slot.name..": читаю исходные стратегии; затем призову к тебе и закреплю эту сторону. Стой на месте.");
end

function T:Configure(slot)
	self.stage="configuring";
	-- Set anchors directly: the stay shortcut also resets AI and touches unrelated state.
	self:Job("position "..slot.position.." set",slot.name,"set");
	self:Job("position stay set",slot.name,"set");
	for _,channel in ipairs({"co","nc"}) do self:Commands(slot.name,channel,self.desired[channel],slot.original[channel]); end
	self:Job("position "..slot.position.." ?",slot.name,"position",function(point) slot.point=point; end);
	self:Job("position stay ?",slot.name,"position",function(point)
		if not self:Near(point,slot.point) then self:Stop(slot.name..": серверный stay-якорь не совпал со стороной"); end
	end);
	self:Job("go "..slot.position,slot.name,"go",nil,4);
	self:Job("go ?",slot.name,"coords",function(point)
		if not self:Near(point,slot.point) then self:Stop(slot.name..": возвращение в точку не подтверждено"); return; end
		slot.verified=true; self.stage=nil; self.placing=nil; self.expires=nil;
		self:Message(slot.name..": сторона сохранена, go и боевой stay подтверждены сервером.");
		if self:SidesReady() and UnBotTwinEmperors.formation:EnsurePreset() then UnBotTwinEmperors.formation:Save();
		else self:BeginMarkCheck(); end
	end);
end

function T:Near(a,b)
	if not a or not b then return false; end
	local dx,dy=a.x-b.x,a.y-b.y;
	-- Dungeon replies outside 0..100 are world coordinates in yards. Go uses MoveNear.
	if a.x<0 or a.y<0 or b.x<0 or b.y<0 or a.x>100 or a.y>100 or b.x>100 or b.y>100 then
		return dx*dx+dy*dy<=25;
	end
	return math.abs(dx)<=0.02 and math.abs(dy)<=0.02;
end

function T:SidesReady()
	local a,b=self.slots[1],self.slots[2];
	return a and b and a.verified and b.verified and self:Unit(a.name) and self:Unit(b.name)
		and self.context==self:Context() and self:InRoom() and not self:Near(a.point,b.point) or false;
end

function T:MarksReady()
	local state=UnBotTwinEmperors;
	return state.marks[15275] and state.marks[15276] and state.prepared or false;
end

function T:BeginMarkCheck()
	if not self:SidesReady() or self.armed or self.stage or self.pending or #self.queue>0 or self.restoring
		or self:Busy() or UnBotTwinEmperors:GroupInCombat() then return false; end
	local state=UnBotTwinEmperors;
	state.manual=true; state.suppressed=false; state.enabled=true; state.cooldownUntil=0; state.nextScan=0;
	self.markCheckUntil=GetTime()+60;
	state:Prepare();
	if not self:MarksReady() then self:Message("шаг 2: жду автоматические Череп и Звезду; если боссы не видны, по очереди выдели их"); end
	self:Refresh(); return true;
end

function T:CanStartFight()
	local state=UnBotTwinEmperors;
	if state.retreat and state.retreat:IsMobile() then return state.retreat:CanStartFree(); end
	local formation=state.formation; local profile=formation and formation:Profile();
	if profile and (profile.fightControl=="retreat_manual" or profile.fightControl=="retreat_auto") and not formation.prepared then return false; end
	if profile and profile.enabled and profile.points and not formation.prepared then return false; end
	if formation and formation.prepared and not formation:SameRoster() then return false,"изменились участники расстановки или их подгруппы"; end
	return self:SidesReady() and self:MarksReady() and not self.stage and not self.pending
		and #self.queue==0 and not self.restoring and not self:Busy() and not state.active
		and #state.queue==0 and not state.prepareDoneAt and not self.startRequested
		and not UnBotTwinEmperors:GroupInCombat() and not UnitIsDeadOrGhost("player");
end

function T:StartFight()
	if UnBotTwinEmperors.retreat and UnBotTwinEmperors.retreat.blocked then return UnBotTwinEmperors.retreat:CheckTargets(true); end
	if UnBotTwinEmperors.retreat and UnBotTwinEmperors.retreat:IsMobile() then return UnBotTwinEmperors.retreat:StartFree(); end
	if not self:CanStartFight() then self:Message("начать бой нельзя: заверши расстановку обоих танков и проверку меток, дождись готовности вне боя"); return false; end
	local formation=UnBotTwinEmperors.formation;
	local participants=self.slots;
	if formation and formation.prepared and not formation:SameRoster() then self:Message("состав изменился: повтори сохранённую расстановку"); return false; end
	-- Persist the no-rollback boundary before any pull checks or commands.
	for _,member in ipairs(formation and formation.prepared and formation.participants or participants) do
		for _,record in pairs(self:Store()) do
			if type(record)=="table" and record.name==member.name and record.context==self:Context() then record.noAutoRestore=true; end
		end
	end
	if not self.log then self:BeginLog("start_fight"); end
	for _,member in ipairs(formation and formation.prepared and formation.participants or participants) do self.log.names[member.name]=true; end
	if formation then formation:InvalidateCheckpoint("fight"); end
	self.stage="pull_check"; self.expires=GetTime()+math.min(300,#participants*8+20);
	self.startRequested={checking=true};
	self:SetProgress("Перед боем: позиции танков",#participants);
	local index=0;
	local function checkNext()
		index=index+1; local member=participants[index];
		if not member then
			if formation and formation.prepared then formation:ReleaseForPull();
			else self.stage=nil; self.expires=nil; self.startRequested=nil; self:StartFightNow(); end return;
		end
		self:Job("go ?",member.name,"coords",function(point)
			if not self:Near(point,member.point) then self:Stop(member.name..": перед пулом бот не на сохранённой точке; повтори расстановку"); return; end
			self:AdvanceProgress(self.progress);
			checkNext();
		end);
	end
	self:Message("перед пулом проверяю позиции только двух танков, затем отправляю снятие временной пассивности без ожидания ответов");
	checkNext(); return true;
end

function T:StartFightNow()
	if not self:CanStartFight() then self:Message("проверка позиций завершена, но подготовка изменилась; бой не начат"); return false; end
	self:Arm(); if not self.armed then return false; end
	self.startRequested={}; self.markCheckUntil=nil;
	local state=UnBotTwinEmperors;
	state:Start();
	-- Let both tank attack commands go first; caster/raid attacks follow them.
	state.refocusAt=nil; state.casterCheckAt=nil;
	if self.frame then self.frame:Hide(); end
	self:Message(self.retreatMode and "начало боя: основной танк атакует Череп, второй остаётся пассивным; затем подключаются ДД. Окно закрыто." or "начало боя: танки атакуют своих близнецов, затем подключаются ДД. Окно закрыто.");
	return true;
end

function T:AttackSent(name)
	if UnBotTwinEmperors.retreat.mobile then return; end
	if not self.retreatMode then self.positionCheckAt=GetTime()+4; end
	if not self.startRequested then return; end
	self.startRequested[name]=true;
	if self.retreatMode and not UnBotTwinEmperors.retreat.mobile then
		if not self.startRequested[self.slots[1].name] then return; end
	else for _,slot in ipairs(self.slots) do if not self.startRequested[slot.name] then return; end end end
	if self.retreatMode and UnBotTwinEmperors.retreat.mobile and not self.bossCombatAt then self.pullWaitUntil=GetTime()+120; end
	self.startRequested=nil; self.dpsAttackAt=GetTime()+2;
	UnBotTwinEmperors.refocusAt=self.dpsAttackAt;
	UnBotTwinEmperors.casterCheckAt=GetTime()+15;
end

function T:Arm()
	if self.stage or self.pending or #self.queue>0 or self.restoring or self:Busy()
		or UnBotTwinEmperors:GroupInCombat() or not self:InRoom() then self:Message("дождись готовности расстановки вне боя"); return; end
	local profile=UnBotTwinEmperors.formation:Profile();
	if profile and (profile.fightControl=="retreat_manual" or profile.fightControl=="retreat_auto") and not UnBotTwinEmperors.formation.prepared then
		self:Message("для отвода сначала примени сохранённую расстановку: основной танк подвижен, второй пассивен"); return;
	end
	local a,b=self.slots[1],self.slots[2];
	if not a or not b or not a.verified or not b.verified or not self:Unit(a.name) or not self:Unit(b.name)
		or self.context~=self:Context() then self:Message("сначала поставь двух танков на разные стороны и дождись подтверждения"); return; end
	if self:Near(a.point,b.point) then self:Message("точки совпадают: останови сценарий и поставь танков на противоположные края"); return; end
	local state=UnBotTwinEmperors;
	state.manual=true; state.suppressed=false; state.enabled=true; state.cooldownUntil=0;
	state:Prepare();
	if not state.marks[15275] or not state.marks[15276] then self:Message("до пула выдели обоих боссов: нужны проверенные Череп и Звезда"); return; end
	a.icon="skull"; b.icon="star"; self.swaps=0; self.lastTeleport=-1000;
	self.armed=true; self.expires=GetTime()+900; self.bossCombatAt=nil; self.pullWaitUntil=nil;
	if UnBotTwinEmperors.retreat and UnBotTwinEmperors.retreat:Arm() then return; end
	self:Message("разведение готово: "..a.name.." — край Черепа; "..b.name.." — край Звезды. После телепорта танки остаются на местах и меняют цели.");
end

function T:Cycle(delay)
	if not self.armed then return; end
	if self.retreatMode then UnBotTwinEmperors.retreat:Intercept(delay); return; end
	self.cycleAt=GetTime()+(delay or 0); self.cycleDeadline=nil;
	self.positionCheckAt=nil;
	self.correctionUsed=false; self.checks={}; self.aggro={}; self.targetRetries=0;
	-- Switch priority immediately: the old RTI must not pull tanks across the room.
	for _,slot in ipairs(self.slots) do self:Job("rti "..slot.icon,slot.name); end
end

function T:Pull()
	if not self.armed then return; end
	self.expires=GetTime()+900;
	self.pullWaitSeconds=UnBotTwinEmperors.retreat.mobile and 120 or 45;
	if not self.bossCombatAt then self.pullWaitUntil=GetTime()+self.pullWaitSeconds; self:Log("атака отправляется; жду подтверждения боя Близнецов до "..self.pullWaitSeconds.." секунд"); end
	self:Cycle(0.5);
end

function T:ConfirmBossCombat(source)
	if self.bossCombatAt then return; end
	self.bossCombatAt=GetTime();
	if self.pullWaitUntil then
		self.pullWaitUntil=nil; if self.cycleDeadline then self.cycleDeadline=GetTime()+14; end
		if self.retreatMode and UnBotTwinEmperors.retreat.deadline then UnBotTwinEmperors.retreat.deadline=GetTime()+14; end
		if self.retreatMode then self:Message(UnBotTwinEmperors.retreat.mobile and "бой подтверждён; проверяю перехват обоих близнецов" or "бой подтверждён; жду агро Черепа на основном танке для отвода"); return; end
		self.checks={}; self.positionCheckAt=GetTime()+4;
		self:Message("бой Близнецов подтверждён; начинаю проверку удержания сторон ("..source..")");
	end
end

function T:Combat(event,source,dest,spell,...)
	if not self.armed then return; end
	local now=GetTime();
	if event=="SWING_DAMAGE" or event=="SWING_MISSED" or event=="RANGE_DAMAGE" or event=="RANGE_MISSED"
		or event=="SPELL_DAMAGE" or event=="SPELL_PERIODIC_DAMAGE" or event=="SPELL_MISSED"
		or (spell==800 and event=="SPELL_AURA_APPLIED") or (spell==7393 and event=="SPELL_HEAL") then
		self:ConfirmBossCombat("combat log: "..event);
	end
	if (source==15275 or source==15276) and (event=="SWING_DAMAGE" or event=="SWING_MISSED"
		or ((event=="SPELL_DAMAGE" or event=="SPELL_MISSED") and (spell==26006 or spell==26613))) then
		self.aggro=self.aggro or {}; self.aggro[source]={name=select(7,...),at=now};
	end
	if self.retreatMode then UnBotTwinEmperors.retreat:Combat(event,source,dest,spell,...); return; end
	if (source==15275 or source==15276) and spell==800 and event=="SPELL_AURA_APPLIED"
		and now-(self.lastTeleport or -1000)>5 then
		if self.swaps>=30 then self:Stop("лимит 30 телепортов; продолжай управление танками вручную"); return; end
		self.lastTeleport=now; self.swaps=self.swaps+1;
		for _,slot in ipairs(self.slots) do slot.icon=slot.icon=="skull" and "star" or "skull"; end
		self.queue={}; self.pending=nil; self:Cycle(2.5);
	elseif spell==7393 and event=="SPELL_HEAL" and (dest==15275 or dest==15276) then
		local amount,over=select(12,...),select(13,...);
		if type(amount)=="number" and amount>(tonumber(over) or 0) and now>(self.lastTeleport or 0)+5 then
			if self.correctionUsed then
				if now>=(self.healCheckAt or now+1) then self:Stop("близнецы продолжают лечиться после возврата танков; проверь края и агро, автоматических повторов больше нет"); end
			else
				self.correctionUsed=true; self.healCheckAt=now+10;
				for _,slot in ipairs(self.slots) do self:Job("go "..slot.position,slot.name,"go"); end
				self:Message("лечение близнецов: один раз возвращаю танков к сохранённым краям");
			end
		end
	end
end

function T:Holding(entry,name)
	local units={"boss1","boss2","boss3","boss4","boss5","target","focus","mouseover"};
	for i=1,math.min(40,GetNumRaidMembers() or 0) do units[#units+1]="raid"..i.."target"; end
	for _,unit in ipairs(units) do
		if UnBotTwinEmperors:Entry(UnitGUID(unit))==entry then
			local victim=UnitName(unit.."target");
			if victim then return victim==name; end
		end
	end
	local hit=self.aggro and self.aggro[entry];
	return hit and hit.name==name and GetTime()-hit.at<=12 or false;
end

function T:StopOnly(reason)
	self:Log(reason or "Ручная отмена очереди без возврата стратегий","cancel"); self:FinishLog("cancelled");
	if UnBotTwinEmperors.retreat then UnBotTwinEmperors.retreat:Cancel(); end
	local state=UnBotTwinEmperors;
	state.enabled=false; state.manual=false; state.suppressed=true;
	state.active=false; state.prepared=false; state.queue={}; state.prepareDoneAt=nil;
	state.refocusAt=nil; state.casterCheckAt=nil; state.endCheckAt=nil; state.casters=nil; state.casterNames=nil;
	state.formation:Cancelled();
	self.armed=false; self.stage=nil; self.placing=nil; self.cycleAt=nil; self.cycleDeadline=nil;
	self.pullWaitUntil=nil; self.bossCombatAt=nil;
	self.positionCheckAt=nil; self.startRequested=nil; self.dpsAttackAt=nil; self.markCheckUntil=nil;
	self.pending=nil; self.queue={}; self.expires=nil; self.restoring=false;
	self.restoreExpires=nil; self.restoreWork=nil; self.restorePhase=nil; self.restoreExplicit=nil; self.formationFailure=nil; self.progress=nil;
	for _,slot in pairs(self.slots) do slot.verified=false; end
	self:Message("очередь остановлена. Возврат стратегий отменён; выбранные танки, точки и исходные снимки сохранены.");
end
function T:ReturnOriginal()
	if UnBotTwinEmperors.groupControl then return UnBotTwinEmperors.groupControl:Reset("вручную"); end
	if UnBotTwinEmperors:GroupInCombat() then self:Stop("возврат исходных настроек запрошен во время боя"); return; end
	self:StopOnly(); self:Restore(true); self:Message("возвращаю исходные стратегии, RTI и стойки питомцев. Кнопка «Стоп» отменяет эту очередь.");
end

function T:Stop(reason)
	local r=UnBotTwinEmperors.retreat;
	if self.armed and r and r.mobile and r.enabled then r:Block(reason or "ошибка команды"); return; end
	if UnBotTwinEmperors:GroupInCombat() then
		self:StopOnly("Остановка в бою: "..(reason or "отмена"));
		self:Message("сценарий остановлен в бою: "..(reason or "отмена")..". Без возврата стратегий и RTI; танки сохраняют настройки сторон. Исходные снимки сохранены для возврата после боя."); return;
	end
	if self:AutoRestoreBlocked() then
		self:StopOnly("Остановка после «Начать бой»: "..(reason or "отмена"));
		self:Message("после «Начать бой» сценарий остановлен без сбросов и возврата настроек: "..(reason or "отмена")..". Возврат — только отдельной кнопкой вне боя."); return;
	end
	if self.stage=="pull_check" then
		self:StopOnly("Предбоевая проверка остановлена: "..(reason or "отмена")); self:Message("начало боя остановлено: "..(reason or "отмена")..". Стратегии автоматически не возвращаю; исходные снимки сохранены."); return;
	end
	local state=UnBotTwinEmperors;
	state.enabled=false; state.manual=false; state.suppressed=true;
	state.active=false; state.prepared=false; state.queue={}; state.prepareDoneAt=nil;
	state.refocusAt=nil; state.casterCheckAt=nil; state.endCheckAt=nil;
	state.casters=nil; state.casterNames=nil;
	if UnBotTwinEmperors.formation then UnBotTwinEmperors.formation:Cancelled(); end
	if self.restoring then self:Message("восстановление стратегий уже выполняется"); return; end
	if UnBotTwinEmperors.retreat then UnBotTwinEmperors.retreat:Cancel(); end
	local had=self.armed or self.stage or self.placing;
	self.formationFailure=self.stage and not self.armed and (reason or "подготовка отменена") or nil;
	self.armed=false; self.stage=nil; self.placing=nil; self.cycleAt=nil; self.cycleDeadline=nil;
	self.pullWaitUntil=nil; self.bossCombatAt=nil;
	self.positionCheckAt=nil;
	self.startRequested=nil; self.dpsAttackAt=nil; self.markCheckUntil=nil;
	self.pending=nil; self.queue={}; self.expires=nil;
	for _,slot in pairs(self.slots) do slot.verified=false; end
	if not self.restoring then self:Restore(); end
	if had or reason then self:Message("разведение остановлено: "..(reason or "вручную")..". Восстанавливаю исходные настройки участников сценария."); end
end

function T:Restore(explicit)
 if UnBotTwinEmperors:GroupInCombat() then self:Stop("возврат исходных настроек доступен только после боя"); return; end
 if not explicit and self:AutoRestoreBlocked() then self:Stop("автоматический возврат после «Начать бой» запрещён"); return; end
 if self.restoring then return; end
 UnBotTwinEmperors.formation:InvalidateCheckpoint("restoring");
 if not self.log then self:BeginLog("restore"); end
 self.restoring=true; self.restoreExplicit=explicit==true; self.restoreWork={}; self.restorePhase=0;
 local store=self:Store(); local keys={};
 for key,record in pairs(store) do
  if (key=="1" or key=="2" or tostring(key):find("^formation:")) and type(record)=="table" and record.name then keys[#keys+1]=key; end
 end
 table.sort(keys);
 for _,key in ipairs(keys) do local record=store[key];
  if record.context==self:Context() and self:Unit(record.name) then
   self.log.names[record.name]=true;
   self.restoreWork[#self.restoreWork+1]={name=record.name,key=key,record=record};
  else self:Message(record.name..": восстановление отложено — нужен живой бот в прежнем рейде/инстансе"); end
 end
 self.restoreExpires=GetTime()+math.max(60,#keys*24); self:RestoreNext();
end

function T:RestoreNext()
 if not self.restoring then return; end
 self.restorePhase=self.restorePhase+1;
 local phase=({"co","nc","rti","pet"})[self.restorePhase];
 if not phase then
  local store=self:Store();
  for _,m in ipairs(self.restoreWork) do
   if not m.keep then store[m.key]=nil; self:Message(m.name..": возврат исходных стратегий отправлен, RTI"..(m.record.petStance and " и стойка питомца" or "").." проверены"); end
  end
  self:SetProgress("Возврат завершён",#self.restoreWork); self.progress.done=#self.restoreWork;
  self.restoreWork=nil; return;
 end
 local work={};
 for _,m in ipairs(self.restoreWork) do
  if phase=="co" or phase=="nc" then
   m.wanted={}; for strategy in pairs((m.record.managed or self.desired)[phase]) do m.wanted[strategy]=m.record[phase][strategy]==true; end
   work[#work+1]=m;
  elseif phase=="rti" and m.record.rti then m.wanted=m.record.rti; work[#work+1]=m;
  elseif phase=="pet" and m.record.petStance then
   if UnBotTwinEmperors.formation:CurrentPet(m.name) then m.wanted=m.record.petStance; work[#work+1]=m;
   else m.keep=true; self:Message(m.name..": стойка питомца отложена до его возвращения, снимок сохранён"); end
  end
 end
 local command=phase=="pet" and "pet stance" or phase.." ?";
 self:Log("восстановление: "..phase.." — чтение "..#work.." участников");
 self:SetProgress("Возврат "..phase..": чтение",#work);
 local function matches(m,value)
  if phase=="co" or phase=="nc" then return self:Matches(m.wanted,value); end
  return m.wanted==value;
 end
 self:ReadWave(work,command,phase,function(observed)
  local changed={};
  for _,m in ipairs(work) do
   local actual=observed[m.name];
   if phase=="pet" and actual==nil then m.keep=true;
   elseif not matches(m,actual) then
    if phase=="pet" then self:Job("pet "..m.wanted,m.name); end
    changed[#changed+1]=m;
   end
  end
  self:Log("восстановление: "..phase.." — различия у "..#changed.." участников"..((phase=="co" or phase=="nc") and ", одна отправка без опроса" or ", одна проверка"));
  self:SetProgress("Возврат "..phase..((phase=="co" or phase=="nc") and ": отправка" or ": применение и проверка"),#changed);
  if phase~="pet" then self:RestoreAcknowledged(changed,phase,observed); return; end
  -- All mutations precede the single verification wave. Unchanged sections need no second read.
  self:ReadWave(changed,command,phase,function(verified)
   for _,m in ipairs(changed) do
    if phase=="pet" and verified[m.name]==nil then m.keep=true;
    elseif not matches(m,verified[m.name]) then self:RestoreFailed(m.name..": не восстановлен "..phase); return; end
   end
   self:RestoreNext();
  end);
 end);
end

function T:RestoreAcknowledged(work,phase,observed)
 local progress=self.progress;
 for _,member in ipairs(work) do
  local m=member; local jobs={};
  if phase=="co" or phase=="nc" then
   local saved=self.queue; self.queue={}; self:Commands(m.name,phase,m.wanted,observed[m.name]); jobs=self.queue; self.queue=saved;
  else jobs={{command="rti "..m.wanted}}; end
  for i,job in ipairs(jobs) do
   local final=i==#jobs; local expected={};
   if phase~="rti" then for token in job.command:sub(#phase+2):gmatch("[^,]+") do expected[token:sub(2)]=token:sub(1,1)=="+"; end end
   if phase=="co" or phase=="nc" then
    self:Job(job.command,m.name,nil,function()
     if final then self:AdvanceProgress(progress); end
    end);
   else self:Job(job.command,m.name,phase,function(value)
    local ok=phase=="rti" and value==m.wanted or phase~="rti" and self:Matches(final and m.wanted or expected,value);
    if not ok then self:RestoreFailed(m.name..": не восстановлен "..phase); return; end
    if final then self:AdvanceProgress(progress); end
   end);
   end
  end
 end
 -- co/nc complete on dispatch; other sections still require their expected replies.
 UnBotTwinEmperors.formation:AfterQueue(function() if self.restoring then self:RestoreNext(); end end);
end

function T:RestoreFailed(reason)
	self.restoring=false; self.restoreExpires=nil; self.restoreExplicit=nil; self.queue={}; self.pending=nil;
	self:Message("восстановление не подтверждено: "..reason..". Снимок сохранён; повтори «Стандарт: reset botAI» после боя.");
end

function T:Reply(message,sender)
	if UnBotTwinEmperors.retreat and UnBotTwinEmperors.retreat:Reply(message,sender) then return; end
	if self.restoring and (UnBotTwinEmperors:GroupInCombat() or not self.restoreExplicit and self:AutoRestoreBlocked()) then self:Stop("возврат настроек запрещён после начала боя"); return; end
	local job=self.pending;
	local name=sender and sender:match("^[^-]+");
	local recent=name and self.lastSent[name];
	if name and self.log and self.log.names[name] then self:Log(message,"reply",name); end
	if not name or not self:Unit(name) then return; end
	local text=tostring(message or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","");
	local lower=text:gsub("[A-Z]",string.lower);
	if lower:match("^%s*.-strategies:") and recent then
		local mode=recent.command:match("^(%S+) ");
		if mode=="co" or mode=="nc" then
			self.strategyQuietUntil=self.strategyQuietUntil or {};
			self.strategyQuietUntil[name..":"..mode]=GetTime()+2.5;
		end
	end
	if (self.armed or self.stage or self.restoring) and recent
		and (GetTime()-recent.at<=6 or (job and job.name==name and job.retryAt))
		and UnBotTwinEmperors.retreat:Rejected(lower) then
		if self.armed and UnBotTwinEmperors.retreat.mobile and UnBotTwinEmperors.retreat.enabled then UnBotTwinEmperors.retreat:Block(name..": "..text);
		elseif self.restoring then self:RestoreFailed(text);
		elseif self.armed and (recent.command:match("^co [+-]") or recent.command:match("^nc [+-]")) then self:StopOnly(name..": "..text);
		else self:Stop(name..": "..text); end
		return;
	end
	if not job or name~=job.name or GetTime()>job.deadline then return; end
	if job.wait=="pet" and lower:find("you have no pet",1,true) then
		if self.restoring then self.pending=nil; self:Message(name..": питомец недоступен; снимок сохранён, продолжаю восстановление остальных"); if job.done then job.done(nil); end
		else self:Stop(name..": сервер не видит питомца; подготовка отменена"); end return;
	end
	local value;
	if job.wait=="co" or job.wait=="nc" then
		local prefix,list=lower:match("^%s*(.-)strategies:%s*(.*)$");
		if list and (prefix=="" or (job.wait=="co" and prefix=="combat ") or (job.wait=="nc" and prefix=="non-combat ")) then
			value={}; for token in list:gmatch("[^,]+") do value[token:match("^%s*(.-)%s*$")]=true; end
		end
	elseif job.wait=="targetName" then
		if UnBotTwinEmperors.retreat:TargetNameEntry(text) then value=text; end
	elseif job.wait=="rti" then
		local icon=lower:match("^rti:%s*(%S+)");
		if job.command~="rti ?" then icon=lower:match("^rti set to:%s*(%S+)%s*$"); end
		if icon and (icon=="skull" or icon=="star" or icon=="cross" or icon=="circle" or icon=="square"
			or icon=="triangle" or icon=="diamond" or icon=="moon" or icon=="none") then value=icon; end
	elseif job.wait=="pet" then
		-- Some server builds substitute "stance" in the heading and leave literal % markers.
		local heading,stance=lower:match('^%s*current %%?(%a+) of %%?pet ".-": %%?(%a+)%.?%s*$');
		if heading=="stance" or heading==stance then value=stance; end
		if value~="passive" and value~="defensive" and value~="aggressive" then value=nil; end
	elseif job.wait=="set" then
		local key=job.command:match("^position (%S+) ");
		value=key and lower=="position "..key.." is set" and true or nil;
	elseif job.wait=="go" then
		value=lower=="moving to position "..job.command:sub(4) and true or nil;
	elseif job.wait=="world" then
		local x,y,z,map,orientation=lower:match("^%s*([%d%.%-]+)%s+([%d%.%-]+)%s+([%d%.%-]+)%s+(%d+)%s+([%d%.%-]+)%s*.*$");
		if tonumber(x) and tonumber(y) and tonumber(z) and tonumber(map) and tonumber(orientation)
			and math.abs(tonumber(x))<50000 and math.abs(tonumber(y))<50000 and math.abs(tonumber(z))<50000 then
			value={x=tonumber(x),y=tonumber(y),z=tonumber(z),map=tonumber(map),at=GetTime()};
		end
	elseif job.wait=="position" or job.wait=="coords" then
		local pattern=job.wait=="coords" and "^i am at ([%d%.%-]+),([%d%.%-]+)$"
			or "^position "..job.command:match("^position (%S+) %?$").." is set to ([%d%.%-]+),([%d%.%-]+)$";
		local x,y=lower:match(pattern);
		if x and tonumber(x) and tonumber(y) then value={x=tonumber(x),y=tonumber(y)}; end
	end
	if value==nil then return; end
	self.pending=nil; if job.done then job.done(value); end
end

function T:Tick()
	local now=GetTime(); if now<(self.nextTick or 0) then return; end self.nextTick=now+0.1;
	self:TickLog(now);
	if self.restoring and (UnBotTwinEmperors:GroupInCombat() or not self.restoreExplicit and self:AutoRestoreBlocked()) then self:Stop("возврат настроек запрещён после начала боя"); return; end
	if UnBotTwinEmperors.formation then UnBotTwinEmperors.formation:Tick(); end
 if UnBotTwinEmperors.retreat then UnBotTwinEmperors.retreat:DiagnosticTick(now); end
	if self.markCheckUntil then
		if self:MarksReady() then self.markCheckUntil=nil; self:Message("шаг 2 выполнен: Череп и Звезда проверены; дождись назначения целей ДД, затем нажми «Начать бой»");
		elseif now>=self.markCheckUntil then
			self.markCheckUntil=nil;
			UnBotTwinEmperors.enabled=false; UnBotTwinEmperors.manual=false; UnBotTwinEmperors.suppressed=true;
			UnBotTwinEmperors.queue={};
			self:Message("шаг 2 не завершён за 60 секунд: выдели обоих боссов и нажми «Проверить метки»; бой не начат");
		end
	end
	self:Refresh();
	if self.dpsAttackAt and now>=self.dpsAttackAt then
		self.dpsAttackAt=nil;
		if self.armed and UnBotTwinEmperors.active then
			if UnBotTwinEmperors.formation and UnBotTwinEmperors.formation.prepared then UnBotTwinEmperors.formation:QueueAttacks();
			else UnBotTwinEmperors:Queue("@dps attack rti target"); end
		end
	end
	if self.restoring then
		if now>=(self.restoreExpires or 0) then self:RestoreFailed("истёк конечный таймаут восстановления"); return; end
		if not self.pending and #self.queue==0 then
			self.restoring=false; self.restoreExpires=nil; self.restoreExplicit=nil;
			if self.formationFailure then
				local reason=self.formationFailure; self.formationFailure=nil;
				self:Message("расстановка не выполнена: "..reason..". Восстановление доступных участников закончено; повтори «Отправить состав на сохранённые точки».");
			else self:Refresh(); end
		end
	elseif self.stage or self.armed then
		if self:Context()~=self.context or not self:InRoom() or self:Busy() then
   if self.armed and UnBotTwinEmperors.retreat.mobile then self:StopOnly("смена зоны или другая операция");
   else self:Stop("смена зоны или другая операция"); end return;
  end
		if not UnBotTwinEmperors.retreat.blocked and now>=(self.expires or 0) then self:Stop("таймаут управления"); return; end
		for _,slot in pairs(self.slots) do if not self:Unit(slot.name) then
   if self.armed and UnBotTwinEmperors.retreat.mobile then self:StopOnly(slot.name..": танк недоступен");
   else self:Stop(slot.name..": танк недоступен"); end return;
  end end
		if self.stage and (UnBotTwinEmperors:GroupInCombat() or (GetUnitSpeed and GetUnitSpeed("player")>0)) then self:Stop("расстановка прервана боем или движением игрока"); return; end
	end
	if self.pending and now>=self.pending.deadline then
		local job=self.pending;
		if job.onTimeout then self.pending=nil; job.onTimeout(); return; end
		if (job.attempts or 1)<self.maxAttempts then
			job.retryAt=now+self.retryPause; job.deadline=job.retryAt+6;
			self.nextSend=math.max(self.nextSend,job.retryAt);
			-- Account for this bounded extra wait without restarting the operation's timers.
			for _,key in ipairs({"expires","restoreExpires","cycleDeadline"}) do
				if self[key] then self[key]=self[key]+6+self.retryPause; end
			end
			self:Message(job.name..": нет ответа на «"..job.command.."» за 6 секунд. Повторю: попытка "..((job.attempts or 1)+1).."/"..self.maxAttempts.." через "..self.retryPause.." с.");
			self:Log("Повтор запланирован: "..job.command.."; попытка "..((job.attempts or 1)+1).."/"..self.maxAttempts,"retry",job.name);
		else
			local reason=job.name..": нет ответа на «"..job.command.."» после "..self.maxAttempts.." попыток (по 6 секунд)";
			if self.restoring then self:RestoreFailed(reason); else self:Stop(reason); end return;
		end
	end
	if self.pending and self.pending.retryAt and now>=self.pending.retryAt then
		local job=self.pending; self.pending=nil; job.retryAt=nil; job.quietLogged=nil; job.delayLogged=nil;
		table.insert(self.queue,1,job); -- Same callback/progress entry; queued successors stay blocked until acknowledgement.
	end
	if not self.pending and #self.queue>0 and now>=self.nextSend then
		local job=self.queue[1];
		if UnBotTwinEmperors.retreat.blocked and not job.controllerHold and not job.controllerCheck then table.remove(self.queue,1); return; end
		if job.damageRelease and not UnBotTwinEmperors.retreat:GateSafe() then
			local r=UnBotTwinEmperors.retreat; self.queue={}; self.pending=nil;
			r.epoch=r.epoch+1; r.phase="acquire"; r.phaseUntil=now+90; r.separation=nil;
			r.contacts={}; r.approaches={}; r.threatSent={}; r:DamageGate(true); return;
		end
		if job.retreatEpoch and not UnBotTwinEmperors.retreat:CanSend(job) then
			UnBotTwinEmperors.retreat:Stop("цель или агро изменились перед отправкой движения"); return;
		end
		if job.readyAt and now<job.readyAt then
			if not job.delayLogged then self:Log("ожидание повторной проверки "..job.name..": "..string.format("%.1f",job.readyAt-now).." с"); job.delayLogged=true; end
			return;
		end
		if (job.wait=="co" or job.wait=="nc") and self.strategyQuietUntil
			and now<(self.strategyQuietUntil[job.name..":"..job.wait] or 0) then
			if not job.quietLogged then self:Log("ожидание перед "..job.command.." для "..job.name..": "..string.format("%.1f",self.strategyQuietUntil[job.name..":"..job.wait]-now).." с (защита от прежнего ответа)"); job.quietLogged=true; end
			return;
		end
		table.remove(self.queue,1);
		if not self:Unit(job.name) then
			if self.restoring then self:RestoreFailed(job.name..": недоступен"); else self:Stop(job.name..": недоступен"); end return;
		end
		if job.members and not UnBotTwinEmperors.formation:RouteFits(job) then self:Stop("изменились участники подгруппы; групповая команда отменена"); return; end
		self.nextSend=now+math.max(self.commandInterval,job.pause or 0.5);
		local mode=job.command:match("^(%S+) ");
		for _,name in ipairs(job.members or {job.name}) do
		if mode=="co" or mode=="nc" then
			self.strategyQuietUntil=self.strategyQuietUntil or {};
			self.strategyQuietUntil[name..":"..mode]=now+2.5;
		end
		self.lastSent[name]={command=job.command,at=now,controllerHold=job.controllerHold,controllerCheck=job.controllerCheck};
		end
		if job.wait then
			job.attempts=(job.attempts or 0)+1; job.deadline=now+6;
			self.pending=job;
		end
		self:Log(job.command,"command",job.members and "@group"..job.group or job.name,
			self.lastLogCommandAt and math.floor((now-self.lastLogCommandAt)*1000+0.5) or nil);
		self.lastLogCommandAt=now;
		if job.members then SendChatMessage("@group"..job.group.." "..job.command,"RAID");
		else SendChatMessage(job.command,"WHISPER",nil,job.name); end
		UnBotTwinEmperors.formation:RecordCommand(job);
		if not job.wait and job.done then job.done(); end
	end
	if self.stage=="arrival" then
		local unit=self:Unit(self.placing.name);
		if unit and CheckInteractDistance(unit,3) then
			self.nearAt=self.nearAt or now;
			if now-self.nearAt>=1 then self:Configure(self.placing); end
		else self.nearAt=nil; end
		if self.stage=="arrival" and now>=self.deadline then self:Stop("танк не прибыл за 20 секунд; повторного summon нет"); end
	end
	if self.retreatMode then UnBotTwinEmperors.retreat:Tick(); end
	if self.armed and self.cycleAt and now>=self.cycleAt and not self.pending and #self.queue==0 then
		self.cycleAt=nil; self.cycleDeadline=now+14;
		for _,slot in ipairs(self.slots) do
			local tank=slot;
			self:Job("go "..tank.position,tank.name,"go");
			self:Job("attack rti target",tank.name,nil,function() self:AttackSent(tank.name); end);
		end
	end
	-- A go acknowledgement starts movement. Read positions once after both tanks have had time to arrive.
	if self.armed and self.positionCheckAt and now>=self.positionCheckAt and not self.pending then
		self.positionCheckAt=nil;
		local tail=self.queue; self.queue={};
		self:Log("проверка позиций двух танков перед оставшимися командами ДД");
		for _,slot in ipairs(self.slots) do
			local tank=slot;
			self:Job("go ?",tank.name,"coords",function(point) self.checks[tank.name]=self:Near(point,tank.point); end);
		end
		for _,job in ipairs(tail) do self.queue[#self.queue+1]=job; end
	end
	if self.armed and self.pullWaitUntil then
		for _,slot in ipairs(self.slots) do
			local unit=self:Unit(slot.name); local expected=slot.icon=="skull" and 15275 or 15276;
			if unit and UnitAffectingCombat(unit) and self:Holding(expected,slot.name) then
				self:ConfirmBossCombat("босс атакует танка "..slot.name); break
			end
		end
		if self.pullWaitUntil and now>=self.pullWaitUntil then
			local reason="бой Близнецов не начался за "..(self.pullWaitSeconds or 45).." секунд после отправки атаки";
			self:StopOnly(reason); self:Message(reason..". Автоматика остановлена без возврата стратегий; проверь дальность и начни бой вручную."); return;
		end
	end
	if self.armed and self.cycleDeadline and now>=self.cycleDeadline and not self.pullWaitUntil then
		local ready=true;
		for _,slot in ipairs(self.slots) do
			local unit=self:Unit(slot.name);
			local expected=slot.icon=="skull" and 15275 or 15276;
			local target=unit and UnBotTwinEmperors:Entry(UnitGUID(unit.."target")); local holding=self:Holding(expected,slot.name);
			if not self.checks[slot.name] or not unit or target~=expected or not holding then
				ready=false; self:Log(slot.name..": точка="..tostring(self.checks[slot.name]).."; цель="..tostring(target)
					.."; ожидается="..expected.."; агро="..tostring(holding),"combat_check",slot.name);
			end
		end
		if ready then self.cycleDeadline=nil; self:Message("танки удерживают свои стороны; цели и агро после перехвата подтверждены");
		elseif self.targetRetries<1 then
			self.targetRetries=1; self.cycleDeadline=now+12;
			self.checks={}; self.positionCheckAt=nil;
			for _,slot in ipairs(self.slots) do
				local tank=slot;
				self:Job("go "..tank.position,tank.name,"go"); self:Job("rti "..tank.icon,tank.name);
				self:Job("attack rti target",tank.name,nil,function() self:AttackSent(tank.name); end);
			end
			self:Message("перехват/позиция не подтверждены: одна повторная команда танкам");
		else
			local reason="перехват или удержание краёв не подтверждены; продолжай вручную";
			self:StopOnly(reason); self:Message(reason..". Автоматика остановлена без возврата стратегий; исходные снимки сохранены.");
		end
	end
end

function T:Refresh()
	if not self.frame then return; end
	if GetTime()>=(self.nextAutoSelect or 0) then self.nextAutoSelect=GetTime()+1; self:AutoSelect(); end
	local formation=UnBotTwinEmperors.formation; local profile=formation and formation:Profile();
	local saved=formation and formation:Validate(profile) and profile.context==self:Context();
	local checkpoint=profile and profile.preparation;
	local resumable=checkpoint and checkpoint.status=="active" and checkpoint.context==self:Context();
	self.frame.restore:SetText(resumable and (checkpoint.phase=="ready" and "Проверить готовую расстановку" or "Продолжить сохранённую подготовку") or "Отправить состав на сохранённые точки");
	for side=1,2 do
		local slot=self.slots[side]; self.frame.labels[side]:SetText((side==1 and "Край Черепа: " or "Край Звезды: ")
			..(slot and slot.name or "танк не выбран")..(slot and slot.verified and " — готов" or ""));
		self.frame.place[side]:SetText(saved and "Заменить: поставить сюда" or "Поставить сюда (новая точка)");
	end
	if saved then
		self.frame.savedPoints:SetText(string.format("|cff33ff33Точки сохранены в пресете %s|r\nЧереп: %.2f, %.2f; Звезда: %.2f, %.2f",select(2,formation:Key()),profile.points[1].x,profile.points[1].y,profile.points[2].x,profile.points[2].y));
	else self.frame.savedPoints:SetText("|cffffcc00Для этого пресета и комнаты точки ещё не сохранены.|r\nВыбери танков и один раз поставь их на противоположные края."); end
	if saved and not formation.active and not self.armed and not self.stage and not self.pending
		and #self.queue==0 and not self.restoring and not self:Busy() and not UnBotTwinEmperors:GroupInCombat()
		and not UnitIsDeadOrGhost("player") then self.frame.restore:Enable(); else self.frame.restore:Disable(); end
	local whole=formation and formation.active or profile and profile.enabled and profile.points;
	self.frame.steps[1]:SetText("1. ОБЯЗАТЕЛЬНО — "..(whole and "расставить весь состав: " or "расставить двух танков: ")
		..((whole and formation.prepared or not whole and self:SidesReady()) and "|cff33ff33ГОТОВО|r" or "|cffffcc00НЕ ЗАВЕРШЕНО|r"));
	self.frame.steps[2]:SetText("2. ОБЯЗАТЕЛЬНО — автометки: "..(self:MarksReady() and "|cff33ff33Череп и Звезда проверены|r" or "|cffffcc00жду Череп и Звезду|r"));
	local canStart,blocked=self:CanStartFight();
	self.frame.steps[3]:SetText("3. НАЧАТЬ БОЙ — "..(UnBotTwinEmperors.active and "|cff33ff33запущен|r" or (canStart and "|cff33ff33можно начинать|r" or blocked or "сначала завершите шаги 1 и 2")));
	if self:CanStartFight() then self.frame.start:Enable(); else self.frame.start:Disable(); end
	if self:SidesReady() and not self.armed and not self.stage and not self.restoring
		and not UnBotTwinEmperors.active then self.frame.checkMarks:Enable(); else self.frame.checkMarks:Disable(); end
	if self.restoring or UnBotTwinEmperors:GroupInCombat() then self.frame.returnOriginal:Disable(); else self.frame.returnOriginal:Enable(); end
	self.frame.status:SetText(self.status or "Расстановка возможна только до боя. Противоположные края выбери в комнате близнецов.");
	local progress=self.progress or (resumable and checkpoint.progress);
	self.frame.progress:SetText(progress and ((not self.progress and "Сохранено: " or "")..progress.label..": "..progress.done.."/"..progress.total)
		or (formation and formation.prepared and "Расстановка завершена" or "Очередь не выполняется"));
	local log=self.log or (UnBotSquadConfig and UnBotSquadConfig.twinFormationLogs and UnBotSquadConfig.twinFormationLogs[1]);
	self.frame.logStatus:SetText("Лог Близнецов: "..(self.log and "запись идёт" or log and "последняя запись завершена" or "начнётся при отправке")
		..(log and " / "..log.count.." событий" or "")..". Интервал: "..self.commandInterval.." с.\nПосле попытки /reload — запись в SavedVariables\\UnBot.lua (последние 3 попытки).");
	if UnBotTwinEmperors.retreat then UnBotTwinEmperors.retreat:Refresh(self.frame); end
end

function T:Show()
	if UnBotTwinEmperors.playerTank and UnBotTwinEmperors.playerTank:Selected() then UnBotTwinEmperors.playerTank:Show(); return; end
	if UnBotTwinEmperors.formation then UnBotTwinEmperors.formation:EnsurePreset(); end
	self:AutoSelect();
	if not self.frame then
		local f=CreateFrame("Frame","UnBotTwinTankFrame",UIParent); self.frame=f;
		f:SetSize(560,646); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:SetMovable(true); f:EnableMouse(true);
		f:RegisterForDrag("LeftButton"); f:SetScript("OnDragStart",function() f:StartMoving(); end);
		f:SetScript("OnDragStop",function() f:StopMovingOrSizing(); end);
		f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=32,insets={left=8,right=8,top=8,bottom=8}});
		local title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); title:SetPoint("TOP",0,-17); title:SetText("Близнецы — танки (6.38.214)");
		local close=CreateFrame("Button",nil,f,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",-4,-4);
		local hint=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); f.modeHint=hint; hint:SetPoint("TOPLEFT",18,-45); hint:SetSize(520,48); hint:SetJustifyH("LEFT");
		hint:SetText("Есть сохранённые точки — отправь весь состав на них одной кнопкой. Новые точки задавай танкам вручную; после второй точки состав подготовится автоматически. Бой запускается отдельно.");
		f.savedPoints=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); f.savedPoints:SetPoint("TOPLEFT",18,-102); f.savedPoints:SetSize(520,40); f.savedPoints:SetJustifyH("LEFT");
		f.steps={};
		for index,y in ipairs({-154,-398,-470}) do
			local label=f:CreateFontString(nil,"OVERLAY","GameFontNormal"); label:SetPoint("TOPLEFT",18,y); label:SetSize(520,20); label:SetJustifyH("LEFT"); f.steps[index]=label;
		end
		f.labels={}; f.place={};
		for side=1,2 do
			local index=side; local y=-186-(side-1)*64;
			local label=f:CreateFontString(nil,"OVERLAY","GameFontNormal"); label:SetPoint("TOPLEFT",18,y); f.labels[side]=label;
			local choose=CreateFrame("Button",nil,f,"UIPanelButtonTemplate"); choose:SetSize(225,24); choose:SetPoint("TOPLEFT",18,y-20); choose:SetText("Выбрать танка из цели"); choose:SetScript("OnClick",function() T:Select(index); end);
			local place=CreateFrame("Button",nil,f,"UIPanelButtonTemplate"); place:SetSize(251,24); place:SetPoint("TOPLEFT",265,y-20); place:SetScript("OnClick",function() T:Place(index); end); f.place[side]=place;
		end
		f.restore=CreateFrame("Button",nil,f,"UIPanelButtonTemplate"); f.restore:SetSize(498,26); f.restore:SetPoint("TOPLEFT",18,-302); f.restore:SetText("Отправить состав на сохранённые точки"); f.restore:SetScript("OnClick",function() if UnBotTwinEmperors.retreat and UnBotTwinEmperors.retreat:IsMobile() then UnBotTwinEmperors.retreat:PrepareFree(); else UnBotTwinEmperors.formation:Apply(); end end);
		f.progress=f:CreateFontString(nil,"OVERLAY","GameFontNormal"); f.progress:SetPoint("TOPLEFT",18,-334); f.progress:SetSize(520,18); f.progress:SetJustifyH("LEFT");
		f.logStatus=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); f.logStatus:SetPoint("TOPLEFT",18,-354); f.logStatus:SetSize(520,36); f.logStatus:SetJustifyH("LEFT");
		f.checkMarks=CreateFrame("Button",nil,f,"UIPanelButtonTemplate"); f.checkMarks:SetSize(168,24); f.checkMarks:SetPoint("TOPLEFT",18,-424); f.checkMarks:SetText("Проверить метки"); f.checkMarks:SetScript("OnClick",function() if UnBotTwinEmperors.retreat and UnBotTwinEmperors.retreat:IsMobile() then UnBotTwinEmperors.retreat:FreeMarks(); else T:BeginMarkCheck(); end end);
		f.stop=CreateFrame("Button",nil,f,"UIPanelButtonTemplate"); f.stop:SetSize(88,24); f.stop:SetPoint("TOPLEFT",193,-424); f.stop:SetText("Стоп"); f.stop:SetScript("OnClick",function() T:StopOnly(); end);
		f.returnOriginal=CreateFrame("Button",nil,f,"UIPanelButtonTemplate"); f.returnOriginal:SetSize(227,24); f.returnOriginal:SetPoint("TOPLEFT",288,-424); f.returnOriginal:SetText("Стандарт: reset botAI"); f.returnOriginal:SetScript("OnClick",function() T:ReturnOriginal(); end);
		f.start=CreateFrame("Button",nil,f,"UIPanelButtonTemplate"); f.start:SetSize(498,28); f.start:SetPoint("TOPLEFT",18,-496); f.start:SetText("Начать бой"); f.start:SetScript("OnClick",function() T:StartFight(); end);
		local formation=CreateFrame("Button",nil,f,"UIPanelButtonTemplate"); f.formationSettings=formation; formation:SetSize(498,26); formation:SetPoint("TOPLEFT",18,-535); formation:SetText("Настройки групп по классам/спекам (необязательно)..."); formation:SetScript("OnClick",function() UnBotTwinEmperors.formation:Show(); end);
		f.status=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); f.status:SetPoint("TOPLEFT",18,-572); f.status:SetSize(520,54); f.status:SetJustifyH("LEFT");
	end
	self.frame:Show();
	if UnBotTwinEmperors.retreat then UnBotTwinEmperors.retreat:Attach(self.frame); end
	if not self.armed and not self.stage and not self:SidesReady() and (self:Store()["1"] or self:Store()["2"]) then
		local p=UnBotTwinEmperors.formation:Profile(); local c=p and p.preparation;
		self.status=c and c.status=="active" and ("Сохранён этап «"..(UnBotTwinEmperors.formation.phases[c.phase] or c.phase).."». Нажми продолжение: состав и готовность будут проверены без полного возврата стратегий.")
			or "Есть исходные снимки. «Стоп» только отменяет очередь; «Стандарт: reset botAI» сбрасывает стратегии к серверным значениям. Сохранённые точки и выбранные танки остаются.";
	end
	self:Refresh();
end
end

-- Saved class/spec formation, anchored to the two tank positions.
do
local T=UnBotTwinEmperors.tanks;
local F={draft={},targets={skull="Череп",star="Звезда",split="Обе стороны (хилы)"}};
UnBotTwinEmperors.formation=F;
F.phases={groups="Подгруппы",read="Исходные настройки",prepare="Команды подготовки",safety="Проверка стратегий",
 move="Отправка на точки",arrival="Прибытие на точки",anchors="Проверка удержания и RTI",ready="Готовая расстановка"};
F.specs={paladin={"holy","prot","ret"},warrior={"arms","fury","prot"},dk={"blood","frost","unholy"},
 shaman={"ele","enh","resto"},priest={"holy","disc","shadow"},druid={"balance","feral","feral tank","resto"},
 warlock={"affli","demo","destro"},mage={"arcane","fire","frost"},rogue={"assa","combat","sub"},hunter={"bm","mm","surv"}};
F.coKeys={"stay","tank","dps","heal","passive","follow","guard","formation","flee","runaway","grind","attack weak","attack force","avoid aoe","dps aoe","tank assist","dps assist","close","behind","tank face","tank aoe","move from group","flee from adds"};
F.ncKeys={"stay","passive","follow","guard","grind","move random","runaway","flee from adds","move from group"};

function F:Copy(value)
 if type(value)~="table" then return value; end
 local result={}; for key,item in pairs(value) do result[key]=self:Copy(item); end return result;
end
function F:Key()
 local loaded=UnBotSquadBuilder and UnBotSquadBuilder.loadedBossPreset;
 if not loaded or not loaded.modeKey or loaded.bossKey~="temple_of_ahn_qiraj__the_twin_emperors" then return; end
 return (GetRealmName() or "")..":"..(UnitName("player") or ""),loaded.modeKey;
end
function F:EnsurePreset()
 if self:Key() then return true; end
 if T:InRoom() and UnBotBossPresetLoad then
  UnBotBossPresetLoad("temple_of_ahn_qiraj__the_twin_emperors","40n",false);
 end
 return self:Key()~=nil;
end
function F:Profile(create)
 local owner,mode=self:Key(); if not owner or not mode then return; end
 if mode=="40n6" then
  local root=UnBotSquadConfig and UnBotSquadConfig.twinFormations;
  local profiles=root and root[owner]; local base=profiles and profiles["40n"];
  if profiles and not profiles[mode] and base and base.context==T:Context() and self:Validate(base) then
   profiles[mode]={points=self:Copy(base.points),tanks=self:Copy(base.tanks),rules=self:Copy(base.rules),
    context=base.context,schemaVersion=base.schemaVersion,enabled=base.enabled,savedAt=base.savedAt,copiedFrom="40n"};
  end
 end
 if create then
  UnBotSquadConfig=UnBotSquadConfig or {}; UnBotSquadConfig.twinFormations=UnBotSquadConfig.twinFormations or {};
  local root=UnBotSquadConfig.twinFormations; root[owner]=root[owner] or {}; root[owner][mode]=root[owner][mode] or {};
 end
 local root=UnBotSquadConfig and UnBotSquadConfig.twinFormations; return root and root[owner] and root[owner][mode];
end
function F:Spec(profile)
 local spec=profile.specKey or profile.specName;
 if profile.className=="druid" and spec=="feral combat" then
  local role=UnBotFeralProfileRole and UnBotFeralProfileRole(profile) or profile.feralRole;
  if role=="bear" then return "feral tank"; elseif role=="cat" then return "feral"; end
 end
 return ({protection="prot",restoration="resto",discipline="disc",marksmanship="mm",destruction="destro",
  elemental="ele",enhancement="enh",affliction="affli",demonology="demo",assassination="assa",subtlety="sub",survival="surv",
  ["feral bear"]="feral tank",["feral cat"]="feral"})[spec] or spec;
end
function F:Healer(m) return m.spec=="resto" or m.spec=="holy" or m.spec=="disc"; end
function F:IsTank(m)
 return (m.className=="paladin" or m.className=="warrior") and m.spec=="prot"
  or m.className=="druid" and m.spec=="feral tank"
  or m.className=="dk" and m.spec=="blood";
end
function F:PickTanks(profile,members)
 local chosen,used,byName={},{},{}; profile=profile or {};
 for _,m in ipairs(members) do if self:IsTank(m) then byName[m.name]=m; end end
 local function pick(side,name)
  if not chosen[side] and byName[name] and not used[name] then chosen[side]=byName[name]; used[name]=true; end
 end
 local owner,mode=self:Key();
 if T.selectionOwner==owner and T.selectionMode==mode then
  for side=1,2 do pick(side,T.slots[side] and T.slots[side].name); end
 end
 for side=1,2 do pick(side,profile.selectedTanks and profile.selectedTanks[side]); end
 local recovery=T:Store();
 for side=1,2 do local r=recovery[tostring(side)]; if r and r.context==T:Context() then pick(side,r.name); end end
 for side=1,2 do local rule=profile.tanks and profile.tanks[side];
  if rule then for _,m in ipairs(members) do if m.className==rule.className and m.spec==rule.spec then pick(side,m.name); end end end
 end
 for side=1,2 do for _,m in ipairs(members) do pick(side,m.name); end end
 if not chosen[1] or not chosen[2] then return nil,"нужны два разных живых онлайн-бота в танковом спеке"; end
 return chosen;
end
function F:RuleKey(m) return tostring(m.className)..":"..tostring(m.spec); end
function F:DefaultTarget(m)
 if self:Healer(m) then return "split"; end
 if m.className=="mage" or m.className=="warlock" or m.spec=="shadow" or m.spec=="balance" or m.spec=="ele" then return "star"; end
 return "skull";
end
function F:ReserveExcluded(name,profile)
 if not UnBotSquadRosterIsResurrectionReserve or not UnBotSquadRosterIsResurrectionReserve(name) then return false; end
 for _,slot in pairs(T.slots or {}) do if slot.name==name then return false; end end
 -- A stored former rescuer can still be explicitly selected as a combat role or named alt.
 for _,slot in ipairs(UnBotSquadConfig.slots or {}) do if not slot.reserveOnly and (tonumber(slot.count) or 1)>0 then
  if slot.accountAltName==name or (not slot.accountAltName and slot.className==profile.className
   and (slot.specKey=="any" or self:Spec({specName=slot.specKey})==self:Spec(profile))) then return false; end
 end end
 return true;
end
function F:Roster()
 local members={};
 for i=1,math.min(40,GetNumRaidMembers() or 0) do
  local unit="raid"..i; local name=UnitName(unit);
  if name and name~=UnitName("player") and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit)
   and UnBotBotRegistry and UnBotBotRegistry.bots and UnBotBotRegistry.bots[name]
   and not self:ReserveExcluded(name,UnBotBotRegistry.bots[name])
   and not (UnBotSquadRosterIsOfflineReserve and UnBotSquadRosterIsOfflineReserve(name)) then
   local profile=UnBotBotRegistry.bots[name]; local pet="raidpet"..i;
   members[#members+1]={name=name,className=profile.className,spec=self:Spec(profile),pet=UnitExists(pet) and not UnitIsDeadOrGhost(pet) and UnitName(pet) or nil,
    petGUID=UnitExists(pet) and not UnitIsDeadOrGhost(pet) and UnitGUID(pet) or nil};
  end
 end
 table.sort(members,function(a,b) return a.name<b.name; end); return members;
end
function F:CurrentPet(name)
 for _,m in ipairs(self:Roster()) do if m.name==name then return m.pet,m.petGUID; end end
end
function F:Signature()
 local keys={}; for _,m in ipairs(self:Roster()) do keys[#keys+1]=m.name..":"..self:RuleKey(m)..":"..tostring(m.pet); end return table.concat(keys,"|");
end
function F:SameRoster()
 local owner,mode=self:Key();
 return self.owner==owner and self.mode==mode and self.context==T:Context() and self.signature==self:Signature() and T:InRoom()
  and (not self.routingSignature or (self.prepared and self:ReadyRoutingMatches(self.routingSignature,self.work))
   or self.routingSignature==self:GroupSignature());
end
function F:ReadyRoutingMatches(signature,members)
 -- Ready movement/attacks are whispered to these bots; unrelated reserve/guest changes are irrelevant.
 local names={}; for _,m in ipairs(members or {}) do names[m.name]=true; end
 local function filtered(value)
  local entries={}; for entry in tostring(value or ""):gmatch("[^|]+") do
   if names[entry:match("^([^:]+):")] then entries[#entries+1]=entry; end
  end
  table.sort(entries); return table.concat(entries,"|"),#entries;
 end
 local old,count=filtered(signature); local current,currentCount=filtered(self:GroupSignature());
 return count==#(members or {}) and currentCount==count and old==current;
end
function F:Message(text) self.status=text; T:Message("расстановка: "..text); self:Refresh(); end
function F:Fingerprint(value)
 if type(value)~="table" then return type(value)..":"..tostring(value); end
 local keys={}; for key in pairs(value) do keys[#keys+1]=key; end
 table.sort(keys,function(a,b) return tostring(a)<tostring(b); end);
 local parts={}; for _,key in ipairs(keys) do parts[#parts+1]=self:Fingerprint(key).."="..self:Fingerprint(value[key]); end
 return "{"..table.concat(parts,";").."}";
end
function F:ProfileSignature(profile)
 return self:Fingerprint({points=profile.points,tanks=profile.tanks,rules=profile.rules,selectedTanks=profile.selectedTanks,fightControl=profile.fightControl});
end
function F:SaveCheckpoint()
 local c=self.checkpoint;
 if not c or c.status~="active" or self.kind~="apply" or (not self.active and not self.prepared) then return; end
 c.work=self:Copy(self.work); c.routingSignature=self.routingSignature;
 c.progress=self:Copy(T.progress); c.savedAt=time();
end
function F:CheckpointPhase(phase)
 if not self.checkpoint or self.checkpoint.status~="active" then return; end
 self.checkpoint.phase=phase; self:SaveCheckpoint();
 T:Log("Сохранён этап подготовки: "..phase,"checkpoint");
end
function F:NewCheckpoint()
 local p=self:Profile();
 self.checkpoint=type(p.preparation)=="table" and self:Copy(p.preparation) or {};
 local c=self.checkpoint; c.schema=1; c.status="active"; c.phase="groups"; c.owner=self.owner; c.mode=self.mode; c.context=self.context;
 c.signature=self.signature; c.profileSignature=self:ProfileSignature(p); c.sent={}; c.startedAt=time(); c.adopted=nil; c.routingSignature=nil;
 p.preparation=self.checkpoint; self:SaveCheckpoint();
end
function F:InvalidateCheckpoint(reason)
 local p=self:Profile(); local c=self.checkpoint or (p and p.preparation);
 if c and c.status=="active" then c.status=reason; c.savedAt=time(); end
 self.checkpoint=nil;
end
function F:CommandWasSent(command,name)
 local c=self.active and self.checkpoint;
 return c and c.status=="active" and c.sent[c.phase..":"..name..":"..command]==true;
end
function F:RecordCommand(job)
 local c=self.active and self.checkpoint;
 if not c or c.status~="active" then return; end
 if job.wait and (not ({co=true,nc=true,rti=true})[job.wait] or job.command:match(" %?$")) then return; end
 c.sent[c.phase..":"..job.name..":"..job.command]=true; self:SaveCheckpoint();
end
function F:AfterQueue(done)
 local job=T.queue[#T.queue];
 if not job then done(); return; end
 local previous=job.done; job.done=function(value) if previous then previous(value); end done(); end;
end
function F:CheckpointMatches(c,members,p)
 if type(c)~="table" or c.schema~=1 or c.status~="active" or type(c.work)~="table" or type(c.sent)~="table"
  or not ({groups=true,read=true,prepare=true,safety=true,move=true,arrival=true,anchors=true,ready=true})[c.phase] then return false; end
 local owner,mode=self:Key();
 if c.owner~=owner or c.mode~=mode or c.context~=T:Context() or c.signature~=self:Signature()
  or c.profileSignature~=self:ProfileSignature(p) or #c.work~=#members then return false; end
 local store=T:Store();
 for i,m in ipairs(members) do local old=c.work[i];
  if type(old)~="table" or old.name~=m.name or old.target~=m.target or old.side~=m.side then return false; end
  if old.readDone then
   local record=store[m.side and tostring(m.side) or "formation:"..m.name];
   if not record or record.name~=m.name or record.context~=c.context or not old.actual or not old.prepCO then return false; end
  elseif c.phase~="read" and c.phase~="groups" then return false; end
 end
 return not c.routingSignature or c.routingSignature==self:GroupSignature()
  or (c.phase=="ready" and self:ReadyRoutingMatches(c.routingSignature,members));
end
function F:AdoptCheckpoint(members,p)
 -- Upgrade an already positioned pre-189 roster only after checking every bot; never claim readiness from journals alone.
 if p.preparation or not self:PendingRecovery(members) then return; end
 local store=T:Store();
 for _,m in ipairs(members) do
  local r=store[m.side and tostring(m.side) or "formation:"..m.name];
  if not r or r.name~=m.name or r.context~=T:Context() then return; end
  m.actual={co=self:Copy(r.co),nc=self:Copy(r.nc),rti=r.rti,petStance=r.petStance};
  local base=self:Copy(r.nc); for key,value in pairs(m.nc) do base[key]=value; end m.nc=base;
  if m.co.passive==nil then m.co.passive=r.co.passive==true; end
  m.prepCO=self:Copy(m.co); m.prepCO.passive=true; m.moveNC=self:MoveNC(base,false);
  m.petStanceOriginal=r.petStance; m.readDone=true; m.arrivedDone=true;
 end
 local owner,mode=self:Key();
 local c={schema=1,status="active",phase="ready",owner=owner,mode=mode,context=T:Context(),signature=self:Signature(),
  profileSignature=self:ProfileSignature(p),work=self:Copy(members),sent={},startedAt=time(),adopted=true};
 p.preparation=c; return c;
end
function F:ResumeCheckpoint(c)
 self:Begin("apply",self:Copy(c.work)); self.participants=self.work; self.checkpoint=c;
 self.resumed=true;
 self.routingSignature=c.phase=="ready" and self:GroupSignature() or c.routingSignature;
 T.slots={}; T.selectionOwner,T.selectionMode=self:Key();
 self.groups={skull={},star={},heal={}};
 for _,m in ipairs(self.work) do
  m.confirmed=nil; m.sentStrategies=nil; -- Reload still requires fresh validation; dispatched state is not a server reply.
  T.log.names[m.name]=true; table.insert(self.groups[m.target],m); if m.role=="heal" then table.insert(self.groups.heal,m); end
  if m.side then T.slots[m.side]={name=m.name,side=m.side,point=self:Copy(m.point),position="ub_twins_"..m.side,icon=m.target}; end
 end
 self:Message("продолжаю сохранённый этап «"..self.phases[c.phase].."»; исходные стратегии не возвращаю, бой запускается отдельно");
 if c.phase=="groups" then
  local ok,reason=self:PlanGroups(); if not ok then T:StopOnly(reason); self:Message(reason); return; end
  T:SetProgress("Подгруппы",#self.work); return;
 elseif c.phase=="read" then
  self.index=0; T:SetProgress("Исходные настройки",#self.work);
  for _,m in ipairs(self.work) do if m.readDone then T.progress.done=T.progress.done+1; end end
  self:NextMove(); return;
 elseif c.phase=="prepare" then self:PrepareGroups(); return;
 elseif c.phase=="safety" then self.index=0; T:SetProgress("Проверка стратегий",#self.work); self:NextSafetyCheck(); return; end
 -- Later stages retain all preparation commands; recheck passive combat state before any further movement.
 local phase=c.phase; self.index=0; T:SetProgress("Проверка после /reload",#self.work);
 self:ResumeSafety(function()
  if phase=="move" then self:SendToPoints();
  else
   if phase~="ready" then self:CheckpointPhase("arrival"); end
   self.index=0; T:SetProgress("Проверка точек после /reload",#self.work); self:NextArrival();
  end
 end);
end
function F:ResumeSafety(done)
 self.index=self.index+1; local m=self.work[self.index];
 if not m then done(); return; end
 T:Job("co ?",m.name,"co",function(actual)
  local ok,key=T:Matches(m.prepCO,actual);
  if not ok then T:StopOnly(m.name..": сохранённая подготовка изменилась: co "..key); self:Message(m.name..": сохранённая подготовка изменилась (co "..key.."); нажми отправку для новой расстановки"); return; end
  local function nextMember() T:AdvanceProgress(T.progress); self:ResumeSafety(done); end
  if m.pet then T:Job("pet stance",m.name,"pet",function(stance)
   if stance~="passive" then T:StopOnly(m.name..": питомец уже не пассивен; сохранённая готовность отменена"); self:Message(m.name..": питомец уже не пассивен; сохранённая готовность отменена"); return; end
   nextMember();
  end); else nextMember(); end
 end);
end
function F:Rules()
 local owner,mode=self:Key(); local draftKey=tostring(owner)..":"..tostring(mode);
 if self.draftKey~=draftKey then self.draft={}; self.draftKey=draftKey; end
 local profile=self:Profile(); local rules=self:Copy(profile and profile.rules or {});
 local function add(class,spec)
  local m={className=class,spec=spec}; local key=F:RuleKey(m);
  rules[key]=rules[key] or {className=class,spec=spec,target=F:DefaultTarget(m)};
  if F.draft[key] then rules[key].target=F.draft[key]; end
 end
 for class,specs in pairs(self.specs) do for _,spec in ipairs(specs) do add(class,spec); end end
 for _,p in pairs(UnBotBotRegistry and UnBotBotRegistry.bots or {}) do if p.className and self:Spec(p) then add(p.className,self:Spec(p)); end end
 return rules;
end
function F:ReadyToWork()
 if not self:Key() or not T:InRoom() or UnitIsDeadOrGhost("player") or UnBotTwinEmperors:GroupInCombat()
  or T.stage or T.armed or T.restoring or T.pending or #T.queue>0 or T:Busy() then
  self:Message("выбери пресет Близнецов в их комнате и дождись завершения других операций вне боя"); return false;
 end return true;
end
function F:Begin(kind,work)
 self.owner,self.mode=self:Key(); self.context=T:Context(); self.signature=self:Signature();
 self.kind=kind; self.active=true; self.prepared=false; self.work=work; self.index=0; self.routingSignature=nil; self.resumed=nil;
 T.context=self.context; T.stage="formation_"..kind; T.expires=GetTime()+math.min(1800,math.max(90,#work*35+60));
 UnBotTwinEmperors.manual=true; UnBotTwinEmperors.enabled=true; UnBotTwinEmperors.suppressed=false; self:Refresh();
 if kind=="capture" then T:SetProgress("Сохранение правил",#work); end
end
function F:Snapshot(channel,actual)
 local wanted=self:Copy(actual); for _,key in ipairs(channel=="co" and self.coKeys or self.ncKeys) do wanted[key]=actual[key]==true; end return wanted;
end
function F:MoveNC(wanted,hold)
 local result=self:Copy(wanted or {}); for _,key in ipairs(self.ncKeys) do result[key]=false; end result.stay=hold==true; return result;
end
function F:Read(m,done)
 local actual={}; T:Job("co ?",m.name,"co",function(value) actual.co=value; end);
 T:Job("nc ?",m.name,"nc",function(value)
  actual.nc=value; T:Job("rti ?",m.name,"rti",function(icon)
   actual.rti=icon;
   if m.pet then T:Job("pet stance",m.name,"pet",function(stance) actual.petStance=stance; done(actual); end);
   else done(actual); end
  end);
 end);
end
function F:RaidGroups()
 if not GetRaidRosterInfo then return; end
 local groups,byName={},{}; for g=1,8 do groups[g]={}; end
 for i=1,math.min(40,GetNumRaidMembers() or 0) do
  local name,rank,g=GetRaidRosterInfo(i);
  if not name or not g or not groups[g] then return; end
  local m={name=name,index=i,group=g,online=UnitIsConnected("raid"..i) and not UnitIsDeadOrGhost("raid"..i)};
  groups[g][#groups[g]+1]=m; byName[name]=m;
 end return groups,byName;
end
function F:GroupSignature()
 local groups=self:RaidGroups(); if not groups then return "unavailable"; end
 local keys={}; for g=1,8 do for _,m in ipairs(groups[g]) do keys[#keys+1]=m.name..":"..g..":"..tostring(m.online); end end
 table.sort(keys); return table.concat(keys,"|");
end
function F:PlanGroups()
 local groups=self:RaidGroups();
 if not groups or not SetRaidSubgroup or not SwapRaidSubgroup then return false,"недоступно распределение подгрупп рейда"; end
 if IsRaidLeader and not IsRaidLeader() and (not IsRaidOfficer or not IsRaidOfficer()) then return false,"для распределения нужен лидер или помощник рейда"; end
 self.groups={skull={},star={},heal={}}; local names={};
 for _,m in ipairs(self.work) do
  names[m.name]=m; table.insert(self.groups[m.target],m); if m.role=="heal" then table.insert(self.groups.heal,m); end
 end
 local capacity={}; for g=1,8 do
  capacity[g]=5; for _,m in ipairs(groups[g]) do if not names[m.name] then capacity[g]=capacity[g]-1; end end
 end
 self.groupPlan={}; local g=1;
 for _,target in ipairs({"skull","star"}) do for _,m in ipairs(self.groups[target]) do
  while g<=8 and capacity[g]<=0 do g=g+1; end
  if g>8 then return false,"не хватает мест в подгруппах"; end
  self.groupPlan[m.name]=g; capacity[g]=capacity[g]-1;
 end end
 for _,m in ipairs(self.work) do T:Log("план подгрупп: "..m.name.." -> группа "..self.groupPlan[m.name]); end
 self.groupAttempts=0; self.groupDeadline=GetTime()+60; self.groupNext=0; return true;
end
function F:ArrangeGroups()
 local groups,byName=self:RaidGroups(); if not groups then T:Stop("ростер подгрупп недоступен"); return; end
 if T.progress and T.progress.label=="Подгруппы" then
  local ready=0; for _,m in ipairs(self.work) do if byName[m.name] and byName[m.name].group==self.groupPlan[m.name] then ready=ready+1; end end
  T.progress.done=ready;
 end
 for _,m in ipairs(self.work) do
  local current=byName[m.name]; local wanted=self.groupPlan[m.name];
  if not current then T:Stop("состав изменился при распределении"); return; end
  if current.group~=wanted then
   if GetTime()>=self.groupDeadline or self.groupAttempts>=80 then T:Stop("сервер не подтвердил распределение подгрупп за 60 секунд"); return; end
   if GetTime()<self.groupNext then return; end
   self.groupAttempts=self.groupAttempts+1; self.groupNext=GetTime()+0.5;
   local ok;
   if #groups[wanted]<5 then
    T:Log("подгруппы: "..m.name.." из "..current.group.." -> "..wanted.."; попытка "..self.groupAttempts);
    ok=pcall(SetRaidSubgroup,current.index,wanted);
   else
    for _,other in ipairs(groups[wanted]) do if self.groupPlan[other.name] and self.groupPlan[other.name]~=wanted then
     T:Log("подгруппы: обмен "..m.name.." ("..current.group..") <-> "..other.name.." ("..wanted.."); попытка "..self.groupAttempts);
     ok=pcall(SwapRaidSubgroup,current.index,other.index); break
    end end
   end
   if not ok then T:Stop("не удалось изменить подгруппу рейда; перемещение не начато"); end return;
  end
 end
 self.groupPlan=nil; self.routingSignature=self:GroupSignature(); self.index=0;
 self:Message("группы готовы: Череп — "..#self.groups.skull..", Звезда — "..#self.groups.star.."; хилов — "..#self.groups.heal..". Читаю исходные настройки всех участников до перемещения");
 T:SetProgress("Исходные настройки",#self.work);
 self:CheckpointPhase("read");
 self:NextMove();
end
function F:RouteFits(job)
 local groups=self:RaidGroups(); if not groups then return false; end
 local expected={}; for _,name in ipairs(job.members) do if not T:Unit(name) then return false; end expected[name]=true; end
 for _,m in ipairs(groups[job.group]) do if m.online and m.name~=UnitName("player") then
  if not expected[m.name] then return false; end expected[m.name]=nil;
 end end
 return next(expected)==nil;
end
function F:Batch(command,members,done,pause)
 -- The live server applied @groupN commands to both sides. Never broadcast formation mutations.
 if #members==0 then if done then done(); end return; end
 for i,m in ipairs(members) do
  T:Job(command,m.name,nil,i==#members and done or nil,pause or T.commandInterval);
 end
end

function F:ApplyCommands(channel,field)
 for _,m in ipairs(self.work) do
  self:QueueChanges(m,channel,m[field],m.actual[channel]);
 end
end
function F:QueueChanges(m,channel,wanted,actual)
 local saved=T.queue; T.queue={}; T:Commands(m.name,channel,wanted,actual); local jobs=T.queue; T.queue=saved;
 m.confirmed=m.confirmed or {};
 if #jobs==0 then
  -- During resume the baseline may be old: only a fresh read or acknowledgement qualifies.
  if not self.resumed then m.confirmed[channel]=self:Copy(actual); end
  return;
 end
 for i,job in ipairs(jobs) do
  if not self:CommandWasSent(job.command,m.name) then
   local final=i==#jobs;
   T:Job(job.command,m.name,nil,function()
    if final then
     m.sentStrategies=m.sentStrategies or {}; local planned=self:Copy(actual);
     for key,value in pairs(wanted) do planned[key]=value; end
     m.sentStrategies[channel]=planned; m.confirmed[channel]=nil;
     T:Log(m.name..": "..channel.." отправлен без ожидания ответа","sent",m.name);
    end
   end);
  end
 end
end
function F:Validate(profile)
 if not profile or type(profile.points)~="table" or type(profile.tanks)~="table" then return false,"сначала сохрани две точки танков"; end
 for side=1,2 do
  local p,r=profile.points[side],profile.tanks[side];
  if not p or type(p.x)~="number" or type(p.y)~="number" or p.x~=p.x or p.y~=p.y
   or math.abs(p.x)>100000 or math.abs(p.y)>100000 or not r or not r.className or not r.spec then return false,"неполная запись стороны "..side; end
 end
 if T:Near(profile.points[1],profile.points[2]) then return false,"точки танков совпадают"; end
 return true;
end
function F:Build(profile)
 local ok,reason=self:Validate(profile); if not ok then return nil,reason; end
 local members=self:Roster(); local chosen; chosen,reason=self:PickTanks(profile,members); if not chosen then return nil,reason; end
 for side=1,2 do
  chosen[side].side=side;
 end
 local heals={0,0};
 for _,m in ipairs(members) do
  if not m.className or not m.spec then return nil,m.name..": реестр ещё не определил класс/спек"; end
  local rule=(profile.rules or {})[self:RuleKey(m)] or {target=self:DefaultTarget(m)};
  m.role=m.side and "tank" or (self:Healer(m) and "heal" or "dps");
  local target=rule.target or self:DefaultTarget(m);
  if target~="skull" and target~="star" and target~="split" then return nil,"неизвестная цель "..self:RuleKey(m); end
  if m.side then target=m.side==1 and "skull" or "star";
  elseif m.role=="heal" and target=="split" then target=heals[1]<=heals[2] and "skull" or "star";
  elseif target=="split" then target="skull"; end
  m.target=target; local side=target=="skull" and 1 or 2;
  m.point=self:Copy(profile.points[side]);
  m.co=m.side and self:Copy(T.desired.co) or self:Copy(rule.co or {});
  if m.side and (profile.fightControl=="retreat_manual" or profile.fightControl=="retreat_auto") then
   if m.side==1 then m.co.stay=false; m.co.close=true;
   else m.co.passive=true; end -- The second melee tank is a parked reserve, not Vek'lor's tank.
  end
  if not m.side then m.co.stay=false; end -- Only the two primary tanks remain anchored in combat.
  m.nc=self:Copy(rule.nc or {}); if m.role=="heal" then heals[side]=heals[side]+1; end
 end
 if heals[1]==0 or heals[2]==0 then return nil,"нужны хилы у обоих танков: выбери «Обе стороны» или раздели спеки по сторонам"; end
 if select(2,self:Key())=="40n6" then
  local counts={tank=0,heal=0,dps=0}; for _,m in ipairs(members) do
   local role=self:IsTank(m) and "tank" or self:Healer(m) and "heal" or "dps"; counts[role]=counts[role]+1;
  end
  if #members~=6 or counts.tank~=2 or counts.heal~=2 or counts.dps~=2 then
   return nil,"малый пресет требует ровно 2 танка, 2 ДД и 2 хила онлайн; призови его состав отдельно от большого рейда";
  end
 end
 profile.selectedTanks=profile.selectedTanks or {}; for side=1,2 do profile.selectedTanks[side]=chosen[side].name; end
 return members;
end
function F:Remember(m,actual,managed)
 local store=T:Store(); local key=m.side and tostring(m.side) or "formation:"..m.name;
 if store[key] and store[key].name~=m.name then
  local old=store[key]; local archive="formation:"..old.name;
  if store[archive] then T:Stop("старый снимок "..old.name.." ещё не восстановлен"); return false; end
  store[archive]=old; store[key]=nil;
 end
 if not store[key] then store[key]={name=m.name,context=T:Context(),co=self:Copy(actual.co),nc=self:Copy(actual.nc),rti=actual.rti,petStance=actual.petStance,managed={co={},nc={}}}; end
 local r=store[key]; if r.context~=T:Context() then T:Stop(m.name..": остался снимок из другой зоны"); return false; end
 if r.petStance==nil then r.petStance=actual.petStance; end
 m.petStanceOriginal=r.petStance;
 if not r.managed then r.managed=self:Copy(T.desired); end
 for _,channel in ipairs({"co","nc"}) do for strategy in pairs(managed[channel]) do r.managed[channel][strategy]=true; end end
 return true;
end
function F:Save()
 if not self:ReadyToWork() then return false; end
 if not T:SidesReady() then self:Message("сначала один раз расставь двух танков и дождись подтверждения сторон"); return false; end
 self:InvalidateCheckpoint("edited");
 self.capturePrepared={};
 self.captureReuse=self.prepared and self:SameRoster();
 if self.prepared then for _,m in ipairs(self.participants or {}) do self.capturePrepared[m.name]={co=self:Copy(m.co),nc=self:Copy(m.nc)}; end end
 local rules=self:Rules(); local work,seen={},{}; local tanks={};
 for side=1,2 do local p=UnBotBotRegistry.bots[T.slots[side].name]; tanks[side]={className=p.className,spec=self:Spec(p)}; end
 for _,m in ipairs(self:Roster()) do
  local primary=m.name==T.slots[1].name or m.name==T.slots[2].name;
  local key=self:RuleKey(m); if not primary and not seen[key] then work[#work+1]=m; seen[key]=true; end
 end
 self:Begin("capture",work); self.candidate={points={self:Copy(T.slots[1].point),self:Copy(T.slots[2].point)},tanks=tanks,rules=rules};
 self:Message("запоминаю две опорные точки, цели и co/nc по классам/спекам; затем расставлю текущий состав"); self:NextCapture(); return true;
end
function F:NextCapture()
 self.index=self.index+1; local m=self.work[self.index]; if not m then self:Commit(); return; end
 self:Read(m,function(actual)
  local rule=self.candidate.rules[self:RuleKey(m)];
  local desired=self.capturePrepared[m.name] or actual;
  rule.co=self:Snapshot("co",desired.co); rule.co.stay=false; rule.nc=self:Snapshot("nc",desired.nc);
  T:AdvanceProgress(T.progress);
  self:NextCapture();
 end);
end
function F:Commit()
 local ok,reason=self:Validate(self.candidate); if not ok then T:Stop(reason); self:Message("не сохранено: "..reason); return; end
 local members; members,reason=self:Build(self.candidate); if not members then T:Stop(reason); self:Message("не сохранено: "..reason); return; end
 local p=self:Profile(true);
 p.points=self:Copy(self.candidate.points); p.tanks=self:Copy(self.candidate.tanks); p.rules=self:Copy(self.candidate.rules);
 p.context=T:Context(); p.schemaVersion=2; p.savedAt=time and time() or nil; if p.enabled==nil then p.enabled=true; end
 self.active=false; self.candidate=nil; self.capturePrepared=nil; self.reusePrepared=self.captureReuse; self.captureReuse=nil; T.stage=nil; T.expires=nil;
 self:Message("две точки и правила класс/спек сохранены. Имена и число ДД/хилов не привязаны; для записи на диск нужен /reload");
 self.pendingAuto={owner=self:Key(),mode=select(2,self:Key()),context=T:Context(),at=GetTime()+900};
end
function F:PendingRecovery(members)
 local names={}; for _,m in ipairs(members) do names[m.name]=true; end
 for _,r in pairs(T:Store()) do if type(r)=="table" and names[r.name] then return true; end end return false;
end
function F:Apply()
 if not self:ReadyToWork() then return false; end
	if not self.resumeLog then T:BeginLog("saved_points"); end
	self.resumeLog=nil;
 local p=self:Profile(); if not p or p.context~=T:Context() then self:Message("для этого варианта пресета и комнаты нет сохранённой расстановки"); return false; end
 local members,reason=self:Build(p); if not members then self:Message(reason.."; бой не начат"); return false; end
 for _,m in ipairs(members) do T.log.names[m.name]=true; end
 local checkpoint=p.preparation or self:AdoptCheckpoint(members,p);
 if self:CheckpointMatches(checkpoint,members,p) then self:ResumeCheckpoint(checkpoint); return true; end
 if checkpoint and checkpoint.status=="active" then checkpoint.status="changed"; self.checkpoint=nil; T:Log("Сохранённый этап не подходит текущему составу, пресету или подгруппам; новая подготовка"); end
 local reuse=(self.prepared or self.reusePrepared) and self:SameRoster(); self.reusePrepared=nil;
 if not reuse and self:PendingRecovery(members) then
  if T:AutoRestoreBlocked() then self:Message("после «Начать бой» автоматический возврат запрещён; для новой расстановки нажми «Стандарт: reset botAI» вне боя"); return false; end
  self.prepared=false; T:Restore(); self.resumeLog=true; self.resume={at=GetTime()+math.max(90,#members*26),owner=self:Key(),mode=select(2,self:Key()),context=T:Context()};
  self:Message("восстанавливаю прежние настройки участников перед новой расстановкой"); return true;
 end
 self:Begin("apply",members); self.participants=members; T.slots={};
 self:NewCheckpoint();
 T.selectionOwner,T.selectionMode=self:Key();
 T:Log("участников: "..#members.."; читаю исходные co/nc, RTI и стойки питомцев до движения");
 for _,m in ipairs(members) do T:Log(m.name..": "..(m.target=="skull" and "Череп" or "Звезда")..", "..m.role..", "..self:Go(m.point)); end
 for _,m in ipairs(members) do if m.side then T.slots[m.side]={name=m.name,side=m.side,point=self:Copy(m.point),position="ub_twins_"..m.side,icon=m.target}; end end
 local ok; ok,reason=self:PlanGroups(); if not ok then T:Stop(reason); return false; end
 T:SetProgress("Подгруппы",#members);
 self:Message("распределяю состав на Череп и Звезду по классу/спеку; хилы входят в обе стороны. Перемещение ещё не начато"); return true;
end
function F:Go(point)
 local sep=(point.x<0 or point.y<0 or point.x>100 or point.y>100) and ";" or ",";
 return "go "..string.format("%.4f",point.x)..sep..string.format("%.4f",point.y);
end
function F:NextMove()
 self.index=self.index+1; local m=self.work[self.index]; if not m then self:PrepareGroups(); return; end
 if m.readDone then self:NextMove(); return; end
 self:Read(m,function(actual)
  local ncBase=self:Copy(actual.nc); for key,value in pairs(m.nc) do ncBase[key]=value; end m.nc=ncBase;
  if m.co.passive==nil then m.co.passive=actual.co.passive==true; end
  m.actual=actual; m.prepCO=self:Copy(m.co); m.prepCO.passive=true; m.moveNC=self:MoveNC(ncBase,false);
  if not self:Remember(m,actual,{co=m.prepCO,nc=self:MoveNC(ncBase,true)}) then return; end
  m.readDone=true;
  T:AdvanceProgress(T.progress);
  self:NextMove();
 end);
end
function F:PrepareGroups()
 self:CheckpointPhase("prepare");
 self:Message("исходные настройки прочитаны; отправляю только различия co/nc и подготовку питомцев адресно");
 self:ApplyCommands("co","prepCO"); self:ApplyCommands("nc","moveNC");
 local pets={}; for _,m in ipairs(self.work) do if m.pet then pets[#pets+1]=m; end end
 local passive={}; for _,m in ipairs(pets) do if m.actual.petStance~="passive" then passive[#passive+1]=m; end end
 self:Batch("pet passive",passive); self:Batch("pet follow",pets);
 T:Log("далее — завершение отправки co/nc и проверка питомцев до первого движения");
 T:TrackQueuedProgress("Команды подготовки",function()
  self.index=0; T:SetProgress("Проверка стратегий",#self.work); self:CheckpointPhase("safety"); self:NextSafetyCheck();
 end);
end
function F:SendToPoints()
 self:CheckpointPhase("move");
 self:AssignTargets();
 self:Batch(self:Go(self.groups.skull[1].point),self.groups.skull);
 self:Batch(self:Go(self.groups.star[1].point),self.groups.star);
 T:TrackQueuedProgress("Команды отправки на точки",function()
  T.nextSend=GetTime()+4; self.index=0; T:SetProgress("Прибытие на точки",#self.work);
  self:CheckpointPhase("arrival"); self:NextArrival();
 end);
end
function F:NextSafetyCheck()
 self.index=self.index+1; local m=self.work[self.index];
 if not m then
  self:Message("co/nc отправлены всем участникам, питомцы проверены. Отправляю Череп и Звезду на их точки");
  self:SendToPoints(); return;
 end
 local function afterNC()
  if m.pet then T:Job("pet stance",m.name,"pet",function(stance)
   if stance~="passive" then T:Stop(m.name..": питомец не пассивен; перемещение отменено"); return; end T:AdvanceProgress(T.progress); self:NextSafetyCheck();
  end); else T:AdvanceProgress(T.progress); self:NextSafetyCheck(); end
 end
 self:CheckConfirmed(m,"co",m.prepCO,function() self:CheckConfirmed(m,"nc",m.moveNC,afterNC); end);
end
function F:CheckConfirmed(m,channel,wanted,done)
 local dispatched=m.sentStrategies and m.sentStrategies[channel];
 local value=dispatched or (m.confirmed and m.confirmed[channel]);
 if value and T:Matches(wanted,value) then
  T:Log(m.name..": "..channel..(dispatched and " уже отправлен; опрос пропущен" or " уже прочитан; дополнительный запрос пропущен")); done(); return;
 end
 T:Job(channel.." ?",m.name,channel,function(actual)
  local ok,key=T:Matches(wanted,actual); if not ok then T:Stop(m.name..": подготовка не подтверждена: "..channel.." "..key); return; end
  m.confirmed=m.confirmed or {}; m.confirmed[channel]=self:Copy(actual); done();
 end);
end
function F:NextArrival()
 self.index=self.index+1; local m=self.work[self.index];
 if not m then self:CheckAnchors(); return; end
 m.polls=0; self:CheckArrival(m);
end
function F:CheckArrival(m)
 m.polls=m.polls+1;
 T:Job("go ?",m.name,"coords",function(point)
  if not T:Near(point,m.point) then
   if m.polls>=4 then T:Stop(m.name..": не прибыл на опорную точку; атака не отправлена"); return; end
   self:CheckArrival(m); return;
  end
  if m.arrivedDone then T:AdvanceProgress(T.progress); self:NextArrival(); else self:Anchor(m); end
 end);
 if m.polls>1 then T.queue[#T.queue].readyAt=GetTime()+5; end
end
function F:Anchor(m)
 local hold=self:MoveNC(m.nc,true);
 T:Job("position stay set",m.name,"set");
 if m.side then T:Job("position ub_twins_"..m.side.." set",m.name,"set"); end
 self:QueueChanges(m,"nc",hold,m.moveNC);
 -- Collect anchors for the whole roster before verifying: avoid a 2.5-second wait on every bot.
 self:AfterQueue(function() m.polls=nil; m.arrivedDone=true; T:AdvanceProgress(T.progress); self:NextArrival(); end);
end
function F:CheckAnchors()
 self:CheckpointPhase("anchors");
 self:Message("все прибыли; проверяю удержание точек и RTI всего состава");
 T:SetProgress("Проверка удержания точек",#self.work);
 local holding={};
 for _,m in ipairs(self.work) do
  local value=(m.sentStrategies and m.sentStrategies.nc) or (m.confirmed and m.confirmed.nc);
  if not value or not T:Matches(self:MoveNC(m.nc,true),value) then holding[#holding+1]=m;
  else T:AdvanceProgress(T.progress); end
 end
 T:ReadWave(holding,"nc ?","nc",function(observed)
  local targets={};
  for _,m in ipairs(self.work) do
   local ok,key=T:Matches(self:MoveNC(m.nc,true),observed[m.name] or (m.sentStrategies and m.sentStrategies.nc) or (m.confirmed and m.confirmed.nc));
   if not ok then T:Stop(m.name..": не подтверждён nc "..key); return; end
   if m.role~="heal" then targets[#targets+1]=m; end
  end
  T:SetProgress("Проверка RTI",#targets);
  local pending={}; for _,m in ipairs(targets) do
   if not m.confirmed or m.confirmed.rti~=m.target then pending[#pending+1]=m;
   else T:AdvanceProgress(T.progress); end
  end
  T:ReadWave(pending,"rti ?","rti",function(icons)
   for _,m in ipairs(targets) do
    local icon=icons[m.name] or (m.confirmed and m.confirmed.rti);
    if icon~=m.target then T:Stop(m.name..": сервер не подтвердил цель "..m.target); return; end
    m.actual.rti=icon;
   end
   for _,m in ipairs(self.work) do if m.side then T.slots[m.side].verified=true; end end
   self.active=false; self.prepared=true; T.stage=nil; T.expires=nil;
   T:SetProgress("Расстановка завершена",#self.work); T.progress.done=#self.work;
   self:CheckpointPhase("ready");
   local state=UnBotTwinEmperors; state.prepared=false; T:BeginMarkCheck();
   if self.frame then self.frame:Hide(); end
   T:Show();
   self:Message("все "..#self.participants.." ботов на точках танков; Череп и Звезда готовы, хилы с обеих сторон. Боты и питомцы пассивны до «Начать бой»");
  end);
 end);
end

function F:Casters()
 local names={}; for _,m in ipairs(self.participants or {}) do if m.role=="dps" and m.target=="star" and T:Unit(m.name) then names[#names+1]=m.name; end end
 return names;
end
function F:AssignTargets()
 for _,target in ipairs({"skull","star"}) do
  for _,m in ipairs(self.groups[target]) do
   if m.role~="heal" then
    if (self.prepared or not self.resumed) and m.actual and m.actual.rti==target then
     m.confirmed=m.confirmed or {}; m.confirmed.rti=target;
    elseif not self:CommandWasSent("rti "..target,m.name) then
     local member=m;
     T:Job("rti "..target,m.name,"rti",function(icon)
      if icon~=member.target then T:Stop(member.name..": сервер не подтвердил цель "..member.target); return; end
      member.confirmed=member.confirmed or {}; member.confirmed.rti=icon;
     end);
    end
   end
  end
 end
end
function F:QueueAttacks()
 self:ReleasePets();
 for _,target in ipairs({"skull","star"}) do local members={};
  for _,m in ipairs(self.groups[target]) do if m.role=="dps" then members[#members+1]=m; end end
  self:Batch("attack rti target",members);
 end
 UnBotTwinEmperors.refocusAt=nil;
end
function F:ReleaseForPull()
 T.expires=GetTime()+math.min(600,#self.work*12+30); self.index=0;
 T:SetProgress("Перед боем: боевые стратегии",#self.work);
 self:Message("снимаю временную пассивность: по одной команде каждому, без ожидания ответов и дополнительных co ?");
 self:NextPullCheck();
end
function F:ReleasePets()
 local stances={}; for _,m in ipairs(self.work) do if m.pet and not m.co.passive and m.petStanceOriginal~="passive" then
  local stance=m.petStanceOriginal; stances[stance]=stances[stance] or {}; table.insert(stances[stance],m);
 end end
 for _,stance in ipairs({"defensive","aggressive"}) do if stances[stance] then self:Batch("pet "..stance,stances[stance]); end end
 for _,m in ipairs(self.work) do if m.pet and not m.co.passive then local member=m;
  T:Job("pet stance",m.name,"pet",function(stance)
   if stance~=member.petStanceOriginal then T:Stop(member.name..": не восстановлена боевая стойка питомца"); end
  end);
 end end
end
function F:NextPullCheck()
 self.index=self.index+1; local m=self.work[self.index];
 if not m then T.stage=nil; T.expires=nil; T.startRequested=nil; T:StartFightNow(); return; end
 if m.co.passive==true then T:AdvanceProgress(T.progress); self:NextPullCheck(); return; end
 T:Job("co -passive",m.name,nil,function()
  local planned=self:Copy(m.actual.co); for key,value in pairs(m.co) do planned[key]=value; end
  m.actual.co=planned; m.sentStrategies=m.sentStrategies or {}; m.sentStrategies.co=planned;
  if m.confirmed then m.confirmed.co=nil; end
  T:AdvanceProgress(T.progress); self:NextPullCheck();
 end);
end
function F:AfterSummon()
	if UnBotTwinEmperors.playerTank and UnBotTwinEmperors.playerTank:Selected() then self.pendingAuto=nil; return; end
	if UnBotTwinEmperors.retreat and UnBotTwinEmperors.retreat:IsMobile() then
		self.pendingAuto=nil; self.prepared=false; self:Message("подвижный режим: точки не нужны; подготовь двух танков в /ubtwins tanks и запусти бой отдельно"); return;
	end
 local p=self:Profile(); if not p or not p.enabled or not p.points then return; end
 self:InvalidateCheckpoint("summoned");
 local owner,mode=self:Key(); self.pendingAuto={owner=owner,mode=mode,context=T:Context(),at=GetTime()+900}; self.prepared=false;
 self:Message("после призыва и баффов автоматически расставлю текущие классы/спеки на сохранённые точки");
end
function F:Cancelled()
 self:InvalidateCheckpoint("cancelled");
 self.active=false; self.prepared=false; self.pendingAuto=nil; self.resume=nil; self.resumeLog=nil; self.candidate=nil; self.capturePrepared=nil; self.captureReuse=nil; self.reusePrepared=nil; self.groupPlan=nil; self.routingSignature=nil; self:Refresh();
end
function F:Tick()
 local now=GetTime(); local owner,mode=self:Key(); local wait=self.resume or self.pendingAuto;
 if (self.active or self.prepared and not T.armed) and UnBotTwinEmperors:GroupInCombat() then
  T:Stop("до команды атаки танкам начался бой; подготовка отменена"); return;
 end
 if wait then
  if wait.owner~=owner or wait.mode~=mode or wait.context~=T:Context() or now>=wait.at or UnBotTwinEmperors:GroupInCombat() then
   self.resume=nil; self.resumeLog=nil; self.pendingAuto=nil; self:Message("ожидание отменено: смена пресета/зоны, бой или таймаут");
  elseif not T:Busy() and not T.stage and not T.restoring and not T.pending and #T.queue==0 then
   if self.resume then
    local members=self:Build(self:Profile()); self.resume=nil;
    if not members or self:PendingRecovery(members) then self.resumeLog=nil; self:Message("прежние настройки не восстановлены; снимок сохранён, бой не разрешён"); return; end
   else self.pendingAuto=nil; end
   self:Apply();
  end
 end
 if self.active and not self:SameRoster() then T:Stop("изменился ростер или пресет во время расстановки; повтори её для нового состава"); end
 if self.active and self.groupPlan then self:ArrangeGroups(); end
end
function F:Refresh()
 if not self.frame then return; end
 local p=self:Profile(); local rules=self:Rules(); local keys={}; for key in pairs(rules) do keys[#keys+1]=key; end table.sort(keys);
 self.frame.auto:SetChecked(p and p.enabled or false);
 self.frame.status:SetText(self.status or (p and p.points and "Две точки сохранены. При следующем призыве любой состав расставляется по классу/спеку; хилы делятся по сторонам." or "Один раз расставь танков, проверь цели классов/спеков и нажми «Сохранить и расставить»."));
 for i,row in ipairs(self.frame.rows) do
  local key=keys[i]; row.key=key; row.rule=key and rules[key];
  if key then
   row:Show(); row.name:SetText(rules[key].className.." / "..rules[key].spec);
   row.target:SetText(self.targets[rules[key].target] or rules[key].target);
   if self.active or T.armed or T.stage then row.target:Disable(); else row.target:Enable(); end
  else row:Hide(); end
 end
 if self.active or T.stage or T.restoring or T.armed then self.frame.save:Disable(); self.frame.apply:Disable(); else self.frame.save:Enable(); self.frame.apply:Enable(); end
 if self.frame.returnOriginal then if T.restoring or UnBotTwinEmperors:GroupInCombat() then self.frame.returnOriginal:Disable(); else self.frame.returnOriginal:Enable(); end end
end
function F:Show()
 if not self:EnsurePreset() then self:Message("сначала выбери пресет Императоров-близнецов"); return; end
 if not self.frame then
  local f=CreateFrame("Frame","UnBotTwinFormationFrame",UIParent); self.frame=f;
  f:SetSize(640,580); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton");
  f:SetScript("OnDragStart",function() f:StartMoving(); end); f:SetScript("OnDragStop",function() f:StopMovingOrSizing(); end);
  f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=32,insets={left=8,right=8,top=8,bottom=8}});
  local title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); title:SetPoint("TOP",0,-18); title:SetText("Близнецы — точки и цели классов/спеков");
  local close=CreateFrame("Button",nil,f,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",-4,-4);
  local hint=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); hint:SetPoint("TOPLEFT",18,-48); hint:SetSize(600,70); hint:SetJustifyH("LEFT");
  hint:SetText("После выбора двух точек танков состав автоматически делится на Череп и Звезду. Хилы «Обе стороны» распределяются между ними.\nТаблица необязательна: нажми цель класса/спека, чтобы сменить его сторону.\nДо перемещения: co +passive, pet passive / follow; на точках nc +stay. «Начать бой» возвращает боевые настройки. В бою держатся только два танка.");
  local function button(text,x,y,width,action)
   local b=CreateFrame("Button",nil,f,"UIPanelButtonTemplate"); b:SetSize(width,24); b:SetPoint("TOPLEFT",x,y); b:SetText(text); b:SetScript("OnClick",action); return b;
  end
  button("Расставить танков...",18,-125,280,function() T:Show(); f:Hide(); end);
  f.stop=button("Стоп",316,-125,88,function() T:StopOnly(); end);
  f.returnOriginal=button("Стандарт: reset botAI",412,-125,210,function() T:ReturnOriginal(); end);
  f.auto=CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate"); f.auto:SetSize(24,24); f.auto:SetPoint("TOPLEFT",18,-157);
  local label=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); label:SetPoint("LEFT",f.auto,"RIGHT",2,0); label:SetText("После призыва этого пресета автоматически восстановить расстановку");
  f.auto:SetScript("OnClick",function(b)
   if F.active or T.stage or T.armed then F:Refresh(); return; end
   local p=F:Profile(true); p.enabled=b:GetChecked() and true or false; if not p.enabled then F.pendingAuto=nil; end F:Refresh();
  end);
  local scroll=CreateFrame("ScrollFrame","UnBotTwinFormationScroll",f,"UIPanelScrollFrameTemplate"); scroll:SetPoint("TOPLEFT",18,-190); scroll:SetSize(580,282);
  local child=CreateFrame("Frame",nil,scroll); child:SetSize(580,80*24); scroll:SetScrollChild(child); f.rows={};
  for i=1,80 do
   local row=CreateFrame("Frame",nil,child); row:SetSize(580,23); row:SetPoint("TOPLEFT",0,-(i-1)*24); f.rows[i]=row;
   row.name=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); row.name:SetPoint("LEFT",0,0); row.name:SetSize(330,20); row.name:SetJustifyH("LEFT");
   row.target=CreateFrame("Button",nil,row,"UIPanelButtonTemplate"); row.target:SetSize(230,22); row.target:SetPoint("RIGHT");
   row.target:SetScript("OnClick",function()
    if not row.rule or F.active or T.stage or T.armed then return; end
    local choices=F:Healer(row.rule) and {"split","skull","star"} or {"skull","star"};
    local index=1; for j,value in ipairs(choices) do if value==row.rule.target then index=j%#choices+1; break end end
    F.draft[row.key]=choices[index]; F:Refresh();
   end);
   row.target:SetScript("OnEnter",function(b)
    if not GameTooltip or not row.rule then return; end
    GameTooltip:SetOwner(b,"ANCHOR_RIGHT"); GameTooltip:AddLine("Старт на точке выбранного танка; цель ДД — этот босс.",1,1,1,true);
    for _,channel in ipairs({"co","nc"}) do
     local keys={}; for key,value in pairs(row.rule[channel] or {}) do keys[#keys+1]=(value and "+" or "-")..key; end table.sort(keys);
     GameTooltip:AddLine(channel.." "..(#keys>0 and table.concat(keys,", ") or "серверные настройки"),0.8,0.8,0.8,true);
    end
    GameTooltip:AddLine("co -stay: свободное движение в бою. nc +stay: удержание точки до пула. Личные профили альтов не меняются.",1,0.8,0,true); GameTooltip:Show();
   end);
   row.target:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide(); end end);
  end
  f.save=button("Сохранить и расставить",18,-484,280,function() F:Save(); end);
  f.apply=button("Восстановить расстановку",316,-484,306,function() F:Apply(); end);
  f.status=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); f.status:SetPoint("TOPLEFT",18,-520); f.status:SetSize(600,45); f.status:SetJustifyH("LEFT");
 end
 if T.frame then T.frame:Hide(); end self.frame:Show(); self:Refresh();
end
end

-- Loaded here deliberately: WotLK can retain its TOC file list across /reload.
-- Optional Twin Emperors experiment. `do flee` invokes the movement action;
-- the ordinary chat shortcut `flee` would reset strategies and is forbidden here.
do
local S=UnBotTwinEmperors;
local T=S.tanks;
local R={epoch=0,maxSteps=6,maxTotal=40,stepDistance=20,stepInterval=1.2}; S.retreat=R;

function R:Mode()
 local p=S.formation:Profile(); return p and p.fightControl or "anchors";
end
function R:CanChange()
 return not S:GroupInCombat() and not S.active and #S.queue==0 and not T.armed and not T.stage and not T.restoring
  and not T.pending and #T.queue==0 and not S.formation.active and not T:Busy();
end
function R:SetMode(mode)
 if not ({anchors=true,retreat_manual=true,retreat_auto=true,mobile_auto=true})[mode] then return; end
 if not self:CanChange() then T:Message("режим меняется вне боя после остановки текущей очереди; исходные настройки возвращать не нужно"); return; end
 S.formation:InvalidateCheckpoint("control_changed");
 S.formation:Profile(true).fightControl=mode; S.formation.prepared=false; S.formation.pendingAuto=nil;
 self.freeReady=nil; S.prepared=false;
 T:Message("режим сохранён для этого персонажа и пресета: "..self:Label()..(mode=="mobile_auto" and ". Нажми «Подготовить подвижных танков»: точки не требуются." or ". Примени расстановку заново."));
end
function R:Label()
 return ({anchors="два края",retreat_manual="Череп: ручной шаг",retreat_auto="Череп: автоотход (тест)",mobile_auto="смена боссов + отвод, без точек"})[self:Mode()] or "два края";
end
function R:Cancel()
 self.epoch=self.epoch+1; self.enabled=false; T.retreatMode=false;
 self.busy=false; self.interceptAt=nil; self.deadline=nil; self.verifyAt=nil;
 self.before=nil; self.lastHealAt=nil; self.fleeAt=nil;
 self.worldBefore=nil; self.waypoint=nil; self.moveAt=nil;
 self.geometry=nil;
 self.freeReady=nil; self.mobile=false;
 self.phase=nil; self.dps=nil; self.arena=nil; self.localMove=nil;
 self.localVerifyAt=nil; self.phaseUntil=nil; self.stableAt=nil;
 self.movementFailed=nil; self.approaches=nil; self.threatSent=nil;
 self.gateBusy=false; self.separation=nil; self.contacts=nil; self.inspectSide=nil;
 self.targetAttempts=nil; self.targetNext=nil; self.combatRetargeted=nil; self.monitorAt=nil; self.initialApproach=nil;
 self.initialWalk=nil; self.initialWalkUsed=nil;
 self.blocked=nil; self.holdState=nil; self.targetCheck=nil; self.checkRunning=nil; self.checkRequested=nil;
end
function R:Arm()
 self:Cancel(); local mode=self:Mode();
 if mode~="retreat_manual" and mode~="retreat_auto" then return false; end
 self.enabled=true; T.retreatMode=true; self.auto=mode=="retreat_auto";
 self.main=T.slots[1].name; self.steps=0; self.total=0; self.teleports=0; self.nextStep=0;
 T:Message("отвод Черепа готов: "..self.main.." держит Век’нилаша; "..T.slots[2].name.." — пассивный резерв. "
  ..(self.auto and "При лечении близнецов: до 6 шагов за фазу." or "Шаг — отдельной кнопкой в окне танков.").." Без возврата на края.");
 return true;
end

-- Free-position scenario: preparation changes strategies, never positions.
function R:IsMobile() return self:Mode()=="mobile_auto"; end
function R:FreeReady()
 local ready=self.freeReady; if not ready or ready.context~=T:Context() then return false; end
 local owner,mode=S.formation:Key(); if ready.owner~=owner or ready.mode~=mode then return false; end
 if ready.signature~=self:RosterSignature() then return false; end
 for side=1,2 do if not T.slots[side] or T.slots[side].name~=ready.names[side] or not T:Unit(ready.names[side]) then return false; end end
 return true;
end
function R:FreeMarks()
 if not self:FreeReady() or S:GroupInCombat() or T.stage or T.pending or T.restoring or T.armed or #T.queue>0 then return false; end
 S.enabled=true; S.manual=true; S.suppressed=false; S.cooldownUntil=0; T.markCheckUntil=GetTime()+60;
 S:Prepare(); return true;
end
function R:PrepareFree()
 if not self:IsMobile() or S:GroupInCombat() or T.armed or T.stage or T.restoring or T.pending or #T.queue>0
  or S.active or S.formation.active or T:Busy() or not T:InRoom() or UnitIsDeadOrGhost("player") then return false; end
 T:AutoSelect(); if not T.slots[1] or not T.slots[2] or T.slots[1].name==T.slots[2].name then T:Message("выбери двух разных онлайн-танков"); return false; end
 self:Cancel(); local epoch=self.epoch; local F=S.formation; local work={};
 F.prepared=false;
 T:BeginLog("mobile_tanks"); T.context=T:Context(); T.stage="mobile_prepare"; T.expires=GetTime()+180;
 S.enabled=true; S.manual=true; S.suppressed=false; S.prepared=false;
 for side=1,2 do
  local name=T.slots[side].name; if not T:Unit(name) then T:StopOnly("танк недоступен"); return false; end
  local m={name=name,side=side,co=F:Copy(T.desired.co)}; m.co.stay=true; m.co.close=false;
  work[side]=m; T.log.names[name]=true;
 end
 T:SetProgress("Подвижные танки: проверка настроек",2);
 local index=0;
 local function nextTank()
  if self.epoch~=epoch then return; end
  index=index+1; local m=work[index];
  if not m then
   self:PrepareDamage(epoch,function()
    T.stage=nil; T.expires=nil; self.freeReady={context=T:Context(),owner=F:Key(),mode=select(2,F:Key()),signature=self:RosterSignature(),names={work[1].name,work[2].name},tankNC={[work[1].name]=work[1].actualNC,[work[2].name]=work[2].actualNC}};
    for _,slot in pairs(T.slots) do slot.verified=true; end
    self:FreeMarks(); T:Message("подвижные танки готовы; ДД пассивны до подтверждения агро и 80 ярдов между боссами. Хилы активны. Точки не нужны.");
   end); return;
  end
  F:Read(m,function(actual)
   if self.epoch~=epoch then return; end
   if not F:Remember(m,actual,{co=m.co,nc={}}) then return; end
   m.actualNC=F:Copy(actual.nc);
   -- Refresh the server's live hold position before enabling stay. This
   -- neither moves a tank nor uses a saved encounter anchor.
   T:Job("position stay set",m.name,"set");
   T:Commands(m.name,"co",m.co,actual.co);
   T:Job("co ?",m.name,"co",function(observed)
    if self.epoch~=epoch then return; end
    local ok,key=T:Matches(m.co,observed);
    if not ok then T:StopOnly(m.name..": не подтверждён co "..key); T:Message("подготовка остановлена: сервер не подтвердил подвижные настройки; исходный снимок сохранён"); return; end
    T:AdvanceProgress(T.progress); nextTank();
   end);
  end);
 end
 nextTank(); return true;
end
function R:CanStartFree()
 return self:IsMobile() and self:FreeReady() and T:MarksReady() and not S.active and not T.armed and not T.stage
  and not T.pending and #T.queue==0 and #S.queue==0 and not T.restoring and not T:Busy()
  and not S:GroupInCombat() and T:InRoom() and not UnitIsDeadOrGhost("player");
end
function R:StartFree()
 if not self:CanStartFree() then T:Message("сначала подготовь подвижных танков и проверь метки вне боя; точки не требуются"); return false; end
 local pullEntry=S:Entry(UnitGUID("target"));
 if pullEntry~=15275 and pullEntry~=15276 then T:Message("для команды attack выдели Век’нилаша или Век’лора и снова нажми «Начать бой»"); return false; end
 if not T.log then T:BeginLog("mobile_fight"); end
 for _,slot in ipairs(T.slots) do T.log.names[slot.name]=true; end
 for side=1,2 do local slot=T.slots[side];
  for _,record in pairs(T:Store()) do if type(record)=="table" and record.name==slot.name and record.context==T:Context() then record.noAutoRestore=true; end end
 end
 for _,m in ipairs(self.dps or {}) do
  local record=T:Store()["formation:"..m.name]; if record then record.noAutoRestore=true; end
 end
 self.enabled=true; self.mobile=true; self.auto=true; T.retreatMode=true;
 self.steps=0; self.total=0; self.teleports=0; self.nextStep=0;
 self.phase="acquire"; self.approaches={}; self.threatSent={}; self.contacts={}; self.phaseUntil=GetTime()+120;
 self.initialApproach={}; for _,slot in ipairs(T.slots) do self.initialApproach[slot.name]=true; end
 self.initialWalk=nil; self.initialWalkUsed=nil;
 self.targetAttempts={}; self.targetNext={}; self.combatRetargeted=nil;
 -- Preserve observed initial targets when the two tanks already select different twins.
 local first=S:Entry(UnitGUID(T:Unit(T.slots[1].name).."target"));
 local second=S:Entry(UnitGUID(T:Unit(T.slots[2].name).."target"));
 if (first==15275 and second==15276) or (first==15276 and second==15275) then
  T.slots[1].icon=first==15275 and "skull" or "star"; T.slots[2].icon=second==15275 and "skull" or "star";
 else T.slots[1].icon="skull"; T.slots[2].icon="star"; end
 self.main=T.slots[T.slots[1].icon=="skull" and 1 or 2].name;
 T.armed=true; T.context=T:Context(); T.expires=GetTime()+900; T.lastTeleport=-1000; T.swaps=0;
 T.bossCombatAt=nil; T.aggro={}; T.startRequested={}; T.markCheckUntil=nil;
 S.manual=true; S.enabled=true; S.suppressed=false; S:Start(); S.refocusAt=nil; S.casterCheckAt=nil;
 -- The chat command `attack` means the master's selected target. Send it
 -- only to that twin's tank; all subsequent attacks use the direct RTI action.
 local pullName=T.slots[T.slots[1].icon==(pullEntry==15275 and "skull" or "star") and 1 or 2].name;
 local now=GetTime(); T.lastSent[pullName]={command="attack",at=now};
 T:Log("attack","command",pullName); T.lastLogCommandAt=now;
 SendChatMessage("attack","WHISPER",nil,pullName); T.nextSend=math.max(T.nextSend,now+T.commandInterval);
 if T.frame then T.frame:Hide(); end
 T:Message("attack отправлен "..pullName.."; начинаю подход танков к разным боссам, не ожидая пула. ДД ждут агро и разведения; отвод — от Век’лора."); return true;
end
function R:PhysicalHolder()
 for _,slot in ipairs(T.slots) do
  local unit=T:Unit(slot.name);
  if unit and S:Entry(UnitGUID(unit.."target"))==15275 and T:Holding(15275,slot.name) then return slot.name; end
 end
end
function R:TargetsReady()
 for _,slot in ipairs(T.slots) do
  local unit=T:Unit(slot.name); local entry=slot.icon=="skull" and 15275 or 15276;
  if not unit or S:Entry(UnitGUID(unit.."target"))~=entry or not T:Holding(entry,slot.name) then return false; end
 end
 self.main=self:PhysicalHolder(); return self.main~=nil;
end
function R:Holding()
 local unit=T:Unit(self.main);
 return unit and S:GroupInCombat() and S:Entry(UnitGUID(unit.."target"))==15275 and T:Holding(15275,self.main);
end
function R:Stop(reason)
 if self.mobile and self.enabled and T.armed then self:Block(reason); return; end
 T:StopOnly("Отвод Черепа: "..reason);
 T:Message("отвод остановлен: "..reason..". Настройки и цели не возвращаю; продолжай вручную.");
end
function R:Intercept(delay,retry)
 if self.checkRunning or self.checkRequested then T:Message("проверка целей отменена сменой фазы; можно запросить заново"); end
 self.checkRunning=nil; self.checkRequested=nil;
 self.epoch=self.epoch+1; self.busy=false; self.verifyAt=nil; self.before=nil;
 self.fleeAt=nil; self.lastHealAt=nil; self.deadline=nil;
 self.worldBefore=nil; self.waypoint=nil; self.moveAt=nil;
 self.geometry=nil;
 self.localMove=nil; self.localVerifyAt=nil; self.stableAt=nil;
 self.rtiQueued=nil;
 self.interceptAt=GetTime()+(delay or 0); if not retry then self.retries=0; end
 T.cycleAt=nil; T.cycleDeadline=nil; T.positionCheckAt=nil;
end
function R:QueueMobileAttacks(readyAt)
 local epoch=self.epoch;
 for _,slot in ipairs(T.slots) do
  local name,icon=slot.name,slot.icon;
  T:Job("attack rti target",name,nil,function()
   if not self.enabled or self.epoch~=epoch then return; end
   self.attackAt=GetTime();
  end);
  T.queue[#T.queue].readyAt=readyAt;
  T:Log("перехват назначен: "..name.." -> "..icon,"target_assignment",name);
 end
end
function R:Combat(event,source,dest,spell,...)
 local now=GetTime();
 if self.blocked then
  if (source==15275 or source==15276) and spell==800 and event=="SPELL_AURA_APPLIED" and now-(T.lastTeleport or -1000)>5 then
   T.lastTeleport=now; self.epoch=self.epoch+1; self.targetCheck=nil; self.checkRunning=nil; self.checkRequested=nil;
   for _,slot in ipairs(T.slots) do slot.icon=slot.icon=="skull" and "star" or "skull"; end
   T:Message("телепорт во время удержания: назначения поменялись; пул заблокирован, проверь цели заново");
  end
  return;
 end
 if self.busy and self.worldBefore and source==15275 and (event=="SWING_DAMAGE" or event=="SWING_MISSED"
  or ((event=="SPELL_DAMAGE" or event=="SPELL_MISSED") and spell==26613)) and not T:Holding(15275,self.main) then
  self:Stop("Век’нилаш сменил жертву во время шага"); return;
 end
 if (source==15275 or source==15276) and spell==800 and event=="SPELL_AURA_APPLIED" and now-(T.lastTeleport or -1000)>5 then
  if self.teleports>=30 then self:Stop("лимит 30 телепортов"); return; end
  self.teleports=self.teleports+1; self.steps=0; T.lastTeleport=now; T.swaps=self.teleports;
  T.queue={}; T.pending=nil; self:Intercept(2.5);
  if self.mobile then
   local walking=self.initialWalk; self.initialWalk=nil;
   if walking then for _,slot in ipairs(T.slots) do
    T:Job("position stay set",slot.name,"set"); T:Job("co +stay",slot.name);
   end end
   T.aggro={}; -- Pre-teleport victims cannot prove the new interception.
   -- Twins exchange their actual positions, not the player's stored anchors.
   for _,slot in ipairs(T.slots) do slot.icon=slot.icon=="skull" and "star" or "skull"; T:Job("rti "..slot.icon,slot.name); end
   -- Attack the newly assigned marks as soon as the short teleport stun
   -- ends. Do not wait for the RTI queue to drain and add another delay.
   self.interceptAt=nil; self.rtiQueued=nil;
   self:QueueMobileAttacks(now+2.1);
   self.main=T.slots[T.slots[1].icon=="skull" and 1 or 2].name;
   self.phase="acquire"; self.phaseUntil=now+90; self.approaches={}; self.threatSent={}; self.contacts={}; self.separation=nil;
   self.targetAttempts={}; self.targetNext={}; self.combatRetargeted=true; self.initialApproach=nil;
   self:DamageGate(true);
   T:Message("телепорт: танки меняют боссов — "..T.slots[1].name..": "..T.slots[1].icon..", "..T.slots[2].name..": "..T.slots[2].icon.."; без возврата на точки");
  else T:Message("телепорт: основной танк снова берёт Череп; резерв остаётся на месте. Отвод — после подтверждения агро."); end
 elseif spell==7393 and event=="SPELL_HEAL" and (dest==15275 or dest==15276) and now>(T.lastTeleport or 0)+5 then
  self.lastHealAt=now;
 end
end
-- Raw server coordinates share units/map. `go ?` can return zone percentages
-- and cannot be combined with these boss positions.
function R:PauseMovement(reason)
 if self.mobile and self.enabled and T.armed then self:Block(reason); return; end
 self.epoch=self.epoch+1; self.auto=false; self.busy=false; self.verifyAt=nil;
 self.worldBefore=nil; self.waypoint=nil; self.moveAt=nil;
 self.geometry=nil;
 self.movementFailed=true; self.localMove=nil; self.localVerifyAt=nil;
 if T.pending and T.pending.geometry then T.pending=nil; end
 for i=#T.queue,1,-1 do if T.queue[i].geometry then table.remove(T.queue,i); end end
 T:Message("автоотвод приостановлен: "..reason..". Перехват после телепорта остаётся включён; настройки не возвращаю.");
end
function R:WorldRead(name,command,done)
 T:Job(command,name,"world",done);
 local job=T.queue[#T.queue]; job.geometry=true;
 job.onTimeout=function() self:PauseMovement("сервер не ответил на "..command.."; повторов нет"); end;
end
function R:Geometry(done)
 local epoch=self.epoch; local main=self.main; local unit=T:Unit(main);
 if not unit or not self:Holding() then self:PauseMovement("не подтверждено удержание Век’нилаша"); return; end
 local magical;
 for i=1,GetNumRaidMembers() do
  local u="raid"..i; local name=UnitName(u);
  if name and T:Unit(name) and name~=main and S:Entry(UnitGUID(u.."target"))==15276 then magical=name; break end
 end
 if not magical then self:PauseMovement("нет доступного бота с Век’лором в цели; направление неизвестно"); return; end
 if T.log then T.log.names[magical]=true; end
 local data={};
 local function valid()
  if not self.enabled or self.epoch~=epoch then return false; end
  local otherUnit=T:Unit(magical);
  if not self:Holding() or not otherUnit or S:Entry(UnitGUID(otherUnit.."target"))~=15276 then
   self:PauseMovement("цель или агро изменились при чтении координат"); return false;
  end
  return true;
 end
 self:WorldRead(main,"cdebug position",function(point)
  if not valid() then return; end; data.tank=point;
  self:WorldRead(main,"cdebug tpos",function(physical)
   if not valid() then return; end; data.physical=physical;
   self:WorldRead(magical,"cdebug tpos",function(other)
   if not valid() then return; end; data.magical=other; data.magicalName=magical;
    if point.map~=physical.map or point.map~=other.map or GetTime()-point.at>5 then
     self:PauseMovement("координаты разных карт или устарели"); return;
    end
    done(data);
   end);
  end);
 end);
end
function R:Distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2); end
function R:DirectedStep()
 self.busy=true; local epoch=self.epoch;
 local function move(data)
  if self.epoch~=epoch then return; end
  local p,m,t=data.physical,data.magical,data.tank; local distance=self:Distance(p,m);
  if distance<2 or self:Distance(t,p)>15 then self:PauseMovement("боссы совпадают или танк далеко от Век’нилаша; безопасное направление не подтверждено"); return; end
  local waypoint={x=t.x+self.stepDistance*(p.x-m.x)/distance,y=t.y+self.stepDistance*(p.y-m.y)/distance};
  if self.mobile and not self:InsideSide(self.main,waypoint) then self:PauseMovement("шаг пересекает середину комнаты; движение отменено"); return; end
  if self:Distance(waypoint,m)<self:Distance(t,m)+1 then self:PauseMovement("шаг не увеличивает расстояние до Век’лора"); return; end
  self.geometry=nil;
  self.worldBefore=data; self.waypoint=waypoint;
  -- Stay blocks server reach-spell/melee pursuits. Move its live hold
  -- position to the new waypoint so it cannot undo the commanded retreat.
  local function integer(v) return math.floor(v+0.5); end
  T:Job("position stay "..integer(waypoint.x)..","..integer(waypoint.y)..","..integer(t.z),self.main,"set");
  local holdJob=T.queue[#T.queue]; holdJob.retreatEpoch=epoch; holdJob.geometry=true;
  holdJob.onTimeout=function() self:PauseMovement("сервер не подтвердил новую позицию удержания; шаг отменён"); end;
  T:Job(string.format("go %.2f;%.2f",waypoint.x,waypoint.y),self.main,nil,function()
   if not self.enabled or self.epoch~=epoch then return; end
   self.steps=self.steps+1; self.total=self.total+1; self.moveAt=GetTime(); self.verifyAt=GetTime()+self.stepInterval; self.nextStep=GetTime()+self.stepInterval;
   T:Message("отвод "..self.main..": шаг "..self.stepDistance.." ярдов от Век’лора; расстояние между боссами "..string.format("%.1f",distance)..". Проверю результат.");
  end);
  local job=T.queue[#T.queue]; job.retreatEpoch=epoch; job.geometry=true;
 end
 -- A verification just supplied the same geometry: do not perform a
 -- second identical round of queries before the next movement command.
 local cached=self.geometry;
 if cached and cached.epoch==epoch and cached.main==self.main and GetTime()-cached.data.tank.at<=3
  and self:Holding() and T:Unit(cached.magical)
  and S:Entry(UnitGUID(T:Unit(cached.magical).."target"))==15276 then move(cached.data);
 else self.geometry=nil; self:Geometry(move); end
end
function R:VerifyDirectedStep()
 local epoch=self.epoch; local before=self.worldBefore; local waypoint=self.waypoint;
 self:Geometry(function(data)
  if self.epoch~=epoch then return; end
  if not before or not waypoint then self:PauseMovement("нет исходных координат шага"); return; end
  local distance=self:Distance(data.physical,data.magical); local old=self:Distance(before.physical,before.magical);
  local dx,dy=waypoint.x-before.tank.x,waypoint.y-before.tank.y;
  local progress=((data.tank.x-before.tank.x)*dx+(data.tank.y-before.tank.y)*dy)/self.stepDistance;
  if progress<1 or distance<old+1 then
   self:PauseMovement("разведение не подтверждено: "..string.format("%.1f -> %.1f ярдов",old,distance).."; повторов движения нет"); return;
  end
  self.busy=false; self.worldBefore=nil; self.waypoint=nil; self.moveAt=nil;
  self.geometry={data=data,epoch=epoch,main=self.main,magical=data.magicalName};
  T:Message("разведение подтверждено: "..string.format("%.1f -> %.1f ярдов",old,distance).."; танк "..self.main);
 end);
end
function R:Step()
 if not self.enabled or not T.armed or self.busy or self.interceptAt or T.pending or #T.queue>0 then return; end
 if self.mobile then self.main=self:PhysicalHolder(); end
 if not self.main or not self:Holding() then T:Message("шаг отменён: выбранный танк должен держать Век’нилаша и атаковать Череп"); return; end
 if GetTime()<(self.nextStep or 0) then return; end
 if self.steps>=self.maxSteps or self.total>=self.maxTotal then self:Stop("достигнут лимит шагов; проверь направление и разведение вручную"); return; end
 if self.mobile then self:DirectedStep(); return; end
 self.busy=true; local epoch=self.epoch;
 T:Job("go ?",self.main,"coords",function(point)
  if not self.enabled or self.epoch~=epoch then return; end
  if not self:Holding() then self:Stop("агро Черепа потеряно до шага"); return; end
  self.before=point;
  T:Job("do flee",self.main,nil,function()
   if not self.enabled or self.epoch~=epoch then return; end
   self.steps=self.steps+1; self.total=self.total+1; self.fleeAt=GetTime(); self.verifyAt=GetTime()+4;
   self.nextStep=GetTime()+8;
   T:Message("шаг назад от Век’нилаша: "..self.main.." — do flee; проверю перемещение один раз");
  end);
  T.queue[#T.queue].retreatEpoch=epoch;
 end);
end
function R:CanSend(job)
 if job.namedApproach then
  local unit=T:Unit(job.name); local slot=self:Slot(job.name);
  local entry=unit and S:Entry(UnitGUID(unit.."target"));
  return self.enabled and self.initialWalk and job.retreatEpoch==self.epoch and unit and slot
   and (not entry or entry==(slot.icon=="skull" and 15275 or 15276));
 end
 if job.localApproach then
  local unit=T:Unit(job.name); local slot=self:Slot(job.name);
  return self.enabled and job.retreatEpoch==self.epoch and unit and slot
   and S:Entry(UnitGUID(unit.."target"))==(slot.icon=="skull" and 15275 or 15276);
 end
 return self.enabled and job.retreatEpoch==self.epoch and self:Holding();
end
function R:Reply(message,sender)
 if self.blocked then
  local name=sender and sender:match("^[^-]+"); local recent=name and T.lastSent[name];
  if recent and GetTime()-recent.at<=6 and self:Rejected(message) then
   T:Log(message,"reply",name);
   if recent.controllerHold and self.holdState and self.holdState[name] then self.holdState[name].failed=true; end
   local job=T.pending;
   if job and job.name==name and (job.controllerHold or job.controllerCheck) then T.pending=nil; if job.done then job.done(nil); end end
   T:Message(name..": отказ при удержании/проверке; пул остаётся заблокирован. Повторов нет"); return true;
  end
 end
 local job=T.pending; local name=sender and sender:match("^[^-]+");
 local lower=(message or ""):lower();
 if job and job.mobilePet and name==job.name and lower:find("you have no pet",1,true) then
  T:Log(message,"reply",name); T.pending=nil; if job.done then job.done(nil); end; return true;
 end
 -- A silent final mutation can complete preparation before its rejection arrives.
 local recent=name and T.lastSent[name];
 if not T.armed and self:IsMobile() and (T.stage=="mobile_prepare" or self:FreeReady()) and recent
  and recent.command:match("^co [+-]") and GetTime()-recent.at<=6
  and (lower:find("unknown",1,true) or lower:find("invalid",1,true) or lower:find("cannot",1,true)
   or lower:find("can't",1,true) or lower:find("failed",1,true) or lower:find("невозможно",1,true)) then
  T:Log(message,"reply",name); T:StopOnly(name..": "..message); T:Message(name..": сервер отказал в изменении co; повторов нет"); return true;
 end
 if self.mobile and self.enabled and name then
  local recent=T.lastSent[name];
  if recent and recent.command=="do avenger's shield" and GetTime()-recent.at<=6
   and (lower:find("unknown",1,true) or lower:find("cannot",1,true) or lower:find("failed",1,true) or lower:find("no items",1,true)) then
   self:Stop("сервер отказал в атаке паладина: "..message.."; повторов заклинания нет"); return true;
  end
 end
 if self.enabled and job and job.geometry and name==job.name
  and (lower:find("unknown",1,true) or lower:find("invalid",1,true) or lower:find("cannot",1,true) or lower:find("failed",1,true)) then
  T:Log(message,"reply",name); self:PauseMovement("сервер отказал: "..message); return true;
 end
 if self.mobile and self.enabled and name==self.main and self.moveAt and GetTime()-self.moveAt<=8
  and (lower:find("unknown",1,true) or lower:find("cannot",1,true) or lower:find("failed",1,true)) then
  T:Log(message,"reply",name); self:PauseMovement("сервер отказал в шаге: "..message); return true;
 end
 if not self.enabled or sender~=self.main or not self.fleeAt or GetTime()-self.fleeAt>8 then return false; end
 if lower:find("flee",1,true) and (lower:find("impossible",1,true) or lower:find("useless",1,true)
  or lower:find("failed",1,true) or lower:find("unknown",1,true) or lower:find("cannot",1,true)) then
  self:Stop("сервер отказал в do flee: "..message); return true;
 end
 return false;
end
function R:Tick()
 if not self.enabled then return; end
 if self.mobile then self:MobileTick(); return; end
 local now=GetTime();
 if self.interceptAt and now>=self.interceptAt and not T.pending and #T.queue==0 then
  self.interceptAt=nil;
  if self.mobile then
   -- Victim/target observations can still describe the previous phase.
   -- They must not reverse the assignment when the twins swap positions.
   if not self.rtiQueued then for _,slot in ipairs(T.slots) do T:Job("rti "..slot.icon,slot.name); end end
   self.rtiQueued=nil;
   self:QueueMobileAttacks();
  else
   T:Job("rti skull",self.main);
   T:Job("attack rti target",self.main,nil,function() T:AttackSent(self.main); self.deadline=GetTime()+14; end);
  end
 end
 if self.deadline and T.bossCombatAt and not self.interceptAt then
  if (self.mobile and self:TargetsReady()) or (not self.mobile and self:Holding()) then self.deadline=nil;
  elseif now>=self.deadline then
   if (self.retries or 0)<1 then self.retries=1; self:Intercept(1,true);
   else self:Stop(self.mobile and "не подтверждён перехват обоих боссов после двух попыток; Век’лор требует отдельной проверки агро" or "основной танк не удержал Череп после двух попыток атаки"); return; end
  end
 end
 if self.verifyAt and now>=self.verifyAt and not T.pending and #T.queue==0 then
  self.verifyAt=nil; local epoch=self.epoch;
  if self.mobile then self:VerifyDirectedStep(); return; end
  if not self:Holding() then self:Stop("агро Черепа потеряно после шага"); return; end
  T:Job("go ?",self.main,"coords",function(point)
   if not self.enabled or self.epoch~=epoch then return; end
   local before=self.before;
   if not before or not self:Holding() then self:Stop("нельзя подтвердить шаг и удержание Черепа"); return; end
   local distance=math.sqrt((point.x-before.x)^2+(point.y-before.y)^2);
   local world=math.abs(point.x)>100 or math.abs(point.y)>100 or point.x<0 or point.y<0;
   if distance<(world and 1 or 0.005) then self:Stop("танк не сдвинулся после do flee; повторов движения нет"); return; end
   self.busy=false; self.before=nil;
   T:Message("перемещение "..self.main.." подтверждено; направление и расстояние между боссами проверь в игре");
  end);
 end
 if self.auto and not self.busy and not self.interceptAt and self.lastHealAt and now-self.lastHealAt<=3
  and now>=(self.nextStep or 0) then
  if self.mobile then self.main=self:PhysicalHolder(); end
  if self.main and self:Holding() and (self.mobile or not self.deadline) then self:Step(); end
 end
end
-- Damage admission belongs only to this explicit mobile encounter.
function R:RosterSignature()
 local keys={}; for _,m in ipairs(S.formation:Roster()) do keys[#keys+1]=m.name..":"..S.formation:RuleKey(m); end
 return table.concat(keys,"|");
end
function R:QueuePet(m,hold,epoch)
 local wanted=hold and "passive" or (m.petStanceOriginal or "passive");
 T:Job("pet "..wanted,m.name); T.queue[#T.queue].damageRelease=not hold;
 if hold then T:Job("pet follow",m.name); end
 T:Job("pet stance",m.name,"pet",function(stance)
  if self.epoch~=epoch then return; end
  if not S.formation:CurrentPet(m.name) then m.pet=nil; m.petGUID=nil; return; end
  if stance~=wanted then T:StopOnly(m.name..": стойка питомца не подтверждена"); end
 end);
 T.queue[#T.queue].mobilePet=true;
 T.queue[#T.queue].damageRelease=not hold;
end
function R:SyncPets()
 for _,m in ipairs(self.dps or {}) do
  local pet,guid=S.formation:CurrentPet(m.name);
  if pet~=m.pet or guid~=m.petGUID then
   m.pet=pet; m.petGUID=guid;
   if pet then
    -- A newly appeared pet has no captured original stance: keep it passive for this attempt.
    m.petStanceOriginal=nil; self:QueuePet(m,true,self.epoch);
    T:Log(m.name..": новый питомец удерживается отдельно; танки продолжают работу","pet_change",m.name);
   else T:Log(m.name..": питомец исчез; танки продолжают работу","pet_change",m.name); end
  end
 end
end
function R:WaitForTargets(reason)
 -- Transient selection/target information is acquisition, not a permanent movement failure.
 self.epoch=self.epoch+1; self.busy=false; self.verifyAt=nil; self.localVerifyAt=nil;
 self.geometry=nil; self.worldBefore=nil; self.waypoint=nil; self.localMove=nil;
 self.stableAt=nil; self.contacts={}; self.separation=nil;
 if T.pending and T.pending.geometry then T.pending=nil; end
 for i=#T.queue,1,-1 do if T.queue[i].geometry then table.remove(T.queue,i); end end
 if GetTime()>=(self.targetMessageAt or 0) then
  self.targetMessageAt=GetTime()+4; T:Message("захват целей: "..reason.."; восстановление ограничено, ДД ждут");
 end
end
function R:AcquireTargets()
 self.targetAttempts=self.targetAttempts or {}; self.targetNext=self.targetNext or {};
 local ready=true; local now=GetTime();
 for _,slot in ipairs(T.slots) do
  local unit=T:Unit(slot.name); local expected=slot.icon=="skull" and 15275 or 15276;
  local actual=unit and S:Entry(UnitGUID(unit.."target"));
  if actual~=expected then
   ready=false;
   if now>=(self.targetNext[slot.name] or 0) then
    local attempts=self.targetAttempts[slot.name] or 0;
    if attempts>=3 then
     self:Stop(slot.name..": цель "..tostring(actual or "отсутствует")..", нужен "..expected.."; 3 попытки захвата не помогли. Выдели нужного близнеца и дай этому танку attack вручную"); return false;
    end
    self.targetAttempts[slot.name]=attempts+1; self.targetNext[slot.name]=now+4;
    local name=slot.name; local epoch=self.epoch;
    T:Job("rti "..slot.icon,name);
    T:Job("attack rti target",name,nil,function()
     if self.epoch==epoch then self.targetNext[name]=GetTime()+4; end
    end);
    T:Message("захват "..name.." -> "..slot.icon..": попытка "..(attempts+1).."/3 "..(T.bossCombatAt and "после пула" or "до пула").."; текущая цель "..tostring(actual or "отсутствует"));
   end
  end
 end
 return ready;
end
function R:SelectedTargetsReady()
 local ready=true; local walkable=true;
 for _,slot in ipairs(T.slots) do
  local unit=T:Unit(slot.name);
  local entry=unit and S:Entry(UnitGUID(unit.."target")); local expected=slot.icon=="skull" and 15275 or 15276;
  if not unit or entry~=expected then ready=false; end
  if not unit or entry and entry~=expected then walkable=false; end
 end
 return ready,walkable;
end
function R:BeginInitialWalk()
 -- RTI lookup can fail before a pull. Named go resolves an NPC independently
 -- of current target. Release only these tanks' movement locks for this route.
 local names={};
 for _,slot in ipairs(T.slots) do
  local entry=slot.icon=="skull" and 15275 or 15276;
  local name=S.bossNames and S.bossNames[entry];
  if not name or name=="" or name=="Unknown" then
   self:Stop("нет проверенного имени босса для "..slot.name.."; выдели обоих близнецов при проверке меток"); return;
  end
  -- GoAction compares the server's base NPC name, not the client's locale.
  names[slot.name]=entry==15275 and "Vek'nilash" or "Vek'lor";
 end
 self.initialWalkUsed=true; local epoch=self.epoch;
 local walk={epoch=epoch,members={},deadline=GetTime()+40}; self.initialWalk=walk;
 for _,slot in ipairs(T.slots) do
  local name=slot.name; local member={name=name}; walk.members[#walk.members+1]=member;
  local record=T:Store()[tostring(slot.side)];
  if not record or record.name~=name then self:Stop("нет исходного снимка "..name.." для начального подхода"); return; end
  local follows=self.freeReady and self.freeReady.tankNC and self.freeReady.tankNC[name] and self.freeReady.tankNC[name].follow;
  if follows then record.managed.nc.follow=true; end
  self:WorldRead(name,"cdebug position",function(point)
   if self.initialWalk~=walk or self.epoch~=epoch then return; end
   member.before=point;
  end);
  T:Job("co -stay",name); local release=T.queue[#T.queue]; release.geometry=true; release.namedApproach=true; release.retreatEpoch=epoch;
  if follows then
   T:Job("nc -follow",name); local follow=T.queue[#T.queue]; follow.geometry=true; follow.namedApproach=true; follow.retreatEpoch=epoch;
  end
  T:Job("go "..names[name],name,nil,function()
   if self.initialWalk~=walk or self.epoch~=epoch then return; end
   member.sentAt=GetTime(); walk.checkAt=GetTime()+12;
   T:Message("начальный подход "..name.." -> "..names[name]..": go по имени, без ожидания цели RTI; ДД ждут");
  end);
  local route=T.queue[#T.queue]; route.geometry=true; route.namedApproach=true; route.retreatEpoch=epoch;
 end
end
function R:InitialWalkTick()
 local walk=self.initialWalk; if not walk then return false; end
 if GetTime()>=walk.deadline then self:Stop("начальный подход по имени не подтверждён за 40 секунд; повторов go нет"); return true; end
 if T.pending or #T.queue>0 or walk.checking or not walk.checkAt or GetTime()<walk.checkAt then return true; end
 walk.checking=true;
 for _,m in ipairs(walk.members) do
  local member=m;
  self:WorldRead(m.name,"cdebug position",function(point)
   if self.initialWalk~=walk or self.epoch~=walk.epoch then return; end
   if not member.before or point.map~=member.before.map or self:Distance(point,member.before)<1 then
    self:Stop(member.name..": go по имени не дал движения; повторов нет. Проверь видимость босса и путь"); return;
   end
   T:Log(member.name..": начальное движение подтверждено","geometry",member.name);
  end);
 end
 -- Hold the new, observed position, never the old preparation point.
 for _,slot in ipairs(T.slots) do T:Job("position stay set",slot.name,"set"); T:Job("co +stay",slot.name); end
 S.formation:AfterQueue(function()
  if self.initialWalk~=walk or self.epoch~=walk.epoch then return; end
  self.initialWalk=nil; self.targetAttempts={}; self.targetNext={};
  T:Message("начальный подход проверен; захватываю метки и измеряю расстояние между боссами");
 end);
 return true;
end
function R:CommandFeedback(message)
 if not self.mobile or not self.enabled or type(message)~="string" then return; end
 local text=message:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","");
 local name=text:match("^([^:]+):"); local recent=name and T.lastSent[name]; local lower=text:lower();
 if recent and GetTime()-recent.at<=6 and (self:Rejected(lower) or lower:find("no items",1,true)) then
  if self.blocked then self:Reply(text,name);
  else self:Stop("сервер отказал: "..text.."; повторов команды нет"); end
 end
end
function R:PrepareDamage(epoch,done)
 local F=S.formation; self.dps={};
 for _,m in ipairs(F:Roster()) do if not F:Healer(m) and not F:IsTank(m) then self.dps[#self.dps+1]=m; end end
 T.expires=GetTime()+math.min(600,math.max(180,#self.dps*18));
 local index=0;
 local function nextMember()
  if self.epoch~=epoch then return; end
  index=index+1; local m=self.dps[index]; if not m then done(); return; end
  if T.log then T.log.names[m.name]=true; end
  F:Read(m,function(actual)
   if self.epoch~=epoch then return; end
   if not F:Remember(m,actual,{co={passive=true},nc={}}) then return; end
   m.originalPassive=T:Store()["formation:"..m.name].co.passive==true;
   m.target=F:DefaultTarget(m);
   local rule=F:Rules()[F:RuleKey(m)]; if rule and (rule.target=="skull" or rule.target=="star") then m.target=rule.target; end
   -- Strategy changes are silent on this server: dispatch once, without a follow-up survey.
   if not actual.co.passive then T:Job("co +passive",m.name,nil,function()
    T:Log(m.name..": co +passive отправлен без ожидания ответа","sent",m.name);
   end); end
   if m.pet then self:QueuePet(m,true,epoch); end
   F:AfterQueue(function() if self.epoch==epoch then nextMember(); end end);
  end);
 end
 nextMember();
end
function R:DamageGate(hold)
 local epoch=self.epoch; self.gateBusy=true; self.stableAt=nil;
 S.queue={}; S.refocusAt=nil; S.casterCheckAt=nil; T.dpsAttackAt=nil; T.startRequested=nil;
 for _,m in ipairs(self.dps or {}) do
  if not m.originalPassive then
   local command=hold and "co +passive" or "co -passive";
   T:Job(command,m.name,nil,function()
    if self.epoch~=epoch then return; end
    T:Log(m.name..": "..command.." отправлен без ожидания ответа","sent",m.name);
   end);
   T.queue[#T.queue].damageRelease=not hold;
  end
  if m.pet then self:QueuePet(m,hold,epoch); end
 end
 S.formation:AfterQueue(function()
  if not self.enabled or self.epoch~=epoch then return; end
  self.gateBusy=false;
  if not hold then
   self.phase="fight";
   self.monitorAt=GetTime()+4;
   for _,m in ipairs(self.dps or {}) do if not m.originalPassive then
    T:Job("rti "..m.target,m.name); T:Job("attack rti target",m.name);
    T.queue[#T.queue].damageRelease=true;
   end end
   T:Message("агро и разведение подтверждены: ДД подключены; танки удерживают свои стороны");
  end
 end);
end
function R:GateSafe()
 return self.enabled and not self.blocked and self:TargetsReady() and self.separation and self.separation>=80
  and GetTime()-(self.lastHealAt or -1000)>=3;
end
function R:Slot(name)
 for _,slot in ipairs(T.slots) do if slot.name==name then return slot; end end
end
function R:InsideSide(name,point)
 local a=self.arena; if not a or not a.sides[name] then return false; end
 return ((point.x-a.x)*a.dx+(point.y-a.y)*a.dy)*a.sides[name]>=-2;
end
function R:ReadLocal(slot,done)
 local epoch=self.epoch; local entry=slot.icon=="skull" and 15275 or 15276;
 local other=T.slots[slot==T.slots[1] and 2 or 1]; local data={}; self.busy=true;
 local function valid()
  if not self.enabled or self.epoch~=epoch then return false; end
  local unit,ou=T:Unit(slot.name),T:Unit(other.name);
  if not unit or not ou or S:Entry(UnitGUID(unit.."target"))~=entry
   or S:Entry(UnitGUID(ou.."target"))~=(entry==15275 and 15276 or 15275) then
   self:WaitForTargets("цели танков пока не соответствуют назначенным близнецам"); return false;
  end
  return true;
 end
 if not valid() then return; end
 self:WorldRead(slot.name,"cdebug position",function(tank)
  if not valid() then return; end; data.tank=tank;
  self:WorldRead(slot.name,"cdebug tpos",function(boss)
   if not valid() then return; end; data.boss=boss;
   self:WorldRead(other.name,"cdebug tpos",function(opposite)
    if not valid() then return; end; data.other=opposite;
    if tank.map~=boss.map or tank.map~=opposite.map or GetTime()-tank.at>5 then
     self:PauseMovement("координаты разных карт или устарели; ДД ждут"); return;
    end
    data.physical=entry==15275 and boss or opposite; data.magical=entry==15276 and boss or opposite;
    data.magicalName=entry==15276 and slot.name or other.name;
    if not self.arena then
     local distance=self:Distance(data.physical,data.magical);
     if distance<4 then self:PauseMovement("боссы почти совпадают: направление сторон неизвестно; разведи вручную"); return; end
     self.arena={x=(boss.x+opposite.x)/2,y=(boss.y+opposite.y)/2,
      dx=(data.physical.x-data.magical.x)/distance,dy=(data.physical.y-data.magical.y)/distance,sides={}};
     for _,s in ipairs(T.slots) do self.arena.sides[s.name]=s.icon=="skull" and 1 or -1; end
     T:Log("стороны заданы по текущим боссам; старые точки не используются","geometry");
    end
    if not self:InsideSide(slot.name,boss) then self:PauseMovement("назначенный босс на другой стороне комнаты; преследование запрещено"); return; end
    self.busy=false; done(data);
   end);
  end);
 end);
end
function R:Threat(slot)
 if T:Holding(slot.icon=="skull" and 15275 or 15276,slot.name) then return; end
 if self.threatSent[slot.name] then return; end
 self.threatSent[slot.name]=true;
 local profile=UnBotBotRegistry.bots[slot.name];
 if profile and profile.className=="paladin" then T:Job("do avenger's shield",slot.name); end
 T:Job("attack rti target",slot.name);
end
function R:Approach(slot,data)
 local distance=self:Distance(data.tank,data.boss); local range=slot.icon=="skull" and 4 or 8;
 -- A stacked pull needs an initial route into each boss's half. Once a
 -- tank enters its assigned half, never allow it to cross back; teleport
 -- cancels this permission for both tanks. No saved anchors are involved.
 local initial=self.initialApproach and self.initialApproach[slot.name];
 if initial and self:InsideSide(slot.name,data.tank) then self.initialApproach[slot.name]=false; end
 local entering=self.initialApproach and self.initialApproach[slot.name];
 if distance<=range+1 then self.contacts[slot.name]=true; self:Threat(slot); return; end
 local limit=self.initialApproach and 6 or 3;
 if (self.approaches[slot.name] or 0)>=limit then self:Stop("танк "..slot.name.." не подошёл после "..limit.." шагов; ДД остаются пассивными"); return; end
 local length=math.min(20,distance-range);
 local waypoint={x=data.tank.x+(data.boss.x-data.tank.x)*length/distance,
  y=data.tank.y+(data.boss.y-data.tank.y)*length/distance};
 if not entering and (not self:InsideSide(slot.name,data.tank) or not self:InsideSide(slot.name,waypoint)) then
  self:PauseMovement("танк "..slot.name.." должен начинать возле своего близнеца; переход через центр запрещён"); return;
 end
 local epoch=self.epoch; self.busy=true;
 self.localMove={slot=slot,before=data,waypoint=waypoint};
 T:Job("position stay "..math.floor(waypoint.x+0.5)..","..math.floor(waypoint.y+0.5)..","..math.floor(data.tank.z+0.5),slot.name,"set");
 local hold=T.queue[#T.queue]; hold.geometry=true; hold.localApproach=true; hold.retreatEpoch=epoch;
 hold.onTimeout=function() self:PauseMovement("позиция локального подхода не подтверждена; go отменён"); end;
 T:Job(string.format("go %.2f;%.2f",waypoint.x,waypoint.y),slot.name,nil,function()
  if self.epoch~=epoch then return; end
  self.approaches[slot.name]=(self.approaches[slot.name] or 0)+1; self.localVerifyAt=GetTime()+3;
  T:Message("локальный подход "..slot.name.." к "..slot.icon..": "..string.format("%.1f",length).." ярдов; ДД ждут");
 end);
 local move=T.queue[#T.queue]; move.geometry=true; move.localApproach=true; move.retreatEpoch=epoch;
end
function R:MobileTick()
 if self.blocked or self.checkRunning or self.checkRequested then return; end
 local now=GetTime();
 if self.freeReady and self.freeReady.signature~=self:RosterSignature() then T:StopOnly("боевой состав изменился; повтори подготовку вне боя"); return; end
 if self.interceptAt and now>=self.interceptAt and not T.pending and #T.queue==0 then
  self.interceptAt=nil;
  for _,slot in ipairs(T.slots) do T:Job("rti "..slot.icon,slot.name); end
  self:QueueMobileAttacks(); return;
 end
 -- stay blocks autonomous reach. Geometry and explicit go must run before
 -- the first hit; waiting for bossCombatAt here would deadlock a distant pull.
 if T.bossCombatAt and not self.combatRetargeted then
  self.combatRetargeted=true; self.targetAttempts={}; self.targetNext={}; self.phaseUntil=now+90;
 end
 self.phaseUntil=self.phaseUntil or now+(T.bossCombatAt and 90 or 120);
 if self.phase~="fight" and now>=self.phaseUntil then
  self:Stop(T.bossCombatAt and "агро и 80 ярдов не подтверждены за 90 секунд; ДД остаются пассивными"
   or "начальный подход не запустил бой за 120 секунд; ДД остаются пассивными"); return;
 end
 if self.phase=="fight" and (not self:TargetsReady() or self.lastHealAt and now-self.lastHealAt<3) then
  self.epoch=self.epoch+1; T.queue={}; T.pending=nil;
  self.phase="acquire"; self.phaseUntil=now+90; self.approaches={}; self.threatSent={}; self.contacts={}; self.separation=nil;
  self.targetAttempts={}; self.targetNext={};
  self.geometry=nil; self.localMove=nil; self.localVerifyAt=nil; self.busy=false; self.verifyAt=nil;
  self:DamageGate(true); T:Message("агро потеряно или близнецы лечатся: ДД снова ждут захвата и разведения"); return;
 end
 if self:InitialWalkTick() then return; end
 if T.pending or #T.queue>0 or self.gateBusy or self.interceptAt or self.movementFailed then return; end
 self:SyncPets(); if #T.queue>0 then return; end
 local selected,walkable=self:SelectedTargetsReady();
 if self.initialApproach and not self.initialWalkUsed and not self.arena and not selected and walkable then
  self:BeginInitialWalk(); return;
 end
 if not self:AcquireTargets() then return; end
 if self.localVerifyAt and now>=self.localVerifyAt then
  local move=self.localMove; self.localVerifyAt=nil;
  if not move then self:PauseMovement("нет исходной геометрии подхода"); return; end
  self:ReadLocal(move.slot,function(data)
   if self:Distance(data.tank,move.before.tank)<1 or self:Distance(data.tank,data.boss)>self:Distance(move.before.tank,move.before.boss)-1 then
    self:PauseMovement("танк не приблизился к своему боссу; повторов go нет"); return;
   end
   self.localMove=nil;
   if self:Distance(data.tank,data.boss)<=(move.slot.icon=="skull" and 5 or 9) then self.contacts[move.slot.name]=true; self:Threat(move.slot); end
  end); return;
 end
 if self.localMove then return; end
 if self.verifyAt and now>=self.verifyAt then self.verifyAt=nil; self:VerifyDirectedStep(); return; end
 if self.busy then return; end
 if self.phase=="fight" then
  if now>=(self.monitorAt or 0) then
   self.monitorAt=now+5;
   local slot=self:Slot(self:PhysicalHolder());
   if slot then self:ReadLocal(slot,function(data)
    self.separation=self:Distance(data.physical,data.magical);
    T:Log("контроль разведения: "..string.format("%.1f",self.separation).." ярдов","geometry");
    if self.separation<75 then
     self.phase="acquire"; self.phaseUntil=GetTime()+90; self.contacts={}; self.approaches={}; self.threatSent={};
     self.targetAttempts={}; self.targetNext={}; self:DamageGate(true);
     T:Message("близнецы сблизились: "..string.format("%.1f",self.separation).." ярдов; ДД ждут, восстанавливаю 80 ярдов");
    end
   end); end
  end
  return;
 end
 if not self.contacts[T.slots[1].name] or not self.contacts[T.slots[2].name] or not self:TargetsReady() then
  self.stableAt=nil;
  self.inspectSide=(self.inspectSide or 0)%2+1; local slot=T.slots[self.inspectSide];
  self:ReadLocal(slot,function(data) self:Approach(slot,data); end); return;
 end
 if not T.bossCombatAt then return; end
 self.initialApproach=nil;
 self.stableAt=self.stableAt or now; if now-self.stableAt<2 then return; end
 local slot=self:Slot(self:PhysicalHolder()); if not slot then return; end
 self:ReadLocal(slot,function(data)
  if not self:TargetsReady() then self.stableAt=nil; return; end
  self.separation=self:Distance(data.physical,data.magical);
  if self:GateSafe() then self:DamageGate(false); return; end
  if self.separation<80 and self.auto then
   self.main=slot.name; self.geometry={data=data,epoch=self.epoch,main=self.main,magical=data.magicalName};
   self:Step();
  end
 end);
end

-- A command failure closes admission but retains this encounter's controller.
-- Hold uses CURRENT positions, never old anchors or original strategy values.
function R:Rejected(message)
 local lower=tostring(message or ""):lower();
 for _,word in ipairs({"unknown","invalid","cannot","can't","failed","too far","not set","not found","невозможно","неизвест","не могу","whisper 'go","whisper position"}) do
  if lower:find(word,1,true) then return true; end
 end
 return false;
end
function R:HoldJob(command,name,wait,done)
 T:Job(command,name,wait,done); local job=T.queue[#T.queue]; job.controllerHold=true;
 job.onTimeout=function()
  if self.holdState and self.holdState[name] then self.holdState[name].failed=true; end
  T:Message(name..": удержание не подтверждено на «"..command.."»; пул заблокирован, повторов нет");
  if job.done then job.done(nil); end
 end;
end
function R:Block(reason)
 if self.blocked then return; end
 self.blocked=reason or "команда не выполнена"; self.phase="blocked"; self.epoch=self.epoch+1;
 self.auto=false; self.busy=false; self.gateBusy=false; self.interceptAt=nil;
 self.initialWalk=nil; self.geometry=nil; self.localMove=nil; self.localVerifyAt=nil; self.verifyAt=nil;
 self.separation=nil; self.phaseUntil=nil; self.targetCheck=nil; self.holdState={}; self.checkRunning=nil; self.checkRequested=nil;
 T.pending=nil; T.queue={}; T.pullWaitUntil=nil; T.cycleAt=nil; T.cycleDeadline=nil; T.positionCheckAt=nil;
 T.dpsAttackAt=nil; T.startRequested=nil; S.queue={}; S.refocusAt=nil; S.casterCheckAt=nil; S.endCheckAt=nil;
 for _,slot in ipairs(T.slots) do
  local name=slot.name; self.holdState[name]={};
  local record=T:Store()[tostring(slot.side)];
  if record and record.name==name then
   record.managed.co.passive=true; record.managed.co.stay=true;
   record.managed.nc.stay=true; record.managed.nc.follow=true;
  end
  -- StayAction rejects a stored stay point as useless; clear only this point.
  self:HoldJob("position stay reset",name);
  self:HoldJob("do stay",name);
 end
 for _,slot in ipairs(T.slots) do
  local name=slot.name; local state=self.holdState[name];
  self:HoldJob("position stay set",name,"set",function(value) state.position=value==true; end);
  self:HoldJob("co +stay,+passive",name);
  self:HoldJob("nc +stay,-follow",name);
 end
 self:DamageGate(true);
 for _,job in ipairs(T.queue) do
  job.controllerHold=true;
  if not job.onTimeout then job.onTimeout=function() if job.done then job.done(nil); end end; end
 end
 S.formation:AfterQueue(function()
  if self.blocked then T:Message("УДЕРЖАНИЕ: пул заблокирован — "..self.blocked..". Проверь цели обоих танков; управление остаётся включено"); end
 end);
 T:Message("отказ: "..self.blocked..". Останавливаю маршруты обоих танков, ДД пассивны; пул заблокирован");
 if T.frame then T.frame:Show(); end
end
function R:RetryHold()
 if not self.blocked or T.pending or #T.queue>0 then return false; end
 local reason=self.blocked; self.blocked=nil; self:Block(reason); return true;
end
function R:TargetNameEntry(text)
 local lower=tostring(text or ""):lower();
 for _,entry in ipairs({15275,15276}) do
  if S.bossNames and S.bossNames[entry]==text then return entry; end
  local name=entry==15275 and "vek'nilash" or "vek'lor";
  if lower:find(name,1,true) then return entry; end
 end
end
function R:CanCheckTargets()
 if not self:IsMobile() or not T:InRoom() or T.stage or T.restoring or T:Busy() or self.checkRunning or self.checkRequested then return false; end
 for side=1,2 do if not T.slots[side] or not T:Unit(T.slots[side].name) then return false; end end
 return true;
end
function R:DiagnosticTick(now)
 local request=self.checkRequested; if not request then return; end
 if now>=request.expires then
  self.checkRequested=nil; T:Message("проверка целей не дождалась очереди за 40 секунд; повторов нет"); return;
 end
 if T.pending or #T.queue>0 then return; end
 self.checkRequested=nil;
 if not self:CanCheckTargets() then T:Message("проверка целей отменена: изменилась подготовка или участники"); return; end
 self:CheckTargets(false);
end
function R:CheckTargets(resume)
 if not self:CanCheckTargets() then T:Message("проверка недоступна: выбери двух живых танков в подвижном режиме и дождись подготовки"); return false; end
 if T.pending or #T.queue>0 then
  if resume then T:Message("дождись завершения удержания"); return false; end
  self.checkRequested={expires=GetTime()+40};
  T:Message("проверка целей поставлена после текущей очереди; дополнительных атак для проверки нет"); return true;
 end
 if resume and not self.blocked then return false; end
 if resume and not self:FreeReady() then T:Message("состав или выбранный пресет изменился: продолжение заблокировано; нужна новая подготовка"); return false; end
 local check={epoch=self.epoch,resume=resume,members={}}; self.targetCheck=check; self.checkRunning=true;
 for _,slot in ipairs(T.slots) do
  local name=slot.name; local icon=slot.icon or (slot.side==1 and "skull" or "star");
  local m={name=name,icon=icon,expected=icon=="skull" and 15275 or 15276}; check.members[#check.members+1]=m;
  local function read(command,wait,done)
   T:Job(command,name,wait,done); local job=T.queue[#T.queue]; job.controllerCheck=true;
   job.onTimeout=function() if job.done then job.done(nil); end end;
  end
  read("rti ?","rti",function(value) m.rti=value; end);
  read("cdebug target","targetName",function(value) m.ai=value; end);
  if self.blocked then
   read("co ?","co",function(value) m.co=value; end);
   read("nc ?","nc",function(value) m.nc=value; end);
   read("cdebug position","world",function(value)
    m.before=value; m.sampleAt=GetTime()+3;
    for _,queued in ipairs(T.queue) do if queued.holdSample==m then queued.readyAt=m.sampleAt; end end
   end);
   read("cdebug position","world",function(value)
    m.still=value and m.before and value.map==m.before.map and value.at-m.before.at>=3 and self:Distance(value,m.before)<1;
   end);
   T.queue[#T.queue].holdSample=m;
  end
 end
 S.formation:AfterQueue(function()
  if self.targetCheck~=check or self.epoch~=check.epoch then return; end
  self.checkRunning=nil;
  local ready=true;
  for _,m in ipairs(check.members) do
   local unit=T:Unit(m.name); local entry=unit and S:Entry(UnitGUID(unit.."target"));
   local hold=self.holdState and self.holdState[m.name];
   local held=not self.blocked or hold and hold.position and not hold.failed and m.still and m.co and m.co.stay and m.co.passive and m.nc and m.nc.stay and not m.nc.follow;
   local ok=entry==m.expected and self:TargetNameEntry(m.ai)==m.expected and m.rti==m.icon and held;
   ready=ready and ok;
   T:Message(m.name..": rti="..tostring(m.rti or "нет ответа").."; цель NPC="..tostring(entry or "нет").." (нужен "..m.expected.."); AI="..tostring(m.ai or "нет боевой цели/ответа").."; "..(ok and "ГОТОВ" or "НЕ ГОТОВ")..(self.blocked and (held and "; удержание подтверждено" or "; остановка/удержание не подтверждены") or ""));
  end
  if not check.resume then return; end
  if not ready then T:Message("пул заблокирован: оба танка ещё не готовы; удержание и контроллер остаются включены"); return; end
  self:ResumeHeld(check);
 end);
 T:Message("проверяю метки и действительные цели обоих танков; атаки и движение при удержании заблокированы"); return true;
end
function R:ResumeHeld(check)
 if not self.blocked or self.targetCheck~=check or self.epoch~=check.epoch or not self:SelectedTargetsReady() then return; end
 -- Retain admission lock until both silent strategy mutations have drained.
 for _,slot in ipairs(T.slots) do self:HoldJob("co -passive",slot.name); end
 for _,slot in ipairs(T.slots) do
  local name=slot.name;
  self:HoldJob("co ?",name,"co",function(value)
   if not value or value.passive or not value.stay then self.holdState[name].failed=true; end
  end);
 end
 S.formation:AfterQueue(function()
  if self.targetCheck~=check or self.epoch~=check.epoch then return; end
  for _,slot in ipairs(T.slots) do
   if self.holdState[slot.name].failed then self.blocked=nil; self:Block("сервер отказал при продолжении; оба танка снова удерживаются"); return; end
  end
  if not self:SelectedTargetsReady() then
   -- Selection changed during release; re-hold once through the same bounded path.
   self.blocked=nil; self:Block("цель изменилась при продолжении"); return;
  end
  self.blocked=nil; self.targetCheck=nil; self.auto=true; self.phase="acquire"; self.phaseUntil=GetTime()+90;
  self.contacts={}; self.approaches={}; self.threatSent={}; self.targetAttempts={}; self.targetNext={}; self.movementFailed=nil;
  T.expires=GetTime()+900; S.fightExpiresAt=T.expires; S.endCheckAt=nil;
  T:Message("оба танка ГОТОВЫ: продолжаю захват и разведение; ДД ждут агро и 80 ярдов");
 end);
end

function R:Refresh(frame)
 if not frame or frame.retreatAttached~=true then return; end
 frame.retreatHint:SetText(self:IsMobile() and "Танки сами подходят до пула; ДД ждут агро и 80 ярдов." or "Выбери режим боя; ручной шаг доступен только при агро Век’нилаша.");
 if self:Mode()=="retreat_manual" then frame.retreatStep:Show(); frame.formationSettings:Hide();
 else frame.retreatStep:Hide(); frame.formationSettings:Show(); end
 if self:IsMobile() then
  frame.restore:SetText("Подготовить танков и ДД (без точек)");
  frame.savedPoints:SetText("Танки могут начать рядом: каждый подходит к своему боссу без старых точек.\nДД ждут агро и 80 ярдов. После занятия сторон танки не переходят через центр.");
  frame.steps[1]:SetText("1. Танки и пассивность ДД — "..(self:FreeReady() and "ГОТОВО" or "нажми подготовку без точек"));
  for side=1,2 do frame.labels[side]:SetText("Танк "..side..": "..(T.slots[side] and T.slots[side].name or "не выбран")); frame.place[side]:Disable(); end
  if not S:GroupInCombat() and not T.armed and not T.stage and not T.pending and #T.queue==0 and not T.restoring and not T:Busy() then frame.restore:Enable(); else frame.restore:Disable(); end
  if self:FreeReady() and not S:GroupInCombat() and not T.armed and not T.stage and not T.pending then frame.checkMarks:Enable(); else frame.checkMarks:Disable(); end
 else for side=1,2 do frame.place[side]:Enable(); end end
 frame.start:SetText(self.blocked and "Проверить и продолжить" or "Начать бой");
 if self.blocked then
  frame.steps[3]:SetText("3. ПУЛ ЗАБЛОКИРОВАН — удержание включено; проверь обе цели");
  if not T.pending and #T.queue==0 then frame.start:Enable(); else frame.start:Disable(); end
 end
 if self:IsMobile() then frame.targetCheck:Show(); else frame.targetCheck:Hide(); end
 frame.targetCheck:SetSize(self.blocked and 240 or 498,24);
 if self.blocked then frame.retryHold:Show(); else frame.retryHold:Hide(); end
 if self.blocked and not T.pending and #T.queue==0 then frame.retryHold:Enable(); else frame.retryHold:Disable(); end
 if self:CanCheckTargets() then frame.targetCheck:Enable(); else frame.targetCheck:Disable(); end
 frame.retreatMode:SetText("Режим: "..self:Label());
 if self:CanChange() then frame.retreatMode:Enable(); else frame.retreatMode:Disable(); end
 if self.enabled and not self.auto and not self.busy and not self.interceptAt and not T.pending and #T.queue==0
  and GetTime()>=(self.nextStep or 0) and self:Holding() then frame.retreatStep:Enable(); else frame.retreatStep:Disable(); end
end
function R:Attach(frame)
 if frame.retreatAttached==true then self:Refresh(frame); return; end
 frame.retreatAttached=true;
 frame.retreatMode=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate");
 frame.retreatMode:SetSize(498,24); frame.retreatMode:SetPoint("TOPLEFT",18,-70);
 frame.retreatMode:SetScript("OnClick",function()
  local mode=R:Mode(); R:SetMode(mode=="anchors" and "mobile_auto" or mode=="mobile_auto" and "retreat_manual" or mode=="retreat_manual" and "retreat_auto" or "anchors");
 end);
 frame.retreatStep=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate");
 frame.retreatStep:SetSize(498,26); frame.retreatStep:SetPoint("TOPLEFT",18,-535);
 frame.retreatStep:SetText("Один шаг назад от Черепа: do flee"); frame.retreatStep:SetScript("OnClick",function() R:Step(); end);
 frame.targetCheck=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate");
 frame.targetCheck:SetSize(498,24); frame.targetCheck:SetPoint("TOPLEFT",18,-460);
 frame.targetCheck:SetText("Проверить цели (без атаки)");
 frame.targetCheck:SetScript("OnClick",function() R:CheckTargets(false); end);
 frame.retryHold=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate");
 frame.retryHold:SetSize(251,24); frame.retryHold:SetPoint("TOPLEFT",265,-460);
 frame.retryHold:SetText("Повторить удержание");
 frame.retryHold:SetScript("OnClick",function() R:RetryHold(); end);
 frame.retreatHint=frame.modeHint; frame.retreatHint:SetHeight(20);
 self:Refresh(frame);
end
end

-- Universal manual group action. No boss, preset, map or registry admission gate.
do
UnBotGroupControl={petWork={}};
local C=UnBotGroupControl;
function C:Message(text)
 if UnBotSpecSummonMessage then UnBotSpecSummonMessage(text); else DEFAULT_CHAT_FRAME:AddMessage("UnBot: "..text); end
end
function C:Channel() return (GetNumRaidMembers() or 0)>0 and "RAID" or "PARTY"; end
function C:Members()
 local result={}; local raid=(GetNumRaidMembers() or 0)>0;
 for i=1,(raid and math.min(40,GetNumRaidMembers()) or (GetNumPartyMembers() or 0)) do
  local unit=(raid and "raid" or "party")..i; local name=UnitName(unit);
  if name and name~="" and name~=UNKNOWN and name~=UNKNOWNOBJECT and name~=UnitName("player") and UnitIsConnected(unit) then result[name]=true; end
 end
 return result;
end
function C:Clear()
 self.wiping=false; self.serverWipe=nil; self.petWork={}; self.wipeReadAt=nil; self.wipeUntil=nil; self.readSection=nil; self.members=nil; self.wipeAnswers={}; self.externalResetAt=nil; self.externalResetAnswers={};
 UnBotSquadConfig=UnBotSquadConfig or {}; UnBotSquadConfig.forcedWipe=nil;
 local twins=UnBotTwinEmperors and UnBotTwinEmperors.groupControl; if twins then twins.wiping=false; twins.petWork=self.petWork; end
end
function C:CancelControl()
 if UnBotViscidus then UnBotViscidus.enabled=false; UnBotViscidus.queue={}; end
 local twins=UnBotTwinEmperors and UnBotTwinEmperors.groupControl; if twins and twins.CancelControl then twins:CancelControl(); end
 if UnBotBuffCycleStopByUser and UnBotMythicPlusBuffCycleActive and UnBotMythicPlusBuffCycleActive() then UnBotBuffCycleStopByUser(); end
 if UnBotAltStrategies then UnBotAltStrategies.active=false; UnBotAltStrategies.queue={}; end
end
function C:Rejected(message)
 local lower=tostring(message or ""):lower();
 for _,word in ipairs({"unknown","invalid","cannot","can't","failed","too far","not set","not found","невозможно","неизвест","не могу","whisper 'go","whisper position"}) do
  if lower:find(word,1,true) then return true; end
 end
 return false;
end
function C:PetFinish(name,confirmed)
 SendChatMessage("co +passive,+stay,-follow", "WHISPER",nil,name);
 SendChatMessage("nc +passive,+stay,-follow", "WHISPER",nil,name);
 self.petWork[name]=nil;
 if not confirmed then self:Message(name..": остановка питомца не подтверждена. Владелец оставлен в полном passive; повторов нет"); end
end
function C:PetReply(text,name)
 local p=self.petWork and self.petWork[name]; if not p then return; end
 local lower=text:lower();
 if self:Rejected(text) then self:PetFinish(name,false); return; end
 local list=lower:match("^strategies:%s*(.*)$");
 if (p.stage=="co" or p.stage=="nc") and list then
  p[p.stage]={}; for key in list:gmatch("[^,]+") do p[p.stage][key:match("^%s*(.-)%s*$")]=true; end
  if p.stage=="co" then p.stage="nc"; p.sendAt=GetTime()+2.1; p.sendCommand="nc ?";
  else
   -- Pet commands are suppressed by passive too. Remove all other AI strategies
   -- for this pet owner before opening just chat/stay, never healing or attacks.
   for _,section in ipairs({"co","nc"}) do
    local tokens={"+chat","+stay"}; for key in pairs(p[section]) do if key~="chat" and key~="stay" then tokens[#tokens+1]="-"..key; end end
    SendChatMessage(section.." "..table.concat(tokens,","),"WHISPER",nil,name);
   end
   p.stage="verify_co"; SendChatMessage("co ?","WHISPER",nil,name);
  end
 elseif (p.stage=="verify_co" or p.stage=="verify_nc") and list then
  for key in list:gmatch("[^,]+") do key=key:match("^%s*(.-)%s*$"); if key~="chat" and key~="stay" then self:PetFinish(name,false); return; end end
  if p.stage=="verify_co" then p.stage="verify_nc"; p.sendAt=GetTime()+2.1; p.sendCommand="nc ?";
  else p.stage="passive"; SendChatMessage("pet passive","WHISPER",nil,name); end
 elseif p.stage=="passive" and lower:find("passive",1,true) and not list then
  p.stage="stay"; SendChatMessage("pet stay","WHISPER",nil,name);
 elseif p.stage=="stay" and (lower:find("pet commanded to stay",1,true) or lower:find("pet stay",1,true)) then self:PetFinish(name,true); end
end
function C:Wipe()
 local members=self:Members();
 self:CancelControl(); self:Clear(); self.wiping=true; self.members=members;
 local twins=UnBotTwinEmperors and UnBotTwinEmperors.groupControl; if twins then twins.wiping=true; twins.petWork=self.petWork; twins.reset=nil; twins.victory=nil; end
 UnBotSquadConfig.forcedWipe=true;
 for _,controller in ipairs({UnBotLichKing or {},UnBotSvalnaControl or {},UnBotValithriaHeal or {},
  UnBotPutricideDrink or {},UnBotSindragosaPrep or {},UnBotDeathwhisperControl or {},UnBotSaurfangBeastFocus or {},UnBotMarrowgarRescue or {}}) do
  controller.active=false; controller.armed=false; controller.prepared=false; controller.maintenance=false;
  controller.encounterActive=false; controller.focusEnabled=false; controller.jobs={}; controller.queue={};
  controller.valk=nil; controller.spheres=nil; controller.spirits=nil; controller.rogues=nil;
 end
 if UnBotSquadSummon and UnBotSquadSummon.active and UnBotSquadSummon.Stop then UnBotSquadSummon.Stop("принудительный вайп"); end
 -- One server command per manual click; no AI strategy mutations or retries.
 self.serverWipe=true; self.wipeUntil=GetTime()+32; self.wipeAnswers={};
 self.wipeReadAt=nil; self.readSection=nil; self.petWork={};
 if twins then twins.petWork=self.petWork; end
 SendChatMessage("wipe",self:Channel());
 self:Message("ПРИНУДИТЕЛЬНЫЙ ВАЙП: одна команда wipe отправлена в "..(self:Channel()=="RAID" and "рейд" or "группу")..". Ожидаю смерти ботов; повторов нет. Игрок и живые участники останавливаются сами. Стратегии не менялись.");
end
function C:Event(event,...)
 if event=="PLAYER_LOGIN" then
  self.wiping=UnBotSquadConfig and UnBotSquadConfig.forcedWipe or false;
  local twins=UnBotTwinEmperors and UnBotTwinEmperors.groupControl; if twins then twins.wiping=self.wiping; end
 elseif event=="CHAT_MSG_WHISPER" and self.wiping then
  local text,sender=...; if type(text)~="string" then return; end
  local name=sender and sender:match("^[^-]+"); local members=self:Members();
  if not members[name] then return; end
  local lower=text:lower();
  if lower:find("ai was reset to defaults",1,true) then
   if not self.externalResetAt or GetTime()-self.externalResetAt>12 then self.externalResetAt=GetTime(); self.externalResetAnswers={}; end
   self.externalResetAnswers[name]=true;
   local twins=UnBotTwinEmperors and UnBotTwinEmperors.groupControl; if twins and twins.Archive then twins:Archive(name); end
   local complete=true; for member in pairs(members) do if not self.externalResetAnswers[member] then complete=false; end end
   if complete then self:Clear(); self:Message("reset botAI подтверждён всей группой: режим принудительного вайпа снят"); end
   return;
  end
  if self.wipeUntil and self.members and self.members[name] and not next(self.petWork) and self.readSection and lower:find("strategies:",1,true) then
   self.wipeAnswers[name]=self.wipeAnswers[name] or {}; self.wipeAnswers[name][self.readSection=="co_wait" and "co" or self.readSection]=lower;
  end
  self:PetReply(text,name);
 end
end
function C:Tick()
 if not self.wiping then return; end
 local now=GetTime();
 if self.serverWipe then
  if not self.wipeUntil then return; end
  local dead,total,missing=0,0,0; local units={};
  local raid=(GetNumRaidMembers() or 0)>0;
  for i=1,(raid and math.min(40,GetNumRaidMembers()) or (GetNumPartyMembers() or 0)) do
   local unit=(raid and "raid" or "party")..i; local name=UnitName(unit);
   if name then units[name]=unit; end
  end
  for name in pairs(self.members or {}) do
   total=total+1; local unit=units[name];
   if unit and UnitIsConnected(unit) then if UnitIsDeadOrGhost(unit) then dead=dead+1; end
   else missing=missing+1; end
  end
  if (total>0 and dead==total) or now>=self.wipeUntil then
   self.wipeUntil=nil;
   self:Message("вайп: смерть подтверждена у "..dead.."/"..total.." онлайн-участников исходного состава; недоступно для проверки: "..missing..". "..(dead==total and total>0 and "Команда wipe не повторялась." or "У остальных смерть не подтверждена. Повтор только новым нажатием; живые игроки командой wipe не убиваются.").." После воскрешения запуск тактики выполняйте вручную; флаг вайпа снимается прежним reset botAI.");
  end
  return;
 end
 for name,p in pairs(self.petWork) do
  if not self:Members()[name] then self.petWork[name]=nil;
  elseif now>=p.untilAt then self:PetFinish(name,false);
  elseif p.sendAt and now>=p.sendAt then local command=p.sendCommand; p.sendAt=nil; p.sendCommand=nil; SendChatMessage(command,"WHISPER",nil,name); end
 end
 if self.wipeReadAt and now>=self.wipeReadAt and not next(self.petWork) then
  if self.readSection=="co_wait" then self.readSection="nc"; end
  SendChatMessage(self.readSection.." ?",self:Channel());
  if self.readSection=="co" then self.wipeReadAt=now+2.1; self.readSection="co_wait"; else self.wipeReadAt=nil; end
 end
 if self.wipeUntil and now>=self.wipeUntil then
  self.wipeUntil=nil; self.wipeReadAt=nil; self.readSection=nil; local done,total=0,0;
  for name in pairs(self.members or {}) do
   total=total+1; local a=self.wipeAnswers[name] or {};
   if a.co and a.nc and a.co:find("passive",1,true) and a.co:find("stay",1,true) and a.nc:find("passive",1,true) and a.nc:find("stay",1,true) then done=done+1; end
  end
  self:Message("вайп: passive/stay подтверждены в co и nc у "..done.."/"..total.." участников. Пассивность сохраняется; после воскрешения вручную отправь reset botAI.");
 end
end
C.frame=CreateFrame("Frame"); C.frame:RegisterEvent("PLAYER_LOGIN"); C.frame:RegisterEvent("CHAT_MSG_WHISPER");
C.frame:SetScript("OnEvent",function(_,event,...) C:Event(event,...); end);
C.frame:SetScript("OnUpdate",function() C:Tick(); end);
end

-- Twin victory/reset integration and the one-bot variant.
do
local S=UnBotTwinEmperors;
local T=S.tanks;
local F=S.formation;
local G={}; S.groupControl=G;
local P={queue={},nextSend=0}; S.playerTank=P;

function G:Channel() return (GetNumRaidMembers() or 0)>0 and "RAID" or "PARTY"; end
function G:Members() return UnBotGroupControl:Members(); end
function G:CancelControl()
 P:Stop(); T:StopOnly();
 if UnBotViscidus then UnBotViscidus.enabled=false; UnBotViscidus.queue={}; end
 -- Cancel pending buff/summon work without calling a strategy-restoring disarm.
 if UnBotBuffCycleStopByUser and UnBotMythicPlusBuffCycleActive and UnBotMythicPlusBuffCycleActive() then UnBotBuffCycleStopByUser(); end
 if UnBotAltStrategies then UnBotAltStrategies.active=false; UnBotAltStrategies.queue={}; end
end
function G:Wipe() return UnBotGroupControl:Wipe(); end
function G:Archive(name)
 local store=T:Store(); local archived={};
 for key,r in pairs(store) do
  if (key=="1" or key=="2" or tostring(key):find("^formation:")) and type(r)=="table" and r.name==name then archived[key]=r; store[key]=nil; end
 end
 if next(archived) then
  store.standardResetArchive=store.standardResetArchive or {};
  store.standardResetArchive[#store.standardResetArchive+1]={name=name,at=time and time() or GetTime(),records=archived};
 end
end
function G:Reset(reason)
 if S:GroupInCombat() then S:Message("reset botAI доступен после выхода рейда из боя; в бою настройки сохраняются"); return false; end
 if self.reset then S:Message("reset botAI уже отправлен; жду подтверждения, без повторов"); return false; end
 local members=self:Members(); if not next(members) then S:Message("нет онлайн-ботов для reset botAI"); return false; end
 self:CancelControl(); self.wiping=false; self.petWork={}; self.wipeReadAt=nil; self.wipeUntil=nil; self.victory=nil; self.firstDeathAt=nil; self.deaths={};
 UnBotGroupControl:Clear();
 self.reset={members=members,answers={},untilAt=GetTime()+12};
 SendChatMessage("reset botAI",self:Channel());
 S:Message("стандартные стратегии: reset botAI отправлен всей группе ("..(reason or "вручную").."). Жду подтверждения, повторов нет."); return true;
end
function G:Event(event,...)

 if event=="PLAYER_ENTERING_WORLD" then self.deaths={}; self.victory=nil; end
 if event=="CHAT_MSG_WHISPER" then
  local text,sender=...; local name=sender and sender:match("^[^-]+"); local lower=type(text)=="string" and text:lower() or "";
  if self.reset and self.reset.members[name] and lower:find("ai was reset to defaults",1,true) then
   self.reset.answers[name]=true; self:Archive(name);
  end
 end
 if event=="COMBAT_LOG_EVENT_UNFILTERED" and not self.wiping then
  local kind=select(2,...); local entry=S:Entry(select(6,...));
  if (entry==15275 or entry==15276) and (kind=="UNIT_DIED" or kind=="PARTY_KILL") and T:InRoom() and F:Key() then
   if self.firstDeathAt and GetTime()-self.firstDeathAt>=30 then self.deaths={}; self.firstDeathAt=nil; end
   self.deaths=self.deaths or {}; self.deaths[entry]=true; self.firstDeathAt=self.firstDeathAt or GetTime();
   if self.deaths[15275] and self.deaths[15276] and not self.victory then
    self.victory={at=GetTime()+2,untilAt=GetTime()+60}; P:Stop();
    S:Message("победа подтверждена: оба близнеца погибли. После выхода рейда из боя отправлю reset botAI.");
   end
   return true; -- Do not run the legacy first-death restore/focus path.
  end
 end
 return false;
end
function G:Tick()
 local now=GetTime();
 for name,p in pairs(self.petWork or {}) do
  if now>=p.untilAt then self:PetFinish(name,false);
  elseif p.sendAt and now>=p.sendAt then local command=p.sendCommand; p.sendAt=nil; p.sendCommand=nil; SendChatMessage(command,"WHISPER",nil,name); end
 end
 if self.victory and now>=self.victory.at then
  if not S:GroupInCombat() then self:Reset("победа над близнецами");
  elseif now>=self.victory.untilAt then self.victory=nil; S:Message("победа была подтверждена, но рейд ещё в бою: reset botAI отложен до ручной кнопки"); end
 end
 if self.reset then
  local total,done=0,0; for name in pairs(self.reset.members) do total=total+1; if self.reset.answers[name] then done=done+1; end end
  if done==total or now>=self.reset.untilAt then
   self.reset=nil; S:Message("reset botAI: подтверждено "..done.."/"..total..(done==total and ". Стандартные стратегии восстановлены." or ". Часть ботов не подтвердила сброс; автоматических повторов нет."));
  end
 end

end

function P:Selected()
 local loaded=UnBotSquadBuilder and UnBotSquadBuilder.loadedBossPreset;
 return loaded and loaded.bossKey=="temple_of_ahn_qiraj__the_twin_emperors" and loaded.modeKey=="40n5";
end
function P:Message(text) self.status=text; T:Log(text,"player_tank"); S:Message("№3: "..text); self:Refresh(); end
function P:Stop() self.active=false; self.phase=nil; self.queue={}; self.pending=nil; self.ready=false; self.moving=nil; self.fightUntil=nil; self.totalSteps=0; self.totalAttacks=0; end
function P:Job(command,name,read,done)
 self.queue[#self.queue+1]={command=command,name=name,read=read,done=done};
end
function P:Block(text)
 self.queue={}; self.pending=nil; self.phase="blocked"; self.active=true; self.moving=nil;
 if self.tank and T:Unit(self.tank) then
  self:Job("do stay chat shortcut",self.tank);
  self:Job("co +stay,+passive,-follow",self.tank);
  self:Job("nc +stay,+passive,-follow",self.tank);
  self:Job("do drop target",self.tank);
 end
 self:Message(text..". Контроллер сохранён; повтор захвата — кнопкой с выбранным Веклором. Настройки не сбрасываются.");
end
function P:Strategies(m,section,desired,done)
 self:Job(section.." ?",m.name,section,function(actual)
  local tokens={}; for key,wanted in pairs(desired) do if (actual[key]==true)~=wanted then tokens[#tokens+1]=(wanted and "+" or "-")..key; end end; table.sort(tokens);
  if #tokens==0 then done(); return; end
  self:Job(section.." "..table.concat(tokens,","),m.name);
  self:Job(section.." ?",m.name,section,function(applied)
   for key,wanted in pairs(desired) do if (applied[key]==true)~=wanted then self:Block(m.name..": "..section.." "..key.." не применено"); return; end end
   done();
  end);
 end);
end
function P:Prepare()
 if not self:Selected() or not T:InRoom() or UnitIsDeadOrGhost("player") then self:Message("подготовка №3 доступна живому игроку в комнате Близнецов с выбранным пресетом №3"); return false; end
 if S:GroupInCombat() or T:Busy() or G.reset then self:Message("подготовка доступна вне боя после остальных операций"); return false; end
 G:CancelControl(); UnBotGroupControl:Clear(); G.deaths={}; G.firstDeathAt=nil;
 self.members=F:Roster(); self.tank=nil; self.healer=nil;
 if #self.members==2 then
  for _,m in ipairs(self.members) do
   if m.className=="paladin" and F:IsTank(m) and not self.tank then m.role="tank"; self.tank=m.name;
   elseif F:Healer(m) and not self.healer then m.role="heal"; self.healer=m.name; end
  end
 end
 if not self.tank or not self.healer then
  self:Message("нужны 1 онлайн-бот Protection Paladin и 1 хил + игрок. Призови пресет №3"); return false;
 end
 self.context=T:Context(); self.signature=F:Signature(); self.active=true; self.phase="prepare"; self.untilAt=GetTime()+180;
 T:BeginLog("player_paladin"); for _,m in ipairs(self.members) do T.log.names[m.name]=true; end
 self.prepareIndex=0; self:Message("готовлю паладина и одного хила; игрок берёт Векнилаша. Сброса AI при подготовке нет"); self:PrepareNext(); return true;
end
function P:PrepareNext()
 self.prepareIndex=self.prepareIndex+1; local m=self.members[self.prepareIndex];
 if not m then self.ready=true; self.phase="ready"; self:Message("ГОТОВО: один паладин на Звезде, хил "..self.healer.." активен. Выдели Веклора и нажми «Паладин: атаковать Веклора»"); return; end
 if m.role=="heal" then
  -- Only open healing/movement after a wipe; leave the healer's other strategies alone.
  self:Strategies(m,"co",{passive=false,stay=false,heal=true},function()
   self:Strategies(m,"nc",{passive=false},function() self:PrepareNext(); end);
  end);
  return;
 end
 local co={passive=false,stay=false,follow=false,["tank assist"]=false,["dps assist"]=false,grind=false,["attack weak"]=false,["attack force"]=false};
 co.tank=true; co.close=true; co["tank face"]=false; co["avoid aoe"]=false; co.formation=false;
 local nc={passive=false,follow=false,stay=true,grind=false,["tank assist"]=false,["dps assist"]=false};
 self:Strategies(m,"co",co,function()
  self:Strategies(m,"nc",nc,function()
   self:Job("rti star",m.name,"rti");
   self:PrepareNext();
  end);
 end);
end
function P:Start()
 if not self.ready or not self.tank or not T:Unit(self.tank) or #self.queue>0 or self.pending then self:Message("сначала дождись завершения подготовки"); return false; end
 if S:Entry(UnitGUID("target"))~=15276 then self:Message("выдели именно Веклора (NPC 15276), затем нажми атаку. Векнилаш не подходит"); return false; end
 if self.phase=="blocked" then
  self.phase="resume";
  local m={name=self.tank};
  self:Strategies(m,"co",{passive=false,stay=true,close=false},function()
   self:Strategies(m,"nc",{passive=false,stay=true,follow=false},function()
    self:Job("rti star",self.tank,"rti",function()
     self:BeginAcquire(true); self:Job("co -stay,+close",self.tank);
    end);
   end);
  end);
  self:Message("проверяю снятие удержания и назначение Звезды; повторов отказавших команд нет"); return true;
 end
 if not S:GroupInCombat() then S:MarkedUnit(15276,1); S:MarkedUnit(15275,8); end
 self:BeginAcquire(false); return true;
end
function P:BeginAcquire(rti)
 if (self.totalAttacks or 0)>=96 then self:Block("лимит 96 команд захвата за бой исчерпан"); return; end
 if not T.log then T:BeginLog("player_paladin_fight"); end
 self.active=true; self.phase="acquire"; self.untilAt=GetTime()+45; self.fightUntil=self.fightUntil or GetTime()+900; self.acquireAttempts=1; self.nextAcquire=GetTime()+5; self.steps=0; self.totalSteps=self.totalSteps or 0; self.movePaused=nil; self.moving=nil; self.probeCount=0; self.nextProbe=GetTime()+3; self.lastHeal=GetTime();
 -- Immediate direct action: no queued dependency on a later master target.
 local command=rti and "do attack rti target" or "do attack my target";
 self.lastName=self.tank; self.lastSent=GetTime(); self.lastCommand=command;
 self.totalAttacks=(self.totalAttacks or 0)+1; S:Send(command,self.tank); T:Log(command,"send",self.tank);
 self:Message("атака Веклора отправлена паладину. Теперь игрок берёт Векнилаша и отводит его");
end
function P:MapVector()
 if not DBM or not DBM.GetMapSize or not GetPlayerMapPosition then return; end
 if DBM.HasMapRestrictions and DBM:HasMapRestrictions() then return; end
 if WorldMapFrame and WorldMapFrame:IsShown() then return; end
 if SetMapToCurrentZone then SetMapToCurrentZone(); end
 local unit=T:Unit(self.tank); if not unit then return; end
 local bx,by=GetPlayerMapPosition(unit); local px,py=GetPlayerMapPosition("player"); local ok,w,h=pcall(DBM.GetMapSize,DBM);
 if not ok or type(w)~="number" or type(h)~="number" or w<=0 or h<=0 or not bx or not by or not px or not py or bx<=0 or by<=0 or px<=0 or py<=0 then return; end
 -- WotLK map x is reversed world Y; map y is reversed world X.
 local dx,dy=-(by-py)*h,-(bx-px)*w; local distance=math.sqrt(dx*dx+dy*dy);
 if distance<5 or distance>500 then return; end
 return {x=dx/distance,y=dy/distance,distance=distance};
end
function P:BossUnit(entry)
 local list={"target","focus","mouseover","boss1","boss2"}; for i=1,GetNumRaidMembers() do list[#list+1]="raid"..i.."target"; end
 for _,u in ipairs(list) do if S:Entry(UnitGUID(u))==entry then return u; end end
end
function P:Holding()
 return T:Holding(15276,self.tank) and T:Holding(15275,UnitName("player"));
end
function P:Probe()
 if self.pending or #self.queue>0 or self.movePaused then return; end
 if self.probeCount>=8 then self.movePaused=true; self:Message("лимит проверок отвода в этой фазе исчерпан. Паладин удерживает Веклора; игрок отводит Череп сам"); return; end
 local direction=self:MapVector();
 if not direction then self.movePaused=true; self:Message("нет надёжных координат карты DBM: автоотвод приостановлен. Игрок отводит Череп сам; паладин продолжает держать Звезду"); return; end
 self.probeCount=self.probeCount+1; self.nextProbe=GetTime()+6;
 self:Job("debug position",self.tank,"world",function(point)
  if self.phase=="blocked" then return; end
  local fresh=self:MapVector(); if not fresh then self.movePaused=true; return; end
  if self.moving then
   local moved=math.sqrt((point.x-self.moving.x)^2+(point.y-self.moving.y)^2); self.moving=nil;
   if moved<3 then self.movePaused=true; self:Message("паладин не сдвинулся после go. Повторов движения нет; атака сохранена"); return; end
  end
  self:Job("debug tpos",self.tank,"world",function(boss)
   local unit=T:Unit(self.tank); local physical=self:BossUnit(15275);
   if not unit or S:Entry(UnitGUID(unit.."target"))~=15276 or boss.map~=point.map then self:Block("цель изменилась во время проверки отвода"); return; end
   local gap=math.sqrt((point.x-boss.x)^2+(point.y-boss.y)^2);
   -- A caster can remain 30-40 yards from its tank. Use a conservative
   -- lower bound, with room for the physical boss/player hitboxes too.
   self.separated=gap<=45 and fresh.distance-gap-20>=80 and physical and CheckInteractDistance and CheckInteractDistance(physical,3) and self:Holding();
   if self.separated then self.nextProbe=math.huge; self:Message("агро и разведение подтверждены: паладин держит Веклора, игрок — Векнилаша"); return; end
   if not self:Holding() or self.steps>=4 or self.totalSteps>=120 then return; end
   local dst={x=point.x+fresh.x*25,y=point.y+fresh.y*25,z=point.z};
   self:Job("co +stay,-close",self.tank);
   self:Job(string.format("position stay %d,%d,%d",math.floor(dst.x+0.5),math.floor(dst.y+0.5),math.floor(dst.z+0.5)),self.tank,"position");
   self:Job(string.format("go %.2f;%.2f;%.2f",dst.x,dst.y,dst.z),self.tank,nil,function()
    self.steps=self.steps+1; self.totalSteps=self.totalSteps+1; self.moving=point; self.nextProbe=GetTime()+4;
    self:Message("паладин: шаг 25 ярдов от игрока, "..self.steps.."/4. Игрок продолжает отводить Векнилаша; проверю результат");
   end);
  end);
 end);
end
function P:Reply(message,sender)
 local name=sender and sender:match("^[^-]+"); if type(message)~="string" then return; end
 local lower=message:lower(); local job=self.pending;
 if self.active and name==self.lastName and GetTime()-(self.lastSent or 0)<=6 and S.retreat:Rejected(message) then
  if self.phase=="blocked" then self.queue={}; self.pending=nil; self:Message(name..": удержание не подтверждено; пул заблокирован, повторов нет"); return; end
  if job and job.read=="world" then self.pending=nil; self.queue={}; self.movePaused=true; self:Message("сервер отказал в чтении координат; автоотвод приостановлен. Атака сохраняется");
  else self:Block(name..": "..message); end; return;
 end
 if not job or job.name~=name then return; end
 local value;
 if job.read=="co" or job.read=="nc" then
  local list=lower:match("^strategies:%s*(.*)$"); if list then value={}; for key in list:gmatch("[^,]+") do value[key:match("^%s*(.-)%s*$")]=true; end end
 elseif job.read=="position" then value=lower:find("position stay is set",1,true) and true or nil;
 elseif job.read=="rti" then value=lower:match("^rti set to:%s*(%a+)")==job.command:match("^rti (%a+)$") and true or nil;
 elseif job.read=="world" then
  local x,y,z,map=lower:match("^%s*([%d%.%-]+)%s+([%d%.%-]+)%s+([%d%.%-]+)%s+(%d+)%s");
  if tonumber(x) and tonumber(y) and tonumber(z) and tonumber(map) and math.abs(tonumber(x))<50000 and math.abs(tonumber(y))<50000 then value={x=tonumber(x),y=tonumber(y),z=tonumber(z),map=tonumber(map)}; end
 end
 if value then self.pending=nil; T:Log(message,"reply",name); if job.done then job.done(value); end end
end
function P:Event(event,...)
 if event=="CHAT_MSG_WHISPER" then self:Reply(select(1,...),select(2,...)); return true; end
 if event=="CHAT_MSG_ADDON" then
  local prefix,message,channel,sender=...;
  -- Forks return either prefix+body or unprefixed raw addon text.
  self:Reply(message,sender); if self.pending then self:Reply(prefix,sender); end; return true;
 end
 if event=="PLAYER_ENTERING_WORLD" then self:Stop(); return true; end
 if event=="PLAYER_LOGOUT" then T:FinishLog("reload_or_logout"); return true; end
 if event=="COMBAT_LOG_EVENT_UNFILTERED" then
  if not self.active then return true; end
  local kind=select(2,...); local source=S:Entry(select(3,...)); local dest=S:Entry(select(6,...)); local spell=select(9,...);
  if (source==15275 or source==15276) and (kind=="SWING_DAMAGE" or kind=="SWING_MISSED" or kind=="SPELL_DAMAGE" and spell==26006) then
   T.aggro=T.aggro or {}; T.aggro[source]={name=select(7,...),at=GetTime()};
  end
  if kind=="SPELL_HEAL" and spell==7393 and (dest==15275 or dest==15276) then self.lastHeal=GetTime(); self.separated=false; self.nextProbe=GetTime()+1; end
  if kind=="SPELL_AURA_APPLIED" and spell==800 and (source==15275 or source==15276) and GetTime()-(self.lastTeleport or 0)>5 and self.phase~="blocked" then
   self.lastTeleport=GetTime(); self.queue={}; self.pending=nil; self.separated=false; self.phase="acquire"; self.acquireAttempts=0; self.nextAcquire=GetTime()+2; self.untilAt=GetTime()+45; self.probeCount=0; self.steps=0; self.moving=nil; self.movePaused=nil;
   self:Job("co -stay,+close",self.tank); self:Message("телепорт: паладин возвращает Веклора. Игрок, перехвати Векнилаша");
  end
  return true;
 end
 return false;
end
function P:Tick()
 local now=GetTime(); if not self.active then return; end
 if self.phase=="ready" and not S:GroupInCombat() then S:MarkedUnit(15275,8); S:MarkedUnit(15276,1); end
 if not self:Selected() or self.context~=T:Context() or F:Signature()~=self.signature then self:Stop(); self:Message("пресет, состав или зона изменились; команды отменены без сброса AI"); return; end
 if self.fightUntil and now>=self.fightUntil then self.fightUntil=nil; self:Block("достигнут лимит 15 минут"); end
 if self.pending and now>=self.pending.untilAt then
  local job=self.pending; self.pending=nil;
  if job.read=="world" then self.queue={}; self.movePaused=true; self:Message("нет ответа на "..job.command..": автоотвод приостановлен без повторов; паладин продолжает атаковать Веклора");
  elseif self.phase=="blocked" then self.queue={}; self:Message("удержание не подтверждено: "..job.command.."; повторов нет");
  else self:Block("таймаут "..job.name..": "..job.command); end
 end
 if not self.pending and #self.queue>0 and now>=self.nextSend then
  local job=table.remove(self.queue,1); self.lastSent=now; self.lastName=job.name; self.lastCommand=job.command; self.nextSend=now+1.1;
  if job.read then job.untilAt=now+7; self.pending=job; end
  S:Send(job.command,job.name); T:Log(job.command,"send",job.name);
  if not job.read and job.done then job.done(); end
 end
 if self.phase=="prepare" and now>=self.untilAt then self:Block("подготовка не завершилась за 180 секунд"); end
 if self.phase=="acquire" then
  local unit=T:Unit(self.tank);
  if unit and S:Entry(UnitGUID(unit.."target"))==15276 and T:Holding(15276,self.tank) then self.phase="fight"; self:Message("Веклор атакует паладина. Игрок удерживает и отводит Векнилаша; проверяю разведение");
  elseif now>=self.nextAcquire and not self.pending and #self.queue==0 then
   if self.acquireAttempts>=3 or (self.totalAttacks or 0)>=96 or now>=self.untilAt then self:Block("захват Веклора не подтверждён после ограниченных попыток");
   else self.acquireAttempts=self.acquireAttempts+1; self.totalAttacks=(self.totalAttacks or 0)+1; self.nextAcquire=now+5; self:Job("do attack rti target",self.tank); end
  end
 end
 if self.phase=="fight" then
  if not T:Holding(15276,self.tank) then
   self.queue={}; self.pending=nil; self.separated=false; self.phase="acquire"; self.acquireAttempts=0; self.nextAcquire=now+2; self.untilAt=now+45; self.probeCount=0; self.movePaused=nil;
   self:Message("агро Веклора потеряно: паладин ограниченно повторяет захват Звезды");
  elseif not T:Holding(15275,UnitName("player")) then
   self.separated=false; self.nextProbe=now+4;
   if not self.playerLost then self.playerLost=true; self:Message("игрок потерял Векнилаша: перехвати Череп"); end
  else self.playerLost=nil; if now>=(self.nextProbe or 0) then self:Probe(); end end
 end
 self:Refresh();
end
function P:Refresh()
 if not self.frame then return; end
 self.frame.status:SetText(self.status or "Пресет №3: игрок — Векнилаш, один паладин — Веклор, один хил. Подготовка запускается вручную.");
 self.frame.tank:SetText("Паладин: "..(self.tank or "из состава №3").."; Хил: "..(self.healer or "из состава №3"));
end
function P:Show()
 if T.frame then T.frame:Hide(); end
 if not self.frame then
  local f=CreateFrame("Frame","UnBotTwinPlayerTankFrame",UIParent); self.frame=f;
  f:SetSize(600,377); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton"); f:SetScript("OnDragStart",function() f:StartMoving(); end); f:SetScript("OnDragStop",function() f:StopMovingOrSizing(); end);
  f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=32,insets={left=8,right=8,top=8,bottom=8}});
  local close=CreateFrame("Button",nil,f,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",-4,-4);
  local title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); title:SetPoint("TOP",0,-18); title:SetText("Близнецы №3 — игрок + паладин + хил (6.38.214)");
  local hint=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); hint:SetPoint("TOPLEFT",18,-52); hint:SetSize(560,68); hint:SetJustifyH("LEFT"); hint:SetText("Игрок: Череп, Век'нилаш. Паладин: Звезда, Век'лор.\nПосле атаки паладина выбери Векнилаша и отводи его сам.\nТелепорт сбрасывает агро: игрок снова забирает Череп.\nХил должен оставаться в радиусе лечения паладина. Автоотвод требует DBM.");
  f.tank=f:CreateFontString(nil,"OVERLAY","GameFontNormal"); f.tank:SetPoint("TOPLEFT",18,-124);
  local function button(text,y,fn)
   local b=CreateFrame("Button",nil,f,"UIPanelButtonTemplate"); b:SetSize(560,25); b:SetPoint("TOPLEFT",18,y); b:SetText(text); b:SetScript("OnClick",fn); return b;
  end
  f.prepare=button("1. Подготовить №3: паладин + один хил + игрок",-150,function() P:Prepare(); end);
  f.start=button("2. Паладин: атаковать Веклора из цели / повторить захват",-183,function() P:Start(); end);
  f.stop=button("Стоп — отменить управление без сброса стратегий",-216,function() P:Stop(); T:StopOnly(); P:Message("управление остановлено, стратегии сохранены"); end);
  f.reset=button("Стандартные стратегии — reset botAI (после боя)",-249,function() G:Reset("вручную"); end);
  f.wipe=button("Принудительный вайп — серверная команда wipe",-282,function() G:Wipe(); end);
  f.status=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); f.status:SetPoint("TOPLEFT",18,-319); f.status:SetSize(560,42); f.status:SetJustifyH("LEFT");
 end
 self.frame:Show(); self:Refresh();
end
end
