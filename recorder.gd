extends Node
signal message(text: String)
signal recording_changed(active: bool)

var source: Viewport
var active := false
var finishing := false
var path := ""
var _worker := Thread.new()
var _mutex := Mutex.new()
var _semaphore := Semaphore.new()
var _queue: Array[PackedByteArray]=[]
var _process_info: Dictionary={}
var _capture_audio: AudioEffectCapture
var _audio_index := -1
var _started := 0
var _next_frame := 0.0
var _audio_frames := 0
var _dimensions := Vector2i(1280,720)
var _capturing := false
var _ready_to_capture := false
var dropped_frames := 0
var _finish_deadline := 0

func output_directory() -> String:
	var directory := OS.get_system_dir(OS.SYSTEM_DIR_MOVIES).path_join("Off Road Rider")
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:
		return OS.get_user_data_dir()
	return directory

func status_text() -> String:
	if finishing:
		return "SAVING VIDEO…"
	if active:
		var seconds := int((Time.get_ticks_msec()-_started)/1000)
		return "● REC %02d:%02d  ·  F9 STOP"%[seconds/60,seconds%60]
	return "F9 RECORD  ·  F6 FILM CAMERA  ·  F10 CLIPS"

func start_recording(view: Viewport) -> void:
	if active or finishing:
		return
	if OS.get_name()!="macOS":
		message.emit("Video recording currently requires macOS.")
		return
	var helper := ProjectSettings.globalize_path("res://build/native/recorder")
	if FileAccess.file_exists("res://native/recorder.bin"):
		var checksum := FileAccess.get_sha256("res://native/recorder.bin")
		helper=OS.get_user_data_dir().path_join("video-recorder-"+checksum.substr(0,16))
		# A finished encoder can still be exiting; never overwrite its running executable.
		if not FileAccess.file_exists(helper) or FileAccess.get_sha256(helper)!=checksum:
			var file := FileAccess.open(helper,FileAccess.WRITE)
			if file==null:
				message.emit("Cannot prepare video encoder.")
				return
			file.store_buffer(FileAccess.get_file_as_bytes("res://native/recorder.bin"))
			file.close()
			if OS.execute("/bin/chmod",["u+x",helper])!=0:
				message.emit("Cannot start video encoder.")
				return
	if not FileAccess.file_exists(helper):
		message.emit("Recorder is missing. Build it with tools/build_recorder.sh.")
		return
	source=view
	var viewport_size := view.get_visible_rect().size
	var scale_value := minf(1280/viewport_size.x,720/viewport_size.y)
	_dimensions=Vector2i(maxi(2,int(viewport_size.x*scale_value)/2*2),maxi(2,int(viewport_size.y*scale_value)/2*2))
	path=output_directory().path_join("Ride-%s-%d.mp4"%[Time.get_datetime_string_from_system().replace(":","-"),Time.get_ticks_msec()])
	_process_info=OS.execute_with_pipe(helper,[path,str(_dimensions.x),str(_dimensions.y),str(AudioServer.get_mix_rate())])
	if _process_info.is_empty():
		message.emit("Could not launch video encoder.")
		return
	_capture_audio=AudioEffectCapture.new()
	_capture_audio.buffer_length=2
	_audio_index=AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0,_capture_audio)
	_audio_frames=0
	dropped_frames=0
	_queue.clear()
	_semaphore=Semaphore.new()
	_ready_to_capture=false
	_started=Time.get_ticks_msec()
	_next_frame=0
	active=true
	_worker.start(_encode)
	recording_changed.emit(true)

func _process(_delta: float) -> void:
	if finishing and Time.get_ticks_msec()>_finish_deadline:
		OS.kill(_process_info.pid)
		_finish_deadline=Time.get_ticks_msec()+20000
	if not active or not _ready_to_capture or _capturing:
		return
	var now := Time.get_ticks_msec()
	if now<_next_frame:
		return
	_next_frame=maxf(_next_frame+1000.0/30,now)
	_mutex.lock()
	var backed_up := _queue.size()>=2
	_mutex.unlock()
	if backed_up:
		dropped_frames+=1
		return
	_capture_frame()

func _capture_frame() -> void:
	_capturing=true
	await RenderingServer.frame_post_draw
	if not active:
		_capturing=false
		return
	var frame := source.get_texture().get_image()
	if frame.is_empty():
		_capturing=false
		return
	frame.resize(_dimensions.x,_dimensions.y,Image.INTERPOLATE_BILINEAR)
	var jpeg := frame.save_jpg_to_buffer(0.87)
	var sound := _capture_audio.get_buffer(_capture_audio.get_frames_available())
	var packet := PackedByteArray()
	packet.resize(24)
	packet.encode_u32(0,jpeg.size())
	packet.encode_u32(4,sound.size()*8)
	packet.encode_double(8,(Time.get_ticks_msec()-_started)/1000.0)
	packet.encode_s64(16,_audio_frames)
	_audio_frames+=sound.size()
	packet.append_array(jpeg)
	packet.append_array(sound.to_byte_array())
	_mutex.lock()
	_queue.append(packet)
	_mutex.unlock()
	_semaphore.post()
	_capturing=false

func stop_recording() -> void:
	if not active:
		return
	active=false
	finishing=true
	_finish_deadline=Time.get_ticks_msec()+20000
	_ready_to_capture=false
	if _capture_audio.get_discarded_frames()>0:
		message.emit("Recording ran behind; some sound may be missing.")
	AudioServer.remove_bus_effect(0,_audio_index)
	_audio_index=-1
	var end := PackedByteArray()
	end.resize(24)
	_mutex.lock()
	_queue.append(end)
	_mutex.unlock()
	_semaphore.post()
	recording_changed.emit(false)

func _encode() -> void:
	var pipe: FileAccess=_process_info.stdio
	var greeting := pipe.get_line()
	if greeting!="READY":
		_encoder_done.call_deferred(greeting if not greeting.is_empty() else "Encoder failed to start")
		return
	_encoder_ready.call_deferred()
	while true:
		_semaphore.wait()
		_mutex.lock()
		var packet: PackedByteArray=_queue.pop_front()
		_mutex.unlock()
		pipe.store_buffer(packet)
		if pipe.get_error()!=OK:
			_encoder_done.call_deferred("Video encoder disconnected")
			return
		if packet.decode_u32(0)==0:
			break
	var result := pipe.get_line()
	_encoder_done.call_deferred("" if result=="SAVED" else (result if not result.is_empty() else "Encoder closed before saving"))

func _encoder_ready() -> void:
	_started=Time.get_ticks_msec()
	_next_frame=_started
	_capture_audio.clear_buffer()
	_ready_to_capture=active

func _encoder_done(error: String) -> void:
	_worker.wait_to_finish()
	if _audio_index>=0:
		AudioServer.remove_bus_effect(0,_audio_index)
		_audio_index=-1
	_process_info.stdio.close()
	_process_info.stderr.close()
	active=false
	finishing=false
	_ready_to_capture=false
	recording_changed.emit(false)
	message.emit("Saved: "+path if error.is_empty() else "Recording failed: "+error)

func _exit_tree() -> void:
	if active:
		stop_recording()
	if _worker.is_started():
		_worker.wait_to_finish()
