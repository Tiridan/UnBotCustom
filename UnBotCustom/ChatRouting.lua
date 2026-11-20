-- Display routing; the explicit account controller is embedded below for /reload.
UnBotChatRouting = {windows = {}, last = {}};
local R = UnBotChatRouting;
R.groups = {{key="own",label="Свои альты",title="Альты"},
    {key="paired",label="Альты связанных аккаунтов",title="Второй аккаунт"},
    {key="bots",label="Обычные боты",title="Боты"}};
R.kinds = {{key="reply",label="Обычные ответы и сведения"},
    {key="strategy",label="Стратегии co / nc / de, метки RTI"},
    {key="spell",label="Заклинания и ошибки выполнения"},
    {key="inventory",label="Вещи, покупки, продажи и добыча"},
    {key="debug",label="Диагностика и ответы debug"},
    {key="outgoing",label="Исходящая личка / команды"},
    {key="system",label="Вход / выход, смерть, ответы сервера"},
    {key="group",label="Сообщения бота в группе / рейде"}};

function R.Storage()
    UnBotSquadConfig = UnBotSquadConfig or {};
    local c = UnBotSquadConfig.chatRouting;
    if type(c) ~= "table" then c = {}; UnBotSquadConfig.chatRouting = c; end
    c.schemaVersion = math.max(3, tonumber(c.schemaVersion) or 0);
    if type(c.groups) ~= "table" then c.groups = {}; end
    return c;
end

function R.IsPaired(name)
    local key=UnBotChatNormalizeName(name);
    if key=="" or not UnBotLinkedAccounts then return false;end
    local saved=UnBotLinkedAccounts.Storage();
    for _,accountKey in ipairs(saved.current) do
        local account=saved.accounts[accountKey];
        local alt=type(account)=="table" and type(account.characters)=="table" and account.characters[key];
        if type(alt)=="table" and alt.name and UnBotChatNormalizeName(alt.name)==key then return true;end
    end
    return false;
end

function R.Group(name, message)
    if R.IsPaired(name) then return "paired"; end
    if UnBotChatIsKnownBot(name, true) then return "own"; end
    if UnBotChatIsKnownBot(name) or (message and UnBotChatLooksLikeBotWhisper(message)) then return "bots"; end
end

function R.Tabs()
    local tabs = {};
    for i=1,(NUM_CHAT_WINDOWS or 0) do
        local f,tab=_G["ChatFrame"..i],_G["ChatFrame"..i.."Tab"];
        local title=tab and tab.GetText and tab:GetText();
        if f and title and title~="" and (not tab.IsShown or tab:IsShown()) then
            tabs[#tabs+1]={key="tab:"..i..":"..title,label=title,frame=f,id=i};
        end
    end
    return tabs;
end

function R.TabRoute(title)
    for _,tab in ipairs(R.Tabs()) do if tab.label==title then return tab.key; end end
    return "tab:0:"..title;
end

function R.GeneralRoute()
    local tabs=R.Tabs();
    for _,tab in ipairs(tabs) do if tab.frame==DEFAULT_CHAT_FRAME then return tab.key; end end
    return tabs[1] and tabs[1].key or "tab:0:"..(GENERAL or "Общий");
end

function R.ParseRoute(route)
    if type(route)~="string" then return nil; end
    local id,title=route:match("^tab:(%d+):(.+)$");
    if id then return tonumber(id),title; end
end

function R.RouteFrame(route)
    local id,title=R.ParseRoute(route);
    if not id then return nil; end
    for _,tab in ipairs(R.Tabs()) do
        if tab.id==id and tab.label==title then return tab.frame; end
    end
    -- Frame slots can change after closing windows/reload. Match the saved name.
    for _,tab in ipairs(R.Tabs()) do if tab.label==title then return tab.frame; end end
end

function R.RouteLabel(route)
    if route=="hide" then return "Скрывать"; end
    local _,title=R.ParseRoute(route);
    return title and (R.RouteFrame(route) and title or title.." (вкладка закрыта)") or "Выберите вкладку";
end

function R.ServiceDestination()
    local saved=R.Storage().serviceRoute;
    return (saved=="hide" or R.ParseRoute(saved)) and saved or R.TabRoute("UnBot");
end

function R.WriteService(text)
    -- Keep the established startup queue and combat notices until a route is chosen.
    if R.Storage().serviceRoute==nil then return false;end
    local destination=R.ServiceDestination();
    if destination=="hide" then return true;end
    local frame=R.RouteFrame(destination);
    if not frame then
        frame=DEFAULT_CHAT_FRAME;
        if not frame then return false;end
        if R.serviceWarned~=destination then
            R.serviceWarned=destination;
            local _,title=R.ParseRoute(destination);
            frame:AddMessage("|cffffaa00UnBot: вкладка «"..tostring(title or "").."» закрыта. Служебные сообщения показаны в «"..R.RouteLabel(R.GeneralRoute()).."». Выберите вкладку в настройках чата.|r");
        end
    else R.serviceWarned=nil;end
    frame:AddMessage(tostring(text or ""));return true;
end

function R.Default(group, kind)
    if group~="bots" and kind~="system" and kind~="group" then return R.GeneralRoute(); end
    if kind=="debug" and R.Find("UnBot Debug") then return R.TabRoute("UnBot Debug"); end
    return R.TabRoute("UnBot");
end

function R.ConvertRoute(saved, group, kind)
    if saved=="hide" or R.ParseRoute(saved) then return saved; end
    if saved=="native" or saved=="general" then return R.GeneralRoute(); end
    if saved=="unbot" then return R.TabRoute("UnBot"); end
    if saved=="custom" then return R.TabRoute(R.Title(group)); end
    if saved=="legacy" then
        if group=="own" and kind~="system" and kind~="group" then return R.GeneralRoute(); end
        if kind=="debug" and R.Find("UnBot Debug") then return R.TabRoute("UnBot Debug"); end
        return R.TabRoute("UnBot");
    end
end

function R.Destination(group, kind)
    local c = R.Storage().groups[group];
    local saved = type(c) == "table" and type(c.routes) == "table" and c.routes[kind];
    local route=R.ConvertRoute(saved,group,kind);
    if route then
        local frame=R.RouteFrame(route);
        if frame then
            for _,tab in ipairs(R.Tabs()) do if tab.frame==frame then route=tab.key;break end end
        end
        if route~=saved then c.routes[kind]=route; end -- Lazy, display-only migration.
        return route;
    end
    return R.Default(group, kind);
end

function R.Title(group)
    local c = R.Storage().groups[group];
    if type(c) == "table" and type(c.title) == "string" and c.title ~= "" then return c.title; end
    for _, g in ipairs(R.groups) do if g.key == group then return g.title; end end
end

function R.Clean(message)
    return tostring(message or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "");
end

function R.Kind(event, message, author)
    if event == "CHAT_MSG_WHISPER_INFORM" then return "outgoing"; end
    if event == "CHAT_MSG_SYSTEM" then return "system"; end
    if event ~= "CHAT_MSG_WHISPER" then return "group"; end
    local text = R.Clean(message):lower();
    local chest = UnBotGroundChest;
    if (chest and chest.active and UnBotChatNormalizeName(chest.currentName) == UnBotChatNormalizeName(author))
        or text:match("^debug") or text:match("^position:") or text:match("^tpos:") then return "debug"; end
    if text:find("cannot cast",1,true) or text:find("unknown spell",1,true)
        or text:find("spell cast failed",1,true) or text:match("^casting ")
        or text:match("^cast:") or text:match("^no items") or text:match("^cannot ") then return "spell"; end
    if text:match("^strategies?%s*:") or text:match("^combat strategies")
        or text:match("^non%-combat strategies") or text:match("^rti[%s:]")
        or text:match("^rtsc[%s:]") or text:match("^raid target") then return "strategy"; end
    local recent = UnBotCombatChat and UnBotCombatChat.Recent(author);
    if recent and recent.query and text:match("^[%w%s,_%+%-]+$") then return "strategy"; end
    if text:match("^buying ") or text:match("^selling ") or text:match("^sold ")
        or text:match("^bags?[%s:]") or text:match("^inventory[%s:]")
        or text:match("^loot[%s:]") or text:match("^items?[%s:]") then return "inventory"; end
    if text:match("^do:%s") then return "debug"; end
    return "reply";
end

function R.SystemAuthor(message)
    local text = R.Clean(message);
    return text:match("^[Aa]dd:%s*([^%s]+)%s*%-")
        or text:match("^[Rr]emove:%s*([^%s]+)%s*%-")
        or text:match('Игрок с именем "([^"]+)" не найден')
        or text:match("^([^%s]+) присоединяется к") or text:match("^([^%s]+) покидает ")
        or text:match("^([^%s]+) умирает%.") or text:match("^([^%s]+) dies%.")
        or text:match("^([^%s]+) has joined ") or text:match("^([^%s]+) has left ")
        or text:match("^([^%s]+) joins the ") or text:match("^([^%s]+) leaves the ")
        or text:match("^([^%s:]+):%s*[Cc]annot cast")
        or text:match("^([^%s:]+):%s*[Cc]asting ")
        or text:match("^([^%s:]+):%s*[Uu]nknown spell");
end

function R.Find(title)
    for _,tab in ipairs(R.Tabs()) do if tab.label==title then return tab.frame; end end
end

function R.ValidateTitle(text)
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "");
    local _, count = text:gsub("[^\128-\191]", "");
    if text == "" or count > 24 or text:find("[%c|]") then
        return nil, "Название вкладки: 1–24 символа, без переносов и |.";
    end
    return text;
