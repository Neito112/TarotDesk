namespace TarotDesk.Services;

using TarotDesk.Models;
using System.Diagnostics;

/// <summary>
/// Service để quản lý user preferences (cài đặt)
/// </summary>
public class UserPreferencesService
{
    private readonly string _preferencesFile;
    private UserPreferences _preferences;

    public UserPreferences CurrentPreferences => _preferences;

    public UserPreferencesService()
    {
        _preferencesFile = Path.Combine(FileSystem.AppDataDirectory, "user_preferences.json");
        _preferences = new UserPreferences();
        LoadPreferences();
    }

    public void LoadPreferences()
    {
        try
        {
            if (File.Exists(_preferencesFile))
            {
                var json = File.ReadAllText(_preferencesFile);
                var loaded = System.Text.Json.JsonSerializer.Deserialize<UserPreferences>(json);
                if (loaded != null)
                {
                    _preferences = loaded;
                    // Đảm bảo theme được load
                    if (UserPreferences.AvailableThemes.ContainsKey(_preferences.CurrentTheme))
                    {
                        _preferences.SelectedTheme = UserPreferences.AvailableThemes[_preferences.CurrentTheme];
                    }
                }
            }
            else
            {
                _preferences = new UserPreferences();
                _preferences.SelectedTheme = UserPreferences.AvailableThemes["default"];
                SavePreferences();
            }
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Error loading preferences: {ex.Message}");
            _preferences = new UserPreferences();
            _preferences.SelectedTheme = UserPreferences.AvailableThemes["default"];
        }
    }

    public void SavePreferences()
    {
        try
        {
            var json = System.Text.Json.JsonSerializer.Serialize(_preferences);
            File.WriteAllText(_preferencesFile, json);
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Error saving preferences: {ex.Message}");
        }
    }

    public void SetTheme(string themeName)
    {
        if (UserPreferences.AvailableThemes.ContainsKey(themeName))
        {
            _preferences.CurrentTheme = themeName;
            _preferences.SelectedTheme = UserPreferences.AvailableThemes[themeName];
            SavePreferences();
            OnPreferencesChanged?.Invoke();
        }
    }

    public void SetBackgroundImage(string imagePath)
    {
        _preferences.BackgroundImagePath = imagePath;
        SavePreferences();
        OnPreferencesChanged?.Invoke();
    }

    public void UpdateThemeProperty(string propertyName, object value)
    {
        var property = typeof(AppTheme).GetProperty(propertyName);
        if (property != null && _preferences.SelectedTheme != null)
        {
            property.SetValue(_preferences.SelectedTheme, value);
            SavePreferences();
            OnPreferencesChanged?.Invoke();
        }
    }

    public event Action OnPreferencesChanged;
}
