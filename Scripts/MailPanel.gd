extends Control
class_name MailPanel

@onready var label: Label = %Label


func set_mail(mail: String) -> void:
	label.text = mail


func show_animated(duration: float, delay: float) -> void:
	await get_tree().create_timer(delay / 10).timeout

	var tween : Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_parallel(true)

	tween.tween_property(
		self,
		"modulate:a",
		1.0,
		duration
	).from_current()

	await tween.finished
