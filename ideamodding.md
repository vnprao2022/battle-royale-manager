# Battle Royale Manager — Ý tưởng Modding & Custom Content

> Trạng thái: tài liệu ý tưởng và thiết kế sản phẩm, **chưa triển khai code**.

## 1. Tầm nhìn

Battle Royale Manager nên phát triển thành hai sản phẩm bổ trợ nhau:

1. Một game mô phỏng quản lý esports có database chính thức.
2. Một nền tảng dữ liệu cộng đồng, nơi người chơi tạo, đóng gói, chia sẻ và kích hoạt nội dung tùy chỉnh an toàn.

Nguyên tắc cốt lõi:

- Steam quản lý danh tính người dùng; game không cần hệ thống đăng ký/đăng nhập riêng.
- Nội dung cộng đồng là **data + asset**, tuyệt đối không chứa hoặc thực thi code tùy ý.
- Package được import vào vùng cách ly, validate, xem trước rồi mới enable; không ghi trực tiếp vào database chính thức hoặc save đang chơi.
- Official Content, Community Content, Career Save và Dev/QA là bốn phạm vi tách biệt.
- Career phải ghi lại chính xác phiên bản và danh sách package đang dùng để có thể tái tạo dữ liệu.

## 2. Phạm vi Custom Content

Người chơi có thể tạo hoặc nhập:

```text
CUSTOM CONTENT
├── Teams
├── Players
├── Organizations
├── Tournaments
├── Leagues
├── Maps
├── Rulesets
├── Logos
├── Player Images
├── Team Banners
└── Full Database / Mod Pack
```

Các hành động được phép:

- Import package.
- Export package.
- Create và Edit nội dung do người chơi sở hữu.
- Duplicate nội dung thành bản mới.
- Delete package nếu không có career phụ thuộc, hoặc đưa vào trạng thái Disabled nếu đang được tham chiếu.
- Enable/Disable package cho career mới.
- Chia sẻ file trực tiếp; về sau có thể publish lên Steam Workshop.

## 3. Tách Player Tools khỏi Dev Tools

`Player Custom Content ≠ Dev Tools`.

### Player Custom Content

Người chơi được truy cập:

- Content Library.
- Import/Export.
- Team, Player, Organization Editor.
- Tournament, League và Ruleset Editor.
- Map metadata editor ở mức được kiểm soát.
- Asset uploader và preview.
- Dependency/conflict manager.

### Dev/QA Lab

Chỉ xuất hiện trong build/branch nội bộ:

- Force Match Result.
- AI Debugger.
- Zone Simulator.
- Database Inspector.
- Spawn Entity.
- Time Control.
- Match Lab và công cụ profiling/testing.

Không chỉ ẩn Dev Lab bằng một nút UI. Production export phải loại trừ scene, script, menu và cờ truy cập của công cụ nội bộ.

## 4. Mô hình danh tính và dữ liệu

```text
STEAM ACCOUNT
      │
      ▼
   SteamID
      │
      ▼
PLAYER PROFILE
├── Settings
├── Career Saves
├── Official Content (read-only)
└── Community Content
    ├── Imported
    ├── Created
    ├── Enabled
    └── Workshop Subscriptions (tương lai)
```

SteamID chỉ dùng làm định danh profile, quyền sở hữu và đồng bộ. Không nên ghi SteamID công khai vào package được export.

Ba kho dữ liệu logic:

| Kho | Quyền | Mục đích |
|---|---|---|
| Official Database | Chỉ đọc | Nội dung gốc đi kèm game |
| Content Library | Đọc/ghi có kiểm soát | Package đã import/tạo, metadata, asset và index |
| Career Snapshot | Bất biến theo career | Danh sách package, phiên bản và dữ liệu đã resolve khi bắt đầu career |

## 5. Content Package System

Luồng chuẩn:

```text
Select .brm
    ↓
Read archive trong sandbox
    ↓
Manifest validation
    ↓
Schema + asset + security validation
    ↓
Dependency/conflict resolution
    ↓
Preview + báo cáo thay đổi
    ↓
User Confirm
    ↓
Install vào Content Library bằng transaction
    ↓
Disabled mặc định hoặc Enable theo lựa chọn
    ↓
Game tạo resolved content view
```

Import thất bại phải rollback toàn bộ. Không để lại database record, asset mồ côi hoặc package ở trạng thái nửa cài đặt.

