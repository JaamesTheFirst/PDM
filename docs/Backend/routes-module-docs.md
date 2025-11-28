
# Documentação do Módulo Routes (Planeamento de Viagens)

Este documento descreve, de forma detalhada e profissional, a implementação do módulo **Routes** no backend (NestJS), responsável por:

- Comunicar com o **OpenTripPlanner v2 (OTP)** via GraphQL.
- Planear itinerários multimodais entre dois pontos (origem/destino).
- Filtrar itinerários por tipo de transporte (ex.: só comboio, só autocarro, etc.).
- Calcular métricas agregadas (distância total, distância a pé, modos usados).
- Guardar viagens concretas no histórico (`RouteHistory`) associado ao utilizador autenticado.
- Expor endpoints REST bem definidos e testáveis via Postman.

> Nota: A terminologia e exemplos são escritos em **Português de Portugal**.

---

## 1. Contexto e Objectivos

O módulo **Routes** é o “cérebro” do planeamento de viagens na aplicação.  
Ele faz a ponte entre:

- O grafo multimodal do OTP (conteúdo GTFS/OSM, etc.).
- As preferências do utilizador (guardadas na base de dados).
- O histórico de viagens e estatísticas ecológicas.

Os objectivos principais:

1. **Planeamento de rota**  
   Dado um par de coordenadas (origem, destino) e alguns parâmetros, obter itinerários possíveis a partir do OTP.

2. **Filtragem por modos**  
   Permitir ao frontend pedir:
   - só itinerários com comboio,
   - só itinerários sem comboio,
   - etc.

3. **Histórico de viagens (RouteHistory)**  
   Quando o utilizador escolhe uma rota, guardar essa viagem na base de dados, incluindo:
   - Origem/destino (nome + coordenadas).
   - Lista de modos usados.
   - Distância total e duração total.
   - Métricas de CO2, quando disponíveis.

---

## 2. Dependências e Configuração

### 2.1. Módulo NestJS

O módulo **Routes** vive em `src/routes` e é composto, tipicamente, pelos seguintes ficheiros:

- `routes.module.ts`
- `routes.controller.ts`
- `otp.service.ts` (serviço específico para falar com o OTP)
- `routes.service.ts` (lógica de negócio: filtragem, histórico, etc.)
- `dto/` (subpasta com DTOs)

#### 2.1.1. Módulo

```ts
// src/routes/routes.module.ts
import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { ConfigModule } from '@nestjs/config';
import { RoutesController } from './routes.controller';
import { OtpService } from './otp.service';
import { RoutesService } from './routes.service';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [HttpModule, ConfigModule, PrismaModule],
  controllers: [RoutesController],
  providers: [OtpService, RoutesService],
  exports: [OtpService, RoutesService],
})
export class RoutesModule {}
```

### 2.2. Variáveis de ambiente

```env
OTP_BASE_URL=http://localhost:8080/otp
```

- **`OTP_BASE_URL`**  
  URL base do OpenTripPlanner v2.  
  O módulo assume o endpoint GraphQL em:
  - `${OTP_BASE_URL}/routers/default/index/graphql`

### 2.3. Integração com Auth e Prisma

- O módulo **Routes** utiliza:
  - `JwtAuthGuard` para proteger endpoints que dependem do utilizador (histórico).
  - `PrismaService` para gravar entradas na tabela `RouteHistory` (e futuramente para estatísticas ecológicas).

---

## 3. Modelos de Base de Dados (Prisma)

Os modelos relevantes para o módulo Routes já existem no `schema.prisma`:

### 3.1. RouteHistory

