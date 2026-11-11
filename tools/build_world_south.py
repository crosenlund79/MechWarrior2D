#!/usr/bin/env python3
"""Adds the Southern Junkers iteration content to data/locations/desert_basin_01.json
(idempotent: removes its own previous entries first, tagged with "_wave": "south").
Also validates geometry: roads, salvage, enemies, turrets and teleports must not be
inside rock masses or prop footprints. Run: python3 tools/build_world_south.py"""
import json, math, os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = os.path.join(ROOT, "data/locations/desert_basin_01.json")
d = json.load(open(P))
TAG = "south"


def strip(lst):
    return [x for x in lst if x.get("_wave") != TAG]


for key in ("props", "patches", "zones", "salvage", "enemies", "turrets", "areas"):
    d[key] = strip(d.get(key, []))
for key in ("masses", "walls", "cables", "covers"):
    d["terrain"][key] = strip(d["terrain"].get(key, []))
d["bounds"] = [-2600, 0, 9400, 6200]
zt = d["zone_types"]
zt["ravine"] = {"ambient": 52.0, "solar": 0.5, "abrasion": 0.5, "drag": 1.0, "suit": 0.65, "cooling": 1.05, "storm_exposure": 0.45, "label": "ZONE_RAVINE"}
zt["junker"] = {"ambient": 60.0, "solar": 1.05, "abrasion": 1.0, "drag": 1.0, "suit": 1.05, "storm_exposure": 0.95, "label": "ZONE_JUNKER"}
zt["shade"]["storm_exposure"] = 0.6


def tag(x):
    x["_wave"] = TAG
    return x


def prop(id_, asset, pos, layer="low", rot=0, **kw):
    p = {"id": id_, "asset": asset, "pos": list(pos), "layer": layer}
    if rot:
        p["rot"] = rot
    p.update(kw)
    d["props"].append(tag(p))


def offset_line(pts, dist):
    out = []
    for i, (x, y) in enumerate(pts):
        a = pts[max(0, i - 1)]; b = pts[min(len(pts) - 1, i + 1)]
        tx, ty = b[0] - a[0], b[1] - a[1]
        L = math.hypot(tx, ty) or 1
        nx, ny = -ty / L, tx / L
        out.append([round(x + nx * dist), round(y + ny * dist)])
    return out


# ------------------------------------------------------------------ roads
d["patches"] += [tag(x) for x in [
    {"id": "track_east", "tile": "ground.track", "width": 92, "path": [[2480, 1100], [2700, 1290], [3100, 1420], [3550, 1350], [4000, 1250], [4500, 1300]]},
    {"id": "track_shelter_south", "tile": "ground.track", "width": 88, "path": [[760, 1470], [830, 2000], [770, 2600], [660, 3100], [620, 3300]]},
    {"id": "road_highway", "tile": "ground.asphalt", "width": 150,
     "path": [[-2450, 3400], [-1600, 3380], [-400, 3350], [600, 3290], [1500, 3260], [2400, 3300], [2900, 3520], [3300, 3800], [3800, 4000], [4300, 3990], [4700, 4060], [5050, 4280], [5180, 4500]]},
    {"id": "track_ravine", "tile": "ground.track", "width": 96, "path": [[2620, 2300], [3150, 2600], [3420, 2880], [3650, 3120], [3880, 3340], [4020, 3580], [4120, 3880]]},
    {"id": "track_scrapfield", "tile": "ground.track", "width": 84, "path": [[1600, 3270], [1750, 3600], [1900, 3900], [2050, 4250]]},
]]

# ------------------------------------------------------------------ ravine
center = [[3150, 2600], [3420, 2880], [3650, 3120], [3880, 3340], [4020, 3580]]
west_in = offset_line(center, 205)
west_out = offset_line(center, 400)
east_in = offset_line(center, -205)
east_out = offset_line(center, -520)
west_poly = west_in + list(reversed(west_out))
east_poly = east_in + list(reversed(east_out))
# pull the ends back so the ravine mouths flare open
west_poly[0][1] += 60; east_poly[0][0] += 60
d["terrain"]["masses"] += [
    tag({"id": "ravine_west", "tile": "ground.rock_top", "height": 60, "rough": 34, "seed": 21, "polygon": west_poly}),
    tag({"id": "ravine_east", "tile": "ground.rock_top", "height": 60, "rough": 34, "seed": 22, "polygon": east_poly}),
]
corridor = offset_line(center, 200) + list(reversed(offset_line(center, -200)))
d["zones"].append(tag({"id": "ravine_passage", "type": "ravine", "polygon": corridor}))

