-- Account characters are real player-owned characters controlled by Playerbot.
-- They deliberately share the main profile table so combat and roster helpers
-- can read class/spec data, but every destructive or random-selection path must
-- exclude profiles marked with accountAlt/protectedAccountCharacter.

UnBotAccountAlts = UnBotAccountAlts or {
	active = false,
	mode = nil,
	queue = {},
	index = 0,
	currentName = nil,
	stage = nil,
	nextTime = 0,
	stageUntil = 0,
	whoAttempts = 0,
	inviteAttempts = 0,
	addConfirmed = false,
	cleanupAttempts = 0,
	cleanupRemoveSent = false,
	originalMember = false,
	originalOnline = false,
	lastText = nil,
	discoveryActive = false,
	discoveryUntil = 0,
};

-- Preserve state across /reload-compatible module reinitialization.
UnBotAccountAlts.discoveryActive = UnBotAccountAlts.discoveryActive and true or false;
UnBotAccountAlts.discoveryUntil = tonumber(UnBotAccountAlts.discoveryUntil) or 0;

function UnBotAccountAlts.Trim(text)
	text = tostring(text or "");
	text = string.gsub(text, "^%s+", "");
	text = string.gsub(text, "%s+$", "");
	return text;
end

function UnBotAccountAlts.Key(text)
	text = string.lower(UnBotAccountAlts.Trim(text));
	-- Lua 5.1 lowercases ASCII only. Character names on the Russian client can
	-- contain Cyrillic, so apply the WotLK RU alphabet explicitly.
	local upper = {"А","Б","В","Г","Д","Е","Ё","Ж","З","И","Й","К","Л","М","Н","О","П","Р","С","Т","У","Ф","Х","Ц","Ч","Ш","Щ","Ъ","Ы","Ь","Э","Ю","Я"};
	local lower = {"а","б","в","г","д","е","ё","ж","з","и","й","к","л","м","н","о","п","р","с","т","у","ф","х","ц","ч","ш","щ","ъ","ы","ь","э","ю","я"};
	for index = 1, #upper do
		text = string.gsub(text, upper[index], lower[index]);
	end
	return text;
end

function UnBotAccountAlts.NormalizeFaction(value)
	local key = UnBotAccountAlts.Key(value);
	if (key == "alliance" or key == "альянс") then
		return "Alliance";
	elseif (key == "horde" or key == "орда") then
		return "Horde";
	end
	return nil;
end

function UnBotAccountAlts.CurrentFaction()
	return UnBotAccountAlts.NormalizeFaction(
		UnitFactionGroup and UnitFactionGroup("player") or nil
	);
end

function UnBotAccountAlts.OppositeFaction(faction)
	faction = UnBotAccountAlts.NormalizeFaction(faction);
	if (faction == "Alliance") then
		return "Horde";
	elseif (faction == "Horde") then
		return "Alliance";
	end
	return nil;
end

function UnBotAccountAlts.FactionLabel(faction)
	faction = UnBotAccountAlts.NormalizeFaction(faction);
	if (faction == "Alliance") then
		return "АЛЬЯНС";
	elseif (faction == "Horde") then
		return "ОРДА";
	end
	return "ФРАКЦИЯ ?";
end

function UnBotAccountAlts.FactionFromRace(value)
	local key = UnBotAccountAlts.Key(value);
	key = string.gsub(key, "[%s%-%_']", "");
	if (
		string.find(key, "human", 1, true)
		or string.find(key, "dwarf", 1, true)
		or string.find(key, "nightelf", 1, true)
		or string.find(key, "gnome", 1, true)
		or string.find(key, "draenei", 1, true)
		or string.find(key, "человек", 1, true)
		or string.find(key, "дворф", 1, true)
		or string.find(key, "ночнойэльф", 1, true)
		or string.find(key, "гном", 1, true)
		or string.find(key, "дреней", 1, true)
	) then
		return "Alliance";
	elseif (
		string.find(key, "bloodelf", 1, true)
		or string.find(key, "orc", 1, true)
		or string.find(key, "scourge", 1, true)
		or string.find(key, "undead", 1, true)
		or string.find(key, "tauren", 1, true)
		or string.find(key, "troll", 1, true)
		or string.find(key, "эльфкрови", 1, true)
		or string.find(key, "орк", 1, true)
		or string.find(key, "нежить", 1, true)
		or string.find(key, "отрекш", 1, true)
		or string.find(key, "таурен", 1, true)
		or string.find(key, "тролль", 1, true)
	) then
		return "Horde";
	end
	return nil;
end

function UnBotAccountAlts.SetFaction(name, faction, source)
	local resolved = UnBotAccountAlts.ResolveName(name, true) or UnBotAccountAlts.Trim(name);
	faction = UnBotAccountAlts.NormalizeFaction(faction);
	if (resolved == "" or not faction) then
		return nil;
	end
	local own = UnBotAccountAlts.EnsureStorage().characters[resolved];
	local linked = not own and UnBotAccountAlts.LinkedCharacter(resolved);
	local entry = own or linked or {};
	entry.faction = faction;
	entry.factionSource = source or entry.factionSource;
	entry.factionCheckedAt = time();
	entry.updatedAt = time();
	if (not linked) then UnBotAccountAlts.EnsureStorage().characters[resolved] = entry; end
	local profile = UnBotAccountAlts.GetProfile and UnBotAccountAlts.GetProfile(resolved);
	if (profile) then
		profile.accountFaction = faction;
	end
	return faction;
end

function UnBotAccountAlts.GetFaction(name)
	local resolved = UnBotAccountAlts.ResolveName(name, true) or UnBotAccountAlts.Trim(name);
	if (resolved == "") then
		return nil;
	end
	local entry = UnBotAccountAlts.EnsureStorage().characters[resolved];
	local linked = not UnBotAccountAlts.IsBoundToCurrentAccount(resolved) and UnBotAccountAlts.LinkedCharacter(resolved);
	entry = linked or entry;
	local profile = UnBotAccountAlts.GetProfile and UnBotAccountAlts.GetProfile(resolved);
	local faction = type(entry) == "table" and UnBotAccountAlts.NormalizeFaction(entry.faction) or nil;
	faction = faction or (profile and UnBotAccountAlts.NormalizeFaction(profile.accountFaction or profile.faction));
	faction = faction or (profile and UnBotAccountAlts.FactionFromRace(
		profile.raceFile or profile.raceLocalized or profile.raceName or profile.rawWho
	));
	if (
		not faction
		and type(entry) == "table"
		and UnBotAccountAlts.NormalizeFaction(entry.lastErrorPlayerFaction)
		and string.find(string.lower(tostring(entry.lastError or "")), "opposite faction", 1, true)
	) then
		faction = UnBotAccountAlts.OppositeFaction(entry.lastErrorPlayerFaction);
	end
	local unit = UnBotAccountAlts.FindUnit and UnBotAccountAlts.FindUnit(resolved);
	if (not faction and unit and UnitFactionGroup) then
		faction = UnBotAccountAlts.NormalizeFaction(UnitFactionGroup(unit));
	end
	if (faction and type(entry) == "table" and entry.faction ~= faction) then
		if (linked) then entry.faction = faction;
		else UnBotAccountAlts.SetFaction(resolved, faction, "profile-or-server"); end
	end
	return faction;
end

function UnBotAccountAlts.IsCurrentFaction(name)
	local faction = UnBotAccountAlts.GetFaction(name);
	local current = UnBotAccountAlts.CurrentFaction();
	-- Linked account lists may contain only names. Let the server validate an
	-- explicit named summon; known opposite-faction characters remain blocked.
	if (not faction and not UnBotAccountAlts.EnsureStorage().characters[UnBotAccountAlts.ResolveName(name,true) or name]
		and UnBotAccountAlts.LinkedCharacter(name)) then return true; end
	return faction ~= nil and current ~= nil and faction == current;
end

function UnBotAccountAlts.FactionRestrictionText(name)
	local faction = UnBotAccountAlts.GetFaction(name);
	if (faction) then
		return "Альт "..tostring(name).." относится к фракции "
			..UnBotAccountAlts.FactionLabel(faction)
			.." и недоступен персонажу фракции "
			..UnBotAccountAlts.FactionLabel(UnBotAccountAlts.CurrentFaction())..".";
	end
	return "Фракция альта "..tostring(name)
		.." ещё не подтверждена. Один раз войдите за этого персонажа с включённым UnBot, затем вернитесь и повторите поиск.";
end

function UnBotAccountAlts.SenderKey(text)
	text = tostring(text or "");
	text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "");
	text = string.gsub(text, "|r", "");
	text = string.match(text, "^([^-]+)") or text;
	return UnBotAccountAlts.Key(text);
end

function UnBotAccountAlts.Message(text)
	if (UnBotBotCenterMessage) then
		UnBotBotCenterMessage(text);
	elseif (DEFAULT_CHAT_FRAME) then
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99UnBot|r: "..tostring(text or ""));
	end
end

function UnBotAccountAlts.EnsureStorage()
	UnBotSquadConfig = UnBotSquadConfig or {};
	local storage = UnBotSquadConfig.accountAlts;
	if (type(storage) ~= "table") then
		storage = {};
		UnBotSquadConfig.accountAlts = storage;
	end
	storage.schemaVersion = math.max(8, tonumber(storage.schemaVersion) or 0);
	storage.characters = type(storage.characters) == "table" and storage.characters or {};
	return storage;
end

-- Read the logged-in character only; never connect another character to inspect it.
function UnBotAccountAlts.RecordPlayerSnapshot()
	local name = UnitName("player");
	local faction = UnBotAccountAlts.CurrentFaction();
	if (not name or name == "" or not faction) then return; end
	local storage = UnBotAccountAlts.EnsureStorage();
	storage.playerSnapshotsByRealm = storage.playerSnapshotsByRealm or {};
	local realmKey = UnBotAccountAlts.Key(GetRealmName and GetRealmName() or "unknown-realm");
	storage.playerSnapshotsByRealm[realmKey] = storage.playerSnapshotsByRealm[realmKey] or {};
	local snapshots = storage.playerSnapshotsByRealm[realmKey];
	local key = UnBotAccountAlts.Key(name);
	local snapshot = snapshots[key] or {};
	snapshot.faction = faction;
	snapshot.level = UnitLevel("player");
	snapshot.zoneName = GetRealZoneText and GetRealZoneText() or snapshot.zoneName;
	local subZoneName = GetSubZoneText and GetSubZoneText() or nil;
	snapshot.subZoneName = subZoneName and subZoneName ~= "" and subZoneName or nil;
	snapshot.updatedAt = time();
	snapshots[key] = snapshot;
end

function UnBotAccountAlts.GetPlayerSnapshot(name)
	local snapshots = UnBotAccountAlts.EnsureStorage().playerSnapshotsByRealm;
	local realmKey = UnBotAccountAlts.Key(GetRealmName and GetRealmName() or "unknown-realm");
	return snapshots and snapshots[realmKey] and snapshots[realmKey][UnBotAccountAlts.Key(name)];
end

function UnBotAccountAlts.BuildAccountIdentity(rows)
	local realmName = GetRealmName and GetRealmName() or "unknown-realm";
	local realmKey = UnBotAccountAlts.Key(realmName);
	local characterKeys = {};
	local characterNames = {};
	local function AddName(name)
		name = UnBotAccountAlts.Trim(name);
		local key = UnBotAccountAlts.Key(name);
		if (key ~= "" and not characterKeys[key]) then
			characterKeys[key] = true;
			characterNames[key] = name;
		end
	end
	AddName(UnitName("player"));
	for _, row in ipairs(type(rows) == "table" and rows or {}) do
		AddName(row.name);
	end
	local sortedKeys = {};
	for key in pairs(characterKeys) do
		table.insert(sortedKeys, key);
	end
	table.sort(sortedKeys);
	return {
		realmName = realmName,
		realmKey = realmKey,
		characterKeys = characterKeys,
		characterNames = characterNames,
		fingerprint = realmKey.."|"..table.concat(sortedKeys, ","),
		updatedAt = time(),
	};
end

function UnBotAccountAlts.ReconcileAccountBinding(identity)
	if (
		type(identity) ~= "table"
		or type(identity.characterKeys) ~= "table"
		or not identity.fingerprint
	) then
		return false;
	end
	local storage = UnBotAccountAlts.EnsureStorage();
	for name, entry in pairs(storage.characters) do
		if (type(entry) == "table") then
			local included = identity.characterKeys[UnBotAccountAlts.Key(name)] == true;
			entry.accountBindingActive = included;
			if (included) then
				entry.accountFingerprint = identity.fingerprint;
			end
		end
	end
	-- Bot roster intentionally omits the character currently logged in. It is
	-- nevertheless proven by the login itself and is part of the fingerprint.
	-- Rebind it now so another character can summon it immediately after a
	-- composition change, without requiring a second discovery pass.
	local playerName = UnitName("player");
	local playerKey = UnBotAccountAlts.Key(playerName);
	if (playerName and playerName ~= "" and identity.characterKeys[playerKey] == true) then
		local entry = storage.characters[playerName] or {};
		entry.enabled = entry.enabled ~= false;
		entry.discoverySource = entry.discoverySource or "bot-list";
		entry.discoveredAt = entry.discoveredAt or time();
		entry.accountFingerprint = identity.fingerprint;
		entry.accountBindingActive = true;
		entry.accountProof = "current-player";
		entry.updatedAt = time();
		storage.characters[playerName] = entry;
	end
	return true;
end

function UnBotAccountAlts.ValidateAccountBinding()
	local storage = UnBotAccountAlts.EnsureStorage();
	local identity = storage.accountIdentity;
	local playerKey = UnBotAccountAlts.Key(UnitName("player"));
	local realmKey = UnBotAccountAlts.Key(GetRealmName and GetRealmName() or "unknown-realm");
	local valid = type(identity) == "table"
		and type(identity.characterKeys) == "table"
		and identity.realmKey == realmKey
		and identity.characterKeys[playerKey] == true;
	storage.accountMismatch = not valid;
	if (valid) then
		storage.accountMismatchReason = nil;
		UnBotAccountAlts.ReconcileAccountBinding(identity);
	else
		storage.accountMismatchReason = type(identity) == "table"
			and "Сохранённый реестр альтов не принадлежит текущему аккаунту или серверу. Запустите автопоиск."
			or "Реестр альтов ещё не привязан к аккаунту. Запустите автопоиск.";
	end
	return valid;
end

function UnBotAccountAlts.ApplyAccountIdentity(rows)
	local storage = UnBotAccountAlts.EnsureStorage();
	local previous = storage.accountIdentity;
	local identity = UnBotAccountAlts.BuildAccountIdentity(rows);
	if (type(previous) == "table" and previous.fingerprint ~= identity.fingerprint) then
		storage.previousAccountFingerprint = previous.fingerprint;
		storage.accountIdentityChangedAt = time();
	end
	storage.accountIdentity = identity;
	storage.accountMismatch = false;
	storage.accountMismatchReason = nil;
	UnBotAccountAlts.ReconcileAccountBinding(identity);
	return identity;
end

function UnBotAccountAlts.IsBoundToCurrentAccount(name)
	local resolved = UnBotAccountAlts.ResolveName(name, true);
	local storage = UnBotAccountAlts.EnsureStorage();
	local identity = storage.accountIdentity;
	local entry = resolved and storage.characters[resolved];
	return not storage.accountMismatch
		and type(identity) == "table"
		and type(entry) == "table"
		and entry.accountBindingActive == true
		and entry.accountFingerprint == identity.fingerprint;
end

function UnBotAccountAlts.ResolveName(wanted, includeDisabled)
	local key = UnBotAccountAlts.Key(wanted);
	if (key == "") then
		return nil;
	end
	local storage = UnBotAccountAlts.EnsureStorage();
	for name, entry in pairs(storage.characters) do
		if (
			UnBotAccountAlts.Key(name) == key
			and (includeDisabled or type(entry) ~= "table" or entry.enabled ~= false)
		) then
			return name;
		end
	end
	local linked = UnBotAccountAlts.LinkedCharacter(wanted);
	if (linked and (includeDisabled or linked.enabled ~= false)) then return linked.name; end
	return nil;
end

function UnBotAccountAlts.LinkedCharacter(name)
	if (not UnBotLinkedAccounts or not UnBotLinkedAccounts.Storage) then return nil; end
	local wanted = UnBotAccountAlts.Key(name);
	if (wanted == "" or wanted == UnBotAccountAlts.Key(UnitName("player"))) then return nil; end
	local saved = UnBotLinkedAccounts.Storage();
	local match, matchedAccount;
	for _, accountKey in ipairs(saved.current or {}) do
		local account = saved.accounts and saved.accounts[accountKey];
		for _, character in pairs(account and account.characters or {}) do
			if (type(character) == "table" and type(character.name) == "string"
				and UnBotAccountAlts.Key(character.name) == wanted
				and (not match or character.name < match.name)) then match, matchedAccount = character, accountKey; end
		end
	end
	return match, matchedAccount;
end

function UnBotAccountAlts.CanAddToSquad(name)
	local faction, current = UnBotAccountAlts.GetFaction(name), UnBotAccountAlts.CurrentFaction();
	return not (faction and current and faction ~= current);
end

