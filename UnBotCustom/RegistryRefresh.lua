-- Persistent oldest-first refresh. The existing read-only audit owns transport.
UnBotRegistryRefresh = {};

function UnBotRegistryRefresh.Key()
	return UnBotRegistryCurrentContext().."|"..tostring(UnitName("player")).."|"..tostring(UnitLevel("player"));
end

function UnBotRegistryRefresh.Job(onlyUndated)
	local jobs = UnBotSquadConfig.registryRefreshJobs;
	local key=UnBotRegistryRefresh.Key();
 if onlyUndated==nil then onlyUndated=UnBotSquadConfig.registryRefreshOnlyUndated and UnBotSquadConfig.registryRefreshOnlyUndated[key];end
 local job = type(jobs) == "table" and jobs[key..(onlyUndated and "|undated" or "")];
	if (type(job) == "table" and job.schema == 1 and type(job.queue) == "table" and type(job.results) == "table") then return job; end
end


-- A complete named refresh, with at least one confirmed specialization, initializes this registry.
function UnBotRegistryRefresh.MarkInitialized(job)
 if not job or job.onlyUndated or job.status~="complete" or #job.queue==0
  or (tonumber(job.verified) or 0)+(tonumber(job.fresh) or 0)==0
  or (UnitLevel("player") or 0)<11 then return;end
 local meta=UnBotBotRegistry.meta or {};UnBotBotRegistry.meta=meta;
 meta.lastRegistrySpecRefreshAt=tonumber(job.finishedAt) or time();
 meta.lastRegistrySpecRefreshContext=UnBotRegistryCurrentContext();
 meta.lastRegistrySpecRefreshServer=tostring(GetCVar and GetCVar("realmList") or ""):lower():gsub("/+$","");
end

