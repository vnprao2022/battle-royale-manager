# BATTLE ROYALE MANAGER — GAME DESIGN DOCUMENT

> Tài liệu thiết kế duy nhất của dự án. Phiên bản thiết kế: 2026-08-10.
>
> Tài liệu này thay thế vai trò của mọi tài liệu gameplay cũ đã bị xóa. Không tạo lại `GAME_DESIGN.md`, `GAMEPLAY.md`, `MATCH_GAMEPLAY.md`, `WEAPONS_ITEMS.md` hoặc `PROGRESS.md`.

## 0. Quy ước và phạm vi

### 0.1 Thứ tự ưu tiên thiết kế

1. Các quyết định thiết kế trong tài liệu này.
2. Dữ liệu và quy tắc đã được xác nhận bằng test.
3. Implementation hiện tại.
4. Ý tưởng backlog chưa được duyệt.

Nếu implementation hiện tại mâu thuẫn với GDD, implementation được xem là technical debt cần sửa, không phải lý do thay đổi GDD. Phần “Thiết kế mục tiêu” và “Trạng thái triển khai” luôn được tách riêng.

### 0.2 Nguyên tắc bất biến

- Đây là game quản lý đội tuyển PUBG Esports, không phải game bắn súng trực tiếp.
- Người chơi là Manager; AI và tuyển thủ thực thi trận đấu.
- Trận đấu là Battle Royale nhiều đội trong cùng lobby, không phải Team A vs Team B.
- Kết quả chính là placement, kills và points; không dùng Win/Loss làm mô hình kết quả trung tâm.
- Một lobby tối đa 100 tuyển thủ, tương đương tối đa 25 đội × 4 người.
- Dữ liệu không có nguồn phải hiển thị “Chưa đủ dữ liệu”, không tự sinh số giả để lấp UI.
- Các hệ thống phải tạo cảm giác đang vận hành một tổ chức esports thật, không phải điền form quản trị website.

## 1. Tầm nhìn sản phẩm

### 1.1 High concept

Battle Royale Manager là management simulation trên PC. Người chơi xây dựng và điều hành một câu lạc bộ PUBG Esports, đồng thời có thể đảm nhiệm đội tuyển quốc gia. Người chơi quản lý roster, scouting, chuyển nhượng, hợp đồng, training, scrim, chiến thuật, giải đấu, tài chính, cơ sở vật chất, analytics, quan hệ con người và truyền thông.

Fantasy cốt lõi:

> “Tôi đang quản lý một tổ chức esports thật sự, đưa ra quyết định mỗi ngày và hiểu vì sao đội của mình thành công hoặc thất bại.”

### 1.2 Trụ cột trải nghiệm

- **Management:** roster, nhân sự, hợp đồng, tài chính, facility và lịch.
- **Strategy:** chiến thuật theo map, match, lobby và vai trò từng tuyển thủ.
- **Simulation:** trận đấu có nguyên nhân, diễn biến, kết quả và telemetry có thể giải thích.
- **Events:** inbox, player complaint, board, media, transfer và deadline.
- **Decision making:** lựa chọn có đánh đổi, hậu quả lưu dài hạn và phản hồi rõ ràng.

### 1.3 Vai trò người chơi

Người chơi chịu trách nhiệm ở cấp manager/HLV/analyst:

- Chọn và phát triển đội hình.
- Thiết lập định hướng chiến thuật, không điều khiển micro từng nhân vật.
- Lập kế hoạch theo ngày và xử lý xung đột lịch.
- Đàm phán với tuyển thủ, agent, câu lạc bộ và ban lãnh đạo.
- Đọc analytics và điều chỉnh cách chơi.
- Xử lý quan hệ con người, truyền thông và khủng hoảng.

## 2. Game loop và thời gian

### 2.1 Vòng lặp ngày

```text
DAY
→ Calendar và Command Center
→ Training / Scrim / Event / Match / Management
→ Inbox và quyết định bắt buộc
→ Cập nhật trạng thái tổ chức
→ NEXT DAY
→ Lặp lại
```

Mỗi ngày người chơi nên có một số quyết định nhỏ nhưng có ý nghĩa: train ai, cho ai nghỉ, nhận scrim nào, thay roster hay không, có đàm phán hợp đồng không, đăng ký giải nào, dùng chiến thuật nào và trả lời các bên liên quan ra sao.

### 2.2 Đơn vị thời gian

- Đơn vị thao tác cơ bản: **Day**.
- Cấp tổng hợp: Day → Week → Month → Season.
- Có thể dùng Morning/Afternoon/Evening nếu một ngày có nhiều hoạt động cần thứ tự.
- Không còn thao tác “End Week” làm nút tiến thời gian chính.
- Nút chính là **Next Day**.

### 2.3 Quy tắc dừng khi Next Day

