# Documentação do Módulo GBFS (Bike/Scooter-Share)

Este documento descreve, de forma detalhada e profissional, a implementação do módulo **GBFS** no backend (NestJS), incluindo:

* Contexto e objectivos do módulo
* Dependências e configuração
* Modelos de base de dados relevantes
* Script de seed para sistemas GBFS em Portugal
* Estrutura de DTOs
* Serviço (`GbfsService`)
* Controlador (`GbfsController`)
* Listagem de endpoints
* Exemplos de testes com Postman / Insomnia

Este documento segue a mesma estrutura e nível de detalhe do módulo CP já documentado no projecto.

> Nota: Toda a terminologia e exemplos são pensados para Português de Portugal.

---

## 1. Contexto e Objectivos

O **GBFS (General Bikeshare Feed Specification)** é o standard aberto usado por operadores de **bike-share** e **scooter-share** para expor:

* Localização de estações e/ou veículos soltos;
* Estado em tempo real (bikes disponíveis, docks livres, etc.);
* Tipos de veículos (bike normal, e-bike, trotinete, etc.);
* Planos de preços;
* Zonas de geofencing (onde se pode circular ou estacionar).

O módulo **GBFS** foi criado com três objectivos principais:

1. **Catalogar sistemas GBFS em Portugal**

   * Ler o ficheiro `systems_PT.csv` (fonte externa)
   * Popular a tabela `GbfsSystem` com os sistemas disponíveis (Bird, Nextbike, etc.)

2. **Uniformizar o acesso aos feeds GBFS**

   * Dado um `systemId` (ex.: `bird-braga`, `nextbike_bx`), obter o ficheiro `gbfs.json` (auto-discovery)
   * Descobrir feeds como `station_information`, `station_status`, `free_bike_status`, `geofencing_zones`, etc.
   * Expor endpoints REST simples para cada tipo de feed, abstraindo diferenças entre operadores

3. **Fornecer dados prontos para a aplicação**

   * Endpoint consolidado de **estações com disponibilidade actual** (`station_information` + `station_status`)
   * Endpoint para **veículos soltos** (`free_bike_status`)
   * Endpoints para metadados (`system_information`, `gbfs_versions`), tipos de veículos, planos de preços, regiões e geofencing.

---

## 2. Dependências e Configuração

### 2.1. Estrutura do módulo

O módulo encontra-se em `src/gbfs` e contém:

* `gbfs.module.ts`
* `gbfs.service.ts`
* `gbfs.controller.ts`
* `dto/` (subpasta com DTOs)

```ts
// src/gbfs/gbfs.module.ts
import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { GbfsService } from './gbfs.service';
import { GbfsController } from './gbfs.controller';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [HttpModule, PrismaModule],
  providers: [GbfsService],
  controllers: [GbfsController],
  exports: [GbfsService],
})
export class GbfsModule {}
```

No `AppModule`, o módulo é simplesmente importado:

```ts
// src/app.module.ts
import { Module } from '@nestjs/common';
import { PrismaModule } from './prisma/prisma.module';
import { GbfsModule } from './gbfs/gbfs.module';
// ...

@Module({
  imports: [
    PrismaModule,
    GbfsModule,
    // outros módulos...
  ],
})
export class AppModule {}
```

### 2.2. Variáveis de ambiente

O módulo GBFS não depende de variáveis de ambiente específicas para URLs externas, pois os endpoints de auto-discovery (`gbfs.json`) vêm directamente do CSV e são guardados na base de dados (`GbfsSystem.autoDiscoveryUrl`).

---

## 3. Modelos de Base de Dados (Prisma)

Os modelos relevantes encontram-se no `schema.prisma`.

### 3.1. Sistemas GBFS (`GbfsSystem`)

```prisma
model GbfsSystem {
  id                    Int      @id @default(autoincrement())
  countryCode           String
  name                  String
  location              String?
  systemId              String   @unique
  url                   String?
  autoDiscoveryUrl      String?
  supportedVersions     String?
  authenticationInfoUrl String?

  stations              Station[]

  @@map("gbfs_systems")
}
```

* `countryCode` – código do país (ex.: `"PT"`).
* `name` – nome do sistema (ex.: `"Bird Braga"`).
* `location` – cidade/região (ex.: `"Braga"`).
* `systemId` – identificador textual (ex.: `"bird-braga"`, `"nextbike_bx"`).
* `autoDiscoveryUrl` – URL do ficheiro `gbfs.json` (auto-discovery).
* Relação 1-N com `Station`, pensada para futura sincronização de estações.

