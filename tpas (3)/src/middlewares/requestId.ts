import { randomUUID } from "crypto";
import type { NextFunction, Request, Response } from "express";

export function requestId(req: Request, _res: Response, next: NextFunction) {
  req.id = req.id || randomUUID();
  next();
}
