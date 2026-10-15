class_name WeaponView
extends RefCounted
## What the camera needs from the held weapon: its allowed zoom levels (T-50 "Zoom") and its
## look-ahead factor (T-81 "weapon factor").
##
## Stand-in until the combat task's weapon rows land: then `for_weapon` reads the row's `zoom`
## and `look_ahead` values instead of this table. Values are the launch weapons' T-50 zoom
## column and the classic's per-gun look-ahead (controls-hud-camera.md).

const TABLE := {
	&"": {"zoom": [1], "look_ahead": -1.0},
	&"pistol": {"zoom": [1, 2], "look_ahead": 0.25},
	&"uzi": {"zoom": [1, 3], "look_ahead": 0.375},
	&"smg": {"zoom": [1, 3], "look_ahead": 0.4},
	&"assault_rifle": {"zoom": [1, 2, 4], "look_ahead": 0.45},
	&"pump_shotgun": {"zoom": [1, 2], "look_ahead": 0.45},
	&"sniper_rifle": {"zoom": [1, 3, 5, 7], "look_ahead": 0.7},
	&"rocket_launcher": {"zoom": [1, 4, 6], "look_ahead": 0.65},
}

var key: StringName = &""
var zoom_levels: PackedInt32Array = [1]
## Negative means bare hands (the ruleset's bare factor).
var look_ahead: float = -1.0


static func for_weapon(weapon_key: StringName) -> WeaponView:
	var v := WeaponView.new()
	var row: Dictionary = TABLE.get(weapon_key, TABLE[&""])
	v.key = weapon_key
	v.zoom_levels = PackedInt32Array(row.zoom)
	v.look_ahead = row.look_ahead
	return v
