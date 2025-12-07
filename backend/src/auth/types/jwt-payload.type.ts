/**
 * Estrutura do payload JWT usado pela aplicação.
 *
 * - `sub`  → ID do utilizador (subject)
 * - `email` → email do utilizador
 * - `username` → username público
 * - `iat` → "issued at" (timestamp, set pelo JWT)
 * - `exp` → "expires at" (timestamp, set pelo JWT)
 */
export type JwtPayload = {
  sub: string;
  email: string;
  username: string;
  iat?: number;
  exp?: number;
};