# ------------------------------------------------------------------ cooling station (east)
for args in [
    ("cs_tower_1", "cs.cooling_tower", (4760, 880), "low", 0, {"collision": {"circle": 150}}),
    ("cs_tower_2", "cs.cooling_tower", (5320, 820), "low", 30, {"collision": {"circle": 150}}),
    ("cs_rack", "cs.pipe_rack", (5040, 860), "low", 0, {"collision": {"rect": [260, 40]}}),
    ("cs_tank_1", "cs.tank", (5560, 1240), "low", 0, {"collision": {"circle": 70}}),
    ("cs_tank_2", "cs.tank", (5420, 1450), "low", 40, {"collision": {"circle": 70}}),
    ("cs_tank_3", "cs.tank", (4560, 1520), "low", 0, {"collision": {"circle": 70}}),
    ("cs_bank_1", "cs.radiator_bank", (5050, 1230), "low", 0, {"collision": {"rect": [260, 100]}}),
    ("cs_bank_2", "cs.radiator_bank", (5120, 1500), "low", 14, {"collision": {"rect": [260, 100]}}),
    ("cs_shed", "cs.control_shed", (4700, 1230), "low", -6, {"collision": {"rect": [200, 150]}}),
    ("cs_pipe_1", "prop.pipe", (5300, 1080), "low", 70, {"collision": {"rect": [200, 40]}}),
    ("cs_scrap_1", "prop.scrap_pile", (4900, 1660), "low", 40, {"collision": {"circle": 40}}),
]:
    prop(args[0], args[1], args[2], args[3], args[4], **args[5])
d["salvage"] += [tag(x) for x in [
    {"id": "salvage_cooling_core", "pos": [5050, 1350], "item": "radiator_core", "count": 1, "label": "SALVAGE_COOLING_STATION"},
    {"id": "salvage_cooling_scrap", "pos": [4840, 1540], "item": "scrap", "count": 3, "label": "SALVAGE_COOLING_STATION"},
]]

# ------------------------------------------------------------------ roadside installation (old highway)
for args in [
    ("rr_lot", "road.lot", (620, 3520), "floor", 0, {}),
    ("rr_kiosk", "road.kiosk", (770, 3600), "low", 0, {"collision": {"rect": [230, 150]}}),
    ("rr_pump_1", "road.pump", (470, 3500), "low", 0, {"collision": {"circle": 16}}),
    ("rr_pump_2", "road.pump", (610, 3500), "low", 0, {"collision": {"circle": 16}}),
    ("rr_canopy", "road.canopy", (540, 3500), "overhead", 0, {"occlude": True}),
    ("rr_car_1", "road.car", (330, 3650), "low", 22, {"collision": {"rect": [170, 86]}}),
    ("rr_car_2", "road.car", (1150, 3300), "low", 95, {"collision": {"rect": [170, 86]}}),
    ("rr_car_3", "road.car", (1420, 3230), "low", 82, {"collision": {"rect": [170, 86]}}),
    ("rr_billboard", "road.billboard", (960, 3760), "low", -12, {"collision": {"rect": [290, 40]}}),
    ("rr_sign_1", "road.sign", (230, 3190), "low", 0, {"collision": {"circle": 12}}),
    ("rr_sign_2", "road.sign", (2300, 3180), "low", 180, {"collision": {"circle": 12}}),
    ("rr_sign_3", "road.sign", (4150, 3700), "low", 200, {"collision": {"circle": 12}}),
    ("rr_pylon", "prop.pylon", (1900, 3120), "low", 8, {"collision": {"rect": [180, 40]}}),
]:
    prop(args[0], args[1], args[2], args[3], args[4], **args[5])
