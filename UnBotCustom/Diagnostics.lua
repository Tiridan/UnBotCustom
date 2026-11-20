UnBotDiagnostics = UnBotDiagnostics or {
	bots = {},
	botName = nil,
	states = {},
	pendingQuery = nil,
	frame = nil,
	menuFrame = nil,
};

UnBotDiagnostics.strategies = UnBotDiagnostics.strategies or {
	{
		key = "debug spell",
		label = "Ошибки заклинаний (debug spell)",
		hint = "Показывает Spell ID, код ошибки, цель и режим обмена при неудачном касте.",
	},
	{
		key = "debug move",
		label = "Движение и путь (debug move)",
		hint = "Расширяет сообщения о движении и построении пути. Может писать много строк.",
	},
	{
		key = "debug rpg",
		label = "RPG-поведение (debug rpg)",
		hint = "Показывает решения свободного RPG-поведения бота.",
	},
	{
		key = "debug quest",
		label = "Квестовые решения (debug quest)",
		hint = "Показывает диагностические решения квестовой логики.",
	},
	{
		key = "debug",
		label = "Общий debug",
		hint = "Общий диагностический режим Playerbot. Включайте только для короткой проверки.",
	},
};

function UnBotDiagnostics.Message(text)
	if (UnBotSpecSummonMessage) then
		UnBotSpecSummonMessage(text);
	elseif (DEFAULT_CHAT_FRAME) then
		DEFAULT_CHAT_FRAME:AddMessage("|cff69ccf0[UnBot]|r "..tostring(text));
	end
end

function UnBotDiagnostics.Trim(text)
	return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""));
end

function UnBotDiagnostics.NameKey(name)
	name = UnBotDiagnostics.Trim(name);
	name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "");
	name = name:match("^([^-]+)") or name;
	return string.lower(name);
end

function UnBotDiagnostics.SameName(a, b)
	return UnBotDiagnostics.NameKey(a) ~= ""
		and UnBotDiagnostics.NameKey(a) == UnBotDiagnostics.NameKey(b);
end

function UnBotDiagnostics.SetStatus(text, red)
	local frame = UnBotDiagnostics.frame;
	if (not frame or not frame.statusText) then
		return;
	end
	frame.statusText:SetText(tostring(text or ""));
	if (red) then
		frame.statusText:SetTextColor(1, 0.3, 0.2);
	else
		frame.statusText:SetTextColor(0.35, 0.95, 1);
	end
end

function UnBotDiagnostics.BuildBotList()
	local state = UnBotDiagnostics;
	state.bots = {};
	if (UnBotWorldInteraction and UnBotWorldInteraction.BuildBotList) then
		UnBotWorldInteraction.BuildBotList();
		for _, name in ipairs(UnBotWorldInteraction.bots or {}) do
			table.insert(state.bots, name);
		end
	end
	table.sort(state.bots, function(a, b)
		return UnBotDiagnostics.NameKey(a) < UnBotDiagnostics.NameKey(b);
	end);
	return state.bots;
end

function UnBotDiagnostics.FindBot(name)
	for _, botName in ipairs(UnBotDiagnostics.bots or {}) do
		if (UnBotDiagnostics.SameName(botName, name)) then
			return botName;
		end
	end
	return nil;
end

function UnBotDiagnostics.RefreshChecks()
	local state = UnBotDiagnostics;
	local frame = state.frame;
	if (not frame) then
		return;
	end
	local botState = state.states[UnBotDiagnostics.NameKey(state.botName)];
	for _, check in ipairs(frame.strategyChecks or {}) do
		check:SetChecked(botState and botState.known and botState[check.strategyKey] == true);
	end
	if (not state.botName) then
		UnBotDiagnostics.SetStatus("В текущей группе нет доступного онлайн-бота.", true);
	elseif (botState and botState.known) then
		UnBotDiagnostics.SetStatus(
			"Состояние debug для "..state.botName..": прочитано через nc ? или задано командами этого окна.",
			false
		);
	else
		UnBotDiagnostics.SetStatus(
			"Состояние debug для "..state.botName.." неизвестно. Нажмите «Считать nc ?» перед изменением.",
			false
		);
	end
end

function UnBotDiagnostics.RefreshBotButton(preferTarget)
	local state = UnBotDiagnostics;
	UnBotDiagnostics.BuildBotList();
	local selected = UnBotDiagnostics.FindBot(state.botName);
	if (preferTarget and UnitName("target")) then
		selected = UnBotDiagnostics.FindBot(UnitName("target")) or selected;
	end
	state.botName = selected or state.bots[1];
	if (state.frame and state.frame.botButton) then
		state.frame.botButton:SetText(state.botName or "Нет онлайн-ботов");
	end
	UnBotDiagnostics.RefreshChecks();
end

function UnBotDiagnostics.SelectBot(name)
	UnBotDiagnostics.botName = UnBotDiagnostics.FindBot(name);
	UnBotDiagnostics.pendingQuery = nil;
	if (UnBotDiagnostics.frame and UnBotDiagnostics.frame.botButton) then
		UnBotDiagnostics.frame.botButton:SetText(UnBotDiagnostics.botName or "Нет онлайн-ботов");
	end
	UnBotDiagnostics.RefreshChecks();
end

function UnBotDiagnostics.OpenBotMenu(anchor)
	UnBotDiagnostics.RefreshBotButton(false);
	local menu = {};
	for _, botName in ipairs(UnBotDiagnostics.bots or {}) do
		local name = botName;
		table.insert(menu, {
			text = name,
			notCheckable = true,
			func = function() UnBotDiagnostics.SelectBot(name); end,
		});
	end
	if (#menu == 0) then
		table.insert(menu, { text = "Нет доступных онлайн-ботов", notCheckable = true, disabled = true });
	end
	EasyMenu(UnBotLocale.Menu(menu), UnBotDiagnostics.menuFrame, anchor, 0, 0, "MENU", 2);
end

function UnBotDiagnostics.SendStrategy(strategyKey, enabled)
	if UnBotDiagnostics.raid and UnBotDiagnostics.raid.current then UnBotDiagnostics.Message("Сначала остановите общий дебаг: /ubdiag stop.");return false;end
	UnBotDiagnostics.RefreshBotButton(false);
	local state = UnBotDiagnostics;
	local name = UnBotDiagnostics.FindBot(state.botName);
	if (not name) then
		UnBotDiagnostics.SetStatus("Выбранный бот больше не доступен онлайн.", true);
		UnBotDiagnostics.RefreshChecks();
		return false;
	end
	SendChatMessage("nc "..(enabled and "+" or "-")..strategyKey, "WHISPER", nil, name);
	local key = UnBotDiagnostics.NameKey(name);
	state.states[key] = state.states[key] or {};
	state.states[key].known = true;
	state.states[key][strategyKey] = enabled and true or false;
	UnBotDiagnostics.RefreshChecks();
	UnBotDiagnostics.SetStatus(
		name..": отправлено nc "..(enabled and "+" or "-")..strategyKey..".",
		false
	);
	return true;
end

function UnBotDiagnostics.QueryStrategies()
	if UnBotDiagnostics.raid and UnBotDiagnostics.raid.current then UnBotDiagnostics.Message("Сначала остановите общий дебаг: /ubdiag stop.");return false;end
	UnBotDiagnostics.RefreshBotButton(false);
	local state = UnBotDiagnostics;
	local name = UnBotDiagnostics.FindBot(state.botName);
	if (not name) then
		UnBotDiagnostics.SetStatus("Выберите доступного онлайн-бота.", true);
		return;
	end
	SendChatMessage("nc ?", "WHISPER", nil, name);
	state.pendingQuery = { name = name, deadline = GetTime() + 6 };
	UnBotDiagnostics.SetStatus(name..": отправлено nc ?, жду строку Strategies не более 6 секунд.", false);
end

function UnBotDiagnostics.DisableAllDebug()
	if UnBotDiagnostics.raid and UnBotDiagnostics.raid.current then UnBotDiagnostics.Message("Сначала остановите общий дебаг: /ubdiag stop.");return false;end
	UnBotDiagnostics.RefreshBotButton(false);
	local state = UnBotDiagnostics;
	local name = UnBotDiagnostics.FindBot(state.botName);
	if (not name) then
		UnBotDiagnostics.SetStatus("Выберите доступного онлайн-бота.", true);
		return;
	end
	SendChatMessage(
		"nc -debug,-debug move,-debug rpg,-debug spell,-debug quest",
		"WHISPER",
		nil,
		name
	);
	local key = UnBotDiagnostics.NameKey(name);
	state.states[key] = state.states[key] or {};
	state.states[key].known = true;
	for _, entry in ipairs(state.strategies) do
		state.states[key][entry.key] = false;
	end
	UnBotDiagnostics.RefreshChecks();
	UnBotDiagnostics.SetStatus(name..": отправлена одна команда отключения всех пяти debug-стратегий.", false);
end

function UnBotDiagnostics.ParseStrategyReply(message, sender)
	local state = UnBotDiagnostics;
	local pending = state.pendingQuery;
	if (not pending or not UnBotDiagnostics.SameName(sender, pending.name)) then
		return false;
	end
	local text = tostring(message or "");
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "");
	local list = text:match("^[Ss]trategies:%s*(.*)$");
	if (list == nil) then
		return false;
	end
	local enabled = {};
	for token in string.gmatch(list, "([^,]+)") do
		enabled[UnBotDiagnostics.Trim(token)] = true;
	end
	local key = UnBotDiagnostics.NameKey(pending.name);
	state.states[key] = state.states[key] or {};
	state.states[key].known = true;
	for _, entry in ipairs(state.strategies) do
		state.states[key][entry.key] = enabled[entry.key] == true;
	end
	state.pendingQuery = nil;
	UnBotDiagnostics.RefreshChecks();
	UnBotDiagnostics.SetStatus(pending.name..": фактические небоевые стратегии прочитаны; галочки обновлены.", false);
	return true;
