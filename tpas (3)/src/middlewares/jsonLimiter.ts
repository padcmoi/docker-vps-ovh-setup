import type { NextFunction, Request, Response } from "express";

// Simple JSON-only gate to avoid non-JSON bodies on API routes
export function jsonLimiter() {
  return function (req: Request, res: Response, next: NextFunction) {
    const ct = req.headers["content-type"];
    if (req.method !== "GET" && ct && !ct.includes("application/json")) {
      return res.status(415).json({
        error: "Unsupported Media Type",
        message: "Only application/json is accepted.",
      });
    }
    next();
  };
}
