extends RefCounted
## Rotating objectives for the human player: three at a time, each with a gold reward and XP.
## A mission remembers the value of its statistic when it was handed out ("base"), so
## "capture 300 more cells" always means 300 more than you had.

const Rules := preload("res://scripts/sim/rules.gd")

## delta: target = base + delta[tier]; abs: target = abs[tier] (whichever the template has)
const TEMPLATES := {
	"expand": {"name": "Расширение", "text": "Захватите ещё %d клеток", "stat": "cells", "delta": [120, 300, 700], "gold": [1500, 3000, 6000], "xp": [15, 30, 60]},
	"cities": {"name": "Урбанизация", "text": "Владейте %d городами", "stat": "cities", "delta": [1, 2, 3], "gold": [2000, 3500, 6000], "xp": [15, 30, 50]},
	"bills": {"name": "Законотворец", "text": "Примите ещё %d закона(ов)", "stat": "bills", "delta": [2, 4, 7], "gold": [2000, 4000, 7000], "xp": [15, 30, 50]},
	"ministers": {"name": "Кабинет", "text": "Наймите ещё %d министра(ов)", "stat": "staff", "delta": [1, 2, 4], "gold": [1500, 3000, 5000], "xp": [10, 25, 40]},
	"techs": {"name": "Просвещение", "text": "Изучите ещё %d уровня(ей) технологий", "stat": "techs", "delta": [2, 4, 7], "gold": [2500, 5000, 8000], "xp": [15, 30, 55]},
	"approval": {"name": "Любимец народа", "text": "Поднимите одобрение до %d%%", "stat": "approval", "abs": [70, 80, 90], "gold": [2000, 4000, 7000], "xp": [15, 30, 55]},
	"troops": {"name": "Большая армия", "text": "Соберите %d войск", "stat": "troops", "mult": [1.5, 2.0, 3.0], "min": [800, 2000, 5000], "gold": [1500, 3000, 6000], "xp": [10, 25, 50]},
	"gold": {"name": "Казна", "text": "Накопите %d золота", "stat": "gold", "delta": [5000, 12000, 30000], "gold": [1000, 2500, 5000], "xp": [10, 20, 40]},
	"buildings": {"name": "Стройка века", "text": "Постройте ещё %d зданий из вкладки Постройки", "stat": "extra", "delta": [2, 4, 8], "gold": [2000, 4000, 7000], "xp": [15, 30, 50]},
	"election": {"name": "Мандат", "text": "Выиграйте ещё %d выборы(ов)", "stat": "elections_won", "delta": [1, 2, 3], "gold": [2500, 5000, 8000], "xp": [20, 40, 60]},
	"pact": {"name": "Миротворец", "text": "Заключите ещё %d пакт(а)", "stat": "pacts_signed", "delta": [1, 2, 3], "gold": [2000, 4000, 6000], "xp": [15, 30, 45]},
	"project": {"name": "Стройка государства", "text": "Завершите ещё %d нацпроект(а)", "stat": "projects_done", "delta": [1, 2, 3], "gold": [4000, 8000, 14000], "xp": [30, 60, 100]},
	"resources": {"name": "Недра", "text": "Владейте %d месторождениями", "stat": "resources", "delta": [3, 6, 12], "gold": [2000, 4000, 7000], "xp": [15, 30, 55]},
	"eliminate": {"name": "Завоеватель", "text": "Уничтожьте ещё %d фракцию(ий)", "stat": "kills", "delta": [1, 2, 3], "gold": [4000, 8000, 15000], "xp": [40, 80, 150]},
	"land": {"name": "Держава", "text": "Займите %d%% карты", "stat": "land", "delta": [2, 5, 10], "gold": [3000, 7000, 15000], "xp": [30, 70, 150]},
	"ports": {"name": "Морская держава", "text": "Постройте ещё %d порт(а)", "stat": "ports", "delta": [1, 2, 3], "gold": [2500, 5000, 8000], "xp": [15, 30, 45]},
	"reform": {"name": "Реформатор", "text": "Проведите ещё %d реформу(ы)", "stat": "reforms_done", "delta": [1, 2, 3], "gold": [3000, 6000, 10000], "xp": [20, 40, 70]},
	"spy": {"name": "Плащ и кинжал", "text": "Проведите ещё %d успешную(ых) операцию(ий) разведки", "stat": "spy_ok", "delta": [1, 2, 4], "gold": [3000, 6000, 10000], "xp": [25, 50, 90]},
	"allies": {"name": "Коалиция", "text": "Заключите ещё %d союз(а)", "stat": "allies_made", "delta": [1, 2, 3], "gold": [3000, 6000, 10000], "xp": [25, 50, 80]},
	"trade": {"name": "Купец", "text": "Заключите ещё %d торговых договора(ов)", "stat": "trades_made", "delta": [1, 2, 4], "gold": [2000, 4000, 7000], "xp": [15, 30, 50]},
}
const TEMPLATE_ORDER := ["expand", "cities", "bills", "ministers", "techs", "approval", "troops", "gold", "buildings", "election",
	"pact", "project", "resources", "eliminate", "land", "ports", "reform", "spy", "allies", "trade"]
