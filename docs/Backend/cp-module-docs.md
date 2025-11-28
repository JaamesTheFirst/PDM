
# Documentação do Módulo CP (Comboios de Portugal)

Este documento descreve, de forma detalhada e profissional, a implementação do módulo **CP** no backend (NestJS), incluindo:

- Contexto e objectivos do módulo
- Dependências e configuração
- Estrutura de DTOs
- Serviço (`CpService`)
- Controlador (`CpController`)
- Listagem exaustiva de endpoints
- Exemplos de testes com Postman
- Notas sobre autenticação e boas práticas

> Nota: Toda a terminologia e exemplos são pensados para Português de Portugal.

---

## 1. Contexto e Objectivos

O módulo **CP** integra dados de **Comboios de Portugal** e do grafo **OTP/GTFS** para disponibilizar:

1. **Dados em tempo real** sobre comboios (via API pública `comboios.live`).
2. **Informação de linhas CP** presentes no grafo de transportes (OTP v2 GraphQL).
3. **Informação de estações / paragens (stops)** e respectivos identificadores GTFS.
4. **Horários de partidas por estação**, em duas formas:
   - Dados brutos GTFS (adequado para lógica mais avançada no frontend).
   - Dados já formatados para UI (quadro de partidas com horas e atrasos).

O módulo foi desenhado para:

- Ser **read-only** (não altera dados externos).
- Expor **endpoints públicos**, sem necessidade de autenticação.
- Ser facilmente consumido por aplicações cliente (por exemplo, app Flutter).

---

## 2. Dependências e Configuração

### 2.1. Módulo NestJS

O módulo encontra-se em `src/cp` e contém:

- `cp.module.ts`
- `cp.service.ts`
- `cp.controller.ts`
- `dto/` (subpasta com DTOs)

```ts
// src/cp/cp.module.ts
import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { ConfigModule } from '@nestjs/config';
import { CpService } from './cp.service';
import { CpController } from './cp.controller';

@Module({
  imports: [HttpModule, ConfigModule],
  providers: [CpService],
  controllers: [CpController],
  exports: [CpService],
})
export class CpModule {}
```

### 2.2. Variáveis de ambiente

O módulo recorre a três variáveis principais:

```env
OTP_BASE_URL=http://localhost:8080/otp
CP_VEHICLES_API_URL=https://comboios.live/api/vehicles
CP_VEHICLES_CACHE_TTL_MS=30000
```

- **`OTP_BASE_URL`**  
  URL base do OpenTripPlanner v2.  
  O módulo assume o endpoint GraphQL em:
  - `${OTP_BASE_URL}/routers/default/index/graphql`

- **`CP_VEHICLES_API_URL`**  
  URL da API `comboios.live` para veículos em tempo real.  
  Por omissão:
  - `https://comboios.live/api/vehicles`

- **`CP_VEHICLES_CACHE_TTL_MS`**  
  Tempo de vida (TTL) da cache de veículos, em milissegundos.  
  Valor por defeito: `30000` (30 segundos).

---

## 3. DTOs (Data Transfer Objects)

Todos os DTOs do módulo CP se encontram em `src/cp/dto`.

### 3.1. Veículos em tempo real (`cp-vehicle.dto.ts`)

```ts
export interface CpVehicleDto {
  trainNumber: number;
  runDate: string;
  delay: number | null;
  lastStation: string | null;
  latitude: string | null;
  longitude: string | null;
  status: string;
  hasDisruptions: boolean;
  service: {
    code: string;
    designation: string;
  };
  origin: {
    code: string;
    designation: string;
  };
  destination: {
    code: string;
    designation: string;
  };
}

export interface CpVehiclesApiResponse {
  vehicles: CpVehicleDto[];
}
```

- `trainNumber` — número do comboio (ex.: 133).
- `runDate` — data de circulação.
- `delay` — atraso em segundos (pode ser `null`).
- `latitude` / `longitude` — posição actual do comboio, se disponível.
- `service`, `origin`, `destination` — metadados comerciais e geográficos.

---

### 3.2. DTOs do grafo OTP/GTFS (`cp-graph.dto.ts`)

#### 3.2.1. Linhas CP (routes)

```ts
export interface CpGraphRouteDto {
  gtfsId: string;
  shortName?: string | null;
  longName?: string | null;
  mode: string;
  agencyName?: string | null;
  agencyGtfsId?: string | null;
}
```

