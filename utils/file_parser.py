import os
from typing import Optional, Dict, List, Any
from ..geo_itv_data import TableB, TableC, Detail, DefautDetecte


B01_FIELD_TRONCON = "AAA"
B01_FIELD_REG_AMONT = "AAB"
B01_FIELD_REG_AVAL = "AAF"
C_FIELD_METRAGE = "I"
C_FIELD_CODE_OBS = "A"


class FileParser:
    """
    Classe pour parser les fichiers TXT au format NF EN 13508-2+A1.
    Retourne les métadonnées, les passages et les détails des observations.
    """

    def __init__(self):
        pass

    def parse(self, file_path: str) -> Dict[str, Any]:
        """
        Parse le fichier TXT et retourne un dictionnaire contenant :
        - metadata: Dictionnaire des métadonnées (charset, language, delimiter, etc.)
        - passages: Liste des passages (ancien format)
        - details: Liste des objets Detail (nouveau format)
        """
        content = self.get_file_content(file_path)
        lines = content.split("\n")

        metadata = self.parse_metadata(lines[:6])

        final_data: List[Dict[str, Any]] = [{"n_passage": 1, "tables": {}}]
        details: List[Detail] = [Detail(n_passage=1)]
        current_detail = details[0]

        index = 1
        current_table_name: Optional[str] = None
        current_columns: List[str] = []

        for line in lines[6:]:
            line = line.strip()
            if not line:
                continue

            if line.startswith("#Z"):
                current_table_name = None
                index += 1

                final_data.append({"n_passage": index, "tables": {}})

                current_detail = Detail(n_passage=index)
                details.append(current_detail)
                continue

            if line.startswith("#B") or line.startswith("#C"):
                table_name, column_string = line.split("=")
                current_table_name = table_name
                current_columns = [
                    col.strip()
                    for col in column_string.split(metadata["delimiter"])
                ]

                if table_name not in final_data[index - 1]["tables"]:
                    final_data[index - 1]["tables"][table_name] = {
                        "columns": current_columns,
                        "rows": [],
                    }
                continue

            if current_table_name:
                values = self.parse_line(
                    line,
                    metadata["delimiter"],
                    metadata["quoteChar"]
                )

                final_data[index - 1]["tables"][current_table_name]["rows"].append(values)

                if current_table_name.startswith("#B"):
                    b_row = TableB()
                    for column, value in zip(current_columns, values):
                        if hasattr(b_row, column):
                            setattr(b_row, column, value)
                    current_detail.add_b_row(b_row)

                    if current_table_name == "#B01":
                        current_detail.id_reg_ent = self._clean_id(
                            getattr(b_row, B01_FIELD_REG_AMONT, None)
                        )
                        current_detail.id_reg_sor = self._clean_id(
                            getattr(b_row, B01_FIELD_REG_AVAL, None)
                        )
                        current_detail.id_troncon = self._clean_id(
                            getattr(b_row, B01_FIELD_TRONCON, None)
                        )

                elif current_table_name == "#C":
                    c_row = TableC()
                    for column, value in zip(current_columns, values):
                        if hasattr(c_row, column):
                            setattr(c_row, column, value)
                    current_detail.add_c_row(c_row)

                    code_obs = getattr(c_row, C_FIELD_CODE_OBS, None)
                    if code_obs:
                        code_obs = code_obs.strip().strip('"')

                        # DEBUG temporaire : écrit chaque code_obs lu dans un fichier
                        try:
                            with open(r"C:\temp\geo_itv_debug.txt", "a", encoding="utf-8") as dbg:
                                dbg.write(f"code_obs={code_obs!r} colonnes={current_columns!r} valeurs={values!r}\n")
                        except Exception as e:
                            pass

                        metrage = self._parse_metrage(
                            getattr(c_row, C_FIELD_METRAGE, None),
                            metadata["decimalSeparator"],
                        )

                        current_detail.code_obs = code_obs
                        current_detail.metrage = metrage
                        current_detail.fam_obs = code_obs
                        current_detail.libel_obs = None

                        defaut = DefautDetecte(
                            code_obs=code_obs,
                            metrage=metrage,
                            fam_obs=code_obs,
                        )
                        current_detail.add_defaut(defaut)

        return {
            "metadata": metadata,
            "passages": final_data,
            "details": details,
        }

    def parse_line(self, line: str, delimiter: str, quote_char: str) -> List[str]:
        """
        Parse une ligne CSV en tenant compte des délimiteurs et des guillemets.
        Retourne une liste de valeurs.
        """
        line = line.strip()
        result: List[str] = []
        current = ""
        in_quotes = False

        for char in line:
            if char == quote_char:
                in_quotes = not in_quotes
            elif char == delimiter and not in_quotes:
                result.append(current.strip())
                current = ""
            else:
                current += char

        result.append(current.strip())
        return result

    def _clean_id(self, raw_value: Optional[str]) -> Optional[str]:
        """
        Nettoie un identifiant (regard/tronçon) extrait du TXT : retire les
        guillemets éventuels. Retourne None si la valeur est vide.
        """
        if raw_value is None:
            return None
        value = raw_value.strip().strip('"')
        return value if value else None

    def _parse_metrage(self, raw_value: Optional[str], decimal_separator: str) -> Optional[float]:
        """
        Convertit le champ métrage (#C, colonne I) en float, en tenant compte
        du séparateur décimal déclaré dans les métadonnées (#A4).
        Retourne None si la valeur est vide ou non convertible.
        """
        if raw_value is None:
            return None
        value = raw_value.strip().strip('"')
        if not value:
            return None
        if decimal_separator and decimal_separator != ".":
            value = value.replace(decimal_separator, ".")
        try:
            return float(value)
        except ValueError:
            return None

    def get_file_content(self, file_path: str) -> str:
        """
        Lit le contenu d'un fichier avec l'encodage ISO-8859-1.
        Retourne le contenu sous forme de chaîne de caractères.
        """
        with open(file_path, "r", encoding="ISO-8859-1") as file:
            return file.read()

    def parse_metadata(self, metadata_lines: List[str]) -> Dict[str, str]:
        """
        Parse les lignes de métadonnées (#A1, #A2, etc.).
        Retourne un dictionnaire avec les métadonnées.
        """
        metadata: Dict[str, str] = {}

        for line in metadata_lines:
            if not line.strip():
                continue

            key, value = line.split("=")
            key = key.strip()

            if key == "#A1":
                metadata["charset"] = value.strip()
            elif key == "#A2":
                metadata["language"] = value.strip()
            elif key == "#A3":
                metadata["delimiter"] = value.strip()
            elif key == "#A4":
                metadata["decimalSeparator"] = value.strip()
            elif key == "#A5":
                metadata["quoteChar"] = value.strip()
            elif key == "#A6":
                metadata["version"] = value.strip()

        return metadata