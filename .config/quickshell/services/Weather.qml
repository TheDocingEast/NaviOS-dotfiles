import QtQuick

Item {
    id: root

    property real latitude: 0
    property real longitude: 0
    property string cityName: "--"
    property string country: "--"
    property string temperature: "--"
    property string humidity: "--"
    property string windSpeed: "--"
    property string icon: "?"

    // ── Step 1: get location from IP ───────────────────────────────────
    function fetchLocation() {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", "http://ip-api.com/json/");
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status !== 200) {
                console.warn("ip-api failed:", xhr.status);
                return;
            }
            const d = JSON.parse(xhr.responseText);

            // ip-api returns a "status" field: "success" or "fail"
            if (d.status !== "success") {
                console.warn("ip-api error:", d.message);
                return;
            }

            latitude = d.lat;
            longitude = d.lon;
            cityName = d.city;
            country = d.country;

            console.log(`Location: ${cityName}, ${country} (${latitude}, ${longitude})`);
            fetchWeather();
        };
        xhr.send();
    }

    // ── Step 2: fetch weather using those coords ────────────────────────
    function fetchWeather() {
        const url = `https://api.open-meteo.com/v1/forecast` + `?latitude=${latitude}&longitude=${longitude}` + `&current=temperature_2m,relative_humidity_2m,` + `wind_speed_10m,weather_code`;

        const xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status !== 200) {
                console.warn("Weather fetch failed:", xhr.status);
                return;
            }
            const d = JSON.parse(xhr.responseText).current;
            temperature = Math.round(d.temperature_2m) + "°C";
            humidity = d.relative_humidity_2m + "%";
            windSpeed = d.wind_speed_10m + " m/s";
            icon = wmoIcon(d.weather_code);
        };
        xhr.send();
    }

    // ── WMO code → emoji ───────────────────────────────────────────────
    function wmoIcon(code) {
        if (code === 0)
            return "☀️";
        if (code <= 2)
            return "⛅";
        if (code === 3)
            return "☁️";
        if (code >= 51 && code <= 67)
            return "🌧️";
        if (code >= 71 && code <= 77)
            return "❄️";
        if (code >= 80 && code <= 82)
            return "🌦️";
        if (code >= 95)
            return "⛈️";
        return "🌡️";
    }

    // ── Startup + periodic refresh ─────────────────────────────────────
    Component.onCompleted: fetchLocation()

    // Re-fetch location once per hour (IP rarely changes)
    Timer {
        interval: 60 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.fetchLocation()
    }

    // Re-fetch weather every 10 minutes
    Timer {
        interval: 10 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.fetchWeather()
    }
}
