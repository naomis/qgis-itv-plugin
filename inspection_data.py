from qgis.core import (
    QgsVectorLayer,
    QgsFeature,
    QgsField,
    QgsGeometry,
)
from qgis.PyQt.QtCore import QVariant


class InspectionGeometryCalculator:
    """
    Reproduit côté PyQGIS la logique de génération de la géométrie
    d'une inspection.

    Les données sont fournies directement par les objets Python
    et les couches QGIS.
    """

    def __init__(self, iface=None):
        self.iface = iface

    # ------------------------------------------------------------------
    # MÉTHODE PRINCIPALE
    # ------------------------------------------------------------------

    def get_inspection_geometry(
        self,
        inspection_gid,
        details,
        layer_regard,
        layer_collecteur=None,
        id_field_regard="id",
        id_field_collecteur="id",
    ):
        """
        Calcule la géométrie d'une inspection.

        Parameters
        ----------
        inspection_gid : int
            Identifiant de l'inspection.

        details : list
            Liste des objets Detail.

        layer_regard : QgsVectorLayer
            Couche des regards.

        layer_collecteur : QgsVectorLayer, optional
            Couche des collecteurs.

        id_field_regard : str
            Champ identifiant les regards.

        id_field_collecteur : str
            Champ identifiant les collecteurs.

        Returns
        -------
        QgsVectorLayer
            Couche mémoire contenant le polygone de l'inspection.
        """

        # --------------------------------------------------------------
        # Vérification des couches
        # --------------------------------------------------------------

        if not layer_regard or not layer_regard.isValid():
            raise ValueError(
                "La couche des regards est invalide."
            )

        if (
            layer_collecteur is not None
            and not layer_collecteur.isValid()
        ):
            raise ValueError(
                "La couche des collecteurs est invalide."
            )

        # --------------------------------------------------------------
        # Création des index
        # --------------------------------------------------------------

        regards = self._build_feature_index(
            layer_regard,
            id_field_regard
        )

        collecteurs = {}

        if layer_collecteur is not None:
            collecteurs = self._build_feature_index(
                layer_collecteur,
                id_field_collecteur
            )

        # --------------------------------------------------------------
        # Récupération des géométries
        # --------------------------------------------------------------

        geom_collecteurs = []
        geom_regards = []

        # --------------------------------------------------------------
        # Parcours des détails
        # --------------------------------------------------------------

        for detail in details:

            # ----------------------------------------------------------
            # Vérification de l'inspection
            # ----------------------------------------------------------

            detail_inspection_gid = getattr(
                detail,
                "inspection_gid",
                None
            )

            if (
                detail_inspection_gid is not None
                and str(detail_inspection_gid)
                != str(inspection_gid)
            ):
                continue

            # ----------------------------------------------------------
            # Récupération des identifiants
            # ----------------------------------------------------------

            id_troncon = getattr(
                detail,
                "id_troncon",
                None
            )

            id_reg_ent = getattr(
                detail,
                "id_reg_ent",
                None
            )

            id_reg_sor = getattr(
                detail,
                "id_reg_sor",
                None
            )

            # ----------------------------------------------------------
            # Regard entrée
            # ----------------------------------------------------------

            geom_ent = self._get_geometry_from_index(
                regards,
                id_reg_ent
            )

            if geom_ent is not None:
                geom_regards.append(
                    geom_ent
                )

            # ----------------------------------------------------------
            # Regard sortie
            # ----------------------------------------------------------

            geom_sor = self._get_geometry_from_index(
                regards,
                id_reg_sor
            )

            if geom_sor is not None:
                geom_regards.append(
                    geom_sor
                )

            # ----------------------------------------------------------
            # Collecteur
            # ----------------------------------------------------------

            if collecteurs and id_troncon is not None:

                geom_collecteur = (
                    self._get_geometry_from_index(
                        collecteurs,
                        id_troncon
                    )
                )

                if geom_collecteur is not None:
                    geom_collecteurs.append(
                        geom_collecteur
                    )

        # --------------------------------------------------------------
        # Suppression des doublons
        # --------------------------------------------------------------

        geom_collecteurs = (
            self._remove_duplicate_geometries(
                geom_collecteurs
            )
        )

        geom_regards = (
            self._remove_duplicate_geometries(
                geom_regards
            )
        )

        # --------------------------------------------------------------
        # Union des collecteurs
        # --------------------------------------------------------------

        geom_coll = self._union_geometries(
            geom_collecteurs
        )

        # --------------------------------------------------------------
        # Union des regards
        # --------------------------------------------------------------

        geom_reg = self._union_geometries(
            geom_regards
        )

        # --------------------------------------------------------------
        # Construction de la géométrie finale
        # --------------------------------------------------------------

        geom_finale = self._build_inspection_geometry(
            geom_coll,
            geom_reg
        )

        # --------------------------------------------------------------
        # Création de la couche résultat
        # --------------------------------------------------------------

        return self._create_result_layer(
            layer_regard,
            inspection_gid,
            geom_finale,
            len(geom_collecteurs),
            len(geom_regards)
        )

    # ------------------------------------------------------------------
    # INDEX DES FEATURES
    # ------------------------------------------------------------------

    def _build_feature_index(
        self,
        layer,
        field_name
    ):
        """
        Construit un dictionnaire :

            valeur du champ -> QgsFeature

        Exemple :

            {
                "REG001": feature,
                "REG002": feature,
                "REG003": feature
            }
        """

        index = {}

        field_index = layer.fields().indexOf(
            field_name
        )

        if field_index == -1:
            raise ValueError(
                f"Le champ '{field_name}' "
                f"n'existe pas dans la couche "
                f"'{layer.name()}'."
            )

        for feature in layer.getFeatures():

            value = feature.attribute(
                field_index
            )

            if value is None:
                continue

            index[str(value)] = feature

        return index

    # ------------------------------------------------------------------
    # RÉCUPÉRATION D'UNE GÉOMÉTRIE
    # ------------------------------------------------------------------

    def _get_geometry_from_index(
        self,
        index,
        value
    ):
        """
        Recherche une feature dans un index et retourne
        directement sa géométrie.
        """

        if value is None:
            return None

        feature = index.get(
            str(value)
        )

        if feature is None:
            return None

        geometry = feature.geometry()

        if geometry is None:
            return None

        if geometry.isEmpty():
            return None

        return geometry

    # ------------------------------------------------------------------
    # UNION DES GÉOMÉTRIES
    # ------------------------------------------------------------------

    def _union_geometries(
        self,
        geometries
    ):
        """
        Reproduit :

            ST_Union(geom)

        côté PostGIS.

        Retourne une seule géométrie.
        """

        if not geometries:
            return None

        valid_geometries = []

        for geometry in geometries:

            if geometry is None:
                continue

            if geometry.isEmpty():
                continue

            valid_geometries.append(
                geometry
            )

        if not valid_geometries:
            return None

        result = QgsGeometry.unaryUnion(
            valid_geometries
        )

        if result is None:
            return None

        if result.isEmpty():
            return None

        return result

    # ------------------------------------------------------------------
    # CONSTRUCTION DE LA GÉOMÉTRIE FINALE
    # ------------------------------------------------------------------

    def _build_inspection_geometry(
        self,
        geom_coll,
        geom_reg
    ):
        """
        Construit un rectangle englobant toutes les géométries
        de l'inspection.
        """

        geometries = []

        if geom_coll is not None and not geom_coll.isEmpty():
            geometries.append(geom_coll)

        if geom_reg is not None and not geom_reg.isEmpty():
            geometries.append(geom_reg)

        if not geometries:
            return None

        union_geometry = QgsGeometry.unaryUnion(
            geometries
        )

        if union_geometry is None or union_geometry.isEmpty():
            return None

        rect = union_geometry.boundingBox()

        if rect.isNull():
            return None

        return QgsGeometry.fromRect(rect)

    # ------------------------------------------------------------------
    # SUPPRESSION DES DOUBLONS
    # ------------------------------------------------------------------

    def _remove_duplicate_geometries(
        self,
        geometries
    ):
        """
        Supprime les géométries identiques.

        Un même collecteur peut être référencé plusieurs fois
        dans les détails de l'inspection.
        """

        result = []
        seen = set()

        for geometry in geometries:

            if (
                geometry is None
                or geometry.isEmpty()
            ):
                continue

            key = bytes(
                geometry.asWkb()
            )

            if key in seen:
                continue

            seen.add(key)

            result.append(
                geometry
            )

        return result

    # ------------------------------------------------------------------
    # CRÉATION DE LA COUCHE RÉSULTAT
    # ------------------------------------------------------------------

    def _create_result_layer(
        self,
        reference_layer,
        inspection_gid,
        geometry,
        nb_collecteurs,
        nb_regards
    ):
        """
        Crée la couche mémoire contenant le polygone final.
        """

        crs = reference_layer.crs()

        result = QgsVectorLayer(
            f"Polygon?crs={crs.authid()}",
            "itv_inspection_geometry",
            "memory"
        )

        provider = result.dataProvider()

        provider.addAttributes([
            QgsField(
                "nb_collecteurs",
                QVariant.Int
            ),

            QgsField(
                "nb_regards",
                QVariant.Int
            ),
        ])

        result.updateFields()

        # --------------------------------------------------------------
        # Aucune géométrie
        # --------------------------------------------------------------

        if geometry is None or geometry.isEmpty():
            return result

        # --------------------------------------------------------------
        # Création de la feature
        # --------------------------------------------------------------

        feature = QgsFeature(
            result.fields()
        )

        feature.setGeometry(
            geometry
        )

        feature.setAttributes([
            nb_collecteurs,
            nb_regards,
        ])

        provider.addFeature(
            feature
        )

        result.updateExtents()

        return result