-- Shipped author data is never SavedVariables. Runtime presets remain in
-- UnBotSquadConfig.bossPresets for compatibility with the boss controllers.
UnBotAuthorPresets = { version = 6, author = "Теридан", defaults = {} };

-- BEGIN GENERATED AUTHOR PRESETS
-- Exported boss settings only; no registry, history or account database.
UnBotAuthorPresets.version = 6;
UnBotAuthorPresets.defaults = {
	["blackwing_lair__razorgore_the_untamed"] = {
		["40n"] = {
			["autoGuideOnTargetEnabled"] = false,
			["autoStrategyEnabled"] = false,
			["includeResurrectionReserve"] = false,
			["masterLootEnabled"] = true,
			["requirements"] = {
				[1] = {
					["className"] = "warrior",
					["count"] = 2,
					["label"] = "|cFFC79C6EWarrior|r - Protection (Tank)",
					["specKey"] = "prot",
				},
				[2] = {
					["className"] = "hunter",
					["count"] = 3,
					["label"] = "|cFFABD473Hunter|r - Marksmanship (DPS)",
					["specKey"] = "mm",
				},
				[3] = {
					["className"] = "mage",
					["count"] = 3,
					["label"] = "|cFF69CCF0Mage|r - Frost (DPS)",
					["specKey"] = "frost",
				},
				[4] = {
					["className"] = "shaman",
					["count"] = 1,
					["label"] = "|cFF0070DEShaman|r - Elemental (DPS)",
					["specKey"] = "ele",
				},
				[5] = {
					["className"] = "dk",
					["count"] = 1,
					["label"] = "|cFFC41F3BDeath Knight|r - Blood (Tank)",
					["specKey"] = "blood",
				},
				[6] = {
					["className"] = "priest",
					["count"] = 1,
					["label"] = "|cFFFFFFFFPriest|r - Discipline (Heal)",
					["specKey"] = "disc",
				},
			},
			["resurrectionReserveCount"] = 0,
			["savedAt"] = "2026-09-20",
			["schemaVersion"] = 3,
			["source"] = "composition supplied by Tiridan for Razorgore",
			["storageMode"] = "class-spec",
		},
	},
	["blood_queen_lanathel"] = {
		["25h"] = {
			["autoGuideOnTargetEnabled"] = false,
			["autoStrategyEnabled"] = true,
			["guideText"] = "[Главное]\nНе иди соло. На этом сервере Лана'тель становится берсерком примерно на пятой минуте; для соло потребовалось бы ориентировочно около 8–10 тысяч DPS, что практически недостижимо. Используй уже сохранённый состав «игрок + 2 бота» и закончи бой до берсерка.\n\n[Роль ботов]\nБоты нужны прежде всего как дополнительные цели механики: они сдерживают королеву и подхиливают, пока игрок наносит основной урон. Не рассчитывай на них как на главный источник DPS — темп боя разгоняется вампирским усилением самого игрока.\n\n[Жажда и укус]\nКогда появляется Жажда крови, обязательно используй Вампирский укус до окончания короткого таймера. По стандартной механике нужно кусать любого доступного союзника, который ещё не стал вампиром; в этом малом составе строгий приоритет между двумя ботами не нужен. На текущем сервере также проверено, что укус самой Лана'тель не ломает бой и позволяет продолжить разгон DPS, но это нестандартное поведение и его могут исправить.\n\n[Проверка DPS]\nEssence of the Blood Queen резко усиливает урон и частично лечит от нанесённого урона. Используй усиление для непрерывного DPS и убей Лана'тель до пятой минуты. В обычной механике WotLK берсерк наступает примерно через 5:30; здесь безопасный ориентир короче — 5:00.",
			["guideUpdatedAt"] = "2026-08-29",
			["includeResurrectionReserve"] = true,
			["masterLootEnabled"] = true,
			["requirements"] = {
				[1] = {
					["className"] = "paladin",
					["count"] = 1,
					["label"] = "|cFFF58CBAPaladin|r - Protection (Tank)",
					["specKey"] = "prot",
				},
				[2] = {
					["className"] = "paladin",
					["count"] = 1,
					["label"] = "|cFFF58CBAPaladin|r - Holy (Heal)",
					["specKey"] = "holy",
				},
			},
			["resurrectionReserveCount"] = 1,
			["savedAt"] = "2026-08-03 12:13:38",
			["schemaVersion"] = 2,
			["source"] = "saved from current group/raid",
			["startMessage"] = "НЕ ИДИ СОЛО: на этом сервере берсерк примерно на 5-й минуте, а соло требует около 8–10 тысяч DPS. Вызови сохранённых 2 ботов: они сдерживают босса и подхиливают. При Жажде обязательно используй Укус — безопаснее кусать любого доступного невампира-бота; здесь также срабатывает укус самой Лана'тель. Разгоняй DPS усилением королевы и убей её до берсерка.",
			["startMessageUpdatedAt"] = "2026-08-29",
			["storageMode"] = "class-spec",
		},
		["25n"] = {
			["autoGuideOnTargetEnabled"] = false,
			["autoStrategyEnabled"] = true,
			["includeResurrectionReserve"] = true,
			["masterLootEnabled"] = true,
			["requirements"] = {
				[1] = {
					["className"] = "paladin",
					["count"] = 1,
					["label"] = "|cFFF58CBAPaladin|r - Protection (Tank)",
					["specKey"] = "prot",
				},
				[2] = {
					["className"] = "paladin",
					["count"] = 1,
					["label"] = "|cFFF58CBAPaladin|r - Holy (Heal)",
					["specKey"] = "holy",
				},
			},
			["resurrectionReserveCount"] = 1,
			["savedAt"] = "2026-08-25 16:13:36",
			["schemaVersion"] = 2,
			["source"] = "saved class/spec requirements from current group/raid",
			["storageMode"] = "class-spec",
		},
	},
	["deathbringer_saurfang"] = {
		["25h"] = {
			["autoGuideOnTargetEnabled"] = false,
			["autoStrategyEnabled"] = true,
			["includeResurrectionReserve"] = false,
			["masterLootEnabled"] = true,
			["requirements"] = {
				[1] = {
					["className"] = "dk",
					["count"] = 1,
					["label"] = "|cFFC41F3BDeath Knight|r - Blood (Tank)",
					["specKey"] = "blood",
				},
				[2] = {
					["className"] = "paladin",
					["count"] = 1,
					["label"] = "|cFFF58CBAPaladin|r - Holy (Heal)",
					["specKey"] = "holy",
				},
				[3] = {
					["className"] = "rogue",
					["count"] = 3,
					["label"] = "|cFFFFF569Rogue|r - Combat (DPS)",
					["specKey"] = "combat",
				},
			},
			["resurrectionReserveCount"] = 0,
			["savedAt"] = "2026-07-29 13:21:24",
			["schemaVersion"] = 2,
			["source"] = "BossMemory kill: Tiridan + Blood DK + Holy Paladin + 3 Combat Rogue",
			["startMessage"] = "УНИВЕРСАЛЬНЫЙ СОСТАВ: подходит для Саурфанга 25 гер, 25 об. и 10. НЕ ПЕРЕКЛЮЧАЙСЯ С БОССА — боты сами берут аддов по меткам и уничтожают их за секунды.",
			["startMessageUpdatedAt"] = "2026-08-29",
			["storageMode"] = "class-spec",
		},
	},
	["festergut"] = {
		["25h"] = {
			["autoGuideOnTargetEnabled"] = false,
			["autoStrategyEnabled"] = true,
			["guideText"] = "[Соло — стаки газа]\nНа 25 гер практически нереально задамажить Тухлопуза до опасного порога. 10 стаков газа убивают. Сбрасывай накопление сразу на 9 стаках: десятый стак иногда прилетает почти сразу, поэтому не жди.\n\n[Паладин]\nНа девятом стаке сразу используй Божественный щит. Он полностью снимает все накопленные стаки и позволяет продолжить соло-бой.\n\n[Другие классы]\nЗаранее найди надёжный аналог сброса. Если класс не может гарантированно снять стаки, не иди соло: вызови штатный состав с двумя танками и их ротацией либо подбери свой. Базовый состав работает, но соло-вариант на паладине проверялся чаще.",
			["guideUpdatedAt"] = "2026-08-29",
			["includeResurrectionReserve"] = true,
			["masterLootEnabled"] = true,
			["requirements"] = {
				[1] = {
					["className"] = "dk",
					["count"] = 2,
					["label"] = "|cFFC41F3BDeath Knight|r - Blood (Tank)",
					["specKey"] = "blood",
				},
				[2] = {
					["className"] = "paladin",
					["count"] = 1,
					["label"] = "|cFFF58CBAPaladin|r - Holy (Heal)",
					["specKey"] = "holy",
				},
				[3] = {
					["className"] = "rogue",
					["count"] = 3,
					["label"] = "|cFFFFF569Rogue|r - Combat (DPS)",
					["specKey"] = "combat",
				},
			},
			["resurrectionReserveCount"] = 1,
			["savedAt"] = "2026-07-29",
			["schemaVersion"] = 2,
			["source"] = "Festergut 25 heroic: Tiridan + 2 Blood DK + Holy Paladin + 3 Combat Rogue",
			["startMessage"] = "СОЛО: СБРОС НА 9 СТАКАХ ГАЗА — 10-й убивает и может прилететь сразу. Паладин: Божественный щит полностью очищает стаки. Другим классам нужен свой сброс либо состав с двумя танками.",
			["startMessageUpdatedAt"] = "2026-08-29",
			["storageMode"] = "class-spec",
		},
	},
	["gunship_battle"] = {
		["10n"] = {
			["autoGuideOnTargetEnabled"] = false,
			["autoStrategyEnabled"] = true,
			["guideText"] = "[Роль игрока — Альянс]\nВсё время стой на палубе своего корабля и убивай аддов, которые прыгают через портал. Главная задача — оставаться целью вражеских метателей топоров и принимать их урон на себя. Если игрок исчезает с палубы, метатели переключаются на корабль и начинают его уничтожать. Проще говоря, твоя роль — «всасывать» их урон.\n\n[Метатели топоров]\nОставаясь на своей палубе, старайся бить метателей дальними заклинаниями и убивать их как можно быстрее. Не давай им долго жить, эволюционировать и накапливать апгрейды: к концу боя их урон может стать смертельным даже для персонажа в латах. Держи реактивный ранец наготове. Если принимать их урон стало слишком тяжело, сделай один контролируемый прыжок, быстро зачисти метателей на вражеской палубе и сразу вернись. При составе «игрок + 2 бота» каждый такой прыжок обходится примерно в 20–25% здоровья своего корабля, поэтому максимально экономь прыжки. Это аварийный сброс усиления, а не обычная позиция: прыгай только когда дальнейшее усиление метателей опаснее цены прыжка.\n\n[Бой]\nНе прыгай на вражеский корабль: так ты потеряешь метателей, а у вражеского босса иногда нестабильно проходит смертельный урон. Не садись в пушку: на этом сервере корабль игрока может ошибочно запустить сценарий разрушения, а боты — провалиться под палубу. Остальную механику выполняют боты.",
			["guideUpdatedAt"] = "2026-08-29",
			["includeResurrectionReserve"] = false,
			["masterLootEnabled"] = true,
			["requirements"] = {
				[1] = {
					["className"] = "paladin",
					["count"] = 1,
					["label"] = "|cFFF58CBAPaladin|r - Retribution (DPS)",
					["specKey"] = "ret",
				},
				[2] = {
					["className"] = "warlock",
					["count"] = 1,
					["label"] = "|cFF9482C9Warlock|r - Demonology (DPS)",
					["specKey"] = "demo",
				},
			},
			["resurrectionReserveCount"] = 0,
			["savedAt"] = "2026-08-05 12:45:23",
			["schemaVersion"] = 2,
			["source"] = "saved class/spec requirements from current group/raid",
			["startMessage"] = "АЛЬЯНС: НЕ ПОКИДАЙ ПАЛУБУ! Бей метателей топоров издалека и не давай им усилиться. Ранец держи наготове, но экономь прыжки: составом «игрок + 2 бота» каждый стоит около 20–25% HP корабля. Если урон уже не держится, один раз прыгни, зачисти метателей и сразу вернись.",
			["startMessageUpdatedAt"] = "2026-08-29",
			["storageMode"] = "class-spec",
		},
		["25h"] = {
			["autoGuideOnTargetEnabled"] = false,
			["autoStrategyEnabled"] = true,
			["guideText"] = "[Роль игрока — Альянс]\nВсё время стой на палубе своего корабля и убивай аддов, которые прыгают через портал. Главная задача — оставаться целью вражеских метателей топоров и принимать их урон на себя. Если игрок исчезает с палубы, метатели переключаются на корабль и начинают его уничтожать. Проще говоря, твоя роль — «всасывать» их урон.\n\n[Метатели топоров]\nОставаясь на своей палубе, старайся бить метателей дальними заклинаниями и убивать их как можно быстрее. Не давай им долго жить, эволюционировать и накапливать апгрейды: к концу боя их урон может стать смертельным даже для персонажа в латах. Держи реактивный ранец наготове. Если принимать их урон стало слишком тяжело, сделай один контролируемый прыжок, быстро зачисти метателей на вражеской палубе и сразу вернись. При составе «игрок + 2 бота» каждый такой прыжок обходится примерно в 20–25% здоровья своего корабля, поэтому максимально экономь прыжки. Это аварийный сброс усиления, а не обычная позиция: прыгай только когда дальнейшее усиление метателей опаснее цены прыжка.\n\n[Бой]\nНе прыгай на вражеский корабль: так ты потеряешь метателей, а у вражеского босса иногда нестабильно проходит смертельный урон. Не садись в пушку: на этом сервере корабль игрока может ошибочно запустить сценарий разрушения, а боты — провалиться под палубу. Остальную механику выполняют боты.",
			["guideUpdatedAt"] = "2026-08-29",
			["includeResurrectionReserve"] = true,
			["masterLootEnabled"] = true,
			["requirements"] = {
				[1] = {
					["className"] = "paladin",
					["count"] = 2,
					["label"] = "|cFFF58CBAPaladin|r - Retribution (DPS)",
					["specKey"] = "ret",
				},
			},
			["resurrectionReserveCount"] = 1,
			["savedAt"] = "2026-08-29 12:11:48",
			["schemaVersion"] = 2,
			["source"] = "saved class/spec requirements from current group/raid",
			["startMessage"] = "АЛЬЯНС: НЕ ПОКИДАЙ ПАЛУБУ! Бей метателей топоров издалека и не давай им усилиться. Ранец держи наготове, но экономь прыжки: составом «игрок + 2 бота» каждый стоит около 20–25% HP корабля. Если урон уже не держится, один раз прыгни, зачисти метателей и сразу вернись.",
			["startMessageUpdatedAt"] = "2026-08-29",
			["storageMode"] = "class-spec",
		},
		["25n"] = {
			["autoGuideOnTargetEnabled"] = false,
			["autoStrategyEnabled"] = true,
			["guideText"] = "[Роль игрока — Альянс]\nВсё время стой на палубе своего корабля и убивай аддов, которые прыгают через портал. Главная задача — оставаться целью вражеских метателей топоров и принимать их урон на себя. Если игрок исчезает с палубы, метатели переключаются на корабль и начинают его уничтожать. Проще говоря, твоя роль — «всасывать» их урон.\n\n[Метатели топоров]\nОставаясь на своей палубе, старайся бить метателей дальними заклинаниями и убивать их как можно быстрее. Не давай им долго жить, эволюционировать и накапливать апгрейды: к концу боя их урон может стать смертельным даже для персонажа в латах. Держи реактивный ранец наготове. Если принимать их урон стало слишком тяжело, сделай один контролируемый прыжок, быстро зачисти метателей на вражеской палубе и сразу вернись. При составе «игрок + 2 бота» каждый такой прыжок обходится примерно в 20–25% здоровья своего корабля, поэтому максимально экономь прыжки. Это аварийный сброс усиления, а не обычная позиция: прыгай только когда дальнейшее усиление метателей опаснее цены прыжка.\n\n[Бой]\nНе прыгай на вражеский корабль: так ты потеряешь метателей, а у вражеского босса иногда нестабильно проходит смертельный урон. Не садись в пушку: на этом сервере корабль игрока может ошибочно запустить сценарий разрушения, а боты — провалиться под палубу. Остальную механику выполняют боты.",
			["guideUpdatedAt"] = "2026-08-29",
			["includeResurrectionReserve"] = true,
			["masterLootEnabled"] = true,
			["requirements"] = {
				[1] = {
					["className"] = "paladin",
					["count"] = 2,
					["label"] = "|cFFF58CBAPaladin|r - Retribution (DPS)",
					["specKey"] = "ret",
				},
			},
			["resurrectionReserveCount"] = 1,
			["savedAt"] = "2026-08-25 14:40:20",
			["schemaVersion"] = 2,
			["source"] = "saved class/spec requirements from current group/raid",
			["startMessage"] = "АЛЬЯНС: НЕ ПОКИДАЙ ПАЛУБУ! Бей метателей топоров издалека и не давай им усилиться. Ранец держи наготове, но экономь прыжки: составом «игрок + 2 бота» каждый стоит около 20–25% HP корабля. Если урон уже не держится, один раз прыгни, зачисти метателей и сразу вернись.",
			["startMessageUpdatedAt"] = "2026-08-29",
			["storageMode"] = "class-spec",
		},
	},
	["lord_marrowgar"] = {
		["25h"] = {
			["autoGuideOnTargetEnabled"] = false,
			["autoStrategyEnabled"] = true,
			["guideText"] = "[Бой]\nКостяные шипы — главный приоритет. Перед ожидаемым кастом заранее положи AOE под себя: это помогает ломать шип, даже если бот не успел переключиться. Держись рядом с Holy Paladin — его автоматическое AOE дополнительно бьёт шипы. Не добавляй лишних ботов без необходимости: на этом сервере вместе с составом растёт здоровье шипов.",
			["guideUpdatedAt"] = "2026-08-29",
			["includeResurrectionReserve"] = true,
			["masterLootEnabled"] = true,
			["requirements"] = {
				[1] = {
					["className"] = "dk",
					["count"] = 1,
					["label"] = "|cFFC41F3BDeath Knight|r - Blood (Tank)",
					["specKey"] = "blood",
				},
				[2] = {
					["className"] = "paladin",
					["count"] = 1,
					["label"] = "|cFFF58CBAPaladin|r - Holy (Heal)",
					["specKey"] = "holy",
				},
			},
			["resurrectionReserveCount"] = 1,
			["savedAt"] = "2026-07-28 21:07:21",
			["schemaVersion"] = 2,
			["source"] = "BossMemory: Lord Marrowgar 25 heroic, Tiridan + Blood DK + Holy Paladin",
			["startMessage"] = "AOE-урон под себя прямо перед кастом шипов! Держись ближе к хилу: он автоматически даёт AOE по шипам.",
			["startMessageUpdatedAt"] = "2026-08-29 11:14:40",
			["storageMode"] = "class-spec",
		},
	},
	["professor_putricide"] = {
		["25h"] = {
			["autoGuideOnTargetEnabled"] = false,
			["autoStrategyEnabled"] = true,
			["guideText"] = "[Главное]\nСтабильную тактику с ботами подобрать не удалось: при появлении луж они начинают тупить. Управление поганищем и пожирание луж помогают только частично и крайне нестабильны. Самый надёжный вариант — соло: быстро пройти DPS-проверку и пережить усиление босса на 30%.\n\n[Лужи]\nСразу после пула уводи Мерзоцида к одной из стен и складывай лужи там, подальше от стойки с колбами. В соло они дамажат несильно; если хочешь избегать урона, потихоньку веди босса вдоль стены. Главное — не клади лужи у стойки.\n\n[Смена фаз — героик]\nСейчас на 25 гер и 10 гер сервер иногда не кидает парализующую газовую склянку. Как только началась смена фазы, если тебя не оглушило, сразу беги за Мерзоцидом к стойке и продолжай бить его во время анимации. Это серверный баг и его могут исправить.\n\n[Обычный режим]\nНа 10 об. и 25 об. газовая склянка работает и нормально оглушает между фазами. Не рассчитывай там на героическое окно урона.",
			["guideUpdatedAt"] = "2026-08-29",
			["includeResurrectionReserve"] = true,
			["masterLootEnabled"] = true,
			["requirements"] = {
				[1] = {
					["className"] = "rogue",
					["count"] = 1,
					["label"] = "|cFFFFF569Rogue|r - Combat (DPS)",
					["specKey"] = "combat",
				},
				[2] = {
					["className"] = "warrior",
					["count"] = 1,
					["label"] = "|cFFC79C6EWarrior|r - Arms (DPS)",
					["specKey"] = "arms",
				},
				[3] = {
					["className"] = "paladin",
					["count"] = 1,
					["label"] = "|cFFF58CBAPaladin|r - Holy (Heal)",
					["specKey"] = "holy",
				},
			},
			["resurrectionReserveCount"] = 1,
			["savedAt"] = "2026-08-02 22:28:00",
			["schemaVersion"] = 2,
			["source"] = "Putricide 25 heroic boss-only test: player tank + Holy Paladin + Combat Rogue + Arms/Fury Warrior",
			["startMessage"] = "ГЕРОИК: стабильнее идти СОЛО. Сразу уводи Мерзоцида к стене и складывай лужи сбоку. На смене фазы, если газ не оглушил, беги к стойке и продолжай DPS во время анимации. Нужно пройти DPS-проверку и пережить усиление на 30%.",
			["startMessageUpdatedAt"] = "2026-08-29",
			["storageMode"] = "class-spec",
		},
		["25n"] = {
			["autoGuideOnTargetEnabled"] = false,
			["autoStrategyEnabled"] = true,
			["guideText"] = "[Общее]\nСостав: игрок и один Protection Paladin. Прот-пал нужен только как неподвижный танк-якорь, чтобы Мерзоцид не сбросился, пока игрок управляет поганищем.\n\n[До пула]\nВстаньте в точке, где должен остаться танк, и запустите этот пресет. UnBot призовёт прот-пала, включит tank + stay и отключит ICC, avoid aoe, formation, flee и самостоятельный DPS.\n\n[Бой]\nДержите Мерзоцида в цели на пуле и сами выпейте Drink Me! Бот напиток не использует. Он остаётся в луже и получает адресный аварийный самохил: Holy Light ниже 52% HP и один Lay on Hands ниже 18%.",
			["guideUpdatedAt"] = "2026-08-09",
			["includeResurrectionReserve"] = true,
			["masterLootEnabled"] = true,
			["requirements"] = {
				[1] = {
					["className"] = "paladin",
					["count"] = 1,
					["label"] = "|cFFF58CBAPaladin|r - Holy (Heal)",
					["specKey"] = "holy",
				},
				[2] = {
					["className"] = "paladin",
					["count"] = 1,
					["label"] = "|cFFF58CBAPaladin|r - Protection (Tank)",
					["specKey"] = "prot",
				},
				[3] = {
					["className"] = "warlock",
					["count"] = 3,
					["label"] = "|cFF9482C9Warlock|r - Demonology (DPS)",
					["specKey"] = "demo",
				},
			},
			["resurrectionReserveCount"] = 1,
			["savedAt"] = "2026-08-09 09:59:56",
			["schemaVersion"] = 2,
			["source"] = "saved class/spec requirements from current group/raid",
			["storageMode"] = "class-spec",
		},
	},
	["rotface"] = {
		["25h"] = {
			["autoGuideOnTargetEnabled"] = false,
			["autoStrategyEnabled"] = true,
			["guideText"] = "[Мили — соло]\nГниломорд — простой соло-бой для милишника. Стой в центре комнаты и бей босса. Боты, отдельный состав или дополнительные действия не нужны.\n\n[Дальний бой]\nСоло-тактика для дальника не проверена. Не рассчитывай на мили-сценарий вслепую: при необходимости вызови сохранённый базовый состав или подбери свой.",
			["guideUpdatedAt"] = "2026-08-29",
			["includeResurrectionReserve"] = false,
			["masterLootEnabled"] = true,
			["requirements"] = {
				[1] = {
					["className"] = "dk",
					["count"] = 1,
					["label"] = "|cFFC41F3BDeath Knight|r - Blood (Tank)",
					["specKey"] = "blood",
				},
				[2] = {
					["className"] = "paladin",
					["count"] = 1,
					["label"] = "|cFFF58CBAPaladin|r - Holy (Heal)",
					["specKey"] = "holy",
				},
				[3] = {
					["className"] = "rogue",
					["count"] = 3,
					["label"] = "|cFFFFF569Rogue|r - Combat (DPS)",
					["specKey"] = "combat",
				},
			},
			["resurrectionReserveCount"] = 0,
			["savedAt"] = "2026-07-29",
			["schemaVersion"] = 2,
			["source"] = "confirmed Rotface 25 heroic kill: Tiridan + Blood DK + Holy Paladin + 3 Combat Rogue",
			["startMessage"] = "МИЛИ: ИДИ СОЛО — стой в центре и бей Гниломорда, состав не нужен. ДАЛЬНИЙ БОЙ: соло не проверено; может потребоваться базовый или свой состав.",
			["startMessageUpdatedAt"] = "2026-08-29",
			["storageMode"] = "class-spec",
		},
	},
	["sindragosa"] = {
		["10n"] = {
			["autoGuideOnTargetEnabled"] = false,
			["autoStrategyEnabled"] = true,
			["includeResurrectionReserve"] = false,
			["masterLootEnabled"] = true,
			["requirements"] = {
				[1] = {
					["className"] = "warrior",
					["count"] = 1,
					["label"] = "Warrior - Protection (Tank)",
					["specKey"] = "prot",
				},
				[2] = {
					["className"] = "dk",
					["count"] = 1,
					["label"] = "Death Knight - Blood (Tank)",
					["specKey"] = "blood",
				},
				[3] = {
					["className"] = "druid",
					["count"] = 1,
					["label"] = "Druid - Restoration (Heal)",
					["specKey"] = "resto",
				},
				[4] = {
					["className"] = "warlock",
					["count"] = 4,
					["label"] = "Warlock - Demonology (DPS)",
					["specKey"] = "demo",
				},
			},
			["resurrectionReserveCount"] = 0,
			["savedAt"] = "2026-07-28",
			["schemaVersion"] = 2,
			["source"] = "successful Sindragosa composition",
			["storageMode"] = "class-spec",
		},
		["25h"] = {
			["autoGuideOnTargetEnabled"] = true,
			["autoStrategyEnabled"] = true,
			["confirmedKillAt"] = "2026-08-30 00:00:46",
			["guideText"] = "[Состав]\nРабочий минимальный состав: игрок и ровно 2 Retribution Paladin. Победа на 25 heroic подтверждена боевым логом 30.08.2026; этот же состав установлен для 25 normal. Офлайн-резерв не нужен.\n\n[Третья фаза]\nКогда один ретрик попадает в глыбу, второй временно получает tank, включает Righteous Fury и забирает Синдрагосу. После сброса стаков игрок вручную таунтит босса обратно; подтверждённый удар по Tiridan возвращает ретрика в DPS. Глыбы получают приоритет, затем боты автоматически продолжают бить Синдрагосу.\n\n[Выживание]\nНа 40% HP и ниже ретрики ограниченно используют Holy Light; на 20% и ниже один раз пытаются применить Lay on Hands. Замороженным и мёртвым ботам команды лечения не отправляются. На воздушной фазе игрок сам нажимает Божественный щит по предупреждению UnBot.",
			["guideUpdatedAt"] = "2026-08-30",
			["includeResurrectionReserve"] = false,
			["masterLootEnabled"] = true,
			["requirements"] = {
				[1] = {
					["className"] = "paladin",
					["count"] = 2,
					["label"] = "Paladin - Retribution (DPS)",
					["specKey"] = "ret",
				},
			},
			["resurrectionReserveCount"] = 0,
			["savedAt"] = "2026-08-30",
			["schemaVersion"] = 2,
			["source"] = "WORKING: Sindragosa 25 heroic killed 2026-08-30 00:00:46 with player + 2 Retribution Paladin",
			["startMessage"] = "РАБОЧИЙ СОСТАВ: игрок + 2 ретри-паладина. На воздушной фазе нажми Божественный щит по предупреждению. В третьей фазе дай временному танку забрать босса, сбрось стаки за глыбой и таунти обратно; после подтверждённого удара боты разбирают глыбу и возвращаются на Синдрагосу.",
			["startMessageUpdatedAt"] = "2026-08-30",
			["storageMode"] = "class-spec",
		},
		["25n"] = {
			["autoGuideOnTargetEnabled"] = false,
			["autoStrategyEnabled"] = true,
			["guideText"] = "[Состав]\nРабочий минимальный состав: игрок и ровно 2 Retribution Paladin. Победа на 25 heroic подтверждена боевым логом 30.08.2026; этот же состав установлен для 25 normal. Офлайн-резерв не нужен.\n\n[Третья фаза]\nКогда один ретрик попадает в глыбу, второй временно получает tank, включает Righteous Fury и забирает Синдрагосу. После сброса стаков игрок вручную таунтит босса обратно; подтверждённый удар по Tiridan возвращает ретрика в DPS. Глыбы получают приоритет, затем боты автоматически продолжают бить Синдрагосу.\n\n[Выживание]\nНа 40% HP и ниже ретрики ограниченно используют Holy Light; на 20% и ниже один раз пытаются применить Lay on Hands. Замороженным и мёртвым ботам команды лечения не отправляются. На воздушной фазе игрок сам нажимает Божественный щит по предупреждению UnBot.",
			["guideUpdatedAt"] = "2026-08-30",
			["includeResurrectionReserve"] = false,
			["masterLootEnabled"] = true,
			["requirements"] = {
				[1] = {
					["className"] = "paladin",
					["count"] = 2,
					["label"] = "Paladin - Retribution (DPS)",
					["specKey"] = "ret",
				},
			},
			["resurrectionReserveCount"] = 0,
			["savedAt"] = "2026-08-30",
			["schemaVersion"] = 2,
			["source"] = "WORKING COPY: Sindragosa 25 normal uses the combat-log-confirmed 25 heroic player + 2 Retribution Paladin preset",
			["startMessage"] = "РАБОЧИЙ СОСТАВ: игрок + 2 ретри-паладина. На воздушной фазе нажми Божественный щит по предупреждению. В третьей фазе дай временному танку забрать босса, сбрось стаки за глыбой и таунти обратно; после подтверждённого удара боты разбирают глыбу и возвращаются на Синдрагосу.",
			["startMessageUpdatedAt"] = "2026-08-30",
			["storageMode"] = "class-spec",
		},
	},
	["sister_svalna"] = {
		["25n"] = {
			["autoGuideOnTargetEnabled"] = false,
			["autoStrategyEnabled"] = true,
			["guideText"] = "[Состав]\nВозьми с собой минимум двух ботов. Свална бросает копьё, и дополнительные участники нужны, чтобы освободить захваченную цель. Без двух ботов механика копья может сорвать бой.\n\n[До Свалны]\nПри выборе пресета UnBot пытается выбрать Свалну и поставить на неё Луну. Пока Луна стоит на боссе, танк не должен бежать к ней напролом через окружающие пачки. Если Свална ещё недоступна для выбора, попытка повторяется раз в 10 секунд.\n\n[Бой со Свалной]\nКогда Свална сама вступает в бой, UnBot меняет Луну на Череп и отправляет танку и ДД ограниченные команды фокуса по Черепу.",
			["guideUpdatedAt"] = "2026-08-29",
			["includeResurrectionReserve"] = true,
			["masterLootEnabled"] = true,
			["requirements"] = {
				[1] = {
					["className"] = "paladin",
					["count"] = 1,
					["label"] = "|cFFF58CBAPaladin|r - Protection (Tank)",
					["specKey"] = "prot",
				},
				[2] = {
					["className"] = "paladin",
					["count"] = 1,
					["label"] = "|cFFF58CBAPaladin|r - Holy (Heal)",
					["specKey"] = "holy",
				},
			},
			["resurrectionReserveCount"] = 1,
			["savedAt"] = "2026-08-05",
			["schemaVersion"] = 2,
			["source"] = "Sister Svalna 25 normal: player + Protection Paladin + Holy Paladin + one offline Restoration Druid reserve",
			["startMessage"] = "ВОЗЬМИ МИНИМУМ 2 БОТОВ: они нужны, чтобы снимать копьё Свалны. До боя UnBot ставит на Свалну Луну, чтобы танк не побежал к ней через все пачки; когда начинается бой с самой Свалной, метка меняется на Череп.",
			["startMessageUpdatedAt"] = "2026-08-29",
			["storageMode"] = "class-spec",
		},
	},
	["the_lich_king"] = {
		["10h"] = {
			["autoGuideOnTargetEnabled"] = false,
			["autoStrategyEnabled"] = true,
			["guideText"] = "[Подготовка]\nТестовый состав: игрок + Protection Paladin + Holy Paladin + Marksmanship Hunter. Победа этим составом пока не подтверждена. Включи графические эффекты и проецируемые текстуры, чтобы видеть ловушки.\n\n[Переход]\nНа Беспощадности зимы выйди на внешний обод, убивай ледяные сферы и духов. На Сотрясении немедленно вернись внутрь платформы. Автостратегия временно снимает общий avoid aoe, оставляя ICC, и затем возвращает исходные флаги.\n\n[Валь'киры]\nОбщий фокус всех доступных ботов на одну отмеченную валь'киру. На героике достаточно опустить её до 50% HP, затем переключиться на следующую. На обычном режиме — убить. Держи опасную валь'киру видимой через свою цель или цели группы; без метки автофокус ждёт ICC. Не стой у края перед захватом. При Осквернении выходи из опасной зоны.\n\n[Проверка]\nВ чате появляется «общий фокус ВСЕХ ботов», затем подтверждения фактического урона. Команда фокуса не отключает лечение хилера и не гарантирует переопределение серверного AI.",
			["includeResurrectionReserve"] = false,
			["masterLootEnabled"] = true,
			["requirements"] = {
				[1] = {
					["className"] = "paladin",
					["count"] = 1,
					["label"] = "Paladin - Protection (Tank)",
					["specKey"] = "prot",
				},
				[2] = {
					["className"] = "priest",
					["count"] = 1,
					["label"] = "Priest - Discipline (Heal)",
					["specKey"] = "disc",
				},
				[3] = {
					["className"] = "shaman",
					["count"] = 1,
					["label"] = "Shaman - Enhancement (DPS)",
					["specKey"] = "enh",
				},
			},
			["resurrectionReserveCount"] = 0,
			["savedAt"] = "2026-09-07",
			["schemaVersion"] = 2,
			["source"] = "ТЕСТ: игрок-ретрик + прот-паладин + ДЦ-прист + энх-шаман; победа не подтверждена",
			["startMessage"] = "ЛОВУШКИ: включи эффекты, выходи из опасных зон. ЗИМА: внешний обод; СОТРЯСЕНИЕ: внутрь. ВАЛЬ'КИРЫ: общий фокус отмеченной цели всеми ботами; в героике до 50% HP, затем следующая. Состав пока тестовый.",
			["storageMode"] = "class-spec",
		},
		["10n"] = {
			["autoGuideOnTargetEnabled"] = false,
			["autoStrategyEnabled"] = true,
			["guideText"] = "[Подготовка]\nТестовый состав: игрок + Protection Paladin + Holy Paladin + Marksmanship Hunter. Победа этим составом пока не подтверждена. Включи графические эффекты и проецируемые текстуры, чтобы видеть ловушки.\n\n[Переход]\nНа Беспощадности зимы выйди на внешний обод, убивай ледяные сферы и духов. На Сотрясении немедленно вернись внутрь платформы. Автостратегия временно снимает общий avoid aoe, оставляя ICC, и затем возвращает исходные флаги.\n\n[Валь'киры]\nОбщий фокус всех доступных ботов на одну отмеченную валь'киру. На героике достаточно опустить её до 50% HP, затем переключиться на следующую. На обычном режиме — убить. Держи опасную валь'киру видимой через свою цель или цели группы; без метки автофокус ждёт ICC. Не стой у края перед захватом. При Осквернении выходи из опасной зоны.\n\n[Проверка]\nВ чате появляется «общий фокус ВСЕХ ботов», затем подтверждения фактического урона. Команда фокуса не отключает лечение хилера и не гарантирует переопределение серверного AI.",
			["includeResurrectionReserve"] = false,
			["masterLootEnabled"] = true,
			["requirements"] = {
				[1] = {
					["className"] = "paladin",
					["count"] = 1,
					["label"] = "Paladin - Protection (Tank)",
					["specKey"] = "prot",
				},
				[2] = {
					["className"] = "priest",
					["count"] = 1,
					["label"] = "Priest - Discipline (Heal)",
					["specKey"] = "disc",
				},
				[3] = {
					["className"] = "shaman",
					["count"] = 1,
					["label"] = "Shaman - Enhancement (DPS)",
					["specKey"] = "enh",
				},
			},
			["resurrectionReserveCount"] = 0,
			["savedAt"] = "2026-09-07",
			["schemaVersion"] = 2,
			["source"] = "ТЕСТ: игрок-ретрик + прот-паладин + ДЦ-прист + энх-шаман; победа не подтверждена",
			["startMessage"] = "ЛОВУШКИ: включи эффекты, выходи из опасных зон. ЗИМА: внешний обод; СОТРЯСЕНИЕ: внутрь. ВАЛЬ'КИРЫ: общий фокус отмеченной цели всеми ботами; в героике до 50% HP, затем следующая. Состав пока тестовый.",
			["storageMode"] = "class-spec",
		},
		["25h"] = {
			["autoGuideOnTargetEnabled"] = true,
			["autoStrategyEnabled"] = true,
			["guideText"] = "[Соло]\nПроще всего проходить соло, если хватает DPS и собственного лечения. Соло-килл 25 гер. подтверждён. Групповой состав не меняем: используем сохранённый состав с Protection Paladin, Holy Paladin и тремя Marksmanship Hunter.\n\n[Первые две фазы — ступеньки]\nНа этом сервере проверена позиция на ступеньках: голова персонажа примерно на уровне головы Артаса. До перехода на 40% стой там, не перемещаясь. По наблюдению игрока, сферы с этой позиции не выбивают, шаркающие ужасы не добираются, а ловушки остаются ниже ступенек и не срабатывают на персонаже.\n\n[Сферы — абсолютный приоритет]\nЛедяные сферы, которые присылает Лич, уничтожаются раньше любых других целей: оставшаяся сфера может выбросить игрока с арены. Не пытайся форсировать пропуск фаз ценой сферы. Три ханта должны переключаться на сферы по адресным приказам UnBot; после подтверждения уничтожения возвращаются к основной цели.\n\n[Вторая фаза — Лич и адды]\nОсновной фокус — Лич. При появлении призванных им аддов временно переключай ДД на них, добивай аддов и сразу возвращай фокус на Лича. Сферы всегда прерывают этот цикл и остаются целью №1. На переходе можно проверить вариант с отключением тактик, но это только тест: безопасность пропуска 2-й и 3-й фаз пока не подтверждена.\n\n[Жатва душ — не возвращайся на ступеньки]\nНа третьей фазе держись на уровне основной платформы. При захвате души во Фростморн персонажа принудительно поднимает. Если стоять выше Артаса на ступеньках, наблюдался провал вниз под платформу вместо подъёма. Связь с высотой — рабочее объяснение серверного сбоя; обход проверен в соло-килле.\n\n[Фростморн и выход]\nВнутри Фростморна старайся максимально отхилиться и подготовиться к выходу. Сразу после возвращения проверь землю под собой: Артас может положить Осквернение прямо под персонажа. Немедленно выходи из лужи; третья фаза требует запаса здоровья и самохила.",
			["guideUpdatedAt"] = "2026-09-09",
			["includeResurrectionReserve"] = false,
			["masterLootEnabled"] = true,
			["requirements"] = {},
			["resurrectionReserveCount"] = 0,
			["savedAt"] = "2026-09-08 12:24:17",
			["schemaVersion"] = 2,
			["source"] = "Соло подтверждено; сохранён пользовательский тестовый состав: прот-пал + холи-пал + 3 ханта.",
			["startMessage"] = "25 ГЕР: оставь прот-пала, холи-пала и 3 ханта. СФЕРЫ — абсолютный приоритет, иначе игрока может выбросить с арены. Во 2-й фазе фокус Лича с переключением на его аддов; после убийства аддов сразу обратно на Лича.",
			["startMessageUpdatedAt"] = "2026-09-09",
			["storageMode"] = "class-spec",
		},
		["25n"] = {
			["autoGuideOnTargetEnabled"] = false,
			["autoStrategyEnabled"] = true,
			["guideText"] = "[Соло]\nПроще всего проходить соло, если хватает DPS и собственного лечения. Соло-килл 25 гер. подтверждён. Групповые составы 25 норм. и 25 гер. не подтверждены: оба пресета оставлены пустыми, состав с ботами придётся подбирать самостоятельно.\n\n[Первые две фазы — ступеньки]\nНа этом сервере проверена позиция на ступеньках: голова персонажа примерно на уровне головы Артаса. До перехода на 40% стой там, не перемещаясь. По наблюдению игрока, сферы с этой позиции не выбивают, шаркающие ужасы не добираются, а ловушки остаются ниже ступенек и не срабатывают на персонаже.\n\n[40% — подготовка к третьей фазе]\nК концу второй Беспощадности зимы срочно добей оставшихся аддов. Как только зима заканчивается и Артас начинает бежать к тебе, немедленно спускайся со ступенек на основную платформу. Дальше весь бой проводи на платформе: одновременно выживать под боссом и недобитыми аддами гораздо тяжелее.\n\n[Жатва душ — не возвращайся на ступеньки]\nНа третьей фазе держись на уровне основной платформы. При захвате души во Фростморн персонажа принудительно поднимает. Если стоять выше Артаса на ступеньках, наблюдался провал вниз под платформу вместо подъёма. Связь с высотой — рабочее объяснение серверного сбоя; обход проверен в соло-килле.\n\n[Фростморн и выход]\nВнутри Фростморна старайся максимально отхилиться и подготовиться к выходу. Сразу после возвращения проверь землю под собой: Артас может положить Осквернение прямо под персонажа. Немедленно выходи из лужи; третья фаза требует запаса здоровья и самохила.",
			["guideUpdatedAt"] = "2026-09-08",
			["includeResurrectionReserve"] = false,
			["masterLootEnabled"] = true,
			["requirements"] = {},
			["resurrectionReserveCount"] = 0,
			["savedAt"] = "2026-09-07",
			["schemaVersion"] = 2,
			["source"] = "Соло: при достаточном DPS и самохиле. Групповой состав не подтверждён",
			["startMessage"] = "ПРОЩЕ СОЛО, если хватает DPS и самохила. Групповой пресет не подтверждён — состав подбирай самостоятельно. ДО 40%: стой на ступеньках, голова примерно на уровне головы Артаса. К КОНЦУ ВТОРОЙ ЗИМЫ добей аддов. Артас побежал к тебе — СРОЧНО НА ПЛАТФОРМУ и больше не возвращайся на ступеньки: жатва души может увести под пол. ВО ФРОСТМОРНЕ отхились перед выходом; после выхода сразу проверь лужу под ногами.",
			["startMessageUpdatedAt"] = "2026-09-08",
			["storageMode"] = "class-spec",
		},
	},
	["the_ruby_sanctum__halion"] = {
		["10h"] = {
			["autoGuideOnTargetEnabled"] = false,
			["autoStrategyEnabled"] = true,
			["guideText"] = "[Состав]\nИгрок + два Retribution Paladin.\n\n[Автостратегия]\nПосле сборки и баффов при включённой Автостратегии отправляется co -rs. Это отключение серверной боевой стратегии Рубинового святилища; поведение ботов в порталах нужно проверить в бою.",
			["includeResurrectionReserve"] = false,
			["masterLootEnabled"] = true,
			["requirements"] = {
				[1] = {
					["className"] = "paladin",
					["count"] = 2,
					["label"] = "Paladin - Retribution (DPS)",
					["specKey"] = "ret",
				},
			},
			["resurrectionReserveCount"] = 0,
			["savedAt"] = "2026-09-08",
			["schemaVersion"] = 2,
			["source"] = "Халион: игрок + два ретри-паладина; co -rs",
			["startMessage"] = "Халион: игрок + два ретри-паладина. Автостратегия после сборки отправляет co -rs; проверь переход ботов в портал.",
			["storageMode"] = "class-spec",
		},
		["10n"] = {
			["autoGuideOnTargetEnabled"] = false,
			["autoStrategyEnabled"] = true,
			["guideText"] = "[Состав]\nИгрок + два Retribution Paladin.\n\n[Автостратегия]\nПосле сборки и баффов при включённой Автостратегии отправляется co -rs. Это отключение серверной боевой стратегии Рубинового святилища; поведение ботов в порталах нужно проверить в бою.",
			["includeResurrectionReserve"] = false,
			["masterLootEnabled"] = true,
			["requirements"] = {
				[1] = {
					["className"] = "paladin",
					["count"] = 2,
					["label"] = "Paladin - Retribution (DPS)",
					["specKey"] = "ret",
				},
			},
			["resurrectionReserveCount"] = 0,
			["savedAt"] = "2026-09-08",
			["schemaVersion"] = 2,
			["source"] = "Халион: игрок + два ретри-паладина; co -rs",
			["startMessage"] = "Халион: игрок + два ретри-паладина. Автостратегия после сборки отправляет co -rs; проверь переход ботов в портал.",
			["storageMode"] = "class-spec",
		},
		["25h"] = {
			["autoGuideOnTargetEnabled"] = false,
			["autoStrategyEnabled"] = true,
			["guideText"] = "[Состав]\nИгрок + два Retribution Paladin.\n\n[Автостратегия]\nПосле сборки и баффов при включённой Автостратегии отправляется co -rs. Это отключение серверной боевой стратегии Рубинового святилища; поведение ботов в порталах нужно проверить в бою.",
			["includeResurrectionReserve"] = false,
			["masterLootEnabled"] = true,
			["requirements"] = {
				[1] = {
					["className"] = "paladin",
					["count"] = 2,
					["label"] = "Paladin - Retribution (DPS)",
					["specKey"] = "ret",
				},
			},
			["resurrectionReserveCount"] = 0,
			["savedAt"] = "2026-09-08",
			["schemaVersion"] = 2,
			["source"] = "Халион: игрок + два ретри-паладина; co -rs",
			["startMessage"] = "Халион: игрок + два ретри-паладина. Автостратегия после сборки отправляет co -rs; проверь переход ботов в портал.",
			["storageMode"] = "class-spec",
		},
		["25n"] = {
			["autoGuideOnTargetEnabled"] = false,
			["autoStrategyEnabled"] = true,
			["guideText"] = "[Состав]\nИгрок + два Retribution Paladin.\n\n[Автостратегия]\nПосле сборки и баффов при включённой Автостратегии отправляется co -rs. Это отключение серверной боевой стратегии Рубинового святилища; поведение ботов в порталах нужно проверить в бою.",
			["includeResurrectionReserve"] = false,
			["masterLootEnabled"] = true,
			["requirements"] = {
				[1] = {
					["className"] = "paladin",
					["count"] = 2,
					["label"] = "Paladin - Retribution (DPS)",
					["specKey"] = "ret",
				},
			},
			["resurrectionReserveCount"] = 0,
			["savedAt"] = "2026-09-08",
			["schemaVersion"] = 2,
			["source"] = "Халион: игрок + два ретри-паладина; co -rs",
			["startMessage"] = "Халион: игрок + два ретри-паладина. Автостратегия после сборки отправляет co -rs; проверь переход ботов в портал.",
			["storageMode"] = "class-spec",
		},
	},
	["temple_of_ahn_qiraj__princess_huhuran"] = {
		["40n"] = {
			["autoGuideOnTargetEnabled"] = false,
			["autoStrategyEnabled"] = false,
			["guideText"] = "[Состав]\nИгрок + 34 бота: 2 танка, 6 лекарей, 2 Marksmanship Hunter и 24 других ДД. Основа — попытка 03.10.2026, где у босса осталось 2,4% HP. Двух ДД-воинов заменяют охотники без увеличения размера группы.\n\n[Перед пулом]\nДля фазы 30% держите устойчивую к природе ближнюю группу ближе к Хухуран, чем лекарей и дальних ДД. Ядовитый удар поражает ближайшие цели. Проверьте природное сопротивление и защитные способности этих бойцов; один лишь состав сопротивление не выдаёт.\n\n[Исступление]\nУ охотников проверьте изученный Усмиряющий выстрел и фактическое снятие Исступления (26051). В предыдущем бою охотников не было, три Исступления прошли полностью. Берсерк (26068) начинается около 30% HP; сохраните основной урон и защитные способности к этому моменту.\n\n[Укус виверны]\nНе снимайте Укус виверны (26180) без крайней необходимости: снятие вызывает дополнительный урон (26233). В прошлом логе боты несколько раз снимали его, и цель сразу получала урон. Этот пресет не отключает серверное автоочищение — проверьте поведение в бою.",
			["includeResurrectionReserve"] = false,
			["masterLootEnabled"] = true,
			["requirements"] = {
				{className="paladin", specKey="prot", label="Paladin - Protection (Tank)", count=1},
				{className="warrior", specKey="prot", label="Warrior - Protection (Tank)", count=1},
				{className="paladin", specKey="holy", label="Paladin - Holy (Heal)", count=2},
				{className="priest", specKey="holy", label="Priest - Holy (Heal)", count=1},
				{className="priest", specKey="disc", label="Priest - Discipline (Heal)", count=1},
				{className="druid", specKey="resto", label="Druid - Restoration (Heal)", count=1},
				{className="shaman", specKey="resto", label="Shaman - Restoration (Heal)", count=1},
				{className="hunter", specKey="mm", label="Hunter - Marksmanship (DPS)", count=2},
				{className="rogue", specKey="combat", label="Rogue - Combat (DPS)", count=9},
				{className="warrior", specKey="arms", label="Warrior - Arms (DPS)", count=3},
				{className="warrior", specKey="fury", label="Warrior - Fury (DPS)", count=3},
				{className="dk", specKey="frost", label="Death Knight - Frost (DPS)", count=2},
				{className="mage", specKey="frost", label="Mage - Frost (DPS)", count=7},
			},
			["resurrectionReserveCount"] = 0,
			["savedAt"] = "2026-10-03",
			["schemaVersion"] = 3,
			["source"] = "Хухуран: почти победный состав 34 ботов; 2 ДД-воина заменены на 2 охотников для снятия Исступления; убийство не подтверждено",
			["startMessage"] = "Хухуран: проверь у двух охотников Усмиряющий выстрел. К 30% подготовь природное сопротивление ближней группы, защитные способности и основной урон. Снятие Укуса виверны наносит дополнительный урон.",
			["storageMode"] = "class-spec",
		},
	},
	["temple_of_ahn_qiraj__viscidus"] = {
		["40n"] = {
			["autoGuideOnTargetEnabled"] = false,
			["autoStrategyEnabled"] = true,
			["includeResurrectionReserve"] = false,
			["masterLootEnabled"] = true,
			["requirements"] = {
				[1] = {
					["className"] = "paladin",
					["count"] = 1,
					["label"] = "|cFFF58CBAPaladin|r - Protection (Tank)",
					["specKey"] = "prot",
				},
				[2] = {
					["className"] = "dk",
					["count"] = 1,
					["label"] = "|cFFC41F3BDeath Knight|r - Blood (Tank)",
					["specKey"] = "blood",
				},
				[3] = {
					["className"] = "paladin",
					["count"] = 3,
					["label"] = "|cFFF58CBAPaladin|r - Holy (Heal)",
					["specKey"] = "holy",
				},
				[4] = {
					["className"] = "shaman",
					["count"] = 3,
					["label"] = "|cFF0070DEShaman|r - Restoration (Heal)",
					["specKey"] = "resto",
				},
				[5] = {
					["className"] = "druid",
					["count"] = 2,
					["label"] = "|cFFFF7D0ADruid|r - Restoration (Heal)",
					["specKey"] = "resto",
				},
				[6] = {
					["className"] = "dk",
					["count"] = 1,
					["label"] = "|cFFC41F3BDeath Knight|r - Frost (DPS)",
					["specKey"] = "frost",
				},
				[7] = {
					["className"] = "rogue",
					["count"] = 20,
					["label"] = "|cFFFFF569Rogue|r - Combat (DPS)",
					["specKey"] = "combat",
				},
				[8] = {
					["className"] = "mage",
					["count"] = 5,
					["label"] = "|cFF69CCF0Mage|r - Frost (DPS)",
					["specKey"] = "frost",
				},
			},
			["resurrectionReserveCount"] = 0,
			["savedAt"] = "2026-10-03",
			["schemaVersion"] = 3,
			["source"] = "Нечистотон: танки, лекари и быстрые удары для разбивания; убийство пока не подтверждено",
			["startMessage"] = "На фазе капель автостратегия временно даёт ДД собственный выбор целей. Танк и лекари сохраняют роли. Следите за ядом под ногами и массовым уроном.",
			["storageMode"] = "class-spec",
		},
	},
	["valithria_dreamwalker"] = {
		["10n"] = {
			["autoGuideOnTargetEnabled"] = false,
			["autoStrategyEnabled"] = true,
			["includeResurrectionReserve"] = false,
			["masterLootEnabled"] = true,
			["requirements"] = {
				[1] = {
					["className"] = "dk",
					["count"] = 2,
					["label"] = "|cFFC41F3BDeath Knight|r - Blood (Tank)",
					["specKey"] = "blood",
				},
				[2] = {
					["className"] = "paladin",
					["count"] = 2,
					["label"] = "|cFFF58CBAPaladin|r - Holy (Heal)",
					["specKey"] = "holy",
				},
				[3] = {
					["className"] = "priest",
					["count"] = 1,
					["label"] = "|cFFFFFFFFPriest|r - Discipline (Heal)",
					["specKey"] = "disc",
				},
				[4] = {
					["className"] = "druid",
					["count"] = 1,
					["label"] = "|cFFFF7D0ADruid|r - Restoration (Heal)",
					["specKey"] = "resto",
				},
				[5] = {
					["className"] = "mage",
					["count"] = 3,
					["label"] = "|cFF69CCF0Mage|r - Frost (DPS)",
					["specKey"] = "frost",
				},
			},
			["resurrectionReserveCount"] = 0,
			["savedAt"] = "2026-07-27",
			["schemaVersion"] = 2,
			["source"] = "successful Valithria composition",
			["storageMode"] = "class-spec",
		},
		["25h"] = {
			["autoGuideOnTargetEnabled"] = false,
			["autoStrategyEnabled"] = true,
			["guideText"] = "[Общее]\nПеред пулом расставьте стороны командой /ubvalithria layout. Левый и правый отряды принимают аддов со своей стороны, хилеры стоят в центре у хвоста Валитрии.\n\n[Бой]\nИгрок держится в центре у хвоста Валитрии и помогает убивать аддов, которых танки приводят со своих сторон. Не уводите весь рейд к одному краю.\n\n[Поганище]\nПосле смерти Прожорливого поганища танки получают цель на личинок. Не стойте в месте выброса и дайте танкам несколько секунд собрать агро.\n[Приоритет]\nИсторгающий пламя скелет — немедленный фокус, не дать закончить Разгром. Затем Волдырный зомби, Подавитель, Воскрешенный верховный маг и Прожорливое поганище.\n\n[Агро]\nЧереп — левый фланг, крест — правый. Для зомби и поганища сначала получает команду танк; ДД ждут минимум 2,4 секунды и фактический урон или таунт назначенного танка. Без подтверждения они остаются удержанными. Остальные опасные цели фокусятся без задержки.\n\n[Личинки]\nПосле смерти поганища танк его стороны собирает личинок по треугольнику. Через 2,4 секунды ДД этого фланга получают ту же цель и временный AoE; через 10 секунд AoE выключается. Новая опасная адресная цель отменяет AoE раньше.\n[Строгий захват]\nМежду адресными целями ДД удерживаются без dps/attack force/ICC. На Волдырного зомби и Прожорливое поганище они выходят только после фактического урона или таунта назначенного танка; один выбор цели и истечение таймера больше не считаются захватом.\n\n[После портала]\nХилер, вышедший из Dream State с неполным здоровьем, до трёх раз лечит себя быстрым классовым заклинанием. Адресный Holy Light в Валитрию возобновляется после восстановления минимум 85% здоровья или завершения конечного окна самопомощи.",
			["guideUpdatedAt"] = "2026-08-08",
			["includeResurrectionReserve"] = true,
			["masterLootEnabled"] = true,
			["requirements"] = {
				[1] = {
					["className"] = "druid",
					["count"] = 2,
					["label"] = "|cFFFF7D0ADruid|r - Restoration (Heal)",
					["specKey"] = "resto",
				},
				[2] = {
					["className"] = "paladin",
					["count"] = 1,
					["label"] = "|cFFF58CBAPaladin|r - Retribution (DPS)",
					["specKey"] = "ret",
				},
			},
			["resurrectionReserveCount"] = 1,
			["savedAt"] = "2026-08-25 16:24:29",
			["schemaVersion"] = 2,
			["source"] = "saved class/spec requirements from current group/raid",
			["startMessage"] = "МАКСИМАЛЬНО БЫСТРО ЗАЧИЩАЙ АДДОВ. Друиды сами вылечат Валитрию. Игрок хилом не занимается: при угрозе жизни используй защитные способности и продолжай зачистку.",
			["startMessageUpdatedAt"] = "2026-08-29",
			["storageMode"] = "class-spec",
		},
		["25h18"] = {
			["autoGuideOnTargetEnabled"] = false,
			["autoStrategyEnabled"] = true,
			["guideText"] = "[Общее]\nТестовый вариант подтверждённого малого килла 25 гер: Frost Mage заменён на бота Retribution; итог — игрок Retribution, бот Retribution и два Restoration Druid. Слот использует нативную ICC-стратегию без танков, RTSC-расстановки и строгого допуска ДД.\n\n[Бой]\nОба Retribution убивают аддов. Игрок в первую очередь снимает Подавителей, затем Исторгающих пламя скелетов, Волдырных зомби, Воскрешенных верховных магов и Прожорливых поганищ с личинками.\n\n[Хилеры]\nНе отключайте хилерам ICC: сервер сам распределяет одного друида на Валитрию и порталы, второго — на поддержку группы. Ручной /ubvalithria и /ubvalithria layout для этого состава не требуются.\n\n[Разгром]\nПо возможности прерывайте Разгром скелета. Второй мили-ДД не тратит время на кайт аддов и должен помогать удерживать темп зачистки.",
			["guideUpdatedAt"] = "2026-08-25 20:09:33",
			["includeResurrectionReserve"] = true,
			["masterLootEnabled"] = true,
			["requirements"] = {
				[1] = {
					["className"] = "druid",
					["count"] = 2,
					["label"] = "|cFFFF7D0ADruid|r - Restoration (Heal)",
					["specKey"] = "resto",
				},
				[2] = {
					["className"] = "paladin",
					["count"] = 1,
					["label"] = "|cFFF58CBAPaladin|r - Retribution (DPS)",
					["specKey"] = "ret",
				},
			},
			["resurrectionReserveCount"] = 1,
			["savedAt"] = "2026-08-29 16:08:49",
			["schemaVersion"] = 2,
			["source"] = "saved class/spec requirements from current group/raid",
			["startMessage"] = "МАКСИМАЛЬНО БЫСТРО ЗАЧИЩАЙ АДДОВ. Друиды сами вылечат Валитрию. Игрок хилом не занимается: при угрозе жизни используй защитные способности и продолжай зачистку.",
			["startMessageUpdatedAt"] = "2026-08-29",
			["storageMode"] = "class-spec",
		},
		["25n"] = {
			["autoGuideOnTargetEnabled"] = false,
			["autoStrategyEnabled"] = true,
			["includeResurrectionReserve"] = false,
			["masterLootEnabled"] = true,
			["requirements"] = {
				[1] = {
					["className"] = "dk",
					["count"] = 1,
					["label"] = "|cFFC41F3BDeath Knight|r - Blood (Tank)",
					["specKey"] = "blood",
				},
				[10] = {
					["className"] = "warlock",
					["count"] = 2,
					["label"] = "|cFF9482C9Warlock|r - Demonology (DPS)",
					["specKey"] = "demo",
				},
				[11] = {
					["className"] = "warrior",
					["count"] = 2,
					["label"] = "|cFFC79C6EWarrior|r - Fury (DPS)",
					["specKey"] = "fury",
				},
				[12] = {
					["className"] = "dk",
					["count"] = 1,
					["label"] = "|cFFC41F3BDeath Knight|r - Unholy (DPS)",
					["specKey"] = "unholy",
				},
				[13] = {
					["className"] = "priest",
					["count"] = 1,
					["label"] = "|cFFFFFFFFPriest|r - Shadow (DPS)",
					["specKey"] = "shadow",
				},
				[2] = {
					["className"] = "paladin",
					["count"] = 1,
					["label"] = "|cFFF58CBAPaladin|r - Protection (Tank)",
					["specKey"] = "prot",
				},
				[3] = {
					["className"] = "paladin",
					["count"] = 2,
					["label"] = "|cFFF58CBAPaladin|r - Holy (Heal)",
					["specKey"] = "holy",
				},
				[4] = {
					["className"] = "druid",
					["count"] = 2,
					["label"] = "|cFFFF7D0ADruid|r - Restoration (Heal)",
					["specKey"] = "resto",
				},
				[5] = {
					["className"] = "priest",
					["count"] = 1,
					["label"] = "|cFFFFFFFFPriest|r - Holy (Heal)",
					["specKey"] = "holy",
				},
				[6] = {
					["className"] = "shaman",
					["count"] = 1,
					["label"] = "|cFF0070DEShaman|r - Restoration (Heal)",
					["specKey"] = "resto",
				},
				[7] = {
					["className"] = "mage",
					["count"] = 4,
					["label"] = "|cFF69CCF0Mage|r - Frost (DPS)",
					["specKey"] = "frost",
				},
				[8] = {
					["className"] = "hunter",
					["count"] = 3,
					["label"] = "|cFFABD473Hunter|r - Marksmanship (DPS)",
					["specKey"] = "mm",
				},
				[9] = {
					["className"] = "rogue",
					["count"] = 3,
					["label"] = "|cFFFFF569Rogue|r - Combat (DPS)",
					["specKey"] = "combat",
				},
			},
			["resurrectionReserveCount"] = 0,
			["savedAt"] = "2026-08-04",
			["schemaVersion"] = 2,
			["source"] = "recommended full Valithria 25 normal: player Retribution + 2 tanks + 6 healers + 16 bot DPS",
			["startMessage"] = "МАКСИМАЛЬНО БЫСТРО ЗАЧИЩАЙ АДДОВ. Друиды сами вылечат Валитрию. Игрок хилом не занимается: при угрозе жизни используй защитные способности и продолжай зачистку.",
			["startMessageUpdatedAt"] = "2026-08-29",
			["storageMode"] = "class-spec",
		},
	},
};
-- END GENERATED AUTHOR PRESETS

