import { Router } from 'express';
import { AssistantController } from '../controllers/assistant_controller';
import { db } from '../config/database';
import { requireAuth } from '../middleware/auth';

const router = Router();
const assistantController = new AssistantController(db);

router.post('/ask', requireAuth, assistantController.ask.bind(assistantController));

export default router;
