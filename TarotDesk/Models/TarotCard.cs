using System;
using SQLite;

namespace TarotDesk;

/// <summary>
/// Model đại diện cho một lá bài Tarot
/// </summary>
[Table("TarotCards")]
public class TarotCard
{
    /// <summary>
    /// Khóa chính tự tăng
    /// </summary>
    [PrimaryKey, AutoIncrement]
    public int Id { get; set; }

    /// <summary>
    /// Id của bộ bài mà lá bài này thuộc về
    /// </summary>
    public int DeckId { get; set; }

    /// <summary>
    /// Tên lá bài
    /// </summary>
    public string Name { get; set; }

    /// <summary>
    /// Nội dung diễn giải/ý nghĩa của lá bài
    /// </summary>
    public string Meaning { get; set; }

    /// <summary>
    /// Đường dẫn file ảnh lưu cục bộ
    /// </summary>
    public string ImagePath { get; set; }
}
