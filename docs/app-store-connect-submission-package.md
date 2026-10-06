# Ohana 1.0 App Store Connect 提交填写包

> 状态：可复制草案；仅覆盖 Ohana Free + Ohana Personal。
>
> 生成日期：2026-08-02。
>
> 使用原则：带“仓库证据”的内容可以从当前源码复核；带“账号持有人确认”的内容
> 必须在 App Store Connect、Apple Developer、最终签名 Archive 或法律/商业资料中
> 确认后填写。本文不代表任何外部配置已经完成。

## 1. 提交范围与使用方式

本包只描述 1.0 已批准的本地优先单人版本和可选 Personal 商品。不要把尚未随 1.0
交付的在线服务、跨设备协作、其他 Apple 平台或未验收的系统入口写入商店文案、截图
或审核说明。

建议填写顺序：

1. 先冻结最终 Release Candidate（RC）并核对本文件第 2 节的项目事实。
2. 由账号持有人完成第 8 节的法律、商业与账户确认。
3. 将第 3、4、5 节内容复制到 App Store Connect。
4. 按第 6 节从同一份最终 RC 采集截图。
5. 按第 9 节重新运行长度、字节、链接和空白检查。

Apple 当前字段限制来自：

- [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/)
- [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)
- [In-App Purchase information](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information/)

| 字段 | Apple 限制 | 本包校验口径 |
| --- | --- | --- |
| App Name | 2–30 字符 | grapheme clusters 和 Unicode code points 均不超过 30 |
| Subtitle | 最多 30 字符 | grapheme clusters 和 Unicode code points 均不超过 30 |
| Description | 最多 4,000 字符 | grapheme clusters、code points 和 UTF-8 bytes 都报告 |
| Keywords | 最多 100 UTF-8 bytes | 直接按 UTF-8 bytes 阻断 |
| IAP Display Name | 2–30 字符 | grapheme clusters 和 code points 均不超过 30 |
| IAP Description | 最多 45 字符 | grapheme clusters 和 code points 均不超过 45 |
| IAP Review Notes | 最多 4,000 字符 | 同时检查字符数和 UTF-8 bytes |

## 2. 标识符与当前项目事实

### 2.1 仓库可确认

以下值来自当前 Xcode 工程、Info.plist、语言注册表和 StoreKit 配置；上传前仍须以最终
Archive 为准。

| 项目 | 当前值 | 来源/说明 |
| --- | --- | --- |
| App Store 平台 | iOS，iPhone-only | `TARGETED_DEVICE_FAMILY = 1` |
| 主 App Bundle ID | `com.guanchen.li.Ohana` | 不可用测试或 LocalDevice Bundle ID 替代 |
| Widget Extension Bundle ID | `com.guanchen.li.Ohana.Widgets` | 只用于签名/嵌入核对，不写入产品文案 |
| Marketing Version | `1.0` | `MARKETING_VERSION` |
| Build | `1` | `CURRENT_PROJECT_VERSION`；若上传前递增，以 Archive 为准 |
| 最低系统 | iOS 26.2 | `IPHONEOS_DEPLOYMENT_TARGET` |
| App 名称草案 | `Ohana` | 所有语言统一使用品牌名 |
| 商业形态 | 免费下载 + 可选 App 内购买 | Free 核心功能不要求购买 |
| Free 额度 | 1 Pet / 2 Human / 5 Plant / 3 个普通活跃计划 | 健康关键提醒不计入该计划额度 |
| Personal | Monthly / Yearly 自动续订；Lifetime 非消耗型一次购买 | 三者授予相同的本地 Personal 权益 |
| 账号 | Free / Personal 不需要 Ohana 账号 | 审核不需要测试登录凭据 |
| 广告/分析 | 无第三方广告或分析 SDK | 最终 Archive 仍须复核 |
| 支持邮箱 | `guanchen.li.119@gmail.com` | App 内不会自动附加诊断或用户记录 |
| Support URL | `https://github.com/VeitL/Ohana/blob/main/docs/support.md` | 提交前确认匿名浏览可访问 |
| Privacy Policy URL | `https://github.com/VeitL/Ohana/blob/main/docs/privacy-policy.md` | 仓库文本已对齐；提交前把同一版本发布到该公开 URL 并匿名复核 |
| Terms of Use | Apple Standard EULA | `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/` |
| 注册语言 | zh-Hans, en, de, es, pt-BR, fr, ja, ko, it | 共 9 种 |
| Routing App Coverage File | Not Applicable | Ohana 只记录用户主动开始的遛狗路线，不提供导航或路线规划服务 |
| App Store Server Notifications URL | Production 与 Sandbox 均留空 | Free / Personal 1.0 不使用开发者后端处理交易，也不启用 Family Server Notifications；未来 Family 上线时另行配置和审核 |

### 2.2 只能从外部账户确认的事实

| App Store Connect 字段 | 当前状态 | 提交动作 |
| --- | --- | --- |
| Apple ID（数字） | 未知 | 创建 App 记录后复制实际值 |
| Developer/Legal Name | 未知 | 使用 Apple Developer 账户中的法定显示值 |
| App Price | 未知 | 预期为 Free；必须在 App Store Connect 确认 |
| Marketing URL | 未知且可选 | 没有合格公开页面时留空，不要使用占位 URL |

### 2.3 待产品负责人确认的提交决策

以下项目不应由实现或文档作者代替产品负责人决定。确认后再把最终值复制到
App Store Connect；不得使用占位值。

| 决策 | 当前已知边界 | 待确认值 |
| --- | --- | --- |
| SKU | 不对用户显示，创建 App 记录后不可修改 | `________` |
| Primary Language | 已准备 9 种语言元数据；未覆盖地区会使用 Primary Language 回退 | `________` |
| Copyright | 年份为 2026；实际权利主体不能从仓库推断 | `2026 ________` |
| Primary / Secondary Category | `Lifestyle` 仅为候选；Ohana 不提供诊断或治疗 | `________ / ________` |
| App Review Contact | 支持邮箱不自动等于审核联系人 | 姓名 `____`；邮箱 `____`；电话 `____` |
| App Availability / Storefronts | 必须与经营、法规、DSA 和语言支持范围一致 | `________` |
| Version Release Settings | Manual / Automatic / Automatic no earlier than | `________` |
| Privacy Choices URL | Free / Personal 无开发者账号或数据选择中心；可留空或提供合格公开页面 | `留空 / ________` |
| Accessibility URL | 可留空或提供经负责人批准的公开无障碍说明页 | `留空 / ________` |
| iPhone app on Apple silicon Mac | iPhone-only 原生目标不自动决定兼容分发范围 | `启用 / 不启用` |
| iPhone app on Apple Vision Pro | iPhone-only 原生目标不自动决定兼容分发范围 | `启用 / 不启用` |
| Subscription App Name Display Options | 使用 App 名称或自定义显示名 | `________` |
| Content Rights | 头像、插图、图标、品牌和截图权利仍需权利人确认 | `已确认 / 未确认` |
| Rate App | 创建 App 记录并取得正式 Apple ID 后才能验证目标是否正确 | `1.0 启用 / 保持隐藏` |

