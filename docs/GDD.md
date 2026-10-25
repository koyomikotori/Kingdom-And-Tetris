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

| 10% | 18% | 44% | 18% | 10% |
|---|---|---|---|---|
| Thông tin phe 1 (tên, số lính, sĩ khí từng đơn vị) | Xạ thủ phe 1 | Chiến trường cận chiến | Xạ thủ phe 2 | Thông tin phe 2 |

(Ban đầu là 5/20/50/20/5; tăng khung thông tin lên 10% để đủ chỗ hiện tên đơn vị, đọc được cả trên điện thoại.)

- Phe của người chơi luôn ở bên trái.
- Mỗi hình lính đại diện cho 4 lính.
- Luôn mở màn hình trận đánh khi có cướp; có nút **Bỏ qua** để mô phỏng nốt và xem kết quả ngay.
- Thông tin luôn hiện sẵn, không cần rê chuột (chuẩn bị cho bản điện thoại).

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

### Công trình khai thác, tài nguyên mới, cấp thành chính (M11c, đã chốt)

**Tài nguyên mới:** Khoáng sản (giá trị giao thương 3), Gỗ cứng (2), Ngựa (3). Dùng để nâng cấp thành và sau này tuyển tướng, kỵ binh, quân tinh nhuệ. Lương thực, gỗ, đá là **tài nguyên cơ bản**.

**Công trình khai thác** (1 ô, xây trên ô đúng địa hình trong lãnh thổ). Phần sinh ra cộng thêm vào sản lượng sẵn có của ô; đặt trên ô ◆ thì sản lượng của công trình ×2. Không trả nổi phí duy trì thì công trình ngừng khai thác lượt sau, giống các công trình khác.

| Công trình | Đặt trên | Cần thành | Mỗi lượt | Giá xây | Phí duy trì |
|---|---|---|---|---|---|
| Mỏ khai thác | Đồi | Cấp 2 | +2 Đá, +1 Khoáng sản | 8 Gỗ, 4 Đá | 1 Lương thực |
| Xưởng gỗ | Rừng | Cấp 2 | +2 Gỗ, +1 Gỗ cứng | 6 Gỗ, 4 Đá | 1 Lương thực |
| Trại ngựa | Ruộng | Cấp 3 | +1 Lương thực, +1 Ngựa | 8 Gỗ, 2 Đá | không |

Giới hạn: Mỏ khai thác 3, Xưởng gỗ 3, Trại ngựa 2.

**Thành chính 6 cấp** (nút "Nâng cấp thành chính" trong tab Xây dựng, có hiệu lực ngay). Mỗi cấp thêm **1 chỗ cho đơn vị lính**, mở khóa công trình, và sau này (M11d) cho tuyển **tướng tới N sao** ở cấp N.

| Lên cấp | Giá |
|---|---|
| 2 | 20 Gỗ, 20 Đá |
| 3 | 30 Gỗ, 30 Đá, 10 Khoáng sản |
| 4 | 40 Đá, 20 Khoáng sản, 15 Gỗ cứng |
| 5 | 60 Đá, 35 Khoáng sản, 30 Gỗ cứng |
| 6 | 80 Đá, 50 Khoáng sản, 45 Gỗ cứng, 20 Ngựa |

Các con số sẽ cân bằng lại sau. Chiến thắng Hòa bình thịnh vượng (§9b) chỉ tính thu nhập của 3 tài nguyên cơ bản.

**Bảng công trình (kiểu Kairosoft, chốt sau khi chơi thử M11c):** tab Xây dựng chỉ để **xây mới** (mỗi công trình ghi số đang có / tối đa, khóa khi chưa đủ cấp thành hoặc đã đủ số). **Bấm vào công trình trên bản đồ** mở bảng của nó:
- Tab **Thông tin** (mô tả, vị trí, sản lượng, phí duy trì, số đang có) và **Nâng cấp** (hiện chỉ thành chính có nâng cấp).
- Thao tác bên dưới: **Nâng cấp** (thành chính) · **Di chuyển** · **Phá hủy**. Bấm thao tác thì bảng ghi rõ nó sẽ làm gì, rồi chờ **Xác nhận** / **Hủy**.
- **Di chuyển:** miễn phí, chọn ô mới trên bản đồ (cùng luật như xây: trong lãnh thổ, đúng địa hình, ô trống), Esc để hủy.
- **Phá hủy:** hoàn lại 50% giá xây, không hoàn tác được.
- Thành chính không phá hủy hay di chuyển được.

### Tướng (M11d, đã chốt)

**Một tổng tướng cho cả đạo quân.** Vương quốc giữ tối đa **3 tướng** (đều tốn phí nuôi): một người làm **tổng tướng**, những người khác dự bị (thay khi tổng tướng bị thương hoặc tử trận). Có thể sa thải tướng (có xác nhận).

**Sao (1–6) và chỉ số:** mỗi tướng có **Võ lực** và **Thống suất** (mỗi chỉ số 1–10). Số sao quyết định **tổng điểm** hai chỉ số; tổng điểm và cách chia đều ngẫu nhiên (sao càng cao tổng càng cao, nhưng vẫn có may rủi).
- **Võ lực:** mỗi điểm **+3% tấn công cận chiến và xung phong** cho cả đạo quân.
- **Thống suất:** mỗi điểm **+0,4 sĩ khí** và **+2% phòng thủ** (cận chiến và giáp) cho cả đạo quân.
- Chỉ cộng cho quân của vương quốc, không cộng cho quân đồng minh gửi đến.

