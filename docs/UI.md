# 화면 UI 고치기

화면 UI(룰렛, 가방, 상점 등)는 Studio에서 끌어다 놓은 것이 아니라 **코드로 만든다**. 파일은 `src/client/GachaUI.luau` 하나다.
그래서 UI 팩의 Frame을 StarterGui에 넣어도 우리 화면에는 나오지 않는다. 팩에서 쓰는 것은 **이미지 id**뿐이다.

---

## 1. 아이콘 바꾸기 (가장 쉬움)

`GachaUI.luau` 위쪽의 `ICONS` 표만 고치면 된다.

```lua
local ICONS = {
	bag = "rbxassetid://95338657327605", -- 가방 버튼
	upgrade = "rbxassetid://113532507482722", -- 업그레이드 버튼
	tree = "rbxassetid://100186608972356", -- 내 트리 버튼
	roulette = "rbxassetid://104915011936755", -- 룰렛 버튼
	shop = "rbxassetid://132000942692847", -- 상점 버튼
	coins = "rbxassetid://132123388448433", -- 코인 칸
	close = "rbxassetid://93352627659643", -- 창 닫기 X
}
```

- 다른 그림으로: 따옴표 안 숫자만 바꾼다. 팩의 다른 아이콘 id는 표 바로 위 주석에 있다.
- 아이콘 빼기: `""`로 둔다. 닫기 버튼은 다시 `X` 글자로 나온다.
- 크기: `MENU_ICON_SIZE = 36` (메뉴 버튼 아이콘, 픽셀).

### 새 이미지 id 찾기

| 어디서 | 방법 |
| --- | --- |
| UI 팩 안 | Explorer에서 ImageLabel 클릭 → Properties의 **Image** 칸 (`rbxassetid://숫자`) |
| 내 PNG | Studio **Asset Manager → Images → Bulk Import** → 올린 이미지 오른쪽 클릭 → **Copy Asset ID** |
| Toolbox | 이미지(Decal) 넣기 → Properties의 Texture 칸 숫자. Decal id와 Image id가 다를 수 있으니 화면에 안 나오면 Asset Manager로 올린다 |

---

## 2. 색 바꾸기

`GachaUI.luau` 위쪽 `COLORS` 표.

| 이름 | 쓰이는 곳 |
| --- | --- |
| `panel` | 창·메뉴 버튼 배경 |
| `panelLight` | 창 안 버튼 배경 |
| `green` | 돌리기·사기 같은 주 버튼 |
| `gold` | 코인 글자, 공지 테두리 |
| `text` / `subText` | 기본 글자 / 흐린 글자 |

`Color3.fromRGB(빨강, 초록, 파랑)` 숫자(0~255)만 바꾼다.

---

## 3. 글자 바꾸기

`GachaUI.luau`에서 바꿀 글자(예: `"무료 돌리기"`)를 검색해 따옴표 안만 고친다.
규칙(`CLAUDE.md`): 이모지 쓰지 않기, 문장은 `~습니다`/`~해 주세요`, 버튼은 명사형(`잠그기`).

---

## 4. 위치·크기

버튼마다 `build○○Button` 함수 안의 두 줄.

```lua
Size = UDim2.fromOffset(200, 56), -- 가로 200, 세로 56 픽셀
Position = UDim2.new(0, 16, 1, -84), -- 왼쪽에서 16, 아래에서 84 픽셀 위
```

화면 크기에 맞춰 전체가 자동으로 줄고 늘어난다(`UIScale`). 폰 화면은 Studio **Test → Device**에서 기기를 골라 확인한다.

---

## 확인

1. 고치고 저장 → Rojo가 Studio로 옮긴다.
2. **Play**로 확인. 화면에 빨간 오류가 나면 Output을 보고, 바로 윗줄 쉼표·따옴표 짝을 확인한다.
3. 큰 변경(새 창, 배치 바꾸기, 버튼 모양을 팩 이미지로)은 Claude에게 "상점 창을 이렇게 바꿔 줘"처럼 말한다.