```prisma
model RouteHistory {
  id      String @id @default(cuid())
  userId  String
  user    User   @relation(fields: [userId], references: [id], onDelete: Cascade)

  routeId String?
  route   Route? @relation(fields: [routeId], references: [id])

  originName             String
  originLatitude         Float
  originLongitude        Float
  destinationName        String
  destinationLatitude    Float
  destinationLongitude   Float

  primaryMode            TransportMode
  modes                  TransportMode[]

  distanceMeters         Int
  durationSeconds        Int
  co2Kg                  Float
  co2SavedVsCarKg        Float?

  status                 RouteStatus @default(PLANNED)
  startedAt              DateTime
  finishedAt             DateTime?

  polyline               String?
  segments               Json?
  metadata               Json?

  createdAt              DateTime   @default(now())
  updatedAt              DateTime   @updatedAt

  @@index([userId, startedAt(sort: Desc)])
  @@index([primaryMode])
  @@map("routes_history")
}
```

### 3.2. EmissionFactor (opcional para CO2)

```prisma
model EmissionFactor {
  id         String        @id @default(cuid())
  mode       TransportMode @unique
  kgCo2PerKm Float
  notes      String?

  createdAt  DateTime      @default(now())
  updatedAt  DateTime      @updatedAt

  @@map("emission_factors")
}
```

> Estes modelos permitem calcular e guardar emissões de CO2 por viagem, caso tenhas carregado factores de emissão por modo na tabela `emission_factors`.

---

## 4. DTOs do Módulo Routes

Todos os DTOs do módulo Routes vivem em `src/routes/dto`.

### 4.1. Enum de modos do OTP (`TransitMode`)

```ts
export enum TransitMode {
  BUS = 'BUS',
  TRAM = 'TRAM',
  METRO = 'METRO',
  RAIL = 'RAIL',
  COACH = 'COACH',
}
```

Este enum é usado apenas para limitar os modos transit no OTP (diferente do `TransportMode` do Prisma, que é mais genérico).

### 4.2. Enum de filtro de rota (`RouteFilterMode`)

```ts
export enum RouteFilterMode {
  ALL = 'ALL',
  RAIL_ONLY = 'RAIL_ONLY',
  BUS_ONLY = 'BUS_ONLY',
  NO_RAIL = 'NO_RAIL',
}
```

- `ALL` – não aplica filtro (todos os itinerários).
- `RAIL_ONLY` – apenas itinerários que tenham comboio como modo principal.
- `BUS_ONLY` – apenas itinerários cujo modo principal seja BUS.
- `NO_RAIL` – filtra fora itinerários que incluam RAIL.

### 4.3. DTO de pedido de planeamento (`PlanItineraryDto`)

```ts
import { IsArray, IsEnum, IsNumber, IsOptional } from 'class-validator';
import { Type } from 'class-transformer';
import { TransitMode, RouteFilterMode } from './enums';

export class PlanItineraryDto {
  @Type(() => Number)
  @IsNumber()
  fromLat: number;

  @Type(() => Number)
  @IsNumber()
  fromLon: number;

  @Type(() => Number)
  @IsNumber()
  toLat: number;

  @Type(() => Number)
  @IsNumber()
  toLon: number;

  @IsOptional()
  @IsArray()
  @IsEnum(TransitMode, { each: true })
  transitModes?: TransitMode[];

  @IsOptional()
  @IsEnum(RouteFilterMode)
  filterMode?: RouteFilterMode;
}
```

### 4.4. DTOs de itinerário OTP (response interno)

```ts
export interface OtpLeg {
  mode: string;
  distance: number;
  duration: number;
  startTime: number; // epoch ms
  endTime: number;   // epoch ms;
  from: {
    name: string;
    lat: number;
    lon: number;
  };
  to: {
    name: string;
    lat: number;
    lon: number;
  };
  route?: {
    shortName?: string;
    longName?: string;
  };
  legGeometry?: {
    points: string;
  };
}

export interface OtpItinerary {
  duration: number;
  walkDistance: number;
  startTime: number;
  endTime: number;
  legs: OtpLeg[];
}
```

> Estes são mapeamentos directos do que o OTP v2 devolve na query `plan`.