end

function UnBotDiagnostics.SetCombatLog(enabled)
	UnBotSquadConfig = UnBotSquadConfig or {};
	enabled = enabled and true or false;
	UnBotSquadConfig.recordFullCombatLog = enabled;
	if (UnBotSquadCombatLogApply and not UnBotSquadCombatLogApply(enabled, true) and enabled) then
		UnBotSquadConfig.recordFullCombatLog = false;
	end
	if (UnBotSquadBuilder and UnBotSquadBuilder.combatLogCheck) then
		UnBotSquadBuilder.combatLogCheck:SetChecked(UnBotSquadConfig.recordFullCombatLog == true);
	end
	UnBotDiagnostics.RefreshLogControls();
end

function UnBotDiagnostics.SetBuffLog(enabled)
	if (UnBotBuffDiagnosticSetEnabled) then
		UnBotBuffDiagnosticSetEnabled(enabled, true);
	else
		UnBotSquadConfig = UnBotSquadConfig or {};
		UnBotSquadConfig.buffDiagnosticEnabled = enabled and true or false;
	end
	UnBotDiagnostics.RefreshLogControls();
end

function UnBotDiagnostics.RefreshLogControls()
	local frame = UnBotDiagnostics.frame;
	if (not frame) then
		return;
	end
	UnBotSquadConfig = UnBotSquadConfig or {};
	frame.combatLogCheck:SetChecked(UnBotSquadConfig.recordFullCombatLog == true);
	frame.buffLogCheck:SetChecked(UnBotSquadConfig.buffDiagnosticEnabled == true);
	local diagnostic = UnBotSquadConfig.lastBuffDiagnostic;
	if (type(diagnostic) == "table") then
		frame.logStatusText:SetText(
			"Последний бафф-лог: "..tostring(diagnostic.mode or "режим не указан")
			..", записей "..tostring(#(diagnostic.entries or {}))
			..(diagnostic.active and " (сейчас собирается)" or " (завершён)")
		);
	else
		frame.logStatusText:SetText("Последний расширенный бафф-лог ещё не сохранён.");
	end
end

function UnBotDiagnostics.CreateCheck(parent, y, entry)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate");
	check:SetWidth(24);
	check:SetHeight(24);
	check:SetPoint("TOPLEFT", parent, "TOPLEFT", 28, y);
	check.strategyKey = entry.key;
	check.labelText = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	check.labelText:SetPoint("LEFT", check, "RIGHT", 3, 0);
	check.labelText:SetText(entry.label);
	check:SetScript("OnClick", function(self)
		if (not UnBotDiagnostics.SendStrategy(self.strategyKey, self:GetChecked() and true or false)) then
			UnBotDiagnostics.RefreshChecks();
		end
	end);
	check:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:AddLine(entry.label, 1, 0.82, 0);
		GameTooltip:AddLine(entry.hint, 1, 1, 1, true);
		GameTooltip:AddLine("Команда отправляется только выбранному онлайн-боту.", 0.35, 0.95, 1, true);
		GameTooltip:Show();
	end);
	check:SetScript("OnLeave", function() GameTooltip:Hide(); end);
	return check;
end

function UnBotDiagnostics.CreateFrame()
	if (UnBotDiagnostics.frame) then
		return UnBotDiagnostics.frame;
	end
	local frame = CreateFrame("Frame", "UnBotDiagnosticsFrame", UIParent);
	frame:SetWidth(650);
	frame:SetHeight(585);
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20);
	frame:SetFrameStrata("DIALOG");
	frame:SetClampedToScreen(true);
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

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton");
	close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5);

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	title:SetPoint("TOP", frame, "TOP", 0, -18);
	title:SetText("Диагностика UnBot");

	local intro = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	intro:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -50);
	intro:SetWidth(590);
	intro:SetJustifyH("LEFT");
	intro:SetText("Окно ничего не включает само. Выберите онлайн-бота, вручную прочитайте nc ?, затем меняйте только нужные debug-стратегии.");

	local botLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	botLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -86);
	botLabel:SetText("Бот текущей группы:");

	frame.botButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
	frame.botButton:SetWidth(245);
	frame.botButton:SetHeight(24);
	frame.botButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 165, -80);
	frame.botButton:SetText("Нет онлайн-ботов");
	frame.botButton:SetScript("OnClick", function(self) UnBotDiagnostics.OpenBotMenu(self); end);

	frame.refreshButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
	frame.refreshButton:SetWidth(190);
	frame.refreshButton:SetHeight(24);
	frame.refreshButton:SetPoint("LEFT", frame.botButton, "RIGHT", 8, 0);
	frame.refreshButton:SetText("Обновить список");
	frame.refreshButton:SetScript("OnClick", function() UnBotDiagnostics.RefreshBotButton(true); end);

	local debugHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	debugHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -125);
	debugHeader:SetText("Debug-стратегии выбранного бота");

	frame.strategyChecks = {};
	local y = -145;
	for _, entry in ipairs(UnBotDiagnostics.strategies) do
		table.insert(frame.strategyChecks, UnBotDiagnostics.CreateCheck(frame, y, entry));
		y = y - 32;
	end

	frame.queryButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
	frame.queryButton:SetWidth(190);
	frame.queryButton:SetHeight(25);
	frame.queryButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -315);
	frame.queryButton:SetText("Считать nc ?");
	frame.queryButton:SetScript("OnClick", function() UnBotDiagnostics.QueryStrategies(); end);

	frame.disableButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
	frame.disableButton:SetWidth(245);
	frame.disableButton:SetHeight(25);
	frame.disableButton:SetPoint("LEFT", frame.queryButton, "RIGHT", 10, 0);
	frame.disableButton:SetText("Выключить весь debug у бота");
	frame.disableButton:SetScript("OnClick", function() UnBotDiagnostics.DisableAllDebug(); end);

	frame.statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	frame.statusText:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -350);
	frame.statusText:SetWidth(590);
	frame.statusText:SetHeight(38);
	frame.statusText:SetJustifyH("LEFT");
	frame.statusText:SetJustifyV("TOP");

	local logHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	logHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -395);
	logHeader:SetText("Общие журналы UnBot");

	frame.combatLogCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate");
	frame.combatLogCheck:SetWidth(24);
	frame.combatLogCheck:SetHeight(24);
	frame.combatLogCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -414);
	frame.combatLogCheck.labelText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	frame.combatLogCheck.labelText:SetPoint("LEFT", frame.combatLogCheck, "RIGHT", 3, 0);
	frame.combatLogCheck.labelText:SetText("Писать полный combat log в Logs\\WoWCombatLog.txt");
	frame.combatLogCheck:SetScript("OnClick", function(self)
		UnBotDiagnostics.SetCombatLog(self:GetChecked() and true or false);
	end);

	frame.buffLogCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate");
	frame.buffLogCheck:SetWidth(24);
	frame.buffLogCheck:SetHeight(24);
	frame.buffLogCheck:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -446);
	frame.buffLogCheck.labelText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	frame.buffLogCheck.labelText:SetPoint("LEFT", frame.buffLogCheck, "RIGHT", 3, 0);
	frame.buffLogCheck.labelText:SetText("Собирать расширенный лог каждого бафф-цикла");
	frame.buffLogCheck:SetScript("OnClick", function(self)
		UnBotDiagnostics.SetBuffLog(self:GetChecked() and true or false);
	end);

	frame.logStatusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	frame.logStatusText:SetPoint("TOPLEFT", frame, "TOPLEFT", 31, -480);
	frame.logStatusText:SetWidth(585);
	frame.logStatusText:SetJustifyH("LEFT");

 frame.raidButton=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate");
 frame.raidButton:SetSize(280,25);frame.raidButton:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",28,25);
 frame.raidButton:SetText("Дебаг движения всего рейда");
 frame.raidButton:SetScript("OnClick",function() UnBotDiagnostics.RaidStart();end);
 frame.raidStop=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate");
 frame.raidStop:SetSize(150,25);frame.raidStop:SetPoint("LEFT",frame.raidButton,"RIGHT",10,0);
 frame.raidStop:SetText("Стоп записи");
 frame.raidStop:SetScript("OnClick",function() UnBotDiagnostics.RaidFinish("stopped");end);

	frame:SetScript("OnShow", function()
		UnBotDiagnostics.RefreshBotButton(true);
		UnBotDiagnostics.RefreshLogControls();
	end);
	frame:SetScript("OnHide", function()
		UnBotDiagnostics.pendingQuery = nil;
	end);

	frame:Hide();
	UnBotDiagnostics.frame = frame;
	UnBotDiagnostics.menuFrame = CreateFrame("Frame", "UnBotDiagnosticsMenuFrame", frame, "UIDropDownMenuTemplate");
	table.insert(UISpecialFrames, "UnBotDiagnosticsFrame");
	return frame;
