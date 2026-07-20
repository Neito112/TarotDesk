namespace TarotDesk;

/// <summary>
/// Helper class để truy cập các dịch vụ từ DI container
/// </summary>
public static class ServiceHelper
{
    public static T GetService<T>() where T : class
    {
        var shell = Application.Current?.MainPage as Shell;
        if (shell != null)
        {
            var serviceProvider = shell.Handler?.MauiContext?.Services;
            if (serviceProvider != null)
            {
                return serviceProvider.GetService<T>();
            }
        }

        // Fallback: Sử dụng static handler từ Application
        if (Application.Current?.Handler?.MauiContext?.Services is IServiceProvider serviceProvider2)
        {
            return serviceProvider2.GetService<T>();
        }

        return null;
    }
}
