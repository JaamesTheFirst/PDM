import {
  Controller,
  Get,
  Patch,
  Body,
  Req,
  UseGuards,
} from '@nestjs/common';
import { UnauthorizedException } from '@nestjs/common';
import { UsersService } from './users.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { UpdateUserDto } from './dto/update-user.dto';
import { UpdatePreferencesDto } from './dto/update-preferences.dto';

@UseGuards(JwtAuthGuard)
@Controller('users')
export class UsersController {
  constructor(private usersService: UsersService) {}

  // GET /users/me
  @Get('me')
  getMe(@Req() req) {
    // aceitar várias formas de claim: id, sub, userId
    const userId = req.user?.id ?? req.user?.sub ?? req.user?.userId;
    if (!userId) throw new UnauthorizedException('No user id in JWT payload');

    return this.usersService.findById(userId);
  }

  // PATCH /users/me
  @Patch('me')
  updateMe(@Req() req, @Body() dto: UpdateUserDto) {
    const userId = req.user?.id ?? req.user?.sub ?? req.user?.userId;
    if (!userId) throw new UnauthorizedException('No user id in JWT payload');
    return this.usersService.updateUser(userId, dto);
  }


  // GET /users/me/preferences
  @Get('me/preferences')
  getPreferences(@Req() req) {
    const userId = req.user?.id ?? req.user?.sub ?? req.user?.userId;
    if (!userId) throw new UnauthorizedException('No user id in JWT payload');
    return this.usersService.getPreferences(userId);
  }

  // PATCH /users/me/preferences
  @Patch('me/preferences')
  updatePreferences(@Req() req, @Body() dto: UpdatePreferencesDto) {
    const userId = req.user?.id ?? req.user?.sub ?? req.user?.userId;
    if (!userId) throw new UnauthorizedException('No user id in JWT payload');
    return this.usersService.updatePreferences(userId, dto);
  }
}
