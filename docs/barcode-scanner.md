# Barcode Scanner - StockEase

## Phạm vi

Barcode là chuỗi tùy chọn, tách khỏi SKU. Sản phẩm cũ không có trường này được đọc thành chuỗi rỗng; không cần migration hoặc backfill. Giữ database Firestore hiện tại, Authentication và luồng transaction nhập/xuất. Không gọi API tra cứu thông tin sản phẩm từ barcode.

## Cách dùng

1. **Thêm/Sửa sản phẩm:** nhập Barcode hoặc nhấn biểu tượng quét cạnh trường. Có thể bỏ trống hoặc xóa barcode. Lưu sản phẩm vẫn cần xác nhận và kết nối Firestore.
2. **Sản phẩm / Trang chủ → Scan Barcode:** hướng một mã vào khung. Nếu tìm thấy sản phẩm đang hoạt động trong kho của user hiện tại, mở Product Details.
3. **Không tìm thấy:** màn hình hiển thị `Product not found`. Chọn Thêm sản phẩm để mở form có barcode điền sẵn; SKU và các thông tin khác vẫn phải nhập riêng. Quét không tự tạo sản phẩm.
4. **Nhập kho / Xuất kho:** tại màn hình chọn sản phẩm, nhấn biểu tượng Scan Barcode cạnh ô tìm kiếm. Sản phẩm tìm thấy được chọn cho phiếu; màn hình hiển thị tên, SKU, barcode, tồn hiện tại và tồn dự kiến. Nhập số lượng rồi xác nhận giao dịch bằng luồng hiện có. Không cho xuất quá tồn.
5. **Camera lỗi hoặc bị từ chối quyền:** chọn Nhập mã thủ công. Có thể cấp lại Camera trong Cài đặt Android của StockEase, quay lại và chọn Thử lại camera. Không cần quyền thư viện ảnh.

## Tương thích và camera

- SDK kiểm tra tại máy: Flutter 3.47.5, Dart 3.13.4; Android minSdk 24, Java 17.
- `mobile_scanner 7.5.0` yêu cầu Dart >=3.7, Flutter >=3.29, tương thích SDK trên. Giữ ML Kit bundled mặc định để tránh tải model ở lần quét đầu.
- Chỉ bật EAN-13, EAN-8, UPC-A và Code 128; một kết quả cho mỗi phiên scanner. Khóa xử lý trước thao tác bất đồng bộ để ngăn pop/navigation lặp.
- Camera dừng khi nhập thủ công, ra nền hoặc trả kết quả; controller/subscription được giải phóng khi rời scanner. Flash chỉ bật khi camera báo hỗ trợ.
- Chuẩn hóa bằng trim ở hai đầu, giữ nguyên chữ hoa/thường và số 0. Tối đa 128 ký tự ASCII in được; không chấp nhận ký tự điều khiển.
- ML Kit có thể trả UPC-A 12 chữ số thành EAN-13 với số 0 đứng đầu. Hai dạng dùng chung định danh chống trùng và được tìm kiếm tương đương; trường barcode gốc vẫn giữ nguyên.

## Dữ liệu và Rules

Thêm `barcode` tùy chọn vào `users/{uid}/products/{id}`. Thêm chỉ mục giữ barcode duy nhất tại `users/{uid}/productBarcodes/{sha256(identity)}` với các trường `productId`, `barcode`. SHA-256 chỉ tạo document ID an toàn cho cả Code 128 có dấu `/`, không phải cơ chế xác thực.

Tạo/sửa/xóa ẩn sản phẩm cập nhật chỉ mục barcode và SKU trong transaction, đọc hết trước khi ghi. Rules kiểm tra liên kết hai chiều, định danh hash, UID, sản phẩm hoạt động và giải phóng mã cũ. Không cho tài khoản khác đọc/ghi hoặc chiếm barcode. Hai thao tác đồng thời không thể giữ cùng barcode cho hai sản phẩm. Lịch sử nhập/xuất giữ schema và logic cũ.

Tra cứu chỉ chạy dưới UID của service, bằng query barcode với `Source.server` và timeout 15 giây; không dùng cache trống để kết luận sản phẩm không tồn tại khi mất mạng. Không cần composite index mới.

**Phải áp dụng Rules cập nhật trước khi lưu barcode trên Firebase thật.** Dự án dùng chung SnapLearn thì đối chiếu và publish bản `firestore.merged.rules` phù hợp với Rules đang chạy; không publish `firestore.rules` đè mất các quyền của ứng dụng khác. Công việc này chỉ sửa Rules trong source và kiểm tra bằng Emulator; không tự deploy Rules hoặc ghi sản phẩm vào Firebase thật.