| Sao | Tổng Võ + Thống | Cận vệ | Giá tuyển | Phí nuôi/lượt |
|---|---|---|---|---|
| 1★ | 3–5 | 4 kỵ binh | 30 Lương thực, 20 Gỗ | 2 Lương thực |
| 2★ | 6–8 | 6 | 40 Lương thực, 20 Gỗ, 5 Ngựa | 3 Lương thực |
| 3★ | 9–11 | 7 | 60 Lương thực, 10 Khoáng sản, 10 Ngựa | 4 Lương thực |
| 4★ | 12–14 | 9 | 80 Lương thực, 20 Khoáng sản, 10 Gỗ cứng, 15 Ngựa | 5 Lương thực, 1 Khoáng sản |
| 5★ | 15–17 | 10 | 100 Lương thực, 35 Khoáng sản, 20 Gỗ cứng, 20 Ngựa | 6 Lương thực, 2 Khoáng sản |
| 6★ | 18–20 | 12 | 140 Lương thực, 50 Khoáng sản, 30 Gỗ cứng, 30 Ngựa | 8 Lương thực, 3 Khoáng sản |

**Đặc tính** (`data/traits/`): tướng từ **2★** có 1 đặc tính, **chỉ kích hoạt khi lãnh thổ đạt điều kiện**:

| Đặc tính | Điều kiện | Hiệu ứng |
|---|---|---|
| Thợ săn rừng | Từ 12 ô rừng | Cung thủ +25% sát thương bắn |
| Thiết kỵ | Từ 2 trại ngựa | Xung phong +30% |
| Giữ thành | Khi phòng thủ (cướp, xâm lược) | +2 sĩ khí, +10% phòng thủ |
| Sinh ra trên núi | Từ 10 ô đồi | +15% phòng thủ |
| Tướng đồn điền | Từ 15 ô ruộng | +1,5 sĩ khí |
| Tiên phong | Từ 3 doanh trại | Hàng đầu +15% tấn công cận chiến |

**Chiêu hiền:** bấm vào thành chính → tab **Chiêu hiền**: 3 ứng viên (tên, sao, Võ lực, Thống suất, đặc tính, giá). Số sao không vượt **cấp thành**; sao càng cao càng hiếm. Danh sách đổi sau mỗi **5 lượt**, hoặc trả **20 Lương thực** để đổi ngay. Tab **Tướng**: xem tướng, chọn tổng tướng, sa thải. Phí nuôi tướng trả cùng phí nuôi quân; thiếu lương thực thì quân đào ngũ trước.

**Trong trận:** tổng tướng ra trận cùng một **đơn vị cận vệ kỵ binh** riêng (cờ vàng), **đứng giữa, trước hàng đầu** của đội hình. Cận vệ mạnh như tướng trong Total War Three Kingdoms: chỉ số cao hơn hẳn lính thường, **mỗi cận vệ gây sát thương bằng 4 lính và cần 5 đòn mới ngã**, và còn mạnh thêm theo tướng (+5% tấn công mỗi điểm Võ lực, +5% phòng thủ mỗi điểm Thống suất, ngoài phần cộng cho cả quân). Loại lính có thêm 2 chỉ số chung cho việc này: sát thương mỗi lính và máu mỗi lính (lính thường = 1). Cận vệ **bị vỡ hoặc bị diệt → tướng ngã**: mọi đơn vị phe đó **−3 sĩ khí**. Sau trận: **30% tử trận, 70% bị thương nghỉ 3 lượt** (không ra trận; tướng dự bị không tự thay, người chơi chọn). Không có tổng tướng ra trận được thì quân đi đánh không tướng.

**Sự kiện tướng:**
- **Tướng lạc xin đầu quân:** tướng 1–3★, trả một ít lương thực để nhận (cần còn chỗ).
- **Hàng tướng xin quy thuận:** đầu lượt ngay sau khi sáp nhập một gia tộc, khả năng cao; tướng 3–5★.

### Kinh nghiệm và cấp (M11e, đã chốt)

**Đơn vị lính — 3 cấp:** **Tân binh** (0 XP) → **Cựu binh** (100 XP) → **Tinh nhuệ** (300 XP).

| Cấp | Cộng thêm |
|---|---|
| Tân binh | — |
| Cựu binh | +2 tấn công cận chiến (xạ thủ: +2 tấn công tầm xa), +2 phòng thủ cận chiến, +2 sĩ khí |
| Tinh nhuệ | +4 / +4 / +4 |

**Nhận XP:**
- **Trận đánh:** mỗi đơn vị còn sống sau trận (không vỡ) nhận **+20**, thêm **+2 mỗi lính địch nó hạ**, thêm **+20 nếu phe mình thắng**.
- **Huấn luyện:** có ít nhất 1 doanh trại thì mỗi lượt mọi đơn vị nhận **+10**, nhưng huấn luyện chỉ đưa tới **Cựu binh** (khoảng 10 lượt). **Tinh nhuệ** chỉ đạt được qua trận đánh. Miễn phí.

