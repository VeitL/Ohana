# Ohana 宠物头像生成规范与 Prompt 手册 v2.0

> 本文档用于统一 Ohana App 默认宠物头像的预生成规范。  
> **视觉风格以当前对话中确认的“拟人化 3D 毛绒玩偶吉祥物形象”为最高优先级**；品种、毛色、性别、文件命名、透明 PNG 画布、App 展示需求等以原头像组合清单为基础扩展。

---

## 1. 文档目标

Ohana 需要一套视觉统一、适合 iOS 宠物卡片展示的默认宠物头像资产。头像资产只支持用户根据以下字段切换：

- species：`dog` / `cat`
- breed：犬猫品种
- gender：`boy` / `girl`
- coat：毛色 / 花纹
- eye：不作为资产维度；所有头像统一黑色卡通眼睛

每一个有效组合生成一张透明背景 PNG。资源将放入 App Bundle 的 `PetAvatarAssets/` 中，并通过 Swift 侧静态索引读取。

生成方式要求：正式入库头像必须逐张独立生成。不能用单张底图批量换毛色、换瞳色或做后期批量涂色来代替独立渲染。

---

## 2. 视觉风格总定义

### 2.1 风格名称

**拟人化 3D 毛绒玩偶吉祥物风格**  
英文可描述为：**anthropomorphic 3D plush toy mascot character**。

### 2.2 核心视觉 DNA

| 维度 | 规范 |
|---|---|
| 整体风格 | 高清 3D CGI 渲染，玩偶产品图质感，像高级毛绒公仔 / 品牌 IP 吉祥物 |
| 比例 | 大头小身 Q 版比例，头部明显偏大，身体短小圆润 |
| 身体 | 四肢短而可爱，脚掌和手掌圆滚滚，整体轮廓柔和 |
| 材质 | 柔软短绒毛，细腻毛绒纤维，plush toy / stuffed animal / soft fabric doll 质感 |
| 脸部 | 圆润可爱，表情生动，有亲和力；允许半眯眼、侧眼、坏笑、托脸、眨眼等更多元表情，但不写实、不恐怖、不攻击性 |
| 眼睛 | 夸张大号卡通眼，**眼白保持白色**，统一黑色虹膜观感和黑色卡通瞳孔，明显高光 |
| 姿势 | 像人一样站立，先根据物种与品种特性决定姿势和表情，再叠加性别气质；允许抱胸、交叉腿、半侧身、托脸、挥手、轻街头感站姿等 |
| 服装 | 简单可爱、轻量装饰，允许更多元的轻街头/学院/软萌穿搭，不遮挡毛色、眼睛和品种轮廓；禁止鞋子和袜子，必须露出圆润毛绒脚掌 / 爪爪 |
| 背景 | 最终交付必须是真透明 alpha，无纯色底、无渐变底、无场景、无文字、无水印 |
| 用途 | 宠物头像、贴纸、品牌吉祥物、App 卡片默认头像 |

---

## 3. 最高优先级主 Prompt

这一段是全批次生成时必须继承的主风格 prompt。每张图只替换变量，不改变整体画风。

```text
Generate an anthropomorphic 3D plush toy mascot character of a <species> <breed>.
The character must be a full-body standing character, centered in the image, fully visible from head to feet.
Use big-head-small-body chibi proportions: an oversized rounded head, compact small body, short rounded limbs, soft rounded paws, and a cute toy-like silhouette.
The character should look like a premium stuffed animal mascot or adorable brand IP character, not a realistic animal.

The character has soft short plush fur, visible fine fuzzy fabric fibers, velvet-like plush texture, and high-quality stuffed animal material.
The face is round, cute, expressive, and friendly.
The eyes are oversized cartoon eyes with clearly visible pure white sclera, a black iris appearance, a large black cartoon pupil, and bright glossy eye highlights.
The eyes must not have colored sclera or colored irises.

The character stands upright like a human and poses in a cute anthropomorphic way.
Choose the expression and pose from the breed's personality and physical traits first, then apply gender styling: boy avatars should feel cooler, more confident, and stylish; girl avatars should feel cuter, sweeter, and more charming.
Dress the character in simple cute clothing or light accessories based on breed and gender, while keeping coat color, eyes, ears, face shape, tail, and breed silhouette clearly visible.
Strict footwear rule: no shoes, no sneakers, no boots, no socks, no sandals, no slippers, and no shoe soles. The character must be barefoot as an animal, with visible rounded furry plush paws/feet integrated with the legs.

Overall style: high-resolution 3D CGI render, premium plush mascot character design, toy product render quality, soft studio lighting, soft shadows, sharp clean edges, detailed fur texture, polished app avatar quality.
Transparent PNG background, no scenery, no floor, no text, no watermark.
The result should feel cute, fluffy, rounded, healing, friendly, and suitable for an iOS pet avatar and Ohana brand mascot system.
```

---

## 4. 中文主 Prompt 模板

```text
生成一个 <species_cn> <breed_cn> 的拟人化 3D 毛绒玩偶吉祥物形象。
角色为全身站姿，主体居中，完整可见，大头小身 Q 版比例，头部明显偏大，身体短小圆润，四肢短而可爱，脚掌和手掌圆滚滚。
整体像高级毛绒公仔或品牌 IP 吉祥物，而不是写实动物。

角色拥有柔软的短绒毛质感，表面有细腻的毛绒纤维，材质像 plush toy、stuffed animal、soft fabric doll。
脸部圆润可爱，眼睛为夸张的大号卡通眼睛，眼白必须保持纯白色，虹膜观感统一为黑色，瞳孔为更卡通的黑色大圆瞳，眼睛有清晰高光。
注意：不要生成绿色、蓝色、黄色或异瞳等彩色虹膜，也不要把眼白染色。

表情和姿势必须先根据品种特性决定，再叠加性别气质：男生整体偏酷酷风、自信、有态度；女生整体偏可爱风、甜美、灵动。可为傲娇微笑、开心吐舌、无辜大眼、慵懒半眯眼、害羞微笑等，但不能让性别风格覆盖品种性格。
角色采用拟人化姿势，像人一样站立，根据物种与品种特性摆出不同姿势，比如双手抱胸、双手托脸、歪头站立、交叉腿、挥手、自信站姿。
穿着简单可爱的衣服或轻量配饰，比如白色 T 恤和红色短裤、白色 T 恤和粉色百褶裙、连帽衫、背带裤、小围巾、蝴蝶结等，衣服同样有柔软布料质感。禁止穿鞋子、袜子、靴子、拖鞋或任何鞋底，必须露出圆润毛绒的动物脚掌 / 爪爪。

必须保留 <breed_cn> 的关键品种特征：<breed_traits_cn>。
毛色和花纹必须严格匹配 <coat_cn>。
整体风格为高清 3D CGI 渲染，玩偶产品图质感，棚拍灯光，柔和阴影，边缘清晰，细节精致，画面干净，真透明背景。
适合做宠物头像、贴纸、品牌吉祥物、IP 角色形象。整体感觉非常可爱、圆润、毛茸茸、治愈、有亲和力。
```

