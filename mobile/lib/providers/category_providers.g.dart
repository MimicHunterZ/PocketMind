// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// CategoryRepository Provider - 数据层
/// 提供 Isar 的具体实现（与 sync_providers.dart 中共用同一 provider，
/// 若已经 import sync_providers，此处直接复用 categoryRepositoryProvider）

@ProviderFor(isarCategoryRepository)
const isarCategoryRepositoryProvider = IsarCategoryRepositoryProvider._();

/// CategoryRepository Provider - 数据层
/// 提供 Isar 的具体实现（与 sync_providers.dart 中共用同一 provider，
/// 若已经 import sync_providers，此处直接复用 categoryRepositoryProvider）

final class IsarCategoryRepositoryProvider
    extends
        $FunctionalProvider<
          IsarCategoryRepository,
          IsarCategoryRepository,
          IsarCategoryRepository
        >
    with $Provider<IsarCategoryRepository> {
  /// CategoryRepository Provider - 数据层
  /// 提供 Isar 的具体实现（与 sync_providers.dart 中共用同一 provider，
  /// 若已经 import sync_providers，此处直接复用 categoryRepositoryProvider）
  const IsarCategoryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isarCategoryRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isarCategoryRepositoryHash();

  @$internal
  @override
  $ProviderElement<IsarCategoryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  IsarCategoryRepository create(Ref ref) {
    return isarCategoryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IsarCategoryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IsarCategoryRepository>(value),
    );
  }
}

String _$isarCategoryRepositoryHash() =>
    r'a422a5fb9e30465b12e07b603381d4fc05f5d22e';

/// CategoryService Provider - 业务层
/// 注入 LocalWriteCoordinator + SyncEngine，确保写操作走同步链路

@ProviderFor(categoryService)
const categoryServiceProvider = CategoryServiceProvider._();

/// CategoryService Provider - 业务层
/// 注入 LocalWriteCoordinator + SyncEngine，确保写操作走同步链路

final class CategoryServiceProvider
    extends
        $FunctionalProvider<CategoryService, CategoryService, CategoryService>
    with $Provider<CategoryService> {
  /// CategoryService Provider - 业务层
  /// 注入 LocalWriteCoordinator + SyncEngine，确保写操作走同步链路
  const CategoryServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoryServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoryServiceHash();

  @$internal
  @override
  $ProviderElement<CategoryService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CategoryService create(Ref ref) {
    return categoryService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CategoryService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CategoryService>(value),
    );
  }
}

String _$categoryServiceHash() => r'2a7f2eefe1b70703c0a5c1463c947642ba8f72fb';

/// 所有分类 Stream Provider - 自动监听数据库变化

@ProviderFor(allCategories)
const allCategoriesProvider = AllCategoriesProvider._();

/// 所有分类 Stream Provider - 自动监听数据库变化

final class AllCategoriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Category>>,
          List<Category>,
          Stream<List<Category>>
        >
    with $FutureModifier<List<Category>>, $StreamProvider<List<Category>> {
  /// 所有分类 Stream Provider - 自动监听数据库变化
  const AllCategoriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allCategoriesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allCategoriesHash();

  @$internal
  @override
  $StreamProviderElement<List<Category>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Category>> create(Ref ref) {
    return allCategories(ref);
  }
}

String _$allCategoriesHash() => r'faae0ff1fbcbbdb146c6a710f42392cb5373f14f';

/// 分类操作 Notifier - 封装所有分类相关的业务操作
///
/// UI 层应通过此 Notifier 进行分类的增删改操作，
/// 而不是直接调用 CategoryService

@ProviderFor(CategoryActions)
const categoryActionsProvider = CategoryActionsProvider._();

/// 分类操作 Notifier - 封装所有分类相关的业务操作
///
/// UI 层应通过此 Notifier 进行分类的增删改操作，
/// 而不是直接调用 CategoryService
final class CategoryActionsProvider
    extends $NotifierProvider<CategoryActions, void> {
  /// 分类操作 Notifier - 封装所有分类相关的业务操作
  ///
  /// UI 层应通过此 Notifier 进行分类的增删改操作，
  /// 而不是直接调用 CategoryService
  const CategoryActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'categoryActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$categoryActionsHash();

  @$internal
  @override
  CategoryActions create() => CategoryActions();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$categoryActionsHash() => r'd6cbcff8950b67cdbe1da0c8d787eee4d8f1769a';

/// 分类操作 Notifier - 封装所有分类相关的业务操作
///
/// UI 层应通过此 Notifier 进行分类的增删改操作，
/// 而不是直接调用 CategoryService

abstract class _$CategoryActions extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  void runBuild() {
    build();
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    element.handleValue(ref, null);
  }
}
