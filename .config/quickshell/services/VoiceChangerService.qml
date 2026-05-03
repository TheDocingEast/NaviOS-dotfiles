// services/VoiceChangerService.qml
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ── Состояние процесса ────────────────────────────────────────────────
    property bool   vcReady:         false
    property bool   vcBusy:          false
    property bool   vcRtActive:      false
    property bool   vcLoaded:        false
    property real   vcMicVolume:     2.0
    property real   vcSpeakerVolume: 1.0
    property string vcStatus:        "Не загружен"

    // ── Голоса ────────────────────────────────────────────────────────────
    // Список голосов читается из voice/voices.json
    // Формат: [{"name": "BT-7274", "wav": "/path/to/bt.wav", "txt": "текст..."}]
    property var    voicesList:      []
    property int    currentVoiceIdx: 0

    // ── Фразы ─────────────────────────────────────────────────────────────
    property var    phrasesList:     []   // [{filename, text, duration}]

    // ── VirtualMic ────────────────────────────────────────────────────────
    property var    micsList:        []

    // ── Сигналы для UI ────────────────────────────────────────────────────
    signal phrasesUpdated()
    signal micsUpdated()
    signal voiceChanged()

    // ── Пути ──────────────────────────────────────────────────────────────
    readonly property string voicesJsonPath: Quickshell.env("HOME") + "/.config/quickshell/voice/voices.json"
    readonly property string phrasesDir:     Quickshell.env("HOME") + "/.config/quickshell/phrases/"

    // ── Публичное API ─────────────────────────────────────────────────────

    function load() {
        if (!vcProcess.running) {
            vcProcess.running = true;
            root.vcStatus = "Запуск процесса...";
        } else {
            send({ cmd: "load" });
            root.vcStatus = "Загрузка модели...";
        }
    }

    function unload() {
        if (!vcProcess.running) return;
        if (root.vcBusy || root.vcRtActive) return;
        send({ cmd: "quit" });
        vcKillTimer.restart();
    }

    function send(obj) {
        if (vcProcess.running)
            vcProcess.write(JSON.stringify(obj) + "\n");
    }

    function selectVoice(idx) {
        if (idx < 0 || idx >= voicesList.length) return;
        currentVoiceIdx = idx;
        var v = voicesList[idx];
        send({ cmd: "set_voice", wav: v.wav, txt: v.txt });
    }

    function tts(text, saveAs) {
        var obj = { cmd: "tts", text: text, mic_volume: vcMicVolume };
        if (saveAs) obj.save_as = saveAs;
        send(obj);
    }

    function savePhrase(filename, text) {
        send({ cmd: "save_phrase", filename: filename, text: text });
    }

    function deletePhrase(filename) {
        send({ cmd: "delete_phrase", filename: filename });
    }

    function refreshPhrases() {
        send({ cmd: "list_phrases" });
    }

    function createMic(name) {
        send({ cmd: "create_mic", name: name });
    }

    function deleteMic(name) {
        send({ cmd: "delete_mic", name: name });
    }

    function refreshMics() {
        send({ cmd: "list_mics" });
    }

    // Загрузить список голосов из voices.json
    function loadVoicesList() {
        voicesLoader.active = false;
        voicesLoader.active = true;
    }

    // ── Загрузчик voices.json ─────────────────────────────────────────────
    FileView {
        id: voicesLoader
        path: root.voicesJsonPath
        blockLoading: true
        watchChanges: true
        // text() — функция, не property. onFileChanged срабатывает при изменении файла.
        onFileChanged: {
            try {
                var arr = JSON.parse(voicesLoader.text());
                if (Array.isArray(arr)) root.voicesList = arr;
            } catch(e) {
                root.voicesList = [];
            }
        }
        Component.onCompleted: {
            try {
                var arr = JSON.parse(voicesLoader.text());
                if (Array.isArray(arr)) root.voicesList = arr;
            } catch(e) {
                root.voicesList = [];
            }
        }
    }

    // ── Kill timer ────────────────────────────────────────────────────────
    Timer {
        id: vcKillTimer
        interval: 2000
        repeat: false
        onTriggered: vcProcess.signal(9)
    }

    // ── Backend process ───────────────────────────────────────────────────
    Process {
        id: vcProcess

        stdinEnabled: true

        command: {
            var voices = root.voicesList;
            var v = (voices && voices.length > 0) ? voices[root.currentVoiceIdx] : null;
            var wav = v ? v.wav : Quickshell.env("HOME") + "/.config/quickshell/voice/bt.wav";
            var txt = v ? v.txt : "Пилот Силы АМС продолжит нас искать, чтобы выжить нужно встретиться с майором Андерсоном в 60 километрах от нашего местоположения.";
            return [
                Quickshell.env("HOME") + "/miniforge3/envs/Auri/bin/python",
                "-u",
                Quickshell.env("HOME") + "/.config/quickshell/services/voice_changer.py",
                "--wav", wav,
                "--txt", txt
            ];
        }

        running: false

        onRunningChanged: {
            if (!running) {
                root.vcLoaded  = false;
                root.vcReady   = false;
                root.vcStatus  = "Выгружен";
                vcKillTimer.stop();
            } else {
                // После запуска запрашиваем списки
                refreshMicsTimer.restart();
            }
        }

        stdout: SplitParser {
            onRead: line => {
                try {
                    var ev = JSON.parse(line);
                    switch (ev.event) {
                        case "ready":
                            root.vcReady  = true;
                            root.vcLoaded = true;
                            root.vcBusy   = false;
                            root.vcStatus = "Готов";
                            root.refreshPhrases();
                            root.refreshMics();
                            break;
                        case "status_msg":
                            root.vcStatus = ev.msg;
                            break;
                        case "tts_start":
                            root.vcBusy   = true;
                            root.vcStatus = "Генерация...";
                            break;
                        case "tts_done":
                            root.vcBusy   = false;
                            root.vcStatus = "Готово (" + ev.duration + "с)";
                            break;
                        case "tts_error":
                            root.vcBusy   = false;
                            root.vcStatus = "Ошибка: " + ev.msg;
                            break;
                        case "rt_started":
                            root.vcRtActive = true;
                            root.vcStatus   = "Realtime активен";
                            break;
                        case "rt_stopped":
                            root.vcRtActive = false;
                            root.vcStatus   = "Готов";
                            break;
                        case "rt_error":
                            root.vcRtActive = false;
                            root.vcStatus   = "RT ошибка: " + ev.msg;
                            break;
                        case "unloaded":
                            root.vcReady  = false;
                            root.vcLoaded = false;
                            root.vcStatus = "Выгружен";
                            break;
                        case "voice_changed":
                            root.vcStatus = "Голос изменён";
                            root.voiceChanged();
                            break;
                        case "phrases_list":
                            root.phrasesList = ev.phrases || [];
                            root.phrasesUpdated();
                            break;
                        case "mics_list":
                            root.micsList = ev.mics || [];
                            root.micsUpdated();
                            break;
                        case "mic_created":
                            root.vcStatus = "Микрофон создан: " + ev.name;
                            break;
                        case "mic_deleted":
                            root.vcStatus = "Микрофон удалён: " + ev.name;
                            break;
                        case "mic_error":
                            root.vcStatus = "Mic ошибка: " + ev.msg;
                            break;
                    }
                } catch (e) {}
            }
        }
    }

    // Небольшая задержка перед запросом списков сразу после запуска процесса
    Timer {
        id: refreshMicsTimer
        interval: 500
        repeat: false
        onTriggered: root.refreshMics()
    }
}
