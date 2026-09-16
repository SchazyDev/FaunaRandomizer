extends Control
class_name Modal

signal confirmed(is_confirmed: bool)

var open : bool
var tween : Tween

@onready var modal_window : Control = %ModalWindow
@onready var header_label : Label = %ModalHeaderLabel
@onready var confirm_button : BaseButton = %ModalConfirmButton
@onready var cancel_button : BaseButton = %ModalCancelButton
@onready var container : MarginContainer = %MarginContainer
@onready var buttons_container : Container = %HBoxContainer


func _ready() -> void:
	_connect_signals()
	set_process_unhandled_key_input(false)
	_prepare_panel()


func _connect_signals() -> void:
	cancel_button.pressed.connect(_on_cancel)
	confirm_button.pressed.connect(_on_confirm)


func _prepare_panel() -> void:
	container.scale = Vector2(0.8, 0.8)
	modal_window.modulate.a = 0
	modal_window.pivot_offset = modal_window.size / 2
	hide()


func _on_confirm() -> void:
	close_modal(true)


func _on_cancel() -> void:
	if not open:
		return

	close_modal(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed('ui_cancel') and open:
		get_viewport().set_input_as_handled()
		_on_cancel()


func close_modal(is_confirmed: bool) -> void:
	set_process_unhandled_key_input(false)

	await _show_animated(false)

	confirmed.emit(is_confirmed)
	hide()
	open = false
	await get_tree().process_frame


func prompt() -> bool:
	modal_window.pivot_offset = modal_window.size / 2
	show()

	_show_animated(true)

	open = true
	set_process_unhandled_key_input(true)
	return await confirmed


func _show_animated(show_panel: bool) -> void:
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_parallel(true)

	tween.tween_property(
		container,
		'scale',
		Vector2(1.05, 1.05) if show_panel else Vector2(0.0, 0.0),
		0.3
	)

	tween.tween_property(
		modal_window,
		'modulate:a',
		1.0 if show_panel else 0.0,
		0.3
	)

	await tween.finished


func customize(
	message_text: String,
	confirm_text: String = "",
	cancel_text: String = ""
) -> Modal:

	header_label .text	= message_text

	_prepare_choice_button(confirm_button, confirm_text)
	_prepare_choice_button(cancel_button, cancel_text)
	_prepare_buttons_section([confirm_button, cancel_button])

	return self


func _prepare_choice_button(button: Button, text: String) -> void:
	button.visible = false if text == 'HIDE' else true
	button.text = '   %s   ' % text


func _prepare_buttons_section(buttons: Array[Button]) -> void:
	for button: Button in buttons:
		if button.visible:
			buttons_container.visible = true
			return

	buttons_container.visible = false
	await get_tree().create_timer(2).timeout
	close_modal(true)
