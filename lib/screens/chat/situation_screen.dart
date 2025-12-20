import 'dart:io';

import 'package:flutter/material.dart';
import 'package:language_tutor_app/models/situation.dart';
import 'package:language_tutor_app/providers/situation_provider.dart';
import 'package:language_tutor_app/services/api_service.dart';
import 'package:language_tutor_app/ui/theme/app_theme.dart';
import 'package:provider/provider.dart';

class SituationScreen extends StatefulWidget {
  final String language;
  final String languageCode;
  final String level;
  final String character;
  final String topic;

  const SituationScreen({
    super.key,
    required this.language,
    required this.languageCode,
    required this.level,
    required this.character,
    required this.topic,
  });

  @override
  State<SituationScreen> createState() => _SituationScreenState();
}

class _SituationScreenState extends State<SituationScreen> {
  final _myRoleController = TextEditingController();
  final _partnerRoleController = TextEditingController();
  final _circumstancesController = TextEditingController();

  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _prefillFromExisting();
  }

  @override
  void dispose() {
    _myRoleController.dispose();
    _partnerRoleController.dispose();
    _circumstancesController.dispose();
    super.dispose();
  }

  void _prefillFromExisting() {
    final existing =
        context.read<SituationProvider>().getSituation(widget.languageCode);
    if (existing != null) {
      _applySituation(existing);
      return;
    }

    _myRoleController.text = 'Студент уровня ${widget.level}';
    _partnerRoleController.text = '${widget.character}, носитель языка';
    _circumstancesController.text = 'Практикую разговор на тему "${widget.topic}"';
  }

  Future<void> _generateSituation() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);

    try {
      final situation = await ApiService.generateSituation(
        language: widget.language,
        level: widget.level,
        character: widget.character,
        topicHint: '',
      );
      _applySituation(situation);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ситуация сгенерирована')),
        );
      }
    } on HttpException catch (e) {
      final statusCode = _extractStatusCode(e);
      final hint = statusCode == 404
          ? ' Обнови сервер.'
          : statusCode != null
              ? ' Код: $statusCode'
              : '';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось сгенерировать ситуацию.$hint')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось сгенерировать ситуацию')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  void _applySituation(SituationContext situation) {
    _myRoleController.text = situation.myRole;
    _partnerRoleController.text = situation.partnerRole;
    _circumstancesController.text = situation.circumstances;
  }

  Future<void> _saveAndStart() async {
    final myRole = _myRoleController.text.trim();
    final partnerRole = _partnerRoleController.text.trim();
    final circumstances = _circumstancesController.text.trim();

    if ([myRole, partnerRole, circumstances].any((element) => element.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля')),
      );
      return;
    }

    final situation = SituationContext(
      myRole: myRole,
      partnerRole: partnerRole,
      circumstances: circumstances,
    );

    context
        .read<SituationProvider>()
        .setSituation(widget.languageCode, situation);
    if (mounted) {
      Navigator.of(context).pop(situation);
    }
  }

  void _skip() {
    context.read<SituationProvider>().reset(widget.languageCode);
    Navigator.of(context).pop();
  }

  int? _extractStatusCode(HttpException e) {
    final msg = e.message;
    final match = RegExp(r'(\d{3})').firstMatch(msg);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Ситуация диалога'),
        actions: [
          TextButton(
            onPressed: _isGenerating ? null : _saveAndStart,
            child: const Text('Начать'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _LabeledField(
                label: 'Моя роль',
                controller: _myRoleController,
                hint: 'Например: студент на собеседовании',
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              _LabeledField(
                label: 'Роль собеседника',
                controller: _partnerRoleController,
                hint: 'Например: строгий офицер паспортного контроля',
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              _LabeledField(
                label: 'Ситуация / обстоятельства',
                controller: _circumstancesController,
                hint: 'Где и зачем общаетесь? Какие ограничения?',
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: const Text('Сгенерировать'),
                      onPressed: _isGenerating ? null : _generateSituation,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.colorPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.radiusMedium),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _isGenerating ? null : _saveAndStart,
                      child: const Text('Начать'),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: _isGenerating ? null : _skip,
                child: const Text('Пропустить'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.radiusLarge),
        border: Border.all(
          color: AppColors.colorPrimary.withOpacity(0.18),
        ),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Icon(Icons.forum_outlined, color: AppColors.colorPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.language} · уровень ${widget.level}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Собеседник: ${widget.character}. Язык и уровень уже учтены — вводите только роли и обстоятельства.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Можно сделать сцену более смешной или абсурдной — генератор подскажет.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  const _LabeledField({
    required this.label,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.radiusMedium),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }
}
