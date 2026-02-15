#!/bin/sh

echo "正在执行数据库迁移..."
node dist/src/database/migrate.js

if [ $? -eq 0 ]; then
  echo "数据库迁移成功，启动应用..."
  node dist/src/main.js
else
  echo "数据库迁移失败，退出"
  exit 1
fi
