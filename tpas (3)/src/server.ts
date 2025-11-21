import "dotenv/config";
import app from "./app";
import { env } from "./config/index";
import { logger } from "./lib/logger";

const port = env.PORT;

const server = app.listen(port, () => {
  logger.info({ port }, `HTTP server listening on port ${port}`);
});

// graceful shutdown
const signals: NodeJS.Signals[] = ["SIGINT", "SIGTERM"];
for (const sig of signals) {
  process.on(sig, () => {
    logger.info({ sig }, "Shutting down...");
    server.close(() => process.exit(0));
    // force exit after 5s
    setTimeout(() => process.exit(1), 5000).unref();
  });
}
