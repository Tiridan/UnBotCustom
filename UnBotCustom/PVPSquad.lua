-- Independent PVP state, displayed in the common squad editor. No bot commands.
UnBotPVPSquad = UnBotPVPSquad or {};
UnBotPVPSquad.maxMembers = 39;
UnBotPVPSquad.rows = UnBotPVPSquad.rows or {};

function UnBotPVPSquad.Message(text)
	if (UnBotSpecSummonMessage) then
		UnBotSpecSummonMessage(text);
	elseif (DEFAULT_CHAT_FRAME) then
		DEFAULT_CHAT_FRAME:AddMessage("UnBot: "..text);
	end
end

function UnBotPVPSquad.State()
	local realm = GetRealmName and GetRealmName();
	local player = UnitName and UnitName("player");
	if (not realm or realm == "" or not player or player == "" or player == UNKNOWNOBJECT) then
		return nil;
	end
	UnBotSquadConfig = UnBotSquadConfig or {};
	UnBotSquadConfig.pvpSquadsByCharacter = UnBotSquadConfig.pvpSquadsByCharacter or {};
	local key = realm.."|"..player;
	local state = UnBotSquadConfig.pvpSquadsByCharacter[key];
	if (not state) then
		state = { schemaVersion = 1, slots = {} };
		UnBotSquadConfig.pvpSquadsByCharacter[key] = state;
	end
	state.slots = state.slots or {};
	return state;
end

function UnBotPVPSquad.Count(slot)
	if (slot.reserveOnly) then return 0; end
	if (slot.accountAltName) then return 1; end
	return math.max(1, math.min(UnBotPVPSquad.maxMembers, math.floor(tonumber(slot.count) or 1)));
end

function UnBotPVPSquad.Total(state)
	local total = 0;
	for _, slot in ipairs(state and state.slots or {}) do
		total = total + UnBotPVPSquad.Count(slot);
	end
	return total;
end

-- The common editor counts named characters once and shares one raid budget.
function UnBotPVPSquad.SelectedCount(excluded)
	local total = 0;
	for _, slot in ipairs(UnBotSquadConfig and UnBotSquadConfig.slots or {}) do
		if (slot ~= excluded) then total = total + UnBotPVPSquad.Count(slot); end
	end
	local state = UnBotPVPSquad.State();
	for _, slot in ipairs(state and state.slots or {}) do
		if (slot ~= excluded) then total = total + UnBotPVPSquad.Count(slot); end
	end
	return total;
end

function UnBotPVPSquad.Capacity()
	local reserves = UnBotSquadRosterReserveNames and UnBotSquadRosterReserveNames() or {};
	return math.max(0, UnBotPVPSquad.maxMembers - #reserves);
end

function UnBotPVPSquad.CanAddMembers(count)
	if (UnBotPVPSquad.SelectedCount() + count <= UnBotPVPSquad.Capacity()) then return true; end
	UnBotPVPSquad.Message("Недостаточно мест: максимум 40 участников вместе с вами; учитываются PvE, PvP, альты и офлайн-резерв.");
	return false;
end

function UnBotPVPSquad.CountSlot(mode, index)
	local state = mode == "PVP" and UnBotPVPSquad.State() or UnBotSquadConfig;
	return state and state.slots and state.slots[index];
end

function UnBotPVPSquad.SetCount(mode, index, value, expectedSlot)
	local slot = UnBotPVPSquad.CountSlot(mode, index);
	if (not slot or (expectedSlot and expectedSlot ~= slot) or slot.accountAltName or slot.reserveOnly) then
		UnBotPVPSquad.Refresh(); return false;
	end
	local text = tostring(value or "");
	local count = tonumber(text);
	if (not string.match(text, "^%d+$") or not count or count < 1) then
		UnBotPVPSquad.Refresh(); return false;
	end
	local available = math.max(0, UnBotPVPSquad.Capacity() - UnBotPVPSquad.SelectedCount(slot));
	if (available < 1) then
		UnBotPVPSquad.CanAddMembers(1);
		UnBotPVPSquad.Refresh(); return false;
	end
	local previous = slot.count;
	slot.count = math.min(count, available);
	if (count > available) then
		UnBotPVPSquad.Message("Количество ограничено: для этой позиции доступно "..available.." мест. Всего в рейде не более 40 участников вместе с вами.");
	end
	UnBotPVPSquad.Refresh();
	return slot.count ~= previous;
end

function UnBotPVPSquad.CommitCountEdits()
	for _, rows in ipairs({UnBotSquadBuilder and UnBotSquadBuilder.rows or {}, UnBotPVPSquad.rows}) do
		for _, row in ipairs(rows) do
			if (row.count and row.count.pendingCount) then
				row.count:GetScript("OnEnterPressed")(row.count);
			end
		end
	end
end

function UnBotPVPSquad.ChangePVECount(index, delta)
	UnBotPVPSquad.CommitCountEdits();
	local slot = UnBotPVPSquad.CountSlot("PVE", index);
	return slot and UnBotPVPSquad.SetCount("PVE", index, UnBotPVPSquad.Count(slot) + delta) or false;
end

function UnBotPVPSquad.UpdateCountEdit(row, slot)
	local edit = row.count;
	local editable = not slot.accountAltName and not slot.reserveOnly;
	if (not editable or edit.editSlot ~= slot) then
		edit.pendingCount = nil; edit.editSlot = nil;
		edit:ClearFocus();
	end
	edit:EnableMouse(editable);
	edit:SetTextColor(editable and 1 or .6, editable and .82 or .6, editable and 0 or .6);
	if (not edit:HasFocus()) then
		edit:SetText(slot.reserveOnly and "R" or tostring(UnBotPVPSquad.Count(slot)));
	end
end

function UnBotPVPSquad.CreateCountEdit(row, minus, mode)
	local edit = CreateFrame("EditBox", nil, row, "InputBoxTemplate");
	edit:SetPoint("LEFT", minus, "RIGHT", 4, 0);
	edit:SetWidth(24); edit:SetHeight(20);
	edit:SetAutoFocus(false); edit:SetNumeric(true); edit:SetMaxLetters(3);
	edit:SetFontObject(GameFontNormal); edit:SetJustifyH("CENTER"); edit:SetTextInsets(0, 0, 0, 0);
	local function currentSlot()
		return UnBotPVPSquad.CountSlot(mode, mode == "PVP" and row.index or row.slotIndex);
	end
	local function commit(self)
		local expected, pending, value = self.editSlot, self.pendingCount, self:GetText();
		self.pendingCount = nil; self.editSlot = nil;
		if (pending and expected) then
			UnBotPVPSquad.SetCount(mode, mode == "PVP" and row.index or row.slotIndex, value, expected);
		end
		local slot = currentSlot();
		if (slot) then UnBotPVPSquad.UpdateCountEdit(row, slot); end
	end
	edit:SetScript("OnEditFocusGained", function(self)
		local slot = currentSlot();
		if (not slot or slot.accountAltName or slot.reserveOnly) then self:ClearFocus(); return; end
		self.editSlot = slot; self.pendingCount = nil; self:HighlightText();
	end);
	edit:SetScript("OnTextChanged", function(self, userInput)
		if (userInput and self.editSlot) then self.pendingCount = true; end
	end);
	edit:SetScript("OnEnterPressed", function(self) commit(self); self:ClearFocus(); end);
	edit:SetScript("OnEditFocusLost", commit);
	edit:SetScript("OnEscapePressed", function(self)
		self.pendingCount = nil; self.editSlot = nil; self:ClearFocus();
		local slot = currentSlot();
		if (slot) then UnBotPVPSquad.UpdateCountEdit(row, slot); end
	end);
	edit:SetScript("OnHide", function(self)
		self.pendingCount = nil; self.editSlot = nil; self:ClearFocus();
	end);
	return edit;
end

function UnBotPVPSquad.DisplayCount()
	local state = UnBotPVPSquad.State();
	return #(UnBotSquadConfig.slots or {}) + #(state and state.slots or {});
end

function UnBotPVPSquad.FindSpec(className, specKey)
	for _, classInfo in ipairs(UnBotPVPSquad.catalog or {}) do
		if (classInfo.className == className) then
			if (specKey == "any") then
				return classInfo.label.." - Любая специализация";
			end
			for _, spec in ipairs(classInfo.specs or {}) do
				if (spec.key == specKey) then
					return classInfo.label.." - "..spec.label;
				end
			end
		end
	end
end

function UnBotPVPSquad.Add(className, specKey)
	local label = UnBotPVPSquad.FindSpec(className, specKey);
	local state = UnBotPVPSquad.State();
	if (not label or not state) then return false; end
	if (not UnBotPVPSquad.CanAddMembers(1)) then return false; end
	local found;
	for _, slot in ipairs(state.slots) do
		if (slot.className == className and slot.specKey == specKey) then
			found = slot;
			break
		end
	end
	if (found) then
		found.count = UnBotPVPSquad.Count(found) + 1;
	else
		table.insert(state.slots, { mode = "PVP", className = className, specKey = specKey, label = label, count = 1 });
	end
	UnBotPVPSquad.Open();
	UnBotPVPSquad.Message("PVP-состав: добавлен "..label..". Выбор сохранён отдельно.");
	return true;
end

function UnBotPVPSquad.ChangeCount(index, delta)
	UnBotPVPSquad.CommitCountEdits();
	local state = UnBotPVPSquad.State();
	local slot = state and state.slots[index];
	return slot and UnBotPVPSquad.SetCount("PVP", index, UnBotPVPSquad.Count(slot) + delta) or false;
end

function UnBotPVPSquad.Remove(index)
	local state = UnBotPVPSquad.State();
	if (not state or not state.slots[index]) then return false; end
	table.remove(state.slots, index);
	UnBotPVPSquad.Refresh();
	return true;
end

function UnBotPVPSquad.Clear()
	local state = UnBotPVPSquad.State();
	if (not state) then return; end
	state.slots = {};
	UnBotPVPSquad.Refresh();
end

function UnBotPVPSquad.Button(parent, text, width, callback)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate");
	button:SetWidth(width);
	button:SetHeight(20);
	button:SetText(text);
	button:SetScript("OnClick", callback);
	return button;
end

function UnBotPVPSquad.Parts(slot)
	local classLabel = slot.className or "?";
	local specLabel = slot.specKey == "any" and "Любая" or (slot.specKey or "?");
	for _, classInfo in ipairs(UnBotPVPSquad.catalog or {}) do
		if (classInfo.className == slot.className) then
			classLabel = classInfo.label;
			for _, spec in ipairs(classInfo.specs or {}) do
				local matches = spec.key == slot.specKey;
				for _, alias in ipairs(UnBotPVPSquad.specAliases and UnBotPVPSquad.specAliases[spec.key] or {}) do
					if (alias == slot.specKey) then matches = true; end
				end
				if (matches) then specLabel = spec.label; break end
			end
			break
		end
	end
	if (UnBotLocale) then
		classLabel, specLabel = UnBotLocale.Text(classLabel), UnBotLocale.Text(specLabel);
	end
	return classLabel, specLabel;
end

function UnBotPVPSquad.Column(parent, x, width, text)
	local column = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	column:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -4);
	column:SetWidth(width);
	column:SetHeight(12);
	column:SetJustifyH("LEFT");
	if (text) then column:SetText(text); end
	return column;
