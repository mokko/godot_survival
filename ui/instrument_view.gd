extends Control
## The instrument view: what the drone sees when a tool is held up. Two circles of
## vision for the binoculars, one for the magnifying glass' loupe (set `tubes`);
## everything outside them is dimmed, each circle has a bright rim, and a small
## reticle marks the exact aim point.
##
## The mask is drawn with vertical strips rather than a texture: a circle-shaped
## hole in an overlay cannot be done with four rects, and a 4 px strip is invisible
## at any window size.
##
## The magnification is the **camera's field of view**, pulled in by `player/player.gd`
## while a glass is **raised**; this file draws the mask and nothing else. That
## split is deliberate and it is the whole trick: everything outside the circle is dimmed
## away, so magnifying the entire camera cannot be seen, and one draw path stays the only
## draw path. The alternative — a second `Viewport` rendering the reticle region into the
## circle — is true lens magnification, and it costs a viewport, a texture and an
## alignment to keep right, so it is a separate job and not a fix to this one.
##
## The scroll wheel still owns the base zoom (`player/player.gd::base_fov`). While a glass
## is up the camera is the glass's, so the wheel is not felt until the tool is put away —
## and that is exactly why it moves the **base**: the view comes back to the zoom the
## player chose, including one chosen while looking through the glass. (The wheel's *plain*
## turn walks the hotbar; `Shift`+wheel is this zoom — `player/player.gd`.)
##
## **The lens itself** is the defocus *outside* the circles (`_build_lens()`): what the tube
## shows stays sharp — the glass is the in-focus part — and the world beyond the rim goes soft
## by a gradient, the way a lens goes soft with distance from its plane of focus. It is
## deliberately mild, and it exists only outside: inside, the only things drawn are the rim and
## the reticle. The circles are pushed into the shader from the same numbers `_draw()` masks
## with (`_sync_lens()`), so the mask and the lens cannot disagree.

const DIM := Color(0, 0, 0, 0.72)
const RIM := Color(0.85, 0.92, 1.0, 0.75)
const RIM_GLOW := Color(0.65, 0.85, 1.0, 0.28)
const RETICLE := Color(0.9, 0.96, 1.0, 0.8)

const TUBE_GAP := 0.42   ## distance between tube centres, as a fraction of radius
const STRIP := 4.0       ## px width of the mask strips
const VIEW_RADIUS := 0.34  ## of the viewport height

## How the optics are drawn, and why it is this way round:
##
## **The glass is the sharp part.** A lens focuses *through* the tube — the circle is the exit
## pupil, and the field it shows is the in-focus, magnified view. So the inside is left
## completely alone: no blur, no tint, just the rim and the reticle the mask draws over it.
##
## **The outside is the defocused part**, and it is blurred by an amount that *grows with
## distance from the rim*. That is the circle-of-confusion rule: a point that is not at the
## plane of focus is imaged as a blur spot, and the further it sits from that plane the larger
## the spot (Wikipedia, *Depth of field* / *Circle of confusion* — "the greater the distance an
## object is from the plane of focus, the larger the blur spot"). A lens is not sharp-then-
## suddenly-soft; it goes soft in a gradient, which is what `ramp_px` is for.
##
## It is deliberately mild (`BLUR_PX` is a few pixels, not the frosted pane the first version
## drew *inside* the circle by mistake), because the strips already dim the outside to 0.72
## black — the blur is there to say "out of focus", not to hide anything.
##
## Five taps of the *screen* (the pixel itself plus four diagonals), no mip: the offsets are
## scaled by the ramp, so near the rim the sample is the sharp image and further out it is the
## full blur, with no visible step between them. `screen_tex` is the `BackBufferCopy` the HUD
## puts behind this view (`player/study.gd::_build_hud`) — without it the whole outside goes
## black, which is loud enough to be noticed at once.
const BLUR_PX := 3.0
const RAMP_PX := 70.0          ## how far past the rim the defocus takes to reach full strength
const LENS_TINT := Color(0.88, 0.94, 1.0)

const LENS_SHADER := """
shader_type canvas_item;

// Godot 4 has no `SCREEN_TEXTURE` built-in any more: the screen is an ordinary uniform with
// the screen-texture hint, fed by the `BackBufferCopy` the HUD puts behind this view.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

uniform vec2 rect = vec2(1920.0, 1080.0);
uniform vec2 circle_a = vec2(960.0, 540.0);
uniform vec2 circle_b = vec2(960.0, 540.0);
uniform int tubes = 2;
uniform float radius = 367.0;
uniform float blur_px = 3.0;
uniform float ramp_px = 70.0;
uniform vec4 tint : source_color = vec4(0.88, 0.94, 1.0, 1.0);

void fragment() {
	vec2 px = UV * rect;
	float d = distance(px, circle_a);
	if (tubes >= 2) {
		d = min(d, distance(px, circle_b));
	}
	// Inside the glass: sharp, untouched. Outside: defocused, and more so further out.
	float t = smoothstep(radius, radius + ramp_px, d);
	if (t <= 0.0) {
		COLOR = vec4(0.0);
	} else {
		vec2 off = vec2(blur_px, blur_px) / rect * t;
		vec3 sum = texture(screen_tex, SCREEN_UV).rgb;
		sum += texture(screen_tex, SCREEN_UV + off).rgb;
		sum += texture(screen_tex, SCREEN_UV - off).rgb;
		sum += texture(screen_tex, SCREEN_UV + vec2(off.x, -off.y)).rgb;
		sum += texture(screen_tex, SCREEN_UV - vec2(off.x, -off.y)).rgb;
		COLOR = vec4(sum / 5.0 * mix(vec3(1.0), tint.rgb, t), 1.0);
	}
}
"""