d["zones"].append(tag({"id": "rr_canopy_shade", "type": "shade", "polygon": [[352, 3392], [770, 3392], [770, 3640], [352, 3640]]}))
d["salvage"].append(tag({"id": "salvage_roadside", "pos": [900, 3560], "item": "scrap", "count": 2, "label": "SALVAGE_ROADSIDE"}))

# ------------------------------------------------------------------ scrap field
sf = [("sf_hauler", "wreck.hauler", (2250, 3850), "low", -30, {"collision": {"rect": [260, 150]}}),
      ("sf_wreck_1", "enemy.wreck", (1650, 4100), "low", 40, {"collision": {"circle": 70}}),
      ("sf_wreck_2", "enemy.junker_wreck", (2450, 4300), "low", 160, {"collision": {"circle": 70}}),
      ("sf_engine_1", "prop.engine_block", (1500, 3800), "low", 20, {"collision": {"rect": [80, 70]}}),
      ("sf_engine_2", "prop.engine_block", (2050, 4500), "low", 110, {"collision": {"rect": [80, 70]}}),
      ("sf_tires_1", "prop.tire_stack", (1820, 4380), "low", 0, {"collision": {"circle": 32}}),
      ("sf_tires_2", "prop.tire_stack", (2600, 3950), "low", 0, {"collision": {"circle": 32}}),
      ("sf_pile_1", "prop.scrap_pile", (1400, 4250), "low", 70, {"collision": {"circle": 40}}),
      ("sf_pile_2", "prop.scrap_pile", (2300, 4600), "low", 200, {"collision": {"circle": 40}}),
      ("sf_pile_3", "prop.scrap_pile", (2700, 4250), "low", 10, {"collision": {"circle": 40}}),
      ("sf_pipe", "prop.pipe", (1650, 4600), "low", -35, {"collision": {"rect": [200, 40]}}),
      ("sf_solar", "prop.solar_wreck", (2550, 3650), "low", 25, {"collision": {"rect": [140, 80]}})]
for a in sf:
    prop(a[0], a[1], a[2], a[3], a[4], **a[5])
d["salvage"] += [tag(x) for x in [
    {"id": "salvage_sf_1", "pos": [1720, 3880], "item": "scrap", "count": 3, "label": "SALVAGE_SCRAP_FIELD"},
    {"id": "salvage_sf_2", "pos": [2180, 4060], "item": "scrap", "count": 3, "label": "SALVAGE_SCRAP_FIELD"},
    {"id": "salvage_sf_core", "pos": [1960, 4260], "item": "radiator_core", "count": 1, "label": "SALVAGE_SCRAP_FIELD"},
]]

# ------------------------------------------------------------------ Southern Junkers territory + main base
d["terrain"]["masses"] += [tag(x) for x in [
    {"id": "junker_ridge_east", "tile": "ground.rock_top", "height": 70, "rough": 40, "seed": 31,
     "polygon": [[6250, 3800], [6900, 3600], [6900, 6400], [6050, 6400], [6300, 5900], [6400, 5350], [6300, 4500]]},
    {"id": "junker_ridge_south", "tile": "ground.rock_top", "height": 70, "rough": 40, "seed": 32,
     "polygon": [[3500, 6400], [3900, 6100], [4500, 6060], [5100, 6120], [5700, 6040], [6100, 6400]]},
    {"id": "junker_ridge_west", "tile": "ground.rock_top", "height": 70, "rough": 36, "seed": 33,
     "polygon": [[3500, 4900], [3850, 4780], [4080, 5150], [3980, 5650], [3700, 6000], [3500, 6100]]},
]]
d["patches"].append(tag({"id": "junker_yard", "tile": "ground.junker_dirt",
    "polygon": [[4350, 4380], [5000, 4300], [5450, 4330], [6000, 4450], [6080, 5300], [5900, 5900], [5200, 6000], [4500, 5900], [4250, 5400], [4260, 4800]]}))
