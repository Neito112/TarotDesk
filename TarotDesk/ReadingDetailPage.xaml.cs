using System.Text.Json;

namespace TarotDesk;

public partial class ReadingDetailPage : ContentPage, IQueryAttributable
{
    private DatabaseService _databaseService;
    private int _readingId;

    public ReadingDetailPage()
    {
        InitializeComponent();
        _databaseService = IPlatformApplication.Current.Services.GetRequiredService<DatabaseService>();
    }

    public void ApplyQueryAttributes(IDictionary<string, object> query)
    {
        if (query.ContainsKey("readingId") && int.TryParse(query["readingId"].ToString(), out int readingId))
        {
            _readingId = readingId;
            MainThread.BeginInvokeOnMainThread(async () => await LoadReadingDetail());
        }
    }

    private async Task LoadReadingDetail()
    {
        try
        {
            var reading = await _databaseService.GetReadingByIdAsync(_readingId);
            if (reading == null)
            {
                await DisplayAlert("Lỗi", "Không tìm lưạt", "OK");
                await Shell.Current.GoToAsync("..");
                return;
            }

            ReadingNameLabel.Text = reading.Name;
            ReadingDateLabel.Text = $"📅 {reading.Date:dd/MM/yyyy HH:mm}";

            var cardIds = JsonSerializer.Deserialize<List<int>>(reading.CardIds) ?? new List<int>();
            var cards = await _databaseService.GetCardsByDeckIdAsync(reading.DeckId);
            var selectedCards = cards.Where(c => cardIds.Contains(c.Id)).ToList();

            CardsCollectionView.ItemsSource = selectedCards;
        }
        catch (Exception ex)
        {
            await DisplayAlert("Lỗi", $"Lỗi: {ex.Message}", "OK");
        }
    }
}
