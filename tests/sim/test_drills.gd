extends SimTest
## US-37.6 groundwork: the measuring drills, logged for the tuner. Values come out in the test log.


func test_drills_report() -> void:
	make()
	var flight := Drills.full_up_flight(sim, toy)
	var refill := Drills.refill_time(sim, toy)
	make()
	var walk := Drills.top_walk_speed(sim, toy)
	make()
	var stop := Drills.stop_time(sim, toy)
	make()
	var jump := Drills.jump_height(sim, toy)
	gut.p("DRILL full-up flight      %.3f s" % flight)
	gut.p("DRILL refill from empty   %.3f s" % refill)
	gut.p("DRILL top walk speed      %.1f u/s" % walk)
	gut.p("DRILL stop from full walk %.3f s" % stop)
	gut.p("DRILL jump height (feet)  %.1f u" % jump)
	assert_almost_eq(flight, 4.8, 0.1)
	assert_almost_eq(refill, 11.0, 0.1)
	assert_gt(jump, 20.0)
