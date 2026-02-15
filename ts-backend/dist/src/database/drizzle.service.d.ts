import { OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PostgresJsDatabase } from 'drizzle-orm/postgres-js';
import * as schema from '../database/schema';
export declare class DrizzleService implements OnModuleInit, OnModuleDestroy {
    private configService;
    private readonly logger;
    private client;
    db: PostgresJsDatabase<typeof schema>;
    constructor(configService: ConfigService);
    onModuleInit(): Promise<void>;
    onModuleDestroy(): Promise<void>;
}
