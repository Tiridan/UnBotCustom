-- One owner for loot settings, boss selection, master distribution and rolls (3.3.5a).
UnBotLootSettings = {};
local M = UnBotLootSettings;
M.rolls = {};
M.assigned = {};
M.qualityNames = {[0]="Низкое", "Обычное", "Необычное", "Редкое", "Эпическое", "Легендарное"};

function M.Print(text)
	DEFAULT_CHAT_FRAME:AddMessage("|cffffcc66UnBot — добыча:|r "..tostring(text));
end

function M.RaidWarning(text)
	if (RaidNotice_AddMessage and RaidWarningFrame) then
		RaidNotice_AddMessage(RaidWarningFrame, text, {r=1,g=0.15,b=0.1});
	elseif (UIErrorsFrame and UIErrorsFrame.AddMessage) then
		UIErrorsFrame:AddMessage(text, 1, 0.15, 0.1);
	end
	if (PlaySound) then PlaySound("RaidWarning"); end
end

function M.Warning(text)
	M.Print(text);
	M.RaidWarning(text);
end

local function Copy(value)
	if (type(value) ~= "table") then return value; end
	local result = {};
	for k,v in pairs(value) do result[k] = Copy(v); end
	return result;
end

function M.Get()
	UnBotSquadConfig = UnBotSquadConfig or {};
	local config = UnBotSquadConfig;
	config.lootSettings = config.lootSettings or {characters={}};
	local storage = config.lootSettings;
	storage.characters = storage.characters or {};
	local key = tostring(GetRealmName and GetRealmName() or "").."|"..tostring(UnitName("player") or "");
	storage.characters[key] = storage.characters[key] or {};
	local p = storage.characters[key];
	if (p.bossSelection == nil) then p.bossSelection = true; end
	if (p.showGroupButton == nil) then p.showGroupButton = true; end
	p.buttonWidth = tonumber(p.buttonWidth) or 260;
	p.buttonHeight = tonumber(p.buttonHeight) or 40;
	p.buttonWidth = math.max(160, math.min(500, p.buttonWidth));
	p.buttonHeight = math.max(24, math.min(100, p.buttonHeight));
	p.masterLoot = p.masterLoot or {};
	p.autoGreed = p.autoGreed or {};
	if (type(p.confirmDelete) ~= "table") then p.confirmDelete = {}; end
	if (p.masterLoot.enabled == nil) then p.masterLoot.enabled = false; end
	if (p.autoGreed.enabled == nil) then p.autoGreed.enabled = false; end
	if (p.autoGreed.confirmBind == nil) then p.autoGreed.confirmBind = true; end
	p.masterLoot.target = p.masterLoot.target or UnitName("player") or "";
	p.masterLoot.quality = p.masterLoot.quality or {};
	p.autoGreed.quality = p.autoGreed.quality or {};
	for q=0,5 do
		if (p.masterLoot.quality[q] == nil) then p.masterLoot.quality[q] = false; end
		if (p.autoGreed.quality[q] == nil) then p.autoGreed.quality[q] = false; end
		if (p.confirmDelete[q] == nil) then p.confirmDelete[q] = true; end
	end
	if (config.forceMasterLootAfterSummon == nil) then config.forceMasterLootAfterSummon = true; end
	return p;
end

function M.LinkBagBin()
	if (not BagBin or not BagBin.db) then return; end
	local p = M.Get();
	if (not p.bagBinImported) then
		if (not p.distributionConfigured) then
			if (type(BagBin.db.masterLoot) == "table") then p.masterLoot = Copy(BagBin.db.masterLoot); end
			if (type(BagBin.db.autoGreed) == "table") then p.autoGreed = Copy(BagBin.db.autoGreed); end
		end
		p.bagBinImported = true;
	end
	if (not p.deleteBagBinImported) then
		if (not p.deleteConfigured and type(BagBin.db.confirmDelete) == "table") then
			p.confirmDelete = Copy(BagBin.db.confirmDelete);
		end
		p.deleteBagBinImported = true;
	end
	BagBin.db.confirmDelete = p.confirmDelete;
	if (not BagBin.lootSettingsMoved) then
		BagBin.SuppressDeletePopup = function(_, which) return M.SuppressDeletePopup(which); end;
	end
	-- Retain legacy saved values for migration; only old BagBin needs event delegation.
	BagBin.db.masterLoot = p.masterLoot;
	BagBin.db.autoGreed = p.autoGreed;
	if (not BagBin.lootSettingsMoved) then
		BagBin.AutoMasterLoot = function() return M.Distribute(); end;
		BagBin.AutoGreedStart = function(_, id) return M.Roll(id); end;
		BagBin.AutoGreedConfirm = function(_, id, kind) return M.Confirm(id, kind); end;
	end
end

function M.Changed(section)
	if (section ~= "delete" and section ~= "bots") then M.Get().distributionConfigured = true; end
	M.LinkBagBin();
	M.Refresh();
	if (BagBin and BagBin.Refresh and BagBin.ui) then BagBin:Refresh(); end
