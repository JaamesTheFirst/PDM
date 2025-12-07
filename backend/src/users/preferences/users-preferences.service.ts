import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { UpdatePreferencesDto } from '../dto/update-preferences.dto';

/**
 * Service isolado para leitura/atualização das preferências do utilizador
 * (userPreferences).
 *
 * Responsável por:
 * - normalizar aliases do DTO para campos canónicos
 * - fazer upsert na tabela userPreferences
 */
@Injectable()
export class UsersPreferencesService {
  constructor(private prisma: PrismaService) {}

  /**
   * Atualiza (ou cria) as preferências de um utilizador.
   * - Converte aliases (preferredTransport, preferredModes → preferredTransportModes)
   * - Converte radiusKm (km) para maxWalkingDistance (metros)
   * - Usa upsert para garantir que existe sempre 1 registo por userId
   */
  async updatePreferences(userId: string, prefs: UpdatePreferencesDto) {
    // Normalizar campos alias para as propriedades canónicas
    const normalized: any = { ...prefs };

    // preferredTransport / preferredModes só são usados se a versão canónica não vier
    if (prefs.preferredTransport && !prefs.preferredTransportModes) {
      normalized.preferredTransportModes = prefs.preferredTransport;
    }
    if (prefs.preferredModes && !prefs.preferredTransportModes) {
      normalized.preferredTransportModes = prefs.preferredModes;
    }

    // radiusKm (km) → maxWalkingDistance (metros), se o canónico não vier
    if (prefs.radiusKm !== undefined && prefs.maxWalkingDistance === undefined) {
      normalized.maxWalkingDistance = Math.round(Number(prefs.radiusKm) * 1000);
    }

    // Construir objeto updateData só com campos definidos
    const updateData: any = {};
    if (normalized.preferredTransportModes !== undefined) {
      // array de strings em Prisma → usar { set: [...] }
      updateData.preferredTransportModes = {
        set: normalized.preferredTransportModes,
      };
    }
    if (normalized.maxWalkingDistance !== undefined) {
      updateData.maxWalkingDistance = normalized.maxWalkingDistance;
    }
    if (normalized.avoidHighways !== undefined) {
      updateData.avoidHighways = normalized.avoidHighways;
    }
    if (normalized.ecoFriendlyOnly !== undefined) {
      updateData.ecoFriendlyOnly = normalized.ecoFriendlyOnly;
    }

    try {
      const res = await this.prisma.userPreferences.upsert({
        where: { userId },
        update: updateData,
        create: {
          user: { connect: { id: userId } },
          ...updateData,
        },
      });
      return res;
    } catch (err) {
      // log simples para debug server-side
      console.error('ERROR usersPreferences.updatePreferences', err);
      // envolver num InternalServerErrorException para não vazar detalhe de erro interno
      throw new InternalServerErrorException(
        err?.message || 'Failed to update preferences',
      );
    }
  }

  /**
   * Lê as preferências de um utilizador (ou null se ainda não existirem).
   */
  async getPreferences(userId: string) {
    return this.prisma.userPreferences.findUnique({ where: { userId } });
  }
}