---

## 5. Prompt 变量定义

| 变量 | 示例 | 说明 |
|---|---|---|
| `<species>` | `cat`, `dog` | 英文物种，用于文件名和英文 prompt |
| `<species_cn>` | `猫`, `狗` | 中文物种 |
| `<breed>` | `Devon Rex`, `Shiba Inu` | 英文品种 |
| `<breed_cn>` | `德文卷毛`, `柴犬` | 中文品种 |
| `<gender>` | `boy`, `girl` | 文件名字段；也影响姿势、配饰和服装 |
| `<coat>` | `blue_gray`, `black_tan`, `seal_point` | 文件名字段 |
| `<coat_cn>` | `蓝灰色短卷毛`, `黑棕色`, `海豹重点色` | 生成描述用自然语言 |
| `<eye>` | `black` | 固定值，不进入正式文件名 |
| `<eye_color_cn>` | `黑色` | 固定黑色眼睛，不按毛色变化 |
| `<breed_traits_cn>` | `超大耳朵、精灵感脸型、短卷毛、机灵好奇` | 品种识别特征，必须强提示 |

---

## 6. 眼睛规范：统一黑色眼睛

当前风格中眼睛是角色是否“可爱”和是否“像 App 头像”的关键。

### 6.1 正向要求

- 眼白必须是纯白色 / 乳白色，不要被瞳色污染。
- 虹膜观感统一为黑色，不再按毛色生成绿色、蓝色、金色、铜色或异瞳。
- 瞳孔必须是黑色卡通大圆瞳，不要过度写实。
- 眼睛有 1-2 个明显白色高光点。
- 可使用半眯眼、无辜大眼、开心睁眼等表情，但眼白仍需可见。

### 6.2 英文眼睛追加 Prompt

```text
Eye design: oversized cute cartoon eyes, pure white sclera, black iris appearance, large black round cartoon pupils, glossy white highlights, clean eye outline, expressive eyelids. Do not use colored irises. Do not color the sclera. Do not make the eyes realistic.
```

### 6.3 负面限制

```text
colored sclera, green sclera, blue sclera, yellow sclera, colored iris, green iris, blue iris, yellow iris, odd eyes, heterochromia, realistic animal eyes, tiny pupils, human eyes, creepy eyes, dull eyes, missing eye highlights, asymmetrical eyes
```

---

## 7. 品种特征优先级

所有头像要保持统一风格，但不能把不同品种画成同一张脸。品种特征的优先级高于服装、动作和配饰。

| 优先级 | 内容 |
|---|---|
| P0 | 品种轮廓：耳朵、脸型、鼻口、尾巴、毛量、体型 |
| P1 | 毛色 / 花纹：必须和组合表完全一致 |
| P2 | 眼睛：眼白白色，黑色虹膜观感，黑色卡通瞳孔 |
| P3 | 品种性格：活泼、好动、乖巧、冷静、傲娇、亲人、警觉等，决定表情、姿势和服装方向 |
| P4 | 性别气质：在品种性格基础上做 boy / girl 的气质偏移 |
| P5 | 服装：可变化，但不能遮挡关键识别特征 |

---

## 8. 德文卷毛 Devon Rex 专项规范

德文卷毛是高风险跑偏品种，容易被生成成普通英短 / 家短。因此所有 Devon Rex 头像必须增加专属特征描述。

### 8.1 必须强调的特征

```text
Devon Rex specific traits: extremely large low-set ears, oversized bat-like ears, pixie-like face, small wedge-shaped head, high cheekbones, slender neck, short curly wavy plush fur, mischievous intelligent expression, curious energetic personality, elegant but playful cat silhouette.
```

### 8.2 中文版

```text
必须明显体现德文卷毛特征：超大低位耳朵，像小精灵一样的脸型，小而略楔形的头部，高颧骨，细长脖子，短而卷曲/波浪感的绒毛，机灵好奇、精力充沛、带一点调皮的表情。不能画成普通圆脸英短或普通家猫。
```

### 8.3 德文卷毛灰色公猫示例 Prompt

```text
生成一个灰色毛的公德文卷毛猫拟人化 3D 毛绒玩偶吉祥物形象。
角色全身站姿，主体居中，完整可见，大头小身 Q 版比例，身体短小圆润，四肢短而可爱，脚掌和手掌圆滚滚。
必须明显体现德文卷毛特征：超大低位耳朵，像小精灵一样的脸型，小而略楔形的头部，高颧骨，细长脖子，短而卷曲/波浪感的灰色绒毛，机灵好奇、精力充沛、带一点傲娇调皮的表情。不能画成普通圆脸英短或普通家猫。

角色拥有柔软短绒毛质感，表面有细腻毛绒纤维，材质像高级 plush toy、stuffed animal、soft fabric doll。
眼睛为夸张大号卡通眼睛，眼白保持纯白色，虹膜观感统一为黑色，瞳孔为黑色大圆卡通瞳孔，眼睛有明显白色高光。不要彩色虹膜或彩色眼白。
角色双手抱胸，自信站姿，慵懒半眯眼并带傲娇微笑。
穿白色 T 恤和红色短裤，衣服有柔软布料质感，不能遮挡耳朵、眼睛、脸型和尾巴。
高清 3D CGI 渲染，玩偶产品图质感，棚拍灯光，柔和阴影，边缘清晰，细节精致，真透明背景，无场景、无地面、无文字、无水印。
```

