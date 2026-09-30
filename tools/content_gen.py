# Generates scripts/sim/content.gd: all government content tables.
import json

def gd(v):
    """Python value -> GDScript literal."""
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int,)):
        return str(v)
    if isinstance(v, float):
        s = repr(v)
        return s if "." in s or "e" in s else s + ".0"
    if isinstance(v, str):
        return json.dumps(v, ensure_ascii=False)
    if isinstance(v, list):
        return "[" + ", ".join(gd(x) for x in v) + "]"
    if isinstance(v, dict):
        return "{" + ", ".join("%s: %s" % (gd(k), gd(x)) for k, x in v.items()) + "}"
    raise TypeError(v)

def table(name, rows, order_name=None, extra_fields=None):
    """rows: list of (key, dict). Emits const NAME := {...} and NAME_ORDER."""
    lines = ["const %s := {" % name]
    for key, d in rows:
        lines.append("\t%s: %s," % (gd(key), gd(d)))
    lines.append("}")
    if order_name:
        lines.append("const %s := %s" % (order_name, gd([k for k, _ in rows])))
    return "\n".join(lines)

CATEGORIES = [
    ("econ", "Экономика"), ("army", "Армия"), ("people", "Народ"), ("science", "Наука"),
    ("navy", "Флот"), ("state", "Государство"), ("empire", "Империя"), ("nature", "Природа"),
]

# ---------------------------------------------------------------- parties
PARTIES = [
    ("order", {"name": "Партия порядка", "color": "#F98BA9", "bonus": "+8% роста армии", "who": "казармы, защита, войны, бомбы", "mods": {"growth": 1.08}}),
    ("trade", {"name": "Торговый союз", "color": "#F4D77A", "bonus": "+10% золота", "who": "рынки, порты, налоги, торговля", "mods": {"gold": 1.10}}),
    ("people", {"name": "Народный фронт", "color": "#B7C96A", "bonus": "+6 к цели одобрения", "who": "низкие налоги, довольный народ", "mods": {"approval": 6.0}}),
    ("tech", {"name": "Технократы", "color": "#7FB9E6", "bonus": "−15% к цене технологий", "who": "технологии и города", "mods": {"tech_cost": 0.85}}),
    ("green", {"name": "Зелёные", "color": "#8FD3A0", "bonus": "+4 одобрение, стройки на 10% дешевле", "who": "мир без бомб, фермы, больницы", "mods": {"approval": 4.0, "build_cost": 0.9}}),
    ("empire", {"name": "Имперцы", "color": "#D6BEEA", "bonus": "захват на 8% дешевле", "who": "большая территория, войны, флот", "mods": {"capture": 0.92, "approval": -2.0}}),
]

# ---------------------------------------------------------------- ministers
def M(key, name, desc, fee, salary, mods, cat):
    return (key, {"name": name, "desc": desc, "fee": fee, "salary": float(salary), "cat": cat, "mods": mods})

MINISTERS = [
    M("finance", "Министр финансов", "+15% золота", 3000, 6, {"gold": 1.15}, "econ"),
    M("general", "Генерал", "Фронт продвигается на 20% быстрее", 4000, 8, {"attack_rate": 1.20}, "army"),
    M("diplomat", "Дипломат", "Боты нападают на вас заметно реже", 3500, 6, {"diplomacy": 1.0}, "state"),
    M("scientist", "Учёный", "Технологии на 20% дешевле", 3500, 5, {"tech_cost": 0.80}, "science"),
    M("propagandist", "Пропагандист", "+8 к цели одобрения", 2500, 5, {"approval": 8.0}, "people"),
    M("economist", "Министр экономики", "Постройки на 15% дешевле", 3000, 5, {"build_cost": 0.85}, "econ"),
    M("defense", "Министр обороны", "Ваши клетки на 15% дороже врагу", 4000, 7, {"defense": 1.15}, "army"),
    M("admiral", "Адмирал", "Корабли на 30% быстрее и дальше", 3500, 6, {"ship_speed": 1.3, "naval_reach": 1.3}, "navy"),
    M("culture", "Министр культуры", "+5 одобрение, −3% золота", 2500, 4, {"approval": 5.0, "gold": 0.97}, "people"),
    M("treasurer", "Казначей", "+8 золота в секунду", 2000, 3, {"gold_flat": 8.0}, "econ"),
    M("labor", "Министр труда", "+0.2% роста армии в секунду", 3000, 5, {"interest": 0.002}, "people"),
    M("spy", "Шеф разведки", "Захват чужого на 6% дешевле, +2 к защите", 4500, 7, {"capture": 0.94, "defense": 1.02}, "army"),
    M("speaker", "Спикер Госдумы", "+6 одобрение на выборах", 3000, 4, {"election": 6.0}, "state"),
    M("premier", "Премьер-министр", "+4% ко всему: золото, рост, лимит", 8000, 14, {"gold": 1.04, "growth": 1.04, "cap": 1.04}, "state"),
    M("interior", "Министр внутренних дел", "Волнения начинаются на 8 пунктов позже, −2 одобрение", 3500, 6, {"unrest": -8.0, "approval": -2.0}, "state"),
    M("education", "Министр образования", "Технологии на 10% дешевле, +2 одобрение", 3000, 5, {"tech_cost": 0.90, "approval": 2.0}, "science"),
    M("health", "Министр здравоохранения", "+4 одобрение, +3% роста армии", 3000, 5, {"approval": 4.0, "growth": 1.03}, "people"),
    M("agriculture", "Министр сельского хозяйства", "+6 золота в секунду, +3% роста армии", 2500, 4, {"gold_flat": 6.0, "growth": 1.03}, "econ"),
    M("industry", "Министр промышленности", "Постройки на 10% дешевле, +4 золота в секунду", 3500, 6, {"build_cost": 0.90, "gold_flat": 4.0}, "econ"),
    M("transport", "Министр транспорта", "Фронт на 8% быстрее, корабли на 10% быстрее", 3500, 6, {"attack_rate": 1.08, "ship_speed": 1.1}, "econ"),
    M("trade_min", "Министр торговли", "+8% золота", 3000, 5, {"gold": 1.08}, "econ"),
    M("colonies_min", "Министр колоний", "Захват на 5% дешевле, корабли на 15% дальше", 4500, 7, {"capture": 0.95, "naval_reach": 1.15}, "empire"),
    M("justice", "Министр юстиции", "Волнения позже, законы на 10% дешевле", 3000, 5, {"unrest": -4.0, "bill_cost": 0.9}, "state"),
    M("chief_of_staff", "Начальник Генштаба", "Фронт на 10% быстрее, +5% к лимиту армии", 5000, 9, {"attack_rate": 1.10, "cap": 1.05}, "army"),
    M("quartermaster", "Квартирмейстер", "+8% к лимиту армии", 3500, 6, {"cap": 1.08}, "army"),
    M("astrologer", "Придворный астролог", "+3 одобрение на выборах, +1 одобрение", 1500, 2, {"election": 3.0, "approval": 1.0}, "state"),
    M("chancellor", "Канцлер", "Указы на 30% и законы на 15% дешевле", 5000, 8, {"decree_cost": 0.7, "bill_cost": 0.85}, "state"),
    M("energy", "Министр энергетики", "+10 золота в секунду, постройки на 5% дешевле", 4500, 7, {"gold_flat": 10.0, "build_cost": 0.95}, "econ"),
    M("foreign", "Министр иностранных дел", "Отношения со всеми +10, пакты на 30% дешевле", 4000, 6, {"diplomacy": 0.8, "relation": 10.0, "pact_cost": 0.7}, "state"),
    M("sports_min", "Министр спорта", "+3 одобрение, +2% роста армии", 2500, 4, {"approval": 3.0, "growth": 1.02}, "people"),
    M("planning", "Председатель Госплана", "Бюджет на 20% дешевле, нацпроекты на 20% быстрее", 4500, 7, {"budget_cost": 0.8, "project_speed": 1.2}, "econ"),
    M("ecology", "Министр экологии", "+3 одобрение, волнения позже", 2500, 4, {"approval": 3.0, "unrest": -2.0}, "nature"),
    M("vice_premier", "Вице-премьер", "+2% золота и роста, зарплаты на 5% меньше", 6000, 10, {"gold": 1.02, "growth": 1.02, "salary_mult": 0.95}, "state"),
    M("navy_min", "Морской министр", "Корабли на 20% дальше, порты приносят больше", 3500, 6, {"naval_reach": 1.2, "gold_flat": 4.0}, "navy"),
    M("mayor", "Столичный градоначальник", "+2 одобрение, +5 золота в секунду", 2500, 4, {"approval": 2.0, "gold_flat": 5.0}, "people"),
    M("archivist", "Главный архивариус", "Технологии на 5% дешевле, законы на 5% дешевле", 2000, 3, {"tech_cost": 0.95, "bill_cost": 0.95}, "science"),
]

# ---------------------------------------------------------------- bills
def B(key, name, desc, cost, support, mods, cat, req="", excl=None, req_tech=""):
    d = {"name": name, "desc": desc, "cost": cost, "support": support, "cat": cat, "mods": mods}
    if req:
        d["req"] = req
    if excl:
        d["excl"] = excl
    if req_tech:
        d["req_tech"] = req_tech
    return (key, d)