var tubes := 2             ## 2 = binoculars, 1 = the magnifying glass' loupe
var radius_fraction := VIEW_RADIUS
## How many times this view has actually queued a redraw. The mask is drawn in 4 px
## strips — hundreds of rects on a 1920-wide window — and the caller asks every frame,
## so a redraw has to be earned. Counted here so a test can prove it (a headless run
## has no renderer and cannot see a draw happening).
var redraw_requests := 0
## The lens: a full-rect `ColorRect` with the blur shader, drawn **behind** the strips (the
## mask dims outside the circles; this only touches the inside).
var _lens: ColorRect = null
var _lens_mat: ShaderMaterial = null


func _ready() -> void:
	# A resized window changes the geometry, so that is worth one redraw — and the lens wants
	# the new rect and circle positions at the same moment.
	resized.connect(_on_resized)
	_build_lens()


func _on_resized() -> void:
	queue_redraw()
	_sync_lens()


func set_view(tubes_in: int, radius_in: float) -> bool:
	## The one supported way to change what is drawn. Returns true when something was
	## actually different — the caller (player/study.gd) asks every frame, and
	## unconditionally queuing a redraw there rebuilt the whole mask every frame.
	var changed := false
	if tubes_in != tubes:
		tubes = tubes_in
		changed = true
	if not is_equal_approx(radius_in, radius_fraction):
		radius_fraction = radius_in
		changed = true
	if changed:
		queue_redraw()
		redraw_requests += 1
		_sync_lens()
	return changed


func _build_lens() -> void:
	## The glass: a nine-tap blur of the world inside the circles, built in code like
	## everything else here (no shader asset to keep in sync). `show_behind_parent` is what
	## puts it *under* the mask strips, which is the whole reason it can be a child of this
	## view at all.
	var shader := Shader.new()
	shader.code = LENS_SHADER
	_lens_mat = ShaderMaterial.new()
	_lens_mat.shader = shader
	_lens = ColorRect.new()
	_lens.name = "Lens"
	_lens.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lens.show_behind_parent = true
	_lens.material = _lens_mat
	add_child(_lens)
	_sync_lens()


func _sync_lens() -> void:
	## Push the geometry into the shader: the **same numbers `_draw()` masks with**, computed
	## here from `size`/`tubes`/`radius_fraction` so the mask the player sees and the region
	## the lens blurs cannot drift apart.
	if _lens == null or _lens_mat == null:
		return
	var radius: float = minf(size.x, size.y) * radius_fraction
	var gap := radius * TUBE_GAP
	var a := Vector2(size.x * 0.5, size.y * 0.5)
	var b := a
	if tubes >= 2:
		a = Vector2(size.x * 0.5 - gap, size.y * 0.5)
		b = Vector2(size.x * 0.5 + gap, size.y * 0.5)
	_lens_mat.set_shader_parameter("rect", size)
	_lens_mat.set_shader_parameter("circle_a", a)
	_lens_mat.set_shader_parameter("circle_b", b)
	_lens_mat.set_shader_parameter("tubes", tubes)
	_lens_mat.set_shader_parameter("radius", radius)
	_lens_mat.set_shader_parameter("blur_px", BLUR_PX)
	_lens_mat.set_shader_parameter("ramp_px", RAMP_PX)
	_lens_mat.set_shader_parameter("tint", LENS_TINT)


func _draw() -> void:
	var radius: float = minf(size.x, size.y) * radius_fraction
	var gap := radius * TUBE_GAP
	var centres: Array = [Vector2(size.x * 0.5, size.y * 0.5)]
	if tubes >= 2:
		centres = [
			Vector2(size.x * 0.5 - gap, size.y * 0.5),
			Vector2(size.x * 0.5 + gap, size.y * 0.5),
		]
	_draw_mask(centres, radius)
	for centre in centres:
		draw_arc(centre, radius, 0.0, TAU, 64, RIM_GLOW, 6.0, true)
		draw_arc(centre, radius, 0.0, TAU, 64, RIM, 1.6, true)
	# Reticle: a small cross where the ray actually goes.
	var mid := Vector2(size.x * 0.5, size.y * 0.5)
	draw_line(mid + Vector2(-9, 0), mid + Vector2(-3, 0), RETICLE, 1.0, true)
	draw_line(mid + Vector2(3, 0), mid + Vector2(9, 0), RETICLE, 1.0, true)
	draw_line(mid + Vector2(0, -9), mid + Vector2(0, -3), RETICLE, 1.0, true)
	draw_line(mid + Vector2(0, 3), mid + Vector2(0, 9), RETICLE, 1.0, true)


func _draw_mask(centres: Array, radius: float) -> void:
	## Column by column: whatever the tubes do not cover is dark. A column outside
	## both circles is dark top to bottom.
	var r2 := radius * radius
	var x := 0.0
	while x < size.x:
		var top := size.y
		var bottom := 0.0
		var covered := false
		for centre in centres:
			var dx: float = x - centre.x
			if absf(dx) > radius:
				continue
			var dy: float = sqrt(maxf(r2 - dx * dx, 0.0))
			top = minf(top, centre.y - dy)
			bottom = maxf(bottom, centre.y + dy)
			covered = true
		if not covered:
			draw_rect(Rect2(x, 0.0, STRIP, size.y), DIM)
		else:
			if top > 0.0:
				draw_rect(Rect2(x, 0.0, STRIP, top), DIM)
			if bottom < size.y:
				draw_rect(Rect2(x, bottom, STRIP, size.y - bottom), DIM)
		x += STRIP