import { Request, Response } from "express";
import { AgencyGroupModel } from "../../models/AgencyGroupModel";

const agencyGroupModel = new AgencyGroupModel(null);

/**
 * @openapi
 * summary: Liste toutes les bases PostgreSQL
 * responses:
 *   200: { databases: ["db1", "db2"] }
 *   500: { error: "..." }
 */
export async function getAllAgencyGroup(_req: Request, res: Response) {
  const result = await agencyGroupModel.getAllAgencyGroup();

  if (!result.success) {
    return res.status(500).json({ error: result.error });
  }

  return res.status(200).json({ databases: result.databases });
}

/**
 * @openapi
 * summary: Ajoute une nouvelle base agence et importe le SQL
 * body: { value: 123 }
 * query: {refresh:number}
 * params: {id:number}
 * responses:
 *   200: { success: true, database: "agency_group_xxxxx" }
 *   400: { error: "Nom de base invalide" }
 *   500: { error: "..." }
 */
export async function createAgencyGroup(_req: Request, res: Response) {
  const result = await agencyGroupModel.createAgencyGroup();

  if (!result.success) {
    return res.status(500).json({ error: result.error });
  }

  return res.status(200).json({ success: true, database: result.database });
}

/**
 * @openapi
 * summary: Efface toutes les bases agences (agency_group_*)
 * responses:
 *   200: { deleted: ["agency_group_xxxxx", ...] }
 *   500: { error: "..." }
 */
export async function deletegetAllAgencyGroup(_req: Request, res: Response) {
  const result = await agencyGroupModel.deleteAllAgencyGroups();

  if (!result.success) {
    return res.status(500).json({ error: result.error });
  }

  return res.status(200).json({ deleted: result.deleted });
}
