## 1. Objectivo do Módulo

O módulo **Users** trata:

* Registo e autenticação de utilizadores.
* Gestão de dados de perfil (username, nome próprio, apelido, email, password).
* Gestão das preferências de mobilidade (`UserPreferences`).
* Endpoints protegidos com JWT.

Integra com:

* Módulo **Auth** (login/register/JWT).
* **PrismaService** para persistência.

---

## 2. Endpoints

### Base: `/auth` e `/users`

### 2.1. **Auth**

#### `POST /auth/register`

Registra um utilizador.

```json
{
  "email": "teste@example.com",
  "password": "supersecret",
  "username": "testuser",
  "firstName": "Teste",
  "lastName": "User"
}
```

Resposta: `{ "access_token": "..." }`

---

#### `POST /auth/login`

Login com email ou username.

```json
{ "identifier": "teste@example.com", "password": "supersecret" }
```

---

#### `GET /auth/me` (protegido)

Devolve payload do JWT.

---

### 2.2. **Users**

#### `GET /users/me` (protegido)

Devolve dados do utilizador autenticado.

#### `PATCH /users/me` (protegido)

Atualiza perfil.
Exemplo:

```json
{ "username": "novoUser", "firstName": "Jo", "lastName": "Silva" }
```

#### `GET /users/me/preferences` (protegido)

Obtém `UserPreferences`.

#### `PATCH /users/me/preferences` (protegido)

Upsert das preferências.

```json
{
  "preferredTransportModes": ["WALKING", "BIKE", "BUS"],
  "maxWalkingDistance": 700,
  "avoidHighways": true,
  "ecoFriendlyOnly": true
}
```

---

## 3. Modelos Prisma

### 3.1. **User**

```prisma
model User {
  id        String   @id @default(cuid())
  email     String   @unique
  username  String   @unique
  password  String
  firstName String?
  lastName  String?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  preferences   UserPreferences?
}
```

### 3.2. **UserPreferences**

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

### `CreateUserDto`

* email: IsEmail
* password: MinLength(6)
* username: MinLength(3), MaxLength(30)
* firstName / lastName opcionais

### `UpdatePreferencesDto`

* preferredTransportModes?: string[]
* maxWalkingDistance?: number
* avoidHighways?: boolean
* ecoFriendlyOnly?: boolean

---

## 5. Serviço — `UsersService`

Responsabilidades principais:

* Criar utilizador com validação de unicidade + hashing da password.
* Atualizar utilizador (incluindo hashing de nova password).
* Obter dados do utilizador sem password.
* Upsert de preferências.
* Erros devolvidos como `BadRequestException` ou `InternalServerErrorException` conforme o caso.

---

## 6. Controlador — `UsersController`

* Endpoints protegidos com `JwtAuthGuard`.
* Extrai de forma robusta o `userId` do JWT.
* Usa DTOs para validar inputs.

---

## 7. Guia de Testes no Postman

Assumindo API a correr em `http://localhost:3000`.

### 7.1. **Registar**

`POST http://localhost:3000/auth/register`

Body:

```json
{
  "email": "teste@example.com",
  "password": "supersecret",
  "username": "testuser",
  "firstName": "Teste",
  "lastName": "User"
}
```

### 7.2. **Login**

`POST http://localhost:3000/auth/login`

```json
{ "identifier": "teste@example.com", "password": "supersecret" }
```

Guardar token JWT.

### 7.3. **GET /users/me**

Header: `Authorization: Bearer <token>`

### 7.4. **PATCH /users/me**

```json
{ "username": "novoUser", "firstName": "Jo" }
```

### 7.5. **GET /users/me/preferences**

Authorization obrigatório.

### 7.6. **PATCH /users/me/preferences**

```json
{
  "preferredTransportModes": ["WALKING", "BIKE"],
  "maxWalkingDistance": 700
}
```

---

## 8. Ficheiros Relacionados

* `src/users/dto/create-user.dto.ts`
* `src/users/dto/update-preferences.dto.ts`
* `src/users/users.service.ts`
* `src/users/users.controller.ts`

---

## 9. Próximos Passos

* Criar DTOs de resposta consistentes.
* Adicionar testes unitários e e2e.
* Melhorar mensagens de erro e logging.