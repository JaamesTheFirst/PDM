import { Injectable, BadRequestException, NotFoundException, ConflictException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateStationDto } from './dto/create-station.dto';
import { UpdateStationDto } from './dto/update-station.dto';

@Injectable()
export class StationsService {
  constructor(private prisma: PrismaService) {}

  async create(data: CreateStationDto) {
    // Normalize stationType aliases before persisting
    if (data.stationType) {
      data.stationType = this.normalizeStationType(data.stationType);
    }

    // externalId uniqueness is enforced by Prisma. Catch duplicate errors to return 409.
    try {
      return await this.prisma.station.create({ data: data as any });
    } catch (err: any) {
      // Prisma unique constraint error code = P2002
      if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
        // Determine which field caused the conflict if possible
        const target = (err.meta && (err.meta.target || err.meta.field_name)) || 'unique field';
        throw new ConflictException(`Unique constraint failed: ${target}`);
      }
      // rethrow other errors as internal server error
      throw err;
    }
  }

  /**
   * Find stations with optional filters: limit, offset, type, city, bbox
   * bbox format: minLng,minLat,maxLng,maxLat
   */
  async findAll(query: { limit?: number; offset?: number; type?: string; city?: string; bbox?: string }) {
    const { limit = 50, offset = 0, type, city, bbox } = query as any;

    const where: any = {};
    if (type) where.stationType = this.normalizeStationType(type);
    if (city) where.city = { contains: city, mode: 'insensitive' };

    if (bbox) {
      const parts = bbox.split(',').map(Number);
      if (parts.length !== 4 || parts.some(isNaN)) throw new BadRequestException('Invalid bbox format');
      const [minLng, minLat, maxLng, maxLat] = parts;
      // simple bounding box filter using latitude/longitude
      where.latitude = { gte: minLat, lte: maxLat };
      where.longitude = { gte: minLng, lte: maxLng };
    }

    return this.prisma.station.findMany({ where, take: Number(limit), skip: Number(offset), orderBy: { name: 'asc' } });
  }

  async findOne(id: string) {
    const station = await this.prisma.station.findUnique({ where: { id } });
    if (!station) throw new NotFoundException('Station not found');
    return station;
  }

  async update(id: string, data: UpdateStationDto) {
    await this.findOne(id); // throws if not exists
    if (data.stationType) data.stationType = this.normalizeStationType(data.stationType as any);
    return this.prisma.station.update({ where: { id }, data: data as any });
  }

  async remove(id: string) {
    // Attempt delete; if record is already gone, return null to indicate idempotent delete.
    try {
      return await this.prisma.station.delete({ where: { id } });
    } catch (err: any) {
      if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2025') {
        // Record to delete does not exist
        return null;
      }
      throw err;
    }
  }

  // Accept either a full enum name (e.g. 'BIKE_STATION') or a short alias ('BIKE') and
  // map it to a valid `StationType` value. Throws BadRequestException for invalid inputs.
  private normalizeStationType(value: string) {
    if (!value || typeof value !== 'string') throw new BadRequestException('Invalid stationType');
    const v = value.toUpperCase();
    const mapping: Record<string, string> = {
      BIKE: 'BIKE_STATION',
      SCOOTER: 'SCOOTER_STATION',
      BUS: 'BUS_STOP',
      TRAIN: 'TRAIN_STATION',
      METRO: 'METRO_STATION',
      CHARGING: 'CHARGING_STATION',
      GENERIC: 'GENERIC',
    };

    // If it's already a valid enum (contains underscore), accept it if in enum set
    const possible = Object.keys(mapping).map(k => mapping[k]);
    if (possible.includes(v)) return v;

    // If value equals one of mapping values directly (e.g. 'BIKE_STATION')
    if (Object.values(mapping).includes(v)) return v;

    // Map alias if exists
    if (mapping[v]) return mapping[v];

    throw new BadRequestException(`Invalid stationType: ${value}`);
  }
}
