@tool
extends EditorPlugin
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#	Ignore Folders
#
#	https://github.com/CodeNameTwister/IgnoreFolders
#	author:	"Twister"
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

const IGNORED_ICON : Texture2D = null

const DOT_USER : String = "user://editor/ignorefolders.dat"
const IGNORE : String = ".gdignore"

const IGNORE_OVER_ICON : Texture2D = preload("res://addons/IgnoreFolders/images/Ignore.svg")

var _menu_service : EditorContextMenuPlugin = null
var _fupdate : bool = false

var _show_ignored_items : bool = false:
	set(e):
		if _show_ignored_items != e:
			_show_ignored_items = e
			if is_node_ready():
				_save()
				update()
		else:
			_show_ignored_items = e
			if is_node_ready() and _fupdate:
				_fupdate = false
				var file : EditorFileSystem = EditorInterface.get_resource_filesystem()
				if file:
					file.scan()

var _buffer : PackedStringArray = []
var _tree : Tree = null
var _busy : bool = false

var _default_item : TreeItem = null

var _flg_totals : int = 0

var _buttons : Array[Node] = []

func _check_buffer() -> void:
	var _update : bool = false
	for x : int in range(_buffer.size() - 1, -1 , -1):
		var path : String = _buffer[x]
		if !FileAccess.file_exists(path.path_join(IGNORE)):
			_update = true
			break
	if update:
		var dirs : PackedStringArray = []
		get_all_dirs_recursive("res://", dirs)
		
		for x : int in range(dirs.size() -1, -1, -1):
			var path : String = dirs[x]
			if path.begins_with("res://.godot"):
				dirs.remove_at(x)
		
		_buffer = dirs
		

func update() -> void:
	if _buffer.size() == 0:return
	if _busy or !_show_ignored_items:return
	_fupdate = true
	_busy = true
	_check_buffer()
	var root : TreeItem = _tree.get_root()
	var item : TreeItem = root.get_first_child()

	while null != item and item.get_metadata(0) != "res://":
		item = item.get_next()
	_flg_totals = 0

	_explore(item)
	set_deferred(&"_busy", false)

func __sub(dir : String, path : String, root : TreeItem) -> void:
	var meta : String = root.get_metadata(0)
	if meta == dir:
		var exist : bool = false
		for c : TreeItem in root.get_children():
			var _meta : String = c.get_metadata(0)
			if _meta == path:
				exist = true
				if !_show_ignored_items:
					root.remove_child(c)
					pass
				break
		if _show_ignored_items and !exist:
			var new_item : TreeItem = root.create_child()
			new_item.set_text(0, path.trim_suffix("/").get_file())
			if _default_item:
				new_item.set_icon(0, IGNORE_OVER_ICON)
				new_item.set_icon_modulate(0, _default_item.get_icon_modulate(0).darkened(0.4))
			else:
				new_item.set_icon(0, IGNORE_OVER_ICON)
				new_item.set_icon_modulate(0, Color.LIGHT_SLATE_GRAY)
			new_item.set_metadata(0,  path)
			new_item.set_meta(&"opath", path)
			new_item.set_custom_color(0, Color.DARK_GRAY)
		return
	for tree_item : TreeItem in root.get_children():
		if dir.begins_with(meta):
			__sub(dir, path, tree_item)

func _explore(item : TreeItem) -> void:
	_default_item = item
	for path : String in _buffer:
		__sub(path.get_base_dir().path_join(""), path, item)
	
func _def_update() -> void:
	update.call_deferred()
	
func _ready() -> void:
	
	
	var dock : FileSystemDock = EditorInterface.get_file_system_dock()
	var fs : EditorFileSystem = EditorInterface.get_resource_filesystem()
	_n(dock)
	
	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM, _menu_service)
	
	dock.folder_moved.connect(_moved_callback)
	dock.folder_removed.connect(_remove_callback)
	dock.folder_color_changed.connect(_def_update)
	fs.filesystem_changed.connect(_def_update)
	
	var containers :  Array[Container] = find_button_container(dock)
	for container : Container in containers:
		var button : Button = Button.new()
		button.tooltip_text = "Show/Hide Folders Ignored"
		button.flat = true
		button.icon = IGNORE_OVER_ICON
		button.toggle_mode = true
		button.toggled.connect(_show_hide_enable)
		button.button_pressed = _show_ignored_items
		container.add_child(button)
		container.move_child(button, container.get_child_count() - 2)
		_buttons.append(button)

func _process(delta: float) -> void:
	var efs : EditorFileSystem = EditorInterface.get_resource_filesystem()
	
	if efs.is_scanning():
		return
	
	set_process(false)
	
	var o : Object = self
	for __ : int in range(15):
		await get_tree().process_frame
	if is_instance_valid(o):
		_def_update()
		
func _show_hide_enable(toggle : bool) -> void:
	for b : Button in _buttons:
		b.button_pressed = toggle
	_show_ignored_items = toggle
	_def_update()
	
func get_buffer() -> PackedStringArray:
	return _buffer

