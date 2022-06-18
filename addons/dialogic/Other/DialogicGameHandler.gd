extends Node

enum states {IDLE, SHOWING_TEXT, ANIMATING, AWAITING_CHOICE, WAITING}

var current_timeline = null
var current_timeline_events = []


var current_state = null setget set_current_state
var current_event_idx = 0
var current_portraits = []
var current_bg_music
var current_bg_image
var current_name
var current_text

signal state_changed(new_state)
signal timeline_ended()
signal signal_event(argument)

################################################################################
## 						INPUT (WIP)
################################################################################
# This shouldn't be handled by this script I think, but for testing purposes this works.
func _input(event:InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if current_state == states.IDLE:
			handle_next_event()
		elif current_state == states.SHOWING_TEXT:
			skip_text_animation()

################################################################################
## 						TIMELINE+EVENT HANDLING
################################################################################
func start_timeline(timeline_resource) -> void:
	# load the resource if only the path is given
	if typeof(timeline_resource) == TYPE_STRING:
		timeline_resource = load(timeline_resource)
	
	
	current_timeline = timeline_resource
	current_timeline_events = current_timeline.get_events()
	current_event_idx = -1
	
	handle_next_event()


func end_timeline():
	current_timeline = null
	current_timeline_events = []
	emit_signal("timeline_ended")


func handle_next_event(ignore_argument = "") -> void:
	handle_event(current_event_idx+1)
	
	
func handle_event(event_index:int) -> void:
	if not current_timeline:
		return
	
	hide_all_choices()
	if event_index >= len(current_timeline_events):
		emit_signal('timeline_ended')
		return
	
	current_event_idx = event_index
	var event:DialogicEvent = current_timeline_events[event_index]
	print("\n[D] Handle Event ", event_index, ": ", event)
	if event.continue_at_end:
		print("    -> WILL AUTO CONTINUE!")
		event.connect("event_finished", self, 'handle_next_event')
	event.execute(self)

################################################################################
## 						DISPLAY NODES
################################################################################
func _ready() -> void:
	reset_all_display_nodes()

func reset_all_display_nodes() -> void:
	update_dialog_text('')
	update_name_label('', Color.white)
	hide_all_choices()

func update_dialog_text(text:String) -> void:
	current_state = states.SHOWING_TEXT
	for text_node in get_tree().get_nodes_in_group('dialogic_dialog_text'):
		text_node.bbcode_text = text
		text_node.reveal_text()

func skip_text_animation():
	for text_node in get_tree().get_nodes_in_group('dialogic_dialog_text'):
		text_node.finish_text()

func update_name_label(name:String, color:Color = Color()) -> void:
	for name_label in get_tree().get_nodes_in_group('dialogic_name_label'):
		name_label.text = name
		name_label.self_modulate = color

func update_portrait(character: DialogicCharacter, portrait:String = "", position_idx:int = -1, z_index:int = 0, move:bool = false, animation:String = "") -> void:
	print("HELLO GUYS")
	
	if not character:
		return
	if len(get_tree().get_nodes_in_group('dialogic_portrait_holder')) == 0:
		assert('[Dialogic] If you want to display portraits, you need a PortraitHolder scene!')
		
	if is_character_joined(character):
		var info = get_current_portrait_info_of_character(character)
		if position_idx == -1:
			position_idx = info.position
		if portrait == "":
			portrait = info.portrait
	
	print(character.name, portrait, position_idx)
	if portrait and position_idx:
		for node in get_tree().get_nodes_in_group('dialogic_portrait_position'):
			if node.position_index == position_idx:
				print("hurray")
				var path = character.portraits[portrait].path
				for portrait in current_portraits:
					if portrait.character == character:
						portrait.node.queue_free()
						current_portraits.erase(portrait)
				if not path.ends_with('.tscn'):
					var sprite = Sprite.new()
					get_tree().get_nodes_in_group('dialogic_portrait_holder')[0].add_child(sprite)
					sprite.texture = load(path)
					sprite.centered = false
					sprite.scale = Vector2(1,1)*character.portraits[portrait].scale
					sprite.global_position = node.global_position + character.portraits[portrait].offset
					sprite.global_position.x -= sprite.texture.get_width()/2.0*character.portraits[portrait].scale*character.scale
					sprite.global_position.y -= sprite.texture.get_height()*character.portraits[portrait].scale*character.scale
					current_portraits.append({'character':character, 'portrait':portrait, 'position':position_idx, 'node':sprite})
				
	else:
		for portrait in current_portraits:
			if portrait.character == character:
				portrait.node.queue_free()
				current_portraits.erase(portrait)

func remove_portrait(character:DialogicCharacter) -> void:
	var info = get_current_portrait_info_of_character(character)
	info.node.queue_free()
	current_portraits.erase(info)

func hide_all_choices() -> void:
	for node in get_tree().get_nodes_in_group('dialogic_choice_button'):
		node.hide()
		if node.is_connected('pressed', self, 'choice_selected'):
			node.disconnect('pressed', self, 'choice_selected')

func show_current_choices() -> void:
	hide_all_choices()
	var button_idx = 1
	for choice_index in get_current_choice_indexes():
		var choice_event = current_timeline_events[choice_index]
		show_choice(button_idx, choice_event.Text, true, choice_index)
		button_idx += 1

func show_choice(button_index:int, text:String, enabled:bool, event_index:int) -> void:
	for node in get_tree().get_nodes_in_group('dialogic_choice_button'):
		if node.choice_index == button_index:
			node.show()
			node.text = text
			node.connect('pressed', self, 'choice_selected', [event_index])

func choice_selected(event_index:int) -> void:
	hide_all_choices()
	current_state = states.IDLE
	handle_event(event_index)

func update_background(path:String) -> void:
	for node in get_tree().get_nodes_in_group('dialogic_bg_image'):
		if path.ends_with('.tscn'):
			node.add_child(load(path).instance())
		else:
			node.texture = load(path)


################################################################################
## 						HELPERS
################################################################################
func set_current_state(new_state:int) -> void:
	print('~~~ CHANGE STATE ', ["IDLE", "TEXT", "ANIM", "CHOICE", "WAIT",][new_state])
	current_state = new_state
	emit_signal('state_changed', new_state)

func is_question(index:int) -> bool:
	if current_timeline_events[index] is DialogicTextEvent:
		if len(current_timeline_events)-1 != index:
			if current_timeline_events[index+1] is DialogicChoiceEvent:
				return true
	return false

func get_current_choice_indexes() -> Array:
	var choices = []
	var evt_idx = current_event_idx
	var ignore = 0
	while true:
		evt_idx += 1
		if evt_idx >= len(current_timeline_events):
			break
		
		if current_timeline_events[evt_idx] is DialogicChoiceEvent:
			if ignore == 0:
				choices.append(evt_idx)
			ignore += 1
		if current_timeline_events[evt_idx] is DialogicConditionEvent:
			ignore += 1
		else:
			if ignore == 0:
				break
		
		if current_timeline_events[evt_idx] is DialogicEndBranchEvent:
			ignore -= 1
	
	return choices

func is_character_joined(character:DialogicCharacter) -> bool:
	for portrait in current_portraits:
		if portrait.character == character:
			return true
	return false

func get_joined_characters() -> Array:
	var chars = []
	for portrait in current_portraits:
		chars.append(portrait.character)
	return chars

func get_current_portrait_info_of_character(character:DialogicCharacter) -> Array:
	for portrait in current_portraits:
		if portrait.character == character:
			return portrait
	return []