function UnBotAccountAlts.AccountNames(accountKey)
	if (not accountKey) then
		local names = {};
		for _, name in ipairs(UnBotAccountAlts.GetNames(true,false)) do
			if (UnBotAccountAlts.CanAddToSquad(name)) then names[#names+1] = name; end
		end
		return names;
	end
	local names, seen = {}, {};
	if (not UnBotLinkedAccounts or not UnBotLinkedAccounts.Current(accountKey)) then return names; end
	local account = UnBotLinkedAccounts.Storage().accounts[accountKey];
	for _, character in pairs(account and account.characters or {}) do
		local name = type(character) == "table" and character.name;
		local key = name and UnBotAccountAlts.Key(name);
		if (type(name) == "string" and key ~= "" and name ~= UNKNOWN and name ~= UNKNOWNOBJECT
			and not name:find("[%s%c|,;]") and key ~= UnBotAccountAlts.Key(UnitName("player"))
			and (not seen[key] or name < seen[key])) then
			seen[key] = name;
		end
	end
	for _, name in pairs(seen) do
		if (UnBotAccountAlts.CanAddToSquad(name)) then names[#names+1] = name; end
	end
	table.sort(names, function(a,b) return UnBotAccountAlts.Key(a) < UnBotAccountAlts.Key(b); end);
	return names;
end

function UnBotAccountAlts.IsListed(name)
	return UnBotAccountAlts.IsBoundToCurrentAccount(name) or UnBotAccountAlts.LinkedCharacter(name) ~= nil;
end

function UnBotAccountAlts.IsAlt(name, profile)
	if (type(name) == "table" and profile == nil) then
		profile = name;
		name = profile and profile.name;
	end
	if (profile and (profile.accountAlt or profile.protectedAccountCharacter)) then
		return true;
	end
	return UnBotAccountAlts.ResolveName(name, true) ~= nil;
end

function UnBotAccountAlts.IsEnabled(name)
	local resolved = UnBotAccountAlts.ResolveName(name, true);
	if (not resolved) then
		return false;
	end
	if (UnBotAccountAlts.Key(resolved) == UnBotAccountAlts.Key(UnitName("player"))) then
		return false;
	end
	local entry = UnBotAccountAlts.EnsureStorage().characters[resolved];
	if (not UnBotAccountAlts.IsBoundToCurrentAccount(resolved)) then
		local linked = UnBotAccountAlts.LinkedCharacter(resolved);
		return linked ~= nil and linked.enabled ~= false;
	end
	return type(entry) == "table"
		and entry.discoverySource == "bot-list"
		and UnBotAccountAlts.IsBoundToCurrentAccount(resolved)
		and entry.enabled ~= false;
end

function UnBotAccountAlts.IsServerDiscovered(name)
	local resolved = UnBotAccountAlts.ResolveName(name, true);
	local entry = resolved and UnBotAccountAlts.EnsureStorage().characters[resolved];
	return type(entry) == "table"
		and entry.discoverySource == "bot-list"
		and UnBotAccountAlts.IsBoundToCurrentAccount(resolved);
end

function UnBotAccountAlts.IsMaintenanceAllowed(name)
	local resolved = UnBotAccountAlts.ResolveName(name, true);
	local entry = resolved and UnBotAccountAlts.EnsureStorage().characters[resolved];
	return type(entry) == "table"
		and entry.discoverySource == "bot-list"
		and UnBotAccountAlts.IsBoundToCurrentAccount(resolved)
		and UnBotAccountAlts.IsCurrentFaction(resolved)
		and entry.allowJunkAndReagents == true;
end

function UnBotAccountAlts.SetMaintenanceAllowed(name, allowed)
	local resolved = UnBotAccountAlts.ResolveName(name, true);
	if (not resolved or not UnBotAccountAlts.IsServerDiscovered(resolved)) then
		UnBotAccountAlts.Message(
			"Разрешение не изменено: сначала подтвердите альта автоматическим поиском."
		);
		return false;
	end
	if (allowed and not UnBotAccountAlts.IsCurrentFaction(resolved)) then
		UnBotAccountAlts.Message(UnBotAccountAlts.FactionRestrictionText(resolved));
		return false;
	end
	local entry = UnBotAccountAlts.EnsureStorage().characters[resolved];
	entry.allowJunkAndReagents = allowed and true or false;
	entry.maintenancePermissionUpdatedAt = time();
	entry.updatedAt = time();
	UnBotAccountAlts.Message(
		resolved..": продажа серого хлама и закупка реагентов "
		..(entry.allowJunkAndReagents
			and "разрешены только из вкладки «Текущая группа»."
			or "снова запрещены защитой альта.")
	);
	if (UnBotSpecAuditRefresh) then UnBotSpecAuditRefresh(); end
	return true;
end

function UnBotAccountAlts.ToggleMaintenanceAllowed(name)
	return UnBotAccountAlts.SetMaintenanceAllowed(
		name,
		not UnBotAccountAlts.IsMaintenanceAllowed(name)
	);
end

-- Linked permission covers gray sale only; it never grants reagent restock.
function UnBotAccountAlts.GrayJunkEntry(name)
	local resolved = UnBotAccountAlts.ResolveName(name, true);
	if not resolved or UnBotAccountAlts.Key(resolved) == UnBotAccountAlts.Key(UnitName("player")) then return nil; end
	if UnBotAccountAlts.IsServerDiscovered(resolved) then
		return UnBotAccountAlts.EnsureStorage().characters[resolved], resolved;
	end
	local entry, accountKey = UnBotAccountAlts.LinkedCharacter(name);
	if entry then return entry, entry.name, accountKey; end
end

function UnBotAccountAlts.GrayJunkBinding(name)
	local entry, resolved, accountKey = UnBotAccountAlts.GrayJunkEntry(name);
	if not entry then return nil; end
	return UnBotAccountAlts.SummonContext().."|"..(accountKey and ("linked:"..accountKey) or ("own:"..tostring(entry.accountFingerprint)));
end

function UnBotAccountAlts.IsGrayJunkAllowed(name)
	local entry, resolved, accountKey = UnBotAccountAlts.GrayJunkEntry(name);
	if not entry then return false; end
	if not accountKey then return UnBotAccountAlts.IsMaintenanceAllowed(resolved); end
	-- This is a manual sale to an alt already in the roster, not a summon.
	-- Cross-faction linked characters may share a group on this server.
	return entry.allowGrayJunk == true;
end

function UnBotAccountAlts.SetGrayJunkAllowed(name, allowed, expectedAccountKey)
	local entry, resolved, accountKey = UnBotAccountAlts.GrayJunkEntry(name);
	if not entry or not accountKey or (expectedAccountKey and expectedAccountKey ~= accountKey) then
		UnBotAccountAlts.Message("Разрешение продажи не изменено: альт отсутствует в текущих связанных аккаунтах."); return false;
	end
	entry.allowGrayJunk = allowed and true or false;
	entry.grayJunkPermissionUpdatedAt = time();
	UnBotAccountAlts.Message(resolved..": продажа серого хлама "..(entry.allowGrayJunk and "разрешена" or "запрещена")..". Закупка реагентов не включена.");
	if UnBotChatRouting and UnBotChatRouting.RefreshLinked then UnBotChatRouting.RefreshLinked(); end
	if UnBotSpecAuditRefresh then UnBotSpecAuditRefresh(); end
	return true;
end

function UnBotAccountAlts.GetProfile(name)
	local resolved = UnBotAccountAlts.ResolveName(name, true) or name;
	return resolved
		and UnBotBotRegistry
		and UnBotBotRegistry.bots
		and UnBotBotRegistry.bots[resolved]
		or nil;
end

function UnBotAccountAlts.GetNames(includeDisabled, currentFactionOnly)
	local names = {};
	for name, entry in pairs(UnBotAccountAlts.EnsureStorage().characters) do
		if (
			UnBotAccountAlts.Key(name) ~= UnBotAccountAlts.Key(UnitName("player"))
			and
			UnBotAccountAlts.IsBoundToCurrentAccount(name)
			and (not currentFactionOnly or UnBotAccountAlts.IsCurrentFaction(name))
			and (
				includeDisabled
				or (
				type(entry) == "table"
				and entry.discoverySource == "bot-list"
				and entry.enabled ~= false
				)
			)
		) then
			table.insert(names, name);
		end
	end
	table.sort(names, function(left, right)
		return UnBotAccountAlts.Key(left) < UnBotAccountAlts.Key(right);
	end);
	return names;
end

function UnBotAccountAlts.FindUnit(name)
	if (not name) then
		return nil;
	end
	if (GetNumRaidMembers and GetNumRaidMembers() > 0) then
		for i = 1, GetNumRaidMembers(), 1 do
			local unit = "raid"..i;
			if (GetRaidRosterInfo(i) == name or UnitName(unit) == name) then
				return unit;
			end
		end
	else
		for i = 1, (GetNumPartyMembers and GetNumPartyMembers() or 0), 1 do
			local unit = "party"..i;
			if (UnitName(unit) == name) then
				return unit;
			end
		end
	end
	return nil;
end

function UnBotAccountAlts.IsInGroup(name)
	return UnBotAccountAlts.FindUnit(name) ~= nil;
end

function UnBotAccountAlts.IsOnline(name)
	local unit = UnBotAccountAlts.FindUnit(name);
	return unit and UnitIsConnected(unit) and true or false;
end

function UnBotAccountAlts.GetCurrentGroupNames()
	local names = {};
	for _, name in ipairs(UnBotAccountAlts.GetNames(true)) do
		local unit = UnBotAccountAlts.FindUnit(name);
		if (unit and UnitIsConnected(unit)) then
			table.insert(names, name);
		end
	end
	return names;
end

function UnBotAccountAlts.RecountCheckpoint(checkpoint)
	if (type(checkpoint) ~= "table" or type(checkpoint.names) ~= "table") then
		return;
	end
	local total = 0;
	local completed = 0;
	for name in pairs(checkpoint.names) do
		total = total + 1;
		if (checkpoint.completed and checkpoint.completed[name]) then
			completed = completed + 1;
		end
	end
	checkpoint.total = total;
	checkpoint.completedCount = completed;
	checkpoint.updatedAt = time();
	if (total == 0) then
		checkpoint.active = false;
	end
end

function UnBotAccountAlts.RemoveFromCheckpoint(name, checkpoint)
	if (type(checkpoint) ~= "table" or type(checkpoint.names) ~= "table") then
		return;
	end
	checkpoint.names[name] = nil;
	if (type(checkpoint.completed) == "table") then
		checkpoint.completed[name] = nil;
	end
	UnBotAccountAlts.RecountCheckpoint(checkpoint);
end

function UnBotAccountAlts.ProtectProfile(name, whoInfo, rawWho)
	name = UnBotAccountAlts.Trim(name);
	if (name == "" or name == UnitName("player")) then
		return nil;
	end
	UnBotSquadConfig = UnBotSquadConfig or {};
	UnBotBotRegistry = UnBotBotRegistry or {};
	UnBotBotRegistry.bots = UnBotBotRegistry.bots or {};
	local profile = UnBotBotRegistry.bots[name] or {
		name = name,
		firstSeen = time(),
		seenCount = 0,
	};
	profile.name = name;
	profile.accountAlt = true;
	profile.protectedAccountCharacter = true;
	profile.rotationAllowed = false;
	profile.source = "account-alt";
	profile.forceJunkCycle = nil;
	if (profile.rotationFlags) then
		profile.rotationFlags.quarantinedAt = nil;
		profile.rotationFlags.quarantinedUntil = nil;
		profile.rotationFlags.quarantineReason = nil;
		profile.rotationFlags.unavailableUntil = nil;
		profile.rotationFlags.soulstoneUntil = nil;
		profile.rotationFlags.soulstoneUsedAt = nil;
	end
	if (whoInfo) then
		profile.className = whoInfo.className or profile.className;
		profile.specName = whoInfo.specName or profile.specName;
		profile.level = whoInfo.level or profile.level;
		profile.gearScore = whoInfo.gearScore or profile.gearScore;
		profile.zoneName = whoInfo.zoneName or profile.zoneName;
		if (whoInfo.specName) then
			profile.specCheckedAt = time();
		end
		profile.lastSeen = time();
		profile.seenCount = (tonumber(profile.seenCount) or 0) + 1;
	end
	if (rawWho and rawWho ~= "") then
		profile.rawWho = rawWho;
	end
	UnBotBotRegistry.bots[name] = profile;
	UnBotSquadConfig.botRegistry = UnBotBotRegistry;
	local storage = UnBotAccountAlts.EnsureStorage();
	local linked, accountKey = UnBotAccountAlts.LinkedCharacter(name);
	if (linked and not storage.characters[name]) then
		profile.source, profile.linkedAccountKey = "linked-account-alt", accountKey;
		profile.accountFaction = UnBotAccountAlts.GetFaction(name) or profile.accountFaction;
		return profile;
	end
	local entry = storage.characters[name] or {};
	entry.enabled = entry.enabled ~= false;
	entry.addedAt = entry.addedAt or time();
	entry.updatedAt = time();
	if (whoInfo) then
		entry.lastError = nil;
	end
	storage.characters[name] = entry;
	local faction = UnBotAccountAlts.FactionFromRace(
		profile.raceFile or profile.raceLocalized or profile.raceName or profile.rawWho
	);
	if (not faction) then
		local unit = UnBotAccountAlts.FindUnit(name);
		faction = unit and UnitFactionGroup
			and UnBotAccountAlts.NormalizeFaction(UnitFactionGroup(unit)) or nil;
	end
	if (faction) then
		UnBotAccountAlts.SetFaction(name, faction, "who-or-unit");
	end
	UnBotAccountAlts.RemoveFromCheckpoint(name, UnBotSquadConfig.junkMaintenanceCheckpoint);
	UnBotAccountAlts.RemoveFromCheckpoint(name, UnBotSquadConfig.bagSpaceAuditCheckpoint);
	return profile;
end

function UnBotAccountAlts.RefreshProfileFromUnit(name)
	local resolved = UnBotAccountAlts.ResolveName(name, true) or UnBotAccountAlts.Trim(name);
	local unit = UnBotAccountAlts.FindUnit(resolved);
	if (not unit) then
		return UnBotAccountAlts.GetProfile(resolved), false;
	end
	local localizedClass, classFile = UnitClass(unit);
	local classNames = {
		WARRIOR = "warrior",
		PALADIN = "paladin",
		HUNTER = "hunter",
		ROGUE = "rogue",
		PRIEST = "priest",
		DEATHKNIGHT = "dk",
		SHAMAN = "shaman",
		MAGE = "mage",
		WARLOCK = "warlock",
		DRUID = "druid",
	};
	local level = UnitLevel(unit);
	if (not level or level < 1) then
		level = nil;
	end
	local profile = UnBotAccountAlts.ProtectProfile(resolved, nil, nil);
	if (not profile) then
		return nil, false;
	end
	profile.className = classNames[classFile] or profile.className;
	profile.level = level or profile.level;
	profile.classLocalized = localizedClass or profile.classLocalized;
	profile.classFile = classFile or profile.classFile;
	local raceLocalized, raceFile = UnitRace(unit);
	profile.raceLocalized = raceLocalized or profile.raceLocalized;
	profile.raceFile = raceFile or profile.raceFile;
	profile.sex = UnitSex(unit) or profile.sex;
	profile.lastSeen = time();
	for _, slot in ipairs((UnBotSquadConfig and UnBotSquadConfig.slots) or {}) do
		if (slot.accountAltName == resolved and profile.className) then
			slot.className = profile.className;
			slot.specKey = profile.specName or slot.specKey or "any";
			slot.label = resolved.." — "..profile.className
				..(profile.specName and (" - "..profile.specName) or "");
		end
	end
	return profile, profile.className ~= nil;
end

function UnBotAccountAlts.HandlePassiveWho(message, sender)
	if (not UnBotParseBotWho) then
		return false;
	end
	local name = UnBotAccountAlts.ResolveName(sender, true);
	local profile = name and UnBotAccountAlts.GetProfile(name) or nil;
	if (not name or not profile or not profile.accountAlt) then
		return false;
	end
	local whoInfo = UnBotParseBotWho(message);
	if (not whoInfo or not whoInfo.className) then
		return false;
	end
	UnBotAccountAlts.ProtectProfile(name, whoInfo, message);
	UnBotAccountAlts.RefreshProfileFromUnit(name);
	if (UnBotSpecAuditRefresh) then UnBotSpecAuditRefresh(); end
	if (UnBotSquadBuilderRefresh) then UnBotSquadBuilderRefresh(); end
	return true;
end

function UnBotAccountAlts.SetEnabled(name, enabled)
	local resolved = UnBotAccountAlts.ResolveName(name, true);
	if (not resolved) then
		return false;
	end
	if (enabled and not UnBotAccountAlts.IsServerDiscovered(resolved)) then
		UnBotAccountAlts.Message(
			resolved..": имя не подтверждено серверным Bot roster. Запустите автоматический поиск."
		);
		return false;
	end
	local entry = UnBotAccountAlts.EnsureStorage().characters[resolved];
	entry.enabled = enabled and true or false;
	entry.updatedAt = time();
	UnBotAccountAlts.Message(
		"Альт "..resolved..(entry.enabled
			and " включён: его можно добавлять в составы только по имени."
			or " отключён: сохранённые именные слоты не будут его призывать.")
	);
	if (UnBotSpecAuditRefresh) then UnBotSpecAuditRefresh(); end
	if (UnBotSquadBuilderRefresh) then UnBotSquadBuilderRefresh(); end
	return true;
end

function UnBotAccountAlts.ToggleEnabled(name)
	return UnBotAccountAlts.SetEnabled(name, not UnBotAccountAlts.IsEnabled(name));
end

function UnBotAccountAlts.Forget(name)
	local resolved = UnBotAccountAlts.ResolveName(name, true);
	if (not resolved) then
		UnBotAccountAlts.Message("Альт не найден.");
		return false;
	end
	UnBotAccountAlts.EnsureStorage().characters[resolved] = nil;
	local profile = UnBotAccountAlts.GetProfile(resolved);
	if (profile) then
		profile.accountAlt = nil;
		profile.protectedAccountCharacter = nil;
		profile.rotationAllowed = nil;
		if (profile.source == "account-alt") then
			profile.source = "account-alt-removed";
		end
	end
	for index = #(UnBotSquadConfig.slots or {}), 1, -1 do
		if (UnBotSquadConfig.slots[index].accountAltName == resolved) then
			table.remove(UnBotSquadConfig.slots, index);
		end
	end
	UnBotAccountAlts.Message(
		resolved..": удалён из списка альтов. Профиль бота не удалён из общего реестра."
	);
	if (UnBotSpecAudit and UnBotSpecAudit.selectedAlt == resolved) then
		UnBotSpecAudit.selectedAlt = nil;
	end
	if (UnBotSpecAuditRefresh) then UnBotSpecAuditRefresh(); end
	if (UnBotSquadBuilderRefresh) then UnBotSquadBuilderRefresh(); end
	return true;
end

-- A faction refusal is a skipped named position, never a successful summon.
function UnBotAccountAlts.SquadFactionStatus(name)
	if UnBotAccountAlts.CanAddToSquad(name) then return nil; end
	return "|cffff6060"..tostring(name).." — нельзя призвать: другая фракция|r";
end

function UnBotAccountAlts.ParseSquadPart(part)
	part = UnBotAccountAlts.Trim(part);
	local wanted = string.match(part, "^@(.+)$");
	if (not wanted) then
		return nil, nil;
	end
	local name = UnBotAccountAlts.ResolveName(wanted, true);
	if (not name) then
		return nil, "альт не найден: "..tostring(wanted)..". Добавьте его на вкладке Альты.";
	end
	if (not UnBotAccountAlts.IsEnabled(name)) then
		return nil, "альт "..name.." отключён на вкладке Альты";
	end
	-- Keep named positions intact; the squad controller skips known enemies
	-- and lets the server resolve an unknown faction on the first add.
	local profile = UnBotAccountAlts.GetProfile(name)
		or UnBotAccountAlts.ProtectProfile(name, nil, nil);
	if (not profile) then
		return nil, "защищённый профиль альта "..name.." недоступен";
	end
	return {
		className = profile.className or "unknown",
		specKey = profile.specName or "any",
		specAliases = profile.specName and {profile.specName} or {},
		need = 1,
		have = 0,
		names = {},
		accountAltName = name,
	};
end

function UnBotAccountAlts.BuildSquadMenu(addFunction)
	local menu = {};
	for _, name in ipairs(UnBotAccountAlts.AccountNames()) do
		local altName = name;
		local profile = UnBotAccountAlts.GetProfile(name) or {};
		table.insert(menu, {
			text = altName.." — "..tostring(profile.className or "?")
				.." / "..tostring(profile.specName or "без специализации")
				..", ур. "..tostring(profile.level or "?"),
			notCheckable = true,
			func = function() addFunction(altName,true); end,
		});
	end
	if (#menu == 0) then
		table.insert(menu, {
			text = "Нет доступных альтов своего аккаунта",
			disabled = true,
			notCheckable = true,
		});
	end
	table.insert(menu, {
		text = "|cff69ccf0Управление альтами...|r",
		notCheckable = true,
		func = function()
			if (UnBotBotCenterShow) then
				UnBotBotCenterShow("alts");
				if (UnBotSpecAudit and UnBotSpecAudit.ShowAltsTab) then UnBotSpecAudit.ShowAltsTab("own"); end
			end
		end,
	});
	return menu;
end

function UnBotAccountAlts.BuildLinkedSquadMenu(addFunction, addAccountFunction)
	local menu = {};
	local saved = UnBotLinkedAccounts and UnBotLinkedAccounts.Storage();
	for _, key in ipairs(saved and saved.current or {}) do
		local accountKey = key;
		local account = saved.accounts[key];
		local names, children = UnBotAccountAlts.AccountNames(key), {};
		for _, name in ipairs(names) do
			local altName = name;
			children[#children+1] = {text=name, notCheckable=true, func=function() addFunction(altName,true); end};
		end
		if (#children == 0) then children[1] = {text="Нет доступных альтов этого аккаунта",disabled=true,notCheckable=true}; end
		menu[#menu+1] = {text=tostring(account.name or key).." ("..#names..")",notCheckable=true,hasArrow=true,menuList=children,
			func=function() addAccountFunction(accountKey); end};
	end
	if (#menu == 0) then menu[1] = {text="Нет сохранённых связанных аккаунтов",disabled=true,notCheckable=true}; end
	menu[#menu+1] = {text="Управление связанными аккаунтами...",notCheckable=true,func=function()
		if (UnBotBotCenterShow) then UnBotBotCenterShow("alts"); end
		if (UnBotSpecAudit and UnBotSpecAudit.ShowAltsTab) then UnBotSpecAudit.ShowAltsTab("linked"); end
	end};
	return menu;
end

function UnBotAccountAlts.OtherAutomationActive(ignoreEquip)
	return (
        (UnBotAltSetups and UnBotAltSetups.job) or
		(not ignoreEquip and UnBotAccountAlts.equipUpgrades and UnBotAccountAlts.equipUpgrades.active)
		or (UnBotLinkedAccounts and UnBotLinkedAccounts.job)
		or (UnBotBotScanner and UnBotBotScanner.active)
		or (UnBotDKSpecBalance and UnBotDKSpecBalance.active)
		or (UnBotJunkCleaner and UnBotJunkCleaner.active)
		or (UnBotFastJunkRaid and UnBotFastJunkRaid.active)
		or (UnBotSpecSummon and UnBotSpecSummon.active)
		or (UnBotIsSquadSpecCheckActive and UnBotIsSquadSpecCheckActive())
		or (UnBotBuffCycle and UnBotBuffCycle.active)
	);
end

function UnBotAccountAlts.ParseNames(text)
	local names = {};
	local seen = {};
	for name in string.gmatch(tostring(text or ""), "[^,%s;]+") do
		name = UnBotAccountAlts.Trim(name);
		local key = UnBotAccountAlts.Key(name);
		if (key ~= "" and not seen[key] and name ~= UnitName("player")) then
			seen[key] = true;
			table.insert(names, name);
		end
	end
	return names;
end

function UnBotAccountAlts.RosterClassName(label)
	label = string.lower(UnBotAccountAlts.Trim(label));
	label = string.gsub(label, "%s+", " ");
	local classes = {
		warrior = "warrior",
		paladin = "paladin",
		hunter = "hunter",
		rogue = "rogue",
		priest = "priest",
		shaman = "shaman",
		mage = "mage",
		warlock = "warlock",
		druid = "druid",
		["death knight"] = "dk",
		deathknight = "dk",
		dk = "dk",
	};
	return classes[label];
end

function UnBotAccountAlts.ParseBotRoster(message)
	message = tostring(message or "");
	message = string.gsub(message, "|c%x%x%x%x%x%x%x%x", "");
	message = string.gsub(message, "|r", "");
	local body = string.match(message, "[Bb]ot roster:%s*(.*)");
	if (body == nil) then
		return nil;
	end
	local rows = {};
	local seen = {};
	local playerKey = UnBotAccountAlts.Key(UnitName("player"));
	for part in string.gmatch(body..",", "([^,]*),") do
		local marker, name, classLabel = string.match(
			part,
			"^%s*([%+%-])([^%s,]+)%s+(.+)%s*$"
		);
		name = UnBotAccountAlts.Trim(name);
		classLabel = UnBotAccountAlts.Trim(classLabel);
		local key = UnBotAccountAlts.Key(name);
		if (marker and key ~= "" and key ~= playerKey and not seen[key]) then
			seen[key] = true;
			table.insert(rows, {
				name = name,
				className = UnBotAccountAlts.RosterClassName(classLabel),
				classLabel = classLabel,
				online = marker == "+",
			});
		end
	end
	return rows;
end

function UnBotAccountAlts.RegisterDiscovered(rows)
	local names = {};
	local storage = UnBotAccountAlts.EnsureStorage();
	local identity = storage.accountIdentity;
	for _, row in ipairs(type(rows) == "table" and rows or {}) do
		local snapshot = UnBotAccountAlts.GetPlayerSnapshot(row.name);
		local profile = UnBotAccountAlts.ProtectProfile(row.name, {
			className = row.className,
			level = snapshot and snapshot.level,
		}, nil);
		if (profile) then
			local entry = storage.characters[row.name] or {};
			entry.discoverySource = "bot-list";
			entry.discoveredAt = time();
			entry.rosterClassName = row.className;
			entry.rosterClassLabel = row.classLabel;
			entry.rosterOnline = row.online and true or false;
			entry.accountFingerprint = identity and identity.fingerprint or nil;
			entry.accountBindingActive = identity and true or false;
			entry.updatedAt = time();
			storage.characters[row.name] = entry;
			if (snapshot and snapshot.faction) then
				UnBotAccountAlts.SetFaction(row.name, snapshot.faction, "player-login");
			end
			table.insert(names, row.name);
		end
	end
	return names;
end

function UnBotAccountAlts.HandleBotRoster(message)
	if (not UnBotAccountAlts.discoveryActive) then
		return false;
	end
	local rows = UnBotAccountAlts.ParseBotRoster(message);
	if (rows == nil) then
		return false;
	end
	UnBotAccountAlts.discoveryActive = false;
	UnBotAccountAlts.discoveryUntil = 0;
	if ((GetNumPartyMembers and GetNumPartyMembers() > 0)
		or (GetNumRaidMembers and GetNumRaidMembers() > 0)) then
		UnBotAccountAlts.lastText = "Автопоиск отменён: группа изменилась во время ожидания Bot roster.";
		UnBotAccountAlts.Message(UnBotAccountAlts.lastText);
		if (UnBotSpecAuditRefresh) then UnBotSpecAuditRefresh(); end
		return true;
	end
	UnBotAccountAlts.ApplyAccountIdentity(rows);
	local names = UnBotAccountAlts.RegisterDiscovered(rows);
	if (#names == 0) then
		UnBotAccountAlts.lastText = "Сервер вернул пустой Bot roster.";
		UnBotAccountAlts.Message("Автопоиск завершён: персонажи аккаунта не найдены.");
		if (UnBotSpecAuditRefresh) then UnBotSpecAuditRefresh(); end
		return true;
	end
	UnBotAccountAlts.lastText = "Найдено альтов: "..tostring(#names)..". Без подключения и телепортации.";
	UnBotAccountAlts.Message(
		"Автопоиск нашёл "..tostring(#names).." персонаж(ей): "
		..table.concat(names, ", ")..". Список сохранён без подключения и телепортации."
	);
	for _, name in ipairs(names) do
		if (not UnBotAccountAlts.GetFaction(name)) then
			UnBotAccountAlts.Message(UnBotAccountAlts.FactionRestrictionText(name));
		end
	end
	if (UnBotSpecAuditRefresh) then UnBotSpecAuditRefresh(); end
	if (UnBotSquadBuilderRefresh) then UnBotSquadBuilderRefresh(); end
	return true;
end

function UnBotAccountAlts.StartWho(name)
	if (not name) then
		return false;
	end
    local request = UnBotAccountAlts.setupSummon
    if request then
        local unit = UnBotAccountAlts.FindUnit(name)
        if request.context==UnBotAltSetups.Context() and unit and UnitIsConnected(unit) and UnitGUID(unit)==request.guid
            and UnBotAccountAlts.IsListed(name) and UnBotAccountAlts.IsEnabled(name)
            and UnBotAccountAlts.CanAddToSquad(name) and not InCombatLockdown()
            and not UnitAffectingCombat("player") and not UnitAffectingCombat(unit) then
            local send = MultiBot and MultiBot._throttleOrig or SendChatMessage
            request.sent = pcall(send,"summon","WHISPER",nil,name)
            request.sentAt = GetTime()
        end
        UnBotAccountAlts.Advance()
        return true
    end
	if (UnBotAccountAlts.mode == "summon") then
		local profile = UnBotAccountAlts.RefreshProfileFromUnit(name);
		UnBotAltStrategies.OnSummon(name, "account-alt-direct", true);
		UnBotAccountAlts.Advance(
			"Альт "..name
			.." подключён по точному имени; summon и follow поставлены в очередь"
			..(profile and profile.className and (" (класс: "..profile.className..")") or "")..".",
			false
		);
		return true;
	end
	UnBotAccountAlts.whoAttempts = 1;
	SendChatMessage("who", "WHISPER", nil, name);
	UnBotAccountAlts.stage = "wait_who";
	UnBotAccountAlts.stageUntil = GetTime() + 6;
	UnBotAccountAlts.nextTime = GetTime() + 0.25;
	return true;
end

function UnBotAccountAlts.HandleAddResult(message)
	if (
		not UnBotAccountAlts.active
		or UnBotAccountAlts.stage ~= "wait_join"
		or not UnBotAccountAlts.currentName
	) then
		return false;
	end
	message = tostring(message or "");
	message = string.gsub(message, "|c%x%x%x%x%x%x%x%x", "");
	message = string.gsub(message, "|r", "");
	local name, result = string.match(message, "[Aa]dd:%s*([^%s]+)%s*%-%s*(.+)");
	if (
		not name
		or UnBotAccountAlts.SenderKey(name)
			~= UnBotAccountAlts.SenderKey(UnBotAccountAlts.currentName)
	) then
		return false;
	end
	result = UnBotAccountAlts.Trim(result);
	if (string.find(string.lower(result), "^ok")) then
		UnBotAccountAlts.SetFaction(
			UnBotAccountAlts.currentName,
			UnBotAccountAlts.CurrentFaction(),
			"server-add-ok"
		);
		UnBotAccountAlts.addConfirmed = true;
		if (UnBotAccountAlts.IsOnline(UnBotAccountAlts.currentName)) then
			UnBotAccountAlts.StartWho(UnBotAccountAlts.currentName);
		end
		return true;
	end
	if (string.find(string.lower(result), "opposite faction", 1, true)) then
		local faction = UnBotAccountAlts.SetFaction(
			UnBotAccountAlts.currentName,
			UnBotAccountAlts.OppositeFaction(UnBotAccountAlts.CurrentFaction()),
			"server-opposite-faction"
		);
		UnBotAccountAlts.MarkError(
			UnBotAccountAlts.currentName,
			"opposite faction: "..tostring(result)
		);
		UnBotAccountAlts.Advance(
			"Альт "..tostring(UnBotAccountAlts.currentName).." помечен: "
			..UnBotAccountAlts.FactionLabel(faction)
			..". Для текущей фракции он скрыт из меню состава; повторные add не отправляются.",
			false
		);
		return true;
	end
	UnBotAccountAlts.MarkError(
		UnBotAccountAlts.currentName,
		"server bot add rejected: "..result
	);
	UnBotAccountAlts.Advance(
		"Имя "..tostring(UnBotAccountAlts.currentName)
		.." не добавлено как альт: сервер ответил «"..result
		.."». Приглашение обычному игроку не отправлялось.",
		false
	);
	return true;
end

function UnBotAccountAlts.StartDiscovery()
	if (UnBotAccountAlts.discoveryActive) then
		UnBotAccountAlts.Stop("Автопоиск альтов остановлен пользователем.");
		return false;
	end
	if (UnBotAccountAlts.active or UnBotAccountAlts.OtherAutomationActive()) then
		UnBotAccountAlts.Message("Сначала завершите другую автоматизацию UnBot.");
		return false;
	end
	if (
		(GetNumPartyMembers and GetNumPartyMembers() > 0)
		or (GetNumRaidMembers and GetNumRaidMembers() > 0)
	) then
		UnBotAccountAlts.Message(
			"Автопоиск альтов работает только вне группы: Bot roster может включать случайных ботов текущего состава."
		);
		return false;
	end
	UnBotAccountAlts.centerRefreshHint = nil;
	UnBotAccountAlts.discoveryActive = true;
	UnBotAccountAlts.RecordPlayerSnapshot();
	UnBotAccountAlts.discoveryUntil = GetTime() + 8;
	UnBotAccountAlts.lastDiscoveryContext = UnBotAccountAlts.Key(GetRealmName and GetRealmName() or "unknown-realm")
		.."|"..UnBotAccountAlts.Key(UnitName("player"));
	UnBotAccountAlts.lastDiscoveryAt = GetTime();
	UnBotAccountAlts.lastText = "Запрашиваю Bot roster у сервера...";
	SendChatMessage(".playerbot bot list", "SAY");
	UnBotAccountAlts.Message("Автопоиск альтов: запрашиваю список персонажей аккаунта...");
	if (UnBotSpecAuditRefresh) then UnBotSpecAuditRefresh(); end
	return true;
end

-- Opening a window validates saved evidence locally. Server discovery is manual.
function UnBotAccountAlts.RefreshForCenter()
 local valid=UnBotAccountAlts.ValidateAccountBinding();
 UnBotAccountAlts.centerRefreshHint=valid
  and "Альты: сохранённый список. Поиск запускается кнопкой «Найти альтов автоматически»."
  or "Альты не подтверждены для текущего персонажа/сервера. Запустите «Найти альтов автоматически».";
 return false;
end

function UnBotAccountAlts.StatusText()
	if (UnBotAccountAlts.discoveryActive) then
		return "Альты: жду Bot roster от сервера...";
	end
	if (not UnBotAccountAlts.active) then
		local storage = UnBotAccountAlts.EnsureStorage();
		if (storage.accountMismatch) then
			return storage.accountMismatchReason or "Реестр альтов заблокирован до автопоиска.";
		end
		return UnBotAccountAlts.lastText or "Готово.";
	end
	return "Альты: "..tostring(UnBotAccountAlts.index).."/"
		..tostring(#UnBotAccountAlts.queue).." — "
		..tostring(UnBotAccountAlts.currentName or "подготовка").." ("
		..tostring(UnBotAccountAlts.stage or "...")..").";
end

function UnBotAccountAlts.MarkError(name, text)
	local resolved = UnBotAccountAlts.ResolveName(name, true);
	if (resolved) then
		local entry = UnBotAccountAlts.EnsureStorage().characters[resolved] or UnBotAccountAlts.LinkedCharacter(resolved);
		if (not entry) then return; end
		entry.lastError = text;
		entry.lastErrorAt = time();
		entry.lastErrorPlayerFaction = UnBotAccountAlts.CurrentFaction();
		entry.updatedAt = time();
	end
end

function UnBotAccountAlts.CleanupName(name)
	if (not name) then
		return;
	end
	UnBotAccountAlts.KickFromGroup(name, true);
	SendChatMessage(".playerbot bot remove "..name, "SAY");
	UnBotAccountAlts.KickFromGroup(name, false);
end

function UnBotAccountAlts.KickFromGroup(name, sendLeave)
	if (not name) then
		return;
	end
	if (sendLeave) then
		SendChatMessage("leave", "WHISPER", nil, name);
	end
	-- This private 3.3.5 client is inconsistent between party and raid. Send
	-- the bounded kick by both exact name and the current unit token.
	UninviteUnit(name);
	local unit = UnBotAccountAlts.FindUnit(name);
	if (unit) then
		UninviteUnit(unit);
	end
end

function UnBotAccountAlts.BeginCleanup(name)
	UnBotAccountAlts.cleanupAttempts = 1;
	UnBotAccountAlts.cleanupRemoveSent = false;
	UnBotAccountAlts.KickFromGroup(name, true);
	UnBotAccountAlts.stage = "cleanup_kick";
	UnBotAccountAlts.stageUntil = GetTime() + 5;
	UnBotAccountAlts.nextTime = GetTime() + 0.9;
end

function UnBotAccountAlts.FinishCleanupStep(failed)
	local name = UnBotAccountAlts.currentName;
	if (failed) then
		UnBotAccountAlts.MarkError(name, "остался офлайн в ростере после 8 попыток удаления");
		UnBotAccountAlts.Message(
			"Альт "..tostring(name)
			.." остался офлайн в ростере после 8 попыток. Используйте «Убрать из группы» ещё раз."
		);
	end
	if (UnBotAccountAlts.mode == "remove") then
		UnBotAccountAlts.Finish(failed
			and ("Не удалось полностью убрать альта "..tostring(name).." из ростера.")
			or ("Альт "..tostring(name).." полностью убран из группы и отключён."));
		return;
	end
	UnBotAccountAlts.index = UnBotAccountAlts.index + 1;
	UnBotAccountAlts.currentName = nil;
	UnBotAccountAlts.stage = "begin";
	UnBotAccountAlts.nextTime = GetTime() + 0.4;
	if (UnBotSpecAuditRefresh) then UnBotSpecAuditRefresh(); end
end

function UnBotAccountAlts.RestoreOriginalState(name)
	if (UnBotAccountAlts.originalMember) then
		SendChatMessage("stay", "WHISPER", nil, name);
		SendChatMessage(".playerbot bot remove "..name, "SAY");
	else
		UnBotAccountAlts.CleanupName(name);
	end
end

function UnBotAccountAlts.Finish(text)
	UnBotAccountAlts.setupSummon = nil;
	UnBotAccountAlts.active = false;
	UnBotAccountAlts.mode = nil;
	UnBotAccountAlts.queue = {};
	UnBotAccountAlts.index = 0;
	UnBotAccountAlts.currentName = nil;
	UnBotAccountAlts.stage = nil;
	UnBotAccountAlts.nextTime = 0;
	UnBotAccountAlts.stageUntil = 0;
	UnBotAccountAlts.whoAttempts = 0;
	UnBotAccountAlts.inviteAttempts = 0;
	UnBotAccountAlts.addConfirmed = false;
	UnBotAccountAlts.cleanupAttempts = 0;
	UnBotAccountAlts.cleanupRemoveSent = false;
	UnBotAccountAlts.originalMember = false;
	UnBotAccountAlts.originalOnline = false;
	UnBotAccountAlts.lastText = text or "Готово.";
	if (text) then
		UnBotAccountAlts.Message(text);
	end
	if (UnBotSpecAuditRefresh) then UnBotSpecAuditRefresh(); end
	if (UnBotSquadBuilderRefresh) then UnBotSquadBuilderRefresh(); end
end

function UnBotAccountAlts.Stop(text)
	if UnBotAccountAlts.setupSummon then UnBotAccountAlts.setupSummon.cancelled = true; end
	if (UnBotAccountAlts.discoveryActive) then
		UnBotAccountAlts.discoveryActive = false;
		UnBotAccountAlts.discoveryUntil = 0;
		UnBotAccountAlts.lastText = text or "Автопоиск альтов остановлен.";
		UnBotAccountAlts.Message(UnBotAccountAlts.lastText);
		if (UnBotSpecAuditRefresh) then UnBotSpecAuditRefresh(); end
		return;
	end
	if (
		UnBotAccountAlts.active
		and UnBotAccountAlts.currentName
		and not UnBotAccountAlts.originalOnline
		and not UnBotAccountAlts.setupSummon
	) then
		UnBotAccountAlts.CleanupName(UnBotAccountAlts.currentName);
	end
	UnBotAccountAlts.Finish(text or "Операция с альтами остановлена.");
end

function UnBotAccountAlts.Advance(text, cleanup)
	local name = UnBotAccountAlts.currentName;
	if (text) then
		UnBotAccountAlts.Message(text);
		UnBotAccountAlts.lastText = text;
	end
	if (cleanup and name and not UnBotAccountAlts.originalOnline and not UnBotAccountAlts.setupSummon) then
		UnBotAccountAlts.BeginCleanup(name);
		return;
	end
	UnBotAccountAlts.index = UnBotAccountAlts.index + 1;
	UnBotAccountAlts.currentName = nil;
	UnBotAccountAlts.stage = "begin";
	UnBotAccountAlts.nextTime = GetTime() + 0.4;
	if (UnBotSpecAuditRefresh) then UnBotSpecAuditRefresh(); end
end

function UnBotAccountAlts.StartQueue(names, mode, setupSummon)
	if (UnBotAccountAlts.active) then
		UnBotAccountAlts.Stop("Операция с альтами остановлена пользователем.");
		return false;
	end
	if (UnBotAccountAlts.OtherAutomationActive()) then
		UnBotAccountAlts.Message("Сначала завершите другую автоматизацию UnBot.");
		return false;
	end
	if (type(names) ~= "table" or #names == 0) then
		UnBotAccountAlts.Message("Укажите хотя бы одно имя альта.");
		return false;
	end
	UnBotAccountAlts.active = true;
	UnBotAccountAlts.mode = mode or "import";
	UnBotAccountAlts.setupSummon = setupSummon;
	UnBotAccountAlts.queue = names;
	UnBotAccountAlts.index = 1;
	UnBotAccountAlts.currentName = nil;
	UnBotAccountAlts.stage = "begin";
	UnBotAccountAlts.nextTime = GetTime();
	if (UnBotAccountAlts.mode == "summon") then
		UnBotAccountAlts.lastText = "Именной призыв альта запущен.";
		UnBotAccountAlts.Message(
			"Альт будет подключён и призван по точному имени без проверки специализации."
		);
	else
		UnBotAccountAlts.lastText = "Проверка сведений об альтах запущена.";
		UnBotAccountAlts.Message(
			"Альты: обновляю сведения для "..tostring(#names)
			.." персонаж(ей) по одному, только уже онлайн в группе. Без подключения и телепортации."
		);
	end
	return true;
end

function UnBotAccountAlts.StartImport(text)
	UnBotAccountAlts.Message(
		"Ручное добавление альтов отключено. Используйте «Найти автоматически»: список берётся только из серверного Bot roster."
	);
	return false;
end

function UnBotAccountAlts.Recheck(name)
	local resolved = UnBotAccountAlts.ResolveName(name, true);
	if (not resolved or not UnBotAccountAlts.IsServerDiscovered(resolved)) then
		UnBotAccountAlts.Message("Перепроверять можно только альтов, найденных серверным Bot roster.");
		return false;
	end
	local faction = UnBotAccountAlts.GetFaction(resolved);
	if (faction and not UnBotAccountAlts.IsCurrentFaction(resolved)) then
		UnBotAccountAlts.Message(UnBotAccountAlts.FactionRestrictionText(resolved));
		return false;
	end
	if (not UnBotAccountAlts.IsOnline(resolved)) then
		UnBotAccountAlts.Message("Сведения не обновлены: "..resolved.." не онлайн в текущей группе. Подключение и телепортация не выполняются.");
		return false;
	end
	return UnBotAccountAlts.StartQueue({resolved}, "recheck");
end

function UnBotAccountAlts.Summon(name)
	if UnBotAltStrategies and (UnBotAltStrategies.active or #UnBotAltStrategies.queue>0) then
		UnBotAccountAlts.Message("Дождитесь завершения сверки стратегий или остановите её в редакторе."); return false;
	end
	local resolved = UnBotAccountAlts.ResolveName(name, true);
	if (not resolved or not UnBotAccountAlts.IsEnabled(resolved)) then
		UnBotAccountAlts.Message("Выбранный альт не найден или отключён.");
		return false;
	end
	if (not UnBotAccountAlts.IsCurrentFaction(resolved)) then
		UnBotAccountAlts.Message(UnBotAccountAlts.FactionRestrictionText(resolved));
		return false;
	end
	return UnBotAccountAlts.StartQueue({resolved}, "summon");
end

function UnBotAccountAlts.RemoveFromGroup(name)
	local resolved = UnBotAccountAlts.ResolveName(name, true);
	if (not resolved) then
		UnBotAccountAlts.Message("Альт не найден.");
		return false;
	end
	if (UnBotAccountAlts.active or UnBotAccountAlts.discoveryActive) then
		UnBotAccountAlts.Message("Сначала завершите текущую операцию с альтами.");
		return false;
	end
	if (UnBotAccountAlts.OtherAutomationActive()) then
		UnBotAccountAlts.Message("Сначала завершите другую автоматизацию UnBot.");
		return false;
	end
	UnBotAccountAlts.active = true;
	UnBotAccountAlts.mode = "remove";
	UnBotAccountAlts.queue = {resolved};
	UnBotAccountAlts.index = 1;
	UnBotAccountAlts.currentName = resolved;
	UnBotAccountAlts.originalMember = false;
	UnBotAccountAlts.originalOnline = false;
	UnBotAccountAlts.BeginCleanup(resolved);
	UnBotAccountAlts.Message(resolved..": удаляю из ростера, затем отключаю. Не более 8 попыток.");
	if (UnBotSpecAuditRefresh) then UnBotSpecAuditRefresh(); end
	return true;
end

function UnBotAccountAlts.BeginCurrent()
	local name = UnBotAccountAlts.queue[UnBotAccountAlts.index];
	if (not name) then
		UnBotAccountAlts.Finish("Проверка альтов завершена.");
		return;
	end
	local resolved = UnBotAccountAlts.ResolveName(name, true);
	name = resolved or name;
	UnBotAccountAlts.currentName = name;
	local knownFaction = resolved and UnBotAccountAlts.GetFaction(name) or nil;
	if (knownFaction and not UnBotAccountAlts.IsCurrentFaction(name)) then
		UnBotAccountAlts.Advance(
			"Альт "..tostring(name).." ["
			..UnBotAccountAlts.FactionLabel(knownFaction)
			.."] пропущен: текущая фракция другая, команда add не отправлена.",
			false
		);
		return;
	end
    local request = UnBotAccountAlts.setupSummon
    if request then
        if request.context~=UnBotAltSetups.Context() or not UnBotAccountAlts.IsListed(name) or not UnBotAccountAlts.IsEnabled(name)
            or not UnBotAccountAlts.CanAddToSquad(name) or InCombatLockdown() or UnitAffectingCombat("player") then
            UnBotAccountAlts.Advance()
            return
        end
        local raids = GetNumRaidMembers()
        if not UnBotAccountAlts.IsInGroup(name)
            and ((raids>0 and raids>=40) or (raids==0 and GetNumPartyMembers()>=4)) then
            request.full = true
            UnBotAccountAlts.Advance()
            return
        end
    end
	UnBotAccountAlts.originalMember = UnBotAccountAlts.IsInGroup(name);
	UnBotAccountAlts.originalOnline = UnBotAccountAlts.IsOnline(name);
	UnBotAccountAlts.whoAttempts = 0;
	UnBotAccountAlts.inviteAttempts = 0;
	UnBotAccountAlts.addConfirmed = false;
	if (UnBotAccountAlts.mode ~= "summon" and not UnBotAccountAlts.originalOnline) then
		UnBotAccountAlts.Advance("Альт "..name.." не онлайн в группе: проверка пропущена без подключения.", false);
		return;
	end
	if (UnBotAccountAlts.IsOnline(name)) then
		if (resolved) then
			UnBotAccountAlts.StartWho(name);
		else
			UnBotAccountAlts.MarkError(name, "имя уже принадлежит онлайн-игроку в группе");
			UnBotAccountAlts.Advance(
				"Имя "..tostring(name)
				.." уже находится в группе как обычный игрок и не было найдено в Bot roster. Проверка отменена.",
				false
			);
		end
	else
		if (
			not request and GetNumPartyMembers and GetNumPartyMembers() >= 4
			and GetNumRaidMembers and GetNumRaidMembers() == 0
			and ConvertToRaid
		) then
			ConvertToRaid();
		end
		local send = request and MultiBot and MultiBot._throttleOrig or SendChatMessage;
		UnBotAccountAlts.stage = "wait_join";
		UnBotAccountAlts.stageUntil = GetTime() + 12;
		UnBotAccountAlts.nextTime = GetTime() + 1.25;
		if not pcall(send,".playerbot bot add "..name,"SAY") then UnBotAccountAlts.Advance(); end
	end
	if (UnBotSpecAuditRefresh) then UnBotSpecAuditRefresh(); end
end

function UnBotAccountAlts.HandleWho(message, sender)
	if (
		not UnBotAccountAlts.active
		or UnBotAccountAlts.stage ~= "wait_who"
		or UnBotAccountAlts.SenderKey(sender)
			~= UnBotAccountAlts.SenderKey(UnBotAccountAlts.currentName)
		or not UnBotParseBotWho
	) then
		return false;
	end
	local whoInfo = UnBotParseBotWho(message);
	if (not whoInfo or not whoInfo.className) then
		return false;
	end
	local profile = UnBotAccountAlts.ProtectProfile(sender, whoInfo, message);
	if (not profile) then
		return false;
	end
	if (UnBotAccountAlts.mode == "summon") then
		UnBotAltStrategies.OnSummon(sender, "account-alt-who", true);
		UnBotAccountAlts.Advance(
			"Альт "..sender.." подключён и призван: "
			..tostring(profile.className).." / "..tostring(profile.specName or "без специализации")
			..", уровень "..tostring(profile.level or "?")..".",
			false
		);
	else
		UnBotAccountAlts.Advance(
			"Альт сохранён и защищён: "..sender.." — "
			..tostring(profile.className).." / "..tostring(profile.specName or "без специализации")
			..", уровень "..tostring(profile.level or "?")..", GS "
			..tostring(profile.gearScore or "?")..".",
			true
		);
	end
	return true;
end

UnBotAccountAlts.frame = UnBotAccountAlts.frame
	or CreateFrame("Frame", "UnBotAccountAltsFrame");
UnBotAccountAlts.frame:RegisterEvent("ADDON_LOADED");
UnBotAccountAlts.frame:RegisterEvent("PLAYER_ENTERING_WORLD");
UnBotAccountAlts.frame:RegisterEvent("CHAT_MSG_WHISPER");
UnBotAccountAlts.frame:RegisterEvent("CHAT_MSG_SYSTEM");
UnBotAccountAlts.frame:RegisterEvent("PARTY_MEMBERS_CHANGED");
UnBotAccountAlts.frame:RegisterEvent("RAID_ROSTER_UPDATE");
UnBotAccountAlts.frame:RegisterEvent("PLAYER_REGEN_DISABLED");
UnBotAccountAlts.frame:RegisterEvent("PLAYER_LEAVING_WORLD");
UnBotAccountAlts.frame:SetScript("OnEvent", function(self, event, arg1, arg2)
	UnBotAccountAlts.EquipUpgradesEvent(event, arg1, arg2);
	if (event == "PLAYER_ENTERING_WORLD") then
		UnBotAccountAlts.RecordPlayerSnapshot();
		return;
	end
	if (event == "ADDON_LOADED" and arg1 == "UnBotCustom") then
		local storage = UnBotAccountAlts.EnsureStorage();
		local bindingValid = UnBotAccountAlts.ValidateAccountBinding();
		if (not bindingValid and next(storage.characters) ~= nil) then
			UnBotAccountAlts.lastText = storage.accountMismatchReason;
			UnBotAccountAlts.Message(storage.accountMismatchReason);
		end
		for _, name in ipairs(UnBotAccountAlts.GetNames(true)) do
			local profile = UnBotAccountAlts.GetProfile(name);
			if (profile) then
				UnBotAccountAlts.ProtectProfile(name, nil, nil);
			end
		end
		return;
	end
	if (event == "CHAT_MSG_WHISPER") then
		if (not UnBotAccountAlts.HandleWho(arg1, arg2)) then
			UnBotAccountAlts.HandlePassiveWho(arg1, arg2);
		end
	elseif (event == "CHAT_MSG_SYSTEM") then
		if (not UnBotAccountAlts.HandleBotRoster(arg1)) then
			UnBotAccountAlts.HandleAddResult(arg1);
		end
	elseif (
		UnBotAccountAlts.active
		and UnBotAccountAlts.stage == "wait_join"
		and UnBotAccountAlts.IsOnline(UnBotAccountAlts.currentName)
		and (
			UnBotAccountAlts.addConfirmed
			or UnBotAccountAlts.ResolveName(UnBotAccountAlts.currentName, true)
		)
	) then
		UnBotAccountAlts.StartWho(UnBotAccountAlts.currentName);
	end
end);

UnBotAccountAlts.frame:SetScript("OnUpdate", function()
	UnBotAccountAlts.SummonRefreshTick();
	UnBotAccountAlts.EquipUpgradesTick();
	local now = GetTime();
	if (UnBotAccountAlts.discoveryActive) then
		if (now >= (UnBotAccountAlts.discoveryUntil or 0)) then
			UnBotAccountAlts.discoveryActive = false;
			UnBotAccountAlts.discoveryUntil = 0;
			UnBotAccountAlts.lastText = "Сервер не ответил на bot list за 8 секунд.";
			UnBotAccountAlts.Message(
				"Автопоиск альтов остановлен: сервер не прислал строку Bot roster за 8 секунд."
			);
			if (UnBotSpecAuditRefresh) then UnBotSpecAuditRefresh(); end
		end
		return;
	end
	if (not UnBotAccountAlts.active) then
		return;
	end
	if (now < (UnBotAccountAlts.nextTime or 0)) then
		return;
	end
	if (UnBotAccountAlts.stage == "begin") then
		UnBotAccountAlts.BeginCurrent();
	elseif (UnBotAccountAlts.stage == "wait_join") then
		if (
			UnBotAccountAlts.IsOnline(UnBotAccountAlts.currentName)
			and (
				UnBotAccountAlts.addConfirmed
				or UnBotAccountAlts.ResolveName(UnBotAccountAlts.currentName, true)
			)
		) then
			UnBotAccountAlts.StartWho(UnBotAccountAlts.currentName);
		elseif (now >= (UnBotAccountAlts.stageUntil or 0)) then
			local name = UnBotAccountAlts.currentName;
			UnBotAccountAlts.MarkError(name, "не вошёл в группу за 12 секунд");
			if (
				not UnBotAccountAlts.setupSummon and not UnBotAccountAlts.addConfirmed
				and not UnBotAccountAlts.ResolveName(name, true)
			) then
				SendChatMessage(".playerbot bot remove "..name, "SAY");
			end
			UnBotAccountAlts.Advance(
				"Альт "..tostring(name).." не подключился за 12 секунд; перехожу дальше.",
				UnBotAccountAlts.addConfirmed
					or UnBotAccountAlts.ResolveName(name, true) ~= nil
			);
		else
			UnBotAccountAlts.nextTime = now + 0.25;
		end
	elseif (UnBotAccountAlts.stage == "wait_who") then
		if (now >= (UnBotAccountAlts.stageUntil or 0)) then
			if ((UnBotAccountAlts.whoAttempts or 0) < 3) then
				UnBotAccountAlts.whoAttempts = (UnBotAccountAlts.whoAttempts or 0) + 1;
				SendChatMessage("who", "WHISPER", nil, UnBotAccountAlts.currentName);
				UnBotAccountAlts.stageUntil = now + 6;
			else
				local name = UnBotAccountAlts.currentName;
				UnBotAccountAlts.MarkError(name, "не ответил на who после 3 попыток");
				UnBotAccountAlts.Advance(
					"Альт "..tostring(name).." не ответил на who после трёх попыток; не сохранён.",
					true
				);
			end
		else
			UnBotAccountAlts.nextTime = now + 0.25;
		end
	elseif (UnBotAccountAlts.stage == "cleanup_kick") then
		if (not UnBotAccountAlts.IsInGroup(UnBotAccountAlts.currentName)) then
			SendChatMessage(
				".playerbot bot remove "..UnBotAccountAlts.currentName,
				"SAY"
			);
			UnBotAccountAlts.cleanupRemoveSent = true;
			UnBotAccountAlts.stage = "cleanup_remove";
			UnBotAccountAlts.stageUntil = now + 3;
			UnBotAccountAlts.nextTime = now + 0.75;
		elseif (
			(UnBotAccountAlts.cleanupAttempts or 0) < 4
			and now < (UnBotAccountAlts.stageUntil or 0)
		) then
			UnBotAccountAlts.cleanupAttempts = (UnBotAccountAlts.cleanupAttempts or 0) + 1;
			UnBotAccountAlts.KickFromGroup(UnBotAccountAlts.currentName, true);
			UnBotAccountAlts.nextTime = now + 1;
		else
			SendChatMessage(
				".playerbot bot remove "..UnBotAccountAlts.currentName,
				"SAY"
			);
			UnBotAccountAlts.cleanupRemoveSent = true;
			UnBotAccountAlts.stage = "cleanup_remove";
			UnBotAccountAlts.stageUntil = now + 4;
			UnBotAccountAlts.nextTime = now + 0.75;
		end
	elseif (UnBotAccountAlts.stage == "cleanup_remove") then
		if (UnBotAccountAlts.IsInGroup(UnBotAccountAlts.currentName)) then
			if (
				(UnBotAccountAlts.cleanupAttempts or 0) < 8
				and now < (UnBotAccountAlts.stageUntil or 0)
			) then
				UnBotAccountAlts.cleanupAttempts = (UnBotAccountAlts.cleanupAttempts or 0) + 1;
				UnBotAccountAlts.KickFromGroup(UnBotAccountAlts.currentName, false);
				UnBotAccountAlts.nextTime = now + 0.75;
			else
				UnBotAccountAlts.FinishCleanupStep(true);
			end
		else
			UnBotAccountAlts.FinishCleanupStep(false);
		end
	end
end);

SLASH_UNBOTACCOUNTALTS1 = "/ubalts";
SLASH_UNBOTACCOUNTALTS2 = "/unbotalts";
SlashCmdList["UNBOTACCOUNTALTS"] = function(message)
	local command, rest = string.match(UnBotAccountAlts.Trim(message), "^(%S*)%s*(.-)$");
	command = string.lower(command or "");
	if (command == "add" or command == "добавить") then
		UnBotAccountAlts.StartImport(rest);
	elseif (command == "scan" or command == "find" or command == "найти") then
		UnBotAccountAlts.StartDiscovery();
	elseif (command == "summon" or command == "призвать") then
		UnBotAccountAlts.Summon(rest);
	elseif (command == "stop" or command == "стоп") then
		if UnBotAltStrategies then UnBotAltStrategies.Stop(); end
		if (UnBotAccountAlts.active or UnBotAccountAlts.discoveryActive) then
			UnBotAccountAlts.Stop("Операция с альтами остановлена пользователем.");
		else
			UnBotAccountAlts.Message("Операция с альтами сейчас не выполняется.");
		end
	elseif (command == "list" or command == "список") then
		local names = UnBotAccountAlts.GetNames(true);
		UnBotAccountAlts.Message("Альты аккаунта: "..(#names > 0 and table.concat(names, ", ") or "список пуст")..".");
	else
		if (UnBotBotCenterShow) then
			UnBotBotCenterShow("alts");
		else
			UnBotAccountAlts.Message("Использование: /ubalts scan | summon Имя | stop | list");
		end
	end
end;

-- Personal alt strategies. Kept in an existing XML-loaded file so /reload works
-- even when the client has cached the TOC/XML file list.
UnBotAltStrategies = UnBotAltStrategies or {queue={}, observed={}, results={}, nextSend=0};
do
local S = UnBotAltStrategies;

function S.Context()
	local storage = UnBotAccountAlts.EnsureStorage();
	return tostring(GetRealmName and GetRealmName() or "").."|"..tostring(storage.accountIdentity and storage.accountIdentity.fingerprint or "");
end

function S.Entry(name)
	local resolved = UnBotAccountAlts.ResolveName(name, true);
	if not resolved then return; end
	if UnBotAccountAlts.IsBoundToCurrentAccount(resolved) then
		local entry = UnBotAccountAlts.EnsureStorage().characters[resolved];
		if type(entry)=="table" and entry.discoverySource=="bot-list" then return entry, resolved; end
	end
	-- Keep linked choices in their existing account record, never in the own
	-- account list. LinkedCharacter ignores archived/unlinked accounts.
	local entry, accountKey = UnBotAccountAlts.LinkedCharacter(resolved);
	if type(entry)=="table" then return entry, entry.name, accountKey; end
end

function S.Key(key)
	return type(key)=="string" and #key>0 and #key<=48 and key:match("^[a-z0-9][a-z0-9 ]*$") and key or nil;
end

function S.CopyMap(map)
	local copy, count = {}, 0;
	for key,value in pairs(type(map)=="table" and map or {}) do
		if S.Key(key) and type(value)=="boolean" then
			count=count+1; if count>100 then return nil; end
			copy[key]=value;
		end
	end
	return copy;
end

function S.HasChoices(profile)
	for _,channel in ipairs({"co","nc"}) do
		for key,value in pairs(profile and type(profile[channel])=="table" and profile[channel] or {}) do
			if S.Key(key) and type(value)=="boolean" then return true; end
		end
	end
	return false;
end

function S.OnSummon(name, source, transport)
	local entry, resolved, linkedAccountKey = S.Entry(name);
	if not entry then return false; end
	local profile = entry.strategyProfile;
	local desired = type(profile)=="table" and profile.enabled==true and (S.HasChoices(profile) or profile.samplePreset) and profile or nil;
	local automatic=not linkedAccountKey and UnBotStrategySurvey and UnBotStrategySurvey.HasLibrary();
	if not desired and not transport and not automatic then return false; end
	return S.Enqueue(name, "apply", desired, transport, nil, nil, automatic);
end

function S.Explain(channel,key,value)
	local on,off;
	if key=="grind" then
		on=channel=="nc" and "Сам ищет и атакует мобов; может начать бой без игрока." or "Сам ищет противников для продолжения боя.";
		off="Не ищет мобов самостоятельно; остальные стратегии продолжают работать.";
	elseif key=="attack weak" then
		on=channel=="nc" and "При входе в бой сам выбирает цель для атаки." or "В бою сам выбирает, кого атаковать.";
		off="Самостоятельный выбор цели отключён; цель задают игрок или другие стратегии.";
	elseif key=="loot" then
		on=channel=="nc" and "Подбирает доступную добычу после боя." or "Подбирает доступную добычу во время боя.";
		off=channel=="nc" and "Не подбирает добычу после боя." or "Не подбирает добычу во время боя.";
	elseif key=="quest" then on="Берёт и сдаёт доступные задания вместе с игроком; нужно место в журнале."; off="Не берёт и не сдаёт задания автоматически.";
	elseif key=="follow" then on="Следует за игроком."; off="Автоматическое следование этой стратегией отключено.";
	elseif key=="stay" then on="Остаётся на месте."; off="Стратегия стояния отключена; движение задают другие стратегии.";
	elseif key=="attack force" then on=channel=="co" and "Для атаки нужно вручную указать цель." or "Сам не действует вне боя; нужно ручное управление."; off="Разрешена работа остальных автоматических стратегий.";
	elseif key=="heal" then on="Лечит раненых участников вместо нанесения урона."; off="Роль лекаря этой стратегией отключена.";
	elseif key=="tank" then on="Танкует одну цель."; off="Роль танка одной цели отключена.";
	elseif key=="dps" then on="Включает стратегию dps, если сервер поддерживает её у этого класса. Другие стратегии урона работают независимо."; off="Отключает только dps; классовые стратегии и dps assist сохраняются.";
	elseif key=="food" then on="После боя восстанавливает здоровье и ману едой и питьём."; off="Автоматический отдых с едой и питьём отключён.";
	elseif key=="dps assist" or key=="tank assist" then on="Помогает соответствующей роли с её боевой целью."; off="Автоматическая помощь этой роли отключена.";
	else on=S.labels[key] or key; off="Отключено: "..(S.labels[key] or key).."."; end
	if value==nil then return channel.." "..key..": оставлено серверу. При включении: "..on; end
	return channel.." "..(value and "+" or "-")..key..": "..(value and on or off);
end

function S.Ready(job)
	if job.context~=S.Context() or job.name==UnitName("player") then return false; end
	if job.mode=="copy" or job.mode=="survey" then
		if job.mode=="copy" and not S.Entry(job.target) then return false; end
		local profile=UnBotAccountAlts.GetProfile(job.name);
		if not profile or (UnBotIsAccountAltProfile and UnBotIsAccountAltProfile(job.name,profile)) then return false; end
	else
		local entry, resolved, linkedAccountKey = S.Entry(job.name);
		if not entry or linkedAccountKey~=job.linkedAccountKey or not UnBotAccountAlts.IsCurrentFaction(job.name) then return false; end
	end
	local unit=UnBotAccountAlts.FindUnit(job.name);
	return unit and UnitIsConnected(unit) and not (UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit)) and true or false;
end

function S.Enqueue(name, mode, desired, transport, target, section, automatic)
	if UnBotStrategySurvey and UnBotStrategySurvey.active and mode~="survey" then return false; end
	local linkedAccountKey;
	if mode~="copy" and mode~="survey" then local entry; entry,name,linkedAccountKey=S.Entry(name); if not entry then return false; end end
	local job={name=name, linkedAccountKey=linkedAccountKey, mode=mode, target=target, section=section, context=S.Context(),
		co=S.CopyMap(desired and desired.co), nc=S.CopyMap(desired and desired.nc),
		transport=transport and {"summon","follow"} or {}, index=1,
		notBefore=GetTime()+1.5, queuedAt=GetTime(), replies={}, changed={}, commands=0};
	if not job.co or not job.nc or not S.Ready(job) then return false; end
	if S.active and S.active.name==name and S.active.mode==mode and S.active.context==job.context then return false; end
	for _,pending in ipairs(S.queue) do if pending.name==name and pending.mode==mode and pending.context==job.context then return false; end end
	if #S.queue>=20 then UnBotAccountAlts.Message("Стратегии: очередь заполнена; повторите применение после её завершения."); return false; end
	if mode=="apply" and desired then job.revision=desired.revision; job.requiredPreset=desired.samplePreset; end
	job.automatic=automatic==true;
	job.detectAutomatic=mode=="edit" and UnBotStrategySurvey and UnBotStrategySurvey.HasLibrary() or false;
	if job.automatic then
		local profile=S.Entry(name).strategyProfile;
		job.personalRevision=type(profile)=="table" and (tonumber(profile.revision) or 0) or 0;
		job.personalEnabled=type(profile)=="table" and profile.enabled==true or false;
		if S.ui and S.ui.loaded and S.ui.name==name and S.ui.context==job.context then job.previewBase=S.ui.autoPreview; end
	end
	job.sections={};
	for _,channel in ipairs({"co","nc"}) do
		if (mode=="inspect" or mode=="edit" or mode=="survey") or (mode=="copy" and section==channel) or (mode=="apply" and (job.automatic or next(job[channel]))) then
			table.insert(job.sections,channel);
		end
	end
	table.insert(S.queue,job);
	return true;
end

function S.Finish(text, ok)
	local job=S.active; if not job then return; end
	S.results[job.context.."|"..(job.target or job.name)]=text;
	if job.mode=="apply" then
		local entry=S.Entry(job.name);
		if ok and entry and type(entry.strategyProfile)=="table" and entry.strategyProfile.revision==job.revision then
			entry.strategyProfile.lastVerifiedAt=time();
		end
		if ok and entry and job.autoSelection and entry.autoStrategy==job.autoSelection then entry.autoStrategy.lastVerifiedAt=time(); end
		UnBotAccountAlts.Message("Альт "..job.name..": "..text);
	end
	S.active=nil;
	if job.mode=="survey" and UnBotStrategySurvey then UnBotStrategySurvey.OnSnapshot(job,ok,text); end
	if S.RefreshPanel then S.RefreshPanel(); end
end

function S.Stop()
	if UnBotStrategySurvey and UnBotStrategySurvey.active then UnBotStrategySurvey.Stop(); end
	S.queue={};
	if S.active then S.Finish("сверка остановлена пользователем; повторных команд нет.",false); end
end

function S.Diff(desired, actual, channel)
	local keys, differences={},{};
	for key in pairs(desired) do table.insert(keys,key); end
	table.sort(keys);
	for _,key in ipairs(keys) do
		if (actual[key]==true)~=desired[key] then table.insert(differences,(desired[key] and "+" or "-")..key); end
	end
	local chunks, current={},"";
	for _,token in ipairs(differences) do
		if #current+#token+1>210 then table.insert(chunks,channel.." "..current); current=""; end
		current=current=="" and token or current..","..token;
	end
	if current~="" then table.insert(chunks,channel.." "..current); end
	return chunks, differences;
end

function S.Send(job, command, waitChannel)
	if not S.Ready(job) then S.Finish("персонаж недоступен; сверка остановлена.",false); return; end
	job.commands=job.commands+1;
	if job.commands>16 then S.Finish("достигнут предел команд; сверка остановлена.",false); return; end
	-- Set the wait state before calling the API: replies are never used as
	-- proof until a query was actually sent. No catch-up bursts after a stall.
	job.waitChannel=waitChannel; job.deadline=GetTime()+6;
	S.nextSend=GetTime()+1.5;
	local ok=pcall(SendChatMessage,command,"WHISPER",nil,job.name);
	if not ok then S.Finish("клиент отклонил команду; сверка остановлена.",false); end
end

function S.BuildChanges(job)
	if job.requiredPreset and not UnBotStrategySurvey.VerifyIdentity(job.identity,job.replies.co,job.requiredPreset) then
		S.Finish("класс или специализация альта не соответствуют выбранному снимку; изменения не отправлялись.",false); return;
	end
	if job.automatic and not UnBotStrategySurvey.PrepareAutomatic(job) then return; end
	job.steps={};
	for _,channel in ipairs(job.sections) do
		local chunks,differences=S.Diff(job[channel],job.replies[channel],channel);
		if #differences>0 then
			job.changed[channel]=true;
			for _,command in ipairs(chunks) do table.insert(job.steps,{command=command,channel=channel}); end
			-- Exactly one verification query for this section. Never repeat a
			-- rejected or unconfirmed mutation.
			table.insert(job.steps,{command=channel.." ?",wait=channel});
		end
	end
	job.phase="changes"; job.index=1;
	if #job.steps==0 then S.Finish(job.autoSelection and "серверная основа и личные настройки уже совпадают; изменений нет." or "стратегии уже соответствуют личным настройкам; изменений нет.",true); end
end

function S.Tick()
    if not S.active and UnBotAltSetups and UnBotAltSetups.job then return;end
	local now=GetTime();
	if not S.active then
		local job=S.queue[1]; if not job or now<job.notBefore or now<S.nextSend then return; end
		if now-job.queuedAt>180 or not S.Ready(job) then table.remove(S.queue,1); return; end
		if (InCombatLockdown and InCombatLockdown()) or UnitAffectingCombat("player") then
			if now-job.queuedAt>60 then table.remove(S.queue,1); UnBotAccountAlts.Message("Стратегии "..job.name..": ожидание выхода из боя закончено; команды не отправлялись."); end
			return;
		end
		S.active=table.remove(S.queue,1); job.startedAt=now; job.phase="transport";
	end
	local job=S.active;
	if not S.Ready(job) then S.Finish("персонаж отключился или аккаунт сменился; сверка остановлена.",false); return; end
	if now-job.startedAt>60 then S.Finish("таймаут сверки; повторных команд нет.",false); return; end
	if (InCombatLockdown and InCombatLockdown()) or UnitAffectingCombat("player") then S.Finish("начался бой; сверка остановлена.",false); return; end
	if job.revision then
		local entry=S.Entry(job.name);
		if not entry or not entry.strategyProfile or entry.strategyProfile.revision~=job.revision or entry.strategyProfile.enabled~=true then
			S.Finish("личные настройки изменились; прежняя сверка остановлена.",false); return;
		end
	end
	if job.automatic then
		local profile=S.Entry(job.name).strategyProfile;
		local revision=type(profile)=="table" and (tonumber(profile.revision) or 0) or 0;
		local enabled=type(profile)=="table" and profile.enabled==true or false;
		if revision~=job.personalRevision or enabled~=job.personalEnabled then
			S.Finish("личные настройки изменились; прежняя сверка остановлена.",false); return;
		end
	end
	if job.waitChannel then
		if now>=job.deadline then S.Finish("нет ответа на "..(job.waitChannel=="who" and "who" or job.waitChannel.." ?").."; сверка остановлена без повторов.",false); end
		return;
	end
	if now<S.nextSend then return; end
	if job.phase=="transport" then
		local command=job.transport[job.index];
		if command then job.index=job.index+1; S.Send(job,command); return; end
		job.phase="initial"; job.index=1;
	end
	if job.phase=="initial" then
		if (job.requiredPreset or job.automatic or job.detectAutomatic) and not job.identity then S.Send(job,"who","who"); return; end
		local channel=job.sections[job.index];
		if channel then S.Send(job,channel.." ?",channel); return; end
		if job.mode=="apply" then
			if #job.sections==0 then S.Finish("призван; стандартные стратегии сервера сохранены.",true); else S.BuildChanges(job); end
		elseif job.mode=="copy" then
			if S.ui and S.ui.name==job.target and S.ui.context==job.context then
				S.CopyToDraft(job.section,job.replies[job.section],job.name);
				S.Finish("стратегии скопированы из "..job.name.."; сохраните личный профиль.",true);
			else S.Finish("копирование отменено: выбран другой альт.",false); end
		elseif job.mode=="edit" then
			if S.LoadCurrent(job) then
				S.Finish(S.ui.serverBase and "who, co и nc прочитаны. Серверная основа подобрана; личные изменения применяются поверх неё. Сохраните или примените." or "Текущие co и nc прочитаны: выбор соответствует альту. Измените нужные строки, затем сохраните или примените.",true);
			else S.Finish("чтение отменено: выбран другой альт или окно закрыто.",false); end
		else S.Finish("Текущие стратегии прочитаны.",true); end
		return;
	end
	if job.phase=="changes" then
		local step=job.steps[job.index];
		if not step then S.Finish(job.autoSelection and "серверная основа и личные стратегии подтверждены; сверка завершена." or "личные стратегии подтверждены; сверка завершена.",true); return; end
		if not step.wait then
			job.index=job.index+1;
			local seen=S.observed[job.context.."|"..job.name];
			if seen then seen.pending=seen.pending or {}; seen.pending[step.channel]=true; end
			if UnBotLootControl then UnBotLootControl.observed[job.name]=nil; end
		end
		S.Send(job,step.command,step.wait);
	end
end

function S.Reply(message, sender)
	local job=S.active;
	if not job or UnBotAccountAlts.SenderKey(sender)~=UnBotAccountAlts.SenderKey(job.name) or not S.Ready(job) then return; end
	local text=tostring(message or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","");
	local lower=string.lower(text);
	if lower:find("unknown strategy",1,true) or lower:find("unknown spell",1,true) or lower:find("invalid strategy",1,true)
		or lower:find("cannot",1,true) or lower:find("not allowed",1,true) or lower:find("неизвестн",1,true) then
		S.Finish("сервер отказал: "..text..". Повторов нет.",false); return;
	end
	if not job.waitChannel then return; end
	if GetTime()>=job.deadline then S.Finish("ответ пришёл после таймаута; повторов нет.",false); return; end
	if job.waitChannel=="who" then
		local identity=UnBotParseBotWho and UnBotParseBotWho(text);
		if identity and identity.className then job.identity=identity; job.identity.rawWho=text; job.waitChannel=nil; end
		return;
	end
	local list=lower:match("^%s*strategies:%s*(.*)$");
	if list==nil then
		local prefix;
		prefix,list=lower:match("^%s*(combat) strategies:%s*(.*)$");
		if prefix and job.waitChannel~="co" then return; end
		if list==nil then prefix,list=lower:match("^%s*(non%-combat) strategies:%s*(.*)$"); if prefix and job.waitChannel~="nc" then return; end end
	end
	if list==nil then return; end
	local actual={};
	for token in list:gmatch("[^,]+") do local key=token:match("^%s*(.-)%s*$"); if S.Key(key) then actual[key]=true; end end
	local channel=job.waitChannel; job.waitChannel=nil;
	local cacheKey=job.context.."|"..job.name;
	local seen=S.observed[cacheKey] or {pending={},at={}};
	seen[channel]=actual; seen.at[channel]=time(); seen.pending[channel]=nil; S.observed[cacheKey]=seen;
	if job.phase=="initial" then job.replies[channel]=actual; job.index=job.index+1;
	else
		local _,differences=S.Diff(job[channel],actual,channel);
		if #differences>0 then S.Finish("не подтверждены "..channel..": "..table.concat(differences,", ").."; повторов нет.",false); return; end
		job.index=job.index+1;
	end
	if UnBotLootControl and seen.co and seen.nc and not seen.pending.co and not seen.pending.nc then
		UnBotLootControl.observed[job.name]={co=seen.co.loot==true,nc=seen.nc.loot==true,at=GetTime()};
	end
	if S.RefreshPanel then S.RefreshPanel(); end
end

S.frame=CreateFrame("Frame");
S.frame:RegisterEvent("CHAT_MSG_WHISPER");
S.frame:RegisterEvent("PLAYER_LEAVING_WORLD");
S.frame:SetScript("OnEvent",function(self,event,message,sender)
	if event=="CHAT_MSG_WHISPER" then S.Reply(message,sender); else S.Stop(); S.observed={}; end
end);
S.frame:SetScript("OnUpdate",function() S.Tick(); end);
end

do
local S=UnBotAltStrategies;
S.labels={
	grind="Сам ищет мобов", ["attack weak"]="Сам выбирает цель", ["attack force"]="Ручное указание цели",
	tank="Танк одной цели", ["tank aoe"]="Танк нескольких целей", ["tank assist"]="Помогать танку",
	dps="Стратегия dps", ["dps aoe"]="Урон по площади", ["dps assist"]="Помогать ДД", ["dps debuff"]="Ослаблять цель",
	heal="Лечить группу", aoe="Использовать АоЕ", flee="Отходить от противника", threat="Контролировать угрозу", ["conserve mana"]="Экономить ману",
	fire="Магия огня", ["fire aoe"]="Огонь по нескольким целям", frost="Магия льда", ["frost aoe"]="Лёд по нескольким целям", arcane="Тайная магия",
	shadow="Магия тьмы", ["shadow aoe"]="Тьма по нескольким целям", ["shadow debuff"]="Ослаблять магией тьмы",
	melee="Ближний бой", ["melee aoe"]="Ближний бой по нескольким целям", rshadow="Сопротивление тьме", rfrost="Сопротивление льду", rfire="Сопротивление огню",
	barmor="Аура благочестия", bspeed="Аура скорости", rnature="Сопротивление природе", bhealth="Усиления здоровья", bmana="Усиления маны", bdps="Усиления урона",
	bear="Форма медведя", cat="Форма кошки", ["cat aoe"]="Кошка: несколько целей", caster="Дальний бой", ["caster aoe"]="Дальний бой: несколько целей", ["caster debuff"]="Ослаблять в дальнем бою", totems="Ставить тотемы",
	loot="Поднимать добычу", naxx="Поведение в Наксрамасе", icc="Поведение в ЦЛК", ["avoid aoe"]="Избегать АоЕ", formation="Держать построение",
	["move random"]="Перемещаться случайным образом", emote="Использовать эмоции", food="Есть и пить после боя", stay="Стоять на месте", follow="Следовать за игроком", quest="Брать и сдавать задания с игроком",
	arms="Воин: оружие", behind="Заходить за спину цели", ["cast time"]="Учитывать время произнесения",
	chat="Обрабатывать команды чата", default="Базовое поведение", duel="Поведение в дуэли", potions="Использовать зелья", racials="Использовать расовые способности",
	gather="Собирать ресурсы", mount="Ездить верхом", nc="Базовое поведение вне боя", pvp="Бой с игроками",
};
S.roles={
	{key="server",label="Авто",map={}},
	{key="tank",label="Танк",map={tank=true,["tank assist"]=false,dps=false,heal=false,["attack force"]=false,threat=false}},
	{key="heal",label="Хил",map={heal=true,tank=false,["tank aoe"]=false,dps=false,["conserve mana"]=true,threat=true}},
	{key="dps",label="ДД",map={dps=true,tank=false,["tank aoe"]=false,heal=false,threat=true}},
	{key="assist",label="Помощник игрока",map={dps=true,["dps assist"]=true,tank=false,heal=false,["attack force"]=false}},
};
S.behaviors={
	{key="server",label="Стандарт сервера",map={}},
	{key="leveling",label="Прокачка и квесты",map={follow=true,stay=false,quest=true,loot=true,food=true,["attack force"]=false}},
	{key="follow",label="Следовать без лута",map={follow=true,stay=false,loot=false}},
	{key="stay",label="Стоять на месте",map={stay=true,follow=false,["move random"]=false}},
};

-- Display hints only. Actual active strategies remain visible even when the
-- private server supports a key outside the original catalog's class hints.
S.classStrategies={
	fire="mage", ["fire aoe"]="mage", frost="mage", ["frost aoe"]="mage", arcane="mage",
	shadow="priest warlock", ["shadow aoe"]="priest warlock", ["shadow debuff"]="priest warlock",
	melee="shaman", ["melee aoe"]="shaman", caster="druid shaman", ["caster aoe"]="druid shaman", ["caster debuff"]="druid shaman",
	rshadow="paladin", rfrost="paladin", rfire="paladin", barmor="paladin", bspeed="paladin", rnature="hunter",
	bear="druid", cat="druid", ["cat aoe"]="druid", totems="shaman", arms="warrior",
	heal="priest paladin druid shaman", tank="warrior paladin deathknight druid", ["tank aoe"]="warrior paladin deathknight druid",
	bmana="mage priest warlock paladin hunter druid shaman", ["conserve mana"]="mage priest warlock paladin hunter druid shaman",
};

function S.Catalog(channel)
	local rows,known={},{};
	for _,item in ipairs(channel=="co" and ClassStrategyCO or ClassStrategyNC or {}) do
		if S.Key(item[1]) then table.insert(rows,{key=item[1],label=S.labels[item[1]] or item[2] or item[1],tip=item[3]}); known[item[1]]=true; end
	end
	local ui=S.ui; local seen=ui and ui.name and S.observed[ui.context.."|"..ui.name];
	local extras={};
	for _,map in ipairs({(ui and ui.draft[channel]) or {},(seen and seen[channel]) or {}}) do
		for key in pairs(map) do if S.Key(key) and not known[key] then known[key]=true; table.insert(extras,key); end end
	end
	table.sort(extras);
	for _,key in ipairs(extras) do table.insert(rows,{key=key,label=S.labels[key] or key}); end
	return rows;
end

function S.VisibleCatalog(channel)
	local rows=S.Catalog(channel); local ui=S.ui;
	if not ui or ui.showAdvanced then return rows; end
	local profile=ui.name and UnBotAccountAlts.GetProfile(ui.name);
	local class=profile and string.lower(tostring(profile.className or "")) or "";
	local seen=ui.name and S.observed[ui.context.."|"..ui.name];
	local visible={};
	for _,item in ipairs(rows) do
		local classes=S.classStrategies[item.key];
		local relevant=not classes or class=="" or class=="unknown" or (" "..classes.." "):find(" "..class.." ",1,true);
		local active=(seen and seen[channel] and seen[channel][item.key]==true) or ui.draft[channel][item.key]==true;
		if active or (relevant and S.labels[item.key]) then table.insert(visible,item); end
	end
	return visible;
end

function S.ChoiceValue(channel,key)
	local ui=S.ui; local value=ui.draft[channel][key];
	local base=ui.serverBase and ui.serverBase[channel];
	local copied=ui.draft.samplePreset and ui.draft.samplePreset.sources and ui.draft.samplePreset.sources[channel];
	if base and base[key]~=nil and value==base[key] and not copied then return nil; end
	return value;
end

function S.SetChoice(channel,key,value)
	local ui=S.ui;
	if not ui or not ui.loaded or ui.context~=S.Context() or not S.Entry(ui.name) or S.active or #S.queue>0
		or UnBotAccountAlts.active or (UnBotStrategySurvey and UnBotStrategySurvey.active) then return; end
	ui.explainChannel=channel; ui.explainKey=key; ui.draft[channel][key]=value;
	if value~=nil then ui.draft.enabled=true; end
	ui.draft[channel=="co" and "role" or "behavior"]="custom"; ui.dirty=true; S.RefreshPanel();
end

function S.ChoiceMenu(channel,key,anchor)
	local ui=S.ui;
	if not ui.choiceMenu then ui.choiceMenu=CreateFrame("Frame","UnBotAltChoiceMenu",ui.parent,"UIDropDownMenuTemplate"); end
	local selected=S.ChoiceValue(channel,key); local name,context,session=ui.name,ui.context,ui.session;
	local function select(value)
		if ui.name==name and ui.context==context and ui.session==session then S.SetChoice(channel,key,value); end
		CloseDropDownMenus();
	end
	EasyMenu(UnBotLocale.Menu({
		{text=S.labels[key] or key,isTitle=true,notCheckable=true},
		{text="По умолчанию",checked=selected==nil,func=function() select(nil); end},
		{text="Включить",checked=selected==true,func=function() select(true); end},
		{text="Выключить",checked=selected==false,func=function() select(false); end},
	}),ui.choiceMenu,anchor,0,0,"MENU");
end

function S.Preset(channel,preset)
	local ui=S.ui; if not ui or not ui.loaded or not S.Entry(ui.name) then return; end
	local changes=S.CopyMap(preset.map);
	-- Presets change only their own keys, preserving the complete read snapshot.
	if preset.key=="server" then
		ui.draft[channel]={};
		if ui.draft.samplePreset and ui.draft.samplePreset.sources then
			ui.draft.samplePreset.sources[channel]=nil;
			if not next(ui.draft.samplePreset.sources) then ui.draft.samplePreset=nil; end
		end
	else for key,value in pairs(preset.map) do ui.draft[channel][key]=value; end end
	ui.draft[channel=="co" and "role" or "behavior"]=preset.key;
	if channel=="co" and preset.key~="server" then
		local profile=UnBotAccountAlts.GetProfile(ui.name);
		if profile and profile.className=="druid" then
			if preset.key=="tank" then ui.draft.co.bear=true; ui.draft.co.cat=false; changes.bear=true; changes.cat=false;
			elseif preset.key=="dps" or preset.key=="assist" then
				local spec=string.lower(tostring(profile.specName or ""));
				if spec:find("feral",1,true) or profile.feralRole then ui.draft.co.cat=true; ui.draft.co.bear=false; changes.cat=true; changes.bear=false; end
			end
		end
	end
	if preset.key~="server" then ui.draft.enabled=true; end
	local commands={};
	for key,value in pairs(changes) do table.insert(commands,channel.." "..(value and "+" or "-")..key); end
	table.sort(commands);
	ui.explainKey=nil;
	ui.presetExplanation=preset.key=="server" and "Личные изменения этого раздела сняты. При применении основа выбирается по свежим талантам из /ubstrategies; без снимка сохраняется текущее поведение сервера."
		or ("Пресет «"..preset.label.."»: "..table.concat(commands,", ")..". Остальные прочитанные стратегии сохраняются; поддержка этих команд зависит от класса и сервера.");
	ui.dirty=true; ui.offset=0; if ui.sections then ui.sections[channel].offset=0; end S.RefreshPanel();
end

function S.CopyToDraft(channel,actual,source)
	local ui=S.ui; if not ui or not ui.loaded then return; end
	local map={};
	for _,item in ipairs(S.Catalog(channel)) do map[item.key]=actual[item.key]==true; end
	for key in pairs(actual) do map[key]=true; end
	ui.draft[channel]=map; ui.draft[channel=="co" and "role" or "behavior"]="Как "..source;
	ui.draft.enabled=true; ui.dirty=true; ui.presetExplanation=nil; ui.explainKey=nil;
end

-- Reading for the editor is distinct from read-only inspection (summon/loot).
-- Import both complete replies together; a timeout never creates a partial draft.
function S.LoadCurrent(job)
	local ui=S.ui;
	if not ui or not ui.parent:IsShown() or ui.name~=job.name or ui.context~=job.context or ui.session~=job.session then return false; end
	if not job.replies.co or not job.replies.nc then return false; end
	local maps={};
	for _,channel in ipairs({"co","nc"}) do
		local map={};
		for _,item in ipairs(S.Catalog(channel)) do map[item.key]=job.replies[channel][item.key]==true; end
		for key in pairs(job.replies[channel]) do map[key]=true; end
		maps[channel]=S.CopyMap(map); if not maps[channel] then return false; end
	end
	ui.draft.co=maps.co; ui.draft.nc=maps.nc;
	ui.draft.role="current"; ui.draft.behavior="current";
	ui.loaded=true; ui.dirty=false; ui.presetExplanation=nil; ui.explainKey=nil; ui.draft.samplePreset=nil;
	ui.serverBase=nil; ui.autoPreview=nil;
	if job.detectAutomatic and job.identity then
		local entry=S.Entry(job.name); local profile=type(entry.strategyProfile)=="table" and entry.strategyProfile or nil;
		local definition,record,reason,build=UnBotStrategySurvey.SelectAutomatic(job.identity,job.replies.co,entry.autoStrategy);
		if record then
			local bases={co=UnBotStrategySurvey.ServerMap("co",record),nc=UnBotStrategySurvey.ServerMap("nc",record)};
			if bases.co and bases.nc then
				for _,channel in ipairs({"co","nc"}) do
					local wanted=S.CopyMap(bases[channel]);
					for key,value in pairs(maps[channel]) do if wanted[key]==nil then wanted[key]=value; end end
					if type(profile)=="table" and profile.enabled then for key,value in pairs(S.CopyMap(profile[channel]) or {}) do wanted[key]=value; end end
					ui.draft[channel]=wanted;
				end
				ui.serverBase=bases; ui.draft.role=profile and profile.enabled and profile.role or "server";
				ui.draft.behavior=profile and profile.enabled and profile.behavior or "server";
				ui.autoPreview={className=definition.className,specName=definition.specName,context=UnBotStrategySurvey.Context(),reason=reason,talentBuild=build};
				ui.presetExplanation="Серверная основа: "..definition.classLabel.." / "..definition.specLabel..". Личные настройки — поверх неё; отличия от альта выделены."
					..(reason and " Не определить по талантам; выберите руками желаемую роль." or "");
			end
		end
	end
	return true;
end

function S.ReadCurrent()
	local ui=S.ui; if not ui or not S.Entry(ui.name) then return false; end
	if not S.Enqueue(ui.name,"edit") then
		S.results[ui.context.."|"..ui.name]="Для чтения нужен живой онлайн-альт в вашей группе, вне боя. Дождитесь завершения других операций.";
		S.RefreshPanel(); return false;
	end
	local job=S.queue[#S.queue]; job.session=ui.session;
	ui.loaded=false;
	S.RefreshPanel(); return true;
end

function S.Save()
	local ui=S.ui; local entry=ui and ui.context==S.Context() and S.Entry(ui.name); if not entry then return false; end
	if not ui.loaded then return false; end
	local profile=type(entry.strategyProfile)=="table" and entry.strategyProfile or {};
	profile.schemaVersion=1; profile.enabled=ui.draft.enabled==true;
	for _,channel in ipairs({"co","nc"}) do
		local choices=S.CopyMap(ui.draft[channel]); if not choices then return false; end
		-- Save personal differences, not a frozen copy of the current spec.
		-- A later talent change must be able to select a new server base.
		if ui.serverBase and not (ui.draft.samplePreset and ui.draft.samplePreset.sources and ui.draft.samplePreset.sources[channel]) then
			for key,value in pairs(choices) do if ui.serverBase[channel][key]~=nil and value==(ui.serverBase[channel][key]==true) then choices[key]=nil; end end
		end
		-- Preserve unrecognised schema metadata; boolean strategy keys belong to
		-- this editor and can deliberately be removed with the server-default button.
		for key,value in pairs(type(profile[channel])=="table" and profile[channel] or {}) do
			if not S.Key(key) or type(value)~="boolean" then choices[key]=value; end
		end
		profile[channel]=choices;
	end
	profile.role=ui.draft.role; profile.behavior=ui.draft.behavior;
	if ui.serverBase then profile.baseMode="talents"; end
	profile.samplePreset=ui.draft.samplePreset;
	profile.revision=(tonumber(profile.revision) or 0)+1; profile.updatedAt=time();
	profile.lastVerifiedAt=nil;
	entry.strategyProfile=profile;
	if type(profile.co.loot)=="boolean" and profile.co.loot==profile.nc.loot then entry.allowLoot=profile.co.loot; end
	ui.dirty=false;
	S.results[ui.context.."|"..ui.name]="Личный профиль сохранён. Команды ещё не отправлялись.";
	S.RefreshPanel(); return true;
end

function S.SetLootChoice(name,allowed)
	local entry=S.Entry(name); if not entry then return; end
	local profile=type(entry.strategyProfile)=="table" and entry.strategyProfile or {schemaVersion=1,role="server",behavior="custom"};
	profile.co=type(profile.co)=="table" and profile.co or {}; profile.nc=type(profile.nc)=="table" and profile.nc or {};
	profile.co.loot=allowed==true; profile.nc.loot=allowed==true; profile.enabled=true;
	profile.revision=(tonumber(profile.revision) or 0)+1; profile.updatedAt=time();
	entry.strategyProfile=profile; entry.allowLoot=allowed==true;
	if S.ui and S.ui.name==name and S.ui.context==S.Context() then
		S.ui.draft.co.loot=allowed==true; S.ui.draft.nc.loot=allowed==true; S.ui.draft.enabled=true; S.RefreshPanel();
	end
end

function S.Select(name)
	local entry,resolved=S.Entry(name); local ui=S.ui; if not ui then return; end
	local context=S.Context();
	if ui.name==resolved and ui.context==context then S.RefreshPanel(); return; end
	if ui.dirty then S.Save(); end
	ui.name=resolved; ui.context=context; ui.offset=0; ui.dirty=false; ui.explainKey=nil; ui.presetExplanation=nil; ui.loaded=false; ui.session=(ui.session or 0)+1; ui.showAdvanced=false;
	ui.serverBase=nil; ui.autoPreview=nil;
	local profile=entry and type(entry.strategyProfile)=="table" and entry.strategyProfile or {};
	ui.draft={co=S.CopyMap(profile.co) or {},nc=S.CopyMap(profile.nc) or {},role=profile.role or "server",behavior=profile.behavior or "server",enabled=profile.enabled==true,samplePreset=profile.samplePreset};
	S.RefreshPanel();
end

function S.Menu(channel,anchor,level)
	local ui=S.ui; if not ui or not ui.loaded or not S.Entry(ui.name) then return; end
	local menu={};
	for _,preset in ipairs(channel=="co" and S.roles or S.behaviors) do
		local choice=preset;
		table.insert(menu,{text=choice.label,value=choice.key,checked=ui.draft[channel=="co" and "role" or "behavior"]==choice.key,
			func=function() S.Preset(channel,choice); CloseDropDownMenus(); end});
	end
	for _,info in ipairs(menu) do UIDropDownMenu_AddButton(info,level or 1); end
end

function S.Summary(name)
	local entry=S.Entry(name); if not entry then return "Выберите подтверждённого альта."; end
	local profile=type(entry.strategyProfile)=="table" and entry.strategyProfile or {};
	local seen=S.observed[S.Context().."|"..name];
	local lines={"Личный профиль: "..(profile.enabled and "включён" or "стандарт сервера"),
		"Роль: "..S.PresetLabel(S.roles,profile.role or "server"),
		"Поведение: "..S.PresetLabel(S.behaviors,profile.behavior or "server")};
	if entry.autoStrategy then table.insert(lines,"Серверная основа: "..tostring(entry.autoStrategy.specName or "?")..(entry.autoStrategy.fallback and " (временная; выберите роль руками)" or " (по талантам)")); end
	for _,channel in ipairs({"co","nc"}) do
		local label=channel=="co" and "В бою" or "Вне боя";
		local keys={}; for key in pairs(seen and seen[channel] or {}) do table.insert(keys,key); end; table.sort(keys);
		local text=seen and seen[channel] and (#keys>0 and table.concat(keys,", ") or "нет активных стратегий") or "ещё не прочитаны";
		if #text>160 then text=text:sub(1,160).."..."; end
		table.insert(lines,label..": "..text);
	end
	return table.concat(lines,"\n");
end

function S.PresetLabel(choices,key)
	for _,choice in ipairs(choices) do if choice.key==key then return choice.label; end end
	if type(key)=="string" and key:find("Снимок:",1,true)==1 then return "Свои настройки"; end
	return key=="current" and "Текущие альта" or (key=="custom" and "Свои настройки" or tostring(key));
end

function S.RefreshPanel()
	local ui=S.ui; if not ui then return; end
	local entry=ui.name and ui.context==S.Context() and S.Entry(ui.name);
	local profile=entry and UnBotAccountAlts.GetProfile(ui.name) or {};
	ui.title:SetText(entry and ("Стратегии альта: "..ui.name.." — "..tostring(profile.className or "?").." / "..tostring(profile.specName or "?")) or "Стратегии альта");
	ui.enabled:SetChecked(entry and ui.draft.enabled);
	ui.advanced:SetText(ui.showAdvanced and "Скрыть дополнительные" or "Дополнительно");
	UIDropDownMenu_SetText(ui.role,S.PresetLabel(S.roles,ui.draft.role)); UIDropDownMenu_SetText(ui.behavior,S.PresetLabel(S.behaviors,ui.draft.behavior));
	local seen=entry and S.observed[ui.context.."|"..ui.name];
	local online=entry and UnBotAccountAlts.IsOnline(ui.name);
	for channel,section in pairs(ui.sections) do
		local rows=S.VisibleCatalog(channel); section.offset=math.max(0,math.min(section.offset or 0,math.max(0,#rows-#section.rows)));
		local actual=seen and seen[channel];
		for index,row in ipairs(section.rows) do
			local item=entry and rows[section.offset+index]; row.item=item;
			if item then
				row:Show(); local wanted=ui.draft[channel][item.key];
				local choice=S.ChoiceValue(channel,item.key);
				row.choice:SetText(not ui.loaded and "Ждём чтения" or (choice==nil and "По умолчанию" or (choice and "Включить" or "Выключить"))); row.label:SetText(item.label);
				local changed=ui.loaded and wanted~=nil and actual and wanted~=(actual[item.key]==true);
				row.label:SetTextColor(changed and 1 or .65,changed and .82 or .65,changed and .3 or .65);
				row.current:SetText(seen and seen.pending[channel] and "ждём" or (actual and (actual[item.key] and "вкл" or "выкл") or "?"));
			else row:Hide(); end
		end
		section.range:SetText(entry and (tostring(#rows==0 and 0 or section.offset+1).."–"..tostring(math.min(#rows,section.offset+#section.rows)).." / "..#rows) or "");
		local stamp=seen and seen.at[channel];
		section.snapshot:SetText(stamp and ("Снимок: "..date("%H:%M:%S",stamp)..(online and "" or " — офлайн")) or "Сейчас: неизвестно");
	end
	local result=entry and S.results[ui.context.."|"..ui.name] or "";
	local progress=S.active and S.active.context==ui.context and (S.active.name==ui.name or S.active.target==ui.name);
	ui.status:SetText(progress and ("Сверка: "..tostring(S.active.waitChannel and (S.active.waitChannel.." ? — ждём ответ") or "выполнение очереди с паузами")..". Повторы изменений отключены.") or (ui.dirty and "Есть несохранённые изменения. Нажмите «Сохранить» или «Применить»." or (not ui.loaded and ((result and result~="") and result or "Сначала прочитайте co и nc: нужен онлайн-альт в вашей группе, вне боя.") or (result or ""))));
	ui.explanation:SetText(ui.explainKey and S.Explain(ui.explainChannel,ui.explainKey,S.ChoiceValue(ui.explainChannel,ui.explainKey)) or ui.presetExplanation or "Выберите действие в строке. «Сейчас» — последний ответ альта. Английские команды — в подсказке; полный список — в «Дополнительно».");
	local fighting=(InCombatLockdown and InCombatLockdown()) or UnitAffectingCombat("player");
	local busy=S.active~=nil or #S.queue>0 or (UnBotAccountAlts and UnBotAccountAlts.active) or (UnBotStrategySurvey and UnBotStrategySurvey.active);
	ui.stop:SetText(busy and "Остановить сверку" or "Сверка не запущена"); if busy then ui.stop:Enable(); else ui.stop:Disable(); end
	if not entry or not online or fighting or busy then ui.read:Disable(); else ui.read:Enable(); end
	if not entry or not ui.loaded or not online or fighting or busy then ui.apply:Disable(); else ui.apply:Enable(); end
	for _,dropdown in ipairs({ui.role,ui.behavior}) do if not entry or not ui.loaded or busy then UIDropDownMenu_DisableDropDown(dropdown); else UIDropDownMenu_EnableDropDown(dropdown); end end
	for _,button in ipairs({ui.save,ui.enabled}) do if not entry or not ui.loaded or busy then button:Disable(); else button:Enable(); end end
	for _,row in ipairs(ui.rows) do if not entry or not ui.loaded or busy then row.choice:Disable(); else row.choice:Enable(); end end
end

function S.Open(name)
	if not S.Entry(name) then return; end
	if not S.ui then S.CreatePanel(); end
	local reopening=not S.ui.parent:IsShown();
	S.Select(name); S.ui.parent:Show();
	if reopening then S.ui.loaded=false; end
	if not S.ui.loaded and UnBotAccountAlts.IsOnline(name) then S.ReadCurrent(); end
	S.RefreshPanel();
	S.ui.parent:SetScale(math.min(1,(UIParent:GetWidth()-32)/1010,(UIParent:GetHeight()-32)/700));
end

function S.CreatePanel()
	local parent=CreateFrame("Frame","UnBotAltStrategyEditor",UIParent);
	parent:SetWidth(1010); parent:SetHeight(700); parent:SetPoint("CENTER"); parent:SetFrameStrata("FULLSCREEN_DIALOG"); parent:SetClampedToScreen(true);
	parent:SetMovable(true); parent:EnableMouse(true); parent:RegisterForDrag("LeftButton");
	parent:SetScript("OnDragStart",function(self) self:StartMoving(); end); parent:SetScript("OnDragStop",function(self) self:StopMovingOrSizing(); end);
	parent:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=false,edgeSize=32,insets={left=11,right=12,top=12,bottom=11}});
	parent:SetBackdropColor(.025,.025,.025,1);
	local ui={parent=parent,rows={},sections={},offset=0,draft={co={},nc={},role="server",behavior="server",enabled=false}}; S.ui=ui;
	parent:SetScript("OnUpdate",function(self,elapsed) ui.elapsed=(ui.elapsed or 0)+elapsed; if ui.elapsed>=.5 then ui.elapsed=0; S.RefreshPanel(); end end);
	parent:SetScript("OnHide",function(self) self:StopMovingOrSizing(); if ui.dirty then S.Save(); end end);
	local function text(owner,x,y,width,value,font)
		local label=owner:CreateFontString(nil,"OVERLAY",font or "GameFontHighlightSmall"); label:SetPoint("TOPLEFT",owner,"TOPLEFT",x,y); label:SetWidth(width); label:SetJustifyH("LEFT"); label:SetText(value or ""); return label;
	end
	local function button(owner,x,y,width,label,action)
		local b=CreateFrame("Button",nil,owner,"UIPanelButtonTemplate"); b:SetPoint("TOPLEFT",owner,"TOPLEFT",x,y); b:SetWidth(width); b:SetHeight(24); b:SetText(label); b:SetScript("OnClick",action); return b;
	end
	local close=CreateFrame("Button",nil,parent,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",parent,"TOPRIGHT",-6,-6); close:SetScript("OnClick",function() parent:Hide(); end);
	if UISpecialFrames then table.insert(UISpecialFrames,"UnBotAltStrategyEditor"); end
	ui.title=text(parent,24,-24,558,"Стратегии альта","GameFontNormalLarge");
	ui.lootHelp=button(parent,594,-20,166,"Справка по луту",function() UnBotLootControl.Open(); end);
	ui.survey=button(parent,772,-20,212,"Сбор пресетов классов",function() if UnBotStrategySurvey then UnBotStrategySurvey.Open(); end end);
	ui.survey:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_TOP"); GameTooltip:AddLine("Снимки классов и специализаций",1,.82,.2); GameTooltip:AddLine("Открывает сохранённые co/nc и состояние сбора (/ubstrategies). Сбор запускается отдельной кнопкой в том окне.",1,1,1,true); GameTooltip:Show(); end);
	ui.survey:SetScript("OnLeave",function() GameTooltip:Hide(); end);
	ui.enabled=CreateFrame("CheckButton",nil,parent,"UICheckButtonTemplate"); ui.enabled:SetPoint("TOPLEFT",parent,"TOPLEFT",24,-50); ui.enabled:SetWidth(24); ui.enabled:SetHeight(24);
	text(parent,52,-55,742,"При призыве применять мои настройки поверх основы по талантам.");
	ui.advanced=button(parent,812,-52,172,"Дополнительно",function()
		ui.showAdvanced=not ui.showAdvanced; ui.explainKey=nil;
		for _,section in pairs(ui.sections) do section.offset=0; end S.RefreshPanel();
	end);
	ui.enabled:SetScript("OnClick",function(self) ui.draft.enabled=self:GetChecked() and true or false; ui.dirty=true; S.RefreshPanel(); end);
	local function dropdown(name,x,channel,title,explanation)
		local control=CreateFrame("Frame",name,parent,"UIDropDownMenuTemplate");
		control:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-77); UIDropDownMenu_SetWidth(control,316);
		UIDropDownMenu_Initialize(control,function(self,level) S.Menu(channel,self,level); end);
		local arrow=_G[name.."Button"];
		arrow:HookScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_TOP"); GameTooltip:AddLine(title,1,.82,.2); GameTooltip:AddLine(explanation,1,1,1,true); GameTooltip:Show(); end);
		arrow:HookScript("OnLeave",function() GameTooltip:Hide(); end);
		return control;
	end
	text(parent,24,-87,114,"Выбор роли:","GameFontNormalSmall");
	text(parent,518,-87,114,"Небоевой пресет:","GameFontNormalSmall");
	ui.role=dropdown("UnBotAltRoleDropdown",124,"co","Выбор пресета роли",
		"Авто — роль по талантам. Или выберите роль вручную.");
	ui.behavior=dropdown("UnBotAltBehaviorDropdown",618,"nc","Выбор небоевого пресета",
		"Выберите поведение вне боя.");
	for _,channel in ipairs({"co","nc"}) do
		local mode=channel;
		local section={rows={},offset=0}; ui.sections[mode]=section;
		local column=CreateFrame("Frame",nil,parent); column:SetPoint("TOPLEFT",parent,"TOPLEFT",mode=="co" and 24 or 518,-114); column:SetWidth(466); column:SetHeight(440);
		column:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=8,insets={left=3,right=3,top=3,bottom=3}}); column:SetBackdropColor(.02,.04,.04,.95);
		text(column,8,-8,200,mode=="co" and "БОЕВЫЕ СТРАТЕГИИ (co)" or "НЕБОЕВЫЕ СТРАТЕГИИ (nc)","GameFontNormalSmall");
		section.snapshot=text(column,231,-8,225,"");
		text(column,8,-30,224,"ДЕЙСТВИЕ"); text(column,241,-30,136,"МОЙ ВЫБОР"); text(column,387,-30,68,"СЕЙЧАС");
		for index=1,14 do
			local row=CreateFrame("Frame",nil,column); row:SetPoint("TOPLEFT",column,"TOPLEFT",4,-47-(index-1)*25); row:SetWidth(458); row:SetHeight(25); row.channel=mode;
			row.label=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); row.label:SetPoint("LEFT",row,"LEFT",4,0); row.label:SetWidth(224); row.label:SetHeight(25); row.label:SetJustifyH("LEFT");
			row.choice=CreateFrame("Button",nil,row,"UIPanelButtonTemplate"); row.choice:SetPoint("LEFT",row,"LEFT",237,0); row.choice:SetWidth(136); row.choice:SetHeight(22);
			row.current=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); row.current:SetPoint("LEFT",row,"LEFT",383,0); row.current:SetWidth(68); row.current:SetJustifyH("LEFT");
			row.choice:SetScript("OnClick",function(self) if ui.loaded and row.item then S.ChoiceMenu(mode,row.item.key,self); end end);
			local function showTip(self)
				if not row.item then return; end
				ui.explainChannel=mode; ui.explainKey=row.item.key; S.RefreshPanel();
				GameTooltip:SetOwner(self,"ANCHOR_TOP"); GameTooltip:AddLine(row.item.label,1,.82,.2);
				GameTooltip:AddLine("Включить: "..mode.." +"..row.item.key.."; выключить: "..mode.." -"..row.item.key,.6,.8,1,true);
				GameTooltip:AddLine(S.Explain(mode,row.item.key,S.ChoiceValue(mode,row.item.key)),1,1,1,true);
				GameTooltip:AddLine("По умолчанию: убрать личное указание; использовать основу по талантам, а без снимка — текущее поведение. Жёлтый текст — отличие от последнего ответа.",.8,.8,.8,true); GameTooltip:Show();
			end
			row:EnableMouse(true);
			for _,control in ipairs({row,row.choice}) do control:SetScript("OnEnter",showTip); control:SetScript("OnLeave",function() GameTooltip:Hide(); end); end
			table.insert(section.rows,row); table.insert(ui.rows,row);
		end
		column:EnableMouseWheel(true); column:SetScript("OnMouseWheel",function(self,delta) section.offset=section.offset-delta*3; S.RefreshPanel(); end);
		button(column,8,-409,32,"<",function() section.offset=section.offset-#section.rows; S.RefreshPanel(); end);
		button(column,45,-409,32,">",function() section.offset=section.offset+#section.rows; S.RefreshPanel(); end);
		section.range=text(column,87,-415,120,"");
	end
	ui.explanation=text(parent,24,-568,960,""); ui.explanation:SetHeight(30); ui.explanation:SetJustifyV("TOP");
	ui.status=text(parent,24,-604,960,""); ui.status:SetHeight(30); ui.status:SetJustifyV("TOP");
	ui.read=button(parent,24,-645,185,"Прочитать текущие",function() S.ReadCurrent(); end);
	ui.read:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_TOP"); GameTooltip:AddLine("Прочитать co и nc альта в группе",1,.82,.2); GameTooltip:AddLine("Оба ответа обновят выбор в строках, заменив правки в окне. Сохранённый профиль не меняется до сохранения. Нужен онлайн-альт вне боя.",1,1,1,true); GameTooltip:Show(); end);
	ui.read:SetScript("OnLeave",function() GameTooltip:Hide(); end);
	ui.save=button(parent,219,-645,185,"Сохранить",function() S.Save(); end);
	ui.apply=button(parent,414,-645,185,"Применить и проверить",function()
		if not S.Save() then return; end
		if not S.OnSummon(ui.name,"manual") then S.results[ui.context.."|"..ui.name]="Стандарт сервера: личные изменения не заданы. Команды не отправлялись."; end; S.RefreshPanel();
	end);
	ui.stop=button(parent,609,-645,185,"Остановить сверку",function() S.Stop(); end);
	button(parent,804,-645,180,"Закрыть",function() parent:Hide(); end);
	parent:Hide(); S.RefreshPanel();
end
end

-- Class/spec strategy survey: temporary ordinary bots only; shared finite
-- co/nc transport above, no init, summon, follow, or strategy mutations.
UnBotStrategySurvey=UnBotStrategySurvey or {};
do
local V=UnBotStrategySurvey;
local S=UnBotAltStrategies;

function V.Definitions()
	return UnBotStrategySurveyGetDefinitions and UnBotStrategySurveyGetDefinitions() or {};
end

function V.Context()
	return tostring(GetRealmName() or "").."|"..tostring(UnitFactionGroup("player") or "");
end

function V.Storage()
	UnBotSquadConfig=UnBotSquadConfig or {};
	local root=UnBotSquadConfig.strategySurvey or {}; UnBotSquadConfig.strategySurvey=root;
	root.schemaVersion=1; root.contexts=root.contexts or {};
	local db=root.contexts[V.Context()] or {}; root.contexts[V.Context()]=db;
	db.variants=db.variants or {}; return db;
end

function V.Spec(profile)
	if not profile then return ""; end
	if UnBotSpecCountBalanceProfileSpec then return UnBotSpecCountBalanceProfileSpec(profile); end
	return string.lower(tostring(profile.specName or ""));
end

function V.IdentitySpec(identity,co)
	local spec=UnBotSpecCountBalanceNormalizeSpec and UnBotSpecCountBalanceNormalizeSpec(identity and identity.specName) or V.Spec(identity);
	if identity and identity.className=="druid" and spec=="feral combat" then
		if co and co.bear==true and co.cat==true then return ""; end
		local form=co and co.bear~=co.cat and (co.bear and "bear" or (co.cat and "cat"));
		if form and identity.feralRole and form~=identity.feralRole then return ""; end
		local role=form or identity.feralRole;
		return (role=="bear" or role=="cat") and "feral "..role or "";
	end
	return spec;
end

function V.VerifyIdentity(identity,co,expected)
	if not identity or not expected or identity.className~=expected.className then return false; end
	if expected.context and expected.context~=V.Context() then return false; end
	-- An explicit talent role can restore a wrongly selected combat form.
	local spec=V.IdentitySpec(identity,nil); if spec=="" then spec=V.IdentitySpec(identity,co); end
	return spec==expected.specName;
end

function V.Key(className,specName) return tostring(className)..":"..tostring(specName); end

function V.Ordinary(name,profile)
	if not profile or name==UnitName("player") or not UnBotIsAccountAltProfile or UnBotIsAccountAltProfile(name,profile) then return false; end
	if UnBotAccountAlts.IsAlt and UnBotAccountAlts.IsAlt(name,profile) then return false; end
	if not tostring(name):match("^[^%s%d|,;]+$") then return false; end
	if profile.faction and profile.faction~=UnitFactionGroup("player") then return false; end
	if UnBotRegistryGetActiveFlag and UnBotRegistryGetActiveFlag(profile) then return false; end
	return true;
end

function V.GroupEmptyExcept(name)
	-- Count unresolved/offline members as roster occupants too.
	local raid=GetNumRaidMembers()>0; local count=raid and GetNumRaidMembers() or GetNumPartyMembers();
	for i=1,count do
		local member=UnitName((raid and "raid" or "party")..i);
		if not member or (member~=UnitName("player") and member~=name) then return false; end
	end
	return true;
end

function V.OthersBusy()
	return (UnBotMythicPlusBuffOtherAutomationActive and UnBotMythicPlusBuffOtherAutomationActive(true))
		or (UnBotAccountAlts and (UnBotAccountAlts.active or UnBotAccountAlts.discoveryActive))
		or (UnBotBeaconTravel and UnBotBeaconTravel.active)
		or (UnBotSquadRoleAction and UnBotSquadRoleAction.active)
		or (UnBotBotScanner and UnBotBotScanner.pendingSpecBalanceClass)
		or (S.active and S.active.mode~="survey") or (#S.queue>0 and S.queue[1].mode~="survey")
		or (UnBotMarket and UnBotMarket.job);
end

function V.Fighting()
	return (InCombatLockdown and InCombatLockdown()) or UnitAffectingCombat("player");
end

function V.Message(text) UnBotAccountAlts.Message("Сбор стратегий: "..text); end

function V.Candidates(definition,groupOnly)
	local names={}; local variant=V.Storage().variants[definition.key];
	for name,profile in pairs((UnBotBotRegistry and UnBotBotRegistry.bots) or {}) do
		local unit=UnBotAccountAlts.FindUnit(name);
		if V.Ordinary(name,profile) and not V.tried[name] and profile.className==definition.className
			and (V.Spec(profile)==definition.specName or (definition.className=="druid" and V.Spec(profile)=="feral combat"))
			and (not unit or UnitIsConnected(unit)) and (not groupOnly or unit) then table.insert(names,name); end
	end
	table.sort(names,function(a,b)
		local seenA=variant and variant.samples and variant.samples[a]; local seenB=variant and variant.samples and variant.samples[b];
		if (seenA~=nil)~=(seenB~=nil) then return seenA==nil; end
		local pa=UnBotBotRegistry.bots[a]; local pb=UnBotBotRegistry.bots[b];
		if (tonumber(pa.level) or 0)~=(tonumber(pb.level) or 0) then return (tonumber(pa.level) or 0)>(tonumber(pb.level) or 0); end
		return a<b;
	end);
	return names;
end

function V.Reference(variant)
	if not variant or not variant.samples then return; end
	local sample=variant.samples[variant.referenceName];
	if type(sample)=="table" and type(sample.co)=="table" and type(sample.nc)=="table" then return sample; end
	for _,candidate in pairs(variant.samples) do if type(candidate)=="table" and type(candidate.co)=="table" and type(candidate.nc)=="table" then return candidate; end end
end

-- Use the collected class/spec state as a base, then overlay only this alt's
-- saved choices. Selection metadata is separate from the personal profile.
function V.BaseRecord(definition)
	local record=V.Reference(V.Storage().variants[definition.key]);
	if record and record.className==definition.className and record.specName==definition.specName and record.context==V.Context()
		and S.CopyMap(record.co) and S.CopyMap(record.nc) then return record; end
end

function V.HasLibrary()
	for _,definition in ipairs(V.Definitions()) do if V.BaseRecord(definition) then return true; end end
	return false;
end

function V.SelectAutomatic(identity,co,previous)
	local definitions,trees={},{};
	for _,definition in ipairs(V.Definitions()) do
		if definition.className==identity.className then
			table.insert(definitions,definition);
			local tree=definition.specName:match("^feral ") and "feral combat" or definition.specName;
			if trees[#trees]~=tree then table.insert(trees,tree); end
		end
	end
	local a,b,c=tostring(identity.rawWho or identity.text or identity.talentBuild or ""):match("(%d+)%s*/%s*(%d+)%s*/%s*(%d+)");
	local points=a and {tonumber(a),tonumber(b),tonumber(c)};
	local build=points and table.concat(points,"/") or "?";
	local reason,randomChoice,selectedTree;
	local leading={};
	if (tonumber(identity.level) or 80)<10 or (points and points[1]+points[2]+points[3]==0) then
		reason="нет талантов"; randomChoice=true;
	elseif not points then reason="распределение талантов не получено";
	else
		local maximum=math.max(points[1],points[2],points[3]);
		for i=1,3 do if points[i]==maximum then leading[trees[i] or ""]=true; selectedTree=trees[i]; end end
		local count=0; for _ in pairs(leading) do count=count+1; end
		if count>1 then reason="равные ведущие ветки "..build; selectedTree=nil; end
	end
	local feralSpec;
	if selectedTree=="feral combat" then
		local role=identity.feralRole;
		if role~="bear" and role~="cat" then
			role=co and co.bear~=co.cat and (co.bear and "bear" or (co.cat and "cat")) or nil;
			reason="роль feral не определяется по талантам "..build;
		end
		feralSpec=role and "feral "..role or nil;
	end
	local available={};
	for _,definition in ipairs(definitions) do
		local tree=definition.specName:match("^feral ") and "feral combat" or definition.specName;
		local matches=selectedTree and tree==selectedTree and (not feralSpec or definition.specName==feralSpec)
			or (not selectedTree and (not next(leading) or leading[tree]));
		if matches and V.BaseRecord(definition) then table.insert(available,definition); end
	end
	if #available==0 then return nil,nil,reason,build,selectedTree; end
	local chosen=available[1];
	if randomChoice then
		local remembered=false;
		if previous and previous.context==V.Context() and previous.className==identity.className and previous.reason==reason and previous.talentBuild==build then
			for _,definition in ipairs(available) do if definition.specName==previous.specName then chosen=definition; remembered=true; break end end
		end
		if not remembered then chosen=available[math.random(#available)]; end
	end
	return chosen,V.BaseRecord(chosen),reason,build,selectedTree;
end

function V.ServerMap(channel,record)
	local map={};
	for _,item in ipairs(channel=="co" and ClassStrategyCO or ClassStrategyNC or {}) do if S.Key(item[1]) then map[item[1]]=false; end end
	-- Include server-only keys of sibling specs so changing the base removes
	-- their old class strategies, while unrelated unknown keys stay untouched.
	for _,definition in ipairs(V.Definitions()) do
		if definition.className==record.className then
			local sibling=V.BaseRecord(definition);
			for key in pairs(sibling and sibling[channel] or {}) do if S.Key(key) then map[key]=false; end end
		end
	end
	for key,value in pairs(record[channel]) do if S.Key(key) and type(value)=="boolean" then map[key]=value; end end
	return S.CopyMap(map);
end

function V.PrepareAutomatic(job)
	local entry=S.Entry(job.name); if not entry then S.Finish("альт больше не принадлежит текущему аккаунту.",false); return false; end
	local definition,record,reason,build,tree=V.SelectAutomatic(job.identity,job.replies.co,job.previewBase or entry.autoStrategy);
	if not record then
		UnBotAccountAlts.Message("Альт "..job.name..": нет серверного снимка "..tostring(job.identity.className).." / "..tostring(tree or "неопределённый спек")..". Текущая основа сохранена; выберите роль руками или дополните /ubstrategies.");
		return true;
	end
	local maps={};
	for _,channel in ipairs({"co","nc"}) do
		local map=V.ServerMap(channel,record); if not map then S.Finish("слишком большой серверный профиль; изменения не отправлялись.",false); return false; end
		for key,value in pairs(job[channel]) do map[key]=value; end
		maps[channel]=S.CopyMap(map); if not maps[channel] then S.Finish("слишком большой личный профиль; изменения не отправлялись.",false); return false; end
	end
	job.co=maps.co; job.nc=maps.nc;
	local selection=type(entry.autoStrategy)=="table" and entry.autoStrategy or {};
	selection.context=V.Context(); selection.className=definition.className; selection.specName=definition.specName;
	selection.talentBuild=build; selection.reason=reason; selection.fallback=reason~=nil;
	selection.sourceName=record.sourceName; selection.observedAt=record.observedAt; selection.selectedAt=time(); selection.lastVerifiedAt=nil;
	entry.autoStrategy=selection; job.autoSelection=selection;
	local text="серверная основа "..definition.classLabel.." / "..definition.specLabel.." из /ubstrategies";
	if reason then text=text..". Не определить по талантам ("..reason.."); выбрана временная роль. Выберите руками желаемую роль";
	else text=text.." по талантам "..build; end
	UnBotAccountAlts.Message("Альт "..job.name..": "..text..". Личные настройки применяются поверх основы.");
	return true;
end

function V.Coverage()
	local count,total=0,0; local db=V.Storage();
	for _,definition in ipairs(V.Definitions()) do total=total+1; if V.Reference(db.variants[definition.key]) then count=count+1; end end
	return count,total;
end

function V.Status()
	local db=V.Storage(); local count,total=V.Coverage();
	return "Сохранены варианты: "..count.."/"..total..(V.active and (". Проход "..tostring(V.index).."/"..#V.plan..": "..tostring(V.name or "—").." / "..tostring(V.stage))
		or (db.run and (". "..tostring(db.run.status or "остановлено")) or ". Проход ещё не запускался."));
end

function V.Send(command,channel,name)
	if V.Fighting() or V.OthersBusy() or GetTime()<S.nextSend then return false; end
	if (V.commands or 0)>=300 then V.Finish("остановлено: предел команд прохода; продолжите для завершения очистки"); return false; end
	S.nextSend=GetTime()+1.5; V.commands=(V.commands or 0)+1;
	local ok=pcall(SendChatMessage,command,channel,nil,name);
	if not ok then
		if V.stage=="cleanup" then V.Finish("остановлено: клиент отклонил удаление; временный бот сохранён для продолжения");
		else V.Fail("клиент отклонил команду"); end
	end
	return ok;
end

function V.Finish(status)
	local db=V.Storage(); db.run.status=status; db.run.finishedAt=time(); V.active=false; V.stage=nil;
	V.Message(status..". "..V.Status().." Для записи на диск выполните /reload.");
	V.Refresh();
end

function V.Cleanup()
	V.stage="cleanup"; V.cleanupStep="inspect"; V.cleanupSent=false;
	V.kickAttempts=0; V.nextKickAt=0;
	V.lateAddUntil=GetTime()+7; V.deadline=GetTime()+30;
end

function V.CleanupDone(db)
	db.run.pendingName=nil; db.run.removeConfirmedName=nil; db.run.cleanupRemoveName=nil;
	V.name=nil; V.botStartedAt=nil;
	if V.stopReason then V.Finish(V.stopReason); return; end
	if V.recovering then V.recovering=false;
	elseif V.success then V.index=V.index+1; V.attempts=0; end
	V.stage="pick";
end

function V.CleanupTick(db,now)
	local pending=db.run.pendingName; local unit=pending and UnBotAccountAlts.FindUnit(pending);
	if not pending then V.CleanupDone(db); return; end
	if now>=V.deadline then V.Finish("остановлено: очистка временного бота не завершена; продолжите после боя/операции"); return; end
	if unit and (not V.Ordinary(pending,UnBotBotRegistry.bots[pending]) or (UnBotSquadRosterIsOfflineReserve and UnBotSquadRosterIsOfflineReserve(pending,unit))) then
		V.Finish("остановлено: временный участник защищён или стал резервом; он сохранён в ростере"); return;
	end
	if V.Fighting() or V.OthersBusy() then return; end
	if V.cleanupStep=="inspect" then
		if unit and not UnitIsConnected(unit) then
			-- Resume the old remove-before-leave checkpoint without kicking an
			-- offline reserve. Only our acknowledged temporary bot is restored.
			if db.run.removeConfirmedName~=pending then V.Finish("остановлено: временный бот офлайн без подтверждения remove; он сохранён в ростере"); return; end
			if now<S.nextSend then return; end
			V.cleanupStep="reconnect"; V.reconnectUntil=now+8;
			if V.Send(".playerbot bot add "..pending,"SAY") then V.Message("возвращаю временного бота "..pending.." онлайн для выхода из группы."); end
			return;
		elseif unit then
			db.run.cleanupRemoveName=pending; db.run.removeConfirmedName=nil;
			V.cleanupStep="leave"; V.leaveUntil=now+7;
		elseif db.run.removeConfirmedName==pending then V.CleanupDone(db); return;
		elseif db.run.cleanupRemoveName==pending then V.cleanupStep="remove";
		elseif now>=V.lateAddUntil then V.CleanupDone(db); return;
		else return; end
	end
	if V.cleanupStep=="reconnect" then
		if unit and UnitIsConnected(unit) then
			db.run.cleanupRemoveName=pending; db.run.removeConfirmedName=nil;
			V.cleanupStep="leave"; V.leaveUntil=now+7;
		elseif now>=V.reconnectUntil then V.Finish("остановлено: временный бот не вернулся онлайн за 8 секунд; повторов нет"); return;
		else return; end
	end
	if V.cleanupStep=="leave" then
		if not unit then V.cleanupStep="remove";
		elseif not UnitIsConnected(unit) then V.Finish("остановлено: временный бот отключился до выхода из группы; он сохранён в ростере"); return;
		elseif now>=V.leaveUntil then V.Finish("остановлено: временный бот не вышел из группы; remove не отправлялся"); return;
		elseif V.kickAttempts<3 and now>=V.nextKickAt and now>=S.nextSend then
			V.kickAttempts=V.kickAttempts+1; V.nextKickAt=now+1.5;
			if not V.Send("leave","WHISPER",pending) then return; end
			-- Use the existing party/raid helper; leave stays in the paced queue.
			local ok=pcall(UnBotAccountAlts.KickFromGroup,pending,false);
			if not ok then V.Finish("остановлено: клиент отклонил исключение временного бота; продолжите очистку"); return; end
			if V.kickAttempts==1 then V.Message("вывожу временного бота "..pending.." из группы перед remove."); end
			return;
		else return; end
	end
	if V.cleanupStep=="remove" then
		if unit then V.Finish("остановлено: временный бот снова появился в группе; remove не отправлялся"); return; end
		if now<S.nextSend then return; end
		V.cleanupSent=true; V.cleanupStep="wait_remove"; V.removeUntil=now+8;
		V.Send(".playerbot bot remove "..pending,"SAY"); return;
	end
	if V.cleanupStep=="wait_remove" then
		if db.run.removeConfirmedName==pending and not unit then V.CleanupDone(db);
		elseif now>=V.removeUntil then V.Finish("остановлено: отключение временного бота не подтверждено; повторов нет"); end
	end
end

function V.Fail(reason)
	if not V.active then return; end
	local db=V.Storage(); local definition=V.plan[V.index];
	if definition then
		local row=db.run.progress[definition.key] or {}; db.run.progress[definition.key]=row;
		row.state="не получен"; row.reason=reason; row.attempts=V.attempts;
	end
	V.success=false; V.Cleanup();
	if S.active and S.active.mode=="survey" then S.Finish(reason,false); end
	for i=#S.queue,1,-1 do if S.queue[i].mode=="survey" then table.remove(S.queue,i); end end
end

function V.Stop(reason)
	if not V.active then return; end
	V.stopReason=reason or "остановлено пользователем";
	if S.active and S.active.mode=="survey" then S.Finish(V.stopReason,false); end
	for i=#S.queue,1,-1 do if S.queue[i].mode=="survey" then table.remove(S.queue,i); end end
	V.Cleanup();
end

function V.Start(mode,filter)
	if V.active or V.Fighting() or V.OthersBusy() or S.active or #S.queue>0 then V.Message("сначала завершите другие операции и выйдите из боя."); return false; end
	if IsInInstance and IsInInstance() then V.Message("получайте базовые снимки вне инстанса."); return false; end
	if UnBotRegistryMatchesCurrentContext and not UnBotRegistryMatchesCurrentContext(UnBotBotRegistry) then V.Message("реестр относится к другому миру или фракции."); return false; end
	local db=V.Storage(); local pending=db.run and db.run.pendingName;
	if mode~="group" and not V.GroupEmptyExcept(pending) then V.Message("для полного прохода нужна пустая группа; офлайн-резерв тоже считается участником. Есть режим «Только группа» без призыва и удаления."); return false; end
	if mode=="group" and pending then V.Message("сначала продолжите прежний проход и завершите удаление временного бота."); return false; end
	local plan={};
	for _,definition in ipairs(V.Definitions()) do
		if not filter or definition.className==filter then table.insert(plan,definition); end
	end
	if #plan==0 then V.Message("нет вариантов выбранного класса в каталоге."); return false; end
	db.serial=(tonumber(db.serial) or 0)+1;
	local run=db.run or {}; db.run=run;
	run.id=db.serial; run.mode=mode; run.filter=filter; run.startedAt=time(); run.status="идёт"; run.progress={}; run.pendingName=pending; run.finishedAt=nil;
	V.active=true; V.context=V.Context(); V.runId=db.run.id; V.plan=plan; V.index=1;
	V.tried={}; V.blockedClasses={}; V.commands=0; V.attempts=0; V.startedAt=GetTime(); V.stopReason=nil;
	V.mode=mode; V.name=pending; V.identity=nil; V.success=false; V.recovering=pending~=nil;
	if pending then V.Cleanup(); else V.stage="pick"; end
	V.Message("начат "..(mode=="group" and "опрос текущей группы" or "проход по классам и спекам").." — "..#plan.." вариантов. Только who/co ?/nc ?; стратегии и таланты не меняются.");
	V.Refresh(); return true;
end

function V.Pick()
	local db=V.Storage();
	while V.index<=#V.plan do
		local definition=V.plan[V.index];
		local known=V.Reference(db.variants[definition.key]);
		local skip=V.mode=="resume" and known;
		local candidates=not skip and not V.blockedClasses[definition.className] and V.Candidates(definition,V.mode=="group") or {};
		if skip then db.run.progress[definition.key]={state="сохранён ранее"};
		elseif V.attempts>=3 or #candidates==0 then
			local previous=db.run.progress[definition.key];
			db.run.progress[definition.key]={state="пробел",reason=V.blockedClasses[definition.className] or (previous and previous.reason) or "нет доступного представителя в реестре/группе"};
		else
			V.name=candidates[1]; V.tried[V.name]=true; V.identity=nil; V.rawWho=nil; V.success=false;
			V.attempts=V.attempts+1; V.botStartedAt=GetTime();
			db.run.progress[definition.key]={state="чтение",sourceName=V.name,attempts=V.attempts};
			if V.mode=="group" then V.stage="send_who";
			else
				if not V.GroupEmptyExcept(nil) then V.Stop("состав группы изменился; проход остановлен"); return; end
				db.run.pendingName=V.name; V.stage="send_add";
			end
			return;
		end
		V.index=V.index+1; V.attempts=0;
	end
	V.Finish("проход завершён; пробелы видны в таблице");
end

function V.OnSnapshot(job,ok,reason)
	if not V.active or V.stage~="snapshot" or job.surveyId~=V.runId or job.name~=V.name then return; end
	if not ok or not job.replies.co or not job.replies.nc then V.Fail(reason or "нет полного ответа"); return; end
	local spec=V.IdentitySpec(V.identity,job.replies.co); local key=V.Key(V.identity.className,spec);
	local definition;
	for _,item in ipairs(V.Definitions()) do if item.key==key then definition=item; break end end
	local co=S.CopyMap(job.replies.co); local nc=S.CopyMap(job.replies.nc);
	if not definition or not co or not nc then V.Fail("спек/роль не подтверждены или ответ слишком большой"); return; end
	local db=V.Storage(); local variant=db.variants[key] or {}; db.variants[key]=variant; variant.samples=variant.samples or {};
	local record=variant.samples[V.name] or {}; variant.samples[V.name]=record;
	record.className=definition.className; record.specName=spec; record.whoSpecName=V.identity.specName;
	record.sourceName=V.name; record.level=V.identity.level; record.gearScore=V.identity.gearScore;
	record.playerLevel=UnitLevel("player"); record.zoneName=GetRealZoneText and GetRealZoneText();
	record.realm=GetRealmName(); record.faction=UnitFactionGroup("player"); record.observedAt=time();
	record.rawWho=V.rawWho; record.co=co; record.nc=nc; record.context=V.context;
	variant.referenceName=V.name; variant.lastObservedAt=record.observedAt;
	local profile=UnBotBotRegistry.bots[V.name];
	for _,field in ipairs({"className","specName","level","gearScore","feralRole","talentBuild"}) do if V.identity[field]~=nil then profile[field]=V.identity[field]; end end
	profile.rawWho=V.rawWho; profile.specCheckedAt=time();
	V.success=key==V.plan[V.index].key;
	db.run.progress[V.plan[V.index].key]={state=V.success and "получен" or "другой спек",sourceName=V.name,actualKey=key,attempts=V.attempts};
	V.Message("сохранён "..definition.classLabel.." / "..definition.specLabel.." — "..V.name..", уровень "..tostring(record.level or "?").." (co и nc).");
	V.Cleanup();
end

function V.Reply(message,sender)
	if not V.active or UnBotAccountAlts.SenderKey(sender)~=UnBotAccountAlts.SenderKey(V.name) then return; end
	if V.stage~="wait_who" or GetTime()>=V.deadline then return; end
	local identity=UnBotParseBotWho and UnBotParseBotWho(message);
	if not identity or not identity.className or not identity.specName then return; end
	local profile=UnBotBotRegistry.bots[V.name];
	if not V.Ordinary(V.name,profile) then V.Fail("персонаж защищён или недоступен"); return; end
	V.identity=identity; V.rawWho=message; V.stage="enqueue_snapshot";
end

function V.System(message)
	if not V.active then return; end
	local text=tostring(message or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","");
	if V.stage=="cleanup" and V.cleanupSent then
		local name,status=text:match("^remove:%s*(%S+)%s*%-%s*(.-)%s*$");
		local run=V.Storage().run; status=status and status:gsub("%.$",""):lower();
		if name and run.pendingName and UnBotAccountAlts.SenderKey(name)==UnBotAccountAlts.SenderKey(run.pendingName)
			and (status=="ok" or status=="player is offline") and run.removeConfirmedName~=run.pendingName then
			run.removeConfirmedName=run.pendingName; V.deadline=GetTime()+8;
		end
		return;
	end
	if V.stage=="cleanup" and V.cleanupStep=="reconnect" then
		local name,status=text:match("^add:%s*(%S+)%s*%-%s*(.-)%s*$");
		if name and UnBotAccountAlts.SenderKey(name)==UnBotAccountAlts.SenderKey(V.name) and status~="ok" then
			V.Finish("остановлено: сервер отказал вернуть временного бота онлайн: "..status);
		end
		return;
	end
	if V.stage~="wait_add" then return; end
	local name,status=text:match("^add:%s*(%S+)%s*%-%s*(.-)%s*$");
	if name and UnBotAccountAlts.SenderKey(name)==UnBotAccountAlts.SenderKey(V.name) and status~="ok" then
		if status:lower():find("low",1,true) then V.blockedClasses[V.plan[V.index].className]="сервер: уровень слишком низкий"; end
		V.Fail("сервер отказал в добавлении: "..status);
	end
end

function V.Tick()
	if not V.active then return; end
	if V.context~=V.Context() then V.active=false; return; end
	local db=V.Storage(); local now=GetTime();
	if V.stage~="cleanup" then
		if V.Fighting() then V.Stop("начался бой");
		elseif V.OthersBusy() then V.Stop("началась другая операция");
		elseif IsInInstance and IsInInstance() then V.Stop("вход в инстанс");
		elseif now-V.startedAt>1800 then V.Stop("таймаут прохода 30 минут");
		elseif V.botStartedAt and V.stage~="pick" and now-V.botStartedAt>35 then V.Fail("таймаут представителя"); end
	end
	if V.stage=="pick" then V.Pick();
	elseif V.stage=="send_add" then
		if now<S.nextSend then return; end
		V.stage="wait_add"; V.deadline=now+8;
		V.Send(".playerbot bot add "..V.name,"SAY");
	elseif V.stage=="wait_add" then
		local unit=UnBotAccountAlts.FindUnit(V.name);
		if unit and UnitIsConnected(unit) then V.stage="send_who";
		elseif now>=V.deadline then V.Fail("бот не вошёл онлайн за 8 секунд"); end
	elseif V.stage=="send_who" then
		if now<S.nextSend then return; end
		local profile=UnBotBotRegistry.bots[V.name]; local unit=UnBotAccountAlts.FindUnit(V.name);
		if not V.Ordinary(V.name,profile) or not unit or not UnitIsConnected(unit) then V.Fail("представитель отключился"); return; end
		V.stage="wait_who"; V.deadline=now+6; V.Send("who","WHISPER",V.name);
	elseif V.stage=="wait_who" then if now>=V.deadline then V.Fail("нет ответа who за 6 секунд"); end
	elseif V.stage=="enqueue_snapshot" then
		if S.Enqueue(V.name,"survey") then S.queue[#S.queue].surveyId=V.runId; V.stage="snapshot";
		else V.Fail("очередь чтения недоступна"); end
	elseif V.stage=="cleanup" then
		V.CleanupTick(db,now);
	end
end

function V.CopyPreset(channel,record)
	local ui=S.ui; if not ui or not ui.loaded or V.active or S.active or #S.queue>0 then return false; end
	local profile=UnBotAccountAlts.GetProfile(ui.name);
	if not profile or profile.className~=record.className or V.Spec(profile)~=record.specName or record.context~=V.Context() then V.Message("снимок не соответствует классу/спеку альта."); return false; end
	local map={};
	for _,item in ipairs(S.Catalog(channel)) do map[item.key]=record[channel][item.key]==true; end
	for key in pairs(record[channel]) do map[key]=true; end
	map=S.CopyMap(map); if not map then return false; end
	ui.draft[channel]=map; ui.draft[channel=="co" and "role" or "behavior"]="Снимок: "..record.sourceName;
	local old=ui.draft.samplePreset;
	local metadata={className=record.className,specName=record.specName,context=record.context,sources={}};
	for key,value in pairs(old and old.sources or {}) do metadata.sources[key]=value; end
	metadata.sources[channel]={name=record.sourceName,observedAt=record.observedAt}; ui.draft.samplePreset=metadata;
	ui.draft.enabled=true; ui.dirty=true; ui.explainKey=nil;
	ui.presetExplanation="Снимок "..record.className.." / "..record.specName.." от "..record.sourceName..", уровень "..tostring(record.level or "?")..", "..date("%d.%m.%Y %H:%M",record.observedAt)..". Это прочитанное состояние; при применении класс/спек альта проверяются через who.";
	S.RefreshPanel(); return true;
end

function V.AddPresetMenu(menu,channel)
	local ui=S.ui; local profile=ui and UnBotAccountAlts.GetProfile(ui.name); if not profile then return; end
	local variant=V.Storage().variants[V.Key(profile.className,V.Spec(profile))];
	table.insert(menu,{text="Снимки класса / специализации",isTitle=true,notCheckable=true});
	local names={}; for name,record in pairs(variant and variant.samples or {}) do
		if type(name)=="string" and type(record)=="table" and type(record.co)=="table" and type(record.nc)=="table" and record.context==V.Context() then table.insert(names,name); end
	end; table.sort(names);
	for _,name in ipairs(names) do
		local record=variant.samples[name]; local chosen=ui.draft.samplePreset and ui.draft.samplePreset.sources[channel];
		table.insert(menu,{text=name.." — ур. "..tostring(record.level or "?")..", "..date("%d.%m %H:%M",record.observedAt),checked=chosen and chosen.name==name and ui.draft[channel=="co" and "role" or "behavior"]=="Снимок: "..name or false,
			func=function() V.CopyPreset(channel,record); CloseDropDownMenus(); end});
	end
	if #names==0 then table.insert(menu,{text="Для этого класса/спека снимка нет",disabled=true,notCheckable=true}); end
	table.insert(menu,{text="Открыть сборщик стратегий",notCheckable=true,func=function() V.Open(); CloseDropDownMenus(); end});
end

function V.SortedKeys(map)
	local keys={}; for key,value in pairs(map or {}) do if value==true then table.insert(keys,key); end end; table.sort(keys); return table.concat(keys,", ");
end

function V.Refresh()
	local ui=V.ui; if not ui then return; end
	local definitions=V.Definitions(); local db=V.Storage(); ui.status:SetText(V.Status());
	ui.offset=math.max(0,math.min(ui.offset or 0,math.max(0,#definitions-#ui.rows)));
	for i,row in ipairs(ui.rows) do
		local definition=definitions[ui.offset+i]; row.definition=definition;
		if definition then
			row:Show(); local sample=V.Reference(db.variants[definition.key]); local progress=db.run and db.run.progress[definition.key];
			row.label:SetText(definition.classLabel.." / "..definition.specLabel);
			row.source:SetText(sample and (sample.sourceName.." / ур. "..tostring(sample.level or "?")) or "—");
			row.state:SetText(progress and progress.state or (sample and "сохранён" or "нет снимка"));
		else row:Hide(); end
	end
	local detail=ui.selected and db.variants[ui.selected]; local sample=V.Reference(detail);
	local progress=db.run and db.run.progress[ui.selected or ""];
	ui.detail:SetText(sample and ("Источник: "..sample.sourceName.." / "..sample.className.." / "..sample.specName.." / уровень "..tostring(sample.level or "?").." / "..date("%d.%m.%Y %H:%M",sample.observedAt)
		..(progress and progress.reason and ("\nПоследний проход: "..progress.reason.."; прежний снимок сохранён.") or "")
		.."\nco: "..V.SortedKeys(sample.co).."\nnc: "..V.SortedKeys(sample.nc)) or (progress and progress.reason or "Выберите вариант, чтобы увидеть co/nc и источник. Наведение на строку показывает полный снимок. Пробелы не заменяются общим пресетом."));
	for _,button in ipairs(ui.starts) do if V.active then button:Disable(); else button:Enable(); end end
	if V.active then ui.stop:Enable(); else ui.stop:Disable(); end
end

function V.Open()
	if not V.ui then V.CreatePanel(); end
	V.Refresh(); V.ui.parent:Show();
	V.ui.parent:SetScale(math.min(1,(UIParent:GetWidth()-32)/1010,(UIParent:GetHeight()-32)/700));
end

function V.CreatePanel()
	local parent=CreateFrame("Frame","UnBotStrategySurveyWindow",UIParent);
	parent:SetWidth(1010); parent:SetHeight(700); parent:SetPoint("CENTER"); parent:SetFrameStrata("FULLSCREEN_DIALOG"); parent:SetClampedToScreen(true);
	parent:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=false,edgeSize=32,insets={left=11,right=12,top=12,bottom=11}}); parent:SetBackdropColor(.025,.025,.025,1);
	local ui={parent=parent,rows={},starts={},offset=0}; V.ui=ui;
	local function label(x,y,width,text)
		local field=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); field:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y); field:SetWidth(width); field:SetJustifyH("LEFT"); field:SetText(text or ""); return field;
	end
	local function button(x,y,width,text,action)
		local control=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate"); control:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y); control:SetWidth(width); control:SetHeight(24); control:SetText(text); control:SetScript("OnClick",action); return control;
	end
	label(24,-24,960,"Снимки стратегий по классам и специализациям");
	local help=label(24,-52,960,"Полный проход: пустая группа, вне инстанса. Один бот за раз: add -> who -> co ? -> nc ? -> leave -> remove. Без смены талантов и стратегий.\n«Только группа» читает обычных онлайн-ботов вашей группы без призыва/удаления. Альты и офлайн-резерв не опрашиваются."); help:SetHeight(32);
	ui.status=label(24,-94,960,"");
	label(30,-124,420,"КЛАСС / СПЕК"); label(462,-124,300,"ИСТОЧНИК СНИМКА"); label(790,-124,180,"ПОСЛЕДНИЙ ПРОХОД");
	for i=1,13 do
		local row=button(24,-148-(i-1)*27,960,"",function(self) if self.definition then ui.selected=self.definition.key; V.Refresh(); end end);
		local function field(x,width)
			local text=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); text:SetPoint("LEFT",row,"LEFT",x,0); text:SetWidth(width); text:SetJustifyH("LEFT"); return text;
		end
		row.label=field(6,420); row.source=field(438,315); row.state=field(766,180); table.insert(ui.rows,row);
		row:SetScript("OnEnter",function(self)
			local sample=self.definition and V.Reference(V.Storage().variants[self.definition.key]); if not sample then return; end
			GameTooltip:SetOwner(self,"ANCHOR_TOP"); GameTooltip:AddLine(self.definition.classLabel.." / "..self.definition.specLabel,1,.82,.2);
			GameTooltip:AddLine("Источник: "..sample.sourceName..", уровень "..tostring(sample.level or "?")..", "..date("%d.%m.%Y %H:%M",sample.observedAt),1,1,1,true);
			GameTooltip:AddLine("co: "..V.SortedKeys(sample.co),.6,.8,1,true); GameTooltip:AddLine("nc: "..V.SortedKeys(sample.nc),.6,.8,1,true); GameTooltip:Show();
		end);
		row:SetScript("OnLeave",function() GameTooltip:Hide(); end);
	end
	button(24,-512,45,"<",function() ui.offset=ui.offset-13; V.Refresh(); end);
	button(74,-512,45,">",function() ui.offset=ui.offset+13; V.Refresh(); end);
	ui.detail=label(24,-547,960,""); ui.detail:SetHeight(76); ui.detail:SetJustifyV("TOP");
	table.insert(ui.starts,button(24,-645,185,"Собрать все варианты",function() V.Start("all"); end));
	table.insert(ui.starts,button(219,-645,185,"Продолжить пробелы",function() V.Start("resume"); end));
	table.insert(ui.starts,button(414,-645,185,"Только группа",function() V.Start("group"); end));
	ui.stop=button(609,-645,185,"Остановить",function() V.Stop(); end);
	button(804,-645,180,"Закрыть",function() parent:Hide(); end);
	if UISpecialFrames then table.insert(UISpecialFrames,"UnBotStrategySurveyWindow"); end
	parent:SetScript("OnUpdate",function(self,elapsed) ui.elapsed=(ui.elapsed or 0)+elapsed; if ui.elapsed>=.5 then ui.elapsed=0; V.Refresh(); end end);
	parent:Hide();
end

V.frame=CreateFrame("Frame"); V.frame:RegisterEvent("CHAT_MSG_WHISPER"); V.frame:RegisterEvent("CHAT_MSG_SYSTEM"); V.frame:RegisterEvent("PLAYER_LEAVING_WORLD");
V.frame:SetScript("OnEvent",function(self,event,message,sender)
	if event=="CHAT_MSG_WHISPER" then V.Reply(message,sender);
	elseif event=="CHAT_MSG_SYSTEM" then V.System(message);
	elseif V.active then
		local db=V.Storage(); db.run.status="приостановлено после выхода/reload"; V.active=false;
		if S.active and S.active.mode=="survey" then S.active=nil; end
		for i=#S.queue,1,-1 do if S.queue[i].mode=="survey" then table.remove(S.queue,i); end end
	end
end);
V.frame:SetScript("OnUpdate",function() V.Tick(); end);

-- Manual equipment action and read-only summon preflight share the existing
-- AccountAlts event/update frame. Neither creates a persistent retry queue.
function UnBotAccountAlts.EquipmentBusy()
	return UnBotAccountAlts.active or UnBotAccountAlts.discoveryActive
		or UnBotAccountAlts.OtherAutomationActive(true)
		or (UnBotMythicPlusBuffOtherAutomationActive and UnBotMythicPlusBuffOtherAutomationActive())
		or (UnBotAltStrategies and (UnBotAltStrategies.active or #(UnBotAltStrategies.queue or {}) > 0))
		or (UnBotBeaconTravel and (UnBotBeaconTravel.active or (UnBotBeaconTravel.GetTask and UnBotBeaconTravel.GetTask())))
		or (UnBotRegistryRefresh and UnBotRegistryRefresh.Running and UnBotRegistryRefresh.Running())
		or (UnBotStrategySurvey and UnBotStrategySurvey.active)
		or (UnBotMarket and UnBotMarket.job);
end

function UnBotAccountAlts.SummonContext()
	return UnBotAccountAlts.Key(GetRealmName and GetRealmName() or "").."|"..UnBotAccountAlts.Key(UnitName("player"));
end

function UnBotAccountAlts.RefreshForSummon()
 -- Opening an editor never requests bot/account lists or discovers characters.
 UnBotAccountAlts.RefreshForCenter();
 return false;
end

function UnBotAccountAlts.SummonRefreshTick()
 -- Kept for the existing event frame; all discovery is an explicit player action.
end

function UnBotAccountAlts.SummonSelectionReady()
	for _, slot in ipairs(UnBotSquadConfig.slots or {}) do
		local name = slot.accountAltName;
		if name and name ~= "" then
			local own = UnBotAccountAlts.IsBoundToCurrentAccount(name);
			local linked = UnBotAccountAlts.LinkedCharacter(name);
			if not (own or linked) or not UnBotAccountAlts.IsEnabled(name) then
				return false, "Альт "..name..": привязка не подтверждена или альт выключен. "
					.."Для своих альтов запустите «Найти альтов автоматически»; для связанных — «Обновить привязки» и явный сбор имён в «Связанных аккаунтах».";
			end
		end
	end
	return true;
end

function UnBotAccountAlts.EquipUpgradesEligible(name)
	if UnBotAccountAlts.Key(name) == UnBotAccountAlts.Key(UnitName("player")) or not UnBotAccountAlts.IsListed(name) then return nil; end
	local unit = UnBotAccountAlts.FindUnit(name);
	if unit and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) and not UnitAffectingCombat(unit) then return unit; end
end

function UnBotAccountAlts.EquipUpgradesStop(reason)
	local job = UnBotAccountAlts.equipUpgrades;
	if not job or not job.active then return; end
	job.active = false;
	UnBotAccountAlts.Message("Экипировка альтов: "..(reason or "очередь завершена")..". Команд отправлено: "..job.sent
		..", сообщений об экипировке: "..job.upgrades..", отказов: "..job.failed..", пропущено: "..job.skipped
		..". Отсутствие ответа не подтверждает смену экипировки.");
end

function UnBotAccountAlts.EquipUpgradesStart()
	if UnBotAccountAlts.equipUpgrades and UnBotAccountAlts.equipUpgrades.active then
		UnBotAccountAlts.EquipUpgradesStop("остановлено игроком"); return false;
	end
	if (InCombatLockdown and InCombatLockdown()) or UnitAffectingCombat("player") then
		UnBotAccountAlts.Message("Экипировка альтов доступна вне боя."); return false;
	end
	if UnBotAccountAlts.summonRefresh or UnBotAccountAlts.EquipmentBusy() then
		UnBotAccountAlts.Message("Экипировка альтов: сначала завершите текущую операцию UnBot."); return false;
	end
	UnBotAccountAlts.ValidateAccountBinding();
	local queue, seen = {}, {};
	local raid = GetNumRaidMembers and GetNumRaidMembers() or 0;
	for i=1, (raid > 0 and raid or (GetNumPartyMembers and GetNumPartyMembers() or 0)) do
		local unit = (raid > 0 and "raid" or "party")..i;
		local name = UnitName(unit);
		local key = UnBotAccountAlts.Key(name);
		if name and key ~= "" and not seen[key] and UnBotAccountAlts.EquipUpgradesEligible(name) then
			seen[key] = true; queue[#queue+1] = {name=name, guid=UnitGUID and UnitGUID(unit)};
		end
	end
	if #queue == 0 then UnBotAccountAlts.Message("Экипировка альтов: в составе нет доступных онлайн-альтов своих или связанных аккаунтов."); return false; end
	UnBotAccountAlts.equipUpgrades = {active=true, queue=queue, index=1, sent=0, upgrades=0, failed=0, skipped=0,
		replies={}, nextSend=GetTime(), deadline=GetTime()+#queue*1.5+8, context=UnBotAccountAlts.SummonContext()};
	UnBotAccountAlts.Message("Экипировка альтов: отправляю equip upgrade онлайн-альтам в составе ("..#queue..").");
	return true;
end

function UnBotAccountAlts.EquipUpgradesTick()
	local job = UnBotAccountAlts.equipUpgrades;
	if not job or not job.active then return; end
	local now = GetTime();
	if job.context ~= UnBotAccountAlts.SummonContext() or (InCombatLockdown and InCombatLockdown()) or UnitAffectingCombat("player")
		or UnBotAccountAlts.EquipmentBusy() then UnBotAccountAlts.EquipUpgradesStop("бой, смена персонажа или другая операция"); return; end
	if now >= job.deadline then UnBotAccountAlts.EquipUpgradesStop("таймаут"); return; end
	if now < job.nextSend then return; end
	local entry = job.queue[job.index];
	if not entry then UnBotAccountAlts.EquipUpgradesStop(); return; end
	job.index = job.index+1;
	local unit = UnBotAccountAlts.EquipUpgradesEligible(entry.name);
	if not unit or (entry.guid and UnitGUID(unit) ~= entry.guid) then job.skipped = job.skipped+1;
	else
		job.replies[UnBotAccountAlts.SenderKey(entry.name)] = {};
		local ok = pcall(SendChatMessage, "equip upgrade", "WHISPER", nil, entry.name);
		if not ok then UnBotAccountAlts.EquipUpgradesStop("ошибка отправки команды"); return; end
		job.sent = job.sent+1;
	end
	job.nextSend = now + (job.index > #job.queue and 5 or 1.5);
end

function UnBotAccountAlts.EquipUpgradesEvent(event, message, sender)
	if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_LEAVING_WORLD" then
		UnBotAccountAlts.summonRefresh = nil;
		if UnBotSquadSummon and UnBotSquadSummon.pendingBinding then
			UnBotSquadSummon.pendingBinding = nil;
			UnBotAccountAlts.Message("Ожидание привязок перед призывом отменено: бой или выход из мира.");
		end
	end
	local job = UnBotAccountAlts.equipUpgrades;
	if not job or not job.active then return; end
	if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_LEAVING_WORLD" then
		UnBotAccountAlts.EquipUpgradesStop("бой или выход из мира"); return;
	end
	if event ~= "CHAT_MSG_WHISPER" then return; end
	local reply = job.replies[UnBotAccountAlts.SenderKey(sender)];
	if not reply then return; end
	local text = tostring(message or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower();
	if text:find("unknown command",1,true) or text:find("unknown action",1,true) then
		UnBotAccountAlts.EquipUpgradesStop("сервер не поддерживает equip upgrade"); return;
	end
	if text:find("cannot equip",1,true) or text:find("can't equip",1,true) or text:find("not allowed",1,true) or text:find("too low",1,true) then
		if not reply.failed then reply.failed=true; job.failed=job.failed+1; end
	elseif text:find("equipping",1,true) then job.upgrades=job.upgrades+1; end
end
SLASH_UNBOTSTRATEGYSURVEY1="/ubstrategies";
SlashCmdList.UNBOTSTRATEGYSURVEY=function(message)
	local command,filter=tostring(message or ""):match("^%s*(%S*)%s*(.-)%s*$"); if filter=="" then filter=nil; end
	if command=="start" then V.Start("all",filter);
	elseif command=="resume" then V.Start("resume",filter);
	elseif command=="group" then V.Start("group",filter);
	elseif command=="stop" then V.Stop();
	elseif command=="status" then V.Message(V.Status());
	else V.Open(); end
end;
end
