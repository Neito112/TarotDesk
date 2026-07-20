using System.Collections.ObjectModel;

namespace TarotDesk;

public partial class AddDeckPage : ContentPage
{
    private DatabaseService _databaseService;
    private ObservableCollection<TarotCard> _tempCards;
    private int _currentDeckId;

    public AddDeckPage()
    {
        InitializeComponent();
        _databaseService = IPlatformApplication.Current.Services.GetRequiredService<DatabaseService>();
        _tempCards = new ObservableCollection<TarotCard>();
        CardsCollectionView.ItemsSource = _tempCards;
    }

    private async void OnAddCardClicked(object sender, EventArgs e)
    {
        try
        {
            var result = await MediaPicker.PickPhotoAsync();
            if (result == null) return;

            string imagePath = await SaveImageAsync(result);

            var cardName = await DisplayPromptAsync("Tên lá bài", "Nhập tên:");
            if (string.IsNullOrWhiteSpace(cardName)) return;

            var cardMeaning = await DisplayPromptAsync("Ý nghĩa", "Nhập diễn giải:", maxLength: 300);

            var card = new TarotCard
            {
                Name = cardName,
                Meaning = cardMeaning ?? "",
                ImagePath = imagePath,
                DeckId = 0  // Sẽ set khi lưu deck
            };

            _tempCards.Add(card);
        }
        catch (Exception ex)
        {
            await DisplayAlert("Lỗi", $"Error: {ex.Message}", "OK");
        }
    }

    private async Task<string> SaveImageAsync(FileResult result)
    {
        try
        {
            string cardFolder = Path.Combine(FileSystem.AppDataDirectory, "cards");
            Directory.CreateDirectory(cardFolder);

            string fileName = $"{Guid.NewGuid()}.jpg";
            string filePath = Path.Combine(cardFolder, fileName);

            using (var sourceStream = await result.OpenReadAsync())
            using (var fileStream = File.Create(filePath))
            {
                await sourceStream.CopyToAsync(fileStream);
            }

            return filePath;
        }
        catch (Exception ex)
        {
            await DisplayAlert("Lỗi", $"Lỗi lưu ảnh: {ex.Message}", "OK");
            return "";
        }
    }

    private async void OnSaveDeckClicked(object sender, EventArgs e)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(DeckNameEntry.Text))
            {
                await DisplayAlert("Lỗi", "Nhập tên bộ bài", "OK");
                return;
            }

            if (_tempCards.Count == 0)
            {
                await DisplayAlert("Lỗi", "Thêm ít nhất 1 lá bài", "OK");
                return;
            }

            // Tạo TarotDeck
            var deck = new TarotDeck
            {
                Name = DeckNameEntry.Text,
                CreatedDate = DateTime.Now
            };

            await _databaseService.InsertDeckAsync(deck);

            // Lấy ID của deck vừa tạo
            var allDecks = await _databaseService.GetAllDecksAsync();
            var newDeck = allDecks.LastOrDefault();

            if (newDeck == null)
            {
                await DisplayAlert("Lỗi", "Không tìm deck", "OK");
                return;
            }

            // Lưu từng lá bài
            foreach (var card in _tempCards)
            {
                card.DeckId = newDeck.Id;
                await _databaseService.InsertCardAsync(card);
            }

            await DisplayAlert("Thành công", $"Lưu {_tempCards.Count} lá bài", "OK");

            // Reset và quay về
            _tempCards.Clear();
            DeckNameEntry.Text = "";
            await Shell.Current.GoToAsync("..");
        }
        catch (Exception ex)
        {
            await DisplayAlert("Lỗi", $"Error: {ex.Message}", "OK");
        }
    }
}
