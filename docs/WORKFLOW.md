# 작업 시작·마무리 순서

매번 작업을 시작할 때와 노트북을 끄기 전에 이 순서대로 한다.

---

## 시작할 때

1. **최신 코드 받기**
   ```bash
   cd ~/Tree_deco && git pull
   ```
2. **Rojo 켜기** — 이 터미널 창은 작업 내내 그대로 둔다.
   ```bash
   rojo serve
   ```
   `Address already in use` 오류가 나면 예전 Rojo를 끄고 다시 켠다.
   ```bash
   pkill rojo
   ```
3. **Studio 연결** — 게임을 열고, Play 중이 **아닐 때** **Plugins → Rojo → Connect**.
   빨간 **Disconnect** 버튼과 `Synced ...`가 보이면 연결된 것이다.
4. 작업 시작.

---

## 끝낼 때 (노트북 끄기 전)

### 1. VS Code 저장

- `Cmd + Option + S` — 열린 파일 전부 저장
- 탭 이름 옆에 `●`가 남아 있지 않은지 확인

### 2. Studio 정리

- Play 중이면 ■ **Stop**
- Studio 안에서 직접 바꾼 것(맵, 3D 모델, 게임 설정)이 있으면 `Cmd + S`로 저장
  - 코드는 GitHub에 있으므로 Studio에서 따로 저장하지 않아도 된다.
- **Publish는 실제 게임에 올릴 때만** 한다.

### 3. 고친 파일 올리기

VS Code에서 파일을 고쳤을 때만 한다.

```bash
cd ~/Tree_deco && git status
```

`nothing to commit`이 나오면 올릴 것이 없다 → 4번으로.
바뀐 파일이 나오면 아래를 한 줄씩 실행한다.

```bash
git add -A
```
```bash
git commit -m "무엇을 바꿨는지 짧게"
```
```bash
git pull
```
```bash
git push
```

> `git pull`에서 `CONFLICT`가 나오면 더 진행하지 말고 그 화면을 Claude에게 보낸다.

### 4. Rojo 끄기

`rojo serve` 창에서 `Ctrl + C`.
끄지 않고 노트북을 닫으면 다음에 `Address already in use` 오류가 날 수 있다.

### 5. Claude에게 알리기 (선택)

올린 것이 있으면 "올렸어"라고 알려준다. Claude가 작업 전에 받아서 충돌을 막는다.

---

## 자주 겪는 문제

| 증상 | 해결 |
| --- | --- |
| Studio에 코드가 안 바뀜 (Output의 `Main:줄번호`가 그대로) | Rojo 창에서 Disconnect → Connect. 그래도 안 되면 `pkill rojo` 후 `rojo serve` |
| Connect 누르면 `Http requests can only be executed by game server` | Play 중이다. ■ Stop 후 Connect |
| `git pull`에서 `CONFLICT` | `git rebase --abort` 후 Claude에게 화면 전달 |
| VS Code 왼쪽에 `src` 폴더가 없음 | 다른 폴더를 연 것. 터미널에서 `open -a "Visual Studio Code" ~/Tree_deco` |
| Output에 `[카탈로그 오류]` | 장식·특성 파일 오타. [ADDING_ITEMS.md](ADDING_ITEMS.md) 8번 참고 |

---

## 팀 작업

### 브랜치 규칙

- `main`은 모두가 보는 기준이다. **`main`에 직접 올리지 않는다.**
- 각자 `main`에서 자기 브랜치를 만들어 작업하고, 끝나면 PR로 `main`에 합친다.
- 브랜치 이름: `이름/작업내용` (예: `minji/new-decorations`). Claude는 `claude/...` 브랜치를 쓴다.
- 남의 브랜치에는 올리지 않는다.

```
main ─────●──────────●──────────●───→
           \        /  \        /
 claude/... ●──●──●     \      /
                         \    /
 이름/작업내용            ●──●
```

### 처음 합류할 때 (팀원)

1. 저장소 주인에게 GitHub 저장소(**Settings → Collaborators**)와 Roblox 게임(Studio의 **Collaborate**) 초대를 받는다.
2. 내려받기
   ```bash
   cd ~ && git clone https://github.com/pudding-coder/Tree_deco.git
   ```
3. Rokit 설치 (한 번만), Rojo 설치
   ```bash
   curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
   ```
   터미널을 다시 열고
   ```bash
   cd ~/Tree_deco && rokit install && rojo plugin install
   ```
4. VS Code에서 `~/Tree_deco` 폴더를 연다. (확장: Luau Language Server)

### 새 작업 시작 (팀원)

```bash
cd ~/Tree_deco && git checkout main && git pull
```
```bash
git checkout -b 이름/작업내용
```

작업한 뒤 처음 올릴 때:

```bash
git add -A && git commit -m "무엇을 바꿨는지" && git push -u origin 이름/작업내용
```

GitHub 저장소 페이지에 뜨는 **Compare & pull request** 버튼으로 PR을 만든다. 저장소 주인이 확인하고 합친다.

### Rojo는 한 플레이스에 한 명만

같은 플레이스에 두 사람이 동시에 Rojo **Connect**하면 서로의 코드로 덮어쓴다.

- **각자 테스트용 플레이스를 따로 쓴다.** Studio에서 새 Baseplate를 만들어 **Publish**(새 게임으로) → 거기에 Rojo 연결.
  저장(DataStore) 테스트도 하려면 그 플레이스의 **Game Settings → Security → Enable Studio Access to API Services**를 켠다.
- 원래 게임 플레이스에는 `main`이 확정된 뒤 **한 사람만** 연결해서 반영하고 Publish한다.

### 같은 파일을 동시에 고치지 않기

장식 목록(`Decorations.luau`), `Config.luau`처럼 여럿이 자주 고치는 파일은 작업 전에 누가 고칠지 말해 두면 충돌이 줄어든다.
충돌이 나면 `git rebase --abort`(또는 `git merge --abort`) 후 Claude에게 화면을 보낸다.

---

## 언제 main에 합치나

Studio에서 동작을 확인한 기능이 하나 끝났을 때, Publish 직전, 며칠 쉬기 전.
Claude에게 "병합해줘"라고 하면 PR을 만들고 합친다.
