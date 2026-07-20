using System;
using SQLite;

namespace TarotDesk;

/// <summary>
/// Model đại diện cho một lượt trải bài Tarot
/// </summary>
[Table("TarotReadings")]
public class TarotReading
{
    /// <summary>
    /// Khóa chính tự tăng
    /// </summary>
    [PrimaryKey, AutoIncrement]
    public int Id { get; set; }

    /// <summary>
    /// Id của bộ bài được sử dụng trong lượt trải này
    /// </summary>
    public int DeckId { get; set; }

    /// <summary>
    /// Tên/tiêu đề của lượt trải bài
    /// </summary>
    public string Name { get; set; }

    /// <summary>
    /// Ngày trải bài
    /// </summary>
    public DateTime Date { get; set; }

    /// <summary>
    /// Danh sách ID các lá bài được rút, lưu dưới dạng JSON (VD: "[1,3,5]")
    /// </summary>
    public string CardIds { get; set; }
}
