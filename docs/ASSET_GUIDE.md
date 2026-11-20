# 에셋 작업 매뉴얼 (팀용)

맵 꾸미기와 장식 모델 작업을 여럿이 같이 할 때 보는 문서. 자세한 설명은 각 문서로 이어진다.

| 무엇 | 문서 |
| --- | --- |
| 장식 모델 넣기·바꾸기·방향 | `docs/DECORATION_MODELS.md` |
| 장식 목록(이름·등급)·상점 효과 추가 | `docs/ADDING_ITEMS.md` |
| 맵 배치(트리 자리·벽·바닥·길) 원리 | `docs/MAP.md` |
| 코드 작업·브랜치·Rojo | `docs/WORKFLOW.md` |
| 이 문서에서 쓰는 Command Bar 스크립트 | `tools/studio/*.lua` (VS Code나 GitHub에서 열어 통째로 복사) |

> Command Bar: Studio **View → Command Bar**. 스크립트를 붙여 넣고 Enter. **항상 Play를 멈춘 상태에서** 실행한다(Play 중에 바꾼 건 멈추면 사라진다).

---

## 1. 먼저 알아 둘 것

### 어디에 저장되나

| 무엇 | 저장되는 곳 | 같이 쓰려면 |
| --- | --- | --- |
| 코드(`src/`), 장식 목록, 문서, FBX·그림 원본 | **GitHub** | `git pull` / PR |
| 맵(바닥·소품·트리 자리·벽·길), 장식 3D 모델, 트리 모델 | **플레이스 파일** (Roblox) | Studio 공동 편집(Collaborate) + 저장 |

맵과 모델은 GitHub에 없다. **저장(`Cmd + S`)이나 Publish를 하지 않으면 사라진다.**

### 게임이 읽는 이름 (바꾸지 않기)

게임 코드는 아래 **이름**으로 찾는다. 이름이 다르면 없는 것으로 친다.

| 이름 (Workspace 기준) | 무엇 | 게임이 하는 일 |
| --- | --- | --- |
| `ReplicatedStorage.DecorationModels` | 장식 3D 모델 (이름 = 장식 `id`) | 트리에 걸 때 복제 |
| `ReplicatedStorage.TreeEffectModels` | 상점 효과 모델 (이름 = 효과 `id`) | 효과 켤 때 복제 |
| `ServerStorage.TreeTemplate` | 트리 모델 | 트리 자리마다 복제 |
| `PlotSpots` (안에 `1`, `2` … 파트) | 트리 자리 표시 | 이 위치에 트리를 세운다. 게임 중엔 안 보임 |
| `PlotSpotPads` | 트리 자리 둥근 매트 (흙 + 돌 테두리) | 있으면 그대로 씀 |
| `Baseplate` · `MapFloor` · `MapGround` | 바닥 (이 폴더·모델 안의 파트) | 매트·접속 위치의 바닥 높이로 씀 |
| `MapPaths` | 길 | 바닥 높이 계산에 씀 |
| `MapWalls` | 투명벽 | 게임 중엔 완전히 투명 |
| `StarPole` | 가운데 별 기둥 | 길 스크립트가 광장 가운데로 씀 |
| `MapDecor` | 그 밖의 꾸미기 소품 (가로등·오두막 등) | 없음 (보기만) |

**새 소품은 `MapDecor`에, 새 바닥은 `MapFloor`에** 넣는다. 다른 폴더(특히 `MapWalls`) 안에 섞이지 않게 조심한다.

---

## 2. 같이 작업할 때 규칙

1. **같은 플레이스를 공동 편집(Collaborate)으로** 연다. 각자 다른 플레이스에서 꾸미면 합칠 수 없다.
2. **구역을 나눈다.** 예: A는 북쪽 반, B는 남쪽 반. 같은 모델을 동시에 만지지 않는다.
3. **다시 만드는 스크립트는 한 사람만, 말하고 실행한다.** `make_pads`, `layout_plots_and_pads`, `walls_round`, `paths_*`는 폴더를 **지우고 새로 만든다**. 다른 사람이 그 안에 넣어 둔 걸 같이 지운다.
4. **큰 작업 전 백업**: 지형이 든 에셋, 맵 통째 에셋, 다시 만드는 스크립트를 쓰기 전에 **File → Save to File As**로 내 컴퓨터에 사본을 저장한다(예: `트리맵_1120.rbxl`).
5. 망쳤으면: `Cmd + Z` → 안 되면 Creator Hub → 게임 → **Places → Version History**에서 예전 버전 복원 → Studio에서 플레이스를 **저장하지 말고 닫았다가 다시 연다**.
6. Rojo(코드 연결)는 원래 게임 플레이스에 **한 명만** 연결한다(`docs/WORKFLOW.md`).

---

## 3. 에셋 가져오기

