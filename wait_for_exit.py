import time

def wait_for_user_command():
    """
    启动一个循环，等待用户的退出指令。
    """
    print("--- 任务已完成 ---")
    print("脚本现在将持续等待，直到你输入 'exit' 来结束。")
    print("输入任何其他内容 (或直接按 Enter 键) 将会继续等待。")
    print("-" * 20)

    while True:
        try:
            # 1. 等待用户在命令行输入
            # input() 会阻塞程序，直到用户按下 Enter
            response = input("[等待指令中] > ")

            # 2. 清理输入并转为小写，以便比较
            command = response.strip().lower()

            # 3. 检查是否为退出指令
            if command == 'exit':
                print("收到 'exit' 指令，脚本正在退出...")
                break  # 跳出 while True 循环，结束脚本
            else:
                # 4. 如果不是退出指令，则继续
                if command == "":
                    print("收到 (Enter)，继续等待...")
                else:
                    print(f"收到指令: '{response}'，继续等待...")
            
            # (可选) 增加一个短暂的延迟，防止刷屏
            # time.sleep(0.5) 

        except KeyboardInterrupt:
            # 允许用户使用 Ctrl+C 强制退出
            print("\n检测到 (Ctrl+C)，强制退出。")
            break
        except Exception as e:
            print(f"发生错误: {e}")
            break

if __name__ == "__main__":
    wait_for_user_command()