import {
  Injectable,
  BadRequestException,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateStationDto } from './dto/create-station.dto';
import { UpdateStationDto } from './dto/update-station.dto';

/**
 * Service responsável por:
 * - criar / atualizar / remover stations
 * - listar com filtros (tipo, cidade, bbox)
 * - normalizar o stationType
 */
@Injectable()
export class StationsService {
  constructor(private prisma: PrismaService) {}

  /**
   * Cria uma nova Station na BD.
   * - Normaliza stationType (alias → enum)
   * - Lida com erros de unique constraint (externalId, etc.) devolvendo 409.
   */
  async create(data: CreateStationDto) {
    // Normalize stationType aliases antes de persistir
    if (data.stationType) {
      data.stationType = this.normalizeStationType(data.stationType);
    }

    // externalId (ou outras uniques) são validadas por Prisma. Capturamos P2002 → 409.
    try {
      return await this.prisma.station.create({ data: data as any });
    } catch (err: any) {
      // Prisma unique constraint error code = P2002
      if (
        err instanceof Prisma.PrismaClientKnownRequestError &&
        err.code === 'P2002'
      ) {
        // Determinar campo que falhou (se disponível)
        const target =
          (err.meta && (err.meta.target || err.meta.field_name)) ||
          'unique field';
        throw new ConflictException(`Unique constraint failed: ${target}`);
      }
      // Outros erros sobem como estão (Internal Server Error por Nest)
      throw err;
    }
  }

  /**
   * Lista stations com filtros opcionais:
   * - limit / offset → paginação
   * - type → filtro de stationType (alias ou enum; normalizado aqui)
   * - city → filtro textual insensível a maiúsculas/minúsculas
   * - bbox → bounding box "minLng,minLat,maxLng,maxLat"
   */
  async findAll(query: {
    limit?: number;
    offset?: number;
    type?: string;
    city?: string;
    bbox?: string;
  }) {
    const { limit = 50, offset = 0, type, city, bbox } = query as any;

    const where: any = {};
    if (type) where.stationType = this.normalizeStationType(type);
    if (city) where.city = { contains: city, mode: 'insensitive' };

    if (bbox) {
      const parts = bbox.split(',').map(Number);
      if (parts.length !== 4 || parts.some(isNaN)) {
        throw new BadRequestException('Invalid bbox format');
      }
      const [minLng, minLat, maxLng, maxLat] = parts;
      // Filtro simples por bounding box em latitude/longitude
      where.latitude = { gte: minLat, lte: maxLat };
      where.longitude = { gte: minLng, lte: maxLng };
    }

    return this.prisma.station.findMany({
      where,
      take: Number(limit),
      skip: Number(offset),
      orderBy: { name: 'asc' },
    });
  }

  /**
   * Devolve uma Station por ID ou lança NotFoundException se não existir.
   */
  async findOne(id: string) {
    const station = await this.prisma.station.findUnique({ where: { id } });
    if (!station) throw new NotFoundException('Station not found');
    return station;
  }

  /**
   * Atualiza parcialmente uma Station:
   * - verifica se existe
   * - normaliza stationType se for enviado
   */
  async update(id: string, data: UpdateStationDto) {
    await this.findOne(id); // lança se não existir
    if (data.stationType) {
      data.stationType = this.normalizeStationType(data.stationType as any);
    }
    return this.prisma.station.update({ where: { id }, data: data as any });
  }

  /**
   * Remove uma Station.
   * - Se existir → delete e devolve o registo apagado
   * - Se não existir → devolve null (delete idempotente)
   */
  async remove(id: string) {
    // Tentar eliminar; se já não existir, devolve null para comportamento idempotente.
    try {
      return await this.prisma.station.delete({ where: { id } });
    } catch (err: any) {
      if (
        err instanceof Prisma.PrismaClientKnownRequestError &&
        err.code === 'P2025'
      ) {
        // Registo a apagar não existe
        return null;
      }
      throw err;
    }
  }

  /**
   * Normaliza stationType:
   * - aceita alias (ex: "BIKE") → converte para enum (ex: "BIKE_STATION")
   * - aceita o valor completo do enum (ex: "BIKE_STATION") se for válido
   *
   * Lança BadRequestException para valores inválidos.
   */
  private normalizeStationType(value: string) {
    if (!value || typeof value !== 'string') {
      throw new BadRequestException('Invalid stationType');
    }

    const v = value.toUpperCase();

    // Mapeamento de aliases → valores de enum
    const mapping: Record<string, string> = {
      BIKE: 'BIKE_STATION',
      SCOOTER: 'SCOOTER_STATION',
      BUS: 'BUS_STOP',
      TRAIN: 'TRAIN_STATION',
      METRO: 'METRO_STATION',
      CHARGING: 'CHARGING_STATION',
      GENERIC: 'GENERIC',
    };

    // Conjunto de possíveis valores finais (ex: "BIKE_STATION", "SCOOTER_STATION", ...)
    const possible = Object.keys(mapping).map((k) => mapping[k]);

    // Se já for um valor final conhecido, aceita.
    if (possible.includes(v)) return v;

    // Check redundante, mas tolerante: aceita se corresponder a algum value do mapping.
    if (Object.values(mapping).includes(v)) return v;

    // Se for alias (ex: "BIKE"), mapeia para o enum correspondente.
    if (mapping[v]) return mapping[v];

    throw new BadRequestException(`Invalid stationType: ${value}`);
  }
}
