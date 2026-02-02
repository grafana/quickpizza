import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class LinkItem extends Equatable {
  const LinkItem({
    required this.id,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.url,
    required this.eventName,
  });

  final String id;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String url;
  final String eventName;

  @override
  List<Object?> get props => [id, icon, iconColor, title, subtitle, url, eventName];
}
