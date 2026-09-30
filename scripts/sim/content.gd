extends RefCounted
## Data tables for the government layer. Every item lists "mods": effects merged by World.mods_of().
##
## Multiplicative mods (default 1.0): gold, growth, cap, capture, defense, tech_cost, build_cost,
##   attack_rate, ship_speed, naval_reach, nuke_cost, decree_cost
## Additive mods (default 0.0): approval (target), salary (gold/s drain), interest (army growth rate),
##   gold_flat (gold/s), unrest (threshold shift), election (approval bonus at elections),
##   diplomacy (bots need a bigger edge to attack you), shield (extra bunker radius)

const MOD_MULT := ["gold", "growth", "cap", "capture", "defense", "tech_cost", "build_cost", "attack_rate", "ship_speed", "naval_reach", "nuke_cost", "decree_cost"]
const MOD_ADD := ["approval", "salary", "interest", "gold_flat", "unrest", "election", "diplomacy", "shield"]

# ---------------------------------------------------------------- parties (Duma)
const PARTIES := {
	"order": {"name": "Партия порядка", "color": "#F98BA9", "bonus": "+8% роста армии", "who": "казармы, защита, войны, бомбы", "mods": {"growth": 1.08}},
	"trade": {"name": "Торговый союз", "color": "#F4D77A", "bonus": "+10% золота", "who": "рынки, порты, налоги, торговля", "mods": {"gold": 1.10}},
	"people": {"name": "Народный фронт", "color": "#B7C96A", "bonus": "+6 к цели одобрения", "who": "низкие налоги, довольный народ", "mods": {"approval": 6.0}},
	"tech": {"name": "Технократы", "color": "#7FB9E6", "bonus": "−15% к цене технологий", "who": "технологии и города", "mods": {"tech_cost": 0.85}},
	"green": {"name": "Зелёные", "color": "#8FD3A0", "bonus": "+4 одобрение, стройки на 10% дешевле", "who": "мир без бомб, фермы, больницы", "mods": {"approval": 4.0, "build_cost": 0.9}},
	"empire": {"name": "Имперцы", "color": "#D6BEEA", "bonus": "захват на 8% дешевле", "who": "большая территория, войны, флот", "mods": {"capture": 0.92, "approval": -2.0}},
}
const PARTY_ORDER := ["order", "trade", "people", "tech", "green", "empire"]

# ---------------------------------------------------------------- ministers (fee once, salary per second)
const MINISTERS := {
	"finance": {"name": "Министр финансов", "desc": "+15% золота", "fee": 3000, "salary": 6.0, "mods": {"gold": 1.15}},
	"general": {"name": "Генерал", "desc": "Фронт продвигается на 20% быстрее", "fee": 4000, "salary": 8.0, "mods": {"attack_rate": 1.20}},
	"diplomat": {"name": "Дипломат", "desc": "Боты нападают на вас заметно реже", "fee": 3500, "salary": 6.0, "mods": {"diplomacy": 1.0}},
	"scientist": {"name": "Учёный", "desc": "Технологии на 20% дешевле", "fee": 3500, "salary": 5.0, "mods": {"tech_cost": 0.80}},
	"propagandist": {"name": "Пропагандист", "desc": "+8 к цели одобрения", "fee": 2500, "salary": 5.0, "mods": {"approval": 8.0}},
	"economist": {"name": "Министр экономики", "desc": "Постройки на 15% дешевле", "fee": 3000, "salary": 5.0, "mods": {"build_cost": 0.85}},
	"defense": {"name": "Министр обороны", "desc": "Ваши клетки на 15% дороже врагу", "fee": 4000, "salary": 7.0, "mods": {"defense": 1.15}},
	"admiral": {"name": "Адмирал", "desc": "Корабли на 30% быстрее и дальше", "fee": 3500, "salary": 6.0, "mods": {"ship_speed": 1.3, "naval_reach": 1.3}},
	"culture": {"name": "Министр культуры", "desc": "+5 одобрение, −3% золота", "fee": 2500, "salary": 4.0, "mods": {"approval": 5.0, "gold": 0.97}},
	"treasurer": {"name": "Казначей", "desc": "+8 золота в секунду", "fee": 2000, "salary": 3.0, "mods": {"gold_flat": 8.0}},
	"labor": {"name": "Министр труда", "desc": "+0.2% роста армии в секунду", "fee": 3000, "salary": 5.0, "mods": {"interest": 0.002}},
	"spy": {"name": "Шеф разведки", "desc": "Захват чужого на 6% дешевле, +2 к защите", "fee": 4500, "salary": 7.0, "mods": {"capture": 0.94, "defense": 1.02}},
	"speaker": {"name": "Спикер Госдумы", "desc": "+6 одобрение на выборах", "fee": 3000, "salary": 4.0, "mods": {"election": 6.0}},
	"premier": {"name": "Премьер-министр", "desc": "+4% ко всему: золото, рост, лимит", "fee": 8000, "salary": 14.0, "mods": {"gold": 1.04, "growth": 1.04, "cap": 1.04}},
}
const MINISTER_ORDER := ["finance", "general", "diplomat", "scientist", "propagandist", "economist", "defense", "admiral", "culture", "treasurer", "labor", "spy", "speaker", "premier"]

