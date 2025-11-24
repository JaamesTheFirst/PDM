export interface GiraStationRecordDto {
  [column: string]: string | number | null;
}

export interface GiraStationsSliceDto {
  total: number;
  slice: GiraStationRecordDto[];
}

