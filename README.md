# Expense Tracker Flutter App

A beginner-friendly Flutter expense tracker with:
- Add income and expense transactions
- Categories, dates, notes
- Transaction history and delete
- Monthly income/expense summary and a simple chart
- Date/category/type filters
- CSV export using the share sheet
- Local persistence using `shared_preferences`

> Assignment note: the brief mentions Android Room, ViewModel/LiveData, and MPAndroidChart. Those are native Android libraries. This Flutter implementation uses Dart/Flutter equivalents and `shared_preferences` for local storage. If your supervisor specifically requires SQLite/Room-equivalent persistence, replace the storage layer with `sqflite` or `drift`.

## Run in VS Code
1. Install Flutter and ensure `flutter doctor` works.
2. Open a terminal in this project folder.
3. Run `flutter pub get`
4. Run `flutter run`

For an Android phone, enable Developer options and USB debugging, connect the phone, accept the USB debugging prompt, then run `flutter devices` and `flutter run`.

## Files
- `lib/main.dart`: complete UI, state, filters, chart, CSV export.
- `pubspec.yaml`: required dependencies.