end

function UnBotDiagnostics.Toggle()
	local frame = UnBotDiagnostics.CreateFrame();
	if (frame:IsShown()) then
		frame:Hide();
	else
		frame:Show();
	end
end

UnBotDiagnostics.eventFrame = UnBotDiagnostics.eventFrame
	or CreateFrame("Frame", "UnBotDiagnosticsEventFrame");
UnBotDiagnostics.eventFrame:RegisterEvent("CHAT_MSG_WHISPER");
UnBotDiagnostics.eventFrame:RegisterEvent("PLAYER_LOGIN");
UnBotDiagnostics.eventFrame:RegisterEvent("PLAYER_LOGOUT");
UnBotDiagnostics.eventFrame:RegisterEvent("PLAYER_LEAVING_WORLD");
UnBotDiagnostics.eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED");
UnBotDiagnostics.eventFrame:RegisterEvent("RAID_ROSTER_UPDATE");
UnBotDiagnostics.eventFrame:SetScript("OnEvent", function(self, event, message, sender)
	if event=="PLAYER_LEAVING_WORLD" then
		UnBotDiagnostics.RaidFinish("zone_changed");
	elseif event=="PLAYER_LOGOUT" then
		local r=UnBotDiagnostics.raid.current;if r then r.status=event;UnBotDiagnostics.raid.current=nil;UnBotDiagnostics.raid.pending=nil;end
	elseif event=="PLAYER_LOGIN" then
		local log=UnBotSquadConfig and UnBotSquadConfig.raidMovementDebug and UnBotSquadConfig.raidMovementDebug.last;
		if log and log.status=="recording" then log.status="interrupted";end
		UnBotDiagnostics.RaidRecover();
	elseif (event == "CHAT_MSG_WHISPER") then
		UnBotDiagnostics.ParseStrategyReply(message, sender);
		UnBotDiagnostics.RaidReply(message,sender);
	elseif (UnBotDiagnostics.frame and UnBotDiagnostics.frame:IsShown()) then
		UnBotDiagnostics.RefreshBotButton(false);
	end
end);
UnBotDiagnostics.eventFrame:SetScript("OnUpdate", function(self)
	UnBotDiagnostics.RaidTick();
	local pending = UnBotDiagnostics.pendingQuery;
	if (pending and GetTime() >= (pending.deadline or 0)) then
		UnBotDiagnostics.pendingQuery = nil;
		UnBotDiagnostics.SetStatus(
			pending.name..": строка Strategies не пришла за 6 секунд. Состояние галочек не изменено.",
			true
		);
	end
end);

SLASH_UNBOTDIAGNOSTICS1 = "/ubdiag";
SLASH_UNBOTDIAGNOSTICS2 = "/ubdebug";

-- Explicit roster survey, with optional temporary server debug. Never sends movement commands.
UnBotDiagnostics.raid = {};

function UnBotDiagnostics.RaidRecoveryKey(name,owner)
 return (owner or (tostring(GetRealmName())..":"..tostring(UnitName("player")))).."|"..UnBotDiagnostics.NameKey(name);
end
function UnBotDiagnostics.RaidConfig()
 UnBotSquadConfig=UnBotSquadConfig or {};UnBotSquadConfig.raidMovementDebug=UnBotSquadConfig.raidMovementDebug or {};
 local c=UnBotSquadConfig.raidMovementDebug;c.debugRecovery=c.debugRecovery or {};return c;
end
function UnBotDiagnostics.RaidCheck()
 local b=UnBotSquadBuilder;
 if b and b.raidDebugCheck then b.raidDebugCheck:SetChecked(UnBotDiagnostics.raid.current and not UnBotDiagnostics.raid.current.cleanupReason and true or false);end
 if b and b.pveFallbackCheck and b.pveFallbackCheck.text then b.pveFallbackCheck:SetHitRectInsets(0,-232,0,0);b.pveFallbackCheck.text:SetWidth(232);b.pveFallbackCheck.text:SetText("PvP: добирать спеки из PvE");end
end
function UnBotDiagnostics.RaidCreateCheck(window)
 local d=UnBotDiagnostics;local check=CreateFrame("CheckButton",nil,window,"UICheckButtonTemplate");
 check:SetWidth(24);check:SetHeight(24);check:SetPoint("BOTTOMLEFT",window,"BOTTOMLEFT",284,106);
 check.text=check:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");
 check.text:SetPoint("LEFT",check,"RIGHT",-2,0);check.text:SetWidth(155);check.text:SetJustifyH("LEFT");
 check.text:SetText("Писать дебаг всех ботов");check:SetHitRectInsets(0,-155,0,0);
 check:SetScript("OnClick",function(self) if self:GetChecked() then d.RaidStart(true);else d.RaidFinish("stopped");end;d.RaidCheck();end);
 check:SetScript("OnEnter",function(self)
  GameTooltip:SetOwner(self,"ANCHOR_TOP");GameTooltip:AddLine("Дебаг движения текущего состава",0,0.7,0.7,1);
  GameTooltip:AddLine("Снимки co/nc, координаты, цели и команды аддонов. Временно включает nc debug и debug move, чтобы получить решения ИИ.",1,1,1,true);
  GameTooltip:AddLine("После опроса — 60 секунд записи. Снятие галочки останавливает запись. Снимаются только добавленные этим тестом debug-ключи; тактики движения и личные профили не меняются.",1,1,1,true);
  GameTooltip:AddLine("После завершения выполните /reload для сохранения. На reload запись не возобновляется; оставшийся временный debug снимается одной попыткой.",0,1,0,true);GameTooltip:Show();
 end);check:SetScript("OnLeave",function() GameTooltip:Hide();end);return check;