end

function M.SetDeleteConfirmation(quality, enabled)
	local p=M.Get();
	p.confirmDelete[quality]=enabled and true or false;
	p.deleteConfigured=true;
	M.Print("Подтверждение уничтожения («"..(_G["ITEM_QUALITY"..quality.."_DESC"] or M.qualityNames[quality])
		.."»): "..(enabled and "включено." or "выключено."));
	return "delete";
end

function M.SuppressDeletePopup(which, eventQuality)
	if (not M.ready or M.deleting or (which~="DELETE_ITEM" and which~="DELETE_GOOD_ITEM")
		or not GetCursorInfo or not GetItemInfo or not DeleteCursorItem or not StaticPopup_Hide) then return; end
	-- The native delete event supplies quality even when GetItemInfo is not cached.
	if ((InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player"))) then return; end
	local kind,id,link=GetCursorInfo();
	if (kind~="item" or not id) then return;end
	local _,_,quality=GetItemInfo(link or id);
	if (quality==nil) then quality=eventQuality;end
	if (quality==nil or M.Get().confirmDelete[quality]~=false) then return;end
	local previous=M.deleteAttempt;
	if (previous and previous.id==id and previous.link==link) then return;end
	M.deleteAttempt={id=id,link=link,which=which};
	M.deleting=true;
	-- Match the native Yes button: delete first, then hide. OnHide resets client state.
	local ok=pcall(DeleteCursorItem);
	local currentKind=GetCursorInfo();
	if (ok and currentKind~="item") then
		StaticPopup_Hide(which);
	else
		M.Print("Клиент не разрешил уничтожение. Подтвердите удаление вручную.");
	end
	M.deleting=nil;
end

function M.QueueDeleteConfirmation(name, quality)
	M.deletePending=nil;
	if (M.deleting or not GetCursorInfo or type(quality)~="number" or quality<0 or quality>5) then return;end
	local kind,id,link=GetCursorInfo();
	if (kind~="item" or not id) then return;end
	M.deletePending={id=id,link=link,quality=quality,which=quality>=3 and "DELETE_GOOD_ITEM" or "DELETE_ITEM"};
end

function M.CheckDeleteConfirmation()
	local pending=M.deletePending;
	M.deletePending=nil;
	if (not pending or not GetCursorInfo or not StaticPopup_Visible or not StaticPopup_Visible(pending.which)) then return;end
	local kind,id,link=GetCursorInfo();
	if (kind~="item" or id~=pending.id or link~=pending.link) then return;end
	M.SuppressDeletePopup(pending.which,pending.quality);
end

-- Use the native event, then handle its displayed dialog once on the next frame.
-- This avoids relying on item cache timing or a replaceable StaticPopup_Show wrapper.

function M.GroupName()
	return LOOT_GROUP_LOOT and (string.match(LOOT_GROUP_LOOT, ":%s*(.+)") or LOOT_GROUP_LOOT) or "Групповой";
end

function M.MethodName()
	local method=GetLootMethod and GetLootMethod();
	local names={master=MASTER_LOOTER or "Ответственный за добычу",group=M.GroupName(),
		freeforall="Каждый за себя",roundrobin="По очереди",needbeforegreed="Приоритет по нужности"};
	return names[method] or "не выбран";
end

function M.MethodAutomationBlocked()
	local p = M.Get();
	return p.manualGroupOverride or M.bossLootHold;
end

function M.BossChoice()
	M.Get().manualGroupOverride = nil;
	M.bossLootHold = true;
end

function M.TargetSelected(unit)
	local p = M.Get();
	local guid = UnitGUID and UnitGUID(unit or "target");
	local npc = guid and tonumber(string.sub(guid,9,12),16);
	local selected;
	for _, instance in ipairs(BossMemoryBossCatalog or {}) do
		if ((instance.instanceType or "raid") == "raid") then
			for _, boss in ipairs(instance.bosses or {}) do
				for _, id in ipairs(boss.ids or {}) do
					if (id == npc) then selected = UnBotBossPresetCatalogKey(instance.instance,boss.name); break end
				end
			end
		end
	end
	if (not selected) then p.lastTargetGuid = nil; return; end
	if (p.lastTargetGuid == guid) then return; end
	p.lastTargetGuid = guid;
	if (UnBotGunshipMasterLoot and UnBotGunshipMasterLoot.CheckBossClick) then
		UnBotGunshipMasterLoot.CheckBossClick(selected);
	end
end

function M.SwitchToGroup()
	if (M.groupPending or not GetLootMethod or GetLootMethod() ~= "master") then return; end
	if ((InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player"))) then
		M.Warning("Способ добычи «"..M.GroupName().."» не включается: смена сейчас недоступна в бою."); return;
	end
	if (not SetLootMethod) then M.Warning("Способ добычи изменить не удалось: API недоступен."); return; end
	-- Set before issuing the request: loot/roster events may fire synchronously.
	M.Get().manualGroupOverride = true;
	M.bossLootHold = nil;
	if (UnBotGunshipMasterLootDisarm) then UnBotGunshipMasterLootDisarm(true); end
	if (UnBotGunshipMasterLoot) then
		UnBotGunshipMasterLoot.bossClickCheck = nil;
		UnBotGunshipMasterLoot.resumeWithoutLoot = true;
	end
	if (UnBotAltLootAutomation) then UnBotAltLootAutomation.active = false; end
	local ok = pcall(SetLootMethod, "group");
	if (not ok) then M.Warning("Способ добычи «"..M.GroupName().."» не включается: клиент отклонил смену."); return; end
	M.groupPending = GetTime()+1.5;
	M.CheckGroupResult();
end

function M.CheckGroupResult()
	if (not M.groupPending) then return; end
	if (GetLootMethod and GetLootMethod() == "group") then
		M.groupPending = nil; M.Print("Способ добычи: «"..M.GroupName().."»."); M.UpdateButton();
	elseif (GetTime() >= M.groupPending) then
		M.groupPending = nil; M.Warning("Способ добычи «"..M.GroupName().."» не включается. Проверьте права лидера.");
	end
end

function M.PlayerIsMaster()
	if (UnBotGunshipMasterLootPlayerIsMaster) then return UnBotGunshipMasterLootPlayerIsMaster(); end
	if (not GetLootMethod) then return false; end
	local method, party, raid = GetLootMethod();
	if (method ~= "master") then return false; end
	if ((GetNumRaidMembers() or 0) > 0) then
		return raid and GetRaidRosterInfo(raid) == UnitName("player");
	end
	return party == 0;
end

function M.ScheduleLoot()
	if (not M.lootOpen or not M.Get().masterLoot.enabled) then return; end
	M.lootDeadline = M.lootDeadline or GetTime()+5;
	M.nextLoot = GetTime()+0.2;
end

function M.CheckLootResults()
	for key, attempt in pairs(M.pendingLoot or {}) do
		local name,count;
		if (attempt.slot<=GetNumLootItems()) then local _;_,name,count=GetLootSlotInfo(attempt.slot);end
		local link=name and GetLootSlotLink and GetLootSlotLink(attempt.slot) or name;
		if (not name or link~=attempt.link or count~=attempt.count) then
			M.pendingLoot[key]=nil;
		elseif (GetTime()>=attempt.expires) then
			M.pendingLoot[key]=nil;
			M.Warning("Предмет «"..attempt.name.."» не был выдан получателю «"..attempt.target.."». Проверьте свободное место и сообщения игры; повторной автоматической попытки не будет.");
		end
	end
end

-- Candidate lookup and direct assignment follow BagBin 1.11.1 AutoMasterLoot.
function M.MasterLootCandidate(target)
	if (not GetMasterLootCandidate) then return nil; end
	for index=1,40 do
		if (GetMasterLootCandidate(index)==target) then return index; end
	end
end

function M.Distribute()
	local settings=M.Get().masterLoot;
	if (not M.lootOpen or not settings.enabled or not M.PlayerIsMaster()
		or not GetNumLootItems or not GetMasterLootCandidate or not GiveMasterLoot) then return false; end
	local target=settings.target~="" and settings.target or UnitName("player");
	local threshold=GetLootThreshold and GetLootThreshold() or 2;
	local sent=0;
	M.preparedLoot=M.preparedLoot or {};M.pendingLoot=M.pendingLoot or {};
	for slot=GetNumLootItems(),1,-1 do
		local _,name,count,quality,locked=GetLootSlotInfo(slot);
		if (name and quality and settings.quality[quality] and not locked and LootSlotIsItem(slot)) then
			local link=GetLootSlotLink and GetLootSlotLink(slot) or name;
			local key=tostring(slot)..":"..tostring(link)..":"..tostring(count);
			if (not M.assigned[key]) then
				local candidate=M.MasterLootCandidate(target);
				-- Some clients populate recipients only after selecting a slot.
				-- Below threshold, never select on behalf of another player: ordinary pickup may take it for us.
				if (LootSlot and not M.preparedLoot[key]
					and (quality>=threshold or (not candidate and target==UnitName("player")))) then
					M.preparedLoot[key]=true;
					if (LootFrame) then
						LootFrame.selectedSlot=slot;LootFrame.selectedQuality=quality;LootFrame.selectedItemName=name;
						LootFrame.selectedLootButton=LootFrame:GetName();
					end
					M.selectingLoot=true;M.autoLootMenu=nil;
					local ok=pcall(LootSlot,slot);
					M.selectingLoot=nil;
					if (M.autoLootMenu and CloseDropDownMenus) then CloseDropDownMenus();end
					M.autoLootMenu=nil;
					if (not ok) then M.assigned[key]=true;M.Warning("Клиент не разрешил выбрать предмет «"..name.."» для выдачи.");end
					candidate=M.MasterLootCandidate(target);
				end
				local currentName,currentCount,currentQuality,currentLocked;
				if (slot<=GetNumLootItems()) then
					local _;_,currentName,currentCount,currentQuality,currentLocked=GetLootSlotInfo(slot);
				end
				local currentLink=currentName and GetLootSlotLink and GetLootSlotLink(slot) or currentName;
				if (currentName~=name or currentCount~=count or currentLink~=link) then
					-- Ordinary below-threshold pickup may already have removed this item.
					M.assigned[key]=true;
				elseif (not M.assigned[key] and candidate and not currentLocked and M.lootOpen
					and settings.enabled and settings.quality[currentQuality] and M.PlayerIsMaster()
					and GetMasterLootCandidate(candidate)==target) then
					-- Do not filter by threshold: the server can offer master distribution for white items too.
					M.assigned[key]=true;
					local ok=pcall(GiveMasterLoot,slot,candidate);
					if (not ok) then M.Warning("Не удалось передать предмет «"..name.."». Повторной автоматической попытки не будет.");
					else
						sent=sent+1;
						M.pendingLoot[key]={slot=slot,name=name,link=link,count=count,target=target,expires=GetTime()+2};
					end
				elseif (not M.assigned[key] and not candidate and not M.targetMissing) then
					M.targetMissing=true;M.Print("Получатель «"..tostring(target).."» пока недоступен для предмета «"..name.."». Если список не обновится, распределите его вручную.");
				end
			end
		end
	end
	return sent>0;
end

function M.Roll(id)
	local p = M.Get().autoGreed;
	if (not p.enabled or not id or not GetLootRollItemInfo or not RollOnLoot) then return; end
	if (M.rolls[id]) then return; end
	local _, _, _, quality, _, canNeed, canGreed = GetLootRollItemInfo(id);
	if (quality == nil or not p.quality[quality]) then return; end
	local kind = canNeed and 1 or canGreed and 2;
	if (not kind) then return; end
	M.rolls[id] = {kind=kind, expires=GetTime()+300};
	local ok = pcall(RollOnLoot,id,kind);
	if (not ok) then M.Warning("Автогрид: клиент отклонил выбор. Выберите вручную."); end
end

function M.Confirm(id, kind)
	local p = M.Get().autoGreed;
	local roll = M.rolls[id];
	if (not p.enabled or not p.confirmBind or not roll or roll.confirmed or roll.expires<GetTime()
		or roll.kind ~= kind or not p.quality[select(4,GetLootRollItemInfo(id))] or not ConfirmLootRoll) then return; end
	roll.confirmed = true;
	pcall(ConfirmLootRoll,id,kind);
end

function M.Targets()
	local names, seen = {}, {};
	local function Add(name)
		if (name and name ~= "" and not seen[name]) then seen[name]=true; names[#names+1]=name; end
	end
	Add(UnitName("player"));
	if ((GetNumRaidMembers() or 0)>0) then
		for i=1,GetNumRaidMembers() do Add(GetRaidRosterInfo(i)); end
	else for i=1,GetNumPartyMembers() do Add(UnitName("party"..i)); end end
	if (UnBotAccountAlts and UnBotAccountAlts.GetNames) then
		for _,name in ipairs(UnBotAccountAlts.GetNames(true)) do Add(name); end
	end
	if (BagBin and BagBin.MasterLootTargets) then
		for _,row in ipairs(BagBin:MasterLootTargets()) do Add(row.name); end
	end
	table.sort(names); return names;
end

local function Label(parent,text,x,y,width,font)
	local f=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlightSmall");
	f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);f:SetWidth(width);f:SetJustifyH("LEFT");f:SetText(text);return f;
end
local function Button(parent,text,x,y,width,action)
	local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate");
	b:SetWidth(width);b:SetHeight(26);b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);b:SetText(text);b:SetScript("OnClick",action);return b;
end
local function Check(parent,text,x,y,width,action)
	local b=CreateFrame("CheckButton",nil,parent,"UICheckButtonTemplate");
	b:SetWidth(26);b:SetHeight(26);b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);
	b.text=Label(parent,text,x+32,y-6,width);b:SetHitRectInsets(0,-width,0,0);
	b:SetScript("OnClick",function(self) local section=action(self:GetChecked() and true or false);M.Changed(section);end);return b;
end
local function Edit(parent,x,y,width)
	local e=CreateFrame("EditBox",nil,parent);e:SetWidth(width);e:SetHeight(26);
	e:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);e:SetAutoFocus(false);e:SetFontObject(GameFontHighlightSmall);
	e:SetTextInsets(7,7,0,0);e:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1});
	e:SetBackdropColor(0.03,0.03,0.03,1);e:SetBackdropBorderColor(0.5,0.5,0.5,1);return e;