### 3.2. Estações (`Station`) – integração futura

O modelo `Station` foi preparado para integrar dados provenientes de GBFS:

```prisma
model Station {
  id          String      @id @default(cuid())
  name        String
  description String?

  latitude    Float
  longitude   Float
  address     String?
  city        String?
  country     String?

  externalId  String?
  stationType StationType
  isActive    Boolean     @default(true)

  capacity          Int?
  availableVehicles Int?
  availableDocks    Int?

  energySource    String?
  carbonFootprint Float?

  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  gbfsSystemId Int?
  gbfsSystem   GbfsSystem? @relation(fields: [gbfsSystemId], references: [id])

  // outras relações (rotas, veículos, etc.)

  @@unique([gbfsSystemId, externalId])
  @@map("stations")
}
```

* `externalId` – para GBFS, será o `station_id`.
* `gbfsSystemId` – indica a qual sistema GBFS pertence a estação.
* `stationType` – para bike/scooter-share será tipicamente `BIKE_STATION` ou `SCOOTER_STATION`.

> Nesta fase o módulo **não grava ainda** estações na tabela `Station`; isso fica para uma fase de sincronização futura.

---

## 4. Seed dos Sistemas GBFS (CSV → BD)

### 4.1. Ficheiro `systems_PT.csv`

O ficheiro com os sistemas GBFS em Portugal é obtido de uma fonte externa e guardado no projecto em:

```text
PDM/EXTERNALS/data/gbfs/systems_PT.csv
```

Exemplo de conteúdo:

```csv
Country Code,Name,Location,System ID,URL,Auto-Discovery URL,Supported Versions,Authentication Info URL,Authentication Type,Authentication Parameter Name
PT,Bird Braga,Braga,bird-braga,https://www.bird.co,https://mds.bird.co/gbfs/v2/public/braga/gbfs.json,1.1 ; 2.3,,,
PT,Bird Cascais,Cascais,bird-cascais,https://www.bird.co,https://mds.bird.co/gbfs/v2/public/cascais/gbfs.json,1.1 ; 2.3,,,
PT,Bird Lisbon,Lisbon,bikr-lisbon,https://www.bird.co,https://mds.bird.co/gbfs/v2/public/lisbon/gbfs.json,1.1 ; 2.3,,,
PT,Bird Porto,Porto,bird-porto,https://www.bird.co,https://mds.bird.co/gbfs/v2/public/porto/gbfs.json,1.1 ; 2.3,,,
PT,TubaBike (Barcelos),Barcelos,nextbike_bx,https://www.tubabike.pt/,https://gbfs.nextbike.net/maps/gbfs/v2/nextbike_bx/gbfs.json,2.3,,,
```

### 4.2. Script de seed (`prisma/seed-gbfs.ts`)

Responsável por:

* Ler o CSV;
* Limpar a tabela `gbfs_systems`;
* Inserir os sistemas GBFS em base de dados.

```ts
// prisma/seed-gbfs.ts
import { PrismaClient } from '@prisma/client';
import { parse } from 'csv-parse/sync';
import * as fs from 'fs';
import * as path from 'path';

const prisma = new PrismaClient();

async function main() {
  const csvPath = path.join(
    __dirname,
    '..',
    '..',
    'EXTERNALS',
    'data',
    'gbfs',
    'systems_PT.csv',
  );

  if (!fs.existsSync(csvPath)) {
    throw new Error(`CSV não encontrado em: ${csvPath}`);
  }

  const csvText = fs.readFileSync(csvPath, 'utf8');

  const records = parse(csvText, {
    columns: true,
    skip_empty_lines: true,
    trim: true,
  }) as Record<string, string>[];

  console.log(`📄 Registos lidos do CSV: ${records.length}`);

  // Opcional: limpar a tabela antes de inserir
  await prisma.gbfsSystem.deleteMany();

  await prisma.gbfsSystem.createMany({
    data: records.map((r) => ({
      countryCode: r['Country Code'],
      name: r['Name'],
      location: r['Location'] || null,
      systemId: r['System ID'],
      url: r['URL'] || null,
      autoDiscoveryUrl: r['Auto-Discovery URL'] || null,
      supportedVersions: r['Supported Versions'] || null,
      authenticationInfoUrl: r['Authentication Info URL'] || null,
    })),
    skipDuplicates: true,
  });

  console.log('✅ GBFS systems inseridos na base de dados.');
}

main()
  .catch((e) => {
    console.error('❌ Erro no seed GBFS:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
```

