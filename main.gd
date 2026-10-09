extends Node2D

## A small, self-contained utility management game. All interface elements are
## drawn here so the prototype stays lightweight and works with mouse or touch.

class District:
	var title: String
	var latitude: float
	var longitude: float
	var demand_power: float
	var demand_water: float
	var has_power := true
	var has_water := true
	var unrest := 0.0
	var issue := ""
	var illegal_hookup := false
	var unpaid := false
	var arrears := 0
	var houses: Array = []
	var poles: Array = []
	var repair_left := 0.0
	var repairing := false


class House:
	var label: String
	var offset := Vector2.ZERO
	var style := 0
	var has_power := true
	var has_water := true
	var unpaid := false
	var illegal_hookup := false
	var arrears := 0


class Pole:
	var offset := Vector2.ZERO
	var failed := false
	var repairing := false
	var repair_left := 0.0
	var house_indices: Array[int] = []


class Facility:
	var title: String
	var kind: String
	var fuel_type: String
	var latitude: float
	var longitude: float
	var capacity: float
	var display_offset := Vector2.ZERO
	var fault := false
	var repair_left := 0.0
	var repairing := false
	var fault_name := ""

const DISTRICT_DATA := [
	["Analakely", -18.90832, 47.52629, 28.0, 23.0],
	["Ankorondrano", -18.88597, 47.52292, 35.0, 28.0],
	["Andavamamba", -18.91822, 47.50810, 22.0, 20.0],
	["Itaosy", -18.91667, 47.46667, 25.0, 22.0],
	["Isotry", -18.90995, 47.51615, 26.0, 24.0],
	["Tanjombato", -18.95826, 47.52566, 24.0, 21.0],
]

# Public site markers use approximate coordinates. The RIA diesel fleet is a
# gameplay aggregate; household positions and account states are fictional.
const FACILITY_DATA := [
	["Andekaleka Hydro", "power", "hydro", -18.79401, 48.61925, 42.0],
	["Ambohimanambola HFO", "power", "hfo", -18.94967, 47.61529, 34.0],
	["Antelomita Hydro", "power", "hydro", -19.01198, 47.70334, 9.0],
	["Mandroseza Water Works", "water", "water", -18.93333, 47.55000, 40.0],
	["Faralaza Water Station", "water", "water", -18.86000, 47.47000, 12.0],
	["Vontovorona Water Station", "water", "water", -18.97000, 47.45000, 10.0],
	["Mandroseza HFO Plant", "power", "hfo", -18.93333, 47.55000, 22.0],
	["RIA Diesel Backup Fleet", "power", "diesel", -18.91000, 47.53000, 12.0],
	["Ambatolampy Solar", "power", "solar", -19.48900, 47.44500, 8.0],
]

const MAP_CENTER_LAT := -18.91
const MAP_CENTER_LON := 47.53

const INK := Color("#213733")
const MUTED := Color("#6f8178")
const BG := Color("#edf1e7")
const PANEL := Color("#fffdf7")
const PANEL_HI := Color("#e5f1e9")
const TEAL := Color("#24836d")
const AMBER := Color("#e9a056")
const RED := Color("#d95e57")

var font: Font
var districts: Array[District] = []
var facilities: Array[Facility] = []
var selected := 0
var selected_house := -1
var selected_pole := -1
var selected_facility := -1
var zoom_level := 0
var map_pan := Vector2.ZERO
var map_scale := 2.2
var target_map_scale := 2.2
var map_camera := Vector2(55.0, 0.0)
var target_map_camera := Vector2(55.0, 0.0)
var crew_level := 1
var crew_cooldown := 0.0
var map_drag_active := false
var last_drag_position := Vector2.ZERO
var active_touches: Dictionary = {}
var pinch_distance := 0.0
var touch_pan_active := false
var power_supply := 0.0
var water_supply := 0.0
var power_used := 0.0
var water_used := 0.0
var reservoir := 78.0
var diesel_stock := 1200.0
var diesel_tank_capacity := 12000.0
var diesel_monthly_plan := 3000
var diesel_frequency_days := 10
var diesel_auto_purchase := true
var diesel_days_elapsed := 0.0
var diesel_next_order_day := 10.0
var diesel_truck_in_transit := false
var diesel_truck_eta := 0.0
var diesel_truck_liters := 0.0
var diesel_retry_timer := 0.0
var diesel_panel_open := false
var is_raining := false
var rain_remaining := 0.0
var weather_clock := 0.0
var next_rain_time := 32.0
var rain_popup_open := false
var rain_popup_seen := false
var treasury := 600.0
var loan_used := false
var time_alive := 0.0
var event_clock := 0.0
var income_clock := 0.0
var best_time := 0.0
var game_started := false
var game_over := false
var help_open := false
var show_more_actions := false
var reason := ""
var notice := "Dispatch ready. Keep the lights on... somewhere."
var notice_timer := 0.0
var hitboxes: Dictionary = {}


func _ready() -> void:
	randomize()
	font = ThemeDB.fallback_font
	_load_best()
	_reset()


func _load_best() -> void:
	var save := ConfigFile.new()
	if save.load("user://jiramaty.cfg") == OK:
		best_time = float(save.get_value("scores", "best_time", 0.0))


func _save_best() -> void:
	var save := ConfigFile.new()
	save.set_value("scores", "best_time", best_time)
	save.save("user://jiramaty.cfg")


func _reset() -> void:
	districts.clear()
	for row in DISTRICT_DATA:
		var d := District.new()
		d.title = row[0]
		d.latitude = row[1]
		d.longitude = row[2]
		d.demand_power = row[3]
		d.demand_water = row[4]
		_create_houses(d)
		_create_poles(d)
		districts.append(d)
	facilities.clear()
	for row in FACILITY_DATA:
		var facility := Facility.new()
		facility.title = row[0]
		facility.kind = row[1]
		facility.fuel_type = row[2]
		facility.latitude = row[3]
		facility.longitude = row[4]
		facility.capacity = row[5]
		if facility.title == "Mandroseza Water Works":
			facility.display_offset = Vector2(13, -4)
		elif facility.title == "Mandroseza HFO Plant":
			facility.display_offset = Vector2(-13, 4)
		elif facility.title == "RIA Diesel Backup Fleet":
			facility.display_offset = Vector2(40, -18)
		facilities.append(facility)
	selected = -1
	selected_house = -1
	selected_pole = -1
	selected_facility = -1
	zoom_level = 0
	map_pan = Vector2.ZERO
	map_scale = 2.2
	target_map_scale = 2.2
	map_camera = Vector2(55.0, 0.0)
	target_map_camera = Vector2(55.0, 0.0)
	crew_level = 1
	crew_cooldown = 0.0
	map_drag_active = false
	active_touches.clear()
	pinch_distance = 0.0
	touch_pan_active = false
	power_supply = 0.0
	water_supply = 0.0
	power_used = 0.0
	water_used = 0.0
	reservoir = 78.0
	diesel_stock = 1200.0
	diesel_tank_capacity = 12000.0
	diesel_monthly_plan = 3000
	diesel_frequency_days = 10
	diesel_auto_purchase = true
	diesel_days_elapsed = 0.0
	diesel_next_order_day = 10.0
	diesel_truck_in_transit = false
	diesel_truck_eta = 0.0
	diesel_truck_liters = 0.0
	diesel_retry_timer = 0.0
	diesel_panel_open = false
	is_raining = false
	rain_remaining = 0.0
	weather_clock = 0.0
	next_rain_time = randf_range(26.0, 42.0)
	rain_popup_open = false
	rain_popup_seen = false
	treasury = 600.0
	loan_used = false
	time_alive = 0.0
	event_clock = 0.0
	income_clock = 0.0
	game_over = false
	game_started = false
	help_open = false
	show_more_actions = false
	reason = ""
	notice = ""
	notice_timer = 0.0
	_recalculate_supply()
	queue_redraw()


func _create_houses(d: District) -> void:
	var index := 0
	for row in range(5):
		for col in range(5):
			index += 1
			var house := House.new()
			house.label = "House " + ("%02d" % index)
			house.offset = Vector2((col - 2) * 0.19 + (0.035 if row % 2 == 0 else 0.0), (row - 2) * 0.17)
			house.style = (index + row + col) % 4
			house.unpaid = index in [4, 13, 21]
			house.arrears = 2 if house.unpaid else 0
			house.illegal_hookup = index == 17
			d.houses.append(house)


func _create_poles(d: District) -> void:
	for i in range(7):
		var pole := Pole.new()
		pole.offset = Vector2(-0.65 + float(i % 4) * 0.40, 0.35 if i >= 4 else -0.35)
		for house_index in range(d.houses.size()):
			if house_index % 7 == i:
				pole.house_indices.append(house_index)
		d.poles.append(pole)


func _begin_shift() -> void:
	game_started = true
	help_open = false
	selected = -1
	show_more_actions = false
	time_alive = 0.0
	event_clock = 0.0
	income_clock = 0.0
	notice = "Tap a neighborhood to check its services."
	notice_timer = 6.0
	queue_redraw()


func _recalculate_supply() -> void:
	var total_power := 0.0
	var total_water := 0.0
	var available_power := 0.0
	var available_water := 0.0
	var demand_power := 0.0
	var demand_water := 0.0
	for facility in facilities:
		if facility.kind == "power":
			total_power += facility.capacity
			if not facility.fault:
				if facility.fuel_type == "diesel":
					available_power += facility.capacity * clampf(diesel_stock / 1000.0, 0.0, 1.0)
				elif facility.fuel_type == "solar":
					available_power += facility.capacity * (0.65 + 0.35 * maxf(0.0, sin(time_alive / 28.0)))
				else:
					available_power += facility.capacity
		else:
			total_water += facility.capacity
			if not facility.fault:
				available_water += facility.capacity
	for d in districts:
		demand_power += d.demand_power
		demand_water += d.demand_water
	power_supply = demand_power * (0.81 + 0.025 * sin(time_alive * 0.35)) * available_power / maxf(total_power, 1.0)
	water_supply = minf(demand_water * 0.86 * available_water / maxf(total_water, 1.0), reservoir * 1.15)


func _diesel_order_size() -> float:
	var deliveries_per_month := maxf(1.0, ceil(30.0 / float(diesel_frequency_days)))
	return float(diesel_monthly_plan) / deliveries_per_month