end

function M.Create()
	if (M.ui) then return; end
	local f=CreateFrame("Frame","UnBotLootSettingsFrame",UIParent);
	M.ui=f;f:SetWidth(780);f:SetHeight(700);f:SetPoint("CENTER");f:SetFrameStrata("DIALOG");
	f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag("LeftButton");
	f:SetScript("OnDragStart",f.StartMoving);f:SetScript("OnDragStop",f.StopMovingOrSizing);
	f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=32,edgeSize=16});
	f:SetBackdropColor(0.03,0.03,0.03,0.98);
	Label(f,"UnBot — настройки добычи",24,-18,650,"GameFontNormalLarge");
	Button(f,"X",728,-14,28,function() f:Hide(); end);
	Button(f,"Мастер-лут",24,-56,156,function() M.tab="master";M.Refresh();end);
	Button(f,"Автогрид",186,-56,156,function() M.tab="greed";M.Refresh();end);
	Button(f,"Подтверждение уничтожения",348,-56,246,function() M.tab="delete";M.Refresh();end);
	Button(f,"Лут ботов",600,-56,156,function() M.tab="bots";M.Refresh();end);
	f.master=CreateFrame("Frame",nil,f);f.master:SetAllPoints(f);
	f.greed=CreateFrame("Frame",nil,f);f.greed:SetAllPoints(f);
	f.delete=CreateFrame("Frame",nil,f);f.delete:SetAllPoints(f);
	f.bots=CreateFrame("Frame",nil,f);f.bots:SetAllPoints(f);
	local a=f.master;
	Label(a,"Ответственный за добычу (мастер-лут)",24,-102,710,"GameFontNormal");
	a.boss=Check(a,"Включать при выборе рейдовых боссов",24,-128,650,function(v)
		M.Get().bossSelection=v;
		if (not v and UnBotGunshipMasterLoot) then UnBotGunshipMasterLoot.bossClickCheck=nil; end
	end);
	a.summon=Check(a,"Включать при призыве состава",24,-162,650,function(v)
		UnBotSquadConfig.forceMasterLootAfterSummon=v;
		if (not v and UnBotGunshipMasterLootDisarm) then UnBotGunshipMasterLootDisarm(true); end
	end);
	a.showButton=Check(a,"Показывать кнопку переключения на «"..M.GroupName().."»",24,-196,650,function(v) M.Get().showGroupButton=v;end);
	Label(a,"Размер кнопки: ширина",24,-241,175);a.width=Edit(a,200,-234,80);
	Label(a,"высота",300,-241,70);a.height=Edit(a,370,-234,80);
	for _, hint in ipairs({{a.width,"Ширина кнопки",160,500},{a.height,"Высота кнопки",24,100}}) do
		local field=hint[1];field.sizeHint=hint;field:EnableMouse(true);
		field:SetScript("OnEnter",function(self)
			GameTooltip:SetOwner(self,"ANCHOR_TOP");GameTooltip:SetText(self.sizeHint[2]);
			GameTooltip:AddLine("Минимум: "..self.sizeHint[3].." пикс.",1,1,1);
			GameTooltip:AddLine("Максимум: "..self.sizeHint[4].." пикс.",1,1,1);GameTooltip:Show();
		end);
		field:SetScript("OnLeave",function()GameTooltip:Hide();end);
	end
	Button(a,"Применить",470,-234,140,function()
		local w,h=tonumber(a.width:GetText()),tonumber(a.height:GetText());
		if (not w or not h or w~=w or h~=h or w<160 or w>500 or h<24 or h>100) then
			M.Print("Ширина кнопки: 160–500; высота: 24–100.");return;
		end
		M.Get().buttonWidth=math.floor(w);M.Get().buttonHeight=math.floor(h);M.Refresh();
	end);
	a.resetPosition=Button(a,"Сбросить позицию",620,-234,136,function()
		M.ResetButtonPosition();end);
	Label(a,"Кнопка видна только при мастер-луте. Перемещение — правой кнопкой мыши.",24,-272,730);
	a.enabled=Check(a,"Автоматически выдавать выбранные качества",24,-300,650,function(v)M.Get().masterLoot.enabled=v;end);
	Label(a,"Получатель (точное имя персонажа)",24,-340,710);
	a.target=Edit(a,24,-360,440);
	Button(a,"Сохранить имя",474,-360,132,function()
		local name=string.gsub(a.target:GetText() or "","^%s*(.-)%s*$","%1");
		if (name=="" or string.find(name,"[%s|]")) then M.Print("Введите точное имя получателя.");return;end
		M.Get().masterLoot.target=name;M.Changed();
	end);
	f.recipientMenu=CreateFrame("Frame","UnBotLootRecipientMenu",UIParent,"UIDropDownMenuTemplate");
	Button(a,"Выбрать…",616,-360,140,function(self)
		local menu={};
		for _,name in ipairs(M.Targets()) do
			local targetName=name;
			menu[#menu+1]={text=targetName..(targetName==UnitName("player") and " (игрок)" or ""),notCheckable=true,
				func=function()M.Get().masterLoot.target=targetName;M.Changed();end};
		end
		EasyMenu(menu,f.recipientMenu,self,0,0,"MENU",2);
	end);
	Label(a,"Только доступному кандидату; требуется быть ответственным за добычу.\nНеотмеченные качества и недоступные предметы распределяются вручную.",24,-398,730);
	local b=f.greed;
	Label(b,"Автоматический выбор при розыгрыше добычи",24,-102,710,"GameFontNormal");
	b.enabled=Check(b,"Включить автогрид",24,-136,650,function(v)M.Get().autoGreed.enabled=v;end);
	b.confirm=Check(b,"Подтверждать получение персональных предметов",24,-174,650,function(v)M.Get().autoGreed.confirmBind=v;end);
	Label(b,"Для выбранных качеств: «Мне это нужно», если недоступно — «Жадность».\nЕсли оба варианта запрещены сервером, UnBot оставляет выбор вам.\nПодтверждение привязки отвечает «Да» только для розыгрышей, начатых UnBot.\nПри выключенной галочке дополнительный вопрос остаётся ручным.",24,-222,730);
	for _, page in ipairs({a,b}) do
		local isMasterPage = page == a;
		page.qualities={};
		for q=0,5 do
			local quality=q;
			local top=page==a and -448-q*32 or -326-q*45;
			local row=Check(page,_G["ITEM_QUALITY"..q.."_DESC"] or M.qualityNames[q],36,top,640,function(v)
				local p=M.Get();local settings=isMasterPage and p.masterLoot or p.autoGreed;
				settings.quality[quality]=v;
			end);
			local color=ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q];
			if (color) then row.text:SetTextColor(color.r,color.g,color.b); end
			page.qualities[q]=row;
		end
	end
	local c=f.delete;
	Label(c,"Подтверждение уничтожения предметов",24,-102,710,"GameFontNormal");
	Label(c,"Настройка ручного удаления предметов из сумок.\nГалочка включена — игра спрашивает «Уничтожить предмет?».\nСнята — предмет выбранного качества уничтожается без дополнительного вопроса.\nПо умолчанию подтверждение включено для всех качеств.",24,-138,730);
	c.qualities={};
	for q=0,5 do
		local quality=q;
		local top=-232-q*56;
		local row=Check(c,_G["ITEM_QUALITY"..q.."_DESC"] or M.qualityNames[q],36,top,280,function(v)
			return M.SetDeleteConfirmation(quality,v);
		end);
		Label(c,"Спрашивать «Уничтожить предмет?»",350,top-6,380);
		local color=ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q];
		if (color) then row.text:SetTextColor(color.r,color.g,color.b);end
		c.qualities[q]=row;
	end
	Label(c,"Эти переключатели не меняют правила автоочистки сумок.\nПри неизвестном качестве и в бою штатное подтверждение сохраняется.\nПодтверждение привязки при использовании предмета не изменяется.",24,-592,730);
	local d=f.bots;
	Label(d,"Сбор добычи ботами",24,-102,710,"GameFontNormal");
	d.auto=Check(d,"Применять эти настройки после полной сборки состава",24,-132,650,function(v)
		if UnBotSquadLoot then UnBotSquadLoot.Config().autoApply=v;end;return "bots";
	end);
	d.enable=Check(d,"Разрешить сбор вне боя: nc +loot",24,-170,650,function(v)
		if UnBotSquadLoot then UnBotSquadLoot.Config().enableLoot=v;end;return "bots";
	end);
	d.modes={};
	for i,mode in ipairs(UnBotSquadLoot and UnBotSquadLoot.modes or {}) do
		local chosenMode=mode;
		local x=24+((i-1)%2)*370;local y=-232-math.floor((i-1)/2)*54;
		local row=Check(d,mode.text..(mode.command~="" and (" — "..mode.command) or ""),x,y,315,function()
			UnBotSquadLoot.Config().mode=chosenMode.key;return "bots";
		end);
		row.mode=mode;d.modes[#d.modes+1]=row;
		Label(d,mode.hint,x+32,y-28,310);
	end
	Label(d,"Список предметов: ID, название или ссылка; минус исключает предмет.\nДо 10 строк. Сохраните список перед применением.",24,-406,730);
	d.scroll=CreateFrame("ScrollFrame","UnBotLootBotItemsScroll",d,"UIPanelScrollFrameTemplate");
	d.scroll:SetWidth(708);d.scroll:SetHeight(90);d.scroll:SetPoint("TOPLEFT",d,"TOPLEFT",24,-454);
	d.scroll:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1});
	d.scroll:SetBackdropColor(0.03,0.03,0.03,1);d.scroll:SetBackdropBorderColor(0.5,0.5,0.5,1);
	d.items=Edit(d.scroll,0,0,686);d.items:SetBackdrop(nil);d.items:SetHeight(200);d.items:SetMultiLine(true);d.items:SetMaxLetters(2400);
	d.items:SetJustifyH("LEFT");d.items:SetJustifyV("TOP");
	d.scroll:SetScrollChild(d.items);d.scroll:EnableMouseWheel(true);
	d.scroll:SetScript("OnMouseWheel",function(self,delta)
		self:SetVerticalScroll(math.max(0,math.min(self:GetVerticalScrollRange() or 0,(self:GetVerticalScroll() or 0)-delta*24)));
	end);
	d.items:SetScript("OnTextChanged",function()if not M.loadingBots then M.botsDirty=true;end end);
	d.status=Label(d,"",24,-562,730);d.status:SetHeight(38);
	Button(d,"Сохранить",24,-612,150,function()M.SaveBots(false);end);
	Button(d,"Применить сейчас",186,-612,200,function()if M.SaveBots(true) then UnBotSquadLoot.Apply(false);end end);
	Button(d,"Стоп",398,-612,100,function()if UnBotSquadLoot then UnBotSquadLoot.Finish("Остановлено игроком");end end);
	f.status=Label(f,"",24,-660,730);
	table.insert(UISpecialFrames,"UnBotLootSettingsFrame");
	f:Hide();
