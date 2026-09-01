from qgis.core import (
    QgsVectorLayer,
    QgsFeature,
    QgsField,
    QgsGeometry,
)
from qgis.PyQt.QtCore import QVariant


class BranchGeometryCalculator:
    """
    Reproduit côté PyQGIS la logique de itv.get_bcht_positions().

    Le calcul est fait uniquement à partir :
      - des détails ITV (BCA),
      - de la couche des regards,
      - éventuellement de la couche des collecteurs.

    Aucun accès à la base de données n'est effectué ici.
    """

    def __init__(self, iface=None):
        self.iface = iface

    def _normalize_key(self, value):
        """
        Normalise une clé d'identifiant pour fiabiliser les jointures
        (casse, espaces, zéros initiaux sur valeurs numériques).
        """
        if value is None:
            return None

        text = str(value).strip()
        if not text:
            return None

        if text.isdigit():
            return text.lstrip("0") or "0"

        return text.upper()

    def _is_bca(self, obj):
        """
        Retourne True si l'objet représente un BCA.
        """
        fam_obs = getattr(obj, "fam_obs", None)
        if fam_obs is None:
            return False
        return str(fam_obs).strip().upper() == "BCA"

    def _iter_bca_entries(self, details):
        """
        Retourne les BCA sous forme de couples (parent_detail, bca_obj),
        en couvrant à la fois les BCA portés par Detail et par defauts.
        """
        for detail in details or []:
            if self._is_bca(detail):
                yield detail, detail

            for defect in (getattr(detail, "defauts", None) or []):
                if self._is_bca(defect):
                    yield detail, defect



    def get_branch_positions(
        self,
        details,
        layer_regard,
        layer_collecteur=None,
        id_field_regard="id",
        id_field_collecteur="id",
    ):
        """
        Calcule la position géographique des branchements BCA.

        Parameters
        ----------
        details : list
            Liste des objets Detail.

        layer_regard : QgsVectorLayer
            Couche contenant les regards.

        layer_collecteur : QgsVectorLayer, optional
            Couche contenant les tronçons/collecteurs.

        id_field_regard : str
            Champ permettant d'identifier un regard.

        id_field_collecteur : str
            Champ permettant d'identifier un collecteur.

        Returns
        -------
        QgsVectorLayer
            Couche mémoire de points exploitable dans QGIS.
        """

        if not layer_regard or not layer_regard.isValid():
            raise ValueError("La couche des regards est invalide.")

        # Index des regards pour éviter de parcourir toute la couche
        regards = self._build_feature_index(
            layer_regard,
            id_field_regard
        )

        collecteurs = {}

        if layer_collecteur and layer_collecteur.isValid():
            collecteurs = self._build_feature_index(
                layer_collecteur,
                id_field_collecteur
            )

       

        crs = layer_regard.crs()

        result = QgsVectorLayer(
            f"Point?crs={crs.authid()}",
            "itv_details_bcht",
            "memory"
        )

        provider = result.dataProvider()

        provider.addAttributes([
            QgsField("id", QVariant.Int),
            QgsField("x", QVariant.Double),
            QgsField("y", QVariant.Double),
            QgsField("code", QVariant.String),
            QgsField("libelle", QVariant.String),
            QgsField("orientatio", QVariant.String),
            QgsField("sens_inspe", QVariant.String),
            QgsField("type_mat", QVariant.String),
            QgsField("diametre", QVariant.String),
            QgsField("id_reg_ent", QVariant.String),
            QgsField("id_reg_sor", QVariant.String),
        ])

        result.updateFields()

        features_result = []

        

        row_id = 1
        for parent_detail, bca in self._iter_bca_entries(details):

            id_reg_ent = getattr(bca, "id_reg_ent", None)
            if id_reg_ent is None:
                id_reg_ent = getattr(parent_detail, "id_reg_ent", None)

            id_reg_sor = getattr(bca, "id_reg_sor", None)
            if id_reg_sor is None:
                id_reg_sor = getattr(parent_detail, "id_reg_sor", None)

            id_troncon = getattr(bca, "id_troncon", None)
            if id_troncon is None:
                id_troncon = getattr(parent_detail, "id_troncon", None)

            metrage = getattr(bca, "metrage", None)
            if metrage is None:
                metrage = getattr(parent_detail, "metrage", None)

            if metrage is None:
                continue

            

            regard_ent = self._find_feature(
                regards,
                id_reg_ent
            )

            regard_sor = self._find_feature(
                regards,
                id_reg_sor
            )

            if not regard_ent or not regard_sor:
                continue

            geom_ent = regard_ent.geometry()
            geom_sor = regard_sor.geometry()

            if geom_ent.isEmpty() or geom_sor.isEmpty():
                continue

            
            point = None

            if collecteurs and id_troncon is not None:
                collecteur = self._find_feature(
                    collecteurs,
                    id_troncon
                )

                if collecteur:
                    troncon_geom = collecteur.geometry()
                    if troncon_geom and not troncon_geom.isEmpty():
                        point = self._calculate_on_troncon(
                            troncon_geom,
                            geom_ent,
                            geom_sor,
                            float(metrage)
                        )

            if point is None:
                point = self._calculate_between_regards(
                    geom_ent,
                    geom_sor,
                    float(metrage)
                )

            if point is None:
                continue

            feature = QgsFeature(result.fields())

            feature.setGeometry(
                QgsGeometry.fromPointXY(point)
            )

            feature.setAttributes([
                row_id,
                point.x(),
                point.y(),
                getattr(bca, "code_obs", None) or getattr(parent_detail, "code_obs", None),
                getattr(bca, "libel_obs", None) or getattr(parent_detail, "libel_obs", None),
                getattr(bca, "orientatio", None) or getattr(parent_detail, "orientatio", None),
                getattr(bca, "sens_ecoul", None) or getattr(parent_detail, "sens_ecoul", None),
                None,
                None,
                str(id_reg_ent) if id_reg_ent is not None else None,
                str(id_reg_sor) if id_reg_sor is not None else None,
            ])

            features_result.append(feature)
            row_id += 1

        provider.addFeatures(features_result)
        result.updateExtents()

        return result

   

    def _build_feature_index(self, layer, field_name):
        """
        Construit un dictionnaire :

            valeur du champ -> QgsFeature

        Exemple :

            {
                "REG001": feature,
                "REG002": feature,
                ...
            }
        """

        index = {}

        field_index = layer.fields().indexOf(field_name)

        if field_index == -1:
            raise ValueError(
                f"Le champ '{field_name}' n'existe pas dans "
                f"la couche '{layer.name()}'."
            )

        for feature in layer.getFeatures():

            value = feature.attribute(field_index)

            normalized = self._normalize_key(value)
            if normalized is not None:
                index[normalized] = feature

        return index

  
    def _find_feature(self, index, value):
        """
        Recherche une feature dans un index.

        On convertit en str car :
            123
        et
            "123"

        doivent être considérés comme le même identifiant.
        """

        if value is None:
            return None

        return index.get(self._normalize_key(value))


    def _calculate_on_troncon(
        self,
        troncon_geom,
        regard_ent_geom,
        regard_sor_geom,
        metrage
    ):
        """
        Reproduit la partie :

            direction
            +
            ST_LineInterpolatePoint()

        de la fonction SQL.
        """

        if troncon_geom.isMultipart():

            parts = troncon_geom.asMultiPolyline()

            if not parts:
                return None

            # On prend la première partie.
            # Si tes collecteurs sont réellement multipart,
            # cette partie pourra être améliorée.
            points = parts[0]

            troncon_geom = QgsGeometry.fromPolylineXY(points)

        if troncon_geom.isEmpty():
            return None



        start_point = troncon_geom.interpolate(0)

        if start_point.isEmpty():
            return None

        distance_ent = start_point.distance(
            regard_ent_geom
        )

        distance_sor = start_point.distance(
            regard_sor_geom
        )

        if distance_ent < distance_sor:
            direction_forward = True
        else:
            direction_forward = False



        longueur = troncon_geom.length()

        if longueur <= 0:
            return None

        # Même logique que SQL :
        #
        # LEAST(metrage, longueur) / longueur
        #
        distance = min(
            max(float(metrage), 0.0),
            longueur
        )

        fraction = distance / longueur

       

        if not direction_forward:
            troncon_geom = self._reverse_geometry(
                troncon_geom
            )



        point_geom = troncon_geom.interpolate(
            fraction * troncon_geom.length()
        )

        if point_geom.isEmpty():
            return None

        return point_geom.asPoint()



    def _calculate_between_regards(
        self,
        regard_ent_geom,
        regard_sor_geom,
        metrage
    ):
        """
        Reproduit la partie SQL utilisée lorsqu'il n'existe
        pas de couche collecteur.

        On crée une ligne :

            regard entrant -------- regard sortant

        puis on interpole dessus.
        """

        point_ent = regard_ent_geom.asPoint()
        point_sor = regard_sor_geom.asPoint()

        ligne = QgsGeometry.fromPolylineXY([
            point_ent,
            point_sor
        ])

        longueur = ligne.length()

        if longueur <= 0:
            return None

        distance = min(
            max(float(metrage), 0.0),
            longueur
        )

        fraction = distance / longueur

        point_geom = ligne.interpolate(
            fraction * longueur
        )

        if point_geom.isEmpty():
            return None

        return point_geom.asPoint()



    def _reverse_geometry(self, geometry):
        """
        Inverse le sens d'une LineString.
        """

        if geometry.isMultipart():

            parts = geometry.asMultiPolyline()

            reversed_parts = []

            for part in parts:
                reversed_parts.append(
                    list(reversed(part))
                )

            return QgsGeometry.fromMultiPolylineXY(
                reversed_parts
            )

        points = geometry.asPolyline()

        if not points:
            return geometry

        return QgsGeometry.fromPolylineXY(
            list(reversed(points))
        )