function UnBotAuthorPresets.Copy(value)
	if type(value) ~= "table" then return value; end
	local copy = {};
	for key, item in pairs(value) do copy[key] = UnBotAuthorPresets.Copy(item); end
	return copy;
end

function UnBotAuthorPresets.Equal(a, b)
	if type(a) ~= type(b) then return false; end
	if type(a) ~= "table" then return a == b; end
	for key, value in pairs(a) do
		if not UnBotAuthorPresets.Equal(value, b[key]) then return false; end
	end
	for key in pairs(b) do if a[key] == nil then return false; end end
	return true;
end

function UnBotAuthorPresets.Get(bossKey, modeKey)
	local modes = UnBotAuthorPresets.defaults[bossKey];
	return modes and modes[modeKey];
end

function UnBotAuthorPresets.State(config, bossKey, modeKey)
	config.bossPresetAuthorState = config.bossPresetAuthorState or {};
	local states = config.bossPresetAuthorState;
	states[bossKey] = states[bossKey] or {};
	states[bossKey][modeKey] = states[bossKey][modeKey] or {};
	return states[bossKey][modeKey];
end

function UnBotAuthorPresets.MarkPersonal(config, bossKey, modeKey)
	local state = UnBotAuthorPresets.State(config, bossKey, modeKey);
	state.kind = "personal";
	-- Retain the last baseline and any unknown metadata for future migrations.
