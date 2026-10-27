# Xuất bản Android (APK) — hướng dẫn cài đặt

Project đã có sẵn cấu hình xuất Android (`export_presets.cfg`, preset **"kingdomtiles"**: tên "Kingdom Tiles : Rise Of Realms", gói `com.koyomikotori.kingdomtiles`, màn hình ngang, icon thành trì, `arm64-v8a` cho điện thoại thật và `x86_64` cho giả lập). Máy tính chỉ cần cài thêm 3 thứ dưới đây **một lần**. Các phần mềm này phải tự tải và chấp nhận điều khoản của nhà phát hành.

## 1. Export templates của Godot 4.5.1

1. Mở project trong Godot 4.5.1 (bản có giao diện, không phải bản console).
2. Menu **Editor → Manage Export Templates…**
3. Bấm **Download and Install** (chọn mirror chính thức). Khoảng 1 GB.

Xong thì có thư mục `%APPDATA%\Godot\export_templates\4.5.1.stable\`.

## 2. JDK 17

Godot 4.5 dùng **OpenJDK 17** (máy đang có Java 21; nên cài thêm 17 cho chắc chắn, hai bản dùng song song được).

1. Tải **Eclipse Temurin 17 (LTS)** bản Windows x64 `.msi` tại https://adoptium.net
2. Cài như bình thường; nhớ đường dẫn, ví dụ `C:\Program Files\Eclipse Adoptium\jdk-17.0.x-hotspot`.

## 3. Android SDK

Cách dễ nhất là cài **Android Studio** (https://developer.android.com/studio), mở lần đầu cho nó tự tải SDK. Sau đó vào **More Actions → SDK Manager**:

- Tab **SDK Platforms**: tích **Android 15 (API 35)**.
- Tab **SDK Tools**: tích **Android SDK Build-Tools 35**, **Android SDK Platform-Tools**, **Android SDK Command-line Tools (latest)**.
- Bấm **Apply**. Không cần NDK (project không dùng Gradle build).

Đường dẫn SDK mặc định: `C:\Users\<tên>\AppData\Local\Android\Sdk`.

## 4. Chỉ cho Godot biết đường dẫn

**Editor → Editor Settings → Export → Android**:

- **Java SDK Path**: thư mục JDK 17 ở bước 2.
- **Android SDK Path**: thư mục SDK ở bước 3.
- **Debug Keystore**: để trống, Godot tự tạo khóa debug.

## 5. Xuất APK

1. **Project → Export…**, chọn preset **kingdomtiles**. Nếu còn dòng chữ đỏ, nó sẽ nói thiếu gì.
2. Bấm **Export Project…**, tích **Export With Debug**, lưu vào `build/KingdomTiles.apk` (thư mục `build/` không lên git).
   - **Tên file không được có dấu `:`** (hay `\ / * ? " < > |`): Windows không cho, bước ký APK sẽ báo lỗi "The filename, directory name, or volume label syntax is incorrect". Tên hiện trên điện thoại vẫn là "Kingdom Tiles : Rise Of Realms" (lấy từ `package/name`), chỉ tên file mới cần ngắn gọn.

Hoặc báo mình, mình chạy lệnh xuất giúp:

```bash
"C:/Users/MyPC/Desktop/Godot_v4.5.1-stable_win64_console.exe" --headless --path . --export-debug "kingdomtiles" build/KingdomTiles.apk
```

## 6. Cài lên điện thoại

**Cách 1, chép file:** chép `KingdomTiles.apk` sang điện thoại, mở nó, cho phép "Cài ứng dụng không rõ nguồn gốc" khi được hỏi.

**Cách 2, chạy thẳng từ Godot:** trên điện thoại bật **Tùy chọn nhà phát triển** (bấm 7 lần vào "Số hiệu bản tạo" trong Thông tin điện thoại) và **Gỡ lỗi USB**, cắm cáp, rồi bấm biểu tượng Android ở góc trên bên phải Godot (Remote Debug / One-click deploy).

## 7. Chạy thử trên điện thoại ảo (giả lập trên máy tính)

Máy đã có sẵn điện thoại ảo **KingdomTiles_Phone** (Pixel 7, Android 16, màn 1080×2400, dùng GPU máy tính). APK được xuất cho cả `arm64-v8a` (điện thoại thật) và `x86_64` (giả lập).

**Cách nhanh nhất:** chạy file `tools/android/run_emulator.bat` (bấm đúp). Script tự xuất APK, bật điện thoại ảo nếu chưa bật, chờ khởi động xong, cài và mở game. Lần đầu khởi động mất khoảng 1 phút; các lần sau nếu điện thoại ảo vẫn mở thì chỉ mất vài giây.

**Hoặc ngay trong Godot:** khi điện thoại ảo đang mở, góc trên bên phải Godot có biểu tượng Android (Remote Deploy). Bấm vào là Godot tự xuất, cài và chạy game, kèm log lỗi hiện trong tab Output của Godot.

**Thao tác trên giả lập:**
- Chuột = một ngón tay (bấm, kéo).
- Chụm hai ngón: giữ **Ctrl** rồi kéo chuột.
- Nút Back: nút ◁ trên thanh bên phải cửa sổ giả lập (hoặc phím Esc).
- Xoay ngang / dọc: nút xoay trên thanh bên phải (game luôn nằm ngang).
- Thông báo "Viewing full screen" của Android chỉ hiện lần đầu: bấm **Got it**.

Giả lập dùng card đồ họa máy tính nên chạy mượt hơn điện thoại yếu; vẫn nên thử lại trên máy thật trước khi phát hành.

## Ghi chú

- Bản debug chỉ để chơi thử. Bản phát hành (ký bằng khóa riêng, Google Play) làm ở M14.
- Save game trên điện thoại nằm trong bộ nhớ riêng của ứng dụng; gỡ app là mất save.
- Điện thoại cũ 32-bit cần tích thêm `armeabi-v7a` trong preset.
