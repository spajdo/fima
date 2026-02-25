import 'package:fima/domain/entity/key_map_action.dart';

class ActionRegistry {
  const ActionRegistry();

  List<KeyMapAction> get allActions => KeyMapActionDefs.all;

  List<KeyMapAction> get omniPanelActions => KeyMapActionDefs.omniPanelActions;

  KeyMapAction? getById(String id) => KeyMapActionDefs.getById(id);

  String? getDefaultShortcut(String id) =>
      KeyMapActionDefs.getDefaultShortcut(id);
}
