@tool
extends EditorPlugin

class RecorderExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "OffRoadRecorder"
	func _export_begin(features: PackedStringArray, _debug: bool, _path: String, _flags: int) -> void:
		if features.has("macos"):
			var path := "res://build/native/recorder"
			if FileAccess.file_exists(path):
				add_file("res://native/recorder.bin",FileAccess.get_file_as_bytes(path),false)
			else:
				push_error("Build the macOS video encoder with tools/build_recorder.sh before export.")

var exporter: RecorderExport
func _enter_tree() -> void:
	exporter=RecorderExport.new()
	add_export_plugin(exporter)
func _exit_tree() -> void:
	remove_export_plugin(exporter)