### 8.4 德文卷毛性别气质规范

德文卷毛头像需要在保持统一 Ohana 毛绒 3D 体系的前提下，通过表情、姿势和轻量穿搭做出更明显的性别气质差异。

| 性别 | 气质方向 | 表情 | 姿势 | 服装 / 配饰 |
|---|---|---|---|---|
| `boy` | 更 cool、更自信、更机灵，带一点傲娇和不在乎 | 半眯眼、侧眼、自信坏笑、微挑眉、轻微不对称 smirk | 双手抱胸、交叉腿、头微低但眼神看前方、轻街头感站姿 | 米白宽松 T、短款黑/炭灰马甲、深红短裤、小号青绿色领巾或小拉链细节 |
| `girl` | 更可爱、更灵动、更甜，但仍保留德文的机灵感 | 大眼睛、柔和笑眼、害羞微笑、轻微脸颊暖色绒毛、开心挥手 | 歪头站立、单手托脸、小幅挥手、轻微交叉腿 | 米白圆领上衣、藕粉百褶裙、浅紫/青绿色小围巾、小发夹 |

注意：德文卷毛依赖超大低位耳朵和精灵脸识别，禁止帽子、大蝴蝶结、夸张发饰、墨镜或任何遮挡耳朵、眼睛、脸型和细长脖子的元素。

---

## 9. 性别差异化规则

性别差异只通过气质、姿势、表情、轻量配饰和服装细节表达，不改变品种体型和关键识别特征。

注意：性别差异不能覆盖品种性格。每张头像先根据品种特性确定性格方向、表情、姿势和服装风格，再在这个基础上做 boy / girl 的差异化：`boy` 统一偏酷酷风、自信、有态度；`girl` 统一偏可爱风、甜美、灵动。

| 性别 | 推荐方向 | 可用姿势 | 可用服装 / 配饰 |
|---|---|---|---|
| `boy` | 酷酷风、更稳、更酷、更调皮、更自信 | 双手抱胸、自信站姿、交叉腿、半眯侧眼、歪头坏笑、单手挥手 | 白 T + 红短裤、小领巾、简洁连帽衫、小背带、短款马甲、轻街头感短裤 |
| `girl` | 可爱风、更灵动、更甜、更优雅、更撒娇 | 双手托脸、歪头站立、交叉腿、开心吐舌、挥手、眨眼、害羞微笑 | 白 T + 粉色百褶裙、蝴蝶结、小发夹、柔色围巾、圆领上衣、学院风小裙 |

---

## 10. 品种性格驱动规则

每个品种不能只换毛色。必须根据品种性格生成不同的表情、姿势和轻量服装，让头像在统一 Ohana 画风下有明确差异。

### 10.1 生成决策顺序

1. 先确定品种识别特征：耳朵、脸型、鼻口、尾巴、毛量、体型。
2. 再确定品种性格类型：活泼 / 好动 / 乖巧 / 冷静 / 傲娇 / 亲人 / 警觉 / 优雅等。
3. 根据品种性格选择表情、姿势和服装。
4. 最后叠加性别气质：boy 固定偏酷酷风、自信、有态度；girl 固定偏可爱风、甜美、灵动。

### 10.2 性格类型到视觉表现

| 性格类型 | 表情方向 | 姿势方向 | 服装 / 配饰方向 |
|---|---|---|---|
| 活泼好动 | 亮眼开心、张嘴笑、轻微吐舌 | 挥手、迈步、单脚抬起、身体前倾 | 连帽衫、背带裤、运动感短裤、小领巾 |
| 亲人温暖 | 柔和笑眼、温柔微笑、放松表情 | 双手自然展开、轻挥手、身体微微前倾 | 柔色 T 恤、小围巾、轻量针织感上衣 |
| 冷静独立 | 半眯眼、淡定微笑、安静注视 | 站姿稳定、双手背后、轻微侧身 | 极简上衣、短款马甲、低饱和围巾 |
| 傲娇自信 | 半眯侧眼、坏笑、轻微挑眉 | 抱胸、交叉腿、头微低看前方 | 轻街头马甲、红短裤、小号领巾 |
| 优雅精致 | 温和自信、笑容克制、眼神干净 | 站姿挺拔、单手抬起、脚尖轻转 | 小披肩、圆领上衣、学院风裙装或背带 |
| 警觉聪明 | 专注眼神、微微严肃、精神状态高 | 一手叉腰、站姿挺直、轻微前倾 | 简洁背带、深色小马甲、功能感细节 |
| 憨厚搞怪 | 圆眼、憨笑、略夸张但友好 | 放松站姿、双手摊开、轻微歪头 | 宽松 T 恤、短裤、小领结 |
| 守护可靠 | 沉稳笑容、自信眼神、不凶 | 稳定站姿、手放胸前或腰侧 | 深色背心、小领巾、简洁实用服装 |

### 10.3 品种级映射要求

生成每张图时必须显式写入以下字段，不允许只写通用姿势：

```yaml
breed_personality_type: active | warm | calm | proud | elegant | alert | goofy | reliable
expression: <breed-driven expression>
pose: <breed-driven pose>
outfit: <breed-driven lightweight outfit>
gender_variation: <boy/girl adjustment>
```

例如：

```text
Shiba Inu: proud / confident / slightly smug -> half-lidded side-eye, arms crossed, crossed legs, streetwear vest.
Golden Retriever: warm / friendly / reliable -> bright gentle smile, open welcoming wave, soft scarf or relaxed T-shirt.
Devon Rex: clever / curious / energetic -> mischievous expression, stylish crossed-leg pose, lightweight streetwear or playful skirt.
Samoyed: warm / healing / cheerful -> big smile, open-arm greeting, soft cozy scarf.
Russian Blue: calm / elegant / quiet -> relaxed eyes, composed upright pose, minimal elegant accessory.
```

---

### 10.4 服装与配饰规则

#### 推荐服装池

