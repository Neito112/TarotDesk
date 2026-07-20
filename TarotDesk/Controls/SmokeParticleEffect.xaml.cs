namespace TarotDesk.Controls;

using Microsoft.Maui.Graphics;

/// <summary>
/// Smoke Particle Effect - Hiệu ứng khói sương mờ
/// </summary>
public partial class SmokeParticleEffect : GraphicsView
{
    private List<Particle> _particles = new();
    private Random _random = new();
    private bool _isAnimating = false;

    public SmokeParticleEffect()
    {
        this.Drawable = new SmokeDrawable(this);
    }

    public void StartAnimation()
    {
        if (_isAnimating) return;

        _isAnimating = true;
        InitializeParticles();
        AnimateParticles();
    }

    public void StopAnimation()
    {
        _isAnimating = false;
        _particles.Clear();
    }

    private void InitializeParticles()
    {
        _particles.Clear();

        // Tạo particles ngẫu nhiên
        for (int i = 0; i < 30; i++)
        {
            _particles.Add(new Particle
            {
                X = _random.NextDouble() * this.Width,
                Y = _random.NextDouble() * this.Height,
                VelocityX = (_random.NextDouble() - 0.5) * 2,
                VelocityY = (_random.NextDouble() - 0.5) * 2,
                Radius = _random.NextDouble() * 20 + 5,
                Opacity = 0.3,
                LifeTime = _random.NextDouble() * 3 + 2 // 2-5 seconds
            });
        }
    }

    private async void AnimateParticles()
    {
        while (_isAnimating && _particles.Count > 0)
        {
            foreach (var particle in _particles)
            {
                particle.Update(0.016); // ~60fps
            }

            // Xóa particles đã hết lifetime
            _particles.RemoveAll(p => p.LifeTime <= 0);

            // Invalidate để redraw
            this.Invalidate();

            await Task.Delay(16); // ~60fps
        }
    }

    private class Particle
    {
        public double X { get; set; }
        public double Y { get; set; }
        public double VelocityX { get; set; }
        public double VelocityY { get; set; }
        public double Radius { get; set; }
        public double Opacity { get; set; }
        public double LifeTime { get; set; }

        public void Update(double deltaTime)
        {
            X += VelocityX;
            Y += VelocityY;
            LifeTime -= deltaTime;

            // Fade out theo thời gian
            if (LifeTime > 0)
            {
                Opacity = Math.Max(0, 0.3 * (LifeTime / 3));
            }
        }
    }

    private class SmokeDrawable : IDrawable
    {
        private SmokeParticleEffect _parent;

        public SmokeDrawable(SmokeParticleEffect parent)
        {
            _parent = parent;
        }

        public void Draw(ICanvas canvas, RectF dirtyRect)
        {
            canvas.FillColor = Colors.White;

            foreach (var particle in _parent._particles)
            {
                canvas.Alpha = (float)particle.Opacity;
                canvas.FillCircle((float)particle.X, (float)particle.Y, (float)particle.Radius);
            }

            canvas.Alpha = 1.0f;
        }
    }
}
