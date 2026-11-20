-- Account-alt travel beacons. Character selection remains manual; all
-- in-world steps use the existing bounded account-alt summon controller.

UnBotBeaconTravel = UnBotBeaconTravel or {
	active = false,
	mode = nil,
	stage = nil,
	targetName = nil,
	note = nil,
	startedAt = 0,
	stageUntil = 0,
	summonAttempts = 0,
	cleanupStarted = false,
	logoutAt = 0,
	logoutSent = false,
	handledTaskId = nil,
	replaceConfirmName = nil,
	replaceConfirmUntil = 0,
	disbandAttempts = 0,
	nextDisbandAt = 0,
};

function UnBotBeaconTravel.Trim(text)
	text = tostring(text or "");
	text = string.gsub(text, "^%s+", "");
	text = string.gsub(text, "%s+$", "");
	return text;
end

function UnBotBeaconTravel.Message(text)
	if (UnBotBotCenterMessage) then
		UnBotBotCenterMessage(text);
	elseif (DEFAULT_CHAT_FRAME) then
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99UnBot|r: "..tostring(text or ""));
	end
end

function UnBotBeaconTravel.EnsureStorage()
	local storage = UnBotAccountAlts and UnBotAccountAlts.EnsureStorage
		and UnBotAccountAlts.EnsureStorage() or nil;
	if (not storage) then return nil; end
	storage.schemaVersion = math.max(7, tonumber(storage.schemaVersion) or 0);
	storage.beacons = type(storage.beacons) == "table" and storage.beacons or {};
	return storage;
end

function UnBotBeaconTravel.GetTask()
	local storage = UnBotBeaconTravel.EnsureStorage();
	return storage and type(storage.beaconTravelTask) == "table"
		and storage.beaconTravelTask or nil;
end

function UnBotBeaconTravel.GetBeacon(name)
	local storage = UnBotBeaconTravel.EnsureStorage();
	local resolved = UnBotAccountAlts and UnBotAccountAlts.ResolveName
		and UnBotAccountAlts.ResolveName(name, true) or name;
	return storage and resolved and storage.beacons[resolved] or nil;
end

function UnBotBeaconTravel.GetAllNames()
	local storage = UnBotBeaconTravel.EnsureStorage();
	local names = {};
	local seen = {};
	local function Add(name)
		name = UnBotBeaconTravel.Trim(name);
		local key = UnBotAccountAlts and UnBotAccountAlts.Key
			and UnBotAccountAlts.Key(name) or string.lower(name);
		if (name ~= "" and not seen[key]) then
			seen[key] = true;
			table.insert(names, name);
		end
	end
	if (UnBotAccountAlts and UnBotAccountAlts.GetNames) then
		for _, name in ipairs(UnBotAccountAlts.GetNames(true, false)) do Add(name); end
	elseif (storage and type(storage.accountIdentity) == "table") then
		-- Compatibility fallback: the active identity is already scoped by realm
		-- and account. Never merge the whole account-wide character archive here.
		for _, name in pairs(storage.accountIdentity.characterNames or {}) do Add(name); end
	end
	Add(UnitName("player"));
	table.sort(names, function(left, right)
		return string.lower(left) < string.lower(right);
	end);
	return names;
end

function UnBotBeaconTravel.GetCounts()
	local storage = UnBotBeaconTravel.EnsureStorage();
	local total = 0;
	local beacons = 0;
	local available = 0;
	for _, name in ipairs(UnBotBeaconTravel.GetAllNames()) do
		total = total + 1;
		local beacon = storage and storage.beacons[name];
		if (type(beacon) == "table" and beacon.enabled ~= false) then
			beacons = beacons + 1;
		elseif (
			name ~= UnitName("player")
			and UnBotAccountAlts
			and UnBotAccountAlts.IsEnabled(name)
			and UnBotAccountAlts.IsCurrentFaction(name)
		) then
			available = available + 1;
		end
	end
	return total, beacons, available;
end

function UnBotBeaconTravel.BuildRows()
	local storage = UnBotBeaconTravel.EnsureStorage();
	local rows = {};
	for _, name in ipairs(UnBotBeaconTravel.GetAllNames()) do
		local beacon = storage and storage.beacons[name];
		local profile = UnBotAccountAlts and UnBotAccountAlts.GetProfile
			and UnBotAccountAlts.GetProfile(name) or {};
		local isCurrent = name == UnitName("player");
		table.insert(rows, {
			name = name,
			profile = profile or {},
			beacon = type(beacon) == "table" and beacon or nil,
			isCurrent = isCurrent,
			enabled = not isCurrent and UnBotAccountAlts and UnBotAccountAlts.IsEnabled(name) or false,
			sameFaction = isCurrent or (UnBotAccountAlts and UnBotAccountAlts.IsCurrentFaction(name)) or false,
		});
	end
	table.sort(rows, function(left, right)
		local leftAssigned = left.beacon and left.beacon.enabled ~= false;
		local rightAssigned = right.beacon and right.beacon.enabled ~= false;
		if (leftAssigned ~= rightAssigned) then return leftAssigned; end
		local leftZone = leftAssigned and tostring(left.beacon.zoneName or "") or "";
		local rightZone = rightAssigned and tostring(right.beacon.zoneName or "") or "";
		if (leftZone ~= rightZone) then return leftZone < rightZone; end
		return string.lower(left.name) < string.lower(right.name);
	end);
	return rows;
