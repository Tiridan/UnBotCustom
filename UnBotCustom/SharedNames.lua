-- Private name/class union. Levels, specs, history and settings stay local.
UnBotSharedNames = {};
local N=UnBotSharedNames;
N.prefix="UBNAMES4";N.jobs={};N.peers={};N.serial=0;N.revision=0;
N.channel="UnBotRegistry335";N.presenceSeen={};N.online={};N.peerAccounts={};
N.accounts={};
-- Private account bindings are excluded from the public snapshot.
N.characters={};
N.classes={warrior=true,paladin=true,hunter=true,rogue=true,priest=true,shaman=true,mage=true,warlock=true,druid=true,dk=true};
function N.Class(value) return type(value)=="string" and N.classes[value] and value or nil;end
N.lower={};N.upper={};
do
 local upper="АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ";
 local lower="абвгдеёжзийклмнопрстуфхцчшщъыьэюя";
 for i=1,#upper,2 do N.lower[upper:sub(i,i+1)]=lower:sub(i,i+1);N.upper[lower:sub(i,i+1)]=upper:sub(i,i+1);end
end
function N.Name(name)
 if name==UNKNOWN or name==UNKNOWNOBJECT or name=="UNKNOWN" or name=="UNKNOWNOBJECT" then return;end
 -- Lua byte classes depend on locale; UTF-8 continuation bytes are not spaces.
 if type(name)~="string" or name=="" or #name>48 or name:find("[%z\1-\32\127,|;:%%\\\"]") then return;end
 name=name:gsub("[A-Z]",string.lower):gsub("[\208\209][\128-\191]",N.lower);
 local first,rest=name:match("^(.[\128-\191]*)(.*)$");
 return first and ((N.upper[first] or first:gsub("[a-z]",string.upper))..rest) or nil;
end
function N.Realm() return tostring(GetRealmName() or ""):gsub("^%s+",""):gsub("%s+$",""):lower();end
function N.AccountSlot(account)
 for i,value in ipairs(N.accounts) do if value==account then return i;end end
end
function N.Account(name) return N.peerAccounts[N.Name(name) or ""];end
function N.ClientAccount()
 if not GetCVar then return "";end
 local ok,value=pcall(GetCVar,"accountName");
 return ok and tostring(value or ""):match("^%s*(.-)%s*$"):upper() or "";
end
function N.SaveLocalAccount(account,source)
 if not N.AccountSlot(account) then return;end
 UnBotSquadConfig=UnBotSquadConfig or {};
 local saved=UnBotSquadConfig.sharedNamesLocalAccount;
 if type(saved)~="table" then saved={};UnBotSquadConfig.sharedNamesLocalAccount=saved;end
 saved.account=account;saved.source=source;saved.schema=1;N.accountSource=source;
 return account;
end
function N.Enabled()
 local account=N.ClientAccount();
 if account~="" then
  if N.AccountSlot(account) then return N.SaveLocalAccount(account,"client");end
  N.accountSource="unsupported-client";return;
 end
 local saved=UnBotSquadConfig and UnBotSquadConfig.sharedNamesLocalAccount;
 if type(saved)=="table" and N.AccountSlot(saved.account) then N.accountSource="saved";return saved.account;end
 -- One-time migration on an already known character; all future characters use the account setting.
 local player=N.Name(UnitName("player"));
 for candidate,names in pairs(N.characters[N.Realm()] or {}) do
  for _,name in ipairs(names) do if name==player then return N.SaveLocalAccount(candidate,"bootstrap");end end
 end
 N.accountSource="unset";
end
-- This is transport self-identification, not server-verified ownership or alt control rights.
function N.RememberPlayer(name,account)
 local context=UnBotRegistryCurrentContext();name=N.Name(name);
 if not name or not N.AccountSlot(account) or context:find("unknown",1,true) then return;end
 local config=UnBotSquadConfig;
 config.sharedNamesPlayersByContext=config.sharedNamesPlayersByContext or {};
 config.sharedNamesPlayersByContext[context]=config.sharedNamesPlayersByContext[context] or {};
 config.sharedNamesPlayersByContext[context][name]=account;
 if N.bucket and N.bucket[name] then N.bucket[name]=nil;N.MarkDirty();end
