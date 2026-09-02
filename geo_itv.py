# -*- coding: utf-8 -*-
"""Point d'entrée du plugin GeoITV pour QGIS.

SPDX-License-Identifier: MIT
Copyright (c) 2025 NAOMIS
"""
from qgis.PyQt.QtCore import QSettings, QTranslator, QCoreApplication, QUrl
from qgis.PyQt.QtGui import QIcon, QDesktopServices
from qgis.PyQt.QtWidgets import QAction, QMessageBox

from qgis.core import QgsProviderRegistry, QgsWkbTypes, QgsMapLayerProxyModel

# Initialize Qt resources from file resources.py
from .resources import *
# Import the code for the dialog
from .geo_itv_dialog import GeoITVDialog
import os.path


SETTINGS_KEY_USE_DB_VIEWS = "GeoITV/use_db_views"
SETTINGS_KEY_LOG_LEVEL = "GeoITV/log_level"


def _read_bool_setting(key, default=False):
    """
    Lit un booléen dans QSettings de manière robuste.
    """
    value = QSettings().value(key, default)
    if isinstance(value, bool):
        return value
    text = str(value).strip().lower()
    return text in ("1", "true", "yes", "y", "on")


def _read_text_setting(key, default=""):
    value = QSettings().value(key, default)
    if value is None:
        return default
    return str(value)


