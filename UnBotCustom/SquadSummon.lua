-- Shared UI entry point; the PvE and PvP controllers keep separate state.
UnBotSquadSummon = UnBotSquadSummon or {};

function UnBotSquadSummon.Message(text)
	UnBotPVPSquad.Message("Призыв состава: "..text);
end

function UnBotSquadSummon.Signature()
	local parts = {};
	for _, slot in ipairs(UnBotSquadConfig.slots or {}) do
		-- A named alt is selected by identity. Class/spec are roster hints
		-- refreshed after joining, rather than criteria for choosing a bot.
		local identity = slot.accountAltName and slot.accountAltName ~= "" and ("alt:"..slot.accountAltName)
			or ("bot:"..tostring(slot.className)..":"..tostring(slot.specKey));
		table.insert(parts, identity..":"..tostring(tonumber(slot.count) or 1)..":"..tostring(slot.reserveOnly and true or false));
	end
	-- Loading the current roster can reorder equivalent PvE rows.
	-- Compare their contents while retaining the PvP queue's own order.
	table.sort(parts);
	table.insert(parts, 1, UnBotPVPSummon.Signature());
	return table.concat(parts,"|");
end

function UnBotSquadSummon.Cancel(reason, skipPVEStop)
	if UnBotTwinEmperors and UnBotTwinEmperors.formation
		and (UnBotTwinEmperors.formation.active or UnBotTwinEmperors.formation.pendingAuto or UnBotTwinEmperors.formation.resume) then
		UnBotTwinEmperors.tanks:Stop(reason or "призыв и расстановка отменены игроком");
	end
	if (UnBotGunshipMasterLoot and UnBotGunshipMasterLoot.paused) then
		UnBotGunshipMasterLoot.RestoreSummon();
		if (not skipPVEStop and UnBotSquadBuilder.pveStopClick) then UnBotSquadBuilder.pveStopClick(reason); end
	end
	local s, wasActive = UnBotSquadSummon, UnBotSquadSummon.active;
	UnBotSquadSummon.pendingBinding = nil;
	if (UnBotSummonLog and (wasActive or UnBotSquadBuilder.postSummonSequence
		or (UnBotPVPSquad.transport.PVEOwner and UnBotPVPSquad.transport.PVEOwner.active))) then
		UnBotSummonLog.Safe("Result","squad","stopped",reason);
	end
	s.active, s.phase, s.pveComplete, s.lootPending = false, nil, nil, nil;
	UnBotPVPSummon.Stop(reason or "отменено игроком");
	if (wasActive) then UnBotSquadSummon.Message(reason or "отменено игроком"); end
	UnBotPVPSquad.Refresh();
end

function UnBotSquadSummon.Stop(reason)
	reason = type(reason)=="string" and reason or "остановлено игроком";
	UnBotSquadSummon.Cancel(reason, true);
	if (UnBotSquadBuilder.pveStopClick) then UnBotSquadBuilder.pveStopClick(reason); end
end

function UnBotSquadSummon.StopReason()
	local s = UnBotSquadSummon;
	if (s.context ~= UnBotRegistryCurrentContext()) then return "остановлено: сменился сервер или фракция"; end
	if (s.signature ~= UnBotSquadSummon.Signature()) then return "остановлено: изменён выбранный состав"; end
	if (UnitAffectingCombat("player") or InCombatLockdown()) then return "остановлено: начался бой"; end
	if (GetTime() >= s.deadline) then return "остановлено: истёк общий таймаут призыва"; end
end

function UnBotSquadSummon.ReservePlaces()
	-- Existing offline members still physically occupy slots; no additional reserve is planned.
	return #UnBotSquadRosterReserveNames();
end

function UnBotSquadSummon.Start(bindingChecked)
	UnBotPVPSquad.CommitCountEdits();
	if (UnBotFullTalentCatalog and UnBotFullTalentCatalog.IsBusy()) then
		UnBotSquadSummon.Message("сначала завершите сбор полного каталога талантов"); return false;
	end
	if (UnBotTwinEmperors and UnBotTwinEmperors.tanks
		and (UnBotTwinEmperors.tanks.armed or UnBotTwinEmperors.tanks.stage or UnBotTwinEmperors.tanks.restoring)) then
		UnBotSquadSummon.Message("сначала остановите разведение близнецов и восстановите настройки танков"); return false;
	end
	if (UnBotSpiritRescue and UnBotSpiritRescue.active) then
		UnBotSquadSummon.Message("сначала завершите освобождение духа и возврат ботов"); return false;
	end
	if (UnBotGunshipMasterLoot and UnBotGunshipMasterLoot.paused) then
		return UnBotGunshipMasterLoot.ResumeSummon();
	end
	local s, t = UnBotSquadSummon, UnBotPVPSquad.transport;
	if (s.active or UnBotPVPSummon.active) then
		UnBotSquadSummon.Message("призыв уже идёт; для отмены нажмите «Стоп»"); return false;
	end
	if UnBotAccountAlts and UnBotAccountAlts.RefreshForSummon then
		if UnBotAccountAlts.equipUpgrades and UnBotAccountAlts.equipUpgrades.active then
			UnBotSquadSummon.Message("сначала завершите экипировку альтов"); return false;
		end
		if not bindingChecked then UnBotAccountAlts.RefreshForSummon(); end
		if UnBotAccountAlts.summonRefresh or UnBotAccountAlts.discoveryActive or (UnBotLinkedAccounts and UnBotLinkedAccounts.job) then
			if not s.pendingBinding then
				s.pendingBinding={signature=UnBotSquadSummon.Signature(),context=UnBotAccountAlts.SummonContext(),deadline=GetTime()+22};
				UnBotSquadSummon.Message("дожидаюсь проверки привязок альтов; после ответа начну выбранный призыв");
			end
			return true;
		end
		local ready, reason = UnBotAccountAlts.SummonSelectionReady();
		if not ready then UnBotSquadSummon.Message(reason); return false; end
	end
	local pve, pvp = t.PVECount(), UnBotPVPSquad.Total(UnBotPVPSquad.State());
	-- The original PvE-only entry point runs verbatim, including boss presets.
	if (pvp == 0) then return UnBotSquadBuilder.pveStartClick(); end
	if (t.Busy() or next(UnBotPVPSummon.cleanup)) then
		UnBotSquadSummon.Message("сначала завершите предыдущую операцию UnBot"); return false;
	end
	if (UnitAffectingCombat("player") or InCombatLockdown()) then
		UnBotSquadSummon.Message("запуск доступен вне боя"); return false;
	end
	if (pve > 0) then
		local total, limit = pve + pvp + UnBotSquadSummon.ReservePlaces() + 1, UnBotPVPSummon.MemberLimit();
		if (total > limit) then
			UnBotSquadSummon.Message("выбрано участников с игроком и существующими офлайн-участниками "..total..", доступно мест "..limit); return false;
		end
	end
	s.active, s.pveComplete, s.idleAt, s.nextTick = true, false, nil, 0;
	s.talentsChanged=false; s.lootPending=nil;
	s.context, s.signature = UnBotRegistryCurrentContext(), UnBotSquadSummon.Signature();
	s.deadline = GetTime() + math.max(300,(pve + pvp) * 180);
	if (pve == 0) then
		if (UnBotSummonLog) then UnBotSummonLog.Safe("Begin","","pvp_only"); end
		if (t.Settling()) then
			s.phase, s.pveComplete = "wait", true;
			UnBotSquadSummon.Message("дожидаюсь завершения очистки предыдущего цикла, затем вызываю PVP");
		else
			s.phase = "pvp";
			if (not UnBotPVPSummon.Start()) then s.active = false; return false; end
		end
	else
		s.phase = "pve";
		UnBotSquadSummon.Message("выбрано PVE "..pve..", PVP "..pvp..". Сначала сбор PVE, затем подготовка PVP");
		UnBotSquadBuilder.pveStartClick();
		if (not s.pveComplete and not UnBotSquadBuilder.postSummonSequence and not t.Busy()) then
			UnBotSquadSummon.Cancel("PVE-призыв не запущен; очередь PVP отменена"); return false;
		end
	end
	UnBotPVPSquad.Refresh();
	return true;
