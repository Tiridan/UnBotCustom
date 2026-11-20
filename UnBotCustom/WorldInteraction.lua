-- Friendly UI for the Playerbot "los gos" -> "u N" workflow.
-- The server remains the source of truth: the list is built only from the
-- selected online bot's current whisper response.

UnBotWorldInteraction = UnBotWorldInteraction or {
	botName = nil,
	bots = {},
	objects = {},
	mode = nil,
	requestStartedAt = 0,
	hardDeadline = 0,
	quietDeadline = 0,
	gotReply = false,
	selectedIndex = nil,
	selectedLabel = nil,
	nextAutoScanAt = 0,
	homePending = {},
	homeExpected = 0,
	homeConfirmed = 0,
	homeFailed = 0,
	homeDeadline = 0,
	homeInnName = nil,
	taxiPending = {},
	taxiExpected = 0,
	taxiConfirmed = 0,
	taxiFailed = 0,
	taxiDeadline = 0,
	taxiMasterName = nil,
	autoRogueAttempted = false,
	autoRogueDeadline = 0,
};

function UnBotWorldInteraction.Message(text)
	text = tostring(text or "");
	if (UnBotSpecSummonMessage) then
		UnBotSpecSummonMessage(text);
	elseif (DEFAULT_CHAT_FRAME) then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00d9ffUnBot:|r "..text);
	end
end

function UnBotWorldInteraction.Trim(text)
	text = tostring(text or "");
	text = string.gsub(text, "^%s+", "");
	text = string.gsub(text, "%s+$", "");
	return text;
end

function UnBotWorldInteraction.NameKey(name)
	name = UnBotWorldInteraction.Trim(name);
	name = string.gsub(name, "%-[^%-]+$", "");
	if (UnBotAccountAlts and UnBotAccountAlts.Key) then
		return UnBotAccountAlts.Key(name);
	end
	return string.lower(name);
end

function UnBotWorldInteraction.SameName(a, b)
	return UnBotWorldInteraction.NameKey(a) == UnBotWorldInteraction.NameKey(b);
end

function UnBotWorldInteraction.IsAccountAlt(name)
	local profile = UnBotBotRegistry and UnBotBotRegistry.bots
		and UnBotBotRegistry.bots[name];
	if (UnBotIsAccountAltProfile) then
		return UnBotIsAccountAltProfile(name, profile) and true or false;
	end
	return (
		UnBotAccountAlts
		and UnBotAccountAlts.IsKnown
		and UnBotAccountAlts.IsKnown(name)
	) and true or false;
end

function UnBotWorldInteraction.HomePendingCount()
	local count = 0;
	for _ in pairs(UnBotWorldInteraction.homePending or {}) do
		count = count + 1;
	end
	return count;
end

function UnBotWorldInteraction.FinishHomeBinding(timedOut)
	local state = UnBotWorldInteraction;
	local missing = UnBotWorldInteraction.HomePendingCount();
	state.mode = nil;
	state.homePending = {};
	UnBotWorldInteraction.SetStatus(
		"Гостиница «"..tostring(state.homeInnName or "?").."»: подтверждено "
		..tostring(state.homeConfirmed or 0).."/"..tostring(state.homeExpected or 0)
		..((state.homeFailed or 0) > 0
			and (", отказов "..tostring(state.homeFailed)) or "")
		..(timedOut and missing > 0
			and (", без ответа "..tostring(missing)..". Команда не повторялась.")
			or "."),
		(state.homeConfirmed or 0) < (state.homeExpected or 0)
	);
end

function UnBotWorldInteraction.TaxiPendingCount()
	local count = 0;
	for _ in pairs(UnBotWorldInteraction.taxiPending or {}) do
		count = count + 1;
	end
	return count;
end

function UnBotWorldInteraction.FinishTaxiOpening()
	local state = UnBotWorldInteraction;
	local silent = UnBotWorldInteraction.TaxiPendingCount();
	state.mode = nil;
	state.taxiPending = {};
	UnBotWorldInteraction.SetStatus(
		"Полётный узел у «"..tostring(state.taxiMasterName or "?").."»: отправлено "
		..tostring(state.taxiExpected or 0)
		..", подтверждено "..tostring(state.taxiConfirmed or 0)
		..", отказов "..tostring(state.taxiFailed or 0)
		..", без ответа "..tostring(silent)
		..". Для taxi молчание допустимо; команды не повторялись.",
		(state.taxiFailed or 0) > 0
	);
