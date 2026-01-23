// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'base_list_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BaseListModel<T> _$BaseListModelFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) =>
    BaseListModel<T>(
      totalCount: (json['totalCount'] as num?)?.toInt(),
      pageSize: (json['pageSize'] as num?)?.toInt(),
      totalPage: (json['totalPage'] as num?)?.toInt(),
      currPage: (json['currPage'] as num?)?.toInt(),
      list: (json['list'] as List<dynamic>?)?.map(fromJsonT).toList(),
    );

Map<String, dynamic> _$BaseListModelToJson<T>(
  BaseListModel<T> instance,
  Object? Function(T value) toJsonT,
) =>
    <String, dynamic>{
      'totalCount': instance.totalCount,
      'pageSize': instance.pageSize,
      'totalPage': instance.totalPage,
      'currPage': instance.currPage,
      'list': instance.list?.map(toJsonT).toList(),
    };
