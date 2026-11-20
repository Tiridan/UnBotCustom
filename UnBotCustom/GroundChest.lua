-- Bounded ground-chest session with one explicit init workaround per start.
-- Reconnecting a bot can lose the working state; never persist init readiness.
-- The server-side Playerbot AI decides
-- whether and how to interact with the nearby GameObject; the addon only brings
-- one rogue online at a time and never pretends that a cast line proves success.

UnBotGroundChest = UnBotGroundChest or {
	active = false,
	stage = "idle",
	maxFallbacks = 6,
	fallbackCount = 0,
	tried = {},
	lateCleanup = {},
	currentName = nil,
	currentAdded = false,
	pendingName = nil,
	pendingKind = nil,
	pendingWasOnline = false,
	inviteSent = false,
	addAttempts = 0,
	nextActionAt = 0,
	deadline = 0,
	status = "Сеанс не запущен.",
	frame = nil,
	refreshElapsed = 0,
};

function UnBotGroundChest.Message(text)
	if (UnBotBotCenterMessage) then
		UnBotBotCenterMessage(text);
	elseif (UnBotChatWrite) then
		UnBotChatWrite("|cff69ccf0[UnBot]|r "..tostring(text));
	end
end

function UnBotGroundChest.IsOnline(name)
	return name
		and UnBotGroundChestIsInGroup
		and UnBotGroundChestIsInGroup(name)
		and UnBotRaidReserveOnline
		and UnBotRaidReserveOnline(name)
		and true or false;
end

function UnBotGroundChest.SendSay(text)
	if (UnBotBuffCycleSendSay) then
		UnBotBuffCycleSendSay(text);
	else
		SendChatMessage(text, "SAY");
	end
end

function UnBotGroundChest.SendWhisper(name, text)
	if (not name) then
		return;
	end
	if (UnBotBuffCycleSendWhisper) then
		UnBotBuffCycleSendWhisper(name, text);
	else
		SendChatMessage(text, "WHISPER", nil, name);
	end
end

function UnBotGroundChest.SetStatus(text, announce)
	UnBotGroundChest.status = tostring(text or "");
	if (announce) then
		UnBotGroundChest.Message(UnBotGroundChest.status);
	end
	UnBotGroundChest.Refresh();
end

function UnBotGroundChest.HasLateCleanup()
	for _ in pairs(UnBotGroundChest.lateCleanup or {}) do
		return true;
	end
	return false;
end

function UnBotGroundChest.StageText()
	local state = UnBotGroundChest;
	if (state.stage == "add_candidate") then
		return "Подключение доступного разбойника";
	elseif (state.stage == "wait_poison") then
		return "Жду 9 секунд: разбойник наносит яды";
	elseif (state.stage == "who_before_init") then
		return "Проверяем разбойника перед переинициализацией";
	elseif (state.stage == "wait_init_reply") then
		return "Ждём принятия init сервером";
	elseif (state.stage == "wait_init_settle") then
		return "Ждём 9 секунд после принятия init";
	elseif (state.stage == "who_after_init") then
		return "Проверяем ответ разбойника после init";
	elseif (state.stage == "wait_arrival") then
		return "Проверяем прибытие разбойника к вам";
	elseif (state.stage == "watch_chest") then
		return "Разбойник самостоятельно пытается открыть сундук";
	elseif (state.stage == "rotate_offline") then
		return "Отключаем предыдущего помощника";
	elseif (state.stage == "stop_offline") then
		return "Завершаем помощь и отключаем разбойника";
	elseif (state.active) then
		return "Сеанс выполняется";
	end
	return "Остановлено";
end

function UnBotGroundChest.TimeText()
	local state = UnBotGroundChest;
	if ((state.deadline or 0) > GetTime()) then
		return tostring(math.max(0, math.ceil(state.deadline - GetTime()))).." сек.";
	end
	return "—";
end

function UnBotGroundChest.Refresh()
	local state = UnBotGroundChest;
	local frame = state.frame;
	if (not frame) then
		return;
	end
	frame.currentText:SetText("Текущий разбойник: "..tostring(state.currentName or state.pendingName or "—"));
	frame.phaseText:SetText("Что происходит: "..UnBotGroundChest.StageText());
	frame.timerText:SetText("Осталось: "..UnBotGroundChest.TimeText());
	frame.counterText:SetText(
		"Переинициализация: "..tostring(state.initCount or 0).."/1"
	);
	frame.statusText:SetText(tostring(state.status or ""));
	if (state.active or UnBotGroundChest.HasLateCleanup()) then
		frame.startButton:Disable();
	else
		frame.startButton:Enable();
	end
	if (state.active) then
		frame.stopButton:Enable();
	else
		frame.stopButton:Disable();
	end