BILLS = [
    # --- economy
    B("free_trade", "Свободная торговля", "+10% золота", 5000, ["trade", "tech"], {"gold": 1.10}, "econ", excl=["tariffs"]),
    B("luxury_tax", "Налог на роскошь", "+6% золота, −2 одобрение", 3000, ["people", "trade"], {"gold": 1.06, "approval": -2.0}, "econ"),
    B("no_duties", "Отмена пошлин", "+4 одобрение, −5% золота", 2500, ["trade", "people"], {"approval": 4.0, "gold": 0.95}, "econ"),
    B("bank_reform", "Банковская реформа", "+5 золота в секунду, +3% золота", 4500, ["trade", "tech"], {"gold_flat": 5.0, "gold": 1.03}, "econ"),
    B("public_works", "Общественные работы", "Постройки на 10% дешевле", 4000, ["people", "tech"], {"build_cost": 0.90}, "econ"),
    B("stock_exchange", "Биржа", "+8% золота", 7000, ["trade", "tech"], {"gold": 1.08}, "econ", req="bank_reform"),
    B("gold_standard", "Золотой стандарт", "+5% золота, −3% роста армии", 5000, ["trade", "order"], {"gold": 1.05, "growth": 0.97}, "econ"),
    B("tariffs", "Протекционизм", "+10 золота в секунду, −2 одобрение", 4000, ["trade", "order"], {"gold_flat": 10.0, "approval": -2.0}, "econ", excl=["free_trade"]),
    B("guilds", "Гильдии", "Постройки на 5% дешевле, +2% золота", 3500, ["trade", "people"], {"build_cost": 0.95, "gold": 1.02}, "econ"),
    B("mint", "Монетный двор", "+6 золота в секунду", 3000, ["trade", "tech"], {"gold_flat": 6.0}, "econ"),
    B("income_tax", "Подоходный налог", "+8% золота, −4 одобрение", 4500, ["trade", "order"], {"gold": 1.08, "approval": -4.0}, "econ"),
    B("vat", "Налог с продаж", "+6% золота, −3 одобрение", 4000, ["trade", "tech"], {"gold": 1.06, "approval": -3.0}, "econ"),
    B("tax_amnesty", "Налоговая амнистия", "+5 одобрение, −4% золота", 2500, ["people", "trade"], {"approval": 5.0, "gold": 0.96}, "econ"),
    B("salt_monopoly", "Соляная монополия", "+10 золота в секунду, −2 одобрение", 3500, ["empire", "trade"], {"gold_flat": 10.0, "approval": -2.0}, "econ"),
    B("corp_law", "Закон об акционерных обществах", "+5% золота", 4500, ["tech", "trade"], {"gold": 1.05}, "econ", req="stock_exchange"),
    B("ports_free", "Свободные порты", "Корабли на 12% быстрее, +2% золота", 4000, ["trade", "empire"], {"ship_speed": 1.12, "gold": 1.02}, "econ"),
    B("roads", "Дорожный фонд", "Фронт на 6% быстрее, постройки на 5% дешевле", 4500, ["trade", "tech"], {"attack_rate": 1.06, "build_cost": 0.95}, "econ"),
    B("credit", "Дешёвый кредит", "Постройки на 12% дешевле, −2% золота", 5000, ["trade", "people"], {"build_cost": 0.88, "gold": 0.98}, "econ"),
    B("insurance", "Страхование", "Волнения позже, +2% золота", 3500, ["trade", "tech"], {"unrest": -3.0, "gold": 1.02}, "econ"),
    B("antitrust", "Антимонопольный закон", "+4 одобрение, −2% золота", 3000, ["people", "tech"], {"approval": 4.0, "gold": 0.98}, "econ"),
    B("pension_fund", "Пенсионный фонд", "+3 одобрение, +3 на выборах, −3% золота", 4000, ["people", "trade"], {"approval": 3.0, "election": 3.0, "gold": 0.97}, "econ", req="pensions"),
    B("child_benefits", "Детские пособия", "+4 одобрение, +2% роста, −4% золота", 4500, ["people", "green"], {"approval": 4.0, "growth": 1.02, "gold": 0.96}, "econ"),
    B("cooperatives", "Кооперативы", "+4 золота в секунду, +2 одобрение", 3000, ["green", "people"], {"gold_flat": 4.0, "approval": 2.0}, "econ"),
    B("state_bank", "Госбанк", "+8 золота в секунду, зарплаты на 10% меньше", 5500, ["order", "trade"], {"gold_flat": 8.0, "salary_mult": 0.9}, "econ"),
    B("budget_rule", "Бюджетное правило", "Бюджет на 20% дешевле", 4000, ["tech", "trade"], {"budget_cost": 0.8}, "econ"),
    B("lean_gov", "Сокращение аппарата", "Зарплаты на 20% меньше, −2 одобрение", 3500, ["trade", "tech"], {"salary_mult": 0.8, "approval": -2.0}, "econ"),
    B("civil_service", "Табель о рангах", "Зарплаты на 10% меньше, +2 на выборах", 3000, ["order", "tech"], {"salary_mult": 0.9, "election": 2.0}, "econ"),
    B("export_bonus", "Экспортные премии", "+5% золота при портах: +4 золота в секунду", 3500, ["trade", "empire"], {"gold": 1.03, "gold_flat": 4.0}, "econ"),
    # --- army
    B("army_reform", "Военная реформа", "+10% к лимиту армии", 5000, ["order", "tech"], {"cap": 1.10}, "army"),
    B("pro_army", "Профессиональная армия", "+12% к лимиту, −4% золота", 5500, ["order", "tech"], {"cap": 1.12, "gold": 0.96}, "army", excl=["militia"]),
    B("conscription", "Всеобщая воинская обязанность", "+0.4% роста армии в секунду, −6 одобрение", 5000, ["order", "empire"], {"interest": 0.004, "approval": -6.0}, "army"),
    B("emergency", "Чрезвычайное положение", "+20% роста армии, −10 к цели одобрения", 6000, ["order", "empire"], {"growth": 1.20, "approval": -10.0}, "army", excl=["demob"]),
    B("logistics_corps", "Логистический корпус", "Фронт продвигается на 10% быстрее", 4500, ["order", "trade"], {"attack_rate": 1.10}, "army"),
    B("border_forts", "Крепости на границе", "+15% к защите, −3% золота", 6000, ["order", "empire"], {"defense": 1.15, "gold": 0.97}, "army"),
    B("nuclear_shield", "Ядерный щит", "Бункеры сбивают бомбы на 8 клеток дальше", 6000, ["order", "tech"], {"shield": 8.0}, "army"),
    B("officer_school", "Офицерская школа", "Фронт на 8% быстрее", 4000, ["order", "tech"], {"attack_rate": 1.08}, "army"),
    B("reserves", "Резервисты", "+8% к лимиту армии", 4000, ["order", "people"], {"cap": 1.08}, "army"),
    B("militia", "Ополчение", "+5% к лимиту, +2 одобрение", 3000, ["people", "order"], {"cap": 1.05, "approval": 2.0}, "army", excl=["pro_army"]),
    B("war_tax", "Военный налог", "+6% золота, −3 одобрение", 3500, ["order", "empire"], {"gold": 1.06, "approval": -3.0}, "army"),
    B("veterans", "Льготы ветеранам", "+4 одобрение, −3% золота", 3000, ["order", "people"], {"approval": 4.0, "gold": 0.97}, "army"),
    B("military_industry", "Военно-промышленный комплекс", "+0.2% роста армии в секунду, −3% золота", 5000, ["order", "tech"], {"interest": 0.002, "gold": 0.97}, "army"),
    B("general_staff", "Реформа Генштаба", "Фронт на 10% быстрее, зарплаты +10%", 5000, ["order", "empire"], {"attack_rate": 1.10, "salary_mult": 1.1}, "army", req="officer_school"),
    B("cavalry", "Кавалерийский устав", "Захват на 5% дешевле", 4000, ["order", "empire"], {"capture": 0.95}, "army"),
    B("trenches", "Окопная доктрина", "+10% к защите, фронт на 5% медленнее", 3500, ["order", "green"], {"defense": 1.10, "attack_rate": 0.95}, "army", excl=["blitz"]),
    B("blitz", "Доктрина прорыва", "Фронт на 15% быстрее, −5% к защите", 5000, ["order", "empire"], {"attack_rate": 1.15, "defense": 0.95}, "army", excl=["trenches"]),
    B("war_bonds", "Военные облигации", "+10 золота в секунду, −3 одобрение", 4000, ["order", "trade"], {"gold_flat": 10.0, "approval": -3.0}, "army"),
    B("drill", "Всеобщая военная подготовка", "+0.15% роста армии в секунду, −2 одобрение", 3500, ["order", "people"], {"interest": 0.0015, "approval": -2.0}, "army"),
    B("garrisons", "Гарнизоны", "+8% к защите, −3 золота в секунду", 3000, ["order", "empire"], {"defense": 1.08, "gold_flat": -3.0}, "army"),
    B("field_hospitals", "Полевые госпитали", "+5% роста армии, +1 одобрение", 3500, ["green", "order"], {"growth": 1.05, "approval": 1.0}, "army"),
    B("war_academy", "Военная академия", "Фронт на 6% быстрее, технологии на 5% дешевле", 4500, ["tech", "order"], {"attack_rate": 1.06, "tech_cost": 0.95}, "army"),
    B("demob", "Демобилизация", "+8 одобрение, −10% к лимиту армии", 2500, ["people", "green"], {"approval": 8.0, "cap": 0.90}, "army", excl=["emergency"]),
    B("mercenaries", "Наёмники", "+8% к лимиту армии, +6 золота в секунду расходов", 4000, ["order", "trade"], {"cap": 1.08, "salary": 6.0}, "army"),
    B("fortress_towns", "Города-крепости", "+6% к защите, +1 одобрение", 4000, ["order", "tech"], {"defense": 1.06, "approval": 1.0}, "army"),
    B("air_defense", "Противовоздушная оборона", "Бункеры сбивают бомбы ещё на 6 клеток дальше", 5000, ["order", "tech"], {"shield": 6.0}, "army", req="nuclear_shield"),
    B("nuclear_doctrine", "Ядерная доктрина", "Бомбы на 20% дешевле, −4 одобрение", 8000, ["order", "empire"], {"nuke_cost": 0.8, "approval": -4.0}, "army", excl=["disarmament"]),
    B("prohibition", "Сухой закон", "+3% роста армии, −5 одобрение", 2500, ["order", "tech"], {"growth": 1.03, "approval": -5.0}, "army"),
    B("sappers", "Инженерные войска", "Захват гор и лесов… любой земли на 4% дешевле", 3500, ["order", "tech"], {"capture": 0.96}, "army"),
    # --- navy
    B("navy_program", "Флотская программа", "Корабли на 25% быстрее", 4000, ["empire", "trade"], {"ship_speed": 1.25}, "navy"),
    B("coast_defense", "Береговая оборона", "Ваши клетки на 10% дороже врагу", 4500, ["order", "green"], {"defense": 1.10}, "navy"),
    B("admiralty", "Адмиралтейство", "Корабли на 20% дальше", 4500, ["empire", "order"], {"naval_reach": 1.2}, "navy"),
    B("merchant_fleet", "Торговый флот", "+8 золота в секунду, +2% золота", 4000, ["trade", "empire"], {"gold_flat": 8.0, "gold": 1.02}, "navy"),
    B("marines", "Морская пехота", "Захват на 5% дешевле, корабли на 10% быстрее", 5000, ["empire", "order"], {"capture": 0.95, "ship_speed": 1.1}, "navy", req="navy_program"),
    B("lighthouses", "Маяки", "Корабли на 10% быстрее, +1 одобрение", 2500, ["trade", "green"], {"ship_speed": 1.1, "approval": 1.0}, "navy"),
    B("fishing", "Рыбный промысел", "+5 золота в секунду, +1 одобрение", 2000, ["green", "trade"], {"gold_flat": 5.0, "approval": 1.0}, "navy"),
    B("naval_academy", "Морская академия", "Корабли на 15% дальше, технологии на 3% дешевле", 4000, ["tech", "empire"], {"naval_reach": 1.15, "tech_cost": 0.97}, "navy"),
    B("privateers", "Каперство", "+8 золота в секунду, −2 одобрение", 3500, ["empire", "trade"], {"gold_flat": 8.0, "approval": -2.0}, "navy"),
    B("canal_law", "Закон о каналах", "Корабли на 15% быстрее, постройки на 3% дешевле", 4500, ["tech", "trade"], {"ship_speed": 1.15, "build_cost": 0.97}, "navy"),
    B("sea_patrol", "Морские патрули", "+5% к защите, корабли на 5% дальше", 3500, ["order", "trade"], {"defense": 1.05, "naval_reach": 1.05}, "navy"),
    # --- people
    B("social", "Социальный пакет", "+8 к цели одобрения, −5% золота", 4000, ["people", "trade"], {"approval": 8.0, "gold": 0.95}, "people"),
    B("free_medicine", "Бесплатная медицина", "+6 одобрение, −6% золота", 4500, ["people", "green"], {"approval": 6.0, "gold": 0.94}, "people"),
    B("pensions", "Пенсионная реформа", "+5 одобрение, −5% золота", 4000, ["people", "trade"], {"approval": 5.0, "gold": 0.95}, "people"),
    B("eight_hours", "Восьмичасовой рабочий день", "+4 одобрение, −3% роста", 3000, ["people", "green"], {"approval": 4.0, "growth": 0.97}, "people"),
    B("free_speech", "Свобода слова", "+3 одобрение, волнения начинаются позже", 3000, ["people", "green"], {"approval": 3.0, "unrest": -5.0}, "people", excl=["censorship"]),
    B("election_reform", "Избирательная реформа", "+5 одобрение на выборах", 3500, ["people", "tech"], {"election": 5.0}, "people"),
    B("green_deal", "Зелёный курс", "+5 одобрение, −2% роста армии", 3500, ["green", "people"], {"approval": 5.0, "growth": 0.98}, "people"),
    B("schools", "Всеобщее образование", "+3 одобрение, технологии на 5% дешевле", 4000, ["people", "tech"], {"approval": 3.0, "tech_cost": 0.95}, "people"),
    B("housing", "Жилищная программа", "+5 одобрение, −4% золота", 4500, ["people", "green"], {"approval": 5.0, "gold": 0.96}, "people"),
    B("min_wage", "Минимальная зарплата", "+4 одобрение, −3% золота", 3000, ["people", "order"], {"approval": 4.0, "gold": 0.97}, "people"),
    B("unions", "Профсоюзы", "+3 одобрение, волнения позже", 3000, ["people", "green"], {"approval": 3.0, "unrest": -4.0}, "people"),
    B("equal_rights", "Равные права", "+4 одобрение, +3% роста армии", 3500, ["people", "tech"], {"approval": 4.0, "growth": 1.03}, "people"),
    B("public_transport", "Общественный транспорт", "+3 одобрение, фронт на 3% быстрее", 4000, ["green", "people"], {"approval": 3.0, "attack_rate": 1.03}, "people"),
    B("libraries", "Библиотеки", "+2 одобрение, технологии на 4% дешевле", 2500, ["tech", "people"], {"approval": 2.0, "tech_cost": 0.96}, "people"),
    B("theatres", "Театры и музеи", "+4 одобрение, −2% золота", 3000, ["people", "green"], {"approval": 4.0, "gold": 0.98}, "people"),
    B("sports", "Спортивный закон", "+3 одобрение, +2% роста армии", 3000, ["people", "order"], {"approval": 3.0, "growth": 1.02}, "people"),
    B("holidays", "Праздничные дни", "+5 одобрение, −3% золота, −2% роста", 2500, ["people", "green"], {"approval": 5.0, "gold": 0.97, "growth": 0.98}, "people"),
    B("censorship", "Цензура", "−3 одобрение, +5 на выборах, волнения позже", 3000, ["order", "empire"], {"approval": -3.0, "election": 5.0, "unrest": -6.0}, "people", excl=["free_speech"]),
    B("secret_police", "Тайная полиция", "Волнения начинаются намного позже, −6 одобрение", 4500, ["order", "empire"], {"unrest": -10.0, "approval": -6.0}, "people"),
    B("referendums", "Референдумы", "+3 одобрение, +4 на выборах", 3500, ["people", "green"], {"approval": 3.0, "election": 4.0}, "people"),
    B("elderly_care", "Уход за пожилыми", "+3 одобрение, −2% золота", 3000, ["people", "green"], {"approval": 3.0, "gold": 0.98}, "people"),
    B("clean_water", "Чистая вода", "+3 одобрение, +2% роста армии", 3500, ["green", "tech"], {"approval": 3.0, "growth": 1.02}, "people"),
    B("vaccination", "Вакцинация", "+4% роста армии, +1 одобрение", 4000, ["tech", "green"], {"growth": 1.04, "approval": 1.0}, "people", req="free_medicine"),
    B("anti_corruption", "Антикоррупционный закон", "+4 одобрение, зарплаты на 10% меньше", 4000, ["people", "tech"], {"approval": 4.0, "salary_mult": 0.9}, "people"),
    B("welfare", "Пособия по безработице", "+5 одобрение, −5% золота", 4000, ["people", "green"], {"approval": 5.0, "gold": 0.95}, "people"),
    B("orphanages", "Приюты", "+2 одобрение, +1% роста армии", 2000, ["people", "green"], {"approval": 2.0, "growth": 1.01}, "people"),
    B("prison_reform", "Реформа тюрем", "+2 одобрение, волнения позже", 2500, ["people", "tech"], {"approval": 2.0, "unrest": -3.0}, "people"),
    B("bread_price", "Твёрдые цены на хлеб", "+4 одобрение, −4 золота в секунду", 2000, ["people", "order"], {"approval": 4.0, "gold_flat": -4.0}, "people"),
    # --- science
    B("science", "Наука в приоритете", "−20% к цене технологий", 4000, ["tech", "people"], {"tech_cost": 0.80}, "science"),
    B("universities", "Университеты", "−10% к цене технологий, +2 одобрение", 4500, ["tech", "green"], {"tech_cost": 0.90, "approval": 2.0}, "science"),
    B("patents", "Патентное право", "Технологии на 8% дешевле, +2% золота", 4000, ["tech", "trade"], {"tech_cost": 0.92, "gold": 1.02}, "science"),
    B("academy", "Академия наук", "Технологии на 10% дешевле, +4 золота в секунду расходов", 5000, ["tech", "people"], {"tech_cost": 0.90, "salary": 4.0}, "science", req="universities"),
    B("observatory_law", "Обсерватории", "Корабли на 10% дальше, технологии на 3% дешевле", 3500, ["tech", "empire"], {"naval_reach": 1.1, "tech_cost": 0.97}, "science"),
    B("engineering", "Инженерный корпус", "Постройки на 10% дешевле, фронт на 4% быстрее", 4500, ["tech", "order"], {"build_cost": 0.90, "attack_rate": 1.04}, "science"),
    B("metric", "Метрическая система", "+3% золота, постройки на 3% дешевле", 3000, ["tech", "trade"], {"gold": 1.03, "build_cost": 0.97}, "science"),
    B("printing", "Книгопечатание", "+2 одобрение, технологии на 5% дешевле, +2 на выборах", 3500, ["tech", "people"], {"approval": 2.0, "tech_cost": 0.95, "election": 2.0}, "science"),
    B("expeditions", "Научные экспедиции", "Корабли на 15% дальше, технологии на 3% дешевле", 4000, ["tech", "green"], {"naval_reach": 1.15, "tech_cost": 0.97}, "science"),
    B("grants", "Гранты учёным", "Технологии на 10% дешевле, −4 золота в секунду", 3500, ["tech", "green"], {"tech_cost": 0.90, "gold_flat": -4.0}, "science"),
    B("tech_schools", "Технические училища", "+0.1% роста армии в секунду, технологии на 4% дешевле", 4000, ["tech", "order"], {"interest": 0.001, "tech_cost": 0.96}, "science"),
    B("open_science", "Открытая наука", "Технологии на 7% дешевле, +2 одобрение", 4500, ["tech", "people"], {"tech_cost": 0.93, "approval": 2.0}, "science", req="academy"),
    B("space_law", "Закон о космосе", "Корабли на 20% дальше и 10% быстрее, технологии на 5% дешевле", 9000, ["tech", "empire"], {"naval_reach": 1.2, "ship_speed": 1.1, "tech_cost": 0.95}, "science", req_tech="rockets"),
    B("statistics", "Статистическое бюро", "+2% золота, бюджет на 10% дешевле", 3000, ["tech", "trade"], {"gold": 1.02, "budget_cost": 0.9}, "science"),
    # --- state
    B("cheap_decrees", "Реформа канцелярии", "Указы на 30% дешевле", 3000, ["tech", "trade"], {"decree_cost": 0.7}, "state"),
    B("constitution", "Конституция", "+5 одобрение, +5 на выборах, волнения позже", 8000, ["people", "tech"], {"approval": 5.0, "election": 5.0, "unrest": -5.0}, "state"),
    B("federation", "Федерация", "+3 одобрение, захват на 3% дешевле", 6000, ["empire", "people"], {"approval": 3.0, "capture": 0.97}, "state", excl=["centralization"]),
    B("centralization", "Централизация", "Указы на 20% и бюджет на 10% дешевле, −2 одобрение", 5000, ["order", "tech"], {"decree_cost": 0.8, "budget_cost": 0.9, "approval": -2.0}, "state", excl=["federation"]),
    B("meritocracy", "Меритократия", "Зарплаты на 15% меньше, технологии на 3% дешевле", 4000, ["tech", "trade"], {"salary_mult": 0.85, "tech_cost": 0.97}, "state"),
    B("term_limits", "Ограничение сроков", "+4 на выборах, +2 одобрение", 3000, ["people", "green"], {"election": 4.0, "approval": 2.0}, "state"),
    B("state_media", "Государственные СМИ", "+6 на выборах, −2 одобрение", 3500, ["order", "empire"], {"election": 6.0, "approval": -2.0}, "state"),
    B("transparency", "Открытое правительство", "+3 одобрение, зарплаты на 5% меньше", 3500, ["people", "tech"], {"approval": 3.0, "salary_mult": 0.95}, "state"),
    B("census", "Перепись населения", "+3% золота, +2% роста армии", 3000, ["tech", "trade"], {"gold": 1.03, "growth": 1.02}, "state"),
    B("civil_code", "Гражданский кодекс", "+2 одобрение, +2% золота, волнения позже", 4000, ["tech", "people"], {"approval": 2.0, "gold": 1.02, "unrest": -2.0}, "state"),
    B("customs_union", "Таможенный союз", "+4% золота, боты нападают реже", 5000, ["trade", "green"], {"gold": 1.04, "diplomacy": 0.3}, "state"),
    B("propaganda_ministry", "Министерство пропаганды", "Указы на 30% дешевле, +4 на выборах", 4000, ["order", "empire"], {"decree_cost": 0.7, "election": 4.0}, "state"),
    B("audit", "Счётная палата", "Бюджет на 15% дешевле, зарплаты на 5% меньше", 4500, ["tech", "trade"], {"budget_cost": 0.85, "salary_mult": 0.95}, "state"),
    B("regional_councils", "Земства", "+3 одобрение, постройки на 5% дешевле", 4000, ["people", "green"], {"approval": 3.0, "build_cost": 0.95}, "state"),
    B("national_bank", "Национальный банк", "+4% золота, законы на 10% дешевле", 5000, ["trade", "tech"], {"gold": 1.04, "bill_cost": 0.9}, "state", req="bank_reform"),
    B("chancellery", "Реформа делопроизводства", "Законы на 20% дешевле", 3500, ["tech", "order"], {"bill_cost": 0.8}, "state"),
    B("diplomacy_corps", "Дипломатический корпус", "Боты нападают реже", 5000, ["trade", "green"], {"diplomacy": 0.6}, "state"),
    B("peace_treaties", "Мирные договоры", "Отношения со всеми +8, пакты на 20% дешевле", 4000, ["green", "trade"], {"relation": 8.0, "pact_cost": 0.8}, "state"),
    B("civil_defense", "Гражданская оборона", "Волнения позже, бункеры на 3 клетки дальше", 3500, ["order", "green"], {"unrest": -3.0, "shield": 3.0}, "state"),
    B("national_projects", "Закон о нацпроектах", "Нацпроекты идут на 25% быстрее", 5000, ["tech", "people"], {"project_speed": 1.25}, "state"),
    # --- empire
    B("land_reform", "Земельная реформа", "Захват любой земли на 8% дешевле", 5500, ["empire", "people"], {"capture": 0.92}, "empire"),
    B("resettlement", "Программа переселения", "+6% роста армии", 4000, ["empire", "people"], {"growth": 1.06}, "empire"),
    B("imperial_edict", "Имперский эдикт", "Захват чужого на 10% дешевле, −4 одобрение", 6500, ["empire", "order"], {"capture": 0.90, "approval": -4.0}, "empire"),
    B("colonies", "Колониальная хартия", "Захват на 6% дешевле, корабли на 10% дальше", 6000, ["empire", "trade"], {"capture": 0.94, "naval_reach": 1.1}, "empire"),
    B("frontier", "Освоение окраин", "+4% роста армии, захват на 4% дешевле", 5000, ["empire", "people"], {"growth": 1.04, "capture": 0.96}, "empire"),
    B("tribute", "Дань с покорённых", "+10 золота в секунду, −3 одобрение", 4500, ["empire", "order"], {"gold_flat": 10.0, "approval": -3.0}, "empire"),
    B("assimilation", "Ассимиляция", "Волнения позже, +2% роста армии", 4000, ["empire", "order"], {"unrest": -5.0, "growth": 1.02}, "empire"),
    B("imperial_roads", "Имперские дороги", "Фронт на 8% быстрее, постройки на 5% дешевле", 5500, ["empire", "tech"], {"attack_rate": 1.08, "build_cost": 0.95}, "empire"),
    B("expansion_act", "Акт о расширении", "Захват на 7% дешевле, −3 одобрение", 7000, ["empire", "order"], {"capture": 0.93, "approval": -3.0}, "empire", req="imperial_edict"),
    B("vassals", "Вассальные договоры", "Боты нападают реже, +3% золота", 5000, ["empire", "trade"], {"diplomacy": 0.5, "gold": 1.03}, "empire"),
    B("great_wall_law", "Пограничный вал", "+12% к защите, −5 золота в секунду", 6500, ["empire", "order"], {"defense": 1.12, "gold_flat": -5.0}, "empire"),
    B("manifest", "Манифест величия", "+4 одобрение, +3 на выборах, захват на 2% дешевле", 4500, ["empire", "people"], {"approval": 4.0, "election": 3.0, "capture": 0.98}, "empire"),
    B("settlers", "Переселенцы", "+3% роста армии, +5% к лимиту", 4500, ["empire", "green"], {"growth": 1.03, "cap": 1.05}, "empire"),
    B("protectorates", "Протектораты", "Отношения +5, захват на 3% дешевле", 5000, ["empire", "green"], {"relation": 5.0, "capture": 0.97}, "empire"),
    # --- nature
    B("disarmament", "Ядерное разоружение", "Бомбы вдвое дороже, +6 одобрение", 3000, ["green", "people"], {"nuke_cost": 2.0, "approval": 6.0}, "nature", excl=["nuclear_doctrine"]),
    B("forests", "Охрана лесов", "+3 одобрение, захват на 2% дороже", 2500, ["green", "people"], {"approval": 3.0, "capture": 1.02}, "nature"),
    B("parks", "Национальные парки", "+4 одобрение, −2% золота", 3000, ["green", "people"], {"approval": 4.0, "gold": 0.98}, "nature"),
    B("clean_air", "Чистый воздух", "+3 одобрение, +2% роста армии", 3500, ["green", "tech"], {"approval": 3.0, "growth": 1.02}, "nature"),
    B("recycling", "Переработка отходов", "+2 золота в секунду, +2 одобрение", 3000, ["green", "tech"], {"gold_flat": 2.0, "approval": 2.0}, "nature"),
    B("organic", "Органическое земледелие", "+3 одобрение, +2% роста, −2% золота", 3000, ["green", "people"], {"approval": 3.0, "growth": 1.02, "gold": 0.98}, "nature"),
    B("wind_power", "Ветряные мельницы", "+4 золота в секунду, постройки на 3% дешевле", 3500, ["green", "tech"], {"gold_flat": 4.0, "build_cost": 0.97}, "nature"),
    B("animal_rights", "Защита животных", "+2 одобрение", 2000, ["green", "people"], {"approval": 2.0}, "nature"),
    B("nuclear_ban", "Запрет ядерных испытаний", "Бомбы в полтора раза дороже, +4 одобрение, боты нападают реже", 4000, ["green", "people"], {"nuke_cost": 1.5, "approval": 4.0, "diplomacy": 0.3}, "nature", req="disarmament"),
    B("green_cities", "Зелёные города", "+3 одобрение, +3% к лимиту армии", 4000, ["green", "tech"], {"approval": 3.0, "cap": 1.03}, "nature"),
    B("water_law", "Водный кодекс", "+2 одобрение, корабли на 5% быстрее", 3000, ["green", "trade"], {"approval": 2.0, "ship_speed": 1.05}, "nature"),
    B("soil_care", "Охрана почв", "+3 золота в секунду, +1 одобрение", 2500, ["green", "people"], {"gold_flat": 3.0, "approval": 1.0}, "nature"),
]

