@tool
extends DialogicEvent
class_name DialogicBackgroundEvent

# DEFINE ALL PROPERTIES OF THE EVENT
var Path: String = ""

func _execute() -> void:
	dialogic.Backgrounds.update_background(Path)
	finish()

func get_required_subsystems() -> Array:
	return [
				{'name':'Backgrounds',
				'subsystem':get_script().resource_path.get_base_dir().plus_file('Subsystem_Backgrounds.gd')},
			]


################################################################################
## 						INITIALIZE
################################################################################

# SET ALL VALUES THAT SHOULD NEVER CHANGE HERE
func _init() -> void:
	event_name = "Background"
	set_default_color('Color4')
	event_category = Category.AUDIOVISUAL
	event_sorting_index = 0
	


################################################################################
## 						SAVING/LOADING
################################################################################
func get_shortcode() -> String:
	return "background"

func get_shortcode_parameters() -> Dictionary:
	return {
		#param_name : property_name
		"path"		: "Path",
	}


################################################################################
## 						EDITOR REPRESENTATION
################################################################################

func build_event_editor():
	add_header_edit('Path', ValueType.SinglelineText, 'Path:')