end

function UnBotGroundChest.OtherAutomationActive()
	return (
		(UnBotLockboxService and UnBotLockboxService.active)
		or (UnBotBotScanner and UnBotBotScanner.active)
		or (UnBotJunkCleaner and UnBotJunkCleaner.active)
		or (UnBotFastJunkRaid and UnBotFastJunkRaid.active)
		or (UnBotBuffCycle and UnBotBuffCycle.active)
		or (UnBotSoulstoneTest and UnBotSoulstoneTest.active)
		or (UnBotSpecSummon and UnBotSpecSummon.active)
		or (UnBotSquadRoleAction and UnBotSquadRoleAction.active)
		or (UnBotSquadNearbyGate and UnBotSquadNearbyGate.active)
		or (UnBotDKSpecBalance and UnBotDKSpecBalance.active)
		or (
			UnBotSquadSpecCheck
			and (
				UnBotSquadSpecCheck.active
				or (UnBotSquadSpecCheck.autoStartAt or 0) > 0
			)
		)
		or (UnBotRaidReserve and UnBotRaidReserve.active)
	);
end

function UnBotGroundChest.MarkLateCleanup(name)
	if (name) then
		UnBotGroundChest.lateCleanup[name] = GetTime() + 20;
	end
end

function UnBotGroundChest.BeginAdd(name, kind)
	local state = UnBotGroundChest;
	if (name and UnBotIsAccountAltProfile and UnBotIsAccountAltProfile(name,
		UnBotBotRegistry and UnBotBotRegistry.bots and UnBotBotRegistry.bots[name])) then
		state.tried[name] = true;
		UnBotGroundChest.BeginFallback("персонажи аккаунта не используются для переинициализации");
		return;
	end
	if (name and not UnBotGroundChestIsInGroup(name)) then
		local raid = (GetNumRaidMembers() or 0) > 0;
		local count = raid and GetNumRaidMembers() or ((GetNumPartyMembers() or 0) + 1);
		if (count >= (raid and 40 or 5)) then
			UnBotGroundChest.FinalizeStop("Нет свободного места для другого разбойника. Отключённые участники остаются в группе; освободите место и повторите.");
			return;
		end
	end
	if (not name) then
		UnBotGroundChest.SetStatus("Наземный сундук: имя разбойника не определено.", true);
		state.active = false;
		state.stage = "idle";
		UnBotGroundChest.Refresh();
		return;
	end
	state.pendingName = name;
	state.pendingKind = kind;
	state.pendingWasOnline = UnBotGroundChest.IsOnline(name);
	state.inviteSent = false;
	state.addAttempts = 0;
	state.nextActionAt = GetTime();
	state.deadline = GetTime() + 15;
	state.stage = "add_candidate";
	if (state.pendingWasOnline) then
		UnBotGroundChest.RogueReady(name, false, kind);
		return;
	end
	UnBotGroundChest.SetStatus(
		"Подключаю доступного разбойника "..name.." (кандидат "
			..tostring(state.fallbackCount).."/"..tostring(state.maxFallbacks)..").",
		true
	);
end

function UnBotGroundChest.BeginFallback(reason)
	local state = UnBotGroundChest;
	UnBotGroundChest.RestoreDebug();
	state.currentName = nil;
	state.currentAdded = false;
	state.pendingName = nil;
	state.pendingKind = nil;
	state.deadline = 0;
	if ((state.fallbackCount or 0) >= (state.maxFallbacks or 5)) then
		state.active = false;
		state.stage = "idle";
		UnBotGroundChest.SetStatus(
			"Не удалось подключить помощника после шести кандидатов. Поиск завершён.",
			true
		);
		return;
	end
	local candidates = UnBotGroundChestCandidateList and UnBotGroundChestCandidateList(state.tried) or {};
	local name = candidates[1];
	if (not name) then
		state.active = false;
		state.stage = "idle";
		UnBotGroundChest.SetStatus(
			"Свободных разбойников больше нет. Помощь со вскрытием завершена.",
			true
		);
		return;
	end
	state.fallbackCount = (state.fallbackCount or 0) + 1;
	state.tried[name] = true;
	UnBotGroundChest.SetStatus(
		"Наземный сундук: "..tostring(reason or "выбираем доступного помощника")
		..". Кандидат: "..name..".",
		true
	);
	UnBotGroundChest.BeginAdd(name, "candidate");
end