end

function R.Window(title, manual)
    local f = R.Find(title);
    if f then return f; end
    if not UnBotChatCanCreate then return nil; end
    local state = R.windows[title];
    if not state then state={attempts=0,retryAt=0}; R.windows[title]=state; end
    if not manual and (state.attempts >= 3 or GetTime() < state.retryAt) then return nil; end
    state.attempts = state.attempts+1; state.retryAt = GetTime()+10;
    if FCF_OpenNewWindow then pcall(FCF_OpenNewWindow, title); end
    f = R.Find(title); -- Some clients throw after creating a partial window.
    if not f then
        for i=1,(NUM_CHAT_WINDOWS or 0) do
            local tab=_G["ChatFrame"..i.."Tab"];
            if tab and tab.GetText and tab:GetText()==title then f=_G["ChatFrame"..i];break end
        end
    end
    if f then
        local tab=_G[tostring(f:GetName()).."Tab"];
        if tab and tab.Show then tab:Show();end
        UnBotChatPrepareFrame(f); UnBotChatDockFrame(f);
        if UnBotCombatChat then UnBotCombatChat.InstallDBMChatRouting(); end
    end
    return f;
end

function R.WriteOnce(event, message, author, frame)
    local key = event.."\031"..tostring(author or "").."\031"..tostring(message or "");
    local now = GetTime();
    if R.last.key == key and now-(R.last.time or 0) < 0.02 then return; end
    R.last.key=key; R.last.time=now;
    local prefix = "|cffff80ff<"..tostring(author or "")..">|r ";
    if event == "CHAT_MSG_WHISPER_INFORM" then prefix="|cffaaaaff-> "..tostring(author)..":|r ";
    elseif event == "CHAT_MSG_SYSTEM" then prefix="|cffffff00Сервер:|r "; end
    frame:AddMessage(prefix..tostring(message or ""));
end

function R.Filter(self, event, message, author)
    if UnBotAltSetups and UnBotAltSetups.QuietChat and UnBotAltSetups.QuietChat(event,message,author) then return true,true;end
    local name = author;
    if event == "CHAT_MSG_SYSTEM" then
        if UnBotChatKeepAutoBalanceSystem(message) then return false; end
        name=R.SystemAuthor(message);
        if not name then return false; end
    elseif event ~= "CHAT_MSG_WHISPER" and event ~= "CHAT_MSG_WHISPER_INFORM"
        and event ~= "CHAT_MSG_SAY" and event ~= "CHAT_MSG_PARTY"
        and event ~= "CHAT_MSG_PARTY_LEADER" and event ~= "CHAT_MSG_RAID"
        and event ~= "CHAT_MSG_RAID_LEADER" then return false; end
    if UnBotChatNormalizeName(name) == UnBotChatNormalizeName(UnitName("player")) then return false; end
    -- Content heuristics apply only to whispers, never to player group/system text.
    local group = R.Group(name, event == "CHAT_MSG_WHISPER" and message or nil);
    if not group then return false; end
    local kind = R.Kind(event, message, author);
    local destination = R.Destination(group, kind);
    if destination == "hide" then return true, true; end
    local f=R.RouteFrame(destination);
    if not f then
        if not R.warned then
            R.warned=true;
            local _,title=R.ParseRoute(destination);
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffaa00UnBot: вкладка «"..tostring(title or "").."» закрыта. Сообщения показаны в «"..R.RouteLabel(R.GeneralRoute()).."». Выберите вкладку в настройках чата.|r"); end
        end
        f=DEFAULT_CHAT_FRAME;
        if not f then return true,false; end
    else
        R.warned=false;
    end
    R.WriteOnce(event, message, author, f);
    return true, true;
end


