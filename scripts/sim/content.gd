extends RefCounted
## Data tables for the government layer. Every item lists "mods": effects merged by World.mods_of().
## Generated from tools/content_gen.py — edit the generator, not this file.
##
## Multiplicative mods (default 1.0): gold, growth, cap, capture, defense, tech_cost, build_cost,
##   attack_rate, ship_speed, naval_reach, nuke_cost, decree_cost, salary_mult, budget_cost, bill_cost,
##   project_speed, pact_cost
## Additive mods (default 0.0): approval (target), salary (gold/s drain), interest (army growth rate),
##   gold_flat (gold/s), unrest (threshold shift), election (approval bonus at elections),
##   diplomacy (bots need a bigger edge to attack you), shield (extra bunker radius), relation (bot attitude)

const MOD_MULT := ["gold", "growth", "cap", "capture", "defense", "tech_cost", "build_cost", "attack_rate", "ship_speed", "naval_reach", "nuke_cost", "decree_cost", "salary_mult", "budget_cost", "bill_cost", "project_speed", "pact_cost"]
const MOD_ADD := ["approval", "salary", "interest", "gold_flat", "unrest", "election", "diplomacy", "shield", "relation"]

const CATEGORIES := {"econ": "Экономика", "army": "Армия", "people": "Народ", "science": "Наука", "navy": "Флот", "state": "Государство", "empire": "Империя", "nature": "Природа"}
const CATEGORY_ORDER := ["econ", "army", "people", "science", "navy", "state", "empire", "nature"]

# ---------------------------------------------------------------- parties (Duma)
const PARTIES := {
	"order": {"name": "Партия порядка", "color": "#F98BA9", "bonus": "+8% роста армии", "who": "казармы, защита, войны, бомбы", "mods": {"growth": 1.08}},
	"trade": {"name": "Торговый союз", "color": "#F4D77A", "bonus": "+10% золота", "who": "рынки, порты, налоги, торговля", "mods": {"gold": 1.1}},
	"people": {"name": "Народный фронт", "color": "#B7C96A", "bonus": "+6 к цели одобрения", "who": "низкие налоги, довольный народ", "mods": {"approval": 6.0}},
	"tech": {"name": "Технократы", "color": "#7FB9E6", "bonus": "−15% к цене технологий", "who": "технологии и города", "mods": {"tech_cost": 0.85}},
	"green": {"name": "Зелёные", "color": "#8FD3A0", "bonus": "+4 одобрение, стройки на 10% дешевле", "who": "мир без бомб, фермы, больницы", "mods": {"approval": 4.0, "build_cost": 0.9}},
	"empire": {"name": "Имперцы", "color": "#D6BEEA", "bonus": "захват на 8% дешевле", "who": "большая территория, войны, флот", "mods": {"capture": 0.92, "approval": -2.0}},
}
const PARTY_ORDER := ["order", "trade", "people", "tech", "green", "empire"]

# ---------------------------------------------------------------- ministers (fee once, salary per second)
const MINISTERS := {
	"finance": {"name": "Министр финансов", "desc": "+15% золота", "fee": 3000, "salary": 6.0, "cat": "econ", "mods": {"gold": 1.15}},
	"general": {"name": "Генерал", "desc": "Фронт продвигается на 20% быстрее", "fee": 4000, "salary": 8.0, "cat": "army", "mods": {"attack_rate": 1.2}},
	"diplomat": {"name": "Дипломат", "desc": "Боты нападают на вас заметно реже", "fee": 3500, "salary": 6.0, "cat": "state", "mods": {"diplomacy": 1.0}},
	"scientist": {"name": "Учёный", "desc": "Технологии на 20% дешевле", "fee": 3500, "salary": 5.0, "cat": "science", "mods": {"tech_cost": 0.8}},
	"propagandist": {"name": "Пропагандист", "desc": "+8 к цели одобрения", "fee": 2500, "salary": 5.0, "cat": "people", "mods": {"approval": 8.0}},
	"economist": {"name": "Министр экономики", "desc": "Постройки на 15% дешевле", "fee": 3000, "salary": 5.0, "cat": "econ", "mods": {"build_cost": 0.85}},
	"defense": {"name": "Министр обороны", "desc": "Ваши клетки на 15% дороже врагу", "fee": 4000, "salary": 7.0, "cat": "army", "mods": {"defense": 1.15}},
	"admiral": {"name": "Адмирал", "desc": "Корабли на 30% быстрее и дальше", "fee": 3500, "salary": 6.0, "cat": "navy", "mods": {"ship_speed": 1.3, "naval_reach": 1.3}},
	"culture": {"name": "Министр культуры", "desc": "+5 одобрение, −3% золота", "fee": 2500, "salary": 4.0, "cat": "people", "mods": {"approval": 5.0, "gold": 0.97}},
	"treasurer": {"name": "Казначей", "desc": "+8 золота в секунду", "fee": 2000, "salary": 3.0, "cat": "econ", "mods": {"gold_flat": 8.0}},
	"labor": {"name": "Министр труда", "desc": "+0.2% роста армии в секунду", "fee": 3000, "salary": 5.0, "cat": "people", "mods": {"interest": 0.002}},
	"spy": {"name": "Шеф разведки", "desc": "Захват чужого на 6% дешевле, +2 к защите", "fee": 4500, "salary": 7.0, "cat": "army", "mods": {"capture": 0.94, "defense": 1.02}},
	"speaker": {"name": "Спикер Госдумы", "desc": "+6 одобрение на выборах", "fee": 3000, "salary": 4.0, "cat": "state", "mods": {"election": 6.0}},
	"premier": {"name": "Премьер-министр", "desc": "+4% ко всему: золото, рост, лимит", "fee": 8000, "salary": 14.0, "cat": "state", "mods": {"gold": 1.04, "growth": 1.04, "cap": 1.04}},
	"interior": {"name": "Министр внутренних дел", "desc": "Волнения начинаются на 8 пунктов позже, −2 одобрение", "fee": 3500, "salary": 6.0, "cat": "state", "mods": {"unrest": -8.0, "approval": -2.0}},
	"education": {"name": "Министр образования", "desc": "Технологии на 10% дешевле, +2 одобрение", "fee": 3000, "salary": 5.0, "cat": "science", "mods": {"tech_cost": 0.9, "approval": 2.0}},
	"health": {"name": "Министр здравоохранения", "desc": "+4 одобрение, +3% роста армии", "fee": 3000, "salary": 5.0, "cat": "people", "mods": {"approval": 4.0, "growth": 1.03}},
	"agriculture": {"name": "Министр сельского хозяйства", "desc": "+6 золота в секунду, +3% роста армии", "fee": 2500, "salary": 4.0, "cat": "econ", "mods": {"gold_flat": 6.0, "growth": 1.03}},
	"industry": {"name": "Министр промышленности", "desc": "Постройки на 10% дешевле, +4 золота в секунду", "fee": 3500, "salary": 6.0, "cat": "econ", "mods": {"build_cost": 0.9, "gold_flat": 4.0}},
	"transport": {"name": "Министр транспорта", "desc": "Фронт на 8% быстрее, корабли на 10% быстрее", "fee": 3500, "salary": 6.0, "cat": "econ", "mods": {"attack_rate": 1.08, "ship_speed": 1.1}},
	"trade_min": {"name": "Министр торговли", "desc": "+8% золота", "fee": 3000, "salary": 5.0, "cat": "econ", "mods": {"gold": 1.08}},
	"colonies_min": {"name": "Министр колоний", "desc": "Захват на 5% дешевле, корабли на 15% дальше", "fee": 4500, "salary": 7.0, "cat": "empire", "mods": {"capture": 0.95, "naval_reach": 1.15}},
	"justice": {"name": "Министр юстиции", "desc": "Волнения позже, законы на 10% дешевле", "fee": 3000, "salary": 5.0, "cat": "state", "mods": {"unrest": -4.0, "bill_cost": 0.9}},
	"chief_of_staff": {"name": "Начальник Генштаба", "desc": "Фронт на 10% быстрее, +5% к лимиту армии", "fee": 5000, "salary": 9.0, "cat": "army", "mods": {"attack_rate": 1.1, "cap": 1.05}},
	"quartermaster": {"name": "Квартирмейстер", "desc": "+8% к лимиту армии", "fee": 3500, "salary": 6.0, "cat": "army", "mods": {"cap": 1.08}},
	"astrologer": {"name": "Придворный астролог", "desc": "+3 одобрение на выборах, +1 одобрение", "fee": 1500, "salary": 2.0, "cat": "state", "mods": {"election": 3.0, "approval": 1.0}},
	"chancellor": {"name": "Канцлер", "desc": "Указы на 30% и законы на 15% дешевле", "fee": 5000, "salary": 8.0, "cat": "state", "mods": {"decree_cost": 0.7, "bill_cost": 0.85}},
	"energy": {"name": "Министр энергетики", "desc": "+10 золота в секунду, постройки на 5% дешевле", "fee": 4500, "salary": 7.0, "cat": "econ", "mods": {"gold_flat": 10.0, "build_cost": 0.95}},
	"foreign": {"name": "Министр иностранных дел", "desc": "Отношения со всеми +10, пакты на 30% дешевле", "fee": 4000, "salary": 6.0, "cat": "state", "mods": {"diplomacy": 0.8, "relation": 10.0, "pact_cost": 0.7}},
	"sports_min": {"name": "Министр спорта", "desc": "+3 одобрение, +2% роста армии", "fee": 2500, "salary": 4.0, "cat": "people", "mods": {"approval": 3.0, "growth": 1.02}},
	"planning": {"name": "Председатель Госплана", "desc": "Бюджет на 20% дешевле, нацпроекты на 20% быстрее", "fee": 4500, "salary": 7.0, "cat": "econ", "mods": {"budget_cost": 0.8, "project_speed": 1.2}},
	"ecology": {"name": "Министр экологии", "desc": "+3 одобрение, волнения позже", "fee": 2500, "salary": 4.0, "cat": "nature", "mods": {"approval": 3.0, "unrest": -2.0}},
	"vice_premier": {"name": "Вице-премьер", "desc": "+2% золота и роста, зарплаты на 5% меньше", "fee": 6000, "salary": 10.0, "cat": "state", "mods": {"gold": 1.02, "growth": 1.02, "salary_mult": 0.95}},
	"navy_min": {"name": "Морской министр", "desc": "Корабли на 20% дальше, порты приносят больше", "fee": 3500, "salary": 6.0, "cat": "navy", "mods": {"naval_reach": 1.2, "gold_flat": 4.0}},
	"mayor": {"name": "Столичный градоначальник", "desc": "+2 одобрение, +5 золота в секунду", "fee": 2500, "salary": 4.0, "cat": "people", "mods": {"approval": 2.0, "gold_flat": 5.0}},
	"archivist": {"name": "Главный архивариус", "desc": "Технологии на 5% дешевле, законы на 5% дешевле", "fee": 2000, "salary": 3.0, "cat": "science", "mods": {"tech_cost": 0.95, "bill_cost": 0.95}},
}
const MINISTER_ORDER := ["finance", "general", "diplomat", "scientist", "propagandist", "economist", "defense", "admiral", "culture", "treasurer", "labor", "spy", "speaker", "premier", "interior", "education", "health", "agriculture", "industry", "transport", "trade_min", "colonies_min", "justice", "chief_of_staff", "quartermaster", "astrologer", "chancellor", "energy", "foreign", "sports_min", "planning", "ecology", "vice_premier", "navy_min", "mayor", "archivist"]

