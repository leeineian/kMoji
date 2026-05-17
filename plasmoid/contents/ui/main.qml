import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    Plasmoid.icon: "preferences-desktop-emoticons-symbolic"
    preferredRepresentation: compactRepresentation
    hideOnWindowDeactivate: !plasmoid.configuration.AlwaysOpen

    compactRepresentation: CompactRepresentation {
        plasmoidItem: root
    }

    fullRepresentation: PlasmaExtras.Representation {
        collapseMarginsHint: true

        Layout.minimumWidth: Kirigami.Units.gridUnit * 27
        Layout.preferredWidth: Kirigami.Units.gridUnit * 35
        Layout.preferredHeight: Kirigami.Units.gridUnit * 35

        Layout.minimumHeight: Math.max(
            Kirigami.Units.gridUnit * 24,
            fullRepresentationView
            ? fullRepresentationView.minimumRequiredHeight
            : Kirigami.Units.gridUnit * 30
        )

        FullRepresentation {
            id: fullRepresentationView
            anchors.fill: parent
            plasmoidItem: root
        }
    }
}
