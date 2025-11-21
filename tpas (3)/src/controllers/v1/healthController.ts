import type { Request, Response } from "express";

/**
 * @openapi
 * summary: Obtient des informations
 * query: {refresh:number}
 * responses:
 *   200: {"status":"ok","uptime":60.24794608,"timestamp":"2025-11-12T14:19:18.369Z"}
 *   403: {"error":"Forbidden"}
 */
export async function getHealth(_req: Request, res: Response) {
  res.json({
    status: "ok",
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
  });
}
