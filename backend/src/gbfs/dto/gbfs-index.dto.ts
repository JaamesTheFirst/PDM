// backend/src/gbfs/dto/gbfs-index.dto.ts

export interface GbfsFeedMeta {
  name: string;
  url: string;
}

export interface GbfsIndexLanguageBlock {
  feeds: GbfsFeedMeta[];
}

export interface GbfsIndexDto {
  last_updated: number;
  ttl: number;
  data: Record<string, GbfsIndexLanguageBlock>; // "pt", "en", ...
  version: string;
}
