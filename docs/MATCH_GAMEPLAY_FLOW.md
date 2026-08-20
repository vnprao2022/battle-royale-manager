# Match Gameplay — luồng, dữ liệu và implementation hiện tại

Tài liệu này mô tả **những gì code hiện tại thực sự thực hiện**. Nội dung không suy diễn từ nút, nhãn hoặc ảnh. Các giới hạn chưa có implementation được ghi riêng ở cuối.

## 1. Điểm vào và vòng đời của một match

```text
Career / Tournament event
  → GameState.prepare_match_context(event)
  → GameState.effective_match_plan()
  → MatchRuntime.start_match(game_data, map_id, plan, seed)
  → FLIGHT / DROP
  → AIRBORNE
  → LOOTING
  → REGROUP / ROTATION / CONTACT / COMBAT
  → 5 vòng bo + Red Zone + Airdrop
  → còn 1 team
  → MatchRuntime._finish()
  → result telemetry
  → GameState.apply_match_runtime_result(result, event) nếu là career match
```

Các file điều khiển:

- `scripts/game_state.gd`: lịch thi đấu, chuẩn bị context, coach plan hiệu lực, commit kết quả về career.
- `scripts/match_runtime.gd`: toàn bộ simulation của match.
- `scripts/map_catalog.gd`: load/validate map, hệ số kích thước, nguồn loot, đường và movement profile.
- `scripts/match_map_overlay.gd`: render layer gameplay và tương tác observer/editor.
- `scripts/main.gd`: Match Observer, Match Gameplay LAB và Map Manager.
- `data/tactics/coach_presets.json`: danh sách lựa chọn chiến thuật hợp lệ.
- `data/maps/*.json`: sáu descriptor map schema v2.
- `database/rules/competitive_rules.json`: quy mô lobby/ruleset và danh sách map competitive.

Simulation dùng seed ổn định từ event + map + season, hoặc seed truyền trực tiếp. Cùng state và cùng seed phải sinh cùng result; `tests/match_determinism_test.gd` kiểm tra ranh giới này.

## 2. Cấu trúc map gameplay thật

Tất cả map là hình vuông và dùng tọa độ chuẩn hóa `0.0–1.0` trên cả hai trục. `map_size_km` xác định quy mô vật lý.

| Map | Kích thước | Loot density | Vehicle need |
|---|---:|---:|---:|
| Tactical Island | 4×4 km | ×1.25 | ×0.72 |
| Coastal Breakwater | 4×4 km | ×1.25 | ×0.72 |
| Verdant Reach | 5×5 km | ×1.00 | ×1.00 |
| Frostline Valley | 5×5 km | ×1.00 | ×1.00 |
| Sunscorch Basin | 6×6 km | ×0.82 | ×1.35 |
| Highland Reserve | 6×6 km | ×0.82 | ×1.35 |

Mỗi descriptor schema v2 có các layer dữ liệu sau:

1. `regions`: Landmark/POI có tên, loại (`city`, `port`, `military_base`, `village`, `industrial`, `landmark`), bán kính, terrain, loot multiplier và hotness.
2. `compounds`: khu nhỏ thuộc `poi_id`; có vị trí, bán kính, số/tipo building, cover, hotness, loot multiplier và stock capacity. Runtime loot trực tiếp từ layer này.
3. `roads`: polyline thuộc `highway`, `secondary` hoặc `dirt`; mỗi đường có `width`, `vehicle_speed` và `vehicle_spawn_chance` riêng.
4. `points`: nhà/camp biệt lập, safety cao và loot thấp. Đây là lựa chọn thực tế cho `FIXED_SAFE`/`LOOT_ROUTE`.
5. `transport_nodes`: garage/motorpool có xác suất cấp xe riêng.
6. `terrain_strokes`: nét brush sông hoặc rừng, lưu path, width, movement multiplier và vision multiplier. Sông mặc định cho bơi ở tốc độ ×0.50; rừng mặc định di chuyển ×0.82 và tầm nhìn ×0.55.
7. `buildings`: hình chữ nhật có vị trí/kích thước, cover rating, loot multiplier và số loot slot. Đây là dữ liệu gameplay 2D, không phải hình trang trí.

