# Bộ bài chờ duyệt (Submissions)

Khi người dùng gửi bộ bài của mình lên server, app tạo một Pull Request (branch `submit/...`) và file JSON của bộ bài nằm ở thư mục này.

- Chủ sở hữu (Neito112) xem từng PR trong màn hình quản trị của app (hoặc trên GitHub) rồi duyệt hoặc từ chối.
- PR được duyệt: file được chuyển sang `server/decks/`.
- PR bị từ chối: PR được đóng và file không được giữ lại.

Không đặt token hay thông tin bí mật vào thư mục này.
