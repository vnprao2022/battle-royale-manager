extends SceneTree

const UserSettingsScript=preload("res://scripts/user_settings.gd")
const ResponsiveScript=preload("res://scripts/ui/utilities/responsive.gd")
var checks:=0
var failures:=0

func _init()->void:
	_check(int(ProjectSettings.get_setting("display/window/size/window_width_override",0))==0,"1920 width override still forces 1.5x scaling")
	_check(str(ProjectSettings.get_setting("display/window/stretch/mode","disabled"))=="disabled","Canvas stretch still forces virtual 1280 coordinates")
	var settings=UserSettingsScript.new(); settings.values=UserSettingsScript.defaults(); settings.values.resolution="2560x1080"; _check(settings.resolution_value()==Vector2i(2560,1080),"Ultrawide resolution is not supported")
	settings.values.master_volume=37; settings.values.music_volume=28; settings.values.sfx_volume=19; settings.apply_runtime(null); _check(AudioServer.get_bus_index("Music")>=0 and AudioServer.get_bus_index("SFX")>=0,"Audio settings have no runtime buses")
	_check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))-linear_to_db(0.37))<0.01 and absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))-linear_to_db(0.28))<0.01 and absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))-linear_to_db(0.19))<0.01,"Audio sliders do not reach their runtime buses")
	_check(FileAccess.get_file_as_string("res://scripts/main.gd").contains('values.get("reduce_motion",false)'),"Reduce Motion has no UI animation consumer")
	_check(ResponsiveScript.classify(1280)==ResponsiveScript.COMPACT and ResponsiveScript.classify(1600)==ResponsiveScript.STANDARD and ResponsiveScript.classify(1920)==ResponsiveScript.WIDE and ResponsiveScript.classify(2560)==ResponsiveScript.ULTRAWIDE,"Responsive classification mismatch")
	_check(ResponsiveScript.content_width(Vector2(2560,1080))<=2100,"Ultrawide content has no readable maximum")
	if failures>0: push_error("SETTINGS_RESOLUTION_TEST_FAILED checks=%d failures=%d"%[checks,failures]); quit(1)
	else: print("SETTINGS_RESOLUTION_TEST_OK checks=%d"%checks); quit(0)

func _check(condition:bool,message:String)->void:
	checks+=1
	if not condition: failures+=1; push_error("CHECK FAILED: "+message)
