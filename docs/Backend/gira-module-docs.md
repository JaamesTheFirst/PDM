# Documentação do Módulo GIRA (Lisboa Bike-Share)

Este documento descreve, de forma detalhada e profissional, a implementação do módulo **GIRA** no backend (NestJS), incluindo:

* Contexto e objectivos do módulo
* Fluxo de dados entre ficheiro Excel/CSV e base de dados
* Modelo de base de dados (`GiraStation`)
* DTOs usados internamente
* Serviço (`GiraService`)
* Controlador (`GiraController`)
* Endpoints disponíveis e exemplos de teste

A ideia é manter este módulo alinhado com o estilo de documentação dos outros módulos (CP, Routes, GBFS).

> Nota: Terminologia em **Português de Portugal** e focada no sistema de bicicletas partilhadas **GIRA** (Lisboa).

---

## 1. Contexto e Objectivos

O sistema **GIRA** (Lisboa Bike-Share) disponibiliza um ficheiro (normalmente em **Excel/XLSX** ou CSV) com a informação das estações de bicicletas, incluindo:

* Identificador da estação (ID)
* Nome
* Morada / freguesia
* Coordenadas (latitude, longitude)
* Capacidade (número de docks / bikes)

O módulo **GIRA** no backend tem como objectivo:

1. **Ingerir os dados do ficheiro de estações** para a base de dados (tabela `gira_stations`).
2. **Evitar ler o ficheiro a cada pedido HTTP** – os endpoints passam a ler sempre da base de dados.
3. Fornecer **endpoints REST simples** para:

   * Paginar estações (`/gira/stations`).
   * Pesquisar estações por campos específicos (`/gira/stations/search`).
   * Recarregar manualmente os dados a partir do ficheiro (`/gira/stations/reload`).

Este módulo é, portanto, a "fonte interna" de dados do GIRA, sobre a qual outros módulos (ex.: UI, routing, eco, etc.) se podem apoiar.

---

## 2. Dependências e Configuração

### 2.1. Módulo NestJS

O módulo vive em `src/gira` e é composto por:

* `gira.module.ts`
* `gira.service.ts`
* `gira.controller.ts`
* `dto/` (subpasta para DTOs)

```ts
// src/gira/gira.module.ts
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { GiraService } from './gira.service';
import { GiraController } from './gira.controller';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [ConfigModule, PrismaModule],
  providers: [GiraService],
  controllers: [GiraController],
  exports: [GiraService],
})
export class GiraModule {}
```

No `AppModule`, o módulo é simplesmente importado:

```ts
// src/app.module.ts
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module';
import { GiraModule } from './gira/gira.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    GiraModule,
  ],
})
export class AppModule {}
```

### 2.2. Variáveis de ambiente

O módulo utiliza duas variáveis principais:

```env
# Caminho absoluto para o ficheiro XLSX/CSV com as estações GIRA
GIRA_STATIONS_FILE=/app/data/gira_stations.xlsx

# Se "true", força reload do ficheiro ao arrancar o módulo
GIRA_FORCE_RELOAD=false
```

* **`GIRA_STATIONS_FILE`** – caminho completo para o ficheiro de estações (pode ser montado via Docker volume).
* **`GIRA_FORCE_RELOAD`** – quando `true`, apaga e recarrega sempre os dados da tabela `gira_stations` ao arrancar.

---

## 3. Modelo de Base de Dados (Prisma)

O modelo `GiraStation` representa uma estação no contexto do ficheiro original do GIRA.

```prisma
model GiraStation {
  id         Int      @id @default(autoincrement())

  // Id da estação no ficheiro original (ex.: "ID", "Station ID")
  externalId String?  // ex: "123"
  name       String?
  address    String?
  parish     String?  // freguesia / zona
  latitude   Float?
  longitude  Float?
  capacity   Int?     // número total de docks / bikes

  // Guarda o registo bruto para não perder nenhuma coluna
  raw        Json?

  createdAt  DateTime @default(now())
  updatedAt  DateTime @updatedAt

  @@map("gira_stations")
}
```

Notas:

* `raw` guarda o **row completo** do ficheiro (todas as colunas), permitindo devolver ao frontend exactamente o que existia no Excel.
* Os campos normalizados (`name`, `latitude`, `longitude`, etc.) facilitam pesquisas e integrações futuras (por exemplo, copiar estas estações para a tabela `Station` genérica).

---

## 4. DTOs

Os DTOs vivem em `src/gira/dto`.

### 4.1. `GiraStationRecordDto`

Representa um registo genérico de estação, tal como lido do Excel/CSV (mapa de colunas):

```ts
// src/gira/dto/gira-station.dto.ts
export interface GiraStationRecordDto {
  [column: string]: string | number | null;
}
```

### 4.2. `GiraStationsSliceDto`

Usado para paginação simples:

```ts
export interface GiraStationsSliceDto {
  total: number;
  slice: GiraStationRecordDto[];
}
```

### 4.3. Barrel de DTOs

```ts
// src/gira/dto/index.ts
export * from './gira-station.dto';
```

---

## 5. Serviço (`GiraService`)

O `GiraService` é responsável por:

1. **Carregar o ficheiro GIRA** (XLSX/CSV) em memória.
2. Converter as linhas do ficheiro em `GiraStationRecordDto[]`.
3. Sincronizar estas linhas com a tabela `gira_stations` (delete + insert em chunks).
4. Expor funções para:

   * Paginação (`getStationsSlice`)
   * Pesquisa (`searchStations`)

### 5.1. Estrutura base

```ts
// src/gira/gira.service.ts
import {
  Injectable,
  Logger,
  OnModuleInit,
  BadRequestException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { existsSync } from 'fs';
import { readFile, utils } from 'xlsx';
import {
  GiraStationRecordDto,
  GiraStationsSliceDto,
} from './dto';
import { PrismaService } from '../prisma/prisma.service';
import { GiraStation } from '@prisma/client';

@Injectable()
export class GiraService implements OnModuleInit {
  private readonly logger = new Logger(GiraService.name);

  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
  ) {}
```

---

### 5.2. Inicialização automática (`onModuleInit`)

Ao arrancar o módulo:

* Verifica quantos registos existem em `gira_stations`.
* Se `count === 0` ou `GIRA_FORCE_RELOAD=true` → recarrega o ficheiro.
* Caso contrário, assume que a tabela já está preenchida.

```ts
async onModuleInit() {
  const forceReload = this.config.get<string>('GIRA_FORCE_RELOAD') === 'true';
  const count = await this.prisma.giraStation.count();

  if (forceReload || count === 0) {
    this.logger.log(
      `Initializing GIRA stations (force=${forceReload}, existing=${count})`,
    );
    try {
      await this.loadStationsFromFile();
    } catch (err) {
      this.logger.error(
        'Error loading GIRA stations on module init',
        (err as Error).stack,
      );
    }
  } else {
    this.logger.log(
      `GIRA stations already present in DB (${count}); skipping file load`,
    );
  }
}
```

---

### 5.3. Carregar ficheiro (`loadStationsFromFile`)

Lê o ficheiro XLSX/CSV configurado em `GIRA_STATIONS_FILE` (ou um caminho explícito recebido por POST) e converte a primeira sheet em `GiraStationRecordDto[]`.

```ts
async loadStationsFromFile(filePathOverride?: string) {
  const filePath =
    filePathOverride ?? this.config.get<string>('GIRA_STATIONS_FILE');

  if (!filePath) {
    this.logger.warn('GIRA_STATIONS_FILE not configured; skipping ingestion');
    return;
  }
  if (!existsSync(filePath)) {
    throw new BadRequestException(
      `GIRA stations file not found at path ${filePath}`,
    );
  }

  this.logger.log(`Loading GIRA stations from ${filePath}`);

  const workbook = readFile(filePath);
  const [firstSheetName] = workbook.SheetNames;
  if (!firstSheetName) {
    throw new BadRequestException('GIRA workbook contains no sheets');
  }

  const worksheet = workbook.Sheets[firstSheetName];
  const rows = utils.sheet_to_json<GiraStationRecordDto>(worksheet, {
    defval: null,
  });

  this.logger.log(`Loaded ${rows.length} GIRA station records from file`);
  await this.syncStationsToDatabase(rows);
}
```

