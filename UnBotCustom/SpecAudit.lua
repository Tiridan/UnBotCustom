-- Unified bot registry, specialization audit and reagent target UI.
-- Class/spec catalog shared with the finite strategy survey in AccountAlts.lua.

UnBotSpecAudit = UnBotSpecAudit or {
	selectedClass = "druid", selectedSpec = "restoration", selectedBot = nil,
	minimumCount = 8, activeTab = "registry", registryOffset = 0, specOffset = 0,
	registryFilter = "all", refreshElapsed = 0, selectedAlt = nil, selectedBeacon = nil,
};

local auditCatalog = {
	{ className = "warrior", classLabel = "Воин", specs = {"arms", "fury", "protection"} },
	{ className = "paladin", classLabel = "Паладин", specs = {"holy", "protection", "retribution"} },
	{ className = "hunter", classLabel = "Охотник", specs = {"beast mastery", "marksmanship", "survival"} },
	{ className = "rogue", classLabel = "Разбойник", specs = {"assassination", "combat", "subtlety"} },
	{ className = "priest", classLabel = "Жрец", specs = {"discipline", "holy", "shadow"} },
	{ className = "shaman", classLabel = "Шаман", specs = {"elemental", "enhancement", "restoration"} },
	{ className = "mage", classLabel = "Маг", specs = {"arcane", "fire", "frost"} },
	{ className = "warlock", classLabel = "Чернокнижник", specs = {"affliction", "demonology", "destruction"} },
	{ className = "druid", classLabel = "Друид", specs = {"balance", "feral bear", "feral cat", "restoration"} },
	{ className = "dk", classLabel = "Рыцарь смерти", specs = {"blood", "frost", "unholy"} },
};

local specLabels = {
	arms="Оружие", fury="Неистовство", protection="Защита", holy="Свет", retribution="Воздаяние",
	["beast mastery"]="Повелитель зверей", marksmanship="Стрельба", survival="Выживание",
	assassination="Ликвидация", combat="Бой", subtlety="Скрытность", discipline="Послушание",
	shadow="Тьма", elemental="Стихии", enhancement="Совершенствование", restoration="Исцеление",
	arcane="Тайная магия", fire="Огонь", frost="Лёд", affliction="Колдовство", demonology="Демонология",
	destruction="Разрушение", balance="Баланс", ["feral combat"]="Сила зверя",
	["feral bear"]="Сила зверя — танк", ["feral cat"]="Сила зверя — ДПС",
	blood="Кровь", unholy="Нечестивость",
};

local classLabels = {};
for _, data in ipairs(auditCatalog) do classLabels[data.className] = data.classLabel; end

function UnBotStrategySurveyGetDefinitions()
	local definitions={};
	for _,classData in ipairs(auditCatalog) do
		for _,specName in ipairs(classData.specs) do
			table.insert(definitions,{key=classData.className..":"..specName,className=classData.className,specName=specName,
				classLabel=classData.classLabel,specLabel=specLabels[specName] or specName});
		end
	end
	return definitions;
end

local function CenterNormalize(text)
	text=string.lower(tostring(text or "")); text=string.gsub(text,"%s+"," ");
	text=string.gsub(text,"^%s+",""); text=string.gsub(text,"%s+$",""); return text;
end

local function CenterProfileSpecName(profile)
	local resolved=UnBotTalentInfo and UnBotTalentInfo.Spec(profile); if resolved then return resolved; end
	local specName=CenterNormalize(profile and profile.specName);
	if CenterNormalize(profile and profile.className)=="druid" then
		local role=UnBotFeralProfileRole and UnBotFeralProfileRole(profile);
		if role=="bear" then return "feral bear"; end
		if role=="cat" then return "feral cat"; end
	end
	return specName;
end

local function CenterMessage(text)
	if UnBotBotCenterMessage then
		UnBotBotCenterMessage(text);
	elseif DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99UnBot|r: "..tostring(text or ""));
	end
end

local function CenterDate(value, withTime)
	value=tonumber(value) or 0; if value<=0 then return "нет данных"; end
	return date(withTime and "%d.%m.%Y %H:%M" or "%d.%m.%Y",value);
end

local function CenterMinimum(commit)
	local value=tonumber(UnBotSpecAudit.minimumEdit and UnBotSpecAudit.minimumEdit:GetText()) or UnBotSpecAudit.minimumCount or 8;
	value=math.max(1,math.min(12,math.floor(value))); UnBotSpecAudit.minimumCount=value;
	if commit and UnBotSpecAudit.minimumEdit then UnBotSpecAudit.minimumEdit:SetText(tostring(value)); end
	return value;
end

local function CenterFlagText(name,profile)
	if UnBotDKSpecBalance and UnBotDKSpecBalance.auditUnavailable and UnBotDKSpecBalance.auditUnavailable[name] then return "не ответил на проверку"; end
	local flags=profile and profile.rotationFlags or {}; local now=time();
	if (tonumber(flags.quarantinedUntil) or 0)>now then
		return "недоступен до "..date("%d.%m %H:%M",flags.quarantinedUntil)..(flags.quarantineReason and (": "..tostring(flags.quarantineReason)) or "");
	elseif (tonumber(flags.unavailableUntil) or 0)>now then return "недоступен до "..date("%d.%m %H:%M",flags.unavailableUntil);
	elseif (tonumber(flags.soulstoneUntil) or 0)>now then return "камень души недоступен до "..date("%d.%m %H:%M",flags.soulstoneUntil); end
	return "доступен";
end

local function CenterIsUnavailable(name,profile)
	if UnBotDKSpecBalance and UnBotDKSpecBalance.auditUnavailable and UnBotDKSpecBalance.auditUnavailable[name] then return true; end
	local flags=profile and profile.rotationFlags or {}; local now=time();
	return (tonumber(flags.quarantinedUntil) or 0)>now or (tonumber(flags.unavailableUntil) or 0)>now;
end

local function CenterReagentSummary(profile)
	local className=CenterNormalize(profile and profile.className); local items=UnBotJunkCleanerReagentTargets and UnBotJunkCleanerReagentTargets[className] or {};
	if #items==0 then return "—"; end local parts={};
	for _,item in ipairs(items) do
		local target=UnBotReagentTargetGet and UnBotReagentTargetGet(className,item.id,item.target) or item.target;
		local count=profile.reagentCounts and (profile.reagentCounts[item.id] or profile.reagentCounts[tostring(item.id)]);
		table.insert(parts,(count==nil and "?" or tostring(count)).."/"..tostring(target));
	end return table.concat(parts,", ");
end

local function CenterRegistryTotal()
	local n=0; for name,profile in pairs((UnBotBotRegistry and UnBotBotRegistry.bots) or {}) do if not UnBotIsAccountAltProfile or not UnBotIsAccountAltProfile(name,profile) then n=n+1; end end return n;
end

local function CenterBuildRegistryRows()
	local rows={}; local search=CenterNormalize(UnBotSpecAudit.searchEdit and UnBotSpecAudit.searchEdit:GetText() or ""); local filter=UnBotSpecAudit.registryFilter or "all";
	for name,profile in pairs((UnBotBotRegistry and UnBotBotRegistry.bots) or {}) do
		if not UnBotIsAccountAltProfile or not UnBotIsAccountAltProfile(name,profile) then
		local className=CenterNormalize(profile.className); local specName=CenterProfileSpecName(profile);
		local searchable=CenterNormalize(name.." "..className.." "..specName.." "..tostring(profile.classLocalized or ""));
		local matches=search=="" or string.find(searchable,search,1,true);
		if matches and filter=="quarantine" then matches=CenterIsUnavailable(name,profile); end
		if matches and filter=="reagents" then matches=UnBotRegistryNeedsReagentRestock and UnBotRegistryNeedsReagentRestock(profile) or false; end
		if matches and filter=="junk" then matches=UnBotRegistryProfileNeedsJunkSale and UnBotRegistryProfileNeedsJunkSale(profile) or false; end
		local classification=UnBotTalentInfo and UnBotTalentInfo.Get(profile) or {mode="unknown"};
		if matches and (UnBotSpecAudit.talentMode or "all")~="all" then matches=classification.mode==UnBotSpecAudit.talentMode; end
		if matches then table.insert(rows,{name=name,profile=profile,className=className,specName=specName,classification=classification}); end
		end
	end
	table.sort(rows,function(a,b) if a.className~=b.className then return a.className<b.className; end if a.specName~=b.specName then return a.specName<b.specName; end return string.lower(a.name)<string.lower(b.name); end);
	return rows;
end

local function CenterBuildSpecRows()
	local rows,byKey={},{};
	for _,classData in ipairs(auditCatalog) do for _,specName in ipairs(classData.specs) do
		local row={className=classData.className,classLabel=classData.classLabel,specName=specName,specLabel=specLabels[specName] or specName,total=0,available=0,verified=0,bots={},modes={pve=0,pvp=0,unknown=0}};
		local mode=UnBotSpecAudit.talentMode;
		if UnBotTalentInfo and (mode=="pve" or mode=="pvp") then
			local targets=UnBotTalentInfo.Targets(row.className,mode);
			if targets then row.supported=targets[specName]~=nil; end
		end
		row.key=row.className..":"..row.specName; byKey[row.key]=row; table.insert(rows,row);
	end end
	local unknown=0; local state=UnBotDKSpecBalance or {};
	for name,profile in pairs((UnBotBotRegistry and UnBotBotRegistry.bots) or {}) do
		if not UnBotIsAccountAltProfile or not UnBotIsAccountAltProfile(name,profile) then
		local className=CenterNormalize(profile.className); local specName=CenterProfileSpecName(profile); if specName~="feral bear" and specName~="feral cat" and UnBotSpecCountBalanceNormalizeSpec then specName=UnBotSpecCountBalanceNormalizeSpec(specName); end local row=byKey[className..":"..specName];
		local classification=UnBotTalentInfo and UnBotTalentInfo.Get(profile) or {mode="unknown"};
		if row then
			row.modes[classification.mode]=(row.modes[classification.mode] or 0)+1;
			if (UnBotSpecAudit.talentMode or "all")=="all" or classification.mode==UnBotSpecAudit.talentMode then
				row.total=row.total+1; local available=UnBotSpecCountBalanceProfileAvailable and UnBotSpecCountBalanceProfileAvailable(name,profile);
				if available then row.available=row.available+1; end
				if profile.talentSnapshot and not profile.talentSnapshotStale then row.verified=row.verified+1; end
				table.insert(row.bots,{name=name,profile=profile,classification=classification,available=available and true or false});
			end
		elseif (UnBotSpecAudit.talentMode or "all")=="all" or classification.mode==UnBotSpecAudit.talentMode then unknown=unknown+1; end
		end
	end
	for _,row in ipairs(rows) do table.sort(row.bots,function(a,b) if a.available~=b.available then return a.available; end return tostring(a.name)<tostring(b.name); end); end
	return rows,byKey,unknown;
end

local function CenterBotDetails(name,profile)
	if not name or not profile then return "Выберите бота в списке."; end
	local className=CenterNormalize(profile.className);
	local classification=UnBotTalentInfo and UnBotTalentInfo.Get(profile) or {mode="unknown"};
	local lines={
		name,
		(classLabels[className] or tostring(profile.className or "?")).." — "..(specLabels[CenterProfileSpecName(profile)] or tostring(profile.specName or "?")),
		"Уровень: "..tostring(profile.level or "?").."   Экипировка: "..tostring(profile.gearScore or "?"),
		"Статус: "..CenterFlagText(name,profile),
		"Режим: "..((UnBotTalentInfo and UnBotTalentInfo.labels[classification.mode]) or "Неизвестно"),
		"Шаблон: "..tostring(classification.preset or "не определён"),
		"Таланты: "..tostring(profile.talentSnapshot and profile.talentSnapshot.build or "не прочитаны"),
		"Осмотр: "..CenterDate(profile.talentSnapshot and profile.talentSnapshot.checkedAt,true),
		classification.reason or "Источник: осмотр / каталог сервера",
		"Класс/спек проверены: "..CenterDate(UnBotRegistryRefresh and UnBotRegistryRefresh.CheckedAt(profile) or profile.specCheckedAt,true),
		"Призывался: "..tostring(profile.summonCount or 0).." раз. Последний раз: "..CenterDate(profile.lastSummonedAt,true),
		"Хлам продан: "..CenterDate(profile.junkSoldAt,true)..(UnBotRegistryProfileNeedsJunkSale and UnBotRegistryProfileNeedsJunkSale(profile) and " — нужно повторить" or ""),
		"Свободно в сумках: "..tostring(profile.freeBagSlots==nil and "неизвестно" or profile.freeBagSlots),
		"",
		"Реагенты:",
	};
	local items=UnBotJunkCleanerReagentTargets and UnBotJunkCleanerReagentTargets[className] or {};
	if #items==0 then table.insert(lines,"Для этого класса реагенты не нужны."); end
	for _,item in ipairs(items) do
		local target=UnBotReagentTargetGet and UnBotReagentTargetGet(className,item.id,item.target) or item.target;
		local count=profile.reagentCounts and (profile.reagentCounts[item.id] or profile.reagentCounts[tostring(item.id)]);
		local itemName=GetItemInfo and GetItemInfo(item.id) or nil;
		table.insert(lines,tostring(itemName or item.label)..": "..tostring(count==nil and "?" or count).." из "..tostring(target)..(count~=nil and (tonumber(count) or 0)<target and " — нужно купить" or ""));
	end
	table.insert(lines,"Проверено: "..CenterDate(profile.reagentCountsAt,true));
	return table.concat(lines,"\n");
end