wall = {"id": "junker_walls", "tile": "junker.wall_strip", "width": 30, "segments": [
    [[4500, 4520], [4960, 4440]],          # north-west of the gate
    [[5410, 4440], [5860, 4540]],          # north-east of the gate
    [[5860, 4540], [5960, 4900]], [[5960, 4900], [5940, 5260]],      # east (breach 5260→5560)
    [[5910, 5560], [5760, 5820]], [[5760, 5820], [5200, 5900]], [[5200, 5900], [4660, 5820]],
    [[4660, 5820], [4460, 5470]],          # west (breach 5470→5060)
    [[4410, 5060], [4500, 4520]]]}
d["terrain"]["walls"].append(tag(wall))
for args in [
    ("jk_workshop", "junker.workshop", (5200, 5150), "low", 0, {"collision": {"rect": [520, 350]}}),
    ("jk_shed_1", "junker.shed", (4600, 4690), "low", 6, {"collision": {"rect": [190, 150]}}),
    ("jk_shed_2", "junker.shed_b", (5480, 4600), "low", -4, {"collision": {"rect": [190, 150]}}),
    ("jk_shed_3", "junker.shed_b", (4790, 5560), "low", 12, {"collision": {"rect": [190, 150]}}),
    ("jk_shed_4", "junker.shed", (5640, 5560), "low", -10, {"collision": {"rect": [190, 150]}}),
    ("jk_stack_1", "junker.scrap_stack", (4590, 5660), "low", 30, {"collision": {"rect": [140, 110]}}),
    ("jk_stack_2", "junker.scrap_stack", (5470, 5720), "low", 10, {"collision": {"rect": [140, 110]}}),
    ("jk_dead_mech_1", "enemy.junker_wreck", (5790, 5650), "low", 40, {"collision": {"circle": 70}}),
    ("jk_dead_mech_2", "enemy.wreck", (4180, 4620), "low", -20, {"collision": {"circle": 70}}),
    ("jk_cooler", "junker.cooler", (5600, 5150), "low", 90, {"collision": {"rect": [150, 110]}}),
    ("jk_generator", "junker.generator", (4560, 4920), "low", 90, {"collision": {"rect": [140, 96]}, "anim": "junker_machine"}),
    ("jk_tarp_1", "junker.tarp", (5420, 5660), "overhead", 4, {"occlude": True}),
    ("jk_tarp_2", "junker.tarp", (5000, 5640), "overhead", -6, {"occlude": True}),
    ("jk_barrel_1", "junker.burn_barrel", (4850, 4640), "low", 0, {"collision": {"circle": 18}, "anim": "fire_barrel"}),
    ("jk_barrel_2", "junker.burn_barrel", (5560, 5000), "low", 0, {"collision": {"circle": 18}, "anim": "fire_barrel"}),
    ("jk_barrel_3", "junker.burn_barrel", (5220, 5600), "low", 0, {"collision": {"circle": 18}, "anim": "fire_barrel"}),
    ("jk_insignia_gate", "junker.insignia", (5180, 4300), "floor", 0, {}),
    ("jk_insignia_yard", "junker.insignia", (5200, 4870), "floor", 15, {}),
    ("jk_light_1", "junker.lamp", (4990, 4530), "low", 0, {"collision": {"circle": 12}, "light": True, "light_color": [1.0, 0.62, 0.3], "light_energy": 0.38, "light_scale": 1.8}),
    ("jk_light_2", "junker.lamp", (5380, 4540), "low", 0, {"collision": {"circle": 12}, "light": True, "light_color": [1.0, 0.62, 0.3], "light_energy": 0.38, "light_scale": 1.8}),
    ("jk_light_3", "junker.lamp", (4500, 5060), "low", 0, {"collision": {"circle": 12}, "light": True, "light_color": [1.0, 0.62, 0.3], "light_energy": 0.38, "light_scale": 1.8}),
    ("jk_light_4", "junker.lamp", (5560, 4990), "low", 0, {"collision": {"circle": 12}, "light": True, "light_color": [1.0, 0.62, 0.3], "light_energy": 0.38, "light_scale": 1.8}),
    ("jk_light_5", "junker.lamp", (5200, 5760), "low", 0, {"collision": {"circle": 12}, "light": True, "light_color": [1.0, 0.62, 0.3], "light_energy": 0.38, "light_scale": 1.8}),
    ("jk_clank", "junker.lamp", (5000, 5320), "low", 0, {"collision": {"circle": 12}, "light": True, "light_color": [1.0, 0.62, 0.3], "light_energy": 0.38, "light_scale": 1.8, "anim": "clank"}),
]:
    prop(args[0], args[1], args[2], args[3], args[4], **args[5])