### 4.3. Como correr o seed

Na raiz do backend:

```bash
cd backend
npx ts-node prisma/seed-gbfs.ts
# ou, se estiver configurado no package.json:
# npx prisma db seed
```

Depois de correr o seed, a tabela `gbfs_systems` deverá conter uma linha por sistema definido no CSV.

---

## 5. DTOs (Data Transfer Objects)

Todos os DTOs do módulo GBFS se encontram em `src/gbfs/dto`.

### 5.1. DTO de sistema (`GbfsSystemDto`)

```ts
// src/gbfs/dto/gbfs-system.dto.ts
export class GbfsSystemDto {
  id: number;
  countryCode: string;
  name: string;
  location?: string | null;
  systemId: string;
  url?: string | null;
  autoDiscoveryUrl?: string | null;
  supportedVersions?: string | null;
  authenticationInfoUrl?: string | null;
}
```

Usado para expor os sistemas GBFS guardados em base de dados.

---

### 5.2. DTO de index/feeds (`GbfsIndexDto`)

Representa o ficheiro `gbfs.json` (auto-discovery) de um sistema.

```ts
// src/gbfs/dto/gbfs-index.dto.ts
export interface GbfsFeedMeta {
  name: string;
  url: string;
}

export interface GbfsIndexLanguageBlock {
  feeds: GbfsFeedMeta[];
}

export interface GbfsIndexDto {
  last_updated: number;
  ttl: number;
  data: Record<string, GbfsIndexLanguageBlock>; // ex.: "pt", "en"
  version: string;
}
```

* `data` – contém um objecto por idioma (`pt`, `en`, etc.), cada um com a lista de `feeds`.
* Cada feed tem `name` (ex.: `station_information`) e `url` (link para o JSON desse feed).

---

### 5.3. Query de feed genérico (`GetGbfsFeedQueryDto`)

```ts
// src/gbfs/dto/get-gbfs-feed.dto.ts
import { IsOptional, IsString } from 'class-validator';

export class GetGbfsFeedQueryDto {
  @IsString()
  name: string;        // ex.: "station_information"

  @IsOptional()
  @IsString()
  lang?: string;       // ex.: "pt", "en"
}
```

Usado em `/gbfs/:systemId/feed?name=...&lang=...`.

---

### 5.4. Barrel de DTOs (opcional)

```ts
// src/gbfs/dto/index.ts
export * from './gbfs-system.dto';
export * from './gbfs-index.dto';
export * from './get-gbfs-feed.dto';
```

---

## 6. Serviço (`GbfsService`)

O `GbfsService` é responsável por:

1. Ler os sistemas GBFS da base de dados (`GbfsSystem`).
2. Buscar o ficheiro `gbfs.json` (auto-discovery) de um sistema.
3. Determinar o idioma a usar (`pt`, `en`, etc.).
4. Obter a lista de feeds (`feeds`) e resolver URLs de feeds específicos.
5. Expor métodos convenientes para feeds comuns (`station_information`, `station_status`, `free_bike_status`, etc.).
6. Combinar `station_information` + `station_status` num payload único com estações e disponibilidade.

### 6.1. Estrutura base

```ts
// src/gbfs/gbfs.service.ts
import {
  BadRequestException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { lastValueFrom } from 'rxjs';
import { PrismaService } from '../prisma/prisma.service';
import { GbfsIndexDto, GbfsFeedMeta } from './dto/gbfs-index.dto';
import { GbfsSystemDto } from './dto/gbfs-system.dto';

@Injectable()
export class GbfsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly http: HttpService,
  ) {}
```

---

### 6.2. Sistemas (BD)

```ts
async findAllSystems(): Promise<GbfsSystemDto[]> {
  return this.prisma.gbfsSystem.findMany({
    orderBy: { name: 'asc' },
  });
}

async findSystemBySystemId(systemId: string): Promise<GbfsSystemDto> {
  const system = await this.prisma.gbfsSystem.findUnique({
    where: { systemId },
  });

  if (!system) {
    throw new NotFoundException(
      `GBFS system with systemId "${systemId}" not found`,
    );
  }

  return system;
}
```

