import { dbPgQuery } from "../../lib/pgdb";

export class ImmeubleModel {
  constructor(private dbName: string) {}

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
