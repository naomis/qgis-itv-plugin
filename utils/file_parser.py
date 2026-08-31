import os
from ..geo_itv_data import TableB, TableC, Detail

class FileParser:
    def __init__(self):
        pass

    def parse(self, file_path):
        content = self.get_file_content(file_path)
        lines = content.split("\n")

        metadata = self.parse_metadata(lines[:6])

        # Ancienne structure 
        final_data = [{"n_passage": 1, "tables": {}}]

        # Nouvelle structure
        details = [Detail(n_passage=1)]
        current_detail = details[0]

        index = 1
        current_table_name = None
        current_columns = []

        for line in lines[6:]:

            line = line.strip()

            if not line:
                continue

            if line.startswith("#Z"):

                current_table_name = None

                # Ancienne structure
                final_data.append({
                    "n_passage": index + 1,
                    "tables": {}
                })

                # Nouvelle structure
                current_detail = Detail(n_passage=index + 1)
                details.append(current_detail)

                index += 1
                continue

            if line.startswith("#B") or line.startswith("#C"):

                table_name, column_string = line.split("=")

                current_table_name = table_name
                current_columns = [
                    col.strip()
                    for col in column_string.split(metadata["delimiter"])
                ]

                # Ancienne structure
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

                elif current_table_name == "#C":

                    c_row = TableC()

                    for column, value in zip(current_columns, values):
                        if hasattr(c_row, column):
                            setattr(c_row, column, value)

                    current_detail.add_c_row(c_row)

        return {
            "metadata": metadata,
            "passages": final_data,   # Ancien format
            "details": details,       # Nouveau format
        }

    def parse_line(self, line, delimiter, quote_char):
        line = line.strip()

        result = []
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

    def get_file_content(self, file_path):
        with open(file_path, "r", encoding="ISO-8859-1") as file:
            return file.read()

    def parse_metadata(self, metadata_lines):

        metadata = {}

        for line in metadata_lines:

            key, value = line.split("=")

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