Hai layer mới là tùy chọn để sáu descriptor cũ vẫn load được; `MapCatalog.load_map()` bổ sung mảng rỗng nếu descriptor chưa có. Khi lưu override từ LAB, toàn bộ nét vẽ/path/width/rectangle được serialize vào `user://map_overrides`. Runtime đọc chung schema này nên không có logic riêng hard-code cho từng map.

`MapCatalog.validate()` từ chối map không vuông, sai kích thước 4/5/6, thiếu layer, road class không hợp lệ, compound không thuộc POI, hoặc compound không có building.

### Điểm đáp

- `HOT_CONTEST`: sort POI theo hotness giảm dần, sau đó đáp vào compound nóng trong POI.
- `FIXED_SAFE`: chọn isolated point có safety cao nhất.
- `SPLIT_LOOT`: hai người đầu thiên về POI/center; hai người sau đi isolated point.
- `ADAPTIVE`: Entry/Fragger thiên hot drop, Scout/Support thiên safe loot, còn lại center.
- `drop_accuracy` tạo xác suất lệch điểm đáp; dù bay tối đa `0.34` normalized từ đường bay.
- Thời gian tiếp đất phụ thuộc quãng bay và `landing_speed`.

### Loot theo kích thước map

Nguồn loot hiệu lực là `compounds + enabled isolated points + enabled buildings`. Named POI không tự phát đồ; POI tổ chức các compound và quyết định drop/hotness.

```text
effective multiplier = source loot_multiplier × map size_density_factor × Custom Rules loot_density_scale
base slots = explicit loot_slots, nếu có
           = 3 với isolated point/building
           = building_count × 2 với compound
generated slots = base slots × effective multiplier (tối thiểu 1)
```

Do đó map 4×4 có mật độ item cao hơn; map 6×6 ít item hơn và có vehicle need cao hơn. Isolated point/building mặc định sinh khoảng ba offer trước hệ số; compound lớn có nhiều offer theo số building.

## 3. Deployment và state của player

Các state được code sử dụng:

- `IN_PLANE`: đi theo plane position.
- `AIRBORNE`: lerp từ jump position tới destination.
- `LOOTING`: loot mỗi 5–8 giây trong khoảng 24–38 giây.
- `ALIVE`, `WALKING`, `DRIVING`, `SWIMMING`: trạng thái di chuyển/chiến đấu.
- `HEALING`, `BOOSTING`, `REVIVING`: action có thời gian và có thể bị ngắt.
- `KNOCKED`: DBNO giảm theo thời gian hoặc sát thương.
- `DEAD`: bị loại hoàn toàn.

Plane hoàn thành đường bay trong 75 giây. Vòng simulation bắt đầu movement sau 70 giây; proximity combat bắt đầu sau 82 giây.

## 4. Loot và inventory

Khi match khởi tạo, mỗi loot source sinh một mảng item thật theo số slot. Slot đầu ưu tiên weapon, slot hai ưu tiên ammo; các slot sau roll từ weapon/ammo/armor/heal/boost/throwable bằng trọng số. SR rất hiếm trong normal loot (AWM/Lynx không nằm trong normal pool); AWM hiện chỉ được cấp bởi airdrop.

Mỗi lượt loot chọn source có multiplier cao nhất đang phủ vị trí player; multiplier không cộng dồn khi overlap. Với building, player phải thực sự nằm trong rectangle. Player chấm điểm từng offer rồi có thể nhặt hoặc bỏ qua:

- Sniper/Scout ưu tiên SR → DMR → AR.
- Entry/Fragger ưu tiên SMG/Shotgun/AR.
- Support ưu tiên DMR/AR/LMG.
- Các role còn lại ưu tiên AR/DMR/SMG.
- Weapon hiện có, armor durability, lượng ammo và nhu cầu heal/utility đều tham gia quyết định.

Item đã nhặt bị xóa khỏi source. Loot efficiency điều chỉnh thời gian giữa hai quyết định; Coach resource plan thay đổi nhịp và ưu tiên:

- `MINIMAL`: interval chậm hơn ×1.30.
- `FULL`: interval nhanh hơn ×0.75 và cộng điểm nhẹ cho mọi offer hợp lệ.
- `HEAL`: cộng ưu tiên lớn cho heal/boost.
- `UTILITY`: cộng ưu tiên lớn cho throwable.

Backpack capacity: không backpack 50; Lv.1 150; Lv.2 220; cấp cao hơn 270. Khi overweight, runtime bỏ Bandage trước rồi bỏ từng 10 ammo; danh sách `discarded` được ghi trong result.

Ammo trong simulation vẫn là **shot unit**: một lần bắn tiêu thụ một unit. UI chỉ quy đổi để tạo cảm giác số viên theo băng/loại súng:

| Category | 1 internal unit hiển thị thành |
|---|---:|
| Shotgun | 5 |
| SMG / AR | 30 |
| LMG | 50 |
| DMR | 10 |
| SR | 5 |
| Pistol | 15 |

Ví dụ AR có `ammo = 3` trong runtime sẽ hiện `90` trên HUD; SR có `ammo = 3` sẽ hiện `15`. Việc quy đổi chỉ là presentation, không thay đổi số fire event.

## 5. Movement, road và vehicle

Movement đọc terrain gần POI nhất và `terrain_rules`. Foot/swim/vehicle có base speed riêng; mức khẩn cấp tăng theo số vòng bo.

- Đi bộ base: `0.00075` normalized/giây.
- Bơi base: `0.00038`.
- Xe base: `0.0022`.
- AI squad dùng base `0.00068` foot và `0.0018` vehicle.
- Urgency: `1 + zone_number × 0.22`, cộng thêm `1.4` từ bo 5.
- Trên đường, vehicle multiplier được nhân với highway/secondary/dirt multiplier; khoảng cách nhận đường dùng chính `width` của nét vẽ.
- Player có thể lấy xe gần transport node hoặc roll xe khi ở trên road. Road chance mặc định: highway 45%, secondary 25%, dirt 8%; sau đó còn chịu `vehicle_need_factor` và `vehicle_density_scale`.
- Terrain brush tham gia movement tại vị trí hiện tại: river chuyển state thành `SWIMMING` và movement ×0.50; forest movement ×0.82.
- Xe có fuel/durability; cạn một trong hai sẽ kết thúc route.
- Người đang lái có 16% xác suất tạo vehicle impact khi fire event, gây raw 120.

Map 6×6 có nhiều transport node, vehicle need ×1.35 và fuel khởi tạo cao hơn; map 4×4 giảm ưu tiên xe.

## 6. Vòng bo

Match mặc định dài tối đa 900 giây.

| Bo | Reveal | Bắt đầu co | Co xong | Radius | Damage base | Severity |
|---:|---:|---:|---:|---:|---:|---|
| 1 | 80s | 130s | 260s | 0.38 | 1 | Rất thấp |
| 2 | 260s | 310s | 450s | 0.25 | 2 | Thấp |
| 3 | 450s | 490s | 610s | 0.15 | 4 | Trung bình |
| 4 | 610s | 645s | 750s | 0.08 | 8 | Khá cao |
| 5 | 750s | 780s | 900s | 0.00 | 18 | Cao |

Damage ngoài blue zone:

- Standing player: `blue_damage × zone_damage_scale × delta × 0.55`.
- Knocked player: DBNO giảm `blue_damage × zone_damage_scale × delta × 0.42`.
- Blue có thể ngắt revive khi HP xuống dưới 75.
- Nếu tất cả đội chết cùng final tick, `_resolve_final_tick_tie()` chọn bằng combat score + seeded random; đây là quy tắc kỹ thuật hiện tại, không phải luật tournament chính thức.

## 7. Red Zone và Airdrop

Red Zone đầu tiên xuất hiện ngẫu nhiên ở 145–190 giây, chỉ khi còn hơn hai team. Tâm và bán kính luôn nằm trong active circle. Một đợt kéo dài 24–38 giây; sau đó chờ 135–210 giây. Mỗi update có 10% chance bắn shell; shell trong phạm vi 0.032 gây raw 140 và có thể finish knocked player.