## 6. Định dạng `.brm`

`.brm` là archive có cấu trúc cố định, không phải executable:

```text
LCK_2026.brm
├── manifest.json
├── teams.json
├── players.json
├── organizations.json
├── tournaments.json
├── leagues.json
├── rulesets.json
├── maps.json
├── assets/
│   ├── teams/
│   ├── players/
│   ├── logos/
│   ├── banners/
│   └── maps/
├── localization/
│   ├── en.json
│   └── vi.json
└── thumbnail.png
```

Không bắt buộc package phải có mọi file. Manifest khai báo rõ module nào tồn tại.

### Manifest đề xuất

```json
{
  "format_version": 1,
  "package_id": "community.lck.2026",
  "name": "LCK 2026",
  "version": "1.0.0",
  "author": "Community Author",
  "description": "Custom 2026 league database",
  "game_version": ">=1.0.0",
  "content": {
    "teams": 10,
    "players": 90,
    "tournaments": 1,
    "leagues": 1
  },
  "dependencies": [],
  "load_after": [],
  "conflicts": [],
  "languages": ["en", "vi"],
  "checksums": {},
  "license": "Custom",
  "created_at": "2026-01-01T00:00:00Z"
}
```

`package_id` phải ổn định và duy nhất; tên hiển thị có thể thay đổi. `version` dùng semantic versioning. `checksums` giúp phát hiện file hỏng hoặc bị sửa sau khi đóng gói.

## 7. ID và quan hệ dữ liệu

Mỗi entity dùng ID có namespace:

```text
community.lck.2026:team:t1
community.lck.2026:player:faker
community.lck.2026:league:lck
```

Quy tắc:

- Không dùng array index, tên hiển thị hoặc tên file làm khóa chính.
- Roster tham chiếu player/team bằng ID.
- Tournament tham chiếu league, team và ruleset bằng ID.
- Asset tham chiếu qua đường dẫn tương đối trong package.
- Official ID không được bị overwrite trực tiếp.
- Package mở rộng official content phải dùng cơ chế patch/override được khai báo rõ, có preview và thứ tự ưu tiên.

## 8. Enable, load order và conflict

Import chỉ đưa package vào library; **Enable** mới đưa package vào content view của game.

Thứ tự resolve đề xuất:

1. Official base content.
2. Official updates/DLC.
3. Community dependencies.
4. Community packages theo load order.
5. User-created local override.

Các loại conflict:

- Trùng `package_id` và cùng version: hỏi Replace hoặc Cancel.
- Cùng `package_id`, version mới hơn: hiển thị Upgrade và migration impact.
- Hai package cùng override một entity: báo conflict, cho chọn priority.
- Thiếu dependency: không cho enable.
- Dependency sai version: đề nghị update/downgrade phù hợp.
- Circular dependency: từ chối enable.

Game cần màn hình `Resolved Changes`: Added, Modified, Replaced, Missing và Conflicted trước khi xác nhận.

## 9. Quan hệ với Career Save

Khi tạo career, game lưu một `Content Lock`:

- Package ID và version.
- Checksum.
- Load order.
- Danh sách entity đã resolve.
- Game/database schema version.

Career đang chạy không tự động nhận update package. Người chơi có thể:

- Tiếp tục với snapshot hiện tại.
- Clone career rồi thử migrate.
- Chấp nhận update sau khi xem báo cáo thay đổi.

Nếu thiếu package, game không được âm thầm thay dữ liệu. Phải hiển thị package bị thiếu và các lựa chọn Restore, Locate File hoặc mở career ở chế độ recovery nếu có thể.

Xóa package đang được career tham chiếu phải có cảnh báo. Lựa chọn an toàn mặc định là Disable/Archive, không hard-delete.

## 10. Validation và bảo mật

Validator phải chạy trước khi ghi bất kỳ dữ liệu nào vào Content Library.

### Archive security

- Chặn path traversal như `../` và đường dẫn tuyệt đối.
- Chặn symlink, executable, DLL, script và file không có trong allowlist.
- Giới hạn tổng dung lượng nén/giải nén, số file, độ sâu folder và compression ratio để chống zip bomb.
- Đọc file trong sandbox staging.
- Verify checksum trước khi install.
- Chuẩn hóa tên file và chống tên trùng không phân biệt hoa/thường trên Windows.

