export async function createLotByImmeubleNom(immeubleNom: string, numero: string, type: string = "habitation") {
  const [rows]: any = await mariadbQuery("SELECT id FROM immeuble WHERE nom = ?", [immeubleNom]);
  if (!rows || !rows.length) throw new Error("Immeuble not found");
  const immeuble_id = rows[0].id;
  await mariadbQuery("INSERT INTO lot (immeuble_id, numero, type) VALUES (?, ?, ?)", [immeuble_id, numero, type]);
}
import { mariadbQuery } from "../../lib/mariadb";

export async function getImmeubleIdByNom(nom: string): Promise<number | null> {
  const [rows]: any = await mariadbQuery("SELECT id FROM immeuble WHERE nom = ?", [nom]);
  return rows && rows.length ? rows[0].id : null;
}

export async function getLots() {
  return await mariadbQuery("SELECT * FROM lot");
}

export async function createLot(immeuble_id: number, numero: string, type: string = "habitation") {
  await mariadbQuery("INSERT INTO lot (immeuble_id, numero, type) VALUES (?, ?, ?)", [immeuble_id, numero, type]);
}

export async function deleteLot(id: number) {
  return await mariadbQuery("DELETE FROM lot WHERE id = ?", [id]);
}