**Lính bổ sung pha loãng kinh nghiệm:** XP là trung bình mỗi lính, lính mới có 0 XP, nên khi thêm lính (bổ sung cuối lượt, sự kiện): XP mới = XP cũ × lính cũ / tổng lính. Đơn vị mất một nửa quân rồi bổ sung đầy còn khoảng nửa XP và có thể tụt cấp.

**Tướng:** bắt đầu ở **cấp 1**, cấp tối đa = **2 + số sao** (1★: cấp 3, 6★: cấp 8). Lên cấp tiếp theo cần **100 × cấp hiện tại** XP.
- Chỉ **tổng tướng ra trận** nhận XP: **+30** mỗi trận, **+30 nếu thắng**, **+5 mỗi lính địch cận vệ hạ**. Tướng ngã trong trận vẫn nhận XP nếu sống sót (bị thương). Tướng dự bị không lên cấp.
- Mỗi cấp được **1 điểm**; người chơi tự cộng vào **Võ lực** hoặc **Thống suất** trong tab Tướng. Điểm chưa dùng được giữ lại.

**Hiển thị:** tab Quân đội (ký hiệu cấp + thanh XP mỗi đơn vị), màn hình trận (ký hiệu cấp cạnh tên đơn vị), tab Tướng (cấp, thanh XP, nút cộng điểm). Báo cáo sau trận chưa ghi lên cấp; bố cục các tab sẽ gọn lại ở M12.

**Để sau:** quân gia tộc có cấp; **Thảo phạt đạo tặc** — icon đỏ hiện ở góc màn hình, cử 1 tướng, 1 mưu sĩ và vài đơn vị đi như một chuyến commission (kiểu mini game thảo phạt trong Dungeon Village của Kairosoft): cutscene màn hình ngang, một hàng quân xếp theo loại tiến từ trái sang phải, đánh qua từng ải tới khi chinh phục hết hoặc thua hết; nhận tài nguyên, kinh nghiệm, trang bị. Cách này cho tướng dự bị có việc làm.

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

### 9.1 Bản đồ thế giới (M8)

- Nút **Ngoại giao** trên thanh trên cùng mở màn hình bản đồ thế giới (toàn màn hình).
- Bản đồ dạng **điểm vùng nối đường**: vương quốc ở giữa, mỗi gia tộc là một điểm, có đường nối giữa các vùng giáp nhau.
- Chạm vào một gia tộc → bảng bên phải: mô tả, tính cách, sức mạnh, hướng, quan hệ, tài nguyên dư/thiếu, và các hành động.
- **Bảng lệnh kiểu Shogun 2** (chốt sau M9b): thanh bên phải chỉ có phần tóm tắt và **mỗi lệnh một nút** (Trao đổi · Tặng quà · Hợp đồng giao thương · Liên minh · Bất tương xâm · Tuyên chiến; khi đang chiến tranh: Tấn công · Nghị hòa · Tặng quà, các lệnh hòa bình bị ẩn). Nút không dùng được thì mờ đi, lý do ghi ngay dưới.
- Bấm một nút → **bảng riêng giữa màn hình** (bản đồ mờ phía sau) để chỉnh chi tiết, xem trước kết quả / khả năng đồng ý rồi mới xác nhận. Bảng nào dùng tài nguyên (trao đổi, tặng quà, hợp đồng, nghị hòa) hiện luôn **kho tài nguyên hiện có**. Tuyên chiến liệt kê hết hậu quả; Tấn công cho xem trước quân hai bên (cả đồng minh và bạn của đối phương).

### 9.2 Gia tộc (tên tạm, sửa trong `data/clans/`)

| Gia tộc | Vị trí | Tính cách | Dư | Thiếu | Quan hệ đầu / gốc |
|---|---|---|---|---|---|
| Lang Tộc Phương Bắc | Bắc (giáp biên) | Hiếu chiến | Đá | Lương thực | −10 / −15 |
| Thương Hội Đông Hải | Đông (giáp biên) | Thương nhân | Lương thực | Gỗ | 10 / 20 |
| Điền Trang Nam Lâm | Nam (giáp biên) | Ôn hòa | Gỗ | Đá | 20 / 30 |
| Hắc Sơn Bảo | Tây (giáp biên) | Cô lập | Đá | Lương thực | −5 / 0 |
| Vương Quốc Kim Ưng | Xa, Đông Bắc | Hiếu chiến | Đá | Gỗ | 0 / −5 |
| Bộ Lạc Thảo Nguyên | Xa, Tây Nam | Ôn hòa | Lương thực | Đá | 0 / 10 |

Gia tộc giáp biên có hướng (Bắc/Đông/Nam/Tây) để M9 biết mất đất ở cạnh nào. Gia tộc ở xa chỉ giao thương (giá kém hơn).

### 9.3 Quan hệ

Thang −100 → +100:

| Mức | Khoảng |
|---|---|
| Thù địch | ≤ −60 |
| Căng thẳng | −59 → −20 |
| Trung lập | −19 → 19 |
| Thân thiện | 20 → 59 |
| Thân thiết | ≥ 60 |

