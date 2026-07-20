using System;
using SQLite;

namespace TarotDesk;

/// <summary>
/// Model cho một bộ bài Tarot
/// </summary>
[Table("TarotDecks")]
public class TarotDeck
{
    /// <summary>
    /// Khóa chính tự tăng
    /// </summary>
    [PrimaryKey, AutoIncrement]
    public int Id { get; set; }

    /// <summary>
    /// Tên bộ bài
    /// </summary>
    public string Name { get; set; }

    /// <summary>
    /// Ngày tạo bộ bài
    /// </summary>
    public DateTime CreatedDate { get; set; }
}