---

### 6.3. Leitura do `gbfs.json` (auto-discovery)

```ts
async getGbfsIndex(systemId: string): Promise<GbfsIndexDto> {
  const system = await this.findSystemBySystemId(systemId);

  if (!system.autoDiscoveryUrl) {
    throw new BadRequestException(
      `System "${systemId}" does not have an autoDiscoveryUrl`,
    );
  }

  try {
    const response$ = this.http.get<GbfsIndexDto>(system.autoDiscoveryUrl);
    const response = await lastValueFrom(response$);
    return response.data;
  } catch (error) {
    throw new ServiceUnavailableException(
      `Failed to fetch gbfs index for system "${systemId}"`,
    );
  }
}
```

---

### 6.4. Escolha de idioma preferido

```ts
private pickLanguage(
  data: GbfsIndexDto['data'],
  preferredLang?: string,
): string {
  const langs = Object.keys(data ?? {});
  if (!langs.length) {
    throw new NotFoundException('No languages available in GBFS index');
  }

  // 1. Idioma solicitado, se existir
  if (preferredLang && langs.includes(preferredLang)) return preferredLang;

  // 2. Português, se existir
  if (langs.includes('pt')) return 'pt';

  // 3. Inglês, se existir
  if (langs.includes('en')) return 'en';

  // 4. Caso contrário, o primeiro que aparecer
  return langs[0];
}
```

---

### 6.5. Listar feeds disponíveis

```ts
async listFeeds(systemId: string, lang?: string): Promise<GbfsFeedMeta[]> {
  const index = await this.getGbfsIndex(systemId);
  const chosenLang = this.pickLanguage(index.data, lang);

  const feeds = index.data[chosenLang]?.feeds ?? [];
  return feeds;
}
```

---

### 6.6. Obter um feed concreto (genérico)

```ts
async getFeed(systemId: string, feedName: string, lang?: string): Promise<any> {
  const index = await this.getGbfsIndex(systemId);
  const chosenLang = this.pickLanguage(index.data, lang);
  const feeds = index.data[chosenLang]?.feeds ?? [];

  const feed = feeds.find((f) => f.name === feedName);

  if (!feed) {
    throw new NotFoundException(
      `Feed "${feedName}" not found for system "${systemId}" (lang: "${chosenLang}")`,
    );
  }

  try {
    const resp$ = this.http.get(feed.url);
    const resp = await lastValueFrom(resp$);
    return resp.data;
  } catch (error) {
    throw new ServiceUnavailableException(
      `Failed to fetch feed "${feedName}" for system "${systemId}"`,
    );
  }
}
```

---

### 6.7. Métodos específicos por feed

Wrappers convenientes que usam `getFeed` por baixo:

```ts
// Metadados
async getSystemInformation(systemId: string, lang?: string) {
  return this.getFeed(systemId, 'system_information', lang);
}

async getGbfsVersions(systemId: string, lang?: string) {
  return this.getFeed(systemId, 'gbfs_versions', lang);
}

// Estações e veículos
async getStationInformation(systemId: string, lang?: string) {
  return this.getFeed(systemId, 'station_information', lang);
}

async getStationStatus(systemId: string, lang?: string) {
  return this.getFeed(systemId, 'station_status', lang);
}

async getFreeBikeStatus(systemId: string, lang?: string) {
  return this.getFeed(systemId, 'free_bike_status', lang);
}

// Tipos, preços, regiões, geofencing
async getVehicleTypes(systemId: string, lang?: string) {
  return this.getFeed(systemId, 'vehicle_types', lang);
}

async getPricingPlans(systemId: string, lang?: string) {
  return this.getFeed(systemId, 'system_pricing_plans', lang);
}

async getRegions(systemId: string, lang?: string) {
  return this.getFeed(systemId, 'system_regions', lang);
}

async getGeofencingZones(systemId: string, lang?: string) {
  return this.getFeed(systemId, 'geofencing_zones', lang);
}
```

---

### 6.8. Estações com disponibilidade (info + status)

Endpoint de **alto nível** para o frontend: devolve as estações já com a informação de disponibilidade (`num_bikes_available`, `num_docks_available`, etc.) num único payload.

