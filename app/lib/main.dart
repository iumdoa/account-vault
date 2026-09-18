import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'application/vault_session_controller.dart';
import 'infrastructure/mock/mock_vault_repository.dart';
import 'presentation/widgets/management_view.dart';
import 'presentation/widgets/quick_panel_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = MockVaultRepository();
  final controller = VaultSessionController(
    repository: repository,
    isMockMode: true,
  );

  runApp(AccountVaultApp(controller: controller));
}

class AccountVaultApp extends StatelessWidget {
  final VaultSessionController controller;

  const AccountVaultApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Account Vault',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF181A1F),
      ),
      home: AppRootScaffold(controller: controller),
    );
  }
}

class AppRootScaffold extends StatefulWidget {
  final VaultSessionController controller;

  const AppRootScaffold({super.key, required this.controller});

  @override
  State<AppRootScaffold> createState() => _AppRootScaffoldState();
}

class _AppRootScaffoldState extends State<AppRootScaffold> {
  static const MethodChannel _windowChannel = MethodChannel(
    'dev.local.account_vault/window',
  );

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isManagementView = false;

  @override
  void initState() {
    super.initState();
    widget.controller.loadEntries();
    widget.controller.addListener(_onControllerChanged);
    _windowChannel.setMethodCallHandler(_handleNativeMethodCall);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusSearchBox();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final msg = widget.controller.feedbackMessage;
    if (msg != null && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          backgroundColor: const Color(0xFF282C34),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFF3E4451)),
          ),
        ),
      );
      widget.controller.clearFeedback();
    }
  }

  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    if (call.method == 'onShow') {
      if (mounted) {
        setState(() {
          // Returning to quick panel view on hotkey show
          _isManagementView = false;
        });
        _focusSearchBox();
      }
      return true;
    }
    return null;
  }

  void _focusSearchBox() {
    if (!_isManagementView) {
      if (!_searchFocusNode.hasFocus) {
        _searchFocusNode.requestFocus();
      }
      if (_searchController.text.isNotEmpty) {
        _searchController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _searchController.text.length,
        );
      }
    }
  }

  Future<void> _hideWindow() async {
    try {
      await _windowChannel.invokeMethod('hideWindow');
    } catch (e) {
      debugPrint('Error hiding window: $e');
    }
  }

  Future<void> _quitApp() async {
    try {
      await _windowChannel.invokeMethod('quitApp');
    } catch (e) {
      debugPrint('Error quitting app: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: _isManagementView
                  ? ManagementView(
                      controller: widget.controller,
                      onBackToQuickPanel: () {
                        setState(() {
                          _isManagementView = false;
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _focusSearchBox();
                        });
                      },
                      onQuitApp: _quitApp,
                    )
                  : QuickPanelView(
                      controller: widget.controller,
                      searchController: _searchController,
                      searchFocusNode: _searchFocusNode,
                      onOpenManagement: () {
                        setState(() {
                          _isManagementView = true;
                        });
                      },
                      onHideWindow: _hideWindow,
                    ),
            ),
          ),
        );
      },
    );
  }
}
