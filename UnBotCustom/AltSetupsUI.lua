-- Visual draft editor; ordinary frames remain available during combat.
local A=UnBotAltSetups;
function A.Text(parent,text,x,y,width,font)
    local f=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlightSmall");f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);
    if width then f:SetWidth(width);end;f:SetJustifyH("LEFT");f:SetText(text);return f;
end
function A.Button(parent,text,x,y,w,click,helpTitle,helpBody)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate");b:SetSize(w or 120,24);b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);b:SetText(text);b:SetScript("OnClick",click);if helpTitle then A.Tooltip(b,helpTitle,helpBody);end;return b;
end
function A.Edit(parent,x,y,width)
    local e=CreateFrame("EditBox",nil,parent)
    e:SetSize(width,22)
    e:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    e:SetFontObject(GameFontHighlight)
    e:SetTextInsets(7,7,0,0)
    e:SetBackdrop({
        bgFile="Interface\\Buttons\\WHITE8X8",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize=10,
        insets={left=3,right=3,top=3,bottom=3},
    })
    e:SetBackdropColor(.035,.045,.065,1)
    e:SetBackdropBorderColor(.5,.55,.65,1)
    e:EnableMouse(true)
    e:SetAutoFocus(false)
    e:SetMaxLetters(80)
    e:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
    e:SetScript("OnHide",function(self) self:ClearFocus() end)
    return e
end
function A.AddHelpLines(text)
    text=tostring(text or ""):gsub("|H[^|]+|h(.-)|h","%1"):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","");
    for paragraph in (text.."\n"):gmatch("(.-)\n") do
        local line="";
        for word in paragraph:gmatch("%S+") do
            local candidate=line=="" and word or (line.." "..word);local visible=candidate:gsub("[\128-\191]","");
            if #visible>48 and line~="" then GameTooltip:AddLine(line,1,1,1,true);line=word;else line=candidate;end
        end
        GameTooltip:AddLine(line=="" and " " or line,1,1,1,true);
    end
end
function A.Tooltip(button,title,body)
    button:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(title);A.AddHelpLines(body);GameTooltip:Show();end);
    button:SetScript("OnLeave",function() GameTooltip:Hide();end);
end
function A.PresetNames(name)
    local names={};if name then for label in pairs(A.Entry(name).presets) do names[#names+1]=label;end end
    table.sort(names);return names;
end
function A.Select(name)
    if A.dirty then A.Status("Есть несохранённые изменения. Сохраните набор или нажмите «Отменить изменения».",true);return;end
    A.selected=name;if A.RestoreObserved then A.RestoreObserved(name);end;A.viewCurrent=true;local entry=A.Entry(name);local label=entry.selectedPreset;
    if label==nil then label=entry.bindings.pve or entry.bindings.pvp or A.PresetNames(name)[1];end
    if label and entry.presets[label] then A.draft=A.Copy(entry.presets[label]);A.draftLabel=label;A.viewCurrent=false;
    else A.draft=A.Copy(A.cache[A.Key(name)]);A.draftLabel=nil;end
    if A.draft then local cache=A.cache[A.Key(name)];A.draft.bags=A.ProjectGearBags(cache and cache.bags,cache and cache.gear or {},A.draft.gear or {});end
    A.drag=nil;A.gearFilter=nil;A.bagPage=1;A.tradePage=1;if A.WarmItems then A.WarmItems(A.draft);end
    if not A.cache[A.Key(name)] then A.Status(name..": данные ещё не загружены. Нажмите «Обновить данные».");end
    A.Refresh();
end
function A.LoadPreset(label)
    if A.job then A.Status("Дождитесь завершения действия или нажмите «Стоп», чтобы изменить набор.",true);return;end
    if not A.selected then return;end
    local p=A.Entry(A.selected).presets[label];if not p then return;end
    A.dirty=false;A.drag=nil;SetCursor(nil);
    A.draft=A.Copy(p);local cache=A.cache[A.Key(A.selected)];A.draft.bags=A.ProjectGearBags(cache and cache.bags,cache and cache.gear or {},A.draft.gear or {});
    A.viewCurrent=false;A.draftLabel=label;A.RememberPreset(A.selected,label);if A.WarmItems then A.WarmItems(A.draft);end;A.Refresh();
end
function A.FinishEditorSave(p)
    if p.context~=A.Context() then A.Status("Персонаж изменился. Откройте набор заново.",true);return;end
    local ok,answer=A.Save(p.name,p.label,p.draft);if not ok then A.Status(answer,true);return;end
    if A.selected==p.name and A.draft==p.source then
        A.draftLabel=answer;A.RememberPreset(p.name,answer);A.viewCurrent=false;A.dirty=false;
    end
    A.RequestOutfitSave(p.name,answer);
    A.Status("Набор «"..answer.."» сохранён. Для переодевания нажмите «Применить весь набор».");A.Refresh();
end
function A.EditorSaveIntent(label)
    if A.job then A.Status("Дождитесь завершения действия или нажмите «Стоп».",true);return;end
    if not A.selected or not A.draft then A.Status("Выберите альта и нажмите «Обновить данные».",true);return;end
    return {name=A.selected,label=label,draft=A.Copy(A.draft),source=A.draft,context=A.Context()};
end
function A.SaveDraft()
    if not A.draftLabel then A.NewPreset();return;end
    local p=A.EditorSaveIntent(A.draftLabel);if not p then return;end
    A.pendingSave=p;StaticPopup_Show("UNBOT_SETUP_OVERWRITE",p.label);
end
StaticPopupDialogs.UNBOT_SETUP_OVERWRITE={text="Сохранить настройки из окна в набор «%s»? Его прежние настройки будут заменены.",button1="Сохранить",button2="Отмена",timeout=0,whileDead=true,hideOnEscape=true,
    OnAccept=function() local p=A.pendingSave;A.pendingSave=nil;if p then A.FinishEditorSave(p);end;end,
    OnCancel=function() A.pendingSave=nil;end};
function A.CreatePreset(p,label)
    label=UnBotAccountAlts.Trim(label or "");
    if label=="" or #label>80 or label:find("[%c|]") then A.Status("Введите название нового набора: от 1 до 80 символов без |.",true);return;end
    if A.Entry(p.name).presets[label] then A.Status("Набор «"..label.."» уже есть. Введите другое название или выберите его и нажмите «Сохранить изменения».",true);return;end
    p.label=label;A.FinishEditorSave(p);
end
StaticPopupDialogs.UNBOT_SETUP_SAVE_AS={text="Сохранить настройки из окна как новый набор. Введите его название:",button1="Создать",button2="Отмена",hasEditBox=true,maxLetters=80,timeout=0,whileDead=true,hideOnEscape=true,
    OnShow=function(self) self.editBox:SetText("");self.editBox:SetFocus();end,
    OnAccept=function(self) local p=A.pendingNewPreset;A.pendingNewPreset=nil;if p then A.CreatePreset(p,self.editBox:GetText());end;end,
    OnCancel=function() A.pendingNewPreset=nil;end};
StaticPopupDialogs.UNBOT_SETUP_RENAME={text="Переименовать набор «%s». Введите новое название:",button1="Переименовать",button2="Отмена",hasEditBox=true,maxLetters=80,timeout=0,whileDead=true,hideOnEscape=true,
    OnShow=function(self) self.editBox:SetText(A.pendingRename and A.pendingRename.label or "");self.editBox:SetFocus();self.editBox:HighlightText();end,
    OnAccept=function(self) local p=A.pendingRename;A.pendingRename=nil;if p then A.RenameDraft(self.editBox:GetText(),p);end;end,
    OnCancel=function() A.pendingRename=nil;end};
function A.Assign(mode)
    if not A.selected or not A.draftLabel or A.dirty then A.Status("Сохраните набор и выберите его в списке.",true);return;end
    A.Entry(A.selected).bindings[mode]=A.draftLabel;A.Status(A.selected..": для "..(mode=="pve" and "PvE" or "PvP").." выбран набор «"..A.draftLabel.."».");A.Refresh();
end
function A.ClearDraft()
    if A.job then A.Status("Дождитесь завершения действия или нажмите «Стоп».",true);return;end
    A.dirty=false;A.drag=nil;
    if A.draftLabel then A.LoadPreset(A.draftLabel);
    elseif A.selected then A.draft=A.Copy(A.cache[A.Key(A.selected)]);A.Refresh();end
end
function A.CanPlace(slot,link,knownLoc)
    if not link then return true;end
    local loc=knownLoc;
    if loc==nil then local info=A.ItemInfo and A.ItemInfo(link);loc=info and info.equipLoc or select(9,GetItemInfo(link));end
    if not loc or loc=="" then return false;end
    local list=UnBotGetEquipLocBySlotID and UnBotGetEquipLocBySlotID(slot) or {};
    if slot==19 then return loc=="INVTYPE_TABARD";end
    for _,v in ipairs(list) do if v==loc then return true;end end;return false;
end
function A.Place(slot,link)
    if A.job and not ((A.job.progressive or A.job.backgroundBags) and A.job.name==A.selected) then A.Status("Дождитесь завершения действия или нажмите «Стоп», чтобы изменить набор.",true);return;end
    if not A.draft then A.Status("Нажмите «Обновить данные» или выберите сохранённый набор.",true);return;end
    if link and not A.CanPlace(slot,link) then A.Status("Вещь не подходит для этой ячейки или ещё не загрузилась. Наведите на неё мышь и попробуйте снова.",true);return;end
    if link then
        local found=false;for _,item in ipairs(A.draft.bags or {}) do if A.ItemKey(item)==A.ItemKey(link) then found=true;end end
        for _,item in pairs(A.cache[A.Key(A.selected)] and A.cache[A.Key(A.selected)].gear or {}) do if A.ItemKey(item)==A.ItemKey(link) then found=true;end end
        if not found then A.Status("Эта вещь не найдена у альта. Обновите его данные и выберите вещь снова.",true);return;end
    end
    local old=A.draft.gear[slot];
    if A.ItemKey(old)~=A.ItemKey(link) then
        local bags=A.draft.bags or {};A.draft.bags=bags;
        if link then for index,item in ipairs(bags) do if A.ItemKey(item)==A.ItemKey(link) then table.remove(bags,index);break end end end
        if old then
            local found=false;for _,item in ipairs(bags) do if A.ItemKey(item)==A.ItemKey(old) then found=true;end end
            if not found then bags[#bags+1]=old;end
        end
    end
    A.draft.gear[slot]=link or false;A.dirty=true;A.drag=nil;SetCursor(nil);A.Refresh();
end
function A.EquipFromBag(link)
    if not link or not A.draft then return;end
    local candidates={};for slot=1,19 do if A.CanPlace(slot,link) then candidates[#candidates+1]=slot;end end
    if #candidates==0 then A.Status("Эту вещь нельзя надеть. Если данные ещё загружаются, наведите на неё мышь.",true);return;end
    local selected=candidates[1];
    if A.gearFilter and A.CanPlace(A.gearFilter,link) then selected=A.gearFilter;
    else for _,slot in ipairs(candidates) do if not A.draft.gear[slot] then selected=slot;break end end end
    A.Place(selected,link);
end
function A.ReceiveSlot(slot)
    if GetCursorInfo and GetCursorInfo() then A.Status("Здесь можно выбрать только вещи альта. Для передачи своих вещей откройте вкладку «Обмен».",true);return;end
    local d=A.drag;
    if d and d.name==A.selected and GetTime()-d.at<30 then A.Place(slot,d.link);
    else A.Status("Перетащите вещь из сумок альта в нужную ячейку. Свои вещи передавайте на вкладке «Обмен».",true);end
end
function A.DisplayGearLink(link,slot)
    if not link or not A.selected then return link;end
    local actual=A.cache[A.Key(A.selected)];
    if actual and A.draft and actual.guid==A.draft.guid and actual.realm==A.draft.realm
        and actual.gear and A.GearMatches(link,actual.gear[slot]) then
        return actual.gear[slot];
    end
    return link;
end
function A.Icon(parent,size)
    local b=CreateFrame("Button",nil,parent);b:SetSize(size,size);
    b.icon=b:CreateTexture(nil,"ARTWORK");b.icon:SetAllPoints(b);b.icon:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot");
    b.border=b:CreateTexture(nil,"OVERLAY");b.border:SetTexture("Interface\\Buttons\\UI-Quickslot2");b.border:SetPoint("CENTER");b.border:SetSize(size*1.65,size*1.65);
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square","ADD");
    b:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT");
        local link=self.slot and A.DisplayGearLink(self.link,self.slot) or self.link;
        if link then GameTooltip:SetHyperlink(link);else GameTooltip:SetText(self.label or "Пусто");end
        if self.help then A.AddHelpLines(self.help);end;GameTooltip:Show();
    end);b:SetScript("OnLeave",function() GameTooltip:Hide();end);return b;
end
function A.SetIcon(b,link,label)
    b.link=link;b.label=label;
    local info=link and A.ItemInfo and A.ItemInfo(link);
    local texture=info and info.texture or (link and select(10,GetItemInfo(link)));b.icon:SetTexture(texture or (link and "Interface\\Icons\\INV_Misc_QuestionMark" or "Interface\\PaperDoll\\UI-Backpack-EmptySlot"));
end
function A.MakeGear(parent)
    local p=CreateFrame("Frame",nil,parent);p:SetAllPoints(parent);
    p:SetScript("OnShow",function() end);
    p.model=CreateFrame("DressUpModel",nil,p);p.model:SetPoint("TOPLEFT",p,"TOPLEFT",68,-40);p.model:SetSize(310,390);
    p.model:SetScript("OnMouseWheel",function(self,delta) A.rotation=(A.rotation or 0)+delta*0.25;self:SetFacing(A.rotation);end);p.model:EnableMouseWheel(true);
    p.note=A.Text(p,"",66,-370,310);p.slots={};
    local left={1,2,3,15,5,4,19,9};local right={10,6,7,8,11,12,13,14};
    for side,list in ipairs({left,right}) do for row,slot in ipairs(list) do
        local b=A.Icon(p,38);b:SetPoint("TOPLEFT",p,"TOPLEFT",side==1 and 14 or 396,-30-(row-1)*49);b.slot=slot;b.help="Левая кнопка: показать вещи для этой ячейки.\nЕсли вещь уже выбрана, поставить её.\nПравая кнопка: убрать вещь из набора.\nАльт переоденется после применения набора.";
        b:RegisterForClicks("LeftButtonUp","RightButtonUp");b:SetScript("OnClick",function(self,button) if button=="RightButton" then A.Place(self.slot,false);elseif A.drag or (GetCursorInfo and GetCursorInfo()) then A.ReceiveSlot(self.slot);else A.FilterGearSlot(self.slot);end end);
        b:RegisterForDrag("LeftButton");b:SetScript("OnReceiveDrag",function(self) A.ReceiveSlot(self.slot);end);
        b:SetScript("OnDragStart",function(self) if self.link then A.drag={link=self.link,name=A.selected,at=GetTime()};SetCursor(select(10,GetItemInfo(self.link)));end end);
        b:SetScript("OnDragStop",function() SetCursor(nil);end);p.slots[slot]=b;
    end end
    for column,slot in ipairs({16,17,18}) do
        local b=A.Icon(p,38);b:SetPoint("TOPLEFT",p,"TOPLEFT",130+(column-1)*56,-430);b.slot=slot;b.help="Левая кнопка: показать вещи для этой ячейки.\nЕсли вещь уже выбрана, поставить её.\nПравая кнопка: убрать вещь из набора.";
        b:RegisterForClicks("LeftButtonUp","RightButtonUp");b:SetScript("OnClick",function(self,button) if button=="RightButton" then A.Place(self.slot,false);elseif A.drag or (GetCursorInfo and GetCursorInfo()) then A.ReceiveSlot(self.slot);else A.FilterGearSlot(self.slot);end end);
        b:SetScript("OnReceiveDrag",function(self) A.ReceiveSlot(self.slot);end);p.slots[slot]=b;
    end
    p.bagTitle=A.Text(p,"Доступная экипировка",460,-10,390,"GameFontNormal");
    A.Button(p,"Все слоты",460,-34,160,function() A.FilterGearSlot(nil);end);
    p.filterLabel=A.Text(p,"Все слоты",635,-41,215);
    p.optionScroll=CreateFrame("ScrollFrame","UnBotAltGearOptionsScroll",p,"UIPanelScrollFrameTemplate");
    p.optionScroll:SetPoint("TOPLEFT",p,"TOPLEFT",460,-70);p.optionScroll:SetSize(360,308);
    p.optionContent=CreateFrame("Frame",nil,p.optionScroll);p.optionContent:SetSize(350,308);
    p.optionScroll:SetScrollChild(p.optionContent);
    p.bags={};p.groupTitles={};
    p.page=A.Text(p,"",460,-398,385);p.page:SetHeight(30);
    A.Text(p,"Выберите ячейку слева, чтобы оставить вещи для неё. «Все слоты» вернёт список по группам.\nПКМ по вещи добавляет её в комплект. Затем нажмите «Применить экипировку».",460,-444,385);
    A.SectionActions(p,"gear");
    return p;
end
function A.ChangeTalent(tab,index,delta)
    if A.job and not ((A.job.progressive or A.job.backgroundBags) and A.job.name==A.selected) then A.Status("Дождитесь завершения действия или нажмите «Стоп», чтобы изменить набор.",true);return;end
    if not A.draft or not A.draft.trees then return;end
    local talent=A.draft.trees[tab].talents[index];local rank=talent.rank;talent.rank=math.max(0,math.min(talent.maxRank,rank+delta));
    local ok,reason=A.ValidTalents(A.draft);if not ok then talent.rank=rank;A.Status(reason,true);return;end
    A.dirty=true;A.Refresh();
end
function A.MakeTalents(parent)
    local p=CreateFrame("Frame",nil,parent);p:SetAllPoints(parent);p.trees={};p.summary=A.Text(p,"",10,-7,410,"GameFontNormal");p.summary:SetHeight(42);
    p.actual=A.Text(p,"",440,-34,405,"GameFontNormalSmall");p.actual:SetHeight(26);
    for slot=1,2 do local n=slot;A.Button(p,"Включить спек "..n,440+(n-1)*204,-5,195,function() A.ActivateSlot(n);end,"Переключить специализацию альта","Действительно переключит активный спек у альта вместе с его талантами и символами. Сначала сохраните изменения в окне.");end
    A.Text(p,"Стрелки ведут к зависимому таланту. Золотая стрелка: нужный талант изучен полностью.\nЛевая кнопка добавляет очко, правая убирает. Подсказка показывает требования.",14,-62,820);
    for tab=1,3 do
        local tree=CreateFrame("Frame",nil,p);tree:SetPoint("TOPLEFT",p,"TOPLEFT",14+(tab-1)*280,-88);tree:SetSize(268,439);
        tree:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=12,insets={left=4,right=4,top=4,bottom=4}});tree:SetBackdropColor(0.035,0.045,0.065,1);
        tree.title=A.Text(tree,"",10,-12,246,"GameFontNormal");tree.buttons={};p.trees[tab]=tree;
    end
    A.Button(p,"Сбросить очки в редакторе",280,-548,250,function()
        if A.job or not A.draft then return;end;for _,tree in ipairs(A.draft.trees) do for _,t in ipairs(tree.talents) do t.rank=0;end end;A.dirty=true;A.Refresh();
    end,"Сбросить только в редакторе","Позволяет заново распределить очки в окне. Для изменения талантов альта нажмите «Применить и сохранить таланты».");
    A.SectionActions(p,"talents");
    return p;
