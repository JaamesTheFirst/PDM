import { Test, TestingModule } from '@nestjs/testing';
import { GbfsController } from './gbfs.controller';

describe('GbfsController', () => {
  let controller: GbfsController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [GbfsController],
    }).compile();

    controller = module.get<GbfsController>(GbfsController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });
});