end

function M.ApplyButtonPosition()
	if (not M.groupButton) then return; end
	local pos=M.Get().buttonPosition;
	M.groupButton:ClearAllPoints();
	if (pos) then M.groupButton:SetPoint(pos.point,UIParent,pos.relativePoint,pos.x,pos.y);
	else M.groupButton:SetPoint("CENTER",UIParent,"CENTER",0,-150);end
end

function M.CreateGroupButton()
	if (M.groupButton) then return; end
	local b=CreateFrame("Button","UnBotGroupLootButton",UIParent,"UIPanelButtonTemplate");M.groupButton=b;
	b:SetFrameStrata("HIGH");b:SetMovable(true);b:SetClampedToScreen(true);b:RegisterForDrag("RightButton");
	b:SetText("Включить «"..M.GroupName().."»");
	b:SetScript("OnClick",function() if (not M.ignoreClickUntil or GetTime()>M.ignoreClickUntil) then M.SwitchToGroup();end end);
	b:SetScript("OnDragStart",function(self)self:StartMoving();end);
	b:SetScript("OnDragStop",function(self)
		self:StopMovingOrSizing();local point,_,relativePoint,x,y=self:GetPoint();
		M.Get().buttonPosition={point=point,relativePoint=relativePoint,x=x,y=y};M.ignoreClickUntil=GetTime()+0.2;
	end);
	b:SetScript("OnEnter",function(self)
		GameTooltip:SetOwner(self,"ANCHOR_TOP");GameTooltip:SetText("Способ добычи: «"..M.GroupName().."»");
		GameTooltip:AddLine("ЛКМ — переключить; правая кнопка — переместить.",1,1,1);
		GameTooltip:AddLine("Размер: /ubloot → Мастер-лут.",1,0.82,0);GameTooltip:Show();
	end);
	b:SetScript("OnLeave",function()GameTooltip:Hide();end);
	M.ApplyButtonPosition();b:Hide();