# ---------------------------------------------------------------- bills (need BILL_MAJORITY seats among supporting parties)
const BILLS := {
	"army_reform": {"name": "Военная реформа", "desc": "+10% к лимиту армии", "cost": 5000, "support": ["order", "tech"], "mods": {"cap": 1.10}},
	"free_trade": {"name": "Свободная торговля", "desc": "+10% золота", "cost": 5000, "support": ["trade", "tech"], "mods": {"gold": 1.10}},
	"social": {"name": "Социальный пакет", "desc": "+8 к цели одобрения, −5% золота", "cost": 4000, "support": ["people", "trade"], "mods": {"approval": 8.0, "gold": 0.95}},
	"science": {"name": "Наука в приоритете", "desc": "−20% к цене технологий", "cost": 4000, "support": ["tech", "people"], "mods": {"tech_cost": 0.80}},
	"emergency": {"name": "Чрезвычайное положение", "desc": "+20% роста армии, −10 к цели одобрения", "cost": 6000, "support": ["order", "empire"], "mods": {"growth": 1.20, "approval": -10.0}},
	"luxury_tax": {"name": "Налог на роскошь", "desc": "+6% золота, −2 одобрение", "cost": 3000, "support": ["people", "trade"], "mods": {"gold": 1.06, "approval": -2.0}},
	"no_duties": {"name": "Отмена пошлин", "desc": "+4 одобрение, −5% золота", "cost": 2500, "support": ["trade", "people"], "mods": {"approval": 4.0, "gold": 0.95}},
	"conscription": {"name": "Всеобщая воинская обязанность", "desc": "+0.4% роста армии в секунду, −6 одобрение", "cost": 5000, "support": ["order", "empire"], "mods": {"interest": 0.004, "approval": -6.0}},
	"pro_army": {"name": "Профессиональная армия", "desc": "+12% к лимиту, −4% золота", "cost": 5500, "support": ["order", "tech"], "mods": {"cap": 1.12, "gold": 0.96}},
	"resettlement": {"name": "Программа переселения", "desc": "+6% роста армии", "cost": 4000, "support": ["empire", "people"], "mods": {"growth": 1.06}},
	"free_medicine": {"name": "Бесплатная медицина", "desc": "+6 одобрение, −6% золота", "cost": 4500, "support": ["people", "green"], "mods": {"approval": 6.0, "gold": 0.94}},
	"pensions": {"name": "Пенсионная реформа", "desc": "+5 одобрение, −5% золота", "cost": 4000, "support": ["people", "trade"], "mods": {"approval": 5.0, "gold": 0.95}},
	"eight_hours": {"name": "Восьмичасовой рабочий день", "desc": "+4 одобрение, −3% роста", "cost": 3000, "support": ["people", "green"], "mods": {"approval": 4.0, "growth": 0.97}},
	"universities": {"name": "Университеты", "desc": "−10% к цене технологий, +2 одобрение", "cost": 4500, "support": ["tech", "green"], "mods": {"tech_cost": 0.90, "approval": 2.0}},
	"navy_program": {"name": "Флотская программа", "desc": "Корабли на 25% быстрее", "cost": 4000, "support": ["empire", "trade"], "mods": {"ship_speed": 1.25}},
	"coast_defense": {"name": "Береговая оборона", "desc": "Ваши клетки на 10% дороже врагу", "cost": 4500, "support": ["order", "green"], "mods": {"defense": 1.10}},
	"border_forts": {"name": "Крепости на границе", "desc": "+15% к защите, −3% золота", "cost": 6000, "support": ["order", "empire"], "mods": {"defense": 1.15, "gold": 0.97}},
	"diplomacy_corps": {"name": "Дипломатический корпус", "desc": "Боты нападают реже", "cost": 5000, "support": ["trade", "green"], "mods": {"diplomacy": 0.6}},
	"prohibition": {"name": "Сухой закон", "desc": "+3% роста армии, −5 одобрение", "cost": 2500, "support": ["order", "tech"], "mods": {"growth": 1.03, "approval": -5.0}},
	"free_speech": {"name": "Свобода слова", "desc": "+3 одобрение, волнения начинаются позже", "cost": 3000, "support": ["people", "green"], "mods": {"approval": 3.0, "unrest": -5.0}},
	"land_reform": {"name": "Земельная реформа", "desc": "Захват любой земли на 8% дешевле", "cost": 5500, "support": ["empire", "people"], "mods": {"capture": 0.92}},
	"logistics_corps": {"name": "Логистический корпус", "desc": "Фронт продвигается на 10% быстрее", "cost": 4500, "support": ["order", "trade"], "mods": {"attack_rate": 1.10}},
	"disarmament": {"name": "Ядерное разоружение", "desc": "Бомбы вдвое дороже, +6 одобрение", "cost": 3000, "support": ["green", "people"], "mods": {"nuke_cost": 2.0, "approval": 6.0}},
	"nuclear_shield": {"name": "Ядерный щит", "desc": "Бункеры сбивают бомбы на 8 клеток дальше", "cost": 6000, "support": ["order", "tech"], "mods": {"shield": 8.0}},
	"cheap_decrees": {"name": "Реформа канцелярии", "desc": "Указы на 30% дешевле", "cost": 3000, "support": ["tech", "trade"], "mods": {"decree_cost": 0.7}},
	"public_works": {"name": "Общественные работы", "desc": "Постройки на 10% дешевле", "cost": 4000, "support": ["people", "tech"], "mods": {"build_cost": 0.90}},
	"green_deal": {"name": "Зелёный курс", "desc": "+5 одобрение, −2% роста армии", "cost": 3500, "support": ["green", "people"], "mods": {"approval": 5.0, "growth": 0.98}},
	"imperial_edict": {"name": "Имперский эдикт", "desc": "Захват чужого на 10% дешевле, −4 одобрение", "cost": 6500, "support": ["empire", "order"], "mods": {"capture": 0.90, "approval": -4.0}},
	"bank_reform": {"name": "Банковская реформа", "desc": "+5 золота в секунду, +3% золота", "cost": 4500, "support": ["trade", "tech"], "mods": {"gold_flat": 5.0, "gold": 1.03}},
	"election_reform": {"name": "Избирательная реформа", "desc": "+5 одобрение на выборах", "cost": 3500, "support": ["people", "tech"], "mods": {"election": 5.0}},
}
const BILL_ORDER := ["free_trade", "luxury_tax", "no_duties", "bank_reform", "public_works", "cheap_decrees",
	"army_reform", "pro_army", "conscription", "emergency", "logistics_corps", "border_forts", "coast_defense", "nuclear_shield",
	"social", "free_medicine", "pensions", "eight_hours", "free_speech", "election_reform", "green_deal", "prohibition",
	"science", "universities", "navy_program", "diplomacy_corps", "disarmament", "land_reform", "resettlement", "imperial_edict"]

