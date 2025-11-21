import { mariadbQuery } from "../../lib/mariadb";

export async function getImmeubles() {
  return await mariadbQuery("SELECT * FROM immeuble");
}

export async function createImmeuble(nom: string) {
  await mariadbQuery("INSERT INTO immeuble (nom) VALUES (?)", [nom]);
  // Pour récupérer l'insert, refaire un SELECT si besoin
}

export async function deleteImmeuble(id: number) {
  return await mariadbQuery("DELETE FROM immeuble WHERE id = ?", [id]);
}
