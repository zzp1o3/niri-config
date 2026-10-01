import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.ProcessList

// Embedded live process list (same component the built-in process popup uses):
// sortable column headers, search, expandable rows and right-click context menu.
Item {
    id: root

    property string searchText: ""
    property string processFilter: "all"
    property bool active: false
    property var popoutRef: null

    implicitWidth: 400
    implicitHeight: 320

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Theme.nestedSurface
        clip: true

        ProcessesView {
            id: procView
            anchors.fill: parent
            anchors.margins: Theme.spacingS
            active: root.active
            searchText: root.searchText
            processFilter: root.processFilter
            contextMenu: menu
        }
    }

    ProcessContextMenu {
        id: menu
        transientSurfaceTracker: root.popoutRef?.transientSurfaceTracker ?? null
        Component.onCompleted: parent = procView
        onProcessKilled: procView.forceRefreshCount++
    }
}