# ---------------------------------------------------------------- buildings
def BD(key, name, desc, cost, mods, cat, party, coast=False):
    return (key, {"name": name, "desc": desc, "cost": cost, "coast": coast, "cat": cat, "party": party, "mods": mods})

BUILDINGS = [
    BD("farm", "Ферма", "+6 золота в секунду, +1 одобрение", 2000, {"gold_flat": 6.0, "approval": 1.0}, "econ", "green"),
    BD("mine", "Шахта", "+12 золота в секунду, −1 одобрение", 3500, {"gold_flat": 12.0, "approval": -1.0}, "econ", "trade"),
    BD("bank", "Банк", "+5% золота", 5000, {"gold": 1.05}, "econ", "trade"),
    BD("customs", "Таможня", "+4% золота (на берегу)", 3500, {"gold": 1.04}, "econ", "trade", coast=True),
    BD("casino", "Казино", "+15 золота в секунду, −3 одобрение", 4000, {"gold_flat": 15.0, "approval": -3.0}, "econ", "trade"),
    BD("workshop", "Мастерская", "+8 золота в секунду", 2500, {"gold_flat": 8.0}, "econ", "trade"),
    BD("warehouse", "Склад", "+5 золота в секунду, волнения позже", 2800, {"gold_flat": 5.0, "unrest": -2.0}, "econ", "trade"),
    BD("market_hall", "Торговые ряды", "+4% золота", 4500, {"gold": 1.04}, "econ", "trade"),
    BD("brewery", "Пивоварня", "+7 золота в секунду, +1 одобрение", 3000, {"gold_flat": 7.0, "approval": 1.0}, "econ", "people"),
    BD("vineyard", "Виноградник", "+6 золота в секунду, +1 одобрение", 2500, {"gold_flat": 6.0, "approval": 1.0}, "econ", "green"),
    BD("sawmill", "Лесопилка", "+9 золота в секунду, −1 одобрение", 3000, {"gold_flat": 9.0, "approval": -1.0}, "econ", "trade"),
    BD("quarry", "Каменоломня", "Постройки на 4% дешевле, +4 золота в секунду", 3500, {"build_cost": 0.96, "gold_flat": 4.0}, "econ", "trade"),
    BD("foundry", "Литейная", "+10 золота в секунду, +200 к лимиту армии", 4500, {"gold_flat": 10.0, "cap_flat": 200.0}, "econ", "order"),
    BD("trading_post", "Фактория", "+6% золота (на берегу)", 4000, {"gold": 1.06}, "econ", "trade", coast=True),
    BD("oil_well", "Нефтяная вышка", "+20 золота в секунду, −3 одобрение", 7000, {"gold_flat": 20.0, "approval": -3.0}, "econ", "trade"),
    BD("toll_road", "Платная дорога", "+6 золота в секунду, фронт на 2% быстрее", 3500, {"gold_flat": 6.0, "attack_rate": 1.02}, "econ", "trade"),
    BD("mill", "Мельница", "+5 золота в секунду, +1 одобрение", 2000, {"gold_flat": 5.0, "approval": 1.0}, "econ", "green"),
    BD("treasury", "Казначейство", "+3% золота", 5000, {"gold": 1.03}, "econ", "trade"),
    BD("granary", "Амбар", "Волнения начинаются позже, +2 одобрение", 2500, {"unrest": -4.0, "approval": 2.0}, "people", "green"),
    BD("hospital", "Больница", "+3 одобрение", 3000, {"approval": 3.0}, "people", "green"),
    BD("temple", "Храм", "+4 одобрение, −2% роста армии", 2500, {"approval": 4.0, "growth": 0.98}, "people", "people"),
    BD("stadium", "Стадион", "+5 одобрение", 6000, {"approval": 5.0}, "people", "people"),
    BD("palace", "Дворец", "+3 одобрение, +4 на выборах", 7000, {"approval": 3.0, "election": 4.0}, "people", "empire"),
    BD("school", "Школа", "+2 одобрение, технологии на 2% дешевле", 2500, {"approval": 2.0, "tech_cost": 0.98}, "people", "tech"),
    BD("theatre", "Театр", "+3 одобрение", 3000, {"approval": 3.0}, "people", "people"),
    BD("bathhouse", "Бани", "+2 одобрение, +1% роста армии", 2000, {"approval": 2.0, "growth": 1.01}, "people", "people"),
    BD("orphanage", "Приют", "+2 одобрение", 1800, {"approval": 2.0}, "people", "people"),
    BD("park", "Парк", "+2 одобрение", 1500, {"approval": 2.0}, "people", "green"),
    BD("monument", "Монумент", "+2 одобрение, +3 на выборах", 3500, {"approval": 2.0, "election": 3.0}, "people", "empire"),
    BD("library", "Библиотека", "+1 одобрение, технологии на 3% дешевле", 2500, {"approval": 1.0, "tech_cost": 0.97}, "people", "tech"),
    BD("clinic", "Поликлиника", "+2 одобрение, +1% роста армии", 2500, {"approval": 2.0, "growth": 1.01}, "people", "green"),
    BD("square", "Площадь", "+2 одобрение, +2 золота в секунду", 2000, {"approval": 2.0, "gold_flat": 2.0}, "people", "people"),
    BD("prison", "Тюрьма", "Волнения намного позже, −1 одобрение", 3000, {"unrest": -5.0, "approval": -1.0}, "people", "order"),
    BD("town_hall", "Ратуша", "+2 одобрение, +2 на выборах", 3500, {"approval": 2.0, "election": 2.0}, "people", "people"),
    BD("arsenal", "Арсенал", "+600 к лимиту армии", 3500, {"cap_flat": 600.0}, "army", "empire"),
    BD("hq", "Штаб", "Фронт продвигается на 10% быстрее", 5000, {"attack_rate": 1.10}, "army", "order"),
    BD("fortress", "Крепость", "Ваши клетки на 12% дороже врагу", 5000, {"defense": 1.12}, "army", "order"),
    BD("radar", "Радар", "Бункеры сбивают бомбы на 6 клеток дальше", 4500, {"shield": 6.0}, "army", "tech"),
    BD("watchtower", "Сторожевая башня", "+5% к защите", 1800, {"defense": 1.05}, "army", "order"),
    BD("armory", "Оружейная", "+400 к лимиту армии", 2500, {"cap_flat": 400.0}, "army", "order"),
    BD("mil_academy", "Кадетский корпус", "Фронт на 5% быстрее, +2% роста армии", 5000, {"attack_rate": 1.05, "growth": 1.02}, "army", "order"),
    BD("garrison", "Гарнизон", "+8% к защите, −2 золота в секунду", 3500, {"defense": 1.08, "gold_flat": -2.0}, "army", "order"),
    BD("supply_depot", "Склад снабжения", "Фронт на 6% быстрее", 4000, {"attack_rate": 1.06}, "army", "order"),
    BD("airfield", "Аэродром", "Фронт на 8% быстрее, корабли на 10% дальше", 6000, {"attack_rate": 1.08, "naval_reach": 1.1}, "army", "order"),
    BD("silo", "Ракетная шахта", "Бомбы на 10% дешевле, бункеры на 3 клетки дальше", 8000, {"nuke_cost": 0.9, "shield": 3.0}, "army", "order"),
    BD("training_ground", "Полигон", "+0.1% роста армии в секунду", 3000, {"interest": 0.001}, "army", "order"),
    BD("university", "Университет", "Технологии на 8% дешевле, +0.1% роста", 4500, {"tech_cost": 0.92, "interest": 0.001}, "science", "tech"),
    BD("lab", "Лаборатория", "Технологии на 12% дешевле", 5500, {"tech_cost": 0.88}, "science", "tech"),
    BD("observatory", "Обсерватория", "Корабли на 8% дальше, технологии на 3% дешевле", 4000, {"naval_reach": 1.08, "tech_cost": 0.97}, "science", "tech"),
    BD("printing_house", "Типография", "+1 одобрение, +2 на выборах", 3000, {"approval": 1.0, "election": 2.0}, "science", "tech"),
    BD("institute", "Институт", "Технологии на 10% дешевле, +0.05% роста", 6500, {"tech_cost": 0.90, "interest": 0.0005}, "science", "tech"),
    BD("inventors", "Дом изобретателей", "Постройки на 4% дешевле", 4000, {"build_cost": 0.96}, "science", "tech"),
    BD("power_plant", "Электростанция", "+8 золота в секунду, постройки на 3% дешевле", 6000, {"gold_flat": 8.0, "build_cost": 0.97}, "science", "tech"),
    BD("archive", "Архив", "Законы на 5% дешевле", 3000, {"bill_cost": 0.95}, "science", "tech"),
    BD("shipyard", "Верфь", "Корабли на 20% быстрее и дальше (на берегу)", 4000, {"ship_speed": 1.2, "naval_reach": 1.2}, "navy", "empire", coast=True),
    BD("lighthouse", "Маяк", "Корабли на 10% быстрее (на берегу)", 2500, {"ship_speed": 1.1}, "navy", "trade", coast=True),
    BD("naval_base", "Военно-морская база", "Корабли на 25% дальше, +3% к защите (на берегу)", 6000, {"naval_reach": 1.25, "defense": 1.03}, "navy", "empire", coast=True),
    BD("fish_market", "Рыбный рынок", "+8 золота в секунду, +1 одобрение (на берегу)", 3000, {"gold_flat": 8.0, "approval": 1.0}, "navy", "trade", coast=True),
    BD("drydock", "Сухой док", "Корабли на 15% быстрее (на берегу)", 4500, {"ship_speed": 1.15}, "navy", "empire", coast=True),
    BD("embassy", "Посольство", "Боты нападают реже", 4000, {"diplomacy": 0.4}, "state", "green"),
    BD("courthouse", "Суд", "Волнения позже, +1 одобрение", 3000, {"unrest": -3.0, "approval": 1.0}, "state", "tech"),
    BD("ministry", "Министерство", "Зарплаты на 5% меньше", 4500, {"salary_mult": 0.95}, "state", "tech"),
    BD("consulate", "Консульство", "Отношения со всеми +4", 3000, {"relation": 4.0}, "state", "green"),
    BD("windmill", "Ветряк", "+4 золота в секунду", 2000, {"gold_flat": 4.0}, "nature", "green"),
    BD("reservoir", "Водохранилище", "+2 одобрение, +2% роста армии", 3500, {"approval": 2.0, "growth": 1.02}, "nature", "green"),
    BD("reserve", "Заповедник", "+3 одобрение", 3000, {"approval": 3.0}, "nature", "green"),
    BD("orchard", "Сад", "+4 золота в секунду, +1 одобрение", 2200, {"gold_flat": 4.0, "approval": 1.0}, "nature", "green"),
]

