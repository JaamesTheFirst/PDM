// backend/src/gbfs/dto/get-gbfs-feed.dto.ts
import { IsOptional, IsString } from 'class-validator';

export class GetGbfsFeedQueryDto {
  @IsString()
  name: string; // ex: "station_information", "station_status"

  @IsOptional()
  @IsString()
  lang?: string; // opcional: "pt", "en", etc.
}
