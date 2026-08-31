from dataclasses import dataclass, field


@dataclass
class TableB:
    AAA: str | None = None
    AAB: str | None = None
    AAC: str | None = None
    AAD: str | None = None
    AAE: str | None = None
    AAF: str | None = None
    AAG: str | None = None
    AAH: str | None = None
    AAI: str | None = None
    AAJ: str | None = None
    AAK: str | None = None
    AAL: str | None = None
    AAM: str | None = None
    AAN: str | None = None
    AAO: str | None = None
    AAP: str | None = None
    AAQ: str | None = None
    AAT: str | None = None
    AAU: str | None = None
    AAV: str | None = None

    detail: "Detail | None" = None
    passage_gid: int | None = None

    def set_data(self, data_enum, value):
        setattr(self, data_enum.name, value)


@dataclass
class TableC:
    A: str | None = None
    B: str | None = None
    C: str | None = None
    D: str | None = None
    E: str | None = None
    F: str | None = None
    G: str | None = None
    H: str | None = None
    I: str | None = None
    J: str | None = None
    K: str | None = None
    L: str | None = None
    M: str | None = None
    N: str | None = None

    detail: "Detail | None" = None
    passage_gid: int | None = None

@dataclass
class IDS:
    gid: int | None = None
    inspection_gid: int | None = None
    id_itv: str | None = None
    id_sig: str | None = None

@dataclass
class Detail:
    gid: int | None = None
    inspection_gid: int | None = None
    n_passage: int | None = None
    sens_ecoul: str | None = None
    id_reg_ent: int | None = None
    id_reg_sor: int | None = None
    id_troncon: int | None = None
    type_obs: str | None = None
    fam_obs: str | None = None
    code_obs: str | None = None
    libel_obs: str | None = None
    quan_charg: str | None = None
    rmq_obs: str | None = None
    orientatio: str | None = None
    metrage: float | None = None
    precipitat: str | None = None
    photo: str | None = None
    video: str | None = None
    video_tps: str | None = None
    date_obs: str | None = None

    b_rows: list[TableB] = field(default_factory=list)
    c_rows: list[TableC] = field(default_factory=list)

    def add_b_row(self, row: TableB):
        row.detail = self
        row.passage_gid = self.gid
        self.b_rows.append(row)

    def add_c_row(self, row: TableC):
        row.detail = self
        row.passage_gid = self.gid
        self.c_rows.append(row)

