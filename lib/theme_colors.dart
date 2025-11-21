import 'package:flutter/material.dart';

/// Адаптивные цвета, которые автоматически подстраиваются под светлую/темную тему
class AppColors {
  // Приватный конструктор
  AppColors._();

  /// Цвет текста с пониженной яркостью (для вторичного текста)
  static Color textSecondary(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? Colors.grey.shade400
        : Colors.grey.shade700;
  }

  /// Цвет текста с сильно пониженной яркостью (для подсказок)
  static Color textTertiary(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? Colors.grey.shade500
        : Colors.grey.shade600;
  }

  /// Цвет текста для неактивных элементов
  static Color textDisabled(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? Colors.grey.shade600
        : Colors.grey.shade500;
  }

  /// Цвет фона для статус-чипов (светлые плашки)
  static Color statusBackground(BuildContext context, Color baseColor) {
    final brightness = Theme.of(context).brightness;
    if (brightness == Brightness.dark) {
      // В темной теме используем более темный оттенок
      return baseColor.withValues(alpha: 0.25);
    } else {
      // В светлой теме используем светлый оттенок
      return Color.alphaBlend(baseColor.withValues(alpha: 0.15), Colors.white);
    }
  }

  /// Цвет текста для статус-чипов
  static Color statusText(BuildContext context, Color baseColor) {
    final brightness = Theme.of(context).brightness;
    if (brightness == Brightness.dark) {
      // В темной теме используем более светлый цвет для читаемости
      return baseColor.withValues(
        red: (baseColor.r + 0.3).clamp(0.0, 1.0),
        green: (baseColor.g + 0.3).clamp(0.0, 1.0),
        blue: (baseColor.b + 0.3).clamp(0.0, 1.0),
      );
    } else {
      // В светлой теме используем более темный цвет
      return baseColor.withValues(
        red: (baseColor.r * 0.6).clamp(0.0, 1.0),
        green: (baseColor.g * 0.6).clamp(0.0, 1.0),
        blue: (baseColor.b * 0.6).clamp(0.0, 1.0),
      );
    }
  }

  /// Цвет для разделителей
  static Color divider(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
  }

  /// Цвет фона для карточек/контейнеров
  static Color surfaceContainer(BuildContext context) {
    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }

  /// Цвет фона для приподнятых элементов
  static Color surfaceElevated(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? Theme.of(context).colorScheme.surface.withValues(
            red: (Theme.of(context).colorScheme.surface.r + 0.05).clamp(
              0.0,
              1.0,
            ),
            green: (Theme.of(context).colorScheme.surface.g + 0.05).clamp(
              0.0,
              1.0,
            ),
            blue: (Theme.of(context).colorScheme.surface.b + 0.05).clamp(
              0.0,
              1.0,
            ),
          )
        : Colors.white;
  }

  // Семантические цвета со статусами
  static const Color successBase = Colors.green;
  static const Color errorBase = Colors.red;
  static const Color warningBase = Colors.orange;
  static const Color infoBase = Colors.blue;

  /// Цвет успеха (фон)
  static Color successBackground(BuildContext context) {
    return statusBackground(context, successBase);
  }

  /// Цвет успеха (текст)
  static Color successText(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? Colors.green.shade300
        : Colors.green.shade800;
  }

  /// Цвет ошибки (фон)
  static Color errorBackground(BuildContext context) {
    return statusBackground(context, errorBase);
  }

  /// Цвет ошибки (текст)
  static Color errorText(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? Colors.red.shade300
        : Colors.red.shade800;
  }

  /// Цвет предупреждения (фон)
  static Color warningBackground(BuildContext context) {
    return statusBackground(context, warningBase);
  }

  /// Цвет предупреждения (текст)
  static Color warningText(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? Colors.orange.shade300
        : Colors.orange.shade800;
  }

  /// Цвет информации (фон)
  static Color infoBackground(BuildContext context) {
    return statusBackground(context, infoBase);
  }

  /// Цвет информации (текст)
  static Color infoText(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? Colors.blue.shade300
        : Colors.blue.shade800;
  }

  /// Цвет для назначенного пользователя (фон)
  static Color assignedUserBackground(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? Colors.blue.withValues(alpha: 0.25)
        : Colors.blue.shade50;
  }

  /// Цвет для назначенного пользователя (текст)
  static Color assignedUserText(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? Colors.blue.shade300
        : Colors.blue.shade900;
  }

  /// Цвет для назначенного пользователя (иконка)
  static Color assignedUserIcon(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? Colors.blue.shade400
        : Colors.blue.shade700;
  }

  /// Цвет для назначенного пользователя (граница)
  static Color assignedUserBorder(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? Colors.blue.shade700
        : Colors.blue.shade200;
  }
}
