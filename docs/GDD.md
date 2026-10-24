# Kingdom And Tetris — GDD v0.2

Tên tạm của dự án. Tài liệu này ghi lại các quyết định đã chốt; mục "Câu hỏi mở" là những thứ chưa quyết.

## 1. Tóm tắt

Game chiến thuật xây dựng vương quốc theo lượt, 2D pixel art, chơi đơn, Windows PC, Godot 4.5 + GDScript.

Người chơi đặt các mảnh đất (polyomino kiểu Tetris) để mở rộng lãnh thổ. Hình dạng và cách sắp xếp lãnh thổ quyết định sản lượng tài nguyên và loại quân có thể tuyển. Định kỳ địch tấn công, trận đánh diễn ra tự động trên chiến trường nhìn ngang.

## 2. Vòng lặp một lượt

1. Nhận 3 mảnh đất.
2. Đặt mảnh để mở rộng hoặc cải tạo lãnh thổ.
3. Xây công trình, tuyển quân, ngoại giao (từ M6).
4. Kết thúc lượt: thu tài nguyên theo địa hình, trả tiền nuôi quân.
5. Nếu có cướp / quân xâm lược đến, hoặc mình đi đánh → auto-battle (§7).
6. Xử lý sự kiện (nếu có).

Không còn "đợt địch theo mốc lượt cố định": địch đến từ cướp ngẫu nhiên và từ các gia tộc láng giềng (§7, §9).

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

### 7.1 Ba loại xung đột

| Loại | Xuất hiện khi | Thua thì | Thắng thì (đề xuất) |
|---|---|---|---|
| **Cướp** | Ngẫu nhiên mỗi lượt, hoặc do sự kiện | Mất một phần tài nguyên | Thu một ít chiến lợi phẩm |
| **Quân xâm lược** | Gia tộc láng giềng có quan hệ xấu tấn công | Mất đất ở phía biên giáp kẻ địch | Quan hệ / uy tín thay đổi, có thể đòi bồi thường |
| **Đi xâm lược** | Người chơi đem quân đánh vùng xung quanh | Mất **toàn bộ** quân + bồi thường tài nguyên | Chiếm vùng / tài nguyên |

**Toàn bộ quân tham chiến** trong mọi trận.

### 7.2 Cướp

- Từ lượt 6, mỗi lượt có **15%** khả năng cướp xuất hiện.
- **Không báo trước:** cướp đến ngay đầu lượt, trận đánh diễn ra luôn.
- Quân cướp đông dần theo số lượt (cấu hình trong `data/raids/bandits.tres`).
- **Thua:** mất 30% mỗi loại tài nguyên, và lính còn sống mất thêm 30% mỗi loại (tháo chạy). Lính chết trong trận thì vẫn mất như thường.
- **Thắng:** nhận một ít tài nguyên theo số cướp bị đánh bại. Sau này: kinh nghiệm cho tướng, mưu sĩ, lính.
- **Trạm lính canh:** mỗi trạm giảm 4% tỉ lệ cướp, tối đa 3 trạm, tốn phí duy trì mỗi lượt. Nếu không trả đủ phí duy trì thì lượt đó trạm không có tác dụng. Sau này có thể thêm tác dụng khác.

### 7.3 Quân xâm lược & mất đất

Bản đồ vương quốc có 4 cạnh tương ứng 4 hướng trên bản đồ thế giới. Thua trước quân xâm lược đến từ hướng nào thì mất các ô lãnh thổ sát cạnh đó: ô trở lại đất hoang, công trình trên đó bị phá. Thành chính không bao giờ mất. Cần có bản đồ thế giới (§9) để biết hướng.

### 7.4 Trận đánh theo pha (bản M5, sẽ thay bằng §7.6)

Mỗi loại lính có **hàng** (trước / giữa / sau) và **kiểu đánh** (cận chiến / cung / súng). Quân tính theo **số lượng**, không tính từng con.

1. **Súng** (nếu có): hai phe nổ súng cùng lúc, sát thương vào **hàng đầu** của đối phương.
2. **Cung**: tên bắn vòng lên rồi rơi xuống, sát thương **chia đều cho cả 3 hàng** của đối phương (dàn trải nên yếu hơn mỗi hàng).
3. **Xung phong**: bộ binh (sau này cả tướng, kỵ binh) lao vào nhau giữa chiến trường. Mỗi hiệp, toàn bộ lính cận chiến đánh vào hàng đầu còn sống của đối phương; cung thủ vẫn bắn yểm trợ với 50% sức.
4. Sau mỗi bước: phe nào chết hết, hoặc **còn dưới 40% quân** ban đầu thì tan vỡ và thua. Hết 8 hiệp mà chưa phân thắng bại thì phe còn tỉ lệ quân cao hơn thắng (bằng nhau thì phe phòng thủ thắng).