func _dispatch_diesel_order(liters: float, automatic: bool) -> bool:
	if diesel_truck_in_transit:
		if not automatic:
			notice = "The fuel truck is already on the road."
		return false
	var order_liters := minf(liters, diesel_tank_capacity - diesel_stock)
	if order_liters < 1.0:
		if not automatic:
			notice = "Diesel tanks are already full."
		return false
	var cost := order_liters * 0.12
	if treasury < cost:
		if not automatic:
			notice = "That delivery costs $" + str(int(cost)) + ". The treasury is short."
		return false
	treasury -= cost
	diesel_truck_liters = order_liters
	diesel_truck_eta = 18.0
	diesel_truck_in_transit = true
	if not automatic:
		diesel_next_order_day = diesel_days_elapsed + float(diesel_frequency_days)
	diesel_retry_timer = 0.0
	notice = "Diesel ordered: " + str(int(order_liters)) + " L. The tanker is on its way."
	notice_timer = 5.0
	return true


func _update_weather(delta: float) -> void:
	if is_raining:
		rain_remaining = maxf(0.0, rain_remaining - delta)
		if rain_remaining <= 0.0:
			is_raining = false
			weather_clock = 0.0
			rain_popup_seen = false
	else:
		weather_clock += delta
		if weather_clock >= next_rain_time:
			is_raining = true
			rain_remaining = 18.0
			rain_popup_seen = false
			next_rain_time = randf_range(50.0, 75.0)
			notice = "Rain is falling over the network."
			notice_timer = 5.0
	if is_raining and not rain_popup_seen and not diesel_panel_open:
		rain_popup_open = true


func _process(delta: float) -> void:
	var camera_blend := 1.0 - exp(-delta * 9.0)
	map_scale = lerpf(map_scale, target_map_scale, camera_blend)
	map_camera = map_camera.lerp(target_map_camera, camera_blend)
	_update_zoom_level()
	if not game_started or game_over:
		queue_redraw()
		return
	time_alive += delta
	event_clock += delta
	income_clock += delta
	diesel_days_elapsed += delta / 6.0
	notice_timer = maxf(0.0, notice_timer - delta)
	_update_weather(delta)
	if diesel_truck_in_transit:
		diesel_truck_eta = maxf(0.0, diesel_truck_eta - delta)
		if diesel_truck_eta <= 0.0:
			diesel_stock = minf(diesel_tank_capacity, diesel_stock + diesel_truck_liters)
			diesel_truck_in_transit = false
			diesel_truck_liters = 0.0
			notice = "Diesel tanker arrived. Reserve: " + str(int(diesel_stock)) + " L."
			notice_timer = 5.0
	if diesel_auto_purchase and diesel_days_elapsed >= diesel_next_order_day:
		diesel_retry_timer = maxf(0.0, diesel_retry_timer - delta)
		if diesel_retry_timer <= 0.0:
			if _dispatch_diesel_order(_diesel_order_size(), true):
				diesel_next_order_day += float(diesel_frequency_days)
			else:
				diesel_retry_timer = 6.0
	for d in districts:
		d.demand_power = clampf(d.demand_power + randf_range(-1.3, 1.3) * delta, 14.0, 46.0)
		d.demand_water = clampf(d.demand_water + randf_range(-0.9, 0.9) * delta, 12.0, 38.0)
	for facility in facilities:
		if facility.repairing:
			facility.repair_left = maxf(0.0, facility.repair_left - delta)
			if facility.repair_left <= 0.0:
				facility.repairing = false
				facility.fault = false
				notice = facility.title + " is back online."
				notice_timer = 5.0
	for d in districts:
		if d.repairing:
			d.repair_left = maxf(0.0, d.repair_left - delta)
			if d.repair_left <= 0.0:
				d.repairing = false
				var fixed_issue := d.issue
				d.issue = ""
				if fixed_issue in ["Transformer fault", "Copper theft"]:
					d.has_power = true
					for house in d.houses:
						house.has_power = true
				if fixed_issue == "Main pipe leak":
					d.has_water = true
					for house in d.houses:
						house.has_water = true
				notice = fixed_issue + " repaired in " + d.title + "."
				notice_timer = 5.0
		for pole in d.poles:
			if pole.repairing:
				pole.repair_left = maxf(0.0, pole.repair_left - delta)
				if pole.repair_left <= 0.0:
					pole.repairing = false
					pole.failed = false
					for house_index in pole.house_indices:
						d.houses[house_index].has_power = d.has_power
					notice = "Power pole repaired in " + d.title + "."
					notice_timer = 5.0
	crew_cooldown = maxf(0.0, crew_cooldown - delta)
	_recalculate_supply()
	power_used = 0.0
	water_used = 0.0
	for d in districts:
		if d.has_power:
			for house in d.houses:
				if house.has_power:
					power_used += d.demand_power / d.houses.size() * (1.3 if house.illegal_hookup else 1.0)
		if d.has_water:
			for house in d.houses:
				if house.has_water:
					water_used += d.demand_water / d.houses.size()

	# Water is a finite shared reserve; rain refills it slowly, leaks waste it.
	reservoir = clampf(reservoir + (1.8 if is_raining else 0.8) * delta - (water_used / 100.0) * delta, 0.0, 100.0)
	var diesel_capacity := 0.0
	var all_power_capacity := 0.0
	for facility in facilities:
		if facility.kind == "power" and not facility.fault:
			all_power_capacity += facility.capacity
			if facility.fuel_type == "diesel":
				diesel_capacity += facility.capacity
	diesel_stock = maxf(0.0, diesel_stock - power_used * diesel_capacity / maxf(all_power_capacity, 1.0) * 0.22 * delta)
	var power_shortage := maxf(0.0, power_used - power_supply)
	var water_shortage := maxf(0.0, water_used - water_supply)
	if power_shortage > 0.0:
		for d in districts:
			if d.has_power:
				d.unrest += (power_shortage / maxf(power_supply, 1.0)) * 0.8 * delta
	if water_shortage > 0.0 or reservoir < 8.0:
		for d in districts:
			if d.has_water:
				d.unrest += (0.45 if reservoir < 8.0 else 0.22) * delta
	for d in districts:
		var power_off_count := 0
		var water_off_count := 0
		for house in d.houses:
			if not house.has_power:
				power_off_count += 1
			if not house.has_water:
				water_off_count += 1
		d.unrest += (0.65 * power_off_count / d.houses.size() + 0.45 * water_off_count / d.houses.size()) * delta
		if power_off_count == 0 and water_off_count == 0 and power_shortage <= 0.0 and water_shortage <= 0.0:
			d.unrest = maxf(0.0, d.unrest - 1.8 * delta)
		if d.issue == "Main pipe leak":
			reservoir = maxf(0.0, reservoir - 0.35 * delta)
		if d.unrest >= 100.0:
			_end_game("Public patience ran out in " + d.title)
			return

	if income_clock >= 8.0:
		income_clock = 0.0
		_collect_tariffs()
	if event_clock >= randf_range(35.0, 45.0):
		event_clock = 0.0
		_spawn_incident()
	if treasury < -60.0:
		_end_game("The treasury is empty. Even the repair truck is out of fuel.")
		return
	if time_alive >= 180.0:
		_end_game("Shift complete. The city is mostly still here.")
		return
	queue_redraw()


func _collect_tariffs() -> void:
	var earned := 0.0
	for d in districts:
		for house in d.houses:
			if house.unpaid:
				house.arrears += 1
			else:
				earned += (int(house.has_power) + int(house.has_water)) * 0.2
	treasury += earned
	if earned > 0:
		notice = "Bills collected: +$" + str(int(earned)) + " (some accounts remain mysteriously unpaid)."
		notice_timer = 3.0


func _spawn_incident() -> void:
	var d: District = districts[randi_range(0, districts.size() - 1)]
	var house: House = d.houses[randi_range(0, d.houses.size() - 1)]
	if randi_range(0, 5) == 0:
		var working_poles: Array[Pole] = []
		for pole in d.poles:
			if not pole.failed and not pole.repairing:
				working_poles.append(pole)
		if not working_poles.is_empty():
			var pole: Pole = working_poles[randi_range(0, working_poles.size() - 1)]
			pole.failed = true
			for house_index in pole.house_indices:
				d.houses[house_index].has_power = false
			notice = "Power pole failure in " + d.title + ". Tap the red pole to dispatch a crew."
	elif not house.unpaid and randi_range(0, 2) == 0:
		house.unpaid = true
		house.arrears = 1
		notice = d.title + ": " + house.label + " has an overdue bill."
	elif not house.illegal_hookup and randi_range(0, 1) == 0:
		house.illegal_hookup = true
		notice = "Illegal hookup detected at " + d.title + " / " + house.label + "."
	else:
		var candidates: Array[Facility] = []
		for facility in facilities:
			if not facility.fault and not facility.repairing:
				candidates.append(facility)
		if not candidates.is_empty() and randi_range(0, 1) == 0:
			var facility: Facility = candidates[randi_range(0, candidates.size() - 1)]
			facility.fault = true
			facility.fault_name = "Equipment failure"
			notice = "Incident: " + facility.title + " has failed. Tap its marker to dispatch a team."
		else:
			d.issue = ["Transformer fault", "Main pipe leak", "Copper theft"][randi_range(0, 2)]
			if d.issue in ["Transformer fault", "Copper theft"]:
				d.has_power = false
				for h in d.houses:
					h.has_power = false
			elif d.issue == "Main pipe leak":
				d.has_water = false
				for h in d.houses:
					h.has_water = false
			notice = "Incident: " + d.issue.to_lower() + " in " + d.title + ". Tap the quartier to respond."
	notice_timer = 6.0


