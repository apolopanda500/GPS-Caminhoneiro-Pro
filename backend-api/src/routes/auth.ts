import { Router } from 'express';
import { AuthController } from '../controllers/authController';
import { db } from '../config/database';

const router = Router();
const authController = new AuthController(db);

router.post('/register', authController.register.bind(authController));
router.post('/verify', authController.verifyCode.bind(authController));
router.post('/resend', authController.resendCode.bind(authController));
router.post('/login', authController.login.bind(authController));
router.post('/profile', authController.updateProfile.bind(authController));

export default router;