end
function UnBotDiagnostics.RaidCleanupTick()
 local d=UnBotDiagnostics;local r=d.raid.current;local now=GetTime();if not r then return;end
 local c=d.RaidConfig();local p=d.raid.pending;
 if p then
  if now<p.deadline then return;end
  local b=r.bots[p.index];b.cleanup="no_reply";d.raid.pending=nil;r.cleanupIndex=r.cleanupIndex+1;
 end
 if now<r.nextSend then return;end
 local b=r.bots[r.cleanupIndex];
 if not b then d.RaidFinish(r.cleanupReason,true);return;end
 local key=d.RaidRecoveryKey(b.name,r.owner);local recovery=c.debugRecovery[key];
 if not recovery or recovery.owner~=r.owner then r.cleanupIndex=r.cleanupIndex+1;return;end
 local u=d.RaidUnit(b.name,recovery.guid);
 if not u or not UnitIsConnected(u) then b.cleanup="unavailable";r.cleanupIndex=r.cleanupIndex+1;return;end
 local parts={};for _,k in ipairs(recovery.keys) do parts[#parts+1]="-"..k;end;parts[#parts+1]="?";
 d.raid.pending={index=r.cleanupIndex,section="cleanup",deadline=now+6};r.nextSend=now+1.2;
 SendChatMessage("nc "..table.concat(parts,","),"WHISPER",nil,b.name);
end
function UnBotDiagnostics.RaidRecover()
 local d=UnBotDiagnostics;if d.raid.current then return;end
 local c=d.RaidConfig();local owner=tostring(GetRealmName())..":"..tostring(UnitName("player"));local bots={};
 for _,v in pairs(c.debugRecovery) do if v.owner==owner then bots[#bots+1]={name=v.name,guid=v.guid,results={},samples={}};end end
 if #bots==0 then return;end
 local r={schema=1,owner=owner,clock=GetTime(),startedAt=time(),status="cleanup_after_reload",bots=bots,events={},dropped=0,
  cleanupReason="cleanup_after_reload",cleanupIndex=1,nextSend=GetTime()+2};
 c.lastRecovery=r;d.raid.current=r;d.Message("Дебаг рейда: одна попытка снять временный debug после /reload; запись не возобновляется.");
end

function UnBotDiagnostics.RaidUnit(name, guid)
 for i=1,(GetNumRaidMembers()>0 and GetNumRaidMembers() or GetNumPartyMembers()) do
  local u=(GetNumRaidMembers()>0 and "raid" or "party")..i;
  if UnBotDiagnostics.SameName(UnitName(u),name) and (not guid or UnitGUID(u)==guid) then return u;end
 end
end
function UnBotDiagnostics.RaidBusy()
 local g=UnBotGuardPosts;
 if g and g.Busy and g:Busy() then return true;end
 if g and (g.batch or g.cleanup or (g.op and g.op.phase~="door_arrival")) then return true;end
 return UnBotDiagnostics.pendingQuery~=nil;
end
function UnBotDiagnostics.RaidEvent(kind, text, name, extra)
 local r=UnBotDiagnostics.raid.current;if not r then return;end
 if #r.events>=2000 then r.dropped=r.dropped+1;return;end
 r.events[#r.events+1]={t=GetTime()-r.clock,kind=kind,name=name,text=UnBotSummonLog.Text(text,1500),extra=extra};
end
function UnBotDiagnostics.RaidFinish(reason, finalized)
 local d=UnBotDiagnostics;local r=d.raid.current;if not r then return;end
 if r.cleanupReason and not finalized then return;end
 if not finalized then
  local recovery=d.RaidConfig().debugRecovery;local needs=false;
  for _,b in ipairs(r.bots) do local item=recovery[d.RaidRecoveryKey(b.name,r.owner)];if item and item.owner==r.owner then needs=true;end end
  if needs then r.cleanupReason=reason;r.cleanupIndex=1;d.raid.pending=nil;r.nextSend=math.max(r.nextSend or 0,GetTime()+1.2);d.RaidCheck();d.Message("Дебаг рейда: снимаю только временно добавленные debug-ключи.");return;end
 end
 r.status=reason;r.finishedAt=time();r.duration=GetTime()-r.clock;
 if d.raid.pending then
  local p=d.raid.pending;r.bots[p.index].results[p.section]={status=reason};
 end
 d.raid.current=nil;d.raid.pending=nil;d.RaidCheck();
 local complete=0;for _,b in ipairs(r.bots) do if b.results.co and b.results.co.status=="ok" and b.results.nc and b.results.nc.status=="ok" then complete=complete+1;end end
 d.Message("Дебаг рейда: завершён ("..reason.."); co/nc "..complete.."/"..#r.bots..". Для сохранения журнала выполните /reload.");
 local remaining=0;for _,v in pairs(d.RaidConfig().debugRecovery) do if v.owner==r.owner then remaining=remaining+1;end end
 if remaining>0 then d.Message("Не подтверждено снятие временного debug у "..remaining.." ботов; /ubdiag cleanup — одна попытка повторить снятие.");end
 d.SetStatus("Дебаг рейда: "..reason..", стратегии "..complete.."/"..#r.bots.."; журнал готов к /reload.",false);
end
function UnBotDiagnostics.RaidStart(trace)
 local d=UnBotDiagnostics;if d.raid.current then d.Message("Дебаг рейда уже идёт. /ubdiag stop — остановить запись.");return;end
 if d.RaidBusy() then d.Message("Сначала завершите текущую проверку/подготовку ботов. Дебаг не прерывает её.");return;end
 local recovery=d.RaidConfig().debugRecovery;
 for _,v in pairs(recovery) do if v.owner==tostring(GetRealmName())..":"..tostring(UnitName("player")) then d.Message("Остался временный debug без подтверждения снятия. /ubdiag cleanup — одна повторная попытка.");return;end end
 local bots={};d.BuildBotList();
 for _,name in ipairs(d.bots) do
  local u=d.RaidUnit(name);if u then bots[#bots+1]={name=name,guid=UnitGUID(u),results={},samples={}};end
 end
 if #bots==0 then d.Message("В группе нет известных онлайн-ботов для диагностики.");return;end
 UnBotSquadConfig=UnBotSquadConfig or {};UnBotSquadConfig.raidMovementDebug=UnBotSquadConfig.raidMovementDebug or {};
 local r={schema=1,version="6.39.38",startedAt=time(),clock=GetTime(),owner=tostring(GetRealmName())..":"..tostring(UnitName("player")),
  trace=trace and true or false,zone=GetRealZoneText(),status="recording",bots=bots,events={},dropped=0,index=1,stage=1,nextSend=GetTime(),deadline=GetTime()+600,nextSample=0};
 UnBotSquadConfig.raidMovementDebug.last=r;d.raid.current=r;d.RaidCheck();
 if r.trace then d.Message("Временно включаю nc debug/debug move только у ботов этого теста; после записи сниму добавленные ключи.");end
 d.Message("Дебаг рейда: "..#bots.." ботов; читаю co/nc/позицию и записываю движение, цели, команды аддонов. Тактики движения не меняются.");
end
function UnBotDiagnostics.RaidSample()
 local d=UnBotDiagnostics;local r=d.raid.current;local now=GetTime();if not r or now<r.nextSample then return;end
 r.nextSample=now+1;
 for _,b in ipairs(r.bots) do
  if #b.samples<120 then
   local u=d.RaidUnit(b.name,b.guid);local s={t=now-r.clock,available=u and UnitIsConnected(u) and true or false};
   if s.available then
    local x,y=GetPlayerMapPosition(u);s.x=x;s.y=y;s.map=GetMapInfo();s.floor=GetCurrentMapDungeonLevel();
    s.combat=UnitAffectingCombat(u) and true or false;s.dead=UnitIsDeadOrGhost(u) and true or false;
    s.target=UnitName(u.."target");s.targetGUID=UnitGUID(u.."target");s.moving=GetUnitSpeed and GetUnitSpeed(u) or nil;
   end
   b.samples[#b.samples+1]=s;
  end
 end
end
function UnBotDiagnostics.RaidReply(message,sender)
 local d=UnBotDiagnostics;local r=d.raid.current;if not r then return;end
 local member;for _,b in ipairs(r.bots) do if d.SameName(sender,b.name) then member=b;break end end
 if not member then return;end
 d.RaidEvent("reply",message,member.name);
 local p=d.raid.pending;if not p or not d.SameName(sender,r.bots[p.index].name) then return;end
 local text=d.Trim(tostring(message):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""));local value;
 if p.section=="co" or p.section=="nc" or p.section=="debug" or p.section=="cleanup" then
  local lower=text:lower();local prefix,list=lower:match("^(.-)strategies:%s*(.*)$");
  if list and (prefix=="" or (p.section=="co" and prefix=="combat ") or ((p.section=="nc" or p.section=="debug" or p.section=="cleanup") and prefix=="non-combat ")) then
   value={};for token in list:gmatch("[^,]+") do value[d.Trim(token)]=true;end
  end
 elseif p.section=="world" then
  local a,b,c,m,o=text:match("^([%d%.%-]+)%s+([%d%.%-]+)%s+([%d%.%-]+)%s+(%d+)%s+([%d%.%-]+)");
  if tonumber(a) and tonumber(b) and tonumber(c) and tonumber(m) and tonumber(o) then value={x=tonumber(a),y=tonumber(b),z=tonumber(c),map=tonumber(m),orientation=tonumber(o)};end
 end
 local denied=text:lower():find("unknown command",1,true) or text:lower():find("invalid command",1,true);
 if value or denied then
  if p.section=="cleanup" then
   local key=d.RaidRecoveryKey(member.name,r.owner);local rec=d.RaidConfig().debugRecovery[key];local clean=value~=nil;
   for _,k in ipairs(rec and rec.keys or {}) do if value and value[k] then clean=false;end end
   member.cleanup=clean and "ok" or "refused_or_still_enabled";
   if clean then d.RaidConfig().debugRecovery[key]=nil;end
   d.raid.pending=nil;r.cleanupIndex=r.cleanupIndex+1;return;
  end
  member.results[p.section]={status=value and "ok" or "refused",value=value,raw=text,t=GetTime()-r.clock};
  d.raid.pending=nil;r.stage=r.stage+1;
 end
end
function UnBotDiagnostics.RaidTick()
 local d=UnBotDiagnostics;local r=d.raid.current;if not r then return;end
 local now=GetTime();if r.cleanupReason then d.RaidCleanupTick();return;end
 if now>=r.deadline then d.RaidFinish("timeout");return;end
 if d.RaidBusy() then d.RaidFinish("other_operation");return;end
 d.RaidSample();
 local p=d.raid.pending;
 if p and now>=p.deadline then
  r.bots[p.index].results[p.section]={status="no_reply"};d.raid.pending=nil;r.stage=r.stage+1;
 elseif p then return;end
 if now<r.nextSend then return;end
 if r.stage>4 then r.index=r.index+1;r.stage=1;end
 local b=r.bots[r.index];
 if not b then
  if not r.observeUntil then r.observeUntil=now+(r.trace and 60 or 20);d.Message("Дебаг рейда: опрос закончен; записываю движение и команды ещё "..(r.trace and 60 or 20).." секунд.");end
  if now>=r.observeUntil then d.RaidFinish("complete");end
  return;
 end
 local u=d.RaidUnit(b.name,b.guid);
 if not u or not UnitIsConnected(u) or UnitIsDeadOrGhost(u) then
  b.skipped="left_offline_dead_or_changed_guid";r.index=r.index+1;r.stage=1;return;
 end
 local section=({"co","nc","debug","world"})[r.stage];local command=({"co ?","nc ?",false,"cdebug position"})[r.stage];
 if section=="debug" then
  local actual=b.results.nc;local keys={};
  if r.trace and actual and actual.status=="ok" then
   for _,key in ipairs({"debug","debug move"}) do if not actual.value[key] then keys[#keys+1]=key;end end
  end
  if #keys==0 then r.stage=r.stage+1;return;end
  local parts={};for _,key in ipairs(keys) do parts[#parts+1]="+"..key;end;parts[#parts+1]="?";command="nc "..table.concat(parts,",");
  d.RaidConfig().debugRecovery[d.RaidRecoveryKey(b.name,r.owner)]={name=b.name,guid=b.guid,owner=r.owner,keys=keys};
 end
 d.raid.pending={index=r.index,section=section,deadline=now+6};r.nextSend=now+1.2;
 d.RaidEvent("query",command,b.name);SendChatMessage(command,"WHISPER",nil,b.name);
 d.SetStatus("Дебаг рейда: "..r.index.."/"..#r.bots..", "..b.name.." — "..command,false);
end
function UnBotDiagnostics.RaidCommand(text,channel,language,target)
 local d=UnBotDiagnostics;local r=d.raid.current;if not r then return;end
 if channel=="WHISPER" then
  local found=false;for _,b in ipairs(r.bots) do if d.SameName(target,b.name) then found=true;break end end
  if not found then return;end
 elseif channel~="PARTY" and channel~="RAID" and channel~="SAY" then return;end
 local stack=debugstack and debugstack(3,5,0) or "";
 d.RaidEvent("client_command",text,target,{channel=channel,stack=UnBotSummonLog.Text(stack,1400)});
end
if hooksecurefunc then hooksecurefunc("SendChatMessage",UnBotDiagnostics.RaidCommand);end

SlashCmdList["UNBOTDIAGNOSTICS"] = function(text)
 local arg=UnBotDiagnostics.Trim(text):lower();
 if arg=="raid" or arg=="all" then UnBotDiagnostics.RaidStart();
 elseif arg=="trace" then UnBotDiagnostics.RaidStart(true);
 elseif arg=="cleanup" then UnBotDiagnostics.RaidRecover();
 elseif arg=="stop" then UnBotDiagnostics.RaidFinish("stopped");
 else UnBotDiagnostics.Toggle();end
end

-- Squad diagnostics. Uses the existing load path (also works after /reload).
-- Passive hooks never replace WoW API functions or send diagnostic chat traffic.
UnBotSummonLog = UnBotSummonLog or {};
UnBotSummonLog.maxEvents = 3000;
UnBotSummonLog.maxBytes = 2 * 1024 * 1024;
UnBotSummonLog.maxSeconds = 1800;

function UnBotSummonLog.Text(value, limit)
	local text = tostring(value or "");
	limit = limit or 1024;
	if (#text > limit) then
		-- Do not leave a partial UTF-8 character in SavedVariables.
		local cut = limit;
		while (cut > 0 and (text:byte(cut + 1) or 0) >= 128
			and (text:byte(cut + 1) or 0) < 192) do cut = cut - 1; end
		return text:sub(1, cut).." [truncated]";
	end
	return text;
end

function UnBotSummonLog.Safe(method, ...)
	local ok, err = pcall(UnBotSummonLog[method], ...);
	if (not ok) then
		-- A diagnostic failure must not interrupt a summon or a protected API hook.
		local log = UnBotSummonLog.current;
		if (log) then
			log.loggerError = UnBotSummonLog.Text(err);
			log.status = "logger_error";
		end
		UnBotSummonLog.current = nil;
		if (UnBotSummonLog.ownsChat and LoggingChat) then pcall(LoggingChat, false); end
		UnBotSummonLog.ownsChat = nil;
	end
	return ok;
end

function UnBotSummonLog.Plan(source)
	local plan = {pve={},pvp={},pveCount=0,pvpCount=0};
	local key = tostring(GetRealmName() or "").."|"..tostring(UnitName("player") or "");
	local pvp = UnBotSquadConfig.pvpSquadsByCharacter and UnBotSquadConfig.pvpSquadsByCharacter[key];
	plan.allowPVEFallback = not pvp or pvp.allowPVEFallback~=false;
	for _, mode in ipairs({"pve","pvp"}) do
		local slots = mode == "pve" and UnBotSquadConfig.slots or (pvp and pvp.slots);
		for i, slot in ipairs(slots or {}) do
			if (i > 40) then break end
			local count = slot.reserveOnly and 0 or math.max(0,math.min(39,tonumber(slot.count) or 1));
			table.insert(plan[mode], {className=UnBotSummonLog.Text(slot.className,64),
				specKey=UnBotSummonLog.Text(slot.specKey,64),count=count,
				accountAltName=slot.accountAltName and UnBotSummonLog.Text(slot.accountAltName,128),
				reserveOnly=slot.reserveOnly and true or false,mode=mode});
			plan[mode.."Count"] = plan[mode.."Count"] + count;
		end
	end
	plan.expectedPVE = source ~= "pvp" and source ~= "pvp_only";
	plan.expectedPVP = source == "pvp" or source == "pvp_only"
		or (plan.pvpCount > 0 and UnBotSquadSummon and UnBotSquadSummon.active) or false;
	if (source == "enabled_mid_run") then
		local state,_,builder = UnBotSummonLog.Context();
		plan.expectedPVE = (state and state.active and state.mode == "squad")
			or (builder and builder.postSummonSequence ~= nil) or false;
		plan.expectedPVP = (UnBotPVPSummon and UnBotPVPSummon.active)
			or plan.expectedPVP or false;
	end
	return plan;
end

function UnBotSummonLog.Result(stage, status, reason, requested, ready, skipped)
	local log = UnBotSummonLog.current;
	if (not log) then return; end
	log.results = log.results or {};
	log.results[stage] = {status=status,reason=UnBotSummonLog.Text(reason),requested=requested,
		ready=ready,skipped=skipped,atMs=math.floor((GetTime()-log.clockStart)*1000+.5)};
	UnBotSummonLog.Add("result", stage..":"..status, nil,
		"requested="..tostring(requested).." ready="..tostring(ready).." skipped="..tostring(skipped)
		.." reason="..tostring(reason or ""));
	if (stage=="pvp" and UnBotPVPSummon) then
		local native,converted=0,0;
		for _,entry in ipairs(UnBotPVPSummon.items or {}) do
			if (entry.ready) then if (entry.origin=="converted-pve") then converted=converted+1;
				elseif (entry.origin=="native-pvp" or entry.confirmation=="preserved") then native=native+1; end end
		end
		log.results[stage].nativeReady,log.results[stage].convertedFromPVE=native,converted;
	end
end

function UnBotSummonLog.CompletePVE(sequence)
	if (not sequence or not UnBotSummonLog.current) then return; end
	local requested,ready,skipped = 0,0,0;
	local state = UnBotSummonLog.Context();
	for _, slot in ipairs(state and state.squad and state.squad.slots or {}) do
		requested = requested + (tonumber(slot.need) or 0);
		ready = ready + (tonumber(slot.have) or 0);
		if (slot.skipped) then skipped = skipped + (tonumber(slot.need) or 0); end
	end
	if (UnBotSummonLog.current.source == "builder") then
		-- Arrival replacement excludes refused named positions from its new
		-- runtime request; keep the original plan's deficit visible.
		requested = math.max(requested,UnBotSummonLog.current.plan.pveCount);
	end
	if (requested == 0) then return; end -- no proof from an unrelated continuation
	UnBotSummonLog.Result("pve", ready == requested and "completed" or "partial",
		skipped > 0 and "opposite-faction slots skipped" or nil,requested,ready,skipped);
end

function UnBotSummonLog.Outcome(log)
	local results,plan = log.results or {},log.plan or {};
	for _, result in pairs(results) do if (result.status == "stopped") then return "stopped"; end end
	local stages,partial = 0,false;
	for _, stage in ipairs({"pve","pvp"}) do
		if (plan[stage == "pve" and "expectedPVE" or "expectedPVP"]) then
			local result = results[stage];
			if (not result or (result.status ~= "completed" and result.status ~= "partial")) then return "unknown"; end
			stages = stages + 1;
			partial = partial or result.status == "partial";
		end
	end
	return stages > 0 and (partial and "partial" or "completed") or "unknown";
end

function UnBotSummonLog.Inspect(stage, job, detail)
	local log = UnBotSummonLog.current;
	if (not log or not job) then return; end
	if (UnBotSummonLog.inspectJob ~= job) then
		log.inspectSerial = (log.inspectSerial or 0) + 1;
		UnBotSummonLog.inspectJob = job;
	end
	UnBotSummonLog.Remember(job.name);
	local owner = job.owner == UnBotPVPSummon and "pvp"
		or (UnBotPVPSquad and UnBotPVPSquad.transport and job.owner == UnBotPVPSquad.transport.PVEOwner and "pve") or "audit";
	UnBotSummonLog.Add(stage, detail, job.name,
		"inspectId="..tostring(log.inspectSerial).." owner="..owner
		.." class="..tostring(job.className).." level="..tostring(job.level).." build="..tostring(job.build)
		.." guid="..tostring(job.guid).." attempt="..tostring(job.attempts).." summons="..tostring(job.summons));
	if (stage == "inspect_finish" or stage == "inspect_cancel") then UnBotSummonLog.inspectJob = nil; end
end

function UnBotSummonLog.Wait(owner, reason, target, kind)
	local log = UnBotSummonLog.current;
	if (not log) then return; end
	log.waitStates = log.waitStates or {};
	local old,now = log.waitStates[owner],GetTime();
	if (old and old.reason == reason and old.target == target and old.kind == kind) then return; end
	log.performance = log.performance or {waitMs={},operationCounts={}};
	if (old) then
		local elapsed = math.max(0,math.floor((now-old.at)*1000+.5));
		local key = owner..":"..old.reason;
		log.performance.waitMs[key] = (log.performance.waitMs[key] or 0) + elapsed;
		UnBotSummonLog.Add("wait_end",owner..":"..old.reason,old.target,"kind="..tostring(old.kind).." elapsedMs="..elapsed);
		log.waitStates[owner] = nil;
	end
	if (reason) then
		log.waitStates[owner] = {reason=reason,target=target,kind=kind,at=now};
		UnBotSummonLog.Add("wait_begin",owner..":"..reason,target,"kind="..tostring(kind));
	end
end

function UnBotSummonLog.Operation(stage, owner, op, detail)
	local log = UnBotSummonLog.current;
	if (not log or not op) then return; end
	log.performance = log.performance or {waitMs={},operationCounts={}};
	if (stage == "op_send") then
		local key = owner..":"..op.kind;
		log.performance.operationCounts[key] = (log.performance.operationCounts[key] or 0) + 1;
	end
	UnBotSummonLog.Add(stage,owner..":"..op.kind,op.entry and op.entry.name,
		"opId="..tostring(op.id).." attempt="..tostring(op.attempts)
		.." queuedMs="..math.floor((GetTime()-(op.createdAt or GetTime()))*1000+.5)
		.." sinceSendMs="..tostring(op.sentAt and math.floor((GetTime()-op.sentAt)*1000+.5))
		.." "..tostring(detail or ""));
end

function UnBotSummonLog.Add(kind, text, target, detail)
	local log = UnBotSummonLog.current;
	if (not log) then return; end
	local now = GetTime();
	local entry = {
		t = math.floor((now - log.clockStart) * 1000 + 0.5),
		kind = UnBotSummonLog.Text(kind, 64),
		text = UnBotSummonLog.Text(text, kind == "roster" and 8192 or 2048),
		target = UnBotSummonLog.Text(target, 128),
		detail = UnBotSummonLog.Text(detail, 1024),
	};
	log.serial = log.serial + 1;
	entry.seq = log.serial;
	entry.bytes = #entry.kind + #entry.text + #entry.target + #entry.detail + 128;
	-- Ring retains the LAST events before a disconnect, not just the beginning.
	while (log.count > 0 and (log.count >= UnBotSummonLog.maxEvents
		or log.bytes + entry.bytes > UnBotSummonLog.maxBytes)) do
		local old = log.events[log.first];
		log.bytes = log.bytes - old.bytes;
		log.events[log.first] = nil;
		log.first = log.first % UnBotSummonLog.maxEvents + 1;
		log.count = log.count - 1;
		log.dropped = log.dropped + 1;
	end
	local index = (log.first + log.count - 1) % UnBotSummonLog.maxEvents + 1;
	log.events[index] = entry;
	log.count = log.count + 1;
	log.bytes = log.bytes + entry.bytes;
	log.lastEventMs = entry.t;
end

function UnBotSummonLog.State()
	local s, check, builder, gate, buff, reserve = UnBotSummonLog.Context();
	s, check, builder, gate, buff, reserve = s or {}, check or {}, builder or {},
		gate or {}, buff or {}, reserve or {};
	local parts = {};
	for _, key in ipairs({"active", "mode", "stage", "candidate", "requestedName",
		"className", "currentClassName", "specName", "stageTime", "stageUntil",
		"tries", "inviteAttempts", "whoAttempts", "initAttempts", "requestedFallback"}) do
		parts[#parts + 1] = key.."="..UnBotSummonLog.Text(s[key], 128);
	end
	parts[#parts + 1] = "check="..tostring(check.active)..":"..tostring(check.mode)
		..":"..tostring(check.currentName)..":"..tostring(check.index);
	parts[#parts + 1] = "gate="..tostring(gate.active)..":"..tostring(gate.stage);
	parts[#parts + 1] = "buff="..tostring(buff.active)..":"..tostring(buff.stage)
		..":"..tostring(buff.phaseIndex);
	parts[#parts + 1] = "reserve="..tostring(reserve.active)..":"..tostring(reserve.stage);
	parts[#parts + 1] = "sequence="..tostring(builder.postSummonSequence ~= nil);
	parts[#parts + 1] = "combat="..tostring(UnitAffectingCombat("player") and true or false);
	local pvp,common,inspect = UnBotPVPSummon or {},UnBotSquadSummon or {},UnBotTalentInfo and UnBotTalentInfo.job;
	local op = pvp.op or {};
	parts[#parts + 1] = "common="..tostring(common.active)..":"..tostring(common.phase);
	parts[#parts + 1] = "pvp="..tostring(pvp.active)..":"..tostring(pvp.phase)..":"..tostring(pvp.index)
		..":"..tostring(pvp.round)..":"..tostring(op.kind)..":"..tostring(op.entry and op.entry.name)
		..":attempts="..tostring(op.attempts)..":pass="..(pvp.fallback and "pve-fallback" or "native");
	parts[#parts + 1] = "inspect="..tostring(inspect and inspect.name)..":"..tostring(inspect and inspect.attempts);
	parts[#parts + 1] = "lootPaused="..tostring(UnBotGunshipMasterLoot and UnBotGunshipMasterLoot.paused);
	local progress = {};
	for i, slot in ipairs((s.squad and s.squad.slots) or {}) do
		if (i > 40) then break end
		local names = {};
		for name in pairs(slot.names or {}) do
			if (#names >= 40) then break end
			names[#names + 1] = UnBotSummonLog.Text(name, 64);
		end
		table.sort(names);
		progress[#progress + 1] = tostring(i)..":"..tostring(slot.have).."/"
			..tostring(slot.need).."="..table.concat(names, ",")..(slot.skipped and ":skipped="..slot.skipped or "");
	end
	for i, entry in ipairs(pvp.items or {}) do
		if (i > 120) then break end
		progress[#progress + 1] = "pvp:"..tostring(entry.slotIndex)..":"..tostring(entry.name)
			..":ready="..tostring(entry.ready)..":failed="..tostring(entry.failed);
	end
	local cleaning = false;
	for _, entry in pairs(pvp.cleanup or {}) do
		if (GetTime() < (entry.untilTime or 0)) then cleaning = true; break end
	end
	local busy = (s.active and s.mode == "squad")
		or (check.active and (check.mode == "pre_summon" or check.mode == "post_summon"))
		or (check.autoStartAt or 0) > 0 or gate.active or buff.active or reserve.active
		or builder.postSummonSequence ~= nil
		or common.active or pvp.active or inspect ~= nil or cleaning
		or (UnBotGunshipMasterLoot and UnBotGunshipMasterLoot.paused);
	return UnBotSummonLog.Text(table.concat(parts, " "), 2048),
		UnBotSummonLog.Text(table.concat(progress, "; "), 2048), busy;
end

function UnBotSummonLog.Remember(name)
	if (not name or UnBotSummonLog.names[name]) then return; end
	if (UnBotSummonLog.nameCount >= 1000) then return; end
	UnBotSummonLog.names[name] = true;
	UnBotSummonLog.nameCount = UnBotSummonLog.nameCount + 1;
end

function UnBotSummonLog.Roster()
	local rows = {};
	local raid = GetNumRaidMembers();
	local count = raid > 0 and raid or GetNumPartyMembers();
	for i = 1, math.min(count, 40) do
		local unit = (raid > 0 and "raid" or "party")..i;
		local name = UnitName(unit);
		if (name) then
			UnBotSummonLog.Remember(name);
			rows[#rows + 1] = UnBotSummonLog.Text(name, 64)
				.."[online="..tostring(UnitIsConnected(unit) and true or false)
				..",visible="..tostring(UnitIsVisible(unit) and true or false)
				..",dead="..tostring(UnitIsDeadOrGhost(unit) and true or false).."]";
		end
	end
	table.sort(rows);
	return (raid > 0 and "raid " or "party ")..tostring(count)..": "..table.concat(rows, "; ");
end

function UnBotSummonLog.Observe()
	local log = UnBotSummonLog.current;
	if (not log) then return; end
	local state, progress, busy = UnBotSummonLog.State();
	if (state ~= log.lastState) then
		UnBotSummonLog.Add("state", state);
		log.lastState = state;
	end
	if (progress ~= log.lastProgress) then
		UnBotSummonLog.Add("slots", progress);
		log.lastProgress = UnBotSummonLog.Text(progress, 2048);
	end
	local roster = UnBotSummonLog.Roster();
	if (roster ~= log.lastRoster) then
		UnBotSummonLog.Add("roster", roster);
		log.lastRoster = roster;
	end
	if (busy) then UnBotSummonLog.idleSince = nil;
	elseif (not UnBotSummonLog.idleSince) then UnBotSummonLog.idleSince = GetTime(); end
end

function UnBotSummonLog.Begin(requirements, source, partial)
	if (not UnBotSquadConfig or not UnBotSquadConfig.summonLogging) then return; end
	if (UnBotSummonLog.current) then UnBotSummonLog.Finish("next_run"); end
	UnBotSquadConfig.summonLogs = UnBotSquadConfig.summonLogs or {};
	local log = {
		schema = 2, version = GetAddOnMetadata("UnBotCustom", "Version"),
		startedAt = time(), clockStart = GetTime(), status = "recording",
		requirements = UnBotSummonLog.Text(requirements, 4096), source = source,
		partial = partial and true or false,
		player = UnitName("player"), realm = GetRealmName(), faction = UnitFactionGroup("player"),
		level = UnitLevel("player"), zone = GetRealZoneText(),
		buffRaid = UnBotSquadConfig.buffRaidAfterSummon and true or false,
		reserveCount = UnBotSquadConfig.resurrectionReserveCount,
		events = {}, first = 1, count = 0, bytes = 0, serial = 0, dropped = 0,
	};
	log.plan,log.results,log.outcome = UnBotSummonLog.Plan(source),{},"unknown";
	local pvpParts = {};
	for _, slot in ipairs(log.plan.pvp) do
		pvpParts[#pvpParts+1] = slot.className.." "..slot.specKey.." "..tostring(slot.count);
	end
	log.pvpRequirements = table.concat(pvpParts,", ");
	local _, _, builder = UnBotSummonLog.Context();
	if (GetInstanceInfo) then
		local name, kind, difficulty, difficultyName, maximum = GetInstanceInfo();
		log.instance = {name = name, kind = kind, difficulty = difficulty,
			difficultyName = difficultyName, maximum = maximum};
	end
	local preset = builder and builder.pendingBossPreset;
	log.boss = preset and {bossKey = preset.bossKey, modeKey = preset.modeKey} or nil;
	log.addons = {};
	for i = 1, math.min(GetNumAddOns(), 300) do
		local name = GetAddOnInfo(i);
		if (name and IsAddOnLoaded(name)) then
			log.addons[#log.addons + 1] = UnBotSummonLog.Text(name.."="
				..tostring(GetAddOnMetadata(name, "Version") or "?"), 256);
		end
	end
	table.insert(UnBotSquadConfig.summonLogs, 1, log);
	while (#UnBotSquadConfig.summonLogs > 2) do table.remove(UnBotSquadConfig.summonLogs); end
	UnBotSummonLog.current = log;
	UnBotSummonLog.names = {};
	UnBotSummonLog.nameCount = 0;
	UnBotSummonLog.lastCommandAt = nil;
	UnBotSummonLog.bucket = nil;
	UnBotSummonLog.idleSince = nil;
	UnBotSummonLog.ownsChat = nil;
	UnBotSummonLog.inspectJob = nil;
	if (LoggingChat) then
		-- Observe a manually enabled chat log; never enable whole-chat recording.
		local checked, active = pcall(LoggingChat);
		log.chatLogEnabled = checked and active and true or false;
	end
	UnBotSummonLog.Add("start", log.requirements, nil, source);
	UnBotSummonLog.Add("plan_pvp", log.pvpRequirements, nil,
		"expectedPVE="..tostring(log.plan.expectedPVE).." expectedPVP="..tostring(log.plan.expectedPVP));
	UnBotSummonLog.Observe();
	UnBotDiagnostics.Message("Лог призыва: запись начата без записи общего чата. После теста /reload; передайте SavedVariables\\UnBot.lua.");
end

function UnBotSummonLog.Finish(reason)
	local log = UnBotSummonLog.current;
	if (not log) then return; end
	for owner in pairs(log.waitStates or {}) do UnBotSummonLog.Wait(owner); end
	UnBotSummonLog.Observe();
	log.outcome = UnBotSummonLog.Outcome(log);
	UnBotSummonLog.Add("end", reason, nil, "outcome="..log.outcome);
	log.endReason = reason;
	log.status = reason == "idle" and (log.outcome == "unknown" and "idle_unknown" or log.outcome) or reason;
	log.endedAt = time();
	UnBotSummonLog.current = nil;
	UnBotSummonLog.names = nil;
	UnBotSummonLog.inspectJob = nil;
	if (UnBotSummonLog.ownsChat and LoggingChat) then pcall(LoggingChat, false); end
	UnBotSummonLog.ownsChat = nil;
end

function UnBotSummonLog.Command(api, text, channel, target)
	local log = UnBotSummonLog.current;
	if (not log) then return; end
	if (api == "SendChatMessage" and channel ~= "SAY" and channel ~= "RAID"
		and channel ~= "PARTY" and channel ~= "WHISPER") then return; end
	if (target) then UnBotSummonLog.Remember(target); end
	local named = tostring(text or ""):match("^%.playerbot bot %S+ (.+)$");
	if (named) then UnBotSummonLog.Remember(named); end
	UnBotSummonLog.Observe();
	local now = GetTime();
	local bucket = math.floor(now);
	if (bucket ~= UnBotSummonLog.bucket) then
		UnBotSummonLog.bucket = bucket; UnBotSummonLog.bucketCount = 0;
	end
	UnBotSummonLog.bucketCount = UnBotSummonLog.bucketCount + 1;
	local gap = UnBotSummonLog.lastCommandAt and math.floor((now - UnBotSummonLog.lastCommandAt) * 1000 + 0.5);
	UnBotSummonLog.lastCommandAt = now;
	local stack = "";
	if (debugstack) then
		local ok, value = pcall(debugstack, 3, 5, 0);
		if (ok) then stack = UnBotSummonLog.Text(value, 700); end
	end
	UnBotSummonLog.Add("api", api.." "..tostring(text or ""), target,
		"channel="..tostring(channel).." gapMs="..tostring(gap)
		.." callsThisSecond="..tostring(UnBotSummonLog.bucketCount).."\n"..stack);
	-- API observed after call; this is not proof of delivery or server acceptance.
end

function UnBotSummonLog.IsSystemChat(message)
	local text = tostring(message or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
		:gsub("|H.-|h(.-)|h", "%1"):match("^%s*(.-)%s*$");
	if text == "" then return true end
	local label = text:match("^%[([^%]]+)%]");
	if not label then return false end
	label = label:lower();
	if label == "autobalance" or label == "playerbot" or label == "unbot" then return false end
	return text:match("^%[[^%]]+%]%s*[^:]+:") ~= nil;
end

function UnBotSummonLog.Event(event, message, sender)
	if (event == "PLAYER_LOGIN") then
		for _, log in ipairs((UnBotSquadConfig and UnBotSquadConfig.summonLogs) or {}) do
			if (log.status == "recording") then log.status = "interrupted_unknown"; end
		end
		return;
	end
	if (not UnBotSummonLog.current) then return; end
	if (event == "PLAYER_LOGOUT") then UnBotSummonLog.Finish("player_logout"); return; end
	if (event == "CHAT_MSG_WHISPER" and not UnBotSummonLog.names[sender]) then return; end
	if (event == "CHAT_MSG_SYSTEM" and UnBotSummonLog.IsSystemChat(message)) then return; end
	UnBotSummonLog.Observe();
	if (event ~= "PARTY_MEMBERS_CHANGED" and event ~= "RAID_ROSTER_UPDATE") then
		UnBotSummonLog.Add(event, message, sender);
	end
end

function UnBotSummonLog.Tick()
	local log = UnBotSummonLog.current;
	if (not log) then return; end
	UnBotSummonLog.Observe();
	if (GetTime() - log.clockStart >= UnBotSummonLog.maxSeconds) then
		UnBotSummonLog.Finish("log_timeout");
	elseif (UnBotSummonLog.idleSince and GetTime() - UnBotSummonLog.idleSince >= 10) then
		UnBotSummonLog.Finish("idle");
	end
end

function UnBotSummonLog.SetEnabled(enabled)
	UnBotSquadConfig = UnBotSquadConfig or {};
	UnBotSquadConfig.summonLogging = enabled and true or false;
	if (not enabled) then UnBotSummonLog.Finish("disabled");
	elseif (UnBotSummonLog.Context and not UnBotSummonLog.current) then
		local _, _, busy = UnBotSummonLog.State();
		if (busy) then UnBotSummonLog.Begin("", "enabled_mid_run", true); end
	end
	UnBotDiagnostics.Message(enabled
		and "Лог призыва включён. Перед проверкой выполните /reload, затем нажмите Призвать."
		or "Лог призыва выключен. Собранные журналы сохранены в памяти; /reload запишет их на диск.");
end

function UnBotSummonLog.CreateCheck(window)
	local check = CreateFrame("CheckButton", nil, window, "UICheckButtonTemplate");
	check:SetWidth(24); check:SetHeight(24);
	check:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 22, 70);
	check.text = check:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	check.text:SetPoint("LEFT", check, "RIGHT", -2, 0);
	check.text:SetWidth(350); check.text:SetJustifyH("LEFT");
	check.text:SetText("Лог призыва (для диагностики вылетов)");
	check:SetHitRectInsets(0, -350, 0, 0);
	check:SetScript("OnClick", function(self)
		UnBotSummonLog.Safe("SetEnabled", self:GetChecked() and true or false);
	end);
	check:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP");
		GameTooltip:AddLine("Лог призыва состава", 0, 0.7, 0.7, 1);
		GameTooltip:AddLine("Сохраняет два последних запуска: полный план PvE/PvP, этапы осмотра, команды, интервалы и ответы. По умолчанию выключен.", 1, 1, 1, 1);
		GameTooltip:AddLine("Отдельно сохраняет подтверждённый итог, дефицит и остановку. Бездействие само по себе не означает успех.", 1, 1, 1, 1);
		GameTooltip:AddLine("Переписка каналов, переданная сервером как системный чат, и пустые строки не записываются. Ответы ботов и ошибки сохраняются.", 1, 1, 1, 1);
		GameTooltip:AddLine("После теста: /reload и файл SavedVariables\\UnBot.lua. Автоматическая запись всего чата отключена.", 0, 1, 0, 1);
		GameTooltip:AddLine("При аварийном разрыве журнал может не записаться: используйте запись экрана с панелью UnBotTrace.", 1, 0.82, 0, 1);
		GameTooltip:Show();
	end);
	check:SetScript("OnLeave", function() GameTooltip:Hide(); end);
	return check;
end

UnBotSummonLog.eventFrame = CreateFrame("Frame", "UnBotSummonLogEventFrame");
for _, event in ipairs({"PLAYER_LOGIN", "PLAYER_LOGOUT", "PLAYER_LEAVING_WORLD",
	"CHAT_MSG_WHISPER", "CHAT_MSG_SYSTEM", "UI_ERROR_MESSAGE", "UI_INFO_MESSAGE",
	"PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED"}) do
	UnBotSummonLog.eventFrame:RegisterEvent(event);
end
UnBotSummonLog.eventFrame:SetScript("OnEvent", function(self, event, ...)
	UnBotSummonLog.Safe("Event", event, ...);
end);
UnBotSummonLog.eventFrame:SetScript("OnUpdate", function(self, elapsed)
	if (not UnBotSummonLog.current) then return; end
	self.elapsed = (self.elapsed or 0) + elapsed;
	if (self.elapsed >= 0.1) then self.elapsed = 0; UnBotSummonLog.Safe("Tick"); end
end);
if (hooksecurefunc) then
	hooksecurefunc("SendChatMessage", function(text, channel, language, target)
		UnBotSummonLog.Safe("Command", "SendChatMessage", text, channel, target);
	end);
	for _, api in ipairs({"InviteUnit", "UninviteUnit", "ConvertToRaid", "SetRaidSubgroup", "SetLootMethod"}) do
		local apiName = api;
		if (type(_G[apiName]) == "function") then
			hooksecurefunc(apiName, function(a, b, c)
				UnBotSummonLog.Safe("Command", apiName, a, b, c);
			end);
		end
	end
end
