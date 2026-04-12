"""
services/voice_changer.py

QML → Python команды:
  {"cmd": "tts", "text": "...", "mic_volume": 2.0}
  {"cmd": "rt_start"}
  {"cmd": "rt_stop"}
  {"cmd": "set_mic_volume", "volume": 2.0}
  {"cmd": "set_speaker_volume", "volume": 1.0}
  {"cmd": "set_voice", "wav": "/path/to/file.wav", "txt": "текст"}
  {"cmd": "save_phrase", "text": "...", "filename": "phrase_001.wav"}
  {"cmd": "list_phrases"}
  {"cmd": "create_mic", "name": "VirtualMic"}
  {"cmd": "delete_mic", "name": "VirtualMic"}
  {"cmd": "list_mics"}
  {"cmd": "load"}
  {"cmd": "unload"}
  {"cmd": "quit"}

Python → QML события:
  {"event": "ready"}
  {"event": "status_msg", "msg": "..."}
  {"event": "tts_start"}
  {"event": "tts_done", "duration": 2.3, "saved_path": "/path/or/null"}
  {"event": "tts_error", "msg": "..."}
  {"event": "rt_started"}
  {"event": "rt_stopped"}
  {"event": "rt_error", "msg": "..."}
  {"event": "unloaded"}
  {"event": "phrases_list", "phrases": [{"filename": "...", "text": "...", "duration": 5.1}]}
  {"event": "mics_list", "mics": ["VirtualMic", "VirtualMic2"]}
  {"event": "mic_created", "name": "VirtualMic"}
  {"event": "mic_deleted", "name": "VirtualMic"}
  {"event": "mic_error", "msg": "..."}
  {"event": "voice_changed"}
"""

import sys
import os
import json
import argparse
import threading
import tempfile
import subprocess
import time
import traceback
import numpy as np
from pathlib import Path

_log = open("/tmp/voicechanger.log", "w", buffering=1)
sys.stderr = _log

# ── Конфигурация ──────────────────────────────────────────────────────────────

VIRTUAL_MIC  = "VirtualMic"
SPEAKER_SINK = "@DEFAULT_SINK@"
RT_BLOCK     = 512
RT_SR        = 16000

# ── Состояние ─────────────────────────────────────────────────────────────────

state = {
    "tts_busy":       False,
    "rt_active":      False,
    "mic_volume":     2.0,
    "speaker_volume": 1.0,
}

tts_model     = None
voice_prompt  = None
current_wav   = None
current_txt   = None
rt_stop_event = threading.Event()

phrases_dir = Path("/home/thedocingeast/.config/quickshell/phrases")
voices_dir  = Path("/home/thedocingeast/.config/quickshell/voice")

# ── Протокол ──────────────────────────────────────────────────────────────────

def emit(event: dict):
    print(json.dumps(event, ensure_ascii=False), flush=True)

# ── TTS ───────────────────────────────────────────────────────────────────────

def load_tts(wav_path: str, txt: str):
    global tts_model, voice_prompt, current_wav, current_txt
    try:
        import torch
        emit({"event": "status_msg", "msg": "Загрузка TTS модели..."})
        print(f"[vc] load_tts: {wav_path}", file=sys.stderr)

        try:
            from qwen_tts import Qwen3TTSModel
        except ImportError as e:
            raise RuntimeError(f"qwen_tts не установлен: {e}")

        if tts_model is None:
            tts_model = Qwen3TTSModel.from_pretrained(
                "Qwen/Qwen3-TTS-12Hz-1.7B-Base",
                device_map="cuda",
                dtype=torch.float16,
            )
            print("[vc] model loaded", file=sys.stderr)

        emit({"event": "status_msg", "msg": "Запекание голоса..."})

        if not Path(wav_path).exists():
            raise RuntimeError(f"WAV не найден: {wav_path}")

        voice_prompt = tts_model.create_voice_clone_prompt(
            ref_audio=wav_path,
            ref_text=txt,
        )
        current_wav = wav_path
        current_txt = txt
        torch.cuda.empty_cache()
        print("[vc] voice prompt ready", file=sys.stderr)
        emit({"event": "ready"})
    except Exception as e:
        print(f"[vc] load_tts ERROR: {traceback.format_exc()}", file=sys.stderr)
        emit({"event": "tts_error", "msg": str(e)})


