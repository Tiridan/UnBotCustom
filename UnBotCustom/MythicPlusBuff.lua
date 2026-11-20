-- Mythic+ buff helper for a full five-player party.
-- One known bot is parked temporarily, the normal raid buff engine works
-- through the single free slot, then the exact same bot is restored.

UnBotMythicPlusBuff = UnBotMythicPlusBuff or {
	active = false,
	stage = "idle",
	nextTime = 0,
	deadline = 0,
	attempts = 0,
	originalMembers = {},
	parkedName = nil,
	parkedClass = nil,
	parkedSpec = nil,
	parkedRole = nil,
	allowBuffCycleStart = false,
	stoppingBuffCycle = false,
	buffDone = false,
	buffStartedAt = 0,
	restoreReason = nil,
	cancelled = false,
	combatWaitReported = false,
};

local state = UnBotMythicPlusBuff;
local frame = CreateFrame("Frame");

local function Normalize(text)
	text = string.lower(tostring(text or ""));
	text = string.gsub(text, "^%s+", "");
	text = string.gsub(text, "%s+$", "");
	text = string.gsub(text, "%s+", " ");
	if (text == "death knight" or text == "deathknight") then
		return "dk";
	end
	return text;
end

local function Message(text)
	if (UnBotSpecSummonMessage) then
		UnBotSpecSummonMessage(text);
	elseif (DEFAULT_CHAT_FRAME) then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00cccc"..tostring(text).."|r");
	end
end

local function SendAdd(name)
	if (name) then
		SendChatMessage(".playerbot bot add "..tostring(name), "SAY");
	end
end

local function OtherAutomationActive()
	return UnBotMythicPlusBuffOtherAutomationActive
		and UnBotMythicPlusBuffOtherAutomationActive()
		or false;
end

-- Lower score means that parking this member costs fewer useful group buffs.
-- DPS is preferred; healer/tank and finally an unknown registered bot are safe
-- fallbacks because the operation is available only outside combat.
local function ParkPriority(profile)
	if (type(profile) ~= "table") then
		return nil, nil;
	end
	local className = Normalize(profile.className);
	local specName = Normalize(profile.specName);
	if (specName == "prot") then specName = "protection"; end
	if (specName == "resto") then specName = "restoration"; end
	if (specName == "disc") then specName = "discipline"; end
	if (specName == "ret") then specName = "retribution"; end
	local classUtility = 0;
	if (className == "dk") then
		classUtility = 2;
	elseif (className == "warrior") then
		classUtility = 3;
	elseif (className == "mage") then
		classUtility = 6;
	elseif (className == "warlock") then
		classUtility = 7;
	elseif (className == "druid") then
		classUtility = 8;
	elseif (className == "priest") then
		classUtility = 9;
	elseif (className == "paladin") then
		classUtility = 10;
	end
	local feralRole = className == "druid"
		and specName == "feral combat"
		and UnBotFeralProfileRole
		and UnBotFeralProfileRole(profile) or nil;
	local isDps = className == "rogue"
		or className == "hunter"
		or className == "mage"
		or className == "warlock"
		or (className == "shaman" and (specName == "elemental" or specName == "enhancement"))
		or (className == "dk" and (specName == "frost" or specName == "unholy"))
		or (className == "warrior" and (specName == "arms" or specName == "fury"))
		or (className == "druid" and specName == "balance")
		or (
		className == "druid"
		and specName == "feral combat"
		and feralRole == "cat"
	)
		or (className == "priest" and specName == "shadow")
		or (className == "paladin" and specName == "retribution");
	if (isDps) then
		return classUtility, "ДД";
	end
	local isHealer = (className == "paladin" and specName == "holy")
		or (className == "priest" and (specName == "holy" or specName == "discipline"))
		or (className == "shaman" and specName == "restoration")
		or (className == "druid" and specName == "restoration");
	if (isHealer) then
		return 100 + classUtility, "хила";
	end
	local isTank = (className == "warrior" and specName == "protection")
		or (className == "paladin" and specName == "protection")
		or (className == "dk" and specName == "blood")
		or (className == "druid" and specName == "feral combat" and feralRole == "bear");
	if (isTank) then
		return 100 + classUtility, "танка";
	end
	return 200 + classUtility, "бота с неизвестной ролью";
end

