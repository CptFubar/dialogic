@tool
extends DialogicEvent
class_name DialogicConverterEvent

#Well this isnt ACTUALLY an event, but I can't find any other way to register to the settings panel...

func get_required_subsystems() -> Array:
	return [
				{'name':'Converter',
				'subsystem': get_script().resource_path.get_base_dir().plus_file('Subsystem_Converter.gd'),
				'settings': get_script().resource_path.get_base_dir().plus_file('Settings_Converter.tscn')
				},
			]
