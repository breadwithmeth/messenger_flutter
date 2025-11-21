# Гайд по использованию адаптивной цветовой схемы

## Обзор

В проекте реализована адаптивная система цветов через класс `AppColors`, которая автоматически подстраивается под светлую/темную тему для обеспечения максимальной читаемости текста.

## Основные принципы

### 1. Цвета текста

Используйте семантические методы вместо жестко заданных цветов:

```dart
// ❌ Плохо - не адаптируется к теме
color: Colors.grey.shade600

// ✅ Хорошо - автоматически адаптируется
color: AppColors.textSecondary(context)
```

#### Доступные варианты:

- `AppColors.textSecondary(context)` - для вторичного текста (метаданные, подписи)
- `AppColors.textTertiary(context)` - для третичного текста (подсказки, time stamps)
- `AppColors.textDisabled(context)` - для неактивных элементов

### 2. Статусные чипы и плашки

Для цветных индикаторов статусов используйте комбинацию фона и текста:

```dart
Container(
  decoration: BoxDecoration(
    color: AppColors.statusBackground(context, Colors.blue),
  ),
  child: Text(
    'Статус',
    style: TextStyle(
      color: AppColors.statusText(context, Colors.blue),
    ),
  ),
)
```

### 3. Семантические цвета

Для стандартных состояний используйте готовые методы:

```dart
// Успех
AppColors.successBackground(context)  // Фон
AppColors.successText(context)        // Текст

// Ошибка
AppColors.errorBackground(context)    // Фон
AppColors.errorText(context)          // Текст

// Предупреждение
AppColors.warningBackground(context)  // Фон
AppColors.warningText(context)        // Текст

// Информация
AppColors.infoBackground(context)     // Фон
AppColors.infoText(context)           // Текст
```

### 4. Специальные элементы

Для назначенных пользователей:

```dart
Container(
  decoration: BoxDecoration(
    color: AppColors.assignedUserBackground(context),
    border: Border.all(
      color: AppColors.assignedUserBorder(context),
    ),
  ),
  child: Row(
    children: [
      Icon(
        Icons.person,
        color: AppColors.assignedUserIcon(context),
      ),
      Text(
        'Имя',
        style: TextStyle(
          color: AppColors.assignedUserText(context),
        ),
      ),
    ],
  ),
)
```

### 5. Разделители и контейнеры

```dart
// Разделитель
color: AppColors.divider(context)

// Фон контейнера
color: AppColors.surfaceContainer(context)

// Приподнятый элемент
color: AppColors.surfaceElevated(context)
```

## Примеры использования

### Пример 1: Карточка со статусом

```dart
Card(
  child: Container(
    decoration: BoxDecoration(
      color: AppColors.surfaceContainer(context),
    ),
    child: Column(
      children: [
        // Заголовок
        Text(
          'Заголовок',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        // Вторичная информация
        Text(
          'Подробности',
          style: TextStyle(
            color: AppColors.textSecondary(context),
          ),
        ),
        // Статус
        Container(
          decoration: BoxDecoration(
            color: AppColors.statusBackground(context, Colors.green),
          ),
          child: Text(
            'Активен',
            style: TextStyle(
              color: AppColors.statusText(context, Colors.green),
            ),
          ),
        ),
      ],
    ),
  ),
)
```

### Пример 2: Сообщение об ошибке

```dart
Container(
  decoration: BoxDecoration(
    color: AppColors.errorBackground(context),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Row(
    children: [
      Icon(
        Icons.error_outline,
        color: AppColors.errorText(context),
      ),
      Text(
        'Произошла ошибка',
        style: TextStyle(
          color: AppColors.errorText(context),
        ),
      ),
    ],
  ),
)
```

## Преимущества

✅ **Автоматическая адаптация** - цвета меняются при переключении темы  
✅ **Гарантированная читаемость** - всегда достаточный контраст  
✅ **Консистентность** - единообразие цветов по всему приложению  
✅ **Простота поддержки** - изменения в одном месте применяются везде  

## Миграция старого кода

При замене жестко заданных цветов следуйте этой таблице:

| Старый код | Новый код |
|------------|-----------|
| `Colors.grey.shade600` | `AppColors.textSecondary(context)` |
| `Colors.grey.shade500` | `AppColors.textTertiary(context)` |
| `Colors.grey.shade700` | `AppColors.textSecondary(context)` |
| `Colors.blue.shade50` | `AppColors.statusBackground(context, Colors.blue)` |
| `Colors.blue.shade900` | `AppColors.statusText(context, Colors.blue)` |
| `Colors.green.shade600` | `AppColors.successText(context)` |
| `Colors.red.shade300` | `AppColors.errorText(context)` |

## Заключение

Используйте `AppColors` для всех цветов, связанных с текстом и статусами. Это обеспечит отличную читаемость как в светлой, так и в темной теме! 🎨
