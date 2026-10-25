class_name DataLibrary
extends RefCounted
## Loads every .tres in a folder into a dictionary keyed by one of its properties.
## Adding content means adding a .tres file; no code changes needed.


static func load_folder(folder: String, id_property: StringName) -> Dictionary:
	var result := {}
	var file_names := Array(ResourceLoader.list_directory(folder))
	file_names.sort()
	for file_name: String in file_names:
		if not file_name.ends_with(".tres"):
			continue
		var resource := load(folder + file_name)
		var id: Variant = resource.get(id_property) if resource != null else null
		if id == null or str(id).is_empty():
			push_error("%s%s has no '%s'" % [folder, file_name, id_property])
			continue
		if result.has(id):
			push_error("Duplicate %s '%s' in %s%s" % [id_property, id, folder, file_name])
			continue
		result[id] = resource
	return result
