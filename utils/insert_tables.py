from qgis.PyQt import QtWidgets

def insert_b01_table(self, cursor, passage_gid, b01_data):
    """
    Insère les données de la table `B01` associées à un passage dans la base de données.
    """
    try:
        b01_query = """
            INSERT INTO itv."B01" (
                gid, "AAA", "AAB", "AAC", "AAD", "AAE", "AAF", "AAG", "AAH", "AAI", "AAJ", "AAK", "AAL", "AAM", "AAN", "AAO", "AAP", "AAQ", "AAT", "AAU", "AAV", passage_gid
            ) VALUES (DEFAULT, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING gid;
        """
        expected_columns = ["AAA", "AAB", "AAC", "AAD", "AAE", "AAF", "AAG", "AAH", "AAI", "AAJ", "AAK", "AAL", "AAM", "AAN", "AAO", "AAP", "AAQ", "AAT", "AAU", "AAV"]
        parsed_columns = b01_data["columns"]
        column_index_map = {col: parsed_columns.index(col) for col in parsed_columns if col in expected_columns}

        for row in b01_data["rows"]:
            values = [
                row[column_index_map[col]] if col in column_index_map else None
                for col in expected_columns
            ]

            values.append(passage_gid)
            cursor.execute(b01_query, values)
            b01_gid = cursor.fetchone()[0] 

            #QtWidgets.QMessageBox.information(self, "Info", "Données B01 insérées avec succès dans la table `B01`.")
            #self.log_message(f"Données B01 insérées avec succès dans la table `B01` avec gid={b01_gid}.")

    except Exception as e:
        # Gestion des erreurs
        QtWidgets.QMessageBox.critical(self, "Erreur", f"Erreur lors de l'insertion des données B01 : {str(e)}")
        #self.log_message(f"Erreur lors de l'insertion des données B01 : {str(e)}")

def insert_b02_table(self, cursor, passage_gid, b02_data):
    """
    Insère les données de la table `B02` associées à un passage dans la base de données.
    """
    try:
        # Requête SQL pour insérer les données de la table `B02`
        b02_query = """
            INSERT INTO itv."B02"(
                gid, "ABA", "ABB", "ABC", "ABD", "ABE", "ABF", "ABG", "ABH", "ABI", "ABJ", "ABK", "ABL", "ABM", "ABN", "ABO", "ABP", "ABQ", "ABR", "ABS", "ABT", passage_gid)
                VALUES (DEFAULT, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING gid;
        """
        expected_columns = ["ABA", "ABB", "ABC", "ABD", "ABE", "ABF", "ABG", "ABH", "ABI", "ABJ", "ABK", "ABL", "ABM", "ABN", "ABO", "ABP", "ABQ", "ABR", "ABS", "ABT"]
        parsed_columns = b02_data["columns"]
        column_index_map = {col: parsed_columns.index(col) for col in parsed_columns if col in expected_columns}
        for row in b02_data["rows"]:
            values = [
                row[column_index_map[col]] if col in column_index_map else None
                for col in expected_columns
            ]
            values.append(passage_gid)
            cursor.execute(b02_query, values)
            b02_gid = cursor.fetchone()[0]

            #QtWidgets.QMessageBox.information(self, "Info", f"Données B02 insérées avec succès dans la table `B02`.")
            #self.log_message(f"Données B02 insérées avec succès dans la table `B02` avec gid={b02_gid}.")

    except Exception as e:
        # Gestion des erreurs
        QtWidgets.QMessageBox.critical(self, "Erreur", f"Erreur lors de l'insertion des données B02 : {str(e)}")
        #self.log_message(f"Erreur lors de l'insertion des données B02 : {str(e)}")
    
