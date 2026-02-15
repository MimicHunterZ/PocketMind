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
var AiService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.AiService = void 0;
const common_1 = require("@nestjs/common");
const drizzle_service_1 = require("../database/drizzle.service");
const schema_1 = require("../database/schema");
const mock_provider_1 = require("./providers/mock.provider");
let AiService = AiService_1 = class AiService {
    constructor(drizzle, mockProvider) {
        this.drizzle = drizzle;
        this.mockProvider = mockProvider;
        this.logger = new common_1.Logger(AiService_1.name);
        this.providers = new Map();
        this.registerProvider(mockProvider);
    }
    registerProvider(provider) {
        this.providers.set(provider.getId(), provider);
    }
    async generate(request, providerId = 'mock') {
        const provider = this.providers.get(providerId);
        if (!provider) {
            throw new Error(`Provider ${providerId} not found`);
        }
        this.logger.log(`Processing AI request. traceId=${request.traceId}, provider=${providerId}`);
        try {
            const response = await provider.generate(request);
            this.auditLog(request, response).catch((err) => {
                if (err instanceof Error) {
                    this.logger.error(`Failed to write audit log: ${err.message}`, err.stack);
                }
                else {
                    this.logger.error('Failed to write audit log: Unknown error', JSON.stringify(err));
                }
            });
            return response;
        }
        catch (error) {
            let errorMessage;
            let errorStack;
            if (error instanceof Error) {
                errorMessage = error.message;
                errorStack = error.stack;
            }
            else {
                errorMessage = 'Unknown error';
                errorStack = JSON.stringify(error);
            }
            this.logger.error(`AI Generation failed: ${errorMessage}`, errorStack);
            this.drizzle.db
                .insert(schema_1.tokenAuditLogs)
                .values({
                traceId: request.traceId,
                userId: request.userId,
                provider: providerId,
                model: request.model || 'unknown',
                promptTokens: 0,
                completionTokens: 0,
                totalTokens: 0,
                latencyMs: 0,
                status: 'failed',
                errorMessage: errorMessage,
            })
                .catch((err) => {
                const errMsg = err instanceof Error ? err.message : JSON.stringify(err);
                this.logger.error('Failed to log audit failure', errMsg);
            });
            throw error;
        }
    }
    async auditLog(request, response) {
        await this.drizzle.db.insert(schema_1.tokenAuditLogs).values({
            traceId: request.traceId,
            userId: request.userId,
            provider: response.provider,
            model: response.model,
            promptTokens: response.usage?.promptTokens || 0,
            completionTokens: response.usage?.completionTokens || 0,
            totalTokens: response.usage?.totalTokens || 0,
            latencyMs: response.latencyMs || 0,
            status: 'success',
            errorMessage: null,
        });
    }
};
exports.AiService = AiService;
exports.AiService = AiService = AiService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [drizzle_service_1.DrizzleService,
        mock_provider_1.MockAiProvider])
], AiService);
//# sourceMappingURL=ai.service.js.map