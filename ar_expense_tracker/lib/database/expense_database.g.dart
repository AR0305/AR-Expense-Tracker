// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense_database.dart';

// ignore_for_file: type=lint
class $ExpenseGroupsTable extends ExpenseGroups
    with TableInfo<$ExpenseGroupsTable, ExpenseGroup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExpenseGroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('folder_rounded'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monthlyBudgetMeta = const VerificationMeta(
    'monthlyBudget',
  );
  @override
  late final GeneratedColumn<double> monthlyBudget = GeneratedColumn<double>(
    'monthly_budget',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isMonthlyBudgetMeta = const VerificationMeta(
    'isMonthlyBudget',
  );
  @override
  late final GeneratedColumn<bool> isMonthlyBudget = GeneratedColumn<bool>(
    'is_monthly_budget',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_monthly_budget" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    icon,
    createdAt,
    monthlyBudget,
    isPinned,
    isArchived,
    isMonthlyBudget,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'expense_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExpenseGroup> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('monthly_budget')) {
      context.handle(
        _monthlyBudgetMeta,
        monthlyBudget.isAcceptableOrUnknown(
          data['monthly_budget']!,
          _monthlyBudgetMeta,
        ),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('is_monthly_budget')) {
      context.handle(
        _isMonthlyBudgetMeta,
        isMonthlyBudget.isAcceptableOrUnknown(
          data['is_monthly_budget']!,
          _isMonthlyBudgetMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExpenseGroup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExpenseGroup(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      monthlyBudget: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}monthly_budget'],
      ),
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      isMonthlyBudget: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_monthly_budget'],
      )!,
    );
  }

  @override
  $ExpenseGroupsTable createAlias(String alias) {
    return $ExpenseGroupsTable(attachedDatabase, alias);
  }
}

class ExpenseGroup extends DataClass implements Insertable<ExpenseGroup> {
  final int id;
  final String name;
  final String icon;
  final DateTime createdAt;
  final double? monthlyBudget;
  final bool isPinned;
  final bool isArchived;
  final bool isMonthlyBudget;
  const ExpenseGroup({
    required this.id,
    required this.name,
    required this.icon,
    required this.createdAt,
    this.monthlyBudget,
    required this.isPinned,
    required this.isArchived,
    required this.isMonthlyBudget,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['icon'] = Variable<String>(icon);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || monthlyBudget != null) {
      map['monthly_budget'] = Variable<double>(monthlyBudget);
    }
    map['is_pinned'] = Variable<bool>(isPinned);
    map['is_archived'] = Variable<bool>(isArchived);
    map['is_monthly_budget'] = Variable<bool>(isMonthlyBudget);
    return map;
  }

  ExpenseGroupsCompanion toCompanion(bool nullToAbsent) {
    return ExpenseGroupsCompanion(
      id: Value(id),
      name: Value(name),
      icon: Value(icon),
      createdAt: Value(createdAt),
      monthlyBudget: monthlyBudget == null && nullToAbsent
          ? const Value.absent()
          : Value(monthlyBudget),
      isPinned: Value(isPinned),
      isArchived: Value(isArchived),
      isMonthlyBudget: Value(isMonthlyBudget),
    );
  }

  factory ExpenseGroup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExpenseGroup(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      icon: serializer.fromJson<String>(json['icon']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      monthlyBudget: serializer.fromJson<double?>(json['monthlyBudget']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      isMonthlyBudget: serializer.fromJson<bool>(json['isMonthlyBudget']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'icon': serializer.toJson<String>(icon),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'monthlyBudget': serializer.toJson<double?>(monthlyBudget),
      'isPinned': serializer.toJson<bool>(isPinned),
      'isArchived': serializer.toJson<bool>(isArchived),
      'isMonthlyBudget': serializer.toJson<bool>(isMonthlyBudget),
    };
  }

  ExpenseGroup copyWith({
    int? id,
    String? name,
    String? icon,
    DateTime? createdAt,
    Value<double?> monthlyBudget = const Value.absent(),
    bool? isPinned,
    bool? isArchived,
    bool? isMonthlyBudget,
  }) => ExpenseGroup(
    id: id ?? this.id,
    name: name ?? this.name,
    icon: icon ?? this.icon,
    createdAt: createdAt ?? this.createdAt,
    monthlyBudget: monthlyBudget.present
        ? monthlyBudget.value
        : this.monthlyBudget,
    isPinned: isPinned ?? this.isPinned,
    isArchived: isArchived ?? this.isArchived,
    isMonthlyBudget: isMonthlyBudget ?? this.isMonthlyBudget,
  );
  ExpenseGroup copyWithCompanion(ExpenseGroupsCompanion data) {
    return ExpenseGroup(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      icon: data.icon.present ? data.icon.value : this.icon,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      monthlyBudget: data.monthlyBudget.present
          ? data.monthlyBudget.value
          : this.monthlyBudget,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      isMonthlyBudget: data.isMonthlyBudget.present
          ? data.isMonthlyBudget.value
          : this.isMonthlyBudget,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExpenseGroup(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('createdAt: $createdAt, ')
          ..write('monthlyBudget: $monthlyBudget, ')
          ..write('isPinned: $isPinned, ')
          ..write('isArchived: $isArchived, ')
          ..write('isMonthlyBudget: $isMonthlyBudget')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    icon,
    createdAt,
    monthlyBudget,
    isPinned,
    isArchived,
    isMonthlyBudget,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExpenseGroup &&
          other.id == this.id &&
          other.name == this.name &&
          other.icon == this.icon &&
          other.createdAt == this.createdAt &&
          other.monthlyBudget == this.monthlyBudget &&
          other.isPinned == this.isPinned &&
          other.isArchived == this.isArchived &&
          other.isMonthlyBudget == this.isMonthlyBudget);
}

class ExpenseGroupsCompanion extends UpdateCompanion<ExpenseGroup> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> icon;
  final Value<DateTime> createdAt;
  final Value<double?> monthlyBudget;
  final Value<bool> isPinned;
  final Value<bool> isArchived;
  final Value<bool> isMonthlyBudget;
  const ExpenseGroupsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.icon = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.monthlyBudget = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.isMonthlyBudget = const Value.absent(),
  });
  ExpenseGroupsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.icon = const Value.absent(),
    required DateTime createdAt,
    this.monthlyBudget = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.isMonthlyBudget = const Value.absent(),
  }) : name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<ExpenseGroup> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? icon,
    Expression<DateTime>? createdAt,
    Expression<double>? monthlyBudget,
    Expression<bool>? isPinned,
    Expression<bool>? isArchived,
    Expression<bool>? isMonthlyBudget,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (icon != null) 'icon': icon,
      if (createdAt != null) 'created_at': createdAt,
      if (monthlyBudget != null) 'monthly_budget': monthlyBudget,
      if (isPinned != null) 'is_pinned': isPinned,
      if (isArchived != null) 'is_archived': isArchived,
      if (isMonthlyBudget != null) 'is_monthly_budget': isMonthlyBudget,
    });
  }

  ExpenseGroupsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? icon,
    Value<DateTime>? createdAt,
    Value<double?>? monthlyBudget,
    Value<bool>? isPinned,
    Value<bool>? isArchived,
    Value<bool>? isMonthlyBudget,
  }) {
    return ExpenseGroupsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      isMonthlyBudget: isMonthlyBudget ?? this.isMonthlyBudget,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (monthlyBudget.present) {
      map['monthly_budget'] = Variable<double>(monthlyBudget.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (isMonthlyBudget.present) {
      map['is_monthly_budget'] = Variable<bool>(isMonthlyBudget.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExpenseGroupsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('createdAt: $createdAt, ')
          ..write('monthlyBudget: $monthlyBudget, ')
          ..write('isPinned: $isPinned, ')
          ..write('isArchived: $isArchived, ')
          ..write('isMonthlyBudget: $isMonthlyBudget')
          ..write(')'))
        .toString();
  }
}

class $ExpensesTable extends Expenses with TableInfo<$ExpensesTable, Expense> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExpensesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>?, String>
  imagePaths = GeneratedColumn<String>(
    'image_paths',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<List<String>?>($ExpensesTable.$converterimagePathsn);
  @override
  late final GeneratedColumnWithTypeConverter<List<SubExpense>?, String>
  subExpenses = GeneratedColumn<String>(
    'sub_expenses',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<List<SubExpense>?>($ExpensesTable.$convertersubExpensesn);
  static const VerificationMeta _isRecurringMeta = const VerificationMeta(
    'isRecurring',
  );
  @override
  late final GeneratedColumn<bool> isRecurring = GeneratedColumn<bool>(
    'is_recurring',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_recurring" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _recurrencePeriodMeta = const VerificationMeta(
    'recurrencePeriod',
  );
  @override
  late final GeneratedColumn<String> recurrencePeriod = GeneratedColumn<String>(
    'recurrence_period',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextRecurringDateMeta = const VerificationMeta(
    'nextRecurringDate',
  );
  @override
  late final GeneratedColumn<DateTime> nextRecurringDate =
      GeneratedColumn<DateTime>(
        'next_recurring_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<int> groupId = GeneratedColumn<int>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES expense_groups (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _omitFromAvgMeta = const VerificationMeta(
    'omitFromAvg',
  );
  @override
  late final GeneratedColumn<bool> omitFromAvg = GeneratedColumn<bool>(
    'omit_from_avg',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("omit_from_avg" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    amount,
    date,
    category,
    note,
    imagePaths,
    subExpenses,
    isRecurring,
    recurrencePeriod,
    nextRecurringDate,
    groupId,
    omitFromAvg,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'expenses';
  @override
  VerificationContext validateIntegrity(
    Insertable<Expense> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('is_recurring')) {
      context.handle(
        _isRecurringMeta,
        isRecurring.isAcceptableOrUnknown(
          data['is_recurring']!,
          _isRecurringMeta,
        ),
      );
    }
    if (data.containsKey('recurrence_period')) {
      context.handle(
        _recurrencePeriodMeta,
        recurrencePeriod.isAcceptableOrUnknown(
          data['recurrence_period']!,
          _recurrencePeriodMeta,
        ),
      );
    }
    if (data.containsKey('next_recurring_date')) {
      context.handle(
        _nextRecurringDateMeta,
        nextRecurringDate.isAcceptableOrUnknown(
          data['next_recurring_date']!,
          _nextRecurringDateMeta,
        ),
      );
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('omit_from_avg')) {
      context.handle(
        _omitFromAvgMeta,
        omitFromAvg.isAcceptableOrUnknown(
          data['omit_from_avg']!,
          _omitFromAvgMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Expense map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Expense(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      imagePaths: $ExpensesTable.$converterimagePathsn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}image_paths'],
        ),
      ),
      subExpenses: $ExpensesTable.$convertersubExpensesn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}sub_expenses'],
        ),
      ),
      isRecurring: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_recurring'],
      )!,
      recurrencePeriod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_period'],
      ),
      nextRecurringDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_recurring_date'],
      ),
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}group_id'],
      )!,
      omitFromAvg: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}omit_from_avg'],
      )!,
    );
  }

  @override
  $ExpensesTable createAlias(String alias) {
    return $ExpensesTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $converterimagePaths =
      const ListStringConverter();
  static TypeConverter<List<String>?, String?> $converterimagePathsn =
      NullAwareTypeConverter.wrap($converterimagePaths);
  static TypeConverter<List<SubExpense>, String> $convertersubExpenses =
      const SubExpenseListConverter();
  static TypeConverter<List<SubExpense>?, String?> $convertersubExpensesn =
      NullAwareTypeConverter.wrap($convertersubExpenses);
}