local function SelectParkedMember(members)
	local candidates = {};
	local playerName = UnitName("player");
	for name in pairs(members or {}) do
		local profile = name ~= playerName
			and UnBotBotRegistry
			and UnBotBotRegistry.bots
			and UnBotBotRegistry.bots[name];
		local utility, role = ParkPriority(profile);
		if (
			type(utility) == "number"
			and not (
				UnBotIsAccountAltProfile
				and UnBotIsAccountAltProfile(name, profile)
			)
		) then
			table.insert(candidates, {
				name = name,
				profile = profile,
				utility = utility,
				role = role,
			});
		end
	end
	table.sort(candidates, function(left, right)
		local leftUtility = tonumber(left.utility) or 999;
		local rightUtility = tonumber(right.utility) or 999;
		if (leftUtility ~= rightUtility) then
			return leftUtility < rightUtility;
		end
		return string.lower(left.name) < string.lower(right.name);
	end);
	return candidates[1];
end

local function Reset()
	state.active = false;
	state.stage = "idle";
	state.nextTime = 0;
	state.deadline = 0;
	state.attempts = 0;
	state.originalMembers = {};
	state.parkedName = nil;
	state.parkedClass = nil;
	state.parkedSpec = nil;
	state.parkedRole = nil;
	state.allowBuffCycleStart = false;
	state.stoppingBuffCycle = false;
	state.buffDone = false;
	state.buffStartedAt = 0;
	state.restoreReason = nil;
	state.cancelled = false;
	state.combatWaitReported = false;
	frame:Hide();
end

local function CurrentRosterMatchesOriginal()
	local current = UnBotMythicPlusBuffGetMembers and UnBotMythicPlusBuffGetMembers() or {};
	for name in pairs(state.originalMembers or {}) do
		if (not current[name]) then
			return false, name;
		end
	end
	for name in pairs(current) do
		if (not state.originalMembers[name]) then
			return false, name;
		end
	end
	return true, nil;
end

local function FinishRestoration()
	if (UnBotMythicPlusBuffSuppressPendingReserve) then
		UnBotMythicPlusBuffSuppressPendingReserve();
	end
	local matched, mismatchName = CurrentRosterMatchesOriginal();
	local parkedName = state.parkedName;
	local cancelled = state.cancelled;
	local restoreReason = state.restoreReason;
	local raidCount = GetNumRaidMembers and GetNumRaidMembers() or 0;
	if (matched and raidCount == 0 and GetNumPartyMembers() == 4) then
		if (cancelled) then
			Message("Mythic+: операция остановлена; исходная группа восстановлена, "..tostring(parkedName).." возвращён.");
		else
			Message(
				"Mythic+: бафф-цикл завершён без рейда; "..tostring(parkedName)
				.." возвращён в исходную пятёрку. У временно исключённого ДД групповые баффы после возврата не гарантируются."
			);
		end
		Reset();
		return;
	end
	Message(
		"Mythic+: автоматическое восстановление состава не подтверждено"
		..(restoreReason and " ("..tostring(restoreReason)..")" or "")
		..(mismatchName and "; проверьте "..tostring(mismatchName) or "")
		..". Ожидался возврат "..tostring(parkedName).."; подмена другим ботом не выполнялась."
	);
	Reset();
end

local function BeginRestore(reason, cancelled)
	if (UnBotMythicPlusBuffSuppressPendingReserve) then
		UnBotMythicPlusBuffSuppressPendingReserve();
	end
	state.restoreReason = reason or state.restoreReason;
	state.cancelled = cancelled == true or state.cancelled == true;
	if (UnBotMythicPlusBuffCycleActive and UnBotMythicPlusBuffCycleActive()) then
		state.stoppingBuffCycle = true;
		UnBotBuffCycleStopByUser();
		state.stoppingBuffCycle = false;
	end
	state.stage = "restore";
	state.attempts = 0;
	state.nextTime = GetTime() + 0.5;
	state.deadline = GetTime() + 60;
	state.combatWaitReported = false;
end

function UnBotMythicPlusBuffIsRunning()
	return state.active == true;
end

function UnBotMythicPlusBuffMayStartBuffCycle()
	return state.active == true and state.allowBuffCycleStart == true;
end

function UnBotMythicPlusBuffIsStoppingBuffCycle()
	return state.stoppingBuffCycle == true;
end