**Quan hệ = tổng các yếu tố** (kiểu Total War, đã chốt sau khi chơi thử M9b). Người chơi luôn xem được từng yếu tố, và chúng cộng lại đúng bằng con số trên thanh:
- **Yếu tố lâu dài:**
  - Thiện cảm gốc (mức gốc trong file gia tộc).
  - E dè vương quốc lớn mạnh (trừ).
  - Đang có hợp đồng dài hạn +15.
  - Đang liên minh +30.
  - Đang có hiệp ước bất tương xâm +10.
- **Sự kiện gần đây**, ghi riêng theo nguồn: ấn tượng ban đầu (quan hệ đầu − mức gốc), quà tặng, giao thương, chuyện hợp đồng, chiến tranh với vương quốc, vương quốc gây chiến với gia tộc khác, trận đánh chung, bị hủy liên minh. Mỗi nguồn **mờ dần về 0** mỗi lượt (ôn hòa / thương nhân 2 điểm, hiếu chiến 3, cô lập 1).
- **E dè** = Uy hiếp × hệ số (hiếu chiến ×1.0, cô lập ×0.8, ôn hòa ×0.5, thương nhân ×0.4). Không áp ngay mà **tăng dần** tới mức đó, mỗi lượt cùng số điểm như trên (giảm dần khi Uy hiếp giảm).
- **Uy hiếp** của vương quốc = (số ô lãnh thổ − 16) / 4 + 15 × số gia tộc đã sáp nhập + số lính / 20. Vương quốc càng lớn mạnh, các gia tộc càng e dè.
- Tổng bị giới hạn −100 → 100. Mỗi thay đổi dịch đúng con số đang hiển thị (phần vượt giới hạn bị bỏ, không nằm ẩn).
- Bảng gia tộc hiện quan hệ, mức "về lâu dài" (khi mọi sự kiện đã mờ hết và e dè đã đủ), nút **Chi tiết quan hệ** (chạm để mở) liệt kê phần cộng và phần trừ; rê chuột vào thanh quan hệ cũng hiện bảng đó.
- **Tặng quà:** mỗi 5 giá trị tài nguyên = +1 quan hệ, nhân theo tính cách (ôn hòa ×1.5, thương nhân ×1, hiếu chiến ×0.6, cô lập ×0.5); tối đa +15 mỗi lượt cho mỗi gia tộc.
- Mỗi lần trao đổi: +1 quan hệ (tối đa +3 mỗi lượt).
- "Đồng minh" là hiệp ước riêng (§9.7), không phải một mức quan hệ.

### 9.4 Trao đổi tài nguyên

- Giá trị: lương thực 1, gỗ 1, đá 2.
- Đưa X, nhận Y: số nhận = số đưa × giá trị(X) / giá trị(Y) × hệ số giá.
- Hệ số giá = 0.6 + quan hệ/100 × 0.2, +0.15 nếu là thương nhân, ×1.4 nếu X là thứ họ **thiếu**, ×1.3 nếu Y là thứ họ **dư**, ×0.85 nếu ở xa.
- Mỗi gia tộc chỉ nhận tối đa 40 giá trị hàng mỗi lượt (chống mua đi bán lại vô hạn).
- Quan hệ Căng thẳng trở xuống: từ chối giao thương.

### 9.5 Hợp đồng giao thương dài hạn

- Người chơi đề nghị: **đưa** X mỗi lượt, **nhận** Y mỗi lượt, trong **N lượt** (5–30, người chơi chọn). Giá trị hàng đưa tối đa 30 mỗi lượt. Mỗi gia tộc tối đa 1 hợp đồng.
- **Thương thảo (kiểu Shogun 2):** trước khi gửi, hiện khả năng đồng ý.
  - Khả năng = 1.5 − (Y đòi / Y công bằng) + quan hệ/200 + tính cách (thương nhân +0.15, ôn hòa +0.05, hiếu chiến −0.1, cô lập −0.2), giới hạn 0 → 95%. "Y công bằng" là số họ sẽ trả cho X theo giá trao đổi một lần (§9.4).
  - Mức: Rất có thể (≥80%), Có thể (≥55%), Khó (≥30%), Rất khó (>0), Không thể.
  - Gia tộc từ chối khi quan hệ Căng thẳng trở xuống. Bị từ chối → phải đợi lượt sau mới đề nghị lại với gia tộc đó.
- **Ký:** quan hệ +8 ngay (sự kiện, mờ dần), và +15 suốt thời gian hợp đồng còn chạy (§9.3). Mỗi lượt (lúc kết thúc lượt): đưa X, nhận Y, quan hệ +1.
- **Thiếu hàng để giao:** lượt đó bỏ qua, quan hệ −3.
- **Hết hạn:** quan hệ +3 (và mất +15 của hợp đồng). **Người chơi hủy:** quan hệ −20. **Quan hệ xuống Thù địch:** gia tộc tự hủy.

### 9.6 Chiến tranh (M9)

**Trạng thái:** mỗi gia tộc ở **Hòa bình** hoặc **Chiến tranh** với vương quốc.