Airdrop đầu tiên ở 285 giây, các đợt sau cách 210–280 giây. Drop nằm trong 72% active circle. Nếu player team mình cách ≤ 0.13 và engagement không phải `AVOID`, player lấy AWM với 3 internal shot units (HUD hiển thị 15), Helmet Lv.3 durability 90 và Vest Lv.3 durability 120.

## 8. Súng, attachment và combat

Danh sách weapon pool hiện có 41 súng:

- AR: M416, SCAR-L, AUG, QBZ, Beryl M762, AKM, ACE32, Groza, G36C, FAMAS, M16A4, Mutant.
- SMG: UMP45, Vector, MP5K, Micro Uzi, Tommy Gun, PP-19 Bizon.
- DMR: Mini14, Mk12, SLR, SKS, Dragunov, VSS.
- SR: M24, Kar98k, AWM, Lynx AMR.
- LMG: M249, MG3, DP-28.
- Shotgun: S12K, DBS, S686, S1897, O12.
- Pistol: P92, Deagle, R1895, P18C.

Mỗi profile có category, ideal range, accuracy, damage. `WEAPON_PROFILES` và `LEGACY_WEAPON_PROFILES` đều được runtime đọc; “legacy” là tên bảng trong code, không có nghĩa súng bị vô hiệu. Khoảng cách normalized giữa hai player được đổi sang mét bằng cạnh map (`map_size_km × 1000`).

| Category | Optimal | Max | Damage giữ lại ở max | Ý nghĩa implementation |
|---|---:|---:|---:|---|
| Shotgun | 12 m | 40 m | 34% | Rất mạnh ở sát mục tiêu; raw damage tối thiểu 105 trong optimal range. |
| Pistol | 45 m | 120 m | 42% | Sidearm ngắn-trung bình. |
| SMG | 60 m | 180 m | 44% | Xa hơn shotgun nhưng giảm damage theo cự ly. |
| AR | 180 m | 450 m | 52% | Tầm trung. |
| LMG | 220 m | 520 m | 52% | Tầm trung-dài. |
| DMR | 380 m | 850 m | 62% | Tầm xa hơn rifle. |
| SR | 700 m | 1,250 m | 72% | Xa nhất; raw damage tối thiểu 105 trong optimal range. |

Ngoài max range, hit chance bị hạ xuống 1%. Trong range, damage nội suy từ 100% ở optimal tới cột “giữ lại ở max”. Shotgun/SR đủ gây knock một phát khi trúng mục tiêu không có armor; headshot vẫn nhân 1.5. Kết quả thực tế còn phụ thuộc accuracy, falloff, cover và virtual HP của helmet/vest.

```text
hit chance = clamp(
  aim / 115 × weapon_accuracy
  - range_progress × distance_penalty
  - building_cover_rating × 0.38
  + competitive_modifier
  + tactical_plan_bonus,
  0.12, 0.84)

raw damage = weapon_damage × category_distance_falloff × random(0.82, 1.18)
headshot chance = 16%
```

Competitive modifier hiện tại: AI bắn team người chơi `+0.07`; team người chơi bắn AI `-0.035`. Đây là implementation hiện tại và là điểm cần cân bằng tiếp, không phải difficulty setting tổng quát.

Armor/mũ là **virtual HP theo durability**, không giảm theo phần trăm. Damage trước tiên trừ trực tiếp durability của item phù hợp; phần vượt quá mới vào HP. Một hit có thể gây 0 HP damage nếu virtual HP hấp thụ hết. Capacity hiện tại:

- Helmet Lv.1/Lv.2/Lv.3: 35/60/90 virtual HP.
- Vest Lv.1/Lv.2/Lv.3: 50/80/120 virtual HP.

Headshot dùng helmet; body shot dùng vest. Item vỡ khi durability về 0. Damage làm hủy action đang thực hiện. Kill feed lưu và hiển thị khoảng cách mét của knock/kill đã xác nhận.

Attachment slot: scope, muzzle, magazine, grip, stock. Scope bị giới hạn theo category; grip chỉ AR/SMG; stock AR/SMG/DMR/SR; pistol không nhận scope.

## 9. Heal, boost, revive và utility