# ---------------------------------------------------------------- extra technologies
def T(key, name, desc, mx, costs, req, mods, cat):
    return (key, {"name": name, "desc": desc, "max": mx, "costs": costs, "req": req, "cat": cat, "mods": mods})

EXTRA_TECHS = [
    T("irrigation", "Ирригация", "+4% роста армии за уровень", 2, [3500, 7000], "", {"growth": 1.04}, "econ"),
    T("medicine", "Медицина", "+4 к цели одобрения за уровень", 2, [4000, 8000], "", {"approval": 4.0}, "people"),
    T("electricity", "Электричество", "Постройки на 10% дешевле за уровень", 2, [5000, 10000], "", {"build_cost": 0.90}, "science"),
    T("radio", "Радио", "+3 одобрение и +3 на выборах за уровень", 2, [4500, 9000], "", {"approval": 3.0, "election": 3.0}, "people"),
    T("banking", "Банковское дело", "+8% золота за уровень", 2, [5000, 10000], "trade", {"gold": 1.08}, "econ"),
    T("artillery", "Артиллерия", "Захват чужого на 8% дешевле за уровень", 2, [6000, 12000], "tactics", {"capture": 0.92}, "army"),
    T("railways", "Железные дороги", "Фронт на 12% быстрее за уровень", 2, [5500, 11000], "logistics", {"attack_rate": 1.12}, "army"),
    T("satellites", "Спутники", "Корабли и бомбы дальше и быстрее", 1, [20000], "rockets", {"naval_reach": 1.5, "ship_speed": 1.3}, "science"),
    T("printing_press", "Печатный станок", "+2 одобрение, +2 на выборах за уровень", 2, [3000, 6000], "", {"approval": 2.0, "election": 2.0}, "people"),
    T("steel", "Сталь", "+6% к защите, +3% к лимиту за уровень", 2, [4500, 9000], "fortification", {"defense": 1.06, "cap": 1.03}, "army"),
    T("steam", "Паровые машины", "+6% золота, корабли на 10% быстрее за уровень", 2, [5000, 10000], "", {"gold": 1.06, "ship_speed": 1.1}, "econ"),
    T("chemistry", "Химия", "Захват на 5% дешевле, +2% роста за уровень", 2, [5500, 11000], "", {"capture": 0.95, "growth": 1.02}, "science"),
    T("telegraph", "Телеграф", "Фронт на 6% быстрее, указы на 10% дешевле за уровень", 2, [4000, 8000], "", {"attack_rate": 1.06, "decree_cost": 0.9}, "state"),
    T("sanitation", "Санитария", "+5% роста армии, +2 одобрение за уровень", 2, [3500, 7000], "medicine", {"growth": 1.05, "approval": 2.0}, "people"),
    T("agronomy", "Агрономия", "+5 золота в секунду, +3% роста за уровень", 3, [2500, 5000, 10000], "irrigation", {"gold_flat": 5.0, "growth": 1.03}, "econ"),
    T("aviation", "Авиация", "Фронт на 10% быстрее, корабли на 15% дальше за уровень", 2, [8000, 16000], "railways", {"attack_rate": 1.10, "naval_reach": 1.15}, "army"),
    T("radar_tech", "Радиолокация", "Бункеры на 5 клеток дальше, +3% к защите за уровень", 2, [6000, 12000], "radio", {"shield": 5.0, "defense": 1.03}, "army"),
    T("computers", "Вычислительные машины", "Технологии на 10% дешевле, +3% золота за уровень", 2, [9000, 18000], "electricity", {"tech_cost": 0.90, "gold": 1.03}, "science"),
    T("concrete", "Бетон", "Постройки на 10% дешевле, +4% к защите за уровень", 2, [4000, 8000], "", {"build_cost": 0.90, "defense": 1.04}, "science"),
    T("mass_media", "Массовые медиа", "+5 на выборах, +2 одобрение", 1, [7000], "radio", {"election": 5.0, "approval": 2.0}, "people"),
    T("genetics", "Генетика", "+6% роста армии за уровень", 2, [10000, 20000], "medicine", {"growth": 1.06}, "science"),
    T("containers", "Контейнерные перевозки", "Корабли на 20% быстрее, +4% золота", 1, [12000], "steam", {"ship_speed": 1.2, "gold": 1.04}, "navy"),
    T("cryptography", "Криптография", "Боты нападают реже, +3% к защите", 1, [6000], "", {"diplomacy": 0.3, "defense": 1.03}, "state"),
    T("fusion", "Термоядерный синтез", "+15% золота, +10% роста армии", 1, [40000], "nuclear", {"gold": 1.15, "growth": 1.10}, "science"),
    T("optics", "Оптика", "Корабли на 10% дальше за уровень", 2, [3000, 6000], "", {"naval_reach": 1.1}, "navy"),
    T("economics", "Экономическая наука", "Бюджет на 10% дешевле, +2% золота за уровень", 2, [4500, 9000], "", {"budget_cost": 0.9, "gold": 1.02}, "econ"),
]