## 3. App 主元数据（9 种语言）

下列文案刻意只描述当前 Free + Personal 能力，不承诺未来功能。Descriptions 为纯文本，
复制时保留段落即可，不要加入 Markdown 标记。

### `zh-Hans`

- Name: `Ohana`
- Subtitle: `家人宠物植物的照护记录`
- Keywords: `宠物照护,植物养护,家庭,提醒,用药,遛狗,日历,健康,记录`

#### Description

```text
Ohana 是一款本地优先的家庭照护记录 App，帮助你照顾家中的人、宠物和植物。

把喂食、散步、清洁、用药、状态、花费、照片、资料、里程碑和日常时刻放在一起。通过提醒和日历建立日常节奏，再从近期趋势、连胜、周报，以及随照护记录成长的岛屿中看见积累。

Ohana Free 包含核心照护记录、手动导出，以及 1 只活跃宠物、2 位活跃 Human、5 株活跃植物和 3 个普通活跃计划。健康关键提醒不受数量限制。

Ohana Personal 为可选升级，解锁不限数量的活跃档案与普通计划、90 天和全部时间趋势、兽医 PDF 摘要、Personal 外观，以及本机化验单扫描与逐项复核。可选择月付、年付或一次购买的 Lifetime。价格与优惠资格由 App Store 提供，购买可在设置中恢复。

Free 和 Personal 均不需要 Ohana 账号。Ohana 没有广告，也不使用第三方分析。照护记录保留在设备上，除非你主动选择受限备份或导出。可选自动备份会将加密、受限的数据包写入你自己的 iCloud Drive，并排除 Human 健康数据。

Ohana 用于整理照护记录与日常安排，不提供诊断、治疗或紧急服务。
```

### `en-US`

- Name: `Ohana`
- Subtitle: `Care for pets, people, plants`
- Keywords: `pet care,plant care,reminders,medication,walks,calendar,wellness,household,care log,local`

#### Description

```text
Ohana is a local-first care organizer for the people, pets, and plants in your home.

Keep feeding, walks, hygiene, medication, wellbeing, expenses, photos, documents, milestones, and everyday moments together. Build routines with reminders and a calendar. Follow recent trends, streaks, weekly summaries, and an island that grows as care is recorded.

Ohana Free includes core care records, manual export, one active pet, two active people, five active plants, and three active everyday plans. Health-critical reminders are not limited.

Ohana Personal is optional. It unlocks unlimited active profiles and everyday plans, 90-day and all-time trends, veterinary PDF summaries, Personal appearance options, and on-device lab-report scanning with item-by-item review. Choose monthly, yearly, or a one-time Lifetime purchase. Prices and offer eligibility come from the App Store, and purchases can be restored in Settings.

Free and Personal require no Ohana account. Ohana has no ads or third-party analytics. Care records stay on the device unless you choose a restricted backup or export. Optional automatic backup writes an encrypted, restricted package to your own iCloud Drive and excludes Human health data.

Ohana helps organize care records and routines. It does not provide diagnosis, treatment, or emergency services.
```

### `de-DE`

- Name: `Ohana`
- Subtitle: `Alltagspflege für dein Zuhause`
- Keywords: `Tierpflege,Pflanzenpflege,Erinnerung,Medikamente,Spaziergang,Kalender,Tagebuch,Zuhause`

#### Description

```text
Ohana ist ein lokal ausgerichteter Pflegeplaner für Menschen, Tiere und Pflanzen in deinem Zuhause.

Halte Fütterung, Spaziergänge, Hygiene, Medikamente, Wohlbefinden, Ausgaben, Fotos, Dokumente, Meilensteine und Alltagsmomente an einem Ort fest. Plane Routinen mit Erinnerungen und Kalender. Erkenne Fortschritt in aktuellen Trends, Serien, Wochenübersichten und einer Insel, die mit deinen Einträgen wächst.

Ohana Free umfasst die grundlegende Pflegedokumentation, manuellen Export sowie 1 aktives Tier, 2 aktive Menschen, 5 aktive Pflanzen und 3 aktive Alltagspläne. Gesundheitlich wichtige Erinnerungen sind nicht begrenzt.

Ohana Personal ist optional. Es schaltet unbegrenzt viele aktive Profile und Alltagspläne, 90-Tage- und Gesamttrends, PDF-Zusammenfassungen für Tierarzttermine, Personal-Designs sowie lokale Scans von Laborberichten mit Einzelprüfung frei. Zur Wahl stehen monatlich, jährlich oder Lifetime als Einmalkauf. Preise und Angebotsberechtigung kommen aus dem App Store; Käufe lassen sich in den Einstellungen wiederherstellen.

Free und Personal benötigen kein Ohana-Konto. Ohana enthält keine Werbung und keine Analyse von Drittanbietern. Pflegedaten bleiben auf dem Gerät, sofern du nicht selbst ein eingeschränktes Backup oder einen Export startest. Das optionale automatische Backup schreibt ein verschlüsseltes, eingeschränktes Paket in dein eigenes iCloud Drive und schließt Gesundheitsdaten von Menschen aus.

Ohana hilft bei Dokumentation und Organisation. Die App bietet keine Diagnose, Behandlung oder Notfallhilfe.
```

### `es-ES`

- Name: `Ohana`
- Subtitle: `Cuidados para toda la casa`
- Keywords: `mascotas,plantas,cuidados,recordatorios,medicación,paseos,calendario,bienestar,hogar`

#### Description

