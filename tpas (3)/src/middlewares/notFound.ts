import type { NextFunction, Request, Response } from "express";

export function notFound(req: Request, res: Response, _next: NextFunction) {
  res.status(404).json({
    error: "Not Found",
    message: "The requested resource does not exist here.",
    path: req.originalUrl,
    requestId: req.id,
  });
}
