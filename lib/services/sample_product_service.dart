import 'product_service.dart';

typedef _Sample = (String, String, String, int, int, int, String);

const _samples = <_Sample>[
  ('Coca-Cola 330 ml', 'BV001', 'Đồ uống', 10000, 50, 10, 'can'),
  ('Pepsi 330 ml', 'BV002', 'Đồ uống', 10000, 8, 10, 'can'),
  ('Nước suối Aquafina 500 ml', 'BV003', 'Đồ uống', 6000, 72, 12, 'bottle'),
  ('Trà xanh Không Độ 455 ml', 'BV004', 'Đồ uống', 12000, 24, 8, 'bottle'),
  ('Mì Hảo Hảo tôm chua cay', 'FD001', 'Thực phẩm', 4500, 100, 20, 'pack'),
  ('Gạo ST25 túi 1 kg', 'FD002', 'Thực phẩm', 38000, 15, 5, 'kg'),
  ('Nước mắm Nam Ngư 500 ml', 'FD003', 'Thực phẩm', 36000, 5, 6, 'bottle'),
  ('Cá hộp Ba Cô Gái 155 g', 'FD004', 'Thực phẩm', 22000, 18, 6, 'can'),
  ('Bánh Oreo vani 119,6 g', 'SN001', 'Đồ ăn vặt', 18000, 0, 10, 'pack'),
  ('Khoai tây Lay’s vị tự nhiên', 'SN002', 'Đồ ăn vặt', 12000, 5, 8, 'pack'),
  ('Bánh Choco Pie hộp 6 cái', 'SN003', 'Đồ ăn vặt', 34000, 18, 5, 'box'),
  ('Đậu phộng Tân Tân 55 g', 'SN004', 'Đồ ăn vặt', 12000, 16, 5, 'pack'),
  (
    'Kem đánh răng Colgate 180 g',
    'PC001',
    'Chăm sóc cá nhân',
    32000,
    25,
    5,
    'piece',
  ),
  (
    'Dầu gội Clear bạc hà 170 g',
    'PC002',
    'Chăm sóc cá nhân',
    59000,
    3,
    5,
    'bottle',
  ),
  (
    'Xà phòng Lifebuoy 90 g',
    'PC003',
    'Chăm sóc cá nhân',
    15000,
    20,
    6,
    'piece',
  ),
  ('Nước rửa chén Sunlight 750 g', 'HH001', 'Gia dụng', 31000, 12, 5, 'bottle'),
  ('Khăn giấy Bless You hộp 180 tờ', 'HH002', 'Gia dụng', 28000, 0, 4, 'box'),
  ('Túi rác tự hủy 3 cuộn', 'HH003', 'Gia dụng', 29000, 10, 3, 'pack'),
  (
    'Bút bi Thiên Long TL-027 xanh',
    'ST001',
    'Văn phòng phẩm',
    4000,
    48,
    12,
    'piece',
  ),
  ('Vở Hồng Hà 96 trang', 'ST002', 'Văn phòng phẩm', 12000, 7, 7, 'piece'),
];

Future<({int added, int existing, int failed})> seedSampleProducts(
  ProductService products,
) async {
  var added = 0;
  var existing = 0;
  var failed = 0;
  for (final (name, sku, category, price, quantity, minStock, unit)
      in _samples) {
    try {
      await products.save(
        name: name,
        sku: sku,
        category: category,
        price: price,
        quantity: quantity,
        minStock: minStock,
        unit: unit,
      );
      added++;
    } on DuplicateSkuException {
      existing++;
    } on Exception {
      failed++;
    }
  }
  return (added: added, existing: existing, failed: failed);
}
