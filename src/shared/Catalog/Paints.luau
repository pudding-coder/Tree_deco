--[[
	칠하기 색 목록 ― 장식 목록에 paintable = true가 적힌 장식은 뽑을 때 이 중 한 색이 랜덤으로 정해진다.
	정해진 색은 장식 모델의 Paint 파트(이름이 Paint로 시작하는 파트)에 칠해진다. (docs/ADDING_ITEMS.md 6번)
	임시 모양(공)은 공 전체가 이 색이 된다.

	id      저장용 이름. 영문으로 시작, 영문·숫자·_만. (중요) 한 번 정하면 절대 바꾸지 말 것
	name    화면에 보이는 이름 (장식 이름 앞에 붙는다: "분홍 공")
	rgb     { 빨강, 초록, 파랑 } 0~255
	weight  (선택) 나오는 비율. 안 쓰면 1
	retired (선택) true면 더 이상 나오지 않는다. 이미 가진 장식은 그대로
]]

return {
	{ id = "Pink", name = "분홍", rgb = { 255, 150, 190 } },
	{ id = "HotPink", name = "진분홍", rgb = { 255, 90, 160 } },
	{ id = "Red", name = "빨강", rgb = { 230, 60, 60 } },
	{ id = "Orange", name = "주황", rgb = { 255, 150, 60 } },
	{ id = "Yellow", name = "노랑", rgb = { 255, 220, 80 } },
	{ id = "Mint", name = "민트", rgb = { 120, 230, 190 } },
	{ id = "Sky", name = "하늘", rgb = { 130, 200, 255 } },
	{ id = "Blue", name = "파랑", rgb = { 70, 120, 230 } },
	{ id = "Lavender", name = "보라", rgb = { 180, 140, 255 } },
	{ id = "White", name = "하양", rgb = { 245, 245, 250 }, retired = true }, -- 흰 장식 파츠(Trim)와 겹쳐서 뺐다
}
