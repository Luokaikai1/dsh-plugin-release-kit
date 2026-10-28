# 双端发布流程（GitHub public + 魔搭 dataset）

以 DSH 插件为例；其它 git 仓库同理。每步都有对应的可验证结果。

## 0. 前置

- GitHub PAT（``repo`` 作用域，如需删库还要 ``delete_repo``）
- 魔搭访问令牌（个人设置里的访问令牌）
- 本机 git；Windows 下建议 git-bash
- 先过完 ``CHECKLIST.md`` 与 ``scripts/secret_scan.sh``

## 1. 确认公开面

```bash
# 用令牌解出账号，别按印象里的账号名去搜
curl -s -H "Authorization: Bearer $PAT" https://api.github.com/user | grep '"login"'
```

再按该账号检索是否已有同名仓库。**常见错误**：按另一个账号名搜，得出「没发过」的错误结论。

## 2. 本地脱敏与历史重写

```bash
# 工作树替换
sed -i 's/真实群号/123456789/g' test/xxx.test.js

# 全历史替换（重写所有提交）
FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch -f --tree-filter \
  'sed -i "s/真实群号/123456789/g" test/xxx.test.js 2>/dev/null; true' -- HEAD

# 备份分支如果含旧值，发布前删掉
git branch -D backup/pre-scrub
```

验证：``git grep -n '真实群号' $(git rev-list HEAD)`` 必须 0 命中。

## 3. GitHub

```bash
# 建库（也可用网页）
curl -s -X POST -H "Authorization: Bearer $PAT" \
  -H "Content-Type: application/json" \
  -d '{"name":"repo-name","private":false,"license_template":"mit"}' \
  https://api.github.com/user/repos

# 推送（沙箱/受限环境下 TLS 可能走 schannel 报 SEC_E_NO_CREDENTIALS）
git -c http.sslBackend=openssl push --force \
  "https://x-access-token:<PAT>@github.com/<owner>/<repo>.git" HEAD:main

# 补 topics
curl -s -X PUT -H "Authorization: Bearer $PAT" \
  -H "Content-Type: application/json" \
  -d '{"names":["dsh","plugin"]}' \
  https://api.github.com/repos/<owner>/<repo>/topics
```

## 4. 魔搭

魔搭建库接口（``POST /api/v1/datasets``）实测常返回 500，**先在网页手动建空库**，再推：

```bash
# 鉴权（两种写法都可用）
git ls-remote "https://oauth2:<MS_TOKEN>@www.modelscope.cn/datasets/<ns>/<name>.git"

# master 是保护分支，禁 force push。先合并远端初始提交再普通推送：
git fetch "https://oauth2:<MS_TOKEN>@www.modelscope.cn/datasets/<ns>/<name>.git" master:refs/remotes/ms/master
git merge --allow-unrelated-histories --no-edit -X ours refs/remotes/ms/master
git push "https://oauth2:<MS_TOKEN>@www.modelscope.cn/datasets/<ns>/<name>.git" HEAD:master
```

## 5. 复核

```bash
git fetch <url> master:refs/remotes/ms/verify
git ls-tree -r --name-only refs/remotes/ms/verify     # 文件清单
git grep -n '真实群号' refs/remotes/ms/verify          # 必须 0 命中
```

再打开网页确认 README 渲染、描述、license。

## 6. 收尾

- 旧库若含隐私：转私有 → 改名 ``-archive`` → 彻底删除（需 ``delete_repo``）
- **吊销本次用过的令牌**（它们很可能已在日志/终端里明文出现过）
- 记录 commit SHA 与发布时间

## 已知坑

| 现象 | 原因 | 处理 |
|---|---|---|
| ``SEC_E_NO_CREDENTIALS`` | Windows schannel 在受限环境取不到凭据 | ``git -c http.sslBackend=openssl`` |
| 魔搭 ``pre-receive hook declined`` | master 保护分支禁 force | fetch + merge 后普通 push |
| ``POST /api/v1/datasets`` 500 | 创建接口对令牌不可用 | 网页手动建库 |
| force push 后旧对象仍可访问 | Git 对象未 GC | 删库重建才彻底 |
| 两端历史分叉 | 魔搭多一个 merge 提交 | 后续同步先 ``git pull`` |