### 4.5. DTO de itinerário enriquecido no backend

```ts
import { TransportMode } from '@prisma/client';

export interface EnrichedItinerary extends OtpItinerary {
  modes: string[];               // ex.: ["WALK", "RAIL"]
  primaryMode: string;           // ex.: "RAIL"
  totalDistanceMeters: number;   // soma de distance das legs
  totalWalkDistanceMeters: number;
  hasBus: boolean;
  hasRail: boolean;
  hasCar: boolean;
  hasBicycle: boolean;
}
```

### 4.6. DTO da resposta /routes/plan

```ts
export interface PlanResponseDto {
  originalItineraryCount: number;
  filteredItineraryCount: number;
  filterApplied: {
    filterMode: RouteFilterMode;
  };
  itineraries: EnrichedItinerary[];
}
```

---

## 5. Serviço de Comunicação com OTP (`OtpService`)

### 5.1. Estrutura geral

```ts
import {
  BadGatewayException,
  Injectable,
  Logger,
} from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { ConfigService } from '@nestjs/config';
import { firstValueFrom } from 'rxjs';
import { PlanItineraryDto } from './dto';

@Injectable()
export class OtpService {
  private readonly logger = new Logger(OtpService.name);
  private readonly otpBaseUrl: string;

  constructor(
    private readonly http: HttpService,
    private readonly config: ConfigService,
  ) {
    this.otpBaseUrl =
      this.config.get<string>('OTP_BASE_URL') || 'http://localhost:8080/otp';
  }

  private get graphqlEndpoint(): string {
    return `${this.otpBaseUrl.replace(/\/$/, '')}/routers/default/index/graphql`;
  }

  // ...
}
```

### 5.2. Query GraphQL de planeamento (`plan`)

```ts
const PLAN_QUERY = `
query Plan(
  $from: String!,
  $to: String!
) {
  plan(
    fromPlace: $from,
    toPlace: $to
  ) {
    itineraries {
      duration
      walkDistance
      startTime
      endTime
      legs {
        mode
        distance
        duration
        startTime
        endTime
        from { name lat lon }
        to { name lat lon }
        route { shortName longName }
        legGeometry { points }
      }
    }
  }
}
`;
```

### 5.3. Chamada ao OTP e parsing

```ts
interface OtpGraphQlError {
  message: string;
}

interface OtpPlanResponse {
  data?: {
    plan?: {
      itineraries: OtpItinerary[];
    } | null;
  };
  errors?: OtpGraphQlError[];
}

@Injectable()
export class OtpService {
  // ...

  async plan(dto: PlanItineraryDto): Promise<OtpItinerary[]> {
    const endpoint = this.graphqlEndpoint;

    const variables = {
      from: `${dto.fromLat},${dto.fromLon}`,
      to: `${dto.toLat},${dto.toLon}`,
    };

    try {
      const response = await firstValueFrom(
        this.http.post<OtpPlanResponse>(
          endpoint,
          {
            query: PLAN_QUERY,
            variables,
          },
          {
            headers: { 'Content-Type': 'application/json' },
          },
        ),
      );

      if (response.data.errors && response.data.errors.length > 0) {
        this.logger.error(
          response.data.errors.map((e) => e.message).join('; '),
        );
        throw new BadGatewayException('OTP returned an error');
      }

      return response.data.data?.plan?.itineraries ?? [];
    } catch (error) {
      this.logger.error('Failed to fetch itinerary from OTP', error as any);
      throw new BadGatewayException('Failed to fetch itinerary from OTP');
    }
  }
}
```

---

## 6. Serviço de Negócio (`RoutesService`)

O `RoutesService` é responsável por:

- Chamar o `OtpService.plan`.
- Enriquecer itinerários com métricas adicionais.
- Aplicar filtros (`RouteFilterMode`).
- Guardar viagens no `RouteHistory` quando necessário.

### 6.1. Estrutura básica

