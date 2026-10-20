import { Router } from 'express';
import { AdminController } from '../controllers/admin_controller';
import { db } from '../config/database';

const router = Router();
const adminController = new AdminController(db);

router.get('/backup', adminController.backup.bind(adminController));
router.get('/db', adminController.health.bind(adminController));

export default router;
