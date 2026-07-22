/// Purpose      : Unit tests for the Repository Layer's shared CRUD
///                behaviour, exercised through ProductRepository.
/// Author       : HMEOS Engineering
/// Version      : 1.0.0
/// Dependencies : flutter_test, sqflite_common_ffi,
///                core/database/database_helper.dart,
///                repositories/product_repository.dart,
///                models/product_model.dart
/// Description  : Since every concrete repository shares
///                BaseSqliteRepository's implementation,
///                ProductRepository stands in for all 11 — a create/
///                read/update/soft-delete/search/filter/exists/count
///                pass here exercises the same code path every other
///                repository uses. Uses
///                DatabaseHelper.forTesting() with an in-memory
///                sqflite_common_ffi database so this runs without a
///                device/emulator or path_provider.
/// Change History:
///   1.0.0 - SPR-DEP-003 - Initial creation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:hue_muse_shade_ai/core/database/database_helper.dart';
import 'package:hue_muse_shade_ai/models/product_model.dart';
import 'package:hue_muse_shade_ai/repositories/product_repository.dart';

Future<Database> _openTestDatabase() async {
  sqfliteFfiInit();
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      // singleInstance defaults to true in sqflite, keyed by path —
      // and inMemoryDatabasePath is the literal string ':memory:', so
      // without this every test file opening an in-memory database
      // this way (this file, database_helper_test.dart, and
      // widget_test_support.dart) shared one real connection when
      // flutter test ran them concurrently. See
      // widget_test_support.dart's _openTestDatabase for the full
      // writeup — same fix applied here for the same reason.
      singleInstance: false,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE Product_Master (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            product_code TEXT NOT NULL,
            category TEXT NOT NULL,
            base_type TEXT,
            description TEXT,
            is_active INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL DEFAULT (datetime('now')),
            updated_at TEXT NOT NULL DEFAULT (datetime('now'))
          )
        ''');
      },
    ),
  );
}

void main() {
  late Database db;
  late ProductRepository repository;

  setUp(() async {
    db = await _openTestDatabase();
    repository = ProductRepository(
      databaseHelper: DatabaseHelper.forTesting(db),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('ProductRepository (BaseSqliteRepository CRUD contract)', () {
    test('create() persists a record and assigns an id', () async {
      final ProductModel created = await repository.create(
        const ProductModel(
          name: 'Classic Nail Polish',
          productCode: 'NP-001',
          category: 'Nail Polish',
        ),
      );

      expect(created.id, isNotNull);
      expect(created.name, 'Classic Nail Polish');
    });

    test('readById() returns the created record', () async {
      final ProductModel created = await repository.create(
        const ProductModel(
          name: 'Matte Lipstick',
          productCode: 'LP-001',
          category: 'Lipstick',
        ),
      );

      final ProductModel? found = await repository.readById(created.id!);

      expect(found, isNotNull);
      expect(found!.productCode, 'LP-001');
    });

    test('update() modifies fields and persists them', () async {
      final ProductModel created = await repository.create(
        const ProductModel(
          name: 'Kajal',
          productCode: 'KJ-001',
          category: 'Kajal',
        ),
      );

      await repository.update(created.copyWith(description: 'Smudge-proof'));
      final ProductModel? updated = await repository.readById(created.id!);

      expect(updated!.description, 'Smudge-proof');
    });

    test('softDelete() hides the record from readAll() by default',
        () async {
      final ProductModel created = await repository.create(
        const ProductModel(
          name: 'Mascara',
          productCode: 'MS-001',
          category: 'Mascara',
        ),
      );

      final bool deleted = await repository.softDelete(created.id!);
      final List<ProductModel> active = await repository.readAll();
      final List<ProductModel> withInactive = await repository.readAll(
        includeInactive: true,
      );

      expect(deleted, isTrue);
      expect(active.where((ProductModel p) => p.id == created.id), isEmpty);
      expect(
        withInactive.where((ProductModel p) => p.id == created.id),
        isNotEmpty,
      );
    });

    test('search() matches by name substring', () async {
      await repository.create(
        const ProductModel(
          name: 'Ruby Red Nail Polish',
          productCode: 'NP-002',
          category: 'Nail Polish',
        ),
      );
      await repository.create(
        const ProductModel(
          name: 'Coral Blush',
          productCode: 'BL-001',
          category: 'Blush',
        ),
      );

      final List<ProductModel> results = await repository.search('Ruby');

      expect(results, hasLength(1));
      expect(results.first.productCode, 'NP-002');
    });

    test('filter() matches exact column value', () async {
      await repository.create(
        const ProductModel(
          name: 'Foundation A',
          productCode: 'FD-001',
          category: 'Foundation',
        ),
      );
      await repository.create(
        const ProductModel(
          name: 'Concealer A',
          productCode: 'CC-001',
          category: 'Concealer',
        ),
      );

      final List<ProductModel> results = await repository.findByCategory(
        'Foundation',
      );

      expect(results, hasLength(1));
      expect(results.first.category, 'Foundation');
    });

    test('exists() and count() reflect active rows only', () async {
      final ProductModel created = await repository.create(
        const ProductModel(
          name: 'Eyeliner',
          productCode: 'EL-001',
          category: 'Eyeliner',
        ),
      );

      expect(await repository.exists(created.id!), isTrue);
      expect(await repository.count(), 1);

      await repository.softDelete(created.id!);

      expect(await repository.exists(created.id!), isFalse);
      expect(await repository.count(), 0);
      expect(await repository.count(includeInactive: true), 1);
    });
  });
}
