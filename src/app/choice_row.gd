class_name ChoiceRow
extends HBoxContainer
## One setting as a row: its name, then ‹ value › to step through the choices. Big targets for
## thumbs; arrow keys and a pad work through focus.

signal changed(value: Variant)

var values: Array = []
var texts: PackedStringArray = []
var index: int = 0

var _value: Label
var _title: String


func _init(title: String, choice_values: Array, choice_texts: PackedStringArray, current: Variant, label_width: float = 96.0, value_width: float = 104.0) -> void:
	_title = title
	name = title.replace(" ", "")
	values = choice_values
	texts = choice_texts
	index = maxi(0, values.find(current))
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 4)
	var l := Ui.label(title, Ui.FONT_SMALL, Ui.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	l.custom_minimum_size = Vector2(label_width, 0)
	add_child(l)
	add_child(_arrow("‹", -1))
	_value = Ui.label("", Ui.FONT_SMALL, Ui.TEXT)
	_value.custom_minimum_size = Vector2(value_width, 0)
	add_child(_value)
	add_child(_arrow("›", 1))
	_show()


func value() -> Variant:
	return values[index]


func step(by: int) -> void:
	index = posmod(index + by, values.size())
	_show()
	changed.emit(values[index])


func _arrow(text: String, by: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(Ui.BUTTON_HEIGHT, Ui.BUTTON_HEIGHT * 0.8)
	b.pressed.connect(step.bind(by))
	return b


func _show() -> void:
	_value.text = texts[index]
