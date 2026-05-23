import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
         name: i18nc("@title", "Settings")
         icon: "preferences-desktop-navigation"
         source: "../ui/config.qml"
    }
}