```ts
async getStationsWithStatus(systemId: string, lang?: string) {
  const [info, status] = await Promise.all([
    this.getStationInformation(systemId, lang),
    this.getStationStatus(systemId, lang),
  ]);

  const infoStations = info?.data?.stations ?? [];
  const statusStations = status?.data?.stations ?? [];

  const statusById = new Map(
    statusStations.map((s: any) => [s.station_id, s]),
  );

  const merged = infoStations.map((s: any) => {
    const st = statusById.get(s.station_id) ?? {};
    return {
      ...s,
      ...(st as any),
    };
  });

  return {
    last_updated: Math.max(info.last_updated ?? 0, status.last_updated ?? 0),
    ttl: Math.min(info.ttl ?? 60, status.ttl ?? 60),
    system_id: systemId,
    data: {
      stations: merged,
    },
  };
}
```

---

## 7. Controlador (`GbfsController`)

O controlador expõe os endpoints HTTP.
Caminho base: **`/gbfs`**.

```ts
// src/gbfs/gbfs.controller.ts
import { Controller, Get, Param, Query } from '@nestjs/common';
import { GbfsService } from './gbfs.service';
import { GbfsSystemDto } from './dto/gbfs-system.dto';
import { GetGbfsFeedQueryDto } from './dto/get-gbfs-feed.dto';
import { GbfsFeedMeta } from './dto/gbfs-index.dto';

@Controller('gbfs')
export class GbfsController {
  constructor(private readonly gbfsService: GbfsService) {}
```

### 7.1. Sistemas (BD)

```ts
  // GET /gbfs/systems
  @Get('systems')
  async listSystems(): Promise<GbfsSystemDto[]> {
    return this.gbfsService.findAllSystems();
  }

  // GET /gbfs/systems/:systemId
  @Get('systems/:systemId')
  async getSystem(
    @Param('systemId') systemId: string,
  ): Promise<GbfsSystemDto> {
    return this.gbfsService.findSystemBySystemId(systemId);
  }
```

---

### 7.2. Index e feeds (genérico)

```ts
  // GET /gbfs/:systemId/index
  @Get(':systemId/index')
  async getIndex(@Param('systemId') systemId: string) {
    return this.gbfsService.getGbfsIndex(systemId);
  }

  // GET /gbfs/:systemId/feeds?lang=pt
  @Get(':systemId/feeds')
  async listFeeds(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ): Promise<GbfsFeedMeta[]> {
    return this.gbfsService.listFeeds(systemId, lang);
  }

  // GET /gbfs/:systemId/feed?name=station_information&lang=pt
  @Get(':systemId/feed')
  async getFeed(
    @Param('systemId') systemId: string,
    @Query() query: GetGbfsFeedQueryDto,
  ) {
    return this.gbfsService.getFeed(systemId, query.name, query.lang);
  }
```

---

### 7.3. Endpoints específicos por feed

```ts
  // SYSTEM INFORMATION
  // GET /gbfs/:systemId/system?lang=pt
  @Get(':systemId/system')
  async getSystemInfo(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getSystemInformation(systemId, lang);
  }

  // STATION INFORMATION
  // GET /gbfs/:systemId/stations/info?lang=pt
  @Get(':systemId/stations/info')
  async getStationInfo(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getStationInformation(systemId, lang);
  }

  // STATION STATUS
  // GET /gbfs/:systemId/stations/status?lang=pt
  @Get(':systemId/stations/status')
  async getStationStatus(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getStationStatus(systemId, lang);
  }

  // ESTAÇÕES + STATUS (principal para o frontend)
  // GET /gbfs/:systemId/stations?lang=pt
  @Get(':systemId/stations')
  async getStations(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getStationsWithStatus(systemId, lang);
  }

  // FREE BIKE STATUS
  // GET /gbfs/:systemId/free-bikes?lang=pt
  @Get(':systemId/free-bikes')
  async getFreeBikes(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getFreeBikeStatus(systemId, lang);
  }

  // VEHICLE TYPES
  // GET /gbfs/:systemId/vehicle-types?lang=pt
  @Get(':systemId/vehicle-types')
  async getVehicleTypes(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getVehicleTypes(systemId, lang);
  }

  // PRICING PLANS
  // GET /gbfs/:systemId/pricing-plans?lang=pt
  @Get(':systemId/pricing-plans')
  async getPricingPlans(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getPricingPlans(systemId, lang);
  }

  // REGIONS
  // GET /gbfs/:systemId/regions?lang=pt
  @Get(':systemId/regions')
  async getRegions(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getRegions(systemId, lang);
  }

  // GEOFENCING ZONES
  // GET /gbfs/:systemId/geofencing-zones?lang=pt
  @Get(':systemId/geofencing-zones')
  async getGeofencingZones(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getGeofencingZones(systemId, lang);
  }

  // GBFS VERSIONS
  // GET /gbfs/:systemId/versions?lang=pt
  @Get(':systemId/versions')
  async getGbfsVersions(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getGbfsVersions(systemId, lang);
  }
}
```