- Representa uma linha CP no grafo (ex.: AP, IC, R).

#### 3.2.2. Stops básicos e detalhe de route

```ts
export interface CpStopBasicDto {
  gtfsId: string;
  name: string;
  lat?: number;
  lon?: number;
}

export interface CpGraphRouteDetailDto extends CpGraphRouteDto {
  stops: CpStopBasicDto[];
}
```

- `CpGraphRouteDetailDto` inclui:
  - Metadados da linha (herdados de `CpGraphRouteDto`).
  - Lista de paragens (stops) associadas.

#### 3.2.3. Resultado de pesquisa de stops

```ts
export interface CpStopSearchResultDto {
  gtfsId: string;
  name: string;
  lat?: number;
  lon?: number;
}
```

- Utilizado em `/cp/stops/search`.

#### 3.2.4. Partidas brutas (GTFS)

```ts
export interface CpDepartureDto {
  routeGtfsId?: string;
  routeShortName?: string | null;
  routeLongName?: string | null;
  mode: string;
  agencyName?: string | null;
  headsign?: string | null;
  scheduledDeparture: number;   // segundos desde serviceDay
  realtimeDeparture: number;    // segundos desde serviceDay
  realtime: boolean;
  serviceDay: number;           // epoch (segundos, meia-noite local)
}

export interface CpStopDeparturesDto {
  stopId: string;
  stopName: string;
  lat?: number;
  lon?: number;
  departures: CpDepartureDto[];
}
```

- `serviceDay` — epoch (segundos) do início do dia de serviço.
- `scheduledDeparture` e `realtimeDeparture` — segundos desde `serviceDay`.

#### 3.2.5. Board formatado para UI

```ts
export interface CpStopBoardRowDto {
  time: string;                // "HH:MM"
  destination: string | null;  // headsign
  lineShortName?: string | null;
  lineLongName?: string | null;
  routeGtfsId?: string;
  delayMinutes: number;        // pode ser 0
  isRealtime: boolean;
}

export interface CpStopBoardDto {
  stopId: string;
  stopName: string;
  lat?: number;
  lon?: number;
  departures: CpStopBoardRowDto[];
}
```

- Estes DTOs são pensados para consumo directo pela UI, sem cálculos extra.

---

### 3.3. Barrel de DTOs (`index.ts`)

```ts
// src/cp/dto/index.ts
export * from './cp-vehicle.dto';
export * from './cp-graph.dto';
```

---

## 4. Serviço (`CpService`)

O serviço é responsável por:

1. Contactar a API `comboios.live` (veículos em tempo real).
2. Contactar o OTP v2 GraphQL (routes, stops, horários).
3. Filtrar apenas dados relevantes a CP.
4. Formatar dados para os DTOs definidos.

### 4.1. Estrutura geral

```ts
@Injectable()
export class CpService {
  private readonly logger = new Logger(CpService.name);

  private vehiclesCache: CpVehicleDto[] = [];
  private cacheTimestamp = 0;

  constructor(
    private readonly http: HttpService,
    private readonly configService: ConfigService,
  ) {}
}
```

---

### 4.2. Configuração de URLs

```ts
private get vehiclesApiUrl(): string {
  return (
    this.configService.get<string>('CP_VEHICLES_API_URL') ||
    'https://comboios.live/api/vehicles'
  );
}

private get cacheTtlMs(): number {
  const configured = this.configService.get<number>(
    'CP_VEHICLES_CACHE_TTL_MS',
  );
  return configured ?? 30_000;
}

private get otpGraphQlUrl(): string {
  const base =
    this.configService.get<string>('OTP_BASE_URL') ||
    'http://localhost:8080/otp';
  return `${base.replace(/\/$/, '')}/routers/default/index/graphql`;
}
```

---

### 4.3. Veículos em tempo real (comboios.live)

#### 4.3.1. Fetch directo da API

```ts
private async fetchVehicles(): Promise<CpVehicleDto[]> {
  const { data } = await firstValueFrom(
    this.http.get<CpVehiclesApiResponse>(this.vehiclesApiUrl),
  );
  return data.vehicles ?? [];
}
```

#### 4.3.2. Método público com cache

