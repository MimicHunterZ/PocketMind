信息如下，url 为帖子对应的连接，title为帖子的标题，description/content 为帖子的内容（已经抓取了）：
- url: <url>
- title: <title>
- description: <description>
- content: <content>
- question: <question>

注意：本次分析所需的全部信息已经在 content 中提供，禁止调用任何工具（包括搜索/爬取/Skill/Shell）。


1) 必须生成 summary（总结），用于概括帖子核心信息。
2) 必须生成 tags（标签），为帖子提炼 2~5 个简短中文关键词标签，每个标签不超过 8 个汉字，以数组形式输出。
3) 如果 question 为空，则 answer 返回空字符串。
4) 输出格式固定为：
<format>

