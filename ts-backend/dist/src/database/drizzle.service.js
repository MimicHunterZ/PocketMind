"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var DrizzleService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.DrizzleService = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const postgres_js_1 = require("drizzle-orm/postgres-js");
const postgres_1 = require("postgres");
const schema = require("../database/schema");
let DrizzleService = DrizzleService_1 = class DrizzleService {
    constructor(configService) {
        this.configService = configService;
        this.logger = new common_1.Logger(DrizzleService_1.name);
    }
    async onModuleInit() {
        try {
            const databaseUrl = this.configService.get('DATABASE_URL');
            if (!databaseUrl) {
                throw new Error('DATABASE_URL 环境变量未配置');
            }
            this.logger.log('正在连接数据库...');
            this.client = (0, postgres_1.default)(databaseUrl, {
                max: 10,
                idle_timeout: 20,
                connect_timeout: 10,
            });
            this.db = (0, postgres_js_1.drizzle)(this.client, { schema });
            this.logger.log('数据库连接成功');
        }
        catch (error) {
            const errorMessage = error instanceof Error ? error.message : JSON.stringify(error);
            this.logger.error(`数据库连接失败: ${errorMessage}`);
            throw error;
        }
    }
    async onModuleDestroy() {
        try {
            if (this.client) {
                this.logger.log('正在关闭数据库连接...');
                await this.client.end();
                this.logger.log('数据库连接已关闭');
            }
        }
        catch (error) {
            const errorMessage = error instanceof Error ? error.message : JSON.stringify(error);
            this.logger.error(`关闭数据库连接失败: ${errorMessage}`);
        }
    }
};
exports.DrizzleService = DrizzleService;
exports.DrizzleService = DrizzleService = DrizzleService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [config_1.ConfigService])
], DrizzleService);
//# sourceMappingURL=drizzle.service.js.map