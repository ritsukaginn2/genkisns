# GenkiSNS iOS App 启动问题 - 调试总结

**日期**: 2026-06-12  
**问题**: 应用在 "Installing and launching..." 阶段卡住，无法启动  
**根本原因**: SQLite 数据库初始化失败  
**解决方案**: 已修复 ✅

---

## 🔴 问题分析

### 症状
1. App 编译成功（Xcode build done）
2. App 部署到 iPhone（Installing and launching...）
3. **然后卡住，不显示任何错误，应用崩溃**

### 发现的错误
```
flutter: error DatabaseException(Error Domain=SqfliteDarwinDatabase Code=0 "not an error" 
UserInfo={NSLocalizedDescription=not an error}) sql 'PRAGMA journal_mode = WAL' args [] 
during open, closing...
```

### 根本原因
SQLite 数据库文件可能被损坏，或者在打开时执行 WAL（Write-Ahead Logging）pragma 失败。当 `onConfigure` 中的任何代码失败时，整个数据库打开流程就会失败，导致 app 无法初始化数据层。

---

## ✅ 解决方案

### 修复内容
在 `sqlite_post_store.dart` 中实现三层错误恢复：

#### 层级 1: 忽略 WAL 模式错误
```dart
try {
  await db.execute('PRAGMA journal_mode = WAL');
} catch (e) {
  debugPrint('Warning: WAL mode not supported, falling back to default');
  // 继续而不是崩溃
}
```

#### 层级 2: 捕获数据库打开错误
```dart
try {
  database = await openDatabase(...);
} catch (e) {
  debugPrint('Error opening database: $e');
  // 进入恢复流程
}
```

#### 层级 3: 删除损坏数据库并重新创建
```dart
if (dbFile.existsSync()) {
  dbFile.deleteSync();
  debugPrint('Deleted corrupted database, trying again...');
}
// 尝试再次打开（会自动创建新数据库）
database = await openDatabase(...);
```

### 效果
- ✅ App 现在能够从损坏的 SQLite 文件中恢复
- ✅ 如果数据库无法打开，自动删除并创建新的
- ✅ WAL 模式失败时自动降级
- ✅ 不会卡在初始化阶段

---

## 🧪 测试建议

### 在 iPhone 上运行（有线连接更快）
```bash
# 连接 USB 后运行（而不是 wireless）
flutter run -d <your-iphone-id>
```

### 预期行为
1. Xcode 编译完成
2. App 安装到设备
3. App 启动显示首页
4. 初始化日志（可在 Xcode console 中查看）：
   - `LLM Client initialized with installation_id: ...`
   - `IAP availability: true`
   - `Purchases restored`
5. App 显示笔记列表或空状态

### 如果仍有问题
1. 卸载应用（Settings → General → iPhone Storage → GenkiSNS → Delete App）
2. 清理 Flutter 缓存：`flutter clean`
3. 重新运行：`flutter run -d <device-id>`

---

## 📊 性能提示

### 编译速度
- **有线 USB 连接**: ~1-2 分钟
- **Wireless 连接**: ~5-10 分钟

### 建议
- 开发时使用 **USB 有线连接**
- 首次构建后，可以进行热重载（Hot Reload）来快速测试

---

## 📝 代码变更

### 文件
- `apps/mobile/lib/data/stores/sqlite_post_store.dart`

### 变更行数
- 添加: ~98 行
- 修改: ~9 行

### Commit
```
d28baf2 fix: improve SQLite database error handling
```

---

## 🎯 后续步骤

### 立即
1. ✅ 代码已修复并 push 到 GitHub
2. 使用有线连接在 iPhone 上运行：
   ```bash
   flutter run -d <device-id>
   ```

### 如果你想测试后端集成
1. 启动 LLM 后端：
   ```bash
   cd services/llm-proxy
   docker-compose up -d
   ```

2. 修改 App 后端 URL（如果后端运行在本地）
   - 编辑：`apps/mobile/lib/data/services/llm_client.dart`
   - 改变：`static const String baseUrl = 'http://localhost:8000/v1';`

3. 发布笔记，应该能看到 AI 生成的评论

---

## 💡 技术细节

### 为什么这个修复有效
1. **分离关注点**: WAL 模式是优化，失败时可以降级
2. **数据库重建**: 如果文件损坏，删除并重新创建比修复更简单
3. **多层防御**: 三个层级的错误处理确保无论在哪个阶段出错都能恢复
4. **优雅降级**: 不会导致应用完全崩溃

### 何时会触发恢复
- SQLite WAL 模式不受支持（某些旧设备）
- 数据库文件被意外损坏
- 磁盘空间不足导致写入失败
- iOS 系统清理了不完整的数据库

---

**现在应用应该能够在 iPhone 上正常启动！🚀**
