import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { UpdatePreferencesDto } from '../dto/update-preferences.dto';

@Injectable()
export class UsersPreferencesService {
  constructor(private prisma: PrismaService) {}

  async updatePreferences(userId: string, prefs: UpdatePreferencesDto) {
    const updateData: any = {};
    if (prefs.preferredTransportModes !== undefined) {
      updateData.preferredTransportModes = { set: prefs.preferredTransportModes };
    }
    if (prefs.maxWalkingDistance !== undefined) {
      updateData.maxWalkingDistance = prefs.maxWalkingDistance;
    }
    if (prefs.avoidHighways !== undefined) {
      updateData.avoidHighways = prefs.avoidHighways;
    }
    if (prefs.ecoFriendlyOnly !== undefined) {
      updateData.ecoFriendlyOnly = prefs.ecoFriendlyOnly;
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
