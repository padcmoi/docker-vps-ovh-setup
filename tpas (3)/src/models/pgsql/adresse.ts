import { dbPgQuery } from "../../lib/pgdb";

export class AdresseModel {
  constructor(private dbName: string) {}

  async createAdresseByImmeubleId(
    immeuble_id: number,
    ligne1: string,
    ligne2: string | null,
    code_postal: string,
    ville: string
  ) {
    return await dbPgQuery(
      this.dbName,
      "INSERT INTO adresse (immeuble_id, ligne1, ligne2, code_postal, ville) VALUES ($1, $2, $3, $4, $5) RETURNING *",
      [immeuble_id, ligne1, ligne2, code_postal, ville]
    );
  }

  async getImmeubleIdByNom(nom: string): Promise<number | null> {
    const result = await dbPgQuery(this.dbName, "SELECT id FROM immeuble WHERE nom = $1", [nom]);
    const rows = result.rows;
    return rows && rows.length ? rows[0].id : null;
  }

  async deleteAdresse(id: number) {
    return await dbPgQuery(this.dbName, "DELETE FROM adresse WHERE id = $1", [id]);
  }
}
