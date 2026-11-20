-- WotLK 3.3.5a: a bounded experiment for conflicting Winter movement.
-- The server owns ICC positioning, targeting, tanking and healing.
UnBotLichKing = {active = false, jobs = {}, nextSend = 0, ignoreUntil = 0};
local state = UnBotLichKing;
local frame = CreateFrame("Frame");
local winter = { [68981]=true, [74270]=true, [74271]=true, [74272]=true,
    [72259]=true, [74273]=true, [74274]=true, [74275]=true };

local function Message(text)
    if UnBotCombatChat then UnBotCombatChat.Write("|cff66ccffЛич: |r"..text)
    elseif DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffЛич: |r"..text); end
end

local function Config()
    UnBotSquadConfig = UnBotSquadConfig or {};
    UnBotSquadConfig.lichKing = UnBotSquadConfig.lichKing or {};
    local db = UnBotSquadConfig.lichKing;
    if db.enabled == nil then db.enabled = true; end
    db.restore = db.restore or {};
    db.history = db.history or {};
    return db;
end

local function Enabled()
    return Config().enabled and UnBotBossPresetLoadedAutoStrategyEnabled
        and UnBotBossPresetLoadedAutoStrategyEnabled("the_lich_king");
end

local function IsBoss(guid)
    return type(guid) == "string" and (string.sub(guid, 1, 6) == "0xF130" or string.sub(guid, 1, 6) == "0xF150")
        and tonumber(string.sub(guid, 7, 12), 16) == 36597;
end

local function UnitFor(name, alive)
    if name == UnitName("player") then return nil; end
    local profile = UnBotBotRegistry and UnBotBotRegistry.bots and UnBotBotRegistry.bots[name];
    local unit = profile and UnBotSquadRosterFindUnit and UnBotSquadRosterFindUnit(name);
    if unit and UnitIsConnected(unit) and (not alive or not UnitIsDeadOrGhost(unit)) then
        return unit;
    end
end