d["zones"] += [tag(x) for x in [
    {"id": "jk_tarp_1_shade", "type": "shade", "polygon": [[5290, 5570], [5590, 5570], [5590, 5790], [5290, 5790]]},
    {"id": "jk_tarp_2_shade", "type": "shade", "polygon": [[4870, 5550], [5170, 5550], [5170, 5770], [4870, 5770]]},
    {"id": "junker_territory", "type": "junker", "polygon": [[3700, 3900], [6900, 3700], [6900, 6300], [3600, 6300]]},
]]
d["terrain"]["cables"] += [tag(x) for x in [
    {"from": [4560, 4970], "to": [4500, 5060], "sag": [10, 20]}, {"from": [4570, 4860], "to": [4990, 4530], "sag": [-40, 30]},
    {"from": [4590, 4980], "to": [5000, 5320], "sag": [30, 0]}, {"from": [4990, 4530], "to": [5380, 4540], "sag": [0, 40]},
    {"from": [5380, 4540], "to": [5560, 4990], "sag": [40, -10]}, {"from": [4580, 4985], "to": [5200, 5760], "sag": [-60, 40]}]]
d["turrets"] = [tag(x) for x in [
    {"id": "jk_turret_gate_w", "pos": [4870, 4380], "facing_deg": -10},
    {"id": "jk_turret_gate_e", "pos": [5500, 4400], "facing_deg": 15},
    {"id": "jk_turret_west", "pos": [4290, 4930], "facing_deg": 260},
    {"id": "jk_turret_east", "pos": [6020, 5080], "facing_deg": 90},
    {"id": "jk_turret_south", "pos": [5200, 5990], "facing_deg": 180}]]
d["enemies"] += [tag(x) for x in [
    {"id": "junker_yard_guard", "type": "junker", "spawn": [4950, 4650], "heading_deg": 90,
     "patrol": [[4950, 4700], [5300, 4760], [5750, 4950], [5750, 5450], [5100, 5450], [4740, 5150], [4820, 4760]]},
    {"id": "junker_gate_guard", "type": "junker", "spawn": [5000, 4100], "heading_deg": 90,
     "patrol": [[4950, 4120], [5420, 4120], [5420, 3920], [4950, 3920]]},
    {"id": "junker_parked", "type": "junker", "spawn": [5730, 4820], "heading_deg": 210, "parked": True, "pilot_spawn": [5820, 4750],
     "patrol": [[5730, 4820], [5650, 5000], [5420, 4820]]}]]
d["areas"] = [tag(x) for x in [
    {"id": "area_refuge", "name": "AREA_REFUGE", "polygon": [[-2000, 300], [-1100, 300], [-1100, 1350], [-2000, 1350]]},
    {"id": "area_cooling", "name": "AREA_COOLING_STATION", "polygon": [[4300, 500], [5900, 500], [5900, 1800], [4300, 1800]]},
    {"id": "area_ravine", "name": "AREA_RAVINE", "polygon": corridor},
    {"id": "area_roadside", "name": "AREA_ROADSIDE", "polygon": [[150, 3150], [1100, 3150], [1100, 3800], [150, 3800]]},
    {"id": "area_scrapfield", "name": "AREA_SCRAP_FIELD", "polygon": [[1300, 3650], [2800, 3650], [2800, 4700], [1300, 4700]]},
    {"id": "area_junkers", "name": "AREA_JUNKER_TERRITORY", "polygon": [[3700, 3900], [6900, 3700], [6900, 6300], [3600, 6300]]},
    {"id": "area_junker_base", "name": "AREA_JUNKER_BASE", "polygon": [[4300, 4350], [6000, 4350], [6000, 5950], [4300, 5950]]}]]