def set_voice(wav_path: str, txt: str):
    """Сменить голос без перезагрузки модели."""
    global voice_prompt, current_wav, current_txt
    if tts_model is None:
        emit({"event": "tts_error", "msg": "Модель не загружена"})
        return

    def _run():
        try:
            import torch
            emit({"event": "status_msg", "msg": "Запекание нового голоса..."})
            if not Path(wav_path).exists():
                raise RuntimeError(f"WAV не найден: {wav_path}")
            voice_prompt = tts_model.create_voice_clone_prompt(
                ref_audio=wav_path,
                ref_text=txt,
            )
            current_wav = wav_path
            current_txt = txt
            torch.cuda.empty_cache()
            emit({"event": "voice_changed"})
            emit({"event": "status_msg", "msg": "Готов"})
        except Exception as e:
            emit({"event": "tts_error", "msg": str(e)})

    threading.Thread(target=_run, daemon=True).start()


def do_tts(text: str, mic_volume: float, save_path: str = None):
    global state
    if state["tts_busy"]:
        emit({"event": "tts_error", "msg": "TTS уже занят"})
        return
    if tts_model is None or voice_prompt is None:
        emit({"event": "tts_error", "msg": "Модель не загружена"})
        return
    state["tts_busy"] = True
    emit({"event": "tts_start"})

    def _run():
        import torch
        import soundfile as sf
        saved = None
        try:
            with torch.inference_mode():
                wavs, sr = tts_model.generate_voice_clone(
                    text=text,
                    language="Russian",
                    voice_clone_prompt=voice_prompt,
                    speech_rate=0.6,
                    temperature=0.45,
                )

            audio = wavs[0]
            if hasattr(audio, "numpy"):
                audio = audio.numpy()

            pad = np.zeros(int(sr * 0.5), dtype=audio.dtype)
            audio = np.concatenate([audio, pad])
            duration = len(audio) / sr

            # Сохраняем если указан путь
            if save_path:
                phrases_dir.mkdir(parents=True, exist_ok=True)
                out = phrases_dir / save_path
                sf.write(str(out), audio, sr)
                saved = str(out)
                print(f"[vc] phrase saved: {saved}", file=sys.stderr)

            # Воспроизводим через tmp
            tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
            sf.write(tmp.name, audio, sr)
            _play_to_mic(tmp.name, mic_volume, sr,
                         1 if audio.ndim == 1 else audio.shape[1],
                         state["speaker_volume"])
            Path(tmp.name).unlink(missing_ok=True)
            torch.cuda.empty_cache()
            emit({"event": "tts_done", "duration": round(duration, 2), "saved_path": saved})
        except Exception as e:
            emit({"event": "tts_error", "msg": str(e)})
        finally:
            state["tts_busy"] = False

    threading.Thread(target=_run, daemon=True).start()


