import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
/// Konu fotoğraflarının dosya tarafı.
///
/// Veritabanında yalnızca **göreli** yol saklanıyor. iOS, uygulama klasörünün
/// tam yolunu her kurulumda ve yedekten dönüşte değiştiriyor; mutlak yol
/// saklayan uygulamalar güncellemeden sonra bütün görselleri kaybediyor.
/// Mutlak yol her okumada yeniden kuruluyor.
class PhotoStore {
  PhotoStore({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  /// Belge klasörü altındaki klasör adı.
  static const folder = 'konu_fotograflari';

  /// Kaydedilen görselin en uzun kenarı.
  ///
  /// Kitap sayfası okunabilsin diye yüksek, ama telefonun 4000 pikselik ham
  /// çıktısını saklamıyoruz: bir yıl boyunca yüzlerce fotoğraf ekleyen bir
  /// öğrencide bu, gigabaytlarca yer demek.
  static const maxDimension = 2000.0;
  static const quality = 82;

  final ImagePicker _picker;

  /// Kameradan ya da galeriden bir fotoğraf alır ve kalıcı klasöre kopyalar.
  ///
  /// Dönen değer veritabanına yazılacak göreli yol; kullanıcı vazgeçerse
  /// `null`.
  Future<String?> pick({required bool fromCamera}) async {
    final picked = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: maxDimension,
      maxHeight: maxDimension,
      imageQuality: quality,
    );
    if (picked == null) return null;

    final directory = await _directory();
    final name = '${DateTime.now().microsecondsSinceEpoch}'
        '${p.extension(picked.path).isEmpty ? '.jpg' : p.extension(picked.path)}';
    final target = File(p.join(directory.path, name));
    await target.writeAsBytes(await picked.readAsBytes());

    return p.join(folder, name);
  }

  /// Göreli yoldan okunabilir bir dosya üretir.
  Future<File> fileFor(String relativePath) async {
    final documents = await getApplicationDocumentsDirectory();
    return File(p.join(documents.path, relativePath));
  }

  /// Dosyayı siler. Dosya yoksa sessizce geçer: veritabanı satırı ile disk
  /// arasında tutarsızlık, kullanıcıya gösterilecek bir hata değil.
  Future<void> delete(String relativePath) async {
    try {
      final file = await fileFor(relativePath);
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      // Yoksayılıyor; satır zaten silinecek.
    }
  }

  /// Verilen yolların tamamını siler. Uygulama sıfırlanırken kullanılıyor.
  Future<void> deleteAll(Iterable<String> relativePaths) async {
    for (final path in relativePaths) {
      await delete(path);
    }
  }

  Future<Directory> _directory() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(documents.path, folder));
    if (!directory.existsSync()) await directory.create(recursive: true);
    return directory;
  }
}
