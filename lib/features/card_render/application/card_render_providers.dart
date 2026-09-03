import 'package:flutter_id_card/features/card_render/application/id_card_renderer.dart';
import 'package:flutter_id_card/features/card_render/application/imposition_service.dart';
import 'package:flutter_id_card/features/card_render/data/template_repository.dart';
import 'package:flutter_id_card/features/card_render/domain/card_template.dart';
import 'package:flutter_id_card/features/data_entry/application/entry_providers.dart';
import 'package:flutter_id_card/shared/models/school_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fonts are loaded once and shared; reloading the TTFs per card would dominate
/// the render time on a 25-up sheet.
final FutureProvider<IdCardRenderer> idCardRendererProvider =
    FutureProvider<IdCardRenderer>((Ref ref) => IdCardRenderer.load());

final Provider<TemplateRepository> templateRepositoryProvider =
    Provider<TemplateRepository>((Ref ref) => TemplateRepository());

final FutureProvider<ImpositionService> impositionServiceProvider =
    FutureProvider<ImpositionService>((Ref ref) async {
  final IdCardRenderer renderer = await ref.watch(idCardRendererProvider.future);
  return ImpositionService(renderer);
});

/// The layout for the active school, resolved against its configured template
/// id and card size.
final FutureProvider<CardTemplate> activeTemplateProvider =
    FutureProvider<CardTemplate>((Ref ref) async {
  final SchoolConfig config = await ref.watch(schoolConfigProvider.future);
  final TemplateRepository repo = ref.watch(templateRepositoryProvider);
  return repo.resolve(
    templateId: config.templateId,
    cardSize: config.cardSize,
  );
});
