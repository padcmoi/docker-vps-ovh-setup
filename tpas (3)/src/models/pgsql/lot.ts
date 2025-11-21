import { dbPgQuery } from "../../lib/pgdb";

export class LotModel {
  constructor(private dbName: string) {}

  async createLotByImmeubleNom(immeubleNom: string, numero: string, type: string = "habitation") {
    const result = await dbPgQuery(this.dbName, "SELECT id FROM immeuble WHERE nom = $1", [immeubleNom]);
    const rows = result.rows;
    if (!rows || !rows.length) throw new Error("Immeuble not found");
    const immeuble_id = rows[0].id;
    return await dbPgQuery(this.dbName, "INSERT INTO lot (immeuble_id, numero, type) VALUES ($1, $2, $3) RETURNING *", [
      immeuble_id,
      numero,
      type,
    ]);
  }

  async getImmeubles() {
    return await dbPgQuery(this.dbName, "SELECT * FROM immeuble");
  }

  async createImmeuble(nom: string) {
    return await dbPgQuery(this.dbName, "INSERT INTO immeuble (nom) VALUES ($1) RETURNING *", [nom]);
  }

  async deleteImmeuble(id: number) {
    return await dbPgQuery(this.dbName, "DELETE FROM immeuble WHERE id = $1", [id]);
  }
}