d["teleports"] = {"refuge": {"pos": [-1440, 930], "heading_deg": 0}, "junker_base": {"pos": [5180, 3860], "heading_deg": 180},
                  "cooling_station": {"pos": [4400, 1260], "heading_deg": 90}, "scrap_field": {"pos": [1900, 3640], "heading_deg": 180},
                  "roadside": {"pos": [620, 3220], "heading_deg": 90}, "ravine": {"pos": [3150, 2560], "heading_deg": 135}}
# ---- Thawborn: car start in the refuge garage, tyre grip per zone, creature territories, hunt areas
d["mech_start"] = {"pos": [-1440, 930], "heading_deg": 180, "_note": "the player's car starts parked in the canyon refuge garage bay"}
d["garage"] = {"pos": [-1440, 930], "radius": 300.0, "_note": "refuge garage bay (car must be stopped here)"}
GRIP = {"shade": 1.0, "dunes": 0.7, "salt": 1.0, "canyon": 1.0, "refuge": 1.05, "ravine": 1.0, "junker": 0.95}
for k, v in d["zone_types"].items():
    v["grip"] = GRIP.get(k, 1.0)
d["default_zone"]["grip"] = 0.92
d["creatures"] = [
    {"id": "skirr_n1", "species": "skirr", "pack": "north", "spawn": [3250, 560]},
    {"id": "skirr_n2", "species": "skirr", "pack": "north", "spawn": [3350, 640]},
    {"id": "skirr_n3", "species": "skirr", "pack": "north", "spawn": [3200, 700]},
    {"id": "skirr_n4", "species": "skirr", "pack": "north", "spawn": [3400, 520]},
    {"id": "skirr_f1", "species": "skirr", "pack": "flats", "spawn": [-2150, 4000]},
    {"id": "skirr_f2", "species": "skirr", "pack": "flats", "spawn": [-2080, 3950]},
    {"id": "skirr_f3", "species": "skirr", "pack": "flats", "spawn": [-2220, 3940]},
    {"id": "grindback_dunes", "species": "grindback", "spawn": [1640, 1950]},
    {"id": "grindback_flats", "species": "grindback", "spawn": [-1100, 3900]},
    {"id": "rimeback", "species": "rimeback", "spawn": [-200, 5000], "heading_deg": 90}]
d["rimeback_route"] = [[-200, 5000], [600, 5420], [1100, 4950], [820, 4300], [-300, 4120], [-1100, 4500], [-1500, 5150], [-900, 5700]]
d["rimeback_lair"] = [-2000, 5650]
d["areas"] += [tag(x) for x in [
    {"id": "area_thaw_flats", "name": "AREA_THAW_FLATS", "polygon": [[-2500, 3850], [1250, 3850], [1250, 6150], [-2500, 6150]]},
    {"id": "area_dune_sea", "name": "AREA_DUNE_SEA", "polygon": [[1360, 1300], [1900, 1300], [1900, 2600], [1360, 2600]]},
    {"id": "area_skirr_den", "name": "AREA_SKIRR_DEN", "polygon": [[2700, 150], [3900, 150], [3900, 1000], [2700, 1000]]}]]
d["teleports"].update({"thaw_flats": {"pos": [-300, 4300], "heading_deg": 180}, "dune_sea": {"pos": [1150, 1900], "heading_deg": 90},
                       "skirr_den": {"pos": [2700, 800], "heading_deg": 90}})
# Scatter: wider, sparser (avoid the new locations)
d["scatter"] = [s for s in d["scatter"] if s.get("seed") != 41]
d["scatter"].append(tag({"seed": 41, "count": 150, "area": [-300, 2600, 7000, 3500], "spacing": 90,
                         "assets": ["prop.rock_small_a", "prop.rock_small_b", "prop.stones", "prop.stones", "prop.rock_small_a"]}))
d["scatter"].append(tag({"seed": 42, "count": 60, "area": [3600, 0, 3200, 2600], "spacing": 90,
                         "assets": ["prop.rock_small_a", "prop.stones", "prop.rock_small_b"]}))