func _end_game(why: String) -> void:
	game_over = true
	reason = why
	best_time = maxf(best_time, time_alive)
	_save_best()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if map_drag_active and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_pan_map(motion.relative)
			return
	if event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
		if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			map_drag_active = false
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		active_touches[drag.index] = drag.position
		if active_touches.size() >= 2 and touch_pan_active:
			var touch_positions: Array = active_touches.values()
			var distance_now: float = touch_positions[0].distance_to(touch_positions[1])
			if pinch_distance > 0.0 and distance_now > 0.0:
				_zoom_at((touch_positions[0] + touch_positions[1]) * 0.5, distance_now / pinch_distance)
			pinch_distance = distance_now
		elif active_touches.size() == 1 and touch_pan_active:
			_pan_map(drag.relative)
		return
	var point := Vector2.ZERO
	var pressed := false
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		pressed = mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
		point = mouse.position
		if pressed and game_started and not game_over and _map_rect(get_viewport_rect().size).has_point(point):
			map_drag_active = true
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		pressed = touch.pressed
		point = touch.position
		if touch.pressed:
			active_touches[touch.index] = touch.position
			if active_touches.size() == 1:
				touch_pan_active = _map_rect(get_viewport_rect().size).has_point(touch.position)
			if active_touches.size() >= 2:
				var touch_positions: Array = active_touches.values()
				pinch_distance = touch_positions[0].distance_to(touch_positions[1])
		else:
			active_touches.erase(touch.index)
			if active_touches.size() < 2:
				pinch_distance = 0.0
			if active_touches.is_empty():
				touch_pan_active = false
		if touch.pressed and active_touches.size() >= 2:
			return
	if not pressed:
		if event is InputEventMouseButton:
			var wheel := event as InputEventMouseButton
			if wheel.pressed and wheel.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and game_started and not game_over and not diesel_panel_open and not rain_popup_open:
				_zoom_at(wheel.position, 1.18 if wheel.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.18)
		return
	if game_started and not game_over and (diesel_panel_open or rain_popup_open):
		for key in hitboxes:
			if (hitboxes[key] as Rect2).has_point(point):
				_handle_button(str(key))
				return
		return
	if not game_started:
		for key in hitboxes:
			if (hitboxes[key] as Rect2).has_point(point):
				if str(key) == "start":
					_begin_shift()
				elif str(key) in ["help", "help_close"]:
					help_open = not help_open
					queue_redraw()
				return
		return
	if game_over:
		for key in hitboxes:
			if str(key) == "restart" and (hitboxes[key] as Rect2).has_point(point):
				_reset()
				return
		return
	for key in hitboxes:
		if (hitboxes[key] as Rect2).has_point(point):
			_handle_button(str(key))
			return
	var map_rect := _map_rect(get_viewport_rect().size)
	if map_rect.has_point(point):
		var nearest_facility := -1
		var facility_distance := INF
		for i in facilities.size():
			var dist := _facility_point(facilities[i], map_rect).distance_to(point)
			if dist < facility_distance:
				facility_distance = dist
				nearest_facility = i
		if nearest_facility >= 0 and facility_distance < 32.0:
			selected_facility = nearest_facility
			selected = -1
			selected_house = -1
			selected_pole = -1
			show_more_actions = false
			queue_redraw()
			return
		if zoom_level == 2:
			var district := _district_for_zoomed_map()
			if district >= 0:
				var d: District = districts[district]
				var nearest_pole := -1
				var pole_distance := INF
				for pole_index in d.poles.size():
					var pole_screen := _pole_point(d, d.poles[pole_index], map_rect)
					var dist := pole_screen.distance_to(point)
					if dist < pole_distance:
						pole_distance = dist
						nearest_pole = pole_index
				if nearest_pole >= 0 and pole_distance < 28.0:
					selected = district
					selected_pole = nearest_pole
					selected_house = -1
					selected_facility = -1
					show_more_actions = false
					queue_redraw()
					return
				var nearest_house := -1
				var house_distance := INF
				for h in d.houses.size():
					var dist := _house_point(d, d.houses[h], map_rect).distance_to(point)
					if dist < house_distance:
						house_distance = dist
						nearest_house = h
				if nearest_house >= 0 and house_distance < 38.0:
					selected = district
					selected_house = nearest_house
					selected_pole = -1
					selected_facility = -1
					show_more_actions = false
					queue_redraw()
					return
		var closest := -1
		var distance := INF
		for i in districts.size():
			var marker := _district_point(districts[i], map_rect)
			var dist := marker.distance_to(point)
			if dist < distance:
				distance = dist
				closest = i
		if closest >= 0 and distance < (90.0 if zoom_level == 0 else 75.0):
			selected = closest
			selected_house = -1
			selected_pole = -1
			selected_facility = -1
			if zoom_level == 0:
				target_map_camera = Vector2.ZERO
				target_map_scale = 38.0
			elif zoom_level == 1:
				target_map_camera = _district_world(closest)
				target_map_scale = 350.0
			show_more_actions = false
			queue_redraw()


func _handle_button(action: String) -> void:
	if action == "fuel_panel":
		diesel_panel_open = true
		queue_redraw()
		return
	if action == "fuel_close":
		diesel_panel_open = false
		queue_redraw()
		return
	if action == "fuel_month_down":
		diesel_monthly_plan = maxi(1000, diesel_monthly_plan - 500)
	elif action == "fuel_month_up":
		diesel_monthly_plan = mini(12000, diesel_monthly_plan + 500)
	elif action == "fuel_frequency":
		var frequencies := [5, 10, 15, 30]
		var current_index: int = frequencies.find(diesel_frequency_days)
		diesel_frequency_days = frequencies[(current_index + 1) % frequencies.size()]
		diesel_next_order_day = diesel_days_elapsed + float(diesel_frequency_days)
	elif action == "fuel_auto":
		diesel_auto_purchase = not diesel_auto_purchase
	elif action == "fuel_order":
		if _dispatch_diesel_order(_diesel_order_size(), false):
			diesel_next_order_day = diesel_days_elapsed + float(diesel_frequency_days)
	elif action == "rain_cut_all":
		for d in districts:
			d.has_power = false
			for house in d.houses:
				house.has_power = false
		rain_popup_open = false
		rain_popup_seen = true
		notice = "Rain protocol activated: power cut in every quartier. The reason is still unclear."
		notice_timer = 6.0
		queue_redraw()
		return
	elif action == "rain_ignore":
		rain_popup_open = false
		rain_popup_seen = true
		notice = "Rain observed. No one can explain the outage policy."
		notice_timer = 5.0
		queue_redraw()
		return
	if action in ["fuel_month_down", "fuel_month_up", "fuel_frequency", "fuel_auto", "fuel_order"]:
		queue_redraw()
		return
	if action == "zoom_in":
		_zoom_map(1)
		return
	if action == "zoom_out":
		_zoom_map(-1)
		return
	if action == "zoom_home":
		zoom_level = 0
		target_map_scale = 2.2
		map_scale = 2.2
		target_map_camera = Vector2(55.0, 0.0)
		map_camera = target_map_camera
		selected = -1
		selected_house = -1
		selected_pole = -1
		selected_facility = -1
		map_pan = Vector2.ZERO
		queue_redraw()
		return
	if action == "more":
		show_more_actions = not show_more_actions
		queue_redraw()
		return
	if action == "close_selection":
		selected = -1
		selected_house = -1
		selected_pole = -1
		selected_facility = -1
		show_more_actions = false
		queue_redraw()
		return
	if selected_facility >= 0:
		_handle_facility_action(action)
		return
	if selected_pole >= 0 and selected >= 0:
		var d: District = districts[selected]
		var pole: Pole = d.poles[selected_pole]
		if action == "pole_repair":
			if pole.repairing:
				notice = "Pole crew is working: " + _clock_string(pole.repair_left) + " remaining."
			elif not pole.failed:
				notice = "This pole is operational."
			elif crew_cooldown > 0.0:
				notice = "Maintenance team returns in " + _clock_string(crew_cooldown) + "."
			elif treasury < 24.0:
				notice = "Pole repair needs $24 for parts and transport."
			else:
				treasury -= 24.0
				pole.repairing = true
				pole.repair_left = _repair_duration() * 0.7
				crew_cooldown = pole.repair_left + 8.0
				notice = "Crew dispatched to repair the power pole."
			notice_timer = 5.0
			queue_redraw()
		return
	if selected_house >= 0 and selected >= 0:
		_handle_house_action(action)
		return
	if selected < 0:
		if action == "upgrade_crew":
			_upgrade_crew()
		return
	var d: District = districts[selected]
	match action:
		"power":
			d.has_power = not d.has_power
			for house in d.houses:
				house.has_power = d.has_power
			notice = d.title + (" connected to the grid." if d.has_power else " put on the outage schedule.")
		"water":
			d.has_water = not d.has_water
			for house in d.houses:
				house.has_water = d.has_water
			notice = d.title + (" water valve opened." if d.has_water else " water rationed.")
		"repair":
			if d.repairing:
				notice = "Repair team is working: " + _clock_string(d.repair_left) + " remaining."
			elif crew_cooldown > 0.0:
				notice = "Maintenance team returns in " + _clock_string(crew_cooldown) + "."
			elif d.issue == "":
				notice = "No reported fault here. The paperwork is already caught up."
			else:
				var cost := 55 if d.issue == "Main pipe leak" else 38
				if treasury < cost:
					notice = "Repair costs $" + str(cost) + ". Treasury says: maybe tomorrow."
				else:
					treasury -= cost
					d.repairing = true
					d.repair_left = _repair_duration()
					crew_cooldown = d.repair_left + 12.0
					notice = "Team dispatched to " + d.title + ". Repair takes " + _clock_string(d.repair_left) + "."
		"inspect":
			var found := false
			for house in d.houses:
				if house.illegal_hookup:
					found = true
			if found:
				if treasury < 20:
					notice = "Inspection team needs $20 for fuel."
				else:
					treasury -= 20
					for house in d.houses:
						house.illegal_hookup = false
					notice = "Illegal connection removed in " + d.title + "."
			else:
				notice = "No illegal connection detected. Inspector requests per diem anyway."
		"billing":
			var count := 0
			for house in d.houses:
				if house.unpaid:
					count += 1
			if count > 0 and treasury >= 12:
				treasury -= 12
				for house in d.houses:
					if house.unpaid:
						treasury += house.arrears * 14
						house.arrears = 0
						house.unpaid = false
				notice = "Billing visit complete in " + d.title + "."
			else:
				notice = "No overdue bills found, or billing has no $12 fuel money."
		"upgrade_crew":
			_upgrade_crew()
		"loan":
			if not loan_used and treasury < 120.0:
				treasury += 180
				loan_used = true
				notice = "Emergency loan approved: +$180."
	notice_timer = 5.0
	queue_redraw()


func _map_rect(size: Vector2) -> Rect2:
	if _is_portrait(size):
		var portrait_top := 88.0
		var portrait_bottom := size.y - 380.0
		return Rect2(0.0, portrait_top, size.x, maxf(140.0, portrait_bottom - portrait_top))
	var margin := 22.0
	var desktop_top := 126.0
	var bottom := size.y - 94.0
	var width := size.x * 0.66
	return Rect2(margin, desktop_top, width - margin, maxf(200.0, bottom - desktop_top))


func _panel_rect(size: Vector2) -> Rect2:
	if _is_portrait(size):
		var has_selection := selected >= 0 or selected_house >= 0 or selected_pole >= 0 or selected_facility >= 0
		var panel_height := 136.0 if not has_selection else (380.0 if show_more_actions else 280.0)
		return Rect2(12.0, size.y - panel_height - 14.0, size.x - 24.0, panel_height)
	return Rect2(size.x * 0.69, 126.0, size.x * 0.29 - 22.0, size.y - 220.0)


