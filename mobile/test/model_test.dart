import 'package:flutter_test/flutter_test.dart';
import 'package:pocketmind/model/note.dart';
import 'package:pocketmind/model/category.dart';

void main() {
  group('Note Model Tests', () {
    test('Note 初始化测试', () {
      final note = Note();
      expect(note.id, null);
      expect(note.title, null);
      expect(note.content, null);
      expect(note.url, null);
      expect(note.categoryId, 1);
      expect(note.tags, isEmpty);
    });

    test('Note 带参数初始化测试', () {
      final note = Note()
        ..title = '测试标题'
        ..content = '测试内容'
        ..url = 'https://example.com'
        ..categoryId = 2
        ..tags = ['important'];

      expect(note.title, '测试标题');
      expect(note.content, '测试内容');
      expect(note.url, 'https://example.com');
      expect(note.categoryId, 2);
      expect(note.tags, ['important']);
    });

    test('Note 时间戳测试', () {
      final now = DateTime.now();
      final note = Note()..time = now;

      expect(note.time, now);
      expect(
        note.time?.isBefore(DateTime.now().add(Duration(seconds: 1))),
        true,
      );
    });

    test('Note 创建链接关系测试', () {
      final note = Note();
      expect(note.category, isNotNull);
    });

    test('Note 分类ID默认值测试', () {
      final note = Note();
      expect(note.categoryId, equals(1)); // 默认为 home 分类
    });

    test('Note 空内容测试', () {
      final note = Note()
        ..title = null
        ..content = ''
        ..url = null;

      expect(note.title, null);
      expect(note.content, '');
      expect(note.url, null);
    });

    test('Note URL 边界测试', () {
      final note = Note();

      // 有效 URL
      note.url = 'https://example.com';
      expect(note.url, 'https://example.com');

      // 相对 URL
      note.url = '/path/to/resource';
      expect(note.url, '/path/to/resource');

      // 空 URL
      note.url = '';
      expect(note.url, '');
    });
  });

  group('Category Model Tests', () {
    test('Category 初始化测试', () {
      final category = Category()..name = '日常';

      expect(category.id, null);
      expect(category.name, '日常');
      expect(category.description, null);
      expect(category.createdTime, null);
    });

    test('Category 带描述初始化测试', () {
      final category = Category()
        ..name = '工作'
        ..description = '工作相关的笔记';

      expect(category.name, '工作');
      expect(category.description, '工作相关的笔记');
    });

    test('Category 创建时间测试', () {
      final now = DateTime.now();
      final category = Category()
        ..name = '学习'
        ..createdTime = now;

      expect(category.createdTime, now);
    });

    test('Category 名称唯一性约束（模型层）', () {
      final category1 = Category()..name = '项目';
      final category2 = Category()..name = '项目';

      expect(category1.name, category2.name);
      // 实际的唯一性约束由数据库层检查
    });

    test('Category 长名称测试', () {
      final longName = 'A' * 100;
      final category = Category()..name = longName;

      expect(category.name, longName);
    });

    test('Category 特殊字符名称测试', () {
      final category = Category()
        ..name = '特殊分类 @#\$%'
        ..description = '带有特殊字符\n的描述';

      expect(category.name, '特殊分类 @#\$%');
      expect(category.description?.contains('\n'), true);
    });

    test('Category 空字符串测试', () {
      final category = Category()
        ..name = ''
        ..description = '';

      expect(category.name, '');
      expect(category.description, '');
    });
  });

  group('Note 和 Category 关系测试', () {
    test('Note 链接到 Category', () {
      final note = Note()
        ..title = '笔记'
        ..categoryId = 5;

      final category = Category()..name = '分类';

      expect(note.categoryId, 5);
      expect(category.name, '分类');
    });

    test('多个 Note 关联同一 Category', () {
      final note1 = Note()
        ..title = '笔记1'
        ..categoryId = 1;

      final note2 = Note()
        ..title = '笔记2'
        ..categoryId = 1;

      expect(note1.categoryId, note2.categoryId);
    });
  });

  group('Note 字段长度和边界测试', () {
    test('Note 标题长度边界', () {
      final longTitle = 'T' * 1000;
      final note = Note()..title = longTitle;

      expect(note.title, longTitle);
      expect(note.title?.length, 1000);
    });

    test('Note 内容长度边界', () {
      final longContent = 'C' * 10000;
      final note = Note()..content = longContent;

      expect(note.content, longContent);
      expect(note.content?.length, 10000);
    });

    test('Note 多行内容', () {
      final multilineContent = '''
        第一行
        第二行
        第三行
      ''';
      final note = Note()..content = multilineContent;

      expect(note.content, contains('第一行'));
      expect(note.content, contains('第二行'));
      expect(note.content, contains('第三行'));
    });
  });

  group('Note tags 字段测试', () {
    test('单个 tag', () {
      final note = Note()..tags = ['important'];
      expect(note.tags, ['important']);
    });

    test('tags 为空列表', () {
      final note = Note();
      expect(note.tags, isEmpty);
    });

    test('多个 tag', () {
      final note = Note()..tags = ['tag1', 'tag2'];
      expect(note.tags, ['tag1', 'tag2']);
    });

    test('tag 包含特殊字符', () {
      final note = Note()..tags = ['tag-with-dash_and_underscore'];
      expect(note.tags, ['tag-with-dash_and_underscore']);
    });
  });
}