## File triển khai

| Nhóm | File |
| --- | --- |
| Model | `lib/models/product.dart`, `lib/models/product_barcode.dart` |
| Service | `lib/services/product_service.dart` |
| Scanner / kết quả | `lib/screens/barcode/barcode_scanner_screen.dart`, `barcode_lookup_screen.dart` |
| Sản phẩm | `lib/screens/products/product_form_screen.dart`, `product_list_screen.dart`, `product_details_screen.dart` |
| Nhập/xuất | `lib/screens/inventory/product_selection_sheet.dart`, `stock_movement_screen.dart` |
| Navigation | `lib/screens/dashboard_screen.dart`, `lib/screens/stock_shell.dart` |
| Android / dependency | `android/app/src/main/AndroidManifest.xml`, `pubspec.yaml`, `pubspec.lock` |
| Rules | `firestore.rules`, `firestore.merged.rules` |
| Test | `test/barcode_service_test.dart`, `test/barcode_scanner_test.dart`, `test/firestore_inventory_rules_test.mjs` |
| Hồi quy | Chữ ký save trong `test/purchase_price_form_test.dart`, `test/sample_product_service_test.dart`; bảo đảm phần tử nằm trong viewport trong `test/dashboard_navigation_test.dart` |
| Test phần cứng | `integration_test/barcode_device_test.dart`, `barcode_fixtures.dart` |

## Kiểm tra

Kết quả thực chạy ngày 09/11/2026:

- Toàn bộ **88 Flutter unit/widget test đạt**, bao gồm 14 test barcode mới và các test hồi quy hiện có.
- Hai bộ Rules đều đạt trên Firestore Emulator: **228 assertions tổng cộng**, gồm cả nhập/xuất sản phẩm có barcode, tranh chấp đồng thời và UPC-A/EAN-13 tương đương.
- `flutter analyze --no-pub`: **No issues found**.
- Build APK debug thành công: `build/app/outputs/flutter-apk/app-debug.apk`.
- Chưa chạy smoke test camera trên điện thoại: các lần kiểm tra ADB sau khi triển khai không tìm thấy điện thoại trước đó, chỉ có emulator offline. Camera/flash/quyền/vòng đời được kiểm tra bằng platform test double; chưa được xác nhận trên phần cứng thật.
- Chưa publish Rules và chưa ghi barcode/sản phẩm thử nghiệm vào Firebase thật.

```powershell
flutter test --no-pub
flutter analyze --no-pub
dart format --output=none --set-exit-if-changed lib test integration_test
flutter build apk --debug --no-pub
```

Test unit/widget kiểm tra dữ liệu cũ, số 0 đầu, UPC/EAN tương đương, barcode trùng, thay đổi đồng thời SKU/barcode, bỏ barcode, xóa ẩn và dùng lại mã, phân user, camera giả lập, từ chối quyền, flash, ra nền/khôi phục, chống phát hiện lặp, Product not found, thêm mới từ mã điền sẵn, mở chi tiết và Stock In/Out có xác nhận. Có kiểm tra màn hình nhỏ, xoay ngang và chữ lớn.

Rules Emulator dùng project demo local, không truy cập database thật:

```powershell
$env:FIRESTORE_EMULATOR_JAR = 'C:/path/to/cloud-firestore-emulator.jar'
$env:FIRESTORE_JAVA = 'C:/path/to/java.exe'
node test/firestore_inventory_rules_test.mjs
```

Smoke test Android là harness riêng, không khởi tạo Firebase. Trên thiết bị đã cấp Camera, chạy:

```powershell
flutter test integration_test/barcode_device_test.dart -d <device-id> --no-pub
```

Harness kiểm tra mở camera, flash nếu có, đọc bốn ảnh barcode tổng hợp bằng ML Kit native, nhập thủ công và rời màn hình. Ảnh test được nhúng trong code integration test, không đưa vào assets của app chính. Sau test cần chạy lại app chính bằng `flutter run` hoặc cài APK build từ `lib/main.dart`. Việc đọc ảnh tổng hợp không thay thế thử quét nhãn thật qua camera ở các điều kiện ánh sáng/khoảng cách khác nhau.

Tham khảo: [mobile_scanner](https://pub.dev/packages/mobile_scanner), [Firebase Rules hashing](https://firebase.google.com/docs/reference/rules/rules.hashing).