class Expense extends DataClass implements Insertable<Expense> {
  final int id;
  final String? title;
  final double amount;
  final DateTime date;
  final String category;
  final String? note;
  final List<String>? imagePaths;
  final List<SubExpense>? subExpenses;
  final bool isRecurring;
  final String? recurrencePeriod;
  final DateTime? nextRecurringDate;
  final int groupId;
  final bool omitFromAvg;
  const Expense({
    required this.id,
    this.title,
    required this.amount,
    required this.date,
    required this.category,
    this.note,
    this.imagePaths,
    this.subExpenses,
    required this.isRecurring,
    this.recurrencePeriod,
    this.nextRecurringDate,
    required this.groupId,
    required this.omitFromAvg,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    map['amount'] = Variable<double>(amount);
    map['date'] = Variable<DateTime>(date);
    map['category'] = Variable<String>(category);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || imagePaths != null) {
      map['image_paths'] = Variable<String>(
        $ExpensesTable.$converterimagePathsn.toSql(imagePaths),
      );
    }
    if (!nullToAbsent || subExpenses != null) {
      map['sub_expenses'] = Variable<String>(
        $ExpensesTable.$convertersubExpensesn.toSql(subExpenses),
      );
    }
    map['is_recurring'] = Variable<bool>(isRecurring);
    if (!nullToAbsent || recurrencePeriod != null) {
      map['recurrence_period'] = Variable<String>(recurrencePeriod);
    }
    if (!nullToAbsent || nextRecurringDate != null) {
      map['next_recurring_date'] = Variable<DateTime>(nextRecurringDate);
    }
    map['group_id'] = Variable<int>(groupId);
    map['omit_from_avg'] = Variable<bool>(omitFromAvg);
    return map;
  }