Sát thương của một nhóm = số lính còn sống × max(1, công − thủ của mục tiêu) × hệ số pha × ngẫu nhiên ±10%. Hai phe ra đòn cùng lúc trong mỗi bước.

Không có quân thì thua ngay.

### 7.5 Hiển thị (M6)

Màn hình ngang, chia theo bề ngang:

| 5% | 20% | 50% | 20% | 5% |
|---|---|---|---|---|
| Thông tin phe 1 (số quân còn lại) | Xạ thủ phe 1 | Chiến trường cận chiến | Xạ thủ phe 2 | Thông tin phe 2 |

- Súng: loạt đạn li ti bay vụt qua chiến trường.
- Cung: tên bay lên khỏi khung hình, rồi rơi xuống từ phía trên.
- Xung phong: bộ binh + tướng (cưỡi ngựa) lao vào, va chạm ở giữa.
- Mỗi hình lính đại diện cho một nhóm lính; khi thiệt hại đủ số lượng thì hình bị thổi bay ra phía sau, ra khỏi khung hình.
- Nút điều khiển: **tạm dừng**, **tăng tốc**, **rút lui** (§7.6).
- Kết thúc: bảng thống kê thiệt hại của cả 2 phe và sát thương gây ra theo loại lính (đã có từ M5).

### 7.6 Chiến đấu v2 — chỉ số lính, sĩ khí, rút lui (đã chốt)

**Chỉ số của một đơn vị lính:**

| Chỉ số | Ý nghĩa |
|---|---|
| **HP / Number** | Số lính còn lại của đơn vị. Bị đánh thì số lính giảm. |
| **Melee Attack** | Sát thương khi đánh gần. |
| **Melee Defense** | Giảm sát thương nhận từ đánh gần. |
| **Armor** | Giảm sát thương nhận từ đạn và tên. |
| **Charge Attack** | Sát thương cộng thêm, chỉ ở **lần lao vào giao tranh đầu tiên**; sau đó không còn tác dụng. |
| **Morale** (sĩ khí) | Giảm khi tướng chết, và khi số lính giảm xuống dưới các mốc nhất định. Về 0 thì cả đơn vị **bị loại khỏi trận như bị tiêu diệt hoàn toàn**, dù vẫn còn lính. |
| **Range Attack** | Sát thương đánh xa. Chỉ đơn vị dùng súng hoặc cung mới có. |

**Đánh xa:**
- **Súng:** nã một loạt đạn duy nhất ở đầu trận, sau đó không tham gia trận đánh nữa.
- **Cung:** bắn nhiều loạt tên, cách nhau một khoảng thời gian. Cung càng tốt thì bắn càng nhanh (chỉ số thời gian nạp tên).

**Rút lui:** trong trận có nút **Rút lui**, dùng được bất cứ lúc nào. Rút lui thì trận đó tính là **thua**, nhưng toàn bộ quân chỉ thiệt hại **50%** thay vì bị đánh tan. Dùng khi tiền tuyến đã vỡ và muốn giữ lại hậu tuyến (súng, cung).

**Hệ quả kỹ thuật:** vì có rút lui giữa trận và cung bắn theo thời gian, trận đánh chuyển sang mô phỏng **theo thời gian** (tick), có thể chạy từng bước. Màn hình trận đánh điều khiển bộ mô phỏng: tạm dừng thì ngừng gọi, tăng tốc thì chạy nhiều tick mỗi khung hình, rút lui thì kết thúc ngay. Bộ mô phỏng vẫn thuần logic, có seed và test headless được (test có thể giả lập "rút lui ở giây thứ X").

**Đơn vị (squad):** mỗi lần tuyển được **một đơn vị gồm nhiều lính** (ví dụ kiếm sĩ: 20 lính). Trên màn hình trận đánh, mỗi đơn vị chỉ vẽ vài hình đại diện (ví dụ 5 hình cho 20 lính) để tránh lag, giống Ninja Village. Mỗi đơn vị là một quân riêng, có số lính và sĩ khí riêng (sau này: kinh nghiệm riêng). Giá tuyển và phí nuôi tính theo đơn vị.

