# Domain Write Kernel 推进总账（跨会话唯一进度源）

> 工作协议：任何成员生命周期 / Domain write-kernel 架构会话开工前先读本文件；收工前必须更新对应 Phase 行和更新日志，否则视为未完成。
> 状态图例：⬜ 未开始 ｜ 🔵 分析完成待修 ｜ 🟡 本地实施中 ｜ 🟢 本地门禁通过 ｜ 🟢\* 本地门禁通过但带验收债 ｜ 🏁 Phase-end CI + 纯复审通过 ｜ ⛔ 阻塞
> CI 节奏：Phase 内只跑本地验证；只有每个 Phase 结束后才 commit/push 一次并查阅一次 CI。CI 不是 heartbeat，不在 Phase 中途反复触发。

## 阶段总览

| Phase | 范围 | 状态 | 本地门禁 | Phase-end CI | 备注 |
|---|---|---|---|---|---|
| 0 | 冻结点补丁 + 全 app 写入矩阵 | 🟢 | 写入矩阵完成；文档/脚本级本地验证 PASS | required | 本地完成：Phase 0 写入矩阵已产出：docs/planning/domain-write-kernel-write-matrix.md；本阶段仅本地验证，Phase-end CI 待提交后一次性执行。；下一步 commit/push 一次并查一次 CI。 |
| 1 | Typed subject taxonomy | 🟡 | Event/Reminder taxonomy 已开始；全 app subject resolution 待补 | pending | 覆盖 Event/Reminder、care fact、ledger、task、notification、backup/sync；行为保持 characterization |
| 2 | Capability authorizer | 🟡 | Schedule token 已开始；全局 AuthorizedMutationPlan 待补 | pending | disposition 是结果，不是能力；authorizer 才能发 plan/token |
| 3 | Schedule writer 首批收口 | 🟢 | `scripts/module-exit-gate.sh` PASS；raw Event/Reminder scan 收口 | required | Event/Reminder 写入已收进 writer；下一步是本 Phase 唯一一次 commit/push + CI |
| 4 | Fact / ledger / economy 收口 | ⬜ | pending | pending | care fact、expense、wallet ledger、reward、family task completion 改为 plan 驱动 |
| 5 | Restore / sync / import 收口 | ⬜ | pending | pending | Backup restore / Cloud apply 走 RehydrateWriter；禁止 raw persistence bypass |
| 6 | R8/R9 审计升级 | 🟡 | schedule 审计已升级；全 effects 审计待补 | pending | 禁 direct constructor、raw matcher、restore/apply bypass、effect guessing、feature taxonomy string |
| 7 | 依赖倒挂收缩 | ⬜ | pending | pending | taxonomy、policy result、mutation plan 保持 feature-neutral；Domain/Models 不新增 feature command result/string |

## Phase 明细

| Phase | 目标 | 本地验证规则 | 退出准则 |
|---|---|---|---|
| 0 | 不再逐 command patch；先产全 app 写入矩阵 | 只读扫描、矩阵 review、本地不触发 CI | 无完整矩阵不得进入下一批实现 |
| 1 | `DomainEntityLinkRegistry` + `DomainSubjectResolution` 覆盖全 app subject/effect | characterization tests、changed-file audits | 新 link type 未注册 taxonomy 时不能静默写入 |
| 2 | `DomainPolicyAuthorizer` + `AuthorizedMutationPlan/token` | token compile checks、targeted policy tests、changed-file audits | 调用方无法伪造写能力 |
| 3 | Event/Reminder 写入只走 schedule writer | targeted schedule suites、raw constructor scan、member lifecycle audit、fixture tests、module-exit gate | feature command 不能直接构造并 insert member-scoped Event/Reminder |
| 4 | care fact / ledger / reward / wallet / task effects 走 authorized plan | targeted care/economy/family-task suites、ledger/reward fixtures、economy/member audits | 核心业务事实和 effects 不能绕过 authorized plan |
| 5 | restore/sync/import 走 rehydrate policy | backup/cloud targeted tests、rehydrate fixtures、restore/apply bypass audit | restore/sync 不能 raw insert member-scoped 状态 |
| 6 | R8/R9 从“有 helper”升级为“绕不过 writer/token” | bad/good fixtures first、全相关 audit scripts | fixture 覆盖 constructor、matcher、assignee-only、indirect owner、restore/apply、effects bypass |
| 7 | 收缩 Domain/Models 对 feature taxonomy/result 的依赖 | architecture boundary audit、dependency scans、targeted compile/test | Domain policy 类型 feature-neutral；新增 feature-owned string 审计红 |

## 当前记录

- 备份点：`/Users/guanchenli/Documents/Space/Ohana-backups/20260615-134858-pre-domain-write-kernel`
- Phase 3 本地验证：`scripts/module-exit-gate.sh` PASS，完整 903 unit tests + 3 UI launch tests 通过；`scripts/audit-member-lifecycle-gate.sh --all` scanned 809 files，warnings=0；audit fixture tests passed；raw `Event(`/`Reminder(` 只剩 writer + CloudSync apply + backup decode 边界。
- Phase 3 待办：commit/push 后只查一次 CI，并用 `scripts/track-domain-write-kernel-plan.sh ci 3 <run-url> <pass|fail|blocked>` 写回本文件。

## 核心判断

成员生命周期只是最先暴露问题的场景；真正病灶是业务写入、subject 解析、policy、effects 没有统一入场券。

真正根因：

- 调用方先拥有写能力，再被要求自觉问 policy。
- `Event/Reminder` 和多种业务事实用 raw string/id 表达 owner、subject、assignee、display target、effect target。
- disposition/resolver 是建议性信号，不是能力令牌。
- restore/sync/import 仍能绕过 user command 直接落 persistence。
- 审计查调用形状，没有证明“非法状态构造不出来”。

目标架构：

```text
Raw Intent / DTO / Restore Record
-> DomainSubjectResolution
-> DomainPolicyAuthorizer
-> AuthorizedMutationPlan / token
-> ScopedPersistenceWriter
-> Typed Effects Dispatcher
-> Revision / Sync / Notification / Ledger / Reward
```

## 最终验收

- command 构造不出未经授权的成员/经济/提醒/ledger 写入。
- restore/sync 构造不出 raw persistence bypass。
- deep link、delete、filter、overdue、task、notification、ledger 全部消费 typed resolution。
- 新 link type 未注册 taxonomy 时无法写入并审计红。
- bad/good fixture 覆盖 direct constructor、raw matcher、assignee-only、indirect owner、restore/apply、effects bypass。
- 结尾只做一次全新纯复审；P0/P1 必须为 0。

## 更新日志

- 2026-06-15 Phase 3 local complete：Schedule writer 首批收口完成，本地 module-exit gate 通过；Phase-end CI pending。

- 2026-06-15 14:34:57 +0200 Phase 0 start：Phase 0 开始：只做全 app 写入矩阵和扫描，本阶段内不触发 CI。

- 2026-06-15 14:37:47 +0200 Phase 0 complete：本地完成：Phase 0 写入矩阵已产出：docs/planning/domain-write-kernel-write-matrix.md；本阶段仅本地验证，Phase-end CI 待提交后一次性执行。；Phase-end CI required。

- 2026-06-15 Phase 0 local gate：`bash -n scripts/track-domain-write-kernel-plan.sh` PASS；`scripts/track-domain-write-kernel-plan.sh status` PASS；`scripts/dev-check-changed.sh` PASS（no app build recommended）；`git diff --check` PASS。