  ExpensesCompanion toCompanion(bool nullToAbsent) {
    return ExpensesCompanion(
      id: Value(id),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      amount: Value(amount),
      date: Value(date),
      category: Value(category),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      imagePaths: imagePaths == null && nullToAbsent
          ? const Value.absent()
          : Value(imagePaths),
      subExpenses: subExpenses == null && nullToAbsent
          ? const Value.absent()
          : Value(subExpenses),
      isRecurring: Value(isRecurring),
      recurrencePeriod: recurrencePeriod == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrencePeriod),
      nextRecurringDate: nextRecurringDate == null && nullToAbsent
          ? const Value.absent()
          : Value(nextRecurringDate),
      groupId: Value(groupId),
      omitFromAvg: Value(omitFromAvg),
    );
  }

  factory Expense.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Expense(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String?>(json['title']),
      amount: serializer.fromJson<double>(json['amount']),
      date: serializer.fromJson<DateTime>(json['date']),
      category: serializer.fromJson<String>(json['category']),
      note: serializer.fromJson<String?>(json['note']),
      imagePaths: serializer.fromJson<List<String>?>(json['imagePaths']),
      subExpenses: serializer.fromJson<List<SubExpense>?>(json['subExpenses']),
      isRecurring: serializer.fromJson<bool>(json['isRecurring']),
      recurrencePeriod: serializer.fromJson<String?>(json['recurrencePeriod']),
      nextRecurringDate: serializer.fromJson<DateTime?>(
        json['nextRecurringDate'],
      ),
      groupId: serializer.fromJson<int>(json['groupId']),
      omitFromAvg: serializer.fromJson<bool>(json['omitFromAvg']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String?>(title),
      'amount': serializer.toJson<double>(amount),
      'date': serializer.toJson<DateTime>(date),
      'category': serializer.toJson<String>(category),
      'note': serializer.toJson<String?>(note),
      'imagePaths': serializer.toJson<List<String>?>(imagePaths),
      'subExpenses': serializer.toJson<List<SubExpense>?>(subExpenses),
      'isRecurring': serializer.toJson<bool>(isRecurring),
      'recurrencePeriod': serializer.toJson<String?>(recurrencePeriod),
      'nextRecurringDate': serializer.toJson<DateTime?>(nextRecurringDate),
      'groupId': serializer.toJson<int>(groupId),
      'omitFromAvg': serializer.toJson<bool>(omitFromAvg),
    };
  }

  Expense copyWith({
    int? id,
    Value<String?> title = const Value.absent(),
    double? amount,
    DateTime? date,
    String? category,
    Value<String?> note = const Value.absent(),
    Value<List<String>?> imagePaths = const Value.absent(),
    Value<List<SubExpense>?> subExpenses = const Value.absent(),
    bool? isRecurring,
    Value<String?> recurrencePeriod = const Value.absent(),
    Value<DateTime?> nextRecurringDate = const Value.absent(),
    int? groupId,
    bool? omitFromAvg,
  }) => Expense(
    id: id ?? this.id,
    title: title.present ? title.value : this.title,
    amount: amount ?? this.amount,
    date: date ?? this.date,
    category: category ?? this.category,
    note: note.present ? note.value : this.note,
    imagePaths: imagePaths.present ? imagePaths.value : this.imagePaths,
    subExpenses: subExpenses.present ? subExpenses.value : this.subExpenses,
    isRecurring: isRecurring ?? this.isRecurring,
    recurrencePeriod: recurrencePeriod.present
        ? recurrencePeriod.value
        : this.recurrencePeriod,
    nextRecurringDate: nextRecurringDate.present
        ? nextRecurringDate.value
        : this.nextRecurringDate,
    groupId: groupId ?? this.groupId,
    omitFromAvg: omitFromAvg ?? this.omitFromAvg,
  );
  Expense copyWithCompanion(ExpensesCompanion data) {
    return Expense(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      amount: data.amount.present ? data.amount.value : this.amount,
      date: data.date.present ? data.date.value : this.date,
      category: data.category.present ? data.category.value : this.category,
      note: data.note.present ? data.note.value : this.note,
      imagePaths: data.imagePaths.present
          ? data.imagePaths.value
          : this.imagePaths,
      subExpenses: data.subExpenses.present
          ? data.subExpenses.value
          : this.subExpenses,
      isRecurring: data.isRecurring.present
          ? data.isRecurring.value
          : this.isRecurring,
      recurrencePeriod: data.recurrencePeriod.present
          ? data.recurrencePeriod.value
          : this.recurrencePeriod,
      nextRecurringDate: data.nextRecurringDate.present
          ? data.nextRecurringDate.value
          : this.nextRecurringDate,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      omitFromAvg: data.omitFromAvg.present
          ? data.omitFromAvg.value
          : this.omitFromAvg,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Expense(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('amount: $amount, ')
          ..write('date: $date, ')
          ..write('category: $category, ')
          ..write('note: $note, ')
          ..write('imagePaths: $imagePaths, ')
          ..write('subExpenses: $subExpenses, ')
          ..write('isRecurring: $isRecurring, ')
          ..write('recurrencePeriod: $recurrencePeriod, ')
          ..write('nextRecurringDate: $nextRecurringDate, ')
          ..write('groupId: $groupId, ')
          ..write('omitFromAvg: $omitFromAvg')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    amount,
    date,
    category,
    note,
    imagePaths,
    subExpenses,
    isRecurring,
    recurrencePeriod,
    nextRecurringDate,
    groupId,
    omitFromAvg,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Expense &&
          other.id == this.id &&
          other.title == this.title &&
          other.amount == this.amount &&
          other.date == this.date &&
          other.category == this.category &&
          other.note == this.note &&
          other.imagePaths == this.imagePaths &&
          other.subExpenses == this.subExpenses &&
          other.isRecurring == this.isRecurring &&
          other.recurrencePeriod == this.recurrencePeriod &&
          other.nextRecurringDate == this.nextRecurringDate &&
          other.groupId == this.groupId &&
          other.omitFromAvg == this.omitFromAvg);
}

class ExpensesCompanion extends UpdateCompanion<Expense> {
  final Value<int> id;
  final Value<String?> title;
  final Value<double> amount;
  final Value<DateTime> date;
  final Value<String> category;
  final Value<String?> note;
  final Value<List<String>?> imagePaths;
  final Value<List<SubExpense>?> subExpenses;
  final Value<bool> isRecurring;
  final Value<String?> recurrencePeriod;
  final Value<DateTime?> nextRecurringDate;
  final Value<int> groupId;
  final Value<bool> omitFromAvg;
  const ExpensesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.amount = const Value.absent(),
    this.date = const Value.absent(),
    this.category = const Value.absent(),
    this.note = const Value.absent(),
    this.imagePaths = const Value.absent(),
    this.subExpenses = const Value.absent(),
    this.isRecurring = const Value.absent(),
    this.recurrencePeriod = const Value.absent(),
    this.nextRecurringDate = const Value.absent(),
    this.groupId = const Value.absent(),
    this.omitFromAvg = const Value.absent(),
  });
  ExpensesCompanion.insert({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    required double amount,
    required DateTime date,
    required String category,
    this.note = const Value.absent(),
    this.imagePaths = const Value.absent(),
    this.subExpenses = const Value.absent(),
    this.isRecurring = const Value.absent(),
    this.recurrencePeriod = const Value.absent(),
    this.nextRecurringDate = const Value.absent(),
    required int groupId,
    this.omitFromAvg = const Value.absent(),
  }) : amount = Value(amount),
       date = Value(date),
       category = Value(category),
       groupId = Value(groupId);
  static Insertable<Expense> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<double>? amount,
    Expression<DateTime>? date,
    Expression<String>? category,
    Expression<String>? note,
    Expression<String>? imagePaths,
    Expression<String>? subExpenses,
    Expression<bool>? isRecurring,
    Expression<String>? recurrencePeriod,
    Expression<DateTime>? nextRecurringDate,
    Expression<int>? groupId,
    Expression<bool>? omitFromAvg,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (amount != null) 'amount': amount,
      if (date != null) 'date': date,
      if (category != null) 'category': category,
      if (note != null) 'note': note,
      if (imagePaths != null) 'image_paths': imagePaths,
      if (subExpenses != null) 'sub_expenses': subExpenses,
      if (isRecurring != null) 'is_recurring': isRecurring,
      if (recurrencePeriod != null) 'recurrence_period': recurrencePeriod,
      if (nextRecurringDate != null) 'next_recurring_date': nextRecurringDate,
      if (groupId != null) 'group_id': groupId,
      if (omitFromAvg != null) 'omit_from_avg': omitFromAvg,
    });
  }

  ExpensesCompanion copyWith({
    Value<int>? id,
    Value<String?>? title,
    Value<double>? amount,
    Value<DateTime>? date,
    Value<String>? category,
    Value<String?>? note,
    Value<List<String>?>? imagePaths,
    Value<List<SubExpense>?>? subExpenses,
    Value<bool>? isRecurring,
    Value<String?>? recurrencePeriod,
    Value<DateTime?>? nextRecurringDate,
    Value<int>? groupId,
    Value<bool>? omitFromAvg,
  }) {
    return ExpensesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      note: note ?? this.note,
      imagePaths: imagePaths ?? this.imagePaths,
      subExpenses: subExpenses ?? this.subExpenses,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrencePeriod: recurrencePeriod ?? this.recurrencePeriod,
      nextRecurringDate: nextRecurringDate ?? this.nextRecurringDate,
      groupId: groupId ?? this.groupId,
      omitFromAvg: omitFromAvg ?? this.omitFromAvg,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (imagePaths.present) {
      map['image_paths'] = Variable<String>(
        $ExpensesTable.$converterimagePathsn.toSql(imagePaths.value),
      );
    }
    if (subExpenses.present) {
      map['sub_expenses'] = Variable<String>(
        $ExpensesTable.$convertersubExpensesn.toSql(subExpenses.value),
      );
    }
    if (isRecurring.present) {
      map['is_recurring'] = Variable<bool>(isRecurring.value);
    }
    if (recurrencePeriod.present) {
      map['recurrence_period'] = Variable<String>(recurrencePeriod.value);
    }
    if (nextRecurringDate.present) {
      map['next_recurring_date'] = Variable<DateTime>(nextRecurringDate.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<int>(groupId.value);
    }
    if (omitFromAvg.present) {
      map['omit_from_avg'] = Variable<bool>(omitFromAvg.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExpensesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('amount: $amount, ')
          ..write('date: $date, ')
          ..write('category: $category, ')
          ..write('note: $note, ')
          ..write('imagePaths: $imagePaths, ')
          ..write('subExpenses: $subExpenses, ')
          ..write('isRecurring: $isRecurring, ')
          ..write('recurrencePeriod: $recurrencePeriod, ')
          ..write('nextRecurringDate: $nextRecurringDate, ')
          ..write('groupId: $groupId, ')
          ..write('omitFromAvg: $omitFromAvg')
          ..write(')'))
        .toString();
  }
}

class $CustomCategoriesTable extends CustomCategories
    with TableInfo<$CustomCategoriesTable, CustomCategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomCategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconNameMeta = const VerificationMeta(
    'iconName',
  );
  @override
  late final GeneratedColumn<String> iconName = GeneratedColumn<String>(
    'icon_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<int> groupId = GeneratedColumn<int>(
    'group_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    iconName,
    colorValue,
    groupId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'custom_categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<CustomCategory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('icon_name')) {
      context.handle(
        _iconNameMeta,
        iconName.isAcceptableOrUnknown(data['icon_name']!, _iconNameMeta),
      );
    } else if (isInserting) {
      context.missing(_iconNameMeta);
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    } else if (isInserting) {
      context.missing(_colorValueMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CustomCategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CustomCategory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      iconName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_name'],
      )!,
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}group_id'],
      ),
    );
  }

  @override
  $CustomCategoriesTable createAlias(String alias) {
    return $CustomCategoriesTable(attachedDatabase, alias);
  }
}

