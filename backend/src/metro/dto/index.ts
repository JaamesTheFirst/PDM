// src/metro/dto/index.ts
//
// Re-export dos DTOs relacionados com Metro Lisboa e Metro do Porto.
// Facilita imports do tipo:
//
//   import { MetroLineStatusSummaryDto, MetroPortoRouteDto } from './dto';

export * from './metro.dto';          // DTOs da API oficial do Metro de Lisboa
export * from './metro-porto.dto';    // DTOs do Metro do Porto via OTP/GTFS
