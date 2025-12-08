// src/metro/dto/metro.dto.ts
//
// DTOs específicos da API oficial do Metro de Lisboa,
// usada para tempos de espera, estados de linha, etc.

/**
 * Identificador semântico de linha do Metro de Lisboa.
 * A string é usada diretamente na API do Metro.
 */
export type MetroLineId = 'amarela' | 'azul' | 'verde' | 'vermelha';

/**
 * Resumo de estado das linhas do Metro de Lisboa.
 *
 * O backend do Metro devolve um objeto "flat" com campos por linha
 * e por tipo de mensagem, por isso estes nomes seguem o contrato deles.
 */
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

/**
 * Informação estática de uma estação do Metro de Lisboa.
 */
export interface MetroStationInfoDto {
  stop_id: string;
  stop_name: string;
  stop_lat: string;
  stop_lon: string;
  stop_url?: string;
  linha?: string;
  zone_id?: string;
}

/**
 * Tempo de espera numa estação/cais, tal como devolvido pela API.
 *
 * A API devolve vários campos de comboios e tempos de chegada
 * (1º, 2º, 3º comboio).
 */
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

/**
 * Destino de linha (ex: "Odivelas", "Cais do Sodré").
 */
export interface MetroDestinationDto {
  id_destino: string;
  nome_destino: string;
}

/**
 * Intervalos de circulação por linha/direção na API do Metro.
 */
export interface MetroIntervalDto {
  Linha: string;
  HoraInicio: string;
  HoraFim: string;
  Intervalo: string;
  UT: number;
  Dia?: string;
}