end

function UnBotAuthorPresets.ApplyDefault(config, bossKey, modeKey)
	local preset = UnBotAuthorPresets.Get(bossKey, modeKey);
	config.bossPresets[bossKey] = config.bossPresets[bossKey] or {};
	config.bossPresets[bossKey][modeKey] = UnBotAuthorPresets.Copy(preset);
	local state = UnBotAuthorPresets.State(config, bossKey, modeKey);
	state.kind = preset and "author" or "personal";
	if preset then
		state.baseline = UnBotAuthorPresets.Copy(preset);
		state.version = UnBotAuthorPresets.version;
	end
	return preset ~= nil;
end

function UnBotAuthorPresets.KeepWinningTwins(config)
 if config.twinWinningPresetRevision==1 then return; end
 local boss="temple_of_ahn_qiraj__the_twin_emperors";
 for _,field in ipairs({"bossPresets","bossPresetBackups","bossPresetAuthorState"}) do
  local modes=config[field] and config[field][boss];
  if type(modes)=="table" then
   for key,value in pairs(modes) do
    if key~="40n5" and type(value)=="table" and (key=="40n" or key=="40n6" or value.requirements or value.slots or field=="bossPresetAuthorState" and value.kind) then modes[key]=nil; end
   end
  end
 end
 local winner=config.bossPresets and config.bossPresets[boss] and config.bossPresets[boss]["40n5"];
 if winner and winner.validatedKill==nil then winner.validatedKill=UnBotAuthorPresets.Copy(UnBotAuthorPresets.defaults[boss]["40n5"].validatedKill); end
 config.twinWinningPresetRevision=1;
