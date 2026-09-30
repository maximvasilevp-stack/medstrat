extends RefCounted
## Achievements unlock once per player profile (Settings) and give XP. Checked from the match scene.

const LIST := {
	"first_blood": {"name": "Первая кровь", "desc": "Захватите первую чужую клетку", "xp": 10},
	"hundred": {"name": "Сотня", "desc": "Владейте 100 клетками", "xp": 10},
	"thousand": {"name": "Тысяча", "desc": "Владейте 1000 клетками", "xp": 30},
	"ten_thousand": {"name": "Десять тысяч", "desc": "Владейте 10 000 клетками", "xp": 80},
	"quarter": {"name": "Четверть мира", "desc": "Займите 25% карты", "xp": 120},
	"winner": {"name": "Победитель", "desc": "Выиграйте матч", "xp": 200},
	"city_builder": {"name": "Градостроитель", "desc": "Постройте 5 городов", "xp": 30},
	"admiral": {"name": "Адмирал", "desc": "Проведите высадку с моря", "xp": 25},
	"nuclear": {"name": "Атомный век", "desc": "Запустите ядерную бомбу", "xp": 40},
	"mega": {"name": "Судный день", "desc": "Запустите MEGA NUKE", "xp": 80},
	"pacifist": {"name": "Пацифист", "desc": "Примите Ядерное разоружение", "xp": 30},
	"lawmaker": {"name": "Законодатель", "desc": "Примите 10 законов", "xp": 40},
	"codex": {"name": "Свод законов", "desc": "Примите 30 законов", "xp": 100},
	"cabinet": {"name": "Полный кабинет", "desc": "Наймите 8 министров", "xp": 40},
	"scholar": {"name": "Учёный", "desc": "Изучите 10 уровней технологий", "xp": 40},
	"beloved": {"name": "Любимый правитель", "desc": "Одобрение 90%", "xp": 30},
	"tyrant": {"name": "Тиран", "desc": "Одобрение ниже 15% и вы всё ещё живы", "xp": 20},
	"reelected": {"name": "Переизбран", "desc": "Выиграйте 3 выборов подряд", "xp": 40},
	"diplomat": {"name": "Дипломат", "desc": "Заключите пакт о ненападении", "xp": 20},
	"ally": {"name": "Союзник", "desc": "Заключите союз", "xp": 40},
	"overlord": {"name": "Сюзерен", "desc": "Получите вассала", "xp": 60},
	"merchant": {"name": "Купец", "desc": "Три торговых договора одновременно", "xp": 40},
	"spymaster": {"name": "Мастер шпионажа", "desc": "5 успешных операций разведки", "xp": 50},
	"reformer": {"name": "Реформатор", "desc": "Смените курс на трёх осях реформ", "xp": 40},
	"builder": {"name": "Великий строитель", "desc": "Завершите 3 нацпроекта", "xp": 60},
	"prospector": {"name": "Старатель", "desc": "Владейте 20 месторождениями", "xp": 40},
	"conqueror": {"name": "Завоеватель", "desc": "Уничтожьте 3 фракции", "xp": 80},
	"survivor": {"name": "Выживший", "desc": "Продержитесь 20 минут", "xp": 30},
	"marathon": {"name": "Марафонец", "desc": "Продержитесь 45 минут", "xp": 80},
	"rich": {"name": "Богач", "desc": "Накопите 100 000 золота", "xp": 50},
	"horde": {"name": "Орда", "desc": "Соберите 50 000 войск", "xp": 50},
	"missions10": {"name": "Исполнитель", "desc": "Выполните 10 заданий", "xp": 60},
	"all_seasons": {"name": "Круглый год", "desc": "Переживите все четыре времени года", "xp": 20},
	"nightmare": {"name": "Кошмар наяву", "desc": "Выиграйте матч на сложности «Кошмар»", "xp": 300},
	"economist": {"name": "Экономист", "desc": "ВВП 500 золота в секунду", "xp": 50},
	"banker": {"name": "Банкир", "desc": "Возьмите кредит и полностью его погасите", "xp": 30},
	"tycoon": {"name": "Спекулянт", "desc": "Заработайте 10 000 на ручной торговле товарами", "xp": 60},
	"printer": {"name": "Печатный станок", "desc": "Проведите три эмиссии и не получите дефолт", "xp": 30},
}
const ORDER := ["first_blood", "hundred", "thousand", "ten_thousand", "quarter", "winner", "city_builder", "admiral", "nuclear", "mega",
	"pacifist", "lawmaker", "codex", "cabinet", "scholar", "beloved", "tyrant", "reelected", "diplomat", "ally", "overlord", "merchant",
	"spymaster", "reformer", "builder", "prospector", "conqueror", "survivor", "marathon", "rich", "horde", "missions10", "all_seasons", "nightmare",
	"economist", "banker", "tycoon", "printer"]


