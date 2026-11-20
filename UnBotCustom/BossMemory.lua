local ADDON = "UnBotCustom";

-- Storage is initialized after UnBot SavedVariables have loaded.

local BM = {
	active = nil,
	lastAttempt = nil,
	updateTick = 0,
	groupNames = {},
	ui = nil,
	minimapButton = nil,
	rosterByName = {},
	lastRosterByName = {},
	lastAttemptFinishedAt = nil,
	saveReloadPending = false,
	saveReloadAt = nil,
	saveReloadRewardSeen = false,
	lootOpen = false,
	activeLootRolls = {},
	lootCheckPending = nil,
};

local GuessSpecFromWho;
local RefreshBossMemoryUI;
local SortedMechanics;
local MigrateBossMemoryDB;
local SyncLastKillRosterSpec;

local MAX_RECENT_WIPES = 50;
local LATE_KILL_WINDOW = 30;
local BOSS_COMPLETION_TIMEOUT = 60;
local AUTO_SAVE_RELOAD_DELAY = 60;
local LOOT_METHOD_VERIFY_DELAY = 0.5;

local BossRewardItemIDs = {
	[40752] = "Emblem of Heroism",
	[40753] = "Emblem of Valor",
	[45624] = "Emblem of Conquest",
	[47241] = "Emblem of Triumph",
	[49426] = "Emblem of Frost",
};

local BossRewardTextAliases = {
	["emblem of heroism"] = 40752,
	["эмблема героизма"] = 40752,
	["Эмблема героизма"] = 40752,
	["emblem of valor"] = 40753,
	["эмблема доблести"] = 40753,
	["Эмблема доблести"] = 40753,
	["emblem of conquest"] = 45624,
	["эмблема завоевания"] = 45624,
	["Эмблема завоевания"] = 45624,
	["emblem of triumph"] = 47241,
	["эмблема триумфа"] = 47241,
	["Эмблема триумфа"] = 47241,
	["emblem of frost"] = 49426,
	["эмблема льда"] = 49426,
	["Эмблема льда"] = 49426,
};

local BossCatalogByNpcId = {};
for _, instance in ipairs(BossMemoryBossCatalog or {}) do
	for _, encounter in ipairs(instance.bosses or {}) do
		for _, npcId in ipairs(encounter.ids or {}) do
			BossCatalogByNpcId[npcId] = {
				instance = instance.instance,
				instanceType = instance.instanceType,
				encounter = encounter.name,
				friendlyVictory = encounter.friendlyVictory and true or false,
			};
		end
	end
end

local TrashBossNames = {
	["Валь'кира-глашатай"] = true,
	["Верховный правитель Саурфанг"] = true,
	["Вестник смерти - верховный жрец"] = true,
	["Волдырный зомби"] = true,
	["Вонючка"] = true,
	["Воскрешенный верховный маг"] = true,
	["Гинзелль Отразительница Гнили"] = true,
	["Гниющий ледяной великан"] = true,
	["Заклятый страж"] = true,
	["Исторгающий пламя скелет"] = true,
	["Каифа Неумолимый"] = true,
	["Кор'кронский боевой маг"] = true,
	["Кор'кронский метатель топоров"] = true,
	["Маз'дина"] = true,
	["Наррок Крушитель Стали"] = true,
	["Оача'ноа"] = true,
	["Прелесть"] = true,
	["Прожорливое поганище"] = true,
	["Проклятый"] = true,
	["Разлагающийся колосс"] = true,
	["Снобольд-вассал"] = true,
	["Харкзог"] = true,
	["Эрин Мглистое Копыто"] = true,
};

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffUnBot — история боссов|r: "..tostring(msg));
end

local function IsLootUIBusy()
	if (BM.lootOpen) then
		return true;
	end
	if (LootFrame and LootFrame.IsShown and LootFrame:IsShown()) then
		return true;
	end
	if (MasterLooterFrame and MasterLooterFrame.IsShown and MasterLooterFrame:IsShown()) then
		return true;
	end

	local now = GetTime();
	for rollId, expiresAt in pairs(BM.activeLootRolls) do
		if (expiresAt and expiresAt > now) then
			return true;
		end
		BM.activeLootRolls[rollId] = nil;
	end

	local frameCount = NUM_GROUP_LOOT_FRAMES or 4;
	for i = 1, frameCount do
		local rollFrame = _G["GroupLootFrame"..i];
		if (rollFrame and rollFrame.IsShown and rollFrame:IsShown()) then
			return true;
		end
	end
	return false;
end

local function ScheduleKillSaveReload(confirmation)
	if (BossMemoryDB and BossMemoryDB.recordHistory == false) then return; end
	local rewardConfirmed = string.find(tostring(confirmation or ""), "reward:", 1, true) ~= nil;
	BM.saveReloadPending = true;
	BM.saveReloadRewardSeen = rewardConfirmed;
	BM.saveReloadAt = GetTime() + (rewardConfirmed and 0 or AUTO_SAVE_RELOAD_DELAY);
	if (rewardConfirmed) then
		Print("confirmed kill queued for disk save; waiting for loot and rolls to close");
	else
		Print("confirmed kill queued for disk save; 60s allowed for chest loot and rolls");
	end
end

local function Round(num, decimals)
	local mult = 10 ^ (decimals or 0);
	return math.floor(num * mult + 0.5) / mult;
end

local function FormatNumber(num)
	num = tonumber(num);
	if (not num) then
		return "?";
	end
	if (num >= 1000000) then
		return tostring(Round(num / 1000000, 1)).."m";
	elseif (num >= 1000) then
		return tostring(Round(num / 1000, 1)).."k";
	end
	return tostring(num);
end

local function SnapshotBossRewardCounts()
	local counts = {};
	for itemId in pairs(BossRewardItemIDs) do
		counts[itemId] = GetItemCount and (GetItemCount(itemId) or 0) or 0;
	end
	return counts;
end

local function SafeName(name)
	if (not name or name == "" or name == UNKNOWN or name == UNKNOWNOBJECT) then
		return nil;
	end
	return name;
end

local function NormalizeText(text)
	text = string.lower(tostring(text or ""));
	text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "");
	text = string.gsub(text, "|r", "");
	text = string.gsub(text, "|h", "");
	text = string.gsub(text, "%s+", " ");
	text = string.gsub(text, "^%s+", "");
	text = string.gsub(text, "%s+$", "");
	return text;
end

local BMClassSpecs = {
	WARRIOR = {"Arms", "Fury", "Protection"},
	PALADIN = {"Holy", "Protection", "Retribution"},
	HUNTER = {"Beast Mastery", "Marksmanship", "Survival"},
	ROGUE = {"Assassination", "Assasination", "Combat", "Subtlety"},
	PRIEST = {"Discipline", "Holy", "Shadow"},
	SHAMAN = {"Elemental", "Enhancement", "Restoration"},
	MAGE = {"Arcane", "Fire", "Frost"},
	WARLOCK = {"Affliction", "Demonology", "Destruction"},
	DRUID = {"Balance", "Feral Combat", "Restoration"},
	DEATHKNIGHT = {"Blood", "Frost", "Unholy"},
};

local function CanonicalSpecName(spec)
	if (spec == "Assasination") then
		return "Assassination";
	end
	return spec;
end

local function PlayerTalentSpec()
	local bestName = nil;
	local bestPoints = -1;
	for i = 1, 3 do
		local name, icon, pointsSpent = GetTalentTabInfo(i);
		if (name and (pointsSpent or 0) > bestPoints) then
			bestName = name;
			bestPoints = pointsSpent or 0;
		end
	end
	if (bestName and bestPoints > 0) then
		return bestName;
	end
	return nil;
end

local function BuildRosterLookup(roster)
	local byName = {};
	for _, member in ipairs(roster or {}) do
		if (member.name) then
			byName[member.name] = member;
		end
	end
	return byName;
end

local function SetRosterSpec(name, spec)
	if (not name or not spec or spec == "") then
		return;
	end
	local member = BM.rosterByName and BM.rosterByName[name];
	if (not member) then
		member = BM.lastRosterByName and BM.lastRosterByName[name];
	end
	if (member) then
		member.spec = CanonicalSpecName(spec);
		if (SyncLastKillRosterSpec) then
			SyncLastKillRosterSpec(name, member.spec);
		end
	end
end

local function GetRosterMemberForSpec(name)
	if (BM.rosterByName and BM.rosterByName[name]) then
		return BM.rosterByName[name];
	end
	if (BM.lastRosterByName and BM.lastRosterByName[name]) then
		return BM.lastRosterByName[name];
	end
	return nil;
end

local function HandleWhoWhisper(message, sender)
	local member = GetRosterMemberForSpec(sender);
	if (not member) then
		return;
	end
	local spec = GuessSpecFromWho(message, member.classFile);
	if (spec) then
		SetRosterSpec(sender, spec);
		if (BM.ui and BM.ui.frame and BM.ui.frame:IsShown()) then
			RefreshBossMemoryUI();
		end
	end
end

function GuessSpecFromWho(message, classFile)
	local text = NormalizeText(message);
	classFile = tostring(classFile or "");
	local specs = BMClassSpecs[classFile];
	if (not specs) then
		return nil;
	end
	if (not string.find(text, " lvl", 1, true) or not string.find(text, " gs", 1, true)) then
		return nil;
	end
	for _, spec in ipairs(specs) do
		local normalizedSpec = NormalizeText(spec);
		if (string.find(text, normalizedSpec.." (", 1, true)) then
			return CanonicalSpecName(spec);
		end
	end
	return nil;
end

local function RequestRosterSpecs(roster)
	for _, member in ipairs(roster or {}) do
		if (member.name == UnitName("player")) then
			member.spec = PlayerTalentSpec();
		elseif (member.name) then
			SendChatMessage("who", "WHISPER", nil, member.name);
		end
	end
end

local function DifficultyMode(instanceType, difficultyIndex, difficultyName)
	local index = tonumber(difficultyIndex) or 0;
	local text = string.lower(tostring(difficultyName or ""));
	if (
		string.find(text, "heroic", 1, true)
		or string.find(text, "геро", 1, true)
	) then
		return "heroic";
	end
	if (instanceType == "raid" and (index == 3 or index == 4)) then
		return "heroic";
	end
	if (instanceType == "party" and index == 2) then
		return "heroic";
	end
	return "normal";
end

local function CanonicalDifficultyIndex(instanceType, maxPlayers, mode, difficultyIndex)
	local index = tonumber(difficultyIndex) or 0;
	if (index > 0) then
		return index;
	end
	local size = tonumber(maxPlayers) or 0;
	if (instanceType == "raid") then
		if (mode == "heroic") then
			return size >= 25 and 4 or 3;
		end
		return size >= 25 and 2 or 1;
	end
	if (instanceType == "party") then
		return mode == "heroic" and 2 or 1;
	end
	return 0;
end

local function BuildInstanceKey(name, instanceType, maxPlayers, difficultyIndex, difficultyName, difficultyMode)
	name = name or "World";
	instanceType = instanceType or "none";
	maxPlayers = tonumber(maxPlayers) or 0;
	local mode = difficultyMode or DifficultyMode(instanceType, difficultyIndex, difficultyName);
	local index = CanonicalDifficultyIndex(instanceType, maxPlayers, mode, difficultyIndex);
	return table.concat({
		tostring(name),
		tostring(instanceType),
		tostring(maxPlayers),
		tostring(index),
		tostring(mode),
	}, "|"), index, mode;
end

local function ParseInstanceStorageKey(key)
	local name, instanceType, maxPlayers, difficultyIndex, mode =
		string.match(key or "", "^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$");
	if (name) then
		return name, instanceType, tonumber(maxPlayers) or 0,
			tonumber(difficultyIndex) or 0, mode;
	end
	local legacyName, legacyType, legacyMaxPlayers, legacyDifficultyName =
		string.match(key or "", "^([^|]*)|([^|]*)|([^|]*)|(.*)$");
	local legacyMode = DifficultyMode(
		legacyType,
		nil,
		legacyDifficultyName
	);
	return legacyName or key or "Unknown", legacyType or "",
		tonumber(legacyMaxPlayers) or 0,
		CanonicalDifficultyIndex(legacyType, legacyMaxPlayers, legacyMode, nil),
		legacyMode,
		legacyDifficultyName or "";
end

local function InitDB()
	BossMemoryDB.version = tonumber(BossMemoryDB.version) or 0;
	BossMemoryDB.bosses = BossMemoryDB.bosses or {};
	BossMemoryDB.last = BossMemoryDB.last or nil;
	BossMemoryDB.minimap = BossMemoryDB.minimap or { angle = 225, hide = false };
	MigrateBossMemoryDB();
	BossMemoryDB.version = math.max(tonumber(BossMemoryDB.version) or 0, 9);