end

function UnBotAuthorPresets.Sync(config)
	if UnBotAuthorPresets.syncedConfig == config then return; end
	config.bossPresets = config.bossPresets or {};
	for bossKey, modes in pairs(UnBotAuthorPresets.defaults) do
		for modeKey in pairs(modes) do
			local current = config.bossPresets[bossKey] and config.bossPresets[bossKey][modeKey];
			local state = UnBotAuthorPresets.State(config, bossKey, modeKey);
			if current == nil and state.kind == nil then
				UnBotAuthorPresets.ApplyDefault(config, bossKey, modeKey);
			elseif state.kind == "author" and UnBotAuthorPresets.Equal(current, state.baseline) then
				UnBotAuthorPresets.ApplyDefault(config, bossKey, modeKey);
			else
				-- Old SavedVariables have no ownership marker: keep every existing
				-- preset, including empty/solo presets and unknown fields, as personal.
				UnBotAuthorPresets.MarkPersonal(config, bossKey, modeKey);
			end
		end
	end
	UnBotAuthorPresets.KeepWinningTwins(config);
	UnBotAuthorPresets.syncedConfig = config;
end

function UnBotAuthorPresets.IsStandard(config, bossKey, modeKey)
	local state = config.bossPresetAuthorState and config.bossPresetAuthorState[bossKey];
	state = state and state[modeKey];
	local current = config.bossPresets[bossKey] and config.bossPresets[bossKey][modeKey];
	return state and state.kind == "author" and UnBotAuthorPresets.Equal(current, state.baseline);
