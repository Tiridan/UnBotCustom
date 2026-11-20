-- Explicit, per-bot RTSC posts and manual combat-phase changes. No automatic summon hooks.
UnBotGuardPosts = UnBotGuardPosts or {};
local G = UnBotGuardPosts;
G.interval = 1.2;
G.raidKeys = {"naxx","icc","aq20","bwl","gruulslair","hyjal","karazhan","magtheridon","moltencore","onyxia","rs","ssc","blacktemple","ulduar","voa"};
G.move = {
 co={stay=false,formation=false,follow=false,passive=false,guard=false,runaway=false,["flee from adds"]=false,["move from group"]=false},
 -- This server protects loot AND gather: either token rejects the whole nc command.
 nc={stay=false,follow=false,aggressive=false,grind=false,passive=false,guard=false,runaway=false,["flee from adds"]=false,["move from group"]=false},
};

function G:Copy(value)
 if type(value)~="table" then return value; end
 local copy={}; for k,v in pairs(value) do copy[k]=self:Copy(v); end return copy;
end
function G:Key(name)
 if UnBotWorldInteraction and UnBotWorldInteraction.NameKey then return UnBotWorldInteraction.NameKey(name); end
 name=tostring(name or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","");
 return string.lower(name:match("^([^-]+)") or name);
end
function G:Owner() return (GetRealmName() or "")..":"..(UnitName("player") or ""); end
function G:Context()
 local instance,kind,difficulty,_,_,_,_,map=GetInstanceInfo();
 return table.concat({tostring(instance or ""),tostring(kind or ""),tostring(difficulty or 0),tostring(map or 0),tostring(GetRealZoneText() or "")},"|");
end
function G:Store()
 UnBotSquadConfig=UnBotSquadConfig or {};
 UnBotSquadConfig.guardPosts=UnBotSquadConfig.guardPosts or {};
 local root=UnBotSquadConfig.guardPosts; root.owners=root.owners or {};
 local key=self:Owner(); root.owners[key]=root.owners[key] or {};
 local s=root.owners[key]; s.contexts=s.contexts or {}; s.recovery=s.recovery or {}; s.events=s.events or {};
 return s;
end
function G:Hash(text)
 local h=0; for i=1,#text do h=(h*31+text:byte(i))%1000000007; end return tostring(h);
end
function G:Point()
 if not self.bot then return; end
 local s=self:Store(); local key=self:Context(); s.contexts[key]=s.contexts[key] or {};
 local context=s.contexts[key]; local name=self:Key(self.bot);
 context[name]=context[name] or {points={}};
 local b=context[name]; b.points=b.points or {}; local slot=self.slot or 1;
 b.points[slot]=b.points[slot] or {key="ubg_"..self:Hash(self:Owner().."|"..key).."_"..slot,aggressive=true};
 return b.points[slot];
end
function G:LogText(value)
 local text=tostring(value or ""); if #text<=1400 then return text; end
 local cut=1400; while cut>0 and (text:byte(cut+1) or 0)>=128 and (text:byte(cut+1) or 0)<192 do cut=cut-1; end
 return text:sub(1,cut).." [truncated]";
end
function G:Log(kind,text,name)
 local s=self:Store(); local entries=s.events;
 entries[#entries+1]={at=time(),clock=GetTime(),kind=kind,bot=name or self.bot,text=self:LogText(text)};
 while #entries>600 do table.remove(entries,1); end
end
function G:Status(text,announce)
 self.status=text; self:Refresh();
 if self.Presets and (self.Presets.doorActive or (self.groupWatch and self.groupWatch.door)) then self.Presets.status=text;self.Presets:Refresh();end
 if announce then
  self:Log("status",text);
  if UnBotSpecSummonMessage then UnBotSpecSummonMessage("Пост: "..text); end
 end
end
function G:Bots()
 local list={};
 if UnBotWorldInteraction then
  UnBotWorldInteraction.BuildBotList();
  for _,name in ipairs(UnBotWorldInteraction.bots or {}) do list[#list+1]=name; end
 end
 return list;
end
function G:Unit(name)
 for i=1,(GetNumRaidMembers()>0 and GetNumRaidMembers() or GetNumPartyMembers()) do
  local unit=(GetNumRaidMembers()>0 and "raid" or "party")..i;
  if self:Key(UnitName(unit))==self:Key(name) and UnitIsConnected(unit)
   and not UnitIsDeadOrGhost(unit) and self:Key(name)~=self:Key(UnitName("player")) then
   for _,known in ipairs(self:Bots()) do if self:Key(known)==self:Key(name) then return unit; end end
  end
 end
end
function G:Busy()
 return (UnBotAltStrategies and UnBotAltStrategies.active)
  or (UnBotStrategySurvey and UnBotStrategySurvey.active)
  or (UnBotWorldInteraction and UnBotWorldInteraction.mode)
  or (UnBotTwinEmperors and UnBotTwinEmperors.tanks and
   (UnBotTwinEmperors.tanks.stage or UnBotTwinEmperors.tanks.pending or UnBotTwinEmperors.tanks.armed))
  or (UnBotRaidReserveOtherAutomationActive and UnBotRaidReserveOtherAutomationActive(false,false,true));
end
function G:Valid(op)
 if op.owner~=self:Owner() or op.context~=self:Context() then return false,"сменились персонаж или зона"; end
 local unit=self:Unit(op.name);
 if not unit or UnitGUID(unit)~=op.guid then return false,"бот недоступен, мёртв или изменился состав"; end
 if not op.readOnly then
  -- co/nc and RTSC are server commands. The Aedm secure action is configured once, before combat.
  if self:Busy() then return false,"работает другая операция UnBot"; end
 end
 if op.door and self.Presets then return self.Presets:ValidateDoor(op);end
 return true;
end
function G:Stop(reason)
 if self.Presets and self.Presets.Hunters then self.Presets.Hunters:Stop(reason or "Стоп постов");end
 if self.Presets and self.Presets.Manual then self.Presets.Manual:AoeStopAll();end
 local batch=self.batch;self.batch=nil;self.groupWatch=nil;
 if batch then self.bot,self.slot=batch.previousBot,batch.previousSlot;end
 local op=self.op;
 if op and op.kind=="point" then
  self.cleanup={name=op.name,guid=op.guid,owner=op.owner,untilAt=GetTime()+8};
 end
 self.op=nil; self.nextSend=math.max(self.nextSend or 0,GetTime()+self.interval);
 self:Status(reason or "Очередь остановлена. Для возврата настроек нажмите «Снять пост».",true);
 if self.Presets then self.Presets:OperationEnded(op);
  if batch and batch.gluth then self.Presets.status=self.status;self.Presets.doorActive=nil;self.Presets:Refresh();end
 end
end
function G:Begin(kind,readOnly,point)
 if self.batch and not self.groupWorking then self:Status("Сначала завершите групповую расстановку или нажмите «Стоп».",true);return;end
 if not self.groupWorking and not readOnly and not (point and point.gluth and self.groupWatch and self.groupWatch.door) then self.groupWatch=nil;end
 if self.op or self.cleanup then self:Status("Сначала завершите текущий шаг или нажмите «Стоп».",true); return; end
 if kind=="inspect" and self:Busy() then self:Status("Дождитесь окончания другой операции UnBot.",true); return; end
 local unit=self:Unit(self.bot); if not unit or not UnitGUID(unit) then self:Status("Выберите живого онлайн-бота своей группы.",true); return; end
 local op={kind=kind,name=UnitName(unit),guid=UnitGUID(unit),owner=self:Owner(),context=self:Context(),
  point=point or self:Point(),slot=self.slot or 1,queue={},actual={},readOnly=readOnly,expires=GetTime()+90};
 local ok,why=self:Valid(op); if not ok then self:Status(why,true); return; end
 self.op=op; self:Log("begin",kind,op.name); return op;
end
function G:Job(command,wait,done)
 if self.op then self.op.queue[#self.op.queue+1]={command=command,wait=wait,done=done}; end
end
function G:Done(text)
 local op=self.op;self.op=nil; self:Status(text,true);
 if self.Presets then self.Presets:OperationEnded(op);end
 if op and op.group then self:GroupStepDone();end
end
function G:Strategies(text)
 local list=text:match("^[Ss]trategies:%s*(.*)$");
 if not list then return; end
 local result={};
 for key in list:gmatch("[^,]+") do result[key:match("^%s*(.-)%s*$")]=true; end
 return result;
end
function G:Coordinates(text)
 local x,y=text:match("[Ii] am at%s+([%-%.%d]+)%s*,%s*([%-%.%d]+)");
 if not x then x,y=text:match("[Pp]osition stay is set to%s+([%-%.%d]+)%s*,%s*([%-%.%d]+)"); end
 x,y=tonumber(x),tonumber(y);
 if x and y and x==x and y==y then return {x=x,y=y}; end
end
function G:Matches(wanted,actual)
 for key,value in pairs(wanted) do if value~=(actual[key]==true) then return false,key; end end return true;
end
function G:Read(mode,done)
 self:Job(mode.." ?",mode,function(actual) self.op.actual[mode]=actual; if done then done(actual); end end);
end
function G:Apply(mode,wanted,done)
 local op=self.op; local actual=op.actual[mode]; local differences={};
 for key,value in pairs(wanted) do
  if value~=(actual[key]==true) then differences[#differences+1]=(value and "+" or "-")..key; end
 end
 table.sort(differences);
 if #differences==0 then if done then done(); end return; end
 local record=self:Store().recovery[self:Key(op.name)];
 if record and op.kind~="restore" then
  record.applied=record.applied or {co={},nc={}};
  for key,value in pairs(wanted) do if value~=(actual[key]==true) then record.applied[mode][key]=value; end end
 end
 -- A standalone mode ? can overwrite an unprocessed mutation in ChatCommandTrigger.
 -- Include '?' in the same parameter string. Wait for each chunk before sending the next.
 local chunks={}; local command=mode.." "; local expected={};
 for _,change in ipairs(differences) do
  local separator=#command>#mode+1 and "," or "";
  if #command+#separator+#change+2>230 then
   chunks[#chunks+1]={command=command,expected=self:Copy(expected)};
   command=mode.." "; separator="";
  end
  command=command..separator..change; expected[change:sub(2)]=wanted[change:sub(2)];
 end
 chunks[#chunks+1]={command=command,expected=wanted};
 for _,chunk in ipairs(chunks) do
  local current=chunk; local last=current==chunks[#chunks];
  self:Job(current.command..",?",mode,function(observed)
   op.actual[mode]=observed;
   local ok,key=self:Matches(current.expected,observed);
   if not ok then self:Stop("Сервер не подтвердил "..mode.." "..key.." после изменения. Повторов нет; можно восстановить стратегии."); return; end
   if last and done then done(); end
  end);
 end
end
function G:Wanted(op,hold)
 local wanted=self:Copy(self.move);
 if hold then wanted.co.stay=true; wanted.nc.stay=true; wanted.nc.aggressive=op.point.aggressive==true; end
 if op.point.disableRaid then
  for _,key in ipairs(self.raidKeys) do
   if op.actual.co[key] or op.actual.nc[key] then wanted.co[key]=false; wanted.nc[key]=false; end
  end
 end
 return wanted;
end
function G:Remember(op,wanted)
 local store=self:Store(); local key=self:Key(op.name); local existing=store.recovery[key];
 if existing then
  if existing.guid~=op.guid or existing.context~=op.context then
   self:Stop("У этого бота есть другой незавершённый пост. Сначала восстановите стратегии."); return false;
  end
  -- A later point may explicitly manage another raid key. Capture it only once.
  existing.original=existing.original or {co={},nc={}};
  for mode,keys in pairs(wanted) do
   existing.original[mode]=existing.original[mode] or {};
   for key in pairs(keys) do if existing.original[mode][key]==nil then existing.original[mode][key]=op.actual[mode][key]==true; end end
  end
  return true;
 end
 local original={co={},nc={}};
 for mode,keys in pairs(wanted) do for k in pairs(keys) do original[mode][k]=op.actual[mode][k]==true; end end
 store.recovery[key]={name=op.name,guid=op.guid,context=op.context,slot=op.slot,at=time(),original=original,applied={co={},nc={}}};
 return true;
end
function G:Define()
 local op=self:Begin("point"); if not op then return; end
 -- A fresh server key prevents a cancelled selection from previewing an older point.
 self.pickSequence=(self.pickSequence or 0)+1;
 op.pickKey="ubg_"..self:Hash(op.owner.."|"..op.context).."_"..op.slot.."_"..self:Hash(time()..":"..GetTime()..":"..self.pickSequence);
 self:Job("rtsc");
 self:Job("rtsc save "..op.pickKey,nil,function()
  op.phase="click"; op.castReady=true;
  self:Status("Подготовка завершена. Нажмите «Прицел Aedm», затем щёлкните нужное место на земле.",true);
 end);
 self:Status("Включаю RTSC для "..op.name..". Затем нужно применить Aedm.",true);
end
-- Casting is performed exclusively by the inherited secure OnClick handler.
-- Never call CastSpell/Click from timers or overwrite that handler.
function G:RefreshCast()
 -- Permanent secure spell attributes: never enable/disable or reconfigure the cast action by an asynchronous phase.
end
function G:CastPreClick()
 local op=self.op;
 if not op or op.kind~="point" or op.phase~="click" or not op.castReady then
  self:Status("Прицел Aedm — ручное заклинание. Чтобы записать точку, сначала нажмите «Подготовить» и дождитесь готовности.",true); return;
 end
 local ok,why=self:Valid(op); if not ok then self:Stop(why); return; end
 op.castPressedAt=GetTime(); self:Log("cast_click","Aedm 30758",op.name);
end
function G:CastPostClick()
 local op=self.op;
 if not op or op.kind~="point" or op.phase~="click" or not op.castPressedAt then return; end
 if SpellIsTargeting and SpellIsTargeting() then
  self:Status("Прицел открыт. Щёлкните пол. Если столб появился, а окно ждёт — нажмите «Проверить метку».",true);
 else
  self:Status("После клика по земле нажмите «Проверить метку», если окно не перешло к проверке само.",true);
 end
end
-- SENT observes the request; SUCCEEDED may be absent for the special RTSC spell.
-- Neither event proves the server saved the point. The player confirms the preview.
function G:Picked(source)
 local op=self.op;
 if (source~="sent" and source~="spell") or not op or op.kind~="point" or op.phase~="click" or not op.castReady then return; end
 op.castSignal=source;
end
function G:PreviewPoint()
 local op=self.op;
 if not op or op.kind~="point" or (op.phase~="click" and op.phase~="confirm") then return; end
 local ok,why=self:Valid(op); if not ok then self:Stop(why); return; end
 if SpellIsTargeting and SpellIsTargeting() then self:Status("Сначала щёлкните нужное место на земле или отмените прицел правым кликом.",true); return; end
 if not op.castPressedAt and not op.castSignal then self:Status("Сначала откройте «Прицел Aedm» и щёлкните землю.",true); return; end
 op.castReady=false; op.castSignal=nil; op.phase="preview"; op.expires=GetTime()+20;
 self:Job("rtsc show "..op.pickKey,nil,function()
  op.phase="confirm"; op.expires=GetTime()+45;
  self:Status("Проверка метки отправлена. Если столб появился в нужном месте — нажмите «Метка верна». Нет столба или место неверное — «Стоп» и повторите подготовку.",true);
 end);
 self:Status("Показываю новую точку. Сам клик ещё не подтверждает её сохранение сервером.",true);
end
function G:ConfirmPoint()
 local op=self.op; if not op or op.kind~="point" or op.phase~="confirm" then return; end
 local ok,why=self:Valid(op); if not ok then self:Stop(why); return; end
 op.point.key=op.pickKey; op.point.pickedAt=time(); op.point.castConfirmed=true; op.point.confirmation="visual";
 op.point.coordinates=nil; op.point.confirmedAt=nil;
 self:Log("point_confirmed",op.pickKey,op.name);
 self:Done("Метка подтверждена игроком. Теперь нажмите «Отправить».");
end
function G:ShowPoint()
 if self.op and self.op.kind=="point" then self:PreviewPoint(); return; end
 local p=self:Point(); if not p or not p.pickedAt then self:Status("Сначала задайте эту точку через Aedm.",true); return; end
 local op=self:Begin("show",true); if not op then return; end
 self:Job("rtsc show "..p.key,nil,function() self:Done("Команда показа метки отправлена "..op.name..". Обозначение временное."); end);
end
function G:Deploy()
 local p=self:Point(); if not p or not p.pickedAt or not p.castConfirmed then self:Status("Задайте точку: «Подготовить» → «Прицел Aedm» → земля → проверка метки → «Метка верна».",true); return; end
 local op=self:Begin("move"); if not op then return; end
 self:Status("Читаю исходные co/nc у "..op.name.." перед расстановкой.",true);
 self:Read("co",function() self:Read("nc",function()
  local rec=self:Store().recovery[self:Key(op.name)];
  -- RTSC MoveToSpell updates an existing co stay anchor. Keep the hold profile during a phase change.
  op.retarget=rec and op.actual.co.stay and op.actual.nc.stay and true or false;
  local wanted=self:Wanted(op,op.retarget); if not self:Remember(op,wanted) then return; end
  self:Apply("co",wanted.co,function() self:Apply("nc",wanted.nc,function()
   self:Job("rtsc go "..p.key,nil,function()
    op.phase="arrival"; op.expires=GetTime()+60;
    local record=self:Store().recovery[self:Key(op.name)]; record.movingSlot=op.slot;
    self:Status("Переход отправлен. Дождитесь центра метки и нажмите «На месте — охранять». Автоповторов нет.",true);
   end);
  end); end);
 end); end);
end
function G:ConfirmArrival()
 local op=self.op; if not op or op.kind~="move" or op.phase~="arrival" then return; end
 local ok,why=self:Valid(op); if not ok then self:Stop(why); return; end
 op.phase="hold"; op.expires=GetTime()+60;
 self:Job("go ?","coords",function(point)
  -- The player confirms the world marker; a stationary coordinate alone is NOT arrival proof.
  op.point.coordinates=point; op.point.confirmedAt=time();
  local rec=self:Store().recovery[self:Key(op.name)];
  for _,mode in ipairs({"co","nc"}) do
   for _,key in ipairs({"stay","passive","move from group"}) do
    rec.applied[mode][key]=key=="stay";
   end
  end
  self:Job("stay","stay",function()
   self:Read("co",function() self:Read("nc",function()
    local wanted=self:Wanted(op,true);
    self:Apply("co",wanted.co,function() self:Apply("nc",wanted.nc,function()
     self.observe={name=op.name,guid=op.guid,owner=op.owner,context=op.context,untilAt=GetTime()+300};
     local record=self:Store().recovery[self:Key(op.name)]; record.activeSlot=op.slot; record.movingSlot=nil;
     self:Done(op.name..": охрана точки "..op.slot.." включена. Сменить пост можно и в бою.");
    end); end);
   end); end);
  end);
 end);
 self:Status("Прибытие подтверждено игроком. Считываю координаты и включаю охрану.",true);
end
function G:Restore(point)
 local record=self:Store().recovery[self:Key(self.bot)]; if not record then self:Status("Для выбранного бота нет сохранённых изменений.",true); return; end
 local op=self:Begin("restore",false,point); if not op then return; end
 if record.guid~=op.guid then self:Stop("GUID бота не совпал с сохранённым. Восстановление отменено."); return; end
 self:Read("co",function() self:Read("nc",function()
  local wanted={co={},nc={}};
  for mode,keys in pairs(record.applied) do for key,value in pairs(keys) do
   if (op.actual[mode][key]==true)==value then wanted[mode][key]=record.original[mode][key]==true;
   else self:Log("preserve",mode.." "..key..": ручное изменение сохранено",op.name); end
  end end
  self:Apply("co",wanted.co,function() self:Apply("nc",wanted.nc,function()
   self:Store().recovery[self:Key(op.name)]=nil; self.observe=nil;
   self:Done(op.name..": стратегии восстановлены. Точки сохранены.");
  end); end);
 end); end);
 self:Status("Снимаю пост: читаю текущие стратегии. Восстановление доступно и в бою.",true);
end
function G:Inspect()
 local op=self:Begin("inspect",true); if not op then return; end
 self:Read("co",function() self:Read("nc",function()
  self:Job("position stay ?","anchor",function(anchor)
   self:Job("go ?","coords",function(point)
    op.point.lastObserved={at=time(),actual=point,anchor=anchor};
    local a=anchor.x and string.format("%.4f, %.4f",anchor.x,anchor.y) or "не задан";
    self:Done(string.format("%s: сейчас %.4f, %.4f; якорь stay: %s. Ответы записаны в журнал.",op.name,point.x,point.y,a));
   end);
  end);
 end); end);
 self:Status("Разовая проверка co/nc, якоря и позиции.",true);
end
-- Explicit three-bot layout. Preparation is paced; only the final GO is a three-message burst.
function G:GroupBindings(create)
 local store=self:Store(); local context=self:Context();
 if create then store.groups=store.groups or {};store.groups[context]=store.groups[context] or {};end
 return store.groups and store.groups[context] or {};
end
function G:BoundPoint(name,slot)
 local context=self:Store().contexts[self:Context()];
 local binding=context and context[self:Key(name)];
 return binding and binding.points and binding.points[slot];
end
function G:BindGroup(index)
 if self.op or self.cleanup or self.batch then return;end
 local p=self:Point();
 if not self:Unit(self.bot) or not p or not p.pickedAt or not p.castConfirmed then
  self:Status("Сначала выберите бота и подтвердите его точку, затем запомните строку группы.",true);return;
 end
 for i=1,3 do local row=self:GroupBindings()[i];
  if i~=index and type(row)=="table" and self:Key(row.name)==self:Key(self.bot) then self:Status("Этот бот уже выбран в другой строке.",true);return;end
 end
 self.groupWatch=nil;
 local rows=self:GroupBindings(true);local row=rows[index] or {};
 row.name=self.bot;row.slot=self.slot or 1;rows[index]=row;
 self:Status("Группа: строка "..index.." — "..self.bot..", точка "..(self.slot or 1)..". Отправки ещё не было.",true);
end
function G:GroupSnapshot(restoring)
 local entries,seen={},{};
 for i=1,3 do
  local row=self:GroupBindings()[i];local unit=row and self:Unit(row.name);
  local p=row and self:BoundPoint(row.name,row.slot);
  if not unit or not UnitGUID(unit) or seen[self:Key(row.name)]
   or (not restoring and (not p or not p.pickedAt or not p.castConfirmed)) then
   return nil,"Для трёх разных живых ботов подтвердите точки и заполните все три строки.";
  end
  if restoring and not self:Store().recovery[self:Key(row.name)] then return nil,"Нет снимка стратегий для "..row.name.."; снимите остальные посты по одному.";end
  seen[self:Key(row.name)]=true;
  entries[i]={name=UnitName(unit),guid=UnitGUID(unit),owner=self:Owner(),context=self:Context(),
   slot=row.slot,point=p,key=p and p.key};
 end
 return entries;
end
function G:GroupValid(batch)
 if batch.gluth then return self.Presets:GroupValid(batch);end
 if batch.owner~=self:Owner() or batch.context~=self:Context() then return false,"сменились персонаж или зона";end
 for _,entry in ipairs(batch.entries) do
  local ok,why=self:Valid(entry);if not ok then return false,entry.name..": "..why;end
  if batch.kind~="restore" and (self:BoundPoint(entry.name,entry.slot)~=entry.point or entry.point.key~=entry.key) then
   return false,"изменилось назначение "..entry.name;
  end
 end
 return true;
end
function G:GroupBegin(restoring)
 if self.op or self.cleanup or self.batch then self:Status("Сначала завершите текущий шаг или нажмите «Стоп».",true);return;end
 local entries,why=self:GroupSnapshot(restoring);if not entries then self:Status(why,true);return;end
 local b={entries=entries,owner=self:Owner(),context=self:Context(),kind=restoring and "restore" or "prepare",
  phase=restoring and "restore" or "prepare",index=1,expires=GetTime()+180,previousBot=self.bot,previousSlot=self.slot};
 local ok;ok,why=self:GroupValid(b);if not ok then self:Status(why,true);return;end
 self.groupWatch=nil;self.batch=b;self:GroupStep();
end
function G:GroupStep()
 if self.batch and self.batch.gluth then self.Presets:GroupStep();return;end
 local b=self.batch;if not b then return;end
 local ok,why=self:GroupValid(b);if not ok then self:Stop("Группа остановлена: "..why);return;end
 local entry=b.entries[b.index];self.bot=entry.name;self.slot=entry.slot;
 self.groupWorking=true;
 if b.phase=="restore" then
  self:Restore();if self.op then self.op.group=true;end
 elseif b.phase=="hold" then
  local op=self:Begin("move");
  if op then op.group=true;op.phase="arrival";self:ConfirmArrival();end
 else
  local op=self:Begin("group_prepare");
  if op then
   op.group=true;
   self:Read("co",function() self:Read("nc",function()
    local wanted=self:Wanted(op,true);wanted.nc.aggressive=false;
    if not self:Remember(op,wanted) then return;end
    self:Apply("co",wanted.co,function() self:Apply("nc",wanted.nc,function()
     self:Done(op.name..": удержание и путь подготовлены; движение ещё не запущено.");
    end);end);
   end);end);
  end
 end
 self.groupWorking=nil;
 if not self.op and self.batch==b then self:Stop("Не удалось начать шаг группы. Снимки стратегий сохранены.");end
end
function G:GroupStepDone()
 if self.batch and self.batch.gluth then self.Presets:GroupStepDone();return;end
 local b=self.batch;if not b then return;end
 b.index=b.index+1;
 if b.index<=3 then self:GroupStep();return;end
 self.bot,self.slot=b.previousBot,b.previousSlot;
 if b.phase=="prepare" then
  b.phase="armed";b.expires=GetTime()+120;
  self:Status("Трое готовы и удерживают исходные места. Нажмите «Отправить троих»: команды движения уйдут вместе.",true);
 else
  self.batch=nil;
  self:Status(b.phase=="hold" and "Трое закреплены на своих точках. Возврат — серверный stay; привязка при смене боя контролируется до 10 минут." or "Посты троих сняты; исходные стратегии восстановлены. Точки сохранены.",true);
 end
end
function G:GroupSend(returning)
 if self.batch and self.batch.gluth then if not returning then self.Presets:GroupSend();end;return;end
 local b=self.batch;
 if returning then
  if self.op or self.cleanup or b then self:Status("Завершите текущий шаг или нажмите «Стоп».",true);return;end
  local entries,why=self:GroupSnapshot();if not entries then self:Status(why,true);return;end
  for _,entry in ipairs(entries) do
   local rec=self:Store().recovery[self:Key(entry.name)];
   if not rec or rec.guid~=entry.guid or rec.context~=entry.context or rec.targetKey~=entry.key then
    self:Status("Сначала подготовьте и отправьте этих троих. Для изменённой точки нужна новая подготовка.",true);return;
   end
  end
  b={entries=entries,owner=self:Owner(),context=self:Context(),previousBot=self.bot,previousSlot=self.slot};
 elseif not b or b.phase~="armed" then return;end
 local ok,why=self:GroupValid(b);if not ok then self:Stop("Общая отправка отменена до движения: "..why);return;end
 local now=GetTime();b.phase="arrival";b.expires=now+120;self.batch=b;
 local watch={entries={},owner=b.owner,context=b.context,untilAt=now+600,nextAt=now+1};
 -- Validate all three above before sending any movement command. No arrival waits between GO messages.
 for i,entry in ipairs(b.entries) do
  local rec=self:Store().recovery[self:Key(entry.name)];rec.targetKey=entry.key;rec.movingSlot=entry.slot;
  watch.entries[i]={name=entry.name,guid=entry.guid,slot=entry.slot,key=entry.key,
   combat=UnitAffectingCombat(self:Unit(entry.name)) and true or false,attempts=0,lastSent=now};
  self:Log("group_go",entry.key,entry.name);SendChatMessage("rtsc go "..entry.key,"WHISPER",nil,entry.name);
 end
 self.nextSend=now+self.interval;self.groupWatch=watch;
 self:Status("Команды отправлены троим без ожидания друг друга. Когда каждый дойдёт до своей метки — «Все на месте».",true);
end
function G:GroupHold()
 if self.batch and self.batch.gluth then self.Presets:GroupHold();return;end
 local b=self.batch;if not b or b.phase~="arrival" or self.op then return;end
 b.phase="hold";b.index=1;b.expires=GetTime()+180;self:GroupStep();
end
function G:GroupWatchTick()
 local w=self.groupWatch;if not w then return;end
 local now=GetTime();if now<w.nextAt then return;end
 w.nextAt=now+1;
 if now>=w.untilAt or w.owner~=self:Owner() or w.context~=self:Context() or self:Busy() then
  self.groupWatch=nil;self:Status(w.door and "Контроль привязки танка у двери завершён. Точка и stay сохранены." or "Контроль привязки троих завершён. Сохранённые точки и stay оставлены.",true);return;
 end
 if self.op or self.cleanup then return;end
 for _,e in ipairs(w.entries) do
  local unit=self:Unit(e.name);local p;
   if w.door then p=self.Presets:WatchedDoor(w,e);else p=self:BoundPoint(e.name,e.slot);end
   local rec=e.manual and self.Presets.Manual:Record(e.slot) or self:Store().recovery[self:Key(e.name)];
  if not unit or UnitGUID(unit)~=e.guid or not p or p.key~=e.key or not rec or rec.targetKey~=e.key then e.disabled=true;end
  if not e.disabled then
   local combat=UnitAffectingCombat(unit) and true or false;
   if combat~=e.combat then e.combat=combat;e.rebindAt=now+self.interval;end
   if e.rebindAt and now>=e.rebindAt then
    e.rebindAt=nil;
    if e.attempts<2 then
     e.attempts=e.attempts+1;e.lastSent=now;
     self:Log("group_rebind",e.key.." | state="..tostring(e.combat).." | "..e.attempts.."/2",e.name);
     SendChatMessage(e.anchorCommand or ("rtsc go "..e.key),"WHISPER",nil,e.name);self.nextSend=now+self.interval;
    else e.disabled=true;self:Status(e.name..": две коррекции привязки исчерпаны; при необходимости нажмите «Вернуть троих».",true);end
   end
  end
 end
end
function G:GroupWatchRefusal(message,sender)
 local w=self.groupWatch;if not w or not self:Refusal(tostring(message or ""):lower()) then return false;end
 for _,e in ipairs(w.entries) do
  if not e.disabled and e.lastSent and GetTime()-e.lastSent<=7 and self:Key(sender)==self:Key(e.name) then
   e.disabled=true;self:Log("group_refusal",message,e.name);
   if self.batch then self:Stop(e.name..": отказ сервера; общий переход остановлен, снимки сохранены.");
   else self:Status(e.name..": отказ сервера; автоматическая коррекция прекращена.",true);end
   return true;
  end
 end
 return false;
end

function G:Refusal(lower)
 for _,text in ipairs({"except loot","except gather","unknown spell","unknown strategy","unknown command","cannot cast","no items","not allowed","too far away","can't go there","cannot go","no permission","not your bot","not set","invalid command","it is in water","whisper 'go"}) do
  if lower:find(text,1,true) then return true; end
 end
 return false;
end
function G:GroupSystem(message)
 local w=self.groupWatch;if not w then return false;end
 local text=tostring(message or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","");
 local name,body=text:match("^%s*([^:]+):%s*(.*)$");if not name then return false;end
 name=name:match("^%s*(.-)%s*$"):gsub("^%[",""):gsub("%]$","");
 return self:GroupWatchRefusal(body,name);
end
function G:System(message)
 if self.Presets and self.Presets.Manual and self.Presets.Manual:CaptureSystem(message) then return;end
 if self.Presets and self.Presets.Quick and self.Presets.Quick:DeploySystem(message) then return;end
 if self.Presets and self.Presets.Hunters then
  local n,b=tostring(message or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):match("^%s*([^:]+):%s*(.*)$");
  if n and self.Presets.Hunters:Reply(b,n:match("^%s*(.-)%s*$"):gsub("^%[",""):gsub("%]$","")) then return;end
 end
 if self.Presets and self.Presets.Manual and self.Presets.Manual:AoeSystem(message) then return;end
 if self:GroupSystem(message) then return;end
 local op=self.op;
 if not op or not op.lastSent or GetTime()-op.lastSent>7 then return; end
 local text=tostring(message or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("|H.-|h(.-)|h","%1");
 local name,body=text:match("^%s*([^:]+):%s*(.*)$");
 if not name then return; end
 name=name:match("^%s*(.-)%s*$"):gsub("^%[",""):gsub("%]$","");
 -- System feedback has no sender field. Accept only a named refusal for the recently commanded bot.
 if self:Key(name)==self:Key(op.name) and self:Refusal(body:lower()) then
  self:Log("system",text,op.name); self:Reply(body,op.name);
 end
end
function G:Reply(message,sender)
 if self.Presets and self.Presets.Manual and self.Presets.Manual:CaptureReply(message,sender) then return;end
 if self.Presets and self.Presets.Quick and self.Presets.Quick:DeployReply(message,sender) then return;end
 if self.Presets and self.Presets.Hunters and self.Presets.Hunters:Reply(message,sender) then return;end
 if self.Presets and self.Presets.Manual and self.Presets.Manual:AoeReply(message,sender) then return;end
 if self.Presets and self.Presets:GroupReply(message,sender) then return;end
 if self:GroupWatchRefusal(message,sender) then return;end
 local text=tostring(message or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","");
 local op=self.op; local watch=self.observe;
 if (op and self:Key(sender)==self:Key(op.name)) or (watch and watch.untilAt>GetTime() and watch.owner==self:Owner() and watch.context==self:Context() and self:Key(sender)==self:Key(watch.name)) then
  self:Log("reply",text,sender);
 end
 if not op or self:Key(sender)~=self:Key(op.name) then return; end
 local valid,why=self:Valid(op); if not valid then self:Stop(why); return; end
 local lower=text:lower();
 if op.manual and (lower:find("cannot summon",1,true) or lower:find("cannot be summoned",1,true) or lower:find("can't summon",1,true)) then self:Stop(op.name..": призыв отклонён — "..text);return;end
 if self:Refusal(lower) and not (op.pending and op.pending.wait=="anchor" and lower:find("not set",1,true)) then
  self:Stop(op.name..": отказ сервера — "..text); return;
 end
 local job=op.pending; if not job then return; end
 local value;
 if job.wait=="co" or job.wait=="nc" then value=self:Strategies(text);
 elseif job.wait=="rti" then value=lower:match("^rti set to:%s*(%a+)");
  elseif job.wait=="world" then value=self.Presets and self.Presets:ParseWorld(text);
 elseif job.wait=="resetAI" and lower:find("ai was reset to defaults",1,true) then value=true;
 elseif job.wait=="anchorSet" and (lower:match("^position stay is set%s*$") or lower:match("^staying%s*$") or text:find("Стою",1,true)) then value=true;
 elseif job.wait=="coords" then if lower:find("i am at",1,true) then value=self:Coordinates(text); end
 elseif job.wait=="anchor" then
  if lower:find("position stay is not set",1,true) then value={};
  elseif lower:find("position stay is set to",1,true) then value=self:Coordinates(text); end
 elseif job.wait=="stay" and (lower:find("staying",1,true) or text:find("Стою",1,true)) then value=true; end
 if value~=nil then
  op.pending=nil; if job.done then job.done(value); end
 end
end
function G:Tick()
 local now=GetTime();
 if now>=(self.launcherCheckAt or 0) then self.launcherCheckAt=now+1;self:RefreshLauncher();end
 if self.cleanup and now>=(self.nextSend or 0) then
  local c=self.cleanup; self.cleanup=nil; local unit=self:Unit(c.name);
  if now<c.untilAt and c.owner==self:Owner() and unit and UnitGUID(unit)==c.guid then
   self:Log("send","rtsc cancel",c.name); SendChatMessage("rtsc cancel","WHISPER",nil,c.name); self.nextSend=now+self.interval;
  end
 end
 if self.observe and (now>self.observe.untilAt or self.observe.owner~=self:Owner() or self.observe.context~=self:Context()) then self.observe=nil; end
 if self.batch and now>=self.batch.expires then self:Stop("Время группового шага истекло; точки и снимки сохранены.");return;end
 self:GroupWatchTick();
 if self.Presets and self.Presets.Manual then self.Presets.Manual:CaptureTick();end
 if self.Presets and self.Presets.Quick then self.Presets.Quick:SummonTick();end
 if self.Presets and self.Presets.Quick then self.Presets.Quick:DeployTick();end
 if self.Presets and self.Presets.Hunters then self.Presets.Hunters:Tick();end
 if self.Presets and self.Presets.Manual then self.Presets.Manual:AoeTick();end
 local op=self.op; if not op then return; end
 local ok,why=self:Valid(op); if not ok then self:Stop(why); return; end
 if now>=op.expires then self:Stop("Время шага истекло. Повторов нет; при необходимости восстановите стратегии."); return; end
 if op.kind=="point" and op.phase=="click" and op.castSignal and not (SpellIsTargeting and SpellIsTargeting()) then self:PreviewPoint(); end
 if self.op~=op then return; end
 if op.arrival and self.Presets.Manual:ArrivalTick(op,now) then return;end
 if op.pending then
  if now>=op.pending.deadline then self:Stop("Нет ответа на «"..op.pending.command.."» за 7 секунд. Повторов нет."); end
  return;
 end
 if op.delay then
  if now<op.delay.at then return; end
  local callback=op.delay.done; op.delay=nil; if callback then callback(); end
  if self.op~=op then return; end
 end
 if now<(self.nextSend or 0) then return; end
 local job=table.remove(op.queue,1); if not job then return; end
 self.nextSend=now+self.interval;
 if job.wait then job.deadline=now+7; op.pending=job;
 else op.delay={at=self.nextSend,done=job.done}; end
 if op.kind=="point" and job.command:match("^rtsc save ") then op.phase="arming"; op.expires=now+45; end
 op.lastSent=now; op.lastCommand=job.command;
 self:Log("send",job.command,op.name); SendChatMessage(job.command,"WHISPER",nil,op.name);
 self:Refresh();
end
function G:Select(name)
 if self.op or self.cleanup or self.batch then self:Status("Сначала завершите шаг или нажмите «Стоп».",true); return; end
 self.bot=name; self:Store().lastBot=name; self:Refresh();
end
function G:Menu(kind,anchor)
 if self.op or self.cleanup or self.batch then return; end
 local menu={};
 if kind=="bot" then
  for _,bot in ipairs(self:Bots()) do local name=bot; menu[#menu+1]={text=name,notCheckable=true,func=function() self:Select(name); end}; end
  if #menu==0 then menu[1]={text="Нет онлайн-ботов в группе",disabled=true,notCheckable=true}; end
 else
  for i=1,3 do local index=i; menu[#menu+1]={text="Точка "..i,notCheckable=true,func=function() self.slot=index; self:Refresh(); end}; end
 end
 EasyMenu(UnBotLocale and UnBotLocale.Menu(menu) or menu,self.menu,anchor,0,0,"MENU",2);
end
function G:HasBoundPost()
 -- Visibility must not create empty points or change the bot's settings.
 local storage=UnBotSquadConfig and UnBotSquadConfig.guardPosts;
 local owner=storage and storage.owners and storage.owners[self:Owner()];
 local context=owner and owner.contexts and owner.contexts[self:Context()];
 if not context then return false;end
 for _,name in ipairs(self:Bots()) do
  local binding=context[self:Key(name)];
  if binding and binding.points and self:Unit(name) then
   for slot=1,3 do
    local point=binding.points[slot];
    if point and point.key and point.pickedAt and point.castConfirmed then return true;end
   end
  end
 end
 return false;
end
function G:RefreshLauncher()
 local launcher=self.launcher;if not launcher then return;end
 -- Protected visibility is prepared before combat; the secure click still works in combat.
 if InCombatLockdown() then self.launcherDirty=true;return;end
 local policy=self:HasBoundPost() and "[group] show; hide" or "hide";
 if self.launcherPolicy~=policy then
  if RegisterStateDriver then RegisterStateDriver(launcher,"visibility",policy);
  elseif policy=="hide" then launcher:Hide();else launcher:Show();end
  self.launcherPolicy=policy;
 end
 self.launcherDirty=nil;
end
function G:Refresh()
 self:RefreshLauncher();
 local f=self.frame; if not f then return; end
 local p=self:Point(); local busy=self.op or self.cleanup or self.batch;
 f.bot:SetText(self.bot or "Выберите бота");
 for i,button in ipairs(f.slots) do button:SetText((i==(self.slot or 1) and "|cffffff00" or "").."Точка "..i.."|r"); end
 f.aggressive:SetChecked(p and p.aggressive==true); f.raid:SetChecked(p and p.disableRaid==true);
 local op=self.op; local click=op and op.kind=="point" and op.phase=="click";
 f.define:SetText("1. Подготовить");
 f.show:SetText(op and op.kind=="point" and "Проверить метку" or "Показать метку");
 self:RefreshCast();
 local function enabled(button,value) if value then button:Enable(); else button:Disable(); end end
 enabled(f.bot,not busy); for _,button in ipairs(f.slots) do enabled(button,not busy); end; enabled(f.refresh,not busy);
 enabled(f.aggressive,self.bot and not busy); enabled(f.raid,self.bot and not busy and not self:Store().recovery[self:Key(self.bot)]);
 enabled(f.define,self.bot and not busy);
 enabled(f.show,(self.bot and p and p.pickedAt and not busy) or (op and op.kind=="point" and ((click and (op.castPressedAt or op.castSignal)) or op.phase=="confirm")));
 enabled(f.accept,op and op.kind=="point" and op.phase=="confirm");
 enabled(f.deploy,self.bot and p and p.pickedAt and p.castConfirmed and not busy);
 enabled(f.confirm,op and op.kind=="move" and op.phase=="arrival");
 enabled(f.restore,self.bot and self:Store().recovery[self:Key(self.bot)] and not busy);
 enabled(f.stop,busy or self.groupWatch); enabled(f.inspect,self.bot and not busy);
 if f.groupRows then
  for i,b in ipairs(f.groupRows) do local row=self:GroupBindings()[i];b:SetText(row and (row.name.." → точка "..row.slot) or (i..". Запомнить выбранного"));enabled(b,not busy);end
  enabled(f.groupPrepare,not busy);enabled(f.groupSend,self.batch and self.batch.phase=="armed");
  enabled(f.groupHold,self.batch and self.batch.phase=="arrival");
  enabled(f.groupReturn,not busy);enabled(f.groupRestore,not busy);
 end
 f.status:SetText(self.status or "Выберите бота и точку. Открытие окна не отправляет команды.");
 local point=p and (p.pickedAt and (p.castConfirmed and "Точка задана" or "Нужно повторить выбор") or "Ещё не задана") or "Выберите бота";
 if p and p.coordinates then point=point..string.format("; подтверждено %.4f, %.4f",p.coordinates.x,p.coordinates.y); end
 local record=self.bot and self:Store().recovery[self:Key(self.bot)];
 if record and record.context==self:Context() and record.activeSlot then
  point=point.."; пост "..record.activeSlot..(record.movingSlot and " → "..record.movingSlot or "");
 end
 f.pointInfo:SetText(point);
end
function G:PrepareView()
 if not self.op then
  local list=self:Bots(); local target=UnitName("target"); local preferred=self.bot or self:Store().lastBot;
  for _,name in ipairs(list) do if self:Key(name)==self:Key(target) then preferred=name; break end end
  self.bot=nil; for _,name in ipairs(list) do if self:Key(name)==self:Key(preferred) then self.bot=name; break end end
  self.bot=self.bot or list[1];
 end
 if not self.status and self:Store().recovery[self:Key(self.bot)] then
  self.status="Есть сохранённые изменения этого бота. После /reload охрана автоматически не запускается; доступно восстановление стратегий.";
 end
 self:Refresh();
end
function G:EnsureUI()
 if self.frame then return true; end
 if InCombatLockdown() then return false; end
 self:CreateUI(); self.frame:Hide(); return true;
end
-- Generic manual placement: three saved names, exactly two addressed commands per click.
G.Simple={};
function G.Simple:Rows()
 local s=G:Store();s.simplePosts=s.simplePosts or {};return s.simplePosts;
end
function G.Simple:Save(index,text)
 local name=tostring(text or ""):match("^%s*(.-)%s*$");
 local rows=self:Rows();rows[index]=rows[index] or {};rows[index].name=name;
 return name;
end
function G.Simple:Message(text)
 self.status=text;if self.frame then self.frame.status:SetText(text);end
 if UnBotSpecSummonMessage then UnBotSpecSummonMessage("Расстановка: "..text);end
end
function G.Simple:Place(index)
 local f=self.frame;local row=self:Rows()[index];
 local name=self:Save(index,f and f.rows[index].name:GetText() or (row and row.name));
 if name=="" or name:find("[%s%c|/\\]") then self:Message("Укажите имя бота в строке "..index..".");return;end
 -- Deliberately no combat, class, roster, map, AI or operation gates.
 SendChatMessage("summon","WHISPER",nil,name);
 SendChatMessage("stay","WHISPER",nil,name);
 self:Message(name..": отправлены summon и stay.");
end
function G.Simple:Names()
 local list,seen={},{};
 local function add(name)
  if name and name~="" and name~=UNKNOWNOBJECT and name~=UNKNOWN and G:Key(name)~=G:Key(UnitName("player")) and not seen[G:Key(name)] then
   seen[G:Key(name)]=true;list[#list+1]=name;
  end
 end
 for _,name in ipairs(G:Bots()) do add(name);end
 local raid=GetNumRaidMembers()>0;
 for i=1,(raid and GetNumRaidMembers() or GetNumPartyMembers()) do add(UnitName((raid and "raid" or "party")..i));end
 for _,row in ipairs(self:Rows()) do add(row.name);end
 table.sort(list,function(a,b) return G:Key(a)<G:Key(b);end);return list;
end
function G.Simple:Menu(index,anchor,page)
 local list=self:Names();page=page or 1;local menu={};local first=(page-1)*12+1;
 for i=first,math.min(first+11,#list) do
  local name=list[i];menu[#menu+1]={text=name,notCheckable=true,func=function()
   G.Simple:Save(index,name);G.Simple.frame.rows[index].name:SetText(name);
  end};
 end
 if first>1 then menu[#menu+1]={text="← Назад",notCheckable=true,func=function() G.Simple:Menu(index,anchor,page-1);end};end
 if first+11<#list then menu[#menu+1]={text="Далее →",notCheckable=true,func=function() G.Simple:Menu(index,anchor,page+1);end};end
 if #menu==0 then menu[1]={text="Введите имя вручную",notCheckable=true,disabled=true};end
 EasyMenu(menu,self.menu,anchor,0,0,"MENU");
end
function G.Simple:Show()
 if not self.frame then self:CreateUI();end
 local rows=self:Rows();
 for i=1,3 do self.frame.rows[i].name:SetText(rows[i] and rows[i].name or "");end
 self.frame:Show();
end
function G.Simple:CreateUI()
 local f=CreateFrame("Frame","UnBotSimplePostsFrame",UIParent);self.frame=f;
 f:SetWidth(560);f:SetHeight(300);f:SetPoint("CENTER",UIParent,"CENTER",0,0);
 f:SetFrameStrata("DIALOG");f:SetClampedToScreen(true);f:SetMovable(true);f:EnableMouse(true);
 f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=32,insets={left=11,right=12,top=12,bottom=11}});
 local function label(text,x,y,width,style)
  local t=f:CreateFontString(nil,"OVERLAY",style or "GameFontHighlightSmall");t:SetPoint("TOPLEFT",f,"TOPLEFT",x,-y);t:SetWidth(width);t:SetJustifyH("LEFT");t:SetText(text);return t;
 end
 local function button(text,x,y,width,fn)
  local b=CreateFrame("Button",nil,f,"UIPanelButtonTemplate");b:SetWidth(width);b:SetHeight(28);b:SetPoint("TOPLEFT",f,"TOPLEFT",x,-y);b:SetText(text);b:SetScript("OnClick",fn);return b;
 end
 f.dragHandle=CreateFrame("Frame",nil,f);f.dragHandle:SetPoint("TOPLEFT",f,"TOPLEFT",12,-8);f.dragHandle:SetWidth(500);f.dragHandle:SetHeight(38);
 f.dragHandle:EnableMouse(true);f.dragHandle:RegisterForDrag("LeftButton");
 f.dragHandle:SetScript("OnDragStart",function() f:StartMoving();end);f.dragHandle:SetScript("OnDragStop",function() f:StopMovingOrSizing();end);
 label("Расстановка — 3 бота",25,23,470,"GameFontNormalLarge");
 f.close=CreateFrame("Button",nil,f,"UIPanelCloseButton");f.close:SetPoint("TOPRIGHT",f,"TOPRIGHT",-5,-5);f.close:SetScript("OnClick",function() f:Hide();end);
 label("Встаньте в нужное место. Выберите имя или впишите его вручную.",25,63,510);
 f.rows={};
 for i=1,3 do
  local index=i;local y=94+(i-1)*46;local row={};f.rows[i]=row;
  label(i..".",25,y+8,24,"GameFontNormal");
  row.name=CreateFrame("EditBox",nil,f,"InputBoxTemplate");row.name:SetWidth(210);row.name:SetHeight(28);row.name:SetPoint("TOPLEFT",f,"TOPLEFT",54,-y);row.name:SetAutoFocus(false);row.name:SetMaxLetters(48);
  row.name:SetScript("OnTextChanged",function(s) G.Simple:Save(index,s:GetText());end);
  row.name:SetScript("OnEnterPressed",function(s) G.Simple:Save(index,s:GetText());s:ClearFocus();end);
  row.name:SetScript("OnEscapePressed",function(s) s:ClearFocus();end);
  row.name:SetScript("OnEditFocusLost",function(s) G.Simple:Save(index,s:GetText());end);
  row.choose=button("Выбрать",275,y,82,function(s) G.Simple:Menu(index,s);end);
  row.place=button("summon + stay",367,y,168,function() G.Simple:Place(index);end);
 end
 f.status=label("Каждое нажатие: summon → stay только указанному боту.",25,242,510);f.status:SetHeight(38);f.status:SetJustifyV("TOP");
 self.menu=CreateFrame("Frame","UnBotSimplePostsMenu",UIParent,"UIDropDownMenuTemplate");
 UISpecialFrames=UISpecialFrames or {};table.insert(UISpecialFrames,"UnBotSimplePostsFrame");
 f:Hide();
end

function G:Show()
 self.Simple:Show();
end
function G:CreateUI()
 if InCombatLockdown() then return; end
 local f=CreateFrame("Frame","UnBotGuardPostsFrame",UIParent,"SecureHandlerBaseTemplate"); self.frame=f;
 f:SetWidth(600); f:SetHeight(650); f:SetPoint("CENTER",UIParent,"CENTER",0,0);
 f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton");
 f:SetScript("OnDragStart",function(s) if not InCombatLockdown() then s:StartMoving(); end end); f:SetScript("OnDragStop",function(s) if not InCombatLockdown() then s:StopMovingOrSizing(); end end);
 f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=32,insets={left=11,right=12,top=12,bottom=11}});
 local function label(text,x,y,width,style)
  local t=f:CreateFontString(nil,"OVERLAY",style or "GameFontHighlightSmall"); t:SetPoint("TOPLEFT",f,"TOPLEFT",x,y); t:SetWidth(width); t:SetJustifyH("LEFT"); t:SetText(text); return t;
 end
 local function button(text,x,y,width,fn)
  local b=CreateFrame("Button",nil,f,"UIPanelButtonTemplate"); b:SetWidth(width); b:SetHeight(26); b:SetPoint("TOPLEFT",f,"TOPLEFT",x,y); b:SetText(text); b:SetScript("OnClick",fn); return b;
 end
 local function check(text,y,key)
  local b=CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate"); b:SetWidth(24); b:SetHeight(24); b:SetPoint("TOPLEFT",f,"TOPLEFT",24,y);
  local t=label(text,52,y-5,515); b:SetScript("OnClick",function(s) local p=G:Point(); if p then p[key]=s:GetChecked() and true or false; end; G:Refresh(); end); return b,t;
 end
 label("Расстановка — пост охраны",26,-22,530,"GameFontNormalLarge");
 -- A dedicated header hit area makes dragging reliable without covering close/controls.
 f.dragHandle=CreateFrame("Frame",nil,f);
 f.dragHandle:SetWidth(535); f.dragHandle:SetHeight(40);
 f.dragHandle:SetPoint("TOPLEFT",f,"TOPLEFT",12,-10);
 f.dragHandle:EnableMouse(true); f.dragHandle:RegisterForDrag("LeftButton");
 f.dragHandle:SetScript("OnDragStart",function() if not InCombatLockdown() then f:StartMoving(); end end);
 f.dragHandle:SetScript("OnDragStop",function() if not InCombatLockdown() then f:StopMovingOrSizing(); end end);
 local close=CreateFrame("Button",nil,f,"UIPanelCloseButton,SecureHandlerClickTemplate"); f.close=close;
 -- Set visuals explicitly: inherited secure templates may not retain the close skin.
 close:SetWidth(32); close:SetHeight(32);
 close:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up");
 close:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down");
 close:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight","ADD");
 close:ClearAllPoints();
 close:SetPoint("TOPRIGHT",f,"TOPRIGHT",-5,-5); close:RegisterForClicks("LeftButtonUp");
 close:SetFrameRef("panel",f); close:SetAttribute("_onclick",'self:GetFrameRef("panel"):Hide()');
 label("Посты ботов и запись точек арены.",26,-53,355);
 label("Бот",26,-86,55,"GameFontNormal");
 f.bot=button("Выберите бота",85,-78,330,function(s) G:Menu("bot",s); end);
 f.refresh=button("Обновить",425,-78,145,function() G:Show(); end);
 label("Точка",26,-120,55,"GameFontNormal");
 f.slots={};
 for i=1,3 do local slot=i; f.slots[i]=button("Точка "..i,85+(i-1)*58,-112,54,function() if not G.op and not G.cleanup then G.slot=slot; G:Refresh(); end end); end
 f.point=f.slots[1];
 f.pointInfo=label("",267,-119,300); f.pointInfo:SetHeight(30); f.pointInfo:SetJustifyV("TOP");
 f.aggressive=check("Атаковать ближайших врагов — nc +aggressive",-151,"aggressive");
 f.raid=check("Снять активную тактику рейда на время поста (naxx / icc и др.)",-180,"disableRaid");
 label("Одиночный переход: stay снимается; при смене поста и в группе stay включён.\nНа пути снимаются follow/formation/passive/guard и режимы ухода от боя.\nLoot/gather не меняются. Группа: aggressive включается после прибытия.",26,-215,544);
 f.define=button("1. Подготовить",26,-270,170,function() G:Define(); end);
 f.cast=CreateFrame("Button","UnBotGuardPostsCast",f,"UIPanelButtonTemplate,SecureActionButtonTemplate");
 f.cast:SetWidth(170); f.cast:SetHeight(26); f.cast:SetPoint("TOPLEFT",f,"TOPLEFT",207,-270); f.cast:SetText("Прицел Aedm");
 f.cast:RegisterForClicks("LeftButtonUp");
 f.cast:SetAttribute("checkselfcast",false); f.cast:SetAttribute("checkfocuscast",false);
 f.cast:SetAttribute("*type1","spell"); f.cast:SetAttribute("*spell1",30758);
 f.cast:SetScript("PreClick",function(button) G:CastPreClick(button); end);
 f.cast:SetScript("PostClick",function() G:CastPostClick(); end);
 f.show=button("Показать метку",388,-270,182,function() G:ShowPoint(); end);
 f.accept=button("Метка верна",26,-306,170,function() G:ConfirmPoint(); end);
 f.deploy=button("2. Отправить",207,-306,170,function() G:Deploy(); end);
 f.confirm=button("3. На месте — охранять",388,-306,182,function() G:ConfirmArrival(); end);
 f.inspect=button("Проверить позицию",26,-342,170,function() G:Inspect(); end);
 f.restore=button("Снять пост / вернуть стратегии",207,-342,238,function() G:Restore(); end);
 f.stop=button("Стоп",456,-342,114,function() G:Stop(); end);
 f.status=label("",26,-381,544); f.status:SetHeight(52); f.status:SetJustifyV("TOP");
 label("Трое: подтвердите каждому точку выше и запомните его в своей строке.",26,-440,544);
 f.groupRows={};for i=1,3 do local row=i;f.groupRows[i]=button(i..". Запомнить выбранного",26+(i-1)*181,-466,174,function() G:BindGroup(row);end);end
 f.groupPrepare=button("1. Подготовить троих",26,-502,174,function() G:GroupBegin();end);
 f.groupSend=button("2. Отправить троих",207,-502,174,function() G:GroupSend();end);
 f.groupHold=button("3. Все на месте",388,-502,182,function() G:GroupHold();end);
 f.groupReturn=button("Вернуть троих на точки",26,-538,265,function() G:GroupSend(true);end);
 f.groupRestore=button("Снять посты троих",305,-538,265,function() G:GroupBegin(true);end);
 label("Назначение — сохранённая метка. Удержание — stay. При смене боя\nпривязка восстанавливается до 2 раз на бота в течение 10 минут. Стоп отменяет контроль.",26,-578,544);
 label("Крестик скрывает окно. Точки сохраняются после /reload.\nВозврат после отбрасывания зависит от серверного stay; проверьте на обычном мобе.",26,-612,544);
 self.menu=CreateFrame("Frame","UnBotGuardPostsMenu",UIParent,"UIDropDownMenuTemplate");
 if self.Presets then self.Presets:CreateUI();end
 -- A secure launcher can reveal the pre-created protected panel during combat.
 local launcher=CreateFrame("Button","UnBotGuardPostsLauncher",UIParent,"UIPanelButtonTemplate,SecureHandlerClickTemplate"); self.launcher=launcher;
 launcher:SetWidth(125); launcher:SetHeight(26); launcher:SetPoint("BOTTOMRIGHT",UIParent,"BOTTOMRIGHT",-40,150); launcher:SetText("Посты ботов");
 launcher:RegisterForClicks("LeftButtonUp"); launcher:SetFrameRef("panel",f);
 launcher:SetAttribute("_onclick",'local panel=self:GetFrameRef("panel"); if panel:IsShown() then panel:Hide(); else panel:Show(); end');
 launcher:SetScript("PostClick",function() if f:IsShown() then G:PrepareView(); end end);
 launcher:Hide();self.launcherPolicy=nil;self:RefreshLauncher();
 f:SetScript("OnShow",function() G:PrepareView(); end);
end
G.events=CreateFrame("Frame","UnBotGuardPostsEvents");
for _,event in ipairs({"CHAT_MSG_WHISPER","CHAT_MSG_SYSTEM","UNIT_SPELLCAST_SENT","UNIT_SPELLCAST_SUCCEEDED","UNIT_SPELLCAST_FAILED","UNIT_SPELLCAST_INTERRUPTED","COMBAT_LOG_EVENT_UNFILTERED","PLAYER_LOGOUT","SPELLS_CHANGED","PLAYER_LOGIN","PLAYER_REGEN_ENABLED","PARTY_MEMBERS_CHANGED","RAID_ROSTER_UPDATE","PLAYER_ENTERING_WORLD","ZONE_CHANGED_NEW_AREA","UI_ERROR_MESSAGE"}) do G.events:RegisterEvent(event); end
G.events:SetScript("OnEvent",function(_,event,...)
 if event=="CHAT_MSG_WHISPER" then G:Reply(...);
 elseif event=="CHAT_MSG_SYSTEM" then G:System(...);
 elseif event=="UNIT_SPELLCAST_SENT" or event=="UNIT_SPELLCAST_SUCCEEDED" or event=="UNIT_SPELLCAST_FAILED" or event=="UNIT_SPELLCAST_INTERRUPTED" then
  local unit,spell,rank,line,id=...;
  if unit=="player" and G.op and G.op.kind=="point" and (tonumber(id)==30758 or (GetSpellInfo and spell==GetSpellInfo(30758))) then
   G:Log("cast_event",event.." | "..tostring(spell).." | "..tostring(rank).." | "..tostring(line).." | "..tostring(id),G.op.name);
   if event=="UNIT_SPELLCAST_SENT" then G:Picked("sent");
   elseif event=="UNIT_SPELLCAST_SUCCEEDED" then G:Picked("spell");
   else G.op.castSignal=nil; end
  end
  elseif event=="SPELLS_CHANGED" or event=="PLAYER_REGEN_ENABLED" or event=="PLAYER_LOGIN"
  or event=="PARTY_MEMBERS_CHANGED" or event=="RAID_ROSTER_UPDATE" or event=="PLAYER_ENTERING_WORLD" or event=="ZONE_CHANGED_NEW_AREA" then G:EnsureUI(); G:Refresh();
   if event=="PLAYER_REGEN_ENABLED" and G.Presets and G.Presets.Quick then G.Presets.Quick:DeployCombatEnd();end
 elseif event=="UI_ERROR_MESSAGE" then
  if G.op and G.op.kind=="point" and G.op.phase=="click" then G:Log("cast_error",tostring((...)),G.op.name); end
 elseif event=="COMBAT_LOG_EVENT_UNFILTERED" then
  local _,kind,source,sourceName,_,dest,destName,_,spell,spellName=...;
   if G.Presets and G.Presets.Quick then G.Presets.Quick:DeployCombat(kind,source,sourceName,dest,destName,spell);end
  if G.Presets and G.Presets.Manual then G.Presets.Manual:AoeCombat(kind,source,sourceName,dest,destName,spell);end
  if G.Presets and G.Presets.Hunters then G.Presets.Hunters:Combat(kind,source,sourceName,dest,destName,spell);end
  local watch=G.observe;
  if watch and GetTime()<watch.untilAt and watch.owner==G:Owner() and watch.context==G:Context() and dest==watch.guid
   and (kind=="SPELL_CAST_SUCCESS" or kind=="SPELL_DAMAGE") then
   G:Log("combat",tostring(kind).." "..tostring(sourceName).." -> "..watch.name.." "..tostring(spell).." "..tostring(spellName),watch.name);
  end
 elseif event=="PLAYER_LOGOUT" then if G.op then G:Log("interrupted",G.op.kind,G.op.name); end end
end);
G.events:SetScript("OnUpdate",function(_,elapsed)
 G.elapsed=(G.elapsed or 0)+elapsed; if G.elapsed>=0.1 then G.elapsed=0; G:Tick(); end
end);
function G:Slash(message)
 local action,rest=tostring(message or ""):match("^%s*(%S+)%s*(.-)%s*$"); action=action and action:lower();
 if action=="quick" and self.Presets then self.Presets.Quick:Open();return;end
 if action=="hunters" and self.Presets then self.Presets.Hunters:Show();return;end
 if action=="presets" and self.Presets then self.Presets:Toggle();return;end
 if action=="hold" then self:ConfirmArrival(); return; end
 if action=="accept" then self:ConfirmPoint(); return; end
 if action=="go" or action=="set" then
  local name,slot=rest:match("^(%S+)%s+([123])$");
  if not name then slot=rest:match("^([123])$"); name=self.bot or self:Store().lastBot; end
  if not slot or not name or not self:Unit(name) then self:Status("Команда: /ubguard "..action.." Имя 1 (точки 1–3).",true); return; end
  if self.op or self.cleanup then self:Status("Сначала завершите текущий шаг или нажмите «Стоп».",true); return; end
  self:Select(name); self.slot=tonumber(slot); self:Refresh();
  if action=="go" then self:Deploy(); else self:Define(); end
 elseif action=="off" then
  if self.op or self.cleanup then self:Status("Сначала завершите текущий шаг или нажмите «Стоп».",true); return; end
  local name=rest~="" and rest or self.bot or self:Store().lastBot;
  if not name or not self:Unit(name) then self:Status("Укажите живого бота своей группы: /ubguard off Имя.",true); return; end
  self:Select(name); self:Restore();
 else self:Show(); end
end
SLASH_UNBOTGUARDPOSTS1="/ubguard";
SlashCmdList["UNBOTGUARDPOSTS"]=function(message) G:Slash(message); end;

-- Configure protected frames before combat; never summon or send a bot command at startup.
G:EnsureUI();
