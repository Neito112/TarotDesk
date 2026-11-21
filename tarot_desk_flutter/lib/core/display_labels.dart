/// Display-label mapping for stored option ids (Worker A).
///
/// The stored values (theme ids, table/cloth/decor option strings,
/// mystic-track list positions) are PERSISTED identifiers — they must
/// never change, and no code comparison against them may change.
/// This file only maps each stored identifier to the localization
/// key whose translated value is SHOWN to the user.
///
/// Usage: `settings.tr(themeDisplayKey(t.id))`,
/// `settings.tr(tableStyleDisplayKey(opt))`, etc.
///
/// Fallback: an unknown future id is returned unchanged, so it still
/// shows something instead of going blank (`tr()` renders an unknown
/// key as the key itself, and an unknown id as the id itself).
/// Ids with no key yet (`Đá Cổ`, `Vũ Trụ`, `Lá Khô` — filtered out of
/// every chip list today, see audit §U6) fall through to that default
/// until keys are added for them.

/// Theme: takes the theme id (`default_dark`, …) or, defensively,
/// the stored Vietnamese display name (`Tối Obsidian (Mặc định)`, …).
String themeDisplayKey(String idOrName) {
  switch (idOrName) {
    case 'default_dark':
    case 'Tối Obsidian (Mặc định)':
      return 'theme.obsidian';
    case 'mystical_purple':
    case 'Tím Huyền Bí':
      return 'theme.mysticPurple';
    case 'golden_sun':
    case 'Hoàng Kim Nắng Ấm':
      return 'theme.goldenSun';
    case 'gothic_night':
    case 'Đêm Gothic Tinh Tế':
      return 'theme.gothicNight';
    default:
      return idOrName;
  }
}

/// Table style: takes the stored option string (`Gỗ Sồi`, …).
String tableStyleDisplayKey(String id) {
  switch (id) {
    case 'Gỗ Sồi':
      return 'table.oak';
    default:
      return id;
  }
}

/// Cloth style: takes the stored option string (`Nhung Tím`, …).
String clothDisplayKey(String id) {
  switch (id) {
    case 'Nhung Tím':
      return 'cloth.purpleVelvet';
    case 'Lụa Vàng':
      return 'cloth.goldSilk';
    case 'Thảm Đen':
      return 'cloth.blackCarpet';
    default:
      return id;
  }
}

/// Decor item: takes the stored option string (`Đá Thạch Anh`, …).
String decorDisplayKey(String id) {
  switch (id) {
    case 'Đá Thạch Anh':
      return 'decor.crystal';
    case 'Quả Cầu':
      return 'decor.crystalBall';
    case 'Hương Trầm':
      return 'decor.incense';
    case 'Nến Đen':
      return 'decor.blackCandle';
    default:
      return id;
  }
}

/// Mystic preset track: takes the 0-based index into [kMysticTracks].
/// Out-of-range indexes return a key-shaped string so `tr()` shows
/// the key text instead of blank (no such index exists today — the
/// list has exactly 5 tracks).
String trackTitleKey(int index) {
  switch (index) {
    case 0:
      return 'music.track1';
    case 1:
      return 'music.track2';
    case 2:
      return 'music.track3';
    case 3:
      return 'music.track4';
    case 4:
      return 'music.track5';
    default:
      return 'music.track${index + 1}';
  }
}