function UnBotMythicPlusBuffShouldExcludeRegistryName(name)
	return state.active == true and state.parkedName == name;
end

function UnBotMythicPlusBuffStopByUser()
	if (not state.active) then
		Message("Нет активного баффа Mythic+.");
		return false;
	end
	Message("Mythic+: остановка запрошена; временные бафферы удаляются, исключённый ДД будет возвращён.");
	BeginRestore("остановлено пользователем", true);
	return true;
end

function UnBotMythicPlusBuffStart()
	if (state.active) then
		return UnBotMythicPlusBuffStopByUser();
	end
	if (UnitAffectingCombat and UnitAffectingCombat("player")) then
		Message("Mythic+: запуск возможен только вне боя.");
		return false;
	end
	if (IsMounted and IsMounted()) then
		Message("Mythic+: спешьтесь перед запуском баффов.");
		return false;
	end
	if (GetNumRaidMembers and GetNumRaidMembers() > 0) then
		Message("Mythic+: требуется обычная группа, а не рейд.");
		return false;
	end
	if (GetNumPartyMembers() ~= 4) then
		Message("Mythic+: требуется полная группа — игрок и четыре участника.");
		return false;
	end
	if (
		(UnitIsPartyLeader and not UnitIsPartyLeader("player"))
		or (
			not UnitIsPartyLeader
			and IsPartyLeader
			and not IsPartyLeader()
		)
	) then
		Message("Mythic+: игрок должен быть лидером группы, чтобы временно исключить и вернуть ДД.");
		return false;
	end
	if (OtherAutomationActive()) then
		Message("Mythic+: сначала завершите другую автоматическую операцию UnBot.");
		return false;
	end
	if (
		not UnBotMythicPlusBuffGetMembers
		or not UnBotMythicPlusBuffUninvite
		or not UnBotRaidBuffCycleStart
	) then
		Message("Mythic+: модуль загружен не полностью; выполните полный перезапуск клиента WoW.");
		return false;
	end

	local members = UnBotMythicPlusBuffGetMembers();
	local playerName = UnitName("player");
	local memberCount = 0;
	local unavailable = {};
	for name in pairs(members) do
		memberCount = memberCount + 1;
		if (name ~= playerName) then
			local unit = UnBotSquadRosterFindUnit and UnBotSquadRosterFindUnit(name);
			if (
				not unit
				or not UnitIsConnected(unit)
				or (UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit))
				or (
					UnBotSquadNearbyGateUnitReady
					and not UnBotSquadNearbyGateUnitReady(unit)
				)
			) then
				table.insert(unavailable, name);
			end
		end
	end
	if (memberCount ~= 5) then
		Message("Mythic+: не удалось подтвердить точный состав из пяти участников.");
		return false;
	end
	if (#unavailable > 0) then
		table.sort(unavailable);
		Message("Mythic+: все участники должны быть живы, онлайн и рядом. Не готовы: "..table.concat(unavailable, ", ")..".");
		return false;
	end

	local candidate = SelectParkedMember(members);
	if (not candidate) then
		Message("Mythic+: в текущей группе не найден зарегистрированный бот для временного исключения. Игроки и альты аккаунта не исключаются.");
		return false;
	end

	state.active = true;
	state.stage = "remove";
	state.nextTime = GetTime();
	state.deadline = GetTime() + 15;
	state.attempts = 0;
	state.originalMembers = members;
	state.parkedName = candidate.name;
	state.parkedClass = Normalize(candidate.profile.className);
	state.parkedSpec = Normalize(candidate.profile.specName);
	state.parkedRole = candidate.role or "бота";
	state.allowBuffCycleStart = false;
	state.stoppingBuffCycle = false;
	state.buffDone = false;
	state.buffStartedAt = 0;
	state.restoreReason = nil;
	state.cancelled = false;
	state.combatWaitReported = false;
	if (UnBotMythicPlusBuffSuppressPendingReserve) then
		UnBotMythicPlusBuffSuppressPendingReserve();
	end
	frame:Show();
	Message(
		"Mythic+: временно исключаю "..state.parkedRole.." "..candidate.name.." ("
		..state.parkedClass.." / "..state.parkedSpec
		.."). Оставшиеся классы используются первыми; недостающие бафферы ротируются по одному слоту. Для остановки: /ubstopbuffs."
	);
	return true;
end

frame:SetScript("OnUpdate", function()
	if (not state.active) then
		frame:Hide();
		return;
	end
	local now = GetTime();
	if (now < (state.nextTime or 0)) then
		return;
	end

	if (state.stage == "remove") then
		if (not UnBotMythicPlusBuffIsInGroup(state.parkedName)) then
			if (GetNumPartyMembers() ~= 3) then
				BeginRestore("после исключения ДД состав не равен четырём участникам", false);
				return;
			end
			state.stage = "start_buff";
			state.nextTime = now + 0.5;
			return;
		end
		if (UnitAffectingCombat and UnitAffectingCombat("player")) then
			BeginRestore("начался бой до исключения ДД", false);
			return;
		end
		if (now >= (state.deadline or 0) or state.attempts >= 3) then
			BeginRestore("сервер не исключил выбранного ДД за три попытки", false);
			return;
		end
		state.attempts = state.attempts + 1;
		UnBotMythicPlusBuffUninvite(state.parkedName);
		state.nextTime = now + 2.5;
		return;
	end

	if (state.stage == "start_buff") then
		if (GetNumRaidMembers and GetNumRaidMembers() > 0) then
			BeginRestore("группа неожиданно стала рейдом до запуска баффов", false);
			return;
		end
		if (GetNumPartyMembers() ~= 3) then
			BeginRestore("свободный слот Mythic+ не подтверждён", false);
			return;
		end
		state.allowBuffCycleStart = true;
		local started = UnBotRaidBuffCycleStart(function()
			state.buffDone = true;
		end, 5, true, false);
		state.allowBuffCycleStart = false;
		if (not started) then
			BeginRestore("штатный бафф-цикл не запустился", false);
			return;
		end
		state.stage = "buff";
		state.buffStartedAt = now;
		state.deadline = now + 900;
		state.nextTime = now + 0.5;
		return;
	end

	if (state.stage == "buff") then
		if (GetNumRaidMembers and GetNumRaidMembers() > 0) then
			BeginRestore("во время баффов группа неожиданно стала рейдом", false);
			return;
		end
		if (state.buffDone) then
			BeginRestore(nil, false);
			return;
		end
		if (
			now > (state.buffStartedAt or 0) + 2
			and UnBotMythicPlusBuffCycleActive
			and not UnBotMythicPlusBuffCycleActive()
		) then
			BeginRestore("бафф-цикл остановился до штатного завершения", false);
			return;
		end
		if (now >= (state.deadline or 0)) then
			BeginRestore("истёк общий таймаут бафф-цикла", false);
			return;
		end
		state.nextTime = now + 0.5;
		return;
	end

	if (state.stage == "restore") then
		if (UnBotMythicPlusBuffIsInGroup(state.parkedName)) then
			FinishRestoration();
			return;
		end
		if (GetNumRaidMembers and GetNumRaidMembers() > 0) then
			state.restoreReason = "состав является рейдом; автоматическое преобразование назад запрещено";
			FinishRestoration();
			return;
		end
		if (now >= (state.deadline or 0)) then
			FinishRestoration();
			return;
		end
		if (GetNumPartyMembers() >= 4) then
			state.nextTime = now + 1;
			return;
		end
		if (UnitAffectingCombat and UnitAffectingCombat("player")) then
			if (not state.combatWaitReported) then
				state.combatWaitReported = true;
				Message("Mythic+: бой начался; защищённое приглашение отложено, отправлена только серверная команда возврата ДД.");
			end
			if (state.attempts == 0) then
				SendAdd(state.parkedName);
				state.attempts = 1;
			end
			state.nextTime = now + 2;
			return;
		end
		state.combatWaitReported = false;
		if (state.attempts >= 6) then
			state.nextTime = now + 1;
			return;
		end
		state.attempts = state.attempts + 1;
		if (state.attempts == 2 or state.attempts == 4) then
			SendAdd(state.parkedName);
		end
		InviteUnit(state.parkedName);
		state.nextTime = now + 2.5;
	end
end);

SLASH_UNBOTMYTHICPLUSBUFF1 = "/ubmythicbuffs";
SLASH_UNBOTMYTHICPLUSBUFF2 = "/ubmplusbuffs";
SlashCmdList["UNBOTMYTHICPLUSBUFF"] = UnBotMythicPlusBuffStart;
