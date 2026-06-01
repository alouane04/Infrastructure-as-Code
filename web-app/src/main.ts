import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { join } from 'path';
import { AppModule } from './app.module';
import * as session from 'express-session';
import { AppSessionBaseType } from './libs/data-structures/app-session.type';
import Redis from 'ioredis';
import { RedisStore } from 'connect-redis';

declare module 'express-session' {
  export interface SessionData extends AppSessionBaseType {}
}

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  // Redis client (ioredis)
  const redisClient = new Redis({
    host: process.env.REDIS_HOST || 'localhost',
    port: parseInt(process.env.REDIS_PORT || '6379'),
  });

  redisClient.on('error', (err) => {
    console.error('Redis error:', err);
  });

  // Redis session store (connect-redis v9 + ioredis cast)
  const redisStore = new (RedisStore as any)({
    client: redisClient as any,
    prefix: 'sess:',
  });

  app.use(session({
    store: redisStore,
    secret: process.env.SESSION_SECRET || 'local-dev-secret',
    resave: false,
    saveUninitialized: false,
    cookie: {
      maxAge: 1000 * 60 * 60 * 24,
      httpOnly: true,
    },
  }));

  app.useStaticAssets(join(__dirname, '..', 'public'));
  app.setBaseViewsDir(join(__dirname, 'views'));
  app.setViewEngine('hbs');

  await app.listen(process.env.PORT || 3000);
}
bootstrap();
