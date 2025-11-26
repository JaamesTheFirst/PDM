## 1. Objectivo do Módulo

O módulo **Users Preferences** trata da persistência e lógica das preferências de mobilidade associadas a um utilizador.

Funcionalidades:
- Obter preferências de um utilizador autenticado.
- Upsert (criar/actualizar) preferências do utilizador.

Integra com:
- `Auth` (JWT) para identificar o utilizador.
- `PrismaService` para persistência.

---

## 2. Endpoints

Base: `/users`

### `GET /users/me/preferences` (protegido)
- Descrição: devolve o registo `UserPreferences` do utilizador autenticado ou `null` se não existir.

### `PATCH /users/me/preferences` (protegido)
- Descrição: upsert das preferências do utilizador.
- Body exemplo:

```json
{
  "preferredTransportModes": ["WALKING", "BIKE", "BUS"],
  "maxWalkingDistance": 700,
  "avoidHighways": true,
  "ecoFriendlyOnly": true
}
```

Resposta: objecto `UserPreferences` com `createdAt` e `updatedAt`.

---

## 3. Modelos Prisma

Este módulo usa o modelo `UserPreferences` definido no `schema.prisma` (nenhuma alteração foi necessária):

```prisma
model UserPreferences {
  id       String @id @default(cuid())
  userId   String @unique
  user     User   @relation(fields: [userId], references: [id], onDelete: Cascade)

  preferredTransportModes TransportMode[]
  maxWalkingDistance      Int      @default(500)
  avoidHighways           Boolean  @default(false)
  ecoFriendlyOnly         Boolean  @default(true)

  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}
```

---

## 4. DTOs e Validação

### `UpdatePreferencesDto`
- `preferredTransportModes?: string[]` (IsArray, IsString each)
- `maxWalkingDistance?: number` (IsInt)
- `avoidHighways?: boolean` (IsBoolean)
- `ecoFriendlyOnly?: boolean` (IsBoolean)

Validações existentes usam `class-validator` e são aplicadas automaticamente no controller.

---

## 5. Serviço — `UsersPreferencesService`

Responsabilidades:
- Mapear o DTO para a forma esperada pelo Prisma (arrays como `{ set: [...] }`).
- Executar `upsert` para criar/actualizar as preferências (ligando o `user` no create).
- Tratar erros e devolver mensagens úteis.

Assinaturas principais:
- `getPreferences(userId: string)`
- `updatePreferences(userId: string, prefs: UpdatePreferencesDto)`

Notas de implementação:
- O `updatePreferences` usa `prisma.userPreferences.upsert({ where: { userId }, update: {...}, create: { user: { connect: { id: userId } }, ... } })`.

---

## 6. Controlador

Os endpoints continuam em `UsersController` (`backend/src/users/users.controller.ts`) e estão protegidos por `JwtAuthGuard`.

Comportamento do controller:
- Extrai `userId` do payload JWT de forma defensiva (`req.user?.id ?? req.user?.sub ?? req.user?.userId`).
- Delegam para `UsersService`, que por sua vez injeta e usa `UsersPreferencesService`.

---

## 7. Guia de Testes no Postman (rápido)

1. `POST /auth/login` → obtém `{ "access_token": "<TOKEN>" }`.
2. `GET /users/me/preferences` com header `Authorization: Bearer <TOKEN>` — guarda `updatedAt`.
3. `PATCH /users/me/preferences` com body de exemplo (ver secção 2).
4. `GET /users/me/preferences` novamente — verificar `preferredTransportModes` e `updatedAt` (deve ser posterior).

Snippet de teste (opcional) — `PATCH` Tests:

```javascript
const res = pm.response.json();
pm.test('preferredTransportModes contains WALKING', () => pm.expect(res.preferredTransportModes).to.include('WALKING'));
pm.collectionVariables.set('prefs_after_updatedAt', res.updatedAt);
```

---

## 8. Ficheiros Relacionados

- `backend/src/users/preferences/users-preferences.service.ts` (NOVO)
- `backend/src/users/users.service.ts` (actualizado para delegar)
- `backend/src/users/users.module.ts` (providers atualizados)
- `backend/src/users/users.controller.ts` (endpoints existentes)
- `docs/users_preferences_test_guide.txt` (guia rápido)

---

## 9. Próximos Passos

- Executar `npx tsc --noEmit` para quick sanity check.
- Adicionar testes unitários para `UsersPreferencesService`.
- (Opcional) Extrair um `UsersPreferencesController` se preferires separar as rotas num módulo próprio.
- Commit & PR quando estiveres pronto.
