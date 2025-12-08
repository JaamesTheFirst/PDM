import { IsEnum } from 'class-validator';
import { RouteStatus } from '@prisma/client';

/**
 * DTO para atualizar o estado de uma RouteHistory
 * (ex: PLANNED → COMPLETED ou CANCELLED).
 */
export class UpdateRouteStatusDto {
  @IsEnum(RouteStatus)
  status: RouteStatus;
}
