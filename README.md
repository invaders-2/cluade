# Claude Code 初始化规则

这个仓库存储我的 Claude Code 协作规则。每次新对话时 Claude Code 自动读取 `CLAUDE.md`，按照里面的规则与我协作。

## 使用方法

### 新机器首次设置

**方法一（推荐）：放在项目根目录**
```bash
git clone https://github.com/invaders-2/cluade.git
# 然后把 CLAUDE.md 复制到项目根目录，或创建符号链接
```

**方法二：放在用户目录**
将 `CLAUDE.md` 复制到 `C:\Users\<用户名>\CLAUDE.md`，Claude Code 启动时自动加载。

### 更新规则

```bash
git pull
```

然后把最新的 `CLAUDE.md` 复制到对应位置即可。

### 不同机器的 CLAUDE.md 是否应该一样？

是的。如果你在多台机器上使用 Claude Code，这个仓库就是统一的规则来源。所有机器都从同一个仓库拉取，确保行为一致。

## 文件说明

- `CLAUDE.md` — Claude Code 初始化规则（核心文件）
- `README.md` — 本说明文件

## 维护

规则由用户（老板）提需求，Claude Code（总经理）整理成文档后提交到此仓库。
