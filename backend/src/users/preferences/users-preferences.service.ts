import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { UpdatePreferencesDto } from '../dto/update-preferences.dto';

@Injectable()
export class UsersPreferencesService {
  constructor(private prisma: PrismaService) {}

  async updatePreferences(userId: string, prefs: UpdatePreferencesDto) {
    // Normalize alias fields to canonical names
    const normalized: any = { ...prefs };
    if (prefs.preferredTransport && !prefs.preferredTransportModes) {
      normalized.preferredTransportModes = prefs.preferredTransport;
    }
    if (prefs.preferredModes && !prefs.preferredTransportModes) {
      normalized.preferredTransportModes = prefs.preferredModes;
    }
    if (prefs.radiusKm !== undefined && prefs.maxWalkingDistance === undefined) {
      // convert km -> meters
      normalized.maxWalkingDistance = Math.round(Number(prefs.radiusKm) * 1000);
    }

    const updateData: any = {};
    if (normalized.preferredTransportModes !== undefined) {
      updateData.preferredTransportModes = { set: normalized.preferredTransportModes };
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
      console.error('ERROR usersPreferences.updatePreferences', err);
      throw new InternalServerErrorException(err?.message || 'Failed to update preferences');
    }
  }

  async getPreferences(userId: string) {
    return this.prisma.userPreferences.findUnique({ where: { userId } });
  }
}
