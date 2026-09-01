Utilisation
===========

1. Ouvrez GeoITV depuis le menu Extensions de QGIS.
2. Sélectionnez le fichier TXT d'inspection conforme à NF EN 13508-2+A1.
3. Sélectionnez la couche des regards et son champ identifiant. La couche collecteur est facultative.
4. Ajoutez, si nécessaire, les fichiers CSV de correspondance entre les identifiants ITV et SIG.
5. Lancez le traitement.

Le mode standard FullPython ajoute les couches ``itv_inspection``, ``itv_details``, ``itv_details_bcht`` et ``itv_details_bcht_lines`` au projet. Les erreurs sont signalées en rouge, les avertissements métier en orange et une exécution complète en vert.

Le mode DB legacy est disponible dans Extensions > GeoITV > Configuration. Il importe les données dans PostgreSQL/PostGIS et charge les vues SQL associées.