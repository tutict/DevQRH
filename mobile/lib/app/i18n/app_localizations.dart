import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum AppLocaleMode { system, english, chinese }

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('zh')];
  static final english = AppLocalizations(const Locale('en'));
  static final chinese = AppLocalizations(const Locale('zh'));

  static const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    DefaultMaterialLocalizations.delegate,
    DefaultWidgetsLocalizations.delegate,
    DefaultCupertinoLocalizations.delegate,
  ];

  static AppLocalizations of(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context) ?? const Locale('en');
    return resolve(locale);
  }

  static AppLocalizations resolve(Locale locale) {
    return locale.languageCode.toLowerCase().startsWith('zh')
        ? chinese
        : english;
  }

  bool get isChinese => locale.languageCode.toLowerCase().startsWith('zh');

  String get appTitle => '应手';
  String get searchTab => isChinese ? '搜索' : 'Search';
  String get agentTab => isChinese ? 'Agent' : 'Agent';
  String get favoritesTab => isChinese ? '收藏' : 'Favorites';
  String get recentTab => isChinese ? '最近' : 'Recent';
  String get settingsTab => isChinese ? '设置' : 'Settings';
  String get catalog => isChinese ? '目录' : 'Catalog';
  String get runbook => isChinese ? '手册' : 'Runbook';
  String get searchSectionTitle => isChinese ? '搜索' : 'Search';
  String get agentTitle => isChinese ? 'Agent 导航' : 'Agent Navigator';
  String get agentInputTitle => isChinese ? '复杂问题输入' : 'Complex issue input';
  String get agentInputHint =>
      'service lag after deploy / timeout query / cpu and db spike';
  String get agentRun => isChinese ? '开始导航' : 'Run agent';
  String get agentQuickPrompts => isChinese ? '示例问题' : 'Prompt ideas';
  String get agentWaitingTitle =>
      isChinese ? '等待问题描述' : 'Waiting for a problem';
  String get agentWaitingDescription => isChinese
      ? '输入一段更复杂的故障描述，Agent 会收敛成推荐手册和排查建议。'
      : 'Enter a more complex incident description and Agent will narrow it into a recommended runbook and next checks.';
  String get ragAnswerTitle => isChinese ? 'RAG 答案' : 'RAG answer';
  String get ragSources => isChinese ? '引用来源' : 'Sources';
  String get ragLocalMode => isChinese ? '本地答案' : 'Local answer';
  String get ragLlmMode => isChinese ? 'LLM 答案' : 'LLM answer';
  String get ragLocalFallbackMode => isChinese ? '本地回退' : 'Local fallback';
  String get agentBestMatch => isChinese ? '推荐 runbook' : 'Recommended runbook';
  String get agentClarifiers => isChinese ? '下一步排查' : 'Next checks';
  String get agentAlternatives => isChinese ? '备选路径' : 'Alternative paths';
  String get agentNoClarifiers => isChinese
      ? '当前没有额外排查提示，可以先打开推荐 runbook。'
      : 'No extra checks yet. Open the recommended runbook first.';
  String get agentNoCandidates => isChinese
      ? 'Agent 还没找到合适的 runbook。试试补充更具体的症状或影响范围。'
      : 'Agent did not find a strong runbook yet. Try adding more specific symptoms or impact.';
  String get agentOpenRunbook => isChinese ? '打开手册' : 'Open runbook';
  String get agentScore => isChinese ? '匹配分' : 'Score';
  String get searchPlaceholder => 'service lag / CPU 100% / timeout query';
  String get recentSearchesTitle => isChinese ? '最近搜索' : 'Recent searches';
  String get suggestionsTitle => isChinese ? '建议' : 'Suggestions';
  String get clear => isChinese ? '清除' : 'Clear';
  String get recentSearchesEmpty => isChinese
      ? '完成第一次搜索后，这里会显示最近搜索。'
      : 'Recent searches appear after your first lookup.';
  String get suggestionsEmpty =>
      isChinese ? '当前输入还没有建议。' : 'No suggestion yet for this input.';
  String get quickSearches => isChinese ? '快捷搜索' : 'Quick searches';
  String get contentStatus => isChinese ? '内容状态' : 'Content status';
  String get manageLibrary => isChinese ? '管理资料库' : 'Manage library';
  String get topMatches => isChinese ? '最佳匹配' : 'Top matches';
  String get waitingForInput => isChinese ? '等待输入' : 'Waiting for input';
  String get waitingForInputDescription => isChinese
      ? '输入一个症状后即可对 runbook 进行排序。'
      : 'Enter one symptom to rank the top runbooks.';
  String get searchFailed => isChinese ? '搜索失败' : 'Search failed';
  String get agentFailed =>
      isChinese ? 'Agent 导航失败' : 'Agent navigation failed';
  String get firstActionCopied =>
      isChinese ? '已复制第一步操作' : 'First action copied';
  String matchSignalsFor(String query) => isChinese
      ? '“${query.trim()}” 的匹配信号'
      : 'Match signals for "${query.trim()}"';
  String get showPreview => isChinese ? '展开预览' : 'Show preview';
  String get hidePreview => isChinese ? '收起预览' : 'Hide preview';
  String get copyFirstAction => isChinese ? '复制第一步' : 'Copy first action';
  String runbooksCount(int count) =>
      isChinese ? '$count 个 runbook' : '$count runbooks';
  String favoritesCount(int count) =>
      isChinese ? '$count 个收藏' : '$count favorites';
  String recentCount(int count) => isChinese ? '$count 条最近记录' : '$count recent';
  String searchesCount(int count) =>
      isChinese ? '$count 条搜索' : '$count searches';
  String get importedContentFallbackNotice => isChinese
      ? '导入其他包时，当前知识库仍然可用。'
      : 'Current handbook stays available while you import another package.';
  String sourceLabel(String label) => label;
  String get bundledLibrary => isChinese ? '内置资料库' : 'bundled library';
  String get importedPackage => isChinese ? '导入包' : 'imported package';
  String get noLibrary => isChinese ? '无资料库' : 'no library';
  String versionFromSource(String version, String source) =>
      isChinese ? '版本 $version，来源：$source。' : 'Version $version from $source.';
  String versionFromSourceUpdated(
    String version,
    String source,
    String updatedAt,
  ) => isChinese
      ? '版本 $version，来源：$source，更新于 $updatedAt。'
      : 'Version $version from $source, updated $updatedAt.';
  String get copyTools => isChinese ? '复制工具' : 'Copy tools';
  String get copySummary => isChinese ? '复制摘要' : 'Copy summary';
  String get copySteps => isChinese ? '复制步骤' : 'Copy steps';
  String get runbookSummaryCopied =>
      isChinese ? '已复制手册摘要' : 'Runbook summary copied';
  String get immediateStepsCopied =>
      isChinese ? '已复制立即执行步骤' : 'Immediate steps copied';
  String get immediateActions => isChinese ? '立即动作' : 'Immediate Actions';
  String get decisionTree => isChinese ? '决策树' : 'Decision Tree';
  String get symptoms => isChinese ? '症状' : 'Symptoms';
  String get rootCause => isChinese ? '根因' : 'Root Cause';
  String get longTermFix => isChinese ? '长期修复' : 'Long-term Fix';
  String get recent => isChinese ? '最近查看' : 'Recent';
  String get related => isChinese ? '相关项' : 'Related';
  String get checklistSummaryId => 'ID';
  String get checklistSummaryKeywords => isChinese ? '关键词' : 'Keywords';
  String get checklistSummarySymptoms => isChinese ? '症状' : 'Symptoms';
  String get checklistSummaryImmediateActions =>
      isChinese ? '立即动作' : 'Immediate actions';
  String get settingsTitle => isChinese ? '设置' : 'Settings';
  String get libraryStatus => isChinese ? '资料库状态' : 'Library status';
  String get ready => isChinese ? '已就绪' : 'Ready';
  String get empty => isChinese ? '为空' : 'Empty';
  String get handbookLibrary => isChinese ? '手册资料库' : 'Handbook library';
  String get version => isChinese ? '版本' : 'Version';
  String get source => isChinese ? '来源' : 'Source';
  String get updated => isChinese ? '更新时间' : 'Updated';
  String get importPackage => isChinese ? '导入包' : 'Import package';
  String get useBuiltInLibrary =>
      isChinese ? '使用内置资料库' : 'Use built-in library';
  String get lastIssue => isChinese ? '最近问题' : 'Last issue';
  String get issue => isChinese ? '问题' : 'Issue';
  String get fallback => isChinese ? '回退策略' : 'Fallback';
  String get currentHandbookStaysAvailable =>
      isChinese ? '当前手册仍然可用。' : 'Current handbook stays available.';
  String get noHandbookLoaded =>
      isChinese ? '当前没有加载任何手册。' : 'No handbook is loaded.';
  String get runbooksLabel => isChinese ? '手册数量' : 'Runbooks';
  String get notLoadedLabel => isChinese ? '未加载' : 'Not loaded';
  String get builtInLabel => isChinese ? '内置' : 'Built-in';
  String get selectedPackageEmpty =>
      isChinese ? '所选包为空。' : 'Selected package is empty.';
  String importedPackageMessage(String fileName) =>
      isChinese ? '已导入 $fileName' : 'Imported $fileName';
  String get importFailed => isChinese ? '导入失败' : 'Import failed';
  String get builtInLibraryRestored =>
      isChinese ? '已恢复内置资料库' : 'Built-in library restored';
  String get displayLanguage => isChinese ? '显示语言' : 'Display language';
  String get language => isChinese ? '语言' : 'Language';
  String get followSystem => isChinese ? '跟随系统' : 'Follow system';
  String get englishLabel => 'English';
  String get chineseLabel => isChinese ? '简体中文' : 'Simplified Chinese';
  String languageModeLabel(AppLocaleMode mode) {
    return switch (mode) {
      AppLocaleMode.system => followSystem,
      AppLocaleMode.english => englishLabel,
      AppLocaleMode.chinese => chineseLabel,
    };
  }

  String get displayTheme => isChinese ? '显示主题' : 'Display theme';
  String get theme => isChinese ? '主题' : 'Theme';
  String get lightThemeLabel => isChinese ? '亮色' : 'Light';
  String get darkThemeLabel => isChinese ? '暗色' : 'Dark';
  String themeModeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => followSystem,
      ThemeMode.light => lightThemeLabel,
      ThemeMode.dark => darkThemeLabel,
    };
  }

  String get favoritesTitle => isChinese ? '收藏' : 'Favorites';
  String get savedRunbooks => isChinese ? '已保存 runbook' : 'Saved runbooks';
  String get saved => isChinese ? '已保存' : 'saved';
  String get viewed => isChinese ? '已查看' : 'viewed';
  String get noFavorites => isChinese ? '暂无收藏' : 'No favorites';
  String get bookmarkRunbooksHint =>
      isChinese ? '收藏 runbook 以便快速访问。' : 'Bookmark runbooks for quick access.';
  String get loadingRunbook =>
      isChinese ? '正在加载 runbook...' : 'Loading runbook...';
  String get runbookNotCachedYet =>
      isChinese ? '该 runbook 内容尚未缓存。' : 'Runbook content is not cached yet.';
  String collectionSummary(
    int count,
    int totalCount,
    String activityLabel,
    String sourceLabel,
  ) {
    final total = totalCount > 0
        ? (isChinese ? '共 $totalCount 个 runbook' : 'of $totalCount runbooks')
        : (isChinese ? '支持离线使用' : 'ready offline');
    return isChinese
        ? '$activityLabel $count 条，$total，来源 ${sourceLabel.toLowerCase()}。'
        : '$count $activityLabel, $total, source ${sourceLabel.toLowerCase()}.';
  }

  String get recentTitle => isChinese ? '最近' : 'Recent';
  String get recentActivity => isChinese ? '最近活动' : 'Recent activity';
  String get noRecentRunbooks =>
      isChinese ? '暂无最近查看的 runbook' : 'No recent runbooks';
  String get openRunbookHint => isChinese
      ? '打开一个 runbook 后会显示在这里。'
      : 'Open a runbook and it appears here.';
  String get findRunbooks => isChinese ? '查找 runbook' : 'Find runbooks';
  String get filterRunbooksHint => isChinese
      ? '按标题、症状、关键词、根因或修复方案筛选。'
      : 'Filter by title, symptom, keyword, cause, or fix.';
  String get views => isChinese ? '视图' : 'Views';
  String get saveView => isChinese ? '保存视图' : 'Save view';
  String get saveViewHint => isChinese
      ? '保存当前筛选条件，便于一键复用。'
      : 'Save the current filter set for one-tap reuse.';
  String get filterPlaceholder => 'mysql / timeout / memory leak';
  String get tags => isChinese ? '标签' : 'Tags';
  String get clearTags => isChinese ? '清除标签' : 'Clear tags';
  String get favoritesOnly => isChinese ? '仅收藏' : 'Favorites only';
  String get recentTags => isChinese ? '最近标签' : 'Recent tags';
  String get loading => isChinese ? '加载中...' : 'Loading...';
  String get sort => isChinese ? '排序' : 'Sort';
  String get noHandbookLoadedTitle =>
      isChinese ? '未加载手册' : 'No handbook loaded';
  String get noHandbookLoadedDescription => isChinese
      ? '请在设置中恢复内置资料库，或导入一个手册包。'
      : 'Restore the built-in library or import a handbook package from Settings.';
  String get openSettingsForImportIssue => isChinese
      ? '请打开设置，查看最近一次导入问题。'
      : 'Open Settings and review the last import issue.';
  String get noMatchingRunbooks =>
      isChinese ? '没有匹配的 runbook' : 'No matching runbooks';
  String get noRunbookContentAvailable =>
      isChinese ? '当前没有可用的 runbook 内容。' : 'No runbook content is available.';
  String get broaderFilterHint => isChinese
      ? '试试更宽泛的关键词、其他标签，或者清空当前筛选。'
      : 'Try a broader keyword, another tag, or clear the current filter.';
  String get allRunbooks => isChinese ? '全部 runbook' : 'All runbooks';
  String filteredBy(String labels) =>
      isChinese ? '已筛选：$labels' : 'Filtered: $labels';
  String matchedRunbooks(int count) => isChinese
      ? '匹配到 $count 个 runbook'
      : '$count runbook${count == 1 ? '' : 's'} matched';
  String get saveViewDialogTitle => isChinese ? '保存视图' : 'Save view';
  String get saveViewDialogHint => 'DB focus / production triage';
  String get cancel => isChinese ? '取消' : 'Cancel';
  String get save => isChinese ? '保存' : 'Save';
  String matchedSummary(int matchedCount, int totalCount) => isChinese
      ? '$matchedCount / $totalCount 条匹配'
      : '$matchedCount / $totalCount matched';
  String sortedBy(String sortLabel) =>
      isChinese ? '排序：$sortLabel' : 'Sorted $sortLabel';
  String searchSummary(String value) =>
      isChinese ? '搜索“$value”' : 'Search "$value"';
  String tagSummary(String tag) => isChinese ? '标签 $tag' : 'Tag $tag';
  String contentSourceShortLabel(String label) => label;
  String get bundledShort => isChinese ? '内置' : 'Bundled';
  String get importedShort => isChinese ? '导入' : 'Imported';
  String get offlineShort => isChinese ? '离线' : 'Offline';
  String get titleAsc => isChinese ? '标题 A-Z' : 'Title A-Z';
  String get titleDesc => isChinese ? '标题 Z-A' : 'Title Z-A';
  String get favoritesFirst => isChinese ? '收藏优先' : 'Favorites first';
  String get mostSymptoms => isChinese ? '症状最多' : 'Most symptoms';
  String settingsOverview(
    String version,
    String sourceLabel,
    String readinessLabel,
  ) => isChinese
      ? '版本 $version，来源 ${sourceLabel.toLowerCase()}，状态：$readinessLabel。'
      : 'Version $version, source ${sourceLabel.toLowerCase()}, ${readinessLabel.toLowerCase()}.';
  String matchHintTitleId() => isChinese ? '标题或 ID 命中' : 'title/id match';
  String matchHintKeyword(String token) =>
      isChinese ? '关键词 $token' : 'keyword $token';
  String matchHintSymptom(String token) =>
      isChinese ? '症状 $token' : 'symptom $token';
  String matchHintContext(String token) =>
      isChinese ? '上下文 $token' : 'context $token';
  String matchHintSynonym(String token, String synonym) =>
      isChinese ? '同义词 $token->$synonym' : 'synonym $token->$synonym';
  String matchHintSymptomSynonym(String token, String synonym) =>
      isChinese ? '症状同义词 $token->$synonym' : 'symptom synonym $token->$synonym';
  String matchHintBroadOverlap() =>
      isChinese ? '文本存在宽泛重叠' : 'broad text overlap';
  String previewSymptoms(String value) =>
      isChinese ? '症状：$value' : 'Symptoms: $value';
  String previewNext(String value) => isChinese ? '下一步：$value' : 'Next: $value';
  String previewRootCause(String value) =>
      isChinese ? '根因：$value' : 'Root cause: $value';

  String localizeContentError(String message) {
    if (!isChinese) {
      return message;
    }
    if (message ==
        'Imported package could not be loaded. Using built-in library.') {
      return '导入包无法加载，已回退到内置资料库。';
    }
    if (message == 'Import failed') {
      return importFailed;
    }
    if (message == 'Content package must be a JSON object.') {
      return '内容包必须是一个 JSON 对象。';
    }
    if (message == 'Content package must include at least one checklist.') {
      return '内容包至少需要包含一个 checklist。';
    }
    if (message ==
        'Content package checklists must include non-empty id and title values.') {
      return '内容包中的 checklist 必须包含非空的 id 和 title。';
    }
    if (message == 'Content package is missing "matchingConfig".') {
      return '内容包缺少 "matchingConfig"。';
    }
    if (message == 'Content package is missing "checklists".') {
      return '内容包缺少 "checklists"。';
    }
    if (message.startsWith('Import failed: ')) {
      return '导入失败：${message.substring('Import failed: '.length)}';
    }
    if (message.startsWith('Checklist not found: ')) {
      return '未找到 checklist：${message.substring('Checklist not found: '.length)}';
    }
    return message;
  }

  String localizeMatchHint(String hint) {
    if (!isChinese) {
      return hint;
    }
    if (hint == 'title/id match') {
      return matchHintTitleId();
    }
    if (hint == 'broad text overlap') {
      return matchHintBroadOverlap();
    }
    if (hint.startsWith('keyword ')) {
      return matchHintKeyword(hint.substring('keyword '.length));
    }
    if (hint.startsWith('symptom synonym ')) {
      final payload = hint.substring('symptom synonym '.length);
      final parts = payload.split('->');
      if (parts.length == 2) {
        return matchHintSymptomSynonym(parts[0], parts[1]);
      }
    }
    if (hint.startsWith('symptom ')) {
      return matchHintSymptom(hint.substring('symptom '.length));
    }
    if (hint.startsWith('context ')) {
      return matchHintContext(hint.substring('context '.length));
    }
    if (hint.startsWith('synonym ')) {
      final payload = hint.substring('synonym '.length);
      final parts = payload.split('->');
      if (parts.length == 2) {
        return matchHintSynonym(parts[0], parts[1]);
      }
    }
    return hint;
  }

  String localizeClarifier(String value) {
    if (!isChinese) {
      return value;
    }
    if (value.startsWith('check: ')) {
      return '检查：${value.substring('check: '.length)}';
    }
    return value;
  }
}

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