| 어디서 | 방법 | 다음 할 일 |
| --- | --- | --- |
| Toolbox (무료 모델) | 3D 화면의 원하는 자리로 **끌어다 놓기** | 4번 체크리스트 |
| Toolbox (안전하게) | 에셋 오른쪽 클릭 → Copy Asset ID → `tools/studio/safe_insert.lua`의 `ID`에 넣고 실행. 스크립트 삭제·고정·`MapDecor`에 넣기까지 한 번에 | 위치만 옮기기 |
| FBX 파일 (Blender로 만든 것, `assets/models/…`) | **Import 3D** → 창에서 **Anchored 체크** → Import | 색이 회색이면 아래 5-E |
| `.rbxm` 파일 | 넣을 폴더 오른쪽 클릭 → **Insert from File** | 4번 체크리스트 |

> **지형(Terrain)이 든 에셋**은 기존 지형을 덮어쓴다. 넣기 전에 반드시 백업.

---

## 4. 넣은 직후 체크리스트 (무료 모델)

1. **스크립트 지우기 + 고정**: 넣은 모델을 선택하고 `tools/studio/clean_selection.lua` 실행.
   - 무료 모델에는 `qTexture`, `TextureConfiguration`, `CoreViewSystem` 같은 이름으로 위장한 **백도어**가 자주 숨어 있다.
   - 고정하지 않으면 Play할 때 떨어지거나 쓰러진다(나무 잎이 떨어지는 것도 이것).
   - 스크립트는 **편집 중엔 실행되지 않는다**. Play·Publish 전에만 지우면 된다.
2. **폴더 정리**: `MapDecor`(소품) / `MapFloor`(바닥) / `DecorationModels`(장식)로 옮긴다. 여러 개 옮기기: 선택 → `Cmd + X` → 폴더 선택 → `Cmd + Shift + V`(Paste Into, 위치 유지).
3. **바닥에 맞추기**: 떠 있거나 묻혔으면 선택하고 `tools/studio/snap_to_floor.lua`.
4. 필요 없는 부분 지우기: Explorer에서 첫 칸 클릭 → `Shift`+마지막 칸 클릭 → Delete.

---

## 5. 종류별 작업

### A. 장식 모델 (트리에 거는 것)

`docs/DECORATION_MODELS.md`를 따른다. 핵심만:

- `ReplicatedStorage.DecorationModels`에 넣고 **이름을 장식 `id`와 똑같이**(대소문자까지).
- 앞(얼굴)은 Front(-Z), 위는 위(+Y). 여러 개는 꺼내기 → 돌리기 → 다시 넣기 스크립트로 한꺼번에.
- 크기·묻힘·기울기는 `Decorations.luau` 장식 줄에 `size` / `out` / `lean` / `sink` / `turn`.
- 새 장식은 장식 목록에도 한 줄 추가(`docs/ADDING_ITEMS.md`). 모델만 넣으면 게임에 안 나온다.
- 지워도 플레이어가 가진 장식은 안 사라진다(모양만 임시 공으로 바뀜). **장식 줄(id)은 절대 지우지 않는다.**

### B. 맵 소품 (가로등·오두막·울타리 등)

- `MapDecor` 폴더에 넣는다. 울퉁불퉁한 바닥에서는 `snap_to_floor.lua`로 높이를 맞춘다.
- 자꾸 클릭에 걸리는 큰 것(벽·길·매트·바닥)은 `tools/studio/lock_toggle.lua`로 잠근다.

### C. 바닥

- 새 바닥 에셋은 **`MapFloor` 폴더**에(또는 지금처럼 `Baseplate` 안에) 넣고 고정한다. 이름이 맞아야 매트·접속 위치가 그 바닥에 맞춰진다.
- 예전 바닥은 지우거나 아래로 내려 **겹치지 않게**(겹치면 깜빡인다).
- 기울었으면 Properties → Orientation의 첫째·셋째 값을 0으로.
- **바닥을 바꾼 뒤에는 6번 순서대로 다시 실행**한다.

### D. 트리 자리 · 매트 · 길 · 벽

판 위치나 바닥이 바뀌면 **이 순서로** 다시 실행한다(한 사람만):

1. `tools/studio/layout_plots_and_pads.lua` — 자리 수(`COUNT`, 지금 12)·매트 지름(`PAD`, 지금 50)으로 판을 원 둘레에 다시 놓고 매트까지 만든다. 포토존 자리(판 사이 가장 큰 틈)는 비워 둔다.
   - 판만 손으로 옮겼으면 `tools/studio/make_pads.lua`(매트만 다시 만들기).
2. `tools/studio/walls_round.lua` — 원형 투명벽.
3. 길: 바닥이 메시면 `tools/studio/paths_mesh_floor.lua`, 지형이면 `paths_terrain_floor.lua`.
4. 저장.