### JSON/data validation

- Parse theo schema và `format_version`.
- Kiểm tra kiểu, field bắt buộc, range, enum và độ dài chuỗi.
- ID phải duy nhất; mọi reference phải tồn tại.
- Roster size, tournament participant count và ruleset phải hợp lệ.
- Chặn NaN, infinity, số âm vô lý và dữ liệu vượt giới hạn gameplay.
- Unknown field được cảnh báo hoặc giữ lại theo chính sách versioning, không được làm game crash.

### Asset validation

| Asset | Định dạng | Kích thước đề xuất | Giới hạn dung lượng |
|---|---|---:|---:|
| Logo | PNG, JPG, WEBP | Tối đa 512×512 | 2 MB |
| Player portrait | PNG, JPG, WEBP | Tối đa 1024×1024 | 5 MB |
| Team banner | PNG, JPG, WEBP | Tối đa 2048×1024 | 8 MB |
| Thumbnail | PNG, JPG, WEBP | 640×360 đề xuất | 2 MB |
| Map preview | PNG, JPG, WEBP | Tối đa 4096×4096 | 16 MB |

Game nên decode ảnh để xác nhận định dạng thật, không tin phần mở rộng. Ảnh quá lớn có thể được đề nghị resize khi người chơi tạo package; package import từ bên ngoài phải bị từ chối nếu vượt hard limit.

### Nội dung bị cấm

- `.exe`, `.dll`, `.bat`, `.cmd`, `.ps1`, `.sh`.
- GDScript, C#, native plugin hoặc shader tùy ý.
- Macro, embedded object và payload có thể thực thi.
- URL tự động tải nội dung khi game chạy.
- Đường dẫn đọc file ngoài package.

## 11. Trình tạo nội dung trong game

### Content Library

Mỗi package card hiển thị:

- Thumbnail, tên, tác giả, version.
- Installed/Enabled/Disabled/Broken/Update Available.
- Số team, player, league, tournament và map.
- Dependencies, conflict và career đang sử dụng.
- Các action: Enable, Disable, Edit, Duplicate, Export, Delete.

Package import từ người khác mặc định read-only. `Edit` nên tạo một fork/duplicate mới để không phá checksum và khả năng cập nhật bản gốc.

### Editor flow

```text
Create Package
  → Package Info
  → Create/Import Entities
  → Link Rosters & Competitions
  → Add Assets
  → Validate
  → Preview
  → Save Draft
  → Export .brm
```

Nên có autosave draft, undo/redo, bulk CSV import ở phiên bản sau và validation chạy trực tiếp theo từng field.

### Trạng thái UI bắt buộc

- Empty state có hướng dẫn.
- Import progress và Cancel an toàn.
- Validation report theo Error/Warning/Info.
- Conflict resolver.
- Delete confirmation nêu rõ career bị ảnh hưởng.
- Broken package recovery.
- Toast/log cho import, export và update.

## 12. Mod Pack

Mod Pack có hai kiểu:

1. **Bundle:** chứa trực tiếp nhiều module/entity trong một `.brm`.
2. **Collection:** manifest chỉ liệt kê dependency tới nhiều package độc lập.

Ví dụ:

```text
BRM Community Pack
├── V.League PUBG 2026
├── LCK 2026
├── PUBG Global Series
├── SEA Custom League
└── My Fantasy League
```

Collection phù hợp Steam Workshop vì mỗi package có thể update riêng. Bundle phù hợp chia sẻ offline và cài đặt một file. Export wizard cần nói rõ loại package để tránh người dùng vô tình sao chép asset có bản quyền.

## 13. Steam Workshop — giai đoạn mở rộng

Luồng tương lai:

```text
Create/Validate Package
        ↓
Workshop Publish Preview
        ↓
Title + Description + Tags + Visibility
        ↓
Upload package + thumbnail
        ↓
Subscribe / Auto-download
        ↓
Local validator chạy lại
        ↓
User Enable
```

Workshop không được bỏ qua validator. Subscription chỉ tải package; người chơi vẫn phải Enable hoặc chấp nhận enable khi tạo career mới.

Metadata Workshop nên có:

- Content type và region.
- Real World/Fantasy/Historical/What If.
- Supported game version.
- Languages.
- Dependencies.
- License/attribution.
- NSFW/rights-reporting policy nếu cần.

