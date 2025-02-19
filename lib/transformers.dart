@JS()
library transformers_wrapper;

import 'package:js/js.dart';

@JS('analyzeSentiment')
external Object analyzeSentiment(String text);
