// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class S {
  S();

  static S? _current;

  static S get current {
    assert(
      _current != null,
      'No instance of S was loaded. Try to initialize the S delegate before accessing S.current.',
    );
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<S> load(Locale locale) {
    final name =
        (locale.countryCode?.isEmpty ?? false)
            ? locale.languageCode
            : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = S();
      S._current = instance;

      return instance;
    });
  }

  static S of(BuildContext context) {
    final instance = S.maybeOf(context);
    assert(
      instance != null,
      'No instance of S present in the widget tree. Did you add S.delegate in localizationsDelegates?',
    );
    return instance!;
  }

  static S? maybeOf(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  /// `phone`
  String get phone {
    return Intl.message('phone', name: 'phone', desc: '', args: []);
  }

  /// `email`
  String get email {
    return Intl.message('email', name: 'email', desc: '', args: []);
  }

  /// `login`
  String get login {
    return Intl.message('login', name: 'login', desc: '', args: []);
  }

  /// `OmniCast`
  String get appName {
    return Intl.message('OmniCast', name: 'appName', desc: '', args: []);
  }

  /// `Hello`
  String get hello {
    return Intl.message('Hello', name: 'hello', desc: '', args: []);
  }

  /// `What do you want to create today?`
  String get whatToCreate {
    return Intl.message(
      'What do you want to create today?',
      name: 'whatToCreate',
      desc: '',
      args: [],
    );
  }

  /// `Explanation Video`
  String get explanationVideo {
    return Intl.message(
      'Explanation Video',
      name: 'explanationVideo',
      desc: '',
      args: [],
    );
  }

  /// `PPT`
  String get ppt {
    return Intl.message('PPT', name: 'ppt', desc: '', args: []);
  }

  /// `AI Blog`
  String get aiBlog {
    return Intl.message('AI Blog', name: 'aiBlog', desc: '', args: []);
  }

  /// `Text to Speech`
  String get textToSpeech {
    return Intl.message(
      'Text to Speech',
      name: 'textToSpeech',
      desc: '',
      args: [],
    );
  }

  /// `AI Image Generation`
  String get aiImage {
    return Intl.message(
      'AI Image Generation',
      name: 'aiImage',
      desc: '',
      args: [],
    );
  }

  /// `Voice Cloning`
  String get voiceCloning {
    return Intl.message(
      'Voice Cloning',
      name: 'voiceCloning',
      desc: '',
      args: [],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<S> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
      Locale.fromSubtags(languageCode: 'zh'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<S> load(Locale locale) => S.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
