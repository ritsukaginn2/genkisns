import '../../mock/mock_data.dart';
import '../../models.dart';

class UserRepository {
  const UserRepository();

  UserProfile getDefaultUser() => defaultUser;
}