func _is_portrait(size: Vector2) -> bool:
	return size.x < size.y


func _district_point(d: District, rect: Rect2) -> Vector2:
	return _world_to_screen(_geo_to_world(d.latitude, d.longitude), rect)


func _geo_to_world(latitude: float, longitude: float) -> Vector2:
	return Vector2((longitude - MAP_CENTER_LON) * 105.3, (MAP_CENTER_LAT - latitude) * 111.32)


func _district_world(index: int) -> Vector2:
	if index < 0 or index >= districts.size():
		return Vector2.ZERO
	var d: District = districts[index]
	return _geo_to_world(d.latitude, d.longitude)


func _facility_point(facility: Facility, rect: Rect2) -> Vector2:
	var world := _geo_to_world(facility.latitude, facility.longitude)
	return _world_to_screen(world, rect) + facility.display_offset


func _house_point(d: District, house: House, rect: Rect2) -> Vector2:
	var district_index := districts.find(d)
	var world := _district_world(district_index) + house.offset
	return _world_to_screen(world, rect)


func _pole_point(d: District, pole: Pole, rect: Rect2) -> Vector2:
	return _world_to_screen(_district_world(districts.find(d)) + pole.offset, rect)


func _world_to_screen(world: Vector2, rect: Rect2) -> Vector2:
	return rect.get_center() + Vector2((world.x - map_camera.x) * map_scale, -(world.y - map_camera.y) * map_scale) + map_pan


func _screen_to_world(point: Vector2, rect: Rect2) -> Vector2:
	var relative := point - rect.get_center() - map_pan
	return map_camera + Vector2(relative.x / maxf(map_scale, 0.001), -relative.y / maxf(map_scale, 0.001))


func _pan_map(screen_delta: Vector2) -> void:
	if not game_started or game_over or diesel_panel_open or rain_popup_open:
		return
	target_map_camera.x -= screen_delta.x / maxf(map_scale, 0.001)
	target_map_camera.y += screen_delta.y / maxf(map_scale, 0.001)
	queue_redraw()


func _zoom_at(point: Vector2, factor: float) -> void:
	var rect := _map_rect(get_viewport_rect().size)
	if not rect.has_point(point):
		point = rect.get_center()
	var anchor := _screen_to_world(point, rect)
	target_map_scale = clampf(target_map_scale * factor, 2.2, 760.0)
	var relative := point - rect.get_center() - map_pan
	target_map_camera = anchor - Vector2(relative.x / target_map_scale, -relative.y / target_map_scale)
	_update_zoom_level()
	queue_redraw()


func _update_zoom_level() -> void:
	zoom_level = 0 if map_scale < 10.0 else (1 if map_scale < 150.0 else 2)


func _district_for_zoomed_map() -> int:
	return selected if selected >= 0 else 0


func _district_unpaid_count(d: District) -> int:
	var count := 0
	for house in d.houses:
		if house.unpaid:
			count += 1
	return count


func _district_illegal_count(d: District) -> int:
	var count := 0
	for house in d.houses:
		if house.illegal_hookup:
			count += 1
	return count


func _district_failed_pole_count(d: District) -> int:
	var count := 0
	for pole in d.poles:
		if pole.failed:
			count += 1
	return count


func _zoom_map(amount: int) -> void:
	_zoom_at(_map_rect(get_viewport_rect().size).get_center(), 1.8 if amount > 0 else 1.0 / 1.8)
	if target_map_scale <= 2.21:
		selected = -1
		selected_house = -1
		selected_pole = -1
		selected_facility = -1
		target_map_camera = Vector2(55.0, 0.0)
		map_camera = target_map_camera


func _repair_duration() -> float:
	return maxf(6.0, 32.0 - (crew_level - 1) * 7.0)


func _upgrade_crew() -> void:
	if crew_level >= 3:
		notice = "Maintenance team is fully upgraded."
	elif treasury < 240.0:
		notice = "Crew upgrade needs $240. Keep collecting bills first."
	else:
		treasury -= 240.0
		crew_level += 1
		notice = "Maintenance crew upgraded to level " + str(crew_level) + ". Repairs are faster now."
	notice_timer = 5.0
	queue_redraw()


func _handle_facility_action(action: String) -> void:
	var facility: Facility = facilities[selected_facility]
	if action == "repair_facility":
		if facility.repairing:
			notice = "Team is at the site: " + _clock_string(facility.repair_left) + " left."
		elif crew_cooldown > 0.0:
			notice = "Maintenance team returns in " + _clock_string(crew_cooldown) + "."
		elif not facility.fault:
			notice = facility.title + " is operating normally."
		elif treasury < 65.0:
			notice = "Dispatch needs $65 for parts and fuel."
		else:
			treasury -= 65.0
			facility.repairing = true
			facility.repair_left = _repair_duration() + 10.0
			crew_cooldown = facility.repair_left + 12.0
			notice = "Team dispatched to " + facility.title + ". It will take " + _clock_string(facility.repair_left) + "."
	elif action == "upgrade_crew":
		_upgrade_crew()
	notice_timer = 5.0
	queue_redraw()


func _handle_house_action(action: String) -> void:
	var d: District = districts[selected]
	var house: House = d.houses[selected_house]
	match action:
		"house_power":
			house.has_power = not house.has_power
			notice = house.label + (" reconnected to power." if house.has_power else " disconnected from power.")
		"house_water":
			house.has_water = not house.has_water
			notice = house.label + (" water restored." if house.has_water else " water valve closed.")
		"house_bill":
			if not house.unpaid:
				notice = "This account is paid up."
			elif treasury < 12.0:
				notice = "Billing visit needs $12 fuel."
			else:
				treasury -= 12.0
				treasury += house.arrears * 14.0
				house.arrears = 0
				house.unpaid = false
				notice = house.label + " settled its bill."
		"house_inspect":
			if not house.illegal_hookup:
				notice = "No illegal connection found at this house."
			elif treasury < 20.0:
				notice = "Inspection needs $20 fuel."
			else:
				treasury -= 20.0
				house.illegal_hookup = false
				notice = "Illegal hookup removed from " + house.label + "."
		"upgrade_crew":
			_upgrade_crew()
	notice_timer = 5.0
	queue_redraw()


func _button(name: String, rect: Rect2, label: String, active := false, danger := false) -> void:
	hitboxes[name] = rect
	var fill := PANEL_HI if active else TEAL
	if danger:
		fill = RED
	_draw_round_rect(rect, fill, 18)
	var color := INK if active else Color.WHITE
	draw_string(font, rect.position + Vector2(9, rect.size.y * 0.67), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 18.0, 14, color)


func _draw_round_rect(rect: Rect2, fill: Color, radius: float = 22.0) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.corner_radius_top_left = int(radius)
	style.corner_radius_top_right = int(radius)
	style.corner_radius_bottom_left = int(radius)
	style.corner_radius_bottom_right = int(radius)
	style.anti_aliasing = true
	draw_style_box(style, rect)


func _draw_title_screen(size: Vector2) -> void:
	# Quiet, illustrated title screen: one obvious action and an optional help card.
	var sky_top := Color("#f7f4e9")
	var sky_bottom := Color("#dcebe0")
	for band in 28:
		var t := float(band) / 27.0
		var band_color := sky_top.lerp(sky_bottom, t)
		draw_rect(Rect2(0, size.y * band / 28.0, size.x, size.y / 28.0 + 1.0), band_color)
	var title_y := size.y * 0.17
	draw_string(font, Vector2(0, title_y - 20), "A CITY-SERVICES GAME", HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, TEAL)
	draw_string(font, Vector2(0, title_y + 40), "JIRAMATY", HORIZONTAL_ALIGNMENT_CENTER, size.x, 48, INK)
	draw_string(font, Vector2(size.x * 0.12, title_y + 82), "Keep the city going, one neighborhood at a time.", HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.76, 15, MUTED)
	_draw_city_illustration(size)
	var start_h := clampf(size.y * 0.052, 52.0, 66.0)
	var button_rect := Rect2(size.x * 0.10, size.y * 0.755, size.x * 0.80, start_h)
	_draw_round_rect(Rect2(button_rect.position + Vector2(0, 5), button_rect.size), Color("#1c6759", 0.20), 28)
	_draw_round_rect(button_rect, TEAL, 28)
	draw_string(font, Vector2(button_rect.position.x, button_rect.position.y + 42), "START A SHIFT", HORIZONTAL_ALIGNMENT_CENTER, button_rect.size.x, 19, Color.WHITE)
	hitboxes["start"] = button_rect
	var help_h := clampf(size.y * 0.042, 48.0, 54.0)
	var help_rect := Rect2(size.x * 0.25, size.y * 0.845, size.x * 0.50, help_h)
	_draw_round_rect(help_rect, Color("#fffdf7", 0.82), 24)
	draw_string(font, Vector2(help_rect.position.x, help_rect.position.y + 33), "HOW TO PLAY", HORIZONTAL_ALIGNMENT_CENTER, help_rect.size.x, 14, INK)
	hitboxes["help"] = help_rect
	if best_time > 0.0:
		draw_string(font, Vector2(0, size.y * 0.94), "BEST SHIFT  " + _clock_string(best_time), HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, MUTED)


