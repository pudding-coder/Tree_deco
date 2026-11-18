# 장식·특성 추가하고 고치는 법

장식과 특성은 **파일 두 개**에 표로 적혀 있다. 코드를 몰라도 한 줄을 복사해서 고치면 된다.

| 무엇 | 파일 |
| --- | --- |
| 장식 (빨간 공, 키캡 키링 …) | `src/shared/Catalog/Decorations.luau` |
| 특성 (반짝이, 황금 …) | `src/shared/Catalog/Traits.luau` |

적은 내용은 게임이 시작될 때 자동으로 검사된다. 잘못 적으면 Studio Output에 **어느 줄이 왜 틀렸는지** 빨간 글씨로 나온다.

---

## 1. 처음 한 번만 준비

1. [VS Code](https://code.visualstudio.com/)를 설치한다.
2. VS Code에서 **File → Open Folder…** → `Tree_deco` 폴더(홈 폴더 안)를 연다.
3. 왼쪽 **Extensions**(네모 4개 아이콘)에서 아래를 검색해 설치한다.
   - **Luau Language Server** (JohnnyMorganz) — 오타를 빨간 밑줄로 알려준다.

---

## 2. 작업 순서 (매번)

1. **최신 코드 받기** — 터미널에서
   ```bash
   cd ~/Tree_deco && git pull
   ```
2. **Rojo 켜기** — 다른 터미널 창에서 `rojo serve`, Studio에서 (Play 중이 아닐 때) **Plugins → Rojo → Connect**
3. **VS Code에서 파일 고치기** → `Cmd + S`로 저장. Studio에 자동으로 들어간다.
4. **Studio에서 ▶ Play** → Output에 빨간 오류가 없는지 확인 → 뽑아 보기
5. **올리기** — 터미널에서
   ```bash
   git add -A && git commit -m "장식 추가: 눈송이 키링" && git push
   ```
   VS Code 왼쪽 **Source Control**(갈래 아이콘)에서 메시지를 적고 **Commit → Sync Changes**를 눌러도 같다.

> Claude와 같이 작업할 때는 시작 전에 꼭 `git pull`, 끝나면 `git push` 후 "올렸어"라고 알려주기. 같은 파일을 동시에 고치면 충돌이 난다.

---

## 3. 장식 추가하기

`Decorations.luau`에서 같은 등급 줄 하나를 복사해 아래에 붙이고 고친다.

```lua
{ id = "SnowflakeKeyring", name = "눈송이 키링", rarity = "Rare", area = "Ornament" },
```

| 칸 | 뜻 | 적는 법 |
| --- | --- | --- |
| `id` | 저장용 이름 | 영문으로 시작, 영문·숫자·`_`만. 다른 장식과 겹치면 안 됨 |
| `name` | 화면에 보이는 이름 | 한글 OK, 아무 때나 바꿔도 됨 |
| `rarity` | 등급 | `"Common"` `"Uncommon"` `"Rare"` `"Epic"` `"Legendary"` `"Mystic"` `"Secret"` |
| `area` | 트리 어디에 거는지 | `"Topper"`(꼭대기) `"Ornament"`(가지) `"Garland"`(띠) |
| `weight` | (선택) 같은 등급 안에서 나오는 비율 | 안 쓰면 1. `weight = 2`면 2배 잘 나옴, `0.5`면 절반 |
| `model` | (선택) 3D 모델 이름 | 트리 꾸미기 작업 후 사용 (아래 6번) |
| `paintable` | (선택) 랜덤 색 칠하기 | `paintable = true`면 뽑을 때 색이 정해져 모델의 `Paint` 파트에 칠해진다 (아래 6번) |
| `holdable` | (선택) 잡기 | `holdable = true`면 트리에 걸린 이 장식에 캐릭터가 닿을 때 손을 뻗어 잡은 채 트리에 매달린다(누구나). 점프하면 놓는다. 장식은 빠지지 않는다 |

**주의**
- 줄 끝 쉼표 `,`를 빼먹지 않기. 글자는 큰따옴표 `" "`로 감싸기.
- 같은 등급 장식이 많아질수록 그 등급 안에서 특정 장식이 나올 확률은 낮아진다. 등급 확률(예: 레어 1/25)은 그대로다.

---

## 4. 특성 추가하기

`Traits.luau`에 한 줄 추가한다.

```lua
{ id = "Candy", name = "사탕", n = 50, mult = 3 },
```

| 칸 | 뜻 | 적는 법 |
| --- | --- | --- |
| `id` | 저장용 이름 | 장식과 같은 규칙 |
| `name` | 화면 이름 | 아무 때나 바꿔도 됨 |
| `n` | 확률 분모 | `50`이면 1/50. **기본 특성(`None`) 하나만 비워 둔다** |
| `mult` | 가치 배수 | `3`이면 장식 가치 ×3 |
| `effect` | (선택) 장식 주변 분위기 | `Sparkle` `Frost` `Gold` `Rainbow` `Aurora` `Smoge` 중 하나 (`src/server/TraitEffects.luau`). 장식 색은 바꾸지 않는다 |

특성 확률(1/n)을 모두 더한 값이 100%를 넘으면 오류가 난다.

특성 글자색은 `src/client/GachaUI.luau` 위쪽의 `TRAIT_COLORS`에서 정한다. 새 특성을 넣고 색을 안 정하면 흰색으로 나온다.

```lua
Candy = Color3.fromRGB(255, 150, 200),
```

---

## 5. 고치기·없애기

| 하고 싶은 것 | 괜찮은지 |
| --- | --- |
| `name` 바꾸기 | ✅ 언제든 |
| `weight`, `n`, `mult` 바꾸기 | ✅ 단, 밸런스가 바뀐다 (7번) |
| `rarity`, `area` 바꾸기 | ⚠️ 이미 가진 사람의 장식도 같이 바뀐다 |
| `id` 바꾸기 | ❌ 가진 사람의 장식이 사라진다. 새 장식을 추가하고 옛것은 `retired`로 |
| 줄 지우기 | ❌ 가진 사람의 장식이 사라진다. 대신 `retired = true` |

**그만 나오게 하기** — 줄을 지우지 말고 끝에 `retired = true`를 붙인다. 더 이상 뽑히지 않지만 이미 가진 사람은 그대로 갖는다.

```lua
{ id = "CandyCane", name = "사탕지팡이", rarity = "Common", area = "Ornament", retired = true },
```

---

## 6. 3D 모델 연결

모델이 없는 장식은 등급 색 공으로 보인다. 모델을 연결하면 그 모델이 트리에 걸린다.

### 만들기

- Blender나 Studio에서 만든다. Toolbox 모델도 된다(직접 만든 게 아니면 사용 조건 확인).
- **크기는 아무래도 된다.** 게임이 가장 긴 변을 오너먼트 2.3스터드, 토퍼 4스터드에 맞춘다.
- **정면**이 있는 장식(얼굴, 글자)은 정면이 Studio의 Front(-Z), 위가 위(+Y)를 보게 둔다. 게임은 `DecorationModels`에 놓인 그대로의 방향을 쓴다. 여러 모델을 Studio에서 한꺼번에 돌려 맞추는 법은 `docs/DECORATION_MODELS.md`.
- 오너먼트는 모델 가운데가 자리에 온다. 고리(걸이)는 위쪽에 두면 자연스럽다.
- 파트를 너무 많이 쓰지 않는다. 트리 하나에 오너먼트 10개, 서버에 트리 여러 개가 있다. 장식 하나에 파트 10개 안쪽을 권한다.

### Studio에 넣기

1. Blender에서 **File → Export → FBX**로 내보낸다.
2. Studio **Home → Import 3D**로 FBX를 불러온다. Workspace에 Model이 생긴다.
3. Explorer의 `ReplicatedStorage` 안에 `DecorationModels` 폴더를 만들고(처음 한 번), 모델을 그 안으로 옮긴다. (Rojo는 이 폴더를 건드리지 않는다)
4. 모델 이름을 장식 `id`와 **똑같이**(대소문자까지) 바꾼다. 예: `TungSahurKeyring`. 그러면 자동으로 연결되고 `Decorations.luau`는 고칠 필요가 없다.
5. (모델 이름을 `id`와 다르게 지었을 때만) 그 장식 줄에 `model = "모델 이름"`을 붙인다.
   ```lua
   { id = "TungSahurKeyring", name = "퉁퉁퉁 사후르 키링", rarity = "Common", area = "Ornament", model = "TungSahurKeyringV2" },
   ```
6. Play해서 트리에 걸어 본다. 확인이 끝나면 플레이스를 저장(`Cmd + S`, Publish)한다. 모델은 GitHub가 아니라 플레이스 파일에 저장된다.

### 걸었을 때 고치기 (장식 줄에 추가)

| 문제 | 고치는 법 |
| --- | --- |
| 너무 작거나 크다 | `size = 1.3` (1.3배), `size = 0.8` (0.8배) |
| 뒤를 보고 있다 | `turn = 180` |
| 옆을 보고 있다 | `turn = 90` 또는 `turn = -90` |
| 오너먼트가 트리에 묻힌다 | `out = 0.4` (0.4스터드 바깥으로). 더 묻히면 숫자를 키운다 |
| 오너먼트가 너무 눕거나 너무 서 있다 | `lean = 30` (더 기울임), `lean = 10` (덜 기울임), `lean = 0` (똑바로). 안 쓰면 10 |
| 토퍼가 꼭대기 위에 떠 있다 (모자·머리처럼 씌우고 싶다) | `sink = 0.5` (모델 높이의 절반이 꼭대기 아래로). 0~1 사이. `id`가 `Hair`로 끝나는 토퍼는 안 써도 0.5 |
| 모델이 안 보이고 공이 나온다 | `DecorationModels` 안의 모델 이름이 장식 `id`(또는 적어 둔 `model`)와 대소문자까지 같은지 확인. `model`을 적었는데 못 찾으면 Output에 `장식 모델을 찾지 못했습니다`가 나온다 |

```lua
{ id = "TungSahurKeyring", ..., size = 1.2, turn = 180 },
```

띠(Garland) 모델은 줄 모양이라 트리를 감싸는 방식이 따로 필요하다. 지금은 오너먼트와 토퍼만 모델을 권한다.

### 랜덤 색이 칠해지는 곳 (Paint 파트)

모델은 **장식마다 하나만** 만든다. 색별로 따로 만들 필요 없다.

1. 색을 바꿀 부분(머리, 리본 등)은 **파트 이름을 `Paint`로 시작**하게 짓는다. 예: `PaintHair`, `PaintRibbon`. 여러 개여도 된다.
2. 장식 줄에 `paintable = true`를 붙인다. 예: `{ id = "MikuKeyring", ..., paintable = true },`
3. 뽑을 때 `src/shared/Catalog/Paints.luau`의 색 중 하나가 랜덤으로 정해지고, `Paint` 파트만 그 색으로 칠해진다. 나머지 파트(눈, 고리 등)는 원래 색 그대로다.

- 색이 다르면 가방 칸이 따로 생긴다. 그래서 `Paint` 파트가 있는 모델에만 `paintable`을 켠다.
- `Paint` 파트는 **그림(TextureID) 없이 단색**으로 만든다. 그림이 있으면 색을 바꿔도 거의 안 바뀐다. Blender에서는 칠할 부분을 따로 떼어 단색 재질로 두면 된다.
- 색 목록은 `Paints.luau`에서 추가·수정한다(`id`는 바꾸지 않기, 그만 쓸 색은 `retired = true`).
- 특성 분위기(빛 안개)는 모델의 `PrimaryPart`(없으면 가장 큰 파트)에 붙는다.

---

## 6-1. 트리 효과 (상점)

뽑기가 아니라 상점에서 코인으로 사는 꾸미기다. **파일 두 곳**에 적는다.

1. `src/shared/Catalog/TreeEffects.luau`에 한 줄 추가
   ```lua
   { id = "SnowGlobe", name = "스노글로브", area = "Effect" },
   { id = "GiftPile", name = "선물 더미", area = "Floor" },
   { id = "SnowField", name = "눈밭", area = "Floor", spread = true },
   ```
   - `area`: `"Effect"`(트리 효과, 하나만 켜짐) 또는 `"Floor"`(바닥, 여러 개)
   - `spread = true`: 바닥 아이템을 트리 밑 가운데에 넓게 깐다(잔디·마법진). 없으면 트리 둘레 바닥 자리에 하나씩 놓는다(선물 더미)
   - `size = 1.2`: 모델 크기 배수
2. `src/shared/Config.luau`의 `TREE_EFFECT_COST`에 코인 가격을 적는다. 로벅스 가격은 `TREE_EFFECT_ROBUX_PRICE`(지금은 '준비 중'으로만 보임)
3. 모양: Studio에서 `ReplicatedStorage` 안에 `TreeEffectModels` 폴더를 만들고 모델 이름을 `id`와 똑같이 지어 넣는다. 방향 규칙은 장식 모델과 같다(`docs/DECORATION_MODELS.md`). 모델이 없으면 코드로 만든 기본 효과가 있는 `Grass`·`Fire`·`Confetti`·`Lightning`만 보이고, 나머지는 Play할 때 Output에 `모양이 없는 트리 효과` 경고가 나온다.
   - 크기는 자동: 넓게 까는 바닥은 트리 지름보다 조금 크게, 바닥 자리 아이템은 3스터드, 트리 효과는 트리 높이의 1.3배.
   - 모델 안 스크립트는 지워진다. 빙글빙글 도는 마법진처럼 스크립트로 움직이던 효과는 멈춰 보일 수 있다. 그럴 땐 Claude에게 움직임을 넣어 달라고 한다.
4. `id`는 출시 후 바꾸지 않는다. 그만 팔려면 `retired = true`.

## 7. 밸런스

- 장식을 추가하거나 이름을 바꾸는 건 밸런스에 영향이 거의 없다.
- 특성 `n`·`mult`, 장식 `weight`, 등급을 바꾸면 수입과 목표 도달 시간이 달라진다. 크게 바꿀 때는 Claude에게 "시뮬레이터 돌려줘"라고 하면 `tools/balance_sim.py`로 확인한다.
- 확정된 목록은 `GAME_RULES.md`에도 반영한다.

---

## 8. 자주 나는 오류

Play를 눌렀을 때 Output에 `[카탈로그 오류]`가 나오면 그 아래 줄을 읽는다.

| Output 메시지 | 고치는 법 |
| --- | --- |
| `id가 다른 장식과 겹쳐요` | 다른 `id`로 바꾸기 |
| `id는 영문으로 시작하고 …` | 한글·띄어쓰기·특수문자 빼기 (`눈송이` → `Snowflake`) |
| `rarity는 … 중 하나여야 해요` | 대소문자까지 정확히 (`"rare"` ❌ → `"Rare"` ✅) |
| `area는 … 중 하나여야 해요` | `"Topper"` `"Ornament"` `"Garland"` 중 하나 |
| `… 등급에 뽑힐 수 있는 장식이 하나도 없어요` | 그 등급에 장식을 하나 이상 남기기 (`retired` 아닌 것) |
| `n을 비워 둔 기본 특성이 정확히 1개여야 해요` | 특성 중 하나만 `n`을 비우기 |
| `Expected ',' …` 같은 문법 오류 | 바로 윗줄 끝 쉼표, 따옴표 짝 확인 |