end

function UnBotWorldInteraction.IsKnownBot(name)
	if (not name or not UnBotBotRegistry or not UnBotBotRegistry.bots) then
		return false;
	end
	if (UnBotBotRegistry.bots[name]) then
		return true;
	end
	for savedName in pairs(UnBotBotRegistry.bots) do
		if (UnBotWorldInteraction.SameName(savedName, name)) then
			return true;
		end
	end
	return false;
end

function UnBotWorldInteraction.AddRosterBot(name, unit, seen)
	if (
		name
		and name ~= UNKNOWNOBJECT
		and name ~= UNKNOWN
		and not UnBotWorldInteraction.SameName(name, UnitName("player"))
		and unit
		and UnitIsConnected(unit)
		and UnBotWorldInteraction.IsKnownBot(name)
	) then
		local key = UnBotWorldInteraction.NameKey(name);
		if (not seen[key]) then
			seen[key] = true;
			table.insert(UnBotWorldInteraction.bots, name);
		end
	end
end

function UnBotWorldInteraction.BuildBotList()
	local state = UnBotWorldInteraction;
	local seen = {};
	state.bots = {};
	if (GetNumRaidMembers and GetNumRaidMembers() > 0) then
		for index = 1, GetNumRaidMembers() do
			local unit = "raid"..index;
			local name = GetRaidRosterInfo(index);
			if (not name or name == UNKNOWNOBJECT or name == UNKNOWN) then
				name = UnitName(unit);
			end
			UnBotWorldInteraction.AddRosterBot(name, unit, seen);
		end
	else
		for index = 1, (GetNumPartyMembers and GetNumPartyMembers() or 0) do
			local unit = "party"..index;
			UnBotWorldInteraction.AddRosterBot(UnitName(unit), unit, seen);
		end
	end
	table.sort(state.bots, function(a, b)
		return UnBotWorldInteraction.NameKey(a) < UnBotWorldInteraction.NameKey(b);
	end);
	return state.bots;
end

function UnBotWorldInteraction.FindBot(name)
	for _, botName in ipairs(UnBotWorldInteraction.bots or {}) do
		if (UnBotWorldInteraction.SameName(botName, name)) then
			return botName;
		end
	end
	return nil;
end

function UnBotWorldInteraction.SetStatus(text, red)
	local frame = UnBotWorldInteraction.frame;
	if (not frame or not frame.status) then
		return;
	end
	frame.status:SetText(tostring(text or ""));
	if (red) then
		frame.status:SetTextColor(1, 0.35, 0.25);
	else
		frame.status:SetTextColor(0.75, 0.9, 1);
	end
end

function UnBotWorldInteraction.RefreshBotButton(preferTarget)
	local state = UnBotWorldInteraction;
	UnBotWorldInteraction.BuildBotList();
	local selected = UnBotWorldInteraction.FindBot(state.botName);
	if (preferTarget and UnitExists("target")) then
		selected = UnBotWorldInteraction.FindBot(UnitName("target")) or selected;
	end
	selected = selected or state.bots[1];
	state.botName = selected;
	if (state.frame and state.frame.botButton) then
		state.frame.botButton:SetText(selected and ("Бот: "..selected.."  v") or "Бот: не выбран  v");
	end
	if (not selected) then
		UnBotWorldInteraction.SetStatus(
			"Нет доступных онлайн-ботов из реестра. Сначала добавьте бота в текущую группу.",
			true
		);
	end
end

function UnBotWorldInteraction.StartAutomaticRogue()
	local state = UnBotWorldInteraction;
	if (state.autoRogueAttempted) then
		return;
	end
	state.autoRogueAttempted = true;
	state.autoRogueDeadline = GetTime() + 20;
	UnBotWorldInteraction.SetStatus(
		"В группе нет доступного бота LOS. Призываю разбойника из реестра...",
		false
	);
	if (not UnBotSpecSummonStart) then
		state.autoRogueDeadline = 0;
		UnBotWorldInteraction.SetStatus(
			"Автоматический призыв разбойника недоступен: модуль призыва не загружен.",
			true
		);
		return;
	end
	local started = UnBotSpecSummonStart(
		"rogue combat",
		function(name)
			state.autoRogueDeadline = 0;
			state.botName = name;
			UnBotWorldInteraction.RefreshBotButton(false);
			if (state.frame and state.frame:IsShown() and state.mode ~= "scan") then
				UnBotWorldInteraction.Scan();
			end
		end,
		"world-los"
	);
	if (not started) then
		state.autoRogueDeadline = 0;
	end
