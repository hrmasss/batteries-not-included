class_name TeamLook
extends RefCounted
## How a team shows on a toy (US-26.1, US-26.2): the batteries and wires in the team colour
## with a pattern per team (plain, stripes, dots, chevrons), and a thin outline in the team
## colour around the whole toy (`TeamOutline`). Free-for-all toys keep the copper-top battery
## (art lab default, accepted 2026-10-15).
##
## Teams here are the combat sim's: 0 is no team, 1 and up are teams. Colours come from
## `TeamPalette` (palette team = combat team - 1, as the HUD maps them), so the toy, its name
## tag and the HUD agree, and the colour-vision palette (US-42.4) reaches the batteries too.

const BAKED_FFA := "neutral"


static func index(team: int) -> int:
	return -1 if team <= Fighter.NO_TEAM else team - 1


static func battery_color(team: int) -> Color:
	var i := index(team)
	return Color.WHITE if i < 0 else TeamPalette.battery_color(i)


static func outline_color(team: int) -> Color:
	return TeamPalette.outline_color(index(team))


## The overlay drawn over the tinted greyscale layer: a pattern piece, "" for plain, or
## "baked" when the toy uses a baked layer instead (free-for-all).
static func pattern_piece(team: int) -> StringName:
	var i := index(team)
	if i < 0:
		return &"baked"
	var kind := ArtLibrary.TEAM_PATTERNS[i % ArtLibrary.TEAM_PATTERNS.size()]
	return &"" if kind == "" else StringName(ArtLibrary.SOLDIER + "jetpack_pattern_" + kind)


## The baked free-for-all layer (copper top).
static func baked_piece(_team: int = Fighter.NO_TEAM) -> StringName:
	return StringName(ArtLibrary.SOLDIER + "jetpack_team_" + BAKED_FFA)
