from __future__ import annotations
from dataclasses import dataclass, field
from typing import TYPE_CHECKING
from shapely import Point, Geometry

if TYPE_CHECKING:
    from typing import Optional

@dataclass
class TableB:
    """Classe pour stocker les données de la table B (B01, B02, B03, B04)."""
    AAA: Optional[str] = None
    AAB: Optional[str] = None
    AAC: Optional[str] = None
    AAD: Optional[str] = None
    AAE: Optional[str] = None
    AAF: Optional[str] = None
    AAG: Optional[str] = None
    AAH: Optional[str] = None
    AAI: Optional[str] = None
    AAJ: Optional[str] = None
    AAK: Optional[str] = None
    AAL: Optional[str] = None
    AAM: Optional[str] = None
    AAN: Optional[str] = None
    AAO: Optional[str] = None
    AAP: Optional[str] = None
    AAQ: Optional[str] = None
    AAT: Optional[str] = None
    AAU: Optional[str] = None
    AAV: Optional[str] = None

    # Référence vers le Detail parent (optionnel)
    detail: Optional["Detail"] = None
    passage_gid: Optional[int] = None

    def set_data(self, data_enum, value):
        """Définit la valeur d'un champ en utilisant un enum."""
        setattr(self, data_enum.name, value)


@dataclass
class TableC:
    """Classe pour stocker les données de la table C."""
    A: Optional[str] = None
    B: Optional[str] = None
    C: Optional[str] = None
    D: Optional[str] = None
    E: Optional[str] = None
    F: Optional[str] = None
    G: Optional[str] = None
    H: Optional[str] = None
    I: Optional[str] = None
    J: Optional[str] = None
    K: Optional[str] = None
    L: Optional[str] = None
    M: Optional[str] = None
    N: Optional[str] = None

    # Référence vers le Detail parent (optionnel)
    detail: Optional["Detail"] = None
    passage_gid: Optional[int] = None



@dataclass
class IDS:
    """Classe pour stocker les identifiants (regard, tronçon, etc.)."""
    gid: Optional[int] = None
    inspection_gid: Optional[int] = None
    id_itv: Optional[str] = None
    id_sig: Optional[str] = None



@dataclass
class DefautDetecte:
    """Classe pour stocker les défauts détectés."""
    inspection_gid: Optional[int] = None
    id_reg_ent: Optional[int] = None
    id_reg_sor: Optional[int] = None
    id_troncon: Optional[int] = None

    metrage: Optional[float] = None
    x: Optional[float] = None
    y: Optional[float] = None

    code_obs: Optional[str] = None
    libel_obs: Optional[str] = None
    fam_obs: Optional[str] = None
    code_insee: Optional[str] = None

    geometry: Optional[Geometry] = None



@dataclass
class Detail:
    """Classe pour stocker les détails d'une observation ITV."""
    gid: Optional[int] = None
    inspection_gid: Optional[int] = None
    n_passage: Optional[int] = None
    sens_ecoul: Optional[str] = None
    id_reg_ent: Optional[int] = None
    id_reg_sor: Optional[int] = None
    id_troncon: Optional[int] = None
    type_obs: Optional[str] = None
    fam_obs: Optional[str] = None
    code_obs: Optional[str] = None
    libel_obs: Optional[str] = None
    quan_charg: Optional[str] = None
    rmq_obs: Optional[str] = None
    orientatio: Optional[str] = None
    metrage: Optional[float] = None
    precipitat: Optional[str] = None
    photo: Optional[str] = None
    video: Optional[str] = None
    video_tps: Optional[str] = None
    date_obs: Optional[str] = None

    geometry: Optional[Geometry] = None

    # Listes pour stocker les données associées
    b_rows: list[TableB] = field(default_factory=list)
    c_rows: list[TableC] = field(default_factory=list)
    defauts: list[DefautDetecte] = field(default_factory=list)

    
    def add_defaut(self, defaut: DefautDetecte):
        """Ajoute un défaut à la liste des défauts détectés."""
        if self.inspection_gid is not None:
            defaut.inspection_gid = self.inspection_gid
        if self.id_troncon is not None:
            defaut.id_troncon = self.id_troncon
        if self.id_reg_ent is not None:
            defaut.id_reg_ent = self.id_reg_ent
        if self.id_reg_sor is not None:
            defaut.id_reg_sor = self.id_reg_sor

        if defaut.x is not None and defaut.y is not None:
            defaut.geometry = Point(defaut.x, defaut.y)

        self.defauts.append(defaut)

    
    def add_b_row(self, b_row: TableB):
        """Ajoute une ligne de type B (TableB) à la liste b_rows."""
        self.b_rows.append(b_row)
        b_row.detail = self  # Met à jour la référence vers le Detail parent

    
    def add_c_row(self, c_row: TableC):
        """Ajoute une ligne de type C (TableC) à la liste c_rows."""
        self.c_rows.append(c_row)
        c_row.detail = self  # Met à jour la référence vers le Detail parent