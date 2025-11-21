import { Pool, PoolClient, QueryResult, QueryResultRow } from "pg";

// Strict check for PostgreSQL database names
function validatePgDbName(dbName: string) {
  if (!dbName || !/^[a-zA-Z0-9_]+$/.test(dbName)) {
    throw new Error(`Invalid database name: "${dbName}"`);
  }
}

// Root connection for CREATE DATABASE
const PG_HOST = process.env.PG_HOST ?? "localhost";
const PG_PORT = Number(process.env.PG_PORT ?? 5432);
const PG_USER = process.env.PG_USER ?? "user";
const PG_PASSWORD = process.env.PG_PASSWORD ?? "password";

export const pgRootPool = new Pool({
  host: PG_HOST,
  port: PG_PORT,
  user: PG_USER,
  password: PG_PASSWORD,
  database: process.env.PG_ROOT_DB ?? "postgres",
  max: 5,
});

// Cache pools per model
type PgPoolEntry = {
  pool: Pool;
  lastUsed: number;
};

const modelPools = new Map<string, PgPoolEntry>();

const MODEL_POOL_TTL_MS = Number(process.env.PG_MODEL_POOL_TTL_MS ?? 5 * 60 * 1000);
const MODEL_MAX_POOLS = Number(process.env.PG_MODEL_MAX_POOLS ?? 200);
const MODEL_POOL_MAX = Number(process.env.PG_MODEL_POOL_MAX ?? 5);

// Cleanup pools
setInterval(() => {
  const now = Date.now();
  for (const [dbName, entry] of modelPools.entries()) {
    if (now - entry.lastUsed > MODEL_POOL_TTL_MS) {
      entry.pool.end().catch(() => undefined);
      modelPools.delete(dbName);
    }
  }
}, 30_000).unref();

// Returns or creates a pool for a given database
function getPgModelPool(dbName: string): Pool {
  validatePgDbName(dbName);
  const now = Date.now();

  const existing = modelPools.get(dbName);
  if (existing) {
    existing.lastUsed = now;
    return existing.pool;
  }

  // Limit the total number of pools
  if (modelPools.size >= MODEL_MAX_POOLS) {
    let oldestKey: string | null = null;
    let oldestTime = Infinity;

    for (const [key, entry] of modelPools.entries()) {
      if (entry.lastUsed < oldestTime) {
        oldestTime = entry.lastUsed;
        oldestKey = key;
      }
    }

    if (oldestKey) {
      const oldest = modelPools.get(oldestKey);
      if (oldest) {
        oldest.pool.end().catch(() => undefined);
      }
      modelPools.delete(oldestKey);
    }
  }

  // Create a small pool for this model
  const pool = new Pool({
    host: PG_HOST,
    port: PG_PORT,
    user: PG_USER,
    password: PG_PASSWORD,
    database: dbName,
    max: MODEL_POOL_MAX,
  });

  modelPools.set(dbName, { pool, lastUsed: now });
  return pool;
}

/**
 * Prepared query in a model DB.
 */
export async function dbPgQuery<T extends QueryResultRow = any>(
  dbName: string,
  sql: string,
  params?: any[]
): Promise<QueryResult<T>> {
  validatePgDbName(dbName);
  const pool = getPgModelPool(dbName);
  return pool.query<T>(sql, params);
}

/**
 * Prepared transaction in a model DB.
 */
export async function dbPgTransaction<T>(dbName: string, fn: (client: PoolClient) => Promise<T>): Promise<T> {
  validatePgDbName(dbName);

  const pool = getPgModelPool(dbName);
  const client = await pool.connect();

  try {
    await client.query("BEGIN");
    const output = await fn(client);
    await client.query("COMMIT");
    return output;
  } catch (err) {
    await client.query("ROLLBACK").catch(() => undefined);
    throw err;
  } finally {
    client.release();
  }
}

/**
 * Admin (root) query – CREATE DATABASE, etc.
 */
export async function dbPgRootQuery<T extends QueryResultRow = any>(sql: string, params?: any[]): Promise<QueryResult<T>> {
  if (sql.includes(";") && !sql.trim().endsWith(";")) {
    throw new Error("Multiple SQL statements forbidden");
  }
  return pgRootPool.query<T>(sql, params);
}

/**
 * Creates a model DB.
 */
export async function createPgDatabase(dbName: string): Promise<void> {
  validatePgDbName(dbName);
  await dbPgRootQuery(`CREATE DATABASE "${dbName}"`);
}

/**
 * Initializes a DB with SQL (already read by the controller).
 */
export async function initPgDatabaseWithSql(dbName: string, sql: string): Promise<void> {
  validatePgDbName(dbName);
  const pool = getPgModelPool(dbName);
  await pool.query(sql);
}

/**
 * Closes a pool DB
 */
export async function closePgDatabasePool(dbName: string): Promise<void> {
  const entry = modelPools.get(dbName);
  if (entry) {
    await entry.pool.end().catch(() => undefined);
    modelPools.delete(dbName);
  }
}
