# schema.md — 制度宪法

> 统一命名、编辑权限、内容规范，防多角色乱编辑。

## 命名
- 项目目录：`wiki/projects/<项目名>/`，项目名用简短小写连字符。
- 文件名 ascii 优先（跨 Win/Mac 安全），标题用中文。

## 编辑权限
| 区域 | 可写角色 |
|------|---------|
| `system/` | 仅 Coordinator |
| `projects/<x>/inbox/` | 对应执行角色 |
| `projects/<x>/outputs/` | 仅 Coordinator 核验后入 |
| `pages/` | Coordinator 核验后入 |
| `raw/` | 只读，禁改 |

## 内容规范
- 没有归属的信息不准落盘（先查 §6 记忆路由表）。
- 维护秩序靠归档不靠删除：废弃内容移 `archive/`，保留可追溯历史。