def _play_to_mic(wav_path: str, mic_volume: float, sr: int, channels: int, speaker_volume: float = 1.0):
    def _send(device, volume):
        cmd_ff = ["ffmpeg", "-y", "-i", wav_path,
                  "-filter:a", f"volume={volume}",
                  "-f", "f32le", "-ar", str(sr), "-ac", str(channels), "pipe:1"]
        cmd_pa = ["pacat", "--playback",
                  f"--rate={sr}", f"--channels={channels}",
                  "--format=float32le", f"--device={device}"]
        try:
            pff = subprocess.Popen(cmd_ff, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
            ppa = subprocess.Popen(cmd_pa, stdin=pff.stdout,
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            pff.stdout.close()
            ppa.wait()
        except Exception as e:
            print(f"[vc] play error ({device}): {e}", file=sys.stderr)

    t_mic = threading.Thread(target=_send, args=(VIRTUAL_MIC, mic_volume), daemon=True)
    t_spk = threading.Thread(target=_send, args=(SPEAKER_SINK, speaker_volume), daemon=True)
    t_mic.start(); t_spk.start()
    t_mic.join();  t_spk.join()

# ── Фразы ─────────────────────────────────────────────────────────────────────

def list_phrases():
    phrases_dir.mkdir(parents=True, exist_ok=True)
    result = []
    meta_file = phrases_dir / "phrases.json"
    meta = {}
    if meta_file.exists():
        try:
            meta = json.loads(meta_file.read_text())
        except Exception:
            pass

    for wav in sorted(phrases_dir.glob("*.wav")):
        info = meta.get(wav.name, {})
        # Длина через ffprobe
        try:
            out = subprocess.check_output(
                ["ffprobe", "-v", "quiet", "-show_entries", "format=duration",
                 "-of", "default=noprint_wrappers=1:nokey=1", str(wav)],
                stderr=subprocess.DEVNULL
            )
            dur = round(float(out.strip()), 1)
        except Exception:
            dur = 0.0
        result.append({
            "filename": wav.name,
            "text": info.get("text", ""),
            "duration": dur,
        })
    emit({"event": "phrases_list", "phrases": result})


def save_phrase_meta(filename: str, text: str):
    meta_file = phrases_dir / "phrases.json"
    meta = {}
    if meta_file.exists():
        try:
            meta = json.loads(meta_file.read_text())
        except Exception:
            pass
    meta[filename] = {"text": text}
    meta_file.write_text(json.dumps(meta, ensure_ascii=False, indent=2))


def delete_phrase(filename: str):
    f = phrases_dir / filename
    if f.exists():
        f.unlink()
    # Убираем из meta
    meta_file = phrases_dir / "phrases.json"
    if meta_file.exists():
        try:
            meta = json.loads(meta_file.read_text())
            meta.pop(filename, None)
            meta_file.write_text(json.dumps(meta, ensure_ascii=False, indent=2))
        except Exception:
            pass
    list_phrases()

# ── VirtualMic (PipeWire null sink) ───────────────────────────────────────────

def list_mics():
    try:
        out = subprocess.check_output(
            ["pactl", "list", "sinks", "short"],
            stderr=subprocess.DEVNULL
        ).decode()
        mics = []
        for line in out.splitlines():
            parts = line.split()
            if len(parts) >= 2:
                name = parts[1]
                if name not in ("@DEFAULT_SINK@",) and "null" in name.lower() or "_mic" in name.lower() or "virtual" in name.lower():
                    mics.append(name)
        emit({"event": "mics_list", "mics": mics})
    except Exception as e:
        emit({"event": "mic_error", "msg": str(e)})


def create_mic(name: str):
    try:
        subprocess.run(
            ["pactl", "load-module", "module-null-sink",
             f"sink_name={name}",
             f"sink_properties=device.description={name}"],
            check=True, capture_output=True
        )
        emit({"event": "mic_created", "name": name})
        list_mics()
    except subprocess.CalledProcessError as e:
        emit({"event": "mic_error", "msg": e.stderr.decode().strip()})
    except Exception as e:
        emit({"event": "mic_error", "msg": str(e)})


def delete_mic(name: str):
    try:
        # Найти module index для этого sink
        out = subprocess.check_output(
            ["pactl", "list", "modules", "short"],
            stderr=subprocess.DEVNULL
        ).decode()
        idx = None
        for line in out.splitlines():
            if "module-null-sink" in line and name in line:
                idx = line.split()[0]
                break
        if idx:
            subprocess.run(["pactl", "unload-module", idx], check=True, capture_output=True)
            emit({"event": "mic_deleted", "name": name})
        else:
            emit({"event": "mic_error", "msg": f"Sink '{name}' не найден"})
        list_mics()
    except Exception as e:
        emit({"event": "mic_error", "msg": str(e)})

# ── Realtime ──────────────────────────────────────────────────────────────────

def rt_start():
    global state
    if state["rt_active"]:
        return
    state["rt_active"] = True
    rt_stop_event.clear()
    emit({"event": "rt_started"})

    def _run():
        try:
            import sounddevice as sd
            audio_buf = []
            last_process = time.time()
            PROCESS_INTERVAL = 1.5

            def _cb(indata, frames, time_info, status):
                audio_buf.append(indata.copy())

            with sd.InputStream(samplerate=RT_SR, channels=1, dtype="float32",
                                blocksize=RT_BLOCK, callback=_cb):
                while not rt_stop_event.is_set():
                    time.sleep(0.1)
                    now = time.time()
                    if now - last_process >= PROCESS_INTERVAL and audio_buf:
                        chunk = np.concatenate(audio_buf)
                        audio_buf.clear()
                        last_process = now
                        _rt_convert_chunk(chunk, RT_SR)
        except Exception as e:
            emit({"event": "rt_error", "msg": str(e)})
        finally:
            state["rt_active"] = False
            emit({"event": "rt_stopped"})

    threading.Thread(target=_run, daemon=True).start()


def _rt_convert_chunk(audio: np.ndarray, sr: int):
    try:
        import soundfile as sf
        tmp_in  = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
        tmp_out = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
        sf.write(tmp_in.name, audio, sr)
        subprocess.run([
            "ffmpeg", "-y", "-i", tmp_in.name,
            "-filter:a", "asetrate=16000*1.3,aresample=16000,atempo=0.77",
            tmp_out.name,
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        _play_to_mic(tmp_out.name, state["mic_volume"], sr, 1, state["speaker_volume"])
        Path(tmp_in.name).unlink(missing_ok=True)
        Path(tmp_out.name).unlink(missing_ok=True)
    except Exception as e:
        emit({"event": "rt_error", "msg": str(e)})


def rt_stop():
    rt_stop_event.set()

# ── Выгрузка ──────────────────────────────────────────────────────────────────

def unload_tts():
    global tts_model, voice_prompt
    if tts_model is None:
        return
    try:
        import torch
        del tts_model, voice_prompt
        tts_model = None
        voice_prompt = None
        torch.cuda.empty_cache()
        print("[vc] model unloaded", file=sys.stderr)
        emit({"event": "unloaded"})
    except Exception as e:
        print(f"[vc] unload error: {e}", file=sys.stderr)

# ── Главный цикл ──────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--wav", required=True)
    parser.add_argument("--txt", required=True)
    args = parser.parse_args()

    threading.Thread(target=load_tts, args=(args.wav, args.txt), daemon=True).start()

    import select
    print("[vc] main loop started", file=sys.stderr)

    while True:
        try:
            ready, _, _ = select.select([sys.stdin], [], [], 0.5)
        except Exception as e:
            print(f"[vc] select error: {e}", file=sys.stderr)
            break

        if not ready:
            continue

        line = sys.stdin.readline()
        if not line:
            print("[vc] stdin EOF", file=sys.stderr)
            break
        line = line.strip()
        if not line:
            continue

        print(f"[vc] cmd: {line}", file=sys.stderr)
        try:
            cmd = json.loads(line)
        except json.JSONDecodeError:
            continue

        action = cmd.get("cmd", "")

        if action == "tts":
            do_tts(
                cmd.get("text", ""),
                cmd.get("mic_volume", state["mic_volume"]),
                cmd.get("save_as"),  # None если не нужно сохранять
            )
        elif action == "rt_start":
            rt_start()
        elif action == "rt_stop":
            rt_stop()
        elif action == "set_mic_volume":
            state["mic_volume"] = float(cmd.get("volume", 2.0))
        elif action == "set_speaker_volume":
            state["speaker_volume"] = float(cmd.get("volume", 1.0))
        elif action == "set_voice":
            set_voice(cmd.get("wav", ""), cmd.get("txt", ""))
        elif action == "save_phrase":
            # Сохранить метаданные фразы (wav уже сохранён через tts с save_as)
            save_phrase_meta(cmd.get("filename", ""), cmd.get("text", ""))
            list_phrases()
        elif action == "delete_phrase":
            delete_phrase(cmd.get("filename", ""))
        elif action == "list_phrases":
            list_phrases()
        elif action == "create_mic":
            create_mic(cmd.get("name", "VirtualMic"))
        elif action == "delete_mic":
            delete_mic(cmd.get("name", ""))
        elif action == "list_mics":
            list_mics()
        elif action == "load":
            if tts_model is None:
                threading.Thread(target=load_tts, args=(args.wav, args.txt), daemon=True).start()
        elif action == "unload":
            if not state["tts_busy"] and not state["rt_active"]:
                unload_tts()
        elif action == "quit":
            rt_stop()
            unload_tts()
            break

    print("[vc] exit", file=sys.stderr)


if __name__ == "__main__":
    main()