end

function UnBotWorldInteraction.SelectBot(name)
	local state = UnBotWorldInteraction;
	state.botName = UnBotWorldInteraction.FindBot(name);
	state.objects = {};
	state.mode = nil;
	state.selectedIndex = nil;
	state.selectedLabel = nil;
	state.nextAutoScanAt = 0;
	UnBotWorldInteraction.RefreshBotButton(false);
	UnBotWorldInteraction.RefreshRows();
	if (state.botName) then
		UnBotWorldInteraction.Scan();
	end
end

function UnBotWorldInteraction.OpenBotMenu(anchor)
	UnBotWorldInteraction.RefreshBotButton(false);
	local menu = {
		{ text = "Выберите онлайн-бота", isTitle = true, notCheckable = true },
	};
	for _, botName in ipairs(UnBotWorldInteraction.bots) do
		local name = botName;
		table.insert(menu, {
			text = name,
			notCheckable = true,
			func = function() UnBotWorldInteraction.SelectBot(name); end,
		});
	end
	if (#UnBotWorldInteraction.bots == 0) then
		table.insert(menu, { text = "Нет доступных ботов", isTitle = true, notCheckable = true });
	end
	EasyMenu(UnBotLocale.Menu(menu), UnBotWorldInteraction.menuFrame, anchor, 0, 0, "MENU", 2);
end

function UnBotWorldInteraction.CleanObjectLabel(label, index)
	label = tostring(label or "");
	label = string.gsub(label, "^[%s:=%-,;]+", "");
	label = string.gsub(label, "[%s,;]+$", "");
	if (label == "") then
		label = "Объект "..tostring(index);
	end
	return label;
end

function UnBotWorldInteraction.AddObject(index, label)
	index = tonumber(index);
	if (not index) then
		return false;
	end
	label = UnBotWorldInteraction.CleanObjectLabel(label, index);
	for _, item in ipairs(UnBotWorldInteraction.objects) do
		if (item.index == index) then
			item.label = label;
			return false;
		end
	end
	table.insert(UnBotWorldInteraction.objects, { index = index, label = label });
	return true;
end

function UnBotWorldInteraction.ParseObjectReply(message)
	message = tostring(message or "");
	local cursor = 1;
	local added = 0;
	while (true) do
		local startAt, endAt, index = string.find(message, "%[(%d+)%]", cursor);
		if (not startAt) then
			break
		end
		local nextAt = string.find(message, "%[%d+%]", endAt + 1);
		local label = string.sub(message, endAt + 1, nextAt and (nextAt - 1) or string.len(message));
		if (UnBotWorldInteraction.AddObject(index, label)) then
			added = added + 1;
		end
		cursor = endAt + 1;
	end
	return added;
end

function UnBotWorldInteraction.RefreshRows()
	local state = UnBotWorldInteraction;
	local frame = state.frame;
	if (not frame or not frame.rows) then
		return;
	end
	local count = #state.objects;
	FauxScrollFrame_Update(frame.scroll, count, #frame.rows, 30);
	local offset = FauxScrollFrame_GetOffset(frame.scroll);
	for rowIndex, row in ipairs(frame.rows) do
		local item = state.objects[offset + rowIndex];
		if (item) then
			row.objectIndex = item.index;
			row.objectLabel = item.label;
			row.text:SetText("["..tostring(item.index).."]  "..tostring(item.label));
			row:Show();
		else
			row.objectIndex = nil;
			row.objectLabel = nil;
			row:Hide();
		end
	end
	if (frame.emptyText) then
		if (count == 0) then
			frame.emptyText:Show();
		else
			frame.emptyText:Hide();
		end
	end
end

function UnBotWorldInteraction.Scan()
	local state = UnBotWorldInteraction;
	UnBotWorldInteraction.RefreshBotButton(false);
	local botName = UnBotWorldInteraction.FindBot(state.botName);
	if (not botName) then
		UnBotWorldInteraction.SetStatus("Выберите доступного онлайн-бота.", true);
		return;
	end
	state.botName = botName;
	state.objects = {};
	state.selectedIndex = nil;
	state.selectedLabel = nil;
	state.mode = "scan";
	state.requestStartedAt = GetTime();
	state.hardDeadline = state.requestStartedAt + 6;
	state.quietDeadline = state.hardDeadline;
	state.nextAutoScanAt = state.requestStartedAt + 6;
	state.gotReply = false;
	UnBotWorldInteraction.RefreshRows();
	SendChatMessage("los gos", "WHISPER", nil, botName);
	UnBotWorldInteraction.SetStatus(
		"Запрос отправлен "..botName..". Жду список объектов (до 6 секунд)...",
		false
	);
end

function UnBotWorldInteraction.UseObject(index, label)
	local state = UnBotWorldInteraction;
	local botName = UnBotWorldInteraction.FindBot(state.botName);
	index = tonumber(index);
	if (not botName or not index) then
		UnBotWorldInteraction.SetStatus("Бот или объект больше недоступен. Обновите список.", true);
		return;
	end
	state.botName = botName;
	state.mode = "use";
	state.selectedIndex = index;
	state.selectedLabel = UnBotWorldInteraction.CleanObjectLabel(label, index);
	state.hardDeadline = GetTime() + 5;
	state.nextAutoScanAt = state.hardDeadline + 1;
	state.gotReply = false;
	SendChatMessage("u "..tostring(index), "WHISPER", nil, botName);
	UnBotWorldInteraction.SetStatus(
		"Команда отправлена: "..botName.." использует ["..tostring(index).."] "..tostring(label or "объект")..".",
		false
	);
end

function UnBotWorldInteraction.BindAccountAltsHome()
	local state = UnBotWorldInteraction;
	if (UnitAffectingCombat and UnitAffectingCombat("player")) then
		UnBotWorldInteraction.SetStatus("Привязка к гостинице недоступна в бою.", true);
		return;
	end
	if (
		not UnitExists("target")
		or (UnitIsPlayer and UnitIsPlayer("target"))
		or (UnitIsFriend and not UnitIsFriend("player", "target"))
		or (UnitIsDeadOrGhost and UnitIsDeadOrGhost("target"))
	) then
		UnBotWorldInteraction.SetStatus(
			"Выделите живого дружественного трактирщика и повторите команду.",
			true
		);
		return;
	end

	UnBotWorldInteraction.BuildBotList();
	local altNames = {};
	for _, name in ipairs(state.bots or {}) do
		if (UnBotWorldInteraction.IsAccountAlt(name)) then
			table.insert(altNames, name);
		end
	end
	if (#altNames == 0) then
		UnBotWorldInteraction.SetStatus(
			"В текущей группе нет подключённых подтверждённых альтов аккаунта.",
			true
		);
		return;
	end

	state.mode = "home";
	state.homePending = {};
	state.homeExpected = #altNames;
	state.homeConfirmed = 0;
	state.homeFailed = 0;
	state.homeDeadline = GetTime() + 8;
	state.homeInnName = UnitName("target") or "выбранный трактирщик";
	for _, name in ipairs(altNames) do
		state.homePending[UnBotWorldInteraction.NameKey(name)] = name;
		SendChatMessage("home", "WHISPER", nil, name);
	end
	UnBotWorldInteraction.SetStatus(
		"Команда home отправлена только альтам аккаунта: "..tostring(#altNames)
		..". Трактирщик: "..tostring(state.homeInnName)..". Жду подтверждение...",
		false
	);
end

function UnBotWorldInteraction.OpenAccountAltFlightNode()
	local state = UnBotWorldInteraction;
	if (UnitAffectingCombat and UnitAffectingCombat("player")) then
		UnBotWorldInteraction.SetStatus("Открытие полётного узла недоступно в бою.", true);
		return;
	end
	if (
		not UnitExists("target")
		or (UnitIsPlayer and UnitIsPlayer("target"))
		or (UnitIsFriend and not UnitIsFriend("player", "target"))
		or (UnitIsDeadOrGhost and UnitIsDeadOrGhost("target"))
	) then
		UnBotWorldInteraction.SetStatus(
			"Выделите живого дружественного распорядителя полётов и повторите команду.",
			true
		);
		return;
	end

	UnBotWorldInteraction.BuildBotList();
	local altNames = {};
	for _, name in ipairs(state.bots or {}) do
		if (UnBotWorldInteraction.IsAccountAlt(name)) then
			table.insert(altNames, name);
		end
	end
	if (#altNames == 0) then
		UnBotWorldInteraction.SetStatus(
			"В текущей группе нет подключённых подтверждённых альтов аккаунта.",
			true
		);
		return;
	end

	state.mode = "taxi";
	state.taxiPending = {};
	state.taxiExpected = #altNames;
	state.taxiConfirmed = 0;
	state.taxiFailed = 0;
	state.taxiDeadline = GetTime() + 6;
	state.taxiMasterName = UnitName("target") or "выбранный распорядитель полётов";
	for _, name in ipairs(altNames) do
		state.taxiPending[UnBotWorldInteraction.NameKey(name)] = name;
		SendChatMessage("taxi", "WHISPER", nil, name);
	end
	UnBotWorldInteraction.SetStatus(
		"Команда taxi отправлена только альтам аккаунта: "..tostring(#altNames)
		..". Распорядитель: "..tostring(state.taxiMasterName)
		..". Жду только явные ответы до 6 секунд...",
		false
	);
end

function UnBotWorldInteraction.HandleWhisper(message, sender)
	local state = UnBotWorldInteraction;
	if (state.mode == "taxi") then
		local key = UnBotWorldInteraction.NameKey(sender);
		if (not state.taxiPending[key]) then
			return;
		end
		local text = string.lower(tostring(message or ""));
		local confirmed = (
			string.find(text, "ready for the next flight", 1, true)
			or (string.find(text, "flight", 1, true) and string.find(text, "learn", 1, true))
			or (string.find(text, "пол", 1, true) and string.find(text, "откры", 1, true))
		) and true or false;
		local failed = (
			string.find(text, "cannot find any flightmaster", 1, true)
			or string.find(text, "can't fly", 1, true)
			or string.find(text, "cannot", 1, true)
			or string.find(text, "too far", 1, true)
			or string.find(text, "unknown command", 1, true)
			or string.find(text, "not supported", 1, true)
			or string.find(text, "usage", 1, true)
			or string.find(text, "не могу", 1, true)
			or string.find(text, "слишком далеко", 1, true)
			or string.find(text, "неизвестн", 1, true)
			or (string.find(text, "распорядител", 1, true) and string.find(text, "не найден", 1, true))
		) and true or false;
		if (not confirmed and not failed) then
			return;
		end
		state.taxiPending[key] = nil;
		if (confirmed) then
			state.taxiConfirmed = (state.taxiConfirmed or 0) + 1;
		else
			state.taxiFailed = (state.taxiFailed or 0) + 1;
		end
		if (UnBotWorldInteraction.TaxiPendingCount() == 0) then
			UnBotWorldInteraction.FinishTaxiOpening();
		else
			UnBotWorldInteraction.SetStatus(
				"Полётный узел: подтверждено "..tostring(state.taxiConfirmed or 0)
				..", отказов "..tostring(state.taxiFailed or 0)
				..", жду остальных...",
				(state.taxiFailed or 0) > 0
			);
		end
		return;
	end
	if (state.mode == "home") then
		local key = UnBotWorldInteraction.NameKey(sender);
		if (not state.homePending[key]) then
			return;
		end
		local text = string.lower(tostring(message or ""));
		local confirmed = (
			string.find(text, "new home", 1, true)
			or (string.find(text, "нов", 1, true) and string.find(text, "дом", 1, true))
		) and true or false;
		local failed = (
			string.find(text, "cannot", 1, true)
			or string.find(text, "can't", 1, true)
			or string.find(text, "not an inn", 1, true)
			or string.find(text, "no inn", 1, true)
			or string.find(text, "too far", 1, true)
			or string.find(text, "не могу", 1, true)
			or string.find(text, "не трактир", 1, true)
		) and true or false;
		if (not confirmed and not failed) then
			return;
		end
		state.homePending[key] = nil;
		if (confirmed) then
			state.homeConfirmed = (state.homeConfirmed or 0) + 1;
		else
			state.homeFailed = (state.homeFailed or 0) + 1;
		end
		if (UnBotWorldInteraction.HomePendingCount() == 0) then
			UnBotWorldInteraction.FinishHomeBinding(false);
		else
			UnBotWorldInteraction.SetStatus(
				"Привязка к гостинице: подтверждено "
				..tostring(state.homeConfirmed or 0).."/"
				..tostring(state.homeExpected or 0)..", жду остальных...",
				false
			);
		end
		return;
	end
	if (not state.mode or not state.botName or not UnBotWorldInteraction.SameName(sender, state.botName)) then
		return;
	end
	local now = GetTime();
	state.gotReply = true;
	if (state.mode == "scan") then
		UnBotWorldInteraction.ParseObjectReply(message);
		state.quietDeadline = math.min(state.hardDeadline, now + 1);
		UnBotWorldInteraction.RefreshRows();
		if (#state.objects > 0) then
			UnBotWorldInteraction.SetStatus(
				"Найдено объектов: "..tostring(#state.objects)..". Нажмите нужную строку один раз.",
				false
			);
		end
	elseif (state.mode == "use") then
		local text = tostring(message or "");
		if (UnBotAccountAlts and UnBotAccountAlts.Key) then
			text = UnBotAccountAlts.Key(text);
		else
			text = string.lower(text);
		end
		if (string.find(text, "using", 1, true) or string.find(text, "использ", 1, true)) then
			state.mode = nil;
			UnBotWorldInteraction.SetStatus(
				"Бот подтвердил использование объекта: "
				..tostring(state.selectedLabel or ("["..tostring(state.selectedIndex or "?").."]"))..".",
				false
			);
		elseif (
			string.find(text, "cannot", 1, true)
			or string.find(text, "can't", 1, true)
			or string.find(text, "cooldown", 1, true)
			or string.find(text, "не могу", 1, true)
			or string.find(text, "невозможно", 1, true)
		) then
			state.mode = nil;
			UnBotWorldInteraction.SetStatus("Сервер отказал: "..tostring(message), true);
		end
	end
end

function UnBotWorldInteraction.Update()
	local state = UnBotWorldInteraction;
	local now = GetTime();
	if (state.autoRogueDeadline and state.autoRogueDeadline > 0) then
		UnBotWorldInteraction.RefreshBotButton(false);
		if (state.botName) then
			state.autoRogueDeadline = 0;
		elseif (now >= state.autoRogueDeadline) then
			state.autoRogueDeadline = 0;
			UnBotWorldInteraction.SetStatus(
				"Разбойник не вошёл в группу за 20 секунд. Проверьте ответ призыва и повторите открытие LOS.",
				true
			);
		end
	end
	if (state.mode == "scan") then
		if (state.gotReply and now >= state.quietDeadline) then
			state.mode = nil;
			if (#state.objects == 0) then
				UnBotWorldInteraction.SetStatus(
					"Бот ответил, но номера объектов не распознаны. Подойдите ближе и повторите запрос.",
					true
				);
			end
		elseif (now >= state.hardDeadline) then
			state.mode = nil;
			UnBotWorldInteraction.SetStatus(
				"Ответ на LOS не получен за 6 секунд. Проверьте расстояние до бота и повторите запрос.",
				true
			);
		end
	elseif (state.mode == "home" and now >= (state.homeDeadline or 0)) then
		UnBotWorldInteraction.FinishHomeBinding(true);
	elseif (state.mode == "taxi" and now >= (state.taxiDeadline or 0)) then
		UnBotWorldInteraction.FinishTaxiOpening();
	elseif (state.mode == "use" and now >= state.hardDeadline) then
		state.mode = nil;
		UnBotWorldInteraction.SetStatus(
			"Подтверждение не пришло за 5 секунд. Команда не повторялась; проверьте результат в мире.",
			true
		);
	end
	if (
		state.frame
		and state.frame:IsShown()
		and state.botName
		and not state.mode
		and now >= (state.nextAutoScanAt or 0)
	) then
		UnBotWorldInteraction.Scan();
	end
end

function UnBotWorldInteraction.CreateFrame()
	if (UnBotWorldInteraction.frame) then
		return UnBotWorldInteraction.frame;
	end
	local frame = CreateFrame("Frame", "UnBotWorldInteractionFrame", UIParent);
	frame:SetWidth(570);
	frame:SetHeight(470);
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40);
	frame:SetFrameStrata("DIALOG");
	frame:SetToplevel(true);
	frame:SetMovable(true);
	frame:EnableMouse(true);
	frame:RegisterForDrag("LeftButton");
	frame:SetScript("OnDragStart", function(self) self:StartMoving(); end);
	frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); end);
	frame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	});

	frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	frame.title:SetPoint("TOP", frame, "TOP", 0, -18);
	frame.title:SetText("Взаимодействие с миром (LOS)");

	frame.help = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	frame.help:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -50);
	frame.help:SetWidth(520);
	frame.help:SetJustifyH("LEFT");
	frame.help:SetText(
		"Первый бот выбирается автоматически, а список обновляется каждые 6 секунд. Нажмите нужный объект один раз."
	);

	frame.botButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
	frame.botButton:SetWidth(245);
	frame.botButton:SetHeight(25);
	frame.botButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -88);
	frame.botButton:SetText("Бот: не выбран  v");
	frame.botButton:SetScript("OnClick", function(self) UnBotWorldInteraction.OpenBotMenu(self); end);

	frame.scanButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
	frame.scanButton:SetWidth(245);
	frame.scanButton:SetHeight(25);
	frame.scanButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -88);
	frame.scanButton:SetText("Найти объекты рядом");
	frame.scanButton:SetScript("OnClick", function() UnBotWorldInteraction.Scan(); end);

	frame.listTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	frame.listTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 29, -128);
	frame.listTitle:SetText("Что использовать");

	frame.list = CreateFrame("Frame", nil, frame);
	frame.list:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -148);
	frame.list:SetWidth(510);
	frame.list:SetHeight(216);
	frame.list:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 12,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	});
	frame.list:SetBackdropColor(0.02, 0.05, 0.08, 0.92);
	frame.list:SetBackdropBorderColor(0.15, 0.65, 0.75, 0.9);

	frame.rows = {};
	for rowIndex = 1, 7 do
		local row = CreateFrame("Button", nil, frame.list);
		row:SetWidth(470);
		row:SetHeight(28);
		row:SetPoint("TOPLEFT", frame.list, "TOPLEFT", 8, -7 - ((rowIndex - 1) * 30));
		row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD");
		row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
		row.text:SetPoint("LEFT", row, "LEFT", 8, 0);
		row.text:SetWidth(448);
		row.text:SetJustifyH("LEFT");
		row:SetScript("OnClick", function(self)
			if (self.objectIndex) then
				UnBotWorldInteraction.UseObject(self.objectIndex, self.objectLabel);
			end
		end);
		frame.rows[rowIndex] = row;
	end

	frame.emptyText = frame.list:CreateFontString(nil, "OVERLAY", "GameFontDisable");
	frame.emptyText:SetPoint("CENTER", frame.list, "CENTER", -8, 0);
	frame.emptyText:SetText("Список пуст — ожидаю ближайшее автоматическое обновление");

	frame.scroll = CreateFrame(
		"ScrollFrame",
		"UnBotWorldInteractionScrollFrame",
		frame.list,
		"FauxScrollFrameTemplate"
	);
	frame.scroll:SetPoint("TOPLEFT", frame.list, "TOPLEFT", 0, -5);
	frame.scroll:SetPoint("BOTTOMRIGHT", frame.list, "BOTTOMRIGHT", -25, 5);
	frame.scroll:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, 30, UnBotWorldInteraction.RefreshRows);
	end);

	frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	frame.status:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -374);
	frame.status:SetWidth(430);
	frame.status:SetHeight(38);
	frame.status:SetJustifyH("LEFT");
	frame.status:SetJustifyV("TOP");
	frame.status:SetText("Выберите онлайн-бота.");

	frame.homeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
	frame.homeButton:SetWidth(225);
	frame.homeButton:SetHeight(24);
	frame.homeButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 20);
	frame.homeButton:SetText("Привязать альтов к гостинице");
	frame.homeButton:SetScript("OnClick", function()
		UnBotWorldInteraction.BindAccountAltsHome();
	end);
	frame.homeButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP");
		GameTooltip:AddLine("Привязать альтов к гостинице", 0, 0.8, 1, 1);
		GameTooltip:AddLine(
			"Выделите трактирщика. Команда home будет отправлена один раз только подключённым подтверждённым альтам аккаунта.",
			1, 1, 1, true
	);
		GameTooltip:AddLine("Дикие и обычные боты не затрагиваются.", 0, 1, 0, true);
		GameTooltip:Show();
	end);
	frame.homeButton:SetScript("OnLeave", function() GameTooltip:Hide(); end);

	frame.taxiButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
	frame.taxiButton:SetWidth(190);
	frame.taxiButton:SetHeight(24);
	frame.taxiButton:SetPoint("LEFT", frame.homeButton, "RIGHT", 10, 0);
	frame.taxiButton:SetText("Открыть полёты альтам");
	frame.taxiButton:SetScript("OnClick", function()
		UnBotWorldInteraction.OpenAccountAltFlightNode();
	end);
	frame.taxiButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP");
		GameTooltip:AddLine("Открыть полётный узел альтам", 0, 0.8, 1, 1);
		GameTooltip:AddLine(
			"Выделите распорядителя полётов и стойте рядом с ним вместе с подключёнными альтами. Каждому альту один раз отправится taxi.",
			1, 1, 1, true
		);
		GameTooltip:AddLine("Дикие и обычные боты не затрагиваются; автоматических повторов нет.", 0, 1, 0, true);
		GameTooltip:Show();
	end);
	frame.taxiButton:SetScript("OnLeave", function() GameTooltip:Hide(); end);

	frame.closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
	frame.closeButton:SetWidth(82);
	frame.closeButton:SetHeight(24);
	frame.closeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 20);
	frame.closeButton:SetText("Закрыть");
	frame.closeButton:SetScript("OnClick", function() frame:Hide(); end);

	frame:SetScript("OnShow", function()
		local state = UnBotWorldInteraction;
		state.autoRogueAttempted = false;
		state.botName = nil;
		state.objects = {};
		state.mode = nil;
		state.selectedIndex = nil;
		state.selectedLabel = nil;
		state.nextAutoScanAt = 0;
		UnBotWorldInteraction.RefreshBotButton(false);
		UnBotWorldInteraction.RefreshRows();
		if (state.botName) then
			UnBotWorldInteraction.Scan();
		else
			UnBotWorldInteraction.StartAutomaticRogue();
		end
	end);
	frame:SetScript("OnHide", function()
		UnBotWorldInteraction.mode = nil;
		UnBotWorldInteraction.autoRogueDeadline = 0;
		UnBotWorldInteraction.nextAutoScanAt = 0;
	end);
	frame:Hide();
	UnBotWorldInteraction.frame = frame;
	UnBotWorldInteraction.menuFrame = CreateFrame(
		"Frame",
		"UnBotWorldInteractionMenuFrame",
		UIParent,
		"UIDropDownMenuTemplate"
	);
	table.insert(UISpecialFrames, "UnBotWorldInteractionFrame");
	return frame;
