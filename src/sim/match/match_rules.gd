class_name MatchRules
extends RefCounted
## When a match ends and who won (01_world "A match", US-17, US-18): on time by default
## (T-72); at the kill limit when the host turned it on (T-73); when one player is left in
## free-for-all or one team in team deathmatch. Winner: the most kills or the top team score,
## or a tie.

enum End { NONE, TIME, KILL_LIMIT, LAST_PLAYER, LAST_TEAM }

class Result:
	extends RefCounted
	var reason: End = End.NONE
	var tie: bool = false
	## Free-for-all: the winning player's id; 0 on a tie or in team play.
	var winner_id: int = 0
	## Team deathmatch: the winning team; 0 on a tie or in free-for-all.
	var winner_team: int = 0
	## Team scores by team, for team deathmatch.
	var team_scores: Dictionary = {}
	var best: Scoreboard.Row = null
	var rows: Array[Scoreboard.Row] = []
	## Match time when it ended, s.
	var time: float = 0.0


var config: MatchConfig
var scores: Scoreboard
var length: float = 0.0
var over: bool = false
var result: Result = null


func _init(match_config: MatchConfig, scoreboard: Scoreboard) -> void:
	config = match_config
	scores = scoreboard
	length = match_config.length


func time_left(now: float) -> float:
	return maxf(0.0, length - now)


## Checks the end after a tick at match time `now`. Returns true on the tick the match ends.
func check(now: float) -> bool:
	if over:
		return false
	var reason := End.NONE
	if config.is_teams():
		if scores.teams().size() < 2:
			reason = End.LAST_TEAM
		elif config.kill_limit_on and _top_team_score() >= config.kill_limit:
			reason = End.KILL_LIMIT
	else:
		if scores.order.size() < 2:
			reason = End.LAST_PLAYER
		elif config.kill_limit_on and scores.ranked()[0].kills >= config.kill_limit:
			reason = End.KILL_LIMIT
	if reason == End.NONE and now >= length - CombatSim.TIME_EPSILON:
		reason = End.TIME
	if reason == End.NONE:
		return false
	over = true
	result = _result(reason, now)
	return true


func _top_team_score() -> int:
	var best := 0
	for t in scores.teams():
		best = maxi(best, scores.team_score(t))
	return best


func _result(reason: End, now: float) -> Result:
	var r := Result.new()
	r.reason = reason
	r.time = minf(now, length)
	r.rows = scores.ranked()
	r.best = scores.best()
	if config.is_teams():
		var top := -1
		for t in scores.teams():
			var s := scores.team_score(t)
			r.team_scores[t] = s
			if s > top:
				top = s
				r.winner_team = t
				r.tie = false
			elif s == top:
				r.tie = true
		if r.tie:
			r.winner_team = 0
	else:
		if r.rows.size() >= 2 and r.rows[0].kills == r.rows[1].kills:
			r.tie = true
		elif not r.rows.is_empty():
			r.winner_id = r.rows[0].id
	return r