class CustomCategory extends DataClass implements Insertable<CustomCategory> {
  final int id;
  final String name;
  final String iconName;
  final int colorValue;
  final int? groupId;
  const CustomCategory({
    required this.id,
    required this.name,
    required this.iconName,
    required this.colorValue,
    this.groupId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['icon_name'] = Variable<String>(iconName);
    map['color_value'] = Variable<int>(colorValue);
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<int>(groupId);
    }
    return map;
  }

  CustomCategoriesCompanion toCompanion(bool nullToAbsent) {
    return CustomCategoriesCompanion(
      id: Value(id),
      name: Value(name),
      iconName: Value(iconName),
      colorValue: Value(colorValue),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
    );
  }

  factory CustomCategory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CustomCategory(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      iconName: serializer.fromJson<String>(json['iconName']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      groupId: serializer.fromJson<int?>(json['groupId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'iconName': serializer.toJson<String>(iconName),
      'colorValue': serializer.toJson<int>(colorValue),
      'groupId': serializer.toJson<int?>(groupId),
    };
  }

  CustomCategory copyWith({
    int? id,
    String? name,
    String? iconName,
    int? colorValue,
    Value<int?> groupId = const Value.absent(),
  }) => CustomCategory(
    id: id ?? this.id,
    name: name ?? this.name,
    iconName: iconName ?? this.iconName,
    colorValue: colorValue ?? this.colorValue,
    groupId: groupId.present ? groupId.value : this.groupId,
  );
  CustomCategory copyWithCompanion(CustomCategoriesCompanion data) {
    return CustomCategory(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      iconName: data.iconName.present ? data.iconName.value : this.iconName,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CustomCategory(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('iconName: $iconName, ')
          ..write('colorValue: $colorValue, ')
          ..write('groupId: $groupId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, iconName, colorValue, groupId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CustomCategory &&
          other.id == this.id &&
          other.name == this.name &&
          other.iconName == this.iconName &&
          other.colorValue == this.colorValue &&
          other.groupId == this.groupId);
}

class CustomCategoriesCompanion extends UpdateCompanion<CustomCategory> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> iconName;
  final Value<int> colorValue;
  final Value<int?> groupId;
  const CustomCategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.iconName = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.groupId = const Value.absent(),
  });
  CustomCategoriesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String iconName,
    required int colorValue,
    this.groupId = const Value.absent(),
  }) : name = Value(name),
       iconName = Value(iconName),
       colorValue = Value(colorValue);
  static Insertable<CustomCategory> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? iconName,
    Expression<int>? colorValue,
    Expression<int>? groupId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (iconName != null) 'icon_name': iconName,
      if (colorValue != null) 'color_value': colorValue,
      if (groupId != null) 'group_id': groupId,
    });
  }

  CustomCategoriesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? iconName,
    Value<int>? colorValue,
    Value<int?>? groupId,
  }) {
    return CustomCategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      colorValue: colorValue ?? this.colorValue,
      groupId: groupId ?? this.groupId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (iconName.present) {
      map['icon_name'] = Variable<String>(iconName.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<int>(groupId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomCategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('iconName: $iconName, ')
          ..write('colorValue: $colorValue, ')
          ..write('groupId: $groupId')
          ..write(')'))
        .toString();
  }
}

class $CategoryBudgetsTable extends CategoryBudgets
    with TableInfo<$CategoryBudgetsTable, CategoryBudget> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoryBudgetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _includePastExpensesMeta =
      const VerificationMeta('includePastExpenses');
  @override
  late final GeneratedColumn<bool> includePastExpenses = GeneratedColumn<bool>(
    'include_past_expenses',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("include_past_expenses" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<int> groupId = GeneratedColumn<int>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES expense_groups (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    category,
    amount,
    createdAt,
    includePastExpenses,
    groupId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'category_budgets';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryBudget> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('include_past_expenses')) {
      context.handle(
        _includePastExpensesMeta,
        includePastExpenses.isAcceptableOrUnknown(
          data['include_past_expenses']!,
          _includePastExpensesMeta,
        ),
      );
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CategoryBudget map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryBudget(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      includePastExpenses: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}include_past_expenses'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}group_id'],
      )!,
    );
  }

  @override
  $CategoryBudgetsTable createAlias(String alias) {
    return $CategoryBudgetsTable(attachedDatabase, alias);
  }
}