end

function UnBotWorldInteraction.Toggle()
	local frame = UnBotWorldInteraction.CreateFrame();
	if (frame:IsShown()) then
		frame:Hide();
	else
		frame:Show();
	end
end

UnBotWorldInteraction.eventFrame = UnBotWorldInteraction.eventFrame
	or CreateFrame("Frame", "UnBotWorldInteractionEventFrame");
UnBotWorldInteraction.eventFrame:RegisterEvent("CHAT_MSG_WHISPER");
UnBotWorldInteraction.eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED");
UnBotWorldInteraction.eventFrame:RegisterEvent("RAID_ROSTER_UPDATE");
UnBotWorldInteraction.eventFrame:SetScript("OnEvent", function(self, event, message, sender)
	if (event == "CHAT_MSG_WHISPER") then
		UnBotWorldInteraction.HandleWhisper(message, sender);
	elseif (UnBotWorldInteraction.frame and UnBotWorldInteraction.frame:IsShown()) then
		local previousBot = UnBotWorldInteraction.botName;
		UnBotWorldInteraction.RefreshBotButton(false);
		if (
			UnBotWorldInteraction.botName
			and not UnBotWorldInteraction.SameName(previousBot, UnBotWorldInteraction.botName)
		) then
			UnBotWorldInteraction.objects = {};
			UnBotWorldInteraction.mode = nil;
			UnBotWorldInteraction.selectedIndex = nil;
			UnBotWorldInteraction.selectedLabel = nil;
			UnBotWorldInteraction.nextAutoScanAt = 0;
			UnBotWorldInteraction.RefreshRows();
			UnBotWorldInteraction.Scan();
		end
	end
end);
UnBotWorldInteraction.eventFrame:SetScript("OnUpdate", function()
	UnBotWorldInteraction.Update();
end);

SLASH_UNBOTWORLDINTERACTION1 = "/ublos";
SLASH_UNBOTWORLDINTERACTION2 = "/ubworld";
SlashCmdList["UNBOTWORLDINTERACTION"] = function()
	UnBotWorldInteraction.Toggle();
end
