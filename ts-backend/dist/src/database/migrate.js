"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const postgres_1 = require("postgres");
const fs = require("fs");
const path = require("path");
async function migrate() {
    const databaseUrl = process.env.DATABASE_URL;
    if (!databaseUrl) {
        console.error('错误：DATABASE_URL 环境变量未配置');
        process.exit(1);
    }
    console.log('正在连接数据库...');
    const sql = (0, postgres_1.default)(databaseUrl, { max: 1 });
    try {
        console.log('开始执行数据库迁移...');
        const migrationPath = path.join(__dirname, '../drizzle/0000_initial.sql');
        const migrationSql = fs.readFileSync(migrationPath, 'utf-8');
        await sql.unsafe(migrationSql);
        console.log('数据库迁移执行成功！');
    }
    catch (error) {
        console.error('数据库迁移失败：', error);
        process.exit(1);
    }
    finally {
        await sql.end();
    }
}
migrate();
//# sourceMappingURL=migrate.js.map