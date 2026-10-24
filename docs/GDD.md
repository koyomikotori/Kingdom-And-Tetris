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

- Mảnh đất là một nhóm ô có hình dạng, mỗi ô trong mảnh có địa hình riêng (ngẫu nhiên theo trọng số của địa hình).
- Hình dạng v0.1: ô đơn, thanh 2, thanh 3, vuông 2×2, **L trái** và **L phải** (hai hình khác nhau, là ảnh gương của nhau).
- **Người chơi không xoay được mảnh.** Thay vào đó, mỗi hướng xoay của một hình là một mảnh riêng có thể được rút ra: L trái có 4 hướng, L phải có 4 hướng, thanh có ngang/dọc, vuông và ô đơn chỉ có 1. Mỗi hình được chia đều trọng số cho các hướng của nó, để hình nhiều hướng không bị rút ra nhiều hơn. (Thử nghiệm, có thể đổi sang cho xoay sau.)
- **Kết nối:** mảnh phải chạm cạnh (không tính chéo) với lãnh thổ hiện có, hoặc đè lên lãnh thổ hiện có.
- **Đè / thay thế:** mảnh mới được đặt đè lên đất đã đặt trước đó. Ô bị đè **mất địa hình cũ** (và mất sản lượng của nó), lấy địa hình của mảnh mới. Đây là cách cải tạo lãnh thổ.
  - Không được đè lên thành chính.
  - Ô có công trình khác: v0.1 **không cho đè** (xem câu hỏi mở).
- **Ô quan trọng:** khoảng 20% số mảnh có một ô quan trọng (đánh dấu ◆). Đè lên ô quan trọng thì mất nó.
- Đặt không hợp lệ thì không được thay đổi bản đồ và không tiêu thụ mảnh.
- Mỗi lượt nhận 3 mảnh mới. Không bắt buộc đặt hết; mảnh chưa đặt **bị bỏ** khi kết thúc lượt.
- Vì được phép đè lên lãnh thổ của mình, gần như luôn có chỗ đặt, nên v0.1 chưa cần cơ chế đổi mảnh.

## 5. Sản lượng

Mỗi lượt, mỗi ô thuộc lãnh thổ cho sản lượng theo địa hình của nó:

| Địa hình | Sản lượng mỗi lượt |
|---|---|
| Cỏ | không có (đất trống để xây) |
| Ruộng | 1 lương thực |
| Rừng | 1 gỗ |
| Đồi đá | 1 đá |

Ví dụ: có 4 ô ruộng thì được 4 lương thực mỗi lượt. Đặt một ô rừng đè lên 1 trong 4 ô ruộng đó thì còn 3 lương thực + 1 gỗ mỗi lượt.

**Ô quan trọng ◆ cho sản lượng ×2** trên ô đó (ô cỏ ◆ vẫn không cho gì).

Tài nguyên được cộng vào kho khi bấm **Kết thúc lượt**, tính theo lãnh thổ lúc đó. Thanh trên cùng hiển thị kho và thu nhập mỗi lượt, ví dụ "Lương thực: 10 (+5)". Khi rê mảnh lên bản đồ, game cho biết thu nhập sẽ thay đổi thế nào nếu đặt ở đó.

Loại tài nguyên nằm trong `data/resources/`, sản lượng của địa hình nằm trong trường `yields` của file địa hình.

Các quy tắc kề nhau (cụm ruộng, trại gỗ cạnh rừng, mỏ cạnh đồi…) **tạm gác lại**; chỉ thử thêm nếu sau khi chơi thử thấy việc xếp đất còn thiếu chiều sâu.

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

## 8. Công trình & quân đội

- Prototype: 3 tài nguyên (lương thực, gỗ, đá). Quặng và vàng thêm khi có quân cao cấp / tướng.
- Tất cả chỉ số nằm trong file dữ liệu (`data/buildings/`, `data/units/`), không viết cứng trong code.

### Công trình (M4)

- Xây trong lãnh thổ, chọn ở tab **Xây dựng**, có bóng xem trước giống mảnh đất.
- Xây xong thì trừ tài nguyên. Không đủ tài nguyên hoặc chỗ không hợp lệ thì không xây và không trừ gì.
- Mảnh đất không được đè lên công trình.

| Công trình | Giá | Điều kiện | Tác dụng |
|---|---|---|---|
| Doanh trại | 6 gỗ, 2 đá | Ô cỏ, tối đa 1 | Cho phép tuyển quân |

### Quân lính (M4)

- Tuyển ở tab **Quân đội**. Mỗi lính tốn **1 lương thực mỗi lượt** để nuôi.
- Thanh tài nguyên hiển thị thu nhập ròng (sản lượng trừ nuôi quân).
- Cuối lượt: thu sản lượng trước, rồi trả tiền nuôi quân. Nếu không đủ lương thực, lính **bỏ đi** (nhóm đông nhất bỏ trước) cho đến khi đủ.

| Lính | Máu | Công | Thủ | Tầm | Giá | Điều kiện |
|---|---|---|---|---|---|---|
| Kiếm sĩ | 100 | 12 | 4 | 1 | 3 lương thực, 1 đá | Doanh trại |
| Thương binh | 90 | 10 | 3 | 1 | 2 lương thực, 2 gỗ | Doanh trại |
| Cung thủ | 60 | 9 | 1 | 5 | 2 lương thực, 3 gỗ | Doanh trại + ≥3 ô rừng |

Sau này: lính khiên, kỵ binh, lính súng; tướng (1 tướng võ + 1 quân sư mẫu).

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
| M1 | Lưới 12×12, thành 2×2, zoom/pan, xem thông tin ô | Xong |
| M2 | Mảnh đất (hướng cố định), xem trước, kết nối, đè thay thế, ô quan trọng | Xong |
| ⏸ | **Chơi thử: xếp đất có vui không? Chỉnh trước khi đi tiếp** | Xong (ổn) |
| M3 | Sản lượng mỗi lượt, kết thúc lượt, nhận mảnh đầu lượt, ô ◆ ×2 | Xong |
| M4 | Công trình, dữ liệu đơn vị, doanh trại, tuyển quân, nuôi quân, mở khóa theo địa hình | Đang làm |
| M5 | Auto-battle kiểu Ninja Village + đợt địch theo lượt | |
| M6 | Sự kiện, tướng, điều kiện thắng/thua | |
| M7 | Lưu/tải, thêm nội dung | |
| M8 | Pixel art, âm thanh, cân bằng, build Windows | |

## 11. Câu hỏi mở

- Đè lên ô có công trình (ngoài thành): cấm hẳn, hay cho phép phá công trình và hoàn lại một phần tài nguyên?
- Sau khi chơi thử: có nên cho người chơi xoay mảnh không?
- Số mảnh mỗi lượt và tỉ lệ xuất hiện ô quan trọng.
- Bản đồ cố định 12×12, hay mở rộng biên khi nâng cấp thành?
- Bộ asset pixel art sẽ dùng (Kenney, itch.io…).
