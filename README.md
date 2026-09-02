# GeoITV

<p align="center">
  <img src="assets/icon_192x192.png" alt="Logo GeoITV" width="112">
</p>

GeoITV est un plugin QGIS open source pour géolocaliser les défauts et les branchements issus de fichiers d'inspection télévisée au format NF EN 13508-2+A1.

La version 1.0.3 propose deux modes d'exécution : FullPython, le mode standard sans base de données, et DB legacy pour les organisations qui souhaitent conserver les données dans PostgreSQL/PostGIS.

## Fonctionnalités

- Lecture des fichiers TXT d'inspection ITV.
- Géolocalisation des défauts, branchements BCA et emprise d'inspection.
- Jointure avec les couches SIG de regards et, facultativement, de collecteurs.
- Import de fichiers CSV de correspondance entre identifiants ITV et SIG.
- Signalement des correspondances SIG absentes et des écarts de longueur de tronçon supérieurs à 2 m.
- Styles QGIS fournis pour les couches de résultats.

## Installation

### Depuis QGIS

Après publication, installez GeoITV depuis le gestionnaire d'extensions QGIS : `Extensions > Installer/Gérer les extensions`.

### Installation manuelle pour le développement

1. Clonez ce dépôt ou téléchargez son archive.
2. Copiez le dossier `qgis-itv-plugin` dans le répertoire des extensions du profil QGIS.
3. Redémarrez QGIS, puis activez GeoITV depuis `Extensions > Installer/Gérer les extensions`.

Sous Windows, le répertoire du profil par défaut est généralement `%APPDATA%\QGIS\QGIS3\profiles\default\python\plugins`.

Le script `deploy.ps1` permet de copier le plugin vers ce répertoire. Pour utiliser un autre profil ou emplacement, copiez `deploy.config.example.ps1` vers `deploy.config.ps1` et adaptez la configuration locale. Ce fichier est ignoré par Git.

## Configuration et utilisation

1. Ouvrez `Extensions > GeoITV`.
2. Sélectionnez le fichier TXT conforme à NF EN 13508-2+A1.
3. Sélectionnez la couche SIG des regards et le champ identifiant associé.
4. Sélectionnez facultativement la couche des collecteurs et son champ identifiant.
5. Ajoutez des CSV de correspondance si les identifiants ITV diffèrent des identifiants SIG.
6. Lancez le traitement.

Les erreurs sont affichées en rouge, les avertissements métier en orange et un traitement complet en vert. Le niveau `Debug`, disponible dans `Extensions > GeoITV > Configuration`, ajoute les informations techniques utiles au diagnostic.

## Modes d'exécution

### FullPython, mode standard

Ce mode ne requiert aucune base de données. Les calculs sont exécutés dans l'environnement Python de QGIS, avec PyQGIS et Shapely. QGIS fournit également GDAL/OGR pour la gestion des couches vectorielles.

Les résultats sont ajoutés au projet sous forme de couches mémoire :

- `itv_inspection` : emprise de l'inspection ;
- `itv_details` : défauts géolocalisés ;
- `itv_details_bcht` : points de branchement BCA ;
- `itv_details_bcht_lines` : orientations des branchements ;
- `itv_ids_reg` et `itv_ids_coll` : tables de correspondance ITV/SIG.

### DB legacy, PostgreSQL/PostGIS

Ce mode importe les données ITV et les couches SIG sélectionnées dans un schéma PostgreSQL/PostGIS, puis exécute les fonctions et vues SQL du schéma `itv`. Il est destiné aux workflows nécessitant la conservation centralisée des données et les vues SQL historiques.

Prérequis : PostgreSQL 12 ou supérieur, PostGIS 3.4 ou supérieur, et les droits nécessaires pour créer l'extension PostGIS, le schéma `itv` et les tables associées. Les couches SIG doivent avoir un SRID défini ; les calculs métriques sont réalisés en EPSG:2154.

Créez le schéma en exécutant [resources/create_schema_itv.sql](resources/create_schema_itv.sql) sur une base vide. Le script crée l'extension PostGIS, les tables, vues, fonctions, contraintes et index nécessaires.

## Démarrer PostGIS avec Docker

Docker est facultatif et n'est pas nécessaire au mode FullPython. Pour démarrer une base PostGIS locale depuis zéro :

```powershell
docker run --rm --name geoitv-postgis `
  --env-file .env.local `
  -e POSTGRES_DB=geoitv `
  -p 5432:5432 `
  -v geoitv-postgis-data:/var/lib/postgresql/data `
  postgis/postgis:17-3.5-alpine
```

Avant cette commande, créez localement le fichier `.env.local` avec la variable obligatoire attendue par l'image officielle `postgis/postgis` et une valeur robuste. Ce fichier est ignoré par Git.

Dans un second terminal PowerShell, créez le schéma :

```powershell
Get-Content -Raw resources\create_schema_itv.sql |
  docker exec -i geoitv-postgis psql -U postgres -d geoitv -v ON_ERROR_STOP=1
```

La base est alors accessible dans QGIS sur `localhost`, port `5432`, base `geoitv`, utilisateur `postgres`. Le volume Docker `geoitv-postgis-data` conserve les données lorsque le conteneur est recréé. Pour supprimer définitivement cet environnement :

```powershell
docker volume rm geoitv-postgis-data
```

## Développement

### Prérequis FullPython

Le mode FullPython requiert QGIS et son environnement Python, ainsi que la bibliothèque Python Shapely. GDAL/OGR est fourni avec les installations QGIS standards et est utilisé par QGIS pour lire et écrire les couches vectorielles.

Le code est sous licence [MIT](LICENSE). Les contributions, rapports de bugs et propositions d'amélioration sont les bienvenus via les [issues](https://github.com/naomis/qgis-itv-plugin/issues) et les pull requests.

Remerciements à Gabriel NOIRET et Kénan LACRAMPE pour leur participation au développement du plugin.

La documentation utilisateur complète est disponible après génération dans `help/build/html/index.html`.