import { IsNotEmpty, IsObject } from 'class-validator';
import { OtpItinerary } from '../otp.service';

export class SaveRouteDto {
  @IsObject()
  @IsNotEmpty()
  itinerary: OtpItinerary;
}
