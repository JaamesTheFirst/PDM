// backend/src/gbfs/dto/get-gbfs-feed.dto.ts
import { IsOptional, IsString } from 'class-validator';

/**
 * Query params para obter um feed específico de um sistema GBFS.
 *
 * Usado em:
 *   GET /gbfs/:systemId/feed?name=station_information&lang=pt
 */
export class GetGbfsFeedQueryDto {
  @IsString()
  name: string; // ex: "station_information", "station_status"

  @IsOptional()
  @IsString()
  lang?: string; // opcional: "pt", "en", etc.
}