class GeoITV:
    """QGIS Plugin Implementation."""

    def __init__(self, iface):
        """Constructor.

        :param iface: An interface instance that will be passed to this class
            which provides the hook by which you can manipulate the QGIS
            application at run time.
        :type iface: QgsInterface
        """
        # Save reference to the QGIS interface
        self.iface = iface
        # initialize plugin directory
        self.plugin_dir = os.path.dirname(__file__)
        # initialize locale
        locale = QSettings().value('locale/userLocale')[0:2]
        locale_path = os.path.join(
            self.plugin_dir,
            'i18n',
            'GeoITV_{}.qm'.format(locale))

        if os.path.exists(locale_path):
            self.translator = QTranslator()
            self.translator.load(locale_path)
            QCoreApplication.installTranslator(self.translator)

        # Declare instance attributes
        self.actions = []
        self.menu = self.tr(u'&GeoITV')

        # Check if plugin was started the first time in current QGIS session
        # Must be set in initGui() to survive plugin reloads
        self.first_start = None

    # noinspection PyMethodMayBeStatic
    def tr(self, message):
        """Get the translation for a string using Qt translation API.

        We implement this ourselves since we do not inherit QObject.

        :param message: String for translation.
        :type message: str, QString

        :returns: Translated version of message.
        :rtype: QString
        """
        # noinspection PyTypeChecker,PyArgumentList,PyCallByClass
        return QCoreApplication.translate('GeoITV', message)


    def add_action(
        self,
        icon_path,
        text,
        callback,
        enabled_flag=True,
        add_to_menu=True,
        add_to_toolbar=True,
        status_tip=None,
        whats_this=None,
        parent=None):
        """Add a toolbar icon to the toolbar.

        :param icon_path: Path to the icon for this action. Can be a resource
            path (e.g. ':/plugins/foo/bar.png') or a normal file system path.
        :type icon_path: str

        :param text: Text that should be shown in menu items for this action.
        :type text: str

        :param callback: Function to be called when the action is triggered.
        :type callback: function

        :param enabled_flag: A flag indicating if the action should be enabled
            by default. Defaults to True.
        :type enabled_flag: bool

        :param add_to_menu: Flag indicating whether the action should also
            be added to the menu. Defaults to True.
        :type add_to_menu: bool

        :param add_to_toolbar: Flag indicating whether the action should also
            be added to the toolbar. Defaults to True.
        :type add_to_toolbar: bool

        :param status_tip: Optional text to show in a popup when mouse pointer
            hovers over the action.
        :type status_tip: str

        :param parent: Parent widget for the new action. Defaults None.
        :type parent: QWidget

        :param whats_this: Optional text to show in the status bar when the
            mouse pointer hovers over the action.

        :returns: The action that was created. Note that the action is also
            added to self.actions list.
        :rtype: QAction
        """

        icon = QIcon(icon_path)
        action = QAction(icon, text, parent)
        action.triggered.connect(callback)
        action.setEnabled(enabled_flag)

        if status_tip is not None:
            action.setStatusTip(status_tip)

        if whats_this is not None:
            action.setWhatsThis(whats_this)

        if add_to_toolbar:
            # Adds plugin icon to Plugins toolbar
            self.iface.addToolBarIcon(action)

        if add_to_menu:
            self.iface.addPluginToMenu(
                self.menu,
                action)

        self.actions.append(action)

        return action

    def show_about(self):
        """
        Affiche une boîte de dialogue À propos avec logos, texte, et lien GEOPAL.
        """
        from qgis.PyQt.QtWidgets import QDialog, QLabel, QVBoxLayout, QHBoxLayout, QPushButton, QDialogButtonBox
        from qgis.PyQt.QtGui import QPixmap, QDesktopServices
        from qgis.PyQt.QtCore import Qt, QUrl

        dlg = QDialog(self.iface.mainWindow())
        dlg.setWindowTitle("À propos de GeoITV")

        layout = QVBoxLayout()


        # Texte principal (avant logo Naomis)
        text_before_logo = (
            "<b>GeoITV</b><br>"
            "Plugin QGIS pour faciliter l'import, le traitement et la visualisation des données issues d'inspections télévisées (ITV)."
        )
        label_text_before = QLabel(text_before_logo)
        label_text_before.setOpenExternalLinks(True)
        label_text_before.setWordWrap(True)
        layout.addWidget(label_text_before)

        # Logo Naomis (centré, entre version et merci)
        logo_layout = QHBoxLayout()
        logo_layout.addStretch(1)
        logo_naomis = QLabel()
        logo_naomis.setPixmap(QPixmap(os.path.join(self.plugin_dir, "assets", "logo_naomis.png")).scaledToHeight(48, Qt.SmoothTransformation))
        logo_layout.addWidget(logo_naomis, alignment=Qt.AlignCenter)
        logo_layout.addStretch(1)
        layout.addLayout(logo_layout)

        # Texte principal (après logo Naomis)
        text_after_logo = (
            "<b>Conception et développement :</b> NAOMIS (<a href='https://www.naomis.fr'>www.naomis.fr</a>)<br><br>"
            "<b>Version :</b> 1.0.5<br><br>"
            "<div style='text-align:center;'><b>Merci à tous les contributeurs et utilisateurs de ce plugin !</b></div><br>"
            "<b>Code source :</b> <a href='https://github.com/naomis/qgis-itv-plugin'>https://github.com/naomis/qgis-itv-plugin</a><br>"
            "<b>Licence :</b> MIT License<br><br>"
            "<span style='font-size:9pt;'>Projet développé dans le cadre du programme <b>GEOPAL</b> (<a href='https://www.geopal.org/'>en savoir plus</a>) financé par la Région des Pays de la Loire.</span>"
        )
        label_text_after = QLabel(text_after_logo)
        label_text_after.setOpenExternalLinks(True)
        label_text_after.setWordWrap(True)
        layout.addWidget(label_text_after)

        # Logos partenaires (GEOPAL et Région)
        logos_part_layout = QHBoxLayout()
        logo_geopal = QLabel()
        logo_region = QLabel()
        # Logos plus grands (48px) et espacés
        logo_geopal.setPixmap(QPixmap(os.path.join(self.plugin_dir, "assets", "geopal.svg")).scaledToHeight(40, Qt.SmoothTransformation))
        logo_region.setPixmap(QPixmap(os.path.join(self.plugin_dir, "assets", "logo_pdl.png")).scaledToHeight(40, Qt.SmoothTransformation))
        logos_part_layout.addStretch(1)
        logos_part_layout.addWidget(logo_geopal, alignment=Qt.AlignCenter)
        # Espacement horizontal entre les deux logos
        spacer = QLabel()
        spacer.setFixedWidth(32)
        logos_part_layout.addWidget(spacer)
        logos_part_layout.addWidget(logo_region, alignment=Qt.AlignCenter)
        logos_part_layout.addStretch(1)
        layout.addLayout(logos_part_layout)

        # Espacement vertical entre les logos et le bouton fermer
        from qgis.PyQt.QtWidgets import QSpacerItem, QSizePolicy
        spacer_vertical = QSpacerItem(20, 24, QSizePolicy.Minimum, QSizePolicy.Fixed)
        layout.addItem(spacer_vertical)

        # Bouton fermer centré
        btns = QDialogButtonBox(QDialogButtonBox.Close)
        btns.rejected.connect(dlg.reject)
        btns_layout = QHBoxLayout()
        btns_layout.addStretch(1)
        btns_layout.addWidget(btns, alignment=Qt.AlignCenter)
        btns_layout.addStretch(1)
        layout.addLayout(btns_layout)

        dlg.setLayout(layout)
        # Appliquer un style local compact pour la boîte "À propos"
        dlg.setStyleSheet(
            "QDialog { background-color: white; }"
            "QLabel { font-size: 9pt; }"
            "QDialogButtonBox QPushButton { font-size: 9pt; min-height: 24px; }"
        )
        dlg.exec_()

    def show_help(self):
        import os
        from qgis.PyQt.QtWidgets import QMessageBox
        # Chemin absolu vers la doc locale
        doc_path = os.path.join(self.plugin_dir, 'help', 'build', 'html', 'index.html')
        if os.path.exists(doc_path):
            QDesktopServices.openUrl(QUrl.fromLocalFile(doc_path))
        else:
            # Fallback : doc en ligne si la locale n'existe pas
            QDesktopServices.openUrl(QUrl("https://votre-url-aide-ou-doc.fr"))

    def show_configuration(self):
        """
        Affiche la configuration du mode d'exécution du plugin.
        """
        from qgis.PyQt.QtWidgets import (
            QDialog,
            QVBoxLayout,
            QHBoxLayout,
            QLabel,
            QCheckBox,
            QComboBox,
            QWidget,
            QDialogButtonBox,
        )

        dlg = QDialog(self.iface.mainWindow())
        dlg.setWindowTitle("Configuration GeoITV")
        font = dlg.font()
        font.setPointSize(9)
        dlg.setFont(font)
        dlg.setStyleSheet(
            "QLabel { font-size: 9pt; }"
            "QCheckBox { font-size: 9pt; }"
            "QComboBox { font-size: 9pt; min-height: 22px; }"
            "QDialogButtonBox QPushButton { font-size: 9pt; min-height: 24px; }"
        )

        layout = QVBoxLayout()

        intro = QLabel(
            "Choisissez le mode d'exécution par défaut du plugin :"
        )
        intro.setWordWrap(True)
        layout.addWidget(intro)

        checkbox_db = QCheckBox("Activer le mode base de données (vues SQL legacy)")
        checkbox_db.setChecked(_read_bool_setting(SETTINGS_KEY_USE_DB_VIEWS, default=False))
        layout.addWidget(checkbox_db)

        log_row = QWidget()
        log_row_layout = QHBoxLayout()
        log_row_layout.setContentsMargins(0, 0, 0, 0)
        log_row_layout.addWidget(QLabel("Niveau de log :"))
        log_level_combo = QComboBox()
        log_level_combo.addItem("Standard", "info")
        log_level_combo.addItem("Debug", "debug")
        current_log_level = _read_text_setting(SETTINGS_KEY_LOG_LEVEL, "info").strip().lower()
        if current_log_level == "verbose":
            current_log_level = "debug"
        idx = log_level_combo.findData(current_log_level)
        log_level_combo.setCurrentIndex(idx if idx >= 0 else 0)
        log_row_layout.addWidget(log_level_combo)
        log_row.setLayout(log_row_layout)
        layout.addWidget(log_row)

        help_text = QLabel(
            "<i>Décoché: mode FullPython (sans dépendance SQL).<br>"
            "Coché: mode DB (PostgreSQL/PostGIS + vues SQL).</i>"
        )
        help_text.setWordWrap(True)
        layout.addWidget(help_text)

        buttons = QDialogButtonBox(QDialogButtonBox.Ok | QDialogButtonBox.Cancel)
        buttons.accepted.connect(dlg.accept)
        buttons.rejected.connect(dlg.reject)

        btn_layout = QHBoxLayout()
        btn_layout.addStretch(1)
        btn_layout.addWidget(buttons)
        layout.addLayout(btn_layout)

        dlg.setLayout(layout)

        if dlg.exec_():
            use_db_views = checkbox_db.isChecked()

            settings = QSettings()
            settings.setValue(SETTINGS_KEY_USE_DB_VIEWS, use_db_views)
            settings.setValue(SETTINGS_KEY_LOG_LEVEL, log_level_combo.currentData())

            mode_label = "DB legacy (vues SQL)" if use_db_views else "FullPython"
            QMessageBox.information(
                self.iface.mainWindow(),
                "Configuration enregistrée",
                f"Mode : {mode_label}" + ("\nSchéma SQL : itv" if use_db_views else "")
            )

            if hasattr(self, "dlg") and self.dlg is not None:
                self.dlg.refresh_mode_ui()

    def initGui(self):
        """Create the menu entries and toolbar icons inside the QGIS GUI."""
        icon_path = ':/plugins/geo_itv/icon.png'
        self.add_action(
            icon_path,
            text=self.tr(u'GeoITV'),
            callback=self.run,
            parent=self.iface.mainWindow())

        # Action Configuration
        self.action_config = QAction("Configuration", self.iface.mainWindow())
        self.action_config.triggered.connect(self.show_configuration)
        self.iface.addPluginToMenu(self.menu, self.action_config)

        # Action Aide
        self.action_help = QAction("Aide", self.iface.mainWindow())
        self.action_help.triggered.connect(self.show_help)
        self.iface.addPluginToMenu(self.menu, self.action_help)

        # Action À propos
        self.action_about = QAction("À propos", self.iface.mainWindow())
        self.action_about.triggered.connect(self.show_about)
        self.iface.addPluginToMenu(self.menu, self.action_about)

        # will be set False in run()
        self.first_start = True


    def unload(self):
        """Removes the plugin menu items and icons from QGIS GUI, including custom actions."""
        for action in self.actions:
            self.iface.removePluginMenu(self.tr(u'&GeoITV'), action)
            self.iface.removeToolBarIcon(action)
        # Remove custom menu actions if they exist
        if hasattr(self, 'action_config'):
            self.iface.removePluginMenu(self.menu, self.action_config)
        if hasattr(self, 'action_about'):
            self.iface.removePluginMenu(self.menu, self.action_about)
        if hasattr(self, 'action_help'):
            self.iface.removePluginMenu(self.menu, self.action_help)


    def run(self):
        """Run method that performs all the real work"""

        # Create the dialog with elements (after translation) and keep reference
        # Only create GUI ONCE in callback, so that it will only load when the plugin is started
        if self.first_start == True:
            self.show_about()
            self.first_start = False
            self.dlg = GeoITVDialog()

        # Reset progress bar at each run
        self.dlg.progressBar.setValue(0)
        self.dlg.log_info("Démarrage de GeoITV...", True)

        # Get the list of PostgreSQL connections and populate the combo box
        connexions = QgsProviderRegistry.instance().providerMetadata("postgres").connections()
        self.dlg.cmbConnexionBDD.clear()
        self.dlg.cmbConnexionBDD.addItems(connexions.keys())

        # Set geometry types for layer selection comboBoxes
        self.dlg.mapLayerComboBox_regard.setFilters(QgsMapLayerProxyModel.PointLayer)
        self.dlg.mapLayerComboBox_collecteur.setFilters(QgsMapLayerProxyModel.LineLayer)
        self.dlg.mapLayerComboBox_collecteur.setCurrentIndex(0)
        self.dlg.refresh_mode_ui()
        
        # show the dialog
        self.dlg.show()
        # Run the dialog event loop
        result = self.dlg.exec_()
        # See if OK was pressed
        if result:
            # Do something useful here - delete the line containing pass and
            # substitute with your code.
            pass

