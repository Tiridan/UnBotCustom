-- Player-only Gluth arena notes. Map coordinates are deliberately not world XYZ.
local G=UnBotGuardPosts;
G.Presets={};
local P=G.Presets;
P.roles={{key="door",label="Дверь"},{key="right_grate",label="Решётка справа"},{key="left_grate",label="Решётка слева"},{key="center",label="Центр"}};
function P:Current(create)
 local root=UnBotSquadConfig and UnBotSquadConfig.guardPosts;
 local owner=root and root.owners and root.owners[G:Owner()];
 if create then owner=G:Store();owner.presets=owner.presets or {};end
 local context=G:Context();
 if not owner then return;end
 if create then owner.presets[context]=owner.presets[context] or {items={}};end
 local s=owner.presets and owner.presets[context];if not s then return;end
 if create then
  s.items=s.items or {};s.items.Gluth=s.items.Gluth or {id="Gluth",name="Глут",points={}};
  s.items.Gluth.points=s.items.Gluth.points or {};s.selected="Gluth";
 end
 return s.items and s.items.Gluth;
end
function P:MapPosition()
 if not GetPlayerMapPosition or not GetMapInfo or not GetCurrentMapDungeonLevel then return;end
 local x,y=GetPlayerMapPosition("player");
 if type(x)~="number" or type(y)~="number" or x~=x or y~=y or x<0 or x>1 or y<0 or y>1 or (x==0 and y==0) then return;end
 return {x=x,y=y,mapFile=GetMapInfo(),floor=GetCurrentMapDungeonLevel(),
  mapAreaId=GetCurrentMapAreaID and GetCurrentMapAreaID() or nil,
  zone=GetRealZoneText(),subZone=GetSubZoneText and GetSubZoneText() or nil,
  source="player_map",at=time()};
end
function P:Record(index)
 if not self.roles[index] then return;end
 if (G.op and G.op.door) or (G.batch and G.batch.gluth) then self:Message("Сначала завершите отправку танка или нажмите «Стоп».");return;end
 if SetMapToCurrentZone then SetMapToCurrentZone();end
 local position=self:MapPosition();
 if not position then self:Message("Клиент не отдал позицию игрока. Встаньте на площадку и повторите запись.");return;end
 if position.mapFile~="Naxxramas" or position.floor~=1 then
  self:Message("Эти три точки — для арены Глута: Наксрамас, этаж 1 (квартал Мерзости).");return;
 end
 local d=self:Current(true);local point=d.points[index] or {};
 point.role=self.roles[index].key;point.label=self.roles[index].label;point.mapPoint=position;
 -- An explicit new player sample invalidates only a previous conversion, not unrelated fields.
 point.world=nil;point.key=nil;d.points[index]=point;d.updatedAt=time();
 G:Log("gluth_player_point",string.format("%d %s | %.9f %.9f | %s floor %s",index,point.label,position.x,position.y,position.mapFile,tostring(position.floor)),UnitName("player"));
 self:Message(string.format("Точка %d — %s записана: X %.5f%%, Y %.5f%%; этаж %d.",index,point.label,position.x*100,position.y*100,position.floor));
end
function P:Message(text)
 self.status=text;self:Refresh();
 if UnBotSpecSummonMessage then UnBotSpecSummonMessage("Точки Глута: "..text);end
end

-- Naxx floor 1: local QuestieCompat.UiMapData[162], also matching DBM map size.
-- Client/map axes are swapped relative to the raw server XYZ convention.
function P:WorldXY(p)
 if type(p)~="table" or p.mapFile~="Naxxramas" or p.floor~=1 or p.mapAreaId~=536
  or type(p.x)~="number" or type(p.y)~="number" or p.x~=p.x or p.y~=p.y
  or p.x<0 or p.x>1 or p.y<0 or p.y>1 or (p.x==0 and p.y==0) then return;end
 return {x=3615.830078125-p.y*729.2199707031,y=-2640.2700195312-p.x*1093.830078125,map=533};
end
function P:ParseWorld(text)
 local x,y,z,map,o,tail=text:match("^%s*(%S+)%s+(%S+)%s+(%S+)%s+(%d+)%s+(%S+)%s*(.-)%s*$");
 if not x or (tail~="" and not tail:match("^|[^|]*|$")) then return;end
 local w={x=tonumber(x),y=tonumber(y),z=tonumber(z),map=tonumber(map),orientation=tonumber(o)};
 for _,key in ipairs({"x","y","z","orientation"}) do local n=w[key];if not n or n~=n or math.abs(n)>20000 then return;end end
 if not w.map or w.map>65535 then return;end;return w;
end
function P:DoorPoint(index)
 local d=self:Current();return d and d.points and d.points[index or 1];
end
function P:Signature(p)
 if not self:WorldXY(p) then return;end
 return string.format("gluth_door_%.12f_%.12f",p.x,p.y);
end
function P:Distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2);end
function P:Anchor(w)
 -- Server PositionAction uses integer atoi; nearest yard, with correct negative rounding.
 return string.format("position stay %d,%d,%d",math.floor(w.x+.5),math.floor(w.y+.5),math.floor(w.z+.5));
end
function P:Tank(index)
 local d=self:Current();return d and d.bindings and d.bindings[index or 1] and d.bindings[index or 1].name;
end
function P:DebugActive() return UnBotDiagnostics and UnBotDiagnostics.raid and UnBotDiagnostics.raid.current;end
function P:Idle() return not (G.op or G.batch or G.cleanup or G:Busy() or self:DebugActive());end
function P:RosterUnit(name)
 -- Presence differs from G:Unit: an offline/dead member still belongs to the roster.
 for i=1,(GetNumRaidMembers()>0 and GetNumRaidMembers() or GetNumPartyMembers()) do
  local u=(GetNumRaidMembers()>0 and "raid" or "party")..i;
  if G:Key(UnitName(u))==G:Key(name) then return u;end
 end
end
function P:DetachAbsentTank(name,index)
 index=index or 1;
 if self:RosterUnit(name) or G:Key(self:Tank(index))~=G:Key(name) then return false;end
 local d=self:Current();local rec=G:Store().recovery[G:Key(name)];
 if rec and rec.door then rec.door.active=false;rec.door.detachedAt=time();end
 local watch=G.groupWatch;
 if watch and watch.door then
  for i=#watch.entries,1,-1 do if G:Key(watch.entries[i].name)==G:Key(name) then table.remove(watch.entries,i);end end
  if #watch.entries==0 then G.groupWatch=nil;end
 end
 -- Keep the former bot's original/applied strategies for a later explicit restore.
 if d and d.bindings and d.bindings[index] then d.bindings[index].name=nil;end
 G:Log("gluth_door_detach","Бот вышел из группы; привязка снята, точка и снимок стратегий сохранены.",name);
 return true;
end
function P:SelectTank(name,index)
 index=index or 1;if not self.roles[index] then return;end
 if not self:Idle() or not G:Unit(name) then return;end
 local d=self:Current();if not d then self:Message("Сначала запишите точку двери.");return;end
 for i=1,3 do if i~=index and G:Key(self:Tank(i))==G:Key(name) then self:Message("Этот танк уже назначен на другую точку. Сначала снимите прежний пост.");return;end end
 local previous=self:Tank(index);local rec=previous and G:Store().recovery[G:Key(previous)];
 if previous and G:Key(previous)~=G:Key(name) and rec then
  if self:RosterUnit(previous) then self:Message("Сначала снимите пост прежнего танка: он ещё в группе. Координаты точек останутся.");return;end
  self:DetachAbsentTank(previous,index);
 end
 d.bindings=d.bindings or {};d.bindings[index]=d.bindings[index] or {};d.bindings[index].name=name;
 local detail=previous and G:Key(previous)~=G:Key(name) and rec and " Прежний бот вышел из группы; его снимок стратегий сохранён." or "";
 self:Message(name.." выбран: "..self.roles[index].label..". Движение ещё не отправлялось."..detail);
