import { Router } from 'express';
import { AlertController } from '../controllers/alertController';
import { db } from '../config/database';

const router = Router();
const alertController = new AlertController(db);

router.get('/nearby', alertController.getNearby.bind(alertController));
router.post('/', alertController.createAlert.bind(alertController));
router.get('/messages', alertController.getMessages.bind(alertController));
router.post('/messages', alertController.createMessage.bind(alertController));

export default router;
