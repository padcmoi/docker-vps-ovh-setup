import { Router } from "express";
import AgencyGroupRouter from "./endpoints/agency-group";
import healthRouter from "./endpoints/health";

const router = Router();

/**
 * @openapi-desc
 * Route santé : description personnalisée pour le tag health
 *
 */
router.use("/health", healthRouter);

/**
 * @openapi-desc
 * Route agency-group : model agency group
 */
router.use("/agency-group", AgencyGroupRouter);

export default router;
