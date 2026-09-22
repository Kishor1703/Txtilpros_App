import 'package:flutter_test/flutter_test.dart';
import 'package:txtilpros_app/app_state.dart';

void main() {
  test('new report supports adding, replacing, and removing an after photo', () {
    final form = createEmptyReportForm();
    final before = <String, dynamic>{'kind': 'before', 'name': 'before.jpg'};
    final after = <String, dynamic>{'kind': 'after', 'name': 'after.jpg'};
    final replacement = <String, dynamic>{'kind': 'after', 'name': 'new.jpg'};

    form['photos']['before'] = <Map<String, dynamic>>[before];
    form['photos']['after'] = after;
    expect(form['photos']['after'], same(after));

    form['photos']['after'] = replacement;
    expect(form['photos']['after'], same(replacement));
    expect(form['photos']['before'], [before]);

    form['photos']['after'] = null;
    expect(form['photos']['after'], isNull);
    expect(createEmptyReportForm()['photos']['before'], isEmpty);
  });
}
