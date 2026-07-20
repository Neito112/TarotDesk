using System.Collections.ObjectModel;
using System.Text.Json;

namespace TarotDesk;

public partial class NewReadingPage : ContentPage, IQueryAttributable
{
    private DatabaseService _databaseService;
    private ObservableCollection<TarotCard> _drawnCards;
    private List<TarotCard> _deckCards;
    private int _deckId;
    private bool _isResuming;
    private TarotCard _currentCard;

    public NewReadingPage()
    {
        InitializeComponent();
        _databaseService = IPlatformApplication.Current.Services.GetRequiredService<DatabaseService>();
        _drawnCards = new ObservableCollection<TarotCard>();
        _deckCards = new List<TarotCard>();
        DrawnCardsCollectionView.ItemsSource = _drawnCards;
    }

    public void ApplyQueryAttributes(IDictionary<string, object> query)
    {
        if (query.ContainsKey("deckId") && int.TryParse(query["deckId"].ToString(), out int deckId))
        {
            _deckId = deckId;
            MainThread.BeginInvokeOnMainThread(async () => await LoadDeck());
        }

        if (query.ContainsKey("resume") && bool.TryParse(query["resume"].ToString(), out bool resume) && resume)
        {
            _isResuming = true;
            MainThread.BeginInvokeOnMainThread(async () => await ResumeReading());
        }
    }

    private async Task LoadDeck()
    {
        try
        {
            _deckCards = await _databaseService.GetCardsByDeckIdAsync(_deckId);
            if (_deckCards.Count == 0)
            {
                await DisplayAlert("Lỗi", "Deck không có lá bài", "OK");
                await Shell.Current.GoToAsync("..");
            }
        }
        catch (Exception ex)
        {
            await DisplayAlert("Lỗi", $"Lỗi tải deck: {ex.Message}", "OK");
        }
    }

    private async Task ResumeReading()
    {
        try
        {
            if (Preferences.ContainsKey("UnsavedReading"))
            {
                var json = Preferences.Get("UnsavedReading", "");
                if (!string.IsNullOrEmpty(json))
                {
                    var resumeData = JsonSerializer.Deserialize<SavedReadingData>(json);
                    if (resumeData != null)
                    {
                        _deckId = resumeData.DeckId;
                        await LoadDeck();

                        if (resumeData.CardIds != null)
                        {
                            foreach (int cardId in resumeData.CardIds)
                            {
                                var card = _deckCards.FirstOrDefault(c => c.Id == cardId);
                                if (card != null)
                                {
                                    _drawnCards.Add(card);
                                }
                            }
                        }
                    }
                }
            }
        }
        catch (Exception ex)
        {
            await DisplayAlert("Lỗi", $"Lỗi resume: {ex.Message}", "OK");
        }
    }

    private async void OnBackClicked(object sender, EventArgs e)
    {
        if (_drawnCards.Count > 0)
        {
            var cardIds = _drawnCards.Select(c => c.Id).ToList();
            var saveData = new SavedReadingData
            {
                DeckId = _deckId,
                CardIds = cardIds
            };
            Preferences.Set("UnsavedReading", JsonSerializer.Serialize(saveData));
        }
        await Shell.Current.GoToAsync("..");
    }

    private async void OnDrawCardClicked(object sender, EventArgs e)
    {
        try
        {
            if (_deckCards.Count == 0)
            {
                await DisplayAlert("Lỗi", "Deck không có lá bài", "OK");
                return;
            }

            Random random = new Random();
            _currentCard = _deckCards[random.Next(_deckCards.Count)];

            if (!string.IsNullOrEmpty(_currentCard.ImagePath) && File.Exists(_currentCard.ImagePath))
            {
                CardImage.Source = ImageSource.FromFile(_currentCard.ImagePath);
            }

            CardNameLabel.Text = _currentCard.Name;
            CardMeaningLabel.Text = _currentCard.Meaning;
            NoCardLabel.IsVisible = false;
            _drawnCards.Add(_currentCard);
        }
        catch (Exception ex)
        {
            await DisplayAlert("Lỗi", $"Lỗi: {ex.Message}", "OK");
        }
    }

    private async void OnSaveReadingClicked(object sender, EventArgs e)
    {
        try
        {
            if (_drawnCards.Count == 0)
            {
                await DisplayAlert("Lỗi", "Rút ít nhất 1 lá bài", "OK");
                return;
            }

            var cardIds = _drawnCards.Select(c => c.Id).ToList();
            var reading = new TarotReading
            {
                DeckId = _deckId,
                Date = DateTime.Now,
                CardIds = JsonSerializer.Serialize(cardIds)
            };

            await _databaseService.InsertReadingAsync(reading);
            await DisplayAlert("Thành công", "Lưu lượt thành công", "OK");
            Preferences.Remove("UnsavedReading");
            _drawnCards.Clear();
            NoCardLabel.IsVisible = true;
            CardImage.Source = null;
            CardNameLabel.Text = "";
            CardMeaningLabel.Text = "";
            await Shell.Current.GoToAsync("..");
        }
        catch (Exception ex)
        {
            await DisplayAlert("Lỗi", $"Lỗi: {ex.Message}", "OK");
        }
    }
}

internal class SavedReadingData
{
    public int DeckId { get; set; }
    public List<int> CardIds { get; set; }
}