# ---------------------------------------------------------------- extra buildings (the eight cards stay; these live in the government panel)
const BUILDINGS := {
	"farm": {"name": "Ферма", "desc": "+6 золота в секунду, +1 одобрение", "cost": 2000, "coast": false, "mods": {"gold_flat": 6.0, "approval": 1.0}},
	"mine": {"name": "Шахта", "desc": "+12 золота в секунду, −1 одобрение", "cost": 3500, "coast": false, "mods": {"gold_flat": 12.0, "approval": -1.0}},
	"university": {"name": "Университет", "desc": "Технологии на 8% дешевле, +0.1% роста", "cost": 4500, "coast": false, "mods": {"tech_cost": 0.92, "interest": 0.001}},
	"shipyard": {"name": "Верфь", "desc": "Корабли на 20% быстрее и дальше (на берегу)", "cost": 4000, "coast": true, "mods": {"ship_speed": 1.2, "naval_reach": 1.2}},
	"fortress": {"name": "Крепость", "desc": "Ваши клетки на 12% дороже врагу", "cost": 5000, "coast": false, "mods": {"defense": 1.12}},
	"hospital": {"name": "Больница", "desc": "+3 одобрение", "cost": 3000, "coast": false, "mods": {"approval": 3.0}},
	"temple": {"name": "Храм", "desc": "+4 одобрение, −2% роста армии", "cost": 2500, "coast": false, "mods": {"approval": 4.0, "growth": 0.98}},
	"bank": {"name": "Банк", "desc": "+5% золота", "cost": 5000, "coast": false, "mods": {"gold": 1.05}},
	"casino": {"name": "Казино", "desc": "+15 золота в секунду, −3 одобрение", "cost": 4000, "coast": false, "mods": {"gold_flat": 15.0, "approval": -3.0}},
	"stadium": {"name": "Стадион", "desc": "+5 одобрение", "cost": 6000, "coast": false, "mods": {"approval": 5.0}},
	"palace": {"name": "Дворец", "desc": "+3 одобрение, +4 на выборах", "cost": 7000, "coast": false, "mods": {"approval": 3.0, "election": 4.0}},
	"customs": {"name": "Таможня", "desc": "+4% золота (на берегу)", "cost": 3500, "coast": true, "mods": {"gold": 1.04}},
	"lab": {"name": "Лаборатория", "desc": "Технологии на 12% дешевле", "cost": 5500, "coast": false, "mods": {"tech_cost": 0.88}},
	"arsenal": {"name": "Арсенал", "desc": "+600 к лимиту армии", "cost": 3500, "coast": false, "mods": {"cap_flat": 600.0}},
	"hq": {"name": "Штаб", "desc": "Фронт продвигается на 10% быстрее", "cost": 5000, "coast": false, "mods": {"attack_rate": 1.10}},
	"radar": {"name": "Радар", "desc": "Бункеры сбивают бомбы на 6 клеток дальше", "cost": 4500, "coast": false, "mods": {"shield": 6.0}},
	"granary": {"name": "Амбар", "desc": "Волнения начинаются позже, +2 одобрение", "cost": 2500, "coast": false, "mods": {"unrest": -4.0, "approval": 2.0}},
	"embassy": {"name": "Посольство", "desc": "Боты нападают реже", "cost": 4000, "coast": false, "mods": {"diplomacy": 0.4}},
}
const BUILDING_ORDER := ["farm", "mine", "bank", "customs", "casino", "granary", "hospital", "temple", "stadium", "palace",
	"university", "lab", "arsenal", "hq", "fortress", "radar", "shipyard", "embassy"]

