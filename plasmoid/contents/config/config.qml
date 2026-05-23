import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
         name: i18nc("@title", "General")
         icon: "preferences-desktop-navigation"
         source: "../ui/config.qml"
    }
}