---

## 8. Testes básicos com Postman / Insomnia

### 8.1. Pré-requisitos

* Backend NestJS a correr em `http://localhost:3000`.
* Base de dados com `gbfs_systems` populada via `prisma/seed-gbfs.ts`.
* Ligação HTTP para os endpoints GBFS externos (Bird, Nextbike, etc.).

---

### 8.2. Verificar sistemas GBFS em BD

**Request**

* Método: `GET`
* URL: `http://localhost:3000/gbfs/systems`

**Resposta (exemplo)**

```json
[
  {
    "id": 1,
    "countryCode": "PT",
    "name": "Bird Braga",
    "location": "Braga",
    "systemId": "bird-braga",
    "url": "https://www.bird.co",
    "autoDiscoveryUrl": "https://mds.bird.co/gbfs/v2/public/braga/gbfs.json",
    "supportedVersions": "1.1 ; 2.3",
    "authenticationInfoUrl": null
  },
  {
    "id": 2,
    "countryCode": "PT",
    "name": "TubaBike (Barcelos)",
    "location": "Barcelos",
    "systemId": "nextbike_bx",
    "url": "https://www.tubabike.pt/",
    "autoDiscoveryUrl": "https://gbfs.nextbike.net/maps/gbfs/v2/nextbike_bx/gbfs.json",
    "supportedVersions": "2.3",
    "authenticationInfoUrl": null
  }
]
```

---

### 8.3. Obter um sistema específico

**Request**

* `GET http://localhost:3000/gbfs/systems/bird-braga`

**Resposta (exemplo)**

```json
{
  "id": 1,
  "countryCode": "PT",
  "name": "Bird Braga",
  "location": "Braga",
  "systemId": "bird-braga",
  "url": "https://www.bird.co",
  "autoDiscoveryUrl": "https://mds.bird.co/gbfs/v2/public/braga/gbfs.json",
  "supportedVersions": "1.1 ; 2.3",
  "authenticationInfoUrl": null
}
```

---

### 8.4. Testar o `gbfs.json` (auto-discovery)

**Request**

* `GET http://localhost:3000/gbfs/bird-braga/index`

**Resposta (exemplo simplificado)**

```json
{
  "last_updated": 1764204047,
  "ttl": 60,
  "data": {
    "pt": {
      "feeds": [
        { "name": "free_bike_status", "url": "https://mds.bird.co/gbfs/v2/public/braga/free_bike_status.json" },
        { "name": "gbfs_versions", "url": "https://mds.bird.co/gbfs/v2/public/braga/gbfs_versions.json" },
        { "name": "geofencing_zones", "url": "https://mds.bird.co/gbfs/v2/public/braga/geofencing_zones.json" },
        { "name": "station_information", "url": "https://mds.bird.co/gbfs/v2/public/braga/station_information.json" },
        { "name": "station_status", "url": "https://mds.bird.co/gbfs/v2/public/braga/station_status.json" },
        { "name": "system_information", "url": "https://mds.bird.co/gbfs/v2/public/braga/system_information.json" },
        { "name": "system_pricing_plans", "url": "https://mds.bird.co/gbfs/v2/public/braga/system_pricing_plans.json" },
        { "name": "system_regions", "url": "https://mds.bird.co/gbfs/v2/public/braga/system_regions.json" },
        { "name": "vehicle_types", "url": "https://mds.bird.co/gbfs/v2/public/braga/vehicle_types.json" }
      ]
    },
    "en": {
      "feeds": [ /* ... */ ]
    }
  },
  "version": "2.3"
}
```

---

### 8.5. Listar feeds de um sistema

**Request**

* `GET http://localhost:3000/gbfs/bird-braga/feeds?lang=pt`

**Resposta (exemplo)**