end

function UnBotAuthorPresets.StorePersonal(config, bossKey, modeKey, values, previous)
	local preset = UnBotAuthorPresets.Copy(previous or {});
	for key, value in pairs(values) do preset[key] = UnBotAuthorPresets.Copy(value); end
	-- Keep legacy readers consistent without retaining an obsolete composition.
	if preset.slots ~= nil then preset.slots = UnBotAuthorPresets.Copy(preset.requirements); end
	config.bossPresets[bossKey] = config.bossPresets[bossKey] or {};
	config.bossPresets[bossKey][modeKey] = preset;
	UnBotAuthorPresets.MarkPersonal(config, bossKey, modeKey);
	return preset;
end

function UnBotAuthorPresets.BuiltinGet(bossKey, modeKey)
	local preset = UnBotAuthorPresets.Get(bossKey, modeKey);
	if not preset then return nil; end
	return UnBotAuthorPresets.Copy(preset.requirements or {}), preset.source,
		preset.resurrectionReserveCount, preset.guideText, preset.startMessage;
end

-- The sole Twin preset keeps the validated 6.38.213 combat behavior.
UnBotAuthorPresets.version = 17;
do
 local boss="temple_of_ahn_qiraj__the_twin_emperors";
 local p={autoGuideOnTargetEnabled=false,autoStrategyEnabled=true,includeResurrectionReserve=false,masterLootEnabled=true,resurrectionReserveCount=0,schemaVersion=2,storageMode="class-spec"};
 p.requirements={
  {className="paladin",specKey="prot",label="Paladin - Protection (Tank)",count=1},
  {className="priest",specKey="disc",label="Priest - Discipline (Heal)",count=1},
 };
 p.savedAt="2026-10-12";
 p.source="Близнецы: победа 12.10.2026 — игрок + Protection Paladin + Discipline Priest";
 p.startMessage="№3: игрок берёт Череп (Век'нилаш), единственный пал-танк — Звезду (Век'лор). /ubtwins tanks -> Подготовить -> выдели Веклора -> Паладин: атаковать Веклора. Затем возьми Векнилаша и оттаскивай его от брата. Хил остаётся в радиусе лечения паладина. После телепорта снова перехвати Череп.";
 p.guideText="[Состав №3]\nИгрок, один бот Protection Paladin и один хил Discipline Priest. ДД и резерва в этом пресете нет. Победа подтверждена 12.10.2026: Yrelia + Benard + Bahhun, 12 минут 32 секунды, без смертей. Сложность 40 с AutoBalance для малого состава. В победном логе есть 182 события Исцеления брата. Через 17,5 секунды после пула паладину отправлено passive/stay при неподтверждённом захвате; автоматического go не было. Сохранено фактическое поведение победной версии 6.38.213, а не доказательство непрерывного автоотвода.\n\n[Роли и подготовка]\nИгрок удерживает Век'нилаша (Череп), паладин — Век'лора (Звезда). Подготовка запускается отдельной кнопкой в /ubtwins tanks: только паладину отключаются копирование цели игрока и следование; личный профиль не изменяется. Читаются co/nc, отправляются только отличия и однократно проверяется применение. Нужны ровно два онлайн-бота: один Protection Paladin и один хил. Для хила проверяются co -passive,-stay,+heal и nc -passive; его прочие стратегии и личный профиль сохраняются. Хилу не назначается цель босса, атака или отвод. Перед пулом держи его в радиусе лечения паладина; движение к цели лечения выполняет серверный AI.\n\n[Пул]\nВыдели Веклора и нажми «Паладин: атаковать Веклора». Команда do attack my target отправляется сразу по выбранному Веклору. Затем сам выбери Векнилаша, набери агро и отводи его. Пустой cdebug не блокирует запуск.\n\n[Отвод]\nПри доступной карте DBM бот пробует шаги по 25 ярдов от игрока: до 4 за фазу, до 120 за бой, 15 минут. Направление проверяется по координатам рейда, мировая точка — через debug position. Ответ принимается из WHISPER или ADDON. Нет координат или нет движения — отвод приостанавливается, атака сохраняется; игрок продолжает отводить физического босса. Веклор может кастовать с места, поэтому шаг бота не доказывает движение босса.\n\n[Телепорт]\nРоли остаются привязаны к боссам: паладин возвращает Веклора, игрок сам перехватывает Векнилаша. На фазу не более 3 команд захвата. При отказе попытки прекращаются, паладину отправляется удержание; контроллер остаётся доступен, повтор только кнопкой после ручного выбора Веклора.\n\n[Завершение]\nПосле смерти обоих близнецов и выхода из боя отправляется reset botAI. «Стандартные стратегии» выполняет эту же команду вне боя. «Стоп», ошибка, reload и принудительный вайп не возвращают стратегии. «Принудительный вайп» останавливает контроллеры и один раз отправляет серверную команду wipe группе/рейду: управляемые боты погибают, игрок останавливается сам. Пакет passive/stay больше не отправляется. После воскрешения флаг вайпа снимается вручную через reset botAI.";
 p.validatedKill={["confirmedAt"]="2026-10-12 00:58:03",["recordId"]="1791755131:98029539:0xF130003BAB000098",["duration"]=751.6,["groupSize"]=3,["characters"]={"Yrelia","Benard","Bahhun"},["deaths"]=0,["bossMaxHealth"]=124563,["healBrotherEvents"]=182,["controllerVersion"]="6.38.213",["controllerHeldTankAtMs"]=53231,["confirmation"]="BossMemory combat-log death + player confirmed victory"};
 UnBotAuthorPresets.defaults[boss]={ ["40n5"]=p };