local function CenterSpecDetails(row,minimum)
	if not row then return "Выберите специализацию."; end local lines={row.classLabel.." — "..row.specLabel,"Фильтр: "..((UnBotTalentInfo and UnBotTalentInfo.labels[UnBotSpecAudit.talentMode or "all"]) or "Все"),"Всего: "..row.total.."   Доступны: "..row.available.."   Осмотрены: "..row.verified,"PvE: "..row.modes.pve.."   PvP: "..row.modes.pvp.."   Неизвестно: "..row.modes.unknown,"Минимум доступных: "..minimum.."   Нужно ещё: "..(row.supported==false and "—" or math.max(0,minimum-row.available)),"","Конкретные боты этой специализации:"};
	if row.supported==false then table.insert(lines,4,"В каталоге нет однозначного шаблона этой роли для выбранного режима."); end
	for index,entry in ipairs(row.bots) do
		if index<=26 then
			local checked=(UnBotDKSpecBalance and UnBotDKSpecBalance.auditVerified and UnBotDKSpecBalance.auditVerified[entry.name]) and "проверен сейчас" or ("проверен "..CenterDate(entry.profile.talentSnapshot and entry.profile.talentSnapshot.checkedAt,true));
			table.insert(lines,entry.name.." ["..((UnBotTalentInfo and UnBotTalentInfo.labels[entry.classification.mode]) or "?").."] — "..(entry.available and "доступен" or CenterFlagText(entry.name,entry.profile))..", "..checked..", экипировка "..tostring(entry.profile.gearScore or "?"));
		elseif index==27 then
			table.insert(lines,"...и ещё "..tostring(#row.bots-26)..". Полный список — на вкладке «Все боты».");
		end
	end
	if #row.bots==0 then table.insert(lines,"Нет сохранённых ботов с этой специализацией."); end return table.concat(lines,"\n");
end

-- Display reads only the live roster and already attached profiles. Service actions
-- still build/validate their own queues when the user explicitly clicks them.
local function CenterCurrentGroupDetails()
 local queue,alts,altNames,seen={},{},{},{};
 local account=UnBotAccountAlts;
 for _,name in ipairs(account and account.GetNames and account.GetNames(true) or {}) do altNames[name]=true; end
 local raid=(GetNumRaidMembers() or 0)>0; local player=UnitName("player");
 for i=1,(raid and math.min(40,GetNumRaidMembers()) or (GetNumPartyMembers() or 0)) do
  local unit=(raid and "raid" or "party")..i; local name=UnitName(unit);
  if name and name~=player and name~=UNKNOWN and name~=UNKNOWNOBJECT and not seen[name] and UnitIsConnected(unit) then
   seen[name]=true;
   local profile=UnBotBotRegistry and UnBotBotRegistry.bots and UnBotBotRegistry.bots[name];
   if altNames[name] then alts[#alts+1]=name;
   elseif profile and not (UnBotIsAccountAltProfile and UnBotIsAccountAltProfile(name,profile))
    and not (account and account.IsListed and account.IsListed(name)) then queue[#queue+1]=name; end
  end
 end
 table.sort(queue,function(a,b)
  local profiles=UnBotBotRegistry.bots; local ca=CenterNormalize(profiles[a].className); local cb=CenterNormalize(profiles[b].className);
  if ca~=cb then return ca<cb; end return a:lower()<b:lower();
 end);
 table.sort(alts,function(a,b) return account.Key(a)<account.Key(b); end);
	local lines={}; local allowedAlts=0;
	if #queue==0 and #alts==0 then
		table.insert(lines,"В текущей группе или рейде нет доступных ботов или альтов.");
		table.insert(lines,"Соберите группу, затем вернитесь на эту вкладку.");
		return table.concat(lines,"\n"),0,0,0;
	end
	if #queue>0 then table.insert(lines,"|cffffd200ОБЫЧНЫЕ БОТЫ — ОБСЛУЖИВАЮТСЯ|r"); end
	for index,name in ipairs(queue) do
		if index<=18 then
			local profile=UnBotBotRegistry and UnBotBotRegistry.bots and UnBotBotRegistry.bots[name] or {};
			local className=CenterNormalize(profile.className); local specName=CenterProfileSpecName(profile);
			table.insert(lines,name.." — "..(classLabels[className] or tostring(profile.className or "?")).." / "..(specLabels[specName] or tostring(profile.specName or "?")));
		elseif index==19 then
			table.insert(lines,"...и ещё "..tostring(#queue-18)..".");
		end
	end
	if #alts>0 then
		if #queue>0 then table.insert(lines,""); end
		table.insert(lines,"|cff69ccf0АЛЬТЫ АККАУНТА|r");
		for _,name in ipairs(alts) do
			local profile=UnBotAccountAlts.GetProfile(name) or {};
			local allowed=UnBotAccountAlts.IsMaintenanceAllowed and UnBotAccountAlts.IsMaintenanceAllowed(name);
			if allowed then allowedAlts=allowedAlts+1; end
			table.insert(lines,name.." — "..tostring(profile.className or "?").." / "..tostring(profile.specName or "?")..(allowed and " |cff55ffbb[хлам + реагенты разрешены]|r" or " |cffaaaaaa[защищён]|r"));
		end
	end
	return table.concat(lines,"\n"),#queue,#alts,allowedAlts;
end

local function CenterFilterLabel()
	local labels={all="Все",quarantine="Недоступные",reagents="Нужно купить",junk="Нужно продать хлам"}; return "Показать: "..tostring(labels[UnBotSpecAudit.registryFilter] or labels.all);
end

local function CenterSetScroll(slider,offsetKey,total,visible)
	local maxOffset=math.max(0,total-visible); UnBotSpecAudit[offsetKey]=math.max(0,math.min(maxOffset,tonumber(UnBotSpecAudit[offsetKey]) or 0)); slider:SetMinMaxValues(0,maxOffset); slider:SetValue(UnBotSpecAudit[offsetKey]); if maxOffset>0 then slider:Show(); else slider:Hide(); end
end

function UnBotSpecAuditCycleTalentMode()
	local order={all="pve",pve="pvp",pvp="unknown",unknown="all"};
	UnBotSpecAudit.talentMode=order[UnBotSpecAudit.talentMode or "all"] or "all";
	UnBotSpecAudit.registryOffset,UnBotSpecAudit.specOffset=0,0; UnBotSpecAudit.selectedBot=nil;
	UnBotSpecAuditRefresh();
end

local function CenterAutomationStatus()
	if UnBotRegistryRefresh and UnBotRegistryRefresh.Running() then return UnBotRegistryRefresh.Status(); end
	if UnBotStrategySurvey and UnBotStrategySurvey.active then return UnBotStrategySurvey.Status(); end
	if UnBotBeaconTravel and (UnBotBeaconTravel.active or UnBotBeaconTravel.GetTask()) then return UnBotBeaconTravel.StatusText(); end
	if UnBotAccountAlts and (UnBotAccountAlts.active or UnBotAccountAlts.discoveryActive) then return UnBotAccountAlts.StatusText(); end
	if UnBotBotScanner and UnBotBotScanner.active then
		local text=UnBotBotScannerUIProgressText and UnBotBotScannerUIProgressText() or "";
		text=string.gsub(text,"^Полный скан:%s*","");
		return "Обновляю список ботов"..(text~="" and (": "..text) or "...");
	end
	if UnBotDKSpecBalance and UnBotDKSpecBalance.active then return "Проверяю специализации: "..tostring((UnBotDKSpecBalance.auditSuccess or 0)+(UnBotDKSpecBalance.auditFailed or 0)).."/"..tostring(UnBotDKSpecBalance.targetCount or 0)..". Сейчас: "..tostring(UnBotDKSpecBalance.currentName or "—").."."; end
	if UnBotJunkCleaner and UnBotJunkCleaner.active then local timing=UnBotServiceTiming and UnBotServiceTiming.ActiveText and UnBotServiceTiming.ActiveText(UnBotJunkCleaner.timingMode,UnBotJunkCleaner); return (UnBotJunkCleaner.currentGroupOnly and "Текущая группа — " or "")..(UnBotJunkCleaner.bagAuditOnly and "проверяю сумки: " or "обслуживаю ботов: ")..tostring(UnBotJunkCleaner.index or 0).."/"..tostring(#(UnBotJunkCleaner.queue or {}))..". Сейчас: "..tostring(UnBotJunkCleaner.currentName or "—")..(timing and ". "..timing or "."); end
	if UnBotFastJunkRaid and UnBotFastJunkRaid.active then local timing=UnBotServiceTiming and UnBotServiceTiming.ActiveText and UnBotServiceTiming.ActiveText("fast",UnBotFastJunkRaid); return (UnBotFastJunkRaid.currentGroupOnly and "Текущая группа — " or "")..(UnBotFastJunkRaid.accountAltsOnly and "продаю хлам альтов: " or "продаю хлам: ")..tostring(UnBotFastJunkRaid.processed or 0).."/"..tostring(#(UnBotFastJunkRaid.queue or {}))..(timing and ". "..timing or "."); end
	if (UnBotSpecAudit.activeTab=="alts" or UnBotSpecAudit.activeTab=="beacons")
		and UnBotAccountAlts and UnBotAccountAlts.centerRefreshHint then return UnBotAccountAlts.centerRefreshHint; end
	local meta=UnBotBotRegistry and UnBotBotRegistry.meta or {};
	if (tonumber(meta.lastScanFinished) or 0)>0 then
		local total=tonumber(meta.lastScanProfiles) or UnBotSpecAudit.registryTotal;
		if not total then total=CenterRegistryTotal(); UnBotSpecAudit.registryTotal=total; end
		return "Список обновлён "..date("%d.%m.%Y %H:%M",meta.lastScanFinished)..". Найдено ботов: "..tostring(total)..".";
	end
	if UnBotRegistryRefresh and UnBotRegistryRefresh.Job() then return UnBotRegistryRefresh.Status(); end
	return "Список ботов ещё не обновлялся.";
end

local function CenterCreateButton(parent,text,width,x,y,onClick)
	local button=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate"); button:SetWidth(width); button:SetHeight(24); button:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y); button:SetText(text); button:SetScript("OnClick",onClick); return button;
end

local function CenterCreateActionButton(parent,text,width,x,y,title,description,requirements,onClick)
	local button=CenterCreateButton(parent,text,width,x,y,onClick);
	button:SetScript("OnEnter",function(self)
		GameTooltip:SetOwner(self,"ANCHOR_TOP"); GameTooltip:AddLine(title,1,.82,.18); GameTooltip:AddLine(description,1,1,1,true);
		if requirements and requirements~="" then GameTooltip:AddLine(" "); GameTooltip:AddLine(requirements,1,.35,.2,true); end GameTooltip:Show();
	end); button:SetScript("OnLeave",function() GameTooltip:Hide(); end); return button;
end

local function CenterCreateEditBox(parent,width,height,numeric)
	local edit=CreateFrame("EditBox",nil,parent); edit:SetWidth(width); edit:SetHeight(height); edit:SetAutoFocus(false); edit:SetFontObject(GameFontHighlight); edit:SetJustifyH("CENTER"); edit:SetTextColor(1,1,1);
	edit:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}}); edit:SetBackdropColor(.015,.055,.06,.97); edit:SetBackdropBorderColor(.35,.65,.68,.95);
	if numeric and edit.SetNumeric then edit:SetNumeric(true); end
	edit:SetScript("OnEscapePressed",function(self) self:ClearFocus(); end); edit:SetScript("OnEditFocusGained",function(self) self:SetBackdropBorderColor(1,.72,.18,1); end); edit:SetScript("OnEditFocusLost",function(self) self:SetBackdropBorderColor(.35,.65,.68,.95); end); return edit;
end

local function CenterCreateSlider(parent,name,x,y,height,offsetKey)
	local slider=CreateFrame("Slider",name,parent,"UIPanelScrollBarTemplate"); slider:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y); slider:SetHeight(height); slider:SetValueStep(1);
	slider:SetScript("OnValueChanged",function(self,value) local rounded=math.floor((tonumber(value) or 0)+.5); if UnBotSpecAudit[offsetKey]~=rounded then UnBotSpecAudit[offsetKey]=rounded; UnBotSpecAuditRefresh(); end end); return slider;
end

local function CenterCreateRow(parent,width,y)
	local row=CreateFrame("Button",nil,parent); row:SetWidth(width); row:SetHeight(21); row:SetPoint("TOPLEFT",parent,"TOPLEFT",0,y); row:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background"});
	row.separator=row:CreateTexture(nil,"BORDER"); row.separator:SetHeight(1); row.separator:SetPoint("BOTTOMLEFT",row,"BOTTOMLEFT",0,0); row.separator:SetPoint("BOTTOMRIGHT",row,"BOTTOMRIGHT",0,0); row.separator:SetTexture(.18,.55,.58,.65);
	row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight","ADD"); return row;
end

local function CenterCreateText(row,x,width,justify)
	local text=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); text:SetPoint("LEFT",row,"LEFT",x,0); text:SetWidth(width); text:SetJustifyH(justify or "LEFT"); return text;
end

local function CenterShowTab(tab)
	UnBotSpecAudit.activeTab=tab; for key,panel in pairs(UnBotSpecAudit.panels or {}) do if key==tab then panel:Show(); else panel:Hide(); end end
	for key,button in pairs(UnBotSpecAudit.tabButtons or {}) do button:SetButtonState(key==tab and "PUSHED" or "NORMAL",key==tab); end
	if UnBotSpecAudit.searchEdit then if tab=="registry" then UnBotSpecAudit.searchEdit:Show(); else UnBotSpecAudit.searchEdit:Hide(); end end
	if UnBotSpecAudit.minimumEdit then if tab=="specs" then UnBotSpecAudit.minimumEdit:Show(); else UnBotSpecAudit.minimumEdit:Hide(); end end
	for _,entry in ipairs(UnBotSpecAudit.reagentEdits or {}) do if tab=="reagents" then entry.edit:Show(); else entry.edit:Hide(); end end
	if tab=="reagents" then for _,entry in ipairs(UnBotSpecAudit.reagentEdits or {}) do entry.edit:SetText(tostring(UnBotReagentTargetGet(entry.className,entry.item.id,entry.item.target))); end end
	UnBotSpecAuditRefresh();
end

local function CenterSaveReagents()
	for _,entry in ipairs(UnBotSpecAudit.reagentEdits or {}) do local value=UnBotReagentTargetSet(entry.className,entry.item.id,entry.edit:GetText()); entry.edit:SetText(tostring(value or 0)); entry.edit:ClearFocus(); end
	CenterMessage("Количество реагентов сохранено."); UnBotSpecAuditRefresh();
end

local function CenterSetEditEnabled(edit,enabled)
	if not edit then return; end
	edit:EnableMouse(enabled and true or false);
	edit:SetTextColor(enabled and 1 or .55,enabled and 1 or .55,enabled and 1 or .55);
	if not enabled then edit:ClearFocus(); end
end

local function CenterBuildAltRows()
	local rows={};
	if not UnBotAccountAlts or not UnBotAccountAlts.GetNames then return rows; end
	for _,name in ipairs(UnBotAccountAlts.GetNames(true)) do
		local profile=UnBotAccountAlts.GetProfile(name) or {};
		local faction=UnBotAccountAlts.GetFaction and UnBotAccountAlts.GetFaction(name);
		table.insert(rows,{name=name,profile=profile,enabled=UnBotAccountAlts.IsEnabled(name),maintenanceAllowed=UnBotAccountAlts.IsMaintenanceAllowed and UnBotAccountAlts.IsMaintenanceAllowed(name),unit=UnBotAccountAlts.FindUnit(name),faction=faction,factionLabel=UnBotAccountAlts.FactionLabel and UnBotAccountAlts.FactionLabel(faction) or "ФРАКЦИЯ ?",sameFaction=UnBotAccountAlts.IsCurrentFaction and UnBotAccountAlts.IsCurrentFaction(name)});
	end
	return rows;
end

local function CenterAltDetails(entry)
	if not entry then return "Выберите альта в списке."; end
	local profile=entry.profile or {};
	return entry.name.."\n"..tostring(profile.className or "?").." / "..tostring(profile.specName or "?")
		.." — уровень "..tostring(profile.level or "?").."\nФракция: "..tostring(entry.factionLabel or "?")
		.."\n\n"..(UnBotAltStrategies and UnBotAltStrategies.Summary(entry.name) or "Стратегии ещё не прочитаны.");
end

local function CenterBeaconDetails(entry)
	if not entry then return "Выберите персонажа в списке."; end
	local beacon=entry.beacon;
	if not beacon or beacon.enabled==false then
		return entry.name.."\nМаяк не назначен.\n\nНажмите «Поставить здесь», чтобы подключить персонажа, призвать его к текущей точке и безопасно отключить.\n\nТекущий персонаж и персонажи другой фракции не используются.";
	end
	local location=tostring(beacon.zoneName or "неизвестная зона");
	if beacon.subZoneName and beacon.subZoneName~="" then location=location.." — "..tostring(beacon.subZoneName); end
	local lines={
		entry.name,
		"Место: "..location,
		"Установлен: "..CenterDate(beacon.placedAt,true),
		"Последняя проверка позиции: "..CenterDate(beacon.locationUpdatedAt,true),
		"Последний переход: "..CenterDate(beacon.lastUsedAt,true),
		"Использований: "..tostring(beacon.useCount or 0),
		"Защита от переноса: "..(beacon.pinned and "ЗАКРЕПЛЁН" or "не закреплён"),
		"",
		"Заметка:",
		(beacon.note and beacon.note~="") and tostring(beacon.note) or "—",
	};
	return table.concat(lines,"\n");
end

-- Coalesce roster events; periodic status updates run only while work is active.
function UnBotSpecAudit.MarkDirty() UnBotSpecAudit.dirty=true; end
function UnBotSpecAudit.WorkActive()
 return (UnBotRegistryRefresh and UnBotRegistryRefresh.Running())
  or (UnBotBotScanner and (UnBotBotScanner.active or UnBotBotScanner.pendingTalentAudit or UnBotBotScanner.talentAuditRunning or UnBotBotScanner.pendingSpecBalanceClass))
  or (UnBotDKSpecBalance and UnBotDKSpecBalance.active)
  or (UnBotJunkCleaner and UnBotJunkCleaner.active) or (UnBotFastJunkRaid and UnBotFastJunkRaid.active)
  or (UnBotAccountAlts and (UnBotAccountAlts.active or UnBotAccountAlts.discoveryActive))
  or (UnBotBeaconTravel and (UnBotBeaconTravel.active or UnBotBeaconTravel.GetTask()))
  or (UnBotAltStrategies and (UnBotAltStrategies.active or #(UnBotAltStrategies.queue or {})>0))
  or (UnBotStrategySurvey and UnBotStrategySurvey.active);
end
function UnBotSpecAudit.Tick(elapsed)
 local state=UnBotSpecAudit; if not state.frame or not state.frame:IsShown() then return; end
 state.refreshElapsed=(state.refreshElapsed or 0)+elapsed; if state.refreshElapsed<.25 then return; end
 local previous=state.workActive; local active=state.WorkActive(); state.workActive=active;
 if state.dirty or (previous and not active) then state.refreshElapsed=0; UnBotSpecAuditRefresh();
 elseif active and state.refreshElapsed>=.5 then state.refreshElapsed=0; UnBotSpecAuditRefresh(true);
 elseif not active then state.refreshElapsed=0; end
end

function UnBotSpecAuditRefresh(statusOnly)
 if UnBotSpecAudit.opening then UnBotSpecAudit.dirty=true; return; end
	local modeLabel="Режим: "..((UnBotTalentInfo and UnBotTalentInfo.labels[UnBotSpecAudit.talentMode or "all"]) or "Все");
	if UnBotSpecAudit.registryModeButton then UnBotSpecAudit.registryModeButton:SetText(modeLabel); end
	if UnBotSpecAudit.specModeButton then UnBotSpecAudit.specModeButton:SetText(modeLabel); end
	local frame=UnBotSpecAudit.frame;
	if not frame or not frame:IsShown() then return; end
 if not statusOnly then UnBotSpecAudit.dirty=false; end
	local activeTab=UnBotSpecAudit.activeTab or "registry";
	local status=CenterAutomationStatus(); UnBotSpecAudit.statusText:SetText(status);
	if UnBotSpecAudit.registryProgress then
		local job=UnBotRegistryRefresh and UnBotRegistryRefresh.Job();
		local visible=job and UnBotRegistryRefresh.OutcomeCounts and status==UnBotRegistryRefresh.Status(job);
		if visible then
			local c=UnBotRegistryRefresh.OutcomeCounts(job);
			UnBotSpecAudit.registryProgress:SetValue(c.total>0 and c.processed/c.total or 0);
			UnBotSpecAudit.registryProgress:SetStatusBarColor(c.unconfirmed>0 and 1 or .2,c.unconfirmed>0 and .65 or .8,.2);
			UnBotSpecAudit.registryProgress:Show();UnBotSpecAudit.statusText:SetHeight(30);
		else UnBotSpecAudit.registryProgress:Hide();UnBotSpecAudit.statusText:SetHeight(36);end
	end

	local selectedProfile=UnBotSpecAudit.selectedBot and UnBotBotRegistry and UnBotBotRegistry.bots and UnBotBotRegistry.bots[UnBotSpecAudit.selectedBot];
	local selectedAltEntry=UnBotSpecAudit.altSelectedEntry;
 local counts=UnBotSpecAudit.currentGroupCounts or {};
 local groupCount,groupAltCount,groupAllowedAltCount=counts[1] or 0,counts[2] or 0,counts[3] or 0;

	-- These two pages scale with the entire saved bot catalog. The periodic
	-- status tick must not rebuild and sort them while the window is idle.
	if activeTab=="registry" and not statusOnly then
		local registryRows=CenterBuildRegistryRows();
		UnBotSpecAudit.registryRows=registryRows;
		CenterSetScroll(UnBotSpecAudit.registrySlider,"registryOffset",#registryRows,#UnBotSpecAudit.registryButtons);
		for index,button in ipairs(UnBotSpecAudit.registryButtons) do
			local row=registryRows[(UnBotSpecAudit.registryOffset or 0)+index];
			if row then
				button.data=row; button:Show(); button.nameText:SetText(row.name); button.specText:SetText((classLabels[row.className] or row.className).." / "..(specLabels[row.specName] or row.specName));
				local unavailable=CenterIsUnavailable(row.name,row.profile);
				button.modeText:SetText(UnBotTalentInfo and UnBotTalentInfo.labels[row.classification.mode] or "?"); button.modeText:SetTextColor(row.classification.mode=="pvp" and 1 or .65,row.classification.mode=="pve" and 1 or .65,.65);
				button.stateText:SetText(unavailable and "НЕДОСТУПЕН" or "доступен"); button.stateText:SetTextColor(unavailable and 1 or .25,unavailable and .25 or 1,.25);
				button.reagentText:SetText(CenterReagentSummary(row.profile)); button.bagText:SetText(row.profile.freeBagSlots==nil and "?" or tostring(row.profile.freeBagSlots)); button.junkText:SetText(CenterDate(row.profile.junkSoldAt,false));
				button:SetBackdropColor(index%2==0 and .035 or .075,index%2==0 and .15 or .22,index%2==0 and .16 or .23,row.name==UnBotSpecAudit.selectedBot and .98 or .82); button.separator:SetTexture(row.name==UnBotSpecAudit.selectedBot and 1 or .18,row.name==UnBotSpecAudit.selectedBot and .72 or .55,row.name==UnBotSpecAudit.selectedBot and .18 or .58,row.name==UnBotSpecAudit.selectedBot and .95 or .65);
			else button.data=nil; button:Hide(); end
		end
		local registryTotal=CenterRegistryTotal(); UnBotSpecAudit.registryTotal=registryTotal;
		UnBotSpecAudit.registryCountText:SetText("Показано: "..tostring(#registryRows).." / "..tostring(registryTotal)); UnBotSpecAudit.filterButton:SetText(CenterFilterLabel()); UnBotSpecAudit.registryDetail:SetText(CenterBotDetails(UnBotSpecAudit.selectedBot,selectedProfile));
	elseif activeTab=="specs" and not statusOnly then
		local minimum=CenterMinimum(false); local specRows,byKey,unknown=CenterBuildSpecRows(); UnBotSpecAudit.specRows=specRows; UnBotSpecAudit.specByKey=byKey;
		local selected=byKey[tostring(UnBotSpecAudit.selectedClass)..":"..tostring(UnBotSpecAudit.selectedSpec)] or specRows[1]; CenterSetScroll(UnBotSpecAudit.specSlider,"specOffset",#specRows,#UnBotSpecAudit.specButtons);
		for index,button in ipairs(UnBotSpecAudit.specButtons) do
			local row=specRows[(UnBotSpecAudit.specOffset or 0)+index];
			if row then
				button.data=row; button:Show(); button.classText:SetText(row.classLabel); button.specText:SetText(row.specLabel); button.countText:SetText(row.total.." / "..row.available);
				button.pveText:SetText(tostring(row.modes.pve)); button.pvpText:SetText(tostring(row.modes.pvp)); button.unknownModeText:SetText(tostring(row.modes.unknown)); button.unknownModeText:SetTextColor(row.modes.unknown>0 and 1 or .55,row.modes.unknown>0 and .75 or .55,.35);
				local need=row.supported==false and 0 or math.max(0,minimum-row.available); button.deficitText:SetText(row.supported==false and "—" or tostring(need)); button.deficitText:SetTextColor(need>0 and 1 or .2,need>0 and .25 or 1,need>0 and .25 or .35);
				local isSelected=selected and row.key==selected.key; button:SetBackdropColor(index%2==0 and .035 or .075,index%2==0 and .15 or .22,index%2==0 and .16 or .23,isSelected and .98 or .82); button.separator:SetTexture(isSelected and 1 or .18,isSelected and .72 or .55,isSelected and .18 or .58,isSelected and .95 or .65);
			else button.data=nil; button:Hide(); end
		end
		UnBotSpecAudit.specDetail:SetText(CenterSpecDetails(selected,minimum)); local catalogClasses=0; for _,classData in ipairs(auditCatalog) do if UnBotFullTalentCatalog and UnBotFullTalentCatalog.Get(classData.className,80) then catalogClasses=catalogClasses+1; end end
		UnBotSpecAudit.unknownText:SetText("Спек неизвестен: "..tostring(unknown).."  |  Каталог: "..catalogClasses.."/"..#auditCatalog);
	elseif activeTab=="current" and not statusOnly then
		local groupText; groupText,groupCount,groupAltCount,groupAllowedAltCount=CenterCurrentGroupDetails();
		UnBotSpecAudit.currentGroupCounts={groupCount,groupAltCount,groupAllowedAltCount};
		if UnBotSpecAudit.currentGroupDetail then UnBotSpecAudit.currentGroupDetail:SetText(groupText); end
		if UnBotSpecAudit.currentGroupCount then UnBotSpecAudit.currentGroupCount:SetText("Обычных ботов: "..tostring(groupCount).."   Альтов онлайн: "..tostring(groupAltCount).."   Альтов с разрешением: "..tostring(groupAllowedAltCount)); end
	elseif activeTab=="alts" and not statusOnly then
  selectedAltEntry=nil;
		local altRows=CenterBuildAltRows(); UnBotSpecAudit.altRows=altRows; UnBotSpecAudit.altOffset=math.min(UnBotSpecAudit.altOffset or 0,math.max(0,#altRows-15));
		for _,row in ipairs(altRows) do if row.name==UnBotSpecAudit.selectedAlt then selectedAltEntry=row; break end end
		for index,button in ipairs(UnBotSpecAudit.altButtons or {}) do
			local row=altRows[(UnBotSpecAudit.altOffset or 0)+index];
			if row then
				button.data=row; button:Show(); button.nameText:SetText(row.name); button.profileText:SetText((classLabels[CenterNormalize(row.profile.className)] or tostring(row.profile.className or "?")).." / "..(specLabels[CenterProfileSpecName(row.profile)] or tostring(row.profile.specName or "без специализации"))); button.factionText:SetText(row.faction and tostring(row.factionLabel) or "?");
				button.stateText:SetText(not row.sameFaction and (row.faction and "чужая" or "проверить") or (row.unit and "в группе" or (row.enabled and "доступен" or "отключён"))); button.serviceText:SetText(row.maintenanceAllowed and "РАЗРЕШЁН" or "защищён"); button.serviceText:SetTextColor(row.maintenanceAllowed and .25 or .7,row.maintenanceAllowed and 1 or .7,row.maintenanceAllowed and .75 or .7); button.stateText:SetTextColor(row.sameFaction and row.enabled and .25 or 1,row.sameFaction and row.enabled and 1 or .35,row.sameFaction and row.enabled and .8 or .25);
				local chosen=row.name==UnBotSpecAudit.selectedAlt; button:SetBackdropColor(index%2==0 and .035 or .075,index%2==0 and .15 or .22,index%2==0 and .16 or .23,chosen and .98 or .82); button.separator:SetTexture(chosen and 1 or .18,chosen and .72 or .55,chosen and .18 or .58,chosen and .95 or .65); if chosen then selectedAltEntry=row; end
			else button.data=nil; button:Hide(); end
		end
		if not selectedAltEntry and altRows[1] then selectedAltEntry=altRows[1]; UnBotSpecAudit.selectedAlt=selectedAltEntry.name; end
		UnBotSpecAudit.altSelectedEntry=selectedAltEntry;
		if UnBotSpecAudit.altDetail then UnBotSpecAudit.altDetail:SetText(CenterAltDetails(selectedAltEntry)); end if UnBotSpecAudit.altStatus then UnBotSpecAudit.altStatus:SetText(UnBotAccountAlts and UnBotAccountAlts.StatusText() or "Модуль альтов недоступен."); end if UnBotSpecAudit.altMaintenanceCheck then UnBotSpecAudit.altMaintenanceCheck:SetChecked(selectedAltEntry and selectedAltEntry.maintenanceAllowed and true or false); end
		if UnBotSpecAudit.altStrategyButton then if selectedAltEntry and selectedAltEntry.sameFaction then UnBotSpecAudit.altStrategyButton:Enable(); else UnBotSpecAudit.altStrategyButton:Disable(); end end
	elseif activeTab=="beacons" and not statusOnly then
		local beaconRows=UnBotBeaconTravel and UnBotBeaconTravel.BuildRows and UnBotBeaconTravel.BuildRows() or {}; UnBotSpecAudit.beaconRows=beaconRows;
		local selectedBeaconEntry;
		for index,button in ipairs(UnBotSpecAudit.beaconButtons or {}) do
			local row=beaconRows[index];
			if row then
				button.data=row; button:Show();
				local beacon=row.beacon; local assigned=beacon and beacon.enabled~=false;
				button.nameText:SetText(row.name); button.zoneText:SetText(assigned and tostring(beacon.zoneName or "?") or "— не назначен —"); button.noteText:SetText(assigned and tostring((beacon.note and beacon.note~="") and beacon.note or "—") or "—"); button.usedText:SetText(assigned and ((tonumber(beacon.lastUsedAt) or 0)>0 and CenterDate(beacon.lastUsedAt,false) or "не использован") or "—"); button.pinText:SetText(assigned and (beacon.pinned and "ЗАКРЕПЛЁН" or "НЕ ЗАКРЕПЛЁН") or (row.isCurrent and "текущий" or (row.sameFaction and row.enabled and "доступен" or "недоступен")));
			button.pinText:SetTextColor(assigned and beacon.pinned and 1 or .65,assigned and beacon.pinned and .72 or .9,assigned and beacon.pinned and .18 or .9);
			local chosen=row.name==UnBotSpecAudit.selectedBeacon; button:SetBackdropColor(index%2==0 and .035 or .075,index%2==0 and .15 or .22,index%2==0 and .16 or .23,chosen and .98 or .82); button.separator:SetTexture(chosen and 1 or .18,chosen and .72 or .55,chosen and .18 or .58,chosen and .95 or .65); if chosen then selectedBeaconEntry=row; end
			else button.data=nil; button:Hide(); end
		end
		if not selectedBeaconEntry and beaconRows[1] then selectedBeaconEntry=beaconRows[1]; UnBotSpecAudit.selectedBeacon=selectedBeaconEntry.name; end
		if UnBotSpecAudit.beaconDetail then UnBotSpecAudit.beaconDetail:SetText(CenterBeaconDetails(selectedBeaconEntry)); end
		if UnBotSpecAudit.beaconNoteEdit and (not UnBotSpecAudit.beaconNoteEdit:HasFocus()) and UnBotSpecAudit.beaconNoteName~=UnBotSpecAudit.selectedBeacon then local beacon=selectedBeaconEntry and selectedBeaconEntry.beacon; UnBotSpecAudit.beaconNoteEdit:SetText(beacon and tostring(beacon.note or "") or ""); UnBotSpecAudit.beaconNoteName=UnBotSpecAudit.selectedBeacon; end
		local total,assigned,available=0,0,0; if UnBotBeaconTravel and UnBotBeaconTravel.GetCounts then total,assigned,available=UnBotBeaconTravel.GetCounts(); end if UnBotSpecAudit.beaconCounts then UnBotSpecAudit.beaconCounts:SetText("Текущий аккаунт / мир: "..tostring(total).."/10   Маяки: "..tostring(assigned).."   Доступно для нового маяка: "..tostring(available)); end
		local recommended,reason=nil,"модуль недоступен"; if UnBotBeaconTravel and UnBotBeaconTravel.Recommend then recommended,reason=UnBotBeaconTravel.Recommend(); end if UnBotSpecAudit.beaconRecommendation then UnBotSpecAudit.beaconRecommendation:SetText(recommended and ("Рекомендация: "..recommended.." — "..tostring(reason)..".") or ("Рекомендация недоступна: "..tostring(reason)..".")); end
	end
 if statusOnly and activeTab=="alts" and UnBotSpecAudit.altStatus then
  UnBotSpecAudit.altStatus:SetText(UnBotAccountAlts and UnBotAccountAlts.StatusText() or "Модуль альтов недоступен.");
 end
	local junkActive=UnBotJunkCleaner and UnBotJunkCleaner.active; local groupJunk=junkActive and UnBotJunkCleaner.currentGroupOnly; local bagActive=junkActive and not groupJunk and UnBotJunkCleaner.bagAuditOnly; local deepActive=junkActive and not groupJunk and not UnBotJunkCleaner.bagAuditOnly and UnBotJunkCleaner.deepVendorCleanup; local standardActive=junkActive and not groupJunk and not UnBotJunkCleaner.bagAuditOnly and not UnBotJunkCleaner.deepVendorCleanup; local groupBagActive=groupJunk and UnBotJunkCleaner.bagAuditOnly; local groupDeepActive=groupJunk and not UnBotJunkCleaner.bagAuditOnly and UnBotJunkCleaner.deepVendorCleanup; local groupStandardActive=groupJunk and not UnBotJunkCleaner.bagAuditOnly and not UnBotJunkCleaner.deepVendorCleanup; local fastRunning=UnBotFastJunkRaid and UnBotFastJunkRaid.active; local fastActive=fastRunning and not UnBotFastJunkRaid.currentGroupOnly; local groupFastActive=fastRunning and UnBotFastJunkRaid.currentGroupOnly; local altImportActive=UnBotAccountAlts and UnBotAccountAlts.active; local altDiscoveryActive=UnBotAccountAlts and UnBotAccountAlts.discoveryActive; local altActive=altImportActive or altDiscoveryActive; local beaconActive=UnBotBeaconTravel and UnBotBeaconTravel.active; local classRebuildPending=UnBotBotScanner and (UnBotBotScanner.pendingSpecBalanceClass or UnBotBotScanner.pendingTalentAudit); local busy=(UnBotBotScanner and UnBotBotScanner.active) or classRebuildPending or (UnBotDKSpecBalance and UnBotDKSpecBalance.active) or junkActive or fastRunning or altActive or beaconActive or (UnBotAltStrategies and (UnBotAltStrategies.active or #UnBotAltStrategies.queue>0)); UnBotSpecAudit.scanButton:SetText(UnBotBotScanner and (UnBotBotScanner.active or UnBotBotScanner.pendingTalentAudit or UnBotBotScanner.talentAuditRunning) and "Остановить обновление" or (UnBotRegistryRefresh and UnBotRegistryRefresh.Running() and "Остановить обновление" or "Обновить реестр"));
	busy=busy or (UnBotStrategySurvey and UnBotStrategySurvey.active);
 if UnBotSpecAudit.undatedButton then if busy then UnBotSpecAudit.undatedButton:Disable();else UnBotSpecAudit.undatedButton:Enable();end end
	if activeTab=="registry" and UnBotSpecAudit.registryAddButton then local roleBusy=UnBotSquadRoleAction and UnBotSquadRoleAction.active; local alreadyOnline=UnBotSpecAudit.selectedBot and UnBotSpecSummonIsInGroup and UnBotSpecSummonIsInGroup(UnBotSpecAudit.selectedBot) and UnBotRaidReserveOnline and UnBotRaidReserveOnline(UnBotSpecAudit.selectedBot); UnBotSpecAudit.registryAddButton:SetText(roleBusy and "Добавление..." or (alreadyOnline and "Уже в группе" or "Добавить в группу")); if busy or roleBusy or alreadyOnline or not selectedProfile then UnBotSpecAudit.registryAddButton:Disable(); else UnBotSpecAudit.registryAddButton:Enable(); end end
	UnBotSpecAudit.maintenanceButton:SetText(standardActive and "Остановить" or "Продать и купить"); UnBotSpecAudit.deepMaintenanceButton:SetText(deepActive and "Остановить" or "Продать всё лишнее"); UnBotSpecAudit.fastJunkButton:SetText(fastActive and "Остановить" or "Быстро продать хлам"); UnBotSpecAudit.bagAuditButton:SetText(bagActive and "Остановить" or "Проверить сумки");
	if busy and not ((UnBotRegistryRefresh and UnBotRegistryRefresh.Running()) or (UnBotBotScanner and (UnBotBotScanner.active or UnBotBotScanner.pendingTalentAudit or UnBotBotScanner.talentAuditRunning))) then UnBotSpecAudit.scanButton:Disable(); else UnBotSpecAudit.scanButton:Enable(); end if busy and not standardActive then UnBotSpecAudit.maintenanceButton:Disable(); else UnBotSpecAudit.maintenanceButton:Enable(); end if busy and not deepActive then UnBotSpecAudit.deepMaintenanceButton:Disable(); else UnBotSpecAudit.deepMaintenanceButton:Enable(); end if busy and not fastActive then UnBotSpecAudit.fastJunkButton:Disable(); else UnBotSpecAudit.fastJunkButton:Enable(); end if busy and not bagActive then UnBotSpecAudit.bagAuditButton:Disable(); else UnBotSpecAudit.bagAuditButton:Enable(); end if busy then UnBotSpecAudit.forceAllButton:Disable(); UnBotSpecAudit.saveReagentsButton:Disable(); else UnBotSpecAudit.forceAllButton:Enable(); UnBotSpecAudit.saveReagentsButton:Enable(); end for _,entry in ipairs(UnBotSpecAudit.reagentEdits or {}) do CenterSetEditEnabled(entry.edit,not busy); end
	if UnBotSpecAudit.discoverButton then
		local finding=UnBotBotScanner and UnBotBotScanner.active;
		UnBotSpecAudit.discoverButton:SetText(finding and "Остановить поиск" or "Найти новых ботов");
		if busy and not finding then UnBotSpecAudit.discoverButton:Disable(); else UnBotSpecAudit.discoverButton:Enable(); end
	end
	if activeTab=="current" and UnBotSpecAudit.groupMaintenanceButton then local serviceUnavailable=(groupCount+(groupAllowedAltCount or 0))==0; local botsUnavailable=groupCount==0; UnBotSpecAudit.groupMaintenanceButton:SetText(groupStandardActive and "Остановить" or "Продать и купить"); UnBotSpecAudit.groupDeepButton:SetText(groupDeepActive and "Остановить" or "Продать всё лишнее"); UnBotSpecAudit.groupFastButton:SetText(groupFastActive and "Остановить" or "Быстро продать хлам"); UnBotSpecAudit.groupBagButton:SetText(groupBagActive and "Остановить" or "Проверить сумки"); if (busy or serviceUnavailable) and not groupStandardActive then UnBotSpecAudit.groupMaintenanceButton:Disable(); else UnBotSpecAudit.groupMaintenanceButton:Enable(); end if (busy or botsUnavailable) and not groupDeepActive then UnBotSpecAudit.groupDeepButton:Disable(); else UnBotSpecAudit.groupDeepButton:Enable(); end if (busy or serviceUnavailable) and not groupFastActive then UnBotSpecAudit.groupFastButton:Disable(); else UnBotSpecAudit.groupFastButton:Enable(); end if (busy or botsUnavailable) and not groupBagActive then UnBotSpecAudit.groupBagButton:Disable(); else UnBotSpecAudit.groupBagButton:Enable(); end end
	if activeTab=="alts" and UnBotSpecAudit.altDiscoveryButton then UnBotSpecAudit.altDiscoveryButton:SetText(altDiscoveryActive and "Остановить поиск" or "Найти альтов автоматически"); if busy and not altDiscoveryActive then UnBotSpecAudit.altDiscoveryButton:Disable(); else UnBotSpecAudit.altDiscoveryButton:Enable(); end local hasAlt=selectedAltEntry~=nil; for _,button in ipairs(UnBotSpecAudit.altActionButtons or {}) do if busy or not hasAlt then button:Disable(); else button:Enable(); end end local factionUsable=hasAlt and selectedAltEntry.sameFaction; local factionKnown=hasAlt and selectedAltEntry.faction~=nil; if UnBotSpecAudit.altSummonButton and not factionUsable then UnBotSpecAudit.altSummonButton:Disable(); end if UnBotSpecAudit.altAddButton and not factionUsable then UnBotSpecAudit.altAddButton:Disable(); end if UnBotSpecAudit.altRecheckButton and factionKnown and not factionUsable then UnBotSpecAudit.altRecheckButton:Disable(); end if UnBotSpecAudit.altToggleButton then UnBotSpecAudit.altToggleButton:SetText(selectedAltEntry and (selectedAltEntry.enabled and "Отключить" or "Включить") or "Включить / отключить"); end if UnBotSpecAudit.altMaintenanceCheck then if busy or not factionUsable then UnBotSpecAudit.altMaintenanceCheck:Disable(); UnBotSpecAudit.altMaintenanceLabel:SetTextColor(.5,.5,.5); else UnBotSpecAudit.altMaintenanceCheck:Enable(); UnBotSpecAudit.altMaintenanceLabel:SetTextColor(1,.82,.18); end end end
	if activeTab=="beacons" and UnBotSpecAudit.beaconPlaceButton then
		local selected;
		for _,row in ipairs(UnBotSpecAudit.beaconRows or {}) do
			if row.name==UnBotSpecAudit.selectedBeacon then selected=row; break end
		end
		local assigned=selected and selected.beacon and selected.beacon.enabled~=false;
		local usable=selected and not selected.isCurrent and selected.enabled and selected.sameFaction;
		if busy or not usable then UnBotSpecAudit.beaconPlaceButton:Disable(); else UnBotSpecAudit.beaconPlaceButton:Enable(); end
		if busy or not assigned or not usable then UnBotSpecAudit.beaconTravelButton:Disable(); else UnBotSpecAudit.beaconTravelButton:Enable(); end
		if busy or not assigned then
			UnBotSpecAudit.beaconSaveNoteButton:Disable(); UnBotSpecAudit.beaconPinButton:Disable(); UnBotSpecAudit.beaconUnassignButton:Disable();
		else
			UnBotSpecAudit.beaconSaveNoteButton:Enable(); UnBotSpecAudit.beaconPinButton:Enable(); UnBotSpecAudit.beaconUnassignButton:Enable();
		end
		UnBotSpecAudit.beaconPinButton:SetText(assigned and selected.beacon.pinned and "Открепить" or "Закрепить");
		if UnBotSpecAudit.beaconCancelButton then
			if UnBotBeaconTravel and ((UnBotBeaconTravel.GetTask and UnBotBeaconTravel.GetTask()) or UnBotBeaconTravel.active) then UnBotSpecAudit.beaconCancelButton:Enable(); else UnBotSpecAudit.beaconCancelButton:Disable(); end
		end
		CenterSetEditEnabled(UnBotSpecAudit.beaconNoteEdit,not busy and selected~=nil);
	end
	if activeTab=="specs" then local auditBusy=(UnBotDKSpecBalance and UnBotDKSpecBalance.active) or (UnBotBotScanner and (UnBotBotScanner.pendingSpecBalanceClass or UnBotBotScanner.pendingTalentAudit)); for _,button in ipairs(UnBotSpecAudit.auditButtons or {}) do if busy or auditBusy then button:Disable(); else button:Enable(); end end if auditBusy then UnBotSpecAudit.stopAuditButton:Enable(); else UnBotSpecAudit.stopAuditButton:Disable(); end end
end

local function CenterCreateRegistryPanel(frame)
	local panel=CreateFrame("Frame",nil,frame); panel:SetPoint("TOPLEFT",20,-128); panel:SetWidth(970); panel:SetHeight(515); UnBotSpecAudit.registryModeButton=CenterCreateButton(panel,"Режим: Все",140,710,0,function() UnBotSpecAuditCycleTalentMode(); end); local searchLabel=panel:CreateFontString(nil,"OVERLAY","GameFontNormal"); searchLabel:SetPoint("TOPLEFT",2,-2); searchLabel:SetText("Поиск:");
	local search=CenterCreateEditBox(panel,180,22,false); search:SetPoint("LEFT",searchLabel,"RIGHT",8,0); search:SetJustifyH("LEFT"); if search.SetTextInsets then search:SetTextInsets(6,6,0,0); end search:SetScript("OnTextChanged",function() UnBotSpecAudit.registryOffset=0; UnBotSpecAuditRefresh(); end); UnBotSpecAudit.searchEdit=search;
	UnBotSpecAudit.filterButton=CenterCreateButton(panel,"Показать: Все",170,270,0,function() local order={all="quarantine",quarantine="reagents",reagents="junk",junk="all"}; UnBotSpecAudit.registryFilter=order[UnBotSpecAudit.registryFilter or "all"] or "all"; UnBotSpecAudit.registryOffset=0; UnBotSpecAuditRefresh(); end);
	UnBotSpecAudit.registryCountText=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); UnBotSpecAudit.registryCountText:SetPoint("TOPLEFT",455,-7);
	local header=CreateFrame("Frame",nil,panel); header:SetPoint("TOPLEFT",panel,"TOPLEFT",2,-28); header:SetWidth(676); header:SetHeight(22); header:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}}); header:SetBackdropColor(.04,.19,.20,.96); header:SetBackdropBorderColor(.3,.62,.64,.9);
	local function HeaderText(x,width,text,justify) local label=header:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); label:SetPoint("LEFT",header,"LEFT",x,0); label:SetWidth(width); label:SetJustifyH(justify or "LEFT"); label:SetText(text); label:SetTextColor(1,.82,.18); return label; end
	HeaderText(5,105,"ИМЯ"); HeaderText(112,155,"КЛАСС / СПЕЦИАЛИЗАЦИЯ"); HeaderText(270,65,"РЕЖИМ"); HeaderText(338,80,"СТАТУС"); HeaderText(421,87,"РЕАГЕНТЫ"); HeaderText(510,42,"СУМКИ","CENTER"); HeaderText(555,112,"ХЛАМ ПРОДАН");
	local list=CreateFrame("Frame",nil,panel); list:SetPoint("TOPLEFT",2,-50); list:SetWidth(690); list:SetHeight(440); list:EnableMouseWheel(true); UnBotSpecAudit.registryButtons={};
	for i=1,20 do local row=CenterCreateRow(list,676,-((i-1)*22)); row.nameText=CenterCreateText(row,5,105); row.specText=CenterCreateText(row,112,155); row.modeText=CenterCreateText(row,270,65); row.stateText=CenterCreateText(row,338,80); row.reagentText=CenterCreateText(row,421,87); row.bagText=CenterCreateText(row,510,42,"CENTER"); row.junkText=CenterCreateText(row,555,112); row:SetScript("OnClick",function(self) if self.data then UnBotSpecAudit.selectedBot=self.data.name; UnBotSpecAuditRefresh(); end end); table.insert(UnBotSpecAudit.registryButtons,row); end
	UnBotSpecAudit.registrySlider=CenterCreateSlider(panel,"UnBotBotCenterRegistryScrollBar",682,-50,438,"registryOffset"); list:SetScript("OnMouseWheel",function(self,delta) UnBotSpecAudit.registrySlider:SetValue((UnBotSpecAudit.registryOffset or 0)-delta*3); end); for _,row in ipairs(UnBotSpecAudit.registryButtons) do row:EnableMouseWheel(true); row:SetScript("OnMouseWheel",function(self,delta) UnBotSpecAudit.registrySlider:SetValue((UnBotSpecAudit.registryOffset or 0)-delta*3); end); end
	local detail=CreateFrame("Frame",nil,panel); detail:SetPoint("TOPLEFT",710,-28); detail:SetWidth(255); detail:SetHeight(410); detail:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=12,insets={left=3,right=3,top=3,bottom=3}}); detail:SetBackdropColor(0,0,0,.75); UnBotSpecAudit.registryDetail=detail:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); UnBotSpecAudit.registryDetail:SetPoint("TOPLEFT",10,-10); UnBotSpecAudit.registryDetail:SetWidth(235); UnBotSpecAudit.registryDetail:SetJustifyH("LEFT"); UnBotSpecAudit.registryDetail:SetJustifyV("TOP"); UnBotSpecAudit.registryAddButton=CenterCreateActionButton(panel,"Добавить в группу",180,710,-448,"Добавить выбранного бота","Отправит точный bot add для выбранного имени и ограниченно дождётся появления бота в вашей группе.","Спек и профиль не меняются, bot init и summon не отправляются. Явный выбор не заменяется случайным ботом.",function() if UnBotBotCenterAddExact then UnBotBotCenterAddExact(UnBotSpecAudit.selectedBot); else CenterMessage("Модуль точного добавления бота не загрузился."); end end); CenterCreateActionButton(panel,"Обслужить этого бота",180,710,-478,"Обслужить выбранного бота","Продаст его серый хлам и докупит реагенты.","Нужны пустая группа и открытый торговец.",function() if UnBotSpecAudit.selectedBot then UnBotJunkCleanerStartSingle(UnBotSpecAudit.selectedBot); else CenterMessage("Сначала выберите бота."); end end); return panel;
end

function UnBotSpecAudit.ShowSpecRowTooltip(self)
	local row=self.data; if not row or not GameTooltip then return; end
	GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine(row.classLabel.." — "..row.specLabel);
	GameTooltip:AddLine("Весь реестр: PvE "..row.modes.pve..", PvP "..row.modes.pvp..", неизвестно "..row.modes.unknown,1,1,1,true);
	GameTooltip:AddLine("В фильтре: всего "..row.total..", доступно "..row.available,1,1,1,true);
	GameTooltip:AddLine("Неизвестно: нет полного осмотра или однозначного совпадения с каталогом сервера.",1,.8,.3,true);
	GameTooltip:AddLine("Проверка читает всех ботов класса независимо от фильтра.",.65,.85,1,true);
	GameTooltip:Show();
end

local function CenterCreateSpecPanel(frame)
	local panel=CreateFrame("Frame",nil,frame); panel:SetPoint("TOPLEFT",20,-128); panel:SetWidth(970); panel:SetHeight(515); UnBotSpecAudit.specModeButton=CenterCreateButton(panel,"Режим: Все",130,575,0,function() UnBotSpecAuditCycleTalentMode(); end); local label=panel:CreateFontString(nil,"OVERLAY","GameFontNormal"); label:SetPoint("TOPLEFT",2,-3); label:SetText("Минимум на спек в выбранном режиме:"); local edit=CenterCreateEditBox(panel,42,22,true); edit:SetPoint("LEFT",label,"RIGHT",8,0); edit:SetMaxLetters(2); edit:SetText(tostring(UnBotSpecAudit.minimumCount or 8)); edit:SetScript("OnEnterPressed",function(self) CenterMinimum(true); self:ClearFocus(); UnBotSpecAuditRefresh(); end); UnBotSpecAudit.minimumEdit=edit; UnBotSpecAudit.unknownText=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); UnBotSpecAudit.unknownText:SetPoint("TOPLEFT",710,-8); UnBotSpecAudit.unknownText:SetWidth(255); UnBotSpecAudit.unknownText:SetJustifyH("LEFT");
	UnBotSpecAudit.strategySurveyButton=CenterCreateActionButton(panel,"Снимки стратегий классов",240,2,-492,"Сборщик co/nc по классам и спекам","Откроет отдельный проход по 31 варианту с источниками, прогрессом и пробелами. Полный проход: один обычный бот за раз; add, who, co ?, nc ?, leave, remove.","Без init, смены стратегий и применения профилей альтов. Для короткой проверки есть режим «Только группа».",function() if UnBotStrategySurvey then UnBotStrategySurvey.Open(); end end);
	UnBotSpecAudit.strategySurveyButton:SetHeight(20);
	UnBotSpecAudit.fullCatalogButton=CenterCreateActionButton(panel,"Каталог талантов",174,250,-492,"Полные шаблоны талантов сервера","Откроет отдельный сборщик полных шаблонов. Их снимки нужны, чтобы отличать PvE и PvP с одинаковыми суммами очков.","Меняет таланты только одного временного бота на класс; обычное обновление реестра читает класс и спек через who без смены талантов.",function() if UnBotFullTalentCatalog then UnBotFullTalentCatalog.Show(); end end); UnBotSpecAudit.fullCatalogButton:SetHeight(20);
	local header=CreateFrame("Frame",nil,panel); header:SetPoint("TOPLEFT",panel,"TOPLEFT",2,-29); header:SetWidth(535); header:SetHeight(22); header:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}}); header:SetBackdropColor(.04,.19,.20,.96); header:SetBackdropBorderColor(.3,.62,.64,.9);
	local function HeaderText(x,width,text,justify) local headerLabel=header:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); headerLabel:SetPoint("LEFT",header,"LEFT",x,0); headerLabel:SetWidth(width); headerLabel:SetJustifyH(justify or "LEFT"); headerLabel:SetText(text); headerLabel:SetTextColor(1,.82,.18); return headerLabel; end
	HeaderText(5,118,"КЛАСС"); HeaderText(126,119,"СПЕЦИАЛИЗАЦИЯ"); HeaderText(247,36,"PvE","CENTER"); HeaderText(285,36,"PvP","CENTER"); HeaderText(323,45,"НЕИЗВ.","CENTER"); HeaderText(372,90,"В ФИЛЬТРЕ","CENTER"); HeaderText(468,62,"НУЖНО","RIGHT");
	local list=CreateFrame("Frame",nil,panel); list:SetPoint("TOPLEFT",2,-52); list:SetWidth(552); list:SetHeight(398); list:EnableMouseWheel(true); UnBotSpecAudit.specButtons={}; for i=1,18 do local row=CenterCreateRow(list,535,-((i-1)*22)); row.classText=CenterCreateText(row,5,118); row.specText=CenterCreateText(row,126,119); row.pveText=CenterCreateText(row,247,36,"CENTER"); row.pveText:SetTextColor(.35,1,.6); row.pvpText=CenterCreateText(row,285,36,"CENTER"); row.pvpText:SetTextColor(1,.55,.4); row.unknownModeText=CenterCreateText(row,323,45,"CENTER"); row.countText=CenterCreateText(row,372,90,"CENTER"); row.deficitText=CenterCreateText(row,468,62,"RIGHT"); row:SetScript("OnEnter",UnBotSpecAudit.ShowSpecRowTooltip); row:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide(); end end); row:SetScript("OnClick",function(self) if self.data then UnBotSpecAudit.selectedClass=self.data.className; UnBotSpecAudit.selectedSpec=self.data.specName; UnBotSpecAuditRefresh(); end end); table.insert(UnBotSpecAudit.specButtons,row); end UnBotSpecAudit.specSlider=CenterCreateSlider(panel,"UnBotBotCenterSpecScrollBar",542,-52,394,"specOffset"); list:SetScript("OnMouseWheel",function(self,delta) UnBotSpecAudit.specSlider:SetValue((UnBotSpecAudit.specOffset or 0)-delta*3); end); for _,row in ipairs(UnBotSpecAudit.specButtons) do row:EnableMouseWheel(true); row:SetScript("OnMouseWheel",function(self,delta) UnBotSpecAudit.specSlider:SetValue((UnBotSpecAudit.specOffset or 0)-delta*3); end); end
	local detail=CreateFrame("Frame",nil,panel); detail:SetPoint("TOPLEFT",575,-30); detail:SetWidth(390); detail:SetHeight(415); detail:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=12,insets={left=3,right=3,top=3,bottom=3}}); detail:SetBackdropColor(0,0,0,.75); UnBotSpecAudit.specDetail=detail:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); UnBotSpecAudit.specDetail:SetPoint("TOPLEFT",10,-10); UnBotSpecAudit.specDetail:SetWidth(365); UnBotSpecAudit.specDetail:SetJustifyH("LEFT"); UnBotSpecAudit.specDetail:SetJustifyV("TOP"); UnBotSpecAudit.auditButtons={};
	local b1=CenterCreateActionButton(panel,"Проверить всех",128,2,-466,"Проверить специализации","Последовательно выполнит add -> who -> summon -> осмотр -> remove и обновит последний известный спек. Ничего менять не будет.","Нужна пустая группа.",function() UnBotSpecAuditStart(nil,false,CenterMinimum(true)); end); table.insert(UnBotSpecAudit.auditButtons,b1); local b2=CenterCreateActionButton(panel,"Проверить класс",138,140,-466,"Проверить выбранный класс","Обновит фактические специализации уже известных ботов выбранного класса без init.","Нужна пустая группа.",function() if UnBotSpecAudit.selectedClass then UnBotSpecAuditStart(UnBotSpecAudit.selectedClass,false,CenterMinimum(true)); else CenterMessage("Сначала выберите класс."); end end); table.insert(UnBotSpecAudit.auditButtons,b2); local b3=CenterCreateActionButton(panel,"Пересобрать класс",174,288,-466,"Пересобрать класс в выбранном режиме","Выберите PvE или PvP. Сначала обновляются список и полные таланты класса, затем точные шаблоны сервера закрывают дефицит.","Меняются только подтверждённые боты выбранного режима с запасом выше минимума. Неизвестные и другой режим не используются. Требуется пустая группа.",function()
		local mode=UnBotSpecAudit.talentMode;
		if mode~="pve" and mode~="pvp" then CenterMessage("Для пересборки выберите фильтр PvE или PvP."); return; end
		if not UnBotFullTalentCatalog.Get(UnBotSpecAudit.selectedClass,80) then CenterMessage("Сначала соберите полный каталог талантов выбранного класса."); return; end
		UnBotSpecCountBalanceStart(CenterMinimum(true),UnBotSpecAudit.selectedClass,mode);
	end); table.insert(UnBotSpecAudit.auditButtons,b3); local safety=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); safety:SetPoint("LEFT",panel,"LEFT",474,-466); safety:SetWidth(305); safety:SetJustifyH("LEFT"); safety:SetText("Проверка читает весь класс. Пересборка: выбранный PvE/PvP, точные шаблоны, без продолжения после /reload."); safety:SetTextColor(.55,.85,.85); UnBotSpecAudit.stopAuditButton=CenterCreateButton(panel,"Остановить",90,797,-466,function() UnBotClassSpecRebuildStop(); end); table.insert(UnBotSpecAudit.auditButtons,UnBotSpecAudit.stopAuditButton); return panel;