**Sức mạnh quân sự** = số lính của gia tộc (tối đa = giá trị trong file dữ liệu). Hồi 2 lính mỗi lượt tới mức tối đa. Quân của gia tộc dùng các loại lính như người chơi, theo tỉ lệ `army_units` trong file gia tộc.

**Bắt đầu chiến tranh:**
- Người chơi **tuyên chiến** (nút trên bản đồ thế giới, bấm 2 lần): quan hệ với họ xuống Thù địch, các gia tộc khác −5.
- Gia tộc tự tuyên chiến khi quan hệ **Thù địch**, mỗi lượt có khả năng: hiếu chiến 15%, cô lập 5%, thương nhân 5%, ôn hòa 2%. Gia tộc **hiếu chiến** còn có thể tuyên chiến từ mức **Căng thẳng** (5% mỗi lượt).
- Chỉ gia tộc **giáp biên** mới đánh nhau được. Chiến tranh nổ ra thì hợp đồng giao thương với họ tự hủy.

**Quân xâm lược (họ đánh mình):** khi đang chiến tranh, mỗi lượt 25% khả năng (cách lần trước ít nhất 3 lượt), họ đem **60% quân** tới. Trận đánh như đánh cướp (màn hình trận, có rút lui).
- Thua: luật thua chung (§7.6), **mất tối đa 6 ô lãnh thổ gần cạnh phía họ nhất** (ô thành đất hoang, công trình trên đó bị phá, thành chính không bao giờ mất) và **bị cướp phá 40%** mỗi loại tài nguyên (nặng hơn cướp: 30%).
- Thắng: họ mất số lính tử trận.

**Đi xâm lược (mình đánh họ):** nút **Tấn công** trên bản đồ thế giới, khi đang chiến tranh, 1 lần mỗi lượt. Toàn bộ quân tham chiến; họ phòng thủ bằng toàn bộ quân.
- Thắng: mỗi lính địch tử trận = +1 lương thực, +1 gỗ, +1 đá chiến lợi phẩm.
- Thua: **mất toàn bộ quân** (rút lui thì đơn vị chưa vỡ giữ 50%) và **bồi thường 25%** mỗi loại tài nguyên.

**Sáp nhập:** khi người chơi thắng và sức mạnh của họ còn dưới 15% tối đa, họ đầu hàng:
- Gia tộc bị sáp nhập (không còn giao thiệp).
- **Bản đồ vương quốc nới rộng thêm 4 hàng/cột đất hoang về phía họ** (ví dụ 12×12 → 12×16). Người chơi tự đặt mảnh đất để chiếm.
- Gia tộc ở xa có đường nối với họ trở thành **láng giềng mới cùng hướng** đó.

**Nghị hòa:** thương thảo như hợp đồng, hiện khả năng đồng ý:
- Khả năng = 0.1 + 0.8 × (tỉ lệ quân họ đã mất) + quan hệ/200 + giá trị bồi thường/100, tối đa 95%. Mỗi lượt đề nghị 1 lần.
- Hòa xong: quan hệ ít nhất −30 (Căng thẳng), **đình chiến 10 lượt** (không bên nào tuyên chiến lại).

### 9.7 Liên minh & bất tương xâm (M9b)

**Bạn bè giữa các gia tộc** (cố định trong dữ liệu, `friends` trong `data/clans/`, luôn hai chiều):

| Gia tộc | Bạn |
|---|---|
| Lang Tộc Phương Bắc | Vương Quốc Kim Ưng |
| Vương Quốc Kim Ưng | Lang Tộc Phương Bắc, Thương Hội Đông Hải |
| Thương Hội Đông Hải | Vương Quốc Kim Ưng |
| Hắc Sơn Bảo | Bộ Lạc Thảo Nguyên |
| Bộ Lạc Thảo Nguyên | Hắc Sơn Bảo, Điền Trang Nam Lâm |
| Điền Trang Nam Lâm | Bộ Lạc Thảo Nguyên |

**Liên minh:**
- Chỉ đề nghị được khi quan hệ **Thân thiết (≥ 60)** và không chiến tranh. Hiện khả năng đồng ý trước khi gửi:
  - Khả năng = 0.3 + (quan hệ − 60) / 80 + tính cách (như hợp đồng: thương nhân +0.15, ôn hòa +0.05, hiếu chiến −0.1, cô lập −0.2) − Uy hiếp / 200, giới hạn 0 → 95%.
  - Bị từ chối → **3 lượt** sau mới đề nghị lại được.
- Thời hạn **20 lượt**. Trong **5 lượt cuối** có thể **gia hạn** thêm 20 lượt (lại tính khả năng đồng ý). Hết hạn thì phải ký lại từ đầu.
- Khi đang liên minh, **quan hệ +30** ngay (yếu tố lâu dài, §9.3); hết liên minh thì mất +30 ngay. Uy hiếp vẫn tác động.
- Quan hệ tụt xuống dưới **Thân thiện (< 20)** → liên minh tự tan. Người chơi chủ động hủy → quan hệ **−30**.

