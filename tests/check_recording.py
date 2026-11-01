"""Validate actual game clips; ffmpeg/ffprobe are test tools, not game dependencies."""
import json
import array
import math
import subprocess
import sys
from pathlib import Path

for path in map(Path, sys.argv[1:]):
    info = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_entries",
        "stream=codec_name,width,height,duration,nb_frames,avg_frame_rate",
        "-of", "json", str(path),
    ]))
    video, audio = info["streams"]
    assert video["codec_name"] == "h264" and audio["codec_name"] == "aac"
    assert video["width"] <= 1280 and video["height"] <= 720
    assert int(video["nb_frames"]) > 10, "Recording must contain moving frames"
    assert abs(float(video["duration"]) - float(audio["duration"])) < 0.15
    timing = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
        "frame=best_effort_timestamp_time", "-of", "json", str(path)]))
    times = [float(frame["best_effort_timestamp_time"]) for frame in timing["frames"]]
    assert all(b > a for a, b in zip(times, times[1:])), "Video timestamps must increase"
    pcm = array.array("f", subprocess.check_output([
        "ffmpeg", "-v", "error", "-i", str(path), "-vn", "-f", "f32le", "-"]))
    assert math.sqrt(sum(sample * sample for sample in pcm) / len(pcm)) > 0.00001, "Game audio must be audible"
    # Decode variable-rate video without rounding timestamps to a coarse output timebase.
    subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-fps_mode", "passthrough", "-enc_time_base", "1:60000", "-f", "null", "-"], check=True)
    print(path.name, json.dumps(info["streams"]))
