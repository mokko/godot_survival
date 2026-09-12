extends Node
## Day/night cycle. A full day lasts DAY_LENGTH real seconds (Minecraft:
## 20 minutes = 10 min day, ~1.5 min each dusk/dawn, 7 min night).
## Rotates the sun around a tilted axis (subsolar behavior for ~36 N,
## Japan's latitude: the noon sun climbs to ~77 degrees, not straight
## overhead), tints sky/ambient through dawn/noon/dusk/night, and scales
## glow-plant emission up at night (bioluminescent lore).

const DAY_LENGTH := 1200.0            # seconds for a full day+night
const JAPAN_MAX_SUN_ELEVATION := 77.0 # deg; ~36 N latitude, equinox-ish
const GLOW_GROUP := "glow_plants"

## Time of day in [0, 1): 0 = sunrise, 0.25 = noon, 0.5 = sunset,
## 0.5-1 = night. Starts at mid-morning.
var time_of_day := 0.1

@onready var sun: DirectionalLight3D = get_node("../DirectionalLight3D")
@onready var world_env: WorldEnvironment = get_node("../WorldEnvironment")

# Color keyframes sampled by sun elevation phase.
const DAWN := Color(0.95, 0.62, 0.38)
const NOON := Color(0.72, 0.8, 0.86)
const DUSK := Color(0.85, 0.45, 0.3)
const NIGHT := Color(0.08, 0.1, 0.18)


func _ready() -> void:
	# Tag emissive flora/fauna so _process can scale them.
	for path in ["../Plants", "../Animals"]:
		var root: Node = get_node_or_null(path)
		if root == null:
			continue
		for n in root.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			var mat: Material = mi.get_active_material(0)
			if mat != null and mat.emission_enabled:
				mi.add_to_group(GLOW_GROUP)


func _process(delta: float) -> void:
	time_of_day = fmod(time_of_day + delta / DAY_LENGTH, 1.0)

	# Sun elevation: sin curve, +1 at noon (0.25), -1 at midnight (0.75).
	var elev := sin(time_of_day * TAU)
	var elev_deg := elev * JAPAN_MAX_SUN_ELEVATION
	# Azimuth sweeps east->south->west across the day (northern hemisphere:
	# sun tracks through the southern sky).
	var az: float = lerp(-110.0, 110.0, clampf(time_of_day / 0.5, 0.0, 1.0))
	sun.rotation = Vector3(deg_to_rad(90.0 - elev_deg), deg_to_rad(az), 0.0)

	# Sun strength: zero below horizon.
	var day := clampf(elev * 3.0, 0.0, 1.0)
	sun.light_energy = 1.3 * day

	# Sky + fog tint: dawn/noon/dusk warm, night deep blue.
	var sky_mat: ProceduralSkyMaterial = world_env.environment.sky.sky_material
	var horizon := NOON
	if elev < -0.15:
		horizon = NIGHT
	elif elev < 0.2:
		horizon = DAWN.lerp(NOON, clampf((elev + 0.15) / 0.35, 0.0, 1.0))
	elif time_of_day > 0.35:
		horizon = DUSK
	sky_mat.sky_horizon_color = horizon
	sky_mat.sky_top_color = NIGHT.lerp(Color(0.25, 0.45, 0.72), day)
	sky_mat.ground_horizon_color = horizon
	world_env.environment.fog_light_color = horizon
	world_env.environment.ambient_light_energy = lerpf(0.25, 1.0, day)

	# Glow plants flare up as the sun dies.
	var glow := lerpf(2.2, 1.0, day)
	get_tree().call_group(GLOW_GROUP, "set_instance_shader_parameter",
			"emission_energy", glow)
