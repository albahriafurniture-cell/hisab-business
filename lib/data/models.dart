// Hisab Business data models + hand-written Hive TypeAdapters (no codegen).
// typeIds 0..15 are reserved as documented in PROJECT_STATUS.md.

import 'package:hive/hive.dart';

// ------------------------------------------------------------------ business
class BusinessProfile {
  final String id;
  String name;
  String category;
  String phone;
  String address;
  String ownerName;
  final DateTime createdAt;

  BusinessProfile({
    required this.id,
    required this.name,
    this.category = '',
    this.phone = '',
    this.address = '',
    this.ownerName = '',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'phone': phone,
        'address': address,
        'ownerName': ownerName,
        'createdAt': createdAt.toIso8601String(),
      };

  factory BusinessProfile.fromJson(Map<String, dynamic> j) => BusinessProfile(
        id: j['id'] as String,
        name: j['name'] as String,
        category: j['category'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        address: j['address'] as String? ?? '',
        ownerName: j['ownerName'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class BusinessProfileAdapter extends TypeAdapter<BusinessProfile> {
  @override
  final int typeId = 0;

  @override
  BusinessProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BusinessProfile(
      id: fields[0] as String,
      name: fields[1] as String,
      category: fields[2] as String,
      phone: fields[3] as String,
      address: fields[4] as String,
      ownerName: fields[5] as String,
      createdAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, BusinessProfile obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.phone)
      ..writeByte(4)
      ..write(obj.address)
      ..writeByte(5)
      ..write(obj.ownerName)
      ..writeByte(6)
      ..write(obj.createdAt);
  }
}

// --------------------------------------------------------------------- party
class Party {
  final String id;
  String name;
  String phone;
  String address;
  String kind; // 'customer' | 'supplier'
  String photoPath;
  String notes;
  bool archived;
  final DateTime createdAt;
  DateTime updatedAt;

  Party({
    required this.id,
    required this.name,
    this.phone = '',
    this.address = '',
    this.kind = 'customer',
    this.photoPath = '',
    this.notes = '',
    this.archived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'kind': kind,
        'photoPath': photoPath,
        'notes': notes,
        'archived': archived,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Party.fromJson(Map<String, dynamic> j) => Party(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String? ?? '',
        address: j['address'] as String? ?? '',
        kind: j['kind'] as String? ?? 'customer',
        photoPath: j['photoPath'] as String? ?? '',
        notes: j['notes'] as String? ?? '',
        archived: j['archived'] as bool? ?? false,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

class PartyAdapter extends TypeAdapter<Party> {
  @override
  final int typeId = 1;

  @override
  Party read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Party(
      id: fields[0] as String,
      name: fields[1] as String,
      phone: fields[2] as String,
      address: fields[3] as String,
      kind: fields[4] as String,
      photoPath: fields[5] as String,
      notes: fields[6] as String,
      archived: fields[7] as bool,
      createdAt: fields[8] as DateTime,
      updatedAt: fields[9] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Party obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.phone)
      ..writeByte(3)
      ..write(obj.address)
      ..writeByte(4)
      ..write(obj.kind)
      ..writeByte(5)
      ..write(obj.photoPath)
      ..writeByte(6)
      ..write(obj.notes)
      ..writeByte(7)
      ..write(obj.archived)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.updatedAt);
  }
}

// ---------------------------------------------------------------- khata entry
class KhataEntry {
  final String id;
  String partyId;
  String direction; // 'gave' | 'got'
  double amount;
  DateTime date;
  String detail;
  String photoPath;
  final DateTime createdAt;

  KhataEntry({
    required this.id,
    required this.partyId,
    required this.direction,
    required this.amount,
    required this.date,
    this.detail = '',
    this.photoPath = '',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'partyId': partyId,
        'direction': direction,
        'amount': amount,
        'date': date.toIso8601String(),
        'detail': detail,
        'photoPath': photoPath,
        'createdAt': createdAt.toIso8601String(),
      };

  factory KhataEntry.fromJson(Map<String, dynamic> j) => KhataEntry(
        id: j['id'] as String,
        partyId: j['partyId'] as String,
        direction: j['direction'] as String,
        amount: (j['amount'] as num).toDouble(),
        date: DateTime.parse(j['date'] as String),
        detail: j['detail'] as String? ?? '',
        photoPath: j['photoPath'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class KhataEntryAdapter extends TypeAdapter<KhataEntry> {
  @override
  final int typeId = 2;

  @override
  KhataEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return KhataEntry(
      id: fields[0] as String,
      partyId: fields[1] as String,
      direction: fields[2] as String,
      amount: fields[3] as double,
      date: fields[4] as DateTime,
      detail: fields[5] as String,
      photoPath: fields[6] as String,
      createdAt: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, KhataEntry obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.partyId)
      ..writeByte(2)
      ..write(obj.direction)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.detail)
      ..writeByte(6)
      ..write(obj.photoPath)
      ..writeByte(7)
      ..write(obj.createdAt);
  }
}

// ------------------------------------------------------------------ cash entry
class CashEntry {
  final String id;
  String direction; // 'in' | 'out'
  double amount;
  DateTime date;
  String category;
  String partyId;
  String detail;
  String photoPath;
  final DateTime createdAt;

  CashEntry({
    required this.id,
    required this.direction,
    required this.amount,
    required this.date,
    this.category = '',
    this.partyId = '',
    this.detail = '',
    this.photoPath = '',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'direction': direction,
        'amount': amount,
        'date': date.toIso8601String(),
        'category': category,
        'partyId': partyId,
        'detail': detail,
        'photoPath': photoPath,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CashEntry.fromJson(Map<String, dynamic> j) => CashEntry(
        id: j['id'] as String,
        direction: j['direction'] as String,
        amount: (j['amount'] as num).toDouble(),
        date: DateTime.parse(j['date'] as String),
        category: j['category'] as String? ?? '',
        partyId: j['partyId'] as String? ?? '',
        detail: j['detail'] as String? ?? '',
        photoPath: j['photoPath'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class CashEntryAdapter extends TypeAdapter<CashEntry> {
  @override
  final int typeId = 3;

  @override
  CashEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CashEntry(
      id: fields[0] as String,
      direction: fields[1] as String,
      amount: fields[2] as double,
      date: fields[3] as DateTime,
      category: fields[4] as String,
      partyId: fields[5] as String,
      detail: fields[6] as String,
      photoPath: fields[7] as String,
      createdAt: fields[8] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CashEntry obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.direction)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.partyId)
      ..writeByte(6)
      ..write(obj.detail)
      ..writeByte(7)
      ..write(obj.photoPath)
      ..writeByte(8)
      ..write(obj.createdAt);
  }
}
// ------------------------------------------------------- expense category
class ExpenseCategory {
  final String id;
  String name;
  String iconKey;
  int color; // ARGB

  ExpenseCategory({
    required this.id,
    required this.name,
    this.iconKey = 'other',
    this.color = 0xFF94A3B8,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconKey': iconKey,
        'color': color,
      };

  factory ExpenseCategory.fromJson(Map<String, dynamic> j) =>
      ExpenseCategory(
        id: j['id'] as String,
        name: j['name'] as String,
        iconKey: j['iconKey'] as String? ?? 'other',
        color: j['color'] as int? ?? 0xFF94A3B8,
      );
}

class ExpenseCategoryAdapter extends TypeAdapter<ExpenseCategory> {
  @override
  final int typeId = 4;

  @override
  ExpenseCategory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExpenseCategory(
      id: fields[0] as String,
      name: fields[1] as String,
      iconKey: fields[2] as String,
      color: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ExpenseCategory obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.iconKey)
      ..writeByte(3)
      ..write(obj.color);
  }
}

// ---------------------------------------------------------- expense entry
class ExpenseEntry {
  final String id;
  String categoryId;
  double amount;
  DateTime date;
  String detail;
  String photoPath;
  final DateTime createdAt;

  ExpenseEntry({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.date,
    this.detail = '',
    this.photoPath = '',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoryId': categoryId,
        'amount': amount,
        'date': date.toIso8601String(),
        'detail': detail,
        'photoPath': photoPath,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ExpenseEntry.fromJson(Map<String, dynamic> j) => ExpenseEntry(
        id: j['id'] as String,
        categoryId: j['categoryId'] as String,
        amount: (j['amount'] as num).toDouble(),
        date: DateTime.parse(j['date'] as String),
        detail: j['detail'] as String? ?? '',
        photoPath: j['photoPath'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class ExpenseEntryAdapter extends TypeAdapter<ExpenseEntry> {
  @override
  final int typeId = 5;

  @override
  ExpenseEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExpenseEntry(
      id: fields[0] as String,
      categoryId: fields[1] as String,
      amount: fields[2] as double,
      date: fields[3] as DateTime,
      detail: fields[4] as String,
      photoPath: fields[5] as String,
      createdAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ExpenseEntry obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.categoryId)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.detail)
      ..writeByte(5)
      ..write(obj.photoPath)
      ..writeByte(6)
      ..write(obj.createdAt);
  }
}

// ----------------------------------------------------------------- stock item
class StockItem {
  final String id;
  String name;
  String unit;
  double buyPrice;
  double sellPrice;
  String barcode;
  String photoPath;
  double? lowStockAt;
  final DateTime createdAt;
  DateTime updatedAt;

  StockItem({
    required this.id,
    required this.name,
    this.unit = 'pcs',
    this.buyPrice = 0,
    this.sellPrice = 0,
    this.barcode = '',
    this.photoPath = '',
    this.lowStockAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'unit': unit,
        'buyPrice': buyPrice,
        'sellPrice': sellPrice,
        'barcode': barcode,
        'photoPath': photoPath,
        'lowStockAt': lowStockAt,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory StockItem.fromJson(Map<String, dynamic> j) => StockItem(
        id: j['id'] as String,
        name: j['name'] as String,
        unit: j['unit'] as String? ?? 'pcs',
        buyPrice: (j['buyPrice'] as num? ?? 0).toDouble(),
        sellPrice: (j['sellPrice'] as num? ?? 0).toDouble(),
        barcode: j['barcode'] as String? ?? '',
        photoPath: j['photoPath'] as String? ?? '',
        lowStockAt: (j['lowStockAt'] as num?)?.toDouble(),
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

class StockItemAdapter extends TypeAdapter<StockItem> {
  @override
  final int typeId = 6;

  @override
  StockItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StockItem(
      id: fields[0] as String,
      name: fields[1] as String,
      unit: fields[2] as String,
      buyPrice: fields[3] as double,
      sellPrice: fields[4] as double,
      barcode: fields[5] as String,
      photoPath: fields[6] as String,
      lowStockAt: fields[7] as double?,
      createdAt: fields[8] as DateTime,
      updatedAt: fields[9] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, StockItem obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.unit)
      ..writeByte(3)
      ..write(obj.buyPrice)
      ..writeByte(4)
      ..write(obj.sellPrice)
      ..writeByte(5)
      ..write(obj.barcode)
      ..writeByte(6)
      ..write(obj.photoPath)
      ..writeByte(7)
      ..write(obj.lowStockAt)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.updatedAt);
  }
}

// ------------------------------------------------------------ stock movement
class StockMovement {
  final String id;
  String itemId;
  String direction; // 'in' | 'out'
  double qty;
  double rate;
  String partyId;
  String billNo;
  DateTime date;
  String note;
  final DateTime createdAt;

  StockMovement({
    required this.id,
    required this.itemId,
    required this.direction,
    required this.qty,
    this.rate = 0,
    this.partyId = '',
    this.billNo = '',
    required this.date,
    this.note = '',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'itemId': itemId,
        'direction': direction,
        'qty': qty,
        'rate': rate,
        'partyId': partyId,
        'billNo': billNo,
        'date': date.toIso8601String(),
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory StockMovement.fromJson(Map<String, dynamic> j) => StockMovement(
        id: j['id'] as String,
        itemId: j['itemId'] as String,
        direction: j['direction'] as String,
        qty: (j['qty'] as num).toDouble(),
        rate: (j['rate'] as num? ?? 0).toDouble(),
        partyId: j['partyId'] as String? ?? '',
        billNo: j['billNo'] as String? ?? '',
        date: DateTime.parse(j['date'] as String),
        note: j['note'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class StockMovementAdapter extends TypeAdapter<StockMovement> {
  @override
  final int typeId = 7;

  @override
  StockMovement read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StockMovement(
      id: fields[0] as String,
      itemId: fields[1] as String,
      direction: fields[2] as String,
      qty: fields[3] as double,
      rate: fields[4] as double,
      partyId: fields[5] as String,
      billNo: fields[6] as String,
      date: fields[7] as DateTime,
      note: fields[8] as String,
      createdAt: fields[9] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, StockMovement obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.itemId)
      ..writeByte(2)
      ..write(obj.direction)
      ..writeByte(3)
      ..write(obj.qty)
      ..writeByte(4)
      ..write(obj.rate)
      ..writeByte(5)
      ..write(obj.partyId)
      ..writeByte(6)
      ..write(obj.billNo)
      ..writeByte(7)
      ..write(obj.date)
      ..writeByte(8)
      ..write(obj.note)
      ..writeByte(9)
      ..write(obj.createdAt);
  }
}

// -------------------------------------------------------------- staff member
class StaffMember {
  final String id;
  String name;
  String phone;
  String role;
  double monthlySalary;
  String photoPath;
  bool active;
  final DateTime joinedAt;

  StaffMember({
    required this.id,
    required this.name,
    this.phone = '',
    this.role = '',
    this.monthlySalary = 0,
    this.photoPath = '',
    this.active = true,
    required this.joinedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'role': role,
        'monthlySalary': monthlySalary,
        'photoPath': photoPath,
        'active': active,
        'joinedAt': joinedAt.toIso8601String(),
      };

  factory StaffMember.fromJson(Map<String, dynamic> j) => StaffMember(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String? ?? '',
        role: j['role'] as String? ?? '',
        monthlySalary: (j['monthlySalary'] as num? ?? 0).toDouble(),
        photoPath: j['photoPath'] as String? ?? '',
        active: j['active'] as bool? ?? true,
        joinedAt: DateTime.parse(j['joinedAt'] as String),
      );
}

class StaffMemberAdapter extends TypeAdapter<StaffMember> {
  @override
  final int typeId = 8;

  @override
  StaffMember read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StaffMember(
      id: fields[0] as String,
      name: fields[1] as String,
      phone: fields[2] as String,
      role: fields[3] as String,
      monthlySalary: fields[4] as double,
      photoPath: fields[5] as String,
      active: fields[6] as bool,
      joinedAt: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, StaffMember obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.phone)
      ..writeByte(3)
      ..write(obj.role)
      ..writeByte(4)
      ..write(obj.monthlySalary)
      ..writeByte(5)
      ..write(obj.photoPath)
      ..writeByte(6)
      ..write(obj.active)
      ..writeByte(7)
      ..write(obj.joinedAt);
  }
}

// ---------------------------------------------------------- attendance record
class AttendanceRecord {
  final String id;
  String staffId;
  DateTime date;
  String status; // 'present' | 'absent' | 'half'

  AttendanceRecord({
    required this.id,
    required this.staffId,
    required this.date,
    this.status = 'present',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'staffId': staffId,
        'date': date.toIso8601String(),
        'status': status,
      };

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) =>
      AttendanceRecord(
        id: j['id'] as String,
        staffId: j['staffId'] as String,
        date: DateTime.parse(j['date'] as String),
        status: j['status'] as String? ?? 'present',
      );
}

class AttendanceRecordAdapter extends TypeAdapter<AttendanceRecord> {
  @override
  final int typeId = 9;

  @override
  AttendanceRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AttendanceRecord(
      id: fields[0] as String,
      staffId: fields[1] as String,
      date: fields[2] as DateTime,
      status: fields[3] as String,
    );
  }

  @override
  void write(BinaryWriter writer, AttendanceRecord obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.staffId)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.status);
  }
}

// ------------------------------------------------------------- salary payment
class SalaryPayment {
  final String id;
  String staffId;
  double amount;
  DateTime date;
  String kind; // 'salary' | 'advance' | 'bonus'
  String note;

  SalaryPayment({
    required this.id,
    required this.staffId,
    required this.amount,
    required this.date,
    this.kind = 'salary',
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'staffId': staffId,
        'amount': amount,
        'date': date.toIso8601String(),
        'kind': kind,
        'note': note,
      };

  factory SalaryPayment.fromJson(Map<String, dynamic> j) => SalaryPayment(
        id: j['id'] as String,
        staffId: j['staffId'] as String,
        amount: (j['amount'] as num).toDouble(),
        date: DateTime.parse(j['date'] as String),
        kind: j['kind'] as String? ?? 'salary',
        note: j['note'] as String? ?? '',
      );
}

class SalaryPaymentAdapter extends TypeAdapter<SalaryPayment> {
  @override
  final int typeId = 10;

  @override
  SalaryPayment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SalaryPayment(
      id: fields[0] as String,
      staffId: fields[1] as String,
      amount: fields[2] as double,
      date: fields[3] as DateTime,
      kind: fields[4] as String,
      note: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, SalaryPayment obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.staffId)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.kind)
      ..writeByte(5)
      ..write(obj.note);
  }
}
// ------------------------------------------------------------------ bill item
/// Embedded in [Bill] — never stored in its own box.
class BillItem {
  String itemId;
  String name;
  double qty;
  double rate;
  double total;

  BillItem({
    required this.itemId,
    required this.name,
    required this.qty,
    required this.rate,
    required this.total,
  });

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'name': name,
        'qty': qty,
        'rate': rate,
        'total': total,
      };

  factory BillItem.fromJson(Map<String, dynamic> j) => BillItem(
        itemId: j['itemId'] as String,
        name: j['name'] as String,
        qty: (j['qty'] as num).toDouble(),
        rate: (j['rate'] as num).toDouble(),
        total: (j['total'] as num).toDouble(),
      );
}

class BillItemAdapter extends TypeAdapter<BillItem> {
  @override
  final int typeId = 11;

  @override
  BillItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BillItem(
      itemId: fields[0] as String,
      name: fields[1] as String,
      qty: fields[2] as double,
      rate: fields[3] as double,
      total: fields[4] as double,
    );
  }

  @override
  void write(BinaryWriter writer, BillItem obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.itemId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.qty)
      ..writeByte(3)
      ..write(obj.rate)
      ..writeByte(4)
      ..write(obj.total);
  }
}

// ------------------------------------------------------------------------ bill
class Bill {
  final String id;
  String billNo;
  String partyId;
  DateTime date;
  List<BillItem> items;
  double subtotal;
  double taxPct;
  double discount;
  double grandTotal;
  String status; // 'paid' | 'due' | 'partial'
  String note;
  final DateTime createdAt;

  Bill({
    required this.id,
    required this.billNo,
    this.partyId = '',
    required this.date,
    List<BillItem>? items,
    this.subtotal = 0,
    this.taxPct = 0,
    this.discount = 0,
    this.grandTotal = 0,
    this.status = 'due',
    this.note = '',
    required this.createdAt,
  }) : items = items ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'billNo': billNo,
        'partyId': partyId,
        'date': date.toIso8601String(),
        'items': items.map((i) => i.toJson()).toList(),
        'subtotal': subtotal,
        'taxPct': taxPct,
        'discount': discount,
        'grandTotal': grandTotal,
        'status': status,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Bill.fromJson(Map<String, dynamic> j) => Bill(
        id: j['id'] as String,
        billNo: j['billNo'] as String,
        partyId: j['partyId'] as String? ?? '',
        date: DateTime.parse(j['date'] as String),
        items: (j['items'] as List? ?? [])
            .map((e) => BillItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        subtotal: (j['subtotal'] as num? ?? 0).toDouble(),
        taxPct: (j['taxPct'] as num? ?? 0).toDouble(),
        discount: (j['discount'] as num? ?? 0).toDouble(),
        grandTotal: (j['grandTotal'] as num? ?? 0).toDouble(),
        status: j['status'] as String? ?? 'due',
        note: j['note'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class BillAdapter extends TypeAdapter<Bill> {
  @override
  final int typeId = 12;

  @override
  Bill read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Bill(
      id: fields[0] as String,
      billNo: fields[1] as String,
      partyId: fields[2] as String,
      date: fields[3] as DateTime,
      items: (fields[4] as List).cast<BillItem>(),
      subtotal: fields[5] as double,
      taxPct: fields[6] as double,
      discount: fields[7] as double,
      grandTotal: fields[8] as double,
      status: fields[9] as String,
      note: fields[10] as String,
      createdAt: fields[11] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Bill obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.billNo)
      ..writeByte(2)
      ..write(obj.partyId)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.items)
      ..writeByte(5)
      ..write(obj.subtotal)
      ..writeByte(6)
      ..write(obj.taxPct)
      ..writeByte(7)
      ..write(obj.discount)
      ..writeByte(8)
      ..write(obj.grandTotal)
      ..writeByte(9)
      ..write(obj.status)
      ..writeByte(10)
      ..write(obj.note)
      ..writeByte(11)
      ..write(obj.createdAt);
  }
}

// ---------------------------------------------------------------- bank account
class BankAccount {
  final String id;
  String bankName;
  String title;
  String accountNo;
  final DateTime createdAt;

  BankAccount({
    required this.id,
    required this.bankName,
    this.title = '',
    this.accountNo = '',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'bankName': bankName,
        'title': title,
        'accountNo': accountNo,
        'createdAt': createdAt.toIso8601String(),
      };

  factory BankAccount.fromJson(Map<String, dynamic> j) => BankAccount(
        id: j['id'] as String,
        bankName: j['bankName'] as String,
        title: j['title'] as String? ?? '',
        accountNo: j['accountNo'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class BankAccountAdapter extends TypeAdapter<BankAccount> {
  @override
  final int typeId = 13;

  @override
  BankAccount read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BankAccount(
      id: fields[0] as String,
      bankName: fields[1] as String,
      title: fields[2] as String,
      accountNo: fields[3] as String,
      createdAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, BankAccount obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.bankName)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.accountNo)
      ..writeByte(4)
      ..write(obj.createdAt);
  }
}

// -------------------------------------------------------------------- bank txn
class BankTxn {
  final String id;
  String bankAccountId;
  String direction; // 'deposit' | 'withdraw'
  double amount;
  DateTime date;
  String detail;
  final DateTime createdAt;

  BankTxn({
    required this.id,
    required this.bankAccountId,
    required this.direction,
    required this.amount,
    required this.date,
    this.detail = '',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'bankAccountId': bankAccountId,
        'direction': direction,
        'amount': amount,
        'date': date.toIso8601String(),
        'detail': detail,
        'createdAt': createdAt.toIso8601String(),
      };

  factory BankTxn.fromJson(Map<String, dynamic> j) => BankTxn(
        id: j['id'] as String,
        bankAccountId: j['bankAccountId'] as String,
        direction: j['direction'] as String,
        amount: (j['amount'] as num).toDouble(),
        date: DateTime.parse(j['date'] as String),
        detail: j['detail'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class BankTxnAdapter extends TypeAdapter<BankTxn> {
  @override
  final int typeId = 14;

  @override
  BankTxn read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BankTxn(
      id: fields[0] as String,
      bankAccountId: fields[1] as String,
      direction: fields[2] as String,
      amount: fields[3] as double,
      date: fields[4] as DateTime,
      detail: fields[5] as String,
      createdAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, BankTxn obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.bankAccountId)
      ..writeByte(2)
      ..write(obj.direction)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.detail)
      ..writeByte(6)
      ..write(obj.createdAt);
  }
}

// -------------------------------------------------------------------- reminder
class Reminder {
  final String id;
  String partyId;
  DateTime dueDate;
  double amount;
  String note;
  int sentCount;
  DateTime? lastSentAt;
  bool done;
  final DateTime createdAt;

  Reminder({
    required this.id,
    required this.partyId,
    required this.dueDate,
    this.amount = 0,
    this.note = '',
    this.sentCount = 0,
    this.lastSentAt,
    this.done = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'partyId': partyId,
        'dueDate': dueDate.toIso8601String(),
        'amount': amount,
        'note': note,
        'sentCount': sentCount,
        'lastSentAt': lastSentAt?.toIso8601String(),
        'done': done,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Reminder.fromJson(Map<String, dynamic> j) => Reminder(
        id: j['id'] as String,
        partyId: j['partyId'] as String,
        dueDate: DateTime.parse(j['dueDate'] as String),
        amount: (j['amount'] as num? ?? 0).toDouble(),
        note: j['note'] as String? ?? '',
        sentCount: j['sentCount'] as int? ?? 0,
        lastSentAt: j['lastSentAt'] == null
            ? null
            : DateTime.parse(j['lastSentAt'] as String),
        done: j['done'] as bool? ?? false,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class ReminderAdapter extends TypeAdapter<Reminder> {
  @override
  final int typeId = 15;

  @override
  Reminder read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Reminder(
      id: fields[0] as String,
      partyId: fields[1] as String,
      dueDate: fields[2] as DateTime,
      amount: fields[3] as double,
      note: fields[4] as String,
      sentCount: fields[5] as int,
      lastSentAt: fields[6] as DateTime?,
      done: fields[7] as bool,
      createdAt: fields[8] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Reminder obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.partyId)
      ..writeByte(2)
      ..write(obj.dueDate)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.note)
      ..writeByte(5)
      ..write(obj.sentCount)
      ..writeByte(6)
      ..write(obj.lastSentAt)
      ..writeByte(7)
      ..write(obj.done)
      ..writeByte(8)
      ..write(obj.createdAt);
  }
}