end

function UnBotPVPSquad.Columns(row, slot, mode)
	if (not row.specText) then
		row.label:SetWidth(84);
		row.label:SetHeight(12);
		row.specText = UnBotPVPSquad.Column(row, 99, 112);
		row.modeText = UnBotPVPSquad.Column(row, 215, 40);
		row.typeText = UnBotPVPSquad.Column(row, 260, 50);
		row:EnableMouse(true);
		row:SetScript("OnEnter", function(self)
			local display = self.displaySlot;
			if (not display) then return; end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
			local displayLabel = display.label or (display.className.." - "..display.specKey);
			GameTooltip:AddLine(UnBotLocale and UnBotLocale.Text(displayLabel) or displayLabel, 1, 0.82, 0, 1);
			if (display.accountAltName) then GameTooltip:AddLine("Альт: "..display.accountAltName, 0.4, 0.8, 1, 1); end
			GameTooltip:AddLine(self.displayMode == "PVP"
				and "PVP: общая кнопка «Призвать», с проверкой и применением серверного PVP-пресета."
				or "PVE: используется существующий призыв и пресеты 1–5.", 1, 1, 1, 1);
			if (self.displayMode == "PVP" and self.assignment) then
				GameTooltip:AddLine(self.assignment:GetText() or "", 1, 0.7, 0.4, 1);
			end
			if (display.reserveOnly) then GameTooltip:AddLine("Резерв в ростере", 0.7, 0.7, 0.7, 1); end
			GameTooltip:Show();
		end);
		row:SetScript("OnLeave", function() GameTooltip:Hide(); end);
	end
	row.displaySlot = slot;
	row.displayMode = mode;
	local classLabel, specLabel = UnBotPVPSquad.Parts(slot);
	row.label:SetText(classLabel);
	row.specText:SetText(specLabel);
	row.specText:SetTextColor(0.9, 0.9, 0.9);
	row.modeText:SetText(mode);
	row.typeText:SetText(UnBotSquadBuilderUI and UnBotSquadBuilderUI.SlotType(slot) or (slot.accountAltName and "альт" or "бот"));
	row.typeText:SetTextColor(0.72, 0.84, 0.84);
	if (mode == "PVP") then row.modeText:SetTextColor(1, 0.55, 0.25);
	else row.modeText:SetTextColor(0.35, 0.85, 0.8); end
end

function UnBotPVPSquad.CreateHeader(builder)
	if (UnBotPVPSquad.header) then return; end
	local header = CreateFrame("Frame", nil, builder.frame);
	header:SetPoint("TOPLEFT", builder.frame, "TOPLEFT", 20, -102);
	header:SetWidth(426);
	header:SetHeight(18);
	UnBotPVPSquad.Column(header, 11, 84, "Класс"):SetTextColor(0.45, 0.82, 0.84);
	UnBotPVPSquad.Column(header, 99, 112, "Спек / роль"):SetTextColor(0.45, 0.82, 0.84);
	UnBotPVPSquad.Column(header, 215, 40, "Режим"):SetTextColor(0.45, 0.82, 0.84);
	UnBotPVPSquad.Column(header, 260, 50, "Тип"):SetTextColor(0.45, 0.82, 0.84);
	UnBotPVPSquad.Column(header, 318, 104, "Количество"):SetTextColor(0.45, 0.82, 0.84);
	UnBotPVPSquad.header = header;