```text
white t-shirt and red shorts
white t-shirt and pink pleated skirt
simple hoodie
tiny overalls
small scarf
small bow tie
pink bow on head
small hair clip
minimal sailor collar
off-white oversized t-shirt
short charcoal utility vest
dusty rose pleated skirt
soft lavender mini scarf
teal neckerchief
```

#### 禁止项

- 不要复杂服饰，不要遮挡毛色和花纹。
- 不要戴大帽子遮住耳朵，特别是德文卷毛、法斗、柯基等靠耳朵识别的品种。
- 不要把配饰作为品种特征的替代。
- 不要穿鞋子、袜子、靴子、拖鞋、凉鞋或任何鞋底；脚部必须是裸露的圆润毛绒动物脚掌 / 爪爪。
- 不要加入品牌 logo、文字、图案水印。

---

## 11. 构图与 PNG 交付规范

| 项目 | 规范 |
|---|---|
| 文件格式 | PNG with alpha |
| 正式入库画布尺寸 | `600x800` |
| 源图目标尺寸 | 直接生成 `600x800` 竖版源图；若生成器返回尺寸略有偏差，后处理仅校正到 `600x800` |
| 背景 | 最终文件必须为真透明 alpha，不要纯色底、阴影底、渐变底 |
| 主体 | 全身完整可见，头顶、耳朵、尾巴、脚掌不能裁切 |
| 脚部 | 禁止鞋子和袜子，脚部必须是符合物种的裸露圆润毛绒脚掌 / 爪爪 |
| 主体高度 | alpha bbox 高度约占画布 `92% - 98%` |
| 上下留白 | 顶部和底部各约 `2% - 4%` |
| 左右留白 | 尽量少，只保留耳朵、尾巴、衣服不被裁切的呼吸空间 |
| 主体位置 | 居中略偏下，脚或身体底部接近画布底部 |
| 适配方式 | `scaledToFit` |
| 禁止 | 不要输出 1:1 方图，不要大面积透明边距 |

### 11.1 严格透明 PNG 生成流程

用于正式入库的头像不要直接依赖生成器返回的“透明背景预览”。复杂毛绒边缘可能被输出成棋盘格、黑底、灰底或伪透明。正式资产必须走以下流程：

1. 每张头像必须逐张独立生成 `600x800` 竖版源图，背景指定为完全均匀的纯色 chroma key。默认使用 `#ff00ff`，避免与黑色眼睛、常见毛色和白色眼白冲突。
2. Prompt 中必须写明：背景只有一个纯色，无阴影、无渐变、无纹理、无地面、无反射，主体边缘清晰，主体内部不得出现 `#ff00ff`。
3. 将源图保存到 `tmp/imagegen/<breed>_sources/`，文件名后缀使用 `_chroma.png`。
4. 用本地透明处理脚本移除色键，输出到 `tmp/imagegen/<breed>_alpha/`。
5. 验证 alpha 源图必须为 `RGBA`，四角 alpha 为 `0`，主体 alpha bbox 高度约占画布 `92% - 98%`，且边缘没有明显色键残留。
6. 将通过验证的 alpha 源图校正为 `600x800` RGBA PNG 后，才能复制到 `PetAvatarAssets/`，并使用正式文件名替换旧图。禁止把 `1200x1600` 作为默认中间产物。
7. 禁止用一张或两张底图批量调色生成整套头像；每个 `gender + coat` 组合都必须由生成模型独立渲染。

透明处理建议命令：

```bash
python "${CODEX_HOME:-$HOME/.codex}/skills/.system/imagegen/scripts/remove_chroma_key.py" \
  --input tmp/imagegen/devon_rex_sources/<filename>_chroma.png \
  --out tmp/imagegen/devon_rex_alpha/<filename>.png \
  --auto-key border \
  --soft-matte \
  --transparent-threshold 12 \
  --opaque-threshold 220 \
  --despill
```

---

## 12. 文件命名规范

所有文件使用英文小写和下划线，便于 Swift 侧静态索引。

```text
<species>_<breed>_<gender>_<coat>.png
```

示例：

```text
dog_french_bulldog_girl_fawn_black_mask.png
cat_devon_rex_boy_blue_gray.png
cat_girl_standard.png
```

### 12.1 standard 兜底头像

每个物种额外提供：

```text
<species>_boy_standard.png
<species>_girl_standard.png
```

用于用户选择自定义毛色、品种毛色图缺失或未覆盖品种时的兜底显示。Standard 是物种级 fallback，不属于任何具体品种。

当前 App 入口级 standard 覆盖：`cat`、`dog`、`fish`、`bird`、`rabbit`、`reptile`、`hamster`、`other`。其中 `other` 是“其他”入口的通用 companion fallback，不表达具体真实物种。

猫类 standard 设计为通用家猫轮廓：中等耳朵、中性脸型、普通弯尾、中性暖灰 / 奶灰短绒，避免德文大耳朵、英短圆脸、布偶重点色、缅因耳尖毛等强品种特征。

狗类 standard 设计为通用小中型狗轮廓：半垂耳或柔和圆耳、普通尾巴、中性奶油 / 浅棕短绒，避免柴犬立耳卷尾、金毛长耳长毛、法斗短鼻蝙蝠耳、柯基短腿等强品种特征。

鱼类 standard 设计为通用圆润观赏鱼吉祥物：简单尾鳍、背鳍和侧鳍，暖奶油 / 浅橙 / 暖灰色 plush 质感，避免金鱼、锦鲤、斗鱼、小丑鱼等强品种或强物种特征。

鸟类 standard 设计为通用小型宠物鸟轮廓：圆身体、短喙、柔和翅膀、普通尾羽，中性奶油 / 暖灰 / 柔和蓝或桃色，避免鹦鹉强弯喙、猫头鹰脸盘、企鹅花纹等强特征。

兔类 standard 设计为通用家兔轮廓：中等直立圆耳、紧凑圆身体、小棉尾，暖奶油 / 奶灰短绒，避免垂耳、安哥拉长毛、狮子兔鬃毛、荷兰兔强分区花纹。

爬宠 standard 设计为通用小蜥蜴 / 守宫轮廓：圆头、小四肢、可见弯尾、柔和鳞片缝线，鼠尾草绿 / 暖米色，避免蛇、龟壳、变色龙冠、龙翼、鳄鱼长吻等强特征。