```ts
async getVehicles(forceRefresh = false): Promise<CpVehicleDto[]> {
  const cacheIsFresh =
    Date.now() - this.cacheTimestamp < this.cacheTtlMs &&
    this.vehiclesCache.length > 0;

  if (!forceRefresh && cacheIsFresh) {
    return this.vehiclesCache;
  }

  try {
    this.vehiclesCache = await this.fetchVehicles();
    this.cacheTimestamp = Date.now();
    return this.vehiclesCache;
  } catch (error) {
    this.logger.error('Failed to fetch CP vehicles', error as any);
    if (this.vehiclesCache.length > 0) {
      this.logger.warn('Serving cached CP vehicles due to upstream failure');
      return this.vehiclesCache;
    }
    throw new ServiceUnavailableException('Failed to fetch CP vehicles');
  }
}
```

#### 4.3.3. Obter um comboio específico

```ts
async getVehicle(trainNumber: string): Promise<CpVehicleDto | undefined> {
  const vehicles = await this.getVehicles();
  return vehicles.find(
    (vehicle) => String(vehicle.trainNumber) === String(trainNumber),
  );
}
```

---

### 4.4. OTP/GTFS – Linhas CP

#### 4.4.1. Query GraphQL de routes

```ts
const ROUTES_QUERY = `
  query Routes {
    routes {
      gtfsId
      shortName
      longName
      mode
      agency {
        gtfsId
        name
      }
    }
  }
`;
```

#### 4.4.2. Obter todas as routes CP

```ts
async getCpRoutesFromGraph(): Promise<CpGraphRouteDto[]> {
  try {
    const response = await firstValueFrom(
      this.http.post<GtfsRoutesResponse>(
        this.otpGraphQlUrl,
        { query: ROUTES_QUERY },
        { headers: { 'Content-Type': 'application/json' } },
      ),
    );

    if (response.data.errors && response.data.errors.length > 0) {
      this.logger.error(
        response.data.errors.map((e) => e.message).join('; '),
      );
      throw new ServiceUnavailableException('OTP returned an error');
    }

    const routes = response.data.data?.routes ?? [];

    const cpRoutes = routes.filter((r) => {
      const agencyName = (r.agency?.name || '').toLowerCase();
      const isRail = r.mode === 'RAIL' || r.mode === 'TRAIN';
      const isCp =
        agencyName.includes('comboios de portugal') ||
        agencyName.startsWith('cp ');
      return isRail || isCp;
    });

    return cpRoutes.map((r) => ({
      gtfsId: r.gtfsId,
      shortName: r.shortName ?? null,
      longName: r.longName ?? null,
      mode: r.mode,
      agencyName: r.agency?.name ?? null,
      agencyGtfsId: r.agency?.gtfsId ?? null,
    }));
  } catch (error) {
    this.logger.error('Failed to fetch CP routes from OTP', error as any);
    throw new ServiceUnavailableException(
      'Failed to fetch CP routes from OTP',
    );
  }
}
```

---

### 4.5. OTP/GTFS – Detalhe de route + stops

#### 4.5.1. Query GraphQL de detalhe

```ts
const ROUTE_DETAIL_QUERY = `
  query RouteDetail($id: String!) {
    route(id: $id) {
      gtfsId
      shortName
      longName
      mode
      agency {
        gtfsId
        name
      }
      patterns {
        stops {
          gtfsId
          name
          lat
          lon
        }
      }
    }
  }
`;
```

#### 4.5.2. Método de detalhe

```ts
async getCpRouteDetail(routeGtfsId: string): Promise<CpGraphRouteDetailDto> {
  try {
    const response = await firstValueFrom(
      this.http.post<GtfsRouteDetailResponse>(
        this.otpGraphQlUrl,
        {
          query: ROUTE_DETAIL_QUERY,
          variables: { id: routeGtfsId },
        },
        { headers: { 'Content-Type': 'application/json' } },
      ),
    );

    if (response.data.errors && response.data.errors.length > 0) {
      this.logger.error(
        response.data.errors.map((e) => e.message).join('; '),
      );
      throw new ServiceUnavailableException('OTP returned an error');
    }

    const route = response.data.data?.route;
    if (!route) {
      throw new NotFoundException(
        `Route ${routeGtfsId} not found in OTP graph`,
      );
    }

    const stopsMap = new Map<string, CpStopBasicDto>();
    for (const pattern of route.patterns || []) {
      for (const st of pattern.stops || []) {
        if (!stopsMap.has(st.gtfsId)) {
          stopsMap.set(st.gtfsId, {
            gtfsId: st.gtfsId,
            name: st.name,
            lat: st.lat,
            lon: st.lon,
          });
        }
      }
    }

    return {
      gtfsId: route.gtfsId,
      shortName: route.shortName ?? null,
      longName: route.longName ?? null,
      mode: route.mode,
      agencyName: route.agency?.name ?? null,
      agencyGtfsId: route.agency?.gtfsId ?? null,
      stops: Array.from(stopsMap.values()),
    };
  } catch (error) {
    this.logger.error(
      `Failed to fetch CP route detail ${routeGtfsId} from OTP`,
      error as any,
    );
    throw new ServiceUnavailableException(
      'Failed to fetch CP route detail from OTP',
    );
  }
}
```