end
function N.Protected(name)
 name=N.Name(name);if not name then return false;end
 if name==N.Name(UnitName("player")) then return true;end
 local contexts=UnBotSquadConfig and UnBotSquadConfig.sharedNamesPlayersByContext;
 local known=contexts and UnBotRegistryCurrentContext and contexts[UnBotRegistryCurrentContext()];
 if known and known[name] then return true;end
 for _,accounts in pairs(N.characters) do for _,chars in pairs(accounts) do for _,character in ipairs(chars) do
  if name==character then return true;end
 end end end
 local bots=UnBotBotRegistry and UnBotBotRegistry.bots;
 local actual=N.profileNames and N.profileNames[name] or name;
 local p=bots and (bots[actual] or bots[name]);
 return p and ((UnBotIsAccountAltProfile and UnBotIsAccountAltProfile(name,p)) or p.accountAlt or p.protectedAccountCharacter);
end
function N.Message(text)
 if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99UnBot|r: Общие имена: "..text);end
end
function N.Wake()
 N.frame:SetScript("OnUpdate",function(_,elapsed)
  N.elapsed=(N.elapsed or 0)+elapsed;if N.elapsed>=.1 then N.elapsed=0;N.Tick();end
 end);
end
function N.MarkDirty()
 N.revision=N.revision+1;N.dirtyAt=N.dirtyAt or (GetTime()+2);N.Wake();
end
function N.Learn(name,className)
 name=N.Name(name);if not name or N.Protected(name) or not N.bucket then return false;end
 local previous=N.bucket[name];local added=not previous;
 UnBotKnownBots[name]=true;
 local actual=N.profileNames[name] or name;
 if not UnBotBotRegistry.bots[actual] then
  UnBotBotRegistry.bots[name]={name=name,sharedNameOnly=true};N.profileNames[name]=name;
 end
 local profile=UnBotBotRegistry.bots[actual];className=N.Class(className);
 if className and (not profile.className or profile.className=="") then profile.className=className;end
 local known=N.Class(profile.className);
 if known then profile.sharedNameOnly=nil;end
 N.bucket[name]=known or true;
 return added,known and previous~=known or false;
end
function N.Attach()
 if not N.ready or not N.Enabled() or not UnBotRegistryCurrentContext or not UnBotBotRegistry or not UnBotBotRegistry.bots then return;end
 local context=UnBotRegistryCurrentContext();
 if context:find("unknown",1,true) then return;end
 UnBotSquadConfig.sharedNamesByContext=UnBotSquadConfig.sharedNamesByContext or {};
 local saved=UnBotSquadConfig.sharedNamesByContext[context] or {};
 N.context=context;N.bucket={};N.profileNames={};
 N.RememberPlayer(UnitName("player"),N.Enabled());
 for name in pairs(UnBotBotRegistry.bots) do local key=N.Name(name);if key then N.profileNames[key]=name;end end
 for name,value in pairs(saved) do if value then N.Learn(name,N.Class(value));end end
 if not UnBotPublicRegistrySeed or not UnBotPublicRegistry or UnBotPublicRegistry.Server()==UnBotPublicRegistrySeed.serverKey then
  for _,name in ipairs((UnBotSharedNamesSeed or {})[context] or {}) do N.Learn(name);end
 end
 for name in pairs(UnBotBotRegistry.bots) do N.Learn(name);end
 for name in pairs(UnBotKnownBots or {}) do N.Learn(name);end
 UnBotSquadConfig.sharedNamesByContext[context]=N.bucket;
end
function N.Found(name)
 if not N.ready or not N.Enabled() then return;end
 if N.context~=UnBotRegistryCurrentContext() or not N.bucket then N.Attach();end
 local added,classChanged=N.Learn(name);
 if added or classChanged then N.MarkDirty();end
