import { Router } from "express";
import { getHealth } from "../../../../controllers/v1/healthController";

const router = Router();

router.get("/", getHealth);

export default router;
