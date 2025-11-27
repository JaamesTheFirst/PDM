# Documentação do Módulo Metro (Lisboa + Porto)

## Índice

1. [Visão geral](#1-visão-geral)
2. [Arquitectura e ficheiros](#2-arquitectura-e-ficheiros)
3. [Configuração e ambiente](#3-configuração-e-ambiente)
4. [Modelo de dados (DTOs)](#4-modelo-de-dados-dtos)
   - [4.1 DTOs Metro Lisboa](#41-dtos-metro-lisboa)
   - [4.2 DTOs Metro do Porto (OTP)](#42-dtos-metro-do-porto-otp)
5. [Serviços](#5-serviços)
   - [5.1 MetroService (Lisboa)](#51-metroservice-lisboa)
   - [5.2 MetroTokenService (Lisboa)](#52-metrotokenservice-lisboa)
   - [5.3 MetroPortoService (Porto / OTP)](#53-metroportoservice-porto--otp)
6. [Controller e rotas HTTP](#6-controller-e-rotas-http)
7. [Referência de endpoints – Metro Lisboa](#7-referência-de-endpoints--metro-lisboa)
8. [Referência de endpoints – Metro do Porto](#8-referência-de-endpoints--metro-do-porto)
9. [Testes com Postman](#9-testes-com-postman)
10. [Tratamento de erros e logging](#10-tratamento-de-erros-e-logging)
11. [Integração com outras partes do sistema](#11-integração-com-outras-partes-do-sistema)
12. [Possíveis extensões futuras](#12-possíveis-extensões-futuras)

---

## 1. Visão geral

O módulo **`metro`** fornece uma camada unificada de acesso a informação de metro para duas áreas metropolitanas:

- **Metro de Lisboa**
  - Integração com a API oficial do Metro de Lisboa.
  - Permite consultar:
    - Estado das linhas.
    - Tempos de espera por estação/linha.
    - Informação de estações.
    - Intervalos entre comboios.
    - Destinos.

- **Metro do Porto**
  - Integração com o **OpenTripPlanner (OTP v2)** já configurado no projecto.
  - Usa o **grafo GTFS/OSM** para:
    - Obter agências/linhas (routes).
    - Obter paragens (stops).
    - Obter paragens por linha.
    - Obter partidas próximas numa determinada paragem.

Todos os endpoints são expostos sob o prefixo:

- `GET /metro/...` → Metro de Lisboa
- `GET /metro/porto/...` → Metro do Porto (via OTP GraphQL)

> **Nota:**  
> Os endpoints do módulo `metro` são actualmente **públicos** (sem autenticação JWT), uma vez que expõem informação sobre redes de transporte público.

---

## 2. Arquitectura e ficheiros

Estrutura principal do módulo:

```text
src/
  metro/
    dto/
      metro.dto.ts          # DTOs Metro Lisboa
      metro-porto.dto.ts    # DTOs Metro Porto (OTP)
      index.ts              # Re-export de todos os DTOs

    metro.module.ts         # Declaração do módulo para NestJS
    metro.controller.ts     # Controller único (Lisboa + Porto)
    metro.service.ts        # Lógica de integração Metro Lisboa
    metro-token.service.ts  # Gestão de token OAuth2 / API key Metro Lisboa
    metro-porto.service.ts  # Lógica de integração Metro Porto (OTP GraphQL)
```

Integração no `AppModule` (exemplo):

```ts
// src/app.module.ts
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { MetroModule } from './metro/metro.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    MetroModule,
    // outros módulos...
  ],
})
export class AppModule {}
```

---

## 3. Configuração e ambiente

### 3.1. Variáveis de ambiente

Ficheiro `.env` do backend deve conter, pelo menos:

```env
# OTP (OpenTripPlanner) v2
OTP_BASE_URL=http://localhost:8080/otp

# Metro Lisboa – escolher uma das abordagens

# 1) API key legacy (Bearer token directo na chamada à API de estado)
METRO_LISBOA_API_KEY=

# 2) OU OAuth2 Client Credentials (recommended a longo prazo)
METRO_LISBOA_CLIENT_ID=
METRO_LISBOA_CLIENT_SECRET=
```

Regras:

- Se `METRO_LISBOA_API_KEY` estiver definida, será usada como `Bearer <API_KEY>`.
- Se **não** houver `METRO_LISBOA_API_KEY`, o sistema tenta obter um token via OAuth2 com:
  - `METRO_LISBOA_CLIENT_ID`
  - `METRO_LISBOA_CLIENT_SECRET`

### 3.2. Dependências externas

- **Metro Lisboa**
  - Host: `https://api.metrolisboa.pt:8243`
  - Base do serviço de estado: `/estadoServicoML/1.0.1`
  - Endpoints específicos (ver secção 7).

- **Metro do Porto**
  - Usa o OTP já em uso para planeamento de rotas (`routes`).
  - Endpoint GraphQL:
    - `${OTP_BASE_URL}/index/graphql`, por exemplo:
    - `http://localhost:8080/otp/index/graphql`

---

## 4. Modelo de dados (DTOs)

### 4.1. DTOs Metro Lisboa

Ficheiro: `src/metro/dto/metro.dto.ts`

```ts
export type MetroLineId = 'amarela' | 'azul' | 'verde' | 'vermelha';

export interface MetroLineStatusSummaryDto {
  amarela: string;
  azul: string;
  verde: string;
  vermelha: string;
  tipo_msg_am: string;
  tipo_msg_az: string;
  tipo_msg_vd: string;
  tipo_msg_vm: string;
  amarela_curta: string;
  azul_curta: string;
  verde_curta: string;
  vermelha_curta: string;
}

export interface MetroStationInfoDto {
  stop_id: string;
  stop_name: string;
  stop_lat: string;
  stop_lon: string;
  stop_url?: string;
  linha?: string;
  zone_id?: string;
}

export interface MetroWaitingTimeDto {
  stop_id: string;
  cais: string;
  hora: string;
  comboio: string;
  tempoChegada1: string;
  comboio2?: string;
  tempoChegada2?: string;
  comboio3?: string;
  tempoChegada3?: string;
  destino: string;
  sairServico: string;
  UT?: string;
}

export interface MetroDestinationDto {
  id_destino: string;
  nome_destino: string;
}

export interface MetroIntervalDto {
  Linha: string;
  HoraInicio: string;
  HoraFim: string;
  Intervalo: string;
  UT: number;
  Dia?: string;
}
```

### 4.2. DTOs Metro do Porto (OTP)

Ficheiro: `src/metro/dto/metro-porto.dto.ts`

```ts
export interface MetroPortoAgencyDto {
  id: string;
  name: string;
  url?: string;
  timezone?: string;
  lang?: string;
  phone?: string;
}

export interface MetroPortoRouteDto {
  id: string;
  shortName?: string;
  longName?: string;
  mode?: string;
  color?: string;
  textColor?: string;
  agency?: MetroPortoAgencyDto;
}

export interface MetroPortoStopDto {
  id: string;
  code?: string;
  name: string;
  desc?: string;
  lat: number;
  lon: number;
  zoneId?: string;
  url?: string;
  parentStation?: string;
}

export interface MetroPortoStopTimeDto {
  stopId: string;
  stopName: string;
  serviceDay: number;
  scheduledDeparture: number;
  realtimeDeparture: number;
  departureDelay: number;
  stopHeadsign?: string;
  tripHeadsign?: string;
  routeId?: string;
  tripId?: string;
  directionId?: string;
}

export interface MetroPortoUpcomingDepartureDto {
  stop: MetroPortoStopDto;
  route: MetroPortoRouteDto;
  stopTime: MetroPortoStopTimeDto;
}
```

Re-export em `src/metro/dto/index.ts`:

```ts
export * from './metro.dto';
export * from './metro-porto.dto';
```

---

## 5. Serviços

### 5.1. MetroService (Lisboa)

Ficheiro: `src/metro/metro.service.ts`

Responsável por:

- Comunicar com a API oficial do Metro de Lisboa.
- Usar `MetroTokenService` ou `METRO_LISBOA_API_KEY` para obter um token Bearer.
- Converter a resposta JSON no formato de DTOs usados internamente.

Método interno principal:

```ts
private async callMetroApi<T>(path: string): Promise<T>
```

- Recebe apenas o **path relativo**, ex.: `/estadoLinha/todos`.
- Aplica o header `Authorization: Bearer <token>`.
- Lança `BadGatewayException` em caso de:
  - Erro de rede / timeout.
  - Erro da API (4xx/5xx).
- Faz logging via `Logger`.

Métodos públicos principais:

- `getAllStationWaitingTimes(): Promise<MetroWaitingTimeDto[]>`
- `getStationWaitingTimes(stationId: string): Promise<MetroWaitingTimeDto[]>`
- `getLineWaitingTimes(lineId: string): Promise<MetroWaitingTimeDto[]>`
- `getStationInfo(stationId: string): Promise<MetroStationInfoDto[]>`
- `getAllStationsInfo(): Promise<MetroStationInfoDto[]>`
- `getAllLineStatus(): Promise<MetroLineStatusSummaryDto>`
- `getLineStatus(lineId: string): Promise<Partial<MetroLineStatusSummaryDto>>`
- `getDestinations(): Promise<MetroDestinationDto[]>`
- `getIntervalsByLine(lineId: string, directionCode: string, serviceCode?: string): Promise<MetroIntervalDto | MetroIntervalDto[]>`

---

### 5.2. MetroTokenService (Lisboa)

Ficheiro: `src/metro/metro-token.service.ts`

Responsável por:

- Obter tokens OAuth2 (`/token` com `grant_type=client_credentials`).
- Fazer **cache** do token até expirar (`expires_in`).
- Só é usado se **não** existir `METRO_LISBOA_API_KEY`.

Interface principal:

```ts
async getAccessToken(): Promise<string>
```

Comportamento:

- Se `METRO_LISBOA_CLIENT_ID` ou `METRO_LISBOA_CLIENT_SECRET` não estiverem configurados → `BadGatewayException`.
- Reutiliza token em memória até ~60s antes da expiração.
- Em caso de erro na chamada ao endpoint `/token`, faz logging e lança `BadGatewayException('Unable to authenticate with Metro API')`.

---

### 5.3. MetroPortoService (Porto / OTP)

Ficheiro: `src/metro/metro-porto.service.ts`

Responsável por:

- Comunicar com o **endpoint GraphQL do OTP**:
  - `POST {OTP_BASE_URL}/index/graphql`
- Construir queries GraphQL para:
  - Agências (`agencies`).
  - Routes (`routes`, `node(id) { ... on Route ... }`).
  - Stops (`stops`, `node(id) { ... on Stop ... }`).
  - Stops por route (`patterns.stops`).
  - Stoptimes (`stoptimesForPatterns`).

Método auxiliar interno:

```ts
private async graphqlRequest<TData>(
  query: string,
  variables?: Record<string, any>,
): Promise<TData>
```

- Envia a query e variáveis.
- Se `errors[]` no GraphQL → log + `BadGatewayException`.
- Se `data` for `null/undefined` → `BadGatewayException`.
- Em erro de rede → log e `BadGatewayException('Falha ao comunicar com o serviço OTP (GraphQL)')`.

Métodos públicos principais:

- `getAgencyInfo(): Promise<MetroPortoAgencyDto | null>`
- `getRoutes(): Promise<MetroPortoRouteDto[]>`
- `getRoute(routeId: string): Promise<MetroPortoRouteDto | null>`
- `getStops(): Promise<MetroPortoStopDto[]>`
- `getStop(stopId: string): Promise<MetroPortoStopDto | null>`
- `getStopsByRoute(routeId: string): Promise<MetroPortoStopDto[]>`
- `getUpcomingDeparturesByStop(stopId: string, limit = 10): Promise<MetroPortoUpcomingDepartureDto[]>`

Notas importantes:

- **IDs de paragens e rotas** são os **IDs internos do OTP**, por exemplo:
  - `stop.id = "U3RvcDoxOjAxMDAwMQ"`
  - `route.id = "Um91dGU6MQ"`
- Esses IDs são usados nos endpoints `:stopId` e `:routeId`.

---

## 6. Controller e rotas HTTP

Ficheiro: `src/metro/metro.controller.ts`

Responsável por expor endpoints REST sobre os serviços `MetroService` (Lisboa) e `MetroPortoService` (Porto).

Prefixo global: `@Controller('metro')`.

Dividido logicamente em dois grupos:

- **Metro de Lisboa**:
  - `/metro/waiting-times/...`
  - `/metro/stations...`
  - `/metro/lines...`
  - `/metro/destinations`
  - `/metro/intervals/...`

- **Metro do Porto**:
  - `/metro/porto/...`

Não há autenticação nestes endpoints (dados públicos).

---

## 7. Referência de endpoints – Metro Lisboa

Base: `http://localhost:3000`

### 7.1. Tempos de espera – todas as estações

**Endpoint**

```http
GET /metro/waiting-times/stations
```

**Descrição**

Devolve tempos de espera em todas as estações do Metro de Lisboa.

**Resposta**

Array de `MetroWaitingTimeDto`.

---

### 7.2. Tempos de espera – estação específica

**Endpoint**

```http
GET /metro/waiting-times/stations/:stationId
```

**Parâmetros**

- `stationId` – ID da estação conforme API do Metro (ex.: `COL`, `TEL`, etc.).

**Descrição**

Devolve tempos de espera apenas na estação indicada.

---

### 7.3. Tempos de espera – linha específica

**Endpoint**

```http
GET /metro/waiting-times/lines/:lineId
```

**Parâmetros**

- `lineId`: `amarela | azul | verde | vermelha`

**Descrição**

Tempos de espera nas estações dessa linha.

---

### 7.4. Informação de todas as estações

**Endpoint**

```http
GET /metro/stations
```

**Descrição**

Lista de estações com coordenadas, nomes, linha, etc.

**Resposta**

Array de `MetroStationInfoDto`.

---

### 7.5. Informação de uma estação

**Endpoint**

```http
GET /metro/stations/:stationId
```

**Descrição**

Detalhes de uma estação específica.

---

### 7.6. Estado de todas as linhas

**Endpoint**

```http
GET /metro/lines/status
```

**Descrição**

Estado de operação de todas as linhas (mensagem longa, curta, etc.).

**Resposta**

`MetroLineStatusSummaryDto`.

---

### 7.7. Estado de uma linha

**Endpoint**

```http
GET /metro/lines/:lineId/status
```

**Parâmetros**

- `lineId`: `amarela | azul | verde | vermelha`

**Descrição**

Estado da linha seleccionada.

---

### 7.8. Destinos

**Endpoint**

```http
GET /metro/destinations
```

**Descrição**

Lista de destinos possíveis (texto usado na sinalética, etc.).

**Resposta**

Array de `MetroDestinationDto`.

---

### 7.9. Intervalos por linha e direcção

**Endpoint**

```http
GET /metro/intervals/:lineId/:direction
```

**Parâmetros de rota**

- `lineId`: `amarela | azul | verde | vermelha`
- `direction`: código da direcção (ex.: `1` ou `2` – depende da API)

**Query params**

- `serviceCode` (opcional) – código de serviço (ex.: `U`).

**Exemplo**

```http
GET /metro/intervals/amarela/1?serviceCode=U
```

---

## 8. Referência de endpoints – Metro do Porto

Base: `http://localhost:3000`

Todos os endpoints abaixo usam o grafo do OTP via GraphQL.

### 8.1. Agência Metro do Porto

**Endpoint**

```http
GET /metro/porto/agency
```

**Descrição**

Devolve a agência que corresponde ao Metro do Porto (filtrada a partir da lista de `agencies` do OTP).

**Resposta**

`MetroPortoAgencyDto | null`.

---

### 8.2. Listar linhas (routes)

**Endpoint**

```http
GET /metro/porto/routes
```

**Descrição**

Lista todas as rotas (linhas) presentes no grafo OTP que pertencem ao Metro do Porto.

**Resposta**

Array de `MetroPortoRouteDto`.

---

### 8.3. Detalhe de uma linha (route)

**Endpoint**

```http
GET /metro/porto/routes/:routeId
```

**Parâmetros**

- `routeId` – ID OTP da rota (ex.: `Um91dGU6MQ`).

**Descrição**

Devolve detalhes da rota específica.

---

### 8.4. Listar todas as paragens (stops)

**Endpoint**

```http
GET /metro/porto/stops
```

**Descrição**

Lista completa de paragens conhecidas pelo OTP (pode incluir mais do que apenas Metro, dependendo do grafo carregado).

**Resposta**

Array de `MetroPortoStopDto`.

---

### 8.5. Detalhe de uma paragem

**Endpoint**

```http
GET /metro/porto/stops/:stopId
```

**Parâmetros**

- `stopId` – **ID OTP** da paragem (campo `id` devolvido por `/metro/porto/stops`), por exemplo: `U3RvcDoxOjAxMDAwMQ`.

> **Importante:**  
> O `stop_id` aqui **não é** o código numérico (ex.: `010001`), mas sim o ID interno do OTP (`id`).

---

### 8.6. Paragens de uma linha (routeId)

**Endpoint**

```http
GET /metro/porto/routes/:routeId/stops
```

**Parâmetros**

- `routeId` – ID OTP da rota.

**Descrição**

Devolve todas as paragens associadas àquela rota.
Se existirem paragens repetidas em múltiplos padrões, são deduplicadas.

---

### 8.7. Próximas partidas numa paragem

**Endpoint**

```http
GET /metro/porto/stops/:stopId/departures
```

**Parâmetros de rota**

- `stopId` – ID OTP da paragem.

**Query params**

- `limit` (opcional, default: `10`) – número máximo de partidas a devolver.

**Descrição**

- Junta:
  - Informação da paragem (`stop`).
  - Informação da rota (`route`).
  - Informação das horas (`stopTime`).
- Ordena os resultados por hora efectiva (`serviceDay + realtimeDeparture`).

---

## 9. Testes com Postman

### 9.1. Setup básico

- **Base URL**: `http://localhost:3000`
- Certificar que:
  - Backend NestJS está a correr.
  - OTP está up em `OTP_BASE_URL`.
  - Para Lisboa, tens credenciais válidas (API key ou OAuth).

### 9.2. Exemplos de chamadas

#### Metro Lisboa

1. **Estado de todas as linhas**

   - Method: `GET`
   - URL: `http://localhost:3000/metro/lines/status`

2. **Tempos de espera numa estação**

   - Method: `GET`
   - URL: `http://localhost:3000/metro/waiting-times/stations/TEL`

3. **Informação de estações**

   - Method: `GET`
   - URL: `http://localhost:3000/metro/stations`

4. **Intervalos linha amarela, direcção 1**

   - Method: `GET`
   - URL: `http://localhost:3000/metro/intervals/amarela/1?serviceCode=U`

#### Metro do Porto

1. **Listar rotas do Metro do Porto**

   - Method: `GET`
   - URL: `http://localhost:3000/metro/porto/routes`

2. **Listar paragens**

   - Method: `GET`
   - URL: `http://localhost:3000/metro/porto/stops`

3. **Testar detalhe de uma paragem**

   - Pegar num `id` do passo anterior (ex.: `"U3RvcDoxOjAxMDAwMQ"`).
   - Method: `GET`
   - URL: `http://localhost:3000/metro/porto/stops/U3RvcDoxOjAxMDAwMQ`

4. **Testar partidas próximas**

   - Method: `GET`
   - URL: `http://localhost:3000/metro/porto/stops/U3RvcDoxOjAxMDAwMQ/departures?limit=5`

5. **Testar paragens de uma rota**

   - Pegar num routeId de `/metro/porto/routes` (ex.: `Um91dGU6MQ`).
   - Method: `GET`
   - URL: `http://localhost:3000/metro/porto/routes/Um91dGU6MQ/stops`

---

## 10. Tratamento de erros e logging

### 10.1. Metro Lisboa

- Em caso de falha na API (rede, timeout, erro HTTP ≠ 2xx):
  - `MetroService` faz logging com `Logger(MetroService.name)`.
  - Lança `BadGatewayException('Failed to reach Metro Lisboa API')`.
- Em caso de falha na autenticação OAuth:
  - `MetroTokenService` lança `BadGatewayException('Unable to authenticate with Metro API')`.

### 10.2. Metro do Porto (OTP)

- Erros do GraphQL (campo `errors` na resposta):
  - São logados e é lançada `BadGatewayException('OTP devolveu um erro no GraphQL')`.
- Falhas de rede/HTTP:
  - São logadas com o stack trace.
  - Lança `BadGatewayException('Falha ao comunicar com o serviço OTP (GraphQL)')`.

---

## 11. Integração com outras partes do sistema

### 11.1. Integração com a app móvel / frontend

- Metro Lisboa:
  - Usar `GET /metro/stations` para mostrar estações no mapa.
  - Quando o utilizador selecciona uma estação:
    - Chamar `GET /metro/waiting-times/stations/:stationId` e mostrar tempos de espera por cais.
  - Página de estado de rede:
    - Chamar `GET /metro/lines/status`.

- Metro do Porto:
  - Usar `GET /metro/porto/routes` para listar linhas.
  - Usar `GET /metro/porto/stops` para obter paragens e associá-las a layers no mapa (podem ser filtradas).
  - Ao clicar numa paragem:
    - Chamar `GET /metro/porto/stops/:stopId/departures?limit=5` para mostrar próximas partidas.

### 11.2. Integração futura com histórico / eco

- Não há, neste módulo, persistência directa para a base de dados (Prisma).  
- Os dados podem ser usados por outros módulos para:
  - Construir históricos de viagens (quando o user selecciona uma saída específica).
  - Calcular métricas ecológicas (quando cruzado com fatores de emissão, distâncias, etc).

---

## 12. Possíveis extensões futuras

Algumas ideias para evoluir o módulo:

1. **Cache de respostas**
   - Implementar caching (por exemplo, em memória ou Redis) para endpoints mais estáticos:
     - `GET /metro/stations`
     - `GET /metro/destinations`
     - `GET /metro/porto/routes`
     - `GET /metro/porto/stops`

2. **Normalização de modos**
   - Mapear modos OTP (`mode`) para o enum `TransportMode` já existente no domínio da aplicação.

3. **Filtros adicionais no Metro do Porto**
   - Filtrar, do lado do backend, apenas rotas/paragens efectivamente pertencentes ao Metro do Porto, se o grafo tiver outros operadores.

4. **Integração directa com o módulo de rotas**
   - Usar informação do Metro (esperas + serviços reais) como input para optimizações de planeamento multimodal.

5. **Autenticação opcional**
   - Possibilidade de proteger estes endpoints com JWT em contextos B2B, mantendo-os públicos para app do utilizador final.

---

Com este módulo, a aplicação passa a ter uma abstração consistente para **dois sistemas de metro distintos (Lisboa e Porto)**, recorrendo às fontes oficiais/OTP, com uma interface REST uniforme e pronta a ser consumida pelo frontend ou por outros serviços internos.
