export interface CpVehicleDto {
  trainNumber: number;
  runDate: string;
  delay: number | null;
  lastStation: string | null;
  latitude: string | null;
  longitude: string | null;
  status: string;
  hasDisruptions: boolean;
  service: {
    code: string;
    designation: string;
  };
  origin: {
    code: string;
    designation: string;
  };
  destination: {
    code: string;
    designation: string;
  };
}

export interface CpVehiclesApiResponse {
  vehicles: CpVehicleDto[];
}

