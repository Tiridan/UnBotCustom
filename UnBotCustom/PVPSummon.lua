-- Separate PvP pipeline: join/arrival -> read -> apply -> verify -> bounded refill.
UnBotPVPSummon = UnBotPVPSummon or {};
UnBotPVPSummon.cleanup = {};
UnBotPVPSummon.sendInterval = 1;
UnBotPVPSummon.retryInterval = 3;

function UnBotPVPSummon.LogOperation(stage, op, detail)
	if (not UnBotPVPSummon.catalogOnly and UnBotSummonLog and op) then
		UnBotSummonLog.Safe("Operation",stage,"pvp",op,detail);
	end
end

function UnBotPVPSummon.LogWait(reason, op)
	if (not UnBotPVPSummon.catalogOnly and UnBotSummonLog) then
		UnBotSummonLog.Safe("Wait","pvp",reason,op and op.entry.name,op and op.kind);
	end
end

function UnBotPVPSummon.CandidateResult(entry, status, reason)
	if (not UnBotPVPSummon.catalogOnly and UnBotSummonLog) then
		UnBotSummonLog.Safe("Add","candidate_result",status,entry.name,
			"slot="..entry.slotIndex.." elapsedMs="..math.floor((GetTime()-(entry.createdAt or GetTime()))*1000+.5)
			.." reason="..tostring(reason or entry.confirmation or "").." origin="..tostring(entry.origin));
	end
end

function UnBotPVPSummon.Clean(text)
	-- ASCII command/name folding must not corrupt UTF-8 refusal text when the
	-- host's C locale treats individual UTF-8 bytes as uppercase Cyrillic.
	return tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|h", "")
		:gsub("[A-Z]",string.lower):match("^%s*(.-)%s*$");
end

function UnBotPVPSummon.Message(text)
	UnBotPVPSquad.Message((UnBotPVPSummon.catalogOnly and "Каталог спеков: " or "PVP: ")..text);
end

function UnBotPVPSummon.Signature()
	local state, parts = UnBotPVPSquad.State(), {};
	for _, slot in ipairs(state and state.slots or {}) do
		table.insert(parts, tostring(slot.className)..":"..tostring(slot.specKey)..":"..UnBotPVPSquad.Count(slot));
	end
	return table.concat(parts, "|").."|pveFallback="..tostring(not state or state.allowPVEFallback~=false);
end

function UnBotPVPSummon.Unit(name)
	return UnBotSquadRosterFindUnit(name);
end

function UnBotPVPSummon.Near(entry)
	local unit = UnBotPVPSummon.Unit(entry.name);
	return unit and UnBotSquadNearbyGateUnitReady(unit) and not UnitIsDeadOrGhost(unit);
end

function UnBotPVPSummon.Protected(name)
	-- PvE assignments are a snapshot: a newly summoned PvP bot must not be
	-- claimed by an initially empty matching PvE row during this controller.
	return (not UnBotPVPSummon.catalogOnly and UnBotPVPSummon.protected and UnBotPVPSummon.protected[name])
		or UnBotIsAccountAltProfile(name, UnBotBotRegistry.bots and UnBotBotRegistry.bots[name])
		or UnBotSquadRosterIsOfflineReserve(name);
end

function UnBotPVPSummon.Fail(entry, reason, quarantine)
	local s = UnBotPVPSummon;
	UnBotPVPSummon.LogOperation("op_end",s.op,reason);
	UnBotPVPSummon.LogWait(nil);
	if (s.inspectEntry==entry) then UnBotTalentInfo.Cancel(s); s.inspectEntry=nil; end
	entry.failed, entry.ready, entry.reason = true, false, reason;
	UnBotPVPSummon.CandidateResult(entry,"failed",reason);
	if (quarantine and not s.catalogOnly) then UnBotRegistrySetHourlyQuarantine(entry.name, "PVP: "..reason, "PVP-карантин"); end
	if (entry.new and (entry.sentAdd or UnBotPVPSummon.Unit(entry.name))) then
		s.cleanup[entry.name] = {at = GetTime(), untilTime = GetTime() + 30, attempts = 0};
	end
	s.op = nil;
	UnBotPVPSummon.Message(entry.name..": "..reason);
end

function UnBotPVPSummon.Stop(reason)
	local s = UnBotPVPSummon;
	if (not s.active) then return; end
	UnBotPVPSummon.LogOperation("op_end",s.op,reason or "stopped");
	UnBotPVPSummon.LogWait(nil);
	if (not s.catalogOnly and UnBotSummonLog) then UnBotSummonLog.Safe("Result","pvp","stopped",reason); end
	if (UnBotTalentInfo) then UnBotTalentInfo.Cancel(s); end
	s.inspectEntry,s.resetAI=nil,nil;
	s.active, s.op = false, nil;
	if (UnBotGunshipMasterLoot) then UnBotGunshipMasterLoot.summonGuard = false; end
	for _, entry in ipairs(s.items or {}) do
		if (entry.new and (s.catalogOnly or not entry.ready) and (entry.sentAdd or UnBotPVPSummon.Unit(entry.name))
			and (not s.catalogOnly or not entry.releaseQueued)) then
			s.cleanup[entry.name] = s.cleanup[entry.name] or {at = GetTime(), untilTime = GetTime() + 30, attempts = 0};
		end
	end
	UnBotPVPSummon.Message(reason or "остановлено");
	UnBotPVPSquad.Refresh();
end

function UnBotPVPSummon.ObservationValid(profile)
	local observation = profile and profile.pvpObservation;
	local checked = observation and tonumber(observation.checkedAt) or 0;
	if (checked <= 0 or (observation.source ~= "applied" and observation.source ~= "named" and observation.source~="full-inspect")) then return false; end
	if (observation.source=="full-inspect" and (not UnBotTalentInfo or profile.talentSnapshotStale or UnBotTalentInfo.Get(profile).mode~="pvp")) then return false; end
	if (UnBotTalentInfo and profile.talentSnapshot and UnBotFullTalentCatalog.Get(profile.className,profile.level)
		and UnBotTalentInfo.Get(profile).mode~="pvp") then return false; end
	if (profile.pveObservation and profile.pveObservation.source~="converted-pvp" and (tonumber(profile.pveObservation.checkedAt) or 0) >= checked) then return false; end
	if ((tonumber(profile.specCheckedAt) or 0) > checked) then
		local build = profile.talentBuild;
		if (not build and profile.rawWho) then
			local a,b,c = UnBotPVPSummon.Clean(profile.rawWho):match("%((%d+)[/%-](%d+)[/%-](%d+)%)");
			if (a) then build = a.."-"..b.."-"..c; end
		end
		if (build and UnBotPVPSummon.Clean(build):gsub("/","-") ~= observation.build) then return false; end
	end
	return true;
end

function UnBotPVPSummon.RosterAssignments()
	local s, t, state = UnBotPVPSummon, UnBotPVPSquad.transport, UnBotPVPSquad.State();
	local assigned, claimed, attempted, names = {}, {}, {}, {};
	if (not state or not t or not t.Roster or not UnBotRegistryMatchesCurrentContext(UnBotBotRegistry)) then return assigned; end
	local current = s.signature == UnBotPVPSummon.Signature() and s.context == UnBotRegistryCurrentContext() and not s.catalogOnly;
	if (current) then
		for _, entry in ipairs(s.items or {}) do
			attempted[entry.name] = true;
			local slot, unit = state.slots[entry.slotIndex], UnBotPVPSummon.Unit(entry.name);
			local verified = entry.ready and UnBotPVPSummon.ObservationValid(UnBotBotRegistry.bots and UnBotBotRegistry.bots[entry.name]);
			if (slot and unit and not entry.failed and (verified or s.active) and not claimed[entry.name]) then
				assigned[entry.slotIndex] = assigned[entry.slotIndex] or {};
				claimed[entry.name] = true;
				table.insert(assigned[entry.slotIndex],{name=entry.name, online=UnitIsConnected(unit),
					ready=verified and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit)});
			end
		end
	end
	for name in pairs(t.Roster() or {}) do table.insert(names,name); end
	table.sort(names);
	-- Reload loses controller items, but verified profile observations persist.
	-- A later PvE application or contradictory who supersedes that observation.
	for pass = 1, 2 do
		for index, slot in ipairs(state.slots) do
			if ((slot.specKey == "any") == (pass == 2)) then
				assigned[index] = assigned[index] or {};
				for _, name in ipairs(names) do
					local p = UnBotBotRegistry.bots and UnBotBotRegistry.bots[name];
					local display, mode = UnBotPVPSummon.RosterProfile(p);
					local unit = UnBotPVPSummon.Unit(name);
					if (not claimed[name] and not attempted[name] and unit and mode == "pvp"
						and not UnBotIsAccountAltProfile(name,p)
						and not UnBotSquadRosterIsOfflineReserve(name)
						and #assigned[index] < UnBotPVPSquad.Count(slot)
						and t.Matches(display,slot.className,slot.specKey)) then
						claimed[name] = true;
						table.insert(assigned[index],{name=name,online=UnitIsConnected(unit),
							ready=UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit)});
					end
				end
			end
		end
	end
	return assigned;
end

-- Use verified talents/observations, including the post-apply role when the
-- legacy registry branch still contains the pre-application specialization.
function UnBotPVPSummon.RosterProfile(profile)
	if (not profile or not UnBotRegistryMatchesCurrentContext(UnBotBotRegistry)
		or UnBotIsAccountAltProfile(profile.name,profile)) then return profile,"pve"; end
	local role;
	if (UnBotPVPSummon.ObservationValid(profile)) then
		role = UnBotPVPSummon.Clean(profile.pvpObservation.preset):match("^(.-)%s+pvp$");
	elseif (UnBotTalentInfo) then
		local info = UnBotTalentInfo.Get(profile);
		local checked = tonumber(info.checkedAt) or 0;
		local newerPVE = profile.pveObservation and profile.pveObservation.source ~= "converted-pvp"
			and (tonumber(profile.pveObservation.checkedAt) or 0) >= checked;
		local changedWho = (tonumber(profile.specCheckedAt) or 0) > checked
			and profile.talentBuild and profile.talentSnapshot
			and profile.talentBuild:gsub("/","-") ~= profile.talentSnapshot.build;
		if (info.mode == "pvp" and not newerPVE and not changedWho) then role = info.specRole; end
	end
	if (not role or role == "") then return profile,"pve"; end
	local display = {};
	for key,value in pairs(profile) do display[key] = value; end
	local aliases = UnBotPVPSquad.transport and UnBotPVPSquad.transport.SpecAliases[role];
	display.specName = aliases and aliases[1] or role;
	if (aliases and aliases.feralRole) then display.feralRole = aliases.feralRole; end
	if (profile.className == "druid") then
		if (role == "bear" or role == "cat") then
			display.specName,display.feralRole = "feral combat",role;
		elseif (role == "feral bear" or role == "feral cat") then
			display.specName,display.feralRole = "feral combat",role:match("feral (%S+)");
		end
	end
	return display,"pvp";
end

function UnBotPVPSummon.ReservedNames()
	local names = {};
	for _, members in pairs(UnBotPVPSummon.RosterAssignments()) do
		for _, member in ipairs(members) do names[member.name] = true; end
	end
	local pve = UnBotPVPSquad.transport and UnBotPVPSquad.transport.PVEOwner;
	if (pve and pve.squad and (pve.active or (UnBotSquadSummon and UnBotSquadSummon.active
		and UnBotSquadSummon.pveComplete and pve.squad.pvpSignature == UnBotPVPSummon.Signature()))) then
		for name in pairs(pve.squad.pvpNames or {}) do names[name] = true; end
	end
	return names;
end

-- Plan both lists before PvE can classify a current member as surplus.
-- Explicit named PvE slots win; confirmed PvP assignments then retain their
-- mode, and exact roles precede class-only rows in each independent list.
function UnBotPVPSummon.PlanExisting(pveSlots)
	local t, state = UnBotPVPSquad.transport, UnBotPVPSquad.State();
	local assigned, reserved, claimed, names = {}, {}, {}, {};
	if (not t or not state or not UnBotRegistryMatchesCurrentContext(UnBotBotRegistry)) then return assigned, reserved; end
	pveSlots = pveSlots or UnBotSquadConfig.slots or {};
	for _, slot in ipairs(pveSlots) do
		if (slot.accountAltName) then claimed[slot.accountAltName] = true; end
	end
	for name in pairs(t.Roster() or {}) do
		local p, unit = UnBotBotRegistry.bots and UnBotBotRegistry.bots[name], UnBotPVPSummon.Unit(name);
		if (p and unit and UnitIsConnected(unit) and not t.ActiveFlag(p)
			and not UnBotIsAccountAltProfile(name,p) and not UnBotSquadRosterIsOfflineReserve(name)) then
			table.insert(names,name);
		end
	end
	table.sort(names);
	local pve = t.PVEOwner;
	if (UnBotSquadSummon and UnBotSquadSummon.active and UnBotSquadSummon.pveComplete
		and pve and pve.squad and pve.squad.pvpSignature == UnBotPVPSummon.Signature()) then
		-- Carry unconfirmed current candidates through the PvE -> PvP handoff;
		-- their own bounded who/preset pass will decide readiness.
		for index, members in pairs(pve.squad.pvpAssignments or {}) do
			assigned[index] = {};
			for _, name in ipairs(members) do
				local p, unit = UnBotBotRegistry.bots[name], UnBotPVPSummon.Unit(name);
				if (not claimed[name] and p and unit and UnitIsConnected(unit)
					and not t.ActiveFlag(p) and not UnBotIsAccountAltProfile(name,p)
					and not UnBotSquadRosterIsOfflineReserve(name)) then
					claimed[name], reserved[name] = true, true;
					table.insert(assigned[index],name);
				end
			end
		end
	end
	for index, members in pairs(UnBotPVPSummon.RosterAssignments()) do
		assigned[index] = assigned[index] or {};
		for _, member in ipairs(members) do
			local p = UnBotBotRegistry.bots and UnBotBotRegistry.bots[member.name];
			if (not claimed[member.name] and member.online and p and not t.ActiveFlag(p)
				and UnBotPVPSummon.ObservationValid(p)) then
				claimed[member.name], reserved[member.name] = true, true;
				table.insert(assigned[index],member.name);
			end
		end
	end
	for pass = 1, 2 do
		for _, slot in ipairs(pveSlots) do
			if (not slot.accountAltName and not slot.reserveOnly and ((slot.specKey == "any") == (pass == 2))) then
				local count = 0;
				for _, name in ipairs(names) do
					if (not claimed[name] and count < (tonumber(slot.need or slot.count) or 1)
						and t.Matches(UnBotBotRegistry.bots[name],slot.className,slot.specKey)) then
						claimed[name], count = true, count + 1;
					end
				end
			end
		end
	end
	for pass = 1, 2 do
		for index, slot in ipairs(state.slots or {}) do
			if ((slot.specKey == "any") == (pass == 2)) then
				assigned[index] = assigned[index] or {};
				for _, name in ipairs(names) do
					local unit = UnBotPVPSummon.Unit(name);
					if (not claimed[name] and not UnitIsDeadOrGhost(unit) and #assigned[index] < UnBotPVPSquad.Count(slot)
						and t.Matches(UnBotBotRegistry.bots[name],slot.className,slot.specKey)) then
						claimed[name], reserved[name] = true, true;
						table.insert(assigned[index],name);
					end
				end
			end
		end
	end
	return assigned, reserved;
end