# ---------------------------------------------------------------- extra technologies (levels, costs; effects are mods per level)
const EXTRA_TECHS := {
	"irrigation": {"name": "Ирригация", "desc": "+4% роста армии за уровень", "max": 2, "costs": [3500, 7000], "req": "", "mods": {"growth": 1.04}},
	"banking": {"name": "Банковское дело", "desc": "+8% золота за уровень", "max": 2, "costs": [5000, 10000], "req": "trade", "mods": {"gold": 1.08}},
	"medicine": {"name": "Медицина", "desc": "+4 к цели одобрения за уровень", "max": 2, "costs": [4000, 8000], "req": "", "mods": {"approval": 4.0}},
	"artillery": {"name": "Артиллерия", "desc": "Захват чужого на 8% дешевле за уровень", "max": 2, "costs": [6000, 12000], "req": "tactics", "mods": {"capture": 0.92}},
	"railways": {"name": "Железные дороги", "desc": "Фронт на 12% быстрее за уровень", "max": 2, "costs": [5500, 11000], "req": "logistics", "mods": {"attack_rate": 1.12}},
	"electricity": {"name": "Электричество", "desc": "Постройки на 10% дешевле за уровень", "max": 2, "costs": [5000, 10000], "req": "", "mods": {"build_cost": 0.90}},
	"radio": {"name": "Радио", "desc": "+3 одобрение и +3 на выборах за уровень", "max": 2, "costs": [4500, 9000], "req": "", "mods": {"approval": 3.0, "election": 3.0}},
	"satellites": {"name": "Спутники", "desc": "Корабли и бомбы дальше и быстрее", "max": 1, "costs": [20000], "req": "rockets", "mods": {"naval_reach": 1.5, "ship_speed": 1.3}},
}
const EXTRA_TECH_ORDER := ["irrigation", "medicine", "electricity", "radio", "banking", "artillery", "railways", "satellites"]