function UnBotGroundChest.RogueReady(name, added, kind)
	local state = UnBotGroundChest;
	state.currentName = name;
	state.currentAdded = added and true or false;
	state.pendingName = nil;
	state.pendingKind = kind;
	state.addAttempts = 0;
	state.inviteSent = false;
	state.nextActionAt = 0;
	state.herbFailure = nil;
	state.initAccepted = false;
	state.beforeWho = nil;
	state.afterWho = nil;
	if (UnBotDebugChatWrite) then UnBotDebugChatWrite("Начало проверки разбойника "..name.." для вскрытия сундука."); end
	if (UnBotGroundChestRecordGameplaySummon) then
		UnBotGroundChestRecordGameplaySummon(name, "ground-lockbox-service");
	end
	if (UnBotGroupStrategyOnGameplaySummon) then
		UnBotGroupStrategyOnGameplaySummon(name, "ground-lockbox-service");
	end
	if (added) then
		state.stage = "wait_poison";
		state.deadline = GetTime() + 9;
		UnBotGroundChest.SetStatus(
			"Разбойник "..name.." вошёл в группу. Ждём 9 секунд, пока он подготовит оружие, затем подзовём его к вам.",
			true
		);
	else
		UnBotGroundChest.QueryBeforeInit();
	end
end

function UnBotGroundChest.QueryBeforeInit()
	local state = UnBotGroundChest;
	state.stage = "who_before_init";
	state.deadline = GetTime() + 8;
	UnBotGroundChest.SendWhisper(state.currentName, "who");
	UnBotGroundChest.SetStatus("Проверяем "..tostring(state.currentName).." перед одним init. Он может изменить уровень, экипировку, навыки и специализацию бота.", true);
end

function UnBotGroundChest.BeginInit()
	local state = UnBotGroundChest;
	local name = state.currentName;
	local unit = name and UnBotSquadRosterFindUnit and UnBotSquadRosterFindUnit(name);
	if ((state.initCount or 0) >= 1 or not state.beforeWho or not UnBotGroundChest.IsOnline(name)
		or not unit or (UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit))
		or (InCombatLockdown and InCombatLockdown())
		or (UnitAffectingCombat and (UnitAffectingCombat("player") or UnitAffectingCombat(unit)))
		or (UnBotIsAccountAltProfile and UnBotIsAccountAltProfile(name,
			UnBotBotRegistry and UnBotBotRegistry.bots and UnBotBotRegistry.bots[name]))) then
		UnBotGroundChest.Stop("Переинициализация недоступна: проверьте состояние разбойника. Повторного init в этом сеансе не будет.");
		return;
	end
	state.initCount = 1;
	state.stage = "wait_init_reply";
	state.deadline = GetTime() + 10;
	UnBotGroundChest.SendSay(".playerbot bot init "..name);
	UnBotGroundChest.SetStatus("Отправлен один init для "..name..". Ждём ответа сервера; повторять команду не будем.", true);
end

function UnBotGroundChest.OnSystem(message)
	local state = UnBotGroundChest;
	if (not state.active or state.stage ~= "wait_init_reply") then return; end
	if (GetTime() >= state.deadline) then UnBotGroundChest.Tick(); return; end
	local text = tostring(message or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "");
	local lower = string.lower(text);
	local name, result = lower:match("init:%s*([^%s]+)%s*%-%s*(.+)");
	if (name and UnBotAccountAlts.SenderKey(name) == UnBotAccountAlts.SenderKey(state.currentName)) then
		if (result == "ok" or result:match("^ok%s*%(") or result:match("^ok%s*$")) then
			-- 'ok (queued)' acknowledges acceptance, not completed initialization.
			state.initAccepted = true;
			state.stage = "wait_init_settle";
			state.deadline = GetTime() + 9;
			UnBotGroundChest.SetStatus("Сервер принял init для "..state.currentName..". Ждём 9 секунд, затем проверим who и прибытие.", true);
		else
			UnBotGroundChest.Stop("Сервер отклонил init: "..text..". Повторных попыток не будет.");
		end
	elseif (lower:find("usage:", 1, true) and lower:find("add/init/remove", 1, true)) then
		UnBotGroundChest.Stop("Сервер не принял синтаксис init. Помощь остановлена без повторов.");
	end
end

function UnBotGroundChest.PositionCurrent()
	local state = UnBotGroundChest;
	state.stage = "wait_arrival";
	state.deadline = GetTime() + 30;
	state.arrivalAttempts = 0;
	state.whoReceived = false;
	state.whoZone = nil;
	state.whoWaitUntil = GetTime() + 3;
	state.nextSummonAt = state.whoWaitUntil;
	state.nextWhoAt = nil;
	UnBotGroundChest.SendWhisper(state.currentName, "who");
	UnBotGroundChest.SetStatus("Проверяем, где находится "..tostring(state.currentName)..". Ожидание вскрытия начнётся только после прибытия к вам.", true);
