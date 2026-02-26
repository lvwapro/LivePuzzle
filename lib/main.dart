import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:live_puzzle/screens/main_screen.dart';
import 'package:live_puzzle/providers/locale_provider.dart';
import 'package:live_puzzle/l10n/app_localizations.dart';

void main() {
  runApp(const ProviderScope(child: LivePuzzleApp()));
}

class LivePuzzleApp extends ConsumerWidget {
  const LivePuzzleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    
    return MaterialApp(
      title: 'LivePuzzle',
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('zh', ''),
      ],
      theme: ThemeData(
        // 颜色主题
        primaryColor: const Color(0xFFFF4D8D), // vibrant-pink
        scaffoldBackgroundColor: const Color(0xFFFFF0F3), // soft-pink
        
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF4D8D),
          primary: const Color(0xFFFF4D8D), // vibrant-pink
          secondary: const Color(0xFFFFD1DC), // pastel-pink
          surface: Colors.white,
          background: const Color(0xFFFFF0F3), // soft-pink
        ),

        // 文本主题
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5C5456), // warm-gray
          ),
          displayMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5C5456),
          ),
          displaySmall: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5C5456),
          ),
          headlineMedium: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5C5456),
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5C5456),
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF5C5456),
          ),
          bodyLarge: TextStyle(
            fontSize: 14,
            color: Color(0xFF5C5456),
          ),
          bodyMedium: TextStyle(
            fontSize: 12,
            color: Color(0xFF5C5456),
          ),
        ),

        // 卡片主题
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          color: Colors.white,
          shadowColor: const Color(0xFFFF4D8D).withOpacity(0.12),
        ),

        // 按钮主题
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF4D8D),
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: const Color(0xFFFF4D8D).withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 16,
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFFF4D8D),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // 输入框主题
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Color(0xFFFF4D80),
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),

        // AppBar主题
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFF0F3),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5C5456),
          ),
          iconTheme: IconThemeData(
            color: Color(0xFFFF4D8D),
          ),
        ),

        // 对话框主题
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
        ),

        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}
