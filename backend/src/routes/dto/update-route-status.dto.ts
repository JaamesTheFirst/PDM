import { IsEnum } from 'class-validator';
import { RouteStatus } from '@prisma/client';

export class UpdateRouteStatusDto {
  @IsEnum(RouteStatus)
  status: RouteStatus;
}