end

function M.UpdateButton()
	if (not M.ready) then return; end
	M.CreateGroupButton();local p=M.Get();local b=M.groupButton;
	b:SetWidth(p.buttonWidth);b:SetHeight(p.buttonHeight);
	if (p.showGroupButton and GetLootMethod and GetLootMethod()=="master") then b:Show();else b:Hide();end
end

function M.ResetButtonPosition()
	M.Get().buttonPosition={point="CENTER",relativePoint="CENTER",x=0,y=0};
	M.CreateGroupButton();
	M.ApplyButtonPosition();
	M.UpdateButton();
	M.Print("Кнопка групповой добычи возвращена в центр экрана. Закройте настройки, чтобы увидеть кнопку.");
end

function M.SaveBots(silent)
	if not M.ui or not UnBotSquadLoot then return false;end
	local text=M.ui.bots.items:GetText() or "";
	local items,err=UnBotSquadLoot.Items(text);
	if not items then UnBotSquadLoot.Message(err);return false;end
	UnBotSquadLoot.Config().items=text;M.botsDirty=nil;
	if not silent then UnBotSquadLoot.Message("Выбор сохранён. Для готового состава нажмите «Применить сейчас».");end
	return true;
end

function M.RefreshBots()
	if not M.ui then return;end
	local d=M.ui.bots;
	if not UnBotSquadLoot then d.status:SetText("Модуль сбора добычи не загружен.");return;end
	local config=UnBotSquadLoot.Config();
	d.auto:SetChecked(config.autoApply==true);d.enable:SetChecked(config.enableLoot==true);
	for _,button in ipairs(d.modes) do button:SetChecked(UnBotSquadLoot.Mode(config.mode).key==button.mode.key);end
	if not M.botsDirty then M.loadingBots=true;d.items:SetText(config.items or "");M.loadingBots=nil;end
	d.status:SetText(UnBotSquadLoot.status or "Открытие окна и выбор настроек не отправляют команд. «Применить сейчас» — для текущего состава.");
