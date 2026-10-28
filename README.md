# dsh-plugin-release-kit

一套把 DeepSeek Harness（DSH）插件**安全发到 GitHub 与魔搭（ModelScope）**的最小工具包：脱敏审计脚本 + 发布前核对清单 + 可复现的双端发布流程。

不是又一个插件市场条目，而是「发布这件事本身」的操作手册与检查器。

## 它解决什么

自研插件或对下载插件的改造，直接 push 出去时最容易踩三件事：

1. **密钥/隐私漏出去**——API key、token、真实群号、绝对路径混在代码或测试夹具里，且历史提交里删不掉。
2. **描述和功能对不上**——README 写的能力代码里没有，代码里的坑 README 不提。
3. **双端不一致**——GitHub 发了、魔搭没发，或两边历史分叉后再也同步不上。

工具包对应给出：`secret_scan.sh`（工作树 + 全历史双扫）、`CHECKLIST.md`（功能 ↔ 描述核对）、`docs/publish-flow.md`（双端发布 12 步，含魔搭保护分支等坑）。

## 内容

| 文件 | 用途 |
|---|---|
| `scripts/secret_scan.sh` | 扫描 git 仓库的工作树与**全部历史提交**，命中密钥、账号、群号、本机路径、内网端点 |
| `CHECKLIST.md` | 发布前逐项核对：先列代码事实，再对照 README 与平台描述，缺陷必须显性化 |
| `docs/publish-flow.md` | GitHub public + 魔搭 dataset 的完整发布步骤与回滚办法 |

## 用法

```bash
# 1. 脱敏审计（在插件仓库根目录执行）
bash scripts/secret_scan.sh /path/to/your-plugin-repo

# 2. 逐项勾 CHECKLIST.md
#    重点：README 与平台描述能不能和代码逐句对上；已知缺陷有没有写进「已知限制」

# 3. 按 docs/publish-flow.md 依次完成双端发布
```

扫描输出分七段：远端与提交数、工作树高置信密钥、工作树键值凭据、工作树隐私痕迹、全历史高置信密钥、全历史键值凭据、历史中的可疑文件名与 `.gitignore` 内容。任何一段有命中都要人工判定——**测试夹具可以用，真实凭据不行**。

## 已知限制

- **只做过 Windows + DSH 桌面版环境的实测**，Linux/macOS 未验证；脚本是 bash，需要 git-bash 或原生 bash。
- 扫描基于正则，**不能证明没泄露**，只能证明命中了什么。二进制文件被 `-I` 跳过，若怀疑图片/数据库里藏密钥需单独排查。
- 魔搭侧 `POST /api/v1/datasets` 创建接口实测恒返回 500，**建库必须先到网页手动完成**，工具包不代建。
- 魔搭 `master` 是保护分支，`force push` 会被拒；流程用「fetch + merge --allow-unrelated-histories」绕开，因此**魔搭与 GitHub 的历史会分叉**，后续同步需先 pull。
- GitHub 上执行 `force push` 后旧对象不会立即消失，知道 SHA 仍可访问；彻底清除只能删库重建。
- 未包含 CI、自动发版、Release 打包；也不自动吊销令牌。

## 许可

MIT。扫描规则与清单可以按其实际风险自行增删，改了建议在 Description 里注明。