# ---------------------------------------------------------------- bills (need BILL_MAJORITY seats among supporting parties; req = bill needed first, excl = incompatible bills, req_tech = technology needed)
const BILLS := {
	"free_trade": {"name": "Свободная торговля", "desc": "+10% золота", "cost": 5000, "support": ["trade", "tech"], "cat": "econ", "mods": {"gold": 1.1}, "excl": ["tariffs"]},
	"luxury_tax": {"name": "Налог на роскошь", "desc": "+6% золота, −2 одобрение", "cost": 3000, "support": ["people", "trade"], "cat": "econ", "mods": {"gold": 1.06, "approval": -2.0}},
	"no_duties": {"name": "Отмена пошлин", "desc": "+4 одобрение, −5% золота", "cost": 2500, "support": ["trade", "people"], "cat": "econ", "mods": {"approval": 4.0, "gold": 0.95}},
	"bank_reform": {"name": "Банковская реформа", "desc": "+5 золота в секунду, +3% золота", "cost": 4500, "support": ["trade", "tech"], "cat": "econ", "mods": {"gold_flat": 5.0, "gold": 1.03}},
	"public_works": {"name": "Общественные работы", "desc": "Постройки на 10% дешевле", "cost": 4000, "support": ["people", "tech"], "cat": "econ", "mods": {"build_cost": 0.9}},
	"stock_exchange": {"name": "Биржа", "desc": "+8% золота", "cost": 7000, "support": ["trade", "tech"], "cat": "econ", "mods": {"gold": 1.08}, "req": "bank_reform"},
	"gold_standard": {"name": "Золотой стандарт", "desc": "+5% золота, −3% роста армии", "cost": 5000, "support": ["trade", "order"], "cat": "econ", "mods": {"gold": 1.05, "growth": 0.97}},
	"tariffs": {"name": "Протекционизм", "desc": "+10 золота в секунду, −2 одобрение", "cost": 4000, "support": ["trade", "order"], "cat": "econ", "mods": {"gold_flat": 10.0, "approval": -2.0}, "excl": ["free_trade"]},
	"guilds": {"name": "Гильдии", "desc": "Постройки на 5% дешевле, +2% золота", "cost": 3500, "support": ["trade", "people"], "cat": "econ", "mods": {"build_cost": 0.95, "gold": 1.02}},
	"mint": {"name": "Монетный двор", "desc": "+6 золота в секунду", "cost": 3000, "support": ["trade", "tech"], "cat": "econ", "mods": {"gold_flat": 6.0}},
	"income_tax": {"name": "Подоходный налог", "desc": "+8% золота, −4 одобрение", "cost": 4500, "support": ["trade", "order"], "cat": "econ", "mods": {"gold": 1.08, "approval": -4.0}},
	"vat": {"name": "Налог с продаж", "desc": "+6% золота, −3 одобрение", "cost": 4000, "support": ["trade", "tech"], "cat": "econ", "mods": {"gold": 1.06, "approval": -3.0}},
	"tax_amnesty": {"name": "Налоговая амнистия", "desc": "+5 одобрение, −4% золота", "cost": 2500, "support": ["people", "trade"], "cat": "econ", "mods": {"approval": 5.0, "gold": 0.96}},
	"salt_monopoly": {"name": "Соляная монополия", "desc": "+10 золота в секунду, −2 одобрение", "cost": 3500, "support": ["empire", "trade"], "cat": "econ", "mods": {"gold_flat": 10.0, "approval": -2.0}},
	"corp_law": {"name": "Закон об акционерных обществах", "desc": "+5% золота", "cost": 4500, "support": ["tech", "trade"], "cat": "econ", "mods": {"gold": 1.05}, "req": "stock_exchange"},
	"ports_free": {"name": "Свободные порты", "desc": "Корабли на 12% быстрее, +2% золота", "cost": 4000, "support": ["trade", "empire"], "cat": "econ", "mods": {"ship_speed": 1.12, "gold": 1.02}},
	"roads": {"name": "Дорожный фонд", "desc": "Фронт на 6% быстрее, постройки на 5% дешевле", "cost": 4500, "support": ["trade", "tech"], "cat": "econ", "mods": {"attack_rate": 1.06, "build_cost": 0.95}},
	"credit": {"name": "Дешёвый кредит", "desc": "Постройки на 12% дешевле, −2% золота", "cost": 5000, "support": ["trade", "people"], "cat": "econ", "mods": {"build_cost": 0.88, "gold": 0.98}},
	"insurance": {"name": "Страхование", "desc": "Волнения позже, +2% золота", "cost": 3500, "support": ["trade", "tech"], "cat": "econ", "mods": {"unrest": -3.0, "gold": 1.02}},
	"antitrust": {"name": "Антимонопольный закон", "desc": "+4 одобрение, −2% золота", "cost": 3000, "support": ["people", "tech"], "cat": "econ", "mods": {"approval": 4.0, "gold": 0.98}},
	"pension_fund": {"name": "Пенсионный фонд", "desc": "+3 одобрение, +3 на выборах, −3% золота", "cost": 4000, "support": ["people", "trade"], "cat": "econ", "mods": {"approval": 3.0, "election": 3.0, "gold": 0.97}, "req": "pensions"},
	"child_benefits": {"name": "Детские пособия", "desc": "+4 одобрение, +2% роста, −4% золота", "cost": 4500, "support": ["people", "green"], "cat": "econ", "mods": {"approval": 4.0, "growth": 1.02, "gold": 0.96}},
	"cooperatives": {"name": "Кооперативы", "desc": "+4 золота в секунду, +2 одобрение", "cost": 3000, "support": ["green", "people"], "cat": "econ", "mods": {"gold_flat": 4.0, "approval": 2.0}},
	"state_bank": {"name": "Госбанк", "desc": "+8 золота в секунду, зарплаты на 10% меньше", "cost": 5500, "support": ["order", "trade"], "cat": "econ", "mods": {"gold_flat": 8.0, "salary_mult": 0.9}},
	"budget_rule": {"name": "Бюджетное правило", "desc": "Бюджет на 20% дешевле", "cost": 4000, "support": ["tech", "trade"], "cat": "econ", "mods": {"budget_cost": 0.8}},
	"lean_gov": {"name": "Сокращение аппарата", "desc": "Зарплаты на 20% меньше, −2 одобрение", "cost": 3500, "support": ["trade", "tech"], "cat": "econ", "mods": {"salary_mult": 0.8, "approval": -2.0}},
	"civil_service": {"name": "Табель о рангах", "desc": "Зарплаты на 10% меньше, +2 на выборах", "cost": 3000, "support": ["order", "tech"], "cat": "econ", "mods": {"salary_mult": 0.9, "election": 2.0}},
	"export_bonus": {"name": "Экспортные премии", "desc": "+5% золота при портах: +4 золота в секунду", "cost": 3500, "support": ["trade", "empire"], "cat": "econ", "mods": {"gold": 1.03, "gold_flat": 4.0}},
	"army_reform": {"name": "Военная реформа", "desc": "+10% к лимиту армии", "cost": 5000, "support": ["order", "tech"], "cat": "army", "mods": {"cap": 1.1}},
	"pro_army": {"name": "Профессиональная армия", "desc": "+12% к лимиту, −4% золота", "cost": 5500, "support": ["order", "tech"], "cat": "army", "mods": {"cap": 1.12, "gold": 0.96}, "excl": ["militia"]},
	"conscription": {"name": "Всеобщая воинская обязанность", "desc": "+0.4% роста армии в секунду, −6 одобрение", "cost": 5000, "support": ["order", "empire"], "cat": "army", "mods": {"interest": 0.004, "approval": -6.0}},
	"emergency": {"name": "Чрезвычайное положение", "desc": "+20% роста армии, −10 к цели одобрения", "cost": 6000, "support": ["order", "empire"], "cat": "army", "mods": {"growth": 1.2, "approval": -10.0}, "excl": ["demob"]},
	"logistics_corps": {"name": "Логистический корпус", "desc": "Фронт продвигается на 10% быстрее", "cost": 4500, "support": ["order", "trade"], "cat": "army", "mods": {"attack_rate": 1.1}},
	"border_forts": {"name": "Крепости на границе", "desc": "+15% к защите, −3% золота", "cost": 6000, "support": ["order", "empire"], "cat": "army", "mods": {"defense": 1.15, "gold": 0.97}},
	"nuclear_shield": {"name": "Ядерный щит", "desc": "Бункеры сбивают бомбы на 8 клеток дальше", "cost": 6000, "support": ["order", "tech"], "cat": "army", "mods": {"shield": 8.0}},
	"officer_school": {"name": "Офицерская школа", "desc": "Фронт на 8% быстрее", "cost": 4000, "support": ["order", "tech"], "cat": "army", "mods": {"attack_rate": 1.08}},
	"reserves": {"name": "Резервисты", "desc": "+8% к лимиту армии", "cost": 4000, "support": ["order", "people"], "cat": "army", "mods": {"cap": 1.08}},
	"militia": {"name": "Ополчение", "desc": "+5% к лимиту, +2 одобрение", "cost": 3000, "support": ["people", "order"], "cat": "army", "mods": {"cap": 1.05, "approval": 2.0}, "excl": ["pro_army"]},
	"war_tax": {"name": "Военный налог", "desc": "+6% золота, −3 одобрение", "cost": 3500, "support": ["order", "empire"], "cat": "army", "mods": {"gold": 1.06, "approval": -3.0}},
	"veterans": {"name": "Льготы ветеранам", "desc": "+4 одобрение, −3% золота", "cost": 3000, "support": ["order", "people"], "cat": "army", "mods": {"approval": 4.0, "gold": 0.97}},
	"military_industry": {"name": "Военно-промышленный комплекс", "desc": "+0.2% роста армии в секунду, −3% золота", "cost": 5000, "support": ["order", "tech"], "cat": "army", "mods": {"interest": 0.002, "gold": 0.97}},
	"general_staff": {"name": "Реформа Генштаба", "desc": "Фронт на 10% быстрее, зарплаты +10%", "cost": 5000, "support": ["order", "empire"], "cat": "army", "mods": {"attack_rate": 1.1, "salary_mult": 1.1}, "req": "officer_school"},
	"cavalry": {"name": "Кавалерийский устав", "desc": "Захват на 5% дешевле", "cost": 4000, "support": ["order", "empire"], "cat": "army", "mods": {"capture": 0.95}},
	"trenches": {"name": "Окопная доктрина", "desc": "+10% к защите, фронт на 5% медленнее", "cost": 3500, "support": ["order", "green"], "cat": "army", "mods": {"defense": 1.1, "attack_rate": 0.95}, "excl": ["blitz"]},
	"blitz": {"name": "Доктрина прорыва", "desc": "Фронт на 15% быстрее, −5% к защите", "cost": 5000, "support": ["order", "empire"], "cat": "army", "mods": {"attack_rate": 1.15, "defense": 0.95}, "excl": ["trenches"]},
	"war_bonds": {"name": "Военные облигации", "desc": "+10 золота в секунду, −3 одобрение", "cost": 4000, "support": ["order", "trade"], "cat": "army", "mods": {"gold_flat": 10.0, "approval": -3.0}},
	"drill": {"name": "Всеобщая военная подготовка", "desc": "+0.15% роста армии в секунду, −2 одобрение", "cost": 3500, "support": ["order", "people"], "cat": "army", "mods": {"interest": 0.0015, "approval": -2.0}},
	"garrisons": {"name": "Гарнизоны", "desc": "+8% к защите, −3 золота в секунду", "cost": 3000, "support": ["order", "empire"], "cat": "army", "mods": {"defense": 1.08, "gold_flat": -3.0}},
	"field_hospitals": {"name": "Полевые госпитали", "desc": "+5% роста армии, +1 одобрение", "cost": 3500, "support": ["green", "order"], "cat": "army", "mods": {"growth": 1.05, "approval": 1.0}},
	"war_academy": {"name": "Военная академия", "desc": "Фронт на 6% быстрее, технологии на 5% дешевле", "cost": 4500, "support": ["tech", "order"], "cat": "army", "mods": {"attack_rate": 1.06, "tech_cost": 0.95}},
	"demob": {"name": "Демобилизация", "desc": "+8 одобрение, −10% к лимиту армии", "cost": 2500, "support": ["people", "green"], "cat": "army", "mods": {"approval": 8.0, "cap": 0.9}, "excl": ["emergency"]},
	"mercenaries": {"name": "Наёмники", "desc": "+8% к лимиту армии, +6 золота в секунду расходов", "cost": 4000, "support": ["order", "trade"], "cat": "army", "mods": {"cap": 1.08, "salary": 6.0}},
	"fortress_towns": {"name": "Города-крепости", "desc": "+6% к защите, +1 одобрение", "cost": 4000, "support": ["order", "tech"], "cat": "army", "mods": {"defense": 1.06, "approval": 1.0}},
	"air_defense": {"name": "Противовоздушная оборона", "desc": "Бункеры сбивают бомбы ещё на 6 клеток дальше", "cost": 5000, "support": ["order", "tech"], "cat": "army", "mods": {"shield": 6.0}, "req": "nuclear_shield"},
	"nuclear_doctrine": {"name": "Ядерная доктрина", "desc": "Бомбы на 20% дешевле, −4 одобрение", "cost": 8000, "support": ["order", "empire"], "cat": "army", "mods": {"nuke_cost": 0.8, "approval": -4.0}, "excl": ["disarmament"]},
	"prohibition": {"name": "Сухой закон", "desc": "+3% роста армии, −5 одобрение", "cost": 2500, "support": ["order", "tech"], "cat": "army", "mods": {"growth": 1.03, "approval": -5.0}},
	"sappers": {"name": "Инженерные войска", "desc": "Захват гор и лесов… любой земли на 4% дешевле", "cost": 3500, "support": ["order", "tech"], "cat": "army", "mods": {"capture": 0.96}},
	"navy_program": {"name": "Флотская программа", "desc": "Корабли на 25% быстрее", "cost": 4000, "support": ["empire", "trade"], "cat": "navy", "mods": {"ship_speed": 1.25}},
	"coast_defense": {"name": "Береговая оборона", "desc": "Ваши клетки на 10% дороже врагу", "cost": 4500, "support": ["order", "green"], "cat": "navy", "mods": {"defense": 1.1}},
	"admiralty": {"name": "Адмиралтейство", "desc": "Корабли на 20% дальше", "cost": 4500, "support": ["empire", "order"], "cat": "navy", "mods": {"naval_reach": 1.2}},
	"merchant_fleet": {"name": "Торговый флот", "desc": "+8 золота в секунду, +2% золота", "cost": 4000, "support": ["trade", "empire"], "cat": "navy", "mods": {"gold_flat": 8.0, "gold": 1.02}},
	"marines": {"name": "Морская пехота", "desc": "Захват на 5% дешевле, корабли на 10% быстрее", "cost": 5000, "support": ["empire", "order"], "cat": "navy", "mods": {"capture": 0.95, "ship_speed": 1.1}, "req": "navy_program"},
	"lighthouses": {"name": "Маяки", "desc": "Корабли на 10% быстрее, +1 одобрение", "cost": 2500, "support": ["trade", "green"], "cat": "navy", "mods": {"ship_speed": 1.1, "approval": 1.0}},
	"fishing": {"name": "Рыбный промысел", "desc": "+5 золота в секунду, +1 одобрение", "cost": 2000, "support": ["green", "trade"], "cat": "navy", "mods": {"gold_flat": 5.0, "approval": 1.0}},
	"naval_academy": {"name": "Морская академия", "desc": "Корабли на 15% дальше, технологии на 3% дешевле", "cost": 4000, "support": ["tech", "empire"], "cat": "navy", "mods": {"naval_reach": 1.15, "tech_cost": 0.97}},
	"privateers": {"name": "Каперство", "desc": "+8 золота в секунду, −2 одобрение", "cost": 3500, "support": ["empire", "trade"], "cat": "navy", "mods": {"gold_flat": 8.0, "approval": -2.0}},
	"canal_law": {"name": "Закон о каналах", "desc": "Корабли на 15% быстрее, постройки на 3% дешевле", "cost": 4500, "support": ["tech", "trade"], "cat": "navy", "mods": {"ship_speed": 1.15, "build_cost": 0.97}},
	"sea_patrol": {"name": "Морские патрули", "desc": "+5% к защите, корабли на 5% дальше", "cost": 3500, "support": ["order", "trade"], "cat": "navy", "mods": {"defense": 1.05, "naval_reach": 1.05}},
	"social": {"name": "Социальный пакет", "desc": "+8 к цели одобрения, −5% золота", "cost": 4000, "support": ["people", "trade"], "cat": "people", "mods": {"approval": 8.0, "gold": 0.95}},
	"free_medicine": {"name": "Бесплатная медицина", "desc": "+6 одобрение, −6% золота", "cost": 4500, "support": ["people", "green"], "cat": "people", "mods": {"approval": 6.0, "gold": 0.94}},
	"pensions": {"name": "Пенсионная реформа", "desc": "+5 одобрение, −5% золота", "cost": 4000, "support": ["people", "trade"], "cat": "people", "mods": {"approval": 5.0, "gold": 0.95}},
	"eight_hours": {"name": "Восьмичасовой рабочий день", "desc": "+4 одобрение, −3% роста", "cost": 3000, "support": ["people", "green"], "cat": "people", "mods": {"approval": 4.0, "growth": 0.97}},
	"free_speech": {"name": "Свобода слова", "desc": "+3 одобрение, волнения начинаются позже", "cost": 3000, "support": ["people", "green"], "cat": "people", "mods": {"approval": 3.0, "unrest": -5.0}, "excl": ["censorship"]},
	"election_reform": {"name": "Избирательная реформа", "desc": "+5 одобрение на выборах", "cost": 3500, "support": ["people", "tech"], "cat": "people", "mods": {"election": 5.0}},
	"green_deal": {"name": "Зелёный курс", "desc": "+5 одобрение, −2% роста армии", "cost": 3500, "support": ["green", "people"], "cat": "people", "mods": {"approval": 5.0, "growth": 0.98}},
	"schools": {"name": "Всеобщее образование", "desc": "+3 одобрение, технологии на 5% дешевле", "cost": 4000, "support": ["people", "tech"], "cat": "people", "mods": {"approval": 3.0, "tech_cost": 0.95}},
	"housing": {"name": "Жилищная программа", "desc": "+5 одобрение, −4% золота", "cost": 4500, "support": ["people", "green"], "cat": "people", "mods": {"approval": 5.0, "gold": 0.96}},
	"min_wage": {"name": "Минимальная зарплата", "desc": "+4 одобрение, −3% золота", "cost": 3000, "support": ["people", "order"], "cat": "people", "mods": {"approval": 4.0, "gold": 0.97}},
	"unions": {"name": "Профсоюзы", "desc": "+3 одобрение, волнения позже", "cost": 3000, "support": ["people", "green"], "cat": "people", "mods": {"approval": 3.0, "unrest": -4.0}},
	"equal_rights": {"name": "Равные права", "desc": "+4 одобрение, +3% роста армии", "cost": 3500, "support": ["people", "tech"], "cat": "people", "mods": {"approval": 4.0, "growth": 1.03}},
	"public_transport": {"name": "Общественный транспорт", "desc": "+3 одобрение, фронт на 3% быстрее", "cost": 4000, "support": ["green", "people"], "cat": "people", "mods": {"approval": 3.0, "attack_rate": 1.03}},
	"libraries": {"name": "Библиотеки", "desc": "+2 одобрение, технологии на 4% дешевле", "cost": 2500, "support": ["tech", "people"], "cat": "people", "mods": {"approval": 2.0, "tech_cost": 0.96}},
	"theatres": {"name": "Театры и музеи", "desc": "+4 одобрение, −2% золота", "cost": 3000, "support": ["people", "green"], "cat": "people", "mods": {"approval": 4.0, "gold": 0.98}},
	"sports": {"name": "Спортивный закон", "desc": "+3 одобрение, +2% роста армии", "cost": 3000, "support": ["people", "order"], "cat": "people", "mods": {"approval": 3.0, "growth": 1.02}},
	"holidays": {"name": "Праздничные дни", "desc": "+5 одобрение, −3% золота, −2% роста", "cost": 2500, "support": ["people", "green"], "cat": "people", "mods": {"approval": 5.0, "gold": 0.97, "growth": 0.98}},
	"censorship": {"name": "Цензура", "desc": "−3 одобрение, +5 на выборах, волнения позже", "cost": 3000, "support": ["order", "empire"], "cat": "people", "mods": {"approval": -3.0, "election": 5.0, "unrest": -6.0}, "excl": ["free_speech"]},
	"secret_police": {"name": "Тайная полиция", "desc": "Волнения начинаются намного позже, −6 одобрение", "cost": 4500, "support": ["order", "empire"], "cat": "people", "mods": {"unrest": -10.0, "approval": -6.0}},
	"referendums": {"name": "Референдумы", "desc": "+3 одобрение, +4 на выборах", "cost": 3500, "support": ["people", "green"], "cat": "people", "mods": {"approval": 3.0, "election": 4.0}},
	"elderly_care": {"name": "Уход за пожилыми", "desc": "+3 одобрение, −2% золота", "cost": 3000, "support": ["people", "green"], "cat": "people", "mods": {"approval": 3.0, "gold": 0.98}},
	"clean_water": {"name": "Чистая вода", "desc": "+3 одобрение, +2% роста армии", "cost": 3500, "support": ["green", "tech"], "cat": "people", "mods": {"approval": 3.0, "growth": 1.02}},
	"vaccination": {"name": "Вакцинация", "desc": "+4% роста армии, +1 одобрение", "cost": 4000, "support": ["tech", "green"], "cat": "people", "mods": {"growth": 1.04, "approval": 1.0}, "req": "free_medicine"},
	"anti_corruption": {"name": "Антикоррупционный закон", "desc": "+4 одобрение, зарплаты на 10% меньше", "cost": 4000, "support": ["people", "tech"], "cat": "people", "mods": {"approval": 4.0, "salary_mult": 0.9}},
	"welfare": {"name": "Пособия по безработице", "desc": "+5 одобрение, −5% золота", "cost": 4000, "support": ["people", "green"], "cat": "people", "mods": {"approval": 5.0, "gold": 0.95}},
	"orphanages": {"name": "Приюты", "desc": "+2 одобрение, +1% роста армии", "cost": 2000, "support": ["people", "green"], "cat": "people", "mods": {"approval": 2.0, "growth": 1.01}},
	"prison_reform": {"name": "Реформа тюрем", "desc": "+2 одобрение, волнения позже", "cost": 2500, "support": ["people", "tech"], "cat": "people", "mods": {"approval": 2.0, "unrest": -3.0}},
	"bread_price": {"name": "Твёрдые цены на хлеб", "desc": "+4 одобрение, −4 золота в секунду", "cost": 2000, "support": ["people", "order"], "cat": "people", "mods": {"approval": 4.0, "gold_flat": -4.0}},
	"science": {"name": "Наука в приоритете", "desc": "−20% к цене технологий", "cost": 4000, "support": ["tech", "people"], "cat": "science", "mods": {"tech_cost": 0.8}},
	"universities": {"name": "Университеты", "desc": "−10% к цене технологий, +2 одобрение", "cost": 4500, "support": ["tech", "green"], "cat": "science", "mods": {"tech_cost": 0.9, "approval": 2.0}},
	"patents": {"name": "Патентное право", "desc": "Технологии на 8% дешевле, +2% золота", "cost": 4000, "support": ["tech", "trade"], "cat": "science", "mods": {"tech_cost": 0.92, "gold": 1.02}},
	"academy": {"name": "Академия наук", "desc": "Технологии на 10% дешевле, +4 золота в секунду расходов", "cost": 5000, "support": ["tech", "people"], "cat": "science", "mods": {"tech_cost": 0.9, "salary": 4.0}, "req": "universities"},
	"observatory_law": {"name": "Обсерватории", "desc": "Корабли на 10% дальше, технологии на 3% дешевле", "cost": 3500, "support": ["tech", "empire"], "cat": "science", "mods": {"naval_reach": 1.1, "tech_cost": 0.97}},
	"engineering": {"name": "Инженерный корпус", "desc": "Постройки на 10% дешевле, фронт на 4% быстрее", "cost": 4500, "support": ["tech", "order"], "cat": "science", "mods": {"build_cost": 0.9, "attack_rate": 1.04}},
	"metric": {"name": "Метрическая система", "desc": "+3% золота, постройки на 3% дешевле", "cost": 3000, "support": ["tech", "trade"], "cat": "science", "mods": {"gold": 1.03, "build_cost": 0.97}},
	"printing": {"name": "Книгопечатание", "desc": "+2 одобрение, технологии на 5% дешевле, +2 на выборах", "cost": 3500, "support": ["tech", "people"], "cat": "science", "mods": {"approval": 2.0, "tech_cost": 0.95, "election": 2.0}},
	"expeditions": {"name": "Научные экспедиции", "desc": "Корабли на 15% дальше, технологии на 3% дешевле", "cost": 4000, "support": ["tech", "green"], "cat": "science", "mods": {"naval_reach": 1.15, "tech_cost": 0.97}},
	"grants": {"name": "Гранты учёным", "desc": "Технологии на 10% дешевле, −4 золота в секунду", "cost": 3500, "support": ["tech", "green"], "cat": "science", "mods": {"tech_cost": 0.9, "gold_flat": -4.0}},
	"tech_schools": {"name": "Технические училища", "desc": "+0.1% роста армии в секунду, технологии на 4% дешевле", "cost": 4000, "support": ["tech", "order"], "cat": "science", "mods": {"interest": 0.001, "tech_cost": 0.96}},
	"open_science": {"name": "Открытая наука", "desc": "Технологии на 7% дешевле, +2 одобрение", "cost": 4500, "support": ["tech", "people"], "cat": "science", "mods": {"tech_cost": 0.93, "approval": 2.0}, "req": "academy"},
	"space_law": {"name": "Закон о космосе", "desc": "Корабли на 20% дальше и 10% быстрее, технологии на 5% дешевле", "cost": 9000, "support": ["tech", "empire"], "cat": "science", "mods": {"naval_reach": 1.2, "ship_speed": 1.1, "tech_cost": 0.95}, "req_tech": "rockets"},
	"statistics": {"name": "Статистическое бюро", "desc": "+2% золота, бюджет на 10% дешевле", "cost": 3000, "support": ["tech", "trade"], "cat": "science", "mods": {"gold": 1.02, "budget_cost": 0.9}},
	"cheap_decrees": {"name": "Реформа канцелярии", "desc": "Указы на 30% дешевле", "cost": 3000, "support": ["tech", "trade"], "cat": "state", "mods": {"decree_cost": 0.7}},
	"constitution": {"name": "Конституция", "desc": "+5 одобрение, +5 на выборах, волнения позже", "cost": 8000, "support": ["people", "tech"], "cat": "state", "mods": {"approval": 5.0, "election": 5.0, "unrest": -5.0}},
	"federation": {"name": "Федерация", "desc": "+3 одобрение, захват на 3% дешевле", "cost": 6000, "support": ["empire", "people"], "cat": "state", "mods": {"approval": 3.0, "capture": 0.97}, "excl": ["centralization"]},
	"centralization": {"name": "Централизация", "desc": "Указы на 20% и бюджет на 10% дешевле, −2 одобрение", "cost": 5000, "support": ["order", "tech"], "cat": "state", "mods": {"decree_cost": 0.8, "budget_cost": 0.9, "approval": -2.0}, "excl": ["federation"]},
	"meritocracy": {"name": "Меритократия", "desc": "Зарплаты на 15% меньше, технологии на 3% дешевле", "cost": 4000, "support": ["tech", "trade"], "cat": "state", "mods": {"salary_mult": 0.85, "tech_cost": 0.97}},
	"term_limits": {"name": "Ограничение сроков", "desc": "+4 на выборах, +2 одобрение", "cost": 3000, "support": ["people", "green"], "cat": "state", "mods": {"election": 4.0, "approval": 2.0}},
	"state_media": {"name": "Государственные СМИ", "desc": "+6 на выборах, −2 одобрение", "cost": 3500, "support": ["order", "empire"], "cat": "state", "mods": {"election": 6.0, "approval": -2.0}},
	"transparency": {"name": "Открытое правительство", "desc": "+3 одобрение, зарплаты на 5% меньше", "cost": 3500, "support": ["people", "tech"], "cat": "state", "mods": {"approval": 3.0, "salary_mult": 0.95}},
	"census": {"name": "Перепись населения", "desc": "+3% золота, +2% роста армии", "cost": 3000, "support": ["tech", "trade"], "cat": "state", "mods": {"gold": 1.03, "growth": 1.02}},
	"civil_code": {"name": "Гражданский кодекс", "desc": "+2 одобрение, +2% золота, волнения позже", "cost": 4000, "support": ["tech", "people"], "cat": "state", "mods": {"approval": 2.0, "gold": 1.02, "unrest": -2.0}},
	"customs_union": {"name": "Таможенный союз", "desc": "+4% золота, боты нападают реже", "cost": 5000, "support": ["trade", "green"], "cat": "state", "mods": {"gold": 1.04, "diplomacy": 0.3}},
	"propaganda_ministry": {"name": "Министерство пропаганды", "desc": "Указы на 30% дешевле, +4 на выборах", "cost": 4000, "support": ["order", "empire"], "cat": "state", "mods": {"decree_cost": 0.7, "election": 4.0}},
	"audit": {"name": "Счётная палата", "desc": "Бюджет на 15% дешевле, зарплаты на 5% меньше", "cost": 4500, "support": ["tech", "trade"], "cat": "state", "mods": {"budget_cost": 0.85, "salary_mult": 0.95}},
	"regional_councils": {"name": "Земства", "desc": "+3 одобрение, постройки на 5% дешевле", "cost": 4000, "support": ["people", "green"], "cat": "state", "mods": {"approval": 3.0, "build_cost": 0.95}},
	"national_bank": {"name": "Национальный банк", "desc": "+4% золота, законы на 10% дешевле", "cost": 5000, "support": ["trade", "tech"], "cat": "state", "mods": {"gold": 1.04, "bill_cost": 0.9}, "req": "bank_reform"},
	"chancellery": {"name": "Реформа делопроизводства", "desc": "Законы на 20% дешевле", "cost": 3500, "support": ["tech", "order"], "cat": "state", "mods": {"bill_cost": 0.8}},
	"diplomacy_corps": {"name": "Дипломатический корпус", "desc": "Боты нападают реже", "cost": 5000, "support": ["trade", "green"], "cat": "state", "mods": {"diplomacy": 0.6}},
	"peace_treaties": {"name": "Мирные договоры", "desc": "Отношения со всеми +8, пакты на 20% дешевле", "cost": 4000, "support": ["green", "trade"], "cat": "state", "mods": {"relation": 8.0, "pact_cost": 0.8}},
	"civil_defense": {"name": "Гражданская оборона", "desc": "Волнения позже, бункеры на 3 клетки дальше", "cost": 3500, "support": ["order", "green"], "cat": "state", "mods": {"unrest": -3.0, "shield": 3.0}},
	"national_projects": {"name": "Закон о нацпроектах", "desc": "Нацпроекты идут на 25% быстрее", "cost": 5000, "support": ["tech", "people"], "cat": "state", "mods": {"project_speed": 1.25}},
	"land_reform": {"name": "Земельная реформа", "desc": "Захват любой земли на 8% дешевле", "cost": 5500, "support": ["empire", "people"], "cat": "empire", "mods": {"capture": 0.92}},
	"resettlement": {"name": "Программа переселения", "desc": "+6% роста армии", "cost": 4000, "support": ["empire", "people"], "cat": "empire", "mods": {"growth": 1.06}},
	"imperial_edict": {"name": "Имперский эдикт", "desc": "Захват чужого на 10% дешевле, −4 одобрение", "cost": 6500, "support": ["empire", "order"], "cat": "empire", "mods": {"capture": 0.9, "approval": -4.0}},
	"colonies": {"name": "Колониальная хартия", "desc": "Захват на 6% дешевле, корабли на 10% дальше", "cost": 6000, "support": ["empire", "trade"], "cat": "empire", "mods": {"capture": 0.94, "naval_reach": 1.1}},
	"frontier": {"name": "Освоение окраин", "desc": "+4% роста армии, захват на 4% дешевле", "cost": 5000, "support": ["empire", "people"], "cat": "empire", "mods": {"growth": 1.04, "capture": 0.96}},
	"tribute": {"name": "Дань с покорённых", "desc": "+10 золота в секунду, −3 одобрение", "cost": 4500, "support": ["empire", "order"], "cat": "empire", "mods": {"gold_flat": 10.0, "approval": -3.0}},
	"assimilation": {"name": "Ассимиляция", "desc": "Волнения позже, +2% роста армии", "cost": 4000, "support": ["empire", "order"], "cat": "empire", "mods": {"unrest": -5.0, "growth": 1.02}},
	"imperial_roads": {"name": "Имперские дороги", "desc": "Фронт на 8% быстрее, постройки на 5% дешевле", "cost": 5500, "support": ["empire", "tech"], "cat": "empire", "mods": {"attack_rate": 1.08, "build_cost": 0.95}},
	"expansion_act": {"name": "Акт о расширении", "desc": "Захват на 7% дешевле, −3 одобрение", "cost": 7000, "support": ["empire", "order"], "cat": "empire", "mods": {"capture": 0.93, "approval": -3.0}, "req": "imperial_edict"},
	"vassals": {"name": "Вассальные договоры", "desc": "Боты нападают реже, +3% золота", "cost": 5000, "support": ["empire", "trade"], "cat": "empire", "mods": {"diplomacy": 0.5, "gold": 1.03}},
	"great_wall_law": {"name": "Пограничный вал", "desc": "+12% к защите, −5 золота в секунду", "cost": 6500, "support": ["empire", "order"], "cat": "empire", "mods": {"defense": 1.12, "gold_flat": -5.0}},
	"manifest": {"name": "Манифест величия", "desc": "+4 одобрение, +3 на выборах, захват на 2% дешевле", "cost": 4500, "support": ["empire", "people"], "cat": "empire", "mods": {"approval": 4.0, "election": 3.0, "capture": 0.98}},
	"settlers": {"name": "Переселенцы", "desc": "+3% роста армии, +5% к лимиту", "cost": 4500, "support": ["empire", "green"], "cat": "empire", "mods": {"growth": 1.03, "cap": 1.05}},
	"protectorates": {"name": "Протектораты", "desc": "Отношения +5, захват на 3% дешевле", "cost": 5000, "support": ["empire", "green"], "cat": "empire", "mods": {"relation": 5.0, "capture": 0.97}},
	"disarmament": {"name": "Ядерное разоружение", "desc": "Бомбы вдвое дороже, +6 одобрение", "cost": 3000, "support": ["green", "people"], "cat": "nature", "mods": {"nuke_cost": 2.0, "approval": 6.0}, "excl": ["nuclear_doctrine"]},
	"forests": {"name": "Охрана лесов", "desc": "+3 одобрение, захват на 2% дороже", "cost": 2500, "support": ["green", "people"], "cat": "nature", "mods": {"approval": 3.0, "capture": 1.02}},
	"parks": {"name": "Национальные парки", "desc": "+4 одобрение, −2% золота", "cost": 3000, "support": ["green", "people"], "cat": "nature", "mods": {"approval": 4.0, "gold": 0.98}},
	"clean_air": {"name": "Чистый воздух", "desc": "+3 одобрение, +2% роста армии", "cost": 3500, "support": ["green", "tech"], "cat": "nature", "mods": {"approval": 3.0, "growth": 1.02}},
	"recycling": {"name": "Переработка отходов", "desc": "+2 золота в секунду, +2 одобрение", "cost": 3000, "support": ["green", "tech"], "cat": "nature", "mods": {"gold_flat": 2.0, "approval": 2.0}},
	"organic": {"name": "Органическое земледелие", "desc": "+3 одобрение, +2% роста, −2% золота", "cost": 3000, "support": ["green", "people"], "cat": "nature", "mods": {"approval": 3.0, "growth": 1.02, "gold": 0.98}},
	"wind_power": {"name": "Ветряные мельницы", "desc": "+4 золота в секунду, постройки на 3% дешевле", "cost": 3500, "support": ["green", "tech"], "cat": "nature", "mods": {"gold_flat": 4.0, "build_cost": 0.97}},
	"animal_rights": {"name": "Защита животных", "desc": "+2 одобрение", "cost": 2000, "support": ["green", "people"], "cat": "nature", "mods": {"approval": 2.0}},
	"nuclear_ban": {"name": "Запрет ядерных испытаний", "desc": "Бомбы в полтора раза дороже, +4 одобрение, боты нападают реже", "cost": 4000, "support": ["green", "people"], "cat": "nature", "mods": {"nuke_cost": 1.5, "approval": 4.0, "diplomacy": 0.3}, "req": "disarmament"},
	"green_cities": {"name": "Зелёные города", "desc": "+3 одобрение, +3% к лимиту армии", "cost": 4000, "support": ["green", "tech"], "cat": "nature", "mods": {"approval": 3.0, "cap": 1.03}},
	"water_law": {"name": "Водный кодекс", "desc": "+2 одобрение, корабли на 5% быстрее", "cost": 3000, "support": ["green", "trade"], "cat": "nature", "mods": {"approval": 2.0, "ship_speed": 1.05}},
	"soil_care": {"name": "Охрана почв", "desc": "+3 золота в секунду, +1 одобрение", "cost": 2500, "support": ["green", "people"], "cat": "nature", "mods": {"gold_flat": 3.0, "approval": 1.0}},
}
const BILL_ORDER := ["free_trade", "luxury_tax", "no_duties", "bank_reform", "public_works", "stock_exchange", "gold_standard", "tariffs", "guilds", "mint", "income_tax", "vat", "tax_amnesty", "salt_monopoly", "corp_law", "ports_free", "roads", "credit", "insurance", "antitrust", "pension_fund", "child_benefits", "cooperatives", "state_bank", "budget_rule", "lean_gov", "civil_service", "export_bonus", "army_reform", "pro_army", "conscription", "emergency", "logistics_corps", "border_forts", "nuclear_shield", "officer_school", "reserves", "militia", "war_tax", "veterans", "military_industry", "general_staff", "cavalry", "trenches", "blitz", "war_bonds", "drill", "garrisons", "field_hospitals", "war_academy", "demob", "mercenaries", "fortress_towns", "air_defense", "nuclear_doctrine", "prohibition", "sappers", "navy_program", "coast_defense", "admiralty", "merchant_fleet", "marines", "lighthouses", "fishing", "naval_academy", "privateers", "canal_law", "sea_patrol", "social", "free_medicine", "pensions", "eight_hours", "free_speech", "election_reform", "green_deal", "schools", "housing", "min_wage", "unions", "equal_rights", "public_transport", "libraries", "theatres", "sports", "holidays", "censorship", "secret_police", "referendums", "elderly_care", "clean_water", "vaccination", "anti_corruption", "welfare", "orphanages", "prison_reform", "bread_price", "science", "universities", "patents", "academy", "observatory_law", "engineering", "metric", "printing", "expeditions", "grants", "tech_schools", "open_science", "space_law", "statistics", "cheap_decrees", "constitution", "federation", "centralization", "meritocracy", "term_limits", "state_media", "transparency", "census", "civil_code", "customs_union", "propaganda_ministry", "audit", "regional_councils", "national_bank", "chancellery", "diplomacy_corps", "peace_treaties", "civil_defense", "national_projects", "land_reform", "resettlement", "imperial_edict", "colonies", "frontier", "tribute", "assimilation", "imperial_roads", "expansion_act", "vassals", "great_wall_law", "manifest", "settlers", "protectorates", "disarmament", "forests", "parks", "clean_air", "recycling", "organic", "wind_power", "animal_rights", "nuclear_ban", "green_cities", "water_law", "soil_care"]