**Quản lý đơn vị:**
- **Bổ sung quân:** cuối mỗi lượt, đơn vị thiếu quân tự hồi 25% quân số chuẩn (làm tròn lên, không vượt chuẩn), **miễn phí** (đã tốn lương thực nuôi quân). Cần có ít nhất 1 doanh trại.
- **Giới hạn số đơn vị:** thành chính cho 2, mỗi doanh trại thêm 4; tối đa 3 doanh trại (tổng 14). Sau này: nâng cấp / mở rộng thành để tăng giới hạn và mở rộng ra đất hoang mới.
- **Giải tán:** người chơi có thể giải tán một đơn vị (ví dụ còn quá ít quân, hoặc muốn thay bằng loại tốt hơn). Không hoàn tài nguyên.
- Không có gộp đơn vị.

**Sĩ khí:** mỗi loại lính có mức sĩ khí riêng; lính càng tốt sĩ khí càng cao (như Shogun 2). Sĩ khí giảm mỗi khi đơn vị mất thêm 25% quân, và khi tướng chết (khi có tướng). Về 0 thì đơn vị **vỡ**.

**Kết thúc trận:** phe có toàn bộ đơn vị bị vỡ hoặc chết hết thì thua. Hết giờ thì phe còn tỉ lệ quân cao hơn thắng (bằng nhau thì phe phòng thủ thắng).

**Thiệt hại khi thua** (cả thua thường lẫn rút lui):
- Đơn vị **đã vỡ** (hết quân hoặc hết sĩ khí): **mất sạch**.
- Đơn vị **chưa vỡ** (rút lui, hoặc khi hết giờ): **giữ 50%** số lính còn lại.
- Tài nguyên vẫn bị mất như thua bình thường (cướp: 30%).
- Phe thắng: đơn vị bị vỡ vẫn giữ số lính sống sót (họ quay về sau trận).

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
| Trạm lính canh | 4 gỗ, 3 đá | Ô cỏ, tối đa 3 | −4% khả năng bị cướp mỗi trạm; duy trì 1 lương thực/lượt |

Công trình có thể có phí duy trì. Phí này được trả sau tiền nuôi quân; nếu không đủ thì lượt đó công trình tạm ngưng tác dụng.

### Quân lính (M4)

- Tuyển ở tab **Quân đội**. Mỗi lính tốn **1 lương thực mỗi lượt** để nuôi.
- Thanh tài nguyên hiển thị thu nhập ròng (sản lượng trừ nuôi quân).
- Cuối lượt: thu sản lượng trước, rồi trả tiền nuôi quân. Nếu không đủ lương thực, lính **bỏ đi** (nhóm đông nhất bỏ trước) cho đến khi đủ.

Mỗi lần tuyển được 1 đơn vị; giá và phí nuôi tính theo đơn vị.

| Lính | Số lính | Hàng / kiểu | Cận chiến | Phòng thủ | Giáp | Xung kích | Sĩ khí | Bắn xa / nạp | Giá | Điều kiện |
|---|---|---|---|---|---|---|---|---|---|---|
| Kiếm sĩ | 20 | Trước / cận chiến | 9 | 7 | 5 | 5 | 8 | — | 3 lương thực, 1 đá | Doanh trại |
| Thương binh | 20 | Giữa / cận chiến | 6 | 9 | 4 | 3 | 7 | — | 2 lương thực, 2 gỗ | Doanh trại |
| Cung thủ | 15 | Sau / cung | 3 | 2 | 2 | 1 | 5 | 6 / 5 giây | 2 lương thực, 3 gỗ | Doanh trại + ≥3 ô rừng |
| Cướp cầm dao | 16 | Trước / cận chiến | 6 | 3 | 1 | 4 | 4 | — | (địch) | |
| Cướp cung | 10 | Sau / cung | 2 | 1 | 0 | 0 | 3 | 4 / 6 giây | (địch) | |

Số đơn vị cướp = 1 + lượt × 0.15. Cân bằng hiện tại (mô phỏng 200 trận mỗi trường hợp): lượt 6 cần 1 đơn vị, lượt 12 khoảng 2, lượt 20–30 khoảng 4 đơn vị (2 kiếm sĩ + 1 thương binh + 1 cung thủ). Trận kéo dài khoảng 7–40 giây tùy chênh lệch lực lượng.

Sau này: lính khiên, kỵ binh, lính súng; tướng (1 tướng võ + 1 quân sư mẫu).

## 9. Bản đồ thế giới & ngoại giao