Next Day chỉ tiến tới điểm có thể xử lý tiếp theo và phải dừng trước sự kiện cần quyết định. Thứ tự ưu tiên mặc định:

1. Official Match.
2. Tournament event hoặc deadline.
3. Training bắt buộc.
4. Scrim đã xác nhận.
5. Meeting.
6. Media interview.
7. Inbox decision.
8. Facility completion.
9. Contract deadline.
10. Sự kiện quan trọng khác.

Nếu nhiều sự kiện cùng ngày, xử lý theo thời điểm và priority. Game không được tự chạy qua một quyết định bắt buộc.

### 2.4 Calendar

Calendar là nguồn sự thật về thời gian, gồm:

- Tournament, matchday và từng match.
- Team training và individual training.
- Recovery.
- Scrim và Scrim Cluster.
- Contract/transfer meeting.
- Media interview, board meeting và important event.
- Travel.
- Facility construction/completion.
- National Team camp và match.

Mỗi event có ID, loại, thời gian bắt đầu/kết thúc, priority, participant, trạng thái, yêu cầu xử lý, ảnh hưởng và liên kết tới entity nguồn.

## 3. Hệ thống giải đấu

### 3.1 Mô hình Battle Royale

Một match chứa nhiều đội cùng thi đấu. Lobby hợp lệ có thể là 16, 20, 24 hoặc 25 đội; không hard-code 16. Không match nào vượt quá 25 đội hoặc 100 tuyển thủ.

Kết quả mỗi đội:

- Placement.
- Kills.
- Placement Points.
- Kill Points.
- Bonus/Penalty nếu rulebook cho phép.
- Total Match Points.

Không dùng đối thủ duy nhất, score kiểu H2H hoặc Win/Loss làm kết quả chính.

### 3.2 Ba loại giải chính

| Loại | Participant | Phạm vi | Mục đích |
|---|---|---|---|
| Giải Quốc gia | Club trong cùng một quốc gia | Flagship national championship | Vô địch quốc gia, tiền thưởng, ranking và suất quốc tế |
| Giải Quốc nội | Club trong cùng một quốc gia | Hệ thống Tier 1/2/3 | Lịch thi đấu thường xuyên, thăng/hạng và qualification |
| Giải Quốc tế | Club từ nhiều quốc gia, hoặc National Team khi format quy định | Nhiều quốc gia | Danh hiệu quốc tế, prize pool lớn và world prestige |

Không xây thêm SEA, NA hoặc Regional League như một cấp giải độc lập. “Khu vực” chỉ có thể là metadata phục vụ scouting, travel, ranking hoặc điều kiện mời, không phải tầng competition thứ tư.

Giải Quốc gia dành cho club trong quốc gia đó, không đồng nghĩa với giải của National Team. Một giải quốc tế có thể có `participant_type = NATIONAL` để tổ chức World Cup đội tuyển quốc gia mà không tạo thêm loại giải thứ tư.

### 3.3 Tournament definition

Mỗi tournament phải khai báo:

- Identity: ID, tên, quốc gia, loại giải, participant type, tier và prestige.
- Economy: prize pool, prize distribution, entry cost và travel cost.
- Capacity: số đội tối đa 25 và số tuyển thủ mỗi đội.
- Schedule: registration window, start/end date, số ngày, số match và matches/day.
- Format: stage, group/lobby allocation, advancement, elimination và qualification.
- Scoring: placement table, kill point, bonus/penalty và tie-breaker.
- Eligibility: quốc gia, tier, ranking, invitation, roster lock và license.
- Qualification slots: số suất theo quốc gia và đường lấy suất.
- Registration state: eligible, registered, conflict, rejected, invited, ongoing, completed.

### 3.4 Format linh hoạt

Ví dụ format hợp lệ:

- 5 match/ngày × 3 ngày.
- 7 match/tuần × 8 tuần.
- 3 match/ngày × 5 ngày.
- 6 match/ngày × 3 ngày.

Format không được gắn cứng vào một giải hoặc một lobby size. Nếu tournament có nhiều hơn 25 participant tổng, hệ thống phải chia lobby/group; không được đưa tất cả vào một match vượt giới hạn.

### 3.5 Slot quốc tế theo quốc gia

Mỗi giải quốc tế có bảng slot riêng. Một quốc gia có thể nhận 0, 1, 2, 3 hoặc nhiều suất tùy giới hạn tổng của giải. Slot có thể dựa trên:

- Thành tích giải quốc gia/quốc nội.
- Ranking hiện tại.
- Qualification tournament.
- Thành tích quốc tế và lịch sử quốc gia.
- Tier và chính sách của giải.

Không mặc định mọi quốc gia đều có suất. Tổng slot sau phân bổ không được vượt participant limit.

### 3.6 Tournament discovery và đăng ký

Competition Center phải cho xem toàn bộ hệ thống giải, không chỉ giải đang tham gia.

