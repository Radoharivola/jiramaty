extends Node2D

# Prototype: Délestage Chaos
# Tap a neighborhood to cut or restore its power.
# Supply is always lower than total demand. Keep every riot meter below 100
# and don't overload the grid. Score = seconds survived.

class Hood:
	var hood_name: String = ""
	var pos: Vector2 = Vector2.ZERO  # fractions of the screen size
	var demand: float = 30.0
	var powered: bool = true
	var riot: float = 0.0
	var radius: float = 70.0

var hoods: Array = []
var supply: float = 0.0
var powered_demand: float = 0.0
var overload: float = 0.0
var time_alive: float = 0.0
var best_time: float = 0.0
var game_over: bool = false
var reason: String = ""
var font: Font


func _ready() -> void:
	randomize()
	font = ThemeDB.fallback_font
	_reset()


func _reset() -> void:
	hoods.clear()
	var data: Array = [
		["Analakely", Vector2(0.30, 0.22), 32.0],
		["Ankorondrano", Vector2(0.72, 0.30), 40.0],
		["Ambohidratrimo", Vector2(0.25, 0.50), 24.0],
		["Itaosy", Vector2(0.70, 0.58), 28.0],
		["Isotry", Vector2(0.45, 0.78), 30.0],
	]
	for d in data:
		var h := Hood.new()
		h.hood_name = d[0]
		h.pos = d[1]
		h.demand = d[2]
		hoods.append(h)
	supply = 0.0
	powered_demand = 0.0
	overload = 0.0
	time_alive = 0.0
	game_over = false
	reason = ""
	queue_redraw()


func _process(delta: float) -> void:
	if game_over:
		return

	time_alive += delta

	# Demand drifts randomly so the player keeps having to re-decide.
	var total_demand: float = 0.0
	for h in hoods:
		h.demand = clampf(h.demand + randf_range(-6.0, 6.0) * delta, 15.0, 50.0)
		total_demand += h.demand

	# Supply is always about 60% of demand, with a slow wobble.
	supply = total_demand * 0.6 * (1.0 + 0.08 * sin(time_alive * 0.6))

	powered_demand = 0.0
	for h in hoods:
		if h.powered:
			powered_demand += h.demand

	# Grid overload.
	if powered_demand > supply:
		overload += ((powered_demand - supply) / supply) * 60.0 * delta
	else:
		overload = maxf(0.0, overload - 15.0 * delta)

	if overload >= 100.0:
		overload = 100.0
		_end_game("Grid collapse: total blackout")
		return

	# Riot meters.
	for h in hoods:
		if h.powered:
			h.riot = maxf(0.0, h.riot - 5.0 * delta)
		else:
			h.riot += (2.0 + h.demand * 0.08) * delta
		if h.riot >= 100.0:
			h.riot = 100.0
			_end_game("Riot in " + h.hood_name)
			return

	queue_redraw()


func _end_game(why: String) -> void:
	game_over = true
	reason = why
	best_time = maxf(best_time, time_alive)
	queue_redraw()


func _input(event: InputEvent) -> void:
	var e := event as InputEventMouseButton
	if e == null or not e.pressed or e.button_index != MOUSE_BUTTON_LEFT:
		return

	if game_over:
		_reset()
		return

	var size: Vector2 = get_viewport_rect().size
	for h in hoods:
		var center: Vector2 = h.pos * size
		if center.distance_to(e.position) <= h.radius:
			h.powered = not h.powered
			break


func _draw() -> void:
	var size: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.08, 0.12))

	# Neighborhoods.
	for h in hoods:
		var center: Vector2 = h.pos * size
		var fill: Color = Color(0.95, 0.80, 0.25) if h.powered else Color(0.18, 0.19, 0.24)
		draw_circle(center, h.radius, fill)
		draw_arc(center, h.radius, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 3.0)

		var label_w: float = h.radius * 2.0 + 60.0
		var text_col: Color = Color(0.1, 0.1, 0.1) if h.powered else Color(0.85, 0.85, 0.9)
		draw_string(font, Vector2(center.x - label_w / 2.0, center.y - 4.0), h.hood_name, HORIZONTAL_ALIGNMENT_CENTER, label_w, 18, text_col)
		draw_string(font, Vector2(center.x - label_w / 2.0, center.y + 20.0), "demand " + str(int(h.demand)), HORIZONTAL_ALIGNMENT_CENTER, label_w, 16, text_col)

		# Riot bar under each neighborhood.
		var bar_w: float = h.radius * 2.0
		var bar_pos: Vector2 = Vector2(center.x - h.radius, center.y + h.radius + 10.0)
		draw_rect(Rect2(bar_pos, Vector2(bar_w, 12.0)), Color(0.2, 0.2, 0.25))
		var riot_col: Color = Color(0.9, 0.25, 0.2) if h.riot > 66.0 else Color(0.95, 0.6, 0.2)
		draw_rect(Rect2(bar_pos, Vector2(bar_w * h.riot / 100.0, 12.0)), riot_col)

	# HUD.
	draw_string(font, Vector2(20.0, 36.0), "Time: " + str(snappedf(time_alive, 0.1)) + "s   Best: " + str(snappedf(best_time, 0.1)) + "s", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	draw_string(font, Vector2(20.0, 66.0), "Supply: " + str(int(supply)) + "   Used: " + str(int(powered_demand)), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)

	var ov_pos: Vector2 = Vector2(20.0, 80.0)
	draw_rect(Rect2(ov_pos, Vector2(size.x - 40.0, 14.0)), Color(0.2, 0.2, 0.25))
	draw_rect(Rect2(ov_pos, Vector2((size.x - 40.0) * overload / 100.0, 14.0)), Color(0.9, 0.3, 0.2))
	draw_string(font, Vector2(20.0, 118.0), "Grid overload", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.8, 0.8, 0.85))

	# Game over overlay.
	if game_over:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.75))
		draw_string(font, Vector2(0.0, size.y * 0.42), "GAME OVER", HORIZONTAL_ALIGNMENT_CENTER, size.x, 48, Color.WHITE)
		draw_string(font, Vector2(0.0, size.y * 0.48), reason, HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, Color(0.95, 0.5, 0.4))
		draw_string(font, Vector2(0.0, size.y * 0.53), "Survived " + str(snappedf(time_alive, 0.1)) + "s", HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, Color.WHITE)
		draw_string(font, Vector2(0.0, size.y * 0.60), "Tap to restart", HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(0.8, 0.8, 0.85))
