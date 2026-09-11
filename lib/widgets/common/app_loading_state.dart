import 'package:flutter/material.dart';

/// حالة تحميل موحدة للشاشات الكاملة ومناطق المحتوى.
///
/// التصميم مقصود أن يكون بسيطًا مثل شاشة «المسميات الوظيفية»:
/// مؤشر تحميل في المنتصف بدون بطاقة أو إطار أو قائمة ضيقة حوله.
class AppLoadingState extends StatelessWidget {
  final String label;
  final double fallbackHeight;

  const AppLoadingState({
    super.key,
    this.label = 'جاري تحميل البيانات',
    this.fallbackHeight = 220,
  });

  @override
  Widget build(BuildContext context) {
    final indicator = Semantics(
      container: true,
      liveRegion: true,
      label: label,
      child: const SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // عندما تكون حالة التحميل هي جسم الشاشة، يتم توسيطها في كامل المساحة.
        if (constraints.hasBoundedHeight && constraints.maxHeight.isFinite) {
          return Center(child: indicator);
        }

        // بعض الشاشات تضع حالة التحميل داخل ListView؛ نعطيها مساحة ثابتة
        // حتى لا تظهر كمؤشر صغير ملتصق بأعلى القائمة.
        return SizedBox(
          height: fallbackHeight,
          child: Center(child: indicator),
        );
      },
    );
  }
}