## 14. Các use case nổi bật

- Database mùa giải thật theo từng năm.
- Historical pack: Faker 2013, T1 2016, TheShy 2018, G2 2019.
- Fantasy league hoặc What If roster.
- Vietnam Esports League với 16 teams, 160 players, logo và ruleset riêng.
- Tournament quốc tế do cộng đồng thiết kế.
- Chọn team theo season/year với database lock chính xác.
- Chia sẻ career setup giữa bạn bè bằng cùng package ID/version.

## 15. Phiên bản và migration

Hai version độc lập:

- `format_version`: cấu trúc file `.brm`.
- `version`: phiên bản nội dung của package.

Game chỉ tự migrate những format cũ có migration chính thức. Không sửa file nguồn âm thầm; tạo bản migrated trong library và giữ package gốc để rollback.

Backward compatibility tối thiểu nên được công bố theo từng major game version. Package không tương thích phải hiển thị lý do cụ thể, không chỉ báo `Import failed`.

## 16. Quyền tác giả và chia sẻ

- Tác giả phải khai báo license và attribution.
- Export preview liệt kê asset bên thứ ba.
- Official logos/portraits không tự động được phép export lại.
- Package có nội dung thật cần disclaimer rằng game không xác nhận quyền sử dụng thương hiệu/hình ảnh.
- Cần Report/Unpublish flow khi tích hợp Workshop.
- Không đưa SteamID, đường dẫn máy cá nhân hoặc save data vào package.

## 17. Telemetry và quyền riêng tư

Nếu có telemetry, chỉ ghi các sự kiện kỹ thuật tối thiểu như import thành công/thất bại, loại lỗi validator và crash signature. Không upload nội dung package cá nhân, ảnh tùy chỉnh hoặc dữ liệu nhận dạng nếu chưa có đồng ý rõ ràng.

## 18. Lộ trình đề xuất

### Phase 1 — Nền tảng local

- Định nghĩa manifest/schema/ID namespace.
- Import `.brm` vào staging sandbox.
- Validator và transactional install.
- Content Library với Enable/Disable/Delete.
- Official và Community data isolation.
- Career Content Lock.

### Phase 2 — Creator tools

- Team/Player/Organization editor.
- Tournament/League/Ruleset editor.
- Asset import, crop và preview.
- Duplicate/fork và local export.
- Dependency/conflict manager.

### Phase 3 — Database mở rộng

- Full Database/Mod Pack.
- Map metadata editor.
- Localization package.
- Package migration và recovery.
- Bulk data workflow cho creator nâng cao.

### Phase 4 — Steam Workshop

- Publish/Subscribe/Update.
- Collection và dependency download.
- Rating, tag, report và moderation.
- Cloud synchronization cho manifest/subscription list.

## 19. Tiêu chí hoàn thành hệ thống

- Package không thể ghi trực tiếp vào Official Database.
- Không loại file nào trong package có thể thực thi code.
- Import lỗi rollback sạch và không làm hỏng library/save.
- Package lớn hoặc độc hại không thể gây zip bomb/path traversal.
- Dependency, conflict và load order có kết quả xác định.
- Career cũ vẫn mở đúng với Content Lock của nó.
- Update package không tự thay đổi career đang chơi.
- Export rồi import lại cho kết quả dữ liệu tương đương.
- Người chơi hiểu rõ package nào đang Enabled và ảnh hưởng career nào.
- Production build không chứa Dev/QA Lab.

## 20. Kết luận thiết kế

Kiến trúc phù hợp nhất là:

```text
SteamID
  └── Player Profile
      ├── Career Saves + Content Locks
      ├── Official Content (read-only)
      └── Community Content Library
          ├── Import / Export
          ├── Create / Duplicate / Edit
          ├── Validate / Resolve
          └── Enable / Share / Workshop

Dev/QA — separate build or branch
  ├── Match Lab
  ├── AI Lab
  ├── Map/Zone Lab
  ├── Database Inspector
  └── Internal Debug Tools
```

Điểm khác biệt của Battle Royale Manager không chỉ là cho phép đổi logo hay tên đội. Giá trị lớn nhất là một hệ sinh thái database theo mùa giải, lịch sử, fantasy và giải đấu cộng đồng, nhưng vẫn bảo vệ save, database chính thức và máy người chơi bằng một package pipeline an toàn, có version và có thể tái tạo.
