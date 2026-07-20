using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using SQLite;
using TarotDesk;

namespace TarotDesk;

    /// <summary>
    /// Dịch vụ quản lý cơ sở dữ liệu SQLite cho ứng dụng TarotDesk
    /// Singleton pattern - khởi tạo 1 lần duy nhất
    /// </summary>
    public class DatabaseService
    {
        private SQLiteAsyncConnection _database;
        private const string DatabaseFileName = "tarotdesk.db";

        public DatabaseService()
        {
        }

        /// <summary>
        /// Khởi tạo kết nối cơ sở dữ liệu và tạo bảng nếu chưa tồn tại
        /// </summary>
        public async Task InitAsync()
        {
            if (_database is not null)
                return;

            try
            {
                var databasePath = Path.Combine(FileSystem.AppDataDirectory, DatabaseFileName);

                _database = new SQLiteAsyncConnection(databasePath);

                // Tạo các bảng nếu chưa tồn tại
                await _database.CreateTableAsync<TarotCard>();
                await _database.CreateTableAsync<TarotDeck>();
                await _database.CreateTableAsync<TarotReading>();
            }
            catch (Exception ex)
            {
                throw new Exception($"Lỗi khởi tạo cơ sở dữ liệu: {ex.Message}", ex);
            }
        }

        // ==================== TarotCard Operations ====================

        /// <summary>
        /// Thêm một lá bài mới vào cơ sở dữ liệu
        /// </summary>
        public async Task<int> InsertCardAsync(TarotCard card)
        {
            try
            {
                return await _database.InsertAsync(card);
            }
            catch (Exception ex)
            {
                throw new Exception($"Lỗi thêm lá bài: {ex.Message}", ex);
            }
        }

        /// <summary>
        /// Lấy toàn bộ danh sách lá bài
        /// </summary>
        public async Task<List<TarotCard>> GetAllCardsAsync()
        {
            try
            {
                return await _database.Table<TarotCard>().ToListAsync();
            }
            catch (Exception ex)
            {
                throw new Exception($"Lỗi lấy danh sách lá bài: {ex.Message}", ex);
            }
        }

        /// <summary>
        /// Lấy danh sách lá bài theo ID bộ bài
        /// </summary>
        public async Task<List<TarotCard>> GetCardsByDeckIdAsync(int deckId)
        {
            try
            {
                return await _database.Table<TarotCard>()
                    .Where(c => c.DeckId == deckId)
                    .ToListAsync();
            }
            catch (Exception ex)
            {
                throw new Exception($"Lỗi lấy danh sách lá bài theo bộ: {ex.Message}", ex);
            }
        }

        // ==================== TarotDeck Operations ====================

        /// <summary>
        /// Thêm một bộ bài mới
        /// </summary>
        public async Task<int> InsertDeckAsync(TarotDeck deck)
        {
            try
            {
                deck.CreatedDate = DateTime.Now;
                return await _database.InsertAsync(deck);
            }
            catch (Exception ex)
            {
                throw new Exception($"Lỗi thêm bộ bài: {ex.Message}", ex);
            }
        }

        /// <summary>
        /// Lấy danh sách toàn bộ bộ bài
        /// </summary>
        public async Task<List<TarotDeck>> GetAllDecksAsync()
        {
            try
            {
                return await _database.Table<TarotDeck>()
                    .OrderByDescending(d => d.CreatedDate)
                    .ToListAsync();
            }
            catch (Exception ex)
            {
                throw new Exception($"Lỗi lấy danh sách bộ bài: {ex.Message}", ex);
            }
        }

        // ==================== TarotReading Operations ====================

        /// <summary>
        /// Thêm một lượt trải bài mới
        /// </summary>
        public async Task<int> InsertReadingAsync(TarotReading reading)
        {
            try
            {
                if (string.IsNullOrEmpty(reading.Name))
                {
                    // Tự động tạo tên: "Lượt trải dd/MM HH:mm"
                    reading.Name = $"Lượt trải {reading.Date:dd/MM HH:mm}";
                }

                if (reading.Date == default)
                {
                    reading.Date = DateTime.Now;
                }

                return await _database.InsertAsync(reading);
            }
            catch (Exception ex)
            {
                throw new Exception($"Lỗi thêm lượt trải bài: {ex.Message}", ex);
            }
        }

        /// <summary>
        /// Lấy toàn bộ danh sách lượt trải, sắp xếp theo ngày giảm dần
        /// </summary>
        public async Task<List<TarotReading>> GetAllReadingsAsync()
        {
            try
            {
                return await _database.Table<TarotReading>()
                    .OrderByDescending(r => r.Date)
                    .ToListAsync();
            }
            catch (Exception ex)
            {
                throw new Exception($"Lỗi lấy danh sách lượt trải: {ex.Message}", ex);
            }
        }

        /// <summary>
        /// Lấy chi tiết 1 lượt trải theo ID
        /// </summary>
        public async Task<TarotReading> GetReadingByIdAsync(int id)
        {
            try
            {
                return await _database.Table<TarotReading>()
                    .FirstOrDefaultAsync(r => r.Id == id);
            }
            catch (Exception ex)
            {
                throw new Exception($"Lỗi lấy chi tiết lượt trải: {ex.Message}", ex);
            }
        }

        /// <summary>
        /// Cập nhật lượt trải
        /// </summary>
        public async Task<int> UpdateReadingAsync(TarotReading reading)
        {
            try
            {
                return await _database.UpdateAsync(reading);
            }
            catch (Exception ex)
            {
                throw new Exception($"Lỗi cập nhật lượt trải: {ex.Message}", ex);
            }
        }

        /// <summary>
        /// Xóa lượt trải theo ID
        /// </summary>
        public async Task<int> DeleteReadingAsync(int id)
        {
            try
            {
                return await _database.DeleteAsync<TarotReading>(id);
            }
            catch (Exception ex)
            {
                throw new Exception($"Lỗi xóa lượt trải: {ex.Message}", ex);
            }
        }
    }