---

### 4.6. OTP/GTFS – Pesquisa de stops

#### 4.6.1. Query de pesquisa

```ts
const STOPS_SEARCH_QUERY = `
  query StopsSearch($name: String!) {
    stops(name: $name) {
      gtfsId
      name
      lat
      lon
    }
  }
`;
```

#### 4.6.2. Método de pesquisa

```ts
async searchStops(q: string, limit = 10): Promise<CpStopSearchResultDto[]> {
  if (!q || q.trim().length === 0) return [];

  try {
    const response = await firstValueFrom(
      this.http.post<GtfsStopsSearchResponse>(
        this.otpGraphQlUrl,
        {
          query: STOPS_SEARCH_QUERY,
          variables: { name: q },
        },
        { headers: { 'Content-Type': 'application/json' } },
      ),
    );

    if (response.data.errors && response.data.errors.length > 0) {
      this.logger.error(
        response.data.errors.map((e) => e.message).join('; '),
      );
      throw new ServiceUnavailableException('OTP returned an error');
    }

    const stops = response.data.data?.stops ?? [];
    const trimmed = stops.slice(0, limit);

    return trimmed.map((s) => ({
      gtfsId: s.gtfsId,
      name: s.name,
      lat: s.lat,
      lon: s.lon,
    }));
  } catch (error) {
    this.logger.error('Failed to search stops in OTP', error as any);
    throw new ServiceUnavailableException('Failed to search stops in OTP');
  }
}
```

---

### 4.7. OTP/GTFS – Partidas por stop (bruto)

#### 4.7.1. Query de partidas

```ts
const STOP_DEPARTURES_QUERY = `
  query StopDepartures(
    $stopId: String!,
    $startTime: Long!,
    $timeRange: Int!,
    $numberOfDepartures: Int!
  ) {
    stop(id: $stopId) {
      gtfsId
      name
      lat
      lon
      stoptimesForPatterns(
        startTime: $startTime,
        timeRange: $timeRange,
        numberOfDepartures: $numberOfDepartures
      ) {
        pattern {
          headsign
          route {
            gtfsId
            shortName
            longName
            mode
            agency {
              gtfsId
              name
            }
          }
        }
        stoptimes {
          scheduledDeparture
          realtimeDeparture
          realtime
          serviceDay
          headsign
        }
      }
    }
  }
`;
```

#### 4.7.2. Método bruto