# ---------------------------------------------------------------- budget (levels 0..3; cost per second scales with land)
const BUDGET := {
	"army": {"name": "Армия", "desc": "+0.25% роста армии в секунду за уровень", "mods": {"interest": 0.0025}},
	"science": {"name": "Наука", "desc": "Технологии на 6% дешевле за уровень", "mods": {"tech_cost": 0.94}},
	"social": {"name": "Народ", "desc": "+3 к цели одобрения за уровень", "mods": {"approval": 3.0}},
	"infrastructure": {"name": "Инфраструктура", "desc": "Постройки на 5% дешевле за уровень", "mods": {"build_cost": 0.95}},
}
const BUDGET_ORDER := ["army", "science", "social", "infrastructure"]
const BUDGET_COST_PER_CELL := 0.008      # gold per second per level per cell
const BUDGET_MAX := 3

# ---------------------------------------------------------------- extra decrees
const EXTRA_DECREES := {
	"amnesty": {"name": "Амнистия", "desc": "+10 одобрение, −8% войск", "cost": 0, "cooldown": 900, "approval": 10.0, "troops_share": -0.08},
	"requisition": {"name": "Реквизиция", "desc": "+3000 золота, −12 одобрение", "cost": 0, "cooldown": 900, "approval": -12.0, "gold": 3000.0},
	"parade": {"name": "Парад", "desc": "+6 одобрение", "cost": 1200, "cooldown": 600, "approval": 6.0},
}
const EXTRA_DECREE_ORDER := ["amnesty", "requisition", "parade"]

