namespace TarotDesk;

public class DeckDisplayModel
{
    public int Id { get; set; }
    public string Name { get; set; }
    public int CardCount { get; set; }
    public string CardCountText => $"📚 {CardCount} lá bài";
}

public partial class SelectDeckPage : ContentPage
{
    private DatabaseService _databaseService;

    public SelectDeckPage()
    {
        InitializeComponent();
        _databaseService = IPlatformApplication.Current.Services.GetRequiredService<DatabaseService>();
    }

    protected override async void OnAppearing()
    {
        base.OnAppearing();
        await LoadDecks();
    }

    private async Task LoadDecks()
    {
        try
        {
            LoadingIndicator.IsRunning = true;
            LoadingIndicator.IsVisible = true;

            var decks = await _databaseService.GetAllDecksAsync();

            if (decks.Count == 0)
            {
                NoDecksLabel.IsVisible = true;
                DecksCollectionView.IsVisible = false;
                LoadingIndicator.IsRunning = false;
                LoadingIndicator.IsVisible = false;
                return;
            }

            var displayList = new List<DeckDisplayModel>();
            foreach (var deck in decks)
            {
                var cards = await _databaseService.GetCardsByDeckIdAsync(deck.Id);
                displayList.Add(new DeckDisplayModel
                {
                    Id = deck.Id,
                    Name = deck.Name,
                    CardCount = cards.Count
                });
            }

            DecksCollectionView.ItemsSource = displayList;
            NoDecksLabel.IsVisible = false;
            DecksCollectionView.IsVisible = true;

            // Gắn event handler selection
            DecksCollectionView.SelectionChanged += async (s, e) =>
            {
                if (e.CurrentSelection.FirstOrDefault() is DeckDisplayModel selected)
                {
                    await Shell.Current.GoToAsync($"newreading?deckId={selected.Id}");
                }
            };
        }
        catch (Exception ex)
        {
            await DisplayAlert("Lỗi", $"Lỗi tải deck: {ex.Message}", "OK");
        }
        finally
        {
            LoadingIndicator.IsRunning = false;
            LoadingIndicator.IsVisible = false;
        }
    }
}