end

local function CenterCreateReagentPanel(frame)
	local panel=CreateFrame("Frame",nil,frame); panel:SetPoint("TOPLEFT",20,-128); panel:SetWidth(970); panel:SetHeight(515);
	local helpBox=CreateFrame("Frame",nil,panel); helpBox:SetPoint("TOPLEFT",4,-2); helpBox:SetWidth(940); helpBox:SetHeight(42); helpBox:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=10,insets={left=3,right=3,top=3,bottom=3}}); helpBox:SetBackdropColor(.03,.03,.03,.95); helpBox:SetBackdropBorderColor(.35,.35,.35,.9);
	local help=helpBox:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); help:SetPoint("LEFT",helpBox,"LEFT",12,0); help:SetWidth(916); help:SetJustifyH("LEFT"); help:SetText("Укажите, сколько предметов должен носить каждый бот. UnBot докупит недостающее. 0 — не покупать.");
	local classHeader=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); classHeader:SetPoint("TOPLEFT",18,-52); classHeader:SetText("КЛАСС"); classHeader:SetTextColor(.65,.65,.65);
	local reagentHeader=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); reagentHeader:SetPoint("TOPLEFT",210,-52); reagentHeader:SetText("РЕАГЕНТ"); reagentHeader:SetTextColor(.65,.65,.65);
	local targetHeader=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); targetHeader:SetPoint("TOPLEFT",670,-52); targetHeader:SetText("СКОЛЬКО НУЖНО"); targetHeader:SetTextColor(.65,.65,.65);
	UnBotSpecAudit.reagentEdits={};
	local y=-72;
	local ordered={"dk","druid","mage","paladin","priest","shaman"};
	local classTokens={dk="DEATHKNIGHT",druid="DRUID",mage="MAGE",paladin="PALADIN",priest="PRIEST",shaman="SHAMAN"};
	for _,className in ipairs(ordered) do
		local items=(UnBotJunkCleanerReagentTargets and UnBotJunkCleanerReagentTargets[className]) or {};
		local groupHeight=math.max(38,#items*30+8);
		local group=CreateFrame("Frame",nil,panel); group:SetPoint("TOPLEFT",4,y); group:SetWidth(940); group:SetHeight(groupHeight); group:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=10,insets={left=3,right=3,top=3,bottom=3}}); group:SetBackdropColor(.025,.025,.025,.84); group:SetBackdropBorderColor(.25,.25,.25,.85);
		local color=RAID_CLASS_COLORS and RAID_CLASS_COLORS[classTokens[className]];
		local classBand=group:CreateTexture(nil,"BACKGROUND"); classBand:SetPoint("TOPLEFT",group,"TOPLEFT",4,-4); classBand:SetPoint("BOTTOMLEFT",group,"BOTTOMLEFT",4,4); classBand:SetWidth(160); classBand:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background"); classBand:SetVertexColor(color and color.r or .8,color and color.g or .65,color and color.b or .15,.28);
		local classText=group:CreateFontString(nil,"OVERLAY","GameFontNormal"); classText:SetPoint("TOPLEFT",group,"TOPLEFT",14,-12); classText:SetWidth(140); classText:SetJustifyH("LEFT"); classText:SetText(classLabels[className] or className); if color then classText:SetTextColor(color.r,color.g,color.b); end
		for index,item in ipairs(items) do
			local row=CreateFrame("Frame",nil,group); row:SetPoint("TOPLEFT",group,"TOPLEFT",170,-4-((index-1)*30)); row:SetWidth(766); row:SetHeight(28);
			local rowBg=row:CreateTexture(nil,"BACKGROUND"); rowBg:SetAllPoints(row); rowBg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background"); rowBg:SetVertexColor(index%2==0 and .16 or .11,index%2==0 and .16 or .11,index%2==0 and .16 or .11,.58);
			local itemName=GetItemInfo and GetItemInfo(item.id) or nil;
			local itemTexture=GetItemIcon and GetItemIcon(item.id) or nil;
			local icon=row:CreateTexture(nil,"ARTWORK"); icon:SetWidth(22); icon:SetHeight(22); icon:SetPoint("LEFT",row,"LEFT",7,0); icon:SetTexture(itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark");
			local itemText=row:CreateFontString(nil,"OVERLAY","GameFontHighlight"); itemText:SetPoint("LEFT",row,"LEFT",36,0); itemText:SetWidth(440); itemText:SetJustifyH("LEFT"); itemText:SetText(tostring(itemName or item.label));
			local edit=CenterCreateEditBox(row,70,22,true); edit:SetPoint("LEFT",row,"LEFT",500,0); edit:SetMaxLetters(4); edit:SetText(tostring(UnBotReagentTargetGet(className,item.id,item.target))); edit:SetScript("OnEnterPressed",function(self) CenterSaveReagents(); end); table.insert(UnBotSpecAudit.reagentEdits,{className=className,item=item,edit=edit});
		end
		y=y-groupHeight-5;
	end
	local actions=CreateFrame("Frame",nil,panel); actions:SetPoint("TOPLEFT",4,-422); actions:SetWidth(940); actions:SetHeight(90); actions:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=10,insets={left=3,right=3,top=3,bottom=3}}); actions:SetBackdropColor(.025,.025,.025,.92); actions:SetBackdropBorderColor(.3,.3,.3,.9); local actionsTitle=actions:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); actionsTitle:SetPoint("TOPLEFT",12,-7); actionsTitle:SetText("ДЕЙСТВИЯ");
	UnBotSpecAudit.saveReagentsButton=CenterCreateActionButton(actions,"Сохранить",130,10,-23,"Сохранить","Запомнит введённые числа.",nil,CenterSaveReagents);
	UnBotSpecAudit.forceAllButton=CenterCreateActionButton(actions,"Проверить всех заново",170,145,-23,"Проверить всех заново","Следующее обслуживание пройдёт по всем ботам.","После этого нажмите «Продать и купить».",function() if UnBotJunkCleanerForceAllNow then UnBotJunkCleanerForceAllNow(); end end);
	UnBotSpecAudit.maintenanceButton=CenterCreateActionButton(actions,"Продать и купить",190,320,-23,"Продать хлам и купить реагенты","Продаёт серый хлам и докупает нужные предметы.","Нужны пустая группа и торговец.",function() if UnBotJunkCleaner and UnBotJunkCleaner.active and not UnBotJunkCleaner.bagAuditOnly and not UnBotJunkCleaner.deepVendorCleanup then UnBotBotServiceStartMaintenance(); else CenterSaveReagents(); if UnBotBotServiceStartMaintenance then UnBotBotServiceStartMaintenance(); end end end);
	UnBotSpecAudit.deepMaintenanceButton=CenterCreateActionButton(actions,"Продать всё лишнее",220,515,-23,"Продать всё лишнее","Продаёт серый хлам и проверенное запасное снаряжение; докупает недостающие реагенты.","Классовые и профессиональные предметы защищены. Неизвестные предметы остаются. Нужен торговец.",function() if UnBotJunkCleaner and UnBotJunkCleaner.active and UnBotJunkCleaner.deepVendorCleanup then UnBotBotServiceStartDeepMaintenance(); else CenterSaveReagents(); if UnBotBotServiceStartDeepMaintenance then UnBotBotServiceStartDeepMaintenance(); end end end);
	UnBotSpecAudit.fastJunkButton=CenterCreateActionButton(actions,"Быстро продать хлам",190,10,-52,"Быстро продать серый хлам","Быстро продаёт только серые предметы.","Нужны пустая группа и торговец.",function() if UnBotFastJunkRaidStart then UnBotFastJunkRaidStart(); end end);
	UnBotSpecAudit.bagAuditButton=CenterCreateActionButton(actions,"Проверить сумки",190,205,-52,"Проверить свободное место","Покажет, сколько свободного места у каждого бота.","Нужна пустая группа.",function() if UnBotBagSpaceAuditStart then UnBotBagSpaceAuditStart(); end end);
	local note=actions:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); note:SetPoint("TOPLEFT",410,-56); note:SetWidth(515); note:SetJustifyH("LEFT"); note:SetText("Наведите мышь на кнопку — появится короткая подсказка."); return panel;
