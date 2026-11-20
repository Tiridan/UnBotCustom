
function RecvQuestReward(name, info)
	local i1, i2 = string.find(info, "Hitem");
	if (i1 == nil or i2 == nil) then
		return;
	end
	
	local textList = UnBotSplit(string.sub(info, i2), "Hitem:");
	local itemIDs = {};
	for i=1, #textList do
		local itemID = tonumber(string.match(textList[i],"%d+"));
		if (itemID ~= nil) then
			local texture;
			local itemName;
			itemName,_,_,_,_,_,_,_,_,texture = GetItemInfo(itemID);
			local needQuery = false;
			if (itemName == nil or texture == nil) then
				YssBossLoot:QueryItemInfo(itemID);
				itemName = "???";
				texture = "Interface\\Icons\\Temp";
				needQuery = true;
			end
			local itemInfo = {[1] = itemID, [2] = needQuery, [3] = tostring(name), [4] = texture, [5] = tostring(itemName)};
			table.insert(itemIDs, itemInfo);
		end
	end
	if (#itemIDs > 0) then
		ShowQuestReward(name, itemIDs);
	end
end

function ShowQuestReward(name, items)
	local qrFrame = CreateFrame("Frame","QR"..name,UIParent,"QuestRewardFrame");
	qrFrame.showTick = GetTime();
	local qrLabel = _G[qrFrame:GetName().."TitleLabel"];
	if (qrLabel ~= nil) then
		qrLabel:SetText(name..UnBotLocale.Text(" |cffcccc00Select reward for completing quests|r")); -- Needs correction
	else
		DisplayInfomation("Complete quest reward panelLabel "..qrFrame:GetName().."TitleLabel Not found, failed to set player name "..name); -- Needs correction
	end
	local qrBar = _G[qrFrame:GetName().."TickBar"];
	if (qrBar ~= nil) then
		qrBar:SetPoint("CENTER", qrFrame, "TOP", 0, -7);
		qrFrame.tickBar = qrBar;
		qrFrame.tickBar:SetValue(0);
	end
	for i=1, #items do
		local item = items[i];
		local qrBtn = CreateFrame("Button",qrFrame:GetName()..tostring(i),qrFrame,"QuestRewardButtonTemplate");
		local offsetX = 15 + (qrBtn:GetWidth() + 8) * (i - 1);
		qrBtn:SetPoint("BOTTOMLEFT", qrFrame, "BOTTOMLEFT", offsetX, 15);
		qrBtn.item = item;
		if (item[4] ~= nil) then
			qrBtn:SetNormalTexture(item[4]);
		end
		table.insert(qrFrame.rewardItems, item);
		table.insert(qrFrame.rewardBtns, qrBtn);
		qrBtn:Show();
	end
	
	local frameCount = #UnBotFrame.ShowedQRs;
	local startHeight = (UIParent:GetHeight() - (qrFrame:GetHeight() + 30) * 4) / 2;
	local posY = startHeight + (frameCount % 4) * (qrFrame:GetHeight() + 30);
	qrFrame:SetPoint("CENTER", UIParent, "TOPLEFT", UIParent:GetWidth() / 2, posY * (-1));
	qrFrame:Show();
	table.insert(UnBotFrame.ShowedQRs, qrFrame);
end

function UnBotShowQuestRewardTips(self, item)
	if (self == nil or item == nil) then
		return;
	end
	GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT");
	if (item[2] == true) then
		local texture;
		local itemName;
		itemName,_,_,_,_,_,_,_,_,texture = GetItemInfo(item[1]);
		if (itemName ~= nil and texture ~= nil) then
			self.item[2] = false;
			self.item[4] = texture;
			self.item[5] = tostring(itemName);
			self:SetNormalTexture(self.item[4]);
			GameTooltip:SetHyperlink("item:"..tostring(item[1])..":0:0:0:0:0:0:0");
		else
			GameTooltip:AddLine(item[5],1,0,0,1);
			GameTooltip:AddLine(" ",1,1,1,1);
			GameTooltip:AddLine(UnBotLocale.Text("This item has not appeared on your client. You need to wait for a moment to query the server and then move the mouse to this item again."),1,0,0,1); -- Needs correction
		end
	else
		GameTooltip:SetHyperlink("item:"..tostring(item[1])..":0:0:0:0:0:0:0");
	end

	if (self.item[2] == false) then
		GameTooltip:AddLine(" ",1,1,1,1);
		GameTooltip:AddLine(UnBotLocale.Text("Left mouse button: Select ")..item[3]..UnBotLocale.Text(" as the quest reward"),1,0,0,1);
	end
	GameTooltip:Show();
end

function UnBotSelectQuestReward(self, item)
	if (self == nil or item == nil or item[2] == nil or item[2] == true) then
		return;
	end
	local itemLink
	_,itemLink,_,_,_,_,_,_,_,_ = GetItemInfo(tostring(item[1]));
	SendChatMessage("r "..itemLink, "WHISPER", nil, item[3]);
	local qr = self:GetParent();
	UnBotRemoveByQRFrame(qr);
	setglobal(qr:GetName().."TitleLabel", nil);
	qr:Hide();
	qr:SetParent(nil);
end

function UnBotQuestRewardTick(qrFrame, tick)
	if (qrFrame.showTick > 0) then
		if  ((tick - qrFrame.showTick) > qrFrame.waitTime) then
			qrFrame.showTick = 0;
			qrFrame.tickBar = nil;
			if ((#qrFrame.rewardItems) > 0 and (#qrFrame.rewardBtns) > 0) then
				UnBotSelectQuestReward(qrFrame.rewardBtns[1], qrFrame.rewardItems[1]);
			end
		else
			if (qrFrame.tickBar ~= nil and qrFrame.waitTime > 0) then
				local timed = tick - qrFrame.showTick;
				if (timed > qrFrame.waitTime) then
					timed = qrFrame.waitTime;
				end
				qrFrame.tickBar:SetValue(timed / qrFrame.waitTime);
			end
		end
	end
end


-- Player-owned alt journals. Replies are collected independently of chat display filters.
UnBotAltQuests = UnBotAltQuests or {cache={}, altOffset=0, questOffset=0, missingOnly=true};
local Q = UnBotAltQuests;

-- Class masks from installed Questie WotLK quest data, fields 7/17; 1065 IDs.
-- Display metadata only; no dependency on Questie at runtime.
Q.classMasks={
    [26]=1024,[27]=1024,[28]=1024,[29]=1024,[30]=1024,[31]=1024,[63]=64,[96]=64,[100]=64,[220]=64,[272]=1024,[397]=256,[972]=64,[1103]=64,
    [1442]=2,[1462]=64,[1463]=64,[1464]=64,[1470]=256,[1471]=256,[1472]=256,[1473]=256,[1474]=256,[1476]=256,[1478]=256,[1485]=256,[1498]=1,[1499]=256,
    [1501]=256,[1502]=1,[1503]=1,[1504]=256,[1505]=1,[1506]=256,[1507]=256,[1508]=256,[1509]=256,[1510]=256,[1511]=256,[1512]=256,[1513]=256,[1515]=256,
    [1516]=64,[1517]=64,[1518]=64,[1519]=64,[1520]=64,[1521]=64,[1522]=64,[1523]=64,[1524]=64,[1525]=64,[1526]=64,[1527]=64,[1528]=64,[1529]=64,
    [1530]=64,[1531]=64,[1532]=64,[1534]=64,[1535]=64,[1536]=64,[1598]=256,[1599]=256,[1638]=1,[1639]=1,[1640]=1,[1641]=2,[1642]=2,[1643]=2,
    [1644]=2,[1645]=2,[1646]=2,[1647]=2,[1648]=2,[1649]=2,[1650]=2,[1651]=2,[1652]=2,[1653]=2,[1654]=2,[1655]=2,[1661]=2,[1665]=1,
    [1666]=1,[1667]=1,[1678]=1,[1679]=1,[1680]=1,[1681]=1,[1682]=1,[1683]=1,[1684]=1,[1685]=256,[1686]=1,[1688]=256,[1689]=256,[1692]=1,
    [1693]=1,[1698]=1,[1699]=1,[1700]=1,[1701]=1,[1702]=1,[1703]=1,[1704]=1,[1705]=1,[1706]=1,[1708]=1,[1709]=1,[1710]=1,[1711]=1,
    [1712]=1,[1713]=1,[1714]=1,[1715]=256,[1716]=256,[1717]=256,[1718]=1,[1719]=1,[1738]=256,[1739]=256,[1740]=256,[1758]=256,[1778]=2,[1779]=2,
    [1780]=2,[1781]=2,[1783]=2,[1784]=2,[1785]=2,[1786]=2,[1787]=2,[1788]=2,[1789]=2,[1790]=2,[1791]=1,[1792]=1,[1793]=2,[1794]=2,
    [1795]=256,[1796]=256,[1798]=256,[1799]=256,[1801]=256,[1802]=256,[1803]=256,[1804]=256,[1805]=256,[1806]=2,[1818]=1,[1819]=1,[1820]=1,[1821]=1,
    [1822]=1,[1823]=1,[1824]=1,[1825]=1,[1838]=1,[1839]=1,[1840]=1,[1841]=1,[1842]=1,[1843]=1,[1844]=1,[1845]=1,[1846]=1,[1847]=1,
    [1848]=1,[1858]=8,[1859]=8,[1860]=128,[1861]=128,[1879]=128,[1880]=128,[1881]=128,[1882]=128,[1883]=128,[1884]=128,[1885]=8,[1886]=8,[1898]=8,
    [1899]=8,[1919]=128,[1920]=128,[1921]=128,[1938]=128,[1939]=128,[1940]=128,[1941]=128,[1942]=128,[1943]=128,[1944]=128,[1945]=128,[1946]=128,[1947]=128,
    [1948]=128,[1949]=128,[1950]=128,[1951]=128,[1952]=128,[1953]=128,[1954]=128,[1955]=128,[1956]=128,[1957]=128,[1958]=128,[1959]=128,[1960]=128,[1961]=128,
    [1962]=128,[1963]=8,[1978]=8,[1998]=8,[1999]=8,[2000]=8,[2018]=8,[2019]=8,[2205]=8,[2206]=8,[2218]=8,[2238]=8,[2239]=8,[2241]=8,
    [2242]=8,[2259]=8,[2260]=8,[2281]=8,[2282]=8,[2298]=8,[2299]=8,[2300]=8,[2358]=8,[2359]=8,[2360]=8,[2378]=8,[2379]=8,[2380]=8,
    [2381]=8,[2382]=8,[2383]=1,[2458]=8,[2460]=8,[2478]=8,[2479]=8,[2480]=8,[2607]=8,[2608]=8,[2609]=8,[2983]=64,[2984]=64,[2985]=64,
    [2986]=64,[2996]=256,[2997]=2,[2998]=2,[2999]=2,[3000]=2,[3001]=256,[3065]=1,[3082]=4,[3083]=8,[3084]=64,[3085]=16,[3086]=128,[3087]=4,
    [3088]=8,[3089]=64,[3090]=256,[3091]=1,[3092]=4,[3093]=64,[3094]=1024,[3095]=1,[3096]=8,[3097]=16,[3098]=128,[3099]=256,[3100]=1,[3101]=2,
    [3102]=8,[3103]=16,[3104]=128,[3105]=256,[3106]=1,[3107]=2,[3108]=4,[3109]=8,[3110]=16,[3112]=1,[3113]=8,[3114]=128,[3115]=256,[3116]=1,
    [3117]=4,[3118]=8,[3119]=16,[3120]=1024,[3631]=256,[3681]=2,[4485]=2,[4486]=2,[4487]=256,[4488]=256,[4489]=256,[4490]=256,[4736]=256,[4737]=256,
    [4738]=256,[4739]=256,[4781]=256,[4782]=256,[4783]=256,[4784]=256,[4785]=256,[4786]=256,[4961]=256,[4962]=256,[4963]=256,[4964]=256,[4965]=256,[4967]=256,
    [4968]=256,[4969]=256,[4975]=256,[4976]=256,[5061]=1024,[5621]=16,[5622]=16,[5623]=16,[5624]=16,[5625]=16,[5626]=16,[5627]=16,[5628]=16,[5629]=16,
    [5630]=16,[5631]=16,[5632]=16,[5633]=16,[5634]=16,[5635]=16,[5636]=16,[5637]=16,[5638]=16,[5639]=16,[5640]=16,[5641]=16,[5642]=16,[5643]=16,
    [5644]=16,[5645]=16,[5646]=16,[5647]=16,[5648]=16,[5649]=16,[5650]=16,[5651]=16,[5652]=16,[5654]=16,[5655]=16,[5656]=16,[5657]=16,[5658]=16,
    [5659]=16,[5660]=16,[5661]=16,[5662]=16,[5663]=16,[5672]=16,[5673]=16,[5674]=16,[5675]=16,[5676]=16,[5677]=16,[5678]=16,[5679]=16,[5680]=16,
    [5921]=1024,[5922]=1024,[5923]=1024,[5924]=1024,[5925]=1024,[5926]=1024,[5927]=1024,[5928]=1024,[5929]=1024,[5930]=1024,[5931]=1024,[5932]=1024,[6001]=1024,[6002]=1024,
    [6061]=4,[6062]=4,[6063]=4,[6064]=4,[6065]=4,[6066]=4,[6067]=4,[6068]=4,[6069]=4,[6070]=4,[6071]=4,[6072]=4,[6073]=4,[6074]=4,
    [6075]=4,[6076]=4,[6081]=4,[6082]=4,[6083]=4,[6084]=4,[6085]=4,[6086]=4,[6087]=4,[6088]=4,[6089]=4,[6101]=4,[6102]=4,[6103]=4,
    [6121]=1024,[6122]=1024,[6123]=1024,[6124]=1024,[6125]=1024,[6126]=1024,[6127]=1024,[6128]=1024,[6129]=1024,[6130]=1024,[6681]=8,[6701]=8,[6721]=4,[6722]=4,
    [7463]=128,[7498]=8,[7499]=1,[7500]=128,[7501]=2,[7502]=256,[7503]=4,[7504]=16,[7505]=64,[7506]=1024,[7562]=256,[7563]=256,[7564]=256,[7581]=256,
    [7582]=256,[7583]=256,[7601]=256,[7602]=256,[7603]=256,[7621]=16,[7622]=16,[7623]=256,[7624]=256,[7625]=256,[7626]=256,[7627]=256,[7628]=256,[7629]=256,
    [7630]=256,[7631]=256,[7632]=4,[7633]=4,[7634]=4,[7635]=4,[7636]=4,[7637]=2,[7638]=2,[7639]=2,[7640]=2,[7641]=2,[7642]=2,[7643]=2,
    [7644]=2,[7645]=2,[7646]=2,[7647]=2,[7648]=2,[7666]=2,[7667]=64,[7668]=64,[7669]=64,[7670]=2,[8041]=1,[8042]=1,[8043]=1,[8044]=1,
    [8045]=2,[8046]=2,[8047]=2,[8048]=2,[8049]=16,[8050]=16,[8051]=16,[8052]=16,[8053]=2,[8054]=2,[8055]=2,[8056]=64,[8057]=1024,[8058]=1,
    [8059]=256,[8060]=128,[8061]=16,[8062]=4,[8063]=8,[8064]=1024,[8065]=1024,[8066]=4,[8067]=4,[8068]=128,[8069]=128,[8070]=16,[8071]=16,[8072]=8,
    [8073]=8,[8074]=64,[8075]=64,[8076]=256,[8077]=256,[8078]=1,[8079]=1,[8101]=128,[8102]=128,[8103]=128,[8104]=128,[8106]=256,[8107]=256,[8108]=256,
    [8109]=256,[8110]=1024,[8111]=1024,[8112]=1024,[8113]=1024,[8116]=64,[8117]=64,[8118]=64,[8119]=64,[8141]=8,[8142]=8,[8143]=8,[8144]=8,[8145]=4,
    [8146]=4,[8147]=4,[8148]=4,[8151]=4,[8153]=4,[8184]=1,[8185]=2,[8186]=8,[8187]=4,[8188]=64,[8189]=128,[8190]=256,[8191]=16,[8192]=1024,
    [8231]=4,[8232]=4,[8233]=8,[8234]=8,[8235]=8,[8236]=8,[8249]=8,[8250]=128,[8251]=128,[8252]=128,[8253]=128,[8254]=16,[8255]=16,[8256]=16,
    [8257]=16,[8258]=64,[8259]=64,[8316]=1,[8328]=128,[8344]=256,[8376]=2,[8377]=4,[8378]=8,[8379]=16,[8380]=64,[8381]=128,[8382]=1024,[8410]=64,
    [8411]=64,[8412]=64,[8413]=64,[8414]=2,[8415]=2,[8416]=2,[8417]=1,[8418]=2,[8419]=256,[8420]=256,[8421]=256,[8422]=256,[8423]=1,[8424]=1,
    [8425]=1,[8544]=1,[8556]=1,[8557]=1,[8558]=1,[8559]=1,[8560]=1,[8561]=1,[8562]=1,[8563]=256,[8564]=16,[8592]=16,[8593]=16,[8594]=16,
    [8596]=16,[8602]=64,[8603]=16,[8621]=64,[8622]=64,[8623]=64,[8624]=64,[8625]=128,[8626]=4,[8627]=2,[8628]=2,[8629]=2,[8630]=2,[8631]=128,
    [8632]=128,[8633]=128,[8634]=128,[8637]=8,[8638]=8,[8639]=8,[8640]=8,[8641]=8,[8655]=2,[8656]=4,[8657]=4,[8658]=4,[8659]=4,[8660]=256,
    [8661]=256,[8662]=256,[8663]=256,[8664]=256,[8665]=1024,[8666]=1024,[8667]=1024,[8668]=1024,[8669]=1024,[8689]=16,[8690]=64,[8691]=128,[8692]=1024,[8693]=8,
    [8694]=256,[8695]=2,[8696]=4,[8697]=16,[8698]=64,[8699]=128,[8700]=1024,[8701]=8,[8702]=256,[8703]=2,[8704]=4,[8705]=16,[8706]=64,[8707]=128,
    [8708]=1024,[8709]=8,[8710]=256,[8711]=2,[8712]=4,[8767]=9,[8788]=1494,[8905]=1024,[8906]=4,[8907]=128,[8908]=2,[8909]=16,[8910]=8,[8911]=256,
    [8912]=1,[8913]=1024,[8914]=4,[8915]=128,[8916]=16,[8917]=8,[8918]=64,[8919]=256,[8920]=1,[8926]=1024,[8927]=1024,[8931]=4,[8932]=128,[8933]=2,
    [8934]=16,[8935]=8,[8936]=256,[8937]=1,[8938]=4,[8939]=128,[8940]=16,[8941]=8,[8942]=64,[8943]=256,[8944]=1,[8951]=1024,[8952]=4,[8953]=128,
    [8954]=2,[8955]=16,[8956]=8,[8957]=64,[8958]=256,[8959]=1,[8962]=129,[8963]=1280,[8964]=12,[8965]=82,[8966]=129,[8967]=1280,[8968]=12,[8969]=82,
    [8985]=9,[8986]=1090,[8987]=144,[8988]=260,[8989]=1090,[8990]=9,[8991]=144,[8992]=260,[8999]=1024,[9000]=4,[9001]=128,[9002]=2,[9003]=16,[9004]=8,
    [9005]=256,[9006]=1,[9007]=1024,[9008]=4,[9009]=16,[9010]=8,[9011]=64,[9012]=256,[9013]=1,[9014]=128,[9016]=1024,[9017]=4,[9018]=128,[9019]=16,
    [9020]=8,[9021]=256,[9022]=1,[9034]=1,[9036]=1,[9037]=1,[9038]=1,[9039]=1,[9040]=1,[9041]=1,[9042]=1,[9043]=2,[9044]=2,[9045]=2,
    [9046]=2,[9047]=2,[9048]=2,[9049]=2,[9050]=2,[9051]=1024,[9052]=1024,[9053]=1024,[9054]=4,[9055]=4,[9056]=4,[9057]=4,[9058]=4,[9059]=4,
    [9060]=4,[9061]=4,[9063]=1024,[9068]=64,[9069]=64,[9070]=64,[9071]=64,[9072]=64,[9073]=64,[9074]=64,[9075]=64,[9077]=8,[9079]=8,[9080]=8,
    [9081]=8,[9082]=8,[9083]=8,[9084]=8,[9086]=1024,[9087]=1024,[9088]=1024,[9089]=1024,[9090]=1024,[9091]=1024,[9092]=1024,[9093]=1024,[9095]=128,[9096]=128,
    [9097]=128,[9098]=128,[9099]=128,[9100]=128,[9101]=128,[9102]=128,[9103]=256,[9104]=256,[9105]=256,[9106]=256,[9107]=256,[9108]=256,[9109]=256,[9110]=256,
    [9111]=16,[9112]=16,[9113]=16,[9114]=16,[9115]=16,[9116]=16,[9117]=16,[9118]=16,[9257]=16,[9269]=1024,[9270]=128,[9271]=256,[9287]=2,[9288]=4,
    [9289]=1,[9290]=128,[9291]=16,[9362]=128,[9364]=128,[9392]=8,[9393]=4,[9402]=128,[9403]=128,[9404]=128,[9421]=64,[9449]=64,[9450]=64,[9451]=64,
    [9460]=8,[9461]=64,[9462]=64,[9464]=64,[9465]=64,[9467]=64,[9468]=64,[9484]=4,[9485]=4,[9486]=4,[9487]=128,[9488]=128,[9489]=16,[9491]=8,
    [9500]=64,[9501]=64,[9502]=64,[9503]=64,[9504]=64,[9508]=64,[9509]=64,[9529]=256,[9532]=8,[9547]=64,[9551]=64,[9552]=64,[9553]=64,[9554]=64,
    [9555]=64,[9582]=1,[9586]=16,[9591]=4,[9592]=4,[9593]=4,[9595]=128,[9598]=2,[9599]=2,[9600]=2,[9601]=2,[9617]=4,[9618]=8,[9619]=256,
    [9673]=4,[9675]=4,[9676]=2,[9677]=2,[9678]=2,[9681]=2,[9684]=2,[9685]=2,[9686]=2,[9690]=2,[9691]=2,[9692]=2,[9707]=2,[9710]=2,
    [9712]=2,[9721]=2,[9722]=2,[9723]=2,[9725]=2,[9735]=2,[9736]=2,[9737]=2,[9757]=4,[10350]=1,[10364]=16,[10366]=2,[10371]=1,[10372]=8,
    [10376]=16,[10377]=16,[10378]=16,[10379]=16,[10490]=64,[10491]=64,[10492]=64,[10493]=2,[10494]=64,[10495]=2,[10496]=64,[10497]=2,[10498]=64,[10499]=2,
    [10529]=4,[10530]=4,[10534]=16,[10539]=16,[10548]=8,[10590]=2,[10592]=2,[10593]=2,[10605]=256,[10638]=16,[10779]=4,[10788]=256,[10789]=256,[10790]=256,
    [10794]=8,[10931]=16,[10932]=16,[10933]=16,[10934]=16,[10955]=1024,[10961]=1024,[10964]=1024,[10965]=1024,[10978]=1024,[10979]=1024,[10980]=1024,[10986]=1024,[10987]=1024,
    [10988]=1024,[10990]=1024,[10991]=1024,[10992]=1024,[10993]=1024,[10994]=1024,[11001]=1024,[11011]=1024,[11102]=1024,[12172]=128,[12173]=128,[12228]=128,[12593]=32,[12619]=32,
    [12625]=32,[12636]=32,[12641]=32,[12657]=32,[12670]=32,[12678]=32,[12679]=32,[12680]=32,[12687]=32,[12697]=32,[12698]=32,[12700]=32,[12701]=32,[12706]=32,
    [12711]=32,[12714]=32,[12715]=32,[12716]=32,[12717]=32,[12718]=32,[12719]=32,[12720]=32,[12722]=32,[12723]=32,[12724]=32,[12725]=32,[12727]=32,[12733]=32,
    [12738]=32,[12739]=32,[12742]=32,[12743]=32,[12744]=32,[12745]=32,[12746]=32,[12747]=32,[12748]=32,[12749]=32,[12750]=32,[12751]=32,[12754]=32,[12755]=32,
    [12756]=32,[12757]=32,[12778]=32,[12779]=32,[12800]=32,[12801]=32,[12842]=32,[12848]=32,[12849]=32,[12850]=32,[13104]=1503,[13105]=32,[13165]=32,[13166]=32,
    [13188]=32,[13189]=32,[13408]=1503,[13409]=1503,[13410]=32,[13411]=32,[13682]=1503,[13788]=32,[13789]=1503,[13790]=1503,[13791]=32,[13793]=32,[13795]=32,[13809]=1503,
    [13810]=1503,[13811]=1503,[13812]=32,[13813]=32,[13814]=32,[13861]=1503,[13862]=1503,[13863]=32,[13864]=32,[14100]=64,[14111]=64,[14418]=8,[14419]=8,[14420]=8,
    [14421]=8,
};

function Q.ClassLabel(id)
    local mask=Q.classMasks[id];if not mask then return nil;end
    local names={};
    for _,class in ipairs({{1,"Воин"},{2,"Паладин"},{4,"Охотник"},{8,"Разбойник"},{16,"Жрец"},
        {32,"Рыцарь смерти"},{64,"Шаман"},{128,"Маг"},{256,"Чернокнижник"},{1024,"Друид"}}) do
        if mask%(class[1]*2)>=class[1] then table.insert(names,class[2]);end
    end
    return #names>0 and table.concat(names,", ") or nil;
end


function Q.Key(name)
    name=tostring(name or ""):match("^[^-]+") or "";
    return UnBotAccountAlts.Key(name);
end

function Q.Context()
    return tostring(GetRealmName()).."|"..tostring(UnitName("player")).."|"
        ..tostring(UnBotAccountAlts.EnsureStorage().accountIdentity and UnBotAccountAlts.EnsureStorage().accountIdentity.fingerprint or "");
end

function Q.SyncContext()
    local context=Q.Context();
    if Q.context~=context then
        Q.context=context;Q.playerQuestNames=nil;Q.cooldown=nil;Q.autoRead=nil;Q.playerCache=nil;Q.cache={};Q.job=nil;Q.confirm=nil;Q.selected=nil;Q.questId=nil;
    end
end

function Q.Alts()
    local rows,seen={},{};
    local function Add(name,kind)
        local key=Q.Key(name);
        if key=="" or seen[key] or key==Q.Key(UnitName("player")) then return; end
        if not UnBotAltStrategies.Entry(name) then return; end
        seen[key]=true;
        local unit=UnBotAccountAlts.FindUnit(name);
        table.insert(rows,{name=name,kind=kind,online=unit and UnitIsConnected(unit) and true or false});
    end
    for _,name in ipairs(UnBotAccountAlts.GetNames(true,false)) do Add(name,"Свой аккаунт"); end
    local linked=UnBotLinkedAccounts and UnBotLinkedAccounts.Storage();
    for _,key in ipairs(linked and linked.current or {}) do
        local account=linked.accounts and linked.accounts[key];
        for _,entry in pairs(account and account.characters or {}) do
            if type(entry)=="table" and type(entry.name)=="string" then Add(entry.name,"Связанный аккаунт"); end
        end
    end
    table.sort(rows,function(a,b) if a.online~=b.online then return a.online; end return Q.Key(a.name)<Q.Key(b.name); end);
    return rows;
end

function Q.Online(name)
    if not name or not UnBotAltStrategies.Entry(name) then return false; end
    local unit=UnBotAccountAlts.FindUnit(name);
    return unit and UnitIsConnected(unit) and true or false;
end

function Q.PlayerSignature()
    local count,total=GetNumQuestLogEntries();
    local parts={tostring(count),tostring(total)};
    for i=1,count do
        local title,_,_,_,header,closed,_,_,id=GetQuestLogTitle(i);
        table.insert(parts,tostring(id or title)..":"..tostring(header)..":"..tostring(closed));
    end
    return table.concat(parts,"|");
end

function Q.PlayerQuests()
    if Q.playerCache then return Q.playerCache;end
    local ids,collapsed={},{};Q.playerQuestNames={};
    local selection=GetQuestLogSelection();
    local selectedId=selection and select(9,GetQuestLogTitle(selection));
    Q.scanningPlayer=true;
    -- The original 3.3.5 API puts questID ninth; collapsed headers hide child rows.
    local i=1;
    while i<=GetNumQuestLogEntries() and i<=100 do
        local title,_,_,_,header,closed,_,_,id=GetQuestLogTitle(i);
        if header and closed then table.insert(collapsed,i);ExpandQuestHeader(i);end
        if not header and tonumber(id) and id>0 then ids[id]=true;Q.playerQuestNames[id]=title;end
        i=i+1;
    end
    for j=#collapsed,1,-1 do CollapseQuestHeader(collapsed[j]);end
    if selectedId and selectedId>0 then
        for j=1,GetNumQuestLogEntries() do if select(9,GetQuestLogTitle(j))==selectedId then SelectQuestLogEntry(j);break end end
    elseif selection and selection>0 then SelectQuestLogEntry(selection);end
    Q.scanningPlayer=false;Q.playerSignature=Q.PlayerSignature();Q.playerCache=ids;
    return ids;
end

function Q.Status(text,announce)
    Q.status=text;
    if announce then UnBotChatWrite("UnBot: "..text); end
    Q.Refresh();
end

function Q.ClearConfirmation()
    Q.confirm=nil;
    if Q.window then Q.window.confirmPanel:Hide(); end
    if Q.Native and Q.Native.confirmPanel then Q.Native.confirmPanel:Hide();end
end

function Q.Select(name,silent)
    if Q.job or (Q.Native and Q.Native.op) then return; end
    Q.ClearConfirmation();Q.selected=name;Q.questId=nil;Q.questOffset=0;Q.Refresh();
    if not silent then Q.AutoRead();end
end

-- One request per explicit open/selection; no retries or periodic server polling.
function Q.AutoRead()
    Q.autoRead=nil;
    if Q.job or (Q.Native and Q.Native.op) or not Q.Online(Q.selected) then return;end
    local snapshot=Q.Snapshot();
    if snapshot and not snapshot.stale and GetTime()-snapshot.at<=120 then return;end
    Q.autoRead={name=Q.selected,context=Q.Context(),at=math.max(GetTime(),Q.cooldown or 0)};
    Q.TryAutoRead();
end

function Q.TryAutoRead()
    local pending=Q.autoRead;
    if not pending then return;end
    if pending.name~=Q.selected or pending.context~=Q.Context() or not Q.window or not Q.window:IsShown()
        or not Q.Online(pending.name) or GetTime()>pending.at+5 then Q.autoRead=nil;return;end
    if Q.job or GetTime()<pending.at then return;end
    Q.autoRead=nil;Q.cooldown=GetTime()+2;Q.StartRead(pending.name);
end

-- Track the exact command until a chat throttle really dispatches it.
function Q.PruneSends()
    local pending={};
    for _,ticket in ipairs(Q.pendingSends or {}) do
        if GetTime()<=ticket.untilAt then table.insert(pending,ticket);end
    end
    Q.pendingSends=pending;
end

function Q.OwnSend(message,channel,target)
    Q.PruneSends();
    for i,ticket in ipairs(Q.pendingSends) do
        if channel=="WHISPER" and message==ticket.command and Q.Key(target)==ticket.key then
            table.remove(Q.pendingSends,i);
            if ticket.job and ticket.context==Q.Context() and (Q.job==ticket.job or (Q.Native and Q.Native.op and ticket.job.npcOp==Q.Native.op)) then
                local job=ticket.job;
                job.sentAt=GetTime();
                if job.parent then job.parent.pendingAccepts=math.max(0,job.parent.pendingAccepts-1);job.parent.lastAcceptAt=GetTime();end
                job.deadline=GetTime()+(job.kind=="drop" and 3 or (job.kind=="read" and 10 or 8));
            end
            return true;
        end
    end
    return false;
end

-- MultiBot's passive quest popup must not claim replies to our own read.
-- Only this sender's quest-list packets are scoped; other events still reach MultiBot.
function Q.MultiBotOwnReply(message,sender)
    local job=Q.job or (Q.Native and Q.Native.NpcJob(sender));local tail=Q.readTail;
    local own=job and job.kind=="read" and job.context==Q.Context() and Q.Key(sender)==Q.Key(job.name);
    own=own or (tail and tail.context==Q.Context() and GetTime()<=tail.untilAt and Q.Key(sender)==tail.key);
    if not own then return false;end
    local text=tostring(message or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","");
    return text=="--- Incompleted quests ---" or text=="--- Completed quests ---"
        or text=="--- Summary ---" or text:match("^Total:%s*%d+%s*/%s*25")~=nil
        or text:find("|Hquest:",1,true)~=nil;
end

function Q.InstallMultiBotCompatibility()
    if not MultiBot or type(MultiBot.HandleMultiBotEvent)~="function" or MultiBot.HandleMultiBotEvent==Q.multiBotWrapper then return;end
    local previous=MultiBot.HandleMultiBotEvent;
    Q.multiBotWrapper=function(event,message,sender,...)
        if event=="CHAT_MSG_WHISPER" and Q.MultiBotOwnReply(message,sender) then return;end
        return previous(event,message,sender,...);
    end;
    MultiBot.HandleMultiBotEvent=Q.multiBotWrapper;
end

function Q.Send(command,name,ownerJob)
    Q.InstallMultiBotCompatibility();Q.PruneSends();
    if #Q.pendingSends>=2048 then Q.sendError="Очередь квестовых команд переполнена.";return false;end
    local ticket={command=command,key=Q.Key(name),job=ownerJob or Q.job,context=Q.Context(),untilAt=GetTime()+(ownerJob and 600 or 30)};
    table.insert(Q.pendingSends,ticket);
    Q.sending=true;
    local ok,reason=pcall(SendChatMessage,command,"WHISPER",nil,name);
    Q.sending=false;
    if not ok then
        for i=#Q.pendingSends,1,-1 do if Q.pendingSends[i]==ticket then table.remove(Q.pendingSends,i);end end
    end
    Q.sendError=not ok and tostring(reason):gsub("[%c]"," "):gsub("|","||"):sub(1,300) or nil;
    return ok;
end

function Q.StartRead(name,verification)
    Q.autoRead=nil;
    if not Q.Online(name) then
        Q.job=nil;Q.Status("Альт должен быть онлайн в вашей группе. Подключите его на вкладке «Альты».",true);return false;
    end
    Q.ClearConfirmation();
    Q.job={kind="read",name=name,context=Q.Context(),deadline=GetTime()+10,entries={},seen={},verification=verification};
    if not Q.Send("quests all",name) then
        Q.job=nil;Q.Status("Не удалось отправить запрос журнала. Повторите вручную.",true);return false;
    end
    Q.Status("Читаю журнал "..name.."…");return true;
end

function Q.Read()
    Q.SyncContext();
    if Q.job or (Q.Native and Q.Native.op) or GetTime()<(Q.cooldown or 0) then return; end
    Q.cooldown=GetTime()+2;
    Q.StartRead(Q.selected);
end

function Q.Snapshot()
    local snapshot=Q.selected and Q.cache[Q.Key(Q.selected)];
    if snapshot and snapshot.context==Q.Context() then return snapshot; end
end

function Q.Quest()
    local snapshot=Q.Snapshot();
    for _,entry in ipairs(snapshot and snapshot.entries or {}) do if entry.id==Q.questId then return entry; end end
end

function Q.CanAct()
    local snapshot=Q.Snapshot();
    return not Q.job and Q.Online(Q.selected) and snapshot and not snapshot.stale
        and GetTime()-snapshot.at<=120 and Q.Quest()~=nil and GetTime()>=(Q.cooldown or 0);
end

function Q.Action(kind)
    if kind~="share" and kind~="drop" then return; end
    if not Q.CanAct() then Q.Status("Обновите журнал онлайн-альта и выберите задание.");return; end
    local entry=Q.Quest();
    if kind=="share" and Q.PlayerQuests()[entry.id] then Q.Status("Это задание уже есть в вашем журнале.");return; end
    if kind=="drop" then
        Q.confirm={name=Q.selected,id=entry.id,context=Q.Context()};
        local title=Q.Native and Q.Native.frame and Q.Native.LocalTitle({name=Q.selected,entry=entry}) or entry.title;
        local text="Отменить у "..Q.selected.." задание «"..title.."»? Прогресс задания у альта будет потерян.";
        if Q.Native and Q.Native.ShowDeleteConfirmation(text) then return;end
        if Q.window then Q.window.confirmText:SetText(text);Q.window.confirmPanel:Show();
        else Q.ClearConfirmation();Q.Status("Выберите задание альта в журнале.");end
        return;
    end
    Q.BeginAction(kind,entry);
end

function Q.ConfirmDrop()
    local confirm=Q.confirm;
    if (Q.Native and Q.Native.op) or not confirm or confirm.context~=Q.Context() or confirm.name~=Q.selected or confirm.id~=Q.questId or not Q.CanAct() then
        Q.ClearConfirmation();Q.Status("Выбор изменился. Обновите журнал перед отменой.");return;
    end
    local entry=Q.Quest();Q.ClearConfirmation();Q.BeginAction("drop",entry);
end


function Q.QuestLabel(entry)
    if entry and type(entry.link)=="string" and entry.link~="" then return entry.link;end
    return "«"..tostring(entry and entry.title or "Задание").."» (ID "..tostring(entry and entry.id or "?")..")";
end

function Q.BeginAction(kind,entry)
    Q.cooldown=GetTime()+3;
    Q.job={kind=kind,name=Q.selected,id=entry.id,title=entry.title,label=Q.QuestLabel(entry),context=Q.Context(),deadline=GetTime()+(kind=="drop" and 3 or 8)};
    local label=Q.job.label;
    local pending=Q.Native and Q.Native.op and Q.Native.op.pending;
    local prefix=pending and ("Обмен 2/2 ["..pending.step.."/"..pending.total.."]: ") or "";
    Q.Status(prefix..(kind=="share" and (Q.selected.." -> игрок: запрашиваю ") or ("Отмена у "..Q.selected..": "))..label,true);
    if not Q.Send(kind.." "..entry.link,Q.selected) then
        Q.job=nil;Q.Status("Ошибка при отправке команды: "..tostring(Q.sendError or "неизвестная ошибка клиента"),true);return;
    end
    if kind=="drop" then Q.Snapshot().stale=true; end
    Q.Status(kind=="share" and (prefix.."Ожидаю предложение от "..Q.selected..": "..label)
        or ("Проверю отмену у "..Q.selected..": "..label));
end

function Q.FinishRead(job,total,incomplete,complete)
    Q.readTail={key=Q.Key(job.name),context=job.context,untilAt=GetTime()+0.5};
    local n,c=0,0;
    for _,entry in ipairs(job.entries) do if entry.complete then c=c+1;else n=n+1;end end
    if total~=n+c or incomplete~=n or complete~=c then
        Q.job=nil;
        if Q.cache[Q.Key(job.name)] then Q.cache[Q.Key(job.name)].stale=true;end
        Q.Status("Журнал "..job.name.." получен не полностью. Нажмите «Обновить журнал» ещё раз.",true);return;
    end
    local snapshot={name=job.name,entries=job.entries,at=GetTime(),context=job.context,total=total,incomplete=incomplete,complete=complete};
    job.result=snapshot;Q.cache[Q.Key(job.name)]=snapshot;Q.playerCache=nil;Q.job=nil;
    if job.verification then
        local found=job.seen[job.verification.id];
        if not found and Q.Native then Q.Native.DeleteVerified(job.name,job.verification.id);end
        Q.Status(found and ("Проверка: задание осталось в журнале "..job.name..". Повторная отмена не отправлялась.")
            or ("Проверка: задание отсутствует в журнале "..job.name.."."),true);
    else Q.Status("Журнал "..job.name..": "..total.." / 25; выполнено: "..complete..".",true); end
end

function Q.Reply(message,sender)
    local job=Q.job or (Q.Native and Q.Native.NpcJob(sender));
    if not job or job.done or Q.Key(sender)~=Q.Key(job.name) then return; end
    if job.context~=Q.Context() or not Q.Online(job.name) then Q.job=nil;Q.Status("Подключение альта изменилось. Запрос остановлен.");return; end
    local text=tostring(message or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","");
    local lower=text:lower();
    if job.kind=="npc_talk" or job.kind=="npc_accept" then Q.Native.NpcReply(job,message);return;end
    if Q.Native then Q.Native.Reply(job,lower);end
    if lower:find("unknown command",1,true) or lower:find("cannot",1,true) or lower:find("not allowed",1,true)
        or lower:find("can't",1,true) or lower:find("invalid quest",1,true) then
        job.readFailed=true;Q.job=nil;Q.Status("Ответ "..job.name..(job.label and (" по "..job.label) or "")..": "..text,true);return;
    end
    if job.kind=="share" then
        if lower:find("quest was not shared",1,true) then Q.job=nil;Q.Status("Альт "..job.name.." не смог поделиться заданием "..(job.label or Q.QuestLabel(job))..". Сервер отказал в передаче.",true);return;end
        if lower:find("quest shared",1,true) then Q.job=nil;Q.Status(job.name.." предложил группе "..(job.label or Q.QuestLabel(job))..". Примите задание в появившемся окне.",true);end
        return;
    elseif job.kind=="drop" then
        if lower:find("quest removed",1,true) then job.deadline=GetTime()+0.6;end
        return;
    elseif job.kind~="read" then return; end
    if text=="--- Incompleted quests ---" then
        if job.section then job.invalid=true;end
        job.section="incomplete";return;
    elseif text=="--- Completed quests ---" then job.section="complete";return;
    elseif text=="--- Summary ---" then job.summary=true;return;end
    local total,incomplete,complete=text:match("^Total:%s*(%d+)%s*/%s*25%s*%(incompleted:%s*(%d+),%s*completed:%s*(%d+)%)%s*$");
    if total and job.summary then
        if job.invalid then Q.job=nil;Q.Status("Ответы журналов пересеклись. Повторите запрос вручную.",true);return;end
        Q.FinishRead(job,tonumber(total),tonumber(incomplete),tonumber(complete));return;
    end
    if job.section and not job.summary then
        local payload,title=text:match("|H(quest:[^|]+)|h%[([^%]]+)%]|h");
        local id=payload and tonumber(payload:match("^quest:(%d+)"));
        if id and not job.seen[id] then
            job.seen[id]=true;
            -- SendChatMessage needs a complete chat hyperlink, including color and reset.
            local link=tostring(message):match("(|c%x%x%x%x%x%x%x%x|Hquest:[^|]+|h%[[^%]]+%]|h|r)");
            link=link or ("|cffffff00|H"..payload.."|h["..title.."]|h|r");
            table.insert(job.entries,{id=id,title=title,link=link,level=tonumber(payload:match("^quest:%d+:([%-]?%d+)")),complete=job.section=="complete"});
        end
    end
end


function Q.SystemReply(message)
    local job=Q.job;
    if not job or (job.kind~="share" and job.kind~="drop") then return;end
    local text=tostring(message or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","");
    local author,body=text:match("^([^:]+):%s*(.-)%s*$");
    if not author or Q.Key(author)~=Q.Key(job.name) then return;end
    local key=body:lower():gsub("[%s%.]+$","");
    if key=="quest was not shared" or key=="quest shared" or key=="quest removed" then Q.Reply(body,job.name);end
end

function Q.Tick()
    Q.SyncContext();
    if Q.Native then Q.Native.AutoRefresh();Q.Native.Tick();end
    Q.TryAutoRead();
    if Q.cooldown and Q.cooldown>0 and GetTime()>=Q.cooldown then Q.cooldown=0;Q.Refresh();end
    local snapshot=Q.Snapshot();
    if snapshot and not snapshot.stale and GetTime()-snapshot.at>120 then snapshot.stale=true;Q.Refresh();end
    local job=Q.job;
    if not job then return; end
    if job.context~=Q.Context() or not Q.Online(job.name) then
        Q.job=nil;Q.ClearConfirmation();Q.Status("Альт недоступен. Действие остановлено; повторной отправки нет.",true);return;
    end
    if job.kind=="npc_talk" or job.kind=="npc_accept" then return;end
    if GetTime()<job.deadline then return; end
    Q.job=nil;
    if job.kind=="drop" then Q.StartRead(job.name,{id=job.id});return;end
    if job.kind=="read" and Q.cache[Q.Key(job.name)] then Q.cache[Q.Key(job.name)].stale=true;end
    Q.Status(job.kind=="share" and ("Нет подтверждения обмена: "..job.name..", "..(job.label or Q.QuestLabel(job))..". Проверьте окно принятия; команда не повторялась.")
        or "Полный журнал не получен за 10 секунд. Повторите запрос вручную.",true);
end

function Q.VisibleQuests()
    local rows,player={},Q.PlayerQuests();
    local snapshot=Q.Snapshot();
    for _,entry in ipairs(snapshot and snapshot.entries or {}) do
        if not Q.missingOnly or not player[entry.id] then table.insert(rows,entry);end
    end
    return rows,player;
end

function Q.Refresh()
    if Q.Native then Q.Native.Refresh();end
    local f=Q.window;if not f then return;end
    local alts=Q.Alts();
    Q.altOffset=math.max(0,math.min(Q.altOffset,math.max(0,#alts-12)));
    for i,b in ipairs(f.alts) do
        local row=alts[Q.altOffset+i];b.row=row;
        if row then
            b:SetText((row.name==Q.selected and "|cffffd100" or "|cffffffff")..row.name.."|r\n"..row.kind..(row.online and ": онлайн" or ": не в группе / офлайн"));b:Show();
            if Q.job then b:Disable();else b:Enable();end
        else b:Hide();end
    end
    local rows,player=Q.VisibleQuests();
    Q.questOffset=math.max(0,math.min(Q.questOffset,math.max(0,#rows-12)));
    for i,b in ipairs(f.quests) do
        local entry=rows[Q.questOffset+i];b.entry=entry;
        if entry then
            local classLabel=Q.ClassLabel(entry.id);
            b:SetText((entry.id==Q.questId and "|cffffd100" or "|cffffffff")..(classLabel and "[Классовое] " or "")..entry.title.."|r");
            b.state:SetText((entry.complete and "Выполнено" or "В процессе")..(player[entry.id] and "; есть у меня" or "; нет у меня")..(classLabel and ("; "..classLabel) or ""));b:Show();
        else b:Hide();end
    end
    local snapshot=Q.Snapshot();
    f.summary:SetText((Q.selected or "Выберите альта слева")..(snapshot and (" — "..snapshot.total.." / 25; в списке: "..#rows.."\nСнимок: "..math.floor(math.max(0,GetTime()-snapshot.at)).." сек. назад"..(snapshot.stale and "; требуется обновление" or "")) or "\nНажмите «Обновить журнал»."));
    f.status:SetText(Q.status or "Выберите онлайн-альта и обновите его журнал.");
    f.filter:SetChecked(Q.missingOnly);
    if Q.Online(Q.selected) and not Q.job then f.read:Enable();else f.read:Disable();end
    local ready=Q.CanAct();local entry=Q.Quest();
    if ready and not player[entry.id] then f.share:Enable();else f.share:Disable();end
    if ready then f.drop:Enable();else f.drop:Disable();end
end

function Q.Build()
    if Q.window then return;end
    local f=UnBotServiceUI.Window("UnBotAltQuestsWindow","Задания альтов",750);Q.window=f;
    local help=UnBotServiceUI.Text(f,15,950,"Сравните задания альта со своим журналом. Альт может предложить группе доступное для передачи задание.\nСвои задания предлагайте через обычный журнал. Взятие у NPC работает со стратегией quest.");help:SetPoint("TOPLEFT",32,-66);
    local left=UnBotServiceUI.Panel(f,270,495);left:SetPoint("TOPLEFT",28,-134);
    local right=UnBotServiceUI.Panel(f,680,495);right:SetPoint("TOPLEFT",310,-134);
    f.alts={};f.quests={};
    left:EnableMouseWheel(true);left:SetScript("OnMouseWheel",function(_,d)Q.altOffset=Q.altOffset-d*3;Q.Refresh();end);
    right:EnableMouseWheel(true);right:SetScript("OnMouseWheel",function(_,d)Q.questOffset=Q.questOffset-d*3;Q.Refresh();end);
    for i=1,12 do
        local b=UnBotServiceUI.Button(left,250,"",function(self)if self.row then Q.Select(self.row.name);end end);b:SetHeight(38);b:SetPoint("TOPLEFT",10,-10-(i-1)*39);b:GetFontString():SetFont(STANDARD_TEXT_FONT,12);f.alts[i]=b;
        b=UnBotServiceUI.Button(right,652,"",function(self)
            if not self.entry then return;end
            if IsShiftKeyDown() and ChatEdit_InsertLink then ChatEdit_InsertLink(self.entry.link);return;end
            Q.ClearConfirmation();Q.questId=self.entry.id;Q.Refresh();
        end);b:SetHeight(38);b:SetPoint("TOPLEFT",14,-10-(i-1)*39);
        b:GetFontString():SetFont(STANDARD_TEXT_FONT,15);b:GetFontString():ClearAllPoints();b:GetFontString():SetPoint("TOPLEFT",12,-3);b:GetFontString():SetWidth(628);b:GetFontString():SetJustifyH("LEFT");
        b.state=UnBotServiceUI.Text(b,11,628);b.state:SetPoint("TOPLEFT",12,-22);
        b:SetScript("OnEnter",function(self)if self.entry then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetHyperlink(self.entry.link:match("|H([^|]+)|h"));local classLabel=Q.ClassLabel(self.entry.id);if classLabel then GameTooltip:AddLine("Классовое задание: "..classLabel,1,0.82,0,true);end;GameTooltip:Show();end end);
        b:SetScript("OnLeave",function()GameTooltip:Hide();end);f.quests[i]=b;
    end
    f.filter=CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate");f.filter:SetWidth(24);f.filter:SetHeight(24);f.filter:SetPoint("TOPLEFT",320,-105);f.filter:SetScript("OnClick",function(self)Q.missingOnly=self:GetChecked() and true or false;Q.questOffset=0;Q.questId=nil;Q.ClearConfirmation();Q.Refresh();end);
    local label=UnBotServiceUI.Text(f,14,500,"Есть у альта, нет в моём журнале");label:SetPoint("LEFT",f.filter,"RIGHT",4,0);
    f.summary=UnBotServiceUI.Text(f,13,270);f.summary:SetPoint("TOPLEFT",32,-638);
    f.read=UnBotServiceUI.Button(f,200,"Обновить журнал",Q.Read);f.read:SetPoint("TOPLEFT",318,-638);
    f.share=UnBotServiceUI.Button(f,232,"Попросить поделиться",function()Q.Action("share");end);f.share:SetPoint("TOPLEFT",524,-638);
    f.drop=UnBotServiceUI.Button(f,225,"Отменить у альта…",function()Q.Action("drop");end);f.drop:SetPoint("TOPLEFT",762,-638);
    f.status=UnBotServiceUI.Text(f,14,950);f.status:SetPoint("TOPLEFT",32,-690);f.status:SetHeight(48);
    f.confirmPanel=UnBotServiceUI.Panel(f,800,150);f.confirmPanel:SetPoint("CENTER",f,"CENTER",0,0);f.confirmPanel:SetFrameStrata("FULLSCREEN_DIALOG");
    f.confirmText=UnBotServiceUI.Text(f.confirmPanel,17,750);f.confirmText:SetPoint("TOPLEFT",24,-20);f.confirmText:SetHeight(65);
    f.confirmYes=UnBotServiceUI.Button(f.confirmPanel,220,"Отменить задание",Q.ConfirmDrop);f.confirmYes:SetPoint("BOTTOMLEFT",24,18);
    f.confirmNo=UnBotServiceUI.Button(f.confirmPanel,160,"Назад",Q.ClearConfirmation);f.confirmNo:SetPoint("BOTTOMRIGHT",-24,18);f.confirmPanel:Hide();
    f:SetScript("OnShow",function()Q.SyncContext();Q.Refresh();end);
    f:SetScript("OnHide",function()Q.autoRead=nil;Q.ClearConfirmation();end);
end

function Q.Show(name)
    Q.SyncContext();Q.playerCache=nil;Q.Build();
    if not Q.job then
        local preferred=name or (UnBotSpecAudit and UnBotSpecAudit.selectedAlt) or UnitName("target");
        if preferred and UnBotAltStrategies.Entry(preferred) then Q.Select(UnBotAccountAlts.ResolveName(preferred,true),true);end
        if not Q.selected then for _,row in ipairs(Q.Alts()) do if row.online then Q.selected=row.name;break end end end
    end
    Q.window:Show();Q.window:Raise();Q.Refresh();Q.AutoRead();
end

Q.events=CreateFrame("Frame");
for _,event in ipairs({"CHAT_MSG_WHISPER","CHAT_MSG_SYSTEM","QUEST_LOG_UPDATE","PARTY_MEMBERS_CHANGED","RAID_ROSTER_UPDATE","UNIT_CONNECTION","PLAYER_ENTERING_WORLD"}) do Q.events:RegisterEvent(event);end
Q.events:SetScript("OnEvent",function(_,event,message,sender)
    if event=="CHAT_MSG_WHISPER" then Q.Reply(message,sender);return;end
    if event=="CHAT_MSG_SYSTEM" then Q.SystemReply(message);return;end
    if event=="QUEST_LOG_UPDATE" then
        if Q.scanningPlayer then return;end
        if Q.playerSignature~=Q.PlayerSignature() then Q.playerCache=nil;end
    end
    Q.SyncContext();Q.ClearConfirmation();
    for key,snapshot in pairs(Q.cache) do if not Q.Online(snapshot.name) then snapshot.stale=true;end end
    if event=="PLAYER_ENTERING_WORLD" then Q.cache={};Q.job=nil;end
    if Q.Native then Q.Native.Event(event);end
    if Q.window and Q.window:IsShown() then Q.Refresh();end
end);
Q.events:SetScript("OnUpdate",function(self,elapsed)
    self.elapsed=(self.elapsed or 0)+elapsed;if self.elapsed<0.2 then return;end;self.elapsed=0;Q.Tick();
end);
if hooksecurefunc then hooksecurefunc("SendChatMessage",function(message,channel,language,target)
    if Q.OwnSend(message,channel,target) or Q.sending then return;end
    local text=tostring(message or ""):lower();
    local op=Q.Native and Q.Native.op;
    if op and op.mode=="npc" and (channel=="PARTY" or channel=="RAID" or (channel=="WHISPER" and op.npcJobs[Q.Key(target)]))
        and (text:match("^quests") or text:match("^drop%s") or text:match("^share%s") or text:match("^accept%s") or text=="talk") then
        Q.Native.Stop("Отправлена другая квестовая команда. Принятие у NPC остановлено; повторов нет.");return;
    end
    local job=Q.job;if not job then return;end
    local same=channel=="WHISPER" and Q.Key(target)==Q.Key(job.name);
    if (same or channel=="PARTY" or channel=="RAID") and (text:match("^quests") or text:match("^drop%s") or text:match("^share%s") or (Q.Native and Q.Native.op and Q.Native.op.mode=="npc" and (text:match("^accept%s") or text=="talk"))) then
        if Q.cache[Q.Key(job.name)] then Q.cache[Q.Key(job.name)].stale=true;end
        Q.job=nil;Q.Status("Отправлена другая квестовая команда. Обновите журнал после её завершения.");
    end
end);end
SLASH_UNBOTALTQUESTS1="/ubquests";
SlashCmdList.UNBOTALTQUESTS=function()Q.Show();end;


-- Original WotLK journal extension. Player rows/API indices remain owned by Blizzard.
Q.Native={offset=0};
local N=Q.Native;

function N.Settings()
    UnBotSquadConfig=UnBotSquadConfig or {};
    UnBotSquadConfig.altQuestJournal=UnBotSquadConfig.altQuestJournal or {};
    local key=Q.Context();
    if type(UnBotSquadConfig.altQuestJournal[key])~="table" then UnBotSquadConfig.altQuestJournal[key]={};end
    local settings=UnBotSquadConfig.altQuestJournal[key];
    if settings.missingOnly==nil then settings.missingOnly=false;end
    if type(settings.collapsedAlts)~="table" then settings.collapsedAlts={};end
    return settings;
end

function N.Roster()
    local rows={};
    for _,row in ipairs(Q.Alts()) do if row.online then table.insert(rows,row);end end
    return rows;
end

function N.RosterKey()
    local names={};for _,row in ipairs(N.Roster()) do table.insert(names,row.name);end
    return table.concat(names,"|");
end

function N.Fresh(name)
    local s=Q.cache[Q.Key(name)];
    return s and s.context==Q.Context() and not s.stale and GetTime()-s.at<=120 and s or nil;
end

function N.WithPlayerLog(callback)
    local selected=GetQuestLogSelection();
    local selectedId=selected and select(9,GetQuestLogTitle(selected));
    local headers={};local i=1;local result;
    Q.scanningPlayer=true;
    while i<=GetNumQuestLogEntries() and i<=100 do
        local _,_,_,_,header,closed=GetQuestLogTitle(i);
        if header and closed then table.insert(headers,i);ExpandQuestHeader(i);end
        i=i+1;
    end
    local ok,reason=pcall(function()result=callback();end);
    for j=#headers,1,-1 do CollapseQuestHeader(headers[j]);end
    if selectedId and selectedId>0 then
        for j=1,GetNumQuestLogEntries() do if select(9,GetQuestLogTitle(j))==selectedId then SelectQuestLogEntry(j);break end end
    elseif selected and selected>0 then SelectQuestLogEntry(selected);end
    Q.scanningPlayer=false;Q.playerCache=nil;Q.playerSignature=Q.PlayerSignature();
    if not ok then return nil,tostring(reason);end
    return result;
end

function N.PlayerEntries()
    return N.WithPlayerLog(function()
        local rows={};
        for i=1,GetNumQuestLogEntries() do
            local title,_,_,_,header,_,_,_,id=GetQuestLogTitle(i);
            if not header and tonumber(id) and id>0 then table.insert(rows,{id=id,title=title,link=type(GetQuestLink)=="function" and GetQuestLink(i) or nil});end
        end
        return rows;
    end);
end

function N.Push(id)
    return N.WithPlayerLog(function()
        for i=1,GetNumQuestLogEntries() do
            if select(9,GetQuestLogTitle(i))==id then
                SelectQuestLogEntry(i);
                if not GetQuestLogPushable() then return false;end
                if type(QuestLogPushQuest)~="function" then error("Штатная функция QuestLogPushQuest недоступна");end
                QuestLogPushQuest();return true;
            end
        end
        return false;
    end);
end

function N.Stop(text)
    local op=N.op;N.op=nil;
    N.nextAutoRefresh=GetTime()+60;
    if op and Q.job==op.activeJob then Q.job=nil;end
    if text then Q.Status(text,true);else Q.Refresh();end
end

function N.Start(mode,forceRead)
    Q.ClearConfirmation();
    if N.op then N.Stop("Обмен остановлен. Уже отправленные предложения остаются в игре.");return;end
    if Q.job then Q.Status("Дождитесь текущего запроса журнала.");return;end
    Q.SyncContext();Q.autoRead=nil;
    N.nextAutoRefresh=GetTime()+60;
    local roster=N.Roster();
    if #roster==0 then Q.Status("В группе нет подключённых альтов своего или связанного аккаунта.",true);return;end
    N.op={mode=mode or "view",forceRead=forceRead==true,phase="collect",roster=roster,rosterKey=N.RosterKey(),context=Q.Context(),
        index=1,snapshots={},deadline=GetTime()+600,nextAt=0,failed=0,pushed=0,accepted=0,refused=0,declined=0};
    N.Tick();Q.Refresh();
end

-- One bounded read pass every minute while the alt panel is visible.
-- A running action or confirmation defers the pass; missed intervals never accumulate.
function N.AutoRefresh()
    if not N.frame or not QuestLogFrame or not QuestLogFrame:IsShown()
        or not N.frame:IsShown() or not N.Settings().enabled then N.nextAutoRefresh=nil;return;end
    if not N.nextAutoRefresh then N.nextAutoRefresh=GetTime()+60;return;end
    if GetTime()<N.nextAutoRefresh or N.op or Q.job or Q.confirm or GetTime()<(Q.cooldown or 0) then return;end
    N.Start("view",true);
end

-- All selected online alts scan and accept independently; chat throttles retain their rate limit.
function N.NpcJob(sender)
    local op=N.op;
    return op and op.mode=="npc" and op.npcJobs and op.npcJobs[Q.Key(sender)] or nil;
end

function N.StartNpc()
    if N.op or Q.job or Q.confirm then Q.Status("Дождитесь текущей операции с заданиями.",true);return;end
    if not UnitExists("target") or UnitIsPlayer("target") or not UnitGUID("target") then
        Q.Status("Выберите квестодателя NPC своей целью.",true);return;
    end
    Q.SyncContext();local roster=N.Roster();
    if #roster==0 then Q.Status("В группе нет подключённых альтов своего или связанного аккаунта.",true);return;end
    Q.autoRead=nil;Q.ClearConfirmation();
    local op={mode="npc",phase="npc_parallel",roster=roster,rosterKey=N.RosterKey(),context=Q.Context(),
        target=UnitGUID("target"),targetName=UnitName("target") or "NPC",deadline=GetTime()+600,
        accepted=0,notAccepted=0,unverified=0,npcJobs={}};
    N.op=op;
    for i,alt in ipairs(roster) do
        if i<=39 then op.npcJobs[Q.Key(alt.name)]={kind="npc_talk",name=alt.name,context=op.context,npcOp=op,
            candidates={},candidateIds={},pendingAccepts=0,deadline=op.deadline};end
    end
    Q.Status("Проверяю доступные задания у "..op.targetName.." сразу для всех альтов. Команды принятия отправляются по мере ответов, без ожидания другого альта.",true);
    for _,alt in ipairs(roster) do
        local job=op.npcJobs[Q.Key(alt.name)];
        if job and not Q.Send("talk",job.name,job) then
            job.done=true;op.unverified=op.unverified+1;Q.Status(job.name..": запрос NPC не отправлен: "..tostring(Q.sendError)..". Повтора нет.",true);
        end
    end
    Q.Refresh();
end

function N.NpcReply(job,message)
    if job.done then return;end
    local text=tostring(message or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","");
    local lower=text:lower();
    local refused=lower:find("unknown",1,true) or lower:find("cannot",1,true) or lower:find("can't",1,true)
        or lower:find("not allowed",1,true) or lower:find("invalid",1,true) or lower:find("too far",1,true)
        or lower:find("not enough",1,true) or lower:find("log is full",1,true);
    if refused then job.refused=text;end
    if job.kind~="npc_talk" or not lower:match("^quest%s+[%a ]+:") then return;end
    job.sawReply=true;
    if not lower:match("^quest%s+available:") or job.refused then return;end
    local op=job.npcOp;
    if N.op~=op or UnitGUID("target")~=op.target or op.context~=Q.Context() or op.rosterKey~=N.RosterKey() then return;end
    for payload,title in text:gmatch("|H(quest:[^|]+)|h%[([^%]]+)%]|h") do
        local id=tonumber(payload:match("^quest:(%d+)"));
        if id and not job.candidateIds[id] and #job.candidates<25 then
            job.candidateIds[id]=true;
            local entry={id=id,title=title,link="|cffffff00|H"..payload.."|h["..title.."]|h|r"};
            table.insert(job.candidates,entry);
            local send={kind="npc_accept",name=job.name,context=job.context,npcOp=op,parent=job};
            job.pendingAccepts=job.pendingAccepts+1;
            if not Q.Send("accept "..entry.link,job.name,send) then
                job.pendingAccepts=job.pendingAccepts-1;entry.sendError=Q.sendError or "ошибка отправки";
            end
            Q.Status(job.name..": принимаю "..Q.QuestLabel(entry).." у "..op.targetName..".",true);
        end
    end
end

function N.NpcReport(op,job)
    local snapshot=job.result;local ids={};
    if snapshot and snapshot.context==op.context then for _,entry in ipairs(snapshot.entries) do ids[entry.id]=true;end
    else snapshot=nil;end
    for _,entry in ipairs(job.candidates) do
        local prefix=job.name..": Кв "..Q.QuestLabel(entry);
        if not snapshot then
            op.unverified=op.unverified+1;Q.Status(prefix..": не удалось проверить принятие — полный журнал не получен. Повторных команд нет.",true);
        elseif ids[entry.id] then
            op.accepted=op.accepted+1;Q.Status(prefix.." принят! Проверено по журналу альта.",true);
        else
            op.notAccepted=op.notAccepted+1;
            if snapshot.total>=25 then Q.Status(prefix.." доступен, НО не принят! Журнал альта заполнен (25 / 25).",true);
            elseif entry.sendError then Q.Status(prefix.." доступен, НО не принят! Команда не отправлена: "..entry.sendError..".",true);
            elseif job.refused then Q.Status(prefix.." доступен, НО не принят! Ответ сервера: "..job.refused..". Если альт далеко от NPC, надо подойти поближе.",true);
            else Q.Status(prefix.." доступен, НО не принят! Надо подойти поближе. Если альт уже рядом, проверьте ограничения задания.",true);end
        end
    end
    job.done=true;
end

function N.NpcTick(op)
    if UnitGUID("target")~=op.target then N.Stop("Квестодатель в цели изменился. Проверка и принятие остановлены; новые команды не отправлялись.");return;end
    local allDone=true;
    for _,alt in ipairs(op.roster) do
        local job=op.npcJobs[Q.Key(alt.name)];
        if job and not job.done then
            if job.kind=="npc_talk" and job.sentAt and GetTime()>=job.deadline and job.pendingAccepts==0
                and GetTime()>=(job.lastAcceptAt or 0)+2 then
                if #job.candidates==0 then
                    Q.Status(job.name..(job.refused and (": ответ сервера: "..job.refused) or (job.sawReply and ": доступных заданий у NPC не найдено." or ": нет ответа о доступных заданиях. Подведите альта ближе к NPC и повторите вручную.")),true);
                    if not job.sawReply or job.refused then op.unverified=op.unverified+1;end
                    job.done=true;
                else
                    job.kind="read";job.entries={};job.seen={};job.result=nil;job.sentAt=nil;job.deadline=op.deadline;
                    if not Q.Send("quests all",job.name,job) then job.readFailed=true;end
                end
            elseif job.kind=="read" and (job.result or job.readFailed or (job.sentAt and GetTime()>=job.deadline)) then
                N.NpcReport(op,job);
            end
            if not job.done then allDone=false;end
        end
    end
    if allDone then N.Stop("Проверка заданий у NPC завершена. Принято: "..op.accepted.."; не принято: "..op.notAccepted.."; не удалось проверить: "..op.unverified..".");end
end

function N.BeginRead(op,name)
    op.readName=name;op.readAt=GetTime();
    local phase=op.phase=="verify" and "проверка журналов после передачи" or "подготовка журналов";
    local progress="Обмен: "..phase.." ["..op.index.."/"..#op.roster.."], "..name..".";
    if op.mode=="exchange" then Q.Status(progress,true);end
    if Q.StartRead(name) then op.activeJob=Q.job;if op.mode=="exchange" then Q.Status(progress);end
    else op.failed=op.failed+1;op.readName=nil;op.index=op.index+1;end
end

function N.IncomingPlan(op)
    local rows,seen={},{};local own=Q.PlayerQuests();
    for _,alt in ipairs(op.roster) do
        local s=op.snapshots[alt.name];
        for _,entry in ipairs(s and s.entries or {}) do
            if not own[entry.id] and not seen[entry.id] then
                seen[entry.id]=true;table.insert(rows,{name=alt.name,entry=entry});
            end
        end
    end
    return rows;
end

function N.NextOffer(op)
    if op.pending then
        local p=op.pending;
        if Q.job then return;end
        if Q.PlayerQuests()[p.id] then op.accepted=op.accepted+1;op.pending=nil;op.nextAt=GetTime()+1;Q.Status("Принято от "..p.name..": "..Q.QuestLabel(p.entry).." ["..p.step.."/"..p.total.."].",true);return;end
        if p.state=="refused" then op.refused=op.refused+1;op.pending=nil;op.nextAt=GetTime()+1;return;end
        if p.state=="offered" and p.finished then op.declined=op.declined+1;op.pending=nil;op.nextAt=GetTime()+1;Q.Status("Предложение закрыто без принятия: "..p.name..", "..Q.QuestLabel(p.entry).." ["..p.step.."/"..p.total.."].",true);return;end
        if p.state~="offered" then N.Stop("Нет подтверждения предложения от "..p.name..": "..Q.QuestLabel(p.entry)..". Обмен остановлен без повторов; проверьте окно принятия.");return;end
        if GetTime()>p.deadline then N.Stop("Ожидание принятия задания истекло. Обмен остановлен; уже принято: "..op.accepted..".");end
        return;
    end
    if GetTime()<op.nextAt or (QuestFrame and QuestFrame:IsShown()) then return;end
    local own=Q.PlayerQuests();local count=0;for _ in pairs(own) do count=count+1;end
    if count>=25 then N.Stop("В журнале игрока нет свободных мест. Обмен завершён; предложено игроком: "..op.pushed..", принято игроком: "..op.accepted..".");return;end
    local item=op.incoming[op.index];
    if not item then
        N.Stop("Обмен завершён. Предложено игроком: "..op.pushed.."; принято игроком: "..op.accepted.."; отказов: "..op.refused.."; отклонено: "..op.declined.."; непрочитанных ответов: "..op.failed..".");return;
    end
    op.index=op.index+1;
    if own[item.entry.id] then return;end
    op.pending={id=item.entry.id,name=item.name,entry=item.entry,step=op.index-1,total=#op.incoming,state="sending",deadline=GetTime()+8};
    Q.selected=item.name;Q.questId=item.entry.id;
    Q.BeginAction("share",item.entry);op.activeJob=Q.job;
    if not Q.job then N.Stop("Ошибка отправки. Обмен остановлен: "..tostring(Q.sendError or Q.status));end
end

function N.Tick()
    local op=N.op;if not op then return;end
    if op.context~=Q.Context() or op.rosterKey~=N.RosterKey() then N.Stop("Состав или персонаж изменился. Обмен остановлен; запустите новый проход вручную.");return;end
    if GetTime()>op.deadline then N.Stop("Проход завершён по лимиту времени. Повторных команд не отправлялось.");return;end
    if op.mode=="npc" then N.NpcTick(op);return;end
    if op.phase=="incoming" then N.NextOffer(op);return;end
    if op.phase=="own" then
        if GetTime()<op.nextAt or (QuestFrame and QuestFrame:IsShown()) then return;end
        local entry=op.own[op.index];
        if not entry then op.phase="verify";op.index=1;op.snapshots={};Q.Refresh();return;end
        local progress="Обмен 1/2 ["..op.index.."/"..#op.own.."]: игрок -> группа, "..Q.QuestLabel(entry);
        op.index=op.index+1;op.nextAt=GetTime()+2;
        Q.Status(progress,true);
        local sent,reason=N.Push(entry.id);
        if sent==nil then N.Stop("Ошибка предложения "..Q.QuestLabel(entry)..": "..tostring(reason));return;end
        if sent then op.pushed=op.pushed+1;end
        Q.Status(progress..(sent and (" — предложено. Всего предложено: "..op.pushed..".") or " — передача недоступна, пропущено."),not sent);return;
    end
    if op.readName then
        if Q.job then return;end
        local s=N.Fresh(op.readName);
        if s and s.at>=op.readAt then op.snapshots[op.readName]=s;else op.failed=op.failed+1;end
        op.readName=nil;op.index=op.index+1;
    end
    local alt=op.roster[op.index];
    if alt then
        local cached=N.Fresh(alt.name);
        if op.mode=="view" and not op.forceRead and cached then op.snapshots[alt.name]=cached;op.index=op.index+1;Q.Refresh();return;end
        N.BeginRead(op,alt.name);return;
    end
    if op.mode=="view" then
        local loaded=0;for _ in pairs(op.snapshots) do loaded=loaded+1;end
        if loaded==0 then N.Stop("Не удалось загрузить журналы альтов. Непрочитанных ответов: "..op.failed..".");
        else N.Stop("Загружено журналов альтов: "..loaded.." из "..#op.roster..". Непрочитанных ответов: "..op.failed..".");end
        return;
    end
    if op.phase=="verify" then op.incoming=N.IncomingPlan(op);op.phase="incoming";op.index=1;Q.Refresh();return;end
    if not next(op.snapshots) then N.Stop("Нет полных ответов альтов. Обмен не выполнялся.");return;end
    local own,reason=N.PlayerEntries();
    if not own then N.Stop("Не удалось прочитать журнал игрока: "..tostring(reason));return;end
    op.own={};
    for _,entry in ipairs(own) do
        local missing=false;
        for _,s in pairs(op.snapshots) do
            local found=false;for _,e in ipairs(s.entries) do if e.id==entry.id then found=true;break end end
            if not found and s.total<25 then missing=true;break end
        end
        if missing then table.insert(op.own,entry);end
    end
    op.phase="own";op.index=1;Q.Status("Обмен: предлагаю группе доступные задания игрока.");
end

function N.Reply(job,text)
    local op=N.op;local p=op and op.pending;
    if not p or job.kind~="share" or job.id~=p.id or job.name~=p.name then return;end
    if text:find("quest was not shared",1,true) or text:find("cannot",1,true) or text:find("not allowed",1,true)
        or text:find("can't",1,true) or text:find("invalid quest",1,true) or text:find("unknown command",1,true) then p.state="refused";
    elseif text:find("quest shared",1,true) then p.state="offered";p.deadline=GetTime()+60;end
end


function N.DeleteEntry()
    local row=N.altSelection;if not row then return nil;end
    local snapshot=N.Fresh(row.name);
    for _,entry in ipairs(snapshot and snapshot.entries or {}) do if entry.id==row.entry.id then return entry;end end
end

function N.DropSelected()
    local row=N.altSelection;
    if N.op or Q.job or not row or not N.DeleteEntry() or not Q.Online(row.name) then
        Q.Status("Выберите задание онлайн-альта и обновите его журнал.");return;
    end
    Q.selected=row.name;Q.questId=row.entry.id;Q.Action("drop");
end

function N.ShowDeleteConfirmation(text)
    local row=N.altSelection;
    if not N.confirmPanel or not QuestLogFrame:IsShown() or not row or row.name~=Q.selected or row.entry.id~=Q.questId then return false;end
    N.confirmText:SetText(text);N.confirmPanel:Show();return true;
end

function N.DeleteVerified(name,id)
    local row=N.altSelection;
    if row and row.name==name and row.entry.id==id then N.altSelection=nil;N.ClearDetail();end
end

function N.ClearDetail()
    Q.ClearConfirmation();
    N.selected=nil;
    if N.detail then N.detail:Hide();end
    if QuestLogControlPanel_UpdateState then QuestLogControlPanel_UpdateState();end
end


function N.CaptureTooltip(row,tooltip)
    if not row or not row.entry or not tooltip or type(tooltip.NumLines)~="function" then return nil;end
    local name=tooltip:GetName();if not name then return nil;end
    local texts={};
    for i=1,math.min(tooltip:NumLines(),40) do
        local left=_G[name.."TextLeft"..i];local right=_G[name.."TextRight"..i];
        local text=left and left:GetText();local extra=right and right:GetText();
        if extra and extra~="" then text=(text or "").." "..extra;end
        if text and text:find("%S") then table.insert(texts,text);end
    end
    if #texts<1 then return nil;end
    local title=table.remove(texts,1);
    N.descriptions=N.descriptions or {};
    local data={title=title,objectives=#texts>0 and table.concat(texts,"\n\n") or nil};N.descriptions[row.entry.id]=data;
    return data;
end

function N.Description(row)
    if not N.scanTooltip then N.scanTooltip=CreateFrame("GameTooltip","UnBotAltQuestDescriptionTooltip",UIParent,"GameTooltipTemplate");end
    local tooltip=N.scanTooltip;tooltip:SetOwner(UIParent,"ANCHOR_NONE");tooltip:ClearLines();
    local ok=pcall(tooltip.SetHyperlink,tooltip,row.entry.link:match("|H([^|]+)|h"));
    local data=ok and N.CaptureTooltip(row,tooltip);tooltip:Hide();
    data=data or (N.descriptions and N.descriptions[row.entry.id]);
    if data and data.objectives then return data;end
    -- Optional localized DB fallback. The native tooltip remains the primary source.
    if QuestieLoader and type(QuestieLoader.ImportModule)=="function" then
        local loaded,db=pcall(QuestieLoader.ImportModule,QuestieLoader,"QuestieDB");
        if loaded and db and type(db.QueryQuestSingle)=="function" then
            local found,objectives=pcall(db.QueryQuestSingle,row.entry.id,"objectivesText");
            local titled,title=pcall(db.QueryQuestSingle,row.entry.id,"name");
            if found and type(objectives)=="table" then
                local text={};for _,line in ipairs(objectives) do if type(line)=="string" then table.insert(text,line);end end
                if #text>0 then return {title=data and data.title or (titled and title or row.entry.title),objectives=table.concat(text,"\n\n")};end
            end
        end
    end
    return data;
end

function N.RenderDetail(row,data)
    N.detail.title:SetText(data and data.title or row.entry.title);
    N.detail.info:SetText("Задание альта: "..row.name.."\n"..(row.entry.complete and "Выполнено" or "В процессе")
        ..(Q.ClassLabel(row.entry.id) and ("\nКлассовое: "..Q.ClassLabel(row.entry.id)) or "")
        .."\n\nЦели задания\n\n"..(data and data.objectives or "Клиент ещё не получил текст этого задания. Наведите мышь на его строку, чтобы запросить подсказку."));
    local height=N.detail.info:GetStringHeight()+8;N.detail.info:SetHeight(height);N.detail.content:SetHeight(math.max(1,height));
end

function N.MarkOwnClasses()
    if not QuestLogScrollFrame or not QuestLogScrollFrame.buttons then return;end
    for _,button in ipairs(QuestLogScrollFrame.buttons) do
        local index=button:GetID();
        if index and index>0 then
            local title,level,_,_,header,_,_,_,id=GetQuestLogTitle(index);
            if title and not header then
                local current=button:GetText();
                if button.unbotOwnIndex~=index or button.unbotOwnQuest~=id or current~=button.unbotOwnRendered then
                    button.unbotOwnBase=current or title;button.unbotOwnIndex=index;button.unbotOwnQuest=id;
                end
                local formatted=(N.Settings().showPlayerLevels and level and level>0 and ("["..level.." ур.] ") or "")
                    ..(Q.ClassLabel(id) and "[Классовое] " or "")..(button.unbotOwnBase or title);
                if current~=formatted then
                    button:SetText(formatted);
                    if QuestLogTitleButton_Resize then QuestLogTitleButton_Resize(button);end
                end
                button.unbotOwnRendered=formatted;
            else button.unbotOwnIndex=nil;button.unbotOwnRendered=nil;button.unbotOwnBase=nil;button.unbotOwnQuest=nil;end
        end
    end
end


function N.SetMissingOnly(value)
    N.Settings().missingOnly=value and true or false;N.offset=0;Q.ClearConfirmation();
    if value and N.altSelection and Q.PlayerQuests()[N.altSelection.entry.id] then N.altSelection=nil;end
    if value and N.selected and Q.PlayerQuests()[N.selected.entry.id] then N.ClearDetail();end
    N.Refresh();
end

function N.LocalTitle(row)
    local id=row.entry.id;
    if Q.playerQuestNames and Q.playerQuestNames[id] then return Q.playerQuestNames[id];end
    local data=N.descriptions and N.descriptions[id];if data and data.title then return data.title;end
    if QuestieLoader and type(QuestieLoader.ImportModule)=="function" then
        local ok,db=pcall(QuestieLoader.ImportModule,QuestieLoader,"QuestieDB");
        if ok and db and type(db.QueryQuestSingle)=="function" then
            local titled,title=pcall(db.QueryQuestSingle,id,"name");
            if titled and type(title)=="string" and title~="" then return title;end
        end
    end
    N.titleTried=N.titleTried or {};
    if not N.titleTried[id] then
        N.titleTried[id]=true;data=N.Description(row);
        if data and data.title then return data.title;end
    end
    return row.entry.title;
end

function N.OpenOwn(id)
    local headers={};local targetHeader;local currentHeader;local i=1;
    Q.scanningPlayer=true;
    while i<=GetNumQuestLogEntries() and i<=100 do
        local _,_,_,_,header,closed,_,_,qid=GetQuestLogTitle(i);
        if header then currentHeader=i;if closed then table.insert(headers,i);ExpandQuestHeader(i);end end
        if qid==id then targetHeader=currentHeader;end
        i=i+1;
    end
    -- Reveal the selected quest's own section, preserving all other closed sections.
    for j=#headers,1,-1 do if headers[j]~=targetHeader then CollapseQuestHeader(headers[j]);end end
    Q.scanningPlayer=false;Q.playerCache=nil;
    N.ClearDetail();
    for j=1,GetNumQuestLogEntries() do
        if select(9,GetQuestLogTitle(j))==id then
            N.openingOwn=true;QuestLog_SetSelection(j);if QuestLog_Update then QuestLog_Update();end;N.openingOwn=false;return true;
        end
    end
    return false;
end

function N.Select(row)
    if N.op or Q.job then return;end
    if not row.entry then return;end
    Q.ClearConfirmation();N.altSelection=row;Q.selected=row.name;Q.questId=row.entry.id;
    if Q.PlayerQuests()[row.entry.id] then N.OpenOwn(row.entry.id);return;end
    Q.selected=row.name;Q.questId=row.entry.id;N.selected=row;
    N.RenderDetail(row,N.Description(row));
    N.detail.scroll:SetVerticalScroll(0);
    N.detail:Show();if QuestLogControlPanel then QuestLogControlPanel:Hide();end
    N.Refresh();
end

function N.ToggleAlt(name)
    local collapsed=N.Settings().collapsedAlts;local key=Q.Key(name);
    collapsed[key]=not collapsed[key] or nil;
    if collapsed[key] and N.altSelection and Q.Key(N.altSelection.name)==key then
        N.altSelection=nil;N.ClearDetail();
    end
    N.Refresh();
end

function N.Rows()
    local rows={};local own=Q.PlayerQuests();
    for _,alt in ipairs(N.Roster()) do
        local snapshot=Q.cache[Q.Key(alt.name)];
        if snapshot and snapshot.context~=Q.Context() then snapshot=nil;end
        local entries={};
        for _,entry in ipairs(snapshot and snapshot.entries or {}) do
            if not N.Settings().missingOnly or not own[entry.id] then table.insert(entries,entry);end
        end
        table.sort(entries,function(a,b)
            local al=N.EntryLevel(a) or math.huge;local bl=N.EntryLevel(b) or math.huge;
            if al~=bl then return al<bl;end
            return a.id<b.id;
        end);
        local collapsed=N.Settings().collapsedAlts[Q.Key(alt.name)]==true;
        table.insert(rows,{header=true,collapsed=collapsed,name=alt.name,text=alt.name..(snapshot and (" — "..#entries.." из "..snapshot.total..(N.Fresh(alt.name) and "" or "; обновите")) or " — журнал не загружен")});
        if not collapsed then
            for _,entry in ipairs(entries) do table.insert(rows,{name=alt.name,entry=entry,shared=own[entry.id] and true or false});end
        end
    end
    return rows;
end

-- Independent windows: never shorten the player's quest viewport for the alt list.
function N.SaveWindow(frame,key)
    local settings=N.Settings();local value=settings[key] or {};settings[key]=value;
    value.width=frame:GetWidth();value.height=frame:GetHeight();
    if frame.GetLeft and frame:GetLeft() and frame:GetTop() then
        local scale=frame:GetEffectiveScale()/UIParent:GetEffectiveScale();
        value.x=frame:GetLeft()*scale;value.y=frame:GetTop()*scale;
    end
end

function N.RestoreWindow(frame,key,width,height)
    local value=N.Settings()[key] or {};
    local maxW,maxH=UIParent:GetWidth(),UIParent:GetHeight();
    frame:SetWidth(math.max(key=="journalWindow" and 682 or 280,math.min(value.width or width,maxW)));
    frame:SetHeight(math.max(key=="journalWindow" and 447 or 300,math.min(value.height or height,maxH)));
    frame:ClearAllPoints();
    if value.x and value.y then
        frame:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",value.x,value.y);
    elseif key=="sideWindow" then
        frame:SetPoint("TOPLEFT",QuestLogFrame,"TOPRIGHT",8,0);
    else
        frame:SetPoint("CENTER",UIParent,"CENTER",N.Settings().enabled and -150 or 0,0);
    end
end

function N.WindowControls(frame,key)
    frame:SetMovable(true);frame:SetUserPlaced(true);frame:SetResizable(true);frame:SetClampedToScreen(true);
    frame:SetMinResize(key=="journalWindow" and 682 or 280,key=="journalWindow" and 447 or 300);
    frame:SetMaxResize(UIParent:GetWidth(),UIParent:GetHeight());
    local drag=CreateFrame("Frame",nil,frame);drag:SetPoint("TOPLEFT",48,-2);drag:SetPoint("TOPRIGHT",-32,-2);drag:SetHeight(29);
    drag:EnableMouse(true);drag:RegisterForDrag("LeftButton");
    drag:SetScript("OnDragStart",function()frame:StartMoving();end);
    drag:SetScript("OnDragStop",function()frame:StopMovingOrSizing();N.SaveWindow(frame,key);end);
    local grip=CreateFrame("Button",nil,frame);grip:SetWidth(18);grip:SetHeight(18);grip:SetPoint("BOTTOMRIGHT",-2,2);
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up");
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight");
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down");
    grip:SetScript("OnMouseDown",function(_,button)if button=="LeftButton" then frame:StartSizing("BOTTOMRIGHT");end end);
    grip:SetScript("OnMouseUp",function()frame:StopMovingOrSizing();N.SaveWindow(frame,key);end);
    frame:HookScript("OnHide",function()frame:StopMovingOrSizing();end);
    frame.unbotDrag=drag;frame.unbotGrip=grip;
end

function N.DescriptionWidths(parent)
    N.textWidths=N.textWidths or {};
    local names={"QuestInfoTitleHeader","QuestInfoDescriptionHeader","QuestInfoDescriptionText","QuestInfoObjectivesHeader","QuestInfoObjectivesText","QuestInfoGroupSize","QuestInfoRewardText","QuestInfoSpellObjectiveLearnLabel"};
    for i=1,10 do table.insert(names,"QuestInfoObjective"..i);end
    for _,name in ipairs(names) do
        local text=_G[name];
        if text and text.GetWidth then
            if not N.textWidths[name] then N.textWidths[name]=text:GetWidth();end
            if parent==QuestLogDetailScrollChildFrame and QuestLogFrame:IsShown() then
                text:SetWidth(math.max(180,QuestLogDetailScrollFrame:GetWidth()-25));
            else text:SetWidth(N.textWidths[name]);end
        end
    end
end

-- Slice the original artwork: fixed header/footer/edges, stretch only panel interiors.
-- ElvUI owns both the dark quest background and its light text palette.
function N.ElvUIQuestSkin()
    local engine=type(ElvUI)=="table" and ElvUI[1];
    local skins=type(engine)=="table" and engine.private and engine.private.skins;
    local blizzard=skins and skins.blizzard;
    return blizzard and blizzard.enable and blizzard.quest and true or false;
end

function N.SkinLayout(width,height,left)
    if N.ElvUIQuestSkin() then
        for _,part in ipairs(N.skin or {}) do part.texture:Hide();end
        return;
    end
    if not QuestLogFrame.CreateTexture then return;end
    if not N.skin then
        N.skin={};
        local xs={0,18,330,350,512,650,682};local ys={0,73,410,445};
        for y=1,3 do for x=1,6 do
            local texture=QuestLogFrame:CreateTexture(nil,"BORDER");
            local right=xs[x]>=512;local origin=right and 512 or 0;local atlas=right and 256 or 512;
            texture:SetTexture(right and "Interface\\QuestFrame\\UI-QuestLogDualPane-RIGHT" or "Interface\\QuestFrame\\UI-QuestLogDualPane-Left");
            texture:SetTexCoord((xs[x]-origin)/atlas,(xs[x+1]-origin)/atlas,ys[y]/512,ys[y+1]/512);
            table.insert(N.skin,{texture=texture,x=x,y=y});
        end end
        if QuestLogFrame.GetRegions then
            for _,region in ipairs({QuestLogFrame:GetRegions()}) do
                if region.GetTexture then
                    local path=region:GetTexture();local ours=false;
                    for _,part in ipairs(N.skin) do if part.texture==region then ours=true;break end end
                    if not ours and type(path)=="string" and path:find("UI-QuestLogDualPane-",1,true) then region:Hide();end
                end
            end
        end
    end
    local divider=left+45;local paperWidth=width-32-divider;
    local xs={0,18,left+25,divider,divider+paperWidth*162/300,width-32,width};
    local ys={0,73,height-37,height-2};
    for _,part in ipairs(N.skin) do
        part.texture:ClearAllPoints();part.texture:SetPoint("TOPLEFT",QuestLogFrame,"TOPLEFT",xs[part.x],-ys[part.y]);
        part.texture:SetWidth(xs[part.x+1]-xs[part.x]);part.texture:SetHeight(ys[part.y+1]-ys[part.y]);part.texture:Show();
    end
end

function N.Layout()
    if N.layingOut or not N.frame then return;end
    N.layingOut=true;
    local width,height=QuestLogFrame:GetWidth(),QuestLogFrame:GetHeight();
    local left=math.floor((width-72)/2);local right=width-left-79;local body=height-112;
    QuestLogScrollFrame:ClearAllPoints();QuestLogScrollFrame:SetPoint("TOPLEFT",QuestLogFrame,"TOPLEFT",19,-75);
    QuestLogScrollFrame:SetWidth(left);QuestLogScrollFrame:SetHeight(body);
    if QuestLogScrollFrame.scrollChild then QuestLogScrollFrame.scrollChild:SetWidth(left);end
    if not QuestLogDetailScrollFrame.GetParent or QuestLogDetailScrollFrame:GetParent()==QuestLogFrame then
        QuestLogDetailScrollFrame:ClearAllPoints();QuestLogDetailScrollFrame:SetPoint("TOPRIGHT",QuestLogFrame,"TOPRIGHT",-32,-77);
        QuestLogDetailScrollFrame:SetWidth(right);QuestLogDetailScrollFrame:SetHeight(body-2);
        if QuestLogDetailScrollChildFrame then QuestLogDetailScrollChildFrame:SetWidth(right);end
    end
    if QuestLogControlPanel and (not QuestLogControlPanel.GetParent or QuestLogControlPanel:GetParent()==QuestLogFrame) then QuestLogControlPanel:SetWidth(left+2);end
    N.exchange:ClearAllPoints();N.exchange:SetPoint("BOTTOMLEFT",QuestLogFrame,"BOTTOMLEFT",left+45,14);
    N.detail.title:SetWidth(right-28);N.detail.content:SetWidth(right-48);N.detail.info:SetWidth(right-48);N.detail.share:SetWidth(right-28);
    if N.selected then N.RenderDetail(N.selected,N.descriptions and N.descriptions[N.selected.entry.id]);end
    -- Grow the native row pool with the viewport, keeping native quest indices and group marks.
    if N.rowHeight~=body and QuestLogScrollFrame.scrollChild and HybridScrollFrame_CreateButtons then
        N.rowHeight=body;
        local bar=QuestLogScrollFrame.scrollBar;local offset=bar and bar:GetValue() or 0;
        if N.rowPool then QuestLogScrollFrame.buttons=N.rowPool;end
        HybridScrollFrame_CreateButtons(QuestLogScrollFrame,"QuestLogTitleButtonTemplate");
        N.rowPool=QuestLogScrollFrame.buttons;local active={};
        local count=math.ceil(body/N.rowPool[1]:GetHeight())+1;
        for i,button in ipairs(N.rowPool) do if i<=count then active[i]=button;else button:Hide();end end
        QuestLogScrollFrame.buttons=active;
        if bar then bar:SetValue(offset);end
        if QuestLog_Update then QuestLog_Update();end
    end
    for _,button in ipairs(QuestLogScrollFrame.buttons or {}) do
        button:SetWidth(left-6);if button.normalText and QuestLogTitleButton_Resize then QuestLogTitleButton_Resize(button);end
    end
    N.SkinLayout(width,height,left);
    if QuestLogDetailScrollChildFrame then N.DescriptionWidths(QuestLogDetailScrollChildFrame);end
    if N.frame then
        if N.npcAccept then N.npcAccept:SetWidth(math.max(130,N.frame:GetWidth()-126));end
        N.status:SetWidth(N.frame:GetWidth()-32);N.dropButton:SetWidth(N.frame:GetWidth()-48);
    end
    N.layingOut=false;
end

-- Quest hyperlinks carry the quest level; difficulty is evaluated for the current player.
function N.EntryLevel(entry)
    local level=tonumber(entry.level) or tonumber((entry.link or ""):match("quest:%d+:([%-]?%d+)"));
    if level and level>0 then return level;end
end

function N.RowText(row)
    if row.header then return "|cffffd100"..(row.collapsed and "[+] " or "[-] ")..row.text.."|r";end
    local level=N.EntryLevel(row.entry);local color="|cffffffff";
    if level and GetQuestDifficultyColor then
        local rgb=GetQuestDifficultyColor(level);
        if rgb then color=string.format("|cff%02x%02x%02x",math.floor(rgb.r*255+0.5),math.floor(rgb.g*255+0.5),math.floor(rgb.b*255+0.5));end
    end
    return "  "..color..(level and ("["..level.." ур.] ") or "")..(Q.ClassLabel(row.entry.id) and "[Классовое] " or "")
        ..N.LocalTitle(row).."|r"..(row.shared and " |cff999999(есть у меня)|r" or "");
end

function N.Refresh()
    if not N.frame then return;end
    local shown=N.Settings().enabled==true;N.check:SetChecked(shown);
    N.missingCheck:SetChecked(N.Settings().missingOnly);
    N.levelCheck:SetChecked(N.Settings().showPlayerLevels==true);
    if shown then N.missingCheck:Enable();else N.missingCheck:Disable();end
    if not QuestLogFrame:IsShown() then return;end
    N.Layout();N.MarkOwnClasses();
    if shown then
        if EmptyQuestLogFrame then EmptyQuestLogFrame:Hide();end
        N.frame:Show();
        local count=math.max(1,math.min(50,math.floor((N.frame:GetHeight()-190)/20)));
        local rows=N.Rows();N.offset=math.max(0,math.min(N.offset,math.max(0,#rows-count)));
        for i,b in ipairs(N.buttons) do
            local row=i<=count and rows[N.offset+i] or nil;b.row=row;
            if row then
                b:SetWidth(N.frame:GetWidth()-42);b.label:SetWidth(N.frame:GetWidth()-50);
                b:SetText(N.RowText(row));b:Show();
                if b.LockHighlight then
                    if not row.header and N.altSelection and N.altSelection.name==row.name and N.altSelection.entry.id==row.entry.id then b:LockHighlight();else b:UnlockHighlight();end
                end
                if not row.header and (N.op or Q.job) then b:Disable();else b:Enable();end
            else b:Hide();end
        end
        N.scrollUpdating=true;N.scroll:SetMinMaxValues(0,math.max(0,#rows-count));N.scroll:SetValue(N.offset);N.scrollUpdating=nil;
        N.status:SetText(Q.status or "Числа возле имени: показано из общего количества.");
    else
        N.frame:Hide();N.ClearDetail();
    end
    if N.selected and Q.PlayerQuests()[N.selected.entry.id] then N.ClearDetail();end
    local selectedAlt=N.altSelection;
    if not N.op and not Q.job and selectedAlt and N.DeleteEntry() and Q.Online(selectedAlt.name) and GetTime()>=(Q.cooldown or 0) then N.dropButton:Enable();else N.dropButton:Disable();end
    if N.selected then
        if not N.op and Q.CanAct() then N.detail.share:Enable();else N.detail.share:Disable();end
    end
    if N.npcAccept then if N.op or Q.job or Q.confirm then N.npcAccept:Disable();else N.npcAccept:Enable();end end
    N.exchange:SetText(N.op and (N.op.mode=="exchange" and "Остановить обмен" or "Остановить чтение") or "Обменяться заданиями");
end

function N.Enable(enabled)
    N.Settings().enabled=enabled and true or false;
    if not enabled then N.altSelection=nil;N.Stop();N.ClearDetail();end
    N.Refresh();if QuestLog_Update then QuestLog_Update();end
    if enabled and not N.op and not Q.job then N.Start("view");end
end

function N.Build()
    if N.frame or not QuestLogFrame or not QuestLogScrollFrame or not QuestLogDetailScrollFrame then return;end
    N.check=CreateFrame("CheckButton","UnBotJournalAltsCheck",QuestLogFrame,"UICheckButtonTemplate");
    N.check:SetWidth(22);N.check:SetHeight(22);N.check:SetPoint("TOPLEFT",QuestLogFrame,"TOPLEFT",175,-45);
    local label=N.check:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");label:SetPoint("LEFT",N.check,"RIGHT",0,0);label:SetText("Показать задания альтов");
    N.levelCheck=CreateFrame("CheckButton","UnBotJournalPlayerLevelCheck",QuestLogFrame,"UICheckButtonTemplate");
    N.levelCheck:SetWidth(22);N.levelCheck:SetHeight(22);N.levelCheck:SetPoint("TOPLEFT",QuestLogFrame,"TOPLEFT",357,-45);
    local levelLabel=N.levelCheck:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");levelLabel:SetPoint("LEFT",N.levelCheck,"RIGHT",0,0);levelLabel:SetText("Показывать уровень");
    N.levelCheck:SetScript("OnClick",function(self)N.Settings().showPlayerLevels=self:GetChecked() and true or false;N.Refresh();end);
    N.frame=UnBotServiceUI.Panel(QuestLogFrame,340,447);N.frame:Hide();
    N.missingCheck=CreateFrame("CheckButton","UnBotJournalMissingCheck",N.frame,"UICheckButtonTemplate");
    N.missingCheck:SetWidth(22);N.missingCheck:SetHeight(22);N.missingCheck:SetPoint("TOPLEFT",N.frame,"TOPLEFT",12,-34);
    local missingLabel=N.missingCheck:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");missingLabel:SetPoint("LEFT",N.missingCheck,"RIGHT",0,0);missingLabel:SetText("Только которых нет у меня");
    N.missingCheck:SetScript("OnClick",function(self)N.SetMissingOnly(self:GetChecked());end);
    N.check:SetScript("OnClick",function(self)N.Enable(self:GetChecked());end);
    N.frame:SetPoint("TOPLEFT",QuestLogFrame,"TOPRIGHT",8,0);
    local title=N.frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");title:SetPoint("TOPLEFT",16,-12);title:SetText("Задания альтов");
    N.reload=CreateFrame("Button",nil,N.frame,"UIPanelButtonTemplate");N.reload:SetWidth(78);N.reload:SetHeight(18);N.reload:SetPoint("TOPLEFT",16,-65);N.reload:SetText("Обновить");N.reload:SetScript("OnClick",function()if not N.op then N.Start("view",true);end end);
    N.npcAccept=CreateFrame("Button",nil,N.frame,"UIPanelButtonTemplate");N.npcAccept:SetHeight(18);N.npcAccept:SetWidth(180);
    N.npcAccept:SetPoint("TOPLEFT",N.reload,"TOPRIGHT",8,0);N.npcAccept:SetText("Взять у NPC");N.npcAccept:SetScript("OnClick",N.StartNpc);
    N.npcAccept:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_TOP");GameTooltip:AddLine("Проверить и принять все доступные задания у выбранного NPC",1,0.82,0,true);
        GameTooltip:AddLine("Для всех онлайн-альтов текущей группы одновременно: запрос NPC, принятие доступных заданий по мере ответов и проверка журналов. Альты должны стоять рядом с NPC. Команда talk может также сдать выполненные задания этому NPC. Повторов команд нет.",1,1,1,true);GameTooltip:Show();
    end);N.npcAccept:SetScript("OnLeave",function()GameTooltip:Hide();end);
    N.status=N.frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");N.status:SetPoint("BOTTOMLEFT",16,45);N.status:SetWidth(308);N.status:SetHeight(40);N.status:SetJustifyH("LEFT");
    N.dropButton=CreateFrame("Button","UnBotJournalDropAltQuest",N.frame,"UIPanelButtonTemplate");N.dropButton:SetWidth(150);N.dropButton:SetHeight(23);N.dropButton:SetPoint("BOTTOMLEFT",16,14);N.dropButton:SetText("Отменить у альта…");
    N.dropButton:SetScript("OnClick",N.DropSelected);
    N.dropButton:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_TOP");local row=N.altSelection;
        GameTooltip:AddLine(row and ("Отменить у "..row.name..": "..N.LocalTitle(row)) or "Выберите задание альта",1,0.82,0,true);
        GameTooltip:AddLine("Будет отменено только задание выбранного альта. Перед отправкой появится подтверждение.",1,1,1,true);GameTooltip:Show();
    end);N.dropButton:SetScript("OnLeave",function()GameTooltip:Hide();end);
    N.buttons={};N.frame:EnableMouseWheel(true);
    N.frame:SetScript("OnMouseWheel",function(_,d)N.offset=N.offset-d*3;N.Refresh();end);
    for i=1,50 do
        local b=CreateFrame("Button",nil,N.frame);b:SetHeight(19);b:SetPoint("TOPLEFT",12,-96-(i-1)*20);
        b.label=b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");b.label:SetPoint("LEFT",4,0);b.label:SetJustifyH("LEFT");b:SetFontString(b.label);
        b:SetNormalFontObject("GameFontHighlightSmall");b:SetHighlightFontObject("GameFontNormalSmall");
        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight","ADD");
        b:SetScript("OnClick",function(self)
            if not self.row then return;end
            if self.row.header then N.ToggleAlt(self.row.name);return;end
            if not self.row.entry then return;end
            if IsShiftKeyDown() then ChatEdit_InsertLink(self.row.entry.link);else N.Select(self.row);end
        end);
        b:SetScript("OnEnter",function(self)if self.row and self.row.entry then
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:ClearLines();GameTooltip:SetHyperlink(self.row.entry.link:match("|H([^|]+)|h"));
            local data=N.CaptureTooltip(self.row,GameTooltip);
            if data and N.selected and N.selected.entry.id==self.row.entry.id then N.RenderDetail(N.selected,data);end
            if Q.ClassLabel(self.row.entry.id) then GameTooltip:AddLine("Классовое: "..Q.ClassLabel(self.row.entry.id),1,0.82,0,true);end
            GameTooltip:Show();end end);
        b:SetScript("OnLeave",function()GameTooltip:Hide();end);N.buttons[i]=b;
    end
    N.detail=UnBotServiceUI.Panel(QuestLogFrame,300,335);N.detail:SetAllPoints(QuestLogDetailScrollFrame);N.detail:SetFrameLevel(QuestLogDetailScrollFrame:GetFrameLevel()+10);N.detail:Hide();
    N.detail.title=UnBotServiceUI.Text(N.detail,17,270);N.detail.title:SetPoint("TOPLEFT",12,-12);N.detail.title:SetHeight(52);
    N.detail.scroll=CreateFrame("ScrollFrame","UnBotAltQuestDescriptionScroll",N.detail,"UIPanelScrollFrameTemplate");
    N.detail.scroll:SetPoint("TOPLEFT",N.detail,"TOPLEFT",12,-72);N.detail.scroll:SetPoint("BOTTOMRIGHT",N.detail,"BOTTOMRIGHT",-30,46);
    N.detail.content=CreateFrame("Frame",nil,N.detail.scroll);N.detail.content:SetWidth(250);N.detail.content:SetHeight(215);N.detail.scroll:SetScrollChild(N.detail.content);
    N.detail.info=UnBotServiceUI.Text(N.detail.content,13,250);N.detail.info:SetPoint("TOPLEFT",0,0);N.detail.info:SetHeight(215);
    N.detail.share=UnBotServiceUI.Button(N.detail,270,"Попросить поделиться",function()Q.Action("share");end);N.detail.share:SetHeight(26);N.detail.share:SetPoint("BOTTOMLEFT",12,12);N.detail.share:GetFontString():SetFont(STANDARD_TEXT_FONT,13);
    N.confirmPanel=UnBotServiceUI.Panel(QuestLogFrame,560,160);N.confirmPanel:SetPoint("CENTER",QuestLogFrame,"CENTER",0,0);N.confirmPanel:SetFrameStrata("FULLSCREEN_DIALOG");N.confirmPanel:Hide();
    N.confirmText=UnBotServiceUI.Text(N.confirmPanel,16,512);N.confirmText:SetPoint("TOPLEFT",24,-20);N.confirmText:SetHeight(80);
    N.confirmYes=UnBotServiceUI.Button(N.confirmPanel,235,"Отменить задание у альта",Q.ConfirmDrop);N.confirmYes:SetHeight(30);N.confirmYes:GetFontString():SetFont(STANDARD_TEXT_FONT,14);N.confirmYes:SetPoint("BOTTOMLEFT",24,16);
    N.confirmNo=UnBotServiceUI.Button(N.confirmPanel,160,"Назад",Q.ClearConfirmation);N.confirmNo:SetHeight(30);N.confirmNo:SetPoint("BOTTOMRIGHT",-24,16);
    N.exchange=CreateFrame("Button","UnBotJournalExchange",QuestLogFrame,"UIPanelButtonTemplate");N.exchange:SetWidth(190);N.exchange:SetHeight(21);N.exchange:SetPoint("BOTTOMLEFT",QuestLogFrame,"BOTTOMLEFT",350,14);
    N.exchange:SetText("Обменяться заданиями");N.exchange:SetScript("OnClick",function()N.Start("exchange");end);
    N.exchange:SetScript("OnEnter",function(self)GameTooltip:SetOwner(self,"ANCHOR_TOP");GameTooltip:AddLine("Один обмен с альтами текущей группы",1,0.82,0);GameTooltip:AddLine("Ваши задания предлагаются группе. Затем альты по одному предлагают задания, которых у вас нет. Окна принятия закрываете вы.",1,1,1,true);GameTooltip:Show();end);
    N.exchange:SetScript("OnLeave",function()GameTooltip:Hide();end);
    N.close=CreateFrame("Button",nil,N.frame,"UIPanelCloseButton");N.close:SetPoint("TOPRIGHT",0,0);N.close:SetScript("OnClick",function()N.Enable(false);end);
    N.scroll=CreateFrame("Slider","UnBotJournalAltScrollBar",N.frame,"UIPanelScrollBarTemplate");
    N.scroll:SetPoint("TOPRIGHT",-14,-112);N.scroll:SetPoint("BOTTOMRIGHT",-14,110);N.scroll:SetMinMaxValues(0,0);N.scroll:SetValueStep(1);
    N.scroll:SetScript("OnValueChanged",function(_,value)if not N.scrollUpdating then N.offset=math.floor(value+0.5);N.Refresh();end end);
    -- Opt out of the stock panel manager so the journal keeps the player's position.
    QuestLogFrame:SetAttribute("UIPanelLayout-defined",true);QuestLogFrame:SetAttribute("UIPanelLayout-enabled",false);
    local registered=false;for _,name in ipairs(UISpecialFrames) do if name=="QuestLogFrame" then registered=true;end end
    if not registered then table.insert(UISpecialFrames,"QuestLogFrame");end
    N.WindowControls(QuestLogFrame,"journalWindow");N.WindowControls(N.frame,"sideWindow");
    N.RestoreWindow(QuestLogFrame,"journalWindow",682,447);N.RestoreWindow(N.frame,"sideWindow",340,447);
    QuestLogFrame:HookScript("OnSizeChanged",function()N.Layout();N.Refresh();
        if QuestLog_UpdateQuestDetails and QuestLogFrame:IsShown() and not N.selected then QuestLog_UpdateQuestDetails(false);end
    end);
    N.frame:HookScript("OnSizeChanged",function()N.Layout();N.Refresh();end);
    if QuestInfo_Display then hooksecurefunc("QuestInfo_Display",function(_,parent)N.DescriptionWidths(parent);end);end
    if type(QuestLogDetailFrame_DetachFromQuestLog)=="function" then hooksecurefunc("QuestLogDetailFrame_DetachFromQuestLog",function()
        QuestLogDetailScrollFrame:SetWidth(298);if QuestLogDetailScrollChildFrame then QuestLogDetailScrollChildFrame:SetWidth(298);end
        N.DescriptionWidths(nil);
    end);end
    if type(QuestLogDetailFrame_AttachToQuestLog)=="function" then hooksecurefunc("QuestLogDetailFrame_AttachToQuestLog",N.Layout);end
    QuestLogFrame:HookScript("OnShow",function()N.RestoreWindow(QuestLogFrame,"journalWindow",682,447);N.RestoreWindow(N.frame,"sideWindow",340,447);N.Refresh();if N.Settings().enabled and not N.op and not Q.job then N.Start("view");end end);
    QuestLogFrame:HookScript("OnHide",function()N.altSelection=nil;N.Stop();N.nextAutoRefresh=nil;N.ClearDetail();end);
    hooksecurefunc("QuestLog_SetSelection",function(questIndex)if not Q.scanningPlayer then
        -- An empty native journal periodically selects 0; it does not select another quest.
        if questIndex==0 and N.selected and not N.openingOwn then N.Refresh();return;end
        if not N.openingOwn then N.altSelection=nil;end
        N.ClearDetail();N.Refresh();
    end end);
    hooksecurefunc("QuestLog_Update",function()if not Q.scanningPlayer then N.Refresh();end end);
    hooksecurefunc("QuestLogControlPanel_UpdateState",function()if N.selected and QuestLogControlPanel then QuestLogControlPanel:Hide();end end);
    if QuestLogControlPanel then QuestLogControlPanel:HookScript("OnShow",function(self)if N.selected then self:Hide();end end);end
end

function N.Event(event)
    if event=="PLAYER_LOGIN" then N.Build();return;end
    if N.op and N.op.pending then
        if event=="QUEST_DETAIL" then N.op.pending.sawPopup=true;
        elseif event=="QUEST_FINISHED" and N.op.pending.sawPopup then N.op.pending.finished=true;end
    end
    if event~="CHAT_MSG_WHISPER" and not Q.scanningPlayer then N.Refresh();end
end

Q.LegacyShow=Q.Show;
function Q.Show(name)
    N.Build();
    if not N.frame then Q.LegacyShow(name);return;end
    Q.SyncContext();
    if Q.window then Q.window:Hide();end
    if not QuestLogFrame:IsShown() then ShowUIPanel(QuestLogFrame);end
    N.Enable(true);
end

N.Build();
for _,event in ipairs({"PLAYER_LOGIN","QUEST_DETAIL","QUEST_FINISHED"}) do Q.events:RegisterEvent(event);end
