// Copyright 2024 Google LLC. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')
@Tags(['node'])
library;

import 'package:test/test.dart';

import '../shared/function.dart';
import '../node_test.dart';

void main() {
  setUpAll(ensureSnapshotUpToDate);
  sharedTests(runSassEmbedded);
}