import 'package:hive_flutter/hive_flutter.dart';

class Branch {
  const Branch({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static Branch fromMap(Map<dynamic, dynamic> map) {
    return Branch(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      createdAt: DateTime.tryParse((map['createdAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}

class BranchRecord {
  const BranchRecord({
    required this.id,
    required this.branch,
  });

  final int id;
  final Branch branch;
}

class BranchRepository {
  static const String boxName = 'branches';

  Future<Box<Map>> openBox() async {
    if (!Hive.isBoxOpen(boxName)) {
      return Hive.openBox<Map>(boxName);
    }
    return Hive.box<Map>(boxName);
  }

  Future<List<Branch>> getAllBranches() async {
    final box = await openBox();
    final branches = box.values.map(Branch.fromMap).toList(growable: false);
    branches.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return branches;
  }

  Future<List<BranchRecord>> getAllBranchRecords() async {
    final box = await openBox();
    final records = box.keys
        .map((key) => BranchRecord(id: key as int, branch: Branch.fromMap(box.get(key)!)))
        .toList(growable: false);
    records.sort((a, b) => a.branch.name.toLowerCase().compareTo(b.branch.name.toLowerCase()));
    return records;
  }

  Future<Branch> addBranch(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Branch name is required.');
    }

    final box = await openBox();
    final existing = box.values
        .map(Branch.fromMap)
        .any((branch) => branch.name.toLowerCase() == trimmed.toLowerCase());
    if (existing) {
      throw StateError('Branch name already exists.');
    }

    final branch = Branch(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: trimmed,
      createdAt: DateTime.now(),
    );
    await box.add(branch.toMap());
    return branch;
  }

  Future<void> updateBranch(int key, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Branch name is required.');
    }
    final box = await openBox();
    final existing = box.get(key);
    if (existing == null) {
      return;
    }
    final current = Branch.fromMap(existing);
    final updated = Branch(
      id: current.id,
      name: trimmed,
      createdAt: current.createdAt,
    );
    await box.put(key, updated.toMap());
  }

  Future<void> deleteBranch(int key) async {
    final box = await openBox();
    await box.delete(key);
  }

  Future<Map<String, String>> branchNameMap() async {
    final branches = await getAllBranches();
    return {
      for (final branch in branches) branch.id: branch.name,
    };
  }
}