```ts
async getStopDeparturesFromGraph(
  stopGtfsId: string,
  opts?: {
    startTime?: number;
    timeRange?: number;
    numberOfDepartures?: number;
  },
): Promise<CpStopDeparturesDto> {
  const nowSeconds = Math.floor(Date.now() / 1000);

  const startTime = opts?.startTime ?? nowSeconds;
  const timeRange = opts?.timeRange ?? 3600;
  const numberOfDepartures = opts?.numberOfDepartures ?? 20;

  try {
    const response = await firstValueFrom(
      this.http.post<GtfsStopDeparturesResponse>(
        this.otpGraphQlUrl,
        {
          query: STOP_DEPARTURES_QUERY,
          variables: {
            stopId: stopGtfsId,
            startTime,
            timeRange,
            numberOfDepartures,
          },
        },
        { headers: { 'Content-Type': 'application/json' } },
      ),
    );

    if (response.data.errors && response.data.errors.length > 0) {
      this.logger.error(
        response.data.errors.map((e) => e.message).join('; '),
      );
      throw new ServiceUnavailableException('OTP returned an error');
    }

    const stop = response.data.data?.stop;
    if (!stop) {
      throw new NotFoundException(
        `Stop ${stopGtfsId} not found in OTP graph`,
      );
    }

    const departures: CpDepartureDto[] = [];

    for (const patternRow of stop.stoptimesForPatterns || []) {
      const route = patternRow.pattern?.route;
      const patternHeadsign = patternRow.pattern?.headsign ?? undefined;
      const agencyName = route?.agency?.name ?? undefined;

      const isRail =
        route?.mode === 'RAIL' || route?.mode === 'TRAIN';
      const isCp =
        (agencyName || '').toLowerCase().includes('comboios de portugal') ||
        (agencyName || '').toLowerCase().startsWith('cp ');

      if (!isRail && !isCp) {
        continue;
      }

      for (const st of patternRow.stoptimes || []) {
        departures.push({
          routeGtfsId: route?.gtfsId,
          routeShortName: route?.shortName ?? null,
          routeLongName: route?.longName ?? null,
          mode: route?.mode ?? 'RAIL',
          agencyName,
          headsign: st.headsign ?? patternHeadsign ?? undefined,
          scheduledDeparture: st.scheduledDeparture,
          realtimeDeparture: st.realtimeDeparture,
          realtime: st.realtime,
          serviceDay: st.serviceDay,
        });
      }
    }

    return {
      stopId: stop.gtfsId,
      stopName: stop.name,
      lat: stop.lat,
      lon: stop.lon,
      departures,
    };
  } catch (error) {
    this.logger.error(
      `Failed to fetch departures for stop ${stopGtfsId} from OTP`,
      error as any,
    );
    throw new ServiceUnavailableException(
      'Failed to fetch departures for this stop from OTP',
    );
  }
}
```

---

### 4.8. OTP/GTFS – Board formatado para UI

```ts
async getStopBoard(
  stopGtfsId: string,
  opts?: {
    startTime?: number;
    timeRange?: number;
    numberOfDepartures?: number;
  },
): Promise<CpStopBoardDto> {
  const raw = await this.getStopDeparturesFromGraph(stopGtfsId, opts);

  const rows: CpStopBoardRowDto[] = raw.departures
    .map((d) => {
      const departureEpochSeconds = d.serviceDay + d.realtimeDeparture;
      const date = new Date(departureEpochSeconds * 1000);
      const hh = String(date.getHours()).padStart(2, '0');
      const mm = String(date.getMinutes()).padStart(2, '0');
      const time = `${hh}:${mm}`;

      const delaySeconds = d.realtimeDeparture - d.scheduledDeparture;
      const delayMinutes = Math.round(delaySeconds / 60);

      return {
        time,
        destination: d.headsign ?? null,
        lineShortName: d.routeShortName ?? null,
        lineLongName: d.routeLongName ?? null,
        routeGtfsId: d.routeGtfsId,
        delayMinutes,
        isRealtime: d.realtime,
      } as CpStopBoardRowDto;
    })
    .sort((a, b) => (a.time < b.time ? -1 : a.time > b.time ? 1 : 0));

  return {
    stopId: raw.stopId,
    stopName: raw.stopName,
    lat: raw.lat,
    lon: raw.lon,
    departures: rows,
  };
}
```

---

## 5. Controlador (`CpController`)

O controlador expõe os endpoints HTTP.  
Caminho base: **`/cp`**.

```ts
@Controller('cp')
export class CpController {
  constructor(private readonly cpService: CpService) {}
}
```

### 5.1. Endpoints de veículos em tempo real

#### 5.1.1. Listar todos os veículos

- **Método:** `GET`
- **URL:** `/cp/vehicles`
- **Query params:**
  - `refresh` (boolean, opcional) — força refresh da cache.

```ts
@Get('vehicles')
getVehicles(
  @Query('refresh', new DefaultValuePipe(false), ParseBoolPipe)
  refresh: boolean,
): Promise<CpVehicleDto[]> {
  return this.cpService.getVehicles(refresh);
}
```

#### 5.1.2. Detalhe de um veículo

- **Método:** `GET`
- **URL:** `/cp/vehicles/:trainNumber`