end

function UnBotPVPSquad.ColorStatus(row, status)
	if (status == "ready") then
		row:SetBackdropColor(0.025,0.12,0.06,0.94);
		row:SetBackdropBorderColor(0.2,0.65,0.3,0.9);
		row.assignment:SetTextColor(0.2,1,0.35);
	elseif (status == "pending" or status == "partial") then
		row:SetBackdropColor(0.12,0.085,0.025,0.94);
		row:SetBackdropBorderColor(0.75,0.5,0.15,0.85);
		row.assignment:SetTextColor(1,0.8,0.3);
	elseif (status == "failed") then
		row:SetBackdropColor(0.14,0.035,0.035,0.94);
		row:SetBackdropBorderColor(0.75,0.2,0.2,0.85);
		row.assignment:SetTextColor(1,0.4,0.4);
	else
		row:SetBackdropColor(0.035,0.07,0.09,0.94);
		row:SetBackdropBorderColor(0.25,0.36,0.42,0.85);
		row.assignment:SetTextColor(0.7,0.75,0.8);
	end
end

function UnBotPVPSquad.Summary(pveSlots, state, pvpAssignments, pveAssignments)
	local summary = {pveNeeded=0,pvpNeeded=UnBotPVPSquad.Total(state),pveReady=0,pvpReady=0,
		onlineBots=0,onlineOthers=0,offline=0,skipped=0};
	local claimed,seen = {},{};
	local t = UnBotPVPSquad.transport;
	for name in pairs(t and t.Roster and t.Roster() or {}) do
		if (name ~= UnitName("player") and not seen[name]) then
			seen[name] = true;
			local unit = UnBotSquadRosterFindUnit and UnBotSquadRosterFindUnit(name);
			local profile = UnBotBotRegistry and UnBotBotRegistry.bots and UnBotBotRegistry.bots[name];
			if (unit and UnitIsConnected) then
				if (UnitIsConnected(unit)) then
					if (profile) then summary.onlineBots = summary.onlineBots + 1;
					else summary.onlineOthers = summary.onlineOthers + 1; end
				else summary.offline = summary.offline + 1; end
			end
		end
	end
	local function count(members, limit, pvp)
		local ready = 0;
		for _, member in ipairs(members or {}) do
			local unit = member.unit or (UnBotSquadRosterFindUnit and UnBotSquadRosterFindUnit(member.name));
			if (ready < limit and member.name and member.name ~= UnitName("player") and not claimed[member.name]
				and (pvp and member.ready or (not pvp and member.online))
				and unit and UnitIsConnected and UnitIsConnected(unit)
				and (not UnitIsDeadOrGhost or not UnitIsDeadOrGhost(unit))) then
				claimed[member.name] = true; ready = ready + 1;
			end
		end
		return ready;
	end
	local pvp = UnBotPVPSummon;
	local current = pvp and pvp.Signature and UnBotRegistryCurrentContext
		and pvp.signature == pvp.Signature() and pvp.context == UnBotRegistryCurrentContext() and not pvp.catalogOnly;
	for index, slot in ipairs(state and state.slots or {}) do
		local needed = UnBotPVPSquad.Count(slot);
		local ready = count(pvpAssignments[index],needed,true);
		summary.pvpReady = summary.pvpReady + ready;
		if (current and pvp.blocked and pvp.blocked[index]) then summary.skipped = summary.skipped + needed - ready; end
	end
	local assigned = pveAssignments or (UnBotSquadBuilderRosterAssignments and UnBotSquadBuilderRosterAssignments() or {});
	for _, slot in ipairs(pveSlots or {}) do
		if (not slot.reserveOnly) then
			local needed = math.max(1,tonumber(slot.count) or 1);
			summary.pveNeeded = summary.pveNeeded + needed;
			if (slot.accountAltName and UnBotAccountAlts and UnBotAccountAlts.CanAddToSquad
				and not UnBotAccountAlts.CanAddToSquad(slot.accountAltName)) then
				summary.skipped = summary.skipped + needed;
			else summary.pveReady = summary.pveReady + count(assigned[slot],needed,false); end
		end
	end
	summary.needed = summary.pveNeeded + summary.pvpNeeded;
	summary.ready = summary.pveReady + summary.pvpReady;
	summary.missing = math.max(0,summary.needed - summary.ready - summary.skipped);
	summary.onlinePlayers = summary.onlineOthers + 1;
	summary.onlineTotal = summary.onlineBots + summary.onlinePlayers;
	return summary;
end

function UnBotPVPSquad.StatusText(summary, active)
	return "Выбрано: "..summary.needed.." (PvE "..summary.pveNeeded.." + PvP "..summary.pvpNeeded..")\n"
		.."Онлайн: "..summary.onlineBots.." ботов + "..(summary.onlineOthers == 0 and "вы" or (summary.onlinePlayers.." игроков"))
		.." = "..summary.onlineTotal..". Офлайн: "..summary.offline.."\n"
		.."Подтверждено: "..summary.ready.."/"..summary.needed..". Пропущено: "..summary.skipped..". "
		..(active and "Осталось: " or "Не хватает: ")..summary.missing;
end

