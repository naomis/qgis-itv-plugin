from __future__ import annotations

from math import atan2, sin, cos, pi
from typing import Optional

from shapely import Point, LineString

from qgis.PyQt.QtCore import QVariant

from qgis.core import (
    Qgis,
    QgsMessageLog,
    QgsProject,
    QgsVectorLayer,
    QgsFeature,
    QgsGeometry,
    QgsField,
    QgsLineSymbol,
    QgsSingleSymbolRenderer,
    QgsArrowSymbolLayer,
)


class BcaGeometryCalculator:
    """
    Calcul et affichage des branchements BCA.

    Fonctionnement :

    - Les BCA peuvent être portés directement par Detail
      ou être contenus dans detail.defauts.
    - Les identifiants regard sont normalisés.
    - Le tronçon collecteur est utilisé s'il existe.
    - Si aucun collecteur n'est fourni, un tronçon virtuel est
      automatiquement créé entre le regard entrant et le regard sortant.
    - Le point du BCA est calculé suivant le métrage.
    - La direction du branchement est calculée suivant orientatio.
    - Une couche QGIS de lignes est créée.
    - La couche est affichée avec une symbologie de flèche bleue.
    """

    def __init__(self):
        self.layer_name = "Orientation_branchement"

    # ==========================================================
    # NORMALISATION DES IDENTIFIANTS
    # ==========================================================

    @staticmethod
    def _normalize_key(value):
        """
        Transforme un identifiant en clé comparable.

        Exemple :
            00123  -> "123"
            "00123" -> "123"
            " 123 " -> "123"
        """

        if value is None:
            return None

        try:
            text = str(value).strip()
        except Exception:
            return None

        if not text:
            return None

        return text.lstrip("0") or "0"

    # ==========================================================
    # TEST BCA
    # ==========================================================

    @staticmethod
    def _is_bca(obj) -> bool:
        """
        Retourne True si l'objet est un BCA.

        On accepte :
            obj.fam_obs == "BCA"

        ou :
            obj.fam_obs == "BCA" avec éventuellement
            des défauts imbriqués.
        """

        if obj is None:
            return False

        try:
            return str(getattr(obj, "fam_obs", "")).strip().upper() == "BCA"
        except (AttributeError, TypeError, ValueError):
            return False

    # ==========================================================
    # EXTRACTION DES BCA
    # ==========================================================

    def _extract_bca_details(self, details):
        """
        Extrait tous les BCA.

        IMPORTANT :
        Dans ton modèle actuel, les BCA sont dans :

            detail.defauts

        et non directement dans self.details.

        On retourne les objets BCA eux-mêmes.
        """

        result = []

        if not details:
            return result

        for detail in details:

            # --------------------------------------------------
            # Cas 1 : le Detail lui-même est un BCA
            # --------------------------------------------------

            if self._is_bca(detail):
                result.append(detail)

            # --------------------------------------------------
            # Cas 2 : le BCA est dans detail.defauts
            # --------------------------------------------------

            for defaut in getattr(detail, "defauts", None) or []:

                if self._is_bca(defaut):

                    # On garde le lien vers le Detail parent.
                    defaut._bca_parent_detail = detail

                    result.append(defaut)

        return result

    # ==========================================================
    # COPIE DES INFORMATIONS DU DETAIL PARENT
    # ==========================================================

    @staticmethod
    def _get_value(bca, name, default=None):
        """Récupère une valeur du BCA puis de son Detail parent.

        Les anciennes versions du parseur ont utilisé plusieurs variantes
        pour l'orientation. On les accepte toutes ici, sans dépendre d'un
        attribut précis du parser.
        """
        aliases = {
            "orientatio": ("orientatio", "orientation", "orient", "direction", "sens"),
        }
        names = aliases.get(name, (name,))

        parent = getattr(bca, "_bca_parent_detail", None)
        objects = (bca, parent) if parent is not None else (bca,)

        for obj in objects:
            if obj is None:
                continue
            for attr in names:
                try:
                    value = getattr(obj, attr, None)
                except Exception:
                    value = None
                if value is not None and str(value).strip() != "":
                    return value

        return default

    # ==========================================================
    # MÉTHODE PRINCIPALE
    # ==========================================================

    def create_arrow_layer(
        self,
        details,
        troncons,
        regards,
    ):
        """
        Crée la couche QGIS des flèches BCA.

        Parameters
        ----------
        details :
            Liste des Detail.

        troncons :
            dict :
                identifiant tronçon -> Shapely LineString

        regards :
            dict :
                identifiant regard -> Shapely Point
        """

        # ------------------------------------------------------
        # Nettoyage ancienne couche
        # ------------------------------------------------------

        self._remove_existing_layer()

        # ------------------------------------------------------
        # Sécurisation
        # ------------------------------------------------------

        if troncons is None:
            troncons = {}

        if regards is None:
            regards = {}

        # ------------------------------------------------------
        # Extraction réelle des BCA
        # ------------------------------------------------------

        bca_details = self._extract_bca_details(details)

        # ------------------------------------------------------
        # Création couche
        # ------------------------------------------------------

        layer = QgsVectorLayer(
            "LineString",
            self.layer_name,
            "memory",
        )

        if not layer.isValid():
            raise RuntimeError(
                "Impossible de créer la couche BCA."
            )

        # ------------------------------------------------------
        # CRS du projet
        # ------------------------------------------------------

        project_crs = QgsProject.instance().crs()

        if project_crs.isValid():
            layer.setCrs(project_crs)

        # ------------------------------------------------------
        # Champs
        # ------------------------------------------------------

        provider = layer.dataProvider()

        provider.addAttributes([
            QgsField("gid", QVariant.Int),
            QgsField("inspection_gid", QVariant.Int),
            QgsField("id_troncon", QVariant.Int),
            QgsField("id_reg_ent", QVariant.Int),
            QgsField("id_reg_sor", QVariant.Int),
            QgsField("metrage", QVariant.Double),
            QgsField("orientatio", QVariant.String),
        ])

        layer.updateFields()

        features = []

        # ======================================================
        # PARCOURS DES BCA
        # ======================================================

        for bca in bca_details:

            try:

                # --------------------------------------------------
                # Identifiants
                # --------------------------------------------------

                id_troncon = self._get_value(
                    bca,
                    "id_troncon",
                )

                id_reg_ent = self._get_value(
                    bca,
                    "id_reg_ent",
                )

                id_reg_sor = self._get_value(
                    bca,
                    "id_reg_sor",
                )

                metrage = self._get_value(
                    bca,
                    "metrage",
                )

                orientatio = self._get_value(
                    bca,
                    "orientatio",
                )

                # --------------------------------------------------
                # Recherche regards
                # --------------------------------------------------

                regard_ent = regards.get(
                    self._normalize_key(id_reg_ent)
                )

                regard_sor = regards.get(
                    self._normalize_key(id_reg_sor)
                )

                # --------------------------------------------------
                # Les deux regards sont obligatoires
                # --------------------------------------------------

                if regard_ent is None:
                    continue

                if regard_sor is None:
                    continue

                if regard_ent.is_empty:
                    continue

                if regard_sor.is_empty:
                    continue

                # --------------------------------------------------
                # Recherche du tronçon réel
                # --------------------------------------------------

                troncon = troncons.get(
                    self._normalize_key(id_troncon)
                )

                # ==================================================
                # IMPORTANT :
                # PAS DE COLLECTEUR
                # ==================================================
                #
                # On construit automatiquement un tronçon virtuel
                # entre les deux regards.
                #
                # C'est précisément le cas de ton traitement actuel.
                # ==================================================

                if troncon is None:

                    if regard_ent.equals(
                        regard_sor
                    ):
                        continue

                    troncon = LineString([
                        (
                            regard_ent.x,
                            regard_ent.y,
                        ),
                        (
                            regard_sor.x,
                            regard_sor.y,
                        ),
                    ])

                # --------------------------------------------------
                # Vérification géométrie
                # --------------------------------------------------

                if troncon is None:
                    continue

                if troncon.is_empty:
                    continue

                if not isinstance(
                    troncon,
                    LineString,
                ):
                    continue

                if troncon.length <= 0:
                    continue

                # --------------------------------------------------
                # Calcul géométrie
                # --------------------------------------------------

                geometry = self.calculate(
                    detail=bca,
                    troncon=troncon,
                    regard_ent=regard_ent,
                    regard_sor=regard_sor,
                )

                if geometry is None:
                    continue

                # --------------------------------------------------
                # Stockage
                # --------------------------------------------------

                bca.geometry = geometry

                # --------------------------------------------------
                # Feature QGIS
                # --------------------------------------------------

                feature = QgsFeature(
                    layer.fields()
                )

                qgis_geometry = QgsGeometry.fromWkt(
                    geometry.wkt
                )

                if qgis_geometry.isNull():
                    continue

                if qgis_geometry.isEmpty():
                    continue

                feature.setGeometry(
                    qgis_geometry
                )

                # --------------------------------------------------
                # Attributs
                # --------------------------------------------------

                feature.setAttribute(
                    "gid",
                    self._get_value(
                        bca,
                        "gid",
                    ),
                )

                feature.setAttribute(
                    "inspection_gid",
                    self._get_value(
                        bca,
                        "inspection_gid",
                    ),
                )

                feature.setAttribute(
                    "id_troncon",
                    id_troncon,
                )

                feature.setAttribute(
                    "id_reg_ent",
                    id_reg_ent,
                )

                feature.setAttribute(
                    "id_reg_sor",
                    id_reg_sor,
                )

                try:
                    feature.setAttribute(
                        "metrage",
                        float(metrage)
                        if metrage is not None
                        else None,
                    )
                except Exception:
                    feature.setAttribute(
                        "metrage",
                        None,
                    )

                feature.setAttribute(
                    "orientatio",
                    str(orientatio)
                    if orientatio is not None
                    else None,
                )

                features.append(feature)

            except Exception as error:
                # Un BCA défectueux ne doit pas empêcher
                # les autres BCA d'être créés.
                QgsMessageLog.logMessage(
                    f"BCA ignoré : {error}", "GeoITV", Qgis.Warning
                )

        # ======================================================
        # AJOUT DES FEATURES
        # ======================================================

        if features:

            ok, added = provider.addFeatures(
                features
            )

            if not ok:
                raise RuntimeError(
                    "QGIS n'a pas réussi à ajouter les géométries BCA."
                )

        layer.updateExtents()

        # ======================================================
        # SYMBOLOGIE
        # ======================================================

        self._apply_arrow_style(
            layer
        )

        # ======================================================
        # AJOUT AU PROJET
        # ======================================================

        QgsProject.instance().addMapLayer(
            layer
        )

        layer.triggerRepaint()

        return layer

    # ==========================================================
    # CALCUL D'UNE GÉOMÉTRIE
    # ==========================================================

    def calculate(
        self,
        detail,
        troncon: LineString,
        regard_ent: Point,
        regard_sor: Point,
    ) -> Optional[LineString]:
        """
        Calcule la ligne représentant le branchement BCA.
        """

        if detail is None:
            return None

        if not self._is_bca(detail):
            return None

        # ------------------------------------------------------
        # Métrage
        # ------------------------------------------------------

        # ------------------------------------------------------
        # Géométrie
        # ------------------------------------------------------

        if troncon is None:
            return None

        if troncon.is_empty:
            return None

        if not isinstance(
            troncon,
            LineString,
        ):
            return None

        if troncon.length <= 0:
            return None

        metrage = self._get_value(
            detail,
            "metrage",
        )

        if metrage is None:
            metrage = troncon.length / 2.0

        try:
            metrage = float(metrage)
        except (TypeError, ValueError):
            metrage = troncon.length / 2.0

        # ------------------------------------------------------
        # Regards
        # ------------------------------------------------------

        if regard_ent is None:
            return None

        if regard_sor is None:
            return None

        if regard_ent.is_empty:
            return None

        if regard_sor.is_empty:
            return None

        # ------------------------------------------------------
        # Sens du tronçon
        # ------------------------------------------------------

        direction = self._get_direction(
            troncon,
            regard_ent,
            regard_sor,
        )

        # ------------------------------------------------------
        # Point au métrage
        # ------------------------------------------------------

        point = self._get_observation_point(
            troncon,
            metrage,
            direction,
        )

        if point is None:
            return None

        # ------------------------------------------------------
        # Azimut du tronçon
        # ------------------------------------------------------

        azimuth = self._get_azimuth(
            troncon,
            direction,
        )

        if azimuth is None:
            return None

        # ------------------------------------------------------
        # Orientation BCA
        # ------------------------------------------------------

        orientatio = self._get_value(
            detail,
            "orientatio",
        )

        return self._get_arrow_geometry(
            point,
            azimuth,
            orientatio,
        )

    # ==========================================================
    # DIRECTION DU TRONÇON
    # ==========================================================

    def _get_direction(
        self,
        troncon: LineString,
        regard_ent: Point,
        regard_sor: Point,
    ) -> str:
        """
        Détermine si le sens de la géométrie du tronçon
        correspond au sens entrant -> sortant.
        """

        start_point = Point(
            troncon.coords[0]
        )

        end_point = Point(
            troncon.coords[-1]
        )

        # ------------------------------------------------------
        # Distance du début vers les regards
        # ------------------------------------------------------

        start_ent = start_point.distance(
            regard_ent
        )

        start_sor = start_point.distance(
            regard_sor
        )

        # ------------------------------------------------------
        # Distance de la fin vers les regards
        # ------------------------------------------------------

        end_ent = end_point.distance(
            regard_ent
        )

        end_sor = end_point.distance(
            regard_sor
        )

        # ------------------------------------------------------
        # Le début est le regard entrant
        # ------------------------------------------------------

        if (
            start_ent + end_sor
            <=
            start_sor + end_ent
        ):
            return "forward"

        return "reverse"

    # ==========================================================
    # POINT AU MÉTRAGE
    # ==========================================================

    def _get_observation_point(
        self,
        troncon: LineString,
        metrage: float,
        direction: str,
    ) -> Optional[Point]:
        """
        Retourne le point situé à 'metrage' depuis
        le regard entrant.
        """

        longueur = troncon.length

        if longueur <= 0:
            return None

        # ------------------------------------------------------
        # Protection métrage
        # ------------------------------------------------------

        metrage = max(
            0.0,
            min(
                metrage,
                longueur,
            ),
        )

        # ------------------------------------------------------
        # Sens normal
        # ------------------------------------------------------

        if direction == "forward":

            return troncon.interpolate(
                metrage
            )

        # ------------------------------------------------------
        # Sens inverse
        # ------------------------------------------------------

        reverse_coords = list(
            troncon.coords
        )

        reverse_coords.reverse()

        reverse_troncon = LineString(
            reverse_coords
        )

        return reverse_troncon.interpolate(
            metrage
        )

    # ==========================================================
    # AZIMUT
    # ==========================================================

    def _get_azimuth(
        self,
        troncon: LineString,
        direction: str = "forward",
    ) -> Optional[float]:
        """
        Calcule l'azimut local du tronçon.

        L'azimut est calculé au milieu de la ligne afin
        d'éviter de prendre uniquement la direction des
        extrémités sur un tronçon courbe.
        """

        if troncon is None:
            return None

        if troncon.is_empty:
            return None

        if troncon.length <= 0:
            return None

        try:

            # --------------------------------------------------
            # On prend une petite fenêtre autour du milieu
            # --------------------------------------------------

            p1 = troncon.interpolate(
                0.45,
                normalized=True,
            )

            p2 = troncon.interpolate(
                0.55,
                normalized=True,
            )

            dx = p2.x - p1.x
            dy = p2.y - p1.y

            if abs(dx) < 1e-12 and abs(dy) < 1e-12:

                p1 = troncon.interpolate(
                    0.25,
                    normalized=True,
                )

                p2 = troncon.interpolate(
                    0.75,
                    normalized=True,
                )

                dx = p2.x - p1.x
                dy = p2.y - p1.y

            azimuth = atan2(
                dx,
                dy,
            )

            # --------------------------------------------------
            # Si le tronçon est parcouru en sens inverse,
            # l'azimut doit également être inversé.
            # --------------------------------------------------

            if direction == "reverse":
                azimuth += pi

            # --------------------------------------------------
            # Normalisation
            # --------------------------------------------------

            while azimuth > pi:
                azimuth -= 2 * pi

            while azimuth < -pi:
                azimuth += 2 * pi

            return azimuth

        except Exception:
            return None

    # ==========================================================
    # CRÉATION DE LA FLÈCHE
    # ==========================================================

    def _get_arrow_geometry(
        self,
        point: Point,
        azimuth: float,
        orientatio: Optional[str],
    ) -> Optional[LineString]:
        """
        Crée la ligne du branchement.

        orientatio :

            12h -> dans l'axe du collecteur

            03h / 04h / 05h
                -> droite

            06h / 07h / 08h / 09h /
            10h / 11h
                -> gauche

        La flèche QGIS sera ensuite dessinée
        à l'extrémité de cette ligne.
        """

        if point is None:
            return None

        if orientatio is None or not str(orientatio).strip():
            # Orientation absente : on conserve le BCA avec une flèche dans
            # l'axe du collecteur. La valeur est explicitement enregistrée
            # dans la couche pour éviter les 0 entités.
            orientatio = "12h"

        try:
            orientatio = str(orientatio).strip().lower().replace(" ", "")
        except Exception:
            orientatio = "12h"

        # Tolérance aux variantes 3h, 03H, 7 H, etc.
        if orientatio.endswith("h") and orientatio[:-1].isdigit():
            orientatio = f"{int(orientatio[:-1]):02d}h"

        # ======================================================
        # ORIENTATION
        # ======================================================

        if orientatio in (
            "03h",
            "04h",
            "05h",
        ):

            angle = (
                azimuth - pi / 2
            )

        elif orientatio in (
            "06h",
            "07h",
            "08h",
            "09h",
            "10h",
            "11h",
        ):

            angle = (
                azimuth + pi / 2
            )

        elif orientatio == "12h":

            angle = azimuth

        else:
            return None

        # ======================================================
        # LONGUEUR
        # ======================================================

        longueur = 3.0

        # ======================================================
        # PROJECTION
        # ======================================================

        end_point = self._project_point(
            point,
            longueur,
            angle,
        )

        if end_point is None:
            return None

        # ======================================================
        # LIGNE
        # ======================================================

        return LineString([
            (
                point.x,
                point.y,
            ),
            (
                end_point.x,
                end_point.y,
            ),
        ])

    # ==========================================================
    # PROJECTION
    # ==========================================================

    @staticmethod
    def _project_point(
        point: Point,
        distance: float,
        azimuth: float,
    ) -> Optional[Point]:
        """
        Projette un point selon un azimut.

        Convention utilisée :

            x = x + distance * sin(azimuth)
            y = y + distance * cos(azimuth)
        """

        if point is None:
            return None

        try:

            x = (
                point.x
                + distance * sin(azimuth)
            )

            y = (
                point.y
                + distance * cos(azimuth)
            )

            return Point(
                x,
                y,
            )

        except Exception:
            return None

    # ==========================================================
    # SUPPRESSION ANCIENNE COUCHE
    # ==========================================================

    def _remove_existing_layer(self):
        """
        Supprime l'ancienne couche BCA.
        """

        project = QgsProject.instance()

        layers_to_remove = []

        for layer in project.mapLayers().values():

            if layer.name() == self.layer_name:

                layers_to_remove.append(
                    layer.id()
                )

        for layer_id in layers_to_remove:

            project.removeMapLayer(
                layer_id
            )

    # ==========================================================
    # STYLE FLÈCHE
    # ==========================================================

    def _apply_arrow_style(
        self,
        layer: QgsVectorLayer,
    ):
        """
        Applique une symbologie bleue avec ligne fine
        et tête de flèche visible.
        """

        if layer is None:
            return

        # ------------------------------------------------------
        # Ligne principale
        # ------------------------------------------------------

        symbol = QgsLineSymbol.createSimple({
            "color": "0,0,255,255",
            "width": "1.2",
        })

        # ------------------------------------------------------
        # Tête de flèche
        # ------------------------------------------------------

        arrow_symbol = QgsArrowSymbolLayer.create({
            "is_curved": "0",
            "arrow_width": "2.0",
            "arrow_start_width": "0",
            "head_length": "6",
            "head_thickness": "1.5",
            "head_type": "0",
            "color": "0,0,255,255",
            "outline_color": "0,0,255,255",
        })

        # ------------------------------------------------------
        # Ajout de la flèche
        # ------------------------------------------------------

        if arrow_symbol is not None:
            symbol.appendSymbolLayer(arrow_symbol)

        # ------------------------------------------------------
        # Renderer
        # ------------------------------------------------------

        layer.setRenderer(
            QgsSingleSymbolRenderer(symbol)
        )

        layer.triggerRepaint()

