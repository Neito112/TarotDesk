namespace TarotDesk.Controls;

public partial class TwinklingLabel : Label
{
    private bool _isAnimating = false;
    private double _minOpacity = 0.3;
    private double _maxOpacity = 1.0;
    private uint _animationDuration = 800; // milliseconds

    public TwinklingLabel()
    {
        InitializeComponent();
        this.Loaded += OnLoaded;
        this.Unloaded += OnUnloaded;
    }

    private void OnLoaded(object? sender, EventArgs e)
    {
        if (!_isAnimating)
        {
            StartTwinkle();
        }
    }

    private void OnUnloaded(object? sender, EventArgs e)
    {
        StopTwinkle();
    }

    public async void StartTwinkle()
    {
        _isAnimating = true;
        while (_isAnimating && this.IsLoaded)
        {
            // Fade out
            await this.FadeTo(_minOpacity, _animationDuration / 2);
            // Fade in
            await this.FadeTo(_maxOpacity, _animationDuration / 2);
        }
    }

    public void StopTwinkle()
    {
        _isAnimating = false;
        this.Opacity = _maxOpacity;
    }
}

