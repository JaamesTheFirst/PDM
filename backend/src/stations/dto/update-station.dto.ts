import { IsString, IsOptional, IsNumber, IsInt, Min } from 'class-validator';
import { StationType } from '@prisma/client';

export class UpdateStationDto {
	@IsOptional()
	@IsString()
	name?: string;

	@IsOptional()
	@IsString()
	description?: string;

	@IsOptional()
	@IsNumber()
	latitude?: number;

	@IsOptional()
	@IsNumber()
	longitude?: number;

	@IsOptional()
	@IsString()
	address?: string;

	@IsOptional()
	@IsString()
	city?: string;

	@IsOptional()
	@IsString()
	country?: string;

	@IsOptional()
	@IsString()
	externalId?: string;

	@IsOptional()
	// Accept alias or full enum value as string; will be normalised in the service.
	@IsString()
	stationType?: string;

	@IsOptional()
	@IsInt()
	@Min(0)
	capacity?: number;

	@IsOptional()
	@IsInt()
	@Min(0)
	availableVehicles?: number;

	@IsOptional()
	@IsInt()
	@Min(0)
	availableDocks?: number;
}
