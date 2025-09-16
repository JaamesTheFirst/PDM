import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { RoutesModule } from './routes/routes.module';
import { StationsModule } from './stations/stations.module';
import { VehiclesModule } from './vehicles/vehicles.module';
import { HealthController } from './health/health.controller';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    PrismaModule,
    AuthModule,
    UsersModule,
    RoutesModule,
    StationsModule,
    VehiclesModule,
  ],
  controllers: [HealthController],
})
export class AppModule {}
