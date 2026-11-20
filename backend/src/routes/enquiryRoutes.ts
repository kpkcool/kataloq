import express, { type RequestHandler, type Router } from 'express';
import type { EnquiryService } from '../services/EnquiryService.js';
import { createEnquiryController } from '../controllers/enquiryController.js';

/** Enquiry endpoint, mounted under /api/v1. The rate limiter applies to this route only. */
export function enquiryRoutes(enquiries: EnquiryService, rateLimiter: RequestHandler): Router {
  const controller = createEnquiryController(enquiries);
  const router = express.Router();

  router.post('/enquiries', rateLimiter, controller.submit);

  return router;
}
