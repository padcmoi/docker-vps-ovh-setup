import type { NextFunction, Request, Response } from "express";

// Centralized error handler
export function errorHandler(err: any, req: Request, res: Response, _next: NextFunction) {
  const status = typeof err?.status === "number" ? err.status : 500;
  const code = err?.code || "ERR_INTERNAL";
  const message = err?.message || "Internal Server Error";
  const extra = err?.extra ?? undefined;

  // You can hook your logger here if needed
  console.error({ code, status, message, extra, requestId: req.id });

  res.status(status).json({
    error: code,
    message,
    requestId: req.id,
  });
}
