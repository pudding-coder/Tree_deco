# Tree_deco
로블록스 크리스마스 트리 꾸미기 게임

## Roblox Studio 연결 (Rojo)

```bash
# 1) Rokit 설치 (한 번만)
curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
# 2) 저장소 폴더에서 Rojo 설치 후 실행
rokit install
rojo serve
```

Studio에서 Rojo 플러그인을 설치하고(`rojo plugin install`) 플러그인 창에서 **Connect**를 누르면 `src/` 코드가 반영됩니다.

## 장식·특성 추가

`src/shared/Catalog/Decorations.luau`, `src/shared/Catalog/Traits.luau`에 한 줄씩 추가하면 됩니다. 자세한 방법은 [docs/ADDING_ITEMS.md](docs/ADDING_ITEMS.md)를 보세요.

## 밸런스 값 조정

모든 밸런스 수치는 `src/shared/Config.luau` 한 곳에 있습니다. 값을 고친 뒤 시뮬레이터로 목표 도달 시간을 확인하세요.

```bash
python3 tools/balance_sim.py
```

자세한 순서는 `GAME_RULES.md`의 「부록: 밸런스 값 바꾸기」를 참고하세요.
