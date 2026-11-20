-- Public release bootstrap; no account/character allowlist and no network operations.
UnBotPublicRegistry={};
local P=UnBotPublicRegistry;
P.classes={warrior=true,paladin=true,hunter=true,rogue=true,priest=true,shaman=true,mage=true,warlock=true,druid=true,dk=true};
function P.Server()
 return tostring(GetCVar and GetCVar("realmList") or ""):gsub("^%s+",""):gsub("%s+$",""):gsub("/+$",""):lower();
end
function P.Source()
 local seed=UnBotPublicRegistrySeed;
 if type(seed)~="table" or seed.schema~=1 or P.Server()=="" or P.Server()~=seed.serverKey
  or not UnBotRegistryCurrentContext then return;end
 local context=UnBotRegistryCurrentContext();
 local bucket=seed.contexts and seed.contexts[context];
 if type(bucket)=="table" and type(bucket.bots)=="table" then return bucket,seed.serverKey.."|"..context,seed.seedId;end
end
function P.Apply(target)
 local source,key,id=P.Source();
 if not source or type(target)~="table" then return 0,0;end
 target.meta=target.meta or {};target.bots=target.bots or {};
 if target.meta.publicRegistrySeedId==id and target.meta.publicRegistrySeedContext==key then return 0,0;end
 local added,classes=0,0;local existing={};
 for name in pairs(target.bots) do
  local canonical=UnBotSharedNames and UnBotSharedNames.Name(name);if canonical then existing[canonical]=name;end
 end
 for name,className in pairs(source.bots) do
  local canonical=UnBotSharedNames and UnBotSharedNames.Name(name);
  local actual=existing[name] or name;local profile=target.bots[actual];
  if canonical==name and name~=UnitName("player") and not UnBotIsAccountAltProfile(actual,profile)
   and not (UnBotSharedNames and UnBotSharedNames.Protected(name)) then
   if not profile then profile={name=name,sharedNameOnly=true};target.bots[actual]=profile;added=added+1;end
   if type(profile)=="table" and not profile.className and P.classes[className] then
    profile.className=className;profile.sharedNameOnly=nil;classes=classes+1;
   end
   UnBotKnownBots[actual]=true;
  end
 end
 target.meta.publicRegistrySeedId=id;target.meta.publicRegistrySeedContext=key;
 target.meta.publicRegistryNames=source.count;target.meta.publicRegistryClasses=source.classCount;
 return added,classes;
end
function P.Report()
 local source=P.Source();if not source or not DEFAULT_CHAT_FRAME then return;end
 local realm=GetRealmName() or "";
 local faction=UnitFactionGroup("player")=="Horde" and "Орда" or "Альянс";
 DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99UnBot|r: Общая база ботов: "..realm.." / "..faction.." — "..source.count.." имён, "..source.classCount.." с классом.");
end