```ts
@Get('vehicles/:trainNumber')
async getVehicle(
  @Param('trainNumber') trainNumber: string,
): Promise<CpVehicleDto> {
  const vehicle = await this.cpService.getVehicle(trainNumber);
  if (!vehicle) {
    throw new NotFoundException(
      `Train ${trainNumber} not found in latest CP feed`,
    );
  }
  return vehicle;
}
```

---

### 5.2. Endpoints de linhas CP (grafo)

#### 5.2.1. Listar todas as routes CP

- **Método:** `GET`
- **URL:** `/cp/routes/graph`

```ts
@Get('routes/graph')
getCpRoutesFromGraph(): Promise<CpGraphRouteDto[]> {
  return this.cpService.getCpRoutesFromGraph();
}
```

#### 5.2.2. Detalhe de uma route

- **Método:** `GET`
- **URL:** `/cp/routes/graph/:routeGtfsId`

```ts
@Get('routes/graph/:routeGtfsId')
getCpRouteDetail(
  @Param('routeGtfsId') routeGtfsId: string,
): Promise<CpGraphRouteDetailDto> {
  return this.cpService.getCpRouteDetail(routeGtfsId);
}
```

#### 5.2.3. Stops de uma route (wrapper)

- **Método:** `GET`
- **URL:** `/cp/routes/graph/:routeGtfsId/stops`

```ts
@Get('routes/graph/:routeGtfsId/stops')
async getCpRouteStops(
  @Param('routeGtfsId') routeGtfsId: string,
): Promise<{ route: CpGraphRouteDetailDto }> {
  const detail = await this.cpService.getCpRouteDetail(routeGtfsId);
  return { route: detail };
}
```

---

### 5.3. Endpoints de pesquisa de stops

#### 5.3.1. Pesquisa por nome

- **Método:** `GET`
- **URL:** `/cp/stops/search`
- **Query params:**
  - `q` — texto de pesquisa (obrigatório).
  - `limit` — máximo de resultados (opcional, default 10).

```ts
@Get('stops/search')
searchStops(
  @Query('q') q: string,
  @Query('limit', new DefaultValuePipe(10), ParseIntPipe)
  limit: number,
): Promise<CpStopSearchResultDto[]> {
  return this.cpService.searchStops(q, limit);
}
```

---

### 5.4. Endpoints de horários (departures)

#### 5.4.1. Dados brutos GTFS

- **Método:** `GET`
- **URL:** `/cp/stops/:gtfsId/departures`
- **Query params:**
  - `startTime` (epoch seconds, opcional; se omisso, usa “agora”).
  - `timeRange` (segundos, opcional; default 3600).
  - `numberOfDepartures` (opcional; default 20).

```ts
@Get('stops/:gtfsId/departures')
getStopDepartures(
  @Param('gtfsId') gtfsId: string,
  @Query('startTime') startTime?: string,
  @Query('timeRange', new DefaultValuePipe(3600), ParseIntPipe)
  timeRange?: number,
  @Query('numberOfDepartures', new DefaultValuePipe(20), ParseIntPipe)
  numberOfDepartures?: number,
): Promise<CpStopDeparturesDto> {
  const startTimeSec = startTime ? Number(startTime) : undefined;

  return this.cpService.getStopDeparturesFromGraph(gtfsId, {
    startTime: startTimeSec,
    timeRange,
    numberOfDepartures,
  });
}
```

#### 5.4.2. Board formatado para UI

- **Método:** `GET`
- **URL:** `/cp/stops/:gtfsId/departures/board`

```ts
@Get('stops/:gtfsId/departures/board')
getStopBoard(
  @Param('gtfsId') gtfsId: string,
  @Query('startTime') startTime?: string,
  @Query('timeRange', new DefaultValuePipe(3600), ParseIntPipe)
  timeRange?: number,
  @Query('numberOfDepartures', new DefaultValuePipe(20), ParseIntPipe)
  numberOfDepartures?: number,
): Promise<CpStopBoardDto> {
  const startTimeSec = startTime ? Number(startTime) : undefined;

  return this.cpService.getStopBoard(gtfsId, {
    startTime: startTimeSec,
    timeRange,
    numberOfDepartures,
  });
}
```

---

## 6. Testes básicos com Postman

### 6.1. Pré-requisitos

- Backend NestJS a correr em: `http://localhost:3000`
- OTP v2 a correr em: `http://localhost:8080/otp`
- Grafo OTP com GTFS da CP carregado.
- Módulo `CpModule` importado no `AppModule`.