end

function UnBotGroundChest.IsNearby()
	local name = UnBotGroundChest.currentName;
	local unit = name and UnBotSquadRosterFindUnit and UnBotSquadRosterFindUnit(name);
	if (not unit or not UnBotGroundChest.IsOnline(name)) then return false; end
	if (not UnitIsVisible or not UnitIsVisible(unit)) then return false; end
	-- A zone name alone cannot distinguish two copies of the same dungeon.
	return CheckInteractDistance and CheckInteractDistance(unit, 1) and true or false;
end

function UnBotGroundChest.RestoreDebug()
	local state = UnBotGroundChest;
	state.debugQuery = nil;
	if (state.debugOwned and UnBotGroundChest.IsOnline(state.debugOwned)) then
		UnBotGroundChest.SendWhisper(state.debugOwned, "nc -debug spell");
	end
	state.debugOwned = nil;
end

function UnBotGroundChest.OnDebug(message, sender)
	local state = UnBotGroundChest;
	if (not state.active or not state.currentName) then return; end
	if (UnBotAccountAlts.SenderKey(sender) ~= UnBotAccountAlts.SenderKey(state.currentName)) then return; end
	local text = tostring(message or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "");
	local now = GetTime();
	local q = state.debugQuery;
	local list = text:match("^[Ss]trategies:%s*(.*)$");
	if (q and now < q.deadline and list and UnBotGroundChest.IsOnline(q.name)) then
		state.debugQuery = nil;
		local enabled = false;
		for token in list:gmatch("([^,]+)") do
			if (token:match("^%s*(.-)%s*$") == "debug spell") then enabled = true; end
		end
		if (not enabled) then
			state.debugOwned = q.name;
			UnBotGroundChest.SendWhisper(q.name, "nc +debug spell");
		end
		UnBotGroundChest.Message("Диагностика заклинаний включена для "..q.name..". Ошибки — во вкладке UnBot Debug.");
		return;
	end
	if (state.stage ~= "watch_chest") then return; end
	if (not UnBotGroundChest.IsNearby()) then return; end
	local lower = string.lower(text);
	if (lower:find("unknown spell", 1, true) or lower:find("cannot cast", 1, true)
		or lower:find("no items", 1, true) or lower:find("level is too low", 1, true)) then
		state.currentAdded = true;
		UnBotGroundChest.Stop("Разбойник сообщил об отказе: "..text..". Отключаем помощника без повторного init; место в группе сохраняется.");
		return;
	end
	if (lower:find("pick lock", 1, true) and lower:find("casting", 1, true)) then state.herbFailure = nil; return; end
	if (not lower:find("spell cast failed", 1, true)) then return; end
	local spell = tonumber(lower:match("spell id:%s*(%d+)"));
	if (spell ~= 32605 or not lower:find("gameobject", 1, true)) then return; end
	local low = lower:match("low guid:%s*(%d+)");
	local high = lower:match("high guid:%s*(%d+)");
	if (not low or not high) then return; end
	local key = low..":"..high;
	local previous = state.herbFailure;
	if (not previous or previous.key ~= key or now-previous.at > 10) then
		state.herbFailure = {key=key, at=now}; return;
	end
	if (now-previous.at < 0.5) then return; end
	state.herbFailure = nil;
	state.tried[state.currentName] = true;
	-- Stop the faulty server loop, preserving its offline roster slot.
	state.currentAdded = true;
	UnBotGroundChest.Stop(state.currentName..": сбор трав повторяется после init. Обход не помог; отключаем разбойника без перебора других и без повторного init.");
end

