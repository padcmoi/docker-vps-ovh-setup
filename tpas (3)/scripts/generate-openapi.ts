import fs from "node:fs/promises";

import path from "node:path";

type HttpMethod = "get" | "post" | "put" | "patch" | "delete";

interface PseudoParams {
  query?: Record<string, string>;
  params?: Record<string, string>;
  body?: Record<string, string>;
  responses?: Record<string, string>;
}

interface RouteDoc {
  method: HttpMethod;
  path: string;
  tag: string;
  parameters?: RouteParameter[];
  body?: Record<string, string>;
  responses?: ResponsesObject;
  summary?: string;
}

interface RouteParameter {
  name: string;
  in: "query" | "path";
  required: boolean;
  schema: {
    type: string;
  };
}

interface ResponseContent {
  example: unknown;
}

interface ResponseItem {
  description: string;
  content: {
    "application/json": ResponseContent;
  };
}

type ResponsesObject = Record<string, ResponseItem>;

type PathsObject = Record<
  string,
  Record<
    string,
    {
      summary: string;
      description?: string;
      tags: string[];
      parameters?: RouteParameter[];
      responses?: ResponsesObject;
    }
  >
>;

async function extractRouteDescriptionsForVersion(routesRoot: string, version: string): Promise<Record<string, string>> {
  const routeDescriptions: Record<string, string> = {};

  const indexFile = path.join(routesRoot, version, "index.ts");

  try {
    const indexSource = await fs.readFile(indexFile, "utf8");

    const descRegex = /\/\*\*([\s\S]*?)@openapi-desc([\s\S]*?)\*\/\s*router\.use\(["'`]([^"'`]*)["'`],/g;

    let match;

    while ((match = descRegex.exec(indexSource)) !== null) {
      const routePath = match[3];

      const descRaw = match[2].trim();

      const description = descRaw
        .split("\n")
        .map((l) => l.replace(/^[*\s]+/, "").trim())
        .filter(Boolean)
        .join(" ");

      routeDescriptions[routePath] = description;
    }
  } catch {
    /* ignore */
  }

  return routeDescriptions;
}

function toKebabCase(name: string): string {
  const replaced = name.replace(/([a-z0-9])([A-Z])/g, "$1-$2");

  return replaced.replace(/_/g, "-").toLowerCase();
}

function parsePseudoRecord(src: string | undefined): Record<string, string> {
  if (!src) return {};

  const trimmed = src.trim();

  if (!trimmed.startsWith("{") || !trimmed.endsWith("}")) return {};

  const inner = trimmed.slice(1, -1).trim();

  if (!inner) return {};

  const result: Record<string, string> = {};

  for (const part of inner.split(",")) {
    const piece = part.trim();

    if (!piece) continue;

    const splitIndex = piece.indexOf(":");

    if (splitIndex === -1) continue;

    const rawKey = piece.slice(0, splitIndex).trim();

    const rawType = piece.slice(splitIndex + 1).trim();

    if (!rawKey || !rawType) continue;

    result[rawKey] = rawType;
  }

  return result;
}

function parseAnnotations(block: string | undefined): PseudoParams {
  if (!block) return {};

  const lines = block
    .split("\n")
    .map((l) => l.replace(/^\s*\*\s?/, "").trim())
    .filter((l) => l.length > 0);

  let querySource: string | undefined;

  let paramsSource: string | undefined;

  let bodySource: string | undefined;

  const responsesSource: Record<string, string> = {};

  let inResponses = false;

  for (const line of lines) {
    if (line.startsWith("@openapi")) {
      inResponses = false;
      continue;
    }

    if (line.startsWith("query:")) {
      inResponses = false;
      querySource = line.slice("query:".length).trim();
      continue;
    }

    if (line.startsWith("params:")) {
      inResponses = false;
      paramsSource = line.slice("params:".length).trim();
      continue;
    }

    if (line.startsWith("body:")) {
      inResponses = false;
      bodySource = line.slice("body:".length).trim();
      continue;
    }

    if (line.startsWith("responses:")) {
      inResponses = true;
      continue;
    }

    if (inResponses) {
      const match = line.match(/^(\d{3})\s*:\s*(.+)$/);
      if (match) {
        const status = match[1];
        const jsonLike = match[2].trim();
        responsesSource[status] = jsonLike;
      }
    }
  }

  return {
    query: parsePseudoRecord(querySource),
    params: parsePseudoRecord(paramsSource),
    body: parsePseudoRecord(bodySource),
    responses: Object.keys(responsesSource).length > 0 ? responsesSource : undefined,
  };
}

function toOpenApiType(typeName: string | undefined): string {
  if (!typeName) return "string";

  const lower = typeName.toLowerCase();

  if (lower === "number" || lower === "integer") return "number";

  if (lower === "string") return "string";

  if (lower === "boolean") return "boolean";

  return "string";
}

function buildParameters(meta: PseudoParams): RouteParameter[] | undefined {
  const parameters: RouteParameter[] = [];

  if (meta.params) {
    for (const [name, typeName] of Object.entries(meta.params)) {
      parameters.push({
        name,
        in: "path",
        required: true,
        schema: { type: toOpenApiType(typeName) },
      });
    }
  }

  if (meta.query) {
    for (const [name, typeName] of Object.entries(meta.query)) {
      parameters.push({
        name,
        in: "query",
        required: false,
        schema: { type: toOpenApiType(typeName) },
      });
    }
  }

  return parameters.length > 0 ? parameters : undefined;
}

function buildResponses(meta: PseudoParams): ResponsesObject | undefined {
  if (!meta.responses) return undefined;

  const responses: ResponsesObject = {};

  for (const [status, raw] of Object.entries(meta.responses)) {
    let example: unknown = raw;

    const trimmed = raw.trim();

    if ((trimmed.startsWith("{") && trimmed.endsWith("}")) || (trimmed.startsWith("[") && trimmed.endsWith("]"))) {
      try {
        const parsed = JSON.parse(trimmed) as unknown;
        example = parsed;
      } catch {
        example = raw;
      }
    }

    responses[status] = {
      description: `${status} response`,
      content: {
        "application/json": {
          example,
        },
      },
    };
  }

  return responses;
}

async function findRouteFiles(rootDir: string): Promise<string[]> {
  const results: string[] = [];

  async function walk(current: string): Promise<void> {
    const entries = await fs.readdir(current, { withFileTypes: true });

    for (const entry of entries) {
      const full = path.join(current, entry.name);

      if (entry.isDirectory()) {
        await walk(full);
      } else if (entry.isFile() && full.endsWith(".ts")) {
        results.push(full);
      }
    }
  }

  await walk(rootDir);

  return results;
}

async function retrieveImportFromRegex(source: string, handlerName: string, filePath: string) {
  let result: null | string = null;

  const importRegex = /import\s+\{?\s*([\w,\s]+)\s*\}?\s+from\s+["']([^"']+)["'];?/g;
  const importMap: Record<string, string> = {};
  let importMatch;
  while ((importMatch = importRegex.exec(source)) !== null) {
    const imported = importMatch[1];
    const importPath = importMatch[2];
    for (const fn of imported.split(",")) {
      const fnName = fn.trim();
      if (fnName) {
        importMap[fnName] = importPath;
      }
    }
  }

  const pathController = importMap[handlerName] || "(inconnu)";

  const controllerFullPath = path.resolve(path.dirname(filePath), pathController);
  const controllerBase = controllerFullPath.replace(/\.[^/.]+$/, "");
  const tsControllerPath = controllerBase + ".ts";
  try {
    result = await fs.readFile(tsControllerPath, "utf8");
  } catch {
    //
  }

  return result;
}

async function extractRoutesFromSource(source: string, basePath: string, tag: string, filePath: string): Promise<RouteDoc[]> {
  const routes: RouteDoc[] = [];
  const commentRouteRegex = /\/\*\*([\s\S]*?)\*\/[\s\n\r]*router\.(get|post|put|patch|delete)\(\s*["'`]([^"'`]*)["'`]\s*,/g;
  let match: RegExpExecArray | null;

  while ((match = commentRouteRegex.exec(source)) !== null) {
    const block = match[1];
    const method = match[2] as HttpMethod;
    const subPath = match[3];
    const meta = parseAnnotations(block);
    const fullPath = subPath === "/" ? basePath : subPath.startsWith("/") ? `${basePath}${subPath}` : `${basePath}/${subPath}`;
    const parameters = buildParameters(meta);
    const responses = buildResponses(meta);

    // Récupère le summary si présent dans le commentaire (ligne par ligne, ignore les étoiles)
    let summary = undefined;
    const blockLines = block.split("\n").map((l) => l.replace(/^[*\s]+/, "").trim());
    for (const line of blockLines) {
      if (line.startsWith("summary:")) {
        summary = line.slice("summary:".length).trim();
        break;
      }
    }
    // summary = "1212";

    routes.push({
      method,
      path: fullPath,
      tag,
      parameters,
      body: meta.body,
      responses,
      summary,
    });
  }

  const routeRegex = /router\.(get|post|put|patch|delete)\(\s*["'`]([^"'`]*)["'`]\s*,\s*([\w]+)/g;
  while ((match = routeRegex.exec(source)) !== null) {
    const method = match[1] as HttpMethod;
    const subPath = match[2];
    const handlerName = match[3];
    const fullPath = subPath === "/" ? basePath : `${basePath}${subPath}`;
    const exists = routes.some((r) => r.method === method && r.path === fullPath);
    if (!exists) {
      // Second chance: if no annotation exists on the route, check the controller
      const controllerSource = await retrieveImportFromRegex(source, handlerName, filePath);

      let jsdocBlock: string | undefined = undefined;
      let meta: PseudoParams = {};
      let summary: string | undefined = undefined;
      let matchJsdoc: RegExpExecArray | null = null;

      if (controllerSource) {
        const jsdocRegex = /\/\*\*([\s\S]*?@openapi[\s\S]*?)\*\/[\s\n\r]*export[\s\n\r]+(async\s+)?function\s+([a-zA-Z0-9_]+)\b/g;

        while ((matchJsdoc = jsdocRegex.exec(controllerSource)) !== null) {
          const controllerFunctionName = matchJsdoc[3];
          if (controllerFunctionName === handlerName) {
            jsdocBlock = matchJsdoc[1];
            break;
          }
        }
      }

      if (jsdocBlock) {
        meta = parseAnnotations(jsdocBlock);

        const blockLines = jsdocBlock.split("\n").map((l) => l.replace(/^[*\s]+/, "").trim());
        for (const line of blockLines) {
          if (line.startsWith("summary:")) {
            summary = line.slice("summary:".length).trim();
            break;
          }
        }

        routes.push({
          method,
          path: fullPath,
          tag,
          parameters: buildParameters(meta),
          body: meta.body,
          responses: buildResponses(meta),
          summary,
        });
      }

      //
      // If nothing was found, keep the default behavior
      else {
        routes.push({
          method,
          path: fullPath,
          tag,
          parameters: undefined,
          body: undefined,
          responses: undefined,
          summary: undefined,
        });
      }
    }
  }

  return routes;
}

function pathParamsToBraces(path: string): string {
  return path.replace(/:([a-zA-Z0-9_]+)/g, "{$1}");
}

async function scanRoutes(routesRoot: string, apiBasePrefix: string): Promise<RouteDoc[]> {
  const files = await findRouteFiles(routesRoot);
  const docs: RouteDoc[] = [];
  for (const filePath of files) {
    const source = await fs.readFile(filePath, "utf8");
    const rel = path.relative(routesRoot, filePath).replace(/\\/g, "/");
    const segments = rel.split("/");

    if (segments.length < 2) continue;

    const versionSegment = segments[0];
    const fileName = segments[segments.length - 1];
    const resourceName = fileName.replace(/\.ts$/, "");

    const resourceSegment = toKebabCase(resourceName);
    const tag = `${apiBasePrefix}/${versionSegment}`;
    const basePath = `${apiBasePrefix}/${versionSegment}/${resourceSegment}`;

    const routes = await extractRoutesFromSource(source, basePath, tag, filePath);

    docs.push(...routes);
  }

  return docs.map((route) => ({ ...route, path: pathParamsToBraces(route.path) }));
}

function buildPathsObject(routes: RouteDoc[], routeDescriptions: Record<string, string>): PathsObject {
  const paths: PathsObject = {};
  for (const route of routes) {
    if (!paths[route.path]) {
      paths[route.path] = {};
    }
    const pathItem = paths[route.path];
    const segments = route.path.replace(/^\//, "").split("/");
    const tag = segments.length > 0 ? segments[0] : route.path;
    let description;
    for (const key in routeDescriptions) {
      if (route.path.startsWith(key)) {
        description = routeDescriptions[key];
        break;
      }
    }
    const requestBody =
      route.body && Object.keys(route.body).length > 0
        ? {
            required: true,
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: Object.fromEntries(Object.entries(route.body).map(([k, v]) => [k, { type: toOpenApiType(v) }])),
                  required: Object.keys(route.body),
                },
                example: Object.fromEntries(Object.keys(route.body).map((k) => [k, "string"])),
              },
            },
          }
        : undefined;
    pathItem[route.method] = {
      summary: route.summary && route.summary.length > 0 ? route.summary : "",
      description,
      tags: [tag],
      ...(route.parameters ? { parameters: route.parameters } : {}),
      ...(requestBody ? { requestBody } : {}),
      ...(route.responses ? { responses: route.responses } : {}),
    };
  }
  return paths;
}

async function main(): Promise<void> {
  // clear openapi folder
  try {
    const files = await fs.readdir(path.join(process.cwd(), "openapi"));
    for (const file of files) {
      if (file.endsWith(".json")) {
        await fs.unlink(path.join(process.cwd(), "openapi", file));
      }
    }
  } catch {
    //
  }

  const projectRoot = process.cwd();
  const routesRoot = path.join(projectRoot, "src/routes/api");

  const openapiDir = path.join(projectRoot, "openapi");
  try {
    await fs.mkdir(openapiDir);
  } catch {
    // ignore si déjà existant
  }
  const stats = await fs.stat(routesRoot);
  if (!stats.isDirectory()) {
    throw new Error(`Missing routes directory at ${routesRoot}`);
  }

  const indexFile = path.join(routesRoot, "index.ts");
  const indexSource = await fs.readFile(indexFile, "utf8");

  const routeUseRegex = /router\.use\(["'`](\/api\/[a-zA-Z0-9-]+)["'`],\s*([a-zA-Z0-9_]+)/g;
  const versions: string[] = [];

  let match: RegExpExecArray | null = null;
  while ((match = routeUseRegex.exec(indexSource)) !== null) {
    const versionPath = match[1];

    versions.push(versionPath);
  }

  const apiBasePrefix = "/api";
  const routes = await scanRoutes(routesRoot, apiBasePrefix);

  for (const version of versions) {
    const versionName = version.replace("/api/", "");
    const routeDescriptions = await extractRouteDescriptionsForVersion(routesRoot, versionName);
    const routesForVersion = routes.filter((r) => r.path.startsWith(version + "/"));
    const pathsRel: typeof routesForVersion = routesForVersion.map((r) => ({
      ...r,
      path: r.path.replace(version, ""),
      tag: version,
    }));
    const openapiVersionPath = path.join(openapiDir, `openapi.${versionName}.json`);

    const tagsSection = Object.entries(routeDescriptions).map(([route, desc]) => {
      const tagName = route.replace(/\//g, "").toLowerCase();
      return { name: tagName, description: desc };
    });
    const docVersion = {
      openapi: "3.0.3",
      info: {
        title: `API ${versionName}`,
        version: versionName,
      },
      servers: [{ url: version }],
      components: {},
      tags: tagsSection,
      paths: buildPathsObject(pathsRel, routeDescriptions),
    };
    await fs.writeFile(openapiVersionPath, JSON.stringify(docVersion, null, 2), "utf8");
  }

  for (const version of versions) {
    const routesForVersion = routes.filter((r) => r.path.startsWith(version + "/"));
    const header = `✅ OpenAPI ${version} généré (${routesForVersion.length} routes):`;
    const lines = routesForVersion.map((r) => `  • ${r.method.toUpperCase()} ${r.path.replace(version, "")}`);
    console.log([header, ...lines, ""].join("\n"));
  }
}

void main();
