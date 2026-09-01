Installation
============

1. Installez GeoITV depuis le gestionnaire d'extensions QGIS lorsque la version est publiée, ou copiez le dossier du plugin dans le répertoire des extensions QGIS pour une installation manuelle.
2. Activez GeoITV dans le gestionnaire d'extensions.
3. Ouvrez le plugin depuis le menu Extensions.

Le mode standard FullPython ne requiert aucune connexion à une base de données. Il s'exécute dans l'environnement Python de QGIS et requiert la bibliothèque Shapely. GDAL/OGR est fourni par les installations QGIS standards.

Le mode DB legacy requiert PostgreSQL 12 ou supérieur avec PostGIS 3.4 ou supérieur, ainsi que le schéma ``itv`` créé avec ``resources/create_schema_itv.sql``. Les couches SIG utilisées en base doivent avoir un SRID défini.

Dépendances principales :
- QGIS (PyQt, qgis.core)
- psycopg2 (uniquement pour le mode DB legacy)