end

local function CenterCreateAltPanel(frame)
	local panel=CreateFrame("Frame",nil,frame); panel:SetPoint("TOPLEFT",20,-128); panel:SetWidth(970); panel:SetHeight(550);
	local helpBox=CreateFrame("Frame",nil,panel); helpBox:SetPoint("TOPLEFT",4,-2); helpBox:SetWidth(940); helpBox:SetHeight(58); helpBox:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=10,insets={left=3,right=3,top=3,bottom=3}}); helpBox:SetBackdropColor(.03,.03,.03,.95); helpBox:SetBackdropBorderColor(.35,.35,.35,.9);
	local help=helpBox:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); help:SetPoint("TOPLEFT",helpBox,"TOPLEFT",12,-9); help:SetWidth(916); help:SetJustifyH("LEFT"); help:SetText("Выберите альта слева. Справа — его профиль и текущие стратегии. Кнопка «Редактировать стратегии» открывает отдельное окно. По умолчанию UnBot их не меняет. Личный профиль применяется только после сохранения; квесты, лут и следование настраиваются отдельно от боевой роли.");
	UnBotSpecAudit.altNamesEdit=nil; UnBotSpecAudit.altImportButton=nil;
	UnBotSpecAudit.altDiscoveryButton=CenterCreateActionButton(panel,"Найти альтов автоматически",240,4,-69,"Найти альтов автоматически","Сохранит имена и классы из серверного Bot roster без подключения и телепортации альтов. Известные сведения сохраняются.","Работает только вне группы, чтобы случайные боты состава не попали в список альтов.",function() if not UnBotAccountAlts then return; end if UnBotAccountAlts.discoveryActive then UnBotAccountAlts.Stop("Автопоиск альтов остановлен пользователем."); else UnBotAccountAlts.StartDiscovery(); end end);
	UnBotSpecAudit.altStatus=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); UnBotSpecAudit.altStatus:SetPoint("TOPLEFT",254,-75); UnBotSpecAudit.altStatus:SetWidth(550); UnBotSpecAudit.altStatus:SetJustifyH("LEFT");
	UnBotSpecAudit.altLootHelpButton=CenterCreateActionButton(panel,"Справка по луту",130,814,-69,"Справка по луту","Как включить nc loot в личном редакторе, правила добычи и квестовый лут.",nil,function() UnBotLootControl.Open(); end);
	local listHeader=CreateFrame("Frame",nil,panel); listHeader:SetPoint("TOPLEFT",4,-103); listHeader:SetWidth(535); listHeader:SetHeight(24); listHeader:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}}); listHeader:SetBackdropColor(.04,.19,.20,.96); listHeader:SetBackdropBorderColor(.3,.62,.64,.9);
	local function AltHeaderText(x,width,text,justify) local label=listHeader:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); label:SetPoint("LEFT",listHeader,"LEFT",x,0); label:SetWidth(width); label:SetJustifyH(justify or "LEFT"); label:SetText(text); label:SetTextColor(1,.82,.18); return label; end
	AltHeaderText(7,105,"ИМЯ"); AltHeaderText(115,176,"КЛАСС / СПЕК"); AltHeaderText(295,70,"ФРАКЦИЯ"); AltHeaderText(369,68,"СТАТУС"); AltHeaderText(441,70,"СЕРВИС","RIGHT");
	local list=CreateFrame("Frame",nil,panel); list:SetPoint("TOPLEFT",4,-127); list:SetWidth(535); list:SetHeight(332); list:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=10,insets={left=3,right=3,top=3,bottom=3}}); list:SetBackdropColor(.025,.025,.025,.9); list:SetBackdropBorderColor(.25,.45,.46,.9);
	UnBotSpecAudit.altButtons={};
	list:EnableMouseWheel(true); list:SetScript("OnMouseWheel",function(self,delta) UnBotSpecAudit.altOffset=math.max(0,math.min((UnBotSpecAudit.altOffset or 0)-delta*3,math.max(0,#(UnBotSpecAudit.altRows or {})-15))); UnBotSpecAuditRefresh(); end);
	for i=1,15 do local row=CenterCreateRow(list,519,-5-((i-1)*22)); row.nameText=CenterCreateText(row,7,105); row.profileText=CenterCreateText(row,115,176); row.factionText=CenterCreateText(row,295,70); row.stateText=CenterCreateText(row,369,68); row.serviceText=CenterCreateText(row,441,70,"RIGHT"); row:SetScript("OnClick",function(self) if self.data then UnBotSpecAudit.selectedAlt=self.data.name; UnBotSpecAuditRefresh(); end end); table.insert(UnBotSpecAudit.altButtons,row); end
	local detail=CreateFrame("Frame",nil,panel); detail:SetPoint("TOPLEFT",553,-103); detail:SetWidth(391); detail:SetHeight(356); detail:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=10,insets={left=3,right=3,top=3,bottom=3}}); detail:SetBackdropColor(.015,.045,.05,.92); detail:SetBackdropBorderColor(.3,.62,.64,.9);
	UnBotSpecAudit.altDetail=detail:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); UnBotSpecAudit.altDetail:SetPoint("TOPLEFT",12,-12); UnBotSpecAudit.altDetail:SetWidth(366); UnBotSpecAudit.altDetail:SetHeight(245); UnBotSpecAudit.altDetail:SetJustifyH("LEFT"); UnBotSpecAudit.altDetail:SetJustifyV("TOP");
	UnBotSpecAudit.altStrategyButton=CenterCreateActionButton(detail,"Редактировать стратегии",260,12,-264,"Стратегии выбранного альта","Откроет личные боевые и небоевые стратегии, пресеты и русские пояснения. Изменения сохраняются на профиле альта и переживают повторный поиск.",nil,function() if UnBotAltStrategies then UnBotAltStrategies.Open(UnBotSpecAudit.selectedAlt); end end);
	UnBotSpecAudit.altMaintenanceCheck=CreateFrame("CheckButton",nil,detail,"UICheckButtonTemplate"); UnBotSpecAudit.altMaintenanceCheck:SetWidth(24); UnBotSpecAudit.altMaintenanceCheck:SetHeight(24); UnBotSpecAudit.altMaintenanceCheck:SetPoint("BOTTOMLEFT",detail,"BOTTOMLEFT",8,12); UnBotSpecAudit.altMaintenanceCheck:SetScript("OnClick",function() if UnBotAccountAlts and UnBotAccountAlts.SetMaintenanceAllowed then UnBotAccountAlts.SetMaintenanceAllowed(UnBotSpecAudit.selectedAlt,UnBotSpecAudit.altMaintenanceCheck:GetChecked()); end end); UnBotSpecAudit.altMaintenanceCheck:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_TOP"); GameTooltip:AddLine("Разрешить безопасное обслуживание",1,.82,.18); GameTooltip:AddLine("Только серый хлам и классовые реагенты, только когда альт уже онлайн в текущей группе.",1,1,1,true); GameTooltip:AddLine("Глубокая продажа, полные проходы реестра и проверка сумок останутся запрещены.",1,.35,.2,true); GameTooltip:Show(); end); UnBotSpecAudit.altMaintenanceCheck:SetScript("OnLeave",function() GameTooltip:Hide(); end);
	UnBotSpecAudit.altMaintenanceLabel=detail:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); UnBotSpecAudit.altMaintenanceLabel:SetPoint("LEFT",UnBotSpecAudit.altMaintenanceCheck,"RIGHT",2,0); UnBotSpecAudit.altMaintenanceLabel:SetWidth(340); UnBotSpecAudit.altMaintenanceLabel:SetJustifyH("LEFT"); UnBotSpecAudit.altMaintenanceLabel:SetText("Разрешить продажу хлама и закупку реагентов");
	local function Selected() return UnBotSpecAudit.selectedAlt; end
	UnBotSpecAudit.altActionButtons={};
	local summon=CenterCreateActionButton(panel,"Подключить и призвать",190,4,-470,"Призвать альта","Подключит персонажа по имени; summon и follow выполняются с паузами. Затем сверяет только явно сохранённый личный профиль стратегий.","Без личного профиля стратегии сервера сохраняются; who и обязательного квестового профиля нет.",function() if UnBotAccountAlts then UnBotAccountAlts.Summon(Selected()); end end); UnBotSpecAudit.altSummonButton=summon; table.insert(UnBotSpecAudit.altActionButtons,summon);
	local recheck=CenterCreateActionButton(panel,"Обновить сведения",180,199,-470,"Обновить сведения об альте","Запросит who только у альта, уже подключённого к текущей группе. Не подключает и не телепортирует персонажа.","Для неизвестной фракции один раз войдите за альта с включённым UnBot и повторите поиск.",function() if UnBotAccountAlts then UnBotAccountAlts.Recheck(Selected()); end end); UnBotSpecAudit.altRecheckButton=recheck; table.insert(UnBotSpecAudit.altActionButtons,recheck);
	UnBotSpecAudit.altToggleButton=CenterCreateActionButton(panel,"Включить / отключить",165,384,-470,"Доступность в составах","Отключённый альт остаётся защищённым, но сохранённые составы не смогут его вызвать.",nil,function() if UnBotAccountAlts then UnBotAccountAlts.ToggleEnabled(Selected()); end end); table.insert(UnBotSpecAudit.altActionButtons,UnBotSpecAudit.altToggleButton);
	local add=CenterCreateActionButton(panel,"Добавить в состав",165,554,-470,"Добавить именной слот","Добавит конкретного альта в редактор состава. Такой слот сохраняется в обычных и боссовых пресетах.","В состав можно добавить только альта текущей фракции.",function() if UnBotSquadBuilderAddAccountAlt then UnBotSquadBuilderAddAccountAlt(Selected()); end if UnBotSquadBuilderShow then UnBotSquadBuilderShow(); end end); UnBotSpecAudit.altAddButton=add; table.insert(UnBotSpecAudit.altActionButtons,add);
	local remove=CenterCreateActionButton(panel,"Убрать из группы",170,724,-470,"Отключить альта","Отправит leave, удалит из группы и выполнит bot remove. Профиль и защита сохранятся.",nil,function() if UnBotAccountAlts then UnBotAccountAlts.RemoveFromGroup(Selected()); end end); table.insert(UnBotSpecAudit.altActionButtons,remove);
	local forget=CenterCreateActionButton(panel,"Забыть",65,899,-470,"Удалить из списка альтов","Снимет защитную пометку и удалит именной слот из открытого состава. Профиль общего реестра не удаляется.","Используйте только для ошибочно добавленного имени.",function() if UnBotAccountAlts then UnBotAccountAlts.Forget(Selected()); end end); table.insert(UnBotSpecAudit.altActionButtons,forget);
	return panel;
