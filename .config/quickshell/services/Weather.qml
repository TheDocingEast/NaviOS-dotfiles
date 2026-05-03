// services/Weather.qml
// Singleton — один экземпляр на весь ShellRoot.
// Предоставляет: текущую погоду + 7-дневный прогноз + код страны (для Nager.Date).
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    // ── Геолокация ────────────────────────────────────────────────────────
    property real   latitude:    0
    property real   longitude:   0
    property string cityName:    "--"
    property string country:     "--"
    property string countryCode: ""   // ISO 3166-1 alpha-2, напр. "LV" — для Nager.Date

    // ── Текущая погода ────────────────────────────────────────────────────
    property string temperature: "--"
    property string humidity:    "--"
    property string windSpeed:   "--"
    property string windDir:     "--"   // направление ветра, напр. "NW"
    property string icon:        "?"
    property string description: "--"

    // ── Прогноз на 7 дней ─────────────────────────────────────────────────
    // Массив объектов: { date, icon, desc, tempMax, tempMin, windMax, precipSum }
    property var forecast: []

    // ── Флаги состояния ───────────────────────────────────────────────────
    property bool loading: false
    property bool ready:   false

    // ── Публичное API ─────────────────────────────────────────────────────
    function refresh() { fetchLocation() }

    // ── Шаг 1: геолокация по IP ───────────────────────────────────────────
    function fetchLocation() {
        root.loading = true
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "http://ip-api.com/json/")
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status !== 200) {
                console.warn("[Weather] ip-api failed:", xhr.status)
                root.loading = false
                return
            }
            try {
                var d = JSON.parse(xhr.responseText)
                if (d.status !== "success") {
                    console.warn("[Weather] ip-api error:", d.message)
                    root.loading = false
                    return
                }
                root.latitude    = d.lat
                root.longitude   = d.lon
                root.cityName    = d.city
                root.country     = d.country
                root.countryCode = d.countryCode
                fetchWeather()
            } catch(e) {
                console.warn("[Weather] ip-api parse error:", e)
                root.loading = false
            }
        }
        xhr.send()
    }

    // ── Шаг 2: текущая погода + 7-дневный прогноз (один запрос) ──────────
    function fetchWeather() {
        var url = "https://api.open-meteo.com/v1/forecast"
            + "?latitude="  + root.latitude
            + "&longitude=" + root.longitude
            + "&current=temperature_2m,relative_humidity_2m,"
            + "wind_speed_10m,wind_direction_10m,weather_code"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,"
            + "wind_speed_10m_max,precipitation_sum"
            + "&wind_speed_unit=ms"
            + "&timezone=auto"
            + "&forecast_days=7"

        var xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            root.loading = false
            if (xhr.status !== 200) {
                console.warn("[Weather] open-meteo failed:", xhr.status)
                return
            }
            try {
                var resp = JSON.parse(xhr.responseText)

                var c = resp.current
                root.temperature = Math.round(c.temperature_2m) + "°C"
                root.humidity    = c.relative_humidity_2m + "%"
                root.windSpeed   = c.wind_speed_10m.toFixed(1) + " m/s"
                root.windDir     = degToCompass(c.wind_direction_10m)
                root.icon        = wmoIcon(c.weather_code)
                root.description = wmoDescription(c.weather_code)

                var d    = resp.daily
                var days = []
                for (var i = 0; i < d.time.length; i++) {
                    days.push({
                        date:      d.time[i],
                        icon:      wmoIcon(d.weather_code[i]),
                        desc:      wmoDescription(d.weather_code[i]),
                        tempMax:   Math.round(d.temperature_2m_max[i]),
                        tempMin:   Math.round(d.temperature_2m_min[i]),
                        windMax:   d.wind_speed_10m_max[i].toFixed(1),
                        precipSum: d.precipitation_sum[i].toFixed(1)
                    })
                }
                root.forecast = days
                root.ready    = true
            } catch(e) {
                console.warn("[Weather] parse error:", e)
            }
        }
        xhr.send()
    }

    // ── Вспомогательные функции ───────────────────────────────────────────
    function degToCompass(deg) {
        var dirs = ["N","NE","E","SE","S","SW","W","NW"]
        return dirs[Math.round(deg / 45) % 8]
    }

    function wmoIcon(code) {
        if (code === 0)               return "☀️"
        if (code <= 2)                return "⛅"
        if (code === 3)               return "☁️"
        if (code >= 45 && code <= 48) return "🌫️"
        if (code >= 51 && code <= 57) return "🌦️"
        if (code >= 61 && code <= 67) return "🌧️"
        if (code >= 71 && code <= 77) return "❄️"
        if (code >= 80 && code <= 82) return "🌦️"
        if (code === 85 || code === 86) return "🌨️"
        if (code >= 95)               return "⛈️"
        return "🌡️"
    }

    function wmoDescription(code) {
        if (code === 0)               return "Clear sky"
        if (code === 1)               return "Mainly clear"
        if (code === 2)               return "Partly cloudy"
        if (code === 3)               return "Overcast"
        if (code >= 45 && code <= 48) return "Foggy"
        if (code >= 51 && code <= 55) return "Drizzle"
        if (code >= 56 && code <= 57) return "Freezing drizzle"
        if (code >= 61 && code <= 65) return "Rain"
        if (code >= 66 && code <= 67) return "Freezing rain"
        if (code >= 71 && code <= 75) return "Snowfall"
        if (code === 77)              return "Snow grains"
        if (code >= 80 && code <= 82) return "Rain showers"
        if (code >= 85 && code <= 86) return "Snow showers"
        if (code === 95)              return "Thunderstorm"
        if (code >= 96)               return "Thunderstorm + hail"
        return "Unknown"
    }

    // ── Автообновление ────────────────────────────────────────────────────
    Component.onCompleted: fetchLocation()

    Timer {
        interval: 60 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.fetchLocation()
    }

    Timer {
        interval: 10 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.fetchWeather()
    }
}
