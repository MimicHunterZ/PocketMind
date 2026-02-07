import json
import os
import sys

# 锁定项目根目录下的 todo.json
ROOT_DIR = os.getcwd()
TODO_FILE = os.path.join(ROOT_DIR, 'todo.json')

def load_db():
    if not os.path.exists(TODO_FILE):
        # 默认初始化
        return {"project_name": "Project", "active_feature_idx": 0, "features": []}
    with open(TODO_FILE, 'r', encoding='utf-8') as f:
        return json.load(f)

def save_db(data):
    with open(TODO_FILE, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

# --- 核心逻辑 ---

def cmd_read():
    """仪表盘视图：展示所有大任务，并展开当前聚焦任务的详情"""
    db = load_db()
    feats = db.get("features", [])
    active_idx = db.get("active_feature_idx", 0)

    if not feats:
        print("📭 Task list is empty. Use 'feature add <title> <desc>' to start.")
        return

    # 1. 打印大任务列表 (The Map)
    print("\n=== 🗺️ PROJECT MAP (Features) ===")
    for idx, f in enumerate(feats):
        marker = "👉" if idx == active_idx else "  "
        icon = "🟢" if f['status'] == 'completed' else "🔵" if f['status'] == 'in_progress' else "⚪"
        print(f"{marker} [{idx}] {icon} {f['title']}")

    # 2. 打印当前聚焦任务的详情 (The Focus)
    if 0 <= active_idx < len(feats):
        curr_feat = feats[active_idx]
        print(f"\n=== 🔭 FOCUS VIEW: {curr_feat['title']} ===")
        print(f"ℹ️  Desc: {curr_feat.get('desc', '')}")
        print("-" * 50)
        
        steps = curr_feat.get("steps", [])
        if not steps:
            print("   (No steps yet. Use 'step add' to populate)")
        
        pending_count = 0
        for s_idx, step in enumerate(steps):
            s_icon = "✅" if step['status'] == 'completed' else "⬜"
            # 智能指针：指向第一个未完成的任务
            pointer = " 👈 [NEXT]" if step['status'] == 'pending' and pending_count == 0 else ""
            if step['status'] == 'pending': pending_count += 1
            print(f"   {s_idx}. {s_icon} {step['desc']}{pointer}")
            
        print("-" * 50)
        if pending_count == 0 and steps:
            print("🎉 Current feature steps all done! Use 'feature complete' or 'switch' to move on.")
    else:
        print("\n⚠️ Active index out of range. Use 'switch <idx>' to fix.")

def cmd_feature(action, *args):
    """大任务管理：add, del, switch, complete"""
    db = load_db()
    feats = db["features"]

    if action == "add":
        # python task.py feature add "Title" "Desc"
        title = args[0]
        desc = args[1] if len(args) > 1 else ""
        new_feat = {"title": title, "desc": desc, "status": "pending", "steps": []}
        feats.append(new_feat)
        new_idx = len(feats) - 1
        # 如果是第一个，自动激活
        if len(feats) == 1: 
            new_feat['status'] = 'in_progress'
            db['active_feature_idx'] = 0
        
        save_db(db)
        print(f"✅ Feature created at INDEX [{new_idx}]: {title}")

    elif action == "switch":
        # python task.py feature switch 2
        idx = int(args[0])
        if 0 <= idx < len(feats):
            db['active_feature_idx'] = idx
            feats[idx]['status'] = 'in_progress' # 自动标记为进行中
            save_db(db)
            print(f"🔄 Switched focus to Feature [{idx}]: {feats[idx]['title']}")
            cmd_read() # 立即展示新视图
        else:
            print(f"❌ Invalid Feature Index: {idx}")

    elif action == "del":
        idx = int(args[0])
        if 0 <= idx < len(feats):
            removed = feats.pop(idx)
            # 修正 active_idx
            if db['active_feature_idx'] >= len(feats):
                db['active_feature_idx'] = max(0, len(feats) - 1)
            save_db(db)
            print(f"🗑️ Deleted Feature [{idx}]: {removed['title']}")

def cmd_step(action, *args):
    """小任务管理：add, insert, mod, del, complete (针对当前 Active Feature)"""
    db = load_db()
    a_idx = db.get("active_feature_idx", 0)
    if a_idx >= len(db["features"]):
        print("❌ No active feature selected.")
        return
    
    steps = db["features"][a_idx]["steps"]

    if action == "add":
        # 追加到末尾
        desc = args[0]
        steps.append({"desc": desc, "status": "pending"})
        new_step_idx = len(steps) - 1
        save_db(db)
        print(f"✅ Step added at INDEX {new_step_idx}: {desc}")

    elif action == "insert":
        # python task.py step insert 2 "New Task"
        idx = int(args[0])
        desc = args[1]
        steps.insert(idx, {"desc": desc, "status": "pending"})
        save_db(db)
        print(f"✅ Step inserted at INDEX {idx}: {desc}")

    elif action == "mod":
        # python task.py step mod 2 "New Text"
        idx = int(args[0])
        desc = args[1]
        if 0 <= idx < len(steps):
            steps[idx]['desc'] = desc
            save_db(db)
            print(f"📝 Step {idx} updated.")

    elif action == "del":
        idx = int(args[0])
        if 0 <= idx < len(steps):
            removed = steps.pop(idx)
            save_db(db)
            print(f"🗑️ Step {idx} deleted: {removed['desc']}")

    elif action == "complete":
        # 自动完成第一个 pending 的
        found = False
        for idx, s in enumerate(steps):
            if s['status'] == 'pending':
                s['status'] = 'completed'
                print(f"✅ Completed Step {idx}: {s['desc']}")
                
                # 检查有没有下一个
                next_steps = [ns for ni, ns in enumerate(steps) if ns['status']=='pending']
                if next_steps:
                    print(f"🚀 [NEXT ACTION]: {next_steps[0]['desc']}")
                else:
                    print("✨ Feature steps cleared! Suggest: 'feature switch' or 'feature add'.")
                found = True
                break
        if not found:
            print("⚠️ No pending steps found.")
        save_db(db)

# --- 入口 ---
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python task_manager.py [read|feature|step] ...")
        sys.exit(0)
    
    scope = sys.argv[1] # read, feature, step
    
    if scope == "read":
        cmd_read()
    elif scope == "feature":
        cmd_feature(sys.argv[2], *sys.argv[3:])
    elif scope == "step":
        cmd_step(sys.argv[2], *sys.argv[3:])