```text
Ohana es un organizador de cuidados local para las personas, mascotas y plantas de tu hogar.

Reúne alimentación, paseos, higiene, medicación, bienestar, gastos, fotos, documentos, hitos y momentos cotidianos. Crea rutinas con recordatorios y calendario. Consulta tendencias recientes, rachas, resúmenes semanales y una isla que crece con cada cuidado registrado.

Ohana Free incluye registros esenciales, exportación manual, 1 mascota activa, 2 personas activas, 5 plantas activas y 3 planes cotidianos activos. Los recordatorios críticos de salud no tienen límite.

Ohana Personal es opcional. Desbloquea perfiles y planes cotidianos activos sin límite, tendencias de 90 días y de todo el historial, resúmenes veterinarios en PDF, estilos Personal y escaneo local de informes de laboratorio con revisión de cada resultado. Elige entre pago mensual, anual o Lifetime como compra única. Los precios y la elegibilidad de las ofertas proceden del App Store; puedes restaurar las compras en Ajustes.

Free y Personal no requieren una cuenta de Ohana. Ohana no tiene anuncios ni análisis de terceros. Los registros permanecen en el dispositivo salvo que elijas una copia restringida o una exportación. La copia automática opcional guarda un paquete cifrado y restringido en tu propio iCloud Drive y excluye los datos de salud de personas.

Ohana ayuda a organizar registros y rutinas de cuidado. No ofrece diagnóstico, tratamiento ni servicios de emergencia.
```

### `pt-BR`

- Name: `Ohana`
- Subtitle: `Cuidados para toda a casa`
- Keywords: `animais,plantas,cuidados,lembretes,medicação,passeios,calendário,bem-estar,casa`

#### Description

```text
Ohana é um organizador local de cuidados para pessoas, animais e plantas da sua casa.

Reúna alimentação, passeios, higiene, medicamentos, bem-estar, despesas, fotos, documentos, marcos e momentos do dia a dia. Crie rotinas com lembretes e calendário. Acompanhe tendências recentes, sequências, resumos semanais e uma ilha que cresce com cada cuidado registrado.

Ohana Free inclui registros essenciais, exportação manual, 1 animal ativo, 2 pessoas ativas, 5 plantas ativas e 3 planos cotidianos ativos. Lembretes críticos de saúde não têm limite.

Ohana Personal é opcional. Ele libera perfis e planos cotidianos ativos ilimitados, tendências de 90 dias e de todo o histórico, resumos veterinários em PDF, visuais Personal e digitalização local de exames laboratoriais com revisão item a item. Escolha mensal, anual ou Lifetime como compra única. Preços e elegibilidade de ofertas vêm da App Store; compras podem ser restauradas nos Ajustes.

Free e Personal não exigem uma conta Ohana. Ohana não tem anúncios nem análises de terceiros. Os registros ficam no aparelho, a menos que você escolha um backup restrito ou uma exportação. O backup automático opcional grava um pacote criptografado e restrito no seu próprio iCloud Drive e exclui dados de saúde de pessoas.

Ohana ajuda a organizar registros e rotinas de cuidado. Não fornece diagnóstico, tratamento nem serviços de emergência.
```

### `fr-FR`

- Name: `Ohana`
- Subtitle: `Le soin de toute la maison`
- Keywords: `animaux,plantes,soins,rappels,médicaments,promenades,calendrier,bien-être,foyer`

#### Description

```text
Ohana est un carnet de soins local pour les personnes, les animaux et les plantes de votre foyer.

Regroupez repas, promenades, hygiène, médicaments, bien-être, dépenses, photos, documents, étapes importantes et moments du quotidien. Créez des routines avec des rappels et un calendrier. Suivez les tendances récentes, les séries, les bilans hebdomadaires et une île qui grandit au fil des soins enregistrés.

Ohana Free comprend les dossiers essentiels, l’export manuel, 1 animal actif, 2 personnes actives, 5 plantes actives et 3 routines actives. Les rappels de santé essentiels ne sont pas limités.

Ohana Personal est facultatif. Il débloque un nombre illimité de profils et de routines actives, les tendances sur 90 jours et tout l’historique, des résumés vétérinaires en PDF, des styles Personal et la numérisation locale de comptes rendus de laboratoire avec vérification de chaque résultat. Choisissez une formule mensuelle, annuelle ou Lifetime en achat unique. Les prix et l’éligibilité aux offres viennent de l’App Store ; les achats peuvent être restaurés dans Réglages.

Free et Personal ne nécessitent aucun compte Ohana. Ohana ne contient ni publicité ni outil d’analyse tiers. Les données restent sur l’appareil, sauf si vous choisissez une sauvegarde restreinte ou un export. La sauvegarde automatique facultative écrit un paquet chiffré et restreint dans votre propre iCloud Drive et exclut les données de santé humaines.

Ohana aide à organiser les soins. L’app ne fournit ni diagnostic, ni traitement, ni service d’urgence.
```

### `ja-JP`

- Name: `Ohana`
- Subtitle: `家族・ペット・植物のケア記録`
- Keywords: `ペット,植物,家族,ケア,リマインダー,服薬,散歩,記録`

#### Description

```text
Ohanaは、家で暮らす人、ペット、植物のケアをまとめるローカル中心の記録アプリです。

食事、散歩、衛生、服薬、体調、支出、写真、書類、節目、日々の思い出をひとつに整理できます。リマインダーとカレンダーで習慣をつくり、最近の傾向、継続記録、週間まとめ、ケアの記録とともに育つ島で積み重ねを振り返れます。

Ohana Freeでは、基本のケア記録と手動エクスポートに加え、アクティブなペット1匹、人2人、植物5株、日常プラン3件を利用できます。健康上重要なリマインダーに件数制限はありません。

Ohana Personalは任意のアップグレードです。アクティブなプロフィールと日常プランの上限がなくなり、90日間・全期間の傾向、獣医向けPDF要約、Personalの外観、端末内での検査報告書のスキャンと項目ごとの確認を利用できます。月額、年額、または1回購入のLifetimeから選べます。価格とオファー対象資格はApp Storeから取得し、購入は設定から復元できます。

FreeとPersonalにOhanaアカウントは不要です。広告や第三者の解析ツールは使用しません。ケア記録は、ユーザーが制限付きバックアップやエクスポートを選ばない限り端末内に保存されます。任意の自動バックアップは、暗号化した制限付きパッケージを自分のiCloud Driveへ保存し、人の健康データを除外します。

Ohanaはケアの記録と予定整理を支援するアプリです。診断、治療、緊急サービスは提供しません。
```

### `ko-KR`

- Name: `Ohana`
- Subtitle: `가족·반려동물·식물 돌봄 기록`
- Keywords: `반려동물,식물,가족,돌봄,미리알림,복약,산책,달력,기록`

#### Description

