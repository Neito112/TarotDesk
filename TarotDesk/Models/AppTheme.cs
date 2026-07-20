namespace TarotDesk.Models;

/// <summary>
/// Định nghĩa Theme cho ứng dụng Tarot
/// </summary>
public class AppTheme
{
    public string Name { get; set; } = "Default Galaxy";
    public string BackgroundColor { get; set; } = "#0a0514";
    public string AccentColor { get; set; } = "#FFD700";
    public string TextColor { get; set; } = "#FFFFFF";
    public bool EnableGlassEffect { get; set; } = true;
    public bool EnableSmokeEffect { get; set; } = true;
    public double GlassOpacity { get; set; } = 0.15;
    public double BlurRadius { get; set; } = 10;
}

/// <summary>
/// User preferences cho ứng dụng
/// </summary>
public class UserPreferences
{
    public string CurrentTheme { get; set; } = "default";
    public string BackgroundImagePath { get; set; } = "";
    public AppTheme SelectedTheme { get; set; } = new();
    public bool EnableAnimations { get; set; } = true;
    public bool EnableParticleEffects { get; set; } = true;
    public double TextAnimationSpeed { get; set; } = 1.0;
    public string ToolbarTextColor { get; set; } = "#FFFFFF";

    public static Dictionary<string, AppTheme> AvailableThemes => new()
    {
        {
            "default",
            new AppTheme
            {
                Name = "Galaxy Noir",
                BackgroundColor = "#0a0514",
                AccentColor = "#FFD700",
                TextColor = "#FFFFFF",
                EnableGlassEffect = true,
                EnableSmokeEffect = true
            }
        },
        {
            "mystic",
            new AppTheme
            {
                Name = "Mystic Purple",
                BackgroundColor = "#1a0033",
                AccentColor = "#DA70D6",
                TextColor = "#E0E0E0",
                EnableGlassEffect = true,
                EnableSmokeEffect = true
            }
        },
        {
            "ocean",
            new AppTheme
            {
                Name = "Ocean Blue",
                BackgroundColor = "#001a4d",
                AccentColor = "#00BFFF",
                TextColor = "#FFFFFF",
                EnableGlassEffect = true,
                EnableSmokeEffect = true
            }
        },
        {
            "twilight",
            new AppTheme
            {
                Name = "Twilight",
                BackgroundColor = "#0d1b2a",
                AccentColor = "#FF6B9D",
                TextColor = "#FFFFFF",
                EnableGlassEffect = true,
                EnableSmokeEffect = true
            }
        }
    };
}
