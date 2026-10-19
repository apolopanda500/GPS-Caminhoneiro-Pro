import { Router } from 'express';
import { PaymentController } from '../controllers/payment_controller';
import { db } from '../config/database';

const router = Router();
const paymentController = new PaymentController(db);

router.post('/pix', paymentController.createPixPayment.bind(paymentController));
router.post('/confirm', paymentController.confirmPremium.bind(paymentController));

export default router;
