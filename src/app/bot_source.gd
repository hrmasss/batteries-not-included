class_name BotSource
extends InputSource
## The local player's intent from a bot brain: autoplay for demos, recordings and soak runs.
## The toy still takes a plain intent, as from a thumb.

var bot: Bot = null


func intent_for(_view: GameView, _tick: int) -> InputIntent:
	return bot.intent(SimClock.TICK) if bot != null else InputIntent.idle()