**Đồng minh gửi quân:**
- Vào mọi trận của vương quốc: bị cướp, bị xâm lược, đi đánh. Mỗi đồng minh gửi **30% sức mạnh hiện có** (cùng loại lính theo `army_units`), đứng chung phe người chơi, vẽ màu cờ của họ.
- Không gửi nếu sức mạnh của họ dưới 30% tối đa, hoặc kẻ địch là **bạn** của họ.
- Lính đồng minh chết hay mất khi thua thì sức mạnh của đồng minh giảm thật (luật thua chung §7.6, không chịu luật "mất toàn bộ quân" khi đi đánh thua), rồi hồi dần như thường.
- Thắng trận chung: quan hệ **+5**. Thua: **−10**.

**Hiệp ước bất tương xâm:**
- Ký được khi quan hệ **Thân thiện (≥ 20)** trở lên và không chiến tranh, luôn được đồng ý. Kéo dài **10 lượt**, hết hạn thì ký lại.
- Đang có hiệp ước: **quan hệ +10** (yếu tố lâu dài, §9.3); hết hạn hoặc bị phá thì mất +10 ngay.
- Trong thời gian đó gia tộc **không tuyên chiến** với vương quốc, dù quan hệ có tụt. Có thể ký cùng lúc với liên minh (đồng minh vẫn gửi quân như thường).

**Khi bạn đánh một gia tộc:**
- Bạn của họ gửi **30% quân** sang giúp họ phòng thủ (cùng điều kiện ≥ 30% sức mạnh), trừ khi người bạn đó là đồng minh của bạn hoặc đang có bất tương xâm với bạn. Lính họ mất cũng trừ vào sức mạnh của họ.
- Người chơi tuyên chiến: bạn của mục tiêu **−15** quan hệ (thay cho −5 như các gia tộc khác).
- **Phá hiệp ước:** tuyên chiến với đồng minh → liên minh tan, mọi gia tộc khác thêm **−20**. Tuyên chiến khi đang bất tương xâm → hiệp ước mất, mọi gia tộc khác thêm **−10**.
- Chiến tranh nổ ra (bất kể bên nào tuyên chiến) thì liên minh và bất tương xâm với gia tộc đó mất.

### 9.8 Ý tưởng ngoại giao để sau

- Tăng độ khó: gia tộc hồi quân nhanh hơn / mạnh dần theo thời gian, quân xâm lược đông hơn ở giai đoạn sau.

- Kết thông gia (quan hệ tăng lâu dài, cần tướng/người trong gia đình — M11).
- Yêu sách / cống nạp: gia tộc mạnh đòi nộp tài nguyên mỗi lượt, từ chối thì quan hệ giảm và dễ bị xâm lược; người chơi mạnh cũng có thể đòi lại.
- Mượn đường quân sự (đánh gia tộc ở xa qua đất láng giềng — M9).
- Sự kiện ngoại giao ngẫu nhiên: sứ giả đến, gia tộc gặp nạn đói xin viện trợ, hai gia tộc gây chiến với nhau…

## 9b. Thắng / thua (M11a, đã chốt)

Không giới hạn số lượt: chơi tới khi thắng hoặc thua.

**Hai đường chiến thắng** (đạt đường nào trước cũng được; chốt lại sau khi chơi thử, gộp ngoại giao với kinh tế):

| Đường | Điều kiện |
|---|---|
| **Chinh phục** | Sáp nhập mọi gia tộc. Thắng ngay khi gia tộc cuối cùng đầu hàng. |
| **Hòa bình thịnh vượng** | Cùng lúc: mọi gia tộc chưa bị sáp nhập đều đang là đồng minh (**ít nhất 1** đồng minh), **từ 120 ô lãnh thổ**, thu nhập ròng (sau nuôi quân, phí công trình, hợp đồng) **từ +50 mỗi loại tài nguyên cơ bản (lương thực, gỗ, đá) mỗi lượt**; giữ như vậy **10 lượt liền**. |

Các con số sẽ cân bằng lại sau.

- Bộ đếm "giữ liền" tăng ở cuối mỗi lượt khi điều kiện đang đúng, và về 0 ngay khi điều kiện sai.
- Thắng → **màn chiến thắng** với thống kê (số lượt, lãnh thổ, số lính, trận thắng/thua, gia tộc sáp nhập / đồng minh). Chọn **Chơi tiếp** (ván tiếp tục, không báo thắng lại) hoặc **Về menu chính**.

**Thất bại: thành chính thất thủ.** Thua một trận xâm lược khi vương quốc **không còn ô đất nào ngoài thành chính** thì thành chính bị chiếm và ván kết thúc. Màn thất bại có **Tải game** và **Về menu chính**. Khi chỉ còn từ 6 ô đất trở xuống ngoài thành chính, bảng Mục tiêu và thông báo cuối lượt cảnh báo.

**Theo dõi:** nút **Mục tiêu** trên thanh trên cùng mở bảng giữa màn hình (2 cột). Mỗi đường chiến thắng có thanh tiến độ, từng điều kiện kèm số hiện tại / số cần (ví dụ "Lãnh thổ 72/120"), và số lượt đã giữ ("Đã giữ 4/10 lượt"). Bảng có cả mục cảnh báo thành chính.

Thống kê trận thắng/thua và trạng thái thắng/thua được lưu cùng ván (§10.1).

