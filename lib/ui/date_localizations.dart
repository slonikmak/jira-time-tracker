import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

/// Keeps numeric dates day-first in the English Material date picker.
class DayFirstEnglishLocalizations extends MaterialLocalizationEn {
  DayFirstEnglishLocalizations()
    : super(
        fullYearFormat: DateFormat.y('en'),
        compactDateFormat: DateFormat('dd.MM.yyyy', 'en'),
        shortDateFormat: DateFormat('d MMM y', 'en'),
        mediumDateFormat: DateFormat('EEE, d MMM', 'en'),
        longDateFormat: DateFormat('EEEE, d MMMM y', 'en'),
        yearMonthFormat: DateFormat.yMMMM('en'),
        shortMonthDayFormat: DateFormat('d MMM', 'en'),
        decimalFormat: NumberFormat.decimalPattern('en'),
        twoDigitZeroPaddedFormat: NumberFormat('00', 'en'),
      );

  @override
  String get dateHelpText => 'DD.MM.YYYY';
}

class DayFirstMaterialDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const DayFirstMaterialDelegate();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';
  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    // The standard delegate initialises intl date data on a cold start.
    await GlobalMaterialLocalizations.delegate.load(locale);
    return DayFirstEnglishLocalizations();
  }

  @override
  bool shouldReload(DayFirstMaterialDelegate old) => false;
}