```text
Ohana는 집에서 함께하는 사람, 반려동물, 식물의 돌봄을 정리하는 로컬 중심 기록 앱입니다.

급여, 산책, 위생, 복약, 상태, 지출, 사진, 문서, 기념일과 일상의 순간을 한곳에 모아 보세요. 미리 알림과 달력으로 루틴을 만들고, 최근 추세, 연속 기록, 주간 요약, 돌봄 기록과 함께 자라는 섬에서 변화를 확인할 수 있습니다.

Ohana Free에는 기본 돌봄 기록과 수동 내보내기, 활성 반려동물 1마리, 사람 2명, 식물 5개, 일상 플랜 3개가 포함됩니다. 건강상 중요한 미리 알림은 개수 제한이 없습니다.

Ohana Personal은 선택 사항입니다. 활성 프로필과 일상 플랜을 제한 없이 이용하고, 90일 및 전체 기간 추세, 수의사용 PDF 요약, Personal 디자인, 기기 내 검사 보고서 스캔과 항목별 검토를 사용할 수 있습니다. 월간, 연간 또는 일회성 Lifetime 구매 중에서 선택하세요. 가격과 혜택 대상 여부는 App Store에서 제공하며, 설정에서 구매를 복원할 수 있습니다.

Free와 Personal은 Ohana 계정이 필요하지 않습니다. 광고와 제3자 분석 도구를 사용하지 않습니다. 사용자가 제한 백업이나 내보내기를 선택하지 않는 한 돌봄 기록은 기기에 남습니다. 선택형 자동 백업은 암호화된 제한 패키지를 사용자의 iCloud Drive에 저장하며 사람의 건강 데이터는 제외합니다.

Ohana는 돌봄 기록과 일정을 정리하는 앱입니다. 진단, 치료 또는 응급 서비스를 제공하지 않습니다.
```

### `it-IT`

- Name: `Ohana`
- Subtitle: `Cura quotidiana della casa`
- Keywords: `animali,piante,cura,promemoria,farmaci,passeggiate,calendario,benessere,famiglia`

#### Description

```text
Ohana è un organizzatore locale per la cura di persone, animali e piante della tua casa.

Riunisci alimentazione, passeggiate, igiene, farmaci, benessere, spese, foto, documenti, traguardi e momenti quotidiani. Crea routine con promemoria e calendario. Segui tendenze recenti, serie, riepiloghi settimanali e un’isola che cresce con ogni cura registrata.

Ohana Free include registri essenziali, esportazione manuale, 1 animale attivo, 2 persone attive, 5 piante attive e 3 piani quotidiani attivi. I promemoria sanitari essenziali non hanno limiti.

Ohana Personal è facoltativo. Sblocca profili e piani quotidiani attivi senza limiti, tendenze a 90 giorni e dell’intero storico, riepiloghi veterinari in PDF, stili Personal e scansione locale dei referti di laboratorio con revisione di ogni risultato. Scegli tra mensile, annuale o Lifetime come acquisto unico. Prezzi e idoneità alle offerte provengono dall’App Store; puoi ripristinare gli acquisti nelle Impostazioni.

Free e Personal non richiedono un account Ohana. Ohana non contiene pubblicità né strumenti di analisi di terze parti. I registri restano sul dispositivo, a meno che tu scelga un backup limitato o un’esportazione. Il backup automatico facoltativo salva un pacchetto cifrato e limitato nel tuo iCloud Drive ed esclude i dati sanitari delle persone.

Ohana aiuta a organizzare registri e routine di cura. Non fornisce diagnosi, trattamenti o servizi di emergenza.
```

### 共用 URL 字段

- Support URL:
  `https://github.com/VeitL/Ohana/blob/main/docs/support.md`
- Privacy Policy URL:
  `https://github.com/VeitL/Ohana/blob/main/docs/privacy-policy.md`
- Marketing URL: 留空，直到有经过发布负责人确认的公开页面。
- Promotional Text: 首发可留空；不要用它补充未来承诺。
- What’s New: 1.0 首发不需要编造更新说明。
- App Preview: 1.0 不提供；首发只使用静态截图。

## 4. Personal 商品与 legacy 恢复的九语言 IAP 元数据

Apple 的 [IAP 信息规范](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information/)
要求 Display Name 为 2–30 字符、Description 不超过 45 字符。自动续订商品应按
[Offer auto-renewable subscriptions](https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions/)
创建并随首个 App 版本一起送审。

### 4.1 商品结构

| 商品 | Reference Name 草案 | 类型 | Product ID | 周期/权益 |
| --- | --- | --- | --- | --- |
| Personal Monthly | `Ohana Personal Monthly` | Auto-Renewable Subscription | `com.guanchen.li.Ohana.personal.monthly` | 1 个月；无默认试用 |
| Personal Yearly | `Ohana Personal Yearly` | Auto-Renewable Subscription | `com.guanchen.li.Ohana.personal.yearly` | 1 年；仅符合资格的新订阅者显示 14 天免费试用 |
| Personal Lifetime | `Ohana Personal Lifetime` | Non-Consumable | `com.guanchen.li.Ohana.personal.lifetime` | 一次购买；当前 build 的本地 Personal 权益 |
| Supporter Pack（legacy） | 使用账号内既有 Reference Name，不猜测或重建 | Non-Consumable；restore-only | `com.guanchen.li.Ohana.supporterPack` | 只恢复已验证的历史购买并授予 Personal Lifetime；不得新售 |

配置要求：

- Monthly 和 Yearly 放入同一个订阅组。
- Subscription Group Reference Name 建议使用内部值 `Ohana Personal`。
- Subscription Group Display Name 在九种语言均使用 `Ohana Personal`。
- Monthly 和 Yearly 提供相同权益、不同周期，应处于相同 subscription level。
- 三个 Personal 商品与 legacy `supporterPack` 的 App Store Family Sharing 均保持关闭。
- Yearly 的试用由 App Store Connect 配置和 StoreKit 资格决定；App 不硬编码资格。
- 仓库目标价格为 €2.99 / 月、€14.99 / 年、€49.99 Lifetime，但这不是外部配置证据。
  只有 App Store Connect 中实际保存的价格档位和各 Storefront 显示价格才可发布。
- 不创建额外“折扣 Lifetime”SKU；任何优惠必须使用 Apple 支持的真实 offer。
- 1.0 不启用 Promoted In-App Purchases，也不配置 win-back offers，因此不准备
  1024×1024 IAP promotional image。此决定不取消 Monthly、Yearly、Lifetime 各自必需
  的 App Review Screenshot。