| Item | Tác dụng | Thời gian |
|---|---|---:|
| Bandage | +10, cap 75 | 4s |
| First Aid Kit | lên 75 | 6s |
| Med Kit | lên 100 | 8s |
| Energy Drink | +40 boost | 4s |
| Painkiller | +60 boost | 6s |
| Adrenaline Syringe | +100 boost | 10s |

Revive chỉ bắt đầu khi rescuer ở trong `0.028` normalized; ra khỏi range sẽ hủy. Communication tăng xác suất ra quyết định revive; discipline/game sense/loot efficiency giảm mistake chance. Boost giảm dần và hồi HP khi còn boost.

Utility gồm Smoke, Frag, Molotov, Flash. Smoke là cover visual; Frag raw 90, Molotov raw 64. Flash hiện có effect visual/event nhưng không có debuff aim/vision riêng. Đây là giới hạn đã xác nhận.

## 10. Tactics và thuộc tính ảnh hưởng

`coach_plan` được merge từ GameState, requested plan và default:

- Drop policy tác động chọn POI/compound/isolated point.
- Zone macro (`EDGE`, `CENTER`, `FAST`, `LATE`) tạo tên macro và target rotation.
- Positioning thay đổi target trong circle.
- Formation + spacing thay đổi offset vị trí bốn thành viên.
- Combat range cộng hit bonus khi khoảng cách phù hợp.
- Flank cộng từ 0 đến 0.07 hit chance.
- Focus fire và target priority quyết định chọn knocked/lowest HP/fragger/isolated/closest.
- Information policy, vision, hearing, game sense, stealth, formation và terrain tác động contact detection.
- Resource plan tác động tốc độ loot và loại tài nguyên ưu tiên.

Các attribute được copy vào runtime: aim, game sense, vision, hearing, reaction, communication, leadership, discipline, composure, stealth, utility, zone reading, drop accuracy, landing speed, loot efficiency, early combat, adaptability, map knowledge và energy. Không phải mọi field đều có formula riêng; ví dụ leadership/energy hiện chủ yếu được giữ trong state, chưa có modifier trực tiếp trong combat formula.

## 11. Event loop, score và kết quả

Sau 80 giây, event generator chạy mỗi 18–32 giây:

- 26% loot.
- 22% rotation.
- 30% contact.
- 14% combat.
- 8% utility/scout.

Proximity combat chạy riêng mỗi 1.5–3 giây khi hai team cách ≤ 0.105. `ai_aggression_scale` nhân contact chance.

Scoreboard dùng `active_match_scoring`: placement points theo rank + `kills × kill_point`. Tie trong bảng ưu tiên team còn sống, thời điểm bị loại và kills. Result gồm scoreboard, player stats, own player stats, loot statistics, combat/zone/vehicle/utility/airdrop events, decision log, kill feed, timeline và final snapshot.

Career match mới gọi `GameState.apply_match_runtime_result()`. Match chạy tự do trong LAB không tự commit career.

## 12. Match Observer, LAB và Map Manager đang làm được gì

### Observer

- Xem map vuông, flight path, bo hiện tại/bo kế, Red Zone, airdrop/effect, bullet trail và mọi player.
- Chọn team/player, xem HP, state, loadout, accuracy, boost, kill feed và ranking.
- Zoom, pan, reset 1:1, lọc team, ẩn/hiện player đã chết.
- Không hiển thị layer thiết kế chi tiết (POI/road/river/forest/building); đây là ranh giới có chủ ý giữa broadcast observer và công cụ phân tích.

### LAB (cần bật Custom Rules / developer mode)

- New Match, pause/resume, tốc độ 1×/4×/16×/32×.
- Chỉnh drop policy, zone macro, formation và engagement trước/new match.
- Xem resources và decision/event log.
- Custom Rules được runtime tiêu thụ: weapon damage, zone damage, loot density, AI aggression, vehicle density và per-weapon modifier.
- Mở Map Manager để xem/chỉnh các gameplay layer. Layer thiết kế cũng được hiển thị trên map LAB.
- LAB không cho điều khiển player trực tiếp hoặc ép một kết quả combat cụ thể.

### Map Manager

