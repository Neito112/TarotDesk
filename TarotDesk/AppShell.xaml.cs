namespace TarotDesk;

public partial class AppShell : Shell
{
    public AppShell()
    {
        InitializeComponent();

        // Đăng ký các trang con để có thể điều hướng bằng tên
        Routing.RegisterRoute("adddeck", typeof(AddDeckPage));
        Routing.RegisterRoute("selectdeck", typeof(SelectDeckPage));
        Routing.RegisterRoute("newreading", typeof(NewReadingPage));
        Routing.RegisterRoute("oldreadings", typeof(OldReadingsPage));
        Routing.RegisterRoute("readingdetail", typeof(ReadingDetailPage));
    }
}