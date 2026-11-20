-- Explicit player-owned alt presets. Lua 5.1 / Interface 30300.
UnBotAltSetups = UnBotAltSetups or {};
local A = UnBotAltSetups;
A.cache = {}; A.results = {}; A.queue = {}; A.serial = 0;
A.slotNames = {"Голова","Шея","Плечи","Рубашка","Грудь","Пояс","Ноги","Ступни","Запястья","Кисти","Кольцо 1","Кольцо 2","Аксессуар 1","Аксессуар 2","Спина","Правая рука","Левая рука","Дальний бой","Накидка"};
A.slotCommands = {
    "head","neck","shoulder","shirt","chest","waist","legs","feet","wrist","hands",
    "finger 1","finger 2","trinket 1","trinket 2","back","main hand","off hand","ranged","tabard"
};
function A.Copy(value)
    if type(value)~="table" then return value; end
    local out={}; for k,v in pairs(value) do out[k]=A.Copy(v); end; return out;
end
function A.Key(name) return UnBotAccountAlts.Key(name); end
function A.Context() return tostring(GetRealmName()).."|"..tostring(UnitName("player")); end
function A.Storage()
    UnBotSquadConfig=UnBotSquadConfig or {};
    if type(UnBotSquadConfig.altSetups)~="table" then UnBotSquadConfig.altSetups={}; end
    local root=UnBotSquadConfig.altSetups;
    root.schemaVersion=math.max(1,tonumber(root.schemaVersion) or 0);
    root.realms=type(root.realms)=="table" and root.realms or {};
    local realm=tostring(GetRealmName());
    root.realms[realm]=type(root.realms[realm])=="table" and root.realms[realm] or {};
    return root.realms[realm],root;
end
function A.Entry(name)
    local storage=A.Storage(); local key=A.Key(name);
    if type(storage[key])~="table" then storage[key]={presets={},bindings={}}; end
    local e=storage[key]; e.presets=type(e.presets)=="table" and e.presets or {};
    e.bindings=type(e.bindings)=="table" and e.bindings or {}; return e;
