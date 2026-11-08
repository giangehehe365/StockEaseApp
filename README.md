# StockEase

Ứng dụng Android quản lý kho cho cửa hàng nhỏ, phát triển bằng Flutter. Mốc đầu tiên gồm đăng ký và đăng nhập bằng email, đăng nhập Google, khôi phục phiên và đăng xuất bằng Firebase Authentication.

## Chạy trên Android

1. Dùng Flutter với Dart 3.13.4 trở lên và thiết bị Android API 24 trở lên.
2. Trong [Firebase Console](https://console.firebase.google.com/), thêm ứng dụng Android với package name `com.stockease.stockease`.
3. Tải cấu hình Firebase của ứng dụng và đặt tại `android/app/google-services.json`. Mỗi nhóm có thể dùng cấu hình Firebase riêng.
4. Trong Firebase Console, mở **Authentication → Sign-in method** và bật **Email/Password**.
5. Chạy các lệnh sau từ thư mục dự án.

```shell
flutter pub get
flutter run
```

Xem [hướng dẫn cấu hình Android](https://firebase.google.com/docs/android/setup) và [hướng dẫn xác thực bằng mật khẩu](https://firebase.google.com/docs/auth/flutter/password-auth) của Firebase.

### Bật đăng nhập Google

Thêm SHA-1 của khóa ký Android vào ứng dụng StockEase trong Firebase Console. Khi chạy debug, lấy SHA-1 bằng `./gradlew :app:signingReport` từ thư mục `android` (`.\gradlew.bat :app:signingReport` trên PowerShell). Bật nhà cung cấp **Google** trong **Authentication → Sign-in method**, sau đó tải lại `google-services.json` để tệp có thông tin OAuth và build lại ứng dụng.

## Kiểm tra Authentication

```shell
flutter analyze
flutter test
```

Trên thiết bị, đăng ký một email mới, đóng và mở lại ứng dụng để kiểm tra phiên, sau đó đăng xuất và đăng nhập lại. Thử thêm mật khẩu sai, email trùng và mất mạng. Màn hình sau đăng nhập hiện hiển thị email và nút đăng xuất.

Trên Pixel 7 hoặc thiết bị có Google Play Services, thử **Tiếp tục với Google**, hủy hộp chọn tài khoản, đăng nhập, mở lại ứng dụng, đăng xuất rồi chọn một tài khoản Google khác.

## Product Management

StockEase lưu sản phẩm trong `users/{uid}/products` và dùng `users/{uid}/productSkus` để giữ SKU duy nhất cho từng kho. SKU được bỏ khoảng trắng ở hai đầu và chuyển thành chữ hoa. Thao tác xóa ẩn sản phẩm và giải phóng SKU, đồng thời giữ ID và bản ghi sản phẩm cho lịch sử kho sau này. Thao tác lưu và xóa cần kết nối Firestore để hoàn tất transaction.

Sau khi đăng nhập, thanh điều hướng mở **Trang chủ**, **Sản phẩm** và **Hồ sơ**. Trang chủ tổng hợp từ danh sách sản phẩm đang hoạt động. Hồ sơ lưu tên hiển thị và tên cửa hàng tại `users/{uid}/stockease/profile`.

Trong bản debug, mở **Hồ sơ → Nạp dữ liệu mẫu** và xác nhận để nạp 20 sản phẩm vào kho hiện tại. SKU đang có sẽ được bỏ qua. Nếu có lỗi trong lúc nạp, có thể thử lại để tiếp tục với các SKU còn thiếu.

### Chuẩn bị Firestore

1. Mở **Firestore Database** trong Firebase Console của project đang dùng cho Android. Nếu chưa có database, tạo database mặc định.
2. Áp dụng các quy tắc trong `firestore.rules`. Nếu project dùng chung với SnapLearn, đối chiếu `firestore.merged.rules` với rules đang chạy rồi Publish bản đã gộp để giữ các thay đổi gần đây của cả hai ứng dụng. Bản rules mới cấp quyền cho hồ sơ StockEase và cho phép hai danh mục mới.
3. Chạy `flutter pub get`, sau đó `flutter run` và đăng nhập. Chọn **Sản phẩm** để vào kho.

### Kiểm thử CRUD

1. Dùng tài khoản mới và kiểm tra màn hình kho trống. Thêm sản phẩm với giá VND, số lượng và mức tồn tối thiểu hợp lệ.
2. Mở chi tiết và kiểm tra nhãn **Tồn kho thấp** khi số lượng nhỏ hơn hoặc bằng mức tối thiểu.
3. Thử thêm SKU trùng bằng chữ thường và chữ hoa. Kiểm tra các trường bắt buộc và số âm.
4. Sửa tên, SKU hoặc giá. Kiểm tra số lượng giữ nguyên. Thử đổi sang SKU của sản phẩm khác và kiểm tra thông báo lỗi.
5. Tắt rồi mở lại ứng dụng, kiểm tra dữ liệu còn. Đăng xuất và đăng nhập tài khoản thứ hai, xác nhận kho độc lập và có thể dùng cùng SKU.
6. Thử hủy rồi xác nhận xóa. Sản phẩm sẽ biến mất khỏi danh sách sau khi xác nhận. Có thể thêm lại cùng SKU.

## Nhập xuất kho

Áp dụng Firestore Rules mới trước khi thử. Với Firebase project dùng chung SnapLearn, đối chiếu `firestore.merged.rules` với rules đang chạy trước khi Publish. Không cần chỉnh sản phẩm cũ. Số lượng ban đầu vẫn là tồn đầu kỳ.

Trên **Trang chủ**, chọn **Nhập kho** hoặc **Xuất kho** rồi chọn sản phẩm. Bạn cũng có thể mở các thao tác này từ **Chi tiết sản phẩm**. Nhập số lượng nguyên dương, ghi chú nếu cần rồi xác nhận. Kết nối Firestore là bắt buộc để transaction cập nhật tồn và ghi lịch sử cùng lúc.

Mở **Lịch sử kho** trên Trang chủ để xem toàn bộ giao dịch hoặc **Lịch sử sản phẩm** trong Chi tiết. Lịch sử của sản phẩm đã ẩn vẫn xuất hiện trong lịch sử toàn kho. Dashboard và các màn hình sản phẩm cập nhật khi dữ liệu thay đổi.

Kịch bản demo với sản phẩm tồn 50: nhập 20 để được 70, xuất 15 để còn 55, rồi thử xuất 100 và xác nhận số lượng cùng lịch sử giữ nguyên. Đóng mở lại app và đăng nhập tài khoản khác để kiểm tra dữ liệu bền vững và tách biệt.

### Tìm kiếm và ngày giao dịch

Màn hình chọn sản phẩm tìm trực tiếp theo một phần tên hoặc SKU, không phân biệt hoa/thường. Khi xuất kho, bật **Chỉ còn hàng** để lọc sản phẩm có tồn lớn hơn 0. Danh sách sử dụng dữ liệu của tài khoản hiện tại từ `ProductService`, loại bỏ sản phẩm đã archived và lọc trên máy khi nhập từ khóa.

Phiếu nhập/xuất hiển thị SKU, tồn hiện tại và tồn dự kiến. **Ngày giao dịch** mặc định là thời điểm mở phiếu; chạm để chọn cả ngày và giờ bằng hai picker. Giao diện hiển thị giờ địa phương theo `dd/MM/yyyy HH:mm`, không chấp nhận thời điểm tương lai. Chọn giờ bằng biểu mẫu 24 giờ; hủy một trong hai picker sẽ giữ thời điểm cũ. Dialog xác nhận tóm tắt sản phẩm, số lượng, thời điểm, tồn dự kiến và ghi chú trước khi lưu.

Giao dịch mới bổ sung `movementId`, `sku`, `transactionDate` vào collection `users/{uid}/stockMovements` hiện có. `createdAt` vẫn là server timestamp tại thời điểm ghi hệ thống. Không đổi database, không migration hoặc sửa/xóa lịch sử cũ; bản ghi thiếu `transactionDate` sử dụng `createdAt`, thiếu cả hai hiển thị **Đang đồng bộ**. Lịch sử cũ chưa có SKU vẫn tìm được bằng tên.

Lịch sử sắp theo ngày giao dịch mới nhất, có tìm kiếm tên/SKU, lọc nhập/xuất và khoảng ngày bao gồm toàn bộ ngày bắt đầu/kết thúc. Chạm giao dịch để xem ghi chú, mã và thời điểm lưu. Chi tiết sản phẩm hiển thị ba giao dịch gần nhất và vẫn có nút mở toàn bộ lịch sử riêng.

**Cần áp dụng Rules cập nhật** trong `firestore.rules` hoặc bản gộp phù hợp trước khi dùng phiên bản này. Rules cũ sẽ từ chối các trường mới. Các file Rules chỉ được chỉnh trong source; chưa được deploy lên Firebase. Bộ kiểm tra ghép tồn kho/lịch sử và quyền tài khoản vẫn được giữ. Tham khảo cơ chế transaction và `getAfter()` trong [tài liệu Firebase](https://firebase.google.com/docs/firestore/manage-data/transactions).

### Kiểm thử Inventory

```powershell
flutter analyze --no-pub
flutter test --no-pub
```

Các test Inventory kiểm tra tìm tên/SKU, xóa từ khóa, lọc còn hàng, chọn ngày quá khứ, tồn dự kiến, validation, chống submit lặp, ghi ngày vào service, retry cùng mã không tăng tồn lần hai, lỗi commit, lọc lịch sử theo ngày và tương thích dữ liệu cũ. Có kiểm tra bố cục chọn sản phẩm khi bàn phím làm giảm chiều cao màn hình.

Kiểm thử Rules bằng Firestore Emulator đã cài sẵn, Java 21+ và Node.js 18+ (không cần npm dependency):

```powershell
$env:FIRESTORE_EMULATOR_JAR = 'C:/path/to/cloud-firestore-emulator.jar'
$env:FIRESTORE_JAVA = 'C:/path/to/jdk/bin/java.exe'
node test/firestore_inventory_rules_test.mjs
```

Script tự mở rồi đóng emulator cho từng bộ Rules, chỉ dùng project `demo-stockease-inventory`, dữ liệu tạm và cổng 8187; không truy cập Firebase thật. Có thể đổi cổng qua `FIRESTORE_TEST_PORT`. Script kiểm tra nhập/xuất hợp lệ, xuất quá tồn, ngày tương lai, ghi lệch tồn, ghi thiếu lịch sử/cập nhật sản phẩm, sản phẩm archived, quyền tài khoản, tính bất biến của lịch sử và đọc bản ghi cũ.

Vẫn cần kiểm tra thủ công trên Android: nhập/xuất với Firebase của nhóm, đóng/mở lại app, đăng xuất rồi đăng nhập tài khoản khác và mô phỏng mất mạng. Unit/widget test và emulator không thay thế kiểm tra vòng đời ứng dụng trên thiết bị.

### Báo cáo thay đổi Inventory (08/11/2026)

| File đã sửa/thêm | Nội dung |
| --- | --- |
| `lib/models/stock_movement.dart` | SKU, ngày giao dịch, fallback bản ghi cũ, định dạng và bộ lọc lịch sử |
| `lib/services/inventory_service.dart` | Ghi trường mới trong transaction, kiểm tra ngày và owner, retry theo mã giao dịch |
| `lib/screens/stock_shell.dart` | Kết nối bottom sheet chọn sản phẩm mới vào luồng hiện có |
| `lib/screens/inventory/product_selection_sheet.dart` (mới) | Tìm kiếm tức thì, xóa từ khóa, lọc còn hàng, empty state, cuộn khi bàn phím mở |
| `lib/screens/inventory/stock_movement_screen.dart` | Ngày/giờ, tồn dự kiến, validation, trạng thái nút và dialog tóm tắt |
| `lib/screens/inventory/inventory_history_screen.dart` | Tìm kiếm, loại giao dịch, khoảng ngày và chi tiết giao dịch |
| `lib/screens/products/product_details_screen.dart` | Ba giao dịch gần nhất của sản phẩm, loading/error/retry |
| `firestore.rules`, `firestore.merged.rules` | Cho phép và kiểm tra các trường mới, giữ ràng buộc ghi nguyên tử |
| `test/stock_movement_screen_test.dart` | Chọn ngày/giờ, preview, lỗi lưu, validation và chống submit lặp |
| `test/product_list_search_test.dart` | Cập nhật test double cho lịch sử trong chi tiết sản phẩm |
| `test/inventory_management_test.dart` (mới) | Tìm kiếm, bộ lọc, dữ liệu cũ, khoảng ngày, chi tiết và viewport nhỏ |
| `test/inventory_service_test.dart` (mới) | Kiểm tra callback transaction, ngày, snapshot sản phẩm, retry và lỗi commit |
| `test/firestore_inventory_rules_test.mjs` (mới) | Kiểm thử hai bộ Rules với dữ liệu demo trên Emulator |
| `README.md` | Hướng dẫn sử dụng, áp dụng Rules, kiểm thử và báo cáo |

Kết quả thực chạy: `flutter analyze --no-pub` không có issue; `flutter test --no-pub` qua **21 test**; script Firestore Emulator qua **84 assertions** trên cả hai bộ Rules; kiểm tra định dạng Dart không có file cần sửa. Chưa deploy Rules, chưa build/chạy app trên Android hoặc kiểm tra đóng/mở lại ứng dụng với Firebase thật.

## Dashboard tương tác

Toàn bộ diện tích các thẻ thống kê có thể nhấn, có hiệu ứng Material và mũi tên xem chi tiết. Các thẻ mở route mới với AppBar/Back, không thay đổi bộ lọc hoặc từ khóa đang dùng ở tab Sản phẩm.

| Thẻ / thao tác | Màn hình được tái sử dụng và trạng thái ban đầu |
| --- | --- |
| Tổng sản phẩm | Product List: toàn bộ sản phẩm đang hoạt động, tìm tên/SKU, tổng số sản phẩm |
| Tổng số lượng tồn | Product List: số lượng giảm dần, tổng tồn của danh sách hiển thị phía trên |
| Tồn kho thấp | Product List: `0 < quantity <= minStock`; có thể xóa bộ lọc |
| Hết hàng | Product List: `quantity == 0`, badge và nút Nhập thêm hàng |
| Giao dịch nhập kho | Inventory History: bộ lọc IN áp dụng ngay |
| Giao dịch xuất kho | Inventory History: bộ lọc OUT; khi rỗng hiển thị “Chưa có giao dịch xuất kho” |
| Sản phẩm trong Cần bổ sung hàng | Nhấn card mở Product Details; nút Nhập thêm hàng mở Stock In cho đúng sản phẩm |

Product List nhận `initialStockFilter`, `initialSort`, `showStockSummary` và `title`. Khi không truyền danh sách `products`, màn hình tự nghe `ProductService.watchProducts()` và có loading/error/retry. Tab Sản phẩm tiếp tục nhận danh sách từ StockShell. Cả hai đều sử dụng cùng service theo user hiện tại và loại trừ archived. Bộ lọc được khởi tạo một lần, không bị reset khi dữ liệu mới về. Tổng tồn trên màn hình tồn kho phản ánh danh sách sau search/filter; mỗi sản phẩm vẫn hiển thị đơn vị riêng.

Inventory History nhận `initialFilter`, giữ search và khoảng ngày hiện có, hiển thị số giao dịch và ghi chú ngắn trong danh sách. Tiêu đề thay đổi theo bộ lọc đang chọn. Chi tiết giao dịch dùng dialog hiện có. Dashboard tiếp tục tính thống kê từ dữ liệu thực tế, tách hết hàng khỏi tồn thấp. Sau CRUD hoặc nhập/xuất, các stream cập nhật danh sách và Dashboard.

Các file thay đổi trong đợt Dashboard:

- `lib/screens/dashboard_screen.dart`: callback cho sáu thẻ; ripple/mũi tên; thao tác bổ sung hàng.
- `lib/screens/stock_shell.dart`: mở route với filter/sort và tái sử dụng luồng Stock In.
- `lib/screens/products/product_list_screen.dart`: nhận trạng thái ban đầu, route có AppBar, stream và tổng tồn.
- `lib/screens/inventory/inventory_history_screen.dart`: bộ lọc ban đầu, tiêu đề, đếm giao dịch, empty state và ghi chú.
- `lib/widgets/product_card.dart`: mức tồn tối thiểu và nút Nhập thêm hàng.
- `test/dashboard_navigation_test.dart` (mới): kiểm tra sáu thẻ, Back, trạng thái tab, cập nhật dữ liệu, phân phạm vi user/archived, restock và màn hình nhỏ; loading/error/retry.
- `test/inventory_management_test.dart`: kiểm tra ghi chú trong đúng dialog sau khi danh sách cũng hiển thị ghi chú.
- `README.md`: hướng dẫn và báo cáo thay đổi.

Đợt này không sửa Authentication, service, database hoặc Firestore Rules. Các kiểm thử navigation dùng Firestore test double để chạy cả StockShell lẫn các màn hình thật; việc mô phỏng dữ liệu cập nhật không thay thế kiểm tra Firebase và nhập/xuất trên Android. Trường hợp Firebase còn dùng Rules cũ vẫn cần áp dụng Rules từ đợt Inventory trước.

Kết quả kiểm tra đợt Dashboard: **27 Flutter test đều đạt**, `flutter analyze --no-pub` báo **No issues found**, và `dart format --output=none --set-exit-if-changed` xác nhận cả 7 file Dart thay đổi đã đúng định dạng. Chưa chạy thử bản cập nhật Dashboard trên thiết bị Android thật/emulator Android.