end

-- Explicit experimental Gluth composition, requested 18.10.2026; no validated kill.
UnBotAuthorPresets.version = 27;
do
 local p={autoGuideOnTargetEnabled=false,autoStrategyEnabled=false,includeResurrectionReserve=false,masterLootEnabled=true,resurrectionReserveCount=0,schemaVersion=3,storageMode="class-spec"};
 p.requirements={
  {className="paladin",specKey="prot",label="Paladin - Protection (Tank)",count=1},
  {className="hunter",specKey="mm",label="Hunter - Marksmanship (DPS)",count=3},
  {className="priest",specKey="disc",label="Priest - Discipline (Heal)",count=1},
 };
 p.savedAt="2026-10-18";p.source="Проба Глута: 1 Protection Paladin + 3 MM Hunter + 1 Discipline Priest; результат в игре ещё не подтверждён";
 p.startMessage="Проба: пал-танк у двери, 3 MM-ханта на зомби, Disc-хил. После призыва появится маленькая панель: встань у двери → Поставить танка. Затем Включить 3 хантов: RTI зомби. После reload панель открывается через /ubguard quick. Звезда зарезервирована для зомби. Глут исключается другой меткой, сервер сам ищет зомби; игрок может продолжать бить босса.";
 p.guideText="[Пробный состав]\nИгрок + 1 Protection Paladin + 3 Marksmanship Hunter + 1 Discipline Priest. Без дополнительного офлайн-резерва. Это эксперимент, убийство этим составом не подтверждено.\n\n[Дверь]\nПри призыве пресета автоматически открывается маленькая панель. В бою игрок сам встаёт у двери и жмёт Поставить танка. Паладин выбирается по подтверждённому назначению Protection в текущем составе, цель игрока менять не нужно. Прямые naxx off → summon+stay → якорь без чтения или сохранения стратегий. После холодного reload: /ubguard quick. Полное окно /ubguard тоже доступно. Дождаться записи поста. Прежний stay-якорь и ограниченный контроль сохранены. Постановка по прежнему явно снимает naxx всему текущему рейду, включая хила.\n\n[Охотники]\nНа маленькой панели кнопка Включить 3 хантов: RTI зомби берёт трёх подтверждённых MM-охотников из состава пресета. Для ручных назначений остаётся /ubguard hunters и кнопка в окне постов. Только им: co -naxx,-mark rti,-dps assist,-attack weak,-passive,-aoe,-stay; nc -naxx,-mark rti,-stay,-aggressive,-grind. Эти команды отключают конкурирующие выбор цели/автометки и удержание на месте; классовые стратегии урона сохраняются. Проверка каждого раздела однократная через ,?, затем rti star с подтверждением. Личные профили не переписываются.\n\n[Фокус]\nЗвезда предназначена для Zombie Chow / Закуска зомби (обычный NPC16360 и наблюдаемый серверный351069). Доступная клиенту цель отмечается сразу. Если зомби ещё никто не выбрал, сначала Глут получает другую метку (сохраняется существующая, либо Череп), затем первому охотнику do mark rti: сервер выбирает непомеченного атакующего. rti ? должен подтвердить star и точное имя зомби; иной моб → стоп до атаки. Первому охотнику одна attack rti target; после подтверждения GUID зомби в его цели остальные двое получают ту же звезду. Игроку не требуется выбирать зомби или наводить курсор. Нужна доступная цель Глута у игрока/группы для безопасного исключения босса. После смерти — следующий зомби. Пустой подтверждённый список проверяется раз6с, до80запросов за10мин; событие призыва ускоряет следующий поиск. Отказ/нет ответа/неподтверждённая метка/захват → стоп без спама. Касты для поиска и protected выбор цели игрока не используются. Фокус не гарантирует достаточный урон/убийство; серверный путь до отдельного игрового подтверждения считается экспериментальным.\n\n[Границы]\nДо10мин/60целей/180команд атаки; конец боя/смерть или офлайн охотника/другая зона/операция → стоп. После reload назначения сохранены, режим включается вручную. Стоп оставляет серверные настройки; для выбранного бота штатная кнопка Снять пост выделенного: сброс ИИ. Хил лечит штатно, режим охотников не командует ему и танку. Окна открываются и после reload прямо в бою.";
 UnBotAuthorPresets.defaults["naxxramas__gluth"]={ ["40n"]=UnBotAuthorPresets.Copy(p),["10n"]=p,["25n"]=UnBotAuthorPresets.Copy(p) };
