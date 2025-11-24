import { Body, Controller, Post } from '@nestjs/common';
import { OtpService, OtpItinerary } from './otp.service';
import { PlanItineraryDto } from './dto/plan-itinerary.dto';

@Controller('routes')
export class RoutesController {
  constructor(private readonly otpService: OtpService) {}

  @Post('plan')
  planTrip(@Body() dto: PlanItineraryDto): Promise<OtpItinerary[]> {
    return this.otpService.plan(dto);
  }
}

