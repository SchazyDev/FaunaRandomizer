class_name AnimatedButton
extends Node

@export var button_object : Node = self
@export var player : AudioStreamPlayer

@export_subgroup('Animation')
@export var hover_scale			: Vector2 	= Vector2(1.10, 1.10)
@export var click_scale			: Vector2 	= Vector2(0.90, 0.90)
@export var animation_duration	: float 	= 0.20

@export_subgroup('Sound')
@export var use_press_sound		: bool		= true
@export var press_sound			: AudioStream
@export var use_hover_sound		: bool		= true
@export var hover_sound			: AudioStream

var tween : Tween


func _ready() -> void:
	setup_button	(button_object)
	connect_signals	(button_object)


func setup_button(button: BaseButton) -> void:
	if not is_instance_valid(button):
		return

	button.scale = Vector2(1, 1)
	_on_resized(button)


func connect_signals(button: BaseButton) -> void:
	button.resized		.connect(_on_resized		.bind(button))
	button.pressed		.connect(_on_pressed		.bind(button))

	button.mouse_entered.connect(_on_mouse_entered	.bind(button))
	button.mouse_exited	.connect(_on_mouse_exited	.bind(button))


func _on_pressed(button: BaseButton) -> void:
	if use_press_sound and player:
		player.stream = press_sound
		player.play()

	animate_scale(button, click_scale, true)


func _on_mouse_entered(button: BaseButton) -> void:
	if button.disabled or button.modulate.a < 0.5:
		return

	if use_hover_sound and player:
		player.stream = hover_sound
		player.play()

	animate_scale(button, hover_scale)


func _on_mouse_exited(button: BaseButton) -> void:
	if button.disabled or button.modulate.a < 0.5:
		return

	animate_scale(button, Vector2(1, 1))


func animate_scale(button: BaseButton, target_scale: Vector2, reset: bool = false) -> void:
	if (not is_instance_valid(button)
		or button.scale == target_scale):
			return

	if is_instance_valid(tween):
		tween.kill()

	tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	tween.tween_property(
		button,
		'scale',
		Vector2.ONE if reset else target_scale,
		animation_duration if reset else animation_duration * 1.5
	)


func _on_resized(button : BaseButton) -> void:
	if not is_instance_valid(button):
		return

	button.pivot_offset = Vector2(button.size.x / 2, button.size.y / 2)