- Chọn cả sáu map bằng selector; preview đúng khung vuông.
- Hiển thị POI, compound, highway/secondary/dirt road, isolated loot point, transport node, river/forest brush và building rectangle.
- Drag POI/compound/point; chỉnh vị trí, radius, loot, hotness, capacity, terrain và traversal rule tương ứng.
- Thêm/xóa POI, compound, isolated loot point.
- Freehand brush tạo highway/secondary/dirt road, river hoặc forest; `SIZE` chỉnh độ rộng normalized trước khi vẽ.
- House Rectangle kéo từ góc này sang góc kia để tạo building; inspector chỉnh cover, loot multiplier và loot slots.
- Có thể chọn/xóa road, terrain stroke, building trong Master List; save override vào `user://map_overrides`; reset về descriptor mặc định.
- Transport node được hiển thị và runtime dùng nhưng chưa có editor riêng; muốn thay đổi node hiện phải sửa JSON/override data.

### Analyst Map

- Team Analysis có `ANALYST MAP • READ ONLY`, load descriptor của map sắp thi đấu và hiển thị toàn bộ layer thiết kế.
- Không bật editor gesture và không ghi override; chức năng này chỉ để đọc/phân tích.
- Nếu LAB đã save override cho map đó, Analyst Map đọc override ở lần load tiếp theo.

## 13. Liên kết với gameplay ngoài match

- Tournament/Calendar cung cấp event, map, team count và scoring.
- Tactics cung cấp coach plan được dùng trực tiếp trong deployment, movement, contact và combat.
- Roster/player development cung cấp attributes cho runtime.
- Training lưu `recent_training_impact`, nhưng runtime hiện đọc attribute đã cập nhật; chưa có overlay “recent training bonus” tách riêng trong công thức match.
- Career result commit cập nhật lịch sử/kết quả và các hệ thống downstream qua GameState.
- Replay/analytics dùng result telemetry và timeline.
- Developer/Custom Rules cung cấp simulation overrides.
- Map Manager override ảnh hưởng các match khởi tạo sau khi save; không thay descriptor của match đang chạy.

## 14. Giới hạn đã xác nhận

- Không có interior navigation, door/window interaction, vật lý projectile hay line-of-sight theo từng building; rectangle building là vùng 2D có loot và cover, không phải level geometry 3D.
- `cover_rating` của building rectangle đã giảm hit chance khi target đứng trong rect. `building_types` của compound chưa tạo geometry/LOS riêng.
- Road tác động tốc độ xe, nhưng AI pathfinding chưa tìm shortest path theo graph; player vẫn move-toward target thẳng và nhận road bonus khi ở gần polyline.
- Vehicle node/road kiểm soát acquisition, nhưng spawn chưa bị consume; nhiều player có thể roll cùng nguồn ở các thời điểm khác nhau.
- Flash chưa có debuff; Smoke chưa block contact formula; airdrop chỉ cấp trực tiếp cho player team mình đủ gần.
- Player loot hiện là quyết định AI theo role/loadout, chưa có màn tương tác để người dùng bấm chọn từng item giữa live match.
- Weather, day/night, destructible cover, boat, train, plane crash, recoil pattern và per-ammo caliber chưa có implementation được xác nhận.
- LAB chưa có timeline scrub/replay seek; nó quan sát simulation live và tăng tốc.

## 15. Kiểm thử liên quan

- `tests/map_structure_test.gd`: schema v2, map vuông, POI→compound, ba cấp đường, safe isolated loot, transport, size scaling và runtime loot stock.
- `tests/match_determinism_test.gd`: deterministic result theo seed.
- `tests/game_systems_test.gd`: gameplay và career systems.
- `tests/state_integrity_test.gd`: tính toàn vẹn state.
- `tests/redesign_systems_test.gd`: sáu map load/validate trong regression rộng.
- `tests/map_editor_combat_test.gd`: schema layer tùy chỉnh, river/forest/building/road, ammo UI, range falloff, virtual HP armor, distance kill feed và loot preference.
- `tests/map_lab_ui_test.gd`: Map Manager + Analyst Map ở 1280×720 và 1920×1080, bao gồm tạo road/river/forest/building bằng editor events.
