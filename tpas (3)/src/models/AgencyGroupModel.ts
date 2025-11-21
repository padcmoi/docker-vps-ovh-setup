import fs from "fs";
import path from "path";
import { closePgDatabasePool, createPgDatabase, dbPgRootQuery, initPgDatabaseWithSql } from "../lib/pgdb";
import { generateLowerHash } from "../utils/hash.util";

type AgencyGroupListResult = { success: true; databases: string[] } | { success: false; error: string };

type AgencyGroupCreateResult = { success: true; database: string } | { success: false; error: string };

type AgencyGroupDeleteResult = { success: true; deleted: string[] } | { success: false; error: string };

export class AgencyGroupModel {
  constructor(private dbName: string | null) {}

  async getAllAgencyGroup(): Promise<AgencyGroupListResult> {
    try {
      const result = await dbPgRootQuery(
        "SELECT datname FROM pg_database WHERE datistemplate = false AND datname LIKE 'agency_group_%';"
      );
      const databases = result.rows.map((row: any) => row.datname);
      return { success: true, databases };
    } catch (err) {
      const message = err instanceof Error ? err.message : "Unknown error while listing agency groups";
      return { success: false, error: message };
    }
  }

  async createAgencyGroup(): Promise<AgencyGroupCreateResult> {
    try {
      const unique = generateLowerHash();
      const dbName = `agency_group_${unique}`;

      await createPgDatabase(dbName);

      const sqlPath = path.resolve(__dirname, "../../init/agency_base.sql");
      const sql = fs.readFileSync(sqlPath, "utf8");

      await initPgDatabaseWithSql(dbName, sql);

      return { success: true, database: dbName };
    } catch (err) {
      const message = err instanceof Error ? err.message : "Unknown error while creating agency group";
      return { success: false, error: message };
    }
  }

  async deleteAllAgencyGroups(): Promise<AgencyGroupDeleteResult> {
    try {
      const result = await dbPgRootQuery(
        `SELECT datname FROM pg_database
         WHERE datistemplate = false
         AND datname LIKE 'agency_group_%';`
      );

      const dbs = result.rows.map((row: any) => row.datname);

      for (const dbName of dbs) {
        await closePgDatabasePool(dbName);
        await dbPgRootQuery(`DROP DATABASE "${dbName}" WITH (FORCE)`);
      }

      return { success: true, deleted: dbs };
    } catch (err) {
      const message = err instanceof Error ? err.message : "Unknown error while deleting agency groups";
      return { success: false, error: message };
    }
  }
}
