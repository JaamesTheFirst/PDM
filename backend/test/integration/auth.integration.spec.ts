import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../../src/app.module';

describe('Auth Integration (e2e)', () => {
  let app: INestApplication;

  beforeEach(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  describe('/auth/signup (POST)', () => {
    it('should create a new user', () => {
      return request(app.getHttpServer())
        .post('/auth/signup')
        .send({
          email: 'test@example.com',
          password: 'Test123!@#',
          name: 'Test User',
        })
        .expect(201)
        .expect(res => {
          expect(res.body).toHaveProperty('user');
          expect(res.body.user).toHaveProperty('email', 'test@example.com');
        });
    });

    it('should reject invalid email', () => {
      return request(app.getHttpServer())
        .post('/auth/signup')
        .send({
          email: 'invalid-email',
          password: 'Test123!@#',
          name: 'Test User',
        })
        .expect(400);
    });
  });

  describe('/auth/login (POST)', () => {
    it('should login with valid credentials', async () => {
      // First create a user
      await request(app.getHttpServer()).post('/auth/signup').send({
        email: 'login@example.com',
        password: 'Test123!@#',
        name: 'Test User',
      });

      // Then login
      return request(app.getHttpServer())
        .post('/auth/login')
        .send({
          email: 'login@example.com',
          password: 'Test123!@#',
        })
        .expect(200)
        .expect(res => {
          expect(res.body).toHaveProperty('access_token');
        });
    });

    it('should reject invalid credentials', () => {
      return request(app.getHttpServer())
        .post('/auth/login')
        .send({
          email: 'login@example.com',
          password: 'WrongPassword',
        })
        .expect(401);
    });
  });
});