for big in [(3900, 600, 0), (4200, 2300, 80), (6200, 1900, 200), (2900, 3000, 40), (1000, 4700, 300), (3300, 4600, 120), (6400, 3000, 30), (-800, 4200, 160), (200, 5400, 60), (2600, 5500, 250), (-1700, 5000, 15)]:
    prop(f"rock_s_{big[0]}_{big[1]}", "prop.rock_large_a" if big[2] % 2 == 0 else "prop.rock_large_b", (big[0], big[1]), "low", big[2], collision={"circle": 50})
d["scatter_avoid"] = [a for a in d["scatter_avoid"] if len(a) == 4 and not (a[0] >= 3500 and a[1] >= 2500)]
d["scatter_avoid"] += [[4300, 500, 1600, 1300], [150, 3150, 1000, 700], [1300, 3650, 1500, 1050], [4250, 4250, 1900, 1800], [-2500, 3250, 7300, 250]]

json.dump(d, open(P, "w"), indent="\t", ensure_ascii=False)

# ------------------------------------------------------------------ validation (point-in-polygon against roughly the rock outlines)
def inside(pt, poly):
    x, y = pt; c = False
    for i in range(len(poly)):
        x1, y1 = poly[i]; x2, y2 = poly[(i + 1) % len(poly)]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1 + 1e-9) + x1:
            c = not c
    return c


def dist_seg(p, a, b):
    ax, ay = a; bx, by = b; px, py = p
    dx, dy = bx - ax, by - ay
    t = max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy + 1e-9)))
    return math.hypot(ax + dx * t - px, ay + dy * t - py)


masses = d["terrain"]["masses"]
errs = []
def near_mass(pt, margin):
    for m in masses:
        poly = m["polygon"]
        if inside(pt, poly):
            return m["id"]
        if min(dist_seg(pt, poly[i], poly[(i + 1) % len(poly)]) for i in range(len(poly))) < margin:
            return m["id"] + " (edge)"
    return ""
for p in d["patches"]:
    if "path" in p:
        for i in range(len(p["path"]) - 1):
            a, b = p["path"][i], p["path"][i + 1]
            for k in range(11):
                t = k / 10
                pt = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
                hit = near_mass(pt, 130 if p.get("_wave") == TAG else 0)
                if hit:
                    errs.append(f"road {p['id']} at {tuple(round(v) for v in pt)} → {hit}")
for s in d["salvage"]:
    if near_mass(s["pos"], 60):
        errs.append(f"salvage {s['id']} in rock")
for e in d["enemies"]:
    if near_mass(e["spawn"], 120):
        errs.append(f"enemy {e['id']} in rock")
    for wp in e.get("patrol", []):
        if near_mass(wp, 110):
            errs.append(f"enemy {e['id']} patrol {wp} in rock")
for t in d["turrets"]:
    if near_mass(t["pos"], 30):
        errs.append(f"turret {t['id']} in rock")
for k, v in d["teleports"].items():
    if near_mass(v["pos"], 130):
        errs.append(f"teleport {k} in rock")
# creatures and the rimeback route must be clear of rock and big props
for c in d["creatures"]:
    if near_mass(c["spawn"], 120):
        errs.append(f"creature {c['id']} in rock")
for wp in d["rimeback_route"] + [d["rimeback_lair"]]:
    if near_mass(wp, 170):
        errs.append(f"rimeback route {wp} in rock")
    for pr in d["props"]:
        if "collision" in pr and math.hypot(pr["pos"][0] - wp[0], pr["pos"][1] - wp[1]) < 190:
            errs.append(f"rimeback route {wp} blocked by {pr['id']}")
# props with collision must not cover roads
for pr in d["props"]:
    if "collision" not in pr:
        continue
    r = pr["collision"].get("circle") or max(pr["collision"].get("rect", [0, 0])) / 2
    for p in d["patches"]:
        if "path" not in p or p.get("_wave") != TAG or (p["id"] == "road_highway" and pr["id"].startswith("rr_car")):
            continue
        for i in range(len(p["path"]) - 1):
            if dist_seg(pr["pos"], p["path"][i], p["path"][i + 1]) < r + p.get("width", 90) / 2 - 10 and not pr["id"].startswith(("jk_", "rr_sign")):
                errs.append(f"prop {pr['id']} blocks {p['id']}")
print("\n".join(errs) if errs else "geometry OK")
sys.exit(1 if errs else 0)
