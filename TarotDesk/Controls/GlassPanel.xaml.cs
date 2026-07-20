namespace TarotDesk.Controls;

using Microsoft.Maui.Graphics;

/// <summary>
/// Glass Panel - Glassmorphism container with blur effect
/// </summary>
public partial class GlassPanel : Border
{
    // Bindable properties
    public static readonly BindableProperty GlassOpacityProperty =
        BindableProperty.Create(nameof(GlassOpacity), typeof(double), typeof(GlassPanel), 0.15,
            propertyChanged: OnGlassOpacityChanged);

    public static readonly BindableProperty AccentColorProperty =
        BindableProperty.Create(nameof(AccentColor), typeof(Color), typeof(GlassPanel), Colors.White);

    public static readonly BindableProperty BlurRadiusProperty =
        BindableProperty.Create(nameof(BlurRadius), typeof(double), typeof(GlassPanel), 10d);

    public double GlassOpacity
    {
        get => (double)GetValue(GlassOpacityProperty);
        set => SetValue(GlassOpacityProperty, value);
    }

    public Color AccentColor
    {
        get => (Color)GetValue(AccentColorProperty);
        set => SetValue(AccentColorProperty, value);
    }

    public double BlurRadius
    {
        get => (double)GetValue(BlurRadiusProperty);
        set => SetValue(BlurRadiusProperty, value);
    }

    public GlassPanel()
    {
        ApplyGlassEffect();
    }

    private static void OnGlassOpacityChanged(BindableObject bindable, object oldValue, object newValue)
    {
        if (bindable is GlassPanel panel)
        {
            panel.ApplyGlassEffect();
        }
    }

    private void ApplyGlassEffect()
    {
        // Semi-transparent background with glass effect
        this.BackgroundColor = new Color(
            (int)(AccentColor.Red * 255),
            (int)(AccentColor.Green * 255),
            (int)(AccentColor.Blue * 255),
            (int)(GlassOpacity * 255)
        );

        // Border color - subtle highlight
        this.Stroke = new Color(
            (int)(AccentColor.Red * 255),
            (int)(AccentColor.Green * 255),
            (int)(AccentColor.Blue * 255),
            102
        );

        this.StrokeThickness = 1.5;

        // Shadow for depth
        this.Shadow = new Shadow
        {
            Brush = Colors.Black,
            Offset = new Point(0, 4),
            Radius = 8,
            Opacity = 0.2f
        };
    }
}