# ---------------------------------------------------------------- budget
BUDGET = [
    ("army", {"name": "Армия", "desc": "+0.25% роста армии в секунду за уровень", "mods": {"interest": 0.0025}}),
    ("science", {"name": "Наука", "desc": "Технологии на 6% дешевле за уровень", "mods": {"tech_cost": 0.94}}),
    ("social", {"name": "Народ", "desc": "+3 к цели одобрения за уровень", "mods": {"approval": 3.0}}),
    ("infrastructure", {"name": "Инфраструктура", "desc": "Постройки на 5% дешевле за уровень", "mods": {"build_cost": 0.95}}),
    ("navy", {"name": "Флот", "desc": "Корабли на 8% быстрее и дальше за уровень", "mods": {"ship_speed": 1.08, "naval_reach": 1.08}}),
    ("police", {"name": "Правопорядок", "desc": "Волнения позже на 2 пункта за уровень, −0.5 одобрение", "mods": {"unrest": -2.0, "approval": -0.5}}),
    ("culture", {"name": "Культура", "desc": "+2 одобрение, +1.5 на выборах за уровень", "mods": {"approval": 2.0, "election": 1.5}}),
    ("diplomacy", {"name": "Дипломатия", "desc": "Отношения +4, боты нападают реже за уровень", "mods": {"relation": 4.0, "diplomacy": 0.2}}),
]