# ---------------------------------------------------------------- extra buildings (party = who gains Duma weight per building)
const BUILDINGS := {
	"farm": {"name": "Ферма", "desc": "+6 золота в секунду, +1 одобрение", "cost": 2000, "coast": false, "cat": "econ", "party": "green", "mods": {"gold_flat": 6.0, "approval": 1.0}},
	"mine": {"name": "Шахта", "desc": "+12 золота в секунду, −1 одобрение", "cost": 3500, "coast": false, "cat": "econ", "party": "trade", "mods": {"gold_flat": 12.0, "approval": -1.0}},
	"bank": {"name": "Банк", "desc": "+5% золота", "cost": 5000, "coast": false, "cat": "econ", "party": "trade", "mods": {"gold": 1.05}},
	"customs": {"name": "Таможня", "desc": "+4% золота (на берегу)", "cost": 3500, "coast": true, "cat": "econ", "party": "trade", "mods": {"gold": 1.04}},
	"casino": {"name": "Казино", "desc": "+15 золота в секунду, −3 одобрение", "cost": 4000, "coast": false, "cat": "econ", "party": "trade", "mods": {"gold_flat": 15.0, "approval": -3.0}},
	"workshop": {"name": "Мастерская", "desc": "+8 золота в секунду", "cost": 2500, "coast": false, "cat": "econ", "party": "trade", "mods": {"gold_flat": 8.0}},
	"warehouse": {"name": "Склад", "desc": "+5 золота в секунду, волнения позже", "cost": 2800, "coast": false, "cat": "econ", "party": "trade", "mods": {"gold_flat": 5.0, "unrest": -2.0}},
	"market_hall": {"name": "Торговые ряды", "desc": "+4% золота", "cost": 4500, "coast": false, "cat": "econ", "party": "trade", "mods": {"gold": 1.04}},
	"brewery": {"name": "Пивоварня", "desc": "+7 золота в секунду, +1 одобрение", "cost": 3000, "coast": false, "cat": "econ", "party": "people", "mods": {"gold_flat": 7.0, "approval": 1.0}},
	"vineyard": {"name": "Виноградник", "desc": "+6 золота в секунду, +1 одобрение", "cost": 2500, "coast": false, "cat": "econ", "party": "green", "mods": {"gold_flat": 6.0, "approval": 1.0}},
	"sawmill": {"name": "Лесопилка", "desc": "+9 золота в секунду, −1 одобрение", "cost": 3000, "coast": false, "cat": "econ", "party": "trade", "mods": {"gold_flat": 9.0, "approval": -1.0}},
	"quarry": {"name": "Каменоломня", "desc": "Постройки на 4% дешевле, +4 золота в секунду", "cost": 3500, "coast": false, "cat": "econ", "party": "trade", "mods": {"build_cost": 0.96, "gold_flat": 4.0}},
	"foundry": {"name": "Литейная", "desc": "+10 золота в секунду, +200 к лимиту армии", "cost": 4500, "coast": false, "cat": "econ", "party": "order", "mods": {"gold_flat": 10.0, "cap_flat": 200.0}},
	"trading_post": {"name": "Фактория", "desc": "+6% золота (на берегу)", "cost": 4000, "coast": true, "cat": "econ", "party": "trade", "mods": {"gold": 1.06}},
	"oil_well": {"name": "Нефтяная вышка", "desc": "+20 золота в секунду, −3 одобрение", "cost": 7000, "coast": false, "cat": "econ", "party": "trade", "mods": {"gold_flat": 20.0, "approval": -3.0}},
	"toll_road": {"name": "Платная дорога", "desc": "+6 золота в секунду, фронт на 2% быстрее", "cost": 3500, "coast": false, "cat": "econ", "party": "trade", "mods": {"gold_flat": 6.0, "attack_rate": 1.02}},
	"mill": {"name": "Мельница", "desc": "+5 золота в секунду, +1 одобрение", "cost": 2000, "coast": false, "cat": "econ", "party": "green", "mods": {"gold_flat": 5.0, "approval": 1.0}},
	"treasury": {"name": "Казначейство", "desc": "+3% золота", "cost": 5000, "coast": false, "cat": "econ", "party": "trade", "mods": {"gold": 1.03}},
	"granary": {"name": "Амбар", "desc": "Волнения начинаются позже, +2 одобрение", "cost": 2500, "coast": false, "cat": "people", "party": "green", "mods": {"unrest": -4.0, "approval": 2.0}},
	"hospital": {"name": "Больница", "desc": "+3 одобрение", "cost": 3000, "coast": false, "cat": "people", "party": "green", "mods": {"approval": 3.0}},
	"temple": {"name": "Храм", "desc": "+4 одобрение, −2% роста армии", "cost": 2500, "coast": false, "cat": "people", "party": "people", "mods": {"approval": 4.0, "growth": 0.98}},
	"stadium": {"name": "Стадион", "desc": "+5 одобрение", "cost": 6000, "coast": false, "cat": "people", "party": "people", "mods": {"approval": 5.0}},
	"palace": {"name": "Дворец", "desc": "+3 одобрение, +4 на выборах", "cost": 7000, "coast": false, "cat": "people", "party": "empire", "mods": {"approval": 3.0, "election": 4.0}},
	"school": {"name": "Школа", "desc": "+2 одобрение, технологии на 2% дешевле", "cost": 2500, "coast": false, "cat": "people", "party": "tech", "mods": {"approval": 2.0, "tech_cost": 0.98}},
	"theatre": {"name": "Театр", "desc": "+3 одобрение", "cost": 3000, "coast": false, "cat": "people", "party": "people", "mods": {"approval": 3.0}},
	"bathhouse": {"name": "Бани", "desc": "+2 одобрение, +1% роста армии", "cost": 2000, "coast": false, "cat": "people", "party": "people", "mods": {"approval": 2.0, "growth": 1.01}},
	"orphanage": {"name": "Приют", "desc": "+2 одобрение", "cost": 1800, "coast": false, "cat": "people", "party": "people", "mods": {"approval": 2.0}},
	"park": {"name": "Парк", "desc": "+2 одобрение", "cost": 1500, "coast": false, "cat": "people", "party": "green", "mods": {"approval": 2.0}},
	"monument": {"name": "Монумент", "desc": "+2 одобрение, +3 на выборах", "cost": 3500, "coast": false, "cat": "people", "party": "empire", "mods": {"approval": 2.0, "election": 3.0}},
	"library": {"name": "Библиотека", "desc": "+1 одобрение, технологии на 3% дешевле", "cost": 2500, "coast": false, "cat": "people", "party": "tech", "mods": {"approval": 1.0, "tech_cost": 0.97}},
	"clinic": {"name": "Поликлиника", "desc": "+2 одобрение, +1% роста армии", "cost": 2500, "coast": false, "cat": "people", "party": "green", "mods": {"approval": 2.0, "growth": 1.01}},
	"square": {"name": "Площадь", "desc": "+2 одобрение, +2 золота в секунду", "cost": 2000, "coast": false, "cat": "people", "party": "people", "mods": {"approval": 2.0, "gold_flat": 2.0}},
	"prison": {"name": "Тюрьма", "desc": "Волнения намного позже, −1 одобрение", "cost": 3000, "coast": false, "cat": "people", "party": "order", "mods": {"unrest": -5.0, "approval": -1.0}},
	"town_hall": {"name": "Ратуша", "desc": "+2 одобрение, +2 на выборах", "cost": 3500, "coast": false, "cat": "people", "party": "people", "mods": {"approval": 2.0, "election": 2.0}},
	"arsenal": {"name": "Арсенал", "desc": "+600 к лимиту армии", "cost": 3500, "coast": false, "cat": "army", "party": "empire", "mods": {"cap_flat": 600.0}},
	"hq": {"name": "Штаб", "desc": "Фронт продвигается на 10% быстрее", "cost": 5000, "coast": false, "cat": "army", "party": "order", "mods": {"attack_rate": 1.1}},
	"fortress": {"name": "Крепость", "desc": "Ваши клетки на 12% дороже врагу", "cost": 5000, "coast": false, "cat": "army", "party": "order", "mods": {"defense": 1.12}},
	"radar": {"name": "Радар", "desc": "Бункеры сбивают бомбы на 6 клеток дальше", "cost": 4500, "coast": false, "cat": "army", "party": "tech", "mods": {"shield": 6.0}},
	"watchtower": {"name": "Сторожевая башня", "desc": "+5% к защите", "cost": 1800, "coast": false, "cat": "army", "party": "order", "mods": {"defense": 1.05}},
	"armory": {"name": "Оружейная", "desc": "+400 к лимиту армии", "cost": 2500, "coast": false, "cat": "army", "party": "order", "mods": {"cap_flat": 400.0}},
	"mil_academy": {"name": "Кадетский корпус", "desc": "Фронт на 5% быстрее, +2% роста армии", "cost": 5000, "coast": false, "cat": "army", "party": "order", "mods": {"attack_rate": 1.05, "growth": 1.02}},
	"garrison": {"name": "Гарнизон", "desc": "+8% к защите, −2 золота в секунду", "cost": 3500, "coast": false, "cat": "army", "party": "order", "mods": {"defense": 1.08, "gold_flat": -2.0}},
	"supply_depot": {"name": "Склад снабжения", "desc": "Фронт на 6% быстрее", "cost": 4000, "coast": false, "cat": "army", "party": "order", "mods": {"attack_rate": 1.06}},
	"airfield": {"name": "Аэродром", "desc": "Фронт на 8% быстрее, корабли на 10% дальше", "cost": 6000, "coast": false, "cat": "army", "party": "order", "mods": {"attack_rate": 1.08, "naval_reach": 1.1}},
	"silo": {"name": "Ракетная шахта", "desc": "Бомбы на 10% дешевле, бункеры на 3 клетки дальше", "cost": 8000, "coast": false, "cat": "army", "party": "order", "mods": {"nuke_cost": 0.9, "shield": 3.0}},
	"training_ground": {"name": "Полигон", "desc": "+0.1% роста армии в секунду", "cost": 3000, "coast": false, "cat": "army", "party": "order", "mods": {"interest": 0.001}},
	"university": {"name": "Университет", "desc": "Технологии на 8% дешевле, +0.1% роста", "cost": 4500, "coast": false, "cat": "science", "party": "tech", "mods": {"tech_cost": 0.92, "interest": 0.001}},
	"lab": {"name": "Лаборатория", "desc": "Технологии на 12% дешевле", "cost": 5500, "coast": false, "cat": "science", "party": "tech", "mods": {"tech_cost": 0.88}},
	"observatory": {"name": "Обсерватория", "desc": "Корабли на 8% дальше, технологии на 3% дешевле", "cost": 4000, "coast": false, "cat": "science", "party": "tech", "mods": {"naval_reach": 1.08, "tech_cost": 0.97}},
	"printing_house": {"name": "Типография", "desc": "+1 одобрение, +2 на выборах", "cost": 3000, "coast": false, "cat": "science", "party": "tech", "mods": {"approval": 1.0, "election": 2.0}},
	"institute": {"name": "Институт", "desc": "Технологии на 10% дешевле, +0.05% роста", "cost": 6500, "coast": false, "cat": "science", "party": "tech", "mods": {"tech_cost": 0.9, "interest": 0.0005}},
	"inventors": {"name": "Дом изобретателей", "desc": "Постройки на 4% дешевле", "cost": 4000, "coast": false, "cat": "science", "party": "tech", "mods": {"build_cost": 0.96}},
	"power_plant": {"name": "Электростанция", "desc": "+8 золота в секунду, постройки на 3% дешевле", "cost": 6000, "coast": false, "cat": "science", "party": "tech", "mods": {"gold_flat": 8.0, "build_cost": 0.97}},
	"archive": {"name": "Архив", "desc": "Законы на 5% дешевле", "cost": 3000, "coast": false, "cat": "science", "party": "tech", "mods": {"bill_cost": 0.95}},
	"shipyard": {"name": "Верфь", "desc": "Корабли на 20% быстрее и дальше (на берегу)", "cost": 4000, "coast": true, "cat": "navy", "party": "empire", "mods": {"ship_speed": 1.2, "naval_reach": 1.2}},
	"lighthouse": {"name": "Маяк", "desc": "Корабли на 10% быстрее (на берегу)", "cost": 2500, "coast": true, "cat": "navy", "party": "trade", "mods": {"ship_speed": 1.1}},
	"naval_base": {"name": "Военно-морская база", "desc": "Корабли на 25% дальше, +3% к защите (на берегу)", "cost": 6000, "coast": true, "cat": "navy", "party": "empire", "mods": {"naval_reach": 1.25, "defense": 1.03}},
	"fish_market": {"name": "Рыбный рынок", "desc": "+8 золота в секунду, +1 одобрение (на берегу)", "cost": 3000, "coast": true, "cat": "navy", "party": "trade", "mods": {"gold_flat": 8.0, "approval": 1.0}},
	"drydock": {"name": "Сухой док", "desc": "Корабли на 15% быстрее (на берегу)", "cost": 4500, "coast": true, "cat": "navy", "party": "empire", "mods": {"ship_speed": 1.15}},
	"embassy": {"name": "Посольство", "desc": "Боты нападают реже", "cost": 4000, "coast": false, "cat": "state", "party": "green", "mods": {"diplomacy": 0.4}},
	"courthouse": {"name": "Суд", "desc": "Волнения позже, +1 одобрение", "cost": 3000, "coast": false, "cat": "state", "party": "tech", "mods": {"unrest": -3.0, "approval": 1.0}},
	"ministry": {"name": "Министерство", "desc": "Зарплаты на 5% меньше", "cost": 4500, "coast": false, "cat": "state", "party": "tech", "mods": {"salary_mult": 0.95}},
	"consulate": {"name": "Консульство", "desc": "Отношения со всеми +4", "cost": 3000, "coast": false, "cat": "state", "party": "green", "mods": {"relation": 4.0}},
	"windmill": {"name": "Ветряк", "desc": "+4 золота в секунду", "cost": 2000, "coast": false, "cat": "nature", "party": "green", "mods": {"gold_flat": 4.0}},
	"reservoir": {"name": "Водохранилище", "desc": "+2 одобрение, +2% роста армии", "cost": 3500, "coast": false, "cat": "nature", "party": "green", "mods": {"approval": 2.0, "growth": 1.02}},
	"reserve": {"name": "Заповедник", "desc": "+3 одобрение", "cost": 3000, "coast": false, "cat": "nature", "party": "green", "mods": {"approval": 3.0}},
	"orchard": {"name": "Сад", "desc": "+4 золота в секунду, +1 одобрение", "cost": 2200, "coast": false, "cat": "nature", "party": "green", "mods": {"gold_flat": 4.0, "approval": 1.0}},
}
const BUILDING_ORDER := ["farm", "mine", "bank", "customs", "casino", "workshop", "warehouse", "market_hall", "brewery", "vineyard", "sawmill", "quarry", "foundry", "trading_post", "oil_well", "toll_road", "mill", "treasury", "granary", "hospital", "temple", "stadium", "palace", "school", "theatre", "bathhouse", "orphanage", "park", "monument", "library", "clinic", "square", "prison", "town_hall", "arsenal", "hq", "fortress", "radar", "watchtower", "armory", "mil_academy", "garrison", "supply_depot", "airfield", "silo", "training_ground", "university", "lab", "observatory", "printing_house", "institute", "inventors", "power_plant", "archive", "shipyard", "lighthouse", "naval_base", "fish_market", "drydock", "embassy", "courthouse", "ministry", "consulate", "windmill", "reservoir", "reserve", "orchard"]