Tab trạng thái: Tất cả, Đang diễn ra, Sắp diễn ra, Đã đăng ký, Đã kết thúc.

Filter: loại giải, quốc gia, tier, participant type, eligibility và thời gian.

Tournament card/detail hiển thị tên, loại, tier, quốc gia, prize pool, lobby size, số match/ngày, ngày bắt đầu/kết thúc, qualification, slot, scoring, format và trạng thái đăng ký.

Luồng đăng ký:

1. Người chơi mở tournament detail.
2. Hệ thống tính eligibility và roster/license requirement.
3. Calendar kiểm tra xung đột với tournament khác, scrim xác nhận, training bắt buộc, travel và event quan trọng.
4. Nếu hợp lệ: **Đăng ký tham gia**.
5. Nếu không hợp lệ: hiển thị **Không đủ điều kiện** cùng lý do.
6. Nếu xung đột: hiển thị **Trùng lịch** và các event liên quan.
7. Tournament đã đăng ký xuất hiện trong tab riêng và Calendar.

### 3.7 Matchday

Matchday là một tập hợp match của cùng stage/ngày, ví dụ Matchday 1 gồm Match 1–5, mỗi match có cùng hoặc khác map theo rotation.

Mỗi match có map, weather, zone seed, redzone policy, participant IDs, scoring rules, roster lock, tactical plan và result.

Người chơi có hai lựa chọn:

- **Simulate/Skip:** chạy cùng simulation core ở tốc độ tức thời, sau đó hiển thị đầy đủ kết quả.
- **Watch Match:** theo dõi simulation qua observer; không điều khiển nhân vật.

Hai lựa chọn phải tạo kết quả theo cùng quy tắc, không có simulator giả riêng.

### 3.8 Match result và standings

Kết quả hiển thị toàn bộ lobby từ #1 đến #N cùng kills, placement points, kill points và total points. Điểm được commit đúng một lần vào tournament standings.

Standings tổng hợp:

- Matches played.
- WWCD/first placements.
- Placement points.
- Kills và kill points.
- Penalty/bonus.
- Total points.
- Rank và qualification/cut state.

Tie-breaker được định nghĩa trong tournament rulebook, ví dụ total points → total kills → WWCD → best recent placement.

## 4. Match simulation và chuẩn bị trận

### 4.1 Mục tiêu simulation

Simulation phải tạo cảm giác đang xem đội thi đấu: alive teams, player status, kills, placement, zone, rotation, engagement, positioning, knock, finish, clutch, highlight và final circle. Kết quả phải giải thích được bằng timeline, telemetry và quyết định chiến thuật.

### 4.2 Hệ thống runtime

- Airborne, drop và loot route.
- White Zone, Blue Zone và Redzone.
- Information model: vision, hearing, scouting và communication.
- Movement, formation, rotation và positioning.
- Weapon, ammo, armor, heal, boost, utility và vehicle.
- Contact, damage, knock, finish, revive và elimination.
- AI/IGL decision theo role, tình huống và manager policy.
- Scoreboard, feed, replay event và final result.

### 4.3 Match preparation

Trước mỗi match, người chơi xem/chọn:

- Tournament, matchday, match number và scoring.
- Map, weather, lobby size và toàn bộ participant.
- Active roster, substitute và player role.
- Energy, form, morale và expected placement range.
- Map preset và match-specific plan.
- Opponent team form, team profile và analyst report.
- Current meta và các thay đổi meta liên quan.

Người chơi chuẩn bị để đối đầu toàn bộ lobby, không chuẩn bị cho một đối thủ duy nhất.

### 4.4 Observer và replay

Observer hiển thị tactical map, zone, team markers, alive count, roster status, kill feed, selected team/player, timeline và tốc độ. Replay phải có snapshot đủ để dựng lại marker và zone theo thời điểm, không chỉ phát danh sách text trên ảnh nền.

## 5. Chiến thuật

### 5.1 Cấu trúc tactical plan

- **Drop:** Hot, Safe, Adaptive, Contested, Split, Compound Priority.
- **Rotation:** Early, Mid, Late, Edge, Center Control, Gatekeeping.
- **Engagement:** Aggressive, Selective, Defensive, Third Party, Trade Focus, Avoid Fight.
- **Formation:** 4-man, 2-2, 3-1, Anchor, Scout, Support.
- **Resource:** heal, utility, ammo và vehicle priority.
- **Endgame:** Hold, Push, Edge, Center, High Ground, Compound Control.

Manager đặt policy; AI/IGL thực thi và có thể thích ứng theo thông tin hợp lệ. Policy không phải điều khiển micro.

### 5.2 Tactics theo map

Mỗi map có preset riêng gồm drop location/route, loot route, rotation timing, zone preference, engagement, vehicle plan, utility priority và endgame. Không dùng một chiến thuật duy nhất cho mọi map.