static func _count_true(d: Dictionary) -> int:
	var n := 0
	for k in d:
		if d[k]:
			n += 1
	return n


## Is the condition of one achievement met right now?
static func met(world, fid: int, key: String) -> bool:
	var f: Dictionary = world.factions[fid]
	var c: Dictionary = f["counters"]
	match key:
		"first_blood":
			return int(c.get("captured_enemy", 0)) > 0
		"hundred":
			return f["cells"] >= 100
		"thousand":
			return f["cells"] >= 1000
		"ten_thousand":
			return f["cells"] >= 10000
		"quarter":
			return world.land_share(fid) >= 0.25
		"winner":
			return world.winner_declared == fid
		"city_builder":
			return f["cities"] >= 5
		"admiral":
			return int(c.get("landings", 0)) > 0
		"nuclear":
			return int(c.get("nukes", 0)) > 0
		"mega":
			return int(c.get("meganukes", 0)) > 0
		"pacifist":
			return bool(f["bills"].get("disarmament", false))
		"lawmaker":
			return _count_true(f["bills"]) >= 10
		"codex":
			return _count_true(f["bills"]) >= 30
		"cabinet":
			return _count_true(f["staff"]) >= 8
		"scholar":
			var n := 0
			for k in f["tech"]:
				n += int(f["tech"][k])
			return n >= 10
		"beloved":
			return f["approval"] >= 90.0
		"tyrant":
			return f["approval"] < 15.0 and f["alive"] and world.seconds() > 60.0
		"reelected":
			return int(c.get("election_streak", 0)) >= 3
		"diplomat":
			return int(c.get("pacts_signed", 0)) > 0
		"ally":
			return int(c.get("allies_made", 0)) > 0
		"overlord":
			return int(c.get("vassals", 0)) > 0
		"merchant":
			var n := 0
			for o in f["trade"]:
				if int(f["trade"][o]) > world.tick:
					n += 1
			return n >= 3
		"spymaster":
			return int(c.get("spy_ok", 0)) >= 5
		"reformer":
			return int(c.get("reforms_done", 0)) >= 3
		"builder":
			return f["projects_done"].size() >= 3
		"prospector":
			var n := 0
			for k in f["res"]:
				n += int(f["res"][k])
			return n >= 20
		"conqueror":
			return int(c.get("kills", 0)) >= 3
		"survivor":
			return f["alive"] and world.seconds() >= 1200.0
		"marathon":
			return f["alive"] and world.seconds() >= 2700.0
		"rich":
			return f["gold"] >= 100000.0 and not f["admin"]
		"horde":
			return f["troops"] >= 50000.0 and not f["admin"]
		"missions10":
			return int(c.get("missions_done", 0)) >= 10
		"all_seasons":
			return world.seconds() >= 4.0 * 120.0 and f["alive"]
		"nightmare":
			return world.winner_declared == fid and world.difficulty >= 3
		"economist":
			return float(f["econ"]["gdp"]) >= 500.0
		"banker":
			return int(c.get("loans_repaid", 0)) > 0
		"tycoon":
			return float(f["econ"]["manual_profit"]) >= 10000.0
		"printer":
			return int(c.get("emissions", 0)) >= 3 and not f["econ"]["defaulted"]
	return false


## Keys unlocked right now that are not in `unlocked` yet.
static func check_new(world, fid: int, unlocked: Dictionary) -> Array:
	var out: Array = []
	if world.factions[fid]["admin"]:
		return out
	for key in ORDER:
		if not unlocked.get(key, false) and met(world, fid, key):
			out.append(key)
	return out
