# -*- coding: utf-8 -*-
"""Initialise le plugin GeoITV pour QGIS.

SPDX-License-Identifier: MIT
Copyright (c) 2025 NAOMIS
"""


# noinspection PyPep8Naming
def classFactory(iface):  # pylint: disable=invalid-name
    """Load GeoITV class from file GeoITV.

    :param iface: A QGIS interface instance.
    :type iface: QgsInterface
    """
    #
    from .geo_itv import GeoITV
    return GeoITV(iface)