---

### 5.4. Sincronização com a base de dados (`syncStationsToDatabase`)

O método `syncStationsToDatabase` faz:

1. `deleteMany()` à tabela `gira_stations` (full refresh).
2. `createMany()` em chunks para não rebentar memória.

```ts
private async syncStationsToDatabase(rows: GiraStationRecordDto[]) {
  this.logger.log('Syncing GIRA stations into database...');

  // Limpa a tabela antes de inserir
  await this.prisma.giraStation.deleteMany();

  if (!rows.length) {
    this.logger.warn('No GIRA rows to persist; table left empty.');
    return;
  }

  const chunkSize = 5000; // ajustável
  const getString = (row: GiraStationRecordDto, key: string): string | null => {
    const v = row[key];
    if (v === null || v === undefined || v === '') return null;
    return String(v);
  };

  const getNumber = (row: GiraStationRecordDto, key: string): number | null => {
    const v = row[key];
    if (v === null || v === undefined || v === '') return null;
    const n = Number(v);
    return Number.isNaN(n) ? null : n;
  };

  for (let i = 0; i < rows.length; i += chunkSize) {
    const chunk = rows.slice(i, i + chunkSize);

    await this.prisma.giraStation.createMany({
      data: chunk.map((r) => ({
        // Adapta estes nomes às colunas reais do ficheiro GIRA
        externalId:
          getString(r, 'ID') ??
          getString(r, 'Station ID') ??
          getString(r, 'Id'),

        name:
          getString(r, 'Name') ??
          getString(r, 'Station Name'),

        address: getString(r, 'Address'),
        parish:
          getString(r, 'Parish') ??
          getString(r, 'Freguesia'),

        latitude:
          getNumber(r, 'Latitude') ??
          getNumber(r, 'lat') ??
          getNumber(r, 'LAT'),

        longitude:
          getNumber(r, 'Longitude') ??
          getNumber(r, 'lon') ??
          getNumber(r, 'LON'),

        capacity:
          getNumber(r, 'Capacity') ??
          getNumber(r, 'Docks') ??
          getNumber(r, 'Capacidade'),

        raw: r as any,
      })),
      skipDuplicates: true,
    });

    this.logger.log(
      `Inserted GIRA stations ${i}–${Math.min(
        i + chunkSize,
        rows.length,
      )} / ${rows.length}`,
    );
  }

  this.logger.log('✅ GIRA stations synced into database');
}
```

> Importante: os endpoints **não lêem o ficheiro Excel**. O ficheiro só é usado aqui, uma vez por carga. Depois disto, todos os dados vêm da base de dados.

---

### 5.5. Conversão para DTO genérico (`toRecordDto`)

Para manter compatibilidade com o formato original do ficheiro, o serviço expõe as estações como `GiraStationRecordDto`. O campo `raw` é usado preferencialmente:

```ts
private toRecordDto(dbRow: GiraStation): GiraStationRecordDto {
  if (dbRow.raw) {
    return dbRow.raw as GiraStationRecordDto;
  }

  const record: GiraStationRecordDto = {};
  if (dbRow.externalId) record['ID'] = dbRow.externalId;
  if (dbRow.name) record['Name'] = dbRow.name;
  if (dbRow.address) record['Address'] = dbRow.address;
  if (dbRow.parish) record['Parish'] = dbRow.parish;
  if (dbRow.latitude != null) record['Latitude'] = dbRow.latitude;
  if (dbRow.longitude != null) record['Longitude'] = dbRow.longitude;
  if (dbRow.capacity != null) record['Capacity'] = dbRow.capacity;
  return record;
}
```

Ou seja:

* Se `raw` estiver preenchido → devolve **exactamente** o row original do ficheiro (todas as colunas).
* Caso contrário (cenários futuros) → reconstrói um objeto compatível com as principais colunas.

---

### 5.6. Paginação (`getStationsSlice`)