end

function UnBotBeaconTravel.Recommend()
	local free = {};
	local reusable = {};
	for _, row in ipairs(UnBotBeaconTravel.BuildRows()) do
		if (not row.isCurrent and row.enabled and row.sameFaction) then
			if (not row.beacon or row.beacon.enabled == false) then
				table.insert(free, row);
			elseif (not row.beacon.pinned) then
				table.insert(reusable, row);
			end
		end
	end
	if (#free > 0) then
		table.sort(free, function(left, right)
			local leftLevel = tonumber(left.profile and left.profile.level) or 999;
			local rightLevel = tonumber(right.profile and right.profile.level) or 999;
			if (leftLevel ~= rightLevel) then return leftLevel < rightLevel; end
			return string.lower(left.name) < string.lower(right.name);
		end);
		return free[1].name, "ещё не назначен маяком";
	end
	if (#reusable == 0) then return nil, "нет свободного или незакреплённого маяка"; end
	table.sort(reusable, function(left, right)
		local leftUsed = tonumber(left.beacon.lastUsedAt) or 0;
		local rightUsed = tonumber(right.beacon.lastUsedAt) or 0;
		if (leftUsed ~= rightUsed) then return leftUsed < rightUsed; end
		local leftPlaced = tonumber(left.beacon.placedAt) or 0;
		local rightPlaced = tonumber(right.beacon.placedAt) or 0;
		if (leftPlaced ~= rightPlaced) then return leftPlaced < rightPlaced; end
		return string.lower(left.name) < string.lower(right.name);
	end);
	local beacon = reusable[1].beacon;
	local reason = (tonumber(beacon.lastUsedAt) or 0) > 0
		and ("давно не использовался: "..date("%d.%m.%Y", beacon.lastUsedAt))
		or "ещё ни разу не использовался";
	return reusable[1].name, reason;
end

function UnBotBeaconTravel.StatusText()
	local task = UnBotBeaconTravel.GetTask();
	if (UnBotBeaconTravel.active) then
		return "Маяки: "..tostring(UnBotBeaconTravel.mode or "операция").." — "
			..tostring(UnBotBeaconTravel.stage or "подготовка").." ("
			..tostring(UnBotBeaconTravel.targetName or "?")..").";
	end
	if (task) then
		if ((tonumber(task.expiresAt) or 0) <= time()) then
			return "Предыдущий переход просрочен. Нажмите «Отменить переход» справа внизу.";
		end
		if (task.stage == "await_beacon_login") then
			return "Переход ожидает входа за маяк "..tostring(task.beaconName)..".";
		elseif (task.stage == "await_traveler_login") then
			return "Переход ожидает входа за "..tostring(task.travelerName)..".";
		elseif (task.stage == "failed") then
			return "Переход остановлен: "..tostring(task.error or "неизвестная ошибка")
				..". Нажмите «Отменить переход» справа внизу.";
		end
	end
	return "Маяки готовы.";
end

function UnBotBeaconTravel.OtherAutomationActive()
	return (
		(UnBotAccountAlts and (UnBotAccountAlts.active or UnBotAccountAlts.discoveryActive))
		or (UnBotBotScanner and UnBotBotScanner.active)
		or (UnBotDKSpecBalance and UnBotDKSpecBalance.active)
		or (UnBotJunkCleaner and UnBotJunkCleaner.active)
		or (UnBotFastJunkRaid and UnBotFastJunkRaid.active)
		or (UnBotSpecSummon and UnBotSpecSummon.active)
		or (UnBotIsSquadSpecCheckActive and UnBotIsSquadSpecCheckActive())
	);
end

function UnBotBeaconTravel.GroupIsEmpty()
	return (not GetNumPartyMembers or GetNumPartyMembers() == 0)
		and (not GetNumRaidMembers or GetNumRaidMembers() == 0);
end

function UnBotBeaconTravel.TargetReady(name)
	local unit = UnBotAccountAlts and UnBotAccountAlts.FindUnit
		and UnBotAccountAlts.FindUnit(name) or nil;
	if (not unit or (UnitIsConnected and not UnitIsConnected(unit))) then return false; end
	if (UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit)) then return false; end
	if (UnBotSquadNearbyGateUnitReady) then
		return UnBotSquadNearbyGateUnitReady(unit) and true or false;
	end
	if (UnitIsVisible and not UnitIsVisible(unit)) then return false; end
	if (UnitInRange and UnitInRange(unit)) then return true; end
	if (CheckInteractDistance) then return CheckInteractDistance(unit, 1) and true or false; end
	return not UnitIsVisible or UnitIsVisible(unit);
end

function UnBotBeaconTravel.RefreshUI()
	if (UnBotSpecAuditRefresh) then UnBotSpecAuditRefresh(); end
end

function UnBotBeaconTravel.Stop(text, preserveTask)
	UnBotBeaconTravel.active = false;
	UnBotBeaconTravel.mode = nil;
	UnBotBeaconTravel.stage = nil;
	UnBotBeaconTravel.targetName = nil;
	UnBotBeaconTravel.note = nil;
	UnBotBeaconTravel.startedAt = 0;
	UnBotBeaconTravel.stageUntil = 0;
	UnBotBeaconTravel.summonAttempts = 0;
	UnBotBeaconTravel.cleanupStarted = false;
	UnBotBeaconTravel.logoutAt = 0;
	UnBotBeaconTravel.logoutSent = false;
	UnBotBeaconTravel.disbandAttempts = 0;
	UnBotBeaconTravel.nextDisbandAt = 0;
	if (not preserveTask) then
		local storage = UnBotBeaconTravel.EnsureStorage();
		if (storage) then storage.beaconTravelTask = nil; end
	end
	if (text) then UnBotBeaconTravel.Message(text); end
	UnBotBeaconTravel.RefreshUI();
end

function UnBotBeaconTravel.Fail(text, keepTask)
	local task = UnBotBeaconTravel.GetTask();
	if (task and keepTask) then
		task.stage = "failed";
		task.error = tostring(text or "операция остановлена");
		task.failedAt = time();
	end
	UnBotBeaconTravel.Stop("Маяки: "..tostring(text or "операция остановлена")..".", keepTask);
end

function UnBotBeaconTravel.SaveAssignment(name, note, source)
	local storage = UnBotBeaconTravel.EnsureStorage();
	if (not storage) then return nil; end
	local old = storage.beacons[name];
	local now = time();
	local zoneName = GetRealZoneText and GetRealZoneText() or "Неизвестная зона";
	local subZoneName = GetSubZoneText and GetSubZoneText() or "";
	local beacon = type(old) == "table" and old or {};
	if (type(old) == "table" and old.enabled ~= false and old.zoneName) then
		beacon.history = type(beacon.history) == "table" and beacon.history or {};
		table.insert(beacon.history, 1, {
			zoneName = old.zoneName,
			subZoneName = old.subZoneName,
			note = old.note,
			placedAt = old.placedAt,
			replacedAt = now,
		});
		while (#beacon.history > 5) do table.remove(beacon.history); end
	end
	beacon.enabled = true;
	beacon.zoneName = zoneName;
	beacon.subZoneName = subZoneName ~= "" and subZoneName or nil;
	beacon.note = UnBotBeaconTravel.Trim(note);
	beacon.placedAt = now;
	beacon.locationUpdatedAt = now;
	beacon.locationSource = source or "placed";
	beacon.useCount = tonumber(beacon.useCount) or 0;
	storage.beacons[name] = beacon;
	return beacon;
end

function UnBotBeaconTravel.SetNote(name, note)
	local beacon = UnBotBeaconTravel.GetBeacon(name);
	if (not beacon or beacon.enabled == false) then
		UnBotBeaconTravel.Message("Сначала поставьте выбранного персонажа как маяк.");
		return false;
	end
	beacon.note = UnBotBeaconTravel.Trim(note);
	beacon.updatedAt = time();
	UnBotBeaconTravel.Message("Заметка маяка "..tostring(name).." сохранена.");
	UnBotBeaconTravel.RefreshUI();
	return true;
end

function UnBotBeaconTravel.TogglePinned(name)
	local beacon = UnBotBeaconTravel.GetBeacon(name);
	if (not beacon or beacon.enabled == false) then
		UnBotBeaconTravel.Message("Закрепить можно только установленный маяк.");
		return false;
	end
	beacon.pinned = not beacon.pinned;
	beacon.updatedAt = time();
	UnBotBeaconTravel.Message(tostring(name)..(beacon.pinned
		and ": маяк закреплён и не будет предлагаться для переноса."
		or ": маяк снова можно предлагать для переноса."));
	UnBotBeaconTravel.RefreshUI();
	return true;
end

function UnBotBeaconTravel.Unassign(name)
	local beacon = UnBotBeaconTravel.GetBeacon(name);
	if (not beacon or beacon.enabled == false) then
		UnBotBeaconTravel.Message("Выбранный персонаж не назначен маяком.");
		return false;
	end
	beacon.enabled = false;
	beacon.unassignedAt = time();
	UnBotBeaconTravel.Message(tostring(name)..": статус маяка снят; персонаж не перемещался.");
	UnBotBeaconTravel.RefreshUI();
	return true;
end

function UnBotBeaconTravel.ValidateTarget(name)
	local resolved = UnBotAccountAlts and UnBotAccountAlts.ResolveName
		and UnBotAccountAlts.ResolveName(name, true) or nil;
	if (not resolved) then return nil, "персонаж не подтверждён серверным Bot roster"; end
	if (resolved == UnitName("player")) then return nil, "текущий персонаж не может призвать самого себя"; end
	if (not UnBotAccountAlts.IsEnabled(resolved)) then return nil, "персонаж отключён на вкладке «Альты»"; end
	if (not UnBotAccountAlts.IsCurrentFaction(resolved)) then
		return nil, UnBotAccountAlts.FactionRestrictionText(resolved);
	end
	return resolved, nil;
end

function UnBotBeaconTravel.StartPlace(name, note)
	if (UnBotBeaconTravel.active or UnBotBeaconTravel.OtherAutomationActive()) then
		UnBotBeaconTravel.Message("Сначала завершите другую автоматизацию UnBot.");
		return false;
	end
	if (InCombatLockdown and InCombatLockdown()) then
		UnBotBeaconTravel.Message("Поставить маяк можно только вне боя.");
		return false;
	end
	if (not UnBotBeaconTravel.GroupIsEmpty()) then
		UnBotBeaconTravel.Message("Для установки маяка нужна пустая группа без офлайн-резерва.");
		return false;
	end
	if (UnBotBeaconTravel.GetTask()) then
		UnBotBeaconTravel.Message("Новая установка заблокирована сохранённым переходом. На вкладке «Маяки» нажмите кнопку «Отменить переход» справа внизу (или введите /ubm cancel), затем снова нажмите «Поставить здесь».");
		return false;
	end
	local resolved, reason = UnBotBeaconTravel.ValidateTarget(name);
	if (not resolved) then UnBotBeaconTravel.Message("Маяк не установлен: "..tostring(reason).."."); return false; end
	local oldBeacon = UnBotBeaconTravel.GetBeacon(resolved);
	if (oldBeacon and oldBeacon.enabled ~= false and oldBeacon.zoneName) then
		local confirmationValid = UnBotBeaconTravel.replaceConfirmName == resolved
			and (tonumber(UnBotBeaconTravel.replaceConfirmUntil) or 0) >= GetTime();
		if (not confirmationValid) then
			UnBotBeaconTravel.replaceConfirmName = resolved;
			UnBotBeaconTravel.replaceConfirmUntil = GetTime() + 12;
			local oldNote = UnBotBeaconTravel.Trim(oldBeacon.note);
			if (UnBotBeaconTravel.Trim(note) == oldNote) then
				note = "";
				if (UnBotSpecAudit and UnBotSpecAudit.beaconNoteEdit) then
					UnBotSpecAudit.beaconNoteEdit:SetText("");
				end
			end
			local consequence = tostring(oldBeacon.zoneName);
			if (oldBeacon.subZoneName and oldBeacon.subZoneName ~= "") then
				consequence = consequence.." / "..tostring(oldBeacon.subZoneName);
			end
			if (oldNote ~= "") then consequence = consequence.." — «"..oldNote.."»"; end
			UnBotBeaconTravel.Message("Перенос маяка "..resolved.." освободит точку "
				..consequence..". Старая заметка не переносится. Повторно нажмите «Поставить здесь» в течение 12 секунд для подтверждения.");
			UnBotBeaconTravel.RefreshUI();
			return false;
		end
		if (UnBotBeaconTravel.Trim(note) == UnBotBeaconTravel.Trim(oldBeacon.note)) then
			note = "";
		end
	end
	UnBotBeaconTravel.replaceConfirmName = nil;
	UnBotBeaconTravel.replaceConfirmUntil = 0;
	UnBotBeaconTravel.active = true;
	UnBotBeaconTravel.mode = "установка";
	UnBotBeaconTravel.stage = "подключение альта";
	UnBotBeaconTravel.targetName = resolved;
	UnBotBeaconTravel.note = UnBotBeaconTravel.Trim(note);
	UnBotBeaconTravel.startedAt = GetTime();
	UnBotBeaconTravel.stageUntil = GetTime() + 20;
	UnBotBeaconTravel.summonAttempts = 0;
	UnBotBeaconTravel.cleanupStarted = false;
	UnBotBeaconTravel.Message("Маяк: подключаю "..resolved.." и ставлю в точке «"
		..tostring(GetRealZoneText and GetRealZoneText() or "текущая зона").."».");
	if (not UnBotAccountAlts.Summon(resolved)) then
		UnBotBeaconTravel.Fail("не удалось запустить точный призыв", false);
		return false;
	end
	UnBotBeaconTravel.RefreshUI();
	return true;
end

function UnBotBeaconTravel.DisbandCurrentGroup()
	if (UnBotBeaconTravel.GroupIsEmpty()) then return true; end
	if (UnitIsPartyLeader and not UnitIsPartyLeader("player")) then
		if (LeaveParty) then pcall(LeaveParty); end
		return false;
	end
	local names = {};
	local raidCount = GetNumRaidMembers and GetNumRaidMembers() or 0;
	local partyCount = GetNumPartyMembers and GetNumPartyMembers() or 0;
	if (raidCount > 0) then
		for index = 1, raidCount do
			local unit = "raid"..index;
			local memberName = UnitName(unit);
			if (memberName and memberName ~= UnitName("player")) then
				table.insert(names, memberName);
			end
		end
	else
		for index = 1, partyCount do
			local memberName = UnitName("party"..index);
			if (memberName and memberName ~= UnitName("player")) then
				table.insert(names, memberName);
			end
		end
	end
	for _, memberName in ipairs(names) do
		if (UninviteUnit) then pcall(UninviteUnit, memberName); end
	end
	if (#names == 0 and LeaveParty) then pcall(LeaveParty); end
	return false;
end

function UnBotBeaconTravel.CommitTravel(resolved, beacon)
	local storage = UnBotBeaconTravel.EnsureStorage();
	local now = time();
	storage.beaconTravelTask = {
		id = tostring(now)..":"..tostring(UnitName("player"))..":"..resolved,
		stage = "await_beacon_login",
		travelerName = UnitName("player"),
		beaconName = resolved,
		destinationZone = beacon.zoneName,
		destinationSubZone = beacon.subZoneName,
		createdAt = now,
		expiresAt = now + 1800,
	};
	UnBotBeaconTravel.Stop(nil, true);
	UnBotBeaconTravel.Message("Группа распущена. Переход сохранён. Сейчас выберите персонажа-маяк "
		..resolved.." ("..tostring(beacon.zoneName)..").");
	if (Logout) then
		local ok = pcall(Logout);
		if (not ok) then
			UnBotBeaconTravel.Message("Автоматический выход недоступен этому клиенту. Выполните /logout вручную.");
		end
	else
		UnBotBeaconTravel.Message("Выполните /logout и войдите за "..resolved..".");
	end
	return true;
end

function UnBotBeaconTravel.StartTravel(name)
	if (UnBotBeaconTravel.active or UnBotBeaconTravel.OtherAutomationActive()) then
		UnBotBeaconTravel.Message("Сначала завершите другую автоматизацию UnBot.");
		return false;
	end
	if (InCombatLockdown and InCombatLockdown()) then
		UnBotBeaconTravel.Message("Переход через маяк можно начать только вне боя.");
		return false;
	end
	if (UnBotBeaconTravel.GetTask()) then
		UnBotBeaconTravel.Message("Уже есть сохранённый переход. На вкладке «Маяки» нажмите кнопку «Отменить переход» справа внизу (или введите /ubm cancel), затем повторите перемещение.");
		return false;
	end
	local resolved, reason = UnBotBeaconTravel.ValidateTarget(name);
	local beacon = resolved and UnBotBeaconTravel.GetBeacon(resolved) or nil;
	if (not resolved) then UnBotBeaconTravel.Message("Переход не начат: "..tostring(reason).."."); return false; end
	if (not beacon or beacon.enabled == false or not beacon.zoneName) then
		UnBotBeaconTravel.Message("Сначала поставьте выбранного персонажа как маяк.");
		return false;
	end
	if (not UnBotBeaconTravel.GroupIsEmpty()) then
		UnBotBeaconTravel.active = true;
		UnBotBeaconTravel.mode = "переход";
		UnBotBeaconTravel.stage = "роспуск группы";
		UnBotBeaconTravel.targetName = resolved;
		UnBotBeaconTravel.startedAt = GetTime();
		UnBotBeaconTravel.stageUntil = GetTime() + 12;
		UnBotBeaconTravel.disbandAttempts = 1;
		UnBotBeaconTravel.nextDisbandAt = GetTime() + 1.5;
		UnBotBeaconTravel.Message("Перед переходом распускаю текущую группу. Выход начнётся только после пустого ростера.");
		UnBotBeaconTravel.DisbandCurrentGroup();
		UnBotBeaconTravel.RefreshUI();
		return true;
	end
	return UnBotBeaconTravel.CommitTravel(resolved, beacon);
end

function UnBotBeaconTravel.CancelTask()
	local storage = UnBotBeaconTravel.EnsureStorage();
	if (storage) then storage.beaconTravelTask = nil; end
	if (UnBotAccountAlts and UnBotAccountAlts.active) then
		UnBotAccountAlts.Stop("Операция с альтом остановлена вместе с переходом.");
	end
	UnBotBeaconTravel.Stop("Переход через маяк отменён.", true);
	return true;
end

function UnBotBeaconTravel.BeginTaskForCurrentCharacter()
	local task = UnBotBeaconTravel.GetTask();
	if (not task) then return false; end
	if ((tonumber(task.expiresAt) or 0) <= time()) then
		task.stage = "failed";
		task.error = "задание просрочено";
		UnBotBeaconTravel.Message("Маяки: сохранённый переход просрочен. Откройте вкладку «Маяки» и отмените его.");
		return false;
	end
	local player = UnitName("player");
	if (task.stage == "await_beacon_login") then
		if (player ~= task.beaconName) then
			UnBotBeaconTravel.Message("Маяки: ожидался вход за "..tostring(task.beaconName)
				..", сейчас выбран "..tostring(player)..". Команды не отправлены.");
			return false;
		end
		if (not UnBotBeaconTravel.GroupIsEmpty()) then
			UnBotBeaconTravel.Fail("у персонажа-маяка уже есть группа; очистите её и повторите переход", true);
			return false;
		end
		UnBotBeaconTravel.active = true;
		UnBotBeaconTravel.mode = "переход";
		UnBotBeaconTravel.stage = "ожидание мира";
		UnBotBeaconTravel.targetName = task.travelerName;
		UnBotBeaconTravel.startedAt = GetTime();
		UnBotBeaconTravel.stageUntil = GetTime() + 3;
		UnBotBeaconTravel.summonAttempts = 0;
		UnBotBeaconTravel.handledTaskId = task.id;
		UnBotBeaconTravel.Message("Маяк активирован. Через несколько секунд призову "
			..tostring(task.travelerName)..".");
		return true;
	elseif (task.stage == "await_traveler_login") then
		if (player ~= task.travelerName) then
			UnBotBeaconTravel.Message("Маяки: теперь войдите за "..tostring(task.travelerName)
				..". Команды текущим персонажем не отправлены.");
			return false;
		end
		local actualZone = GetRealZoneText and GetRealZoneText() or "";
		if (task.destinationZone and actualZone ~= "" and actualZone ~= task.destinationZone) then
			task.stage = "failed";
			task.error = "ожидалась зона «"..tostring(task.destinationZone).."», получена «"..actualZone.."»";
			UnBotBeaconTravel.Message("Маяки: переход не подтверждён — "..task.error..".");
			return false;
		end
		local beacon = UnBotBeaconTravel.GetBeacon(task.beaconName);
		if (beacon) then
			beacon.lastUsedAt = time();
			beacon.useCount = (tonumber(beacon.useCount) or 0) + 1;
		end
		if (GetNumPartyMembers and GetNumPartyMembers() == 1 and GetNumRaidMembers and GetNumRaidMembers() == 0) then
			local unit = UnBotAccountAlts and UnBotAccountAlts.FindUnit(task.beaconName);
			if (unit) then
				if (UnitIsPartyLeader and UnitIsPartyLeader("player")) then UninviteUnit(task.beaconName); else LeaveParty(); end
			end
		end
		local storage = UnBotBeaconTravel.EnsureStorage();
		if (storage) then storage.beaconTravelTask = nil; end
		UnBotBeaconTravel.Stop(nil, true);
		UnBotBeaconTravel.Message("Переход через маяк "..tostring(task.beaconName)
			.." завершён: "..tostring(actualZone ~= "" and actualZone or task.destinationZone)..".");
		UnBotBeaconTravel.RefreshUI();
		return true;
	end
	return false;
end

function UnBotBeaconTravel.UpdatePlayerLocation()
	local storage = UnBotBeaconTravel.EnsureStorage();
	if (not storage) then return; end
	local name = UnitName("player");
	local beacon = name and storage.beacons[name];
	if (type(beacon) ~= "table" or beacon.enabled == false) then return; end
	local zoneName = GetRealZoneText and GetRealZoneText() or nil;
	local subZoneName = GetSubZoneText and GetSubZoneText() or nil;
	if (zoneName and zoneName ~= "") then
		beacon.zoneName = zoneName;
		beacon.subZoneName = subZoneName and subZoneName ~= "" and subZoneName or nil;
		beacon.locationUpdatedAt = time();
		beacon.locationSource = "player-login";
	end
end

function UnBotBeaconTravel.SendSummon()
	if (not UnBotBeaconTravel.targetName) then return; end
	UnBotBeaconTravel.summonAttempts = (tonumber(UnBotBeaconTravel.summonAttempts) or 0) + 1;
	SendChatMessage("stay", "WHISPER", nil, UnBotBeaconTravel.targetName);
	SendChatMessage("summon", "WHISPER", nil, UnBotBeaconTravel.targetName);
	UnBotBeaconTravel.stageUntil = GetTime() + 8;
	UnBotBeaconTravel.Message("Маяки: summon "..tostring(UnBotBeaconTravel.summonAttempts)
		.."/2 для "..tostring(UnBotBeaconTravel.targetName)..".");
end

function UnBotBeaconTravel.HandleExplicitFailure(message, sender)
	if (not UnBotBeaconTravel.active or not UnBotBeaconTravel.targetName) then return false; end
	local text = tostring(message or "");
	text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "");
	text = string.gsub(text, "|r", "");
	local lowered = string.lower(text);
	local failed = string.find(lowered, "unknown spell", 1, true)
		or string.find(lowered, "cannot cast", 1, true)
		or string.find(lowered, "no items", 1, true)
		or string.find(lowered, "too low to summon", 1, true)
		or string.find(lowered, "level is too low", 1, true)
		or string.find(text, "Неизвестное заклинание", 1, true)
		or string.find(text, "Невозможно применить", 1, true)
		or string.find(text, "Слишком низкий уровень", 1, true);
	if (not failed) then return false; end
	if (sender and sender ~= "") then
		local senderKey = UnBotAccountAlts and UnBotAccountAlts.SenderKey
			and UnBotAccountAlts.SenderKey(sender) or string.lower(sender);
		local targetKey = UnBotAccountAlts and UnBotAccountAlts.SenderKey
			and UnBotAccountAlts.SenderKey(UnBotBeaconTravel.targetName)
			or string.lower(UnBotBeaconTravel.targetName);
		if (senderKey ~= targetKey) then return false; end
	elseif (not string.find(lowered, string.lower(UnBotBeaconTravel.targetName), 1, true)) then
		return false;
	end
	if (UnBotAccountAlts and UnBotAccountAlts.active) then
		UnBotAccountAlts.Stop("Операция остановлена после явного отказа сервера.");
	end
	UnBotBeaconTravel.Fail("сервер отказал: "..text, UnBotBeaconTravel.mode == "переход");
	return true;
end

function UnBotBeaconTravel.CompleteTravelerArrival(source)
	local task = UnBotBeaconTravel.GetTask();
	if (not task) then
		UnBotBeaconTravel.Fail("задание перехода потеряно", false);
		return false;
	end
	if (UnBotAccountAlts and UnBotAccountAlts.active and UnBotAccountAlts.Finish) then
		-- Do not call Stop here: it deliberately cleans up a newly connected alt.
		-- For travel, the new roster slot itself proves that the server moved the traveler.
		UnBotAccountAlts.Finish("Маяки: участник появился в группе; точное имя для перехода не требуется.");
	end
	task.stage = "await_traveler_login";
	task.summonedAt = time();
	task.arrivalSource = source or "target";
	UnBotBeaconTravel.stage = "выход к выбору персонажа";
	UnBotBeaconTravel.logoutAt = GetTime() + 2;
	UnBotBeaconTravel.Message("Путешественник появился в группе. Считаю телепортацию завершённой; сейчас выйду, затем выберите "
		..tostring(task.travelerName)..".");
	UnBotBeaconTravel.RefreshUI();
	return true;
end

function UnBotBeaconTravel.OnUpdate()
	if (not UnBotBeaconTravel.active) then return; end
	local now = GetTime();
	if (UnBotBeaconTravel.stage == "роспуск группы") then
		if (UnBotBeaconTravel.GroupIsEmpty()) then
			local name = UnBotBeaconTravel.targetName;
			local beacon = name and UnBotBeaconTravel.GetBeacon(name) or nil;
			if (not beacon or beacon.enabled == false or not beacon.zoneName) then
				UnBotBeaconTravel.Fail("маяк потерял назначенную точку во время роспуска группы", false);
			else
				UnBotBeaconTravel.CommitTravel(name, beacon);
			end
			return;
		end
		if (now >= UnBotBeaconTravel.stageUntil) then
			UnBotBeaconTravel.Fail("не удалось полностью распустить группу за 12 секунд; выход отменён", false);
			return;
		end
		if (now >= (UnBotBeaconTravel.nextDisbandAt or 0)) then
			if ((UnBotBeaconTravel.disbandAttempts or 0) >= 6) then
				UnBotBeaconTravel.Fail("после шести попыток в группе остались участники; выход отменён", false);
				return;
			end
			UnBotBeaconTravel.disbandAttempts = (UnBotBeaconTravel.disbandAttempts or 0) + 1;
			UnBotBeaconTravel.nextDisbandAt = now + 1.5;
			UnBotBeaconTravel.DisbandCurrentGroup();
		end
		return;
	end
	if (UnBotBeaconTravel.stage == "ожидание мира" and now >= UnBotBeaconTravel.stageUntil) then
		UnBotBeaconTravel.stage = "подключение путешественника";
		UnBotBeaconTravel.stageUntil = now + 20;
		if (not UnBotAccountAlts.Summon(UnBotBeaconTravel.targetName)) then
			UnBotBeaconTravel.Fail("не удалось подключить путешественника", true);
		end
		return;
	end
	if (UnBotBeaconTravel.stage == "подключение альта" or UnBotBeaconTravel.stage == "подключение путешественника") then
		if (
			UnBotBeaconTravel.stage == "подключение путешественника"
			and not UnBotBeaconTravel.GroupIsEmpty()
		) then
			UnBotBeaconTravel.CompleteTravelerArrival("roster");
			return;
		end
		if (UnBotAccountAlts and UnBotAccountAlts.active) then
			if (now >= UnBotBeaconTravel.stageUntil) then
				UnBotAccountAlts.Stop("Операция с альтом остановлена по таймауту маяка.");
				UnBotBeaconTravel.Fail("персонаж не вошёл в группу за 20 секунд", UnBotBeaconTravel.mode == "переход");
			end
			return;
		end
		if (not UnBotAccountAlts.IsOnline(UnBotBeaconTravel.targetName)) then
			UnBotBeaconTravel.Fail("персонаж не подключился к группе", UnBotBeaconTravel.mode == "переход");
			return;
		end
		UnBotBeaconTravel.stage = "проверка прибытия";
		UnBotBeaconTravel.stageUntil = now + 2;
		UnBotBeaconTravel.summonAttempts = 1;
		return;
	end
	if (UnBotBeaconTravel.stage == "проверка прибытия") then
		if (UnBotBeaconTravel.TargetReady(UnBotBeaconTravel.targetName)) then
			if (UnBotBeaconTravel.mode == "установка") then
				UnBotBeaconTravel.SaveAssignment(UnBotBeaconTravel.targetName, UnBotBeaconTravel.note, "placed");
				UnBotBeaconTravel.stage = "отключение маяка";
				UnBotBeaconTravel.stageUntil = now + 12;
				UnBotBeaconTravel.cleanupStarted = true;
				UnBotAccountAlts.RemoveFromGroup(UnBotBeaconTravel.targetName);
			else
				UnBotBeaconTravel.CompleteTravelerArrival("target");
			end
			if (UnBotBeaconTravel.mode == "установка") then
				UnBotBeaconTravel.RefreshUI();
			end
			return;
		end
		if (now >= UnBotBeaconTravel.stageUntil) then
			if ((UnBotBeaconTravel.summonAttempts or 0) < 2) then
				UnBotBeaconTravel.SendSummon();
			else
				UnBotBeaconTravel.Fail("после двух summon персонаж не появился рядом", UnBotBeaconTravel.mode == "переход");
			end
		end
		return;
	end
	if (UnBotBeaconTravel.stage == "отключение маяка") then
		if (UnBotAccountAlts and UnBotAccountAlts.active) then
			if (now < UnBotBeaconTravel.stageUntil) then return; end
			UnBotAccountAlts.Stop("Очистка маяка остановлена по таймауту.");
		end
		local name = UnBotBeaconTravel.targetName;
		local stillInGroup = UnBotAccountAlts and UnBotAccountAlts.IsInGroup(name);
		UnBotBeaconTravel.Stop("Маяк "..tostring(name).." установлен: "
			..tostring(GetRealZoneText and GetRealZoneText() or "текущая зона")
			..(stillInGroup and ". Персонаж остался в ростере — нажмите «Убрать из группы» ещё раз" or ""), false);
		return;
	end
	if (UnBotBeaconTravel.stage == "выход к выбору персонажа" and now >= UnBotBeaconTravel.logoutAt) then
		if (UnBotBeaconTravel.logoutSent) then return; end
		UnBotBeaconTravel.logoutSent = true;
		if (InCombatLockdown and InCombatLockdown()) then
			UnBotBeaconTravel.Fail("автоматический выход заблокирован боем; выйдите вручную после боя", true);
			return;
		end
		if (Logout) then
			local ok = pcall(Logout);
			if (not ok) then
				UnBotBeaconTravel.Message("Автоматический выход недоступен. Выполните /logout вручную.");
			end
		else
			UnBotBeaconTravel.Message("Выполните /logout вручную и войдите за путешественника.");
		end
		return;
	end
end

UnBotBeaconTravel.frame = UnBotBeaconTravel.frame or CreateFrame("Frame", "UnBotBeaconTravelFrame");
UnBotBeaconTravel.frame:RegisterEvent("PLAYER_ENTERING_WORLD");
UnBotBeaconTravel.frame:RegisterEvent("CHAT_MSG_WHISPER");
UnBotBeaconTravel.frame:RegisterEvent("CHAT_MSG_SYSTEM");
UnBotBeaconTravel.frame:RegisterEvent("UI_ERROR_MESSAGE");
UnBotBeaconTravel.frame:RegisterEvent("PARTY_MEMBERS_CHANGED");
UnBotBeaconTravel.frame:RegisterEvent("RAID_ROSTER_UPDATE");
UnBotBeaconTravel.frame:SetScript("OnEvent", function(self, event, arg1, arg2)
	if (event == "PLAYER_ENTERING_WORLD") then
		UnBotBeaconTravel.UpdatePlayerLocation();
		UnBotBeaconTravel.BeginTaskForCurrentCharacter();
	elseif (
		(event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE")
		and UnBotBeaconTravel.active
		and UnBotBeaconTravel.stage == "подключение путешественника"
		and not UnBotBeaconTravel.GroupIsEmpty()
	) then
		UnBotBeaconTravel.CompleteTravelerArrival("roster");
	elseif (event == "CHAT_MSG_WHISPER") then
		UnBotBeaconTravel.HandleExplicitFailure(arg1, arg2);
	elseif (event == "CHAT_MSG_SYSTEM" or event == "UI_ERROR_MESSAGE") then
		UnBotBeaconTravel.HandleExplicitFailure(arg1, nil);
	end
end);
UnBotBeaconTravel.frame:SetScript("OnUpdate", function() UnBotBeaconTravel.OnUpdate(); end);

SLASH_UNBOTBEACON1 = "/ubbeacon";
SLASH_UNBOTBEACON2 = "/ubm";
SlashCmdList["UNBOTBEACON"] = function(message)
	local command = string.lower(UnBotBeaconTravel.Trim(message));
	if (command == "cancel" or command == "отмена") then
		UnBotBeaconTravel.CancelTask();
	elseif (command == "status" or command == "статус") then
		UnBotBeaconTravel.Message(UnBotBeaconTravel.StatusText());
	elseif (UnBotBotCenterShow) then
		UnBotBotCenterShow("beacons");
	else
		UnBotBeaconTravel.Message("Центр управления ещё не загрузился.");
	end
end
