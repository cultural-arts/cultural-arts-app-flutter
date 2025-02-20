@JS()
library transformers_wrapper;

import 'dart:js_interop';

@JS('analyzeSentiment')
external JSPromise analyzeSentiment(String text);