仓鼠 standard 设计为通用仓鼠轮廓：圆脸、小圆耳、颊囊、小爪、紧凑身体，暖棕 / 奶油短绒，避免鼠类长吻、豚鼠体型、兔耳等混淆特征。

其他 standard 设计为物种不明确的通用 companion mascot：圆润小耳、简单爪子、友好尾巴，暖奶油 / 浅灰 / 浅棕，不带任何强动物、奇幻或品牌特征。

Standard 也遵循性别气质：男生偏 cool、自信但克制；女生偏可爱、亲和但不过度装饰。禁止帽子、墨镜、大 logo 或遮挡脸部 / 耳朵的配饰。

---

## 13. Prompt 拼装逻辑

建议为每个资产组合拼装以下字段：

```yaml
species: dog | cat
breed: French Bulldog | Devon Rex | Shiba Inu
breed_cn: 法斗 | 德文卷毛 | 柴犬
gender: boy | girl
coat: blue_gray
coat_cn: 蓝灰色短绒毛
breed_traits_cn: 超大低位耳朵、精灵感脸型、短卷毛、机灵好奇
breed_personality_type: proud
personality: confident, curious, playful
expression: half-lidded side-eye, tiny smug smile
pose: arms crossed, one leg crossed
outfit: off-white t-shirt, charcoal utility vest, deep red shorts, teal neckerchief
gender_variation: boy, cooler and more confident
negative_prompt: <global negative prompt + breed-specific negative prompt>
eye: black
eye_cn: 黑色眼睛
output_filename: cat_devon_rex_boy_blue_gray.png
```

---

## 14. 全局 Negative Prompt

```text
realistic animal photo, hyper-realistic anatomy, ordinary pet photo, scary, aggressive, creepy, ugly, thin body, long limbs, human face, hard plastic, metallic texture, flat 2D illustration, sketch, watercolor, low quality, blurry, distorted eyes, asymmetrical eyes, colored sclera, green sclera, blue sclera, yellow sclera, colored iris, green iris, blue iris, yellow iris, heterochromia, odd eyes, realistic animal eyes, missing eye highlights, bad proportions, extra limbs, extra fingers, messy background, scenery, floor, shadow background, gradient background, text, watermark, logo, cropped ears, cropped feet, cropped tail
```

---

## 15. 品种性格提示建议

这些短语应写入每个品种的 prompt，用于让头像在统一风格下保留差异。

生成资产时，表格中的每个品种都必须先归入第 10.2 节的一个性格类型，再产出对应的 `expression`、`pose` 和 `outfit`。不能只把这些短语作为描述背景，也不能让不同品种共用同一套动作、服装和表情。

### 15.1 犬类

| 品种 | 品种特征 / 性格提示 |
|---|---|
| French Bulldog | 蝙蝠耳、短鼻、敦实、憨厚、放松自信 |
| Labrador | 友好、温暖、可靠、运动感、亲人 |
| Golden Retriever | 温柔、阳光、亲切、笑容明显、毛量蓬松 |
| German Shepherd | 立耳、聪明、忠诚、警觉、自信 |
| Poodle | 卷毛、优雅、聪明、轻盈、精致 |
| Dachshund | 长身体、短腿、勇敢、调皮、好奇 |
| Beagle | 垂耳、活泼、爱探索、亲切 |
| Shiba Inu | 立耳、卷尾、自信、傲娇、机灵 |
| Corgi | 短腿、大耳朵、圆屁股、活泼、开心 |
| Husky | 狼感脸型、面具花纹、蓝眼/异瞳可选、精力旺盛 |
| Pomeranian | 蓬松毛球、尖耳、甜美、活泼 |
| Border Collie | 聪明、专注、敏捷、黑白轮廓明显 |
| Yorkshire Terrier | 小型、丝质毛感、精致、活泼 |
| Schnauzer | 胡子眉毛、方脸、机警、酷感 |
| Chihuahua | 大耳、小体型、警觉、灵动 |
| Shih Tzu | 圆脸、长毛、甜美、温顺 |
| Maltese | 白色长毛、优雅、干净、柔软 |
| Bichon Frise | 白色卷毛、圆头、快乐、像棉花糖 |
| Bulldog | 宽脸、皱褶、敦实、憨厚 |
| Australian Shepherd | 牧羊犬轮廓、灵活、聪明、merle 花纹突出 |
| Pug | 黑面罩、圆眼、短鼻、憨厚搞怪 |
| Cavalier | 长垂耳、温柔、贵族感、亲人 |
| Rottweiler | 强壮、黑棕标记、稳重、保护欲 |
| Doberman | 修长、警觉、优雅、酷感 |
| Boxer | 方口鼻、运动感、热情、调皮 |
| Bernese | 三色大狗、温柔、厚毛、可靠 |
| Great Dane | 高大、优雅、温和、强轮廓 |
| Samoyed | 白色蓬松、微笑脸、温暖、治愈 |
| Chow Chow | 狮子感厚毛、圆脸、稳重、独立 |
| Cocker Spaniel | 长垂耳、卷毛耳朵、温柔、甜美 |

### 15.2 猫类

| 品种 | 品种特征 / 性格提示 |
|---|---|
| Domestic Shorthair | 自然猫感、亲切、灵活、普通家猫但要可爱 |
| Domestic Longhair | 蓬松长毛、柔软、优雅、亲和 |
| British Shorthair | 圆脸、厚实短毛、铜眼常见、稳重可爱 |
| American Shorthair | 健壮、虎斑清晰、友好、自然 |
| Chinese Li Hua / Dragon Li | 短毛、M 字额纹、鱼骨状狸花虎斑、环尾、机敏、活泼、警觉 |
| Ragdoll | 蓝眼、重点色、温柔、软萌、安静 |
| Maine Coon | 大体型、耳尖毛、厚毛、威风但温柔 |
| Persian | 扁脸、长毛、圆眼、贵气、安静 |
| Exotic Shorthair | 圆脸短鼻、短毛波斯感、呆萌 |
| Bengal | 豹纹/玫瑰斑、野性花纹、活泼、运动感 |
| Siamese | 重点色、蓝眼、修长、聪明、爱表达 |
| Scottish Fold | 折耳、圆脸、安静、软萌 |
| Russian Blue | 蓝灰短毛、绿色眼睛、优雅、安静 |
| Sphynx | 无毛/绒感皮肤、大耳、外星感但可爱 |
| Devon Rex | 超大耳朵、精灵脸、短卷毛、机灵好奇、精力充沛 |
| Abyssinian | ticked coat、修长、活泼、聪明 |
| Burmese | 圆润、金眼、亲人、温暖 |