```ts
async getStationsSlice(
  limit = 100,
  offset = 0,
): Promise<GiraStationsSliceDto> {
  const safeLimit = Math.min(Math.max(limit, 1), 1000);
  const safeOffset = Math.max(offset, 0);

  const [total, rows] = await this.prisma.$transaction([
    this.prisma.giraStation.count(),
    this.prisma.giraStation.findMany({
      skip: safeOffset,
      take: safeLimit,
      orderBy: { id: 'asc' },
    }),
  ]);

  return {
    total,
    slice: rows.map((r) => this.toRecordDto(r)),
  };
}
```

* Os dados vêm **exclusivamente da BD**, nunca do ficheiro.
* `slice` já vem no formato `GiraStationRecordDto` (normalmente igual ao row original do Excel).

---

### 5.7. Pesquisa (`searchStations`)

Permite pesquisar por alguns campos pré-definidos, usando Prisma.

```ts
async searchStations(field: string, value: string): Promise<GiraStationRecordDto[]> {
  if (!field || !value) {
    throw new BadRequestException(
      'Both "field" and "value" query parameters are required',
    );
  }

  const normalizedField = field.toLowerCase().trim();

  const fieldMap: Record<string, keyof GiraStation> = {
    name: 'name',
    externalid: 'externalId',
    address: 'address',
    parish: 'parish',
  };

  const prismaField = fieldMap[normalizedField];
  if (!prismaField) {
    throw new BadRequestException(
      `Unsupported search field "${field}". Use one of: ${Object.keys(
        fieldMap,
      ).join(', ')}`,
    );
  }

  const rows = await this.prisma.giraStation.findMany({
    where: {
      [prismaField]: {
        contains: value,
        mode: 'insensitive',
      } as any,
    },
    orderBy: { id: 'asc' },
    take: 500, // safety limit
  });

  return rows.map((r) => this.toRecordDto(r));
}
```

---

## 6. Controlador (`GiraController`)

O controlador expõe os endpoints HTTP.
Caminho base: **`/gira`**.

```ts
// src/gira/gira.controller.ts
import {
  Body,
  Controller,
  DefaultValuePipe,
  Get,
  ParseIntPipe,
  Post,
  Query,
} from '@nestjs/common';
import { GiraService } from './gira.service';

@Controller('gira')
export class GiraController {
  constructor(private readonly giraService: GiraService) {}

  @Get('stations')
  async getStations(
    @Query('limit', new DefaultValuePipe(100), ParseIntPipe) limit: number,
    @Query('offset', new DefaultValuePipe(0), ParseIntPipe) offset: number,
  ) {
    const { total, slice } = await this.giraService.getStationsSlice(
      limit,
      offset,
    );

    return {
      total,
      limit,
      offset,
      records: slice,
    };
  }

  @Get('stations/search')
  async searchStations(
    @Query('field') field: string,
    @Query('value') value: string,
  ) {
    const records = await this.giraService.searchStations(field, value);
    return {
      count: records.length,
      records,
    };
  }

  @Post('stations/reload')
  async reloadStations(@Body('filePath') filePath?: string) {
    await this.giraService.loadStationsFromFile(filePath);
    return { message: 'GIRA station data reloaded successfully' };
  }
}
```

### 6.1. Resumo dos endpoints

* `GET /gira/stations` – lista paginada de registos de estações
* `GET /gira/stations/search` – pesquisa por campo/valor
* `POST /gira/stations/reload` – recarrega dados a partir de ficheiro (ADMIN / manutenção)

---

## 7. Fluxo de Dados (Excel → BD → API)

1. **Excel/CSV GIRA**

   * Ficheiro de estações disponibilizado pela fonte oficial.

2. **Ingestão inicial**

   * `onModuleInit` chama `loadStationsFromFile` se a tabela estiver vazia ou `GIRA_FORCE_RELOAD=true`.

3. **Sincronização**

   * `syncStationsToDatabase` faz `deleteMany()` + `createMany()` em `gira_stations`.