end

-- Separate full raid trial: 39 bots + player; preserve the existing small variant.
do
 local p={autoGuideOnTargetEnabled=false,autoStrategyEnabled=false,includeResurrectionReserve=false,masterLootEnabled=true,resurrectionReserveCount=0,schemaVersion=3,storageMode="class-spec"};
 p.requirements={
  {className="paladin",specKey="prot",label="Paladin - Protection (Tank)",count=4},
  {className="hunter",specKey="mm",label="Hunter - Marksmanship (DPS)",count=3},
  {className="paladin",specKey="holy",label="Paladin - Holy (Heal)",count=2},
  {className="priest",specKey="disc",label="Priest - Discipline (Heal)",count=2},
  {className="shaman",specKey="resto",label="Shaman - Restoration (Heal)",count=2},
  {className="druid",specKey="resto",label="Druid - Restoration (Heal)",count=2},
  {className="mage",specKey="fire",label="Mage - Fire (DPS)",count=6},
  {className="warlock",specKey="affli",label="Warlock - Affliction (DPS)",count=6},
  {className="priest",specKey="shadow",label="Priest - Shadow (DPS)",count=4},
  {className="rogue",specKey="combat",label="Rogue - Combat (DPS)",count=4},
  {className="warrior",specKey="fury",label="Warrior - Fury (DPS)",count=4},
 };
 p.savedAt="2026-10-18";p.source="Глут40: полный рейд, 4 Protection Paladin, 8 хилов, 27 ДД + игрок; проба без подтверждённого убийства";
 p.startMessage="Полный рейд: игрок + 39 ботов. При запуске призыва UnBot снимает naxx в co и nc у текущей группы и один раз у каждого входящего бота. /ubguard quick показывает четыре кнопки; каждая отправляет выбранному танку только summon и stay.";
 p.guideText="[Состав]\n40 участников вместе с игроком: 4 Protection Paladin, 8 хилов и 27 ДД. Офлайн-резерва нет. Отдельный экспериментальный вариант; старый малый состав сохранён.\n\n[Отключение naxx]\nПри запуске призыва Глута текущей группе отправляются co -naxx и nc -naxx. Каждый новый бот получает обе команды один раз после появления в ростере. Нет опроса стратегий, ожидания ответа или повторного спама. Наблюдатель действует только в рамках этого конечного squad-призыва.\n\n[Четыре танка]\n/ubguard quick показывает четыре одинаковые кнопки. Встаньте в нужной точке и нажмите кнопку нужного танка. Кнопка немедленно отправляет только summon, затем stay. Нет автоматического Освящения, co/nc, cdebug, position stay, чтения стратегий, подтверждения прибытия или повтора.\n\n[Почему снимаются оба набора]\nСвежий debug после summon+stay показал gluth position с приоритетом61, который уводит танка к средней решётке. Проверка co ? не показала naxx, но nc ? показала активный naxx. Поэтому на старте призыва снимаются оба варианта: co -naxx и nc -naxx.\n\n[Бой]\nВ попытке15:13–15:20 из128зомби рейд добил13, а115 умерли от Глута; это до575% его максимального здоровья лечением. Убийство после изменения ещё не подтверждено.";
 UnBotAuthorPresets.defaults["naxxramas__gluth"]["40n_full"]=p;
