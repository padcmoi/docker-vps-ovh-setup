import pino from "pino";
import { env } from "../config/index";

export const logger = pino({
  level: env.LOG_LEVEL,
  transport:
    env.NODE_ENV !== "production"
      ? {
          targets: [
            {
              target: "pino-pretty",
              options: {
                translateTime: "SYS:standard",
                colorize: true,
                singleLine: false,
              },
            },
          ],
        }
      : undefined,
});
