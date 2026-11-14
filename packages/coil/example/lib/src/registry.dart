import 'package:coil_example/src/pages/components/accordion_page.dart';
import 'package:coil_example/src/pages/components/badge_page.dart';
import 'package:coil_example/src/pages/components/banner_page.dart';
import 'package:coil_example/src/pages/components/breadcrumb_page.dart';
import 'package:coil_example/src/pages/components/button_page.dart';
import 'package:coil_example/src/pages/components/calendar_page.dart';
import 'package:coil_example/src/pages/components/card_page.dart';
import 'package:coil_example/src/pages/components/carousel_dots_page.dart';
import 'package:coil_example/src/pages/components/chat_message_page.dart';
import 'package:coil_example/src/pages/components/checkbox_group_page.dart';
import 'package:coil_example/src/pages/components/checkbox_page.dart';
import 'package:coil_example/src/pages/components/combobox_page.dart';
import 'package:coil_example/src/pages/components/command_menu_page.dart';
import 'package:coil_example/src/pages/components/context_menu_page.dart';
import 'package:coil_example/src/pages/components/data_table_page.dart';
import 'package:coil_example/src/pages/components/date_picker_page.dart';
import 'package:coil_example/src/pages/components/dialog_page.dart';
import 'package:coil_example/src/pages/components/dropdown_page.dart';
import 'package:coil_example/src/pages/components/field_page.dart';
import 'package:coil_example/src/pages/components/file_thumbnail_page.dart';
import 'package:coil_example/src/pages/components/input_copy_page.dart';
import 'package:coil_example/src/pages/components/input_group_page.dart';
import 'package:coil_example/src/pages/components/input_message_page.dart';
import 'package:coil_example/src/pages/components/input_page.dart';
import 'package:coil_example/src/pages/components/queued_stack_page.dart';
import 'package:coil_example/src/pages/components/radio_group_page.dart';
import 'package:coil_example/src/pages/components/scroll_area_page.dart';
import 'package:coil_example/src/pages/components/select_page.dart';
import 'package:coil_example/src/pages/components/sidebar_page.dart';
import 'package:coil_example/src/pages/components/skeleton_page.dart';
import 'package:coil_example/src/pages/components/slider_page.dart';
import 'package:coil_example/src/pages/components/switch_page.dart';
import 'package:coil_example/src/pages/components/table_page.dart';
import 'package:coil_example/src/pages/components/tabs_page.dart';
import 'package:coil_example/src/pages/components/textarea_page.dart';
import 'package:coil_example/src/pages/components/thinking_steps_page.dart';
import 'package:coil_example/src/pages/components/toggle_group_page.dart';
import 'package:coil_example/src/pages/components/tooltip_page.dart';
import 'package:coil_example/src/pages/foundations/colors_page.dart';
import 'package:coil_example/src/pages/foundations/motion_page.dart';
import 'package:coil_example/src/pages/foundations/shapes_page.dart';
import 'package:coil_example/src/pages/foundations/spacing_page.dart';
import 'package:coil_example/src/pages/foundations/type_page.dart';
import 'package:flutter/widgets.dart';

/// The home screen's groups: foundations, then DESIGN.md §14's sections.
enum CatalogGroup {
  foundations('Foundations'),
  leafControls('Leaf controls'),
  groupedControls('Grouped controls'),
  menusAndOverlays('Menus and overlays'),
  layoutAndDisplay('Layout and display'),
  shellAndComposites('Shell and composites');

  const CatalogGroup(this.title);

  final String title;
}

/// One catalog page. Each page file declares its entry next to the page:
///
/// ```dart
/// const buttonEntry = CatalogEntry(
///   slug: 'button',
///   title: 'Button',
///   group: .leafControls,
///   summary: 'Five variants, loading, selected and icon-only.',
///   page: ButtonPage.new,
/// );
/// ```
@immutable
class CatalogEntry {
  const CatalogEntry({
    required this.slug,
    required this.title,
    required this.group,
    required this.summary,
    required this.page,
  });

  /// The URL segment, unique in the catalog.
  final String slug;

  /// The name on the home screen and in the page header. For components,
  /// the name DESIGN.md §14 uses, so the planned list can skip it.
  final String title;

  final CatalogGroup group;

  /// One line on the home screen.
  final String summary;

  /// Builds the page.
  final Widget Function() page;

  String get path =>
      '${group == CatalogGroup.foundations ? 'foundations' : 'components'}/$slug';
}

/// Every page, in home-screen order within its group. To add a component:
/// write `lib/src/pages/components/<name>_page.dart` with its page and
/// `const <name>Entry`, then add the entry here.
const catalogEntries = <CatalogEntry>[
  colorsEntry,
  typeEntry,
  spacingEntry,
  shapesEntry,
  motionEntry,
  buttonEntry,
  badgeEntry,
  skeletonEntry,
  checkboxEntry,
  switchEntry,
  inputEntry,
  textareaEntry,
  fieldEntry,
  checkboxGroupEntry,
  radioGroupEntry,
  sliderEntry,
  toggleGroupEntry,
  tabsEntry,
  inputGroupEntry,
  inputCopyEntry,
  selectEntry,
  dialogEntry,
  tooltipEntry,
  dropdownEntry,
  contextMenuEntry,
  comboboxEntry,
  commandMenuEntry,
  sidebarEntry,
  calendarEntry,
  datePickerEntry,
  inputMessageEntry,
  queuedStackEntry,
  fileThumbnailEntry,
  dataTableEntry,
  accordionEntry,
  cardEntry,
  tableEntry,
  bannerEntry,
  breadcrumbEntry,
  thinkingStepsEntry,
  carouselDotsEntry,
  chatMessageEntry,
  scrollAreaEntry,
];

/// Every component DESIGN.md §14 specifies, by group. The home screen lists
/// the ones without a [CatalogEntry] yet as planned.
const designComponents = <CatalogGroup, List<String>>{
  CatalogGroup.leafControls: [
    'Button',
    'Badge',
    'Checkbox',
    'Switch',
    'Input',
    'Textarea',
    'Skeleton',
  ],
  CatalogGroup.groupedControls: [
    'Field',
    'CheckboxGroup',
    'RadioGroup',
    'ToggleGroup',
    'Slider',
    'Tabs',
    'InputGroup',
    'InputCopy',
  ],
  CatalogGroup.menusAndOverlays: [
    'Dialog',
    'Tooltip',
    'Dropdown',
    'Select',
    'ContextMenu',
    'Combobox',
    'CommandMenu',
  ],
  CatalogGroup.layoutAndDisplay: [
    'Accordion',
    'Card',
    'Table',
    'Banner',
    'Breadcrumb',
    'ThinkingSteps',
    'CarouselDots',
    'ChatMessage',
    'ScrollArea',
  ],
  CatalogGroup.shellAndComposites: [
    'Sidebar',
    'Calendar',
    'DatePicker',
    'InputMessage',
    'QueuedStack',
    'FileThumbnail',
    'DataTable',
  ],
};