4. **Consumo pelos endpoints**

   * `GET /gira/stations` → usa `getStationsSlice` → lê exclusivamente da BD.
   * `GET /gira/stations/search` → usa `searchStations` → lê exclusivamente da BD.
   * `records` devolve o `raw` original (todas as colunas), mantendo compatibilidade com o ficheiro.

5. **Reload manual (opcional)**

   * `POST /gira/stations/reload` permite recarregar a partir de um novo ficheiro.

---

## 8. Exemplos de Teste (Postman / Insomnia)

### 8.1. Verificar que as estações estão carregadas

**Request**

* Método: `GET`
* URL: `http://localhost:3000/gira/stations?limit=10&offset=0`

**Resposta (exemplo)**

```json
{
  "total": 285,
  "limit": 10,
  "offset": 0,
  "records": [
    {
      "ID": "101",
      "Name": "Campo Grande",
      "Address": "Campo Grande, Lisboa",
      "Parish": "Alvalade",
      "Latitude": 38.7581,
      "Longitude": -9.1573,
      "Capacity": 30,
      "...": "outras colunas do ficheiro"
    }
  ]
}
```

---

### 8.2. Pesquisa por nome

**Request**

* `GET http://localhost:3000/gira/stations/search?field=name&value=Campo`

**Resposta (exemplo)**

```json
{
  "count": 2,
  "records": [
    {
      "ID": "101",
      "Name": "Campo Grande",
      "Parish": "Alvalade",
      "Latitude": 38.7581,
      "Longitude": -9.1573,
      "Capacity": 30
    },
    {
      "ID": "102",
      "Name": "Campo Pequeno",
      "Parish": "Avenidas Novas",
      "Latitude": 38.7399,
      "Longitude": -9.1481,
      "Capacity": 25
    }
  ]
}
```

---

### 8.3. Reload manual a partir de um ficheiro

**Request**

* Método: `POST`
* URL: `http://localhost:3000/gira/stations/reload`
* Body (JSON):

```json
{
  "filePath": "/app/data/gira_stations_novo.xlsx"
}
```

**Resposta (exemplo)**

```json
{
  "message": "GIRA station data reloaded successfully"
}
```

> Atenção: este endpoint faz **delete + insert** de todas as estações. Em produção, deve ser tratado como um endpoint de **admin/manutenção**, idealmente protegido por autenticação.

---

## 9. Autenticação

Actualmente, o módulo **GIRA**:

* Não usa `JwtAuthGuard` em nenhum endpoint.
* Todos os endpoints (`/gira/stations`, `/gira/stations/search`, `/gira/stations/reload`) são públicos por omissão.

Recomenda-se, numa fase posterior:

* Proteger o endpoint `POST /gira/stations/reload` com um guard (ex.: JWT + role admin), uma vez que altera dados.
* Manter os endpoints de leitura (`GET /gira/stations`, `GET /gira/stations/search`) públicos ou semi-públicos, dependendo da política da aplicação.

---

## 10. Extensões Futuras

Algumas evoluções naturais para o módulo GIRA:

1. **Integração com a tabela `Station` genérica**

   * Criar um serviço/cron `syncGiraToStations()` que copia as estações GIRA para `Station` com `stationType = BIKE_STATION`.
   * Permite unificar GIRA com outras fontes (GBFS, GTFS, etc.).

2. **Endpoint normalizado**

   * Expor `/gira/stations/normalized` com uma estrutura mais simples:

     ```json
     {
       "id": "101",
       "name": "Campo Grande",
       "lat": 38.7581,
       "lon": -9.1573,
       "capacity": 30,
       "address": "...",
       "parish": "..."
     }
     ```

3. **Filtros adicionais**

   * Pesquisa por freguesia, capacidade mínima, bounding box (lat/lon), etc.

4. **Integração com mapas e routing**

   * Usar as coordenadas das estações GIRA como pontos de origem/destino em rotas multimodais (ex.: ligação ao módulo Routes/OTP).

Este documento serve como referência para a equipa backend e frontend na utilização do módulo GIRA, garantindo que está claro como os dados são ingeridos, guardados e expostos pela API.
