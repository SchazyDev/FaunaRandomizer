extends Control
class_name Main

const REVOLUTIONS : int = 3
const ANIMATION_DURATION : float = 1
const WHEEL_COPIES : int = REVOLUTIONS + 2

const MIN_TICK_INTERVAL : float = 1.0 / 40.0
const MAX_TICK_POLYPHONY : int = 6

@export var mail_scene : PackedScene

@export_group("Audio")
@export var background_music : AudioStream
@export var spin_tick_sound : AudioStream
@export var winner_sound : AudioStream
@export var start_sound : AudioStream

var _mail_list : PackedStringArray
var _winners : Array[String]
var _winners_count : int

var _current_target_index : int = -1
var _is_spinning : bool

var _item_height : float
var _item_separation : float

var _music_tween : Tween
var _spin_step : float
var _last_crossed_index : int
var _last_tick_msec : int
var _spin_tick_active : bool
var _prev_y : float
var _current_speed : float

@onready var _music_player : AudioStreamPlayer = %Music
@onready var _spin_player : AudioStreamPlayer = %Spin
@onready var _sfx_player : AudioStreamPlayer = %SFX

@onready var exit_button : Button = %ExitButton
@onready var modal : Modal = %ModalWindow

@onready var mask : ColorRect = %Mask
@onready var post_process : ColorRect = %PostProcess

@onready var split_conatiner : HSplitContainer = %HSplitContainer

@onready var input_section : AnimatedContainer = %InputSection
@onready var mail_list_input : TextEdit = %MailList
@onready var winners_count_input : LineEdit = %WinnersCount
@onready var start_button : Button = %StartButton

@onready var result_section : AnimatedContainer = %ResultSection
@onready var mail_labels_section : VBoxContainer = %MailLabels
@onready var wheel_panel : Panel = %WheelPanel
@onready var results_panel : VBoxContainer = %ResultsPanel
@onready var results_labels_panel : VBoxContainer = %ResultsLabelsPanel
@onready var reset_button : Button = %ResetButton


func _ready() -> void:
	if _spin_player.max_polyphony < MAX_TICK_POLYPHONY:
		_spin_player.max_polyphony = MAX_TICK_POLYPHONY

	_prepare_scene()
	_connect_signals()

	_play_music(background_music)

	await _show_scene()
	await _show_elements_animated()


func _prepare_scene() -> void:
	split_conatiner.split_offset = 1000
	mask.color.a = 1

	post_process.material.set_shader_parameter("pixel_factor", 100.0)
	post_process.material.set_shader_parameter("color_levels", 2.0)
	post_process.material.set_shader_parameter("dither_strength", 0.0)
	post_process.material.set_shader_parameter("chrom_aberration", 5.0)


func _connect_signals() -> void:
	exit_button.pressed.connect(
		func():
			get_tree().quit()
	)

	mail_list_input.text_changed.connect(
		func():
			_mail_list = mail_list_input.text.strip_edges().split("\n", false)
	)

	winners_count_input.text_changed.connect(_on_winners_count_changed)
	start_button.pressed.connect(_on_start_pressed)
	reset_button.pressed.connect(_on_reset_pressed)


func _play_music(stream: AudioStream) -> void:
	if not stream:
		return

	if not _music_player.stream == stream:
		_music_player.stream = stream
		_music_player.play()

	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()

	_music_tween = create_tween()
	_music_tween.tween_property(
		_music_player,
		"volume_db",
		-10.0,
		0.5
	)

	_music_tween.tween_property(
		_music_player,
		"pitch_scale",
		1.0,
		2.0
	)


func _play_sfx(stream: AudioStream) -> void:
	if not stream:
		return

	_sfx_player.stream = stream
	_sfx_player.play()


func _show_scene() -> void:
	var tween : Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_parallel(true)

	tween.tween_property(
		mask,
		"color:a",
		0.0,
		ANIMATION_DURATION
	)

	tween.tween_property(
		post_process.material,
		'shader_parameter/pixel_factor',
		0.5,
		ANIMATION_DURATION
	)

	tween.tween_property(
		post_process.material,
		'shader_parameter/color_levels',
		6.0,
		ANIMATION_DURATION
	)

	tween.tween_property(
		post_process.material,
		'shader_parameter/dither_strength',
		1.0,
		ANIMATION_DURATION
	)

	tween.tween_property(
		post_process.material,
		'shader_parameter/chrom_aberration',
		0.0,
		ANIMATION_DURATION
	)

	await tween.finished


func _show_elements_animated() -> void:
	var tween : Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_parallel(true)

	tween.tween_property(
		split_conatiner,
		"split_offset",
		0,
		ANIMATION_DURATION
	)

	await tween.finished
	await input_section.show_animated()


func _on_winners_count_changed(new_text: String) -> void:
	if (new_text.is_empty()
		or not new_text.is_valid_int()):
			_winners_count = 0
			winners_count_input.text = ""
			return

	_winners_count = clampi(int(new_text), 0, 99)


func _on_start_pressed() -> void:
	if _mail_list.is_empty():
		await _show_modal("type_mails")
		return

	if _winners_count <= 0:
		await _show_modal("type_winners")
		return

	await _switch_sections(true)
	await result_section.show_animated()

	_winners.clear()
	await _prepare_mail_wheel(false)

	_current_target_index = randi() % _mail_list.size()
	_start_spin()


