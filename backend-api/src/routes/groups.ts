import { Router } from 'express';
import { GroupController } from '../controllers/group_controller';
import { db } from '../config/database';
import { requireAuth } from '../middleware/auth';

const router = Router();
const groupController = new GroupController(db);

router.get('/', requireAuth, groupController.listForDriver.bind(groupController));
router.post('/', requireAuth, groupController.create.bind(groupController));
router.get('/:id/members', requireAuth, groupController.listMembers.bind(groupController));
router.post('/:id/join', requireAuth, groupController.join.bind(groupController));
router.post('/:id/leave', requireAuth, groupController.leave.bind(groupController));
router.post('/:id/routes', requireAuth, groupController.shareRoute.bind(groupController));
router.get('/:id/routes', requireAuth, groupController.listRoutes.bind(groupController));
router.patch(
  '/:id/routes/:shareId',
  requireAuth,
  groupController.editarRota.bind(groupController),
);
router.delete(
  '/:id/routes/:shareId',
  requireAuth,
  groupController.removerRota.bind(groupController),
);

export default router;