# credits: collapse_folders
func find_button_container(node: Node) -> Array[Container]:
	var containers: Array[Container] = []
	for child in node.get_children():
		if child is MenuButton and child.tooltip_text == tr("Sort Files"):
			containers.append(node)
		
		for container in find_button_container(child):
			containers.append(container)

	return containers

func _on_ignore_cmd(paths : PackedStringArray) -> void:
	for path : String in paths:
		var _path : String = path.path_join(IGNORE)
		if FileAccess.file_exists(_path):
			DirAccess.remove_absolute(_path)
			var i : int = _buffer.find(path.trim_suffix("/"))
			if i > -1:
				_buffer.remove_at(i)
		else:
			var _file : FileAccess = FileAccess.open(_path, FileAccess.WRITE)
			if _file:
				_file.store_8(0)
				_file.close()
				var i : int = _buffer.find(path)
				if i < 0:
					_buffer.append(path.trim_suffix("/"))
		
	var file : EditorFileSystem = EditorInterface.get_resource_filesystem()
	if file:
		file.scan()
		var o : Object = self
		for __ : int in range(15):
			await get_tree().process_frame
		if is_instance_valid(o):
			_def_update()
			
func _enter_tree() -> void:
	_setup()
	
	_menu_service = ResourceLoader.load("res://addons/IgnoreFolders/menu_item.gd").new()
	_menu_service.ref_plug = self
	_menu_service.ignore_folders.connect(_on_ignore_cmd)
	
	var dirs : PackedStringArray = []
	get_all_dirs_recursive("res://", dirs)
	
	for x : int in range(dirs.size() -1, -1, -1):
		var path : String = dirs[x]
		if path.begins_with("res://.godot"):
			dirs.remove_at(x)
	
	_buffer = dirs
	
	_save()
		
		
func _save() -> void:
	var cfg : ConfigFile = ConfigFile.new()
	cfg.set_value("IgnoreUnignoreItems", "Enabled", _show_ignored_items)
	cfg.save(DOT_USER)
	cfg = null
		
		
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_save()
		
		
func _exit_tree() -> void:
	
	if is_instance_valid(_menu_service):
		remove_context_menu_plugin(_menu_service)
		_menu_service.ref_plug = null
	
	var dock : FileSystemDock = EditorInterface.get_file_system_dock()
	var fs : EditorFileSystem = EditorInterface.get_resource_filesystem()
	_n(dock)
	dock.folder_moved.disconnect(_moved_callback)
	dock.folder_removed.disconnect(_remove_callback)
	dock.folder_color_changed.disconnect(_def_update)
	
	
	fs.filesystem_changed.disconnect(_def_update)
	
	_menu_service = null
	_buffer.clear()
	
	for x : Button in _buttons:
		x.queue_free()
		
func get_all_files_recursive(path: String, files_array: PackedStringArray = []) -> void:
	var dir : DirAccess = DirAccess.open(path)

	if dir == null:
		return
		
	dir.list_dir_begin()
	var file_name : String = dir.get_next()

	while !file_name.is_empty():
		if dir.current_is_dir():
			var current_path : String = path.path_join(file_name)
			if FileAccess.file_exists(current_path.path_join(IGNORE)):
				files_array.append(current_path)
			get_all_files_recursive(current_path, files_array)
		file_name = dir.get_next()
	dir.list_dir_end()
		
func get_all_dirs_recursive(path: String, files_array: PackedStringArray = []) -> void:
	var dir : DirAccess = DirAccess.open(path)

	if dir == null:
		return

	dir.list_dir_begin()
	var file_name : String = dir.get_next()

	while !file_name.is_empty():
		if dir.current_is_dir():
			var current_path : String = path.path_join(file_name)
			if FileAccess.file_exists(current_path.path_join(IGNORE)):
				files_array.append(current_path)
				file_name = dir.get_next()
				continue
			get_all_files_recursive(current_path, files_array)
		file_name = dir.get_next()
	dir.list_dir_end()

func _setup() -> void:
	var dir : String = DOT_USER.get_base_dir()
	if !DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
		return
	if FileAccess.file_exists(DOT_USER):
		var cfg : ConfigFile = ConfigFile.new()
		if OK != cfg.load(DOT_USER):return
		_show_ignored_items = bool(cfg.get_value("IgnoreUnignoreItems", "Enabled", true))
		
#region callbacks
func _moved_callback(a : String, b : String ) -> void:
	if a != b:
		var i : int = _buffer.find(a)
		if i > -1:
			_buffer.remove_at(i)
			if !_buffer.has(b):
				if FileAccess.file_exists(b.path_join(IGNORE)):
					_buffer.append(b)
					_def_update()

func _remove_callback(path : String) -> void:
	var i : int = _buffer.find(path)
	if i > -1:
		_buffer.remove_at(i)
		_def_update()
#endregion
		
#region rescue_fav
func _n(n : Node) -> bool:
	if n is Tree:
		var t : TreeItem = (n.get_root())
		if null != t:
			t = t.get_first_child()
			while t != null:
				if t.get_metadata(0) == "res://":
					_tree = n
					return true
				t = t.get_next()
	for x in n.get_children():
		if _n(x): return true
	return false
#endregion