### 5.3 Match Plan

Người chơi có thể tạo override chỉ áp dụng cho một match cụ thể. Match Plan kế thừa map preset rồi cho phép chỉnh. Có thể copy plan cũ nhưng bản copy là dữ liệu độc lập.

### 5.4 Player role

| Role | Trách nhiệm chính |
|---|---|
| IGL | Shot calling, macro, rotation |
| Entry | First engagement, tạo khoảng trống |
| Fragger | Damage và kills |
| Support | Utility, cover, revive |
| Anchor | Giữ vị trí và bảo vệ flank |
| Scout | Information và route safety |
| Flex | Thích ứng vai trò |

Hiệu quả plan phụ thuộc kỹ năng, role familiarity, communication, teamwork, form, energy và morale của những người được giao nhiệm vụ.

## 6. Club, National Team và hồ sơ đội

### 6.1 Hai management context

Club và National Team tồn tại song song. Người chơi chuyển context mà không tạo career thứ hai.

Club quản lý đầy đủ transfer, loan, salary, contract, facility, finance, sponsor và roster dài hạn.

National Team chỉ tham chiếu player canonical theo nationality, không clone player, không transfer và không sở hữu hợp đồng. National Team tập trung vào call-up/release, camp, roster, role, tactics và giải dành cho đội tuyển quốc gia.

### 6.2 Call-up

Điều kiện triệu tập:

- Player có nationality phù hợp.
- Không bị cấm hoặc unavailable.
- Lịch club và national event được kiểm tra.
- Squad size và submission deadline còn hợp lệ.

National roster luôn hiển thị current club. Release chỉ xóa reference khỏi squad, không thay đổi club.

### 6.3 Team Profile

Mọi team trong database đều mở được profile:

- Logo, tên, country, region metadata và Club/National.
- Ranking, rating, form và reputation.
- Roster, coach và staff.
- Recent results, tournament participation và achievements.
- Team style, strengths và weaknesses có confidence/source.

Không có dữ liệu coach/staff/style thì hiển thị “Chưa đủ dữ liệu”, không tạo giả.

## 7. Tuyển thủ, roster và phát triển

### 7.1 Canonical player

Mỗi player có một identity duy nhất được club, national team, match, contract và history cùng tham chiếu. Hồ sơ gồm:

- Identity: ID, tên, handle, nationality, tuổi và ảnh.
- Career: current club, team history và national caps.
- Competitive: role, overall, potential, form, energy và availability.
- Attributes: Aim, Reaction, Game Sense, Communication, Zone Reading, Clutch, Teamwork, Utility và adaptability.
- PUBG source metrics: average rank, kills, damage và survival time cùng provenance.
- Employment: salary, contract, value, clauses và expectation.
- Psychology: morale, trust, happiness, loyalty, ambition và relationship.
- Performance/history: match stats, tournament stats, awards và development history.

Overall là chỉ báo tổng hợp, không phải hệ số duy nhất của simulation.

### 7.2 Roster management

Người chơi quản lý starter, substitute, reserve, role, playing-time expectation, availability và roster lock. Quyết định bench kéo dài ảnh hưởng morale/trust và có thể kích hoạt Inbox.

### 7.3 Training và recovery

Training là calendar activity có duration, intensity, coach/facility modifier, energy cost, injury/risk và expected gain. Nội dung gồm Aim, Reaction, Game Sense, Communication, Zone Reading, Clutch, Teamwork, Utility, role và weapon specialization.

Training tác động attributes, form, energy, morale và chemistry. Recovery ưu tiên energy/readiness nhưng giảm thời gian phát triển. Hoạt động cần thời gian không hoàn tất ngay khi bấm nút.

### 7.4 Quan hệ tuyển thủ

Morale, trust, happiness, loyalty, ambition, playing-time expectation, manager relationship và teammate relationship có memory/history. Promise, benching, salary, role, kết quả đội và hội thoại thay đổi các chỉ số này; chúng tác động performance, contract willingness và transfer desire.

## 8. Scouting, transfer và hợp đồng

### 8.1 Scouting

Scout flow:

```text
SEARCH → SCOUT → PROFILE → CONTACT → NEGOTIATE → OFFER
→ PLAYER/CLUB RESPONSE → NEGOTIATE AGAIN → ACCEPT/REJECT → SIGN
```

Scout report có confidence, source, strengths, risks, role fit, value, salary expectation và affordability. Không được “Đàm phán và ký” bằng một click.

### 8.2 Transfer market

Player của đội mình được đưa vào Transfer List chủ động. Club khác có thể gửi buy, loan hoặc negotiated offer qua Inbox.

Người chơi có thể chấp nhận, từ chối, đàm phán, yêu cầu giá cao hơn hoặc điều khoản khác. Loan gồm duration, fee, salary share, optional purchase clause, expected role và playing time.

### 8.3 Contract negotiation