const ACTIVE := 3


## Current value of a mission statistic.
static func value(world, fid: int, stat: String) -> float:
	var f: Dictionary = world.factions[fid]
	match stat:
		"cells", "cities", "ports", "troops", "gold", "approval", "elections_won":
			return float(f[stat])
		"bills":
			var n := 0
			for k in f["bills"]:
				if f["bills"][k]:
					n += 1
			return float(n)
		"staff":
			var n := 0
			for k in f["staff"]:
				if f["staff"][k]:
					n += 1
			return float(n)
		"techs":
			var n := 0
			for k in f["tech"]:
				n += int(f["tech"][k])
			return float(n)
		"extra":
			var n := 0
			for k in f["extra"]:
				n += int(f["extra"][k])
			return float(n)
		"projects_done":
			return float(f["projects_done"].size())
		"resources":
			var n := 0
			for k in f["res"]:
				n += int(f["res"][k])
			return float(n)
		"land":
			return world.land_share(fid) * 100.0
		_:
			return float(f["counters"].get(stat, 0))


static func make(world, fid: int, key: String, tier: int) -> Dictionary:
	var t: Dictionary = TEMPLATES[key]
	var base := value(world, fid, t["stat"])
	var target: float
	if t.has("abs"):
		target = float(t["abs"][tier])
	elif t.has("mult"):
		target = maxf(base * float(t["mult"][tier]), float(t["min"][tier]))
	else:
		target = base + float(t["delta"][tier])
	return {"key": key, "tier": tier, "base": base, "target": target, "gold": int(t["gold"][tier]), "xp": int(t["xp"][tier])}


static func describe(m: Dictionary) -> String:
	var t: Dictionary = TEMPLATES[m["key"]]
	return t["text"] % int(round(m["target"] - (0.0 if (t.has("abs") or t.has("mult")) else m["base"])))


static func progress(world, fid: int, m: Dictionary) -> float:
	var t: Dictionary = TEMPLATES[m["key"]]
	var v := value(world, fid, t["stat"])
	var lo: float = 0.0 if (t.has("abs") or t.has("mult")) else m["base"]
	return clampf((v - lo) / maxf(1e-6, m["target"] - lo), 0.0, 1.0)


static func done(world, fid: int, m: Dictionary) -> bool:
	return value(world, fid, TEMPLATES[m["key"]]["stat"]) >= m["target"] - 1e-6


## A new mission whose template is not already active; the tier grows with missions completed.
static func draw(world, fid: int, active: Array, completed: int) -> Dictionary:
	var used := {}
	for m in active:
		used[m["key"]] = true
	var options: Array = []
	for key in TEMPLATE_ORDER:
		if not used.has(key):
			options.append(key)
	var key: String = options[world.rng.randi_range(0, options.size() - 1)]
	@warning_ignore("integer_division")
	var tier: int = clampi(completed / 4, 0, 2)
	return make(world, fid, key, tier)