function UnBotGroundChest.OnWho(message, sender)
	local state = UnBotGroundChest;
	if (not state.active or not state.currentName) then return; end
	if (UnBotAccountAlts.SenderKey(sender) ~= UnBotAccountAlts.SenderKey(state.currentName)) then return; end
	local text = tostring(message or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "");
	if (state.stage == "who_before_init" or state.stage == "who_after_init") then
		if (GetTime() >= state.deadline) then UnBotGroundChest.Tick(); return; end
		local info = UnBotParseBotWho and UnBotParseBotWho(text);
		if (not info or not info.className or not info.level) then return; end
		if (info.className ~= "rogue" or info.level < 11) then
			UnBotGroundChest.Stop("Для этого сервиса нужен подтверждённый разбойник от 11 уровня. Переинициализация прекращена.");
			return;
		end
		if (state.stage == "who_before_init") then
			state.beforeWho = text;
			UnBotGroundChest.BeginInit();
		else
			state.afterWho = text;
			state.debugQuery = {name=state.currentName, deadline=GetTime()+6};
			UnBotGroundChest.SendWhisper(state.currentName, "nc ?");
			UnBotGroundChest.Message("Получен who после init: "..text..". Специализация для вскрытия не отбирается.");
			UnBotGroundChest.PositionCurrent();
		end
		return;
	end
	if (state.stage ~= "wait_arrival") then return; end
	local zone = text:match("%(([^()]*)%)%s*,%s*[Pp]laying with");
	if (not zone) then return; end
	state.whoReceived = true;
	state.whoZone = zone;
	UnBotGroundChest.SetStatus("Ответ "..state.currentName..": "..zone..". Проверяем, появился ли разбойник рядом с вами.", true);
end

function UnBotGroundChest.TickArrival(now)
	local state = UnBotGroundChest;
	if (UnBotGroundChest.IsNearby() and (state.whoReceived or now >= state.whoWaitUntil)) then
		UnBotGroundChest.SetStatus("Разбойник рядом с вами. Начинаем ожидание вскрытия.", true);
		UnBotGroundChest.StartWatching();
		return;
	end
	if (now >= state.deadline) then
		UnBotGroundChest.Stop("Разбойник не появился рядом за 30 секунд после проверки местоположения. Попытки телепортации прекращены.");
		return;
	end
	if (not UnBotGroundChest.IsOnline(state.currentName)) then return; end
	if (state.nextWhoAt and now >= state.nextWhoAt) then
		state.nextWhoAt = nil;
		UnBotGroundChest.SendWhisper(state.currentName, "who");
	end
	if (now >= state.nextSummonAt and state.arrivalAttempts < 3) then
		state.arrivalAttempts = state.arrivalAttempts + 1;
		state.nextSummonAt = now + 8;
		state.nextWhoAt = now + 2;
		UnBotGroundChest.SendWhisper(state.currentName, "summon");
		UnBotGroundChest.SendWhisper(state.currentName, "follow");
		UnBotGroundChest.SetStatus("Подзываем "..state.currentName.." к вам: попытка "..state.arrivalAttempts.."/3. Ждём появления рядом.", true);
	end
end

function UnBotGroundChest.StartWatching()
	local state = UnBotGroundChest;
	local name = state.currentName;
	if (not name) then
		return;
	end
	UnBotGroundChest.SendWhisper(name, "follow");
	state.stage = "watch_chest";
	state.deadline = GetTime() + 60;
	state.herbFailure = nil;
	UnBotGroundChest.SetStatus(name.." рядом после init. На вскрытие — 60 секунд. Заберите добычу и нажмите «Остановить». Открытие проверьте сами; после офлайн эффект init может пропасть.", true);
end

function UnBotGroundChest.BeginOffline(nextStage)
	local state = UnBotGroundChest;
	local name = state.currentName;
	UnBotGroundChest.RestoreDebug();
	if (not name or not state.currentAdded or not UnBotGroundChest.IsOnline(name)) then
		state.currentName = nil;
		state.currentAdded = false;
		if (nextStage == "fallback") then
			UnBotGroundChest.BeginFallback("предыдущая попытка завершена");
		else
			UnBotGroundChest.FinalizeStop(state.stopReason or "Сеанс наземного сундука остановлен.");
		end
		return;
	end
	state.stage = nextStage == "fallback" and "rotate_offline" or "stop_offline";
	state.offlineNext = nextStage;
	state.offlineAttempts = 1;
	state.nextActionAt = GetTime() + 3;
	state.deadline = GetTime() + 8;
	UnBotGroundChest.SendSay(".playerbot bot remove "..name);
	UnBotGroundChest.SetStatus(
		"Временный разбойник "..name.." отключается, но остаётся в списке группы.",
		true
	);
end

function UnBotGroundChest.FinalizeStop(text)
	local state = UnBotGroundChest;
	UnBotGroundChest.RestoreDebug();
	state.active = false;
	state.stage = "idle";
	state.currentName = nil;
	state.currentAdded = false;
	state.pendingName = nil;
	state.pendingKind = nil;
	state.inviteSent = false;
	state.deadline = 0;
	state.nextActionAt = 0;
	UnBotGroundChest.SetStatus(text or "Сеанс наземного сундука остановлен.", true);
end