end

function M.Refresh()
	M.UpdateButton();
	if UnBotSquadBuilderUI and UnBotSquadBuilderUI.RefreshSettings and UnBotSquadBuilder then
		UnBotSquadBuilderUI.RefreshSettings(UnBotSquadBuilder);
	end
	local f=M.ui;if (not f) then return;end
	local p=M.Get();
	f.master:Hide();f.greed:Hide();f.delete:Hide();f.bots:Hide();
	if (M.tab=="bots") then f.bots:Show();
	elseif (M.tab=="delete") then f.delete:Show();
	elseif (M.tab=="greed") then f.greed:Show();else f.master:Show();end
	f.master.boss:SetChecked(p.bossSelection);f.master.summon:SetChecked(UnBotSquadConfig.forceMasterLootAfterSummon~=false);
	f.master.showButton:SetChecked(p.showGroupButton);f.master.width:SetText(p.buttonWidth);f.master.height:SetText(p.buttonHeight);
	f.master.enabled:SetChecked(p.masterLoot.enabled);f.master.target:SetText(p.masterLoot.target);
	f.greed.enabled:SetChecked(p.autoGreed.enabled);f.greed.confirm:SetChecked(p.autoGreed.confirmBind);
	for q=0,5 do
		f.master.qualities[q]:SetChecked(p.masterLoot.quality[q]);
		f.greed.qualities[q]:SetChecked(p.autoGreed.quality[q]);
		f.delete.qualities[q]:SetChecked(p.confirmDelete[q]);
	end
	M.RefreshBots();
	f.status:SetText("Настройки сохраняются. Способ добычи: "..M.MethodName());