# ---------------------------------------------------------------- extra technologies (levels, costs; effects are mods per level)
const EXTRA_TECHS := {
	"irrigation": {"name": "Ирригация", "desc": "+4% роста армии за уровень", "max": 2, "costs": [3500, 7000], "req": "", "cat": "econ", "mods": {"growth": 1.04}},
	"medicine": {"name": "Медицина", "desc": "+4 к цели одобрения за уровень", "max": 2, "costs": [4000, 8000], "req": "", "cat": "people", "mods": {"approval": 4.0}},
	"electricity": {"name": "Электричество", "desc": "Постройки на 10% дешевле за уровень", "max": 2, "costs": [5000, 10000], "req": "", "cat": "science", "mods": {"build_cost": 0.9}},
	"radio": {"name": "Радио", "desc": "+3 одобрение и +3 на выборах за уровень", "max": 2, "costs": [4500, 9000], "req": "", "cat": "people", "mods": {"approval": 3.0, "election": 3.0}},
	"banking": {"name": "Банковское дело", "desc": "+8% золота за уровень", "max": 2, "costs": [5000, 10000], "req": "trade", "cat": "econ", "mods": {"gold": 1.08}},
	"artillery": {"name": "Артиллерия", "desc": "Захват чужого на 8% дешевле за уровень", "max": 2, "costs": [6000, 12000], "req": "tactics", "cat": "army", "mods": {"capture": 0.92}},
	"railways": {"name": "Железные дороги", "desc": "Фронт на 12% быстрее за уровень", "max": 2, "costs": [5500, 11000], "req": "logistics", "cat": "army", "mods": {"attack_rate": 1.12}},
	"satellites": {"name": "Спутники", "desc": "Корабли и бомбы дальше и быстрее", "max": 1, "costs": [20000], "req": "rockets", "cat": "science", "mods": {"naval_reach": 1.5, "ship_speed": 1.3}},
	"printing_press": {"name": "Печатный станок", "desc": "+2 одобрение, +2 на выборах за уровень", "max": 2, "costs": [3000, 6000], "req": "", "cat": "people", "mods": {"approval": 2.0, "election": 2.0}},
	"steel": {"name": "Сталь", "desc": "+6% к защите, +3% к лимиту за уровень", "max": 2, "costs": [4500, 9000], "req": "fortification", "cat": "army", "mods": {"defense": 1.06, "cap": 1.03}},
	"steam": {"name": "Паровые машины", "desc": "+6% золота, корабли на 10% быстрее за уровень", "max": 2, "costs": [5000, 10000], "req": "", "cat": "econ", "mods": {"gold": 1.06, "ship_speed": 1.1}},
	"chemistry": {"name": "Химия", "desc": "Захват на 5% дешевле, +2% роста за уровень", "max": 2, "costs": [5500, 11000], "req": "", "cat": "science", "mods": {"capture": 0.95, "growth": 1.02}},
	"telegraph": {"name": "Телеграф", "desc": "Фронт на 6% быстрее, указы на 10% дешевле за уровень", "max": 2, "costs": [4000, 8000], "req": "", "cat": "state", "mods": {"attack_rate": 1.06, "decree_cost": 0.9}},
	"sanitation": {"name": "Санитария", "desc": "+5% роста армии, +2 одобрение за уровень", "max": 2, "costs": [3500, 7000], "req": "medicine", "cat": "people", "mods": {"growth": 1.05, "approval": 2.0}},
	"agronomy": {"name": "Агрономия", "desc": "+5 золота в секунду, +3% роста за уровень", "max": 3, "costs": [2500, 5000, 10000], "req": "irrigation", "cat": "econ", "mods": {"gold_flat": 5.0, "growth": 1.03}},
	"aviation": {"name": "Авиация", "desc": "Фронт на 10% быстрее, корабли на 15% дальше за уровень", "max": 2, "costs": [8000, 16000], "req": "railways", "cat": "army", "mods": {"attack_rate": 1.1, "naval_reach": 1.15}},
	"radar_tech": {"name": "Радиолокация", "desc": "Бункеры на 5 клеток дальше, +3% к защите за уровень", "max": 2, "costs": [6000, 12000], "req": "radio", "cat": "army", "mods": {"shield": 5.0, "defense": 1.03}},
	"computers": {"name": "Вычислительные машины", "desc": "Технологии на 10% дешевле, +3% золота за уровень", "max": 2, "costs": [9000, 18000], "req": "electricity", "cat": "science", "mods": {"tech_cost": 0.9, "gold": 1.03}},
	"concrete": {"name": "Бетон", "desc": "Постройки на 10% дешевле, +4% к защите за уровень", "max": 2, "costs": [4000, 8000], "req": "", "cat": "science", "mods": {"build_cost": 0.9, "defense": 1.04}},
	"mass_media": {"name": "Массовые медиа", "desc": "+5 на выборах, +2 одобрение", "max": 1, "costs": [7000], "req": "radio", "cat": "people", "mods": {"election": 5.0, "approval": 2.0}},
	"genetics": {"name": "Генетика", "desc": "+6% роста армии за уровень", "max": 2, "costs": [10000, 20000], "req": "medicine", "cat": "science", "mods": {"growth": 1.06}},
	"containers": {"name": "Контейнерные перевозки", "desc": "Корабли на 20% быстрее, +4% золота", "max": 1, "costs": [12000], "req": "steam", "cat": "navy", "mods": {"ship_speed": 1.2, "gold": 1.04}},
	"cryptography": {"name": "Криптография", "desc": "Боты нападают реже, +3% к защите", "max": 1, "costs": [6000], "req": "", "cat": "state", "mods": {"diplomacy": 0.3, "defense": 1.03}},
	"fusion": {"name": "Термоядерный синтез", "desc": "+15% золота, +10% роста армии", "max": 1, "costs": [40000], "req": "nuclear", "cat": "science", "mods": {"gold": 1.15, "growth": 1.1}},
	"optics": {"name": "Оптика", "desc": "Корабли на 10% дальше за уровень", "max": 2, "costs": [3000, 6000], "req": "", "cat": "navy", "mods": {"naval_reach": 1.1}},
	"economics": {"name": "Экономическая наука", "desc": "Бюджет на 10% дешевле, +2% золота за уровень", "max": 2, "costs": [4500, 9000], "req": "", "cat": "econ", "mods": {"budget_cost": 0.9, "gold": 1.02}},
}
const EXTRA_TECH_ORDER := ["irrigation", "medicine", "electricity", "radio", "banking", "artillery", "railways", "satellites", "printing_press", "steel", "steam", "chemistry", "telegraph", "sanitation", "agronomy", "aviation", "radar_tech", "computers", "concrete", "mass_media", "genetics", "containers", "cryptography", "fusion", "optics", "economics"]