- 자리 수를 바꾸면 `Config.luau`의 `SERVER_MAX_PLAYERS`와 **Roblox 게임 설정의 최대 인원**도 같게.
- 판 하나만 손볼 때는 판(`PlotSpots`의 숫자)과 매트(`PlotSpotPads`의 `Spot숫자`)를 **같이 선택해서** 옮긴다. 트리는 판 바닥 높이에 선다.
- SpawnLocation은 별 기둥과 겹치지 않게 광장 빈 바닥에.

### E. 우리가 만든 FBX (`assets/models/map/`)

- Import 3D로 불러오면 대부분 **회색**이다. 모델을 선택하고 `tools/studio/recolor_fbx.lua` 실행(파트 이름 끝 `_Wood`, `_Gold` 등으로 색을 입힌다).
- `StarPole.fbx`는 색 그림이 들어 있어 **불러오기만 하면 색이 보인다**(색 입히기 쓰지 않기).
- 새 FBX는 Claude에게 만들어 달라고 하면 `tools/blender/`에 스크립트와 함께 만든다.

### F. 파티클 (눈 내리는 기계 등)

- 눈꽃 그림: `assets/textures/snowflake.png` (Roblox에 올린 ID `92676423649432`).
- 양·속도·모양 바꾸기: `tools/studio/particles_snow.lua`의 `TARGET`(파티클이 든 모델 이름)을 맞추고 실행.
- 그림을 새로 올린 직후엔 `Asset content representation is being generated`가 뜬다. 몇 분 기다리면 보인다.

---

## 6. Publish 전 체크리스트

1. `tools/studio/scan_scripts.lua` 실행 → 목록을 보고 `DELETE = true`로 다시 실행 → **`찾음: 0`** 확인. (우리 코드 `Server`·`Client`·`Shared`는 건너뛴다)
2. **Play로 확인**: 트리가 매트 위에 서는지, 접속하면 트리 앞 바닥에 서는지, 장식 모델이 보이는지, 떨어지는 소품이 없는지.
3. 저장(`Cmd + S`) → **File → Publish to Roblox**.
4. 친구에게 예전 모습이 보이면: Creator Hub → 게임 → 서버 → **업데이트되지 않은 서버 다시 시작**.

### 아바타 모델 (NPC·마네킹)

`tools/studio/make_avatar.lua`를 Command Bar에서 실행하면 카메라 앞 바닥에 사람 모양 모델(`AvatarModel`)이 서고, `MapDecor`(없으면 Workspace)에 들어간다.

- 맨 위 설정만 바꾼다: 이름, 머리 위 이름표(`DISPLAY_NAME`), 옷 색, `R15`/`R6`.
- `USER_ID`에 로블록스 사용자 번호를 넣으면 그 사람 옷차림으로 만든다.
- 기본은 고정된 마네킹(`ANCHORED = true`, 안의 스크립트 지움). 같은 이름으로 다시 실행하면 지우고 새로 만든다. 여러 개가 필요하면 이름을 바꿔 실행한다.

---

## 7. 자주 겪는 문제

| 증상 | 원인 | 해결 |
| --- | --- | --- |
| 나한텐 보이는데 친구한텐 안 보이는 모델 | Import 3D로 올린 메시가 Roblox **검토 중** (올린 사람만 보임) | 기다리기. Creator Hub → 개발 아이템 → 메시. 다른 계정으로 접속해 확인 |
| 친구 트리 장식이 다 공 | 그 장식들에 **3D 모델이 아직 없음** | 장식 모델 채우기 (5-A) |
| 친구한테 맵이 예전 그대로 | 예전 서버에 들어감 | 6번 4 (서버 다시 시작) |
| Play하면 물건이 떨어짐 | 고정 안 됨, 또는 안의 스크립트가 고정을 풂 | `clean_selection.lua` |
| 트리·캐릭터가 눈에 묻힘 | 판이 바닥보다 아래, 또는 바닥이 게임이 읽는 이름이 아님 | 바닥을 `MapFloor`/`Baseplate`에 넣고 6번 D 순서 다시 |
| 매트가 판을 안 따라옴 | 매트는 만든 자리에 고정 | `make_pads.lua` 다시 |
| 투명벽 근처 나무 잎이 잘림 (편집 중) | 반투명끼리 겹침 | 게임에선 괜찮음. 편집 중엔 `walls_visible_toggle.lua` |
| 3D 화면에서 벽·길이 자꾸 클릭됨 | 잠금 안 됨 | `lock_toggle.lua` |
| 모델 색이 회색 | Import 3D가 재질 색을 안 가져옴 | `recolor_fbx.lua` 또는 Properties → Color |
| Material을 바꿔도 그대로 | Model 전체를 선택함(색·재질은 안쪽 파트에 있음) | Explorer에서 안쪽 파트 선택, 또는 3D 화면에서 `Alt`(맥 `Option`)+클릭 |
| 넣자마자 다른 게 사라짐 | 지형 에셋이 덮어씀 / 실수로 삭제 | `Cmd + Z` → Version History (2번 5) |
| Creator Hub 오류 `cannot require using asset ID` | 무료 모델 백도어 | 6번 1 |
