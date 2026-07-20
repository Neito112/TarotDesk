🎯 TarotDesk Advanced UI Enhancement with Settings & Tarot Icons
Understanding
Người dùng muốn:

Thêm Settings page để tùy chỉnh giao diện (background, text effects)
Sửa toolbars - text màu đen bị chìm, cần dùng trắng
Thêm glass morphism (glassmorphism) effects khắp giao diện
Thêm hiệu ứng khói sương mờ phảng phất (particle effects)
Thay thế icons từ bài tây sang Tarot symbols: Wands (Gậy), Cups (Cốc), Swords (Kiếm), Pentacles (Xu)
Assumptions
Sẽ tạo SettingsPage.xaml mới để quản lý themes và backgrounds
Sẽ tạo AppSettings class để lưu trữ preferences (UserPreferences)
Glass morphism sẽ được thực hiện bằng Border + Blur + Gradient
Particle effects (khói) sẽ dùng Canvas hoặc animations
Icons Tarot sẽ dùng Unicode symbols hoặc tạo SVG resources
Cần AppShell.xaml để thêm Settings navigation tab
Approach
Tạo Settings infrastructure: UserPreferences class, SettingsService, AppSettings.xaml
Tạo SettingsPage: UI để chọn background, text effects, theme colors
Thêm Glass Morphism: Cập nhật Styles.xaml với blur effects, semi-transparent backgrounds
Fix Toolbars: Cập nhật text color từ đen sang trắng/golden
Thêm Particle Effects: Tạo SmokeEffect.xaml component với animation
Thay thế Icons: Dùng Tarot Unicode symbols hoặc SVG cho Wands ♠→♣, Cups ♥, Swords ⚄, Pentacles 🔮
Update MainPage & OtherPages: Áp dụng glass morphism + new icons + settings integration
Tạo Theme System: Models để quản lý themes khác nhau
Build & Test: Đảm bảo không có errors
Key Files
TarotDesk/Views/SettingsPage.xaml & .cs - Cài đặt giao diện
TarotDesk/Services/UserPreferencesService.cs - Quản lý user settings
TarotDesk/Models/AppTheme.cs - Theme definitions
TarotDesk/Utils/TarotSymbols.cs - Icons tarot symbols
TarotDesk/Controls/GlassPanel.xaml & .cs - Glass morphism container
TarotDesk/Controls/SmokeParticle.xaml & .cs - Hiệu ứng khói
TarotDesk/Resources/Styles/Styles.xaml - Cập nhật glass effects
TarotDesk/AppShell.xaml - Thêm Settings tab
Các Pages khác - Áp dụng glass morphism & tarot icons
Risks & Open Questions
Performance của particle effects trên devices di động
Compatibility của Unicode tarot symbols trên các platforms
Storage preferences (local file vs preferences API)
Background image handling (memory vs quality)
Last Updated: 2026-07-20 20:06:05

📝 Plan Steps
Tạo UserPreferencesService & AppTheme models - quản lý user settings
Tạo GlassPanel custom control - glass morphism reusable component
Tạo SettingsPage.xaml & .cs - UI cài đặt theme, backgrounds, effects
Tạo TarotSymbols utility - định nghĩa icons Tarot (gậy, cốc, kiếm, xu)
Tạo SmokeParticleEffect - hiệu ứng khói sương trang trí
Cập nhật AppShell.xaml - thêm Settings navigation
Cập nhật Styles.xaml - glass morphism styles cho tất cả controls
Cập nhật MainPage.xaml - áp dụng glass effects, tarot icons, smoke particles
Cập nhật tất cả XAML pages - sử dụng glass panels, tarot icons, text colors
Cập nhật Toolbars - text colors từ đen sang trắng/golden
Build & comprehensive test - đảm bảo tất cả features hoạt động
