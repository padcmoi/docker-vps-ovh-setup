import { Router } from "express";
import { createAgencyGroup, deletegetAllAgencyGroup, getAllAgencyGroup } from "../../../../controllers/v1/agencyGroupController";

const router = Router();

router.get("/", getAllAgencyGroup);

router.post("/", createAgencyGroup);

router.delete("/all", deletegetAllAgencyGroup);

export default router;
