import 'package:flutter_test/flutter_test.dart';
import 'package:pocketmind/util/image_storage_helper.dart';

void main() {
  group('ImageStorageHelper.relativePathForUrl (内容寻址)', () {
    test('相同 URL + 相同扩展名 → 相同 relativePath (跨调用稳定)', () {
      const url = 'https://sns-img-bd.xhscdn.com/abc123.jpg';
      final a = ImageStorageHelper.relativePathForUrl(url, '.jpg');
      final b = ImageStorageHelper.relativePathForUrl(url, '.jpg');
      expect(a, b);
    });

    test('相同 URL + 不同扩展名 → 文件名 hash 部分相同,后缀不同', () {
      const url = 'https://example.com/img';
      final a = ImageStorageHelper.relativePathForUrl(url, '.jpg');
      final b = ImageStorageHelper.relativePathForUrl(url, '.webp');
      expect(a, isNot(b));
      // 取出文件名（去除目录和后缀）后,hash 部分应一致
      String hashOf(String path) =>
          path.split('/').last.replaceAll(RegExp(r'\.\w+$'), '');
      expect(hashOf(a), hashOf(b));
    });

    test('不同 URL → 不同 relativePath', () {
      final a = ImageStorageHelper.relativePathForUrl(
        'https://example.com/a.jpg',
        '.jpg',
      );
      final b = ImageStorageHelper.relativePathForUrl(
        'https://example.com/b.jpg',
        '.jpg',
      );
      expect(a, isNot(b));
    });

    test('扩展名为空时退化为 .jpg', () {
      final relativePath = ImageStorageHelper.relativePathForUrl(
        'https://example.com/no-ext-cdn',
        '',
      );
      expect(relativePath.endsWith('.jpg'), isTrue);
    });

    test('relativePath 始终位于 pocket_images/ 目录下', () {
      final relativePath = ImageStorageHelper.relativePathForUrl(
        'https://example.com/x.png',
        '.png',
      );
      expect(relativePath.startsWith('pocket_images/'), isTrue);
    });

    test('hash 长度固定为 32 位 hex (取自 sha256 前缀)', () {
      final relativePath = ImageStorageHelper.relativePathForUrl(
        'https://example.com/whatever',
        '.png',
      );
      final fileName = relativePath.split('/').last;
      final hashPart = fileName.replaceAll(RegExp(r'\.\w+$'), '');
      expect(hashPart.length, 32);
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(hashPart), isTrue);
    });
  });
}
