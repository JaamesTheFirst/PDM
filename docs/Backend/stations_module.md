## 1. Objectivo do Módulo

O módulo **Stations** gere as estações/paragens/hubs usados pela aplicação: operações de criação, leitura, actualização e eliminação.

Funcionalidades principais:
- CRUD de estações.
- Listagens filtráveis por `city`, `type` (normalizado) e `bbox`.
- Normalização de `stationType` a partir de aliases curtos (ex.: `BIKE`, `BUS`).

Integra com:
- `Auth` (JWT) para endpoints protegidos.
- `PrismaService` para persistência.

---

## 2. Endpoints (resumo)

Base: `/stations`

- `POST /stations` (protegido)
  - Cria uma estação. `externalId` é opcional e único.
  - Respostas: `201 Created`, `409 Conflict` (duplicado), `400 Bad Request`.

- `GET /stations`
  - Lista estações. Query params: `limit`, `offset`, `type`, `city`, `bbox`.
  - Resposta: `200 OK` com array de estações.

- `GET /stations/:id`
  - Obter detalhes de uma estação.
  - Resposta: `200 OK` ou `404 Not Found`.

- `PATCH /stations/:id` (protegido)
  - Actualização parcial.
  - Resposta: `200 OK` com objecto actualizado.

- `DELETE /stations/:id` (protegido)
  - Elimina uma estação. Idempotente — devolve `204 No Content` mesmo se o recurso já não existir.

---

## 3. Principais regras e comportamento

- `stationType` aceita aliases curtos e é normalizado internamente para os valores do enum do Prisma (`BIKE` → `BIKE_STATION`, etc.).
- `externalId` é único no banco; tentativas de criar duplicado resultam em `409 Conflict`.
- `GET /stations` devolve um array; a paginação usa `limit`/`offset`.

---

## 4. Onde está o código

- `backend/src/stations/stations.controller.ts`
- `backend/src/stations/stations.service.ts` (normalização de `stationType`)
- `backend/src/stations/dto/create-station.dto.ts`
- `backend/src/stations/dto/update-station.dto.ts`
- `backend/prisma/schema.prisma`

---

## 5. Como testar no Postman — exemplos práticos

Nota: abaixo tens exemplos mínimos de request/response para copiar ao Postman. Ajusta `host`/`ports` conforme o teu ambiente.

1) Login — obter token

- Request: `POST http://localhost:3000/auth/login`
- Headers: `Content-Type: application/json`
- Body (JSON):

```json
{
  "identifier": "tester@example.com",
  "password": "Pa$$w0rd"
}
```

- Response (200):

```json
{
  "access_token": "eyJ...",
  "token_type": "bearer",
  "expires_in": 3600
}
```

2) Criar estação — `POST /stations`

- Request: `POST http://localhost:3000/stations`
- Headers: `Content-Type: application/json`, `Authorization: Bearer <TOKEN>`
- Body (exemplo mínimo):

```json
{
  "externalId": "ST_TEST_001",
  "name": "Praça Teste",
  "latitude": 38.7223,
  "longitude": -9.1393,
  "city": "Lisboa",
  "stationType": "BIKE",
  "capacity": 10
}
```

- Response (201 Created):

```json
{
  "id": "cl6xyz...",
  "externalId": "ST_TEST_001",
  "name": "Praça Teste",
  "latitude": 38.7223,
  "longitude": -9.1393,
  "city": "Lisboa",
  "stationType": "BIKE_STATION",
  "capacity": 10,
  "createdAt": "2025-11-27T12:34:56.789Z"
}
```

Erro comum: criar com `externalId` já existente → `409 Conflict` com mensagem `Unique constraint failed`.

3) Listar estações — `GET /stations`

- Request: `GET http://localhost:3000/stations?limit=10&offset=0`
- Headers: `Authorization: Bearer <TOKEN>` (se necessário)

- Response (200):

```json
[
  {
    "id": "cl6xyz...",
    "externalId": "ST_TEST_001",
    "name": "Praça Teste",
    "latitude": 38.7223,
    "longitude": -9.1393,
    "city": "Lisboa",
    "stationType": "BIKE_STATION",
    "capacity": 10
  }
]
```

4) Obter por id — `GET /stations/:id`

- Request: `GET http://localhost:3000/stations/{id}`
- Response (200): objecto da estação (mesmos campos do create).

5) Atualizar (parcial) — `PATCH /stations/:id`

- Request: `PATCH http://localhost:3000/stations/{id}`
- Headers: `Content-Type: application/json`, `Authorization: Bearer <TOKEN>`
- Body (exemplo):

```json
{ "name": "Praça Teste (updated)", "capacity": 12 }
```

- Response (200): objecto actualizado.

6) Apagar — `DELETE /stations/:id`

- Request: `DELETE http://localhost:3000/stations/{id}`
- Headers: `Authorization: Bearer <TOKEN>`
- Response: `204 No Content` (body vazio). Repetir o DELETE deve continuar a devolver `204` (idempotente).

---

## 6. Erros importantes (resumido)

- `400 Bad Request` — payload inválido.
- `401 Unauthorized` — token ausente/ inválido.
- `404 Not Found` — recurso não existe.
- `409 Conflict` — tentativa de criar com `externalId` duplicado.

---

## 7. Próximos passos recomendados

- Gerar `postman_collection.json` com as requests base (login + stations) para importação no Postman.
- Adicionar testes unitários/e2e para `StationsService`.

Arquivo actualizado: `docs/stations_module.md`.

---