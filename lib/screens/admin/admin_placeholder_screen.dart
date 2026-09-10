import 'package:flutter/material.dart';

import '../../widgets/common/app_card.dart';

class AdminPlaceholderScreen extends StatelessWidget {
  final String title;
  final String description;
  final bool canEdit;

  const AdminPlaceholderScreen({
    super.key,
    required this.title,
    required this.description,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    
                  ),
                ),
                const SizedBox(height: 8),
                Text(description),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(canEdit ? Icons.edit : Icons.visibility),
                    const SizedBox(width: 8),
                    Text(
                      canEdit
                          ? 'صلاحيتك: عرض وإضافة وتعديل واعتماد'
                          : 'صلاحيتك: عرض فقط',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const AppCard(
            child: Text(
              'هذه شاشة تأسيسية. الخطوة التالية هي تحويلها إلى شاشة عمليات كاملة: جدول، بحث، فلترة، إضافة، اعتماد، تصدير PDF/Excel حسب نوع الصلاحية.',
            ),
          ),
        ],
      ),
    );
  }
}


