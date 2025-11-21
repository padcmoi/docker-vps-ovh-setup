import { mariadbQuery } from "../../lib/mariadb";

export async function getImmeubleIdByNom(nom: string): Promise<number | null> {
  const [rows]: any = await mariadbQuery("SELECT id FROM immeuble WHERE nom = ?", [nom]);
  return rows && rows.length ? rows[0].id : null;
}

export async function getAdresses() {
  return await mariadbQuery("SELECT * FROM adresse");
}

export async function createAdresse(
  immeuble_id: number,
  ligne1: string,
  ligne2: string | null,
  code_postal: string,
  ville: string
) {
  await mariadbQuery("INSERT INTO adresse (immeuble_id, ligne1, ligne2, code_postal, ville) VALUES (?, ?, ?, ?, ?)", [
    immeuble_id,
    ligne1,
    ligne2,
    code_postal,
    ville,
  ]);
}

export async function createAdresseByImmeubleId(
  immeuble_id: number,
  ligne1: string,
  ligne2: string | null,
  code_postal: string,
  ville: string
) {
  await mariadbQuery("INSERT INTO adresse (immeuble_id, ligne1, ligne2, code_postal, ville) VALUES (?, ?, ?, ?, ?)", [
    immeuble_id,
    ligne1,
    ligne2,
    code_postal,
    ville,
  ]);
}

export async function deleteAdresse(id: number) {
  return await mariadbQuery("DELETE FROM adresse WHERE id = ?", [id]);
}