function UnBotPVPSquad.Render(pveAssignments)
	local builder = UnBotSquadBuilder;
	if (not builder or not builder.frame or not builder.scrollChild) then return; end
	UnBotPVPSquad.CreateHeader(builder);
	UnBotPVPSquad.FallbackCheck(builder);
	if (builder.statusCaption) then
		builder.statusCaption:SetText("СТАТУС СОСТАВА | PVP: "..UnBotPVPSquad.Total(UnBotPVPSquad.State()));
	end
	local pveSlots = UnBotSquadConfig.slots or {};
	-- Read the displayed snapshot directly. PVECount normalizes character
	-- storage and replaces slot tables, invalidating assignment table keys.
	for index, slot in ipairs(pveSlots) do
		local row = builder.rows[index];
		if (row) then
			UnBotPVPSquad.Columns(row, slot, "PVE");
			local assignment = row.assignment:GetText() or "";
			if (slot.accountAltName) then
				if (not string.find(assignment, slot.accountAltName, 1, true)) then
					assignment = slot.accountAltName.." — "..assignment;
				end
				assignment = "|cff69ccf0[альт]|r "..assignment;
			end
			if (slot.reserveOnly) then assignment = "|cffaaaaaa[резерв]|r "..assignment; end
			row.assignment:SetText(assignment);
		end
	end
	local state = UnBotPVPSquad.State();
	local slots = state and state.slots or {};
	local pvpAssignments = UnBotPVPSummon and UnBotPVPSummon.RosterAssignments and UnBotPVPSummon.RosterAssignments() or {};
	for index, slot in ipairs(slots) do
		local row = UnBotPVPSquad.rows[index];
		if (not row) then
			row = CreateFrame("Frame", nil, builder.scrollChild);
			row:SetWidth(426);
			row:SetHeight(34);
			row:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
				edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 8,
				insets = { left = 3, right = 3, top = 3, bottom = 3 } });
			row:SetBackdropColor(0.12, 0.055, 0.025, 0.94);
			row:SetBackdropBorderColor(0.65, 0.3, 0.12, 0.85);
			row.label = UnBotPVPSquad.Column(row, 11, 84);
			row.assignment = UnBotPVPSquad.Column(row, 15, 378, "PVP: готов к призыву");
			row.assignment:ClearAllPoints();
			row.assignment:SetPoint("TOPLEFT", row, "TOPLEFT", 15, -17);
			row.assignment:SetTextColor(0.8, 0.65, 0.5);
			row.minus = UnBotPVPSquad.Button(row, "-", 24, function() UnBotPVPSquad.ChangeCount(row.index, -1); end);
			row.minus:SetPoint("TOPLEFT", row, "TOPLEFT", 314, 0);
			row.count = UnBotPVPSquad.CreateCountEdit(row, row.minus, "PVP");
			row.plus = UnBotPVPSquad.Button(row, "+", 24, function() UnBotPVPSquad.ChangeCount(row.index, 1); end);
			row.plus:SetPoint("LEFT", row.count, "RIGHT", 2, 0);
			row.remove = UnBotPVPSquad.Button(row, "x", 24, function() UnBotPVPSquad.Remove(row.index); end);
			row.remove:SetPoint("LEFT", row.plus, "RIGHT", 6, 0);
			UnBotPVPSquad.rows[index] = row;
		end
		row.index = index;
		row:ClearAllPoints();
		row:SetPoint("TOPLEFT", builder.scrollChild, "TOPLEFT", 0, -(#pveSlots + index - 1) * 36);
		UnBotPVPSquad.Columns(row, slot, "PVP");
		local status = "idle";
		if (UnBotPVPSummon and UnBotPVPSummon.SlotStatus) then status = UnBotPVPSummon.SlotStatus(index,pvpAssignments); end
		row.assignment:SetText(UnBotPVPSummon and UnBotPVPSummon.SlotText(index,pvpAssignments) or "PVP: ожидает призыва");
		UnBotPVPSquad.ColorStatus(row,status);
		UnBotPVPSquad.UpdateCountEdit(row, slot);
		row:Show();
	end
	for index = #slots + 1, #UnBotPVPSquad.rows do UnBotPVPSquad.rows[index]:Hide(); end
	builder.scrollChild:SetHeight(math.max(202, (#pveSlots + #slots) * 36));
	builder.scrollFrame:UpdateScrollChildRect();
	builder.scrollFrame:SetVerticalScroll(math.min(builder.scrollFrame:GetVerticalScroll(), builder.scrollFrame:GetVerticalScrollRange() or 0));
	local summary = UnBotPVPSquad.Summary(pveSlots,state,pvpAssignments,pveAssignments);
	local pve = UnBotPVPSquad.transport and UnBotPVPSquad.transport.PVEOwner;
	local active = (UnBotPVPSummon and UnBotPVPSummon.active) or (UnBotSquadSummon and UnBotSquadSummon.active)
		or (pve and pve.active and pve.mode == "squad") or builder.postSummonSequence ~= nil;
	if (builder.status) then builder.status:SetText(UnBotPVPSquad.StatusText(summary,active)); end
	if (UnBotPVPSummon and UnBotPVPSummon.active and builder.statusCaption) then
		if (UnBotPVPSummon.catalogOnly) then
			builder.statusCaption:SetText("КАТАЛОГ СПЕКОВ: класс "..UnBotPVPSummon.scanCursor.."/"..UnBotPVPSummon.total);
		else builder.statusCaption:SetText("PVP: "..UnBotPVPSummon.phaseLabel.." | "..(UnBotPVPSummon.fallback and "добор PvE" or "готовые PvP")..", раунд "..UnBotPVPSummon.round); end
	elseif (UnBotSquadSummon and UnBotSquadSummon.active and builder.statusCaption) then
		builder.statusCaption:SetText("ПРИЗЫВ СОСТАВА: PVE -> PVP");
	elseif (active and builder.statusCaption) then
		builder.statusCaption:SetText("ПРИЗЫВ СОСТАВА: PVE / проверка прибытия");
	else
		local complete = summary.needed > 0 and summary.ready == summary.needed;
		if (builder.statusCaption) then
			builder.statusCaption:SetText((complete and "СОСТАВ ГОТОВ" or "ПРОВЕРКА СОСТАВА")
				.." | PVE "..summary.pveReady.."/"..summary.pveNeeded.." | PVP "..summary.pvpReady.."/"..summary.pvpNeeded);
		end
	end
	if (UnBotSquadBuilderUI and UnBotSquadBuilderUI.RenderStatus) then
		UnBotSquadBuilderUI.RenderStatus(builder,summary,active);
	end
end

function UnBotPVPSquad.HasRequestedBots()
	local state = UnBotPVPSquad.State();
	for _, slot in ipairs(state and state.slots or {}) do
		if (not slot.accountAltName and UnBotPVPSquad.Count(slot) > 0) then return true; end
	end
	return false;
end

function UnBotPVPSquad.FallbackCheck(builder)
	if (not builder.pveFallbackCheck) then
		local check = CreateFrame("CheckButton",nil,builder.frame,"UICheckButtonTemplate");
		builder.pveFallbackCheck = check;
		check:SetWidth(24); check:SetHeight(24);
		check:SetPoint("BOTTOMLEFT",builder.frame,"BOTTOMLEFT",22,106);
		check.text=check:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");
		check.text:SetPoint("LEFT",check,"RIGHT",-2,0); check.text:SetWidth(422); check.text:SetJustifyH("LEFT");
		check.text:SetText("При нехватке PvP спеков конвертировать из PvE");
		check:SetHitRectInsets(0,-422,0,0);
		check:SetScript("OnClick",function(self)
			local state=UnBotPVPSquad.State();
			if (not UnBotPVPSquad.HasRequestedBots() or (UnBotPVPSummon and UnBotPVPSummon.active) or (UnBotSquadSummon and UnBotSquadSummon.active)) then
				self:SetChecked(UnBotPVPSquad.HasRequestedBots() and (not state or state.allowPVEFallback~=false)); return;
			end
			if (state) then state.allowPVEFallback=self:GetChecked() and true or false; end
			UnBotPVPSquad.Refresh();
		end);
		check:SetScript("OnEnter",function(self)
			GameTooltip:SetOwner(self,"ANCHOR_TOP");
			GameTooltip:AddLine("Добор PvE → PvP",0,0.7,0.7,1);
			GameTooltip:AddLine("Сначала ищем готовых PvP-ботов. При дефиците переводим PvE-ботов той же специализации; нужны полные шаблоны класса и уровня. Результат подтверждаем двумя снимками талантов.",1,1,1,true);
			GameTooltip:AddLine("Альты, резерв и назначенные PvE-участники защищены. Без галочки новые таланты не применяются. Для классов без полного каталога при включённой галочке сохраняется прежнее применение серверного пресета с проверкой talents.",1,0.82,0,true);
			GameTooltip:Show();
		end);
		check:SetScript("OnLeave",function() GameTooltip:Hide(); end);
	end
	local state=UnBotPVPSquad.State();
	local requested = UnBotPVPSquad.HasRequestedBots();
	builder.pveFallbackCheck:SetChecked(requested and (not state or state.allowPVEFallback~=false));
	if (not requested or (UnBotPVPSummon and UnBotPVPSummon.active) or (UnBotSquadSummon and UnBotSquadSummon.active)) then
		builder.pveFallbackCheck:Disable();
	else builder.pveFallbackCheck:Enable(); end
	if (builder.pveFallbackCheck.text) then
		builder.pveFallbackCheck.text:SetTextColor(requested and 1 or .5,requested and 1 or .5,requested and 1 or .5);
	end
	if (UnBotSquadBuilderUI and builder.settingsControlsReady) then UnBotSquadBuilderUI.RefreshSettings(builder); end
end

function UnBotPVPSquad.Refresh()
	if (UnBotSquadBuilderRefresh) then UnBotSquadBuilderRefresh(); end
end

function UnBotPVPSquad.Open()
	if (UnBotSquadBuilderShow) then UnBotSquadBuilderShow(); end
	local scroll = UnBotSquadBuilder and UnBotSquadBuilder.scrollFrame;
	if (scroll) then
		local offset = #(UnBotSquadConfig.slots or {}) * 36;
		scroll:SetVerticalScroll(math.min(offset, scroll:GetVerticalScrollRange() or 0));
	end
end

SLASH_UNBOTPVPSQUAD1 = "/ubpvp";
SlashCmdList["UNBOTPVPSQUAD"] = UnBotPVPSquad.Open;

-- Display-only helpers. Opening the registry never starts a server scan.
UnBotSquadBuilderUI = {};

-- Event-driven display; the idle OnUpdate only checks controller flags.
function UnBotSquadBuilderUI.Dirty()
 local b=UnBotSquadBuilder;
 if b then b.refreshDirty=true; end
end

function UnBotSquadBuilderUI.Busy(builder)
 local owner=UnBotPVPSquad.transport and UnBotPVPSquad.transport.PVEOwner;
 local fast=UnBotPVEFastSummon;
 return (owner and owner.active and owner.mode=="squad")
  or (UnBotPVPSummon and UnBotPVPSummon.active)
  or (UnBotSquadSummon and UnBotSquadSummon.active)
  or (fast and (fast.op or fast.manualRemoval or fast.autoRemoval))
  or builder.postSummonSequence~=nil;
end

function UnBotSquadBuilderUI.Tick(builder)
 local busy=UnBotSquadBuilderUI.Busy(builder) and true or false;
 if busy~=builder.refreshWasBusy then builder.refreshDirty=true;builder.refreshWasBusy=busy;end
 local now=GetTime();
 if (builder.refreshDirty or busy) and now>=(builder.refreshNextAt or 0) then
  builder.refreshNextAt=now+(busy and .5 or .25);
  UnBotSquadBuilderRefresh();
 end
end

function UnBotSquadBuilderUI.Event(builder,event,unit)
 if event=="UNIT_HEALTH" or event=="UNIT_FLAGS" or event=="UNIT_NAME_UPDATE" then
  if not unit or not (unit=="player" or unit:match("^raid%d+$") or unit:match("^party%d+$")) then return;end
  builder.refreshUnits=builder.refreshUnits or {};
  local state=tostring(UnitName(unit))..":"..tostring(UnitIsConnected(unit))..":"..tostring(UnitIsDeadOrGhost(unit));
  if builder.refreshUnits[unit]==state then return;end
  builder.refreshUnits[unit]=state;
 end
 UnBotSquadBuilderUI.Dirty();
end

function UnBotSquadBuilderUI.AttachUpdates(builder)
 local window=builder.frame;
 for _,event in ipairs({"RAID_ROSTER_UPDATE","PARTY_MEMBERS_CHANGED","PLAYER_ENTERING_WORLD",
  "PLAYER_ALIVE","PLAYER_UNGHOST","UNIT_HEALTH","UNIT_FLAGS","UNIT_NAME_UPDATE"}) do window:RegisterEvent(event);end
 window:SetScript("OnEvent",function(self,event,unit) UnBotSquadBuilderUI.Event(builder,event,unit);end);
 window:SetScript("OnUpdate",function() UnBotSquadBuilderUI.Tick(builder);end);
end


function UnBotSquadBuilderUI.SlotType(slot)
	local name = slot and slot.accountAltName;
	if (not name) then return "бот"; end
	if (UnBotAccountAlts and UnBotAccountAlts.IsBoundToCurrentAccount
		and UnBotAccountAlts.IsBoundToCurrentAccount(name)) then return "альт"; end
	if (UnBotAccountAlts and UnBotAccountAlts.LinkedCharacter
		and UnBotAccountAlts.LinkedCharacter(name)) then return "альт с."; end
	local profile = UnBotBotRegistry and UnBotBotRegistry.bots and UnBotBotRegistry.bots[name];
	if (profile and (profile.source == "linked-account-alt" or profile.linkedAccountKey)) then return "альт с."; end
	return "альт";
end

function UnBotSquadBuilderUI.Freshness(now)
	now = tonumber(now) or time();
	local result = {total=0, old=0, unknown=0, oldestDays=0};
	if (UnBotRegistryMatchesCurrentContext and not UnBotRegistryMatchesCurrentContext()) then
		result.unavailable = true;
		return result;
	end
	for name, profile in pairs(UnBotBotRegistry and UnBotBotRegistry.bots or {}) do
		if (type(profile) == "table" and name ~= UnitName("player")
			and not (UnBotIsAccountAltProfile and UnBotIsAccountAltProfile(name, profile))) then
			result.total = result.total + 1;
			local checked = UnBotRegistryRefresh and UnBotRegistryRefresh.CheckedAt(profile)
				or (profile.className and profile.specName and tonumber(profile.specCheckedAt)) or 0;
			if (checked <= 0) then
				result.unknown = result.unknown + 1;
			else
				local days = math.max(0, math.floor((now - checked) / 86400));
				if (days >= 1) then result.old = result.old + 1; end
				result.oldestDays = math.max(result.oldestDays, days);
			end
		end
	end
	return result;
end

function UnBotSquadBuilderUI.OpenRegistry()
	if (UnBotBotCenterShow) then UnBotBotCenterShow("registry"); end
end

function UnBotSquadBuilderUI.RefreshRegistry()
 UnBotSquadBuilderUI.OpenRegistry();
 if UnBotRegistryRefresh and UnBotRegistryRefresh.Start then
  if not UnBotRegistryRefresh.Running() then UnBotRegistryRefresh.Start();end
 elseif UnBotSpecSummonMessage then UnBotSpecSummonMessage("Модуль обновления реестра не загружен. Перезапустите клиент.");end
end

function UnBotSquadBuilderUI.CreateSection(builder, field, caption, bottom, height)
	local section = {};
	section.background = builder.frame:CreateTexture(nil, "BACKGROUND");
	section.background:SetTexture([[Interface\Tooltips\UI-Tooltip-Background]]);
	section.background:SetVertexColor(0.035, 0.11, 0.13, 0.96);
	section.background:SetPoint("BOTTOMLEFT", builder.frame, "BOTTOMLEFT", 16, bottom);
	section.background:SetWidth(456);
	section.background:SetHeight(height);
	section.line = builder.frame:CreateTexture(nil, "BORDER");
	section.line:SetTexture(0.12, 0.62, 0.65, 0.72);
	section.line:SetPoint("BOTTOMLEFT", builder.frame, "BOTTOMLEFT", 18, bottom + height);
	section.line:SetWidth(452);
	section.line:SetHeight(1);
	section.caption = builder.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	section.caption:SetPoint("BOTTOMLEFT", builder.frame, "BOTTOMLEFT", 22, bottom + height - 22);
	section.caption:SetText(caption);
	section.caption:SetTextColor(0.42, 0.78, 0.8);
	builder[field] = section;
end

function UnBotSquadBuilderUI.CreateFreshness(builder)
	builder.registryFreshnessText = builder.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	builder.registryFreshnessText:SetPoint("BOTTOMLEFT", builder.frame, "BOTTOMLEFT", 22, 170);
	builder.registryFreshnessText:SetWidth(202);
	builder.registryFreshnessText:SetHeight(14);
	builder.registryFreshnessText:SetJustifyH("LEFT");
	builder.registryFreshnessDays = CreateFrame("Button", nil, builder.frame);
	builder.registryFreshnessDays:SetPoint("BOTTOMLEFT", builder.frame, "BOTTOMLEFT", 230, 168);
	builder.registryFreshnessDays:SetWidth(56);
	builder.registryFreshnessDays:SetHeight(18);
	builder.registryFreshnessDays.label = builder.registryFreshnessDays:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	builder.registryFreshnessDays.label:SetAllPoints();
	builder.registryFreshnessDays.label:SetJustifyH("RIGHT");
	builder.registryFreshnessDays:SetScript("OnClick", UnBotSquadBuilderUI.OpenRegistry);
	builder.registryFreshnessDays:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP");
		GameTooltip:AddLine("Свежесть реестра ботов", 0, 0.7, 0.7, 1);
		GameTooltip:AddLine("Считается время последней проверки класса и специализации. Простой вход бота онлайн не обновляет этот срок.", 1, 1, 1, true);
		GameTooltip:AddLine("Показаны боты без проверки хотя бы сутки и максимальный возраст сведений. Записи без даты посчитаны отдельно; альты исключены.", 1, 1, 1, true);
		GameTooltip:AddLine("Старые сведения могут ухудшать подбор по спеку. Дни открывают реестр; кнопка рядом запускает обновление.", 1, 0.82, 0, true);
		GameTooltip:Show();
	end);
	builder.registryFreshnessDays:SetScript("OnLeave", function() GameTooltip:Hide(); end);

	builder.registryRefreshButton=CreateFrame("Button",nil,builder.frame,"UIPanelButtonTemplate");
	builder.registryRefreshButton:SetPoint("BOTTOMLEFT",builder.frame,"BOTTOMLEFT",294,168);
	builder.registryRefreshButton:SetWidth(170);builder.registryRefreshButton:SetHeight(18);
	builder.registryRefreshButton:SetText("Обновить реестр ботов");
 builder.registryRefreshButton.reminderGlow=builder.registryRefreshButton:CreateTexture(nil,"OVERLAY");
 builder.registryRefreshButton.reminderGlow:SetAllPoints();
 builder.registryRefreshButton.reminderGlow:SetTexture(1,.65,.05,.3);
 builder.registryRefreshButton.reminderGlow:SetBlendMode("ADD");
 builder.registryRefreshButton.reminderGlow:Hide();
 builder.registryRefreshButton:SetScript("OnUpdate",function(self,elapsed) UnBotRegistryRefresh.UpdateReminderButton(self,elapsed);end);
 builder.registryRefreshButton:SetScript("OnHide",function(self)
  self.reminderState=nil;self.reminderGlow:Hide();self:UnlockHighlight();
 end);
	builder.registryRefreshButton:SetScript("OnClick",UnBotSquadBuilderUI.RefreshRegistry);
	builder.registryRefreshButton:SetScript("OnEnter",function(self)
		GameTooltip:SetOwner(self,"ANCHOR_TOP");GameTooltip:AddLine("Обновить реестр ботов",1,.82,0);
		local state=UnBotRegistryRefresh.ReminderState();
  GameTooltip:AddLine(UnBotRegistryRefresh.ReminderText(state) or "Регулярная проверка известных имён уточняет специализации и ускоряет подбор состава.",1,1,1,true);
  GameTooltip:AddLine("Встроенная база содержит имена и классы; специализации нужно проверить на сервере. Рекомендуем полный проход хотя бы раз в 7 дней.",1,.82,.2,true);
		GameTooltip:AddLine("Проверка известных имён запускается в пустой группе. В окне реестра показаны прогресс, прошедшее время и результат.",.7,.85,.85,true);
		GameTooltip:Show();
	end);builder.registryRefreshButton:SetScript("OnLeave",function() GameTooltip:Hide();end);
	UnBotSquadBuilderUI.RefreshFreshness(builder, true);
end

function UnBotSquadBuilderUI.RefreshFreshness(builder, force)
	if (not builder or not builder.registryFreshnessText) then return; end
	local now = time();
	local context = UnBotRegistryCurrentContext and UnBotRegistryCurrentContext();
	if (not force and builder.registryFreshnessAt and now - builder.registryFreshnessAt < 15
		and builder.registryFreshnessSource == UnBotBotRegistry and builder.registryFreshnessContext == context) then return; end
	builder.registryFreshnessAt, builder.registryFreshnessSource, builder.registryFreshnessContext = now, UnBotBotRegistry, context;
	local result = UnBotSquadBuilderUI.Freshness(now);
	builder.registryFreshness = result;
	local label, days;
	if (result.unavailable) then label, days = "Реестр: нет данных", "открыть";
	elseif (result.total == 0) then label, days = "Реестр: боты не найдены", "открыть";
	elseif (result.old == 0 and result.unknown == 0) then label, days = "Реестр: свежих "..result.total, "0 дн.";
	else
		label = "Реестр: > суток "..result.old.."; без даты "..result.unknown;
		days = result.oldestDays > 0 and ("до "..result.oldestDays.." дн.") or "нет даты";
	end
	builder.registryFreshnessText:SetText(label);
	builder.registryFreshnessText:SetTextColor((result.old > 0 or result.unknown > 0) and 1 or 0.72, 0.8, 0.72);
	builder.registryFreshnessDays.label:SetText(days);
	if builder.registryRefreshButton and UnBotRegistryRefresh then UnBotRegistryRefresh.UpdateReminderButton(builder.registryRefreshButton, .05);end
end


-- Shared display only: no summon queues or PvP assignments are changed here.
function UnBotSquadBuilderUI.ProgressModel(summary, active)
 local builder=UnBotSquadBuilder or {};
 local pve=UnBotPVPSquad.transport and UnBotPVPSquad.transport.PVEOwner;
 local fast=UnBotPVEFastSummon;
 local problems=fast and fast.CleanupProblems and fast.CleanupProblems() or {};
 local cleanup=0;
 for _,entry in pairs(pve and pve.cleanupQueue or {}) do if entry.pveOwned then cleanup=cleanup+1; end end
 local pending=fast and fast.manualRemoval;
 local automatic=fast and fast.autoRemoval;
 local busy=active or cleanup>0 or pending~=nil or automatic~=nil;
 local needed=tonumber(summary.needed) or 0;
 local ready=math.min(needed,math.max(0,tonumber(summary.ready) or 0));
 local value=needed>0 and ready/needed*100 or 0;
 local percent=math.floor(value+.5);
 local complete=needed>0 and ready==needed;
 local result={value=value,percent=percent,problems=problems,pending=pending,
  caption="ПОЗИЦИИ: "..ready.."/"..needed.." — "..percent.."%",color={.2,.72,.82}};
 local cycle,phase;
 if pending then cycle,phase="ОЖИДАНИЕ ИСКЛЮЧЕНИЯ","Проверяю выход "..pending.name.." из ростера";
 elseif automatic then cycle,phase="ИДЁТ ОЧИСТКА","Возврат онлайн перед исключением: "..automatic.target.name;
 elseif active then
  cycle="ИДЁТ";
  if UnBotPVPSummon and UnBotPVPSummon.active then
   phase=UnBotPVPSummon.catalogOnly and "Чтение каталога специализаций" or ("PvP: "..tostring(UnBotPVPSummon.phaseLabel or "подготовка"));
  elseif fast and fast.op then phase="Быстрый добор: "..fast.op.name;
  elseif pve and pve.active then
   local stages={squad_prefetch="Приглашение ботов",wait_prefetch_ready="Подготовка кандидата",
    wait_registry_member="Ожидание входа",wait_registry_who="Проверка специализации",
    wait_registry_init_settle="Ребалансировка",wait_registry_init_rate="Ребалансировка",
    wait_registry_feral_strategy="Проверка роли друида",wait_next="Подбор следующего кандидата"};
   phase=(stages[pve.stage] or "Подбор состава")..(pve.requestedName and (": "..pve.requestedName) or "");
  elseif UnBotBuffCycle and UnBotBuffCycle.active then phase="Баффы состава";
  elseif UnBotSquadNearbyGate and UnBotSquadNearbyGate.active then phase="Проверка прибытия";
  else phase="Проверка прибытия / завершение подготовки"; end
 elseif cleanup>0 then cycle,phase="ИДЁТ ОЧИСТКА","Осталось проверить исключение: "..cleanup;
 elseif #problems>0 then cycle,phase="ОСТАНОВЛЕН — НУЖНО ДЕЙСТВИЕ","Лишний участник: "..problems[1].name;
 elseif complete then cycle,phase="ЗАВЕРШЁН","Все заданные позиции закрыты";
 elseif needed==0 then cycle,phase="НЕ ЗАПУЩЕН","Добавьте участников в состав";
 else cycle,phase="НЕ ВЫПОЛНЯЕТСЯ","Есть незакрытые или пропущенные позиции"; end
 if #problems>0 then
  result.color={1,.6,.16};
  if active then phase=phase.."; требуется исключить "..problems[1].name; end
  if #problems>1 then phase=phase.." (+"..(#problems-1)..")"; end
 elseif complete and not busy then result.color={.3,.9,.4};
 elseif not busy then result.color={.85,.7,.25}; end
 local roster="Онлайн: "..summary.onlineBots.." ботов + "..(summary.onlineOthers==0 and "вы" or (summary.onlinePlayers.." игроков"))
  .." = "..summary.onlineTotal..". Офлайн: "..summary.offline;
 result.text="Цикл: "..cycle.."\n"..phase.."\n"
  .."PvE "..summary.pveReady.."/"..summary.pveNeeded.." | PvP "..summary.pvpReady.."/"..summary.pvpNeeded
  .." | Не хватает: "..summary.missing.." | Пропущено: "..summary.skipped.."\n"..roster;
 for _,problem in ipairs(problems) do if problem.offline then result.target=problem;break end end
 result.hint=complete and #problems==0 and not busy and "Все нужные позиции подтверждены" or "";
 if result.target then
  result.allowed,result.hint=fast.ManualAllowed(result.target);
  if result.allowed then result.hint="Освободить место по нажатию →"; end
 elseif #problems>0 then result.hint="Лишний участник ещё онлайн"; end
 local last=fast and fast.lastManualRemoval;
 if not pending and last and GetTime()-last.at<8 then
  result.hint=last.name..(last.removed and ": место освобождено" or ": исключение не подтверждено");
 end
 return result;
end

function UnBotSquadBuilderUI.CreateProgress(builder)
 if builder.summonProgress then return; end
 local bar=CreateFrame("StatusBar",nil,builder.frame);
 builder.summonProgress=bar;
 bar:SetPoint("BOTTOMLEFT",builder.frame,"BOTTOMLEFT",22,254);
 bar:SetWidth(444);bar:SetHeight(12);
 bar:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]]);
 bar:SetMinMaxValues(0,100);bar:SetValue(0);
 local background=bar:CreateTexture(nil,"BACKGROUND");
 background:SetAllPoints();background:SetTexture(0.04,0.07,0.08,.95);
 builder.cleanupHint=builder.frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");
 builder.cleanupHint:SetPoint("BOTTOMLEFT",builder.frame,"BOTTOMLEFT",22,186);
 builder.cleanupHint:SetWidth(266);builder.cleanupHint:SetHeight(18);builder.cleanupHint:SetJustifyH("LEFT");
 local button=CreateFrame("Button",nil,builder.frame,"UIPanelButtonTemplate");
 builder.offlineKickButton=button;
 button:SetPoint("BOTTOMRIGHT",builder.frame,"BOTTOMRIGHT",-24,186);
 button:SetWidth(168);button:SetHeight(18);button:Hide();
 button:SetScript("OnMouseDown",function(self) self.pressedTarget=self.cleanupTarget; end);
 button:SetScript("OnClick",function(self)
  local target=self.pressedTarget or self.cleanupTarget;self.pressedTarget=nil;
  if not target or not self.cleanupTarget or target.name~=self.cleanupTarget.name then return; end
  if UnBotPVEFastSummon then UnBotPVEFastSummon.ManualExclude(target); end
  if UnBotSquadBuilderRefresh then UnBotSquadBuilderRefresh(); end
 end);
 button:SetScript("OnEnter",function(self)
  GameTooltip:SetOwner(self,"ANCHOR_TOP");
  GameTooltip:AddLine("Исключить лишнего офлайн-бота",1,.82,0);
  GameTooltip:AddLine("Исключение из группы выполняется только по вашему нажатию. Результат проверяется по ростеру.",1,1,1,true);
  GameTooltip:AddLine("Резерв, альты и участники, принятые в состав, защищены.",.7,.85,.85,true);
  GameTooltip:Show();
 end);
 button:SetScript("OnLeave",function() GameTooltip:Hide(); end);
end

function UnBotSquadBuilderUI.RenderStatus(builder,summary,active)
 UnBotSquadBuilderUI.CreateProgress(builder);
 local model=UnBotSquadBuilderUI.ProgressModel(summary,active);
 if builder.statusCaption then builder.statusCaption:SetText(model.caption); end
 if builder.status then builder.status:SetText(model.text); end
 builder.summonProgress:SetValue(model.value);
 builder.summonProgress:SetStatusBarColor(unpack(model.color));
 builder.cleanupHint:SetText(model.hint or "");
 builder.cleanupHint:SetTextColor(unpack(model.color));
 local button=builder.offlineKickButton;
 button.cleanupTarget=model.target;
 if model.target then
  button:SetText(model.pending and "Проверяю исключение..." or ("Исключить "..model.target.name));
  if model.allowed then button:Enable();else button:Disable();end
  button:Show();
 else button:Hide();end
end


-- Compact summon options; debug disclosure changes layout only, never logging state.
function UnBotSquadBuilderUI.LayoutSettings(b)
 local delta=b.debugExpanded and 88 or 0;
 local function Place(o,anchor,x,y)
  if not o then return;end
  o:ClearAllPoints();o:SetPoint(anchor,b.frame,anchor,x,y);
 end
 local settings=b.settingsSection;
 if settings then
  settings.background:SetHeight(104+delta);
  Place(settings.line,"BOTTOMLEFT",18,158+delta);
  Place(settings.caption,"BOTTOMLEFT",22,136+delta);settings.caption:SetText("НАСТРОЙКИ ПРИЗЫВА");
 end
 Place(b.pveFallbackCheck,"BOTTOMLEFT",22,106+delta);
 Place(b.masterLootCheck,"BOTTOMLEFT",284,106+delta);
 Place(b.lootDistributionSettingsButton,"BOTTOMLEFT",432,106+delta);
 Place(b.raidBuffCheck,"BOTTOMLEFT",22,80+delta);
 Place(b.commandSettingsButton,"BOTTOMLEFT",284,80+delta);
 if b.commandSettingsButton then b.commandSettingsButton:SetWidth(174);b.commandSettingsButton:Show();end
 if b.lootSettingsButton then b.lootSettingsButton:Hide();end
 Place(b.debugToggle,"BOTTOMLEFT",22,54+delta);
 b.debugToggle:SetText(b.debugExpanded and "Дебаг [-]" or "Дебаг [+]");
 local checks={b.summonLogCheck,b.combatLogCheck,b.raidDebugCheck};
 for i=1,3 do
  local check=checks[i];
  if check then
   Place(check,"BOTTOMLEFT",34,110-(i-1)*27);
   if check.text then check.text:SetWidth(380);end
   check:SetHitRectInsets(0,-380,0,0);
   if b.debugExpanded then check:Show();else check:Hide();end
  end
 end
 if b.statusSection then
  Place(b.statusSection.background,"BOTTOMLEFT",16,166+delta);
  Place(b.statusSection.line,"BOTTOMLEFT",18,306+delta);
  Place(b.statusSection.caption,"BOTTOMLEFT",22,284+delta);
 end
 Place(b.statusCaption,"BOTTOMLEFT",22,268+delta);
 Place(b.status,"BOTTOMLEFT",22,208+delta);
 Place(b.summonProgress,"BOTTOMLEFT",22,254+delta);
 Place(b.cleanupHint,"BOTTOMLEFT",22,186+delta);
 Place(b.offlineKickButton,"BOTTOMRIGHT",-24,186+delta);
 Place(b.registryFreshnessText,"BOTTOMLEFT",22,170+delta);
 Place(b.registryFreshnessDays,"BOTTOMLEFT",230,168+delta);
 Place(b.registryRefreshButton,"BOTTOMLEFT",294,168+delta);
 if b.scrollFrame then
  b.scrollFrame:SetHeight(324-delta);b.scrollFrame:UpdateScrollChildRect();
  b.scrollFrame:SetVerticalScroll(math.min(b.scrollFrame:GetVerticalScroll() or 0,b.scrollFrame:GetVerticalScrollRange() or 0));
 end
 if b.rosterBackground then b.rosterBackground:SetHeight(384-delta);end
end

function UnBotSquadBuilderUI.RefreshSettings(b)
 if b.masterLootCheck then b.masterLootCheck:SetChecked(UnBotSquadConfig.forceMasterLootAfterSummon~=false);end
end

function UnBotSquadBuilderUI.CreateSettings(b)
 if b.settingsControlsReady then return;end
 b.settingsControlsReady=true;
 UnBotPVPSquad.FallbackCheck(b);
 if b.pveFallbackCheck and b.pveFallbackCheck.text then
  b.pveFallbackCheck:SetHitRectInsets(0,-232,0,0);b.pveFallbackCheck.text:SetWidth(232);
  b.pveFallbackCheck.text:SetText("PvP: добирать спеки из PvE");
 end
 if UnBotSquadCommands then UnBotSquadCommands.CreateButton(b);end
 local c=CreateFrame("CheckButton",nil,b.frame,"UICheckButtonTemplate");b.masterLootCheck=c;
 c:SetWidth(24);c:SetHeight(24);c:SetHitRectInsets(0,-106,0,0);
 c.text=c:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");
 c.text:SetPoint("LEFT",c,"RIGHT",-2,0);c.text:SetWidth(106);c.text:SetJustifyH("LEFT");c.text:SetText("Мастер-лут");
 c:SetScript("OnClick",function(self)
  UnBotSquadConfig.forceMasterLootAfterSummon=self:GetChecked() and true or false;
  if not UnBotSquadConfig.forceMasterLootAfterSummon and UnBotGunshipMasterLootDisarm then UnBotGunshipMasterLootDisarm(true);end
  if UnBotLootSettings then UnBotLootSettings.Refresh();end
 end);
 c:SetScript("OnEnter",function(self)
  GameTooltip:SetOwner(self,"ANCHOR_TOP");GameTooltip:AddLine("Ответственный за добычу при призыве",1,.82,0);
  GameTooltip:AddLine("После призыва UnBot включает мастер-лут на игрока. Само включение галочки не меняет текущий способ добычи.",1,1,1,true);
  GameTooltip:AddLine("Выбор босса, получатель, качества и остальные настройки — под шестерёнкой справа.",.7,.85,1,true);GameTooltip:Show();
 end);c:SetScript("OnLeave",function()GameTooltip:Hide();end);
 local gear=b.lootDistributionSettingsButton;
 if gear then
  gear:SetWidth(24);gear:SetHeight(24);gear:SetText("");
  gear:SetNormalTexture("Interface\\Icons\\INV_Misc_Gear_01");
  gear:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD");
  gear:SetScript("OnClick",function()UnBotLootSettings.Show();end);
  gear:SetScript("OnEnter",function(self)
   GameTooltip:SetOwner(self,"ANCHOR_TOP");GameTooltip:AddLine("Настройки добычи",1,.82,0);
   GameTooltip:AddLine("Мастер-лут, автогрид, подтверждение уничтожения и сбор добычи ботами — в одном окне.",1,1,1,true);GameTooltip:Show();
  end);gear:SetScript("OnLeave",function()GameTooltip:Hide();end);
 end
 local toggle=CreateFrame("Button",nil,b.frame,"UIPanelButtonTemplate");b.debugToggle=toggle;
 toggle:SetWidth(160);toggle:SetHeight(22);
 toggle:SetScript("OnClick",function()
  b.debugExpanded=not b.debugExpanded;UnBotSquadBuilderUI.LayoutSettings(b);
 end);
 UnBotSquadBuilderUI.RefreshSettings(b);UnBotSquadBuilderUI.LayoutSettings(b);
end