---

### 6.2. Testar veículos em tempo real

#### 6.2.1. Listar todos os comboios

- **Request**
  - Método: `GET`
  - URL: `http://localhost:3000/cp/vehicles`

- **Resposta esperada (exemplo)**

```json
[
  {
    "trainNumber": 133,
    "runDate": "2025-11-26",
    "delay": 120,
    "lastStation": "Porto Campanha",
    "latitude": "41.1487193",
    "longitude": "-8.5848353",
    "status": "RUNNING",
    "hasDisruptions": false,
    "service": {
      "code": "AP",
      "designation": "Alfa Pendular"
    },
    "origin": {
      "code": "PSE",
      "designation": "Porto São Bento"
    },
    "destination": {
      "code": "LSA",
      "designation": "Lisboa Santa Apolónia"
    }
  }
]
```

#### 6.2.2. Forçar refresh da cache

- **Request**
  - `GET http://localhost:3000/cp/vehicles?refresh=true`

---

#### 6.2.3. Obter um comboio específico

1. Primeiro, obter um `trainNumber` da resposta anterior (ex.: `133`).
2. De seguida:

- **Request**
  - `GET http://localhost:3000/cp/vehicles/133`

- **Resposta esperada (exemplo)**

```json
{
  "trainNumber": 133,
  "runDate": "2025-11-26",
  "delay": 120,
  "lastStation": "Porto Campanha",
  "latitude": "41.1487193",
  "longitude": "-8.5848353",
  "status": "RUNNING",
  "hasDisruptions": false,
  "service": {
    "code": "AP",
    "designation": "Alfa Pendular"
  },
  "origin": {
    "code": "PSE",
    "designation": "Porto São Bento"
  },
  "destination": {
    "code": "LSA",
    "designation": "Lisboa Santa Apolónia"
  }
}
```

---

### 6.3. Testar linhas CP no grafo

#### 6.3.1. Listar todas as routes CP

- **Request**
  - `GET http://localhost:3000/cp/routes/graph`

- **Resposta esperada (exemplo)**

```json
[
  {
    "gtfsId": "PT_CPF:AP123",
    "shortName": "AP",
    "longName": "Porto - Lisboa",
    "mode": "RAIL",
    "agencyName": "CP - Comboios de Portugal",
    "agencyGtfsId": "PT_CPF"
  },
  {
    "gtfsId": "PT_CPF:IC456",
    "shortName": "IC",
    "longName": "Porto - Lisboa",
    "mode": "RAIL",
    "agencyName": "CP - Comboios de Portugal",
    "agencyGtfsId": "PT_CPF"
  }
]
```

Guarde um `gtfsId` de route, por exemplo `PT_CPF:AP123`.

---

#### 6.3.2. Detalhe de uma route + stops

- **Request**
  - `GET http://localhost:3000/cp/routes/graph/PT_CPF:AP123`

- **Resposta esperada (exemplo)**

```json
{
  "gtfsId": "PT_CPF:AP123",
  "shortName": "AP",
  "longName": "Porto - Lisboa",
  "mode": "RAIL",
  "agencyName": "CP - Comboios de Portugal",
  "agencyGtfsId": "PT_CPF",
  "stops": [
    {
      "gtfsId": "PT_CPF:94_2006",
      "name": "Porto Campanha",
      "lat": 41.1487193,
      "lon": -8.5848353
    },
    {
      "gtfsId": "PT_CPF:94_31039",
      "name": "Lisboa Oriente",
      "lat": 38.7677593,
      "lon": -9.0990948
    }
  ]
}
```

---

### 6.4. Testar pesquisa de estações

#### 6.4.1. Pesquisa simples

- **Request**
  - `GET http://localhost:3000/cp/stops/search?q=Campanha&limit=5`

- **Resposta esperada (exemplo)**

```json
[
  {
    "gtfsId": "PT_CPF:94_2006",
    "name": "Porto Campanha",
    "lat": 41.1487193,
    "lon": -8.5848353
  },
  {
    "gtfsId": "PT_CPF:94_1008",
    "name": "Porto Sao Bento",
    "lat": 41.1455668,
    "lon": -8.6102211
  }
]
```

Guarde um `gtfsId` (por exemplo `PT_CPF:94_2006`) para os testes de horários.

---

### 6.5. Testar horários brutos (`/departures`)

