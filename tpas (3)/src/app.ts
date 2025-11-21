import express from "express";
// import pinoHttp from "pino-http";
// import { logger } from "./lib/logger";
import { installSwagger } from "./lib/swagger";
import { errorHandler } from "./middlewares/errorHandler";
import { jsonLimiter } from "./middlewares/jsonLimiter";
import { notFound } from "./middlewares/notFound";
import { requestId } from "./middlewares/requestId";
import router from "./routes/api/index";

const app = express();

// Core middlewares
app.use(requestId);
// app.use(pinoHttp({ logger }));
app.use(express.json({ limit: "1mb" }));
app.use(jsonLimiter());

// Routes
app.use(router);

installSwagger(app);

// 404 + error handling
app.use(notFound);
app.use(errorHandler);

export default app;
