--[[
	장식 몸통 색 목록 ― 뽑을 때 서버가 이 중 하나를 같은 확률로 정한다.
	색은 가치에 영향을 주지 않는다. 장식 모델의 Main 파츠에만 칠한다. (docs/ASSET_RULES.md)

	id      저장용 이름. 영문으로 시작, 영문·숫자·_만. (중요) 한 번 정하면 절대 바꾸지 말 것
	name    화면에 보이는 이름. 언제든 바꿔도 된다.
	color   RGB
	retired (선택) true면 더 이상 뽑히지 않는다. 이미 가진 장식은 그 색 그대로다.

	흰색·금색은 Trim 파츠, 황금 특성과 겹치므로 넣지 않는다.
]]

return {
	{ id = "Red", name = "빨간", color = Color3.fromRGB(200, 42, 48) },
	{ id = "DeepGreen", name = "진초록", color = Color3.fromRGB(30, 112, 62) },
	{ id = "LightGreen", name = "연초록", color = Color3.fromRGB(122, 190, 92) },
	{ id = "Navy", name = "남색", color = Color3.fromRGB(38, 58, 124) },
	{ id = "SkyBlue", name = "하늘색", color = Color3.fromRGB(118, 184, 230) },
	{ id = "Purple", name = "보라", color = Color3.fromRGB(132, 82, 172) },
	{ id = "Pink", name = "분홍", color = Color3.fromRGB(240, 140, 172) },
	{ id = "Brown", name = "갈색", color = Color3.fromRGB(150, 96, 56) },
}