func _on_reset_pressed() -> void:
	_winners.clear()
	_mail_list.clear()
	_winners_count = 0
	_current_target_index = -1
	_is_spinning = false

	mail_list_input.text = ""
	winners_count_input.text = ""

	for child : Node in results_labels_panel.get_children():
		child.queue_free()

	for child : Node in mail_labels_section.get_children():
		child.queue_free()

	reset_button.hide()

	await _switch_to_results_panel(false)
	await _switch_sections(false)
	await input_section.show_animated()


func _show_modal(type: String) -> bool:
	var modal_text : String
	match type:
		"type_mails":
			modal_text = "Укажите участников"

		"type_winners":
			modal_text = "Укажите количество победителей"

		"winner":
			modal_text = "Победитель #%s:\n%s" % [_winners.size(), _winners[-1]]

		"all_winners":
			modal_text = "Все победители выбраны"

	modal.customize(
		modal_text,
		"HIDE" if type == "all_winners" else "OK",
		"HIDE"
	)

	return await modal.prompt()


func _switch_sections(to_results: bool) -> void:
	if to_results:
		result_section.show()
		await _fade_panel(input_section, false)
		await _fade_panel(result_section, true)

	else:
		input_section.show()
		await _fade_panel(result_section, false)
		await _fade_panel(input_section, true)


func _switch_to_results_panel(to_results: bool) -> void:
	if to_results:
		await _fade_panel(wheel_panel, false)
		await _fade_panel(results_panel, true)

	else:
		await _fade_panel(results_panel, false)
		await _fade_panel(wheel_panel, true)


func _fade_panel(panel: Control, to_show: bool) -> void:
	var tween : Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUART)

	tween.tween_property(
		panel,
		"modulate:a",
		1.0 if to_show else 0.0,
		ANIMATION_DURATION / 2
	)

	await tween.finished


func _prepare_mail_wheel(animate: bool) -> void:
	for child : Node in mail_labels_section.get_children():
		child.queue_free()

	await get_tree().process_frame

	if mail_labels_section is BoxContainer:
		_item_separation = mail_labels_section.get_theme_constant("separation")

	if (_item_height <= 0.0):
		var probe : MailPanel = mail_scene.instantiate()
		mail_labels_section.add_child(probe)

		await get_tree().process_frame

		_item_height = probe.size.y
		probe.queue_free()

		await get_tree().process_frame

	for copy : int in WHEEL_COPIES:
		for j : int in _mail_list.size():
			var mail_panel : MailPanel = mail_scene.instantiate()
			mail_labels_section.add_child(mail_panel)

			mail_panel.set_mail(_mail_list[j])

			if animate and copy == 0:
				mail_panel.show_animated(ANIMATION_DURATION, j)

			else:
				mail_panel.modulate.a = 1.0


func _start_spin() -> void:
	if _mail_list.is_empty():
		return

	_is_spinning = true
	_play_sfx(start_sound)

	var list_size : int = _mail_list.size()
	_spin_step = max(_item_height + _item_separation, 1.0)

	var end_index : int = (WHEEL_COPIES - 2) * list_size + _current_target_index
	var end_y : float = (wheel_panel.size.y - _item_height) * 0.5 - end_index * _spin_step
	var start_y : float = end_y + REVOLUTIONS * list_size * _spin_step

	mail_labels_section.position.y = start_y

	_prev_y = start_y
	_last_crossed_index = int(floor(start_y / _spin_step))
	_last_tick_msec = 0
	_current_speed = 0.0
	_spin_tick_active = true

	var tween : Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(
		mail_labels_section,
		"position:y",
		end_y,
		ANIMATION_DURATION * 5
	)

	tween.finished.connect(_on_spin_finished, CONNECT_ONE_SHOT)


func _process(delta : float) -> void:
	if not _spin_tick_active:
		return

	_update_spin_ticks(delta)


func _update_spin_ticks(delta : float) -> void:
	_current_speed = abs(mail_labels_section.position.y - _prev_y) / max(delta, 0.0001)
	_prev_y = mail_labels_section.position.y

	var crossed : int = int(floor(mail_labels_section.position.y / _spin_step))
	if crossed == _last_crossed_index:
		return

	_last_crossed_index = crossed

	var now_msec : int = Time.get_ticks_msec()
	if now_msec - _last_tick_msec < int(MIN_TICK_INTERVAL * 1000.0):
		return

	_last_tick_msec = now_msec

	_play_spin_tick()


func _play_spin_tick() -> void:
	if not spin_tick_sound:
		return

	_spin_player.stream = spin_tick_sound
	_spin_player.play()


func _on_spin_finished() -> void:
	_is_spinning = false
	_spin_tick_active = false

	if _spin_player.playing:
		_spin_player.stop()

	_play_sfx(winner_sound)

	_winners.append(_mail_list[_current_target_index])
	_mail_list.remove_at(_current_target_index)

	await _show_modal("winner")

	if (_winners.size() < _winners_count
		and not _mail_list.is_empty()):
			_current_target_index = randi() % _mail_list.size()
			await _prepare_mail_wheel(false)
			_start_spin()

	else:
		await get_tree().process_frame
		await _show_modal("all_winners")
		await _switch_to_results_panel(true)
		_show_winners()


func _show_winners() -> void:
	for i : int in _winners.size():
		var mail_panel : MailPanel = mail_scene.instantiate()
		results_labels_panel.add_child(mail_panel)

		mail_panel.set_mail(_winners[i])
		mail_panel.show_animated(ANIMATION_DURATION, i)

	reset_button.show()