```ts
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { OtpService } from './otp.service';
import {
  PlanItineraryDto,
  EnrichedItinerary,
  PlanResponseDto,
  RouteFilterMode,
} from './dto';
import { TransportMode, RouteStatus } from '@prisma/client';

@Injectable()
export class RoutesService {
  constructor(
    private readonly otp: OtpService,
    private readonly prisma: PrismaService,
  ) {}
}
```

### 6.2. Enriquecimento de itinerários

```ts
private enrichItinerary(iti: OtpItinerary): EnrichedItinerary {
  const modesSet = new Set<string>();
  let totalDistance = 0;
  let totalWalk = 0;

  for (const leg of iti.legs) {
    modesSet.add(leg.mode);
    totalDistance += leg.distance;

    if (leg.mode === 'WALK' || leg.mode === 'FOOT') {
      totalWalk += leg.distance;
    }
  }

  const modes = Array.from(modesSet);
  const primaryMode = modes.find((m) => m !== 'WALK') || 'WALK';

  return {
    ...iti,
    modes,
    primaryMode,
    totalDistanceMeters: Math.round(totalDistance),
    totalWalkDistanceMeters: Math.round(totalWalk),
    hasBus: modes.includes('BUS'),
    hasRail: modes.includes('RAIL'),
    hasCar: modes.includes('CAR'),
    hasBicycle: modes.includes('BICYCLE') || modes.includes('BIKE'),
  };
}
```

### 6.3. Aplicação de filtros

```ts
private filterItinerary(
  iti: EnrichedItinerary,
  filterMode: RouteFilterMode,
): boolean {
  switch (filterMode) {
    case RouteFilterMode.RAIL_ONLY:
      return iti.hasRail;
    case RouteFilterMode.BUS_ONLY:
      return iti.hasBus;
    case RouteFilterMode.NO_RAIL:
      return !iti.hasRail;
    case RouteFilterMode.ALL:
    default:
      return true;
  }
}
```

### 6.4. Planeamento + filtragem

```ts
async planAndFilter(dto: PlanItineraryDto): Promise<PlanResponseDto> {
  const rawItis = await this.otp.plan(dto);
  const enriched = rawItis.map((i) => this.enrichItinerary(i));

  const mode = dto.filterMode || RouteFilterMode.ALL;
  const filtered = enriched.filter((iti) => this.filterItinerary(iti, mode));

  return {
    originalItineraryCount: enriched.length,
    filteredItineraryCount: filtered.length,
    filterApplied: {
      filterMode: mode,
    },
    itineraries: filtered,
  };
}
```

### 6.5. Guardar uma viagem no histórico

Assumindo que o frontend envia:

- O DTO de planeamento original (ou pelo menos as coordenadas).
- O índice da rota escolhida.

```ts
export class SaveRouteFromPlanDto {
  plan: PlanItineraryDto;
  selectedIndex: number;
  planResult: PlanResponseDto;
}
```

```ts
async saveToHistory(
  userId: string,
  dto: SaveRouteFromPlanDto,
) {
  const iti = dto.planResult.itineraries[dto.selectedIndex];
  if (!iti) {
    throw new Error('Selected itinerary index is invalid');
  }

  const firstLeg = iti.legs[0];
  const lastLeg = iti.legs[iti.legs.length - 1];

  const startedAt = new Date(iti.startTime);
  const finishedAt = new Date(iti.endTime);

  // Modo principal traduzido para TransportMode (schema Prisma)
  const primaryMode: TransportMode =
    iti.hasRail
      ? TransportMode.TRAIN
      : iti.hasBus
      ? TransportMode.BUS
      : TransportMode.WALKING;

  const co2Kg = await this.computeCo2ForItinerary(iti, primaryMode);

  const created = await this.prisma.routeHistory.create({
    data: {
      userId,
      originName: firstLeg.from.name || 'Origin',
      originLatitude: firstLeg.from.lat,
      originLongitude: firstLeg.from.lon,
      destinationName: lastLeg.to.name || 'Destination',
      destinationLatitude: lastLeg.to.lat,
      destinationLongitude: lastLeg.to.lon,
      primaryMode,
      modes: [primaryMode],
      distanceMeters: iti.totalDistanceMeters,
      durationSeconds: Math.round(iti.duration),
      co2Kg,
      status: RouteStatus.COMPLETED,
      startedAt,
      finishedAt,
      polyline: iti.legs[0]?.legGeometry?.points ?? null,
      segments: iti.legs as any,
      metadata: iti as any,
    },
  });

  return created;
}
```