# ---------------------------------------------------------------- reforms (one option per axis)
def R(key, name, desc, mods, parties):
    return (key, {"name": name, "desc": desc, "mods": mods, "parties": parties})

REFORMS = [
    ("government", {"name": "Форма правления", "default": "republic", "options": dict([
        R("republic", "Республика", "Сбалансированный курс без особых эффектов", {}, {"people": 4.0, "tech": 2.0}),
        R("monarchy", "Монархия", "+3 одобрение, волнения позже, указы на 15% дешевле, −3 на выборах", {"approval": 3.0, "unrest": -4.0, "decree_cost": 0.85, "election": -3.0}, {"order": 6.0, "empire": 6.0}),
        R("junta", "Военная хунта", "+8% роста и +5% лимита армии, −8 одобрение, волнения намного позже", {"growth": 1.08, "cap": 1.05, "approval": -8.0, "unrest": -8.0}, {"order": 12.0}),
        R("technocracy", "Технократия", "Технологии на 15% и постройки на 5% дешевле, −2 одобрение", {"tech_cost": 0.85, "build_cost": 0.95, "approval": -2.0}, {"tech": 12.0}),
    ])}),
    ("economy", {"name": "Экономический уклад", "default": "market", "options": dict([
        R("market", "Рыночная экономика", "Сбалансированный курс без особых эффектов", {}, {"trade": 4.0}),
        R("planned", "Плановая экономика", "Постройки на 15% дешевле, нацпроекты на 25% быстрее, −5% золота", {"build_cost": 0.85, "project_speed": 1.25, "gold": 0.95}, {"order": 6.0, "people": 4.0}),
        R("mixed", "Смешанная экономика", "+2% золота, +2 одобрение", {"gold": 1.02, "approval": 2.0}, {"people": 4.0, "trade": 4.0}),
        R("guild", "Цеховая экономика", "+6 золота в секунду, технологии на 5% дороже", {"gold_flat": 6.0, "tech_cost": 1.05}, {"trade": 4.0, "green": 4.0}),
    ])}),
    ("army_model", "Устройство армии"),
    ("religion", "Церковь и государство"),
    ("foreign", "Внешняя политика"),
    ("society", "Общественный строй"),
]
REFORMS[2] = ("army_model", {"name": "Устройство армии", "default": "conscript", "options": dict([
    R("conscript", "Призывная армия", "Сбалансированный курс без особых эффектов", {}, {"order": 2.0}),
    R("professional", "Контрактная армия", "+8% к лимиту, +5 золота в секунду расходов", {"cap": 1.08, "salary": 5.0}, {"order": 4.0, "tech": 4.0}),
    R("militia", "Народное ополчение", "+10% к защите, фронт на 8% медленнее, +2 одобрение", {"defense": 1.10, "attack_rate": 0.92, "approval": 2.0}, {"people": 6.0, "green": 4.0}),
    R("legions", "Легионы", "Фронт на 10% быстрее, захват на 4% дешевле, −3 одобрение", {"attack_rate": 1.10, "capture": 0.96, "approval": -3.0}, {"empire": 10.0}),
])})
REFORMS[3] = ("religion", {"name": "Церковь и государство", "default": "secular", "options": dict([
    R("secular", "Светское государство", "Сбалансированный курс без особых эффектов", {}, {"tech": 2.0}),
    R("state_church", "Государственная церковь", "+4 одобрение, волнения позже, технологии на 5% дороже", {"approval": 4.0, "unrest": -4.0, "tech_cost": 1.05}, {"order": 4.0, "empire": 4.0}),
    R("freedom", "Свобода вероисповедания", "+3 одобрение, боты нападают чуть реже", {"approval": 3.0, "diplomacy": 0.2}, {"people": 6.0, "green": 2.0}),
    R("theocracy", "Теократия", "+6 одобрение, +6 на выборах, технологии на 15% дороже, −5% золота", {"approval": 6.0, "election": 6.0, "tech_cost": 1.15, "gold": 0.95}, {"order": 8.0}),
])})
REFORMS[4] = ("foreign", {"name": "Внешняя политика", "default": "neutral", "options": dict([
    R("neutral", "Нейтралитет", "Сбалансированный курс без особых эффектов", {}, {"green": 2.0}),
    R("open", "Открытые границы", "+5% золота, отношения со всеми +8", {"gold": 1.05, "relation": 8.0}, {"trade": 8.0}),
    R("expansion", "Экспансия", "Захват на 6% дешевле, отношения −10, −2 одобрение", {"capture": 0.94, "relation": -10.0, "approval": -2.0}, {"empire": 10.0}),
    R("isolation", "Изоляция", "+10% к защите, −8% золота, волнения позже", {"defense": 1.10, "gold": 0.92, "unrest": -3.0}, {"order": 6.0}),
])})
REFORMS[5] = ("society", {"name": "Общественный строй", "default": "equality", "options": dict([
    R("equality", "Равенство", "Сбалансированный курс без особых эффектов", {}, {"people": 4.0}),
    R("estates", "Сословия", "+3% золота, −2 одобрение", {"gold": 1.03, "approval": -2.0}, {"empire": 4.0, "order": 4.0}),
    R("meritocratic", "Меритократия", "Технологии на 5% дешевле, зарплаты на 10% меньше", {"tech_cost": 0.95, "salary_mult": 0.9}, {"tech": 8.0}),
    R("corporate", "Корпоративный строй", "+8 золота в секунду, волнения позже", {"gold_flat": 8.0, "unrest": -2.0}, {"trade": 6.0, "order": 2.0}),
])})

