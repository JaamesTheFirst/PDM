export type JwtPayload = {
  sub: string;
  email: string;
  username: string;
  iat?: number;
  exp?: number;
};