```json
[
  {
    "name": "free_bike_status",
    "url": "https://mds.bird.co/gbfs/v2/public/braga/free_bike_status.json"
  },
  {
    "name": "gbfs_versions",
    "url": "https://mds.bird.co/gbfs/v2/public/braga/gbfs_versions.json"
  },
  {
    "name": "geofencing_zones",
    "url": "https://mds.bird.co/gbfs/v2/public/braga/geofencing_zones.json"
  },
  {
    "name": "station_information",
    "url": "https://mds.bird.co/gbfs/v2/public/braga/station_information.json"
  },
  {
    "name": "station_status",
    "url": "https://mds.bird.co/gbfs/v2/public/braga/station_status.json"
  },
  {
    "name": "system_information",
    "url": "https://mds.bird.co/gbfs/v2/public/braga/system_information.json"
  },
  {
    "name": "system_pricing_plans",
    "url": "https://mds.bird.co/gbfs/v2/public/braga/system_pricing_plans.json"
  },
  {
    "name": "system_regions",
    "url": "https://mds.bird.co/gbfs/v2/public/braga/system_regions.json"
  },
  {
    "name": "vehicle_types",
    "url": "https://mds.bird.co/gbfs/v2/public/braga/vehicle_types.json"
  }
]
```

---

### 8.6. Estaçōes com disponibilidade

**Request**

* `GET http://localhost:3000/gbfs/bird-braga/stations?lang=pt`

**Resposta (exemplo simplificado)**

```json
{
  "last_updated": 1764204047,
  "ttl": 60,
  "system_id": "bird-braga",
  "data": {
    "stations": [
      {
        "station_id": "123",
        "name": "Estação Centro",
        "lat": 41.55,
        "lon": -8.42,
        "capacity": 15,
        "num_bikes_available": 7,
        "num_docks_available": 8
      }
    ]
  }
}
```

---

### 8.7. Veículos soltos (free-floating)

**Request**

* `GET http://localhost:3000/gbfs/bird-braga/free-bikes?lang=pt`

**Resposta**

Estrutura GBFS típica, com `data.bikes` contendo `lat`, `lon` e outros campos de cada veículo.

---

### 8.8. Geofencing, tipos, preços e metadados

* `GET /gbfs/bird-braga/geofencing-zones?lang=pt`
* `GET /gbfs/bird-braga/vehicle-types?lang=pt`
* `GET /gbfs/bird-braga/pricing-plans?lang=pt`
* `GET /gbfs/bird-braga/regions?lang=pt`
* `GET /gbfs/bird-braga/system?lang=pt`
* `GET /gbfs/bird-braga/versions?lang=pt`

Estes endpoints devolvem os JSONs tal como definidos pela especificação GBFS, para consumo directo pelo frontend ou outros módulos (Eco, mapas, etc.).

---

## 9. Autenticação

O módulo **GBFS** apenas lê dados públicos:

* Sistemas GBFS (carregados via CSV/seed);
* Feeds públicos expostos pelos operadores (Bird, Nextbike, etc.).

Por isso:

* Os endpoints **não** usam `JwtAuthGuard`;
* São todos **públicos**, adequados para consumo directo por app web/mobile;
* Não gravam dados de utilizador, histórico, nem preferências.

Autenticação será relevante em módulos que cruzem estes dados com:

* Roteamento multimodal (Routes/OTP);
* Histórico do utilizador (RouteHistory);
* Estatísticas ecológicas (Eco).

---

## 10. Extensões futuras

Possíveis evoluções do módulo GBFS:

1. **Sincronizar estações para `Station`**

   * Script que lê `station_information` de cada sistema
   * Faz *upsert* em `Station` com base em `[gbfsSystemId, externalId (station_id)]`

2. **Endpoint de estações próximas do utilizador**

   * `GET /stations/nearby?lat=...&lon=...`
   * Usa `Station` + (opcionalmente) dados de `station_status` para listar estações por distância.

3. **Integração de geofencing com `ServiceArea`**

   * Guardar `geofencing_zones` como GeoJSON em `ServiceArea.polygon`
   * Permitir desenhar zonas na UI (no-park, slow zone, etc.).

4. **Integração com módulo Eco**

   * Usar `vehicle_types` e `system_pricing_plans` para estimar custos e emissões por viagem com bike/scooter-share.

Este documento serve como referência para a equipa backend e frontend ao trabalhar com dados GBFS, garantindo uma camada consistente de integração com os sistemas de bike/scooter-share em Portugal.
