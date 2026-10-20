import { Router } from 'express';
import { GroupController } from '../controllers/group_controller';
import { db } from '../config/database';

const router = Router();
const groupController = new GroupController(db);

router.get('/', groupController.listForDriver.bind(groupController));
router.post('/', groupController.create.bind(groupController));
router.get('/:id/members', groupController.listMembers.bind(groupController));
router.post('/:id/join', groupController.join.bind(groupController));
router.post('/:id/leave', groupController.leave.bind(groupController));
router.post('/:id/routes', groupController.shareRoute.bind(groupController));
router.get('/:id/routes', groupController.listRoutes.bind(groupController));

export default router;