### 6.6. Cálculo de CO2 (simplificado)

```ts
private async computeCo2ForItinerary(
  iti: EnrichedItinerary,
  primaryMode: TransportMode,
): Promise<number> {
  const factor = await this.prisma.emissionFactor.findUnique({
    where: { mode: primaryMode },
  });

  if (!factor) {
    return 0;
  }

  const distanceKm = iti.totalDistanceMeters / 1000;
  return factor.kgCo2PerKm * distanceKm;
}
```

---

## 7. Controlador (`RoutesController`)

O controlador expõe os endpoints HTTP.  
Caminho base: **`/routes`**.

```ts
import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { RoutesService } from './routes.service';
import { PlanItineraryDto, SaveRouteFromPlanDto } from './dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { JwtPayload } from '../auth/types/jwt-payload.type';

@Controller('routes')
export class RoutesController {
  constructor(private readonly routesService: RoutesService) {}

  @UseGuards(JwtAuthGuard)
  @Post('plan')
  planTrip(
    @Body() dto: PlanItineraryDto,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.routesService.planAndFilter(dto);
  }

  @UseGuards(JwtAuthGuard)
  @Post('history')
  saveToHistory(
    @Body() dto: SaveRouteFromPlanDto,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.routesService.saveToHistory(user.sub, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Get('history')
  listHistory(@CurrentUser() user: JwtPayload) {
    return this.routesService.listHistory(user.sub);
  }

  @UseGuards(JwtAuthGuard)
  @Get('history/:id')
  getHistoryById(
    @Param('id') id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.routesService.getHistoryById(user.sub, id);
  }
}
```

### 7.1. Listar histórico de viagens

```ts
async listHistory(userId: string) {
  return this.prisma.routeHistory.findMany({
    where: { userId },
    orderBy: { startedAt: 'desc' },
    take: 50,
  });
}

async getHistoryById(userId: string, id: string) {
  return this.prisma.routeHistory.findFirstOrThrow({
    where: { id, userId },
  });
}
```

---

## 8. Endpoints e Exemplos de Teste (Postman)

### 8.1. Obter token JWT (Auth)

Antes de testar `/routes`, é necessário:

1. **Registar** ou **fazer login** no módulo `auth` para obter um `access_token`.
2. Usar esse token no header `Authorization: Bearer <token>` nos pedidos para `/routes`.

#### 8.1.1. Registo

- **Método:** `POST`
- **URL:** `http://localhost:3000/auth/register`
- **Body (JSON):**

```json
{
  "email": "test@example.com",
  "username": "testuser",
  "password": "Test1234!",
  "firstName": "Test",
  "lastName": "User"
}
```

- **Resposta:**

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR..."
}
```

#### 8.1.2. Login

- **Método:** `POST`
- **URL:** `http://localhost:3000/auth/login`
- **Body:**

```json
{
  "identifier": "testuser",
  "password": "Test1234!"
}
```

- **Resposta:**

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR..."
}
```

Guarda este `access_token` para usar nos testes seguintes.

---

### 8.2. Planeamento de rota (`POST /routes/plan`)

- **Método:** `POST`
- **URL:** `http://localhost:3000/routes/plan`
- **Headers:**
  - `Authorization: Bearer <teu_token>`
  - `Content-Type: application/json`

