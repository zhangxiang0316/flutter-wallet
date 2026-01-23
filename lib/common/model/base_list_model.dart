import 'package:json_annotation/json_annotation.dart';

part 'base_list_model.g.dart';

@JsonSerializable(
    explicitToJson: true,
    fieldRename: FieldRename.snake,
    genericArgumentFactories: true)
class BaseListModel<T> {
  @JsonKey(name: 'totalCount')
  final int? totalCount;
  @JsonKey(name: 'pageSize')
  final int? pageSize;
  @JsonKey(name: 'totalPage')
  final int? totalPage;
  @JsonKey(name: 'currPage')
  final int? currPage;
  final List<T>? list;

  const BaseListModel({
    this.totalCount,
    this.pageSize,
    this.totalPage,
    this.currPage,
    this.list,
  });

  // 使用泛型和工厂构造函数
  factory BaseListModel.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) =>
      _$BaseListModelFromJson(json, fromJsonT);

  // 需要定义 toJson 方法
  Map<String, dynamic> toJson(Object Function(T value) toJsonT) =>
      _$BaseListModelToJson(this, toJsonT);
}