end

-- Client-side Gluth intercept trial: explicitly named paladin roles, manual hard posts and one central healer.
do
 local p={autoGuideOnTargetEnabled=false,autoStrategyEnabled=false,includeResurrectionReserve=false,masterLootEnabled=true,resurrectionReserveCount=0,schemaVersion=3,storageMode="class-spec"};
 p.requirements={
  {className="paladin",specKey="prot",label="Paladin - Protection (Tank)",count=4},
  {className="priest",specKey="disc",label="Priest - Discipline (Heal)",count=1},
 };
 p.savedAt="2026-10-18";p.source="Глут40: ручной именной перехват — 4 Protection Paladin на независимых жёстких постах, 1 Discipline Priest в центре + игрок";
 p.startMessage="Глут40 — перехват: откройте /ubguard quick. Для каждой роли выделите конкретного Protection Paladin и нажмите «Имя». Затем встаньте на его пост и нажмите «Поставить». Для двери держите Глута в цели до подтверждения закрепления.";
 p.guideText="[Состав]\nРовно 5 ботов + игрок: 4 Protection Paladin и 1 Discipline Priest. Других хилов и ДД нет. Имена назначаются игроком заново в каждом явном запуске: выделите одного из четырёх живых протопаладинов и нажмите «Имя» в строке роли. Одно имя нельзя назначить дважды. Назначения переживают /reload текущего запуска, но не переносятся в новый состав.\n\n[Ручная расстановка]\nИгрок встаёт на нужное место и нажимает «Поставить» у назначенного имени. Аддон один раз читает co/nc, сохраняет только управляемые ключи, включает боевой stay, снимает follow/formation/автовыбор и другие причины преследования, затем делает summon, position stay set и cdebug position. Три перехватчика получают passive и не выбирают цель сами; прямое Освящение продолжает работать. Дверной паладин остаётся боевым tank, но закреплён stay.\n\n[Дверь]\nПосле вайпа у двери выделите Глута, нажмите «Поставить» в первой строке и не меняйте цель до сообщения «закреплён». Только после фиксации дверной паладин получает do attack my target и начинает набирать угрозу с места. Пока он держит босса, игрок вручную ставит остальных паладинов у решёток.\n\n[АоЕ и страх]\nКаждому поставленному паладину включаются Праведная ярость и конечный прямой цикл cast consecration on <имя>: максимум 10 минут/120 команд, отказ или молчание 7 секунд — стоп. После снятия Ужасающего рева допускаются не более двух возвратов на сохранённый XYZ; каждый возврат состоит из position stay, go и stay. Обычного бесконечного контроля движения нет.\n\n[Хил и завершение]\nВстаньте между постами и нажмите «Поставить Disc-хила здесь». При отмене сценария аддон останавливает АоЕ, отправляет follow и последовательно восстанавливает только те co/nc-ключи, которые сам изменил. Личные профили и другие боты не затрагиваются. Окно доступно прямо в бою, включая после холодного /reload.";
 UnBotAuthorPresets.defaults["naxxramas__gluth"]["40n_intercept"]=p;
end

-- Two-squad corridor tactic reported as a successful kill by the quoted guide author.
do
 local p={autoGuideOnTargetEnabled=false,autoStrategyEnabled=false,includeResurrectionReserve=false,masterLootEnabled=true,resurrectionReserveCount=0,schemaVersion=3,storageMode="class-spec"};
 p.requirements={
  {className="druid",specKey="bear",label="Druid - Feral Bear (Tank)",count=1},
  {className="shaman",specKey="resto",label="Shaman - Restoration (Heal)",count=1},
  {className="warrior",specKey="fury",label="Warrior - Fury (DPS)",count=1},
  {className="rogue",specKey="combat",label="Rogue - Combat (DPS)",count=1},
  {className="warlock",specKey="affli",label="Warlock - Affliction (DPS)",count=1},
  {className="paladin",specKey="prot",label="Paladin - Protection (Tank)",count=1},
  {className="mage",specKey="fire",label="Mage - Fire (DPS)",count=1},
  {className="priest",specKey="disc",label="Priest - Discipline (Heal)",count=1},
 };
 p.savedAt="2026-10-19";p.source="Глут40: коридорная тактика из сообщения пользователя; автор сообщения подтвердил убийство, на этом клиенте пресет ещё не проверен";
 p.startMessage="Глут — коридор: 8 ботов + игрок-хант. После полного сбора UnBot сам раскладывает подгруппы: 1 — медведь, resto-шаман, fury-вар, combat-рога, affli-лок; 2 — игрок, prot-пал, fire-маг, Disc. Панель /ubguard quick: две кнопки призыва групп, каждая сразу отправляет co/nc -naxx. Кнопка группы 1 подставляет /maintank медведя — подтвердите Enter, если он ещё не назначен главным танком. Затем всем stay.";
 p.guideText="[Состав]\nИгрок должен быть на охотнике. Пресет призывает 8 ботов. Группа 1 на Глута: Feral Bear, Restoration Shaman, Fury Warrior, Combat Rogue и Affliction Warlock. Группа 2 на зомби: игрок-охотник, Protection Paladin, Fire Mage и Discipline Priest. В обеих группах есть танк и хил. Специализации ДД выбраны как конкретный вариант для сборщика; при необходимости их можно заменить в личной копии пресета.\n\n[После сбора]\nПри запуске призыва UnBot сразу снимает naxx в co и nc у текущего рейда; каждый входящий бот получает обе команды один раз. После полного сбора автоматически раскладывает пять ботов босса в группу 1, а игрока и трёх ботов зомби — в группу 2. Нужны права лидера/помощника. В /ubguard quick доступны две кнопки призыва и кнопка повторной раскладки. Перед призывом аддон проверяет фактические подгруппы. Если медведь ещё не назначен главным танком, кнопка группы 1 подставляет /maintank ИмяМедведя: нажмите Enter. Это защищённое действие клиента; выбор цели не требуется. Затем остановите ботов командой stay. Личные профили не переписываются.\n\n[Расстановка]\nПроще проводить бой в проходе между комнатами Глута и Таддиуса. После открытия двери, пробежки и контролируемого вайпа дождитесь полного сброса Глута, воскресните и поставьте обе группы у двери Таддиуса. Группа 1 остаётся там и принимает босса.\n\n[Пул]\nОхотником возьмите Глута в цель командой /target Gluth и сагрите питомцем сквозь закрытую дверь. Отведите босса к группе 1 у двери Таддиуса. Когда группа 1 приняла Глута, бегите на мост у двери Глута и вызовите туда группу 2 её кнопкой в /ubguard quick. Если группу 1 нужно вернуть к точке босса, используйте кнопку группы 1. Они пишут в рейд @group1 summon и @group2 summon соответственно; сразу после summon отправляются co -naxx и nc -naxx всему рейду.\n\n[Зомби]\nГруппа 2 держит мост: Protection Paladin собирает идущих зомби Освящением, Discipline Priest лечит, Fire Mage помогает массовым уроном после топота/призыва, игрок непрерывно накрывает поток Градом стрел. Цель — убивать зомби до того, как они дойдут до Глута и отхилят его.\n\n[Границы]\nПанель открывается в бою и после холодного reload в бою. Повторное открытие не запускает команды; раскладку после изменения ростера можно повторить отдельной кнопкой. Раскладка ограничена 30 секундами и одной отправкой на имя, отсутствие подтверждения 5 секунд завершает её. Посторонние участники групп 1/2 и офлайн-резерв не перемещаются. RTI, сохранённые XYZ, автоматические лужи и фоновый контроль движения не используются. Старые режимы Глута не изменены. Убийство подтверждено только автором переданной тактики; результат этого пресета на текущем составе ещё нужно проверить в игре.";
 UnBotAuthorPresets.defaults["naxxramas__gluth"]["40n_corridor"]=p;
end

-- 6.39.67: legacy Gluth modes keep their old controls; intercept owns its named manual placement flow.
for _,p in pairs(UnBotAuthorPresets.defaults["naxxramas__gluth"] or {}) do
  if p==UnBotAuthorPresets.defaults["naxxramas__gluth"]["40n_intercept"] or p==UnBotAuthorPresets.defaults["naxxramas__gluth"]["40n_corridor"] then
   -- This mode has its own complete guide and one-button deployment contract above.
  elseif p==UnBotAuthorPresets.defaults["naxxramas__gluth"]["40n_full"] then
   p.startMessage="Глут40: при призыве всем снимаются co/nc naxx. /ubguard quick даёт четыре кнопки; каждая отправляет танку только summon и stay. Луж, cdebug, ожиданий и повторов нет.";
 else
   p.startMessage="Глут: при призыве всем снимаются co/nc naxx. /ubguard quick: постановка танка — ровно summon и stay. АоЕ — отдельный прямой каст под себя с учётом реального GCD.";
 end
 if p~=UnBotAuthorPresets.defaults["naxxramas__gluth"]["40n_full"] and p~=UnBotAuthorPresets.defaults["naxxramas__gluth"]["40n_intercept"] and p~=UnBotAuthorPresets.defaults["naxxramas__gluth"]["40n_corridor"] then
   p.guideText="[Танк, 6.39.63]\nКнопка постановки немедленно отправляет только summon и stay. Нет cdebug, co/nc, чтения стратегий, подтверждения прибытия и повторов. Кнопка АоЕ отдельно отправляет прямой cast consecration/blood boil on <имя>; реальные успешные касты и GCD сдвигают следующий запрос. Отказ или молчание7с — стоп без спама. После reload повтор включается вручную.\n\n[Охотники]\nОтдельная кнопка RTI3хантов сохранена; она не запускается вместе с танком. Групповой -naxx остаётся только ручной кнопкой.\n\n[Проверка]\nОкна открываются в бою и после reload. Каст в чате не доказывает агро: успех — SPELL_DAMAGE Освящения по зомби и затем удары зомби по перехватчику. Убийство ещё не подтверждено.";
 end
end