end

function UnBotSpecAudit.ShowAltsTab(tab)
	local f=UnBotSpecAudit.altsPanel;if not f then return; end
	tab=tab=="linked" and "linked" or "own";UnBotSpecAudit.altsTab=tab;
	UnBotChatRouting.Storage().selectedAltsTab=tab;
	for key,panel in pairs(f.pages) do if key==tab then panel:Show();else panel:Hide();end end
	for key,button in pairs(f.buttons) do button:SetButtonState(key==tab and "PUSHED" or "NORMAL",key==tab);end
end

function UnBotSpecAudit.CreateAltsPanel(frame)
	local panel=CreateFrame("Frame",nil,frame);panel:SetPoint("TOPLEFT",20,-128);panel:SetWidth(970);panel:SetHeight(550);panel:Hide();
	UnBotSpecAudit.altsPanel=panel;
	local own=CenterCreateAltPanel(panel);own:ClearAllPoints();own:SetPoint("TOPLEFT",panel,"TOPLEFT",0,-34);own:SetHeight(516);own:Hide();
	panel.pages={own=own,linked=UnBotChatRouting.CreateLinkedPanel(panel)};
	panel.buttons={own=CenterCreateButton(panel,"Свои альты",180,4,-2,function()UnBotSpecAudit.ShowAltsTab("own");end),
		linked=CenterCreateButton(panel,"Связанные аккаунты",230,192,-2,function()UnBotSpecAudit.ShowAltsTab("linked");end)};
	panel.questButton=CenterCreateButton(panel,"Задания альтов…",200,434,-2,function() if UnBotAltQuests then UnBotAltQuests.Show(); end end);
	panel:SetScript("OnShow",function()UnBotSpecAudit.ShowAltsTab(UnBotChatRouting.Storage().selectedAltsTab or "own");end);
	panel:SetScript("OnHide",function()for _,page in pairs(panel.pages) do page:Hide();end end);
	return panel;