end
function A.MakeGlyphs(parent)
    local p=CreateFrame("Frame",nil,parent);p:SetAllPoints(parent);p.icons={};
    A.Text(p,"Символы выбранного набора",20,-22,800,"GameFontNormalLarge");
    for i=1,6 do local b=A.Icon(p,48);b:SetPoint("TOPLEFT",p,"TOPLEFT",35+((i-1)%3)*260,-85-math.floor((i-1)/3)*120);b.title=A.Text(p,"",92+((i-1)%3)*260,-96-math.floor((i-1)/3)*120,185);p.icons[i]=b;end
    A.Text(p,"Здесь можно только посмотреть символы. Они переключаются вместе со спеком.\nЧтобы выбрать другие символы, войдите за альта и настройте их на нужном спеке.\n\nЭто список символов, а не их расположение в ячейках. После применения набора UnBot проверит, что символы совпадают с сохранёнными.",25,-355,800);
    return p;
end
function A.Create()
    if A.window then return A.window;end
    A.preservePresetOnRead=true;
    local f=CreateFrame("Frame","UnBotAltSetupsWindow",UIParent);A.window=f;f:Hide();f:SetSize(1120,860);f:SetPoint("CENTER");f:SetFrameStrata("DIALOG");f:SetClampedToScreen(true);f:EnableMouse(true);f:SetMovable(true);
    f:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=14,insets={left=5,right=5,top=5,bottom=5}});f:SetBackdropColor(.025,.03,.045,1);f:SetBackdropBorderColor(.38,.47,.62,1);
    f.solid=f:CreateTexture(nil,"BACKGROUND");f.solid:SetPoint("TOPLEFT",f,"TOPLEFT",5,-5);f.solid:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-5,5);f.solid:SetTexture(.025,.03,.045,1);
    f:SetScale(math.min(1,(UIParent:GetWidth()-30)/1120,(UIParent:GetHeight()-35)/860));
    local title=CreateFrame("Frame",nil,f);title:SetPoint("TOPLEFT",f,"TOPLEFT",8,-6);title:SetSize(970,30);title:EnableMouse(true);title:RegisterForDrag("LeftButton");
    title:SetScript("OnDragStart",function() f:StartMoving();end);title:SetScript("OnDragStop",function() f:StopMovingOrSizing();local _,root=A.Storage();local point,_,relative,x,y=f:GetPoint();root.position={point=point,relative=relative,x=x,y=y};end);
    f.moveHandle=title;f:RegisterForDrag("LeftButton");f:SetScript("OnDragStart",title:GetScript("OnDragStart"));f:SetScript("OnDragStop",title:GetScript("OnDragStop"));
    A.Text(title,"Настройка альтов",8,-8,390,"GameFontNormalLarge");A.Text(title,"Окно можно перетащить за заголовок или фон",470,-10,400);
    A.Button(f,"Стоп",990,-8,76,function() A.Stop();end,"Остановить действие","Остановит оставшиеся действия. Уже выполненные изменения останутся у альта.");
    local close=CreateFrame("Button",nil,f,"UIPanelCloseButton");close:SetPoint("TOPRIGHT",f,"TOPRIGHT",-4,-4);
    f.tabs={};for i,label in ipairs({"Экипировка","Таланты","Символы","Заклинания","Обмен","Поведение","Группы"}) do local tab=i;f.tabs[i]=A.Button(f,label,15+(i-1)*155,-43,149,function() A.tab=tab;A.Refresh();end);end
    f.side=CreateFrame("Frame",nil,f);f.side:SetPoint("TOPLEFT",f,"TOPLEFT",14,-82);f.side:SetSize(198,637);
    A.Text(f.side,"Выберите альта",4,-4,190,"GameFontNormal");
    local scroll=CreateFrame("ScrollFrame","UnBotAltSetupsRosterScroll",f.side,"UIPanelScrollFrameTemplate");scroll:SetPoint("TOPLEFT",f.side,"TOPLEFT",0,-30);scroll:SetSize(176,478);
    local child=CreateFrame("Frame",nil,scroll);child:SetSize(174,478);scroll:SetScrollChild(child);f.roster=child;f.rows={};
    A.Text(f.side,"Выбранный альт",4,-523,188,"GameFontNormalSmall");f.selectedTitle=A.Text(f.side,"Выберите альта",4,-546,190,"GameFontNormalLarge");
    f.sideSummary=A.Text(f.side,"",4,-571,190);f.sideSummary:SetHeight(34);
    A.Button(f.side,"Обновить данные",4,-611,188,function() A.RefreshAlt();end,"Обновить данные альта","Обновит сведения об экипировке, талантах и символах. Выбранный сохранённый набор останется в окне.");
    f.content=CreateFrame("Frame",nil,f);f.content:SetPoint("TOPLEFT",f,"TOPLEFT",230,-91);f.content:SetSize(865,622);
    f.gear=A.MakeGear(f.content);f.talents=A.MakeTalents(f.content);f.glyphs=A.MakeGlyphs(f.content);f.spells=A.MakeSpells(f.content);f.trade=A.MakeTrade(f.content);f.behavior=A.MakeBehavior(f.content);
    f.groups=A.MakeGroups(f);f.groups:SetPoint("TOPLEFT",f,"TOPLEFT",14,-91);f.groups:SetSize(1080,710);
    local bar=CreateFrame("Frame",nil,f);f.personal=bar;bar:SetPoint("TOPLEFT",f,"TOPLEFT",230,-722);bar:SetSize(865,90);
    bar:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=10,insets={left=3,right=3,top=3,bottom=3}});bar:SetBackdropColor(.04,.055,.075,1);
    A.Text(bar,"Сохранённый набор:",10,-13,110,"GameFontNormal");
    f.preset=CreateFrame("Frame","UnBotAltSetupsPresetDropdown",bar,"UIDropDownMenuTemplate");f.preset:SetPoint("TOPLEFT",bar,"TOPLEFT",112,-4);UIDropDownMenu_SetWidth(f.preset,200);
    UIDropDownMenu_Initialize(f.preset,function(self,level)
        local info=UIDropDownMenu_CreateInfo();info.text="Текущие данные альта (без набора)";info.checked=not A.draftLabel;info.func=function() A.LoadCurrent();end;UIDropDownMenu_AddButton(info,level);
        for _,label in ipairs(A.PresetNames(A.selected)) do local item=UIDropDownMenu_CreateInfo();item.text=label;item.checked=A.draftLabel==label;item.func=function() A.LoadPreset(label);end;UIDropDownMenu_AddButton(item,level);end
    end);
    A.Tooltip(f.preset,"Открыть сохранённый набор","Выберите набор для просмотра и редактирования. При смене набора несохранённые правки отменяются. Чтобы записать правки, нажмите «Сохранить изменения». Альт переоденется только после применения.");
    f.savePreset=A.Button(bar,"Сохранить изменения",350,-8,180,function() A.SaveDraft();end,"Сохранить в выбранный набор","Заменит настройки выбранного набора тем, что сейчас показано в окне. Перед сохранением появится название набора для подтверждения. Экипировка альта не изменится.");
    f.saveAs=A.Button(bar,"Сохранить как новый…",540,-8,185,function() A.NewPreset();end,"Создать отдельный набор","Запросит имя, сохранит все настройки из окна в новый набор и выберет его в списке. Прежний набор останется без изменений.");
    A.Button(bar,"Переименовать…",735,-8,120,function() A.RenameDraft();end,"Переименовать выбранный набор","Изменит только имя выбранного набора и ссылки на него в группах. Правки в окне сохраняются кнопкой «Сохранить изменения».");
    A.Button(bar,"Применить весь набор",10,-46,210,function() A.ApplyWhole();end,"Применить все разделы","Сравнит выбранный сохранённый набор с альтом и применит только отличающиеся разделы. Совпадающие вещи и таланты не меняются. Для одного раздела используйте кнопку на его вкладке.");
    A.Button(bar,"Отменить изменения",230,-46,180,function() A.ClearDraft();end);A.Button(bar,"Удалить…",425,-46,105,function() A.DeleteDraft();end,"Удалить выбранный набор","Удалит набор после подтверждения и снимет его назначения PvE/PvP и в группах. Экипировка альта не изменится.");f.personalNote=A.Text(bar,"",540,-45,305);f.personalNote:SetHeight(36);
    f.state=A.Text(f,"",230,-826,865);f.state:SetHeight(27);
    f.statusTip=CreateFrame("Frame",nil,f);f.statusTip:SetPoint("TOPLEFT",f,"TOPLEFT",230,-823);f.statusTip:SetSize(865,30);f.statusTip:EnableMouse(true);
    f.statusTip:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Состояние действия");A.AddHelpLines(f.state:GetText());GameTooltip:Show();end);f.statusTip:SetScript("OnLeave",function() GameTooltip:Hide();end);
    f:SetScript("OnHide",function() A.drag=nil;SetCursor(nil);if A.job or A.groupAssembly or A.parallelGroup or #A.queue>0 or A.pendingGearBags or A.pendingOutfitSave then A.Message("Окно закрыто. Начатое действие продолжается. Для остановки: /ubsetups stop.");end end);
    UISpecialFrames=UISpecialFrames or {};table.insert(UISpecialFrames,"UnBotAltSetupsWindow");local _,root=A.Storage();local pos=root.position;if pos then f:ClearAllPoints();f:SetPoint(pos.point,UIParent,pos.relative,pos.x,pos.y);end
    A.tab=A.tab or 1;return f;
end
function A.RefreshStatus()
    local f=A.window;if not f or not f:IsShown() then return;end
    local j=A.job;local text=A.status or "";
    if j then
        local labels={inspect="проверяем экипировку и таланты",co="проверяем настройки боя",nc="проверяем настройки вне боя",glyphs="читаем установленные символы",bags="читаем содержимое сумок",switch="переключаем спек",talents="распределяем таланты",gear="меняем экипировку",strategy="восстанавливаем личные настройки",ignored="проверяем запреты заклинаний",spellbook="обновляем заклинания",spell_change="меняем запрет заклинания",trade_bags="обновляем сумки",trade_request="запрашиваем вещь у альта"};
        text=j.name..": "..(j.wait and (labels[j.wait.kind] or "проверяем данные") or "проверяем данные").."...";
    end
    if j and j.gearProgress then
        local progress=j.gearProgress;local current=progress.current;
        if progress.stage=="commands" and current and current.action=="outfit_save" then
            text=j.name..": Сохраняем серверный аутфит «"..j.label.."».";
        elseif progress.stage=="commands" and current and current.action=="outfit_apply" then
            text=j.name..": Применяем аутфит «"..j.label.."» целиком.";
        elseif progress.stage=="commands" and current then
            local removing=current.action=="remove";
            local total=removing and progress.removeTotal or progress.equipTotal;
            text=j.name..": "..(removing and "Снимаем экипировку " or "Надеваем экипировку ")
                ..current.index.."/"..total.." — "..A.slotNames[current.slot]..".";
        elseif progress.stage=="verify" then
            text=j.name..": Проверяем результат переодевания.";
        elseif progress.stage=="verified" and j.fastGear then
            text=j.name..": Экипировка проверена. Сохраняем комплект.";
        end
    end
    if j and j.mode=="outfit_save" then text=j.name..": Сохраняем аутфит «"..j.label.."» на сервере.";end
    if j and j.mode=="trade" and j.tradePhase=="review" then text=j.name..": проверьте вещи и подтвердите обмен в окне WoW.";end
    local group=A.groupResult;
    if j and group and group.label then
        text="Подтверждено "..group.ok.." из "..group.total.." — "..text;
    end
    if j and j.progressive then text=j.name..": "..(j.readStatus or "Начинаем загрузку.");end
    local pending=A.gearRead.pending;
    if j and pending and pending.name==A.selected and pending.name~=j.name and A.gearRead.Visible(pending.name) then
        text=text.." Следом обновим данные: "..pending.name..".";
    end
    f.state:SetText(text);f.state:SetTextColor(A.bad and 1 or 0.8,A.bad and 0.35 or 0.88,A.bad and 0.3 or 1);
end
local function TalentCell(talent)
    return talent.tier..":"..talent.column
end
local function TalentPosition(talent)
    return 23+(talent.column-1)*59,-43-(talent.tier-1)*33
end
local function TalentLinkPart(treeUI,index,left,top,width,height,ready)
    if width<=0 or height<=0 then return index end
    index=index+1
    local part=treeUI.links[index]
    if not part then
        part=treeUI:CreateTexture(nil,"ARTWORK")
        treeUI.links[index]=part
    end
    part:ClearAllPoints()
    part:SetPoint("TOPLEFT",treeUI,"TOPLEFT",left,top)
    part:SetSize(width,height)
    if ready then part:SetTexture(1,.78,.23,1)
    else part:SetTexture(.48,.55,.65,.82) end
    part:Show()
    return index
end
local function DrawTalentLinks(treeUI,tree,byCell)
    treeUI.links=treeUI.links or {}
    local count=0
    for _,target in ipairs(tree and tree.talents or {}) do
        local tx,ty=TalentPosition(target)
        tx=tx+14
        for _,requirement in ipairs(target.prereqs or {}) do
            local source=byCell[TalentCell(requirement)]
            if source and source.tier<target.tier then
                local sx,sy=TalentPosition(source)
                sx=sx+14
                local ready=source.rank==source.maxRank
                if sx==tx and source.tier+1==target.tier then
                    count=TalentLinkPart(treeUI,count,tx-1,sy-29,2,sy-29-ty,ready)
                else
                    -- Route long links between columns so they do not run through talent icons.
                    local lane=sx+(tx<sx and -21 or 21)
                    count=TalentLinkPart(treeUI,count,math.min(sx,lane),sy-14,math.abs(sx-lane)+1,2,ready)
                    count=TalentLinkPart(treeUI,count,lane-1,sy-14,2,sy-14-ty+2,ready)
                    count=TalentLinkPart(treeUI,count,math.min(lane,tx),ty+3,math.abs(lane-tx)+1,2,ready)
                end
                count=TalentLinkPart(treeUI,count,tx-4,ty+4,9,1,ready)
                count=TalentLinkPart(treeUI,count,tx-2,ty+3,5,1,ready)
                count=TalentLinkPart(treeUI,count,tx-1,ty+2,3,2,ready)
            end
        end
    end
    for i=count+1,#treeUI.links do treeUI.links[i]:Hide() end
end
local function AddTalentRequirements(tree,talent)
    local pointsInEarlierTiers=0
    for _,other in ipairs(tree.talents) do
        if other.tier<talent.tier then pointsInEarlierTiers=pointsInEarlierTiers+other.rank end
    end
    local needed=(talent.tier-1)*5
    if needed>0 then
        local ready=pointsInEarlierTiers>=needed
        GameTooltip:AddLine("Очки в предыдущих рядах: "..pointsInEarlierTiers.." / "..needed,1,ready and .82 or .35,ready and .25 or .3,true)
    end
    for _,requirement in ipairs(talent.prereqs or {}) do
        for _,source in ipairs(tree.talents) do
            if source.tier==requirement.tier and source.column==requirement.column then
                local ready=source.rank==source.maxRank
                GameTooltip:AddLine("Требуется: "..source.name.." ("..source.rank.." / "..source.maxRank..")",1,ready and .82 or .35,ready and .25 or .3,true)
                break
            end
        end
    end
end
function A.Refresh()
    local f=A.window;if not f or not f:IsShown() then return;end
    local names=A.Names();f.roster:SetHeight(math.max(478,#names*63));
    for i,name in ipairs(names) do
        local row=f.rows[i];if not row then
            row=CreateFrame("Frame",nil,f.roster);row:SetSize(174,61);row:SetPoint("TOPLEFT",f.roster,"TOPLEFT",0,-(i-1)*63);
            row.choose=A.Button(row,"",0,-1,174,function(self) A.Select(self:GetParent().name);end);
            row.detail=A.Text(row,"",3,-28,168);f.rows[i]=row;
        end
        row.name=name;row.choose:SetText((name==A.selected and "• " or "")..name);
        local result=A.results[A.Key(name)];local unit=UnBotAccountAlts.FindUnit(name);
        row.detail:SetText(result and result.text or (unit and UnitIsConnected(unit) and "В группе, в игре" or "Не в игре или вне группы"));row.detail:SetHeight(28);row:Show();
    end
    for i=#names+1,#f.rows do f.rows[i]:Hide();end
    if #names==0 then A.status="Альты не найдены. Откройте «Альты аккаунта» и запустите поиск.";end
    f.selectedTitle:SetText(A.selected or "Выберите альта");
    UIDropDownMenu_SetText(f.preset,A.draftLabel or "Текущие данные альта");
    local e=A.selected and A.Entry(A.selected);local d=A.draft;
    f.sideSummary:SetText("Набор: "..(A.draftLabel or "текущие данные").."\n"..(d and ("Спек "..tostring(d.spec or "…")) or "Данные ещё не загружены"));
    f.personalNote:SetText(A.draftLabel and ((A.dirty and "Изменения для «" or "Открыт набор «")..A.draftLabel.."»."..(A.dirty and " Нажмите «Сохранить изменения» или «Сохранить как новый…»." or " Можно применить его или сохранить отдельную копию.")) or "Текущие данные альта. «Сохранить как новый…» создаст набор из настроек в окне.");
    if A.StateCaption and A.selected then f.sideSummary:SetText(f.sideSummary:GetText().."\n"..A.StateCaption(A.selected));f.sideSummary:SetHeight(46);end
    if A.tab==7 then f.side:Hide();f.content:Hide();f.groups:Show();A.RefreshGroups();else f.side:Show();f.content:Show();f.groups:Hide();end
    if (A.tab or 1)<=4 then f.personal:Show();else f.personal:Hide();end
    if A.tab==6 then f.behavior:Show();A.RefreshBehavior();else f.behavior:Hide();end
    if (A.tab or 1)==1 then f.gear:Show();f.gear.bagTitle:Show();else f.gear:Hide();f.gear.bagTitle:Hide();end
    if A.tab==2 then f.talents:Show();else f.talents:Hide();end
    if A.tab==3 then f.glyphs:Show();else f.glyphs:Hide();end
    local u=A.selected and UnBotAccountAlts.FindUnit(A.selected);
    for i,b in pairs(f.gear.slots) do A.SetIcon(b,d and d.gear[i],A.slotNames[i]);end
    if (A.tab or 1)==1 and d and u and UnitIsConnected(u) then
        local showHelm=not ShowingHelm or ShowingHelm();
        local parts={tostring(UnitGUID(u)),tostring(u),tostring(showHelm)};for i=1,19 do parts[#parts+1]=tostring(A.ItemKey(d.gear[i]));end
        local modelKey=table.concat(parts,"|");f.gear.model:Show();
        if f.gear.modelKey~=modelKey then
            f.gear.model:SetUnit(u);
            local actual=A.cache[A.Key(A.selected)];local preview=false;
            for slot=1,19 do if not actual or A.ItemKey(d.gear[slot])~=A.ItemKey(actual.gear[slot]) then preview=true;end end
            if preview then
                f.gear.model:Undress();
                -- Preview follows this client's helmet preference; SetUnit keeps the alt's native appearance.
                for slot=1,19 do if slot~=16 and (slot~=1 or showHelm) and d.gear[slot] then f.gear.model:TryOn(d.gear[slot]);end end
                if d.gear[16] then f.gear.model:TryOn(d.gear[16]);end
            end
            f.gear.modelKey=modelKey;
        end
        f.gear.model:SetFacing(A.rotation or 0);f.gear.note:SetText("");
    else f.gear.modelKey=nil;f.gear.model:Hide();f.gear.note:SetText("Чтобы увидеть модель, добавьте альта в группу. Сохранённый набор можно посмотреть и без него.");end
    A.RefreshGearOptions();
    local ok,points=A.ValidTalents(d);f.talents.summary:SetText(d and ((A.draftLabel and ("Набор «"..A.draftLabel.."»: ") or "В редакторе: ")..A.TalentStateText(d).."\nОчки: "..(ok and points or (d.trees and "ошибка" or "загрузка")).." / "..math.max(0,d.level-9)) or "Нажмите «Обновить данные».");
    local actual=A.selected and A.cache[A.Key(A.selected)];local flags=A.selected and A.stateFlags[A.Key(A.selected)];
    f.talents.actual:SetText(actual and actual.trees and ("У альта активен: "..A.TalentStateText(actual)..(flags and flags.talents=="loaded" and " (последнее чтение)" or " (не проверено)")) or "Активный спек альта ещё не прочитан.");
    for tab,treeUI in ipairs(f.talents.trees) do
        local tree=A.tab==2 and d and d.trees and d.trees[tab];local spent=0;local byCell={};
        for index,t in ipairs(tree and tree.talents or {}) do
            spent=spent+t.rank;byCell[TalentCell(t)]=t;local b=treeUI.buttons[index];
            if not b then
                b=A.Icon(treeUI,29);b.rank=A.Text(b,"",0,-24,40,"GameFontNormalSmall");b.tab=tab;b.index=index;
                b:RegisterForClicks("LeftButtonUp","RightButtonUp");b:SetScript("OnClick",function(self,button) A.ChangeTalent(self.tab,self.index,button=="RightButton" and -1 or 1);end);
                b:SetScript("OnEnter",function(self)
                    local tree=A.draft and A.draft.trees and A.draft.trees[self.tab];local talent=tree and tree.talents[self.index];if not talent then return;end
                    GameTooltip:SetOwner(self,"ANCHOR_RIGHT");if talent.talentId then GameTooltip:SetHyperlink("talent:"..talent.talentId..":"..math.max(0,talent.rank-1));else GameTooltip:SetText(talent.name);end
                    GameTooltip:AddLine("В наборе: "..talent.rank.." / "..talent.maxRank,1,0.82,0);AddTalentRequirements(tree,talent);GameTooltip:Show();
                end);treeUI.buttons[index]=b;
            end
            b:ClearAllPoints();b:SetPoint("TOPLEFT",treeUI,"TOPLEFT",TalentPosition(t));b.icon:SetTexture(t.icon or "Interface\\Icons\\INV_Misc_QuestionMark");b.icon:SetDesaturated(t.rank==0);b.rank:SetText(t.rank.."/"..t.maxRank);b:Show();
        end
        for index=#(tree and tree.talents or {})+1,#treeUI.buttons do treeUI.buttons[index]:Hide();end
        DrawTalentLinks(treeUI,tree,byCell);
        treeUI.title:SetText(tree and (tree.name..": "..spent) or "Ветка "..tab);
    end
    for i,b in ipairs(f.glyphs.icons) do local link=d and d.glyphs and d.glyphs[i];A.SetIcon(b,link,"Символ не указан");b.title:SetText(link and ((A.ItemInfo and A.ItemInfo(link).name) or link) or "—");end
    A.RefreshSpells();A.RefreshTrade();A.RefreshStatus();
end
function A.Show()
    local f=A.Create();f:Show();
    if A.selected and UnBotAccountAlts.CanAddToSquad and not UnBotAccountAlts.CanAddToSquad(A.selected) then A.selected=nil;A.draft=nil;A.draftLabel=nil;A.dirty=false;end
    if not A.selected then local names=A.Names();if names[1] then A.Select(names[1]);end end
    A.Refresh();
end

-- Spell rules are draft data; reading or selecting a row never changes the bot.
function A.MakeSpells(parent)
    local p=CreateFrame("Frame",nil,parent);p:SetAllPoints(parent);p.rows={};
    A.Button(p,"Обновить заклинания",12,-8,200,function() A.spells.Read();end,"Обновить список заклинаний","Покажет заклинания альта и текущие запреты.\nАльт должен быть в игре и в группе.");
    A.Text(p,"Поиск",232,-14,70);p.search=A.Edit(p,294,-10,240);p.search:SetScript("OnTextChanged",function() A.spellPage=1;A.RefreshSpells();end);
    p.filter=A.Button(p,"Только запрещённые",555,-8,220,function() A.spellOnlyBanned=not A.spellOnlyBanned;A.spellPage=1;A.RefreshSpells();end);
    A.Text(p,"Выберите, какие заклинания альту разрешено использовать, затем нажмите «Применить запреты».\nНастройки сохранятся в выбранном личном наборе.",12,-42,828);
    for i=1,8 do
        local row=CreateFrame("Frame",nil,p);row:SetSize(840,43);row:SetPoint("TOPLEFT",p,"TOPLEFT",12,-85-(i-1)*46);
        row.icon=A.Icon(row,32);row.icon:SetPoint("TOPLEFT",0,0);
        row.icon:SetScript("OnEnter",function(self) if self.spell then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetHyperlink("spell:"..self.spell);GameTooltip:Show();end end);
        row.title=A.Text(row,"",43,0,340);row.state=A.Text(row,"",43,-19,340);
        row.keep=A.Button(row,"Не менять",395,-2,125,function(self) A.spells.Set(self:GetParent().id,nil);end,"Оставить текущую настройку","При применении набора запрет этого заклинания не изменится.");
        row.ban=A.Button(row,"Запретить",529,-2,138,function(self) A.spells.Set(self:GetParent().id,true);end,"Запретить заклинание","После применения набора альт не будет использовать это заклинание.");
        row.allow=A.Button(row,"Разрешить",676,-2,146,function(self) A.spells.Set(self:GetParent().id,false);end,"Разрешить заклинание","После применения набора запрет будет снят.\nАльт сам выбирает, когда использовать заклинание.");
        p.rows[i]=row;
    end
    A.Button(p,"Назад",12,-459,100,function() A.spellPage=math.max(1,(A.spellPage or 1)-1);A.RefreshSpells();end);
    p.page=A.Text(p,"",134,-466,550);
    A.Button(p,"Далее",724,-459,100,function() A.spellPage=(A.spellPage or 1)+1;A.RefreshSpells();end);
    A.Text(p,"Показаны активные классовые и расовые способности. Профессии, транспорт и эффекты предметов скрыты; их сохранённые запреты остаются.\nКаждый ранг настраивается отдельно. Серые способности не найдены в последнем списке альта.",12,-500,830);
    A.SectionActions(p,"spells");
    return p;
end
function A.RefreshSpells()
    local f=A.window;if not f or not f.spells then return;end;local p=f.spells;
    if A.tab==4 then p:Show();else p:Hide();return;end
    local data=A.selected and A.Entry(A.selected).spellbook;local rules=A.draft and A.draft.spellRules or {};
    local ids,seen={},{};local hidden=0;for _,id in ipairs(data and data.ids or {}) do seen[id]=true;end
    for id in pairs(rules) do seen[id]=true;end;for id in pairs(data and data.ignored or {}) do seen[id]=true;end
    local search=(p.search:GetText() or ""):lower();
    for id in pairs(seen) do
        if A.spells.Visible(id) then
        local name,rank,icon=GetSpellInfo(id);name=name or ("Заклинание "..id);
        if (search=="" or name:lower():find(search,1,true) or tostring(id):find(search,1,true)) and (not A.spellOnlyBanned or rules[id]==true or (data and data.ignored[id])) then
            ids[#ids+1]={id=id,name=name,rank=rank,icon=icon};
        end
        else hidden=hidden+1;end
    end
    table.sort(ids,function(x,y) if x.name==y.name then return x.id<y.id;end;return x.name<y.name;end);
    p.filter:SetText(A.spellOnlyBanned and "Показать все" or "Только запрещённые");
    local pages=math.max(1,math.ceil(#ids/8));A.spellPage=math.min(pages,math.max(1,A.spellPage or 1));
    local learned={};for _,id in ipairs(data and data.ids or {}) do learned[id]=true;end
    for i,row in ipairs(p.rows) do
        local v=ids[(A.spellPage-1)*8+i];
        if v then
            row.id=v.id;row.icon.spell=v.id;row.icon.icon:SetTexture(v.icon or "Interface\\Icons\\INV_Misc_QuestionMark");row.icon.icon:SetDesaturated(not learned[v.id]);
            row.title:SetText(v.name..((v.rank and v.rank~="") and (" / "..v.rank) or "").." ["..v.id.."]");
            local current=data and (data.ignored[v.id] and "запрещено" or "разрешено") or "нет данных";
            local rule=rules[v.id]==true and "Запретить" or (rules[v.id]==false and "Разрешить" or "Не менять");
            row.state:SetText("У альта: "..current..". В наборе: "..rule..(not learned[v.id] and " / не найдено" or ""));row:Show();
        else row:Hide();end
    end
    p.page:SetText("Страница "..A.spellPage.." / "..pages..", способностей: "..#ids..(hidden>0 and "; скрыто прочих: "..hidden or "")..(not data and "; нажмите «Обновить заклинания»" or ""));
end
function A.MakeTrade(parent)
    local p=CreateFrame("Frame",nil,parent);p:SetAllPoints(parent);p.mine={};p.alt={};
    p:SetScript("OnShow",function() end);
    A.Button(p,"Обновить сумки",12,-8,195,function() A.trade.Start(true);end,"Обновить содержимое сумок","Покажет ваши вещи и вещи выбранного альта.\nНажмите кнопку, чтобы запросить актуальные сумки. Открытие вкладки использует сохранённые данные.");
    A.Text(p,"Количество для альта",228,-15,205);p.amount=A.Edit(p,431,-10,55);p.amount:SetText("1");p.amount:SetMaxLetters(5);
    A.Text(p,"У альта можно забрать целую стопку вещи",511,-15,320);
    A.Text(p,"Мои сумки: передать альту",12,-49,400,"GameFontNormal");p.altTitle=A.Text(p,"Сумки альта: забрать себе",450,-49,400,"GameFontNormal");
    for i=1,56 do
        for _,side in ipairs({"mine","alt"}) do
            local b=A.Icon(p,35);b:SetPoint("TOPLEFT",p,"TOPLEFT",(side=="mine" and 16 or 454)+((i-1)%8)*49,-78-math.floor((i-1)/8)*47);
            b.selection=b:CreateTexture(nil,"OVERLAY");b.selection:SetAllPoints(b);b.selection:SetTexture(0.1,0.9,0.25,0.4);b.selection:Hide();
            b.count=A.Text(b,"",0,-24,45,"GameFontNormalSmall");b.side=side;
            b.help=side=="mine" and "Укажите количество в поле над сумками.\nНажмите на вещь, чтобы выбрать её.\nПовторный клик снимает выбор.\nЗа один обмен можно передать до шести стопок." or "Клик по обычной вещи выбирает стопку для передачи.\nПерсональная вещь попадёт в седьмую ячейку для зачарования.\nПовторный клик снимает выбор.\nМожно выбрать до шести разных вещей.\nКоличество проверьте в окне обмена.";
            b:SetScript("OnClick",function(self)
                if self.row then A.trade.Toggle(self.row,self.side=="mine" and "give" or "take",self.side=="mine" and tonumber(p.amount:GetText()) or 1);end
            end);p[side][i]=b;
        end
    end
    A.Button(p,"Назад",12,-412,85,function() A.tradePage=math.max(1,(A.tradePage or 1)-1);A.RefreshTrade();end);
    p.page=A.Text(p,"",113,-420,610);
    A.Button(p,"Далее",748,-412,85,function() A.tradePage=(A.tradePage or 1)+1;A.RefreshTrade();end);
    A.Button(p,"Запросить обмен",12,-450,205,function() A.trade.Start(false);end,"Открыть обмен с альтом","Добавит выбранные вещи в окно обмена.\nПроверьте количество и подтвердите передачу в окне WoW.\nАльт должен стоять рядом.");
    A.Button(p,"Снять выбор",229,-450,180,function() if not A.job then A.trade.cart={};A.RefreshTrade();end end);
    A.Button(p,"Отменить обмен",421,-450,180,function() A.Stop("Обмен остановлен. Проверьте сумки перед новым запросом.");end);
    p.restore=A.Button(p,"Вернуть вещь",613,-450,210,function() A.trade.RestorePending();end,"Вернуть снятую вещь","Повторно проверит альта и наденет вещь, если её не удалось вернуть после зачарования. Другая вещь в исходной ячейке не заменяется.");
    A.Text(p,"Выберите вещи кликом, затем нажмите «Запросить обмен». Повторный клик снимает выбор.\nСвои вещи появятся в обмене автоматически. Для деления стопки нужно место в обычной сумке.\nУ альта берётся целая стопка выбранной вещи. Проверьте количество и подтвердите обмен в окне WoW.",12,-490,832);
    A.Text(p,"Надетые вещи альта — клик для зачарования в седьмой ячейке обмена",12,-553,830,"GameFontNormal");
    p.equipped={};
    for slot=1,19 do
        local b=A.Icon(p,29);b:SetPoint("TOPLEFT",p,"TOPLEFT",16+(slot-1)*43,-580);
        b.selection=b:CreateTexture(nil,"OVERLAY");b.selection:SetAllPoints(b);b.selection:SetTexture(.1,.9,.25,.4);b.selection:Hide();
        b.help="Выберите одну вещь для зачарования: надетую или из сумки. Она появится в ячейке «Не будет передано». Снимать вещь не требуется.";
        b:SetScript("OnClick",function(self) if self.row then A.trade.Toggle(self.row,"take",1);end end);
        p.equipped[slot]=b;
    end
    return p;
end
function A.RefreshTrade()
    local f=A.window;if not f or not f.trade then return;end;local p=f.trade;local t=A.trade;
    if A.tab==5 then p:Show();else p:Hide();return;end
    if t.owner~=A.selected and not A.job then t.cart={};t.owner=A.selected;end
    if A.selected and A.Entry(A.selected).pendingEnchantReturn then p.restore:Show();else p.restore:Hide();end
    local mine=t.PlayerBags();local data=A.selected and t.bags[A.Key(A.selected)];local alt=data and data.rows or {};
    local pages=math.max(1,math.ceil(math.max(#mine,#alt)/56));A.tradePage=math.min(pages,math.max(1,A.tradePage or 1));
    local giving,taking=0,0;for _,v in ipairs(t.cart) do if v.direction=="give" then giving=giving+1;else taking=taking+1;end end
    for _,side in ipairs({"mine","alt"}) do for i,b in ipairs(p[side]) do
        local row=(side=="mine" and mine or alt)[(A.tradePage-1)*56+i];b.row=row;A.SetIcon(b,row and row.link,"Пустая ячейка");
        b.count:SetText(row and tostring(row.count) or "");b.icon:SetDesaturated(row and (row.locked or (side=="mine" and row.bound)) or false);
        if not (A.job and A.job.mode=="trade") and t.Selected(row,side=="mine" and "give" or "take") then b.selection:Show();else b.selection:Hide();end
    end end
    local actual=A.selected and A.cache[A.Key(A.selected)];
    for slot,b in ipairs(p.equipped) do
        local link=actual and actual.gear[slot];b.row=link and {id=A.ItemID(link),link=link,bound=true,count=1};A.SetIcon(b,link,A.slotNames[slot]);
        if t.Selected(b.row,"take") and not A.job then b.selection:Show();else b.selection:Hide();end
    end
    p.altTitle:SetText("Сумки "..(A.selected or "альта")..": забрать или зачаровать");
    p.page:SetText("Страница "..A.tradePage.." / "..pages.."; выбрано для альта: "..giving.." / 6, себе "..taking.." / 6"..(not data and "; обновите сумки альта" or ""));
end

function A.RefreshAlt()
    if not A.selected then return;end
    if A.dirty then A.Status("Сохраните изменения или отмените их перед обновлением.",true);return;end
    if A.Start(A.selected,nil,(A.tab or 1)==1) and A.job and A.job.mode=="read" then A.job.autoGearRead=true;end
end
function A.LoadCurrent()
    if A.job or not A.selected then A.Status("Дождитесь завершения действия или нажмите «Стоп».",true);return;end
    A.dirty=false;A.drag=nil;SetCursor(nil);
    A.Entry(A.selected).selectedPreset=false;A.draftLabel=nil;A.draft=A.Copy(A.cache[A.Key(A.selected)]);A.viewCurrent=true;A.Refresh();if not A.draft then A.Status("Данные ещё не загружены. Нажмите «Обновить данные».");end
end
function A.NewPreset()
    local p=A.EditorSaveIntent();if not p then return;end
    A.pendingNewPreset=p;StaticPopup_Show("UNBOT_SETUP_SAVE_AS");
end
function A.RenameDraft(label,intent)
    if not intent then
        if A.job then A.Status("Дождитесь завершения действия или нажмите «Стоп».",true);return;end
        if not A.selected or not A.draftLabel then A.Status("Сначала выберите сохранённый набор.",true);return;end
        A.pendingRename={name=A.selected,label=A.draftLabel,context=A.Context()};StaticPopup_Show("UNBOT_SETUP_RENAME",A.draftLabel);return;
    end
    if intent.context~=A.Context() then return;end
    local old=intent.label;local ok,answer=A.RenamePreset(intent.name,old,label);
    if not ok then A.Status(answer,true);return;end
    if A.selected==intent.name and A.draftLabel==old then A.draftLabel=answer;end
    if A.groupDraft then for _,m in pairs(A.groupDraft.members or {}) do if A.Key(m.name)==A.Key(intent.name) and m.preset==old then m.preset=answer;end end end
    A.Status("Набор переименован в «"..answer.."».");A.Refresh();
end

function A.DeleteDraft(intent)
    if not intent then
        if A.job or #A.queue>0 or A.groupAssembly then A.Status("Дождитесь завершения текущего действия или нажмите «Стоп».",true);return;end
        if not A.selected or not A.draftLabel then A.Status("Сначала выберите сохранённый набор.",true);return;end
        A.pendingDelete={name=A.selected,label=A.draftLabel,context=A.Context(),preset=A.Entry(A.selected).presets[A.draftLabel]};
        StaticPopup_Show("UNBOT_SETUP_DELETE",A.selected..": «"..A.draftLabel.."»");return;
    end
    if intent.context~=A.Context() then A.Status("Персонаж изменился. Выберите набор заново.",true);return;end
    local ok,reason=A.DeletePreset(intent.name,intent.label,intent.preset);
    if not ok then A.Status(reason,true);return;end
    if A.groupDraft then for _,m in pairs(A.groupDraft.members or {}) do
        if A.Key(m.name)==A.Key(intent.name) and m.preset==intent.label then m.preset=nil;end
    end end
    if A.selected==intent.name and A.draftLabel==intent.label then A.LoadCurrent();end
    A.Status(intent.name..": набор «"..intent.label.."» удалён. Его назначения сняты; экипировка альта не изменена.");A.Refresh();
end
StaticPopupDialogs.UNBOT_SETUP_DELETE={text="Удалить набор %s? Его назначения PvE/PvP и в группах будут сняты. Несохранённые правки этого набора будут отменены. Экипировка альта не изменится.",button1="Удалить",button2="Отмена",timeout=0,whileDead=true,hideOnEscape=true,
    OnAccept=function() local p=A.pendingDelete;A.pendingDelete=nil;if p then A.DeleteDraft(p);end;end,
    OnCancel=function() A.pendingDelete=nil;end};
function A.ApplyWhole()
    if not A.draftLabel or A.dirty then A.Status("Сначала сохраните набор. Для применения одного раздела нажмите кнопку на его вкладке.",true);return;end
    A.Start(A.selected,A.draftLabel);
end
function A.ApplySection(section)
    local job=A.job;
    if section=="gear" and job and job.progressive and job.name==A.selected and job.bags then
        A.Finish(true,"Переходим к применению экипировки.");
    end
    if not A.selected or not A.draft then A.Status("Выберите альта и обновите данные.",true);return;end
    local label=A.draftLabel;
    A.StartSection(A.selected,label,section,A.draft);
end
function A.SectionActions(p,section)
    local labels={talents="Применить и сохранить таланты",gear="Применить экипировку",spells="Применить запреты"};
    p.apply=A.Button(p,labels[section],14,-548,250,function() A.ApplySection(section);end,"Применить и сохранить","Изменит только этот раздел у альта. После проверки сохранит результат в выбранном наборе. Если набор ещё не создан, создаст новый.");
    A.Text(p,"После применения этот раздел сохранится в выбранном наборе. Остальные изменения в окне останутся для редактирования.",14,-586,820);
end
function A.MakeBehavior(parent)
    local p=CreateFrame("Frame",nil,parent);p:SetAllPoints(parent);
    A.Text(p,"Поведение выбранного альта",14,-14,820,"GameFontNormalLarge");p.summary=A.Text(p,"",14,-58,820);p.summary:SetHeight(250);
    p.edit=A.Button(p,"Редактировать стратегии",14,-330,280,function()
        if not A.selected then A.Status("Выберите альта слева.",true);return;end
        if UnBotAltStrategies and UnBotAltStrategies.Open then UnBotAltStrategies.Open(A.selected);end
    end);
    A.Text(p,"Откроется редактор личного профиля этого альта. Сохранение и применение стратегий выполняются в нём. Эти настройки не входят в набор экипировки и талантов.",14,-380,810);return p;
end
function A.RefreshBehavior()
    local s=UnBotAltStrategies;A.window.behavior.summary:SetText(A.selected and s and s.Summary and s.Summary(A.selected) or "Выберите альта слева.");
end
function A.GroupLoad(label)
    if A.groupDirty then A.Status("Сохраните группу или отмените её изменения.",true);return;end
    local g=A.GroupStorage().profiles[label];if not g then return;end
    A.groupLabel=label;A.groupDraft=A.Copy(g);if A.window then A.window.groups.name:SetText(label);end;A.Refresh();
end
function A.GroupSaveDraft()
    if not A.groupDraft then return false;end
    local ok,label=A.SaveGroup(A.window.groups.name:GetText(),A.groupDraft,A.groupLabel);
    if not ok then A.Status(label,true);return false;end
    A.groupLabel=label;A.groupDirty=false;A.groupDraft=A.Copy(A.GroupStorage().profiles[label]);A.Status("Группа «"..label.."» сохранена.");A.Refresh();return true;
end
function A.MakeGroups(parent)
    local p=CreateFrame("Frame",nil,parent);p.rows={};
    A.Text(p,"Группы наборов",8,-8,350,"GameFontNormalLarge");
    p.pick=CreateFrame("Frame","UnBotSetupGroupDropdown",p,"UIDropDownMenuTemplate");p.pick:SetPoint("TOPLEFT",p,"TOPLEFT",0,-39);UIDropDownMenu_SetWidth(p.pick,220);
    UIDropDownMenu_Initialize(p.pick,function(self,level) for _,label in ipairs(A.GroupNames()) do local item=UIDropDownMenu_CreateInfo();item.text=label;item.checked=A.groupLabel==label;item.func=function() A.GroupLoad(label);end;UIDropDownMenu_AddButton(item,level);end end);
    A.Text(p,"Название:",280,-49,85);p.name=A.Edit(p,370,-45,230);
    A.Button(p,"Новая группа",630,-43,180,function() if A.groupDirty then A.Status("Сохраните группу или отмените её изменения.",true);return;end;A.groupLabel=nil;A.groupDraft={members={}};A.groupDirty=true;p.name:SetText("");A.Refresh();end);
    A.Text(p,"Выберите участников и назначьте каждому его личный набор. Сохранение группы не меняет альтов.",8,-88,1050);
    A.Text(p,"Участвует       Альт",8,-125,380,"GameFontNormal");A.Text(p,"Личный набор",390,-125,350,"GameFontNormal");A.Text(p,"Доступность",810,-125,230,"GameFontNormal");
    local scroll=CreateFrame("ScrollFrame","UnBotSetupGroupScroll",p,"UIPanelScrollFrameTemplate");scroll:SetPoint("TOPLEFT",p,"TOPLEFT",8,-151);scroll:SetSize(1035,370);
    p.list=CreateFrame("Frame",nil,scroll);p.list:SetSize(1015,370);scroll:SetScrollChild(p.list);
    A.Button(p,"Сохранить группу",8,-546,220,function() A.GroupSaveDraft();end);
    A.Button(p,"Собрать и применить",246,-546,220,function() if A.GroupSaveDraft() then A.StartNamedGroup(A.groupLabel);end end,"Собрать группу и применить наборы","Сохранит назначения и призовёт недостающих альтов. Затем применит наборы до трёх альтов одновременно; осмотр выполняется по очереди. Окно можно закрыть. Отмена: «Стоп» или /ubsetups stop.");
    A.Button(p,"Отменить изменения",484,-546,220,function() A.groupDirty=false;A.groupDraft=nil;if A.groupLabel then A.GroupLoad(A.groupLabel);else A.Refresh();end end);
    p.note=A.Text(p,"",8,-587,1030);
    A.Text(p,"Макрос для сбора группы и применения наборов",8,-624,650);p.macro=A.Edit(p,8,-648,700);p.macro:SetMaxLetters(255);
    return p;
end
function A.RefreshGroups()
    local p=A.window.groups;
    if not A.groupDraft then local label=A.groupLabel or A.GroupNames()[1];A.groupLabel=label;A.groupDraft=A.Copy(A.GroupStorage().profiles[label]);p.name:SetText(label or "");end
    UIDropDownMenu_SetText(p.pick,A.groupLabel or "Новая группа");p.macro:SetText(A.groupLabel and ("/ubsetups group "..A.groupLabel) or "Сначала сохраните группу");
    p.note:SetText(A.groupDirty and "Есть несохранённые изменения группы." or "Недостающие альты будут призваны, если есть место. Текущие участники останутся в группе.");
    local names=A.Names();p.list:SetHeight(math.max(370,#names*45));
    for i,name in ipairs(names) do
        local row=p.rows[i];if not row then
            row=CreateFrame("Frame",nil,p.list);row:SetSize(1015,43);row:SetPoint("TOPLEFT",p.list,"TOPLEFT",0,-(i-1)*45);
            row.check=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate");row.check:SetSize(24,24);row.check:SetPoint("TOPLEFT",0,-3);
            row.title=A.Text(row,"",90,-10,270);row.state=A.Text(row,"",802,-10,210);
            row.pick=CreateFrame("Frame","UnBotSetupGroupMember"..i,row,"UIDropDownMenuTemplate");row.pick:SetPoint("TOPLEFT",row,"TOPLEFT",365,0);UIDropDownMenu_SetWidth(row.pick,360);
            row.check:SetScript("OnClick",function(self) local r=self:GetParent();local m=A.groupDraft.members[A.Key(r.name)] or {name=r.name,preset=A.PresetNames(r.name)[1]};m.enabled=self:GetChecked() and true or false;A.groupDraft.members[A.Key(r.name)]=m;A.groupDirty=true;A.RefreshGroups();end);
            UIDropDownMenu_Initialize(row.pick,function(self,level) local r=self:GetParent();for _,label in ipairs(A.PresetNames(r.name)) do local info=UIDropDownMenu_CreateInfo();info.text=label;info.func=function() local m=A.groupDraft.members[A.Key(r.name)] or {name=r.name};m.preset=label;m.enabled=true;A.groupDraft.members[A.Key(r.name)]=m;A.groupDirty=true;A.RefreshGroups();end;UIDropDownMenu_AddButton(info,level);end end);p.rows[i]=row;
        end
        row.name=name;local m=A.groupDraft.members[A.Key(name)];row.check:SetChecked(m and m.enabled==true);row.title:SetText(name);UIDropDownMenu_SetText(row.pick,m and m.preset or "Выберите набор");
        local u=UnBotAccountAlts.FindUnit(name);row.state:SetText(u and UnitIsConnected(u) and "В группе, в игре" or "Требуется призыв");row:Show();
    end
    for i=#names+1,#p.rows do p.rows[i]:Hide();end
end

function A.FilterGearSlot(slot)
    A.gearFilter=slot;A.drag=nil;SetCursor(nil);
    if A.window and A.window.gear then A.window.gear.optionScroll:SetVerticalScroll(0);end
    A.Refresh();
end
function A.GearOptionGroups()
    local groups,bySlot={},{};local unknown,total=0,0;
    for _,link in ipairs(A.draft and A.draft.bags or {}) do
        local info=A.ItemInfo and A.ItemInfo(link);
        local loc=info and info.equipLoc or select(9,GetItemInfo(link));
        if loc==nil then unknown=unknown+1;
        elseif loc~="" then
            local selected=A.gearFilter;
            if selected then
                if not A.CanPlace(selected,link,loc) then selected=nil;end
            else
                for slot=1,19 do if A.CanPlace(slot,link,loc) then selected=slot;break end end
                if selected==12 then selected=11;elseif selected==14 then selected=13;end
            end
            if selected then
                if not bySlot[selected] then bySlot[selected]={slot=selected,items={}};end
                local group=bySlot[selected];group.items[#group.items+1]=link;total=total+1;
            end
        end
    end
    for slot=1,19 do if bySlot[slot] then groups[#groups+1]=bySlot[slot];end end
    return groups,total,unknown;
end
function A.GearOptionIcon(parent)
    local button=A.Icon(parent,36);
    button.help="Правая кнопка: добавить вещь в комплект.\nЛевая кнопка: выбрать вещь, затем нажать на нужную ячейку.";
    button:RegisterForClicks("LeftButtonUp","RightButtonUp");button:RegisterForDrag("LeftButton");
    local function pick(self)
        if self.link then A.drag={link=self.link,name=A.selected,at=GetTime()};SetCursor(select(10,GetItemInfo(self.link)));A.Status("Вещь выбрана. Нажмите на нужную ячейку экипировки.");end
    end
    button:SetScript("OnClick",function(self,mouseButton)
        if mouseButton=="RightButton" then A.EquipFromBag(self.link);else pick(self);end
    end);
    button:SetScript("OnDragStart",pick);button:SetScript("OnDragStop",function() SetCursor(nil);end);
    return button;
end
function A.RefreshGearOptions()
    local p=A.window and A.window.gear;if not p then return;end
    local groups,total,unknown=A.GearOptionGroups();local count,x,y=0,0,0;
    local width,pitch,rowHeight=350,44,74;
    p.filterLabel:SetText(A.gearFilter and A.slotNames[A.gearFilter] or "Все слоты");
    for index,group in ipairs(groups) do
        local title=p.groupTitles[index];
        if not title then title=A.Text(p.optionContent,"",0,0,345,"GameFontNormal");p.groupTitles[index]=title;end
        local label=A.slotNames[group.slot];
        if not A.gearFilter then
            if group.slot==11 then label="Кольца";elseif group.slot==13 then label="Аксессуары";end
        end
        title:SetWidth(width);title:SetText(label.." ("..#group.items..")");
        local titleWidth=math.min(width,math.ceil(title:GetStringWidth()+2));
        local groupWidth=math.max(math.min(#group.items,8)*pitch-8,titleWidth);
        if x>0 and x+groupWidth>width then x=0;y=y+rowHeight;end
        local groupX,groupY=x,y;
        title:ClearAllPoints();title:SetWidth(groupWidth);title:SetPoint("TOPLEFT",p.optionContent,"TOPLEFT",x,-y);title:Show();
        for itemIndex,link in ipairs(group.items) do
            count=count+1;local button=p.bags[count];
            if not button then button=A.GearOptionIcon(p.optionContent);p.bags[count]=button;end
            if x+36>width then x=0;y=y+rowHeight;end
            button:ClearAllPoints();button:SetPoint("TOPLEFT",p.optionContent,"TOPLEFT",x,-y-24);
            x=x+pitch;
            A.SetIcon(button,link,"");button:Show();
        end
        x=x-8;
        if y==groupY then x=math.max(x,groupX+titleWidth);end
        x=x+12;
    end
    for index=#groups+1,#p.groupTitles do p.groupTitles[index]:Hide();end
    for index=count+1,#p.bags do p.bags[index]:Hide();end
    p.optionContent:SetHeight(math.max(308,y+rowHeight));
    local status=total>0 and ("Доступно вещей: "..total) or (A.gearFilter and "Для этой ячейки вещей нет." or "Доступной экипировки нет.");
    if unknown>0 then status=status.." Загружаются сведения о вещах: "..unknown..".";end
    p.page:SetText(status);
end


do
local A=UnBotAltSetups
-- BEGIN ALT SPELL CATALOG
local catalog={classes={[10]=128,[17]=16,[53]=8,[66]=128,[67]=2,[71]=1,[72]=1,[75]=4,[78]=1,[99]=1024,[100]=1,[116]=128,[118]=128,[120]=128,[122]=128,[126]=256,[130]=128,[131]=64,[132]=256,[133]=128,[136]=4,[139]=16,[143]=128,[145]=128,[168]=128,[172]=256,[205]=128,[284]=1,[285]=1,[324]=64,[325]=64,[331]=64,[332]=64,[339]=1024,[348]=256,[355]=1,[370]=64,[379]=64,[403]=64,[408]=8,[421]=64,[453]=16,[465]=2,[467]=1024,[469]=1,[475]=128,[498]=2,[526]=64,[527]=16,[528]=16,[529]=64,[543]=128,[546]=64,[547]=64,[548]=64,[552]=16,[556]=64,[585]=16,[586]=16,[587]=128,[588]=16,[589]=16,[591]=16,[592]=16,[594]=16,[596]=16,[597]=128,[598]=16,[600]=16,[602]=16,[603]=256,[604]=128,[605]=16,[633]=2,[635]=2,[639]=2,[642]=2,[643]=2,[647]=2,[676]=1,[686]=256,[687]=256,[688]=256,[689]=256,[691]=256,[693]=256,[694]=1,[695]=256,[696]=256,[697]=256,[698]=256,[699]=256,[702]=256,[703]=8,[705]=256,[706]=256,[707]=256,[709]=256,[710]=256,[712]=256,[724]=16,[740]=1024,[755]=256,[759]=128,[768]=1024,[769]=1024,[770]=1024,[772]=1,[774]=1024,[779]=1024,[780]=1024,[781]=4,[782]=1024,[783]=1024,[837]=128,[845]=1,[853]=2,[865]=128,[871]=1,[879]=2,[883]=4,[905]=64,[913]=64,[915]=64,[921]=8,[930]=64,[939]=64,[943]=64,[945]=64,[959]=64,[970]=16,[974]=64,[976]=16,[980]=256,[982]=4,[984]=16,[988]=16,[990]=128,[992]=16,[996]=16,[1002]=4,[1004]=16,[1006]=16,[1008]=128,[1010]=256,[1014]=256,[1022]=2,[1026]=2,[1032]=2,[1038]=2,[1042]=18,[1044]=2,[1058]=1024,[1062]=1024,[1064]=64,[1066]=1024,[1075]=1024,[1079]=1024,[1082]=1024,[1086]=256,[1088]=256,[1094]=256,[1098]=256,[1106]=256,[1108]=256,[1120]=256,[1122]=256,[1126]=1024,[1130]=4,[1152]=2,[1160]=1,[1161]=1,[1243]=16,[1244]=16,[1245]=16,[1329]=8,[1430]=1024,[1449]=128,[1454]=256,[1455]=256,[1456]=256,[1459]=128,[1460]=128,[1461]=128,[1462]=4,[1463]=128,[1464]=1,[1490]=256,[1494]=4,[1495]=4,[1499]=4,[1510]=4,[1513]=4,[1515]=4,[1535]=64,[1543]=4,[1608]=1,[1680]=1,[1706]=16,[1714]=256,[1715]=1,[1719]=1,[1725]=8,[1735]=1024,[1752]=8,[1757]=8,[1758]=8,[1759]=8,[1760]=8,[1766]=8,[1776]=8,[1784]=8,[1804]=8,[1822]=1024,[1823]=1024,[1824]=1024,[1833]=8,[1842]=8,[1850]=1024,[1856]=8,[1857]=8,[1943]=8,[1949]=256,[1953]=128,[1966]=8,[1978]=4,[2006]=16,[2008]=64,[2010]=16,[2048]=1,[2050]=16,[2052]=16,[2053]=16,[2054]=16,[2055]=16,[2060]=16,[2061]=16,[2062]=64,[2070]=8,[2090]=1024,[2091]=1024,[2094]=8,[2096]=16,[2098]=8,[2120]=128,[2121]=128,[2136]=128,[2137]=128,[2138]=128,[2139]=128,[2362]=256,[2457]=1,[2458]=1,[2484]=64,[2565]=1,[2589]=8,[2590]=8,[2591]=8,[2637]=1024,[2641]=4,[2643]=4,[2645]=64,[2687]=1,[2767]=16,[2782]=1024,[2791]=16,[2800]=2,[2812]=2,[2825]=64,[2860]=64,[2893]=1024,[2894]=64,[2908]=1024,[2912]=1024,[2941]=256,[2944]=16,[2948]=128,[2973]=4,[2974]=4,[2983]=8,[3029]=1024,[3034]=4,[3043]=4,[3044]=4,[3045]=4,[3111]=4,[3137]=1024,[3140]=128,[3411]=1,[3472]=2,[3552]=128,[3561]=128,[3562]=128,[3563]=128,[3565]=128,[3566]=128,[3567]=128,[3599]=64,[3627]=1024,[3661]=4,[3662]=4,[3674]=4,[3698]=256,[3699]=256,[3700]=256,[3714]=32,[3738]=64,[3747]=16,[4987]=2,[5019]=400,[5116]=4,[5118]=4,[5138]=256,[5143]=128,[5144]=128,[5145]=128,[5171]=8,[5176]=1024,[5177]=1024,[5178]=1024,[5179]=1024,[5180]=1024,[5185]=1024,[5186]=1024,[5187]=1024,[5188]=1024,[5189]=1024,[5195]=1024,[5196]=1024,[5201]=1024,[5209]=1024,[5211]=1024,[5215]=1024,[5217]=1024,[5221]=1024,[5225]=1024,[5229]=1024,[5232]=1024,[5234]=1024,[5242]=1,[5246]=1,[5277]=8,[5308]=1,[5384]=4,[5394]=64,[5484]=256,[5487]=1024,[5500]=256,[5502]=2,[5504]=128,[5505]=128,[5506]=128,[5530]=1,[5570]=1024,[5588]=2,[5589]=2,[5599]=2,[5614]=2,[5615]=2,[5675]=64,[5676]=256,[5697]=256,[5699]=256,[5730]=64,[5740]=256,[5782]=256,[5857]=256,[5938]=8,[6041]=64,[6060]=16,[6063]=16,[6064]=16,[6065]=16,[6066]=16,[6074]=16,[6075]=16,[6076]=16,[6077]=16,[6078]=16,[6117]=128,[6127]=128,[6129]=128,[6131]=128,[6141]=128,[6143]=128,[6178]=1,[6190]=1,[6192]=1,[6196]=64,[6197]=4,[6201]=256,[6202]=256,[6205]=256,[6213]=256,[6215]=256,[6217]=256,[6219]=256,[6222]=256,[6223]=256,[6229]=256,[6343]=1,[6346]=16,[6353]=256,[6363]=64,[6364]=64,[6365]=64,[6366]=256,[6375]=64,[6377]=64,[6390]=64,[6391]=64,[6392]=64,[6495]=64,[6546]=1,[6547]=1,[6548]=1,[6552]=1,[6572]=1,[6574]=1,[6603]=1535,[6673]=1,[6756]=1024,[6760]=8,[6761]=8,[6762]=8,[6768]=8,[6770]=8,[6774]=8,[6778]=1024,[6780]=1024,[6785]=1024,[6787]=1024,[6789]=256,[6793]=1024,[6795]=1024,[6798]=1024,[6800]=1024,[6807]=1024,[6808]=1024,[6809]=1024,[6940]=2,[6991]=4,[7001]=16,[7128]=16,[7268]=128,[7269]=128,[7270]=128,[7294]=2,[7300]=128,[7301]=128,[7302]=128,[7320]=128,[7322]=128,[7328]=2,[7369]=1,[7379]=1,[7384]=1,[7386]=1,[7641]=256,[7646]=256,[7648]=256,[7651]=256,[8004]=64,[8005]=64,[8008]=64,[8010]=64,[8012]=64,[8017]=64,[8018]=64,[8019]=64,[8024]=64,[8027]=64,[8030]=64,[8033]=64,[8038]=64,[8042]=64,[8044]=64,[8045]=64,[8046]=64,[8050]=64,[8052]=64,[8053]=64,[8056]=64,[8058]=64,[8071]=64,[8075]=64,[8092]=16,[8102]=16,[8103]=16,[8104]=16,[8105]=16,[8106]=16,[8122]=16,[8124]=16,[8129]=16,[8134]=64,[8143]=64,[8154]=64,[8155]=64,[8160]=64,[8161]=64,[8170]=64,[8177]=64,[8181]=64,[8184]=64,[8190]=64,[8198]=1,[8204]=1,[8205]=1,[8227]=64,[8232]=64,[8235]=64,[8249]=64,[8288]=256,[8289]=256,[8349]=64,[8400]=128,[8401]=128,[8402]=128,[8406]=128,[8407]=128,[8408]=128,[8412]=128,[8413]=128,[8416]=128,[8417]=128,[8418]=128,[8419]=128,[8422]=128,[8423]=128,[8427]=128,[8437]=128,[8438]=128,[8439]=128,[8444]=128,[8445]=128,[8446]=128,[8450]=128,[8451]=128,[8455]=128,[8457]=128,[8458]=128,[8461]=128,[8462]=128,[8492]=128,[8494]=128,[8495]=128,[8498]=64,[8499]=64,[8502]=64,[8503]=64,[8512]=64,[8621]=8,[8623]=8,[8624]=8,[8631]=8,[8632]=8,[8633]=8,[8637]=8,[8639]=8,[8640]=8,[8643]=8,[8647]=8,[8676]=8,[8696]=8,[8721]=8,[8724]=8,[8725]=8,[8820]=1,[8903]=1024,[8905]=1024,[8907]=1024,[8910]=1024,[8914]=1024,[8918]=1024,[8921]=1024,[8924]=1024,[8925]=1024,[8926]=1024,[8927]=1024,[8928]=1024,[8929]=1024,[8936]=1024,[8938]=1024,[8939]=1024,[8940]=1024,[8941]=1024,[8946]=1024,[8949]=1024,[8950]=1024,[8951]=1024,[8955]=1024,[8972]=1024,[8983]=1024,[8992]=1024,[8998]=1024,[9000]=1024,[9005]=1024,[9007]=1024,[9472]=16,[9473]=16,[9474]=16,[9484]=16,[9485]=16,[9490]=1024,[9492]=1024,[9493]=1024,[9634]=1024,[9745]=1024,[9747]=1024,[9750]=1024,[9752]=1024,[9754]=1024,[9756]=1024,[9758]=1024,[9821]=1024,[9823]=1024,[9824]=1024,[9826]=1024,[9827]=1024,[9829]=1024,[9830]=1024,[9833]=1024,[9834]=1024,[9835]=1024,[9839]=1024,[9840]=1024,[9841]=1024,[9845]=1024,[9846]=1024,[9849]=1024,[9850]=1024,[9852]=1024,[9853]=1024,[9856]=1024,[9857]=1024,[9858]=1024,[9862]=1024,[9863]=1024,[9866]=1024,[9867]=1024,[9875]=1024,[9876]=1024,[9880]=1024,[9881]=1024,[9884]=1024,[9885]=1024,[9888]=1024,[9889]=1024,[9892]=1024,[9894]=1024,[9896]=1024,[9898]=1024,[9901]=1024,[9904]=1024,[9908]=1024,[9910]=1024,[9912]=1024,[10053]=128,[10054]=128,[10059]=128,[10060]=16,[10138]=128,[10139]=128,[10140]=128,[10144]=128,[10145]=128,[10148]=128,[10149]=128,[10150]=128,[10151]=128,[10156]=128,[10157]=128,[10159]=128,[10160]=128,[10161]=128,[10169]=128,[10170]=128,[10173]=128,[10174]=128,[10177]=128,[10179]=128,[10180]=128,[10181]=128,[10185]=128,[10186]=128,[10187]=128,[10191]=128,[10192]=128,[10193]=128,[10197]=128,[10199]=128,[10201]=128,[10202]=128,[10205]=128,[10206]=128,[10207]=128,[10211]=128,[10212]=128,[10215]=128,[10216]=128,[10219]=128,[10220]=128,[10223]=128,[10225]=128,[10230]=128,[10273]=128,[10274]=128,[10278]=2,[10290]=2,[10291]=2,[10292]=2,[10293]=2,[10298]=2,[10299]=2,[10300]=2,[10301]=2,[10308]=2,[10310]=2,[10312]=2,[10313]=2,[10314]=2,[10318]=2,[10322]=2,[10324]=2,[10326]=2,[10328]=2,[10329]=2,[10391]=64,[10392]=64,[10395]=64,[10396]=64,[10399]=64,[10406]=64,[10407]=64,[10408]=64,[10412]=64,[10413]=64,[10414]=64,[10427]=64,[10428]=64,[10431]=64,[10432]=64,[10437]=64,[10438]=64,[10442]=64,[10447]=64,[10448]=64,[10456]=64,[10462]=64,[10463]=64,[10466]=64,[10467]=64,[10468]=64,[10472]=64,[10473]=64,[10478]=64,[10479]=64,[10486]=64,[10495]=64,[10496]=64,[10497]=64,[10526]=64,[10537]=64,[10538]=64,[10585]=64,[10586]=64,[10587]=64,[10595]=64,[10600]=64,[10601]=64,[10605]=64,[10622]=64,[10623]=64,[10880]=16,[10881]=16,[10888]=16,[10890]=16,[10892]=16,[10893]=16,[10894]=16,[10898]=16,[10899]=16,[10900]=16,[10901]=16,[10909]=16,[10915]=16,[10916]=16,[10917]=16,[10927]=16,[10928]=16,[10929]=16,[10933]=16,[10934]=16,[10937]=16,[10938]=16,[10945]=16,[10946]=16,[10947]=16,[10951]=16,[10952]=16,[10955]=16,[10957]=16,[10958]=16,[10960]=16,[10961]=16,[10963]=16,[10964]=16,[10965]=16,[11113]=128,[11129]=128,[11267]=8,[11268]=8,[11269]=8,[11273]=8,[11274]=8,[11275]=8,[11279]=8,[11280]=8,[11281]=8,[11289]=8,[11290]=8,[11293]=8,[11294]=8,[11297]=8,[11299]=8,[11300]=8,[11303]=8,[11305]=8,[11306]=64,[11307]=64,[11314]=64,[11315]=64,[11366]=128,[11416]=128,[11417]=128,[11418]=128,[11419]=128,[11420]=128,[11426]=128,[11549]=1,[11550]=1,[11551]=1,[11554]=1,[11555]=1,[11556]=1,[11564]=1,[11565]=1,[11566]=1,[11567]=1,[11572]=1,[11573]=1,[11574]=1,[11578]=1,[11580]=1,[11581]=1,[11600]=1,[11601]=1,[11604]=1,[11605]=1,[11608]=1,[11609]=1,[11659]=256,[11660]=256,[11661]=256,[11665]=256,[11667]=256,[11668]=256,[11671]=256,[11672]=256,[11675]=256,[11677]=256,[11678]=256,[11681]=256,[11682]=256,[11683]=256,[11684]=256,[11687]=256,[11688]=256,[11689]=256,[11693]=256,[11694]=256,[11695]=256,[11699]=256,[11700]=256,[11707]=256,[11708]=256,[11711]=256,[11712]=256,[11713]=256,[11719]=256,[11721]=256,[11722]=256,[11725]=256,[11726]=256,[11729]=256,[11730]=256,[11733]=256,[11734]=256,[11735]=256,[11739]=256,[11740]=256,[11958]=128,[12042]=128,[12043]=128,[12051]=128,[12292]=1,[12294]=1,[12323]=1,[12328]=1,[12355]=128,[12472]=128,[12484]=128,[12485]=128,[12486]=128,[12494]=128,[12505]=128,[12522]=128,[12523]=128,[12524]=128,[12525]=128,[12526]=128,[12536]=128,[12654]=128,[12695]=1,[12696]=1,[12705]=1,[12723]=1,[12798]=1,[12809]=1,[12824]=128,[12825]=128,[12826]=128,[12964]=1,[12966]=1,[12967]=1,[12968]=1,[12969]=1,[12970]=1,[12975]=1,[12976]=1,[13018]=128,[13019]=128,[13020]=128,[13021]=128,[13031]=128,[13032]=128,[13033]=128,[13159]=4,[13161]=4,[13163]=4,[13165]=4,[13481]=4,[13542]=4,[13543]=4,[13544]=4,[13549]=4,[13550]=4,[13551]=4,[13552]=4,[13553]=4,[13554]=4,[13555]=4,[13750]=8,[13795]=4,[13797]=4,[13809]=4,[13812]=4,[13813]=4,[13877]=8,[13977]=8,[14093]=8,[14177]=8,[14181]=8,[14183]=8,[14185]=8,[14251]=8,[14260]=4,[14261]=4,[14262]=4,[14263]=4,[14264]=4,[14265]=4,[14266]=4,[14269]=4,[14270]=4,[14271]=4,[14278]=8,[14281]=4,[14282]=4,[14283]=4,[14284]=4,[14285]=4,[14286]=4,[14287]=4,[14288]=4,[14289]=4,[14290]=4,[14294]=4,[14295]=4,[14298]=4,[14299]=4,[14300]=4,[14301]=4,[14302]=4,[14303]=4,[14304]=4,[14305]=4,[14310]=4,[14311]=4,[14314]=4,[14315]=4,[14316]=4,[14317]=4,[14318]=4,[14319]=4,[14320]=4,[14321]=4,[14322]=4,[14323]=4,[14324]=4,[14325]=4,[14326]=4,[14327]=4,[14743]=16,[14751]=16,[14752]=16,[14818]=16,[14819]=16,[14914]=16,[15207]=64,[15208]=64,[15237]=16,[15261]=16,[15262]=16,[15263]=16,[15264]=16,[15265]=16,[15266]=16,[15267]=16,[15286]=16,[15407]=16,[15430]=16,[15431]=16,[15473]=16,[15487]=16,[16166]=64,[16177]=64,[16188]=64,[16190]=64,[16236]=64,[16237]=64,[16268]=64,[16339]=64,[16341]=64,[16342]=64,[16355]=64,[16356]=64,[16362]=64,[16387]=64,[16511]=8,[16689]=1024,[16810]=1024,[16811]=1024,[16812]=1024,[16813]=1024,[16857]=1024,[16914]=1024,[16979]=1024,[17116]=1024,[17311]=16,[17312]=16,[17313]=16,[17314]=16,[17329]=1024,[17347]=8,[17348]=8,[17364]=64,[17401]=1024,[17402]=1024,[17727]=256,[17728]=256,[17877]=256,[17919]=256,[17920]=256,[17921]=256,[17922]=256,[17923]=256,[17924]=256,[17925]=256,[17926]=256,[17928]=256,[17951]=256,[17952]=256,[17953]=256,[17962]=256,[18093]=256,[18220]=256,[18223]=256,[18498]=1,[18499]=1,[18540]=256,[18541]=256,[18562]=1024,[18647]=256,[18657]=1024,[18658]=1024,[18662]=256,[18708]=256,[18807]=16,[18809]=128,[18867]=256,[18868]=256,[18869]=256,[18870]=256,[18871]=256,[18937]=256,[18938]=256,[18960]=1024,[19028]=256,[19185]=4,[19236]=16,[19238]=16,[19240]=16,[19241]=16,[19242]=16,[19243]=16,[19263]=4,[19276]=16,[19277]=16,[19278]=16,[19279]=16,[19280]=16,[19306]=4,[19386]=4,[19434]=4,[19503]=4,[19506]=4,[19574]=4,[19577]=4,[19579]=4,[19740]=2,[19742]=2,[19746]=2,[19750]=2,[19752]=2,[19801]=4,[19834]=2,[19835]=2,[19836]=2,[19837]=2,[19838]=2,[19850]=2,[19852]=2,[19853]=2,[19854]=2,[19876]=2,[19878]=4,[19879]=4,[19880]=4,[19882]=4,[19883]=4,[19884]=4,[19885]=4,[19888]=2,[19891]=2,[19895]=2,[19896]=2,[19897]=2,[19898]=2,[19899]=2,[19900]=2,[19939]=2,[19940]=2,[19941]=2,[19942]=2,[19943]=2,[20043]=4,[20050]=2,[20052]=2,[20053]=2,[20066]=2,[20116]=2,[20153]=256,[20154]=2,[20164]=2,[20165]=2,[20166]=2,[20184]=2,[20185]=2,[20186]=2,[20187]=2,[20190]=4,[20216]=18,[20217]=2,[20230]=1,[20243]=1,[20252]=1,[20271]=2,[20375]=2,[20425]=2,[20467]=2,[20473]=2,[20484]=1024,[20569]=1,[20609]=64,[20610]=64,[20647]=1,[20658]=1,[20660]=1,[20661]=1,[20662]=1,[20736]=4,[20739]=1024,[20742]=1024,[20747]=1024,[20748]=1024,[20752]=256,[20755]=256,[20756]=256,[20757]=256,[20770]=16,[20772]=2,[20773]=2,[20776]=64,[20777]=64,[20900]=4,[20901]=4,[20902]=4,[20903]=4,[20904]=4,[20909]=4,[20910]=4,[20911]=2,[20922]=2,[20923]=2,[20924]=2,[20925]=2,[20927]=2,[20928]=2,[20929]=2,[20930]=2,[21084]=2,[21169]=64,[21551]=1,[21552]=1,[21553]=1,[21562]=16,[21564]=16,[21849]=1024,[21850]=1024,[22568]=1024,[22570]=1024,[22782]=128,[22783]=128,[22812]=1024,[22827]=1024,[22828]=1024,[22829]=1024,[22842]=1024,[22845]=1024,[22959]=128,[23028]=128,[23455]=16,[23458]=16,[23459]=16,[23759]=256,[23760]=256,[23761]=256,[23762]=256,[23826]=256,[23827]=256,[23828]=256,[23829]=256,[23833]=256,[23834]=256,[23835]=256,[23836]=256,[23837]=256,[23838]=256,[23839]=256,[23840]=256,[23841]=256,[23842]=256,[23843]=256,[23844]=256,[23880]=1,[23881]=1,[23885]=1,[23920]=1,[23922]=1,[23923]=1,[23924]=1,[23925]=1,[23989]=4,[24131]=4,[24132]=4,[24133]=4,[24134]=4,[24135]=4,[24239]=2,[24248]=1024,[24274]=2,[24275]=2,[24398]=64,[24406]=4,[24529]=4,[24530]=128,[24858]=1024,[24907]=1024,[24974]=1024,[24975]=1024,[24976]=1024,[24977]=1024,[25202]=1,[25203]=1,[25208]=1,[25210]=16,[25213]=16,[25217]=16,[25218]=16,[25221]=16,[25222]=16,[25231]=1,[25233]=16,[25234]=1,[25235]=16,[25236]=1,[25241]=1,[25242]=1,[25248]=1,[25258]=1,[25264]=1,[25269]=1,[25286]=1,[25288]=1,[25289]=1,[25290]=2,[25291]=2,[25292]=2,[25294]=4,[25295]=4,[25296]=4,[25297]=1024,[25298]=1024,[25299]=1024,[25300]=8,[25302]=8,[25304]=128,[25306]=128,[25307]=256,[25308]=16,[25309]=256,[25311]=256,[25312]=16,[25314]=16,[25315]=16,[25316]=16,[25329]=16,[25331]=16,[25345]=128,[25346]=128,[25357]=64,[25361]=64,[25363]=16,[25364]=16,[25367]=16,[25368]=16,[25372]=16,[25375]=16,[25384]=16,[25387]=16,[25389]=16,[25391]=64,[25392]=16,[25396]=64,[25420]=64,[25422]=64,[25423]=64,[25431]=16,[25433]=16,[25435]=16,[25437]=16,[25439]=64,[25442]=64,[25448]=64,[25449]=64,[25454]=64,[25457]=64,[25464]=64,[25467]=16,[25469]=64,[25472]=64,[25489]=64,[25500]=64,[25505]=64,[25508]=64,[25509]=64,[25525]=64,[25528]=64,[25533]=64,[25535]=64,[25537]=64,[25546]=64,[25547]=64,[25552]=64,[25557]=64,[25560]=64,[25563]=64,[25567]=64,[25570]=64,[25574]=64,[25590]=64,[25780]=2,[25781]=2,[25782]=2,[25894]=2,[25898]=2,[25899]=2,[25902]=2,[25903]=2,[25911]=2,[25912]=2,[25913]=2,[25914]=2,[25916]=2,[25918]=2,[25997]=2,[26017]=2,[26363]=64,[26364]=64,[26365]=64,[26366]=64,[26367]=64,[26369]=64,[26370]=64,[26371]=64,[26372]=64,[26573]=2,[26654]=1,[26669]=8,[26679]=8,[26839]=8,[26861]=8,[26862]=8,[26863]=8,[26864]=8,[26865]=8,[26867]=8,[26884]=8,[26889]=8,[26978]=1024,[26979]=1024,[26980]=1024,[26981]=1024,[26982]=1024,[26983]=1024,[26984]=1024,[26985]=1024,[26986]=1024,[26987]=1024,[26988]=1024,[26989]=1024,[26990]=1024,[26991]=1024,[26992]=1024,[26994]=1024,[26995]=1024,[26996]=1024,[26997]=1024,[26998]=1024,[27000]=1024,[27001]=1024,[27002]=1024,[27003]=1024,[27004]=1024,[27005]=1024,[27006]=1024,[27007]=1024,[27008]=1024,[27009]=1024,[27012]=1024,[27013]=1024,[27014]=4,[27016]=4,[27019]=4,[27021]=4,[27022]=4,[27023]=4,[27024]=4,[27025]=4,[27026]=4,[27044]=4,[27045]=4,[27046]=4,[27065]=4,[27067]=4,[27068]=4,[27069]=4,[27070]=128,[27071]=128,[27072]=128,[27073]=128,[27074]=128,[27075]=128,[27076]=128,[27078]=128,[27079]=128,[27080]=128,[27082]=128,[27085]=128,[27086]=128,[27087]=128,[27088]=128,[27090]=128,[27101]=128,[27124]=128,[27125]=128,[27126]=128,[27127]=128,[27128]=128,[27130]=128,[27131]=128,[27132]=128,[27133]=128,[27134]=128,[27135]=2,[27136]=2,[27137]=2,[27138]=2,[27139]=2,[27140]=2,[27141]=2,[27142]=2,[27143]=2,[27149]=2,[27150]=2,[27151]=2,[27152]=2,[27153]=2,[27154]=2,[27173]=2,[27174]=2,[27175]=2,[27176]=2,[27179]=2,[27180]=2,[27209]=256,[27210]=256,[27211]=256,[27212]=256,[27213]=256,[27214]=256,[27215]=256,[27216]=256,[27217]=256,[27218]=256,[27219]=256,[27220]=256,[27222]=256,[27223]=256,[27224]=256,[27228]=256,[27230]=256,[27238]=256,[27243]=256,[27250]=256,[27259]=256,[27260]=256,[27263]=256,[27265]=256,[27285]=256,[27441]=8,[27448]=8,[27681]=16,[27683]=16,[27799]=16,[27800]=16,[27801]=16,[27803]=16,[27804]=16,[27805]=16,[27813]=16,[27817]=16,[27818]=16,[27828]=16,[27841]=16,[27870]=16,[27871]=16,[27873]=16,[27874]=16,[28172]=256,[28176]=256,[28189]=256,[28271]=128,[28272]=128,[28275]=16,[28276]=16,[28609]=128,[28610]=256,[28612]=128,[29077]=128,[29166]=1024,[29177]=64,[29178]=64,[29228]=64,[29442]=128,[29707]=1,[29722]=256,[29841]=1,[29842]=1,[29858]=256,[29886]=256,[29893]=256,[30016]=1,[30022]=1,[30108]=256,[30146]=256,[30165]=64,[30283]=256,[30324]=1,[30330]=1,[30356]=1,[30357]=1,[30404]=256,[30405]=256,[30413]=256,[30414]=256,[30449]=128,[30451]=128,[30455]=128,[30459]=256,[30482]=128,[30545]=256,[30546]=256,[30706]=64,[30798]=64,[30823]=64,[30824]=64,[30874]=64,[30909]=256,[30910]=256,[31016]=8,[31018]=1024,[31117]=256,[31125]=8,[31224]=8,[31589]=128,[31643]=128,[31661]=128,[31687]=128,[31709]=1024,[31789]=2,[31801]=2,[31803]=2,[31804]=2,[31821]=2,[31834]=2,[31842]=2,[31884]=2,[31898]=2,[31935]=2,[32175]=64,[32176]=64,[32182]=64,[32223]=2,[32231]=256,[32266]=128,[32267]=128,[32271]=128,[32272]=128,[32375]=16,[32379]=16,[32386]=256,[32388]=256,[32389]=256,[32390]=256,[32391]=256,[32546]=16,[32593]=64,[32594]=64,[32645]=8,[32684]=8,[32699]=2,[32700]=2,[32796]=128,[32841]=16,[32996]=16,[32999]=16,[33041]=128,[33042]=128,[33043]=128,[33072]=2,[33073]=2,[33074]=2,[33076]=16,[33110]=16,[33143]=16,[33151]=16,[33196]=16,[33197]=16,[33198]=16,[33206]=16,[33357]=1024,[33405]=128,[33619]=16,[33690]=128,[33691]=128,[33717]=128,[33736]=64,[33745]=1024,[33763]=1024,[33786]=1024,[33831]=1024,[33876]=1024,[33878]=1024,[33891]=1024,[33917]=1024,[33933]=128,[33938]=128,[33943]=1024,[33944]=128,[33946]=128,[33982]=1024,[33983]=1024,[33986]=1024,[33987]=1024,[34026]=4,[34074]=4,[34120]=4,[34299]=1024,[34411]=8,[34412]=8,[34413]=8,[34428]=1,[34433]=16,[34471]=4,[34477]=4,[34490]=4,[34501]=4,[34600]=4,[34754]=16,[34833]=4,[34834]=4,[34835]=4,[34836]=4,[34837]=4,[34861]=16,[34863]=16,[34864]=16,[34865]=16,[34866]=16,[34913]=128,[34914]=16,[34916]=16,[34917]=16,[34919]=16,[34936]=256,[35098]=4,[35099]=4,[35101]=4,[35395]=2,[35702]=256,[35703]=256,[35704]=256,[35705]=256,[35706]=256,[35715]=128,[35717]=128,[36554]=8,[36916]=4,[36936]=64,[37116]=1024,[37117]=1024,[37420]=128,[38692]=128,[38697]=128,[38699]=128,[38700]=128,[38703]=128,[38704]=128,[39374]=16,[40120]=1024,[42198]=128,[42208]=128,[42209]=128,[42210]=128,[42211]=128,[42212]=128,[42213]=128,[42218]=256,[42223]=256,[42224]=256,[42225]=256,[42226]=256,[42230]=1024,[42231]=1024,[42232]=1024,[42233]=1024,[42234]=4,[42243]=4,[42244]=4,[42245]=4,[42650]=32,[42651]=32,[42832]=128,[42833]=128,[42841]=128,[42842]=128,[42843]=128,[42844]=128,[42845]=128,[42846]=128,[42858]=128,[42859]=128,[42872]=128,[42873]=128,[42890]=128,[42891]=128,[42894]=128,[42896]=128,[42897]=128,[42913]=128,[42914]=128,[42917]=128,[42920]=128,[42921]=128,[42925]=128,[42926]=128,[42930]=128,[42931]=128,[42937]=128,[42938]=128,[42939]=128,[42940]=128,[42944]=128,[42945]=128,[42949]=128,[42950]=128,[42955]=128,[42956]=128,[42985]=128,[42995]=128,[43002]=128,[43008]=128,[43010]=128,[43012]=128,[43015]=128,[43017]=128,[43019]=128,[43020]=128,[43023]=128,[43024]=128,[43038]=128,[43039]=128,[43043]=128,[43044]=128,[43045]=128,[43046]=128,[43265]=32,[43339]=64,[43987]=128,[44203]=1024,[44205]=1024,[44206]=1024,[44207]=1024,[44208]=1024,[44401]=128,[44413]=128,[44416]=16,[44425]=128,[44450]=128,[44457]=128,[44461]=128,[44544]=128,[44572]=128,[44614]=128,[44780]=128,[44781]=128,[45237]=16,[45241]=16,[45242]=16,[45284]=64,[45286]=64,[45287]=64,[45288]=64,[45289]=64,[45290]=64,[45291]=64,[45292]=64,[45293]=64,[45294]=64,[45295]=64,[45296]=64,[45297]=64,[45298]=64,[45299]=64,[45300]=64,[45301]=64,[45302]=64,[45438]=128,[45462]=32,[45463]=32,[45469]=32,[45470]=32,[45477]=32,[45524]=32,[45529]=32,[45902]=32,[46584]=32,[46845]=1,[46856]=1,[46857]=1,[46916]=1,[46924]=1,[46946]=1,[46947]=1,[46968]=1,[47193]=256,[47206]=256,[47241]=256,[47436]=1,[47437]=1,[47439]=1,[47440]=1,[47449]=1,[47450]=1,[47465]=1,[47470]=1,[47471]=1,[47474]=1,[47475]=1,[47476]=32,[47485]=1,[47486]=1,[47487]=1,[47488]=1,[47497]=1,[47498]=1,[47501]=1,[47502]=1,[47519]=1,[47520]=1,[47528]=32,[47540]=16,[47541]=32,[47568]=32,[47585]=16,[47610]=128,[47632]=32,[47633]=32,[47666]=16,[47750]=16,[47757]=16,[47758]=16,[47788]=16,[47793]=256,[47808]=256,[47809]=256,[47810]=256,[47811]=256,[47812]=256,[47813]=256,[47814]=256,[47815]=256,[47817]=256,[47818]=256,[47819]=256,[47820]=256,[47822]=256,[47823]=256,[47824]=256,[47825]=256,[47826]=256,[47827]=256,[47833]=256,[47834]=256,[47835]=256,[47836]=256,[47837]=256,[47838]=256,[47841]=256,[47843]=256,[47846]=256,[47847]=256,[47855]=256,[47856]=256,[47857]=256,[47859]=256,[47860]=256,[47863]=256,[47864]=256,[47865]=256,[47867]=256,[47871]=256,[47878]=256,[47884]=256,[47886]=256,[47888]=256,[47889]=256,[47890]=256,[47891]=256,[47892]=256,[47893]=256,[47897]=256,[48018]=256,[48020]=256,[48040]=16,[48045]=16,[48062]=16,[48063]=16,[48065]=16,[48066]=16,[48067]=16,[48068]=16,[48070]=16,[48071]=16,[48072]=16,[48073]=16,[48074]=16,[48075]=16,[48076]=16,[48077]=16,[48078]=16,[48084]=16,[48085]=16,[48086]=16,[48087]=16,[48088]=16,[48089]=16,[48112]=16,[48113]=16,[48119]=16,[48120]=16,[48122]=16,[48123]=16,[48124]=16,[48125]=16,[48126]=16,[48127]=16,[48134]=16,[48135]=16,[48153]=16,[48155]=16,[48156]=16,[48157]=16,[48158]=16,[48159]=16,[48160]=16,[48161]=16,[48162]=16,[48168]=16,[48169]=16,[48170]=16,[48171]=16,[48172]=16,[48173]=16,[48181]=256,[48263]=32,[48265]=32,[48266]=32,[48299]=16,[48300]=16,[48377]=1024,[48378]=1024,[48438]=1024,[48440]=1024,[48441]=1024,[48442]=1024,[48443]=1024,[48444]=1024,[48445]=1024,[48446]=1024,[48447]=1024,[48450]=1024,[48451]=1024,[48459]=1024,[48461]=1024,[48462]=1024,[48463]=1024,[48464]=1024,[48465]=1024,[48466]=1024,[48467]=1024,[48468]=1024,[48469]=1024,[48470]=1024,[48477]=1024,[48479]=1024,[48480]=1024,[48505]=1024,[48559]=1024,[48560]=1024,[48561]=1024,[48562]=1024,[48563]=1024,[48564]=1024,[48565]=1024,[48566]=1024,[48567]=1024,[48568]=1024,[48569]=1024,[48570]=1024,[48571]=1024,[48572]=1024,[48573]=1024,[48574]=1024,[48575]=1024,[48576]=1024,[48577]=1024,[48578]=1024,[48579]=1024,[48637]=8,[48638]=8,[48656]=8,[48657]=8,[48658]=8,[48659]=8,[48660]=8,[48663]=8,[48666]=8,[48667]=8,[48668]=8,[48671]=8,[48672]=8,[48673]=8,[48674]=8,[48675]=8,[48676]=8,[48689]=8,[48690]=8,[48691]=8,[48707]=32,[48721]=32,[48743]=32,[48781]=2,[48782]=2,[48784]=2,[48785]=2,[48788]=2,[48792]=32,[48800]=2,[48801]=2,[48805]=2,[48806]=2,[48816]=2,[48817]=2,[48818]=2,[48819]=2,[48820]=2,[48821]=2,[48822]=2,[48823]=2,[48824]=2,[48825]=2,[48826]=2,[48827]=2,[48931]=2,[48932]=2,[48933]=2,[48934]=2,[48935]=2,[48936]=2,[48937]=2,[48938]=2,[48941]=2,[48942]=2,[48943]=2,[48945]=2,[48947]=2,[48949]=2,[48950]=2,[48951]=2,[48952]=2,[48982]=32,[48989]=4,[48990]=4,[48995]=4,[48996]=4,[48998]=4,[48999]=4,[49000]=4,[49001]=4,[49005]=32,[49009]=4,[49010]=4,[49011]=4,[49012]=4,[49016]=32,[49020]=32,[49028]=32,[49039]=32,[49044]=4,[49045]=4,[49047]=4,[49048]=4,[49049]=4,[49050]=4,[49051]=4,[49052]=4,[49053]=4,[49054]=4,[49055]=4,[49056]=4,[49064]=4,[49065]=4,[49066]=4,[49067]=4,[49071]=4,[49142]=32,[49143]=32,[49146]=32,[49158]=32,[49184]=32,[49189]=32,[49203]=32,[49206]=32,[49222]=32,[49230]=64,[49231]=64,[49232]=64,[49233]=64,[49235]=64,[49236]=64,[49237]=64,[49238]=64,[49239]=64,[49240]=64,[49268]=64,[49269]=64,[49270]=64,[49271]=64,[49272]=64,[49273]=64,[49275]=64,[49276]=64,[49277]=64,[49278]=64,[49279]=64,[49280]=64,[49281]=64,[49283]=64,[49284]=64,[49358]=128,[49359]=128,[49360]=128,[49361]=128,[49376]=1024,[49377]=1024,[49560]=32,[49575]=32,[49576]=32,[49796]=32,[49799]=1024,[49800]=1024,[49802]=1024,[49803]=1024,[49804]=1024,[49821]=16,[49892]=32,[49893]=32,[49894]=32,[49895]=32,[49896]=32,[49903]=32,[49904]=32,[49909]=32,[49917]=32,[49918]=32,[49919]=32,[49920]=32,[49921]=32,[49923]=32,[49924]=32,[49926]=32,[49927]=32,[49928]=32,[49929]=32,[49930]=32,[49936]=32,[49937]=32,[49938]=32,[49939]=32,[49940]=32,[49941]=32,[49998]=32,[49999]=32,[50149]=32,[50150]=32,[50212]=1024,[50213]=1024,[50322]=1024,[50334]=1024,[50444]=32,[50447]=32,[50448]=32,[50449]=32,[50464]=1024,[50511]=256,[50516]=1024,[50536]=32,[50581]=256,[50589]=256,[50720]=1,[50763]=1024,[50764]=1024,[50765]=1024,[50766]=1024,[50767]=1024,[50768]=1024,[50769]=1024,[50796]=256,[50842]=32,[50977]=32,[51052]=32,[51267]=32,[51271]=32,[51325]=32,[51326]=32,[51327]=32,[51328]=32,[51409]=32,[51410]=32,[51411]=32,[51416]=32,[51417]=32,[51418]=32,[51419]=32,[51423]=32,[51424]=32,[51425]=32,[51490]=64,[51505]=64,[51514]=64,[51533]=64,[51637]=8,[51662]=8,[51675]=8,[51677]=8,[51680]=8,[51690]=8,[51693]=8,[51699]=8,[51713]=8,[51722]=8,[51723]=8,[51724]=8,[51730]=64,[51886]=64,[51988]=64,[51991]=64,[51992]=64,[51993]=64,[51994]=64,[52127]=64,[52129]=64,[52131]=64,[52134]=64,[52136]=64,[52138]=64,[52372]=32,[52373]=32,[52374]=32,[52375]=32,[52610]=1024,[52983]=16,[52984]=16,[52985]=16,[52986]=16,[52987]=16,[52988]=16,[52998]=16,[52999]=16,[53000]=16,[53001]=16,[53002]=16,[53003]=16,[53005]=16,[53006]=16,[53007]=16,[53022]=16,[53023]=16,[53140]=128,[53142]=128,[53199]=1024,[53200]=1024,[53201]=1024,[53209]=4,[53220]=4,[53223]=1024,[53225]=1024,[53226]=1024,[53227]=1024,[53230]=4,[53248]=1024,[53249]=1024,[53251]=1024,[53254]=4,[53271]=4,[53301]=4,[53307]=1024,[53308]=1024,[53312]=1024,[53323]=32,[53331]=32,[53338]=4,[53339]=4,[53341]=32,[53343]=32,[53351]=4,[53352]=4,[53385]=2,[53407]=2,[53408]=2,[53489]=2,[53563]=2,[53595]=2,[53600]=2,[53601]=2,[53651]=2,[53652]=2,[53653]=2,[53654]=2,[53655]=2,[53656]=2,[53657]=2,[53659]=2,[53672]=2,[53726]=2,[53733]=2,[53736]=2,[53742]=2,[53756]=256,[54043]=2,[54149]=2,[54152]=2,[54153]=2,[54428]=2,[54646]=128,[54648]=128,[54741]=128,[54748]=128,[54755]=1024,[54785]=256,[54817]=256,[54879]=256,[54968]=18,[55050]=32,[55090]=32,[55166]=64,[55198]=64,[55233]=32,[55258]=32,[55259]=32,[55260]=32,[55261]=32,[55262]=32,[55265]=32,[55268]=32,[55270]=32,[55271]=32,[55342]=128,[55359]=128,[55360]=128,[55361]=128,[55362]=128,[55458]=64,[55459]=64,[55533]=64,[55694]=1,[56112]=1,[56131]=16,[56160]=16,[56161]=16,[56222]=32,[56453]=4,[56641]=4,[56815]=32,[57330]=32,[57532]=32,[57622]=64,[57623]=32,[57720]=64,[57721]=64,[57722]=64,[57755]=1,[57823]=1,[57933]=8,[57934]=8,[57946]=256,[57960]=64,[57992]=8,[57993]=8,[57994]=64,[58381]=16,[58427]=8,[58431]=4,[58432]=4,[58433]=4,[58434]=4,[58580]=64,[58581]=64,[58582]=64,[58643]=64,[58649]=64,[58652]=64,[58656]=64,[58659]=128,[58699]=64,[58703]=64,[58704]=64,[58731]=64,[58734]=64,[58737]=64,[58739]=64,[58741]=64,[58745]=64,[58746]=64,[58749]=64,[58751]=64,[58753]=64,[58755]=64,[58756]=64,[58757]=64,[58771]=64,[58773]=64,[58774]=64,[58785]=64,[58789]=64,[58790]=64,[58794]=64,[58795]=64,[58796]=64,[58801]=64,[58803]=64,[58804]=64,[58887]=256,[58889]=256,[59092]=256,[59156]=64,[59158]=64,[59159]=64,[59161]=256,[59163]=256,[59164]=256,[59170]=256,[59171]=256,[59172]=256,[59578]=2,[59671]=256,[59672]=256,[59673]=256,[60043]=64,[60051]=4,[60052]=4,[60053]=4,[60103]=64,[60192]=4,[60202]=4,[60210]=4,[60219]=256,[60220]=256,[60970]=1,[61005]=4,[61006]=4,[61024]=128,[61025]=128,[61154]=32,[61155]=32,[61156]=32,[61157]=32,[61158]=32,[61191]=256,[61290]=256,[61295]=64,[61299]=64,[61300]=64,[61301]=64,[61305]=128,[61316]=128,[61336]=1024,[61384]=1024,[61387]=1024,[61388]=1024,[61390]=1024,[61391]=1024,[61411]=2,[61610]=256,[61649]=64,[61650]=64,[61654]=64,[61657]=64,[61721]=128,[61780]=128,[61846]=4,[61847]=4,[61999]=32,[62078]=1024,[62124]=2,[62757]=4,[62900]=32,[62901]=32,[62902]=32,[62903]=32,[62904]=32,[63560]=32,[63668]=4,[63669]=4,[63670]=4,[63671]=4,[63672]=4,[63685]=64,[63731]=16,[63734]=16,[63735]=16,[64044]=16,[64058]=16,[64205]=2,[64353]=128,[64357]=128,[64380]=1,[64382]=1,[64801]=1024,[64843]=16,[64844]=16,[64891]=18,[64901]=16,[64904]=16,[65139]=1024,[66188]=32,[66196]=32,[66198]=32,[66215]=32,[66216]=32,[66217]=32,[66842]=64,[66843]=64,[66844]=64,[66922]=18,[70772]=16,[70809]=64,[70909]=128},races={[2481]=4,[7744]=16,[20549]=32,[20572]=2,[20577]=16,[20589]=64,[20594]=4,[25046]=512,[26297]=128,[28730]=512,[28880]=1024,[33697]=2,[33702]=2,[50613]=512,[58984]=8,[59542]=1024,[59543]=1024,[59544]=1024,[59545]=1024,[59547]=1024,[59548]=1024,[59752]=1}}
-- END ALT SPELL CATALOG
A.spells.catalog=catalog
local classBits={WARRIOR=1,PALADIN=2,HUNTER=4,ROGUE=8,PRIEST=16,DEATHKNIGHT=32,SHAMAN=64,MAGE=128,WARLOCK=256,DRUID=1024}
local raceBits={Human=1,Orc=2,Dwarf=4,NightElf=8,Scourge=16,Tauren=32,Gnome=64,Troll=128,BloodElf=512,Draenei=1024}
local function Has(mask,flag) return mask and flag and math.floor(mask/flag)%2==1 end
function A.spells.Visible(id)
    local unit=A.selected and UnBotAccountAlts.FindUnit(A.selected)
    local class=unit and select(2,UnitClass(unit)) or A.draft and A.draft.class
    if Has(catalog.classes[id],classBits[class]) then return true end
    local races=catalog.races[id]
    if not races then return false end
    local race=unit and UnitRace and select(2,UnitRace(unit))
    return not race or Has(races,raceBits[race]) or false
end
end