- 若 `supporterPack` 确实曾在生产销售，保留其九语言元数据、`currentEntitlements`
  恢复和停售状态，不把它加入新售商品入口。若从未存在任何生产购买历史，账号持有人
  必须在提交前明确这一事实，并统一处置代码、审核备注和恢复承诺，不能同时声称
  “历史购买可恢复”又不存在可恢复商品。

### 4.2 `zh-Hans`

| 项目 | Display Name | Description |
| --- | --- | --- |
| Subscription Group | `Ohana Personal` | — |
| Monthly | `Ohana Personal 月付` | `按月使用 Ohana Personal 功能` |
| Yearly | `Ohana Personal 年付` | `按年使用 Ohana Personal 功能` |
| Lifetime | `Ohana Personal 永久版` | `一次购买，永久使用当前 Personal 功能` |

### 4.3 `en-US`

| 项目 | Display Name | Description |
| --- | --- | --- |
| Subscription Group | `Ohana Personal` | — |
| Monthly | `Ohana Personal Monthly` | `Monthly access to Ohana Personal.` |
| Yearly | `Ohana Personal Yearly` | `Yearly access to Ohana Personal.` |
| Lifetime | `Ohana Personal Lifetime` | `One purchase for current Personal features.` |

### 4.4 `de-DE`

| 项目 | Display Name | Description |
| --- | --- | --- |
| Subscription Group | `Ohana Personal` | — |
| Monthly | `Ohana Personal monatlich` | `Monatlicher Zugriff auf Ohana Personal.` |
| Yearly | `Ohana Personal jährlich` | `Jährlicher Zugriff auf Ohana Personal.` |
| Lifetime | `Ohana Personal dauerhaft` | `Einmalkauf für aktuelle Personal-Funktionen.` |

### 4.5 `es-ES`

| 项目 | Display Name | Description |
| --- | --- | --- |
| Subscription Group | `Ohana Personal` | — |
| Monthly | `Ohana Personal mensual` | `Acceso mensual a Ohana Personal.` |
| Yearly | `Ohana Personal anual` | `Acceso anual a Ohana Personal.` |
| Lifetime | `Ohana Personal de por vida` | `Compra única: funciones Personal actuales.` |

### 4.6 `pt-BR`

| 项目 | Display Name | Description |
| --- | --- | --- |
| Subscription Group | `Ohana Personal` | — |
| Monthly | `Ohana Personal mensal` | `Acesso mensal ao Ohana Personal.` |
| Yearly | `Ohana Personal anual` | `Acesso anual ao Ohana Personal.` |
| Lifetime | `Ohana Personal vitalício` | `Compra única: recursos Personal atuais.` |

### 4.7 `fr-FR`

| 项目 | Display Name | Description |
| --- | --- | --- |
| Subscription Group | `Ohana Personal` | — |
| Monthly | `Ohana Personal mensuel` | `Accès mensuel à Ohana Personal.` |
| Yearly | `Ohana Personal annuel` | `Accès annuel à Ohana Personal.` |
| Lifetime | `Ohana Personal à vie` | `Achat unique : fonctions Personal actuelles.` |

### 4.8 `ja-JP`

| 项目 | Display Name | Description |
| --- | --- | --- |
| Subscription Group | `Ohana Personal` | — |
| Monthly | `Ohana Personal 月額` | `月ごとにOhana Personalを利用できます` |
| Yearly | `Ohana Personal 年額` | `1年ごとにOhana Personalを利用できます` |
| Lifetime | `Ohana Personal 買い切り` | `1回の購入で現在のPersonal機能を利用できます` |

### 4.9 `ko-KR`

| 项目 | Display Name | Description |
| --- | --- | --- |
| Subscription Group | `Ohana Personal` | — |
| Monthly | `Ohana Personal 월간` | `월간 Ohana Personal 이용권` |
| Yearly | `Ohana Personal 연간` | `연간 Ohana Personal 이용권` |
| Lifetime | `Ohana Personal 평생 이용권` | `한 번 구매로 현재 Personal 기능 이용` |

### 4.10 `it-IT`

| 项目 | Display Name | Description |
| --- | --- | --- |
| Subscription Group | `Ohana Personal` | — |
| Monthly | `Ohana Personal mensile` | `Accesso mensile a Ohana Personal.` |
| Yearly | `Ohana Personal annuale` | `Accesso annuale a Ohana Personal.` |
| Lifetime | `Ohana Personal a vita` | `Acquisto unico: funzioni Personal attuali.` |

### 4.11 Legacy Supporter Pack（restore-only）

以下字符串来自当前 `.storekit` 配置，仅用于核对既有商品；不要将该商品重新开放销售。

| Locale | Display Name | Description |
| --- | --- | --- |
| `zh-Hans` | `Ohana 支持者礼包（旧版）` | `已验证的历史购买可恢复 Personal 永久权益` |
| `en-US` | `Ohana Supporter Pack (Legacy)` | `Previous purchase grants Personal Lifetime.` |
| `de-DE` | `Ohana Supporter-Paket (alt)` | `Früherer Kauf gewährt Personal dauerhaft.` |
| `es-ES` | `Pack de apoyo Ohana (antiguo)` | `Compra anterior: Personal de por vida.` |
| `pt-BR` | `Pacote de apoio Ohana (antigo)` | `A compra anterior dá Personal vitalício.` |
| `fr-FR` | `Pack de soutien Ohana (ancien)` | `Un ancien achat donne Personal à vie.` |
| `ja-JP` | `Ohana サポーターパック（旧商品）` | `以前の購入はPersonal買い切りとして有効です` |
| `ko-KR` | `Ohana 서포터 팩(이전 상품)` | `기존 구매는 Personal 평생 이용권으로 인정됩니다.` |
| `it-IT` | `Pacchetto Ohana (precedente)` | `L'acquisto precedente dà Personal a vita.` |

## 5. 可直接粘贴的 Review Notes

### 5.1 App Review Notes（英文，原样粘贴）

源码 G1 清理已完成。仅在最终 signed Archive 与 Developer Portal/profile 确认未重新
引入 Sign in with Apple、APNs、`remote-notification` 或 Guardian keys 后复制；
外部签名门禁未关闭时保持 NO-GO。

下列英文中的 legacy Supporter 两句，仅在账号持有人确认
`com.guanchen.li.Ohana.supporterPack` 有真实生产购买历史时保留；若无生产历史，
删除这两句，不重建该 SKU，也不要向审核员承诺历史恢复。

