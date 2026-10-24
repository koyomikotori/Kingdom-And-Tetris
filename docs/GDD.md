# Kingdom And Tetris — GDD v0.2

Tên tạm của dự án. Tài liệu này ghi lại các quyết định đã chốt; mục "Câu hỏi mở" là những thứ chưa quyết.

## 1. Tóm tắt

Game chiến thuật xây dựng vương quốc theo lượt, 2D pixel art, chơi đơn, Windows PC, Godot 4.5 + GDScript.

Người chơi đặt các mảnh đất (polyomino kiểu Tetris) để mở rộng lãnh thổ. Hình dạng và cách sắp xếp lãnh thổ quyết định sản lượng tài nguyên và loại quân có thể tuyển. Định kỳ địch tấn công, trận đánh diễn ra tự động trên chiến trường nhìn ngang.

## 2. Vòng lặp một lượt

1. Nhận mảnh đất (mặc định 3 mảnh/lượt, sẽ cân chỉnh).
2. Đặt / xoay mảnh để mở rộng hoặc cải tạo lãnh thổ.
3. Thu tài nguyên theo địa hình + quy tắc kề nhau.
4. Xây công trình, tuyển quân.
5. Xử lý sự kiện (nếu có).
6. Đến lượt có đợt địch → auto-battle.

Bản đầu **không có bản đồ chiến dịch**: thay bằng các đợt địch theo mốc lượt (ví dụ lượt 5, 10, 15…). Bản đồ chiến dịch thêm sau khi vòng lặp chính đã vui.

## 3. Bản đồ

| Thông số | Giá trị |
|---|---|
| Kích thước lưới | 12×12 (cấu hình được, có thể lên 15×15) |
| Kích thước ô | 32×32 px |
| Camera | Lăn chuột để zoom, kéo chuột phải/giữa để di chuyển |
| Thành chính | 2×2, đặt giữa bản đồ |
| Lãnh thổ khởi đầu | Vùng 4×4 cỏ quanh thành |
| Hệ tọa độ | `Vector2i(x, y)`, x sang phải, y xuống dưới, (0,0) là góc trên trái |

Mỗi ô lưu riêng: **địa hình**, **quyền sở hữu**, **công trình**, **ô quan trọng** (sẽ thêm ở M2). Không gộp vào một biến `type`.

Ô chưa sở hữu là đất hoang, chưa có địa hình. Địa hình chỉ xuất hiện khi người chơi đặt mảnh đất lên.

### Địa hình v0.1

| Địa hình | Tài nguyên chính |
|---|---|
| Cỏ | — (đất trống để xây) |
| Ruộng | Lương thực |
| Rừng | Gỗ |
| Đồi đá | Đá (sau này: quặng) |

("Mỏ" là công trình đặt trên đồi đá, không phải địa hình.)

## 4. Cơ chế đặt đất

- Mảnh đất là một nhóm ô có hình dạng (đơn, thanh, chữ L, vuông…), mỗi ô trong mảnh có địa hình riêng.
- Xoay 4 hướng × 90°. (Lật mảnh: câu hỏi mở.)
- **Kết nối:** mảnh phải chạm cạnh (không tính chéo) với lãnh thổ hiện có, hoặc đè lên lãnh thổ hiện có.
- **Đè / thay thế:** mảnh mới được phép đặt đè lên đất đã đặt trước đó; địa hình cũ bị thay bằng địa hình mới. Đây là cách cải tạo lãnh thổ.
  - Không được đè lên thành chính.
  - Ô đang có công trình: v0.1 **không cho đè** (xem câu hỏi mở).
- **Ô quan trọng:** một số ô trong mảnh mang đặc tính đặc biệt (đất màu mỡ, rừng cổ, mạch quặng…). Chúng cho sản lượng cao hơn hoặc mở khóa công trình/đơn vị. Đè lên ô quan trọng thì mất nó, nên người chơi phải cân nhắc.
- Đặt không hợp lệ thì không được thay đổi bản đồ và không tiêu thụ mảnh.
- Chống kẹt: cho đổi một mảnh (có phí nhỏ) nếu không còn chỗ đặt.

## 5. Quy tắc kề nhau (lõi câu đố)

Kề nhau = chung cạnh (4 hướng). Các con số chỉ để thử, sẽ cân chỉnh sau M3.

