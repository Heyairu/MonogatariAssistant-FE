import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "bin/file.dart";
import "modules/baseinfoview.dart" as BaseInfoModule;
import "modules/chapterselectionview.dart" as ChapterModule;

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "物語Assistant",
      theme: ThemeData(
        primarySwatch: Colors.lightBlue,
        useMaterial3: true,
      ),
      home: const ContentView(),
    );
  }
}

// 數據模型類別（BaseInfoData, ChapterData, SegmentData 現在從模組導入）

class SceneData {
  String sceneName;
  String sceneUUID;
  
  SceneData({
    required this.sceneName,
    String? sceneUUID,
  }) : sceneUUID = sceneUUID ?? DateTime.now().millisecondsSinceEpoch.toString();
}

class StoryEventData {
  String storyEvent;
  List<SceneData> scenes;
  String memo;
  String storyEventUUID;
  
  StoryEventData({
    required this.storyEvent,
    required this.scenes,
    required this.memo,
    String? storyEventUUID,
  }) : storyEventUUID = storyEventUUID ?? DateTime.now().millisecondsSinceEpoch.toString();
}

class StorylineData {
  String storylineName;
  String storylineType;
  List<StoryEventData> scenes;
  String memo;
  String chapterUUID;
  
  StorylineData({
    required this.storylineName,
    required this.storylineType,
    required this.scenes,
    required this.memo,
    String? chapterUUID,
  }) : chapterUUID = chapterUUID ?? DateTime.now().millisecondsSinceEpoch.toString();
}

class Location {
  String localName;
  String description;
  String locationUUID;
  
  Location({
    required this.localName,
    this.description = "",
    String? locationUUID,
  }) : locationUUID = locationUUID ?? DateTime.now().millisecondsSinceEpoch.toString();
}

class CharacterProfile {
  String name;
  String description;
  String characterUUID;
  
  CharacterProfile({
    this.name = "新角色",
    this.description = "",
    String? characterUUID,
  }) : characterUUID = characterUUID ?? DateTime.now().millisecondsSinceEpoch.toString();
}

// 主要 ContentView
class ContentView extends StatefulWidget {
  const ContentView({super.key});

  @override
  State<ContentView> createState() => _ContentViewState();
}

class _ContentViewState extends State<ContentView> {
  // 狀態變數
  int slidePage = 0;
  int autoSaveTime = 1;
  
  // 主編輯器文字
  String contentText = "";
  final TextEditingController textController = TextEditingController();
  
  // 數據狀態
  BaseInfoModule.BaseInfoData baseInfoData = BaseInfoModule.BaseInfoData();
  List<ChapterModule.SegmentData> segmentsData = [
    ChapterModule.SegmentData(
      segmentName: "Seg 1",
      chapters: [ChapterModule.ChapterData(chapterName: "Chapter 1", chapterContent: "")],
    )
  ];
  
  List<StorylineData> outlineData = [
    StorylineData(
      storylineName: "主線 1",
      storylineType: "起",
      scenes: [
        StoryEventData(
          storyEvent: "事件 1",
          scenes: [SceneData(sceneName: "場景 A")],
          memo: ""
        )
      ],
      memo: ""
    )
  ];
  
  List<Location> worldSettingsData = [Location(localName: "全部")];
  List<CharacterProfile> characterData = [CharacterProfile()];
  
  // 選取狀態
  String? selectedSegID;
  String? selectedChapID;
  int totalWords = 0;
  
  // 檔案狀態
  ProjectFile? currentProject;
  bool showingError = false;
  String errorMessage = "";
  bool isLoading = false;
  
  // 同步狀態標記 - 防止在同步期間觸發循環更新
  bool _isSyncing = false;
  