- **Body (exemplo – viagem Porto → Azambuja, filtro por comboio):**

```json
{
  "fromLat": 41.15080714528068,
  "fromLon": -8.609899043995682,
  "toLat": 39.05423834341491,
  "toLon": -8.866055810206802,
  "transitModes": ["RAIL"],
  "filterMode": "RAIL_ONLY"
}
```

- **Resposta (exemplo real simplificado):**

```json
{
  "originalItineraryCount": 5,
  "filteredItineraryCount": 5,
  "filterApplied": {
    "filterMode": "RAIL_ONLY"
  },
  "itineraries": [
    {
      "duration": 16338,
      "walkDistance": 3574.93,
      "startTime": 1764181142000,
      "endTime": 1764197480000,
      "legs": [
        {
          "mode": "WALK",
          "distance": 726.25,
          "duration": 658,
          "startTime": 1764181142000,
          "endTime": 1764181800000,
          "from": { "name": "Origin", "lat": 41.1508071, "lon": -8.609899 },
          "to": { "name": "Porto Sao Bento", "lat": 41.1455668, "lon": -8.6102211 },
          "route": null,
          "legGeometry": { "points": "..." }
        },
        {
          "mode": "RAIL",
          "distance": 2154.32,
          "duration": 240,
          "startTime": 1764181800000,
          "endTime": 1764182040000,
          "from": { "name": "Porto Sao Bento", "lat": 41.1455668, "lon": -8.6102211 },
          "to": { "name": "Porto Campanha", "lat": 41.1487193, "lon": -8.5848353 },
          "route": { "shortName": "Linha do Marco", "longName": null },
          "legGeometry": { "points": "..." }
        }
        // ...
      ],
      "modes": ["WALK", "RAIL"],
      "primaryMode": "RAIL",
      "totalDistanceMeters": 324848,
      "totalWalkDistanceMeters": 3575,
      "hasBus": false,
      "hasRail": true,
      "hasCar": false,
      "hasBicycle": false
    }
  ]
}
```

---

### 8.3. Guardar uma viagem no histórico (`POST /routes/history`)

Depois de o utilizador escolher um itinerário no frontend:

- **Método:** `POST`
- **URL:** `http://localhost:3000/routes/history`
- **Headers:**
  - `Authorization: Bearer <teu_token>`
  - `Content-Type: application/json`

- **Body (exemplo):**

```json
{
  "plan": {
    "fromLat": 41.15080714528068,
    "fromLon": -8.609899043995682,
    "toLat": 39.05423834341491,
    "toLon": -8.866055810206802,
    "transitModes": ["RAIL"],
    "filterMode": "RAIL_ONLY"
  },
  "selectedIndex": 0,
  "planResult": {
    "originalItineraryCount": 5,
    "filteredItineraryCount": 5,
    "filterApplied": {
      "filterMode": "RAIL_ONLY"
    },
    "itineraries": [
      { /* aqui vens copiar o itinerário 0 devolvido em /routes/plan */ }
    ]
  }
}
```

> Na prática, o frontend pode guardar a resposta de `/routes/plan` e enviar apenas o itinerário seleccionado. Esta estrutura é apenas um exemplo completo.

- **Resposta (exemplo):**

```json
{
  "id": "clxyz...",
  "userId": "cmigeoguk0000qtzskw9sh41n",
  "originName": "Origin",
  "originLatitude": 41.1508071,
  "originLongitude": -8.609899,
  "destinationName": "Destination",
  "destinationLatitude": 39.0542383,
  "destinationLongitude": -8.8660558,
  "primaryMode": "TRAIN",
  "modes": ["TRAIN"],
  "distanceMeters": 324848,
  "durationSeconds": 16338,
  "co2Kg": 12.34,
  "status": "COMPLETED",
  "startedAt": "2025-11-26T18:19:02.000Z",
  "finishedAt": "2025-11-26T22:51:20.000Z",
  "createdAt": "2025-11-26T18:00:00.000Z",
  "updatedAt": "2025-11-26T18:00:00.000Z"
}
```

