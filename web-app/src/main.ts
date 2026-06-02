import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { join } from 'path';
import { AppModule } from './app.module';
import * as session from 'express-session';
import { AppSessionBaseType } from './libs/data-structures/app-session.type';
import { createClient } from 'redis';
import { RedisStore } from 'connect-redis';

declare module 'express-session' {
  export interface SessionData extends AppSessionBaseType {}
}

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  // Redis client (node-redis v5 — the API connect-redis v9 expects)
  const redisClient = createClient({
    socket: {
      host: process.env.REDIS_HOST || 'localhost',
      port: parseInt(process.env.REDIS_PORT || '6379'),
    },
  });

  redisClient.on('error', (err) => {
    console.error('Redis error:', err);
  });

  await redisClient.connect();

  // Redis session store (connect-redis v9 + node-redis v5)
  const redisStore = new RedisStore({
    client: redisClient,
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
