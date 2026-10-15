class_name Scoreboard
extends RefCounted
## Per player: kills, deaths, suicides, team kills, damage dealt to enemies, current and best
## streak (US-20.1), kept from the match's combat events. Team scores are their players' kills
## (US-17.2). Kill credit follows `CombatSim`: a pop credits a kill, a suicide or a team kill.

class Row:
	extends RefCounted
	var id: int = 0
	var name: String = ""
	var team: int = Fighter.NO_TEAM
	var bot: bool = false
	var kills: int = 0
	var deaths: int = 0
	var suicides: int = 0
	var team_kills: int = 0
	var damage: float = 0.0
	var streak: int = 0
	var best_streak: int = 0

	func to_dict() -> Dictionary:
		return {"id": id, "name": name, "team": team, "bot": bot, "kills": kills, "deaths": deaths,
			"suicides": suicides, "team_kills": team_kills, "damage": damage, "streak": streak,
			"best_streak": best_streak}


var rows: Dictionary = {}
## Seat order, for a steady table.
var order: Array[int] = []


func add(id: int, player_name: String, team: int, bot: bool) -> Row:
	var r := Row.new()
	r.id = id
	r.name = player_name
	r.team = team
	r.bot = bot
	rows[id] = r
	order.append(id)
	return r


func row(id: int) -> Row:
	return rows.get(id, null)


func remove(id: int) -> void:
	rows.erase(id)
	order.erase(id)


## Feed every combat event here, in order.
func on_event(e: Dictionary) -> void:
	match e.type:
		&"hit":
			var by := row(int(e.attacker))
			var victim := row(int(e.toy))
			if by != null and victim != null and by != victim and not _mates(by, victim):
				by.damage += float(e.amount)
		&"pop":
			var victim := row(int(e.toy))
			if victim == null:
				return
			victim.deaths += 1
			victim.streak = 0
			var killer := row(int(e.killer))
			match e.credit:
				&"kill":
					if killer != null:
						killer.kills += 1
						killer.streak += 1
						killer.best_streak = maxi(killer.best_streak, killer.streak)
				&"team_kill":
					if killer != null:
						killer.team_kills += 1
						killer.suicides += 1
				_:
					victim.suicides += 1


func _mates(a: Row, b: Row) -> bool:
	return a.team != Fighter.NO_TEAM and a.team == b.team


func team_score(team: int) -> int:
	var n := 0
	for id: int in order:
		var r: Row = rows[id]
		if r.team == team:
			n += r.kills
	return n


## Teams with players in them, lowest first.
func teams() -> Array[int]:
	var out: Array[int] = []
	for id: int in order:
		var t: int = (rows[id] as Row).team
		if t != Fighter.NO_TEAM and not out.has(t):
			out.append(t)
	out.sort()
	return out


## Best first: most kills, then fewest deaths, then most damage, then seat order.
func ranked() -> Array[Row]:
	var out: Array[Row] = []
	for id: int in order:
		out.append(rows[id])
	var seat := func(r: Row) -> int: return order.find(r.id)
	out.sort_custom(func(a: Row, b: Row) -> bool:
		if a.kills != b.kills:
			return a.kills > b.kills
		if a.deaths != b.deaths:
			return a.deaths < b.deaths
		if a.damage != b.damage:
			return a.damage > b.damage
		return seat.call(a) < seat.call(b))
	return out


## US-20.3: the match's best player, the top of the ranking.
func best() -> Row:
	var r := ranked()
	return r[0] if not r.is_empty() else null