end

function UnBotSquadSummon.Update()
	local s, now, t = UnBotSquadSummon, GetTime(), UnBotPVPSquad.transport;
	if s.pendingBinding then
		local pending = s.pendingBinding;
		if pending.context ~= UnBotAccountAlts.SummonContext() or pending.signature ~= UnBotSquadSummon.Signature()
			or now >= pending.deadline or UnitAffectingCombat("player") or InCombatLockdown() then
			s.pendingBinding=nil; UnBotSquadSummon.Message("ожидание привязок отменено: бой, смена состава/персонажа или таймаут"); return;
		end
		if not UnBotAccountAlts.summonRefresh and not UnBotAccountAlts.discoveryActive and not (UnBotLinkedAccounts and UnBotLinkedAccounts.job) then
			s.pendingBinding=nil; UnBotSquadSummon.Start(true);
		end
		return;
	end
	if (not s.active or now < (s.nextTick or 0)) then return; end
	s.nextTick = now + 0.2;
	local reason = UnBotSquadSummon.StopReason();
	if (reason) then UnBotSquadSummon.Stop(reason); return; end
	if (s.phase == "pvp") then
		if (not UnBotPVPSummon.active) then
			s.active = false; UnBotPVPSquad.Refresh();
			if (s.lootPending and UnBotSquadLoot) then s.lootPending=nil; UnBotSquadLoot.Auto(); end
		end
		return;
	end
	if (t.Busy() or t.Settling()) then s.idleAt = nil; return; end
	if (not s.idleAt) then s.idleAt = now + 2; return; end
	if (now < s.idleAt) then return; end
	if (not s.pveComplete) then
		UnBotSquadSummon.Cancel("PVE-проход остановился без завершения; автоматический PVP не запущен"); return;
	end
	s.phase = "pvp";
	UnBotSquadSummon.Message("PVE-проход завершён; начинаю выбранные PVP-позиции");
	if (not UnBotPVPSummon.Start()) then UnBotSquadSummon.Cancel("не удалось запустить PVP-проход"); end
end

-- Observe completion after the original continuation finishes arrival/buffs.
-- Keep its body and all PvE callbacks unchanged.
UnBotSquadSummon.pveContinue = UnBotSquadPostSummonContinue;
UnBotSquadPostSummonContinue = function(...)
	local result = UnBotSquadSummon.pveContinue(...);
	if (UnBotSquadSummon.active and UnBotSquadSummon.phase == "pve" and not UnBotSquadBuilder.postSummonSequence) then
		UnBotSquadSummon.pveComplete = true;
	end
	return result;
end;

UnBotSquadSummon.frame = CreateFrame("Frame", "UnBotSquadSummonController");
UnBotSquadSummon.frame:SetScript("OnUpdate", UnBotSquadSummon.Update);


-- BEGIN NAMED BATCH TRANSPORT
do
-- Named add batches and one group who. No persistent evidence is inferred from saved hints.
UnBotBatchSummon = {};
local B = UnBotBatchSummon;
local t = UnBotPVPSquad.transport;
local owner = t.PVEOwner;
local api = owner.BatchAPI;
local R = UnBotRegistryRefresh;

function B.Message(text) t.Message("Пакетный призыв: "..text); end
function B.Live(name)
 local unit=UnBotSquadRosterFindUnit(name);
 if unit and UnitIsConnected(unit) and not UnBotSquadRosterIsOfflineReserve(name,unit)
  and UnitName(unit)==name and UnitGUID(unit) then return unit; end
end
function B.Name(sender,entries)
 local base=tostring(sender or ""):gsub("%-.*$","");
 for name in pairs(entries or {}) do if name:lower()==base:lower() then return name; end end