```text
Ohana 1.0 is an iPhone-only, local-first household care app. No Ohana account or review credentials are required.

First launch:
1. Choose Standard or Zen.
2. Enter any name for the local Human profile.
3. In Standard, choose Later if you do not want to create a pet.
4. Finish onboarding to reach the main interface.

In-App Purchases:
1. Open Settings from the main interface.
2. Tap "Ohana Personal".
3. The screen loads Monthly, Yearly, and Lifetime products from StoreKit.
4. Select a product and use the purchase button. "Restore Purchases" is on the same screen.

Lab-report scanning:
1. Use a verified Personal entitlement from any of the three products above.
2. Return to the main interface, open a Human profile, then open Health Report or Checkup.
3. Tap "Scan Lab Report" and choose the document camera or Photos.
4. Review each recognized item individually. Every item starts unconfirmed; edit its value, unit, or reference range when needed, then explicitly confirm only the items to save.

Without a Personal entitlement, the same scan entry opens the Personal explanation and the import command remains fail-closed. Free users can still create and edit basic Human health reports and metrics manually. A downgrade never hides or deletes previously confirmed structured results.

All three products unlock the same Personal feature set in this build: unlimited active pet, Human, plant, and everyday-plan counts; 90-day and all-time trends; veterinary PDF summaries; Personal appearance options; and on-device lab-report scanning with item-by-item review. Source images and recognized text are not uploaded or persisted. Monthly and Yearly are auto-renewable. Yearly presents a 14-day free trial only when the signed StoreKit product reports the reviewer account as eligible. Lifetime is a one-time non-consumable purchase. Prices and offer eligibility are never hard-coded.

Purchases are handled by StoreKit and verified before access is granted. A cancelled, pending, failed, or unverified transaction does not unlock access. Restore calls AppStore.sync() and then rechecks verified current entitlements. Existing local care data remains available if a subscription expires or a transaction is revoked.

A verified historical purchase of com.guanchen.li.Ohana.supporterPack restores
Personal Lifetime. That legacy product is not offered for new purchase.

Permissions are requested only when the reviewer opens a feature that needs them. Location is used for a walk route and can continue during an active walk. Health access is optional and read-only. Camera and Photos are used only after the reviewer chooses an image or attachment, or explicitly starts the Personal lab-report flow described above. Lab pages and complete recognized text stay in volatile memory for on-device processing; they are not uploaded or persisted. Only item-by-item confirmed structured results are saved locally. Notifications are for local reminders.

Ohana Family guardian, remote guardian notifications, CloudKit collaboration, native iPad/watchOS apps, and Care+ are not part of this submission.

Ohana is not a medical device and does not provide diagnosis or emergency services.
```

如果最终 RC 的菜单标题、首次启动步骤、权限或 Personal 能力发生变化，必须先修改
Review Notes；不能让审核员按旧路径查找。

### 5.2 IAP Review Notes

#### Personal Monthly

```text
Open Ohana, complete the no-login onboarding, then go to Settings > Ohana Personal. Select Monthly and tap the purchase button. This one-month auto-renewable subscription unlocks the Personal features shown on that screen. It has no introductory offer. Access is granted only after StoreKit returns a verified transaction. Restore Purchases is available on the same screen. The attached review screenshot must come from the final RC and show the Monthly option selected with its real StoreKit price.
```

#### Personal Yearly

```text
Open Ohana, complete the no-login onboarding, then go to Settings > Ohana Personal. Select Yearly and tap the purchase button. This one-year auto-renewable subscription unlocks the Personal features shown on that screen. A 14-day free trial is displayed only when StoreKit reports that the reviewer account is eligible. Access is granted only after a verified transaction. Restore Purchases is available on the same screen. The attached review screenshot must come from the final RC and show the Yearly option selected with its real StoreKit price and eligible offer state.
```

#### Personal Lifetime

```text
Open Ohana, complete the no-login onboarding, then go to Settings > Ohana Personal. Select Lifetime and tap the purchase button. This is a non-consumable one-time purchase for the Personal features shown in this build. It is not an auto-renewable subscription. Access is granted only after StoreKit returns a verified transaction, and it can be restored from the same screen. The attached review screenshot must come from the final RC and show the Lifetime option selected with its real StoreKit price.
```

#### Legacy Supporter Pack（restore-only）

```text
This legacy non-consumable is not offered for new purchase. If it exists in the production catalog, a reviewer account with a verified historical entitlement for com.guanchen.li.Ohana.supporterPack can open Settings > Ohana Personal and tap Restore Purchases; the app maps that entitlement to Personal Lifetime. Keep the product unavailable for new sale. If no production purchase history exists, do not submit or recreate this SKU; remove the historical-restore claim from the final review metadata instead.
```

### 5.3 Review Information 仍需账号持有人填写

- Contact First Name / Last Name。
- 可在审核期间接听的 Phone Number。
- 可及时收件的 Email。
- Demo Account：选择“不需要”，不要编造账号密码。
- Notes 中不要放内部测试口令、真实用户资料或完整购买收据。

## 6. 截图采集计划

Apple 接受每种设备尺寸 1–10 张 JPG/PNG，不允许 alpha。具体尺寸见
[Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)；
上传流程见
[Upload app previews and screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/)。

### 6.1 公开展示截图

使用最高要求的 6.9 英寸 iPhone 竖屏尺寸之一：

- `1260 × 2736`
- `1290 × 2796`
- `1320 × 2868`

建议 6 张，全部来自同一个最终 Release RC：

| 顺序 | 场景 | 必须显示 | 必须避开 |
| --- | --- | --- | --- |
| 1 | Standard 首页 | 家庭岛屿、今天的轻量行动、真实本地示例数据 | 调试角标、未来入口、通知权限弹窗 |
| 2 | 快速照护 | 一次喂食/散步/清洁记录与即时反馈 | 真实地址、真实人物/宠物资料 |
| 3 | 日历与提醒 | 日常计划、近期事项、完成状态 | 夸大远程通知或多人协作 |
| 4 | 趋势与历史 | Free 可达的近期趋势和原始历史 | 把医疗信息写成诊断结论 |
| 5 | 档案与回忆 | 人、宠物或植物档案，照片/里程碑等本地记录 | 私密健康、位置、票据、证件数据 |
| 6 | Zen | 每日状态/植物/连续记录的克制界面 | 暗示它会改变奖励倍率或替代照护 |

采集规则：

- 每种语言至少打开对应 App 语言后检查标题、按钮、截断和动态数据；首发若上传九套
  截图，逐语言使用同一场景顺序。