- **Request**
  - `GET http://localhost:3000/cp/stops/PT_CPF:94_2006/departures?timeRange=7200&numberOfDepartures=20`

- **Resposta esperada (exemplo)**

```json
{
  "stopId": "PT_CPF:94_2006",
  "stopName": "Porto Campanha",
  "lat": 41.1487193,
  "lon": -8.5848353,
  "departures": [
    {
      "routeGtfsId": "PT_CPF:AP123",
      "routeShortName": "AP",
      "routeLongName": "Porto - Lisboa",
      "mode": "RAIL",
      "agencyName": "CP - Comboios de Portugal",
      "headsign": "Lisboa Santa Apolonia",
      "scheduledDeparture": 43200,
      "realtimeDeparture": 43320,
      "realtime": true,
      "serviceDay": 1764182400
    }
  ]
}
```

---

### 6.6. Testar board formatado (`/departures/board`)

- **Request**
  - `GET http://localhost:3000/cp/stops/PT_CPF:94_2006/departures/board?timeRange=7200&numberOfDepartures=20`

- **Resposta esperada (exemplo)**

```json
{
  "stopId": "PT_CPF:94_2006",
  "stopName": "Porto Campanha",
  "lat": 41.1487193,
  "lon": -8.5848353,
  "departures": [
    {
      "time": "12:05",
      "destination": "Lisboa Santa Apolonia",
      "lineShortName": "AP",
      "lineLongName": "Porto - Lisboa",
      "routeGtfsId": "PT_CPF:AP123",
      "delayMinutes": 2,
      "isRealtime": true
    },
    {
      "time": "12:30",
      "destination": "Azambuja",
      "lineShortName": "R",
      "lineLongName": "Lisboa - Azambuja",
      "routeGtfsId": "PT_CPF:R789",
      "delayMinutes": 0,
      "isRealtime": false
    }
  ]
}
```

Este endpoint é o mais apropriado para a UI, pois:

- Evita que o frontend tenha de converter `serviceDay` + `realtimeDeparture` em horas.
- Devolve já as horas no formato `"HH:MM"`.
- Indica o atraso em minutos (`delayMinutes`) e se é informação em tempo real (`isRealtime`).

---

## 7. Autenticação

O módulo **CP** foi desenhado para expor **dados públicos**, pelo que:

- **Não** utiliza `JwtAuthGuard` nos endpoints.
- Pode ser consumido directamente por qualquer cliente (Web, Mobile, etc.).

A autenticação será relevante noutros módulos, por exemplo:

- Histórico de viagens do utilizador.
- Estações favoritas do utilizador.
- Estatísticas ecológicas personalizadas.

Nesses casos, deverá ser utilizado o `JwtAuthGuard` e o payload JWT já implementado no módulo `auth`.

---

## 8. Boas práticas e extensões futuras

Possíveis evoluções:

1. **Integração entre horários GTFS e posições em tempo real**
   - Endpoint que combine:
     - `getStopDeparturesFromGraph` (horários planeados)
     - `getVehicles` / `getVehicle` (atrasos e posições)
   - Para fornecer por exemplo:
     - “comboio X está a Y km da estação, chega em Z minutos”.

2. **Filtros avançados de linhas**
   - Permitir query params em `/cp/routes/graph` para filtrar por:
     - `mode=RAIL`, `shortName=AP`, etc.

3. **Paginação e limites**
   - Em cenários de muitos resultados, considerar:
     - Paginação explicitamente definida em endpoints de pesquisa.

4. **Cache adicional no lado do OTP**
   - Cache de respostas frequentes de routes/stops, se necessário.

---

## 9. Resumo

O módulo **CP** fornece uma base sólida para trabalhar com:

- Dados em tempo real de comboios (API externa).
- Estrutura de linhas e estações CP via grafo OTP/GTFS.
- Horários de partidas em formato bruto e amigável para UI.

A implementação está alinhada com boas práticas NestJS, com:

- Separação clara entre serviço e controlador.
- Utilização de DTOs específicos.
- Tratamento de erros robusto (incluindo fallback de cache na API externa).
- Endpoints públicos adequados para ser consumidos por uma app de mobilidade multimodal.

Este documento pode ser utilizado como referência tanto para desenvolvimento backend como para equipas de frontend que necessitem de integrar os dados da CP na aplicação.
