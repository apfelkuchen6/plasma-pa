/*
    Copyright 2014-2015 Harald Sitter <sitter@kde.org>

    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License as
    published by the Free Software Foundation; either version 2 of
    the License or (at your option) version 3 or any later version
    accepted by the membership of KDE e.V. (or its successor approved
    by the membership of KDE e.V.), which shall act as a proxy
    defined in Section 14 of version 3 of the license.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

import QtQuick 2.2
import QtQuick.Layouts 1.0

import org.kde.plasma.core 2.1 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents // PC3 TabBar/TabButton need work first
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.plasma.plasmoid 2.0

import org.kde.plasma.private.volume 0.1

import "../code/icon.js" as Icon

Item {
    id: main

    property bool volumeFeedback: Plasmoid.configuration.volumeFeedback
    property bool globalMute: Plasmoid.configuration.globalMute
    property int currentMaxVolumePercent: plasmoid.configuration.raiseMaximumVolume ? 150 : 100
    property int currentMaxVolumeValue: currentMaxVolumePercent * PulseAudio.NormalVolume / 100.00
    property int volumeStep: Math.round(Plasmoid.configuration.volumeStep * PulseAudio.NormalVolume / 100.0)
    property string displayName: i18n("Audio Volume")
    property QtObject draggedStream: null

    // DEFAULT_SINK_NAME in module-always-sink.c
    readonly property string dummyOutputName: "auto_null"

    Layout.minimumHeight: PlasmaCore.Units.gridUnit * 8
    Layout.minimumWidth: PlasmaCore.Units.gridUnit * 14
    Layout.preferredHeight: PlasmaCore.Units.gridUnit * 21
    Layout.preferredWidth: PlasmaCore.Units.gridUnit * 24
    Plasmoid.switchHeight: Layout.minimumHeight
    Plasmoid.switchWidth: Layout.minimumWidth

    Plasmoid.icon: paSinkModel.preferredSink && !isDummyOutput(paSinkModel.preferredSink) ? Icon.name(paSinkModel.preferredSink.volume, paSinkModel.preferredSink.muted)
                                                                                          : Icon.name(0, true)
    Plasmoid.toolTipMainText: {
        var sink = paSinkModel.preferredSink;
        if (!sink || isDummyOutput(sink)) {
            return displayName;
        }

        if (sink.muted) {
            return i18n("Audio Muted");
        } else {
            return i18n("Volume at %1%", volumePercent(sink.volume));
        }
    }
    Plasmoid.toolTipSubText: {
        if (paSinkModel.preferredSink && !isDummyOutput(paSinkModel.preferredSink)) {
            var port = paSinkModel.preferredSink.ports[paSinkModel.preferredSink.activePortIndex];
            if (port) {
                return port.description
            }
            return paSinkModel.preferredSink.name
        }
        return ""
    }

    function isDummyOutput(output) {
        return output && output.name === dummyOutputName;
    }

    function boundVolume(volume) {
        return Math.max(PulseAudio.MinimalVolume, Math.min(volume, currentMaxVolumeValue));
    }

    function volumePercent(volume) {
        return Math.round(volume / PulseAudio.NormalVolume * 100.0);
    }

    function increaseVolume() {
        if (!paSinkModel.preferredSink || isDummyOutput(paSinkModel.preferredSink)) {
            return;
        }
        var volume = boundVolume(paSinkModel.preferredSink.volume + volumeStep);
        var percent = volumePercent(volume);
        paSinkModel.preferredSink.muted = percent == 0;
        paSinkModel.preferredSink.volume = volume;
        osd.showVolume(percent);
        playFeedback();
    }

    function decreaseVolume() {
        if (!paSinkModel.preferredSink || isDummyOutput(paSinkModel.preferredSink)) {
            return;
        }
        var volume = boundVolume(paSinkModel.preferredSink.volume - volumeStep);
        var percent = volumePercent(volume);
        paSinkModel.preferredSink.muted = percent == 0;
        paSinkModel.preferredSink.volume = volume;
        osd.showVolume(percent);
        playFeedback();
    }

    function muteVolume() {
        if (!paSinkModel.preferredSink || isDummyOutput(paSinkModel.preferredSink)) {
            return;
        }
        var toMute = !paSinkModel.preferredSink.muted;
        if (toMute) {
            enableGlobalMute();
            osd.showMute(0);
        } else {
            if (globalMute) {
                disableGlobalMute();
            }
            paSinkModel.preferredSink.muted = toMute;
            osd.showMute(volumePercent(paSinkModel.preferredSink.volume));
            playFeedback();
        }
    }

    function increaseMicrophoneVolume() {
        if (!paSourceModel.defaultSource) {
            return;
        }
        var volume = boundVolume(paSourceModel.defaultSource.volume + volumeStep);
        var percent = volumePercent(volume);
        paSourceModel.defaultSource.muted = percent == 0;
        paSourceModel.defaultSource.volume = volume;
        osd.showMic(percent);
    }

    function decreaseMicrophoneVolume() {
        if (!paSourceModel.defaultSource) {
            return;
        }
        var volume = boundVolume(paSourceModel.defaultSource.volume - volumeStep);
        var percent = volumePercent(volume);
        paSourceModel.defaultSource.muted = percent == 0;
        paSourceModel.defaultSource.volume = volume;
        osd.showMic(percent);
    }

    function muteMicrophone() {
        if (!paSourceModel.defaultSource) {
            return;
        }
        var toMute = !paSourceModel.defaultSource.muted;
        paSourceModel.defaultSource.muted = toMute;
        osd.showMicMute(toMute? 0 : volumePercent(paSourceModel.defaultSource.volume));
    }

    function playFeedback(sinkIndex) {
        if (!volumeFeedback) {
            return;
        }
        if (sinkIndex == undefined) {
            sinkIndex = paSinkModel.preferredSink.index;
        }
        feedback.play(sinkIndex);
    }


    function enableGlobalMute() {
        var role = paSinkModel.role("Muted");
        var rowCount = paSinkModel.rowCount();
        // List for devices that are already muted. Will use to keep muted after disable GlobalMute.
        var globalMuteDevices = [];

        for (var i = 0; i < rowCount; i++) {
            var idx = paSinkModel.index(i, 0);
            var name = paSinkModel.data(idx, paSinkModel.role("Name"));
            if (paSinkModel.data(idx, role) === false) {
                paSinkModel.setData(idx, true, role);
            } else {
                globalMuteDevices.push(name + "." + paSinkModel.data(idx, paSinkModel.role("ActivePortIndex")));
            }
        }
        // If all the devices were muted, will unmute them all with disable GlobalMute.
        plasmoid.configuration.globalMuteDevices = globalMuteDevices.length < rowCount ? globalMuteDevices : [];
        plasmoid.configuration.globalMute = true;
        globalMute = true;
    }

    function disableGlobalMute() {
        var role = paSinkModel.role("Muted");
        for (var i = 0; i < paSinkModel.rowCount(); i++) {
            var idx = paSinkModel.index(i, 0);
            var name = paSinkModel.data(idx, paSinkModel.role("Name")) + "." + paSinkModel.data(idx, paSinkModel.role("ActivePortIndex"));
            if (plasmoid.configuration.globalMuteDevices.indexOf(name) === -1) {
                paSinkModel.setData(idx, false, role);
            }
        }
        plasmoid.configuration.globalMuteDevices = [];
        plasmoid.configuration.globalMute = false;
        globalMute = false;
    }

    SinkModel {
        id: paSinkModel

        property bool initalDefaultSinkIsSet: false

        onDefaultSinkChanged: {
            if (!defaultSink || !plasmoid.configuration.outputChangeOsd) {
                return;
            }

            // avoid showing a OSD on startup
            if (!initalDefaultSinkIsSet) {
                initalDefaultSinkIsSet = true;
                return;
            }

            var description = defaultSink.description;
            if (isDummyOutput(defaultSink)) {
                description = i18n("No output device");
            }

            var icon = Icon.formFactorIcon(defaultSink.formFactor);
            if (!icon) {
                // Show "muted" icon for Dummy output
                if (isDummyOutput(defaultSink)) {
                    icon = "audio-volume-muted";
                }
            }

            if (!icon) {
                icon = Icon.name(defaultSink.volume, defaultSink.muted);
            }
            osd.showText(icon, description);
        }

        onRowsInserted: {
            if (globalMute) {
                var role = paSinkModel.role("Muted");
                for (var i = 0; i < paSinkModel.rowCount(); i++) {
                    var idx = paSinkModel.index(i, 0);
                    if (paSinkModel.data(idx, role) === false) {
                        paSinkModel.setData(idx, true, role);
                    }
                }
            }
        }
    }

    PulseObjectFilterModel {
        id: paSinkFilterModel
        sortRole: "SortByDefault"
        sortOrder: Qt.DescendingOrder
        filterOutInactiveDevices: true
        sourceModel: paSinkModel
    }

    SourceModel {
        id: paSourceModel
    }

    PulseObjectFilterModel {
        id: paSourceFilterModel
        sortRole: "SortByDefault"
        sortOrder: Qt.DescendingOrder
        filterOutInactiveDevices: true
        sourceModel: paSourceModel
    }

    Plasmoid.compactRepresentation: PlasmaCore.IconItem {
        source: plasmoid.icon
        active: mouseArea.containsMouse
        colorGroup: PlasmaCore.ColorScope.colorGroup

        MouseArea {
            id: mouseArea

            property int wheelDelta: 0
            property bool wasExpanded: false

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onPressed: {
                if (mouse.button == Qt.LeftButton) {
                    wasExpanded = plasmoid.expanded;
                } else if (mouse.button == Qt.MiddleButton) {
                    muteVolume();
                }
            }
            onClicked: {
                if (mouse.button == Qt.LeftButton) {
                    plasmoid.expanded = !wasExpanded;
                }
            }
            onWheel: {
                var delta = wheel.angleDelta.y || wheel.angleDelta.x;
                wheelDelta += delta;
                // Magic number 120 for common "one click"
                // See: https://qt-project.org/doc/qt-5/qml-qtquick-wheelevent.html#angleDelta-prop
                while (wheelDelta >= 120) {
                    wheelDelta -= 120;
                    increaseVolume();
                }
                while (wheelDelta <= -120) {
                    wheelDelta += 120;
                    decreaseVolume();
                }
            }
        }
    }

    GlobalActionCollection {
        // KGlobalAccel cannot transition from kmix to something else, so if
        // the user had a custom shortcut set for kmix those would get lost.
        // To avoid this we hijack kmix name and actions. Entirely mental but
        // best we can do to not cause annoyance for the user.
        // The display name actually is updated to whatever registered last
        // though, so as far as user visible strings go we should be fine.
        // As of 2015-07-21:
        //   componentName: kmix
        //   actions: increase_volume, decrease_volume, mute
        name: "kmix"
        displayName: main.displayName
        GlobalAction {
            objectName: "increase_volume"
            text: i18n("Increase Volume")
            shortcut: Qt.Key_VolumeUp
            onTriggered: increaseVolume()
        }
        GlobalAction {
            objectName: "decrease_volume"
            text: i18n("Decrease Volume")
            shortcut: Qt.Key_VolumeDown
            onTriggered: decreaseVolume()
        }
        GlobalAction {
            objectName: "mute"
            text: i18n("Mute")
            shortcut: Qt.Key_VolumeMute
            onTriggered: muteVolume()
        }
        GlobalAction {
            objectName: "increase_microphone_volume"
            text: i18n("Increase Microphone Volume")
            shortcut: Qt.Key_MicVolumeUp
            onTriggered: increaseMicrophoneVolume()
        }
        GlobalAction {
            objectName: "decrease_microphone_volume"
            text: i18n("Decrease Microphone Volume")
            shortcut: Qt.Key_MicVolumeDown
            onTriggered: decreaseMicrophoneVolume()
        }
        GlobalAction {
            objectName: "mic_mute"
            text: i18n("Mute Microphone")
            shortcut: Qt.Key_MicMute
            onTriggered: muteMicrophone()
        }
    }

    VolumeOSD {
        id: osd

        function showVolume(text) {
            if (!main.Plasmoid.configuration.volumeOsd)
                return
            show(text, currentMaxVolumePercent)
        }

        function showMute(text) {
            if (!main.Plasmoid.configuration.muteOsd)
                return
            show(text, currentMaxVolumePercent)
        }

        function showMic(text) {
            if (!main.Plasmoid.configuration.micOsd)
                return
            showMicrophone(text)
        }

        function showMicMute(text) {
            if (!main.Plasmoid.configuration.muteOsd)
                return
            showMicrophone(text)
        }
    }

    VolumeFeedback {
        id: feedback
    }

    PlasmaCore.Svg {
        id: lineSvg
        imagePath: "widgets/line"
    }

    Plasmoid.fullRepresentation: PlasmaComponents3.Page {
        Layout.preferredHeight: main.Layout.preferredHeight
        Layout.preferredWidth: main.Layout.preferredWidth

        function beginMoveStream(type, stream) {
            if (type == "sink") {
                sourceView.visible = false;
            } else if (type == "source") {
                sinkView.visible = false;
            }

            devicesLine.visible = false;
            tabBar.currentTab = devicesTab;
        }

        function endMoveStream() {
            tabBar.currentTab = streamsTab;

            sourceView.visible = true;
            devicesLine.visible = true;
            sinkView.visible = true;
        }

        header: PlasmaExtras.PlasmoidHeading {
            // Make this toolbar's buttons align vertically with the ones above
            rightPadding: -PlasmaCore.Units.devicePixelRatio

            RowLayout {
                anchors.fill: parent

                PlasmaComponents3.CheckBox {
                    id: raiseMaximumVolumeCheckbox
                    checked: plasmoid.configuration.raiseMaximumVolume
                    onToggled: {
                        plasmoid.configuration.raiseMaximumVolume = checked
                        if (!checked) {
                            for (var i = 0; i < paSinkModel.rowCount(); i++) {
                                if (paSinkModel.data(paSinkModel.index(i, 0), paSinkModel.role("Volume")) > PulseAudio.NormalVolume) {
                                    paSinkModel.setData(paSinkModel.index(i, 0), PulseAudio.NormalVolume, paSinkModel.role("Volume"));
                                }
                            }
                            for (var i = 0; i < paSourceModel.rowCount(); i++) {
                                if (paSourceModel.data(paSourceModel.index(i, 0), paSourceModel.role("Volume")) > PulseAudio.NormalVolume) {
                                    paSourceModel.setData(paSourceModel.index(i, 0), PulseAudio.NormalVolume, paSourceModel.role("Volume"));
                                }
                            }
                        }
                    }
                    text: i18n("Raise maximum volume")
                }

                Item {
                    Layout.fillWidth: true
                }

                PlasmaComponents3.ToolButton {
                    id: globalMuteCheckbox

                    visible: !(plasmoid.containmentDisplayHints & PlasmaCore.Types.ContainmentDrawsPlasmoidHeading)

                    icon.name: "audio-volume-muted"
                    onClicked: {
                        if (!globalMute) {
                            enableGlobalMute();
                        } else {
                            disableGlobalMute();
                        }
                    }
                    checked: globalMute

                    Accessible.name: i18n("Force mute all playback devices")
                    PlasmaComponents3.ToolTip {
                        text: i18n("Force mute all playback devices")
                    }
                }

                PlasmaComponents3.ToolButton {
                    visible: !(plasmoid.containmentDisplayHints & PlasmaCore.Types.ContainmentDrawsPlasmoidHeading)

                    icon.name: "configure"
                    onClicked: plasmoid.action("configure").trigger()

                    Accessible.name: plasmoid.action("configure").text
                    PlasmaComponents3.ToolTip {
                        text: plasmoid.action("configure").text
                    }
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent

            PlasmaExtras.ScrollArea {
                id: scrollView

                Layout.fillWidth: true
                Layout.fillHeight: true

                horizontalScrollBarPolicy: Qt.ScrollBarAlwaysOff
                flickableItem.boundsBehavior: Flickable.StopAtBounds;

                //our scroll isn't a list of delegates, all internal items are tab focussable, making this redundant
                activeFocusOnTab: false

                Item {
                    width: streamsView.visible ? streamsView.width : devicesView.width
                    height: streamsView.visible ? streamsView.height : devicesView.height

                    ColumnLayout {
                        id: streamsView
                        spacing: 0
                        visible: tabBar.currentTab == streamsTab
                        property int maximumWidth: scrollView.viewport.width
                        width: maximumWidth
                        Layout.maximumWidth: maximumWidth

                        ListView {
                            id: sinkInputView

                            Layout.fillWidth: true
                            Layout.minimumHeight: contentHeight
                            Layout.maximumHeight: contentHeight

                            model: PulseObjectFilterModel {
                                filters: [ { role: "VirtualStream", value: false } ]
                                sourceModel: SinkInputModel {}
                            }
                            boundsBehavior: Flickable.StopAtBounds;
                            delegate: StreamListItem {
                                type: "sink-input"
                                draggable: sinkView.count > 1
                            }
                        }

                        PlasmaCore.SvgItem {
                            elementId: "horizontal-line"
                            Layout.preferredWidth: scrollView.viewport.width - PlasmaCore.Units.smallSpacing * 4
                            Layout.preferredHeight: naturalSize.height
                            Layout.leftMargin: PlasmaCore.Units.smallSpacing * 2
                            Layout.rightMargin: PlasmaCore.Units.smallSpacing * 2
                            Layout.topMargin: PlasmaCore.Units.smallSpacing
                            svg: lineSvg
                            visible: sinkInputView.model.count > 0 && sourceOutputView.model.count > 0
                        }

                        ListView {
                            id: sourceOutputView

                            Layout.fillWidth: true
                            Layout.minimumHeight: contentHeight
                            Layout.maximumHeight: contentHeight

                            model: PulseObjectFilterModel {
                                filters: [ { role: "VirtualStream", value: false } ]
                                sourceModel: SourceOutputModel {}
                            }
                            boundsBehavior: Flickable.StopAtBounds;
                            delegate: StreamListItem {
                                type: "source-input"
                                draggable: sourceView.count > 1
                            }
                        }
                    }

                    ColumnLayout {
                        id: devicesView
                        visible: tabBar.currentTab == devicesTab
                        property int maximumWidth: scrollView.viewport.width
                        width: maximumWidth
                        Layout.maximumWidth: maximumWidth
                        spacing: 0

                        ListView {
                            id: sinkView

                            Layout.fillWidth: true
                            Layout.minimumHeight: contentHeight
                            Layout.maximumHeight: contentHeight
                            spacing: 0

                            model: paSinkFilterModel

                            boundsBehavior: Flickable.StopAtBounds;
                            delegate: DeviceListItem {
                                type: "sink"
                                onlyone: sinkView.count === 1
                            }
                        }

                        PlasmaCore.SvgItem {
                            id: devicesLine
                            elementId: "horizontal-line"
                            Layout.preferredWidth: scrollView.viewport.width - PlasmaCore.Units.smallSpacing * 4
                            Layout.leftMargin: PlasmaCore.Units.smallSpacing * 2
                            Layout.rightMargin: Layout.leftMargin
                            Layout.topMargin: PlasmaCore.Units.smallSpacing
                            svg: lineSvg
                            visible: sinkView.model.count > 0 && sourceView.model.count > 0 && (sinkView.model.count > 1 || sourceView.model.count > 1)
                        }

                        ListView {
                            id: sourceView

                            Layout.fillWidth: true
                            Layout.minimumHeight: contentHeight
                            Layout.maximumHeight: contentHeight

                            model: paSourceFilterModel

                            boundsBehavior: Flickable.StopAtBounds;
                            delegate: DeviceListItem {
                                type: "source"
                                onlyone: sourceView.count === 1
                            }
                        }
                    }

                    PlasmaExtras.Heading {
                        level: 4
                        enabled: false
                        width: parent.width
                        height: scrollView.height
                        visible: streamsView.visible && !sinkInputView.count && !sourceOutputView.count
                        text: i18n("No applications playing or recording audio")
                        wrapMode: Text.WordWrap
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                    }

                    PlasmaExtras.Heading {
                        level: 4
                        enabled: false
                        width: parent.width
                        height: scrollView.height
                        visible: devicesView.visible && !sinkView.count && !sourceView.count
                        text: i18n("No output or input devices found")
                        wrapMode: Text.WordWrap
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }

        footer: PlasmaExtras.PlasmoidHeading {
            location: PlasmaExtras.PlasmoidHeading.Location.Footer
            // Allow tabbar to touch the footer's top border
            topPadding: -topInset

            RowLayout {
                anchors.fill: parent

                PlasmaComponents.TabBar {
                    id: tabBar
                    Layout.fillWidth: true
                    activeFocusOnTab: true
                    tabPosition: Qt.BottomEdge

                    PlasmaComponents.TabButton {
                        id: devicesTab
                        text: i18n("Devices")
                    }

                    PlasmaComponents.TabButton {
                        id: streamsTab
                        text: i18n("Applications")
                    }
                }
            }
        }
    }

    function action_forceMute() {
        if (!globalMute) {
            enableGlobalMute();
        } else {
            disableGlobalMute();
        }
    }

    Component.onCompleted: {
        MicrophoneIndicator.init();

        plasmoid.setAction("forceMute", i18n("Force mute all playback devices"), "audio-volume-muted");
        plasmoid.action("forceMute").checkable = true;
        plasmoid.action("forceMute").checked = Qt.binding(() => {return globalMute;});
    }
}