---

### 8.4. Listar histórico (`GET /routes/history`)

- **Método:** `GET`
- **URL:** `http://localhost:3000/routes/history`
- **Headers:**
  - `Authorization: Bearer <teu_token>`

- **Resposta (exemplo):**

```json
[
  {
    "id": "clxyz...",
    "originName": "Origin",
    "destinationName": "Destination",
    "primaryMode": "TRAIN",
    "distanceMeters": 324848,
    "durationSeconds": 16338,
    "co2Kg": 12.34,
    "startedAt": "2025-11-26T18:19:02.000Z",
    "finishedAt": "2025-11-26T22:51:20.000Z"
  }
]
```

---

### 8.5. Detalhe de uma viagem (`GET /routes/history/:id`)

- **Método:** `GET`
- **URL:** `http://localhost:3000/routes/history/clxyz...`
- **Headers:**
  - `Authorization: Bearer <teu_token>`

- **Resposta (exemplo):**

```json
{
  "id": "clxyz...",
  "originName": "Origin",
  "destinationName": "Destination",
  "originLatitude": 41.1508071,
  "originLongitude": -8.609899,
  "destinationLatitude": 39.0542383,
  "destinationLongitude": -8.8660558,
  "primaryMode": "TRAIN",
  "modes": ["TRAIN"],
  "distanceMeters": 324848,
  "durationSeconds": 16338,
  "co2Kg": 12.34,
  "co2SavedVsCarKg": 25.0,
  "status": "COMPLETED",
  "startedAt": "2025-11-26T18:19:02.000Z",
  "finishedAt": "2025-11-26T22:51:20.000Z",
  "polyline": "ogdzF|rps@...",
  "segments": [ /* legs OTP */ ],
  "metadata": { /* itinerário completo OTP */ },
  "createdAt": "2025-11-26T18:00:00.000Z",
  "updatedAt": "2025-11-26T18:05:00.000Z"
}
```

---

## 9. Autenticação

Ao contrário do módulo **CP**, o módulo **Routes** trabalha directamente com dados do utilizador e com o seu histórico, por isso:

- Todos os endpoints principais (`/routes/plan`, `/routes/history`, etc.) devem estar protegidos com `JwtAuthGuard`.
- O JWT é emitido pelo módulo `auth` (já existente) e contém:
  - `sub` (id do utilizador),
  - `email`,
  - `username`.

O decorator `@CurrentUser()` injeta esse payload nos métodos do controller para ser usado pelo `RoutesService`.

---

## 10. Resumo e Próximos Passos

O módulo **Routes** fornece:

- Uma camada limpa para falar com o OTP v2 via GraphQL.
- Itinerários enriquecidos prontos a consumir pela app.
- Filtragem por modos de transporte (RAIL_ONLY, BUS_ONLY, etc.).
- Integração directa com o histórico de viagens, permitindo:
  - Análises posteriores,
  - Geração de estatísticas ecológicas,
  - Recomendação de rotas frequentes.

Próximos passos naturais:

1. Integrar preferências do utilizador (`UserPreferences`) no planeamento:
   - Excluir modos indesejados,
   - Respeitar distância máxima a pé, etc.
2. Ligar o histórico de viagens com o módulo **Eco**:
   - Calcular CO2 acumulado por período (dia, semana, mês),
   - Gamificar o uso de transportes mais sustentáveis.
3. Adicionar testes automatizados (e2e) para garantir que:
   - `/routes/plan` funciona correctamente contra o OTP.
   - `/routes/history` grava de forma consistente e segura.

Este documento serve como base de referência para equipas backend e frontend ao trabalharem com o planeamento e histórico de viagens na aplicação.