end

local function CenterCreateBeaconPanel(frame)
	local panel=CreateFrame("Frame",nil,frame); panel:SetPoint("TOPLEFT",20,-128); panel:SetWidth(970); panel:SetHeight(515);
	local helpBox=CreateFrame("Frame",nil,panel); helpBox:SetPoint("TOPLEFT",4,-2); helpBox:SetWidth(940); helpBox:SetHeight(58); helpBox:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=10,insets={left=3,right=3,top=3,bottom=3}}); helpBox:SetBackdropColor(.03,.03,.03,.95); helpBox:SetBackdropBorderColor(.35,.35,.35,.9);
	local help=helpBox:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); help:SetPoint("TOPLEFT",helpBox,"TOPLEFT",12,-9); help:SetWidth(916); help:SetJustifyH("LEFT"); help:SetText("Маяк — припаркованный альт аккаунта. Установка требует пустой группы; перед переходом UnBot сам распустит текущую группу и только затем выйдет. Персонажа на экране выбора вы выбираете вручную.");
	UnBotSpecAudit.beaconCounts=panel:CreateFontString(nil,"OVERLAY","GameFontNormal"); UnBotSpecAudit.beaconCounts:SetPoint("TOPLEFT",12,-72); UnBotSpecAudit.beaconCounts:SetTextColor(1,.82,.18);
	UnBotSpecAudit.beaconRecommendation=panel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); UnBotSpecAudit.beaconRecommendation:SetPoint("TOPLEFT",330,-73); UnBotSpecAudit.beaconRecommendation:SetWidth(610); UnBotSpecAudit.beaconRecommendation:SetJustifyH("LEFT");
	local listHeader=CreateFrame("Frame",nil,panel); listHeader:SetPoint("TOPLEFT",4,-100); listHeader:SetWidth(616); listHeader:SetHeight(24); listHeader:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=2,right=2,top=2,bottom=2}}); listHeader:SetBackdropColor(.04,.19,.20,.96); listHeader:SetBackdropBorderColor(.3,.62,.64,.9);
	local function Header(x,width,text,justify) local label=listHeader:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); label:SetPoint("LEFT",listHeader,"LEFT",x,0); label:SetWidth(width); label:SetJustifyH(justify or "LEFT"); label:SetText(text); label:SetTextColor(1,.82,.18); return label; end
	Header(7,94,"ПЕРСОНАЖ"); Header(103,145,"МЕСТО"); Header(252,175,"ЗАМЕТКА"); Header(431,95,"ИСПОЛЬЗОВАН"); Header(528,76,"СТАТУС","RIGHT");
	local list=CreateFrame("Frame",nil,panel); list:SetPoint("TOPLEFT",4,-124); list:SetWidth(616); list:SetHeight(247); list:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=10,insets={left=3,right=3,top=3,bottom=3}}); list:SetBackdropColor(.025,.025,.025,.9); list:SetBackdropBorderColor(.25,.45,.46,.9);
	UnBotSpecAudit.beaconButtons={};
	for i=1,10 do local row=CenterCreateRow(list,600,-5-((i-1)*22)); row.nameText=CenterCreateText(row,7,94); row.zoneText=CenterCreateText(row,103,145); row.noteText=CenterCreateText(row,252,175); row.usedText=CenterCreateText(row,431,95); row.pinText=CenterCreateText(row,528,70,"RIGHT"); row:SetScript("OnClick",function(self) if self.data then UnBotSpecAudit.selectedBeacon=self.data.name; UnBotSpecAudit.beaconNoteName=nil; UnBotSpecAuditRefresh(); end end); table.insert(UnBotSpecAudit.beaconButtons,row); end
	local detail=CreateFrame("Frame",nil,panel); detail:SetPoint("TOPLEFT",632,-100); detail:SetWidth(312); detail:SetHeight(271); detail:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=10,insets={left=3,right=3,top=3,bottom=3}}); detail:SetBackdropColor(.015,.045,.05,.92); detail:SetBackdropBorderColor(.3,.62,.64,.9);
	local detailTitle=detail:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); detailTitle:SetPoint("TOPLEFT",detail,"TOPLEFT",12,-10); detailTitle:SetText("КАРТОЧКА МАЯКА"); detailTitle:SetTextColor(1,.82,.18);
	local detailLine=detail:CreateTexture(nil,"BORDER"); detailLine:SetHeight(1); detailLine:SetPoint("TOPLEFT",detail,"TOPLEFT",10,-29); detailLine:SetPoint("TOPRIGHT",detail,"TOPRIGHT",-10,-29); detailLine:SetTexture(.18,.55,.58,.75);
	UnBotSpecAudit.beaconDetail=detail:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); UnBotSpecAudit.beaconDetail:SetPoint("TOPLEFT",detail,"TOPLEFT",12,-39); UnBotSpecAudit.beaconDetail:SetWidth(288); UnBotSpecAudit.beaconDetail:SetJustifyH("LEFT"); UnBotSpecAudit.beaconDetail:SetJustifyV("TOP");
	local noteLabel=panel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); noteLabel:SetPoint("TOPLEFT",472,-379); noteLabel:SetText("ЗАМЕТКА / ЗАЧЕМ НУЖЕН МАЯК (НЕОБЯЗАТЕЛЬНО)"); noteLabel:SetTextColor(1,.82,.18);
	UnBotSpecAudit.beaconNoteEdit=CenterCreateEditBox(panel,312,28,false); UnBotSpecAudit.beaconNoteEdit:ClearAllPoints(); UnBotSpecAudit.beaconNoteEdit:SetPoint("TOPLEFT",472,-398); UnBotSpecAudit.beaconNoteEdit:SetJustifyH("LEFT"); UnBotSpecAudit.beaconNoteEdit:SetMaxLetters(160); UnBotSpecAudit.beaconNoteEdit:SetScript("OnEnterPressed",function(self) if UnBotBeaconTravel then UnBotBeaconTravel.SetNote(UnBotSpecAudit.selectedBeacon,self:GetText()); self:ClearFocus(); end end);
	local recommendation=CenterCreateActionButton(panel,"Выбрать рекомендацию",190,4,-382,"Выбрать рекомендуемого персонажа","Сначала выбирает неназначенного персонажа. Если свободных нет — самый давно не использовавшийся незакреплённый маяк.","Ничего не перемещает без отдельного нажатия «Поставить здесь».",function() if UnBotBeaconTravel then local name,reason=UnBotBeaconTravel.Recommend(); if name then UnBotSpecAudit.selectedBeacon=name; UnBotSpecAudit.beaconNoteName=nil; UnBotSpecAuditRefresh(); CenterMessage("Рекомендован "..name..": "..tostring(reason).."."); else CenterMessage("Нет кандидата: "..tostring(reason).."."); end end end);
	local actions=CreateFrame("Frame",nil,panel); actions:SetPoint("TOPLEFT",4,-423); actions:SetWidth(940); actions:SetHeight(83); actions:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=10,insets={left=3,right=3,top=3,bottom=3}}); actions:SetBackdropColor(.025,.025,.025,.92); actions:SetBackdropBorderColor(.3,.3,.3,.9);
	local function Selected() return UnBotSpecAudit.selectedBeacon; end
	local function Note() return UnBotSpecAudit.beaconNoteEdit and UnBotSpecAudit.beaconNoteEdit:GetText() or ""; end
	UnBotSpecAudit.beaconSaveNoteButton=CenterCreateActionButton(panel,"Сохранить заметку",155,789,-398,"Сохранить заметку","Сохраняет необязательное пояснение к текущему месту маяка.",nil,function() if UnBotBeaconTravel then UnBotBeaconTravel.SetNote(Selected(),Note()); end end);
	UnBotSpecAudit.beaconPlaceButton=CenterCreateActionButton(actions,"Поставить здесь",150,8,-12,"Поставить маяк здесь","Подключит выбранного альта, призовёт его к текущей точке, запишет зону и заметку, затем отключит.","Только вне боя и с полностью пустой группой. При переносе прежняя точка попадёт в историю.",function() if UnBotBeaconTravel then UnBotBeaconTravel.StartPlace(Selected(),Note()); end end);
	UnBotSpecAudit.beaconTravelButton=CenterCreateActionButton(actions,"Переместиться",145,163,-12,"Переместиться через маяк","Сначала полностью распустит текущую группу, затем сохранит переход и выйдет к выбору персонажей. Войдите за указанного маяка; UnBot призовёт текущего персонажа и снова выйдет.","Выбор обоих персонажей на экране входа выполняется вручную. Если группу не удалось очистить, выход отменяется.",function() if UnBotBeaconTravel then UnBotBeaconTravel.StartTravel(Selected()); end end);
	UnBotSpecAudit.beaconPinButton=CenterCreateActionButton(actions,"Закрепить",120,313,-12,"Закрепить маяк","Закреплённый маяк никогда не предлагается для автоматического переиспользования.",nil,function() if UnBotBeaconTravel then UnBotBeaconTravel.TogglePinned(Selected()); end end);
	UnBotSpecAudit.beaconUnassignButton=CenterCreateActionButton(actions,"Снять статус",125,438,-12,"Снять статус маяка","Удаляет назначение и заметку из активного списка, но не подключает и не перемещает персонажа.","Прежние данные остаются в записи и восстановятся при новой установке.",function() if UnBotBeaconTravel then UnBotBeaconTravel.Unassign(Selected()); end end);
	UnBotSpecAudit.beaconCancelButton=CenterCreateActionButton(actions,"Отменить переход",145,568,-12,"Отменить переход","Удаляет только незавершённое межперсонажное задание.","Уже перемещённых персонажей назад не телепортирует.",function() if UnBotBeaconTravel then UnBotBeaconTravel.CancelTask(); end end);
	local hint=actions:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); hint:SetPoint("TOPLEFT",12,-49); hint:SetWidth(910); hint:SetJustifyH("LEFT"); hint:SetText("Установка новой точки заменяет старое назначение только после подтверждённого прибытия. Закреплённые маяки можно перенести вручную, но они не попадают в рекомендацию.");
	UnBotSpecAudit.beaconRecommendationButton=recommendation;
	return panel;