# ---------------------------------------------------------------- national projects
def P(key, name, desc, cost, duration, mods, approval, cat, req_tech=""):
    d = {"name": name, "desc": desc, "cost": cost, "duration": duration, "mods": mods, "approval": float(approval), "cat": cat}
    if req_tech:
        d["req_tech"] = req_tech
    return (key, d)

PROJECTS = [
    P("grand_canal", "Великий канал", "Корабли на 20% быстрее, +3% золота", 12000, 120, {"ship_speed": 1.2, "gold": 1.03}, 3, "navy"),
    P("railway_net", "Трансконтинентальная магистраль", "Фронт на 15% быстрее, постройки на 5% дешевле", 15000, 150, {"attack_rate": 1.15, "build_cost": 0.95}, 2, "econ"),
    P("literacy", "Всеобщая грамотность", "Технологии на 15% дешевле, +3 одобрение", 8000, 90, {"tech_cost": 0.85, "approval": 3.0}, 4, "science"),
    P("cathedral", "Великий собор", "+6 одобрение, +4 на выборах", 9000, 100, {"approval": 6.0, "election": 4.0}, 5, "people"),
    P("power_grid", "Электрификация", "+8% золота, +10 золота в секунду", 14000, 120, {"gold": 1.08, "gold_flat": 10.0}, 2, "econ"),
    P("olympics", "Олимпийские игры", "+4 одобрение, отношения со всеми +10", 10000, 60, {"approval": 4.0, "relation": 10.0}, 8, "people"),
    P("space", "Космическая программа", "Корабли на 30% дальше, технологии на 10% дешевле, +5 на выборах", 30000, 200, {"naval_reach": 1.3, "tech_cost": 0.9, "election": 5.0}, 6, "science", req_tech="rockets"),
    P("nuclear_plant", "Атомная станция", "+12% золота", 25000, 180, {"gold": 1.12}, 1, "science", req_tech="nuclear"),
    P("great_wall", "Великая стена", "+20% к защите", 16000, 150, {"defense": 1.2}, 2, "army"),
    P("highways", "Сеть дорог", "Фронт на 8% быстрее, постройки на 7% дешевле", 9000, 90, {"attack_rate": 1.08, "build_cost": 0.93}, 2, "econ"),
    P("hospitals", "Сеть больниц", "+8% роста армии, +3 одобрение", 11000, 110, {"growth": 1.08, "approval": 3.0}, 4, "people"),
    P("universities", "Университетская сеть", "Технологии на 15% дешевле, +0.1% роста", 13000, 120, {"tech_cost": 0.85, "interest": 0.001}, 2, "science"),
    P("fleet", "Большая судостроительная программа", "Корабли на 25% быстрее и 20% дальше", 14000, 130, {"ship_speed": 1.25, "naval_reach": 1.2}, 1, "navy"),
    P("welfare_state", "Государство благосостояния", "+8 одобрение, волнения позже, −4% золота", 18000, 150, {"approval": 8.0, "unrest": -6.0, "gold": 0.96}, 6, "people"),
    P("megacity", "Столичный мегаполис", "+12% к лимиту армии, +12 золота в секунду", 20000, 160, {"cap": 1.12, "gold_flat": 12.0}, 3, "econ"),
    P("world_fair", "Всемирная выставка", "+4% золота, отношения +8, +2 одобрение", 8000, 70, {"gold": 1.04, "relation": 8.0, "approval": 2.0}, 4, "state"),
    P("reforestation", "Восстановление лесов", "+4 одобрение, +2% роста армии", 6000, 80, {"approval": 4.0, "growth": 1.02}, 3, "nature"),
    P("rearmament", "Перевооружение", "+10% к лимиту, фронт на 8% быстрее, −2 одобрение", 17000, 120, {"cap": 1.1, "attack_rate": 1.08, "approval": -2.0}, 0, "army"),
    P("dam", "Плотина", "+14 золота в секунду, +3% роста армии", 11000, 100, {"gold_flat": 14.0, "growth": 1.03}, 2, "nature"),
    P("telegraph_net", "Телеграфная сеть", "Указы на 20% дешевле, фронт на 4% быстрее", 7000, 60, {"decree_cost": 0.8, "attack_rate": 1.04}, 1, "state"),
    P("coastal_forts", "Береговые форты", "+10% к защите, корабли на 10% дальше", 10000, 90, {"defense": 1.1, "naval_reach": 1.1}, 1, "navy"),
    P("land_registry", "Земельный кадастр", "+5% золота, захват на 3% дешевле", 9000, 80, {"gold": 1.05, "capture": 0.97}, 1, "state"),
    P("academy_arts", "Академия искусств", "+5 одобрение, +3 на выборах", 7000, 70, {"approval": 5.0, "election": 3.0}, 3, "people"),
    P("grain_reserve", "Государственный резерв зерна", "Волнения намного позже, +2 одобрение", 6000, 60, {"unrest": -8.0, "approval": 2.0}, 2, "econ"),
]

# ---------------------------------------------------------------- extra decrees
EXTRA_DECREES = [
    ("amnesty", {"name": "Амнистия", "desc": "+10 одобрение, −8% войск", "cost": 0, "cooldown": 900, "approval": 10.0, "troops_share": -0.08}),
    ("requisition", {"name": "Реквизиция", "desc": "+3000 золота, −12 одобрение", "cost": 0, "cooldown": 900, "approval": -12.0, "gold": 3000.0}),
    ("parade", {"name": "Парад", "desc": "+6 одобрение", "cost": 1200, "cooldown": 600, "approval": 6.0}),
    ("tax_holiday", {"name": "Налоговые каникулы", "desc": "+8 одобрение", "cost": 2000, "cooldown": 900, "approval": 8.0}),
    ("treasury_audit", {"name": "Ревизия казны", "desc": "+2500 золота, −5 одобрение", "cost": 0, "cooldown": 1200, "approval": -5.0, "gold": 2500.0}),
    ("recruits", {"name": "Набор рекрутов", "desc": "+8% войск, −5 одобрение", "cost": 1500, "cooldown": 600, "approval": -5.0, "troops_share": 0.08}),
    ("charity", {"name": "Благотворительность", "desc": "+5 одобрение", "cost": 800, "cooldown": 450, "approval": 5.0}),
    ("fireworks", {"name": "Фейерверк", "desc": "+3 одобрение", "cost": 500, "cooldown": 300, "approval": 3.0}),
    ("pardon", {"name": "Помилование", "desc": "+4 одобрение, −2% войск", "cost": 0, "cooldown": 600, "approval": 4.0, "troops_share": -0.02}),
    ("army_bonus", {"name": "Премия армии", "desc": "+4% войск", "cost": 2500, "cooldown": 600, "troops_share": 0.04}),
]

# ---------------------------------------------------------------- extra events
def E(title, text, c1, c2):
    return {"title": title, "text": text, "choices": [c1, c2]}