# ---------------------------------------------------------------- budget (levels 0..3; cost per second scales with land)
const BUDGET := {
	"army": {"name": "Армия", "desc": "+0.25% роста армии в секунду за уровень", "mods": {"interest": 0.0025}},
	"science": {"name": "Наука", "desc": "Технологии на 6% дешевле за уровень", "mods": {"tech_cost": 0.94}},
	"social": {"name": "Народ", "desc": "+3 к цели одобрения за уровень", "mods": {"approval": 3.0}},
	"infrastructure": {"name": "Инфраструктура", "desc": "Постройки на 5% дешевле за уровень", "mods": {"build_cost": 0.95}},
	"navy": {"name": "Флот", "desc": "Корабли на 8% быстрее и дальше за уровень", "mods": {"ship_speed": 1.08, "naval_reach": 1.08}},
	"police": {"name": "Правопорядок", "desc": "Волнения позже на 2 пункта за уровень, −0.5 одобрение", "mods": {"unrest": -2.0, "approval": -0.5}},
	"culture": {"name": "Культура", "desc": "+2 одобрение, +1.5 на выборах за уровень", "mods": {"approval": 2.0, "election": 1.5}},
	"diplomacy": {"name": "Дипломатия", "desc": "Отношения +4, боты нападают реже за уровень", "mods": {"relation": 4.0, "diplomacy": 0.2}},
}
const BUDGET_ORDER := ["army", "science", "social", "infrastructure", "navy", "police", "culture", "diplomacy"]
const BUDGET_COST_PER_CELL := 0.008      # gold per second per level per cell
const BUDGET_MAX := 3