def insert_b03_table(self, cursor, passage_gid, b03_data):
    """
    Insère les données de la table `B03` associées à un passage dans la base de données.
    """
    try:
        # Requête SQL pour insérer les données de la table `B03`
        b03_query = """
            INSERT INTO itv."B03"(gid, "ACA", "ACB", "ACC", "ACD", "ACE", "ACF", "ACG", "ACH", "ACI", "ACJ", "ACK", "ACL", "ACM", "ACN", passage_gid)
            VALUES (DEFAULT, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING gid;
        """
        expected_columns = ["ACA", "ACB", "ACC", "ACD", "ACE", "ACF", "ACG", "ACH", "ACI", "ACJ", "ACK", "ACL", "ACM", "ACN"]
        parsed_columns = b03_data["columns"]
        column_index_map = {col: parsed_columns.index(col) for col in parsed_columns if col in expected_columns}
        for row in b03_data["rows"]:
            values = [
                row[column_index_map[col]] if col in column_index_map else None
                for col in expected_columns
            ]
            values.append(passage_gid)
            cursor.execute(b03_query, values)
            b03_gid = cursor.fetchone()[0]

            #QtWidgets.QMessageBox.information(self, "Info", f"Données B03 insérées avec succès dans la table `B03`.")
            #self.log_message(f"Données B03 insérées avec succès dans la table `B03` avec gid={b03_gid}.")

    except Exception as e:
        # Gestion des erreurs
        QtWidgets.QMessageBox.critical(self, "Erreur", f"Erreur lors de l'insertion des données B03 : {str(e)}")
        #self.log_message(f"Erreur lors de l'insertion des données B03 : {str(e)}")

def insert_b04_table(self, cursor, passage_gid, b04_data):
    """
    Insère les données de la table 'B04' associées à un passage dans la base de données.
    """
    try:
        # Requête SQL pour insérer les données de la table `B04`
        b04_query = """
        INSERT INTO itv."B04"(gid, "ADA", "ADB", "ADC", "ADD", "ADE", passage_gid)
            VALUES (DEFAULT, %s, %s, %s, %s, %s, %s)
            RETURNING gid;
        """
        expected_columns = ["ADA", "ADB", "ADC", "ADD", "ADE"]
        parsed_columns = b04_data["columns"]
        column_index_map = {col: parsed_columns.index(col) for col in parsed_columns if col in expected_columns}
        for row in b04_data["rows"]:
            values = [
                row[column_index_map[col]] if col in column_index_map else None
                for col in expected_columns
            ]
            values.append(passage_gid)
            cursor.execute(b04_query, values)
            b04_gid = cursor.fetchone()[0]

            #QtWidgets.QMessageBox.information(self, "Info", f"Données B04 insérées avec succès dans la table `B04`.")
            #self.log_message(f"Données B04 insérées avec succès dans la table `B04` avec gid={b04_gid}.")

    except Exception as e:
        # Gestion des erreurs
        QtWidgets.QMessageBox.critical(self, "Erreur", f"Erreur lors de l'insertion des données B04 : {str(e)}")
        #self.log_message(f"Erreur lors de l'insertion des données B04 : {str(e)}")

def insert_c_table(self, cursor, passage_gid, c_data):
    """
    Insère les données de la table `C` associées à un passage dans la base de données.
    """
    try:
        # Requête SQL pour insérer les données de la table `C`
        c_query = """
            INSERT INTO itv."C" (
                gid, "I", "J", "A", "B", "C", "D", "E", "F", "G", "H", "K", "L", "M", "N", passage_gid
            ) VALUES (DEFAULT, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING gid;
        """

        # Liste des colonnes attendues dans la table `C`
        expected_columns = ["I", "J", "A", "B", "C", "D", "E", "F", "G", "H", "K", "L", "M", "N"]

        # Colonnes présentes dans les données parsées
        parsed_columns = c_data["columns"]

        # Mapping des colonnes parsées aux colonnes attendues
        column_index_map = {col: parsed_columns.index(col) for col in parsed_columns if col in expected_columns}

        # Insérer chaque ligne de données dans la table `C`
        for row in c_data["rows"]:
            values = [
                row[column_index_map[col]] if col in column_index_map else None
                for col in expected_columns
            ]

            # Ajouter `passage_gid` à la fin des valeurs
            values.append(passage_gid)
            # Exécuter la requête d'insertion
            cursor.execute(c_query, values)
            c_gid = cursor.fetchone()[0]  # Récupère l'ID généré pour la ligne

            #QtWidgets.QMessageBox.information(self, "Info", f"Données C insérées avec succès dans la table `C`.")
            #self.log_message(f"Données C insérées avec succès dans la table `C` avec gid={c_gid} dans le passage {passage_gid}.")

    except Exception as e:
        # Gestion des erreurs
        QtWidgets.QMessageBox.critical(self, "Erreur", f"Erreur lors de l'insertion des données C : {str(e)}")
        #self.log_message(f"Erreur lors de l'insertion des données C : {str(e)}")