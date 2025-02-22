/*
    SPDX-FileCopyrightText: 2014-2015 Harald Sitter <sitter@kde.org>

    SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL
*/

#include "port.h"

namespace QPulseAudio
{
Port::Port(QObject *parent)
    : Profile(parent)
{
}

Port::~Port() = default;

} // QPulseAudio
