/**
 * 数据库迁移脚本
 * 在应用启动前自动执行，确保数据库表结构正确
 */
import postgres from 'postgres';
import * as fs from 'fs';
import * as path from 'path';

async function migrate() {
  const databaseUrl = process.env.DATABASE_URL;
  
  if (!databaseUrl) {
    console.error('错误：DATABASE_URL 环境变量未配置');
    process.exit(1);
  }

  console.log('正在连接数据库...');
  // Handle both default and named imports
  const sql = ((postgres as any).default || postgres)(databaseUrl, { max: 1 });

  try {
    console.log('开始执行数据库迁移...');
    
    // 读取迁移 SQL 文件
    const migrationPath = path.join(__dirname, '../drizzle/0000_initial.sql');
    const migrationSql = fs.readFileSync(migrationPath, 'utf-8');
    
    // 执行迁移
    await sql.unsafe(migrationSql);
    
    console.log('数据库迁移执行成功！');
  } catch (error) {
    console.error('数据库迁移失败：', error);
    process.exit(1);
  } finally {
    await sql.end();
  }
}

migrate();