**Để sau:** bản đồ sẽ có thêm nhiều gia tộc, và khi bắt đầu ván người chơi chọn một trong vài gia tộc để chơi. Điều kiện thắng sẽ được chỉnh lại cho khó hơn lúc đó (code đã tính theo số gia tộc thực tế, không cố định 6).

## 9c. Sự kiện ngẫu nhiên (M11b, đã chốt)

**Xuất hiện:** đầu mỗi lượt, từ lượt 3, sau trận đánh đầu lượt (nếu có). Số sự kiện mỗi lượt:

| Số sự kiện | Khả năng |
|---|---|
| 0 | 50% |
| 1 | 30% |
| 2 | 15% |
| 3 | 5% |

- Mỗi sự kiện có **trọng số** và **thời gian nghỉ** riêng (ví dụ được mùa không lặp lại trong 8 lượt). Một lượt không ra 2 lần cùng một sự kiện.
- Mỗi sự kiện có **điều kiện** ghi trong dữ liệu (`data/events/*.tres`): lượt tối thiểu, kho tài nguyên, có công trình, có quân, đang chiến tranh, có đồng minh, có gia tộc ở mức quan hệ phù hợp, vừa đánh thắng cướp ở lượt trước… Sự kiện ngoại giao tự chọn một gia tộc phù hợp. Thêm sự kiện mới chỉ cần thêm file.
- Sự kiện hiện lần lượt ở **bảng giữa màn hình**, phải chọn mới đi tiếp. Sự kiện chưa giải quyết được lưu cùng ván (tải lại vẫn còn).

**Lựa chọn, hậu quả ẩn một phần:** mỗi sự kiện có 1–3 lựa chọn.
- **Cái giá** (tài nguyên bỏ ra) luôn hiện rõ; không đủ thì lựa chọn bị khóa.
- **Kết quả** chỉ ghi gợi ý; có thể ngẫu nhiên giữa vài kết quả. Chọn xong mới hiện kết quả thật và danh sách thay đổi.
- Hậu quả có thể là: được/mất tài nguyên (số cố định hoặc phần trăm), quan hệ với một gia tộc hoặc mọi gia tộc (nguồn "Sự kiện" trong chi tiết quan hệ, mờ dần), thêm đơn vị lính, mất một phần lính, bổ sung quân, thêm mảnh đất vào tay, gia tộc mạnh/yếu đi, gia tộc tuyên chiến.

**Bộ sự kiện đầu tiên:**
- Kinh tế: được mùa, sâu bệnh mất mùa, thương nhân lạ, cháy kho gỗ, phát hiện mạch đá.
- Ngoại giao: gia tộc gặp nạn đói xin viện trợ, sứ giả mang quà, gia tộc mạnh đòi cống nạp, đồng minh nhờ giúp.
- Quân sự: người tình nguyện đầu quân, lính đòi tăng lương, dịch bệnh trong doanh trại, bọn cướp bị bắt xin tha (chỉ khi lượt trước vừa đánh thắng cướp).
- Việc trong vương quốc: lễ hội mùa, nông dân xin khai hoang, thầy thuốc ghé qua.

**Để sau (cần tướng, quân sư):** chiêu mộ tướng / quân sư của gia tộc vừa bị đánh bại; nhặt được trang bị tốt (chỉ tướng và quân sư dùng được).

## 10. Quyết định kỹ thuật

| Vấn đề | Quyết định |
|---|---|
| Dữ liệu tĩnh (địa hình, mảnh, đơn vị, công trình) | `Resource` (`.tres`) trong `data/`, nạp theo thư mục |
| Trạng thái ván chơi | Lớp `RefCounted` thuần logic (`BoardData`, …), không phụ thuộc Node |
| Hiển thị | Node riêng (`BoardView`, …) chỉ đọc dữ liệu, không tự sửa |
| Lưu game | JSON có trường `save_version`; **không** dùng `ResourceSaver`/`.tres` cho file save |
| Kiểm thử | Script headless tự viết trong `tests/`, không dùng thư viện ngoài |
| Độ phân giải | Khung thiết kế 1280×720, cửa sổ mặc định 1920×1080 (phóng to tự động, chữ vẫn nét), `stretch = canvas_items`, `aspect = expand` để vừa mọi tỉ lệ màn hình |
| Nền tảng | Windows trước; **Android (APK)** sau. Renderer GL Compatibility hợp với Android. Giao diện mới không được chỉ dựa vào rê chuột hay phím tắt |
| Tên lớp | Tránh trùng lớp có sẵn của Godot (ví dụ dùng `CellData`, không dùng `TileData`) |

### 10.1 Lưu / tải (M10, đã chốt)

