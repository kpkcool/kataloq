import type { RequestHandler } from 'express';
import { enquirySchema } from '../domain/enquiry.js';
import { parseInput } from '../http/validate.js';
import { UnsupportedMediaTypeError } from '../http/errors.js';
import type { EnquiryService } from '../services/EnquiryService.js';

export function createEnquiryController(enquiries: EnquiryService) {
  /**
   * POST /api/v1/enquiries
   * 202 Accepted only after the email provider accepted the message: inbox delivery
   * itself is asynchronous and can't be confirmed (AS-7).
   */
  const submit: RequestHandler = async (req, res) => {
    if (!req.is('application/json')) throw new UnsupportedMediaTypeError();

    const enquiry = parseInput(enquirySchema, req.body ?? {});
    const { enquiryId } = await enquiries.submit(enquiry);

    res.setHeader('Cache-Control', 'no-store');
    res.status(202).json({ enquiryId, status: 'sent' });
  };

  return { submit };
}
