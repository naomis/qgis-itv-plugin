.. GeoITV documentation master file, created by
   sphinx-quickstart on Sun Feb 12 17:11:03 2012.


GeoITV
===============

.. image:: ../../assets/icon_180x180.png
   :alt: Logo GeoITV
   :width: 120px
   :align: center

.. centered:: **GeoITV**

GeoITV, c’est l’outil open source pour intégrer et exploiter les inspections vidéo de réseaux d’assainissement dans QGIS.

À partir d’un fichier .txt normé NF EN 13508-2+A1, GeoITV :
- détermine la position précise des défauts observés,
- recense et oriente les regards et branchements,
- gère la correspondance entre identifiants SIG et ITV,
- visualise l’emprise de l’inspection et tous les objets détectés directement sur la carte.

En quelques clics, vos données ITV deviennent exploitables, croisées avec vos couches SIG, pour un suivi technique et patrimonial efficace.


Fonctionnalités principales
---------------------------

- Import de fichiers TXT ou CSV issus des inspections vidéo
- Conversion automatique vers des couches SIG (Shapefile, PostGIS)
- Visualisation des résultats dans QGIS
- Suivi temporel et spatial des inspections
- Gestion des erreurs et des incohérences via des fichiers de correspondance

Utilisation et intégration
--------------------------

GeoITV s’adresse aux utilisateurs SIG souhaitant intégrer efficacement des données d’inspection ITV dans leur base QGIS/PostGIS. Le plugin automatise l’import, la conversion et l’affichage, tout en assurant la cohérence avec la base de données existante. Il est conçu pour s’intégrer dans des workflows open source et mutualisés.

Fichiers de correspondance : la clé d’une intégration fiable
------------------------------------------------------------

Lors de l’import, il est fréquent que les identifiants utilisés dans les fichiers d’inspection (collecteurs, regards, etc.) diffèrent de ceux de votre SIG (noms, formats, conventions). Le fichier de correspondance permet de faire le lien entre ces deux mondes :

- Il associe chaque identifiant du fichier d’inspection à l’identifiant officiel de votre base SIG.
- Il garantit que les données importées sont correctement reliées à vos objets existants.

Ce fichier doit être au format CSV, avec au minimum :

- une colonne pour l’identifiant du fichier d’inspection
- une colonne pour l’identifiant SIG correspondant


Exemple de structure :

::

   id_reg (ou coll),id_sig
   RG_001,R_000145
   RG_002,R_000278




Création du schéma itv
----------------------

Le plugin GeoITV nécessite un schéma nommé `itv` dans une base PostgreSQL/PostGIS. Ce schéma structure et centralise toutes les données liées aux inspections de réseaux.

⚠️ Prérequis :
- Disposer d’une base PostgreSQL avec l’extension PostGIS activée.
- Être connecté avec un compte ayant les droits suffisants pour créer un schéma et ses objets (tables, vues, fonctions, etc.).

Le plugin fournit un backup SQL complet (dump PostgreSQL) prêt à l’emploi. Vous pouvez le télécharger directement depuis l’interface du plugin ou la documentation.

Procédure d’installation du schéma :

1. Préparez le code SQL :
   - Téléchargez le backup SQL fourni par le plugin.
   - Ouvrez-le dans votre éditeur ou outil SQL préféré.
   - Sélectionnez tout le code (Ctrl+A) et copiez-le (Ctrl+C).

2. Connectez-vous à votre base PostgreSQL/PostGIS.

3. Collez le script SQL dans une zone de requête.
   - Vérifiez que les premières lignes ne provoquent pas de conflit (par exemple, si le schéma `itv` existe déjà).
   - Si besoin, commentez ou supprimez la ligne `CREATE SCHEMA itv;` ou ajoutez `DROP SCHEMA itv CASCADE;` au début (⚠️ cela efface les données existantes du schéma !).

4. Exécutez le script.
   - Attendez la fin de l’exécution : le schéma `itv`, ses tables, champs, contraintes, etc. seront créés.

**Remarque :**
Si le schéma ou certaines tables existent déjà, vérifiez leur structure avant toute modification ou suppression.

.. toctree::
   :maxdepth: 2
   :caption: Sommaire

   a-propos
   installation
   utilisation
   contribution

Indices et tables
=================

* :ref:`genindex`
* :ref:`modindex`
* :ref:`search`
