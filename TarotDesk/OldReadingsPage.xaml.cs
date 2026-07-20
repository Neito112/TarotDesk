using System.Text.Json;

namespace TarotDesk;

public class ReadingDisplayModel
{
    public int Id { get; set; }
    public string Name { get; set; }
    public DateTime Date { get; set; }
    public int CardCount { get; set; }
    public string DateText => Date.ToString("dd/MM/yyyy HH:mm");
    public string CardCountText => $"📚 {CardCount} lá bài";
}

public partial class OldReadingsPage : ContentPage
{
    private DatabaseService _databaseService;

    public OldReadingsPage()
    {
        InitializeComponent();
        _databaseService = IPlatformApplication.Current.Services.GetRequiredService<DatabaseService>();
    }

    protected override async void OnAppearing()
    {
        base.OnAppearing();
        await LoadReadings();
    }

    private async Task LoadReadings()
    {
        try
        {
            LoadingIndicator.IsRunning = true;
            LoadingIndicator.IsVisible = true;

            var readings = await _databaseService.GetAllReadingsAsync();

            if (readings.Count == 0)
            {
                NoReadingsLabel.IsVisible = true;
                ReadingsCollectionView.IsVisible = false;
                LoadingIndicator.IsRunning = false;
                LoadingIndicator.IsVisible = false;
                return;
            }

            var displayList = new List<ReadingDisplayModel>();
            foreach (var reading in readings)
            {
                try
                {
                    var cardIds = JsonSerializer.Deserialize<List<int>>(reading.CardIds) ?? new List<int>();
                    displayList.Add(new ReadingDisplayModel
                    {
                        Id = reading.Id,
                        Name = reading.Name,
                        Date = reading.Date,
                        CardCount = cardIds.Count
                    });
                }
                catch
                {
                    displayList.Add(new ReadingDisplayModel
                    {
                        Id = reading.Id,
                        Name = reading.Name,
                        Date = reading.Date,
                        CardCount = 0
                    });
                }
            }

            ReadingsCollectionView.ItemsSource = displayList;
            NoReadingsLabel.IsVisible = false;
            ReadingsCollectionView.IsVisible = true;

            // Gắn event handler selection
            ReadingsCollectionView.SelectionChanged += async (s, e) =>
            {
                if (e.CurrentSelection.FirstOrDefault() is ReadingDisplayModel selected)
                {
                    await Shell.Current.GoToAsync($"readingdetail?readingId={selected.Id}");
                }
            };
        }
        catch (Exception ex)
        {
            await DisplayAlert("Lỗi", $"Lỗi tải lưạt: {ex.Message}", "OK");
        }
        finally
        {
            LoadingIndicator.IsRunning = false;
            LoadingIndicator.IsVisible = false;
        }
    }
}