function R.Roster()
    local rows,seen={},{};
    local raid=(GetNumRaidMembers and GetNumRaidMembers() or 0)>0;
    local count=raid and GetNumRaidMembers() or (GetNumPartyMembers and GetNumPartyMembers() or 0);
    local player=UnBotChatNormalizeName(UnitName("player"));
    for i=1,math.min(raid and 40 or 4,tonumber(count) or 0) do
        local unit=(raid and "raid" or "party")..i;
        local name=UnitName(unit);
        local className=UnitClass and UnitClass(unit);
        if raid and GetRaidRosterInfo then
            local rosterName,rank,subgroup,level,rosterClass=GetRaidRosterInfo(i);
            if not name or name==UNKNOWN or name==UNKNOWNOBJECT then name=rosterName;end
            className=className or rosterClass;
        end
        local key=UnBotChatNormalizeName(name);
        if name and name~="" and name~=UNKNOWN and name~=UNKNOWNOBJECT and key~=player and not seen[key] then
            seen[key]=true;
            rows[#rows+1]={name=name,key=key,className=className or "",online=UnitIsConnected and UnitIsConnected(unit) and true or false};
        end
    end
    table.sort(rows,function(a,b)return a.key<b.key;end);
    return rows;
end


function R.LinkedRows()
    local members,rows,entries={},{},{};
    for _,entry in ipairs(R.Roster()) do members[entry.key]=entry;end
    local saved=UnBotLinkedAccounts and UnBotLinkedAccounts.Storage();
    if saved then
        for _,accountKey in ipairs(saved.current) do
            local account=saved.accounts[accountKey];
            if type(account)=="table" and (not saved.selected or accountKey==saved.selected) then
                for key,alt in pairs(account.characters or {}) do
                    if type(alt)=="table" and alt.name and UnBotChatNormalizeName(alt.name)==key then
                        entries[key]={name=alt.name,account=account.name or accountKey,accountKey=accountKey,alt=alt};
                    end
                end
            end
        end
    end
    for key,entry in pairs(entries) do
        local member=members[key];local className=member and member.className;
        if className and className~="" then entry.alt.className=className;end
        rows[#rows+1]={key=key,name=entry.name,account=entry.account,accountKey=entry.accountKey,alt=entry.alt,
            className=className or entry.alt.className or "—",
            state=member and (member.online and "В группе / онлайн" or "В группе / офлайн") or "Вне группы"};
    end
    table.sort(rows,function(a,b)return a.key<b.key;end);return rows;
end

function R.RefreshLinked()
    local f=R.linkedFrame;if not f then return;end
    local entries=R.LinkedRows();local pageSize=#f.rows;local pages=math.max(1,math.ceil(#entries/pageSize));
    f.page=math.max(1,math.min(pages,f.page or 1));
    for i,row in ipairs(f.rows) do
        local entry=entries[(f.page-1)*pageSize+i];
        if entry then
            row.name=entry.name;row.accountKey=entry.accountKey;row.alt=entry.alt;
            row.title:SetText(entry.name);row.classText:SetText(entry.className);
            row.accountText:SetText(entry.account);
            row.sellJunk:SetChecked(entry.alt.allowGrayJunk == true);
            local editableAlt,_,editableAccount;
            if UnBotAccountAlts and UnBotAccountAlts.GrayJunkEntry then editableAlt,_,editableAccount=UnBotAccountAlts.GrayJunkEntry(entry.name);end
            if editableAlt==entry.alt and editableAccount==entry.accountKey then row.sellJunk:Enable();else row.sellJunk:Disable();end
            row.state:SetText(entry.state);row:Show();
        else row.name=nil;row.accountKey=nil;row.alt=nil;row.sellJunk:SetChecked(false);row.sellJunk:Disable();row:Hide();end
    end
    if #entries==0 then
        local saved=UnBotLinkedAccounts and UnBotLinkedAccounts.Storage();
        local selected=saved and saved.selected and saved.accounts[saved.selected];
        if not saved or #saved.current==0 then
            f.summary:SetText(saved and saved.verifiedAt and "Список пуст: связанных аккаунтов нет." or "Нет подтверждённых привязок. Нажмите «Обновить привязки».");
        elseif not selected then
            f.summary:SetText("Список пуст. Выберите аккаунт, затем нажмите «Собрать альтов аккаунта».");
        elseif UnBotLinkedAccounts.InGroup() then
            f.summary:SetText("Альты "..tostring(selected.name or saved.selected).." ещё не собраны. Покиньте группу / рейд, затем нажмите «Собрать альтов аккаунта».");
        elseif UnBotLinkedAccounts.Fighting() then
            f.summary:SetText("Альты "..tostring(selected.name or saved.selected).." ещё не собраны. После боя нажмите «Собрать альтов аккаунта».");
        else
            f.summary:SetText("Альты "..tostring(selected.name or saved.selected).." ещё не собраны. Нажмите «Собрать альтов аккаунта».");
        end
    else
        f.summary:SetText("Сохранено альтов: "..#entries..". Вне группы имена тоже остаются в списке.");
    end
    f.pageText:SetText("Страница "..f.page.." / "..pages);
    if f.page>1 then f.prev:Enable();else f.prev:Disable();end
    if f.page<pages then f.next:Enable();else f.next:Disable();end
    if UnBotLinkedAccounts then UnBotLinkedAccounts.RefreshPanel(f);end
end

function R.LinkedController()
    if UnBotLinkedAccounts and UnBotLinkedAccounts.frame then return UnBotLinkedAccounts;end
    local text="Модуль связанных аккаунтов не загружен. Полностью перезапустите клиент WoW.";
    if R.linkedFrame then R.linkedFrame.status:SetText(text);end
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("UnBot: "..text);end
end

function R.CreateLinkedPanel(parent)
    if R.linkedFrame then return R.linkedFrame;end
    local f=CreateFrame("Frame","UnBotLinkedAltsPanel",parent);R.linkedFrame=f;f.page=1;f.rows={};
    f:SetPoint("TOPLEFT",parent,"TOPLEFT",0,-34);f:SetWidth(970);f:SetHeight(516);f:Hide();
    local intro=UnBotServiceUI.Text(f,14,940,"Все известные альты привязанных аккаунтов автоматически относятся к «Альты связанных аккаунтов». Сбор подключает всех альтов выбранного аккаунта; начинайте без группы / рейда.");
    intro:SetPoint("TOPLEFT",f,"TOPLEFT",12,-4);
    f.refreshAccounts=UnBotServiceUI.Button(f,210,"Обновить привязки",function()
        local controller=R.LinkedController();if controller then controller.BeginRefresh();end
    end);
    f.refreshAccounts:SetPoint("TOPLEFT",f,"TOPLEFT",12,-42);f.refreshAccounts:SetHeight(30);
    f.accountMenu=CreateFrame("Frame","UnBotLinkedAccountChoice",f,"UIDropDownMenuTemplate");
    f.accountMenu:SetPoint("TOPLEFT",f,"TOPLEFT",226,-40);UIDropDownMenu_SetWidth(f.accountMenu,278);
    UIDropDownMenu_Initialize(f.accountMenu,function(self,level)if UnBotLinkedAccounts then UnBotLinkedAccounts.AccountMenu(self,level);end end);
    f.scan=UnBotServiceUI.Button(f,280,"Собрать альтов аккаунта",function()
        local controller=R.LinkedController();if controller then controller.BeginScan(controller.Storage().selected);end
    end);f.scan:SetPoint("TOPLEFT",f,"TOPLEFT",548,-42);f.scan:SetHeight(30);
    f.stop=UnBotServiceUI.Button(f,100,"Стоп",function()
        local controller=R.LinkedController();if controller then controller.Stop();end
    end);
    f.stop:SetPoint("TOPLEFT",f,"TOPLEFT",840,-42);f.stop:SetHeight(30);
    f.accountsText=UnBotServiceUI.Text(f,13,940,"Нажмите «Обновить привязки», чтобы получить список с сервера.");
    f.accountsText:SetPoint("TOPLEFT",f,"TOPLEFT",12,-82);
    local loginLabel=UnBotServiceUI.Text(f,14,72,"Логин:");loginLabel:SetPoint("TOPLEFT",f,"TOPLEFT",12,-116);
    f.login=CreateFrame("EditBox",nil,f,"InputBoxTemplate");f.login:SetWidth(230);f.login:SetHeight(28);
    f.login:SetMaxLetters(64);f.login:SetAutoFocus(false);f.login:SetPoint("TOPLEFT",f,"TOPLEFT",84,-108);
    local secretLabel=UnBotServiceUI.Text(f,14,70,"Код:");secretLabel:SetPoint("TOPLEFT",f,"TOPLEFT",334,-116);
    f.secret=CreateFrame("EditBox",nil,f,"InputBoxTemplate");f.secret:SetWidth(230);f.secret:SetHeight(28);
    f.secret:SetMaxLetters(128);f.secret:SetAutoFocus(false);f.secret:SetPassword(true);f.secret:SetPoint("TOPLEFT",f,"TOPLEFT",398,-108);
    for _,input in ipairs({f.login,f.secret}) do
        input:SetScript("OnEnterPressed",function(self)self:ClearFocus();end);
        input:SetScript("OnEscapePressed",function(self)self:ClearFocus();end);
    end
    f.link=UnBotServiceUI.Button(f,290,"Связать аккаунт",function()
        local controller=R.LinkedController();if controller then controller.Link(f.login:GetText(),f.secret:GetText());end
    end);f.link:SetPoint("TOPLEFT",f,"TOPLEFT",650,-106);f.link:SetHeight(30);
    local help=UnBotServiceUI.Text(f,13,940,"PikaWoW: на ПРИВЯЗЫВАЕМОМ аккаунте введите .playerbots account setKey ВАШ_КОД\nНа ОСНОВНОМ — укажите здесь логин того аккаунта (не имя персонажа) и этот код. Код не сохраняется.");
    help:SetPoint("TOPLEFT",f,"TOPLEFT",12,-144);
    f.status=UnBotServiceUI.Text(f,13,940,"Имена сохраняются автоматически. На диск — при /reload или выходе из игры.");
    f.status:SetPoint("TOPLEFT",f,"TOPLEFT",12,-184);f.status:SetTextColor(0.35,0.95,1);
    f.summary=UnBotServiceUI.Text(f,14,940);f.summary:SetPoint("TOPLEFT",f,"TOPLEFT",12,-220);
    for _,column in ipairs({{12,200,"Имя"},{232,190,"Аккаунт"},{442,150,"Класс"},{602,170,"Состояние"},{802,150,"Продать хлам"}}) do
        local label=UnBotServiceUI.Text(f,14,column[2],column[3]);label:SetPoint("TOPLEFT",f,"TOPLEFT",column[1],-244);
    end
    for i=1,10 do
        local row=UnBotServiceUI.Panel(f,940,20);row:SetPoint("TOPLEFT",f,"TOPLEFT",12,-268-(i-1)*20);
        row.title=UnBotServiceUI.Text(row,13,200);row.title:SetPoint("TOPLEFT",row,"TOPLEFT",0,-3);
        row.accountText=UnBotServiceUI.Text(row,13,190);row.accountText:SetPoint("TOPLEFT",row,"TOPLEFT",220,-3);
        row.classText=UnBotServiceUI.Text(row,13,150);row.classText:SetPoint("TOPLEFT",row,"TOPLEFT",430,-3);
        row.state=UnBotServiceUI.Text(row,13,170);row.state:SetPoint("TOPLEFT",row,"TOPLEFT",590,-3);
        row.sellJunk=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate");
        row.sellJunk:SetWidth(20);row.sellJunk:SetHeight(20);row.sellJunk:SetPoint("TOPLEFT",row,"TOPLEFT",816,0);
        row.sellJunk:SetScript("OnClick",function(self)
            if row.name and UnBotAccountAlts and UnBotAccountAlts.GrayJunkEntry then
                local entry,_,accountKey=UnBotAccountAlts.GrayJunkEntry(row.name);
                if entry==row.alt and accountKey==row.accountKey then
                    UnBotAccountAlts.SetGrayJunkAllowed(row.name,self:GetChecked(),row.accountKey);
                end
            end
            R.RefreshLinked();
        end);
        row.sellJunk:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_TOP");GameTooltip:AddLine("Разрешить продажу серого хлама",1,.82,.18);
            GameTooltip:AddLine("Для этого альта при нажатии «Продать хлам альтов». Нужен онлайн-альт в составе и открытый торговец. Реагенты и другие предметы не продаются; закупка реагентов не включается.",1,1,1,true);
            GameTooltip:Show();
        end);
        row.sellJunk:SetScript("OnLeave",function() GameTooltip:Hide();end);
        f.rows[i]=row;
    end
    f.prev=UnBotServiceUI.Button(f,100,"Назад",function()f.page=f.page-1;R.RefreshLinked();end);
    f.prev:SetHeight(28);
    f.prev:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",12,4);
    f.next=UnBotServiceUI.Button(f,100,"Далее",function()f.page=f.page+1;R.RefreshLinked();end);
    f.next:SetHeight(28);
    f.next:SetPoint("LEFT",f.prev,"RIGHT",12,0);
    f.pageText=UnBotServiceUI.Text(f,14,500);f.pageText:SetPoint("LEFT",f.next,"RIGHT",16,0);
    for _,event in ipairs({"PARTY_MEMBERS_CHANGED","RAID_ROSTER_UPDATE","PLAYER_ENTERING_WORLD"}) do f:RegisterEvent(event);end
    f:SetScript("OnEvent",function(self)if self:IsShown() then R.RefreshLinked();end end);
    f:SetScript("OnShow",function()R.RefreshLinked();if UnBotLinkedAccounts then UnBotLinkedAccounts.OnShow();end end);
    f:SetScript("OnHide",function()
        f.login:ClearFocus();f.secret:SetText("");f.secret:ClearFocus();
    end);
    return f;
end

function R.LoadDrafts()
    local f=R.frame; f.drafts={};
    for _,g in ipairs(R.groups) do
        local d={routes={}};
        for _,k in ipairs(R.kinds) do d.routes[k.key]=R.Destination(g.key,k.key); end
        f.drafts[g.key]=d;
    end
end

function R.Refresh()
    local f=R.frame;
    local draft=f.drafts[f.group];
    for _,row in ipairs(f.rows) do
        UIDropDownMenu_SetText(row.menu,R.RouteLabel(draft.routes[row.kind]));
    end
    for _,b in ipairs(f.groupButtons) do
        if b.group==f.group then b:Disable(); else b:Enable(); end
    end
    f.dbmIntercept:SetChecked(UnBotCombatChat.IsDBMChatRoutingEnabled());
    UIDropDownMenu_SetText(f.serviceMenu,R.RouteLabel(R.ServiceDestination()));
end

function R.Saved()
    R.warned=false;
    R.serviceWarned=nil;
    if R.frame and R.frame.status then R.frame.status:SetText("Изменения применяются автоматически. На диск — при /reload или выходе из игры.");end
    if R.linkedFrame and UnBotLinkedAccounts then UnBotLinkedAccounts.RefreshPanel(R.linkedFrame);end
end

function R.SaveRoutes(group)
    local routes=R.frame.drafts[group].routes;
    for _,k in ipairs(R.kinds) do
        if routes[k.key]~="hide" and not R.ParseRoute(routes[k.key]) then R.frame.status:SetText("Выберите вкладку для всех типов сообщений.");return false;end
    end
    local c=R.Storage();
    if type(c.groups[group])~="table" then c.groups[group]={};end
    local saved=c.groups[group];
    if type(saved.routes)~="table" then saved.routes={};end
    for _,k in ipairs(R.kinds) do saved.routes[k.key]=routes[k.key];end
    R.Saved();return true;
end


function R.OpenDraftTab()
    local title,err=R.ValidateTitle(R.frame.titleInput:GetText());
    if not title then R.frame.status:SetText(err); return; end
    local existed=R.Find(title);
    local f=R.Window(title,true);
    if not f then R.frame.status:SetText("Не удалось открыть вкладку: выйдите из боя и освободите одно окно чата."); return; end
    if FCF_SelectDockFrame and UnBotChatFrameIsDocked(f) then FCF_SelectDockFrame(f); else f:Show(); end
    if not existed then f:AddMessage("|cffffcc66UnBot: вкладка «"..title.."» создана.|r"); end
    local ui=R.frame;
    if ui.createKind then
        if ui.createKind=="service" then R.Storage().serviceRoute=R.TabRoute(title);R.Saved();
        else ui.drafts[ui.createGroup].routes[ui.createKind]=R.TabRoute(title);R.SaveRoutes(ui.createGroup);end
    end
    ui.createKind=nil;ui.createGroup=nil;ui.titleInput:ClearFocus();
    R.Refresh();
    ui.status:SetText("Вкладка «"..title.."» доступна в списках. Изменения применяются автоматически.");
end

function R.SelectedRoute(kind)
    if kind=="service" then return R.ServiceDestination();end
    return R.frame.drafts[R.frame.group].routes[kind];
end

function R.ChooseRoute(kind,destination)
    if kind=="service" then R.Storage().serviceRoute=destination;R.Saved();
    else R.frame.drafts[R.frame.group].routes[kind]=destination;R.SaveRoutes(R.frame.group);end
end

function R.Menu(dropdown, kind, level)
    -- WotLK initializes dropdowns immediately, before the window has drafts.
    -- Opening a completed dropdown invokes this initializer again.
    if not R.frame or not R.frame.drafts or not R.frame.drafts[R.frame.group] then return; end
    for _,d in ipairs(R.Tabs()) do
        local destination,label=d.key,d.label;
        local info=UIDropDownMenu_CreateInfo();
        info.text=label; info.checked=R.SelectedRoute(kind)==destination;
        info.func=function()
            R.ChooseRoute(kind,destination);
            UIDropDownMenu_SetText(dropdown,label);
        end;
        UIDropDownMenu_AddButton(info,level or 1);
    end
    local hidden=UIDropDownMenu_CreateInfo();
    hidden.text="Скрывать";hidden.checked=R.SelectedRoute(kind)=="hide";
    hidden.func=function()
        R.ChooseRoute(kind,"hide");
        UIDropDownMenu_SetText(dropdown,"Скрывать");
    end;
    UIDropDownMenu_AddButton(hidden,level or 1);
    local create=UIDropDownMenu_CreateInfo();create.text="Создать вкладку...";create.notCheckable=true;
    create.func=function()
        R.frame.createKind=kind;R.frame.createGroup=R.frame.group;
        R.frame.titleInput:SetText("");R.frame.titleInput:SetFocus();
        R.frame.status:SetText("Введите название сверху и нажмите «Создать вкладку». Она сразу будет выбрана для этой строки.");
        CloseDropDownMenus();
    end;
    UIDropDownMenu_AddButton(create,level or 1);
end

function R.CreatePanel(parent)
    if not R.frame then
        local f=CreateFrame("Frame","UnBotChatSettingsFrame",parent);
        f:SetPoint("TOPLEFT",parent,"TOPLEFT",20,-128);f:SetWidth(970);f:SetHeight(550);f:Hide();
        R.frame=f; f.group=R.Storage().selectedGroup or "own";
        if f.group~="own" and f.group~="paired" and f.group~="bots" then f.group="own";end
        f.groupButtons={}; f.rows={};
        local intro=UnBotServiceUI.Text(f,14,940,"Выберите вкладки по их названиям в чате. Служебные сообщения UnBot настраиваются отдельно для всех участников.");
        intro:SetPoint("TOPLEFT",f,"TOPLEFT",12,-4);
        for i,g in ipairs(R.groups) do
            local key=g.key;
            local b=UnBotServiceUI.Button(f,290,g.label,function()
                f.group=key;R.Storage().selectedGroup=key;
                f.createKind=nil;f.createGroup=nil;R.Refresh();
            end);
            b.group=key; b:SetPoint("TOPLEFT",f,"TOPLEFT",12+(i-1)*310,-32);
            f.groupButtons[i]=b;
        end
        local titleLabel=UnBotServiceUI.Text(f,16,245,"Название новой вкладки:");
        titleLabel:SetPoint("TOPLEFT",f,"TOPLEFT",12,-84);
        f.titleInput=CreateFrame("EditBox",nil,f,"InputBoxTemplate");
        f.titleInput:SetWidth(330); f.titleInput:SetHeight(28); f.titleInput:SetAutoFocus(false);
        f.titleInput:SetPoint("TOPLEFT",f,"TOPLEFT",264,-78);
        f.titleInput:SetScript("OnTextChanged",function(self) if not f.loading then R.Storage().newTabTitle=self:GetText();end end);
        f.titleInput:SetScript("OnEnterPressed",function(self) self:ClearFocus(); end);
        f.titleInput:SetScript("OnEscapePressed",function(self) self:ClearFocus(); end);
        local open=UnBotServiceUI.Button(f,290,"Создать вкладку",R.OpenDraftTab);
        open:SetPoint("TOPRIGHT",f,"TOPRIGHT",-48,-74);
        for i,k in ipairs(R.kinds) do
            local kind=k.key;
            local label=UnBotServiceUI.Text(f,16,540,k.label);
            label:SetPoint("TOPLEFT",f,"TOPLEFT",12,-118-(i-1)*30);
            local menu=CreateFrame("Frame","UnBotChatRoute"..i,f,"UIDropDownMenuTemplate");
            menu:SetPoint("TOPLEFT",f,"TOPLEFT",555,-110-(i-1)*30);
            UIDropDownMenu_SetWidth(menu,328);
            UIDropDownMenu_Initialize(menu,function(self,level) R.Menu(self,kind,level); end);
            f.rows[i]={kind=kind,menu=menu};
        end
        local serviceLabel=UnBotServiceUI.Text(f,16,540,"Служебные сообщения UnBot (для всех)");
        serviceLabel:SetPoint("TOPLEFT",f,"TOPLEFT",12,-366);
        f.serviceMenu=CreateFrame("Frame","UnBotChatServiceRoute",f,"UIDropDownMenuTemplate");
        f.serviceMenu:SetPoint("TOPLEFT",f,"TOPLEFT",555,-358);
        UIDropDownMenu_SetWidth(f.serviceMenu,328);
        UIDropDownMenu_Initialize(f.serviceMenu,function(self,level)R.Menu(self,"service",level);end);
        f.dbmIntercept=CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate");
        f.dbmIntercept:SetWidth(24);f.dbmIntercept:SetHeight(24);
        f.dbmIntercept:SetPoint("TOPLEFT",f,"TOPLEFT",12,-400);
        f.dbmIntercept:SetScript("OnClick",function(self)
            R.Storage().interceptDBM=self:GetChecked() and true or false;
            R.Saved();
        end);
        local dbmLabel=UnBotServiceUI.Text(f,16,890,"Перехватывать сообщения DBM (переносить во вкладку UnBot)");
        dbmLabel:SetPoint("TOPLEFT",f,"TOPLEFT",44,-405);
        local dbmHint=UnBotServiceUI.Text(f,14,890,"По умолчанию выключено. Изменение применяется сразу.");
        dbmHint:SetPoint("TOPLEFT",f,"TOPLEFT",44,-426);
        local hint=UnBotServiceUI.Text(f,14,940,"Список связанных альтов: «Альты» -> «Связанные аккаунты». «Скрывать» убирает текст; обработка ответов продолжается.");
        hint:SetPoint("TOPLEFT",f,"TOPLEFT",12,-454);
        f.status=UnBotServiceUI.Text(f,15,942,"Изменения применяются автоматически. На диск — при /reload или выходе из игры.");
        f.status:SetPoint("TOPLEFT",f,"TOPLEFT",12,-490); f.status:SetTextColor(0.35,0.95,1);
        local defaults=UnBotServiceUI.Button(f,360,"Сбросить выбранную группу",function()
            for _,k in ipairs(R.kinds) do f.drafts[f.group].routes[k.key]=R.Default(f.group,k.key); end
            R.SaveRoutes(f.group);R.Refresh();
        end);
        defaults:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",12,4);
        f:SetScript("OnHide",function()
            f.titleInput:ClearFocus();CloseDropDownMenus();
        end);
        f:SetScript("OnShow",function()
            R.LoadDrafts();f.createKind=nil;f.createGroup=nil;
            f.loading=true;f.titleInput:SetText(R.Storage().newTabTitle or "");f.loading=false;
            R.Refresh();
        end);
    end
    return R.frame;
end

function R.Show()
    if UnBotBotCenterShow then UnBotBotCenterShow("chat");end
end

SLASH_UNBOTCHATSETTINGS1="/ubchatsettings";
SlashCmdList["UNBOTCHATSETTINGS"]=R.Show;

-- Account controller is embedded so cached pre-239 TOCs still load it on /reload.
do
-- Explicit account discovery/linking; chat routing itself remains display-only.
UnBotLinkedAccounts = {verified=false, redactedLoggers={}};
local L = UnBotLinkedAccounts;

function L.Storage()
    local c=UnBotChatRouting.Storage();
    if type(c.linkedAccountsByRealm)~="table" then c.linkedAccountsByRealm={};end
    local realm=GetRealmName and GetRealmName() or "";
    if type(c.linkedAccountsByRealm[realm])~="table" then c.linkedAccountsByRealm[realm]={};end
    -- Old realm-only cache remains archived. A copied cache grants no links.
    local account=GetCVar and tostring(GetCVar("accountName") or ""):upper() or "";
    local owner=account~="" and account or ("player:"..tostring(UnitName("player") or ""));
    if type(c.linkedAccountsByOwner)~="table" then c.linkedAccountsByOwner={};end
    if type(c.linkedAccountsByOwner[realm])~="table" then c.linkedAccountsByOwner[realm]={};end
    if type(c.linkedAccountsByOwner[realm][owner])~="table" then
        local archived=c.linkedAccountsByRealm[realm];local copy={};
        for key,value in pairs(archived) do copy[key]=value;end
        copy.current={};copy.selected=nil;copy.verifiedAt=nil;copy.owner=owner;
        c.linkedAccountsByOwner[realm][owner]=copy;
    end
    local s=c.linkedAccountsByOwner[realm][owner];
    if type(s.accounts)~="table" then s.accounts={};end
    if type(s.current)~="table" then s.current={};end
    s.schemaVersion=math.max(2,tonumber(s.schemaVersion) or 0);
    return s;
end

function L.Clean(text)
    return tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
        :gsub("^Сервер:%s*",""):match("^%s*(.-)%s*$");
end

function L.AccountKey(name)
    name=L.Clean(name);
    if name=="" or #name>64 or name:find("[%s%c|;\"'\\]") then return nil;end
    return name:upper();
end

function L.Redact(text)
    text=tostring(text or "");
    text=text:gsub("(%.playerbots?%s+account%s+[Ll][Ii][Nn][Kk]%s+%S+%s+)%S+","%1[скрыто]");
    return (text:gsub("(%.playerbots?%s+account%s+[Ss][Ee][Tt][Kk][Ee][Yy]%s+)%S+","%1[скрыто]"));
end

function L.InstallRedaction()
    -- Both installed loggers observe SAY commands; mask before they store text.
    for _,logger in ipairs({UnBotSummonLog or false,UnBotTrace or false}) do
        if logger and type(logger.Text)=="function" and not L.redactedLoggers[logger] then
            local original=logger.Text;
            logger.Text=function(value,limit)return original(L.Redact(value),limit);end;
            L.redactedLoggers[logger]=true;
        end
    end
end

function L.Message(text)
    L.status=text;
    if UnBotChatAddMessage then UnBotChatAddMessage("Связанные аккаунты: "..text);
    elseif DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("UnBot: Связанные аккаунты: "..text);end
    L.Refresh();
end

function L.Refresh()
    if UnBotChatRouting.linkedFrame then UnBotChatRouting.RefreshLinked();end
end

function L.Fighting()
    return (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player"));
end

function L.OthersBusy()
    return (UnBotMythicPlusBuffOtherAutomationActive and UnBotMythicPlusBuffOtherAutomationActive())
        or (UnBotAccountAlts and (UnBotAccountAlts.active or UnBotAccountAlts.discoveryActive))
        or (UnBotBeaconTravel and UnBotBeaconTravel.active)
        or (UnBotAltStrategies and (UnBotAltStrategies.active or #(UnBotAltStrategies.queue or {})>0))
        or (UnBotTrace and UnBotTrace.sweep and UnBotTrace.sweep.active);
end

function L.InGroup()
    return (GetNumRaidMembers and GetNumRaidMembers() or 0)>0
        or (GetNumPartyMembers and GetNumPartyMembers() or 0)>0;
end

function L.CanStart()
    if L.job or GetTime()<(L.cooldownUntil or 0) then L.Message("Дождитесь завершения текущего запроса.");return false;end
    if L.Fighting() then L.Message("Сначала выйдите из боя.");return false;end
    if L.OthersBusy() then L.Message("Сначала завершите другую операцию UnBot.");return false;end
    return true;
end

function L.Current(key)
    for _,value in ipairs(L.Storage().current) do if value==key then return true;end end
    return false;
end

function L.Send(command)
    -- Secure post-hooks can observe this call after pcall has returned. Keep
    -- ownership on the finite request, not on the duration of the Lua call.
    -- Never retain a link/setKey secret, even in transient runtime state.
    if L.job then L.job.command=L.Clean(L.Redact(command)):lower();end
    local ok=pcall(SendChatMessage,command,"SAY");
    if not ok then L.Stop("Не удалось отправить команду серверу.");end
    return ok;
end

function L.BeginRefresh(internal)
    if not internal and not L.CanStart() then return false;end
    L.job={kind="accounts",deadline=GetTime()+8,names={},seen={}};
    L.Message("Запрашиваю привязанные аккаунты...");
    return L.Send(".playerbots account linkedAccounts");
end

function L.OnShow()
    -- Viewing saved links never starts a server request or an account scan.
    L.Refresh();
end

function L.CommitAccounts()
    local job=L.job;if not job or job.kind~="accounts" then return;end
    local s=L.Storage();
    -- Only a completed response replaces the visible links; cached characters survive unlinking.
    s.current=job.names;s.verifiedAt=time();L.verified=true;
    if s.selected and not L.Current(s.selected) then s.selected=nil;end
    -- A single confirmed account is the only meaningful scan target. Select it
    -- so the player can collect its characters without reopening the dropdown.
    if not s.selected and #s.current==1 then s.selected=s.current[1];end
    for _,key in ipairs(s.current) do
        if type(s.accounts[key])~="table" then s.accounts[key]={};end
        local entry=s.accounts[key];entry.name=job.seen[key];
        if type(entry.characters)~="table" then entry.characters={};end
    end
    L.job=nil;L.cooldownUntil=GetTime()+1;
    L.Message("Привязанных аккаунтов: "..#s.current..".");
end

function L.Select(key)
    local s=L.Storage();s.selected=key;
    local f=UnBotChatRouting.linkedFrame;if f then f.page=1;end
    L.Refresh();
end

function L.BeginScan(key)
    if not L.CanStart() then return false;end
    if L.InGroup() then L.Message("Для сбора альтов выйдите из группы и рейда, включая офлайн-участников.");return false;end
    if (not L.verified and not L.Storage().verifiedAt) or not L.Current(key) then L.Message("Обновите привязки и выберите подтверждённый аккаунт.");return false;end
    local entry=L.Storage().accounts[key];
    L.job={kind="scan",key=key,deadline=GetTime()+20,seen={},count=0,errors=0};
    L.Message("Подключаю всех альтов "..entry.name.." и собираю имена...");
    return L.Send(".playerbots bot addaccount "..entry.name);
end

function L.FinishScan(reason)
    local job=L.job;if not job or job.kind~="scan" then return;end
    local entry=L.Storage().accounts[job.key];
    entry.scannedAt=time();entry.lastScanCount=job.count;entry.scanStatus=reason;
    L.job=nil;L.cooldownUntil=GetTime()+2;
    L.Message(reason.." "..entry.name..": сохранено имён из ответов — "..job.count
        ..(job.errors>0 and (", отказов подключения — "..job.errors) or "")..".");
end

function L.Link(login,secret)
    login=L.Clean(login);secret=tostring(secret or "");
    local key=L.AccountKey(login);
    if not key then L.Message("Укажите логин аккаунта без пробелов и кавычек.");return false;end
    if secret=="" or secret:find("[%s%c|]") then L.Message("Укажите секретный код без пробелов.");return false;end
    if not L.CanStart() then return false;end
    local command=".playerbots account link "..login.." "..secret;
    if #command>255 then L.Message("Логин и код слишком длинные для команды чата.");return false;end
    L.InstallRedaction();
    L.job={kind="link",key=key,deadline=GetTime()+8};
    local f=UnBotChatRouting.linkedFrame;
    if f then f.secret:SetText("");f.secret:ClearFocus();f.login:ClearFocus();end
    L.Message("Отправлена привязка аккаунта "..login.."...");
    return L.Send(command);
end

function L.Stop(reason)
    if L.job and L.job.kind=="scan" then L.FinishScan(reason or "Сбор остановлен.");return;end
    L.job=nil;L.cooldownUntil=GetTime()+2;
    L.Message(reason or "Запрос остановлен. Сохранённые списки оставлены.");
end

function L.RecordName(job,name,result)
    local key=UnBotChatNormalizeName(name);
    if key=="" or name:find("[%s%c|,;]") or key==UnBotChatNormalizeName(UnitName("player")) then return;end
    local entry=L.Storage().accounts[job.key];
    if type(entry.characters)~="table" then entry.characters={};end
    local isNew=type(entry.characters[key])~="table";
    if isNew then entry.characters[key]={};end
    local alt=entry.characters[key];alt.name=name;alt.seenAt=time();alt.result=result;
    if not job.seen[key] then
        job.count=job.count+1;job.seen[key]=true;
        if result~="ok" and result~="player already logged in" then job.errors=job.errors+1;end
    end
    L.Refresh();
end

function L.Line(text)
    local job=L.job;if not job then return;end
    text=L.Clean(text);
    if job.kind=="accounts" then
        if text=="No linked accounts." then job.names={};job.seen={};L.CommitAccounts();return;end
        if text=="Linked accounts:" then
            if job.header then L.Stop("Получен второй ответ списка привязок. Повторите обновление.");return;end
            job.header=true;job.lastReply=GetTime();return;
        end
        if job.header and text=="- Unknown account" then L.Stop("Сервер не смог определить один из аккаунтов. Сохранённые привязки оставлены.");return;end
        local name=text:match("^%-%s*(%S+)%s*$");
        if job.header and name then
            local key=L.AccountKey(name);
            if not key or name=="Unknown" then return;end
            if not job.seen[key] then job.names[#job.names+1]=key;job.seen[key]=name;end
            job.lastReply=GetTime();return;
        end
    elseif job.kind=="link" and text=="Account linked successfully." then
        local key=job.key;L.job=nil;L.verified=false;L.Storage().selected=key;
        L.Message("Аккаунт связан. Обновляю список привязок...");L.BeginRefresh(true);return;
    elseif job.kind=="scan" then
        local name,result=text:match("^addaccount:%s*(.-)%s+%-%s+(.+)$");
        if name then
            L.RecordName(job,name,result:lower());job.lastReply=GetTime();return;
        end
    end
    if text:match("^Usage:") or text:lower():match("^unknown command") or text=="Account not found." or text=="Invalid security key."
        or text=="PlayerbotMgr instance not found." or text:find("Neither account nor character",1,true)
        or text:find("Could not find account",1,true) then
        L.Stop(text=="Invalid security key." and "Неверный секретный код. Проверьте код на привязываемом аккаунте."
            or "Сервер отказал в запросе. Проверьте логин и доступность команды.");
    end
end

function L.System(message)
    if not L.job then return;end
    for line in tostring(message or ""):gmatch("[^\r\n]+") do L.Line(line);end
end

function L.Update()
    local job=L.job;if not job then return;end
    if L.Fighting() or L.OthersBusy() then L.Stop("Запрос остановлен: начался бой или другая операция.");return;end
    local now=GetTime();
    if job.lastReply and now-job.lastReply>=2 then
        if job.kind=="accounts" and job.header and #job.names>0 then L.CommitAccounts();return;
        elseif job.kind=="scan" and job.count>0 then L.FinishScan("Сбор завершён.");return;end
    end
    if now>=job.deadline then
        if job.kind=="scan" then L.FinishScan("Таймаут: полнота списка не подтверждена.");
        else L.Stop("Сервер не прислал полный ответ за 8 секунд. Сохранённые списки оставлены.");end
    end
end

function L.AccountMenu(dropdown,level)
    local s=L.Storage();
    local all=UIDropDownMenu_CreateInfo();all.text="Все сохранённые альты";all.checked=not s.selected;
    all.func=function()L.Select(nil);end;UIDropDownMenu_AddButton(all,level or 1);
    for _,key in ipairs(s.current) do
        local accountKey=key;local entry=s.accounts[key];local count=0;
        for _ in pairs(entry.characters or {}) do count=count+1;end
        local info=UIDropDownMenu_CreateInfo();info.text=entry.name.." ("..count..")";info.checked=s.selected==key;
        info.func=function()L.Select(accountKey);end;UIDropDownMenu_AddButton(info,level or 1);
    end
end

function L.RefreshPanel(f)
    local s=L.Storage();local selected=s.selected and s.accounts[s.selected];
    UIDropDownMenu_SetText(f.accountMenu,selected and selected.name or "Все сохранённые альты");
    local names={};for _,key in ipairs(s.current) do names[#names+1]=s.accounts[key].name;end
    local namesText=table.concat(names,", ");
    if #namesText>60 then namesText="аккаунтов: "..#names.." (выберите из списка выше)";end
    f.accountsText:SetText(((s.verifiedAt and "Привязаны: ") or "Привязки не подтверждены: ")
        ..(#names>0 and namesText or "нет")..(s.verifiedAt and (" / "..date("%d.%m %H:%M",s.verifiedAt)) or ""));
    f.status:SetText(L.status or "Списки сохраняются при /reload или выходе из игры.");
    if L.job then f.refreshAccounts:Disable();f.scan:Disable();f.link:Disable();f.stop:Enable();
    else
        f.refreshAccounts:Enable();f.link:Enable();f.stop:Disable();
        if selected and s.verifiedAt and L.Current(s.selected) and not L.InGroup() and not L.Fighting() then f.scan:Enable();else f.scan:Disable();end
    end
end

L.frame=CreateFrame("Frame","UnBotLinkedAccountsEvents");
for _,event in ipairs({"CHAT_MSG_SYSTEM","PLAYER_LEAVING_WORLD","PLAYER_ENTERING_WORLD","ADDON_LOADED"}) do L.frame:RegisterEvent(event);end
L.frame:SetScript("OnEvent",function(self,event,message)
    if event=="CHAT_MSG_SYSTEM" then L.System(message);
    elseif event=="ADDON_LOADED" then L.InstallRedaction();
    elseif event=="PLAYER_LEAVING_WORLD" then if L.job then L.Stop("Запрос прерван выходом из мира.");end
    elseif event=="PLAYER_ENTERING_WORLD" then L.verified=false;L.opened=nil;L.Refresh();end
end);
L.frame:SetScript("OnUpdate",L.Update);
if hooksecurefunc then hooksecurefunc("SendChatMessage",function(message,channel)
    -- addaccount replies carry no login. Do not mix replies from overlapping local commands.
    if L.job and channel=="SAY" then
        local text=L.Clean(message):lower();
        if L.Clean(L.Redact(message)):lower()==L.job.command then return;end
        -- The main account's read-only roster has a different response header;
        -- it cannot mix linked-account names, unlike a second addaccount.
        if L.job.kind=="accounts" and text:match("^%.playerbots?%s+bot%s+list%s*$") then return;end
        if text:match("^%.playerbots?%s+bot%s+") or text:match("^%.playerbots?%s+account%s+") then
            L.Stop("Запрос остановлен: другая команда — "..L.Redact(text):sub(1,180)..". Сохранённые списки оставлены.");
        end
    end
end);end
L.InstallRedaction();
end

