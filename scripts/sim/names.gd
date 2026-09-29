extends RefCounted
## Deterministic fantasy names for city-states and nicknames for bots.

const PREFIXES := ["Блэк", "Крэг", "Лор", "Гип", "Эск", "Торн", "Рук", "Орен", "Вер", "Сол", "Дар",
	"Мор", "Кал", "Тар", "Эль", "Вал", "Аур", "Нор", "Зар", "Фен", "Гал", "Ири", "Каст", "Мел", "Ост", "Раш",
	"Сер", "Тил", "Урс", "Хол", "Циан", "Шад", "Ярл", "Бел", "Гро", "Дюн"]
const SUFFIXES := ["мер", "мур", "вин", "ноз", "ария", "вик", "свуд", "таль", "дания", "ион", "ос", "ум",
	"ия", "ант", "ген", "ор", "ин", "гард", "холм", "берг", "мор", "дор", "ват", "ния", "терра", "ленд"]
const PHRASES := ["Логово волков", "Подземный мир", "Нижнее болото", "Тихая гавань", "Семь холмов",
	"Костяной берег", "Медвежий угол", "Соляные копи", "Старый форт", "Красная скала", "Долина ветров",
	"Чёрный лес", "Янтарный порт", "Пепельные земли", "Гнездо соколов", "Серые башни", "Дальний предел",
	"Каменный мост", "Лунная бухта", "Северный дозор"]
const NICKNAMES := ["tick", "Аурелия", "Джезза", "Кайзер", "Рыжий", "Пират_77", "Ночь", "Стратег", "Молот",
	"Vlad", "Ксюша", "Барон", "Северянин", "Шторм", "Зеро", "Легат", "Комета", "Маэстро", "Гризли", "Фокс",
	"Император", "Птица", "Ветер", "Титан", "Кот", "Некто", "Ярость", "Лис", "Атлас", "Сова"]


static func city_name(rng: RandomNumberGenerator, used: Dictionary) -> String:
	for attempt in 50:
		var name: String
		if rng.randf() < 0.3:
			name = PHRASES[rng.randi_range(0, PHRASES.size() - 1)]
		else:
			name = PREFIXES[rng.randi_range(0, PREFIXES.size() - 1)] + SUFFIXES[rng.randi_range(0, SUFFIXES.size() - 1)]
		if not used.has(name):
			used[name] = true
			return name
	return "Город %d" % rng.randi_range(100, 999)


static func bot_name(rng: RandomNumberGenerator, used: Dictionary) -> String:
	for attempt in 50:
		var name: String = NICKNAMES[rng.randi_range(0, NICKNAMES.size() - 1)]
		if rng.randf() < 0.3:
			name += str(rng.randi_range(1, 99))
		if not used.has(name):
			used[name] = true
			return name
	return "Игрок %d" % rng.randi_range(100, 999)


static func short_number(v: float) -> String:
	if v >= 1_000_000.0:
		return "%.2fM" % (v / 1_000_000.0)
	if v >= 10_000.0:
		return "%.1fK" % (v / 1000.0)
	if v >= 1000.0:
		return "%.2fK" % (v / 1000.0)
	return str(int(v))