# ---------------------------------------------------------------- reforms: one option per axis, changing costs gold and approval
const REFORMS := {
	"government": {"name": "Форма правления", "default": "republic", "options": {"republic": {"name": "Республика", "desc": "Сбалансированный курс без особых эффектов", "mods": {}, "parties": {"people": 4.0, "tech": 2.0}}, "monarchy": {"name": "Монархия", "desc": "+3 одобрение, волнения позже, указы на 15% дешевле, −3 на выборах", "mods": {"approval": 3.0, "unrest": -4.0, "decree_cost": 0.85, "election": -3.0}, "parties": {"order": 6.0, "empire": 6.0}}, "junta": {"name": "Военная хунта", "desc": "+8% роста и +5% лимита армии, −8 одобрение, волнения намного позже", "mods": {"growth": 1.08, "cap": 1.05, "approval": -8.0, "unrest": -8.0}, "parties": {"order": 12.0}}, "technocracy": {"name": "Технократия", "desc": "Технологии на 15% и постройки на 5% дешевле, −2 одобрение", "mods": {"tech_cost": 0.85, "build_cost": 0.95, "approval": -2.0}, "parties": {"tech": 12.0}}}},
	"economy": {"name": "Экономический уклад", "default": "market", "options": {"market": {"name": "Рыночная экономика", "desc": "Сбалансированный курс без особых эффектов", "mods": {}, "parties": {"trade": 4.0}}, "planned": {"name": "Плановая экономика", "desc": "Постройки на 15% дешевле, нацпроекты на 25% быстрее, −5% золота", "mods": {"build_cost": 0.85, "project_speed": 1.25, "gold": 0.95}, "parties": {"order": 6.0, "people": 4.0}}, "mixed": {"name": "Смешанная экономика", "desc": "+2% золота, +2 одобрение", "mods": {"gold": 1.02, "approval": 2.0}, "parties": {"people": 4.0, "trade": 4.0}}, "guild": {"name": "Цеховая экономика", "desc": "+6 золота в секунду, технологии на 5% дороже", "mods": {"gold_flat": 6.0, "tech_cost": 1.05}, "parties": {"trade": 4.0, "green": 4.0}}}},
	"army_model": {"name": "Устройство армии", "default": "conscript", "options": {"conscript": {"name": "Призывная армия", "desc": "Сбалансированный курс без особых эффектов", "mods": {}, "parties": {"order": 2.0}}, "professional": {"name": "Контрактная армия", "desc": "+8% к лимиту, +5 золота в секунду расходов", "mods": {"cap": 1.08, "salary": 5.0}, "parties": {"order": 4.0, "tech": 4.0}}, "militia": {"name": "Народное ополчение", "desc": "+10% к защите, фронт на 8% медленнее, +2 одобрение", "mods": {"defense": 1.1, "attack_rate": 0.92, "approval": 2.0}, "parties": {"people": 6.0, "green": 4.0}}, "legions": {"name": "Легионы", "desc": "Фронт на 10% быстрее, захват на 4% дешевле, −3 одобрение", "mods": {"attack_rate": 1.1, "capture": 0.96, "approval": -3.0}, "parties": {"empire": 10.0}}}},
	"religion": {"name": "Церковь и государство", "default": "secular", "options": {"secular": {"name": "Светское государство", "desc": "Сбалансированный курс без особых эффектов", "mods": {}, "parties": {"tech": 2.0}}, "state_church": {"name": "Государственная церковь", "desc": "+4 одобрение, волнения позже, технологии на 5% дороже", "mods": {"approval": 4.0, "unrest": -4.0, "tech_cost": 1.05}, "parties": {"order": 4.0, "empire": 4.0}}, "freedom": {"name": "Свобода вероисповедания", "desc": "+3 одобрение, боты нападают чуть реже", "mods": {"approval": 3.0, "diplomacy": 0.2}, "parties": {"people": 6.0, "green": 2.0}}, "theocracy": {"name": "Теократия", "desc": "+6 одобрение, +6 на выборах, технологии на 15% дороже, −5% золота", "mods": {"approval": 6.0, "election": 6.0, "tech_cost": 1.15, "gold": 0.95}, "parties": {"order": 8.0}}}},
	"foreign": {"name": "Внешняя политика", "default": "neutral", "options": {"neutral": {"name": "Нейтралитет", "desc": "Сбалансированный курс без особых эффектов", "mods": {}, "parties": {"green": 2.0}}, "open": {"name": "Открытые границы", "desc": "+5% золота, отношения со всеми +8", "mods": {"gold": 1.05, "relation": 8.0}, "parties": {"trade": 8.0}}, "expansion": {"name": "Экспансия", "desc": "Захват на 6% дешевле, отношения −10, −2 одобрение", "mods": {"capture": 0.94, "relation": -10.0, "approval": -2.0}, "parties": {"empire": 10.0}}, "isolation": {"name": "Изоляция", "desc": "+10% к защите, −8% золота, волнения позже", "mods": {"defense": 1.1, "gold": 0.92, "unrest": -3.0}, "parties": {"order": 6.0}}}},
	"society": {"name": "Общественный строй", "default": "equality", "options": {"equality": {"name": "Равенство", "desc": "Сбалансированный курс без особых эффектов", "mods": {}, "parties": {"people": 4.0}}, "estates": {"name": "Сословия", "desc": "+3% золота, −2 одобрение", "mods": {"gold": 1.03, "approval": -2.0}, "parties": {"empire": 4.0, "order": 4.0}}, "meritocratic": {"name": "Меритократия", "desc": "Технологии на 5% дешевле, зарплаты на 10% меньше", "mods": {"tech_cost": 0.95, "salary_mult": 0.9}, "parties": {"tech": 8.0}}, "corporate": {"name": "Корпоративный строй", "desc": "+8 золота в секунду, волнения позже", "mods": {"gold_flat": 8.0, "unrest": -2.0}, "parties": {"trade": 6.0, "order": 2.0}}}},
}
const REFORM_ORDER := ["government", "economy", "army_model", "religion", "foreign", "society"]
const REFORM_COST := 5000
const REFORM_APPROVAL_HIT := 6.0