local function Members()
    local names = {};
    local raid = (GetNumRaidMembers() or 0) > 0;
    for i = 1, math.min(raid and 40 or 4, raid and GetNumRaidMembers() or GetNumPartyMembers()) do
        local name = UnitName((raid and "raid" or "party")..i);
        if name and UnitFor(name, true) then names[#names + 1] = name; end
    end
    return names;
end

local function GroupInCombat()
    if UnitAffectingCombat("player") then return true; end
    for _, name in ipairs(Members()) do
        if UnitAffectingCombat(UnitFor(name, true)) then return true; end
    end
    return false;
end

local function Log(kind, name, detail)
    local run = state.run;
    if not run then return; end
    if #run.events >= 240 then run.dropped = (run.dropped or 0) + 1; return; end
    run.events[#run.events + 1] = {at = GetTime() - state.started,
        kind = kind, name = name, detail = string.sub(tostring(detail or ""), 1, 700)};
end

local function Queue(name, stage, command)
    state.jobs[name] = {stage = stage, command = command, due = GetTime()};
end

local function RestoreCommand(old)
    return "co "..(old.icc and "+" or "-").."icc,"
        ..(old.avoid and "+" or "-").."avoid aoe";
end

local function Restore(reason)
    local db = Config();
    state.active = false;
    state.ignoreUntil = GetTime() + 8;
    state.jobs = {}; -- Cancel unsent mutations and outstanding snapshot requests.
    if state.run then state.run.ended = date("%Y-%m-%d %H:%M:%S"); state.run.reason = reason; end
    local count = 0;
    for name, old in pairs(db.restore) do
        if type(old) == "table" and type(old.icc) == "boolean" and type(old.avoid) == "boolean" then
            if UnitFor(name, false) then
                Queue(name, "restore_send", RestoreCommand(old));
                count = count + 1;
            else
                Log("restore-unavailable", name, "Исходный профиль сохранён; /ublk restore после возвращения бота.");
            end
        end
    end
    state.recoverUntil = GetTime() + 20;
    if count > 0 then Message(reason..". Возвращаю исходные стратегии: "..count.."."); end
end

local function Start(guid)
    local db = Config();
    if not Enabled() or state.active or GetTime() < state.ignoreUntil or not GroupInCombat() then return; end
    local _, kind = GetInstanceInfo();
    if kind ~= "raid" then return; end
    if next(db.restore) then
        Message("Осталось неподтверждённое восстановление. Выполни /ublk restore перед новым тестом.");
        state.ignoreUntil = GetTime() + 75;
        return;
    end
    state.active = true;
    state.boss = guid;
    state.started = GetTime();
    state.damageKeys = 0;
    state.deadline = state.started + 75;
    state.jobs = {};
    state.summaryAt = state.started + 12;
    state.run = {started = date("%Y-%m-%d %H:%M:%S"), events = {}, bots = {}, damage = {}};
    db.history[#db.history + 1] = state.run;
    while #db.history > 3 do table.remove(db.history, 1); end
    for _, name in ipairs(Members()) do
        state.run.bots[name] = {confirmed = false};
        Queue(name, "snapshot", "co ?");
    end
    Message("Переход — на внешний обод! Проверяю стратегии; ICC управляет аддами, общий avoid aoe временно снимается.");
    Log("winter", nil, guid);
end

-- The installed UnBot StrategyFrame uses the same unlabelled Strategies: reply.
-- Only accept it while waiting for this bot's own co query, never outside a job.
local function ParseStrategies(text)
    text = string.lower(tostring(text or "")):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "");
    if text:find("non%-combat") or text:find("non combat", 1, true) then return nil; end
    local list = text:match("strategies:%s*(.*)");
    if not list then return nil; end
    local result = {};
    for token in list:gmatch("[^,]+") do
        token = token:match("^%s*(.-)%s*$");
        result[token] = true;
    end
    return {icc = result.icc == true, avoid = result["avoid aoe"] == true};
end

local function Reply(text, sender)
    local job = state.jobs[sender];
    if not job then return; end
    local low = string.lower(tostring(text or ""));
    if low:find("unknown", 1, true) or low:find("cannot", 1, true)
        or low:find("not allowed", 1, true) or low:find("invalid", 1, true) then
        Log("refused", sender, text);
        state.jobs[sender] = nil;
        Message(sender..": отказ сервера; повторов нет. Проверь /ublk status.");
        return;
    end
    if not job.waitUntil or GetTime() > job.waitUntil then return; end
    local flags = ParseStrategies(text);
    if not flags then return; end
    Log(job.stage.."-reply", sender, text);
    local db = Config();
    if job.stage == "snapshot" and state.active then
        if not UnitFor(sender, true) then state.jobs[sender] = nil; return; end
        state.run.bots[sender].before = flags;
        if flags.icc and not flags.avoid then
            state.run.bots[sender].confirmed = true;
            state.jobs[sender] = nil;
        else
            -- Persist the undo record BEFORE sending a mutation, including across /reload.
            db.restore[sender] = flags;
            Queue(sender, "apply_send", "co +icc,-avoid aoe");
        end
    elseif job.stage == "verify" then
        state.run.bots[sender].confirmed = flags.icc and not flags.avoid;
        if not state.run.bots[sender].confirmed then
            Message(sender..": профиль перехода не подтверждён; возможен конфликт другой тактики.");
        end
        state.jobs[sender] = nil;
    elseif job.stage == "restore_verify" then
        local old = db.restore[sender];
        if old and flags.icc == old.icc and flags.avoid == old.avoid then
            db.restore[sender] = nil;
            Log("restored", sender, "Исходные icc / avoid aoe подтверждены");
        else
            Message(sender..": восстановление не подтверждено. /ublk restore — одна новая попытка.");
        end
        state.jobs[sender] = nil;
    end
end

local function Status()
    local db = Config();
    Message((db.enabled and "Включён" or "Выключен").."; переход: "..(state.active and "да" or "нет")..".");
    Message("Автостратегия загруженного пресета Лича: "..(Enabled() and "активна" or "не активна")..".");
    local run = state.run or db.history[#db.history];
    if run then
        for name, bot in pairs(run.bots) do
            Message(name..": ICC без avoid aoe "..(bot.confirmed and "подтверждён" or "не подтверждён")..".");
            if bot.before then
                Message(name..": до перехода icc "..(bot.before.icc and "вкл" or "выкл")
                    ..", avoid aoe "..(bot.before.avoid and "вкл" or "выкл")..".");
            end
        end
    end
    local count = 0;
    for name in pairs(db.restore) do count = count + 1; Message(name..": требуется подтверждение восстановления."); end
    if count == 0 then Message("Незавершённых восстановлений нет."); end
    Message("Автофокус валь'кир: "..(db.valkyrEnabled ~= false and "включён" or "выключен")..".");
end

-- Attack requests only: ICC, tanking, healing and hazard avoidance stay in charge.
local valkIds = {[36609]=true, [39120]=true, [39121]=true, [39122]=true};
local icons = {"star", "circle", "diamond", "triangle", "moon", "square", "cross", "skull"};

local function NpcId(guid)
    if type(guid) == "string" and (guid:sub(1, 6) == "0xF130" or guid:sub(1, 6) == "0xF150") then
        return tonumber(guid:sub(7, 12), 16);
    end
end

local function SeenUnits()
    local units = {"target", "focus", "mouseover", "boss1", "boss2", "boss3", "boss4"};
    local raid = (GetNumRaidMembers() or 0) > 0;
    for i = 1, math.min(raid and 40 or 4, raid and GetNumRaidMembers() or GetNumPartyMembers()) do
        units[#units + 1] = (raid and "raid" or "party")..i.."target";
    end
    return units;
end

-- Sphere duty survives Quake: remaining orbs can still knock players off.
local sphereIds = {[36633]=true, [39305]=true, [39306]=true, [39307]=true};

local function SphereLog(kind, name, detail)
    local q=state.spheres;
    if q and #q.report.events < 240 then
        q.report.events[#q.report.events+1]={at=GetTime()-q.started,kind=kind,name=name,detail=detail};
    end
end

local function SphereEvent(kind, source, dest, spell, sourceName)
    if not Enabled() then return; end
    if IsBoss(source) and winter[spell] and (kind == "SPELL_CAST_START" or kind == "SPELL_AURA_APPLIED")
        and GroupInCombat() then
        local _, instance=GetInstanceInfo();
        if instance ~= "raid" then return; end
        if not state.spheres then
            local q={started=GetTime(),deadline=GetTime()+95,seen={},count=0};
            q.report={started=date("%Y-%m-%d %H:%M:%S"),events={}};
            state.spheres=q;
            local db=Config(); db.sphereHistory=db.sphereHistory or {};
            db.sphereHistory[#db.sphereHistory+1]=q.report;
            while #db.sphereHistory > 3 do table.remove(db.sphereHistory,1); end
            Message("Хант: ледяные сферы — первый приоритет, включая остатки после Сотрясения.");
        end
    end
    local q=state.spheres;
    if not q then return; end
    if IsBoss(source) and spell == 72262 and kind == "SPELL_CAST_START" then
        q.deadline=math.min(q.deadline,GetTime()+25);
    elseif kind == "UNIT_DIED" then
        if IsBoss(dest) then q.deadline=0; end
        if q.seen[dest] then q.seen[dest].done=true; end
    elseif (kind == "RANGE_DAMAGE" or kind == "SPELL_DAMAGE" or kind == "SWING_DAMAGE") and q.seen[dest] then
        local h=q.seen[dest].hunters[sourceName];
        if h and not h.confirmed then
            h.confirmed=true; SphereLog("damage-confirmed",sourceName,dest);
            Message(sourceName..": урон по ледяной сфере подтверждён.");
        end
    end
end

local function SphereTick()
    state.sphereHunters={};
    local q=state.spheres;
    if not q then return; end
    if not Enabled() or not GroupInCombat() or GetTime() >= q.deadline then
        SphereLog("end",nil,"окно сфер завершено"); state.spheres=nil; return;
    end
    local chosen, chosenUnit, score;
    for _,unit in ipairs(SeenUnits()) do
        local guid=UnitGUID(unit);
        if sphereIds[NpcId(guid)] and UnitExists(unit) and not UnitIsDeadOrGhost(unit)
            and UnitCanAttack("player",unit) and (UnitHealth(unit) or 0)>0 then
            local entry=q.seen[guid];
            if not entry and q.count < 40 then
                entry={deadline=GetTime()+20,hunters={}}; q.seen[guid]=entry; q.count=q.count+1;
            end
            if entry and not entry.done and GetTime()<entry.deadline then
                -- Rescue the player first, then finish the weakest visible orb.
                local rank=(UnitName(unit.."target")==UnitName("player") and 0 or 100000000)+(UnitHealth(unit) or 0);
                if not score or rank<score or (rank==score and guid<chosen) then
                    chosen=guid; chosenUnit=unit; score=rank;
                end
            end
        end
    end
    if not chosen then return; end
    local entry=q.seen[chosen];
    -- Fill the whole reservation before any early return after a whisper.
    for _,name in ipairs(Members()) do
        local profile=UnBotBotRegistry.bots[name];
        local unit=UnitFor(name,true);
        if string.lower(tostring(profile.className or ""))=="hunter" and unit
            and not (UnitInVehicle and UnitInVehicle(unit)) then state.sphereHunters[name]=true; end
    end
    for _,name in ipairs(Members()) do
        local profile=UnBotBotRegistry.bots[name];
        if string.lower(tostring(profile.className or ""))=="hunter" then
            local unit=UnitFor(name,true);
            if unit and not (UnitInVehicle and UnitInVehicle(unit)) then
                state.sphereHunters[name]=true; -- Never send a competing Valkyr order.
                local h=entry.hunters[name];
                if not h then h={attempts=0,nextAt=0,marks=0};entry.hunters[name]=h; end
                if not h.blocked and h.attempts<6 and GetTime()>=h.nextAt and GetTime()>=state.nextSend then
                    if UnitGUID(unit.."target")==chosen and h.attempts>0 then
                        h.nextAt=GetTime()+0.3;
                    else
                        if UnitGUID(chosenUnit)~=chosen then return; end
                        local icon=GetRaidTargetIndex(chosenUnit);
                        local command;
                        if icons[icon] then
                            if h.icon==icon and q.lastGuid==chosen then
                                command="attack rti target"; h.icon=nil; h.attempts=h.attempts+1;h.nextAt=GetTime()+1;
                            else
                                h.marks=h.marks+1;
                                if h.marks>12 then h.blocked=true;return;end
                                command="rti "..icons[icon];h.icon=icon;h.nextAt=GetTime()+0.15;
                            end
                        elseif UnitGUID("target")==chosen then
                            command="attack";h.attempts=h.attempts+1;h.nextAt=GetTime()+1;h.icon=nil;
                        elseif not entry.warned then
                            entry.warned=true; Message("Сфера без метки: выдели её целью для адресного приказа ханту.");
                        end
                        if command then
                            q.lastGuid=chosen; q.lastSender=name; h.sentAt=GetTime();
                            state.nextSend=GetTime()+0.15;SphereLog("command",name,command.." "..chosen);
                            SendChatMessage(command,"WHISPER",nil,name);return;
                        end
                    end
                end
            end
        end
    end
end

local function ValkLog(kind, name, detail)
    local v = state.valk;
    if not v or not v.report then return; end
    if #v.report.events >= 240 then v.report.dropped = (v.report.dropped or 0) + 1; return; end
    v.report.events[#v.report.events + 1] = {at=GetTime()-v.started, kind=kind, name=name, detail=detail};
end

local function ValkStop(reason)
    local v = state.valk;
    if not v or not v.current then return; end
    ValkLog("end", nil, reason);
    Message("Валь'кира: "..reason..". Выбор дальнейшей цели — ICC.");
    v.current = nil;
    v.helpers = {};
end

local function ValkEvent(kind, source, dest, spell, sourceName)
    if not Enabled() or Config().valkyrEnabled == false then return; end
    local v = state.valk;
    if not v and (IsBoss(source) or IsBoss(dest))
        and (kind == "SPELL_CAST_START" or kind == "SPELL_SUMMON" or kind == "SWING_DAMAGE" or kind == "SPELL_DAMAGE") then
        local _, instance = GetInstanceInfo();
        if instance ~= "raid" or not GroupInCombat() then return; end
        v = {started=GetTime(), deadline=GetTime()+900, seen={}, count=0, helpers={}, blocked={}, nextSend=0};
        state.valk = v;
    end
    if not v then return; end
    if kind == "UNIT_DIED" and IsBoss(dest) then ValkStop("босс погиб"); v.deadline = 0; return; end
    if v.deadline <= GetTime() then return; end
    if kind == "SPELL_CAST_START" and IsBoss(source) and winter[spell] then
        ValkStop("началась зима"); v.pauseUntil=GetTime()+75;
    elseif kind == "SPELL_CAST_START" and IsBoss(source) and spell == 72262 then
        v.pauseUntil=GetTime()+5;
    elseif kind == "SPELL_CAST_START" and IsBoss(source) and spell == 72762 then
        -- CLEU does not reliably expose the Defile target. Leave native ICC
        -- three seconds to move without an extra attack request from us.
        v.pauseUntil=GetTime()+3;
    elseif kind == "SPELL_CAST_START" and valkIds[NpcId(source)] and (spell == 73784 or spell == 73785 or spell == 73786) then
        if v.seen[source] then v.seen[source].done=true; end
        if v.current == source then ValkStop("валь'кира перешла к вытягиванию жизни"); end
    elseif kind == "UNIT_DIED" and valkIds[NpcId(dest)] then
        if v.seen[dest] then v.seen[dest].done=true; end
        if v.current == dest then ValkStop("цель погибла"); end
    elseif (kind == "SPELL_DAMAGE" or kind == "RANGE_DAMAGE" or kind == "SWING_DAMAGE")
        and dest == v.current and v.helpers[sourceName] and not v.helpers[sourceName].confirmed then
        v.helpers[sourceName].confirmed=true;
        ValkLog("damage-confirmed", sourceName, dest);
        Message(sourceName..": урон по валь'кире подтверждён.");
    end
end

local function ValkTick()
    local v = state.valk;
    if not v then return; end
    if not GroupInCombat() then ValkStop("группа вышла из боя"); state.valk=nil; return; end
    if not Enabled() or Config().valkyrEnabled == false or GetTime() >= v.deadline then
        ValkStop("автофокус остановлен"); return;
    end
    if GetTime() < (v.pauseUntil or 0) or state.active then return; end
    local _, _, difficulty = GetInstanceInfo();
    local heroic = difficulty == 3 or difficulty == 4;
    local found = {};
    for _, unit in ipairs(SeenUnits()) do
        local guid = UnitGUID(unit);
        if valkIds[NpcId(guid)] and UnitExists(unit) and not UnitIsDeadOrGhost(unit)
            and UnitCanAttack("player", unit) then
            local max = UnitHealthMax(unit) or 0;
            local hp = UnitHealth(unit) or 0;
            local seen = v.seen[guid];
            if not seen and v.count < 60 then
                seen = {untilTime=GetTime()+25, attempts={}};
                v.seen[guid]=seen; v.count=v.count+1;
            end
            if seen and heroic and max > 0 and hp/max <= 0.5 then
                seen.done=true;
                if guid == v.current then ValkStop("50% HP — приоритет снят"); end
            end
            if seen and not seen.done and GetTime() < seen.untilTime and max > 0 and hp > 0 then
                found[guid] = {unit=unit, icon=GetRaidTargetIndex(unit), hp=hp};
            end
        end
    end
    if v.current and not found[v.current] then
        if not v.missingAt then v.missingAt=GetTime(); end
        if GetTime()-v.missingAt < 1 then return; end
        ValkStop("цель недоступна или истёк лимит 25с");
    end
    local chosen = v.current;
    if not chosen then
        for guid, info in pairs(found) do
            if icons[info.icon] and (not chosen or info.hp < found[chosen].hp
                or (info.hp == found[chosen].hp and guid < chosen)) then chosen=guid; end
        end
    end
    if not chosen then
        if next(found) and not v.unmarkedWarned then
            v.unmarkedWarned=true;
            Message("Валь'кира видна, но рейдовой метки нет: жду метку ICC, команда по случайной цели не отправляется.");
        end
        return;
    end
    v.missingAt=nil;
    local info=found[chosen];
    if not icons[info.icon] then return; end
    if chosen ~= v.current then
        v.current=chosen; v.helpers={}; v.blocked={}; v.unmarkedWarned=nil;
        v.report={started=date("%Y-%m-%d %H:%M:%S"), guid=chosen, events={}};
        local db=Config(); db.valkyrHistory=db.valkyrHistory or {};
        db.valkyrHistory[#db.valkyrHistory+1]=v.report;
        while #db.valkyrHistory > 3 do table.remove(db.valkyrHistory, 1); end
        for _, name in ipairs(Members()) do
            if not state.IsBossRogue(name) then v.helpers[name]={nextAt=0}; end
        end
        Message((Config().rogueBossFocus and "Валь'кира — фокус без рог! Метка: " or "Валь'кира — общий фокус ВСЕХ ботов! Метка: ")..icons[info.icon]..(heroic and ", до 50% HP." or ", до уничтожения."));
    end
    if GetTime() < v.nextSend or GetTime() < state.nextSend then return; end
    for name, helper in pairs(v.helpers) do
        local attempts=v.seen[chosen].attempts;
        local botUnit=UnitFor(name, true);
        if not v.blocked[name] and not (state.sphereHunters and state.sphereHunters[name]) and botUnit
            and not (UnitInVehicle and UnitInVehicle(botUnit))
            and GetTime() >= helper.nextAt and (attempts[name] or 0) < 3 then
            local target=UnitGUID(botUnit.."target");
            if target == chosen and (attempts[name] or 0) > 0 then
                helper.nextAt=GetTime()+1;
                helper.icon=nil;
            else
                -- Recheck GUID and icon before EACH half of the command pair.
                if UnitGUID(info.unit) ~= chosen or GetRaidTargetIndex(info.unit) ~= info.icon then return; end
                local command;
                if helper.icon == info.icon then
                    command="attack rti target";
                    attempts[name]=(attempts[name] or 0)+1;
                    helper.icon=nil; helper.nextAt=GetTime()+2;
                else
                    command="rti "..icons[info.icon]; helper.icon=info.icon;
                    helper.nextAt=GetTime()+0.15;
                    helper.markerChanges=(helper.markerChanges or 0)+1;
                    if helper.markerChanges > 6 then v.blocked[name]=true; return; end
                end
                v.nextSend=GetTime()+0.15; state.nextSend=v.nextSend;
                helper.sentAt=GetTime();
                ValkLog("command", name, command);
                SendChatMessage(command, "WHISPER", nil, name);
                return;
            end
        end
    end
end

-- Saurfang-style shared DPS focus, bounded and subordinate to LK emergencies.
function state.AddLog(kind, name, detail)
    local q=state.adds;
    if q and #q.report.events<240 then
        q.report.events[#q.report.events+1]={at=GetTime()-q.started,kind=kind,name=name,detail=detail};
    end
end

function state.AddEvent(kind, source, dest, spell, sourceName)
    if not Enabled() then return; end
    if IsBoss(source) and ((winter[spell] and kind=="SPELL_CAST_START")
        or (kind=="SPELL_SUMMON" and (NpcId(dest)==37698 or NpcId(dest)==36701))) and GroupInCombat() then
        local _,instance=GetInstanceInfo();
        if instance~="raid" then return; end
        if not state.adds then
            local q={started=GetTime(),deadline=GetTime()+180,seen={},count=0};
            q.report={started=date("%Y-%m-%d %H:%M:%S"),events={}};
            state.adds=q;
            local db=Config();db.addHistory=db.addHistory or {};
            db.addHistory[#db.addHistory+1]=q.report;
            while #db.addHistory>3 do table.remove(db.addHistory,1); end
            Message("Адды: общий фокус всех ДД — ужас, затем духи; сферы и валь'киры приоритетнее.");
        end
    end
    local q=state.adds;
    if not q then return; end
    if IsBoss(source) and kind=="SPELL_CAST_START" and spell==72262 then
        q.deadline=math.min(q.deadline,GetTime()+60);q.pauseUntil=GetTime()+5;
    elseif IsBoss(source) and kind=="SPELL_CAST_START" and spell==72762 then
        q.pauseUntil=GetTime()+3;
    elseif kind=="UNIT_DIED" then
        if IsBoss(dest) then q.deadline=0; end
        if q.seen[dest] then q.seen[dest].done=true; end
    elseif (kind=="RANGE_DAMAGE" or kind=="SPELL_DAMAGE" or kind=="SWING_DAMAGE") and q.seen[dest] then
        local h=q.seen[dest].hunters[sourceName];
        if h and not h.confirmed then
            h.confirmed=true;state.AddLog("damage-confirmed",sourceName,dest);
            Message(sourceName..": урон по "..q.seen[dest].label.." подтверждён.");
        end
    end
end

function state.AddTick()
    local q=state.adds;
    if not q then return; end
    local now=GetTime();
    if not Enabled() or not GroupInCombat() or now>=q.deadline then
        state.AddLog("end",nil,"окно добивания завершено");state.adds=nil;return;
    end
    local blocked=now<(q.pauseUntil or 0) or next(state.sphereHunters or {})~=nil;
    local chosen,chosenUnit,rank;
    for _,unit in ipairs(SeenUnits()) do
        local guid=UnitGUID(unit);local id=NpcId(guid);
        if id and UnitExists(unit) and not UnitIsDeadOrGhost(unit) and UnitCanAttack("player",unit)
            and (UnitHealth(unit) or 0)>0 then
            if sphereIds[id] then blocked=true;
            elseif valkIds[id] then
                local _,_,difficulty=GetInstanceInfo();
                local max=UnitHealthMax(unit) or 0;
                local seen=state.valk and state.valk.seen[guid];
                if not (seen and seen.done) and not ((difficulty==3 or difficulty==4)
                    and max>0 and UnitHealth(unit)/max<=0.5) then blocked=true; end
            elseif id==37698 or id==36701 then
                local entry=q.seen[guid];
                if not entry and q.count<20 then
                    entry={deadline=now+60,hunters={},label=id==37698 and "шаркающему ужасу" or "гневному духу"};
                    q.seen[guid]=entry;q.count=q.count+1;
                end
                if entry and not entry.done and now<entry.deadline then
                    -- Keep the current target within its type, like Saurfang.
                    local score=(id==37698 and 0 or 1000000000)
                        +(guid==q.current and 0 or 100000000)+(UnitHealth(unit) or 0);
                    if not rank or score<rank or (score==rank and guid<chosen) then
                        chosen=guid;chosenUnit=unit;rank=score;
                    end
                elseif entry and not entry.done then
                    entry.done=true;state.AddLog("timeout",nil,guid);
                    Message("Истёк лимит добивания: "..entry.label..". Дальнейшие цели выбирает ICC.");
                end
            end
        end
    end
    if state.valk and state.valk.current then blocked=true; end
    if blocked or chosen~=q.current then
        -- Sphere/Valkyr commands can change RTI between our two group orders.
        for _,entry in pairs(q.seen) do entry.pendingIcon=nil; end
    end
    if blocked then return; end
    local changed=chosen~=q.current;
    q.current=chosen;
    if not chosen then return; end
    local entry=q.seen[chosen];
    if changed then
        entry.nextAt=now;
        Message("Общий фокус ДД по "..entry.label.."; держим одну цель до её смерти.");
    end
    if entry.refused or now<(entry.nextAt or 0) or now<state.nextSend then return; end
    if (entry.attacks or 0)>=6 or (entry.orders or 0)>=18 then
        if not entry.limitWarned then
            entry.limitWarned=true;state.AddLog("retry-limit",nil,chosen);
            Message("Лимит общих приказов по адду исчерпан; дальнейших повторов нет.");
        end
        return;
    end
    if UnitGUID(chosenUnit)~=chosen then return; end
    local icon=GetRaidTargetIndex(chosenUnit);
    -- SetRaidTarget is the same 3.3.5 API used by the live Saurfang controller.
    if icon~=8 and SetRaidTarget and not entry.markFailed and (entry.markAttempts or 0)<3
        and now>=(entry.nextMarkAt or 0) then
        entry.markAttempts=(entry.markAttempts or 0)+1;entry.nextMarkAt=now+1;
        local ok=pcall(SetRaidTarget,chosenUnit,8);
        if not ok then entry.markFailed=true; end
        entry.pendingIcon=nil;state.nextSend=now+0.15;return;
    end
    local command;
    if icons[icon] then
        if entry.pendingIcon==icon then
            command="@dps attack rti target";entry.pendingIcon=nil;
            entry.attacks=(entry.attacks or 0)+1;entry.nextAt=now+0.9;
        else
            command="@dps rti "..icons[icon];entry.pendingIcon=icon;entry.nextAt=now+0.25;
        end
    elseif UnitGUID("target")==chosen then
        command="@dps attack";entry.pendingIcon=nil;
        entry.attacks=(entry.attacks or 0)+1;entry.nextAt=now+0.9;
    elseif not entry.warned then
        entry.warned=true;Message("Не удалось поставить метку на адда: выдели его текущей целью.");
    end
    if command then
        if not state.AddBroadcast(command) then
            entry.refused=true;state.AddLog("refused",nil,"нет канала группы");return;
        end
        entry.orders=(entry.orders or 0)+1;state.nextSend=now+0.15;
        state.AddLog("command",Config().rogueBossFocus and "hunters" or "@dps",command.." "..chosen);
        for _,name in ipairs(Members()) do
            entry.hunters[name]=entry.hunters[name] or {};
            entry.hunters[name].sentAt=now;
        end
    end
end

local function Tick()
    local now = GetTime();
    if state.loginAt and now >= state.loginAt then
        state.loginAt = nil;
        if next(Config().restore) then Restore("Восстановление после загрузки"); end
    end
    if state.active then
        if not Enabled() then Restore("Автостратегия пресета отключена");
        elseif now >= state.deadline then Restore("Таймаут перехода 75с");
        elseif not GroupInCombat() then Restore("Группа вышла из боя"); end
    end
    if state.active and state.summaryAt and now >= state.summaryAt then
        state.summaryAt = nil;
        local all, confirmed = 0, 0;
        for _, bot in pairs(state.run.bots) do all = all + 1; if bot.confirmed then confirmed = confirmed + 1; end end
        Message("Профиль перехода подтверждён: "..confirmed.."/"..all..". Сферы — приоритет дальнего ДД; духов держит танк.");
    end
    for name, job in pairs(state.jobs) do
        if job.waitUntil and now >= job.waitUntil then
            Log("timeout", name, job.stage);
            local label = job.stage == "snapshot" and "проверку исходных стратегий"
                or (job.stage == "restore_verify" and "проверку восстановления" or "проверку перехода");
            Message(name..": нет ответа на "..label.."; автоматических повторов нет.");
            state.jobs[name] = nil;
        elseif job.command and now >= job.due and now >= state.nextSend then
            if not UnitFor(name, job.stage ~= "restore_send" and job.stage ~= "restore_verify") then
                Log("unavailable", name, job.stage);
                state.jobs[name] = nil;
            else
                local command = job.command;
                job.command = nil;
                state.nextSend = now + 0.15;
                if job.stage == "apply_send" or job.stage == "restore_send" then
                    job.stage = job.stage == "apply_send" and "verify" or "restore_verify";
                    job.command = "co ?";
                    job.due = now + 0.6;
                    -- Accept explicit rejection, but not an unsolicited strategy echo.
                    job.waitUntil = nil;
                else
                    job.waitUntil = now + 4;
                end
                Log("command", name, command);
                SendChatMessage(command, "WHISPER", nil, name);
                break
            end
        end
    end
    if not state.active and state.recoverUntil and now >= state.recoverUntil then
        state.jobs = {};
        state.recoverUntil = nil;
        if next(Config().restore) then
            Message("Восстановление не завершено для всех. Исходные значения сохранены; /ublk restore после возвращения ботов.");
        else
            Message("Исходные стратегии восстановлены и подтверждены.");
        end
    end
end

frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
frame:RegisterEvent("CHAT_MSG_WHISPER");
frame:RegisterEvent("PLAYER_ENTERING_WORLD");
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then state.loginAt = GetTime() + 2; return; end
    if event == "CHAT_MSG_WHISPER" then
        local text, sender = ...;
        state.RogueReply(text,sender);
        local adds=state.adds;
        local helper=adds and adds.current and adds.seen[adds.current].hunters[sender];
        if helper and helper.sentAt and GetTime()-helper.sentAt<=4 then
            local low=string.lower(tostring(text or ""));
            if low:find("cannot",1,true) or low:find("unknown",1,true) or low:find("invalid",1,true)
                or low:find("no target",1,true) or low:find("not in my sight",1,true)
                or low:find("no items",1,true) then
                helper.blocked=true;adds.seen[adds.current].refused=true;
                state.AddLog("refused",sender,string.sub(text,1,500));
                Message(sender..": отказ при добивании адда; общие повторы по этой цели прекращены.");
            end
        end
        local q=state.spheres;
        local h=q and q.lastGuid and q.seen[q.lastGuid] and q.seen[q.lastGuid].hunters[sender];
        if h and h.sentAt and GetTime()-h.sentAt<=4 then
            local low=string.lower(tostring(text or ""));
            if low:find("cannot",1,true) or low:find("unknown",1,true) or low:find("invalid",1,true)
                or low:find("no target",1,true) or low:find("not in my sight",1,true) then
                h.blocked=true;SphereLog("refused",sender,string.sub(text,1,500));
                Message(sender..": отказ при атаке сферы; повторы для этой сферы прекращены.");
            end
        end
        local v=state.valk;
        local h=v and v.helpers[sender];
        if h and h.sentAt and GetTime()-h.sentAt <= 4 then
            local low=string.lower(tostring(text or ""));
            if low:find("cannot",1,true) or low:find("unknown",1,true) or low:find("invalid",1,true)
                or low:find("no target",1,true) or low:find("not in my sight",1,true) then
                v.blocked[sender]=true;
                ValkLog("refused", sender, string.sub(text,1,500));
                Message(sender..": отказ при фокусе валь'киры, повторы прекращены.");
            end
        end
        Reply(...); return;
    end
    local _, kind, source, sourceName, sourceFlags, dest, destName, destFlags, spell = ...;
    SphereEvent(kind, source, dest, spell, sourceName);
    ValkEvent(kind, source, dest, spell, sourceName);
    state.AddEvent(kind, source, dest, spell, sourceName);
    if IsBoss(source) then
        if (kind == "SPELL_CAST_START" or kind == "SPELL_AURA_APPLIED") and winter[spell] then
            Start(source);
        elseif state.active and source == state.boss and kind == "SPELL_CAST_START" and spell == 72262 then
            Message("Сотрясение — немедленно внутрь платформы!");
            Restore("Сотрясение");
        end
    elseif state.active and kind == "UNIT_DIED" and dest == state.boss then
        Restore("Босс погиб");
    end
    if not state.active then return; end
    if kind == "UNIT_DIED" and (state.run.bots[destName] or destName == UnitName("player")) then
        Log("death", destName, dest);
    elseif kind == "SPELL_DAMAGE" or kind == "SPELL_PERIODIC_DAMAGE" or kind == "SWING_DAMAGE" then
        if state.run.bots[sourceName] then
            -- Bounded aggregate by bot and NPC id; no NPC GUID/name growth.
            local npc = type(dest) == "string" and tonumber(string.sub(dest, 7, 12), 16);
            if npc then
                local key = sourceName..":"..npc;
                local amount = tonumber((select(kind == "SWING_DAMAGE" and 9 or 12, ...))) or 0;
                if state.run.damage[key] or (state.damageKeys or 0) < 80 then
                    if not state.run.damage[key] then state.damageKeys = (state.damageKeys or 0) + 1; end
                    state.run.damage[key] = (state.run.damage[key] or 0) + amount;
                end
            end
        end
    end
end);
frame:SetScript("OnUpdate", function(self, elapsed)
    state.elapsed = (state.elapsed or 0) + elapsed;
    if state.elapsed < 0.15 then return; end
    state.elapsed = 0;
    if state.active or next(state.jobs) or state.loginAt or state.recoverUntil then Tick(); end
    SphereTick();
    ValkTick();
    state.AddTick();
    state.RogueTick();
end);

SLASH_UNBOTLICHKING1 = "/ublk";
SlashCmdList.UNBOTLICHKING = function(text)
    text = string.lower(tostring(text or "")):match("^%s*(.-)%s*$");
    if text == "rogues" then state.RogueSetup();
    elseif text == "rogues off" then Config().rogueBossFocus=false;state.rogues=nil;Message("Отдельный фокус рог выключен.");
    elseif text == "valk off" then Config().valkyrEnabled=false; ValkStop("выключено вручную"); Message("Автофокус валь'кир выключен.");
    elseif text == "valk on" then Config().valkyrEnabled=true; Message("Автофокус валь'кир включён.");
    elseif text == "off" then Config().enabled = false; ValkStop("контроллер выключен"); Restore("Контроллер выключен"); Message("Контроллер Лича выключен.");
    elseif text == "on" then Config().enabled = true; Message("Контроллер Лича включён: переход и общий фокус валь'кир.");
    elseif text == "restore" then Restore("Ручное восстановление");
    elseif text == "" or text == "status" then Status();
    else Message("/ublk on | off | status | restore | valk on | valk off"); end
end;

-- Plague warning lives in this existing TOC entry so /reload can load it.
do
-- Presentation only: no movement, dispel or bot commands.
UnBotLichPlague = {};
local P = UnBotLichPlague;
local ids = {[70337]=true,[73912]=true,[73913]=true,[73914]=true,
    [70338]=true,[73785]=true,[73786]=true,[73787]=true};
local panel = CreateFrame("Frame", "UnBotLichPlaguePanel", UIParent);
panel:SetWidth(520);
panel:SetHeight(150);
panel:SetPoint("CENTER", UIParent, "CENTER", 0, 180);
panel:SetFrameStrata("HIGH");
panel:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background"});
panel.text = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
panel.text:SetPoint("TOPLEFT", 12, -12);
panel.text:SetPoint("BOTTOMRIGHT", -12, 12);
panel.text:SetJustifyH("CENTER");
panel:Hide();
P.panel = panel;

function P.Radar(active)
    local r=DBM and DBM.RangeCheck;
    if not r or not DBM.Options then return end
    if not P.hooked and hooksecurefunc then
        hooksecurefunc(r,"Show",function(...)
            if not P.radarChanging then P.lastRadar={...};P.radarOwned=nil; end
        end);
        hooksecurefunc(r,"Hide",function()
            if not P.radarChanging then P.lastRadar=nil;P.radarOwned=nil; end
        end);
        P.hooked=true;
    end
    if active and not P.radarActive then
        P.radarActive=true;
        -- Do not overwrite a pre-existing window whose settings are unknown.
        if r:IsShown() and not P.lastRadar then return end
        P.previousRadar=r:IsShown() and P.lastRadar or nil;
        P.radarChanging=true;
        local old=DBM.Options.RangeFrameFrames;
        DBM.Options.RangeFrameFrames="radar";
        local ok=pcall(r.Show,r,10);
        DBM.Options.RangeFrameFrames=old;
        P.radarChanging=nil;P.radarOwned=ok;
    elseif not active and P.radarActive then
        P.radarActive=nil;
        if P.radarOwned then
            P.radarChanging=true;
            if P.previousRadar then pcall(r.Show,unpack(P.previousRadar));
            else pcall(r.Hide,r); end
            P.radarChanging=nil;
        end
        P.radarOwned=nil;P.previousRadar=nil;
    end
end

function P.Units()
    local units = {"player"};
    local raid = GetNumRaidMembers() or 0;
    for i=1,math.min(raid>0 and raid or (GetNumPartyMembers() or 0),40) do
        local unit = (raid>0 and "raid" or "party")..i;
        if UnitExists(unit) and not UnitIsUnit(unit,"player") then units[#units+1]=unit; end
    end
    return units;
end

function P.Disease(unit)
    if not UnitIsConnected(unit) or UnitIsDeadOrGhost(unit) then return end
    for i=1,40 do
        local name,_,_,stacks,_,_,expires,_,_,_,id = UnitDebuff(unit,i);
        if not name then break end
        if ids[id] then return stacks or 1,expires end
    end
end

function P.Distance(a,b)
    -- Missing map coordinates must never become a false "clear" result.
    if not DBM or not DBM.GetMapSize or not GetPlayerMapPosition then return end
    if DBM.HasMapRestrictions and DBM:HasMapRestrictions() then return end
    local ax,ay=GetPlayerMapPosition(a);
    local bx,by=GetPlayerMapPosition(b);
    if not ax or not ay or not bx or not by or (ax==0 and ay==0) or (bx==0 and by==0) then return end
    local ok,w,h=pcall(DBM.GetMapSize,DBM);
    if not ok or type(w)~="number" or type(h)~="number" or w<=0 or h<=0 then return end
    return math.sqrt(((ax-bx)*w)^2+((ay-by)*h)^2);
end

function P.Nearby(carrier,units)
    local near,unknown={},0;
    for _,unit in ipairs(units) do
        if not UnitIsUnit(unit,carrier) and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) then
            local distance=P.Distance(carrier,unit);
            if not distance then unknown=unknown+1;
            elseif distance<=10 then near[#near+1]=UnitName(unit) or "?"; end
        end
    end
    local text=#near>0 and ("|cffff5555В пределах 10 ярдов: "..table.concat(near,", ").."|r")
        or "|cffffff00Союзников в пределах 10 ярдов не обнаружено.|r";
    if unknown>0 then text=text.."\n|cffffaa00Дистанция неизвестна для союзников: "..unknown..".|r"; end
    return text;
end

function P.Update()
    if Config().plagueEnabled == false then
        P.testUntil=nil;P.carrier=nil;panel:Hide();P.Radar(false);return;
    end
    local testing=P.testUntil and GetTime()<P.testUntil;
    local units=P.Units();
    local carriers,chosen,stacks={},nil,nil;
    for _,unit in ipairs(units) do
        local count=P.Disease(unit);
        if count then
            carriers[#carriers+1]=UnitName(unit) or "?";
            if not chosen then chosen=unit;stacks=count; end
        end
    end
    if testing then chosen="player";stacks=1;carriers={"ТЕСТ"}; end
    P.Radar(chosen~=nil);
    if not chosen then panel:Hide();P.carrier=nil;return end
    local mine=UnitIsUnit(chosen,"player");
    local title=mine and "ЧУМА НА ТЕБЕ — отойди от союзников!" or ("ЧУМА: "..table.concat(carriers,", "));
    local key=UnitGUID(chosen);
    if key~=P.carrier then
        P.carrier=key;
        if PlaySound then PlaySound("RaidWarning") end
        if UnBotCombatChat then UnBotCombatChat.Write("|cffff5555Лич: "..title.."|r") end
    end
    panel.text:SetText("|cffff5555"..title.."|r\nЗаряды: "..stacks..". Радиус вокруг: "..(UnitName(chosen) or "?")
        .."\n"..P.Nearby(chosen,units).."\nРадар DBM — вокруг ТЕБЯ, 10 ярдов.\nПроверь аддов и питомцев перед Очищением.");
    panel:Show();
end

function P.SetEnabled(enabled)
    Config().plagueEnabled=enabled and true or false;
    P.testUntil=nil;
    P.Update();
    if UnBotBossPresetCatalogRefresh then UnBotBossPresetCatalogRefresh(); end
    Message("Предупреждение о чуме "..(Config().plagueEnabled and "включено." or "выключено."));
end

local driver=CreateFrame("Frame");
driver:SetScript("OnUpdate",function(self,elapsed)
    P.elapsed=(P.elapsed or 0)+elapsed;
    if P.elapsed<0.2 then return end
    P.elapsed=0;
    P.Update();
end);
SLASH_UNBOTPLAGUE1="/ubplague";
SlashCmdList.UNBOTPLAGUE=function(text)
    text=string.lower(tostring(text or "")):match("^%s*(.-)%s*$");
    if text == "off" or text == "on" then
        P.SetEnabled(text == "on");
    elseif text == "status" then
        Message("Предупреждение о чуме "..(Config().plagueEnabled ~= false and "включено." or "выключено."));
    elseif text == "" or text == "test" then
        if Config().plagueEnabled == false then
            Message("Предупреждение о чуме выключено. Включить: /ubplague on.");return;
        end
        P.testUntil=GetTime()+8;P.Update();
    else
        Message("/ubplague off — выключить; on — включить; status — состояние; test — тест на 8 секунд.");
    end
end;

end


function state.IsBossRogue(name)
    if not Config().rogueBossFocus then return false end
    local unit=UnitFor(name,true);
    if not unit then return false end
    local _,class=UnitClass(unit);
    return Config().rogueBossFocus and class=="ROGUE";
end

function state.RogueSetup()
    if InCombatLockdown() then Message("Менять состав можно только вне боя.");return end
    local loaded=UnBotSquadBuilder and UnBotSquadBuilder.loadedBossPreset;
    if not loaded or loaded.bossKey~="the_lich_king" then
        local _,instance,difficulty=GetInstanceInfo();
        local modes={[1]="10n",[2]="25n",[3]="10h",[4]="25h"};
        local mode=instance=="raid" and modes[difficulty];
        if not mode then Message("Вне рейда выбери ЦЛК -> Король-лич -> нужную сложность; обычный пресет 1–5 не содержит привязки к боссу.");return end
        if UnBotBossPresetLoad then UnBotBossPresetLoad("the_lich_king",mode,false);end
        loaded=UnBotSquadBuilder and UnBotSquadBuilder.loadedBossPreset;
        if not loaded or loaded.bossKey~="the_lich_king" then Message("Не удалось загрузить пресет Лича. Открой ЦЛК -> Король-лич в сборщике.");return end
        Message("Загружен пресет Лича "..mode.."; применяю состав 2 ханта + 1 рога.");
    end
    local slots,hunterAdded={},nil;
    for _,slot in ipairs(UnBotSquadConfig.slots or {}) do
        if slot.reserveOnly or (slot.className~="rogue" and slot.className~="hunter") then
            local copy={};for k,v in pairs(slot) do copy[k]=v;end;slots[#slots+1]=copy;
        elseif slot.className=="hunter" and not hunterAdded then
            local copy={};for k,v in pairs(slot) do copy[k]=v;end;
            copy.count=2;slots[#slots+1]=copy;hunterAdded=true;
        end
    end
    if not hunterAdded then slots[#slots+1]={className="hunter",specKey="mm",label="Hunter - Marksmanship (DPS)",count=2};end
    slots[#slots+1]={className="rogue",specKey="combat",label="Rogue - Combat (DPS)",count=1};
    local total=0;for _,slot in ipairs(slots) do total=total+(tonumber(slot.count) or 0);end
    if total>39 then Message("Недостаточно мест для состава 2 ханта + 1 рога.");return end
    UnBotSquadBuilderSetSlots(slots);Config().rogueBossFocus=true;
    if UnBotSquadBuilderRefresh then UnBotSquadBuilderRefresh();end
    Message("Состав: 2 ханта + 1 Combat Rogue. Нажми сбор состава. Рога — Лич; ханты — механики. Сохранённый пресет не перезаписан.");
end

function state.RogueReply(text,sender)
    local h=state.rogues and state.rogues.bots[sender];
    if not h or not h.sentAt or GetTime()-h.sentAt>4 then return end
    local low=string.lower(tostring(text or ""));
    if low:find("cannot",1,true) or low:find("unknown",1,true) or low:find("invalid",1,true)
        or low:find("no target",1,true) or low:find("not in my sight",1,true) then
        h.refused=true;Message(sender..": отказ фокуса Лича, повторы прекращены.");
    end
end

function state.RogueTick()
    if not Config().rogueBossFocus or not Enabled() or not GroupInCombat() then state.rogues=nil;return end
    if state.active or GetTime()<state.nextSend then return end
    local unit;
    for _,candidate in ipairs(SeenUnits()) do
        if IsBoss(UnitGUID(candidate)) and UnitCanAttack("player",candidate) and not UnitIsDeadOrGhost(candidate) then unit=candidate;break end
    end
    if not unit then return end
    state.rogues=state.rogues or {deadline=GetTime()+900,bots={}};
    if GetTime()>state.rogues.deadline then return end
    for _,name in ipairs(Members()) do
        if state.IsBossRogue(name) then
            local bot=UnitFor(name,true);
            local h=state.rogues.bots[name] or {attempts=0,nextAt=0};state.rogues.bots[name]=h;
            if not h.refused and h.attempts<12 and GetTime()>=h.nextAt
                and not (UnitInVehicle and UnitInVehicle(bot))
                and UnitGUID(bot.."target")~=UnitGUID(unit) then
                local icon=GetRaidTargetIndex(unit);
                local command;
                if UnitGUID("target")==UnitGUID(unit) then command="attack";
                elseif icons[icon] then
                    if h.icon==icon then command="attack rti target";h.icon=nil;
                    else command="rti "..icons[icon];h.icon=icon; end
                end
                if command then
                    h.attempts=h.attempts+1;h.nextAt=GetTime()+(command:find("^rti ") and 0.25 or 10);
                    h.sentAt=GetTime();state.nextSend=GetTime()+0.15;
                    SendChatMessage(command,"WHISPER",nil,name);return;
                end
            end
        end
    end
end

function state.AddBroadcast(command)
    if not Config().rogueBossFocus then return UnBotSindragosaBroadcast and UnBotSindragosaBroadcast(command); end
    local sent=0;
    for _,name in ipairs(Members()) do
        local unit=UnitFor(name,true);
        local _,class=UnitClass(unit);
        if class=="HUNTER" and not (UnitInVehicle and UnitInVehicle(unit)) then
            SendChatMessage(command:gsub("^@dps ",""),"WHISPER",nil,name);sent=sent+1;
        end
    end
    return sent>0;
end
