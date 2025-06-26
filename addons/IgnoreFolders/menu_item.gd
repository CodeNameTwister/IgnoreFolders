extends EditorContextMenuPlugin
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#	Ignore Folders
#
#	https://github.com/CodeNameTwister/IgnoreFolders
#	author:	"Twister"
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#region godotengine_repository_icons
const TOGGLE_ICON : Texture = preload("res://addons/IgnoreFolders/images/Ignore.svg")
#endregion

signal ignore_folders(path : PackedStringArray)

var ref_plug : EditorPlugin = null

func _popup_menu(paths: PackedStringArray) -> void:
	var _process : bool = false
	var is_ignored : bool = false
	var is_visible : bool = false

	var _ref : PackedStringArray
	if is_instance_valid(ref_plug):
		_ref = ref_plug.get_buffer()

	for p : String in paths:
		if !FileAccess.file_exists(p) and DirAccess.dir_exists_absolute(p):
			_process = true
			if _ref.has(p):
				is_ignored = true
				if is_visible:break
			else:
				is_visible = true
				if is_ignored:break

	if _process:
		if paths.size() == 1:
			if paths[0] == "res://":
				return
		# The translation in tool mode doesn't seem to work at the moment, I'll leave the code anyway.
		var locale : String = OS.get_locale_language()
		var translation: Translation = TranslationServer.get_translation_object(locale)
		if is_visible and is_ignored:
			add_context_menu_item("{0} {1}".format([_get_tr(translation,&"Ignore/Unignore Toggle"), _get_tr(translation,&"Folder")]).capitalize(), _on_ignore_cmd, TOGGLE_ICON)
		elif is_visible:
			add_context_menu_item("{0} {1}".format([_get_tr(translation,&"Ignore"), _get_tr(translation,&"Folder")]).capitalize(), _on_ignore_cmd, TOGGLE_ICON)
		else:
			add_context_menu_item("{0} {1}".format([_get_tr(translation,&"Unignore"), _get_tr(translation,&"Folder")]).capitalize(), _on_ignore_cmd, TOGGLE_ICON)

func _on_ignore_cmd(paths : PackedStringArray) -> void:
	ignore_folders.emit(paths)

func _get_tr(translation : Translation, msg : StringName) -> StringName:
	if translation == null:
		return msg
	var new_msg : StringName = translation.get_message(msg)
	if new_msg.is_empty():
		return msg
	return new_msg
