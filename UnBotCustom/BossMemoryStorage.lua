-- Boss history belongs to UnBot. The optional legacy TOC reads old WoW data once.
UnBotBossMemory = UnBotBossMemory or {};

function UnBotBossMemory.MergeHistory(target, source)
	local function RowKey(row)
		if (type(row) ~= "table") then return type(row)..":"..tostring(row); end
		if (row.recordId and row.recordId ~= "") then return tostring(row.recordId); end
		return table.concat({tostring(row.instanceKey or ""), tostring(row.bossName or ""),
			tostring(row.startDate or ""), tostring(row.endDate or ""),
			tostring(row.groupSize or ""), tostring(row.duration or "")}, "|");
	end
	local function Merge(dst, src)
		for key, value in pairs(src) do
			if (dst[key] == nil) then
				dst[key] = value;
			elseif (type(dst[key]) == "table" and type(value) == "table" and dst[key] ~= value) then
				if (key == "killsLog" or key == "attempts") then
					local seen = {};
					for _, row in ipairs(dst[key]) do seen[RowKey(row)] = row; end
					for _, row in ipairs(value) do
						local id = RowKey(row);
						if (not seen[id]) then
							table.insert(dst[key], row);
							seen[id] = row;
						elseif (type(row) == "table" and type(seen[id]) == "table") then
							Merge(seen[id], row);
						end
					end
				else
					Merge(dst[key], value);
				end
			end
		end
	end
	if (target ~= source) then Merge(target, source); end
	return target;
end

function UnBotBossMemory.InitializeStorage()
	local db = type(UnBotBossMemoryDB) == "table" and UnBotBossMemoryDB or {};
	-- Also preserve data already loaded through a client-cached legacy TOC.
	if (not db.unbotLegacyImported and type(BossMemoryDB) == "table" and BossMemoryDB ~= db) then
		UnBotBossMemory.MergeHistory(db, BossMemoryDB);
	end
	if (not db.unbotLegacyImported and GetAddOnMetadata
		and GetAddOnMetadata("BossMemory", "X-UnBot-DataBridge") == "1") then
		-- The retired addon has no Lua scripts, events or UI. Loading only its TOC
		-- is the WoW-supported way to read BossMemory.lua from SavedVariables.
		if (EnableAddOn) then EnableAddOn("BossMemory"); end
		local ok, loaded, reason = pcall(LoadAddOn, "BossMemory");
		if (ok and loaded) then
			if (type(BossMemoryDB) == "table") then
				UnBotBossMemory.MergeHistory(db, BossMemoryDB);
			end
			db.unbotLegacyImported = true;
			UnBotBossMemory.legacyImportedNow = true;
		else
			UnBotBossMemory.storageWarning = "Старую историю пока не удалось загрузить: "
				..tostring(ok and reason or "ошибка загрузки")..". Она сохранена; повтор будет при следующем входе.";
		end
	end
	-- Explicit user request, 2026-10-28: discard the accumulated fight archive once.
	-- Keep settings and unrelated fields, and never re-import the retired archive.
	if ((tonumber(db.historyClearRevision) or 0) < 1) then
		db.bosses = {};
		db.last = nil;
		db.historyClearRevision = 1;
		db.unbotLegacyImported = true;
		UnBotBossMemory.storageWarning = nil;
		UnBotBossMemory.historyClearedNow = true;
	end
	-- Explicit follow-up: do not accumulate new battle records either.
	if ((tonumber(db.historyDisabledRevision) or 0) < 1) then
		db.bosses = {};
		db.last = nil;
		db.recordHistory = false;
		UnBotBossMemory.historyClearedNow = true;
		db.historyDisabledRevision = 1;
	end
	UnBotBossMemoryDB = db;
	BossMemoryDB = db; -- compatibility for existing consumers and /bm
	return db;
end