end

local function GetInstanceKey()
	local name, instanceType, difficultyIndex, difficultyName, maxPlayers = GetInstanceInfo();
	name = name or "World";
	instanceType = instanceType or "none";
	difficultyName = difficultyName or "";
	maxPlayers = maxPlayers or 0;
	local key, canonicalIndex, mode = BuildInstanceKey(
		name,
		instanceType,
		maxPlayers,
		difficultyIndex,
		difficultyName
	);
	return key, name, instanceType, difficultyName, maxPlayers, canonicalIndex, mode;
end

local function GetRoster()
	local roster = {};
	local count = 0;

	if (GetNumRaidMembers() and GetNumRaidMembers() > 0) then
		for i = 1, GetNumRaidMembers(), 1 do
			local name, rank, subgroup, level, className, classFileName, zone, online, isDead, role = GetRaidRosterInfo(i);
			name = SafeName(name);
			if (name) then
				count = count + 1;
				table.insert(roster, {
					name = name,
					level = level,
					class = className,
					classFile = classFileName,
					group = subgroup,
					online = online and true or false,
					dead = isDead and true or false,
					role = role,
				});
			end
		end
	else
		local playerName = UnitName("player");
		local _, playerClass = UnitClass("player");
		table.insert(roster, {
			name = playerName,
			level = UnitLevel("player"),
			class = select(1, UnitClass("player")),
			classFile = playerClass,
			group = 1,
			online = true,
			dead = UnitIsDeadOrGhost("player") and true or false,
		});
		count = 1;

		for i = 1, GetNumPartyMembers(), 1 do
			local unit = "party"..i;
			local name = SafeName(UnitName(unit));
			if (name) then
				local className, classFileName = UnitClass(unit);
				count = count + 1;
				table.insert(roster, {
					name = name,
					level = UnitLevel(unit),
					class = className,
					classFile = classFileName,
					group = 1,
					online = UnitIsConnected(unit) and true or false,
					dead = UnitIsDeadOrGhost(unit) and true or false,
				});
			end
		end
	end

	table.sort(roster, function(a, b)
		return tostring(a.name) < tostring(b.name);
	end);

	return roster, count;
end

local function RosterSummary(roster)
	local classes = {};
	for _, member in ipairs(roster or {}) do
		local class = member.classFile or member.class or "?";
		classes[class] = (classes[class] or 0) + 1;
	end

	local parts = {};
	for class, count in pairs(classes) do
		table.insert(parts, class..":"..count);
	end
	table.sort(parts);
	return table.concat(parts, ", ");
end

local function CopyRoster(roster)
	local copy = {};
	for _, member in ipairs(roster or {}) do
		table.insert(copy, {
			name = member.name,
			level = member.level,
			class = member.class,
			classFile = member.classFile,
			group = member.group,
			online = member.online,
			dead = member.dead,
			role = member.role,
			spec = member.spec,
		});
	end
	return copy;
end

local function NpcIdFromGUID(guid)
	if (not guid or type(guid) ~= "string" or string.len(guid) < 12) then
		return nil;
	end
	return tonumber(string.sub(guid, 9, 12), 16);
end

local function KillLogKey(row)
	if (row.recordId and row.recordId ~= "") then
		return tostring(row.recordId);
	end
	return tostring(row.instanceKey or "").."|"..tostring(row.bossName or "").."|"..tostring(row.startDate or "").."|"..tostring(row.endDate or "").."|"..tostring(row.groupSize or "").."|"..tostring(row.duration or "");
end

local function DeepCopy(value, seen)
	if (type(value) ~= "table") then
		return value;
	end
	seen = seen or {};
	if (seen[value]) then
		return seen[value];
	end
	local copy = {};
	seen[value] = copy;
	for key, child in pairs(value) do
		copy[DeepCopy(key, seen)] = DeepCopy(child, seen);
	end
	return copy;
end

local function KillSnapshot(attempt)
	local snapshot = DeepCopy(attempt);
	snapshot.result = "kill";
	snapshot.minPercent = 0;
	snapshot.bossMinHealth = 0;
	return snapshot;
end

