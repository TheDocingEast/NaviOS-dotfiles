// WallpaperApi.qml
// Запускает wallpaper_search.py через Process и читает JSON из stdout.
//
// Использование в shell.qml:
//   WallpaperApi { id: api; shellDir: Quickshell.shellDir }
//   api.search("Nord dark forest")
//   // результаты в api.model: { apiThumb, apiUrl, apiTitle, apiPage }

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // Директория шелла — сюда кладём wallpaper_search.py
    property string shellDir: ""

    // Выходная модель — { apiThumb, apiUrl, apiTitle, apiPage }
    property ListModel model: ListModel {}

    property bool   loading:   false
    property string lastQuery: ""

    signal searchStarted()
    signal searchFinished()
    signal errorOccurred(string msg)

    // Внутренний буфер для сборки stdout
    property string _buf: ""

    property var _proc: Process {
        id: searchProc

        stdout: SplitParser {
            onRead: function(line) {
                root._buf += line + "\n";
            }
        }

        // stderr для отладки — выводим в консоль
        stderr: SplitParser {
            onRead: function(line) {
                if (line.trim() !== "")
                    console.warn("[WallpaperApi] stderr:", line);
            }
        }

        onRunningChanged: {
            if (running) return;

            const raw = root._buf.trim();
            root._buf   = "";
            root.loading = false;

            if (raw === "") {
                root.errorOccurred("Пустой ответ от скрипта");
                root.searchFinished();
                return;
            }

            try {
                const data = JSON.parse(raw);

                if (!Array.isArray(data)) {
                    root.errorOccurred(data.error || "Неизвестная ошибка");
                    root.searchFinished();
                    return;
                }

                if (data.length === 0) {
                    root.errorOccurred("Ничего не найдено");
                    root.searchFinished();
                    return;
                }

                root.model.clear();
                data.forEach(function(item) {
                    root.model.append({
                        "apiThumb": item.thumb || "",
                        "apiUrl":   item.url   || item.thumb || "",
                        "apiTitle": item.title || "",
                        "apiPage":  item.page  || ""
                    });
                });
            } catch(e) {
                root.errorOccurred("JSON: " + e.toString());
            }

            root.searchFinished();
        }
    }

    function search(query) {
        const q = query.trim();
        if (q === "" || loading) return;

        lastQuery = q;
        _buf      = "";
        loading   = true;
        model.clear();
        searchStarted();

        searchProc.command = [
            "python3",
            shellDir + "/wallpaper_search.py",
            q
        ];
        searchProc.running = true;
    }
}