EXTRA_EVENTS = [
    E("Открыто месторождение", "Геологи нашли золото в горах.", {"text": "Разрабатывать (+4000 золота, −4 одобрение)", "gold": 4000, "approval": -4}, {"text": "Оставить природе (+5 одобрение)", "approval": 5}),
    E("Забастовка", "Рабочие рынков требуют повышения оплаты.", {"text": "Уступить (−2500 золота, +6 одобрение)", "gold": -2500, "approval": 6}, {"text": "Разогнать (−9 одобрение)", "approval": -9}),
    E("Праздник урожая", "Народ просит устроить гуляния.", {"text": "Устроить (−1500 золота, +8 одобрение)", "gold": -1500, "approval": 8}, {"text": "Отказать (−3 одобрение)", "approval": -3}),
    E("Дезертиры", "Часть солдат бежит домой.", {"text": "Простить (−6% войск, +3 одобрение)", "troops_share": -0.06, "approval": 3}, {"text": "Наказать (−3% войск, −4 одобрение)", "troops_share": -0.03, "approval": -4}),
    E("Иностранный инвестор", "Купец предлагает вложиться в ваши рынки.", {"text": "Принять (+3000 золота, −2 одобрение)", "gold": 3000, "approval": -2}, {"text": "Отказать (+2 одобрение)", "approval": 2}),
    E("Наводнение", "Реки вышли из берегов.", {"text": "Помочь пострадавшим (−3000 золота, +6 одобрение)", "gold": -3000, "approval": 6}, {"text": "Не вмешиваться (−8 одобрение)", "approval": -8}),
    E("Изобретатель", "Мастер предлагает чертежи за вознаграждение.", {"text": "Купить (−3000 золота, технология +1)", "gold": -3000, "tech": 1}, {"text": "Отказать", "approval": -1}),
    E("Коррупционный скандал", "Министра поймали на взятках.", {"text": "Отдать под суд (+7 одобрение, −1500 золота)", "gold": -1500, "approval": 7}, {"text": "Замять (+1500 золота, −6 одобрение)", "gold": 1500, "approval": -6}),
    E("Добровольцы", "Молодёжь просится в армию.", {"text": "Принять всех (+10% войск, −2 одобрение)", "troops_share": 0.10, "approval": -2}, {"text": "Только лучших (+4% войск, +2 одобрение)", "troops_share": 0.04, "approval": 2}),
    E("Ярмарка", "Соседи предлагают торговую ярмарку.", {"text": "Провести (+2500 золота, +2 одобрение)", "gold": 2500, "approval": 2}, {"text": "Отказать (+1 одобрение)", "approval": 1}),
    E("Слухи о перевороте", "Генералы недовольны.", {"text": "Повысить жалование (−3500 золота, +4 одобрение)", "gold": -3500, "approval": 4}, {"text": "Сместить генералов (−12% войск, +3 одобрение)", "troops_share": -0.12, "approval": 3}),
    E("Учёные требуют свободы", "Академия просит снять цензуру.", {"text": "Снять (+5 одобрение, налоги −1)", "approval": 5, "tax": -1}, {"text": "Отказать (−3 одобрение)", "approval": -3}),
    E("Комета", "В небе над столицей появилась комета. Народ волнуется.", {"text": "Объявить добрым знаком (+5 одобрение)", "approval": 5}, {"text": "Пусть объяснят учёные (−2000 золота, технология +1)", "gold": -2000, "tech": 1}),
    E("Пожар в столице", "Сгорел целый квартал.", {"text": "Отстроить (−3000 золота, +6 одобрение)", "gold": -3000, "approval": 6}, {"text": "Оставить как есть (−8 одобрение)", "approval": -8}),
    E("Пиратский набег", "Пираты захватили торговый караван.", {"text": "Заплатить выкуп (−2000 золота)", "gold": -2000}, {"text": "Отбить силой (−5% войск, +4 одобрение)", "troops_share": -0.05, "approval": 4}),
    E("Гастроли", "Знаменитая труппа просится выступить.", {"text": "Бесплатно для народа (+3 одобрение)", "approval": 3}, {"text": "Продавать билеты (+1000 золота)", "gold": 1000}),
    E("Пойман шпион", "Разведка схватила чужого агента.", {"text": "Казнить (−3 одобрение, +3% войск)", "approval": -3, "troops_share": 0.03}, {"text": "Обменять (+1500 золота)", "gold": 1500}),
    E("Голод в горах", "Горные деревни просят хлеба.", {"text": "Отправить обозы (−2500 золота, +7 одобрение)", "gold": -2500, "approval": 7}, {"text": "Не помогать (−9 одобрение)", "approval": -9}),
    E("Бунт в столице", "Толпа вышла на площадь.", {"text": "Подавить (−8% войск, −4 одобрение)", "troops_share": -0.08, "approval": -4}, {"text": "Уступить (−2000 золота, +5 одобрение)", "gold": -2000, "approval": 5}),
    E("Наследство купца", "Богатый купец умер без наследников.", {"text": "В казну (+2500 золота)", "gold": 2500}, {"text": "Раздать беднякам (+6 одобрение)", "approval": 6}),
    E("Землетрясение", "Разрушены дома в провинции.", {"text": "Помочь (−3500 золота, +6 одобрение)", "gold": -3500, "approval": 6}, {"text": "Игнорировать (−10 одобрение)", "approval": -10}),
    E("Мода на армию", "Молодёжь мечтает о службе.", {"text": "Открыть набор (+8% войск, −2 одобрение)", "troops_share": 0.08, "approval": -2}, {"text": "Не сейчас (+2 одобрение)", "approval": 2}),
    E("Урожай винограда", "Год выдался удачным.", {"text": "Продать вино (+2000 золота)", "gold": 2000}, {"text": "Устроить праздник (+7 одобрение)", "approval": 7}),
    E("Династический брак", "Соседний правитель предлагает союз через брак.", {"text": "Согласиться (+5 одобрение)", "approval": 5}, {"text": "Отказать (+1500 золота приданого не будет, но +2% войск)", "troops_share": 0.02}),
    E("Падёж скота", "Болезнь выкосила стада.", {"text": "Компенсации (−2000 золота, +4 одобрение)", "gold": -2000, "approval": 4}, {"text": "Ничего не делать (−6 одобрение)", "approval": -6}),
    E("Партия требует пост", "Крупная партия хочет место в кабинете.", {"text": "Уступить (−1000 золота, +4 одобрение)", "gold": -1000, "approval": 4}, {"text": "Отказать (−4 одобрение)", "approval": -4}),
    E("Народ требует выборов", "На площадях требуют голосования.", {"text": "Пообещать (+6 одобрение)", "approval": 6}, {"text": "Отказать (−7 одобрение, +1000 золота штрафов)", "approval": -7, "gold": 1000}),
    E("Новый университет", "Учёные просят денег на кафедры.", {"text": "Финансировать (−2500 золота, технология +1)", "gold": -2500, "tech": 1}, {"text": "Не финансировать (−2 одобрение)", "approval": -2}),
    E("Вражеская пропаганда", "Соседи распускают слухи о вас.", {"text": "Опровергнуть (−1000 золота, +3 одобрение)", "gold": -1000, "approval": 3}, {"text": "Игнорировать (−4 одобрение)", "approval": -4}),
    E("Найден клад", "Крестьяне откопали древние монеты.", {"text": "Забрать в казну (+2000 золота, −2 одобрение)", "gold": 2000, "approval": -2}, {"text": "Оставить нашедшим (+4 одобрение)", "approval": 4}),
]

# ---------------------------------------------------------------- emit
out = []
out.append('''extends RefCounted
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

const CATEGORIES := %s
const CATEGORY_ORDER := %s
''' % (gd(dict(CATEGORIES)), gd([k for k, _ in CATEGORIES])))

out.append("# ---------------------------------------------------------------- parties (Duma)")
out.append(table("PARTIES", PARTIES, "PARTY_ORDER"))
out.append("\n# ---------------------------------------------------------------- ministers (fee once, salary per second)")
out.append(table("MINISTERS", MINISTERS, "MINISTER_ORDER"))
out.append("\n# ---------------------------------------------------------------- bills (need BILL_MAJORITY seats among supporting parties; req = bill needed first, excl = incompatible bills, req_tech = technology needed)")
out.append(table("BILLS", BILLS, "BILL_ORDER"))
out.append("\n# ---------------------------------------------------------------- extra buildings (party = who gains Duma weight per building)")
out.append(table("BUILDINGS", BUILDINGS, "BUILDING_ORDER"))
out.append("\n# ---------------------------------------------------------------- extra technologies (levels, costs; effects are mods per level)")
out.append(table("EXTRA_TECHS", EXTRA_TECHS, "EXTRA_TECH_ORDER"))
out.append("\n# ---------------------------------------------------------------- budget (levels 0..3; cost per second scales with land)")
out.append(table("BUDGET", BUDGET, "BUDGET_ORDER"))
out.append("const BUDGET_COST_PER_CELL := 0.008      # gold per second per level per cell\nconst BUDGET_MAX := 3")
out.append("\n# ---------------------------------------------------------------- reforms: one option per axis, changing costs gold and approval")
out.append(table("REFORMS", REFORMS, "REFORM_ORDER"))
out.append("const REFORM_COST := 5000\nconst REFORM_APPROVAL_HIT := 6.0")
out.append("\n# ---------------------------------------------------------------- national projects: pay once, wait, get a permanent bonus")
out.append(table("PROJECTS", PROJECTS, "PROJECT_ORDER"))
out.append("const PROJECT_MAX_ACTIVE := 3")
out.append("\n# ---------------------------------------------------------------- diplomacy")
out.append("const RELATION_START := 50.0\nconst RELATION_DRIFT := 0.03           # per second toward RELATION_START\nconst RELATION_ATTACK_HIT := 20.0\nconst RELATION_GIFT := 15.0\nconst GIFT_COST := 2000\nconst GIFT_COST_PER_CELL := 0.3\nconst PACT_COST := 3000\nconst PACT_COST_PER_CELL := 0.5\nconst PACT_MIN_RELATION := 40.0\nconst PACT_SECONDS := 150\nconst RELATION_ATTACK_SCALE := 0.8      # bots need (1 + this * (relation-50)/50) more of an edge to attack you")
out.append("\n# ---------------------------------------------------------------- extra decrees")
out.append(table("EXTRA_DECREES", EXTRA_DECREES, "EXTRA_DECREE_ORDER"))
out.append("\n# ---------------------------------------------------------------- extra random events")
out.append("const EXTRA_EVENTS := [\n" + "".join("\t%s,\n" % gd(e) for e in EXTRA_EVENTS) + "]")
out.append('''

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
''')

src = "\n".join(out)
open("/Users/maksim/Projects/medstrat/scripts/sim/content.gd", "w").write(src)

# sanity: keys unique, refs valid
keys = lambda rows: [k for k, _ in rows]
for name, rows in [("MINISTERS", MINISTERS), ("BILLS", BILLS), ("BUILDINGS", BUILDINGS), ("EXTRA_TECHS", EXTRA_TECHS), ("PROJECTS", PROJECTS)]:
    ks = keys(rows)
    assert len(ks) == len(set(ks)), (name, [k for k in ks if ks.count(k) > 1])
    names = [d["name"] for _, d in rows]
    assert len(names) == len(set(names)), (name, [n for n in names if names.count(n) > 1])
bill_keys = set(keys(BILLS))
for k, d in BILLS:
    assert d.get("req", "") in bill_keys | {""}, k
    for x in d.get("excl", []):
        assert x in bill_keys, (k, x)
        other = dict(BILLS)[x]
        assert k in other.get("excl", []), ("excl must be mutual", k, x)
allmods = set("gold growth cap capture defense tech_cost build_cost attack_rate ship_speed naval_reach nuke_cost decree_cost salary_mult budget_cost bill_cost project_speed pact_cost approval salary interest gold_flat unrest election diplomacy shield relation cap_flat".split())
for rows in [MINISTERS, BILLS, BUILDINGS, EXTRA_TECHS, BUDGET, PROJECTS, PARTIES]:
    for k, d in rows:
        assert set(d["mods"]) <= allmods, (k, set(d["mods"]) - allmods)
for k, d in REFORMS:
    for ok, od in d["options"].items():
        assert set(od["mods"]) <= allmods, (k, ok)
total = len(MINISTERS) + len(BILLS) + len(BUILDINGS) + len(EXTRA_TECHS) + len(BUDGET) * 3 + sum(len(d["options"]) for _, d in REFORMS) + len(PROJECTS) + len(EXTRA_DECREES) + len(EXTRA_EVENTS)
print("ministers %d bills %d buildings %d techs %d budget %d reforms %d projects %d decrees %d events %d => %d items" % (
    len(MINISTERS), len(BILLS), len(BUILDINGS), len(EXTRA_TECHS), len(BUDGET), sum(len(d["options"]) for _, d in REFORMS), len(PROJECTS), len(EXTRA_DECREES), len(EXTRA_EVENTS), total))
