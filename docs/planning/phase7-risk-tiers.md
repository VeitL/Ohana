# Phase 7 风险分级（双轨制执行清单）

> 总览会话 2026-06-13 产出，**待产品主人圈定确认**。轨制定义见手册 Phase 7。
> 已完成（Phase 7）：Walks、Gacha、Shop（均走完整轨，已 🟢）。
> 原则：有疑问就放完整轨——轻量轨是给"确无业务事实/经济/删除/schema"的纯展示件。

## 完整轨（高风险，走完整六步 + 1b 规则书 + 复审资格）

| 模块 | 进完整轨的理由 |
|---|---|
| Medication | 健康关键通知、剂量记录、漏服后果严重 |
| CareLedger | 账本骨干，G2 余额可重放的核心 |
| Expenses | 经济/账本写入 |
| Achievements | 奖励写入（R2 归属风险） |
| GrowthUnlock | 解锁/奖励逻辑 |
| Calendar | 提醒创建/完成，跨功能联动 |
| Notifications | D15 通知预算系统，横切全 app |
| Memorial | D7 情感核心，离世退场跨模块 |
| Onboarding | D17 首次体验，转化漏斗，建岛/建宠业务事实 |
| Privacy | G6 隐私底线 |
| Security | PIN，release-risk |
| PetCare | 护理业务事实写入 + 奖励 |
| CatCare | 猫砂等业务事实写入 + 奖励 |
| Hygiene | 清洁业务事实写入 + 奖励 |
| HumanHealth | 人类健康记录（真实数据，删除语义） |
| DashboardRecords | 聚合正确性 + WeightHistoryView 历史隐患 |

## 轻量轨（低风险橡皮图章，简化流程）

| 模块 | 进轻量轨的理由 | 不确定点（请主人裁定） |
|---|---|---|
| Wishlist | 心愿单，轻量展示 | 是否触经济（心愿→购买）？若是则升轨 |
| Documents | 证件归档展示 | — |
| Insurance | 保单归档展示 | — |
| Moments | 时刻展示 | — |
| PhotoAlbum | 相册展示 | 容量/大图解码性能（smoothness 审计兜底） |
| Milestones | 里程碑展示 | 是否含奖励写入？若是则升轨 |
| HumanNotes | 人类笔记，D1 低调 | — |
| Workouts | 人类锻炼，D1 低调 | 是否触经济奖励？若是则升轨 |
| CrewRoster | 成员名册/切换 | — |
| FunctionMenu | 导航菜单 | — |
| FamilyReports | 周报只读（悬赏已剥离） | 仅需"编译+周报正常显示"核验 |
| FamilyTasks | 已在联机门后 | 仅需"编译 + 路由不可达"核验 |
| Plants | 已在植物门后 | 仅需"编译 + 路由不可达"核验 |

## 待确认事项

1. 圈定上述分级（尤其 4 个"不确定点"模块：Wishlist/Milestones/Workouts/PhotoAlbum 是否升轨）。
2. 轻量轨模块可两三个并一个会话快跑（用独立 worktree 并行）；完整轨一模块一会话。
3. 高风险件建议顺序：Medication → CareLedger → Notifications → Memorial → Onboarding 先行（这几个跨功能/情感/健康权重最高）。
