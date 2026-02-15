"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.MockAiProvider = void 0;
const common_1 = require("@nestjs/common");
let MockAiProvider = class MockAiProvider {
    getId() {
        return 'mock';
    }
    async generate(request) {
        const start = Date.now();
        await new Promise((resolve) => setTimeout(resolve, 500));
        return {
            content: `[Mock AI Response] Analysed: ${request.userPrompt}`,
            usage: {
                promptTokens: request.userPrompt.length,
                completionTokens: 10,
                totalTokens: request.userPrompt.length + 10,
            },
            latencyMs: Date.now() - start,
            provider: 'mock',
            model: 'mock-v1',
        };
    }
};
exports.MockAiProvider = MockAiProvider;
exports.MockAiProvider = MockAiProvider = __decorate([
    (0, common_1.Injectable)()
], MockAiProvider);
//# sourceMappingURL=mock.provider.js.map