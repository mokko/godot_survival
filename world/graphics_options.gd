extends WorldEnvironment
## Applies the rendering options that live on the world scene's environment.
##
## The toggles are in the main menu (ui/splash.gd) and persisted by
## ui/options.gd. The world scene only has to read them when it starts: nothing
## can change them while the world is loaded, because the options panel belongs
## to the splash screen.
##
## Tuning lives with the Environment in world/main.tscn (radius 2.0, intensity
## 1.5 — small enough to read as contact shading under plants and rocks rather
## than as an overall darkening); this script only honours the opt-out.

const Options := preload("res://ui/options.gd")


func _ready() -> void:
	if environment == null:
		push_warning("graphics_options: WorldEnvironment has no Environment")
		return
	environment.ssao_enabled = bool(Options.get_option("ssao"))
