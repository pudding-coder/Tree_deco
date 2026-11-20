--[[
	트리 효과 목록 ― 상점에서 코인(또는 로벅스)으로 사서 내 트리에 켜는 꾸미기. 뽑기에는 나오지 않는다.
	가격은 Config.luau의 TREE_EFFECT_COST(코인)·TREE_EFFECT_ROBUX_PRICE(로벅스)에 id로 적는다.
	자세한 방법: docs/ADDING_ITEMS.md '트리 효과'

	id      저장용 이름. 영문으로 시작, 영문·숫자·_만. (중요) 한 번 정하면 절대 바꾸지 말 것 (바꾸면 산 사람 효과가 사라짐)
	name    화면에 보이는 이름. 언제든 바꿔도 된다.
	area    "Effect"(트리 효과. 하나만 켤 수 있다) "Floor"(바닥. Config.MAX_FLOOR_ITEMS개까지 켤 수 있다)
	spread  (선택, 바닥만) true면 트리 밑 가운데에 넓게 깐다(잔디·마법진). 안 쓰면 트리 둘레 바닥 자리에 하나씩 놓는다(선물 더미 등)
	model   (선택) ReplicatedStorage.TreeEffectModels 안의 모델 이름. 안 쓰면 id와 같은 이름의 모델을 쓴다.
	        모델이 없으면 코드로 만든 기본 효과(Grass, Fire, Confetti, Lightning)를 쓰고, 그것도 없으면 아무것도 안 보인다.
	size    (선택) 모델 크기 배수. 안 쓰면 1
	retired (선택) true면 상점에서 더 이상 팔지 않는다. 이미 산 사람은 그대로 갖는다. (삭제 대신 이걸 쓸 것)
]]

return {
	-- 트리 효과 (하나만)
	{ id = "Confetti", name = "컨페티", area = "Effect" },
	{ id = "Fire", name = "불타는 트리", area = "Effect" },
	{ id = "Lightning", name = "벼락 맞는 트리", area = "Effect" },

	-- 바닥 (여러 개)
	{ id = "Grass", name = "잔디밭", area = "Floor", spread = true },
	{ id = "MagicCircle", name = "마법진", area = "Floor", spread = true, model = "CrucifixEffect" },
	{ id = "StrawberryRug", name = "딸기 러그", area = "Floor", spread = true },
	{ id = "FallenLeaves", name = "낙엽", area = "Floor", spread = true },
}