function UnBotRegistryRefresh.ReminderState(now)
 now=tonumber(now) or time();
 local context=UnBotRegistryCurrentContext();
 local server=tostring(GetCVar and GetCVar("realmList") or ""):lower():gsub("/+$","");
 local registry=UnBotBotRegistry or {};
 if UnBotRegistryMatchesCurrentContext and not UnBotRegistryMatchesCurrentContext(registry) then return "initial",0;end
 local meta=registry.meta or {};
 local checked=meta.lastRegistrySpecRefreshContext==context and meta.lastRegistrySpecRefreshServer==server
  and tonumber(meta.lastRegistrySpecRefreshAt) or 0;
 -- Recognize completed passes from earlier versions without treating bundled names as initialization.
 if checked==0 and not meta.lastRegistrySpecRefreshAt then
  for key,job in pairs(UnBotSquadConfig and UnBotSquadConfig.registryRefreshJobs or {}) do
   if type(key)=="string" and key:sub(1,#context+1)==context.."|" and type(job)=="table"
    and not job.onlyUndated and job.status=="complete" and type(job.queue)=="table" and #job.queue>0
    and (tonumber(key:match("|(%d+)$")) or 0)>=11
    and (tonumber(job.verified) or 0)+(tonumber(job.fresh) or 0)>0 then
    checked=math.max(checked,tonumber(job.finishedAt) or 0);
   end
  end
 end
 if UnBotRegistryRefresh.Running() then return "running",checked;end
 if (UnitLevel("player") or 0)<11 then return "lowlevel",checked;end
 if checked<=0 then return "initial",0;end
 if now-checked>7*86400 then return "stale",checked;end
 return "current",checked;
end

function UnBotRegistryRefresh.ReminderText(state)
 if state=="initial" then
  return "Сначала инициализируйте реестр ботов: нажмите «Инициализация реестра» в окне состава. Проверка соберёт специализации и ускорит подбор. Призыв доступен и без неё.";
 elseif state=="stale" then
  return "Реестр ботов не обновлялся больше 7 дней. Нажмите «Обновить реестр ботов» в окне состава, чтобы уточнить специализации и ускорить подбор. Призыв остаётся доступен.";
 end
end

function UnBotRegistryRefresh.RemindOnOpen()
 local state=UnBotRegistryRefresh.ReminderState();
 local text=UnBotRegistryRefresh.ReminderText(state);
 if not text then return;end
 local key=tostring(GetCVar and GetCVar("realmList") or "").."|"..UnBotRegistryCurrentContext().."|"..state;
 UnBotRegistryRefresh.reminders=UnBotRegistryRefresh.reminders or {};
 local previous=UnBotRegistryRefresh.reminders[key];
 if previous and time()-previous<600 then return;end
 UnBotRegistryRefresh.reminders[key]=time();
 UnBotSpecSummonMessage(text);
 if RaidNotice_AddMessage and RaidWarningFrame then
  RaidNotice_AddMessage(RaidWarningFrame,state=="initial" and "Инициализируйте реестр ботов перед сбором состава" or "Обновите реестр ботов: прошло больше 7 дней",{r=1,g=.72,b=.15});
 end
end

function UnBotRegistryRefresh.UpdateReminderButton(button,elapsed)
 button.reminderElapsed=(button.reminderElapsed or 0)+(elapsed or 0);
 if button.reminderElapsed<.05 then return;end
 button.reminderElapsed=0;
 local now=GetTime();
 if not button.reminderCheckAt or now>=button.reminderCheckAt then
  button.reminderCheckedState=UnBotRegistryRefresh.ReminderState();button.reminderCheckAt=now+1;
 end
 local state=button.reminderCheckedState;
 local needed=state=="initial" or state=="stale";
 if button.reminderState~=state then
  button.reminderState=state;
  button:SetText(state=="initial" and "Инициализация реестра" or state=="running" and "Обновление идёт..." or "Обновить реестр ботов");
  local font=button:GetFontString();
  if font then font:SetTextColor(1,needed and .78 or 1,needed and .2 or 1);end
  if needed then button:LockHighlight();else button:UnlockHighlight();end
 end
 if button.reminderGlow then
  if needed then button.reminderGlow:Show();button.reminderGlow:SetAlpha(.2+.3*(1+math.sin(GetTime()*3)));
  else button.reminderGlow:Hide();end
 end
end

function UnBotRegistryRefresh.Valid(name, profile)
	return type(name) == "string" and name ~= "" and name ~= UnitName("player")
		and name ~= UNKNOWN and name ~= UNKNOWNOBJECT and type(profile) == "table"
		and not UnBotIsAccountAltProfile(name, profile);
end

function UnBotRegistryRefresh.CheckedAt(profile)
	if (not profile or not profile.className or not profile.specName) then return 0; end
	local checked = tonumber(profile.specCheckedAt) or 0;
	local snapshot = profile.talentSnapshot;
	if (snapshot and snapshot.source == "server-inspect" and not profile.talentSnapshotStale and snapshot.context == UnBotRegistryCurrentContext()
		and snapshot.className == profile.className and snapshot.level == tonumber(profile.level)) then
		checked = math.max(checked, tonumber(snapshot.checkedAt) or 0);
	end
	return checked; -- lastSeen also advances for a mere join; it is not a spec check.
end

function UnBotRegistryRefresh.Build(onlyUndated)
	local queue = {};
	for name, profile in pairs(UnBotBotRegistry.bots or {}) do
		if (UnBotRegistryRefresh.Valid(name, profile) and (not onlyUndated or UnBotRegistryRefresh.CheckedAt(profile)<=0)) then
			queue[#queue + 1] = {name=name, className=profile.className, checkedAt=UnBotRegistryRefresh.CheckedAt(profile)};
		end
	end
	table.sort(queue, function(a,b)
		if (a.checkedAt ~= b.checkedAt) then return a.checkedAt < b.checkedAt; end
		return a.name < b.name;
	end);
	return queue;
end

function UnBotRegistryRefresh.Running()
	return UnBotDKSpecBalance and UnBotDKSpecBalance.active and UnBotDKSpecBalance.registryRefreshJob ~= nil;
end

function UnBotRegistryRefresh.Pending(job)
	job = job or UnBotRegistryRefresh.Job();
	return job and job.status ~= "complete" and ((tonumber(job.cursor) or 1) <= #job.queue or job.current ~= nil or job.batch ~= nil);
end

function UnBotRegistryRefresh.Message(text)
	UnBotPVPSquad.transport.Message("Обновление реестра: "..text);
end

function UnBotRegistryRefresh.Touch(job)
	job.updatedAt = time();
	job.cursor = tonumber(job.cursor) or 1;
	while (job.queue[job.cursor] and job.results[job.queue[job.cursor].name]) do job.cursor = job.cursor + 1; end
	if (UnBotSpecAuditRefresh) then UnBotSpecAuditRefresh(true); end
end

function UnBotRegistryRefresh.Record(state, status, reason)
	local job, name = state.registryRefreshJob, state.currentName;
	if (not job or not name or job.results[name]) then return; end
	job.results[name] = {status=status, reason=reason, at=time()};
	job.processed = (job.processed or 0) + 1;
	job[status] = (job[status] or 0) + 1;
	if (status == "verified") then
		local profile = UnBotBotRegistry.bots[name];
		profile.registryCheckedAt, profile.registryCheckedContext = time(), UnBotRegistryCurrentContext();
		job.consecutiveFailures = 0;
	elseif (status == "partial" or status == "failed") then
		job.consecutiveFailures = (job.consecutiveFailures or 0) + 1;
		if (job.consecutiveFailures >= 3) then
			state.stopRequested = true;
			job.pauseReason = "три бота подряд не подтвердили данные; проверьте соединение и продолжите";
			UnBotRegistryRefresh.Message(job.pauseReason);
		end
	end
	UnBotRegistryRefresh.Touch(job);
end

function UnBotRegistryRefresh.BeforeAdd(state)
	local job, name = state.registryRefreshJob, state.currentName;
	local profile = UnBotBotRegistry.bots[name];
	local task = state.currentTask;
	local reason, status;
	if (not UnBotRegistryRefresh.Valid(name, profile) or UnBotSquadRosterIsOfflineReserve(name)) then
		status, reason = "skipped", "имя удалено из реестра или участник защищён";
	elseif (UnBotPVPSquad.transport.ActiveFlag(profile)) then
		status, reason = "skipped", "действует флаг недоступности";
	elseif (profile.talentSnapshot and profile.talentSnapshot.source == "server-inspect" and not profile.talentSnapshotStale
		and profile.talentSnapshot.context == UnBotRegistryCurrentContext()
		and profile.talentSnapshot.className == profile.className
		and profile.talentSnapshot.level == tonumber(profile.level)
		and (tonumber(profile.talentSnapshot.checkedAt) or 0) >= job.startedAt
		and (tonumber(profile.talentSnapshot.checkedAt) or 0) > (tonumber(task.checkedAt) or 0)) then
		status, reason = "fresh", "уже проверен после начала этого прохода";
	end
	if (status) then
		UnBotRegistryRefresh.Record(state,status,reason);
		state.currentName, state.currentTask = nil, nil;
		state.stage, state.nextTime = "next_bot", GetTime() + .2;
		return false;
	end
	UnBotPVPSquad.transport.PVEOwner.CancelStaleCleanup(name);
	profile.registryLastAttemptAt = time();
	job.current = {name=name, index=task.refreshIndex, owned=false};
	job.updatedAt = time();
	return true;
end

function UnBotRegistryRefresh.Observe(state)
	local job = state.registryRefreshJob;
	if (not job or not job.current or job.current.name ~= state.currentName) then return; end
	if (state.currentOwned) then job.current.owned = true; end
	local unit = UnBotSquadRosterFindUnit(state.currentName);
	if (unit and UnitIsConnected(unit) and UnitGUID(unit)) then
		job.current.guid = UnitGUID(unit);
	end
end

function UnBotRegistryRefresh.Cleaned(state)
	local job = state.registryRefreshJob;
	if (job and job.current and job.current.name == state.currentName) then
		job.current = nil;
		UnBotRegistryRefresh.Touch(job);
	end
end

function UnBotRegistryRefresh.Finished(state, complete, reason)
	local job = state.registryRefreshJob;
	if (not job) then return; end
	UnBotRegistryRefresh.Observe(state);
	job.status = not job.current and job.cursor > #job.queue and "complete" or "paused";
	job.pauseReason = job.status == "paused" and (job.pauseReason or reason or "проход прерван") or nil;
	job.finishedAt = job.status == "complete" and time() or nil;
	UnBotRegistryRefresh.Touch(job);
	if (job.status == "complete") then
		UnBotBotRegistry.meta.lastRegistryRefreshAt = time();
		UnBotBotRegistry.meta.lastRegistryRefreshTotal = #job.queue;
		UnBotRegistryRefresh.MarkInitialized(job);
	end
	state.registryRefreshJob = nil;
	UnBotRegistryRefresh.Message(UnBotRegistryRefresh.Status(job).." Для записи на диск выполните /reload.");
end

function UnBotRegistryRefresh.Suspend(state, reason)
	local job = state.registryRefreshJob;
	if (not job) then return; end
	UnBotRegistryRefresh.Observe(state);
	job.status, job.pauseReason = "paused", reason;
	UnBotTalentInfo.Cancel(state);
	state.active, state.stage, state.registryRefreshJob = false, "idle", nil;
	UnBotRegistryRefresh.Touch(job);
	UnBotRegistryRefresh.Message(reason..". Очередь сохранена; продолжение — кнопкой обновления.");
end

function UnBotRegistryRefresh.Guard(state)
	local job = state.registryRefreshJob;
	if (not job) then return true; end
	if (job.key ~= UnBotRegistryRefresh.Key() or not UnitIsConnected("player")) then
		UnBotRegistryRefresh.Suspend(state,"соединение или персонаж изменились");
		return false;
	end
	for name in pairs(UnBotPVPSquad.transport.Roster()) do
		if (name ~= UnitName("player") and name ~= state.currentName) then
			UnBotRegistryRefresh.Suspend(state,"в группу вошёл другой участник; освободите группу перед продолжением");
			return false;
		end
	end
	UnBotRegistryRefresh.Observe(state);
	if ((UnitAffectingCombat("player") or InCombatLockdown()) and not state.stopRequested) then
		job.pauseReason = "проход приостановлен боем";
		UnBotSpecAuditStop();
		return false;
	end
	return true;
end

function UnBotRegistryRefresh.RecoveryAllowed(job)
	local current = job and job.current;
	if (not current or not current.owned or not current.guid
		or not UnBotRegistryRefresh.Valid(current.name, UnBotBotRegistry.bots[current.name])
		or UnBotSquadRosterIsOfflineReserve(current.name)) then return false; end
	local unit = UnBotSquadRosterFindUnit(current.name);
	if (not unit or not UnitIsConnected(unit) or UnitGUID(unit) ~= current.guid) then return false; end
	for name in pairs(UnBotPVPSquad.transport.Roster()) do
		if (name ~= UnitName("player") and name ~= current.name) then return false; end
	end
	return true;
end

function UnBotRegistryRefresh.Recover(state, job)
	if (not UnBotRegistryRefresh.RecoveryAllowed(job)) then
		-- The audit already verified an empty roster before this call.
		job.current = nil;
		return false;
	end
	state.currentName, state.currentOwned = job.current.name, true;
	state.currentTask = {name=job.current.name, action="audit"};
	UnBotPVPSquad.transport.PVEOwner.CancelStaleCleanup(state.currentName);
	UnBotRegistryRefresh.Message("освобождаю временного бота прошлого прохода: "..state.currentName);
	UnBotDKSpecBalanceBeginCleanup();
	return true;
end

function UnBotRegistryRefresh.Start(reset)
	if (UnBotRegistryRefresh.Running()) then UnBotRegistryRefresh.Stop(); return; end
	if (not UnitIsConnected("player") or UnitAffectingCombat("player") or InCombatLockdown()) then
		UnBotRegistryRefresh.Message("запуск доступен при соединении с сервером и вне боя"); return;
	end
	if (UnBotDKSpecBalance.active or UnBotDKSpecBalanceOtherAutomationActive()) then
		UnBotRegistryRefresh.Message("сначала завершите текущую операцию"); return;
	end
	UnBotPVPSquad.transport.Attach();
	local job = UnBotRegistryRefresh.Job();
	-- Never discard the proof needed to release a retained temporary bot.
	if (reset and job and job.current) then
		UnBotRegistryRefresh.Message("сначала продолжите незавершённую очистку прошлого прохода"); return;
	end
	if (reset or not UnBotRegistryRefresh.Pending(job)) then
		local queue = UnBotRegistryRefresh.Build();
		if (#queue == 0) then UnBotRegistryRefresh.Message("реестр пуст; нажмите «Найти новых ботов»"); return; end
		job = job or {};
		job.schema, job.key, job.startedAt, job.updatedAt = 1, UnBotRegistryRefresh.Key(), time(), time();
		job.queue, job.results, job.cursor, job.processed, job.status = queue, {}, 1, 0, "paused";
		job.verified, job.partial, job.failed, job.fresh, job.skipped = 0, 0, 0, 0, 0;
		job.current, job.finishedAt = nil, nil;
		UnBotSquadConfig.registryRefreshJobs = UnBotSquadConfig.registryRefreshJobs or {};
		UnBotSquadConfig.registryRefreshJobs[job.key] = job;
	end
	local queue = {};
	for index, task in ipairs(job.queue) do
		if (not job.results[task.name]) then
			queue[#queue+1] = {name=task.name, className=task.className, action="audit", checkedAt=task.checkedAt, refreshIndex=index};
		end
	end
	job.pauseReason, job.consecutiveFailures = nil, 0;
	if (UnBotSpecAuditStart(nil,false,8,nil,nil,job,queue)) then
		if (not UnBotRegistryRefresh.Running()) then return; end
		job.status = "running";
		UnBotRegistryRefresh.Message("сначала давно не проверенные; продолжение "..tostring(job.processed or 0)
			.."/"..#job.queue..", осталось "..#queue..". who и полные таланты, один бот за раз.");
	end
end

function UnBotRegistryRefresh.Stop()
	local state = UnBotDKSpecBalance;
	if (not UnBotRegistryRefresh.Running() or state.stopRequested) then return; end
	state.registryRefreshJob.pauseReason = "остановлено пользователем";
	UnBotSpecAuditStop();
end

function UnBotRegistryRefresh.Status(job)
	job = job or UnBotRegistryRefresh.Job();
	if (not job) then return "Сначала проверяются боты с самыми старыми данными."; end
	return (UnBotRegistryRefresh.Running() and "Обновляю" or job.status == "complete" and "Завершено" or "Приостановлено")
		.." "..tostring(job.processed or 0).."/"..#job.queue.."; осталось: "..tostring(#job.queue-(job.processed or 0)).."; полные: "..tostring(job.verified or 0)
		..", неполные: "..tostring(job.partial or 0)..", недоступно: "..tostring(job.failed or 0)
		..(UnBotRegistryRefresh.Running() and (". Сейчас: "..tostring(UnBotDKSpecBalance.currentName or "очистка")) or "");
end

function UnBotRegistryRefresh.ButtonText()
	if (UnBotRegistryRefresh.Running()) then return "Остановить обновление"; end
	return UnBotRegistryRefresh.Pending() and "Продолжить обновление" or "Обновить список ботов";
end

UnBotRegistryRefresh.frame = CreateFrame("Frame");
UnBotRegistryRefresh.frame:RegisterEvent("PLAYER_LOGIN");
UnBotRegistryRefresh.frame:RegisterEvent("PLAYER_LOGOUT");
UnBotRegistryRefresh.frame:RegisterEvent("PLAYER_LEAVING_WORLD");
UnBotRegistryRefresh.frame:SetScript("OnEvent", function(self,event)
	if (event == "PLAYER_LOGIN") then
		local job = UnBotRegistryRefresh.Job();
		if (job and job.status == "running") then job.status, job.pauseReason = "paused", "вход после прерванного прохода"; end
	elseif (UnBotRegistryRefresh.Running()) then
		UnBotRegistryRefresh.Suspend(UnBotDKSpecBalance,"выход из мира; обновление приостановлено");
	end
end);

SLASH_UNBOTREGISTRYREFRESH1 = "/ubrefresh";
SlashCmdList.UNBOTREGISTRYREFRESH = function(text)
	text = tostring(text or ""):lower():match("^%s*(%S*)") or "";
	if (text == "stop") then UnBotRegistryRefresh.Stop();
	elseif (text == "status") then UnBotRegistryRefresh.Message(UnBotRegistryRefresh.Status());
	elseif (text == "new") then UnBotRegistryRefresh.Start(true);
	else UnBotRegistryRefresh.Start(); end
end;
