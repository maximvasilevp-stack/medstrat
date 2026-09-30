extends RefCounted
## Historical starts: the player begins next to a real city with a flavour bonus and a goal text.
## "free" is the normal match with a hand-picked capital.

const LIST := {
	"free": {"name": "Свободная игра", "city": "", "desc": "Выберите столицу сами. Никаких бонусов, чистая стратегия.", "troops": 1.0, "gold": 1.0, "tech": "", "bills": []},
	"rome": {"name": "Рим", "city": "Рим", "desc": "Легионы и дороги: старт у Рима, +50% войск, изучена Логистика.", "troops": 1.5, "gold": 1.0, "tech": "logistics", "bills": []},
	"athens": {"name": "Афины", "city": "Афины", "desc": "Философы и триеры: старт у Афин, изучена Навигация, принят закон Университеты.", "troops": 1.0, "gold": 1.2, "tech": "navigation", "bills": ["universities"]},
	"carthage": {"name": "Карфаген", "city": "Тунис", "desc": "Торговая империя моря: старт у Туниса, +2000 золота, изучена Торговля.", "troops": 1.0, "gold": 2.3, "tech": "trade", "bills": []},
	"vikings": {"name": "Викинги", "city": "Осло", "desc": "Драккары: старт у Осло, +30% войск, Навигация, принята Флотская программа.", "troops": 1.3, "gold": 1.0, "tech": "navigation", "bills": ["navy_program"]},
	"byzantium": {"name": "Византия", "city": "Стамбул", "desc": "Стены Константинополя: старт у Стамбула, изучена Фортификация, Береговая оборона.", "troops": 1.0, "gold": 1.5, "tech": "fortification", "bills": ["coast_defense"]},
	"egypt": {"name": "Египет", "city": "Каир", "desc": "Житница Нила: старт у Каира, +3000 золота, Ирригация.", "troops": 1.0, "gold": 3.0, "tech": "irrigation", "bills": []},
	"franks": {"name": "Франки", "city": "Париж", "desc": "Рыцари: старт у Парижа, +40% войск, изучена Тактика.", "troops": 1.4, "gold": 1.0, "tech": "tactics", "bills": []},
	"rus": {"name": "Русь", "city": "Москва", "desc": "Просторы и стужа: старт у Москвы, +20% войск, Призыв, Программа переселения.", "troops": 1.2, "gold": 1.2, "tech": "conscription", "bills": ["resettlement"]},
	"britain": {"name": "Британия", "city": "Лондон", "desc": "Владычица морей: старт у Лондона, Навигация, Свободная торговля.", "troops": 1.0, "gold": 1.6, "tech": "navigation", "bills": ["free_trade"]},
	"iberia": {"name": "Иберия", "city": "Мадрид", "desc": "Реконкиста: старт у Мадрида, +30% войск, Фортификация.", "troops": 1.3, "gold": 1.2, "tech": "fortification", "bills": []},
	"caliphate": {"name": "Халифат", "city": "Дамаск", "desc": "Дом мудрости: старт у Дамаска, +2500 золота, Медицина, Наука в приоритете.", "troops": 1.0, "gold": 2.6, "tech": "medicine", "bills": ["science"]},
	"poland": {"name": "Речь Посполитая", "city": "Варшава", "desc": "Крылатые гусары: старт у Варшавы, +35% войск, Кавалерийский устав.", "troops": 1.35, "gold": 1.0, "tech": "", "bills": ["cavalry"]},
	"ottomans": {"name": "Османы", "city": "Анкара", "desc": "Янычары и пушки: старт у Анкары, +25% войск, Артиллерия через Тактику.", "troops": 1.25, "gold": 1.3, "tech": "tactics", "bills": []},
}
const ORDER := ["free", "rome", "athens", "carthage", "vikings", "byzantium", "egypt", "franks", "rus", "britain", "iberia", "caliphate", "poland", "ottomans"]


static func get_def(key: String) -> Dictionary:
	return LIST[key] if LIST.has(key) else LIST["free"]


## Cell of the named city on the map, -1 if missing.
static func city_cell(map, name: String) -> int:
	for c in map.cities:
		if c["name"] == name:
			return int(c["cell"])
	return -1