end
function A.Names()
    local names,seen={},{};
    local function Add(name)
        if UnBotAccountAlts.CanAddToSquad and not UnBotAccountAlts.CanAddToSquad(name) then return;end
        if type(name)=="string" and name~=UnitName("player") and not seen[A.Key(name)] and UnBotAccountAlts.IsListed(name) then
            seen[A.Key(name)]=true; names[#names+1]=name;
        end
    end
    for _,name in ipairs(UnBotAccountAlts.GetNames(true,false)) do Add(name); end
    if UnBotLinkedAccounts then
        local s=UnBotLinkedAccounts.Storage();
        for _,k in ipairs(s.current or {}) do for _,row in pairs(s.accounts[k] and s.accounts[k].characters or {}) do Add(row.name); end end
    end
    table.sort(names,function(x,y) return A.Key(x)<A.Key(y); end); return names;
end
function A.Status(text,bad)
    A.status=tostring(text or ""); A.bad=bad;
    if A.Refresh then A.Refresh(); end
end
function A.Message(text) UnBotAccountAlts.Message("Наборы: "..text); end
function A.GroupNotice(text)
    if GetNumRaidMembers and GetNumRaidMembers()>0
        and ((IsRaidLeader and IsRaidLeader()) or (IsRaidOfficer and IsRaidOfficer())) then
        local send=MultiBot and MultiBot._throttleOrig or SendChatMessage
        if pcall(send,text,"RAID_WARNING") then return end
    end
    if RaidNotice_AddMessage and RaidWarningFrame then
        RaidNotice_AddMessage(RaidWarningFrame,text,ChatTypeInfo and ChatTypeInfo.RAID_WARNING or {r=1,g=.82,b=0})
    end
end
function A.ItemKey(link) return type(link)=="string" and link:match("item:([^|]+)") or false; end
function A.ItemID(link) return type(link)=="string" and tonumber(link:match("item:(%d+)")) or nil; end
function A.GearIdentity(link)
    local key=A.ItemKey(link);
    if not key then return nil;end
    local fields={};
    for field in (key..":"):gmatch("(.-):") do fields[#fields+1]=tonumber(field) or 0;end
    local generic=true;
    for index=2,8 do if (fields[index] or 0)~=0 then generic=false;end end
    return fields,generic;
end
function A.GearMatches(expected,actual)
    if not expected or not actual then return not expected and not actual;end
    local wanted,generic=A.GearIdentity(expected);
    local observed=A.GearIdentity(actual);
    if not wanted or not observed or wanted[1]~=observed[1] then return false;end
    -- Inventory replies contain type-only links. Inspect links additionally identify the item's enhancements.
    if generic then return true;end
    for index=2,8 do if (wanted[index] or 0)~=(observed[index] or 0) then return false;end end
    return true;
end
function A.Fingerprint(trees)
    local a={}; for _,tree in ipairs(trees or {}) do
        local r={};for _,t in ipairs(tree.talents or {}) do r[#r+1]=tostring(t.rank); end
        a[#a+1]=table.concat(r);
    end; return table.concat(a,"-");
end
function A.GlyphKey(list)
    local ids={}; for _,link in ipairs(list or {}) do ids[#ids+1]=A.ItemID(link) or 0; end
    table.sort(ids); return table.concat(ids,",");
end
function A.ValidTalents(snapshot)
    if type(snapshot)~="table" or type(snapshot.trees)~="table" or #snapshot.trees~=3 then return false,"Данные талантов ещё не загружены. Нажмите «Обновить данные»."; end
    local total=0;
    for _,tree in ipairs(snapshot.trees) do
        if type(tree.talents)~="table" or #tree.talents<1 or #tree.talents>50 then return false,"Не удалось получить все таланты. Обновите данные альта."; end
        local byCell={};for _,t in ipairs(tree.talents) do byCell[t.tier..":"..t.column]=t; end
        for _,t in ipairs(tree.talents) do
            if type(t.rank)~="number" or type(t.maxRank)~="number" or t.maxRank<1 or t.maxRank>5 or t.rank~=math.floor(t.rank) or t.rank<0 or t.rank>t.maxRank then return false,"В наборе указано неверное число очков таланта. Проверьте распределение."; end
            total=total+t.rank;
            if t.rank>0 then
                local lower=0;for _,other in ipairs(tree.talents) do if other.tier<t.tier then lower=lower+other.rank; end end
                if lower<(t.tier-1)*5 then return false,"Для этого ряда нужно больше очков в предыдущих рядах: "..t.name; end
                for _,p in ipairs(t.prereqs or {}) do
                    local required=byCell[p.tier..":"..p.column];
                    if not required or required.rank~=required.maxRank then return false,"Сначала полностью изучите талант, необходимый для "..t.name; end
                end
            end
        end
    end
    if total>math.max(0,(tonumber(snapshot.level) or 0)-9) then return false,"Распределено больше очков талантов, чем доступно на этом уровне."; end
    return true,total;
end
function A.Save(name,label,draft)
    label=UnBotAccountAlts.Trim(label):gsub("[%c|]","");
    if label=="" or #label>80 then return false,"Название пустое или слишком длинное. Введите короткое название, например «PvP»."; end
    if not UnBotAccountAlts.IsListed(name) or not draft or draft.name~=name or draft.realm~=GetRealmName() then return false,"Этот набор сохранён для другого персонажа или сервера."; end
    local ok,reason=A.ValidTalents(draft); if not ok then return false,reason; end
    if draft.spec~=1 and draft.spec~=2 then return false,"Выберите спек 1 или 2."; end
    if A.spells then local valid,why=A.spells.Valid(draft.spellRules);if not valid then return false,why;end end
    local e=A.Entry(name);local saved=A.Copy(e.presets[label] or {});
    for _,key in ipairs({"name","guid","realm","class","level","spec","groups","trees","gear","glyphs","spellRules"}) do saved[key]=A.Copy(draft[key]); end
    saved.updatedAt=time();saved.fingerprint=A.Fingerprint(saved.trees);
    saved.serverOutfit=A.OutfitDefinition(name,label,saved);e.presets[label]=saved;
    return true,label;
end
function A.Busy(ignoreGroup)
    return (A.groupAssembly and not ignoreGroup) or UnBotAccountAlts.active or UnBotAccountAlts.discoveryActive
        or (UnBotAccountAlts.OtherAutomationActive and UnBotAccountAlts.OtherAutomationActive())
        or (UnBotAltStrategies and (UnBotAltStrategies.active or #UnBotAltStrategies.queue>0))
        or (UnBotStrategySurvey and UnBotStrategySurvey.active)
        or (UnBotPVPSummon and UnBotPVPSummon.active)
        or (UnBotSquadSummon and UnBotSquadSummon.active)
        or (UnBotFullTalentCatalog and UnBotFullTalentCatalog.IsBusy())
        or (UnBotAltQuests and UnBotAltQuests.job)
        or (UnBotAltQuests and UnBotAltQuests.Native and UnBotAltQuests.Native.op)
        or (UnBotMythicPlusBuffOtherAutomationActive and UnBotMythicPlusBuffOtherAutomationActive());
end
function A.Ready(j,mutation)
    if A.Context()~=j.context then return nil,"Изменился активный персонаж или игровой мир. Выберите альта заново.";end
    if not UnBotAccountAlts.IsEnabled(j.name) then return nil,"Альт отключён в списке управления. Включите его перед применением набора.";end
    if not UnBotAccountAlts.IsListed(j.name) then return nil,"Альт больше не найден в списке доступных персонажей. Обновите список альтов.";end
    if UnBotAccountAlts.CanAddToSquad and not UnBotAccountAlts.CanAddToSquad(j.name) then return nil,"Альт недоступен для состава текущего персонажа. Проверьте выбранного альта.";end
    local u=UnBotAccountAlts.FindUnit(j.name);
    if not u then return nil,"Альт больше не найден в группе. Действие остановлено.";end
    if not UnitIsConnected(u) then return nil,"Альт офлайн. Действие остановлено.";end
    if UnitIsDeadOrGhost(u) then return nil,"Альт погиб. Действие остановлено.";end
    if UnitGUID(u)~=j.guid then return nil,"GUID альта изменился: в группе найден другой персонаж. Действие остановлено.";end
    if j.class and select(2,UnitClass(u))~=j.class then return nil,"Данные персонажа не совпали. Обновите данные альта."; end
    if mutation and j.mode=="section" and A.Entry(j.name).presets[j.label]~=j.presetReference then return nil,"Выбранный набор изменился. Обновите его перед применением.";end
    if mutation and UnBotAltStrategies then
        local entry=UnBotAltStrategies.Entry(j.name);local p=entry and entry.strategyProfile;
        if (p and p.revision)~=j.personalRevision or (p and p.enabled==true or false)~=j.personalEnabled then return nil,"Личные настройки альта изменились. Обновите его данные перед повторным применением набора.";end
    end
    if mutation and ((UnitAffectingCombat and (UnitAffectingCombat(u) or UnitAffectingCombat("player"))) or (InCombatLockdown and InCombatLockdown())) then return nil,"Игрок или альт в бою, поэтому действие остановлено. Настраивать набор в окне можно и во время боя."; end
    return u;
end
function A.Log(j,kind,text)
    j.trace[#j.trace+1]={at=GetTime(),kind=kind,text=text};
    if #j.trace>160 then table.remove(j.trace,1); end
end
function A.Stop(reason)
    if A.trade and A.trade.active then A.trade.Stop(reason);end
    if A.groupResult then A.groupResult.skipped=A.groupResult.skipped+#A.queue;end
    A.queue={}; if A.job then A.Finish(false,reason or "Действие остановлено. Уже выполненные изменения остаются у альта. Обновите его данные.",true);else A.groupResult=nil;end
end
function A.ReleaseInspect(j)
    local w=j and j.wait;if not w or not w.originalNotify then return;end
    w.lease=false;if NotifyInspect==w.notifyGuard then NotifyInspect=w.originalNotify;end
end
function A.Finish(ok,text,stopAll)
    local j=A.job; if not j then return; end
    A.ReleaseInspect(j);
    A.Log(j,ok and "complete" or "stopped",text);
    A.results[A.Key(j.name)]={ok=ok,text=text,stage=A.FailureStage(j),at=time(),trace=A.Copy(j.trace),name=j.name};
    A.job=nil; A.notifying=false;
    if stopAll then
        if A.groupResult then A.groupResult.skipped=A.groupResult.skipped+#A.queue;end
        A.queue={};
    end
    if not ok or (not j.autoGearRead and j.mode~="trade_read" and j.mode~="spells") then A.Message(j.name..": "..text);end
    A.Status(j.name..": "..text,not ok);
    if A.groupResult then if ok then A.groupResult.ok=A.groupResult.ok+1;else A.groupResult.failed=A.groupResult.failed+1;A.RecordGroupFailure(A.groupResult,j.name,text,A.FailureStage(j));end end
    if #A.queue>0 then
        A.nextJobAt=GetTime()+2;
        local group=A.groupResult;
        if group and group.label then A.Status("«"..group.label.."»: подтверждено "..group.ok.." из "..group.total..". Следующий альт — "..A.queue[1].name..".");end
    else
        if A.groupResult then
            local group=A.groupResult
            local complete=group.failed==0 and group.skipped==0 and (not group.total or group.ok==group.total);
            local summary;
            if group.label then
                if complete then summary="Группа «"..group.label.."» готова. Наборы применены и проверены у "..group.ok.." из "..group.total.." альтов.";
                else summary="Обработка группы «"..group.label.."» "..(stopAll and "остановлена" or "завершена")..". Подтверждено "..group.ok..", ошибок "..group.failed..", пропущено "..group.skipped..".";end
            else summary="Группа: готово "..group.ok..", ошибок "..group.failed..", пропущено "..group.skipped..".";end
            A.Message(summary)
            if group.label then A.GroupNotice(summary) end
            A.groupResult=nil;
            A.Status(A.ReportGroupFailures(group,summary),not complete);
        end
    end
end
function A.Send(kind,command,after,mutation)
    local j=A.job;if not j then return; end
    local unit,reason=A.Ready(j,mutation);if not unit then A.Finish(false,reason);return;end
    if #command>250 or command:find("[%c]") then A.Finish(false,"Не удалось отправить действие: слишком длинные или некорректные данные.");return;end
    j.wait={kind=kind,command=command,after=after,mutation=mutation,sent=false,deadline=GetTime()+10};
    j.sendAt=math.max(GetTime(),A.nextSend or 0);j.next=nil;
end
function A.Inspect(after)
    local j=A.job;if not j then return;end
    A.ReleaseInspect(j);
    local w={kind="inspect",after=after,pass=0,attempts=0,at=GetTime()+0.5,deadline=GetTime()+14,lease=true};j.wait=w;j.next=nil;
    w.originalNotify=NotifyInspect;
    w.notifyGuard=function(unit,...)
        if w.lease and (A.job==j or (A.parallelGroup and A.parallelGroup.inspectOwner==j)) and j.wait==w and GetTime()<=w.deadline and not A.notifying and (not unit or UnitGUID(unit)~=j.guid) then
            -- Background inspections share one client cache. Keep a short, bounded read window.
            local caller=debugstack and debugstack(2,8,0) or "";
            if (InspectFrame and InspectFrame:IsShown()) or caller:find("DoInspectFrameShow",1,true) or caller:find("InspectUnit",1,true) or caller:find("Blizzard_InspectUI",1,true) then
                if A.ParallelInspectConflict then A.ParallelInspectConflict(j,"Открыто обычное окно осмотра. Закройте его и обновите данные альта.") else A.Finish(false,"Открыто обычное окно осмотра. Закройте его и обновите данные альта.");end
            else
                w.deferred=(w.deferred or 0)+1;
                if w.deferred==1 then A.Log(j,"inspect_deferred","unit="..tostring(unit).."; "..caller);end
                return;
            end
        end
        return w.originalNotify(unit,...);
    end;
    NotifyInspect=w.notifyGuard;
end
function A.Snapshot(unit)
    if not UnBotFullTalentCatalog or not UnBotFullTalentCatalog.ReadSnapshot then return nil,"Не удалось загрузить осмотр альта. Выполните /reload."; end
    local s,reason=UnBotFullTalentCatalog.ReadSnapshot(unit,nil,UnitLevel(unit));if not s then return nil,reason;end
    local out={name=UnitName(unit),realm=GetRealmName(),guid=UnitGUID(unit),class=select(2,UnitClass(unit)),level=UnitLevel(unit),spec=s.activeTalentGroup,groups=GetNumTalentGroups(true),trees=s.trees,gear={},checkedAt=time()};
    for tab,tree in ipairs(out.trees) do for index,t in ipairs(tree.talents) do
        local _,icon=GetTalentInfo(tab,index,true,false,out.spec);t.icon=icon;t.prereqs={};
        if GetTalentPrereqs then local p={GetTalentPrereqs(tab,index,true,false,out.spec)};
            for i=1,#p,4 do if type(p[i])=="number" and type(p[i+1])=="number" then t.prereqs[#t.prereqs+1]={tier=p[i],column=p[i+1]};end end
        end
    end end
    for i=1,19 do
        out.gear[i]=GetInventoryItemLink(unit,i) or false;
        if not out.gear[i] and GetInventoryItemTexture and GetInventoryItemTexture(unit,i) then return nil,"Экипировка ещё загружается.";end
    end
    return out;
end
function A.SnapshotKey(s)
    local a={tostring(s.guid),tostring(s.spec),A.Fingerprint(s.trees)};
    for i=1,19 do a[#a+1]=tostring(A.ItemKey(s.gear[i]));end;return table.concat(a,"|");
end
function A.Strategies(message)
    local text=message:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","");
    local line=text:match("^Strategies:%s*(.*)");if line==nil then return;end
    local out={};for token in line:gmatch("[^,]+") do token=UnBotAccountAlts.Trim(token);if UnBotAltStrategies.Key(token) then out[token]=true;end end
    return out;
end
function A.Reply(message,sender,system)
    local j=A.job; if not j or not j.wait then return; end
    if not system and UnBotAccountAlts.SenderKey(sender)~=A.Key(j.name) then return; end
    if system and not message:find(j.name,1,true) then return;end
    local w=j.wait;if not w.sent and w.kind~="inspect" then return;end
    local low=tostring(message):lower();
    if low:find("unknown command",1,true) or low:find("cannot use",1,true) or low:find("invalid link",1,true) or low:find("cannot equip",1,true) or low:find("not enough",1,true) or low:find("can't",1,true) or low:find("cannot change",1,true) then
        A.Log(j,"refusal",message);A.Finish(false,"Сервер отказал: "..message.." Действие не будет повторено автоматически.");return;
    end
    if system then return;end
    if w.kind=="co" or w.kind=="nc" then w.response=A.Strategies(message);
    elseif w.kind=="glyphs" then
        if message:find("Glyphs:",1,true) or message:find("No glyphs equipped",1,true) then
            w.response={};for link in message:gmatch("|c%x+|Hitem:[^|]+|h%[[^%]]*%]|h|r") do w.response[#w.response+1]=link;end
            if message:find("Glyphs:",1,true) and #w.response==0 then A.Finish(false,"Не удалось прочитать символы альта. Обновите его данные.");return;end
        end
    elseif w.kind=="bags" then
        w.received=true;w.last=GetTime();w.items=w.items or {};w.seen=w.seen or {};
        for link in message:gmatch("|c%x+|Hitem:[^|]+|h%[[^%]]*%]|h|r") do local k=A.ItemKey(link);
            if not w.seen[k] and #w.items<240 then w.seen[k]=true;w.items[#w.items+1]=link;end
        end
    elseif w.kind=="switch" then
        local expected=j.target.spec==1 and "Active first talent" or "Active second talent";
        if message:find(expected,1,true) then w.response=true;end
    elseif w.kind=="talents" then if message:find("Applying "..j.target.fingerprint,1,true) then w.response=true;end
    elseif w.kind=="outfit_save" then
        local definition=j.outfitDefinition;
        if definition and message:find("Setting outfit "..definition.name.." as ",1,true) then
            w.response=true;A.MarkOutfitSaved(j);
        end
    elseif w.kind=="outfit_apply" then
        if j.outfitDefinition and message:find("Replacing current equip with outfit "..j.outfitDefinition.name,1,true) then w.response=true;end
    elseif w.kind=="gear" then if message:find("Equipping",1,true) or message:find("unequipped",1,true) then w.response=true;end
    elseif w.kind=="strategy" then if A.Strategies(message) or low:find("strategy",1,true) or low:find("strategies",1,true) then w.response=true;end end
    if w.response~=nil then A.Log(j,"reply",message);end
end
function A.Preflight(j,s)
    local p=j.target;if p.name~=j.name or p.realm~=GetRealmName() or p.guid~=j.guid or p.class~=s.class then return false,"Этот набор сохранён для другого персонажа.";end
    if p.spec~=1 and p.spec~=2 then return false,"В наборе указан неверный спек. Выберите спек 1 или 2.";end
    if p.spec>(tonumber(s.groups) or 1) then return false,"У альта не открыта выбранная специализация.";end
    local ok,reason=A.ValidTalents(p);if not ok then return false,reason;end
    if p.level~=s.level then return false,"Уровень альта изменился. Обновите его данные и сохраните набор заново.";end
    if type(p.gear)~="table" or type(p.glyphs)~="table" then return false,"В наборе не хватает данных об экипировке или символах. Обновите данные альта и сохраните набор заново.";end
    if A.spells then local valid,why=A.spells.Valid(p.spellRules);if not valid then return false,why;end end
    return A.BuildGear(j);
end
function A.BuildGear(j)
    local p,s=j.target,j.snapshot;local steps={};
    local progress={steps={},removeTotal=0,equipTotal=0};j.gearProgress=progress;
    if j.mode=="section" and j.section~="gear" then j.gearSteps={};j.gearIndex=1;return true;end
    for i=1,19 do if p.gear[i]~=false and not A.ItemID(p.gear[i]) then return false,"В наборе не заполнена ячейка «"..A.slotNames[i].."».";end end
    local ids={};for i=1,19 do local id=A.ItemID(p.gear[i]);if id then
        if ids[id] then return false,"Одинаковые вещи выбраны для двух ячеек. Сервер не различает их экземпляры. Выберите другую вещь для одной из ячеек.";end;ids[id]=true;
    end end
    -- Clear only changed equipment. Clearing paired slots permits deterministic first-empty placement.
    local changed={};for i=1,19 do if not A.GearMatches(p.gear[i],s.gear[i]) then changed[i]=true;end end
    for _,pair in ipairs({{11,12},{13,14},{16,17}}) do if changed[pair[1]] or changed[pair[2]] then changed[pair[1]]=true;changed[pair[2]]=true;end end
    local available={};for _,link in ipairs(j.bags or {}) do available[A.ItemID(link)]=true;end
    for i=1,19 do local id=A.ItemID(s.gear[i]);if id then available[id]=true;end end
    for i in pairs(changed) do local id=A.ItemID(p.gear[i]);if id and not available[id] then return false,"У альта не найдена вещь для ячейки «"..A.slotNames[i].."».";end end
    if j.mode=="apply" then
        local different=false;for _ in pairs(changed) do different=true;break end
        j.gearSteps={};j.gearIndex=1;
        if different then
            j.outfitDefinition=A.OutfitDefinition(j.name,j.label,j.target);
            local definition=j.outfitDefinition;
            if #("outfit "..definition.name.."="..definition.signature)>250 then return false,"Список предметов аутфита слишком длинный для команды.";end
            j.gearSteps={"outfit "..definition.name.."="..definition.signature,"outfit "..definition.name.." replace"};
            progress.steps={{action="outfit_save"},{action="outfit_apply"}};
        end
        return true;
    end
    for i=1,19 do if changed[i] and s.gear[i] then
        steps[#steps+1]="ue "..A.slotCommands[i];
        progress.removeTotal=progress.removeTotal+1;
        progress.steps[#steps]={action="remove",slot=i,index=progress.removeTotal};
    end end
    for i=1,19 do if changed[i] and p.gear[i] then
        local id=A.ItemID(p.gear[i]);
        -- Match EquipInventory.xml: the client resolves a localized, valid hyperlink from the item ID.
        local _,clientLink=GetItemInfo(tostring(id));
        if type(clientLink)~="string" or A.ItemID(clientLink)~=id then
            if A.ItemInfo then A.ItemInfo(p.gear[i]);end
            return false,"Ссылка на предмет ещё не загружена. Наведите на вещь мышь и повторите применение.";
        end
        steps[#steps+1]="e "..(i==16 and "mh " or i==17 and "oh " or "")..clientLink;
        progress.equipTotal=progress.equipTotal+1;
        progress.steps[#steps]={action="equip",slot=i,index=progress.equipTotal};
    end end
    j.gearSteps=steps;j.gearIndex=1;return true;
end
function A.PlanTalents(j)
    j.target.fingerprint=A.Fingerprint(j.target.trees);
    if A.Fingerprint(j.snapshot.trees)~=j.target.fingerprint then
        local ok,points=A.ValidTalents(j.target);if not ok or points==0 then A.Finish(false,"Нельзя применить пустое или неверное распределение талантов. Для переключения готового спека нажмите «Спек 1» или «Спек 2».");return;end
        A.Send("talents","talents apply "..j.target.fingerprint,"talents_done",true);
    else j.next="gear_plan";end
end
function A.Next(step)
    local j=A.job;if not j then return;end
    if step=="begin" then A.Send("co","co ?","baseline_co");
    elseif step=="baseline_co" then j.beforeCo=j.answer;A.Send("nc","nc ?","baseline_nc");
    elseif step=="baseline_nc" then j.beforeNc=j.answer;A.Inspect("baseline_inspect");
    elseif step=="baseline_inspect" then j.before=A.Copy(j.snapshot);A.Send("glyphs","glyphs","baseline_glyphs");
    elseif step=="baseline_glyphs" then
        j.snapshot.glyphs=j.answer;j.before.glyphs=A.Copy(j.answer);
        if j.mode=="slot" then j.answer={};j.next="baseline_bags";else A.Send("bags","c","baseline_bags");end
    elseif step=="baseline_bags" then
        j.bags=j.answer;j.snapshot.bags=A.Copy(j.bags);j.snapshot.bagsCheckedAt=time();if A.WarmItems then A.WarmItems(j.snapshot);end
        A.cache[A.Key(j.name)]=A.Copy(j.snapshot);
        if j.mode=="slot" and j.desiredSpec~=j.snapshot.spec then
            if j.desiredSpec>(tonumber(j.snapshot.groups) or 1) then A.Finish(false,"У альта не открыта вторая специализация.");return;end
            j.target={spec=j.desiredSpec};A.Send("switch","talents switch "..j.desiredSpec,"slot_done",true);return;
        end
        if j.mode=="section" then
            local ok,why=A.PrepareSection(j);if not ok then A.Finish(false,why);return;end
        end
        if j.mode=="read" or j.mode=="slot" then
            if A.selected==j.name then
                if (j.autoGearRead or j.mode=="slot") and (A.dirty or (A.preservePresetOnRead and A.draftLabel and not A.viewCurrent)) then
                    if A.draft then A.draft.bags=A.ProjectGearBags(j.bags,j.snapshot.gear,A.draft.gear or {});end
                    A.Finish(true,A.dirty and "Данные альта обновлены. Несохранённые изменения оставлены в окне." or "Данные альта обновлены. В окне остаётся выбранный сохранённый набор.");return;end
                A.draft=A.Copy(j.snapshot);if not A.viewCurrent then A.draftLabel=nil;end
            end
            A.Finish(true,"Данные обновлены: спек "..j.snapshot.spec..", таланты, символы и экипировка. Теперь можно настроить и сохранить набор.");return;
        end
        local ok,reason=A.Preflight(j,j.snapshot);if not ok then A.Finish(false,reason);return;end
        if j.snapshot.spec~=j.target.spec then A.Send("switch","talents switch "..j.target.spec,"switch_done",true);
        else j.next="target_glyphs_done";j.answer=j.snapshot.glyphs;end
    elseif step=="slot_done" then A.Inspect("slot_inspected");
    elseif step=="slot_inspected" then
        if j.snapshot.spec~=j.desiredSpec then A.Finish(false,"Выбранный спек не включился. Обновите данные альта.");return;end
        A.Send("glyphs","glyphs","slot_glyphs");
    elseif step=="slot_glyphs" then
        j.snapshot.glyphs=j.answer;j.snapshot.bags=j.bags;j.target=A.Copy(j.snapshot);j.target.fingerprint=A.Fingerprint(j.target.trees);j.next="personal_co_query";
    elseif step=="personal_co_query" then A.Send("co","co ?","personal_co");
    elseif step=="switch_done" then A.Inspect("target_inspected");
    elseif step=="target_inspected" then
        if j.snapshot.spec~=j.target.spec then A.Finish(false,"Сервер не подтвердил смену спека. Обновите данные альта.");return;end
        A.Send("glyphs","glyphs","target_glyphs_done");
    elseif step=="target_glyphs_done" then
        j.snapshot.glyphs=j.answer;
        if A.GlyphKey(j.answer)~=A.GlyphKey(j.target.glyphs) then A.Finish(false,"Символы не совпадают с набором. Войдите за альта и настройте их на нужном спеке: из этого окна изменить их нельзя.");return;end
        A.PlanTalents(j);
    elseif step=="talents_done" then A.Inspect("talents_verified");
    elseif step=="talents_verified" then
        if j.snapshot.spec~=j.target.spec or A.Fingerprint(j.snapshot.trees)~=j.target.fingerprint then A.Finish(false,"Таланты не совпали с набором. Обновите данные альта и проверьте очки. Автоматического повтора не будет.");return;end
        j.next="gear_plan";
    elseif step=="gear_plan" then
        local ok,reason=A.BuildGear(j);if not ok then A.Finish(false,reason);return;end;j.next="gear_next";
    elseif step=="gear_next" then
        local index=j.gearIndex;local command=j.gearSteps[index];j.gearIndex=index+1;
        if command then
            if j.gearProgress then j.gearProgress.stage="commands";j.gearProgress.current=j.gearProgress.steps[index];end
            local action=j.gearProgress and j.gearProgress.current;
            local kind=action and action.action;
            if kind=="outfit_save" or kind=="outfit_apply" then A.Send(kind,command,"gear_next",kind=="outfit_apply");
            else A.Send("gear",command,"gear_next",true);end
        else
            if j.gearProgress then j.gearProgress.stage="verify";end
            A.Inspect("gear_verified");
        end
    elseif step=="gear_verified" then
        local observed=A.cache[A.Key(j.name)] or {};
        observed.name=j.name;observed.realm=j.snapshot.realm;observed.guid=j.snapshot.guid;observed.gear=A.Copy(j.snapshot.gear);observed.checkedAt=time();
        A.cache[A.Key(j.name)]=observed;
        for i=1,19 do if not A.GearMatches(j.target.gear[i],j.snapshot.gear[i]) then
            local expected,actual=j.target.gear[i],j.snapshot.gear[i];
            A.Entry(j.name).lastGearFailure={at=time(),slot=i,expected=expected,actual=actual,trace=A.Copy(j.trace)};
            local reason;
            if not expected then reason="Не удалось снять "..tostring(actual or "предмет")..". Ячейка «"..A.slotNames[i].."» осталась занятой.";
            elseif not actual then reason="Не удалось надеть "..expected..". Ячейка «"..A.slotNames[i].."» осталась пустой.";
            else reason="В ячейке «"..A.slotNames[i].."» ожидалось "..expected..", но осмотр показывает "..actual..".";end
            A.Finish(false,reason.." Проверьте свободное место в сумках и сообщения сервера.");return;
        end end
        j.gearIntent=A.Copy(j.target.gear);j.target.gear=A.Copy(j.snapshot.gear);
        if j.gearProgress then j.gearProgress.stage="verified";end
        if j.snapshot.spec~=j.target.spec or A.Fingerprint(j.snapshot.trees)~=j.target.fingerprint then A.Finish(false,"Во время переодевания сменился спек. Обновите данные альта.");return;end
        if j.fastGear then j.next="fast_gear_commit";
        elseif A.spells and j.target.spellRules and next(j.target.spellRules) then j.next="spell_apply_read";
        else A.Send("co","co ?","personal_co");end
    elseif step=="personal_co" then j.actualCo=j.answer;A.Send("nc","nc ?","personal_nc");
    elseif step=="personal_nc" then
        j.actualNc=j.answer;j.strategySteps={};
        for _,section in ipairs({"co","nc"}) do
            local desired=j.personal and j.personal[section] or {};
            local actual=section=="co" and j.actualCo or j.actualNc;
            local chunks=UnBotAltStrategies.Diff(desired,actual,section);
            for _,command in ipairs(chunks) do j.strategySteps[#j.strategySteps+1]={command=command,section=section};end
        end
        j.strategyIndex=1;j.next="personal_next";
    elseif step=="personal_next" then
        local item=j.strategySteps[j.strategyIndex];j.strategyIndex=j.strategyIndex+1;
        if item then A.Send("strategy",item.command,"personal_next",true);
        elseif #j.strategySteps>0 then A.Send("co","co ?","personal_verify_co");
        else j.next="final_glyphs";end
    elseif step=="personal_verify_co" then j.actualCo=j.answer;A.Send("nc","nc ?","personal_verify_nc");
    elseif step=="personal_verify_nc" then
        j.actualNc=j.answer;
        for _,section in ipairs({"co","nc"}) do
            local actual=section=="co" and j.actualCo or j.actualNc;
            for key,value in pairs(j.personal and j.personal[section] or {}) do if (actual[key]==true)~=value then A.Finish(false,"Не удалось подтвердить личную настройку: "..section.." "..key..". Обновите данные альта.");return;end end
        end;j.next="final_glyphs";
    elseif step=="final_glyphs" then A.Send("glyphs","glyphs","complete");
    elseif step=="complete" then
        if not j.finalGlyphs then
            if A.GlyphKey(j.answer)~=A.GlyphKey(j.target.glyphs) then A.Finish(false,"После смены талантов символы изменились. Действие остановлено. Проверьте символы, войдя за альта.");return;end
            j.finalGlyphs=A.Copy(j.answer);
            if j.gearSteps and #j.gearSteps>0 then A.Send("bags","c","complete");return;end
        elseif j.gearSteps and #j.gearSteps>0 then j.bags=j.answer;end
        j.snapshot.spellRules=A.Copy(j.target.spellRules);j.snapshot.glyphs=j.finalGlyphs;j.snapshot.bags=j.bags;A.cache[A.Key(j.name)]=A.Copy(j.snapshot);
        if j.mode=="section" then A.CommitSection(j);return;end
        if j.mode=="apply" and j.gearIntent then
            local preset=A.Entry(j.name).presets[j.label];
            if preset then for slot=1,19 do
                local expected=preset.gear[slot];
                local _,generic=A.GearIdentity(expected);
                if generic and A.ItemKey(expected)==A.ItemKey(j.gearIntent[slot])
                    and A.GearMatches(expected,j.snapshot.gear[slot]) then
                    preset.gear[slot]=j.snapshot.gear[slot];
                end
            end end
        end
        if A.selected==j.name and j.mode=="apply" then A.draft=A.Copy(j.snapshot);A.draftLabel=j.label;A.dirty=false;if A.RememberPreset then A.RememberPreset(j.name,j.label);end end
        if j.mode=="slot" then
            if A.selected==j.name and not A.draftLabel then A.draft=A.Copy(j.snapshot);A.draftLabel=nil;A.viewCurrent=true;A.dirty=false end
            A.Finish(true,"Спек №"..j.snapshot.spec.." включён. Его таланты и символы загружены в окно.");
        else A.Finish(true,"Набор «"..j.label.."» применён: спек "..j.target.spec..". Таланты и экипировка проверены."..(j.target.spellRules and next(j.target.spellRules) and " Настройки заклинаний проверены." or ""));end
    end
end
function A.Begin(item)
    local unit=UnBotAccountAlts.FindUnit(item.name);
    if not unit or not UnitIsConnected(unit) or not UnBotAccountAlts.IsEnabled(item.name) then
        A.job={name=item.name,trace={}};A.Finish(false,"Альт должен быть в игре и в вашей группе.");return;
    end
    A.serial=A.serial+1;
    A.job={id=A.serial,name=item.name,guid=UnitGUID(unit),class=select(2,UnitClass(unit)),context=A.Context(),mode=item.mode,target=A.Copy(item.target),label=item.label,next="begin",trace={},started=GetTime(),deadline=GetTime()+180};
    local entry=UnBotAltStrategies.Entry(item.name);local p=entry and entry.strategyProfile;
    A.job.personalRevision=p and p.revision;A.job.personalEnabled=p and p.enabled==true or false;
    if p and p.enabled then A.job.personal={co=UnBotAltStrategies.CopyMap(p.co) or {},nc=UnBotAltStrategies.CopyMap(p.nc) or {}};end
    A.job.desiredSpec=item.desiredSpec;
    A.Status(item.name..": обновляем данные...");
    local group=A.groupResult
    if group and group.label and item.mode=="apply" then
        A.GroupNotice("Подтверждено "..group.ok.." из "..group.total..". "..item.name..": применяем и проверяем набор «"..item.label.."».")
    end
end
function A.Start(name,label,progressive)
    if A.job or #A.queue>0 then A.Status("Действие уже выполняется. Дождитесь завершения или нажмите «Стоп».",true);return false;end
    if A.Busy() then A.Status("UnBot занят другим действием. Дождитесь его завершения.",true);return false;end
    if not name or not UnBotAccountAlts.IsEnabled(name) then A.Status("Выберите своего альта из списка.",true);return false;end
    local p=label and A.Entry(name).presets[label];if label and not p then A.Status("Набор не найден. Выберите его в списке.",true);return false;end
    A.Begin({name=name,label=label,target=p,mode=p and "apply" or "read"});
    if A.job and not p then A.job.progressive=progressive==true;end
    return A.job~=nil;
end
function A.ActivateSlot(slot)
    if A.dirty then A.Status("Сначала сохраните набор или нажмите «Отменить изменения».",true);return false;end
    if A.job or #A.queue>0 or A.Busy() then A.Status("UnBot занят другим действием. Дождитесь его завершения.",true);return false;end
    if not A.selected then return false;end
    A.Begin({name=A.selected,mode="slot",desiredSpec=slot});return A.job~=nil;
end
function A.StartGroup(mode)
    if A.job or #A.queue>0 then A.Status("Действие уже выполняется.",true);return false;end
    if A.Busy() then A.Status("UnBot занят другим действием.",true);return false;end
    local items,skipped={},0;
    for _,name in ipairs(A.Names()) do
        local e=A.Entry(name);if e.selected then
            local label=e.bindings[mode];local p=label and e.presets[label];local unit=UnBotAccountAlts.FindUnit(name);
            if p and unit and UnitIsConnected(unit) and UnBotAccountAlts.IsEnabled(name) then items[#items+1]={name=name,label=label,target=A.Copy(p),mode="apply"};
            else skipped=skipped+1;A.results[A.Key(name)]={ok=false,text="Пропущен: не назначен набор "..mode.." или альт не найден в группе.",name=name};end
        end
    end
    if #items==0 then A.Status("Отметьте альтов и назначьте каждому набор "..mode..". Альты должны быть онлайн в группе.",true);return false;end
    A.groupResult={ok=0,failed=0,skipped=skipped};A.queue=items;A.nextJobAt=GetTime();return true;
end
function A.Tick()
    local j=A.job;
    if not j then if #A.queue>0 and GetTime()>=(A.nextJobAt or 0) then A.Begin(table.remove(A.queue,1));end;return;end
    local unit,reason=A.Ready(j);if not unit then A.Finish(false,reason,true);return;end
    if GetTime()>j.deadline then A.Finish(false,"Время ожидания истекло. Обновите данные альта: часть изменений могла уже примениться. Автоматического повтора не будет.");return;end
    local w=j.wait;
    if not w then if j.next then local step=j.next;j.next=nil;A.Next(step);end;return;end
    if w.kind=="inspect" then
        if GetTime()>w.deadline then A.Finish(false,"Не удалось проверить экипировку и таланты альта. Обновите данные снова.");return;end
        if not w.pending and GetTime()>=w.at then
            if CanInspect and not CanInspect(unit) then A.Finish(false,"Закройте обычное окно осмотра и подведите альта поближе. Затем обновите данные.");return;end
            w.pending=true;w.attempts=(w.attempts or 0)+1;A.notifying=true;local ok=pcall(NotifyInspect,unit);A.notifying=false;
            if not ok then A.Finish(false,"Игра не разрешила осмотр альта. Окно настроек остаётся доступным.");end
        end
    else
        if not w.sent and GetTime()>=j.sendAt then
            local ready,why=A.Ready(j,w.mutation);if not ready then A.Finish(false,why);return;end
            w.sent=true;w.sentAt=GetTime();w.deadline=GetTime()+10;A.nextSend=GetTime()+((j.fastGear and w.kind=="gear") and .5 or 1.5);A.Log(j,w.mutation and "mutation" or "query",w.command);
            -- MultiBot publishes the immediate chat API. Our finite controller paces it itself;
            -- no mutation is left in a third-party queue after Stop or a roster change.
            local send=MultiBot and MultiBot._throttleOrig or SendChatMessage;
            A.quietChat={name=A.Key(j.name),command=w.command,kind=w.kind,untilAt=GetTime()+12};
            if not pcall(send,w.command,"WHISPER",nil,j.name) then A.Finish(false,"Не удалось подтвердить отправку действия. Обновите данные альта перед повторным применением набора.");return;end
        end
        if w.kind=="gear" and w.sent and GetTime()-w.sentAt>=(j.fastGear and .5 or 1.5) then w.response=true;end
        if w.kind=="bags" and w.received and GetTime()-(w.last or 0)>2 then w.response=w.items or {};end
        if w.response~=nil then j.answer=w.response;j.wait=nil;j.next=w.after;
        elseif w.sent and GetTime()>w.deadline then
            if w.kind=="strategy" then j.wait=nil;j.next=w.after;
            elseif w.mutation then A.Finish(false,"Нет подтверждения команды «"..w.command.."». Неизвестно, выполнилось ли действие. Обновите данные альта. Автоматического повтора не будет.");
            elseif w.kind=="bags" then j.wait=nil;j.answer={};j.next=w.after;j.bagsUnknown=true;
            else A.Finish(false,"Нет ответа на «"..w.command.."». Действие остановлено.");end
        end
    end
    if A.RefreshStatus then A.RefreshStatus();end
end
function A.InspectReady()
    local j=A.job;local w=j and j.wait;if not w or w.kind~="inspect" or not w.pending then return;end
    local unit=A.Ready(j);if not unit then return;end
    local s,reason;
    if w.after=="progressive_gear" then s,reason=A.EquipmentSnapshot(unit);else s,reason=A.Snapshot(unit);end
    w.pending=false;
    local expected=(w.after=="slot_inspected" and j.desiredSpec) or ((w.after=="target_inspected" or w.after=="talents_verified") and j.target and j.target.spec);
    if s and expected and s.spec~=expected then s=nil;reason="Ждём обновление активной специализации.";end
    if s and w.after=="talents_verified" and A.Fingerprint(s.trees)~=j.target.fingerprint then s=nil;reason="Ждём новые ранги талантов.";end
    if not s then
        A.Log(j,"inspect_incomplete",tostring(reason));w.first=nil;w.firstSnapshot=nil;
        if (w.attempts or 0)<4 and GetTime()+1.5<w.deadline then w.at=GetTime()+1.5;
        else A.Finish(false,"Не удалось получить полные данные альта. Подведите его ближе и обновите данные.");end;return;
    end
    local key=A.SnapshotKey(s);
    local gearPending=false;
    if w.after=="gear_verified" and j.target then
        for slot=1,19 do if not A.GearMatches(j.target.gear[slot],s.gear[slot]) then gearPending=true;break end end
    end
    local fastVerified=j.fastGear and w.after=="gear_verified" and not gearPending;
    if fastVerified or (w.first==key and (not gearPending or (w.attempts or 0)>=4)) then
        A.Log(j,"inspect_stable","requests="..tostring(w.attempts).."; deferred="..tostring(w.deferred or 0));
        A.ReleaseInspect(j);j.snapshot=s;j.wait=nil;j.next=w.after;
    elseif (w.attempts or 0)<4 and GetTime()+1.5<w.deadline then
        if w.firstSnapshot then
            local differences={};local previous=w.firstSnapshot;
            if previous.spec~=s.spec then differences[#differences+1]="spec";end
            if A.Fingerprint(previous.trees)~=A.Fingerprint(s.trees) then differences[#differences+1]="talents";end
            for i=1,19 do if A.ItemKey(previous.gear[i])~=A.ItemKey(s.gear[i]) then differences[#differences+1]="gear:"..i;end end
            A.Log(j,"inspect_loading",table.concat(differences,","));
        end
        w.first=key;w.firstSnapshot=A.Copy(s);w.pass=(w.pass or 0)+1;w.at=GetTime()+1.5;
    else A.Finish(false,"Данные альта продолжают меняться. Подождите немного и обновите их снова.");end
end
A.frame=CreateFrame("Frame");
for _,event in ipairs({"CHAT_MSG_WHISPER","CHAT_MSG_SYSTEM","INSPECT_TALENT_READY","PLAYER_ENTERING_WORLD","PLAYER_REGEN_DISABLED"}) do A.frame:RegisterEvent(event);end
A.frame:SetScript("OnEvent",function(self,event,message,sender)
    if event=="CHAT_MSG_WHISPER" then A.Reply(message,sender);
    elseif event=="CHAT_MSG_SYSTEM" then A.Reply(tostring(message),nil,true);
    elseif event=="INSPECT_TALENT_READY" then A.InspectReady();
    elseif event=="PLAYER_ENTERING_WORLD" then if A.job or A.groupAssembly or A.parallelGroup or A.pendingGearBags or #A.queue>0 then A.Stop("Местоположение или персонаж изменились. Оставшиеся действия отменены.");end;A.cache={};
    elseif event=="PLAYER_REGEN_DISABLED" and (A.groupAssembly or (A.job and A.job.mode~="read")) then A.Stop("Начался бой. Оставшиеся действия остановлены. Настраивать набор в окне можно.");end
end);
A.frame:SetScript("OnUpdate",function(self,elapsed) self.elapsed=(self.elapsed or 0)+elapsed;if self.elapsed<0.1 then return;end;self.elapsed=0;A.Tick();end);
if hooksecurefunc then hooksecurefunc("NotifyInspect",function(unit)
    local j=A.job;
    if j and j.wait and j.wait.kind=="inspect" and not A.notifying and (not unit or UnitGUID(unit)~=j.guid) then
        A.Log(j,"inspect_conflict","unit="..tostring(unit).."; "..tostring(debugstack and debugstack(2,8,0) or ""));
        A.Finish(false,"Другой аддон прервал осмотр. Обновите данные альта ещё раз.");
    end
end);end
SLASH_UNBOTALTSETUPS1="/ubsetups";
SlashCmdList.UNBOTALTSETUPS=function(text) if text=="stop" then A.Stop();elseif A.Show then A.Show();end end;

-- BEGIN ALT SETUP ITEM CACHE
do
-- Item metadata cache, following Ling's saved texture -> client info -> GetItemIcon order.
local A=UnBotAltSetups;
local C={queue={},pending={},tried={},nextAt=0};A.icons=C;
function C.Storage()
    local _,root=A.Storage();root.itemInfo=type(root.itemInfo)=="table" and root.itemInfo or {};
    local key=tostring(GetRealmName()).."|"..tostring(GetLocale and GetLocale() or "enUS");
    if C.contextKey and C.contextKey~=key then C.queue={};C.pending={};C.tried={};C.deadline=nil;end;C.contextKey=key;
    if type(root.itemInfo[key])~="table" then root.itemInfo[key]={};end
    return root.itemInfo[key],key;
end
function C.ValidTexture(texture)
    if type(texture)=="number" then return texture>0 and texture or nil;end
    if type(texture)~="string" or texture=="" then return;end
    local low=texture:lower();if low:find("questionmark",1,true) or low:find("wowunknownitem",1,true) then return;end
    return texture;
end
function C.LingIcons()
    local realm=GetRealmName();if C.lingRealm==realm and C.lingDB==PikaBankViewerDB then return;end
    C.lingRealm=realm;C.lingDB=PikaBankViewerDB;C.ling={};
    if type(PikaBankViewerDB)~="table" then return;end
    local count=0;
    local function Import(items)
        for _,item in ipairs(type(items)=="table" and items or {}) do
            local id=tonumber(item.id);local texture=C.ValidTexture(item.texture);
            if id and texture and count<12000 then C.ling[id]={texture=texture};count=count+1;end
        end
    end
    for key,bank in pairs(PikaBankViewerDB.reagentSearchBanks or {}) do
        if type(key)=="string" and key:sub(1,#realm+1)==realm..":" and type(bank)=="table" then Import(bank.items);end
    end
    for _,character in pairs(PikaBankViewerDB.characters or {}) do
        if type(character)=="table" and character.realm==realm and type(character.bank)=="table" then Import(character.bank.items);end
    end
end
function C.Read(link,queue)
    local id=A.ItemID(link);if not id then return {};end
    local storage,key=C.Storage();local info=storage[id];if type(info)~="table" then info={};storage[id]=info;end
    C.LingIcons();local imported=C.ling[id];
    if not C.ValidTexture(info.texture) then info.texture=imported and imported.texture;end
    local name,_,quality,level,required,itemType,subType,_,equipLoc,texture=GetItemInfo(link);
    texture=C.ValidTexture(texture) or C.ValidTexture(GetItemIcon and GetItemIcon(id));
    local changed=false;
    if texture and info.texture~=texture then info.texture=texture;changed=true;end
    if name then
        if info.name~=name or info.equipLoc~=equipLoc then changed=true;end
        info.name=name;info.quality=quality;info.level=level;info.requiredLevel=required;info.itemType=itemType;info.subType=subType;info.equipLoc=equipLoc;info.checkedAt=time();
    end
    if queue and (not info.texture or not info.name or info.equipLoc==nil) and not C.pending[id] and (C.tried[id] or 0)<2 and #C.queue<300 then
        C.queue[#C.queue+1]={id=id,link=link,key=key,at=GetTime()};C.pending[id]=true;
        C.deadline=C.deadline or GetTime()+45;
    end
    return info,changed;
end
function A.ItemInfo(link) return C.Read(link,true);end
function A.WarmItems(snapshot)
    if not snapshot then return;end
    for _,field in ipairs({"gear","glyphs","bags"}) do for _,link in pairs(snapshot[field] or {}) do if link then C.Read(link,true);end end end
end
function C.Stop() C.queue={};C.pending={};C.deadline=nil;C.refresh=nil;end
function C.Tick()
    local running=A.job or A.groupAssembly or A.parallelGroup or #A.queue>0 or A.pendingOutfitSave or A.pendingGearBags;
    if (not A.window or not A.window:IsShown()) and not running then if #C.queue>0 then C.Stop();end;return;end
    local now=GetTime();
    if C.refresh and now>=(C.refreshedAt or 0)+0.5 then C.refresh=nil;C.refreshedAt=now;if A.Refresh then A.Refresh();end end
    if #C.queue==0 then C.deadline=nil;return;end
    if C.deadline and now>C.deadline then C.Stop();return;end
    if now<C.nextAt then return;end
    C.nextAt=now+0.12;
    local request=table.remove(C.queue,1);C.pending[request.id]=nil;
    local _,key=C.Storage();if key~=request.key then C.Stop();return;end
    local info,changed=C.Read(request.link,false);if changed then C.refresh=true;end
    if info.texture and info.name and info.equipLoc~=nil then return;end
    if now<request.at then C.queue[#C.queue+1]=request;C.pending[request.id]=true;return;end
    if request.final then return;end
    C.tried[request.id]=(C.tried[request.id] or 0)+1;
    if not C.tooltip then C.tooltip=CreateFrame("GameTooltip","UnBotAltSetupsItemQueryTooltip",UIParent,"GameTooltipTemplate");end
    -- A hidden standard item tooltip requests client metadata, without cursor/focus changes.
    C.tooltip:SetOwner(UIParent,"ANCHOR_NONE");pcall(C.tooltip.SetHyperlink,C.tooltip,request.link);C.tooltip:Hide();
    if C.tried[request.id]<2 then request.at=now+0.8;C.queue[#C.queue+1]=request;C.pending[request.id]=true;
    else request.final=true;request.at=now+1.2;C.queue[#C.queue+1]=request;C.pending[request.id]=true;end
end
C.frame=CreateFrame("Frame");C.frame:SetScript("OnUpdate",function() C.Tick();end);

end

-- BEGIN ALT SETUP SPELL RULES
do
local A=UnBotAltSetups;
local S={};A.spells=S;
function S.Valid(rules)
    if rules==nil then return true;end
    if type(rules)~="table" then return false,"Не удалось прочитать настройки заклинаний в наборе. Выберите их заново.";end
    local n=0;for id,value in pairs(rules) do
        n=n+1;if type(id)~="number" or id<1 or id~=math.floor(id) or type(value)~="boolean" or n>64 then return false,"В наборе можно настроить до 64 заклинаний. Проверьте выбранные запреты и разрешения.";end
    end;return true;
end
function S.Link(id) return GetSpellLink(id) or ("|cffffffff|Hspell:"..id.."|h["..id.."]|h|r");end
function S.Set(id,value)
    if A.job or (A.trade and A.trade.active) then A.Status("Дождитесь завершения текущего действия.",true);return;end
    if not A.draft then A.Status("Сначала нажмите «Обновить данные».",true);return;end
    A.draft.spellRules=A.draft.spellRules or {};A.draft.spellRules[id]=value;A.dirty=true;A.Refresh();
end
function S.Read()
    if A.dirty then A.Status("Перед обновлением сохраните набор или нажмите «Отменить изменения».",true);return;end
    if not A.selected or A.job or #A.queue>0 or A.Busy() then A.Status("Выберите альта и дождитесь завершения текущего действия UnBot.",true);return;end
    A.Begin({name=A.selected,mode="spells"});
end
function S.Plan(j)
    j.spellBefore=A.Copy(j.answer);j.spellExpected=A.Copy(j.answer);j.spellSteps={};
    for id,value in pairs(j.target.spellRules or {}) do
        j.spellExpected[id]=value or nil;
        if (j.answer[id]==true)~=value then j.spellSteps[#j.spellSteps+1]={id=id,ban=value};end
    end
    table.sort(j.spellSteps,function(x,y) return x.id<y.id;end);j.spellIndex=1;j.next="spell_apply_next";
end
function S.Same(x,y)
    for id,v in pairs(x) do if v and not y[id] then return false;end end
    for id,v in pairs(y) do if v and not x[id] then return false;end end;return true;
end
local previousNext=A.Next;
function A.Next(step)
    local j=A.job;if not j then return;end
    if step=="begin" and j.mode=="spells" then A.Send("ignored","ss ?","spell_read_ignored");
    elseif step=="spell_read_ignored" then j.ignored=A.Copy(j.answer);A.Send("spellbook","spells","spell_read_book");
    elseif step=="spell_read_book" then
        local entry=A.Entry(j.name);entry.spellbook={guid=j.guid,at=time(),ids=A.Copy(j.answer),ignored=A.Copy(j.ignored)};
        if A.selected==j.name then A.Refresh();end
        A.Finish(true,"Список заклинаний обновлён: "..#j.answer.." записей. Выберите запреты и сохраните набор.");
    elseif step=="spell_apply_read" then A.Send("ignored","ss ?","spell_apply_plan");
    elseif step=="spell_apply_plan" then S.Plan(j);
    elseif step=="spell_apply_next" then
        local item=j.spellSteps[j.spellIndex];j.spellIndex=j.spellIndex+1;
        -- Numeric IDs replace the server list. A bare hyperlink adds one; -hyperlink removes one.
        if item then A.Send("spell_change","ss "..(item.ban and "" or "-")..S.Link(item.id),"spell_apply_next",true);
        else A.Send("ignored","ss ?","spell_apply_verified");end
    elseif step=="spell_apply_verified" then
        if not S.Same(j.spellExpected,j.answer) then A.Finish(false,"Запреты заклинаний не совпали с ожидаемыми. Обновите список и проверьте настройки. Автоматического повтора не будет.");return;end
        local b=A.Entry(j.name).spellbook;if b and b.guid==j.guid then b.ignored=A.Copy(j.answer);end
        A.Send("co","co ?","personal_co");
    else previousNext(step);end
end
local previousReply=A.Reply;
function A.Reply(message,sender,system)
    previousReply(message,sender,system);
    local j=A.job;local w=j and j.wait;
    if not w or not w.sent or system or UnBotAccountAlts.SenderKey(sender)~=A.Key(j.name) then return;end
    local low=message:lower();
    if low:find("unknown spell",1,true) then A.Finish(false,"Сервер не распознал это заклинание. Действие не будет повторено автоматически.");return;end
    if w.kind=="ignored" then
        if message:find("Ignored spell list is empty",1,true) then w.response={};
        elseif message:find("Ignored spell list:",1,true) then
            local ids={};for id in message:gmatch("|Hspell:(%d+)") do ids[tonumber(id)]=true;end
            if not next(ids) then A.Finish(false,"Не удалось прочитать запреты заклинаний. Обновите список снова.");return;end
            w.response=ids;
        end
    elseif w.kind=="spell_change" then
        if message:find("added to ignored spells",1,true) or message:find("removed from ignored spells",1,true) then w.response=true;end
    elseif w.kind=="spellbook" then
        if message:find("=== Spells ===",1,true) then w.header=true;w.items={};w.ids={};w.last=GetTime();end
        if w.header then
            for id in message:gmatch("|Hspell:(%d+)") do id=tonumber(id);
                if not w.ids[id] then w.ids[id]=true;w.items[#w.items+1]=id;end
            end
            w.last=GetTime();
            if #w.items>2000 then A.Finish(false,"Список заклинаний слишком большой. Он не сохранён, чтобы не потерять часть записей.");return;end
        end
        if message:find("No spells found",1,true) then w.response={};end
    end
end
local previousTick=A.Tick;
function A.Tick()
    local j=A.job;local w=j and j.wait;
    if w and w.kind=="spellbook" and w.sent then
        if not w.extended then w.extended=true;w.deadline=GetTime()+40;end
        if w.header and GetTime()-(w.last or 0)>3 then w.response=w.items;end
    end
    previousTick();
end
end

-- BEGIN ALT SETUP TRADE
do
local A=UnBotAltSetups;
local T={cart={},bags={}};A.trade=T;
function T.PlayerBags()
    local rows,totals={},{};
    for bag=0,4 do for slot=1,GetContainerNumSlots(bag) do
        local link=GetContainerItemLink(bag,slot);
        if link then local _,count,locked=GetContainerItemInfo(bag,slot);local id=A.ItemID(link);
            if id then rows[#rows+1]={link=link,id=id,count=count,locked=locked,bag=bag,slot=slot};totals[id]=(totals[id] or 0)+count;end
        end
    end end;return rows,totals;
end
function T.Add(row,direction,count)
    if A.job then A.Status("Дождитесь завершения текущего действия.",true);return;end
    if not A.selected or not row then return;end
    if T.owner~=A.selected then T.cart={};T.owner=A.selected;end
    if row.bound and direction=="give" then A.Status("Свою персональную вещь выберите вручную в седьмой ячейке окна обмена.",true);return;end
    if row.bound then
        for _,v in ipairs(T.cart) do if v.bound then A.Status("Для зачарования можно выбрать одну вещь альта.",true);return;end end
    end
    count=tonumber(count);if not count or count<1 or count~=math.floor(count) then A.Status("Введите целое количество предметов, не меньше одного.",true);return;end
    if direction=="take" then if count~=1 then A.Status("За один обмен у альта можно забрать одну целую стопку каждой выбранной вещи.",true);return;end;else if count>row.count then A.Status("В этой стопке нет указанного количества. Уменьшите число.",true);return;end end
    local slots=0;for _,v in ipairs(T.cart) do if v.direction==direction and not v.bound then slots=slots+(direction=="take" and v.count or 1);end
        if (direction=="give" and v.direction==direction and v.bag==row.bag and v.slot==row.slot) or (direction=="take" and v.direction==direction and v.id==row.id) then A.Status("Вещь уже выбрана. Нажмите на неё, чтобы снять выбор, затем укажите количество и выберите снова.",true);return;end
    end
    if not row.bound and slots+(direction=="take" and count or 1)>6 then A.Status("За один обмен можно передать до шести стопок с каждой стороны.",true);return;end
    local v=A.Copy(row);v.direction=direction;v.count=count;T.cart[#T.cart+1]=v;A.Refresh();
end
function T.Selected(row,direction)
    if not row or T.owner~=A.selected then return;end
    for i,v in ipairs(T.cart) do
        if v.direction==direction and ((direction=="take" and v.id==row.id) or (direction=="give" and v.bag==row.bag and v.slot==row.slot and A.ItemKey(v.link)==A.ItemKey(row.link))) then return i;end
    end
end
function T.Toggle(row,direction,count)
    if A.job then A.Status("Дождитесь завершения текущего действия.",true);return;end
    local index=T.Selected(row,direction);
    if index then table.remove(T.cart,index);A.Refresh();else T.Add(row,direction,count);end
end
function T.Start(readOnly)
    if A.job or #A.queue>0 or A.Busy() then A.Status("UnBot занят другим действием. Дождитесь его завершения.",true);return;end
    if not A.selected then return;end
    T.pendingRefresh=nil;
    if not readOnly and (T.owner~=A.selected or #T.cart==0) then A.Status("Выберите вещи кликом в сумках.",true);return;end
    if not readOnly and ((TradeFrame and TradeFrame:IsShown()) or (GetCursorInfo and GetCursorInfo())) then A.Status("Закройте открытое окно обмена и уберите предмет с курсора.",true);return;end
    A.Begin({name=A.selected,mode=readOnly and "trade_read" or "trade"});
    if A.job then A.job.cart=A.Copy(T.cart);end
end
function T.Partner(j)
    return UnitGUID("NPC")==j.guid and A.Key(UnitName("NPC"))==A.Key(j.name);
end
function T.Stop()
    local j=A.job;T.active=nil;if A.window then A.window:SetFrameStrata("DIALOG");end
    if j and j.mode=="trade" and j.opened and T.Partner(j) and TradeFrame and TradeFrame:IsShown() then j.opened=nil;pcall(CancelTrade);end
end
function T.Validate(j,only)
    for _,v in ipairs(only and {only} or j.cart) do
        if v.direction=="give" then
            local link=GetContainerItemLink(v.bag,v.slot);local _,count,locked=GetContainerItemInfo(v.bag,v.slot);
            if A.ItemKey(link)~=A.ItemKey(v.link) or locked or (count or 0)<v.count then return false,"Вещи в ваших сумках изменились. Снимите выбор и выберите их заново.";end
        else
            local found=false;for _,r in ipairs(j.bagRows or {}) do if r.id==v.id and (r.bound==true)==(v.bound==true) then found=true;end end
            if v.bound then for _,link in pairs(j.snapshot.gear) do if A.ItemKey(link)==A.ItemKey(v.link) then found=true;end end end
            if not found then return false,"Одна из выбранных вещей больше не доступна у альта. Обновите сумки и выберите вещи заново.";end
            if v.bound then
                local copies=0;for _,r in ipairs(j.bagRows or {}) do if r.id==v.id then copies=copies+(r.count or 1);end end
                for _,link in pairs(j.snapshot.gear) do if A.ItemID(link)==v.id then copies=copies+1;end end
                if copies>1 then return false,"У альта несколько одинаковых вещей. Выберите предмет для зачарования вручную, чтобы не перепутать экземпляры.";end
            end
            -- The server searches all inventory by ID; prevent selecting an equipped copy.
            for _,link in pairs(j.snapshot.gear) do if not v.bound and A.ItemID(link)==v.id then return false,"Такая же вещь надета на альте. Сначала снимите её вручную, затем обновите сумки.";end end
        end
    end;return true;
end
function T.Offers()
    local offer={give={},take={}};
    for i=1,6 do
        for _,side in ipairs({"give","take"}) do
            local link=(side=="give" and GetTradePlayerItemLink or GetTradeTargetItemLink)(i);
            if link then local _,_,count=(side=="give" and GetTradePlayerItemInfo or GetTradeTargetItemInfo)(i);
                local id=A.ItemID(link);if id then offer[side][id]=(offer[side][id] or 0)+(count or 1);end
            end
        end
    end;offer.enchant=A.ItemID(GetTradeTargetItemLink(7));return offer;
end
function T.Matches(j,offer)
    local give,take={},{};local enchant;
    for _,v in ipairs(j.cart) do if v.bound then enchant=v.id;elseif v.direction=="give" then give[v.id]=(give[v.id] or 0)+v.count;else take[v.id]=true;end end
    if enchant~=offer.enchant then return false;end
    for id,count in pairs(give) do if offer.give[id]~=count then return false;end end
    for id in pairs(offer.give) do if not give[id] then return false;end end
    for id in pairs(take) do if not offer.take[id] or offer.take[id]<1 then return false;end end
    for id in pairs(offer.take) do if not take[id] then return false;end end
    return true;
end
function T.Open(j)
    local unit,reason=A.Ready(j,true);if not unit then A.Finish(false,reason);return;end
    if not CheckInteractDistance(unit,2) then A.Finish(false,"Подведите альта поближе, чтобы открыть обмен.");return;end
    local ok,why=T.Validate(j);if not ok then A.Finish(false,why);return;end
    local _,totals=T.PlayerBags();j.playerBefore=totals;j.tradePhase="opening";j.tradeAt=GetTime()+10;j.next=nil;j.wait=nil;
    T.active=true;if A.window then A.window:SetFrameStrata("MEDIUM");end
    if not pcall(InitiateTrade,unit) then A.Finish(false,"Игра не разрешила открыть обмен. Проверьте, что альт рядом и доступен.");end
end
local previousNext=A.Next;
function A.Next(step)
    local j=A.job;if not j then return;end
    if step=="begin" and j.mode=="trade_read" then A.Inspect("trade_inspected");
    elseif step=="begin" and j.mode=="trade" then A.Inspect("trade_inspected");
    elseif step=="trade_inspected" then A.cache[A.Key(j.name)]=A.Copy(j.snapshot);A.Send("trade_bags","c","trade_bags_read");
    elseif step=="trade_bags_read" then
        j.bagRows=j.answer;T.bags[A.Key(j.name)]={guid=j.guid,at=GetTime(),rows=A.Copy(j.answer)};
        if j.mode=="trade_read" then A.Finish(true,"Сумки обновлены. У альта показано общее количество каждой вещи, включая все её стопки.");else T.Open(j);end
    elseif step=="trade_request_next" then
        local v=j.cart[j.tradeIndex];j.tradeIndex=j.tradeIndex+1;
        if not v then j.tradePhase="review";j.wait=nil;j.next=nil;j.tradeAt=GetTime()+90;A.Status("Проверьте вещи и количество в окне обмена WoW, затем подтвердите передачу.");return;end
        if v.direction=="take" then
            j.tradePhase="request";local link;
            if v.bound then
                -- Confirm possession in bags or equipped slots, then resolve the client-localized link by ID.
                for _,row in ipairs(j.bagRows or {}) do if row.id==v.id and row.bound and (row.count or 1)==1 then link=row.link;break end end
                if not link then
                    for slot=1,19 do local item=j.snapshot.gear[slot];if A.ItemID(item)==v.id then link=item;break end end
                end
                if not link then A.Finish(false,"Вещь для зачарования не найдена у альта. Обмен остановлен.");return;end
                A.Log(j,"enchant_source_link",link);
                local _,clientLink=GetItemInfo(tostring(v.id));
                if type(clientLink)~="string" or A.ItemID(clientLink)~=v.id then
                    A.Finish(false,"Не загрузилась клиентская ссылка на вещь для зачарования. Наведите на неё мышь и повторите запрос.");return;
                end
                link=clientLink;A.Log(j,"enchant_client_link",link);
            else local _,clientLink=GetItemInfo(v.link);link=clientLink or v.link;end
            A.Send("trade_request",(v.bound and "nt " or "give ")..link,"trade_request_next",true);
        else j.pendingItem=v;j.tradePhase="place";j.next=nil;end
    elseif step=="trade_finished_bags" then
        local before,after={},{};for _,r in ipairs(j.bagRows or {}) do before[r.id]=r.count;end;for _,r in ipairs(j.answer) do after[r.id]=r.count;end
        for _,v in ipairs(j.cart) do
            local expected=(before[v.id] or 0)+(j.offer.give[v.id] or 0)-(j.offer.take[v.id] or 0);
            if (after[v.id] or 0)~=expected then A.Finish(false,"У вас количество вещей изменилось, но в сумках альта результат не совпал. Обновите его данные и проверьте вещи. Обмен не повторится автоматически.");return;end
        end
        T.bags[A.Key(j.name)]={guid=j.guid,at=GetTime(),rows=A.Copy(j.answer)};T.cart={};T.active=nil;
        A.Finish(true,"Обмен завершён. Вещи проверены, сумки обоих персонажей обновлены.");
    else previousNext(step);end
end
local previousReply=A.Reply;
function A.Reply(message,sender,system)
    previousReply(message,sender,system);
    local j=A.job;local w=j and j.wait;
    if not w or not w.sent or system or UnBotAccountAlts.SenderKey(sender)~=A.Key(j.name) then return;end
    if w.kind=="trade_bags" then
        if message:find("=== Inventory ===",1,true) then w.header=true;w.rows={};w.ids={};end
        if w.header then
            local link=message:match("^%s*(|c%x+|Hitem:[^|]+|h%[[^%]]*%]|h|r)");
            if link then local id=A.ItemID(link);if w.ids[id] then A.Finish(false,"В списке сумок есть повторяющиеся вещи. Данные не загружены; обновите сумки снова.");return;end
                w.ids[id]=true;w.rows[#w.rows+1]={id=id,link=link,count=tonumber(message:sub(#link+1):match("^x(%d+)")) or 1,bound=message:find("(soulbound)",1,true)~=nil};
                if #w.rows>240 then A.Finish(false,"Список сумок слишком большой. Обновите сумки снова.");return;end
            end
            local count=tonumber(message:match("=== Inventory end: (%d+) ==="));
            if count then if count~=#w.rows then A.Finish(false,"Не удалось получить весь список вещей. Обновите сумки снова.");else w.response=w.rows;end end
        end
    end
end
local previousFinish=A.Finish;
function A.Finish(ok,text,all)
    if A.job and A.job.mode=="trade" then T.Stop();end
    previousFinish(ok,text,all);
end
local previousTick=A.Tick;
function A.Tick()
    local j=A.job;
    if j and j.mode=="trade" and j.tradePhase then
        local unit,why=A.Ready(j,true);
        if not unit then A.Finish(false,why,true);return;end
        if j.tradePhase=="closed" then
            if GetTime()<j.tradeAt then return;end
            local _,totals=T.PlayerBags();j.offer=j.acceptedOffer or j.offer;local valid=j.tradeComplete and j.offer and T.Matches(j,j.offer);
            local evidence={"server="..tostring(j.tradeComplete),"offer="..tostring(j.offer~=nil),"list="..tostring(j.offer and T.Matches(j,j.offer))};
            for _,v in ipairs(j.cart) do evidence[#evidence+1]=v.id..":"..tostring(j.playerBefore[v.id] or 0).."/"..tostring(totals[v.id] or 0);end;A.Log(j,"trade_evidence",table.concat(evidence,"; "));
            if valid then
                local ids={};for id in pairs(j.offer.give) do ids[id]=true;end;for id in pairs(j.offer.take) do ids[id]=true;end
                for id in pairs(ids) do if (totals[id] or 0)~=(j.playerBefore[id] or 0)-(j.offer.give[id] or 0)+(j.offer.take[id] or 0) then valid=false;end end
            end
            j.tradePhase=nil;T.active=nil;
            if valid then A.Send("trade_bags","c","trade_finished_bags");
            else A.Finish(false,"Обмен закрыт. Передача не подтверждена; выбранные вещи сохранены. Проверьте сумки перед новым запросом.");end;return;
        end
        if GetTime()>j.tradeAt then A.Finish(false,"Время обмена истекло. Проверьте сумки перед новым запросом.");return;end
        if j.tradePhase~="opening" and not T.Partner(j) then A.Finish(false,"Участник обмена изменился. Передача остановлена.",true);return;end
        if j.tradePhase=="place" then
            local v=j.pendingItem;local ok,reason=T.Validate(j,v);if not ok then A.Finish(false,reason);return;end
            if GetCursorInfo and GetCursorInfo() then A.Finish(false,"Уберите предмет с курсора и запросите обмен снова.");return;end
            local slot=1;while slot<=6 and GetTradePlayerItemLink(slot) do slot=slot+1;end
            if slot>6 then A.Finish(false,"В окне обмена нет свободной ячейки для вещи.");return;end
            j.offerSlot=slot;local _,count=GetContainerItemInfo(v.bag,v.slot);
            if v.count<count then
                local empty;
                for bag=0,4 do
                    local family=0;if bag>0 and GetContainerNumFreeSlots then local free;free,family=GetContainerNumFreeSlots(bag);end
                    if family==0 then for cell=1,GetContainerNumSlots(bag) do if not empty and not GetContainerItemLink(bag,cell) then empty={bag=bag,slot=cell};end end end
                end
                if not empty then A.Finish(false,"Освободите ячейку в обычной сумке, чтобы отделить нужное количество предметов.");return;end
                j.split={bag=empty.bag,slot=empty.slot,before=count,link=v.link,count=v.count};
                local split=pcall(function() SplitContainerItem(v.bag,v.slot,v.count);PickupContainerItem(empty.bag,empty.slot);end);
                if not split or (GetCursorInfo and GetCursorInfo()) then A.Finish(false,"Не удалось отделить нужное количество. Проверьте сумку и предмет на курсоре.");return;end
                j.tradePhase="split_wait";j.actionDeadline=GetTime()+5;return;
            end
            local placed=pcall(function() PickupContainerItem(v.bag,v.slot);ClickTradeButton(slot);end);
            if not placed or (GetCursorInfo and GetCursorInfo()) then A.Finish(false,"Вещь не удалось добавить в обмен. Проверьте сумки и предмет на курсоре.");return;end
            j.tradePhase="place_wait";j.actionDeadline=GetTime()+5;
        elseif j.tradePhase=="split_wait" then
            local v=j.pendingItem;local split=j.split;
            local _,count,locked=GetContainerItemInfo(split.bag,split.slot);local _,left,sourceLocked=GetContainerItemInfo(v.bag,v.slot);
            if A.ItemKey(GetContainerItemLink(split.bag,split.slot))==A.ItemKey(v.link) and count==v.count and left==split.before-v.count and not locked and not sourceLocked then
                v.bag=split.bag;v.slot=split.slot;j.split=nil;j.tradePhase="place";
            elseif GetTime()>j.actionDeadline then A.Finish(false,"Не удалось проверить количество в отделённой стопке. Обмен отменён; проверьте сумки.");end;return;
        elseif j.tradePhase=="place_wait" then
            local v=j.pendingItem;local _,_,count=GetTradePlayerItemInfo(j.offerSlot);
            if A.ItemKey(GetTradePlayerItemLink(j.offerSlot))==A.ItemKey(v.link) and count==v.count then
                j.pendingItem=nil;j.tradePhase="building";j.next="trade_request_next";
            elseif GetTime()>j.actionDeadline then A.Finish(false,"В обмене оказалось другое количество предметов. Обмен отменён до передачи.");end;return;
        elseif j.tradePhase=="request" and j.wait and j.wait.sent then
            if GetTime()>=(j.requestCheckAt or 0) then
                local v=j.cart[j.tradeIndex-1];local found=0;
                if v.bound then
                    if A.ItemID(GetTradeTargetItemLink(7))==v.id then found=1;end
                    for slot=1,6 do if A.ItemID(GetTradeTargetItemLink(slot))==v.id then
                        A.Finish(false,"Вещь для зачарования попала в слот передачи. Обмен отменён: используйте ячейку «Не будет передано».");return;
                    end end
                else for i=1,6 do if A.ItemID(GetTradeTargetItemLink(i))==v.id then found=found+1;end end end
                if found>=v.count then j.wait.response=true;end
            end
        end
        if j.tradePhase=="opening" or j.tradePhase=="review" then return;end
    end
    previousTick();
end
T.frame=CreateFrame("Frame");
for _,event in ipairs({"TRADE_SHOW","TRADE_CLOSED","TRADE_REQUEST_CANCEL","TRADE_ACCEPT_UPDATE","TRADE_PLAYER_ITEM_CHANGED","TRADE_TARGET_ITEM_CHANGED","UI_INFO_MESSAGE","CHAT_MSG_SYSTEM"}) do T.frame:RegisterEvent(event);end
T.frame:SetScript("OnEvent",function(_,event,a,b)
    local j=A.job;if not j or j.mode~="trade" or not j.tradePhase then return;end
    if (event=="UI_INFO_MESSAGE" or event=="CHAT_MSG_SYSTEM") and (a==ERR_TRADE_COMPLETE or b==ERR_TRADE_COMPLETE) then j.tradeComplete=true;
    elseif event=="TRADE_SHOW" then
        if not T.Partner(j) then A.Finish(false,"Открылся обмен с другим персонажем. Выбранные вещи не отправлены.");return;end
        j.opened=true;j.tradePhase="building";j.tradeAt=GetTime()+90;j.tradeIndex=1;j.next="trade_request_next";
    elseif event=="TRADE_CLOSED" or event=="TRADE_REQUEST_CANCEL" then
        j.tradePhase="closed";j.tradeAt=GetTime()+1.5;j.wait=nil;j.next=nil;
    elseif event=="TRADE_ACCEPT_UPDATE" then
        if T.Partner(j) then j.offer=T.Offers();if tonumber(a)==1 then j.acceptedOffer=A.Copy(j.offer);end end
    elseif event=="TRADE_PLAYER_ITEM_CHANGED" or event=="TRADE_TARGET_ITEM_CHANGED" then
        if j.tradePhase~="closed" and not j.tradeComplete then j.offer=nil;end;j.requestCheckAt=GetTime()+0.3;
    end
end);
end

-- Event-driven, single-shot refresh of the visible trade tab. No periodic bag queries.
do
local A=UnBotAltSetups;
local T=A.trade;
function T.Visible(name)
    return A.window and A.window:IsShown() and A.tab==5 and A.selected and (not name or A.selected==name);
end
function T.RequestRefresh(name,result,force)
    name=name or A.selected;
    if not result and not force then return;end
    if T.stopping or not T.Visible(name) then return;end
    if A.job and A.job.name==name and (A.job.mode=="trade_read" or A.job.mode=="trade") then return;end
    T.pendingRefresh={name=name,context=A.Context(),at=GetTime()+0.3,deadline=GetTime()+20,result=A.Copy(result)};
end
function T.AutoTick()
    if T.playerRefresh and GetTime()>=T.playerRefresh then
        T.playerRefresh=nil;if T.Visible() and A.RefreshTrade then A.RefreshTrade();end
    end
    local p=T.pendingRefresh;if not p then return;end
    if not T.Visible(p.name) or p.context~=A.Context() or GetTime()>p.deadline then T.pendingRefresh=nil;return;end
    if GetTime()<p.at or A.job or #A.queue>0 or A.Busy() then return;end
    T.pendingRefresh=nil;
    local unit=UnBotAccountAlts.FindUnit(p.name);
    if not unit or not UnitIsConnected(unit) or not UnBotAccountAlts.IsEnabled(p.name) or not UnBotAccountAlts.IsListed(p.name) then return;end
    T.Start(true);
    if A.job and A.job.name==p.name and A.job.mode=="trade_read" then A.job.autoBagRefresh=true;A.job.tradeResult=p.result;end
end
local previousTick=A.Tick;
function A.Tick() previousTick();T.AutoTick();end
local previousFinish=A.Finish;
function A.Finish(ok,text,all)
    local j=A.job;previousFinish(ok,text,all);
    if j and j.mode=="trade" and not ok and not T.stopping then T.RequestRefresh(j.name,A.results[A.Key(j.name)]);
    elseif j and j.autoBagRefresh and j.tradeResult then
        A.results[A.Key(j.name)]=j.tradeResult;
        A.Status(j.name..": "..j.tradeResult.text..(ok and " Сумки обновлены." or " Обновить сумки не удалось."),not j.tradeResult.ok);
    end
end
local previousStop=A.Stop;
function A.Stop(reason)
    T.pendingRefresh=nil;T.playerRefresh=nil;T.stopping=true;previousStop(reason);T.stopping=nil;
end
T.autoFrame=CreateFrame("Frame");
for _,event in ipairs({"BAG_UPDATE","TRADE_SHOW","TRADE_CLOSED","TRADE_REQUEST_CANCEL","PLAYER_ENTERING_WORLD"}) do T.autoFrame:RegisterEvent(event);end
T.autoFrame:SetScript("OnEvent",function(_,event)
    if event=="PLAYER_ENTERING_WORLD" then T.pendingRefresh=nil;T.playerRefresh=nil;T.externalTrade=nil;
    elseif event=="BAG_UPDATE" then if T.Visible() then T.playerRefresh=GetTime()+0.2;end
    elseif event=="TRADE_SHOW" then
        T.externalTrade=nil;
        if T.Visible() and not (A.job and A.job.mode=="trade") then
            local unit=UnBotAccountAlts.FindUnit(A.selected);
            if unit and UnitGUID(unit)==UnitGUID("NPC") and A.Key(UnitName("NPC"))==A.Key(A.selected) then T.externalTrade={name=A.selected,context=A.Context()};end
        end
    elseif T.externalTrade then
        local p=T.externalTrade;T.externalTrade=nil;
        if p.context==A.Context() then T.RequestRefresh(p.name,nil,true);end
    end
end);
end

-- Read the selected alt once for equipment, talents or glyphs, preserving unsaved edits.
do
local A=UnBotAltSetups;
local G={};A.gearRead=G;
function G.Visible(name)
    local tab=A.tab or 1;
    return A.window and A.window:IsShown() and tab>=1 and tab<=3 and A.selected and (not name or A.selected==name);
end
function G.Request(name,force)
    name=name or A.selected;
    -- Opening the editor uses its cached snapshot. Only an explicit refresh reads again.
    if not force then return;end
    if not G.Visible(name) or A.dirty then return;end
    if A.job and A.job.name==name and (A.job.mode=="read" or A.job.mode=="apply" or A.job.mode=="slot") then return;end
    local now=GetTime();
    local readyBy=(A.job and A.job.mode=="read" and A.job.deadline) or now;
    G.pending={name=name,context=A.Context(),at=now+0.3,deadline=math.max(now,readyBy)+20};
end
function G.Tick()
    local p=G.pending;if not p then return;end
    if not G.Visible(p.name) or A.dirty or p.context~=A.Context() or GetTime()>p.deadline then G.pending=nil;return;end
    if GetTime()<p.at or A.job or #A.queue>0 or A.Busy() then return;end
    G.pending=nil;local unit=UnBotAccountAlts.FindUnit(p.name);
    if not unit or not UnitIsConnected(unit) or not UnBotAccountAlts.IsEnabled(p.name) or not UnBotAccountAlts.IsListed(p.name) then return;end
    A.Start(p.name,nil,(A.tab or 1)==1);
    if A.job and A.job.name==p.name and A.job.mode=="read" then A.job.autoGearRead=true;end
end
local previousStart=A.Start;
function A.Start(name,label,progressive) G.pending=nil;return previousStart(name,label,progressive);end
local previousStop=A.Stop;
function A.Stop(reason) G.pending=nil;return previousStop(reason);end
local previousTick=A.Tick;
function A.Tick() previousTick();G.Tick();end
G.frame=CreateFrame("Frame");G.frame:RegisterEvent("PLAYER_ENTERING_WORLD");G.frame:SetScript("OnEvent",function() G.pending=nil;end);
end

-- Personal task actions and named group setups. Saved data is extended lazily.
do
local A=UnBotAltSetups;
function A.RememberPreset(name,label) A.Entry(name).selectedPreset=label;end
function A.NewLabel(name,spec)
    local base="Спек "..tostring(spec or 1);local label=base;
    for i=1,100 do if not A.Entry(name).presets[label] then return label;end;label=base.." ("..(i+1)..")";end
end
function A.StartSection(name,label,section,draft)
    if A.job or #A.queue>0 or A.Busy() then A.Status("Дождитесь завершения текущего действия.",true);return false;end
    if section~="talents" and section~="gear" and section~="spells" then return false;end
    if not draft or draft.name~=name or draft.realm~=GetRealmName() or not UnBotAccountAlts.IsListed(name) then A.Status("Сначала выберите альта и обновите его данные.",true);return false;end
    label=UnBotAccountAlts.Trim(label or "");if label=="" then label=A.NewLabel(name,draft.spec);end
    if not label or #label>80 or label:find("[%c|]") then A.Status("Введите короткое название набора.",true);return false;end
    local valid,why=true;
    if section=="talents" then valid,why=A.ValidTalents(draft);if not valid then A.Status(why,true);return false;end end
    if A.spells then valid,why=A.spells.Valid(draft.spellRules);if not valid then A.Status(why,true);return false;end end
    if A.gearRead then A.gearRead.pending=nil;end;if A.trade then A.trade.pendingRefresh=nil;end
    A.Begin({name=name,label=label,mode="section"});
    if not A.job then return false;end
    A.job.section=section;A.job.sectionDraft=A.Copy(draft);A.job.presetReference=A.Entry(name).presets[label];
    A.job.fastGear=section=="gear";return true;
end
function A.PrepareSection(j)
    local d,s=j.sectionDraft,j.snapshot;
    if not d or d.guid~=s.guid or d.class~=s.class then return false,"Данные относятся к другому персонажу. Обновите данные альта.";end
    j.target=A.Copy(s);j.target.spellRules=nil;
    if j.section=="talents" then j.target.spec=d.spec;j.target.trees=A.Copy(d.trees);j.target.glyphs=A.Copy(d.glyphs);j.target.fingerprint=A.Fingerprint(d.trees);
    elseif j.section=="gear" then j.target.gear=A.Copy(d.gear);
    else j.target.spellRules=A.Copy(d.spellRules);end
    return true;
end
function A.CommitSection(j)
    if A.Entry(j.name).presets[j.label]~=j.presetReference then A.Finish(false,"Альт изменён, но набор уже отредактирован в другом месте. Обновите данные перед сохранением.");return;end
    local saved=A.Copy(j.presetReference or j.snapshot);
    for _,key in ipairs({"name","realm","guid","class","level","groups"}) do saved[key]=A.Copy(j.snapshot[key]);end
    if j.section=="talents" then saved.trees=A.Copy(j.snapshot.trees);saved.spec=j.snapshot.spec;saved.glyphs=A.Copy(j.snapshot.glyphs);
    elseif j.section=="gear" then saved.gear=A.Copy(j.snapshot.gear);
    else saved.spellRules=A.Copy(j.sectionDraft.spellRules);end
    local ok,why=A.Save(j.name,j.label,saved);if not ok then A.Finish(false,"Альт изменён, но набор не сохранён: "..tostring(why));return;end
    A.RememberPreset(j.name,j.label);
    if A.selected==j.name then
        A.draft=A.Copy(j.sectionDraft);A.draftLabel=j.label;
        for _,key in ipairs({"trees","spec","groups","glyphs"}) do if A.draft[key]==nil then A.draft[key]=A.Copy(saved[key]);end end
        if j.section=="talents" then A.draft.trees=A.Copy(j.snapshot.trees);A.draft.spec=j.snapshot.spec;A.draft.glyphs=A.Copy(j.snapshot.glyphs);
        elseif j.section=="gear" then A.draft.gear=A.Copy(j.snapshot.gear);else A.draft.spellRules=A.Copy(j.sectionDraft.spellRules);end
        A.draft.bags=A.ProjectGearBags(j.bags,j.snapshot.gear,A.draft.gear or {});A.draft.level=j.snapshot.level;
        A.dirty=A.Fingerprint(A.draft.trees)~=A.Fingerprint(saved.trees) or not A.spells.Same(A.draft.spellRules or {},saved.spellRules or {});
        -- false is an explicit allow rule, not an absent key.
        for id,v in pairs(A.draft.spellRules or {}) do if (saved.spellRules or {})[id]~=v then A.dirty=true;end end
        for id,v in pairs(saved.spellRules or {}) do if (A.draft.spellRules or {})[id]~=v then A.dirty=true;end end
        for i=1,19 do if A.ItemKey(A.draft.gear[i])~=A.ItemKey(saved.gear[i]) then A.dirty=true;end end
        A.viewCurrent=false;
    end
    local captions={talents="Таланты",gear="Экипировка",spells="Настройки заклинаний"};
    A.Finish(true,captions[j.section].." применены и сохранены в наборе «"..j.label.."».");
end
function A.GroupStorage()
    local _,root=A.Storage();root.groupSetups=type(root.groupSetups)=="table" and root.groupSetups or {};
    local all=root.groupSetups;all.contexts=type(all.contexts)=="table" and all.contexts or {};all.schemaVersion=1;
    local key=A.Context();if type(all.contexts[key])~="table" then all.contexts[key]={profiles={}};end
    local db=all.contexts[key];db.profiles=type(db.profiles)=="table" and db.profiles or {};
    if not db.migratedBindings then
        for _,mode in ipairs({"pve","pvp"}) do
            local label=mode=="pve" and "PvE" or "PvP";
            if not db.profiles[label] then
                local group={name=label,members={},updatedAt=time()};
                for _,name in ipairs(A.Names()) do local e=A.Entry(name);local preset=e.bindings[mode];
                    if preset and e.presets[preset] then group.members[A.Key(name)]={name=name,preset=preset,enabled=e.selected==true};end
                end;db.profiles[label]=group;
            end
        end;db.migratedBindings=true;
    end;return db;
end
function A.GroupNames()
    local out={};for label in pairs(A.GroupStorage().profiles) do out[#out+1]=label;end;table.sort(out);return out;
end
function A.SaveGroup(label,draft,oldLabel)
    if A.job or A.groupAssembly or #A.queue>0 then return false,"Сначала дождитесь завершения действия.";end
    label=UnBotAccountAlts.Trim(label or "");if label=="" or #label>80 or label:find("[%c|]") then return false,"Введите короткое название группы.";end
    local db=A.GroupStorage();if label~=oldLabel and db.profiles[label] then return false,"Группа с таким названием уже существует.";end
    local saved=A.Copy(db.profiles[oldLabel or label] or {});saved.name=label;saved.members=A.Copy(draft.members or {});saved.updatedAt=time();
    for _,v in pairs(saved.members) do
        if v.enabled and (not UnBotAccountAlts.IsListed(v.name) or not A.Entry(v.name).presets[v.preset or ""] or (UnBotAccountAlts.CanAddToSquad and not UnBotAccountAlts.CanAddToSquad(v.name))) then return false,"Выберите доступного альта и его сохранённый набор для каждого участника.";end
    end
    db.profiles[label]=saved;if oldLabel and oldLabel~=label then db.profiles[oldLabel]=nil;end;return true,label;
end
local function GroupEligible(name)
    return A.Key(name)~=A.Key(UnitName("player"))
        and UnBotAccountAlts.IsListed(name) and UnBotAccountAlts.IsEnabled(name)
        and (not UnBotAccountAlts.CanAddToSquad or UnBotAccountAlts.CanAddToSquad(name))
end
local function GroupUnit(item)
    if not GroupEligible(item.name) then return nil end
    local unit=UnBotAccountAlts.FindUnit(item.name)
    if unit and UnitIsConnected(unit) and UnitGUID(unit)==item.target.guid then return unit end
end
local function GroupSkip(plan,name,reason)
    plan.skipped=plan.skipped+1
    local text="Пропущен: "..reason
    A.results[A.Key(name)]={ok=false,name=name,text=text,stage="подготовка состава"}
    A.RecordGroupFailure(plan,name,text,"подготовка состава")
    A.Message(name..": "..text)
end
local function BeginGroupApply(plan)
    A.groupAssembly=nil
    if #plan.ready==0 then
        local summary="Не удалось подготовить ни одного участника группы «"..plan.label.."»."
        A.Status(A.ReportGroupFailures(plan,summary),true)
        A.Message(summary)
        A.GroupNotice(summary)
        return false
    end
    if A.StartParallelGroup then return A.StartParallelGroup(plan) end
    A.groupResult={ok=0,failed=0,skipped=plan.skipped,label=plan.label,total=#plan.ready}
    A.queue=plan.ready
    A.nextJobAt=GetTime()
    A.Status("Состав проверен. Применяем наборы группы «"..plan.label.."».")
    A.GroupNotice("«"..plan.label.."»: призыв завершён, начинаем применение и проверку наборов. Подтверждено 0 из "..#plan.ready..".")
    return true
end
local function GroupInCombat()
    return (InCombatLockdown and InCombatLockdown()) or UnitAffectingCombat("player")
end
local function TickGroupAssembly(plan)
    local alts=UnBotAccountAlts
    local now=GetTime()
    if plan.context~=A.Context() or GroupInCombat() or now>plan.deadline then
        A.Stop("Сбор группы остановлен. Проверьте состав и запустите команду снова.")
        return
    end
    local dismounted,why=A.GroupDismountReady(plan)
    if dismounted~=true then if dismounted==false then A.Stop(why) end;return end
    local request=plan.request
    if request then
        if request.cancelled then A.Stop("Сбор группы остановлен.");return end
        if alts.setupSummon==request then
            if now>request.deadline then alts.Finish("Время ожидания подключения альта истекло.")
            else return end
        end
        if request.sent and not request.showArrival then
            request.showArrival=true
            A.Status("Призыв • "..(plan.index-1).."/"..#plan.items.." — "..request.item.name..": ждём, пока альт будет рядом.")
        end
        local unit=GroupUnit(request.item)
        if request.sent and unit and (not CanInspect or CanInspect(unit)) and now>=request.sentAt+1.5 then
            plan.ready[#plan.ready+1]=request.item
        elseif request.sent and now<=request.deadline then
            return
        else
            local reason=request.full and "в группе нет свободного места." or "альт не подключился или не подошёл на расстояние осмотра."
            GroupSkip(plan,request.item.name,reason)
        end
        plan.request=nil
        plan.nextAt=now+.4
        return
    end
    if now<plan.nextAt or A.Busy(true) then return end
    local item=plan.items[plan.index]
    if not item then BeginGroupApply(plan);return end
    plan.index=plan.index+1
    if GroupUnit(item) then
        plan.ready[#plan.ready+1]=item
    elseif not GroupEligible(item.name) then
        GroupSkip(plan,item.name,"альт больше недоступен.")
    else
        request={item=item,guid=item.target.guid,context=plan.context,deadline=now+25}
        if alts.StartQueue and alts.StartQueue({item.name},"summon",request) then
            plan.request=request
            local progress="1/2 • Призыв "..(plan.index-1).."/"..#plan.items.." — подключаем "..item.name.."."
            A.Status(progress)
            A.GroupNotice(progress)
        else
            GroupSkip(plan,item.name,"не удалось запустить призыв.")
        end
    end
end
local previousAssemblyTick=A.Tick
function A.Tick()
    if A.groupAssembly then TickGroupAssembly(A.groupAssembly);return end
    previousAssemblyTick()
end
local previousAssemblyStop=A.Stop
function A.Stop(reason)
    local plan=A.groupAssembly
    if plan then
        A.groupAssembly=nil
        if plan.request and UnBotAccountAlts.setupSummon==plan.request then
            UnBotAccountAlts.Finish("Призыв альта остановлен.")
        end
        local message=reason or "Сбор группы остановлен."
        A.Status(message,true)
        A.GroupNotice(message)
    end
    previousAssemblyStop(reason)
end
function A.StartNamedGroup(label)
    if A.job or #A.queue>0 or A.Busy() then
        A.Status("Дождитесь завершения текущего действия.",true);A.Message(A.status);return false
    end
    if GroupInCombat() then A.Status("Собрать группу и применить наборы можно после боя.",true);A.Message(A.status);return false end
    local db=A.GroupStorage()
    local group=db.profiles[label]
    if not group then
        for key,stored in pairs(db.profiles) do
            if A.Key(key)==A.Key(label) then group=stored;label=key;break end
        end
    end
    if not group then A.Status("Группа «"..tostring(label).."» не найдена.",true);A.Message(A.status);return false end
    local plan={label=label,items={},ready={},skipped=0,index=1,context=A.Context(),nextAt=GetTime()}
    local keys={}
    for key in pairs(group.members or {}) do keys[#keys+1]=key end
    table.sort(keys)
    local needsSummon=false
    for _,key in ipairs(keys) do
        local member=group.members[key]
        if member.enabled then
            local preset=A.Entry(member.name).presets[member.preset or ""]
            if GroupEligible(member.name) and preset and preset.guid and preset.name==member.name and preset.realm==GetRealmName() then
                local item={name=member.name,label=member.preset,target=A.Copy(preset),mode="apply"}
                plan.items[#plan.items+1]=item
                if GroupUnit(item) then plan.ready[#plan.ready+1]=item else needsSummon=true end
            else
                GroupSkip(plan,member.name,"нет доступного альта или подходящего сохранённого набора.")
            end
        end
    end
    if A.gearRead then A.gearRead.pending=nil end
    if A.trade then A.trade.pendingRefresh=nil end
    if #plan.items>0 then local ok,why=A.PrepareGroupDismount(plan);if not ok then A.Status(why,true);A.Message(why);return false end end
    if not needsSummon then return BeginGroupApply(plan) end
    plan.ready={}
    plan.deadline=GetTime()+30*#plan.items+5
    A.groupAssembly=plan
    local progress="1/2 • «"..label.."»: проверяем состав ("..#plan.items..")."
    A.Status(progress)
    A.GroupNotice(progress)
    return true
end

function A.DeletePreset(name,label,expected)
    if A.job or #A.queue>0 or A.groupAssembly then return false,"Дождитесь завершения текущего действия или нажмите «Стоп».";end
    local e=A.Entry(name);local preset=e.presets[label or ""];
    if not preset then return false,"Набор уже удалён или не выбран.";end
    if expected and preset~=expected then return false,"Набор изменился. Выберите его и повторите удаление.";end
    e.presets[label]=nil;
    if e.selectedPreset==label then e.selectedPreset=false;end
    for mode,value in pairs(e.bindings) do if value==label then e.bindings[mode]=nil;end end
    local _,root=A.Storage();
    for context,db in pairs(root.groupSetups and root.groupSetups.contexts or {}) do
        if context:sub(1,#GetRealmName()+1)==GetRealmName().."|" then
            for _,group in pairs(db.profiles or {}) do for _,v in pairs(group.members or {}) do
                if A.Key(v.name)==A.Key(name) and v.preset==label then v.preset=nil;end
            end end
        end
    end
    return true;
end
function A.RenamePreset(name,oldLabel,newLabel)
    if A.job or #A.queue>0 then return false,"Дождитесь завершения текущего действия.";end
    newLabel=UnBotAccountAlts.Trim(newLabel or "");local e=A.Entry(name);
    if not e.presets[oldLabel or ""] then return false,"Выберите сохранённый набор.";end
    if newLabel=="" or #newLabel>80 or newLabel:find("[%c|]") then return false,"Введите короткое название набора.";end
    if newLabel~=oldLabel and e.presets[newLabel] then return false,"Набор с таким названием уже существует.";end
    if newLabel==oldLabel then return true,newLabel;end
    e.presets[newLabel]=e.presets[oldLabel];e.presets[oldLabel]=nil;e.selectedPreset=newLabel;
    for mode,value in pairs(e.bindings) do if value==oldLabel then e.bindings[mode]=newLabel;end end
    local _,root=A.Storage();
    for context,db in pairs(root.groupSetups and root.groupSetups.contexts or {}) do
        if context:sub(1,#GetRealmName()+1)==GetRealmName().."|" then
            for _,group in pairs(db.profiles or {}) do for _,v in pairs(group.members or {}) do if A.Key(v.name)==A.Key(name) and v.preset==oldLabel then v.preset=newLabel;end end end
        end
    end;return true,newLabel;
end
local previousSlash=SlashCmdList.UNBOTALTSETUPS;
SlashCmdList.UNBOTALTSETUPS=function(text)
    local label=tostring(text or ""):match("^group%s+(.+)$");
    if label then A.StartNamedGroup(UnBotAccountAlts.Trim(label));else previousSlash(text);end
end
end

-- Hide only controller-owned command replies. Event handlers still receive every response.
function A.QuietChat(event,message,author)
    local record=A.quietChat;
    if not record or GetTime()>record.untilAt or A.Key(author)~=record.name then return false;end
    if event=="CHAT_MSG_WHISPER_INFORM" then return message==record.command;end
    if event~="CHAT_MSG_WHISPER" then return false;end
    local text=tostring(message or "");
    if record.kind=="outfit_save" or record.kind=="outfit_apply" then
        return text:find("Setting outfit ",1,true)~=nil or text:find("Replacing current equip with outfit ",1,true)~=nil
            or text:find("Equipping ",1,true)~=nil or text:find("unequipped",1,true)~=nil;
    end
    if record.kind=="bags" or record.kind=="trade_bags" then
        return text:find("|Hitem:",1,true)~=nil or text:find("Inventory",1,true)~=nil;
    end
    if record.kind=="co" or record.kind=="nc" or record.kind=="strategy" then return text:find("Strategies:",1,true)~=nil;end
    if record.kind=="glyphs" then return text:find("Glyphs:",1,true)~=nil or text:find("No glyphs equipped",1,true)~=nil;end
    if record.kind=="spellbook" then return text:find("|Hspell:",1,true)~=nil;end
    if record.kind=="switch" then return text:find("Active first talent",1,true)~=nil or text:find("Active second talent",1,true)~=nil;end
    if record.kind=="talents" then return text:find("Applying ",1,true)~=nil;end
    return false;
end
if ChatFrame_AddMessageEventFilter then
    for _,event in ipairs({"CHAT_MSG_WHISPER","CHAT_MSG_WHISPER_INFORM"}) do
        ChatFrame_AddMessageEventFilter(event,function(_,kind,message,author) return A.QuietChat(kind,message,author);end);
    end
end

-- Equipment is published before the remaining read-only sections.
do
local A=UnBotAltSetups
function A.EquipmentSnapshot(unit)
    local snapshot={name=UnitName(unit),realm=GetRealmName(),guid=UnitGUID(unit),
        class=select(2,UnitClass(unit)),level=UnitLevel(unit),gear={},checkedAt=time()}
    for slot=1,19 do
        snapshot.gear[slot]=GetInventoryItemLink(unit,slot) or false
        if not snapshot.gear[slot] and GetInventoryItemTexture and GetInventoryItemTexture(unit,slot) then
            return nil,"Экипировка ещё загружается."
        end
    end
    return snapshot
end
function A.PublishProgressive(j,stage)
    local snapshot=j.snapshot
    snapshot.bags=A.Copy(j.bags or {})
    if j.bags then snapshot.bagsCheckedAt=time() end
    A.cache[A.Key(j.name)]=A.Copy(snapshot)
    if A.WarmItems then A.WarmItems(snapshot) end
    if A.selected~=j.name then return end
    if stage=="gear" then
        if A.dirty or (A.draftLabel and A.preservePresetOnRead and not A.viewCurrent) then return end
        A.draft=A.Copy(snapshot)
        j.readDraft=A.draft
        j.readGear=A.Copy(snapshot.gear)
    elseif stage=="bags" and A.draft then
        -- The available list includes worn items omitted from the previewed preset.
        A.draft.bags=A.ProjectGearBags(snapshot.bags,snapshot.gear,A.draft.gear or {})
    elseif j.readDraft and A.draft==j.readDraft then
        if stage=="talents" then
            for _,key in ipairs({"trees","spec","groups","level"}) do A.draft[key]=A.Copy(snapshot[key]) end
        elseif stage=="glyphs" then A.draft.glyphs=A.Copy(snapshot.glyphs)
        end
    end
    if A.Refresh then A.Refresh() end
end
local previousNext=A.Next
function A.Next(step)
    local j=A.job
    if not j or not j.progressive then return previousNext(step) end
    if step=="begin" then
        j.readStatus="Читаем надетые вещи."
        A.Inspect("progressive_gear")
    elseif step=="progressive_gear" then
        A.PublishProgressive(j,"gear")
        j.readStatus="Экипировка загружена. Читаем сумки."
        A.Send("bags","c","progressive_bags")
    elseif step=="progressive_bags" then
        if j.bagsUnknown then A.Finish(false,"Экипировка загружена, но сумки не прочитаны. Повторите обновление.");return end
        j.bags=A.Copy(j.answer)
        A.PublishProgressive(j,"bags")
        j.readStatus="Вещи и сумки загружены. Читаем таланты."
        A.Inspect("progressive_talents")
    elseif step=="progressive_talents" then
        A.PublishProgressive(j,"talents")
        j.readStatus="Вещи, сумки и таланты загружены. Читаем символы."
        A.Send("glyphs","glyphs","progressive_glyphs")
    elseif step=="progressive_glyphs" then
        j.snapshot.glyphs=A.Copy(j.answer)
        A.PublishProgressive(j,"glyphs")
        A.Finish(true,"Экипировка, сумки, таланты и символы загружены."..(A.dirty and " Ваши изменения в редакторе сохранены." or ""))
    else return previousNext(step)
    end
end
end

-- A gear-only action uses the recently read screen data and verifies its result.
do
local A=UnBotAltSetups
local function Recent(snapshot,j,bags)
    local stamp=snapshot and (bags and snapshot.bagsCheckedAt or snapshot.checkedAt)
    return snapshot and snapshot.guid==j.guid and snapshot.realm==GetRealmName()
        and snapshot.level==UnitLevel(UnBotAccountAlts.FindUnit(j.name))
        and type(stamp)=="number" and time()>=stamp and time()-stamp<=15
end
local function PrepareFastGear(j)
    local ok,why=A.PrepareSection(j)
    if ok then ok,why=A.Preflight(j,j.snapshot) end
    if not ok then A.Finish(false,why);return end
    j.target.fingerprint=A.Fingerprint(j.target.trees)
    j.gearBefore=A.Copy(j.snapshot.gear)
    j.next="gear_next"
end
function A.ProjectGearBags(original,before,after)
    local bags=A.Copy(original or {})
    for slot=1,19 do
        if A.ItemKey(before[slot])~=A.ItemKey(after[slot]) then
            if after[slot] then
                for index,link in ipairs(bags) do
                    if A.ItemKey(link)==A.ItemKey(after[slot]) then table.remove(bags,index);break end
                end
            end
            if before[slot] then
                local found=false
                for _,link in ipairs(bags) do if A.ItemKey(link)==A.ItemKey(before[slot]) then found=true end end
                if not found then bags[#bags+1]=before[slot] end
            end
        end
    end
    return bags
end
local previousNext=A.Next
function A.Next(step)
    local j=A.job
    if not j then return end
    if step=="begin" and j.fastGear then
        local cache=A.cache[A.Key(j.name)]
        if Recent(cache,j,false) and Recent(cache,j,true) and cache.trees and cache.glyphs then
            j.snapshot=A.Copy(cache);j.bags=A.Copy(cache.bags or {})
            PrepareFastGear(j)
        else
            j.gearReadCache=A.Copy(cache)
            A.Inspect("fast_gear_baseline")
        end
    elseif step=="fast_gear_baseline" then
        local cache=j.gearReadCache
        if cache and cache.guid==j.guid and cache.spec==j.snapshot.spec and cache.glyphs then
            j.snapshot.glyphs=A.Copy(cache.glyphs)
            j.next="fast_gear_bag_query"
        else A.Send("glyphs","glyphs","fast_gear_glyphs")
        end
    elseif step=="fast_gear_glyphs" then
        j.snapshot.glyphs=A.Copy(j.answer);j.next="fast_gear_bag_query"
    elseif step=="fast_gear_bag_query" then A.Send("bags","c","fast_gear_bags")
    elseif step=="fast_gear_bags" then
        if j.bagsUnknown then A.Finish(false,"Не удалось прочитать сумки. Обновите данные перед переодеванием.");return end
        j.bags=A.Copy(j.answer);j.snapshot.bags=A.Copy(j.bags);j.snapshot.bagsCheckedAt=time()
        A.cache[A.Key(j.name)]=A.Copy(j.snapshot)
        PrepareFastGear(j)
    elseif step=="fast_gear_commit" then
        -- The inspect result contains the gear and talents. Carry forward known glyphs.
        j.snapshot.glyphs=A.Copy(j.target.glyphs)
        j.bags=A.ProjectGearBags(j.bags,j.gearBefore,j.snapshot.gear)
        j.snapshot.bags=A.Copy(j.bags)
        j.snapshot.bagsCheckedAt=nil
        A.cache[A.Key(j.name)]=A.Copy(j.snapshot)
        local name,context=j.name,j.context
        A.CommitSection(j)
        if A.results[A.Key(name)] and A.results[A.Key(name)].ok then
            A.pendingGearBags={name=name,context=context,at=GetTime()+.3,deadline=GetTime()+20}
        end
    elseif step=="begin" and j.backgroundBags then A.Send("bags","c","gear_background_bags")
    elseif step=="gear_background_bags" then
        if j.bagsUnknown then
            A.Finish(false,"Экипировка применена, но сумки не обновлены.")
        else
            local cache=A.cache[A.Key(j.name)]
            if cache and cache.guid==j.guid then
                cache.bags=A.Copy(j.answer);cache.bagsCheckedAt=time()
                if A.selected==j.name and A.draft and A.draft.guid==j.guid then
                    A.draft.bags=A.ProjectGearBags(j.answer,cache.gear,A.draft.gear)
                end
            end
            A.Finish(true,"Экипировка готова. Сумки обновлены.")
        end
    else previousNext(step)
    end
end
local previousTick=A.Tick
function A.Tick()
    previousTick()
    local pending=A.pendingGearBags
    if not pending then return end
    if pending.context~=A.Context() or GetTime()>pending.deadline then A.pendingGearBags=nil;return end
    if GetTime()<pending.at or A.job or #A.queue>0 or A.Busy() then return end
    A.pendingGearBags=nil
    local unit=UnBotAccountAlts.FindUnit(pending.name)
    if not unit or not UnitIsConnected(unit) then return end
    A.Begin({name=pending.name,mode="gear_bags"})
    if A.job then
        A.job.backgroundBags=true;A.job.autoGearRead=true
        A.job.applyResult=A.Copy(A.results[A.Key(pending.name)])
    end
end
local previousFinish=A.Finish
function A.Finish(ok,text,all)
    local job=A.job
    previousFinish(ok,text,all)
    if job and job.backgroundBags and job.applyResult then
        A.results[A.Key(job.name)]=job.applyResult
    end
end
local previousStop=A.Stop
function A.Stop(reason) A.pendingGearBags=nil;return previousStop(reason) end
end

-- Named presets mirror a Playerbots outfit. Applying a preset invokes one replace action.
do
local A=UnBotAltSetups
function A.OutfitDefinition(name,label,preset)
    local old=preset.serverOutfit;
    local definition=type(old)=="table" and A.Copy(old) or {};
    if type(definition.name)~="string" or not definition.name:match("^ubc_[%x_]+$") then
        local hash=5381;
        local text=A.Context().."|"..name.."|"..tostring(label);
        for index=1,#text do hash=(hash*33+text:byte(index))%2147483647;end
        local guid=tostring(preset.guid or ""):gsub("[^%x]",""):sub(-8);
        definition.name="ubc_"..guid.."_"..string.format("%08x",hash);
    end
    local ids,seen={},{};
    for slot=1,19 do local id=A.ItemID(preset.gear and preset.gear[slot]);if id and not seen[id] then ids[#ids+1]=id;seen[id]=true;end end
    table.sort(ids);definition.signature=table.concat(ids,",");
    return definition;
end
function A.MarkOutfitSaved(job)
    local definition=job.outfitDefinition;
    local preset=A.Entry(job.name).presets[job.label];
    if not preset or not definition then return;end
    local current=A.OutfitDefinition(job.name,job.label,preset);
    if current.name==definition.name and current.signature==definition.signature then
        current.syncedAt=time();current.syncedSignature=definition.signature;preset.serverOutfit=current;
    end
end
function A.RequestOutfitSave(name,label)
    A.pendingOutfitSave={name=name,label=label,context=A.Context(),deadline=GetTime()+20,at=GetTime()+.3};
end
local previousNext=A.Next
function A.Next(step)
    local job=A.job;
    if job and job.mode=="outfit_save" and step=="begin" then
        local current=A.Entry(job.name).presets[job.label];
        if current~=job.presetReference then A.Finish(false,"Набор изменился. Сохраните его заново.");return;end
        local definition=job.outfitDefinition;
        A.Send("outfit_save","outfit "..definition.name.."="..definition.signature,"outfit_saved",false);
    elseif job and job.mode=="outfit_save" and step=="outfit_saved" then
        A.Finish(true,"Аутфит «"..job.label.."» сохранён на сервере. Экипировка не менялась.");
    else previousNext(step);end
end
local previousTick=A.Tick
function A.Tick()
    previousTick();
    local pending=A.pendingOutfitSave;if not pending then return;end
    if pending.context~=A.Context() or GetTime()>pending.deadline then A.pendingOutfitSave=nil;return;end
    if GetTime()<pending.at or A.job or #A.queue>0 or A.Busy() then return;end
    A.pendingOutfitSave=nil;
    local unit=UnBotAccountAlts.FindUnit(pending.name);
    local preset=A.Entry(pending.name).presets[pending.label];
    if not preset or not unit or not UnitIsConnected(unit) or UnitGUID(unit)~=preset.guid
        or not UnBotAccountAlts.IsListed(pending.name) or not UnBotAccountAlts.IsEnabled(pending.name) then return;end
    A.Begin({name=pending.name,label=pending.label,mode="outfit_save"});
    if A.job then A.job.presetReference=preset;A.job.outfitDefinition=A.OutfitDefinition(pending.name,pending.label,preset);end
end
local previousStop=A.Stop
function A.Stop(reason) A.pendingOutfitSave=nil;return previousStop(reason);end
end


-- Plan only the sections whose observed state differs from the requested preset.
do
local A=UnBotAltSetups
A.verifiedParts={}
local function SameRules(wanted,actual)
    if not actual then return false end
    for id,value in pairs(wanted or {}) do if (actual[id]==true)~=value then return false end end
    return true
end
local function Continue(j)
    j.next="selective_spells"
end
local function Plan(j)
    local s,p=j.snapshot,j.target
    j.changed={spec=s.spec~=p.spec,talents=s.spec~=p.spec or A.Fingerprint(s.trees)~=A.Fingerprint(p.trees),gear=false,spells=false}
    for slot=1,19 do if not A.GearMatches(p.gear[slot],s.gear[slot]) then j.changed.gear=true;break end end
    local known=A.verifiedParts[A.Key(j.name)]
    if known and (known.context~=j.context or known.guid~=j.guid or time()<known.at or time()-known.at>15) then known=nil end
    j.changed.spells=p.spellRules and next(p.spellRules)~=nil and not SameRules(p.spellRules,known and known.rules) or false
    j.target.fingerprint=A.Fingerprint(p.trees)
    j.needPersonal=j.personal and j.changed.talents
    if j.changed.gear then A.Send("bags","c","selective_bags") else j.next="selective_preflight" end
end
local previousNext=A.Next
function A.Next(step)
    local j=A.job
    if not j then return end
    if step=="begin" and (j.mode=="apply" or (j.mode=="section" and j.section~="gear")) then
        j.selective=true;j.cached=A.Copy(A.cache[A.Key(j.name)])
        A.Inspect("selective_baseline")
    elseif not j.selective then return previousNext(step)
    elseif step=="selective_baseline" then
        j.before=A.Copy(j.snapshot)
        j.bags=A.Copy(j.cached and j.cached.guid==j.guid and j.cached.bags or {})
        if j.cached and j.cached.guid==j.guid and j.cached.spec==j.snapshot.spec
            and type(j.cached.checkedAt)=="number" and time()>=j.cached.checkedAt and time()-j.cached.checkedAt<=15 then j.snapshot.glyphs=A.Copy(j.cached.glyphs) end
        if j.mode=="section" then
            local ok,why=A.PrepareSection(j);if not ok then A.Finish(false,why);return end
            if not j.target.glyphs then j.target.glyphs=A.Copy(j.sectionDraft.glyphs or {}) end
        end
        Plan(j)
    elseif step=="selective_bags" then
        if j.bagsUnknown then A.Finish(false,"Не удалось прочитать сумки. Экипировка не менялась.");return end
        j.bags=A.Copy(j.answer);j.snapshot.bagsCheckedAt=time();j.next="selective_preflight"
    elseif step=="selective_preflight" then
        local ok,why=A.Preflight(j,j.snapshot);if not ok then A.Finish(false,why);return end
        -- A section changes only its own part, even if unrelated cached spell rules exist.
        if j.mode=="section" and j.section~="spells" then j.changed.spells=false end
        if j.changed.spec then A.Send("switch","talents switch "..j.target.spec,"switch_done",true)
        elseif j.changed.talents or not j.snapshot.glyphs then A.Send("glyphs","glyphs","selective_glyphs")
        else
            if A.GlyphKey(j.snapshot.glyphs)~=A.GlyphKey(j.target.glyphs) then A.Finish(false,"Символы не совпадают с набором. Проверьте выбранный спек и символы альта.");return end
            j.next="gear_plan"
        end
    elseif step=="target_inspected" then
        if j.snapshot.spec~=j.target.spec then A.Finish(false,"Сервер не подтвердил смену спека.");return end
        A.Send("glyphs","glyphs","selective_glyphs")
    elseif step=="selective_glyphs" then
        j.snapshot.glyphs=A.Copy(j.answer);j.knownGlyphs=A.Copy(j.answer)
        if A.GlyphKey(j.answer)~=A.GlyphKey(j.target.glyphs) then A.Finish(false,"Символы не совпадают с набором. Настройте их, войдя за альта.");return end
        A.PlanTalents(j)
    elseif step=="gear_plan" then
        if j.changed.gear then
            local ok,why=A.BuildGear(j);if not ok then A.Finish(false,why);return end
            j.next="gear_next"
        else Continue(j) end
    elseif step=="gear_verified" then
        -- Reuse the existing full slot verification, without its unrelated follow-up queries.
        local fast=j.fastGear;j.fastGear=true;previousNext(step)
        if A.job==j then j.fastGear=fast;Continue(j) end
    elseif step=="selective_spells" then
        if j.changed.spells then j.next="spell_apply_read" else j.next="selective_personal" end
    elseif step=="spell_apply_next" and j.spellSteps and #j.spellSteps==0 then
        j.answer=j.spellBefore;j.next="spell_apply_verified"
    elseif step=="spell_apply_verified" then
        if not A.spells.Same(j.spellExpected,j.answer) then A.Finish(false,"Запреты заклинаний не совпали с ожидаемыми. Автоматического повтора не будет.");return end
        j.verifiedRules=A.Copy(j.answer)
        local book=A.Entry(j.name).spellbook;if book and book.guid==j.guid then book.ignored=A.Copy(j.answer) end
        j.next="selective_personal"
    elseif step=="selective_personal" then
        if j.needPersonal then A.Send("co","co ?","personal_co") else j.next="final_glyphs" end
    elseif step=="final_glyphs" then
        if j.changed.talents then A.Send("glyphs","glyphs","selective_final_glyphs")
        else j.finalGlyphs=A.Copy(j.snapshot.glyphs or j.knownGlyphs or j.target.glyphs);j.next="selective_complete" end
    elseif step=="selective_final_glyphs" then
        if A.GlyphKey(j.answer)~=A.GlyphKey(j.target.glyphs) then A.Finish(false,"После смены талантов символы изменились. Проверьте их, войдя за альта.");return end
        j.finalGlyphs=A.Copy(j.answer);j.next="selective_complete"
    elseif step=="selective_complete" then
        if j.changed.gear and not j.finalBagsRead then
            j.finalBagsRead=true;A.Send("bags","c","selective_final_bags");return
        end
        if j.verifiedRules then A.verifiedParts[A.Key(j.name)]={guid=j.guid,context=j.context,at=time(),rules=A.Copy(j.verifiedRules)} end
        j.snapshot.glyphs=A.Copy(j.finalGlyphs);j.snapshot.bags=A.Copy(j.bags)
        if not j.changed.gear then j.gearIntent=A.Copy(j.target.gear) end
        j.answer=j.bags;previousNext("complete")
    elseif step=="selective_final_bags" then
        if j.bagsUnknown then A.Finish(false,"Экипировка применена, но сумки не обновились. Обновите данные альта.");return end
        j.bags=A.Copy(j.answer);j.snapshot.bagsCheckedAt=time();j.next="selective_complete"
    else return previousNext(step) end
end
local previousFinish=A.Finish
function A.Finish(ok,text,all)
    local j=A.job
    if j and j.selective then
        if not ok then
            A.verifiedParts[A.Key(j.name)]=nil
            local cache=A.cache[A.Key(j.name)];if cache then cache.checkedAt=nil end
        elseif j.mode=="apply" and j.changed then
            local parts={}
            if j.changed.spec then parts[#parts+1]="спек" end
            if j.changed.talents then parts[#parts+1]="таланты" end
            if j.changed.gear then parts[#parts+1]="экипировка" end
            if j.changed.spells then parts[#parts+1]="запреты заклинаний" end
            text=#parts>0 and ("Набор «"..j.label.."» применён. Проверены изменения: "..table.concat(parts,", ")..".") or ("Альт уже соответствует набору «"..j.label.."». Изменения не требуются.")
        end
    end
    return previousFinish(ok,text,all)
end
end


-- Explicit recovery for items left unequipped by earlier addon versions. New enchant requests never unequip.
do
local A=UnBotAltSetups
local T=A.trade
local function Cache(j)
    local snapshot=A.Copy(j.snapshot)
    snapshot.bags={}
    for _,row in ipairs(j.bagRows or {}) do snapshot.bags[#snapshot.bags+1]=row.link end
    snapshot.bagsCheckedAt=time();A.cache[A.Key(j.name)]=snapshot
    T.bags[A.Key(j.name)]={guid=j.guid,at=GetTime(),rows=A.Copy(j.bagRows or {})}
end
local function ClearReturn(j)
    local entry=A.Entry(j.name);local pending=entry.pendingEnchantReturn
    if pending and pending.token==j.enchantReturn.token and pending.guid==j.guid then entry.pendingEnchantReturn=nil end
end
local function EndReturn(j)
    Cache(j);ClearReturn(j)
    local outcome=j.enchantOutcome or {ok=true,text="Вещь возвращена в экипировку."}
    j.enchantReturn=nil;j.enchantRestoring=nil
    A.Finish(outcome.ok,outcome.text.." Вещь надета обратно.",outcome.all)
end
local function ReturnInspect(j)
    j.tradePhase=nil;T.Stop();T.active=nil;j.wait=nil;j.next=nil
    j.enchantRestoring=true;j.deadline=GetTime()+75
    A.Status(j.name..": возвращаем вещь после зачарования...")
    if j.enchantSettleUntil and GetTime()<j.enchantSettleUntil then j.next="enchant_return_settle"
    else A.Inspect("enchant_return_inspected") end
end
local previousOpen=T.Open
function T.Open(j)
    if A.Entry(j.name).pendingEnchantReturn then
        A.Finish(false,"Сначала верните ранее снятую вещь кнопкой «Вернуть вещь».");return
    end
    return previousOpen(j)
end
local previousNext=A.Next
function A.Next(step)
    local j=A.job;if not j then return end
    if step=="begin" and j.mode=="trade_restore" then ReturnInspect(j)
    elseif step=="enchant_return_settle" then
        if GetTime()<j.enchantSettleUntil then j.next="enchant_return_settle" else A.Inspect("enchant_return_inspected") end
    elseif step=="enchant_return_inspected" then
        local record=j.enchantReturn;local current=j.snapshot.gear[record.slot]
        if current then
            if A.ItemID(current)~=record.id then A.Finish(false,"Исходная ячейка занята другой вещью. Автоматически заменять её не буду.");return end
            A.Send("trade_bags","c","enchant_return_already_bags")
        else
            for slot=1,19 do if A.ItemID(j.snapshot.gear[slot])==record.id then
                A.Finish(false,"Вещь уже надета в другой ячейке. Верните её в исходную ячейку вручную.");return
            end end
            A.Send("trade_bags","c","enchant_return_bags")
        end
    elseif step=="enchant_return_already_bags" then
        j.bagRows=A.Copy(j.answer)
        for _,row in ipairs(j.bagRows) do if row.id==j.enchantReturn.id then
            A.Finish(false,"В ячейке и сумке есть одинаковые вещи. Верните нужный экземпляр вручную.");return
        end end
        EndReturn(j)
    elseif step=="enchant_return_bags" then
        j.bagRows=A.Copy(j.answer);local record=j.enchantReturn;local count=0
        for _,row in ipairs(j.bagRows) do if row.id==record.id then count=count+(row.count or 1) end end
        for slot=1,19 do if A.ItemID(j.snapshot.gear[slot])==record.id then count=count+1 end end
        if count~=1 then A.Finish(false,"Не удалось однозначно найти снятую вещь для возврата.");return end
        local _,link=GetItemInfo(tostring(record.id))
        if type(link)~="string" or A.ItemID(link)~=record.id then A.Finish(false,"Не загрузилась ссылка для возврата вещи.");return end
        local prefix=record.slot==16 and "mh " or record.slot==17 and "oh " or ""
        A.Send("gear","e "..prefix..link,"enchant_return_equipped",true)
    elseif step=="enchant_return_equipped" then A.Inspect("enchant_return_verified")
    elseif step=="enchant_return_verified" then
        if A.ItemID(j.snapshot.gear[j.enchantReturn.slot])~=j.enchantReturn.id then A.Finish(false,"Сервер не подтвердил возврат вещи в исходную ячейку.");return end
        A.Send("trade_bags","c","enchant_return_bags_done")
    elseif step=="enchant_return_bags_done" then j.bagRows=A.Copy(j.answer);EndReturn(j)
    else return previousNext(step) end
end
local previousFinish=A.Finish
function A.Finish(ok,text,all)
    local j=A.job
    if j and j.enchantReturn then
        if not j.enchantRestoring then
            j.enchantOutcome={ok=ok,text=text,all=all}
            local wait=j.wait
            if wait and wait.sent and wait.mutation then j.enchantSettleUntil=(wait.sentAt or GetTime())+10 end
            ReturnInspect(j);return
        else
            text=tostring(text).." Снятая вещь ещё не возвращена. После устранения причины нажмите «Вернуть вещь» во вкладке «Обмен»."
        end
    end
    return previousFinish(ok,text,all)
end
function T.RestorePending()
    if A.job or #A.queue>0 or A.Busy() then A.Status("Дождитесь завершения текущего действия.",true);return end
    local name=A.selected;local record=name and A.Entry(name).pendingEnchantReturn
    local unit=name and UnBotAccountAlts.FindUnit(name)
    if not record then A.Status("Нет снятой вещи, ожидающей возврата.");return end
    if record.context~=A.Context() or record.realm~=GetRealmName() or not unit or UnitGUID(unit)~=record.guid then A.Status("Для возврата нужен тот же альт в вашей группе.",true);return end
    if TradeFrame and TradeFrame:IsShown() then A.Status("Закройте обмен перед возвратом вещи.",true);return end
    A.Begin({name=name,mode="trade_restore"})
    if A.job then A.job.enchantReturn=A.Copy(record);A.job.enchantOutcome={ok=true,text="Возврат вещи завершён."} end
end
end


-- Confirm the bot's inventory again after its native trade-opening replies have settled.
do
local A=UnBotAltSetups
local T=A.trade
local originalEvent=T.frame:GetScript("OnEvent")
T.frame:SetScript("OnEvent",function(self,event,...)
    local current=A.job
    if event=="TRADE_SHOW" and current and current.mode=="trade" and current.opened then return end
    originalEvent(self,event,...)
    local j=A.job
    if event~="TRADE_SHOW" or not j or j.mode~="trade" or not j.opened then return end
    for _,item in ipairs(j.cart or {}) do if item.bound then
        j.tradePhase="opening_ready";j.tradeReadyAt=GetTime()+1.5;j.tradeReadyDeadline=GetTime()+8;j.tradeLastReply=GetTime()
        j.next="enchant_open_ready";break
    end end
end)
local previousReply=A.Reply
function A.Reply(message,sender,system)
    local j=A.job
    if j and j.tradePhase=="opening_ready" and not system and UnBotAccountAlts.SenderKey(sender)==A.Key(j.name) then
        j.tradeLastReply=GetTime();A.Log(j,"trade_open_reply",tostring(message))
    end
    return previousReply(message,sender,system)
end
local previousNext=A.Next
function A.Next(step)
    local j=A.job;if not j then return end
    if step=="enchant_open_ready" then
        if GetTime()>j.tradeReadyDeadline then A.Finish(false,"Бот не завершил подготовку обмена. Запрос вещи не отправлялся.");return end
        if GetTime()<j.tradeReadyAt or GetTime()<(j.tradeLastReply or 0)+.5 then j.next=step;return end
        j.tradePhase="building";A.Send("trade_bags","c","enchant_open_inventory")
    elseif step=="enchant_open_inventory" then
        j.bagRows=A.Copy(j.answer)
        T.bags[A.Key(j.name)]={guid=j.guid,at=GetTime(),rows=A.Copy(j.bagRows)}
        local ok,why=T.Validate(j);if not ok then A.Finish(false,why);return end
        A.Log(j,"trade_open_inventory","rows="..#j.bagRows)
        j.next="trade_request_next"
    else return previousNext(step) end
end
end

-- Observed state is separate from editable presets. Opening UI never queries the bot.
do
local A=UnBotAltSetups
A.stateFlags={}
function A.TalentStateText(snapshot)
    if not snapshot then return "нет данных" end
    local counts={};local main,most=nil,0
    for _,tree in ipairs(snapshot.trees or {}) do
        local total=0;for _,talent in ipairs(tree.talents or {}) do total=total+(talent.rank or 0) end
        counts[#counts+1]=tostring(total);if total>most then main,most=tree.name,total end
    end
    return "спек №"..tostring(snapshot.spec or "…")..(main and (", "..main) or "")..(#counts>0 and (" ("..table.concat(counts,"/")..")") or "")
end
local fields={gear={"gear"},talents={"trees","spec","groups","level"},glyphs={"glyphs"},bags={"bags","bagsCheckedAt"},spells={"spellRules"}}
function A.ObserveState(name,snapshot,parts)
    if not snapshot or not snapshot.guid or snapshot.realm~=GetRealmName() or A.Key(snapshot.name)~=A.Key(name) then return end
    local e=A.Entry(name);local saved=e.observedState
    if type(saved)~="table" or not saved.snapshot or saved.snapshot.guid~=snapshot.guid then saved={schema=1,snapshot={},parts={}};e.observedState=saved end
    saved.parts=saved.parts or {};local out=saved.snapshot
    for _,k in ipairs({"name","realm","guid","class","level"}) do out[k]=snapshot[k] end
    local flags=A.stateFlags[A.Key(name)] or {};A.stateFlags[A.Key(name)]=flags
    for part in pairs(parts or {}) do
        for _,k in ipairs(fields[part] or {}) do out[k]=A.Copy(snapshot[k]) end
        saved.parts[part]=time();flags[part]="loaded"
    end
    out.checkedAt=snapshot.checkedAt or time();saved.updatedAt=time()
end
function A.RestoreObserved(name)
    local saved=A.Entry(name).observedState
    if not saved or not saved.snapshot or saved.snapshot.realm~=GetRealmName() then return end
    local key=A.Key(name);local unit=UnBotAccountAlts.FindUnit(name)
    if unit and UnitGUID(unit)~=saved.snapshot.guid then A.stateFlags[key]={};return end
    if not A.cache[key] then
        A.cache[key]=A.Copy(saved.snapshot);A.cache[key].checkedAt=nil;A.cache[key].bagsCheckedAt=nil
        local flags={};for part in pairs(saved.parts or {}) do flags[part]="stale" end;A.stateFlags[key]=flags
        if saved.tradeRows then A.trade.bags[key]={guid=saved.snapshot.guid,rows=A.Copy(saved.tradeRows),at=0} end
    end
end
function A.InvalidateState(name,parts)
    local key=A.Key(name);local flags=A.stateFlags[key] or {};A.stateFlags[key]=flags
    for part in pairs(parts or fields) do flags[part]="stale" end
    local cache=A.cache[key];if cache then cache.checkedAt=nil;cache.bagsCheckedAt=nil end
end
function A.StateCaption(name)
    local part=({"gear","talents","glyphs","spells","bags"})[A.tab or 1]
    local flag=part and (A.stateFlags[A.Key(name)] or {})[part]
    return flag=="loaded" and "Данные загружены; обновление вручную." or flag=="stale" and "Данные сохранены; актуальность не проверена." or "Нажмите кнопку обновления для загрузки."
end
local previousPublish=A.PublishProgressive
function A.PublishProgressive(j,stage)
    previousPublish(j,stage)
    A.ObserveState(j.name,j.snapshot,{[stage=="gear" and "gear" or stage]=true})
end
local previousSend=A.Send
function A.Send(kind,command,after,mutation)
    local j=A.job
    if j and mutation then
        local parts=(kind=="switch" or kind=="talents") and {talents=true,glyphs=true,spells=true}
            or kind=="spell_change" and {spells=true} or {gear=true,bags=true}
        A.InvalidateState(j.name,parts)
    end
    return previousSend(kind,command,after,mutation)
end
local function PublishRecovery(j)
    local r=j.stateRecovery
    A.ObserveState(j.name,j.snapshot,r.observed)
    local saved=A.Entry(j.name).observedState
    if saved then A.cache[A.Key(j.name)]=A.Copy(saved.snapshot) end
    if A.selected==j.name and not A.dirty and not A.draftLabel then A.draft=A.Copy(A.cache[A.Key(j.name)]) end
    r.complete=true
    A.Finish(false,r.reason.." Актуальное состояние альта перечитано. Команды изменения повторно не отправлялись.")
    if A.Refresh then A.Refresh() end
end
local function RecoveryNext(j)
    local r=j.stateRecovery
    if r.bags then r.bags=nil;A.Send("trade_bags","c","state_recovery_bags")
    elseif r.glyphs then r.glyphs=nil;A.Send("glyphs","glyphs","state_recovery_glyphs")
    elseif r.spells then r.spells=nil;A.Send("ignored","ss ?","state_recovery_spells")
    else PublishRecovery(j) end
end
local previousNext=A.Next
function A.Next(step)
    local j=A.job
    if not j or not j.stateRecovery then return previousNext(step) end
    if step=="state_recovery_begin" then A.Inspect("state_recovery_inspected")
    elseif step=="state_recovery_inspected" then
        j.stateRecovery.observed={gear=true,talents=true}
        A.ObserveState(j.name,j.snapshot,j.stateRecovery.observed)
        A.cache[A.Key(j.name)]=A.Copy(A.Entry(j.name).observedState.snapshot)
        RecoveryNext(j)
    elseif step=="state_recovery_bags" then
        if j.bagsUnknown then A.Finish(false,"Не удалось перечитать сумки.");return end
        j.snapshot.bags={};for _,row in ipairs(j.answer or {}) do j.snapshot.bags[#j.snapshot.bags+1]=row.link end
        j.snapshot.bagsCheckedAt=time();A.trade.bags[A.Key(j.name)]={guid=j.guid,at=GetTime(),rows=A.Copy(j.answer)}
        A.ObserveState(j.name,j.snapshot,{bags=true})
        A.Entry(j.name).observedState.tradeRows=A.Copy(j.answer);j.stateRecovery.observed.bags=true;RecoveryNext(j)
    elseif step=="state_recovery_glyphs" then j.snapshot.glyphs=A.Copy(j.answer);j.stateRecovery.observed.glyphs=true;RecoveryNext(j)
    elseif step=="state_recovery_spells" then
        j.snapshot.spellRules=A.Copy(j.answer);j.stateRecovery.observed.spells=true
        local book=A.Entry(j.name).spellbook;if book and book.guid==j.guid then book.ignored=A.Copy(j.answer) end
        RecoveryNext(j)
    else A.Finish(false,"Не удалось завершить сверку состояния.") end
end
local previousFinish=A.Finish
function A.Finish(ok,text,all)
    local j=A.job
    if j and j.stateRecovery then
        if not j.stateRecovery.complete then
            A.InvalidateState(j.name)
            text=j.stateRecovery.reason.." Перечитать актуальное состояние не удалось: "..tostring(text)
        end
        return previousFinish(false,text,all)
    end
    if j and not ok then
        A.InvalidateState(j.name)
        local eligible=j.mode=="apply" or j.mode=="section" or j.mode=="slot" or j.mode=="trade"
        if eligible and not all and not j.enchantReturn and not A.trade.stopping and not A.Busy(true) and A.Ready(j) then
            local mode,section=j.mode,j.section
            A.ReleaseInspect(j);if mode=="trade" then A.trade.Stop() end
            j.stateRecovery={reason=tostring(text),stage=A.FailureStage(j),bags=mode=="apply" or mode=="trade" or section=="gear",
                glyphs=mode=="apply" or mode=="slot" or section=="talents",spells=mode=="apply" or section=="spells"}
            j.mode="state_recovery";j.selective=nil;j.fastGear=nil;j.progressive=nil;j.wait=nil;j.next="state_recovery_begin";j.deadline=GetTime()+55
            A.notifying=false;A.Log(j,"reconcile",tostring(text));A.Status(j.name..": проверяем актуальность данных после ошибки...")
            return
        end
    elseif j and ok then
        local snapshot=A.Copy(A.cache[A.Key(j.name)] or j.snapshot)
        if snapshot then
            if j.bagRows then
                snapshot.bags={};for _,row in ipairs(j.bagRows) do snapshot.bags[#snapshot.bags+1]=row.link end
                snapshot.bagsCheckedAt=time();A.cache[A.Key(j.name)]=A.Copy(snapshot)
            end
            local parts={};if snapshot.gear then parts.gear=true end
            if snapshot.trees then parts.talents=true end
            if snapshot.glyphs then parts.glyphs=true end
            if snapshot.bagsCheckedAt then parts.bags=true end
            if snapshot.spellRules then parts.spells=true end
            A.ObserveState(j.name,snapshot,parts)
            if j.bagRows then A.Entry(j.name).observedState.tradeRows=A.Copy(j.bagRows) end
        end
        if j.mode=="spells" then
            local flags=A.stateFlags[A.Key(j.name)] or {};A.stateFlags[A.Key(j.name)]=flags;flags.spells="loaded"
            local e=A.Entry(j.name);local saved=e.observedState;local book=e.spellbook
            if saved and book and saved.snapshot.guid==book.guid then
                saved.parts.spells=time();saved.snapshot.spellRules=A.Copy(book.ignored)
            end
        end
    end
    return previousFinish(ok,text,all)
end
-- A zone change invalidates confidence, not the last observed display data.
local oldEvent=A.frame:GetScript("OnEvent")
A.frame:SetScript("OnEvent",function(self,event,...)
    if event=="PLAYER_ENTERING_WORLD" then
        for _,name in ipairs(A.Names()) do A.InvalidateState(name) end
    end
    return oldEvent(self,event,...)
end)
end

-- Named compositions share a finite command scheduler and one inspect lease.
do
local A=UnBotAltSetups
local oldTick,oldFinish,oldStop=A.Tick,A.Finish,A.Stop
local oldReply,oldInspect,oldInspectReady=A.Reply,A.Inspect,A.InspectReady
local oldBusy,oldQuiet=A.Busy,A.QuietChat
local Fill
local function Representative(p)
    if p.inspectOwner and p.active[p.inspectOwner.id] then return p.inspectOwner end
    for _,j in pairs(p.active) do return j end
end
local function Progress(p)
    local text="«"..p.label.."»: проверено "..p.done.." из "..p.total..", ошибок "..p.failed.."; одновременно до "..p.limit.." альтов."
    if text~=p.lastText then p.lastText=text;A.Status(text,p.failed>0);A.GroupNotice(text) end
end
local function EndGroup(p,cancelled)
    if p.closed then return end
    p.closed=true;A.parallelGroup=nil;A.job=nil;A.groupResult=nil;A.queue={}
    A.nextSend=math.max(A.nextSend or 0,p.nextExternal or 0)
    local good=not cancelled and p.failed==0 and p.skipped==0 and p.done==p.total
    local text=good and ("Группа «"..p.label.."» готова. Наборы применены и проверены у "..p.ok.." из "..p.total.." альтов.")
        or ("Группа «"..p.label.."» "..(cancelled and "остановлена" or "обработана")..". Подтверждено "..p.ok..", ошибок "..p.failed..", пропущено "..p.skipped..".")
    A.Message(text);A.GroupNotice(text);A.Status(A.ReportGroupFailures(p,text),not good)
end
function A.RunParallelJob(j,fn)
    local p=A.parallelGroup
    if not p or not j then return fn() end
    local savedJob,savedGroup,savedSend,savedQuiet=A.job,A.groupResult,A.nextSend,A.quietChat
    A.job=j;A.groupResult=nil;A.nextSend=j.parallelNextSend or 0;A.quietChat=j.parallelQuiet
    local ok,answer=pcall(fn)
    j.parallelNextSend=A.nextSend;j.parallelQuiet=A.quietChat
    p.nextExternal=math.max(p.nextExternal or 0,j.parallelNextSend or 0)
    if not ok then A.Finish(false,"Внутренняя ошибка применения: "..tostring(answer),true) end
    if p.inspectOwner==j and (not j.wait or j.wait.kind~="inspect" or not p.active[j.id]) then p.inspectOwner=nil end
    A.nextSend=savedSend;A.quietChat=savedQuiet;A.groupResult=savedGroup
    A.job=savedJob and p.active[savedJob.id] and savedJob or Representative(p)
    return ok and answer
end
function A.StartParallelGroup(plan)
    if A.parallelGroup then return false end
    local items,seenNames,seenGuids={}, {}, {}
    local failureDetails=A.Copy(plan.failureDetails or {})
    local skipped=plan.skipped or 0
    for _,item in ipairs(plan.ready) do
        local key=A.Key(item.name);local guid=item.target and item.target.guid
        if not seenNames[key] and guid and not seenGuids[guid] then
            seenNames[key]=true;seenGuids[guid]=true;items[#items+1]=A.Copy(item)
        else skipped=skipped+1;failureDetails[key]={name=item.name,reason="Повторное назначение имени или GUID пропущено.",stage="подготовка состава"};A.Message(item.name..": повторное назначение пропущено.") end
    end
    local p={label=plan.label,context=plan.context or A.Context(),playerDismountGate=A.Copy(plan.playerDismountGate),pending=items,index=1,active={},byName={},
        limit=3,total=#items,done=0,ok=0,failed=0,skipped=skipped,failureDetails=failureDetails,nextSend=GetTime(),
        deadline=GetTime()+180*math.ceil(#items/3)+30}
    p.nextSend=math.max(p.nextSend,A.nextSend or 0)
    A.parallelGroup=p;A.groupAssembly=nil;A.queue={};A.groupResult=nil
    if p.total==0 then EndGroup(p,false);return false end
    Progress(p);Fill(p)
    if not next(p.active) then EndGroup(p,false);return false end
    return true
end
function A.Busy(ignoreGroup)
    return (not ignoreGroup and A.parallelGroup~=nil) or oldBusy(ignoreGroup)
end
function A.Inspect(after)
    local j=A.job;local p=A.parallelGroup
    if not p or not j or j.parallelGroup~=p then return oldInspect(after) end
    if p.inspectOwner and p.inspectOwner~=j then j.parallelInspect=after;j.next=nil;return end
    p.inspectOwner=j;j.parallelInspect=nil;return oldInspect(after)
end
function A.ParallelInspectConflict(j,reason)
    if A.parallelGroup and j.parallelGroup==A.parallelGroup then
        return A.RunParallelJob(j,function() A.Finish(false,reason) end)
    end
    return A.Finish(false,reason)
end
function A.InspectReady()
    local p=A.parallelGroup
    if not p then return oldInspectReady() end
    local j=p.inspectOwner
    if j and p.active[j.id] then return A.RunParallelJob(j,oldInspectReady) end
end
function A.Reply(message,sender,system)
    local p=A.parallelGroup
    if not p then return oldReply(message,sender,system) end
    local j
    if not system then j=p.byName[UnBotAccountAlts.SenderKey(sender)]
    else
        for _,candidate in pairs(p.active) do
            if tostring(message):find(candidate.name,1,true) then if j then return end;j=candidate end
        end
    end
    if j then return A.RunParallelJob(j,function() oldReply(message,sender,system) end) end
end
function A.QuietChat(event,message,author)
    local p=A.parallelGroup
    local j=p and p.byName[UnBotAccountAlts.SenderKey(author)]
    if not j then return oldQuiet(event,message,author) end
    local saved=A.quietChat;A.quietChat=j.parallelQuiet
    local result=oldQuiet(event,message,author);A.quietChat=saved;return result
end
function A.Finish(ok,text,all)
    local p=A.parallelGroup;local j=A.job
    if not p or not j or j.parallelGroup~=p then return oldFinish(ok,text,all) end
    local saved=A.groupResult;A.groupResult=nil
    local wasRecovering=j.stateRecovery
    oldFinish(ok,text,all)
    if j.stateRecovery and not wasRecovering then j.parallelInspect=nil end
    A.groupResult=saved
    if A.job~=j then
        p.active[j.id]=nil;p.byName[A.Key(j.name)]=nil
        if p.inspectOwner==j then p.inspectOwner=nil end
        local result=A.results[A.Key(j.name)]
        p.done=p.done+1;if result and result.ok then p.ok=p.ok+1 else p.failed=p.failed+1;A.RecordGroupFailure(p,j.name,result and result.text or text,result and result.stage or A.FailureStage(j));end
        if not p.stopping then Progress(p) end
    end
end
function A.Stop(reason)
    local p=A.parallelGroup
    if not p then return oldStop(reason) end
    p.stopping=true
    for index=p.index,#p.pending do local item=p.pending[index];A.RecordGroupFailure(p,item.name,reason or "Применение остановлено до начала работы с этим альтом.","ожидание применения");end
    p.skipped=p.skipped+math.max(0,#p.pending-p.index+1);p.index=#p.pending+1
    local jobs={};for _,j in pairs(p.active) do jobs[#jobs+1]=j end
    for _,j in ipairs(jobs) do
        A.RunParallelJob(j,function() oldStop(reason or "Параллельное применение остановлено. Уже выполненные изменения сохранены.") end)
    end
    EndGroup(p,true)
end
Fill=function(p)
    local count=0;for _ in pairs(p.active) do count=count+1 end
    while count<p.limit and p.index<=#p.pending do
        local item=p.pending[p.index];p.index=p.index+1
        local unit=UnBotAccountAlts.FindUnit(item.name)
        if not unit or not UnitIsConnected(unit) or UnitGUID(unit)~=item.target.guid or not UnBotAccountAlts.IsEnabled(item.name) then
            p.done=p.done+1;p.failed=p.failed+1
            local text=not unit and "Альт не найден в группе. Набор не отправлен."
                or not UnitIsConnected(unit) and "Альт офлайн. Набор не отправлен."
                or UnitGUID(unit)~=item.target.guid and "GUID альта не совпадает с сохранённым персонажем. Набор не отправлен."
                or "Альт отключён в списке управления. Набор не отправлен."
            A.results[A.Key(item.name)]={name=item.name,ok=false,text=text,stage="проверка доступности",at=time()};A.RecordGroupFailure(p,item.name,text,"проверка доступности");A.Message(item.name..": "..text)
        else
            A.job=nil;A.groupResult=nil;A.Begin(item)
            local j=A.job
            if j then
                j.parallelGroup=p;p.active[j.id]=j;p.byName[A.Key(j.name)]=j;count=count+1
            else p.done=p.done+1;p.failed=p.failed+1;local result=A.results[A.Key(item.name)];A.RecordGroupFailure(p,item.name,result and result.text or "Не удалось начать применение набора.",result and result.stage or "подготовка");end
        end
    end
    A.job=Representative(p)
end
function A.Tick()
    local p=A.parallelGroup
    if not p then return oldTick() end
    if p.context~=A.Context() then A.Stop("Изменился персонаж или игровой мир. Применение остановлено.");return end
    if GetTime()>p.deadline then A.Stop("Истёк общий срок ожидания применения группы.");return end
    if (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player")) then
        A.Stop("У игрока начался бой. Применение наборов остановлено.");return
    end
    local dismounted,why=A.GroupDismountReady(p)
    if dismounted~=true then if dismounted==false then A.Stop(why) end;return end
    Fill(p)
    local jobs={};for _,j in pairs(p.active) do jobs[#jobs+1]=j end
    table.sort(jobs,function(a,b) return a.id<b.id end)
    for _,j in ipairs(jobs) do if p.active[j.id] then
        A.RunParallelJob(j,function()
            if j.parallelInspect and not p.inspectOwner then A.Inspect(j.parallelInspect) end
            local wait=j.wait;local sending=wait and wait.kind~="inspect" and not wait.sent
            -- Per-character 1.5s pacing is retained; the shared channel sends at most twice a second.
            if sending then j.sendAt=math.max(j.sendAt or 0,p.nextSend) end
            oldTick()
            if sending and wait.sent then p.nextSend=GetTime()+.5 end
        end)
    end end
    if p.done>=p.total and not next(p.active) then EndGroup(p,false) else A.job=Representative(p) end
end
end

-- Keep actionable, run-specific failures beside group counters.
do
local A=UnBotAltSetups
function A.FailureStage(j)
    if not j then return "подготовка" end
    if j.stateRecovery and j.stateRecovery.stage then return j.stateRecovery.stage end
    local step=(j.wait and j.wait.after) or j.lastStep or j.next or ""
    if step:find("gear_verified",1,true) then return "проверка экипировки" end
    if step:find("talents_verified",1,true) then return "проверка талантов" end
    local kind=j.wait and j.wait.kind
    local labels={inspect="осмотр альта",switch="переключение спека",talents="применение талантов",
        glyphs="чтение символов",bags="чтение сумок",trade_bags="чтение сумок",ignored="чтение запретов",
        spell_change="настройка заклинаний",spellbook="чтение заклинаний",strategy="личные стратегии",
        co="чтение боевых стратегий",nc="чтение стратегий вне боя",outfit_save="сохранение аутфита",
        outfit_apply="применение аутфита",gear="переодевание"}
    if labels[kind] then return labels[kind] end
    if step:find("gear",1,true) then return "подготовка экипировки" end
    if step:find("personal",1,true) then return "личные стратегии" end
    if step:find("glyph",1,true) then return "проверка символов" end
    if step:find("spell",1,true) then return "настройка заклинаний" end
    return "проверка перед применением"
end
function A.RecordGroupFailure(group,name,reason,stage)
    group.failureDetails=group.failureDetails or {}
    group.failureDetails[A.Key(name)]={name=tostring(name),reason=tostring(reason or "Причина не получена."),stage=stage or "применение набора"}
end
function A.ReportGroupFailures(group,summary)
    local keys={};for key in pairs(group.failureDetails or {}) do keys[#keys+1]=key end;table.sort(keys)
    if #keys==0 then return summary end
    local lines={}
    for _,key in ipairs(keys) do
        local d=group.failureDetails[key]
        local line=d.name.." — "..d.stage..": "..d.reason
        lines[#lines+1]=line;A.Message("Группа «"..tostring(group.label or "состав").."»: "..line)
    end
    -- Put the cause first: a long counter line must not hide it in the fixed-height status.
    return table.concat(lines,"\n").."\n"..summary
end
local previousNext=A.Next
function A.Next(step)
    if A.job then A.job.lastStep=step end
    return previousNext(step)
end
end

-- The player dismounts once; followers copy the player's mount state themselves.
do
local A=UnBotAltSetups
function A.PrepareGroupDismount(plan)
    if not IsMounted or not IsMounted() then return true end
    if IsFlying and IsFlying() then return false,"Сначала приземлитесь: автоматический дисмаунт в полёте не выполнен. Наборы не отправлены." end
    if not Dismount then return false,"Клиент не предоставляет дисмаунт игрока. Наборы не отправлены." end
    if not pcall(Dismount) then return false,"Игра не разрешила спешить игрока. Наборы не отправлены." end
    plan.playerDismountGate={deadline=GetTime()+3,settleAt=GetTime()+2}
    A.Status("Спешиваем игрока. Ждём, пока альты повторят его состояние...")
    return true
end
function A.GroupDismountReady(state)
    local gate=state.playerDismountGate
    if not gate then return true end
    if IsMounted and IsMounted() then
        if GetTime()>gate.deadline then return false,"Игрок остался на маунте после дисмаунта. Применение наборов остановлено без повторной команды." end
        return nil
    end
    if GetTime()<gate.settleAt then return nil end
    state.playerDismountGate=nil
    return true
end
end
