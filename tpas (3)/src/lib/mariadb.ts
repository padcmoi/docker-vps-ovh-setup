import mysql from "mysql2/promise";

export const mariadbPool = mysql.createPool({
  host: "mariadb",
  port: 3306,
  user: "user",
  password: "password",
  database: "appdb",
});

export async function mariadbQuery(sql: string, params?: any[]) {
  const [rows] = await mariadbPool.query(sql, params);
  return rows;
}
