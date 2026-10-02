import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

// Merged clock + date + weather bar widget, styled after the stock DMS clock
// (stacked digit pairs, hairline divider, accent-colored date) with the
// stock weather look (icon + temperature) appended below.
// Left click  -> DankDash overview tab (calendar), same as the old clock.
// Right click -> DankDash weather tab, same as the old weather widget.
PluginComponent {
    id: root

    pillClickAction: () => Quickshell.execDetached(["dms", "ipc", "call", "dash", "toggle", "overview"])
    pillRightClickAction: () => Quickshell.execDetached(["dms", "ipc", "call", "dash", "toggle", "weather"])

    // ---------- time ----------
    property date now: new Date()

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    readonly property real textSize: Theme.barTextSize(barThickness, barConfig?.fontScale, barConfig?.maximizeWidgetText)
    readonly property real digitWidth: Math.round(textSize * 0.6)
    readonly property int iconSize: Theme.barIconSize(barThickness, -6, barConfig?.maximizeWidgetIcons, barConfig?.iconScale)

    readonly property string hoursText: {
        const h = root.now.getHours();
        if (SettingsData.use24HourClock)
            return String(h).padStart(2, "0");
        const h12 = h === 0 ? 12 : (h > 12 ? h - 12 : h);
        return SettingsData.padHours12Hour ? String(h12).padStart(2, "0") : String(h12);
    }
    readonly property string minutesText: String(root.now.getMinutes()).padStart(2, "0")

    readonly property string ampmText: {
        if (SettingsData.use24HourClock)
            return "";
        return root.now.getHours() >= 12 ? " PM" : " AM";
    }

    // vertical mode always pads to two digits so the cells stay aligned
    readonly property string hoursTextPadded: {
        const h = root.now.getHours();
        if (SettingsData.use24HourClock)
            return String(h).padStart(2, "0");
        const h12 = h === 0 ? 12 : (h > 12 ? h - 12 : h);
        return String(h12).padStart(2, "0");
    }

    // locale-aware date order (same rule as the stock clock)
    readonly property bool dateFirst: {
        const fmt = I18n.locale().dateFormat(Locale.ShortFormat);
        return fmt.indexOf("d") < fmt.indexOf("M");
    }
    readonly property string dateMonth: String(root.now.getMonth() + 1).padStart(2, "0")
    readonly property string dateDay: String(root.now.getDate()).padStart(2, "0")
    readonly property string datePairA: root.dateFirst ? root.dateDay : root.dateMonth
    readonly property string datePairB: root.dateFirst ? root.dateMonth : root.dateDay
    readonly property string dateFlat: root.dateFirst ? (root.dateDay + "-" + root.dateMonth) : (root.dateMonth + "-" + root.dateDay)

    // ---------- weather ----------
    readonly property bool weatherOn: SettingsData.weatherEnabled
    readonly property bool weatherReady: WeatherService.weather?.available ?? false
    readonly property string weatherIcon: WeatherService.getWeatherIcon(WeatherService.weather?.wCode ?? 0)
    readonly property string weatherTempShort: root.weatherReady ? String(WeatherService.weather.temp) : "--"
    readonly property string weatherTempFull: root.weatherReady ? WeatherService.currentTempText(false) : "--"

    Component.onCompleted: WeatherService.addRef()
    Component.onDestruction: WeatherService.removeRef()

    // one split-flap style digit cell, fixed width to avoid jitter
    component DigitCell: StyledText {
        required property string value
        text: value
        font.pixelSize: root.textSize
        color: Theme.widgetTextColor
        width: root.digitWidth
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignBottom
    }

    // ---------- bar pills ----------
    verticalBarPill: Component {
        Column {
            spacing: 0

            Row {
                spacing: 0
                anchors.horizontalCenter: parent.horizontalCenter
                DigitCell { value: root.hoursTextPadded.charAt(0) }
                DigitCell { value: root.hoursTextPadded.charAt(1) }
            }

            Row {
                spacing: 0
                anchors.horizontalCenter: parent.horizontalCenter
                DigitCell { value: root.minutesText.charAt(0) }
                DigitCell { value: root.minutesText.charAt(1) }
            }

            Item {
                width: root.digitWidth * 2
                height: Theme.spacingM
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    width: parent.width * 0.6
                    height: 1
                    color: Theme.outlineButton
                    anchors.centerIn: parent
                }
            }

            Row {
                spacing: 0
                anchors.horizontalCenter: parent.horizontalCenter
                DigitCell { value: root.datePairA.charAt(0); color: Theme.primary }
                DigitCell { value: root.datePairA.charAt(1); color: Theme.primary }
            }

            Row {
                spacing: 0
                anchors.horizontalCenter: parent.horizontalCenter
                DigitCell { value: root.datePairB.charAt(0); color: Theme.primary }
                DigitCell { value: root.datePairB.charAt(1); color: Theme.primary }
            }

            Item {
                width: 1
                height: Theme.spacingS
                visible: root.weatherOn
            }

            DankIcon {
                name: root.weatherIcon
                size: root.iconSize
                color: Theme.widgetIconColor
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.weatherOn
            }

            StyledText {
                text: root.weatherTempShort
                font.pixelSize: root.textSize
                color: Theme.widgetTextColor
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.weatherOn
            }
        }
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS

            StyledText {
                text: root.hoursText + ":" + root.minutesText + root.ampmText
                font.pixelSize: root.textSize
                color: Theme.widgetTextColor
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: "•"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.outlineButton
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.dateFlat
                font.pixelSize: root.textSize
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }

            Item {
                width: Theme.spacingS
                height: 1
                visible: root.weatherOn
            }

            DankIcon {
                name: root.weatherIcon
                size: root.iconSize
                color: Theme.widgetIconColor
                anchors.verticalCenter: parent.verticalCenter
                visible: root.weatherOn
            }

            StyledText {
                text: root.weatherTempFull
                font.pixelSize: root.textSize
                color: Theme.widgetTextColor
                anchors.verticalCenter: parent.verticalCenter
                visible: root.weatherOn
            }
        }
    }
}