end
function P:TankMenu(anchor,index)
 index=index or 1;
 if not self:Idle() then return;end
 local menu={};for _,n in ipairs(G:Bots()) do local name=n;if G:Unit(name) then
  menu[#menu+1]={text=name,notCheckable=true,func=function() P:SelectTank(name,index);end};
 end end
 if #menu==0 then menu[1]={text="Нет живых онлайн-ботов в группе",disabled=true,notCheckable=true};end
 EasyMenu(UnBotLocale and UnBotLocale.Menu(menu) or menu,self.menu,anchor,0,0,"MENU",2);
end
function P:ValidateDoor(op)
 if op.manual then return self.Manual:Valid(op);end
 local p=self:DoorPoint(op.doorIndex);
 if not p or p.mapPoint~=op.sourcePoint or self:Signature(p.mapPoint)~=op.targetKey or G:Key(self:Tank(op.doorIndex))~=G:Key(op.name) then return false,"сменились точка двери или назначенный танк";end
 return true;
end
function P:OperationEnded(op)
 if op and op.doorRestore and not G:Store().recovery[G:Key(op.name)] then
  local d=self:Current();local i=op.doorIndex or 1;
  if d and d.bindings and d.bindings[i] and G:Key(d.bindings[i].name)==G:Key(op.name) then d.bindings[i].name=nil;end
 end
 if op and (op.door or op.doorRestore) then self.doorActive=nil;self:Refresh();end
 if op and op.quickLock and op.quickComplete and op.quickWorld then
  local q=self.Quick;q.locks=q.locks or {};
  if op.quickHealer then q.healerLock={name=op.name,guid=op.guid,world=G:Copy(op.quickWorld),owner=op.owner,context=op.context};
  else
   q.locks[op.quickIndex]={name=op.name,guid=op.guid,world=G:Copy(op.quickWorld),owner=op.owner,context=op.context,repairs=0};
   P.Manual:AoeToggle(op.quickIndex);
  end
  q:Notice(op.name..": закреплён — "..tostring(op.quickLabel)..(op.quickIndex==1 and "; начал атаку Глута с места." or "; преследование целей выключено."));
 end
 if op and op.quickRestore and self.Quick then self.Quick:RestoreNext();end
end
function P:ValidateSample(op,w)
 if w.map~=533 then return false,"бот на другой серверной карте";end
 SetMapToCurrentZone();
 local unit=G:Unit(op.name);local x,y=GetPlayerMapPosition(unit);
 local mapped=self:WorldXY({x=x,y=y,mapFile=GetMapInfo(),floor=GetCurrentMapDungeonLevel(),mapAreaId=GetCurrentMapAreaID and GetCurrentMapAreaID()});
 if not mapped then return false,"не видна позиция танка на первом этаже Наксрамаса";end
 local residual=self:Distance(mapped,w);
 G:Log("gluth_door_conversion",string.format("server %.4f %.4f | mapped %.4f %.4f | error %.3f",w.x,w.y,mapped.x,mapped.y,residual),op.name);
 if residual>3 then return false,string.format("перевод карты не подтверждён: расхождение %.1f ярда",residual);end
 return true;
end
function P:PrepareDoor(index,group)
 index=index or 1;if not self.roles[index] then return;end
 if not group and not self:Idle() then self:Message("Сначала завершите текущую операцию или нажмите «Стоп».");return;end
 local point=self:DoorPoint(index);local destination=point and self:WorldXY(point.mapPoint);local name=self:Tank(index);
 if not destination then self:Message("Нужна записанная точка Naxxramas, карта клиента 536, этаж 1.");return;end
 if not name or not G:Unit(name) then self:Message("Выберите живого танка своей группы.");return;end
 self:RemoveWatch(name);G.bot=name;G.slot=index;self.doorActive=true;
 local op=G:Begin("gluth_door",false,{gluth=true,aggressive=point.aggressive~=false,disableRaid=point.disableRaid==true});
 if not op then self.doorActive=nil;self:Refresh();return;end
 op.door=true;op.doorIndex=index;op.group=group and true or false;op.sourcePoint=point.mapPoint;op.targetKey=self:Signature(point.mapPoint);op.destination=destination;
 op.expires=GetTime()+120;
 G:Read("co",function() G:Read("nc",function()
  local wanted=G:Wanted(op,true);wanted.nc.aggressive=false;
  if not G:Remember(op,wanted) then return;end
  G:Apply("co",wanted.co,function() G:Apply("nc",wanted.nc,function()
   -- This explicit stay also stops the current route before comparing map/server samples.
   G:Job("stay","stay",function()
    G:Job("cdebug position","world",function(w)
     local ok,why=P:ValidateSample(op,w);if not ok then G:Stop("Движение отменено: "..why..". Снимок стратегий сохранён.");return;end
     if P:Distance(w,op.destination)>120 then G:Stop("Танк дальше 120 ярдов от своей точки. Для пробы подведите его на арену.");return;end
     -- The recorder has no player Z. Use the selected tank's observed floor height for this flat-room trial.
     op.destination.z=w.z;
     local rec=G:Store().recovery[G:Key(op.name)];rec.door=rec.door or {};
     for k,v in pairs(op.destination) do rec.door[k]=v;end
     rec.door.key=op.targetKey;rec.door.index=index;rec.door.active=false;rec.targetKey=op.targetKey;
     if group then
      G.batch.entries[index].destination=G:Copy(op.destination);
      G:Done(op.name..": "..P.roles[index].label.." — подготовлен, движение не запущено.");return;
     end
     G:Job(P:Anchor(op.destination),"anchorSet",function()
      G:Job(string.format("go %.6f;%.6f;%.6f",op.destination.x,op.destination.y,op.destination.z),nil,function()
       op.phase="door_arrival";op.expires=GetTime()+60;
       G:Status(op.name..": отправлен: "..P.roles[index].label..". Когда визуально дойдёт — «На месте — закрепить».",true);
      end);
     end);
    end);
   end);
  end);end);
 end);end);
 G:Status("Танк "..op.name..": сохраняю co/nc, останавливаю маршрут и проверяю перевод карты перед отправкой.",true);
end
function P:HoldDoor()
 if self:DebugActive() then self:Message("Сначала завершите дебаг рейда, затем подтвердите прибытие.");return;end
 local op=G.op;if not op or not op.door or op.phase~="door_arrival" then return;end
 local ok,why=G:Valid(op);if not ok then G:Stop(why);return;end
 op.phase="door_hold";op.expires=GetTime()+60;
 G:Job("cdebug position","world",function(w)
  local valid,reason=P:ValidateSample(op,w);if not valid then G:Stop(reason);return;end
  if math.abs(w.z-op.destination.z)>5 then G:Stop("Высота танка изменилась больше чем на 5 ярдов. Для этой пробы нужна та же ровная площадка.");return;end
  local distance=P:Distance(w,op.destination);
  if distance>3 then G:Stop(string.format("%s ещё в %.1f ярдах от своей точки. Закрепление не подтверждено; исходная точка сохранена.",op.name,distance));return;end
  op.destination.z=w.z;
  G:Job(P:Anchor(op.destination),"anchorSet",function()
   G:Read("co",function() G:Read("nc",function()
    local wanted=G:Wanted(op,true);
    G:Apply("co",wanted.co,function() G:Apply("nc",wanted.nc,function()
     local rec=G:Store().recovery[G:Key(op.name)];rec.door.z=w.z;rec.door.active=true;
     P:Watch(op);
     G:Done(op.name..": закреплён: "..P.roles[op.doorIndex or 1].label.."; co/nc stay включён, выбранный aggressive применён.");
    end);end);
   end);end);
  end);
 end);
 G:Status("Проверяю прибытие танка на свою точку (до 3 ярдов) и закрепляю исходную точку.",true);
end
function P:WatchedDoor(w,e)
 if e.manual then return self.Manual:Watched(e);end
 local p=self:DoorPoint(e.slot);local rec=G:Store().recovery[G:Key(e.name)];
 if p and self:Signature(p.mapPoint)==e.key and G:Key(self:Tank(e.slot))==G:Key(e.name) and rec and rec.door and rec.door.key==e.key then return rec.door;end
end
function P:ReleaseDoor(index)
 index=index or 1;
 if not self:Idle() then self:Message("Сначала завершите шаг или нажмите «Стоп».");return;end
 local name=self:Tank(index);if not name then return;end
 if self:DetachAbsentTank(name,index) then
  self:Message(name.." уже вышел из группы: привязка снята. Координаты точки и снимок его стратегий сохранены; выберите нового танка.");return;
 end
 self:RemoveWatch(name);
 G.bot=name;self.doorActive=true;G:Restore({gluth=true});
 if G.op then G.op.doorRestore=true;G.op.doorIndex=index;else self.doorActive=nil;self:Refresh();end
end


function P:RemoveWatch(name)
 local w=G.groupWatch;if not w or not w.door then return;end
 for i=#w.entries,1,-1 do if G:Key(w.entries[i].name)==G:Key(name) then table.remove(w.entries,i);end end
 if #w.entries==0 then G.groupWatch=nil;end
end
function P:Watch(op)
 self:RemoveWatch(op.name);
 local w=G.groupWatch;
 if not w or not w.door or w.owner~=op.owner or w.context~=op.context then
  w={door=true,owner=op.owner,context=op.context,entries={}};G.groupWatch=w;
 end
 w.untilAt=GetTime()+600;w.nextAt=GetTime()+1;
 w.entries[#w.entries+1]={name=op.name,guid=op.guid,slot=op.doorIndex or 1,key=op.targetKey,anchorCommand=self:Anchor(op.destination),
  combat=UnitAffectingCombat(G:Unit(op.name)) and true or false,attempts=0,lastSent=GetTime()};
end
function P:GroupValid(b)
 if b.owner~=G:Owner() or b.context~=G:Context() then return false,"сменились персонаж или зона";end
 for _,e in ipairs(b.entries) do
  local ok,why=G:Valid(e);if not ok then return false,e.name..": "..why;end
 end
 return true;
end
function P:GroupBegin()
 if not self:Idle() then self:Message("Сначала завершите текущий шаг или нажмите «Стоп».");return;end
 local entries,seen={},{};
 for i=1,3 do
  local point=self:DoorPoint(i);local name=self:Tank(i);local unit=name and G:Unit(name);
  if not unit or not UnitGUID(unit) or seen[G:Key(name)] or not point or not self:WorldXY(point.mapPoint) then
   self:Message("Назначьте трёх разных живых танков: дверь, правая и левая решётки. Все три точки должны быть записаны.");return;
  end
  seen[G:Key(name)]=true;
  entries[i]={name=UnitName(unit),guid=UnitGUID(unit),owner=G:Owner(),context=G:Context(),door=true,doorIndex=i,
   sourcePoint=point.mapPoint,targetKey=self:Signature(point.mapPoint),point={gluth=true,aggressive=point.aggressive~=false,disableRaid=point.disableRaid==true}};
 end
 G.batch={gluth=true,entries=entries,owner=G:Owner(),context=G:Context(),phase="prepare",index=1,expires=GetTime()+180,
  previousBot=G.bot,previousSlot=G.slot};G.groupWatch=nil;
 self:GroupStep();
end
function P:GroupStep()
 local b=G.batch;if not b or not b.gluth then return;end
 local ok,why=self:GroupValid(b);if not ok then G:Stop("Расстановка остановлена: "..why);return;end
 local e=b.entries[b.index];G.groupWorking=true;
 if b.phase=="prepare" then self:PrepareDoor(e.doorIndex,true);
 elseif b.phase=="hold" then
  G.bot=e.name;G.slot=e.doorIndex;self.doorActive=true;
  local op=G:Begin("gluth_hold",false,e.point);
  if op then
   op.door=true;op.doorIndex=e.doorIndex;op.group=true;op.sourcePoint=e.sourcePoint;op.targetKey=e.targetKey;
   op.destination=G:Copy(e.destination);op.phase="door_arrival";self:HoldDoor();
  end
 end
 G.groupWorking=nil;
 if G.batch==b and not G.op then G:Stop("Не удалось начать шаг расстановки. Снимки стратегий сохранены.");end
end
function P:GroupStepDone()
 local b=G.batch;if not b or not b.gluth then return;end
 b.index=b.index+1;
 if b.index<=3 then self:GroupStep();return;end
 G.bot,G.slot=b.previousBot,b.previousSlot;
 if b.phase=="prepare" then
  b.phase="armed";b.expires=GetTime()+120;self:Message("Трое готовы. «Отправить троих» запустит движение к двери и двум решёткам вместе.");
 else
  G.batch=nil;self:Message("Три танка закреплены: дверь, правая и левая решётки. Исходные точки сохранены.");
 end
end
function P:GroupSend()
 local b=G.batch;if not b or not b.gluth or b.phase~="armed" or G.op then return;end
 local ok,why=self:GroupValid(b);if not ok then G:Stop("Общая отправка отменена: "..why);return;end
 for _,e in ipairs(b.entries) do
  local rec=G:Store().recovery[G:Key(e.name)];
  if not e.destination or not rec or rec.guid~=e.guid or not rec.door or rec.door.key~=e.targetKey then
   G:Stop("Подготовка назначения потеряна: "..e.name..". Повторите подготовку.");return;
  end
 end
 b.phase="launch_ack";b.expires=GetTime()+7;b.acks={};
 -- Position stay can itself start movement: dispatch ALL anchors in this tick,
 -- then ALL raw GO commands, without serial anchor waits or arrival barriers.
 for _,e in ipairs(b.entries) do
  G:Log("gluth_group_anchor",self:Anchor(e.destination),e.name);SendChatMessage(self:Anchor(e.destination),"WHISPER",nil,e.name);
 end
 for _,e in ipairs(b.entries) do
  G:Log("gluth_group_go",self.roles[e.doorIndex].label,e.name);
  SendChatMessage(string.format("go %.6f;%.6f;%.6f",e.destination.x,e.destination.y,e.destination.z),"WHISPER",nil,e.name);
  self:Watch(e);
 end
 G.nextSend=GetTime()+G.interval;
 self:Message("Трое отправлены одновременно по своим точкам. Жду подтверждения якорей; затем дождитесь прибытия и нажмите «Все на месте».");
end
function P:GroupReply(message,sender)
 local b=G.batch;if not b or not b.gluth or b.phase~="launch_ack" then return false;end
 local text=tostring(message or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):lower();
 if text~="position stay is set" then return false;end
 local ok,why=self:GroupValid(b);if not ok then G:Stop("Расстановка остановлена: "..why);return true;end
 for i,e in ipairs(b.entries) do if G:Key(e.name)==G:Key(sender) then b.acks[i]=true;G:Log("gluth_group_anchor_ack",text,e.name);end end
 if b.acks[1] and b.acks[2] and b.acks[3] then
  b.phase="arrival";b.expires=GetTime()+120;self:Message("Якоря троих подтверждены. Когда все дойдут — «Все на месте».");
 end
 return true;
end
function P:GroupHold()
 local b=G.batch;if not b or not b.gluth or b.phase~="arrival" or G.op then return;end
 b.phase="hold";b.index=1;b.expires=GetTime()+180;self:GroupStep();
end

function P:Refresh()
 if self.Quick then self.Quick:Refresh();end
 if self.frame and self.frame.manual then self.Manual:Refresh();return;end
 local f=self.frame;if not f then return;end
 local d=self:Current();local count=0;
 for i,row in ipairs(f.rows) do
  local p=d and d.points and d.points[i];local w=p and p.mapPoint;
  if w then
   count=count+1;
   row.info:SetText(string.format("X %.5f%%   Y %.5f%%\n%s · этаж %d",w.x*100,w.y*100,w.mapFile,w.floor));
   row.marker:SetText("|cff55ff77"..i..". "..self.roles[i].label.." — записано|r");
   row.button:SetText(i..". Перезаписать: "..self.roles[i].label);
  else
   row.info:SetText("Ещё не записано");row.marker:SetText("|cffaaaaaa"..i..". "..self.roles[i].label.."|r");
   row.button:SetText(i..". Записать: "..self.roles[i].label);
  end
 end
 f.count:SetText("Записано "..count.." / 3");
 f.status:SetText(self.status or "Встаньте у двери и нажмите кнопку 1, затем у правой и левой решётки — 2 и 3.");
 self:RefreshDoor();
end

function P:RefreshDoor()
 local f=self.frame;if not f or not f.tank then return;end
 local index=self.selected or 1;local p=self:DoorPoint(index);local name=self:Tank(index);local idle=self:Idle();
 local function enable(b,v) if v then b:Enable();else b:Disable();end end
 for i,button in ipairs(f.pointTabs or {}) do
  local n=self:Tank(i);button:SetText((i==index and "> " or "")..i..". "..({"Дверь","Правая","Левая"})[i]..(n and ": "..n or ""));
  enable(button,not G.op);
 end
 f.tank:SetText(name or "Выбрать танка: "..self.roles[index].label);enable(f.tank,idle);
 f.aggressive:SetChecked(not p or p.aggressive~=false);f.raid:SetChecked(p and p.disableRaid);
 enable(f.aggressive,idle and p);enable(f.raid,idle and p and not (name and G:Store().recovery[G:Key(name)]));
 enable(f.send,idle and p and name);enable(f.hold,not self:DebugActive() and G.op and G.op.door and not G.op.group and G.op.doorIndex==index and G.op.phase=="door_arrival");
 enable(f.release,idle and name and G:Store().recovery[G:Key(name)]);enable(f.stop,G.op or G.batch or G.cleanup or G.groupWatch);
 local b=G.batch;enable(f.prepareThree,idle);enable(f.sendThree,b and b.gluth and b.phase=="armed");
 enable(f.holdThree,b and b.gluth and b.phase=="arrival" and not G.op);
end
function P:DoorUI(label)
 local f=self.frame;
 local function button(text,x,y,width,fn)
  local b=CreateFrame("Button",nil,f,"UIPanelButtonTemplate");b:SetWidth(width);b:SetHeight(26);b:SetPoint("TOPLEFT",f,"TOPLEFT",x,-y);b:SetText(text);b:SetScript("OnClick",fn);return b;
 end
 f.pointTabs={};for i=1,3 do local index=i;
  f.pointTabs[i]=button(self.roles[i].label,25+(i-1)*166,453,158,function() P.selected=index;P:Refresh();end);
 end
 f.tank=button("Выбрать танка",25,490,250,function(s) P:TankMenu(s,P.selected or 1);end);
 f.aggressive=CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate");f.aggressive:SetWidth(24);f.aggressive:SetHeight(24);f.aggressive:SetPoint("TOPLEFT",f,"TOPLEFT",285,-490);
 label("nc +aggressive",311,496,195);f.aggressive:SetScript("OnClick",function(s) local p=P:DoorPoint(P.selected or 1);if p and P:Idle() then p.aggressive=s:GetChecked() and true or false;end;P:Refresh();end);
 f.raid=CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate");f.raid:SetWidth(24);f.raid:SetHeight(24);f.raid:SetPoint("TOPLEFT",f,"TOPLEFT",25,-522);
 label("Временно снять тактику рейда (naxx / icc)",51,528,460);f.raid:SetScript("OnClick",function(s) local p=P:DoorPoint(P.selected or 1);if p and P:Idle() then p.disableRaid=s:GetChecked() and true or false;end;P:Refresh();end);
 f.send=button("1. Отправить на точку",25,560,240,function() P:PrepareDoor(P.selected or 1);end);
 f.hold=button("2. На месте — закрепить",275,560,240,function() P:HoldDoor();end);
 f.release=button("Снять пост / вернуть стратегии",25,595,240,function() P:ReleaseDoor(P.selected or 1);end);
 f.stop=button("Стоп",275,595,240,function() G:Stop();P:Refresh();end);
 f.prepareThree=button("Подготовить троих",25,632,158,function() P:GroupBegin();end);
 f.sendThree=button("Отправить троих",191,632,158,function() P:GroupSend();end);
 f.holdThree=button("Все на месте",357,632,158,function() P:GroupHold();end);
 label("Выберите точку сверху и назначьте ей танка. Общий старт — после подготовки.\nВысота берётся у каждого танка; страх Глута временно нарушает удержание.",25,674,490);
 self.menu=CreateFrame("Frame","UnBotGluthDoorMenu",UIParent,"UIDropDownMenuTemplate");
end

function P:Toggle()
 if not self.frame then self:CreateUI();end
 if not self.frame then return;end
 if self.frame:IsShown() then self.frame:Hide();else self.frame:Show();end
 self:Refresh();
end
function P:EnsureToggle()
 -- The main RTSC panel is protected. Attach its entry only outside combat.
 if self.toggle or not G.frame or InCombatLockdown() then return;end
 local toggle=CreateFrame("Button",nil,G.frame,"UIPanelButtonTemplate");self.toggle=toggle;toggle:SetWidth(170);toggle:SetHeight(24);toggle:SetPoint("TOPRIGHT",G.frame,"TOPRIGHT",-28,-45);toggle:SetText("Точки Глута");toggle:SetScript("OnClick",function() P:Toggle();end);
end
function P:CreateUI() return self.Manual:CreateUI();end

-- Explicit manual placement. Only coordinates are saved; no strategy snapshots or queries.
P.Manual={};

-- Addressed self AoE. Gluth placement itself is deliberately only summon + stay.
P.Manual.aoe={};
P.Manual.castActivity={};
P.Manual.aoeActivity={};
P.Manual.aoeSpells={
 DEATHKNIGHT={name="blood boil",label="Вскипание крови",interval=5,ids={[48721]=true,[49939]=true,[49940]=true,[49941]=true}},
 PALADIN={name="consecration",label="Освящение",interval=9,ids={[26573]=true,[20116]=true,[20922]=true,[20923]=true,[20924]=true,[27173]=true,[48818]=true,[48819]=true}},
};
function P.Manual:AoeStop(index,reason)
 local e=self.aoe[index];if not e then return;end
 self.aoe[index]=nil;
 local text=string.format("%s: АоЕ остановлено (%s). Команд %d, попаданий по зомби %d, ударов зомби по танку %d.",e.name,reason or "вручную",e.sent,e.hits,e.taken);
 G:Log("post_aoe_stop",text,e.name);self:Message(text);
end
function P.Manual:AoeStopBot(name)
 for i=1,#P.roles do local e=self.aoe[i];if e and G:Key(e.name)==G:Key(name) then self:AoeStop(i,"смена или снятие поста");end end
end
function P.Manual:AoeStopAll()
 for i=1,#P.roles do self:AoeStop(i,"Стоп");end
end
function P.Manual:ReleaseHolds()
 local released=0;
 for i=1,#P.roles do local r=self:Record(i);local u=r and r.holdApplied and G:Unit(r.name);
  if u and UnitGUID(u)==r.guid then
   SendChatMessage("follow","WHISPER",nil,r.name);
   r.holdApplied=nil;released=released+1;G:Log("manual_hold_release","follow",r.name);
  end
 end
 return released;
end
function P.Manual:AoeNear(e,u)
 if GetMapInfo()~="Naxxramas" or GetCurrentMapDungeonLevel()~=1 then return false;end
 local x,y=GetPlayerMapPosition(u);
 if type(x)~="number" or type(y)~="number" or x~=x or y~=y or x<=0 or y<=0 or x>1 or y>1 then return false;end
 if e.mapPoint and e.mapPoint.mapFile=="Naxxramas" and e.mapPoint.floor==1 then
  local dx=(x-e.mapPoint.x)*1093.830078125;local dy=(y-e.mapPoint.y)*729.2199707031;
  return dx*dx+dy*dy<=16;
 end
 if not e.world then return false;end
 local dx=3615.830078125-y*729.2199707031-e.world.x;
 local dy=-2640.2700195312-x*1093.830078125-e.world.y;
 return dx*dx+dy*dy<=16;
end
function P.Manual:AoeSend(e)
 local now=GetTime();local command="cast "..e.spell.name.." on "..e.name;
 e.sent=e.sent+1;e.lastCastAt=now;e.pending=now+7;e.nextAt=now+e.spell.interval;
 G.nextSend=math.max(G.nextSend or 0,now+G.interval);
 G:Log("post_aoe_cast",command,e.name);SendChatMessage(command,"WHISPER",nil,e.name);
end
function P.Manual:AoeToggle(index)
 index=index or P.selected or 1;
 if self.aoe[index] then self:AoeStop(index,"вручную");return;end
 if G:Busy() or P:DebugActive() then self:Message("Сначала завершите другую автоматизацию или дебаг.");return;end
 local r=self:Record(index);local u=r and G:Unit(r.name);
  if not r or not r.active or not (r.mapPoint or r.world and r.world.map==533) or not u or UnitGUID(u)~=r.guid then
  self:Message("Сначала призовите танка и запишите его точку.");return;
 end
 local _,class=UnitClass(u);local spell=self.aoeSpells[class];
 if not spell then self:Message("АоЕ поддерживает ДК (blood boil) и паладина (consecration).");return;end
 local now=GetTime();local lastCast=self.castActivity[r.guid] or 0;local lastAoe=self.aoeActivity[r.guid] or 0;
  local e={name=r.name,guid=r.guid,key=r.key,owner=G:Owner(),context=G:Context(),world=r.world,mapPoint=r.mapPoint,
  holdApplied=r.holdApplied,spell=spell,untilAt=now+600,nextAt=math.max(now,lastAoe+spell.interval),
  busyUntil=lastCast+1.8,sent=0,hits=0,taken=0};
 self.aoe[index]=e;
 G:Log("post_aoe_start",spell.name.." on self | direct cast, observed cooldown | 600s / 120 commands",r.name);
 self:Message(r.name..": АоЕ включено — прямой "..spell.label.." под себя. Списки стратегий не читаются. До 10 минут.");
 -- The click enables a direct cast. A recent real cast/GCD only delays it; no co/nc query is involved.
 if UnitAffectingCombat(u) and now>=e.nextAt and now>=e.busyUntil and (not e.holdApplied or self:AoeNear(e,u)) then self:AoeSend(e);
 elseif not UnitAffectingCombat(u) then self:Message(r.name..": АоЕ включено; первая команда при вступлении танка в бой.");
 else self:Message(r.name..": АоЕ включено; прямой каст уйдёт после текущего GCD и возврата на пост.");end
end
function P.Manual:AoeValid(e,index)
 local r=self:Record(index);local u=G:Unit(e.name);
 if e.owner~=G:Owner() or e.context~=G:Context() or not r or not r.active or r.key~=e.key or r.guid~=e.guid
  or not u or UnitGUID(u)~=e.guid then return nil,"пост, состав или зона изменились";end
 if G:Busy() or P:DebugActive() then return nil,"другая операция UnBot или дебаг";end
 return u;
end
function P.Manual:AoeTick()
 local now=GetTime();
 for i=1,#P.roles do
  local e=self.aoe[i];
  if e then
   local u,why=self:AoeValid(e,i);
   if not u then self:AoeStop(i,why);
   elseif now>=e.untilAt or e.sent>=120 and not e.pending then self:AoeStop(i,"лимит 10 минут / 120 команд");
   elseif e.pending and now>=e.pending then self:AoeStop(i,"нет подтверждения заклинания за 7 секунд");
    elseif not e.pending and now>=(G.nextSend or 0) and now>=e.nextAt and now>=(e.busyUntil or 0) then
    -- Instant self AoE follows the bot without changing its movement or active AI.
     if UnitAffectingCombat(u) and (not e.holdApplied or self:AoeNear(e,u))
      and not (UnitCastingInfo and UnitCastingInfo(u))
     and not (UnitChannelInfo and UnitChannelInfo(u)) then self:AoeSend(e);end
   end
  end
 end
 if now>=(self.aoeRefreshAt or 0) and next(self.aoe) then self.aoeRefreshAt=now+1;self:Refresh();end
end
function P.Manual:AoeSystem(message)
 local text=tostring(message or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","");
 local name,body=text:match("^%s*([^:]+):%s*(.*)$");if not name then return false;end
 name=name:match("^%s*(.-)%s*$"):gsub("^%[",""):gsub("%]$","");
 return self:AoeReply(body,name);
end
function P.Manual:AoeReply(message,sender)
 local text=tostring(message or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","");local lower=text:lower();
 for i=1,#P.roles do local e=self.aoe[i];
  if e and (e.pending or e.lastCastAt and GetTime()-e.lastCastAt<=7) and G:Key(e.name)==G:Key(sender) then
   local u,why=self:AoeValid(e,i);if not u then self:AoeStop(i,why);return true;end
   if G:Refusal(lower) or lower:find("cannot cast",1,true) or lower:find(" is failed",1,true) or lower:find("no items",1,true) then
    G:Log("post_aoe_refusal",text,e.name);self:AoeStop(i,"отказ: "..text);return true;
   end
   local id=tonumber(text:match("|Hspell:(%d+)"));
   if lower:match("^casting ") and lower:find(" on self",1,true) and id and e.spell.ids[id] then
    e.pending=nil;G:Log("post_aoe_ack",text,e.name);return true;
   end
  end
 end
 return false;
end
function P.Manual:AoeCombat(kind,source,sourceName,dest,destName,spell)
 local now=GetTime();
 if source and (kind=="SPELL_CAST_START" or kind=="SPELL_CAST_SUCCESS") then
  self.castActivity[source]=now;
  for _,candidate in pairs(self.aoeSpells) do if candidate.ids[spell] then self.aoeActivity[source]=now;break end end
 end
 for i=1,#P.roles do local e=self.aoe[i];
  if e then
    if source==e.guid and (kind=="SPELL_CAST_START" or kind=="SPELL_CAST_SUCCESS") then e.busyUntil=now+1.8;end
    if source==e.guid and e.spell.ids[spell] and kind=="SPELL_CAST_SUCCESS" then
     e.pending=nil;e.nextAt=now+e.spell.interval;
    end
   local zombie=tostring(sourceName or ""):find("зомби",1,true) or tostring(sourceName or ""):lower()=="zombie chow";
   if source==e.guid and e.spell.ids[spell] and (kind=="SPELL_DAMAGE" or kind=="SPELL_PERIODIC_DAMAGE")
    and (tostring(destName or ""):find("зомби",1,true) or tostring(destName or ""):lower()=="zombie chow") then
    e.hits=e.hits+1;if e.hits==1 then G:Log("post_aoe_hit",tostring(destName).." | "..tostring(dest),e.name);self:Message(e.name..": АоЕ задело зомби; факт удержания агро проверяем по ударам зомби в танка.");end
   elseif dest==e.guid and zombie and (kind=="SWING_DAMAGE" or kind=="SWING_MISSED") then
    e.taken=e.taken+1;if e.taken==1 then G:Log("post_aoe_aggro",tostring(sourceName).." | "..tostring(source),e.name);self:Message(e.name..": зомби атакует танка — агро подтверждено ударом.");end
   end
  end
 end
end

function P.Manual:Record(index,create)
 local d=P:Current(create);if not d then return;end
 if create then d.manualPosts=d.manualPosts or {};d.manualPosts[index]=d.manualPosts[index] or {};end
 return d.manualPosts and d.manualPosts[index];
end
function P.Manual:Message(text) P:Message(text);end
function P.Manual:Target()
 local name=UnitName("target");local u=name and G:Unit(name);
 if not u or UnitGUID(u)~=UnitGUID("target") then self:Message("Выделите живого онлайн-бота своей группы.");return;end
 return name,u;
end
function P.Manual:NaxxOff(inOperation)
 if not inOperation and not P:Idle() then self:Message("Сначала завершите операцию или нажмите «Стоп».");return false;end
 if GetNumRaidMembers()==0 and GetNumPartyMembers()==0 then self:Message("Нужна группа или рейд.");return false;end
 local channel=GetNumRaidMembers()>0 and "RAID" or "PARTY";
 SendChatMessage("co -naxx",channel);SendChatMessage("nc -naxx",channel);
 G:Log("manual_naxx_off","co -naxx; nc -naxx | "..channel,UnitName("player"));
 if not inOperation then self:Message("Команды отключения naxx отправлены всем ботам текущего рейда в co и nc.");end
 return true;
end
function P.Manual:Valid(op)
 if op.manualReset then return true;end
 local f=P.frame;
 if not f or not f.manual then return false,"окно ручной расстановки недоступно";end
 return true;
end
function P.Manual:Begin(name,index,reset)
 if not P:Idle() then self:Message("Сначала завершите операцию или нажмите «Стоп».");return;end
 G.bot=name;G.slot=index;P.doorActive=true;
 local op=G:Begin(reset and "manual_reset" or "manual_summon",false,{gluth=true});
 if not op then P.doorActive=nil;P:Refresh();return;end
 op.door=true;op.manual=true;op.manualReset=reset;op.doorIndex=index;op.expires=GetTime()+45;
 P:RemoveWatch(name);self:AoeStopBot(name);return op;
end
function P.Manual:Place(name,index,autoAoe,hold,simple)
  if not simple and not P:Idle() then self:Message("Сначала завершите другую операцию или дебаг.");return;end
 if not name then name=self:Target();end
 if not name or not G:Unit(name) then return;end
 index=index or P.selected or 1;local previous=self:Record(index);
 if not simple and previous and previous.active and G:Key(previous.name)~=G:Key(name) and P:RosterUnit(previous.name) then
  self:Message("Этот пост занят: "..previous.name..". Снимите его пост или выберите другую вкладку.");return;
 end
 local sample;
 if not simple then
  if SetMapToCurrentZone then SetMapToCurrentZone();end
  sample=P:MapPosition();
  if not sample or sample.mapFile~="Naxxramas" or sample.floor~=1 then self:Message("Для записи точки встаньте на арену Глута, этаж 1.");return;end
 end
  local unit=G:Unit(name);local guid=UnitGUID(unit);if not guid then self:Message(name..": бот недоступен.");return;end
  P:RemoveWatch(name);self:AoeStopBot(name);
 for i=1,#P.roles do local old=self:Record(i);if old and G:Key(old.name)==G:Key(name) then old.active=false;end end
  local record=P.Manual:Record(index,true);
  record.name=name;record.guid=guid;record.world=nil;record.mapPoint=sample and sample.mapFile=="Naxxramas" and sample.floor==1 and sample or nil;record.at=time();record.source="summon_stay";record.active=true;record.resetPending=nil;
  record.key="manual_"..index.."_"..G:Hash(name..":"..time()..":"..GetTime());record.targetKey=record.key;
  record.holdApplied=true;
  -- The four quick buttons deliberately do only summon + stay. Naxx is removed once
  -- for the group and once for each arriving bot by the finite summon watcher below.
  G:Log("send","summon; stay",name);SendChatMessage("summon","WHISPER",nil,name);SendChatMessage("stay","WHISPER",nil,name);
  G.nextSend=GetTime()+G.interval;
  G:Log("manual_post",P.roles[index].label.." | summon; stay",name);
  self:Message(name..": отправлены summon и stay. Проверок, ожидания и повторов нет.");
  if autoAoe then self:AoeToggle(index);end
end
function P.Manual:Capture(name,index)
 if not name or not G:Unit(name) then self:Message("Для записи нужен живой паладин текущего состава.");return;end
 if SetMapToCurrentZone then SetMapToCurrentZone();end
 local sample=P:MapPosition();if not sample or sample.mapFile~="Naxxramas" or sample.floor~=1 then self:Message("Для записи встаньте в нужную точку арены Глута, этаж 1.");return;end
 if self.capture then self.capture=nil;end
 local unit=G:Unit(name);local now=GetTime();self.capture={name=name,guid=UnitGUID(unit),index=index,sample=sample,owner=G:Owner(),context=G:Context(),phase="arrival",nextAt=now+G.interval,deadline=now+7,lastSent=now};
 G:Log("send","summon",name);SendChatMessage("summon","WHISPER",nil,name);G.nextSend=GetTime()+G.interval;
 self:Message(name..": призываю к точке "..index.."; после появления отдельно остановлю и запишу место.");
end
function P.Manual:CaptureStop(reason)
 local c=self.capture;if not c then return;end;self.capture=nil;
 self:Message("Точка "..c.index.." не записана: "..tostring(reason)..".");
end
function P.Manual:CaptureTick()
 local c=self.capture;if not c then return;end;local now=GetTime();
 if c.owner~=G:Owner() or c.context~=G:Context() then self:CaptureStop("сменились персонаж или зона");return;end
 local unit=G:Unit(c.name);if not unit or UnitGUID(unit)~=c.guid then self:CaptureStop("паладин недоступен");return;end
 if now>=c.deadline then self:CaptureStop(c.phase=="arrival" and "паладин не появился рядом за 7 секунд" or "сервер не ответил за 7 секунд");return;end
 if now<c.nextAt then return;end
 if c.phase=="arrival" then
  local x,y=GetPlayerMapPosition(unit);local s=c.sample;local near=GetMapInfo()==s.mapFile and GetCurrentMapDungeonLevel()==s.floor and type(x)=="number" and type(y)=="number" and not (x==0 and y==0) and math.sqrt(((x-s.x)*1093.830078125)^2+((y-s.y)*729.2199707031)^2)<=12;
  if not near then c.nextAt=now+0.2;return;end
  c.phase="stop";c.deadline=now+7;c.lastSent=now;G:Log("send","stay",c.name);SendChatMessage("stay","WHISPER",nil,c.name);return;
 end
 if c.phase=="anchor_queued" then c.phase="anchor";c.deadline=now+7;c.lastSent=now;G:Log("send","position stay set",c.name);SendChatMessage("position stay set","WHISPER",nil,c.name);return;end
 if c.phase=="world_queued" then c.phase="world";c.deadline=now+7;c.lastSent=now;G:Log("send","cdebug position",c.name);SendChatMessage("cdebug position","WHISPER",nil,c.name);end
end
function P.Manual:CaptureReply(message,sender)
 local c=self.capture;if not c or G:Key(sender)~=G:Key(c.name) or GetTime()-(c.lastSent or 0)>7 then return false;end
 local text=tostring(message or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","");local lower=text:lower();
 if G:Refusal(lower) then self:CaptureStop("отказ сервера — "..text);return true;end
 if c.phase=="stop" and (lower:match("^staying%s*$") or text:find("Стою",1,true)) then c.phase="anchor_queued";c.nextAt=GetTime()+G.interval;c.deadline=c.nextAt+7;return true;end
 if c.phase=="anchor" and (lower:match("^position stay is set%s*$") or lower:match("^staying%s*$") or text:find("Стою",1,true)) then c.phase="world_queued";c.nextAt=GetTime()+G.interval;c.deadline=c.nextAt+7;return true;end
 if c.phase~="world" then return false;end
 local w=P:ParseWorld(text);if not w then return false;end;local unit=G:Unit(c.name);local x,y=GetPlayerMapPosition(unit);local s=c.sample;
 if w.map~=533 or GetMapInfo()~=s.mapFile or GetCurrentMapDungeonLevel()~=s.floor or type(x)~="number" or type(y)~="number" or (x==0 and y==0) or math.sqrt(((x-s.x)*1093.830078125)^2+((y-s.y)*729.2199707031)^2)>12 then self:CaptureStop("призыв к выбранному месту не подтверждён");return true;end
 if GetUnitSpeed and GetUnitSpeed(unit)>0.1 then self:CaptureStop("паладин ещё движется");return true;end
 local record=self:Record(c.index,true);record.name=c.name;record.guid=c.guid;record.world=G:Copy(w);record.mapPoint=s;record.at=time();record.source="gluth_intercept_capture";record.active=false;record.holdApplied=nil;
 G:Log("gluth_intercept_point",string.format("%s | %.6f %.6f %.6f map %d",P.roles[c.index].label,w.x,w.y,w.z,w.map),c.name);self.capture=nil;
 self:Message("Точка "..c.index.." «"..P.roles[c.index].label.."» записана: "..string.format("%.1f %.1f %.1f",w.x,w.y,w.z)..".");return true;
end
function P.Manual:CaptureSystem(message)
 local text=tostring(message or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","");local name,body=text:match("^%s*([^:]+):%s*(.*)$");if not name then return false;end
 return self:CaptureReply(body,name:match("^%s*(.-)%s*$"):gsub("^%[",""):gsub("%]$",""));
end
function P.Manual:ArrivalTick(op,now)
 local a=op.arrival;if not a then return false;end
 if now<a.at then return true;end
 local s=op.playerMap;local u=G:Unit(op.name);local x,y=GetPlayerMapPosition(u);
 local near=s and GetMapInfo()==s.mapFile and GetCurrentMapDungeonLevel()==s.floor
  and type(x)=="number" and type(y)=="number" and not (x==0 and y==0)
  and math.sqrt(((x-s.x)*1093.830078125)^2+((y-s.y)*729.2199707031)^2)<=12;
 if near then op.arrival=nil;a.done();
 elseif now>=a.deadline then G:Stop("Summon отправлен, но танк не появился у места призыва за 7 секунд. Пост не записан; автоматических повторов нет.");end
 return true;
end
function P.Manual:Reset()
 local name=self:Target();if not name then return;end
 if G.op and G:Key(G.op.name)==G:Key(name) then self:Message("Дождитесь записи точки этого танка или нажмите Стоп.");return;end
 P:RemoveWatch(name);self:AoeStopBot(name);local released=false;
 for i=1,#P.roles do local r=self:Record(i);if r and G:Key(r.name)==G:Key(name) then
   if r.holdApplied then SendChatMessage("follow","WHISPER",nil,name);r.holdApplied=nil;released=true;end
  r.active=false;r.resetPending=nil;
 end end
  self:Message(name..": пост снят. Координаты сохранены; "..(released and "отправлен follow после созданного сценарием stay." or "дополнительных команд не было."));
end
function P.Manual:Watched(e)
 local r=self:Record(e.slot);
 if r and r.active and r.guid==e.guid and G:Key(r.name)==G:Key(e.name) and r.key==e.key then return r.world;end
end
function P.Manual:Refresh()
 local f=P.frame;if not f or not f.manual then return;end
 local index=P.selected or 1;local idle=P:Idle();
 for i,b in ipairs(f.pointTabs) do
  local r=self:Record(i);b:SetText((index==i and "> " or "")..i..". "..({"Дверь","Правая","Левая","Центр"})[i]);
  if not G.op and not G.batch then b:Enable();else b:Disable();end
 end
 local r=self:Record(index);
 local pointText=r and r.mapPoint and string.format("\nКарта %.3f%%  %.3f%%",r.mapPoint.x*100,r.mapPoint.y*100)
  or r and r.world and string.format("\nX %.3f  Y %.3f  Z %.3f",r.world.x,r.world.y,r.world.z or 0) or "";
 f.post:SetText(r and ((r.name or "Сохранённая точка")..(r.active and " — точка записана" or " — пост не активен")..pointText) or "Пост ещё не записан.");
 f.status:SetText(P.status or "Встаньте на нужное место и выделите бота. Затем нажмите «Призвать и закрепить».");
 for _,b in ipairs({f.place,f.reset,f.naxx}) do if idle then b:Enable();else b:Disable();end end
 local e=self.aoe[index];
 f.aoe:SetText(e and ("Выключить АоЕ: "..e.name) or "Повторять АоЕ под собой (ДК / паладин)");
 if e or idle and r and r.active then f.aoe:Enable();else f.aoe:Disable();end
 f.aoeInfo:SetText(e and string.format("%s: команд %d; попаданий по зомби %d; ударов в танка %d.\n%s",e.spell.label,e.sent,e.hits,e.taken,e.pending and "Ожидаю подтверждение (до 7 секунд)." or "Только в бою, под ногами танка. До 10 минут.") or "Первый каст сразу по кнопке; AI танка сохраняется.\nОтказ — стоп. После /reload включить вручную.");
 if G.op or G.batch or G.cleanup or G.groupWatch or next(self.aoe) then f.stop:Enable();else f.stop:Disable();end
end

-- Explicit Gluth zombie team. Assignments persist; execution never resumes on reload.
P.Hunters={};
function P.Hunters:Slots(create)
 local d=P:Current(create);if not d then return;end
 if create then d.zombieHunters=d.zombieHunters or {};end
 return d.zombieHunters;
end
function P.Hunters:Message(text)
 self.status=text;G:Log("gluth_hunters",text);P:Message(text);self:Refresh();
end
function P.Hunters:Assign(index)
 if self.run or not P:Idle() then self:Message("Сначала остановите режим и завершите текущую операцию.");return;end
 local name,u=P.Manual:Target();if not name then return;end
 local _,class=UnitClass(u);if class~="HUNTER" then self:Message("В эту строку нужен охотник.");return;end
 local slots=self:Slots(true);
 for i,r in pairs(slots) do if i~=index and G:Key(r.name)==G:Key(name) then self:Message("Этот охотник уже назначен в другую строку.");return;end end
 slots[index]=slots[index] or {};slots[index].name=name;slots[index].guid=UnitGUID(u);
 self:Message("Охотник "..index..": "..name..". Назначение сохранено; команды пока не отправлены.");
end
function P.Hunters:Stop(reason)
 local r=self.run;if not r then return;end
 self.run=nil;
 if G.op and G.op.gluthHunters then G.op=nil;end
 G.bot,G.slot=r.previousBot,r.previousSlot;
 self:Message("RTI зомби остановлен: "..(reason or "вручную")..". Серверные настройки оставлены; сброс — «Снять пост выделенного».");
end
function P.Hunters:Valid(r)
 if r.owner~=G:Owner() or r.context~=G:Context() then return false,"сменились персонаж или зона";end
 if G:Busy() or P:DebugActive() then return false,"работает другая операция UnBot";end
 for _,m in ipairs(r.members) do
  local u=G:Unit(m.name);local _,class=UnitClass(u or "none");
  if not u or UnitGUID(u)~=m.guid or class~="HUNTER" then return false,m.name.." недоступен, мёртв или изменился";end
 end
 return true;
end
function P.Hunters:Start()
 if self.run or not P:Idle() then self:Message("Сначала завершите операцию или нажмите «Стоп».");return;end
 if GetRealZoneText()~="Наксрамас" and GetRealZoneText()~="Naxxramas" then self:Message("Режим предназначен только для Глута в Наксрамасе.");return;end
 local slots=self:Slots();local members={};local seen={};
 for i=1,3 do
  local m=slots and slots[i];local u=m and G:Unit(m.name);local _,class=UnitClass(u or "none");
  if not u or class~="HUNTER" or UnitGUID(u)~=m.guid or seen[G:Key(m.name)] then self:Message("Назначьте трёх разных живых охотников из группы.");return;end
  for j=1,3 do local p=P.Manual:Record(j);if p and p.active and G:Key(p.name)==G:Key(m.name) then self:Message(m.name..": сначала снимите ручной пост сбросом ИИ.");return;end end
  seen[G:Key(m.name)]=true;members[i]={name=m.name,guid=m.guid};
 end
 self.run={members=members,owner=G:Owner(),context=G:Context(),previousBot=G.bot,previousSlot=G.slot,
  expires=GetTime()+90,preparing=true,index=0,rounds=0,attacks=0,confirmed=0,seen={}};
 self:PrepareNext();
end
function P.Hunters:PrepareNext()
 local r=self.run;if not r or not r.preparing then return;end
 local now=GetTime();if now<(r.prepareAt or 0) then return;end
 local commands={"co -naxx,-mark rti,-dps assist,-attack weak,-passive,-aoe,-stay", "nc -naxx,-mark rti,-stay,-aggressive,-grind", "rti star"};
 r.index=r.index+1;local command=commands[r.index];
 if command then
  r.prepareAt=now+0.25;
  for _,m in ipairs(r.members) do
   G:Log("gluth_profile_send",command,m.name);SendChatMessage(command,"WHISPER",nil,m.name);
   if self.run~=r then return;end
  end
 else
  r.preparing=nil;r.expires=now+600;r.nextAt=0;
  self:Message("RTI зомби включён: 3 охотника; быстрый цикл rti star → attack rti target. До 10 минут / 60 целей.");
 end
end

function P.Hunters:NameIsZombie(name)
 return name=="Zombie Chow" or name=="Вкусный зомби" or name=="Закуска зомби";
end
function P.Hunters:BossUnit()
 for _,u in ipairs(self:Units()) do
  if UnitGUID(u) and not UnitIsDeadOrGhost(u) and (UnitName(u)=="Gluth" or UnitName(u)=="Глут") then return u;end
 end
end
function P.Hunters:DiscoverSend(r,command)
 if GetTime()<(r.commandAt or 0) then return false;end
 local m=r.members[1];local unit=G:Unit(m.name);
 if not unit or UnitGUID(unit)~=m.guid then self:Stop("охотник-разведчик недоступен");return false;end
 r.commandAt=GetTime()+0.25;G:Log("gluth_discovery_send",command,m.name);
 SendChatMessage(command,"WHISPER",nil,m.name);return true;
end
function P.Hunters:Discover(r,now)
 local d=r.discovery;
 if not d then
  if now<(r.nextDiscoveryAt or 0) then return;end
  if (r.scans or 0)>=80 then self:Stop("лимит 80 серверных поисков исчерпан");return;end
  d={phase="boss",deadline=now+9};r.discovery=d;r.scans=(r.scans or 0)+1;
 end
 if now>=d.deadline then self:Stop("серверный поиск зомби: нет подтверждения этапа «"..d.phase.."»; повторов нет");return;end
 if d.phase=="boss" then
  -- Native mark rti chooses an unmarked attacker, not necessarily an add.
  -- Keep Gluth under a DIFFERENT icon before allowing this action once.
  local boss=self:BossUnit();
  if not boss then
   if not d.warned then d.warned=true;self:Message("Поиск зомби: жду доступную цель Глута, чтобы исключить босса из автометки.");end
   return;
  end
  local icon=GetRaidTargetIndex(boss);
  if not icon or icon==0 or icon==1 then
   if not d.bossMarkAt then
    d.bossMarkAt=now;local ok=pcall(SetRaidTarget,boss,8);
    if not ok then self:Stop("не удалось пометить Глута черепом для исключения из выбора зомби");end
   elseif now-d.bossMarkAt>=2 then self:Stop("метка исключения Глута не подтверждена; проверьте права на рейдовые метки");end
   return;
  end
  d.bossGuid=UnitGUID(boss);d.phase="mark";d.deadline=now+9;
 end
 if d.phase=="mark" then
  local boss=self:BossUnit();
  if not boss or UnitGUID(boss)~=d.bossGuid or not GetRaidTargetIndex(boss) or GetRaidTargetIndex(boss)<2 then
   self:Stop("Глут потерял метку исключения; серверная автометка отменена");return;
  end
  if self:DiscoverSend(r,"do mark rti") then d.phase="query";d.deadline=now+10;end
 elseif d.phase=="query" then
  -- Query the server mark once; never wait for a scout target before releasing the team.
  if now>=(r.commandAt or 0) then
   d.phase="reply";d.deadline=now+7;
   self:DiscoverSend(r,"rti ?");
  end

 end
end
function P.Hunters:DiscoveryReply(message,sender)
 local r=self.run;local d=r and r.discovery;
 if not d or d.phase~="reply" or G:Key(sender)~=G:Key(r.members[1].name) then return false;end
 local text=tostring(message or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","");
 text=text:gsub("|H.-|h(.-)|h","%1");
 local icon,tail=text:match("^[Rr][Tt][Ii]:%s*(%a+)%s*(.-)%s*$");
 if not icon then return false;end
 if icon~="star" then self:Stop("разведчик сменил rti: ожидалась star, получено "..icon);return true;end
 if tail=="" then
  r.discovery=nil;r.nextDiscoveryAt=GetTime()+(r.discoveryWake and 0 or 1.2);r.discoveryWake=nil;
  if not r.waiting then r.waiting=true;self:Message("Серверный поиск: зомби ещё нет среди доступных атакующих. Ожидаю следующую проверку.");end
  return true;
 end
 local name=tail:match("^%((.-)%)$");
 if not self:NameIsZombie(name) then self:Stop("сервер поставил звезду на «"..tostring(name or tail).."», это не зомби. Атака не отправлена");return true;end
 local boss=self:BossUnit();local icon=boss and GetRaidTargetIndex(boss);
 if not boss or UnitGUID(boss)~=d.bossGuid or not icon or icon<2 then self:Stop("Глут потерял метку исключения; атака отменена");return true;end
 r.discovery=nil;r.waiting=nil;r.rounds=r.rounds+1;
 r.target={sent={},ack={},hits={},verifiedAt=GetTime(),server=true,started=GetTime(),nextCommandAt=0,attempts={}};
 self:Message("Серверная звезда: "..name..". Атакуют все три охотника.");r.nextAt=0;return true;
end

function P.Hunters:IsZombie(u)
 local guid=UnitGUID(u);if not guid or UnitIsDeadOrGhost(u) or not UnitCanAttack("player",u) then return false;end
 -- WotLK creature GUID: 0xF130 + 6 hexadecimal entry digits + spawn counter.
 local entry=guid:match("^0x[Ff]130(%x%x%x%x%x%x)");
 if entry and (tonumber(entry,16)==16360 or tonumber(entry,16)==351069) then return true;end
 return self:NameIsZombie(UnitName(u));
end
function P.Hunters:Units()
 local units={"target","focus","mouseover","targettarget","focustarget","pettarget","boss1","boss2","boss3","boss4"};
 local raid=GetNumRaidMembers()>0;
 for i=1,(raid and GetNumRaidMembers() or GetNumPartyMembers()) do
  local u=(raid and "raid" or "party")..i;units[#units+1]=u.."target";units[#units+1]=u.."targettarget";
  units[#units+1]=(raid and "raidpet" or "partypet")..i.."target";
 end
 return units;
end
function P.Hunters:Find(guid)
 local candidate;local hp;
 for _,u in ipairs(self:Units()) do
  if self:IsZombie(u) then
   if guid and UnitGUID(u)==guid then return u;end
   local health=UnitHealth(u) or 0;
   if not guid and not (self.run and self.run.seen[UnitGUID(u)]) and (not candidate or health<hp) then candidate=u;hp=health;end
  end
 end
 return candidate;
end
function P.Hunters:AttackTick(r,t,now)
 local u=t.guid and self:Find(t.guid) or nil;
 if not t.guid then
  for _,token in ipairs(self:Units()) do
   if self:IsZombie(token) and GetRaidTargetIndex(token)==1 and not r.seen[UnitGUID(token)] then u=token;t.guid=UnitGUID(token);break end
  end
 end
 if t.guid and not u then for _,token in ipairs(self:Units()) do if UnitGUID(token)==t.guid and UnitIsDeadOrGhost(token) then t.dead=true;break end end end
 if t.dead then if t.guid then r.seen[t.guid]=true;end;r.target=nil;r.nextDiscoveryAt=0;r.nextAt=0;return;end
 if u then
  if GetRaidTargetIndex(u)~=1 then
   if not t.marked then
    t.marked=now;local ok=pcall(SetRaidTarget,u,1);if not ok then self:Stop("не удалось поставить звезду");return;end
   end
   if GetRaidTargetIndex(u)~=1 then if now-t.marked>=2 then self:Stop("звезда не подтверждена");end;return;end
  end
  t.verifiedAt=now;
 end
 -- Never attack a star visibly moved onto Gluth or an unrelated creature.
 for _,token in ipairs(self:Units()) do
  if UnitGUID(token) and GetRaidTargetIndex(token)==1 and not self:IsZombie(token) then self:Stop("звезда перемещена с зомби; атака отменена");return;end
 end
 if not t.verifiedAt then return;end
 if now-math.max(t.verifiedAt,t.lastEvidenceAt or 0)>=7 then self:Stop("звезда зомби не видна и нет прямых попаданий за 7 секунд");return;end
 for _,m in ipairs(r.members) do
  local unit=G:Unit(m.name);local focus=t.guid and UnitGUID(unit.."target")==t.guid;
  if t.sent[m.name] and focus and not t.ack[m.name] then t.ack[m.name]=true;r.confirmed=r.confirmed+1;end
  if t.sent[m.name] and not t.ack[m.name] and now-t.sent[m.name]>=7 then self:Stop(m.name..": нет переключения или прямых попаданий за 7 секунд");return;end
 end
 if not t.announced and t.ack[r.members[1].name] and t.ack[r.members[2].name] and t.ack[r.members[3].name] then
  t.announced=true;self:Message("Фокус зомби подтверждён у 3/3 охотников (цель или прямое попадание).");
 end
 if now<(t.nextCommandAt or 0) then return;end
 -- Same two-phase chat loop as Saurfang, addressed only to the selected three.
 local attack=t.phase=="attack";
 t.phase=attack and "rti" or "attack";t.nextCommandAt=now+(attack and 0.9 or 0.25);
 for _,m in ipairs(r.members) do
  if attack then
   if r.attacks>=600 then self:Stop("общий лимит 600 атак исчерпан");return;end
   t.sent[m.name]=t.sent[m.name] or now;t.attempts[m.name]=(t.attempts[m.name] or 0)+1;r.attacks=r.attacks+1;
  end
  local command=attack and "attack rti target" or "rti star";
  G:Log(attack and "gluth_rti_attack" or "gluth_rti_icon",t.guid or "server star",m.name);
  SendChatMessage(command,"WHISPER",nil,m.name);
  if self.run~=r or t.dead then return;end
 end
end
function P.Hunters:Tick()
 local r=self.run;if not r then return;end
 local now=GetTime();local ok,why=self:Valid(r);
 if not ok then self:Stop(why);return;end
 if now>=r.expires then self:Stop("время режима истекло");return;end
 if r.preparing then self:PrepareNext();return;end
 if G.batch or G.cleanup or G.op and not ((G.op.kind=="manual_summon" or G.op.kind=="manual_aoe") and G.op.manual) then self:Stop("началась другая операция постов");return;end
 if G.op then for _,m in ipairs(r.members) do if G:Key(G.op.name)==G:Key(m.name) then self:Stop("охотнику назначается ручной пост");return;end end end
 if now<(r.nextAt or 0) then return;end;r.nextAt=now+0.1;
 if not UnitAffectingCombat("player") then if r.inCombat then self:Stop("бой завершён");end;return;end
 r.inCombat=true;
 if r.target then self:AttackTick(r,r.target,now);return;end
 if r.rounds>=60 or r.attacks>=600 then self:Stop("лимит 60 целей / 600 атак исчерпан");return;end
 -- A newly exposed zombie takes precedence over an outstanding discovery reply.
 local u=self:Find();
 if u then
  r.discovery=nil;r.waiting=nil;r.rounds=r.rounds+1;
  r.target={guid=UnitGUID(u),sent={},ack={},hits={},started=now,nextCommandAt=0,attempts={}};
  self:Message("RTI: выбран зомби → звезда и три охотника, цель "..r.rounds.."/60.");
  self:AttackTick(r,r.target,now);return;
 end
 self:Discover(r,now);
end
function P.Hunters:Reply(message,sender)
 local r=self.run;if not r then return false;end
 for _,m in ipairs(r.members) do
  if G:Key(sender)==G:Key(m.name) then
   local s=tostring(message or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):lower();
   if G:Refusal(s) or s:find("unknown action",1,true) or s:find("action is unknown",1,true) or s:find("dont see my rti",1,true) or s:find("don't see my rti",1,true) or s:find("cannot attack",1,true) then self:Stop(m.name..": "..message);return true;end
  end
 end
 local icon=tostring(message or ""):match("rti set to:%s*(%a+)");
 if icon and icon~="star" then for _,m in ipairs(r.members) do if G:Key(sender)==G:Key(m.name) then self:Stop(m.name..": неверный rti "..icon);return true;end end end
 return self:DiscoveryReply(message,sender);
end
function P.Hunters:Combat(kind,source,sourceName,dest,destName,spell)
 local r=self.run;if not r or r.preparing or r.owner~=G:Owner() or r.context~=G:Context() then return;end
 if kind=="SPELL_SUMMON" and self:NameIsZombie(destName) then r.nextDiscoveryAt=0;r.nextAt=0;r.discoveryWake=r.discovery and true or nil;end
 local t=r.target;if not t then return;end
 if not t.guid and t.server and self:NameIsZombie(destName) and (kind=="RANGE_DAMAGE" or kind=="SWING_DAMAGE") then
  for _,m in ipairs(r.members) do if source==m.guid and t.sent[m.name] then t.guid=dest;break end end
 end
 if not t.guid and t.server and self:NameIsZombie(destName) and (kind=="UNIT_DIED" or kind=="PARTY_KILL") then
  r.seen[dest]=true;r.target=nil;r.nextDiscoveryAt=0;r.nextAt=0;return;
 end
 if (kind=="UNIT_DIED" or kind=="PARTY_KILL") and dest==t.guid then
  t.dead=true;G:Log("gluth_target_dead",kind.." | "..t.guid);return;
 end
 if dest~=t.guid then return;end
 for _,m in ipairs(r.members) do
  if source==m.guid and t.sent[m.name] then
   local unit=G:Unit(m.name);
   -- Traps/periodic AoE while the hunter shoots Gluth do not prove focus.
   local direct=kind=="RANGE_DAMAGE" or kind=="SWING_DAMAGE"
    or (kind=="SPELL_DAMAGE" and unit and UnitGUID(unit.."target")==t.guid);
   if direct then
    t.lastEvidenceAt=GetTime();t.hits[m.name]=GetTime();
    if not t.ack[m.name] then t.ack[m.name]=true;r.confirmed=r.confirmed+1;G:Log("gluth_focus_ack",kind.." | "..t.guid,m.name);end
   end
  end
 end
 if not t.announced and t.ack[r.members[1].name] and t.ack[r.members[2].name] and t.ack[r.members[3].name] then
  t.announced=true;self:Message("Фокус зомби подтверждён у 3/3 охотников (цель или прямое попадание).");
 end
end
function P.Hunters:Refresh()
 local f=self.frame;if not f then return;end
 local slots=self:Slots();
 for i,b in ipairs(f.slots) do b:SetText(i..". "..(slots and slots[i] and slots[i].name or "Выделите охотника → назначить"));if self.run then b:Disable();else b:Enable();end end
 f.status:SetText(self.status or "Состав: паладин Protection у двери, 3 MM-охотника, жрец Discipline. Назначьте охотников из группы.");
 if self.run then f.start:Disable();f.stop:Enable();else f.start:Enable();f.stop:Disable();end
end
function P.Hunters:Show()
 if self.frame then self.frame:Show();self:Refresh();return;end
 local f=CreateFrame("Frame","UnBotGluthHuntersFrame",UIParent);self.frame=f;
 f:SetWidth(570);f:SetHeight(365);f:SetPoint("CENTER");f:SetFrameStrata("DIALOG");f:SetMovable(true);f:EnableMouse(true);f:SetClampedToScreen(true);
 f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=32,insets={left=11,right=12,top=12,bottom=11}});
 local function label(text,y,height)
  local t=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");t:SetPoint("TOPLEFT",25,-y);t:SetWidth(520);t:SetHeight(height);t:SetJustifyH("LEFT");t:SetText(text);return t;
 end
 local function button(text,x,y,width,fn)
  local b=CreateFrame("Button",nil,f,"UIPanelButtonTemplate");b:SetPoint("TOPLEFT",x,-y);b:SetWidth(width);b:SetHeight(27);b:SetText(text);b:SetScript("OnClick",fn);return b;
 end
 label("Глут — 3 охотника: RTI зомби",20,22);
 local drag=CreateFrame("Frame",nil,f);drag:SetWidth(490);drag:SetHeight(40);drag:SetPoint("TOPLEFT",10,-10);drag:EnableMouse(true);drag:RegisterForDrag("LeftButton");drag:SetScript("OnDragStart",function() f:StartMoving();end);drag:SetScript("OnDragStop",function() f:StopMovingOrSizing();end);
 local close=CreateFrame("Button",nil,f,"UIPanelCloseButton");close:SetPoint("TOPRIGHT",-5,-5);close:SetScript("OnClick",function() f:Hide();end);
 f.slots={};for i=1,3 do local index=i;f.slots[i]=button("",25,50+(i-1)*32,520,function() P.Hunters:Assign(index);end);end
 label("rti star — общая звезда; do mark rti — сервер ищет зомби.\nco: -naxx,-mark rti,-dps assist,-attack weak,-passive,-aoe,-stay\nnc: -naxx,-mark rti,-stay,-aggressive,-grind",150,48);
 label("Только эти 3 охотника. Сняты серверный автовыбор/метки и stay;\nклассовые атаки сохранены. Глут исключается другой рейдовой меткой.",201,32);
 f.start=button("Включить RTI зомби",25,240,255,function() P.Hunters:Start();end);
 f.stop=button("Стоп RTI",290,240,255,function() P.Hunters:Stop("вручную");end);
 f.status=label("",278,68);f.status:SetJustifyV("TOP");self:Refresh();
end


-- Compact controls shown only by an explicit Gluth preset summon.
P.Quick={};
P.Quick.Corridor={};
function P.Quick.Corridor:Active()
 local s=P.Quick:Session();local loaded=UnBotSquadBuilder and UnBotSquadBuilder.loadedBossPreset;
 return s and s.active and s.mode=="40n_corridor" and (not loaded or loaded.bossKey=="naxxramas__gluth" and loaded.modeKey=="40n_corridor");
end
function P.Quick.Corridor:Plan()
 if not self:Active() then return nil,"Выберите и призовите пресет «40 — коридор».";end
 if not GetRaidRosterInfo or GetNumRaidMembers()==0 then return nil,"Нужен рейд с восемью ботами пресета.";end
 local s=P.Quick:Session();local entries,seen={},{};
 local groups={druid=1,shaman=1,warrior=1,rogue=1,warlock=1,paladin=2,mage=2,priest=2};
 for _,slot in ipairs(s.slots or {}) do
  if not slot.reserveOnly then
   local group=groups[slot.className];
   if not group or seen[slot.className] or tonumber(slot.count)~=1 or slot.className=="druid" and slot.specKey~="bear" then
    return nil,"Для коридора нужны восемь разных классов исходного пресета, включая медведя.";
   end
   local found,why=P.Quick:Members(slot.className,slot.specKey);
   if not found or #found~=1 then return nil,"Не найден единственный живой "..slot.className.."/"..slot.specKey..": "..tostring(why or "состав ещё не готов");end
   local m=found[1];local key=G:Key(m.name);if seen[key] then return nil,"Повтор имени в составе: "..m.name;end
   seen[slot.className]=true;seen[key]=true;
   entries[#entries+1]={name=m.name,guid=m.guid,key=key,group=group,bear=slot.className=="druid"};
  end
 end
 if #entries~=8 then return nil,"Дождитесь всех восьми ботов коридорного пресета.";end
 local player=UnitName("player");entries[#entries+1]={name=player,guid=UnitGUID("player"),key=G:Key(player),group=2,player=true};
 return entries;
end
function P.Quick.Corridor:Roster(entries)
 local wanted={};for _,m in ipairs(entries) do wanted[m.key]=m;end
 local groups,byKey={{},{},{},{},{},{},{},{}},{};
 for i=1,GetNumRaidMembers() do
  local name,_,group=GetRaidRosterInfo(i);if not name or not groups[group] then return nil,nil,"Ростер рейда ещё обновляется.";end
  local key=G:Key(name);local unit="raid"..i;
  local row={name=name,key=key,index=i,group=group,unit=unit,guid=UnitGUID(unit)};
  groups[group][#groups[group]+1]=row;byKey[key]=row;
  if (group==1 or group==2) and not wanted[key] then return nil,nil,"В группе "..group.." посторонний участник "..name.."; освободите место для пресета.";end
 end
 for _,m in ipairs(entries) do
  local row=byKey[m.key];
  if not row or row.guid~=m.guid or not UnitIsConnected(row.unit) or UnitIsDeadOrGhost(row.unit) then return nil,nil,m.name..": состав изменился, персонаж офлайн или мёртв.";end
 end
 return groups,byKey;
end
function P.Quick.Corridor:Check(entries)
 local groups,roster,why=self:Roster(entries);if not groups then return false,why;end
 local bear;
 for _,m in ipairs(entries) do
  if roster[m.key].group~=m.group then return false,"Группы ещё не разложены: "..m.name.." должен быть в группе "..m.group..".";end
  if m.bear then bear=m;end
 end
 return true,bear,roster;
end
function P.Quick.Corridor:Stop(text)
 self.run=nil;self.status=text;G:Log("gluth_corridor",text);P:Message(text);
end
function P.Quick.Corridor:Start()
 self.run=nil;
 local entries,why=self:Plan();if not entries then self:Stop(why);return;end
 if not SetRaidSubgroup then self:Stop("Клиент не предоставляет SetRaidSubgroup.");return;end
 if not (IsRaidLeader and IsRaidLeader()) and not (IsRaidOfficer and IsRaidOfficer()) then self:Stop("Для раскладки нужен лидер или помощник рейда.");return;end
 local groups,_,reason=self:Roster(entries);if not groups then self:Stop(reason);return;end
 self.run={entries=entries,owner=G:Owner(),context=G:Context(),signature=P.Quick:Signature(),deadline=GetTime()+30,nextAt=0,sent={}};
 self.status="Раскладываю: группа 1 — пять ботов босса; группа 2 — игрок и три бота зомби.";
 self:Tick();P.Quick:Refresh();
end
function P.Quick.Corridor:Tick()
 local r=self.run;if not r then return;end
 local now=GetTime();if now<(r.nextAt or 0) then return;end;r.nextAt=now+0.5;
 if not self:Active() or r.owner~=G:Owner() or r.context~=G:Context() or r.signature~=P.Quick:Signature() then self:Stop("Раскладка остановлена: сменился сценарий, зона или состав.");return;end
 if now>=r.deadline then self:Stop("Нет подтверждения раскладки за 30 секунд. Повтор — кнопкой «Разложить группы».");return;end
 if not (IsRaidLeader and IsRaidLeader()) and not (IsRaidOfficer and IsRaidOfficer()) then self:Stop("Раскладка остановлена: нет прав лидера или помощника.");return;end
 local groups,roster,why=self:Roster(r.entries);if not groups then self:Stop(why);return;end
 -- Only SetRaidSubgroup: move a misplaced member into a free slot. No protected SwapRaidSubgroup.
 for _,m in ipairs(r.entries) do
  local row=roster[m.key];
  if row.group~=m.group and #groups[m.group]<5 then
   if r.pending then
    local prev=roster[r.pending.key];
    if prev and prev.group==r.pending.group then r.pending=nil;
    elseif now<r.pending.untilAt then return;
    else self:Stop("Сервер не подтвердил подгруппу "..r.pending.name.." за 5 секунд. Повторов нет.");return;end
   end
   if r.sent[m.key] then self:Stop("Подгруппа "..m.name.." изменилась повторно. Раскладка остановлена.");return;end
   r.sent[m.key]=true;r.pending={name=m.name,key=m.key,group=m.group,untilAt=now+5};
   G:Log("gluth_corridor_group",m.name.." -> "..m.group);
   local ok=pcall(SetRaidSubgroup,row.index,m.group);
   if not ok then self:Stop("Клиент отклонил перемещение "..m.name.." в подгруппу. Повторов нет.");end
   return;
  end
 end
 local ready,bear=self:Check(r.entries);
 if ready then
  self.run=nil;
  local unit=roster[bear.key].unit;local mt=GetPartyAssignment and GetPartyAssignment("MAINTANK",unit);
  self:Stop("Группы готовы: 1 — 5 ботов босса; 2 — игрок + 3 бота зомби. "..(mt and ("Главный танк: "..bear.name..".") or ("Медведь: "..bear.name..". Кнопка группы 1 подставит /maintank; подтвердите Enter.")));
 elseif r.pending and now>=r.pending.untilAt then self:Stop("Сервер не подтвердил подгруппы. Повтор — кнопкой «Разложить группы».");end
end
function P.Quick.Corridor:Summon(group)
 if group~=1 and group~=2 then return;end
 local entries,why=self:Plan();if not entries then self:Stop(why);return;end
 local ready,bear,roster=self:Check(entries);if not ready then self:Stop(bear);return;end
 -- Keep raid filters visible and apply -naxx at the actual summon click, not a later timer.
 SendChatMessage("@group"..group.." summon","RAID");P.Manual:NaxxOff(true);
 G:Log("gluth_corridor_summon","@group"..group.." summon; co -naxx; nc -naxx");
 self.status="Группа "..group..": summon отправлен; co -naxx и nc -naxx отправлены рейду.";
 if group==1 and not (GetPartyAssignment and GetPartyAssignment("MAINTANK",roster[bear.key].unit)) then
  -- Blizzard's protected /maintank handler must run from the player's Enter key, never from addon Lua.
  local command="/maintank "..bear.name;
  local edit=ChatFrameEditBox or DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox;
  if edit and edit:IsShown() and edit.GetText and edit:GetText()~="" then
   self.status=self.status.." Команда для главного танка: "..command.." (текущий ввод сохранён).";
  else
   if ChatFrame_OpenChat then ChatFrame_OpenChat(command);end
   self.status=self.status.." Нажмите Enter: "..command;
  end
 end
 P:Message(self.status);
end
function P.Quick.Corridor:OnComplete(preset)
 if preset and preset.bossKey=="naxxramas__gluth" and preset.modeKey=="40n_corridor" and self:Active() then self:Start();end
end
function P.Quick.Corridor:Refresh(f)
 f:SetWidth(480);f:SetHeight(330);f.title:SetText("Глут — две группы в коридоре");
 f.help:SetWidth(440);f.help:SetHeight(80);f.help:SetText("Группа 1 → дверь Таддиуса: медведь, шаман, вар, рога, лок.\nГруппа 2 → мост у Глута: вы, протопал, маг, Disc.\nВстаньте в точку и нажмите кнопку нужной группы.\nКаждый призыв сразу снимает co/nc naxx всему рейду.");
 for _,row in ipairs(f.tanks) do row.place:Hide();row.aoe:Hide();row.assign:Hide();row.info:Hide();end
 f.deploy:Hide();f.hunters:Hide();f.naxx:Hide();f.cancel:Hide();
 f.corridorArrange:Show();f.corridor1:Show();f.corridor2:Show();
 f.status:ClearAllPoints();f.status:SetPoint("TOPLEFT",20,-238);f.status:SetWidth(440);f.status:SetHeight(72);
 f.status:SetText(self.status or "После сбора группы раскладываются автоматически. При изменении ростера нажмите «Разложить группы». Главный танк подтверждается Enter через кнопку группы 1.");
end
function P.Quick:Session()
 local s=G:Store().gluthQuickSession;
 if s and s.mode=="40n_intercept" and s.roleAssignmentVersion~=2 then
  -- Pre-6.39.67 names were random. Do not treat them as the player's explicit role choices.
  s.tankNames=nil;s.healerName=nil;s.roleAssignmentVersion=2;
 end
 return s;
end
function P.Quick:Activate(preset)
 self.Corridor.run=nil;self.Corridor.status=nil;
 local previous=self:Session();
 if previous and previous.mode=="40n_intercept" and previous.tankNames then
  local names={};for i=1,4 do if previous.tankNames[i] then names[#names+1]=previous.tankNames[i];end end
  if previous.healerName then names[#names+1]=previous.healerName;end
  if #names>0 then self.restore={names=names,index=1,reason="начат новый сценарий"};end
 end
 if G.op and G.op.quickLock then G:Stop("Начат новый сценарий Глута");end
 self.locks=nil;self.healerLock=nil;
 if self.deploy then self:DeployStop("начат новый сценарий",true);end
 if next(P.Manual.aoe) then P.Manual:AoeStopAll();end
 local s=self:Session() or {};G:Store().gluthQuickSession=s;
 s.active=true;s.bossKey="naxxramas__gluth";s.mode=preset and preset.modeKey or s.mode or "40n";
 if s.mode=="40n_intercept" then s.roleAssignmentVersion=2;end
 s.slots=G:Copy(UnBotSquadConfig.slots or {});s.tankNames=nil;s.healerName=nil;s.startedAt=time();self.lastNotice=nil;
 return s;
end
function P.Quick:Cancel()
 self.Corridor.run=nil;
 local s=self:Session();if s then s.active=false;s.cancelledAt=time();end;self.naxxSummon=nil;
 local names={};for i=1,4 do if s and s.tankNames and s.tankNames[i] then names[#names+1]=s.tankNames[i];end end;if s and s.healerName then names[#names+1]=s.healerName;end
 if self.deploy then self:DeployStop("сценарий отменён",true);end
 if G.op or G.groupWatch and G.groupWatch.door or next(P.Manual.aoe) then G:Stop("Сценарий Глута отменён игроком");
 elseif P.Hunters.run then P.Hunters:Stop("сценарий Глута отменён игроком");end
 local released=P.Manual:ReleaseHolds();
 if s and s.parkedNames then for _,name in pairs(s.parkedNames) do if G:Unit(name) then SendChatMessage("follow","WHISPER",nil,name);released=released+1;end end;s.parkedNames=nil;end
 if s and s.healerName and G:Unit(s.healerName) then SendChatMessage("follow","WHISPER",nil,s.healerName);released=released+1;end
 self.locks=nil;self.healerLock=nil;self:BeginRestore(names,"сценарий отменён");
 self:Notice("Сценарий Глута отменён. "..(released>0 and ("Снято удержание постов: "..released..".") or "Активных удержаний постов не было.").." Окно можно закрыть.");self:Refresh();
end
function P.Quick:ToggleSession()
 local s=self:Session();if s and s.active then self:Cancel();else self:Activate();P.status="Сценарий Глута включён до явной отмены.";self:Refresh();end
end
function P.Quick:Signature()
 local parts={};for _,s in ipairs(UnBotSquadConfig and UnBotSquadConfig.slots or {}) do parts[#parts+1]=table.concat({tostring(s.className),tostring(s.specKey),tostring(s.count),tostring(s.accountAltName),tostring(s.reserveOnly)},":");end
 return table.concat(parts,"|");
end
function P.Quick:Members(class,spec)
 local session=self:Session();
 if not session or not session.active then return nil,"Сценарий Глута выключен. Нажмите «Включить сценарий Глута».";end
 if not UnBotSquadBuilderRosterAssignments then return nil,"Сборщик состава ещё недоступен.";end
 local assigned=UnBotSquadBuilderRosterAssignments(session.slots);local found,seen,skipped={},{},{};
 if type(assigned)~="table" then return nil,"Нет назначений для состава Глута.";end
 for _,slot in ipairs(session.slots or {}) do
  if not slot.reserveOnly and slot.className==class and slot.specKey==spec then
   for _,m in ipairs(assigned[slot] or {}) do
    local u=G:Unit(m.name);local key=G:Key(m.name);
    if m.online and u and UnitGUID(u) then
     if not seen[key] then seen[key]=true;found[#found+1]={name=m.name,guid=UnitGUID(u)};end
    else
     local unit=m.unit or P:RosterUnit(m.name);local why="не распознан как живой бот";
     if not unit then why="не в группе";
     elseif not UnitIsConnected(unit) then why="офлайн";
     elseif UnitIsDeadOrGhost(unit) then why="мёртв";end
     skipped[#skipped+1]=m.name.." — "..why;
    end
   end
  end
 end
 local detail=table.concat(skipped,"; ");G:Log("gluth_quick_members",class.."/"..spec..": "..#found.."; "..detail);
 return found,detail;
end
function P.Quick:Notice(text)
 -- Repeated manual clicks update the window but do not flood chat or the event journal.
 if self.lastNotice==text and GetTime()-(self.lastNoticeAt or 0)<5 then P.status=text;P:Refresh();return;end
 self.lastNotice=text;self.lastNoticeAt=GetTime();G:Log("gluth_quick_notice",text);P:Message(text);
end
function P.Quick:TankCount()
 local s=self:Session();local count=0;
 for _,slot in ipairs(s and s.slots or {}) do
  if not slot.reserveOnly and slot.className=="paladin" and slot.specKey=="prot" then count=count+(tonumber(slot.count) or 0);end
 end
 return math.max(1,math.min(4,count));
end
function P.Quick:IsIntercept()
 local s=self:Session();return s and s.mode=="40n_intercept";
end
function P.Quick:AutoAssignTanks()
 if not self:IsIntercept() then return;end
 local tanks,why=self:Members("paladin","prot");if not tanks then return nil,why;end
 table.sort(tanks,function(a,b) return G:Key(a.name)<G:Key(b.name);end);
 local s=self:Session();s.tankNames=s.tankNames or {};local live,used={},{};
 for _,tank in ipairs(tanks) do live[G:Key(tank.name)]=tank.name;end
 for i=1,4 do local key=G:Key(s.tankNames[i]);if not live[key] or used[key] then s.tankNames[i]=nil;else s.tankNames[i]=live[key];used[key]=true;end end
 for i=1,4 do
  if not s.tankNames[i] then
   for _,tank in ipairs(tanks) do local key=G:Key(tank.name);if not used[key] then s.tankNames[i]=tank.name;used[key]=true;break end end
  end
 end
 if #tanks<4 then return nil,"Protection Paladin: найдено "..#tanks.."/4. "..tostring(why or "");end
 return s.tankNames;
end
function P.Quick:TankName(index)
 local tanks,why=self:Members("paladin","prot");if not tanks then return nil,why;end
 local s=self:Session();local count=self:TankCount();
 if self:IsIntercept() then
  self:AutoAssignTanks();
  local name=s and s.tankNames and s.tankNames[index];
  if not name then return nil,"Для поста \""..P.roles[index].label.."\" не найден свободный живой Protection Paladin.";end
  for _,tank in ipairs(tanks) do if G:Key(tank.name)==G:Key(name) then return tank.name;end end
  return nil,"Назначенный на пост \""..P.roles[index].label.."\" паладин "..tostring(name).." сейчас недоступен.";
 end
 if not s.tankNames then
  if #tanks~=count then return nil,"Protection Paladin: найдено "..#tanks.."/"..count..". "..(why~="" and why or "Дождитесь подтверждения танков в сборщике.");end
  table.sort(tanks,function(a,b) return G:Key(a.name)<G:Key(b.name);end);
  s.tankNames={};local used={};
  -- Preserve an already placed member when extending the old single-tank scenario.
  for i=1,count do local r=P.Manual:Record(i);
   for _,tank in ipairs(tanks) do if r and r.active and G:Key(r.name)==G:Key(tank.name) and not used[G:Key(tank.name)] then
    s.tankNames[i]=tank.name;used[G:Key(tank.name)]=true;break
   end end
  end
  for i=1,count do if not s.tankNames[i] then
   for _,tank in ipairs(tanks) do if not used[G:Key(tank.name)] then s.tankNames[i]=tank.name;used[G:Key(tank.name)]=true;break end end
  end end
 end
 local name=s.tankNames[index];
 for _,tank in ipairs(tanks) do if G:Key(tank.name)==G:Key(name) then return tank.name;end end
 return nil,"Танк "..index.." ("..tostring(name or "не назначен").."): нет живого подтверждённого назначения. "..(why or "");
end
function P.Quick:AssignTank(index)
 if not self:IsIntercept() then return;end
 if G.op or G.batch or G.cleanup or G:Busy() then self:Notice("Дождитесь завершения текущей команды расстановки.");return;end
 local target=UnitName("target");local unit=target and G:Unit(target);if not unit or UnitGUID(unit)~=UnitGUID("target") then self:Notice("Выделите живого Protection Paladin из текущего состава.");return;end
 local tanks,why=self:Members("paladin","prot");local valid;
 for _,tank in ipairs(tanks or {}) do if G:Key(tank.name)==G:Key(target) then valid=tank.name;break end end
 if not valid then self:Notice("Цель не является живым Protection Paladin этого пресета. "..tostring(why or ""));return;end
 local s=self:Session();s.tankNames=s.tankNames or {};
 for i=1,4 do if i~=index and G:Key(s.tankNames[i])==G:Key(valid) then self:Notice(valid.." уже назначен на роль \""..P.roles[i].label.."\".");return;end end
 s.tankNames[index]=valid;self:Notice("Роль \""..P.roles[index].label.."\": "..valid..". Назначение действует для текущего запуска и сохраняется через /reload.");self:Refresh();
end
function P.Quick:ParkOtherTanks(exceptName)
 local s=self:Session();if not s then return;end;self:AutoAssignTanks();s.parkedNames=s.parkedNames or {};
 for i=1,4 do local name=s.tankNames and s.tankNames[i];local key=G:Key(name);
  local r=P.Manual:Record(i);local fixed=r and r.active and G:Key(r.name)==key;
  if name and not fixed and key~=G:Key(exceptName) and G:Unit(name) and not s.parkedNames[key] then
   s.parkedNames[key]=name;G:Log("gluth_intercept_park","stay before manual placement",name);SendChatMessage("stay","WHISPER",nil,name);
  end
 end
end
function P.Quick:Healer()
 local s=self:Session();if not s or not s.active then return nil,"Сценарий Глута выключен.";end
 if not UnBotSquadBuilderRosterAssignments then return nil,"Сборщик состава ещё недоступен.";end
 local assigned=UnBotSquadBuilderRosterAssignments(s.slots);local healers,seen={},{},{};
 for _,slot in ipairs(s.slots or {}) do
  local heal=not slot.reserveOnly and (slot.specKey=="disc" or slot.specKey=="holy" or slot.specKey=="resto")
   and (slot.className=="priest" or slot.className=="paladin" or slot.className=="shaman" or slot.className=="druid");
  if heal then for _,m in ipairs(assigned and assigned[slot] or {}) do local u=G:Unit(m.name);local key=G:Key(m.name);
   if m.online and u and UnitGUID(u) and not seen[key] then seen[key]=true;healers[#healers+1]={name=m.name,guid=UnitGUID(u)};end
  end end
 end
 if #healers==0 then return nil,"Не найден живой подтверждённый хил текущего состава.";end
 if not s.healerName then s.healerName=healers[math.random(#healers)].name;end
 for _,m in ipairs(healers) do if G:Key(m.name)==G:Key(s.healerName) then return m;end end
 s.healerName=healers[math.random(#healers)].name;for _,m in ipairs(healers) do if G:Key(m.name)==G:Key(s.healerName) then return m;end end
end
function P.Quick:Point(index)
 local r=P.Manual:Record(index);local w=r and r.world;
 if type(w)=="table" and tonumber(w.map)==533 and tonumber(w.x) and tonumber(w.y) and tonumber(w.z) then return w;end
end
function P.Quick:Place(index)
 index=index or 1;if index<1 or index>self:TankCount() then return;end
  if self:IsIntercept() then
   self:ManualLock(index);return;
  end
  local full=self:TankCount()==4;
  if not full and G.op and G.op.kind=="manual_summon" and G.op.manual then
  self:Notice(G.op.name..": summon уже отправлен; проверяю прибытие и запись поста.");return;
 end
  if not full and not P:Idle() then self:Notice("Дождитесь завершения призыва или текущей операции.");return;end
 local name,why=self:TankName(index);if not name then self:Notice(why);return;end
  P.selected=index;P.Manual:Place(name,index,false,true,full);
end
function P.Quick:CapturePoint(index)
 if not self:IsIntercept() then return;end
 if self.deploy then self:DeployStop("начата запись новой точки",true);end
 local name,why=self:TankName(index);if not name then self:Notice(why);return;end
 P.selected=index;P.Manual:Capture(name,index);
end
function P.Quick:LockWanted(index,healer)
 local passive=not healer and index~=1;
 local co={stay=true,passive=passive,follow=false,formation=false,guard=false,runaway=false,["flee from adds"]=false,["move from group"]=false,
  flee=false,["avoid aoe"]=false,close=false,behind=false,["tank face"]=false,grind=false,["attack weak"]=false,["attack force"]=false,naxx=false};
 local nc={stay=true,passive=passive,follow=false,guard=false,runaway=false,["flee from adds"]=false,["move from group"]=false,
  grind=false,["move random"]=false,aggressive=false,naxx=false};
 if healer then
  co.heal=true;co.tank=false;co["tank aoe"]=false;co["tank assist"]=false;co.dps=false;co["dps aoe"]=false;co["dps assist"]=false;co["dps debuff"]=false;
 else
  co.tank=index==1;co["tank aoe"]=false;co["tank assist"]=false;co.dps=false;co["dps aoe"]=false;co["dps assist"]=false;co["dps debuff"]=false;
 end
 return {co=co,nc=nc};
end
function P.Quick:ManualLock(index,healer)
 if not self:IsIntercept() then return;end
 if self.restore then self:Notice("Сначала завершается восстановление настроек прежних имён.");return;end
 if G.op or G.batch or G.cleanup or G:Busy() or P:DebugActive() then self:Notice("Дождитесь завершения текущей команды расстановки или дебага.");return;end
 local member,why;
 if healer then member,why=self:Healer();else local name;name,why=self:TankName(index);local u=name and G:Unit(name);member=name and {name=name,guid=u and UnitGUID(u)};end
 if not member or not member.name or not member.guid then self:Notice(why or "Назначенный бот недоступен.");return;end
 if SetMapToCurrentZone then SetMapToCurrentZone();end
 local sample=P:MapPosition();if not sample or sample.mapFile~="Naxxramas" or sample.floor~=1 then self:Notice("Встаньте в нужное место на арене Глута, этаж 1.");return;end
 local bossGuid;
 if not healer and index==1 then
  local lower=tostring(UnitName("target") or ""):lower();bossGuid=UnitGUID("target");
  if not bossGuid or (lower~="глут" and lower~="gluth") then self:Notice("Для дверного танка выделите Глута и не меняйте цель до сообщения о закреплении.");return;end
 end
 if not healer then
  self:ParkOtherTanks(member.name);local session=self:Session();if session and session.parkedNames then session.parkedNames[G:Key(member.name)]=nil;end
 end
 G.bot=member.name;G.slot=healer and 5 or index;
 local op=G:Begin("gluth_intercept_lock",false,{gluth=true});if not op then self:Refresh();return;end
 op.quickLock=true;op.quickHealer=healer and true or false;op.quickIndex=index;op.quickLabel=healer and "хил в центре" or P.roles[index].label;op.quickMap=sample;op.quickBossGuid=bossGuid;op.expires=GetTime()+75;
 G:Read("co",function() G:Read("nc",function()
  local wanted=P.Quick:LockWanted(index,healer);if not G:Remember(op,wanted) then return;end
  G:Apply("co",wanted.co,function() G:Apply("nc",wanted.nc,function()
   G:Job("summon",nil,function()
    op.playerMap=sample;op.arrival={at=GetTime()+0.1,deadline=GetTime()+7,done=function()
     G:Job("stay");G:Job("position stay set","anchorSet",function()
      G:Job("cdebug position","world",function(w)
     if not w or tonumber(w.map)~=533 then G:Stop(member.name..": сервер не подтвердил позицию на карте Наксрамаса.");return;end
     op.quickWorld=G:Copy(w);
     if healer then
      local s=P.Quick:Session();if s then s.healerName=member.name;s.healerPost={world=G:Copy(w),mapPoint=sample,at=time()};end
     else
      local r=P.Manual:Record(index,true);r.name=member.name;r.guid=member.guid;r.world=G:Copy(w);r.mapPoint=sample;r.at=time();r.source="gluth_intercept_manual";r.active=true;r.holdApplied=true;r.resetPending=nil;
      r.key="intercept_manual_"..index.."_"..G:Hash(member.name..":"..time()..":"..GetTime());r.targetKey=r.key;
      G:Job("cast righteous fury on "..member.name);
      if index==1 then
       if UnitGUID("target")~=op.quickBossGuid then G:Stop("Цель изменилась до команды дверному танку. Снова выделите Глута и повторите кнопку.");return;end
       G:Job("do attack my target");
      else G:Job("do drop target");end
     end
       G:Job("stay",nil,function() op.quickComplete=true;G:Done(member.name..": пост закреплён.");end);
      end);
     end);
    end};
   end);
  end);end);
 end);end);
 self:Notice(member.name..": сохраняю текущие стратегии, затем призываю и жёстко закрепляю на месте игрока.");
end
function P.Quick:PlaceHealer()
 self:ManualLock(5,true);
end
function P.Quick:BeginRestore(names,reason)
 local unique,list={},{};
 for _,name in ipairs(names or {}) do local key=G:Key(name);if name and not unique[key] then unique[key]=true;list[#list+1]=name;end end
 self.restore=#list>0 and {names=list,index=1,reason=reason} or nil;self:RestoreNext();
end
function P.Quick:RestoreNext()
 local work=self.restore;if not work or G.op or G.cleanup or G.batch or G:Busy() then return;end
 while work.index<=#work.names do
  local name=work.names[work.index];work.index=work.index+1;
  if G:Unit(name) and G:Store().recovery[G:Key(name)] then
   G.bot=name;G.slot=1;G:Restore({gluth=true});if G.op then G.op.quickRestore=true;G.op.expires=GetTime()+75;return;end
  end
 end
 self.restore=nil;self:Notice("Временные стратегии перехвата восстановлены"..(work.reason and " ("..work.reason..")" or "")..".");
end
function P.Quick:LockTick()
 self:RestoreNext();local now=GetTime();
 local all={};for _,e in pairs(self.locks or {}) do all[#all+1]=e;end;if self.healerLock then all[#all+1]=self.healerLock;end
 for _,e in ipairs(all) do
  local u=G:Unit(e.name);if e.owner~=G:Owner() or e.context~=G:Context() or not u or UnitGUID(u)~=e.guid then e.repairAt=nil;e.repairStep=nil;
  elseif e.repairAt and now>=e.repairAt and not G.op and not self.restore and now>=(G.nextSend or 0) then
   local commands={P:Anchor(e.world),string.format("go %.3f;%.3f;%.3f",e.world.x,e.world.y,e.world.z),"stay"};local command=commands[e.repairStep or 1];
   if command then G:Log("gluth_intercept_fear_repair",command,e.name);SendChatMessage(command,"WHISPER",nil,e.name);G.nextSend=now+G.interval;e.repairStep=(e.repairStep or 1)+1;
   else e.repairAt=nil;e.repairStep=nil;e.repairs=(e.repairs or 0)+1;self:Notice(e.name..": после страха возвращён на именной пост ("..e.repairs.."/2).");end
  end
 end
end
function P.Quick:Aoe(index)
 if P.Manual.aoe[index] then P.Manual:AoeStop(index,"вручную");return;end
 local name,why=self:TankName(index);if not name then self:Notice(why);return;end
 local r=P.Manual:Record(index);
 if not r or G:Key(r.name)~=G:Key(name) then self:Notice("Сначала поставьте танка "..index.." его кнопкой «Ко мне и записать».");return;end
 P.Manual:AoeToggle(index);
end
function P.Quick:DeployQueue(d,name,command,tag,member)
 d.queue[#d.queue+1]={name=name,command=command,tag=tag,member=member};
end
function P.Quick:DeployStop(reason,quiet)
 local d=self.deploy;self.deploy=nil;
 if not d then return;end
 P.Manual:AoeStopAll();
 local text="Перехват остановлен: "..tostring(reason or "вручную")..".";
 G:Log("gluth_intercept_stop",text,UnitName("player"));P.status=text;
 if not quiet then self:Notice(text);else self:Refresh();end
end
function P.Quick:BindPost(index,member,point)
 local r=P.Manual:Record(index,true);r.name=member.name;r.guid=member.guid;r.world=G:Copy(point);r.at=time();r.source="gluth_intercept";r.active=true;r.resetPending=nil;r.holdApplied=true;
 r.key="intercept_"..index.."_"..G:Hash(member.name..":"..time()..":"..GetTime());r.targetKey=r.key;
 member.arrived=true;member.aoePending=true;self:DeployQueue(self.deploy,member.name,"stay","hold",member);G:Log("gluth_intercept_arrival",P.roles[index].label,member.name);
end
function P.Quick:NearPoint(member,point)
 local u=G:Unit(member.name);if not u or UnitGUID(u)~=member.guid or GetMapInfo()~="Naxxramas" or GetCurrentMapDungeonLevel()~=1 then return false;end
 local x,y=GetPlayerMapPosition(u);if type(x)~="number" or type(y)~="number" or x<=0 or y<=0 then return false;end
 local dx=3615.830078125-y*729.2199707031-point.x;local dy=-2640.2700195312-x*1093.830078125-point.y;
 return dx*dx+dy*dy<=16;
end
function P.Quick:HasRighteousFury(member)
 local u=member and G:Unit(member.name);if not u or not UnitBuff then return false;end
 local wanted=GetSpellInfo and GetSpellInfo(25780);
 for i=1,40 do
  local name,_,_,_,_,_,_,_,_,_,id=UnitBuff(u,i)
  if not name then break end
  if tonumber(id)==25780 or wanted and name==wanted then return true end
 end
 return false;
end
function P.Quick:DeployStart()
 if not self:IsIntercept() then self:Notice("Эта кнопка относится только к режиму «40 — перехват».");return;end
 if self.deploy then self:DeployStop("остановлено вручную");return;end
 if not P:Idle() then self:Notice("Сначала завершите другую операцию UnBot или дебаг.");return;end
 local bossName=UnitName("target");local bossGuid=UnitGUID("target");local lower=tostring(bossName or ""):lower();
 if not bossGuid or (lower~="глут" and lower~="gluth") then self:Notice("Перед развёртыванием выделите самого Глута: дверной танк получает do attack my target.");return;end
 local tanks={};for i=1,4 do local name,why=self:TankName(i);if not name then self:Notice(why);return;end;local u=G:Unit(name);tanks[i]={name=name,guid=u and UnitGUID(u),index=i,point=self:Point(i)};
  if not tanks[i].point then self:Notice("Нет серверных XYZ для точки "..i.." — "..P.roles[i].label..". Встаньте туда и нажмите строку записи.");return;end
 end
 local healer,why=self:Healer();if not healer then self:Notice(why);return;end
 local now=GetTime();local d={owner=G:Owner(),context=G:Context(),bossGuid=bossGuid,bossName=bossName,tanks=tanks,healer=healer,queue={},recent={},startedAt=now,expires=now+180,nextSendAt=now,hits=0,sent=0,combatSeen=true};self.deploy=d;
 for i,m in ipairs(tanks) do if self:HasRighteousFury(m) then m.rfConfirmed=true;else self:DeployQueue(d,m.name,"cast righteous fury on "..m.name,"rf",m);end;if i==1 then self:DeployQueue(d,m.name,"do attack my target","attack",m);end end
 for i=2,4 do local m=tanks[i];self:DeployQueue(d,m.name,P:Anchor(m.point),"anchor",m);self:DeployQueue(d,m.name,string.format("go %.3f;%.3f;%.3f",m.point.x,m.point.y,m.point.z),"go",m);end
 healer.point=self:Point(4);self:DeployQueue(d,healer.name,P:Anchor(healer.point),"anchor",healer);self:DeployQueue(d,healer.name,string.format("go %.3f;%.3f;%.3f",healer.point.x,healer.point.y,healer.point.z),"go",healer);
 G:Log("gluth_intercept_start","4 random prot paladins; healer "..healer.name.."; boss "..bossGuid,UnitName("player"));self:Notice("Перехват запущен: три паладина и хил идут на точки; дверной танк "..tanks[1].name.." ждёт двух прямых ударов по Глуту.");
end
function P.Quick:DeployTick()
 self:LockTick();
 local d=self.deploy;if not d then return;end;local now=GetTime();
 if d.owner~=G:Owner() or d.context~=G:Context() then self:DeployStop("сменились персонаж или зона");return;end
 if now>=d.expires or d.sent>=30 then self:DeployStop("лимит 3 минуты / 30 команд");return;end
 if d.attackAt and not d.doorReleased and now>=d.attackAt+20 then self:DeployStop("дверной танк не подтвердил два прямых удара по Глуту за 20 секунд");return;end
 if now>=d.nextSendAt and now>=(G.nextSend or 0) and #d.queue>0 then
  local q=table.remove(d.queue,1);local u=G:Unit(q.name);if not u then self:DeployStop(q.name..": бот недоступен");return;end
  if q.tag=="attack" and UnitGUID("target")~=d.bossGuid then self:DeployStop("перед командой атаки цель игрока перестала быть Глутом");return;end
  d.sent=d.sent+1;d.nextSendAt=now+G.interval;G.nextSend=now+G.interval;d.recent[G:Key(q.name)]=now;G:Log("gluth_intercept_send",q.command,q.name);SendChatMessage(q.command,"WHISPER",nil,q.name);
  if q.tag=="rf" then q.member.rfAt=now;elseif q.tag=="attack" then d.attackAt=now;elseif q.tag=="go" then q.member.goAt=now;end
 end
 for _,m in ipairs(d.tanks) do if not m.rfConfirmed and self:HasRighteousFury(m) then m.rfConfirmed=true;end;if m.rfAt and not m.rfConfirmed and now>=m.rfAt+7 then self:DeployStop(m.name..": Праведная ярость не подтверждена за 7 секунд");return;end end
 for i=2,4 do local m=d.tanks[i];if m.goAt and not m.arrived and self:NearPoint(m,m.point) then self:BindPost(i,m,m.point);end end
 local door=d.tanks[1];if d.doorReleased and door.goAt and not door.arrived and self:NearPoint(door,door.point) then self:BindPost(1,door,door.point);end
 if d.healer.goAt and not d.healer.arrived and self:NearPoint(d.healer,d.healer.point) then d.healer.arrived=true;local s=self:Session();if s then s.healerName=d.healer.name;end;self:DeployQueue(d,d.healer.name,"stay","hold",d.healer);G:Log("gluth_intercept_healer_arrival","Центр",d.healer.name);end
 for _,m in ipairs(d.tanks) do if m.goAt and not m.arrived and now>=m.goAt+90 then self:DeployStop(m.name..": не пришёл на точку за 90 секунд");return;end end
 if d.healer.goAt and not d.healer.arrived and now>=d.healer.goAt+90 then self:DeployStop(d.healer.name..": хил не пришёл в центр за 90 секунд");return;end
 if #d.queue==0 and now>=(G.nextSend or 0) then
  for i,m in ipairs(d.tanks) do
   if m.aoePending then m.aoePending=nil;m.aoeStarted=true;P.Manual:AoeToggle(i);break end
  end
 end
 if d.doorReleased and d.healer.arrived then
  local all=true
  for _,m in ipairs(d.tanks) do
   if not m.arrived or not m.aoeStarted then all=false;break end
  end
  if all and not d.ready then d.ready=true;self:Notice("Посты готовы: 4/4 паладина закреплены, Освящение включено; хил "..d.healer.name.." в центре.");end
 end
end
function P.Quick:DeployReply(message,sender)
 local d=self.deploy;if not d then return false;end;local sent=d.recent[G:Key(sender)];if not sent or GetTime()-sent>7 then return false;end
 local text=tostring(message or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","");local lower=text:lower();local id=tonumber(text:match("|Hspell:(%d+)"));
 if lower:match("^casting ") and id==25780 then for _,m in ipairs(d.tanks) do if G:Key(m.name)==G:Key(sender) then m.rfConfirmed=true;G:Log("gluth_intercept_rf",text,m.name);return true;end end end
 if G:Refusal(lower) then self:DeployStop(sender..": отказ сервера — "..text);return true;end;return false;
end
function P.Quick:DeploySystem(message)
 local text=tostring(message or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","");local name,body=text:match("^%s*([^:]+):%s*(.*)$");if not name then return false;end
 return self:DeployReply(body,name:match("^%s*(.-)%s*$"):gsub("^%[",""):gsub("%]$",""));
end
function P.Quick:DeployCombat(kind,source,sourceName,dest,destName,spell)
 if kind=="SPELL_AURA_REMOVED" and tonumber(spell)==29685 then
  local all={};for _,e in pairs(self.locks or {}) do all[#all+1]=e;end;if self.healerLock then all[#all+1]=self.healerLock;end
  for _,e in ipairs(all) do if dest==e.guid and (e.repairs or 0)<2 then e.repairAt=GetTime()+0.5;e.repairStep=1;G:Log("gluth_intercept_fear_removed","bounded return queued",e.name);end end
 end
 local d=self.deploy;if not d then return;end
 if kind=="SPELL_CAST_SUCCESS" and tonumber(spell)==25780 then
  for _,m in ipairs(d.tanks or {}) do if source==m.guid then m.rfConfirmed=true;break end end
 end
 if (kind=="UNIT_DIED" or kind=="PARTY_KILL") and dest==d.bossGuid then self:DeployStop("Глут погиб");return;end
 local door=d.tanks and d.tanks[1];if not door or d.doorReleased or source~=door.guid or dest~=d.bossGuid then return;end
 local direct=kind=="SWING_DAMAGE" or kind=="RANGE_DAMAGE" or kind=="SPELL_DAMAGE" and not P.Manual.aoeSpells.PALADIN.ids[tonumber(spell) or 0];
 if direct then d.hits=d.hits+1;G:Log("gluth_intercept_boss_hit",kind.." #"..d.hits,door.name);if d.hits>=2 then d.doorReleased=true;self:DeployQueue(d,door.name,P:Anchor(door.point),"anchor",door);self:DeployQueue(d,door.name,string.format("go %.3f;%.3f;%.3f",door.point.x,door.point.y,door.point.z),"go",door);self:Notice(door.name..": два прямых удара по Глуту подтверждены — отправляю к двери.");end end
end
function P.Quick:DeployCombatEnd()
 local d=self.deploy;if d and d.combatSeen then self:DeployStop("бой завершён или произошёл вайп");end
end
function P.Quick:Hunters()
 if P.Hunters.run then P.Hunters:Stop("вручную");return;end
 if not P:Idle() then self:Notice("Дождитесь завершения призыва или текущей операции.");return;end
 local hunters,why=self:Members("hunter","mm");
 if not hunters then self:Notice(why);return;end
 if #hunters~=3 then self:Notice("MM-охотники: найдено "..#hunters.."/3."..(why~="" and (" "..why) or " Дождитесь подтверждения трёх охотников в сборщике."));return;end
 local slots=P.Hunters:Slots(true);
 for i,m in ipairs(hunters) do slots[i]=slots[i] or {};slots[i].name=m.name;slots[i].guid=m.guid;end
 P.Hunters:Start();
end
function P.Quick:Refresh()
 local f=self.frame;if not f then return;end
 if self.Corridor:Active() then self.Corridor:Refresh(f);return;end
 f.title:SetText("Глут — быстрая постановка");f.corridorArrange:Hide();f.corridor1:Hide();f.corridor2:Hide();
 local count=self:TankCount();local session=self:Session();
  if self:IsIntercept() then
   f:SetWidth(560);f.help:SetWidth(520);f.help:SetHeight(38);f.help:SetText("СХЕМА ПОСТОВ: дверь сверху, решётки слева/справа, центр снизу.\nИмена выбраны автоматически. Встаньте в точку и нажмите её большую кнопку.");
   self:AutoAssignTanks();session=self:Session();
   local layout={{120,86,320},{290,157,250},{20,157,250},{120,228,320}};
   local titles={"1. ДВЕРЬ / БОСС","2. ПРАВАЯ РЕШЁТКА","3. ЛЕВАЯ РЕШЁТКА","4. ЦЕНТР — ПАЛАДИН"};
   for i,row in ipairs(f.tanks) do local pos=layout[i];local name=session and session.tankNames and session.tankNames[i];local r=P.Manual:Record(i);local fixed=r and r.active and G:Key(r.name)==G:Key(name);
    row.place:Show();row.info:Show();row.aoe:Hide();row.assign:Hide();row.place:ClearAllPoints();row.place:SetPoint("TOPLEFT",pos[1],-pos[2]);row.place:SetWidth(pos[3]);row.place:SetHeight(32);row.place:SetText(titles[i]..": "..(name or "ПАЛАДИН НЕ НАЙДЕН"));
    row.info:ClearAllPoints();row.info:SetPoint("TOPLEFT",pos[1],-(pos[2]+33));row.info:SetWidth(pos[3]);row.info:SetJustifyH("CENTER");row.info:SetText(fixed and "ЗАКРЕПЛЁН НА ПОСТУ" or (i==1 and "СНАЧАЛА ЦЕЛЬ = ГЛУТ; ЗАТЕМ НАЖАТЬ" or "НАЖАТЬ = ПРИЗВАТЬ И ОСТАНОВИТЬ ЗДЕСЬ"));
   end
   f.deploy:ClearAllPoints();f.deploy:SetPoint("TOPLEFT",20,-299);f.deploy:SetWidth(520);f.deploy:Show();local healer=session and session.healerName;f.deploy:SetText("DISC-ХИЛ В ЦЕНТР"..(healer and (": "..healer) or ""));f.hunters:Hide();f.naxx:Hide();
   f.cancel:ClearAllPoints();f.cancel:SetPoint("TOPLEFT",20,-335);f.cancel:SetWidth(520);f.cancel:Show();f.cancel:SetText(session and session.active and "ОТМЕНИТЬ СЦЕНАРИЙ И ОСВОБОДИТЬ ВСЕХ" or "ВКЛЮЧИТЬ СЦЕНАРИЙ ГЛУТА");
   f.status:ClearAllPoints();f.status:SetPoint("TOPLEFT",20,-373);f.status:SetWidth(520);f.status:SetText(P.status or "Одна кнопка поста выполняет всю цепочку: призыв → остановка → фиксация. Остальные паладины останавливаются автоматически.");
   local height=f.status.GetStringHeight and f.status:GetStringHeight();height=math.max(30,math.min(84,(tonumber(height) or 30)+4));f.status:SetHeight(height);f:SetHeight(373+height+18);return;
  end
  f:SetWidth(380);f.help:SetWidth(340);f.help:SetHeight(28);f.cancel:SetWidth(340);f.status:SetWidth(340);f.deploy:Hide();for _,row in ipairs(f.tanks) do row.assign:Hide();end
  f.help:SetText(count==4 and "При призыве всем снимаются co/nc naxx.\nЧетыре кнопки: только summon → stay." or "Постановка танка: только summon → stay.\nНикаких опросов и повторов.");
 for i,row in ipairs(f.tanks) do
  if i<=count then
   local rowY=74+(i-1)*52;row.place:ClearAllPoints();row.place:SetPoint("TOPLEFT",20,-rowY);row.place:SetHeight(26);row.info:ClearAllPoints();row.info:SetPoint("TOPLEFT",20,-(rowY+28));row.info:SetWidth(340);row.info:SetJustifyH("LEFT");row.aoe:ClearAllPoints();row.aoe:SetPoint("TOPLEFT",260,-rowY);row.place:Show();row.info:Show();if count==4 then row.aoe:Hide();row.place:SetWidth(340);else row.aoe:Show();row.place:SetWidth(232);end
   local r=P.Manual:Record(i);local name=session and session.tankNames and session.tankNames[i];
    row.place:SetText(i..". Призвать и оставить танка");
   local e=P.Manual.aoe[i];row.aoe:SetText(e and "Стоп АоЕ" or "АоЕ");
    local coords=r and r.mapPoint and string.format(" | карта %.2f%% %.2f%%",r.mapPoint.x*100,r.mapPoint.y*100)
     or r and r.world and string.format(" | %.1f %.1f %.1f",r.world.x,r.world.y,r.world.z or 0)
     or r and " | summon+stay отправлены";
    row.info:SetText((name or ("Танк "..i)).." — "..P.roles[i].label..(r and G:Key(r.name)==G:Key(name) and coords or " | точка не записана"));
  else row.place:Hide();row.aoe:Hide();row.info:Hide();end
 end
 local y=74+count*52;
 for _,entry in ipairs({{f.hunters,y},{f.naxx,y+33},{f.cancel,y+66}}) do entry[1]:ClearAllPoints();entry[1]:SetPoint("TOPLEFT",20,-entry[2]);if count==4 then entry[1]:Hide();else entry[1]:Show();end end
 local statusY=count==4 and y or y+101;f.status:ClearAllPoints();f.status:SetPoint("TOPLEFT",20,-statusY);
 f.status:SetText(P.status or "Поставьте каждого танка на место его кнопкой; координаты сохраняются.");
 local height=f.status.GetStringHeight and f.status:GetStringHeight();height=math.max(24,math.min(84,(tonumber(height) or 24)+4));
 f.status:SetHeight(height);f:SetHeight(statusY+height+16);
 f.cancel:SetText(session and session.active and "Отменить сценарий Глута" or "Включить сценарий Глута");
 f.hunters:SetText(P.Hunters.run and "Стоп RTI зомби" or "Включить 3 хантов: RTI зомби");
end
function P.Quick:NaxxAll()
 if GetNumRaidMembers()==0 and GetNumPartyMembers()==0 then self:Notice("Нужна группа или рейд.");return;end
 P.Manual:NaxxOff(true);
 self:Notice("Команды co -naxx и nc -naxx отправлены всем ботам текущей группы/рейда.");
end
function P.Quick:SummonTick()
 self.Corridor:Tick();
 local watch=self.naxxSummon;if not watch then return;end
 local now=GetTime();
 if now>=(watch.expires or 0) or watch.owner~=G:Owner() or watch.context~=G:Context() then self.naxxSummon=nil;return;end
 local summon=UnBotSpecSummon;
 if not watch.started then
  if summon and summon.active and summon.mode=="squad" and summon.squad then
   watch.started=true;watch.squad=summon.squad;
  elseif now>=(watch.startDeadline or 0) then self.naxxSummon=nil;return;
  else return;end
 elseif not summon or not summon.active or summon.mode~="squad" or summon.squad~=watch.squad then
  self.naxxSummon=nil;return;
 end
 local function removeNaxx(name)
  if not name or watch.sent[G:Key(name)] or not G:Unit(name) then return;end
  watch.sent[G:Key(name)]=true;
  SendChatMessage("co -naxx","WHISPER",nil,name);SendChatMessage("nc -naxx","WHISPER",nil,name);
  G:Log("gluth_summon_naxx","co -naxx; nc -naxx",name);
 end
 removeNaxx(summon.requestedName);removeNaxx(summon.candidate);
end
function P.Quick:OnSummon(preset)
 if not preset or preset.bossKey~="naxxramas__gluth" then return;end
 self:Activate(preset);P.Manual:NaxxOff(true);
 self.naxxSummon={owner=G:Owner(),context=G:Context(),expires=GetTime()+1200,startDeadline=GetTime()+5,sent={}};
 if preset.modeKey=="40n_corridor" then
  self.Corridor.status="Собираю восемь ботов. После завершения призыва автоматически разложу две группы. Медведь назначается через кнопку группы 1 и Enter.";
  self:Show();
  return;
 end
 P.status=self:IsIntercept() and "Четыре протопаладина распределены по постам автоматически. Встаньте у нужного поста и нажмите его большую кнопку; для двери держите Глута в цели." or "При призыве всем снимаются co/nc naxx. Четыре кнопки танков отправляют только summon и stay.";self:Show();
end
function P.Quick:Open()
 -- Compatibility with an already summoned Gluth composition from versions without a session marker.
 if not self:Session() then self:Activate();end
 self.lastNotice=nil;P.status="Сценарий Глута сохраняется при переходе в инстанс и /reload, пока вы его не отмените.";
 self:Show();
end
function P.Quick:Show()
 if self.frame then self:Refresh();self.frame:Show();return;end
 local f=CreateFrame("Frame","UnBotGluthQuickFrame",UIParent);self.frame=f;
 f:SetWidth(380);f:SetHeight(184);f:SetPoint("CENTER",UIParent,"CENTER",180,0);f:SetFrameStrata("DIALOG");f:SetMovable(true);f:EnableMouse(true);f:SetClampedToScreen(true);
 f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=32,insets={left=11,right=12,top=12,bottom=11}});
 local function label(text,y,height)
  local t=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");t:SetPoint("TOPLEFT",20,-y);t:SetWidth(340);t:SetHeight(height);t:SetJustifyH("LEFT");t:SetText(text);return t;
 end
 local function button(text,y,fn)
  local b=CreateFrame("Button",nil,f,"UIPanelButtonTemplate");b:SetPoint("TOPLEFT",20,-y);b:SetWidth(340);b:SetHeight(26);b:SetText(text);b:SetScript("OnClick",fn);return b;
 end
  f.title=label("Глут — быстрая постановка",16,18);
 f:RegisterForDrag("LeftButton");f:SetScript("OnDragStart",function(s) s:StartMoving();end);f:SetScript("OnDragStop",function(s) s:StopMovingOrSizing();end);
 local drag=CreateFrame("Frame",nil,f);f.dragHandle=drag;drag:SetWidth(325);drag:SetHeight(28);drag:SetPoint("TOPLEFT",10,-10);drag:EnableMouse(true);drag:RegisterForDrag("LeftButton");drag:SetScript("OnDragStart",function() f:StartMoving();end);drag:SetScript("OnDragStop",function() f:StopMovingOrSizing();end);
 local close=CreateFrame("Button",nil,f,"UIPanelCloseButton");close:SetPoint("TOPRIGHT",-5,-5);close:SetScript("OnClick",function() f:Hide();end);
 f.help=label("",40,28);
 f.tanks={};for i=1,4 do local index=i;local y=74+(i-1)*52;
  local place=button("",y,function() P.Quick:Place(index);end);place:SetWidth(232);
  local aoe=button("АоЕ",y,function() if P.Quick:IsIntercept() then P.Quick:CapturePoint(index);else P.Quick:Aoe(index);end end);aoe:ClearAllPoints();aoe:SetPoint("TOPLEFT",260,-y);aoe:SetWidth(100);
  local assign=button("Имя",y,function() P.Quick:AssignTank(index);end);assign:ClearAllPoints();assign:SetPoint("TOPLEFT",280,-y);assign:SetWidth(80);assign:Hide();
  f.tanks[i]={place=place,aoe=aoe,assign=assign,info=label("",y+28,18)};
 end
 f.place=f.tanks[1].place;
 f.deploy=button("Поставить Disc-хила здесь",282,function() P.Quick:PlaceHealer();end);
 f.hunters=button("Включить 3 хантов: RTI зомби",106,function() P.Quick:Hunters();end);
 f.naxx=button("−naxx всей группе / рейду",139,function() P.Quick:NaxxAll();end);
 f.cancel=button("Отменить сценарий Глута",172,function() P.Quick:ToggleSession();end);
 f.status=label("",207,26);f.status:SetJustifyV("TOP");
 f.corridorArrange=button("Разложить группы",126,function() P.Quick.Corridor:Start();end);f.corridorArrange:SetWidth(440);
 f.corridor1=button("1. Призвать группу босса (5 ботов)",162,function() P.Quick.Corridor:Summon(1);end);f.corridor1:SetWidth(440);
 f.corridor2=button("2. Призвать группу зомби (3 бота)",198,function() P.Quick.Corridor:Summon(2);end);f.corridor2:SetWidth(440);
 self:Refresh();
end

function P.Manual:CreateUI()
 if P.frame then return;end
 local f=CreateFrame("Frame","UnBotGuardPresetsFrame",UIParent);P.frame=f;f.manual=true;
 f:SetWidth(540);f:SetHeight(445);f:SetPoint("CENTER",UIParent,"CENTER",40,0);f:SetFrameStrata("DIALOG");
 f:SetClampedToScreen(true);f:SetMovable(true);f:EnableMouse(true);
 f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=32,insets={left=11,right=12,top=12,bottom=11}});
 local function label(text,x,y,width,style)
  local t=f:CreateFontString(nil,"OVERLAY",style or "GameFontHighlightSmall");t:SetPoint("TOPLEFT",f,"TOPLEFT",x,-y);t:SetWidth(width);t:SetJustifyH("LEFT");t:SetText(text);return t;
 end
 local function button(text,x,y,width,fn)
  local b=CreateFrame("Button",nil,f,"UIPanelButtonTemplate");b:SetWidth(width);b:SetHeight(28);b:SetPoint("TOPLEFT",f,"TOPLEFT",x,-y);b:SetText(text);b:SetScript("OnClick",fn);return b;
 end
 label("Глут — ручная расстановка",25,22,460,"GameFontNormalLarge");
 label("Встаньте на нужное место и выделите конкретного бота в группе.",25,52,490);
 local drag=CreateFrame("Frame",nil,f);f.dragHandle=drag;drag:SetWidth(465);drag:SetHeight(40);drag:SetPoint("TOPLEFT",f,"TOPLEFT",12,-10);drag:EnableMouse(true);drag:RegisterForDrag("LeftButton");drag:SetScript("OnDragStart",function() f:StartMoving();end);drag:SetScript("OnDragStop",function() f:StopMovingOrSizing();end);
 local close=CreateFrame("Button",nil,f,"UIPanelCloseButton");f.close=close;close:SetWidth(32);close:SetHeight(32);close:SetPoint("TOPRIGHT",f,"TOPRIGHT",-5,-5);close:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up");close:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down");close:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight","ADD");close:SetScript("OnClick",function() f:Hide();end);
 f.pointTabs={};for i=1,#P.roles do local index=i;f.pointTabs[i]=button("",25+(i-1)*125,82,115,function() P.selected=index;P:Refresh();end);end
 f.post=label("",25,120,490);f.post:SetHeight(36);
 f.place=button("Призвать выделенного и записать точку",25,166,490,function() P.Manual:Place();end);
 f.reset=button("Снять пост выделенного",25,205,330,function() P.Manual:Reset();end);
 f.stop=button("Стоп",363,205,152,function() G:Stop();P:Refresh();end);
 f.aoe=button("Включить АоЕ у поста",25,244,490,function() P.Manual:AoeToggle();end);
 f.aoeInfo=label("",25,280,490);f.aoeInfo:SetHeight(30);
 f.naxx=button("Отключить naxx рейду",25,319,240,function() P.Manual:NaxxOff();end);
 f.hunters=button("3 охотника: RTI зомби",275,319,240,function() P.Hunters:Show();end);
 f.status=label("",25,360,490);f.status:SetHeight(62);f.status:SetJustifyV("TOP");
 f:SetScript("OnShow",function() P:Refresh();end);P:EnsureToggle();f:Hide();self:Refresh();
end

P:CreateUI();