- 只使用合成、虚构且不对应真实个人的数据。
- 不展示测试 StoreKit 配置、沙盒横幅、开发者菜单、测试种子按钮或内部诊断。
- 不加入未在当前 build 中可达的功能、设备外框或不准确的系统状态栏。
- 若添加文字覆盖层，必须逐语言本地化，且不能覆盖系统/产品关键信息。
- PNG/JPG 必须为 RGB、扁平化且无透明通道。
- 上传后逐语言在 Product Page Preview 中检查实际排序与裁切。

### 6.2 IAP 审核截图

每个商品各上传一张只供审核使用的截图：

1. 从最终签名 RC 打开 `Settings > Ohana Personal`。
2. 连接真实 Sandbox/App Store 测试环境，不使用本地 `.storekit` 价格。
3. 分别选中 Monthly、Yearly、Lifetime。
4. 截图同时显示商品选择、StoreKit 本地化价格、购买按钮，以及页面可识别标题。
5. Yearly 另确认符合资格账号的 14 天试用状态；不符合资格时不要伪造。
6. 截图不得包含 Sandbox Apple Account 邮箱、交易 ID、收据或个人数据。

IAP review screenshot 上传后可替换但不能移除；三张截图在送审前应与第 5.2 节说明逐项
一致。

## 7. 隐私、年龄、出口与合规字段

本节把“代码能支持的事实”和“必须由账号/法律持有人确认的选择”分开。App Store
Connect 的回答必须匹配最终 RC，而不是匹配计划中的产品。

### 7.1 App Privacy

Apple 要求为所有 App 发布隐私回答，操作说明见
[Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)。

#### 仓库证据

- Free / Personal 不要求开发者托管账号。
- 普通照护记录存储在本机；用户主动选择时才导出或写入自己的 iCloud Drive。
- Personal 化验单页面与完整 OCR 文本只在当前端侧导入流程的易失内存中存在；不上传、
  不持久化，也不进入附件、日志、Widget、Live Activity、通知或受限外部备份。只有用户
  逐项确认的结构化报告与指标才原子保存到本机；Free 可继续手工维护基础健康记录。
- App 没有第三方广告或分析 SDK。
- Apple 通过 StoreKit 处理付款；开发者不读取银行卡、账单地址或 Apple Account 密码。
- 当前仓库内 `Ohana/PrivacyInfo.xcprivacy` 的
  `NSPrivacyCollectedDataTypes` 为空，并声明 UserDefaults `CA92.1`、File Timestamp
  `C617.1`、System Boot Time `35F9.1` 三项 required-reason API。
- 当前仓库内隐私政策已收敛为 Free / Personal 1.0；远端公开 URL 仍须在提交前发布
  这一版本并匿名复核。

#### 目标答案及发布前置

目标 Free + Personal RC 在同时满足以下条件后，才可选择：

`No, we do not collect data from this app.`

前置条件：

1. 最终发行路径不上传开发者可访问的数据，且没有第三方 SDK 收集数据。
2. 最终 Archive 的 Privacy Report、主 App/扩展 privacy manifest 和二进制扫描与此一致。
3. `NSPrivacyCollectedDataTypes` 与最终真实行为一致，并保持不随 1.0 出货的数据流为空。
4. 将仓库内已对齐的 Free / Personal 隐私政策发布到 App 内链接指向的公开 URL。
5. 账号持有人在 Product Page Preview 中复核并 Publish。

如果最终 RC 仍有任何开发者或第三方可访问的数据传输，则不得使用上面的回答；必须
选择 `Yes`，按最终数据流逐类披露用途、是否 linked、是否 tracking。不要为了获得
“Data Not Collected”标签隐瞒实际行为。

### 7.2 Age Rating

Apple 会根据问卷计算分级，不能手填一个希望值。流程见
[Set an app age rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/)。

#### 基于当前 Free + Personal 功能的候选答案

| 问卷领域 | 候选回答 | 依据 |
| --- | --- | --- |
| Parental Controls / Age Assurance | No | App 没有该控制 |
| User-Generated Content | No | 没有公开社区、上传内容流或陌生人内容 |
| Messaging and Chat | No | 没有聊天 |
| Advertising | No | 无广告 |
| Unrestricted Web Access | No | 仅有明确的政策、支持和系统页面链接 |
| Social Media capability | No | 没有社交媒体功能 |
| Profanity, Sexual Content, Nudity | None | 当前产品无此内容 |
| Horror/Fear, Violence, Weapons | None | 当前产品无此内容 |
| Alcohol, Tobacco, Drugs | None | 当前产品无此内容 |
| Medical or Treatment Information | Infrequent | 有用药/健康记录和照护提示，但不提供诊断 |
| Contests / Simulated Gambling | None | 无竞赛或下注 |
| Gambling | No | 无真钱赌博 |
| Loot Boxes | No | 椰子不能用真钱购买，随机装饰不以真钱出售 |
| Made for Kids | Not Applicable | 不是 Kids Category 产品 |
| Override to Higher Rating | Not Applicable | 除非实际 EULA/法规要求更高分级 |

账号持有人必须在最终 RC 上逐页完成问卷并保存 Apple 计算出的全球/地区分级；不要在
本文预先声称某个具体年龄值。若功能、随机奖励或健康内容发生变化，重新评估答案。

### 7.3 Export Compliance

Apple 的
[Overview of export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/)
说明：使用标准算法或 Apple OS 加密能力也必须先做出口合规判断。

#### 仓库证据

- App 使用标准 AES-GCM 与 PBKDF2 保护用户选择的备份。
- App 使用 Apple CryptoKit/CommonCrypto 和系统网络/StoreKit 安全能力。
- 未发现自创或未公开的非标准密码算法。
- 当前项目没有可据此自动跳过问卷的已确认
  `ITSAppUsesNonExemptEncryption` 发行结论。

#### 账号持有人/法律确认

1. 在 App Store Connect 对最终 build 回答实际加密用途。
2. 确认标准备份加密是否符合适用的美国出口豁免及目标地区进口要求。
3. 只有确认“不需要出口文档/属于豁免”后，才在最终 Info.plist 设置对应声明。
4. 若 Apple 要求文档，先上传并获得批准，再把 Apple 提供的 key 关联到 build。
5. 本文件不代替出口管制法律意见，也不把 `ITSAppUsesNonExemptEncryption = NO`
   预填为事实。

### 7.4 EU Digital Services Act

