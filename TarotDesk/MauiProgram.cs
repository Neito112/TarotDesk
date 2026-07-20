using Microsoft.Extensions.Logging;
using TarotDesk.Services;
using TarotDesk.Controls;

namespace TarotDesk;

public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        var builder = MauiApp.CreateBuilder();
        builder
            .UseMauiApp<App>()
            .ConfigureFonts(fonts =>
            {
                fonts.AddFont("OpenSans-Regular.ttf", "OpenSansRegular");
                fonts.AddFont("OpenSans-Semibold.ttf", "OpenSansSemibold");
            });

        // Đăng ký DatabaseService như Singleton
        builder.Services.AddSingleton<DatabaseService>();

        // Đăng ký UserPreferencesService  
        builder.Services.AddSingleton<UserPreferencesService>();

        // Đăng ký Pages
        builder.Services.AddTransient<SettingsPage>();
        builder.Services.AddTransient<MainPage>();

        // Đăng ký Custom Controls
        builder.Services.AddTransient<GlassPanel>();
        builder.Services.AddTransient<SmokeParticleEffect>();
        builder.Services.AddTransient<TwinklingLabel>();

#if DEBUG
        builder.Logging.AddDebug();
#endif

        return builder.Build();
    }
}