Điều khoản có thể gồm duration 12/24/36 tháng, salary, signing bonus, performance bonus, buyout/release clause, role, playing time, substitute guarantee và team ambition.

Personality, relationship, facility, reputation, tournament access, competing offer và lịch sử promise ảnh hưởng phản hồi. Kết quả có thể accept, reject hoặc counter-offer. Terminate/break contract luôn hiển thị chi phí và hậu quả.

## 9. Scrim Cluster

### 9.1 Mục đích

Scrim cung cấp luyện tập lobby, tactical familiarity, chemistry, opponent analysis và form mà không ảnh hưởng official standings.

### 9.2 Mô hình cluster

Scrim không phải 15 đội gửi 15 lời mời riêng. Một **Scrim Cluster** chứa nhiều đội, ví dụ 15 đội cùng tham gia một lobby luyện tập. Người chơi nhận một invitation để Join hoặc Decline cluster.

Cluster có host, participant list, capacity tối đa 25, map rotation, số match, thời gian, mục tiêu, eligibility và trạng thái. Cluster chỉ xuất hiện khi phù hợp với availability, reputation, season, location/travel metadata và tournament schedule; không xuất hiện mọi ngày.

### 9.3 Luồng và kết quả

1. Invitation xuất hiện trong Inbox và Calendar preview.
2. Hệ thống kiểm tra xung đột lịch.
3. Join tạo event scrim đã xác nhận; Decline đóng invitation.
4. Đến ngày scrim, Next Day dừng.
5. Người chơi chọn roster và training objective rồi simulate/watch summary.
6. Kết quả cập nhật training effect, fatigue, chemistry, form và report.
7. `official_ranking_impact = 0`; không ghi tournament standings.

## 10. Inbox, hội thoại và sự kiện

### 10.1 Inbox là gameplay hub

Contract warning, transfer/loan offer, complaint, board warning, media interview, scrim/tournament invitation, staff message và event quan trọng được xử lý trong Inbox thay vì tạo nhiều màn hình rời.

Mỗi message có Date Sent, Sender, Category, Subject, Body, related entity, deadline, read/resolved state và choices/action.

### 10.2 Hội thoại

Interaction quan trọng có tối thiểu ba hướng trả lời phù hợp ngữ cảnh, không nhất thiết chỉ là tốt/trung lập/xấu. Hậu quả phụ thuộc personality, situation, history, form và lựa chọn trước đó.

Ví dụ player complaint:

- Tích cực: đảm bảo player vẫn nằm trong kế hoạch.
- Trung lập: hứa đánh giá lại dựa trên phong độ.
- Cứng rắn: yêu cầu player chứng minh năng lực.

Hệ quả có thể thay đổi morale, trust, loyalty, performance, relationship, transfer desire và contract willingness. Choice được commit một lần và lưu memory.

### 10.3 Trigger library

- Một ngày sau tournament: media interview.
- Bench quá lâu: player complaint.
- Thành tích dưới mục tiêu: board warning.
- Contract sắp hết: contract warning.
- Club khác quan tâm: transfer/loan offer.
- Tài chính xấu hoặc chi vượt ngân sách: board/investor event.
- Thành tích tốt: praise, sponsor hoặc media opportunity.

### 10.4 Media và board

Media response tác động fan, reputation, morale, board confidence và media perception. Board theo dõi ranking, mục tiêu giải, tài chính, participation và budget discipline; phản hồi của manager có thể thay đổi confidence và job security.

## 11. Tài chính, staff và facility

### 11.1 Finance

Thu gồm prize, sponsor, merchandise, media/streaming và transfer. Chi gồm salary, signing/transfer/loan fee, facility, staff, scouting và travel. Mọi giao dịch có date, category, source entity và transaction ID.

### 11.2 Staff

Coach, analyst, scout, medical và operations staff ảnh hưởng training, recovery, report confidence, negotiation và logistics. Nếu chưa có dữ liệu nhân sự thật, UI không tự tạo hồ sơ giả.

### 11.3 Facility construction

Upgrade không hoàn tất ngay. Mỗi project có cost, construction days, start/end date, remaining days và operating penalty. Ví dụ small 2 ngày, medium 7, large 14 và major 30 ngày. Calendar hiển thị start/progress/completion; completion chỉ áp dụng benefit khi event hoàn tất.

## 12. Analytics và meta

### 12.1 Nguyên tắc dữ liệu

Analytics chỉ dùng telemetry thật với sample size, time range và confidence. Không đủ sample phải nói rõ. Có filter theo player, team, tournament, match, map, zone phase và date range.

### 12.2 Nhóm chỉ số