- **Ô lưu:** 1 ô **Tự động** + **3 ô lưu tay**. Mỗi ô hiện: lượt, số ô lãnh thổ, số lính, ngày giờ lưu.
- **Tự động lưu** mỗi khi sang lượt mới, sau khi trận đánh đầu lượt (nếu có) đã xong; và lúc bắt đầu ván mới.
- **Lưu tay bất cứ lúc nào ở màn vương quốc**, kể cả giữa lượt: giữ nguyên mảnh đất trên tay, tài nguyên, giới hạn quà / giao thương / đề nghị của lượt. Không lưu được khi đang xem trận đánh hay đang mở bản đồ thế giới. Ghi đè ô đã có phải bấm 2 lần.
- **Tải lại thì gieo lại ngẫu nhiên:** mảnh đất đang trên tay giữ nguyên, nhưng các mảnh sau, cướp, xâm lược, gia tộc đồng ý hay không đều ra kết quả mới.
- **Menu chính** khi mở game: Tiếp tục (bản lưu mới nhất) · Ván mới · Tải game · Thoát. Trong ván: nút **Menu** trên thanh trên cùng → Tiếp tục chơi · Lưu game · Tải game · Về menu chính.
- **Kỹ thuật:**
  - File JSON trong `user://saves/` (`auto.json`, `slot_1.json`…), ghi ra file tạm rồi mới đổi tên để không hỏng file cũ khi game tắt giữa chừng.
  - Mỗi file có `save_version`. Bản cũ hơn được nâng cấp từng bước (`v1 → v2 → …`) khi tải. Bản mới hơn phiên bản game thì báo lỗi, không tải.
  - Chỉ lưu trạng thái ván. Dữ liệu tĩnh (địa hình, lính, gia tộc…) đọc lại từ `data/`. Gia tộc hay loại lính không còn trong dữ liệu thì bỏ qua; gia tộc mới thêm vào dữ liệu thì dùng giá trị ban đầu.

## 11. Lộ trình

| Mốc | Nội dung | Trạng thái |
|---|---|---|
| M1 | Lưới 12×12, thành 2×2, zoom/pan, xem thông tin ô | Xong |
| M2 | Mảnh đất (hướng cố định), xem trước, kết nối, đè thay thế, ô quan trọng | Xong |
| ⏸ | **Chơi thử: xếp đất có vui không? Chỉnh trước khi đi tiếp** | Xong (ổn) |
| M3 | Sản lượng mỗi lượt, kết thúc lượt, nhận mảnh đầu lượt, ô ◆ ×2 | Xong |
| M4 | Công trình, dữ liệu đơn vị, doanh trại, tuyển quân, nuôi quân, mở khóa theo địa hình | Xong |
| M5 | Logic trận đánh theo pha + **cướp** (ngẫu nhiên, không báo trước) + trạm lính canh + bảng thống kê sau trận | Xong |
| M6 | **Chiến đấu v2** (logic): chỉ số mới, sĩ khí, charge, súng 1 loạt, cung theo thời gian nạp, mô phỏng theo tick, rút lui + **quản lý đơn vị** (bổ sung quân, giới hạn theo doanh trại, giải tán) | Xong |
| M7 | Màn hình trận đánh cinematic (10/18/44/18/10, hoạt ảnh, tạm dừng, tăng tốc, rút lui, bỏ qua) | Xong |
| M8 | Bản đồ thế giới làm sẵn + gia tộc + quan hệ + giao thương + hợp đồng dài hạn | Xong |
| M9 | Chiến tranh: tuyên chiến, quân xâm lược (mất đất theo hướng), đi xâm lược, nghị hòa, sáp nhập + mở rộng bản đồ | Xong |
| M9b | Liên minh: hiệp ước, đồng minh gửi quân vào trận, bất tương xâm | Xong |
| M10 | Lưu/tải (JSON có version), menu chính | Xong |
| M11a | Điều kiện thắng/thua, bảng Mục tiêu, màn kết thúc | Xong |
| M11b | Sự kiện ngẫu nhiên (dữ liệu .tres, có lựa chọn và hậu quả) | Xong |
| M11c | Kinh tế mới: cấp thành chính, công trình khai thác, Khoáng sản / Gỗ cứng / Ngựa | Xong |
| M11d | Tướng: sao 1–6, Võ lực / Thống suất / đặc tính theo lãnh thổ, một tổng tướng + cận vệ kỵ binh trong trận, tử trận / bị thương, sự kiện chiêu mộ | Xong |
| M11e | Kinh nghiệm và cấp: đơn vị 3 cấp (huấn luyện tới Cựu binh, pha loãng khi bổ sung), tướng lên cấp và tự cộng điểm | Đang làm |
| M11f | Mưu sĩ: cộng kinh tế, ngoại giao | |
| M12 | **Hỗ trợ cảm ứng + xuất APK** (chạm để xem trước/xác nhận, vuốt để kéo, chụm để zoom, nút thay phím tắt); **sắp xếp lại tab Quân đội và Xây dựng** cho gọn trên điện thoại (ít chữ, thông tin chi tiết mở khi chạm) | |
| M13 | Pixel art, âm thanh, cân bằng, build Windows + Android | |

Lưu/tải được đưa lên trước sự kiện và tướng, vì trạng thái game càng nhiều thì càng khó thêm lưu game về sau.

## 12. Câu hỏi mở

- Đè lên ô có công trình (ngoài thành): cấm hẳn, hay cho phép phá công trình và hoàn lại một phần tài nguyên?
- Sau khi chơi thử: có nên cho người chơi xoay mảnh không?
- Số mảnh mỗi lượt và tỉ lệ xuất hiện ô quan trọng.
- Bản đồ cố định 12×12, hay mở rộng biên khi nâng cấp thành?
- Bộ asset pixel art sẽ dùng (Kenney, itch.io…).