# ---------------------------------------------------------------- national projects: pay once, wait, get a permanent bonus
const PROJECTS := {
	"grand_canal": {"name": "Великий канал", "desc": "Корабли на 20% быстрее, +3% золота", "cost": 12000, "duration": 120, "mods": {"ship_speed": 1.2, "gold": 1.03}, "approval": 3.0, "cat": "navy"},
	"railway_net": {"name": "Трансконтинентальная магистраль", "desc": "Фронт на 15% быстрее, постройки на 5% дешевле", "cost": 15000, "duration": 150, "mods": {"attack_rate": 1.15, "build_cost": 0.95}, "approval": 2.0, "cat": "econ"},
	"literacy": {"name": "Всеобщая грамотность", "desc": "Технологии на 15% дешевле, +3 одобрение", "cost": 8000, "duration": 90, "mods": {"tech_cost": 0.85, "approval": 3.0}, "approval": 4.0, "cat": "science"},
	"cathedral": {"name": "Великий собор", "desc": "+6 одобрение, +4 на выборах", "cost": 9000, "duration": 100, "mods": {"approval": 6.0, "election": 4.0}, "approval": 5.0, "cat": "people"},
	"power_grid": {"name": "Электрификация", "desc": "+8% золота, +10 золота в секунду", "cost": 14000, "duration": 120, "mods": {"gold": 1.08, "gold_flat": 10.0}, "approval": 2.0, "cat": "econ"},
	"olympics": {"name": "Олимпийские игры", "desc": "+4 одобрение, отношения со всеми +10", "cost": 10000, "duration": 60, "mods": {"approval": 4.0, "relation": 10.0}, "approval": 8.0, "cat": "people"},
	"space": {"name": "Космическая программа", "desc": "Корабли на 30% дальше, технологии на 10% дешевле, +5 на выборах", "cost": 30000, "duration": 200, "mods": {"naval_reach": 1.3, "tech_cost": 0.9, "election": 5.0}, "approval": 6.0, "cat": "science", "req_tech": "rockets"},
	"nuclear_plant": {"name": "Атомная станция", "desc": "+12% золота", "cost": 25000, "duration": 180, "mods": {"gold": 1.12}, "approval": 1.0, "cat": "science", "req_tech": "nuclear"},
	"great_wall": {"name": "Великая стена", "desc": "+20% к защите", "cost": 16000, "duration": 150, "mods": {"defense": 1.2}, "approval": 2.0, "cat": "army"},
	"highways": {"name": "Сеть дорог", "desc": "Фронт на 8% быстрее, постройки на 7% дешевле", "cost": 9000, "duration": 90, "mods": {"attack_rate": 1.08, "build_cost": 0.93}, "approval": 2.0, "cat": "econ"},
	"hospitals": {"name": "Сеть больниц", "desc": "+8% роста армии, +3 одобрение", "cost": 11000, "duration": 110, "mods": {"growth": 1.08, "approval": 3.0}, "approval": 4.0, "cat": "people"},
	"universities": {"name": "Университетская сеть", "desc": "Технологии на 15% дешевле, +0.1% роста", "cost": 13000, "duration": 120, "mods": {"tech_cost": 0.85, "interest": 0.001}, "approval": 2.0, "cat": "science"},
	"fleet": {"name": "Большая судостроительная программа", "desc": "Корабли на 25% быстрее и 20% дальше", "cost": 14000, "duration": 130, "mods": {"ship_speed": 1.25, "naval_reach": 1.2}, "approval": 1.0, "cat": "navy"},
	"welfare_state": {"name": "Государство благосостояния", "desc": "+8 одобрение, волнения позже, −4% золота", "cost": 18000, "duration": 150, "mods": {"approval": 8.0, "unrest": -6.0, "gold": 0.96}, "approval": 6.0, "cat": "people"},
	"megacity": {"name": "Столичный мегаполис", "desc": "+12% к лимиту армии, +12 золота в секунду", "cost": 20000, "duration": 160, "mods": {"cap": 1.12, "gold_flat": 12.0}, "approval": 3.0, "cat": "econ"},
	"world_fair": {"name": "Всемирная выставка", "desc": "+4% золота, отношения +8, +2 одобрение", "cost": 8000, "duration": 70, "mods": {"gold": 1.04, "relation": 8.0, "approval": 2.0}, "approval": 4.0, "cat": "state"},
	"reforestation": {"name": "Восстановление лесов", "desc": "+4 одобрение, +2% роста армии", "cost": 6000, "duration": 80, "mods": {"approval": 4.0, "growth": 1.02}, "approval": 3.0, "cat": "nature"},
	"rearmament": {"name": "Перевооружение", "desc": "+10% к лимиту, фронт на 8% быстрее, −2 одобрение", "cost": 17000, "duration": 120, "mods": {"cap": 1.1, "attack_rate": 1.08, "approval": -2.0}, "approval": 0.0, "cat": "army"},
	"dam": {"name": "Плотина", "desc": "+14 золота в секунду, +3% роста армии", "cost": 11000, "duration": 100, "mods": {"gold_flat": 14.0, "growth": 1.03}, "approval": 2.0, "cat": "nature"},
	"telegraph_net": {"name": "Телеграфная сеть", "desc": "Указы на 20% дешевле, фронт на 4% быстрее", "cost": 7000, "duration": 60, "mods": {"decree_cost": 0.8, "attack_rate": 1.04}, "approval": 1.0, "cat": "state"},
	"coastal_forts": {"name": "Береговые форты", "desc": "+10% к защите, корабли на 10% дальше", "cost": 10000, "duration": 90, "mods": {"defense": 1.1, "naval_reach": 1.1}, "approval": 1.0, "cat": "navy"},
	"land_registry": {"name": "Земельный кадастр", "desc": "+5% золота, захват на 3% дешевле", "cost": 9000, "duration": 80, "mods": {"gold": 1.05, "capture": 0.97}, "approval": 1.0, "cat": "state"},
	"academy_arts": {"name": "Академия искусств", "desc": "+5 одобрение, +3 на выборах", "cost": 7000, "duration": 70, "mods": {"approval": 5.0, "election": 3.0}, "approval": 3.0, "cat": "people"},
	"grain_reserve": {"name": "Государственный резерв зерна", "desc": "Волнения намного позже, +2 одобрение", "cost": 6000, "duration": 60, "mods": {"unrest": -8.0, "approval": 2.0}, "approval": 2.0, "cat": "econ"},
}
const PROJECT_ORDER := ["grand_canal", "railway_net", "literacy", "cathedral", "power_grid", "olympics", "space", "nuclear_plant", "great_wall", "highways", "hospitals", "universities", "fleet", "welfare_state", "megacity", "world_fair", "reforestation", "rearmament", "dam", "telegraph_net", "coastal_forts", "land_registry", "academy_arts", "grain_reserve"]
const PROJECT_MAX_ACTIVE := 3

# ---------------------------------------------------------------- diplomacy
const RELATION_START := 50.0
const RELATION_DRIFT := 0.03           # per second toward RELATION_START
const RELATION_ATTACK_HIT := 20.0
const RELATION_GIFT := 15.0
const GIFT_COST := 2000
const GIFT_COST_PER_CELL := 0.3
const PACT_COST := 3000
const PACT_COST_PER_CELL := 0.5
const PACT_MIN_RELATION := 40.0
const PACT_SECONDS := 150
const RELATION_ATTACK_SCALE := 0.8      # bots need (1 + this * (relation-50)/50) more of an edge to attack you

# ---------------------------------------------------------------- extra decrees
const EXTRA_DECREES := {
	"amnesty": {"name": "Амнистия", "desc": "+10 одобрение, −8% войск", "cost": 0, "cooldown": 900, "approval": 10.0, "troops_share": -0.08},
	"requisition": {"name": "Реквизиция", "desc": "+3000 золота, −12 одобрение", "cost": 0, "cooldown": 900, "approval": -12.0, "gold": 3000.0},
	"parade": {"name": "Парад", "desc": "+6 одобрение", "cost": 1200, "cooldown": 600, "approval": 6.0},
	"tax_holiday": {"name": "Налоговые каникулы", "desc": "+8 одобрение", "cost": 2000, "cooldown": 900, "approval": 8.0},
	"treasury_audit": {"name": "Ревизия казны", "desc": "+2500 золота, −5 одобрение", "cost": 0, "cooldown": 1200, "approval": -5.0, "gold": 2500.0},
	"recruits": {"name": "Набор рекрутов", "desc": "+8% войск, −5 одобрение", "cost": 1500, "cooldown": 600, "approval": -5.0, "troops_share": 0.08},
	"charity": {"name": "Благотворительность", "desc": "+5 одобрение", "cost": 800, "cooldown": 450, "approval": 5.0},
	"fireworks": {"name": "Фейерверк", "desc": "+3 одобрение", "cost": 500, "cooldown": 300, "approval": 3.0},
	"pardon": {"name": "Помилование", "desc": "+4 одобрение, −2% войск", "cost": 0, "cooldown": 600, "approval": 4.0, "troops_share": -0.02},
	"army_bonus": {"name": "Премия армии", "desc": "+4% войск", "cost": 2500, "cooldown": 600, "troops_share": 0.04},
}
const EXTRA_DECREE_ORDER := ["amnesty", "requisition", "parade", "tax_holiday", "treasury_audit", "recruits", "charity", "fireworks", "pardon", "army_bonus"]

