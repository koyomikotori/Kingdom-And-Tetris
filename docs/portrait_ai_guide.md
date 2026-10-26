# Hướng dẫn làm chân dung tướng / mưu sĩ bằng AI pixel art

Mục tiêu: một **bộ chân dung pixel anime** cho tướng và mưu sĩ (nam và nữ), cùng một phong cách, đặt vào game thay cho chân dung ghép bằng script.

## 1. Nên dùng nền tảng nào

| Nền tảng | Ưu điểm | Nhược điểm |
|---|---|---|
| **PixelLab** (pixellab.ai) — *khuyến nghị* | Chuyên pixel art; ra ảnh đúng lưới pixel ở kích thước nhỏ (32–128 px); có công cụ giữ phong cách (style reference), sửa từng vùng (inpaint) và plugin cho Aseprite | Trả phí theo gói; phong cách anime cần thử vài lần |
| **Retro Diffusion** (retrodiffusion.ai) | Mô hình riêng cho pixel art, lưới pixel sạch, có giới hạn bảng màu; có plugin Aseprite | Ít lựa chọn về tư thế chân dung hơn |
| Midjourney / ChatGPT (GPT image) / Gemini / Flux | Mặt anime đẹp, dễ ra đúng ý | Chỉ "giả pixel": pixel không đều, nhiều màu chuyển mịn; **bắt buộc xử lý lại** (mục 5) trước khi đưa vào game |

Gợi ý: dùng **PixelLab hoặc Retro Diffusion** làm chính. Nếu muốn mặt đẹp hơn, vẽ ý tưởng bằng Midjourney / ChatGPT, rồi đưa ảnh đó làm ảnh tham chiếu (style reference / image-to-image) cho công cụ pixel.

> **Bản quyền:** trước khi đưa ảnh vào game để phát hành, đọc điều khoản dùng thương mại của nền tảng (nhiều nơi chỉ cho dùng thương mại ở gói trả phí). Không ghi tên nhân vật hay họa sĩ có thật vào prompt.

## 2. Kích thước và định dạng

- **Ảnh gốc 64×64 pixel** (pixel thật, không phải ảnh lớn được làm giống pixel). Đủ chỗ cho mắt anime, tóc và mũ, mà vẫn đúng chất pixel.
- Game sẽ phóng **nguyên lần**: ×2 (128 px) trong Chiêu hiền, ×3 (192 px) trong bảng chi tiết, nên giữ nét pixel sắc.
- **PNG, nền trong suốt.** Game tự vẽ nền và khung (khung gỗ, khung vàng cho 4★ trở lên), nên ảnh không cần khung.
- **Khung hình:** ngực trở lên (bust), mặt nhìn thẳng hoặc hơi nghiêng 3/4, đầu chiếm khoảng 1/2 chiều cao, chừa 3–4 pixel trống ở mép trên để mũ và lông trĩ không bị cắt.
- **Tối đa khoảng 32 màu** mỗi ảnh, viền tối (nâu đen) 1 pixel.

## 3. Prompt mẫu

Viết prompt bằng tiếng Anh (các mô hình hiểu tốt hơn). Giữ nguyên **phần phong cách**, chỉ đổi **phần nhân vật**.

**Phần phong cách** (dùng cho mọi ảnh):

```
pixel art portrait, 64x64, anime style, bust shot, facing viewer, clean 1px dark outline,
limited palette, flat shading with 2-3 tones, crisp pixels, no anti-aliasing, transparent
background, ancient East Asian setting, bright Kairosoft-like colors
```

**Phần nhân vật** (chọn một, rồi đổi chi tiết cho mỗi người):

- Tướng nam:
  ```
  young male general, determined eyes, gold helmet with two long pheasant feathers,
  lamellar armor with gold trim, blue cloth under the armor, short beard
  ```
- Nữ tướng:
  ```
  female general, confident smile, long black hair flowing from under a gold helmet with
  pheasant feathers, light lamellar armor with gold trim, blue cloth
  ```
- Mưu sĩ nam:
  ```
  male strategist, calm wise eyes, black winged official's cap, blue scholar robe with white
  crossed collar, holding a white feather fan, thin mustache
  ```
- Nữ mưu sĩ:
  ```
  female strategist, gentle eyes, hair in a bun with a jade hairpin and dangling beads, blue
  scholar robe with white crossed collar, holding a white feather fan
  ```

**Prompt loại trừ** (negative prompt, nếu nền tảng có):

```
blurry, smooth gradients, anti-aliasing, 3d render, photo, text, watermark, frame, border,
background scenery, full body, extra fingers
```

**Tạo nhiều người khác nhau:** đổi tuổi (young / middle-aged / old), kiểu tóc, màu tóc (black / dark brown / chestnut / silver), râu, biểu cảm (stern / cheerful / cold / kind), màu nhấn (red / jade / purple plume). Nên làm khoảng **6–10 ảnh mỗi nhóm** (tướng nam, nữ tướng, mưu sĩ nam, nữ mưu sĩ) để ít bị trùng mặt.

## 4. Giữ cùng một phong cách

- Làm thật ưng **1 ảnh đầu tiên**, rồi dùng nó làm **ảnh tham chiếu phong cách** (style reference) cho mọi ảnh sau.
- Giữ nguyên phần phong cách của prompt. Nếu nền tảng cho cố định seed thì dùng cùng seed.
- **Áo giáp / áo thụng nên để màu xanh lam.** Đây là màu quân của người chơi hiện tại; sau này có màn chọn màu, mình có thể đổi màu áo bằng code nếu áo vẽ ở một gam màu riêng.

## 5. Xử lý lại (bắt buộc với Midjourney / ChatGPT / Gemini)

1. Mở ảnh trong **Aseprite** (hoặc LibreSprite, Pixelorama miễn phí).
2. Thu nhỏ về **64×64** bằng chế độ **Nearest Neighbor** (không dùng Bilinear).
3. Giảm còn **≤ 32 màu** (Sprite → Color Mode → Indexed), sửa vài pixel lỗi ở mắt và viền.
4. Xóa nền thành trong suốt, xuất **PNG**.

## 6. Đưa vào game

Đặt tên file theo nhóm rồi chép vào thư mục `assets/portraits/pool/`:

```
general_m_01.png, general_m_02.png, ...
general_f_01.png, ...
advisor_m_01.png, ...
advisor_f_01.png, ...
```

Khi đủ ảnh, mình sẽ sửa game để:
- mỗi tướng / mưu sĩ tự nhận một chân dung trong nhóm đúng loại và giới tính (cố định theo người, lưu được),
- game tự vẽ nền và khung quanh ảnh,
- chân dung ghép bằng script chỉ dùng khi nhóm đó chưa có ảnh nào.

Hình pixel lúc ra trận vẫn do script vẽ, vì cần đủ hoạt ảnh và lớp màu theo phe. Nếu muốn, có thể làm bằng AI ở bước sau.
