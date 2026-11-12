extends Node
## Stato della partita e salvataggio dei progressi.

const SAVE := "user://zima_save.cfg"
const CHAPTERS := [
	{"id": 1, "roman": "I", "name": "Il Cortile"},
	{"id": 2, "roman": "II", "name": "La fermata"},
	{"id": 3, "roman": "III", "name": "Il posto di blocco"},
	{"id": 4, "roman": "IV", "name": "Il Дом культуры"},
	{"id": 5, "roman": "V", "name": "L'ospedale n. 3"},
	{"id": 6, "roman": "VI", "name": "La stazione radio"},
	{"id": 7, "roman": "VII", "name": "Sotto la città"},
	{"id": 8, "roman": "VIII", "name": "La ТЭЦ"},
	{"id": 9, "roman": "IX", "name": "I laboratori sotterranei"},
	{"id": 10, "roman": "X", "name": "La valvola"},
]
## Capitoli già portati in Godot.
const READY := [1]

const ITEM_NAMES := {
	"fiammiferi": "Fiammiferi «Пламя»",
	"giornale": "Giornali «Правда»",
	"legna": "Legna per la stufa",
	"chiave": "Chiave di manutenzione «ТП-4»",
	"chiaveGarage": "Chiave «ГАРАЖ №4» · 0417",
	"radio": "Radio da campo",
	"quaderno": "Quaderno verde",
	"piantina": "Piantina del cortile",
	"mappa": "Mappa dello ЗАТО-42",
}

var heat := 100.0
var battery := 60.0
var cans := 0
var food_warm := 0.0
var torch := false
var items := {}
var clues := {}
var flags := {}
var told := {}
var gear := {}
var checkpoint := Vector2.ZERO
var started := false
var ended := false
var paused := false
var gap := false

var unlocked := 1
var done := {}
var last := 1

func _ready() -> void:
	load_save()

func reset_chapter() -> void:
	heat = 100.0
	battery = 60.0
	cans = 0
	food_warm = 0.0
	torch = false
	items = {}
	clues = {}
	flags = {}
	told = {}
	started = false
	ended = false
	paused = false
	gap = false

func fl(k: String) -> bool:
	return bool(flags.get(k, false))

func have(k: String) -> bool:
	return items.has(k)

func load_save() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE) != OK:
		return
	unlocked = int(cf.get_value("p", "unlocked", 1))
	last = int(cf.get_value("p", "last", 1))
	for i in cf.get_value("p", "done", []):
		done[int(i)] = true

func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("p", "unlocked", unlocked)
	cf.set_value("p", "last", last)
	cf.set_value("p", "done", done.keys())
	cf.save(SAVE)

func chapter_done(id: int, next_id: int) -> void:
	done[id] = true
	unlocked = max(unlocked, min(10, id + 1))
	last = next_id if next_id > 0 else id
	save()