end

local function CenterCreateCurrentGroupPanel(frame)
	local panel=CreateFrame("Frame",nil,frame); panel:SetPoint("TOPLEFT",20,-128); panel:SetWidth(970); panel:SetHeight(515);
	local helpBox=CreateFrame("Frame",nil,panel); helpBox:SetPoint("TOPLEFT",4,-2); helpBox:SetWidth(940); helpBox:SetHeight(58); helpBox:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=10,insets={left=3,right=3,top=3,bottom=3}}); helpBox:SetBackdropColor(.03,.03,.03,.95); helpBox:SetBackdropBorderColor(.35,.35,.35,.9);
	local help=helpBox:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); help:SetPoint("TOPLEFT",helpBox,"TOPLEFT",12,-10); help:SetWidth(916); help:SetJustifyH("LEFT"); help:SetText("Здесь обслуживаются только участники, которые уже онлайн в вашей группе. Альт попадёт в безопасную продажу и закупку только после явного разрешения на вкладке «Альты».");
	UnBotSpecAudit.currentGroupCount=panel:CreateFontString(nil,"OVERLAY","GameFontNormal"); UnBotSpecAudit.currentGroupCount:SetPoint("TOPLEFT",16,-76); UnBotSpecAudit.currentGroupCount:SetTextColor(1,.82,.18);
	local listBox=CreateFrame("Frame",nil,panel); listBox:SetPoint("TOPLEFT",4,-98); listBox:SetWidth(940); listBox:SetHeight(284); listBox:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=10,insets={left=3,right=3,top=3,bottom=3}}); listBox:SetBackdropColor(.025,.025,.025,.84); listBox:SetBackdropBorderColor(.25,.25,.25,.85);
	UnBotSpecAudit.currentGroupDetail=listBox:CreateFontString(nil,"OVERLAY","GameFontHighlight"); UnBotSpecAudit.currentGroupDetail:SetPoint("TOPLEFT",listBox,"TOPLEFT",14,-12); UnBotSpecAudit.currentGroupDetail:SetWidth(910); UnBotSpecAudit.currentGroupDetail:SetJustifyH("LEFT"); UnBotSpecAudit.currentGroupDetail:SetJustifyV("TOP");
	local actions=CreateFrame("Frame",nil,panel); actions:SetPoint("TOPLEFT",4,-394); actions:SetWidth(940); actions:SetHeight(112); actions:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=10,insets={left=3,right=3,top=3,bottom=3}}); actions:SetBackdropColor(.025,.025,.025,.92); actions:SetBackdropBorderColor(.3,.3,.3,.9);
	local title=actions:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); title:SetPoint("TOPLEFT",12,-8); title:SetText("ОБСЛУЖИТЬ ТЕКУЩУЮ ГРУППУ");
	UnBotSpecAudit.groupMaintenanceButton=CenterCreateActionButton(actions,"Продать и купить",215,10,-28,"Продать хлам и купить реагенты","По очереди продаст серый хлам и докупит недостающие реагенты каждому текущему боту.","Откройте торговца. Состав группы не изменится.",function() if UnBotBotServiceStartMaintenance then UnBotBotServiceStartMaintenance(true); end end);
	UnBotSpecAudit.groupDeepButton=CenterCreateActionButton(actions,"Продать всё лишнее",215,235,-28,"Расширенная продажа","Продаст серый хлам и проверенное запасное снаряжение; докупит недостающие реагенты.","Классовые и профессиональные предметы защищены. Неизвестные предметы остаются. Откройте торговца.",function() if UnBotBotServiceStartDeepMaintenance then UnBotBotServiceStartDeepMaintenance(true); end end);
	UnBotSpecAudit.groupFastButton=CenterCreateActionButton(actions,"Быстро продать хлам",215,460,-28,"Быстро продать серый хлам","Адресно продаст серый хлам обычным ботам и разрешённым альтам текущей группы.","Откройте торговца. Защищённые альты без флага не затрагиваются.",function() if UnBotFastJunkRaidStart then UnBotFastJunkRaidStart(true); end end);
	UnBotSpecAudit.groupBagButton=CenterCreateActionButton(actions,"Проверить сумки",215,685,-28,"Проверить свободное место","Сохранит количество свободных ячеек у текущих онлайн-ботов.","Торговец не нужен. Состав группы не изменится.",function() if UnBotBagSpaceAuditStart then UnBotBagSpaceAuditStart(true); end end);
	local note=actions:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); note:SetPoint("TOPLEFT",12,-69); note:SetWidth(910); note:SetJustifyH("LEFT"); note:SetText("«Продать и купить» и быстрая продажа также обслуживают разрешённых альтов. Глубокая продажа и проверка сумок работают только с обычными ботами.");
	return panel;