---

## 16. 批量生成 QA Checklist

每张图生成后必须检查：

- [ ] 正式入库文件是否为 `600x800` 竖版 PNG。
- [ ] 是否为 `RGBA` 且真透明背景，四角 alpha 为 `0`，不是黑底、灰底、渐变底或棋盘格底。
- [ ] 是否经过 `600x800` chroma key 源图生成、本地 alpha 移除、透明验证和尺寸校正后再入库。
- [ ] 主体是否全身完整可见，耳朵、尾巴、脚掌未裁切。
- [ ] 是否完全没有鞋子、袜子、靴子、拖鞋、凉鞋或鞋底，脚部是否为裸露圆润毛绒动物脚掌 / 爪爪。
- [ ] 主体是否占画布高度约 `92% - 98%`，没有过多透明边距。
- [ ] 是否符合大头小身、短四肢、毛绒玩偶、3D CGI 风格。
- [ ] 品种关键特征是否明显，例如德文卷毛必须有超大耳朵和精灵脸。
- [ ] 是否根据品种性格选择了专属表情、姿势和服装，而不是所有品种使用同一套模板。
- [ ] Prompt 是否明确写入 `breed_personality_type`、`expression`、`pose`、`outfit` 和 `gender_variation`。
- [ ] 毛色和花纹是否匹配组合表。
- [ ] 眼白是否保持白色。
- [ ] 眼睛是否统一为黑色虹膜观感，没有彩色虹膜或异瞳。
- [ ] 瞳孔是否为黑色卡通瞳孔，并有明显高光。
- [ ] 性别差异是否通过姿势、服装或轻量配饰表达，而不是改变品种体型。
- [ ] 男生是否更 cool、自信、有态度；女生是否更可爱、灵动、甜，但都不破坏品种特征。
- [ ] 服装和配饰是否没有遮挡品种特征。
- [ ] 文件名是否严格符合 `<species>_<breed>_<gender>_<coat>.png`。

---

## 17. 生成示例

### 17.1 Devon Rex boy, blue gray

```text
Species: cat
Breed: Devon Rex
Gender: boy
Coat color and pattern: blue gray short curly plush fur
Eye design: black iris appearance with pure white sclera and black cartoon pupils
Breed personality: mischievous, curious, energetic, smart, slightly smug
Breed personality type: proud / alert
Breed traits: extremely large low-set ears, pixie-like face, small wedge-shaped head, high cheekbones, slender neck, short curly wavy plush fur
Expression: half-lidded side-eye, tiny smug smile, clever curious look
Pose: arms crossed, one leg crossed, confident stylish standing pose
Outfit: off-white t-shirt, short charcoal utility vest, deep red shorts, teal neckerchief
Gender variation: boy, cooler and more confident
Output: cat_devon_rex_boy_blue_gray.png
```

### 17.2 Shiba Inu girl, black tan + dark brown

```text
Species: dog
Breed: Shiba Inu
Gender: girl
Coat color and pattern: black and tan Shiba coat, cream muzzle and cheeks, curled tail
Eye design: black iris appearance with pure white sclera and black cartoon pupils
Breed personality: confident, proud, playful, slightly smug
Breed personality type: proud
Breed traits: upright triangular ears, curled tail, compact body, fox-like face
Expression: bright black cartoon eyes, playful wink or cheeky smile, slightly smug but cute
Pose: tilted head, one paw near cheek, one paw giving a small wave, lively crossed-leg stance
Outfit: soft cream top, dusty rose pleated skirt, tiny scarf or small hair clip that does not cover ears
Gender variation: girl, sweeter and more playful
Output: dog_shiba_inu_girl_black_tan.png
```

### 17.3 French Bulldog boy, fawn black mask + dark brown

```text
Species: dog
Breed: French Bulldog
Gender: boy
Coat color and pattern: fawn coat with black mask
Eye design: black iris appearance with pure white sclera and black cartoon pupils
Breed personality: relaxed, funny, confident, affectionate
Breed personality type: goofy / warm
Breed traits: large bat ears, short muzzle, compact muscular body, round cheeks
Expression: relaxed half-smile, round friendly black eyes, sleepy confident charm
Pose: stable relaxed stance, one paw lightly on belly or chest, shoulders loose
Outfit: loose off-white t-shirt, soft red shorts, small bow tie or neckerchief, no hat covering ears
Gender variation: boy, relaxed and confident
Output: dog_french_bulldog_boy_fawn_black_mask.png
```

---

## 18. App 侧资产索引建议

建议在 Swift 侧维护一个静态索引或生成 JSON manifest：

```json
{
  "species": "cat",
  "breed": "devon_rex",
  "gender": "boy",
  "coat": "blue_gray",
  "eye": "black",
  "filename": "cat_devon_rex_boy_blue_gray.png",
  "fallback": "cat_boy_standard.png"
}
```

匹配逻辑建议：

1. 优先匹配完整组合：`species + breed + gender + coat`。
2. 如果不存在，使用同 species 同 gender 的 `standard`。
3. 如果同 species standard 不存在，回退到当前 SwiftUI Kawaii silhouette。

---

## 19. 批量资产组合清单

以下清单按新规则维护：每个物种/品种只区分 `gender + coat`，眼睛统一黑色，不再按瞳色拆分资产。默认每个毛色生成 `boy` 和 `girl` 两套；standard 只按物种生成 `boy_standard` 和 `girl_standard`，不再按品种生成。

## 生成数量估算

