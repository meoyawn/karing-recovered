class VersionCompareUtils {
  static int compareVersionWithLength(String ver1, String ver2, int length) {
    final one = ver1.split('.');
    final two = ver2.split('.');
    for (var i = 0; i < length; i++) {
      final a = i < one.length ? int.tryParse(one[i]) ?? 0 : 0;
      final b = i < two.length ? int.tryParse(two[i]) ?? 0 : 0;
      if (a != b) return a.compareTo(b);
    }
    return 0;
  }

  static int compareVersion(String ver1, String ver2) {
    List<String> v1 = ver1.split(".");
    List<String> v2 = ver2.split(".");
    if (v1.length == v2.length) {
      for (int i = 0; i < v1.length; ++i) {
        int n1 = int.parse(v1[i]);
        int n2 = int.parse(v2[i]);
        if (n1 < n2) {
          return -1;
        }
        if (n1 > n2) {
          return 1;
        }
      }
    }

    return 0;
  }
}
