namespace TarotDesk.Utils;

/// <summary>
/// Các Tarot symbols - thay thế cho bài tây
/// Wands = Gậy (♣), Cups = Cốc (♥), Swords = Kiếm (♠), Pentacles = Xu (♦)
/// </summary>
public static class TarotSymbols
{
    // Suit symbols
    public const string WANDS = "🪵"; // Gậy - Wood/Wands
    public const string CUPS = "🍷";  // Cốc - Cups  
    public const string SWORDS = "⚔️"; // Kiếm - Swords
    public const string PENTACLES = "🔮"; // Xu/Pentacles - Crystal ball

    // Alternative symbols
    public const string WANDS_ALT = "✦"; // Alternative wand
    public const string CUPS_ALT = "◈"; // Alternative cup
    public const string SWORDS_ALT = "⚡"; // Alternative sword
    public const string PENTACLES_ALT = "◉"; // Alternative pentacle

    // Major Arcana icons
    public const string FOOL = "🃏"; // The Fool
    public const string MAGICIAN = "✨"; // The Magician
    public const string HIGH_PRIESTESS = "👑"; // High Priestess
    public const string EMPRESS = "👸"; // Empress
    public const string EMPEROR = "👨"; // Emperor
    public const string HIEROPHANT = "🙏"; // Hierophant
    public const string LOVERS = "💕"; // Lovers
    public const string CHARIOT = "🐴"; // Chariot
    public const string STRENGTH = "💪"; // Strength
    public const string HERMIT = "🕯️"; // Hermit
    public const string WHEEL = "🔄"; // Wheel of Fortune
    public const string JUSTICE = "⚖️"; // Justice
    public const string HANGED = "🔗"; // The Hanged Man
    public const string DEATH = "💀"; // Death
    public const string TEMPERANCE = "⚗️"; // Temperance
    public const string DEVIL = "👿"; // The Devil
    public const string TOWER = "🏚️"; // The Tower
    public const string STAR = "⭐"; // The Star
    public const string MOON = "🌙"; // The Moon
    public const string SUN = "☀️"; // The Sun
    public const string JUDGMENT = "🔔"; // Judgment
    public const string WORLD = "🌍"; // The World

    // Tarot deck elements
    public const string CARD_BACK = "🂠"; // Card back
    public const string STAR_SPARK = "✦"; // Star
    public const string MYSTICAL = "✧"; // Mystical

    /// <summary>
    /// Lấy icon cho suit (Thứ)
    /// </summary>
    public static string GetSuitIcon(string suit)
    {
        return suit.ToLower() switch
        {
            "wands" or "gậy" => WANDS,
            "cups" or "cốc" => CUPS,
            "swords" or "kiếm" => SWORDS,
            "pentacles" or "xu" => PENTACLES,
            _ => "◈"
        };
    }

    /// <summary>
    /// Lấy icon cho major arcana
    /// </summary>
    public static string GetMajorArcanaIcon(int arcanaNumber)
    {
        return arcanaNumber switch
        {
            0 => FOOL,
            1 => MAGICIAN,
            2 => HIGH_PRIESTESS,
            3 => EMPRESS,
            4 => EMPEROR,
            5 => HIEROPHANT,
            6 => LOVERS,
            7 => CHARIOT,
            8 => STRENGTH,
            9 => HERMIT,
            10 => WHEEL,
            11 => JUSTICE,
            12 => HANGED,
            13 => DEATH,
            14 => TEMPERANCE,
            15 => DEVIL,
            16 => TOWER,
            17 => STAR,
            18 => MOON,
            19 => SUN,
            20 => JUDGMENT,
            21 => WORLD,
            _ => MYSTICAL
        };
    }
}