| 类别 | 毛色组合数 | 性别数 | 预计 PNG 数 |
|---|---:|---:|---:|
| 犬类 | 128 | 2 | 258 |
| 猫类 | 110 | 2 | 222 |
| 其他 App 入口 standard | 5 | 2 | 10 |
| `other` 通用入口 standard | 1 | 2 | 2 |
| 合计 | 244 | 2 | 492 |

## 犬类组合

每一行默认生成 `boy` 和 `girl` 两个性别。

| 品种 | 毛色 / 花纹组合 |
|---|---|
| 法斗 French Bulldog | `fawn_black_mask`, `cream`, `brindle`, `pied`, `black_white`, `blue_gray` |
| 拉布拉多 Labrador | `black`, `yellow`, `chocolate` |
| 金毛 Golden Retriever | `light_golden`, `golden`, `dark_golden` |
| 德牧 German Shepherd | `black_tan`, `sable`, `black_red`, `solid_black`, `white` |
| 贵宾 / 泰迪 Poodle | `white`, `black`, `cream`, `apricot`, `red`, `brown`, `silver` |
| 腊肠 Dachshund | `red`, `black_tan`, `chocolate_tan`, `cream`, `dapple` |
| 比格 Beagle | `tricolor`, `lemon_white`, `red_white`, `chocolate_tricolor` |
| 柴犬 Shiba Inu | `red`, `black_tan`, `cream`, `sesame` |
| 柯基 Corgi | `red_white`, `sable_white`, `fawn_white`, `black_tan_white` |
| 哈士奇 Husky | `black_white`, `gray_white`, `red_white`, `agouti_white`, `white` |
| 博美 Pomeranian | `orange`, `cream`, `white`, `black`, `sable`, `chocolate`, `merle` |
| 边牧 Border Collie | `black_white`, `red_white`, `tricolor`, `sable_white`, `blue_merle`, `red_merle` |
| 约克夏 Yorkshire Terrier | `blue_tan`, `black_tan`, `gold_tan` |
| 雪纳瑞 Schnauzer | `salt_pepper`, `black_silver`, `solid_black`, `white` |
| 吉娃娃 Chihuahua | `fawn`, `cream`, `black_tan`, `chocolate`, `white`, `merle` |
| 西施 Shih Tzu | `gold_white`, `black_white`, `liver_white`, `brindle_white`, `white`, `gray_white` |
| 马尔济斯 Maltese | `white` |
| 比熊 Bichon Frise | `white` |
| 英斗 Bulldog | `fawn_white`, `brindle_white`, `red_white`, `white`, `piebald` |
| 澳牧 Australian Shepherd | `black_tri`, `red_tri`, `blue_merle`, `red_merle` |
| 巴哥 Pug | `fawn_black_mask`, `black`, `silver_fawn`, `apricot_fawn` |
| 骑士查理王 Cavalier | `blenheim`, `tricolor`, `black_tan`, `ruby` |
| 罗威纳 Rottweiler | `black_tan`, `black_mahogany` |
| 杜宾 Doberman | `black_rust`, `red_rust`, `blue_rust`, `fawn_rust` |
| 拳师 Boxer | `fawn`, `brindle`, `white`, `fawn_white`, `brindle_white` |
| 伯恩山 Bernese | `tricolor` |
| 大丹 Great Dane | `fawn`, `brindle`, `black`, `blue`, `harlequin`, `mantle` |
| 萨摩耶 Samoyed | `white`, `biscuit` |
| 松狮 Chow Chow | `red`, `black`, `blue`, `cream`, `cinnamon` |
| 可卡 Cocker Spaniel | `black`, `buff`, `chocolate`, `black_white`, `blue_roan`, `tricolor` |

## 猫类组合

每一行默认生成 `boy` 和 `girl` 两个性别。

| 品种 | 毛色 / 花纹组合 |
|---|---|
| 家短 Domestic Shorthair | `black`, `white`, `blue_gray`, `orange_tabby`, `brown_tabby`, `tuxedo`, `calico`, `tortoiseshell` |
| 家长 Domestic Longhair | `black`, `white`, `blue_gray`, `orange_tabby`, `brown_tabby`, `tuxedo`, `calico`, `tortoiseshell` |
| 英短 British Shorthair | `blue`, `silver_tabby`, `golden_shaded`, `black`, `white`, `cream`, `colorpoint` |
| 美短 American Shorthair | `silver_tabby`, `brown_tabby`, `black`, `white`, `orange_tabby`, `blue` |
| 狸花 Chinese Li Hua / Dragon Li | `brown_mackerel_tabby`, `silver_mackerel_tabby` |
| 布偶 Ragdoll | `seal_point`, `seal_bicolor`, `blue_point`, `blue_bicolor`, `chocolate_point`, `lilac_point`, `flame_point` |
| 缅因 Maine Coon | `brown_tabby`, `silver_tabby`, `red_tabby`, `black_smoke`, `blue_gray`, `black`, `white`, `calico` |
| 波斯 Persian | `white`, `black`, `blue`, `cream`, `silver`, `golden`, `himalayan_seal_point`, `calico` |
| 异国短毛 Exotic Shorthair | `white`, `blue`, `cream`, `black`, `silver`, `tabby`, `colorpoint` |
| 孟加拉 Bengal | `brown_rosetted`, `silver_rosetted`, `snow_lynx`, `charcoal`, `melanistic` |
| 暹罗 Siamese | `seal_point`, `blue_point`, `chocolate_point`, `lilac_point` |
| 苏格兰折耳 Scottish Fold | `blue`, `white`, `silver_tabby`, `brown_tabby`, `cream`, `bicolor` |
| 俄罗斯蓝猫 Russian Blue | `blue_gray` |
| 斯芬克斯 Sphynx | `pink_cream`, `blue_gray`, `black`, `tortie`, `pointed` |
| 德文卷毛 Devon Rex | `black`, `blue_gray`, `white`, `red_tabby`, `cream`, `brown_tabby`, `silver_tabby`, `black_smoke`, `tortoiseshell`, `calico`, `black_white`, `blue_white`, `seal_point`, `blue_point`, `chocolate_point`, `lilac_point`, `flame_point`, `cream_point`, `seal_lynx_point`, `blue_lynx_point` |
| 阿比西尼亚 Abyssinian | `ruddy`, `sorrel`, `blue`, `fawn` |
| 缅甸 Burmese | `sable`, `champagne`, `blue`, `platinum` |

