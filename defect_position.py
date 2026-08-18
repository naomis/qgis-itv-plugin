"""
Module pour calculer les géométries des défauts ITV en fonction des regards/collecteurs et du métrage.
Utilise PyQGIS et Shapely pour les calculs géométriques.
"""

from qgis.core import (
    QgsVectorLayer,
    QgsFeature,
    QgsGeometry,
    QgsPointXY,
    QgsFields,
    QgsField,
    QgsWkbTypes,
    QgsCoordinateReferenceSystem,
    QgsProject,
)
from PyQt5.QtCore import QVariant
from shapely.geometry import Point, LineString, MultiLineString
import math

class DefectGeometryCalculator:
    """
    Classe pour calculer les géométries des défauts en fonction des regards/collecteurs et du métrage.
    """

    def __init__(self, iface=None):
        self.iface = iface

    def get_geometries_from_layer(self, layer, id_field_name: str = "id") -> dict:
        """
        Récupère les géométries d'une couche QGIS et retourne un dictionnaire {id: géométrie}.
        Args:
            layer: QgsVectorLayer - La couche QGIS.
            id_field_name: str - Le nom du champ contenant l'ID (ex: "id", "gid").
        Returns:
            dict: Dictionnaire {id: géométrie (QgsPointXY ou QgsGeometry)}.
        """
        if not layer:
            return {}

        geometries = {}
        field_names = [f.name() for f in layer.fields()]

        for feat in layer.getFeatures():
            if id_field_name not in field_names:
                continue  # Champ ID absent dans la couche

            key = feat[id_field_name]
            if key is None:
                continue

            g = feat.geometry()
            if g is None or g.isEmpty():
                continue
            try:
                if QgsWkbTypes.geometryType(g.wkbType()) == QgsWkbTypes.PointGeometry:
                    try:
                        pt = g.asPoint()
                        geometries[key] = QgsPointXY(pt)
                    except Exception:
                        mpts = g.asMultiPoint()
                        if mpts:
                            geometries[key] = QgsPointXY(mpts[0])
                else:
                    geometries[key] = g 
            except Exception as e:
                print(f"Erreur lors de la lecture de la géométrie pour la feature {feat.id()}: {e}")

        return geometries

    def interpolate_point_along_line(self, line: LineString, metrage: float) -> Point | None:
        """
        Interpole un point sur une LineString à une distance `metrage` depuis le début.
        Args:
            line: LineString - La ligne Shapely.
            metrage: float - La distance depuis le début de la ligne.
        Returns:
            Point | None: Le point interpolé ou None si impossible.
        """
        if metrage < 0:
            return None

        line_length = line.length
        if line_length == 0:
            return None

        if metrage > line_length:
            metrage = line_length

        ratio = metrage / line_length
        return line.interpolate(ratio)

    def interpolate_point_between_points(self, point1: Point, point2: Point, metrage: float) -> Point | None:
        """
        Interpole un point entre deux points à une distance `metrage` depuis point1.
        Args:
            point1: Point - Premier point Shapely.
            point2: Point - Deuxième point Shapely.
            metrage: float - La distance depuis point1.
        Returns:
            Point | None: Le point interpolé ou None si impossible.
        """
        x1, y1 = point1.x, point1.y
        x2, y2 = point2.x, point2.y
        distance = math.sqrt((x2 - x1)**2 + (y2 - y1)**2)

        if distance == 0:
            return None

        if metrage < 0:
            return None

        if metrage > distance:
            metrage = distance

        ratio = metrage / distance
        x = x1 + ratio * (x2 - x1)
        y = y1 + ratio * (y2 - y1)
        return Point(x, y)

    def calculate_defect_geometry(
        self,
        defect: dict,
        geometries_reg: dict,
        geometries_coll: dict
    ) -> dict:
        """
        Calcule la géométrie d'un défaut en fonction des regards/collecteurs et du métrage.
        Args:
            defect: dict - Dictionnaire contenant les informations du défaut.
            geometries_reg: dict - Dictionnaire des géométries des regards {id: géométrie}.
            geometries_coll: dict - Dictionnaire des géométries des collecteurs {id: géométrie}.
        Returns:
            dict: Le défaut avec un champ `geometry` ajouté (ou None si impossible).
        """
        geometry = None
        id_reg_ent = defect.get("id_reg_ent")
        id_reg_sor = defect.get("id_reg_sor")
        id_troncon = defect.get("id_troncon")
        metrage = defect.get("metrage")

        if id_troncon is not None and metrage is not None and id_troncon in geometries_coll:
            geom = geometries_coll[id_troncon]
            if isinstance(geom, LineString):
                geometry = self.interpolate_point_along_line(geom, metrage)
            elif isinstance(geom, MultiLineString):
                geometry = self.interpolate_point_along_line(geom.geoms[0], metrage)
            elif isinstance(geom, QgsGeometry):
                try:
                    line = self._qgs_geometry_to_shapely_line(geom)
                    if line:
                        geometry = self.interpolate_point_along_line(line, metrage)
                except Exception:
                    geometry = None

        if geometry is None and id_reg_ent is not None and id_reg_sor is not None and metrage is not None:
            if id_reg_ent in geometries_reg and id_reg_sor in geometries_reg:
                geom1 = geometries_reg[id_reg_ent]
                geom2 = geometries_reg[id_reg_sor]
                if isinstance(geom1, Point) and isinstance(geom2, Point):
                    geometry = self.interpolate_point_between_points(geom1, geom2, metrage)
                elif isinstance(geom1, QgsPointXY) and isinstance(geom2, QgsPointXY):
                    pt1 = Point(geom1.x(), geom1.y())
                    pt2 = Point(geom2.x(), geom2.y())
                    geometry = self.interpolate_point_between_points(pt1, pt2, metrage)

        if geometry:
            defect["geometry"] = geometry
        else:
            print(f"Impossible de calculer la géométrie pour le défaut : {defect}")

        return defect

    def _qgs_geometry_to_shapely_line(self, qgs_geom: QgsGeometry) -> LineString | None:
        """
        Convertit une QgsGeometry en LineString Shapely.
        Args:
            qgs_geom: QgsGeometry - Géométrie QGIS.
        Returns:
            LineString | None: Ligne Shapely ou None si la conversion échoue.
        """
        try:
            if QgsWkbTypes.geometryType(qgs_geom.wkbType()) == QgsWkbTypes.LineGeometry:
                line = qgs_geom.asPolyline()
                if line:
                    return LineString([(pt.x(), pt.y()) for pt in line])
            elif QgsWkbTypes.geometryType(qgs_geom.wkbType()) == QgsWkbTypes.MultiLineGeometry:
                multi_line = qgs_geom.asMultiPolyline()
                if multi_line and len(multi_line) > 0:
                    return LineString([(pt.x(), pt.y()) for pt in multi_line[0]])
        except Exception:
            pass
        return None

    def calculate_defects_geometry(
        self,
        defects: list[dict],
        geometries_reg: dict,
        geometries_coll: dict
    ) -> list[dict]:
        """
        Calcule les géométries pour une liste de défauts.
        Args:
            defects: list[dict] - Liste des défauts.
            geometries_reg: dict - Dictionnaire des géométries des regards.
            geometries_coll: dict - Dictionnaire des géométries des collecteurs.
        Returns:
            list[dict]: Liste des défauts avec les géométries calculées.
        """
        updated_defects = []
        for defect in defects:
            updated_defect = self.calculate_defect_geometry(defect, geometries_reg, geometries_coll)
            updated_defects.append(updated_defect)
        return updated_defects

    def create_temp_layer_from_defects(
        self,
        defects: list[dict],
        layer_name: str = "Défauts ITV",
        crs: QgsCoordinateReferenceSystem = None
    ) -> QgsVectorLayer:
        """
        Crée une couche temporaire de points à partir des défauts avec géométrie.
        Args:
            defects: list[dict] - Liste des défauts avec géométrie.
            layer_name: str - Nom de la couche.
            crs: QgsCoordinateReferenceSystem - Système de coordonnées (optionnel).
        Returns:
            QgsVectorLayer: Couche temporaire avec les défauts.
        """
        if not crs:
            crs = QgsCoordinateReferenceSystem("EPSG:4326")

        fields = QgsFields()
        fields.append(QgsField("gid", QVariant.Int))
        fields.append(QgsField("code_obs", QVariant.String))
        fields.append(QgsField("libel_obs", QVariant.String))
        fields.append(QgsField("metrage", QVariant.Double))
        fields.append(QgsField("id_reg_ent", QVariant.Int))
        fields.append(QgsField("id_reg_sor", QVariant.Int))
        fields.append(QgsField("id_troncon", QVariant.Int))

        layer = QgsVectorLayer(f"Point?crs={crs.authid()}", layer_name, "memory")
        provider = layer.dataProvider()

        provider.addAttributes(fields.toList())
        layer.updateFields()

        features = []
        for defect in defects:
            if "geometry" not in defect or defect["geometry"] is None:
                continue

            geom_shapely = defect["geometry"]
            if not geom_shapely:
                continue

            qgs_geom = QgsGeometry.fromWkt(geom_shapely.to_wkt())

            feature = QgsFeature()
            feature.setGeometry(qgs_geom)

            feature.setAttributes([
                defect.get("gid", 0),
                defect.get("code_obs", ""),
                defect.get("libel_obs", ""),
                defect.get("metrage", 0.0),
                defect.get("id_reg_ent", None),
                defect.get("id_reg_sor", None),
                defect.get("id_troncon", None)
            ])

            features.append(feature)

        provider.addFeatures(features)
        layer.updateExtents()
        return layer

    def get_defect_positions(
        self,
        defects: list[dict],
        layer_regard: QgsVectorLayer,
        layer_collecteur: QgsVectorLayer,
        id_field_regard: str = "id",
        id_field_collecteur: str = "id"
    ) -> QgsVectorLayer:
        """
        Calcule les positions des défauts et retourne une couche temporaire avec les résultats.
        Fonctionne même si layer_collecteur est None.
        Args:
            defects: list[dict] - Liste des défauts.
            layer_regard: QgsVectorLayer - Couche des regards.
            layer_collecteur: QgsVectorLayer - Couche des collecteurs (peut être None).
            id_field_regard: str - Nom du champ ID pour les regards.
            id_field_collecteur: str - Nom du champ ID pour les collecteurs.
        Returns:
            QgsVectorLayer: Couche temporaire avec les défauts et leurs géométries.
        """
        geometries_reg = self.get_geometries_from_layer(layer_regard, id_field_regard)
        geometries_coll = self.get_geometries_from_layer(layer_collecteur, id_field_collecteur) if layer_collecteur else {}

        if layer_collecteur and layer_collecteur.crs().isValid():
            crs = layer_collecteur.crs()
        elif layer_regard and layer_regard.crs().isValid():
            crs = layer_regard.crs()
        else:
            crs = QgsProject.instance().crs()

        layer_name = "Défauts ITV"
        mem = QgsVectorLayer(f"Point?crs={crs.authid()}", layer_name, "memory")
        prov = mem.dataProvider()
        fields = QgsFields()
        fields.append(QgsField("gid", QVariant.Int))
        fields.append(QgsField("code_obs", QVariant.String))
        fields.append(QgsField("libel_obs", QVariant.String))
        fields.append(QgsField("metrage", QVariant.Double))
        fields.append(QgsField("id_reg_ent", QVariant.Int))
        fields.append(QgsField("id_reg_sor", QVariant.Int))
        fields.append(QgsField("id_troncon", QVariant.Int))
        prov.addAttributes(fields.toList())
        mem.updateFields()

        feats = []
        for d in defects:
            metrage = d.get("metrage")
            pt_geom = None

            id_troncon = d.get("id_troncon")
            id_reg_ent = d.get("id_reg_ent")
            id_reg_sor = d.get("id_reg_sor")

            if layer_collecteur and id_troncon is not None and metrage is not None and id_troncon in geometries_coll:
                line_geom = geometries_coll[id_troncon]
                if isinstance(line_geom, QgsGeometry):
                    try:
                        interp = line_geom.interpolate(float(metrage))
                        if interp and not interp.isEmpty():
                            pt_geom = interp
                    except Exception:
                        try:
                            mlines = line_geom.asMultiPolyline()
                            if mlines and len(mlines) > 0:
                                first_pts = [QgsPointXY(x, y) for x, y in mlines[0]]
                                first_line = QgsGeometry.fromPolylineXY(first_pts)
                                interp = first_line.interpolate(float(metrage))
                                if interp and not interp.isEmpty():
                                    pt_geom = interp
                        except Exception:
                            pt_geom = None

            if pt_geom is None and id_reg_ent is not None and id_reg_sor is not None and metrage is not None:
                if id_reg_ent in geometries_reg and id_reg_sor in geometries_reg:
                    p1 = geometries_reg[id_reg_ent]
                    p2 = geometries_reg[id_reg_sor]
                    if isinstance(p1, QgsPointXY) and isinstance(p2, QgsPointXY):
                        dx = p2.x() - p1.x()
                        dy = p2.y() - p1.y()
                        dist = math.hypot(dx, dy)
                        if dist > 0:
                            d_metrage = float(metrage)
                            if d_metrage < 0:
                                continue
                            if d_metrage > dist:
                                d_metrage = dist
                            ratio = d_metrage / dist
                            x = p1.x() + ratio * dx
                            y = p1.y() + ratio * dy
                            pt_geom = QgsGeometry.fromPointXY(QgsPointXY(x, y))

            if pt_geom is None or pt_geom.isEmpty():
                continue 

            feat = QgsFeature(mem.fields())
            feat.setGeometry(pt_geom)
            feat.setAttributes([
                d.get("gid", 0),
                d.get("code_obs", ""),
                d.get("libel_obs", ""),
                float(d.get("metrage", 0.0)) if d.get("metrage") is not None else None,
                d.get("id_reg_ent", None),
                d.get("id_reg_sor", None),
                d.get("id_troncon", None)
            ])
            feats.append(feat)

        prov.addFeatures(feats)
        mem.updateExtents()
        return mem