func _draw_city_illustration(size: Vector2) -> void:
	var width := size.x
	var base_y := size.y * 0.665
	# Soft landscape layers keep the illustration warm and legible behind the city.
	draw_colored_polygon(PackedVector2Array([Vector2(0, base_y - 18), Vector2(width * 0.22, base_y - 94), Vector2(width * 0.43, base_y - 25), Vector2(width * 0.65, base_y - 105), Vector2(width, base_y - 20), Vector2(width, size.y * 0.76), Vector2(0, size.y * 0.76)]), Color("#bfd9c7"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, base_y + 18), Vector2(width * 0.30, base_y - 20), Vector2(width * 0.58, base_y + 5), Vector2(width * 0.82, base_y - 35), Vector2(width, base_y + 12), Vector2(width, size.y * 0.76), Vector2(0, size.y * 0.76)]), Color("#a9cbb4"))
	var buildings := [
		[0.05, 0.16, 0.10, "#789e88"], [0.17, 0.10, 0.11, "#5d8979"],
		[0.30, 0.19, 0.12, "#86a994"], [0.44, 0.13, 0.10, "#4f8172"],
		[0.56, 0.21, 0.12, "#779c87"], [0.70, 0.14, 0.11, "#578576"],
		[0.83, 0.18, 0.12, "#83a891"],
	]
	for item in buildings:
		var bx := width * float(item[0])
		var bh := size.y * float(item[1])
		var bw := width * float(item[2])
		var by := base_y - bh
		_draw_round_rect(Rect2(bx, by, bw, bh), Color(item[3]), 10)
		for row in 3:
			for col in 2:
				var wx := bx + bw * (0.25 + col * 0.42)
				var wy := by + bh * (0.20 + row * 0.23)
				draw_circle(Vector2(wx, wy), 3.2, Color("#f8d99c", 0.82))
	# A water tower and two softly lit utility poles make the theme read at a glance.
	var tower_x := width * 0.23
	var tower_y := base_y - size.y * 0.25
	draw_line(Vector2(tower_x, tower_y + 26), Vector2(tower_x, base_y - 4), Color("#39766b"), 6)
	_draw_round_rect(Rect2(tower_x - 22, tower_y, 44, 30), Color("#f0a36c"), 14)
	draw_line(Vector2(width * 0.12, base_y - 5), Vector2(width * 0.12, base_y - size.y * 0.20), Color("#4d786e"), 4)
	draw_line(Vector2(width * 0.12, base_y - size.y * 0.18), Vector2(width * 0.81, base_y - size.y * 0.18), Color("#4d786e", 0.75), 2)
	draw_line(Vector2(width * 0.81, base_y - size.y * 0.18), Vector2(width * 0.81, base_y - 5), Color("#4d786e"), 4)
	draw_circle(Vector2(width * 0.12, base_y - size.y * 0.18), 5, AMBER)
	draw_circle(Vector2(width * 0.81, base_y - size.y * 0.18), 5, AMBER)
	draw_rect(Rect2(0, base_y, width, size.y * 0.76 - base_y), Color("#e6c08c"))