## 德文卷毛扩充说明

德文卷毛的颜色范围非常宽，官方体系通常允许几乎所有颜色和花纹。但头像资产第一批不建议穷举所有颜色，否则单个品种会占用过多生成预算。本清单把德文卷毛收敛为 20 个高识别度毛色，保留常见纯色、虎斑、烟色、玳瑁、三花、双色和重点色；眼睛统一黑色，不再为同一毛色生成多种瞳色版本。

| 组别 | 资产覆盖 |
|---|---|
| 纯色 | 黑、蓝灰、巧克力、丁香、白 |
| 红/奶油系 | 红虎斑、奶油 |
| 虎斑/银色/烟色 | 棕虎斑、银虎斑、黑烟 |
| 玳瑁/三花 | 玳瑁、三花 |
| 双色 | 黑白、蓝白 |
| 重点色 | 海豹重点、蓝重点、巧克力重点、丁香重点、火焰重点、奶油重点 |
| 山猫重点色 | 海豹山猫重点、蓝山猫重点 |

## 头像差异化规则

所有头像必须保持同一套 Ohana 视觉系统：透明背景、2.5D 毛绒质感、圆润比例、柔和立体光影、统一相机角度和统一头像留白。不同头像的差异不应来自画风变化，而应来自宠物本身的性别、品种性格和品种特征。

| 维度 | 可变化内容 | 不应变化内容 |
|---|---|---|
| 性别 | 在品种性格基础上调整表情气质、轻量配饰、衣服细节、动作姿态；男生酷酷风，女生可爱风 | 不改变品种体型和关键识别特征，不覆盖品种性格 |
| 品种性格 | 法斗可憨厚放松，柴犬可自信傲娇，金毛可温暖友好，德文卷毛可机灵好奇；必须驱动表情、姿势和服装 | 不做夸张拟人化，不破坏宠物头像属性，不让所有品种使用同一套动作和衣服 |
| 品种特征 | 耳朵、脸型、尾巴、毛量、身体比例、代表性花纹 | 不把不同品种画成同一套脸 |
| 毛色 / 花纹 | 严格匹配组合表 | 不额外加入未选择的颜色 |
| 服装/装饰 | 白 T、背带、丝巾、小领结、发夹等轻量元素 | 不遮挡毛色、眼睛和品种轮廓 |
| 脚部 | 裸露圆润毛绒动物脚掌 / 爪爪，颜色跟随毛色和花纹 | 不穿鞋子、袜子、靴子、拖鞋、凉鞋，不出现鞋底 |

性别差异建议：

| 性别 | 表现方向 |
|---|---|
| `boy` | 酷酷风：更稳、更酷、更自信、有态度；可用简洁 T 恤、短裤、小领巾、单肩包等细节 |
| `girl` | 可爱风：更灵动、更甜、更软萌、更亲和；可用小发夹、蝴蝶结、裙摆、柔色围巾等细节 |

品种性格提示应写进每张图的 prompt，并转化为具体的 expression / pose / outfit。例如德文卷毛可以强调“大耳朵、卷毛、机灵、好奇、精力充沛”，并对应半眯坏笑、交叉腿、轻街头穿搭；法斗可以强调“短鼻、蝙蝠耳、敦实、憨厚、放松自信”，并对应放松憨笑、稳稳站姿、宽松 T 恤。

## 生成提示词模板

```text
Generate a cute 2.5D plush pet avatar for an iOS app.
Species: <dog/cat>.
Breed: <breed>.
Breed personality: <short personality direction based on breed traits>.
Breed personality type: <active/warm/calm/proud/elegant/alert/goofy/reliable>.
Gender styling: <boy/girl>; choose expression and pose from breed traits first, then style boy avatars cooler and more confident, girl avatars cuter and sweeter, while keeping the same overall Ohana avatar style.
Coat color and pattern: <coat>.
Eye design: unified black cartoon eyes with pure white sclera.
Expression: <breed-driven expression, then gender-adjusted>.
Pose: <breed-driven pose, then gender-adjusted>.
Outfit: <breed-driven lightweight outfit, then gender-adjusted>.
Footwear rule: no shoes, no socks, no boots, no sandals, no slippers, no shoe soles; show bare rounded furry animal paws/feet.
Style: soft fuzzy plush texture, rounded toy-like proportions, expressive friendly face, polished app avatar, premium character render.
Composition: centered full-body avatar, consistent camera angle, generous padding.
Background: transparent PNG, no scenery, no floor, no text, no watermark.
Keep breed-specific silhouette and facial features clearly recognizable.
Keep the whole batch visually consistent, but make details different across gender and breed: expression, small accessory, clothing detail, and gesture.
```

## PNG 构图与留白规范

头像最终会在宠物卡片左半部分渲染，使用 `scaledToFit` 贴近底部展示。因此每张 PNG 必须按以下规则交付：

| 项目 | 规范 |
|---|---|
| 正式入库画布尺寸 | `600x800` PNG |
| 背景 | 真透明 alpha，不要纯色底、阴影底、渐变底 |
| 主体高度 | 主体 alpha bbox 高度约占画布 `92% - 98%` |
| 上下留白 | 顶部和底部各只留约 `2% - 4%` |
| 左右留白 | 以不裁切耳朵、尾巴、衣服为准，尽量少留空 |
| 主体位置 | 居中略偏下，脚或身体底部接近画布底部 |
| 卡片效果 | 在卡片中应位于左半部分，上下几乎撑满卡片，只留一点空隙 |

生成 AI 图时不要输出 1:1 方图。方图在卡片左半部分 `scaledToFit` 后会显得偏小；透明边距过多也会让头像在卡片中缩小。

## 参考来源

- AKC Most Popular Dog Breeds: https://www.akc.org/most-popular-breeds/
- CFA Devon Rex: https://cfa.org/breed/devon-rex/
- TICA Devon Rex: https://tica.org/breed/devon-rex/
- TICA color naming reference: https://tica.org/what-color-is-my-cat/
