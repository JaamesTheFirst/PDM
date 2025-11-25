import { Test, TestingModule } from '@nestjs/testing';
import { GbfsService } from './gbfs.service';

describe('GbfsService', () => {
  let service: GbfsService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [GbfsService],
    }).compile();

    service = module.get<GbfsService>(GbfsService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });
});