Apple 的
[DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/)
要求无论是否在 EU 分发都声明 trader status；Apple 不能替开发者决定该身份。

必须由 Account Holder/Admin 确认：

- 是否以 trade/business/craft/profession 目的提供 Ohana。
- App 内购买收入、商业推广、VAT/商业登记等因素是否使账户属于 trader。
- 若为 trader：完成地址、电话、邮箱、付款账户和证明文件验证，并确认 EU 产品合规。
- 若非 trader：确认该法律判断及 EU 产品页将展示的消费者提示。
- 每个 App 的 DSA 状态和 EU Storefront availability 是否一致。

不要在未确认法定身份、地址、电话或组织名称时填写占位值。

## 8. 账号持有人 Go/No-Go 确认

### 8.1 商业与合同

- [ ] Paid Apps Agreement 已生效。
- [ ] Tax 与 Banking 状态有效，可销售 IAP。
- [ ] App 价格实际为 Free。
- [ ] Monthly / Yearly / Lifetime 已用本文 Product ID 创建。
- [ ] 已确认 legacy `supporterPack` 是否确有生产购买历史；若有，保持停售但可恢复；
  若无，统一移除所有历史恢复承诺。
- [ ] Monthly / Yearly 位于同一订阅组、同一权益 level。
- [ ] Yearly 的 14 天 introductory offer 已按计划配置；Monthly 无默认试用。
- [ ] 三个商品的实际价格档位、税务类别、地区和可售状态已人工复核。
- [ ] 三个商品的 App Store Family Sharing 关闭。
- [ ] 首个订阅、订阅组和 Lifetime 已与 1.0 App version 加入同一 submission。
- [ ] 每个商品已有最终 RC 的 review screenshot 和第 5.2 节 notes。
- [ ] 若 legacy `supporterPack` 存在，已用有历史权益的真实账号路径证明 Restore
  后获得 Personal Lifetime，且新用户看不到购买入口。

### 8.2 App 信息

- [ ] Apple ID、SKU、Primary Language、Copyright 使用真实账户值。
- [ ] App Review 联系人、电话和邮箱在审核期可用。
- [ ] Primary/Secondary Category 与真实产品一致。
- [ ] Support URL 与 Privacy Policy URL 可匿名公开访问。
- [ ] 九种语言元数据已经过最终人工语言检查。
- [ ] 九种语言截图已上传，或已明确接受 Apple 的语言回退行为。
- [ ] App Privacy 已基于最终 Archive 发布。
- [ ] Age Rating 问卷已基于最终 RC 保存。
- [ ] Export Compliance 已由有权人员确认。
- [ ] DSA trader status 与 EU availability 已确认。
- [ ] 内容权利、照片、图标、字体和商店截图均有分发权。
- [ ] 若选择 Health & Fitness/Medical 类别，已完成 Apple 要求的相关声明；否则不误选。

### 8.3 最终二进制与审核一致性

- [ ] App version/build、Bundle ID 和签名 Archive 与第 2 节一致。
- [ ] 最终 build 不包含测试 StoreKit 配置、测试数据开关或调试入口。
- [ ] 购买、取消、pending、失败、恢复、过期、退款/撤销和第二设备恢复已有外部证据。
- [ ] 所有商品在真实 Storefront 返回本地化名称、周期、价格和 offer。
- [ ] Review Notes 的每一步都在最终 RC 上按正常 UI 走通。
- [ ] 截图中没有未出货功能、真实个人资料或不准确价格。

任一方框无法确认时保持 No-Go；不要用本文草案替代缺失的外部证据。

## 9. 自动验证与本次结果

### 9.1 建议验证

对本文件运行：

```bash
git diff --check -- docs/app-store-connect-submission-package.md
perl -ne 'if (/[ \t]+$/) { print "$.:$_"; $bad=1 } END { exit($bad || 0) }' docs/app-store-connect-submission-package.md
scripts/audit-doc-status-ledgers.sh
```

长度检查应至少做到：

1. 按 locale 解析 Name、Subtitle、Keywords 和 Description。
2. 对 Name/Subtitle/IAP 文案同时报告 grapheme clusters 与 Unicode code points。
3. 对 Keywords 使用 `bytesize`，上限 100 UTF-8 bytes。
4. 对 Description 和 Review Notes 同时报告字符与 UTF-8 bytes。
5. 校验 9 个 locale 齐全，且每个 locale 都有 3 个 Personal 商品和 1 组条件式
   restore-only legacy 草案；无真实生产历史时不创建或提交 legacy 商品。

Apple 服务端仍是最终裁决者；复制到 App Store Connect 后必须再看字段的实时计数器和
错误提示。

### 9.2 本次自动检查结果

本次检查使用 `Intl.Segmenter(..., { granularity: "grapheme" })`、Unicode code
points 与 Node `Buffer.byteLength(..., "utf8")` 三种计数。若后续修改任何商店文案，
必须重新运行；以下结果不能继承给修改后的文本。

| 检查 | 结果 |
| --- | --- |
| 9 个 App locale | PASS，9/9 |
| Name ≤ 30 chars | PASS；最大 5 graphemes / 5 code points |
| Subtitle ≤ 30 chars | PASS；最大为 `de-DE`，30/30 |
| Description ≤ 4,000 chars | PASS；最大字符数为 `de-DE` 1,549；最大 UTF-8 为 `ja-JP` 1,728 bytes |
| Keywords ≤ 100 UTF-8 bytes | PASS；最大为 `en-US` 89 bytes |
| 36 组 IAP display name/description | PASS，36/36；Display Name 最大 30，Description 最大 44 |
| App Review Notes | PASS；3,184 chars / 3,184 bytes |
| 4 组 IAP Review Notes | PASS；Monthly 499、Yearly 573、Lifetime 502、legacy 508 chars/bytes |
| 文档 URL | PASS；17 个唯一 HTTPS URL 均返回 HTTP 200 |
| Markdown 相对链接 | PASS；本文无相对链接 |
| trailing whitespace | PASS，0 处 |
| status-ledger audit | PASS |

## 10. Apple 官方参考

- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/)
- [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)
- [Required, localizable, and editable properties](https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties/)
- [In-App Purchase information](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information/)
- [Auto-renewable subscription information](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/auto-renewable-subscription-information/)
- [Offer auto-renewable subscriptions](https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions/)
- [Overview of submitting for review](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/overview-of-submitting-for-review/)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
- [Set an app age rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/)
- [Overview of export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/)
- [DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/)
- [Apple Standard EULA](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/)
