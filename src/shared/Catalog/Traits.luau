--[[
	특성 목록 ― 새 특성은 맨 아래에 한 줄 추가하면 된다.
	자세한 방법: docs/ADDING_ITEMS.md

	id      저장용 이름. 영문으로 시작, 영문·숫자·_만. (중요) 한 번 정하면 절대 바꾸지 말 것
	name    화면에 보이는 이름. 언제든 바꿔도 된다.
	n       확률 분모. 10이면 1/10 확률. 기본 특성 하나만 n을 비워 둔다 (나머지 확률을 가져감).
	mult    가치 배수. 장식 가치 = 레어도 기본 가치 × mult
	effect  (선택) 보이는 효과 이름. 트리 꾸미기 작업 때 연결.
	retired (선택) true면 더 이상 붙지 않는다. 이미 가진 사람은 그대로 갖는다.

	※ 초안: GAME_RULES.md에 확정되기 전 목록이다.
]]

return {
	{ id = "None", name = "기본", mult = 1 },
	{ id = "Glitter", name = "반짝이", n = 10, mult = 1.5, effect = "Sparkle" },
	{ id = "Frost", name = "눈꽃", n = 25, mult = 2, effect = "Frost" },
	{ id = "Golden", name = "황금", n = 100, mult = 5, effect = "Gold" },
	{ id = "Rainbow", name = "무지개", n = 500, mult = 10, effect = "Rainbow" },
	{ id = "Aurora", name = "오로라", n = 3000, mult = 25, effect = "Aurora" },
}