func _draw_help(size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#17302b", 0.56))
	var card := Rect2(size.x * 0.08, size.y * 0.29, size.x * 0.84, size.y * 0.40)
	_draw_round_rect(card, PANEL, 28)
	draw_string(font, Vector2(card.position.x + 22, card.position.y + 42), "A SIMPLE FIRST SHIFT", HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 44, 20, INK)
	var copy_y := card.position.y + 86
	var instructions := [
		"1. Tap a quartier, then zoom in to inspect homes and poles.",
		"2. Drag to pan; pinch or use + / − to zoom smoothly.",
		"3. Manage power, water, fuel, repairs, and overdue bills.",
		"4. Keep public patience and the treasury above zero.",
	]
	for line in instructions:
		draw_string(font, Vector2(card.position.x + 22, copy_y), line, HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 44, 14, MUTED)
		copy_y += 34
	var close_rect := Rect2(card.position.x + 18, card.end.y - 70, card.size.x - 36, 52)
	_button("help_close", close_rect, "GOT IT", false)


func _draw() -> void:
	var size := get_viewport_rect().size
	hitboxes.clear()
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	if not game_started:
		_draw_title_screen(size)
		if help_open:
			_draw_help(size)
		return
	_draw_header(size)
	_draw_map(size)
	_draw_panel(size)
	_draw_footer(size)
	if diesel_panel_open:
		_draw_diesel_panel(size)
	if rain_popup_open and not diesel_panel_open:
		_draw_rain_popup(size)
	if game_over:
		_draw_game_over(size)


func _draw_header(size: Vector2) -> void:
	if _is_portrait(size):
		_draw_round_rect(Rect2(12, 10, size.x - 24, 62), PANEL, 24)
		draw_string(font, Vector2(27, 37), "JIRAMATY", HORIZONTAL_ALIGNMENT_LEFT, 132, 19, INK)
		draw_string(font, Vector2(29, 54), "SHIFT " + _clock_string(time_alive), HORIZONTAL_ALIGNMENT_LEFT, 100, 10, MUTED)
		var cash_color := RED if treasury < 100 else TEAL
		draw_string(font, Vector2(size.x - 146, 38), "$" + str(int(treasury)), HORIZONTAL_ALIGNMENT_RIGHT, 126, 18, cash_color)
		draw_string(font, Vector2(size.x - 146, 55), _clock_string(maxf(0.0, 180.0 - time_alive)) + " LEFT", HORIZONTAL_ALIGNMENT_RIGHT, 126, 10, MUTED)
		return
	draw_rect(Rect2(0, 0, size.x, 104), PANEL)
	draw_rect(Rect2(0, 102, size.x, 2), TEAL)
	draw_string(font, Vector2(24, 38), "JIRAMATY", HORIZONTAL_ALIGNMENT_LEFT, 240, 27, INK)
	draw_string(font, Vector2(26, 65), "UTILITY CRISIS MANAGER", HORIZONTAL_ALIGNMENT_LEFT, 240, 12, TEAL)
	draw_string(font, Vector2(size.x * 0.37, 38), "SHIFT " + _clock_string(time_alive), HORIZONTAL_ALIGNMENT_LEFT, 170, 20, INK)
	draw_string(font, Vector2(size.x * 0.37, 65), "BEST " + _clock_string(best_time), HORIZONTAL_ALIGNMENT_LEFT, 170, 12, MUTED)
	var cash_color := RED if treasury < 100 else AMBER
	draw_string(font, Vector2(size.x - 205, 39), "$" + str(int(treasury)), HORIZONTAL_ALIGNMENT_RIGHT, 175, 25, cash_color)
	draw_string(font, Vector2(size.x - 205, 65), "TREASURY", HORIZONTAL_ALIGNMENT_RIGHT, 175, 12, MUTED)
	# Resource strips summarize shared capacity and demand.
	var bar_x := size.x * 0.55
	var bar_w := size.x * 0.21
	draw_string(font, Vector2(bar_x, 31), "POWER", HORIZONTAL_ALIGNMENT_LEFT, 80, 11, MUTED)
	draw_string(font, Vector2(bar_x, 50), str(int(power_used)) + " / " + str(int(power_supply)), HORIZONTAL_ALIGNMENT_LEFT, 130, 15, INK)
	_draw_meter(Rect2(bar_x + 100, 39, bar_w - 100, 9), power_used / maxf(power_supply, 1.0), RED, TEAL)
	draw_string(font, Vector2(bar_x, 76), "WATER", HORIZONTAL_ALIGNMENT_LEFT, 80, 11, MUTED)
	draw_string(font, Vector2(bar_x, 93), str(int(water_used)) + " / " + str(int(water_supply)), HORIZONTAL_ALIGNMENT_LEFT, 130, 15, INK)
	_draw_meter(Rect2(bar_x + 100, 82, bar_w - 100, 9), water_used / maxf(water_supply, 1.0), RED, TEAL)


func _draw_map(size: Vector2) -> void:
	var r := _map_rect(size)
	draw_rect(r, Color("#d5e4d4") if zoom_level == 0 else Color("#dfead9"))
	if zoom_level == 0:
		_draw_regional_map(r)
	elif zoom_level == 1:
		_draw_city_map(r)
	else:
		_draw_quartier_map(r)
	var level_names: Array[String] = ["REGIONAL GRID", "ANTANANARIVO", "QUARTIER / HOUSES"]
	var level_name: String = level_names[zoom_level]
	draw_string(font, r.position + Vector2(70 if zoom_level > 0 else 14, 24), level_name, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 130, 11, MUTED)
	_button("zoom_out", Rect2(r.end.x - 110, r.position.y + 8, 48, 48), "−", false)
	_button("fuel_panel", Rect2(r.end.x - 166, r.position.y + 8, 48, 48), "FUEL", diesel_panel_open)
	_button("zoom_in", Rect2(r.end.x - 58, r.position.y + 8, 48, 48), "+", false)
	if zoom_level > 0:
		_button("zoom_home", Rect2(r.position.x + 10, r.position.y + 8, 48, 48), "MAP", false)


func _draw_regional_map(r: Rect2) -> void:
	var tana := _district_point(districts[0], r)
	var ambohi := _facility_point(facilities[1], r)
	var andekaleka := _facility_point(facilities[0], r)
	var antelomita := _facility_point(facilities[2], r)
	var mandroseza := _facility_point(facilities[3], r)
	draw_line(andekaleka, ambohi, Color("#e9a056", 0.75), 3.0)
	draw_line(ambohi, tana, Color("#e9a056", 0.75), 3.0)
	draw_line(antelomita, ambohi, Color("#e9a056", 0.60), 2.0)
	draw_line(mandroseza, tana, Color("#4682bd", 0.62), 2.5)
	draw_line(_facility_point(facilities[4], r), tana, Color("#4682bd", 0.40), 1.8)
	draw_line(_facility_point(facilities[5], r), tana, Color("#4682bd", 0.40), 1.8)
	draw_line(_facility_point(facilities[6], r), tana, Color("#e9a056", 0.50), 2.0)
	draw_line(_facility_point(facilities[7], r), tana, Color("#6d88b6", 0.60), 2.0)
	draw_line(_facility_point(facilities[8], r), tana, Color("#d7a648", 0.62), 2.0)
	_draw_city_boundary(r, Color("#24836d", 0.07), Color("#24836d", 0.42), 2.0)
	draw_circle(tana, 25.0, Color("#ffffff", 0.74))
	draw_circle(tana, 18.0, TEAL)
	draw_string(font, tana + Vector2(-75, 42), "ANTANANARIVO · tap to zoom", HORIZONTAL_ALIGNMENT_CENTER, 150, 11, INK)
	for facility in facilities:
		_draw_facility_marker(facility, r, 0)


func _draw_city_map(r: Rect2) -> void:
	_draw_city_boundary(r, Color("#d2e0ca", 0.75), Color("#82a990", 0.8), 2.0)
	# Main roads bend between actual quartier anchors rather than forming a generic grid.
	_draw_road_world([_district_world(1), _district_world(1) + Vector2(-1.2, -0.9), _district_world(0) + Vector2(1.2, 0.2), _district_world(4), _district_world(2), _district_world(3)], r, 10.0)
	_draw_road_world([_district_world(1) + Vector2(0.1, -0.8), _district_world(0) + Vector2(0.6, -1.0), _district_world(5) + Vector2(-0.5, 1.3), _district_world(5)], r, 7.0)
	_draw_road_world([_district_world(4), _district_world(4) + Vector2(0.4, -0.7), _district_world(5) + Vector2(-0.4, 0.6)], r, 6.0)
	for i in districts.size():
		var d: District = districts[i]
		var center := _district_point(d, r)
		var fill := Color("#c9dfce", 0.60) if d.has_power and d.has_water else Color("#f0d8b6", 0.62)
		if d.issue != "" or d.unrest > 65.0:
			fill = Color("#f1c0b7", 0.68)
		_draw_quartier_boundary(i, r, fill, TEAL if i == selected else Color("#fffdf7", 0.95), 2.0 if i == selected else 1.2)
		draw_string(font, center + Vector2(-66, 5), d.title, HORIZONTAL_ALIGNMENT_CENTER, 132, 11, INK)
		var alert_count := 0
		for house in d.houses:
			if house.unpaid or house.illegal_hookup:
				alert_count += 1
		var failed_pole := false
		for pole in d.poles:
			failed_pole = failed_pole or pole.failed
		if d.issue != "" or alert_count > 0 or failed_pole:
			draw_circle(center + Vector2(16, -15), 7.0, RED if d.issue != "" or failed_pole else AMBER)
	for facility in facilities:
		if absf(facility.latitude - MAP_CENTER_LAT) < 0.20 and absf(facility.longitude - MAP_CENTER_LON) < 0.22:
			_draw_facility_marker(facility, r, 1)


func _draw_quartier_map(r: Rect2) -> void:
	var d_index := _district_for_zoomed_map()
	if d_index < 0:
		return
	var d: District = districts[d_index]
	var district_world := _district_world(d_index)
	var local_boundary := [Vector2(-0.95,-0.55), Vector2(-0.66,-0.83), Vector2(-0.18,-0.80), Vector2(0.22,-0.67), Vector2(0.72,-0.69), Vector2(0.90,-0.38), Vector2(0.83,0.18), Vector2(0.98,0.53), Vector2(0.60,0.78), Vector2(0.12,0.70), Vector2(-0.27,0.84), Vector2(-0.73,0.66), Vector2(-0.88,0.24)]
	_draw_local_polygon(district_world, local_boundary, r, Color("#c7ddca", 0.55), Color("#79a58c", 0.9), 2.0)
	# Streets and service lines follow the uneven residential blocks.
	var local_roads := [
		[Vector2(-1.0,-0.48), Vector2(-0.58,-0.38), Vector2(-0.12,-0.42), Vector2(0.34,-0.31), Vector2(0.88,-0.38)],
		[Vector2(-0.92,0.05), Vector2(-0.48,0.13), Vector2(-0.04,0.06), Vector2(0.44,0.16), Vector2(0.96,0.08)],
		[Vector2(-0.62,-0.86), Vector2(-0.55,-0.45), Vector2(-0.50,-0.02), Vector2(-0.43,0.42), Vector2(-0.35,0.82)],
		[Vector2(0.42,-0.79), Vector2(0.36,-0.42), Vector2(0.43,-0.02), Vector2(0.50,0.35), Vector2(0.58,0.80)]
	]
	for road in local_roads:
		_draw_road_local(district_world, road, r, 5.0)
	# Roadside electrical conductors, with poles at the junctions.
	var lower_wire := PackedVector2Array()
	var upper_wire := PackedVector2Array()
	for pole_index in d.poles.size():
		if pole_index < 4:
			lower_wire.append(_world_to_screen(district_world + d.poles[pole_index].offset, r))
		else:
			upper_wire.append(_world_to_screen(district_world + d.poles[pole_index].offset, r))
	if lower_wire.size() > 1:
		draw_polyline(lower_wire, Color("#348b70", 0.72), 2.0, true)
	if upper_wire.size() > 1:
		draw_polyline(upper_wire, Color("#348b70", 0.72), 2.0, true)
	for house in d.houses:
		var p := _house_point(d, house, r)
		_draw_house_icon(p, house)
		draw_string(font, p + Vector2(15, 4), house.label.replace("House ", "H"), HORIZONTAL_ALIGNMENT_LEFT, 26, 8, INK)
		if selected_house >= 0 and d.houses[selected_house] == house:
			draw_arc(p, 22.0, 0, TAU, 24, INK, 2.0)
	for pole_index in d.poles.size():
		_draw_pole_icon(_pole_point(d, d.poles[pole_index], r), d.poles[pole_index], pole_index == selected_pole)
	draw_string(font, r.position + Vector2(14, 48), d.title + " · " + str(d.houses.size()) + " accounts", HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 28, 12, INK)
	draw_string(font, r.position + Vector2(14, 66), "Houses · poles · roadside wires   |   red = fault / overdue", HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 28, 10, MUTED)


func _draw_city_boundary(rect: Rect2, fill: Color, outline: Color, width: float) -> void:
	var outline_offsets := [Vector2(-6.9,-2.0), Vector2(-6.0,-4.0), Vector2(-3.9,-4.6), Vector2(-1.6,-4.0), Vector2(0.6,-3.5), Vector2(2.8,-2.4), Vector2(3.5,-0.7), Vector2(2.8,1.4), Vector2(1.5,3.2), Vector2(0.2,5.4), Vector2(-0.7,6.5), Vector2(-2.5,6.2), Vector2(-3.8,5.1), Vector2(-5.7,3.2), Vector2(-6.8,1.0)]
	_draw_local_polygon(Vector2.ZERO, outline_offsets, rect, fill, outline, width)


func _draw_quartier_boundary(index: int, rect: Rect2, fill: Color, outline: Color, width: float) -> void:
	var center := _district_world(index)
	var size := 0.9 + float(index % 3) * 0.14
	var points := [Vector2(-1.2,-0.4), Vector2(-0.8,-0.95), Vector2(-0.15,-0.85), Vector2(0.35,-1.02), Vector2(0.98,-0.68), Vector2(1.12,-0.12), Vector2(0.84,0.52), Vector2(0.35,0.96), Vector2(-0.22,0.78), Vector2(-0.76,0.92), Vector2(-1.08,0.42)]
	var scaled_points: Array[Vector2] = []
	for point in points:
		scaled_points.append(point * size)
	_draw_local_polygon(center, scaled_points, rect, fill, outline, width)


func _draw_local_polygon(center: Vector2, offsets: Array, rect: Rect2, fill: Color, outline: Color, width: float) -> void:
	var points := PackedVector2Array()
	for offset in offsets:
		points.append(_world_to_screen(center + offset, rect))
	if points.size() >= 3:
		draw_colored_polygon(points, fill)
		var closed := points.duplicate()
		closed.append(points[0])
		draw_polyline(closed, outline, width, true)


func _draw_road_world(points: Array, rect: Rect2, width: float) -> void:
	var screen_points := PackedVector2Array()
	for point in points:
		screen_points.append(_world_to_screen(point, rect))
	if screen_points.size() < 2:
		return
	draw_polyline(screen_points, Color("#a08d6d", 0.82), width + 3.0, true)
	draw_polyline(screen_points, Color("#f4f0e3", 0.96), width, true)


func _draw_road_local(center: Vector2, offsets: Array, rect: Rect2, width: float) -> void:
	var world_points: Array[Vector2] = []
	for offset in offsets:
		world_points.append(center + offset)
	_draw_road_world(world_points, rect, width)


func _draw_house_icon(point: Vector2, house: House) -> void:
	var wall_colors := [Color("#f7ead0"), Color("#e8dfc7"), Color("#d9e4dc"), Color("#f2dfc6")]
	var roof_colors := [Color("#b96c58"), Color("#687c79"), Color("#91704f"), Color("#c28a50")]
	var wall: Color = wall_colors[house.style]
	var roof: Color = roof_colors[house.style]
	if house.unpaid:
		roof = RED
	elif house.illegal_hookup:
		roof = AMBER
	var building := Rect2(point.x - 11.0, point.y - 2.0, 22.0, 16.0)
	if house.style == 2:
		building = Rect2(point.x - 9.0, point.y - 10.0, 18.0, 24.0)
	draw_rect(building.grow(2), Color("#fffdf7"))
	draw_rect(building, wall)
	if house.style == 2:
		draw_rect(Rect2(point.x - 11, point.y - 14, 22, 5), roof)
	else:
		var roof_shape := PackedVector2Array([Vector2(point.x - 14, point.y - 1), Vector2(point.x, point.y - 12), Vector2(point.x + 14, point.y - 1)])
		draw_colored_polygon(roof_shape, roof)
	var window_color := Color("#ffd77a") if house.has_power else Color("#84938a")
	draw_rect(Rect2(point.x - 7, point.y + 2, 5, 5), window_color)
	draw_rect(Rect2(point.x + 2, point.y + 2, 5, 5), window_color)
	draw_rect(Rect2(point.x - 1.5, point.y + 7, 4, 7), Color("#8a6651"))
	draw_circle(point + Vector2(11, -9), 3.2, Color("#4682bd") if house.has_water else Color("#aeb7b0"))


func _draw_pole_icon(point: Vector2, pole: Pole, is_selected: bool) -> void:
	var tint := RED if pole.failed else (AMBER if pole.repairing else Color("#56645c"))
	draw_line(point + Vector2(0, -8), point + Vector2(0, 8), Color("#fffdf7"), 5.0)
	draw_line(point + Vector2(0, -8), point + Vector2(0, 8), tint, 2.0)
	draw_line(point + Vector2(-5, -6), point + Vector2(5, -6), tint, 2.0)
	if is_selected or pole.failed:
		draw_circle(point + Vector2(8, -7), 7.0, Color("#fffdf7", 0.9))
		draw_circle(point + Vector2(8, -7), 4.0, tint)


func _draw_facility_marker(facility: Facility, r: Rect2, level: int) -> void:
	var p := _facility_point(facility, r)
	if not r.grow(18).has_point(p):
		return
	var color := Color("#24836d")
	match facility.fuel_type:
		"hydro":
			color = Color("#258f7a")
		"hfo":
			color = Color("#d28244")
		"diesel":
			color = Color("#7763ad")
		"solar":
			color = Color("#d3a832")
		"water":
			color = Color("#4682bd")
	if facility.fault:
		color = RED
	draw_circle(p, 10.0 if level == 0 else 8.0, Color("#fffdf7"))
	draw_circle(p, 7.0 if level == 0 else 5.0, color)
	if selected_facility >= 0 and facilities[selected_facility] == facility:
		draw_arc(p, 13.0, 0, TAU, 32, INK, 2.0)
	draw_string(font, p + Vector2(9, -7), facility.title, HORIZONTAL_ALIGNMENT_LEFT, 155, 9, INK)


func _draw_panel(size: Vector2) -> void:
	var r := _panel_rect(size)
	_draw_round_rect(Rect2(r.position + Vector2(0, 6), r.size), Color("#344b40", 0.12), 28)
	_draw_round_rect(r, PANEL, 28)
	if selected_facility >= 0:
		_draw_facility_panel(r, facilities[selected_facility])
		return
	if selected_pole >= 0 and selected >= 0:
		_draw_pole_panel(r, districts[selected], districts[selected].poles[selected_pole])
		return
	if selected_house >= 0 and selected >= 0:
		_draw_house_panel(r, districts[selected], districts[selected].houses[selected_house])
		return
	if selected < 0:
		var prompt := "Tap a neighborhood to get started."
		draw_string(font, Vector2(r.position.x + 18, r.position.y + 38), "Your shift is ready", HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 36, 19, INK)
		draw_string(font, Vector2(r.position.x + 18, r.position.y + 68), prompt, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 36, 13, MUTED)
		draw_string(font, Vector2(r.position.x + 18, r.position.y + 98), "First incident in  " + _clock_string(maxf(0.0, 35.0 - time_alive)), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 36, 11, TEAL)
		_button("upgrade_crew", Rect2(r.end.x - 132, r.position.y + 18, 112, 44), "CREW  Lv" + str(crew_level) + "  ↑", false)
		return
	var d: District = districts[selected]
	if _is_portrait(size):
		_draw_portrait_panel(r, d)
	else:
		_draw_desktop_panel(r, d)


func _draw_pole_panel(r: Rect2, d: District, pole: Pole) -> void:
	var x := r.position.x + 18.0
	var width := r.size.x - 36.0
	draw_string(font, Vector2(x, r.position.y + 28), "DISTRIBUTION POLE", HORIZONTAL_ALIGNMENT_LEFT, width, 11, TEAL)
	draw_string(font, Vector2(x, r.position.y + 60), d.title + " · Pole " + str(selected_pole + 1), HORIZONTAL_ALIGNMENT_LEFT, width, 20, INK)
	var state := "Crew repairing · " + _clock_string(pole.repair_left) if pole.repairing else ("Failed · " + str(pole.house_indices.size()) + " homes affected" if pole.failed else "Operational")
	draw_string(font, Vector2(x, r.position.y + 91), state, HORIZONTAL_ALIGNMENT_LEFT, width, 13, RED if pole.failed else MUTED)
	_button("pole_repair", Rect2(x, r.position.y + 112, width, 42), "REPAIR POLE  ·  $24", pole.failed and not pole.repairing, pole.failed and not pole.repairing)


func _draw_desktop_panel(r: Rect2, d: District) -> void:
	var x := r.position.x + 16.0
	var width := r.size.x - 32.0
	draw_string(font, Vector2(x, r.position.y + 24), "DISPATCH DESK", HORIZONTAL_ALIGNMENT_LEFT, width, 11, TEAL)
	draw_string(font, Vector2(x, r.position.y + 52), d.title, HORIZONTAL_ALIGNMENT_LEFT, width, 21, INK)
	draw_string(font, Vector2(x, r.position.y + 75), "POWER " + str(int(d.demand_power)) + "   WATER " + str(int(d.demand_water)), HORIZONTAL_ALIGNMENT_LEFT, width, 12, MUTED)
	var yy := r.position.y + 101.0
	draw_string(font, Vector2(x, yy), "CONNECTIONS", HORIZONTAL_ALIGNMENT_LEFT, width, 10, MUTED)
	yy += 11
	var bw := (width - 8.0) / 2.0
	_button("power", Rect2(x, yy, bw, 34), "⚡  " + ("ON" if d.has_power else "OFF"), d.has_power, not d.has_power)
	_button("water", Rect2(x + bw + 8.0, yy, bw, 34), "●  " + ("WATER ON" if d.has_water else "WATER OFF"), d.has_water, not d.has_water)
	yy += 51.0
	draw_string(font, Vector2(x, yy), "FIELD CONDITIONS", HORIZONTAL_ALIGNMENT_LEFT, width, 10, MUTED)
	yy += 20
	var issue_text := d.issue if d.issue != "" else "No active infrastructure fault"
	var illegal_count := _district_illegal_count(d)
	var unpaid_count := _district_unpaid_count(d)
	var failed_poles := _district_failed_pole_count(d)
	if illegal_count > 0:
		issue_text += "  ·  illegal hookups " + str(illegal_count)
	if unpaid_count > 0:
		issue_text += "  ·  overdue accounts " + str(unpaid_count)
	if failed_poles > 0:
		issue_text += "  ·  failed poles " + str(failed_poles)
	draw_string(font, Vector2(x, yy), issue_text, HORIZONTAL_ALIGNMENT_LEFT, width, 12, RED if d.issue != "" or failed_poles > 0 else (AMBER if illegal_count > 0 or unpaid_count > 0 else INK))
	yy += 27.0
	draw_string(font, Vector2(x, yy), "PUBLIC PATIENCE", HORIZONTAL_ALIGNMENT_LEFT, width, 10, MUTED)
	_draw_meter(Rect2(x, yy + 8, width, 8), d.unrest / 100.0, RED, TEAL)
	yy += 34.0
	_button("repair", Rect2(x, yy, width, 34), "REPAIR FAULT  ·  $38–55", d.issue != "", d.issue != "")
	yy += 41.0
	_button("inspect", Rect2(x, yy, width, 34), "INSPECT METER  ·  $20", _district_illegal_count(d) > 0)
	yy += 41.0
	_button("billing", Rect2(x, yy, width, 34), "VISIT BILLING  ·  $12", _district_unpaid_count(d) > 0)
	yy += 46.0
	var reserve_y := mini(yy + 3.0, r.end.y - 34.0)
	draw_string(font, Vector2(x, reserve_y), "RESERVOIR  " + str(int(reservoir)) + "%", HORIZONTAL_ALIGNMENT_LEFT, width, 10, MUTED)
	_draw_meter(Rect2(x, reserve_y + 9.0, width, 7), reservoir / 100.0, TEAL, TEAL)
	if treasury < 120.0 and not loan_used:
		_button("loan", Rect2(x, r.end.y - 40.0, width, 36), "EMERGENCY LOAN  +$180", false, true)


func _draw_portrait_panel(r: Rect2, d: District) -> void:
	var x := r.position.x + 12.0
	var width := r.size.x - 24.0
	var base_y := r.position.y
	draw_string(font, Vector2(x, base_y + 31), d.title, HORIZONTAL_ALIGNMENT_LEFT, width - 58, 21, INK)
	_button("close_selection", Rect2(r.end.x - 60, base_y + 8, 48, 48), "×", false)
	var summary := "Lights on · Water on" if d.has_power and d.has_water else ("One service is off" if d.has_power or d.has_water else "Both services are off")
	draw_string(font, Vector2(x, base_y + 51), summary, HORIZONTAL_ALIGNMENT_LEFT, width, 12, MUTED)
	var button_y := base_y + 65.0
	var gap := 10.0
	var bw := (width - gap) / 2.0
	_button("power", Rect2(x, button_y, bw, 54), "POWER  " + ("ON" if d.has_power else "OFF"), d.has_power, not d.has_power)
	_button("water", Rect2(x + bw + gap, button_y, bw, 54), "WATER  " + ("ON" if d.has_water else "OFF"), d.has_water, not d.has_water)
	var issue_y := base_y + 141.0
	var patience := "People are patient" if d.unrest < 35.0 else ("Patience is wearing thin" if d.unrest < 70.0 else "People are getting angry")
	var issue_text := d.issue if d.issue != "" else patience
	var illegal_count := _district_illegal_count(d)
	var unpaid_count := _district_unpaid_count(d)
	var failed_poles := _district_failed_pole_count(d)
	if d.issue == "" and illegal_count > 0:
		issue_text = str(illegal_count) + " illegal connection(s) need checking"
	if d.issue == "" and unpaid_count > 0:
		issue_text = str(unpaid_count) + " house bill(s) are overdue"
	if d.issue == "" and failed_poles > 0:
		issue_text = str(failed_poles) + " power pole(s) have failed"
	draw_string(font, Vector2(x, issue_y), issue_text, HORIZONTAL_ALIGNMENT_LEFT, width, 12, RED if d.issue != "" or failed_poles > 0 or d.unrest >= 70 else MUTED)
	var more_y := base_y + 158.0
	if d.issue != "":
		var repair_label := "TEAM WORKING  " + _clock_string(d.repair_left) if d.repairing else ("TEAM READY IN  " + _clock_string(crew_cooldown) if crew_cooldown > 0.0 else "FIX " + d.issue.to_upper() + "  ·  $38–55")
		_button("repair", Rect2(x, more_y, width, 46), repair_label, true)
		more_y += 55.0
	_button("more", Rect2(x, more_y, width, 48), "MORE OPTIONS  " + ("−" if show_more_actions else "+"), false)
	if show_more_actions:
		var extra_y := more_y + 54.0
		var extra_w := (width - gap) / 2.0
		_button("inspect", Rect2(x, extra_y, extra_w, 48), "INSPECT  ·  $20", illegal_count > 0)
		_button("billing", Rect2(x + extra_w + gap, extra_y, extra_w, 48), "BILLING  ·  $12", unpaid_count > 0)
		_button("upgrade_crew", Rect2(x, extra_y + 54.0, width, 48), "UPGRADE CREW  ·  $240  (Lv" + str(crew_level) + ")", false)
		if treasury < 120.0 and not loan_used:
			_button("loan", Rect2(x, extra_y + 108.0, width, 48), "EMERGENCY LOAN  +$180", false, true)


func _draw_house_panel(r: Rect2, d: District, house: House) -> void:
	var x := r.position.x + 12.0
	var width := r.size.x - 24.0
	draw_string(font, Vector2(x, r.position.y + 29), d.title + " · " + house.label, HORIZONTAL_ALIGNMENT_LEFT, width - 58, 18, INK)
	_button("close_selection", Rect2(r.end.x - 60, r.position.y + 8, 48, 44), "×", false)
	var state := "UNPAID · " + str(house.arrears) + " shifts" if house.unpaid else ("ILLEGAL CONNECTION" if house.illegal_hookup else "ACCOUNT IN GOOD STANDING")
	draw_string(font, Vector2(x, r.position.y + 52), state, HORIZONTAL_ALIGNMENT_LEFT, width, 11, RED if house.unpaid else (AMBER if house.illegal_hookup else MUTED))
	var button_y := r.position.y + 67.0
	var gap := 8.0
	var bw := (width - gap) / 2.0
	_button("house_power", Rect2(x, button_y, bw, 48), "POWER  " + ("ON" if house.has_power else "CUT"), house.has_power, not house.has_power)
	_button("house_water", Rect2(x + bw + gap, button_y, bw, 48), "WATER  " + ("ON" if house.has_water else "OFF"), house.has_water, not house.has_water)
	var more_y := r.position.y + 128.0
	_button("more", Rect2(x, more_y, width, 44), "ACCOUNT OPTIONS  " + ("−" if show_more_actions else "+"), false)
	if show_more_actions:
		_button("house_bill", Rect2(x, more_y + 51, bw, 46), "COLLECT BILL", house.unpaid)
		_button("house_inspect", Rect2(x + bw + gap, more_y + 51, bw, 46), "INSPECT", house.illegal_hookup)
		_button("upgrade_crew", Rect2(x, more_y + 104, width, 46), "UPGRADE CREW · Lv" + str(crew_level) + " · $240", false)


func _draw_facility_panel(r: Rect2, facility: Facility) -> void:
	var x := r.position.x + 12.0
	var width := r.size.x - 24.0
	var type_label := "WATER PRODUCTION"
	if facility.kind == "power":
		var fuel_names := {"hydro": "HYDROELECTRIC", "hfo": "HEAVY FUEL OIL", "diesel": "DIESEL", "solar": "SOLAR"}
		type_label = str(fuel_names.get(facility.fuel_type, "POWER GENERATION"))
	draw_string(font, Vector2(x, r.position.y + 29), facility.title, HORIZONTAL_ALIGNMENT_LEFT, width - 58, 18, INK)
	_button("close_selection", Rect2(r.end.x - 60, r.position.y + 8, 48, 44), "×", false)
	draw_string(font, Vector2(x, r.position.y + 51), type_label + " · network share " + str(int(facility.capacity)), HORIZONTAL_ALIGNMENT_LEFT, width, 11, MUTED)
	var status := "REPAIRING · " + _clock_string(facility.repair_left) if facility.repairing else ("OFFLINE · " + facility.fault_name if facility.fault else "OPERATING")
	draw_string(font, Vector2(x, r.position.y + 75), status, HORIZONTAL_ALIGNMENT_LEFT, width, 12, RED if facility.fault else TEAL)
	if facility.fuel_type == "diesel":
		draw_string(font, Vector2(x, r.position.y + 96), "Shared diesel reserve · " + str(int(diesel_stock)) + " L", HORIZONTAL_ALIGNMENT_LEFT, width, 10, MUTED)
	var repair_label := "TEAM WORKING  " + _clock_string(facility.repair_left) if facility.repairing else ("TEAM READY IN  " + _clock_string(crew_cooldown) if crew_cooldown > 0.0 else "DISPATCH REPAIR · $65")
	_button("repair_facility", Rect2(x, r.position.y + 108, width, 48), repair_label, facility.fault, facility.fault and not facility.repairing)
	if show_more_actions:
		_button("upgrade_crew", Rect2(x, r.position.y + 218, width, 46), "UPGRADE CREW · Lv" + str(crew_level) + " · $240", false)
	_button("more", Rect2(x, r.position.y + 164, width, 46), "MORE OPTIONS  " + ("−" if show_more_actions else "+"), false)


func _draw_diesel_panel(size: Vector2) -> void:
	hitboxes.clear()
	draw_rect(Rect2(Vector2.ZERO, size), Color("#17302b", 0.62))
	var width := minf(size.x * 0.90, 560.0)
	var height := minf(size.y * 0.74, 560.0)
	var card := Rect2((size.x - width) * 0.5, (size.y - height) * 0.5, width, height)
	_draw_round_rect(card, PANEL, 28)
	var x := card.position.x + 22.0
	var content_width := card.size.x - 44.0
	draw_string(font, Vector2(x, card.position.y + 40), "DIESEL PLAN", HORIZONTAL_ALIGNMENT_LEFT, content_width - 58, 19, INK)
	_button("fuel_close", Rect2(card.end.x - 58, card.position.y + 10, 46, 46), "×", false)
	var truck_status := "Tanker on the road · " + _clock_string(diesel_truck_eta) + " · " + str(int(diesel_truck_liters)) + " L" if diesel_truck_in_transit else "No delivery currently on the road"
	draw_string(font, Vector2(x, card.position.y + 75), truck_status, HORIZONTAL_ALIGNMENT_LEFT, content_width, 11, AMBER if diesel_truck_in_transit else MUTED)
	draw_string(font, Vector2(x, card.position.y + 106), "RESERVE  " + str(int(diesel_stock)) + " / " + str(int(diesel_tank_capacity)) + " L", HORIZONTAL_ALIGNMENT_LEFT, content_width, 12, INK)
	_draw_meter(Rect2(x, card.position.y + 116, content_width, 8), diesel_stock / diesel_tank_capacity, AMBER, TEAL)
	var monthly_y := card.position.y + 158.0
	draw_string(font, Vector2(x, monthly_y), "MONTHLY PURCHASE TARGET", HORIZONTAL_ALIGNMENT_LEFT, content_width, 10, MUTED)
	var adjust_y := monthly_y + 12.0
	_button("fuel_month_down", Rect2(x, adjust_y, 54, 48), "− 500", false)
	draw_string(font, Vector2(x + 62, adjust_y + 29), str(diesel_monthly_plan) + " L / month", HORIZONTAL_ALIGNMENT_CENTER, content_width - 124, 16, INK)
	_button("fuel_month_up", Rect2(card.end.x - 76, adjust_y, 54, 48), "+ 500", false)
	var frequency_y := adjust_y + 72.0
	draw_string(font, Vector2(x, frequency_y), "DELIVERY FREQUENCY", HORIZONTAL_ALIGNMENT_LEFT, content_width, 10, MUTED)
	_button("fuel_frequency", Rect2(x, frequency_y + 12, content_width, 48), "Every " + str(diesel_frequency_days) + " days · " + str(int(_diesel_order_size())) + " L/load", false)
	var auto_y := frequency_y + 76.0
	_button("fuel_auto", Rect2(x, auto_y, content_width, 48), "AUTOMATIC ORDERS  ·  " + ("ON" if diesel_auto_purchase else "OFF"), diesel_auto_purchase)
	var order_label := "TANKER EN ROUTE" if diesel_truck_in_transit else "ORDER NEXT LOAD  ·  $" + str(int(_diesel_order_size() * 0.12))
	_button("fuel_order", Rect2(x, auto_y + 62, content_width, 52), order_label, false, diesel_truck_in_transit)
	draw_string(font, Vector2(x, card.end.y - 20), "In-game month = one shift · delivery takes 3 in-game days", HORIZONTAL_ALIGNMENT_CENTER, content_width, 10, MUTED)


func _draw_rain_popup(size: Vector2) -> void:
	hitboxes.clear()
	draw_rect(Rect2(Vector2.ZERO, size), Color("#17302b", 0.60))
	var width := minf(size.x * 0.86, 540.0)
	var card := Rect2((size.x - width) * 0.5, size.y * 0.34, width, 330.0)
	_draw_round_rect(card, PANEL, 28)
	draw_string(font, Vector2(card.position.x + 20, card.position.y + 42), "RAIN EVENT", HORIZONTAL_ALIGNMENT_CENTER, card.size.x - 40, 12, TEAL)
	draw_string(font, Vector2(card.position.x + 24, card.position.y + 96), "It’s raining.", HORIZONTAL_ALIGNMENT_CENTER, card.size.x - 48, 24, INK)
	draw_string(font, Vector2(card.position.x + 32, card.position.y + 132), "We should cut electricity everywhere… right?", HORIZONTAL_ALIGNMENT_CENTER, card.size.x - 64, 12, MUTED)
	_button("rain_cut_all", Rect2(card.position.x + 22, card.position.y + 172, card.size.x - 44, 58), "CUT POWER EVERYWHERE", false, true)
	_button("rain_ignore", Rect2(card.position.x + 22, card.position.y + 242, card.size.x - 44, 54), "IGNORE THE WEATHER", false)


func _draw_footer(size: Vector2) -> void:
	if _is_portrait(size):
		if notice_timer > 0.0 and notice != "":
			var toast := Rect2(14.0, _panel_rect(size).position.y - 43.0, size.x - 28.0, 34.0)
			_draw_round_rect(toast, Color("#fffdf7", 0.95), 17)
			var short_notice := notice.substr(0, 48)
			draw_string(font, Vector2(toast.position.x + 12, toast.position.y + 22), short_notice, HORIZONTAL_ALIGNMENT_LEFT, toast.size.x - 24, 11, INK)
		return
	var y := size.y - 76.0
	draw_rect(Rect2(0, y, size.x, 76), PANEL)
	draw_rect(Rect2(0, y, size.x, 1), Color("#dde5da"))
	var line := notice if notice_timer > 0.0 else "Every 8 seconds, functioning connections bring in tariffs. Repairs cost money. The city does not accept excuses."
	draw_string(font, Vector2(22, y + 27), line, HORIZONTAL_ALIGNMENT_LEFT, size.x - 44, 14, AMBER if notice_timer > 0.0 else MUTED)
	draw_string(font, Vector2(22, y + 51), "MAP: drag to pan · pinch / wheel to zoom · tap quartiers, homes, poles, and facilities.", HORIZONTAL_ALIGNMENT_LEFT, size.x - 44, 11, MUTED)


func _draw_meter(rect: Rect2, value: float, high: Color, low: Color) -> void:
	_draw_round_rect(rect, Color("#dce6dc"), rect.size.y * 0.5)
	var ratio := clampf(value, 0.0, 1.0)
	var color := low if ratio < 0.72 else high
	if ratio > 0.0:
		var fill_width := minf(rect.size.x, maxf(rect.size.y, rect.size.x * ratio))
		_draw_round_rect(Rect2(rect.position, Vector2(fill_width, rect.size.y)), color, rect.size.y * 0.5)


func _draw_game_over(size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#17302b", 0.56))
	var card := Rect2(size.x * 0.08, size.y * 0.30, size.x * 0.84, size.y * 0.40)
	_draw_round_rect(card, PANEL, 30)
	draw_string(font, Vector2(0, card.position.y + 56), "SHIFT REPORT", HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, TEAL)
	var headline := "SHIFT COMPLETE" if time_alive >= 180.0 else "SHIFT ENDED"
	draw_string(font, Vector2(0, card.position.y + 110), headline, HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, INK)
	draw_string(font, Vector2(card.position.x + 24, card.position.y + 154), reason.substr(0, 54), HORIZONTAL_ALIGNMENT_CENTER, card.size.x - 48, 13, MUTED)
	draw_string(font, Vector2(0, card.position.y + 207), "Time " + _clock_string(time_alive) + "     Best " + _clock_string(best_time), HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, INK)
	var button_rect := Rect2(card.position.x + 22, card.end.y - 76, card.size.x - 44, 56)
	_button("restart", button_rect, "BACK TO CITY", false)


func _clock_string(seconds: float) -> String:
	var total := int(seconds)
	return "%02d:%02d" % [total / 60, total % 60]