- **Weapons:** usage, performance, damage, accuracy, kills, preferred weapon và meta tier.
- **Utility:** Smoke, Frag, Flash, Molotov usage/effectiveness.
- **Zone:** position, priority, survival, early/late rotation và rotation success.
- **Redzone:** exposure, survival, risk và positioning.
- **Combat:** damage, kills, knocks, finishes, survival, engagement và clutch.
- **Teamplay:** communication, trade, support, teamwork và formation effectiveness.
- **Drop/Map:** landing success, contested rate, loot quality, route và map-specific results.

### 12.3 Meta Analysis

Analytics so sánh Previous Meta, Current Meta và Trend. Ví dụ SMG usage +12%, AR usage −8%, Late Rotation +15%, Center Control +7%. Meta change phải ghi time window, sample và source; manager dùng insight để cập nhật tactic/map preset/match plan.

## 13. Dashboard và UI/UX

### 13.1 Nguyên tắc

- Decision first: việc cần làm và deadline nổi bật hơn dữ liệu trang trí.
- Progressive disclosure: summary trước, drill-down sau.
- Full-lobby language; không dùng bố cục football VS.
- Responsive ở 1920×1080, 1600×900, 1440×900 và 1366×768.
- Interaction phải có selected, hover, disabled, loading, empty, error và confirmation state.

### 13.2 Command Center

Dashboard hiển thị current tournament, lobby size, current position, points, next event, readiness, urgent Inbox và tasks. Không cố nhồi toàn bộ participant lên dashboard.

CTA **View Lobby** mở danh sách toàn bộ participant; mỗi team mở Team Profile.

### 13.3 Matchday UI

Pre-match hiển thị tournament, matchday, match number, map, weather, lobby size, scoring, team status, tactical plan, analyst insight và hai CTA **Simulate Match** / **Watch Match**.

### 13.4 Inbox UI

Message detail trình bày Date, Sender, Category, Subject, Body, deadline, choices và consequence confirmation. Inbox phải giống một hệ thống giao tiếp sống, không chỉ là list thông báo.

## 14. Save/Profile flow

### 14.1 Create Profile

```text
NEW PROFILE
→ Customize manager / select or create team
→ Career settings
→ Confirm
→ SAVE PROFILE
→ Return to Profile Menu
→ LOAD PROFILE
→ Start Game
```

Không tự vào game ngay sau bước cuối wizard.

### 14.2 Profile management

Hỗ trợ nhiều slot với New, Load và Delete có xác nhận. Save chứa manager, club, national team, season/date, budget, roster, contracts, transfers, tournaments, calendar, inbox, facilities, relationships, tactics, analytics summary và progress. Save migration giữ unknown field khi có thể và không làm hỏng save người chơi.

## 15. Custom Content và Modding

Player Custom Content tách hoàn toàn khỏi Dev Tools. SteamID cung cấp identity; game quản lý career và content library, không cần login/register riêng.

Package `.brm` là archive data + asset:

```text
package.brm
├── manifest.json
├── teams.json
├── players.json
├── tournaments.json
├── leagues.json
├── assets/teams/
├── assets/players/
├── assets/logos/
└── thumbnail.png
```

Luồng: Import → staging → validator → content database → enable trong career. Không import trực tiếp vào official database. Validator kiểm tra schema, reference, format, dimension, size, path traversal và duplicate ID. Không cho package chạy executable hoặc script tùy ý.

Người chơi có thể Import, Export, Create, Edit, Duplicate, Delete và về sau Share qua Steam Workshop. Dev/QA build riêng mới có Match Lab, AI Debugger, Zone Simulator, Database Inspector, entity spawn và time control.

## 16. Liên kết hệ thống

| Nguồn | Tác động trực tiếp | Tác động tiếp theo |
|---|---|---|
| Training | Attributes, form, energy | Match performance, development |
| Playing time | Morale, trust | Performance, complaint, transfer desire |
| Tactics | Drop/rotation/combat decisions | Placement, kills, telemetry |
| Match performance | Tournament points | Ranking, prize, fan, board confidence |
| Transfer/loan | Roster, finance | Team strength, chemistry, expectations |
| Contract | Finance, trust, availability | Retention, transfer request |
| Facility | Training/recovery/scouting quality | Development và long-term performance |
| Analytics/meta | Manager insight | Map preset và Match Plan |
| Tournament | Schedule, qualification | Prize, reputation, international slots |
| Inbox choice | Relationship/board/media state | Future events và negotiation |
| National call-up | Availability, prestige, fatigue | Club planning và national performance |

## 17. Data contract cấp thiết kế

Các entity tối thiểu:

- Player, Team, Staff, Contract, TransferOffer và LoanOffer.
- Tournament, Stage, Matchday, Match, ScoringRule và QualificationSlot.
- CalendarEvent, InboxMessage, DialogueChoice và Consequence.
- TrainingPlan, ScrimCluster, FacilityProject và TacticalPreset.
- MatchResult, PlayerMatchStat, TeamMatchStat, TelemetryEvent và MetaSnapshot.
- CareerSave, ManagerProfile, ClubContext và NationalContext.

