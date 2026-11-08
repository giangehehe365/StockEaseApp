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

## Currency Exchange Integration — Giá nhập USD/VND

`price` là **giá bán VND** của sản phẩm và giữ nguyên ý nghĩa đó. Tính năng này bổ sung giá nhập riêng vào form Thêm/Sửa hiện có; không đổi số lượng tồn khi chỉnh sửa, không tạo giao dịch kho hoặc thay đổi báo cáo dựa trên giá bán. Firestore vẫn là database hiện tại, không có migration/xóa dữ liệu cũ.

### REST API thực tế

Sử dụng [Frankfurter v2](https://frankfurter.dev/), package `http` và HTTP GET:

```http
GET https://api.frankfurter.dev/v2/rate/USD/VND
Accept: application/json
```

Endpoint đã được kiểm tra trực tiếp ngày 08/11/2026 và trả **HTTP 200**:

```json
{"date":"2026-11-08","base":"USD","quote":"VND","rate":25648}
```

Đây là snapshot phục vụ báo cáo, không phải tỷ giá được cố định trong ứng dụng. Code luôn đọc `rate` từ response. Service kiểm tra status 200, JSON object, `base == USD`, `quote == VND`, rate hữu hạn/lớn hơn 0 và ngày lịch hợp lệ. Timeout 12 giây; lỗi HTTP, JSON, mạng hoặc timeout có thông báo và Retry, không dùng tỷ giá dự phòng giả.

### Sử dụng và quy đổi

Mở **Thêm/Sửa sản phẩm → Giá nhập (Purchase Price)**. Phần này thu gọn được để giữ form gọn. Tiền tệ mặc định VND; không gọi API và tỷ giá lưu bằng 1. VND nhập số nguyên không có dấu phân cách nghìn. USD cho tối đa hai chữ số lẻ, dùng dấu chấm hoặc phẩy thập phân.

Chọn USD để lấy tỷ giá, xem ngày tỷ giá và giá nhập quy đổi. Thay đổi số tiền chỉ tính lại trên máy, không gọi API theo từng ký tự. Nút **Làm mới tỷ giá** gọi GET mới; khi đang tải hoặc có lỗi, form không cho lưu giá USD chưa hợp lệ. Có thể Retry hoặc chuyển về VND. Response đến muộn sau khi đổi tiền tệ/đóng form không được áp dụng.

```text
purchasePriceVnd = round(purchasePriceOriginal × exchangeRate)
```

Làm tròn đến đồng gần nhất; với số không âm, phần lẻ 0,5 làm tròn lên. Form hiển thị tiền Việt có dấu chấm phân cách nghìn và dialog xác nhận giá gốc, tỷ giá/ngày tỷ giá (USD), giá nhập VND, giá bán trước khi lưu. Tất cả số tiền được giới hạn theo mức tối đa hiện có của sản phẩm.

Khi Edit một giá nhập USD đã lưu, form khôi phục **tỷ giá lịch sử đã dùng**, không tự lấy tỷ giá mới làm thay đổi giá nhập. Muốn đổi tỷ giá thì nhấn Làm mới. Product Details hiển thị giá nhập VND, số tiền gốc, tiền tệ và thông tin tỷ giá đã lưu. Sản phẩm cũ hiển thị “Chưa khai báo”, vẫn sửa được khi bỏ trống giá nhập; không tự backfill hoặc ghi đè dữ liệu cũ.

### Các trường Firestore bổ sung

| Trường | Ý nghĩa |
| --- | --- |
| `purchasePriceVnd` | Giá nhập quy đổi, số nguyên VND |
| `purchasePriceOriginal` | Số tiền gốc người dùng nhập |
| `purchaseCurrency` | VND hoặc USD |
| `exchangeRate` | Tỷ giá thực đã dùng; bằng 1 với VND |
| `exchangeRateDate` | Chuỗi ngày API `YYYY-MM-DD` với USD; null với VND |

Các trường được lưu chung transaction lưu sản phẩm hiện có. Khi service không nhận giá nhập mới, những trường đã lưu được giữ nguyên. Rules chấp nhận sản phẩm cũ không có cả bộ trường; khi có giá nhập thì yêu cầu đủ bộ trường và kiểm tra tiền tệ, dấu số tiền, tỷ giá, phép làm tròn. Ràng buộc SKU/user và ghi tồn kho/lịch sử vẫn giữ nguyên.

**Trước khi dùng Add/Edit mới trên Firebase thật, phải áp dụng Rules cập nhật** từ `firestore.rules`, hoặc đối chiếu và áp dụng `firestore.merged.rules` nếu dùng chung Firebase với SnapLearn. Rules cũ sẽ từ chối các trường giá nhập mới. Chỉ source Rules được sửa trong đợt này; chưa deploy lên Firebase. Manifest Android đã có quyền INTERNET nên không cần thêm quyền.

### File thêm/sửa và kiểm thử

- Mới: `lib/models/exchange_rate.dart`, `lib/models/purchase_price.dart`, `lib/services/exchange_rate_service.dart`.
- Sửa: `lib/models/product.dart`, `lib/services/product_service.dart`, `lib/screens/products/product_form_screen.dart`, `lib/screens/products/product_details_screen.dart`.
- Dependency: `pubspec.yaml`, `pubspec.lock` — khai báo trực tiếp `http: ^1.6.0` từ dependency đã có trong cache.
- Rules: `firestore.rules`, `firestore.merged.rules`.
- Test mới: `test/exchange_rate_service_test.dart`, `test/purchase_price_form_test.dart`.
- Test cập nhật: `test/inventory_service_test.dart`, `test/sample_product_service_test.dart`, `test/firestore_inventory_rules_test.mjs`.
- Tài liệu: `README.md`.

Kiểm thử bao gồm GET đúng endpoint/header, HTTP lỗi, JSON/rate/cặp tiền/ngày sai, mạng/timeout, VND không gọi API, USD thành công, tính lại khi đổi giá, Refresh, chuyển tiền tệ khi request đang chạy, số âm/rỗng, xác nhận lưu, khôi phục giá nhập khi Edit, dữ liệu cũ, bảo toàn giá bán/tồn và lưu giá nhập cùng sản phẩm. Tỷ giá cố định trong test chỉ là fixture, không được sử dụng trong code chạy thật.

Emulator kiểm tra cả hai bộ Rules: tạo sản phẩm có giá nhập và SKU reservation, sửa USD/VND, từ chối quy đổi sai/âm/tỷ giá 0/tiền tệ khác/ngày sai/user khác, đọc lại dữ liệu và nhập kho sau khi thêm giá nhập. Chỉ dùng dữ liệu tạm của demo project; không truy cập database thật.

Chưa chạy app trên Android hoặc kiểm tra đóng/mở lại với Firebase thật. Để demo, sau khi Publish Rules: thêm giá nhập USD, xác nhận; đóng/mở app và vào Product Details/Edit để đối chiếu giá nhập/tỷ giá đã lưu; thử mất mạng và chuyển về VND. Authentication không bị chỉnh sửa.

Kết quả kiểm tra đợt Currency Exchange: **43 Flutter test đạt**; **130 assertions đạt trên Firestore Emulator** cho cả hai bộ Rules; `flutter analyze --no-pub` báo **No issues found**; kiểm tra Dart format xác nhận 11 file Dart thay đổi đúng định dạng. GET trực tiếp đến endpoint thật trả HTTP 200 với response đã ghi ở trên.

## Inventory Reports — Báo cáo kho

Trên **Trang chủ → Thao tác nhanh → Báo cáo kho**, mở màn hình **Inventory Reports**. Back trở về Dashboard, không thêm tab Bottom Navigation. Mặc định chọn **Tháng này** (từ ngày 1 đến hết ngày hiện tại); có Hôm nay, 7 ngày qua (gồm hôm nay và 6 ngày trước), hoặc Tùy chọn. Bộ lọc chỉ áp dụng cho thống kê/biểu đồ giao dịch; các phần tổng quan, cần nhập thêm và tồn kho theo sản phẩm luôn là dữ liệu hiện tại.

### Dữ liệu và công thức

Reports đọc `ProductService.watchProducts()` và `InventoryService.watchMovements()` của user hiện tại, rồi tổng hợp trên Flutter. Không có thao tác ghi khi chỉ xem hoặc làm mới báo cáo. Không đổi Authentication, Firestore schema/Rules, service nhập/xuất, dependency, backend hoặc API. Không cần composite index mới: chỉ sử dụng các query hiện có và lọc ngày ở phía Flutter.

| Chỉ số | Công thức / ý nghĩa |
| --- | --- |
| Tổng sản phẩm | Số product đang hoạt động của user; loại archived và trùng ID |
| Tổng số lượng tồn | Tổng `quantity` hiện tại; không cộng lại nhập/xuất vào quantity |
| Giá trị tồn kho | Tổng `quantity × purchasePriceVnd` của sản phẩm có giá nhập VND hợp lệ |
| Tồn thấp | `0 < quantity <= minStock` |
| Hết hàng | `quantity == 0`, không đếm vào tồn thấp |
| Tổng số lượng nhập / xuất | Tổng `quantity` của các movement IN / OUT trong kỳ |
| Số giao dịch nhập / xuất | Số bản ghi IN / OUT trong kỳ, khác tổng số lượng |
| Biến động ròng | Tổng số lượng nhập − tổng số lượng xuất; không phải tồn kho hiện tại |
| Bổ sung tối thiểu | `max(0, minStock − quantity)`; không phải dự báo |

`purchasePriceVnd` hợp lệ là số nguyên không âm trong giới hạn giá đã có. Reports đọc trực tiếp giá VND đã lưu, không gọi lại API tỷ giá hoặc dùng giá bán thay thế. Sản phẩm thiếu/sai giá nhập hiển thị **Chưa có giá nhập**, giá trị riêng **chưa xác định**. Tổng giá trị ghi rõ số sản phẩm có/thiếu giá nhập và chỉ là tổng phần đã biết. Giá nhập bằng 0 hợp lệ được phân biệt với thiếu giá nhập. Giá trị tiền và phép nhân dùng `BigInt` để tránh tràn/mất chính xác với số lớn; format VND bằng dấu chấm phân cách nghìn.

Tổng số lượng cộng các giá trị theo đơn vị riêng của từng sản phẩm, không quy đổi box/bottle/kg sang cùng một đơn vị. Lịch sử của sản phẩm đã archived vẫn được giữ trong báo cáo giao dịch; sản phẩm đó không xuất hiện trong báo cáo tồn kho hiện tại. Giao dịch được phân phạm vi user và loại trùng ID.

### Khoảng ngày và biểu đồ

Ngày giao dịch lấy từ `transactionDate`, fallback `createdAt` cho bản ghi cũ. Ngày được hiểu theo timezone của thiết bị, từ 00:00 ngày bắt đầu đến trước 00:00 ngày sau ngày kết thúc. Giao dịch không có cả hai ngày được đếm trong thông báo riêng và không gán ngày giả. Date Picker không cho khoảng đảo ngược hoặc ngày kết thúc ở tương lai.

Biểu đồ cột có hai series: xanh lá nhập, đỏ xuất; trục Y là số lượng, trục X tăng dần theo thời gian. Hôm nay/7 ngày/tháng này và custom không quá 62 ngày nhóm theo ngày, gồm cả ngày không giao dịch với giá trị 0. Khoảng dài hơn nhóm theo tháng; khoảng rất dài gộp nhiều tháng để giữ tối đa 24 nhóm. Tooltip giới hạn theo đúng khoảng ngày chọn. Vuốt ngang để xem các cột, chạm để xem tổng số lượng. Biểu đồ được dựng bằng widget Flutter, không thêm thư viện hoặc dependency. Khi không có giao dịch, hiển thị empty state.

Nhấn các thẻ số lượng/số giao dịch nhập hoặc xuất mở Inventory History hiện có, truyền đúng loại và khoảng ngày. Nhấn các chỉ số tổng sản phẩm/tồn kho hoặc nút xem tồn thấp/hết hàng mở Product List hiện có. Product Details và Stock In cũng được tái sử dụng từ các dòng sản phẩm cần bổ sung.

### Các danh sách và cập nhật

Danh sách cần nhập thêm đặt hết hàng lên trước rồi đến tồn thấp, hiển thị SKU, tồn hiện tại, minStock, badge và số bổ sung tối thiểu. Khi quantity bằng minStock, badge vẫn là tồn thấp và đề xuất bằng 0, có giải thích rõ. Có nút Nhập thêm hàng.

Báo cáo theo sản phẩm có tìm tên/SKU không phân biệt hoa/thường, lọc danh mục, sort số lượng hoặc giá trị tồn tăng/giảm. Giá trị chưa xác định luôn đứng sau giá trị đã biết khi sort giá trị, không giả lập bằng 0. Mỗi dòng có tên, SKU, danh mục, tồn, đơn vị, giá nhập, giá trị tồn và trạng thái; nhấn mở chi tiết.

Các stream cập nhật sau CRUD/Stock In/Out. Có nút làm mới trên AppBar và kéo xuống để gắn lại các stream. Lỗi hoặc chưa tải xong từng nguồn hiển thị trạng thái riêng, không biến thành các con số 0 giả; nguồn còn hoạt động vẫn hiển thị được. Làm mới/dữ liệu mới về không reset search, category, sort hoặc khoảng ngày đang chọn.

### File tạo/sửa trong đợt Reports

| Loại | File | Nội dung |
| --- | --- | --- |
| Mới | `lib/services/inventory_report_calculator.dart` | Bộ lọc ngày, tổng hợp hiện tại/giao dịch, nhóm biểu đồ, restock, sort giá trị và tiền BigInt |
| Mới | `lib/screens/inventory/inventory_reports_screen.dart` | Màn hình báo cáo, filter, danh sách, thống kê, trạng thái và refresh |
| Mới | `lib/widgets/stock_movement_chart.dart` | Biểu đồ cột hai series, trục, legend, tooltip và cuộn ngang |
| Mới | `test/inventory_report_calculator_test.dart` | Công thức, ngày/giờ, legacy, user/archive, chống trùng, giá trị lớn và sort |
| Mới | `test/inventory_reports_screen_test.dart` | Loading/error/empty/retry/refresh và chiều cao cột, font lớn |
| Sửa | `lib/models/product.dart` | Chỉ bổ sung đọc `isArchived`, `purchasePriceVnd` hợp lệ; không sửa cách ghi sản phẩm |
| Sửa | `lib/screens/dashboard_screen.dart` | Action Báo cáo kho |
| Sửa | `lib/screens/stock_shell.dart` | Route Reports dùng đúng user và các service hiện có |
| Sửa | `lib/screens/inventory/inventory_history_screen.dart` | Nhận khoảng ngày ban đầu khi mở từ Reports |
| Sửa | `test/dashboard_navigation_test.dart` | Reports → History/Details/Stock In, Back, ngày tùy chọn, dữ liệu cập nhật và màn hình nhỏ |
| Sửa | `README.md` | Hướng dẫn, công thức, giới hạn và báo cáo thay đổi |

### Kiểm thử và giới hạn

Kết quả thực chạy: **57 Flutter test đều đạt**, `flutter analyze --no-pub` **No issues found**; đã chạy `dart format .`. Kiểm thử mới gồm 9 trường hợp calculator và 5 trường hợp UI/navigation: tổng tồn/giá trị, thiếu giá nhập, tách tồn thấp/hết hàng, số lượng so với số giao dịch, ranh giới đầu/cuối ngày, UTC sang ngày địa phương, date presets/custom, legacy/missing date, không tính trùng, chart ngày/tháng, sort/filter, phạm vi user/archived, mở lại route, cập nhật dữ liệu, lỗi/empty/loading/refresh, màn hình 360×800 và biểu đồ 320px với text scale 1.8.

Chưa chạy bản cập nhật trên Android hoặc kiểm tra đóng/mở lại app với Firebase thật. Để kiểm tra demo: mở Reports, chọn Tháng này, đối chiếu với History; chọn khoảng cũ và xác nhận tổng quan tồn kho không đổi; nhập thêm hàng từ dòng cảnh báo rồi quay lại kiểm tra tồn/giá trị và biểu đồ. Đóng/mở lại app rồi kiểm tra lại, sau đó đăng nhập tài khoản khác để kiểm tra kho độc lập.

MVP đọc toàn bộ dữ liệu hiện có rồi tổng hợp trên máy; chưa có phân trang/tổng hợp server cho kho lớn. Hai stream sản phẩm và giao dịch có thể đến ở hai thời điểm khác nhau; báo cáo cập nhật theo từng stream, không phải snapshot đồng thời của cả database. Schema không lưu lịch sử giá nhập/tồn đầu kỳ đầy đủ để định giá tồn kho quá khứ, nên không suy diễn tồn kho lịch sử, lợi nhuận hoặc giá vốn. Không triển khai export, dự báo hoặc API mới trong đợt này.