function UnBotGroundChest.Stop(reason)
	local state = UnBotGroundChest;
	if (not state.active) then
		return;
	end
	if (state.stage == "stop_offline") then return; end
	state.stopReason = reason or "Помощь со вскрытием остановлена игроком.";
	UnBotGroundChest.SetStatus(state.stopReason, true);
	if (state.pendingName and not UnBotGroundChest.IsOnline(state.pendingName)) then
		UnBotGroundChest.MarkLateCleanup(state.pendingName);
	end
	if (state.currentName and state.currentAdded) then
		UnBotGroundChest.BeginOffline("stop");
		return;
	end
	if (state.currentName and not state.currentAdded) then
		UnBotGroundChest.SendWhisper(state.currentName, "stay");
	end
	UnBotGroundChest.FinalizeStop(
		tostring(reason or "Сеанс наземного сундука остановлен игроком.")
		.." Участники, которые были с вами до начала, остаются в группе."
	);
end

function UnBotGroundChest.Start()
	local state = UnBotGroundChest;
	if (state.active) then
		UnBotGroundChest.SetStatus("Сеанс уже выполняется. Для завершения нажмите «Остановить».", true);
		return;
	end
	if (UnBotGroundChest.HasLateCleanup()) then
		UnBotGroundChest.SetStatus("Ещё завершаем предыдущую попытку. Подождите до 20 секунд.", true);
		return;
	end
	if ((InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player"))) then
		UnBotGroundChest.SetStatus("Наземный сундук: запуск в бою запрещён.", true);
		return;
	end
	if (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) then
		UnBotGroundChest.SetStatus("Наземный сундук: сначала воскресните.", true);
		return;
	end
	if (UnitLevel and (UnitLevel("player") or 0) < 11) then
		UnBotGroundChest.SetStatus("Наземный сундук: переинициализация доступна с 11 уровня игрока.", true);
		return;
	end
	if (UnBotGroundChest.OtherAutomationActive()) then
		UnBotGroundChest.SetStatus("Сначала завершите другое действие UnBot: призыв, усиление или обслуживание ботов.", true);
		return;
	end
	state.active = true;
	state.stopReason = nil;
	state.stage = "start";
	state.fallbackCount = 0;
	state.initCount = 0;
	state.tried = {};
	state.currentName = nil;
	state.currentAdded = false;
	state.pendingName = nil;
	state.pendingKind = nil;
	state.deadline = 0;
	state.nextActionAt = 0;
	UnBotGroundChest.BeginFallback("выбираем первого доступного дикого разбойника из реестра");
end

function UnBotGroundChest.TickLateCleanup(now)
	for name, expiresAt in pairs(UnBotGroundChest.lateCleanup or {}) do
		if (UnBotGroundChest.IsOnline(name)) then
			UnBotGroundChest.SendSay(".playerbot bot remove "..name);
			UnBotGroundChest.lateCleanup[name] = nil;
			UnBotGroundChest.Message(
				"Наземный сундук: запоздавший временный разбойник "..name
				.." отключён и оставлен в списке группы."
			);
		elseif (now >= (expiresAt or 0)) then
			UnBotGroundChest.lateCleanup[name] = nil;
		end
	end
end

function UnBotGroundChest.Tick()
	local state = UnBotGroundChest;
	local now = GetTime();
	if (state.debugQuery and now >= state.debugQuery.deadline) then
		state.debugQuery = nil;
		UnBotGroundChest.Message("Не получен ответ о настройках диагностики. Автовключение пропущено; уже приходящие ошибки всё равно отслеживаются.");
	end
	UnBotGroundChest.TickLateCleanup(now);
	if (not state.active) then
		UnBotGroundChest.Refresh();
		return;
	end
	if (
		state.stage ~= "stop_offline"
		and state.stage ~= "rotate_offline"
		and ((InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player")))
	) then
		UnBotGroundChest.Stop("Наземный сундук: начался бой, сеанс остановлен.");
		return;
	end
	if (state.stage ~= "stop_offline" and state.stage ~= "rotate_offline") then
		local unit = state.currentName and UnBotSquadRosterFindUnit and UnBotSquadRosterFindUnit(state.currentName);
		if (UnitIsDeadOrGhost and (UnitIsDeadOrGhost("player") or (unit and UnitIsDeadOrGhost(unit)))) then
			UnBotGroundChest.Stop("Игрок или разбойник погиб. Помощь со вскрытием остановлена.");
			return;
		end
	end
	if (state.stage == "add_candidate") then
		local name = state.pendingName;
		if (UnBotGroundChest.IsOnline(name)) then
			UnBotGroundChest.RogueReady(name, not state.pendingWasOnline, state.pendingKind);
			return;
		end
		if (now >= (state.deadline or 0)) then
			UnBotGroundChest.MarkLateCleanup(name);
			UnBotGroundChest.BeginFallback(name.." не появился в вашей группе за 15 секунд");
			return;
		end
		if (now >= (state.nextActionAt or 0)) then
			state.addAttempts = (state.addAttempts or 0) + 1;
			if (state.addAttempts == 1) then
				UnBotGroundChest.SendSay(".playerbot bot add "..name);
			end
			if (
				not state.inviteSent
				and UnBotGroundChestIsInGroup
				and not UnBotGroundChestIsInGroup(name)
				and InviteUnit
			) then
				pcall(InviteUnit, name);
				state.inviteSent = true;
			end
			state.nextActionAt = now + 2;
		end
		return;
	end
	if (state.stage == "wait_poison") then
		if (not UnBotGroundChest.IsOnline(state.currentName)) then
			UnBotGroundChest.Stop(tostring(state.currentName).." отключился. Запустите сервис заново после подключения.");
		elseif (now >= (state.deadline or 0)) then
			UnBotGroundChest.QueryBeforeInit();
		end
		return;
	end
	if (state.currentName and state.stage ~= "stop_offline" and state.stage ~= "rotate_offline"
		and not UnBotGroundChest.IsOnline(state.currentName)) then
		UnBotGroundChest.Stop("Разбойник перешёл офлайн. Эффект init больше не считается действующим; для следующего сундука запустите сервис заново.");
		return;
	end
	if (state.stage == "who_before_init" or state.stage == "who_after_init" or state.stage == "wait_init_reply") then
		if (now >= state.deadline) then
			UnBotGroundChest.Stop(state.stage == "wait_init_reply"
				and "Нет подтверждения init за 10 секунд. Команда могла остаться в очереди; повторять её не будем."
				or "Нет корректного who за 8 секунд. Подготовка прекращена без повторного init.");
		end
		return;
	end
	if (state.stage == "wait_init_settle") then
		if (now >= state.deadline) then
			state.stage = "who_after_init";
			state.deadline = now + 8;
			UnBotGroundChest.SendWhisper(state.currentName, "who");
			UnBotGroundChest.SetStatus("Запрошен who после init. Ждём ответ разбойника.", true);
		end
		return;
	end
	if (state.stage == "wait_arrival") then
		UnBotGroundChest.TickArrival(now);
		return;
	end
	if (state.stage == "watch_chest") then
		if (now >= (state.deadline or 0)) then
			UnBotGroundChest.Stop("60 секунд ожидания истекли. Проверьте сундук; повторного init и перебора разбойников не будет.");
		end
		return;
	end
	if (state.stage == "rotate_offline" or state.stage == "stop_offline") then
		local name = state.currentName;
		if (not UnBotGroundChest.IsOnline(name)) then
			state.currentName = nil;
			state.currentAdded = false;
			if (state.stage == "rotate_offline") then
				UnBotGroundChest.BeginFallback("предыдущему разбойнику не хватило 30 секунд");
			else
				UnBotGroundChest.FinalizeStop(tostring(state.stopReason or "Помощь завершена.").." Приглашённый разбойник отключён и остаётся в списке группы.");
			end
		elseif (now >= (state.deadline or 0)) then
			UnBotGroundChest.FinalizeStop(
				"Не удалось подтвердить отключение разбойника "..tostring(name)
				.." за 8 секунд. Попытки прекращены; проверьте его состояние в группе."
			);
		elseif (now >= (state.nextActionAt or 0) and (state.offlineAttempts or 0) < 2) then
			state.offlineAttempts = (state.offlineAttempts or 0) + 1;
			state.nextActionAt = math.huge;
			UnBotGroundChest.SendSay(".playerbot bot remove "..name);
		end
	end
end

function UnBotGroundChest.CreateFrame()
	if (UnBotGroundChest.frame) then return UnBotGroundChest.frame; end
	local frame = UnBotServiceUI.Window("UnBotGroundChestWindow", "Сундук на земле — помощь со вскрытием", 760);
	local intro = UnBotServiceUI.Text(frame, 19, 948,
		"1. Встаньте рядом с запертым сундуком вне боя и нажмите «Начать вскрытие».\n2. UnBot выберет доступного дикого разбойника из реестра, проверит who и выполнит один init. Если кандидат не подключится, будет проверен следующий — максимум шесть имён. После init UnBot снова проверит who и подзовёт бота к вам.");
	intro:SetPoint("TOPLEFT", frame, "TOPLEFT", 36, -70);
	local warning = UnBotServiceUI.Text(frame, 19, 948,
		"Серверный сбой: разбойники всех трёх специализаций могут выбирать сбор трав вместо взлома. В наших тестах init помогал, но после офлайн -> онлайн ошибка вернулась. Точная причина неизвестна.\nВнимание: init может изменить уровень, экипировку, навыки и специализацию бота. Это временный обход, а не исправление сервера; альты аккаунта исключены.");
	warning:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -20);
	warning:SetTextColor(1, 0.78, 0.35);
	local safety = UnBotServiceUI.Text(frame, 17, 948,
		"3. На вскрытие даётся 60 секунд. Заберите добычу и нажмите «Остановить»: открытие проверяете вы. Повторный сбор трав после init завершит попытку и отключит бота, сохранив место в группе.\nПосле переподключения запустите сервис заново. Логи — в UnBot Debug. Скрытие окна не останавливает сеанс. Нехватку навыка init не гарантирует исправить.");
	safety:SetPoint("TOPLEFT", warning, "BOTTOMLEFT", 0, -18);
	local box = UnBotServiceUI.Panel(frame, 956, 214);
	box:SetPoint("TOPLEFT", frame, "TOPLEFT", 32, -452);
	frame.currentText = UnBotServiceUI.Text(box, 22, 908);
	frame.currentText:SetPoint("TOPLEFT", box, "TOPLEFT", 22, -18);
	frame.currentText:SetTextColor(1, 0.82, 0);
	frame.phaseText = UnBotServiceUI.Text(box, 18, 908);
	frame.phaseText:SetPoint("TOPLEFT", frame.currentText, "BOTTOMLEFT", 0, -14);
	frame.timerText = UnBotServiceUI.Text(box, 18, 500);
	frame.timerText:SetPoint("TOPLEFT", frame.phaseText, "BOTTOMLEFT", 0, -14);
	frame.counterText = UnBotServiceUI.Text(box, 18, 355);
	frame.counterText:SetPoint("TOPRIGHT", frame.timerText, "TOPRIGHT", 408, 0);
	frame.statusText = UnBotServiceUI.Text(box, 18, 908);
	frame.statusText:SetPoint("TOPLEFT", frame.timerText, "BOTTOMLEFT", 0, -18);
	frame.statusText:SetTextColor(0.35, 0.95, 1);
	frame.startButton = UnBotServiceUI.Button(frame, 340, "Начать вскрытие", function() UnBotGroundChest.Start(); end);
	frame.startButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 112, 34);
	frame.stopButton = UnBotServiceUI.Button(frame, 340, "Остановить", function() UnBotGroundChest.Stop("Помощь со вскрытием остановлена игроком."); end);
	frame.stopButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -112, 34);
	frame:SetScript("OnShow", function() UnBotGroundChest.Refresh(); end);
	UnBotGroundChest.frame = frame;
	UnBotGroundChest.Refresh();
	return frame;
end

function UnBotGroundChest.Open()
	local frame = UnBotGroundChest.CreateFrame();
	frame:Show();
	UnBotGroundChest.Refresh();
end

function UnBotGroundChestOpen()
	UnBotGroundChest.Open();
end

UnBotGroundChestDriver = UnBotGroundChestDriver
	or CreateFrame("Frame", "UnBotGroundChestDriver");
UnBotGroundChestDriver:RegisterEvent("CHAT_MSG_WHISPER");
UnBotGroundChestDriver:RegisterEvent("CHAT_MSG_SYSTEM");
UnBotGroundChestDriver:RegisterEvent("PARTY_MEMBERS_CHANGED");
UnBotGroundChestDriver:RegisterEvent("RAID_ROSTER_UPDATE");
UnBotGroundChestDriver:SetScript("OnEvent", function(self, event, message, sender)
	if (event == "CHAT_MSG_SYSTEM") then UnBotGroundChest.OnSystem(message); return; end
	if (event ~= "CHAT_MSG_WHISPER") then UnBotGroundChest.Tick(); return; end
	UnBotGroundChest.OnWho(message, sender);
	UnBotGroundChest.OnDebug(message, sender);
end);
UnBotGroundChestDriver:SetScript("OnUpdate", function(self, elapsed)
	UnBotGroundChest.refreshElapsed = (UnBotGroundChest.refreshElapsed or 0) + elapsed;
	if (UnBotGroundChest.refreshElapsed >= 0.2) then
		UnBotGroundChest.refreshElapsed = 0;
		UnBotGroundChest.Tick();
	end
end);

SLASH_UNBOTGROUNDCHEST1 = "/ubgroundchest";
SlashCmdList["UNBOTGROUNDCHEST"] = function()
	UnBotGroundChest.Open();
end