Mọi entity dùng stable ID. Reference dùng ID thay vì copy object. Event có date/status; mutation tài chính và match result có transaction ID để chống commit lặp.

## 18. Cấu trúc dự án và ownership hiện tại

```text
battle-royale-manager/
├── DOCUMENTATION.md              # GDD và phụ lục duy nhất
├── project.godot                 # Godot project config
├── scenes/                       # Main scene và scene resources
├── scripts/
│   ├── main.gd                   # Presentation/navigation hiện tại
│   ├── game_state.gd             # Career/save/calendar/system state
│   ├── game_database.gd          # Canonical database adapter
│   ├── match_runtime.gd          # Battle Royale simulation core
│   ├── match_map_overlay.gd      # Observer map presentation
│   ├── map_catalog.gd            # Map definitions
│   ├── asset_registry.gd         # Asset ID resolution/fallback
│   └── content_manager.gd        # Custom package staging/validation
├── database/
│   ├── pubg_teams/               # Canonical team source + images
│   └── pubg_players/             # Canonical player source + images
├── data/                          # Career, map, tactic và gameplay config
├── assets/                        # Official UI/game assets
├── tests/                         # Automated tests và capture scripts
└── build/                         # Generated export; không phải source
```

Ownership mục tiêu:

- `GameDatabase`: official canonical entities, read-only.
- `GameState`: career mutation, calendar, save và cross-system orchestration.
- `MatchRuntime`: simulation và telemetry; không sở hữu UI.
- `ContentManager`: package staging, validation và library.
- `AssetRegistry`: asset ID và fallback.
- UI: trình bày state và phát intent, không tự tạo gameplay truth.

## 19. Trạng thái triển khai so với GDD

Ký hiệu: `[x]` đã có bằng chứng; `[~]` có một phần nhưng chưa đúng toàn bộ GDD; `[ ]` chưa có bằng chứng hoàn chỉnh.

### 19.1 Đã có nền tảng

- `[x]` Canonical PUBG database: 153 team, 637 player, logo/portrait và team history.
- `[x]` Search toàn database, World Ranking, Team Profile và Player Profile navigation.
- `[x]` MatchRuntime, combat/zone/loot/vehicle/AI, observer, result commit và telemetry nền tảng.
- `[x]` Placement + kill scoring và tournament standings nhiều participant.
- `[x]` Club/National context, canonical call-up/release và save/reload nền tảng.
- `[x]` Save slots, migration, custom `.brm` validation/import/export nền tảng.
- `[x]` Functional tests gần nhất: `COMPETITION_SCALING_OK`, `NATIONAL_TEAM_OK`, `SCRIM_SYSTEM_OK`, `CAREER_INTEGRATION_OK`, `NAVIGATION_OK`.

### 19.2 Mâu thuẫn phải sửa theo GDD mới

- `[x]` Runtime và tournament validation đã giới hạn tuyệt đối 25 đội/100 player; regression bao phủ 16/20/24/25.
- `[x]` Tournament catalog chính thức đã chuyển sang `NATIONAL`/`DOMESTIC`/`INTERNATIONAL`; không còn descriptor SEA/NA/regional.
- `[ ]` Scrim hiện là 15 request rời; phải thay bằng Scrim Cluster nhiều participant và xuất hiện theo lịch.
- `[x]` Topbar và GameState đã chuyển sang Next Day; event queue chặn tiến ngày khi còn action bắt buộc và dừng sau khi tới ngày có event.
- `[ ]` Career wizard hiện có thể vào game sau tạo; phải Save → Profile Menu → Load.

### 19.3 Hệ thống chưa hoàn chỉnh

- `[~]` Tournament discovery đọc toàn catalog; registration/unregister, participant context, country eligibility, schedule conflict, Calendar và save/load đã hoạt động. Tab/filter đầy đủ, deadline lifecycle và qualification/slot allocation nâng cao vẫn còn thiếu.
- `[ ]` Multi-stage/multi-lobby format khi tổng participant vượt 25.
- `[ ]` Simulate/Watch dùng chung core với Matchday nhiều match hoàn chỉnh.
- `[ ]` Transfer list chủ động, incoming buy/loan offer và negotiation nhiều vòng.
- `[ ]` Contract clause/counter-offer/personality đầy đủ.
- `[ ]` Calendar theo ngày, training duration, travel và facility construction time.
- `[ ]` Inbox có date/sender/deadline, dialogue ba hướng và trigger library đầy đủ.
- `[ ]` Player relationship/memory ảnh hưởng xuyên hệ thống đầy đủ.
- `[ ]` Full analytics cho weapon, utility, zone, redzone, combat, teamplay, drop và meta trend.
- `[ ]` Map-specific preset, match override và role-effect depth đầy đủ.
- `[ ]` Dashboard View Lobby và Matchday preparation theo đặc tả mới.
- `[ ]` Replay snapshot dựng lại marker/zone; localization catalog; soak test; RID/ObjectDB cleanup.