end
function B.Pack(names,prefix)
 local out,line={},prefix;
 for _,name in ipairs(names) do
  if type(name)=="string" and name~="" and not name:find("[%s,;]") then
   local part=(line==prefix and "" or ",")..name;
   if #line+#part>240 then if line~=prefix then out[#out+1]=line;end;line=prefix;part=name;end
   if #prefix+#name<=240 then line=line..part;end
  end
 end
 if line~=prefix then out[#out+1]=line;end
 return out;
end
function B.Broadcast()
 SendChatMessage("who",(GetNumRaidMembers() or 0)>0 and "RAID" or "PARTY");
end
function B.Failure(text,name)
 text=tostring(text or ""):lower();local n=name:lower();
 local named=text:find("'"..n.."'",1,true) or text:find('"'..n..'"',1,true)
  or text:find("add: "..n.." -",1,true);
 if not named then return;end
 if text:find("already logged in",1,true) or text:find("already in group",1,true)
  or text:find("not found",1,true) or text:find("не найден",1,true)
  or text:find("not allowed",1,true) or text:find("too many bots",1,true) then return text;end
end
function B.Store(name,info,raw)
 local a,b=api.Store(name,info,raw);
 local p=UnBotBotRegistry.bots[name];
 if p and UnBotTalentInfo and UnBotTalentInfo.ObserveWho then UnBotTalentInfo.ObserveWho(p,info);end
 if owner.confirmedRoster then owner.confirmedRoster.Who(name,info);end
 return a,b;
end

-- The original resolver still decides class/spec, Bear/Cat, PvE/PvP and personal alt settings.
function B.CanPrefetch()
 return owner.active and owner.mode=="squad" and owner.squad;
end
function B.PrefetchSend()
 local s,q,now=owner,owner.squad,GetTime();
 if UnitAffectingCombat("player") or InCombatLockdown() then s.stageTime=now+1;return true;end
 if not q.batch then
  q.batch={entries={},context=UnBotRegistryCurrentContext()};
  B.Message("призыв по именам; затем общий who.");
 end
 local batch=q.batch;
 if batch.context~=UnBotRegistryCurrentContext() then s.PVETransport.Stop("Пакетный призыв остановлен: изменился контекст.");return true;end
 if batch.done then return false;end
 local loot=UnBotGunshipMasterLoot;
 if loot and loot.summonGuard then
  local joined,pending=false,false;
  for name,e in pairs(batch.entries) do
   if B.Live(name) then joined=true;
   elseif not e.batchFailure and now-e.sentAt<6 then pending=true;
   elseif not e.batchFailure then e.batchFailure="не вошёл после пакетного add";end
  end
  if (joined and not loot.CheckSummon(true)) or (not joined and pending) then s.stageTime=now+.1;return true;end
  if not loot.CheckSummon() then s.stageTime=now+.1;return true;end
 end
 if not batch.joinUntil then
  local occupied=math.max(1+(GetNumPartyMembers() or 0),GetNumRaidMembers() or 0);
  for name in pairs(q.prefetchPending) do if not UnBotSquadRosterFindUnit(name) then occupied=occupied+1;end end
  local names,entries={},{};
  local index=q.prefetchIndex;
  local batchLimit=(loot and loot.summonGuard and not loot.settled) and 3 or 39;
  while q.prefetch[index] and #names<batchLimit do
   local e=q.prefetch[index];
   if e.slot.skipped then index=index+1;
   elseif occupied>=40 then break
   else
    local trial={};for _,n in ipairs(names) do trial[#trial+1]=n;end;trial[#trial+1]=e.name;
    if #B.Pack(trial,".playerbot bot add ")>1 then break end
    names[#names+1]=e.name;entries[#entries+1]=e;occupied=occupied+1;index=index+1;
   end
  end
  q.prefetchIndex=index;
  if #names>0 then
   for _,e in ipairs(entries) do
    e.sentAt,e.batch=now,true;batch.entries[e.name]=e;
    s.CancelStaleCleanup(e.name);q.prefetchPending[e.name]=true;s.checked[e.name]=true;
    s.registryRequests[e.name]=now+120;
    if UnBotGunshipMasterLoot and UnBotGunshipMasterLoot.RecordAttempt then UnBotGunshipMasterLoot.RecordAttempt(e.name);end
   end
   for _,command in ipairs(B.Pack(names,".playerbot bot add ")) do SendChatMessage(command,"SAY");end
   batch.lastSent=now;s.stageTime=now+.25;
  end
  if q.prefetch[index] and occupied<40 then return true;end
  batch.joinUntil=now+6;
 end
 local joined,expected=0,0;
 for name,e in pairs(batch.entries) do
  if not e.batchFailure then expected=expected+1;if B.Live(name) then joined=joined+1;end end
 end
 if not batch.whoAt then
  if joined<expected and now<batch.joinUntil then s.stageTime=now+.1;return true;end
  batch.whoAt,batch.whoUntil=now,now+3;
  local any=false;
  for name,e in pairs(batch.entries) do
   local unit=B.Live(name);
   if unit and not e.batchFailure then e.batchGUID=UnitGUID(unit);any=true;
   elseif not e.batchFailure then e.batchFailure="не вошёл после пакетного add";end
  end
  if any then B.Broadcast();else batch.done=true;return false;end
 end
 local pending=false;
 for _,e in pairs(batch.entries) do if e.batchGUID and not e.batchWho and not e.batchFailure then pending=true;end end
 if pending and now<batch.whoUntil then s.stageTime=now+.1;return true;end
 batch.done=true;s.stageTime=now;
 return false;
end
function B.PrefetchReply(event,text,sender)
 local q=owner.active and owner.mode=="squad" and owner.squad;
 local batch=q and q.batch;
 if not batch or B.delivering then return false;end
 if event=="CHAT_MSG_SYSTEM" then
  for name,e in pairs(batch.entries) do
   if not B.Live(name) and B.Failure(text,name) then e.batchFailure=text;end
  end
  return false;
 end
 if event~="CHAT_MSG_WHISPER" or not batch.whoAt then return false;end
 local name=B.Name(sender,batch.entries);local e=name and batch.entries[name];
 local unit=name and B.Live(name);
 if not e or e.batchWho or e.batchFailure or not unit or UnitGUID(unit)~=e.batchGUID then return false;end
 local info=api.Parse(text);
 if not info or not info.className or not info.specName then return false;end
 e.batchWho={raw=text,at=GetTime(),guid=UnitGUID(unit)};
 -- The group reply can arrive after the resolver started a personal who.
 -- Deliver it now through the same guarded path as an early cached reply.
 if owner.registryMode and owner.stage=="wait_registry_who" and owner.requestedName==name then
  B.DeliverCached(name);
 end
 return true;
end
function B.DeliverCached(name)
 local q=owner.mode=="squad" and owner.squad;
 local e=q and q.batch and q.batch.entries[name];local proof=e and e.batchWho;local unit=B.Live(name);
 if not proof or e.delivered or not unit or q.batch.context~=UnBotRegistryCurrentContext()
  or proof.guid~=UnitGUID(unit) or GetTime()-proof.at>30 then return false;end
 e.delivered=true;owner.stage="wait_registry_who";owner.stageTime=GetTime()+3;owner.whoAttempts=1;
 B.delivering=true;owner.DeliverPresetWho(name,proof.raw);B.delivering=nil;
 return true;
end
function B.Refill()
 local q=owner.mode=="squad" and owner.squad;
 if not q or not q.prefetch or q.prefetchRead<=#q.prefetch or not B.CanPrefetch() then return false;end
 for _,slot in ipairs(q.slots) do
  if not slot.accountAltName and not slot.skipped and not slot.pveExhausted and slot.have<slot.need then
   -- Use the same class-wide, exact-first selection as PrefetchStart.
   -- Fast preset donors retain their existing separate verification policy.
   local candidates=api.Candidates(slot.className,slot.specAliases,owner.checked,true);
   if api.Fast then candidates=api.Fast.Candidates(candidates,slot,true);end
   for _,name in ipairs(candidates) do
    if not (api.Fast and api.Fast.Excluded(name)) and not UnBotBuffCycleArrivalBlock(name) then
     owner.PrefetchStart();return true;
    end
   end
  end
 end
 return false;
end

-- Existing/manual spec checks share the same out-of-order group reply collector.
function B.BeginCheck()
 local c=api.Check;
 c.batch={pending={},context=UnBotRegistryCurrentContext(),deadline=GetTime()+3};
 for _,name in ipairs(c.queue) do
  local unit=B.Live(name);
  c.batch.pending[name]={guid=unit and UnitGUID(unit)};
  if owner.confirmedRoster then owner.confirmedRoster.Forget(name);end
 end
 B.Broadcast();B.Message("общий who: "..#c.queue.." ботов.");
end
function B.FinishCheck()
 local c=api.Check;local view=c.batchView;local results=c.results;
 c.batch,c.batchView=nil,nil;
 api.CheckFinish();
 if view then B.viewResults=results;api.Show(true);B.viewResults=nil;end
end
function B.CheckReply(event,text,sender)
 local c=api.Check;local batch=c.active and c.batch;
 if not batch then return false;end
 if event=="CHAT_MSG_SYSTEM" then
  for name in pairs(batch.pending) do
   if c.PlayerNotFound(text,name) then batch.pending[name]=nil;c.failed=c.failed+1;end
  end
  return true;
 end
 if event~="CHAT_MSG_WHISPER" then return true;end
 local name=B.Name(sender,batch.pending);local e=name and batch.pending[name];local unit=name and B.Live(name);
 if not e or not unit or not e.guid or UnitGUID(unit)~=e.guid or batch.context~=UnBotRegistryCurrentContext() then return true;end
 local info=api.Parse(text);if not info or not info.className or not info.specName then return true;end
 local oldClass,oldSpec=B.Store(name,info,text);
 c.results[name]={zoneName=info.zoneName,visible=UnitIsVisible and UnitIsVisible(unit) and true or false,
  near=CheckInteractDistance and CheckInteractDistance(unit,1) and true or false};
 c.updated=c.updated+1;if oldClass~=info.className or oldSpec~=info.specName then c.changed=c.changed+1;end
 batch.pending[name]=nil;
 return true;
end
function B.CheckTick()
 local c=api.Check;local batch=c.active and c.batch;
 if not batch then if not c.active then c.batch=nil;end;return false;end
 local now=GetTime();
 if batch.context~=UnBotRegistryCurrentContext() or not UnitIsConnected("player") then
  c.active,c.batch,c.batchView=false,nil,nil;B.Message("who остановлен: изменился контекст или соединение; состав сохранён.");return true;
 end
 if not next(batch.pending) then B.FinishCheck();return true;end
 if now<batch.deadline then return true;end
 if not batch.retried then
  batch.retried=true;batch.deadline=now+3;
  for name,e in pairs(batch.pending) do
   local unit=B.Live(name);
   if unit and UnitGUID(unit)==e.guid then SendChatMessage("who","WHISPER",nil,name);
   else batch.pending[name]=nil;c.failed=c.failed+1;end
  end
  return true;
 end
 for _ in pairs(batch.pending) do c.failed=c.failed+1;end
 batch.pending={};B.FinishCheck();return true;
end
function B.ShowCurrent()
 if owner.active or api.Check.active or (UnBotSquadSummon and UnBotSquadSummon.active)
  or (UnBotPVPSummon and UnBotPVPSummon.active) or UnBotSquadBuilder.postSummonSequence then
  B.Message("сначала завершите текущую операцию; состав не изменён.");return false;
 end
 if not api.SupportsSpecs() then return api.Show(true);end
 t.Attach();local names={};
 for name in pairs(t.Roster()) do
  if name~=UnitName("player") and UnBotBotRegistry.bots[name] and B.Live(name)
   and not UnBotIsAccountAltProfile(name,UnBotBotRegistry.bots[name]) then
   names[#names+1]=name;
  end
 end
 if #names==0 then return api.Show(true);end
 api.CheckStart({queue=names,mode="role_status"});
 if api.Check.active and api.Check.batch then api.Check.batchView=true;return true;end
 return false;
end

-- Refresh progress describes the entire queue, not just successful who replies.
function R.OutcomeCounts(job)
 job=job or R.Job();if not job then return;end
 local processed=math.min(#job.queue,math.max(0,tonumber(job.processed) or 0));
 local cache=R.progressCache;
 if cache and cache.job==job and cache.results==job.results and cache.processed==processed then return cache.counts;end
 local c={total=#job.queue,processed=processed,confirmed=(job.verified or 0)+(job.fresh or 0),
  skipped=job.skipped or 0,partial=job.partial or 0,busy=0,missing=0,noWho=0,notFound=0,refused=0,other=0};
 c.remaining=math.max(0,c.total-c.processed);c.unconfirmed=math.max(0,c.processed-c.confirmed);
 c.percent=c.total>0 and math.floor(c.processed*100/c.total) or 0;
 for _,result in pairs(job.results) do
  if result.status=="failed" then
   local reason=tostring(result.reason or ""):gsub("^Не ","не "):gsub("^Нет ","нет ");
   local english=reason:lower(); -- Lua 5.1 byte-wise lower can corrupt UTF-8 Russian.
   if english:find("already logged",1,true) or english:find("already in group",1,true) or reason:find("уже в игре",1,true) then c.busy=c.busy+1;
   elseif english:find("not found",1,true) or reason:find("не найден",1,true) then c.notFound=c.notFound+1;
   elseif reason:find("не вош",1,true) or reason:find("не приш",1,true) then c.missing=c.missing+1;
   elseif reason:find("нет ответа who",1,true) then c.noWho=c.noWho+1;
   elseif english:find("not allowed",1,true) or english:find("too many bots",1,true) then c.refused=c.refused+1;
   else c.other=c.other+1;end
  end
 end
 R.progressCache={job=job,results=job.results,processed=processed,counts=c};return c;
end
function R.ReasonText(job)
 local c=R.OutcomeCounts(job);if not c then return "";end
 local parts={};
 for _,entry in ipairs({{"не пришли",c.missing},{"заняты",c.busy},{"не ответили who",c.noWho},
  {"не найдены",c.notFound},{"отказ сервера",c.refused},{"пропущены",c.skipped},
  {"неполные данные",c.partial},{"прочие ошибки",c.other}}) do
  if entry[2]>0 then parts[#parts+1]=entry[1]..": "..entry[2];end
 end
 return #parts>0 and table.concat(parts,"; ") or "неподтверждённых нет";
end
function R.ProgressText(job)
 local c=R.OutcomeCounts(job);if not c then return "";end
 return "обработано "..c.processed.."/"..c.total.." ("..c.percent.."%); осталось "..c.remaining
  .."; подтверждено "..c.confirmed.."; не подтверждено "..c.unconfirmed;
end
function R.Duration(seconds)
 seconds=math.max(0,math.floor(seconds));
 if seconds<60 then return seconds.." с";end
 return math.floor(seconds/60).." мин "..(seconds%60).." с";
end
function R.Elapsed(job)
 job=job or R.Job();if not job then return 0;end
 if job.status=="complete" and tonumber(job.elapsedSeconds) then return math.max(0,job.elapsedSeconds);end
 local started=tonumber(job.startedAt);if not started then return 0;end
 return math.max(0,(tonumber(job.finishedAt) or time())-started);
end

-- Durable known-name refresh in waves of <=35; no init/respec/logout per participant.
B.refreshBatchLimit=35;
function R.BatchSize()
 local value=tonumber(UnBotSquadConfig.registryRefreshBatchSize);
 if not value or value~=value then value=30;end
 return math.max(1,math.min(B.refreshBatchLimit,math.floor(value)));
end
function R.SetBatchSize(value)
 local number=tonumber(value);
 if not number or number~=number then number=R.BatchSize();end
 UnBotSquadConfig.registryRefreshBatchSize=math.max(1,math.min(B.refreshBatchLimit,math.floor(number)));
 return UnBotSquadConfig.registryRefreshBatchSize;
end
function B.RefreshRecord(name,status,reason)
 local s=B.refresh;local job=s.job;local old=job.results[name];
 if old then
  if status~="verified" or old.status=="verified" or old.status=="skipped" then return;end
  job[old.status]=math.max(0,(job[old.status] or 0)-1);
 else job.processed=(job.processed or 0)+1;end
 job.results[name]={status=status,reason=reason,at=time(),kind="who"};
 job[status]=(job[status] or 0)+1;
 if status=="verified" then
  local p=UnBotBotRegistry.bots[name];p.registryCheckedAt=time();p.registryCheckedContext=UnBotRegistryCurrentContext();p.registryCheckKind="who";
 end
 R.Touch(job);
end
function B.RefreshPause(reason)
 local s=B.refresh;if not s then return;end
 local names={};for name,e in pairs(s.job.batch or {}) do
  if not s.job.results[name] or (s.phase=="cleanup" and e.owned and not e.retained and UnBotSquadRosterFindUnit(name)) then names[#names+1]=name;end
 end
 table.sort(names);if #names>0 then reason=reason..". Боты: "..table.concat(names,", ");end
 s.job.status,s.job.pauseReason="paused",reason;R.Touch(s.job);
 api.Balance.active,api.Balance.registryRefreshJob=false,nil;B.refresh=nil;
 local text="Остановлено: "..reason..". "..R.ProgressText(s.job)..". Очередь сохранена; продолжение вручную.";
 R.Message(text);
 -- A stop must also be visible in the currently selected chat window.
 local frame=SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME;
 if frame and frame.AddMessage then frame:AddMessage("|cffffaa00UnBot: "..text.."|r");end
end
function B.RefreshQueued(s,name)
 if not s.queued then s.queued={};for _,task in ipairs(s.job.queue) do s.queued[task.name]=true;end end
 return s.queued[name];
end
function B.RefreshRosterSafe(s)
 local job=s.job;job.batch=job.batch or {};job.retained=job.retained or {};job.pendingArrivals=job.pendingArrivals or {};
 local loading={};local known=0;
 for name in pairs(t.Roster()) do
  if name~=UnitName("player") then
   known=known+1;
   local unit=UnBotSquadRosterFindUnit(name);local p=UnBotBotRegistry.bots[name];
   local e=job.batch[name];local guid=unit and UnitGUID(unit);
   if not unit or UnitName(unit)~=name or not guid or name==UNKNOWN or name==UNKNOWNOBJECT then
    loading[#loading+1]=name;
   else
    if not e then
     e=job.pendingArrivals[name] or {sent=true,retained=true};job.batch[name]=e;job.pendingArrivals[name]=nil;
    end
    if not e.sent then e.sent=true;e.retained=true;end
    local alt=UnBotIsAccountAltProfile(name,p);
    local offline=not B.Live(name);
    local changed=e.guid and e.guid~=guid;
    if alt or offline or changed or (e.failure and not e.failure:find("не вошёл",1,true)) then e.retained=true;e.owned=nil;end
    e.guid=guid;
    if e.retained then
     local kind=alt and "альт; пропускаю" or offline and "офлайн/резерв; сохраняю" or changed and "сменился GUID; сохраняю участника" or "дополнительный участник; проверю who и сохраню в группе";
     if job.retained[name]~=guid..kind then job.retained[name]=guid..kind;R.Message(name..": "..kind.."; сбор продолжается.");end
    else e.owned=true;end
    if alt or offline then
     e.skip=true;
     if B.RefreshQueued(s,name) and not job.results[name] then B.RefreshRecord(name,"skipped",alt and "альт аккаунта" or "офлайн/резерв сохранён");end
    elseif job.onlyUndated and R.CheckedAt(p)>0 and not B.RefreshQueued(s,name) then
     e.skip=true;
    else
     if not B.RefreshQueued(s,name) then job.queue[#job.queue+1]={name=name,className=p and p.className,checkedAt=0};s.queued[name]=true;end
     e.skip=nil;
     if e.retained then e.failure=nil;end
     if e.failure and e.failure:find("не вошёл",1,true) then e.failure=nil;end
     if s.phase=="who" and not e.failure and not e.queried and (not job.results[name] or job.results[name].status=="failed") then
      e.queried=true;SendChatMessage("who","WHISPER",nil,name);s.whoUntil=math.max(s.whoUntil or 0,GetTime()+3);
     end
    end
   end
  end
 end
 local raw=(GetNumRaidMembers() or 0)>0 and math.max(0,GetNumRaidMembers()-1) or (GetNumPartyMembers() or 0);
 if raw>known then loading[#loading+1]="не загружены имена в "..(raw-known).." местах ростера";end
 if #loading>0 then
  s.rosterLoadingSince=s.rosterLoadingSince or GetTime();
  if not s.loadingNotice then R.Message("Жду загрузки состава: "..table.concat(loading,", ")..". До 30 секунд; сбор не отменён.");s.loadingNotice=true;end
  s.unknownRoster=true;
  if GetTime()-s.rosterLoadingSince<30 then return nil;end
  -- Unresolved slots remain protected; selective cleanup never touches them.
 else s.rosterLoadingSince,s.loadingNotice,s.unknownRoster=nil,nil,nil;end
 return true;
end
function B.RefreshCleanup()
 local s=B.refresh;local now=GetTime();
 if not B.RefreshRosterSafe(s) then return;end
 if s.phase~="cleanup" then
  s.phase,s.cleanupUntil,s.emptySince="cleanup",now+22,nil;
  local allOwned=not s.unknownRoster;
  for name in pairs(t.Roster()) do if name~=UnitName("player") then
   local e=s.job.batch[name];if not e or not e.owned or e.retained or not B.Live(name) then allOwned=false;end
  end end
  s.selective=not allOwned;s.leaveSent=true;
  if allOwned and not s.job.batchLeaveSent then
   s.job.batchLeaveSent=true;
   if (GetNumRaidMembers() or 0)>0 or (GetNumPartyMembers() or 0)>0 then LeaveParty();end
  end
  R.Message("пачка проверена; "..R.ProgressText(s.job)..(s.selective and ". Освобождаю временных ботов; остальных участников сохраняю" or ". Покидаю временную группу и проверяю выход"));
 end
 if s.phase=="cleanup" and not s.selective then
  if s.unknownRoster then s.selective=true;end
  for name in pairs(t.Roster()) do if name~=UnitName("player") then
   local e=s.job.batch[name];if not e or e.retained or not e.owned then s.selective=true;end
  end end
 end
 if s.selective and now>=(s.cleanupSendAt or 0) then
  for name,e in pairs(s.job.batch) do
   if e.owned and not e.retained and not e.leaveSent and B.Live(name) and UnitGUID(B.Live(name))==e.guid then
    e.leaveSent=true;s.cleanupSendAt=now+.2;SendChatMessage("leave","WHISPER",nil,name);break
   end
  end
 end
end

function B.RefreshWave()
 local s=B.refresh;local job=s.job;local names={};job.batch={};
 local limit=R.BatchSize();
 if s.batchLimit~=limit then
  s.batchLimit=limit;s.deadline=math.max(s.deadline or 0,GetTime()+math.max(120,math.ceil((#job.queue-(job.processed or 0))/limit)*75));
 end
 local raw=(GetNumRaidMembers() or 0)>0 and GetNumRaidMembers() or ((GetNumPartyMembers() or 0)+1);
 local free=math.max(0,40-raw);local count=0;
 for _,task in ipairs(job.queue) do
  if not job.results[task.name] and count<limit then
   local p=UnBotBotRegistry.bots[task.name];local unit=B.Live(task.name);
   if (not unit and not R.Valid(task.name,p)) or UnBotIsAccountAltProfile(task.name,p) or t.ActiveFlag(p) or UnBotSquadRosterIsOfflineReserve(task.name) then B.RefreshRecord(task.name,"skipped","защищён или недоступен");
   elseif unit then
    count=count+1;job.batch[task.name]={sent=true,retained=true,guid=UnitGUID(unit)};
   elseif #names<free then names[#names+1]=task.name;count=count+1;job.batch[task.name]={};end
  end
 end
 if count==0 then
  if job.cursor>#job.queue then
   job.batch=nil;job.status="complete";job.finishedAt=time();job.elapsedSeconds=R.Elapsed(job);
   if not job.onlyUndated then UnBotBotRegistry.meta=UnBotBotRegistry.meta or {};UnBotBotRegistry.meta.lastRegistryRefreshAt=time();UnBotBotRegistry.meta.lastRegistryRefreshTotal=#job.queue;UnBotBotRegistry.meta.lastRegistryRefreshElapsedSeconds=job.elapsedSeconds;end
   api.Balance.active,api.Balance.registryRefreshJob=false,nil;B.refresh=nil;R.MarkInitialized(job);R.Touch(job);
   R.Message("проход завершён: "..R.ProgressText(job).."; общее время: "..R.Duration(R.Elapsed(job))..". Для записи на диск /reload.");R.Message(R.ReasonText(job));
  else
   local members={};for name in pairs(t.Roster()) do if name~=UnitName("player") then members[#members+1]=name;end end;table.sort(members);
   B.RefreshPause("нет свободных мест в рейде (40 вместе с игроком). Сохранённые участники: "..table.concat(members,", "));
  end
  return;
 end
 s.commands=B.Pack(names,".playerbot bot add ");s.commandIndex=1;s.phase="add";s.nextAt=GetTime();
 s.waveSize=count;s.waveStarted=GetTime();s.retry=nil;job.current=nil;R.Touch(job);
 R.Message((job.onlyUndated and "только без даты; " or "").."пачка до "..limit..": "..count.." имён; общий who после входа; "..R.ProgressText(job).."; прошло "..R.Duration(R.Elapsed(job)));
end
function B.RefreshTick()
 local s=B.refresh;if not s then return;end
 local now=GetTime();local job=s.job;
 if job.key~=R.Key() or not UnitIsConnected("player") then B.RefreshPause("изменился персонаж или потеряно соединение");return;end
 if UnitAffectingCombat("player") or InCombatLockdown() then B.RefreshPause("начался бой; участники сохранены");return;end
 if now>s.deadline then B.RefreshPause("истёк общий срок прохода; этап "..tostring(s.phase));return;end
 if now<(s.checkAt or 0) then return;end;s.checkAt=now+.1;
 if not B.RefreshRosterSafe(s) or now<(s.nextAt or 0) then return;end
 if s.phase=="next" then
  if s.stop then B.RefreshPause("остановлено пользователем");else B.RefreshWave();end
 elseif s.phase=="add" then
  if s.stop then s.phase="join";s.joinUntil=(s.lastSent or now)+30;return;end
  local command=s.commands[s.commandIndex];
  if command then
   for name in command:sub(#".playerbot bot add "+1):gmatch("[^,]+") do
    job.batch[name].sent=true;job.batch[name].sentAt=time();owner.CancelStaleCleanup(name);
    UnBotBotRegistry.bots[name].registryLastAttemptAt=time();
   end
   SendChatMessage(command,"SAY");s.lastSent=now;s.commandIndex=s.commandIndex+1;s.nextAt=now+.25;
  else s.phase="join";s.joinUntil=now+30;end
 elseif s.phase=="join" then
  local waiting=false;
  for name,e in pairs(job.batch) do if e.sent and not e.skip and not e.failure and not e.retained and not B.Live(name) then waiting=true;end end
  if waiting and now<s.joinUntil then return;end
  if s.stop then B.RefreshCleanup();return;end
  local any=false;
  for name,e in pairs(job.batch) do
   local unit=B.Live(name);
   if unit and not e.skip then e.guid=UnitGUID(unit);if not e.retained then e.owned=true;end;any=true;e.queried=true;
   elseif not e.skip and not e.retained then
    e.failure=e.failure or "не вошёл за 30 секунд";B.RefreshRecord(name,"failed",e.failure);R.Message(name..": "..e.failure.."; пропускаю, сбор продолжается.");
   end
  end
  s.phase,s.whoUntil="who",now+3;
  if any then B.Broadcast();else B.RefreshCleanup();end
 elseif s.phase=="who" then
  local pending=false;
  for name,e in pairs(job.batch) do if not e.skip and not e.failure and not e.checked and (not job.results[name] or job.results[name].status=="failed") then pending=true;end end
  if s.stop or not pending then B.RefreshCleanup();return;end
  if now>=s.whoUntil then
   if not s.retry then
    s.retry=true;s.whoUntil=now+3;
    for name,e in pairs(job.batch) do if not e.skip and not e.failure and not e.checked and (not job.results[name] or job.results[name].status=="failed") and B.Live(name) then SendChatMessage("who","WHISPER",nil,name);end end
   else
    for name,e in pairs(job.batch) do if not e.skip and not e.checked and not job.results[name] then
     B.RefreshRecord(name,"failed",e.failure or "нет ответа who");
     R.Message(name..": "..(e.failure or "нет ответа who после двух запросов").."; пропускаю, сбор продолжается.");e.checked=true;
    end end
    B.RefreshCleanup();
   end
  end
 elseif s.phase=="cleanup" then
  B.RefreshCleanup();if not B.refresh then return;end
  local remaining={};
  if s.selective then
   for name,e in pairs(job.batch) do if e.owned and not e.retained and UnBotSquadRosterFindUnit(name) then remaining[#remaining+1]=name;end end
  elseif (GetNumRaidMembers() or 0)>0 or (GetNumPartyMembers() or 0)>0 then
   for name in pairs(t.Roster()) do if name~=UnitName("player") then remaining[#remaining+1]=name;end end
   if #remaining==0 then remaining[1]="имена состава ещё не загружены";end
  end
  if #remaining==0 then
   s.emptySince=s.emptySince or now;
   if now-s.emptySince>=1 then
    if s.waveStarted then
     job.refreshTiming=job.refreshTiming or {waves=0,seconds=0};job.refreshTiming.waves=job.refreshTiming.waves+1;job.refreshTiming.seconds=job.refreshTiming.seconds+now-s.waveStarted;s.waveStarted=nil;
    end
    for name,e in pairs(job.batch) do if e.sent and not e.owned and not e.retained and not e.skip then job.pendingArrivals[name]=e;end end
    job.batch=nil;job.batchLeaveSent=nil;s.commands=nil;s.retry=nil;s.leaveSent=nil;R.Touch(job);
    if s.stop then B.RefreshPause("остановлено пользователем");else s.verifiedBefore=job.verified or 0;s.phase="next";s.nextAt=now+.5;end
   end
  else s.emptySince=nil;if now>=s.cleanupUntil then table.sort(remaining);B.RefreshPause("выход из временной группы не подтверждён: "..table.concat(remaining,", ").."; повтор команды не отправляется");end end
 end
end
function B.RefreshReply(event,text,sender)
 local s=B.refresh;if not s then return;end
 if event=="CHAT_MSG_SYSTEM" then
  for name,e in pairs(s.job.batch or {}) do if e.sent and not B.Live(name) then e.failure=e.failure or B.Failure(text,name);end end
  return;
 end
 if event~="CHAT_MSG_WHISPER" or s.phase~="who" or s.stop then return;end
 local name=B.Name(sender,s.job.batch);local e=name and s.job.batch[name];local unit=name and B.Live(name);
 if not e or e.skip or e.failure or not unit or UnitGUID(unit)~=e.guid or UnBotIsAccountAltProfile(name,UnBotBotRegistry.bots[name]) then return;end
 local info=api.Parse(text);if not info or not info.className or not info.specName or e.checked then return;end
 if not B.RefreshQueued(s,name) then s.job.queue[#s.job.queue+1]={name=name,className=info.className,checkedAt=0};s.queued[name]=true;end
 B.Store(name,info,text);e.checked=true;B.RefreshRecord(name,"verified","свежий класс/спек из who; полный осмотр талантов не выполнялся");
end

-- Keep the existing job schema and unknown fields; legacy singleton cleanup can resume safely.
B.legacyRefreshStart=R.Start;
function R.Start(reset,onlyUndated)
 if B.refresh then R.Stop();return;end
 if not UnitIsConnected("player") or UnitAffectingCombat("player") or InCombatLockdown() then R.Message("запуск доступен при соединении и вне боя");return;end
 if api.Balance.active or api.OtherBusy() or api.Check.active or (api.Check.autoStartAt or 0)>0 then R.Message("сначала завершите текущую операцию");return;end
 if not api.SupportsSpecs() then
  if onlyUndated then R.Message("Проверка дат специализаций доступна с 11 уровня. Для сбора имён используйте «Найти новых ботов».");return;end
  R.Message("до 11 уровня собираю имена и классы без проверки специализаций");
  UnBotBotScannerDiscover();return;
 end
 t.Attach();onlyUndated=onlyUndated==true;
 local job=R.Job(onlyUndated);
 if reset and job and (job.current or job.batch) then R.Message("сначала продолжите незавершённую очистку");return;end
 if reset or not job or not R.Pending(job) then
  local queue=R.Build(onlyUndated);if #queue==0 then R.Message(onlyUndated and "ботов без даты проверки нет; запуск не требуется" or "реестр пуст");return;end
  job=job or {};job.onlyUndated=onlyUndated;job.schema=1;job.key=R.Key();job.startedAt=time();job.queue=queue;job.results={};job.cursor=1;job.processed=0;
  job.verified,job.partial,job.failed,job.fresh,job.skipped=0,0,0,0,0;job.current,job.batch,job.finishedAt=nil,nil,nil;job.batchLeaveSent=nil;job.refreshTiming={waves=0,seconds=0};job.elapsedSeconds=nil;job.retained={};job.pendingArrivals={};
  UnBotSquadConfig.registryRefreshJobs=UnBotSquadConfig.registryRefreshJobs or {};UnBotSquadConfig.registryRefreshJobs[job.key..(onlyUndated and "|undated" or "")]=job;
 end
 if job.current then
  job.batch=job.batch or {};
  job.batch[job.current.name]={sent=true,owned=job.current.owned,guid=job.current.guid};
 end
 UnBotSquadConfig.registryRefreshOnlyUndated=UnBotSquadConfig.registryRefreshOnlyUndated or {};
 UnBotSquadConfig.registryRefreshOnlyUndated[R.Key()]=onlyUndated;
 local limit=R.BatchSize();
 local s={job=job,phase="next",batchLimit=limit,deadline=GetTime()+math.max(120,math.ceil(#job.queue/limit)*75),verifiedBefore=job.verified or 0};
 B.refresh=s;api.Balance.currentName,api.Balance.currentTask=nil,nil;api.Balance.active=true;api.Balance.mode="audit";api.Balance.stage="batch_refresh";api.Balance.registryRefreshJob=job;
 job.status,job.pauseReason="running",nil;job.current=nil;
 if job.batch and next(job.batch) then
  if job.batchLeaveSent then B.RefreshCleanup();else
   local unsent={};for name,e in pairs(job.batch) do if not e.sent and not job.results[name] then unsent[#unsent+1]=name;end end
   if #unsent>0 then table.sort(unsent);s.commands=B.Pack(unsent,".playerbot bot add ");s.commandIndex=1;s.phase="add";
   else s.phase="join";s.joinUntil=GetTime()+30;end
  end
 else B.RefreshWave();end
end
function R.Stop()
 if B.refresh then B.refresh.stop=true;B.refresh.job.pauseReason="остановлено пользователем";
 else if api.Balance.active and api.Balance.registryRefreshJob then UnBotSpecAuditStop();end end
end
function R.Status(job)
 job=job or R.Job();if not job then return "Проверка известных имён пачками до "..R.BatchSize().."; общий who.";end
 local s=B.refresh;local running=R.Running();
 local label=running and "Обновляю: " or job.status=="complete" and "Завершено: " or "Приостановлено: ";
 local details;
 if running and s and s.job==job then
  local phases={next="следующая пачка",add="призыв",join="ожидание входа",who=s.retry and "повтор who неответившим" or "ответы who",cleanup="выход из группы"};
  details=(s.phase=="next" and "Следующая пачка" or "Пачка "..(s.waveSize or 0).." имён: "..(phases[s.phase] or s.phase)).."; прошло "..R.Duration(R.Elapsed(job));
 elseif job.status=="complete" then details="Общее время: "..R.Duration(R.Elapsed(job)).."; "..R.ReasonText(job);
 else details=(job.pauseReason or "очередь сохранена; продолжение вручную").."; прошло "..R.Duration(R.Elapsed(job));end
 local c=R.OutcomeCounts(job);
 return label..c.processed.."/"..c.total.." ("..c.percent.."%), осталось "..c.remaining.."; подтверждено "..c.confirmed.."; без подтверждения "..c.unconfirmed.."\n"..details;
end
-- Coalesce one buff wave's existing named requests; ownership is rechecked at send time.
function B.QueueBuff(command)
 local action,name=command:match("^%.playerbots? bot (%S+) ([^,%s]+)$");
 local c=api.Buff;
 if not c or (action~="add" and action~="remove") or name=="*" then return false;end
 B.buffQueue=B.buffQueue or {};
 B.buffQueue[#B.buffQueue+1]={action=action,name=name,context=UnBotRegistryCurrentContext(),
  invite=c.registryInvites and c.registryInvites[name],cleanup=c.cleanup and c.cleanup[name]};
 B.buffFlushAt=B.buffFlushAt or (GetTime()+.15);
 return true;
end
function B.FlushBuff()
 if not B.buffQueue or GetTime()<(B.buffFlushAt or 0) then return;end
 if UnitAffectingCombat("player") or InCombatLockdown() then return;end
 local c,adds,removes,seen=api.Buff,{},{},{};
 for _,e in ipairs(B.buffQueue) do
  local p=UnBotBotRegistry.bots[e.name];
  local protected=not c or e.context~=UnBotRegistryCurrentContext() or e.name==UnitName("player")
   or UnBotIsAccountAltProfile(e.name,p) or UnBotSquadRosterIsOfflineReserve(e.name)
   or (c.originalMembers and c.originalMembers[e.name]) or (c.baselineMembers and c.baselineMembers[e.name]);
  if not protected and not seen[e.action..":"..e.name] then
   if e.action=="add" and c.active and c.registryInvites and c.registryInvites[e.name]==e.invite
    and e.invite and c.requestedByName[e.name] and not c.assignments[c.requestedByName[e.name]]
    and not UnBotSquadRosterFindUnit(e.name) then adds[#adds+1]=e.name;
   elseif e.action=="remove" and e.cleanup and c.cleanup[e.name]==e.cleanup
    and not UnBotSquadRosterFindUnit(e.name) and not owner.CleanupProtected(e.name)
    and not (c.keptRegistryNames and c.keptRegistryNames[e.name]) then removes[#removes+1]=e.name;end
   seen[e.action..":"..e.name]=true;
  end
 end
 B.buffQueue,B.buffFlushAt=nil,nil;
 for _,command in ipairs(B.Pack(removes,".playerbot bot remove ")) do SendChatMessage(command,"SAY");end
 for _,command in ipairs(B.Pack(adds,".playerbot bot add ")) do SendChatMessage(command,"SAY");end
end
B.frame=CreateFrame("Frame");
for _,event in ipairs({"CHAT_MSG_WHISPER","CHAT_MSG_SYSTEM","PLAYER_LEAVING_WORLD","PLAYER_LOGOUT"}) do B.frame:RegisterEvent(event);end
B.frame:SetScript("OnEvent",function(_,event,text,sender)
 if event=="PLAYER_LEAVING_WORLD" or event=="PLAYER_LOGOUT" then
  if B.refresh then B.RefreshPause("выход из мира; проход приостановлен");end
 else B.RefreshReply(event,text,sender);end
end);
B.frame:SetScript("OnUpdate",function() B.RefreshTick();B.FlushBuff();end);

end
-- END NAMED BATCH TRANSPORT