class CategoryBudget extends DataClass implements Insertable<CategoryBudget> {
  final int id;
  final String category;
  final double amount;
  final DateTime? createdAt;
  final bool includePastExpenses;
  final int groupId;
  const CategoryBudget({
    required this.id,
    required this.category,
    required this.amount,
    this.createdAt,
    required this.includePastExpenses,
    required this.groupId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['category'] = Variable<String>(category);
    map['amount'] = Variable<double>(amount);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    map['include_past_expenses'] = Variable<bool>(includePastExpenses);
    map['group_id'] = Variable<int>(groupId);
    return map;
  }

  CategoryBudgetsCompanion toCompanion(bool nullToAbsent) {
    return CategoryBudgetsCompanion(
      id: Value(id),
      category: Value(category),
      amount: Value(amount),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      includePastExpenses: Value(includePastExpenses),
      groupId: Value(groupId),
    );
  }

  factory CategoryBudget.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryBudget(
      id: serializer.fromJson<int>(json['id']),
      category: serializer.fromJson<String>(json['category']),
      amount: serializer.fromJson<double>(json['amount']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      includePastExpenses: serializer.fromJson<bool>(
        json['includePastExpenses'],
      ),
      groupId: serializer.fromJson<int>(json['groupId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'category': serializer.toJson<String>(category),
      'amount': serializer.toJson<double>(amount),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'includePastExpenses': serializer.toJson<bool>(includePastExpenses),
      'groupId': serializer.toJson<int>(groupId),
    };
  }

  CategoryBudget copyWith({
    int? id,
    String? category,
    double? amount,
    Value<DateTime?> createdAt = const Value.absent(),
    bool? includePastExpenses,
    int? groupId,
  }) => CategoryBudget(
    id: id ?? this.id,
    category: category ?? this.category,
    amount: amount ?? this.amount,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    includePastExpenses: includePastExpenses ?? this.includePastExpenses,
    groupId: groupId ?? this.groupId,
  );
  CategoryBudget copyWithCompanion(CategoryBudgetsCompanion data) {
    return CategoryBudget(
      id: data.id.present ? data.id.value : this.id,
      category: data.category.present ? data.category.value : this.category,
      amount: data.amount.present ? data.amount.value : this.amount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      includePastExpenses: data.includePastExpenses.present
          ? data.includePastExpenses.value
          : this.includePastExpenses,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryBudget(')
          ..write('id: $id, ')
          ..write('category: $category, ')
          ..write('amount: $amount, ')
          ..write('createdAt: $createdAt, ')
          ..write('includePastExpenses: $includePastExpenses, ')
          ..write('groupId: $groupId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    category,
    amount,
    createdAt,
    includePastExpenses,
    groupId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryBudget &&
          other.id == this.id &&
          other.category == this.category &&
          other.amount == this.amount &&
          other.createdAt == this.createdAt &&
          other.includePastExpenses == this.includePastExpenses &&
          other.groupId == this.groupId);
}

class CategoryBudgetsCompanion extends UpdateCompanion<CategoryBudget> {
  final Value<int> id;
  final Value<String> category;
  final Value<double> amount;
  final Value<DateTime?> createdAt;
  final Value<bool> includePastExpenses;
  final Value<int> groupId;
  const CategoryBudgetsCompanion({
    this.id = const Value.absent(),
    this.category = const Value.absent(),
    this.amount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.includePastExpenses = const Value.absent(),
    this.groupId = const Value.absent(),
  });
  CategoryBudgetsCompanion.insert({
    this.id = const Value.absent(),
    required String category,
    required double amount,
    this.createdAt = const Value.absent(),
    this.includePastExpenses = const Value.absent(),
    required int groupId,
  }) : category = Value(category),
       amount = Value(amount),
       groupId = Value(groupId);
  static Insertable<CategoryBudget> custom({
    Expression<int>? id,
    Expression<String>? category,
    Expression<double>? amount,
    Expression<DateTime>? createdAt,
    Expression<bool>? includePastExpenses,
    Expression<int>? groupId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (category != null) 'category': category,
      if (amount != null) 'amount': amount,
      if (createdAt != null) 'created_at': createdAt,
      if (includePastExpenses != null)
        'include_past_expenses': includePastExpenses,
      if (groupId != null) 'group_id': groupId,
    });
  }

  CategoryBudgetsCompanion copyWith({
    Value<int>? id,
    Value<String>? category,
    Value<double>? amount,
    Value<DateTime?>? createdAt,
    Value<bool>? includePastExpenses,
    Value<int>? groupId,
  }) {
    return CategoryBudgetsCompanion(
      id: id ?? this.id,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
      includePastExpenses: includePastExpenses ?? this.includePastExpenses,
      groupId: groupId ?? this.groupId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (includePastExpenses.present) {
      map['include_past_expenses'] = Variable<bool>(includePastExpenses.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<int>(groupId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoryBudgetsCompanion(')
          ..write('id: $id, ')
          ..write('category: $category, ')
          ..write('amount: $amount, ')
          ..write('createdAt: $createdAt, ')
          ..write('includePastExpenses: $includePastExpenses, ')
          ..write('groupId: $groupId')
          ..write(')'))
        .toString();
  }
}

abstract class _$ExpenseDatabase extends GeneratedDatabase {
  _$ExpenseDatabase(QueryExecutor e) : super(e);
  $ExpenseDatabaseManager get managers => $ExpenseDatabaseManager(this);
  late final $ExpenseGroupsTable expenseGroups = $ExpenseGroupsTable(this);
  late final $ExpensesTable expenses = $ExpensesTable(this);
  late final $CustomCategoriesTable customCategories = $CustomCategoriesTable(
    this,
  );
  late final $CategoryBudgetsTable categoryBudgets = $CategoryBudgetsTable(
    this,
  );
  late final Index expensesGroupIdIdx = Index(
    'expenses_group_id_idx',
    'CREATE INDEX expenses_group_id_idx ON expenses (group_id)',
  );
  late final Index expensesDateIdx = Index(
    'expenses_date_idx',
    'CREATE INDEX expenses_date_idx ON expenses (date)',
  );
  late final Index expensesCategoryIdx = Index(
    'expenses_category_idx',
    'CREATE INDEX expenses_category_idx ON expenses (category)',
  );
  late final Index customCategoriesGroupIdIdx = Index(
    'custom_categories_group_id_idx',
    'CREATE INDEX custom_categories_group_id_idx ON custom_categories (group_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    expenseGroups,
    expenses,
    customCategories,
    categoryBudgets,
    expensesGroupIdIdx,
    expensesDateIdx,
    expensesCategoryIdx,
    customCategoriesGroupIdIdx,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'expense_groups',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('expenses', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'expense_groups',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('category_budgets', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$ExpenseGroupsTableCreateCompanionBuilder =
    ExpenseGroupsCompanion Function({
      Value<int> id,
      required String name,
      Value<String> icon,
      required DateTime createdAt,
      Value<double?> monthlyBudget,
      Value<bool> isPinned,
      Value<bool> isArchived,
      Value<bool> isMonthlyBudget,
    });
typedef $$ExpenseGroupsTableUpdateCompanionBuilder =
    ExpenseGroupsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> icon,
      Value<DateTime> createdAt,
      Value<double?> monthlyBudget,
      Value<bool> isPinned,
      Value<bool> isArchived,
      Value<bool> isMonthlyBudget,
    });

final class $$ExpenseGroupsTableReferences
    extends
        BaseReferences<_$ExpenseDatabase, $ExpenseGroupsTable, ExpenseGroup> {
  $$ExpenseGroupsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$ExpensesTable, List<Expense>> _expensesRefsTable(
    _$ExpenseDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.expenses,
    aliasName: 'expense_groups__id__expenses__group_id',
  );

  $$ExpensesTableProcessedTableManager get expensesRefs {
    final manager = $$ExpensesTableTableManager(
      $_db,
      $_db.expenses,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_expensesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CategoryBudgetsTable, List<CategoryBudget>>
  _categoryBudgetsRefsTable(_$ExpenseDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.categoryBudgets,
        aliasName: 'expense_groups__id__category_budgets__group_id',
      );

  $$CategoryBudgetsTableProcessedTableManager get categoryBudgetsRefs {
    final manager = $$CategoryBudgetsTableTableManager(
      $_db,
      $_db.categoryBudgets,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _categoryBudgetsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ExpenseGroupsTableFilterComposer
    extends Composer<_$ExpenseDatabase, $ExpenseGroupsTable> {
  $$ExpenseGroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get monthlyBudget => $composableBuilder(
    column: $table.monthlyBudget,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isMonthlyBudget => $composableBuilder(
    column: $table.isMonthlyBudget,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> expensesRefs(
    Expression<bool> Function($$ExpensesTableFilterComposer f) f,
  ) {
    final $$ExpensesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.expenses,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExpensesTableFilterComposer(
            $db: $db,
            $table: $db.expenses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> categoryBudgetsRefs(
    Expression<bool> Function($$CategoryBudgetsTableFilterComposer f) f,
  ) {
    final $$CategoryBudgetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.categoryBudgets,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryBudgetsTableFilterComposer(
            $db: $db,
            $table: $db.categoryBudgets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ExpenseGroupsTableOrderingComposer
    extends Composer<_$ExpenseDatabase, $ExpenseGroupsTable> {
  $$ExpenseGroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get monthlyBudget => $composableBuilder(
    column: $table.monthlyBudget,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isMonthlyBudget => $composableBuilder(
    column: $table.isMonthlyBudget,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExpenseGroupsTableAnnotationComposer
    extends Composer<_$ExpenseDatabase, $ExpenseGroupsTable> {
  $$ExpenseGroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<double> get monthlyBudget => $composableBuilder(
    column: $table.monthlyBudget,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isMonthlyBudget => $composableBuilder(
    column: $table.isMonthlyBudget,
    builder: (column) => column,
  );

  Expression<T> expensesRefs<T extends Object>(
    Expression<T> Function($$ExpensesTableAnnotationComposer a) f,
  ) {
    final $$ExpensesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.expenses,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExpensesTableAnnotationComposer(
            $db: $db,
            $table: $db.expenses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> categoryBudgetsRefs<T extends Object>(
    Expression<T> Function($$CategoryBudgetsTableAnnotationComposer a) f,
  ) {
    final $$CategoryBudgetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.categoryBudgets,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryBudgetsTableAnnotationComposer(
            $db: $db,
            $table: $db.categoryBudgets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ExpenseGroupsTableTableManager
    extends
        RootTableManager<
          _$ExpenseDatabase,
          $ExpenseGroupsTable,
          ExpenseGroup,
          $$ExpenseGroupsTableFilterComposer,
          $$ExpenseGroupsTableOrderingComposer,
          $$ExpenseGroupsTableAnnotationComposer,
          $$ExpenseGroupsTableCreateCompanionBuilder,
          $$ExpenseGroupsTableUpdateCompanionBuilder,
          (ExpenseGroup, $$ExpenseGroupsTableReferences),
          ExpenseGroup,
          PrefetchHooks Function({bool expensesRefs, bool categoryBudgetsRefs})
        > {
  $$ExpenseGroupsTableTableManager(
    _$ExpenseDatabase db,
    $ExpenseGroupsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExpenseGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExpenseGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExpenseGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<double?> monthlyBudget = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<bool> isMonthlyBudget = const Value.absent(),
              }) => ExpenseGroupsCompanion(
                id: id,
                name: name,
                icon: icon,
                createdAt: createdAt,
                monthlyBudget: monthlyBudget,
                isPinned: isPinned,
                isArchived: isArchived,
                isMonthlyBudget: isMonthlyBudget,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> icon = const Value.absent(),
                required DateTime createdAt,
                Value<double?> monthlyBudget = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<bool> isMonthlyBudget = const Value.absent(),
              }) => ExpenseGroupsCompanion.insert(
                id: id,
                name: name,
                icon: icon,
                createdAt: createdAt,
                monthlyBudget: monthlyBudget,
                isPinned: isPinned,
                isArchived: isArchived,
                isMonthlyBudget: isMonthlyBudget,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ExpenseGroupsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({expensesRefs = false, categoryBudgetsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (expensesRefs) db.expenses,
                    if (categoryBudgetsRefs) db.categoryBudgets,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (expensesRefs)
                        await $_getPrefetchedData<
                          ExpenseGroup,
                          $ExpenseGroupsTable,
                          Expense
                        >(
                          currentTable: table,
                          referencedTable: $$ExpenseGroupsTableReferences
                              ._expensesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ExpenseGroupsTableReferences(
                                db,
                                table,
                                p0,
                              ).expensesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.groupId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (categoryBudgetsRefs)
                        await $_getPrefetchedData<
                          ExpenseGroup,
                          $ExpenseGroupsTable,
                          CategoryBudget
                        >(
                          currentTable: table,
                          referencedTable: $$ExpenseGroupsTableReferences
                              ._categoryBudgetsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ExpenseGroupsTableReferences(
                                db,
                                table,
                                p0,
                              ).categoryBudgetsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.groupId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ExpenseGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$ExpenseDatabase,
      $ExpenseGroupsTable,
      ExpenseGroup,
      $$ExpenseGroupsTableFilterComposer,
      $$ExpenseGroupsTableOrderingComposer,
      $$ExpenseGroupsTableAnnotationComposer,
      $$ExpenseGroupsTableCreateCompanionBuilder,
      $$ExpenseGroupsTableUpdateCompanionBuilder,
      (ExpenseGroup, $$ExpenseGroupsTableReferences),
      ExpenseGroup,
      PrefetchHooks Function({bool expensesRefs, bool categoryBudgetsRefs})
    >;
typedef $$ExpensesTableCreateCompanionBuilder =
    ExpensesCompanion Function({
      Value<int> id,
      Value<String?> title,
      required double amount,
      required DateTime date,
      required String category,
      Value<String?> note,
      Value<List<String>?> imagePaths,
      Value<List<SubExpense>?> subExpenses,
      Value<bool> isRecurring,
      Value<String?> recurrencePeriod,
      Value<DateTime?> nextRecurringDate,
      required int groupId,
      Value<bool> omitFromAvg,
    });
typedef $$ExpensesTableUpdateCompanionBuilder =
    ExpensesCompanion Function({
      Value<int> id,
      Value<String?> title,
      Value<double> amount,
      Value<DateTime> date,
      Value<String> category,
      Value<String?> note,
      Value<List<String>?> imagePaths,
      Value<List<SubExpense>?> subExpenses,
      Value<bool> isRecurring,
      Value<String?> recurrencePeriod,
      Value<DateTime?> nextRecurringDate,
      Value<int> groupId,
      Value<bool> omitFromAvg,
    });

final class $$ExpensesTableReferences
    extends BaseReferences<_$ExpenseDatabase, $ExpensesTable, Expense> {
  $$ExpensesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ExpenseGroupsTable _groupIdTable(_$ExpenseDatabase db) =>
      db.expenseGroups.createAlias('expenses__group_id__expense_groups__id');

  $$ExpenseGroupsTableProcessedTableManager get groupId {
    final $_column = $_itemColumn<int>('group_id')!;

    final manager = $$ExpenseGroupsTableTableManager(
      $_db,
      $_db.expenseGroups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ExpensesTableFilterComposer
    extends Composer<_$ExpenseDatabase, $ExpensesTable> {
  $$ExpensesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>?, List<String>, String>
  get imagePaths => $composableBuilder(
    column: $table.imagePaths,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<SubExpense>?, List<SubExpense>, String>
  get subExpenses => $composableBuilder(
    column: $table.subExpenses,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get isRecurring => $composableBuilder(
    column: $table.isRecurring,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrencePeriod => $composableBuilder(
    column: $table.recurrencePeriod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextRecurringDate => $composableBuilder(
    column: $table.nextRecurringDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get omitFromAvg => $composableBuilder(
    column: $table.omitFromAvg,
    builder: (column) => ColumnFilters(column),
  );

  $$ExpenseGroupsTableFilterComposer get groupId {
    final $$ExpenseGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.expenseGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExpenseGroupsTableFilterComposer(
            $db: $db,
            $table: $db.expenseGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExpensesTableOrderingComposer
    extends Composer<_$ExpenseDatabase, $ExpensesTable> {
  $$ExpensesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePaths => $composableBuilder(
    column: $table.imagePaths,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subExpenses => $composableBuilder(
    column: $table.subExpenses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRecurring => $composableBuilder(
    column: $table.isRecurring,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrencePeriod => $composableBuilder(
    column: $table.recurrencePeriod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextRecurringDate => $composableBuilder(
    column: $table.nextRecurringDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get omitFromAvg => $composableBuilder(
    column: $table.omitFromAvg,
    builder: (column) => ColumnOrderings(column),
  );

  $$ExpenseGroupsTableOrderingComposer get groupId {
    final $$ExpenseGroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.expenseGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExpenseGroupsTableOrderingComposer(
            $db: $db,
            $table: $db.expenseGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExpensesTableAnnotationComposer
    extends Composer<_$ExpenseDatabase, $ExpensesTable> {
  $$ExpensesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>?, String> get imagePaths =>
      $composableBuilder(
        column: $table.imagePaths,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<List<SubExpense>?, String> get subExpenses =>
      $composableBuilder(
        column: $table.subExpenses,
        builder: (column) => column,
      );

  GeneratedColumn<bool> get isRecurring => $composableBuilder(
    column: $table.isRecurring,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrencePeriod => $composableBuilder(
    column: $table.recurrencePeriod,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextRecurringDate => $composableBuilder(
    column: $table.nextRecurringDate,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get omitFromAvg => $composableBuilder(
    column: $table.omitFromAvg,
    builder: (column) => column,
  );

  $$ExpenseGroupsTableAnnotationComposer get groupId {
    final $$ExpenseGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.expenseGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExpenseGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.expenseGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExpensesTableTableManager
    extends
        RootTableManager<
          _$ExpenseDatabase,
          $ExpensesTable,
          Expense,
          $$ExpensesTableFilterComposer,
          $$ExpensesTableOrderingComposer,
          $$ExpensesTableAnnotationComposer,
          $$ExpensesTableCreateCompanionBuilder,
          $$ExpensesTableUpdateCompanionBuilder,
          (Expense, $$ExpensesTableReferences),
          Expense,
          PrefetchHooks Function({bool groupId})
        > {
  $$ExpensesTableTableManager(_$ExpenseDatabase db, $ExpensesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExpensesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExpensesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExpensesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<List<String>?> imagePaths = const Value.absent(),
                Value<List<SubExpense>?> subExpenses = const Value.absent(),
                Value<bool> isRecurring = const Value.absent(),
                Value<String?> recurrencePeriod = const Value.absent(),
                Value<DateTime?> nextRecurringDate = const Value.absent(),
                Value<int> groupId = const Value.absent(),
                Value<bool> omitFromAvg = const Value.absent(),
              }) => ExpensesCompanion(
                id: id,
                title: title,
                amount: amount,
                date: date,
                category: category,
                note: note,
                imagePaths: imagePaths,
                subExpenses: subExpenses,
                isRecurring: isRecurring,
                recurrencePeriod: recurrencePeriod,
                nextRecurringDate: nextRecurringDate,
                groupId: groupId,
                omitFromAvg: omitFromAvg,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> title = const Value.absent(),
                required double amount,
                required DateTime date,
                required String category,
                Value<String?> note = const Value.absent(),
                Value<List<String>?> imagePaths = const Value.absent(),
                Value<List<SubExpense>?> subExpenses = const Value.absent(),
                Value<bool> isRecurring = const Value.absent(),
                Value<String?> recurrencePeriod = const Value.absent(),
                Value<DateTime?> nextRecurringDate = const Value.absent(),
                required int groupId,
                Value<bool> omitFromAvg = const Value.absent(),
              }) => ExpensesCompanion.insert(
                id: id,
                title: title,
                amount: amount,
                date: date,
                category: category,
                note: note,
                imagePaths: imagePaths,
                subExpenses: subExpenses,
                isRecurring: isRecurring,
                recurrencePeriod: recurrencePeriod,
                nextRecurringDate: nextRecurringDate,
                groupId: groupId,
                omitFromAvg: omitFromAvg,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ExpensesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({groupId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (groupId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.groupId,
                                referencedTable: $$ExpensesTableReferences
                                    ._groupIdTable(db),
                                referencedColumn: $$ExpensesTableReferences
                                    ._groupIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ExpensesTableProcessedTableManager =
    ProcessedTableManager<
      _$ExpenseDatabase,
      $ExpensesTable,
      Expense,
      $$ExpensesTableFilterComposer,
      $$ExpensesTableOrderingComposer,
      $$ExpensesTableAnnotationComposer,
      $$ExpensesTableCreateCompanionBuilder,
      $$ExpensesTableUpdateCompanionBuilder,
      (Expense, $$ExpensesTableReferences),
      Expense,
      PrefetchHooks Function({bool groupId})
    >;
typedef $$CustomCategoriesTableCreateCompanionBuilder =
    CustomCategoriesCompanion Function({
      Value<int> id,
      required String name,
      required String iconName,
      required int colorValue,
      Value<int?> groupId,
    });
typedef $$CustomCategoriesTableUpdateCompanionBuilder =
    CustomCategoriesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> iconName,
      Value<int> colorValue,
      Value<int?> groupId,
    });

class $$CustomCategoriesTableFilterComposer
    extends Composer<_$ExpenseDatabase, $CustomCategoriesTable> {
  $$CustomCategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconName => $composableBuilder(
    column: $table.iconName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CustomCategoriesTableOrderingComposer
    extends Composer<_$ExpenseDatabase, $CustomCategoriesTable> {
  $$CustomCategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconName => $composableBuilder(
    column: $table.iconName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CustomCategoriesTableAnnotationComposer
    extends Composer<_$ExpenseDatabase, $CustomCategoriesTable> {
  $$CustomCategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get iconName =>
      $composableBuilder(column: $table.iconName, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<int> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);
}

class $$CustomCategoriesTableTableManager
    extends
        RootTableManager<
          _$ExpenseDatabase,
          $CustomCategoriesTable,
          CustomCategory,
          $$CustomCategoriesTableFilterComposer,
          $$CustomCategoriesTableOrderingComposer,
          $$CustomCategoriesTableAnnotationComposer,
          $$CustomCategoriesTableCreateCompanionBuilder,
          $$CustomCategoriesTableUpdateCompanionBuilder,
          (
            CustomCategory,
            BaseReferences<
              _$ExpenseDatabase,
              $CustomCategoriesTable,
              CustomCategory
            >,
          ),
          CustomCategory,
          PrefetchHooks Function()
        > {
  $$CustomCategoriesTableTableManager(
    _$ExpenseDatabase db,
    $CustomCategoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CustomCategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CustomCategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CustomCategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> iconName = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<int?> groupId = const Value.absent(),
              }) => CustomCategoriesCompanion(
                id: id,
                name: name,
                iconName: iconName,
                colorValue: colorValue,
                groupId: groupId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String iconName,
                required int colorValue,
                Value<int?> groupId = const Value.absent(),
              }) => CustomCategoriesCompanion.insert(
                id: id,
                name: name,
                iconName: iconName,
                colorValue: colorValue,
                groupId: groupId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CustomCategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$ExpenseDatabase,
      $CustomCategoriesTable,
      CustomCategory,
      $$CustomCategoriesTableFilterComposer,
      $$CustomCategoriesTableOrderingComposer,
      $$CustomCategoriesTableAnnotationComposer,
      $$CustomCategoriesTableCreateCompanionBuilder,
      $$CustomCategoriesTableUpdateCompanionBuilder,
      (
        CustomCategory,
        BaseReferences<
          _$ExpenseDatabase,
          $CustomCategoriesTable,
          CustomCategory
        >,
      ),
      CustomCategory,
      PrefetchHooks Function()
    >;
typedef $$CategoryBudgetsTableCreateCompanionBuilder =
    CategoryBudgetsCompanion Function({
      Value<int> id,
      required String category,
      required double amount,
      Value<DateTime?> createdAt,
      Value<bool> includePastExpenses,
      required int groupId,
    });
typedef $$CategoryBudgetsTableUpdateCompanionBuilder =
    CategoryBudgetsCompanion Function({
      Value<int> id,
      Value<String> category,
      Value<double> amount,
      Value<DateTime?> createdAt,
      Value<bool> includePastExpenses,
      Value<int> groupId,
    });

final class $$CategoryBudgetsTableReferences
    extends
        BaseReferences<
          _$ExpenseDatabase,
          $CategoryBudgetsTable,
          CategoryBudget
        > {
  $$CategoryBudgetsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ExpenseGroupsTable _groupIdTable(_$ExpenseDatabase db) => db
      .expenseGroups
      .createAlias('category_budgets__group_id__expense_groups__id');

  $$ExpenseGroupsTableProcessedTableManager get groupId {
    final $_column = $_itemColumn<int>('group_id')!;

    final manager = $$ExpenseGroupsTableTableManager(
      $_db,
      $_db.expenseGroups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CategoryBudgetsTableFilterComposer
    extends Composer<_$ExpenseDatabase, $CategoryBudgetsTable> {
  $$CategoryBudgetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get includePastExpenses => $composableBuilder(
    column: $table.includePastExpenses,
    builder: (column) => ColumnFilters(column),
  );

  $$ExpenseGroupsTableFilterComposer get groupId {
    final $$ExpenseGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.expenseGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExpenseGroupsTableFilterComposer(
            $db: $db,
            $table: $db.expenseGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CategoryBudgetsTableOrderingComposer
    extends Composer<_$ExpenseDatabase, $CategoryBudgetsTable> {
  $$CategoryBudgetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get includePastExpenses => $composableBuilder(
    column: $table.includePastExpenses,
    builder: (column) => ColumnOrderings(column),
  );

  $$ExpenseGroupsTableOrderingComposer get groupId {
    final $$ExpenseGroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.expenseGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExpenseGroupsTableOrderingComposer(
            $db: $db,
            $table: $db.expenseGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CategoryBudgetsTableAnnotationComposer
    extends Composer<_$ExpenseDatabase, $CategoryBudgetsTable> {
  $$CategoryBudgetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get includePastExpenses => $composableBuilder(
    column: $table.includePastExpenses,
    builder: (column) => column,
  );

  $$ExpenseGroupsTableAnnotationComposer get groupId {
    final $$ExpenseGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.expenseGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExpenseGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.expenseGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CategoryBudgetsTableTableManager
    extends
        RootTableManager<
          _$ExpenseDatabase,
          $CategoryBudgetsTable,
          CategoryBudget,
          $$CategoryBudgetsTableFilterComposer,
          $$CategoryBudgetsTableOrderingComposer,
          $$CategoryBudgetsTableAnnotationComposer,
          $$CategoryBudgetsTableCreateCompanionBuilder,
          $$CategoryBudgetsTableUpdateCompanionBuilder,
          (CategoryBudget, $$CategoryBudgetsTableReferences),
          CategoryBudget,
          PrefetchHooks Function({bool groupId})
        > {
  $$CategoryBudgetsTableTableManager(
    _$ExpenseDatabase db,
    $CategoryBudgetsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoryBudgetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoryBudgetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoryBudgetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<bool> includePastExpenses = const Value.absent(),
                Value<int> groupId = const Value.absent(),
              }) => CategoryBudgetsCompanion(
                id: id,
                category: category,
                amount: amount,
                createdAt: createdAt,
                includePastExpenses: includePastExpenses,
                groupId: groupId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String category,
                required double amount,
                Value<DateTime?> createdAt = const Value.absent(),
                Value<bool> includePastExpenses = const Value.absent(),
                required int groupId,
              }) => CategoryBudgetsCompanion.insert(
                id: id,
                category: category,
                amount: amount,
                createdAt: createdAt,
                includePastExpenses: includePastExpenses,
                groupId: groupId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CategoryBudgetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({groupId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (groupId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.groupId,
                                referencedTable:
                                    $$CategoryBudgetsTableReferences
                                        ._groupIdTable(db),
                                referencedColumn:
                                    $$CategoryBudgetsTableReferences
                                        ._groupIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CategoryBudgetsTableProcessedTableManager =
    ProcessedTableManager<
      _$ExpenseDatabase,
      $CategoryBudgetsTable,
      CategoryBudget,
      $$CategoryBudgetsTableFilterComposer,
      $$CategoryBudgetsTableOrderingComposer,
      $$CategoryBudgetsTableAnnotationComposer,
      $$CategoryBudgetsTableCreateCompanionBuilder,
      $$CategoryBudgetsTableUpdateCompanionBuilder,
      (CategoryBudget, $$CategoryBudgetsTableReferences),
      CategoryBudget,
      PrefetchHooks Function({bool groupId})
    >;

class $ExpenseDatabaseManager {
  final _$ExpenseDatabase _db;
  $ExpenseDatabaseManager(this._db);
  $$ExpenseGroupsTableTableManager get expenseGroups =>
      $$ExpenseGroupsTableTableManager(_db, _db.expenseGroups);
  $$ExpensesTableTableManager get expenses =>
      $$ExpensesTableTableManager(_db, _db.expenses);
  $$CustomCategoriesTableTableManager get customCategories =>
      $$CustomCategoriesTableTableManager(_db, _db.customCategories);
  $$CategoryBudgetsTableTableManager get categoryBudgets =>
      $$CategoryBudgetsTableTableManager(_db, _db.categoryBudgets);
}