# ---------------------------------------------------------------- extra random events
const EXTRA_EVENTS := [
	{"title": "Открыто месторождение", "text": "Геологи нашли золото в горах.",
		"choices": [{"text": "Разрабатывать (+4000 золота, −4 одобрение)", "gold": 4000, "approval": -4},
			{"text": "Оставить природе (+5 одобрение)", "approval": 5}]},
	{"title": "Забастовка", "text": "Рабочие рынков требуют повышения оплаты.",
		"choices": [{"text": "Уступить (−2500 золота, +6 одобрение)", "gold": -2500, "approval": 6},
			{"text": "Разогнать (−9 одобрение)", "approval": -9}]},
	{"title": "Праздник урожая", "text": "Народ просит устроить гуляния.",
		"choices": [{"text": "Устроить (−1500 золота, +8 одобрение)", "gold": -1500, "approval": 8},
			{"text": "Отказать (−3 одобрение)", "approval": -3}]},
	{"title": "Дезертиры", "text": "Часть солдат бежит домой.",
		"choices": [{"text": "Простить (−6% войск, +3 одобрение)", "troops_share": -0.06, "approval": 3},
			{"text": "Наказать (−3% войск, −4 одобрение)", "troops_share": -0.03, "approval": -4}]},
	{"title": "Иностранный инвестор", "text": "Купец предлагает вложиться в ваши рынки.",
		"choices": [{"text": "Принять (+3000 золота, −2 одобрение)", "gold": 3000, "approval": -2},
			{"text": "Отказать (+2 одобрение)", "approval": 2}]},
	{"title": "Наводнение", "text": "Реки вышли из берегов.",
		"choices": [{"text": "Помочь пострадавшим (−3000 золота, +6 одобрение)", "gold": -3000, "approval": 6},
			{"text": "Не вмешиваться (−8 одобрение)", "approval": -8}]},
	{"title": "Изобретатель", "text": "Мастер предлагает чертежи за вознаграждение.",
		"choices": [{"text": "Купить (−3000 золота, технология +1)", "gold": -3000, "tech": 1},
			{"text": "Отказать", "approval": -1}]},
	{"title": "Коррупционный скандал", "text": "Министра поймали на взятках.",
		"choices": [{"text": "Отдать под суд (+7 одобрение, −1500 золота)", "gold": -1500, "approval": 7},
			{"text": "Замять (+1500 золота, −6 одобрение)", "gold": 1500, "approval": -6}]},
	{"title": "Добровольцы", "text": "Молодёжь просится в армию.",
		"choices": [{"text": "Принять всех (+10% войск, −2 одобрение)", "troops_share": 0.10, "approval": -2},
			{"text": "Только лучших (+4% войск, +2 одобрение)", "troops_share": 0.04, "approval": 2}]},
	{"title": "Ярмарка", "text": "Соседи предлагают торговую ярмарку.",
		"choices": [{"text": "Провести (+2500 золота, +2 одобрение)", "gold": 2500, "approval": 2},
			{"text": "Отказать (+1 одобрение)", "approval": 1}]},
	{"title": "Слухи о перевороте", "text": "Генералы недовольны.",
		"choices": [{"text": "Повысить жалование (−3500 золота, +4 одобрение)", "gold": -3500, "approval": 4},
			{"text": "Сместить генералов (−12% войск, +3 одобрение)", "troops_share": -0.12, "approval": 3}]},
	{"title": "Учёные требуют свободы", "text": "Академия просит снять цензуру.",
		"choices": [{"text": "Снять (+5 одобрение, налоги −1)", "approval": 5, "tax": -1},
			{"text": "Отказать (−3 одобрение)", "approval": -3}]},
]


static func merge_mods(target: Dictionary, mods: Dictionary, times: int = 1) -> void:
	for key in mods:
		var v = mods[key]
		if key in MOD_MULT:
			target[key] = target.get(key, 1.0) * pow(float(v), times)
		else:
			target[key] = target.get(key, 0.0) + float(v) * times


static func default_mods() -> Dictionary:
	var m := {}
	for key in MOD_MULT:
		m[key] = 1.0
	for key in MOD_ADD:
		m[key] = 0.0
	m["cap_flat"] = 0.0
	return m