function UnBotPVPSummon.SlotStatus(index, assigned)
	local s, state, ready = UnBotPVPSummon, UnBotPVPSquad.State(), 0;
	local slot = state and state.slots[index];
	local members = (assigned or UnBotPVPSummon.RosterAssignments())[index] or {};
	for _, member in ipairs(members) do
		if (member.ready) then ready = ready + 1; end
	end
	local needed = slot and UnBotPVPSquad.Count(slot) or 1;
	if (ready >= needed) then return "ready",ready,needed; end
	if (s.signature == UnBotPVPSummon.Signature() and not s.catalogOnly) then
		if (s.blocked and s.blocked[index]) then return "failed",ready,needed; end
		if (s.active) then return "pending",ready,needed; end
		for _, entry in ipairs(s.items or {}) do
			if (entry.slotIndex == index and entry.failed) then return "failed",ready,needed; end
		end
	end
	if (#members > 0 and ready == 0) then return "unavailable",ready,needed; end
	return ready > 0 and "partial" or "idle",ready,needed;
end

function UnBotPVPSummon.SlotText(index, assigned)
	local s, names = UnBotPVPSummon, {};
	assigned = assigned or UnBotPVPSummon.RosterAssignments();
	local status, ready, needed = UnBotPVPSummon.SlotStatus(index,assigned);
	for _, member in ipairs(assigned[index] or {}) do
		if (member.ready) then table.insert(names,member.name); end
	end
	if (status == "ready") then
		local converted,applied = 0,0;
		for _, member in ipairs(assigned[index] or {}) do
			local p = UnBotBotRegistry.bots[member.name];
			if (member.ready and p and p.pvpObservation and p.pvpObservation.origin=="converted-pve") then converted=converted+1; end
			if (member.ready and p and p.pvpObservation and p.pvpObservation.origin=="applied") then applied=applied+1; end
		end
		return table.concat(names,", ").." — готово"..(converted>0 and ("; из PvE в PvP: "..converted)
			or (applied>0 and ("; пресет применён: "..applied) or " (готовый PVP)"));
	end
	if (status == "failed") then return (s.blocked and s.blocked[index]) or ("PVP: готово "..ready.."/"..needed.."; "..(s.endReasons and s.endReasons[index] or "подготовка не завершена")); end
	if (status == "pending") then return "PVP: подготовка — готово "..ready.."/"..needed; end
	if (status == "unavailable") then
		for _, member in ipairs(assigned[index] or {}) do table.insert(names,member.name); end
		return table.concat(names,", ").." — офлайн / не готов";
	end
	if (#names > 0) then return table.concat(names,", ").." — готово "..ready.."/"..needed; end
	return "PVP: ожидает призыва / подтверждения";
end

function UnBotPVPSummon.Start()
	if (UnBotFullTalentCatalog and UnBotFullTalentCatalog.IsBusy()) then
		UnBotPVPSummon.Message("сначала завершите сбор полного каталога талантов"); return false;
	end
	if (UnBotGunshipMasterLoot and UnBotGunshipMasterLoot.paused) then
		return UnBotGunshipMasterLoot.ResumeSummon();
	end
	local s, t = UnBotPVPSummon, UnBotPVPSquad.transport;
	if (s.active) then UnBotPVPSummon.Message("призыв уже идёт"); return false; end
	if (not t or t.Busy()) then UnBotPVPSummon.Message("сначала завершите другую операцию UnBot"); return false; end
	if (UnitAffectingCombat("player") or InCombatLockdown()) then UnBotPVPSummon.Message("запуск доступен вне боя"); return false; end
	if ((GetNumRaidMembers() > 0 and not IsRaidLeader() and not IsRaidOfficer())
		or (GetNumRaidMembers() == 0 and GetNumPartyMembers() > 0 and not IsPartyLeader())) then
		UnBotPVPSummon.Message("для приглашений нужен лидер группы или помощник рейда"); return false;
	end
	if (next(s.cleanup)) then UnBotPVPSummon.Message("дождитесь завершения очистки предыдущих кандидатов (до 30 секунд)"); return false; end
	s.catalogOnly = false;
	s.resetAI,s.resetAIDone,s.talentsChanged = nil,false,false;
	t.Attach();
	if (not UnBotRegistryMatchesCurrentContext(UnBotBotRegistry)) then UnBotPVPSummon.Message("реестр не соответствует серверу и фракции"); return false; end
	if (not UnBotSpecSummonPlayerSupportsSpecs()) then UnBotPVPSummon.Message("PVP-пресеты доступны с 11 уровня"); return false; end
	local state = UnBotPVPSquad.State();
	if (not state or #state.slots == 0) then UnBotPVPSummon.Message("сначала выберите PVP-участников"); return false; end
	s.existingAssignments = UnBotPVPSummon.PlanExisting();
	s.requirements, s.items, s.used, s.blocked, s.catalogs = {}, {}, {}, {}, {};
	s.candidateAttempts, s.endReasons, s.opSerial = {}, {}, 0;
	s.fallback, s.deferred, s.fallbackUsed = false, {}, {};
	s.allowPVEFallback = state.allowPVEFallback~=false;
	s.original, s.protected = {}, t.Protected();
	for name in pairs(UnBotBotRegistry.bots or {}) do
		if (UnBotPVPSummon.Unit(name)) then s.original[name] = true; end
	end
	s.total = UnBotPVPSquad.Total(state);
	for index, slot in ipairs(state.slots) do
		if (not UnBotPVPSquad.FindSpec(slot.className, slot.specKey)) then
			UnBotPVPSummon.Message("неизвестная позиция "..index); return false;
		end
		local count = UnBotPVPSquad.Count(slot);
		table.insert(s.requirements, {slotIndex = index, className = slot.className, specKey = slot.specKey, count = count,
			candidateLimit = math.max(12,count*6)});
	end
	-- Exact roles claim candidates before class-only requests.
	table.sort(s.requirements, function(a,b)
		if ((a.specKey == "any") ~= (b.specKey == "any")) then return a.specKey ~= "any"; end
		return a.slotIndex < b.slotIndex;
	end);
	s.active, s.round, s.lastSend, s.op = true, 0, GetTime() - 3, nil;
	if (UnBotSummonLog and (not UnBotSquadSummon or not UnBotSquadSummon.active or not UnBotSummonLog.current)) then
		UnBotSummonLog.Safe("Begin","","pvp");
	end
	s.signature, s.context = UnBotPVPSummon.Signature(), UnBotRegistryCurrentContext();
	s.deadline = GetTime() + math.max(180, s.total * 75);
	s.nativeDeadline = GetTime() + math.max(60,s.total*40);
	if (UnBotGunshipMasterLoot and UnBotGunshipMasterLoot.BeginSummon) then
		UnBotGunshipMasterLoot.BeginSummon();
		if (not s.active) then return false; end
	end
	UnBotPVPSummon.Message("начинаю отдельный призыв: "..s.total.." ботов; новые команды через 1 секунду, повторы через 3 секунды, до 3 отправок");
	UnBotPVPSummon.Refill();
	return true;
end

function UnBotPVPSummon.Refill()
	local s, t = UnBotPVPSummon, UnBotPVPSquad.transport;
	local selectionAt = GetTime();
	local selectionCPU = debugprofilestop and debugprofilestop();
	local missing = false;
	for _, requirement in ipairs(s.requirements) do
		local ready = 0;
		for _, entry in ipairs(s.items) do if (entry.slotIndex == requirement.slotIndex and entry.ready) then ready = ready + 1; end end
		if (ready < requirement.count and not s.blocked[requirement.slotIndex]) then missing = true; end
	end
	if (not missing) then UnBotPVPSummon.Finish(); return; end
	if (not s.fallback and s.allowPVEFallback and GetTime()>=s.nativeDeadline) then
		UnBotPVPSummon.BeginFallback(); return;
	end
	s.round = s.round + 1;
	local added, cached = 0, 0;
	for _, requirement in ipairs(s.requirements) do
		local ready = 0;
		for _, entry in ipairs(s.items) do if (entry.slotIndex == requirement.slotIndex and entry.ready) then ready = ready + 1; end end
		local attempts = s.candidateAttempts[requirement.slotIndex] or 0;
		if (ready < requirement.count and not s.blocked[requirement.slotIndex]
			and attempts < requirement.candidateLimit) then
			local excluded = {};
			for name in pairs(s.protected) do excluded[name] = true; end
			for name in pairs(s.used) do
				if (not s.fallback or not s.deferred[name]) then excluded[name] = true; end
			end
			for name in pairs(s.fallbackUsed) do excluded[name] = true; end
			local candidates, queued = {}, {};
			for _, name in ipairs(s.existingAssignments[requirement.slotIndex] or {}) do
				if (not excluded[name]) then table.insert(candidates,name); queued[name] = true; end
			end
			local registry = t.Candidates(requirement.className, requirement.specKey, excluded);
			local priorities = {};
			for _, name in ipairs(registry) do
				local profile = UnBotBotRegistry.bots[name];
				local mode = s.fallback and "pve" or "pvp";
				local known = (not s.fallback and UnBotPVPSummon.ObservationValid(profile))
					or (UnBotTalentInfo and UnBotTalentInfo.Get(profile).mode==mode);
				priorities[name] = UnBotPVPSummon.Unit(name) and 1
					or (known and (not UnBotTalentInfo or UnBotTalentInfo.Coarse(profile,requirement.className,requirement.specKey,mode)~=false) and 2) or 3;
			end
			-- An available current member always wins over an offline LRU hint.
			for pass = 1, 3 do
				for _, name in ipairs(registry) do
					if (not queued[name] and priorities[name] == pass) then
						table.insert(candidates,name); queued[name] = true;
					end
				end
			end
			local needed = requirement.count - ready;
			local selected = 0;
			for _, name in ipairs(candidates) do
				if (needed <= 0 or attempts >= requirement.candidateLimit) then break end
				local unit = UnBotPVPSummon.Unit(name);
				local compatible = not UnBotTalentInfo or UnBotTalentInfo.CachedMayMatch(UnBotBotRegistry.bots[name],requirement.className,requirement.specKey,"pvp")~=false;
				if (s.fallback) then
					local profile = UnBotBotRegistry.bots[name];
					local targets = UnBotTalentInfo and UnBotTalentInfo.SelectionTemplates(requirement.className,requirement.specKey,"pvp",tonumber(profile.level) or 80);
					compatible = targets and #targets>0 and UnBotTalentInfo.Coarse(profile,requirement.className,requirement.specKey,"pve")~=false;
				end
				if ((not unit or (UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit))) and compatible) then
					s.used[name], excluded[name] = true, true;
					local entry;
					if (s.fallback) then
						s.fallbackUsed[name],s.cleanup[name] = true,nil;
						for _, old in ipairs(s.items) do if (old.name==name) then entry=old; break end end
					end
					if (not entry) then entry={name=name,new=not s.original[name]}; table.insert(s.items,entry); end
					if (s.fallback and not unit) then entry.addAck,entry.recorded=nil,nil; end
					entry.slotIndex,entry.className,entry.specKey = requirement.slotIndex,requirement.className,requirement.specKey;
					entry.round,entry.createdAt,entry.convertFromPVE = s.round,GetTime(),s.fallback;
					entry.failed,entry.ready,entry.reason,entry.prepared,entry.step,entry.current,entry.target,entry.who,entry.ack=nil,nil,nil,nil,nil,nil,nil,nil,nil;
					entry.cacheReused=nil;
					local owner=t.PVEOwner;
					if not s.fallback and owner and owner.confirmedRoster and owner.confirmedRoster.ReusePVP(entry) then cached=cached+1;end
					needed, added = needed - 1, added + 1;
					attempts, selected = attempts + 1, selected + 1;
				end
			end
			s.candidateAttempts[requirement.slotIndex] = attempts;
			if (selected == 0) then s.endReasons[requirement.slotIndex] = s.fallback and "нет доступного PvE-кандидата с полным PvP-шаблоном этой роли/уровня" or "доступные кандидаты закончились"; end
		end
		if (ready < requirement.count and attempts >= requirement.candidateLimit) then
			s.endReasons[requirement.slotIndex] = "исчерпан лимит кандидатов ("..attempts..")";
		end
	end
	if cached>0 then UnBotPVPSummon.Message("Повторный добор: сохранены свежие PvP-подтверждения "..cached.."; повторная проверка не требуется.");end
	if (UnBotSummonLog and not s.catalogOnly) then
		UnBotSummonLog.Safe("Add","selection","pvp refill",nil,"round="..s.round.." added="..added
			.." elapsedMs="..math.floor((GetTime()-selectionAt)*1000+.5)
			.." cpuMs="..tostring(selectionCPU and (debugprofilestop()-selectionCPU)));
	end
	if (added == 0) then
		if (not s.fallback and s.allowPVEFallback) then UnBotPVPSummon.BeginFallback();
		else UnBotPVPSummon.Finish(); end
		return;
	end
	UnBotPVPSummon.Phase("summon",s.fallback and "добор из PvE: сбор и проверка исходных талантов" or "сбор, прибытие и ранняя проверка спеков");
end

function UnBotPVPSummon.BeginFallback()
	local s = UnBotPVPSummon;
	s.nativeCandidateAttempts,s.nativeEndReasons = s.candidateAttempts,s.endReasons;
	s.fallback,s.candidateAttempts,s.endReasons = true,{},{};
	UnBotPVPSummon.Message("готовых PVP не хватило; начинаю добор из PvE той же специализации");
	if (UnBotSummonLog) then UnBotSummonLog.Safe("Add","fallback_start","pve-to-pvp"); end
	UnBotPVPSummon.Refill();
end

function UnBotPVPSummon.Defer(entry, reason)
	local s = UnBotPVPSummon;
	if (s.allowPVEFallback and not s.fallback and entry.who and UnBotTalentInfo
		and UnBotTalentInfo.Coarse(entry.who,entry.className,entry.specKey,"pve")==true) then
		s.deferred[entry.name] = true;
		UnBotPVPSummon.Fail(entry,"кандидат оставлен для добора из PvE: "..tostring(reason),false);
		return;
	end
	UnBotPVPSummon.Fail(entry,reason,false);
end

function UnBotPVPSummon.PrepareConversion(entry)
	local s = UnBotPVPSummon;
	s.op,s.inspectEntry = nil,entry;
	UnBotTalentInfo.ConfirmSelection(entry.name,entry.who,entry.className,entry.specKey,"pve",s,function(snapshot,source,reason)
		s.inspectEntry=nil; UnBotPVPSummon.LogWait(nil);
		if (not snapshot or UnBotPVPSummon.Protected(entry.name)) then UnBotPVPSummon.Fail(entry,reason or "кандидат защищён",false); return; end
		local role = UnBotTalentInfo.Role(entry.className,source.name);
		local targets = UnBotTalentInfo.SelectionTemplates(entry.className,role,"pvp",snapshot.level) or {};
		table.sort(targets,function(a,b) return a.name<b.name; end);
		if (#targets==0) then UnBotPVPSummon.Fail(entry,"нет полного PvP-шаблона той же специализации и уровня",false); return; end
		entry.target,entry.sourcePreset,entry.prepared = targets[1],source.name,true;
		UnBotPVPSummon.Message(entry.name..": подтверждён "..source.name.."; добор через "..entry.target.name);
		if (UnBotSummonLog) then UnBotSummonLog.Safe("Add","conversion_plan",source.name.." -> "..entry.target.name,entry.name); end
	end,function() return s.active and s.inspectEntry==entry and not entry.failed; end);
end

function UnBotPVPSummon.ConfirmConversion(entry, current)
	local s,p = UnBotPVPSummon,UnBotBotRegistry.bots[entry.name];
	s.op,s.inspectEntry = nil,entry;
	p.talentBuild = current.build:gsub("-","/");
	UnBotTalentInfo.Begin(entry.name,s,function(snapshot,reason)
		s.inspectEntry=nil; UnBotPVPSummon.LogWait(nil);
		if (not snapshot or UnBotPVPSummon.Protected(entry.name)) then UnBotPVPSummon.Fail(entry,reason or "кандидат защищён",false); return; end
		if (UnBotTalentInfo.Get(p).mode~="pvp") then UnBotPVPSummon.Fail(entry,"полные таланты не определяют PvP однозначно",false); return; end
		entry.ready,entry.confirmation,entry.origin = true,"full-inspect","converted-pve";
		UnBotPVPSummon.Observe(entry,{name=entry.target.name,build=snapshot.build},"full-inspect");
		UnBotPVPSummon.Message(entry.name..": переведён из PvE; "..entry.target.name.." подтверждён полными талантами");
		UnBotPVPSquad.Refresh();
	end,function() return s.active and s.inspectEntry==entry and not entry.failed; end,entry.target.snapshot);
end

function UnBotPVPSummon.Phase(phase, label)
	local s = UnBotPVPSummon;
	UnBotPVPSummon.LogWait(nil);
	s.phase, s.phaseLabel, s.index, s.op = phase, label, 1, nil;
	UnBotPVPSummon.Message("этап: "..label);
	UnBotPVPSquad.Refresh();
end

function UnBotPVPSummon.Request(entry, kind, command)
	local s = UnBotPVPSummon;
	s.opSerial = (s.opSerial or 0) + 1;
	s.op = {entry = entry, kind = kind, command = command, attempts = 0, id = s.opSerial,
		createdAt = GetTime(), at = math.max(GetTime(), s.lastSend + s.sendInterval)};
	UnBotPVPSummon.LogOperation("op_begin",s.op,"queued");
	if (s.op.at > GetTime()) then UnBotPVPSummon.LogWait("send_interval",s.op); end
end

function UnBotPVPSummon.Occupied()
	return math.max(1 + GetNumPartyMembers(), GetNumRaidMembers());
end

function UnBotPVPSummon.MemberLimit()
	if (not IsInInstance()) then return 40; end
	return UnBotBuffCycleResolveMemberLimit();
end

function UnBotPVPSummon.ResetAIEligible(name)
	for _,slot in ipairs(UnBotSquadConfig.slots or {}) do
		if (slot.accountAltName==name) then return false; end
	end
	local profile = UnBotBotRegistry.bots and UnBotBotRegistry.bots[name];
	local unit = UnBotPVPSummon.Unit(name);
	return profile and name ~= UnitName("player") and unit and UnitIsConnected(unit)
		and not UnBotIsAccountAltProfile(name,profile) and not UnBotSquadRosterIsOfflineReserve(name);
end

function UnBotPVPSummon.BeginResetAI()
	local s = UnBotPVPSummon;
	if (s.resetAIDone) then return false; end
	if (s.resetAI) then return true; end
	local changed = s.talentsChanged or (UnBotSquadSummon and UnBotSquadSummon.active and UnBotSquadSummon.talentsChanged);
	if (not changed) then return false; end
	local names = {};
	for name in pairs(UnBotBotRegistry.bots or {}) do
		if (UnBotPVPSummon.ResetAIEligible(name) and not s.cleanup[name]) then table.insert(names,name); end
	end
	table.sort(names);
	if (#names==0) then s.resetAIDone=true; return false; end
	-- Address ordinary bots individually: a RAID/PARTY broadcast would also reset alts.
	s.resetAI={names=names,index=1,answers={},sent={},nextAt=math.max(GetTime(),s.lastSend+s.sendInterval)};
	s.phase,s.phaseLabel,s.op = "reset-ai","сброс AI обычных ботов",nil;
	s.deadline=math.max(s.deadline,s.resetAI.nextAt+#names*s.sendInterval+13);
	UnBotPVPSummon.Message("таланты менялись; в конце цикла сбрасываю AI обычных онлайн-ботов: "..#names..". Альты и офлайн-резерв исключены");
	if (UnBotSummonLog) then UnBotSummonLog.Safe("Add","reset_ai_begin",tostring(#names)); end
	UnBotPVPSquad.Refresh();
	return true;
end

function UnBotPVPSummon.ResetAIReply(event,message,sender)
	local reset=UnBotPVPSummon.resetAI;
	if (not reset or event~="CHAT_MSG_WHISPER") then return; end
	local clean=UnBotPVPSummon.Clean(message);
	local author=UnBotPVPSummon.Clean(tostring(sender or ""):match("^[^-]+"));
	for name in pairs(reset.sent) do
		if (UnBotPVPSummon.Clean(name)==author and not reset.answers[name]) then
			if (clean:find("ai was reset to defaults",1,true)) then reset.answers[name]="ok";
			elseif (clean:find("unknown command",1,true) or clean:find("cannot cast",1,true)
				or clean:find("unknown spell",1,true) or clean:find("no items",1,true)
				or clean:find("too low",1,true) or clean:find("i'll do it later",1,true)
				or clean:find("i will do it later",1,true)) then reset.answers[name]="refused"; end
			if (reset.answers[name] and UnBotSummonLog) then UnBotSummonLog.Safe("Add","reset_ai_reply",reset.answers[name],name); end
			return;
		end
	end
end

function UnBotPVPSummon.TickResetAI()
	local s,now=UnBotPVPSummon,GetTime();
	local reset=s.resetAI;
	for _,name in ipairs(reset.names) do
		local unit=UnBotPVPSummon.Unit(name);
		if (unit and UnitIsConnected(unit) and UnitAffectingCombat(unit)) then
			UnBotPVPSummon.Stop("сброс AI остановлен: участник вступил в бой; повторов нет"); return;
		end
	end
	if (reset.index<=#reset.names and now>=reset.nextAt) then
		local name=reset.names[reset.index];
		reset.index,reset.nextAt=reset.index+1,now+s.sendInterval;
		-- Recheck ownership/online state immediately before every command.
		if (UnBotPVPSummon.ResetAIEligible(name) and not s.cleanup[name]) then
			reset.sent[name],s.lastSend=now,now;
			if (UnBotSummonLog) then UnBotSummonLog.Safe("Add","reset_ai_send","reset botAI",name); end
			SendChatMessage("reset botAI","WHISPER",nil,name);
		else reset.answers[name]="skipped"; end
	end
	if (reset.index<=#reset.names) then return; end
	local sent,confirmed,missing=0,0,{};
	for _,name in ipairs(reset.names) do
		if (reset.sent[name]) then
			sent=sent+1;
			if (not reset.answers[name] and now<reset.sent[name]+12) then return; end
			if (reset.answers[name]=="ok") then confirmed=confirmed+1;
			else table.insert(missing,name); end
		end
	end
	UnBotPVPSummon.Message("сброс AI: подтверждено "..confirmed.."/"..sent.."; повторов нет"
		..(#missing>0 and (". Нет подтверждения: "..table.concat(missing,", ")) or "."));
	if (UnBotSummonLog) then UnBotSummonLog.Safe("Add","reset_ai_end",confirmed.."/"..sent,table.concat(missing,", ")); end
	s.resetAI,s.resetAIDone=nil,true;
	UnBotPVPSummon.Finish();
end

function UnBotPVPSummon.Finish()
	if (UnBotGunshipMasterLoot and UnBotGunshipMasterLoot.CheckSummon
		and not UnBotGunshipMasterLoot.CheckSummon(true)) then return; end
	if (UnBotPVPSummon.BeginResetAI()) then return; end
	local s, ready, applied, preserved, full, converted = UnBotPVPSummon, 0, 0, 0, 0, 0;
	UnBotPVPSummon.LogWait(nil);
	for _, entry in ipairs(s.items or {}) do
		if (entry.ready) then
			ready = ready + 1;
			if (entry.origin=="converted-pve") then converted=converted+1; end
			if (entry.confirmation == "preserved") then preserved = preserved + 1;
			elseif (entry.origin == "applied" or entry.confirmation == "applied") then applied = applied + 1;
			elseif (entry.confirmation == "full-inspect") then full=full+1; end
		end
	end
	s.active, s.op = false, nil;
	local reasons = {};
	for _, requirement in ipairs(s.requirements or {}) do
		local have = 0;
		for _, entry in ipairs(s.items or {}) do if (entry.slotIndex == requirement.slotIndex and entry.ready) then have = have + 1; end end
		if (have < requirement.count) then
			local reason = s.blocked[requirement.slotIndex] or (s.endReasons and s.endReasons[requirement.slotIndex]) or "подбор не завершён";
			table.insert(reasons,requirement.className.." / "..requirement.specKey..": "..have.."/"..requirement.count.." — "..reason);
		end
	end
	if (UnBotSummonLog) then UnBotSummonLog.Safe("Result","pvp",ready == s.total and "completed" or "partial",table.concat(reasons,"; "),s.total,ready); end
	if (UnBotGunshipMasterLoot) then UnBotGunshipMasterLoot.summonGuard = false; end
	UnBotPVPSummon.Message("подготовка завершена: "..ready.."/"..s.total.."; дефицит "..(s.total - ready)
		..". Полными талантами подтверждено "..full.."; пресет применён и текущее состояние проверено у "..applied.."; имя пресета сервер вернул у "..(ready - applied - preserved - full)
		.."; уже в составе подтверждено "..preserved..". Переведено из PvE: "..converted.."; готовых PVP найдено: "..(ready-applied-converted)..".");
	for _, reason in ipairs(reasons) do UnBotPVPSummon.Message(reason); end
	if (ready == s.total and UnBotSquadLoot) then
		if (UnBotSquadSummon and UnBotSquadSummon.active) then UnBotSquadSummon.lootPending = true;
		else UnBotSquadLoot.Auto(); end
	end
	UnBotPVPSquad.Refresh();
end

function UnBotPVPSummon.Target(entry)
	local s, t = UnBotPVPSummon, UnBotPVPSquad.transport;
	local specKey = entry.specKey;
	if (specKey == "any") then specKey = entry.who.feralRole or entry.who.specName; end
	for _, template in ipairs(entry.catalog or {}) do
		local prefix = UnBotPVPSummon.Clean(template.name):match("^(.-)%s+pvp$");
		if (prefix and t.Matches({className=entry.className, specName=prefix, feralRole=prefix}, entry.className, specKey)) then
			entry.target = template;
			local profile = UnBotBotRegistry.bots[entry.name];
			local observation = profile and profile.pvpObservation;
			local build = entry.who and UnBotPVPSummon.Clean(entry.who.talentBuild):gsub("/","-");
			local a,b,c = UnBotPVPSummon.Clean(profile and profile.rawWho):match("%((%d+)[/%-](%d+)[/%-](%d+)%)");
			if (build == "") then
				build = a and (a.."-"..b.."-"..c);
			end
			local points = a and (tonumber(a)+tonumber(b)+tonumber(c));
			if (not entry.new and observation and UnBotPVPSummon.ObservationValid(profile)
				and UnBotPVPSummon.Clean(observation.preset) == UnBotPVPSummon.Clean(template.name)
				and build == observation.build
				and ((entry.who.level == 80 and build == template.build)
					or (entry.who.level and entry.who.level < 80 and points == entry.who.level - 9))
				and t.Matches(entry.who,entry.className,specKey)) then
				entry.ready, entry.confirmation = true, "preserved";
				UnBotPVPSummon.CandidateResult(entry,"ready","preserved");
				local owner=UnBotPVPSquad.transport.PVEOwner;
				if owner and owner.confirmedRoster then owner.confirmedRoster.PVP(entry);end
				UnBotPVPSummon.Message(entry.name..": сохранённый "..template.name.." подтверждён who; смена не нужна");
			elseif (entry.current and entry.current.name == UnBotPVPSummon.Clean(template.name)) then
				entry.ready, entry.confirmation = true, "named";
				UnBotPVPSummon.Observe(entry,entry.current,"named");
				UnBotPVPSummon.Message(entry.name..": текущий пресет "..template.name..", смена не нужна");
			end
			if (not entry.ready and s.allowPVEFallback==false) then
				UnBotPVPSummon.Fail(entry,"смена талантов отключена; текущий PvP-пресет не подтверждён",false);
			end
			return;
		end
	end
	s.blocked[entry.slotIndex] = "Нет серверного PVP-шаблона для этой роли";
	UnBotPVPSummon.Fail(entry, "в серверном каталоге нет PVP-шаблона для выбранной роли", false);
end

function UnBotPVPSummon.InspectCandidate(entry)
	local s=UnBotPVPSummon;
	s.op,s.inspectEntry=nil,entry;
	UnBotPVPSummon.Message(entry.name..": очки подходят; подтверждаю полный набор талантов PVP.");
	UnBotTalentInfo.ConfirmSelection(entry.name,entry.who,entry.className,entry.specKey,"pvp",s,function(snapshot,item,reason)
		s.inspectEntry=nil;
		UnBotPVPSummon.LogWait(nil);
		if (not snapshot) then UnBotPVPSummon.Defer(entry,reason); return; end
		entry.target,entry.ready,entry.confirmation=item,true,"full-inspect";
		entry.origin="native-pvp";
		UnBotPVPSummon.Observe(entry,{name=item.name,build=snapshot.build},"full-inspect");
		UnBotPVPSummon.Message(entry.name..": спек и PVP подтверждены полными талантами; смена не нужна");
		UnBotPVPSquad.Refresh();
	end,function() return s.active and s.inspectEntry==entry and not entry.failed; end);
end

function UnBotPVPSummon.Observe(entry, current, confirmation)
	local profile = UnBotBotRegistry.bots[entry.name];
	if (not profile) then return; end
	entry.origin = entry.origin or ((entry.ack or confirmation=="applied") and "applied" or "native-pvp");
	UnBotPVPSummon.CandidateResult(entry,"ready",confirmation);
	profile.pvpObservation = profile.pvpObservation or {};
	profile.pvpObservation.preset, profile.pvpObservation.build = entry.target.name, current.build;
	profile.pvpObservation.source, profile.pvpObservation.checkedAt = confirmation, time();
	profile.pvpObservation.origin,profile.pvpObservation.fromPreset = entry.origin,entry.sourcePreset;
	if (entry.origin=="converted-pve" and profile.pveObservation) then profile.pveObservation.source="converted-pvp"; end
	-- The pre-application who may describe another branch. Keep the verified
	-- result as the current registry hint instead of showing the old branch.
	profile.specName = current.name:gsub("%s+pvp$", "");
	profile.talentBuild, profile.specCheckedAt = current.build:gsub("-","/"), time();
	local role = UnBotPVPSummon.Clean(entry.target.name):match("^(.-)%s+pvp$");
	if (profile.className == "druid" and (role == "cat" or role == "bear")) then profile.feralRole = role; end
	local owner=UnBotPVPSquad.transport.PVEOwner;
	if owner and owner.confirmedRoster then owner.confirmedRoster.PVP(entry);end
end

function UnBotPVPSummon.Current(message)
	local clean = UnBotPVPSummon.Clean(message);
	local line = clean:match("my current talent spec is:%s*([^\n\r]+)");
	if (not line) then return nil; end
	local a,b,c = line:match("%((%d+)[/%-](%d+)[/%-](%d+)%)");
	local name = line:match("^(.-)%s*%(");
	if (not a or not name) then return nil; end
	return {line=line, name=name:match("^%s*(.-)%s*$"), build=a.."-"..b.."-"..c, points=tonumber(a)+tonumber(b)+tonumber(c)};
end

function UnBotPVPSummon.Verify(entry, current)
	local target, t = entry.target, UnBotPVPSquad.transport;
	if (current.name == UnBotPVPSummon.Clean(target.name)) then return true, "named"; end
	-- Legacy talents replies contain a branch, not the selected template name.
	-- A matching point summary NEVER skips application. After Picking <name>,
	-- it can only confirm the current branch/build of that explicit application.
	if (not entry.ack or current.name:find(" pve",1,true) or current.name:find(" pvp",1,true)) then return false; end
	local key = UnBotPVPSummon.Clean(target.name):match("^(.-)%s+pvp$");
	if (not t.Matches({className=entry.className,specName=current.name,feralRole=entry.who.feralRole},entry.className,key)) then
		-- Some servers report feral combat instead of cat/bear.
		if (entry.className ~= "druid" or not current.name:find("feral",1,true)) then return false; end
	end
	if (entry.who.level == 80) then return current.build == target.build, "applied"; end
	return current.points == math.max(0, (entry.who.level or 0) - 9), "applied";
end

function UnBotPVPSummon.Reply(event, message, sender)
	local s, op = UnBotPVPSummon, UnBotPVPSummon.op;
	if (s.active and s.resetAI) then UnBotPVPSummon.ResetAIReply(event,message,sender); return; end
	if (not s.active or not op or op.attempts == 0) then return; end
	local entry, clean = op.entry, UnBotPVPSummon.Clean(message);
	if (event == "CHAT_MSG_SYSTEM") then
		local added, result = clean:match("^add:%s*(.-)%s*%-%s*(.-)%s*$");
		if (op.kind == "join" and added == UnBotPVPSummon.Clean(entry.name) and result == "ok") then
			UnBotPVPSummon.LogOperation("op_ack",op,"add accepted; roster not yet confirmed");
			UnBotPVPSummon.LogWait(nil);
			entry.addAck, s.op = true, nil; return;
		end
		if ((op.kind == "join" or op.kind == "invite") and not UnBotPVPSummon.Unit(entry.name)
			and UnBotPVPSummon.SystemNames(clean,entry.name)) then
			if (clean:find("already logged in",1,true) or clean:find("already in group",1,true)
				or clean:find("уже в игре",1,true) or clean:find("уже состоит",1,true)
				or clean:find("not in your instance",1,true) or clean:find("не находится в вашем подземелье",1,true)) then
				if (clean:find("already in group",1,true) or clean:find("уже состоит",1,true)) then
					-- The server may know our membership before the local roster
					-- event arrives. One short grace, without repeating invite.
					if (not op.groupRefusalAt) then
						op.groupRefusalAt = GetTime()+1;
						UnBotPVPSummon.LogOperation("op_ack",op,"already in group; allow local roster to catch up");
					end
				else UnBotPVPSummon.Fail(entry, "сервер сообщил о недоступности приглашения", true); end
			end
		end
		return;
	end
	if (sender ~= entry.name) then return; end
	if (op.kind == "join" and clean == "hello!") then
		UnBotPVPSummon.LogOperation("op_ack",op,"Hello"); UnBotPVPSummon.LogWait(nil);
		entry.addAck, s.op = true, nil; return;
	end
	if (clean:find("i'll do it later",1,true) or clean:find("i will do it later",1,true)
		or clean:find("cannot cast",1,true) or clean:find("unknown command",1,true)
		or clean:find("unknown spell",1,true) or clean:find("no items",1,true)
		or clean:find("level too low",1,true) or clean:find("too low level",1,true)) then
		UnBotPVPSummon.Fail(entry, "сервер явно отказал: "..clean, op.kind == "join" or op.kind == "invite"); return;
	end
	if (op.kind == "who") then
		local who = UnBotParseBotWho(message);
		if (not who or not who.className or not who.specName) then return; end
		UnBotPVPSummon.LogOperation("op_ack",op,"who parsed"); UnBotPVPSummon.LogWait(nil);
		local profile = UnBotBotRegistry.bots[entry.name];
		if (not profile) then UnBotPVPSummon.Fail(entry,"профиль удалён из реестра",false); return; end
		profile.className, profile.specName, profile.level = who.className, who.specName, who.level;
		profile.rawWho, profile.talentBuild, profile.specCheckedAt = message, who.talentBuild, time();
		if (who.feralRole) then profile.feralRole = who.feralRole; end
		if (s.catalogOnly) then
			if (who.className ~= entry.className) then UnBotPVPSummon.Fail(entry,"сервер вернул другой класс",false); return; end
			entry.who, entry.step, s.op = who, "catalog", nil; return;
		end
		if (UnBotTalentInfo) then
			UnBotTalentInfo.ObserveWho(profile,who);
			entry.who = who;
			if (entry.convertFromPVE) then UnBotPVPSummon.PrepareConversion(entry); return; end
			local possible,reason=UnBotTalentInfo.Coarse(who,entry.className,entry.specKey,"pvp");
			if (possible==false) then UnBotPVPSummon.Defer(entry,"отсеян до осмотра: "..reason); return;
			elseif (possible==true) then entry.who=who; UnBotPVPSummon.InspectCandidate(entry); return; end
		end
		entry.catalog = UnBotTalentCatalog.Get(entry.className);
		if (entry.catalog and who.className == entry.className and (s.allowPVEFallback or (not entry.new and UnBotPVPSummon.ObservationValid(profile)))) then
			entry.who, entry.prepared, s.op = who, true, nil;
			UnBotPVPSummon.Target(entry);
			s.index = s.index + 1;
			return;
		end
		if (not UnBotPVPSquad.transport.Matches(who, entry.className, entry.specKey)) then
			UnBotPVPSummon.Fail(entry,"фактическая специализация не соответствует выбранной роли",false); return;
		end
		entry.who, entry.step, s.op = who, "talents", nil;
	elseif (op.kind == "talents") then
		local current = UnBotPVPSummon.Current(message);
		if (not current) then return; end
		UnBotPVPSummon.LogOperation("op_ack",op,"talents parsed"); UnBotPVPSummon.LogWait(nil);
		entry.current, entry.step, s.op = current, "catalog", nil;
	elseif (op.kind == "catalog") then
		entry.catalog = UnBotTalentCatalog.ReadReply(entry, message);
		if (entry.catalog) then
			UnBotPVPSummon.LogOperation("op_ack",op,"catalog complete"); UnBotPVPSummon.LogWait(nil);
			UnBotTalentCatalog.Store(entry.className, entry.catalog);
			s.catalogs[entry.className] = entry.catalog;
			s.op = nil;
			if (s.catalogOnly) then
				entry.ready = true;
				UnBotPVPSummon.Message(entry.className..": сохранено "..#entry.catalog.." названий PVE/PVP");
				return;
			end
			UnBotPVPSummon.Target(entry);
			entry.prepared = true;
			s.index = s.index + 1;
		end
	elseif (op.kind == "apply") then
		if (clean == "picking "..UnBotPVPSummon.Clean(entry.target.name)) then
			UnBotPVPSummon.LogOperation("op_ack",op,"preset accepted"); UnBotPVPSummon.LogWait(nil);
			s.talentsChanged=true;
			entry.ack, s.op, s.index = true, nil, s.index + 1;
			UnBotPVPSummon.Message(entry.name..": сервер принял "..entry.target.name);
		elseif (clean:find("not found",1,true)) then
			UnBotTalentCatalog.Invalidate(entry.className);
			s.blocked[entry.slotIndex] = "Сервер отказал: PVP-шаблон не найден";
			UnBotPVPSummon.Fail(entry,"сервер не нашёл выбранный шаблон; каталог класса обновится при следующем призыве",false);
		end
	elseif (op.kind == "verify") then
		local current = UnBotPVPSummon.Current(message);
		if (not current) then return; end
		UnBotPVPSummon.LogOperation("op_ack",op,"verification reply"); UnBotPVPSummon.LogWait(nil);
		local ok, confirmation = UnBotPVPSummon.Verify(entry,current);
		if (not ok) then UnBotPVPSummon.Fail(entry,"текущее состояние после смены не совпало с пресетом",false); return; end
		if (entry.convertFromPVE) then
			if (not entry.ack or not entry.target.snapshot) then UnBotPVPSummon.Fail(entry,"смена не подтверждена сервером или нет полного шаблона",false); return; end
			UnBotPVPSummon.ConfirmConversion(entry,current); return;
		end
		entry.ready, entry.confirmation, s.op, s.index = true, confirmation, nil, s.index + 1;
		UnBotPVPSummon.Observe(entry,current,confirmation);
		UnBotPVPSummon.Message(entry.name..": "..entry.target.name.." — "
			..(confirmation == "named" and "имя пресета подтверждено сервером" or "применён; текущее состояние проверено, ответ без имени пресета"));
	end
end

function UnBotPVPSummon.SystemNames(text, name)
	-- Match a whole name, never a substring or an unrelated anonymous refusal.
	local first,last = text:find(UnBotPVPSummon.Clean(name),1,true);
	if (not first) then return false; end
	local before,after = text:sub(first-1,first-1),text:sub(last+1,last+1);
	return (before == "" or (not before:match("[%w_]") and before:byte() < 128))
		and (after == "" or (not after:match("[%w_]") and after:byte() < 128));
end

function UnBotPVPSummon.ReadEntry(entry)
	local s = UnBotPVPSummon;
	if (entry.prepared) then s.index = s.index + 1; return false; end
	if (not entry.step) then UnBotPVPSummon.Request(entry,"who","who"); return true;
	elseif (entry.step == "talents") then UnBotPVPSummon.Request(entry,"talents","talents"); return true;
	else
		if (not s.catalogs[entry.className]) then s.catalogs[entry.className] = UnBotTalentCatalog.Get(entry.className); end
		if (s.catalogs[entry.className]) then
			entry.catalog,entry.prepared = s.catalogs[entry.className],true;
			UnBotPVPSummon.Target(entry); s.index = s.index + 1;
		else entry.catalogMap = {}; UnBotPVPSummon.Request(entry,"catalog","talents spec list"); return true; end
	end
	return false;
end

function UnBotPVPSummon.Advance()
	local s = UnBotPVPSummon;
	if (s.catalogOnly) then UnBotTalentCatalog.Advance(); return; end
	if (s.phase == "cleanup") then
		for name, cleanup in pairs(s.cleanup) do
			if (UnBotPVPSummon.Unit(name) and cleanup.attempts < 3 and GetTime() < cleanup.untilTime) then
				UnBotPVPSummon.LogWait("cleanup"); return;
			end
		end
		UnBotPVPSummon.Refill(); return;
	end
	while s.index <= #s.items do
		local entry = s.items[s.index];
		if (entry.failed or entry.ready or entry.round ~= s.round) then s.index = s.index + 1;
		elseif (s.phase == "summon") then
			local unit = UnBotPVPSummon.Unit(entry.name);
			if (not unit) then
				local limit = UnBotPVPSummon.MemberLimit();
				if (UnBotPVPSummon.Occupied() >= limit) then
					for name, cleanup in pairs(s.cleanup) do
						if (UnBotPVPSummon.Unit(name) and cleanup.attempts < 3 and GetTime() < cleanup.untilTime) then
							UnBotPVPSummon.LogWait("cleanup",{entry=entry,kind="join"}); return;
						end
					end
					UnBotPVPSummon.Fail(entry,"нет свободного места в группе/рейде (лимит "..limit..")",false);
				elseif (GetNumRaidMembers() == 0 and GetNumPartyMembers() == 4) then
					ConvertToRaid();
					UnBotPVPSummon.Request(entry,"join",".playerbot bot add "..entry.name); return;
				else
					UnBotPVPSummon.Request(entry,entry.addAck and "invite" or "join",
						entry.addAck and "invite" or ".playerbot bot add "..entry.name); return;
				end
			elseif (UnBotPVPSummon.Near(entry)) then
				if (entry.new and not entry.recorded) then UnBotPVPSquad.transport.Record(entry.name,"pvp-summon"); entry.recorded = true; end
				-- Read this bot before summoning the next one; unsuitable points
				-- are rejected without waiting for the whole class/raid to arrive.
				UnBotPVPSummon.ReadEntry(entry); return;
			else UnBotPVPSummon.Request(entry,"arrival","summon"); return; end
		elseif (s.phase == "read") then
			if (UnBotPVPSummon.ReadEntry(entry)) then return; end
		elseif (s.phase == "apply") then
			UnBotPVPSummon.Request(entry,"apply","talents spec "..entry.target.name); return;
		elseif (s.phase == "verify") then
			UnBotPVPSummon.Request(entry,"verify","talents"); return;
		end
	end
	if (s.phase == "summon") then UnBotPVPSummon.Phase("read","проверка текущих спеков");
	elseif (s.phase == "read") then UnBotPVPSummon.Phase("apply","смена PVP-пресетов");
	elseif (s.phase == "apply") then UnBotPVPSummon.Phase("verify","одна проверка результата");
	else UnBotPVPSummon.Phase("cleanup","очистка отказавших кандидатов"); end
end

function UnBotPVPSummon.Update()
	if (UnBotGunshipMasterLoot and UnBotGunshipMasterLoot.paused) then UnBotPVPSummon.LogWait("loot_pause",UnBotPVPSummon.op); return; end
	local s, now, t = UnBotPVPSummon, GetTime(), UnBotPVPSquad.transport;
	if (UnitAffectingCombat("player") or InCombatLockdown()) then
		if (s.active) then UnBotPVPSummon.Stop("остановлено: начался бой; карантин не назначен"); end
		return;
	end
	for name, cleanup in pairs(s.cleanup) do
		if (now >= cleanup.untilTime or not t or t.Busy() or UnBotPVPSummon.Protected(name)) then s.cleanup[name] = nil;
		elseif (now >= cleanup.at and UnBotPVPSummon.Unit(name) and cleanup.attempts < 3
			and not UnitAffectingCombat(UnBotPVPSummon.Unit(name))) then
			cleanup.attempts, cleanup.at = cleanup.attempts + 1, now + 3;
			t.Uninvite(name);
		end
	end
	if (not s.active) then return; end
	if (t.Busy() or s.context ~= UnBotRegistryCurrentContext() or (not s.catalogOnly and s.signature ~= UnBotPVPSummon.Signature())) then
		UnBotPVPSummon.Stop("остановлено: другая операция, смена контекста или изменение PVP-состава"); return;
	end
	if (now >= s.deadline) then UnBotPVPSummon.Stop("истёк общий таймаут подготовки"); return; end
	if (s.resetAI) then UnBotPVPSummon.TickResetAI(); return; end
	if (s.inspectEntry) then
		UnBotPVPSummon.LogWait("inspect",{entry=s.inspectEntry,kind="inspect"}); return;
	end
	if (not s.catalogOnly and UnBotGunshipMasterLoot and UnBotGunshipMasterLoot.CheckSummon
		and not UnBotGunshipMasterLoot.CheckSummon()) then return; end
	local op = s.op;
	if (not op) then UnBotPVPSummon.Advance(); return; end
	local entry, unit = op.entry, UnBotPVPSummon.Unit(op.entry.name);
	if (UnBotPVPSummon.Protected(entry.name)) then UnBotPVPSummon.Stop("кандидат защищён; команды отменены"); return; end
	if (unit and UnitAffectingCombat(unit)) then UnBotPVPSummon.Stop("кандидат вступил в бой; команды отменены без карантина"); return; end
	if ((op.kind == "join" or op.kind == "invite") and unit and UnitIsConnected(unit)) then
		UnBotPVPSummon.LogOperation("op_ack",op,"connected in our roster"); UnBotPVPSummon.LogWait(nil); s.op = nil; return;
	end
	if (op.kind == "arrival" and UnBotPVPSummon.Near(entry)) then
		UnBotPVPSummon.LogOperation("op_ack",op,"nearby in our roster"); UnBotPVPSummon.LogWait(nil); s.op = nil; return;
	end
	if (op.groupRefusalAt) then
		if (now >= op.groupRefusalAt) then UnBotPVPSummon.Fail(entry,"сервер сообщил: уже состоит в группе; в нашем ростере не появился",true);
		else UnBotPVPSummon.LogWait("roster",op); end
		return;
	end
	if (op.kind ~= "join" and op.kind ~= "invite" and op.kind ~= "arrival" and not UnBotPVPSummon.Near(entry)) then
		UnBotPVPSummon.Fail(entry,"бот перестал быть доступен рядом",true); return;
	end
	if (s.catalogOnly and not unit and (op.kind == "join" or op.kind == "invite")
		and UnBotPVPSummon.Occupied() >= UnBotPVPSummon.MemberLimit()) then
		UnBotPVPSummon.Fail(entry,"нет свободного места для временного бота",false); return;
	end
	if (now < op.at) then
		UnBotPVPSummon.LogWait(op.attempts == 0 and "send_interval"
			or ((op.kind == "join" or op.kind == "invite" or op.kind == "arrival") and "roster" or "server_reply"),op); return;
	end
	if (op.attempts >= 3) then
		if (op.kind == "join") then
			-- Some servers bring bots online without Hello or an automatic invite.
			-- Explicit invitations have their own finite three-attempt budget.
			entry.addAck, s.op = true, nil;
			UnBotPVPSummon.LogOperation("op_end",op,"add retries exhausted; try invite"); UnBotPVPSummon.LogWait(nil);
		else UnBotPVPSummon.Fail(entry,"нет ответа/прибытия после 3 отправок "..op.command,true); end
		return;
	end
	UnBotPVPSummon.LogWait(nil);
	op.attempts, op.at, s.lastSend, op.sentAt = op.attempts + 1, now + s.retryInterval, now, now;
	-- A lost Picking reply does not prove the server left talents unchanged.
	if (op.kind=="apply" and not s.catalogOnly) then s.talentsChanged=true; end
	if (op.kind=="apply" and op.attempts==1 and entry.convertFromPVE) then
		UnBotTalentInfo.Invalidate(UnBotBotRegistry.bots[entry.name],"Ожидаем осмотр после перевода PvE → PvP");
	end
	UnBotPVPSummon.LogOperation("op_send",op,"dispatch");
	if (op.kind == "catalog") then entry.catalogMap, entry.catalogExpected = {}, nil; end
	if (op.kind == "invite") then InviteUnit(entry.name);
	elseif (op.kind == "join") then
		if (not s.catalogOnly and not entry.sentAdd and UnBotGunshipMasterLoot and UnBotGunshipMasterLoot.RecordAttempt) then
			UnBotGunshipMasterLoot.RecordAttempt(entry.name);
		end
		entry.sentAdd = true; SendChatMessage(op.command,"SAY");
	else SendChatMessage(op.command,"WHISPER",nil,entry.name); end
	if (s.op == op) then
		UnBotPVPSummon.LogWait((op.kind == "join" or op.kind == "invite" or op.kind == "arrival") and "roster" or "server_reply",op);
	end
end

-- A realm-wide, account SavedVariables catalog; independent of bot identities,
-- factions, character squads and personal strategy profiles. A verified export
-- can be bundled as seed data for every installation on the same realm.
UnBotTalentCatalog = UnBotTalentCatalog or {};
UnBotTalentCatalog.seed = UnBotTalentCatalog.seed or {};

-- Bundled catalog: full Solo scan confirmed by the player, 2026-10-12.
-- Shared with Solo Progress at the player's request; imported copies stay realm-specific.
UnBotTalentCatalog.seed["solo"] = {
  ["warrior"] = {
    {name="arms pve", build="55-8-8"},
    {name="arms pvp", build="60-11-0"},
    {name="fury pve", build="18-53-0"},
    {name="fury pvp", build="18-53-0"},
    {name="prot pve", build="16-4-51"},
    {name="prot pvp", build="16-3-52"},
  },
  ["paladin"] = {
    {name="holy pve", build="54-17-0"},
    {name="holy pvp", build="52-19-0"},
    {name="prot pve", build="0-53-18"},
    {name="prot pvp", build="0-54-17"},
    {name="ret pve", build="11-5-55"},
    {name="ret pvp", build="0-19-52"},
  },
  ["hunter"] = {
    {name="bm pve", build="56-15-0"},
    {name="bm pvp", build="53-15-3"},
    {name="mm pve", build="7-57-7"},
    {name="mm pvp", build="0-54-17"},
    {name="surv pve", build="0-15-56"},
    {name="surv pvp", build="0-16-55"},
  },
  ["rogue"] = {
    {name="as pve", build="51-18-2"},
    {name="as pvp", build="44-4-23"},
    {name="combat pve", build="20-51-0"},
    {name="combat pvp", build="17-54-0"},
    {name="subtlety pve", build="20-0-51"},
    {name="subtlety pvp", build="12-3-56"},
  },
  ["priest"] = {
    {name="disc pve", build="57-14-0"},
    {name="disc pvp", build="56-15-0"},
    {name="holy pve", build="14-57-0"},
    {name="holy pvp", build="17-54-0"},
    {name="shadow pve", build="13-0-58"},
    {name="shadow pvp", build="20-0-51"},
  },
  ["shaman"] = {
    {name="ele pve", build="57-14-0"},
    {name="ele pvp", build="60-11-0"},
    {name="enh pve", build="19-52-0"},
    {name="enh pvp", build="17-54-0"},
    {name="resto pve", build="0-13-58"},
    {name="resto pvp", build="0-19-52"},
  },
  ["mage"] = {
    {name="arcane pve", build="56-3-12"},
    {name="arcane pvp", build="52-7-12"},
    {name="fire pve", build="18-53-0"},
    {name="fire pvp", build="19-52-0"},
    {name="frost pve", build="18-0-53"},
    {name="frost pvp", build="20-0-51"},
    {name="frostfire pve", build="0-57-14"},
  },
  ["warlock"] = {
    {name="affli pve", build="56-0-15"},
    {name="affli pvp", build="54-17-0"},
    {name="demo pve", build="0-56-15"},
    {name="demo pvp", build="0-53-18"},
    {name="destro pve", build="5-5-61"},
    {name="destro pvp", build="0-20-51"},
  },
  ["druid"] = {
    {name="balance pve", build="58-0-13"},
    {name="balance pvp", build="57-0-14"},
    {name="bear pve", build="0-60-11"},
    {name="cat pve", build="0-53-18"},
    {name="cat pvp", build="0-53-18"},
    {name="resto pve", build="14-0-57"},
    {name="resto pvp", build="13-0-58"},
  },
  ["dk"] = {
    {name="blood pve", build="56-5-10"},
    {name="blood pvp", build="51-0-20"},
    {name="double aura blood pve", build="43-26-2"},
    {name="frost pve", build="0-53-18"},
    {name="frost pvp", build="10-58-3"},
    {name="unholy pve", build="0-18-53"},
    {name="unholy pvp", build="0-17-54"},
  },
};
UnBotTalentCatalog.seed["solo progress"] = UnBotTalentCatalog.seed["solo"];

function UnBotTalentCatalog.Realm()
	local context = UnBotRegistryCurrentContext();
	return tostring(context):match("^(.-)|") or tostring(context);
end

function UnBotTalentCatalog.State()
	local realm = UnBotTalentCatalog.Realm();
	UnBotSquadConfig = UnBotSquadConfig or {};
	UnBotSquadConfig.talentCatalogsByRealm = UnBotSquadConfig.talentCatalogsByRealm or {};
	local state = UnBotSquadConfig.talentCatalogsByRealm[realm];
	if (not state) then
		state = {schemaVersion=1, classes={}};
		UnBotSquadConfig.talentCatalogsByRealm[realm] = state;
	end
	state.classes = state.classes or {};
	return state;
end

function UnBotTalentCatalog.Valid(templates)
	if (type(templates) ~= "table" or #templates > 100) then return false; end
	local seen = {};
	for _, template in ipairs(templates) do
		if (type(template) ~= "table" or type(template.name) ~= "string" or #template.name == 0
			or #template.name > 80 or template.name:find("[%c]") or type(template.build) ~= "string"
			or not template.build:match("^%d+%-%d+%-%d+$") or seen[template.name]) then return false; end
		seen[template.name] = true;
	end
	return true;
end

function UnBotTalentCatalog.Get(className)
	local state = UnBotTalentCatalog.State();
	local record = state.classes[className];
	local seed = UnBotTalentCatalog.seed[UnBotTalentCatalog.Realm()];
	if (not record and seed and UnBotTalentCatalog.Valid(seed[className])) then
		UnBotTalentCatalog.Store(className, seed[className], "bundled");
		record = state.classes[className];
	end
	if (record and record.complete and not record.stale and UnBotTalentCatalog.Valid(record.templates)) then
		return record.templates;
	end
end

function UnBotTalentCatalog.Store(className, templates, source)
	if (not UnBotTalentCatalog.Valid(templates)) then return false; end
	local state, copies = UnBotTalentCatalog.State(), {};
	local record = state.classes[className] or {};
	local old = {};
	for _, template in ipairs(record.templates or {}) do old[template.name] = template; end
	for _, template in ipairs(templates) do
		local copy = {};
		for key, value in pairs(old[template.name] or {}) do copy[key] = value; end
		copy.name, copy.build = template.name, template.build;
		table.insert(copies, copy);
	end
	record.templates, record.complete, record.stale = copies, true, false;
	record.checkedAt, record.source = time(), source or "server";
	state.classes[className] = record;
	if (UnBotTalentCatalog.window and UnBotTalentCatalog.window:IsShown() and not UnBotTalentCatalog.exportView) then
		UnBotTalentCatalog.SetText(UnBotTalentCatalog.Text(false));
	end
	return true;
end

function UnBotTalentCatalog.Invalidate(className)
	local record = UnBotTalentCatalog.State().classes[className];
	if (record) then record.stale = true; end
	if (UnBotPVPSummon.catalogs) then UnBotPVPSummon.catalogs[className] = nil; end
end

function UnBotTalentCatalog.Resolve(className, specKey, mode)
	for _, template in ipairs(UnBotTalentCatalog.Get(className) or {}) do
		local prefix = UnBotPVPSummon.Clean(template.name):match("^(.-)%s+"..mode.."$");
		if (prefix and UnBotPVPSquad.transport.Matches({className=className,specName=prefix,feralRole=prefix},className,specKey)) then
			return template;
		end
	end
end

-- Read-only PvE validation on the existing owner/frame. Confirmed who is
-- delivered to registry acceptance; this path never changes talents.
function UnBotTalentCatalog.BeginPVE(name, who, raw, slot, existing)
	local s = UnBotPVPSquad.transport.PVEOwner;
	local profile = UnBotBotRegistry.bots and UnBotBotRegistry.bots[name];
	slot = slot or s.requestedSlot or {className=s.className,specKey=s.specName,specAliases=s.specAliases};
	-- A rebalance donor needs its factual who stored before init, not rejection
	-- for lacking the target build. Other open roles can still accept it.
	if (s.requestedFallback and not existing and who
		and not UnBotPVPSquad.transport.Matches(who,slot.className,slot.specKey or slot.specAliases)
		and s.mode ~= "squad") then return false; end
	if (s.mode == "squad" and not existing and who) then
		local matching;
		for _, wanted in ipairs(s.squad and s.squad.slots or {}) do
			if (not wanted.skipped and not wanted.accountAltName and wanted.have < wanted.need
				and UnBotPVPSquad.transport.Matches(who,wanted.className,wanted.specKey or wanted.specAliases)) then
				matching = wanted; break
			end
		end
		if (matching) then slot = matching;
		elseif (s.requestedFallback) then return false; end
	end
	if (UnBotTalentInfo and s.active and not s.completionSource and UnBotSpecSummonPlayerSupportsSpecs() and who and who.level==80
		and not slot.accountAltName and not UnBotIsAccountAltProfile(name,profile) and not UnBotSquadRosterIsOfflineReserve(name)
		and UnBotFullTalentCatalog.Get(slot.className,who.level)) then
		if (s.pvePresetDoneName==name) then return false; end
		local possible,reason=UnBotTalentInfo.Coarse(who,slot.className,slot.specKey or slot.specAliases,"pve");
		if (possible==false) then
			UnBotSpecSummonStoreRegistryWho(name,who,raw);
			if (existing) then s.StopForPreset("PVE: "..name..": "..reason.."; текущий участник сохранён");
			else s.RejectForTalent("PVE: "..name..": отсеян до осмотра — "..reason); end
			return true;
		end
		s.pvePreset={name=name,className=slot.className,specKey=slot.specKey or slot.specAliases,
			level=who.level,kind="inspect",existing=existing,who=who,rawWho=raw};
		s.stage,s.stageTime="wait_pve_preset",GetTime();
		UnBotTalentInfo.InspectPVE(s.pvePreset); return true;
	end
	-- PvE selects existing builds. Missing catalogues never authorize a respec.
	return false;
end

function UnBotTalentCatalog.BeginExistingPVE()
	local s = UnBotPVPSquad.transport.PVEOwner;
	if (s.mode ~= "squad" or s.pveExistingPrepared) then return false; end
	s.pveExistingPrepared, s.pveExistingQueue = true, {};
	for _, slot in ipairs(s.squad.slots or {}) do
		if (not slot.accountAltName and ((slot.specKey ~= "any" and not (slot.specAliases and slot.specAliases.anySpec))
			or (UnBotFullTalentCatalog and UnBotFullTalentCatalog.Get(slot.className,80)))) then
			for name in pairs(slot.names or {}) do table.insert(s.pveExistingQueue,{name=name,slot=slot}); end
		end
	end
	table.sort(s.pveExistingQueue,function(a,b) return a.name < b.name; end);
	return UnBotTalentCatalog.NextExistingPVE();
end

function UnBotTalentCatalog.NextExistingPVE()
	local s = UnBotPVPSquad.transport.PVEOwner;
	while #(s.pveExistingQueue or {}) > 0 do
		local entry = table.remove(s.pveExistingQueue,1);
		local profile = UnBotBotRegistry.bots[entry.name];
		if (profile and UnBotTalentCatalog.BeginPVE(entry.name,UnBotParseBotWho(profile.rawWho),profile.rawWho,entry.slot,true)) then return true; end
	end
	return false;
end

function UnBotTalentCatalog.FailPVE(reason)
	local s = UnBotPVPSquad.transport.PVEOwner;
	local op = s.pvePreset;
	if (not op) then return; end
	if (UnBotTalentInfo) then UnBotTalentInfo.Cancel(s); end
	s.pvePreset = nil;
	s.StopForPreset("PVE: "..op.name.." — "..reason.."; призыв остановлен");
end

function UnBotTalentCatalog.TickPVE()
	local s = UnBotPVPSquad.transport.PVEOwner;
	local op, now = s.pvePreset, GetTime();
	if (not op or not s.active) then return; end
	local unit = UnBotSquadRosterFindUnit(op.name);
	if (UnitAffectingCombat("player") or InCombatLockdown() or (unit and UnitAffectingCombat(unit))) then
		UnBotTalentCatalog.FailPVE("начался бой"); return;
	end
	if (not unit or not UnitIsConnected(unit) or UnitIsDeadOrGhost(unit)
		or UnBotIsAccountAltProfile(op.name,UnBotBotRegistry.bots[op.name]) or UnBotSquadRosterIsOfflineReserve(op.name)) then
		UnBotTalentCatalog.FailPVE("бот недоступен или защищён"); return;
	end
	if (now >= op.deadline) then UnBotTalentCatalog.FailPVE("таймаут "..op.kind.." (отправок: "..op.attempts..")"); return; end
end

function UnBotTalentCatalog.PVEReply(event, message, sender)
	local s = UnBotPVPSquad.transport.PVEOwner;
	local op = s.pvePreset;
	return s.active and op and op.kind == "inspect" and event == "CHAT_MSG_WHISPER" and sender == op.name;
end

function UnBotTalentCatalog.FinishPVE(who, message, source)
	local s = UnBotPVPSquad.transport.PVEOwner;
	local op = s.pvePreset;
	local profile = UnBotBotRegistry.bots[op.name];
	profile.pveObservation = profile.pveObservation or {};
	profile.pveObservation.preset, profile.pveObservation.build = op.target.name,op.target.build;
	profile.pveObservation.source, profile.pveObservation.checkedAt = source,time();
	s.pvePreset, s.pvePresetDoneName = nil, op.name;
	UnBotSpecSummonMessage("PVE: "..op.name..": "..op.target.name..(source == "verified"
		and " — применён; новая роль проверена" or source=="full-inspect" and " — спек и PVE подтверждены полными талантами" or " — сервер подтвердил применение"));
	if (op.existing) then
		if (source == "verified" or source=="full-inspect") then UnBotSpecSummonStoreRegistryWho(op.name,who,message); end
		if (not UnBotTalentCatalog.NextExistingPVE()) then s.ContinuePreset(); end
		return;
	end
	s.stage = "wait_registry_who";
	s.pveVerifiedWho = who;
	s.DeliverPresetWho(op.name,message);
end

function UnBotTalentCatalog.ReadReply(entry, message)
	local text = tostring(message or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|h", "");
	entry.catalogMap = entry.catalogMap or {};
	for line in text:gmatch("[^\r\n]+") do
		local index, name, a, b, c = line:match("^%s*(%d+)[%.%)]%s*(.-)%s*%((%d+)[/%-](%d+)[/%-](%d+)%)%s*$");
		index = tonumber(index);
		if (index and index > 0 and index <= 100 and name) then
			entry.catalogMap[index] = {name=name:match("^%s*(.-)%s*$"), build=a.."-"..b.."-"..c};
		end
	end
	entry.catalogExpected = tonumber(UnBotPVPSummon.Clean(text):match("total%s+(%d+)%s+specs?%s+found")) or entry.catalogExpected;
	local expected, count, templates = entry.catalogExpected, 0, {};
	if (not expected or expected > 100) then return; end
	for _ in pairs(entry.catalogMap) do count = count + 1; end
	if (count ~= expected) then return; end
	for index = 1, expected do
		if (not entry.catalogMap[index]) then return; end
		table.insert(templates, entry.catalogMap[index]);
	end
	if (not UnBotTalentCatalog.Valid(templates)) then return; end
	table.sort(templates, function(a,b) return a.name < b.name; end);
	return templates;
end

function UnBotTalentCatalog.Start(refresh, className)
	if (UnBotFullTalentCatalog and UnBotFullTalentCatalog.IsBusy()) then
		UnBotPVPSquad.Message("Каталог спеков: сначала завершите сбор полного каталога талантов"); return false;
	end
	local s, t = UnBotPVPSummon, UnBotPVPSquad.transport;
	if (s.active or (UnBotSquadSummon and UnBotSquadSummon.active) or not t or t.Busy()
		or t.Settling() or next(s.cleanup) or (UnBotGunshipMasterLoot and UnBotGunshipMasterLoot.paused)) then
		UnBotPVPSquad.Message("Каталог спеков: сначала завершите другую операцию UnBot"); return false;
	end
	if (UnitAffectingCombat("player") or InCombatLockdown()) then
		UnBotPVPSquad.Message("Каталог спеков: обход доступен вне боя"); return false;
	end
	if ((GetNumRaidMembers() > 0 and not IsRaidLeader() and not IsRaidOfficer())
		or (GetNumRaidMembers() == 0 and GetNumPartyMembers() > 0 and not IsPartyLeader())) then
		UnBotPVPSquad.Message("Каталог спеков: для временных приглашений нужен лидер или помощник"); return false;
	end
	t.Attach();
	if (not UnBotRegistryMatchesCurrentContext(UnBotBotRegistry)) then
		UnBotPVPSquad.Message("Каталог спеков: реестр ботов относится к другому серверу/фракции"); return false;
	end
	local queue = {};
	for _, classInfo in ipairs(UnBotPVPSquad.catalog or {}) do
		if (not className or className == classInfo.className) then table.insert(queue, classInfo.className); end
	end
	if (#queue == 0) then UnBotPVPSquad.Message("Каталог спеков: неизвестный класс"); return false; end
	s.catalogOnly, s.active, s.scanRefresh = true, true, refresh;
	s.items, s.used, s.catalogs, s.original, s.protected = {}, {}, {}, {}, {};
	s.scanQueue, s.scanCursor, s.scanAttempts, s.scanDone, s.scanMissing = queue, 1, 0, 0, {};
	s.scanEntry, s.op, s.signature, s.phase, s.phaseLabel = nil, nil, nil, "catalog", "обход каталога спеков";
	s.round, s.total, s.lastSend, s.context = 1, #queue, GetTime() - 3, UnBotRegistryCurrentContext();
	s.deadline = GetTime() + #queue * 180;
	for name in pairs(UnBotBotRegistry.bots or {}) do
		if (UnBotPVPSummon.Unit(name)) then s.original[name] = true; end
	end
	UnBotPVPSummon.Message("начинаю обход "..#queue.." классов; один временный бот за раз, без смены талантов");
	return true;
end

function UnBotTalentCatalog.Release(entry)
	if (not entry.releaseQueued and entry.new and (entry.sentAdd or UnBotPVPSummon.Unit(entry.name))) then
		UnBotPVPSummon.cleanup[entry.name] = UnBotPVPSummon.cleanup[entry.name]
			or {at=GetTime(), untilTime=GetTime()+30, attempts=0};
		entry.releaseQueued = true;
	end
end

function UnBotTalentCatalog.Advance()
	local s, t = UnBotPVPSummon, UnBotPVPSquad.transport;
	local entry = s.scanEntry;
	if (entry and (entry.ready or entry.failed)) then
		UnBotTalentCatalog.Release(entry);
		local cleanup, unit = s.cleanup[entry.name], UnBotPVPSummon.Unit(entry.name);
		-- Wait for a confirmed member to leave. A delayed add keeps its cleanup
		-- window before another temporary bot can consume the spare slot.
		if (cleanup and (unit or (entry.sentAdd and not entry.arrived))
			and GetTime() < cleanup.untilTime) then return; end
		if (entry.new and unit) then UnBotPVPSummon.Stop("временный бот не покинул группу; дальнейшие приглашения отменены"); return; end
		if (entry.ready) then s.scanDone, s.scanCursor, s.scanAttempts = s.scanDone + 1, s.scanCursor + 1, 0; end
		s.scanEntry = nil;
		entry = nil;
	end
	if (not entry) then
		while s.scanCursor <= #s.scanQueue do
			local className = s.scanQueue[s.scanCursor];
			if (not s.scanRefresh and UnBotTalentCatalog.Get(className)) then
				s.scanDone, s.scanCursor, s.scanAttempts = s.scanDone + 1, s.scanCursor + 1, 0;
			else
				local names = t.Candidates(className, "any", s.used);
				-- Existing ordinary members can answer read-only requests even
				-- when assigned to PvE. They must never be dismissed by the scan.
				table.sort(names, function(a,b)
					local ua, ub = UnBotPVPSummon.Unit(a), UnBotPVPSummon.Unit(b);
					if ((ua ~= nil) ~= (ub ~= nil)) then return ua ~= nil; end
					return a < b;
				end);
				if (s.scanAttempts < 3) then
					for _, name in ipairs(names) do
						local unit = UnBotPVPSummon.Unit(name);
						if (not UnBotPVPSummon.Protected(name) and (not unit or (UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit)))
							and (unit or UnBotPVPSummon.Occupied() < UnBotPVPSummon.MemberLimit())) then
							entry = {name=name, className=className, specKey="any", new=not s.original[name]};
							s.used[name], s.scanEntry, s.scanAttempts = true, entry, s.scanAttempts + 1;
							table.insert(s.items, entry);
							entry.untilTime = GetTime() + 60;
							break
						end
					end
				end
				if (entry) then break end
				table.insert(s.scanMissing, className);
				UnBotPVPSummon.Message(className..": не прочитан — нет доступного бота/места или исчерпаны 3 кандидата");
				s.scanCursor, s.scanAttempts = s.scanCursor + 1, 0;
			end
		end
		if (not entry) then
			s.active, s.op = false, nil;
			UnBotPVPSummon.Message("обход завершён: "..s.scanDone.."/"..#s.scanQueue.." классов"
				..(#s.scanMissing > 0 and "; не прочитаны: "..table.concat(s.scanMissing, ", ") or "")..". Для записи на диск выполните /reload");
			UnBotPVPSquad.Refresh();
			return;
		end
	end
	local unit = UnBotPVPSummon.Unit(entry.name);
	if (GetTime() >= entry.untilTime) then UnBotPVPSummon.Fail(entry,"таймаут кандидата (60 секунд)",false); return; end
	if (not unit) then
		if (GetNumRaidMembers() == 0 and GetNumPartyMembers() == 4) then ConvertToRaid(); end
		UnBotPVPSummon.Request(entry, entry.addAck and "invite" or "join",
			entry.addAck and "invite" or ".playerbot bot add "..entry.name);
	elseif (not UnBotPVPSummon.Near(entry)) then UnBotPVPSummon.Request(entry,"arrival","summon");
	elseif (not entry.who) then
		entry.arrived = true;
		UnBotPVPSummon.Request(entry,"who","who");
	else
		UnBotPVPSummon.Request(entry,"catalog","talents spec list");
	end
end

function UnBotTalentCatalog.Text(export)
	local lines, total = {}, 0;
	if (export) then table.insert(lines, "UnBotTalentCatalog.seed["..string.format("%q",UnBotTalentCatalog.Realm()).."] = {");
	else table.insert(lines, "Каталог спеков — "..UnBotTalentCatalog.Realm().."\nОбщий для всех персонажей аккаунта. Названия получены с сервера.\n"); end
	for _, classInfo in ipairs(UnBotPVPSquad.catalog or {}) do
		local templates = UnBotTalentCatalog.Get(classInfo.className);
		if (templates) then
			total = total + 1;
			table.insert(lines, export and ("  ["..string.format("%q",classInfo.className).."] = {") or (classInfo.label.." ("..classInfo.className..")"));
			for _, template in ipairs(templates) do
				table.insert(lines, export and ("    {name="..string.format("%q",template.name)..", build="..string.format("%q",template.build).."},")
					or ("  "..template.name.." ("..template.build..")"));
			end
			if (export) then table.insert(lines, "  },"); end
		elseif (not export) then table.insert(lines, classInfo.label.." — ещё не прочитан / требует обновления"); end
	end
	if (export) then table.insert(lines,"};"); end
	if (not export) then table.insert(lines,"\nПрочитано классов: "..total.."/"..#(UnBotPVPSquad.catalog or {})); end
	return table.concat(lines,"\n"), total;
end

function UnBotTalentCatalog.SetText(text)
	local _, lines = text:gsub("\n", "");
	UnBotTalentCatalog.edit:SetHeight(math.max(310, (lines + 1) * 16));
	UnBotTalentCatalog.edit:SetText(text);
end

function UnBotTalentCatalog.Show(export)
	local c = UnBotTalentCatalog;
	c.exportView = export;
	if (not c.window) then
		local frame = CreateFrame("Frame", "UnBotTalentCatalogWindow", UIParent);
		frame:SetWidth(560); frame:SetHeight(440); frame:SetPoint("CENTER"); frame:SetFrameStrata("DIALOG");
		frame:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
			tile=true, tileSize=32, edgeSize=32, insets={left=8,right=8,top=8,bottom=8}});
		frame:EnableMouse(true); frame:SetMovable(true); frame:RegisterForDrag("LeftButton");
		frame:SetScript("OnDragStart",function(self) self:StartMoving(); end);
		frame:SetScript("OnDragStop",function(self) self:StopMovingOrSizing(); end);
		local title = frame:CreateFontString(nil,"OVERLAY","GameFontNormalLarge");
		title:SetPoint("TOPLEFT",20,-18); title:SetText("Серверный каталог спеков");
		local full = UnBotPVPSquad.Button(frame,"Полные таланты...",150,function() UnBotFullTalentCatalog.Show(); end);
		full:SetPoint("TOPRIGHT",-44,-13);
		local close = CreateFrame("Button",nil,frame,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",-5,-5);
		local scroll = CreateFrame("ScrollFrame","UnBotTalentCatalogScroll",frame,"UIPanelScrollFrameTemplate");
		scroll:SetPoint("TOPLEFT",20,-48); scroll:SetPoint("BOTTOMRIGHT",-42,54);
		local edit = CreateFrame("EditBox",nil,scroll);
		edit:SetMultiLine(true); edit:SetAutoFocus(false); edit:SetFontObject(GameFontHighlightSmall);
		edit:SetWidth(490); edit:SetHeight(310); edit:SetMaxLetters(0);
		edit:SetScript("OnEscapePressed",function(self) self:ClearFocus(); frame:Hide(); end);
		edit:SetScript("OnTextChanged",function() scroll:UpdateScrollChildRect(); end);
		scroll:SetScrollChild(edit);
		for index, info in ipairs({{"Обойти классы",function() c.Start(false); end},
			{"Обновить всё",function() c.Start(true); end}, {"Стоп",function() if UnBotPVPSummon.catalogOnly then UnBotPVPSummon.Stop("обход остановлен игроком"); end end},
			{"Экспорт",function() c.Show(true); end}}) do
			local button = UnBotPVPSquad.Button(frame,info[1],122,info[2]);
			button:SetPoint("BOTTOMLEFT",18+(index-1)*130,20);
		end
		c.window, c.edit, c.scroll = frame, edit, scroll;
	end
	local text, total = c.Text(export);
	if (export and total ~= #(UnBotPVPSquad.catalog or {})) then
		UnBotPVPSquad.Message("Каталог спеков: экспорт неполный ("..total.."/"..#(UnBotPVPSquad.catalog or {}).." классов); сначала завершите обход");
	end
	c.SetText(text); c.scroll:SetVerticalScroll(0); c.edit:ClearFocus(); c.window:Show();
	if (export) then c.edit:SetFocus(); c.edit:HighlightText(); end
end

SLASH_UNBOTTALENTCATALOG1 = "/ubspeccatalog";
SlashCmdList.UNBOTTALENTCATALOG = function(text)
	local command, className = UnBotPVPSummon.Clean(text):match("^(%S+)%s*(.-)$");
	if (className == "") then className = nil; end
	if (command == "scan" or command == "refresh") then UnBotTalentCatalog.Start(command == "refresh",className);
	elseif (command == "stop") then if UnBotPVPSummon.catalogOnly then UnBotPVPSummon.Stop("обход остановлен игроком"); end
	elseif (command == "export") then UnBotTalentCatalog.Show(true);
	else UnBotTalentCatalog.Show(false); end
end;

UnBotPVPSummon.frame = CreateFrame("Frame", "UnBotPVPSummonController");
UnBotPVPSummon.frame:RegisterEvent("CHAT_MSG_WHISPER");
UnBotPVPSummon.frame:RegisterEvent("CHAT_MSG_SYSTEM");
UnBotPVPSummon.frame:SetScript("OnEvent", function(self,event,message,sender) UnBotPVPSummon.Reply(event,message,sender); end);
UnBotPVPSummon.frame:SetScript("OnUpdate", UnBotPVPSummon.Update);
SLASH_UNBOTPVPSUMMON1 = "/ubpvpsummon";
SlashCmdList.UNBOTPVPSUMMON = function(text)
	if (UnBotPVPSummon.Clean(text) == "stop") then UnBotPVPSummon.Stop("остановлено игроком");
	else UnBotPVPSummon.Start(); end
end;

-- Full server templates. Kept in an existing TOC file so /reload loads it.
-- No changes to player squads, account alts or strategies. Only owned temporary
-- ordinary level-80 bots may be respecced. The checkpoint uses wall time, never
-- saved GetTime deadlines. Inspection events in 3.3.5 have no reliable GUID;
-- require two matching responses to our own requests and reject competing use.
UnBotFullTalentCatalog = UnBotFullTalentCatalog or {};
do
local c = UnBotFullTalentCatalog;

function c.Message(text)
	if UnBotTalentInfo then UnBotTalentInfo.cache=setmetatable({}, {__mode="k"});end
	if UnBotSquadBuilderUI then UnBotSquadBuilderUI.Dirty();end
	UnBotPVPSquad.Message("Полный каталог: "..text);
	if (c.window and c.window:IsShown() and not c.exportView) then c.Render(); end
end

function c.State()
	UnBotSquadConfig.fullTalentCatalogsByRealm = UnBotSquadConfig.fullTalentCatalogsByRealm or {};
	local realm = UnBotTalentCatalog.Realm();
	local state = UnBotSquadConfig.fullTalentCatalogsByRealm[realm];
	if (not state) then state = {schemaVersion=1,classes={},jobs={}}; UnBotSquadConfig.fullTalentCatalogsByRealm[realm] = state; end
	state.classes, state.jobs = state.classes or {}, state.jobs or {};
	return state;
end

function c.Owner()
	return UnBotRegistryCurrentContext().."|"..tostring(UnitName("player"));
end

function c.Job()
	return c.State().jobs[c.Owner()];
end

function c.IsBusy()
	local j = c.Job();
	return c.active or c.cleanup or (j and j.bot and j.bot.sentAdd)
		or (UnBotTalentInfo and UnBotTalentInfo.job)
		or (UnBotBotScanner and UnBotBotScanner.pendingTalentAudit) or false;
end

function c.Unit()
	local j = c.Job();
	return j and j.bot and UnBotSquadRosterFindUnit(j.bot.name);
end

function c.SafeBot()
	local j, unit = c.Job(), c.Unit();
	local b = j and j.bot;
	local profile = b and UnBotBotRegistry.bots and UnBotBotRegistry.bots[b.name];
	if (not b or j.owner ~= c.Owner() or j.context ~= UnBotRegistryCurrentContext()
		or not profile or profile.className ~= b.className
		or (unit and not b.sentAdd)
		or b.original or j.original[b.name] or b.name == UnitName("player")
		or UnBotIsAccountAltProfile(b.name, UnBotBotRegistry.bots and UnBotBotRegistry.bots[b.name])
		or UnBotSquadRosterIsOfflineReserve(b.name)
		or (b.guid and unit and b.guid ~= UnitGUID(unit))) then return false; end
	return true;
end

function c.Combat()
	local unit = c.Unit();
	return UnitAffectingCombat("player") or InCombatLockdown() or (unit and UnitAffectingCombat(unit));
end

function c.OtherBusy()
	local t = UnBotPVPSquad.transport;
	return not t or t.Busy() or t.Settling() or UnBotPVPSummon.active
		or next(UnBotPVPSummon.cleanup or {}) or (UnBotSquadSummon and UnBotSquadSummon.active)
		or (UnBotGunshipMasterLoot and UnBotGunshipMasterLoot.paused)
		or (UnBotTalentInfo and UnBotTalentInfo.job)
		or (UnBotBotScanner and UnBotBotScanner.pendingTalentAudit);
end

function c.CloseInspect()
	c.inspect, c.firstSnapshot = nil, nil;
	if (c.ownsInspect and ClearInspectPlayer) then ClearInspectPlayer(); end
	c.ownsInspect = false;
end

function c.Pause(reason)
	local j = c.Job();
	c.active, c.op = false, nil;
	c.CloseInspect();
	if (j) then j.status, j.reason, j.updatedAt = "paused", reason, time(); end
	c.Message("остановлен: "..reason..". Прогресс сохранён в памяти; /reload запишет его на диск. Продолжить или Стоп для освобождения временного бота.");
end

function c.Request(kind, command, delay)
	c.op = {kind=kind,command=command,attempts=0,at=math.max(GetTime()+(delay or 0),(c.lastSend or -3)+1),deadline=GetTime()+18};
	local j = c.Job(); j.stage, j.updatedAt = kind, time();
end

function c.Get(className, level)
	local record = c.State().classes[className];
	if (not record or not record.complete or record.stale or level ~= 80) then return nil; end
	local summary = UnBotTalentCatalog.State().classes[className];
	if (summary and summary.stale) then return nil; end
	if (summary and summary.complete) then
		if (#(summary.templates or {}) ~= #(record.list or {})) then return nil; end
		local names = {};
		for _, item in ipairs(summary.templates) do names[item.name]=item.build; end
		for _, item in ipairs(record.list or {}) do if (names[item.name] ~= item.build) then return nil; end end
	end
	local result = {};
	for _, item in ipairs(record.list or {}) do
		local snapshot = record.templates and record.templates[item.name] and record.templates[item.name].levels
			and record.templates[item.name].levels[level];
		if (not snapshot or snapshot.build ~= item.build or snapshot.source ~= "server-inspect") then return nil; end
		table.insert(result, {name=item.name,mode=item.name:lower():match("%s+(pvp)$") or item.name:lower():match("%s+(pve)$"),snapshot=snapshot});
	end
	return result;
end

function c.Start(className, refresh, resume)
	if (c.active or c.cleanup) then c.Message("дождитесь окончания текущего сбора/очистки"); return false; end
	if (c.Combat() or c.OtherBusy()) then c.Message("сначала завершите бой и другие операции UnBot"); return false; end
	if (InspectFrame and InspectFrame:IsShown()) then c.Message("закройте окно осмотра перед сбором"); return false; end
	if (not NotifyInspect or not CanInspect or not GetTalentInfo or not GetActiveTalentGroup) then c.Message("API осмотра недоступен"); return false; end
	if (UnitLevel("player") ~= 80) then c.Message("полный каталог требует игрока и временных ботов 80-го уровня"); return false; end
	if ((GetNumRaidMembers()>0 and not IsRaidLeader() and not IsRaidOfficer())
		or (GetNumRaidMembers()==0 and GetNumPartyMembers()>0 and not IsPartyLeader())) then
		c.Message("для временного бота нужны права лидера/помощника"); return false;
	end
	UnBotPVPSquad.transport.Attach();
	if (not UnBotRegistryMatchesCurrentContext(UnBotBotRegistry)) then c.Message("реестр относится к другому серверу/фракции"); return false; end
	local state, j = c.State(), c.Job();
	-- Repeating the same scan after a pause resumes its owned temporary bot
	-- and completed templates rather than requiring the user to discard the job.
	if (not resume and not refresh and j and j.status == "paused"
		and ((className and #j.queue == 1 and j.queue[1] == className)
			or (not className and #j.queue == #UnBotPVPSquad.catalog))) then resume = true; end
	if (resume) then
		if (not j or j.status == "complete") then c.Message("нет незавершённого прохода"); return false; end
	else
		if (j and j.bot) then c.Message("сначала продолжите старый проход или нажмите Стоп для освобождения его бота"); return false; end
		local queue = {};
		for _, info in ipairs(UnBotPVPSquad.catalog) do if (not className or info.className == className) then table.insert(queue,info.className); end end
		if (#queue == 0) then c.Message("неизвестный класс; пример: warrior"); return false; end
		j = {owner=c.Owner(),context=UnBotRegistryCurrentContext(),queue=queue,classIndex=1,presetIndex=1,
			refresh=refresh,done={},original={},used={},collected=0,startedAt=time()};
		for name in pairs(UnBotPVPSquad.transport.Roster()) do j.original[name] = true; end
		state.jobs[c.Owner()] = j;
	end
	-- Reacquire only the saved owned bot. Other roster members remain untouched.
	if (j.bot and not c.SafeBot()) then c.Message("временный бот больше не принадлежит этому проходу; команды отменены"); return false; end
	j.status, j.reason, j.stage, j.updatedAt = "running", nil, "select", time();
	c.active, c.op, c.stage, c.firstSnapshot = true, nil, "select", nil;
	c.deadline, c.lastSend = GetTime()+math.max(300,#j.queue*1800), GetTime()-3;
	c.Message((resume and "продолжаю" or "начинаю")..": классов "..#j.queue..", полных снимков в проходе "..j.collected.."; один временный бот за раз. Таланты временного бота будут меняться.");
	return true;
end

function c.Select()
	local j, t = c.Job(), UnBotPVPSquad.transport;
	if (j.classIndex > #j.queue) then
		j.status, j.stage, j.updatedAt, c.active = "complete", "complete", time(), false;
		c.Message("сбор завершён: "..#j.queue.."/"..#j.queue.." классов; полных снимков "..j.collected..". Выполните /reload для записи на диск."); return;
	end
	local className = j.queue[j.classIndex];
	if (not j.refresh and not j.bot and c.Get(className,80)) then
		j.classIndex, j.presetIndex = j.classIndex+1, 1; return;
	end
	if (not j.bot) then
		local names = t.Candidates(className,"any",j.used);
		for _, name in ipairs(names) do
			local p = UnBotBotRegistry.bots[name];
			if (p and p.level == 80 and not j.original[name] and not UnBotSquadRosterFindUnit(name)
				and not UnBotIsAccountAltProfile(name,p) and not UnBotSquadRosterIsOfflineReserve(name)) then
				j.bot, j.used[name] = {name=name,className=className}, true; break
			end
		end
		if (not j.bot) then c.Pause(className..": нет доступного обычного бота 80-го уровня вне группы"); return; end
	end
	if (not c.Unit()) then
		if (UnBotPVPSummon.Occupied() >= UnBotPVPSummon.MemberLimit()) then c.Pause("нет свободного места для временного бота"); return; end
		if (GetNumRaidMembers()==0 and GetNumPartyMembers()==4) then
			ConvertToRaid(); c.convertWait = GetTime()+5; c.stage = "convert"; return;
		end
		c.Request("join",".playerbot bot add "..j.bot.name);
	else c.Request("who","who"); end
end

function c.NextPreset()
	local j, record = c.Job(), c.State().classes[c.Job().queue[c.Job().classIndex]];
	j.done[j.bot.className] = j.done[j.bot.className] or {};
	while j.presetIndex <= #j.list do
		local item = j.list[j.presetIndex];
		local saved = record.templates[item.name] and record.templates[item.name].levels and record.templates[item.name].levels[80];
		if (saved and saved.source == "server-inspect" and saved.build == item.build
			and (not j.refresh or j.done[j.bot.className][item.name] == item.build)) then j.presetIndex = j.presetIndex+1;
		else
			c.target, c.firstSnapshot = item, nil;
			c.Request("apply","talents spec "..item.name);
			c.Message(j.bot.className..": "..j.presetIndex.."/"..#j.list.." - "..item.name);
			return;
		end
	end
	record.complete, record.stale, record.checkedAt = true, false, time();
	c.Message(j.bot.className..": полный каталог готов, "..#j.list.." шаблонов");
	c.Release(true);
end

function c.ReadSnapshot(unit, expected, observedLevel)
	local level = observedLevel or 80;
	if ((not observedLevel and not c.SafeBot()) or not unit or not UnitIsConnected(unit) or UnitLevel(unit) ~= level) then return nil,"бот недоступен/уровень изменился"; end
	local group = GetActiveTalentGroup(true);
	if (not group or group < 1 or group > 2) then return nil,"нет активной группы талантов"; end
	local snapshot = {level=level,activeTalentGroup=group,trees={},source="server-inspect",checkedAt=time()};
	local sums, fingerprint, total = {}, {}, 0;
	for tab = 1,3 do
		local name, _, declared = GetTalentTabInfo(tab,true,false,group);
		local count = GetNumTalents(tab,true,false);
		if (not name or not count or count < 1 or count > 50) then return nil,"не загружено дерево "..tab; end
		local tree = {name=name,index=tab,talents={},ranks="",points=0};
		for index = 1,count do
			local label, _, tier, column, rank, maxRank = GetTalentInfo(tab,index,true,false,group);
			if (not label or type(rank) ~= "number" or type(maxRank) ~= "number" or rank < 0
				or rank > maxRank or maxRank < 1 or maxRank > 5 or rank ~= math.floor(rank)) then return nil,"неполные данные таланта"; end
			local link = GetTalentLink and GetTalentLink(tab,index,true,false,group);
			local talentId = link and tonumber(link:match("talent:(%d+)"));
			table.insert(tree.talents,{index=index,name=label,tier=tier,column=column,rank=rank,maxRank=maxRank,talentId=talentId});
			tree.ranks, tree.points = tree.ranks..rank, tree.points+rank;
		end
		if (declared ~= tree.points) then return nil,"очки дерева не совпадают с рангами"; end
		table.insert(snapshot.trees,tree); table.insert(sums,tree.points); table.insert(fingerprint,tree.ranks);
		total = total+tree.points;
	end
	snapshot.build, snapshot.fingerprint = table.concat(sums,"-"), table.concat(fingerprint,"-");
	if ((not observedLevel and total ~= 71) or total > math.max(0,level-9) or (expected and snapshot.build ~= expected)) then return nil,"осмотр не совпал с серверным шаблоном ("..snapshot.build..")"; end
	return snapshot;
end

function c.BeginInspect()
	c.stage = "inspect";
	c.Job().stage = "inspect";
	c.inspect = {attempts=0,at=math.max(GetTime()+1,(c.lastInspect or -3)+2),deadline=GetTime()+24};
end

function c.StoreSnapshot(snapshot)
	local j, className = c.Job(), c.Job().bot.className;
	local record = c.State().classes[className];
	local template = record.templates[c.target.name] or {};
	template.name, template.mode = c.target.name, c.target.name:lower():match("%s+(pvp)$") or c.target.name:lower():match("%s+(pve)$");
	template.levels = template.levels or {};
	for key, value in pairs(template.levels[80] or {}) do if (snapshot[key] == nil) then snapshot[key]=value; end end
	template.levels[80] = snapshot;
	record.templates[c.target.name] = template;
	j.done[className][c.target.name], j.collected, j.updatedAt = c.target.build, j.collected+1, time();
	-- The temporary bot really changed on the server. Keep registry hints current
	-- and invalidate older observations without erasing their history/unknown fields.
	local p = UnBotBotRegistry.bots[j.bot.name];
	if (p) then
		p.talentSnapshot, p.talentBuild, p.specCheckedAt = snapshot, snapshot.build:gsub("-","/"), time();
		p.talentSnapshotStale = false;
		local branch = c.current.name:gsub("%s+pvp$",""):gsub("%s+pve$","");
		local aliases = UnBotPVPSquad.transport.SpecAliases[branch];
		p.specName = aliases and aliases[1] or branch;
		if (className == "druid") then
			local role = c.target.name:lower():match("^(.-)%s+p[vV][eEpP]$");
			if (role == "cat" or role == "bear") then p.feralRole, p.feralRoleSource = role,"server-template"; end
		end
		if (p.pvpObservation) then p.pvpObservation.source = "full-catalog-changed"; end
		if (p.pveObservation) then p.pveObservation.source = "full-catalog-changed"; end
	end
	c.Message("снимок подтверждён: "..className.." / "..c.target.name.." ("..snapshot.build..")");
	j.presetIndex, c.stage = j.presetIndex+1, "preset";
	c.CloseInspect();
end

function c.InspectReady()
	local request, unit = c.inspect, c.Unit();
	if (not c.active or not request or not request.waiting or not c.ownsInspect
		or not unit or UnitGUID(unit) ~= request.guid or c.Combat() or c.OtherBusy()
		or (InspectFrame and InspectFrame:IsShown())) then return; end
	request.waiting = false;
	local snapshot, reason = c.ReadSnapshot(unit,c.target.build);
	if (snapshot and c.firstSnapshot and snapshot.fingerprint == c.firstSnapshot.fingerprint
		and snapshot.activeTalentGroup == c.firstSnapshot.activeTalentGroup) then c.StoreSnapshot(snapshot); return; end
	c.firstSnapshot, request.reason = snapshot, reason;
	request.at = GetTime()+2;
end

function c.Release(advance)
	local j = c.Job();
	c.active, c.op = false, nil; c.CloseInspect();
	if (not j or not j.bot) then return; end
	c.cleanup = {at=GetTime(),deadline=GetTime()+30,attempts=0,advance=advance,missingAt=nil};
	j.status, j.stage, j.updatedAt = "paused", "release", time();
end

function c.Stop()
	local j = c.Job();
	if (c.cleanup) then return; end
	if (not j or not j.bot) then
		c.active, c.op = false,nil; c.CloseInspect();
		if (j and j.status ~= "complete") then j.status = "paused"; end
		c.Message("сбор остановлен; полученные шаблоны сохранены"); return;
	end
	c.Release(false);
	c.Message("сбор остановлен; освобождаю только временного бота этого прохода");
end

function c.TickCleanup()
	local j, r = c.Job(), c.cleanup;
	if (not j or not j.bot or not c.SafeBot()) then c.cleanup=nil; c.Pause("потеряно подтверждение временного бота; очистка отменена"); return; end
	if (c.Combat()) then
		c.cleanup=nil; c.Pause("бой; освобождение бота отложено до ручного Стоп вне боя"); return;
	end
	if (c.OtherBusy()) then c.cleanup=nil; c.Pause("другая операция; очистка отменена"); return; end
	local now, unit = GetTime(), c.Unit();
	if (now >= r.deadline) then c.cleanup=nil; c.Pause("таймаут освобождения временного бота"); return; end
	if (not unit) then
		-- Late add replies must settle before allowing the next temporary slot.
		if (j.bot.sentAdd and not j.bot.guid and now < r.deadline-5) then return; end
		if (not r.missingAt) then r.missingAt=now; return; end
		if (now-r.missingAt < .5) then return; end
		if (j.bot.guid and j.bot.sentAdd) then SendChatMessage(".playerbot bot remove "..j.bot.name,"SAY"); end
		local confirmed = j.bot.guid;
		if (not r.advance) then j.used[j.bot.name]=nil; end
		j.bot, c.cleanup = nil,nil;
		if (r.advance) then
			j.classIndex, j.presetIndex, j.list = j.classIndex+1,1,nil;
			j.status, c.active, c.stage = "running",true,"select";
		else
			j.status="paused";
			c.Message(confirmed and "временный бот освобождён; можно продолжить после /reload"
				or "подключение не подтвердилось; запрос закрыт без отключения неопознанного бота");
		end
		return;
	end
	r.missingAt = nil;
	if (not j.bot.guid) then j.bot.guid=UnitGUID(unit); end
	if (not UnitIsConnected(unit)) then c.cleanup=nil; c.Pause("временный бот офлайн в ростере; очистка остановлена"); return; end
	if (now >= r.at and r.attempts < 3) then
		r.attempts, r.at = r.attempts+1,now+5;
		UnBotPVPSquad.transport.Uninvite(j.bot.name);
	end
end

function c.Reply(event, message, sender)
	local j, op = c.Job(), c.op;
	if (not c.active or not j or not j.bot or not op or op.attempts==0 or c.Combat() or not c.SafeBot()) then return; end
	local clean = UnBotPVPSummon.Clean(message);
	if (event == "CHAT_MSG_SYSTEM") then
		if (op.kind == "join" and clean:find(j.bot.name:lower(),1,true)
			and (clean:find("already logged in",1,true) or clean:find("already in group",1,true)
				or clean:find("not found",1,true) or clean:find("not in your instance",1,true))) then
			if (not c.Unit()) then j.bot=nil; end
			c.Pause("сервер отказал в подключении: "..clean);
		end
		return;
	end
	if (sender ~= j.bot.name) then return; end
	for _, refusal in ipairs({"unknown command","unknown spell","cannot cast","no items","too low","i'll do it later","i will do it later","not found"}) do
		if (clean:find(refusal,1,true)) then c.Pause("сервер отказал: "..clean); return; end
	end
	if (op.kind == "join" and clean == "hello!") then j.bot.addAck=true; return; end
	if (op.kind == "who") then
		local who = UnBotParseBotWho(message);
		if (not who or not who.className or not who.level) then return; end
		if (who.className ~= j.bot.className or who.level ~= 80) then c.Pause("временный бот другого класса или не 80-го уровня"); return; end
		j.bot.guid = UnitGUID(c.Unit());
		if (not j.bot.guid) then c.Pause("нет GUID временного бота"); return; end
		c.op = nil;
		if (not UnBotPVPSummon.Near(j.bot)) then c.Request("arrival","summon"); else c.Request("list","talents spec list"); end
	elseif (op.kind == "list") then
		local list = UnBotTalentCatalog.ReadReply(op,message);
		if (not list) then return; end
		local record = c.State().classes[j.bot.className] or {};
		record.templates, record.list, record.complete, record.stale = record.templates or {},list,false,false;
		record.listCheckedAt = time(); c.State().classes[j.bot.className] = record;
		UnBotTalentCatalog.Store(j.bot.className,list);
		j.list, j.presetIndex, c.op, c.stage = list,1,nil,"preset";
	elseif (op.kind == "apply" and clean == "picking "..UnBotPVPSummon.Clean(c.target.name)) then
		c.Request("talents","talents",1);
	elseif (op.kind == "talents") then
		local current = UnBotPVPSummon.Current(message);
		if (not current) then return; end
		if (current.name:match("%s+pvp$") or current.name:match("%s+pve$")) then
			if (current.name ~= UnBotPVPSummon.Clean(c.target.name)) then c.Pause("сервер вернул имя другого шаблона"); return; end
		end
		if (current.build ~= c.target.build or current.points ~= 71) then c.Pause("talents не совпал с применённым шаблоном"); return; end
		c.current, c.op = current,nil;
		c.BeginInspect();
	end
end

function c.Update()
	if (GetTime() < (c.nextTick or 0)) then return; end
	c.nextTick = GetTime()+.1;
	if (c.cleanup) then c.TickCleanup(); return; end
	if (not c.active) then return; end
	local j, unit = c.Job(), c.Unit();
	if (not j or j.owner ~= c.Owner() or j.context ~= UnBotRegistryCurrentContext()) then
		c.active, c.op = false,nil; c.CloseInspect(); c.Message("сменился персонаж/контекст; проход остановлен"); return;
	end
	if (c.Combat() or c.OtherBusy()) then c.Pause("бой или другая операция UnBot"); return; end
	if (InspectFrame and InspectFrame:IsShown()) then c.Pause("открыт ручной осмотр; автоматический запрос отменён"); return; end
	if (GetTime() >= c.deadline) then c.Pause("истёк общий таймаут прохода"); return; end
	if (j.bot and not c.SafeBot()) then c.Pause("временный бот стал защищённым или сменился GUID"); return; end
	if (unit and (not UnitIsConnected(unit) or UnitIsDeadOrGhost(unit))) then c.Pause("временный бот офлайн или мёртв"); return; end
	if (c.stage == "convert") then
		if (GetNumRaidMembers()>0) then c.stage="select";
		elseif (GetTime()>=c.convertWait) then c.Pause("сервер не перевёл группу в рейд"); end
		return;
	end
	if (c.inspect) then
		local request = c.inspect;
		if (not unit or not UnBotPVPSummon.Near(j.bot) or not CanInspect(unit)) then c.Pause("бот недоступен для осмотра рядом"); return; end
		if (GetTime() >= request.deadline) then c.Pause(request.reason or "нет двух подтверждённых снимков осмотра за 24 секунды"); return; end
		if (GetTime() >= request.at) then
			if (request.attempts >= 3) then c.Pause(request.reason or "осмотр не подтверждён после трёх запросов"); return; end
			request.attempts, request.guid, request.waiting = request.attempts+1,UnitGUID(unit),true;
			request.at, c.lastInspect, c.ownsInspect, c.notifying = GetTime()+6,GetTime(),true,true;
			NotifyInspect(unit); c.notifying=false;
		end
		return;
	end
	local op = c.op;
	if (not op) then if (c.stage == "preset") then c.NextPreset(); else c.Select(); end return; end
	if ((op.kind == "join" or op.kind == "invite") and unit) then c.Request("who","who",1); return; end
	if (op.kind == "arrival" and UnBotPVPSummon.Near(j.bot)) then c.Request("list","talents spec list"); return; end
	if (op.kind ~= "join" and op.kind ~= "invite" and not unit) then c.Pause("временный бот покинул группу"); return; end
	if (GetTime() >= op.deadline) then c.Pause("таймаут запроса "..op.command); return; end
	if (GetTime() < op.at) then return; end
	if (op.kind ~= "join" and op.kind ~= "invite" and op.kind ~= "arrival" and not UnBotPVPSummon.Near(j.bot)) then
		c.Pause("временный бот перестал быть доступен рядом"); return;
	end
	if (op.attempts >= 3) then
		if (op.kind=="join" and j.bot.sentAdd) then c.Request("invite","invite");
		else c.Pause("нет ответа после трёх отправок "..op.command); end
		return;
	end
	op.attempts, op.at, c.lastSend = op.attempts+1,GetTime()+5,GetTime();
	if (op.kind=="list") then op.catalogMap,op.catalogExpected={},nil; end
	if (op.kind=="join") then
		if (UnBotPVPSummon.Occupied() >= UnBotPVPSummon.MemberLimit()) then c.Pause("нет свободного места для временного бота"); return; end
		j.bot.sentAdd=true; SendChatMessage(op.command,"SAY");
	elseif (op.kind=="invite") then InviteUnit(j.bot.name);
	else
		if (op.kind=="apply" and op.attempts==1) then
			-- Application can succeed even if Picking/inspection is lost or Stop
			-- happens immediately afterwards. Never retain old readiness proof.
			local p=UnBotBotRegistry.bots[j.bot.name];
			p.talentSnapshotStale=true;
			if (p.pvpObservation) then p.pvpObservation.source="full-catalog-changed"; end
			if (p.pveObservation) then p.pveObservation.source="full-catalog-changed"; end
		end
		SendChatMessage(op.command,"WHISPER",nil,j.bot.name);
	end
end

function c.Text()
	local j, lines = c.Job(), {"Полные серверные шаблоны / "..UnBotTalentCatalog.Realm(),
		"Применение пресетов меняет таланты временного бота. Полные деревья собираются на 80-м уровне.",
		"Прогресс записывается на диск при /reload или нормальном выходе. После reload нажмите Продолжить.",
		"Временный бот остаётся в последнем применённом пресете. Альты и исходная группа не меняются.",""};
	if (j) then
		local statuses = {running="идёт",paused="пауза",complete="завершён"};
		local stages = {select="выбор бота",join="подключение",invite="приглашение",who="сведения о боте",arrival="прибытие",list="список пресетов",apply="применение пресета",talents="проверка талантов",inspect="осмотр",release="освобождение",complete="завершён"};
		table.insert(lines,"Проход: "..(statuses[j.status] or j.status).." / класс "..math.min(j.classIndex,#j.queue).." из "..#j.queue.." / снимков "..j.collected);
		if (j.bot) then table.insert(lines,"Временный бот: "..j.bot.name.." / этап "..(stages[j.stage] or tostring(j.stage))); end
		if (j.reason) then table.insert(lines,"Причина остановки: "..j.reason); end
	end
	for _, info in ipairs(UnBotPVPSquad.catalog) do
		local record = c.State().classes[info.className];
		local count = 0;
		for _, item in ipairs(record and record.list or {}) do
			local template = record.templates[item.name];
			if (template and template.levels and template.levels[80] and template.levels[80].build==item.build) then count=count+1; end
		end
		table.insert(lines,info.label..": "..count.."/"..tostring(record and #(record.list or {}) or "?")..(c.Get(info.className,80) and " / готов" or " / не завершён"));
		for _, item in ipairs(record and record.list or {}) do
			local template = record.templates[item.name]; local snapshot = template and template.levels and template.levels[80];
			table.insert(lines,"  "..item.name.." ("..item.build..") / "..(snapshot and snapshot.build==item.build and "снимок есть" or "ожидает"));
		end
	end
	return table.concat(lines,"\n");
end

function c.Serialize(value)
	if (type(value)=="string") then return string.format("%q",value); end
	if (type(value)=="number" or type(value)=="boolean") then return tostring(value); end
	if (type(value)~="table") then return "nil"; end
	local keys, parts = {},{};
	for key in pairs(value) do table.insert(keys,key); end
	table.sort(keys,function(a,b) return tostring(a)<tostring(b); end);
	for _, key in ipairs(keys) do table.insert(parts,"["..c.Serialize(key).."]="..c.Serialize(value[key])); end
	return "{"..table.concat(parts,",\n").."}";
end

function c.Render()
	if (c.edit) then
		local text = c.exportView and c.Serialize({realm=UnBotTalentCatalog.Realm(),schemaVersion=1,classes=c.State().classes}) or c.Text();
		local _, lines = text:gsub("\n","");
		c.edit:SetHeight(math.max(320,(lines+1)*16)); c.edit:SetText(text);
	end
end

function c.Show(export)
	c.exportView = export;
	if (not c.window) then
		local f = CreateFrame("Frame","UnBotFullTalentCatalogWindow",UIParent);
		f:SetWidth(750); f:SetHeight(540); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG");
		f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=32,insets={left=8,right=8,top=8,bottom=8}});
		f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton");
		f:SetScript("OnDragStart",function(self) self:StartMoving(); end); f:SetScript("OnDragStop",function(self) self:StopMovingOrSizing(); end);
		local close = CreateFrame("Button",nil,f,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",-5,-5);
		local title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); title:SetPoint("TOP",0,-18); title:SetText("Сбор полного каталога талантов");
		local scroll=CreateFrame("ScrollFrame","UnBotFullTalentCatalogScroll",f,"UIPanelScrollFrameTemplate");
		scroll:SetPoint("TOPLEFT",20,-48); scroll:SetPoint("BOTTOMRIGHT",-42,100);
		local edit=CreateFrame("EditBox",nil,scroll); edit:SetMultiLine(true); edit:SetAutoFocus(false); edit:SetFontObject(GameFontHighlightSmall);
		edit:SetWidth(675); edit:SetHeight(320); edit:SetMaxLetters(0); scroll:SetScrollChild(edit);
		edit:SetScript("OnEscapePressed",function(self) self:ClearFocus(); f:Hide(); end);
		edit:SetScript("OnTextChanged",function() scroll:UpdateScrollChildRect(); end);
		local label=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); label:SetPoint("BOTTOMLEFT",22,74); label:SetText("Класс:");
		local input=CreateFrame("EditBox",nil,f,"InputBoxTemplate"); input:SetWidth(115); input:SetHeight(22); input:SetPoint("BOTTOMLEFT",76,67); input:SetAutoFocus(false); input:SetText("warrior");
		input:SetScript("OnEscapePressed",function(self) self:ClearFocus(); end);
		local keys=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); keys:SetPoint("BOTTOMLEFT",205,73); keys:SetText("warrior, paladin, hunter, rogue, priest, shaman, mage, warlock, druid, dk");
		for i, info in ipairs({{"Все классы",function() c.Start(nil,false,false); end},
			{"Один класс",function() c.Start(UnBotPVPSummon.Clean(input:GetText()),false,false); end},
			{"Продолжить",function() c.Start(nil,false,true); end}, {"Стоп",c.Stop}, {"Экспорт",function() c.Show(true); end}}) do
			local b=UnBotPVPSquad.Button(f,info[1],132,info[2]); b:SetPoint("BOTTOMLEFT",20+(i-1)*142,25);
		end
		c.window,c.edit,c.scroll=f,edit,scroll;
		if (UISpecialFrames) then table.insert(UISpecialFrames,"UnBotFullTalentCatalogWindow"); end
	end
	c.Render(); c.scroll:SetVerticalScroll(0); c.edit:ClearFocus(); c.window:Show();
	if (export) then c.edit:SetFocus(); c.edit:HighlightText(); end
end

SLASH_UNBOTFULLTALENTCATALOG1 = "/ubfullcatalog";
SlashCmdList.UNBOTFULLTALENTCATALOG = function(text)
	local command,className=UnBotPVPSummon.Clean(text):match("^(%S+)%s*(.-)$");
	if (className=="") then className=nil; end
	if (command=="scan" or command=="refresh") then c.Start(className,command=="refresh",false);
	elseif (command=="resume") then c.Start(nil,false,true);
	elseif (command=="stop") then c.Stop();
	elseif (command=="status") then c.Message(c.Text());
	elseif (command=="export") then c.Show(true);
	else c.Show(false); end
end;

c.frame=CreateFrame("Frame","UnBotFullTalentCatalogController");
for _, event in ipairs({"CHAT_MSG_WHISPER","CHAT_MSG_SYSTEM","INSPECT_TALENT_READY","PLAYER_LOGIN","PLAYER_LOGOUT"}) do c.frame:RegisterEvent(event); end
c.frame:SetScript("OnUpdate",c.Update);
c.frame:SetScript("OnEvent",function(self,event,message,sender)
	if (event=="INSPECT_TALENT_READY") then c.InspectReady();
	elseif (event=="PLAYER_LOGOUT") then
		local j=c.Job();
		if (j and j.status~="complete") then j.status,j.updatedAt="paused",time(); end
		c.active,c.op,c.cleanup=false,nil,nil; c.CloseInspect();
	elseif (event=="PLAYER_LOGIN") then
		local j=c.Job();
		if (j and j.status~="complete") then
			j.status="paused";
			c.Message("есть незавершённый проход; /ubfullcatalog resume продолжит, /ubfullcatalog stop освободит временного бота");
		end
	else c.Reply(event,message,sender); end
end);
if (hooksecurefunc and NotifyInspect) then
	hooksecurefunc("NotifyInspect",function(unit)
		-- DBM/GearScore can inspect a new member before our first request.
		-- Only the window containing our in-flight reply / first snapshot owns
		-- the inspection cache and can be invalidated by a competing request.
		if (c.active and c.inspect and (c.ownsInspect or c.firstSnapshot) and not c.notifying) then
			c.ownsInspect=false;
			c.Pause("другой интерфейс/аддон запросил осмотр; чужие данные не приняты");
		end
	end);
end
end

-- One read-only talent source for registry scans, class audits and both pages.
-- Point totals are a cache sanity check, never evidence of PvE/PvP.
UnBotTalentInfo = UnBotTalentInfo or {};
do
local t = UnBotTalentInfo;
t.labels = {all="Все",pve="PvE",pvp="PvP",unknown="Неизвестно"};

function t.Role(className, preset)
	local branch = string.lower(tostring(preset or "")):gsub("%s+pve$",""):gsub("%s+pvp$","");
	if (className=="druid" and (branch=="cat" or branch=="bear")) then return "feral "..branch; end
	local aliases = UnBotPVPSquad.transport.SpecAliases[branch];
	return aliases and aliases[1] or branch;
end

function t.Same(a,b)
	if (not a or not b or a.level~=b.level or a.build~=b.build or a.fingerprint~=b.fingerprint
		or type(a.trees)~="table" or type(b.trees)~="table" or #a.trees~=3 or #b.trees~=3) then return false; end
	for tab=1,3 do
		local x,y=a.trees[tab],b.trees[tab];
		if (not x or not y or not x.talents or not y.talents or #x.talents~=#y.talents) then return false; end
		for i,rank in ipairs(x.talents) do
			local other=y.talents[i];
			if (rank.rank~=other.rank or rank.maxRank~=other.maxRank or rank.tier~=other.tier or rank.column~=other.column
				or (rank.talentId and other.talentId and rank.talentId~=other.talentId)) then return false; end
		end
	end
	return true;
end

function t.Resolve(className,snapshot)
	local result={mode="unknown",source="server-inspect",checkedAt=snapshot and snapshot.checkedAt,reason="Нет полного осмотра талантов"};
	if (not snapshot or snapshot.source~="server-inspect") then return result; end
	local templates=UnBotFullTalentCatalog.Get(className,snapshot.level);
	if (not templates or #templates==0) then result.reason="Полный каталог этого класса и уровня ещё не собран"; return result; end
	local modes,roles,names={},{},{};
	for _,item in ipairs(templates) do
		if (t.Same(snapshot,item.snapshot)) then
			table.insert(names,item.name); modes[item.mode or "unknown"]=true; roles[t.Role(className,item.name)]=true;
		end
	end
	result.candidates=names;
	if (#names==0) then result.reason="Билд отличается от шаблонов сервера"; return result; end
	local role,roleCount=nil,0;
	for value in pairs(roles) do role,roleCount=value,roleCount+1; end
	if (roleCount==1) then result.specRole=role; end
	if (modes.pve and not modes.pvp and not modes.unknown) then result.mode="pve";
	elseif (modes.pvp and not modes.pve and not modes.unknown) then result.mode="pvp";
	else result.reason="Одинаковые таланты у шаблонов разных режимов"; return result; end
	result.reason=nil;
	if (#names==1) then result.preset=names[1]; end
	return result;
end

t.cache=setmetatable({}, {__mode="k"});
t.emptyCacheRecord={};

function t.SnapshotKey(snapshot)
 local parts={};
 for tab,tree in ipairs(snapshot.trees or {}) do
  parts[#parts+1]=tostring(tab);
  for _,rank in ipairs(tree.talents or {}) do
   parts[#parts+1]=table.concat({tostring(rank.rank),tostring(rank.maxRank),tostring(rank.tier),
    tostring(rank.column),tostring(rank.talentId)},",");
  end
 end
 return table.concat(parts,";");
end

function t.CacheKey(profile)
 local snapshot=profile.talentSnapshot or {};
 local full=UnBotFullTalentCatalog.State().classes[profile.className] or t.emptyCacheRecord;
 local summary=UnBotTalentCatalog.State().classes[profile.className] or t.emptyCacheRecord;
 local templates={};
 for _,item in ipairs(full.list or {}) do
  local record=full.templates and full.templates[item.name];
  local snap=record and record.levels and record.levels[tonumber(profile.level)];
  templates[#templates+1]=tostring(item.name)..":"..tostring(item.build)..":"..tostring(snap)
   ..":"..tostring(snap and snap.build)..":"..tostring(snap and snap.checkedAt)..":"..tostring(snap and snap.fingerprint);
 end
 return table.concat({tostring(UnBotBotRegistry),tostring(UnBotRegistryCurrentContext()),
  tostring(profile.className),tostring(profile.level),tostring(profile.talentSnapshot),
  tostring(snapshot.level),tostring(snapshot.context),tostring(snapshot.checkedAt),
  tostring(snapshot.fingerprint),tostring(snapshot.build),tostring(snapshot.source),tostring(snapshot.trees),t.SnapshotKey(snapshot),table.concat(templates,";"),
  tostring(profile.talentSnapshotStale),tostring(profile.talentReadError),
  tostring(full),tostring(full.complete),tostring(full.stale),tostring(full.list),tostring(full.templates),
  tostring(summary),tostring(summary.complete),tostring(summary.stale),tostring(summary.templates)},"|");
end

function t.Get(profile)
	profile=profile or {};
	local cacheKey,now=t.CacheKey(profile),GetTime();
	local cached=t.cache[profile];
	if cached and cached.key==cacheKey and now>=cached.at and now-cached.at<1
		and profile.talentClassification==cached.value then return cached.value;end
	local result;
	if (not UnBotRegistryMatchesCurrentContext(UnBotBotRegistry)) then
		result={mode="unknown",reason="Реестр относится к другому серверу/фракции"};
	elseif (profile.talentSnapshotStale) then
		result={mode="unknown",reason=profile.talentReadError or "Таланты требуют повторного осмотра"};
	elseif (profile.talentSnapshot and profile.talentSnapshot.level~=tonumber(profile.level)) then
		result={mode="unknown",reason="Уровень изменился после осмотра"};
	elseif (profile.talentSnapshot and profile.talentSnapshot.context and profile.talentSnapshot.context~=UnBotRegistryCurrentContext()) then
		result={mode="unknown",reason="Осмотр относится к другому серверу/фракции"};
	else result=t.Resolve(profile.className,profile.talentSnapshot); end
	local saved=profile.talentClassification or {};
	-- Preserve extension fields; replace only fields owned by this classifier.
	for _,key in ipairs({"mode","reason","source","checkedAt","preset","specRole","candidates"}) do saved[key]=result[key]; end
	profile.talentClassification=saved;
	t.cache[profile]={key=cacheKey,at=now,value=saved};
	return saved;
end

function t.Spec(profile)
	local result=t.Get(profile);
	if (result.specRole) then return result.specRole; end
	local spec=profile and profile.specName or "";
	if (profile and profile.className=="druid" and profile.talentSnapshot and not profile.talentSnapshotStale
		and (spec=="feral combat" or spec=="feral bear" or spec=="feral cat")) then return "feral combat"; end
	return nil;
end

function t.Invalidate(profile,reason)
	if (not profile) then return; end
	t.cache[profile]=nil;
	if UnBotSquadBuilderUI then UnBotSquadBuilderUI.Dirty();end
	local owner=UnBotPVPSquad.transport.PVEOwner;
	if owner and owner.confirmedRoster then
		for name,record in pairs(owner.confirmedRoster.entries) do if record.profile==profile then owner.confirmedRoster.Forget(name);end end
	end
	profile.talentSnapshotStale=true; profile.talentReadError=reason; profile.talentReadAttemptAt=time();
	t.Get(profile);
end

function t.ObserveWho(profile,info)
	if UnBotSquadBuilderUI then UnBotSquadBuilderUI.Dirty();end
	local snapshot=profile.talentSnapshot;
	if (snapshot and (snapshot.level~=tonumber(info.level)
		or (info.talentBuild and snapshot.build~=info.talentBuild:gsub("/","-"))
		or (snapshot.className and snapshot.className~=info.className))) then t.Invalidate(profile,"who изменился после осмотра"); end
	if (info.talentBuild) then profile.talentBuild=info.talentBuild; end
end

function t.Store(name,snapshot)
	local p=UnBotBotRegistry.bots[name];
	if (not p) then return; end
	snapshot.context,snapshot.className=UnBotRegistryCurrentContext(),p.className;
	p.talentSnapshot,p.talentSnapshotStale,p.talentReadError=snapshot,false,nil;
	t.cache[p]=nil;
	if UnBotSquadBuilderUI then UnBotSquadBuilderUI.Dirty();end
	p.talentBuild,p.talentReadAttemptAt=snapshot.build:gsub("-","/"),time();
	if (UnBotDKSpecBalance and UnBotDKSpecBalance.auditUnavailable) then UnBotDKSpecBalance.auditUnavailable[name]=nil; end
	local classification=t.Get(p);
	if (classification.specRole) then
		p.specName=classification.specRole;
		if (p.className=="druid") then
			p.feralRole=classification.specRole:match("^feral (%S+)$");
			p.feralRoleSource=p.feralRole and "full-talents" or nil;
			p.feralRoleCheckedAt=time();
		end
	end
	UnBotFullTalentCatalog.Message(name..": полные таланты прочитаны — "..t.labels[classification.mode]
		..(classification.preset and (" / "..classification.preset) or ""));
	if (UnBotSpecAuditRefresh) then UnBotSpecAuditRefresh(); end
end

function t.Cancel(owner, completed)
	local job=t.job;
	if (job and (not owner or job.owner==owner)) then
		if (not completed and UnBotSummonLog) then UnBotSummonLog.Safe("Inspect","inspect_cancel",job,"owner cancelled"); end
		t.job=nil;
		if (NotifyInspect == job.notifyGuard) then NotifyInspect = job.notifyInspect; end
		if (job.owns and ClearInspectPlayer) then ClearInspectPlayer(); end
	end
end

function t.Finish(snapshot,reason)
	local job=t.job;
	if (not job) then return; end
	if (UnBotSummonLog) then UnBotSummonLog.Safe("Inspect","inspect_finish",job,snapshot and "snapshot confirmed" or reason); end
	t.Cancel(job.owner,true);
	if (job.alive and not job.alive()) then return; end
	if (snapshot) then t.Store(job.name,snapshot);
	else
		t.Invalidate(UnBotBotRegistry.bots[job.name],reason);
		UnBotFullTalentCatalog.Message(job.name..": таланты не подтверждены — "..tostring(reason));
	end
	job.done(snapshot,reason);
end

function t.Begin(name,owner,done,alive,expectedSnapshot)
	local p=UnBotBotRegistry.bots[name];
	if (t.job or UnBotFullTalentCatalog.IsBusy() or not p or UnBotIsAccountAltProfile(name,p)
		or UnBotSquadRosterIsOfflineReserve(name) or name==UnitName("player") or not tonumber(p.level) or tonumber(p.level)<10) then
		t.Invalidate(p,"Осмотр недоступен или занят"); done(nil,"Осмотр недоступен или занят"); return;
	end
	t.job={name=name,owner=owner,done=done,alive=alive,className=p.className,level=tonumber(p.level),
		build=p.talentBuild and p.talentBuild:gsub("/","-"),context=UnBotRegistryCurrentContext(),
		expectedSnapshot=expectedSnapshot,deadline=GetTime()+40,at=GetTime()+1,attempts=0,summons=0};
	-- Give this finite read a short exclusive window. A rolling quiet-period
	-- wait starves forever when raid/gear addons inspect once per second.
	-- Capture the previous function per job: later wrappers retain a harmless
	-- pass-through after cancellation, without overwriting another addon's hook.
	local job = t.job;
	job.notifyInspect = NotifyInspect;
	job.notifyGuard = function(unit, ...)
		if (t.job == job and GetTime() < job.deadline and not t.notifying
			and not (job.guid and unit and UnitGUID(unit) == job.guid)) then
			job.deferredRequests = (job.deferredRequests or 0) + 1;
			if (job.deferredRequests == 1 and UnBotSummonLog) then
				UnBotSummonLog.Safe("Inspect","inspect_deferred",job,"background request unit="..tostring(unit));
			end
			return;
		end
		return job.notifyInspect(unit, ...);
	end;
	NotifyInspect = job.notifyGuard;
	if (UnBotSummonLog) then UnBotSummonLog.Safe("Inspect","inspect_begin",t.job,"read-only talents"); end
end

function t.Update()
	local job=t.job;
	if (not job) then return; end
	if (job.alive and not job.alive()) then t.Cancel(job.owner); return; end
	if (GetTime()>=job.deadline) then t.Finish(nil,job.reason or "Таймаут осмотра"); return; end
	if (job.conflict) then
		job.conflict = nil;
		job.conflicts = (job.conflicts or 0) + 1;
		if (job.conflicts >= 2 or job.attempts >= 3) then
			t.Finish(nil,"Осмотр повторно перехвачен другим аддоном; лимит попыток исчерпан"); return;
		end
		job.reason,job.at = "Другой аддон запросил осмотр во время чтения",GetTime()+2;
		UnBotFullTalentCatalog.Message(job.name..": осмотр перехвачен; повторяю после паузы");
	end
	if (GetTime()<(job.at or 0)) then return; end
	local unit=UnBotSquadRosterFindUnit(job.name);
	local p=UnBotBotRegistry.bots[job.name];
	if (not unit or not UnitIsConnected(unit) or UnitIsDeadOrGhost(unit) or not p or p.className~=job.className
		or job.context~=UnBotRegistryCurrentContext() or (job.guid and job.guid~=UnitGUID(unit))) then t.Finish(nil,"Бот недоступен или изменился"); return; end
	if (UnitAffectingCombat("player") or InCombatLockdown() or UnitAffectingCombat(unit)) then t.Finish(nil,"Осмотр остановлен из-за боя"); return; end
	if (InspectFrame and InspectFrame:IsShown()) then t.Finish(nil,"Закройте ручное окно осмотра"); return; end
	local _,token=UnitClass(unit); local className=token and string.lower(token);
	if (className=="deathknight") then className="dk"; end
	if ((className and className~=job.className) or UnitLevel(unit)~=job.level) then t.Finish(nil,"Класс/уровень не совпал с who"); return; end
	job.guid=UnitGUID(unit);
	if (not UnBotPVPSummon.Near(job) or not CanInspect(unit)) then
		if (job.summons>=3) then t.Finish(nil,"Бот не приблизился для осмотра"); return; end
		job.summons,job.at=job.summons+1,GetTime()+5;
		SendChatMessage("summon","WHISPER",nil,job.name); return;
	end
	if (job.attempts>=3) then t.Finish(nil,job.reason or "Нет двух совпадающих ответов осмотра"); return; end
	job.attempts,job.at,job.waiting,job.owns=job.attempts+1,GetTime()+6,true,true;
	if (UnBotSummonLog) then UnBotSummonLog.Safe("Inspect","inspect_request",job,"NotifyInspect"); end
	t.notifying=true; NotifyInspect(unit); t.notifying=false;
end

function t.Ready(guid)
	local job=t.job;
	if (job and UnBotSummonLog) then UnBotSummonLog.Safe("Inspect","inspect_ready",job,
		"INSPECT_TALENT_READY guid="..tostring(guid).." waiting="..tostring(job.waiting).." owns="..tostring(job.owns)
		.." acceptedForRead="..tostring(job.waiting and job.owns and (not guid or guid==job.guid) and true or false)); end
	if (not job or job.conflict or not job.waiting or not job.owns or (guid and guid~=job.guid)) then return; end
	local unit=UnBotSquadRosterFindUnit(job.name);
	if (not unit or UnitGUID(unit)~=job.guid or not UnitIsConnected(unit) or not UnBotPVPSummon.Near(job)) then t.Finish(nil,"Цель осмотра изменилась"); return; end
	job.waiting=false;
	local snapshot,reason=UnBotFullTalentCatalog.ReadSnapshot(unit,job.build,job.level);
	if (not snapshot) then
		if (UnBotSummonLog) then UnBotSummonLog.Safe("Inspect","inspect_invalid",job,reason); end
		job.reason,job.first=reason,nil; job.at=GetTime()+2; return;
	end
	if (job.expectedSnapshot and not t.Same(snapshot,job.expectedSnapshot)) then
		if (UnBotSummonLog) then UnBotSummonLog.Safe("Inspect","inspect_mismatch",job,"different from expected preset"); end
		job.reason,job.first,job.at="Таланты не совпали с применённым шаблоном",nil,GetTime()+2; return;
	end
	if (job.first and t.Same(job.first,snapshot) and job.first.activeTalentGroup==snapshot.activeTalentGroup) then
		if (UnBotSummonLog) then UnBotSummonLog.Safe("Inspect","inspect_match",job,"second matching snapshot"); end
		t.Finish(snapshot); return;
	end
	if (UnBotSummonLog) then UnBotSummonLog.Safe("Inspect",job.first and "inspect_mismatch" or "inspect_first",job,
		job.first and "previous snapshot replaced" or "first valid snapshot accepted"); end
	job.first,job.at=snapshot,GetTime()+2;
end

function t.Targets(className,mode)
	local catalog=UnBotFullTalentCatalog.Get(className,80);
	if (not catalog) then return nil; end
	local result={};
	for _,item in ipairs(catalog) do
		local classification=t.Resolve(className,item.snapshot);
		if (item.mode==mode and classification.mode==mode and classification.specRole) then
			local role=classification.specRole;
			if (not result[role] or item.name<result[role].name) then result[role]=item; end
		end
	end
	return result;
end

function t.SelectionTemplates(className,key,mode,level)
	local catalog=UnBotFullTalentCatalog.Get(className,level);
	if (not catalog) then return nil; end
	local aliases=type(key)=="table" and key or UnBotPVPSquad.transport.SpecAliases[key] or {key};
	local result={};
	for _,item in ipairs(catalog) do
		if (item.mode==mode) then
			local role=t.Role(className,item.name);
			local fits=key=="any" or aliases.anySpec;
			if (aliases.feralRole) then fits=role=="feral "..aliases.feralRole;
			elseif (not fits) then for _,value in ipairs(aliases) do if (role==value) then fits=true; end end end
			if (fits) then item.build=item.snapshot.build; table.insert(result,item); end
		end
	end
	return result;
end

function t.BranchBuild(value)
	local text=tostring(value and (value.talentBuild or value.build or (value.talentSnapshot and value.talentSnapshot.build)) or "");
	local a,b,c=text:match("^(%d+)[/%-](%d+)[/%-](%d+)$");
	if (not a and value and value.rawWho) then a,b,c=value.rawWho:match("%((%d+)[/%-](%d+)[/%-](%d+)%)"); end
	return a and (tonumber(a).."-"..tonumber(b).."-"..tonumber(c));
end

function t.Coarse(value,className,key,mode)
	if (not value or value.className~=className) then return false,"другой класс"; end
	local templates=t.SelectionTemplates(className,key,mode,tonumber(value.level));
	if (not templates) then return nil,"нет полного каталога для этого уровня"; end
	if (#templates==0) then return false,"нет шаблона выбранного спека/режима"; end
	local build=t.BranchBuild(value);
	if (not build) then return true,"очки ещё не известны"; end
	for _,item in ipairs(templates) do if (build==item.snapshot.build) then return true; end end
	return false,"очки "..build.." не подходят для "..mode.." / "..tostring(type(key)=="table" and table.concat(key,"/") or key);
end

function t.CachedMayMatch(profile,className,key,mode)
	-- Stale/missing cache never permanently eliminates an untested bot.
	if (not profile or not profile.talentSnapshot or profile.talentSnapshotStale) then return nil; end
	if (time()-(tonumber(profile.talentSnapshot.checkedAt) or 0)>120) then return nil; end
	if (profile.talentSnapshot.context and profile.talentSnapshot.context~=UnBotRegistryCurrentContext()) then return nil; end
	return t.Coarse(profile,className,key,mode);
end

function t.ConfirmSelection(name,who,className,key,mode,owner,done,alive)
	local possible,reason=t.Coarse(who,className,key,mode);
	if (possible~=true) then done(nil,nil,reason); return; end
	t.Begin(name,owner,function(snapshot,errorText)
		if (not snapshot) then done(nil,nil,errorText); return; end
		if (UnBotIsAccountAltProfile(name,UnBotBotRegistry.bots[name]) or UnBotSquadRosterIsOfflineReserve(name)) then
			done(nil,nil,"кандидат стал защищённым участником"); return;
		end
		local classification=t.Get(UnBotBotRegistry.bots[name]);
		local templates=t.SelectionTemplates(className,key,mode,snapshot.level);
		if (classification.mode==mode and templates) then
			for _,item in ipairs(templates) do
				if (t.Same(snapshot,item.snapshot) and (key=="any" or (type(key)=="table" and key.anySpec)
					or classification.specRole==t.Role(className,item.name))) then done(snapshot,item); return; end
			end
		end
		done(nil,nil,"полные таланты не подтверждают нужный спек и "..mode);
	end,alive);
end

function t.InspectPVE(op)
	local s=UnBotPVPSquad.transport.PVEOwner;
	op.kind,op.attempts,op.deadline="inspect",1,GetTime()+41;
	UnBotSpecSummonStoreRegistryWho(op.name,op.who,op.rawWho);
	UnBotSpecSummonMessage("PVE: "..op.name..": очки подходят; подтверждаю полный набор талантов.");
	t.ConfirmSelection(op.name,op.who,op.className,op.specKey,"pve",s,function(snapshot,item,reason)
		if (not snapshot) then
			s.pvePreset=nil;
			if (op.existing) then s.StopForPreset("PVE: "..op.name..": "..reason.."; текущий участник сохранён");
			else s.RejectForTalent("PVE: "..op.name..": "..reason.."; пробую другого кандидата"); end
			return;
		end
		op.target=item;
		local classification=t.Get(UnBotBotRegistry.bots[op.name]);
		if (classification.specRole) then
			op.who.specName=classification.specRole;
			local role=classification.specRole:match("^feral (%S+)$");
			if (role) then op.who.specName,op.who.feralRole="feral combat",role; end
		end
		UnBotTalentCatalog.FinishPVE(op.who,op.rawWho,"full-inspect");
	end,function() return s.active and s.pvePreset==op and op.kind=="inspect"; end);
end

function t.BalanceWho(state,who,raw)
	local name,task=state.currentName,state.currentTask;
	local post=state.stage=="wait_post_who";
	state.stage="wait_talents";
	t.Begin(name,state,function(snapshot,reason)
		if (not snapshot) then UnBotDKSpecBalanceFailCurrent(reason); return; end
		local classification=t.Get(UnBotBotRegistry.bots[name]);
		if (who.className~=task.className or classification.mode~=state.talentMode or not classification.specRole) then
			UnBotDKSpecBalanceFailCurrent("Донор не подтвердил класс, специализацию или выбранный режим"); return;
		end
		if (post or classification.specRole==task.targetSpec) then
			if (not t.Same(snapshot,task.preset.snapshot)) then UnBotDKSpecBalanceFailCurrent("Шаблон изменился на сервере"); return; end
			UnBotDKSpecBalanceCompleteCurrent(who,raw,task.targetSpec); return;
		end
		if (classification.specRole~=task.sourceSpec
			or UnBotSpecCountBalanceAvailableCount(task.className,task.sourceSpec,state.talentMode)<=(state.minimumCount or 8)) then
			UnBotDKSpecBalanceFailCurrent("У донора больше нет запаса выше минимума"); return;
		end
		local targets=t.Targets(task.className,state.talentMode);
		if (not targets or not targets[task.targetSpec] or not t.Same(targets[task.targetSpec].snapshot,task.preset.snapshot)) then
			UnBotDKSpecBalanceFailCurrent("Каталог цели изменился; повторите проверку класса"); return;
		end
		t.Invalidate(UnBotBotRegistry.bots[name],"Применяется новый шаблон");
		local profile=UnBotBotRegistry.bots[name];
		if (profile.pveObservation) then profile.pveObservation.source="full-catalog-changed"; end
		if (profile.pvpObservation) then profile.pvpObservation.source="full-catalog-changed"; end
		state.stage,state.stageUntil,state.nextTime="wait_talent_preset",GetTime()+12,GetTime()+.25;
		SendChatMessage("talents spec "..task.preset.name,"WHISPER",nil,name);
	end,function() return state.active and state.currentName==name and state.stage=="wait_talents"; end,
		post and task.preset.snapshot or nil);
end

function t.BalanceReply(state,message)
	local clean=UnBotPVPSummon.Clean(message);
	if (clean=="picking "..UnBotPVPSummon.Clean(state.currentTask.preset.name)) then
		UnBotDKSpecBalanceSendWho(true);
	elseif (clean:find("not found",1,true) or clean:find("unknown",1,true) or clean:find("not allowed",1,true)) then
		UnBotDKSpecBalanceFailCurrent("Сервер отклонил шаблон: "..message);
	end
end

t.frame=CreateFrame("Frame"); t.frame:RegisterEvent("INSPECT_TALENT_READY"); t.frame:RegisterEvent("PLAYER_LOGOUT");
t.frame:SetScript("OnUpdate",t.Update);
t.frame:SetScript("OnEvent",function(self,event,guid) if (event=="PLAYER_LOGOUT") then t.Cancel(); else t.Ready(guid); end end);
if (hooksecurefunc and NotifyInspect) then
	hooksecurefunc("NotifyInspect",function(unit)
		local job=t.job;
		if (job and not t.notifying) then
			local guid = unit and UnitGUID(unit);
			if (job.guid and guid == job.guid) then return; end
			if (not job.owns) then return; end
			-- WotLK replies have no reliable target GUID. A foreign reply can
			-- arrive through an API reference cached before our guard: discard
			-- both snapshots, pause once and retry within the original budget.
			if (UnBotSummonLog) then UnBotSummonLog.Safe("Inspect","inspect_conflict",job,
				"foreignGUID="..tostring(guid).." unit="..tostring(unit)
				.." "..(debugstack and debugstack(2,4,0) or "")); end
			job.owns,job.waiting,job.first,job.conflict=false,false,nil,true;
		end
	end);
end
end
