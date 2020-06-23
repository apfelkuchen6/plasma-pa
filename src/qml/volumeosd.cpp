/*
    Copyright 2014-2015 Harald Sitter <sitter@kde.org>

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation; either
    version 2.1 of the License, or (at your option) version 3, or any
    later version accepted by the membership of KDE e.V. (or its
    successor approved by the membership of KDE e.V.), which shall
    act as a proxy defined in Section 6 of version 3 of the license.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with this library.  If not, see <http://www.gnu.org/licenses/>.
*/

#include "volumeosd.h"

#include "osdservice.h"

#define SERVICE QLatin1String("org.kde.plasmashell")
#define PATH QLatin1String("/org/kde/osdService")
#define CONNECTION QDBusConnection::sessionBus()

VolumeOSD::VolumeOSD(QObject *parent)
    : QObject(parent)
{
}

void VolumeOSD::show(int percent, int maximumPercent)
{
    OsdServiceInterface osdService(SERVICE, PATH, CONNECTION);
    osdService.volumeChanged(percent, maximumPercent);
}

void VolumeOSD::showMicrophone(int percent)
{
    OsdServiceInterface osdService(SERVICE, PATH, CONNECTION);
    osdService.microphoneVolumeChanged(percent);
}

void VolumeOSD::showText(const QString &iconName, const QString &text)
{
    OsdServiceInterface osdService(SERVICE, PATH, CONNECTION);
    osdService.showText(iconName, text);
}
