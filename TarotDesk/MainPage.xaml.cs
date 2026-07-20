namespace TarotDesk;

using TarotDesk.Controls;

public partial class MainPage : ContentPage
{
    private SmokeParticleEffect _smokeEffect;

    public MainPage()
    {
        InitializeComponent();
    }

    protected override void OnAppearing()
    {
        base.OnAppearing();

        // Get smoke effect from the page (if it exists)
        _smokeEffect = this.FindByName<SmokeParticleEffect>("SmokeEffect");

        if (_smokeEffect != null)
        {
            _smokeEffect.StartAnimation();
        }

        // Kiểm tra xem có lưỡt trải bài chưa lưu không
        if (Preferences.ContainsKey("UnsavedReading"))
        {
            var resumeButton = this.FindByName<Button>("ResumeButton");
            if (resumeButton != null)
                resumeButton.IsVisible = true;
        }
        else
        {
            var resumeButton = this.FindByName<Button>("ResumeButton");
            if (resumeButton != null)
                resumeButton.IsVisible = false;
        }
    }

    protected override void OnDisappearing()
    {
        base.OnDisappearing();

        if (_smokeEffect != null)
        {
            _smokeEffect.StopAnimation();
        }
    }

    // Bấm nút "Thêm bộ bài"
    private async void OnAddDeckClicked(object sender, EventArgs e)
    {
        await Shell.Current.GoToAsync("adddeck");
    }

    // Bấm nút "Lưỡt trải bài mới" - chuyển đến SelectDeckPage để chọn bộ bài
    private async void OnNewReadingClicked(object sender, EventArgs e)
    {
        await Shell.Current.GoToAsync("selectdeck");
    }

    // Bấm nút "Lịch sử trải bài"
    private async void OnOldReadingsClicked(object sender, EventArgs e)
    {
        await Shell.Current.GoToAsync("oldreadings");
    }

    // Bấm nút "Tiếp tục trải bài cũ"
    private async void OnResumeReadingClicked(object sender, EventArgs e)
    {
        await Shell.Current.GoToAsync("newreading?resume=true");
    }

    // Bấm nút "Cài đặt giao diện"
    private async void OnSettingsClicked(object sender, EventArgs e)
    {
        await Shell.Current.GoToAsync("settings");
    }
}