local function EnsureKillLog(bucket)
	bucket.killsLog = bucket.killsLog or {};

	local seen = {};
	for index, row in ipairs(bucket.killsLog) do
		seen[KillLogKey(row)] = index;
	end
	for _, attempt in ipairs(bucket.attempts or {}) do
		if (attempt.result == "kill") then
			local key = KillLogKey(attempt);
			if (not seen[key]) then
				table.insert(bucket.killsLog, KillSnapshot(attempt));
				seen[key] = #bucket.killsLog;
			else
				-- Upgrade old compact snapshots while the full attempt is still available.
				bucket.killsLog[seen[key]] = KillSnapshot(attempt);
			end
		end
	end
	bucket.kills = math.max(tonumber(bucket.kills) or 0, #bucket.killsLog);
end

SyncLastKillRosterSpec = function(name, spec)
	local attempt = BM.lastAttempt;
	if (not attempt or attempt.result ~= "kill") then
		return;
	end
	local bosses = BossMemoryDB.bosses and BossMemoryDB.bosses[attempt.instanceKey];
	local bucket = bosses and bosses[attempt.bossName];
	if (not bucket) then
		return;
	end
	local attemptKey = KillLogKey(attempt);
	for _, kill in ipairs(bucket.killsLog or {}) do
		if (KillLogKey(kill) == attemptKey) then
			for _, member in ipairs(kill.roster or {}) do
				if (member.name == name) then
					member.spec = CanonicalSpecName(spec);
					return;
				end
			end
		end
	end
end

local function PruneRecentWipes(bucket)
	local attempts = bucket.attempts or {};
	local wipes = 0;
	for _, attempt in ipairs(attempts) do
		if (attempt.result ~= "kill") then
			wipes = wipes + 1;
		end
	end

	local index = 1;
	while (wipes > MAX_RECENT_WIPES and index <= #attempts) do
		if (attempts[index].result ~= "kill") then
			table.remove(attempts, index);
			wipes = wipes - 1;
		else
			index = index + 1;
		end
	end
end

local function BucketContainsOnlyNonCatalogNpcs(bucket)
	local foundNpc = false;
	for _, source in ipairs({bucket.attempts or {}, bucket.killsLog or {}}) do
		for _, row in ipairs(source) do
			local npcId = NpcIdFromGUID(row.bossGUID);
			if (npcId) then
				foundNpc = true;
				if (BossCatalogByNpcId[npcId]) then
					return false;
				end
			end
		end
	end
	return foundNpc;
end

local function RemoveSavedTrashBuckets()
	local targets = {};
	for instanceKey, bosses in pairs(BossMemoryDB.bosses or {}) do
		for bossName, bucket in pairs(bosses or {}) do
			if (TrashBossNames[bossName] or BucketContainsOnlyNonCatalogNpcs(bucket)) then
				table.insert(targets, { instanceKey = instanceKey, bossName = bossName });
			end
		end
	end

	for _, target in ipairs(targets) do
		local bosses = BossMemoryDB.bosses[target.instanceKey];
		if (bosses) then
			bosses[target.bossName] = nil;
			if (not next(bosses)) then
				BossMemoryDB.bosses[target.instanceKey] = nil;
			end
		end
	end

	if (BossMemoryDB.last) then
		local last = BossMemoryDB.last;
		if (not BossMemoryDB.bosses[last.instanceKey] or not BossMemoryDB.bosses[last.instanceKey][last.bossName]) then
			BossMemoryDB.last = nil;
		end
	end
	return #targets;
end

local function NewBossBucket()
	return {
		kills = 0,
		wipes = 0,
		bestPercent = 100,
		attempts = {},
		killsLog = {},
	};
end

local function RecomputeBossBucket(bucket)
	local wipes = 0;
	local bestPercent = 100;
	for _, attempt in ipairs(bucket.attempts or {}) do
		if (attempt.result ~= "kill") then
			wipes = wipes + 1;
		end
		bestPercent = math.min(bestPercent, tonumber(attempt.minPercent) or 100);
	end
	EnsureKillLog(bucket);
	bucket.kills = #(bucket.killsLog or {});
	bucket.wipes = wipes;
	bucket.bestPercent = bucket.kills > 0 and 0 or bestPercent;
	PruneRecentWipes(bucket);
end

local function IsNearZeroBossCompletion(attempt)
	if (not attempt or attempt.friendlyVictory) then
		return false;
	end
	local minPercent = math.min(
		tonumber(attempt.minPercent) or 100,
		tonumber(attempt.lastPercent) or 100
	);
	local minHealth = tonumber(attempt.bossMinHealth);
	local maxHealth = tonumber(attempt.bossMaxHealth);
	if (minPercent > 0.1) then
		return false;
	end
	if (minHealth and maxHealth and maxHealth > 0) then
		return (minHealth / maxHealth) <= 0.001;
	end
	return minPercent <= 0;
end

local function IsReliableVanishedKill(attempt)
	if (IsNearZeroBossCompletion(attempt)) then
		return true;
	end
	if (
		attempt
		and attempt.catalogBoss == "Lady Deathwhisper"
		and not attempt.friendlyVictory
	) then
		local minPercent = math.min(
			tonumber(attempt.minPercent) or 100,
			tonumber(attempt.lastPercent) or 100
		);
		local minHealth = tonumber(attempt.bossMinHealth);
		local maxHealth = tonumber(attempt.bossMaxHealth);
		if (minPercent <= 5) then
			return true;
		end
		if (
			minHealth
			and maxHealth
			and maxHealth > 0
			and (minHealth / maxHealth) <= 0.05
		) then
			return true;
		end
	end
	return false;
end

local function RecoverNearZeroKills()
	local recovered = 0;
	for _, bosses in pairs(BossMemoryDB.bosses or {}) do
		for _, bucket in pairs(bosses or {}) do
			for _, attempt in ipairs(bucket.attempts or {}) do
				local confirmation = tostring(attempt.confirmation or "");
				if (
					attempt.result ~= "kill"
					and string.find(
						confirmation,
						"no death or boss reward",
						1,
						true
					)
					and IsReliableVanishedKill(attempt)
				) then
					attempt.result = "kill";
					attempt.confirmation =
						"recovered: reliable boss disappearance after combat";
					attempt.minPercent = 0;
					attempt.bossMinHealth = 0;
					recovered = recovered + 1;
				end
			end
			RecomputeBossBucket(bucket);
		end
	end
	return recovered;
end

local function NormalizeStoredDifficultyBuckets()
	local oldBosses = BossMemoryDB.bosses or {};
	local oldLast = BossMemoryDB.last;
	local oldLastAttempt;
	if (
		oldLast
		and oldBosses[oldLast.instanceKey]
		and oldBosses[oldLast.instanceKey][oldLast.bossName]
	) then
		oldLastAttempt =
			(oldBosses[oldLast.instanceKey][oldLast.bossName].attempts or {})[oldLast.index];
	end

	local rebuilt = {};
	local killKeys = {};
	for oldInstanceKey, bosses in pairs(oldBosses) do
		local keyName, keyType, keyMaxPlayers, keyDifficultyIndex, keyMode,
			keyDifficultyName = ParseInstanceStorageKey(oldInstanceKey);
		for bossName, bucket in pairs(bosses or {}) do
			EnsureKillLog(bucket);
			for _, source in ipairs({
				{ rows = bucket.attempts or {}, isKillLog = false },
				{ rows = bucket.killsLog or {}, isKillLog = true },
			}) do
				for _, row in ipairs(source.rows) do
					local instanceName = row.instanceName or keyName;
					local instanceType = row.instanceType or keyType;
					local maxPlayers = tonumber(row.maxPlayers) or keyMaxPlayers or 0;
					local difficultyName = row.difficultyName or keyDifficultyName or "";
					local mode = row.difficultyMode or DifficultyMode(
						instanceType,
						row.difficultyIndex or keyDifficultyIndex,
						difficultyName
					);
					local storedDifficultyIndex = row.difficultyIndex;
					if (not storedDifficultyIndex and mode == keyMode) then
						storedDifficultyIndex = keyDifficultyIndex;
					end
					local newKey, difficultyIndex = BuildInstanceKey(
						instanceName,
						instanceType,
						maxPlayers,
						storedDifficultyIndex,
						difficultyName,
						mode
					);
					row.instanceKey = newKey;
					row.instanceName = instanceName;
					row.instanceType = instanceType;
					row.maxPlayers = maxPlayers;
					row.difficultyIndex = difficultyIndex;
					row.difficultyMode = mode;

					rebuilt[newKey] = rebuilt[newKey] or {};
					rebuilt[newKey][bossName] =
						rebuilt[newKey][bossName] or NewBossBucket();
					local target = rebuilt[newKey][bossName];
					if (source.isKillLog) then
						killKeys[newKey] = killKeys[newKey] or {};
						killKeys[newKey][bossName] = killKeys[newKey][bossName] or {};
						local rowKey = KillLogKey(row);
						if (not killKeys[newKey][bossName][rowKey]) then
							killKeys[newKey][bossName][rowKey] = true;
							table.insert(target.killsLog, row);
						end
					else
						table.insert(target.attempts, row);
					end
				end
			end
		end
	end

	BossMemoryDB.bosses = rebuilt;
	BossMemoryDB.last = nil;
	for instanceKey, bosses in pairs(rebuilt) do
		for bossName, bucket in pairs(bosses or {}) do
			table.sort(bucket.attempts, function(a, b)
				return tostring(a.startDate or "") < tostring(b.startDate or "");
			end);
			RecomputeBossBucket(bucket);
			if (oldLastAttempt) then
				for index, attempt in ipairs(bucket.attempts) do
					if (attempt == oldLastAttempt) then
						BossMemoryDB.last = {
							instanceKey = instanceKey,
							bossName = bossName,
							index = index,
						};
					end
				end
			end
		end
	end
end

function MigrateBossMemoryDB()
	if ((tonumber(BossMemoryDB.version) or 0) < 7) then
		NormalizeStoredDifficultyBuckets();
		BossMemoryDB.version = 7;
		Print("normal and heroic boss histories were separated");
	end
	if ((tonumber(BossMemoryDB.version) or 0) < 8) then
		local recovered = RecoverNearZeroKills();
		BossMemoryDB.version = 8;
		if (recovered > 0) then
			Print(
				"recovered "..tostring(recovered)
				.." near-zero boss kill(s) that lacked a combat-log death"
			);
			ScheduleKillSaveReload("recovered near-zero boss kill");
		end
	end
	if ((tonumber(BossMemoryDB.version) or 0) < 9) then
		local recovered = RecoverNearZeroKills();
		BossMemoryDB.version = 9;
		if (recovered > 0) then
			Print(
				"recovered "..tostring(recovered)
				.." reliable vanished-boss kill(s)"
			);
			ScheduleKillSaveReload("recovered vanished-boss kill");
		end
	end
	local removed = RemoveSavedTrashBuckets();
	for _, bosses in pairs(BossMemoryDB.bosses or {}) do
		for _, bucket in pairs(bosses or {}) do
			bucket.attempts = bucket.attempts or {};
			EnsureKillLog(bucket);
			PruneRecentWipes(bucket);
		end
	end
	if (removed > 0) then
		BossMemoryDB.removedTrashRecords = (tonumber(BossMemoryDB.removedTrashRecords) or 0) + removed;
		Print("removed "..tostring(removed).." saved trash-mob records");
	end
end

local function BuildGroupNames(roster)
	local names = {};
	for _, member in ipairs(roster or {}) do
		if (member.name) then
			names[member.name] = true;
		end
	end
	return names;
end

local function IsBossUnit(unit)
	if (not UnitExists(unit) or UnitIsDead(unit)) then
		return false;
	end

	local name = SafeName(UnitName(unit));
	local guid = UnitGUID(unit);
	if (not name or not guid) then
		return false;
	end

	local npcId = NpcIdFromGUID(guid);
	local catalogBoss = npcId and BossCatalogByNpcId[npcId];
	if (not catalogBoss) then
		return false;
	end
	if (UnitIsFriend("player", unit) and not catalogBoss.friendlyVictory) then
		return false;
	end
	return true;
end

local function NotifyUnBotBossTarget(unit)
	if (
		type(UnBotBossPresetTargetBoss) ~= "function"
		or not IsBossUnit(unit)
	) then
		return;
	end
	local guid = UnitGUID(unit);
	local npcId = NpcIdFromGUID(guid);
	local catalogBoss = npcId and BossCatalogByNpcId[npcId];
	if (not catalogBoss) then
		return;
	end
	local _, _, instanceType, _, maxPlayers, difficultyIndex, difficultyMode =
		GetInstanceKey();
	local ok, err = pcall(
		UnBotBossPresetTargetBoss,
		catalogBoss.instance,
		catalogBoss.encounter,
		guid,
		instanceType,
		difficultyIndex,
		maxPlayers,
		difficultyMode
	);
	if (not ok) then
		Print("UnBot target-guide integration failed: "..tostring(err));
	end
end

local function NotifyUnBotAttemptFinished(attempt, result)
	if (
		type(UnBotBossPresetAttemptFinished) ~= "function"
		or (result ~= "kill" and result ~= "wipe")
	) then
		return;
	end
	local ok, err = pcall(
		UnBotBossPresetAttemptFinished,
		attempt.catalogInstance or attempt.instanceName,
		attempt.catalogBoss or attempt.bossName,
		result
	);
	if (not ok) then
		Print("UnBot attempt-finish integration failed: "..tostring(err));
	end
end

local function EnsureMasterLootForBoss(unit)
	if (UnBotLootSettings) then UnBotLootSettings.TargetSelected(unit); return; end
	if (not IsBossUnit(unit)) then
		return;
	end
	if (type(UnBotBossPresetMasterLootEnabled) == "function") then
		local guid = UnitGUID(unit);
		local npcId = NpcIdFromGUID(guid);
		local catalogBoss = npcId and BossCatalogByNpcId[npcId];
		if (catalogBoss) then
			local _, _, instanceType, _, maxPlayers, difficultyIndex, difficultyMode =
				GetInstanceKey();
			local ok, enabled = pcall(
				UnBotBossPresetMasterLootEnabled,
				catalogBoss.instance,
				catalogBoss.encounter,
				instanceType,
				difficultyIndex,
				maxPlayers,
				difficultyMode
			);
			if (not ok) then
				Print("UnBot Master Looter integration failed: "..tostring(enabled));
			elseif (enabled == false) then
				BM.lootCheckPending = nil;
				return;
			end
		end
	end

	-- Loot methods only matter while grouped. Solo kills need no master looter.
	local raidSize = GetNumRaidMembers and GetNumRaidMembers() or 0;
	local partySize = GetNumPartyMembers and GetNumPartyMembers() or 0;
	if (raidSize <= 0 and partySize <= 0) then
		BM.lootCheckPending = nil;
		return;
	end

	local lootMethod = GetLootMethod and GetLootMethod();
	if (lootMethod == "master") then
		BM.lootCheckPending = nil;
		return;
	end

	local bossGUID = UnitGUID(unit);
	if (BM.lootCheckPending and BM.lootCheckPending.bossGUID == bossGUID) then
		return;
	end

	local bossName = SafeName(UnitName(unit)) or "boss";
	local playerName = SafeName(UnitName("player"));
	if (not playerName or not SetLootMethod) then
		Print("boss selected, but Master Looter could not be enabled");
		return;
	end

	local ok, err = pcall(SetLootMethod, "master", playerName);
	if (not ok) then
		Print("boss selected, but Master Looter could not be enabled: "..tostring(err));
		return;
	end

	BM.lootCheckPending = {
		at = GetTime() + LOOT_METHOD_VERIFY_DELAY,
		bossGUID = bossGUID,
		bossName = bossName,
	};
	Print("boss selected: enabling Master Looter ("..playerName..")");
end

local function CurrentBossPercent(unit)
	local maxHealth = UnitHealthMax(unit) or 0;
	if (maxHealth <= 0) then
		return nil;
	end
	local hp = UnitHealth(unit) or 0;
	return (hp / maxHealth) * 100;
end

local function CurrentBossHealth(unit)
	local maxHealth = UnitHealthMax(unit) or 0;
	local health = UnitHealth(unit) or 0;
	return health, maxHealth;
end

local function ScanBossUnit()
	local units = {"target", "focus", "mouseover"};

	for i = 1, GetNumPartyMembers(), 1 do
		table.insert(units, "party"..i.."target");
	end

	if (GetNumRaidMembers() and GetNumRaidMembers() > 0) then
		for i = 1, GetNumRaidMembers(), 1 do
			table.insert(units, "raid"..i.."target");
		end
	end

	for _, unit in ipairs(units) do
		if (IsBossUnit(unit)) then
			return unit;
		end
	end

	return nil;
end

local function UnitTokenByName(name)
	if (not name) then
		return nil;
	end
	if (UnitName("player") == name) then
		return "player";
	end
	if (GetNumRaidMembers() and GetNumRaidMembers() > 0) then
		for i = 1, GetNumRaidMembers(), 1 do
			local unit = "raid"..i;
			if (UnitName(unit) == name) then
				return unit;
			end
		end
	else
		for i = 1, GetNumPartyMembers(), 1 do
			local unit = "party"..i;
			if (UnitName(unit) == name) then
				return unit;
			end
		end
	end
	return nil;
end

local function IsActiveRosterAllDead()
	if (not BM.active) then
		return false;
	end

	local checked = 0;
	for _, member in ipairs(BM.active.roster or {}) do
		local unit = UnitTokenByName(member.name);
		if (unit and UnitExists(unit)) then
			checked = checked + 1;
			if (UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit)) then
				return false;
			end
		end
	end

	return checked > 0;
end

local function IsAnyActiveRosterInCombat()
	if (not BM.active) then
		return false;
	end

	for _, member in ipairs(BM.active.roster or {}) do
		local unit = UnitTokenByName(member.name);
		if (unit and UnitExists(unit) and UnitAffectingCombat(unit)) then
			return true;
		end
	end
	return false;
end

local function IsActiveBossReappeared(unit)
	if (not BM.active or not unit or not UnitExists(unit)) then
		return false;
	end

	local name = SafeName(UnitName(unit));
	local guid = UnitGUID(unit);
	local npcId = NpcIdFromGUID(guid);
	local catalogBoss = npcId and BossCatalogByNpcId[npcId];
	if (guid and BM.active.bossGUID and BM.active.bossGUID ~= guid and catalogBoss and BM.active.catalogBoss == catalogBoss.encounter and BM.active.catalogInstance == catalogBoss.instance) then
		return false;
	end
	return name and guid and BM.active.bossName == name and BM.active.bossGUID and BM.active.bossGUID ~= guid;
end

local function EnsureBossBucket(attempt)
	if (BossMemoryDB.recordHistory == false) then return nil; end
	local instanceKey = attempt.instanceKey;
	local bossName = attempt.bossName;
	BossMemoryDB.bosses[instanceKey] = BossMemoryDB.bosses[instanceKey] or {};
	BossMemoryDB.bosses[instanceKey][bossName] = BossMemoryDB.bosses[instanceKey][bossName] or {
		kills = 0,
		wipes = 0,
		bestPercent = 100,
		attempts = {},
		killsLog = {},
	};
	EnsureKillLog(BossMemoryDB.bosses[instanceKey][bossName]);
	return BossMemoryDB.bosses[instanceKey][bossName];
end

local function StartAttempt(unit)
	if (BM.active) then
		return;
	end

	local name = SafeName(UnitName(unit));
	local guid = UnitGUID(unit);
	if (not name or not guid) then
		return;
	end

	local instanceKey, instanceName, instanceType, difficultyName, maxPlayers,
		difficultyIndex, difficultyMode = GetInstanceKey();
	local roster, groupSize = GetRoster();
	local percent = CurrentBossPercent(unit) or 100;
	local health, maxHealth = CurrentBossHealth(unit);
	local bossNpcId = NpcIdFromGUID(guid);
	local catalogBoss = bossNpcId and BossCatalogByNpcId[bossNpcId];
	if (catalogBoss and catalogBoss.friendlyVictory and percent >= 95) then
		return;
	end

	BM.active = {
		recordId = tostring(time())..":"..tostring(math.floor(GetTime() * 1000))..":"..tostring(guid),
		bossName = name,
		bossGUID = guid,
		bossNpcId = bossNpcId,
		catalogBoss = catalogBoss and catalogBoss.encounter,
		catalogInstance = catalogBoss and catalogBoss.instance,
		friendlyVictory = catalogBoss and catalogBoss.friendlyVictory or false,
		instanceKey = instanceKey,
		instanceName = instanceName,
		instanceType = instanceType,
		difficultyName = difficultyName,
		difficultyIndex = difficultyIndex,
		difficultyMode = difficultyMode,
		maxPlayers = maxPlayers,
		startTime = GetTime(),
		startDate = date("%Y-%m-%d %H:%M:%S"),
		lastBossSeen = GetTime(),
		bossMissingSince = nil,
		missingNoticeShown = false,
		rewardCounts = SnapshotBossRewardCounts(),
		minPercent = percent,
		lastPercent = percent,
		bossStartPercent = percent,
		bossStartHealth = health,
		bossMaxHealth = maxHealth,
		bossMinHealth = health,
		roster = roster,
		groupSize = groupSize,
		rosterSummary = RosterSummary(roster),
		damageTakenBySpell = {},
		damageDoneByGroup = {},
		mechanics = {},
		mechanicSeen = {},
	};
	BM.groupNames = BuildGroupNames(roster);
	BM.rosterByName = BuildRosterLookup(roster);
	RequestRosterSpecs(roster);

	Print("started: "..name.." ("..tostring(groupSize).." players, HP "..tostring(maxHealth)..")");
end

local function UpdateActiveFromUnit(unit)
	if (not BM.active or not UnitExists(unit)) then
		return;
	end

	local guid = UnitGUID(unit);
	local name = SafeName(UnitName(unit));
	if (BM.active.bossGUID and guid and guid ~= BM.active.bossGUID) then
		local npcId = NpcIdFromGUID(guid);
		local catalogBoss = npcId and BossCatalogByNpcId[npcId];
		if (not catalogBoss or BM.active.catalogBoss ~= catalogBoss.encounter or BM.active.catalogInstance ~= catalogBoss.instance) then
			return;
		end
		BM.active.bossGUID = guid;
		BM.active.bossNpcId = npcId;
		BM.active.bossName = name or BM.active.bossName;
	end
	if ((not guid or not BM.active.bossGUID) and name ~= BM.active.bossName) then
		return;
	end

	BM.active.lastBossSeen = GetTime();
	BM.active.bossMissingSince = nil;
	BM.active.missingNoticeShown = false;

	local percent = CurrentBossPercent(unit);
	if (percent) then
		BM.active.lastPercent = percent;
		if (percent < BM.active.minPercent) then
			BM.active.minPercent = percent;
		end
	end
	local health, maxHealth = CurrentBossHealth(unit);
	if (maxHealth and maxHealth > 0) then
		BM.active.bossMaxHealth = math.max(BM.active.bossMaxHealth or 0, maxHealth);
	end
	if (health and health > 0 and (not BM.active.bossMinHealth or health < BM.active.bossMinHealth)) then
		BM.active.bossMinHealth = health;
	end
end

local function AddDamageStat(target, key, amount)
	if (not target or not key or not amount or amount <= 0) then
		return;
	end
	local stat = target[key];
	if (not stat) then
		stat = { count = 0, total = 0, max = 0 };
		target[key] = stat;
	end
	stat.count = stat.count + 1;
	stat.total = stat.total + amount;
	if (amount > stat.max) then
		stat.max = amount;
	end
end

local function SpellKey(spellId, spellName, eventType)
	spellName = spellName or eventType or "unknown";
	spellId = spellId or 0;
	return tostring(spellId)..":"..spellName;
end

local function IsActiveBossSource(guid, name)
	if (not BM.active) then
		return false;
	end
	if (guid and guid == BM.active.bossGUID) then
		return true;
	end
	if (name and BM.active.bossName and name == BM.active.bossName) then
		return true;
	end
	return false;
end

local function IsGroupMemberName(name)
	return name and BM.groupNames and BM.groupNames[name] == true;
end

local function IsActiveBossNameOrGuid(guid, name)
	if (not BM.active) then
		return false;
	end
	return (guid and BM.active.bossGUID and guid == BM.active.bossGUID) or (name and BM.active.bossName and name == BM.active.bossName);
end

local function IsMechanicActor(guid, name)
	name = SafeName(name);
	if (not BM.active or not name) then
		return false;
	end
	if (IsActiveBossNameOrGuid(guid, name) or IsGroupMemberName(name)) then
		return false;
	end
	return true;
end

local function EnsureMechanic(name, guid)
	if (not BM.active) then
		return nil;
	end
	name = SafeName(name);
	if (not name) then
		return nil;
	end

	local row = BM.active.mechanics[name];
	if (not row) then
		row = {
			seen = 0,
			summons = 0,
			deaths = 0,
			events = {},
			damageToGroup = {},
			damageTaken = {},
		};
		BM.active.mechanics[name] = row;
	end

	local seenKey = guid or name;
	if (not BM.active.mechanicSeen[seenKey]) then
		BM.active.mechanicSeen[seenKey] = true;
		row.seen = (row.seen or 0) + 1;
	end

	return row;
end

local function AddMechanicEvent(row, eventType, spellName)
	if (not row or not eventType) then
		return;
	end
	local key = eventType;
	if (spellName and spellName ~= "") then
		key = eventType..":"..spellName;
	end
	row.events[key] = (row.events[key] or 0) + 1;
end

local function TrackMechanicSeen(eventType, guid, name)
	if (not IsMechanicActor(guid, name)) then
		return;
	end
	local row = EnsureMechanic(name, guid);
	if (not row) then
		return;
	end
	if (eventType == "SPELL_SUMMON") then
		row.summons = (row.summons or 0) + 1;
	elseif (eventType == "UNIT_DIED") then
		row.deaths = (row.deaths or 0) + 1;
	end
	AddMechanicEvent(row, eventType, nil);
end

local function AddMechanicDamage(name, guid, target, spellKey, amount)
	local row = EnsureMechanic(name, guid);
	if (row) then
		AddDamageStat(row[target], spellKey, amount);
	end
end

local function TrackMechanicCombatEvent(eventType, srcGUID, srcName, dstGUID, dstName, ...)
	if (not BM.active) then
		return;
	end

	local spellName = nil;
	if (string.find(eventType or "", "^SPELL_") or eventType == "RANGE_DAMAGE" or eventType == "SPELL_PERIODIC_DAMAGE" or eventType == "DAMAGE_SHIELD") then
		local spellId;
		spellId, spellName = select(1, ...);
	end

	if (IsMechanicActor(srcGUID, srcName)) then
		local row = EnsureMechanic(srcName, srcGUID);
		AddMechanicEvent(row, eventType, spellName);
	end
	if (IsMechanicActor(dstGUID, dstName)) then
		local row = EnsureMechanic(dstName, dstGUID);
		AddMechanicEvent(row, eventType, spellName);
	end
end

local function TrackDamageEvent(eventType, srcGUID, srcName, dstGUID, dstName, ...)
	if (not BM.active) then
		return;
	end

	local spellId, spellName, amount;
	if (eventType == "SWING_DAMAGE") then
		amount = select(1, ...);
		spellId = 0;
		spellName = "Melee";
	elseif (eventType == "RANGE_DAMAGE" or eventType == "SPELL_DAMAGE" or eventType == "SPELL_PERIODIC_DAMAGE" or eventType == "DAMAGE_SHIELD") then
		spellId, spellName = select(1, ...);
		amount = select(4, ...);
	else
		return;
	end

	if (IsActiveBossSource(srcGUID, srcName) and IsGroupMemberName(dstName)) then
		AddDamageStat(BM.active.damageTakenBySpell, SpellKey(spellId, spellName, eventType), amount);
	elseif (IsGroupMemberName(srcName) and (dstGUID == BM.active.bossGUID or dstName == BM.active.bossName)) then
		AddDamageStat(BM.active.damageDoneByGroup, SpellKey(spellId, spellName, eventType), amount);
	end
	if (IsMechanicActor(srcGUID, srcName) and IsGroupMemberName(dstName)) then
		AddMechanicDamage(srcName, srcGUID, "damageToGroup", SpellKey(spellId, spellName, eventType), amount);
	elseif (IsGroupMemberName(srcName) and IsMechanicActor(dstGUID, dstName)) then
		AddMechanicDamage(dstName, dstGUID, "damageTaken", SpellKey(spellId, spellName, eventType), amount);
	end
end

local function SortedStats(stats)
	local rows = {};
	for key, stat in pairs(stats or {}) do
		table.insert(rows, {
			key = key,
			count = stat.count or 0,
			total = stat.total or 0,
			max = stat.max or 0,
			avg = stat.count and stat.count > 0 and Round(stat.total / stat.count, 1) or 0,
		});
	end
	table.sort(rows, function(a, b)
		if (a.total == b.total) then
			return a.max > b.max;
		end
		return a.total > b.total;
	end);
	return rows;
end

local function AddCombinedStats(target, source)
	for key, stat in pairs(source or {}) do
		local row = target[key];
		if (not row) then
			row = { count = 0, total = 0, max = 0 };
			target[key] = row;
		end
		row.count = row.count + (stat.count or 0);
		row.total = row.total + (stat.total or 0);
		if ((stat.max or 0) > row.max) then
			row.max = stat.max or 0;
		end
	end
end

local function AddCombinedMechanics(target, source)
	for name, mechanic in pairs(source or {}) do
		local row = target[name];
		if (not row) then
			row = {
				seen = 0,
				summons = 0,
				deaths = 0,
				events = {},
				damageToGroup = {},
				damageTaken = {},
			};
			target[name] = row;
		end
		row.seen = row.seen + (mechanic.seen or 0);
		row.summons = row.summons + (mechanic.summons or 0);
		row.deaths = row.deaths + (mechanic.deaths or 0);
		for eventName, count in pairs(mechanic.events or {}) do
			row.events[eventName] = (row.events[eventName] or 0) + (count or 0);
		end
		AddCombinedStats(row.damageToGroup, mechanic.damageToGroup);
		AddCombinedStats(row.damageTaken, mechanic.damageTaken);
	end
end

local function PrintTopStats(label, stats, limit)
	local rows = SortedStats(stats);
	if (#rows == 0) then
		Print("  "..label..": none");
		return;
	end
	Print("  "..label..":");
	for i = 1, math.min(limit or 5, #rows) do
		local r = rows[i];
		local name = string.match(r.key, "^%d+:(.+)$") or r.key;
		Print("    "..name.." x"..r.count.." total "..r.total.." max "..r.max.." avg "..r.avg);
	end
end

local function FinishAttempt(result, confirmation)
	if (not BM.active) then
		return;
	end

	local attempt = BM.active;
	BM.active = nil;
	BM.lastRosterByName = BuildRosterLookup(attempt.roster);
	BM.rosterByName = {};

	attempt.result = result;
	attempt.duration = Round(GetTime() - attempt.startTime, 1);
	attempt.minPercent = result == "kill" and 0 or Round(attempt.minPercent or 100, 1);
	attempt.bossMinHealth = result == "kill" and 0 or attempt.bossMinHealth;
	attempt.endDate = date("%Y-%m-%d %H:%M:%S");
	attempt.confirmation = confirmation;
	attempt.rewardCounts = nil;
	attempt.mechanicSeen = nil;

	if (BossMemoryDB.recordHistory ~= false) then
		local bucket = EnsureBossBucket(attempt);
		if (result == "kill") then
			bucket.kills = (bucket.kills or 0) + 1;
			table.insert(bucket.killsLog, KillSnapshot(attempt));
		else
			bucket.wipes = (bucket.wipes or 0) + 1;
		end
		if (not bucket.bestPercent or attempt.minPercent < bucket.bestPercent) then
			bucket.bestPercent = attempt.minPercent;
		end

		table.insert(bucket.attempts, attempt);
		PruneRecentWipes(bucket);
		BossMemoryDB.last = {
			instanceKey = attempt.instanceKey,
			bossName = attempt.bossName,
			index = #bucket.attempts,
		};
	end
	BM.lastAttempt = attempt;
	BM.lastAttemptFinishedAt = GetTime();
	if (result == "kill") then
		ScheduleKillSaveReload(attempt.confirmation);
	end

	Print(result..": "..attempt.bossName.." | min HP "..tostring(attempt.minPercent).."% | "..tostring(attempt.groupSize).." players | "..tostring(attempt.duration).."s");
	NotifyUnBotAttemptFinished(attempt, result);
end

local function IsActiveBossCorpse(unit)
	if (
		not BM.active
		or not unit
		or not UnitExists(unit)
		or not UnitIsDead(unit)
	) then
		return false;
	end
	local guid = UnitGUID(unit);
	local name = SafeName(UnitName(unit));
	return (
		(guid and BM.active.bossGUID and guid == BM.active.bossGUID)
		or (name and BM.active.bossName and name == BM.active.bossName)
	) and true or false;
end

local function PromoteLastAttemptToKill(guid, name)
	local attempt = BM.lastAttempt;
	if (not attempt or attempt.result == "kill" or not BM.lastAttemptFinishedAt) then
		return false;
	end
	if ((GetTime() - BM.lastAttemptFinishedAt) > LATE_KILL_WINDOW) then
		return false;
	end
	if (attempt.bossGUID and guid) then
		if (attempt.bossGUID ~= guid) then
			return false;
		end
	elseif (not name or name ~= attempt.bossName) then
		return false;
	end

	local bucket = EnsureBossBucket(attempt);
	attempt.result = "kill";
	attempt.confirmation = "late combat-log death";
	attempt.minPercent = 0;
	attempt.bossMinHealth = 0;
	if (bucket) then
		bucket.wipes = math.max(0, (bucket.wipes or 0) - 1);
		bucket.kills = (bucket.kills or 0) + 1;
		bucket.bestPercent = 0;
		table.insert(bucket.killsLog, KillSnapshot(attempt));
	end
	ScheduleKillSaveReload(attempt.confirmation);
	Print("kill confirmed: "..attempt.bossName.." (late combat-log event)");
	return true;
end

local function PromoteLastAttemptToKillFromReward(itemId, source)
	local attempt = BM.lastAttempt;
	if (not attempt or attempt.result == "kill" or not BM.lastAttemptFinishedAt) then
		return false;
	end
	if ((GetTime() - BM.lastAttemptFinishedAt) > BOSS_COMPLETION_TIMEOUT) then
		return false;
	end
	local oldConfirmation = tostring(attempt.confirmation or "");
	if (oldConfirmation ~= "entire roster dead" and not string.find(oldConfirmation, "no death or boss reward", 1, true)) then
		return false;
	end

	local label = BossRewardItemIDs[itemId];
	local bucket = EnsureBossBucket(attempt);
	attempt.result = "kill";
	attempt.confirmation = "reward: "..label.." via "..tostring(source or "unknown");
	attempt.minPercent = 0;
	attempt.bossMinHealth = 0;
	if (bucket) then
		bucket.wipes = math.max(0, (bucket.wipes or 0) - 1);
		bucket.kills = (bucket.kills or 0) + 1;
		bucket.bestPercent = 0;
		table.insert(bucket.killsLog, KillSnapshot(attempt));
	end
	ScheduleKillSaveReload(attempt.confirmation);
	Print("kill confirmed by reward: "..label);
	return true;
end

local function ConfirmKillFromReward(itemId, source)
	if (not BossRewardItemIDs[itemId]) then
		return false;
	end
	if (not BM.active) then
		if (BM.saveReloadPending and BM.lastAttempt and BM.lastAttempt.result == "kill" and BM.lastAttemptFinishedAt and (GetTime() - BM.lastAttemptFinishedAt) <= (AUTO_SAVE_RELOAD_DELAY + BOSS_COMPLETION_TIMEOUT)) then
			BM.saveReloadRewardSeen = true;
			BM.saveReloadAt = GetTime();
			Print("boss reward received; disk save will start after loot and rolls close");
			return true;
		end
		return PromoteLastAttemptToKillFromReward(itemId, source);
	end
	if (ScanBossUnit()) then
		return false;
	end
	local label = BossRewardItemIDs[itemId];
	FinishAttempt("kill", "reward: "..label.." via "..tostring(source or "unknown"));
	Print("kill confirmed by reward: "..label);
	return true;
end

local function CheckBossRewardBags()
	if (not BM.active or not BM.active.rewardCounts or not GetItemCount) then
		return;
	end
	for itemId in pairs(BossRewardItemIDs) do
		local oldCount = BM.active.rewardCounts[itemId] or 0;
		local newCount = GetItemCount(itemId) or 0;
		BM.active.rewardCounts[itemId] = newCount;
		if (newCount > oldCount and ConfirmKillFromReward(itemId, "bag increase")) then
			return;
		end
	end
end

local function CheckBossRewardMessage(message)
	if (not message) then
		return;
	end
	for itemIdText in string.gmatch(message, "|Hitem:(%d+)") do
		local itemId = tonumber(itemIdText);
		if (itemId and BossRewardItemIDs[itemId] and ConfirmKillFromReward(itemId, "loot message")) then
			return;
		end
	end
	local normalized = NormalizeText(message);
	for alias, itemId in pairs(BossRewardTextAliases) do
		if ((string.find(normalized, alias, 1, true) or string.find(tostring(message), alias, 1, true)) and ConfirmKillFromReward(itemId, "reward text")) then
			return;
		end
	end
end

local function PrintAttempt(attempt, index)
	if (not attempt) then
		Print("no attempt data");
		return;
	end

	local prefix = index and ("#"..tostring(index).." ") or "";
	Print(prefix..attempt.result.." "..attempt.bossName.." - "..attempt.instanceName.." "..(attempt.difficultyName or ""));
	Print("  date: "..tostring(attempt.startDate)..", duration: "..tostring(attempt.duration).."s, min HP: "..tostring(attempt.minPercent).."%");
	Print("  confirmation: "..tostring(attempt.confirmation or "legacy record"));
	Print("  boss HP: max "..tostring(attempt.bossMaxHealth or "?")..", start "..tostring(attempt.bossStartHealth or "?")..", min "..tostring(attempt.bossMinHealth or "?"));
	Print("  group: "..tostring(attempt.groupSize).." ("..tostring(attempt.rosterSummary)..")");

	local names = {};
	for _, member in ipairs(attempt.roster or {}) do
		local specText = member.spec and (":"..member.spec) or "";
		table.insert(names, member.name.."["..tostring(member.classFile or member.class or "?")..specText.."]");
	end
	Print("  members: "..table.concat(names, ", "));
	if (attempt.note and attempt.note ~= "") then
		Print("  note: "..attempt.note);
	end
	PrintTopStats("boss damage to group", attempt.damageTakenBySpell, 5);
	PrintTopStats("group damage to boss", attempt.damageDoneByGroup, 5);
	local mechanics = SortedMechanics(attempt.mechanics);
	if (#mechanics > 0) then
		Print("  mechanics:");
		for i = 1, math.min(5, #mechanics) do
			local mechanic = mechanics[i];
			Print("    "..mechanic.name.." seen "..mechanic.seen.." dmgToGroup "..FormatNumber(mechanic.damageToGroup).." dmgTaken "..FormatNumber(mechanic.damageTaken));
		end
	end
end

local function GetLastAttempt()
	local last = BossMemoryDB.last;
	if (not last) then
		return nil;
	end
	local bucket = BossMemoryDB.bosses[last.instanceKey] and BossMemoryDB.bosses[last.instanceKey][last.bossName];
	if (not bucket) then
		return nil;
	end
	return bucket.attempts[last.index], last.index;
end

local function PrintBoss(name)
	name = string.lower(name or "");
	local found = false;
	for _, bosses in pairs(BossMemoryDB.bosses or {}) do
		for bossName, bucket in pairs(bosses) do
			if (name == "" or string.find(string.lower(bossName), name, 1, true)) then
				found = true;
				Print(bossName..": kills "..tostring(bucket.kills or 0)..", wipes "..tostring(bucket.wipes or 0)..", best "..tostring(bucket.bestPercent or "?").."%");
				local attempts = bucket.attempts or {};
				for i = math.max(1, #attempts - 4), #attempts do
					local a = attempts[i];
					Print("  #"..i.." "..a.result.." "..a.startDate.." | "..a.groupSize.." players | bossHP "..tostring(a.bossMaxHealth or "?").." | min "..a.minPercent.."% | "..a.duration.."s");
				end
			end
		end
	end
	if (not found) then
		Print("no boss data for: "..name);
	end
end

local function SplitInstanceKey(key)
	local name, instanceType, maxPlayers, difficultyIndex, mode =
		ParseInstanceStorageKey(key);
	return name or key or "Unknown", instanceType or "",
		tostring(maxPlayers or ""), tostring(difficultyIndex or ""), mode or "";
end

local function InstanceLabel(key)
	local name, instanceType, maxPlayers, difficultyIndex, mode = SplitInstanceKey(key);
	local suffix = {};
	if (maxPlayers and maxPlayers ~= "" and maxPlayers ~= "0") then
		table.insert(suffix, maxPlayers.." игроков");
	end
	if (mode == "heroic") then
		table.insert(suffix, "героический");
	elseif (mode == "normal") then
		table.insert(suffix, "обычный");
	elseif (difficultyIndex and difficultyIndex ~= "" and difficultyIndex ~= "0") then
		table.insert(suffix, "сложность "..difficultyIndex);
	end
	if (#suffix > 0) then
		return name.." ("..table.concat(suffix, ", ")..")";
	end
	return name.." ("..instanceType..")";
end

local function SortedInstanceKeys()
	local keys = {};
	for key in pairs(BossMemoryDB.bosses or {}) do
		table.insert(keys, key);
	end
	table.sort(keys, function(a, b)
		return InstanceLabel(a) < InstanceLabel(b);
	end);
	return keys;
end

local function SortedBossNames(instanceKey)
	local names = {};
	local bosses = BossMemoryDB.bosses and BossMemoryDB.bosses[instanceKey];
	for name in pairs(bosses or {}) do
		table.insert(names, name);
	end
	table.sort(names);
	return names;
end

local function RosterNames(attempt)
	local names = {};
	for _, member in ipairs((attempt and attempt.roster) or {}) do
		local specText = member.spec and (":"..member.spec) or "";
		table.insert(names, tostring(member.name or "?").."["..tostring(member.classFile or member.class or "?")..specText.."]");
	end
	return table.concat(names, ", ");
end

local function AppendTopStats(lines, label, stats, limit)
	local rows = SortedStats(stats);
	table.insert(lines, label..":");
	if (#rows == 0) then
		table.insert(lines, "  none");
		return;
	end
	for i = 1, math.min(limit or 5, #rows) do
		local row = rows[i];
		local name = string.match(row.key, "^%d+:(.+)$") or row.key;
		table.insert(lines, "  "..name.." x"..row.count.." total "..FormatNumber(row.total).." max "..FormatNumber(row.max).." avg "..FormatNumber(row.avg));
	end
end

local function TopStatsInline(stats, limit)
	local rows = SortedStats(stats);
	local parts = {};
	for i = 1, math.min(limit or 3, #rows) do
		local row = rows[i];
		local name = string.match(row.key, "^%d+:(.+)$") or row.key;
		table.insert(parts, name.." max "..FormatNumber(row.max).." avg "..FormatNumber(row.avg));
	end
	if (#parts == 0) then
		return "none";
	end
	return table.concat(parts, "; ");
end

local function TopEventsInline(events, limit)
	local rows = {};
	for eventName, count in pairs(events or {}) do
		table.insert(rows, { name = eventName, count = count or 0 });
	end
	table.sort(rows, function(a, b)
		return a.count > b.count;
	end);
	local parts = {};
	for i = 1, math.min(limit or 3, #rows) do
		table.insert(parts, rows[i].name.." x"..tostring(rows[i].count));
	end
	if (#parts == 0) then
		return "none";
	end
	return table.concat(parts, "; ");
end

function SortedMechanics(mechanics)
	local rows = {};
	for name, mechanic in pairs(mechanics or {}) do
		local damageToGroup = 0;
		local damageTaken = 0;
		for _, stat in pairs(mechanic.damageToGroup or {}) do
			damageToGroup = damageToGroup + (stat.total or 0);
		end
		for _, stat in pairs(mechanic.damageTaken or {}) do
			damageTaken = damageTaken + (stat.total or 0);
		end
		table.insert(rows, {
			name = name,
			seen = mechanic.seen or 0,
			summons = mechanic.summons or 0,
			deaths = mechanic.deaths or 0,
			events = mechanic.events or {},
			damageToGroup = damageToGroup,
			damageTaken = damageTaken,
			row = mechanic,
		});
	end
	table.sort(rows, function(a, b)
		if (a.damageToGroup == b.damageToGroup) then
			return a.seen > b.seen;
		end
		return a.damageToGroup > b.damageToGroup;
	end);
	return rows;
end

local function AppendMechanicsBySize(lines, sizes, bySize)
	table.insert(lines, "");
	table.insert(lines, "Mechanics by group size:");
	for _, size in ipairs(sizes) do
		local rows = SortedMechanics(bySize[size].mechanics);
		if (#rows == 0) then
			table.insert(lines, "  "..tostring(size).."p: none");
		else
			table.insert(lines, "  "..tostring(size).."p:");
			for i = 1, math.min(6, #rows) do
				local mechanic = rows[i];
				local suffix = "seen "..tostring(mechanic.seen);
				if (mechanic.summons > 0) then
					suffix = suffix..", summons "..tostring(mechanic.summons);
				end
				if (mechanic.deaths > 0) then
					suffix = suffix..", deaths "..tostring(mechanic.deaths);
				end
				suffix = suffix..", dmg to group "..FormatNumber(mechanic.damageToGroup)..", dmg taken "..FormatNumber(mechanic.damageTaken);
				table.insert(lines, "    "..mechanic.name.." - "..suffix);
				table.insert(lines, "      events: "..TopEventsInline(mechanic.events, 3));
				if (mechanic.damageToGroup > 0) then
					table.insert(lines, "      to group: "..TopStatsInline(mechanic.row.damageToGroup, 3));
				end
				if (mechanic.damageTaken > 0) then
					table.insert(lines, "      taken: "..TopStatsInline(mechanic.row.damageTaken, 3));
				end
			end
		end
	end
end

local function BuildKillRows(bucket, attempts)
	local rows = {};
	local seen = {};

	for _, row in ipairs(bucket.killsLog or {}) do
		local key = KillLogKey(row);
		seen[key] = true;
		table.insert(rows, row);
	end
	for _, attempt in ipairs(attempts or {}) do
		if (attempt.result == "kill") then
			local key = KillLogKey(attempt);
			if (not seen[key]) then
				seen[key] = true;
				table.insert(rows, attempt);
			end
		end
	end

	table.sort(rows, function(a, b)
		return tostring(a.startDate or "") < tostring(b.startDate or "");
	end);
	return rows;
end

local UnBotClassKeys = {
	WARRIOR = "warrior",
	PALADIN = "paladin",
	HUNTER = "hunter",
	ROGUE = "rogue",
	PRIEST = "priest",
	SHAMAN = "shaman",
	MAGE = "mage",
	WARLOCK = "warlock",
	DRUID = "druid",
	DEATHKNIGHT = "dk",
};

local UnBotSpecKeys = {
	WARRIOR = {
		["arms"] = "arms", ["оружие"] = "arms",
		["fury"] = "fury", ["неистовство"] = "fury", ["фури"] = "fury",
		["protection"] = "prot", ["защита"] = "prot", ["прот"] = "prot",
	},
	PALADIN = {
		["holy"] = "holy", ["свет"] = "holy", ["холи"] = "holy",
		["protection"] = "prot", ["защита"] = "prot", ["прот"] = "prot",
		["retribution"] = "ret", ["воздаяние"] = "ret", ["ретри"] = "ret",
	},
	HUNTER = {
		["beast mastery"] = "bm", ["повелитель зверей"] = "bm",
		["marksmanship"] = "mm", ["стрельба"] = "mm",
		["survival"] = "surv", ["выживание"] = "surv",
	},
	ROGUE = {
		["assassination"] = "as", ["assasination"] = "as", ["ликвидация"] = "as",
		["combat"] = "combat", ["бой"] = "combat",
		["subtlety"] = "sub", ["скрытность"] = "sub",
	},
	PRIEST = {
		["discipline"] = "disc", ["послушание"] = "disc",
		["holy"] = "holy", ["свет"] = "holy",
		["shadow"] = "shadow", ["тьма"] = "shadow",
	},
	SHAMAN = {
		["elemental"] = "ele", ["стихии"] = "ele",
		["enhancement"] = "enh", ["совершенствование"] = "enh",
		["restoration"] = "resto", ["исцеление"] = "resto",
	},
	MAGE = {
		["arcane"] = "arcane", ["тайная магия"] = "arcane",
		["fire"] = "fire", ["огонь"] = "fire",
		["frost"] = "frost", ["лед"] = "frost",
	},
	WARLOCK = {
		["affliction"] = "affli", ["колдовство"] = "affli",
		["demonology"] = "demo", ["демонология"] = "demo",
		["destruction"] = "destro", ["разрушение"] = "destro",
	},
	DRUID = {
		["balance"] = "balance", ["баланс"] = "balance",
		["feral combat"] = "feral", ["feral"] = "feral", ["сила зверя"] = "feral",
		["restoration"] = "resto", ["исцеление"] = "resto",
	},
	DEATHKNIGHT = {
		["blood"] = "blood", ["кровь"] = "blood",
		["frost"] = "frost", ["лед"] = "frost",
		["unholy"] = "unholy", ["нечестивость"] = "unholy",
	},
};

local function BuildUnBotSquadCommand(kill)
	if (not kill or not kill.roster) then
		return nil, "selected kill has no saved roster";
	end

	local playerName = UnitName("player");
	local playerFound = false;
	local missing = {};
	local counts = {};
	local botCount = 0;

	for _, member in ipairs(kill.roster) do
		if (member.name == playerName) then
			playerFound = true;
		else
			local classFile = tostring(member.classFile or "");
			local classKey = UnBotClassKeys[classFile];
			local specKey = UnBotSpecKeys[classFile] and UnBotSpecKeys[classFile][NormalizeText(member.spec)];
			if (not classKey or not specKey) then
				table.insert(missing, tostring(member.name or "?").."["..tostring(member.classFile or member.class or "?")..":"..tostring(member.spec or "?").."]");
			else
				local key = classKey.." "..specKey;
				counts[key] = (counts[key] or 0) + 1;
				botCount = botCount + 1;
			end
		end
	end

	if (not playerFound) then
		return nil, "current character "..tostring(playerName or "?").." was not in this saved kill";
	end
	if (#missing > 0) then
		return nil, "class/spec is missing or unsupported for: "..table.concat(missing, ", ");
	end
	if (botCount == 0) then
		return nil, "this was a solo kill; there are no bots to summon";
	end

	local keys = {};
	for key in pairs(counts) do
		table.insert(keys, key);
	end
	table.sort(keys);

	local parts = {};
	for _, key in ipairs(keys) do
		table.insert(parts, key.." "..tostring(counts[key]));
	end
	return table.concat(parts, ", "), nil, botCount;
end

local function SummonSelectedKill()
	if (not BM.ui or not BM.ui.selectedKill) then
		Print("select a saved kill first");
		return;
	end
	if (type(UnBotSpecSummonSquadStart) ~= "function") then
		Print("UnBot SpecSummon is not loaded or is disabled");
		return;
	end
	if ((GetNumRaidMembers() or 0) > 0 or (GetNumPartyMembers() or 0) > 0) then
		Print("leave the current group first so the saved composition can be recreated exactly");
		return;
	end

	local command, err, botCount = BuildUnBotSquadCommand(BM.ui.selectedKill);
	if (not command) then
		Print("cannot summon this kill: "..tostring(err));
		return;
	end

	Print("summoning saved kill "..tostring(BM.ui.selectedKill.startDate)..": "..command);
	UnBotSpecSummonSquadStart(command);
end

local function BuildBossDetails(instanceKey, bossName)
	local lines = {};
	if (not instanceKey) then
		table.insert(lines, "No saved boss data yet.");
		table.insert(lines, "");
		table.insert(lines, "Do a boss pull, then use /reload or logout to write SavedVariables.");
		return table.concat(lines, "\n");
	end
	if (not bossName) then
		table.insert(lines, "Select a boss.");
		return table.concat(lines, "\n");
	end

	local bucket = BossMemoryDB.bosses and BossMemoryDB.bosses[instanceKey] and BossMemoryDB.bosses[instanceKey][bossName];
	if (not bucket) then
		return "No data for selected boss.";
	end

	local attempts = bucket.attempts or {};
	local killRows = BuildKillRows(bucket, attempts);
	local total = #attempts;
	local bestKill;
	local bestProgress;
	local lastAttempt = attempts[total];
	local maxBossHP = 0;
	local minPlayers, maxPlayersSeen;
	local totalDuration = 0;
	local durationCount = 0;
	local groupSizes = {};
	local bySize = {};

	for _, attempt in ipairs(attempts) do
		local size = attempt.groupSize or 0;
		local sizeRow = bySize[size];
		if (not sizeRow) then
			sizeRow = {
				attempts = 0,
				kills = 0,
				wipes = 0,
				bestPercent = 100,
				maxBossHP = 0,
				totalDuration = 0,
				durationCount = 0,
				incoming = {},
				outgoing = {},
				mechanics = {},
			};
			bySize[size] = sizeRow;
		end
		sizeRow.attempts = sizeRow.attempts + 1;
		if (attempt.result == "kill") then
			sizeRow.kills = sizeRow.kills + 1;
		else
			sizeRow.wipes = sizeRow.wipes + 1;
		end
		if ((attempt.minPercent or 100) < sizeRow.bestPercent) then
			sizeRow.bestPercent = attempt.minPercent or 100;
		end
		if ((attempt.bossMaxHealth or 0) > sizeRow.maxBossHP) then
			sizeRow.maxBossHP = attempt.bossMaxHealth or 0;
		end
		if (attempt.duration) then
			sizeRow.totalDuration = sizeRow.totalDuration + attempt.duration;
			sizeRow.durationCount = sizeRow.durationCount + 1;
		end
		AddCombinedStats(sizeRow.incoming, attempt.damageTakenBySpell);
		AddCombinedStats(sizeRow.outgoing, attempt.damageDoneByGroup);
		AddCombinedMechanics(sizeRow.mechanics, attempt.mechanics);

		if ((attempt.bossMaxHealth or 0) > maxBossHP) then
			maxBossHP = attempt.bossMaxHealth or 0;
		end
		if (attempt.groupSize) then
			minPlayers = minPlayers and math.min(minPlayers, attempt.groupSize) or attempt.groupSize;
			maxPlayersSeen = maxPlayersSeen and math.max(maxPlayersSeen, attempt.groupSize) or attempt.groupSize;
			groupSizes[attempt.groupSize] = (groupSizes[attempt.groupSize] or 0) + 1;
		end
		if (attempt.duration) then
			totalDuration = totalDuration + attempt.duration;
			durationCount = durationCount + 1;
		end
		if (not bestProgress or (attempt.minPercent or 100) < (bestProgress.minPercent or 100)) then
			bestProgress = attempt;
		end
	end

	for _, kill in ipairs(killRows) do
		if (not bestKill or (kill.groupSize or 99) < (bestKill.groupSize or 99) or ((kill.groupSize or 99) == (bestKill.groupSize or 99) and (kill.duration or 999999) < (bestKill.duration or 999999))) then
			bestKill = kill;
		end
	end

	local groupParts = {};
	for size, count in pairs(groupSizes) do
		table.insert(groupParts, tostring(size).."p:"..tostring(count));
	end
	table.sort(groupParts);

	table.insert(lines, bossName);
	table.insert(lines, InstanceLabel(instanceKey));
	table.insert(lines, "");
	table.insert(lines, "Stored attempts: "..tostring(total).." (all kills + recent wipes) | kills "..tostring(bucket.kills or #killRows).." ("..tostring(#killRows).." saved) | wipes "..tostring(bucket.wipes or 0).." | best "..tostring(bucket.bestPercent or "?").."%");
	table.insert(lines, "Boss HP observed: "..FormatNumber(maxBossHP).." | group sizes: "..(#groupParts > 0 and table.concat(groupParts, ", ") or "?"));
	if (durationCount > 0) then
		table.insert(lines, "Average duration: "..tostring(Round(totalDuration / durationCount, 1)).."s | players min/max: "..tostring(minPlayers or "?").."/"..tostring(maxPlayersSeen or "?"));
	end

	if (bestKill) then
		table.insert(lines, "");
		table.insert(lines, "Best kill setup:");
		table.insert(lines, "  "..tostring(bestKill.startDate).." | "..tostring(bestKill.groupSize).." players | "..tostring(bestKill.duration).."s | HP "..FormatNumber(bestKill.bossMaxHealth));
		table.insert(lines, "  "..RosterNames(bestKill));
	end
	if (#killRows > 0) then
		table.insert(lines, "");
		table.insert(lines, "Saved kills:");
		for i = math.max(1, #killRows - 4), #killRows do
			local kill = killRows[i];
			table.insert(lines, "  "..tostring(kill.startDate).." | "..tostring(kill.groupSize).."p | "..tostring(kill.duration).."s | "..tostring(kill.confirmation or "legacy").." | "..RosterNames(kill));
		end
	end
	if (bestProgress and bestProgress ~= bestKill) then
		table.insert(lines, "");
		table.insert(lines, "Best progress:");
		table.insert(lines, "  "..tostring(bestProgress.startDate).." | "..tostring(bestProgress.result).." | min "..tostring(bestProgress.minPercent).."% | "..tostring(bestProgress.groupSize).." players");
		table.insert(lines, "  "..RosterNames(bestProgress));
	end

	table.insert(lines, "");
	table.insert(lines, "Recent attempts:");
	for i = math.max(1, total - 7), total do
		local attempt = attempts[i];
		table.insert(lines, "  #"..tostring(i).." "..tostring(attempt.result).." "..tostring(attempt.startDate).." | "..tostring(attempt.groupSize).."p | min "..tostring(attempt.minPercent).."% | "..tostring(attempt.duration).."s | HP "..FormatNumber(attempt.bossMaxHealth));
	end

	table.insert(lines, "");
	table.insert(lines, "By group size:");
	local sizes = {};
	for size in pairs(bySize) do
		table.insert(sizes, size);
	end
	table.sort(sizes);
	for _, size in ipairs(sizes) do
		local row = bySize[size];
		local avgDuration = row.durationCount > 0 and Round(row.totalDuration / row.durationCount, 1) or "?";
		table.insert(lines, "  "..tostring(size).."p: tries "..tostring(row.attempts).." | kills "..tostring(row.kills).." | wipes "..tostring(row.wipes).." | best "..tostring(row.bestPercent).."% | HP "..FormatNumber(row.maxBossHP).." | avg "..tostring(avgDuration).."s");
	end

	table.insert(lines, "");
	table.insert(lines, "Boss damage to group by size:");
	for _, size in ipairs(sizes) do
		table.insert(lines, "  "..tostring(size).."p: "..TopStatsInline(bySize[size].incoming, 4));
	end

	table.insert(lines, "");
	table.insert(lines, "Group damage to boss by size:");
	for _, size in ipairs(sizes) do
		table.insert(lines, "  "..tostring(size).."p: "..TopStatsInline(bySize[size].outgoing, 4));
	end

	AppendMechanicsBySize(lines, sizes, bySize);

	if (lastAttempt and lastAttempt.note and lastAttempt.note ~= "") then
		table.insert(lines, "");
		table.insert(lines, "Last note: "..lastAttempt.note);
	end

	return table.concat(lines, "\n");
end

local function CreateListButton(parent, width, height)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate");
	button:SetWidth(width);
	button:SetHeight(height);
	button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
	button.text:SetPoint("LEFT", button, "LEFT", 6, 0);
	button.text:SetPoint("RIGHT", button, "RIGHT", -6, 0);
	button.text:SetJustifyH("LEFT");
	return button;
end

function RefreshBossMemoryUI()
	if (not BM.ui) then
		return;
	end

	local ui = BM.ui;
	ui.instanceKeys = SortedInstanceKeys();
	if (#ui.instanceKeys == 0) then
		ui.selectedInstanceKey = nil;
		ui.selectedBossName = nil;
	elseif (not ui.selectedInstanceKey or not BossMemoryDB.bosses[ui.selectedInstanceKey]) then
		ui.selectedInstanceKey = ui.instanceKeys[1];
		ui.instanceOffset = 0;
	end

	ui.bossNames = SortedBossNames(ui.selectedInstanceKey);
	if (#ui.bossNames == 0) then
		ui.selectedBossName = nil;
	elseif (not ui.selectedBossName or not (BossMemoryDB.bosses[ui.selectedInstanceKey] and BossMemoryDB.bosses[ui.selectedInstanceKey][ui.selectedBossName])) then
		ui.selectedBossName = ui.bossNames[1];
		ui.bossOffset = 0;
	end

	local selectionId = tostring(ui.selectedInstanceKey or "").."\031"..tostring(ui.selectedBossName or "");
	local bucket = ui.selectedInstanceKey and ui.selectedBossName and BossMemoryDB.bosses[ui.selectedInstanceKey] and BossMemoryDB.bosses[ui.selectedInstanceKey][ui.selectedBossName];
	ui.killRows = bucket and BuildKillRows(bucket, bucket.attempts or {}) or {};
	if (ui.killSelectionId ~= selectionId) then
		ui.killSelectionId = selectionId;
		ui.selectedKillIndex = #ui.killRows;
	end
	ui.selectedKillIndex = math.max(0, math.min(tonumber(ui.selectedKillIndex) or #ui.killRows, #ui.killRows));
	ui.selectedKill = ui.selectedKillIndex > 0 and ui.killRows[ui.selectedKillIndex] or nil;

	for i, button in ipairs(ui.instanceButtons) do
		local key = ui.instanceKeys[(ui.instanceOffset or 0) + i];
		if (key) then
			button.value = key;
			button.text:SetText(InstanceLabel(key));
			button:Enable();
			button:Show();
			if (key == ui.selectedInstanceKey) then
				button:LockHighlight();
			else
				button:UnlockHighlight();
			end
		else
			button.value = nil;
			button.text:SetText("");
			button:Disable();
			button:Hide();
		end
	end

	for i, button in ipairs(ui.bossButtons) do
		local name = ui.bossNames[(ui.bossOffset or 0) + i];
		if (name) then
			button.value = name;
			button.text:SetText(name);
			button:Enable();
			button:Show();
			if (name == ui.selectedBossName) then
				button:LockHighlight();
			else
				button:UnlockHighlight();
			end
		else
			button.value = nil;
			button.text:SetText("");
			button:Disable();
			button:Hide();
		end
	end

	ui.instancePage:SetText(tostring(math.min((ui.instanceOffset or 0) + 1, #ui.instanceKeys)).."-"..tostring(math.min((ui.instanceOffset or 0) + #ui.instanceButtons, #ui.instanceKeys)).." / "..tostring(#ui.instanceKeys));
	ui.bossPage:SetText(tostring(math.min((ui.bossOffset or 0) + 1, #ui.bossNames)).."-"..tostring(math.min((ui.bossOffset or 0) + #ui.bossButtons, #ui.bossNames)).." / "..tostring(#ui.bossNames));
	if (ui.selectedKill) then
		ui.killPage:SetText("Kill "..tostring(ui.selectedKillIndex).."/"..tostring(#ui.killRows).." | "..tostring(ui.selectedKill.startDate or "?").." | "..tostring(ui.selectedKill.groupSize or "?").."p");
		if (ui.selectedKillIndex > 1) then
			ui.prevKill:Enable();
		else
			ui.prevKill:Disable();
		end
		if (ui.selectedKillIndex < #ui.killRows) then
			ui.nextKill:Enable();
		else
			ui.nextKill:Disable();
		end
		ui.summonKill:Enable();
	else
		ui.killPage:SetText("No saved kills");
		ui.prevKill:Disable();
		ui.nextKill:Disable();
		ui.summonKill:Disable();
	end
	ui.details:SetText(BuildBossDetails(ui.selectedInstanceKey, ui.selectedBossName));
end

local function CreateBossMemoryUI()
	if (BM.ui) then
		return BM.ui.frame;
	end

	local frame = CreateFrame("Frame", "BossMemoryFrame", UIParent, "UIPanelDialogTemplate");
	frame:SetWidth(780);
	frame:SetHeight(560);
	frame:SetPoint("CENTER");
	frame:SetMovable(true);
	frame:EnableMouse(true);
	frame:RegisterForDrag("LeftButton");
	frame:SetScript("OnDragStart", frame.StartMoving);
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing);
	frame:Hide();

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	title:SetPoint("TOP", frame, "TOP", 0, -16);
	title:SetText(BossMemoryDB.recordHistory == false and "UnBot — история боёв отключена" or "UnBot — история боссов");

	local instanceTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	instanceTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -45);
	instanceTitle:SetText("Dungeons");

	local bossTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	bossTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 210, -45);
	bossTitle:SetText("Bosses");

	local detailsTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal");
	detailsTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 402, -45);
	detailsTitle:SetText("Statistics");

	local ui = {
		frame = frame,
		instanceOffset = 0,
		bossOffset = 0,
		instanceButtons = {},
		bossButtons = {},
		instanceKeys = {},
		bossNames = {},
		killRows = {},
		selectedKillIndex = 0,
	};
	BM.ui = ui;

	for i = 1, 18 do
		local button = CreateListButton(frame, 175, 22);
		button:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -65 - ((i - 1) * 24));
		button:SetScript("OnClick", function(self)
			ui.selectedInstanceKey = self.value;
			ui.selectedBossName = nil;
			ui.bossOffset = 0;
			ui.killSelectionId = nil;
			RefreshBossMemoryUI();
		end);
		table.insert(ui.instanceButtons, button);
	end

	for i = 1, 18 do
		local button = CreateListButton(frame, 175, 22);
		button:SetPoint("TOPLEFT", frame, "TOPLEFT", 210, -65 - ((i - 1) * 24));
		button:SetScript("OnClick", function(self)
			ui.selectedBossName = self.value;
			ui.killSelectionId = nil;
			RefreshBossMemoryUI();
		end);
		table.insert(ui.bossButtons, button);
	end

	ui.details = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	ui.details:SetPoint("TOPLEFT", frame, "TOPLEFT", 402, -68);
	ui.details:SetWidth(350);
	ui.details:SetHeight(390);
	ui.details:SetJustifyH("LEFT");
	ui.details:SetJustifyV("TOP");

	local refresh = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
	refresh:SetWidth(90);
	refresh:SetHeight(22);
	refresh:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 18);
	refresh:SetText("Refresh");
	refresh:SetScript("OnClick", RefreshBossMemoryUI);

	local prevInstances = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
	prevInstances:SetWidth(42);
	prevInstances:SetHeight(20);
	prevInstances:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 18);
	prevInstances:SetText("<");
	prevInstances:SetScript("OnClick", function()
		ui.instanceOffset = math.max(0, (ui.instanceOffset or 0) - #ui.instanceButtons);
		RefreshBossMemoryUI();
	end);

	local nextInstances = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
	nextInstances:SetWidth(42);
	nextInstances:SetHeight(20);
	nextInstances:SetPoint("LEFT", prevInstances, "RIGHT", 4, 0);
	nextInstances:SetText(">");
	nextInstances:SetScript("OnClick", function()
		ui.instanceOffset = math.min(math.max(0, #ui.instanceKeys - #ui.instanceButtons), (ui.instanceOffset or 0) + #ui.instanceButtons);
		RefreshBossMemoryUI();
	end);

	ui.instancePage = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	ui.instancePage:SetPoint("LEFT", nextInstances, "RIGHT", 6, 0);
	ui.instancePage:SetWidth(80);
	ui.instancePage:SetJustifyH("LEFT");

	local prevBosses = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
	prevBosses:SetWidth(42);
	prevBosses:SetHeight(20);
	prevBosses:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 210, 18);
	prevBosses:SetText("<");
	prevBosses:SetScript("OnClick", function()
		ui.bossOffset = math.max(0, (ui.bossOffset or 0) - #ui.bossButtons);
		RefreshBossMemoryUI();
	end);

	local nextBosses = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
	nextBosses:SetWidth(42);
	nextBosses:SetHeight(20);
	nextBosses:SetPoint("LEFT", prevBosses, "RIGHT", 4, 0);
	nextBosses:SetText(">");
	nextBosses:SetScript("OnClick", function()
		ui.bossOffset = math.min(math.max(0, #ui.bossNames - #ui.bossButtons), (ui.bossOffset or 0) + #ui.bossButtons);
		RefreshBossMemoryUI();
	end);

	ui.bossPage = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	ui.bossPage:SetPoint("LEFT", nextBosses, "RIGHT", 6, 0);
	ui.bossPage:SetWidth(80);
	ui.bossPage:SetJustifyH("LEFT");

	ui.prevKill = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
	ui.prevKill:SetWidth(42);
	ui.prevKill:SetHeight(22);
	ui.prevKill:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 402, 18);
	ui.prevKill:SetText("<");
	ui.prevKill:SetScript("OnClick", function()
		ui.selectedKillIndex = math.max(1, (ui.selectedKillIndex or 1) - 1);
		RefreshBossMemoryUI();
	end);

	ui.nextKill = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
	ui.nextKill:SetWidth(42);
	ui.nextKill:SetHeight(22);
	ui.nextKill:SetPoint("LEFT", ui.prevKill, "RIGHT", 4, 0);
	ui.nextKill:SetText(">");
	ui.nextKill:SetScript("OnClick", function()
		ui.selectedKillIndex = math.min(#(ui.killRows or {}), (ui.selectedKillIndex or 0) + 1);
		RefreshBossMemoryUI();
	end);

	ui.killPage = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	ui.killPage:SetPoint("LEFT", ui.nextKill, "RIGHT", 6, 0);
	ui.killPage:SetWidth(174);
	ui.killPage:SetJustifyH("LEFT");

	ui.summonKill = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate");
	ui.summonKill:SetWidth(174);
	ui.summonKill:SetHeight(24);
	ui.summonKill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 48);
	ui.summonKill:SetText("Summon this kill");
	ui.summonKill:SetScript("OnClick", SummonSelectedKill);
	ui.summonKill:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT");
		GameTooltip:AddLine("Summon saved composition", 0.4, 0.8, 1);
		GameTooltip:AddLine("Uses UnBot SpecSummon with the classes and specs from the selected successful attempt.", 1, 1, 1);
		GameTooltip:AddLine("You must be solo. Your current character is excluded from the bot list.", 1, 0.82, 0);
		GameTooltip:Show();
	end);
	ui.summonKill:SetScript("OnLeave", function()
		GameTooltip:Hide();
	end);

	return frame;
end

local function ShowBossMemoryUI()
	local frame = CreateBossMemoryUI();
	RefreshBossMemoryUI();
	frame:Show();
end

local function ToggleBossMemoryUI()
	local frame = CreateBossMemoryUI();
	if (frame:IsShown()) then
		frame:Hide();
	else
		RefreshBossMemoryUI();
		frame:Show();
	end
end

local function PositionMinimapButton()
	if (not BM.minimapButton or not Minimap) then
		return;
	end

	local angle = BossMemoryDB.minimap and BossMemoryDB.minimap.angle or 225;
	local radians = math.rad(angle);
	local radius = 80;
	BM.minimapButton:ClearAllPoints();
	BM.minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * radius, math.sin(radians) * radius);
end

local function UpdateMinimapButtonPosition()
	if (not BM.minimapButton or not Minimap) then
		return;
	end

	local mx, my = Minimap:GetCenter();
	local px, py = GetCursorPosition();
	local scale = UIParent:GetEffectiveScale();
	px = px / scale;
	py = py / scale;

	local dx = px - mx;
	local dy = py - my;
	local angle;
	if (dx == 0) then
		angle = dy >= 0 and 90 or 270;
	else
		angle = math.deg(math.atan(dy / dx));
		if (dx < 0) then
			angle = angle + 180;
		elseif (dy < 0) then
			angle = angle + 360;
		end
	end
	if (angle < 0) then
		angle = angle + 360;
	end
	BossMemoryDB.minimap.angle = angle;
	PositionMinimapButton();
end

local function CreateMinimapButton()
	if (BM.minimapButton or not Minimap) then
		return;
	end
	if (BossMemoryDB.minimap and BossMemoryDB.minimap.hide) then
		return;
	end

	local button = CreateFrame("Button", "BossMemoryMinimapButton", Minimap);
	button:SetWidth(31);
	button:SetHeight(31);
	button:SetFrameStrata("MEDIUM");
	button:SetMovable(true);
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp");
	button:RegisterForDrag("LeftButton");

	local overlay = button:CreateTexture(nil, "OVERLAY");
	overlay:SetWidth(53);
	overlay:SetHeight(53);
	overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder");
	overlay:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0);

	local icon = button:CreateTexture(nil, "BACKGROUND");
	icon:SetWidth(20);
	icon:SetHeight(20);
	icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09");
	icon:SetPoint("CENTER", button, "CENTER", 0, 1);
	button.icon = icon;

	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight");

	button:SetScript("OnClick", function(self, mouseButton)
		if (mouseButton == "RightButton") then
			Print("/bm ui - open statistics, /bm last - last attempt");
		else
			ToggleBossMemoryUI();
		end
	end);
	button:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", UpdateMinimapButtonPosition);
	end);
	button:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil);
		UpdateMinimapButtonPosition();
	end);
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT");
		GameTooltip:SetText("UnBot — история боссов");
		GameTooltip:AddLine("Left click: statistics", 1, 1, 1);
		GameTooltip:AddLine("Drag: move button", 1, 1, 1);
		GameTooltip:Show();
	end);
	button:SetScript("OnLeave", function()
		GameTooltip:Hide();
	end);

	BM.minimapButton = button;
	PositionMinimapButton();
end

local function Slash(msg)
	msg = msg or "";
	local cmd, rest = string.match(msg, "^(%S*)%s*(.-)$");
	cmd = string.lower(cmd or "");

	if (cmd == "last" or cmd == "") then
		local attempt, index = GetLastAttempt();
		PrintAttempt(attempt, index);
	elseif (cmd == "boss") then
		PrintBoss(rest);
	elseif (cmd == "ui" or cmd == "show" or cmd == "open") then
		ShowBossMemoryUI();
	elseif (cmd == "minimap") then
		BossMemoryDB.minimap.hide = not BossMemoryDB.minimap.hide;
		if (BossMemoryDB.minimap.hide) then
			if (BM.minimapButton) then
				BM.minimapButton:Hide();
			end
			Print("minimap button hidden. Use /bm minimap to show it.");
		else
			if (not BM.minimapButton) then
				CreateMinimapButton();
			end
			if (BM.minimapButton) then
				BM.minimapButton:Show();
				PositionMinimapButton();
			end
			Print("minimap button shown.");
		end
	elseif (cmd == "note") then
		local attempt = GetLastAttempt();
		if (attempt) then
			attempt.note = rest;
			Print("note saved");
		else
			Print("no last attempt");
		end
	elseif (cmd == "stop") then
		if (BM.active) then
			FinishAttempt("manual", "manual stop");
		else
			Print("no active attempt");
		end
	elseif (cmd == "help") then
		Print("/bm last - show last attempt");
		Print("/bm ui - open visual statistics window");
		Print("/bm minimap - show/hide minimap button");
		Print("/bm boss <name> - show boss history");
		Print("/bm note <text> - add note to last attempt");
		Print("/bm stop - finish active attempt manually");
	else
		Print("unknown command. Use /bm help");
	end
end

UnBotBossMemory.Show = ShowBossMemoryUI;
UnBotBossMemory.Toggle = ToggleBossMemoryUI;

local frame = CreateFrame("Frame");
UnBotBossMemory.frame = frame;
frame:RegisterEvent("ADDON_LOADED");
frame:RegisterEvent("PLAYER_REGEN_DISABLED");
frame:RegisterEvent("PLAYER_REGEN_ENABLED");
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
frame:RegisterEvent("PLAYER_TARGET_CHANGED");
frame:RegisterEvent("PARTY_LOOT_METHOD_CHANGED");
frame:RegisterEvent("CHAT_MSG_WHISPER");
frame:RegisterEvent("CHAT_MSG_LOOT");
frame:RegisterEvent("CHAT_MSG_SYSTEM");
frame:RegisterEvent("BAG_UPDATE");
frame:RegisterEvent("LOOT_OPENED");
frame:RegisterEvent("LOOT_CLOSED");
frame:RegisterEvent("START_LOOT_ROLL");
frame:RegisterEvent("CANCEL_LOOT_ROLL");
frame:SetScript("OnEvent", function(self, event, ...)
	if (event == "ADDON_LOADED") then
		local addon = ...;
		if (addon == ADDON and not BM.initialized) then
			UnBotBossMemory.InitializeStorage();
			InitDB();
			BM.initialized = true;
			SLASH_BOSSMEMORY1 = "/bm";
			SLASH_BOSSMEMORY2 = "/bossmemory";
			SlashCmdList["BOSSMEMORY"] = Slash;
			SLASH_UNBOTBOSSES1 = "/ubbosses";
			SlashCmdList["UNBOTBOSSES"] = ShowBossMemoryUI;
			CreateMinimapButton();
			Print("модуль загружен. /ubbosses — история боёв; /bm help — команды.");
			if (UnBotBossMemory.legacyImportedNow and not UnBotBossMemory.historyClearedNow) then
				Print("старая история перенесена в UnBot; /reload сохранит её в новом хранилище.");
			end
			if (UnBotBossMemory.historyClearedNow) then
				Print("Накопленная история боёв очищена; запись новых боёв отключена. /reload сохранит очистку.");
			end
			if (UnBotBossMemory.storageWarning) then Print(UnBotBossMemory.storageWarning); end
		end
	elseif (not BM.initialized) then
		return;
	elseif (event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_TARGET_CHANGED") then
		if (event == "PLAYER_TARGET_CHANGED") then
			if (IsActiveBossCorpse("target")) then
				FinishAttempt("kill", "dead boss corpse targeted");
				return;
			end
			NotifyUnBotBossTarget("target");
			EnsureMasterLootForBoss("target");
		end
		local unit = ScanBossUnit();
		if (BM.active and IsActiveBossReappeared(unit)) then
			FinishAttempt("wipe", "boss respawned with a new GUID");
		end
		if (unit and not BM.active and UnitAffectingCombat("player")) then
			StartAttempt(unit);
		end
	elseif (event == "PARTY_LOOT_METHOD_CHANGED") then
		if (IsBossUnit("target")) then
			EnsureMasterLootForBoss("target");
		end
	elseif (event == "PLAYER_REGEN_ENABLED") then
		if (BM.active and IsActiveRosterAllDead()) then
			FinishAttempt("wipe", "entire roster dead");
		end
	elseif (event == "COMBAT_LOG_EVENT_UNFILTERED") then
		local timestamp, eventType, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags = ...;
		TrackMechanicCombatEvent(eventType, srcGUID, srcName, dstGUID, dstName, select(9, ...));
		TrackDamageEvent(eventType, srcGUID, srcName, dstGUID, dstName, select(9, ...));
		if (BM.active and eventType == "SPELL_SUMMON") then
			TrackMechanicSeen(eventType, dstGUID, dstName);
		elseif (BM.active and eventType == "UNIT_DIED") then
			TrackMechanicSeen(eventType, dstGUID, dstName);
		end
		if (eventType == "UNIT_DIED" or eventType == "PARTY_KILL") then
			if (BM.active and (dstGUID == BM.active.bossGUID or dstName == BM.active.bossName)) then
				FinishAttempt("kill", "combat-log death");
			elseif (not BM.active) then
				PromoteLastAttemptToKill(dstGUID, dstName);
			end
		end
	elseif (event == "CHAT_MSG_WHISPER") then
		local message, sender = ...;
		HandleWhoWhisper(message, sender);
	elseif (event == "CHAT_MSG_LOOT" or event == "CHAT_MSG_SYSTEM") then
		CheckBossRewardMessage(...);
	elseif (event == "BAG_UPDATE") then
		CheckBossRewardBags();
	elseif (event == "LOOT_OPENED") then
		BM.lootOpen = true;
		if (IsActiveBossCorpse("target")) then
			FinishAttempt("kill", "boss corpse loot opened");
		end
	elseif (event == "LOOT_CLOSED") then
		BM.lootOpen = false;
	elseif (event == "START_LOOT_ROLL") then
		local rollId, rollTime = ...;
		if (rollId) then
			BM.activeLootRolls[rollId] = GetTime() + ((tonumber(rollTime) or 60000) / 1000) + 5;
		end
	elseif (event == "CANCEL_LOOT_ROLL") then
		local rollId = ...;
		if (rollId) then
			BM.activeLootRolls[rollId] = nil;
		end
	end
end);

frame:SetScript("OnUpdate", function(self, elapsed)
	if (not BM.initialized) then return; end
	BM.updateTick = BM.updateTick + elapsed;
	if (BM.updateTick < 0.5) then
		return;
	end
	BM.updateTick = 0;

	if (
		BM.active
		and (
			IsActiveBossCorpse("target")
			or IsActiveBossCorpse("focus")
			or IsActiveBossCorpse("mouseover")
		)
	) then
		FinishAttempt("kill", "dead boss corpse observed");
		return;
	end

	if (BM.lootCheckPending and GetTime() >= BM.lootCheckPending.at) then
		local pending = BM.lootCheckPending;
		BM.lootCheckPending = nil;
		local lootMethod = GetLootMethod and GetLootMethod();
		if (lootMethod == "master") then
			Print("loot method confirmed: Master Looter");
		else
			Print("could not enable Master Looter for "..tostring(pending.bossName).."; group leader rights are required");
		end
	end

	if (BM.saveReloadPending and BM.saveReloadAt and GetTime() >= BM.saveReloadAt and not BM.active and not UnitAffectingCombat("player") and not IsLootUIBusy()) then
		BM.saveReloadPending = false;
		BM.saveReloadAt = nil;
		BM.saveReloadRewardSeen = false;
		Print("confirmed kill written to SavedVariables; reloading UI now");
		ReloadUI();
		return;
	end

	local unit = ScanBossUnit();
	if (BM.active and unit and IsActiveBossReappeared(unit)) then
		FinishAttempt("wipe", "boss respawned with a new GUID");
	end
	if (unit and not BM.active and UnitAffectingCombat("player")) then
		StartAttempt(unit);
	end
	if (BM.active) then
		if (IsActiveRosterAllDead()) then
			FinishAttempt("wipe", "entire roster dead");
			return;
		end
		if (unit) then
			UpdateActiveFromUnit(unit);
		elseif (not BM.active.bossMissingSince) then
			BM.active.bossMissingSince = GetTime();
			BM.active.missingNoticeShown = false;
		end
		UpdateActiveFromUnit("target");
		UpdateActiveFromUnit("focus");
		UpdateActiveFromUnit("mouseover");
		if (
			BM.active
			and BM.active.friendlyVictory
			and (BM.active.lastPercent or 0) >= 99.5
			and (BM.active.bossStartPercent or 100) < 95
		) then
			FinishAttempt("kill", "friendly encounter healed to full");
			return;
		end
		if (BM.active and BM.active.bossMissingSince and not IsAnyActiveRosterInCombat()) then
			local missingFor = GetTime() - BM.active.bossMissingSince;
			if (missingFor >= 10 and not BM.active.missingNoticeShown) then
				BM.active.missingNoticeShown = true;
				Print("boss missing; waiting for combat-log death or emblem reward");
			end
			if (missingFor >= BOSS_COMPLETION_TIMEOUT) then
				if (IsReliableVanishedKill(BM.active)) then
					FinishAttempt(
						"kill",
						"reliable boss disappearance out of combat for "
						..tostring(BOSS_COMPLETION_TIMEOUT).."s"
					);
				else
					FinishAttempt(
						"wipe",
						"no death or boss reward after "
						..tostring(BOSS_COMPLETION_TIMEOUT).."s"
					);
				end
			end
		end
	end
end);
