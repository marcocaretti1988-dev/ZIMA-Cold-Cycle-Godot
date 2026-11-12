extends Node
## Profili grafici: "pc" (pieno) e "mobile" (leggero).
## Il profilo si sceglie da solo all'avvio; dal menu si può forzare.

signal changed

var method := "forward_plus"
var touch := false
var pref := "auto"            # auto | pc | mobile
var pc := true                # profilo attivo

func _ready() -> void:
	method = str(ProjectSettings.get_setting_with_override(
		"rendering/renderer/rendering_method"))
	if RenderingServer.has_method("get_current_rendering_method"):
		var m := str(RenderingServer.call("get_current_rendering_method"))
		if m != "":
			method = m
	touch = OS.has_feature("mobile") or OS.has_feature("web_android") \
		or OS.has_feature("web_ios") or DisplayServer.is_touchscreen_available()
	var cf := ConfigFile.new()
	if cf.load("user://zima_gfx.cfg") == OK:
		pref = str(cf.get_value("gfx", "pref", "auto"))
	_resolve()

func _resolve() -> void:
	var auto_pc := method == "forward_plus" and not OS.has_feature("mobile") \
		and not OS.has_feature("web")
	if pref == "pc":
		pc = true
	elif pref == "mobile":
		pc = false
	else:
		pc = auto_pc

func cycle() -> void:
	pref = {"auto": "pc", "pc": "mobile", "mobile": "auto"}[pref]
	var cf := ConfigFile.new()
	cf.set_value("gfx", "pref", pref)
	cf.save("user://zima_gfx.cfg")
	_resolve()
	changed.emit()

func label() -> String:
	var names := {"auto": "AUTO", "pc": "PIENA", "mobile": "LEGGERA"}
	var act := "piena" if pc else "leggera"
	return "GRAFICA: %s  (%s)" % [names[pref], act]

## Effetti disponibili solo con Forward+.
func full_fx() -> bool:
	return pc and method == "forward_plus"

func snow_amount() -> int:
	return 3200 if pc else 900

func print_cap() -> int:
	return 6000 if pc else 2200

func shadows() -> bool:
	return pc or not (OS.has_feature("mobile") or OS.has_feature("web"))

func render_scale() -> float:
	if pc:
		return 1.0
	return 0.75 if (OS.has_feature("mobile") or OS.has_feature("web")) else 1.0
