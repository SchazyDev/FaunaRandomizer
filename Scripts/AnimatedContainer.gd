class_name AnimatedContainer
extends BoxContainer

@export_range(0.0, 1.0, 0.01) var time_to_show: float = 0.5

var tween: Tween
var nodes: Array[Node]

var delay_between: float = 0.5


func _ready() -> void:
	hide()

	nodes = get_children().filter(
		func(a) -> bool:
			return a.visible == true
	)

	for node: Node in nodes:
		node.modulate = Color.TRANSPARENT


func show_animated() -> void:
	if not visible:
		show()

	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)

	for i: int in nodes.size():
		tween.tween_property(
			nodes[i],
			"modulate:a",
			1.0,
			time_to_show
		).set_delay(i * delay_between)

	await tween.finished
