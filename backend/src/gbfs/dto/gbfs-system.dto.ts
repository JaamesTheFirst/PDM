// backend/src/gbfs/dto/gbfs-system.dto.ts
export class GbfsSystemDto {
  id: number;
  countryCode: string;
  name: string;
  location?: string | null;
  systemId: string;
  url?: string | null;
  autoDiscoveryUrl?: string | null;
  supportedVersions?: string | null;
  authenticationInfoUrl?: string | null;
}