Trạng thái sản phẩm: **NOT PRODUCTION READY**.

### 19.4 Báo cáo Phase 1 — Data Architecture

- `[x]` Tournament descriptor nằm trong `database/tournaments/tournaments.json`, có type, participant type, tier, capacity, schedule, scoring, tie-breaker, qualification, slot và prize distribution.
- `[x]` `GameDatabase.validate()` từ chối type sai, lobby trên 25, squad size khác 4 hoặc `max_players` không khớp.
- `[x]` Club country được suy ra deterministic từ nationality chiếm đa số trong canonical roster; National Team dùng country identity riêng.
- `[x]` `MatchRuntime.MAX_TEAM_COUNT = 25`; không còn lobby 32 trong catalog production.
- `[x]` Registration state được lưu trong save v6; Register tạo Calendar events thật, Unregister xóa event chưa hoàn tất và load khôi phục trạng thái.
- `[x]` Schedule conflict chặn đăng ký khi event bắt buộc chồng ngày thi đấu.
- `[x]` Competition Center hiển thị type/tier/country/capacity/prize và trạng thái registration; nút Register gọi GameState thật.
- `[x]` National Team tiếp tục dùng canonical player reference và pass regression save/load.
- `[~]` International slot đã có data contract và được dùng khi chọn participant; cần qualification pipeline theo kết quả mùa trước để thay cho seed participant ban đầu.

Test Phase 1 đã pass: `DATABASE_TEST_PASS`, `COMPETITION_SCALING_OK` (16/20/24/25 và 64/80/96/100), `TOURNAMENT_REGISTRATION_OK`, `NATIONAL_TEAM_OK`, `SAVE_MIGRATION_OK`, `CAREER_INTEGRATION_OK`, `NAVIGATION_OK`. Navigation vẫn báo RID/ObjectDB leak khi thoát process nên cleanup chưa đạt Definition of Done.

### 19.5 Báo cáo Phase 2 — Time/Event Foundation

- `[x]` `advance_day()` tiến đúng một game day và lưu `current_date`.
- `[x]` Event queue đọc `date`, `time`, `priority`, `requires_player_action`, `completed/status` và sắp xếp deterministic.
- `[x]` Next Day không tiến nếu ngày hiện tại còn event bắt buộc chưa xử lý.
- `[x]` Sau khi tiến tới ngày có event bắt buộc, game trả về stop state và UI điều hướng tới Match Day hoặc Inbox.
- `[x]` Weekly economy/training/world update cũ vẫn được giữ và chạy tại mốc bảy ngày, không tạo hệ thống mô phỏng thứ hai.
- `[x]` Save/load khôi phục ngày và event queue; `NEXT_DAY_QUEUE_OK` xác minh advance, stop, block, resume và save.
- `[~]` Tournament Calendar events đã có time/priority/action contract; training, scrim cluster, facility, contract, media và dynamic Inbox event sẽ được nối dần ở các phase sở hữu chúng.
- `[~]` Inbox hiện có pending choice và consequence nền tảng nhưng chưa đủ date/time/sender/deadline và trigger library theo GDD.

## 20. Definition of Done

Một hệ thống chỉ được đánh dấu hoàn tất khi:

1. Data schema và ownership rõ ràng.
2. Gameplay state thay đổi thật và save/load được.
3. UI có đầy đủ happy, empty, loading, disabled, error và confirmation state.
4. Không dùng dữ liệu giả để che thiếu implementation.
5. Hệ thống liên kết đúng với Calendar, Inbox, Finance, Relationship và Analytics liên quan.
6. Có automated test cho rule quan trọng và regression.
7. Có visual QA ở các độ phân giải mục tiêu nếu có UI.
8. Không mâu thuẫn giới hạn 25 đội/100 người và mô hình full lobby.

Production Ready chỉ được công bố khi toàn bộ hệ thống bắt buộc đã đạt Definition of Done, export chạy trên máy Windows sạch, save migration an toàn, soak test đạt yêu cầu và không còn leak nghiêm trọng.

## 21. Thứ tự phát triển đề nghị

1. Chuẩn hóa competition schema theo ba loại giải và giới hạn 25 đội.
2. Xây Calendar/Next Day/event-stop làm xương sống.
3. Tournament discovery, registration, eligibility, slots và conflict.
4. Matchday nhiều match với Simulate/Watch dùng chung runtime.
5. Scrim Cluster và training/facility duration.
6. Transfer/loan/contract negotiation qua Inbox.
7. Relationship, board, media và dialogue consequence.
8. Tactical preset theo map/match/role.
9. Analytics/meta đầy đủ từ telemetry thật.
10. Save/Profile flow, UI QA, performance, localization và production hardening.