end

function UnBotSpecAudit.CommitRegistryBatchSize()
 local edit=UnBotSpecAudit.registryBatchEdit;
 if edit then edit:SetText(tostring(UnBotRegistryRefresh.SetBatchSize(edit:GetText())));end
end

function UnBotSpecAudit.RefreshRegistryClick(onlyUndated)
 UnBotSpecAudit.CommitRegistryBatchSize();
 if UnBotBotScanner and (UnBotBotScanner.active or UnBotBotScanner.pendingTalentAudit or UnBotBotScanner.talentAuditRunning) then
  if UnBotBotScannerUIStart then UnBotBotScannerUIStart();end
 elseif UnBotRegistryRefresh.Running() then UnBotRegistryRefresh.Stop();
 else UnBotRegistryRefresh.Start(false,onlyUndated==true);end
end

function UnBotSpecAudit.CreateRegistryBatchSetting(frame)
 local label=frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");
 label:SetPoint("TOPLEFT",718,-23);label:SetText("Пачка /ubrefresh:");
 local edit=CenterCreateEditBox(frame,42,22,true);
 edit:SetPoint("TOPLEFT",850,-16);edit:SetMaxLetters(3);edit:SetJustifyH("CENTER");
 edit:SetText(tostring(UnBotRegistryRefresh.BatchSize()));
 UnBotSpecAudit.registryBatchEdit=edit;
 edit:SetScript("OnEnterPressed",function(self) UnBotSpecAudit.CommitRegistryBatchSize();self:ClearFocus();end);
 edit:SetScript("OnEditFocusLost",function(self) UnBotSpecAudit.CommitRegistryBatchSize();self:SetBackdropBorderColor(.35,.65,.68,.95);end);
 edit:SetScript("OnEscapePressed",function(self) self:SetText(tostring(UnBotRegistryRefresh.BatchSize()));self:ClearFocus();end);
 edit:SetScript("OnShow",function(self) self:SetText(tostring(UnBotRegistryRefresh.BatchSize()));end);
 edit:SetScript("OnEnter",function(self)
  GameTooltip:SetOwner(self,"ANCHOR_TOP");GameTooltip:AddLine("Размер пачки /ubrefresh",1,.82,.18);
  GameTooltip:AddLine("От 1 до 35 ботов, по умолчанию 30. Enter или выход из поля сохраняет значение. Изменение применяется со следующей пачки.",1,1,1,true);
  GameTooltip:AddLine("Размер применяется к кнопкам «Обновить реестр» и «Проверить без даты», а также к /ubrefresh. Поиск новых ботов справа использует отдельный проход по классам.",1,.35,.2,true);GameTooltip:Show();
 end);
 edit:SetScript("OnLeave",function() GameTooltip:Hide();end);
 local range=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");
 range:SetPoint("LEFT",edit,"RIGHT",8,0);range:SetText("1–35");
end

local function CenterCreateWindow()
	if UnBotSpecAudit.frame then return; end local frame=CreateFrame("Frame","UnBotSpecAuditWindow",UIParent); frame:SetWidth(1010); frame:SetHeight(700); frame:SetPoint("CENTER"); frame:SetFrameStrata("DIALOG"); frame:SetMovable(true); frame:EnableMouse(true); frame:SetClampedToScreen(true); frame:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=32,insets={left=11,right=12,top=12,bottom=11}}); frame:SetScript("OnMouseDown",function(self,button) if button=="LeftButton" then self:StartMoving(); end end); frame:SetScript("OnMouseUp",function(self) self:StopMovingOrSizing(); end); frame:SetScript("OnHide",function(self) self:StopMovingOrSizing(); end); frame:SetScript("OnUpdate",function(self,elapsed) UnBotSpecAudit.Tick(elapsed); end);
 for _,event in ipairs({"RAID_ROSTER_UPDATE","PARTY_MEMBERS_CHANGED","UNIT_CONNECTION","UNIT_NAME_UPDATE","PLAYER_ENTERING_WORLD","UNIT_LEVEL","UNIT_FACTION"}) do frame:RegisterEvent(event); end
 frame:SetScript("OnEvent",function(_,event,unit)
  if not unit or unit=="player" or unit:match("^raid%d+$") or unit:match("^party%d+$") then UnBotSpecAudit.MarkDirty(); end
 end);
	frame:Hide();
	UnBotSpecAudit.CreateRegistryBatchSetting(frame);
	UnBotSpecAudit.registryProgress=CreateFrame("StatusBar",nil,frame);
	UnBotSpecAudit.registryProgress:SetPoint("TOPLEFT",210,-82);UnBotSpecAudit.registryProgress:SetWidth(598);UnBotSpecAudit.registryProgress:SetHeight(7);
	UnBotSpecAudit.registryProgress:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar");UnBotSpecAudit.registryProgress:SetMinMaxValues(0,1);UnBotSpecAudit.registryProgress:SetValue(0);
	UnBotSpecAudit.registryProgress.background=UnBotSpecAudit.registryProgress:CreateTexture(nil,"BACKGROUND");UnBotSpecAudit.registryProgress.background:SetAllPoints(UnBotSpecAudit.registryProgress);UnBotSpecAudit.registryProgress.background:SetTexture(0,0,0,.65);
	UnBotSpecAudit.registryProgress:EnableMouse(true);UnBotSpecAudit.registryProgress:Hide();
	UnBotSpecAudit.registryProgress:SetScript("OnEnter",function(self)
		GameTooltip:SetOwner(self,"ANCHOR_TOP");GameTooltip:AddLine("Обновление реестра",1,.82,.18);
		GameTooltip:AddLine(UnBotRegistryRefresh.Status(),1,1,1,true);GameTooltip:AddLine(UnBotRegistryRefresh.ReasonText(),1,1,1,true);GameTooltip:Show();
	end);UnBotSpecAudit.registryProgress:SetScript("OnLeave",function() GameTooltip:Hide();end);
	frame:SetScript("OnShow",function()
		if UnBotSquadBuilderFrame then UnBotSquadBuilderFrame:Hide(); end
		if UnBotAccountAlts and UnBotAccountAlts.RefreshForCenter then UnBotAccountAlts.RefreshForCenter(); end
	end);
	if UnBotSharedNames and UnBotSharedNames.Enabled() then
		UnBotSpecAudit.sharedNamesButton=CenterCreateActionButton(frame,"Общие имена ×3",170,22,-16,"Общие имена и классы трёх аккаунтов","Объединяет имена и классы обычных ботов без дублей. Известный локальный класс, спеки, уровни, экипировка, таланты и личная история сохраняются. Разные реалмы и фракции не смешиваются.","Участвуют все персонажи настроенных аккаунтов: аккаунт определяется по логину клиента или сохранённой настройке аккаунта; новый персонаж обнаруживается автоматически при входе. Обменивается только с объявившимися онлайн-клиентами. Списки личных альтов не запрашиваются. Кнопка повторяет ограниченный обмен; /reload сохраняет данные на диск.",function() UnBotSharedNames.Begin(true); end);
		UnBotSpecAudit.sharedNamesButton:SetHeight(20);
 UnBotSpecAudit.undatedButton=CenterCreateActionButton(frame,"Проверить без даты",150,210,-16,"Проверить только ботов без даты","Проверяет только имена без даты подтверждённого класса/спека. Записи с датой не вызываются. Незавершённая очередь полного прохода сохраняется отдельно.","Размер пачки от 1 до 35. При отсутствии таких имён покажет сообщение и ничего не запустит.",function() UnBotSpecAudit.RefreshRegistryClick(true);end);
	end
	local close=CreateFrame("Button",nil,frame,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",-5,-5); local title=frame:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); title:SetPoint("TOP",0,-18); title:SetText("Управление ботами и альтами"); UnBotSpecAudit.scanButton=CenterCreateActionButton(frame,"Обновить реестр",170,22,-48,"Обновить реестр","Проверяет известные имена через who, как кнопка в окне призыва состава. Сначала без даты, затем самые старые проверки. Незавершённый полный проход продолжается.","Повторный клик остановит. Дополнительные участники и альты сохраняются. Поле пачки задаёт от 1 до 35 имён.",function() UnBotSpecAudit.RefreshRegistryClick(false); end); UnBotSpecAudit.statusText=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); UnBotSpecAudit.statusText:SetPoint("TOPLEFT",210,-51); UnBotSpecAudit.statusText:SetWidth(598); UnBotSpecAudit.statusText:SetHeight(36); UnBotSpecAudit.statusText:SetJustifyH("LEFT"); UnBotSpecAudit.statusText:SetJustifyV("TOP"); UnBotSpecAudit.discoverButton=CenterCreateActionButton(frame,"Найти новых ботов",142,828,-48,"Поиск новых ботов сервера","На вкладке «Специализации» делает один проход по выбранному классу, независимо от выбранного спека; на остальных вкладках — все классы. До 35 addclass в пачке, общий who и выход из временной группы. На уровнях 1–10 собирает только имена и классы из ростера, без проверки специализаций, талантов и init; при отсутствии подтверждения add — один общий who только для имени/класса. Новые имена объединяются с реестром; после очистки — запись через /reload и автоматический /ubnames.","Нужна пустая группа. Левая кнопка обновляет известных ботов; эта кнопка ищет новые имена.",function() if UnBotBotScannerDiscover then UnBotBotScannerDiscover(UnBotSpecAudit.activeTab=="specs" and UnBotSpecAudit.selectedClass or nil); end end); UnBotSpecAudit.tabButtons={}; UnBotSpecAudit.tabButtons.registry=CenterCreateButton(frame,"Все боты",110,22,-92,function() CenterShowTab("registry"); end); UnBotSpecAudit.tabButtons.specs=CenterCreateButton(frame,"Специализации",120,137,-92,function() CenterShowTab("specs"); end); UnBotSpecAudit.tabButtons.reagents=CenterCreateButton(frame,"Хлам и реагенты",140,262,-92,function() CenterShowTab("reagents"); end); UnBotSpecAudit.tabButtons.alts=CenterCreateButton(frame,"Альты",105,407,-92,function() CenterShowTab("alts"); end); UnBotSpecAudit.tabButtons.chat=CenterCreateButton(frame,"Чат",100,517,-92,function() CenterShowTab("chat"); end); UnBotSpecAudit.tabButtons.beacons=CenterCreateButton(frame,"Маяки",110,622,-92,function() CenterShowTab("beacons"); end); UnBotSpecAudit.tabButtons.current=CenterCreateButton(frame,"Текущая группа",155,737,-92,function() CenterShowTab("current"); end); UnBotSpecAudit.panels={registry=CenterCreateRegistryPanel(frame),specs=CenterCreateSpecPanel(frame),reagents=CenterCreateReagentPanel(frame),alts=UnBotSpecAudit.CreateAltsPanel(frame),beacons=CenterCreateBeaconPanel(frame),current=CenterCreateCurrentGroupPanel(frame),chat=UnBotChatRouting.CreatePanel(frame)}; UnBotSpecAudit.frame=frame; if UISpecialFrames then table.insert(UISpecialFrames,"UnBotSpecAuditWindow"); end CenterShowTab(UnBotSpecAudit.activeTab or "registry");
end

function UnBotBotCenterShow(tab)
	CenterCreateWindow();
	if UnBotSquadBuilderFrame then UnBotSquadBuilderFrame:Hide(); end
	UnBotSpecAudit.activeTab=tab or UnBotSpecAudit.activeTab or "registry";
 UnBotSpecAudit.opening=true; UnBotSpecAudit.frame:Show(); UnBotSpecAudit.opening=nil;
 CenterShowTab(UnBotSpecAudit.activeTab);
end

function UnBotSpecAuditShow()
	UnBotBotCenterShow("specs");
end
