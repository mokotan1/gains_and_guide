import 'package:flutter/foundation.dart';

@immutable
class CoachingMessage {
  final String role;
  final String content;

  const CoachingMessage({required this.role, required this.content});

  factory CoachingMessage.fromJson(Map<String, dynamic> json) {
    final role = json['role'];
    final content = json['content'];

    if (role is! String || role.isEmpty) {
      throw FormatException('CoachingMessage requires a non-empty "role"');
    }
    if (content is! String || content.isEmpty) {
      throw FormatException('CoachingMessage requires a non-empty "content"');
    }

    return CoachingMessage(role: role, content: content);
  }

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

@immutable
class CoachingExample {
  final String id;
  final String category;
  final List<String> tags;
  final String difficulty;
  final List<CoachingMessage> conversations;

  const CoachingExample({
    required this.id,
    required this.category,
    required this.tags,
    required this.difficulty,
    required this.conversations,
  });

  factory CoachingExample.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final category = json['category'];

    if (id is! String || id.isEmpty) {
      throw FormatException('CoachingExample requires a non-empty "id"');
    }
    if (category is! String || category.isEmpty) {
      throw FormatException('CoachingExample requires a non-empty "category"');
    }

    final rawTags = json['tags'] as List<dynamic>? ?? [];
    final rawConversations = json['conversations'] as List<dynamic>? ?? [];

    if (rawConversations.isEmpty) {
      throw FormatException('CoachingExample "$id" must have at least one conversation');
    }

    return CoachingExample(
      id: id,
      category: category,
      tags: rawTags.map((t) => t.toString()).toList(growable: false),
      difficulty: (json['difficulty'] as String?) ?? 'intermediate',
      conversations: rawConversations
          .map((c) => CoachingMessage.fromJson(c as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  bool matchesAny(Set<String> keywords) {
    return tags.any(keywords.contains) || keywords.contains(category);
  }
}

@immutable
class CoachingCategory {
  final String id;
  final String name;
  final String description;
  final String systemInstruction;

  const CoachingCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.systemInstruction,
  });

  factory CoachingCategory.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw FormatException('CoachingCategory requires a non-empty "id"');
    }

    return CoachingCategory(
      id: id,
      name: (json['name'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      systemInstruction: (json['system_instruction'] as String?) ?? '',
    );
  }
}

@immutable
class CoachingKnowledgeBase {
  final String version;
  final List<CoachingCategory> categories;
  final List<CoachingExample> examples;

  const CoachingKnowledgeBase({
    required this.version,
    required this.categories,
    required this.examples,
  });

  factory CoachingKnowledgeBase.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['categories'] as List<dynamic>? ?? [];
    final rawExamples = json['examples'] as List<dynamic>? ?? [];

    return CoachingKnowledgeBase(
      version: (json['version'] as String?) ?? '0.0.0',
      categories: rawCategories
          .map((c) => CoachingCategory.fromJson(c as Map<String, dynamic>))
          .toList(growable: false),
      examples: rawExamples
          .map((e) => CoachingExample.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  List<CoachingExample> findByCategory(String categoryId) {
    return examples.where((e) => e.category == categoryId).toList();
  }

  CoachingCategory? getCategoryById(String categoryId) {
    try {
      return categories.firstWhere((c) => c.id == categoryId);
    } catch (_) {
      return null;
    }
  }
}