end

function M.Show(tab)
	M.LinkBagBin();M.Create();M.tab=tab or M.tab or "master";M.Refresh();
	if (UIParent.GetHeight and UIParent.GetWidth) then
		M.ui:SetScale(math.min(1,(UIParent:GetHeight()-30)/700,(UIParent:GetWidth()-30)/780));
	end
	M.ui:Show();
end

M.frame=CreateFrame("Frame");
for _,event in ipairs({"ADDON_LOADED","PARTY_LOOT_METHOD_CHANGED","PARTY_MEMBERS_CHANGED","RAID_ROSTER_UPDATE",
	"PLAYER_ENTERING_WORLD","PLAYER_TARGET_CHANGED","CURSOR_UPDATE","DELETE_ITEM_CONFIRM","LOOT_OPENED","LOOT_CLOSED","LOOT_SLOT_CHANGED",
	"UPDATE_MASTER_LOOT_LIST","OPEN_MASTER_LOOT_LIST","START_LOOT_ROLL","CONFIRM_LOOT_ROLL","CANCEL_LOOT_ROLL","PLAYER_REGEN_ENABLED"}) do
	M.frame:RegisterEvent(event);
end
M.frame:SetScript("OnEvent",function(self,event,...)
	if (event=="ADDON_LOADED") then
		local name=...;
		if (name=="UnBotCustom") then M.ready=true;M.Get();end
		if (M.ready) then M.LinkBagBin();M.UpdateButton();end
		return;
	end
	if (not M.ready) then return;end
	if (event=="OPEN_MASTER_LOOT_LIST") then
		if (M.selectingLoot) then M.autoLootMenu=true;end
	elseif (event=="DELETE_ITEM_CONFIRM") then M.QueueDeleteConfirmation(...);
	elseif (event=="CURSOR_UPDATE") then M.deleteAttempt=nil;M.deletePending=nil;
	elseif (event=="PLAYER_TARGET_CHANGED") then M.TargetSelected("target");
	elseif (event=="LOOT_OPENED") then M.lootOpen=true;M.assigned={};M.preparedLoot={};M.pendingLoot={};M.targetMissing=nil;M.lootDeadline=nil;M.ScheduleLoot();
	elseif (event=="LOOT_CLOSED") then M.lootOpen=false;M.lootDeadline=nil;M.assigned={};M.preparedLoot={};M.pendingLoot={};
	elseif (event=="LOOT_SLOT_CHANGED" or event=="UPDATE_MASTER_LOOT_LIST") then M.ScheduleLoot();
	elseif (event=="START_LOOT_ROLL") then M.Roll(...);
	elseif (event=="CONFIRM_LOOT_ROLL") then M.Confirm(...);
	elseif (event=="CANCEL_LOOT_ROLL") then local id=...;M.rolls[id]=nil;
	else M.UpdateButton();M.CheckGroupResult();end
end);
M.frame:SetScript("OnUpdate",function()
	if (not M.ready) then return;end
	M.CheckDeleteConfirmation();
	M.CheckGroupResult();
	M.CheckLootResults();
	if (M.lootDeadline and GetTime()>M.lootDeadline) then M.lootDeadline=nil;
	elseif (M.lootDeadline and GetTime()>=(M.nextLoot or 0)) then M.nextLoot=GetTime()+0.5;M.Distribute();end
	if (GetTime()>=(M.nextRollCleanup or 0)) then
		M.nextRollCleanup=GetTime()+5;
		for id,roll in pairs(M.rolls) do if (GetTime()>roll.expires) then M.rolls[id]=nil;end end
	end
end);
SLASH_UNBOTLOOT1="/ubloot";
SlashCmdList.UNBOTLOOT=function(message)
	if (string.lower(tostring(message or "")):match("^%s*resetbutton%s*$")) then M.ResetButtonPosition();
	else M.Show();end
end;
