import type { Express, Request, Response } from "express";
import fs from "fs";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import path from "path";
import swaggerUi from "swagger-ui-express";

function getOpenApiVersions(): string[] {
  const openapiDir = path.join(process.cwd(), "openapi");
  const files = readdirSync(openapiDir);
  return files.filter((f) => /^openapi\.v[0-9]+\.json$/.test(f)).map((f) => f.match(/^openapi\.(v[0-9]+)\.json$/)![1]);
}

function getSpecPath(version?: string): string {
  const openapiDir = path.join(process.cwd(), "openapi");
  if (!version) return "";
  return path.join(openapiDir, `openapi.${version}.json`);
}

export function installSwagger(app: Express) {
  app.get("/doc/versions", (req: Request, res: Response) => {
    const versions = getOpenApiVersions();
    res.json({ versions });
  });

  app.get("/doc", (req: Request, res: Response) => {
    const htmlPath = path.join(process.cwd(), "public/swagger-root.html");
    let html;
    try {
      html = fs.readFileSync(htmlPath, "utf8");
    } catch {
      res.status(500).send({ code: "ENOENT", status: 500, message: `Fichier HTML manquant: ${htmlPath}` });
      return;
    }
    const versions = getOpenApiVersions();
    let versionListHtml = "";
    if (versions.length > 0) {
      for (const v of versions) {
        versionListHtml +=
          '<li><a href="/doc/' +
          v +
          '" class="block px-4 py-3 rounded-lg bg-[#333333] hover:bg-[#222222] text-white font-medium text-lg text-center transition">version <span class="font-bold">' +
          v +
          "</span></a></li>";
      }
    } else {
      versionListHtml = '<li class="text-gray-500">Aucune version disponible</li>';
    }
    html = html.replace("<!--__VERSIONS__-->", versionListHtml);
    res.send(html);
  });

  app.use("/doc/:version", (req: Request, res: Response, next) => {
    const version = req.params.version;
    const specPath = getSpecPath(version);
    if (!specPath || !existsSync(specPath)) {
      res.status(404).send(`OpenAPI spec for version '${version}' not found.`);
      return;
    }
    const spec = JSON.parse(readFileSync(specPath, "utf8"));
    const middlewares = Array.isArray(swaggerUi.serve) ? swaggerUi.serve : [swaggerUi.serve];
    let idx = 0;
    function nextMiddleware(err?: any) {
      if (err) return next(err);
      if (idx < middlewares.length) {
        return middlewares[idx++](req, res, nextMiddleware);
      }
      return swaggerUi.setup(spec)(req, res, next);
    }
    nextMiddleware();
  });
}
