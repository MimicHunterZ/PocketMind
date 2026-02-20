信息如下，url 为帖子对应的连接，title为帖子的标题，description/content 为帖子的内容（已经抓取了）：
- url: <url>
- title: <title>
- description: <description>
- content: <content>
- question: <question>


1) 必须生成 summary（总结），用于概括帖子核心信息。
2) 如果 question 为空，则 answer 返回空字符串。
3) 输出格式固定为：{"summary":"...","answer":"..."}
