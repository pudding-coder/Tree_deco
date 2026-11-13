# Tree_deco 작업 규칙

로블록스 크리스마스 트리 꾸미기 게임. Rojo로 `src/`를 Studio에 동기화한다.

## 꼭 지킬 것

- **UI에 이모지를 쓰지 않는다.** 화면에 보이는 글자(버튼, 라벨, 공지, 토스트)와 장식·특성 목록 모두 해당. 아이콘이 필요하면 글자로 쓴다(예: `코인 120`, `잠금`, `[서버]`).
- **플레이어에게 보이는 문장은 `~습니다`/`~입니다` 말투로 쓴다.** 부탁은 `~해 주십시오`. 버튼처럼 짧은 이름은 명사형(`무료 돌리기`, `잠그기`).
- 장식·특성 `id`는 출시 후 바꾸거나 지우지 않는다. 그만 나오게 하려면 `retired = true`.
- 밸런스 숫자는 `src/shared/Config.luau`에만 둔다. `GAME_RULES.md`는 변수 이름으로 가리킨다.
- 게임 결과(뽑기, 판매, 코인)는 항상 서버에서 정한다.

## 위치

| 무엇 | 파일 |
| --- | --- |
| 게임 규칙 | `GAME_RULES.md` |
| 밸런스 값 | `src/shared/Config.luau` |
| 장식·특성 목록 | `src/shared/Catalog/Decorations.luau`, `Traits.luau` (추가 방법: `docs/ADDING_ITEMS.md`) |
| 등급 이름·색 | `src/shared/Rarity.luau` (확률·가치는 `Config.luau`) |
| 특성 글자색 | `src/client/GachaUI.luau`의 `TRAIT_COLORS` |
| 밸런스 시뮬레이터 | `tools/balance_sim.py` |