1. **Ruộng theo cụm:** mỗi ruộng +1 lương thực; nếu nằm trong cụm ≥3 ruộng liền nhau thì mỗi ô +1 nữa.
2. **Trại gỗ:** +1 gỗ cho mỗi ô rừng kề bên.
3. **Mỏ:** đặt trên đồi đá, +1 đá cho mỗi đồi đá kề bên.
4. **Ô quan trọng:** sản lượng ×2 trên ô đó, hoặc là điều kiện của công trình đặc biệt.
5. **Ồn ào:** mỏ kề nhà dân / thành thì giảm sản lượng của ô bị kề (tạo áp lực phải quy hoạch).

## 6. Liên kết bản đồ ↔ chiến trường

Bản đồ ảnh hưởng chiến đấu trực tiếp chứ không chỉ qua tài nguyên:

- Có rừng (đủ số lượng) → mở khóa cung thủ.
- Có đồng cỏ lớn liền mạch → mở khóa kỵ binh.
- Có đồi đá + mỏ → mở khóa lính khiên, sau này là quân trang bị nặng.
- Tướng có thể nhận buff theo địa hình lãnh thổ.

## 7. Chiến đấu — kiểu Ninja Village (Kairosoft)

- Màn hình nhìn ngang, quân ta bên trái, địch bên phải, mỗi bên có căn cứ/cổng thành.
- Quân tự tiến lên, gặp địch trong tầm thì dừng lại đánh; cung thủ đứng sau bắn.
- Thắng khi phá căn cứ địch hoặc hạ hết quân địch.
- Người chơi chỉ chuẩn bị trước trận: chọn quân, thứ tự xuất quân, tướng.

**Kỹ thuật:** `BattleSimulator` chạy theo tick cố định (ví dụ 10 tick/giây), dùng RNG có seed và xuất ra **danh sách sự kiện** (di chuyển, tấn công, trúng đòn, ngã xuống…). `BattlePresenter` chỉ phát lại danh sách đó bằng hoạt ảnh. Cùng seed + cùng đội hình = cùng kết quả, nên có thể kiểm thử headless.

## 8. Kinh tế & quân đội (giữ nguyên ý từ v0.1, rút gọn phạm vi)

- Prototype: 3 tài nguyên (lương thực, gỗ, đá). Quặng và vàng thêm khi có quân cao cấp / tướng.
- Quân ban đầu: kiếm sĩ, cung thủ, thương binh. Sau đó: lính khiên, kỵ binh, lính súng.
- Tướng: 1 tướng võ + 1 quân sư mẫu.
- Tất cả chỉ số nằm trong file dữ liệu (`Resource`), không viết cứng trong code.

## 9. Quyết định kỹ thuật

| Vấn đề | Quyết định |
|---|---|
| Dữ liệu tĩnh (địa hình, mảnh, đơn vị, công trình) | `Resource` (`.tres`) trong `data/`, nạp theo thư mục |
| Trạng thái ván chơi | Lớp `RefCounted` thuần logic (`BoardData`, …), không phụ thuộc Node |
| Hiển thị | Node riêng (`BoardView`, …) chỉ đọc dữ liệu, không tự sửa |
| Lưu game | JSON có trường `save_version`; **không** dùng `ResourceSaver`/`.tres` cho file save |
| Kiểm thử | Script headless tự viết trong `tests/`, không dùng thư viện ngoài |
| Tên lớp | Tránh trùng lớp có sẵn của Godot (ví dụ dùng `CellData`, không dùng `TileData`) |

## 10. Lộ trình

| Mốc | Nội dung | Trạng thái |
|---|---|---|
| M1 | Lưới 12×12, thành 2×2, zoom/pan, xem thông tin ô | Đang làm |
| M2 | Mảnh đất, xoay, xem trước, kết nối, đè thay thế, ô quan trọng | |
| ⏸ | **Chơi thử: xếp đất có vui không? Chỉnh trước khi đi tiếp** | |
| M3 | Tài nguyên, quy tắc kề nhau, công trình, kết thúc lượt | |
| M4 | Dữ liệu đơn vị, doanh trại, tuyển quân, mở khóa theo địa hình | |
| M5 | Auto-battle kiểu Ninja Village + đợt địch theo lượt | |
| M6 | Sự kiện, tướng, điều kiện thắng/thua | |
| M7 | Lưu/tải, thêm nội dung | |
| M8 | Pixel art, âm thanh, cân bằng, build Windows | |

## 11. Câu hỏi mở

- Có cho lật (mirror) mảnh chữ L/S không?
- Đè lên ô có công trình: cấm hẳn, hay cho phép phá công trình và hoàn lại một phần tài nguyên?
- Số mảnh mỗi lượt và tỉ lệ xuất hiện ô quan trọng.
- Bản đồ cố định 12×12, hay mở rộng biên khi nâng cấp thành?
- Bộ asset pixel art sẽ dùng (Kenney, itch.io…).
