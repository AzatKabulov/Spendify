/// The user's decision about the two AI features (receipt scanning + advice),
/// which send data to Google Gemini (CLAUDE.md §7 ethics 4/6). Plain Dart.
///
///  - [undecided] — never asked. The first-run consent screen is shown before
///    any AI feature can be used.
///  - [granted]   — AI features are available.
///  - [denied]    — AI features are hidden/disabled and no Gemini client is
///    constructed. The rest of the app is fully usable.
///
/// One value serves as both the consent record and the on/off toggle:
/// accepting sets [granted], declining or revoking sets [denied].
enum AiConsent { undecided, granted, denied }
