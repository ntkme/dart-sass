// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')
@Tags(['node'])
library;

import 'package:test/test.dart';

import '../../ensure_npm_package.dart';
import '../node_test.dart';
import '../shared/deprecations.dart';

void main() {
  setUpAll(ensureNpmPackage);
  sharedTests(runSass);
}