end
function N.List()
 local names={};for name in pairs(N.bucket or {}) do if not N.Protected(name) then names[#names+1]=name;end end
 table.sort(names);return names;
end
function N.Records(names)
 local records={};
 for _,name in ipairs(names) do
  local className=N.Class(N.bucket[name]);records[#records+1]=name..(className and (":"..className) or "");
 end
 table.sort(records);return records;
end
function N.Hash(names)
 local h=1;for _,name in ipairs(names) do for i=1,#name do h=(h*31+name:byte(i))%2147483647;end;h=(h*31+44)%2147483647;end
 return tostring(h);
end
function N.Pack(names)
 local pages,line={},"";
 for _,name in ipairs(names) do
  if #line+#name+1>140 then pages[#pages+1]=line;line="";end
  line=line..(line=="" and "" or ",")..name;
 end
 if line~="" or #pages==0 then pages[#pages+1]=line;end
 return pages;
end
function N.Fields(text)
 local fields={};for field in (text.."\t"):gmatch("(.-)\t") do fields[#fields+1]=field;end;return fields;
end
function N.Send(peer,text)
 if #N.prefix+#text>254 then error("UnBot shared-name packet exceeds the WoW 3.3.5 limit");end
 SendAddonMessage(N.prefix,text,"WHISPER",peer);
end
function N.NewJob(peer,token,welcomed)
 local names=N.List();if #names>10000 then N.Message("слишком большой список; обмен не начат");return;end
 local records=N.Records(names);
 local job={peer=peer,token=token,context=N.context,revision=N.revision,names=names,pages=N.Pack(records),hash=N.Hash(records),
  welcomed=welcomed,deadline=GetTime()+12,index=1,acks={},received={},attempts=0};
 if welcomed then job.deadline=GetTime()+math.max(45,#job.pages*2+20);end
 N.jobs[peer]=job;if N.peers[peer] then N.peers[peer].sentRevision=job.revision;end;N.Wake();return job;
end
function N.StartPeer(peer)
 if not N.online[peer] or GetTime()-N.online[peer]>10 then return false;end
 local existing=N.jobs[peer];if existing and not existing.done and not existing.failed then return false;end
 N.serial=N.serial+1;
 local index=N.AccountSlot(N.Enabled());
 N.NewJob(peer,index.."-"..time().."-"..N.serial,false);return true;
end
-- Channel names and ordinary chat whitespace may be normalized in transit.
function N.ChannelMatches(name,index,display)
 local actual=tostring(name or display or ""):gsub("^%d+%.%s*",""):lower();
 if actual~="" then return actual==N.channel:lower();end
 local own=GetChannelName and GetChannelName(N.channel) or 0;
 return own>0 and tonumber(index)==own;
end
function N.Presence(message,sender,channelName,index,display)
 if not N.ChannelMatches(channelName,index,display) or not N.ready or not N.Enabled()
  or type(message)~="string" or #message>160 or not message:match("^UBREG4[:%s]") then return;end
 N.presenceReceived=(N.presenceReceived or 0)+1;
 local kind,context,token,slot=message:match("^UBREG4[:%s]+([HP])[:%s]+(%d+)[:%s]+([%d%-]+)[:%s]+(%d+)$");
 if not kind or not token or #token>48 or not token:match("^%d+%-%d+%-%d+$") then N.presenceReject="формат объявления";return;end
 if context~=N.Hash({(UnBotRegistryCurrentContext())}) then N.presenceReject="другой мир/фракция";return;end
 sender=N.Name(sender);local account=N.accounts[tonumber(slot) or 0];
 if not sender or not account then N.presenceReject="некорректный участник обмена";return;end
 if sender==N.Name(UnitName("player")) then
  if token==N.lastPresenceToken then N.presenceEcho=(N.presenceEcho or 0)+1;end
  return;
 end
 if account==N.Enabled() or (N.peerAccounts[sender] and N.peerAccounts[sender]~=account) then
  N.presenceReject="отправитель не входит в обмен или сменил аккаунт";return;
 end
 if kind=="P" and (not N.discovery or N.discovery.token~=token or GetTime()>=N.discovery.deadline) then
  N.presenceReject="устаревший ответ";return;
 end
 if N.context~=UnBotRegistryCurrentContext() or not N.bucket then N.Attach();end
 local key=kind..":"..token;
 if N.presenceSeen[sender]==key then return;end
 N.presenceSeen[sender]=key;N.online[sender]=GetTime();N.peerAccounts[sender]=account;
 N.RememberPlayer(sender,account);N.presenceAccepted=(N.presenceAccepted or 0)+1;
 if kind=="H" then
  local id=GetChannelName and GetChannelName(N.channel) or 0;
  if id>0 then N.SendPresence("P",token,id);end
 end
 N.StartPeer(sender);
end
function N.SendPresence(kind,token,id)
 N.presenceSent=(N.presenceSent or 0)+1;
 if kind=="H" then N.lastPresenceToken=token;end
 local ok,reason=pcall(SendChatMessage,"UBREG4:"..kind..":"..N.Hash({N.context})..":"..token..":"..N.AccountSlot(N.Enabled()),"CHANNEL",nil,id);
 if not ok then N.presenceReject="ошибка отправки";end
 return ok;
end
function N.Debug()
 local id=GetChannelName and GetChannelName(N.channel) or 0;
 local jobs,failed=0,0;local last;
 for _,job in pairs(N.jobs) do
  if job.failed then failed=failed+1;last=job.reason;elseif not job.done then jobs=jobs+1;end
 end
 return "канал №"..id.."; аккаунт №"..tostring(N.AccountSlot(N.Enabled()) or "?").." ("..tostring(N.accountSource or "?").."); отправлено "..(N.presenceSent or 0)..", эхо "..(N.presenceEcho or 0)
  ..", получено "..(N.presenceReceived or 0)..", принято "..(N.presenceAccepted or 0)
  .."; передач "..jobs..", отказов "..failed..(last and (" ("..last..")") or "")
  ..(N.presenceReject and ("; последнее отклонение: "..N.presenceReject) or "");
end
function N.DebugJobs()
 local names={};for peer in pairs(N.jobs) do names[#names+1]=peer;end;table.sort(names);
 for _,peer in ipairs(names) do
  local job=N.jobs[peer];local received=0;for _ in pairs(job.received) do received=received+1;end
  N.Message(peer..": сеанс "..job.token.."; начало "..(job.welcomed and "да" or "нет")
   .."; отправлено "..(job.index-1).."/"..#job.pages..", получено "..received.."/"..tostring(job.total or "?")
   .."; наш снимок принят "..(job.delivered and "да" or "нет")..", чужой импортирован "..(job.imported and "да" or "нет")
   .."; "..(job.reason or (job.done and "завершено" or "в работе")));
 end
end
function N.DiscoveryTick()
 local job=N.discovery;if not job then return;end
 if GetTime()>=job.deadline then
  N.discovery=nil;
  if not job.sent and N.manual then N.Message("служебный канал обмена недоступен; общая база из релиза сохранена");end
  return;
 end
 if job.sent then return;end
 local id=GetChannelName and GetChannelName(N.channel) or 0;
 if id>0 then
  job.sent=true;
  -- Do not attach the service channel to any chat window.
  if ChatFrame_RemoveChannel then for i=1,(NUM_CHAT_WINDOWS or 0) do
   local frame=_G["ChatFrame"..i];if frame then ChatFrame_RemoveChannel(frame,N.channel);end
  end end
  N.SendPresence("H",job.token,id);
 elseif not job.joined then
  job.joined=true;if JoinChannelByName then JoinChannelByName(N.channel);end
 end
end
function N.Begin(manual)
 if not N.Enabled() then return;end
 N.Attach();if not N.bucket then return;end
 if manual then N.presenceSent=0;N.presenceEcho=0;N.presenceReceived=0;N.presenceAccepted=0;N.presenceReject=nil;N.manual=true;N.receivedNew=0;N.receivedClasses=0;N.Message("объединяю имена и классы обычных ботов с запущенными клиентами; личные альты не передаются");end
 N.dirtyAt=nil;N.summaryPending=true;
 if not N.discovery then
  N.serial=N.serial+1;
  N.discovery={token=time().."-"..math.floor(GetTime()*1000).."-"..N.serial,deadline=GetTime()+8};
 end
 N.Wake();N.DiscoveryTick();
end
function N.Fail(job,reason)
 job.failed=true;job.reason=reason;job.expireAt=GetTime()+30;
 N.peers[job.peer]=nil;
end
function N.Finish(job)
 if job.done or not job.imported or not job.delivered or job.index<=#job.pages then return;end
 job.done=true;job.expireAt=GetTime()+30;N.summaryPending=true;
 N.peers[job.peer]={context=job.context,sentRevision=job.revision};
end
function N.ReceiveSnapshot(job,fields)
 local index,total,count=tonumber(fields[4]),tonumber(fields[5]),tonumber(fields[6]);local digest,payload=fields[7],fields[8];
 if not index or not total or not count or index%1~=0 or total%1~=0 or count%1~=0 or index<1 or index>total
  or total>4000 or count<0 or count>10000 or not payload or #payload>140 then return;end
 if job.total and (job.total~=total or job.count~=count or job.digest~=digest) then N.Fail(job,"снимок изменился при передаче");return;end
 if not job.welcomed then job.welcomed=true;job.deadline=GetTime()+math.max(45,#job.pages*2+total*2+20);end
 if not job.total then job.deadline=GetTime()+math.max(45,#job.pages*2+total*2+20);end
 job.total,job.count,job.digest=total,count,digest;
 if job.received[index] and job.received[index]~=payload then N.Fail(job,"различающиеся повторные пакеты");return;end
 job.received[index]=payload;
 N.Send(job.peer,"A\t"..job.token.."\t"..job.context.."\t"..index);
 if job.imported then N.Send(job.peer,"C\t"..job.token.."\t"..job.context.."\t"..job.count.."\t"..job.digest);return;end
 for i=1,total do if job.received[i]==nil then return;end end
 local names,records,classes,seen={},{},{},{};
 for i=1,total do for record in job.received[i]:gmatch("[^,]+") do
  local name,className=record:match("^([^:]+):([^:]+)$");name=name or record;
  local canonical=N.Name(name);
  if not canonical or name~=canonical or seen[name] or (className and not N.Class(className)) then
   N.Fail(job,"некорректные имена, классы или повторы в снимке");return;
  end
  seen[name]=true;names[#names+1]=name;records[#records+1]=record;classes[name]=className;
 end end
 table.sort(records);
 if #names~=count or N.Hash(records)~=digest then N.Fail(job,"неполный снимок имён и классов");return;end
 if N.context~=UnBotRegistryCurrentContext() or not N.Enabled() then N.Fail(job,"сменился персонаж или мир");return;end
 local added,classAdded=0,0;
 for _,name in ipairs(names) do
  local newName,newClass=N.Learn(name,classes[name]);
  if newName then added=added+1;end;if newClass then classAdded=classAdded+1;end
 end
 job.imported=true;N.receivedNew=(N.receivedNew or 0)+added;N.receivedClasses=(N.receivedClasses or 0)+classAdded;
 N.Send(job.peer,"C\t"..job.token.."\t"..job.context.."\t"..job.count.."\t"..job.digest);
 if added>0 or classAdded>0 then
  N.MarkDirty();
  if UnBotSpecAudit and UnBotSpecAudit.MarkDirty then UnBotSpecAudit.MarkDirty();
  elseif UnBotSpecAuditRefresh then UnBotSpecAuditRefresh();end
 end
 N.peers[job.peer]={context=job.context,sentRevision=job.revision};
 N.Finish(job);
end
-- Tokens are origin-time-serial. Compare numeric generations, not raw strings:
-- a restarted sender must supersede its abandoned partial snapshot.
function N.TokenAfter(candidate,current)
 local origin,stamp,serial=candidate:match("^(%d+)%-(%d+)%-(%d+)$");
 local oldOrigin,oldStamp,oldSerial=current:match("^(%d+)%-(%d+)%-(%d+)$");
 origin,stamp,serial=tonumber(origin),tonumber(stamp),tonumber(serial);
 oldOrigin,oldStamp,oldSerial=tonumber(oldOrigin),tonumber(oldStamp),tonumber(oldSerial);
 if not origin or not oldOrigin then return false;end
 if stamp~=oldStamp then return stamp>oldStamp;end
 if origin~=oldOrigin then return origin<oldOrigin;end
 return serial>oldSerial;
end
function N.Receive(prefix,text,channel,sender)
 if prefix~=N.prefix or channel~="WHISPER" or not N.ready or not N.Enabled() or type(text)~="string" or #text>246 then return;end
 if type(sender)~="string" or sender:find("-",1,true) then return;end
 sender=N.Name(sender);local account=N.Account(sender);
 if not account or account==N.Enabled() or not N.online[sender] then return;end
 local f=N.Fields(text);local kind,token,context=f[1],f[2],f[3];
 if not token or #token>40 or not token:match("^%d+%-%d+%-%d+$") or context~=UnBotRegistryCurrentContext() then return;end
 if N.context~=context or not N.bucket then N.Attach();end
 if not N.bucket then return;end
 local job=N.jobs[sender];
 if kind=="H" then
  if job and job.token~=token and not N.TokenAfter(token,job.token) then return;end
  if not job or job.token~=token then job=N.NewJob(sender,token,true);end
  if job and not job.failed then N.Send(sender,"W\t"..token.."\t"..context);end
  return;
 end
 if not job or job.token~=token or job.failed or job.context~=context then return;end
 if kind=="W" then
  if not job.welcomed then job.deadline=GetTime()+math.max(45,#job.pages*2+20);end
  job.welcomed=true;
 elseif kind=="S" then N.ReceiveSnapshot(job,f);
 elseif kind=="C" then
  if tonumber(f[4])==#job.names and f[5]==job.hash then job.delivered=true;N.Finish(job);end
 elseif kind=="Q" then
  if job.imported then N.Send(job.peer,"C\t"..job.token.."\t"..job.context.."\t"..job.count.."\t"..job.digest);end
 elseif kind=="A" then
  local index=tonumber(f[4]);if index and index==job.index and index<=#job.pages and job.sentAt then
   job.acks[index]=true;job.index=index+1;job.sentAt=nil;job.attempts=0;N.Finish(job);
  end
 end
 N.Wake();
end
function N.Status()
 local names=N.List();local count=#names;local classes=0;local accounts={};
 for _,name in ipairs(names) do if N.Class(N.bucket[name]) then classes=classes+1;end end
 for peer,p in pairs(N.peers) do if p.context==N.context then accounts[N.Account(peer) or "?"]=true;end end
 local connected=0;for _ in pairs(accounts) do connected=connected+1;end
 return "имён "..count..", с классом "..classes.."; связь с другими аккаунтами "..connected.."/2. Передаются имена и классы. Для записи на диск /reload.";
end
function N.Tick()
 local now=GetTime();
 if not N.Enabled() or (N.context and N.context~=UnBotRegistryCurrentContext()) then
  N.jobs={};N.peers={};N.discovery=nil;N.online={};N.peerAccounts={};N.presenceSeen={};N.dirtyAt=nil;N.loginAt=nil;N.frame:SetScript("OnUpdate",nil);return;
 end
 if N.loginAt and now>=N.loginAt then
  N.loginAt=nil;local afterSave=N.afterRegistrySave;N.afterRegistrySave=nil;
  if afterSave then SlashCmdList.UNBOTSHAREDNAMES("");else N.Begin(false);end
 end
 if N.dirtyAt and now>=N.dirtyAt then N.Begin(false);end
 N.DiscoveryTick();
 local active=false;local peers={};
 for peer in pairs(N.jobs) do peers[#peers+1]=peer;end;table.sort(peers);
 local start=1;for i,peer in ipairs(peers) do if peer==N.lastWirePeer then start=i%#peers+1;break end end
 for offset=0,#peers-1 do
  local peer=peers[(start+offset-1)%#peers+1];local job=N.jobs[peer];
  if job.expireAt and now>=job.expireAt then N.jobs[peer]=nil;
  elseif not job.done and not job.failed then
   active=true;
   if now>=job.deadline then N.Fail(job,"нет подтверждения обмена; повтор — кнопкой");
   elseif now>=(N.nextWire or 0) then
    if not job.welcomed then
     if not job.helloAt or now-job.helloAt>=2 then
      if (job.helloTries or 0)>=3 then N.Fail(job,"начало обмена не подтверждено за три попытки");
      else
       N.Send(peer,"H\t"..job.token.."\t"..job.context);job.helloAt=now;job.helloTries=(job.helloTries or 0)+1;N.lastWirePeer=peer;N.nextWire=now+.2;
      end
     end
    elseif job.index<=#job.pages and (not job.sentAt or now-job.sentAt>=2) then
     if job.attempts>=3 then N.Fail(job,"пакет имён не подтверждён за три попытки");
     else
      N.Send(peer,table.concat({"S",job.token,job.context,job.index,#job.pages,#job.names,job.hash,job.pages[job.index]},"\t"));
      job.sentAt=now;job.attempts=job.attempts+1;N.lastWirePeer=peer;N.nextWire=now+.2;
     end
    elseif job.index>#job.pages and not job.delivered and now>=(job.confirmAt or 0) then
     if (job.confirmTries or 0)>=3 then N.Fail(job,"получатель не подтвердил объединение имён");
     else N.Send(peer,"Q\t"..job.token.."\t"..job.context);job.confirmAt=now+2;job.confirmTries=(job.confirmTries or 0)+1;N.lastWirePeer=peer;N.nextWire=now+.2;end
    end
   end
  end
 end
 if not active and not N.dirtyAt and not N.loginAt and not N.discovery then
  if N.summaryPending then
   if N.manual or (N.receivedNew or 0)>0 or (N.receivedClasses or 0)>0 then
    N.Message(N.Status().." Добавлено имён +"..(N.receivedNew or 0)..", классов +"..(N.receivedClasses or 0)..".");
    if N.manual and not next(N.peers) then N.Message("Обмен не установлен: "..N.Debug());end
   end
   N.manual=false;N.receivedNew=0;N.receivedClasses=0;N.summaryPending=false;
  end
  N.frame:SetScript("OnUpdate",nil);
 end
end
N.frame=CreateFrame("Frame");
for _,event in ipairs({"PLAYER_ENTERING_WORLD","PLAYER_LOGOUT","CHAT_MSG_ADDON","CHAT_MSG_CHANNEL","CHAT_MSG_SYSTEM"}) do N.frame:RegisterEvent(event);end
N.frame:SetScript("OnEvent",function(_,event,...)
 if event=="CHAT_MSG_ADDON" then N.Receive(...);
 elseif event=="CHAT_MSG_CHANNEL" then local message,sender,_,display,_,_,_,index,channelName=...;N.Presence(message,sender,channelName,index,display);
 elseif event=="CHAT_MSG_SYSTEM" then
  local message=tostring((...));
  if message:find("в игре не найден",1,true) or message:lower():find("no player named",1,true) then
   for peer,job in pairs(N.jobs) do if message:find(peer,1,true) and not job.done and not job.failed then N.online[peer]=nil;N.Fail(job,"клиент вышел из игры");end end
  end
 elseif event=="PLAYER_LOGOUT" then N.jobs={};N.peers={};N.discovery=nil;N.online={};N.peerAccounts={};N.frame:SetScript("OnUpdate",nil);
 elseif event=="PLAYER_ENTERING_WORLD" and N.Enabled() then
  N.ready=true;local context=UnBotRegistryCurrentContext();
  if N.context~=context then N.jobs={};N.peers={};N.discovery=nil;N.online={};N.peerAccounts={};N.presenceSeen={};N.Attach();N.loginAt=GetTime()+5;N.Wake();end
  local saved=UnBotSquadConfig and UnBotSquadConfig.sharedNamesAfterRegistrySave;
  if saved then
   UnBotSquadConfig.sharedNamesAfterRegistrySave=nil;
   if type(saved)=="table" and saved.context==context and saved.player==UnitName("player")
    and type(saved.requestedAt)=="number" and time()>=saved.requestedAt and time()-saved.requestedAt<=300 then
    N.afterRegistrySave=true;N.loginAt=GetTime()+1;N.Wake();
   end
  end
 end
end);
SLASH_UNBOTSHAREDNAMES1="/ubnames";
SlashCmdList.UNBOTSHAREDNAMES=function(text)
 local selected=tostring(text or ""):match("^%s*account%s+(%S+)%s*$");
 if selected then
  selected=selected:upper();local actual=N.ClientAccount();
  if not N.AccountSlot(selected) then N.Message("Личная сеть обмена в публичной сборке не настроена.");return;end
  if actual~="" and actual~=selected then N.Message("выбор не совпадает с логином текущего клиента; настройка сохранена без изменений.");return;end
  N.SaveLocalAccount(selected,"manual");
  N.jobs={};N.peers={};N.discovery=nil;N.online={};N.peerAccounts={};N.presenceSeen={};
  N.context=nil;N.bucket=nil;N.loginAt=nil;N.afterRegistrySave=nil;N.ready=true;
  N.Message("аккаунт обмена выбран для всех персонажей. Для записи настройки на диск выполните /reload.");
  N.Begin(true);return;
 end
 if not N.Enabled() then
  N.Message("обмен недоступен: персонаж "..tostring(UnitName("player") or "?").." на мире "..tostring(GetRealmName() or "?").." не может участвовать: логин клиента недоступен или аккаунт не настроен. Личная сеть обмена в публичной сборке не настроена.");return;
 end
 if tostring(text or ""):lower():match("^%s*debug%s*$") then N.Message(N.Debug());N.DebugJobs();
 elseif tostring(text or ""):lower():match("^%s*status%s*$") then N.Attach();N.Message(N.Status());else N.Begin(true);end
end;

if ChatFrame_AddMessageEventFilter then
 ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL",function(_,_,message,sender,language,display,player2,flags,zone,index,channelName)
  return N.ChannelMatches(channelName,index,display) and type(message)=="string" and message:match("^UBREG4[:%s]")~=nil;
 end);
end