# ---------------------------------------------------------------- extra random events
const EXTRA_EVENTS := [
	{"title": "Открыто месторождение", "text": "Геологи нашли золото в горах.", "choices": [{"text": "Разрабатывать (+4000 золота, −4 одобрение)", "gold": 4000, "approval": -4}, {"text": "Оставить природе (+5 одобрение)", "approval": 5}]},
	{"title": "Забастовка", "text": "Рабочие рынков требуют повышения оплаты.", "choices": [{"text": "Уступить (−2500 золота, +6 одобрение)", "gold": -2500, "approval": 6}, {"text": "Разогнать (−9 одобрение)", "approval": -9}]},
	{"title": "Праздник урожая", "text": "Народ просит устроить гуляния.", "choices": [{"text": "Устроить (−1500 золота, +8 одобрение)", "gold": -1500, "approval": 8}, {"text": "Отказать (−3 одобрение)", "approval": -3}]},
	{"title": "Дезертиры", "text": "Часть солдат бежит домой.", "choices": [{"text": "Простить (−6% войск, +3 одобрение)", "troops_share": -0.06, "approval": 3}, {"text": "Наказать (−3% войск, −4 одобрение)", "troops_share": -0.03, "approval": -4}]},
	{"title": "Иностранный инвестор", "text": "Купец предлагает вложиться в ваши рынки.", "choices": [{"text": "Принять (+3000 золота, −2 одобрение)", "gold": 3000, "approval": -2}, {"text": "Отказать (+2 одобрение)", "approval": 2}]},
	{"title": "Наводнение", "text": "Реки вышли из берегов.", "choices": [{"text": "Помочь пострадавшим (−3000 золота, +6 одобрение)", "gold": -3000, "approval": 6}, {"text": "Не вмешиваться (−8 одобрение)", "approval": -8}]},
	{"title": "Изобретатель", "text": "Мастер предлагает чертежи за вознаграждение.", "choices": [{"text": "Купить (−3000 золота, технология +1)", "gold": -3000, "tech": 1}, {"text": "Отказать", "approval": -1}]},
	{"title": "Коррупционный скандал", "text": "Министра поймали на взятках.", "choices": [{"text": "Отдать под суд (+7 одобрение, −1500 золота)", "gold": -1500, "approval": 7}, {"text": "Замять (+1500 золота, −6 одобрение)", "gold": 1500, "approval": -6}]},
	{"title": "Добровольцы", "text": "Молодёжь просится в армию.", "choices": [{"text": "Принять всех (+10% войск, −2 одобрение)", "troops_share": 0.1, "approval": -2}, {"text": "Только лучших (+4% войск, +2 одобрение)", "troops_share": 0.04, "approval": 2}]},
	{"title": "Ярмарка", "text": "Соседи предлагают торговую ярмарку.", "choices": [{"text": "Провести (+2500 золота, +2 одобрение)", "gold": 2500, "approval": 2}, {"text": "Отказать (+1 одобрение)", "approval": 1}]},
	{"title": "Слухи о перевороте", "text": "Генералы недовольны.", "choices": [{"text": "Повысить жалование (−3500 золота, +4 одобрение)", "gold": -3500, "approval": 4}, {"text": "Сместить генералов (−12% войск, +3 одобрение)", "troops_share": -0.12, "approval": 3}]},
	{"title": "Учёные требуют свободы", "text": "Академия просит снять цензуру.", "choices": [{"text": "Снять (+5 одобрение, налоги −1)", "approval": 5, "tax": -1}, {"text": "Отказать (−3 одобрение)", "approval": -3}]},
	{"title": "Комета", "text": "В небе над столицей появилась комета. Народ волнуется.", "choices": [{"text": "Объявить добрым знаком (+5 одобрение)", "approval": 5}, {"text": "Пусть объяснят учёные (−2000 золота, технология +1)", "gold": -2000, "tech": 1}]},
	{"title": "Пожар в столице", "text": "Сгорел целый квартал.", "choices": [{"text": "Отстроить (−3000 золота, +6 одобрение)", "gold": -3000, "approval": 6}, {"text": "Оставить как есть (−8 одобрение)", "approval": -8}]},
	{"title": "Пиратский набег", "text": "Пираты захватили торговый караван.", "choices": [{"text": "Заплатить выкуп (−2000 золота)", "gold": -2000}, {"text": "Отбить силой (−5% войск, +4 одобрение)", "troops_share": -0.05, "approval": 4}]},
	{"title": "Гастроли", "text": "Знаменитая труппа просится выступить.", "choices": [{"text": "Бесплатно для народа (+3 одобрение)", "approval": 3}, {"text": "Продавать билеты (+1000 золота)", "gold": 1000}]},
	{"title": "Пойман шпион", "text": "Разведка схватила чужого агента.", "choices": [{"text": "Казнить (−3 одобрение, +3% войск)", "approval": -3, "troops_share": 0.03}, {"text": "Обменять (+1500 золота)", "gold": 1500}]},
	{"title": "Голод в горах", "text": "Горные деревни просят хлеба.", "choices": [{"text": "Отправить обозы (−2500 золота, +7 одобрение)", "gold": -2500, "approval": 7}, {"text": "Не помогать (−9 одобрение)", "approval": -9}]},
	{"title": "Бунт в столице", "text": "Толпа вышла на площадь.", "choices": [{"text": "Подавить (−8% войск, −4 одобрение)", "troops_share": -0.08, "approval": -4}, {"text": "Уступить (−2000 золота, +5 одобрение)", "gold": -2000, "approval": 5}]},
	{"title": "Наследство купца", "text": "Богатый купец умер без наследников.", "choices": [{"text": "В казну (+2500 золота)", "gold": 2500}, {"text": "Раздать беднякам (+6 одобрение)", "approval": 6}]},
	{"title": "Землетрясение", "text": "Разрушены дома в провинции.", "choices": [{"text": "Помочь (−3500 золота, +6 одобрение)", "gold": -3500, "approval": 6}, {"text": "Игнорировать (−10 одобрение)", "approval": -10}]},
	{"title": "Мода на армию", "text": "Молодёжь мечтает о службе.", "choices": [{"text": "Открыть набор (+8% войск, −2 одобрение)", "troops_share": 0.08, "approval": -2}, {"text": "Не сейчас (+2 одобрение)", "approval": 2}]},
	{"title": "Урожай винограда", "text": "Год выдался удачным.", "choices": [{"text": "Продать вино (+2000 золота)", "gold": 2000}, {"text": "Устроить праздник (+7 одобрение)", "approval": 7}]},
	{"title": "Династический брак", "text": "Соседний правитель предлагает союз через брак.", "choices": [{"text": "Согласиться (+5 одобрение)", "approval": 5}, {"text": "Отказать (+1500 золота приданого не будет, но +2% войск)", "troops_share": 0.02}]},
	{"title": "Падёж скота", "text": "Болезнь выкосила стада.", "choices": [{"text": "Компенсации (−2000 золота, +4 одобрение)", "gold": -2000, "approval": 4}, {"text": "Ничего не делать (−6 одобрение)", "approval": -6}]},
	{"title": "Партия требует пост", "text": "Крупная партия хочет место в кабинете.", "choices": [{"text": "Уступить (−1000 золота, +4 одобрение)", "gold": -1000, "approval": 4}, {"text": "Отказать (−4 одобрение)", "approval": -4}]},
	{"title": "Народ требует выборов", "text": "На площадях требуют голосования.", "choices": [{"text": "Пообещать (+6 одобрение)", "approval": 6}, {"text": "Отказать (−7 одобрение, +1000 золота штрафов)", "approval": -7, "gold": 1000}]},
	{"title": "Новый университет", "text": "Учёные просят денег на кафедры.", "choices": [{"text": "Финансировать (−2500 золота, технология +1)", "gold": -2500, "tech": 1}, {"text": "Не финансировать (−2 одобрение)", "approval": -2}]},
	{"title": "Вражеская пропаганда", "text": "Соседи распускают слухи о вас.", "choices": [{"text": "Опровергнуть (−1000 золота, +3 одобрение)", "gold": -1000, "approval": 3}, {"text": "Игнорировать (−4 одобрение)", "approval": -4}]},
	{"title": "Найден клад", "text": "Крестьяне откопали древние монеты.", "choices": [{"text": "Забрать в казну (+2000 золота, −2 одобрение)", "gold": 2000, "approval": -2}, {"text": "Оставить нашедшим (+4 одобрение)", "approval": 4}]},
	{"title": "Банковская паника", "text": "Вкладчики штурмуют банки.", "choices": [{"text": "Гарантировать вклады (−3000 золота, +5 одобрение)", "gold": -3000, "approval": 5}, {"text": "Пусть рынок разберётся (−7 одобрение)", "approval": -7}]},
	{"title": "Золотая лихорадка", "text": "В горах нашли золотую жилу, народ бросает поля.", "choices": [{"text": "Разрешить добычу (+3500 золота, −3% войск)", "gold": 3500, "troops_share": -0.03}, {"text": "Запретить (+3 одобрение)", "approval": 3}]},
	{"title": "Забастовка шахтёров", "text": "Шахты стоят.", "choices": [{"text": "Повысить оплату (−2000 золота, +4 одобрение)", "gold": -2000, "approval": 4}, {"text": "Прислать войска (−2% войск, −6 одобрение)", "troops_share": -0.02, "approval": -6}]},
	{"title": "Торговый караван", "text": "Через ваши земли идёт богатый караван.", "choices": [{"text": "Взять пошлину (+2500 золота)", "gold": 2500}, {"text": "Пропустить бесплатно (+4 одобрение)", "approval": 4}]},
	{"title": "Гастарбайтеры", "text": "Соседи предлагают рабочие руки.", "choices": [{"text": "Принять (+6% войск, −3 одобрение)", "troops_share": 0.06, "approval": -3}, {"text": "Отказать (+2 одобрение)", "approval": 2}]},
	{"title": "Великий архитектор", "text": "Мастер предлагает построить нечто великое.", "choices": [{"text": "Нанять (−4000 золота, +6 одобрение)", "gold": -4000, "approval": 6}, {"text": "Отказать", "approval": -1}]},
	{"title": "Лесной пожар", "text": "Горят леса на границе.", "choices": [{"text": "Тушить всей армией (−4% войск, +3 одобрение)", "troops_share": -0.04, "approval": 3}, {"text": "Пусть горит (−5 одобрение)", "approval": -5}]},
	{"title": "Рыцарский турнир", "text": "Знать просит устроить турнир.", "choices": [{"text": "Устроить (−1500 золота, +5 одобрение, +2% войск)", "gold": -1500, "approval": 5, "troops_share": 0.02}, {"text": "Отказать (−2 одобрение)", "approval": -2}]},
	{"title": "Пророк на площади", "text": "Бродячий проповедник собирает толпы.", "choices": [{"text": "Приблизить ко двору (+5 одобрение, налоги −1)", "approval": 5, "tax": -1}, {"text": "Изгнать (−3 одобрение, +1000 золота конфискаций)", "approval": -3, "gold": 1000}]},
	{"title": "Чума в соседней стране", "text": "Соседи просят лекарей.", "choices": [{"text": "Отправить помощь (−2000 золота, +4 одобрение)", "gold": -2000, "approval": 4}, {"text": "Закрыть границы (−2 одобрение, +3% войск беженцев нет)", "approval": -2}]},
	{"title": "Старый долг", "text": "Купцы напоминают о давнем займе короны.", "choices": [{"text": "Вернуть (−2500 золота, +3 одобрение)", "gold": -2500, "approval": 3}, {"text": "Отречься (−5 одобрение)", "approval": -5}]},
	{"title": "Сокровища затонувшего корабля", "text": "Рыбаки нашли обломки галеона.", "choices": [{"text": "Поднять (−1000 золота, +4000 золота)", "gold": 3000}, {"text": "Оставить морю (+2 одобрение)", "approval": 2}]},
	{"title": "Перепись скота", "text": "Чиновники предлагают пересчитать стада.", "choices": [{"text": "Провести (+1500 золота, −2 одобрение)", "gold": 1500, "approval": -2}, {"text": "Отменить (+2 одобрение)", "approval": 2}]},
	{"title": "Молодой гений", "text": "Юный изобретатель просит лабораторию.", "choices": [{"text": "Дать (−2000 золота, технология +1)", "gold": -2000, "tech": 1}, {"text": "Отказать (−1 одобрение)", "approval": -1}]},
	{"title": "Сборщики налогов проворовались", "text": "Казна недосчиталась золота.", "choices": [{"text": "Судить (+4 одобрение, −1000 золота)", "approval": 4, "gold": -1000}, {"text": "Закрыть глаза (+2000 золота, −5 одобрение)", "gold": 2000, "approval": -5}]},
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


## Total number of decisions available in the government panel.
static func item_count() -> int:
	var n := MINISTERS.size() + BILLS.size() + BUILDINGS.size() + EXTRA_TECHS.size() + BUDGET.size() * BUDGET_MAX + PROJECTS.size() + EXTRA_DECREES.size() + EXTRA_EVENTS.size()
	for axis in REFORMS:
		n += REFORMS[axis]["options"].size()
	return n