- Thêm tab/nút **Ngoại giao**. Bấm vào thì mở một màn hình bản đồ lớn: vương quốc của mình ở một vị trí, các gia tộc / vương quốc xung quanh hiển thị quanh đó.
- Với mỗi gia tộc: xem quan hệ, giao thương (trao đổi tài nguyên), kết liên minh, tuyên chiến.
- Quan hệ xấu thì gia tộc đó có thể gửi quân xâm lược (§7.3). Người chơi cũng có thể đem quân đánh họ.
- Mỗi gia tộc nằm ở một hướng so với vương quốc của mình, quyết định cạnh nào của bản đồ vương quốc bị mất đất khi thua.

**Thế giới làm sẵn** (đã chốt) (khoảng 5–6 gia tộc, mỗi gia tộc một file dữ liệu: tên, vị trí, tính cách, sức mạnh, quan hệ ban đầu). Lý do:
- Dễ cân bằng và dễ viết sự kiện / cốt truyện cho từng gia tộc.
- Ít việc hơn nhiều so với một bộ sinh bản đồ ngẫu nhiên (sông, biển, địa lý…).
- Vì gia tộc là dữ liệu, sau này vẫn có thể thêm chế độ sinh ngẫu nhiên ra các file đó mà không phải viết lại hệ thống.

Biển, sông: chưa làm, để sau.

## 10. Quyết định kỹ thuật

| Vấn đề | Quyết định |
|---|---|
| Dữ liệu tĩnh (địa hình, mảnh, đơn vị, công trình) | `Resource` (`.tres`) trong `data/`, nạp theo thư mục |
| Trạng thái ván chơi | Lớp `RefCounted` thuần logic (`BoardData`, …), không phụ thuộc Node |
| Hiển thị | Node riêng (`BoardView`, …) chỉ đọc dữ liệu, không tự sửa |
| Lưu game | JSON có trường `save_version`; **không** dùng `ResourceSaver`/`.tres` cho file save |
| Kiểm thử | Script headless tự viết trong `tests/`, không dùng thư viện ngoài |
| Tên lớp | Tránh trùng lớp có sẵn của Godot (ví dụ dùng `CellData`, không dùng `TileData`) |

## 11. Lộ trình

| Mốc | Nội dung | Trạng thái |
|---|---|---|
| M1 | Lưới 12×12, thành 2×2, zoom/pan, xem thông tin ô | Xong |
| M2 | Mảnh đất (hướng cố định), xem trước, kết nối, đè thay thế, ô quan trọng | Xong |
| ⏸ | **Chơi thử: xếp đất có vui không? Chỉnh trước khi đi tiếp** | Xong (ổn) |
| M3 | Sản lượng mỗi lượt, kết thúc lượt, nhận mảnh đầu lượt, ô ◆ ×2 | Xong |
| M4 | Công trình, dữ liệu đơn vị, doanh trại, tuyển quân, nuôi quân, mở khóa theo địa hình | Xong |
| M5 | Logic trận đánh theo pha + **cướp** (ngẫu nhiên, không báo trước) + trạm lính canh + bảng thống kê sau trận | Xong |
| M6 | **Chiến đấu v2** (logic): chỉ số mới, sĩ khí, charge, súng 1 loạt, cung theo thời gian nạp, mô phỏng theo tick, rút lui + **quản lý đơn vị** (bổ sung quân, giới hạn theo doanh trại, giải tán) | Đang làm |
| M7 | Màn hình trận đánh cinematic (5/20/50/20/5, hoạt ảnh, tạm dừng, tăng tốc, nút rút lui) | |
| M8 | Bản đồ thế giới làm sẵn + gia tộc + quan hệ + giao thương | |
| M9 | Quân xâm lược (mất đất theo hướng) + đi xâm lược + liên minh | |
| M10 | Lưu/tải (JSON có version) | |
| M11 | Sự kiện, tướng, mưu sĩ, kinh nghiệm, điều kiện thắng/thua | |
| M12 | Pixel art, âm thanh, cân bằng, build Windows | |

Lưu/tải được đưa lên trước sự kiện và tướng, vì trạng thái game càng nhiều thì càng khó thêm lưu game về sau.

## 12. Câu hỏi mở

- Đè lên ô có công trình (ngoài thành): cấm hẳn, hay cho phép phá công trình và hoàn lại một phần tài nguyên?
- Sau khi chơi thử: có nên cho người chơi xoay mảnh không?
- Số mảnh mỗi lượt và tỉ lệ xuất hiện ô quan trọng.
- Bản đồ cố định 12×12, hay mở rộng biên khi nâng cấp thành?
- Bộ asset pixel art sẽ dùng (Kenney, itch.io…).
