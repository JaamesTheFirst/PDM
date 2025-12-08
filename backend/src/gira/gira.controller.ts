// src/gira/gira.controller.ts
import {
  Body,
  Controller,
  DefaultValuePipe,
  Get,
  ParseIntPipe,
  Post,
  Query,
} from '@nestjs/common';
import { GiraService } from './gira.service';

/**
 * Controller para endpoints relacionados com dados GIRA
 * (estações carregadas a partir de ficheiro para a tabela `gira_stations`).
 *
 * Nota: isto é *dados brutos* da GIRA, não o feed GBFS.
 */
@Controller('gira')
export class GiraController {
  constructor(private readonly giraService: GiraService) {}

  /**
   * Devolve uma lista paginada de estações GIRA vindas da BD.
   *
   * GET /gira/stations?limit=100&offset=0
   *
   * @param limit  Número máximo de registos a devolver (default: 100)
   * @param offset Offset para paginação (default: 0)
   */
  @Get('stations')
  async getStations(
    @Query('limit', new DefaultValuePipe(100), ParseIntPipe) limit: number,
    @Query('offset', new DefaultValuePipe(0), ParseIntPipe) offset: number,
  ) {
    const { total, slice } = await this.giraService.getStationsSlice(
      limit,
      offset,
    );

    return {
      total,
      limit,
      offset,
      records: slice,
    };
  }

  /**
   * Pesquisa simples de estações GIRA por campo+valor.
   *
   * GET /gira/stations/search?field=name&value=Alvalade
   *
   * Campos suportados (ver `GiraService.searchStations`):
   *  - name
   *  - externalId
   *  - address
   *  - parish
   */
  @Get('stations/search')
  async searchStations(
    @Query('field') field: string,
    @Query('value') value: string,
  ) {
    const records = await this.giraService.searchStations(field, value);
    return {
      count: records.length,
      records,
    };
  }

  /**
   * Força o reload do ficheiro de estações GIRA para a BD.
   *
   * POST /gira/stations/reload
   * Body opcional: `{ "filePath": "/caminho/para/ficheiro.xlsx" }`
   *
   * Se `filePath` não for fornecido, usa `GIRA_STATIONS_FILE` do .env.
   */
  @Post('stations/reload')
  async reloadStations(@Body('filePath') filePath?: string) {
    await this.giraService.loadStationsFromFile(filePath);
    return { message: 'GIRA station data reloaded successfully' };
  }
}
