# OpenViking 映射规则

## 应借鉴的点
1. 上下文类型分层：resource / memory / skill
2. L0 / L1 / L2 分层
3. 检索与存储分离
4. 会话提交后形成长期知识
5. 可独立服务化

## 不应直接照搬的点
1. 不要把 PocketMind 的业务主模型直接替换成虚拟文件系统
2. 不要把客户端主读取路径改成先读文件
3. 不要把所有资源都当作文件目录节点
4. 不要在现阶段强引入重型 AGFS 风格实现

## PocketMind 的正确映射
### OpenViking 的 resources
对应 PocketMind 中：
- note 文本资源
- 网页抓取资源
- OCR 文本资源
- PDF/Markdown 提取资源
- 聊天归档资源

### OpenViking 的 user memories
对应 PocketMind 中：
- 用户偏好
- 用户习惯
- 长期关注实体
- 事件和里程碑

### OpenViking 的 agent memories
对应 PocketMind 中：
- 系统在执行中沉淀的经验
- 可后续实现，首版可不落地

### OpenViking 的 skills
对应 PocketMind 中：
- 多租户 AI skills
- Prompt / tool / workflow / policy