  @override
  void initState() {
    super.initState();
    
    // 初始化選取項目和編輯器內容
    if (segmentsData.isNotEmpty && segmentsData[0].chapters.isNotEmpty) {
      selectedSegID = segmentsData[0].segmentUUID;
      selectedChapID = segmentsData[0].chapters[0].chapterUUID;
      contentText = segmentsData[0].chapters[0].chapterContent;
    }
    
    textController.text = contentText;
    
    // 監聽文字變化
    textController.addListener(() {
      // 只有當文字真的改變且不在同步狀態時才更新
      if (!_isSyncing && contentText != textController.text) {
        setState(() {
          contentText = textController.text;
          totalWords = contentText.split(RegExp(r"\s+")).where((word) => word.isNotEmpty).length;
        });
      }
    });
  }
  
  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // 響應式佈局：根據螢幕寬度決定使用堆疊還是分割佈局
          if (constraints.maxWidth < 800) {
            return _buildMobileLayout();
          } else {
            return _buildDesktopLayout();
          }
        },
      ),
    );
  }
  
  // AppBar 建構方法
  PreferredSizeWidget _buildAppBar() {
    String title = "物語Assistant";
    if (currentProject != null) {
      title += " - ${currentProject!.nameWithoutExtension}";
      if (currentProject!.isNewFile) {
        title += " (未儲存)";
      }
    }
    
    return AppBar(
      title: Row(
        children: [
          if (isLoading)
            Container(
              margin: const EdgeInsets.only(right: 12),
              child: const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      elevation: 0,
      actions: [
        // 檔案選單
        PopupMenuButton<String>(
          icon: const Icon(Icons.folder),
          tooltip: "檔案",
          onSelected: _handleFileAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: "new",
              child: ListTile(
                leading: Icon(Icons.note_add),
                title: Text("新建檔案"),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: "open",
              child: ListTile(
                leading: Icon(Icons.folder_open),
                title: Text("開啟檔案"),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: "save",
              child: ListTile(
                leading: Icon(Icons.save),
                title: Text("儲存檔案"),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: "saveAs",
              child: ListTile(
                leading: Icon(Icons.save_as),
                title: Text("另存新檔"),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        
        // 編輯工具
        IconButton(
          icon: const Icon(Icons.undo),
          onPressed: () => _performEditorAction("undo"),
          tooltip: "Undo",
        ),
        IconButton(
          icon: const Icon(Icons.redo),
          onPressed: () => _performEditorAction("redo"),
          tooltip: "Redo",
        ),
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () => _performEditorAction("find"),
          tooltip: "Find",
        ),
        
        const SizedBox(width: 8),
      ],
    );
  }

  // 手機佈局（使用 BottomNavigationBar）
  Widget _buildMobileLayout() {
    // 檢查是否在編輯器頁面（slidePage > 8 表示編輯器）
    bool isEditorMode = slidePage > 8;
    
    return Scaffold(
      body: IndexedStack(
        index: isEditorMode ? 1 : 0,  // 0: 功能頁面, 1: 編輯器
        children: [
          _buildMobileFunctionPage(),
          _buildEditor(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: isEditorMode ? 1 : 0,
        onDestinationSelected: (index) {
          // 在切換前同步編輯器內容
          _syncEditorToSelectedChapter();
          
          setState(() {
            if (index == 0) {
              // 切換到功能頁面，保持當前的功能選項
              if (slidePage > 8) slidePage = 0; // 如果在編輯器，切回第一個功能
            } else {
              // 切換到編輯器
              slidePage = 9; // 使用 9 作為編輯器的標識
            }
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: "功能",
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_note),
            label: "編輯器",
          ),
        ],
      ),
    );
  }
  
  // 手機功能頁面（包含功能切換和內容）
  Widget _buildMobileFunctionPage() {
    return Column(
      children: [
        // 功能頁面導航
        Container(
          height: 60,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                for (int i = 0; i < 9; i++)
                  _buildMobileNavigationChip(i),
              ],
            ),
          ),
        ),
        
        // 功能頁面內容 - 使用 IndexedStack 保持狀態
        Expanded(
          child: IndexedStack(
            index: slidePage.clamp(0, 8),
            children: [
              for (int i = 0; i < 9; i++)
                _buildSpecificPageContent(i),
            ],
          ),
        ),
      ],
    );
  }
  
  // 手機導航晶片
  Widget _buildMobileNavigationChip(int index) {
    final List<Map<String, dynamic>> functions = [
      {"icon": Icons.book, "label": "故事設定"},
      {"icon": Icons.menu_book, "label": "章節選擇"},
      {"icon": Icons.list, "label": "大綱調整"},
      {"icon": Icons.public, "label": "世界設定"},
      {"icon": Icons.person, "label": "角色設定"},
      {"icon": Icons.library_books, "label": "詞語參考"},
      {"icon": Icons.search, "label": "搜尋取代"},
      {"icon": Icons.spellcheck, "label": "文本校正"},
      {"icon": Icons.auto_awesome, "label": "Copilot"},
    ];
    
    final function = functions[index];
    final isSelected = slidePage == index;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: FilterChip(
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            // 在切換前同步編輯器內容
            _syncEditorToSelectedChapter();
            
            setState(() {
              slidePage = index;
            });
          }
        },
        avatar: Icon(
          function["icon"],
          size: 18,
          color: isSelected 
            ? Theme.of(context).colorScheme.onSecondaryContainer
            : Theme.of(context).colorScheme.onSurface,
        ),
        label: Text(
          function["label"],
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        backgroundColor: isSelected 
          ? Theme.of(context).colorScheme.secondaryContainer
          : null,
        selectedColor: Theme.of(context).colorScheme.secondaryContainer,
        checkmarkColor: Theme.of(context).colorScheme.onSecondaryContainer,
      ),
    );
  }

  // 特定頁面內容建構（用於 IndexedStack）
  Widget _buildSpecificPageContent(int pageIndex) {
    switch (pageIndex) {
      case 0:
        return _buildBaseInfoView();
      case 1:
        return _buildChapterSelectionView();
      case 2:
        return _buildOutlineView();
      case 3:
        return _buildWorldSettingsView();
      case 4:
        return _buildCharacterSettingsView();
      case 5:
        return _buildGlossaryView();
      case 6:
        return _buildFindReplaceView();
      case 7:
        return _buildProofreadingView();
      case 8:
        return _buildCopilotView();
      default:
        return Center(child: Text("Page ${pageIndex + 1}"));
    }
  }

  // 桌面佈局（使用 NavigationRail）
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // NavigationRail - 包裝在可滾動容器中
        SingleChildScrollView(
          child: IntrinsicHeight(
            child: NavigationRail(
              selectedIndex: _getNavigationIndex(),
              onDestinationSelected: (index) {
                // 在切換前同步編輯器內容
                _syncEditorToSelectedChapter();
                
                setState(() {
                  slidePage = index;
                });
              },
              labelType: NavigationRailLabelType.all,
              backgroundColor: Theme.of(context).colorScheme.surface,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.book),
                  label: Text("故事設定"),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.menu_book),
                  label: Text("章節選擇"),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.list),
                  label: Text("大綱調整"),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.public),
                  label: Text("世界設定"),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person),
                  label: Text("角色設定"),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.library_books),
                  label: Text("詞語參考"),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.search),
                  label: Text("搜尋取代"),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.spellcheck),
                  label: Text("文本校正"),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.auto_awesome),
                  label: Text("Copilot"),
                ),
              ],
            ),
          ),
        ),
        
        // 垂直分隔線
        const VerticalDivider(thickness: 1, width: 1),
        
        // 主要內容區域
        Expanded(
          child: Row(
            children: [
              // 左側內容區域
              Expanded(
                flex: 2,
                child: Container(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  child: _buildPageContent(),
                ),
              ),
              
              // 垂直分隔線
              const VerticalDivider(thickness: 1, width: 1),
              
              // 右側編輯器
              Expanded(
                flex: 3,
                child: _buildEditor(),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // 獲取 NavigationRail 的選中索引
  int _getNavigationIndex() {
    return slidePage > 8 ? 0 : slidePage.clamp(0, 8);
  }
  

  
  // 頁面內容
  Widget _buildPageContent() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: _buildPageView(),
    );
  }
  
  // 頁面視圖
  Widget _buildPageView() {
    int pageIndex = slidePage > 8 ? 0 : slidePage; // 如果在編輯器模式，預設顯示第一頁
    
    switch (pageIndex) {
      case 0:
        return _buildBaseInfoView();
      case 1:
        return _buildChapterSelectionView();
      case 2:
        return _buildOutlineView();
      case 3:
        return _buildWorldSettingsView();
      case 4:
        return _buildCharacterSettingsView();
      case 5:
        return _buildGlossaryView();
      case 6:
        return _buildFindReplaceView();
      case 7:
        return _buildProofreadingView();
      case 8:
        return _buildCopilotView();
      default:
        return Center(child: Text("Page ${pageIndex + 1}"));
    }
  }
  
  // 編輯器
  Widget _buildEditor() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          // 編輯器工具列
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                const Spacer(),
                
                // 編輯工具
                IconButton(
                  icon: const Icon(Icons.select_all),
                  onPressed: () => _performEditorAction("selectAll"),
                  tooltip: "Select All",
                  iconSize: 20,
                ),
                IconButton(
                  icon: const Icon(Icons.content_cut),
                  onPressed: () => _performEditorAction("cut"),
                  tooltip: "Cut",
                  iconSize: 20,
                ),
                IconButton(
                  icon: const Icon(Icons.content_copy),
                  onPressed: () => _performEditorAction("copy"),
                  tooltip: "Copy",
                  iconSize: 20,
                ),
                IconButton(
                  icon: const Icon(Icons.content_paste),
                  onPressed: () => _performEditorAction("paste"),
                  tooltip: "Paste",
                  iconSize: 20,
                ),
                
                const SizedBox(width: 8),
                
                // 字數統計
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    "字數：$totalWords",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 文本編輯器
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              child: TextField(
                controller: textController,
                maxLines: null,
                expands: true,
                decoration: InputDecoration(
                  hintText: "在此輸入您的故事內容...",
                  hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.6,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // 各個頁面的建構方法（符合 Material Design）
  Widget _buildBaseInfoView() {
    return BaseInfoModule.BaseInfoView(
      data: baseInfoData,
      contentText: contentText,
      totalWords: totalWords,
      onDataChanged: (updatedData) {
        setState(() {
          baseInfoData = updatedData;
        });
      },
    );
  }
  
  Widget _buildChapterSelectionView() {
    return ChapterModule.ChapterSelectionView(
      segments: segmentsData,
      contentText: contentText,
      selectedSegmentID: selectedSegID,
      selectedChapterID: selectedChapID,
      onSegmentsChanged: (updatedSegments) {
        // 先存：總是嘗試保存當前編輯器內容（如果有選中的章節）
        _syncEditorToSelectedChapter();
        
        // 然後更新 segmentsData
        setState(() {
          segmentsData = updatedSegments;
        });
        
        // 再讀：這會透過 onContentChanged 自動發生
      },
      onContentChanged: (newContent) {
        // 這是「再讀」的部分：載入選中章節的內容到編輯器
        // 只在內容真的不同時才更新，避免不必要的重建
        if (contentText != newContent) {
          _isSyncing = true;
          setState(() {
            contentText = newContent;
            textController.text = contentText;
            // 重新計算字數
            totalWords = contentText.split(RegExp(r"\s+")).where((word) => word.isNotEmpty).length;
          });
          _isSyncing = false;
        }
      },
      onSelectedSegmentChanged: (segmentID) {
        // 先存：無論如何都先保存當前編輯器內容
        _syncEditorToSelectedChapter();
        
        setState(() {
          selectedSegID = segmentID;
        });
      },
      onSelectedChapterChanged: (chapterID) {
        // 先存：無論如何都先保存當前編輯器內容  
        _syncEditorToSelectedChapter();
        
        setState(() {
          selectedChapID = chapterID;
        });
      },
    );
  }
  
  Widget _buildOutlineView() {
    return _buildPlaceholderPage(
      icon: Icons.list,
      title: "大綱調整",
      description: "大綱功能開發中...",
      color: Colors.orange,
    );
  }
  
  Widget _buildWorldSettingsView() {
    return _buildPlaceholderPage(
      icon: Icons.public,
      title: "世界設定",
      description: "世界設定功能開發中...",
      color: Colors.green,
    );
  }
  
  Widget _buildCharacterSettingsView() {
    return _buildPlaceholderPage(
      icon: Icons.person,
      title: "角色設定",
      description: "角色設定功能開發中...",
      color: Colors.purple,
    );
  }
  
  Widget _buildGlossaryView() {
    return _buildPlaceholderPage(
      icon: Icons.library_books,
      title: "詞語參考",
      description: "詞語參考功能開發中...",
      color: Colors.teal,
    );
  }
  
  Widget _buildFindReplaceView() {
    return _buildPlaceholderPage(
      icon: Icons.search,
      title: "搜尋/取代",
      description: "搜尋/取代功能開發中...",
      color: Colors.indigo,
    );
  }
  
  Widget _buildProofreadingView() {
    return _buildPlaceholderPage(
      icon: Icons.spellcheck,
      title: "文本校正",
      description: "文本校正功能開發中...",
      color: Colors.red,
    );
  }
  
  Widget _buildCopilotView() {
    return _buildPlaceholderPage(
      icon: Icons.auto_awesome,
      title: "Copilot",
      description: "Copilot 功能開發中...",
      color: Colors.deepPurple,
    );
  }
  
  // 通用的佔位頁面
  Widget _buildPlaceholderPage({
    required IconData icon,
    required String title,
    required String description,
    required MaterialColor color,
  }) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                icon,
                size: 64,
                color: color,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("$title 功能即將推出！"),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.construction),
              label: const Text("即將推出"),
            ),
          ],
        ),
      ),
    );
  }
  
  // 檔案操作處理
  void _handleFileAction(String action) {
    switch (action) {
      case "new":
        _newProject();
        break;
      case "open":
        _openProject();
        break;
      case "save":
        _saveProject();
        break;
      case "saveAs":
        _saveProjectAs();
        break;
      case "export_txt":
        _exportAs("txt");
        break;
      case "export_md":
        _exportAs("md");
        break;
    }
  }
  
  // 編輯器操作
  void _performEditorAction(String action) {
    // 這裡可以實作編輯器的 undo, redo, copy, paste 等功能
    // Flutter 的 TextField 已經內建了大部分功能
    switch (action) {
      case "undo":
        // 實作 undo 功能
        break;
      case "redo":
        // 實作 redo 功能
        break;
      case "selectAll":
        textController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: textController.text.length,
        );
        break;
      case "cut":
        if (textController.selection.isValid) {
          final selectedText = textController.selection.textInside(textController.text);
          Clipboard.setData(ClipboardData(text: selectedText));
          textController.text = textController.selection.textBefore(textController.text) +
              textController.selection.textAfter(textController.text);
        }
        break;
      case "copy":
        if (textController.selection.isValid) {
          final selectedText = textController.selection.textInside(textController.text);
          Clipboard.setData(ClipboardData(text: selectedText));
        }
        break;
      case "paste":
        Clipboard.getData("text/plain").then((value) {
          if (value?.text != null) {
            final text = textController.text;
            final selection = textController.selection;
            final newText = text.replaceRange(selection.start, selection.end, value!.text!);
            textController.text = newText;
            textController.selection = TextSelection.collapsed(
              offset: selection.start + value.text!.length,
            );
          }
        });
        break;
      case "find":
        // 實作搜尋功能
        break;
    }
  }
  
  // 檔案操作方法
  Future<void> _newProject() async {
    try {
      setState(() {
        isLoading = true;
      });
      
      final newProject = await FileService.createNewProject();
      
      setState(() {
        currentProject = newProject;
        baseInfoData = BaseInfoModule.BaseInfoData();
        segmentsData = [
          ChapterModule.SegmentData(
            segmentName: "第一部",
            chapters: [ChapterModule.ChapterData(chapterName: "第一章", chapterContent: "")],
          )
        ];
        outlineData = [
          StorylineData(
            storylineName: "主線劇情",
            storylineType: "起",
            scenes: [
              StoryEventData(
                storyEvent: "開始事件",
                scenes: [SceneData(sceneName: "開場場景")],
                memo: ""
              )
            ],
            memo: ""
          )
        ];
        worldSettingsData = [Location(localName: "主要場景")];
        characterData = [CharacterProfile(name: "主角")];
        
        selectedSegID = segmentsData.first.segmentUUID;
        selectedChapID = segmentsData.first.chapters.first.chapterUUID;
        totalWords = 0;
        contentText = "";
        textController.text = "";
        isLoading = false;
      });
      
      _showMessage("新專案建立成功！");
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showError("建立新專案失敗：${e.toString()}");
    }
  }
  
  Future<void> _openProject() async {
    try {
      setState(() {
        isLoading = true;
      });
      
      final projectFile = await FileService.openProject();
      
      if (projectFile != null) {
        await _loadProjectFromXML(projectFile);
        _showMessage("專案開啟成功：${projectFile.nameWithoutExtension}");
      }
    } catch (e) {
      _showError("開啟專案失敗：${e.toString()}");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }
  
  Future<void> _saveProject() async {
    try {
      setState(() {
        isLoading = true;
      });
      
      _syncEditorToSelectedChapter();
      
      currentProject ??= await FileService.createNewProject();
      
      // 生成最新的專案XML內容
      final xmlContent = _generateProjectXML();
      currentProject!.content = xmlContent;
      
      final savedProject = await FileService.saveProject(currentProject!);
      
      setState(() {
        currentProject = savedProject;
        isLoading = false;
      });
      
      _showMessage("專案儲存成功！");
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showError("儲存專案失敗：${e.toString()}");
    }
  }
  
  Future<void> _saveProjectAs() async {
    try {
      setState(() {
        isLoading = true;
      });
      
      _syncEditorToSelectedChapter();
      
      currentProject ??= await FileService.createNewProject();
      
      // 生成最新的專案XML內容
      final xmlContent = _generateProjectXML();
      currentProject!.content = xmlContent;
      
      final savedProject = await FileService.saveProjectAs(currentProject!);
      
      setState(() {
        currentProject = savedProject;
        isLoading = false;
      });
      
      _showMessage("專案另存成功：${savedProject.nameWithoutExtension}");
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showError("另存專案失敗：${e.toString()}");
    }
  }
  
  Future<void> _exportAs(String extension) async {
    try {
      setState(() {
        isLoading = true;
      });
      
      _syncEditorToSelectedChapter();
      
      // 收集所有章節內容
      String allContent = "";
      for (final segment in segmentsData) {
        allContent += "# ${segment.segmentName}\n\n";
        for (final chapter in segment.chapters) {
          allContent += "## ${chapter.chapterName}\n\n";
          allContent += "${chapter.chapterContent}\n\n";
        }
      }
      
      final fileName = currentProject?.nameWithoutExtension ?? "MonogatariExport";
      
      await FileService.exportText(
        content: allContent,
        fileName: fileName,
        extension: extension == "txt" ? ".txt" : ".md",
      );
      
      setState(() {
        isLoading = false;
      });
      
      _showMessage("匯出 $extension 檔案成功！");
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showError("匯出檔案失敗：${e.toString()}");
    }
  }
  
  // 同步編輯器內容到選中的章節（先存的部分）
  void _syncEditorToSelectedChapter() {
    if (_isSyncing) return; // 防止遞歸調用
    
    if (selectedSegID != null && selectedChapID != null) {
      final segIndex = segmentsData.indexWhere((seg) => seg.segmentUUID == selectedSegID);
      if (segIndex != -1) {
        final chapIndex = segmentsData[segIndex].chapters.indexWhere((chap) => chap.chapterUUID == selectedChapID);
        if (chapIndex != -1) {
          // 先存邏輯：無條件保存當前編輯器內容到選中的章節
          _isSyncing = true; // 設置同步標記
          
          // 取得當前編輯器的最新內容（從 textController 直接讀取）
          final currentEditorContent = textController.text;
          
          // 更新章節內容
          segmentsData[segIndex].chapters[chapIndex].chapterContent = currentEditorContent;
          
          // 同步 contentText 變數
          contentText = currentEditorContent;
          
          // 觸發 segmentsData 更新通知（總是觸發以確保資料同步）
          setState(() {}); // 觸發重建以更新所有依賴 segmentsData 的組件
          
          _isSyncing = false; // 清除同步標記
        }
      }
    }
  }
  
  // 訊息處理
  void _showError(String message) {
    setState(() {
      errorMessage = message;
      showingError = true;
    });
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("錯誤"),
        content: Text(errorMessage),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => showingError = false);
            },
            child: const Text("確定"),
          ),
        ],
      ),
    );
  }
  
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  // 專案XML生成
  String _generateProjectXML() {
    final buffer = StringBuffer();
    
    buffer.writeln("<?xml version=\"1.0\" encoding=\"UTF-8\"?>");
    buffer.writeln("<Project>");
    
    // BaseInfo (使用新的 BaseInfoCodec)
    final baseInfoXml = BaseInfoModule.BaseInfoCodec.saveXML(
      data: baseInfoData,
      totalWords: totalWords,
      contentText: contentText,
    );
    if (baseInfoXml != null) {
      buffer.write("  ");
      buffer.write(baseInfoXml.replaceAll("\n", "\n  "));
    }
    
    // ChapterSelection (使用新的 ChapterSelectionCodec)
    final chapterXml = ChapterModule.ChapterSelectionCodec.saveXML(segmentsData);
    if (chapterXml != null) {
      buffer.write("  ");
      buffer.write(chapterXml.replaceAll("\n", "\n  "));
    }
    
    // Outline
    buffer.writeln("  <Type>Outline</Type>");
    buffer.writeln("  <Outline>");
    for (final storyline in outlineData) {
      buffer.writeln("    <Storyline>");
      buffer.writeln("      <StorylineName>${_escapeXml(storyline.storylineName)}</StorylineName>");
      buffer.writeln("      <StorylineType>${_escapeXml(storyline.storylineType)}</StorylineType>");
      buffer.writeln("      <Memo>${_escapeXml(storyline.memo)}</Memo>");
      buffer.writeln("      <ChapterUUID>${storyline.chapterUUID}</ChapterUUID>");
      buffer.writeln("    </Storyline>");
    }
    buffer.writeln("  </Outline>");
    
    // WorldSettings
    buffer.writeln("  <Type>WorldSettings</Type>");
    buffer.writeln("  <WorldSettings>");
    for (final location in worldSettingsData) {
      buffer.writeln("    <Location>");
      buffer.writeln("      <LocalName>${_escapeXml(location.localName)}</LocalName>");
      buffer.writeln("      <Description>${_escapeXml(location.description)}</Description>");
      buffer.writeln("      <LocationUUID>${location.locationUUID}</LocationUUID>");
      buffer.writeln("    </Location>");
    }
    buffer.writeln("  </WorldSettings>");
    
    // Characters
    buffer.writeln("  <Type>Characters</Type>");
    buffer.writeln("  <Characters>");
    for (final character in characterData) {
      buffer.writeln("    <Character>");
      buffer.writeln("      <Name>${_escapeXml(character.name)}</Name>");
      buffer.writeln("      <Description>${_escapeXml(character.description)}</Description>");
      buffer.writeln("      <CharacterUUID>${character.characterUUID}</CharacterUUID>");
      buffer.writeln("    </Character>");
    }
    buffer.writeln("  </Characters>");
    
    buffer.writeln("</Project>");
    
    return buffer.toString();
  }
  
  // 從XML載入專案
  Future<void> _loadProjectFromXML(ProjectFile projectFile) async {
    try {
      setState(() {
        currentProject = projectFile;
      });
      
      final xmlContent = projectFile.content;
      
      // 解析BaseInfo (使用新的 BaseInfoCodec)
      if (XMLParser.hasTypeBlock(xmlContent, "BaseInfo")) {
        final blocks = XMLParser.extractTypeBlocks(xmlContent, "BaseInfo");
        if (blocks.isNotEmpty) {
          final loadedData = BaseInfoModule.BaseInfoCodec.loadXML(blocks.first);
          if (loadedData != null) {
            baseInfoData = loadedData;
          }
        }
      }
      
      // 解析ChapterSelection (使用新的 ChapterSelectionCodec)
      if (XMLParser.hasTypeBlock(xmlContent, "ChapterSelection")) {
        final blocks = XMLParser.extractTypeBlocks(xmlContent, "ChapterSelection");
        if (blocks.isNotEmpty) {
          final loadedSegments = ChapterModule.ChapterSelectionCodec.loadXML(blocks.first);
          if (loadedSegments != null && loadedSegments.isNotEmpty) {
            segmentsData = loadedSegments;
          }
        }
      }
      
      // 設定初始選擇
      if (segmentsData.isNotEmpty && segmentsData[0].chapters.isNotEmpty) {
        selectedSegID = segmentsData[0].segmentUUID;
        selectedChapID = segmentsData[0].chapters[0].chapterUUID;
        contentText = segmentsData[0].chapters[0].chapterContent;
        textController.text = contentText;
      }
      
    } catch (e) {
      throw FileException("解析專案檔案失敗：${e.toString()}");
    }
  }
  
  // XML字符轉義
  String _escapeXml(String text) {
    return text
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll("'", "&apos;")
        .replaceAll("\"", "&quot;");
  }
}