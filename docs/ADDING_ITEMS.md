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
| `effect` | (선택) 보이는 효과 | 트리 꾸미기 작업 후 연결 |

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

## 6. 3D 모델 연결 (트리 꾸미기 작업 이후)

1. Studio에서 장식 모델을 만들거나 Toolbox에서 가져온다.
2. Explorer의 `ReplicatedStorage` 안에 `DecorationModels` 폴더를 만들고 모델을 넣는다. (Rojo는 이 폴더를 건드리지 않는다)
3. 모델 이름을 장식 줄의 `model`에 적는다. 예: `model = "SnowflakeKeyring"`
4. 플레이스를 저장(Publish)한다. 모델은 GitHub가 아니라 플레이스 파일에 저장된다.

---

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
