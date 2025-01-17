@tool
extends ResourceFormatSaver
class_name DialogicTimelineFormatSaver


func _get_recognized_extensions(resource: Resource) -> PackedStringArray:
	return PackedStringArray(["dtl"])


# Return true if this resource should be loaded as a DialogicCharacter 
func _recognize(resource: Resource) -> bool:
	# Cast instead of using "is" keyword in case is a subclass
	resource = resource as DialogicTimeline
	
	if resource:
		return true
	
	return false


# Save the resource
func _save(resource: Resource, path: String = '', flags: int = 0) -> int:
	var err:int
	var file:File = File.new()
	err = file.open(path, File.WRITE)
	
	if err != OK:
		printerr('Can\'t write file: "%s"! code: %d.' % [path, err])
		return err
	
	var result = TimelineUtil.events_to_text(resource._events)
	file.store_string(result)
	file.close()
	print('[Dialogic] Saved timeline "' , path, '"')
	
	# Checking for translation updates
	var trans_updates := {}
	var translate :bool= DialogicUtil.get_project_setting('dialogic/translation_enabled', false)
	for idx in range(0, len(resource._events)):
		var event = resource._events[idx]
		
		if event != null:
			if translate and event.can_be_translated():
				if event.translation_id:
					trans_updates[event.translation_id] = event.get_original_translation_text()
				else:
					trans_updates[event.add_translation_id()] = event.get_original_translation_text()
	
	if translate:
		update_translations(path, trans_updates)
	return OK

func update_translations(path:String, translation_updates:Dictionary):
	if translation_updates.is_empty():
		return
	var err:int
	var trans_file := File.new()
	var file_path :String = ""
	if DialogicUtil.get_project_setting('dialogic/translation_path', '').ends_with('.csv'):
		file_path = ProjectSettings.get_setting('dialogic/translation_path')
	else:
		file_path = path.trim_suffix('.dtl')+'_translation.csv'
	
	err = trans_file.open(file_path, File.READ)
	if err != OK:
		printerr('[Dialogic] Can\'t read translation file: "%s"! code: %d.' % [file_path, err])
		return
	
	var csv_lines := []
	while !trans_file.eof_reached():
		csv_lines.append(trans_file.get_csv_line())
		if csv_lines[-1][0] in translation_updates.keys():
			csv_lines[-1][1] = translation_updates[csv_lines[-1][0]]
			translation_updates.erase(csv_lines[-1][0])
	
	
	trans_file.close()
	trans_file.open(file_path, File.WRITE)
	for line in csv_lines:
		if line and line[0]:
			trans_file.store_csv_line(line)
	for key in translation_updates.keys():
		trans_file.store_csv_line([key, translation_updates[key]])
	trans_file.close()
	print('[Dialogic] Updated translations for "', path ,'"')
