namespace TarotDesk;

using TarotDesk.Services;
using TarotDesk.Models;
using System.Diagnostics;

public partial class SettingsPage : ContentPage
{
    private UserPreferencesService _preferencesService;

    public SettingsPage()
    {
        InitializeComponent();
        _preferencesService = ServiceHelper.GetService<UserPreferencesService>();
        LoadSettings();
    }

    private void LoadSettings()
    {
        try
        {
            var prefs = _preferencesService.CurrentPreferences;

            // Load theme names
            var themeNames = UserPreferences.AvailableThemes.Keys.ToList();
            var themePicker = this.FindByName<Picker>("ThemePicker");
            if (themePicker != null)
            {
                themePicker.ItemsSource = themeNames.Select(k => UserPreferences.AvailableThemes[k].Name).ToList();
                themePicker.SelectedItem = prefs.SelectedTheme.Name;
            }

            // Load other settings
            var glassSwitch = this.FindByName<Switch>("GlassEffectSwitch");
            if (glassSwitch != null)
                glassSwitch.IsChecked = prefs.SelectedTheme.EnableGlassEffect;

            var smokeSwitch = this.FindByName<Switch>("SmokeEffectSwitch");
            if (smokeSwitch != null)
                smokeSwitch.IsChecked = prefs.SelectedTheme.EnableSmokeEffect;

            var opacitySlider = this.FindByName<Slider>("GlassOpacitySlider");
            if (opacitySlider != null)
                opacitySlider.Value = prefs.SelectedTheme.GlassOpacity;

            var speedSlider = this.FindByName<Slider>("AnimationSpeedSlider");
            if (speedSlider != null)
                speedSlider.Value = prefs.TextAnimationSpeed;
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Error loading settings: {ex.Message}");
        }
    }

    private void OnThemeChanged(object sender, EventArgs e)
    {
        try
        {
            var picker = sender as Picker;
            if (picker?.SelectedItem is string themeName)
            {
                var matchingTheme = UserPreferences.AvailableThemes.FirstOrDefault(
                    t => t.Value.Name == themeName).Key;

                if (!string.IsNullOrEmpty(matchingTheme))
                {
                    _preferencesService.SetTheme(matchingTheme);
                }
            }
        }
        catch (Exception ex)
        {
            Debug.WriteLine($"Error changing theme: {ex.Message}");
        }
    }

    private void OnGlassEffectToggled(object sender, ToggledEventArgs e)
    {
        _preferencesService.UpdateThemeProperty("EnableGlassEffect", e.Value);
    }

    private void OnSmokeEffectToggled(object sender, ToggledEventArgs e)
    {
        _preferencesService.UpdateThemeProperty("EnableSmokeEffect", e.Value);
    }

    private void OnGlassOpacityChanged(object sender, ValueChangedEventArgs e)
    {
        _preferencesService.UpdateThemeProperty("GlassOpacity", e.NewValue);
    }

    private void OnAnimationSpeedChanged(object sender, ValueChangedEventArgs e)
    {
        var speed = Math.Round(e.NewValue, 1);
        var speedLabel = this.FindByName<Label>("AnimationSpeedLabel");
        if (speedLabel != null)
            speedLabel.Text = $"{speed}x";

        _preferencesService.CurrentPreferences.TextAnimationSpeed = speed;
        _preferencesService.SavePreferences();
    }

    private void OnToolbarColorWhiteClicked(object sender, EventArgs e)
    {
        _preferencesService.CurrentPreferences.ToolbarTextColor = "#FFFFFF";
        _preferencesService.SavePreferences();
    }

    private void OnToolbarColorGoldenClicked(object sender, EventArgs e)
    {
        _preferencesService.CurrentPreferences.ToolbarTextColor = "#FFD700";
        _preferencesService.SavePreferences();
    }

    private void OnToolbarColorPurpleClicked(object sender, EventArgs e)
    {
        _preferencesService.CurrentPreferences.ToolbarTextColor = "#DA70D6";
        _preferencesService.SavePreferences();
    }

    private void OnResetSettings(object sender, EventArgs e)
    {
        _preferencesService.SetTheme("default");
        LoadSettings();
    }
}

