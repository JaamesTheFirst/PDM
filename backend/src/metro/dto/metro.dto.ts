export type MetroLineId = 'amarela' | 'azul' | 'verde' | 'vermelha';

export interface MetroLineStatusSummaryDto {
  amarela: string;
  azul: string;
  verde: string;
  vermelha: string;
  tipo_msg_am: string;
  tipo_msg_az: string;
  tipo_msg_vd: string;
  tipo_msg_vm: string;
  amarela_curta: string;
  azul_curta: string;
  verde_curta: string;
  vermelha_curta: string;
}

export interface MetroStationInfoDto {
  stop_id: string;
  stop_name: string;
  stop_lat: string;
  stop_lon: string;
  stop_url?: string;
  linha?: string;
  zone_id?: string;
}

export interface MetroWaitingTimeDto {
  stop_id: string;
  cais: string;
  hora: string;
  comboio: string;
  tempoChegada1: string;
  comboio2?: string;
  tempoChegada2?: string;
  comboio3?: string;
  tempoChegada3?: string;
  destino: string;
  sairServico: string;
  UT?: string;
}

export interface MetroDestinationDto {
  id_destino: string;
  nome_destino: string;
}

export interface MetroIntervalDto {
  Linha: string;
  HoraInicio: string;
  HoraFim: string;
  Intervalo: string;
  UT: number;
  Dia?: string;
}

