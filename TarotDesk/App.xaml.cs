using Microsoft.Extensions.DependencyInjection;

namespace TarotDesk
{
    public partial class App : Application
    {
        private DatabaseService _databaseService;

        public App()
        {
            InitializeComponent();
            _databaseService = IPlatformApplication.Current.Services.GetRequiredService<DatabaseService>();
        }

        protected override Window CreateWindow(IActivationState? activationState)
        {
            return new Window(new AppShell());
        }

        protected override void OnStart()
        {
            base.OnStart();
            MainThread.BeginInvokeOnMainThread(async () =>
            {
                await _databaseService.InitAsync();
            });
        }
    }
}
