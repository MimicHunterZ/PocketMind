---
name: dynamic-task-orchestrator
description: 进行新增业务/根据业务执行代码的时候通过读取根目录下面的 todo.json，以获取对应的上下文信息来进行执行任务
tag: ['todo.json']
---

# Full-Stack Task Manager

你通过使用 Python 脚本 `scripts/task_manager.py` 管理项目进度（无需查看对应的py文件）。
你的核心逻辑是：**先看地图 (Project Map)，再聚焦 (Focus View)，最后执行 (Execute)。**

## 核心视图 (read)

每次开始前，必须运行：
`python3 scripts/task_manager.py read`

**理解输出：**
1. **PROJECT MAP**: 显示所有大任务。前面的 `[0], [1]` 是 Feature Index。
2. **FOCUS VIEW**: 显示当前选中的大任务详情。下面的 `0. 1. 2.` 是 Step Index。
3. **[NEXT] 指针**: 指示你当前唯一应该做的小任务。

---

## 指令集 (Tools)

### 1. 🏗️ 大任务管理 (Features)
*操作对象：Project Map 中的列表*

* **添加新功能**:
    `python3 scripts/task_manager.py feature add "标题" "描述"`
    * *AI注意*: 脚本会返回新任务的 Index，如果需要立即做这个，请随后调用 switch。
* **切换当前焦点**:
    `python3 scripts/task_manager.py feature switch <Feature_Index>`
    * *场景*: 做完了一个功能，准备开始下一个；或者中途切换任务。
* **删除大任务**:
    `python3 scripts/task_manager.py feature del <Feature_Index>`

### 2. 🪜 小任务管理 (Steps)
*操作对象：FOCUS VIEW 中的列表 (自动针对当前 Active Feature)*

* **追加步骤 (队尾)**:
    `python3 scripts/task_manager.py step add "描述"`
* **插入步骤 (插队)**:
    `python3 scripts/task_manager.py step insert <Step_Index> "描述"`
    * *场景*: 发现 Step 2 执行前需要先做个准备工作，就 insert 2。
* **修改步骤**:
    `python3 scripts/task_manager.py step mod <Step_Index> "新描述"`
* **删除步骤**:
    `python3 scripts/task_manager.py step del <Step_Index>`
* **✅ 完成当前项**:
    `python3 scripts/task_manager.py step complete`

---

## 标准工作流 (SOP)

### 场景 A：开始新的一天
1. 运行 `read`。
2. 看到 Focus View 中有 `[NEXT]` 标记的任务 -> **开始执行代码**。
3. 执行完毕 -> 运行 `step complete`。

### 场景 B：接到新需求 (Feature)
1. 运行 `feature add "新模块名" "说明..."`。
2. (可选) 如果要立即做这个，运行 `feature switch <返回的Index>`。
3. 接着运行 `step add "第一步..."` 细化该模块。

### 场景 C：发现当前计划有误 (Step)
1. 运行 `read` 发现 Step 2 是错的。
2. 运行 `step mod 2 "修正后的描述"`。
3. 或者运行 `step insert 2 "遗漏的前置步骤"`。

## 约束
- 所有的 Index 都是 **0-based** (从0开始)，请严格参考 `read` 命令返回的数字。
- 不要手动编辑 json 文件，必须使用脚本，以确保 Active Index 同步更新。